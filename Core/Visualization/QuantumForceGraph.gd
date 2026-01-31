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
# Use batched renderer (falls back to GDScript if native unavailable)
const BubbleRendererScript = preload("res://Core/Visualization/BatchedBubbleRenderer.gd")
const EdgeRendererScript = preload("res://Core/Visualization/QuantumEdgeRenderer.gd")
const RegionRendererScript = preload("res://Core/Visualization/QuantumRegionRenderer.gd")
const InfraRendererScript = preload("res://Core/Visualization/QuantumInfraRenderer.gd")
const EffectsRendererScript = preload("res://Core/Visualization/QuantumEffectsRenderer.gd")
const GraphInputScript = preload("res://Core/Visualization/QuantumGraphInput.gd")
const NodeManagerScript = preload("res://Core/Visualization/QuantumNodeManager.gd")
const QuantumNode = preload("res://Core/Visualization/QuantumNode.gd")
const BiomeLayoutCalculator = preload("res://Core/Visualization/BiomeLayoutCalculator.gd")

# Logging
@onready var _verbose = get_node("/root/VerboseConfig")


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
var render_all_biomes: bool = true

var layout_calculator: BiomeLayoutCalculator
var farm_grid = null
var plot_pool = null

var biotic_flux_biome = null
var biotic_icon = null
var chaos_icon = null
var imperium_icon = null

var biome_evolution_batcher = null
var emoji_atlas_batcher = null  # Pre-built emoji atlas for GPU-accelerated rendering
var lookahead_offset: int = 0  # 0 = render current frame; set >0 to preview lookahead

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
	_connect_to_active_biome_manager()


func _connect_to_active_biome_manager():
	"""Connect to ActiveBiomeManager for biome filtering optimization."""
	var abm = get_node_or_null("/root/ActiveBiomeManager")
	if abm:
		# Initialize with current active biome
		active_biome = abm.active_biome
		# Listen for changes
		if abm.has_signal("active_biome_changed"):
			abm.active_biome_changed.connect(_on_active_biome_changed)


func _on_active_biome_changed(new_biome: String, _old_biome: String):
	"""Handle biome switching - update active_biome for force system optimization."""
	set_active_biome(new_biome)


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

	# Default: tether force off (visuals only)
	if "enable_plot_tether_force" in force_system:
		force_system.enable_plot_tether_force = false

	# Connect input signals
	input_handler.bubble_tapped.connect(_on_bubble_tapped)
	input_handler.node_swiped_to.connect(_on_node_swiped_to)

	# Create layout calculator
	layout_calculator = BiomeLayoutCalculator.new()


func _process(delta: float):
	var t0 = Time.get_ticks_usec()
	time_accumulator += delta
	frame_count += 1

	# Check for viewport resize
	var viewport = get_viewport()
	if viewport:
		var new_size = viewport.get_visible_rect().size
		if new_size != cached_viewport_size:
			cached_viewport_size = new_size
			update_layout(true)
	var t1 = Time.get_ticks_usec()

	var ctx = _build_context()
	var t2 = Time.get_ticks_usec()

	# Update node visuals from quantum state
	node_manager.update_node_visuals(quantum_nodes, ctx)
	var t3 = Time.get_ticks_usec()
	node_manager.update_animations(quantum_nodes, time_accumulator, delta)
	var t4 = Time.get_ticks_usec()

	# Update physics forces
	force_system.update(delta, quantum_nodes, ctx)
	var t5 = Time.get_ticks_usec()

	# Update particle effects
	effects_renderer.update_particles(delta, ctx)
	var t6 = Time.get_ticks_usec()

	# Request redraw (throttled for perf)
	if frame_count % 2 == 0:
		queue_redraw()
	var t7 = Time.get_ticks_usec()
	
	if frame_count % 60 == 0:
		if _verbose:
			var total_us = t7 - t0
			var total_ms = total_us / 1000.0
			_verbose.debug("trace", "⏱️", "QFG: %.2fms (Viewport: %.2f, Context: %.2f, Visuals: %.2f, Forces: %.2f)" % [
				total_ms, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, (t5 - t4) / 1000.0
			])


func _draw():
	var t_start = Time.get_ticks_usec()
	var ctx = _build_context()
	var t_ctx = Time.get_ticks_usec()

	# Draw in layers (back to front)
	# 1. Background regions
	region_renderer.draw(self, ctx)
	var t_region = Time.get_ticks_usec()

	# 2. Gate infrastructure
	infra_renderer.draw(self, ctx)
	var t_infra = Time.get_ticks_usec()

	# 3. Edge relationships (MI web, entanglement, coherence, etc.)
	edge_renderer.draw(self, ctx)
	var t_edge = Time.get_ticks_usec()

	# 4. Effects (particles, attractors)
	effects_renderer.draw(self, ctx)
	var t_effects = Time.get_ticks_usec()

	# 5. Quantum bubbles
	bubble_renderer.draw(self, ctx)
	var t_bubble = Time.get_ticks_usec()

	# 6. Sun qubit (always on top)
	bubble_renderer.draw_sun_qubit(self, ctx)
	var t_sun = Time.get_ticks_usec()

	# Debug overlay
	if DEBUG_MODE:
		_draw_debug_overlay()
	var t_end = Time.get_ticks_usec()

	# Performance logging (every 60 frames)
	if frame_count % 60 == 0:
		var total_ms = (t_end - t_start) / 1000.0
		var bubble_ms = (t_bubble - t_effects) / 1000.0
		var sun_ms = (t_sun - t_bubble) / 1000.0

		if _verbose:
			_verbose.debug("trace", "🎨", "Draw: %.2fms (Bubbles: %.2fms, Sun: %.2fms) [%d nodes]" % [
				total_ms, bubble_ms, sun_ms, quantum_nodes.size()
			])


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
		"filter_biome": _get_filter_biome(),
		"layout_calculator": layout_calculator,
		"farm_grid": farm_grid,
		"plot_pool": plot_pool,
		"biome_evolution_batcher": biome_evolution_batcher,
		"emoji_atlas_batcher": emoji_atlas_batcher,
		"lookahead_offset": lookahead_offset,
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
		"plot_tether_colors": plot_tether_colors,
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

	# Connect to PlotPool signals for dynamic updates (optional game mechanic overlay)
	if plot_pool:
		if not plot_pool.terminal_bound.is_connected(_on_terminal_bound):
			plot_pool.terminal_bound.connect(_on_terminal_bound)
		if not plot_pool.terminal_unbound.is_connected(_on_terminal_unbound):
			plot_pool.terminal_unbound.connect(_on_terminal_unbound)

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

	# Create nodes from quantum registers (first-class architecture)
	rebuild_nodes()


func rebuild_nodes():
	"""Rebuild all quantum nodes from current biomes and farm grid."""
	var ctx = _build_context()
	quantum_nodes = node_manager.create_quantum_nodes(ctx)


func register_biome(biome_name: String, biome):
	"""Register a new biome dynamically and rebuild nodes.

	Use this when creating biomes after initial setup (e.g., in tests).

	Args:
	    biome_name: Name of the biome
	    biome: BiomeBase instance
	"""
	if not biomes:
		biomes = {}
	biomes[biome_name] = biome
	rebuild_nodes()

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
	node_manager.filter_nodes_for_biome(quantum_nodes, _get_filter_biome())


func add_nodes_for_biome(biome_name: String, biome) -> void:
	"""Add nodes for a single biome without rebuilding existing nodes.

	Use this for incremental updates when toggling biomes on.
	"""
	if not biomes:
		biomes = {}
	biomes[biome_name] = biome

	# Create nodes for just this biome
	var ctx = _build_context()
	var single_biome_ctx = {
		"biomes": {biome_name: biome},
		"farm_grid": ctx.get("farm_grid"),
		"plot_pool": ctx.get("plot_pool"),
		"layout_calculator": layout_calculator
	}

	var new_nodes = node_manager.create_quantum_nodes(single_biome_ctx)

	# Add to existing nodes
	for node in new_nodes:
		quantum_nodes.append(node)

		# Update lookup dictionaries
		if node.plot_id:
			node_by_plot_id[node.plot_id] = node
		if node.grid_position != Vector2i(-1, -1):
			quantum_nodes_by_grid_pos[node.grid_position] = node
			all_plot_positions[node.grid_position] = node.classical_anchor

	print("  [ForceGraph] Added %d nodes for %s" % [new_nodes.size(), biome_name])


func remove_nodes_for_biome(biome_name: String) -> void:
	"""Remove nodes for a single biome without rebuilding everything.

	Use this for incremental updates when toggling biomes off.
	"""
	# Remove nodes matching this biome
	var removed_count = 0
	var i = quantum_nodes.size() - 1
	while i >= 0:
		var node = quantum_nodes[i]
		if node.biome_name == biome_name:
			# Remove from lookup dictionaries
			if node.plot_id and node_by_plot_id.has(node.plot_id):
				node_by_plot_id.erase(node.plot_id)
			if node.grid_position != Vector2i(-1, -1):
				if quantum_nodes_by_grid_pos.has(node.grid_position):
					quantum_nodes_by_grid_pos.erase(node.grid_position)
				if all_plot_positions.has(node.grid_position):
					all_plot_positions.erase(node.grid_position)

			# Remove from array (RefCounted nodes auto-free when no references remain)
			quantum_nodes.remove_at(i)
			removed_count += 1
		i -= 1

	# Remove from biomes dict
	if biomes and biomes.has(biome_name):
		biomes.erase(biome_name)

	print("  [ForceGraph] Removed %d nodes for %s" % [removed_count, biome_name])


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
	node_manager.filter_nodes_for_biome(quantum_nodes, _get_filter_biome())
	update_layout(true)
	biome_selected.emit(biome_name)


func set_plot_tether_force_enabled(enabled: bool) -> void:
	"""Toggle plot tether physics (visuals remain in edge renderer)."""
	if "enable_plot_tether_force" in force_system:
		force_system.enable_plot_tether_force = enabled


func _get_filter_biome() -> String:
	return "" if render_all_biomes else active_biome


func get_node_at_position(pos: Vector2) -> QuantumNode:
	"""Get quantum node at screen position."""
	return input_handler.get_node_at_position(pos, quantum_nodes)


func highlight_node(node: QuantumNode):
	"""Highlight a quantum node."""
	input_handler.highlight_node(node)


func get_stats() -> Dictionary:
	"""Get graph statistics."""
	return input_handler.get_stats(quantum_nodes, node_by_plot_id)


func get_bubble_renderer():
	"""Get the bubble renderer for stats access."""
	return bubble_renderer


func set_emoji_atlas_batcher(atlas_batcher):
	"""Set the pre-built emoji atlas batcher for GPU-accelerated emoji rendering."""
	emoji_atlas_batcher = atlas_batcher
	if bubble_renderer and bubble_renderer.has_method("set_emoji_atlas_batcher"):
		bubble_renderer.set_emoji_atlas_batcher(atlas_batcher)


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


func update_plot_positions(plot_positions: Dictionary, biome_name: String = "") -> void:
	"""Update plot anchors from PlotGridDisplay (screen-space coordinates).

	Args:
		plot_positions: Dictionary of Vector2i -> Vector2 (screen position)
		biome_name: Optional biome name for logging/context
	"""
	if plot_positions.is_empty():
		return

	# Update global cache
	for grid_pos in plot_positions.keys():
		all_plot_positions[grid_pos] = plot_positions[grid_pos]

	# Update node anchors
	for node in quantum_nodes:
		if node.grid_position == Vector2i(-1, -1):
			continue
		if not plot_positions.has(node.grid_position):
			continue
		var anchor_pos = plot_positions[node.grid_position]
		node.classical_anchor = anchor_pos
		# Keep measured nodes frozen at the new anchor position
		var is_measured = node.is_terminal_measured() or (node.plot and node.plot.has_been_measured)
		if is_measured:
			node.frozen_anchor = anchor_pos
			node.position = anchor_pos

	if _verbose:
		_verbose.debug("viz", "📌", "Plot anchors updated (%d) for biome '%s'" % [
			plot_positions.size(), biome_name
		])


# ============================================================================
# INPUT HANDLING
# ============================================================================

func _unhandled_input(event):
	var ctx = _build_context()
	if input_handler.handle_input(event, ctx):
		get_viewport().set_input_as_handled()


func _on_terminal_bound(terminal: RefCounted, register_id: int):
	"""Handle terminal binding - rebuild nodes to overlay terminal data on existing bubble."""
	rebuild_nodes()


func _on_terminal_unbound(terminal: RefCounted):
	"""Handle terminal unbinding - rebuild nodes to remove terminal overlay."""
	rebuild_nodes()


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
