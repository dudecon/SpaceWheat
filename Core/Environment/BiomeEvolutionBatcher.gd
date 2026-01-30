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
const ENABLE_EVOLUTION = true  # Enable quantum evolution (GDScript fallback path)

# Lookahead configuration (Stage 2)
const ENABLE_LOOKAHEAD = true  # Enable native lookahead if available, else fallback to Stage 1
const LOOKAHEAD_STEPS = 5  # 5 steps = 0.5s lookahead at 10Hz
const LOOKAHEAD_DT = 0.1  # Time per step (matches EVOLUTION_INTERVAL)
const MAX_SUBSTEP_DT = 0.02  # Numerical stability limit

# Phase-shadow LNN configuration (disabled by default to avoid boot-time stalls)
var use_phase_lnn: bool = false  # Enable LNN phase modulation in C++ engine
const LNN_HIDDEN_DIVISOR = 4  # hidden_size = dim / LNN_HIDDEN_DIVISOR

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
var _lookahead_init_started: bool = false
var frame_buffers: Dictionary = {}  # biome_name -> Array[PackedFloat64Array]
var buffer_cursors: Dictionary = {}  # biome_name -> int
var mi_cache: Dictionary = {}  # biome_name -> PackedFloat64Array
var mi_buffers: Dictionary = {}  # biome_name -> Array[PackedFloat64Array]
var bloch_buffers: Dictionary = {}  # biome_name -> Array[PackedFloat64Array]
var purity_buffers: Dictionary = {}  # biome_name -> Array[float]
var metadata_payloads: Dictionary = {}  # biome_name -> Dictionary
var coupling_payloads: Dictionary = {}  # biome_name -> Dictionary
var icon_map_payloads: Dictionary = {}  # biome_name -> Dictionary

# Signal for user action (invalidates lookahead)
signal user_action_detected

# Statistics
var total_evolutions: int = 0
var skipped_evolutions: int = 0  # Biomes skipped due to no bound terminals
var last_batch_time_ms: float = 0.0
var lookahead_refills: int = 0
const LOOKAHEAD_INIT_TIMEOUT_MS = 3000


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
	if ENABLE_LOOKAHEAD:
		_setup_lookahead_engine()

	if lookahead_enabled:
		print("  Mode: Batched lookahead (%d steps × %.1fs = %.1fs buffer)" % [
			LOOKAHEAD_STEPS, LOOKAHEAD_DT, LOOKAHEAD_STEPS * LOOKAHEAD_DT
		])
	else:
		print("  Mode: Stage 1 rotation (%d biomes/frame at %.1fHz)" % [
			BIOMES_PER_FRAME, 1.0 / EVOLUTION_INTERVAL
		])
		if ENABLE_LOOKAHEAD:
			print("  Note: Lookahead engine initializing asynchronously (may activate shortly...)")

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
	mi_buffers[biome_name] = []
	bloch_buffers[biome_name] = []
	purity_buffers[biome_name] = []
	metadata_payloads[biome_name] = _build_metadata_payload(biome)
	coupling_payloads[biome_name] = _get_coupling_payload_from_viz_cache(biome)
	icon_map_payloads[biome_name] = {}

	if lookahead_engine:
		if not ENABLE_LOOKAHEAD:
			return
		var qc = biome.quantum_computer
		var dim = qc.register_map.dim()
		var num_qubits = qc.register_map.num_qubits
		var H_packed = qc.hamiltonian._to_packed() if qc.hamiltonian else PackedFloat64Array()

		var lindblad_triplets: Array = []
		for L in qc.lindblad_operators:
			if L:
				lindblad_triplets.append(_matrix_to_triplets(L))

		var biome_id = lookahead_engine.register_biome(dim, H_packed, lindblad_triplets, num_qubits)
		if biome_id >= 0 and lookahead_engine.has_method("set_biome_metadata"):
			var metadata = _build_metadata_payload(biome)
			lookahead_engine.set_biome_metadata(biome_id, metadata)

		# Enable phase-shadow LNN for this biome (if configured)
		if biome_id >= 0 and use_phase_lnn and lookahead_engine.has_method("enable_biome_lnn"):
			var hidden_size = max(4, dim / LNN_HIDDEN_DIVISOR)
			lookahead_engine.enable_biome_lnn(biome_id, hidden_size)

		lookahead_enabled = (lookahead_engine.get_biome_count() > 0)
		lookahead_accumulator = LOOKAHEAD_DT * LOOKAHEAD_STEPS
		if lookahead_enabled:
			_prime_single_biome(biome, biome_id)

	print("BiomeEvolutionBatcher: Registered biome '%s' (total=%d)" % [biome_name, biomes.size()])


func _setup_lookahead_engine():
	"""Set up the native MultiBiomeLookaheadEngine if available."""
	if ClassDB.class_exists("MultiBiomeLookaheadEngine"):
		call_deferred("_create_lookahead_engine_async")
		return

	# Engine not yet available - wait up to timeout then fall back.
	if not _lookahead_init_started:
		_lookahead_init_started = true
		call_deferred("_await_lookahead_engine")


func _await_lookahead_engine() -> void:
	var tree = Engine.get_main_loop()
	if not tree or not tree is SceneTree:
		print("  MultiBiomeLookaheadEngine: No SceneTree available - using Stage 1 fallback")
		_lookahead_init_started = false
		return

	var start_ms = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms < LOOKAHEAD_INIT_TIMEOUT_MS:
		if ClassDB.class_exists("MultiBiomeLookaheadEngine"):
			await _create_lookahead_engine_async()
			_lookahead_init_started = false
			return
		await tree.process_frame

	print("  MultiBiomeLookaheadEngine: Timeout waiting for native engine - using Stage 1 fallback")
	_lookahead_init_started = false


func _create_lookahead_engine_async() -> void:
	lookahead_engine = ClassDB.instantiate("MultiBiomeLookaheadEngine")
	if not lookahead_engine:
		print("  MultiBiomeLookaheadEngine: Failed to instantiate - using Stage 1 fallback")
		return

	var tree = Engine.get_main_loop()
	var start_ms = Time.get_ticks_msec()

	# Register each biome with the engine
	for biome in biomes:
		if Time.get_ticks_msec() - start_ms > LOOKAHEAD_INIT_TIMEOUT_MS:
			print("  MultiBiomeLookaheadEngine: Init timed out during registration - using Stage 1 fallback")
			lookahead_engine = null
			lookahead_enabled = false
			return

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
		if biome_id >= 0 and lookahead_engine.has_method("set_biome_metadata"):
			var metadata = _build_metadata_payload(biome)
			lookahead_engine.set_biome_metadata(biome_id, metadata)

		# Enable phase-shadow LNN for this biome (if configured)
		if biome_id >= 0 and use_phase_lnn and lookahead_engine.has_method("enable_biome_lnn"):
			var hidden_size = max(4, dim / LNN_HIDDEN_DIVISOR)
			lookahead_engine.enable_biome_lnn(biome_id, hidden_size)

		# Initialize buffers
		var biome_name = biome.get_biome_type()
		frame_buffers[biome_name] = []
		buffer_cursors[biome_name] = 0
		mi_cache[biome_name] = PackedFloat64Array()
		mi_buffers[biome_name] = []
		bloch_buffers[biome_name] = []
		purity_buffers[biome_name] = []
		metadata_payloads[biome_name] = _build_metadata_payload(biome)
		coupling_payloads[biome_name] = _get_coupling_payload_from_viz_cache(biome)

		if tree and tree is SceneTree:
			await tree.process_frame

	lookahead_enabled = (lookahead_engine.get_biome_count() > 0)
	if lookahead_enabled:
		lookahead_accumulator = LOOKAHEAD_DT * LOOKAHEAD_STEPS
		print("  ✓ Lookahead engine ACTIVATED - now using Stage 2 batched evolution")
	var lnn_count = 0
	if use_phase_lnn and lookahead_engine.has_method("is_lnn_enabled"):
		for i in range(lookahead_engine.get_biome_count()):
			if lookahead_engine.is_lnn_enabled(i):
				lnn_count += 1
	print("  MultiBiomeLookaheadEngine: %d biomes registered, %d with LNN" % [
		lookahead_engine.get_biome_count(), lnn_count
	])


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


func _build_metadata_payload(biome) -> Dictionary:
	"""Build structural metadata payload from the biome's register map."""
	if not biome or not biome.quantum_computer or not biome.quantum_computer.register_map:
		return {}
	var register_map = biome.quantum_computer.register_map
	var payload: Dictionary = {}
	payload["num_qubits"] = register_map.num_qubits
	payload["axes"] = register_map.axes.duplicate(true) if "axes" in register_map else {}
	var emoji_to_qubit: Dictionary = {}
	var emoji_to_pole: Dictionary = {}
	var emoji_list: Array = []
	for emoji in register_map.coordinates.keys():
		var coord = register_map.coordinates[emoji]
		emoji_to_qubit[emoji] = coord.get("qubit", -1)
		emoji_to_pole[emoji] = coord.get("pole", -1)
		emoji_list.append(emoji)
	payload["emoji_to_qubit"] = emoji_to_qubit
	payload["emoji_to_pole"] = emoji_to_pole
	payload["emoji_list"] = emoji_list
	return payload


func _get_coupling_payload_from_viz_cache(biome) -> Dictionary:
	"""Get coupling payload from biome's viz_cache (already populated from icons).

	Returns: {
		"hamiltonian": {emoji_a: {emoji_b: coupling_strength, ...}, ...},
		"lindblad": {emoji_a: {emoji_b: rate, ...}, ...}
	}
	"""
	if not biome or not biome.viz_cache:
		return {}

	# viz_cache already has coupling data from icon metadata
	# Extract it by querying all emojis
	var hamiltonian_couplings: Dictionary = {}
	var lindblad_outgoing: Dictionary = {}

	if not biome.quantum_computer or not biome.quantum_computer.register_map:
		return {}

	var register_map = biome.quantum_computer.register_map

	for emoji in register_map.coordinates.keys():
		hamiltonian_couplings[emoji] = biome.viz_cache.get_hamiltonian_couplings(emoji)
		lindblad_outgoing[emoji] = biome.viz_cache.get_lindblad_outgoing(emoji)

	return {
		"hamiltonian": hamiltonian_couplings,
		"lindblad": lindblad_outgoing
	}


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
	# Refill when we've consumed enough to need more (not when buffer is completely empty)
	lookahead_accumulator += delta
	var refill_threshold = (LOOKAHEAD_DT * LOOKAHEAD_STEPS) * 0.8  # Refill at 80% consumption
	if lookahead_accumulator >= refill_threshold:
		lookahead_accumulator = 0.0
		if lookahead_refills % 100 == 0:
			_log("trace", "test", "⚙️", "Refilling lookahead (engine %s)" % [
				"available" if lookahead_engine else "NULL"
			])
		_refill_all_lookahead_buffers()


func _advance_all_buffers():
	"""Advance buffer cursors and update quantum computers with current state."""
	for biome in biomes:
		_apply_buffered_step(biome)


func _apply_buffered_step(biome, apply_post: bool = true) -> void:
	"""Apply current buffered state to a single biome and update viz_cache."""
	if not biome or not biome.quantum_computer:
		return

	var biome_name = biome.get_biome_type()
	var buffer = frame_buffers.get(biome_name, [])
	var cursor = buffer_cursors.get(biome_name, 0)

	if cursor >= buffer.size():
		return

	# Update density matrix from buffer
	var rho_packed = buffer[cursor]
	var dim = biome.quantum_computer.register_map.dim()
	biome.quantum_computer.load_packed_state(rho_packed, dim, true)

	var metadata_payload = metadata_payloads.get(biome_name, {})
	var num_qubits = metadata_payload.get("num_qubits", 0)

	if num_qubits > 0:
		# Update MI cache for force graph (per-step)
		var mi_steps = mi_buffers.get(biome_name, [])
		if cursor < mi_steps.size():
			var mi_step = mi_steps[cursor]
			biome.viz_cache.update_mi_values(mi_step, num_qubits)
			if not mi_step.is_empty():
				biome.quantum_computer._cached_mi_values = mi_step
		elif mi_cache.has(biome_name):
			var mi_cached = mi_cache[biome_name]
			if mi_cached is PackedFloat64Array and not mi_cached.is_empty():
				biome.viz_cache.update_mi_values(mi_cached, num_qubits)

		# Update visualization cache from precomputed lookahead packets
		var bloch_steps = bloch_buffers.get(biome_name, [])
		if cursor < bloch_steps.size():
			var bloch_packet = bloch_steps[cursor]
			if bloch_packet.size() > 0 and Engine.get_process_frames() % 120 == 0:
				print("[BiomeEvolutionBatcher] Updating bloch for %s: packet size=%d, num_qubits=%d" % [
					biome_name, bloch_packet.size(), num_qubits
				])
			biome.viz_cache.update_from_bloch_packet(bloch_packet, num_qubits)
		elif Engine.get_process_frames() % 120 == 0:
			print("[BiomeEvolutionBatcher] ⚠️ No bloch data for %s (cursor=%d, buffer size=%d)" % [
				biome_name, cursor, bloch_steps.size()
			])
			# Detailed diagnostics
			var frame_buffer = frame_buffers.get(biome_name, [])
			var frame_cursor = buffer_cursors.get(biome_name, 0)
			print("  → frame_buffer cursor=%d, size=%d" % [frame_cursor, frame_buffer.size()])
		var purity_steps = purity_buffers.get(biome_name, [])
		if cursor < purity_steps.size():
			biome.viz_cache.update_purity(purity_steps[cursor])
		if metadata_payload:
			biome.viz_cache.update_metadata_from_payload(metadata_payload)
		var coupling_payload = coupling_payloads.get(biome_name, {})
		if coupling_payload:
			biome.viz_cache.update_couplings_from_payload(coupling_payload)
		var icon_map_payload = icon_map_payloads.get(biome_name, {})
		if icon_map_payload:
			biome.viz_cache.update_icon_map(icon_map_payload)

	buffer_cursors[biome_name] = cursor + 1

	# Post-evolution updates
	if apply_post and biome.quantum_evolution_enabled and not biome.evolution_paused:
		_post_evolution_update(biome)


func prime_lookahead_buffers() -> void:
	"""Prime lookahead buffers immediately so viz_cache has payload before UI."""
	if not lookahead_enabled:
		return
	if not _any_active_biomes():
		_prime_frozen_buffers_only()
		for biome in biomes:
			_apply_buffered_step(biome, false)
		return
	_refill_all_lookahead_buffers(false)
	for biome in biomes:
		_apply_buffered_step(biome, false)


func _prime_single_biome(biome, biome_id: int) -> void:
	"""Prime buffers for a single biome (used for dynamic biome registration)."""
	if not lookahead_enabled or not lookahead_engine:
		return
	if not biome or not biome.quantum_computer:
		return
	if biome_id < 0:
		return

	var biome_name = biome.get_biome_type()
	var rho = biome.quantum_computer.density_matrix._to_packed()
	var result = lookahead_engine.evolve_single_biome(
		biome_id, rho, LOOKAHEAD_STEPS, LOOKAHEAD_DT, MAX_SUBSTEP_DT
	)

	frame_buffers[biome_name] = result.get("results", [])
	buffer_cursors[biome_name] = 0
	mi_buffers[biome_name] = result.get("mi_steps", [])
	mi_cache[biome_name] = result.get("mi", PackedFloat64Array())
	bloch_buffers[biome_name] = result.get("bloch_steps", [])
	purity_buffers[biome_name] = result.get("purity_steps", [])
	metadata_payloads[biome_name] = result.get("metadata", metadata_payloads.get(biome_name, {}))
	coupling_payloads[biome_name] = result.get("couplings", coupling_payloads.get(biome_name, {}))
	icon_map_payloads[biome_name] = result.get("icon_map", icon_map_payloads.get(biome_name, {}))

	_apply_buffered_step(biome, false)


func _refill_all_lookahead_buffers(force_all: bool = false):
	"""Refill lookahead buffers with batched C++ call."""
	var batch_start = Time.get_ticks_usec()

	# Check if native engine is available
	if not lookahead_engine:
		_log("warn", "test", "⚠️", "Lookahead engine is null - cannot refill buffers")
		return

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
		if not force_all:
			if plot_pool and not _biome_has_bound_terminals(biome):
				active = false
			if not biome.quantum_evolution_enabled or biome.evolution_paused:
				active = false

		var rho = biome.quantum_computer.density_matrix._to_packed()
		biome_rhos.append(rho)
		active_flags.append(active)

	if biome_rhos.is_empty():
		return
	if not force_all and not _any_active_flags(active_flags):
		_prime_frozen_buffers_only(biome_rhos)
		return

	# Push structural metadata to native engine (aligned with biome order)
	if lookahead_engine and lookahead_engine.has_method("set_biome_metadata"):
		for i in range(biomes.size()):
			var biome = biomes[i]
			var metadata = _build_metadata_payload(biome)
			lookahead_engine.set_biome_metadata(i, metadata)

	# SINGLE C++ CALL for all biomes × all steps
	var result = lookahead_engine.evolve_all_lookahead(
		biome_rhos, LOOKAHEAD_STEPS, LOOKAHEAD_DT, MAX_SUBSTEP_DT
	)

	# Distribute results to buffers
	var results = result.get("results", [])
	var mi_steps_results = result.get("mi_steps", [])
	var mi_results = result.get("mi", [])
	var bloch_steps_results = result.get("bloch_steps", [])
	var purity_steps_results = result.get("purity_steps", [])

	# Diagnostic: check if result counts match biome counts
	if results.size() != biomes.size():
		print("[WARNING] Lookahead result size mismatch: %d results for %d biomes" % [results.size(), biomes.size()])
		print("  Expected: results=%d, mi_steps=%d, bloch_steps=%d, purity=%d" % [
			biomes.size(), biomes.size(), biomes.size(), biomes.size()
		])
		print("  Got: results=%d, mi_steps=%d, bloch_steps=%d, purity=%d" % [
			results.size(), mi_steps_results.size(), bloch_steps_results.size(), purity_steps_results.size()
		])
	var metadata_payloads_result = result.get("metadata", [])
	var coupling_payloads_result = result.get("couplings", [])
	var icon_maps_result = result.get("icon_maps", [])

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
				if lookahead_refills % 50 == 0 and i < bloch_steps_results.size():
					var bloch = bloch_steps_results[i]
					print("[Refill] %s: frame_buffer=%d steps, bloch_buffer=%d packets, cursor reset to 0" % [
						biome_name, results[i].size(), bloch.size() if bloch is Array else 0
					])
			if i < mi_steps_results.size():
				mi_buffers[biome_name] = mi_steps_results[i]
				var mi_steps = mi_steps_results[i]
				if mi_steps.size() > 0:
					mi_cache[biome_name] = mi_steps[mi_steps.size() - 1]
			elif i < mi_results.size():
				mi_cache[biome_name] = mi_results[i]
			if i < bloch_steps_results.size():
				bloch_buffers[biome_name] = bloch_steps_results[i]
			else:
				bloch_buffers[biome_name] = []
			if i < purity_steps_results.size():
				purity_buffers[biome_name] = purity_steps_results[i]
			else:
				purity_buffers[biome_name] = []
			if i < metadata_payloads_result.size():
				metadata_payloads[biome_name] = metadata_payloads_result[i]
			if i < coupling_payloads_result.size():
				coupling_payloads[biome_name] = coupling_payloads_result[i]
			if i < icon_maps_result.size():
				icon_map_payloads[biome_name] = icon_maps_result[i]
		else:
			# Frozen buffer (repeat current state) for inactive/paused biomes
			var frozen_steps: Array = []
			var rho = biome_rhos[i]
			for _step in range(LOOKAHEAD_STEPS):
				frozen_steps.append(rho)
			frame_buffers[biome_name] = frozen_steps
			buffer_cursors[biome_name] = 0
			mi_cache[biome_name] = PackedFloat64Array()
			mi_buffers[biome_name] = []
			bloch_buffers[biome_name] = []
			purity_buffers[biome_name] = []
			if i < metadata_payloads_result.size():
				metadata_payloads[biome_name] = metadata_payloads_result[i]
			if i < coupling_payloads_result.size():
				coupling_payloads[biome_name] = coupling_payloads_result[i]
			if i < icon_maps_result.size():
				icon_map_payloads[biome_name] = icon_maps_result[i]
			inactive_count += 1

	var batch_end = Time.get_ticks_usec()
	last_batch_time_ms = (batch_end - batch_start) / 1000.0
	total_evolutions += (biomes.size() - inactive_count) * LOOKAHEAD_STEPS
	lookahead_refills += 1

	if lookahead_refills % 10 == 0:
		_log("debug", "quantum", "⚡", "Lookahead refill %d biomes × %d steps in %.2fms" % [
			(biomes.size() - inactive_count), LOOKAHEAD_STEPS, last_batch_time_ms
		])
		# Optional sanity log: show top IconMap entries for first available biome
		for biome in biomes:
			if not biome:
				continue
			var biome_name = biome.get_biome_type()
			var icon_map = icon_map_payloads.get(biome_name, {})
			if icon_map and icon_map.has("emojis"):
				var emojis = icon_map.get("emojis", [])
				var weights = icon_map.get("weights", PackedFloat64Array())
				var top = []
				for j in range(min(3, emojis.size())):
					var w = weights[j] if j < weights.size() else 0.0
					top.append("%s:%.2f" % [emojis[j], w])
				_log("debug", "quantum", "🧭", "IconMap %s top: %s" % [biome_name, ", ".join(top)])
				break


func _physics_process_rotation(delta: float):
	"""Stage 1: Rotation mode - evolve BIOMES_PER_FRAME per tick."""
	# No native lookahead -> clear viz caches so visuals go stale
	for biome in biomes:
		if biome and biome.viz_cache:
			biome.viz_cache.clear()

	evolution_accumulator += delta

	if evolution_accumulator >= EVOLUTION_INTERVAL:
		var actual_dt = evolution_accumulator
		evolution_accumulator = 0.0

		_evolve_batch(actual_dt)
		current_index = (current_index + BIOMES_PER_FRAME) % biomes.size()


func get_global_icon_map() -> Dictionary:
	"""Aggregate IconMap payloads across all biomes (resource vocabulary)."""
	var by_emoji: Dictionary = {}
	var total = 0.0
	var steps = 0
	var biome_count = 0

	for biome_name in icon_map_payloads.keys():
		var payload = icon_map_payloads.get(biome_name, {})
		if payload.is_empty():
			continue
		if payload.has("steps"):
			steps = max(steps, int(payload.get("steps", 0)))
		var local = payload.get("by_emoji", {})
		if local.is_empty():
			continue
		biome_count += 1
		for emoji in local.keys():
			var weight = float(local[emoji])
			by_emoji[emoji] = by_emoji.get(emoji, 0.0) + weight

	var emojis: Array = by_emoji.keys()
	emojis.sort_custom(func(a, b): return by_emoji[a] > by_emoji[b])

	var weights = PackedFloat64Array()
	weights.resize(emojis.size())
	for i in range(emojis.size()):
		var emoji = emojis[i]
		var weight = float(by_emoji[emoji])
		weights[i] = weight
		total += weight

	return {
		"emojis": emojis,
		"weights": weights,
		"by_emoji": by_emoji,
		"steps": steps,
		"total": total,
		"num_biomes": biome_count
	}


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
			if biome.time_tracker:
				biome.time_tracker.update(dt)

			if not ENABLE_EVOLUTION:
				skipped_count += 1
				continue

			if plot_pool and not _biome_has_bound_terminals(biome):
				skipped_count += 1
				continue

			if biome.quantum_evolution_enabled and not biome.evolution_paused:
				biome.quantum_computer.evolve(dt, biome.max_evolution_dt)
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


func _any_active_flags(flags: Array) -> bool:
	for flag in flags:
		if flag:
			return true
	return false


func _any_active_biomes() -> bool:
	for biome in biomes:
		if not biome or not biome.quantum_computer:
			continue
		if not biome.quantum_evolution_enabled or biome.evolution_paused:
			continue
		if plot_pool and not _biome_has_bound_terminals(biome):
			continue
		return true
	return false


func _prime_frozen_buffers_only(biome_rhos: Array = []) -> void:
	"""Fill lookahead buffers with frozen current states (no native compute).

	Uses QC.export_bloch_packet() to populate buffers with current state.
	Data flows through the standard railway: buffers → _apply_buffered_step → viz_cache → UI
	"""
	for i in range(biomes.size()):
		var biome = biomes[i]
		if not biome or not biome.quantum_computer:
			continue

		var qc = biome.quantum_computer
		var rho = PackedFloat64Array()
		if i < biome_rhos.size() and biome_rhos[i] is PackedFloat64Array:
			rho = biome_rhos[i]
		if rho.is_empty():
			rho = qc.density_matrix._to_packed()

		var biome_name = biome.get_biome_type()

		# Export current state via QC's standard interface
		var bloch_packet = qc.export_bloch_packet()
		var purity = qc.get_purity()

		# Fill buffers with frozen (repeated) values
		var frozen_rho: Array = []
		var frozen_bloch: Array = []
		var frozen_purity: Array = []
		for _step in range(LOOKAHEAD_STEPS):
			frozen_rho.append(rho)
			frozen_bloch.append(bloch_packet)
			frozen_purity.append(purity)

		frame_buffers[biome_name] = frozen_rho
		buffer_cursors[biome_name] = 0
		bloch_buffers[biome_name] = frozen_bloch
		purity_buffers[biome_name] = frozen_purity
		mi_cache[biome_name] = PackedFloat64Array()
		mi_buffers[biome_name] = []
		metadata_payloads[biome_name] = _build_metadata_payload(biome)
		coupling_payloads[biome_name] = _get_coupling_payload_from_viz_cache(biome)
		icon_map_payloads[biome_name] = {}


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


func get_viz_snapshot(biome_name: String, register_id: int, offset: int = 0) -> Dictionary:
	"""Get visualization snapshot for a register at a lookahead offset.

	Returns a dictionary compatible with QuantumVizCache.get_snapshot():
	{p0, p1, r_xy, phi, purity}
	"""
	if register_id < 0:
		return {}
	var bloch_steps = bloch_buffers.get(biome_name, [])
	if bloch_steps.is_empty():
		return {}
	var cursor = buffer_cursors.get(biome_name, 0)
	var idx = clampi(cursor + offset, 0, bloch_steps.size() - 1)
	var packed = bloch_steps[idx]
	var base = register_id * 8
	if packed.is_empty() or packed.size() < base + 8:
		return {}

	var p0 = packed[base + 0]
	var p1 = packed[base + 1]
	var x = packed[base + 2]
	var y = packed[base + 3]
	var phi = packed[base + 7]
	var r_xy = clampf(sqrt(x * x + y * y), 0.0, 1.0)

	var purity = -1.0
	var purity_steps = purity_buffers.get(biome_name, [])
	if not purity_steps.is_empty() and idx < purity_steps.size():
		purity = purity_steps[idx]

	return {
		"p0": p0,
		"p1": p1,
		"r_xy": r_xy,
		"phi": phi,
		"purity": purity
	}


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
