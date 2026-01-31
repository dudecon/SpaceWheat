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
const LOOKAHEAD_STEPS = 10  # 10 steps = 1.0s lookahead at 10Hz (~2s visual buffer)
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

# Signal emitted when a biome has its 10-step lookahead buffers primed and is ready
signal biome_ready(biome_name: String)

# Pending biomes waiting for native engine to be ready
var _pending_biomes: Array = []
var _engine_ready: bool = false

# === DISTRIBUTED LOOKAHEAD (low-end CPU optimization) ===
# Instead of computing 10 steps at once (5s CPU spike), split into 5 batches of 2 steps
# Each frame processes one batch, spreading the work across 5 frames
const LOOKAHEAD_BATCH_SIZE = 2  # Steps per request (4ms bridge cost, 2-3ms compute)
const LOOKAHEAD_BATCHES_PER_REFILL = 5  # 5 batches × 2 steps = 10 total
var lookahead_batch_queue: Array = []  # Pending batch requests
var _batches_in_flight: Dictionary = {}  # Track partial results accumulating
var active_flags: Array = []  # Which biomes are active (populated with terminals)

# Statistics
var total_evolutions: int = 0
var skipped_evolutions: int = 0  # Biomes skipped due to no bound terminals
var last_batch_time_ms: float = 0.0
var lookahead_refills: int = 0
var _last_refill_time: int = 0  # Time.get_ticks_msec() of last refill
const LOOKAHEAD_INIT_TIMEOUT_MS = 3000

# Physics FPS tracking (for decoupling visualization)
var _physics_frame_count: int = 0
var _physics_fps_start_time: int = 0
var physics_frames_per_second: float = 0.0

# Detailed batching diagnostics
var _visual_frames_since_refill: int = 0
var _last_cursor_log_time: int = 0
var _evolution_tick_count: int = 0  # Total evolution ticks since start

# Adaptive refill timing
var _avg_batch_time_ms: float = 10.0  # Running average of batch processing time
var _avg_frame_time_ms: float = 16.67  # Running average of frame time (starts at 60fps)
var _last_frame_time: int = 0  # For measuring frame deltas
const REFILL_THRESHOLD_MS = 1000.0  # Start refilling when buffer drops below 1 second
const BATCH_TIME_SMOOTHING = 0.3  # EMA smoothing for batch time (0-1, higher = more responsive)

# Rate limit batch processing to prevent physics from blocking rendering
var _physics_frame_counter: int = 0
const PHYSICS_FRAMES_PER_BATCH = 2  # Only process one batch every N physics frames (allows rendering to run)


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
	"""Register a biome dynamically (after initial batcher setup).

	If native engine isn't ready yet, queues the biome for later registration.
	Biome is only 'ready' after its 10-step lookahead buffers are primed.
	"""
	if not biome or not biome.quantum_computer:
		return
	if biomes.has(biome):
		return

	biomes.append(biome)

	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name

	# Initialize buffer structures (empty until primed)
	frame_buffers[biome_name] = []
	buffer_cursors[biome_name] = 0
	mi_cache[biome_name] = PackedFloat64Array()
	mi_buffers[biome_name] = []
	bloch_buffers[biome_name] = []
	purity_buffers[biome_name] = []
	metadata_payloads[biome_name] = _build_metadata_payload(biome)
	coupling_payloads[biome_name] = _get_coupling_payload_from_viz_cache(biome)
	icon_map_payloads[biome_name] = {}

	# If native engine is ready, register and prime immediately
	if _engine_ready and lookahead_engine and ENABLE_LOOKAHEAD:
		_register_and_prime_biome(biome)
	elif ENABLE_LOOKAHEAD and not _engine_ready:
		# Queue for later - native engine still initializing
		_pending_biomes.append(biome)
		print("BiomeEvolutionBatcher: Queued biome '%s' (waiting for native engine)" % biome_name)
	else:
		# ENABLE_LOOKAHEAD is false - use GDScript fallback
		_prime_single_biome_gdscript(biome)
		print("BiomeEvolutionBatcher: Registered biome '%s' (GDScript mode)" % biome_name)
		biome_ready.emit(biome_name)


func _register_and_prime_biome(biome) -> void:
	"""Register a single biome with native engine and prime its buffers."""
	if not lookahead_engine or not biome or not biome.quantum_computer:
		return

	var qc = biome.quantum_computer
	var dim = qc.register_map.dim()
	var num_qubits = qc.register_map.num_qubits
	var H_packed = qc.hamiltonian._to_packed() if qc.hamiltonian else PackedFloat64Array()
	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name

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

	# Prime the biome's 10-step lookahead buffers
	if lookahead_enabled and biome_id >= 0:
		_prime_single_biome(biome, biome_id)
		print("BiomeEvolutionBatcher: Registered biome '%s' (native, primed)" % biome_name)
		biome_ready.emit(biome_name)
	else:
		# Fallback if native registration failed
		_prime_single_biome_gdscript(biome)
		print("BiomeEvolutionBatcher: Registered biome '%s' (GDScript fallback)" % biome_name)
		biome_ready.emit(biome_name)


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
		_process_pending_biomes_gdscript()
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
	_process_pending_biomes_gdscript()


func _create_lookahead_engine_async() -> void:
	lookahead_engine = ClassDB.instantiate("MultiBiomeLookaheadEngine")
	if not lookahead_engine:
		print("  MultiBiomeLookaheadEngine: Failed to instantiate - using Stage 1 fallback")
		_process_pending_biomes_gdscript()
		return

	print("  MultiBiomeLookaheadEngine: Engine created, processing pending biomes...")

	# Process any biomes that were queued while waiting for engine
	var biomes_to_register = _pending_biomes.duplicate()
	_pending_biomes.clear()

	# Also include any biomes already in the biomes array (from initialize())
	for biome in biomes:
		if not biomes_to_register.has(biome):
			biomes_to_register.append(biome)

	var start_ms = Time.get_ticks_msec()
	var registered_biomes: Array = []

	# Register each biome with the native engine
	for biome in biomes_to_register:
		if Time.get_ticks_msec() - start_ms > LOOKAHEAD_INIT_TIMEOUT_MS:
			print("  MultiBiomeLookaheadEngine: Init timed out during registration - using Stage 1 fallback")
			lookahead_engine = null
			lookahead_enabled = false
			_engine_ready = false
			_process_pending_biomes_gdscript()
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

		if biome_id >= 0:
			registered_biomes.append(biome)

	# Mark engine as ready BEFORE priming (so new biomes can register immediately)
	_engine_ready = true
	lookahead_enabled = (lookahead_engine.get_biome_count() > 0)
	lookahead_accumulator = LOOKAHEAD_DT * LOOKAHEAD_STEPS

	# Prime all registered biomes at once using batched evolution
	if lookahead_enabled and not registered_biomes.is_empty():
		_prime_all_biomes_native(registered_biomes)

	# Log final status
	var lnn_count = 0
	if use_phase_lnn and lookahead_engine.has_method("is_lnn_enabled"):
		for i in range(lookahead_engine.get_biome_count()):
			if lookahead_engine.is_lnn_enabled(i):
				lnn_count += 1

	if lookahead_enabled:
		print("  ✓ Lookahead engine ACTIVATED - Stage 2 batched evolution")
		print("  MultiBiomeLookaheadEngine: %d biomes registered, %d with LNN" % [
			lookahead_engine.get_biome_count(), lnn_count
		])
	else:
		print("  MultiBiomeLookaheadEngine: No biomes registered - falling back to Stage 1")


func _prime_all_biomes_native(biomes_to_prime: Array) -> void:
	"""Prime all biomes at once using batched native evolution.

	This fills the 10-step lookahead buffers for all biomes in one batched call,
	then emits biome_ready for each biome.
	"""
	if not lookahead_engine or biomes_to_prime.is_empty():
		return

	print("  Priming %d biomes with %d-step lookahead..." % [biomes_to_prime.size(), LOOKAHEAD_STEPS])

	# Collect current density matrices for all biomes
	var biome_rhos: Array = []
	for biome in biomes_to_prime:
		var qc = biome.quantum_computer
		if qc and qc.density_matrix:
			biome_rhos.append(qc.density_matrix._to_packed())
		else:
			biome_rhos.append(PackedFloat64Array())

	# Batched evolution: all biomes × LOOKAHEAD_STEPS in one native call
	var evo_result = lookahead_engine.evolve_all_lookahead(
		biome_rhos, LOOKAHEAD_STEPS, LOOKAHEAD_DT, MAX_SUBSTEP_DT
	)

	# Unpack results into per-biome buffers
	var results = evo_result.get("results", [])
	var bloch_steps = evo_result.get("bloch_steps", [])
	var purity_steps = evo_result.get("purity_steps", [])
	var mi_steps = evo_result.get("mi_steps", [])

	for i in range(biomes_to_prime.size()):
		var biome = biomes_to_prime[i]
		var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name

		# Fill buffers with evolution results
		if i < results.size():
			frame_buffers[biome_name] = results[i]
		if i < bloch_steps.size():
			bloch_buffers[biome_name] = bloch_steps[i]
		if i < purity_steps.size():
			purity_buffers[biome_name] = purity_steps[i]
		if i < mi_steps.size():
			mi_buffers[biome_name] = mi_steps[i]

		# Reset cursor to start
		buffer_cursors[biome_name] = 0

		# Update viz_cache from first step
		if biome.viz_cache and not frame_buffers[biome_name].is_empty():
			_apply_buffered_step(biome, false)

		# Emit ready signal - this biome now has its 10 physics packets!
		biome_ready.emit(biome_name)

	lookahead_refills += 1
	print("  ✓ All biomes primed and ready!")


func _process_pending_biomes_gdscript() -> void:
	"""Fallback: Process pending biomes using GDScript when native engine unavailable."""
	if _pending_biomes.is_empty():
		return

	print("  Processing %d pending biomes with GDScript fallback..." % _pending_biomes.size())

	for biome in _pending_biomes:
		_prime_single_biome_gdscript(biome)
		var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name
		print("  → %s primed (GDScript)" % biome_name)
		biome_ready.emit(biome_name)

	_pending_biomes.clear()


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


var _first_tick_logged: bool = false

func physics_process(delta: float):
	"""Called at fixed 20Hz by physics loop (from Farm._physics_process()).

	Routes to lookahead mode (Stage 2) or rotation mode (Stage 1).
	"""
	if biomes.is_empty():
		return

	# One-time diagnostic: confirm lookahead status
	if not _first_tick_logged:
		_first_tick_logged = true
		if lookahead_enabled:
			print("[BiomeEvolutionBatcher] STAGE 2 ACTIVE: %d-step lookahead (%.1fs buffer, refill every %.1fs)" % [
				LOOKAHEAD_STEPS, LOOKAHEAD_STEPS * LOOKAHEAD_DT, (LOOKAHEAD_DT * LOOKAHEAD_STEPS) * 0.8
			])
			print("  → Visual interpolation ENABLED: smooth 60fps between 10Hz physics frames")
		else:
			print("[BiomeEvolutionBatcher] WARNING: Stage 1 fallback active (no native lookahead)")
			print("  → This is SLOWER. Check if MultiBiomeLookaheadEngine loaded correctly.")

	if lookahead_enabled:
		_physics_process_lookahead(delta)
	else:
		_physics_process_rotation(delta)


func _physics_process_lookahead(delta: float):
	"""Stage 2: Lookahead mode - distributed batch processing for smooth frame times."""
	# Track frame timing for adaptive refill
	var now_ms = Time.get_ticks_msec()
	if _last_frame_time > 0:
		var frame_delta_ms = now_ms - _last_frame_time
		_avg_frame_time_ms = lerpf(_avg_frame_time_ms, float(frame_delta_ms), BATCH_TIME_SMOOTHING)
	_last_frame_time = now_ms

	# Update time trackers for all biomes (always)
	for biome in biomes:
		if biome and biome.time_tracker:
			biome.time_tracker.update(delta)

	# Advance buffer cursors (10Hz)
	evolution_accumulator += delta
	if evolution_accumulator >= EVOLUTION_INTERVAL:
		evolution_accumulator = 0.0
		_track_physics_fps()
		_advance_all_buffers()

	# Check if we need to trigger a refill (adaptive timing)
	if lookahead_enabled and lookahead_batch_queue.is_empty() and _should_trigger_refill():
		_trigger_adaptive_refill()

	# Rate-limit batch processing: only process one batch every PHYSICS_FRAMES_PER_BATCH physics frames
	# This prevents the synchronous C++ evolution call from blocking rendering
	_physics_frame_counter += 1
	if _physics_frame_counter >= PHYSICS_FRAMES_PER_BATCH:
		_physics_frame_counter = 0

		# Process one batch per interval to spread work (5 batches × 2 steps = 10 steps total)
		# Spreads ~35ms work across more frames to avoid blocking rendering
		if lookahead_enabled and not lookahead_batch_queue.is_empty():
			process_one_lookahead_batch()


func _should_trigger_refill() -> bool:
	"""Check if buffer is running low enough to trigger a refill.

	Adaptive timing based on:
	- Current buffer level (steps remaining)
	- Time to complete refill (5 batches × avg_frame_time)
	- Safety margin to avoid running dry
	"""
	if biomes.is_empty():
		return false

	# Get buffer state from first biome (all should be in sync)
	var first_biome = biomes[0]
	if not first_biome:
		return false
	var biome_name = first_biome.get_biome_type()
	var buffer = frame_buffers.get(biome_name, [])
	var cursor = buffer_cursors.get(biome_name, 0)

	if buffer.is_empty():
		return true  # No buffer at all, definitely need to refill

	var steps_remaining = buffer.size() - cursor
	if steps_remaining <= 0:
		return true  # Already exhausted

	# Calculate time remaining in buffer (each step = LOOKAHEAD_DT seconds = 100ms)
	var buffer_time_remaining_ms = float(steps_remaining) * LOOKAHEAD_DT * 1000.0

	# Trigger refill when buffer drops below 1 second of coverage
	# This gives plenty of runway for the 5 batches to complete
	return buffer_time_remaining_ms < REFILL_THRESHOLD_MS


func _trigger_adaptive_refill() -> void:
	"""Trigger a refill by queueing batches for distributed processing."""
	# Allow refill if engine exists (external setup) OR _engine_ready (internal setup)
	if not lookahead_engine:
		return

	# Collect current density matrices for all biomes
	var biome_rhos: Array = []
	var refill_active_flags: Array = []

	for biome in biomes:
		if not biome or not biome.quantum_computer:
			biome_rhos.append(PackedFloat64Array())
			refill_active_flags.append(false)
			continue

		var qc = biome.quantum_computer
		var rho_packed = qc.density_matrix._to_packed() if qc.density_matrix else PackedFloat64Array()
		biome_rhos.append(rho_packed)

		# Check if biome has bound terminals (active)
		var is_active = _biome_has_bound_terminals(biome)
		refill_active_flags.append(is_active)

	# Queue the batches for distributed processing
	_queue_lookahead_batches(biome_rhos, refill_active_flags)
	_visual_frames_since_refill = 0

	_log("debug", "REFILL", "🔄", "Triggered adaptive refill (threshold=%.0fms)" % REFILL_THRESHOLD_MS)




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
	"""Prime buffers for a single biome using native engine (fast)."""
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


func _prime_single_biome_gdscript(biome) -> void:
	"""Prime viz_cache with GDScript evolution (fallback when native unavailable).

	Runs a single evolution step to populate viz_cache with real Bloch data.
	This prevents inanimate bubbles when native engine isn't ready yet.
	"""
	if not biome or not biome.quantum_computer:
		return

	var qc = biome.quantum_computer
	var biome_name = biome.get_biome_type()

	_log("info", "biome", "🔄", "Priming '%s' viz_cache with GDScript evolution (native engine pending)" % biome_name)

	# Run a single evolution step to get real phase/color data
	qc.evolve(LOOKAHEAD_DT, MAX_SUBSTEP_DT, null)

	# Export Bloch packet from quantum computer
	var bloch_packet = qc.export_bloch_packet()
	var purity = qc.get_purity()
	var num_qubits = qc.register_map.num_qubits

	# Populate viz_cache directly (bypass buffers since no native lookahead)
	if biome.viz_cache:
		biome.viz_cache.update_from_bloch_packet(bloch_packet, num_qubits)
		biome.viz_cache.update_purity(purity)
		_log("debug", "biome", "✓", "Primed '%s' viz_cache: %d qubits, purity=%.3f" % [
			biome_name,
			biome.viz_cache.get_num_qubits(),
			purity
		])
	else:
		_log("warn", "biome", "⚠️", "Biome '%s' has no viz_cache - cannot prime" % biome_name)


func _refill_all_lookahead_buffers(force_all: bool = false):
	"""Refill lookahead buffers with batched C++ call."""
	var batch_start = Time.get_ticks_usec()
	var now_ms = Time.get_ticks_msec()
	var interval_ms = now_ms - _last_refill_time if _last_refill_time > 0 else 0
	_last_refill_time = now_ms

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

	# NOTE: Metadata already pushed at registration time (static, never changes)

	# === DISTRIBUTED LOOKAHEAD: Queue batches instead of computing all at once ===
	# Split 10 steps into 5 batches of 2 steps, spread across 5 frames
	_queue_lookahead_batches(biome_rhos, active_flags)

	# Initialize frozen buffers for inactive biomes immediately
	for i in range(biomes.size()):
		if i < active_flags.size() and not active_flags[i]:
			var biome = biomes[i]
			if biome:
				var biome_name = biome.get_biome_type()
				var frozen_steps: Array = []
				for _step in range(LOOKAHEAD_STEPS):
					frozen_steps.append(biome_rhos[i])
				frame_buffers[biome_name] = frozen_steps
				buffer_cursors[biome_name] = 0
				mi_buffers[biome_name] = []
				bloch_buffers[biome_name] = []
				purity_buffers[biome_name] = []


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


# =============================================================================
# VISUAL INTERPOLATION LAYER
# =============================================================================
# Physics updates at 10Hz, visuals render at 60fps.
# These methods provide smooth interpolation between physics frames.

func get_interpolation_factor() -> float:
	"""Get interpolation factor t in [0, 1] for smooth visual rendering.

	t=0.0: At the current physics frame
	t=1.0: About to advance to next physics frame

	Visual layer should call this each frame and use it to interpolate
	between get_viz_snapshot(biome, reg, 0) and get_viz_snapshot(biome, reg, 1).
	"""
	if not lookahead_enabled:
		return 0.0
	return clampf(evolution_accumulator / EVOLUTION_INTERVAL, 0.0, 1.0)


func get_interpolated_snapshot(biome_name: String, register_id: int) -> Dictionary:
	"""Get interpolated visualization snapshot for smooth 60fps rendering.

	Interpolates between current physics frame and next frame based on
	time elapsed since last physics tick.

	Returns: {p0, p1, r_xy, phi, purity, t} where t is the interpolation factor
	"""
	var t = get_interpolation_factor()

	# Get current and next frame snapshots
	var curr = get_viz_snapshot(biome_name, register_id, 0)
	var next = get_viz_snapshot(biome_name, register_id, 1)

	# If either is empty, return the non-empty one or empty
	if curr.is_empty():
		return next
	if next.is_empty():
		return curr

	# Interpolate all values
	return {
		"p0": lerpf(curr.get("p0", 0.5), next.get("p0", 0.5), t),
		"p1": lerpf(curr.get("p1", 0.5), next.get("p1", 0.5), t),
		"r_xy": lerpf(curr.get("r_xy", 0.0), next.get("r_xy", 0.0), t),
		"phi": _lerp_angle(curr.get("phi", 0.0), next.get("phi", 0.0), t),
		"purity": lerpf(curr.get("purity", 1.0), next.get("purity", 1.0), t),
		"t": t
	}


func _lerp_angle(a: float, b: float, t: float) -> float:
	"""Interpolate angles handling wraparound at 2*PI."""
	var diff = fmod(b - a + 3.0 * PI, TAU) - PI
	return a + diff * t


func _track_physics_fps() -> void:
	"""Track physics frame rate (separate from visual FPS)."""
	_physics_frame_count += 1
	_evolution_tick_count += 1

	# Initialize timer on first call
	if _physics_fps_start_time == 0:
		_physics_fps_start_time = Time.get_ticks_msec()

	# Update FPS every second (1000ms)
	var now = Time.get_ticks_msec()
	var elapsed = now - _physics_fps_start_time
	if elapsed >= 1000:
		physics_frames_per_second = (_physics_frame_count * 1000.0) / elapsed
		_physics_frame_count = 0
		_physics_fps_start_time = now


func track_visual_frame() -> void:
	"""Call this from render loop to count visual frames between refills."""
	_visual_frames_since_refill += 1


func get_batching_diagnostics() -> Dictionary:
	"""Get detailed diagnostics for batching verification."""
	var first_biome_name = ""
	var cursor = -1
	var buffer_size = 0
	var t = get_interpolation_factor()

	if biomes.size() > 0 and biomes[0]:
		first_biome_name = biomes[0].get_biome_type()
		cursor = buffer_cursors.get(first_biome_name, -1)
		var buffer = frame_buffers.get(first_biome_name, [])
		buffer_size = buffer.size()

	return {
		"lookahead_enabled": lookahead_enabled,
		"evolution_tick": _evolution_tick_count,
		"visual_frames_since_refill": _visual_frames_since_refill,
		"refill_count": lookahead_refills,
		"buffer_cursor": cursor,
		"buffer_size": buffer_size,
		"interpolation_t": t,
		"evolution_accumulator": evolution_accumulator,
		"lookahead_accumulator": lookahead_accumulator,
		"batch_queue_size": lookahead_batch_queue.size(),
	}


# ============================================================================
# DISTRIBUTED LOOKAHEAD - Queue-based batch processing (low-end CPU opt)
# ============================================================================

func _queue_lookahead_batches(biome_rhos: Array, active_flags: Array = []) -> void:
	"""Queue lookahead computation as multiple small batches across frames.

	Instead of computing all LOOKAHEAD_STEPS at once (causes CPU spike),
	split into LOOKAHEAD_BATCHES_PER_REFILL batches of LOOKAHEAD_BATCH_SIZE steps each.
	Each frame processes one batch, spreading work smoothly.

	Cost: ~7ms bridge overhead per batch × 5 batches = ~35ms total, spread over 5 frames
	vs: ~35ms all at once (CPU spike to 100% for 5s on weak hardware)
	"""
	if biome_rhos.is_empty():
		return

	# Clear any previous partial results
	_batches_in_flight.clear()

	# Store active flags for later merge
	self.active_flags = active_flags

	# Queue N batch requests, each computing BATCH_SIZE steps
	for batch_num in range(LOOKAHEAD_BATCHES_PER_REFILL):
		var start_step = batch_num * LOOKAHEAD_BATCH_SIZE
		var batch_request = {
			"batch_num": batch_num,
			"start_step": start_step,
			"num_steps": LOOKAHEAD_BATCH_SIZE,
			"biome_rhos": biome_rhos,
		}
		lookahead_batch_queue.append(batch_request)

	_log("debug", "BATCH", "📦", "Queued %d batches (2 steps each) for lazy processing" % LOOKAHEAD_BATCHES_PER_REFILL)


func process_one_lookahead_batch() -> void:
	"""Process a single batch from the queue. Call this once per frame from update loop.

	Each call:
	- Dequeues one batch request (2 steps for all biomes)
	- Calls C++ to evolve (7ms bridge + 2-3ms compute)
	- Accumulates results
	- When all batches done, merges into buffers
	"""
	if lookahead_batch_queue.is_empty():
		return

	# Dequeue one batch
	var batch_req = lookahead_batch_queue.pop_front()
	var batch_num = batch_req["batch_num"]
	var start_step = batch_req["start_step"]
	var num_steps = batch_req["num_steps"]
	var biome_rhos = batch_req["biome_rhos"]

	# Call C++ for this batch only (minimal steps, minimal spike)
	var batch_start = Time.get_ticks_usec()
	var result = lookahead_engine.evolve_all_lookahead(
		biome_rhos, num_steps, LOOKAHEAD_DT, MAX_SUBSTEP_DT
	)
	var batch_end = Time.get_ticks_usec()
	var batch_time_ms = (batch_end - batch_start) / 1000.0

	# Update running average of batch processing time (for adaptive refill timing)
	_avg_batch_time_ms = lerpf(_avg_batch_time_ms, batch_time_ms, BATCH_TIME_SMOOTHING)
	last_batch_time_ms = batch_time_ms

	# Store partial results keyed by batch number
	_batches_in_flight[batch_num] = result

	# If all batches processed, merge and distribute
	if lookahead_batch_queue.is_empty() and _batches_in_flight.size() == LOOKAHEAD_BATCHES_PER_REFILL:
		_merge_accumulated_batches()
		_batches_in_flight.clear()
		lookahead_refills += 1

	if batch_num == 0:  # Log first batch only
		_log("debug", "BATCH", "📦", "Batch %d: %.1fms (avg=%.1fms)" % [batch_num, batch_time_ms, _avg_batch_time_ms])





func _merge_accumulated_batches() -> void:
	"""Merge all accumulated batch results into the final buffers.

	This is called when all LOOKAHEAD_BATCHES_PER_REFILL batches are complete.
	Reconstructs the full 10-step lookahead result from partial 2-step batches.
	"""
	# Initialize accumulated results per biome
	var accumulated_frames: Array = []
	var accumulated_mi_steps: Array = []
	var accumulated_bloch_steps: Array = []
	var accumulated_purity_steps: Array = []

	# Biomes are same order in all batches
	for i in range(biomes.size()):
		accumulated_frames.append([])
		accumulated_mi_steps.append([])
		accumulated_bloch_steps.append([])
		accumulated_purity_steps.append([])

	# Merge batches in order (batch 0, then 1, 2, 3, 4)
	for batch_num in range(LOOKAHEAD_BATCHES_PER_REFILL):
		if batch_num not in _batches_in_flight:
			continue

		var batch_result = _batches_in_flight[batch_num]
		var results = batch_result.get("results", [])
		var mi_steps = batch_result.get("mi_steps", [])
		var bloch_steps = batch_result.get("bloch_steps", [])
		var purity_steps = batch_result.get("purity_steps", [])

		for i in range(biomes.size()):
			if i < results.size():
				accumulated_frames[i].append_array(results[i])
			if i < mi_steps.size():
				accumulated_mi_steps[i].append_array(mi_steps[i])
			if i < bloch_steps.size():
				accumulated_bloch_steps[i].append_array(bloch_steps[i])
			if i < purity_steps.size():
				accumulated_purity_steps[i].append_array(purity_steps[i])

	# Distribute to buffers (same logic as original refill)
	var batch_end = Time.get_ticks_usec()
	for i in range(biomes.size()):
		var biome = biomes[i]
		if not biome:
			continue

		var biome_name = biome.get_biome_type()
		if i < active_flags.size() and active_flags[i]:
			frame_buffers[biome_name] = accumulated_frames[i]
			buffer_cursors[biome_name] = 0
			mi_buffers[biome_name] = accumulated_mi_steps[i]
			bloch_buffers[biome_name] = accumulated_bloch_steps[i]
			purity_buffers[biome_name] = accumulated_purity_steps[i]
		else:
			# Frozen buffer for inactive biomes
			var frozen_steps: Array = []
			for _step in range(LOOKAHEAD_STEPS):
				frozen_steps.append(biome.quantum_computer.density_matrix._to_packed())
			frame_buffers[biome_name] = frozen_steps


