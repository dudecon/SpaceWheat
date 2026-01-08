class_name ToolSelectionRow
extends HBoxContainer

## Physical keyboard layout UI - Bottom row with tool selection buttons [1-6]
## Each button shows the keyboard shortcut and highlights when selected

# Tool definitions from shared config (single source of truth)
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const TOOL_ACTIONS = ToolConfig.TOOL_ACTIONS

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
	# Z-index: ActionBarLayer(50) + 5 = 55 total, below quest(100)
	z_index = 5

	# Container setup
	# Note: Don't use anchors in container children - let parent handle layout
	# Increased separation and padding for touch-friendly appearance
	add_theme_constant_override("separation", 12)  # More space between buttons
	add_theme_constant_override("margin_left", 15)  # Left padding
	add_theme_constant_override("margin_right", 15)  # Right padding
	add_theme_constant_override("margin_top", 8)  # Top padding
	add_theme_constant_override("margin_bottom", 8)  # Bottom padding
	# CRITICAL: Don't set alignment here - let buttons' size_flags_horizontal handle distribution

	# Allow keyboard input to pass through, but buttons can still receive clicks
	mouse_filter = MOUSE_FILTER_PASS
	# Toolbar stretches to fill full width
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Create buttons for tools 1-6
	for tool_num in range(1, 7):
		var button = Button.new()
		var tool_info = TOOL_ACTIONS.get(tool_num, {})
		var tool_name = tool_info.get("name", "Unknown")

		# Button label with keyboard shortcut
		button.text = "[%d] %s" % [tool_num, tool_name]
		# Use SIZE_EXPAND_FILL to make buttons expand to fill available space
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Set stretch_ratio to 1.0 to distribute width equally among all buttons
		button.size_flags_stretch_ratio = 1.0
		# 0 width = full expansion, let layout system handle equal distribution
		button.custom_minimum_size = Vector2(0, 55 * scale_factor)
		# CRITICAL FIX: Clip text overflow so button doesn't size based on text width
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

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

	# Update all button styleboxes (not modulate - styleboxes override it)
	for i in range(tool_buttons.size()):
		var button = tool_buttons[i]
		var tool_idx = i + 1

		# CRITICAL: Must update ALL states (normal, hover, pressed) or selection disappears on interaction
		var is_selected = (tool_idx == tool_num)

		# Normal state
		var old_normal = button.get_theme_stylebox("normal")
		var stylebox_normal = old_normal.duplicate() if old_normal else StyleBoxFlat.new()
		if is_selected:
			stylebox_normal.bg_color = Color(0.0, 0.8, 0.8)
			stylebox_normal.border_color = Color(0.0, 1.0, 1.0)
		else:
			stylebox_normal.bg_color = Color(0.4, 0.4, 0.4)
			stylebox_normal.border_color = Color(0.8, 0.8, 0.8)
		button.add_theme_stylebox_override("normal", stylebox_normal)

		# Hover state (lighter than normal)
		var stylebox_hover = stylebox_normal.duplicate()
		if is_selected:
			stylebox_hover.bg_color = Color(0.2, 1.0, 1.0)  # Brighter cyan
		else:
			stylebox_hover.bg_color = Color(0.6, 0.6, 0.6)  # Light gray
		button.add_theme_stylebox_override("hover", stylebox_hover)

		# Pressed state (darker than normal)
		var stylebox_pressed = stylebox_normal.duplicate()
		if is_selected:
			stylebox_pressed.bg_color = Color(0.0, 0.6, 0.6)  # Darker cyan
			stylebox_pressed.border_color = Color(0.0, 0.8, 0.8)
		else:
			stylebox_pressed.bg_color = Color(0.2, 0.2, 0.2)  # Dark gray
			stylebox_pressed.border_color = Color(0.4, 0.4, 0.4)
		button.add_theme_stylebox_override("pressed", stylebox_pressed)

		# CRITICAL: Force visual update
		button.queue_redraw()


func set_tool_enabled(tool_num: int, enabled: bool) -> void:
	"""Enable or disable a specific tool button"""
	if tool_num < 1 or tool_num > 6:
		return

	var button = tool_buttons[tool_num - 1]
	button.disabled = not enabled

	if not enabled:
		# Update stylebox for disabled state - MUST duplicate!
		var old_stylebox = button.get_theme_stylebox("normal")
		if old_stylebox:
			var stylebox = old_stylebox.duplicate()
			stylebox.bg_color = Color(0.2, 0.2, 0.2)  # Dark gray
			stylebox.border_color = Color(0.4, 0.4, 0.4)  # Darker border
			button.add_theme_stylebox_override("normal", stylebox)
	else:
		# Re-apply current tool selection styling
		_update_tool_visual(current_tool)


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


func _print_corners() -> void:
	"""DEBUG: Print actual corner positions of toolbar"""
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
	"""Return detailed layout debug information for F3 display"""
	var debug_text = ""
	debug_text += "ToolSelectionRow (1-6 toolbar):\n"
	debug_text += "  Position: (%.0f, %.0f)\n" % [position.x, position.y]
	debug_text += "  Actual size: %.0f × %.0f\n" % [size.x, size.y]
	debug_text += "  Custom min size: %s\n" % custom_minimum_size
	debug_text += "  Size flags H: %d (3=EXPAND_FILL)\n" % size_flags_horizontal
	debug_text += "  Size flags V: %d\n" % size_flags_vertical
	debug_text += "  Buttons: %d total (1-6)\n" % tool_buttons.size()

	var button_widths = []
	for i in range(tool_buttons.size()):
		var btn = tool_buttons[i]
		button_widths.append("%.0f" % btn.size.x)
	debug_text += "  Button widths: [%s] (should be equal for stretch)\n" % ", ".join(button_widths)

	return debug_text



	# DEBUG OUTPUT
	print("═══════════════════════════════════════════════════════════════")
	print("DEBUG: ToolSelectionRow (1-6 toolbar)")
	print("═══════════════════════════════════════════════════════════════")
	print("  Name: ToolSelectionRow")
	print("  Parent: %s" % get_parent().name)
	print("  Size flags H: %d (3=SIZE_EXPAND_FILL)" % size_flags_horizontal)
	print("  Custom minimum size: %s" % custom_minimum_size)
	print("═══════════════════════════════════════════════════════════════")
