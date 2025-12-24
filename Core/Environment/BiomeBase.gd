class_name BiomeBase
extends Node

## Abstract base class for all biomes
## Provides shared infrastructure for quantum evolution without enforcing specific physics
## All 8 biome implementations extend this class

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const BiomeUtilities = preload("res://Core/Environment/BiomeUtilities.gd")
const BiomeTimeTracker = preload("res://Core/Environment/BiomeTimeTracker.gd")

# Common infrastructure
var time_tracker: BiomeTimeTracker = BiomeTimeTracker.new()
var quantum_states: Dictionary = {}  # Vector2i -> DualEmojiQubit
var grid = null  # Injected FarmGrid reference

# Visual Properties for QuantumForceGraph rendering
var visual_color: Color = Color(0.5, 0.5, 0.5, 0.3)  # Default gray
var visual_label: String = ""  # Display name with emoji (defaults to get_biome_type())
var visual_center_offset: Vector2 = Vector2.ZERO  # Position offset in graph
var visual_circle_radius: float = 150.0  # Circle radius override
var visual_enabled: bool = true  # Whether to show in force graph

# Oval shape properties for QuantumForceGraph rendering
var visual_oval_width: float = 300.0   # Horizontal semi-axis (a)
var visual_oval_height: float = 185.0  # Vertical semi-axis (b) - golden ratio: 300/1.618

# Bell Gates: Historical entanglement relationships
# Tracks which plots have been entangled together in the past
# Structure: Array of [pos1, pos2, pos3] triplets (for kitchen) or [pos1, pos2] pairs (for 2-qubit)
var bell_gates: Array = []  # Array of Vector2i arrays (triplets or pairs)

# Signals - common interface for all biomes
signal qubit_created(position: Vector2i, qubit: Resource)
signal qubit_measured(position: Vector2i, outcome: String)
signal qubit_evolved(position: Vector2i)
signal bell_gate_created(positions: Array)  # New: emitted when plots are entangled

# HAUNTED UI FIX: Prevent double-initialization when _ready() called multiple times
var _is_initialized: bool = false


func _ready() -> void:
	"""Initialize biome - called by Godot when node enters scene tree"""
	# Guard: Only initialize once (prevents double-init from manual calls)
	if _is_initialized:
		return
	_is_initialized = true
	set_process(true)


func _process(dt: float) -> void:
	"""Main process loop - delegates to biome-specific evolution"""
	time_tracker.update(dt)
	_update_quantum_substrate(dt)


func _update_quantum_substrate(dt: float) -> void:
	"""Override in subclasses to define biome-specific quantum evolution"""
	pass


# ============================================================================
# Common Quantum Operations
# ============================================================================

func create_quantum_state(position: Vector2i, north: String, south: String, theta: float = PI/2) -> Resource:
	"""Create and store a quantum state at grid position"""
	var qubit = BiomeUtilities.create_qubit(north, south, theta)
	quantum_states[position] = qubit
	qubit_created.emit(position, qubit)
	return qubit


func get_qubit(position: Vector2i) -> Resource:
	"""Retrieve quantum state at position"""
	return quantum_states.get(position)


func measure_qubit(position: Vector2i) -> String:
	"""Measure (collapse) quantum state at position"""
	var qubit = quantum_states.get(position)
	if not qubit:
		return ""
	var outcome = qubit.measure()
	qubit_measured.emit(position, outcome)
	return outcome


func clear_qubit(position: Vector2i) -> void:
	"""Remove quantum state at position"""
	if position in quantum_states:
		quantum_states.erase(position)


# ============================================================================
# Bell Gates - Historical Entanglement Relationships
# ============================================================================

func mark_bell_gate(positions: Array) -> void:
	"""
	Mark plots as having been entangled (creates a Bell gate)

	This records the historical relationship - even if plots are no longer
	entangled now, they can be used as a measurement target later.

	NOTE: Biome subclasses can override to apply energy boosts to entangled qubits.

	Args:
		positions: [Vector2i, Vector2i] for 2-qubit OR [Vector2i, Vector2i, Vector2i] for 3-qubit
	"""
	if positions.size() < 2:
		push_error("Bell gate requires at least 2 positions")
		return

	# Check if this exact gate already exists
	for existing_gate in bell_gates:
		if _gates_equal(existing_gate, positions):
			return  # Already recorded

	bell_gates.append(positions.duplicate())
	bell_gate_created.emit(positions)

	print("🔔 Bell gate created at biome %s: %s" % [get_biome_type(), _format_positions(positions)])


func get_bell_gate(index: int) -> Array:
	"""Get a specific Bell gate by index"""
	if index >= 0 and index < bell_gates.size():
		return bell_gates[index]
	return []


func get_all_bell_gates() -> Array:
	"""Get all Bell gates in this biome"""
	return bell_gates.duplicate()


func get_bell_gates_of_size(size: int) -> Array:
	"""Get all Bell gates with specific size (2 for pairs, 3 for triplets)"""
	var filtered = []
	for gate in bell_gates:
		if gate.size() == size:
			filtered.append(gate)
	return filtered


func get_triplet_bell_gates() -> Array:
	"""Get all 3-qubit Bell gates (for kitchen use)"""
	return get_bell_gates_of_size(3)


func get_pair_bell_gates() -> Array:
	"""Get all 2-qubit Bell gates"""
	return get_bell_gates_of_size(2)


func has_bell_gates() -> bool:
	"""Check if any Bell gates exist"""
	return bell_gates.size() > 0


func bell_gate_count() -> int:
	"""Get number of Bell gates"""
	return bell_gates.size()


# ============================================================================
# Status & Debug
# ============================================================================

func get_status() -> Dictionary:
	"""Get current biome status (override to add custom fields)"""
	return BiomeUtilities.create_status_dict({
		"type": get_biome_type(),
		"qubits": quantum_states.size(),
		"time": time_tracker.time_elapsed,
		"cycles": time_tracker.cycle_count
	})


func get_biome_type() -> String:
	"""Override in subclasses to return biome type name"""
	return "Base"


func get_visual_config() -> Dictionary:
	"""Get visual configuration for QuantumForceGraph rendering

	Override to customize appearance (or set visual_* properties in _ready())

	Returns: {color, label, center_offset, circle_radius, oval_width, oval_height, enabled}
	"""
	return {
		"color": visual_color,
		"label": visual_label if visual_label != "" else get_biome_type(),
		"center_offset": visual_center_offset,
		"circle_radius": visual_circle_radius,  # LEGACY - kept for compatibility
		"oval_width": visual_oval_width,
		"oval_height": visual_oval_height,
		"enabled": visual_enabled
	}


func render_biome_content(graph: Node2D, center: Vector2, radius: float) -> void:
	"""Render custom biome-specific content inside biome region circle

	Override in subclasses to draw custom visualizations.
	Called during QuantumForceGraph._draw() for each biome.

	Args:
		graph: QuantumForceGraph instance (access to draw_* methods)
		center: Screen position of biome circle center
		radius: Radius of the biome circle

	Default: does nothing (generic biomes have no custom rendering)
	"""
	pass  # Subclasses override to add custom drawing


func get_plot_positions_in_oval(plot_count: int, center: Vector2, viewport_scale: float = 1.0) -> Array[Vector2]:
	"""Calculate parametric ring pattern positions for plots within this biome's oval

	Returns Array[Vector2] of screen positions arranged in concentric oval rings.
	Uses golden ratio proportions (visual_oval_width : visual_oval_height)

	Args:
		plot_count: Number of plots to position
		center: Center point of the biome oval
		viewport_scale: Scale factor based on graph_radius (default 1.0 for no scaling)

	Returns: Array of screen positions for each plot
	"""
	var positions: Array[Vector2] = []

	if plot_count == 0:
		return positions

	# Apply viewport scaling to oval dimensions for consistency with rendering
	var scaled_oval_width = visual_oval_width * viewport_scale
	var scaled_oval_height = visual_oval_height * viewport_scale

	# Calculate number of rings needed (inner to outer)
	# Rule: innermost ring has 1-3 plots, each ring adds ~6 plots
	var rings = max(1, ceil(sqrt(float(plot_count) / 3.0)))
	var plots_per_ring = []
	var remaining = plot_count

	# Distribute plots across rings (outer rings have more plots)
	for ring_idx in range(rings):
		var plots_in_ring = int(ceil(float(remaining) / float(rings - ring_idx)))
		plots_per_ring.append(plots_in_ring)
		remaining -= plots_in_ring

	# Generate positions for each ring
	var ring_idx = 0
	for num_plots in plots_per_ring:
		# Ring scale factor (0.3 for innermost, 0.9 for outermost)
		var scale = 0.3 + (0.6 * float(ring_idx) / float(max(1, rings - 1)))

		# Parametric oval equation: x = a*cos(t), y = b*sin(t)
		# Uses SCALED oval dimensions for consistency with rendering
		for plot_in_ring in range(num_plots):
			var t = (float(plot_in_ring) / float(num_plots)) * TAU
			var x = center.x + scaled_oval_width * cos(t) * scale
			var y = center.y + scaled_oval_height * sin(t) * scale
			positions.append(Vector2(x, y))

		ring_idx += 1

	return positions


# ============================================================================
# Reset & Lifecycle
# ============================================================================

func reset() -> void:
	"""Reset biome to initial state"""
	quantum_states.clear()
	bell_gates.clear()
	time_tracker.reset()
	_reset_custom()


func _reset_custom() -> void:
	"""Override in subclasses for biome-specific reset logic"""
	pass


# ============================================================================
# Helper Functions - Bell Gate Utilities
# ============================================================================

func _gates_equal(gate1: Array, gate2: Array) -> bool:
	"""Check if two gates are equal (same positions, any order)"""
	if gate1.size() != gate2.size():
		return false

	var g1_sorted = gate1.duplicate()
	var g2_sorted = gate2.duplicate()
	g1_sorted.sort()
	g2_sorted.sort()

	for i in range(g1_sorted.size()):
		if g1_sorted[i] != g2_sorted[i]:
			return false

	return true


func _format_positions(positions: Array) -> String:
	"""Format position array as readable string"""
	var parts = []
	for pos in positions:
		parts.append(str(pos))
	return "[" + ", ".join(parts) + "]"
