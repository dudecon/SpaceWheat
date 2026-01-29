class_name ToolSelectionRow
extends "res://UI/Panels/SelectionButtonRow.gd"

## Physical keyboard layout UI - Bottom row with tool selection buttons [1-4]
## Each button shows the keyboard shortcut and highlights when selected
## v2 Architecture: 4 tools per mode (PLAY/BUILD), Tab toggles mode
## Uses BtnBtmMidl.svg from Assets/UI/Chrome for sci-fi aesthetic

# Tool definitions from shared config (single source of truth)
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")


# Current mode ("play" or "build")
var current_mode: String = "play"

var current_tool: int = 3  # Default to tool 3 (matches ToolConfig.current_group)

# Signal
signal tool_selected(tool_num: int)


func _ready():
	# Z-index: ActionBarLayer(50) + 5 = 55 total, below quest(100)
	z_index = 5
	super._ready()
	_rebuild_buttons()

	# Select tool from ToolConfig (single source of truth)
	var initial_tool = ToolConfig.get_current_group()
	select_tool(initial_tool)

	print("🛠️  ToolSelectionRow initialized with BtnBtmMidl textures (4 tools, starting at %d)" % initial_tool)

func _rebuild_buttons() -> void:
	var tools = ToolConfig.get_current_tools()
	var button_specs: Array[Dictionary] = []
	for tool_num in range(1, 5):
		var tool_info = tools.get(tool_num, {})
		var tool_name = tool_info.get("name", "Unknown")
		var tool_emoji = tool_info.get("emoji", "")
		var icon_path = tool_info.get("icon", "")
		var label_text = ""
		if icon_path != "":
			label_text = "[%d] %s" % [tool_num, tool_name]
		else:
			label_text = "[%d] %s %s" % [tool_num, tool_emoji, tool_name]
		button_specs.append({
			"id": tool_num,
			"text": label_text,
			"icon_path": icon_path,
			"enabled": true
		})
	build_buttons(button_specs)
	if not button_selected.is_connected(_on_button_selected):
		button_selected.connect(_on_button_selected)


func _on_button_selected(tool_num: int) -> void:
	select_tool(tool_num)
	tool_selected.emit(tool_num)
	var tools = ToolConfig.get_current_tools()
	var tool_info = tools.get(tool_num, {})
	print("⌨️  Tool %d selected [%s button]" % [tool_num, tool_info.get("name", "Unknown")])


func select_tool(tool_num: int) -> void:
	"""Select a tool and update button styling."""
	if tool_num < 1 or tool_num > 4:
		return

	current_tool = tool_num
	set_selected(tool_num)


func set_tool_enabled(tool_num: int, enabled: bool) -> void:
	"""Enable or disable a specific tool button."""
	set_button_enabled(tool_num, enabled)


func refresh_for_mode(new_mode: String) -> void:
	"""Update button labels when mode changes between PLAY and BUILD.

	Called by PlayerShell when Tab is pressed.
	"""
	if new_mode not in ["play", "build"]:
		return

	current_mode = new_mode
	_rebuild_buttons()

	# Reset to tool 1 on mode change
	select_tool(1)

	print("🛠️  ToolSelectionRow refreshed for %s mode" % new_mode.to_upper())


# ============================================================================
# LEGACY COMPATIBILITY
# ============================================================================

func _on_tool_button_pressed(tool_num: int) -> void:
	"""Legacy handler - now handled by _on_tool_button_input."""
	select_tool(tool_num)
	tool_selected.emit(tool_num)


func _print_corners() -> void:
	"""DEBUG: Print actual corner positions of toolbar."""
	var tl = position
	var tr = position + Vector2(size.x, 0)
	var bl = position + Vector2(0, size.y)
	var br = position + size

	print("\n🎯 ToolSelectionRow CORNERS:")
	print("  Top-Left:     (%.1f, %.1f)" % [tl.x, tl.y])
	print("  Top-Right:    (%.1f, %.1f)" % [tr.x, tr.y])
	print("  Bottom-Left:  (%.1f, %.1f)" % [bl.x, bl.y])
	print("  Bottom-Right: (%.1f, %.1f)" % [br.x, br.y])
	print("  Size: %.1f × %.1f" % [size.x, size.y])
	print("  Parent size: %.1f × %.1f" % [get_parent().size.x, get_parent().size.y])
	print()


func debug_layout() -> String:
	"""Return detailed layout debug information for F3 display."""
	var debug_text = ""
	debug_text += "ToolSelectionRow (1-4 toolbar):\n"
	debug_text += "  Position: (%.0f, %.0f)\n" % [position.x, position.y]
	debug_text += "  Actual size: %.0f × %.0f\n" % [size.x, size.y]
	debug_text += "  Custom min size: %s\n" % custom_minimum_size
	debug_text += "  Size flags H: %d (3=EXPAND_FILL)\n" % size_flags_horizontal
	debug_text += "  Size flags V: %d\n" % size_flags_vertical
	debug_text += "  Buttons: %d total (BtnBtmMidl style)\n" % buttons.size()

	var button_widths = []
	for btn_data in buttons:
		button_widths.append("%.0f" % btn_data.container.size.x)
	debug_text += "  Button widths: [%s] (should be equal for stretch)\n" % ", ".join(button_widths)

	return debug_text
