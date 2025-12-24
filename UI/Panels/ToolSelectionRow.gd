class_name ToolSelectionRow
extends HBoxContainer

## Physical keyboard layout UI - Bottom row with tool selection buttons [1-6]
## Each button shows the keyboard shortcut and highlights when selected

# Tool definitions (synced from FarmInputHandler)
const TOOL_ACTIONS = {
	1: {"name": "Grower", "emoji": "🌱"},
	2: {"name": "Quantum", "emoji": "⚛️"},
	3: {"name": "Industry", "emoji": "🏭"},
	4: {"name": "Energy", "emoji": "⚡"},
	5: {"name": "Future 5", "emoji": "5️⃣"},
	6: {"name": "Future 6", "emoji": "6️⃣"},
}

# Button array
var tool_buttons: Array[Button] = []
var current_tool: int = 1

# Styling
var selected_color: Color = Color(0.0, 1.0, 1.0)  # Cyan for selected
var normal_color: Color = Color(0.5, 0.5, 0.5)    # Gray for unselected
var hover_color: Color = Color(0.7, 0.7, 0.7)     # Light gray for hover
var disabled_color: Color = Color(0.3, 0.3, 0.3)  # Dark gray for disabled

# Layout manager for scaling
var layout_manager
var scale_factor: float = 1.0

# Signal
signal tool_selected(tool_num: int)


func _ready():
	# Container setup
	# Note: Don't use anchors in container children - let parent handle layout
	# Increased separation and padding for touch-friendly appearance
	add_theme_constant_override("separation", 12)  # More space between buttons
	add_theme_constant_override("margin_left", 15)  # Left padding
	add_theme_constant_override("margin_right", 15)  # Right padding
	add_theme_constant_override("margin_top", 8)  # Top padding
	add_theme_constant_override("margin_bottom", 8)  # Bottom padding
	alignment = BoxContainer.ALIGNMENT_BEGIN

	# Ensure buttons don't block keyboard input
	mouse_filter = MOUSE_FILTER_IGNORE

	# Create buttons for tools 1-6
	for tool_num in range(1, 7):
		var button = Button.new()
		var tool_info = TOOL_ACTIONS.get(tool_num, {})
		var tool_name = tool_info.get("name", "Unknown")

		# Button label with keyboard shortcut
		button.text = "[%d] %s" % [tool_num, tool_name]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(90 * scale_factor, 55 * scale_factor)

		# Don't let buttons steal keyboard focus - keyboard is for input handler
		button.focus_mode = Control.FOCUS_NONE

		# Create beveled/3D StyleBox for touch-friendly appearance
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color(0.4, 0.4, 0.4)  # Default gray
		stylebox.border_color = Color(0.8, 0.8, 0.8)  # Light border for bevel
		stylebox.border_width_left = 2
		stylebox.border_width_top = 2
		stylebox.border_width_right = 2
		stylebox.border_width_bottom = 2
		stylebox.corner_radius_top_left = 4
		stylebox.corner_radius_top_right = 4
		stylebox.corner_radius_bottom_left = 4
		stylebox.corner_radius_bottom_right = 4
		button.add_theme_stylebox_override("normal", stylebox)

		# Hovered state (lighter)
		var stylebox_hover = stylebox.duplicate()
		stylebox_hover.bg_color = Color(0.6, 0.6, 0.6)
		button.add_theme_stylebox_override("hover", stylebox_hover)

		# Pressed state (darker for 3D effect)
		var stylebox_pressed = stylebox.duplicate()
		stylebox_pressed.bg_color = Color(0.2, 0.2, 0.2)
		stylebox_pressed.border_color = Color(0.4, 0.4, 0.4)
		button.add_theme_stylebox_override("pressed", stylebox_pressed)

		# Connect signal
		button.pressed.connect(_on_tool_button_pressed.bindv([tool_num]))

		# Add to container
		add_child(button)
		tool_buttons.append(button)

	# Select first tool by default
	select_tool(1)
	print("🛠️  ToolSelectionRow initialized with 6 tools - beveled touch-friendly buttons")


func select_tool(tool_num: int) -> void:
	"""Select a tool and update button styling (internal - use for UI sync without emitting signal)"""
	_update_tool_visual(tool_num)


func _update_tool_visual(tool_num: int) -> void:
	"""Internal: Update visual state without emitting signal (called by button handler)"""
	if tool_num < 1 or tool_num > 6:
		return

	current_tool = tool_num

	# Update all button colors
	for i in range(tool_buttons.size()):
		var button = tool_buttons[i]
		var tool_idx = i + 1

		if tool_idx == tool_num:
			# Selected tool: bright cyan
			button.modulate = selected_color
		else:
			# Unselected: normal gray
			button.modulate = normal_color


func set_tool_enabled(tool_num: int, enabled: bool) -> void:
	"""Enable or disable a specific tool button"""
	if tool_num < 1 or tool_num > 6:
		return

	var button = tool_buttons[tool_num - 1]
	button.disabled = not enabled

	if not enabled:
		button.modulate = disabled_color


func set_layout_manager(mgr) -> void:
	"""Set layout manager for responsive scaling"""
	layout_manager = mgr
	if layout_manager:
		scale_factor = layout_manager.scale_factor


# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _on_tool_button_pressed(tool_num: int) -> void:
	"""Handle tool button press"""
	_update_tool_visual(tool_num)
	tool_selected.emit(tool_num)  # Explicitly emit signal after visual update
	print("⌨️  Tool %d selected [%s button]" % [tool_num, TOOL_ACTIONS[tool_num]["name"]])
