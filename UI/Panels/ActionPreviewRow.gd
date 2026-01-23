class_name ActionPreviewRow
extends HBoxContainer

## Physical keyboard layout UI - Middle row with QER action preview buttons
## Displays what Q/E/R actions will do based on selected tool
## Buttons are touch-friendly hexagonal buttons with custom texture
## Uses HexButton.svg from Assets/UI/Chrome for sci-fi aesthetic

# Tool actions from shared config (single source of truth)
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const TOOL_ACTIONS = ToolConfig.TOOL_ACTIONS

# HexButton texture path
const HEX_BUTTON_PATH = "res://Assets/UI/Chrome/HexButton.svg"

# Action buttons - now stores container references with .texture and .label children
var action_buttons: Dictionary = {}  # "Q", "E", "R" -> {container, texture, label, disabled}
var current_tool: int = 1
var current_submenu: String = ""  # Active submenu name (empty = show tool actions)

# References for checking action availability
var plot_grid_display = null  # Injected reference to PlotGridDisplay
var farm = null  # Injected reference to Farm
var input_handler = null  # Injected reference to FarmInputHandler (for validation)

# Styling - colors applied via modulate on the TextureRect
var button_color: Color = Color(1.0, 1.0, 1.0)  # Normal state (texture's natural color)
var hover_color: Color = Color(1.2, 1.2, 1.2)  # Slightly brighter on hover
var disabled_color: Color = Color(0.3, 0.3, 0.3)  # Dark for disabled
var enabled_color: Color = Color(0.5, 1.0, 0.5)  # Green tint for available actions
var pressed_color: Color = Color(0.7, 0.7, 0.7)  # Darker when pressed

# Layout manager for scaling
var layout_manager
var scale_factor: float = 1.0

# Preloaded hex button texture
var hex_button_texture: Texture2D = null

# Signals
signal action_pressed(action_key: String)


func _ready():
	# Z-index: Above quest board (3500), above tool selection (3000)
	z_index = 4000

	# Load hex button texture
	hex_button_texture = load(HEX_BUTTON_PATH)
	if not hex_button_texture:
		push_warning("ActionPreviewRow: Could not load HexButton texture from %s" % HEX_BUTTON_PATH)

	# Container setup
	# Note: Don't use anchors in container children - let parent handle layout
	# Reduced spacing to give more room to buttons themselves
	add_theme_constant_override("separation", 12)  # Slightly more space for hex buttons
	add_theme_constant_override("margin_left", 4)
	add_theme_constant_override("margin_right", 4)
	add_theme_constant_override("margin_top", 2)
	add_theme_constant_override("margin_bottom", 2)

	# Allow keyboard input to pass through, but buttons can still receive clicks
	mouse_filter = MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Create Q, E, R hex action buttons
	for action_key in ["Q", "E", "R"]:
		var hex_btn = _create_hex_button(action_key)
		add_child(hex_btn.container)
		action_buttons[action_key] = hex_btn

	# Update display for current tool
	update_for_tool(1)
	print("⬡ ActionPreviewRow initialized with HexButton textures")


func update_for_tool(tool_num: int) -> void:
	"""Update action buttons to show actions for the selected tool"""
	if tool_num < 1 or tool_num > 4:  # v2: 4 tools per mode
		return

	current_tool = tool_num
	current_submenu = ""  # Clear submenu when tool changes

	# Update each action button using ToolConfig API (respects F-cycling)
	for action_key in ["Q", "E", "R"]:
		if not action_buttons.has(action_key):
			continue

		var btn_data = action_buttons[action_key]
		var label_text = ToolConfig.get_action_label(tool_num, action_key)
		var emoji = ToolConfig.get_action_emoji(tool_num, action_key)
		var icon_path = ToolConfig.get_action_icon(tool_num, action_key)

		# Update button label text (shorter format for icon display)
		btn_data.label.text = "[%s] %s" % [action_key, label_text]

		# Load and display icon if available
		if icon_path != "" and btn_data.has("icon"):
			var icon_tex = load(icon_path)
			if icon_tex:
				btn_data.icon.texture = icon_tex
				btn_data.icon.visible = true
			else:
				btn_data.icon.visible = false
		elif btn_data.has("icon"):
			btn_data.icon.visible = false

		# Reset disabled state
		btn_data.disabled = false

	# For Tool 1 (Probe), enhance with preview info
	if tool_num == 1:
		_update_probe_preview()

	# Update action availability based on selected plots
	update_action_availability()


func update_for_submenu(submenu_name: String, submenu_info: Dictionary) -> void:
	"""Update action buttons to show submenu actions

	Called when entering a submenu (e.g., 1-Q opens plant submenu).
	submenu_info contains Q/E/R action definitions.

	Supports _availability dict for per-action availability (e.g., mill power sources).
	When _availability is present, unavailable actions are dimmed using disabled_color.
	"""
	if submenu_name == "":
		# Exiting submenu - restore tool display
		current_submenu = ""
		update_for_tool(current_tool)
		return

	current_submenu = submenu_name

	# Check if entire submenu is disabled
	var is_disabled = submenu_info.get("_disabled", false)

	# Get per-action availability (for mill submenus, etc.)
	# Keys are "Q", "E", "R" with bool values. Default to available if not specified.
	var availability = submenu_info.get("_availability", {})

	# Update each action button with submenu actions
	for action_key in ["Q", "E", "R"]:
		if not action_buttons.has(action_key):
			continue

		var btn_data = action_buttons[action_key]

		var action_info = submenu_info.get(action_key, {})
		var label_text = action_info.get("label", "?")
		var emoji = action_info.get("emoji", "")
		var action = action_info.get("action", "")
		var icon_path = action_info.get("icon", "")

		# Update button label text (shorter format)
		btn_data.label.text = "[%s] %s" % [action_key, label_text]

		# Load and display icon if available
		if icon_path != "" and btn_data.has("icon"):
			var icon_tex = load(icon_path)
			if icon_tex:
				btn_data.icon.texture = icon_tex
				btn_data.icon.visible = true
			else:
				btn_data.icon.visible = false
		elif btn_data.has("icon"):
			# No icon path - hide icon, show emoji in label instead
			btn_data.icon.visible = false
			btn_data.label.text = "[%s] %s %s" % [action_key, emoji, label_text]

		# Check per-action availability (from _availability dict)
		# Default to true (available) if not specified
		var is_available = availability.get(action_key, true)

		# Handle disabled/locked/unavailable states
		if is_disabled or action == "" or not is_available:
			btn_data.disabled = true
			btn_data.texture.modulate = disabled_color
		else:
			# Don't set color here - let validation system handle it below
			btn_data.disabled = false

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

	var q_data = action_buttons["Q"]
	var e_data = action_buttons["E"]
	var r_data = action_buttons["R"]

	match slot_state:
		EMPTY:
			# Empty slot - only E to generate
			q_data.label.text = "[Q] -"
			q_data.disabled = true
			q_data.texture.modulate = disabled_color

			e_data.label.text = "[E] 🔄 Generate"
			e_data.disabled = false
			e_data.texture.modulate = enabled_color

			r_data.label.text = "[R] -"
			r_data.disabled = true
			r_data.texture.modulate = disabled_color

		OFFERED:
			# Offered quest - Q=Accept, E=Reroll, R=Lock/Unlock
			q_data.label.text = "[Q] ✅ Accept"
			q_data.disabled = false
			q_data.texture.modulate = enabled_color

			e_data.label.text = "[E] 🔄 Reroll"
			e_data.disabled = is_locked
			e_data.texture.modulate = disabled_color if is_locked else button_color

			r_data.label.text = "[R] 🔒 %s" % ("Unlock" if is_locked else "Lock")
			r_data.disabled = false
			r_data.texture.modulate = button_color

		ACTIVE:
			# Active quest - Q=Complete, E=Abandon
			q_data.label.text = "[Q] ✅ Complete"
			q_data.disabled = false
			q_data.texture.modulate = enabled_color

			e_data.label.text = "[E] ❌ Abandon"
			e_data.disabled = false
			e_data.texture.modulate = Color(1.0, 0.4, 0.4)  # Red tint for danger

			r_data.label.text = "[R] -"
			r_data.disabled = true
			r_data.texture.modulate = disabled_color

		READY:
			# Ready to complete - Q=Claim, E=Abandon
			q_data.label.text = "[Q] 💰 CLAIM"
			q_data.disabled = false
			q_data.texture.modulate = Color(0.4, 1.0, 0.4)  # Bright green for reward

			e_data.label.text = "[E] ❌ Abandon"
			e_data.disabled = false
			e_data.texture.modulate = Color(1.0, 0.4, 0.4)

			r_data.label.text = "[R] -"
			r_data.disabled = true
			r_data.texture.modulate = disabled_color


func restore_normal_mode() -> void:
	"""Restore normal tool display (called when quest board closes)"""
	if current_submenu == "quest_board":
		current_submenu = ""
		update_for_tool(current_tool)


func set_action_enabled(action_key: String, enabled: bool) -> void:
	"""Enable or disable a specific action button"""
	if not action_buttons.has(action_key):
		return

	var btn_data = action_buttons[action_key]
	btn_data.disabled = not enabled

	if not enabled:
		btn_data.texture.modulate = disabled_color
	else:
		btn_data.texture.modulate = button_color


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

	# Update probe preview for Tool 1 (shows quantum state in button text)
	if current_tool == 1:
		_update_probe_preview()

	update_button_highlights(availability)


func update_button_highlights(availability: Dictionary) -> void:
	"""Highlight buttons based on per-action availability

	Args:
		availability: Dictionary with "Q"/"E"/"R" keys mapping to bool
	"""
	for action_key in ["Q", "E", "R"]:
		if not action_buttons.has(action_key):
			continue

		var btn_data = action_buttons[action_key]

		# Skip if button is already disabled (locked slot from submenu)
		if btn_data.disabled:
			continue

		var is_available = availability.get(action_key, false)

		# Store availability for hover state restoration
		btn_data["available"] = is_available

		if is_available:
			# Actions available - highlight with green tint
			btn_data.texture.modulate = enabled_color
		else:
			# Action not available (no resources, wrong state, etc) - show normal color
			btn_data.texture.modulate = button_color


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


func _update_probe_preview() -> void:
	"""Update Tool 1 (Probe) buttons with preview info from ProbeActions.

	Shows what registers are available for EXPLORE, what terminals can be
	measured, etc. Makes the quantum state visible before action.
	"""
	if not farm or not farm.plot_pool:
		return

	# Get current biome from selection
	var biome = null
	if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
		var selected = plot_grid_display.get_selected_plots()
		if not selected.is_empty() and farm.grid:
			biome = farm.grid.get_biome_for_plot(selected[0])

	if not biome:
		return

	# Get EXPLORE preview
	var explore_preview = ProbeActions.get_explore_preview(farm.plot_pool, biome)
	if explore_preview.can_explore and not explore_preview.top_probabilities.is_empty():
		# Show top probability in button text
		var top = explore_preview.top_probabilities[0]
		var emoji = top.get("emoji", "?")
		var prob = top.get("probability", 0.0) * 100
		action_buttons["Q"].label.text = "[Q] 🔍 Explore (%s %.0f%%)" % [emoji, prob]

	# Get MEASURE preview - find active terminal
	var active_terminals = []
	for terminal in farm.plot_pool.get_active_terminals():
		if terminal.bound_biome and terminal.bound_biome.get_biome_type() == biome.get_biome_type():
			active_terminals.append(terminal)

	if not active_terminals.is_empty():
		var terminal = active_terminals[0]
		var emoji = terminal.north_emoji if terminal.north_emoji else "?"
		action_buttons["E"].label.text = "[E] 👁️ Measure (%s)" % emoji

	# Get POP preview - find measured terminal
	var measured_terminals = []
	for terminal in farm.plot_pool.get_measured_terminals():
		if terminal.bound_biome and terminal.bound_biome.get_biome_type() == biome.get_biome_type():
			measured_terminals.append(terminal)

	if not measured_terminals.is_empty():
		var terminal = measured_terminals[0]
		var outcome = terminal.measured_outcome if terminal.measured_outcome else "?"
		action_buttons["R"].label.text = "[R] ✂️ Pop (%s)" % outcome


func debug_layout() -> String:
	"""Return detailed layout debug information for F3 display"""
	var debug_text = ""
	debug_text += "ActionPreviewRow (Q/E/R toolbar):\n"
	debug_text += "  Position: (%.0f, %.0f)\n" % [position.x, position.y]
	debug_text += "  Actual size: %.0f × %.0f\n" % [size.x, size.y]
	debug_text += "  Custom min size: %s\n" % custom_minimum_size
	debug_text += "  Size flags H: %d (3=EXPAND_FILL)\n" % size_flags_horizontal
	debug_text += "  Size flags V: %d\n" % size_flags_vertical
	debug_text += "  Buttons: %d total (HexButton style)\n" % action_buttons.size()

	var button_widths = []
	for action_key in ["Q", "E", "R"]:
		if action_buttons.has(action_key):
			var btn_data = action_buttons[action_key]
			button_widths.append("%.0f" % btn_data.container.size.x)
	debug_text += "  Button widths: [%s] (should be equal for stretch)\n" % ", ".join(button_widths)

	return debug_text


func _create_hex_button(action_key: String) -> Dictionary:
	"""Create a hexagonal button with texture background, icon, and text label.

	Returns a Dictionary with:
	- container: The root Control node
	- texture: The TextureRect for the hex background
	- icon: The TextureRect for the action icon (centered in hex)
	- label: The Label for button text (below icon)
	- disabled: bool tracking disabled state
	"""
	# Container to hold texture, icon, and label
	var container = Control.new()
	container.name = "HexBtn_%s" % action_key
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.size_flags_stretch_ratio = 1.0
	container.custom_minimum_size = Vector2(80 * scale_factor, 65 * scale_factor)
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	# TextureRect for hex button background
	var texture_rect = TextureRect.new()
	texture_rect.name = "HexTexture"
	texture_rect.texture = hex_button_texture
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(texture_rect)

	# TextureRect for action icon (centered in hex, upper portion)
	var icon_rect = TextureRect.new()
	icon_rect.name = "ActionIcon"
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.set_anchors_preset(Control.PRESET_CENTER_TOP)
	icon_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	icon_rect.custom_minimum_size = Vector2(32 * scale_factor, 32 * scale_factor)
	icon_rect.offset_top = 8 * scale_factor
	icon_rect.offset_bottom = 40 * scale_factor
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.visible = false  # Hidden until icon is set
	container.add_child(icon_rect)

	# Label for button text (bottom portion of hex)
	var label = Label.new()
	label.name = "ButtonLabel"
	label.text = "[%s]" % action_key
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_top = 38 * scale_factor  # Below the icon
	label.offset_bottom = -4 * scale_factor
	label.add_theme_font_size_override("font_size", int(11 * scale_factor))
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	container.add_child(label)

	# Connect input events
	container.gui_input.connect(_on_hex_button_input.bind(action_key))
	container.mouse_entered.connect(_on_hex_button_hover.bind(action_key, true))
	container.mouse_exited.connect(_on_hex_button_hover.bind(action_key, false))

	return {
		"container": container,
		"texture": texture_rect,
		"icon": icon_rect,
		"label": label,
		"disabled": false
	}


func _on_hex_button_input(event: InputEvent, action_key: String) -> void:
	"""Handle input on hex button container."""
	var btn_data = action_buttons.get(action_key)
	if not btn_data or btn_data.disabled:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Visual feedback on press
				btn_data.texture.modulate = pressed_color
			else:
				# Restore color and emit action on release
				_update_single_button_color(action_key)
				action_pressed.emit(action_key)

	# Accept the event so it doesn't propagate
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()


func _on_hex_button_hover(action_key: String, is_hovering: bool) -> void:
	"""Handle mouse hover on hex button."""
	var btn_data = action_buttons.get(action_key)
	if not btn_data or btn_data.disabled:
		return

	if is_hovering:
		# Brighten slightly on hover (unless already showing enabled color)
		var current_mod = btn_data.texture.modulate
		if current_mod != enabled_color:
			btn_data.texture.modulate = hover_color
	else:
		# Restore appropriate color
		_update_single_button_color(action_key)


func _update_single_button_color(action_key: String) -> void:
	"""Update a single button's color based on its current state."""
	var btn_data = action_buttons.get(action_key)
	if not btn_data:
		return

	if btn_data.disabled:
		btn_data.texture.modulate = disabled_color
	elif btn_data.get("available", false):
		btn_data.texture.modulate = enabled_color
	else:
		btn_data.texture.modulate = button_color
