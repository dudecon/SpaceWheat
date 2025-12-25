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
const GridConfig = preload("res://Core/GameState/GridConfig.gd")

var farm: Node
var grid_config: GridConfig
var plot_grid_display = null  # From scene
var input_handler = null  # Created dynamically
var tool_selection_row = null  # From scene
var action_preview_row = null  # From scene
var resource_panel = null  # From scene
var quantum_visualization = null  # Optional - only if needed later
var current_tool: int = 1

# DEBUG: Layout visibility
var debug_layout_visible: bool = false
var debug_label: Label = null


func _ready() -> void:
	"""FarmUI scene is ready - get references to child nodes"""
	print("🎮 FarmUI initializing from scene...")

	# Ensure FarmUI fills its parent for proper layout cascade
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Get references to scene-defined child nodes
	resource_panel = get_node("MainContainer/ResourcePanel")
	plot_grid_display = get_node("MainContainer/PlotGridDisplay")
	quantum_visualization = get_node("QuantumVisualizationController")
	tool_selection_row = get_node("MainContainer/ToolSelectionRow")
	action_preview_row = get_node("MainContainer/ActionPreviewRow")

	print("   ✅ All child nodes referenced")

	# Apply parametric sizing based on viewport
	_apply_parametric_sizing()

	# DEBUG: Add info about toggling debug display
	print("💡 Press F3 to toggle layout debug display")


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


func _on_input_tool_changed(tool_num: int, tool_info: Dictionary) -> void:
	"""Handle tool change from keyboard input (FarmInputHandler)"""
	print("🔄 Tool changed via input: %d (%s)" % [tool_num, tool_info.get("name", "unknown")])
	# Update UI to match the tool that was selected via keyboard
	if tool_selection_row:
		tool_selection_row.select_tool(tool_num)
	if action_preview_row:
		action_preview_row.update_for_tool(tool_num)
	current_tool = tool_num


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

	print("📐 FarmUI parametric sizing applied:")
	print("  ResourcePanel: %.0fpx (6%% of %.0f)" % [resource_panel_height, viewport_height])
	print("  PlotGridDisplay: %.0fpx (66%%)" % plot_grid_height)
	print("  ActionPreviewRow: %.0fpx (15%%)" % action_row_height)
	print("  ToolSelectionRow: %.0fpx (13%%)" % tool_row_height)


func _update_debug_display() -> void:
	"""Update or create debug display showing layout positions"""
	if debug_layout_visible:
		# Create debug label if needed
		if debug_label == null:
			debug_label = Label.new()
			debug_label.z_index = 1000  # Above everything
			add_child(debug_label)

		# Build debug text
		var debug_text = "=== LAYOUT DEBUG (Press F3 to toggle) ===\n"
		debug_text += "\nActionPreviewRow (Q/E/R toolbar):\n"
		if action_preview_row:
			debug_text += "  Position: (%.0f, %.0f)\n" % [action_preview_row.position.x, action_preview_row.position.y]
			debug_text += "  Size: %.0f × %.0f\n" % [action_preview_row.size.x, action_preview_row.size.y]
			debug_text += "  Custom min size: %s\n" % action_preview_row.custom_minimum_size

		debug_text += "\nToolSelectionRow (1-6 toolbar):\n"
		if tool_selection_row:
			debug_text += "  Position: (%.0f, %.0f)\n" % [tool_selection_row.position.x, tool_selection_row.position.y]
			debug_text += "  Size: %.0f × %.0f\n" % [tool_selection_row.size.x, tool_selection_row.size.y]
			debug_text += "  Custom min size: %s\n" % tool_selection_row.custom_minimum_size

		debug_text += "\nFarmUI:\n"
		debug_text += "  Size: %.0f × %.0f\n" % [size.x, size.y]

		debug_label.text = debug_text
		debug_label.position = Vector2(10, 10)
		debug_label.add_theme_font_size_override("font_size", 12)
		debug_label.show()
	else:
		if debug_label != null:
			debug_label.hide()
