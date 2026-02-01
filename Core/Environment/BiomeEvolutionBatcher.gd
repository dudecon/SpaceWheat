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
const LOOKAHEAD_STEPS = 13  # 13 phrames = 1.3s lookahead (Fib[6])
const LOOKAHEAD_DT = 0.1  # Time per phrame (matches EVOLUTION_INTERVAL = 10Hz)
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
var position_buffers: Dictionary = {}  # biome_name -> Array[PackedVector2Array] (NEW: force positions)
var velocity_buffers: Dictionary = {}  # biome_name -> Array[PackedVector2Array] (NEW: force velocities)
var metadata_payloads: Dictionary = {}  # biome_name -> Dictionary
var coupling_payloads: Dictionary = {}  # biome_name -> Dictionary
var icon_map_payloads: Dictionary = {}  # biome_name -> Dictionary

# Native engine biome ID tracking (fixes index mismatch on unregister)
# Maps biome_name -> engine_biome_id for correct result distribution
var _biome_engine_ids: Dictionary = {}  # biome_name -> int (engine biome ID)
var _engine_id_to_biome: Dictionary = {}  # engine_id -> biome_name (reverse lookup)

# Signal for user action (invalidates lookahead)
signal user_action_detected

# Signal emitted when a biome has its 10-step lookahead buffers primed and is ready
signal biome_ready(biome_name: String)

# Pending biomes waiting for native engine to be ready
var _pending_biomes: Array = []
var _engine_ready: bool = false

# === ADAPTIVE FIBONACCI BATCHING ===
# Two-state machine: RECOVERY (ramp up) and COAST (maintain)
# RECOVERY: Buffer low → Fibonacci batch sizes (1,1,2,3,5,8...) to recover quickly
# COAST: Buffer healthy → fixed batch size for lazy maintenance

enum BufferState { RECOVERY, COAST }

const FIB_SEQUENCE: Array[int] = [1, 1, 2, 3, 5, 8, 13, 21]  # Fibonacci packet sizes (in phrames)
const RECOVERY_THRESHOLD: int = 5   # Phrames - below this = RECOVERY mode
const BATCH_TIME_SMOOTHING: float = 0.3  # EMA smoothing

# Adaptive state
var _buffer_state: BufferState = BufferState.RECOVERY
var _fib_index: int = 4             # Start at Fib[4]=5 for reasonable default
var _emergency_refill: bool = false # True if buffer hit 0 (urgent recovery)

# Computed constants (parametric, based on current Fibonacci index)
var COAST_TARGET: int:
	get:
		var batch_size = FIB_SEQUENCE[mini(_fib_index, FIB_SEQUENCE.size() - 1)]
		return batch_size * 2

# === PER-BIOME ASYNC PACKET QUEUES (Option A: Fully Independent) ===
# Each biome has its own queue, thread, and state tracking
var biome_packet_queues: Dictionary = {}  # biome_name -> Array[packet_request]
var biome_threads: Dictionary = {}        # biome_name -> Thread (one per biome, up to 6 parallel)
var biome_pending: Dictionary = {}        # biome_name -> bool (has queued packet)
var biome_in_flight: Dictionary = {}      # biome_name -> bool (thread currently running)
var biome_paused: Dictionary = {}         # biome_name -> bool (no peeked terminals, skip evolution)
var active_flags: Array = []              # Which biomes are active (populated with terminals)

# Legacy global queue (DEPRECATED - will be removed after migration)
var lookahead_batch_queue: Array = []     # OLD: Global pending packets
var _batches_in_flight: Dictionary = {}  # OLD: Global completed packets
var _batch_thread: Thread = null          # OLD: Global single thread
var _batch_result_ready: Dictionary = {}  # OLD: Unused
var _current_batch_request: Dictionary = {} # OLD: Global request tracking

# Physics frame guard (prevents duplicate calls in same frame)
var _last_physics_frame: int = -1

# Statistics
var total_evolutions: int = 0
var skipped_evolutions: int = 0
var last_batch_time_ms: float = 0.0
var lookahead_refills: int = 0
var _last_refill_time: int = 0
const LOOKAHEAD_INIT_TIMEOUT_MS = 3000

# Physics FPS tracking
var _physics_frame_count: int = 0
var _physics_fps_start_time: int = 0
var physics_frames_per_second: float = 0.0

# Diagnostics
var _visual_frames_since_refill: int = 0
var _last_cursor_log_time: int = 0
var _evolution_tick_count: int = 0

# Frame timing
var _avg_batch_time_ms: float = 10.0
var _avg_frame_time_ms: float = 16.67
var _last_frame_time: int = 0
var _physics_frame_counter: int = 0


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
		print("  Mode: Batched lookahead (%d phrames × %.1fs = %.1fs buffer)" % [
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
	if not _is_valid_biome(biome):
		return
	if biomes.has(biome):
		return

	biomes.append(biome)

	var biome_name = _get_biome_name(biome)

	# Initialize buffer structures (empty until primed)
	frame_buffers[biome_name] = []
	buffer_cursors[biome_name] = 0
	mi_cache[biome_name] = PackedFloat64Array()
	mi_buffers[biome_name] = []
	position_buffers[biome_name] = []  # NEW: force positions
	velocity_buffers[biome_name] = []  # NEW: force velocities
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


func unregister_biome(biome) -> void:
	"""Unregister a biome from the batcher (lightweight cleanup).

	NOTE: The native engine doesn't support unregistration, so engine biome IDs
	accumulate. This method only removes the biome from batcher tracking.
	The engine will receive empty rhos for unregistered biomes and skip them.

	Args:
		biome: The biome to unregister
	"""
	if not biome:
		return

	var biome_name = _get_biome_name(biome)

	# Remove from biomes array
	var idx = biomes.find(biome)
	if idx >= 0:
		biomes.remove_at(idx)

	# Clean up buffer dictionaries
	frame_buffers.erase(biome_name)
	buffer_cursors.erase(biome_name)
	mi_cache.erase(biome_name)
	mi_buffers.erase(biome_name)
	bloch_buffers.erase(biome_name)
	purity_buffers.erase(biome_name)
	position_buffers.erase(biome_name)
	velocity_buffers.erase(biome_name)
	metadata_payloads.erase(biome_name)
	coupling_payloads.erase(biome_name)
	icon_map_payloads.erase(biome_name)

	# NOTE: We do NOT remove from _biome_engine_ids or _engine_id_to_biome
	# because the native engine still has this biome registered.
	# The mapping is needed to correctly skip this biome during result processing.

	print("BiomeEvolutionBatcher: Unregistered biome '%s' from batcher (engine id retained)" % biome_name)


func _register_and_prime_biome(biome) -> void:
	"""Register a single biome with native engine and prime its buffers.

	If the biome is already registered with the engine (e.g., by TestBootManager),
	skips engine registration and just primes the buffers.
	"""
	if not lookahead_engine or not _is_valid_biome(biome):
		return

	var qc = biome.quantum_computer
	var dim = qc.register_map.dim()
	var num_qubits = qc.register_map.num_qubits
	var biome_name = _get_biome_name(biome)

	# Check if biome is already registered with engine (by TestBootManager or other caller)
	var biome_id = _biome_engine_ids.get(biome_name, -1)

	if biome_id < 0:
		# Not yet registered - register with native engine
		var H_packed = qc.hamiltonian._to_packed() if qc.hamiltonian else PackedFloat64Array()

		var lindblad_triplets: Array = []
		for L in qc.lindblad_operators:
			if L:
				lindblad_triplets.append(_matrix_to_triplets(L))

		biome_id = lookahead_engine.register_biome(dim, H_packed, lindblad_triplets, num_qubits)

		# Track biome_id mapping for correct result distribution on unregister
		if biome_id >= 0:
			_biome_engine_ids[biome_name] = biome_id
			_engine_id_to_biome[biome_id] = biome_name

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
		print("BiomeEvolutionBatcher: Registered biome '%s' (native id=%d, primed)" % [biome_name, biome_id])
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

		if not _is_valid_biome(biome):
			continue

		var qc = biome.quantum_computer
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
		var biome_name = _get_biome_name(biome)

		# Track biome_id mapping for correct result distribution on unregister
		if biome_id >= 0:
			_biome_engine_ids[biome_name] = biome_id
			_engine_id_to_biome[biome_id] = biome_name

		if biome_id >= 0 and lookahead_engine.has_method("set_biome_metadata"):
			var metadata = _build_metadata_payload(biome)
			lookahead_engine.set_biome_metadata(biome_id, metadata)

		# Enable phase-shadow LNN for this biome (if configured)
		if biome_id >= 0 and use_phase_lnn and lookahead_engine.has_method("enable_biome_lnn"):
			var hidden_size = max(4, dim / LNN_HIDDEN_DIVISOR)
			lookahead_engine.enable_biome_lnn(biome_id, hidden_size)

		# Initialize buffers
		frame_buffers[biome_name] = []
		buffer_cursors[biome_name] = 0
		mi_cache[biome_name] = PackedFloat64Array()
		mi_buffers[biome_name] = []
		position_buffers[biome_name] = []  # NEW: force positions
		velocity_buffers[biome_name] = []  # NEW: force velocities
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

	This fills the N-phrame lookahead buffers for all biomes in one batched call,
	then emits biome_ready for each biome.
	"""
	if not lookahead_engine or biomes_to_prime.is_empty():
		return

	print("  Priming %d biomes with %d-phrame lookahead..." % [biomes_to_prime.size(), LOOKAHEAD_STEPS])

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
		var biome_name = _get_biome_name(biome)

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

		# Update viz_cache from first phrame
		if biome.viz_cache and not frame_buffers[biome_name].is_empty():
			_apply_buffered_step(biome, false)

		# Emit ready signal - this biome now has its N phrames buffered!
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
		var biome_name = _get_biome_name(biome)
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
	var qc = biome.quantum_computer  # Cache reference
	var register_map = qc.register_map
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
	# Combined validation: check all requirements at once
	if not biome or not biome.viz_cache or not biome.quantum_computer or not biome.quantum_computer.register_map:
		return {}

	# viz_cache already has coupling data from icon metadata
	# Extract it by querying all emojis
	var hamiltonian_couplings: Dictionary = {}
	var lindblad_outgoing: Dictionary = {}

	var qc = biome.quantum_computer
	var register_map = qc.register_map

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
	# GUARD: Prevent duplicate calls in same physics frame
	var current_physics_frame = Engine.get_physics_frames()
	if current_physics_frame == _last_physics_frame:
		push_warning("BiomeEvolutionBatcher: physics_process() called TWICE in physics frame %d! Ignoring duplicate." % current_physics_frame)
		return
	_last_physics_frame = current_physics_frame

	if biomes.is_empty():
		return

	# One-time diagnostic: confirm lookahead status
	if not _first_tick_logged:
		_first_tick_logged = true
		if lookahead_enabled:
			print("[BiomeEvolutionBatcher] STAGE 2 ACTIVE: %d-phrame lookahead (%.1fs buffer, refill every %.1fs)" % [
				LOOKAHEAD_STEPS, LOOKAHEAD_STEPS * LOOKAHEAD_DT, (LOOKAHEAD_DT * LOOKAHEAD_STEPS) * 0.8
			])
			print("  → Visual interpolation ENABLED: smooth 60fps ticks between 10Hz phrames")
		else:
			print("[BiomeEvolutionBatcher] WARNING: Stage 1 fallback active (no native lookahead)")
			print("  → This is SLOWER. Check if MultiBiomeLookaheadEngine loaded correctly.")

	if lookahead_enabled:
		_physics_process_lookahead(delta)
	else:
		_physics_process_rotation(delta)


func _physics_process_lookahead(delta: float):
	"""Stage 2: Lookahead mode - distributed C++ packet processing.

	Terminology:
	- tick = visual frame (60 FPS from _process)
	- phrame = physics/evolution frame (10 Hz, this function runs at 20Hz physics but consumes at 10Hz)
	- packet = C++ batch result containing N phrames

	Key fix: Refill check runs at 10Hz phrame rate (consumption), not 20Hz (physics rate).
	"""
	# Track frame timing (for diagnostics only, not control logic)
	var now_ms = Time.get_ticks_msec()
	if _last_frame_time > 0:
		var frame_delta_ms = now_ms - _last_frame_time
		_avg_frame_time_ms = _smooth_metric(_avg_frame_time_ms, float(frame_delta_ms))
	_last_frame_time = now_ms

	# Update time trackers for all biomes (always)
	for biome in biomes:
		if biome and biome.time_tracker:
			biome.time_tracker.update(delta)

	# === 10Hz CONSUMPTION AND REFILL CYCLE (phrames) ===
	# Advance buffer cursors at 10Hz phrame rate (physics/evolution frames)
	evolution_accumulator += delta

	if evolution_accumulator >= EVOLUTION_INTERVAL:
		evolution_accumulator -= EVOLUTION_INTERVAL  # Subtract, don't reset (preserves fractional delta)

		_track_physics_fps()

		# CONSUME: Advance all buffer cursors (1 phrame per biome)
		_advance_all_buffers()

		# Update buffer state based on consumption
		_update_buffer_state()

		# REFILL CHECK: Per-biome independent refills (Option A)
		# Each biome checks its own depth and queues packets independently
		# Prevents global starvation and non-Fibonacci accumulation
		if lookahead_enabled:
			_trigger_per_biome_refills()

	# === PACKET PROCESSING (per physics frame at 20Hz) ===
	# Process all biome packets in parallel (up to 6 threads)
	# Each biome has independent thread - maximum parallelism
	if lookahead_enabled:
		process_all_biome_packets()

	# === LEGACY GLOBAL QUEUE (DEPRECATED - for fallback only) ===
	# OLD: Global single-thread processing (will be removed)
	if lookahead_enabled and (not lookahead_batch_queue.is_empty() or _batch_thread != null):
		process_one_lookahead_packet()


# =============================================================================
# HELPER FUNCTIONS - DRY pattern extraction
# =============================================================================

class BiomeBufferState:
	"""Encapsulates buffer state for a single biome."""
	var biome_name: String
	var buffer: Array
	var cursor: int
	var depth: int
	var is_empty: bool

	func _init(name: String, buf: Array, cur: int):
		biome_name = name
		buffer = buf
		cursor = cur
		depth = buffer.size() - cursor
		is_empty = depth <= 0


func _is_valid_biome(biome) -> bool:
	"""Check if biome has quantum computer (standard null check)."""
	return biome != null and biome.quantum_computer != null


func _get_biome_name(biome) -> String:
	"""Get biome name with fallback to biome.name."""
	if biome == null:
		return ""
	return biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name


func _get_biome_buffer_state(biome) -> BiomeBufferState:
	"""Get buffer state for a single biome (centralized buffer access).

	Eliminates redundant pattern: frame_buffers.get(biome_name, []) + buffer_cursors.get(biome_name, 0)
	"""
	var biome_name = _get_biome_name(biome)
	var buffer = frame_buffers.get(biome_name, [])
	var cursor = buffer_cursors.get(biome_name, 0)
	return BiomeBufferState.new(biome_name, buffer, cursor)


func _get_all_buffer_states() -> Array[BiomeBufferState]:
	"""Get buffer states for all valid biomes."""
	var states: Array[BiomeBufferState] = []
	for biome in biomes:
		if _is_valid_biome(biome):
			states.append(_get_biome_buffer_state(biome))
	return states


func _get_minimum_buffer_depth() -> int:
	"""Get minimum buffer depth across all active biomes.

	Returns the smallest depth to ensure no biome starves.
	Fixes Issue #2: Previously only checked first biome.
	"""
	if biomes.is_empty():
		return 0

	var min_depth = 999999  # Start with large number
	for biome in biomes:
		if not _is_valid_biome(biome):
			continue

		var state = _get_biome_buffer_state(biome)
		if state.depth < min_depth:
			min_depth = state.depth

	return min_depth if min_depth < 999999 else 0


func _get_buffer_depth() -> int:
	"""DEPRECATED: Use _get_minimum_buffer_depth() instead.

	Kept for backward compatibility, calls new implementation.
	Fixes Issue #2: Now checks ALL biomes, not just first.
	"""
	return _get_minimum_buffer_depth()


func _create_frozen_buffer(rho_packed: PackedFloat64Array, steps: int) -> Array:
	"""Create buffer filled with frozen state (repeated current density matrix).

	Eliminates redundant loop in 3 locations.
	"""
	var frozen_steps: Array = []
	frozen_steps.resize(steps)
	for i in range(steps):
		frozen_steps[i] = rho_packed
	return frozen_steps


func _extract_unconsumed_buffer(biome_name: String, buffer_dict: Dictionary) -> Array:
	"""Extract unconsumed portion of a buffer (slice from cursor position).

	Returns empty array if cursor is at or past end of buffer.
	Eliminates redundant buffer slicing pattern in 4 locations.
	"""
	var buffer = buffer_dict.get(biome_name, [])
	var cursor = buffer_cursors.get(biome_name, 0)

	if cursor >= buffer.size():
		return []

	return buffer.slice(cursor)


func _smooth_metric(current: float, new_value: float, alpha: float = BATCH_TIME_SMOOTHING) -> float:
	"""Exponential moving average smoothing.

	Eliminates redundant lerpf(x, y, BATCH_TIME_SMOOTHING) pattern in 2 locations.
	"""
	return lerpf(current, new_value, alpha)


# === PER-BIOME HELPERS (Option A) ===

func _get_biome_depth(biome_name: String) -> int:
	"""Get buffer depth for a SINGLE biome (not minimum across all).

	Used by per-biome refill logic to check each biome independently.
	"""
	var buffer = frame_buffers.get(biome_name, [])
	var cursor = buffer_cursors.get(biome_name, 0)
	return buffer.size() - cursor


func _get_biome_by_name(biome_name: String):
	"""Find biome object by name. Returns null if not found."""
	for biome in biomes:
		if _get_biome_name(biome) == biome_name:
			return biome
	return null


func _get_engine_id_for_biome(biome_name: String) -> int:
	"""Get C++ engine ID for a biome by name. Returns -1 if not found."""
	for engine_id in _engine_id_to_biome:
		if _engine_id_to_biome[engine_id] == biome_name:
			return engine_id
	return -1


func _update_biome_pause_states():
	"""Update pause state for all biomes based on peeked terminals.

	Paused biomes (no bubbles):
	- Don't queue refill packets (saves computation)
	- Don't consume buffer (freeze at current state)
	- Can be unpaused when terminals are peeked
	"""
	for biome in biomes:
		if not _is_valid_biome(biome):
			continue

		var biome_name = _get_biome_name(biome)
		var has_bubbles = _biome_has_peeked_terminals(biome)
		biome_paused[biome_name] = not has_bubbles


func _biome_has_peeked_terminals(biome) -> bool:
	"""Check if biome has any peeked terminals (bubbles to render).

	Returns false if no terminals are peeked (biome should be paused).
	"""
	if not _is_valid_biome(biome):
		return false

	var qc = biome.quantum_computer
	var num_qubits = qc.register_map.num_qubits if qc.register_map else 0

	# Check if any qubits have been peeked
	for i in range(num_qubits):
		# Check via quantum computer's peek tracking
		# (Assumes QC has peeked state tracking - if not, check plot_pool instead)
		var qubit_data = qc.get_qubit_data(i) if qc.has_method("get_qubit_data") else null
		if qubit_data and qubit_data.get("peeked", false):
			return true

	# Fallback: check via plot_pool if biome has bound terminals
	if plot_pool and plot_pool.has_method("get_biome_peek_count"):
		var peek_count = plot_pool.get_biome_peek_count(biome.get_biome_type())
		return peek_count > 0

	# Default: assume active if we can't determine (safe fallback)
	return true


func _should_trigger_biome_refill(biome_name: String, depth: int) -> bool:
	"""Check if a SINGLE biome needs refill (per-biome logic).

	Same logic as _should_trigger_refill but for individual biomes.
	"""
	# Check if biome is paused (no bubbles)
	if biome_paused.get(biome_name, false):
		return false  # Don't refill paused biomes

	if depth <= 0:
		return true  # Emergency

	if _buffer_state == BufferState.RECOVERY:
		return true  # Always refill in recovery

	# COAST: refill when below 2x target (lazy maintenance)
	return depth < COAST_TARGET * 2


func _update_buffer_state() -> void:
	"""Update RECOVERY/COAST state based on minimum buffer depth across all biomes.

	Fixes Issue #2: Now checks ALL biomes, not just first.
	"""
	var depth = _get_minimum_buffer_depth()
	var prev_state = _buffer_state

	if depth <= 0:
		_buffer_state = BufferState.RECOVERY
		_emergency_refill = true
		if prev_state == BufferState.COAST:
			# Emergency: drop fib_index slightly to ramp up quickly (but don't reset to 0!)
			_fib_index = maxi(2, _fib_index - 1)  # Minimum fib_index=2 (batch_size=2)
			_log("info", "STATE", "🔥", "COAST→RECOVERY: buffer empty! (fib=%d)" % _fib_index)
	elif depth < RECOVERY_THRESHOLD:
		_buffer_state = BufferState.RECOVERY
		if prev_state == BufferState.COAST:
			# Maintain current fib_index - let escalation code handle ramping up
			_log("info", "STATE", "⚠️", "COAST→RECOVERY: min_depth=%d < %d (fib=%d)" % [depth, RECOVERY_THRESHOLD, _fib_index])
	else:
		_buffer_state = BufferState.COAST
		if prev_state == BufferState.RECOVERY:
			_log("info", "STATE", "✅", "RECOVERY→COAST: min_depth=%d >= %d (fib=%d)" % [depth, RECOVERY_THRESHOLD, _fib_index])


func _get_adaptive_batch_size() -> int:
	"""Get batch size using Fibonacci escalation.

	Always uses FIB_SEQUENCE[_fib_index].
	RECOVERY: Advance index when buffer low (escalate)
	COAST: Maintain index (stable batch size)
	"""
	return FIB_SEQUENCE[mini(_fib_index, FIB_SEQUENCE.size() - 1)]


func _should_trigger_refill() -> bool:
	"""Check if we should trigger a refill based on state.

	RECOVERY: Always refill (urgent)
	COAST: Only refill when buffer drops below 2x target
	"""
	if biomes.is_empty():
		return false

	var depth = _get_minimum_buffer_depth()

	if depth <= 0:
		return true  # Emergency

	if _buffer_state == BufferState.RECOVERY:
		return true  # Always refill in recovery

	# COAST: refill when below 2x target (lazy maintenance)
	return depth < COAST_TARGET * 2


func _trigger_adaptive_refill() -> void:
	"""Trigger a refill with adaptive batch sizing.

	Uses minimum buffer depth to ensure no biome starves.

	IMPORTANT: Collects rhos in ENGINE REGISTRATION ORDER (by biome_id), not
	batcher.biomes order. This ensures correct result distribution even after
	biomes are unregistered from batcher (native engine keeps all biomes).
	"""
	if not lookahead_engine:
		return

	var batch_size = _get_adaptive_batch_size()
	var depth = _get_minimum_buffer_depth()

	_emergency_refill = false

	# Build a lookup of active biomes (those still in batcher.biomes)
	var active_biome_names: Dictionary = {}
	for biome in biomes:
		if _is_valid_biome(biome):
			var biome_name = _get_biome_name(biome)
			active_biome_names[biome_name] = biome

	# Collect rhos in ENGINE REGISTRATION ORDER (by biome_id)
	# This ensures the native engine receives rhos in the order it expects
	var engine_biome_count = lookahead_engine.get_biome_count()
	var biome_rhos: Array = []
	var refill_active_flags: Array = []

	for engine_id in range(engine_biome_count):
		var biome_name = _engine_id_to_biome.get(engine_id, "")
		var biome = active_biome_names.get(biome_name, null)

		if biome and _is_valid_biome(biome):
			# Active biome: include current rho
			var qc = biome.quantum_computer
			var rho_packed = qc.density_matrix._to_packed() if qc.density_matrix else PackedFloat64Array()
			biome_rhos.append(rho_packed)
			refill_active_flags.append(true)
		else:
			# Unregistered biome or unknown: send empty rho (engine will skip or use frozen)
			biome_rhos.append(PackedFloat64Array())
			refill_active_flags.append(false)

	# Queue packet with adaptive phrame count
	_queue_adaptive_packet(biome_rhos, refill_active_flags, batch_size)
	_visual_frames_since_refill = 0

	# Only log refills in verbose mode (too noisy)
	_log("trace", "REFILL", "🔄", "%s: packet=%d phrames, min_depth=%d, fib=%d, engine_biomes=%d, active=%d" % [
		BufferState.keys()[_buffer_state], batch_size, depth, _fib_index,
		engine_biome_count, active_biome_names.size()
	])


# === PER-BIOME REFILL LOGIC (Option A) ===

func _trigger_per_biome_refills():
	"""Check each biome independently and queue refills as needed.

	Replaces global _trigger_adaptive_refill with per-biome logic.
	Each biome queues its own packet independently.
	"""
	# Update pause states (check for peeked terminals)
	_update_biome_pause_states()

	# Check each biome independently
	for biome in biomes:
		if not _is_valid_biome(biome):
			continue

		var biome_name = _get_biome_name(biome)

		# Skip if already has pending packet for this biome
		if biome_pending.get(biome_name, false):
			continue

		# Get THIS biome's depth (not minimum across all)
		var depth = _get_biome_depth(biome_name)

		# Check if THIS biome needs refill (considers pause state)
		if _should_trigger_biome_refill(biome_name, depth):
			_queue_biome_packet(biome_name, depth)


func _queue_biome_packet(biome_name: String, current_depth: int):
	"""Queue a packet request for a SINGLE biome.

	Creates independent packet that evolves only this biome.
	Other biomes will be frozen in the C++ call.

	PRE-PACKS all biome rhos in main thread to avoid thread-safety issues.
	"""
	var biome = _get_biome_by_name(biome_name)
	if not biome or not _is_valid_biome(biome):
		return

	var batch_size = _get_adaptive_batch_size()

	# PRE-PACK ALL biomes in main thread (thread-safe)
	# Workaround: We need all biome rhos pre-packed so worker thread doesn't call _to_packed()
	var all_biome_rhos: Array = []
	var engine_biome_count = lookahead_engine.get_biome_count() if lookahead_engine else 0

	for engine_id in range(engine_biome_count):
		var engine_biome_name = _engine_id_to_biome.get(engine_id, "")
		var target_biome = _get_biome_by_name(engine_biome_name)

		if target_biome and _is_valid_biome(target_biome):
			var qc = target_biome.quantum_computer
			var rho_packed = qc.density_matrix._to_packed() if qc.density_matrix else PackedFloat64Array()
			all_biome_rhos.append(rho_packed)
		else:
			all_biome_rhos.append(PackedFloat64Array())

	# Create packet request with all rhos pre-packed
	# PackedFloat64Array is safe to pass to threads as long as we don't modify it
	var packet_req = {
		"biome_name": biome_name,
		"all_biome_rhos": all_biome_rhos,  # Pre-packed in main thread
		"target_biome_index": _get_engine_id_for_biome(biome_name),  # Which one to evolve
		"num_steps": batch_size,
		"timestamp": Time.get_ticks_msec(),
	}

	# Add to THIS biome's queue
	if not biome_packet_queues.has(biome_name):
		biome_packet_queues[biome_name] = []

	biome_packet_queues[biome_name].append(packet_req)
	biome_pending[biome_name] = true

	var state_name = "EMERGENCY" if current_depth <= 0 else BufferState.keys()[_buffer_state]
	_log("trace", "REFILL", "🔄", "%s [%s]: queue packet (batch=%d, depth=%d, fib=%d)" % [
		biome_name, state_name, batch_size, current_depth, _fib_index
	])


func process_all_biome_packets():
	"""Process packets for ALL biomes in parallel (up to 6 threads).

	Each biome has independent thread - allows maximum parallelism.
	Replaces global process_one_lookahead_packet with per-biome dispatch.
	"""
	for biome_name in biome_packet_queues.keys():
		_process_biome_packet(biome_name)


func _process_biome_packet(biome_name: String):
	"""Process packet for a SINGLE biome (non-blocking).

	Manages thread lifecycle for this biome:
	- Check if thread running (return if busy)
	- If thread done, collect result and merge
	- If queue has work, start new thread
	"""
	# Check if thread already running for this biome
	if biome_threads.has(biome_name) and biome_threads[biome_name] != null:
		var thread = biome_threads[biome_name]
		if thread.is_alive():
			return  # Thread still running, don't start another

		# Thread finished - collect result
		var result = thread.wait_to_finish()
		_on_biome_packet_completed(biome_name, result)
		biome_threads[biome_name] = null
		biome_in_flight[biome_name] = false

	# Check if queue has work for this biome
	var queue = biome_packet_queues.get(biome_name, [])
	if queue.is_empty():
		biome_pending[biome_name] = false
		return

	# Dequeue next packet for this biome
	var packet_req = queue.pop_front()

	# Start thread for this biome
	var thread = Thread.new()
	thread.start(_run_biome_packet_in_thread.bind(packet_req))
	biome_threads[biome_name] = thread
	biome_in_flight[biome_name] = true


func _run_biome_packet_in_thread(packet_req: Dictionary) -> Dictionary:
	"""Compute packet for SINGLE biome (runs on worker thread).

	Calls C++ evolve_all_lookahead with:
	- Target biome: real rho (evolve)
	- Other biomes: frozen rho (don't evolve)

	All rhos are PRE-PACKED in main thread - worker thread only uses data.
	"""
	var biome_name = packet_req["biome_name"]
	var all_biome_rhos = packet_req["all_biome_rhos"]  # Already packed!
	var target_biome_index = packet_req["target_biome_index"]
	var num_steps = packet_req["num_steps"]

	# Use pre-packed rhos directly (no node method calls in worker thread!)
	var biome_rhos = all_biome_rhos

	# Call C++ (evolves only target biome, freezes others)
	var packet_start = Time.get_ticks_usec()
	var result = lookahead_engine.evolve_all_lookahead(
		biome_rhos, num_steps, LOOKAHEAD_DT, MAX_SUBSTEP_DT
	)
	var packet_end = Time.get_ticks_usec()

	# Add metadata
	result["biome_name"] = biome_name
	result["batch_time_us"] = packet_end - packet_start

	return result


func _on_biome_packet_completed(biome_name: String, result: Dictionary):
	"""Merge packet results for a SINGLE biome.

	Extracts only this biome's results from the C++ return value.
	Other biomes' results are ignored (they were frozen).
	"""
	if not result or result.get("error", false):
		push_error("BiomeEvolutionBatcher: Packet for %s failed!" % biome_name)
		return

	var results = result.get("results", [])
	var mi_steps = result.get("mi_steps", [])
	var bloch_steps = result.get("bloch_steps", [])
	var purity_steps = result.get("purity_steps", [])
	var position_steps = result.get("position_steps", [])
	var velocity_steps = result.get("velocity_steps", [])
	var batch_time_us = result.get("batch_time_us", 0)

	# Find biome's engine ID
	var engine_id = -1
	for eid in _engine_id_to_biome.keys():
		if _engine_id_to_biome[eid] == biome_name:
			engine_id = eid
			break

	if engine_id < 0:
		push_error("BiomeEvolutionBatcher: Unknown biome %s in packet result!" % biome_name)
		return

	# Extract THIS biome's results only
	var biome_frames = results[engine_id] if engine_id < results.size() else []
	var biome_mi = mi_steps[engine_id] if engine_id < mi_steps.size() else []
	var biome_bloch = bloch_steps[engine_id] if engine_id < bloch_steps.size() else []
	var biome_purity = purity_steps[engine_id] if engine_id < purity_steps.size() else []
	var biome_positions = position_steps[engine_id] if engine_id < position_steps.size() else []
	var biome_velocities = velocity_steps[engine_id] if engine_id < velocity_steps.size() else []

	# Preserve unconsumed steps for THIS biome
	var unconsumed_frames = _extract_unconsumed_buffer(biome_name, frame_buffers)
	var unconsumed_mi = _extract_unconsumed_buffer(biome_name, mi_buffers)
	var unconsumed_bloch = _extract_unconsumed_buffer(biome_name, bloch_buffers)
	var unconsumed_purity = _extract_unconsumed_buffer(biome_name, purity_buffers)
	var unconsumed_positions = _extract_unconsumed_buffer(biome_name, position_buffers)
	var unconsumed_velocities = _extract_unconsumed_buffer(biome_name, velocity_buffers)

	# Append new steps to unconsumed
	var new_frames = unconsumed_frames.duplicate()
	new_frames.append_array(biome_frames)
	frame_buffers[biome_name] = new_frames
	buffer_cursors[biome_name] = 0

	var new_mi = unconsumed_mi.duplicate()
	new_mi.append_array(biome_mi)
	mi_buffers[biome_name] = new_mi

	var new_bloch = unconsumed_bloch.duplicate()
	new_bloch.append_array(biome_bloch)
	bloch_buffers[biome_name] = new_bloch

	var new_purity = unconsumed_purity.duplicate()
	new_purity.append_array(biome_purity)
	purity_buffers[biome_name] = new_purity

	var new_positions = unconsumed_positions.duplicate()
	new_positions.append_array(biome_positions)
	position_buffers[biome_name] = new_positions

	var new_velocities = unconsumed_velocities.duplicate()
	new_velocities.append_array(biome_velocities)
	velocity_buffers[biome_name] = new_velocities

	# Update stats
	last_batch_time_ms = batch_time_us / 1000.0
	_avg_batch_time_ms = _smooth_metric(_avg_batch_time_ms, last_batch_time_ms)

	var new_depth = new_frames.size()
	_log("debug", "MERGE", "✅", "%s: merged %d phrames (depth: %d→%d, %.1fms)" % [
		biome_name, biome_frames.size(), unconsumed_frames.size(), new_depth, last_batch_time_ms
	])


func invalidate_biome_buffer(biome_name: String):
	"""Invalidate buffer for a SINGLE biome (player action).

	Clears:
	- Pending packets in queue (purge)
	- Current buffer contents
	- Force positions/velocities

	Does NOT affect other biomes (per-biome independence).
	"""
	# Purge pending packets for this biome
	if biome_packet_queues.has(biome_name):
		var queue_size = biome_packet_queues[biome_name].size()
		biome_packet_queues[biome_name].clear()
		biome_pending[biome_name] = false

		if queue_size > 0:
			_log("info", "INVALIDATE", "🗑️", "%s: purged %d pending packets" % [biome_name, queue_size])

	# Note: Can't stop running thread (Thread API limitation)
	# Thread will complete, but we discard its result
	if biome_in_flight.get(biome_name, false):
		_log("warn", "INVALIDATE", "⚠️", "%s: thread running, will discard result" % biome_name)
		# TODO: Add flag to discard result in _on_biome_packet_completed

	# Clear buffers for this biome
	frame_buffers[biome_name] = []
	mi_buffers[biome_name] = []
	bloch_buffers[biome_name] = []
	purity_buffers[biome_name] = []
	position_buffers[biome_name] = []
	velocity_buffers[biome_name] = []
	buffer_cursors[biome_name] = 0

	# Re-prime this biome from current state
	var biome = _get_biome_by_name(biome_name)
	if biome:
		_prime_single_biome_frozen(biome)

	_log("info", "INVALIDATE", "🔄", "%s: buffer cleared, re-priming with %d phrames" % [
		biome_name, LOOKAHEAD_STEPS
	])


func _prime_single_biome_frozen(biome):
	"""Prime a single biome with frozen buffers (for invalidation recovery)."""
	if not _is_valid_biome(biome):
		return

	var qc = biome.quantum_computer
	var biome_name = _get_biome_name(biome)
	var rho_packed = qc.density_matrix._to_packed() if qc.density_matrix else PackedFloat64Array()

	# Fill with frozen current state
	frame_buffers[biome_name] = _create_frozen_buffer(rho_packed, LOOKAHEAD_STEPS)
	buffer_cursors[biome_name] = 0

	# Export current Bloch and purity
	var bloch_packet = qc.export_bloch_packet() if qc.has_method("export_bloch_packet") else PackedFloat64Array()
	var purity = qc.get_purity() if qc.has_method("get_purity") else 1.0

	bloch_buffers[biome_name] = _create_frozen_buffer(bloch_packet, LOOKAHEAD_STEPS)

	var frozen_purity: Array = []
	frozen_purity.resize(LOOKAHEAD_STEPS)
	for i in range(LOOKAHEAD_STEPS):
		frozen_purity[i] = purity
	purity_buffers[biome_name] = frozen_purity

	mi_buffers[biome_name] = []
	position_buffers[biome_name] = []
	velocity_buffers[biome_name] = []


func _advance_all_buffers():
	"""Advance buffer cursors and update quantum computers with current state.

	Skips paused biomes (no peeked terminals) to save computation.
	"""
	for biome in biomes:
		if not _is_valid_biome(biome):
			continue

		var biome_name = _get_biome_name(biome)

		# Skip paused biomes (no bubbles to render)
		if biome_paused.get(biome_name, false):
			continue

		_apply_buffered_step(biome)


func _apply_buffered_step(biome, apply_post: bool = true) -> void:
	"""Apply current buffered state to a single biome and update viz_cache."""
	if not _is_valid_biome(biome):
		return

	var state = _get_biome_buffer_state(biome)
	var biome_name = state.biome_name
	var buffer = state.buffer
	var cursor = state.cursor

	if cursor >= buffer.size():
		return

	# Update density matrix from buffer
	var rho_packed = buffer[cursor]
	var qc = biome.quantum_computer  # Cache reference (accessed multiple times below)
	var dim = qc.register_map.dim()
	qc.load_packed_state(rho_packed, dim, true)

	var metadata_payload = metadata_payloads.get(biome_name, {})
	var num_qubits = metadata_payload.get("num_qubits", 0)

	if num_qubits > 0:
		# Update MI cache for force graph (per-step)
		var mi_steps = mi_buffers.get(biome_name, [])
		if cursor < mi_steps.size():
			var mi_step = mi_steps[cursor]
			biome.viz_cache.update_mi_values(mi_step, num_qubits)
			if not mi_step.is_empty():
				qc._cached_mi_values = mi_step
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
	if not _is_valid_biome(biome):
		return
	if biome_id < 0:
		return

	var biome_name = _get_biome_name(biome)
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
	if not _is_valid_biome(biome):
		return

	var qc = biome.quantum_computer
	var biome_name = _get_biome_name(biome)

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
	"""Refill lookahead buffers with batched C++ call.

	IMPORTANT: Collects rhos in ENGINE REGISTRATION ORDER (by biome_id), not
	batcher.biomes order. This ensures correct result distribution even after
	biomes are unregistered from batcher.
	"""
	var batch_start = Time.get_ticks_usec()
	var now_ms = Time.get_ticks_msec()
	var interval_ms = now_ms - _last_refill_time if _last_refill_time > 0 else 0
	_last_refill_time = now_ms

	# Check if native engine is available
	if not lookahead_engine:
		_log("warn", "test", "⚠️", "Lookahead engine is null - cannot refill buffers")
		return

	# Build a lookup of active biomes (those still in batcher.biomes)
	var active_biome_names: Dictionary = {}
	for biome in biomes:
		if _is_valid_biome(biome):
			var biome_name = _get_biome_name(biome)
			active_biome_names[biome_name] = biome

	# Collect rhos in ENGINE REGISTRATION ORDER (by biome_id)
	var engine_biome_count = lookahead_engine.get_biome_count()
	var biome_rhos: Array = []
	var refill_active_flags: Array = []

	for engine_id in range(engine_biome_count):
		var biome_name = _engine_id_to_biome.get(engine_id, "")
		var biome = active_biome_names.get(biome_name, null)

		if biome and _is_valid_biome(biome):
			var active = true
			if not force_all:
				if plot_pool and not _biome_has_bound_terminals(biome):
					active = false
				if not biome.quantum_evolution_enabled or biome.evolution_paused:
					active = false

			var rho = biome.quantum_computer.density_matrix._to_packed()
			biome_rhos.append(rho)
			refill_active_flags.append(active)
		else:
			# Unregistered biome: send empty rho
			biome_rhos.append(PackedFloat64Array())
			refill_active_flags.append(false)

	if biome_rhos.is_empty():
		return
	if not force_all and not _any_active_flags(refill_active_flags):
		_prime_frozen_buffers_only(biome_rhos)
		return

	# NOTE: Metadata already pushed at registration time (static, never changes)

	# === ADAPTIVE FIBONACCI PACKET SIZING ===
	# Use adaptive packet sizing (number of phrames) based on current state
	var packet_size = _get_adaptive_batch_size()
	_queue_adaptive_packet(biome_rhos, refill_active_flags, packet_size)

	# Initialize frozen buffers for inactive biomes immediately
	for engine_id in range(engine_biome_count):
		var biome_name = _engine_id_to_biome.get(engine_id, "")
		if biome_name == "" or not active_biome_names.has(biome_name):
			continue
		var biome = active_biome_names[biome_name]
		if engine_id < refill_active_flags.size() and not refill_active_flags[engine_id]:
			if _is_valid_biome(biome):
				var rho = biome_rhos[engine_id] if engine_id < biome_rhos.size() else PackedFloat64Array()
				frame_buffers[biome_name] = _create_frozen_buffer(rho, LOOKAHEAD_STEPS)
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


# === PUBLIC API: Per-Biome Control ===

func pause_biome(biome_name: String):
	"""Manually pause a biome (stop evolution, no refills).

	Useful for debugging or performance optimization.
	"""
	biome_paused[biome_name] = true
	_log("info", "CONTROL", "⏸️", "%s: manually paused" % biome_name)


func resume_biome(biome_name: String):
	"""Manually resume a paused biome (allow evolution and refills)."""
	biome_paused[biome_name] = false
	_log("info", "CONTROL", "▶️", "%s: manually resumed" % biome_name)


func is_biome_paused(biome_name: String) -> bool:
	"""Check if a biome is currently paused."""
	return biome_paused.get(biome_name, false)


func get_biome_diagnostics(biome_name: String) -> Dictionary:
	"""Get detailed diagnostics for a SINGLE biome.

	Returns:
	- depth: Current buffer depth (unconsumed phrames)
	- paused: Whether biome is paused (no evolution)
	- pending: Whether biome has queued packet
	- in_flight: Whether biome has running thread
	- queue_size: Number of pending packets for this biome
	"""
	return {
		"biome_name": biome_name,
		"depth": _get_biome_depth(biome_name),
		"paused": biome_paused.get(biome_name, false),
		"pending": biome_pending.get(biome_name, false),
		"in_flight": biome_in_flight.get(biome_name, false),
		"queue_size": biome_packet_queues.get(biome_name, []).size(),
	}


func get_all_biome_diagnostics() -> Dictionary:
	"""Get diagnostics for ALL biomes (per-biome status).

	Returns dictionary: biome_name -> diagnostics
	"""
	var diagnostics: Dictionary = {}
	for biome in biomes:
		if _is_valid_biome(biome):
			var biome_name = _get_biome_name(biome)
			diagnostics[biome_name] = get_biome_diagnostics(biome_name)
	return diagnostics


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
		if not _is_valid_biome(biome):
			continue

		var qc = biome.quantum_computer
		var rho = PackedFloat64Array()
		if i < biome_rhos.size() and biome_rhos[i] is PackedFloat64Array:
			rho = biome_rhos[i]
		if rho.is_empty():
			rho = qc.density_matrix._to_packed()

		var biome_name = _get_biome_name(biome)

		# Export current state via QC's standard interface
		var bloch_packet = qc.export_bloch_packet()
		var purity = qc.get_purity()

		# Fill buffers with frozen (repeated) values using helper
		frame_buffers[biome_name] = _create_frozen_buffer(rho, LOOKAHEAD_STEPS)
		buffer_cursors[biome_name] = 0
		bloch_buffers[biome_name] = _create_frozen_buffer(bloch_packet, LOOKAHEAD_STEPS)
		# Purity buffer is Array[float], not Array[PackedFloat64Array]
		var frozen_purity: Array = []
		frozen_purity.resize(LOOKAHEAD_STEPS)
		for step_idx in range(LOOKAHEAD_STEPS):
			frozen_purity[step_idx] = purity
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
# Phrames update at 10Hz, visual ticks render at 60fps.
# These methods provide smooth interpolation between phrames.

func get_interpolation_factor() -> float:
	"""Get interpolation factor t in [0, 1] for smooth visual rendering.

	t=0.0: At the current phrame (evolution frame)
	t=1.0: About to advance to next phrame

	Visual layer should call this each tick (60 FPS) and use it to interpolate
	between get_viz_snapshot(biome, reg, 0) and get_viz_snapshot(biome, reg, 1).
	"""
	if not lookahead_enabled:
		return 0.0
	return clampf(evolution_accumulator / EVOLUTION_INTERVAL, 0.0, 1.0)


func get_interpolated_snapshot(biome_name: String, register_id: int) -> Dictionary:
	"""Get interpolated visualization snapshot for smooth 60fps tick rendering.

	Interpolates between current phrame and next phrame based on
	time elapsed since last phrame consumption (10Hz).

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


func get_interpolated_force_positions(biome_name: String) -> PackedVector2Array:
	"""Get interpolated force positions for smooth 60fps rendering.

	Returns interpolated positions between current phrame (t=0) and next phrame (t=1).
	"""
	var t = get_interpolation_factor()
	var cursor = buffer_cursors.get(biome_name, 0)
	var positions = position_buffers.get(biome_name, [])

	if positions.is_empty() or cursor >= positions.size():
		return PackedVector2Array()

	# Get current and next positions
	var curr_positions = positions[cursor] if cursor < positions.size() else PackedVector2Array()
	var next_positions = positions[cursor + 1] if (cursor + 1) < positions.size() else curr_positions

	# Interpolate each position
	var result = PackedVector2Array()
	var num_nodes = mini(curr_positions.size(), next_positions.size())
	result.resize(num_nodes)

	for i in range(num_nodes):
		result[i] = curr_positions[i].lerp(next_positions[i], t)

	return result


func get_force_positions(biome_name: String, lookahead: int = 0) -> PackedVector2Array:
	"""Get force positions for a biome at cursor + lookahead offset.

	Args:
		biome_name: Name of the biome
		lookahead: Offset from cursor (0 = current, 1 = next, etc.)

	Returns: PackedVector2Array of node positions
	"""
	var cursor = buffer_cursors.get(biome_name, 0)
	var positions = position_buffers.get(biome_name, [])

	var index = cursor + lookahead
	if index >= 0 and index < positions.size():
		return positions[index]
	return PackedVector2Array()


func _lerp_angle(a: float, b: float, t: float) -> float:
	"""Interpolate angles handling wraparound at 2*PI."""
	var diff = fmod(b - a + 3.0 * PI, TAU) - PI
	return a + diff * t


func _track_physics_fps() -> void:
	"""Track phrame rate (10Hz evolution consumption, separate from visual 60 FPS ticks)."""
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

	var state_name = "RECOVERY" if _buffer_state == BufferState.RECOVERY else "COAST"

	return {
		"lookahead_enabled": lookahead_enabled,
		"evolution_tick": _evolution_tick_count,
		"visual_frames_since_refill": _visual_frames_since_refill,
		"refill_count": lookahead_refills,
		"buffer_cursor": cursor,
		"buffer_size": buffer_size,
		"buffer_depth": buffer_size - max(0, cursor),
		"interpolation_t": t,
		"evolution_accumulator": evolution_accumulator,
		"lookahead_accumulator": lookahead_accumulator,
		"batch_queue_size": lookahead_batch_queue.size(),
		# Fibonacci adaptive state
		"buffer_state": state_name,
		"fib_index": _fib_index,
		"adaptive_batch_size": _get_adaptive_batch_size(),
	}


func get_performance_metrics() -> Dictionary:
	"""Get C++ task timing metrics for profiling."""
	# Calculate buffer depth
	var buffer_depth = _get_buffer_depth()
	var buffer_coverage_ms = buffer_depth * LOOKAHEAD_DT * 1000.0  # ms of coverage

	# Get current adaptive batch size
	var adaptive_batch_size = _get_adaptive_batch_size()
	var state_name = "RECOVERY" if _buffer_state == BufferState.RECOVERY else "COAST"

	# Calculate refill threshold in milliseconds
	var refill_threshold_ms = COAST_TARGET * 2 * LOOKAHEAD_DT * 1000.0

	# Count per-biome threads and pending packets
	var total_threads_running = 0
	var total_packets_pending = 0
	var total_biomes_paused = 0
	for biome_name in biome_threads.keys():
		var thread = biome_threads[biome_name]
		if thread and thread.is_alive():
			total_threads_running += 1
		if biome_packet_queues.get(biome_name, []).size() > 0:
			total_packets_pending += biome_packet_queues[biome_name].size()
		if biome_paused.get(biome_name, false):
			total_biomes_paused += 1

	return {
		# Timing
		"last_batch_time_ms": last_batch_time_ms,
		"avg_batch_time_ms": _avg_batch_time_ms,
		"avg_frame_time_ms": _avg_frame_time_ms,
		# Adaptive Fibonacci Batching
		"buffer_state": state_name,
		"fib_index": _fib_index,
		"adaptive_batch_size": adaptive_batch_size,
		"batch_size": adaptive_batch_size,  # Alias for VisualBubbleTest compatibility
		"batches_per_refill": 1,  # Always 1 in adaptive mode (variable size per batch)
		"recovery_threshold": RECOVERY_THRESHOLD,
		"coast_target": COAST_TARGET,
		"emergency_refill": _emergency_refill,
		"refill_threshold_ms": refill_threshold_ms,
		# Per-Biome Queue State (Option A)
		"biomes_total": biomes.size(),
		"biomes_paused": total_biomes_paused,
		"biomes_active": biomes.size() - total_biomes_paused,
		"threads_running": total_threads_running,
		"packets_pending": total_packets_pending,
		# Legacy Queue State (DEPRECATED)
		"batches_pending": lookahead_batch_queue.size(),
		"batches_in_flight": 1 if (_batch_thread != null and _batch_thread.is_alive()) else 0,
		"batches_accumulated": _batches_in_flight.size(),
		# Buffer state (minimum across all biomes)
		"buffer_depth": buffer_depth,
		"buffer_coverage_ms": buffer_coverage_ms,
		# Per-Biome Diagnostics
		"per_biome": get_all_biome_diagnostics(),
		# Stats
		"total_evolutions": total_evolutions,
		"refill_count": lookahead_refills,
		"physics_fps": physics_frames_per_second,
	}


# ============================================================================
# DISTRIBUTED LOOKAHEAD - Queue-based C++ packet processing (async compute)
# ============================================================================

func _queue_adaptive_packet(biome_rhos: Array, active_flags_arr: Array, packet_size: int) -> void:
	"""Queue a SINGLE C++ packet with adaptive size (Fibonacci-based).

	Terminology:
	- phrame = physics/evolution frame (10 Hz)
	- packet = C++ batch result containing N phrames

	RECOVERY: packet_size from Fibonacci sequence (1,1,2,3,5,8... phrames)
	COAST: fixed size for maintenance
	"""
	if biome_rhos.is_empty():
		return

	# Clear any previous partial results
	_batches_in_flight.clear()

	# Store active flags for later merge
	self.active_flags = active_flags_arr

	# Queue SINGLE packet with adaptive phrame count
	var packet_request = {
		"batch_num": 0,  # Legacy key name (packet number)
		"start_step": 0,
		"num_steps": packet_size,  # Number of phrames to compute
		"biome_rhos": biome_rhos,
		"total_batches": 1,  # Legacy key: always 1 packet per refill in adaptive mode
	}
	lookahead_batch_queue.append(packet_request)


func cleanup_async_packet() -> void:
	"""Clean up any running C++ packet thread (call before destroying batcher).

	This prevents "Thread destroyed without completion" warnings.
	"""
	if _batch_thread != null and _batch_thread.is_alive():
		_log("debug", "PACKET", "🧹", "Waiting for packet thread to finish (cleanup)...")
		var result = _batch_thread.wait_to_finish()
		# Don't process result during cleanup, just wait for thread to finish
		_batch_thread = null


func process_one_lookahead_packet() -> void:
	"""Process C++ packet in background thread (ASYNC - does not block main thread!).

	Terminology:
	- tick = visual frame (60 FPS)
	- phrame = physics/evolution frame (10 Hz)
	- packet = C++ batch result containing N phrames

	Uses Thread object for simpler async pattern with is_alive() checking.

	Each call:
	- Checks if previous packet thread still running (non-blocking)
	- If done, gets result and processes it
	- If queue not empty and no packet running, starts new packet in background
	"""
	# CHECK: Is previous packet thread still running?
	if _batch_thread != null:
		if _batch_thread.is_alive():
			# Thread still running - don't start new one, don't block
			return

		# Thread finished - get result (non-blocking, thread already done)
		var result = _batch_thread.wait_to_finish()
		_on_packet_completed(result)
		_batch_thread = null

	# START: Queue not empty and no packet running?
	if lookahead_batch_queue.is_empty():
		return

	# Dequeue next packet request
	_current_batch_request = lookahead_batch_queue.pop_front()

	# Start packet computation in background thread (NON-BLOCKING!)
	_batch_thread = Thread.new()
	_batch_thread.start(_run_packet_in_thread.bind(_current_batch_request))


func _run_packet_in_thread(packet_req: Dictionary) -> Dictionary:
	"""Runs on worker thread - DOES NOT BLOCK MAIN THREAD!

	This function computes a C++ packet (N phrames of evolution) in the background
	while the main thread continues rendering ticks at 60 FPS.

	THREAD SAFETY:
	- Input data (packet_req) is passed by value (copied to worker thread)
	- lookahead_engine.evolve_all_lookahead() is assumed to be thread-safe
	  (read-only access to engine state, no shared mutable data)
	- Result dictionary is returned by value, processed on main thread
	"""
	var packet_num = packet_req.get("batch_num", -1)  # Legacy key name, means packet number
	var biome_rhos = packet_req["biome_rhos"]
	var num_phrames = packet_req["num_steps"]  # Number of phrames (evolution frames) to compute
	var total_packets = packet_req.get("total_batches", 1)  # Legacy key, means total packets

	# Time the C++ call (this blocks the WORKER thread, not main thread)
	var packet_start = Time.get_ticks_usec()
	var result = lookahead_engine.evolve_all_lookahead(
		biome_rhos, num_phrames, LOOKAHEAD_DT, MAX_SUBSTEP_DT
	)
	var packet_end = Time.get_ticks_usec()

	# Error handling: check if result is valid
	if result == null or not result is Dictionary:
		push_error("BiomeEvolutionBatcher: Packet %d failed - C++ returned invalid result!" % packet_num)
		return {
			"batch_num": packet_num,
			"total_batches": total_packets,
			"batch_time_us": packet_end - packet_start,
			"error": true,
			"results": [],
			"mi_steps": [],
			"bloch_steps": [],
			"purity_steps": []
		}

	# Add metadata to result
	result["batch_time_us"] = packet_end - packet_start
	result["batch_num"] = packet_num
	result["total_batches"] = total_packets
	result["error"] = false

	return result


func _on_packet_completed(result: Dictionary) -> void:
	"""Called on main thread when background C++ packet finishes computing."""
	var packet_num = result.get("batch_num", 0)  # Legacy key name
	var packet_time_ms = result.get("batch_time_us", 0) / 1000.0
	var total_packets = result.get("total_batches", 1)  # Legacy key name
	var has_error = result.get("error", false)

	# Check for errors from worker thread
	if has_error:
		push_error("BiomeEvolutionBatcher: Packet %d completed with errors - skipping merge" % packet_num)
		# Clear queue to prevent stacking failed packets
		lookahead_batch_queue.clear()
		_batches_in_flight.clear()
		return

	# Update metrics
	_avg_batch_time_ms = _smooth_metric(_avg_batch_time_ms, packet_time_ms)
	last_batch_time_ms = packet_time_ms

	# Store result in _batches_in_flight (accumulated results, waiting to merge)
	_batches_in_flight[packet_num] = result

	# Check if all packets for this refill are done
	# With adaptive batching, total_packets is always 1 (single variable-size packet per refill)
	if lookahead_batch_queue.is_empty() and _batches_in_flight.size() == total_packets:
		var depth_before = _get_buffer_depth()
		_merge_accumulated_packets()
		_batches_in_flight.clear()
		lookahead_refills += 1
		var depth_after = _get_buffer_depth()

		# Fibonacci adaptation based on buffer state
		if _buffer_state == BufferState.RECOVERY and depth_after < COAST_TARGET:
			# RECOVERY: Escalate if buffer still low
			if _fib_index < FIB_SEQUENCE.size() - 1:
				_fib_index += 1
				_log("debug", "PACKET", "📈", "Fib advance: %d→%d (depth=%d, target=%d)" % [
					_fib_index - 1, _fib_index, depth_after, COAST_TARGET
				])
		elif _buffer_state == BufferState.COAST and depth_after > COAST_TARGET * 3:
			# COAST: De-escalate if buffer consistently too large (3x target)
			# This prevents runaway escalation and excessive batch times
			if _fib_index > 2:  # Never go below fib_index=2 (batch_size=2)
				_fib_index -= 1
				_log("debug", "PACKET", "📉", "Fib de-escalate: %d→%d (depth=%d > 3×target=%d)" % [
					_fib_index + 1, _fib_index, depth_after, COAST_TARGET * 3
				])

		# Log completion
		_log("trace", "PACKET", "✓", "Complete: %.1fms, depth %d→%d, state=%s" % [
			packet_time_ms, depth_before, depth_after, BufferState.keys()[_buffer_state]
		])





func _merge_accumulated_packets() -> void:
	"""Merge all accumulated C++ packet results into the phrame buffers.

	Handles both single-packet (adaptive) and multi-packet (legacy priming) modes.

	IMPORTANT: Results come in ENGINE REGISTRATION ORDER (by biome_id), not
	batcher.biomes order. Uses _engine_id_to_biome to correctly map results
	to biome buffers even after biomes are unregistered from batcher.

	Terminology:
	- phrame = physics/evolution frame (10 Hz)
	- packet = C++ batch result containing N phrames
	"""
	# Build lookup of active biomes (those still in batcher.biomes)
	var active_biome_lookup: Dictionary = {}
	for biome in biomes:
		if _is_valid_biome(biome):
			var biome_name = _get_biome_name(biome)
			active_biome_lookup[biome_name] = biome

	# Get engine biome count for proper result array sizing
	var engine_biome_count = lookahead_engine.get_biome_count() if lookahead_engine else 0

	# Initialize accumulated phrames PER ENGINE BIOME ID (not per batcher.biomes index!)
	var accumulated_frames: Dictionary = {}  # biome_name -> Array
	var accumulated_mi_steps: Dictionary = {}
	var accumulated_bloch_steps: Dictionary = {}
	var accumulated_purity_steps: Dictionary = {}
	var accumulated_position_steps: Dictionary = {}
	var accumulated_velocity_steps: Dictionary = {}

	for engine_id in range(engine_biome_count):
		var biome_name = _engine_id_to_biome.get(engine_id, "")
		if biome_name == "":
			continue
		accumulated_frames[biome_name] = []
		accumulated_mi_steps[biome_name] = []
		accumulated_bloch_steps[biome_name] = []
		accumulated_purity_steps[biome_name] = []
		accumulated_position_steps[biome_name] = []
		accumulated_velocity_steps[biome_name] = []

	# Merge packets in order (sort keys to ensure ordering)
	var packet_nums = _batches_in_flight.keys()
	packet_nums.sort()
	for packet_num in packet_nums:
		var packet_result = _batches_in_flight[packet_num]
		var results = packet_result.get("results", [])
		var mi_steps = packet_result.get("mi_steps", [])
		var bloch_steps = packet_result.get("bloch_steps", [])
		var purity_steps = packet_result.get("purity_steps", [])
		var position_steps = packet_result.get("position_steps", [])
		var velocity_steps = packet_result.get("velocity_steps", [])

		# Results are in ENGINE ORDER (by engine_id), not batcher.biomes order!
		for engine_id in range(mini(results.size(), engine_biome_count)):
			var biome_name = _engine_id_to_biome.get(engine_id, "")
			if biome_name == "" or not accumulated_frames.has(biome_name):
				continue

			if engine_id < results.size():
				accumulated_frames[biome_name].append_array(results[engine_id])
			if engine_id < mi_steps.size():
				accumulated_mi_steps[biome_name].append_array(mi_steps[engine_id])
			if engine_id < bloch_steps.size():
				accumulated_bloch_steps[biome_name].append_array(bloch_steps[engine_id])
			if engine_id < purity_steps.size():
				accumulated_purity_steps[biome_name].append_array(purity_steps[engine_id])
			if engine_id < position_steps.size():
				accumulated_position_steps[biome_name].append_array(position_steps[engine_id])
			if engine_id < velocity_steps.size():
				accumulated_velocity_steps[biome_name].append_array(velocity_steps[engine_id])

	# Distribute to phrame buffers - ONLY for biomes still in batcher.biomes!
	for engine_id in range(engine_biome_count):
		var biome_name = _engine_id_to_biome.get(engine_id, "")
		if biome_name == "":
			continue

		# Skip biomes that have been unregistered from batcher
		if not active_biome_lookup.has(biome_name):
			continue

		var biome = active_biome_lookup[biome_name]
		if not _is_valid_biome(biome):
			continue

		# Check if this biome was marked active in the refill request
		if engine_id < active_flags.size() and active_flags[engine_id]:
			# Get unconsumed phrames from existing buffer using helper
			var unconsumed_frames = _extract_unconsumed_buffer(biome_name, frame_buffers)
			var unconsumed_mi = _extract_unconsumed_buffer(biome_name, mi_buffers)
			var unconsumed_bloch = _extract_unconsumed_buffer(biome_name, bloch_buffers)
			var unconsumed_purity = _extract_unconsumed_buffer(biome_name, purity_buffers)
			var unconsumed_positions = _extract_unconsumed_buffer(biome_name, position_buffers)
			var unconsumed_velocities = _extract_unconsumed_buffer(biome_name, velocity_buffers)

			# APPEND new phrames to unconsumed (don't replace!)
			var new_frames = unconsumed_frames.duplicate()
			new_frames.append_array(accumulated_frames.get(biome_name, []))
			frame_buffers[biome_name] = new_frames
			buffer_cursors[biome_name] = 0  # Reset cursor since we sliced

			var new_mi = unconsumed_mi.duplicate()
			new_mi.append_array(accumulated_mi_steps.get(biome_name, []))
			mi_buffers[biome_name] = new_mi

			var new_bloch = unconsumed_bloch.duplicate()
			new_bloch.append_array(accumulated_bloch_steps.get(biome_name, []))
			bloch_buffers[biome_name] = new_bloch

			var new_purity = unconsumed_purity.duplicate()
			new_purity.append_array(accumulated_purity_steps.get(biome_name, []))
			purity_buffers[biome_name] = new_purity

			# Merge force positions/velocities
			var new_positions = unconsumed_positions.duplicate()
			new_positions.append_array(accumulated_position_steps.get(biome_name, []))
			position_buffers[biome_name] = new_positions

			var new_velocities = unconsumed_velocities.duplicate()
			new_velocities.append_array(accumulated_velocity_steps.get(biome_name, []))
			velocity_buffers[biome_name] = new_velocities
		else:
			# Frozen buffer for inactive biomes
			var qc = biome.quantum_computer
			var rho_packed = qc.density_matrix._to_packed() if qc.density_matrix else PackedFloat64Array()
			frame_buffers[biome_name] = _create_frozen_buffer(rho_packed, LOOKAHEAD_STEPS)
			buffer_cursors[biome_name] = 0

	# Safety cap: prevent buffer overflow from multiple packet accumulation
	var depth_after = _get_minimum_buffer_depth()
	if depth_after > COAST_TARGET * 4:
		if _fib_index > 2:
			var old_fib = _fib_index
			_fib_index -= 2  # Drop by 2 steps for faster correction
			_log("warn", "PACKET", "📉📉", "Buffer overflow: depth=%d > 4×target=%d, fib de-escalate: %d→%d" % [
				depth_after, COAST_TARGET * 4, old_fib, _fib_index
			])



# ============================================================================
# TEST HELPERS - Buffer manipulation for diagnostic tests
# ============================================================================

func drain_buffer_to(target_steps: int) -> void:
	"""Reduce buffer to N steps for starvation recovery test."""
	for biome_name in frame_buffers.keys():
		var buffer = frame_buffers.get(biome_name, [])
		if buffer.size() > target_steps:
			# Keep only first N steps
			var drained = buffer.slice(0, target_steps)
			frame_buffers[biome_name] = drained
			
			# Also drain MI/Bloch buffers
			if mi_buffers.has(biome_name):
				var mi_buf = mi_buffers[biome_name]
				if mi_buf.size() > target_steps:
					mi_buffers[biome_name] = mi_buf.slice(0, target_steps)
			
			if bloch_buffers.has(biome_name):
				var bloch_buf = bloch_buffers[biome_name]
				if bloch_buf.size() > target_steps:
					bloch_buffers[biome_name] = bloch_buf.slice(0, target_steps)
			
			if purity_buffers.has(biome_name):
				var purity_buf = purity_buffers[biome_name]
				if purity_buf.size() > target_steps:
					purity_buffers[biome_name] = purity_buf.slice(0, target_steps)
		
		# Reset cursor to 0
		buffer_cursors[biome_name] = 0
	
	print("[TEST] Buffer drained to %d steps (%.0fms coverage)" % [target_steps, target_steps * 100.0])


func fill_buffer_to(target_steps: int) -> void:
	"""Extend buffer to N steps for coast test (duplicates current state)."""
	for biome in biomes:
		if not _is_valid_biome(biome):
			continue

		var biome_name = _get_biome_name(biome)
		var buffer = frame_buffers.get(biome_name, [])
		
		if buffer.is_empty():
			continue
		
		# Duplicate last step to reach target size
		var last_step = buffer[buffer.size() - 1]
		while buffer.size() < target_steps:
			buffer.append(last_step)
		
		frame_buffers[biome_name] = buffer
		
		# Also extend MI/Bloch buffers
		if mi_buffers.has(biome_name):
			var mi_buf = mi_buffers[biome_name]
			if not mi_buf.is_empty():
				var last_mi = mi_buf[mi_buf.size() - 1]
				while mi_buf.size() < target_steps:
					mi_buf.append(last_mi)
				mi_buffers[biome_name] = mi_buf
		
		if bloch_buffers.has(biome_name):
			var bloch_buf = bloch_buffers[biome_name]
			if not bloch_buf.is_empty():
				var last_bloch = bloch_buf[bloch_buf.size() - 1]
				while bloch_buf.size() < target_steps:
					bloch_buf.append(last_bloch)
				bloch_buffers[biome_name] = bloch_buf
		
		if purity_buffers.has(biome_name):
			var purity_buf = purity_buffers[biome_name]
			if not purity_buf.is_empty():
				var last_purity = purity_buf[purity_buf.size() - 1]
				while purity_buf.size() < target_steps:
					purity_buf.append(last_purity)
				purity_buffers[biome_name] = purity_buf
		
		# Reset cursor to 0
		buffer_cursors[biome_name] = 0
	
	print("[TEST] Buffer filled to %d steps (%.0fms coverage)" % [target_steps, target_steps * 100.0])


func set_evolution_paused(paused: bool) -> void:
	"""Pause/unpause evolution for coast test."""
	lookahead_enabled = not paused
	if paused:
		print("[TEST] Evolution PAUSED - coasting on buffer")
	else:
		print("[TEST] Evolution RESUMED")
