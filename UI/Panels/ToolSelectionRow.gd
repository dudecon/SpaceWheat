class_name ToolSelectionRow
extends HBoxContainer

## Physical keyboard layout UI - Bottom row with tool selection buttons [1-4]
## Each button shows the keyboard shortcut and highlights when selected
## v2 Architecture: 4 tools per mode (PLAY/BUILD), Tab toggles mode
## Uses BtnBtmMidl.svg from Assets/UI/Chrome for sci-fi aesthetic

# Tool definitions from shared config (single source of truth)
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

# Button texture path
const BTN_TEXTURE_PATH = "res://Assets/UI/Chrome/BtnBtmMidl.svg"

# Current mode ("play" or "build")
var current_mode: String = "play"

# Button data array - each element is {container, texture, label, tool_num}
var tool_buttons: Array[Dictionary] = []
var current_tool: int = 1

# Styling - colors applied via modulate on the TextureRect
var selected_color: Color = Color(0.4, 1.0, 1.0)  # Bright cyan for selected
var normal_color: Color = Color(1.0, 1.0, 1.0)    # Natural texture color
var hover_color: Color = Color(1.2, 1.2, 1.2)     # Slightly brighter on hover
var pressed_color: Color = Color(0.6, 0.6, 0.6)   # Darker when pressed
var disabled_color: Color = Color(0.3, 0.3, 0.3)  # Dark for disabled

# Layout manager for scaling
var layout_manager
var scale_factor: float = 1.0

# Preloaded button texture
var btn_texture: Texture2D = null

# Signal
signal tool_selected(tool_num: int)


func _ready():
	# Z-index: ActionBarLayer(50) + 5 = 55 total, below quest(100)
	z_index = 5

	# Load button texture
	btn_texture = load(BTN_TEXTURE_PATH)
	if not btn_texture:
		push_warning("ToolSelectionRow: Could not load button texture from %s" % BTN_TEXTURE_PATH)

	# Container setup
	add_theme_constant_override("separation", 8)
	add_theme_constant_override("margin_left", 8)
	add_theme_constant_override("margin_right", 8)
	add_theme_constant_override("margin_top", 4)
	add_theme_constant_override("margin_bottom", 4)

	# Allow keyboard input to pass through, but buttons can still receive clicks
	mouse_filter = MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Create buttons for tools 1-4 (v2 architecture)
	for tool_num in range(1, 5):
		var btn_data = _create_tool_button(tool_num)
		add_child(btn_data.container)
		tool_buttons.append(btn_data)

	# Select first tool by default
	select_tool(1)

	print("🛠️  ToolSelectionRow initialized with BtnBtmMidl textures (4 tools)")


func _create_tool_button(tool_num: int) -> Dictionary:
	"""Create a tool button with texture background and text label.

	Returns a Dictionary with:
	- container: The root Control node
	- texture: The TextureRect for button background
	- label: The Label for button text
	- tool_num: The tool number (1-4)
	- disabled: bool tracking disabled state
	"""
	var tools = ToolConfig.get_current_tools()
	var tool_info = tools.get(tool_num, {})
	var tool_name = tool_info.get("name", "Unknown")
	var tool_emoji = tool_info.get("emoji", "")

	# Container to hold texture and label
	var container = Control.new()
	container.name = "ToolBtn_%d" % tool_num
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.size_flags_stretch_ratio = 1.0
	container.custom_minimum_size = Vector2(0, 50 * scale_factor)
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	# TextureRect for button background
	var texture_rect = TextureRect.new()
	texture_rect.name = "BtnTexture"
	texture_rect.texture = btn_texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(texture_rect)

	# Label for button text (centered over texture)
	var label = Label.new()
	label.name = "ButtonLabel"
	label.text = "[%d] %s %s" % [tool_num, tool_emoji, tool_name]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", int(16 * scale_factor))
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	container.add_child(label)

	# Connect input events
	container.gui_input.connect(_on_tool_button_input.bind(tool_num))
	container.mouse_entered.connect(_on_tool_button_hover.bind(tool_num, true))
	container.mouse_exited.connect(_on_tool_button_hover.bind(tool_num, false))

	return {
		"container": container,
		"texture": texture_rect,
		"label": label,
		"tool_num": tool_num,
		"disabled": false
	}


func _on_tool_button_input(event: InputEvent, tool_num: int) -> void:
	"""Handle input on tool button container."""
	var btn_data = _get_button_data(tool_num)
	if not btn_data or btn_data.disabled:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Visual feedback on press
				btn_data.texture.modulate = pressed_color
			else:
				# Select tool and emit signal on release
				select_tool(tool_num)
				tool_selected.emit(tool_num)
				var tools = ToolConfig.get_current_tools()
				var tool_info = tools.get(tool_num, {})
				print("⌨️  Tool %d selected [%s button]" % [tool_num, tool_info.get("name", "Unknown")])

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()


func _on_tool_button_hover(tool_num: int, is_hovering: bool) -> void:
	"""Handle mouse hover on tool button."""
	var btn_data = _get_button_data(tool_num)
	if not btn_data or btn_data.disabled:
		return

	# Don't change color if this is the selected tool
	if tool_num == current_tool:
		return

	if is_hovering:
		btn_data.texture.modulate = hover_color
	else:
		btn_data.texture.modulate = normal_color


func _get_button_data(tool_num: int) -> Dictionary:
	"""Get button data for a tool number (1-4)."""
	if tool_num < 1 or tool_num > tool_buttons.size():
		return {}
	return tool_buttons[tool_num - 1]


func select_tool(tool_num: int) -> void:
	"""Select a tool and update button styling."""
	if tool_num < 1 or tool_num > 4:
		return

	current_tool = tool_num

	# Update all button colors
	for btn_data in tool_buttons:
		if btn_data.disabled:
			btn_data.texture.modulate = disabled_color
		elif btn_data.tool_num == tool_num:
			btn_data.texture.modulate = selected_color
		else:
			btn_data.texture.modulate = normal_color


func set_tool_enabled(tool_num: int, enabled: bool) -> void:
	"""Enable or disable a specific tool button."""
	var btn_data = _get_button_data(tool_num)
	if btn_data.is_empty():
		return

	btn_data.disabled = not enabled

	if not enabled:
		btn_data.texture.modulate = disabled_color
	else:
		# Restore appropriate color based on selection
		if tool_num == current_tool:
			btn_data.texture.modulate = selected_color
		else:
			btn_data.texture.modulate = normal_color


func set_layout_manager(mgr) -> void:
	"""Set layout manager for responsive scaling."""
	layout_manager = mgr
	if layout_manager:
		scale_factor = layout_manager.scale_factor


func refresh_for_mode(new_mode: String) -> void:
	"""Update button labels when mode changes between PLAY and BUILD.

	Called by PlayerShell when Tab is pressed.
	"""
	if new_mode not in ["play", "build"]:
		return

	current_mode = new_mode
	var tools = ToolConfig.get_current_tools()

	# Update button labels
	for btn_data in tool_buttons:
		var tool_num = btn_data.tool_num
		var tool_info = tools.get(tool_num, {})
		var tool_name = tool_info.get("name", "Unknown")
		var tool_emoji = tool_info.get("emoji", "")
		btn_data.label.text = "[%d] %s %s" % [tool_num, tool_emoji, tool_name]

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
	debug_text += "  Buttons: %d total (BtnBtmMidl style)\n" % tool_buttons.size()

	var button_widths = []
	for btn_data in tool_buttons:
		button_widths.append("%.0f" % btn_data.container.size.x)
	debug_text += "  Button widths: [%s] (should be equal for stretch)\n" % ", ".join(button_widths)

	return debug_text
