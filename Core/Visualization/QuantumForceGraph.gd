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
const GeometryBatcherScript = preload("res://Core/Visualization/GeometryBatcher.gd")
const NestedForceOptimizerScript = preload("res://Core/Visualization/NestedForceOptimizer.gd")

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
var terminal_pool = null

var biotic_flux_biome = null
var biotic_icon = null
var chaos_icon = null
var imperium_icon = null

var biome_evolution_batcher = null
var emoji_atlas_batcher = null  # Pre-built emoji atlas for GPU-accelerated rendering
var bubble_atlas_batcher = null  # Pre-built bubble atlas for GPU-accelerated rendering
var geometry_batcher = null  # Unified batcher for edges/effects/regions/infra
var nested_force_optimizer = null  # Two-level hierarchical force graph (biome clusters + inner bubbles)
var lookahead_offset: int = 0  # 0 = render current frame; set >0 to preview lookahead

var center_position: Vector2 = Vector2.ZERO
var graph_radius: float = 250.0
var time_accumulator: float = 0.0
var frame_count: int = 0

var cached_viewport_size: Vector2 = Vector2.ZERO

# Detailed performance profiling
var _perf_samples: Dictionary = {
	"process_total": [],
	"process_viewport": [],
	"process_context": [],
	"process_visuals": [],
	"process_animations": [],
	"process_forces": [],
	"process_particles": [],
	"draw_total": [],
	"draw_context": [],
	"draw_canvas_item": [],
	"draw_geom_begin": [],
	"draw_region": [],
	"draw_infra": [],
	"draw_edge": [],
	"draw_effects": [],
	"draw_bubble": [],
	"draw_flush": [],
	"draw_sun": [],
	"draw_debug": [],
}
var _perf_report_interval: int = 300  # Report every N frames (less noise)

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
	geometry_batcher = GeometryBatcherScript.new()
	print("[QuantumForceGraph] GeometryBatcher initialized: %s" % geometry_batcher)

	# Default: tether force off (visuals only)
	if "enable_plot_tether_force" in force_system:
		force_system.enable_plot_tether_force = false

	# Connect input signals
	input_handler.bubble_tapped.connect(_on_bubble_tapped)
	input_handler.node_swiped_to.connect(_on_node_swiped_to)

	# Create layout calculator
	layout_calculator = BiomeLayoutCalculator.new()

	# Create geometry batcher for unified draw call batching
	geometry_batcher = GeometryBatcherScript.new()


func _process(delta: float):
	var t0 = Time.get_ticks_usec()
	time_accumulator += delta
	frame_count += 1

	# GATE: Skip all rendering if no bubbles exist
	if quantum_nodes.is_empty():
		return

	# GATE: Check for active terminal bubbles (explored, not measured)
	var has_active = _has_active_terminal_bubbles()

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

	# GATE: Only run animations and particles if we have active (not measured) bubbles
	if has_active:
		node_manager.update_animations(quantum_nodes, time_accumulator, delta)
	var t4 = Time.get_ticks_usec()

	# Update physics forces - BATCHED from evolution packets
	var nodes_with_batched_pos = _apply_batched_force_positions(ctx)
	var t5 = Time.get_ticks_usec()

	# Update nested force graph (two-level: biome clusters + inner bubble positions)
	if nested_force_optimizer:
		# Sync: ensure all bubbles are registered (catches save/load and any missed registrations)
		_sync_bubbles_to_nested_optimizer()
		var mi_cache = _build_mi_cache()

		# Scale force graph delta based on quantum evolution granularity
		# Slower quantum evolution (larger dt) → slower force graph for visual interest
		var force_delta = _get_scaled_force_delta(delta)
		nested_force_optimizer.update(force_delta, mi_cache, center_position)
	else:
		# Fallback: flat skating rink forces if nested optimizer not initialized
		_apply_skating_rink_forces(delta)
		_integrate_velocities(delta, nodes_with_batched_pos)
	var t5a = Time.get_ticks_usec()

	# GATE: Only update particles if we have active bubbles
	if has_active:
		effects_renderer.update_particles(delta, ctx)
	var t6 = Time.get_ticks_usec()

	# Request redraw (throttled for perf)
	if frame_count % 2 == 0:
		queue_redraw()
	var t7 = Time.get_ticks_usec()

	# Store timing samples
	_perf_samples["process_total"].append(t7 - t0)
	_perf_samples["process_viewport"].append(t1 - t0)
	_perf_samples["process_context"].append(t2 - t1)
	_perf_samples["process_visuals"].append(t3 - t2)
	_perf_samples["process_animations"].append(t4 - t3)
	_perf_samples["process_forces"].append(t5 - t4)
	_perf_samples["process_particles"].append(t6 - t5)

	# Trim sample arrays (keep last 300 samples)
	for key in _perf_samples:
		if _perf_samples[key].size() > 300:
			_perf_samples[key].pop_front()

	# Report every N frames
	if frame_count % _perf_report_interval == 0:
		_print_perf_report()


func _draw():
	var t_start = Time.get_ticks_usec()
	var ctx = _build_context()
	var t_ctx = Time.get_ticks_usec()

	# Get canvas item (might stall waiting for GPU)
	var canvas_item = get_canvas_item()
	var t_canvas = Time.get_ticks_usec()

	# Begin geometry batch for all untextured primitives
	geometry_batcher.begin(canvas_item)
	var t_geom_begin = Time.get_ticks_usec()

	# Draw in layers (back to front) - all add to geometry batch
	# 1. Background regions
	region_renderer.draw(self, ctx)
	var t_region = Time.get_ticks_usec()

	# 2. Gate infrastructure
	infra_renderer.draw(self, ctx)
	var t_infra = Time.get_ticks_usec()

	# 3. Edge relationships
	edge_renderer.draw(self, ctx)
	var t_edge = Time.get_ticks_usec()

	# 4. Effects
	effects_renderer.draw(self, ctx)
	var t_effects = Time.get_ticks_usec()

	# 5. Quantum bubbles
	bubble_renderer.draw(self, ctx)
	var t_bubble = Time.get_ticks_usec()

	# Flush geometry batch (RenderingServer call)
	geometry_batcher.flush()
	var t_flush = Time.get_ticks_usec()

	# 6. Sun qubit
	bubble_renderer.draw_sun_qubit(self, ctx)
	var t_sun = Time.get_ticks_usec()

	# Debug overlay
	if DEBUG_MODE:
		_draw_debug_overlay()
	var t_end = Time.get_ticks_usec()

	# Store timing samples (consolidated sub-1ms steps)
	_perf_samples["draw_total"].append(t_end - t_start)
	_perf_samples["draw_context"].append(t_ctx - t_start)
	_perf_samples["draw_canvas_item"].append(t_canvas - t_ctx)  # GPU stall?
	_perf_samples["draw_geom_begin"].append(t_geom_begin - t_canvas)
	_perf_samples["draw_region"].append(t_region - t_geom_begin)
	_perf_samples["draw_infra"].append(t_infra - t_region)
	_perf_samples["draw_edge"].append(t_edge - t_infra)
	_perf_samples["draw_effects"].append(t_effects - t_edge)
	_perf_samples["draw_bubble"].append(t_bubble - t_effects)
	_perf_samples["draw_flush"].append(t_flush - t_bubble)  # RenderingServer.canvas_item_add_triangle_array()
	_perf_samples["draw_sun"].append(t_sun - t_flush)
	_perf_samples["draw_debug"].append(t_end - t_sun)


func _has_active_terminal_bubbles() -> bool:
	"""Check if any terminal bubbles are actively explored (not measured).

	Used to gate animations, particles, and music.
	A bubble is "active" if it has a farm_tether AND is not measured.

	Returns:
		true if at least one bubble is bound and not measured
	"""
	for node in quantum_nodes:
		if node.has_farm_tether and node.terminal:
			# Must be bound AND not measured (frozen state)
			if node.terminal.is_bound and not node.terminal.is_measured:
				return true
	return false


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
		"terminal_pool": terminal_pool,
		"biome_evolution_batcher": biome_evolution_batcher,
		"emoji_atlas_batcher": emoji_atlas_batcher,
		"bubble_atlas_batcher": bubble_atlas_batcher,
		"geometry_batcher": geometry_batcher,
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

func setup(p_biomes: Dictionary, p_farm_grid = null, p_terminal_pool = null, _p_skip_bubbles: bool = false):
	"""Initialize the quantum force graph.

	Args:
	    p_biomes: Dictionary of biome_name → BiomeBase
	    p_farm_grid: Optional FarmGrid reference
	    p_terminal_pool: Optional TerminalPool reference
	    _p_skip_bubbles: Deprecated (kept for API compat, ignored)
	"""
	biomes = p_biomes
	farm_grid = p_farm_grid
	terminal_pool = p_terminal_pool

	# Connect to TerminalPool signals for dynamic updates (optional game mechanic overlay)
	if terminal_pool:
		if not terminal_pool.terminal_bound.is_connected(_on_pool_terminal_bound):
			terminal_pool.terminal_bound.connect(_on_pool_terminal_bound)
		if not terminal_pool.terminal_unbound.is_connected(_on_pool_terminal_unbound):
			terminal_pool.terminal_unbound.connect(_on_pool_terminal_unbound)

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

	# Initialize nested force optimizer (two-level: biome clusters + inner bubbles)
	nested_force_optimizer = NestedForceOptimizerScript.new()
	var biome_array = []
	for biome_name in biomes:
		biome_array.append(biomes[biome_name])
	nested_force_optimizer.initialize(biome_array)

	# Seed meta positions from layout calculator (use biome oval centers if available)
	if layout_calculator:
		for biome_name in biomes:
			var oval = layout_calculator.get_biome_oval(biome_name)
			if not oval.is_empty():
				nested_force_optimizer.meta_positions[biome_name] = oval.get("center", center_position)

	# Create nodes from quantum registers (first-class architecture)
	rebuild_nodes()


func rebuild_nodes():
	"""Rebuild all quantum nodes from current biomes and farm grid."""
	var ctx = _build_context()
	quantum_nodes = node_manager.create_quantum_nodes(ctx)

	# Rebuild lookup dictionaries from created nodes
	node_by_plot_id.clear()
	quantum_nodes_by_grid_pos.clear()
	all_plot_positions.clear()
	for node in quantum_nodes:
		if node.plot_id:
			node_by_plot_id[node.plot_id] = node
		if node.grid_position != Vector2i(-1, -1):
			quantum_nodes_by_grid_pos[node.grid_position] = node
			all_plot_positions[node.grid_position] = node.classical_anchor
		# Register with nested force optimizer
		if nested_force_optimizer and node.biome_name:
			nested_force_optimizer.register_bubble(node, node.biome_name, center_position)


func create_all_register_bubbles():
	"""Create bubbles for ALL quantum registers in all biomes.

	Used by visual tests to populate the force graph without terminal bindings.
	Replaces the single test bubble with one bubble per qubit per biome.
	"""
	# Clear existing nodes
	quantum_nodes.clear()
	node_by_plot_id.clear()
	quantum_nodes_by_grid_pos.clear()
	all_plot_positions.clear()

	# Create bubbles for all registers
	var new_nodes = node_manager.create_all_register_bubbles(biomes, layout_calculator)

	for node in new_nodes:
		quantum_nodes.append(node)
		if node.plot_id:
			node_by_plot_id[node.plot_id] = node
		# Register with nested force optimizer
		if nested_force_optimizer and node.biome_name:
			nested_force_optimizer.register_bubble(node, node.biome_name, center_position)

	queue_redraw()


# ============================================================================
# FARM SIGNAL CONNECTION (Replaces BathQuantumVisualizationController)
# ============================================================================

# Farm reference for signal connections
var farm_ref = null

# Plot selection tracking (synced with PlotGridDisplay)
var plot_grid_display_ref = null
var selected_plot_positions: Dictionary = {}  # Vector2i -> true

func connect_to_farm(farm: Node) -> void:
	"""Connect directly to farm signals (replaces BathQuantumVisualizationController)"""
	if _verbose:
		_verbose.debug("viz", "🔗", "QuantumForceGraph connecting to farm signals")
	farm_ref = farm

	# Connect to terminal lifecycle signals
	if farm.has_signal("terminal_bound"):
		farm.terminal_bound.connect(_on_terminal_bound)
		if _verbose:
			_verbose.debug("viz", "✓", "Connected to farm.terminal_bound signal")
	if farm.has_signal("terminal_measured"):
		farm.terminal_measured.connect(_on_terminal_measured)
	if farm.has_signal("terminal_released"):
		farm.terminal_released.connect(_on_terminal_released)
	if farm.has_signal("biome_removed"):
		farm.biome_removed.connect(_on_biome_removed)
	if farm.has_signal("biome_loaded"):
		farm.biome_loaded.connect(_on_biome_loaded)

	# Store references for node creation
	if "terminal_pool" in farm and farm.terminal_pool:
		terminal_pool = farm.terminal_pool
	if "biome_evolution_batcher" in farm and farm.biome_evolution_batcher:
		biome_evolution_batcher = farm.biome_evolution_batcher


func _on_terminal_bound(position: Vector2i, terminal_id: String, emoji_pair: Dictionary) -> void:
	"""Handle terminal bound event - create bubble when EXPLORE binds a terminal.
	Also removes the test bubble on first EXPLORE (transient boot validation)."""
	var north_emoji = emoji_pair.get("north", "?")
	var south_emoji = emoji_pair.get("south", "?")

	if _verbose:
		_verbose.debug("viz", "📍", "Terminal bound at %s: %s/%s" % [position, north_emoji, south_emoji])

	if not farm_ref or not farm_ref.grid:
		return

	var biome_name = farm_ref.grid.plot_biome_assignments.get(position, "")
	if biome_name.is_empty():
		# Fallback: Try to get biome from terminal's bound_biome_name
		var terminal_temp = farm_ref.terminal_pool.get_terminal(terminal_id) if farm_ref.terminal_pool else null
		if terminal_temp and not terminal_temp.bound_biome_name.is_empty():
			biome_name = terminal_temp.bound_biome_name
		else:
			return

	var plot = farm_ref.grid.get_plot(position)
	var terminal = null
	if farm_ref.terminal_pool:
		terminal = farm_ref.terminal_pool.get_terminal_at_grid_pos(position)
		if not terminal:
			terminal = farm_ref.terminal_pool.get_terminal(terminal_id)

	# Remove test bubble on first EXPLORE (transient boot validation)
	var test_bubble = node_by_plot_id.get("boot_test")
	if test_bubble:
		quantum_nodes.erase(test_bubble)
		node_by_plot_id.erase("boot_test")
		if _verbose:
			_verbose.debug("viz", "🧪", "Test bubble removed (boot validation complete)")

	_create_bubble_for_terminal(biome_name, position, north_emoji, south_emoji, plot, terminal)
	queue_redraw()


func _on_terminal_measured(position: Vector2i, terminal_id: String, outcome: String, probability: float) -> void:
	"""Handle terminal measured event - freeze bubble position"""
	if _verbose:
		_verbose.debug("viz", "📏", "Terminal %s measured at %s → %s (p=%.2f)" % [terminal_id, position, outcome, probability])

	var bubble = quantum_nodes_by_grid_pos.get(position)
	if bubble:
		# Ensure bubble has terminal reference
		if not bubble.terminal and farm_ref and farm_ref.terminal_pool:
			bubble.terminal = farm_ref.terminal_pool.get_terminal_at_grid_pos(position)

		# Freeze position for measurement visualization
		if bubble.terminal:
			bubble.frozen_anchor = bubble.position
			bubble.terminal.frozen_position = bubble.position

		queue_redraw()


func _on_terminal_released(position: Vector2i, terminal_id: String, credits_earned: int) -> void:
	"""Handle terminal released event - remove terminal bubble."""
	if _verbose:
		_verbose.debug("viz", "💰", "Terminal %s released at %s (+%d credits)" % [terminal_id, position, credits_earned])

	var bubble = quantum_nodes_by_grid_pos.get(position)
	if not bubble:
		return

	# Only remove TERMINAL bubbles (has_farm_tether=true)
	if not bubble.has_farm_tether:
		return

	# Unregister from nested force optimizer
	if nested_force_optimizer and bubble.biome_name:
		nested_force_optimizer.unregister_bubble(bubble, bubble.biome_name)

	# Remove terminal bubble from all registries
	quantum_nodes_by_grid_pos.erase(position)
	quantum_nodes.erase(bubble)
	if bubble.plot_id:
		node_by_plot_id.erase(bubble.plot_id)

	queue_redraw()


func _on_biome_loaded(biome_name: String, biome_ref) -> void:
	"""Handle dynamically loaded biome - register for visualization"""
	biomes[biome_name] = biome_ref
	update_layout(true)
	queue_redraw()
	if _verbose:
		_verbose.debug("viz", "🧭", "Dynamic biome registered for viz: %s" % biome_name)


func _on_biome_removed(biome_name: String) -> void:
	"""CASCADE CLEANUP: Remove ALL nodes for removed biome (no exceptions)"""
	var removed_count = 0
	var i = quantum_nodes.size() - 1

	while i >= 0:
		var node = quantum_nodes[i]
		if node.biome_name == biome_name:
			# Unregister from nested force optimizer
			if nested_force_optimizer:
				nested_force_optimizer.unregister_bubble(node, biome_name)

			# Remove from all registries
			if node.plot_id:
				node_by_plot_id.erase(node.plot_id)
			if node.grid_position != Vector2i(-1, -1):
				quantum_nodes_by_grid_pos.erase(node.grid_position)
				all_plot_positions.erase(node.grid_position)

			# Remove from main array
			quantum_nodes.remove_at(i)
			removed_count += 1
		i -= 1

	# Remove from biomes dict (now guaranteed clean)
	if biomes.has(biome_name):
		biomes.erase(biome_name)

	# Compact buffer memory
	if bubble_renderer and bubble_renderer.has_method("compact_buffer"):
		bubble_renderer.compact_buffer()

	if _verbose and removed_count > 0:
		_verbose.info("viz", "🧹", "Cascaded cleanup: removed %d nodes for biome '%s'" % [removed_count, biome_name])

	queue_redraw()


func _create_bubble_for_terminal(biome_name: String, grid_pos: Vector2i, north_emoji: String, south_emoji: String, plot = null, terminal = null) -> void:
	"""Create a bubble for a terminal (direct node creation)"""
	if not biomes.has(biome_name):
		return

	var biome = biomes.get(biome_name)
	if not biome or not biome.viz_cache or not biome.viz_cache.has_metadata():
		return

	if not layout_calculator:
		return

	# Determine initial position (scatter around biome oval)
	var initial_pos = center_position
	var oval = layout_calculator.get_biome_oval(biome_name)
	if not oval.is_empty():
		var center = oval.get("center", center_position)
		var semi_a = oval.get("semi_a", 100.0)
		var semi_b = oval.get("semi_b", 60.0)
		var angle = randf() * TAU
		initial_pos = center + Vector2(
			semi_a * cos(angle) * 0.7,
			semi_b * sin(angle) * 0.7
		)

	# Remove old bubble at this position if exists
	if quantum_nodes_by_grid_pos.has(grid_pos):
		var old_bubble = quantum_nodes_by_grid_pos[grid_pos]
		if old_bubble:
			var idx = quantum_nodes.find(old_bubble)
			if idx >= 0:
				quantum_nodes.remove_at(idx)
			if old_bubble.plot_id and node_by_plot_id.has(old_bubble.plot_id):
				node_by_plot_id.erase(old_bubble.plot_id)

	# Create bubble
	var bubble = QuantumNode.new(plot, initial_pos, grid_pos, center_position)
	bubble.biome_name = biome_name
	bubble.emoji_north = north_emoji
	bubble.emoji_south = south_emoji
	bubble.has_farm_tether = true
	bubble.is_terminal_bubble = true
	bubble.terminal = terminal
	bubble.biome_resolver = func(name: String): return biomes.get(name, null)

	# Store register_id so we can restore boot bubble on POP
	if terminal and terminal.bound_register_id >= 0:
		bubble.register_id = terminal.bound_register_id

	# Add to tracking
	quantum_nodes.append(bubble)
	quantum_nodes_by_grid_pos[grid_pos] = bubble
	all_plot_positions[grid_pos] = bubble.position

	if plot and bubble.plot_id:
		node_by_plot_id[bubble.plot_id] = bubble

	# Register with nested force optimizer
	if nested_force_optimizer:
		nested_force_optimizer.register_bubble(bubble, biome_name, center_position)
		if _verbose:
			_verbose.debug("viz", "🎈", "Terminal bubble registered: %s in %s" % [grid_pos, biome_name])
	else:
		if _verbose:
			_verbose.warn("viz", "⚠️", "Cannot register bubble - nested_force_optimizer is null")

	# Start spawn animation
	bubble.start_spawn_animation(time_accumulator)

	# Set initial visibility based on plot selection state
	var is_selected = selected_plot_positions.has(grid_pos)
	if plot_grid_display_ref and selected_plot_positions.size() > 0:
		bubble.visible = is_selected
	else:
		bubble.visible = true


func _on_plot_selection_changed(position: Vector2i, is_selected: bool) -> void:
	"""Handle plot selection - show/hide bubble based on selection state"""
	if is_selected:
		selected_plot_positions[position] = true
	else:
		selected_plot_positions.erase(position)

	if quantum_nodes_by_grid_pos.has(position):
		var bubble = quantum_nodes_by_grid_pos[position]
		if bubble:
			bubble.visible = is_selected
			queue_redraw()


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
	rebuild_nodes()  # Also rebuilds lookup dictionaries

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
		"terminal_pool": ctx.get("terminal_pool"),
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


func get_perf_averages() -> Dictionary:
	"""Get averaged performance data for external profiling displays."""
	var avg = {}
	for key in _perf_samples:
		var samples = _perf_samples[key]
		if samples.size() > 0:
			var total = 0.0
			for s in samples:
				total += s
			avg[key] = total / samples.size() / 1000.0  # Convert to ms
		else:
			avg[key] = 0.0
	return avg


func get_bubble_renderer():
	"""Get the bubble renderer for stats access."""
	return bubble_renderer


func set_emoji_atlas_batcher(atlas_batcher):
	"""Set the pre-built emoji atlas batcher for GPU-accelerated emoji rendering."""
	emoji_atlas_batcher = atlas_batcher
	if bubble_renderer and bubble_renderer.has_method("set_emoji_atlas_batcher"):
		bubble_renderer.set_emoji_atlas_batcher(atlas_batcher)


func set_bubble_atlas_batcher(atlas_batcher):
	"""Set the pre-built bubble atlas batcher for GPU-accelerated bubble rendering."""
	bubble_atlas_batcher = atlas_batcher
	if bubble_renderer and bubble_renderer.has_method("set_bubble_atlas_batcher"):
		bubble_renderer.set_bubble_atlas_batcher(atlas_batcher)


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
	# Debug key: Toggle shadow influence computation (Shift+S)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_S and event.shift_pressed:
			if bubble_renderer and bubble_renderer.has_method("set_shadow_compute_enabled"):
				var new_state = not bubble_renderer.is_shadow_compute_enabled()
				bubble_renderer.set_shadow_compute_enabled(new_state)
				get_viewport().set_input_as_handled()
				return

	var ctx = _build_context()
	if input_handler.handle_input(event, ctx):
		get_viewport().set_input_as_handled()


func _on_pool_terminal_bound(_terminal: RefCounted, _register_id: int):
	"""Handle terminal binding from TerminalPool.
	No-op: Farm.terminal_bound signal handles bubble creation directly."""
	pass


func _on_pool_terminal_unbound(_terminal: RefCounted):
	"""Handle terminal unbinding from TerminalPool.
	No-op: Farm.terminal_released signal handles bubble removal directly."""
	pass


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


func _apply_batched_force_positions(ctx: Dictionary) -> Dictionary:
	"""Apply pre-computed force positions from BiomeEvolutionBatcher buffers.

	Replaces synchronous force calculation with buffered position reads + interpolation.
	Force positions are computed at 10Hz in C++ alongside evolution, then consumed
	here at 60 FPS with smooth interpolation.

	Returns: Dictionary of node_id → true for nodes that got batched positions
	"""
	var nodes_with_batched_pos: Dictionary = {}
	var biome_batcher = ctx.get("biome_batcher")
	if not biome_batcher:
		return nodes_with_batched_pos

	# Group nodes by biome for batch position lookup
	var nodes_by_biome: Dictionary = {}
	for node in quantum_nodes:
		if not node or not node.biome_name:
			continue
		if not nodes_by_biome.has(node.biome_name):
			nodes_by_biome[node.biome_name] = []
		nodes_by_biome[node.biome_name].append(node)

	# Apply interpolated positions per biome
	for biome_name in nodes_by_biome:
		var biome_nodes = nodes_by_biome[biome_name]
		var interpolated_positions = biome_batcher.get_interpolated_force_positions(biome_name)

		if interpolated_positions.is_empty():
			continue

		# Map positions to nodes by register_id (qubit index)
		# Force positions are indexed by qubit ID, nodes may be in different order
		for node in biome_nodes:
			# Use register_id directly (all nodes have this set from quantum state)
			var qubit_idx = node.register_id
			if qubit_idx >= 0 and qubit_idx < interpolated_positions.size():
				node.position = interpolated_positions[qubit_idx]
				nodes_with_batched_pos[node.get_instance_id()] = true

	return nodes_with_batched_pos


func _extract_qubit_index(plot_id: String) -> int:
	"""Extract qubit index from plot_id (e.g., 'forest_q2' → 2)."""
	if "_q" not in plot_id:
		return -1
	var parts = plot_id.split("_q")
	if parts.size() < 2:
		return -1
	return int(parts[1])


# ============================================================================
# PERFORMANCE PROFILING
# ============================================================================

func _print_perf_report():
	"""Print detailed performance breakdown with averages."""
	var fps = Engine.get_frames_per_second()

	# Calculate averages
	var avg = {}
	for key in _perf_samples:
		var samples = _perf_samples[key]
		if samples.size() > 0:
			var total = 0.0
			for s in samples:
				total += s
			avg[key] = total / samples.size() / 1000.0  # Convert to ms
		else:
			avg[key] = 0.0

	# Calculate max values (P95 approximation)
	var p95 = {}
	for key in _perf_samples:
		var samples = _perf_samples[key].duplicate()
		if samples.size() > 5:
			samples.sort()
			var idx = int(samples.size() * 0.95)
			p95[key] = samples[idx] / 1000.0
		elif samples.size() > 0:
			p95[key] = samples[-1] / 1000.0
		else:
			p95[key] = 0.0

	print("\n" + "═".repeat(78))
	print("🔬 GDSCRIPT PERFORMANCE BREAKDOWN - Frame %d (%.0f FPS)" % [frame_count, fps])
	print("═".repeat(78))

	# Frame budget
	var frame_ms = 1000.0 / fps if fps > 0 else 100.0
	var total_tracked = avg["process_total"] + avg["draw_total"]
	var untracked = frame_ms - total_tracked

	print("\n🎯 FRAME BUDGET: %.1fms/frame (target: 16.67ms)" % frame_ms)
	print("   ├─ Tracked GDScript: %.2fms" % total_tracked)
	print("   └─ Untracked (GPU wait, other): %.2fms" % maxf(0, untracked))

	# _process breakdown
	print("\n📊 _process() breakdown (avg | P95):")
	print("   ├─ Viewport check:   %5.2fms | %5.2fms" % [avg["process_viewport"], p95["process_viewport"]])
	print("   ├─ Build context:    %5.2fms | %5.2fms  ← Dictionary creation" % [avg["process_context"], p95["process_context"]])
	print("   ├─ Update visuals:   %5.2fms | %5.2fms  ← node_manager loop" % [avg["process_visuals"], p95["process_visuals"]])
	print("   ├─ Animations:       %5.2fms | %5.2fms" % [avg["process_animations"], p95["process_animations"]])
	print("   ├─ Force positions:  %5.2fms | %5.2fms" % [avg["process_forces"], p95["process_forces"]])
	print("   └─ Particles:        %5.2fms | %5.2fms" % [avg["process_particles"], p95["process_particles"]])
	print("   TOTAL:               %5.2fms | %5.2fms" % [avg["process_total"], p95["process_total"]])

	# _draw breakdown (consolidated sub-1ms, detailed GPU tracking)
	print("\n🎨 _draw() breakdown (avg | P95):")
	print("   ├─ Context + Canvas:  %5.2fms | %5.2fms  ← Dict + get_canvas_item()" % [avg["draw_context"] + avg["draw_canvas_item"], p95["draw_context"] + p95["draw_canvas_item"]])
	print("   ├─ Geom Setup:        %5.2fms | %5.2fms  ← batcher.begin()" % [avg["draw_geom_begin"], p95["draw_geom_begin"]])
	print("   ├─ Renderers:         %5.2fms | %5.2fms  ← region+infra+edge+effects" % [avg["draw_region"] + avg["draw_infra"] + avg["draw_edge"] + avg["draw_effects"], p95["draw_region"] + p95["draw_infra"] + p95["draw_edge"] + p95["draw_effects"]])
	print("   ├─ Bubble renderer:   %5.2fms | %5.2fms  ← BubbleAtlasBatcher" % [avg["draw_bubble"], p95["draw_bubble"]])
	print("   ├─ Geometry flush:    %5.2fms | %5.2fms  ← RenderingServer call" % [avg["draw_flush"], p95["draw_flush"]])
	print("   ├─ Sun qubit:         %5.2fms | %5.2fms  ← draw_sun_qubit()" % [avg["draw_sun"], p95["draw_sun"]])
	print("   └─ Debug + other:     %5.2fms | %5.2fms" % [avg.get("draw_debug", 0), p95.get("draw_debug", 0)])
	print("   TOTAL:                %5.2fms | %5.2fms" % [avg["draw_total"], p95["draw_total"]])

	# Identify bottleneck
	var bottlenecks: Array = []
	if avg["process_visuals"] > 2.0:
		bottlenecks.append("🚨 update_visuals: %.1fms - node loop too slow" % avg["process_visuals"])
	if avg["process_context"] + avg["draw_context"] > 1.0:
		bottlenecks.append("🚨 context build: %.1fms - called twice per frame!" % (avg["process_context"] + avg["draw_context"]))
	if avg["draw_edge"] > 3.0:
		bottlenecks.append("🚨 edge_renderer: %.1fms - too many edges?" % avg["draw_edge"])
	if avg["draw_bubble"] > 5.0:
		bottlenecks.append("🚨 bubble_renderer: %.1fms - emoji/atlas overhead" % avg["draw_bubble"])
	if untracked > 10.0:
		bottlenecks.append("🚨 untracked: %.1fms - GPU stall or vsync?" % untracked)

	if bottlenecks.size() > 0:
		print("\n⚠️  BOTTLENECKS DETECTED:")
		for b in bottlenecks:
			print("   %s" % b)
	else:
		print("\n✅ No major bottlenecks detected")

	# Node counts
	var geom_stats = geometry_batcher.get_stats() if geometry_batcher else {}
	print("\n📈 STATS: %d nodes | %d tris | %d draw calls" % [
		quantum_nodes.size(),
		geom_stats.get("triangle_count", 0),
		geom_stats.get("draw_calls", 0)
	])
	print("═".repeat(78))


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


func _build_mi_cache() -> Dictionary:
	"""Build mutual information cache per biome for nested force optimizer."""
	var mi_cache: Dictionary = {}
	for biome_name in biomes:
		var biome = biomes[biome_name]
		if biome and biome.quantum_computer and biome.quantum_computer.has_cached_mi():
			mi_cache[biome_name] = biome.quantum_computer._cached_mi_values
		else:
			mi_cache[biome_name] = PackedFloat64Array()
	return mi_cache


func _get_scaled_force_delta(delta: float) -> float:
	"""Scale force graph delta based on quantum evolution granularity.

	Slower quantum evolution (larger dt) → slower force graph movement.
	This keeps the visual interest level consistent regardless of granularity.

	Reference: At dt=0.02s (default fast biome), use full delta.
	           At dt=10000s (max granularity), scale down by ~500x for slower movement.

	Args:
		delta: Raw frame delta from _process()

	Returns:
		Scaled delta for force graph physics
	"""
	const REFERENCE_DT = 0.02  # Baseline evolution dt (default for fast biomes)
	const MIN_SCALE = 0.002     # Minimum scale factor (at max granularity, still show some movement)

	# Get current evolution dt from first available biome
	var current_dt = REFERENCE_DT
	for biome_name in biomes:
		var biome = biomes[biome_name]
		if biome and "max_evolution_dt" in biome:
			current_dt = biome.max_evolution_dt
			break

	# Scale inversely with evolution dt: larger dt → slower force graph
	# Use sqrt to soften the scaling (linear would be too extreme at high dt values)
	var scale = sqrt(REFERENCE_DT / current_dt)
	scale = max(scale, MIN_SCALE)  # Clamp to minimum

	return delta * scale


func _sync_bubbles_to_nested_optimizer() -> void:
	"""Ensure all quantum_nodes are registered with nested force optimizer.

	This catches bubbles that were created via:
	- Save/load (QuantumNodeManager.create_quantum_nodes before save loaded)
	- Dynamic biome additions
	- Any other path that bypasses terminal_bound signal
	"""
	if not nested_force_optimizer:
		return

	var registered_count = 0
	for node in quantum_nodes:
		if not node:
			continue

		# Get biome name from node
		var biome_name = node.biome_name if node.biome_name else ""

		# If no biome_name on node, skip (can't register without biome assignment)
		if biome_name.is_empty():
			continue

		# Check if already registered in any biome's inner graph
		var already_registered = false
		for bname in nested_force_optimizer.biome_graphs:
			var inner = nested_force_optimizer.biome_graphs[bname]
			if node in inner.bubbles:
				already_registered = true
				break

		if not already_registered:
			# register_bubble() creates the inner graph if needed
			nested_force_optimizer.register_bubble(node, biome_name, center_position)
			registered_count += 1

	# Log sync results if bubbles were registered
	if registered_count > 0 and _verbose:
		_verbose.debug("viz", "🔄", "Synced %d bubbles to nested optimizer" % registered_count)


func _apply_skating_rink_forces(delta: float) -> void:
	"""Apply forces to position bubbles on biome ovals (moved from BathQuantumVisualizationController)

	RADIAL ENCODING: ring_distance ← purity Tr(ρ²)
	- Pure states (purity=1.0) → center of oval (ring=0.3)
	- Mixed states (purity=1/N) → edge of oval (ring=0.85)

	ANGULAR ENCODING: phi ← grid position hash (spread bubbles evenly)
	"""
	if not layout_calculator:
		return

	# Group nodes by biome
	var nodes_by_biome: Dictionary = {}
	for node in quantum_nodes:
		if not node.biome_name:
			continue
		if not nodes_by_biome.has(node.biome_name):
			nodes_by_biome[node.biome_name] = []
		nodes_by_biome[node.biome_name].append(node)

	for biome_name in nodes_by_biome:
		var bubbles = nodes_by_biome[biome_name]
		if bubbles.is_empty():
			continue

		var oval = layout_calculator.get_biome_oval(biome_name)
		if oval.is_empty():
			continue

		var center = oval.get("center", Vector2.ZERO)
		var semi_a = oval.get("semi_a", 100.0)
		var semi_b = oval.get("semi_b", 60.0)

		# Get biome's purity for radial positioning
		var biome = biomes.get(biome_name)
		var biome_purity = 0.5  # Default mid-purity
		if biome and ("viz_cache" in biome):
			var purity = biome.viz_cache.get_purity()
			if purity >= 0.0:
				biome_purity = purity

		# RADIAL POSITION: ring_distance ← purity (constant for all bubbles in this biome)
		var min_purity = 0.125  # 1/8 for 3-qubit system
		var purity_normalized = clampf((biome_purity - min_purity) / (1.0 - min_purity), 0.0, 1.0)
		var ring_distance = 0.85 - purity_normalized * 0.55  # 0.85 (mixed) to 0.30 (pure)

		for bubble in bubbles:
			# Skip bubbles that aren't visualizing quantum state
			# Allow: plot bubbles, terminal bubbles (farm_tether), register bubbles (register_id >= 0)
			var is_quantum_bubble = bubble.plot or bubble.has_farm_tether or bubble.register_id >= 0
			if not is_quantum_bubble:
				continue

			# MEASURED BUBBLES: Freeze in place - no skating rink forces
			if bubble.is_terminal_measured():
				bubble.velocity = Vector2.ZERO
				continue

			# ANGULAR POSITION: spread bubbles around oval
			var phi = 0.0
			if bubble.has_farm_tether and not bubble.plot:
				# Terminal bubbles: spread around oval based on grid position hash
				phi = (bubble.grid_position.x * 1.618 + bubble.grid_position.y * 2.718) * TAU
			elif bubble.plot:
				# Plot bubbles: use grid position for spread
				phi = (bubble.grid_position.x * 2.236 + bubble.grid_position.y * 1.414) * TAU

			var target_pos = center + Vector2(
				semi_a * cos(phi) * ring_distance,
				semi_b * sin(phi) * ring_distance
			)

			# Apply force toward target
			var to_target = target_pos - bubble.position
			var distance = to_target.length()

			if distance > 1.0:
				var force_dir = to_target.normalized()
				var skating_rink_strength = 150.0
				var force_magnitude = skating_rink_strength * min(distance / 50.0, 2.0)
				bubble.velocity += force_dir * force_magnitude * delta


func _integrate_velocities(delta: float, nodes_with_batched_pos: Dictionary) -> void:
	"""Integrate velocities into positions for nodes without batched positions.

	Nodes get positions from either:
	1. Batched force system (quantum physics simulation) - if available
	2. Velocity integration (skating rink forces) - fallback

	Args:
		delta: Time step
		nodes_with_batched_pos: Dictionary of node_id → true for nodes that got batched positions
	"""
	const DRAG = 0.92  # Match QuantumForceSystem damping

	for bubble in quantum_nodes:
		# Skip measured bubbles (frozen in place)
		if bubble.is_terminal_measured():
			bubble.velocity = Vector2.ZERO
			continue

		# Apply drag to all bubbles
		bubble.velocity *= DRAG

		# Integrate velocity ONLY if this node didn't get a batched position
		# Batched positions are authoritative (quantum physics), velocity is fallback (visual layout)
		if not nodes_with_batched_pos.has(bubble.get_instance_id()):
			bubble.position += bubble.velocity * delta
