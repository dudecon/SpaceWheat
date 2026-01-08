## FarmUI - Farm-level UI layer
## Handles:
## - Plot grid display and tiles
## - Keyboard selection (T/Y/U/I/O/P/0/9/8/7)
## - Tool switching (1-4)
## - Action execution (Q/E/R)
##
## This layer is swappable - created fresh for each farm

class_name FarmUI
extends Control

const PlotGridDisplay = preload("res://UI/PlotGridDisplay.gd")
const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")
const ToolSelectionRow = preload("res://UI/Panels/ToolSelectionRow.gd")
const ActionPreviewRow = preload("res://UI/Panels/ActionPreviewRow.gd")
const ResourcePanel = preload("res://UI/Panels/ResourcePanel.gd")
const QuantumModeStatusIndicator = preload("res://UI/Panels/QuantumModeStatusIndicator.gd")
const GridConfig = preload("res://Core/GameState/GridConfig.gd")

var farm: Node
var grid_config: GridConfig
var plot_grid_display = null  # From scene
var input_handler = null  # Created dynamically
var tool_selection_row = null  # From scene
var action_preview_row = null  # From scene
var resource_panel = null  # From scene
var quantum_mode_indicator = null  # Created dynamically
var quantum_visualization = null  # Optional - only if needed later
var current_tool: int = 1

# DEBUG: Layout visibility
var debug_layout_visible: bool = false
var debug_label: Label = null


func _ready() -> void:
	"""FarmUI scene is ready - get references to child nodes and setup layout.

	NOTE: Farm setup (setup_farm()) will be called by BootManager after all
	dependencies are guaranteed to exist. We only initialize scene structure here.
	"""
	print("🎮 FarmUI initializing from scene...")

	# Ensure FarmUI is properly sized to fill parent (using anchors)
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Get references to scene-defined child nodes
	resource_panel = get_node("MainContainer/ResourcePanel")
	plot_grid_display = get_node("PlotGridDisplay")  # Now sibling of MainContainer
	# quantum_visualization = get_node("QuantumVisualizationController")  # REMOVED - abandoned ghost node
	tool_selection_row = get_node("MainContainer/ToolSelectionRow")
	action_preview_row = get_node("MainContainer/ActionPreviewRow")

	# Create quantum mode status indicator (Phase 1 UI integration)
	_create_quantum_mode_indicator()

	print("   ✅ All child nodes referenced")

	# CRITICAL: Ensure FarmUI fills its parent (FarmUIContainer)
	# This continues the delegation cascade: FarmView → PlayerShell → FarmUIContainer → FarmUI
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Explicitly match parent size (in case anchors don't work due to layout_mode mismatch)
	if get_parent():
		size = get_parent().size

	# Also size MainContainer to fill FarmUI (it has layout_mode=1 which has the same issue)
	# Use set_deferred to avoid being overridden by layout engine
	var main_container = get_node_or_null("MainContainer")
	if main_container:
		main_container.set_deferred("size", size)
		# CRITICAL: MainContainer must pass input through to PlotGridDisplay below
		main_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		print("   ✅ MainContainer mouse_filter set to IGNORE for plot tile input")

	# Apply responsive sizing BEFORE layout engine runs (critical - must happen in _ready)
	_apply_parametric_sizing()

	# DEBUG: Add info about toggling debug display
	print("💡 Press F3 to toggle layout debug display")
	print("   ⏳ Waiting for BootManager to call setup_farm()...")


func setup_farm(farm_ref: Node) -> void:
	"""Configure FarmUI for a specific farm (called after scene instantiation)"""
	print("📂 Loading farm into FarmUI...")

	farm = farm_ref
	grid_config = farm.grid_config if farm else null

	# Wire ResourcePanel to economy
	if farm and farm.economy and resource_panel:
		resource_panel.connect_to_economy(farm.economy)
		print("   ✅ ResourcePanel wired to economy")

	# Wire PlotGridDisplay to farm
	if farm and plot_grid_display:
		plot_grid_display.inject_farm(farm)
		plot_grid_display.inject_grid_config(grid_config)
		if farm.grid and farm.grid.biomes:
			plot_grid_display.inject_biomes(farm.grid.biomes)

		# Wire rejection visual feedback
		if farm.has_signal("action_rejected"):
			if not farm.action_rejected.is_connected(plot_grid_display.show_rejection_effect):
				farm.action_rejected.connect(plot_grid_display.show_rejection_effect)
				print("   📡 Connected to farm.action_rejected for visual feedback")

		print("   ✅ PlotGridDisplay wired to farm")

	# Quantum visualization optional - skip for now
	# TODO: Wire QuantumVisualization to biomes when needed
	#if farm and farm.grid and farm.grid.biomes and quantum_visualization:
	#	for biome_name in farm.grid.biomes.keys():
	#		var biome = farm.grid.biomes[biome_name]
	#		quantum_visualization.connect_to_biome(biome, {})
	#		break

	# Wire tool selection
	if tool_selection_row:
		if not tool_selection_row.tool_selected.is_connected(_on_tool_selected):
			tool_selection_row.tool_selected.connect(_on_tool_selected)
		tool_selection_row.select_tool(1)

	# Wire action preview
	if action_preview_row:
		action_preview_row.update_for_tool(1)
		if not action_preview_row.action_pressed.is_connected(_on_action_pressed):
			action_preview_row.action_pressed.connect(_on_action_pressed)
			print("   📡 Connected to action_preview_row.action_pressed")

	# Create input handler
	input_handler = FarmInputHandler.new()
	add_child(input_handler)

	# Wire input handler
	if farm and input_handler:
		input_handler.farm = farm
		input_handler.plot_grid_display = plot_grid_display
		input_handler.inject_grid_config(grid_config)

		if input_handler.has_signal("tool_changed"):
			input_handler.tool_changed.connect(_on_input_tool_changed)
			print("   📡 Connected to input_handler.tool_changed")

		if input_handler.has_signal("submenu_changed"):
			input_handler.submenu_changed.connect(_on_input_submenu_changed)
			print("   📡 Connected to input_handler.submenu_changed")

	# Wire plot selection changes
	if plot_grid_display and plot_grid_display.has_signal("selection_count_changed"):
		plot_grid_display.selection_count_changed.connect(_on_selection_changed)
		print("   📡 Connected to plot selection changes")

	print("✅ FarmUI farm setup complete")


func _input(event: InputEvent) -> void:
	"""Handle debug display toggle and UI input

	Note: Tool selection (1-4) is handled by FarmInputHandler via signals
	"""
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:  # F3 to toggle debug layout display
			debug_layout_visible = not debug_layout_visible
			_update_debug_display()
			get_viewport().set_input_as_handled()


func _select_tool(tool_num: int) -> void:
	"""Switch to a different tool"""
	current_tool = tool_num
	if tool_selection_row:
		tool_selection_row.select_tool(tool_num)
	if action_preview_row:
		action_preview_row.update_for_tool(tool_num)
	if input_handler:
		input_handler.current_tool = tool_num
	print("🔧 Tool changed to %d" % tool_num)


func _on_tool_selected(tool_num: int) -> void:
	"""Handle tool selection from UI buttons"""
	_select_tool(tool_num)


func _on_action_pressed(action_key: String) -> void:
	"""Handle action button press from ActionPreviewRow (Q/E/R buttons clicked)"""
	if input_handler:
		print("🖱️  Action button clicked: %s" % action_key)
		input_handler.execute_action(action_key)
	else:
		push_error("FarmUI: Cannot execute action - input_handler not initialized")


func _on_input_tool_changed(tool_num: int, tool_info: Dictionary) -> void:
	"""Handle tool change from keyboard input (FarmInputHandler)"""
	print("🔄 Tool changed via input: %d (%s)" % [tool_num, tool_info.get("name", "unknown")])
	# Update UI to match the tool that was selected via keyboard
	if tool_selection_row:
		tool_selection_row.select_tool(tool_num)
	if action_preview_row:
		action_preview_row.update_for_tool(tool_num)
	current_tool = tool_num


func _on_input_submenu_changed(submenu_name: String, submenu_info: Dictionary) -> void:
	"""Handle submenu enter/exit from FarmInputHandler"""
	if submenu_name == "":
		print("📁 Submenu exited - restoring tool display")
	else:
		print("📂 Submenu entered: %s" % submenu_info.get("name", submenu_name))

	# Update action preview row with submenu actions
	if action_preview_row:
		action_preview_row.update_for_submenu(submenu_name, submenu_info)


func _on_selection_changed(count: int) -> void:
	"""Handle plot selection changes - highlight action buttons when plots selected"""
	if action_preview_row:
		var has_selection = count > 0
		action_preview_row.update_button_highlights(has_selection)
		if has_selection:
			print("✅ %d plot(s) selected - Q/E/R actions available" % count)
		else:
			print("❌ No plots selected - Q/E/R actions disabled" % count)


func _apply_parametric_sizing() -> void:
	"""Apply parametric sizing to UI components based on viewport dimensions"""
	var viewport_size = get_viewport_rect().size
	var viewport_height = viewport_size.y

	# Parametric layout: divide viewport into zones
	# 0-6% (Top): ResourcePanel
	# 6-72% (Middle): PlotGridDisplay
	# 72-87% (Bottom1): ActionPreviewRow
	# 87-100% (Bottom2): ToolSelectionRow

	var resource_panel_height = viewport_height * 0.06
	var plot_grid_height = viewport_height * 0.66  # 72% - 6%
	var action_row_height = viewport_height * 0.15  # 87% - 72%
	var tool_row_height = viewport_height * 0.13   # 100% - 87%

	# Apply to MainContainer children
	if resource_panel:
		resource_panel.custom_minimum_size = Vector2(0, resource_panel_height)

	if plot_grid_display:
		plot_grid_display.custom_minimum_size = Vector2(0, plot_grid_height)

	if action_preview_row:
		action_preview_row.custom_minimum_size = Vector2(0, action_row_height)

	if tool_selection_row:
		tool_selection_row.custom_minimum_size = Vector2(0, tool_row_height)


func _update_debug_display() -> void:
	"""Update or create debug display showing layout positions"""
	if debug_layout_visible:
		# Create debug label if needed
		if debug_label == null:
			debug_label = Label.new()
			debug_label.z_index = 1000  # Above everything
			debug_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			add_child(debug_label)

		# Build debug text with detailed layout info
		var debug_text = "=== LAYOUT DEBUG (Press F3 to toggle) ===\n"

		if action_preview_row and action_preview_row.has_method("debug_layout"):
			debug_text += "\n" + action_preview_row.debug_layout()

		if tool_selection_row and tool_selection_row.has_method("debug_layout"):
			debug_text += "\n" + tool_selection_row.debug_layout()

		debug_text += "\nMainContainer:\n"
		var main_container = get_node_or_null("MainContainer")
		if main_container:
			debug_text += "  Position: (%.0f, %.0f)\n" % [main_container.position.x, main_container.position.y]
			debug_text += "  Size: %.0f × %.0f\n" % [main_container.size.x, main_container.size.y]
			debug_text += "  Size flags H: %d\n" % main_container.size_flags_horizontal

		debug_text += "\nFarmUI (root):\n"
		debug_text += "  Size: %.0f × %.0f\n" % [size.x, size.y]
		debug_text += "  Viewport: %.0f × %.0f\n" % [get_viewport_rect().size.x, get_viewport_rect().size.y]

		debug_label.text = debug_text
		debug_label.position = Vector2(10, 10)
		debug_label.add_theme_font_size_override("font_size", 10)
		debug_label.show()
	else:
		if debug_label != null:
			debug_label.hide()

## ========================================
## Phase 1 UI Integration: Quantum Mode Indicator
## ========================================

func _create_quantum_mode_indicator() -> void:
	"""Create and position quantum rigor mode status indicator (top-right corner)"""
	# Create the indicator component
	quantum_mode_indicator = QuantumModeStatusIndicator.new()

	# Get MainContainer to add it there
	var main_container = get_node_or_null("MainContainer")
	if not main_container:
		push_error("Cannot create quantum mode indicator: MainContainer not found")
		return

	# Add as child of MainContainer
	main_container.add_child(quantum_mode_indicator)

	# Position in top-right corner
	quantum_mode_indicator.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quantum_mode_indicator.offset_left = -220  # 220 pixels from right edge
	quantum_mode_indicator.offset_top = 8      # 8 pixels from top
	quantum_mode_indicator.custom_minimum_size = Vector2(210, 40)

	# Enable input processing for the indicator
	quantum_mode_indicator.mouse_filter = Control.MOUSE_FILTER_PASS

	print("   ✅ Quantum mode status indicator created (top-right corner)")
