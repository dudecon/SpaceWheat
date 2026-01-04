class_name QuantumForceGraph
extends Node2D

## INPUT CONTRACT (Layer 5 - Bubble Touch Gestures)
## ═══════════════════════════════════════════════════════════════
## PHASE: _unhandled_input() - Lowest priority, receives leftover events
## HANDLES: Mouse/touch events that weren't consumed by higher layers
## PURPOSE: Bubble tap (measure/harvest) and swipe (entangle) gestures
## CONSUMES: When gesture detected on quantum node
## EMITS: node_clicked, node_swiped_to
## ═══════════════════════════════════════════════════════════════
##
## Quantum Force-Directed Graph Visualization
## Central visualization showing quantum states as force-directed graph
## Connected to classical plots via tether lines

# Preload dependencies
const QuantumNode = preload("res://Core/Visualization/QuantumNode.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const SemanticCoupling = preload("res://Core/QuantumSubstrate/SemanticCoupling.gd")
const BiomeLayoutCalculator = preload("res://Core/Visualization/BiomeLayoutCalculator.gd")

# Quantum nodes
var quantum_nodes: Array[QuantumNode] = []
var node_by_plot_id: Dictionary = {}  # plot_id -> QuantumNode
var quantum_nodes_by_grid_pos: Dictionary = {}  # grid_pos -> QuantumNode
var sun_qubit_node: QuantumNode = null  # Special celestial sun node

# Graph properties
var center_position: Vector2 = Vector2.ZERO
var graph_radius: float = 300.0
var lock_dimensions: bool = false  # When true, prevent auto-scaling on viewport change

# Layout calculator - computes positions from biome configs + viewport
var layout_calculator: BiomeLayoutCalculator = null
var cached_viewport_size: Vector2 = Vector2.ZERO  # Track viewport for change detection

# Click tracking for double-tap interactions
var clicked_nodes: Dictionary = {}  # grid_position -> click_count
signal node_clicked(grid_position: Vector2i, click_count: int)

# Swipe/drag tracking (for entanglement gesture)
var swipe_start_pos: Vector2 = Vector2.ZERO
var swipe_start_node: QuantumNode = null
var is_swiping: bool = false
const SWIPE_MIN_DISTANCE: float = 50.0  # Minimum distance to register swipe
const SWIPE_MAX_TIME: float = 1.0  # Maximum time for swipe gesture (seconds)
var swipe_start_time: float = 0.0
signal node_swiped_to(from_grid_pos: Vector2i, to_grid_pos: Vector2i)  # Swipe gesture for entangle

# Selection tracking (for entangle mode)
var selected_node_for_entangle: QuantumNode = null

# Force parameters (tuned for visible force-directed behavior)
const TETHER_SPRING_CONSTANT = 0.08  # Strong - pulls bubbles back to home position (Hooke's law)
const MEASURED_TETHER_STRENGTH = 0.3  # MUCH stronger - measured nodes snap to classical position
const REPULSION_STRENGTH = 7000.0  # Strong - push nodes apart vigorously
const ENTANGLE_ATTRACTION = 3.0  # Very strong - pull entangled partners together
const DAMPING = 0.75  # Less friction - more dynamic movement
const MEASURED_DAMPING = 0.95  # Strong damping - measured nodes settle quickly
const MIN_DISTANCE = 5.0  # Minimum distance between nodes
const IDEAL_ENTANGLEMENT_DISTANCE = 60.0  # Target distance for entangled nodes (closer)

# Visual parameters
const TETHER_COLOR = Color(0.8, 0.8, 0.8, 0.6)  # Bright gray, much more visible
const TETHER_WIDTH = 2.5  # Thicker lines for better visibility
const ENTANGLEMENT_COLOR_BASE = Color(1.0, 0.8, 0.2)  # Golden
const ENTANGLEMENT_WIDTH = 3.0

# Animation
var time_accumulator: float = 0.0

# Life cycle effects (external systems can add effects here)
var life_cycle_effects: Dictionary = {
	"spawns": [],     # [{position, time, color}]
	"deaths": [],     # [{position, time, icon}]
	"strikes": []     # [{from, to, time}]
}

# NOTE: Rejection effects removed - now handled by PlotGridDisplay (UI layer)
# Keeping this comment to prevent future duplicate implementations

# Particle system for entanglement lines
var entanglement_particles: Array[Dictionary] = []  # {position, velocity, life, color}
const MAX_PARTICLES_PER_LINE = 8
const PARTICLE_SPEED = 80.0
const PARTICLE_LIFE = 2.0
const PARTICLE_SIZE = 4.0

# Icon particle field overlay
var icon_particles: Array[Dictionary] = []  # {position, velocity, life, color, type}
const ICON_PARTICLE_LIFE = 3.0
const ICON_PARTICLE_SIZE = 3.0
const MAX_ICON_PARTICLES = 150  # Limit total particles
var icon_particle_spawn_accumulator: float = 0.0

# Reference to farm grid and biomes
var farm_grid: FarmGrid = null
var biome = null  # Legacy: Reference to Biome for backward compatibility

# Generic biome registry (name -> BiomeBase instance)
var biomes: Dictionary = {}  # String biome_name -> BiomeBase

# Shorthand references for common biomes (for backward compatibility with sun_qubit access)
var biotic_flux_biome = null  # BioticFlux biome (contains sun_qubit) - populated from biomes dict

# Icon references (for visual effects)
var biotic_icon = null
var chaos_icon = null
var imperium_icon = null

# Tether line colors (by plot grid position)
var plot_tether_colors: Dictionary = {}

# Plot wrappers for quantum visualization
var all_plots: Dictionary = {}  # grid_pos -> PlotBase (FarmPlot, BiomePlot, or CelestialPlot)

# ALL plot positions (including unplanted) for persistent gate infrastructure visualization
var all_plot_positions: Dictionary = {}  # Vector2i grid_pos -> Vector2 screen_pos

# Debug mode (set to false for production)
const DEBUG_MODE = true  # Set to true for debugging node positions and scaling
var debug_frame_count = 0
var frame_count = 0


func _ready():
	set_process(true)
	# Enable mouse input detection (unhandled so UI can process first)
	set_process_unhandled_input(true)
	# Create layout calculator
	layout_calculator = BiomeLayoutCalculator.new()
	print("⚛️ QuantumForceGraph initialized (input enabled)")


# REMOVED: show_rejection_effect() - now handled by PlotGridDisplay (UI layer)


func update_layout(force: bool = false) -> void:
	"""Recompute all positions from biome configs + viewport size

	Called automatically when viewport changes. Can also be called manually
	when biome visual configs change.

	Args:
		force: If true, recompute even if viewport size hasn't changed
	"""
	if not layout_calculator:
		layout_calculator = BiomeLayoutCalculator.new()

	# Get current viewport size
	var viewport = get_viewport()
	var viewport_size = viewport.get_visible_rect().size if viewport else Vector2(1280, 720)

	# Check if update is needed
	if not force and viewport_size == cached_viewport_size:
		return

	cached_viewport_size = viewport_size

	# Compute biome ovals from configs
	layout_calculator.compute_layout(biomes, viewport_size)

	# Update graph center and radius from calculator
	center_position = layout_calculator.graph_center
	graph_radius = layout_calculator.graph_radius

	# Update all node positions from their parametric coordinates
	layout_calculator.update_node_positions(quantum_nodes)

	# CRITICAL: Trigger redraw so new layout is rendered
	queue_redraw()

	if DEBUG_MODE:
		print("📐 Layout updated: %s" % layout_calculator.debug_info())


func initialize(grid: FarmGrid, center_pos: Vector2, radius: float, provided_positions: Dictionary = {}):
	"""Initialize the quantum force graph and create quantum nodes for all plots

	Args:
		grid: FarmGrid with plots and biome assignments
		center_pos: Center position for graph layout
		radius: Radius of graph for scaling
		provided_positions: Optional pre-calculated positions from PlotGridDisplay
			If provided, uses these instead of calculating positions internally.
			Maps Vector2i (grid position) → Vector2 (screen position)
	"""
	farm_grid = grid
	center_position = center_pos
	graph_radius = radius

	# Create quantum nodes if we have a valid grid
	if grid:
		# Use provided positions or calculate them from grid
		var classical_plot_positions: Dictionary = {}
		var parametric_assignments: Dictionary = {}  # grid_pos -> {biome, t, ring}

		# If positions were provided by PlotGridDisplay, use those (plots are foundation)
		if not provided_positions.is_empty():
			print("⚛️ QuantumForceGraph: Using provided plot positions from PlotGridDisplay")
			classical_plot_positions = provided_positions.duplicate()
		else:
			# Fall back to calculating positions internally
			classical_plot_positions = {}

			# Calculate viewport scaling factor for consistent oval sizing
			# graph_radius of 300 is "normal" - scale proportionally for other sizes
			var viewport_scale = graph_radius / 300.0

			# Group plots by biome for parametric ring distribution
			var plots_by_biome: Dictionary = {}  # biome_name -> Array[Vector2i]

			# First pass: group all plots by their assigned biome
			print("🔍 Grouping plots by biome (grid size: %dx%d, scale=%.2f)" % [grid.grid_width, grid.grid_height, viewport_scale])
			print("   plot_biome_assignments has %d entries" % grid.plot_biome_assignments.size())

			for y in range(grid.grid_height):
				for x in range(grid.grid_width):
					var grid_pos = Vector2i(x, y)
					var plot = grid.get_plot(grid_pos)
					if plot:
						var biome_name = grid.plot_biome_assignments.get(grid_pos, "")
						if biome_name == "":
							if biomes.size() > 0:
								biome_name = biomes.keys()[0]  # Use first registered biome as default
								print("   ⚠️  [%s] No assignment, using default biome '%s'" % [grid_pos, biome_name])
							else:
								print("   ❌ [%s] No assignment and no biomes registered!" % grid_pos)

						if biome_name != "":
							if not plots_by_biome.has(biome_name):
								plots_by_biome[biome_name] = []
							plots_by_biome[biome_name].append(grid_pos)

			var total_plots_grouped = 0
			for biome_name in plots_by_biome:
				total_plots_grouped += plots_by_biome[biome_name].size()
				print("     - %s: %d plots" % [biome_name, plots_by_biome[biome_name].size()])

			print("   Total: %d biomes with %d plots" % [plots_by_biome.keys().size(), total_plots_grouped])

			# PARAMETRIC LAYOUT: Assign parametric coordinates to each plot
			# The layout calculator will compute actual positions from these
			for bname in plots_by_biome:
				if not biomes.has(bname):
					print("⚠️ Biome '%s' not found in registry!" % bname)
					continue

				var biome_plots = plots_by_biome[bname]

				# Get parametric coordinates for all plots in this biome
				var parametric_coords = layout_calculator.distribute_nodes_in_biome(
					bname,
					biome_plots.size(),
					0  # seed_offset
				)

				print("🔵 Biome '%s': %d plots → %d parametric coords" % [
					bname,
					biome_plots.size(),
					parametric_coords.size()
				])

				# Assign parametric coords to each plot
				for i in range(biome_plots.size()):
					var grid_pos = biome_plots[i]
					if i < parametric_coords.size():
						parametric_assignments[grid_pos] = {
							"biome": bname,
							"t": parametric_coords[i]["t"],
							"ring": parametric_coords[i]["ring"]
						}

			# Compute initial layout (needed for classical_plot_positions)
			update_layout(true)

			# Convert parametric coords to screen positions for node creation
			for grid_pos in parametric_assignments:
				var params = parametric_assignments[grid_pos]
				var screen_pos = layout_calculator.get_parametric_position(
					params["biome"],
					params["t"],
					params["ring"]
				)
				# Offset anchor position UPWARD (negative Y) so bubbles float above
				classical_plot_positions[grid_pos] = screen_pos + Vector2(0, -60)

		# Create quantum nodes for all plots
		if classical_plot_positions.size() > 0:
			print("\n📍 Classical plot positions:")
			for grid_pos in classical_plot_positions.keys().slice(0, 3):
				var pos = classical_plot_positions[grid_pos]
				print("   Grid %s → Position (%.1f, %.1f)" % [grid_pos, pos.x, pos.y])
			if classical_plot_positions.size() > 3:
				print("   ... and %d more" % (classical_plot_positions.size() - 3))

			# Store ALL plot positions for persistent gate infrastructure visualization
			all_plot_positions = classical_plot_positions.duplicate()
			print("📍 Stored %d plot positions in all_plot_positions" % all_plot_positions.size())

			create_quantum_nodes(classical_plot_positions)

			# PARAMETRIC LAYOUT: Assign parametric coordinates to nodes
			# This allows update_layout() to recompute positions on viewport change
			for grid_pos in parametric_assignments:
				var node = quantum_nodes_by_grid_pos.get(grid_pos)
				if node:
					var params = parametric_assignments[grid_pos]
					node.biome_name = params["biome"]
					node.parametric_t = params["t"]
					node.parametric_ring = params["ring"]

			print("⚛️ QuantumForceGraph initialized with %d quantum nodes (parametric layout)" % quantum_nodes.size())

			# Verify nodes were created with parametric coords
			if quantum_nodes.size() > 0:
				var node = quantum_nodes[0]
				print("   First node: biome='%s', t=%.2f, ring=%.2f, pos=(%.1f, %.1f)" % [
					node.biome_name, node.parametric_t, node.parametric_ring,
					node.position.x, node.position.y
				])
		else:
			print("⚠️ QuantumForceGraph: No plots found to create quantum nodes")


func _unhandled_input(event: InputEvent):
	"""Handle mouse clicks, touch taps, and swipes on quantum nodes

	Uses _unhandled_input() instead of _input() so Control nodes can handle input first.
	Since UI Controls have mouse_filter=IGNORE, unhandled events reach us here.

	Handles both mouse (InputEventMouseButton) and touch (InputEventScreenTouch).
	"""
	# Unified handling for mouse and touch events
	var local_pos: Vector2
	var is_press: bool = false
	var is_release: bool = false

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		# Convert global position to local coordinates
		local_pos = get_global_transform().affine_inverse() * event.global_position
		is_press = event.pressed
		is_release = not event.pressed
		print("🖱️  QuantumForceGraph: Mouse %s at local %s" % ["PRESS" if is_press else "RELEASE", local_pos])

	elif event is InputEventScreenTouch:
		# Touch events - convert position to local coordinates
		local_pos = get_global_transform().affine_inverse() * event.position
		is_press = event.pressed
		is_release = not event.pressed
		print("👆 QuantumForceGraph: Touch %s at local %s (finger %d)" % ["DOWN" if is_press else "UP", local_pos, event.index])

	else:
		return  # Not an event we handle

	var clicked_node = get_node_at_position(local_pos)
	print("   Local pos: %s, Node: %s" % [local_pos, clicked_node])

	if is_press:
		# PRESS/TOUCH DOWN: Start tracking for potential swipe
		if clicked_node:
			print("   ✅ Found quantum node at grid pos: %s" % clicked_node.grid_position)
			swipe_start_pos = local_pos
			swipe_start_node = clicked_node
			is_swiping = true
			swipe_start_time = Time.get_ticks_msec() / 1000.0
			get_viewport().set_input_as_handled()
			print("   Starting swipe tracking from: %s" % clicked_node.grid_position)
		else:
			print("   ⏩ No quantum node at position")

	elif is_release:
		# RELEASE/TOUCH UP: Determine if it was a tap or swipe
		if is_swiping and swipe_start_node:
			var swipe_distance = swipe_start_pos.distance_to(local_pos)
			var swipe_time = (Time.get_ticks_msec() / 1000.0) - swipe_start_time

			print("   Swipe distance: %.1f, time: %.2fs" % [swipe_distance, swipe_time])

			if swipe_distance >= SWIPE_MIN_DISTANCE and swipe_time <= SWIPE_MAX_TIME:
				# SWIPE GESTURE: Check if end is on another node
				var end_node = get_node_at_position(local_pos)
				if end_node and end_node != swipe_start_node:
					print("✨ SWIPE DETECTED: %s → %s" % [swipe_start_node.grid_position, end_node.grid_position])
					node_swiped_to.emit(swipe_start_node.grid_position, end_node.grid_position)
					get_viewport().set_input_as_handled()
				else:
					# Swipe but didn't land on another node - treat as tap
					print("   Swipe but no target - treating as tap")
					if swipe_start_node:
						node_clicked.emit(swipe_start_node.grid_position, 0)
						get_viewport().set_input_as_handled()
			else:
				# SHORT TAP: Regular tap/click
				if swipe_start_node:
					print("👆 TAP DETECTED on: %s" % swipe_start_node.grid_position)
					node_clicked.emit(swipe_start_node.grid_position, 0)
					get_viewport().set_input_as_handled()

		is_swiping = false
		swipe_start_node = null


func set_icons(biotic, chaos, imperium):
	"""Set Icon references for visual effects"""
	biotic_icon = biotic
	chaos_icon = chaos
	imperium_icon = imperium


func set_biome(biome_ref):
	"""Set reference to Biome for sun_qubit access"""
	biome = biome_ref
	print("⚛️ QuantumForceGraph connected to Biome (sun_qubit)")


func wire_to_farm(farm: Node) -> void:
	"""Standard wiring interface for FarmUIController

	This method encapsulates all initialization needed when a farm is injected.
	Called by FarmUIController during farm injection phase.
	"""
	if not farm or not farm.has_meta("grid"):
		print("⚠️ QuantumForceGraph.wire_to_farm(): farm has no grid metadata")
		return

	# Calculate visualization parameters
	var play_rect = get_viewport().get_visible_rect()
	var center = play_rect.get_center()
	var radius = play_rect.size.length() * 0.3

	# Store the grid first (needed for biome registration)
	farm_grid = farm.grid

	# IMPORTANT: Register biomes BEFORE initialize() so plots can find their biomes
	# Generic biome registration from FarmGrid
	if farm_grid:
		var registered_biomes = farm_grid.biomes  # Access FarmGrid.biomes Dictionary
		for biome_name in registered_biomes:
			var biome_obj = registered_biomes[biome_name]
			biomes[biome_name] = biome_obj
			print("⚛️ QuantumForceGraph registered biome: %s" % biome_name)

			# Store BioticFlux reference for backward compatibility (sun_qubit access)
			if biome_name == "BioticFlux":
				biotic_flux_biome = biome_obj

	# NOW initialize quantum graph with farm data (biomes are now registered)
	initialize(farm.grid, center, radius)

	# Legacy: Set biome for backward compatibility
	if farm.has_meta("biome"):
		set_biome(farm.get_meta("biome"))

	# Create sun qubit node (will use biotic_flux_biome)
	create_sun_qubit_node()

	# REFACTOR: No signal connections - visualization reads Farm state directly
	# This eliminates the signal cascade that caused "haunted" behavior
	# Nodes will be updated during _draw() by checking current Farm state

	print("⚛️ QuantumForceGraph wired to farm with multi-biome support (no signals - direct state reading)")


# REFACTOR: Signal handlers removed - no longer needed
# Nodes are updated directly during _draw() by reading current Farm state
# This removes the signal coupling that caused the "haunted" behavior

#func _on_plot_planted(grid_pos: Vector2i) -> void:
#	"""DISABLED: Signal handler - nodes now update during _draw()"""
#	if grid_pos in quantum_nodes_by_grid_pos:
#		var node = quantum_nodes_by_grid_pos[grid_pos]
#		if node:
#			node.update_from_quantum_state()
#
#func _on_plot_harvested(grid_pos: Vector2i) -> void:
#	"""DISABLED: Signal handler - nodes now update during _draw()"""
#	if grid_pos in quantum_nodes_by_grid_pos:
#		var node = quantum_nodes_by_grid_pos[grid_pos]
#		if node:
#			node.update_from_quantum_state()


func set_plot_tether_colors(colors: Dictionary):
	"""Set tether line colors for each plot"""
	plot_tether_colors = colors


func set_all_plots(farm_plots: Array, biome_plots: Array, celestial_plots: Array):
	"""Set all plot wrappers for quantum visualization

	This allows QuantumForceGraph to access FarmPlot, BiomePlot, and CelestialPlot
	instances directly, enabling proper behavior handling (FLOATING, HOVERING, FIXED).
	"""
	all_plots.clear()

	# Index farm plots by grid position
	for plot in farm_plots:
		if plot:
			all_plots[plot.grid_position] = plot

	# Index biome plots by grid position
	for plot in biome_plots:
		if plot:
			all_plots[plot.grid_position] = plot

	# Index celestial plots by grid position
	for plot in celestial_plots:
		if plot:
			all_plots[plot.grid_position] = plot


func create_quantum_nodes(classical_plot_positions: Dictionary):
	"""Create quantum nodes for all plots

	Args:
		classical_plot_positions: Dictionary mapping Vector2i grid position -> Vector2 screen position
	"""
	quantum_nodes.clear()
	node_by_plot_id.clear()
	quantum_nodes_by_grid_pos.clear()

	if DEBUG_MODE:
		print("\n⚛️ ===== CREATING QUANTUM NODES =====")
		print("⚛️ Center position: %s" % center_position)
		print("⚛️ Graph radius: %.1f" % graph_radius)
		print("⚛️ Classical positions count: %d" % classical_plot_positions.size())

	for grid_pos in classical_plot_positions:
		var classical_pos = classical_plot_positions[grid_pos]

		# Try to get plot wrapper first (FarmPlot, BiomePlot, CelestialPlot)
		# Fall back to WheatPlot from farm_grid
		var plot = null
		if all_plots.has(grid_pos):
			plot = all_plots[grid_pos]
		elif farm_grid:
			var wheat_plot = farm_grid.get_plot(grid_pos)
			if wheat_plot:
				plot = wheat_plot

		# Pass center_position so nodes start in the center, not at perimeter
		var node = QuantumNode.new(plot, classical_pos, grid_pos, center_position)
		quantum_nodes.append(node)
		quantum_nodes_by_grid_pos[grid_pos] = node  # Index by grid position for quick lookup

		if plot:
			# Use plot_id if available (PlotBase has it), otherwise get from wrapped plot
			var plot_id = plot.plot_id if plot.has_meta("plot_id") or plot is RefCounted else plot.plot_id
			node_by_plot_id[plot_id] = node

		if DEBUG_MODE and quantum_nodes.size() <= 3:
			print("⚛️ Node %d: grid=%s, classical_pos=%s, initial_pos=%s" % [
				quantum_nodes.size() - 1, grid_pos, classical_pos, node.position
			])

	print("⚛️ Created %d quantum nodes" % quantum_nodes.size())

	if DEBUG_MODE:
		print("⚛️ ===================================\n")


func rebuild_from_biomes(classical_plot_positions: Dictionary) -> void:
	"""Phase 5: Rebuild quantum visualization from biome states after loading a save

	Called by GameStateManager.apply_state_to_game() to rebuild visualization from simulation.
	This clears old nodes and recreates them based on current biome quantum states.

	Args:
		classical_plot_positions: Dictionary mapping Vector2i grid position -> Vector2 screen position
	"""
	print("🔄 QuantumForceGraph: Rebuilding from biome states...")

	# Clear existing visualization
	quantum_nodes.clear()
	node_by_plot_id.clear()
	quantum_nodes_by_grid_pos.clear()
	sun_qubit_node = null

	# Recreate nodes from current biome states
	if classical_plot_positions:
		create_quantum_nodes(classical_plot_positions)

	# Recreate sun node if BioticFlux biome available
	if biotic_flux_biome:
		create_sun_qubit_node()

	print("   ✅ QuantumForceGraph rebuilt: %d nodes recreated from biome states" % quantum_nodes.size())


func create_sun_qubit_node():
	"""Create a special celestial quantum node for the sun/moon qubit

	The sun appears in the BioticFlux biome region as a special immutable
	celestial object. It shows day/night cycle and is always visible.
	"""
	# Use biotic_flux_biome specifically for sun qubit
	if not biotic_flux_biome or not biotic_flux_biome.sun_qubit:
		print("⚠️ Cannot create sun node: biotic_flux_biome or sun_qubit not available")
		return

	# Position sun in BioticFlux biome region (bottom-left area)
	var biome_config = biotic_flux_biome.get_visual_config()
	if not biome_config:
		print("⚠️ Cannot create sun node: BioticFlux biome config not found")
		return

	var biome_center = center_position + biome_config.center_offset * graph_radius
	var biome_radius = biome_config.circle_radius
	var sun_classical_pos = biome_center + Vector2(0, -biome_radius * 0.7)
	var sun_grid_pos = Vector2i(-1, -1)  # Special celestial position

	# Create QuantumNode with null plot (will set properties manually)
	# We can't use the real sun_qubit as a plot due to type constraints
	sun_qubit_node = QuantumNode.new(null, sun_classical_pos, sun_grid_pos, center_position)

	# Store the sun_qubit reference separately (not in plot field)
	sun_qubit_node.set_meta("sun_qubit", biotic_flux_biome.sun_qubit)

	# Set visual properties for celestial appearance
	sun_qubit_node.grid_position = sun_grid_pos
	sun_qubit_node.plot_id = "celestial_sun"
	sun_qubit_node.emoji_north = biotic_flux_biome.sun_qubit.north_emoji
	sun_qubit_node.emoji_south = biotic_flux_biome.sun_qubit.south_emoji
	sun_qubit_node.radius = 30.0  # Sun is bigger than regular nodes
	sun_qubit_node.color = Color(1.0, 0.8, 0.2)  # Golden
	sun_qubit_node.visual_scale = 1.0
	sun_qubit_node.visual_alpha = 1.0

	# FORCE-IMMUNE: Sun/Moon celestial objects do NOT move in force-directed graph
	# quantum_behavior = 2 (FIXED) means no forces applied
	sun_qubit_node.set_meta("quantum_behavior", 2)

	print("Created sun qubit node at position: %s in BioticFlux region (FORCE-IMMUNE)" % sun_classical_pos)


func _process(delta):
	if quantum_nodes.is_empty():
		return

	# Accumulate time for animations
	time_accumulator += delta

	# Update quantum node visual properties from plot states
	_update_node_visuals()

	# Update node animations (fade-in effects)
	_update_node_animations(delta)

	# Update particle system
	_update_particles(delta)

	# Update Icon particle field
	_update_icon_particles(delta)

	# NOTE: Rejection effects removed - now handled by PlotGridDisplay (UI layer)

	# Update Carrion Throne political attractor (if active)
	if imperium_icon and imperium_icon.has_method("update_political_season"):
		imperium_icon.update_political_season(delta)

	# Calculate and apply forces
	_update_forces(delta)

	# Update positions
	_update_positions(delta)

	# Redraw
	queue_redraw()


func _update_node_visuals():
	"""Update visual properties of all nodes from their quantum states"""
	# Update regular quantum nodes
	for node in quantum_nodes:
		node.update_from_quantum_state()

		# Trigger spawn animation if plot just became planted (Model B)
		if node.plot and node.plot.is_planted and node.plot.parent_biome and node.plot.register_id >= 0 and not node.is_spawning and node.visual_scale == 0.0:
			node.start_spawn_animation(time_accumulator)

	# Update sun qubit node (always visible, no spawn animation needed)
	# Phase 3d: Use biotic_flux_biome specifically
	if sun_qubit_node and biotic_flux_biome and biotic_flux_biome.sun_qubit:
		# Sun node stores the qubit in metadata, update emojis
		var sun = biotic_flux_biome.sun_qubit
		sun_qubit_node.emoji_north = sun.north_emoji
		sun_qubit_node.emoji_south = sun.south_emoji

		# Update opacities based on superposition
		var north_prob = pow(cos(sun.theta / 2.0), 2)
		sun_qubit_node.emoji_north_opacity = north_prob
		sun_qubit_node.emoji_south_opacity = 1.0 - north_prob

		# Update color from biome visualization (yellow day → deep purple night)
		var sun_vis = biotic_flux_biome.get_sun_visualization()
		sun_qubit_node.color = sun_vis["color"]

		# Force full visibility for sun
		sun_qubit_node.visual_scale = 1.0
		sun_qubit_node.visual_alpha = 1.0


func _update_node_animations(delta: float):
	"""Update spawn animations for all nodes"""
	for node in quantum_nodes:
		node.update_animation(time_accumulator, delta)


func _update_particles(delta: float):
	"""Update particle system for entanglement lines"""
	# Update existing particles
	for i in range(entanglement_particles.size() - 1, -1, -1):
		var particle = entanglement_particles[i]
		particle.life -= delta
		particle.position += particle.velocity * delta

		if particle.life <= 0.0:
			entanglement_particles.remove_at(i)

	# Spawn new particles along entanglement lines
	_spawn_entanglement_particles(delta)


func _spawn_entanglement_particles(delta: float):
	"""Spawn particles along entanglement lines"""
	var spawn_rate = 3.0  # Particles per second per line

	for node in quantum_nodes:
		if not node.plot:
			continue

		for partner_id in node.plot.entangled_plots.keys():
			var partner_node = node_by_plot_id.get(partner_id)
			if not partner_node or node.plot_id > partner_id:  # Only spawn from one direction
				continue

			# Randomly spawn particles along the line
			if randf() < spawn_rate * delta:
				var start_pos = node.position
				var end_pos = partner_node.position
				var progress = randf()  # Random position along line
				var pos = start_pos.lerp(end_pos, progress)

				# Direction from start to end
				var direction = (end_pos - start_pos).normalized()

				# Create particle (use bright cyan to match new entanglement color)
				var particle = {
					"position": pos,
					"velocity": direction * PARTICLE_SPEED,
					"life": PARTICLE_LIFE,
					"color": Color(0.3, 0.95, 1.0),  # Bright cyan
					"size": PARTICLE_SIZE
				}

				entanglement_particles.append(particle)


func _update_icon_particles(delta: float):
	"""Update Icon particle field overlay"""
	# Update existing particles
	for i in range(icon_particles.size() - 1, -1, -1):
		var particle = icon_particles[i]
		particle.life -= delta

		# Update position based on particle type
		if particle.type == "biotic":
			# Biotic: Smooth upward flow with gentle spiral
			var spiral_offset = Vector2(
				sin(time_accumulator * 2.0 + particle.position.y * 0.1) * 5.0,
				0
			)
			particle.velocity = Vector2(0, -30) + spiral_offset  # Upward flow
		elif particle.type == "chaos":
			# Chaos: Jittery, chaotic movement
			var jitter = Vector2(
				randf_range(-50, 50),
				randf_range(-50, 50)
			)
			particle.velocity = particle.velocity.lerp(jitter, 0.3)
		else:  # imperium
			# Imperium: Ordered circular motion around center
			var to_center = center_position - particle.position
			var perpendicular = Vector2(-to_center.y, to_center.x).normalized()
			particle.velocity = perpendicular * 40.0

		particle.position += particle.velocity * delta

		# Remove dead particles
		if particle.life <= 0.0:
			icon_particles.remove_at(i)

	# Spawn new particles
	_spawn_icon_particles(delta)


func _spawn_icon_particles(delta: float):
	"""Spawn Icon particles based on Icon activation"""
	if not biotic_icon and not chaos_icon and not imperium_icon:
		return

	# Limit total particles
	if icon_particles.size() >= MAX_ICON_PARTICLES:
		return

	icon_particle_spawn_accumulator += delta
	var spawn_interval = 0.05  # 20 particles per second when at full activation

	if icon_particle_spawn_accumulator < spawn_interval:
		return

	icon_particle_spawn_accumulator -= spawn_interval

	# Spawn area (within graph radius)
	var spawn_min = center_position - Vector2(graph_radius, graph_radius) * 0.8
	var spawn_max = center_position + Vector2(graph_radius, graph_radius) * 0.8

	# Spawn Biotic particles
	if biotic_icon:
		var biotic_strength = biotic_icon.get_activation()
		var biotic_count = int(biotic_strength * 3.0)  # 0-3 particles per cycle
		for i in range(biotic_count):
			if icon_particles.size() >= MAX_ICON_PARTICLES:
				break
			var pos = Vector2(
				randf_range(spawn_min.x, spawn_max.x),
				randf_range(spawn_min.y, spawn_max.y)
			)
			icon_particles.append({
				"position": pos,
				"velocity": Vector2(0, -30),  # Start upward
				"life": ICON_PARTICLE_LIFE,
				"color": Color(0.3, 0.8, 0.3),  # Green
				"type": "biotic"
			})

	# Spawn Chaos particles
	if chaos_icon:
		var chaos_strength = chaos_icon.get_activation()
		var chaos_count = int(chaos_strength * 3.0)
		for i in range(chaos_count):
			if icon_particles.size() >= MAX_ICON_PARTICLES:
				break
			var pos = Vector2(
				randf_range(spawn_min.x, spawn_max.x),
				randf_range(spawn_min.y, spawn_max.y)
			)
			icon_particles.append({
				"position": pos,
				"velocity": Vector2.ZERO,  # Start stationary
				"life": ICON_PARTICLE_LIFE,
				"color": Color(0.5, 0.2, 0.5),  # Purple
				"type": "chaos"
			})

	# Spawn Imperium particles (fewer, more ordered)
	if imperium_icon:
		var imperium_strength = imperium_icon.get_activation()
		var imperium_count = int(imperium_strength * 2.0)
		for i in range(imperium_count):
			if icon_particles.size() >= MAX_ICON_PARTICLES:
				break
			var pos = Vector2(
				randf_range(spawn_min.x, spawn_max.x),
				randf_range(spawn_min.y, spawn_max.y)
			)
			icon_particles.append({
				"position": pos,
				"velocity": Vector2.ZERO,
				"life": ICON_PARTICLE_LIFE,
				"color": Color(0.9, 0.7, 0.2),  # Golden
				"type": "imperium"
			})


# REMOVED: _update_rejection_effects() - now handled by PlotGridDisplay (UI layer)


func _update_forces(delta: float):
	"""Calculate and apply all forces to quantum nodes"""
	for node in quantum_nodes:
		var total_force = Vector2.ZERO

		# Check plot's quantum behavior (FLOATING=0, HOVERING=1, FIXED=2)
		var quantum_behavior = node.plot.quantum_behavior if node.plot and "quantum_behavior" in node.plot else -1

		# FIXED PLOTS: Don't move at all (celestial bodies, quantum_behavior=2)
		# These are completely locked to their position
		if quantum_behavior == 2:
			continue  # No forces, no movement for fixed plots

		# HOVERING PLOTS: Fixed relative to their anchor (biome measurement plots, quantum_behavior=1)
		# These don't move but stay positioned over their measurement location
		if quantum_behavior == 1:
			node.position = node.classical_anchor  # Always at anchor
			continue  # Skip force calculations

		# MEASURED NODES: Pull strongly to classical position (collapsed to definite state)
		# Quantum mechanics: Measurement collapses wavefunction to classical anchor
		if node.plot and node.plot.has_been_measured:
			# STRONG tether force - measured nodes snap to their classical position
			total_force += _calculate_tether_force(node, true)

			# Apply force with strong damping (settle quickly to anchor)
			node.apply_force(total_force, delta)
			node.apply_damping(MEASURED_DAMPING)
			continue  # Skip quantum forces (no repulsion, no entanglement)

		# UNMEASURED FLOATING NODES: Full quantum dynamics

		# 1. Weak tether spring force (toward classical anchor)
		total_force += _calculate_tether_force(node, false)

		# 2. Repulsion from all other nodes (only from unmeasured nodes)
		total_force += _calculate_repulsion_forces(node)

		# 3. Attraction to entangled partners (only to unmeasured nodes)
		total_force += _calculate_entanglement_forces(node)

		# Apply force
		node.apply_force(total_force, delta)

		# Apply damping
		node.apply_damping(DAMPING)

	# 4. Semantic coupling between neighboring plots (affects quantum states directly)
	_apply_semantic_coupling(delta)


func _calculate_tether_force(node: QuantumNode, is_measured: bool = false) -> Vector2:
	"""Calculate spring force pulling node toward its classical anchor

	Args:
		node: The quantum node
		is_measured: If true, use MUCH stronger tether (measured nodes snap to position)
	"""
	# Only apply tether force if node is attached to a farm plot
	if not node.has_farm_tether:
		return Vector2.ZERO

	var tether_vector = node.classical_anchor - node.position
	var spring_constant = MEASURED_TETHER_STRENGTH if is_measured else TETHER_SPRING_CONSTANT
	return tether_vector * spring_constant


func _calculate_repulsion_forces(node: QuantumNode) -> Vector2:
	"""Calculate repulsion forces from all other quantum nodes"""
	var repulsion = Vector2.ZERO

	for other_node in quantum_nodes:
		if other_node == node:
			continue

		var delta_pos = node.position - other_node.position
		var distance = delta_pos.length()

		# Avoid division by zero
		if distance < MIN_DISTANCE:
			distance = MIN_DISTANCE

		# Inverse square repulsion
		var force_magnitude = REPULSION_STRENGTH / (distance * distance)
		repulsion += delta_pos.normalized() * force_magnitude

	return repulsion


func _calculate_entanglement_forces(node: QuantumNode) -> Vector2:
	"""Calculate attraction forces to entangled partner nodes"""
	if not node.plot:
		return Vector2.ZERO

	var attraction = Vector2.ZERO

	# Use WheatPlot.entangled_plots (the ACTUAL entanglement data)
	for partner_id in node.plot.entangled_plots.keys():
		var partner_node = node_by_plot_id.get(partner_id)
		if not partner_node:
			continue

		# Spring-like attraction to ideal distance
		var delta_pos = partner_node.position - node.position
		var distance = delta_pos.length()
		var displacement = distance - IDEAL_ENTANGLEMENT_DISTANCE

		# Hooke's law: F = -k * displacement
		attraction += delta_pos.normalized() * displacement * ENTANGLE_ATTRACTION

	return attraction


func _apply_semantic_coupling(delta: float):
	"""Apply semantic coupling between neighboring plots

	Based on Vocabulary Virus design:
	- Similar wheat attracts (monocultures stabilize)
	- Different wheat repels (polycultures innovate)
	- Neutral wheat drifts (Brownian motion)

	Only affects plots within coupling distance (adjacent or close neighbors).
	"""
	const SemanticCoupling = preload("res://Core/QuantumSubstrate/SemanticCoupling.gd")
	const COUPLING_DISTANCE = 150.0  # Max distance for coupling effect
	const COUPLING_STRENGTH = 0.3    # Modulate effect strength

	for i in range(quantum_nodes.size()):
		var node_a = quantum_nodes[i]
		if not node_a.plot or not node_a.plot.is_planted or not node_a.plot.parent_biome or node_a.plot.register_id < 0:
			continue

		# Find neighboring nodes within coupling distance
		for j in range(i + 1, quantum_nodes.size()):
			var node_b = quantum_nodes[j]
			if not node_b.plot or not node_b.plot.is_planted or not node_b.plot.parent_biome or node_b.plot.register_id < 0:
				continue

			# Check distance (only couple nearby plots)
			var distance = node_a.position.distance_to(node_b.position)
			if distance > COUPLING_DISTANCE:
				continue

			# Apply coupling (modulates by distance)
			var distance_factor = 1.0 - (distance / COUPLING_DISTANCE)
			var strength = COUPLING_STRENGTH * distance_factor

			# NOTE: Coupling is a SIMULATION concern, not display
			# Removed display-layer calls to quantum coupling
			# This should be handled by game mechanics, not visualization
			# SemanticCoupling.apply_semantic_coupling(
			#	node_a.plot.quantum_state,
			#	node_b.plot.quantum_state,
			#	delta,
			#	strength
			# )
			# SemanticCoupling.apply_semantic_coupling(
			#	node_b.plot.quantum_state,
			#	node_a.plot.quantum_state,
			#	delta,
			#	strength
			# )


func _find_node_by_qubit(qubit) -> QuantumNode:
	"""Find quantum node that contains a specific qubit"""
	for node in quantum_nodes:
		if node.plot and node.plot.quantum_state == qubit:
			return node
	return null


func _update_positions(delta: float):
	"""Update all node positions from velocities"""
	for node in quantum_nodes:
		# Skip position updates for FIXED (quantum_behavior=2) and HOVERING (quantum_behavior=1) plots
		var quantum_behavior = node.plot.quantum_behavior if node.plot and "quantum_behavior" in node.plot else -1

		if quantum_behavior == 1 or quantum_behavior == 2:
			continue  # HOVERING and FIXED plots don't move (positions set in _update_forces)

		# Only FLOATING (quantum_behavior=0) plots use velocity-based position updates
		node.update_position(delta)


func _draw():
	"""Draw the quantum force graph"""
	# Track frame for debug logging
	frame_count += 1

	# PARAMETRIC LAYOUT: Use BiomeLayoutCalculator for all positioning
	# This handles viewport resize and biome config changes
	if not lock_dimensions:
		update_layout()  # Recomputes positions if viewport changed

	# Draw strange attractor (political season cycle)
	_draw_strange_attractor()

	# Draw Icon auras (environmental effects)
	_draw_icon_auras()

	# Draw biome regions (Venn diagram background) - Phase 3c
	_draw_biome_regions()

	# Draw in layers (back to front)

	# 1. Tether lines (background)
	_draw_tether_lines()

	# 2. Persistent gate infrastructure (at plot positions, architectural)
	_draw_persistent_gate_infrastructure()

	# 3. Energy transfer forces (Lindbladian evolution visualization)
	_draw_energy_transfer_forces()

	# 4. Qubit entanglement lines (at quantum node positions, particle-like)
	_draw_entanglement_lines()

	# 4b. Food web edges (predation/escape relationships in Forest biome)
	_draw_food_web_edges()

	# 3. Entanglement particles (above lines, below nodes)
	_draw_particles()

	# 4. Icon particle field (environmental overlay)
	_draw_icon_particles()

	# 5. Quantum nodes (foreground)
	_draw_quantum_nodes()

	# 6. Sun qubit node (always on top, celestial)
	_draw_sun_qubit_node()

	# 7. Life cycle effects (spawns, deaths, coherence strikes)
	_draw_life_cycle_effects()

	# NOTE: Rejection effects removed - now handled by PlotGridDisplay (UI layer)

	# DEBUG: Draw node position markers to verify scaling
	if DEBUG_MODE:
		_draw_debug_node_positions()


func _draw_biome_regions():
	"""Draw oval biome regions using cached layout from BiomeLayoutCalculator

	Reads pre-computed oval positions/sizes from layout_calculator.biome_ovals.
	Biomes can provide custom rendering via render_biome_content() callback.
	"""
	if not layout_calculator:
		return

	for biome_name in biomes:
		var biome_obj = biomes[biome_name]

		# Get cached oval from layout calculator
		var oval = layout_calculator.get_biome_oval(biome_name)
		if oval.is_empty():
			# Fallback: compute on the fly if not cached
			update_layout(true)
			oval = layout_calculator.get_biome_oval(biome_name)
			if oval.is_empty():
				continue

		var biome_center = oval.get("center", center_position)
		var semi_a = oval.get("semi_a", 100.0)  # Horizontal semi-axis
		var semi_b = oval.get("semi_b", 60.0)   # Vertical semi-axis
		var color = oval.get("color", Color(0.5, 0.5, 0.5, 0.3))
		var label = oval.get("label", biome_name)

		# Draw filled oval using polygon approximation
		# Note: _draw_filled_oval uses full width/height, not semi-axes
		_draw_filled_oval(biome_center, semi_a, semi_b, color)

		# Draw oval border
		_draw_oval_outline(biome_center, semi_a, semi_b, Color(1, 1, 1, 0.2), 2.0)

		# Call biome's custom rendering callback (pass average radius for compatibility)
		var biome_radius = (semi_a + semi_b) / 2.0
		biome_obj.render_biome_content(self, biome_center, biome_radius)

		# Draw label above oval
		var font = ThemeDB.fallback_font
		var label_pos = biome_center + Vector2(0, -semi_b - 15)
		draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1, 1, 1, 0.6))


func _draw_filled_oval(center: Vector2, width: float, height: float, color: Color):
	"""Draw filled oval using polygon approximation"""
	var points: PackedVector2Array = []
	var segments = 64  # Smoothness

	for i in range(segments):
		var t = (float(i) / float(segments)) * TAU
		var x = center.x + width * cos(t)
		var y = center.y + height * sin(t)
		points.append(Vector2(x, y))

	draw_colored_polygon(points, color)


func _draw_oval_outline(center: Vector2, width: float, height: float, color: Color, line_width: float):
	"""Draw oval outline using connected line segments"""
	var segments = 64
	var prev_point = Vector2.ZERO

	for i in range(segments + 1):
		var t = (float(i) / float(segments)) * TAU
		var x = center.x + width * cos(t)
		var y = center.y + height * sin(t)
		var point = Vector2(x, y)

		if i > 0:
			draw_line(prev_point, point, color, line_width, true)
		prev_point = point


func _draw_biome_oval(oval_config: Dictionary) -> void:
	"""Draw a biome oval with fill, border, and label - EXACT code from MultiBiomeVisualTest"""
	var center = oval_config.get("center", Vector2.ZERO)
	var semi_a = oval_config.get("semi_a", 100.0)  # Horizontal radius
	var semi_b = oval_config.get("semi_b", 60.0)   # Vertical radius
	var color = oval_config.get("color", Color(0.5, 0.5, 0.5, 0.3))
	var label = oval_config.get("label", "")

	# Draw filled oval (using existing helper)
	_draw_filled_oval(center, semi_a, semi_b, color)

	# Draw border with slight transparency
	var border_color = Color(color.r, color.g, color.b, min(color.a * 2.0, 0.6))
	_draw_oval_outline(center, semi_a, semi_b, border_color, 2.0)

	# Draw label above the oval
	if not label.is_empty():
		var font = ThemeDB.fallback_font
		var label_pos = center + Vector2(0, -semi_b - 15)
		draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(1, 1, 1, 0.8))



func _draw_tether_lines():
	"""Draw tether lines from classical plots to quantum nodes

	Only draws tethers for nodes attached to actual farm plots (has_farm_tether=true).
	Free-floating biome bubbles (forest organisms, celestial objects) have no tethers.
	"""
	for node in quantum_nodes:
		# Only draw tether if node is attached to a farm plot
		if not node.has_farm_tether:
			continue

		# Also require planted state (Model B)
		if not node.plot or not node.plot.is_planted or not node.plot.parent_biome or node.plot.register_id < 0:
			continue

		# Draw dashed/dotted line for prettier effect
		var start = node.classical_anchor
		var end = node.position
		var direction = (end - start).normalized()
		var distance = start.distance_to(end)
		var dash_length = 8.0
		var gap_length = 6.0
		var current_distance = 0.0

		while current_distance < distance:
			var dash_start = start + direction * current_distance
			var dash_end = start + direction * min(current_distance + dash_length, distance)

			# Fade out near the quantum node for depth
			var fade_factor = 1.0 - (current_distance / distance) * 0.5

			# Use plot-specific tether color if available, otherwise default
			var line_color = TETHER_COLOR
			if node.plot and plot_tether_colors.has(node.grid_position):
				line_color = plot_tether_colors[node.grid_position]
			line_color.a *= fade_factor

			draw_line(dash_start, dash_end, line_color, TETHER_WIDTH, true)
			current_distance += dash_length + gap_length


func _draw_entanglement_lines():
	"""Draw entanglement connections between quantum nodes

	WIDTH ENCODING: Edge width ∝ entanglement strength
	PULSING ANIMATION: Pulse ∝ |√(Nᵢ × Nⱼ)| (interaction strength)
	"""
	var drawn_pairs = {}  # Track to avoid drawing twice
	var entanglement_count = 0

	# Define base width and parameters for width encoding
	var base_width = 1.0
	var max_width = 5.0

	for node in quantum_nodes:
		if not node.plot:
			continue

		# Use WheatPlot.entangled_plots (the ACTUAL entanglement data)
		for partner_id in node.plot.entangled_plots.keys():
			var partner_node = node_by_plot_id.get(partner_id)
			if not partner_node:
				continue

			# Create unique pair key (sorted to avoid duplicates)
			var ids = [node.plot_id, partner_id]
			ids.sort()
			var pair_key = "%s_%s" % [ids[0], ids[1]]

			if drawn_pairs.has(pair_key):
				continue

			drawn_pairs[pair_key] = true

			# ====================================================================
			# WIDTH ENCODING: Edge width ∝ entanglement strength
			# ====================================================================
			# entangled_plots is Dictionary {plot_id -> strength (float)}, not {plot_id -> {dict}}
			var entanglement_strength = node.plot.entangled_plots.get(partner_id, 0.5)

			var base_line_width = base_width + entanglement_strength * max_width

			# ====================================================================
			# PULSING ANIMATION: Proportional to interaction strength
			# ====================================================================
			# Calculate interaction strength from node amplitudes
			var interaction_strength = 0.5  # Fallback
			# Model B: Use purity as proxy for interaction strength
			if node.plot and node.plot.parent_biome and node.plot.register_id >= 0 and partner_node.plot and partner_node.plot.parent_biome and partner_node.plot.register_id >= 0:
				# Get purity values from quantum computers
				var node_biome = node.plot.parent_biome
				var partner_biome = partner_node.plot.parent_biome
				var node_comp = node_biome.quantum_computer.get_component_containing(node.plot.register_id)
				var partner_comp = partner_biome.quantum_computer.get_component_containing(partner_node.plot.register_id)
				if node_comp and partner_comp:
					var node_purity = node_biome.quantum_computer.get_marginal_purity(node_comp, node.plot.register_id)
					var partner_purity = partner_biome.quantum_computer.get_marginal_purity(partner_comp, partner_node.plot.register_id)
					interaction_strength = sqrt(node_purity * partner_purity)  # Geometric mean

			# Animated pulse based on interaction strength
			var phase = time_accumulator * 2.0 * (1.0 + interaction_strength)  # Faster pulse for stronger interactions
			var pulse = (sin(phase) + 1.0) / 2.0  # 0.0 to 1.0
			var pulse_factor = 0.5 + pulse * 0.5  # 0.5 to 1.0

			# Dynamic alpha based on entanglement strength
			var alpha = 0.5 + entanglement_strength * 0.5  # 0.5 to 1.0 based on strength
			alpha = alpha * pulse_factor  # Modulate by pulse

			# Vibrant cyan/electric blue - high contrast against dark background
			var base_color = Color(0.2, 0.9, 1.0)  # Bright cyan/electric blue

			# Calculate pulsed width
			var pulsed_width = base_line_width * pulse_factor

			# Outer glow (widest, creates contrast)
			var glow_outer = base_color
			glow_outer.a = alpha * 0.25
			draw_line(node.position, partner_node.position, glow_outer, pulsed_width * 3.5, true)

			# Mid glow (brighter)
			var glow_mid = base_color
			glow_mid.a = alpha * 0.5
			draw_line(node.position, partner_node.position, glow_mid, pulsed_width * 2.0, true)

			# Core line (very bright, electric)
			var core_color = Color(0.6, 1.0, 1.0)  # Bright cyan-white core
			core_color.a = alpha * 0.95
			draw_line(node.position, partner_node.position, core_color, pulsed_width, true)

			# Draw flowing energy indicator at midpoint
			# SIZE SCALES WITH INTERACTION STRENGTH
			var mid_point = (node.position + partner_node.position) / 2

			# Pulsing glow at midpoint (brighter, more visible) - scales with interaction
			var indicator_pulse = 0.6 + pulse * 0.4
			var base_indicator_size = 8.0 + interaction_strength * 4.0  # Scales with interaction
			var indicator_size = base_indicator_size * pulse_factor

			# Outer glow (cyan halo)
			var glow_color = base_color
			glow_color.a = alpha * 0.4
			draw_circle(mid_point, indicator_size * 1.8, glow_color)

			# Core (bright white-cyan)
			var core_indicator = Color(0.8, 1.0, 1.0)
			core_indicator.a = alpha * 0.95
			draw_circle(mid_point, indicator_size * 0.8, core_indicator)

			# Inner bright spot (pure white pulse) - more prominent for strong interactions
			var bright_spot = Color.WHITE
			bright_spot.a = indicator_pulse * (0.5 + interaction_strength * 0.5)
			draw_circle(mid_point, indicator_size * 0.4, bright_spot)

			entanglement_count += 1

	if DEBUG_MODE and entanglement_count > 0:
		print("🔗 Drew %d entanglement lines" % entanglement_count)


func _draw_food_web_edges():
	"""Draw predation and escape relationships between forest organisms

	Visualizes the food web topology stored in organism qubits:
	- 🍴 (predation): Red/orange arrows from predator to prey
	- 🏃 (escape): Blue dashed lines showing flee relationships

	This creates a dynamic visualization of who's hunting whom!
	"""
	var predation_count = 0
	var escape_count = 0

	# Find forest nodes by checking biome_name
	var forest_nodes: Array = []
	for node in quantum_nodes:
		if node.biome_name == "Forest":
			forest_nodes.append(node)

	if forest_nodes.is_empty():
		return

	# Check each pair for predation/escape relationships
	for predator_node in forest_nodes:
		if not predator_node.plot or not predator_node.plot.quantum_state:
			continue

		var pred_qubit = predator_node.plot.quantum_state
		if not pred_qubit.has_method("get_graph_targets"):
			continue

		# Get predation targets (🍴 = hunts)
		var prey_targets = pred_qubit.get_graph_targets("🍴")

		for prey_node in forest_nodes:
			if prey_node == predator_node:
				continue
			if not prey_node.plot or not prey_node.plot.quantum_state:
				continue

			var prey_emoji = prey_node.emoji_north

			# Check if predator hunts this prey
			if prey_emoji in prey_targets:
				_draw_predation_arrow(predator_node.position, prey_node.position)
				predation_count += 1

		# Get escape targets (🏃 = flees from) - draw from prey perspective
		var escape_targets = pred_qubit.get_graph_targets("🏃")

		for threat_node in forest_nodes:
			if threat_node == predator_node:
				continue
			if not threat_node.plot or not threat_node.plot.quantum_state:
				continue

			var threat_emoji = threat_node.emoji_north

			# Check if this node flees from the threat
			if threat_emoji in escape_targets:
				_draw_escape_line(predator_node.position, threat_node.position)
				escape_count += 1


func _draw_predation_arrow(from_pos: Vector2, to_pos: Vector2):
	"""Draw a hunting/predation arrow (red/orange, solid, with arrowhead)"""
	var direction = (to_pos - from_pos).normalized()
	var distance = from_pos.distance_to(to_pos)

	# Don't draw if too close
	if distance < 30.0:
		return

	# Pulse animation for active hunting
	var pulse = (sin(time_accumulator * 3.0) + 1.0) / 2.0
	var alpha = 0.4 + pulse * 0.3

	# Hunting color: orange-red gradient
	var color = Color(1.0, 0.4, 0.2, alpha)

	# Shorten arrow to not overlap with bubbles
	var arrow_start = from_pos + direction * 25.0
	var arrow_end = to_pos - direction * 25.0

	# Draw glow
	var glow = color
	glow.a = alpha * 0.3
	draw_line(arrow_start, arrow_end, glow, 6.0, true)

	# Draw main line
	draw_line(arrow_start, arrow_end, color, 2.5, true)

	# Draw arrowhead
	var arrow_size = 12.0
	var perp = direction.rotated(PI / 2.0)
	var arrow_tip = arrow_end
	var arrow_left = arrow_tip - direction * arrow_size + perp * arrow_size * 0.5
	var arrow_right = arrow_tip - direction * arrow_size - perp * arrow_size * 0.5

	var arrow_points = PackedVector2Array([arrow_tip, arrow_left, arrow_right])
	draw_colored_polygon(arrow_points, color)


func _draw_escape_line(from_pos: Vector2, threat_pos: Vector2):
	"""Draw an escape/flee relationship (blue, dashed, pointing away from threat)"""
	var direction = (from_pos - threat_pos).normalized()  # Away from threat
	var distance = from_pos.distance_to(threat_pos)

	# Don't draw if too close
	if distance < 30.0:
		return

	# Quick pulse for nervous energy
	var pulse = (sin(time_accumulator * 5.0) + 1.0) / 2.0
	var alpha = 0.3 + pulse * 0.2

	# Escape color: electric blue
	var color = Color(0.3, 0.7, 1.0, alpha)

	# Draw dashed line from prey toward escape direction
	var start = from_pos
	var escape_dir = direction * 40.0  # Short escape vector
	var end = from_pos + escape_dir

	# Draw multiple dashes
	var dash_length = 8.0
	var gap_length = 5.0
	var total_length = 40.0
	var current = 0.0

	while current < total_length:
		var dash_start = start + direction * current
		var dash_end = start + direction * min(current + dash_length, total_length)
		draw_line(dash_start, dash_end, color, 2.0, true)
		current += dash_length + gap_length


func _draw_life_cycle_effects():
	"""Draw life cycle visual effects: spawns, deaths, coherence strikes

	Effects are stored in life_cycle_effects dictionary by external systems.
	Each effect has a 'time' field that counts up - effects fade as time increases.
	"""
	var font = ThemeDB.fallback_font

	# ════════════════════════════════════════════════════════════════
	# SPAWN EFFECTS: Expanding rings of light when organisms are born
	# ════════════════════════════════════════════════════════════════
	for effect in life_cycle_effects.get("spawns", []):
		var pos = effect.get("position", Vector2.ZERO)
		var t = effect.get("time", 0.0)
		var color = effect.get("color", Color.GREEN)

		var duration = 1.0
		var progress = clamp(t / duration, 0.0, 1.0)
		var alpha = 1.0 - progress  # Fade out

		# Expanding ring
		var ring_radius = 10.0 + progress * 50.0
		var ring_color = color
		ring_color.a = alpha * 0.6
		draw_arc(pos, ring_radius, 0, TAU, 32, ring_color, 3.0, true)

		# Inner glow
		var glow_color = color.lightened(0.3)
		glow_color.a = alpha * 0.4
		draw_circle(pos, ring_radius * 0.5, glow_color)

		# Sparkle particles
		for i in range(4):
			var angle = (t * 3.0 + i * TAU / 4.0)
			var sparkle_pos = pos + Vector2(cos(angle), sin(angle)) * ring_radius * 0.7
			var sparkle_color = Color.WHITE
			sparkle_color.a = alpha * 0.8
			draw_circle(sparkle_pos, 3.0 * (1.0 - progress), sparkle_color)

	# ════════════════════════════════════════════════════════════════
	# DEATH EFFECTS: Fading emoji with dissolving particles
	# ════════════════════════════════════════════════════════════════
	for effect in life_cycle_effects.get("deaths", []):
		var pos = effect.get("position", Vector2.ZERO)
		var t = effect.get("time", 0.0)
		var icon = effect.get("icon", "💀")

		var duration = 1.0
		var progress = clamp(t / duration, 0.0, 1.0)
		var alpha = 1.0 - progress

		# Fading emoji (drifting upward like a ghost)
		var ghost_pos = pos + Vector2(0, -progress * 30.0)
		var emoji_alpha = alpha * 0.8
		draw_string(font, ghost_pos, icon, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(1, 1, 1, emoji_alpha))

		# Dissolving particles (float upward and outward)
		for i in range(6):
			var angle = i * TAU / 6.0 + t * 2.0
			var dist = progress * 40.0
			var particle_pos = pos + Vector2(cos(angle), sin(angle) - progress) * dist
			var particle_color = Color(0.5, 0.5, 0.5, alpha * 0.5)
			draw_circle(particle_pos, 2.0 * (1.0 - progress), particle_color)

	# ════════════════════════════════════════════════════════════════
	# COHERENCE STRIKE EFFECTS: Lightning flash between predator and prey
	# ════════════════════════════════════════════════════════════════
	for effect in life_cycle_effects.get("strikes", []):
		var from_pos = effect.get("from", Vector2.ZERO)
		var to_pos = effect.get("to", Vector2.ZERO)
		var t = effect.get("time", 0.0)

		var duration = 0.5
		var progress = clamp(t / duration, 0.0, 1.0)
		var alpha = 1.0 - progress

		# Electric flash color (bright yellow-white)
		var flash_color = Color(1.0, 0.95, 0.5, alpha)

		# Jagged lightning bolt
		var direction = (to_pos - from_pos).normalized()
		var distance = from_pos.distance_to(to_pos)
		var perp = direction.rotated(PI / 2.0)

		var segments = 5
		var prev_point = from_pos
		for i in range(segments):
			var t_seg = float(i + 1) / float(segments)
			var base_point = from_pos.lerp(to_pos, t_seg)
			# Add zigzag offset (except for last point)
			var offset = 0.0 if i == segments - 1 else (randf() - 0.5) * 20.0
			var point = base_point + perp * offset

			# Outer glow
			var glow = flash_color
			glow.a = alpha * 0.3
			draw_line(prev_point, point, glow, 8.0, true)

			# Core lightning
			draw_line(prev_point, point, flash_color, 3.0, true)

			prev_point = point

		# Impact flash at prey position
		var impact_size = 20.0 * (1.0 - progress)
		var impact_color = flash_color
		impact_color.a = alpha * 0.6
		draw_circle(to_pos, impact_size, impact_color)


# REMOVED: _draw_rejection_effects() - now handled by PlotGridDisplay (UI layer)
# This was creating duplicate rejection visuals


func _draw_persistent_gate_infrastructure():
	"""Draw persistent gate infrastructure at PLOT positions (not floating quantum nodes).

	INFRASTRUCTURE VISUAL: Solid architectural lines connecting plot positions
	- Bell gates: Gold/amber two-node connection
	- Cluster gates: Multi-node web with central hub

	These are the persistent "toggle switches" that survive harvest/replant.
	Different from instantaneous qubit entanglements which float with the bubbles.

	IMPORTANT: Uses all_plot_positions (ALL plots) not quantum_nodes_by_grid_pos (only planted)
	"""
	if not farm_grid:
		return

	var drawn_gates = {}  # Track to avoid drawing same gate multiple times
	var gate_count = 0

	# Parametric sizing based on graph radius
	var base_width = graph_radius * 0.008  # ~2.4px at radius 300
	var max_width = graph_radius * 0.02    # ~6px at radius 300
	var corner_radius = graph_radius * 0.025  # Corner connector size

	# Debug: Log available positions on first few frames
	if frame_count < 5:
		print("📍 Gate draw: all_plot_positions has %d entries, checking %d plots" % [all_plot_positions.size(), farm_grid.plots.size()])

	# Iterate ALL plots in the grid (not just quantum nodes)
	# NOTE: farm_grid.plots is a Dictionary {Vector2i -> PlotBase}, so iterate keys and get values
	for grid_pos in farm_grid.plots:
		var plot = farm_grid.plots[grid_pos]
		if not plot:
			continue

		# Check for persistent gates on this plot
		var active_gates = plot.get_active_gates() if plot.has_method("get_active_gates") else []

		for gate in active_gates:
			var gate_type = gate.get("type", "")
			var linked_plots: Array = gate.get("linked_plots", [])

			if linked_plots.is_empty():
				continue

			# Create unique gate key to avoid duplicate draws
			var sorted_positions = linked_plots.duplicate()
			sorted_positions.sort()
			var gate_key = "%s_%s" % [gate_type, str(sorted_positions)]

			if drawn_gates.has(gate_key):
				continue
			drawn_gates[gate_key] = true

			# Collect plot positions from all_plot_positions (includes unplanted plots)
			var plot_positions: Array[Vector2] = []
			for pos in linked_plots:
				# Try all_plot_positions first (all plots)
				if all_plot_positions.has(pos):
					plot_positions.append(all_plot_positions[pos])
				# Fallback to quantum node anchor if available
				elif quantum_nodes_by_grid_pos.has(pos):
					plot_positions.append(quantum_nodes_by_grid_pos[pos].classical_anchor)

			if plot_positions.size() < 2:
				continue

			# Choose visual style based on gate type
			match gate_type:
				"bell":
					_draw_bell_gate_infrastructure(plot_positions, base_width, max_width, corner_radius)
				"cluster":
					_draw_cluster_gate_infrastructure(plot_positions, base_width, max_width, corner_radius)
				_:
					# Default: simple lines
					_draw_bell_gate_infrastructure(plot_positions, base_width, max_width, corner_radius)

			gate_count += 1

	# Debug: Always print gate count on first few frames
	if gate_count > 0 and frame_count < 10:
		print("🔧 Drew %d persistent gate infrastructure (frame %d)" % [gate_count, frame_count])
	elif DEBUG_MODE and gate_count > 0:
		print("🔧 Drew %d persistent gate infrastructure" % gate_count)


func _draw_bell_gate_infrastructure(positions: Array[Vector2], base_width: float, max_width: float, corner_radius: float):
	"""Draw Bell gate infrastructure (2-node connection) at plot positions.

	VISUAL STYLE: Solid amber/gold brackets connecting two plots
	- Architectural feel (infrastructure, not particles)
	- Corner connectors at each plot
	- Solid connecting beam between them
	"""
	if positions.size() < 2:
		return

	var p1 = positions[0]
	var p2 = positions[1]

	# Animation - slow pulse for infrastructure (much slower than qubit entanglement)
	var pulse = (sin(time_accumulator * 0.8) + 1.0) / 2.0  # Slow, steady
	var pulse_factor = 0.7 + pulse * 0.3  # 0.7 to 1.0

	# Amber/gold infrastructure color (distinct from cyan qubit entanglement)
	var infra_color = Color(1.0, 0.75, 0.2)  # Golden amber
	var infra_glow = Color(1.0, 0.85, 0.4)   # Lighter glow

	# Calculate line properties
	var line_width = base_width + max_width * 0.5
	var pulsed_width = line_width * pulse_factor

	# Draw glow layer (outer)
	var glow_color = infra_glow
	glow_color.a = 0.3 * pulse_factor
	draw_line(p1, p2, glow_color, pulsed_width * 2.5, true)

	# Draw core line (solid infrastructure beam)
	var core_color = infra_color
	core_color.a = 0.85 * pulse_factor
	draw_line(p1, p2, core_color, pulsed_width, true)

	# Draw corner connectors at each position (square brackets feel)
	_draw_gate_corner_connector(p1, corner_radius, infra_color, pulse_factor)
	_draw_gate_corner_connector(p2, corner_radius, infra_color, pulse_factor)


func _draw_cluster_gate_infrastructure(positions: Array[Vector2], base_width: float, max_width: float, corner_radius: float):
	"""Draw Cluster gate infrastructure (N-node web) at plot positions.

	VISUAL STYLE: Multi-node web with central hub
	- All nodes connect to central point
	- Corner connectors at each plot
	- Hub indicator in center
	"""
	if positions.size() < 2:
		return

	# Calculate center hub position
	var hub = Vector2.ZERO
	for pos in positions:
		hub += pos
	hub /= positions.size()

	# Animation - slow pulse
	var pulse = (sin(time_accumulator * 0.8) + 1.0) / 2.0
	var pulse_factor = 0.7 + pulse * 0.3

	# Purple/violet for cluster gates (distinct from bell amber)
	var cluster_color = Color(0.7, 0.4, 1.0)  # Purple
	var cluster_glow = Color(0.85, 0.6, 1.0)  # Lighter purple glow

	var line_width = base_width + max_width * 0.3  # Slightly thinner
	var pulsed_width = line_width * pulse_factor

	# Draw spokes from hub to each position
	for pos in positions:
		# Glow layer
		var glow_color = cluster_glow
		glow_color.a = 0.25 * pulse_factor
		draw_line(hub, pos, glow_color, pulsed_width * 2.0, true)

		# Core line
		var core_color = cluster_color
		core_color.a = 0.8 * pulse_factor
		draw_line(hub, pos, core_color, pulsed_width, true)

		# Corner connector at plot position
		_draw_gate_corner_connector(pos, corner_radius, cluster_color, pulse_factor)

	# Draw central hub indicator
	var hub_size = corner_radius * 1.5 * pulse_factor
	var hub_glow = cluster_glow
	hub_glow.a = 0.4 * pulse_factor
	draw_circle(hub, hub_size * 1.5, hub_glow)

	var hub_core = cluster_color
	hub_core.a = 0.9 * pulse_factor
	draw_circle(hub, hub_size, hub_core)

	# Inner bright spot
	var bright = Color.WHITE
	bright.a = 0.6 * pulse_factor
	draw_circle(hub, hub_size * 0.4, bright)


func _draw_gate_corner_connector(pos: Vector2, radius: float, color: Color, pulse_factor: float):
	"""Draw corner connector bracket at a plot position.

	VISUAL: Small square bracket/corner piece indicating infrastructure attachment.
	"""
	var size = radius * pulse_factor

	# Glow circle
	var glow = color
	glow.a = 0.3 * pulse_factor
	draw_circle(pos, size * 1.8, glow)

	# Core circle (solid infrastructure point)
	var core = color
	core.a = 0.9 * pulse_factor
	draw_circle(pos, size, core)

	# Inner highlight
	var highlight = Color.WHITE
	highlight.a = 0.5 * pulse_factor
	draw_circle(pos, size * 0.5, highlight)


func _draw_energy_transfer_forces():
	"""Draw energy transfer forces from sun to plots (Lindbladian evolution visualization)

	Shows how quantum states gain energy from sun coupling and icon influences.
	Arrow opacity/thickness represents energy transfer rate.
	"""
	if not sun_qubit_node or not biotic_flux_biome:
		return

	var sun_color_vis = biotic_flux_biome.get_sun_visualization()
	var sun_theta = sun_color_vis["theta"]

	# Only draw forces if sun is above horizon (has energy to transfer)
	# Energy strength = |cos(sun.theta)| peaks at θ=0 (noon) and θ=π (midnight)
	var energy_strength = abs(cos(sun_theta))

	if energy_strength < 0.1:
		return  # Skip when sun near horizon (θ=π/2, 3π/2) - minimal energy transfer

	var force_arrows_drawn = 0

	for node in quantum_nodes:
		if not node.plot or not node.plot.is_planted or not node.plot.quantum_state:
			continue

		# Skip celestial objects (they don't receive forces)
		if node.plot_id == "celestial_sun" or node.plot_id == "celestial_moon":
			continue

		# Calculate energy transfer rate based on quantum state alignment with sun
		var qubit = node.plot.quantum_state
		if not qubit:
			continue

		# Energy coupling: cos²(θ_plot/2) × cos²((θ_plot - θ_sun)/2)
		var alignment = cos((qubit.theta - sun_theta) / 2.0)
		var plot_alignment = cos(qubit.theta / 2.0)
		var energy_transfer_rate = plot_alignment * plot_alignment * alignment * alignment * energy_strength

		# Skip if no meaningful energy transfer
		if energy_transfer_rate < 0.05:
			continue

		# Draw energy transfer arrow from sun to plot
		# Arrow thickness = energy transfer rate
		var arrow_thickness = clamp(energy_transfer_rate * 3.0, 0.5, 2.5)

		# Arrow color = sun color (yellow day → purple night)
		var arrow_color = sun_color_vis["color"]
		arrow_color.a = clamp(energy_transfer_rate * 0.8, 0.2, 0.7)  # Opacity based on transfer rate

		# Draw arrow from sun toward plot
		var from = sun_qubit_node.position
		var to = node.position
		draw_line(from, to, arrow_color, arrow_thickness, true)

		# Draw arrow head (small triangle at plot end)
		var direction = (to - from).normalized()
		var arrow_size = arrow_thickness * 3.0
		var arrow_left = to - direction * arrow_size + direction.rotated(PI/2) * arrow_size * 0.5
		var arrow_right = to - direction * arrow_size - direction.rotated(PI/2) * arrow_size * 0.5

		# Draw small arrow head triangle
		var arrow_head_color = arrow_color
		arrow_head_color.a = arrow_color.a * 0.8
		draw_colored_polygon([to, arrow_left, arrow_right], arrow_head_color)

		force_arrows_drawn += 1

	if DEBUG_MODE and force_arrows_drawn > 0:
		print("⚡ Drew %d energy transfer force arrows (sun coupling)" % force_arrows_drawn)

	# Draw icon influence forces (spring attraction to stable points)
	_draw_icon_influence_forces()


func _draw_icon_influence_forces():
	"""Draw spring attraction forces toward icon stable points (Hamiltonian evolution)

	Shows how wheat icon and mushroom icon pull qubits toward their stable points.
	- Wheat icon: θ_stable = π/4 (wheat growth state)
	- Mushroom icon: θ_stable = π (mushroom growth state)
	"""
	if not biotic_flux_biome:
		return

	var icon_influence_arrows_drawn = 0

	for node in quantum_nodes:
		if not node.plot or not node.plot.is_planted or not node.plot.quantum_state:
			continue

		# Skip celestial objects
		if node.plot_id == "celestial_sun" or node.plot_id == "celestial_moon":
			continue

		var qubit = node.plot.quantum_state
		if not qubit:
			continue

		# Determine which icon(s) influence this plot
		# Wheat icon: strong coupling if plot_type is WHEAT or hybrid
		# Mushroom icon: strong coupling if plot_type is MUSHROOM or hybrid

		var wheat_stable = PI / 4.0  # Wheat growth state
		var mushroom_stable = PI  # Mushroom growth state

		# Calculate deviation from each stable point
		var wheat_deviation = abs(qubit.theta - wheat_stable)
		var mushroom_deviation = abs(qubit.theta - mushroom_stable)

		# Normalize angles to [0, π]
		if wheat_deviation > PI:
			wheat_deviation = TAU - wheat_deviation
		if mushroom_deviation > PI:
			mushroom_deviation = TAU - mushroom_deviation

		# Draw force toward wheat icon if plot type is wheat-aligned
		if biotic_flux_biome.wheat_icon and wheat_deviation > 0.1:
			var spring_strength = (1.0 - wheat_deviation / PI) * 0.6  # Stronger near stable point
			if spring_strength > 0.1:
				# Wheat icon forces: golden/green color
				var wheat_color = Color(1.0, 0.9, 0.3, spring_strength * 0.5)  # Golden
				var force_magnitude = spring_strength * 15.0  # Arrow length
				var force_direction = (wheat_stable - qubit.theta)
				if force_direction > PI:
					force_direction -= TAU
				force_direction = sign(force_direction)  # Normalize to -1 or +1

				# Draw small indicator line showing attraction
				var indicator_center = node.position
				var indicator_direction = Vector2(cos(qubit.theta), sin(qubit.theta))
				var indicator_end = indicator_center + indicator_direction * force_magnitude * sign(force_direction)
				draw_line(indicator_center, indicator_end, wheat_color, 1.0, true)

				icon_influence_arrows_drawn += 1

		# Draw force toward mushroom icon if plot type is mushroom-aligned
		if biotic_flux_biome.mushroom_icon and mushroom_deviation > 0.1:
			var spring_strength = (1.0 - mushroom_deviation / PI) * 0.6
			if spring_strength > 0.1:
				# Mushroom icon forces: purple/blue color
				var mushroom_color = Color(0.8, 0.4, 0.9, spring_strength * 0.5)  # Purple
				var force_magnitude = spring_strength * 15.0
				var force_direction = (mushroom_stable - qubit.theta)
				if force_direction > PI:
					force_direction -= TAU
				force_direction = sign(force_direction)

				var indicator_center = node.position
				var indicator_direction = Vector2(cos(qubit.theta), sin(qubit.theta))
				var indicator_end = indicator_center + indicator_direction * force_magnitude * sign(force_direction) * 1.5
				draw_line(indicator_center, indicator_end, mushroom_color, 1.0, true)

				icon_influence_arrows_drawn += 1

	if DEBUG_MODE and icon_influence_arrows_drawn > 0:
		print("🎯 Drew %d icon influence force indicators" % icon_influence_arrows_drawn)


func _draw_particles():
	"""Draw energy particles flowing along entanglement lines"""
	for particle in entanglement_particles:
		# Calculate alpha based on remaining life
		var life_ratio = particle.life / PARTICLE_LIFE
		var alpha = clamp(life_ratio, 0.0, 1.0)

		# Outer glow
		var glow_color = particle.color
		glow_color.a = alpha * 0.4
		draw_circle(particle.position, particle.size * 2.0, glow_color)

		# Core particle
		var core_color = Color.WHITE
		core_color.a = alpha * 0.9
		draw_circle(particle.position, particle.size, core_color)


func _draw_icon_particles():
	"""Draw Icon particle field overlay"""
	for particle in icon_particles:
		# Calculate alpha based on remaining life
		var life_ratio = particle.life / ICON_PARTICLE_LIFE
		var alpha = clamp(life_ratio, 0.0, 1.0)

		# Outer glow (softer for environmental effect)
		var glow_color = particle.color
		glow_color.a = alpha * 0.3
		draw_circle(particle.position, ICON_PARTICLE_SIZE * 2.5, glow_color)

		# Core particle (subtle)
		var core_color = particle.color.lightened(0.3)
		core_color.a = alpha * 0.6
		draw_circle(particle.position, ICON_PARTICLE_SIZE, core_color)


## UNIFIED QUANTUM BUBBLE RENDERING
## All quantum entities (plot qubits, celestial qubits) are peer-level
## Rendered with consistent bubble visualization

func _draw_quantum_bubble(node: QuantumNode, is_celestial: bool = false) -> void:
	"""Unified bubble rendering for any quantum entity (peer-level)

	Renders a quantum bubble with:
	- Multi-layer glow (complementary colors or golden)
	- Dark background for emoji contrast
	- Main colored bubble
	- Glossy center highlight
	- State-aware outline (measured vs unmeasured)
	- Dual emoji overlay with superposition opacity
	- SIZE ENCODING: Node size ∝ qubit.radius (coherence)

	Args:
		node: QuantumNode to render
		is_celestial: If true, use golden tint for celestial appearance
	"""
	# Animation scale and alpha
	var anim_scale = node.visual_scale
	var anim_alpha = node.visual_alpha

	if anim_scale <= 0.0:
		return  # Don't draw if not visible

	# Determine if node has been measured (quantum collapse)
	var is_measured = node.plot != null and node.plot.has_been_measured

	# ====================================================================
	# SIZE ENCODING: Node size ∝ qubit.radius (quantum coherence)
	# ====================================================================
	# Base size (minimum radius when coherence is low)
	var base_node_radius = 25.0
	var size_range = 55.0  # Additional radius at maximum coherence

	# Calculate visual radius from qubit coherence (don't modify node.radius!)
	var visual_radius = node.radius  # Default to node's radius
	# Model B: quantum_state no longer exists on plots - use default radius

	# Store visual radius for use in all subsequent rendering (don't modify node.radius)
	# node.radius stays constant for force calculations and other systems

	# ====================================================================
	# COLOR SCHEME: Celestial vs Standard
	# ====================================================================
	var base_color: Color
	var glow_tint: Color
	var is_celestial_render = is_celestial

	# COLOR BRIGHTNESS ENCODING: brightness ∝ qubit.radius (coherence)
	var brightness_factor = 0.3
	# Model B: quantum_state no longer exists - use default brightness

	if is_celestial_render:
		# Celestial: Golden/amber glow
		base_color = Color(1.0, 0.8, 0.2)  # Golden
		glow_tint = base_color
	else:
		# Standard: Use node's quantum-derived color with brightness encoding
		base_color = node.color * Color(brightness_factor, brightness_factor, brightness_factor, 1.0)
		# Complementary color for outer glow (true contrasting hue)
		glow_tint = Color.from_hsv(
			fmod(node.color.h + 0.5, 1.0),  # Opposite hue
			min(node.color.s * 1.3, 1.0),    # Boost saturation
			max(node.color.v * 0.8 * brightness_factor, 0.3)     # Darker for halo, scaled by coherence
		)

	# ====================================================================
	# LAYER 1 & 2: OUTER GLOWS (complementary/golden)
	# ====================================================================
	var glow_alpha = (node.get_glow_alpha() + 0.4) * anim_alpha

	if is_measured and not is_celestial_render:
		# Measured nodes: Bright static cyan glow (ready to harvest!)
		var measured_glow = Color(0.2, 0.95, 1.0)
		measured_glow.a = 0.7 * anim_alpha
		draw_circle(node.position, node.radius * 1.8 * anim_scale, measured_glow)

		measured_glow.a = 0.9 * anim_alpha
		draw_circle(node.position, node.radius * 1.4 * anim_scale, measured_glow)
	else:
		# Unmeasured or celestial: Complementary/golden glow layers
		var outer_glow = glow_tint
		outer_glow.a = glow_alpha * 0.4

		# Outer layer: larger radius for celestial
		var outer_radius = 2.2 if is_celestial_render else 1.6
		draw_circle(node.position, node.radius * outer_radius * anim_scale, outer_glow)

		# Middle glow layer
		var mid_glow = glow_tint
		mid_glow.a = glow_alpha * 0.6
		var mid_radius = 1.8 if is_celestial_render else 1.3
		draw_circle(node.position, node.radius * mid_radius * anim_scale, mid_glow)

	# Inner glow (celestial only - adds warmth)
	if is_celestial_render and glow_alpha > 0:
		var inner_glow = glow_tint.lightened(0.2)
		inner_glow.a = glow_alpha * 0.8
		draw_circle(node.position, node.radius * 1.4 * anim_scale, inner_glow)

	# ====================================================================
	# LAYER 3: Dark background circle (emoji contrast)
	# ====================================================================
	var dark_bg = Color(0.1, 0.1, 0.15, 0.85)
	var bg_radius = 1.12 if is_celestial_render else 1.08
	draw_circle(node.position, node.radius * bg_radius * anim_scale, dark_bg)

	# ====================================================================
	# LAYER 4: Main quantum bubble circle
	# ====================================================================
	var main_color = base_color.lightened(0.15 if not is_celestial_render else 0.1)
	main_color.s = min(main_color.s * 1.2, 1.0)  # More saturated
	main_color.a = 0.75 * anim_alpha
	draw_circle(node.position, node.radius * anim_scale, main_color)

	# ====================================================================
	# LAYER 5: Bright glossy center spot
	# ====================================================================
	var bright_center = base_color.lightened(0.6)
	bright_center.a = 0.8 * anim_alpha
	var spot_size = 0.4 if is_celestial_render else 0.5
	draw_circle(
		node.position + Vector2(-node.radius * 0.25, -node.radius * 0.25) * anim_scale,
		node.radius * spot_size * anim_scale,
		bright_center
	)

	# ====================================================================
	# LAYER 6: Outline (state-aware)
	# ====================================================================
	if is_measured and not is_celestial_render:
		# Measured unmeasured plot: Thick bright cyan outline (collapsed state)
		var measured_outline = Color(0.4, 1.0, 1.0)
		measured_outline.a = 0.98 * anim_alpha
		draw_arc(node.position, node.radius * 1.05 * anim_scale, 0, TAU, 64, measured_outline, 4.0, true)

		# Inner outline for emphasis
		var inner_outline = Color.WHITE
		inner_outline.a = 0.8 * anim_alpha
		draw_arc(node.position, node.radius * 0.98 * anim_scale, 0, TAU, 64, inner_outline, 2.0, true)
	else:
		# Unmeasured or celestial: Subtle outline
		var outline_color: Color
		var outline_width: float

		if is_celestial_render:
			outline_color = Color(1.0, 0.9, 0.3)  # Bright golden
			outline_width = 3.0
		else:
			outline_color = Color.WHITE
			outline_width = 2.5

		outline_color.a = 0.95 * anim_alpha
		draw_arc(node.position, node.radius * 1.02 * anim_scale, 0, TAU, 64, outline_color, outline_width, true)

	# ====================================================================
	# LAYER 6b: THETA ORIENTATION INDICATOR (behavioral direction)
	# ====================================================================
	# For forest organisms: theta indicates hunting/fleeing direction
	# A small arrow on the bubble edge shows which way the organism is "facing"
	if node.biome_name == "Forest" and node.plot and node.plot.quantum_state:
		var qubit = node.plot.quantum_state
		var theta = qubit.theta if "theta" in qubit else PI / 2.0

		# Map theta to visual direction:
		# theta=0 (predatory/north) → pointing up
		# theta=π (prey/south) → pointing down
		# theta=π/2 (neutral) → pointing sideways based on phi
		var phi = qubit.phi if "phi" in qubit else 0.0

		# Direction vector: theta controls vertical, phi controls horizontal
		var dir_y = cos(theta)  # North pole = up, south pole = down
		var dir_x = sin(theta) * cos(phi)  # Equator + phi rotation
		var direction = Vector2(dir_x, -dir_y).normalized()  # Negate y for screen coords

		# Draw orientation indicator at bubble edge
		var indicator_start = node.position + direction * (node.radius * 0.7 * anim_scale)
		var indicator_end = node.position + direction * (node.radius * 1.3 * anim_scale)

		# Color based on state: red for hunting, blue for fleeing, white for neutral
		var indicator_color: Color
		if theta < PI / 3.0:
			indicator_color = Color(1.0, 0.4, 0.3, 0.8)  # Red-orange: predatory
		elif theta > 2.0 * PI / 3.0:
			indicator_color = Color(0.4, 0.7, 1.0, 0.8)  # Blue: prey/fleeing
		else:
			indicator_color = Color(1.0, 1.0, 1.0, 0.5)  # White: neutral

		indicator_color.a *= anim_alpha

		# Draw arrow line
		draw_line(indicator_start, indicator_end, indicator_color, 2.5, true)

		# Draw arrowhead
		var arrow_size = 6.0 * anim_scale
		var perp = direction.rotated(PI / 2.0)
		var arrow_tip = indicator_end
		var arrow_left = arrow_tip - direction * arrow_size + perp * arrow_size * 0.5
		var arrow_right = arrow_tip - direction * arrow_size - perp * arrow_size * 0.5

		var arrow_points = PackedVector2Array([arrow_tip, arrow_left, arrow_right])
		draw_colored_polygon(arrow_points, indicator_color)

	# ====================================================================
	# LAYER 7: DUAL EMOJI SYSTEM (quantum superposition visualization)
	# ====================================================================
	var font = ThemeDB.fallback_font
	var font_size = int(node.radius * (1.1 if is_celestial_render else 1.0))
	var text_pos = node.position - Vector2(font_size * 0.4, -font_size * 0.25)

	# Draw south emoji first (behind north)
	if node.emoji_south != "" and node.emoji_south_opacity > 0.01:
		var south_opacity = node.emoji_south_opacity * (0.9 if is_celestial_render else 1.0)
		_draw_emoji_with_opacity(font, text_pos, node.emoji_south, font_size, south_opacity)

	# Draw north emoji on top (brighter)
	if node.emoji_north != "" and node.emoji_north_opacity > 0.01:
		_draw_emoji_with_opacity(font, text_pos, node.emoji_north, font_size, node.emoji_north_opacity)
	elif node.emoji_north != "" and node.emoji_north_opacity <= 0.01 and node.plot and node.plot.is_planted:
		# DEBUG: Log when a planted plot has zero opacity (shouldn't happen)
		if frame_count % 120 == 0:
			print("⚠️  PLANTED plot with zero opacity: grid=%s, emoji='%s', opacity=%.3f" % [
				node.grid_position, node.emoji_north, node.emoji_north_opacity
			])


func _draw_quantum_nodes():
	"""Draw all plot quantum nodes with unified peer-level rendering

	REFACTOR: Nodes update from current Farm state during rendering
	This eliminates signal coupling and ensures visualization is always in sync
	"""
	var nodes_drawn = 0
	var debug_first_3 = []
	var planted_plots = []

	for node in quantum_nodes:
		# Draw all nodes regardless of quantum state
		# (they'll show as question marks if no quantum state exists)
		if not node.plot:
			continue

		# REFACTOR: Update node from current Farm state before drawing
		# This replaces the signal-based update system
		node.update_from_quantum_state()

		# Track planted plots for debugging
		if node.plot.is_planted:
			planted_plots.append({
				"grid_pos": node.grid_position,
				"emoji": node.emoji_north,
				"opacity": node.emoji_north_opacity,
				"is_planted": node.plot.is_planted
			})

		# Collect debug info for first 3 nodes
		if debug_first_3.size() < 3:
			debug_first_3.append({
				"grid_pos": node.grid_position,
				"pos": node.position,
				"radius": node.radius,
				"opacity": node.emoji_north_opacity,
				"scale": node.visual_scale,
				"planted": node.plot.is_planted if node.plot else false
			})

		# Use unified bubble rendering (is_celestial=false for plot nodes)
		_draw_quantum_bubble(node, false)
		nodes_drawn += 1

	# Log detailed info on every frame (high spam but useful for debugging)
	if DEBUG_MODE and frame_count % 30 == 0:  # Log every 0.5 seconds at 60fps
		print("\n⚛️ Frame %d: %d nodes drawn, %d planted" % [frame_count, nodes_drawn, planted_plots.size()])
		for debug_info in debug_first_3:
			var planted_str = "PLANTED" if debug_info["planted"] else "EMPTY"
			print("   Grid %s: pos=(%.1f, %.1f) r=%.0f opacity=%.2f scale=%.2f [%s]" % [
				debug_info["grid_pos"],
				debug_info["pos"].x,
				debug_info["pos"].y,
				debug_info["radius"],
				debug_info["opacity"],
				debug_info["scale"],
				planted_str
			])
		# Show all planted plots
		if planted_plots.size() > 0:
			print("\n   🌱 PLANTED PLOTS:")
			for p in planted_plots:
				print("      Grid %s: emoji='%s' opacity=%.2f is_planted=%s" % [
					p["grid_pos"],
					p["emoji"],
					p["opacity"],
					p["is_planted"]
				])


func _draw_emoji_with_opacity(font, text_pos: Vector2, emoji: String, font_size: int, opacity: float):
	"""Helper function to draw an emoji with probability-weighted opacity

	Used for quantum superposition visualization - both emojis are drawn overlaid
	with opacity matching their measurement probabilities.
	"""
	# Strong dark shadow/background for contrast (multiple layers)
	var shadow_color = Color(0, 0, 0, 0.8 * opacity)
	for offset_x in [-2, -1, 0, 1, 2]:
		for offset_y in [-2, -1, 0, 1, 2]:
			if offset_x != 0 or offset_y != 0:
				var shadow_pos = text_pos + Vector2(offset_x, offset_y)
				draw_string(font, shadow_pos, emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow_color)

	# Bright white outline for emoji (makes it pop)
	var outline_color = Color(1, 1, 1, 0.6 * opacity)
	for offset_x in [-1, 0, 1]:
		for offset_y in [-1, 0, 1]:
			if abs(offset_x) + abs(offset_y) == 1:  # Only cardinal directions
				var outline_pos = text_pos + Vector2(offset_x * 0.5, offset_y * 0.5)
				draw_string(font, outline_pos, emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, outline_color)

	# Emoji (main) with opacity
	var main_color = Color(1, 1, 1, opacity)
	draw_string(font, text_pos, emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, main_color)


func _draw_sun_qubit_node():
	"""Draw the sun qubit node with pulsing energy aura"""
	"""Draw the sun/moon qubit using unified peer-level quantum bubble rendering

	The sun is rendered as a peer-level quantum entity with:
	- Day/night cycle through theta angle (emoji superposition)
	- Dual emoji representation (☀️ north, 🌙 south)
	- Golden/amber glow to indicate celestial nature (is_celestial=true)
	- Celestial label below the bubble

	The sun/moon qubit is now treated as a quantum entity equal to plot qubits,
	just with a celestial visual tint applied.
	"""
	if not sun_qubit_node:
		return

	# Ensure sun qubit renders with full animation properties
	sun_qubit_node.visual_scale = 1.0  # Always full size
	sun_qubit_node.visual_alpha = 1.0  # Always fully opaque

	# Draw pulsing energy aura (Rabi-like oscillation of intensity)
	if biotic_flux_biome:
		var sun_vis = biotic_flux_biome.get_sun_visualization()
		var energy_strength = abs(cos(sun_vis["theta"]))  # Peaks at noon and midnight

		# Aura expands/contracts with energy strength
		var aura_radius = sun_qubit_node.radius * (1.5 + energy_strength * 0.5)  # 1.5x to 2.0x
		var aura_color = sun_vis["color"]
		aura_color.a = energy_strength * 0.3  # Opacity follows energy
		draw_circle(sun_qubit_node.position, aura_radius, aura_color)

		# Sun rays pulse with energy (only during day/night, not dawn/dusk)
		if energy_strength > 0.3:
			for i in range(8):
				var angle = (TAU / 8.0) * i
				var ray_start = sun_qubit_node.position + Vector2(cos(angle), sin(angle)) * sun_qubit_node.radius
				var ray_end = sun_qubit_node.position + Vector2(cos(angle), sin(angle)) * (sun_qubit_node.radius + 15.0 * energy_strength)
				var ray_color = aura_color
				ray_color.a = energy_strength * 0.6
				draw_line(ray_start, ray_end, ray_color, 1.5, true)

	# Use unified bubble rendering with is_celestial=true for golden appearance
	_draw_quantum_bubble(sun_qubit_node, true)

	# Draw celestial label below sun bubble (identifying label)
	var font = ThemeDB.fallback_font
	var label_color = Color(1.0, 0.85, 0.3, 0.7)
	var label_pos = sun_qubit_node.position + Vector2(0, sun_qubit_node.radius + 25)
	draw_string(font, label_pos, "Celestial", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, label_color)


func _draw_icon_auras():
	"""Draw glowing auras representing Icon influences in the quantum space"""
	if not biotic_icon and not chaos_icon and not imperium_icon:
		return

	# Icon positions (arranged around center)
	var icon_radius = 80.0  # Distance from center

	# Biotic Flux - Upper right (life, growth, order)
	if biotic_icon:
		var biotic_strength = biotic_icon.get_activation()
		if biotic_strength > 0.05:  # Only draw if somewhat active
			var biotic_pos = center_position + Vector2(icon_radius * 0.7, -icon_radius * 0.7)
			_draw_biotic_aura(biotic_pos, biotic_strength)

	# Chaos Icon - Lower left (entropy, conspiracy, chaos)
	if chaos_icon:
		var chaos_strength = chaos_icon.get_activation()
		if chaos_strength > 0.05:
			var chaos_pos = center_position + Vector2(-icon_radius * 0.7, icon_radius * 0.7)
			_draw_chaos_aura(chaos_pos, chaos_strength)

	# Imperium Icon - Right (authority, order, pressure)
	if imperium_icon:
		var imperium_strength = imperium_icon.get_activation()
		if imperium_strength > 0.05:
			var imperium_pos = center_position + Vector2(icon_radius, 0)
			_draw_imperium_aura(imperium_pos, imperium_strength)


func _draw_biotic_aura(pos: Vector2, strength: float):
	"""Draw Biotic Flux aura - bright green, coherent, life-like"""
	var base_radius = 20.0 + (strength * 30.0)  # 20-50 radius
	var color = Color(0.3, 0.8, 0.3)  # Bright green

	# Outer glow layers (multiple for soft effect)
	for i in range(5):
		var layer_radius = base_radius * (1.0 + i * 0.3)
		var layer_alpha = strength * 0.15 * (1.0 - i * 0.2)
		var layer_color = color
		layer_color.a = layer_alpha
		draw_circle(pos, layer_radius, layer_color)

	# Core orb (brighter)
	var core_color = color.lightened(0.3)
	core_color.a = strength * 0.8
	draw_circle(pos, base_radius * 0.7, core_color)

	# Bright center point
	var center_color = Color.WHITE
	center_color.a = strength * 0.6
	draw_circle(pos, base_radius * 0.3, center_color)


func _draw_chaos_aura(pos: Vector2, strength: float):
	"""Draw Chaos aura - dark purple, swirling, chaotic"""
	var base_radius = 20.0 + (strength * 30.0)  # 20-50 radius
	var color = Color(0.5, 0.2, 0.5)  # Dark purple

	# Chaotic outer glow (irregular layers)
	for i in range(6):
		var layer_radius = base_radius * (1.0 + i * 0.25)
		var layer_alpha = strength * 0.12 * (1.0 - i * 0.15)
		var layer_color = color.darkened(i * 0.1)  # Get darker outward
		layer_color.a = layer_alpha
		draw_circle(pos, layer_radius, layer_color)

	# Dark core (vortex center)
	var core_color = color.darkened(0.3)
	core_color.a = strength * 0.7
	draw_circle(pos, base_radius * 0.6, core_color)

	# Purple glow center
	var center_color = color.lightened(0.2)
	center_color.a = strength * 0.5
	draw_circle(pos, base_radius * 0.3, center_color)


func _draw_imperium_aura(pos: Vector2, strength: float):
	"""Draw Imperium aura - golden amber, authoritative"""
	var base_radius = 20.0 + (strength * 30.0)  # 20-50 radius
	var color = Color(0.9, 0.7, 0.2)  # Golden amber

	# Authoritative glow layers
	for i in range(5):
		var layer_radius = base_radius * (1.0 + i * 0.28)
		var layer_alpha = strength * 0.14 * (1.0 - i * 0.18)
		var layer_color = color
		layer_color.a = layer_alpha
		draw_circle(pos, layer_radius, layer_color)

	# Golden core
	var core_color = color.lightened(0.2)
	core_color.a = strength * 0.75
	draw_circle(pos, base_radius * 0.65, core_color)

	# Bright golden center
	var center_color = Color(1.0, 0.9, 0.5)
	center_color.a = strength * 0.6
	draw_circle(pos, base_radius * 0.35, center_color)


func _draw_strange_attractor():
	"""Draw the agricultural-political strange attractor from Carrion Throne

	Visualizes the 4D political season cycle as a 2D trajectory.
	Shows institutional memory and cultural evolution patterns.
	"""
	if not imperium_icon:
		return

	# Check if this is a CarrionThroneIcon with attractor data
	if not imperium_icon.has_method("get_attractor_history"):
		return

	var history = imperium_icon.get_attractor_history()
	if history.is_empty():
		return

	# Draw the attractor trajectory
	var attractor_color = Color(0.7, 0.6, 0.2, 0.4)  # Cold gold, semi-transparent
	var attractor_offset = center_position + Vector2(200, 200)  # Bottom-right corner

	# Draw fade-in trail (older points fade out)
	for i in range(1, history.size()):
		var prev_snapshot = history[i - 1]
		var curr_snapshot = history[i]

		# Project 4D to 2D
		var prev_2d = imperium_icon.project_4d_to_2d(prev_snapshot)
		var curr_2d = imperium_icon.project_4d_to_2d(curr_snapshot)

		# Screen positions
		var prev_pos = attractor_offset + prev_2d
		var curr_pos = attractor_offset + curr_2d

		# Fade factor (newer points brighter)
		var fade = float(i) / float(history.size())
		var line_color = attractor_color
		line_color.a = fade * 0.5

		# Draw line segment
		draw_line(prev_pos, curr_pos, line_color, 2.0, true)

	# Draw current position as bright point
	if history.size() > 0:
		var current = history[history.size() - 1]
		var current_2d = imperium_icon.project_4d_to_2d(current)
		var current_pos = attractor_offset + current_2d

		# Bright golden point
		draw_circle(current_pos, 5.0, Color(1.0, 0.8, 0.3, 0.8))
		draw_circle(current_pos, 3.0, Color(1.0, 0.9, 0.5, 1.0))

	# Draw label
	var label_pos = attractor_offset + Vector2(-80, -90)
	var label_color = Color(0.8, 0.7, 0.3, 0.7)
	var font = ThemeDB.fallback_font
	var season = imperium_icon.get_political_season() if imperium_icon.has_method("get_political_season") else ""
	draw_string(font, label_pos, "Political Season", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)
	if season != "":
		draw_string(font, label_pos + Vector2(0, 16), season, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_color.lightened(0.2))


func get_node_at_position(pos: Vector2) -> QuantumNode:
	"""Get quantum node at screen position (for hover/click)"""
	for node in quantum_nodes:
		var distance = node.position.distance_to(pos)
		if distance <= node.radius:
			print("🖱️ Node found at %s (distance: %.1f, radius: %.1f)" % [node.grid_position, distance, node.radius])
			return node
	print("🖱️ No node found at pos %s (checked %d nodes)" % [pos, quantum_nodes.size()])
	return null


func highlight_node(node: QuantumNode):
	"""Highlight a quantum node (called when classical plot hovered)"""
	# Could add visual effect here
	# For now, handled by rendering order
	pass


func get_stats() -> Dictionary:
	"""Get statistics about the quantum graph"""
	var active_nodes = 0
	var total_entanglements = 0

	for node in quantum_nodes:
		if node.plot and node.plot.is_planted and node.plot.quantum_state:
			active_nodes += 1
			# Use WheatPlot.entangled_plots (the ACTUAL entanglement data)
			total_entanglements += node.plot.entangled_plots.size()

	return {
		"total_nodes": quantum_nodes.size(),
		"active_nodes": active_nodes,
		"total_entanglements": total_entanglements / 2  # Divide by 2 (bidirectional)
	}


func _draw_debug_node_positions():
	"""Draw small circles at each quantum node position to verify scaling"""
	var circle_radius = 8.0
	for node in quantum_nodes:
		if not node.plot:
			continue
		# Draw a small debug circle at the node position
		var color = Color(0.0, 1.0, 1.0, 0.5)  # Cyan, semi-transparent
		draw_circle(node.position, circle_radius, color)

		# Draw position text
		var font = ThemeDB.fallback_font
		var text_pos = node.position + Vector2(-15, -15)
		draw_string(font, text_pos, "[%d,%d]" % [node.grid_position.x, node.grid_position.y],
			HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0, 1, 1, 0.7))


func print_snapshot(reason: String = ""):
	"""Print a snapshot of the current graph state (call on state changes)"""
	if not DEBUG_MODE:
		return

	var stats = get_stats()
	print("\n⚛️ ===== QUANTUM GRAPH SNAPSHOT =====")
	if reason != "":
		print("⚛️ Reason: %s" % reason)
	print("⚛️ Total nodes: %d" % stats.total_nodes)
	print("⚛️ Active (planted): %d" % stats.active_nodes)
	print("⚛️ Entanglements: %d" % stats.total_entanglements)

	# Show entangled pairs
	if stats.total_entanglements > 0:
		print("⚛️ Entangled pairs:")
		var printed_pairs = {}
		for node in quantum_nodes:
			if not node.plot:
				continue
			# Use WheatPlot.entangled_plots (the ACTUAL entanglement data)
			for partner_id in node.plot.entangled_plots.keys():
				var partner_node = node_by_plot_id.get(partner_id)
				if partner_node:
					var ids = [node.plot_id, partner_id]
					ids.sort()
					var pair_key = "%s_%s" % [ids[0], ids[1]]
					if not printed_pairs.has(pair_key):
						print("  %s ↔ %s" % [node.grid_position, partner_node.grid_position])
						printed_pairs[pair_key] = true

	print("⚛️ ===================================\n")
