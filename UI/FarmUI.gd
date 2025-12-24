## FarmUI - Farm-level UI layer
## Handles:
## - Plot grid display and tiles
## - Keyboard selection (T/Y/U/I/O/P/0/9/8/7)
## - Tool switching (1-4)
## - Action execution (Q/E/R)
##
## This layer is swappable - created fresh for each farm

extends Control

const PlotGridDisplay = preload("res://UI/PlotGridDisplay.gd")
const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")
const ToolSelectionRow = preload("res://UI/Panels/ToolSelectionRow.gd")
const ActionPreviewRow = preload("res://UI/Panels/ActionPreviewRow.gd")
const ResourcePanel = preload("res://UI/Panels/ResourcePanel.gd")
const GridConfig = preload("res://Core/GameState/GridConfig.gd")
const QuantumVisualizationController = preload("res://Core/Visualization/QuantumVisualizationController.gd")

var farm: Node
var grid_config: GridConfig
var plot_grid_display: PlotGridDisplay
var input_handler: FarmInputHandler
var tool_selection_row: ToolSelectionRow
var action_preview_row: ActionPreviewRow
var resource_panel: ResourcePanel
var quantum_visualization: QuantumVisualizationController
var current_tool: int = 1


func _init(farm_ref: Node) -> void:
	"""Initialize with the farm (passed in constructor)"""
	farm = farm_ref
	grid_config = farm.grid_config if farm else null


func _ready() -> void:
	"""Set up farm UI synchronously"""
	print("🎮 FarmUI initializing...")

	# Fill parent
	size = get_parent().size
	position = Vector2.ZERO
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Create main layout container (VBox for stacking resources, action preview, plots, tool selection)
	var main_container = VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)

	# ========== RESOURCE PANEL (Top) ==========
	resource_panel = ResourcePanel.new()
	resource_panel.custom_minimum_size = Vector2(0, 50)
	main_container.add_child(resource_panel)

	# Wire ResourcePanel to listen to economy signals (single accounting system)
	if farm and farm.economy:
		resource_panel.connect_to_economy(farm.economy)
	else:
		print("⚠️  Farm or economy not available for ResourcePanel")

	print("   ✅ ResourcePanel created")

	# ========== ACTION PREVIEW ROW (Below Resources) ==========
	action_preview_row = ActionPreviewRow.new()
	action_preview_row.custom_minimum_size = Vector2(0, 60)
	main_container.add_child(action_preview_row)
	print("   ✅ ActionPreviewRow created")

	# ========== PLOT GRID DISPLAY (Middle - expand) ==========
	plot_grid_display = PlotGridDisplay.new()
	plot_grid_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(plot_grid_display)

	# Inject farm data into plot display
	if farm:
		plot_grid_display.inject_farm(farm)
		plot_grid_display.inject_grid_config(farm.grid_config)
		if farm.grid and farm.grid.biomes:
			plot_grid_display.inject_biomes(farm.grid.biomes)

	print("   ✅ PlotGridDisplay created")

	# ========== QUANTUM VISUALIZATION OVERLAY (On top of grid) ==========
	quantum_visualization = QuantumVisualizationController.new()
	quantum_visualization.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(quantum_visualization)

	# Connect quantum viz to biome if available
	if farm and farm.grid and farm.grid.biomes:
		for biome_name in farm.grid.biomes.keys():
			var biome = farm.grid.biomes[biome_name]
			# For now, connect to first biome
			quantum_visualization.connect_to_biome(biome, {})
			print("   ✅ Quantum visualization connected to biome: %s" % biome_name)
			break  # Only connect to first biome for MVP

	print("   ✅ Quantum visualization overlay created")

	# ========== TOOL SELECTION ROW (Bottom) ==========
	tool_selection_row = ToolSelectionRow.new()
	tool_selection_row.custom_minimum_size = Vector2(0, 70)
	main_container.add_child(tool_selection_row)
	tool_selection_row.tool_selected.connect(_on_tool_selected)

	# Initialize with tool 1 to sync UI
	tool_selection_row.select_tool(1)
	action_preview_row.update_for_tool(1)

	print("   ✅ ToolSelectionRow created")

	# Create input handler
	input_handler = FarmInputHandler.new()
	add_child(input_handler)

	# Wire input handler to farm and grid
	if farm:
		input_handler.farm = farm
		input_handler.plot_grid_display = plot_grid_display
		input_handler.inject_grid_config(grid_config)
		# NOTE: Do NOT call set_process_input() here - FarmInputHandler manages its own initialization

	# Listen for tool changes from input handler (keyboard presses)
	if input_handler.has_signal("tool_changed"):
		input_handler.tool_changed.connect(_on_input_tool_changed)
		print("   📡 Connected to input_handler.tool_changed")

	# Listen for selection changes to highlight Q/E/R buttons
	if plot_grid_display.has_signal("selection_count_changed"):
		plot_grid_display.selection_count_changed.connect(_on_selection_changed)
		print("   📡 Connected to plot selection changes")

	print("✅ FarmUI ready")


func _input(event: InputEvent) -> void:
	"""Handle any additional UI input (tool switching is handled by FarmInputHandler via signals)"""
	# Note: Tool selection (1-4) is handled by FarmInputHandler and triggers tool_changed signal
	# No need to duplicate handling here
	pass


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
