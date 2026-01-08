class_name ActionPreviewRow
extends HBoxContainer

## Physical keyboard layout UI - Middle row with QER action preview buttons
## Displays what Q/E/R actions will do based on selected tool
## Buttons are touch-friendly and also show keyboard shortcuts

# Tool actions from shared config (single source of truth)
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const TOOL_ACTIONS = ToolConfig.TOOL_ACTIONS

# Action buttons
var action_buttons: Dictionary = {}  # "Q", "E", "R" -> Button
var current_tool: int = 1
var current_submenu: String = ""  # Active submenu name (empty = show tool actions)

# References for checking action availability
var plot_grid_display = null  # Injected reference to PlotGridDisplay
var farm = null  # Injected reference to Farm
var input_handler = null  # Injected reference to FarmInputHandler (for validation)

# Styling
var button_color: Color = Color(0.45, 0.45, 0.45)  # Lighter base color for visibility
var hover_color: Color = Color(0.6, 0.6, 0.6)
var disabled_color: Color = Color(0.15, 0.15, 0.15)  # Much darker for clear disabled state
var enabled_color: Color = Color(0.3, 0.9, 0.3)  # Bright green for available actions

# Layout manager for scaling
var layout_manager
var scale_factor: float = 1.0

# Signals
signal action_pressed(action_key: String)


func _ready():
	# Z-index: Above quest board (3500), above tool selection (3000)
	z_index = 4000

	# Container setup
	# Note: Don't use anchors in container children - let parent handle layout
	add_theme_constant_override("separation", 10)
	# CRITICAL: Don't set alignment here - let buttons' size_flags_horizontal handle distribution

	# Allow keyboard input to pass through, but buttons can still receive clicks
	mouse_filter = MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Create Q, E, R action buttons with proper size_flags
	for action_key in ["Q", "E", "R"]:
		var button = Button.new()
		button.text = "[%s]" % action_key
		# Use SIZE_EXPAND_FILL (3) to make buttons expand to fill available space
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Set stretch_ratio to 1.0 to distribute width equally among all buttons
		button.size_flags_stretch_ratio = 1.0
		button.custom_minimum_size = Vector2(0, 50 * scale_factor)  # 0 width = full expansion
		# CRITICAL FIX: Clip text overflow so button doesn't size based on text width
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

		button.modulate = button_color

		# Don't let buttons steal keyboard focus
		button.focus_mode = Control.FOCUS_NONE

		# Connect signal
		button.pressed.connect(_on_action_button_pressed.bindv([action_key]))

		# Add to container - layout system will handle size automatically
		add_child(button)
		action_buttons[action_key] = button

	# Update display for current tool
	update_for_tool(1)


func update_for_tool(tool_num: int) -> void:
	"""Update action buttons to show actions for the selected tool"""
	if tool_num < 1 or tool_num > 6:
		return

	current_tool = tool_num
	current_submenu = ""  # Clear submenu when tool changes

	var tool_info = TOOL_ACTIONS.get(tool_num, {})

	# Update each action button
	for action_key in ["Q", "E", "R"]:
		if not action_buttons.has(action_key):
			continue

		var button = action_buttons[action_key]
		var action_info = tool_info.get(action_key, {})
		var label = action_info.get("label", "?")
		var emoji = action_info.get("emoji", "")

		# Update button text
		button.text = "[%s] %s %s" % [action_key, emoji, label]

	# Update action availability based on selected plots
	update_action_availability()


func update_for_submenu(submenu_name: String, submenu_info: Dictionary) -> void:
	"""Update action buttons to show submenu actions

	Called when entering a submenu (e.g., 1-Q opens plant submenu).
	submenu_info contains Q/E/R action definitions.
	"""
	if submenu_name == "":
		# Exiting submenu - restore tool display
		current_submenu = ""
		update_for_tool(current_tool)
		return

	current_submenu = submenu_name

	# Check if entire submenu is disabled
	var is_disabled = submenu_info.get("_disabled", false)

	# Update each action button with submenu actions
	for action_key in ["Q", "E", "R"]:
		if not action_buttons.has(action_key):
			continue

		var button = action_buttons[action_key]

		# CRITICAL FIX: Force button out of pressed state before text update
		# This ensures touch and keyboard render the same way
		button.button_pressed = false

		var action_info = submenu_info.get(action_key, {})
		var label = action_info.get("label", "?")
		var emoji = action_info.get("emoji", "")
		var action = action_info.get("action", "")

		# Update button text with submenu prefix
		button.text = "[%s] %s %s" % [action_key, emoji, label]

		# Handle disabled/locked states (truly unavailable slots only)
		if is_disabled or action == "":
			button.disabled = true
			button.modulate = disabled_color
		else:
			# Don't set color here - let validation system handle it below
			button.disabled = false

	# CRITICAL: Update button colors based on validation (resources, plot states, etc.)
	# This must happen AFTER text is updated so validation knows what submenu we're in
	update_action_availability()


func update_for_quest_board(slot_state: int, is_locked: bool = false) -> void:
	"""Update action buttons to show quest-specific actions

	Called when quest board is open and selection changes.
	Shows context-aware quest actions based on slot state.
	"""
	current_submenu = "quest_board"  # Mark as special mode

	# Quest slot states (from QuestBoard)
	const EMPTY = 0
	const OFFERED = 1
	const ACTIVE = 2
	const READY = 3

	match slot_state:
		EMPTY:
			# Empty slot - only E to generate
			action_buttons["Q"].text = "[Q] -"
			action_buttons["Q"].disabled = true
			action_buttons["Q"].modulate = disabled_color

			action_buttons["E"].text = "[E] 🔄 Generate"
			action_buttons["E"].disabled = false
			action_buttons["E"].modulate = enabled_color

			action_buttons["R"].text = "[R] -"
			action_buttons["R"].disabled = true
			action_buttons["R"].modulate = disabled_color

		OFFERED:
			# Offered quest - Q=Accept, E=Reroll, R=Lock/Unlock
			action_buttons["Q"].text = "[Q] ✅ Accept"
			action_buttons["Q"].disabled = false
			action_buttons["Q"].modulate = enabled_color

			action_buttons["E"].text = "[E] 🔄 Reroll"
			action_buttons["E"].disabled = is_locked
			action_buttons["E"].modulate = disabled_color if is_locked else button_color

			action_buttons["R"].text = "[R] 🔒 %s" % ("Unlock" if is_locked else "Lock")
			action_buttons["R"].disabled = false
			action_buttons["R"].modulate = button_color

		ACTIVE:
			# Active quest - Q=Complete, E=Abandon
			action_buttons["Q"].text = "[Q] ✅ Complete"
			action_buttons["Q"].disabled = false
			action_buttons["Q"].modulate = enabled_color

			action_buttons["E"].text = "[E] ❌ Abandon"
			action_buttons["E"].disabled = false
			action_buttons["E"].modulate = Color(0.6, 0.2, 0.2)  # Red tint for danger

			action_buttons["R"].text = "[R] -"
			action_buttons["R"].disabled = true
			action_buttons["R"].modulate = disabled_color

		READY:
			# Ready to complete - Q=Claim, E=Abandon
			action_buttons["Q"].text = "[Q] 💰 CLAIM"
			action_buttons["Q"].disabled = false
			action_buttons["Q"].modulate = Color(0.2, 0.8, 0.2)  # Bright green for reward

			action_buttons["E"].text = "[E] ❌ Abandon"
			action_buttons["E"].disabled = false
			action_buttons["E"].modulate = Color(0.6, 0.2, 0.2)

			action_buttons["R"].text = "[R] -"
			action_buttons["R"].disabled = true
			action_buttons["R"].modulate = disabled_color


func restore_normal_mode() -> void:
	"""Restore normal tool display (called when quest board closes)"""
	if current_submenu == "quest_board":
		current_submenu = ""
		update_for_tool(current_tool)


func set_action_enabled(action_key: String, enabled: bool) -> void:
	"""Enable or disable a specific action button"""
	if not action_buttons.has(action_key):
		return

	var button = action_buttons[action_key]
	button.disabled = not enabled

	if not enabled:
		button.modulate = disabled_color
	else:
		button.modulate = button_color


func update_action_availability() -> void:
	"""Check selected plots and highlight available actions"""
	# Check if we have references
	if not plot_grid_display or not plot_grid_display.has_method("get_selected_plots"):
		update_button_highlights({"Q": false, "E": false, "R": false})
		return

	var selected_plots = plot_grid_display.get_selected_plots()
	if selected_plots.is_empty():
		update_button_highlights({"Q": false, "E": false, "R": false})
		return

	# Get input handler reference
	if not input_handler:
		# Fallback: naive behavior (all enabled if plots selected)
		var has_selection = selected_plots.size() > 0
		update_button_highlights({"Q": has_selection, "E": has_selection, "R": has_selection})
		return

	# Check each action individually using validation API
	var availability = {
		"Q": input_handler.can_execute_action("Q"),
		"E": input_handler.can_execute_action("E"),
		"R": input_handler.can_execute_action("R"),
	}

	update_button_highlights(availability)


func update_button_highlights(availability: Dictionary) -> void:
	"""Highlight buttons based on per-action availability

	Args:
		availability: Dictionary with "Q"/"E"/"R" keys mapping to bool
	"""
	for action_key in ["Q", "E", "R"]:
		if not action_buttons.has(action_key):
			continue

		var button = action_buttons[action_key]

		# Skip if button is already disabled (locked slot from submenu)
		if button.disabled:
			continue

		var is_available = availability.get(action_key, false)

		if is_available:
			# Actions available - highlight in bright green
			button.modulate = enabled_color
		else:
			# Action not available (no resources, wrong state, etc) - show as base color
			button.modulate = button_color


func set_layout_manager(mgr) -> void:
	"""Set layout manager for responsive scaling"""
	layout_manager = mgr
	if layout_manager:
		scale_factor = layout_manager.scale_factor


# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _on_action_button_pressed(action_key: String) -> void:
	"""Handle action button press"""
	action_pressed.emit(action_key)


func debug_layout() -> String:
	"""Return detailed layout debug information for F3 display"""
	var debug_text = ""
	debug_text += "ActionPreviewRow (Q/E/R toolbar):\n"
	debug_text += "  Position: (%.0f, %.0f)\n" % [position.x, position.y]
	debug_text += "  Actual size: %.0f × %.0f\n" % [size.x, size.y]
	debug_text += "  Custom min size: %s\n" % custom_minimum_size
	debug_text += "  Size flags H: %d (3=EXPAND_FILL)\n" % size_flags_horizontal
	debug_text += "  Size flags V: %d\n" % size_flags_vertical
	debug_text += "  Buttons: %d total\n" % action_buttons.size()

	var button_widths = []
	for action_key in ["Q", "E", "R"]:
		if action_buttons.has(action_key):
			var btn = action_buttons[action_key]
			button_widths.append("%.0f" % btn.size.x)
	debug_text += "  Button widths: [%s] (should be equal for stretch)\n" % ", ".join(button_widths)

	return debug_text
