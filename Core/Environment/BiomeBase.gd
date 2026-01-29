class_name BiomeBase
extends Node

# Access autoloads safely (avoids compile-time errors)
@onready var _icon_registry = get_node("/root/IconRegistry")
@onready var _verbose = get_node("/root/VerboseConfig")

## Abstract base class for all biomes (Model C - Unified QuantumComputer)
##
## Model C: Biome owns ONE canonical quantum state (QuantumComputer).
## Plots are hardware attachments (RegisterIds) that reference it.
## No per-plot independent quantum states.
##
## Architecture: Composition with Facade
## BiomeBase delegates to 7 composable components while maintaining
## the same public API for backward compatibility with subclasses.

# Component imports
const BiomeResourceRegistry = preload("res://Core/Environment/Components/BiomeResourceRegistry.gd")
const BiomeBellGateTracker = preload("res://Core/Environment/Components/BiomeBellGateTracker.gd")
const BiomeQuantumObserver = preload("res://Core/Environment/Components/BiomeQuantumObserver.gd")
const BiomeGateOperations = preload("res://Core/Environment/Components/BiomeGateOperations.gd")
const BiomeQuantumSystemBuilder = preload("res://Core/Environment/Components/BiomeQuantumSystemBuilder.gd")
const BiomeDensityMatrixMutator = preload("res://Core/Environment/Components/BiomeDensityMatrixMutator.gd")

# Core imports
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const QuantumRegister = preload("res://Core/QuantumSubstrate/QuantumRegister.gd")
const QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
# QuantumGateLibrary - moved to BiomeGateOperations component
const BiomeUtilities = preload("res://Core/Environment/BiomeUtilities.gd")
const BiomeTimeTracker = preload("res://Core/Environment/BiomeTimeTracker.gd")
const BiomeDynamicsTracker = preload("res://Core/QuantumSubstrate/BiomeDynamicsTracker.gd")
const StrangeAttractorAnalyzer = preload("res://Core/QuantumSubstrate/StrangeAttractorAnalyzer.gd")
# Icon - accessed via _icon_registry autoload
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
# DensityMatrix - accessed via quantum_computer
# EconomyConstants - unused, economy handled by EconomyManager
const SemanticDrift = preload("res://Core/QuantumSubstrate/SemanticDrift.gd")

# ============================================================================
# COMPONENT INSTANCES
# ============================================================================

var _resource_registry: BiomeResourceRegistry
var _bell_gate_tracker: BiomeBellGateTracker
var _quantum_observer: BiomeQuantumObserver
var _gate_operations: BiomeGateOperations
var _system_builder: BiomeQuantumSystemBuilder
var _density_mutator: BiomeDensityMatrixMutator

# ============================================================================
# CORE STATE (remains in BiomeBase)
# ============================================================================

# Common infrastructure
var time_tracker: BiomeTimeTracker = BiomeTimeTracker.new()
var dynamics_tracker: BiomeDynamicsTracker = null
var attractor_analyzer: StrangeAttractorAnalyzer = null
var grid = null  # Injected FarmGrid reference

# Central quantum state manager for this biome (ONLY source of truth)
var quantum_computer = null  # QuantumComputer type

# Active projections (legacy - to be removed)
var active_projections: Dictionary = {}

# Visual Properties for QuantumForceGraph rendering
var visual_color: Color = Color(0.5, 0.5, 0.5, 0.3)
var visual_label: String = ""
var visual_center_offset: Vector2 = Vector2.ZERO
var visual_circle_radius: float = 150.0
var visual_enabled: bool = true
var visual_oval_width: float = 300.0
var visual_oval_height: float = 185.0

# Signals - common interface for all biomes
signal qubit_created(position: Vector2i, qubit: Resource)
signal qubit_measured(position: Vector2i, outcome: String)
signal qubit_evolved(position: Vector2i)
signal coupling_updated(emoji_a: String, emoji_b: String, strength: float)
signal bell_gate_created(positions: Array)
signal resource_registered(emoji: String, is_producible: bool, is_consumable: bool)

# Initialization guards
var _is_initialized: bool = false
var _qc_recovery_attempted: bool = false
var _qc_missing_warned: bool = false

# Performance: Control quantum evolution frequency
var quantum_evolution_accumulator: float = 0.0
var quantum_evolution_timestep: float = 0.1  # Physics update rate: 10 Hz
var quantum_evolution_enabled: bool = true

# Quantum time scaling (affects simulation speed without changing render rate)
# Lower = slower simulation, higher = faster simulation
# 1.0 = real-time, 0.5 = half-speed, 2.0 = double-speed
var quantum_time_scale: float = 0.125  # Default to 1/8th real-time for detailed observation

# Matrix substep granularity (controls numerical accuracy of evolution)
# Smaller = more substeps = better accuracy but slower computation
# Larger = fewer substeps = faster but less accurate
# Range: 0.005 (very fine) to 0.05 (coarse)
var max_evolution_dt: float = 0.02  # Default substep size

# BUILD mode pause
var evolution_paused: bool = false

# Idle optimization
var is_idle: bool = false

# ============================================================================
# FACADE PROPERTY ACCESSORS (for backward compatibility)
# ============================================================================

# Forward property access to components for backward compatibility
var bell_gates: Array:
	get: return _bell_gate_tracker.bell_gates if _bell_gate_tracker else []
	set(v): if _bell_gate_tracker: _bell_gate_tracker.bell_gates = v

var producible_emojis: Array[String]:
	get: return _resource_registry.producible_emojis if _resource_registry else []
	set(v): if _resource_registry: _resource_registry.producible_emojis = v

var consumable_emojis: Array[String]:
	get: return _resource_registry.consumable_emojis if _resource_registry else []
	set(v): if _resource_registry: _resource_registry.consumable_emojis = v

var emoji_pairings: Dictionary:
	get: return _resource_registry.emoji_pairings if _resource_registry else {}
	set(v): if _resource_registry: _resource_registry.emoji_pairings = v

var planting_capabilities: Array:
	get: return _resource_registry.planting_capabilities if _resource_registry else []
	set(v): if _resource_registry: _resource_registry.planting_capabilities = v

# PlantingCapability alias for backward compatibility (static const)
const PlantingCapability = BiomeResourceRegistry.PlantingCapability

# ============================================================================
# INITIALIZATION
# ============================================================================

func _verbose_log(level: String, category: String, emoji: String, message: String) -> void:
	"""Safely log to VerboseConfig if available"""
	if not has_node("/root/VerboseConfig"):
		return
	var logger = get_node("/root/VerboseConfig")
	match level:
		"debug": logger.debug(category, emoji, message)
		"info": logger.info(category, emoji, message)
		"warn": logger.warn(category, emoji, message)
		"error": logger.error(category, emoji, message)


func _ready() -> void:
	"""Initialize biome - called by Godot when node enters scene tree"""
	if _is_initialized:
		return
	_is_initialized = true

	# Initialize components
	_resource_registry = BiomeResourceRegistry.new()
	_bell_gate_tracker = BiomeBellGateTracker.new()
	_quantum_observer = BiomeQuantumObserver.new()
	_gate_operations = BiomeGateOperations.new()
	_system_builder = BiomeQuantumSystemBuilder.new()
	_density_mutator = BiomeDensityMatrixMutator.new()

	# Forward signals from components FIRST (before _initialize_bath emits signals)
	_bell_gate_tracker.bell_gate_created.connect(_on_bell_gate_created)
	_resource_registry.resource_registered.connect(_on_resource_registered)
	_system_builder.coupling_updated.connect(_on_coupling_updated)

	# Initialize biome-specific quantum computer via virtual method
	# NOTE: Subclasses like BioticFluxBiome create their own quantum_computer here
	_initialize_bath()

	# Wire component dependencies AFTER _initialize_bath() creates the real quantum_computer
	if quantum_computer:
		_quantum_observer.set_quantum_computer(quantum_computer)
		_density_mutator.set_quantum_computer(quantum_computer)

	# Initialize strange attractor tracking
	_initialize_attractor_tracking()

	# Processing will be enabled by BootManager
	set_process(false)


func _wire_component_dependencies() -> void:
	"""Wire dependencies for components that need IconRegistry (call after _ready)"""
	_system_builder.set_dependencies(quantum_computer, _resource_registry, _icon_registry)
	_gate_operations.set_dependencies(quantum_computer, null, _bell_gate_tracker, time_tracker)
	_gate_operations.set_verbose_log_callback(_verbose_log)


# ============================================================================
# SIGNAL FORWARDING (from components to BiomeBase)
# ============================================================================

func _on_bell_gate_created(positions: Array) -> void:
	bell_gate_created.emit(positions)

func _on_resource_registered(emoji: String, is_producible: bool, is_consumable: bool) -> void:
	resource_registered.emit(emoji, is_producible, is_consumable)

func _on_coupling_updated(emoji_a: String, emoji_b: String, strength: float) -> void:
	coupling_updated.emit(emoji_a, emoji_b, strength)


# ============================================================================
# MAIN PROCESS LOOP
# ============================================================================

func _process(delta: float) -> void:
	if not _is_initialized:
		return

	# Check if batched evolution is enabled (BiomeEvolutionBatcher handles evolution)
	if get_meta("batched_evolution", false):
		# Batcher handles quantum evolution
		# Only update time tracker here for UI and drift mechanics
		time_tracker.update(delta)
		return

	if quantum_evolution_enabled:
		quantum_evolution_accumulator += delta
		if quantum_evolution_accumulator >= quantum_evolution_timestep:
			var t0 = Time.get_ticks_usec()
			# Apply quantum_time_scale to slow down/speed up simulation
			var actual_dt = quantum_evolution_accumulator * quantum_time_scale
			quantum_evolution_accumulator = 0.0

			if _ensure_quantum_computer():
				_update_quantum_substrate(actual_dt)
				var t1 = Time.get_ticks_usec()
				if Engine.get_process_frames() % 60 == 0:
					_verbose.trace("biome", "⏱️", "Biome %s Substrate Update: %d us" % [name, t1 - t0])
				
				if not dynamics_tracker:
					dynamics_tracker = BiomeDynamicsTracker.new()
				if dynamics_tracker:
					_track_dynamics()


func _ensure_quantum_computer() -> bool:
	"""Ensure quantum_computer exists"""
	if quantum_computer:
		_qc_recovery_attempted = false
		_qc_missing_warned = false
		return true

	if not _qc_recovery_attempted:
		_qc_recovery_attempted = true
		quantum_computer = QuantumComputer.new(get_biome_type())
		_initialize_bath()

	if not quantum_computer and not _qc_missing_warned:
		push_warning("Biome %s has no quantum_computer" % get_biome_type())
		_qc_missing_warned = true

	return quantum_computer != null


func _update_quantum_substrate(dt: float) -> void:
	"""Virtual method: Override for Model C evolution"""
	_apply_semantic_drift(dt)


func _apply_semantic_drift(dt: float) -> void:
	"""Apply semantic drift based on 🌀 population"""
	if not _icon_registry:
		return
	if quantum_computer:
		SemanticDrift.apply_drift(quantum_computer, _icon_registry, dt)


func get_drift_status() -> Dictionary:
	"""Get current semantic drift status for UI display"""
	if not quantum_computer:
		return {"active": false, "intensity": 0.0, "status_text": "No quantum state"}
	return {
		"active": SemanticDrift.is_drift_active(quantum_computer),
		"intensity": SemanticDrift.get_drift_intensity(quantum_computer),
		"status_text": SemanticDrift.get_drift_status(quantum_computer)
	}


# ============================================================================
# EVOLUTION CONTROL
# ============================================================================

func set_evolution_paused(paused: bool) -> void:
	if evolution_paused == paused:
		return
	evolution_paused = paused
	if paused:
		print("⏸️ %s: Quantum evolution PAUSED (BUILD mode)" % get_biome_type())
	else:
		print("▶️ %s: Quantum evolution RESUMED (PLAY mode)" % get_biome_type())


func is_evolution_paused() -> bool:
	return evolution_paused


# ============================================================================
# FACADE: Resource Registry Methods
# ============================================================================

func register_resource(emoji: String, is_producible: bool = true, is_consumable: bool = false) -> void:
	_resource_registry.register_resource(emoji, is_producible, is_consumable)

func register_emoji_pair(north: String, south: String) -> void:
	_resource_registry.register_emoji_pair(north, south)

func register_planting_capability(north: String, south: String, plant_type: String,
                                   cost: Dictionary, display_name: String = "",
                                   exclusive: bool = false) -> void:
	_resource_registry.register_planting_capability(north, south, plant_type, cost, display_name, exclusive)

func get_plantable_capabilities() -> Array:
	return _resource_registry.get_plantable_capabilities()

func get_planting_cost(plant_type: String) -> Dictionary:
	return _resource_registry.get_planting_cost(plant_type)

func supports_plant_type(plant_type: String) -> bool:
	return _resource_registry.supports_plant_type(plant_type)

func get_producible_emojis() -> Array[String]:
	return _resource_registry.get_producible_emojis()

func get_consumable_emojis() -> Array[String]:
	return _resource_registry.get_consumable_emojis()

func get_emoji_pairings() -> Dictionary:
	return _resource_registry.get_emoji_pairings()

func can_produce(emoji: String) -> bool:
	return _resource_registry.can_produce(emoji)

func can_consume(emoji: String) -> bool:
	return _resource_registry.can_consume(emoji)

func supports_emoji_pair(north: String, south: String) -> bool:
	return _resource_registry.supports_emoji_pair(north, south, quantum_computer)

func get_harvestable_emojis() -> Array[String]:
	return _resource_registry.get_harvestable_emojis()


# ============================================================================
# FACADE: Bell Gate Tracker Methods
# ============================================================================

func mark_bell_gate(positions: Array) -> void:
	_bell_gate_tracker.mark_bell_gate(positions)

func get_bell_gate(index: int) -> Array:
	return _bell_gate_tracker.get_bell_gate(index)

func get_all_bell_gates() -> Array:
	return _bell_gate_tracker.get_all_bell_gates()

func get_bell_gates_of_size(size: int) -> Array:
	return _bell_gate_tracker.get_bell_gates_of_size(size)

func get_triplet_bell_gates() -> Array:
	return _bell_gate_tracker.get_triplet_bell_gates()

func get_pair_bell_gates() -> Array:
	return _bell_gate_tracker.get_pair_bell_gates()

func has_bell_gates() -> bool:
	return _bell_gate_tracker.has_bell_gates()

func bell_gate_count() -> int:
	return _bell_gate_tracker.bell_gate_count()


# ============================================================================
# FACADE: Quantum Observer Methods
# ============================================================================

func get_observable_theta(north: String, south: String) -> float:
	return _quantum_observer.get_observable_theta(north, south)

func get_observable_phi(north: String, south: String) -> float:
	return _quantum_observer.get_observable_phi(north, south)

func get_observable_coherence(north: String, south: String) -> float:
	return _quantum_observer.get_observable_coherence(north, south)

func get_observable_radius(north: String, south: String) -> float:
	return _quantum_observer.get_observable_radius(north, south)

func get_observable_amplitude(emoji: String) -> float:
	return _quantum_observer.get_observable_amplitude(emoji)

func get_observable_phase(emoji: String) -> float:
	return _quantum_observer.get_observable_phase(emoji)

func get_emoji_probability(emoji: String) -> float:
	return _quantum_observer.get_emoji_probability(emoji)

func get_emoji_coherence(north_emoji: String, south_emoji: String):
	return _quantum_observer.get_emoji_coherence(north_emoji, south_emoji)

func get_purity() -> float:
	return _quantum_observer.get_purity()

func get_register_emoji_pair(register_id: int) -> Dictionary:
	return _quantum_observer.get_register_emoji_pair(register_id)

func get_coherence_with_other_registers(register_id: int) -> float:
	return _quantum_observer.get_coherence_with_other_registers(register_id)


# ============================================================================
# FACADE: Plot Register Manager Methods
# ============================================================================

## Get register probability for a specific register ID
func get_register_probability(register_id: int) -> float:
	return _quantum_observer.get_register_probability(register_id)

## Get all unbound register IDs (available for new terminal binding)
func get_unbound_registers(plot_pool = null) -> Array[int]:
	"""Get all register IDs not currently bound to a terminal."""
	if not quantum_computer or not quantum_computer.register_map:
		return []

	var num_qubits = quantum_computer.register_map.num_qubits
	var unbound: Array[int] = []
	var biome_name = get_biome_type() if has_method("get_biome_type") else ""

	for reg_id in range(num_qubits):
		if not plot_pool or not plot_pool.is_register_bound(reg_id, biome_name):
			unbound.append(reg_id)

	return unbound

## Get probability distribution over all unbound registers
func get_register_probabilities(plot_pool = null) -> Dictionary:
	"""Get probability distribution for weighted register selection."""
	var probs: Dictionary = {}
	var unbound = get_unbound_registers(plot_pool)

	for reg_id in unbound:
		if _quantum_observer:
			probs[reg_id] = _quantum_observer.get_register_probability(reg_id)
		else:
			probs[reg_id] = 0.5

	return probs

## Get total number of registers in this biome
func get_total_register_count() -> int:
	if not quantum_computer or not quantum_computer.register_map:
		return 0
	return quantum_computer.register_map.num_qubits

## Get registers not currently bound to any terminal (V2 Architecture)
func get_available_registers_v2(plot_pool) -> Array[int]:
	"""Get unbound registers for EXPLORE action."""
	return get_unbound_registers(plot_pool)


# ============================================================================
# FACADE: Gate Operations Methods
# ============================================================================

func apply_gate_1q(position: Vector2i, gate_name: String) -> bool:
	_wire_component_dependencies()
	return _gate_operations.apply_gate_1q(position, gate_name)

func apply_gate_2q(position_a: Vector2i, position_b: Vector2i, gate_name: String) -> bool:
	_wire_component_dependencies()
	return _gate_operations.apply_gate_2q(position_a, position_b, gate_name)

func entangle_plots(position_a: Vector2i, position_b: Vector2i) -> bool:
	_wire_component_dependencies()
	return _gate_operations.entangle_plots(position_a, position_b)

func create_cluster_state(positions: Array[Vector2i]) -> bool:
	_wire_component_dependencies()
	return _gate_operations.create_cluster_state(positions)

func batch_entangle(positions: Array[Vector2i]) -> bool:
	_wire_component_dependencies()
	return _gate_operations.batch_entangle(positions)

func set_measurement_trigger(trigger_pos: Vector2i, target_positions: Array[Vector2i]) -> bool:
	_wire_component_dependencies()
	return _gate_operations.set_measurement_trigger(trigger_pos, target_positions)

func remove_entanglement(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	_wire_component_dependencies()
	return _gate_operations.remove_entanglement(pos_a, pos_b)

func batch_measure_plots(position: Vector2i) -> Dictionary:
	_wire_component_dependencies()
	return _gate_operations.batch_measure_plots(position, func(pos, outcome): qubit_measured.emit(pos, outcome))


# ============================================================================
# FACADE: Quantum System Builder Methods
# ============================================================================

func expand_quantum_system(north_emoji: String, south_emoji: String) -> Dictionary:
	_wire_component_dependencies()
	return _system_builder.expand_quantum_system(north_emoji, south_emoji)

func inject_coupling(emoji_a: String, emoji_b: String, strength: float) -> Dictionary:
	_wire_component_dependencies()
	return _system_builder.inject_coupling(emoji_a, emoji_b, strength)

func build_operators_cached(biome_name: String, icons: Dictionary) -> void:
	_wire_component_dependencies()
	_system_builder.build_operators_cached(biome_name, icons)


# ============================================================================
# FACADE: Density Matrix Mutator Methods
# ============================================================================

func collapse_register(register_id: int, is_north: bool) -> void:
	_density_mutator.collapse_register(register_id, is_north)

func drain_register_probability(register_id: int, is_north: bool, drain_factor: float) -> void:
	_density_mutator.drain_register_probability(register_id, is_north, drain_factor)


# ============================================================================
# QUANTUM OPERATIONS
# ============================================================================

func boost_coupling(emoji: String, target_emoji: String, factor: float = 1.5) -> bool:
	var result = inject_coupling(emoji, target_emoji, factor)
	return result.get("success", false)


# ============================================================================
# PROJECTIONS (Legacy Support)
# ============================================================================

func create_projection(position: Vector2i, north: String, south: String) -> Resource:
	var qubit = DualEmojiQubit.new(north, south, PI/2.0, null)
	qubit.plot_position = position
	active_projections[position] = {"qubit": qubit, "north": north, "south": south}
	qubit_created.emit(position, qubit)
	return qubit

func update_projections(_dt: float = 0.016) -> void:
	for position in active_projections:
		qubit_evolved.emit(position)

func measure_projection(position: Vector2i) -> String:
	if not active_projections.has(position):
		return ""
	var data = active_projections[position]
	var outcome = ""
	if quantum_computer:
		outcome = quantum_computer.measure_axis(data.north, data.south)
	else:
		outcome = data.north if randf() < 0.5 else data.south
	update_projections()
	qubit_measured.emit(position, outcome)
	return outcome

func remove_projection(position: Vector2i) -> void:
	active_projections.erase(position)

func get_projection_qubit(position: Vector2i) -> Resource:
	if active_projections.has(position):
		return active_projections[position].qubit
	return null


# ============================================================================
# BATH INITIALIZATION (Virtual - Override in subclasses)
# ============================================================================

func _initialize_bath() -> void:
	"""Override in subclasses to set up the quantum computer."""
	pass

func rebuild_quantum_operators() -> void:
	"""Rebuild Hamiltonian operators (call after IconRegistry is ready)"""
	if quantum_computer:
		_rebuild_quantum_operators_impl()

func _rebuild_quantum_operators_impl() -> void:
	"""Override in child classes"""
	pass


# ============================================================================
# STATUS & DEBUG
# ============================================================================

func get_status() -> Dictionary:
	var quantum_size = 0
	if quantum_computer and quantum_computer.register_map:
		quantum_size = quantum_computer.register_map.num_qubits
	return BiomeUtilities.create_status_dict({
		"type": get_biome_type(),
		"qubits": quantum_size,
		"time": time_tracker.time_elapsed,
		"cycles": time_tracker.cycle_count
	})

func get_biome_type() -> String:
	return "Base"

func get_visual_config() -> Dictionary:
	return {
		"color": visual_color,
		"label": visual_label if visual_label != "" else get_biome_type(),
		"center_offset": visual_center_offset,
		"circle_radius": visual_circle_radius,
		"oval_width": visual_oval_width,
		"oval_height": visual_oval_height,
		"enabled": visual_enabled
	}

func render_biome_content(graph: Node2D, center: Vector2, radius: float) -> void:
	pass

func get_plot_positions_in_oval(plot_count: int, center: Vector2, viewport_scale: float = 1.0) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if plot_count == 0:
		return positions

	var semi_a = (visual_oval_width * viewport_scale) / 2.0
	var semi_b = (visual_oval_height * viewport_scale) / 2.0
	var rings = max(1, ceil(sqrt(float(plot_count) / 3.0)))
	var plots_per_ring = []
	var remaining = plot_count

	for ring_idx in range(rings):
		var plots_in_ring = int(ceil(float(remaining) / float(rings - ring_idx)))
		plots_per_ring.append(plots_in_ring)
		remaining -= plots_in_ring

	var ring_idx = 0
	for num_plots in plots_per_ring:
		var scale = 0.3 + (0.6 * float(ring_idx) / float(max(1, rings - 1)))
		for plot_in_ring in range(num_plots):
			var t = (float(plot_in_ring) / float(num_plots)) * TAU
			var x = center.x + semi_a * cos(t) * scale
			var y = center.y + semi_b * sin(t) * scale
			positions.append(Vector2(x, y))
		ring_idx += 1

	positions.sort_custom(func(a, b): return a.x < b.x)
	return positions


# ============================================================================
# DYNAMICS TRACKING
# ============================================================================

func _track_dynamics() -> void:
	if not quantum_computer or not dynamics_tracker:
		return
	var purity = quantum_computer.get_purity() if quantum_computer.has_method("get_purity") else 0.5
	var entropy = _calculate_quantum_entropy()
	var coherence = _calculate_quantum_coherence()
	dynamics_tracker.add_snapshot({"purity": purity, "entropy": entropy, "coherence": coherence})

func _calculate_quantum_entropy() -> float:
	if not quantum_computer or not quantum_computer.density_matrix:
		return 0.5
	var purity = quantum_computer.get_purity() if quantum_computer.has_method("get_purity") else 0.5
	var dim = quantum_computer.density_matrix.dimension() if quantum_computer.density_matrix.has_method("dimension") else 1
	if purity <= 0 or dim <= 1:
		return 0.0
	var max_entropy = log(dim)
	if max_entropy <= 0:
		return 0.0
	return clamp(-log(purity) / max_entropy, 0.0, 1.0)

func _calculate_quantum_coherence() -> float:
	if not quantum_computer or not quantum_computer.density_matrix:
		return 0.0
	var dm = quantum_computer.density_matrix
	var dim = dm.dimension() if dm.has_method("dimension") else 0
	if dim < 2:
		return 0.0
	var mat = dm.get_matrix() if dm.has_method("get_matrix") else null
	if not mat:
		return 0.0
	var total = 0.0
	for i in range(dim):
		for j in range(dim):
			if i != j:
				var element = mat.get_element(i, j)
				if element:
					total += element.re * element.re + element.im * element.im
	var max_coherence = float(dim * (dim - 1))
	return clamp(total / max_coherence, 0.0, 1.0) if max_coherence > 0 else 0.0


# ============================================================================
# STRANGE ATTRACTOR ANALYSIS
# ============================================================================

func _initialize_attractor_tracking() -> void:
	attractor_analyzer = StrangeAttractorAnalyzer.new()
	var key_emojis = _select_key_emojis_for_attractor()
	if key_emojis.size() >= 3:
		attractor_analyzer.initialize(key_emojis)
		_verbose_log("info", "attractor", "📊", "%s: Attractor tracking %s" % [get_biome_type(), str(key_emojis)])
	else:
		push_warning("BiomeBase: Insufficient emojis for attractor tracking (%d < 3)" % key_emojis.size())

func _select_key_emojis_for_attractor() -> Array[String]:
	var emojis: Array[String] = []
	if quantum_computer and quantum_computer.register_map:
		var emoji_list = quantum_computer.register_map.coordinates.keys()
		for i in range(min(3, emoji_list.size())):
			emojis.append(emoji_list[i])
	return emojis

func _record_attractor_snapshot() -> void:
	if not attractor_analyzer:
		return
	var observables: Dictionary = {}
	if quantum_computer and quantum_computer.density_matrix:
		observables = quantum_computer.get_all_populations()
	if not observables.is_empty():
		attractor_analyzer.record_snapshot(observables)


# ============================================================================
# RESET & LIFECYCLE
# ============================================================================

func reset() -> void:
	if quantum_computer:
		quantum_computer.clear()
	active_projections.clear()
	if _bell_gate_tracker:
		_bell_gate_tracker.clear()
	time_tracker.reset()
	if dynamics_tracker:
		dynamics_tracker.clear_history()
	_reset_custom()

func _reset_custom() -> void:
	pass


# ============================================================================
# VECTOR HARVEST OPERATIONS
# ============================================================================

func harvest_all_plots() -> Array:
	if not grid:
		push_warning("BiomeBase.harvest_all_plots(): No grid reference")
		return []

	var results: Array = []
	for position in active_projections.keys():
		var plot = grid.get_plot(position)
		if plot and plot.is_planted:
			var result = plot.harvest()
			results.append(result)
			_verbose_log("debug", "farm", "📍", "Harvested plot at %s: yield=%d" % [position, result.get("yield", 0)])

	var total_yield = 0
	var successful_harvests = 0
	for result in results:
		if result.get("success", false):
			successful_harvests += 1
			total_yield += result.get("yield", 0)

	_verbose_log("info", "farm", "✂️", "BiomeBase.harvest_all_plots(): %d harvested, %d credits total" % [successful_harvests, total_yield])
	return results


# NOTE: Energy tap system removed (2026-01) - was half-disabled and confusing
# Use plot-based quantum measurement + economy credits instead
