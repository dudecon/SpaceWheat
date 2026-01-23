class_name PlotGridDisplay
extends Control

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = get_node("/root/VerboseConfig")

## INPUT CONTRACT (Layer 3 - Mouse Drag Selection)
## ═══════════════════════════════════════════════════════════════
## PHASE: _input() - Runs after FarmInputHandler
## HANDLES: InputEventMouseButton, InputEventMouseMotion, InputEventScreenTouch
## PURPOSE: Multi-plot drag selection across the grid
## CONSUMES: ONLY when click/touch IS on a plot tile
## PASSES: All clicks NOT on plot tiles → allows bubble taps to reach Layer 5
## CRITICAL: Must NOT block non-plot clicks
## ═══════════════════════════════════════════════════════════════
##
## PlotGridDisplay - Visual representation of parametric plot grid around biomes
## Creates and manages PlotTile instances positioned in oval rings around biome centers
## Handles selection, planting visualization, and signal updates
##
## Architecture: Plots are the FOUNDATION (fixed parametric positions)
## QuantumForceGraph reads these positions and tethers quantum bubbles to them

const PlotTile = preload("res://UI/PlotTile.gd")
const GridConfig = preload("res://Core/GameState/GridConfig.gd")
const BiomeLayoutCalculator = preload("res://Core/Visualization/BiomeLayoutCalculator.gd")

# Single-biome view: Only show tiles for the active biome
var active_biome_manager: Node = null

# References
var farm: Node = null
var ui_controller: Node = null
var layout_manager: Node = null
var grid_config: GridConfig = null  # Grid configuration (Phase 7)
var biomes: Dictionary = {}  # biome_name -> BiomeBase (injected via layout manager)

# Plot tiles (Vector2i -> PlotTile)
var tiles: Dictionary = {}

# Parametric positioning - SINGLE source of truth
var layout_calculator: BiomeLayoutCalculator = null
var classical_plot_positions: Dictionary = {}  # Vector2i (grid) → Vector2 (screen position)

# Multi-select management (INLINED - no separate SelectionManager)
var selected_plots: Dictionary = {}  # Vector2i -> true (which plots are selected)

# Backward compatibility: also track last single-click for operations
var current_selection: Vector2i = Vector2i.ZERO

# Drag/swipe selection state
var is_dragging: bool = false
var drag_plots: Dictionary = {}  # Plots touched during this drag
var drag_start_pos: Vector2i = Vector2i(-1, -1)
var _skip_next_click: bool = false  # Skip click handler after multi-plot drag

# Signals for selection state changes
signal selection_count_changed(count: int)

# Rejection effects (for visual feedback when actions are rejected)
var rejection_effects: Array[Dictionary] = []  # [{grid_pos, start_time, reason}]
const REJECTION_EFFECT_DURATION = 1.0  # How long the effect lasts (seconds)
var time_accumulator: float = 0.0


func _ready():
	"""Initialize plot grid display with parametric positioning"""
	_verbose.debug("ui", "🌾", "PlotGridDisplay._ready() called (Instance: %s, child_count before: %d)" % [get_instance_id(), get_child_count()])

	# Safety check: if tiles already exist, DON'T recreate them
	if tiles.size() > 0:
		_verbose.warn("ui", "⚠️", "WARNING: PlotGridDisplay._ready() called but tiles already exist! tile_count=%d" % tiles.size())
		_verbose.warn("ui", "", "This suggests _ready() was called multiple times on the same instance!")
		return

	# Configure this Control for absolute positioning
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = false  # Allow tiles to extend beyond container (they're spread around field)

	# Initialize selection (inlined - no separate manager)
	selected_plots = {}

	# REFACTORING: Create tiles immediately in _ready()
	# Dependencies (grid_config, biomes) are injected BEFORE add_child(), so they're available now
	if grid_config == null:
		_verbose.warn("ui", "⚠️", "PlotGridDisplay: grid_config is null - will be set later")
		return
	if biomes.is_empty():
		_verbose.warn("ui", "⚠️", "PlotGridDisplay: biomes is empty - will be set later")
		return

	# Calculate positions and create tiles SYNCHRONOUSLY
	_calculate_parametric_positions()
	_create_tiles()

	# Connect to ActiveBiomeManager for single-biome view filtering
	_connect_to_biome_manager()

	_verbose.info("ui", "✅", "PlotGridDisplay ready - %d tiles created synchronously (child_count after: %d)" % [tiles.size(), get_child_count()])

	# TouchInputManager connection now happens in _create_tiles() after tiles are created

	# Enable processing for rejection effects animation
	set_process(true)




func show_rejection_effect(action: String, grid_pos: Vector2i, reason: String) -> void:
	"""Show visual feedback when an action is rejected at a plot

	Creates a red pulsing circle effect at the plot position.

	Args:
		action: What action was rejected (e.g., "build_wheat")
		grid_pos: Grid position where the rejection occurred
		reason: Why the action was rejected
	"""
	rejection_effects.append({
		"grid_pos": grid_pos,
		"start_time": time_accumulator,
		"reason": reason
	})
	queue_redraw()  # Trigger immediate visual update


func inject_grid_config(config: GridConfig) -> void:
	"""Inject grid configuration - tiles will be created after biomes are injected"""
	if not config:
		push_error("PlotGridDisplay: Attempted to inject null GridConfig!")
		return

	grid_config = config

	# Validate configuration
	var validation = config.validate()
	if not validation.success:
		push_error("PlotGridDisplay: GridConfig validation failed:")
		for error in validation.errors:
			push_error("  - %s" % error)
		return

	_verbose.info("ui", "💉", "GridConfig injected into PlotGridDisplay")
	_verbose.debug("ui", "⏳", "Tiles will be created once biomes are injected")


func inject_layout_calculator(calculator: BiomeLayoutCalculator) -> void:
	"""Inject shared BiomeLayoutCalculator (SINGLE source of truth)

	Can be called before OR after inject_biomes() - will trigger calculation when ready.
	The calculator instance should come from QuantumForceGraph.layout_calculator.
	"""
	layout_calculator = calculator
	_verbose.info("ui", "💉", "BiomeLayoutCalculator injected into PlotGridDisplay")

	# If biomes are already injected, calculate positions and create tiles now
	if not biomes.is_empty() and grid_config and tiles.size() == 0:
		_verbose.debug("ui", "🎨", "Layout calculator now available - calculating positions...")
		_calculate_parametric_positions()
		_create_tiles()
		_connect_to_biome_manager()
		_verbose.info("ui", "✅", "Tiles created after layout_calculator injection")


func inject_biomes(biomes_dict: Dictionary) -> void:
	"""Inject biome objects for parametric positioning"""
	biomes = biomes_dict
	_verbose.info("ui", "💉", "Biomes injected into PlotGridDisplay (%d biomes)" % biomes.size())

	# If layout_calculator is already available, calculate positions now
	# Otherwise, positions will be calculated when inject_layout_calculator() is called
	if layout_calculator:
		_calculate_parametric_positions()

		# Create tiles NOW that we have positions
		if tiles.size() == 0 and grid_config:
			_verbose.debug("ui", "🎨", "Creating tiles with parametric positions...")
			_create_tiles()
			_connect_to_biome_manager()
			_verbose.info("ui", "✅", "Tiles created after biome injection")
	else:
		_verbose.debug("ui", "⏳", "Waiting for layout_calculator injection before positioning tiles...")


func _calculate_parametric_positions() -> void:
	"""Calculate parametric plot positions - delegates to unified function"""
	if not grid_config:
		_verbose.warn("ui", "⚠️", "PlotGridDisplay: GridConfig not available")
		return

	if biomes.is_empty():
		_verbose.warn("ui", "⚠️", "PlotGridDisplay: Biomes not injected yet")
		return

	if not layout_calculator:
		push_error("PlotGridDisplay: layout_calculator not injected! Call inject_layout_calculator() first.")
		return

	# Get active biome from manager (or default to first biome)
	var active_biome = ""
	var biome_mgr = get_node_or_null("/root/ActiveBiomeManager")
	if biome_mgr and biome_mgr.has_method("get_active_biome"):
		active_biome = biome_mgr.get_active_biome()

	if active_biome == "" and biomes.size() > 0:
		active_biome = biomes.keys()[0]
		_verbose.debug("ui", "📐", "No active biome set, defaulting to '%s'" % active_biome)

	_verbose.debug("ui", "📐", "Initial layout for active biome: '%s'" % active_biome)

	# Use unified function - same code path as biome switching
	_update_layout_for_active_biome(active_biome)

	_verbose.info("ui", "✅", "PlotGridDisplay: Calculated %d positions (unified path)" % classical_plot_positions.size())


func _create_tiles() -> void:
	"""Create plot tiles with parametric positioning around biomes"""
	# Guard: Don't create tiles if they already exist
	if tiles.size() > 0:
		_verbose.warn("ui", "⚠️", "PlotGridDisplay._create_tiles(): Tiles already exist (%d), skipping" % tiles.size())
		return

	if not grid_config:
		_verbose.warn("ui", "⚠️", "PlotGridDisplay._create_tiles(): GridConfig not available")
		return

	# Get all active plots
	var active_plots = grid_config.get_all_active_plots()
	_verbose.debug("ui", "🌾", "Creating %d plot tiles with parametric positioning..." % active_plots.size())
	_verbose.debug("ui", "📍", "Classical positions available: %d" % classical_plot_positions.size())
	_verbose.debug("ui", "🔷", "Biomes available: %d" % biomes.size())
	_verbose.debug("ui", "📏", "PlotGridDisplay size: %s" % size)
	_verbose.debug("ui", "📍", "PlotGridDisplay global_position: %s" % global_position)
	_verbose.debug("ui", "📍", "PlotGridDisplay position: %s" % position)

	var positioned_count = 0
	var fallback_count = 0

	for plot_config in active_plots:
		var pos = plot_config.position
		if positioned_count < 3:
			_verbose.debug("ui", "🔍", "Checking plot at %s - in positions? %s" % [pos, classical_plot_positions.has(pos)])

		# Create tile
		var tile = PlotTile.new()
		tile.grid_position = pos  # CRITICAL: Set the tile's grid position so it emits correctly
		tile.custom_minimum_size = Vector2(90, 90)

		# CRITICAL: Disable layout mode so position is respected
		tile.set_anchors_preset(Control.PRESET_TOP_LEFT)
		tile.set_anchor(SIDE_LEFT, 0.0)
		tile.set_anchor(SIDE_TOP, 0.0)
		tile.set_anchor(SIDE_RIGHT, 0.0)
		tile.set_anchor(SIDE_BOTTOM, 0.0)
		tile.layout_mode = 0  # No layout container

		## REMOVED: tile.clicked.connect() - signal never fires because PlotTile has mouse_filter=IGNORE
		## Plot clicks are handled by PlotGridDisplay._input() using _get_plot_at_screen_position()

		# Position absolutely based on parametric position
		if classical_plot_positions.has(pos):
			var screen_pos = classical_plot_positions[pos]
			# Convert from screen coordinates to local PlotGridDisplay coordinates
			var local_pos = get_global_transform().affine_inverse() * screen_pos
			# Center the tile on the position
			tile.position = local_pos - tile.custom_minimum_size / 2
			positioned_count += 1
			if positioned_count <= 3:  # Only log first 3
				_verbose.debug("ui", "📍", "Tile grid %s → screen (%.1f, %.1f) → local (%.1f, %.1f) → final (%.1f, %.1f)" % [
					pos, screen_pos.x, screen_pos.y, local_pos.x, local_pos.y,
					tile.position.x, tile.position.y
				])
				_verbose.debug("ui", "", "PlotGridDisplay global_transform.origin: %s" % get_global_transform().origin)
		else:
			# Tile is in another biome - hide it until that biome is active
			tile.visible = false
			fallback_count += 1

		add_child(tile)
		tiles[pos] = tile

		# Set keyboard label from grid config synchronously (tile is already created, no need to defer)
		var label = plot_config.keyboard_label if plot_config.keyboard_label else ""
		if label:
			tile.set_label_text(label)

	if positioned_count > 3:
		_verbose.debug("ui", "📍", "... and %d more tiles positioned parametrically" % (positioned_count - 3))

	_verbose.info("ui", "✅", "Created %d plot tiles: %d positioned parametrically, %d without positions" % [tiles.size(), positioned_count, fallback_count])

	# Connect to TouchInputManager for touch selection (do it here after tiles are created)
	# CONNECT_DEFERRED ensures bubbles process tap first (they connect without DEFERRED)
	if TouchInputManager and not TouchInputManager.tap_detected.is_connected(_on_touch_tap):
		TouchInputManager.tap_detected.connect(_on_touch_tap, CONNECT_DEFERRED)
		_verbose.info("ui", "✅", "Touch: Tap-to-select connected with DEFERRED (bubbles have priority)")


## ═══════════════════════════════════════════════════════════════════════════════
## SINGLE-BIOME VIEW FILTERING
## ═══════════════════════════════════════════════════════════════════════════════

func _connect_to_biome_manager() -> void:
	"""Connect to ActiveBiomeManager for single-biome view (idempotent - safe to call multiple times)"""
	# Skip if already fully connected and initialized
	if _biome_manager_connected:
		return

	active_biome_manager = get_node_or_null("/root/ActiveBiomeManager")
	if active_biome_manager:
		if not active_biome_manager.active_biome_changed.is_connected(_on_active_biome_changed):
			active_biome_manager.active_biome_changed.connect(_on_active_biome_changed)
			_verbose.info("ui", "📡", "PlotGridDisplay connected to ActiveBiomeManager")

		# Apply initial biome filter only once (when tiles exist)
		if tiles.size() > 0:
			_filter_tiles_for_biome(active_biome_manager.get_active_biome())
			_biome_manager_connected = true  # Mark as fully initialized
	else:
		_verbose.warn("ui", "⚠️", "ActiveBiomeManager not found - showing all tiles")


func _on_active_biome_changed(new_biome: String, _old_biome: String) -> void:
	"""Handle biome change - recalculate positions and show only tiles for the new biome"""
	_verbose.debug("ui", "🔄", "PlotGridDisplay: Biome changed to %s" % new_biome)

	# CRITICAL: Recalculate layout with new active_biome for proper centering
	_update_layout_for_active_biome(new_biome)

	_filter_tiles_for_biome(new_biome)


func _update_layout_for_active_biome(biome_name: String) -> void:
	"""UNIFIED: Calculate and apply positions for the active biome (single-biome view)

	This is the SINGLE function for position calculation. Used for:
	- Initial load (called from _calculate_parametric_positions)
	- Biome switching (called from _on_active_biome_changed)
	"""
	if not layout_calculator or not grid_config or biomes.is_empty():
		return

	# Get viewport size for layout calculation
	var viewport = get_viewport()
	var viewport_size = viewport.get_visible_rect().size if viewport else Vector2(1280, 720)

	# Compute layout centered on active biome
	layout_calculator.compute_layout(biomes, viewport_size, biome_name)

	_verbose.debug("ui", "📐", "Layout for '%s': center=%s, radius=%.1f" % [
		biome_name, layout_calculator.graph_center, layout_calculator.graph_radius
	])

	# Get plots in this biome
	var plots_in_biome: Array[Vector2i] = []
	for plot_config in grid_config.get_all_active_plots():
		var plot_biome = grid_config.get_biome_for_plot(plot_config.position)
		if plot_biome == biome_name:
			plots_in_biome.append(plot_config.position)

	if plots_in_biome.is_empty():
		return

	# Get screen positions - use FIXED hex layout for 6 plots (same size for all biomes)
	var screen_positions: Array[Vector2] = []
	if plots_in_biome.size() == 6:
		# Use fixed hex positions (same size, 1.67:1 aspect ratio for all biomes)
		screen_positions = layout_calculator.get_hex_screen_positions()
		_verbose.debug("ui", "⬡", "Using FIXED hex layout (1.67:1 aspect ratio)")
	else:
		# Fall back to parametric for non-6 plot counts
		var parametric_coords = layout_calculator.distribute_nodes_in_biome(biome_name, plots_in_biome.size())
		for params in parametric_coords:
			screen_positions.append(layout_calculator.get_parametric_position(
				biome_name, params["t"], params["ring"]
			))

	# Apply positions to tiles
	for i in range(plots_in_biome.size()):
		if i >= screen_positions.size():
			break

		var grid_pos = plots_in_biome[i]
		var screen_pos = screen_positions[i]

		# Store in classical_plot_positions
		classical_plot_positions[grid_pos] = screen_pos

		# If tile exists, reposition it (handles biome switching)
		if tiles.has(grid_pos):
			var tile = tiles[grid_pos]
			var tile_size = tile.custom_minimum_size if tile.custom_minimum_size != Vector2.ZERO else Vector2(90, 90)
			# Convert screen coords to local coords (CRITICAL: same transform as _create_tiles)
			var local_pos = get_global_transform().affine_inverse() * screen_pos
			tile.position = local_pos - tile_size / 2.0

	_verbose.debug("ui", "✅", "Positioned %d plots for '%s'" % [plots_in_biome.size(), biome_name])


func _filter_tiles_for_biome(biome_name: String) -> void:
	"""Show only tiles that belong to the specified biome"""
	if not grid_config:
		return

	var visible_count = 0
	var hidden_count = 0

	for pos in tiles.keys():
		var tile = tiles[pos]
		var tile_biome = grid_config.get_biome_for_plot(pos)

		if tile_biome == biome_name:
			tile.visible = true
			visible_count += 1
		else:
			tile.visible = false
			hidden_count += 1

	_verbose.debug("ui", "👁️", "Biome filter: %d tiles visible (%s), %d hidden" % [visible_count, biome_name, hidden_count])

	# Clear selection when changing biomes (plots from other biomes may be selected)
	_clear_selection_for_other_biomes(biome_name)


func _clear_selection_for_other_biomes(active_biome: String) -> void:
	"""Clear selections for plots not in the active biome"""
	var cleared_count = 0
	var to_clear: Array[Vector2i] = []

	for pos in selected_plots.keys():
		var plot_biome = grid_config.get_biome_for_plot(pos) if grid_config else ""
		if plot_biome != active_biome:
			to_clear.append(pos)

	for pos in to_clear:
		selected_plots.erase(pos)
		if tiles.has(pos):
			tiles[pos].set_checkbox_selected(false)
		cleared_count += 1

	if cleared_count > 0:
		_verbose.debug("ui", "🗑️", "Cleared %d selections from non-active biomes" % cleared_count)
		selection_count_changed.emit(selected_plots.size())


func inject_farm(farm_ref: Node) -> void:
	"""Inject farm reference and connect to plot change signals"""
	farm = farm_ref
	if not farm:
		return

	# Update all tiles with farm data
	for pos in tiles.keys():
		update_tile_from_farm(pos)

	# PHASE 4: Connect to farm signals so PlotGridDisplay updates when plots change
	# Since PlotGridDisplay is now the primary visualization (QuantumForceGraph not integrated),
	# we need these connections to show emoji updates when planting/measuring/harvesting
	if farm.has_signal("plot_planted"):
		if not farm.plot_planted.is_connected(_on_farm_plot_planted):
			farm.plot_planted.connect(_on_farm_plot_planted)
			_verbose.debug("ui", "📡", "Connected to farm.plot_planted")
	if farm.has_signal("plot_measured"):
		if not farm.plot_measured.is_connected(_on_farm_plot_measured):
			farm.plot_measured.connect(_on_farm_plot_measured)
			_verbose.debug("ui", "📡", "Connected to farm.plot_measured")
	if farm.has_signal("plot_harvested"):
		if not farm.plot_harvested.is_connected(_on_farm_plot_harvested):
			farm.plot_harvested.connect(_on_farm_plot_harvested)
			_verbose.debug("ui", "📡", "Connected to farm.plot_harvested")

	# Connect to entanglement signals from FarmGrid
	if farm.grid and farm.grid.has_signal("entanglement_created"):
		if not farm.grid.entanglement_created.is_connected(_on_entanglement_created):
			farm.grid.entanglement_created.connect(_on_entanglement_created)
			_verbose.debug("ui", "📡", "Connected to farm.grid.entanglement_created")

	# Connect to visualization_changed signal for gate/entanglement redraws
	if farm.grid and farm.grid.has_signal("visualization_changed"):
		if not farm.grid.visualization_changed.is_connected(queue_redraw):
			farm.grid.visualization_changed.connect(queue_redraw)
			_verbose.debug("ui", "📡", "Connected to farm.grid.visualization_changed")

	# Connect to terminal_bound for EXPLORE action tile updates
	if farm.has_signal("terminal_bound"):
		if not farm.terminal_bound.is_connected(_on_terminal_bound):
			farm.terminal_bound.connect(_on_terminal_bound)
			_verbose.debug("ui", "📡", "Connected to farm.terminal_bound")

	# Connect to structure_built for industry building tile updates
	if farm.has_signal("structure_built"):
		if not farm.structure_built.is_connected(_on_structure_built):
			farm.structure_built.connect(_on_structure_built)
			_verbose.debug("ui", "📡", "Connected to farm.structure_built")

	_verbose.info("ui", "💉", "Farm injected into PlotGridDisplay")


func rebuild_from_grid() -> void:
	"""Phase 5: Rebuild plot tiles from grid configuration after loading a save

	Called by GameStateManager.apply_state_to_game() to rebuild UI from simulation.
	This clears old tiles and recreates them based on current grid_config and farm state.
	"""
	_verbose.info("ui", "🔄", "PlotGridDisplay: Rebuilding from grid configuration...")

	# Clear existing tiles
	for tile in tiles.values():
		tile.queue_free()
	tiles.clear()

	# Recreate tiles if we have the necessary data
	if grid_config and not biomes.is_empty():
		_calculate_parametric_positions()
		_create_tiles()

		# Apply biome filter for single-biome view
		if active_biome_manager:
			_filter_tiles_for_biome(active_biome_manager.get_active_biome())

		# Update tiles with current farm data if farm is available
		if farm:
			for pos in tiles.keys():
				update_tile_from_farm(pos)

			_verbose.info("ui", "✅", "PlotGridDisplay rebuilt: %d tiles recreated and synced with farm" % tiles.size())
	else:
		_verbose.warn("ui", "⚠️", "PlotGridDisplay rebuild incomplete: grid_config=%s, biomes=%d" % [
			"available" if grid_config else "null",
			biomes.size()
		])


func inject_ui_controller(controller: Node) -> void:
	"""Inject UI controller for callbacks"""
	ui_controller = controller
	_verbose.debug("ui", "📡", "UI controller injected into PlotGridDisplay")


func wire_to_farm(farm_ref: Node) -> void:
	"""Standard wiring interface for FarmUIController

	This method encapsulates all initialization needed when a farm is injected.
	Called by FarmUIController during farm injection phase.
	"""
	inject_farm(farm_ref)
	_verbose.debug("ui", "📡", "PlotGridDisplay wired to farm")


func set_selected_plot(pos: Vector2i) -> void:
	"""Update visual selection to show which plot is selected"""
	# Clear previous selection
	for tile_pos in tiles.keys():
		tiles[tile_pos].set_selected(false)

	# Highlight new selection
	if tiles.has(pos):
		current_selection = pos
		tiles[pos].set_selected(true)
		_verbose.debug("ui", "🎯", "Selected plot: %s" % pos)


func update_tile_from_farm(pos: Vector2i) -> void:
	"""PHASE 4: Update tile visual state directly from farm plot data

	Transforms farm plot state into PlotUIData inline (no FarmUIState layer).
	"""
	if not tiles.has(pos):
		_verbose.debug("ui", "✗", "update_tile_from_farm(%s): tile not found!" % pos)
		return

	if not farm:
		_verbose.debug("ui", "✗", "update_tile_from_farm(%s): farm is null!" % pos)
		var tile = tiles[pos]
		tile.set_plot_data(null, pos, -1)
		return

	if not farm.grid:
		_verbose.debug("ui", "✗", "update_tile_from_farm(%s): farm.grid is null!" % pos)
		var tile = tiles[pos]
		tile.set_plot_data(null, pos, -1)
		return

	var plot = farm.grid.get_plot(pos)
	var terminal = null

	# Check for terminal-bound state (from EXPLORE action)
	if farm.plot_pool:
		terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)

	if not plot and not terminal:
		# Truly empty plot - no plot object and no terminal
		_verbose.debug("ui", "⚠️", "update_tile_from_farm(%s): plot is null/empty and no terminal" % pos)
		var tile = tiles[pos]
		tile.set_plot_data(null, pos, -1)
		return

	# Transform plot/terminal → PlotUIData inline
	_verbose.debug("ui", "✓", "update_tile_from_farm(%s): found plot=%s, terminal=%s" % [pos, plot != null, terminal != null])
	var ui_data = _transform_plot_to_ui_data(pos, plot, terminal)
	var tile = tiles[pos]
	tile.set_plot_data(ui_data, pos, -1)
	_verbose.debug("ui", "🌾", "PlotGridDisplay updating tile for plot %s" % pos)


## PHASE 4: PLOT TRANSFORMATION HELPER

func _transform_plot_to_ui_data(pos: Vector2i, plot, terminal = null) -> Dictionary:
	"""Transform WheatPlot/Terminal state → PlotUIData dictionary

	This inline transformation replaces the FarmUIState layer for real-time updates.
	Handles both:
	- Traditional planted plots (plot.is_planted)
	- Terminal-bound plots from EXPLORE action (terminal.is_bound)
	"""
	# Get entangled plots from the plot data
	var entangled_list = []
	if plot and plot.entangled_plots:
		entangled_list = plot.entangled_plots.keys()

	var ui_data = {
		"position": pos,
		"is_planted": (plot and plot.is_planted) or (terminal and terminal.is_bound),
		"plot_type": _get_plot_type_string(plot.plot_type) if plot else "terminal",
		"north_emoji": "",
		"south_emoji": "",
		"north_probability": 0.0,
		"south_probability": 0.0,
		"energy_level": 0.0,
		"coherence": 0.0,
		"has_been_measured": (plot and plot.has_been_measured) or (terminal and terminal.is_measured),
		"entangled_plots": entangled_list
	}

	# CASE 1: Terminal-bound (from EXPLORE action) - takes priority for emoji display
	if terminal and terminal.is_bound:
		ui_data["north_emoji"] = terminal.north_emoji
		ui_data["south_emoji"] = terminal.south_emoji

		# Get probabilities from biome's quantum_computer
		var north_prob = 0.5
		var south_prob = 0.5
		var biome = terminal.bound_biome

		if biome and biome.quantum_computer:
			north_prob = biome.get_emoji_probability(terminal.north_emoji)
			south_prob = biome.get_emoji_probability(terminal.south_emoji)

			# Normalize to ensure they sum to 1.0
			var total = north_prob + south_prob
			if total > 0.0:
				north_prob /= total
				south_prob /= total

		ui_data["north_probability"] = north_prob
		ui_data["south_probability"] = south_prob

		# If measured, show the measured outcome
		if terminal.is_measured:
			ui_data["has_been_measured"] = true
			# Set probability to 1.0 for measured outcome
			if terminal.measured_outcome == "north":
				ui_data["north_probability"] = 1.0
				ui_data["south_probability"] = 0.0
			else:
				ui_data["north_probability"] = 0.0
				ui_data["south_probability"] = 1.0

	# CASE 2: Traditional planted plot (no terminal, or terminal doesn't override)
	elif plot and plot.is_planted and plot.parent_biome and plot.bath_subplot_id >= 0:
		var emojis = plot.get_plot_emojis()
		ui_data["north_emoji"] = emojis["north"]
		ui_data["south_emoji"] = emojis["south"]

		# Model C: Get probabilities from parent biome's quantum_computer
		var north_prob = 0.5  # Default fallback
		var south_prob = 0.5  # Default fallback

		if plot.parent_biome.quantum_computer:
			# Query quantum_computer for actual emoji probabilities
			north_prob = plot.parent_biome.get_emoji_probability(emojis["north"])
			south_prob = plot.parent_biome.get_emoji_probability(emojis["south"])

			# Normalize to ensure they sum to 1.0 (for display purposes)
			var total = north_prob + south_prob
			if total > 0.0:
				north_prob /= total
				south_prob /= total

		ui_data["north_probability"] = north_prob
		ui_data["south_probability"] = south_prob

		# Energy is now purity (Tr(ρ²)) from plot's quantum state
		ui_data["energy_level"] = plot.get_purity() if plot.has_method("get_purity") else 0.5

		# Get coherence from parent biome if available
		ui_data["coherence"] = 0.0

	return ui_data


func _get_plot_type_string(plot_type_enum: int) -> String:
	"""Convert WheatPlot.PlotType enum to string"""
	match plot_type_enum:
		0: return "wheat"
		1: return "tomato"
		2: return "mushroom"
		3: return "mill"
		4: return "market"
		5: return "kitchen"
		6: return "energy_tap"
		7: return "fire"
		8: return "water"
		9: return "flour"
		_: return "empty"


func refresh_all_tiles() -> void:
	"""Refresh all tiles from current farm state (used after save/load)"""
	_verbose.info("ui", "🔄", "PlotGridDisplay: Refreshing all tiles...")
	for pos in tiles.keys():
		update_tile_from_farm(pos)
	_verbose.info("ui", "✅", "PlotGridDisplay: All %d tiles refreshed" % tiles.size())


func _on_tile_clicked(pos: Vector2i) -> void:
	"""Handle tile click - toggle plot selection (same as keyboard TYUIOP keys)"""
	# Skip if we just completed a multi-plot drag (prevents double-select)
	if _skip_next_click:
		_skip_next_click = false
		_verbose.debug("ui", "🖱️", "Click skipped (multi-drag just completed)")
		return

	_verbose.debug("ui", "🖱️", "Plot tile clicked: %s" % pos)
	toggle_plot_selection(pos)  # Multi-select toggle like keyboard

	# Notify controllers
	if ui_controller and ui_controller.has_method("on_plot_selected"):
		ui_controller.on_plot_selected(pos)


## PHASE 4: DIRECT FARM SIGNAL HANDLERS (bypass FarmUIState)

func _on_farm_plot_planted(pos: Vector2i, plant_type: String) -> void:
	"""Handle plot planted event from farm - PHASE 4: Direct signal"""
	_verbose.debug("ui", "🌱", "Farm.plot_planted received at PlotGridDisplay")
	update_tile_from_farm(pos)


func _on_farm_plot_measured(pos: Vector2i, outcome: String) -> void:
	"""Handle plot measured event from farm - update tile to show collapsed emoji"""
	_verbose.debug("ui", "👁️", "Farm.plot_measured received at PlotGridDisplay: %s → %s" % [pos, outcome])
	update_tile_from_farm(pos)


func _on_farm_plot_harvested(pos: Vector2i, yield_data: Dictionary) -> void:
	"""Handle plot harvested event from farm - PHASE 4: Direct signal"""
	_verbose.debug("ui", "✂️", "Farm.plot_harvested received at PlotGridDisplay")
	update_tile_from_farm(pos)


func _on_entanglement_created(pos_a: Vector2i, pos_b: Vector2i) -> void:
	"""Handle entanglement created event - update both tiles to show entanglement ring"""
	_verbose.debug("ui", "🔗", "Entanglement created: %s ↔ %s - updating tiles" % [pos_a, pos_b])
	update_tile_from_farm(pos_a)
	update_tile_from_farm(pos_b)
	queue_redraw()  # Trigger connection line drawing immediately


func _on_terminal_bound(pos: Vector2i, _terminal_id: String, _emoji_pair: Dictionary) -> void:
	"""Handle terminal bound event from EXPLORE action - update tile to show bound terminal"""
	_verbose.debug("ui", "🔍", "Farm.terminal_bound received at PlotGridDisplay: %s" % pos)
	update_tile_from_farm(pos)


func _on_structure_built(pos: Vector2i, structure_type: String, _emoji_pair: Dictionary) -> void:
	"""Handle structure built event from industry building - update tile to show structure"""
	_verbose.debug("ui", "🏭", "Farm.structure_built received at PlotGridDisplay: %s → %s" % [pos, structure_type])
	update_tile_from_farm(pos)


## KEYBOARD SELECTION SUPPORT

func select_plot_by_key(action: String) -> void:
	"""Select plot by input action name (e.g., 'select_plot_t' for T key)"""
	if not grid_config:
		push_error("PlotGridDisplay: GridConfig not injected!")
		return

	var pos = grid_config.keyboard_layout.get_position_for_action(action)
	if pos == Vector2i(-1, -1):
		push_error("PlotGridDisplay: Unknown keyboard action: %s" % action)
		return

	set_selected_plot(pos)

	# Notify controllers
	if ui_controller and ui_controller.has_method("on_plot_selected"):
		ui_controller.on_plot_selected(pos)

	_verbose.debug("ui", "⌨️", "Selected plot %s via keyboard action %s" % [pos, action])


## MULTI-SELECT SUPPORT (NEW)

func toggle_plot_selection(pos: Vector2i) -> void:
	"""Toggle a plot in the multi-select group (NEW)"""
	if not tiles.has(pos):
		_verbose.warn("ui", "⚠️", "Invalid plot position: %s" % pos)
		return

	if not tiles[pos]:
		_verbose.warn("ui", "⚠️", "Tile at %s not found!" % pos)
		return

	# Toggle selection
	var now_selected: bool
	if selected_plots.has(pos):
		selected_plots.erase(pos)
		now_selected = false
	else:
		selected_plots[pos] = true
		now_selected = true

	# Update visual
	tiles[pos].set_checkbox_selected(now_selected)

	_verbose.debug("ui", "☑️", "Plot %s %s (total selected: %d)" % [pos, "selected" if now_selected else "deselected", selected_plots.size()])
	selection_count_changed.emit(selected_plots.size())


func clear_all_selection() -> void:
	"""Clear all plot selections ([ key)"""
	selected_plots.clear()

	# Update all tiles
	for pos in tiles.keys():
		tiles[pos].set_checkbox_selected(false)

	_verbose.debug("ui", "🗑️", "All selections cleared")
	selection_count_changed.emit(0)


func select_all_plots() -> void:
	"""Select all plots in the active biome (] key)"""
	# Get active biome
	var active_biome = ""
	var biome_mgr = get_node_or_null("/root/ActiveBiomeManager")
	if biome_mgr and biome_mgr.has_method("get_active_biome"):
		active_biome = biome_mgr.get_active_biome()

	# Clear current selections first
	selected_plots.clear()

	# Select all plots in the active biome
	var count = 0
	for pos in tiles.keys():
		var tile = tiles[pos]
		if grid_config:
			var plot_biome = grid_config.get_biome_for_plot(pos)
			if plot_biome == active_biome:
				selected_plots[pos] = true
				tile.set_checkbox_selected(true)
				count += 1
			else:
				tile.set_checkbox_selected(false)
		else:
			# No grid config - select all visible tiles
			if tile.visible:
				selected_plots[pos] = true
				tile.set_checkbox_selected(true)
				count += 1

	_verbose.debug("ui", "✅", "Selected all %d plots in %s" % [count, active_biome])
	selection_count_changed.emit(count)


func get_selected_plots() -> Array[Vector2i]:
	"""Get selected plots in the ACTIVE biome only.

	Filters out any stale selections from other biomes.
	"""
	var result: Array[Vector2i] = []

	# Get active biome to filter selections
	var active_biome = ""
	var biome_mgr = get_node_or_null("/root/ActiveBiomeManager")
	if biome_mgr and biome_mgr.has_method("get_active_biome"):
		active_biome = biome_mgr.get_active_biome()

	for pos in selected_plots.keys():
		# Only include if this plot belongs to the active biome
		if grid_config:
			var plot_biome = grid_config.get_biome_for_plot(pos)
			if active_biome == "" or plot_biome == active_biome:
				result.append(pos)
		else:
			result.append(pos)

	return result


func get_selected_plot_count() -> int:
	"""Get number of selected plots (NEW)"""
	return selected_plots.size()


func get_selected_plot() -> Vector2i:
	"""Get currently selected plot position"""
	return current_selection


## PARAMETRIC POSITIONING - PUBLIC API FOR QUANTUM GRAPH

func get_classical_plot_positions() -> Dictionary:
	"""Get parametric plot positions for QuantumForceGraph tethering

	Returns: Dictionary mapping Vector2i (grid position) → Vector2 (screen position)

	This allows QuantumForceGraph to read plots as the foundation and tether
	quantum bubbles to fixed plot positions.
	"""
	return classical_plot_positions.duplicate()


func get_plot_position(grid_pos: Vector2i) -> Vector2:
	"""Get parametric screen position for a specific plot"""
	return classical_plot_positions.get(grid_pos, Vector2.ZERO)


## DRAG/SWIPE BATCH SELECTION

func _input(event: InputEvent) -> void:
	"""Handle drag/swipe selection across multiple plots

	NOTE: Single clicks/taps are handled via TouchInputManager.tap_detected signal
	connected in _create_tiles(). This function handles:
	- Mouse press on plot: Start drag tracking
	- Mouse motion: Add plots to drag selection
	- Mouse release: End drag and select all dragged plots
	"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start drag tracking if pressing on a plot
				var plot_pos = _get_plot_at_screen_position(event.global_position)
				if plot_pos != Vector2i(-1, -1):
					_start_drag(plot_pos)
					# Don't consume - let TouchInputManager also track for tap detection
					_verbose.debug("ui", "📱", "PlotGridDisplay: Started drag tracking at %s" % plot_pos)
			else:
				# End drag
				if is_dragging:
					_end_drag()
					get_viewport().set_input_as_handled()
					_verbose.debug("ui", "✅", "Consumed by PlotGridDisplay (drag end)")

	elif event is InputEventMouseMotion:
		if is_dragging:
			# Check if cursor is over a new plot
			var plot_pos = _get_plot_at_screen_position(event.global_position)
			if plot_pos != Vector2i(-1, -1):
				if not drag_plots.has(plot_pos):
					_drag_over_plot(plot_pos)

	# TODO: Implement Godot 4 touch drag selection
	# Previous implementation used InputEventScreenDrag (Godot 3 API, doesn't exist in Godot 4)
	# New implementation needs:
	# - Track InputEventScreenTouch with .index for multi-finger support
	# - Monitor position changes in _process() for drag motion
	# - Detect tap vs drag based on movement distance and time
	# See: /home/tehcr33d/ws/SpaceWheat/llm_outbox/TOUCH_CODE_AUDIT.md


func _on_touch_tap(position: Vector2) -> void:
	"""Handle touch tap for plot selection - toggles checkbox for multi-select

	PHASE 2 FIX: Implements spatial hierarchy by checking if bubble already consumed tap.
	Bubbles have priority over plots - if bubble consumed tap, skip plot processing.
	"""
	_verbose.debug("ui", "🎯", "PlotGridDisplay._on_touch_tap received! Position: %s" % position)

	# PRIORITY CHECK: If bubble already consumed this tap, skip plot processing
	if TouchInputManager.is_current_tap_consumed():
		_verbose.debug("ui", "⏩", "Tap already consumed by bubble, skipping plot selection")
		return

	var plot_pos = _get_plot_at_screen_position(position)
	_verbose.debug("ui", "", "Converted to plot grid position: %s" % plot_pos)
	if plot_pos != Vector2i(-1, -1):
		# FOUND PLOT: Toggle checkbox and consume tap
		toggle_plot_selection(plot_pos)
		TouchInputManager.consume_current_tap()
		_verbose.debug("ui", "✅", "Plot checkbox toggled via touch tap: %s (tap CONSUMED)" % plot_pos)
	else:
		# NO PLOT: Let tap pass through
		_verbose.debug("ui", "⏩", "Touch tap at %s - no plot found" % position)


func _start_drag(pos: Vector2i) -> void:
	"""Start drag selection from this plot"""
	is_dragging = true
	drag_plots.clear()
	drag_start_pos = pos
	# First plot in drag is automatically included
	drag_plots[pos] = true
	_verbose.debug("ui", "📱", "Drag started at %s" % pos)


func _drag_over_plot(pos: Vector2i) -> void:
	"""Add plot to drag selection (if not already added)"""
	if not drag_plots.has(pos):
		drag_plots[pos] = true
		# Visual feedback - immediately toggle during drag
		if tiles.has(pos):
			tiles[pos].set_checkbox_selected(true)
		_verbose.debug("ui", "📱", "Drag over %s (total: %d plots)" % [pos, drag_plots.size()])


func _end_drag() -> void:
	"""End drag selection - toggle all dragged plots"""
	is_dragging = false

	if drag_plots.size() <= 1:
		# Single plot or empty - handled by normal click
		drag_plots.clear()
		drag_start_pos = Vector2i(-1, -1)
		return

	# Multi-plot drag completed - skip the click handler that will fire next
	_skip_next_click = true

	# Toggle all dragged plots
	_verbose.debug("ui", "📱", "Drag ended - selecting %d plots: %s" % [drag_plots.size(), drag_plots.keys()])
	for pos in drag_plots.keys():
		if not selected_plots.has(pos):
			selected_plots[pos] = true
			if tiles.has(pos):
				tiles[pos].set_checkbox_selected(true)
		# Note: We don't toggle off during drag - drag is always additive

	selection_count_changed.emit(selected_plots.size())
	drag_plots.clear()
	drag_start_pos = Vector2i(-1, -1)


func _get_plot_at_screen_position(screen_pos: Vector2) -> Vector2i:
	"""Find which plot (if any) is at the given screen position"""
	# Check each VISIBLE tile using global rect
	for pos in tiles.keys():
		var tile = tiles[pos]
		# Skip hidden tiles (tiles from non-active biomes)
		if not tile.visible:
			continue
		var rect = tile.get_global_rect()
		if rect.has_point(screen_pos):
			return pos

	return Vector2i(-1, -1)  # No plot at this position


## ============================================================================
## GATE & ENTANGLEMENT LINE VISUALIZATION
## ============================================================================

var _time_accumulator: float = 0.0
var _check_connections_timer: float = 0.0
var _biome_manager_connected: bool = false  # Track if we've done initial biome manager setup


func _get_tile_center(grid_pos: Vector2i) -> Vector2:
	"""Get center position for a tile in local coordinates for drawing.

	Uses the tile's actual rendered position rather than classical_plot_positions,
	so drawing coordinates match where tiles are actually displayed.
	"""
	if tiles.has(grid_pos):
		var tile = tiles[grid_pos]
		# Convert tile's global center to PlotGridDisplay's local coords
		var global_center = tile.get_global_rect().get_center()
		return get_global_transform().affine_inverse() * global_center
	return Vector2.ZERO

func _process(delta: float) -> void:
	"""Update animation time and periodically check for connections to draw"""
	_time_accumulator += delta
	_check_connections_timer += delta
	time_accumulator += delta

	# CRITICAL: Redraw EVERY FRAME while rejection effects are active (they're animated!)
	if rejection_effects.size() > 0:
		queue_redraw()

	# Remove expired rejection effects
	for i in range(rejection_effects.size() - 1, -1, -1):
		var effect = rejection_effects[i]
		var age = time_accumulator - effect.start_time
		if age >= REJECTION_EFFECT_DURATION:
			rejection_effects.remove_at(i)

	# Check for connections every 0.2 seconds (not every frame for performance)
	if _check_connections_timer >= 0.2:
		_check_connections_timer = 0.0
		if _has_visual_connections():
			queue_redraw()


func _has_visual_connections() -> bool:
	"""Check if there are any visual connections to draw.

	Only checks for persistent gate infrastructure - entanglement
	visualization is now delegated to biomes.
	"""
	if not farm or not farm.grid:
		return false

	# Check for any persistent gates (plot-level infrastructure)
	for pos in farm.grid.plots:
		var plot = farm.grid.plots[pos]
		if plot and plot.has_method("get_active_gates"):
			var gates = plot.get_active_gates()
			if not gates.is_empty():
				return true

	return false


func _draw() -> void:
	"""Draw persistent gate infrastructure between plots.

	NOTE: Entanglement lines (1-E) are NOT drawn here.
	Biomes are responsible for rendering qubit-level entanglement visuals.
	PlotGridDisplay only draws plot-level infrastructure (gates from 2-Q).
	"""
	# ALWAYS draw rejection effects (even if farm is null)
	# These are drawn at z-index=2, above the UI (z-index=1)
	_draw_rejection_effects()

	if not farm or not farm.grid:
		return

	# Draw persistent gate infrastructure only
	# (entanglement visualization is delegated to biomes)
	_draw_persistent_gate_infrastructure()


func _draw_rejection_effects():
	"""Draw red pulsing circles for rejected actions

	Visual feedback when player tries to do something invalid (e.g., plant incompatible crop).
	Effect pulses/grows outward from plot position and fades after REJECTION_EFFECT_DURATION.
	"""
	for effect in rejection_effects:
		var grid_pos = effect.grid_pos
		var age = time_accumulator - effect.start_time

		# Get plot screen position
		var plot_pos = classical_plot_positions.get(grid_pos)
		if not plot_pos:
			continue  # Plot not found

		# Animation progress (0.0 to 1.0)
		var progress = clamp(age / REJECTION_EFFECT_DURATION, 0.0, 1.0)

		# Red color with fade
		var red = Color(1.0, 0.2, 0.2, 1.0 - progress)

		# Pulsing expansion
		var base_radius = 30.0
		var max_radius = 60.0
		var pulse_radius = base_radius + (max_radius - base_radius) * progress

		# Draw outer glow ring (thicker, semi-transparent)
		var glow_color = red
		glow_color.a = (1.0 - progress) * 0.3
		draw_arc(plot_pos, pulse_radius, 0, TAU, 32, glow_color, 8.0, true)

		# Draw main ring (thinner, more opaque)
		var ring_color = red
		ring_color.a = 1.0 - progress
		draw_arc(plot_pos, pulse_radius, 0, TAU, 32, ring_color, 3.0, true)

		# Draw inner flash (fades faster)
		if progress < 0.5:
			var flash_alpha = (1.0 - progress * 2.0) * 0.6
			var flash_color = Color(1.0, 0.5, 0.5, flash_alpha)
			draw_circle(plot_pos, pulse_radius * 0.4, flash_color)


func _draw_entanglement_lines() -> void:
	"""Draw entanglement connection lines between entangled plots.

	Uses plot positions from classical_plot_positions.
	Entanglement data comes from plot.entangled_plots dictionary.
	"""
	if not farm or not farm.grid:
		return

	var drawn_pairs: Dictionary = {}  # Track drawn pairs to avoid duplicates

	for pos in classical_plot_positions:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			continue

		var screen_pos = classical_plot_positions[pos]

		# Draw lines to all entangled partners
		for partner_id in plot.entangled_plots.keys():
			# Find partner plot position
			for other_pos in farm.grid.plots:
				var other_plot = farm.grid.plots[other_pos]
				if other_plot and other_plot.plot_id == partner_id:
					# Create unique key to avoid drawing twice
					var key = str(min(pos.x * 100 + pos.y, other_pos.x * 100 + other_pos.y)) + "_" + str(max(pos.x * 100 + pos.y, other_pos.x * 100 + other_pos.y))
					if drawn_pairs.has(key):
						continue
					drawn_pairs[key] = true

					# Get tile centers for both plots
					var center_a = _get_tile_center(pos)
					var center_b = _get_tile_center(other_pos)

					if center_a != Vector2.ZERO and center_b != Vector2.ZERO:
						# Draw pulsing cyan entanglement line
						var pulse = (sin(_time_accumulator * 3.0) + 1.0) / 2.0
						var entangle_color = Color(0.3, 0.9, 1.0, 0.5 + pulse * 0.3)  # Cyan
						var line_width = 2.0 + pulse * 1.5

						draw_line(center_a, center_b, entangle_color, line_width)

						# Draw small particles along the line
						var particle_count = 3
						for i in range(particle_count):
							var t = fmod((_time_accumulator * 0.5 + float(i) / particle_count), 1.0)
							var particle_pos = center_a.lerp(center_b, t)
							draw_circle(particle_pos, 3.0, entangle_color)
					break


func _draw_persistent_gate_infrastructure() -> void:
	"""Draw persistent gate infrastructure at plot positions.

	Gates are stored in plot.persistent_gates array.
	Visual styles:
	- Bell gates (2 plots): Gold/amber solid connection
	- Cluster gates (3+ plots): Purple hub-and-spoke pattern
	"""
	if not farm or not farm.grid:
		return

	var drawn_gates: Dictionary = {}  # Track drawn gates to avoid duplicates

	for pos in farm.grid.plots:
		var plot = farm.grid.plots[pos]
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

			# Collect tile center positions for linked plots
			var screen_positions: Array[Vector2] = []
			for linked_pos in linked_plots:
				var center = _get_tile_center(linked_pos)
				if center != Vector2.ZERO:
					screen_positions.append(center)

			if screen_positions.size() < 2:
				continue

			# Draw based on gate type
			match gate_type:
				"bell":
					_draw_bell_gate(screen_positions)
				"cluster":
					_draw_cluster_gate(screen_positions)
				_:
					_draw_bell_gate(screen_positions)


func _draw_bell_gate(positions: Array[Vector2]) -> void:
	"""Draw Bell gate (2-node) as gold/amber connection with brackets"""
	if positions.size() < 2:
		return

	var p1 = positions[0]
	var p2 = positions[1]

	# Slow pulse for infrastructure (architectural, not particle-like)
	var pulse = (sin(_time_accumulator * 0.8) + 1.0) / 2.0
	var gate_color = Color(1.0, 0.75, 0.2, 0.6 + pulse * 0.2)  # Golden amber
	var line_width = 3.0 + pulse

	# Draw main connection line
	draw_line(p1, p2, gate_color, line_width)

	# Draw corner brackets at each end
	var bracket_size = 8.0
	var dir = (p2 - p1).normalized()
	var perp = Vector2(-dir.y, dir.x)

	# Bracket at p1
	draw_line(p1 + perp * bracket_size, p1 - perp * bracket_size, gate_color, line_width * 0.7)

	# Bracket at p2
	draw_line(p2 + perp * bracket_size, p2 - perp * bracket_size, gate_color, line_width * 0.7)


func _draw_cluster_gate(positions: Array[Vector2]) -> void:
	"""Draw Cluster gate (N-node) as purple hub-and-spoke pattern"""
	if positions.size() < 2:
		return

	# Calculate centroid
	var centroid = Vector2.ZERO
	for pos in positions:
		centroid += pos
	centroid /= positions.size()

	# Slow pulse for infrastructure
	var pulse = (sin(_time_accumulator * 0.6) + 1.0) / 2.0
	var gate_color = Color(0.7, 0.4, 1.0, 0.5 + pulse * 0.2)  # Purple
	var line_width = 2.5 + pulse * 0.5

	# Draw spokes from centroid to each node
	for pos in positions:
		draw_line(centroid, pos, gate_color, line_width)

		# Draw small circle at each node
		draw_circle(pos, 5.0, gate_color)

	# Draw hub circle at centroid
	draw_circle(centroid, 8.0 + pulse * 2.0, gate_color)


