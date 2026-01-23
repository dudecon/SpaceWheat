class_name QuantumForceGraph
extends Node2D

## Quantum Force Graph - Coordinator
##
## Physics-grounded visualization of quantum states.
## Delegates work to focused component classes:
##
## - QuantumForceSystem: Physics-based position forces
## - QuantumBubbleRenderer: Individual bubble drawing
## - QuantumEdgeRenderer: Relationship lines (MI web, entanglement, etc.)
## - QuantumRegionRenderer: Background regions and heatmaps
## - QuantumInfraRenderer: Gate infrastructure
## - QuantumEffectsRenderer: Particles, attractors, life cycle effects
## - QuantumGraphInput: User input handling
## - QuantumNodeManager: Node lifecycle and visual updates
##
## Visual Channel → Physics Data Mapping:
## - Position (radial): Purity Tr(ρ²) - pure states at center
## - Position (angular): Phase arg(ρ_01) - same-phase qubits cluster
## - Position (distance): Mutual Info I(A:B) - entangled bubbles cluster
## - Emoji opacity: P(n)/mass, P(s)/mass - measurement probability
## - Color hue: arg(ρ_01) - coherence phase
## - Color saturation: |ρ_01| - coherence magnitude
## - Glow intensity: Tr(ρ²) - purity
## - Pulse rate: |ρ_01| + berry_phase - stability


# Preload component scripts
const ForceSystemScript = preload("res://Core/Visualization/QuantumForceSystem.gd")
const BubbleRendererScript = preload("res://Core/Visualization/QuantumBubbleRenderer.gd")
const EdgeRendererScript = preload("res://Core/Visualization/QuantumEdgeRenderer.gd")
const RegionRendererScript = preload("res://Core/Visualization/QuantumRegionRenderer.gd")
const InfraRendererScript = preload("res://Core/Visualization/QuantumInfraRenderer.gd")
const EffectsRendererScript = preload("res://Core/Visualization/QuantumEffectsRenderer.gd")
const GraphInputScript = preload("res://Core/Visualization/QuantumGraphInput.gd")
const NodeManagerScript = preload("res://Core/Visualization/QuantumNodeManager.gd")


# Signals
signal quantum_node_selected(node: QuantumNode)
signal biome_selected(biome_name: String)
signal node_swiped_to(from_grid_pos: Vector2i, to_grid_pos: Vector2i)
signal node_clicked(grid_pos: Vector2i, button_index: int)


# Component instances (untyped to avoid class_name dependency)
var force_system
var bubble_renderer
var edge_renderer
var region_renderer
var infra_renderer
var effects_renderer
var input_handler
var node_manager

# Autoload references
@onready var _touch_input_manager = get_node_or_null("/root/TouchInputManager")


# State
var quantum_nodes: Array = []
var node_by_plot_id: Dictionary = {}
var quantum_nodes_by_grid_pos: Dictionary = {}
var all_plot_positions: Dictionary = {}
var sun_qubit_node: QuantumNode = null

var biomes: Dictionary = {}
var active_biome: String = ""

var layout_calculator: BiomeLayoutCalculator
var farm_grid = null
var plot_pool = null

var biotic_flux_biome = null
var biotic_icon = null
var chaos_icon = null
var imperium_icon = null

var center_position: Vector2 = Vector2.ZERO
var graph_radius: float = 250.0
var time_accumulator: float = 0.0
var frame_count: int = 0

var cached_viewport_size: Vector2 = Vector2.ZERO

# Legacy compatibility properties
var lock_dimensions: bool = false  # Used by BathQuantumVisualizationController

# Particle storage
var entanglement_particles: Array = []
var life_cycle_effects: Dictionary = {"spawns": [], "deaths": [], "strikes": []}

# Tether colors (for backward compatibility)
var plot_tether_colors: Dictionary = {}

# Constants
const DEBUG_MODE = false
const PARTICLE_LIFE = 1.5
const PARTICLE_SPEED = 80.0
const PARTICLE_SIZE = 3.0


func _ready():
	_initialize_components()


func _initialize_components():
	"""Create and configure all component instances."""
	force_system = ForceSystemScript.new()
	bubble_renderer = BubbleRendererScript.new()
	edge_renderer = EdgeRendererScript.new()
	region_renderer = RegionRendererScript.new()
	infra_renderer = InfraRendererScript.new()
	effects_renderer = EffectsRendererScript.new()
	input_handler = GraphInputScript.new()
	node_manager = NodeManagerScript.new()

	# Connect input signals
	input_handler.bubble_tapped.connect(_on_bubble_tapped)
	input_handler.node_swiped_to.connect(_on_node_swiped_to)

	# Create layout calculator
	layout_calculator = BiomeLayoutCalculator.new()


func _process(delta: float):
	time_accumulator += delta
	frame_count += 1

	# Check for viewport resize
	var viewport = get_viewport()
	if viewport:
		var new_size = viewport.get_visible_rect().size
		if new_size != cached_viewport_size:
			cached_viewport_size = new_size
			update_layout(true)

	# Build context for components
	var ctx = _build_context()

	# Update node visuals from quantum state
	node_manager.update_node_visuals(quantum_nodes, ctx)
	node_manager.update_animations(quantum_nodes, time_accumulator, delta)

	# Update physics forces
	force_system.update(delta, quantum_nodes, ctx)

	# Update particle effects
	effects_renderer.update_particles(delta, ctx)

	# Request redraw
	queue_redraw()


func _draw():
	var ctx = _build_context()

	# Draw in layers (back to front)

	# 1. Background regions
	region_renderer.draw(self, ctx)

	# 2. Gate infrastructure
	infra_renderer.draw(self, ctx)

	# 3. Edge relationships (MI web, entanglement, coherence, etc.)
	edge_renderer.draw(self, ctx)

	# 4. Effects (particles, attractors)
	effects_renderer.draw(self, ctx)

	# 5. Quantum bubbles
	bubble_renderer.draw(self, ctx)

	# 6. Sun qubit (always on top)
	bubble_renderer.draw_sun_qubit(self, ctx)

	# Debug overlay
	if DEBUG_MODE:
		_draw_debug_overlay()


func _build_context() -> Dictionary:
	"""Build the shared context dictionary for all components."""
	return {
		"quantum_nodes": quantum_nodes,
		"node_by_plot_id": node_by_plot_id,
		"quantum_nodes_by_grid_pos": quantum_nodes_by_grid_pos,
		"all_plot_positions": all_plot_positions,
		"sun_qubit_node": sun_qubit_node,
		"biomes": biomes,
		"active_biome": active_biome,
		"layout_calculator": layout_calculator,
		"farm_grid": farm_grid,
		"plot_pool": plot_pool,
		"biotic_flux_biome": biotic_flux_biome,
		"biotic_icon": biotic_icon,
		"chaos_icon": chaos_icon,
		"imperium_icon": imperium_icon,
		"center_position": center_position,
		"graph_radius": graph_radius,
		"time_accumulator": time_accumulator,
		"frame_count": frame_count,
		"entanglement_particles": entanglement_particles,
		"life_cycle_effects": life_cycle_effects,
		"force_system": force_system,
		"particle_life": PARTICLE_LIFE,
		"particle_speed": PARTICLE_SPEED,
		"particle_size": PARTICLE_SIZE,
	}


# ============================================================================
# PUBLIC API (Backward Compatibility)
# ============================================================================

func setup(p_biomes: Dictionary, p_farm_grid = null, p_plot_pool = null):
	"""Initialize the quantum force graph.

	Args:
	    p_biomes: Dictionary of biome_name → BiomeBase
	    p_farm_grid: Optional FarmGrid reference
	    p_plot_pool: Optional PlotPool reference
	"""
	biomes = p_biomes
	farm_grid = p_farm_grid
	plot_pool = p_plot_pool

	# Find special biomes
	for biome_name in biomes:
		var biome = biomes[biome_name]
		if biome.has_method("get_sun_visualization"):
			biotic_flux_biome = biome
		if "biotic_icon" in biome:
			biotic_icon = biome.biotic_icon
		if "chaos_icon" in biome:
			chaos_icon = biome.chaos_icon
		if "imperium_icon" in biome:
			imperium_icon = biome.imperium_icon

	# Update layout
	update_layout(true)

	# Create nodes
	rebuild_nodes()


func rebuild_nodes():
	"""Rebuild all quantum nodes from current biomes and farm grid."""
	var ctx = _build_context()
	quantum_nodes = node_manager.create_quantum_nodes(ctx)

	# Rebuild lookup dictionaries
	node_by_plot_id.clear()
	quantum_nodes_by_grid_pos.clear()
	all_plot_positions.clear()

	for node in quantum_nodes:
		if node.plot_id:
			node_by_plot_id[node.plot_id] = node
		if node.grid_position != Vector2i(-1, -1):
			quantum_nodes_by_grid_pos[node.grid_position] = node
			all_plot_positions[node.grid_position] = node.classical_anchor

	# Create sun qubit
	sun_qubit_node = node_manager.create_sun_qubit_node(biotic_flux_biome, layout_calculator)

	# Apply biome filter
	node_manager.filter_nodes_for_biome(quantum_nodes, active_biome)


func update_layout(force_rebuild: bool = false):
	"""Recompute layout from viewport size."""
	var viewport = get_viewport()
	if not viewport:
		return

	var viewport_size = viewport.get_visible_rect().size

	# Compute layout
	layout_calculator.compute_layout(biomes, viewport_size, active_biome)

	center_position = layout_calculator.graph_center
	graph_radius = layout_calculator.graph_radius

	# Update node positions
	if force_rebuild:
		layout_calculator.update_node_positions(quantum_nodes)


func set_active_biome(biome_name: String):
	"""Set the active biome for single-biome view.

	Args:
	    biome_name: Name of biome to show, or "" for all biomes
	"""
	active_biome = biome_name
	node_manager.filter_nodes_for_biome(quantum_nodes, active_biome)
	update_layout(true)
	biome_selected.emit(biome_name)


func get_node_at_position(pos: Vector2) -> QuantumNode:
	"""Get quantum node at screen position."""
	return input_handler.get_node_at_position(pos, quantum_nodes)


func highlight_node(node: QuantumNode):
	"""Highlight a quantum node."""
	input_handler.highlight_node(node)


func get_stats() -> Dictionary:
	"""Get graph statistics."""
	return input_handler.get_stats(quantum_nodes, node_by_plot_id)


func print_snapshot(reason: String = ""):
	"""Print debug snapshot of graph state."""
	if DEBUG_MODE:
		input_handler.print_snapshot(quantum_nodes, node_by_plot_id, reason)


func add_life_cycle_effect(effect_type: String, effect_data: Dictionary):
	"""Add a life cycle effect (spawn, death, strike).

	Args:
	    effect_type: "spawns", "deaths", or "strikes"
	    effect_data: Effect data with position, color, etc.
	"""
	if not life_cycle_effects.has(effect_type):
		life_cycle_effects[effect_type] = []
	effect_data["time"] = 0.0
	life_cycle_effects[effect_type].append(effect_data)


func set_plot_tether_color(grid_pos: Vector2i, color: Color):
	"""Set custom tether color for a plot (legacy compatibility)."""
	plot_tether_colors[grid_pos] = color


# ============================================================================
# INPUT HANDLING
# ============================================================================

func _unhandled_input(event):
	var ctx = _build_context()
	if input_handler.handle_input(event, ctx):
		get_viewport().set_input_as_handled()


func _on_bubble_tapped(node: QuantumNode):
	"""Handle bubble tap from input handler."""
	quantum_node_selected.emit(node)
	# Also emit node_clicked for FarmView compatibility
	if node and node.grid_position != Vector2i(-1, -1):
		node_clicked.emit(node.grid_position, MOUSE_BUTTON_LEFT)

	# CRITICAL: Mark tap as consumed in TouchInputManager to prevent
	# PlotGridDisplay from also handling this tap (spatial hierarchy)
	if _touch_input_manager:
		_touch_input_manager.consume_current_tap()


func _on_node_swiped_to(from_grid_pos: Vector2i, to_grid_pos: Vector2i):
	"""Handle node swipe from input handler."""
	node_swiped_to.emit(from_grid_pos, to_grid_pos)


# ============================================================================
# DEBUG
# ============================================================================

func _draw_debug_overlay():
	"""Draw debug information overlay."""
	var font = ThemeDB.fallback_font
	var stats = get_stats()

	var debug_text = "Nodes: %d active, %d total | Entanglements: %d" % [
		stats.active_nodes, stats.total_nodes, stats.total_entanglements
	]
	draw_string(font, Vector2(10, 20), debug_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	# Draw node positions
	for node in quantum_nodes:
		if not node.visible:
			continue
		draw_circle(node.position, 5.0, Color(0, 1, 1, 0.5))
		draw_string(font, node.position + Vector2(-15, -15),
			"[%d,%d]" % [node.grid_position.x, node.grid_position.y],
			HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0, 1, 1, 0.7))
