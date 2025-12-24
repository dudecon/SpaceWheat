class_name PlotGridDisplay
extends GridContainer

## PlotGridDisplay - Visual representation of the 6x1 farm grid
## Creates and manages PlotTile instances for each plot
## Handles selection, planting visualization, and signal updates

const PlotTile = preload("res://UI/PlotTile.gd")
const PlotSelectionManager = preload("res://UI/PlotSelectionManager.gd")
const GridConfig = preload("res://Core/GameState/GridConfig.gd")
const FarmUIState = preload("res://Core/GameState/FarmUIState.gd")

# References
var farm: Node = null
var ui_state = null  # FarmUIState - abstraction layer (Phase 5, RefCounted not Node)
var ui_controller: Node = null
var layout_manager: Node = null
var grid_config: GridConfig = null  # Grid configuration (Phase 7)

# Plot tiles (Vector2i -> PlotTile)
var tiles: Dictionary = {}

# Multi-select management (NEW)
var selection_manager: PlotSelectionManager = null

# Backward compatibility: also track last single-click for operations
var current_selection: Vector2i = Vector2i.ZERO

# Signals for selection state changes
signal selection_count_changed(count: int)


func _ready():
	"""Initialize plot grid display"""
	print("🌾 PlotGridDisplay._ready() called (Instance: %s, child_count before: %d)" % [get_instance_id(), get_child_count()])

	# Safety check: if tiles already exist, DON'T recreate them
	if tiles.size() > 0:
		print("⚠️  WARNING: PlotGridDisplay._ready() called but tiles already exist! tile_count=%d" % tiles.size())
		print("   This suggests _ready() was called multiple times on the same instance!")
		return

	# Create tiles immediately with or without GridConfig
	# If GridConfig injected, use it; otherwise use default 6x2 layout
	_initialize_container()
	_create_tiles()
	_create_selection_manager()

	print("✅ PlotGridDisplay ready with GridContainer (child_count after: %d)" % get_child_count())


func inject_grid_config(config: GridConfig) -> void:
	"""Inject grid configuration and create tiles (Phase 7)"""
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

	print("💉 GridConfig injected into PlotGridDisplay")

	# Only create tiles if _ready() already ran
	if is_node_ready():
		if tiles.size() == 0:
			_initialize_container()
			_create_tiles()
			_create_selection_manager()
			print("✅ Tiles created from injected GridConfig (child_count: %d)" % get_child_count())


func _initialize_container() -> void:
	"""Initialize GridContainer with grid dimensions from GridConfig"""
	# Use GridConfig if available, otherwise use default 6x2 layout
	var width = grid_config.grid_width if grid_config else 6

	columns = width
	add_theme_constant_override("h_separation", 8)
	add_theme_constant_override("v_separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var height = grid_config.grid_height if grid_config else 2
	print("📐 GridContainer initialized: %dx%d" % [width, height])


func _create_tiles() -> void:
	"""Create plot tiles in grid order (row-major, top to bottom, left to right)"""
	# Use GridConfig if available, otherwise use default 6x2 layout
	var width = grid_config.grid_width if grid_config else 6
	var height = grid_config.grid_height if grid_config else 2

	# Create in row-major order (y first, then x)
	for y in range(height):
		for x in range(width):
			var pos = Vector2i(x, y)
			var plot_config = grid_config.get_plot_at(pos) if grid_config else null
			var is_active = plot_config == null or plot_config.is_active  # Treat null as active when no GridConfig

			# Inactive plots → spacer (invisible placeholder)
			if not is_active:
				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(90, 90)
				add_child(spacer)
				print("  ⬜ Spacer created at position %s" % pos)
				continue

			# Active plots → tile
			var tile = PlotTile.new()
			tile.grid_position = pos  # CRITICAL: Set the tile's grid position so it emits correctly
			tile.custom_minimum_size = Vector2(90, 90)
			tile.size_flags_vertical = Control.SIZE_FILL
			tile.clicked.connect(_on_tile_clicked)

			add_child(tile)
			tiles[pos] = tile

			# Set keyboard label from grid config (if available)
			var label = ""
			if plot_config and plot_config.keyboard_label:
				label = plot_config.keyboard_label
			else:
				# Default labels for 6x2 grid
				if y == 0:
					label = ["T", "Y", "U", "I", "O", "P"][x]
				elif y == 1:
					label = ["0", "9", "8", "7", "", ""][x]

			if label:
				tile.call_deferred("set_label_text", label)

			print("  📍 Plot tile created at position %s (%s)" % [pos, label])

	print("✅ Created %d active plot tiles" % tiles.size())


func _create_selection_manager() -> void:
	"""Create multi-select manager"""
	selection_manager = PlotSelectionManager.new()
	selection_manager.selection_changed.connect(_on_selection_changed)
	print("  🔄 PlotSelectionManager created")


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
	# we need these connections to show emoji updates when planting/harvesting
	if farm.has_signal("plot_planted"):
		if not farm.plot_planted.is_connected(_on_farm_plot_planted):
			farm.plot_planted.connect(_on_farm_plot_planted)
			print("   📡 Connected to farm.plot_planted")
	if farm.has_signal("plot_harvested"):
		if not farm.plot_harvested.is_connected(_on_farm_plot_harvested):
			farm.plot_harvested.connect(_on_farm_plot_harvested)
			print("   📡 Connected to farm.plot_harvested")

	print("💉 Farm injected into PlotGridDisplay")


func inject_ui_state(ui_state_ref) -> void:  # RefCounted, not Node
	"""Inject FarmUIState - the abstraction layer (Phase 5)"""
	if not ui_state_ref:
		push_error("PlotGridDisplay: Attempted to inject null UIState!")
		return

	ui_state = ui_state_ref
	print("💉 UIState injected into PlotGridDisplay")

	# DO NOT connect to UIState signals - QuantumForceGraph is primary visualization
	# These connections would create haunted double-updates
	# Commenting for reference if we switch back to classical mode
	#if ui_state.has_signal("plot_updated"):
	#	ui_state.plot_updated.connect(_on_plot_updated)
	#	print("   📡 Connected to plot_updated signal")
	#if ui_state.has_signal("grid_refreshed"):
	#	ui_state.grid_refreshed.connect(_on_grid_refreshed)
	#	print("   📡 Connected to grid_refreshed signal")
	#_on_grid_refreshed()


func inject_ui_controller(controller: Node) -> void:
	"""Inject UI controller for callbacks"""
	ui_controller = controller
	print("📡 UI controller injected into PlotGridDisplay")


func wire_to_farm(farm_ref: Node) -> void:
	"""Standard wiring interface for FarmUIController

	This method encapsulates all initialization needed when a farm is injected.
	Called by FarmUIController during farm injection phase.
	"""
	inject_farm(farm_ref)
	print("📡 PlotGridDisplay wired to farm")


func set_selected_plot(pos: Vector2i) -> void:
	"""Update visual selection to show which plot is selected"""
	# Clear previous selection
	for tile_pos in tiles.keys():
		tiles[tile_pos].set_selected(false)

	# Highlight new selection
	if tiles.has(pos):
		current_selection = pos
		tiles[pos].set_selected(true)
		print("  🎯 Selected plot: %s" % pos)


func update_tile_from_farm(pos: Vector2i) -> void:
	"""PHASE 4: Update tile visual state directly from farm plot data

	Transforms farm plot state into PlotUIData inline (no FarmUIState layer).
	"""
	if not tiles.has(pos):
		print("   ✗ update_tile_from_farm(%s): tile not found!" % pos)
		return

	if not farm:
		print("   ✗ update_tile_from_farm(%s): farm is null!" % pos)
		var tile = tiles[pos]
		tile.set_plot_data(null, pos, -1)
		return

	if not farm.grid:
		print("   ✗ update_tile_from_farm(%s): farm.grid is null!" % pos)
		var tile = tiles[pos]
		tile.set_plot_data(null, pos, -1)
		return

	var plot = farm.grid.get_plot(pos)
	if not plot:
		# Empty plot
		print("   ⚠️  update_tile_from_farm(%s): plot is null/empty" % pos)
		var tile = tiles[pos]
		tile.set_plot_data(null, pos, -1)
		return

	# Transform plot → PlotUIData inline
	print("   ✓ update_tile_from_farm(%s): found plot, transforming data..." % pos)
	var ui_data = _transform_plot_to_ui_data(pos, plot)
	var tile = tiles[pos]
	tile.set_plot_data(ui_data, pos, -1)
	print("  🌾 PlotGridDisplay updating tile for plot %s" % pos)


func update_tile_from_ui_state(pos: Vector2i) -> void:
	"""Update tile visual state from UIState plot data (Phase 5)"""
	if not tiles.has(pos) or not ui_state:
		return

	var tile = tiles[pos]

	# Get plot data from UIState
	if ui_state.plot_states.has(pos):
		var plot_ui_data = ui_state.plot_states[pos]
		# Don't pass index - only set position and data (label was already set during _ready)
		tile.set_plot_data(plot_ui_data, pos, -1)
		print("  🔄 Updated tile at %s: %s" % [pos, plot_ui_data.plot_type if plot_ui_data.is_planted else "empty"])
	else:
		# Empty plot
		# Don't pass index - preserve keyboard label
		tile.set_plot_data(null, pos, -1)


## PHASE 4: PLOT TRANSFORMATION HELPER

func _transform_plot_to_ui_data(pos: Vector2i, plot) -> FarmUIState.PlotUIData:
	"""Transform WheatPlot state → PlotUIData (mirrors FarmUIState logic)

	This inline transformation replaces the FarmUIState layer for real-time updates.
	"""
	var ui_data = FarmUIState.PlotUIData.new()
	ui_data.position = pos
	ui_data.is_planted = plot.is_planted
	ui_data.plot_type = _get_plot_type_string(plot.plot_type)

	# Transform quantum state (if exists)
	if plot.quantum_state:
		var emojis = plot.get_plot_emojis()
		ui_data.north_emoji = emojis["north"]
		ui_data.south_emoji = emojis["south"]
		ui_data.north_probability = plot.quantum_state.get_north_probability()
		ui_data.south_probability = plot.quantum_state.get_south_probability()
		ui_data.energy_level = plot.quantum_state.energy

	ui_data.has_been_measured = plot.has_been_measured

	return ui_data


func _get_plot_type_string(plot_type_enum: int) -> String:
	"""Convert WheatPlot.PlotType enum to string"""
	match plot_type_enum:
		0: return "wheat"
		1: return "tomato"
		2: return "mushroom"
		_: return "empty"


func _on_tile_clicked(pos: Vector2i) -> void:
	"""Handle tile click - select plot"""
	print("🖱️  Plot tile clicked: %s" % pos)
	set_selected_plot(pos)

	# Notify controllers
	if ui_controller and ui_controller.has_method("on_plot_selected"):
		ui_controller.on_plot_selected(pos)


## PHASE 4: DIRECT FARM SIGNAL HANDLERS (bypass FarmUIState)

func _on_farm_plot_planted(pos: Vector2i, plant_type: String) -> void:
	"""Handle plot planted event from farm - PHASE 4: Direct signal"""
	print("🌱 Farm.plot_planted received at PlotGridDisplay")
	update_tile_from_farm(pos)


func _on_farm_plot_harvested(pos: Vector2i, yield_data: Dictionary) -> void:
	"""Handle plot harvested event from farm - PHASE 4: Direct signal"""
	print("✂️  Farm.plot_harvested received at PlotGridDisplay")
	update_tile_from_farm(pos)


## UI STATE SIGNAL HANDLERS (Phase 5 - Reactive Updates)

func _on_plot_updated(position: Vector2i, plot_data) -> void:
	"""Handle plot changes from UIState - update tile visually"""
	print("🌱 Plot updated via UIState: %s" % position)
	update_tile_from_ui_state(position)


func _on_grid_refreshed() -> void:
	"""Handle bulk grid refresh from UIState (save/load)"""
	print("🔄 Grid refreshed via UIState - updating all tiles")
	for pos in tiles.keys():
		update_tile_from_ui_state(pos)


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

	print("⌨️  Selected plot %s via keyboard action %s" % [pos, action])


## MULTI-SELECT SUPPORT (NEW)

func toggle_plot_selection(pos: Vector2i) -> void:
	"""Toggle a plot in the multi-select group (NEW)"""
	if not tiles.has(pos):
		print("⚠️  Invalid plot position: %s" % pos)
		return

	if not selection_manager:
		print("⚠️  SelectionManager not initialized!")
		return

	if not tiles[pos]:
		print("⚠️  Tile at %s not found!" % pos)
		return

	# Save state before toggling (for ] restoration)
	selection_manager.save_state()

	# Toggle in manager
	var now_selected = selection_manager.toggle_plot(pos)

	# Update visual
	tiles[pos].set_checkbox_selected(now_selected)

	print("☑️  Plot %s %s (total selected: %d)" % [pos, "selected" if now_selected else "deselected", selection_manager.get_count()])


func clear_all_selection() -> void:
	"""Clear all plot selections ([ key)"""
	selection_manager.clear_selection()

	# Update all tiles
	for pos in tiles.keys():
		tiles[pos].set_checkbox_selected(false)

	print("🗑️  All selections cleared")


func restore_previous_selection() -> void:
	"""Restore previous selection state (] key)"""
	selection_manager.restore_state()

	# Update all tiles to match
	for pos in tiles.keys():
		var is_selected = selection_manager.is_selected(pos)
		tiles[pos].set_checkbox_selected(is_selected)


func get_selected_plots() -> Array[Vector2i]:
	"""Get all currently selected plots (NEW)"""
	return selection_manager.get_selected()


func get_selected_plot_count() -> int:
	"""Get number of selected plots (NEW)"""
	return selection_manager.get_count()


func _on_selection_changed(selected_plots: Array[Vector2i], count: int) -> void:
	"""Handle selection manager change signal (NEW)"""
	# This is called when SelectionManager emits selection_changed
	# Could be used to notify other systems about selection state
	if count > 0:
		print("📍 Selection changed: %d plots selected" % count)
	else:
		print("📍 Selection cleared")

	# Emit signal for UI systems to update button highlights
	selection_count_changed.emit(count)


func get_selected_plot() -> Vector2i:
	"""Get currently selected plot position"""
	return current_selection
