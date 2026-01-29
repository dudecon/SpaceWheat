class_name BiomeEvolutionBatcher
extends RefCounted

## BiomeEvolutionBatcher - Rotational batch evolution for all biomes
##
## Stage 2: Batched lookahead mode (single C++ call for all biomes × N steps)
## Falls back to Stage 1 rotation if native engine unavailable.
##
## Performance Optimization: Skip evolution for biomes with no bound terminals
## ("Out of sight, out of mind" - don't evolve unpopulated biomes)

## Safely log via VerboseConfig (Resource can't use @onready)
func _log(level: String, category: String, emoji: String, message: String) -> void:
	var tree = Engine.get_main_loop()
	if not tree or not tree is SceneTree:
		return
	var verbose = tree.root.get_node_or_null("/root/VerboseConfig")
	if not verbose:
		return
	match level:
		"info":
			verbose.info(category, emoji, message)
		"debug":
			verbose.debug(category, emoji, message)
		"warn":
			verbose.warn(category, emoji, message)
		"error":
			verbose.error(category, emoji, message)

# Configuration
const BIOMES_PER_FRAME = 2  # Evolve 2 biomes per frame (Stage 1 fallback)
const EVOLUTION_INTERVAL = 0.1  # 10Hz effective rate

# Lookahead configuration (Stage 2)
const LOOKAHEAD_STEPS = 5  # 5 steps = 0.5s lookahead at 10Hz
const LOOKAHEAD_DT = 0.1  # Time per step (matches EVOLUTION_INTERVAL)
const MAX_SUBSTEP_DT = 0.02  # Numerical stability limit

# State
var biomes: Array = []  # All registered biomes
var current_index: int = 0
var evolution_accumulator: float = 0.0

# PlotPool reference for bound terminal checks
var plot_pool = null

# Stage 2: Lookahead engine and buffers
var lookahead_engine = null  # MultiBiomeLookaheadEngine (C++)
var lookahead_enabled: bool = false
var lookahead_accumulator: float = 0.0
var frame_buffers: Dictionary = {}  # biome_name -> Array[PackedFloat64Array]
var buffer_cursors: Dictionary = {}  # biome_name -> int
var mi_cache: Dictionary = {}  # biome_name -> PackedFloat64Array

# Signal for user action (invalidates lookahead)
signal user_action_detected

# Statistics
var total_evolutions: int = 0
var skipped_evolutions: int = 0  # Biomes skipped due to no bound terminals
var last_batch_time_ms: float = 0.0
var lookahead_refills: int = 0


func initialize(biome_array: Array, p_plot_pool = null):
	"""Initialize batcher with all farm biomes.

	Args:
		biome_array: Array of BiomeBase instances
		p_plot_pool: Optional PlotPool for bound terminal optimization
	"""
	plot_pool = p_plot_pool

	# Filter valid biomes (not null, has quantum computer)
	biomes = biome_array.filter(func(b):
		return b != null and b.quantum_computer != null
	)

	print("BiomeEvolutionBatcher: Registered %d biomes for batch evolution" % biomes.size())

	# Try to initialize Stage 2 lookahead engine
	_setup_lookahead_engine()

	if lookahead_enabled:
		print("  Mode: Batched lookahead (%d steps × %.1fs = %.1fs buffer)" % [
			LOOKAHEAD_STEPS, LOOKAHEAD_DT, LOOKAHEAD_STEPS * LOOKAHEAD_DT
		])
	else:
		print("  Mode: Stage 1 rotation (%d biomes/frame at %.1fHz)" % [
			BIOMES_PER_FRAME, 1.0 / EVOLUTION_INTERVAL
		])

	if plot_pool:
		print("  Optimization: Skip evolution for biomes with no bound terminals")


func register_biome(biome) -> void:
	"""Register a biome dynamically (after initial batcher setup)."""
	if not biome or not biome.quantum_computer:
		return
	if biomes.has(biome):
		return

	biomes.append(biome)

	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name
	frame_buffers[biome_name] = []
	buffer_cursors[biome_name] = 0
	mi_cache[biome_name] = PackedFloat64Array()

	if lookahead_engine:
		var qc = biome.quantum_computer
		var dim = qc.register_map.dim()
		var num_qubits = qc.register_map.num_qubits
		var H_packed = qc.hamiltonian._to_packed() if qc.hamiltonian else PackedFloat64Array()

		var lindblad_triplets: Array = []
		for L in qc.lindblad_operators:
			if L:
				lindblad_triplets.append(_matrix_to_triplets(L))

		lookahead_engine.register_biome(dim, H_packed, lindblad_triplets, num_qubits)
		lookahead_enabled = (lookahead_engine.get_biome_count() > 0)
		lookahead_accumulator = LOOKAHEAD_DT * LOOKAHEAD_STEPS

	print("BiomeEvolutionBatcher: Registered biome '%s' (total=%d)" % [biome_name, biomes.size()])


func _setup_lookahead_engine():
	"""Set up the native MultiBiomeLookaheadEngine if available."""
	if not ClassDB.class_exists("MultiBiomeLookaheadEngine"):
		print("  MultiBiomeLookaheadEngine: Not available, using Stage 1 fallback")
		return

	lookahead_engine = ClassDB.instantiate("MultiBiomeLookaheadEngine")
	if not lookahead_engine:
		print("  MultiBiomeLookaheadEngine: Failed to instantiate")
		return

	# Register each biome with the engine
	for biome in biomes:
		var qc = biome.quantum_computer
		if not qc:
			continue

		# Get operators from QuantumComputer
		var dim = qc.register_map.dim()
		var num_qubits = qc.register_map.num_qubits
		var H_packed = qc.hamiltonian._to_packed() if qc.hamiltonian else PackedFloat64Array()

		# Convert Lindblad operators to triplet format
		var lindblad_triplets: Array = []
		for L in qc.lindblad_operators:
			if L:
				lindblad_triplets.append(_matrix_to_triplets(L))

		# Register with lookahead engine
		var biome_id = lookahead_engine.register_biome(dim, H_packed, lindblad_triplets, num_qubits)

		# Initialize buffers
		var biome_name = biome.get_biome_type()
		frame_buffers[biome_name] = []
		buffer_cursors[biome_name] = 0
		mi_cache[biome_name] = PackedFloat64Array()

	lookahead_enabled = (lookahead_engine.get_biome_count() > 0)
	print("  MultiBiomeLookaheadEngine: %d biomes registered" % lookahead_engine.get_biome_count())


func _matrix_to_triplets(mat) -> PackedFloat64Array:
	"""Convert ComplexMatrix to triplet format for native engine."""
	var triplets = PackedFloat64Array()
	var n = mat.n
	var threshold = 1e-15

	for i in range(n):
		for j in range(n):
			var c = mat.get_element(i, j)
			if abs(c.re) > threshold or abs(c.im) > threshold:
				triplets.append(float(i))
				triplets.append(float(j))
				triplets.append(c.re)
				triplets.append(c.im)

	return triplets


func physics_process(delta: float):
	"""Called at fixed 20Hz by physics loop (from Farm._physics_process()).

	Routes to lookahead mode (Stage 2) or rotation mode (Stage 1).
	"""
	if biomes.is_empty():
		return

	if lookahead_enabled:
		_physics_process_lookahead(delta)
	else:
		_physics_process_rotation(delta)


func _physics_process_lookahead(delta: float):
	"""Stage 2: Lookahead mode - refill buffers when exhausted."""
	# Update time trackers for all biomes (always)
	for biome in biomes:
		if biome and biome.time_tracker:
			biome.time_tracker.update(delta)

	# Advance buffer cursors (10Hz)
	evolution_accumulator += delta
	if evolution_accumulator >= EVOLUTION_INTERVAL:
		evolution_accumulator = 0.0
		_advance_all_buffers()

	# Check if any active biome needs refill
	lookahead_accumulator += delta
	if lookahead_accumulator >= LOOKAHEAD_DT * LOOKAHEAD_STEPS:
		lookahead_accumulator = 0.0
		_refill_all_lookahead_buffers()


func _advance_all_buffers():
	"""Advance buffer cursors and update quantum computers with current state."""
	for biome in biomes:
		var biome_name = biome.get_biome_type()
		var buffer = frame_buffers.get(biome_name, [])
		var cursor = buffer_cursors.get(biome_name, 0)

		if cursor < buffer.size():
			# Update density matrix from buffer
			var rho_packed = buffer[cursor]
			var dim = biome.quantum_computer.register_map.dim()
			biome.quantum_computer.density_matrix._from_packed(rho_packed, dim)
			biome.quantum_computer._renormalize()

			# Update MI cache for force graph
			var mi = mi_cache.get(biome_name, PackedFloat64Array())
			if not mi.is_empty():
				biome.quantum_computer._cached_mi_values = mi

			# Compute visualization metrics from buffered state
			# This populates QC's _viz_metrics_cache for all qubits
			biome.quantum_computer.compute_viz_metrics_from_packed(rho_packed)

			buffer_cursors[biome_name] = cursor + 1

			# Post-evolution updates
			if biome.quantum_evolution_enabled and not biome.evolution_paused:
				_post_evolution_update(biome)


func _refill_all_lookahead_buffers():
	"""Refill lookahead buffers with batched C++ call."""
	var batch_start = Time.get_ticks_usec()

	# Collect current rhos for ALL registered biomes (must match native engine order)
	var biome_rhos: Array = []
	var active_flags: Array = []

	for i in range(biomes.size()):
		var biome = biomes[i]
		if not biome or not biome.quantum_computer:
			# Preserve alignment with a blank entry
			biome_rhos.append(PackedFloat64Array())
			active_flags.append(false)
			continue

		var active = true
		if plot_pool and not _biome_has_bound_terminals(biome):
			active = false
		if not biome.quantum_evolution_enabled or biome.evolution_paused:
			active = false

		var rho = biome.quantum_computer.density_matrix._to_packed()
		biome_rhos.append(rho)
		active_flags.append(active)

	if biome_rhos.is_empty():
		return

	# SINGLE C++ CALL for all biomes × all steps
	var result = lookahead_engine.evolve_all_lookahead(
		biome_rhos, LOOKAHEAD_STEPS, LOOKAHEAD_DT, MAX_SUBSTEP_DT
	)

	# Distribute results to buffers
	var results = result.get("results", [])
	var mi_results = result.get("mi", [])

	var inactive_count = 0
	for i in range(biomes.size()):
		var biome = biomes[i]
		if not biome:
			continue
		var biome_name = biome.get_biome_type()
		if i >= biome_rhos.size():
			continue

		if active_flags[i]:
			if i < results.size():
				frame_buffers[biome_name] = results[i]
				buffer_cursors[biome_name] = 0
			if i < mi_results.size():
				mi_cache[biome_name] = mi_results[i]
		else:
			# Frozen buffer (repeat current state) for inactive/paused biomes
			var frozen_steps: Array = []
			var rho = biome_rhos[i]
			for _step in range(LOOKAHEAD_STEPS):
				frozen_steps.append(rho)
			frame_buffers[biome_name] = frozen_steps
			buffer_cursors[biome_name] = 0
			mi_cache[biome_name] = PackedFloat64Array()
			inactive_count += 1

	var batch_end = Time.get_ticks_usec()
	last_batch_time_ms = (batch_end - batch_start) / 1000.0
	total_evolutions += (biomes.size() - inactive_count) * LOOKAHEAD_STEPS
	lookahead_refills += 1

	if lookahead_refills % 10 == 0:
		_log("debug", "quantum", "⚡", "Lookahead refill %d biomes × %d steps in %.2fms" % [
			(biomes.size() - inactive_count), LOOKAHEAD_STEPS, last_batch_time_ms
		])


func _physics_process_rotation(delta: float):
	"""Stage 1: Rotation mode - evolve BIOMES_PER_FRAME per tick."""
	evolution_accumulator += delta

	if evolution_accumulator >= EVOLUTION_INTERVAL:
		var actual_dt = evolution_accumulator
		evolution_accumulator = 0.0

		_evolve_batch(actual_dt)
		current_index = (current_index + BIOMES_PER_FRAME) % biomes.size()


func _evolve_batch(dt: float):
	"""Evolve a batch of biomes (Stage 1: sequential fallback).

	Args:
		dt: Time step (accumulated since last evolution tick)
	"""
	var batch_start = Time.get_ticks_usec()
	var evolved_count = 0
	var skipped_count = 0

	for i in range(BIOMES_PER_FRAME):
		var idx = (current_index + i) % biomes.size()
		var biome = biomes[idx]

		if biome and biome.quantum_computer:
			biome.time_tracker.update(dt)

			if plot_pool and not _biome_has_bound_terminals(biome):
				skipped_count += 1
				continue

			if biome.quantum_evolution_enabled and not biome.evolution_paused:
				biome.quantum_computer.evolve(dt, biome.max_evolution_dt)
				# Compute viz metrics from live state for visualization
				biome.quantum_computer.compute_viz_metrics_from_live()
				evolved_count += 1
				_post_evolution_update(biome)

	var batch_end = Time.get_ticks_usec()
	last_batch_time_ms = (batch_end - batch_start) / 1000.0
	total_evolutions += evolved_count
	skipped_evolutions += skipped_count

	if total_evolutions % 60 == 0:
		var skip_info = " (skipped %d)" % skipped_count if skipped_count > 0 else ""
		_log("debug", "quantum", "⚡", "Evolved %d biomes in %.2fms%s" % [
			evolved_count, last_batch_time_ms, skip_info
		])


func _biome_has_bound_terminals(biome) -> bool:
	"""Check if a biome has any bound terminals (planted plots)."""
	if not plot_pool:
		return true

	if plot_pool.has_method("get_terminals_in_biome"):
		var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name
		return plot_pool.get_terminals_in_biome(biome_name).size() > 0

	return true


func _post_evolution_update(biome):
	"""Apply biome-specific post-evolution updates."""
	if biome.has_method("_apply_semantic_drift"):
		biome._apply_semantic_drift(EVOLUTION_INTERVAL)

	if biome.has_method("_record_attractor_snapshot"):
		biome._record_attractor_snapshot()

	if biome.dynamics_tracker and biome.has_method("_track_dynamics"):
		biome._track_dynamics()

	match biome.get_biome_type():
		"FungalNetworks":
			if biome.has_method("_update_colony_dominance"):
				biome._update_colony_dominance()
		"VolcanicWorlds":
			if biome.has_method("_update_eruption_state"):
				biome._update_eruption_state()


func signal_user_action():
	"""Called when user takes an action that may invalidate lookahead.

	Triggers immediate refill of affected biome's buffer.
	"""
	if lookahead_enabled:
		# Force immediate refill on next physics tick
		lookahead_accumulator = LOOKAHEAD_DT * LOOKAHEAD_STEPS
		user_action_detected.emit()


func get_buffered_state(biome_name: String) -> PackedFloat64Array:
	"""Get current buffered quantum state for a biome.

	Used by visualization to read async from buffer instead of live state.
	"""
	var buffer = frame_buffers.get(biome_name, [])
	var cursor = buffer_cursors.get(biome_name, 0)

	if cursor < buffer.size():
		return buffer[cursor]

	return PackedFloat64Array()


func get_buffered_state_offset(biome_name: String, offset: int) -> PackedFloat64Array:
	"""Get buffered quantum state at an offset from the current cursor.

	Args:
		biome_name: Biome identifier
		offset: 0 = current, 1 = next frame, etc.
	"""
	var buffer = frame_buffers.get(biome_name, [])
	if buffer.is_empty():
		return PackedFloat64Array()

	var cursor = buffer_cursors.get(biome_name, 0)
	var target = clampi(cursor + offset, 0, buffer.size() - 1)
	return buffer[target]


func get_buffered_mi(biome_name: String) -> PackedFloat64Array:
	"""Get cached mutual information for force graph."""
	return mi_cache.get(biome_name, PackedFloat64Array())


func get_stats() -> Dictionary:
	"""Get performance statistics for monitoring."""
	return {
		"biomes": biomes.size(),
		"biomes_per_frame": BIOMES_PER_FRAME,
		"evolution_interval": EVOLUTION_INTERVAL,
		"current_batch_index": current_index,
		"total_evolutions": total_evolutions,
		"skipped_evolutions": skipped_evolutions,
		"last_batch_time_ms": last_batch_time_ms,
		"lookahead_enabled": lookahead_enabled,
		"lookahead_refills": lookahead_refills,
		"lookahead_steps": LOOKAHEAD_STEPS,
	}
