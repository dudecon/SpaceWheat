class_name ActionPreviewRow
extends HBoxContainer

## Physical keyboard layout UI - Middle row with QER action preview buttons
## Displays what Q/E/R actions will do based on selected tool
## Buttons use BtnBtmMidl.svg (identical styling to 1234 tool buttons)
## Uses BtnBtmMidl.svg from Assets/UI/Chrome for sci-fi aesthetic

# Tool actions from shared config (single source of truth)
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const LindbladHandler = preload("res://UI/Handlers/LindbladHandler.gd")
const EmojiDisplay = preload("res://UI/Core/EmojiDisplay.gd")
const TOOL_ACTIONS = ToolConfig.TOOL_ACTIONS

# Button texture path (matches ToolSelectionRow)
const BTN_TEXTURE_PATH = "res://Assets/UI/Chrome/BtnBtmMidl.svg"

# Action buttons - now stores container references with .texture and .label children
var action_buttons: Dictionary = {}  # "Q", "E", "R" -> {container, texture, label, disabled}
var current_tool: int = 3  # Default to tool 3 (matches ToolConfig.current_group)
var current_submenu: String = ""  # Active submenu name (empty = show tool actions)
var current_submenu_actions: Dictionary = {}
var active_overlay_node: Control = null  # Current overlay for context-aware QER actions

# References for checking action availability
var plot_grid_display = null  # Injected reference to PlotGridDisplay
var farm = null  # Injected reference to Farm
var input_handler = null  # DEPRECATED: Use quantum_input instead
var quantum_input = null  # Injected reference to QuantumInstrumentInput

# Styling - colors applied via modulate on the TextureRect (matches ToolSelectionRow)
var button_color: Color = Color(1.0, 1.0, 1.0)  # Normal state (texture's natural color)
var hover_color: Color = Color(1.2, 1.2, 1.2)  # Slightly brighter on hover
var disabled_color: Color = Color(0.3, 0.3, 0.3)  # Dark for disabled
var enabled_color: Color = Color(0.5, 1.0, 0.5)  # Green tint for available actions
var pressed_color: Color = Color(0.6, 0.6, 0.6)  # Darker when pressed

# Layout manager for scaling
var layout_manager
var scale_factor: float = 1.0

# Preloaded button texture (matches ToolSelectionRow)
var btn_texture: Texture2D = null

# Signals
signal action_pressed(action_key: String)


func _ready():
	# Z-index: ActionBarLayer(50) + 4 = 54 total (below tool selection at 55)
	z_index = 4

	# Load button texture (matches ToolSelectionRow)
	btn_texture = load(BTN_TEXTURE_PATH)
	if not btn_texture:
		push_warning("ActionPreviewRow: Could not load button texture from %s" % BTN_TEXTURE_PATH)

	# Container setup (matches ToolSelectionRow)
	add_theme_constant_override("separation", 8)
	add_theme_constant_override("margin_left", 8)
	add_theme_constant_override("margin_right", 8)
	add_theme_constant_override("margin_top", 4)
	add_theme_constant_override("margin_bottom", 4)

	# Allow keyboard input to pass through, but buttons can still receive clicks
	mouse_filter = MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Create Q, E, R action buttons (matches 1234 button style)
	for action_key in ["Q", "E", "R"]:
		var btn_data = _create_action_button(action_key)
		add_child(btn_data.container)
		action_buttons[action_key] = btn_data

	# Update display for current tool
	update_for_tool(1)
	print("🛠️  ActionPreviewRow initialized with BtnBtmMidl textures (matches 1234 buttons)")


func update_for_tool(tool_num: int) -> void:
	"""Update action buttons to show actions for the selected tool"""
	if tool_num < 1 or tool_num > 4:  # v2: 4 tools per mode
		return

	current_tool = tool_num
	current_submenu = ""  # Clear submenu when tool changes
	current_submenu_actions = {}

	# Update each action button using ToolConfig API (respects F-cycling)
	for action_key in ["Q", "E", "R"]:
		if not action_buttons.has(action_key):
			continue

		var btn_data = action_buttons[action_key]
		var action_info = ToolConfig.get_action(tool_num, action_key)
		var label_text = ToolConfig.get_action_label(tool_num, action_key)
		var emoji = ToolConfig.get_action_emoji(tool_num, action_key)
		var icon_path = ToolConfig.get_action_icon(tool_num, action_key)
		var shift_hint = ""
		if action_info.has("shift_label"):
			shift_hint = " %s" % action_info.get("shift_label")

		# Try to load icon, fall back to emoji if unavailable
		var has_icon = false
		if icon_path != "" and btn_data.has("icon"):
			var icon_tex = load(icon_path)
			if icon_tex:
				btn_data.icon.texture = icon_tex
				btn_data.icon.visible = true
				has_icon = true
			else:
				btn_data.icon.visible = false
		elif btn_data.has("icon"):
			btn_data.icon.visible = false

		# Update button label text
		# If icon loaded, omit emoji from label; otherwise include it as fallback
		if has_icon:
			btn_data.label.text = "[%s] %s%s" % [action_key, label_text, shift_hint]
			btn_data.label.offset_left = 40 * scale_factor  # Make room for icon
			btn_data.base_label_offset = 40 * scale_factor
		else:
			btn_data.label.text = "[%s] %s %s%s" % [action_key, emoji, label_text, shift_hint]
			btn_data.label.offset_left = 0
			btn_data.base_label_offset = 0

		# Reset disabled state
		btn_data.disabled = false

	# For Tool 1 (Probe), enhance with preview info
	if tool_num == 1:
		_update_probe_preview()

	# Update action availability based on selected plots
	update_action_availability()
	_update_action_costs()


func update_for_submenu(submenu_name: String, submenu_info: Dictionary) -> void:
	"""Update action buttons to show submenu actions

	Called when entering a submenu (e.g., 4-Q opens vocab injection).
	submenu_info contains Q/E/R action definitions.

	Supports _availability dict for per-action availability (e.g., mill power sources).
	When _availability is present, unavailable actions are dimmed using disabled_color.
	"""
	if submenu_name == "":
		# Exiting submenu - restore tool display
		current_submenu = ""
		current_submenu_actions = {}
		update_for_tool(current_tool)
		return

	current_submenu = submenu_name
	current_submenu_actions = submenu_info

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

		# Try to load icon, fall back to emoji if unavailable
		var has_icon = false
		if icon_path != "" and btn_data.has("icon"):
			var icon_tex = load(icon_path)
			if icon_tex:
				btn_data.icon.texture = icon_tex
				btn_data.icon.visible = true
				has_icon = true
			else:
				btn_data.icon.visible = false
		elif btn_data.has("icon"):
			btn_data.icon.visible = false

		# Update button label text
		# If icon loaded, omit emoji from label; otherwise include it as fallback
		if has_icon:
			btn_data.label.text = "[%s] %s" % [action_key, label_text]
			btn_data.label.offset_left = 40 * scale_factor
			btn_data.base_label_offset = 40 * scale_factor
		else:
			btn_data.label.text = "[%s] %s %s" % [action_key, emoji, label_text]
			btn_data.label.offset_left = 0
			btn_data.base_label_offset = 0

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
	_update_action_costs()


func update_for_overlay(overlay: Control) -> void:
	"""Switch to overlay mode: QER actions are projected from overlay state.
	
	Overlay must implement get_action_info(key) -> Dictionary.
	"""
	active_overlay_node = overlay
	current_submenu = "overlay"
	
	# Update button display from overlay action info
	for action_key in ["Q", "E", "R"]:
		if not action_buttons.has(action_key):
			continue
			
		var btn_data = action_buttons[action_key]
		var info = active_overlay_node.get_action_info(action_key)
		
		# Reset display
		btn_data.icon.visible = false
		btn_data.base_label_offset = 0
		btn_data.label.offset_left = 0
		
		var label_text = info.get("label", "-")
		var emoji = info.get("emoji", "")
		var is_disabled = info.get("disabled", false)
		btn_data.label.text = "[%s] %s %s" % [action_key, emoji, label_text]
		btn_data.disabled = is_disabled
		btn_data.texture.modulate = disabled_color if is_disabled else button_color

	_update_action_costs()


func restore_normal_mode() -> void:
	"""Restore normal tool display (called when overlay closes)"""
	active_overlay_node = null
	current_submenu = ""
	update_for_tool(current_tool)


func update_for_quest_board(_slot_state: int, _is_locked: bool = false) -> void:
	"""Legacy: Re-route to update_for_overlay if possible."""
	if active_overlay_node:
		update_for_overlay(active_overlay_node)


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
	"""Check selected plots and highlight available actions.

	Uses QuantumInstrumentInput for current selection state, or falls back
	to naive behavior if no input handler is available.
	"""
	_update_action_costs()

	# Check if we have references
	if not plot_grid_display or not plot_grid_display.has_method("get_selected_plots"):
		update_button_highlights({"Q": false, "E": false, "R": false})
		return

	var selected_plots = plot_grid_display.get_selected_plots()
	if selected_plots.is_empty():
		update_button_highlights({"Q": false, "E": false, "R": false})
		return

	# Check for quantum_input or fall back to input_handler
	var handler = quantum_input if quantum_input else input_handler

	if handler and handler.has_method("can_execute_action"):
		# Use validation API if available
		var availability = {
			"Q": handler.can_execute_action("Q"),
			"E": handler.can_execute_action("E"),
			"R": handler.can_execute_action("R"),
		}
		update_button_highlights(availability)
	elif handler and handler.has_method("get_current_selection"):
		# QuantumInstrumentInput: Check if there's a valid selection
		var selection = handler.get_current_selection()
		var has_selection = selection.get("plot_idx", -1) >= 0
		update_button_highlights({"Q": has_selection, "E": has_selection, "R": has_selection})
	else:
		# Fallback: naive behavior (all enabled if plots selected)
		var has_selection = selected_plots.size() > 0
		update_button_highlights({"Q": has_selection, "E": has_selection, "R": has_selection})

	# Update probe preview for Tool 1 (shows quantum state in button text)
	if current_tool == 1:
		_update_probe_preview()


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
	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else ""
	var active_terminals = []
	for terminal in farm.plot_pool.get_active_terminals():
		if terminal.bound_biome_name == biome_name:
			active_terminals.append(terminal)

	if not active_terminals.is_empty():
		var terminal = active_terminals[0]
		var emoji = terminal.north_emoji if terminal.north_emoji else "?"
		action_buttons["E"].label.text = "[E] 👁️ Measure (%s)" % emoji

	# Get POP preview - find measured terminal
	var measured_terminals = []
	for terminal in farm.plot_pool.get_measured_terminals():
		if terminal.bound_biome_name == biome_name:
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
	debug_text += "  Buttons: %d total (BtnBtmMidl style)\n" % action_buttons.size()

	var button_widths = []
	for action_key in ["Q", "E", "R"]:
		if action_buttons.has(action_key):
			var btn_data = action_buttons[action_key]
			button_widths.append("%.0f" % btn_data.container.size.x)
	debug_text += "  Button widths: [%s] (should be equal for stretch)\n" % ", ".join(button_widths)

	return debug_text


func _create_action_button(action_key: String) -> Dictionary:
	"""Create an action button with texture background, icon glyph, and text label.
	Matches the styling of ToolSelectionRow buttons (BtnBtmMidl.svg).

	Returns a Dictionary with:
	- container: The root Control node
	- texture: The TextureRect for button background
	- icon: The TextureRect for action icon glyph
	- label: The Label for button text
	- disabled: bool tracking disabled state
	"""
	# Container to hold texture, icon, and label
	var container = Control.new()
	container.name = "ActionBtn_%s" % action_key
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

	# TextureRect for action icon glyph (left side)
	var icon_rect = TextureRect.new()
	icon_rect.name = "ActionIcon"
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	icon_rect.offset_left = 8 * scale_factor
	icon_rect.offset_right = 40 * scale_factor
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.visible = false  # Hidden by default, shown when icon is set
	container.add_child(icon_rect)

	# Container for action costs (left side, glyph + amount)
	var cost_container = HBoxContainer.new()
	cost_container.name = "CostContainer"
	cost_container.layout_mode = 1  # Anchors-based positioning
	cost_container.size_flags_horizontal = Control.SIZE_SHRINK_END
	cost_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost_container.custom_minimum_size = Vector2(110 * scale_factor, 24 * scale_factor)
	cost_container.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	cost_container.offset_left = -120 * scale_factor
	cost_container.offset_right = -6 * scale_factor
	cost_container.offset_top = 6 * scale_factor
	cost_container.offset_bottom = -6 * scale_factor
	cost_container.add_theme_constant_override("separation", int(2 * scale_factor))
	cost_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_container.visible = false
	cost_container.z_index = 5
	cost_container.z_as_relative = true
	container.add_child(cost_container)

	# Label for button text (centered over texture)
	var label = Label.new()
	label.name = "ButtonLabel"
	label.text = "[%s]" % action_key
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
	container.gui_input.connect(_on_action_button_input.bind(action_key))
	container.mouse_entered.connect(_on_action_button_hover.bind(action_key, true))
	container.mouse_exited.connect(_on_action_button_hover.bind(action_key, false))

	return {
		"container": container,
		"texture": texture_rect,
		"icon": icon_rect,
		"label": label,
		"cost_container": cost_container,
		"base_label_offset": 0,
		"disabled": false
	}

func _update_action_costs() -> void:
	"""Update cost labels for Q/E/R actions based on selection."""
	for action_key in ["Q", "E", "R"]:
		if not action_buttons.has(action_key):
			continue
		var btn_data = action_buttons[action_key]
		var action_info = _get_action_info(action_key)
		var action_name = action_info.get("action", "")

		# Handle combined reap/harvest_all display
		if action_name == "reap" and action_info.get("shift_action", "") == "harvest_all":
			var normal_cost = EconomyConstants.get_action_cost("reap")
			var shift_cost = EconomyConstants.get_action_cost("harvest_all")
			var has_cost = _set_combined_cost_display(btn_data, normal_cost, shift_cost)
			_adjust_label_for_cost(btn_data, has_cost, 170)
			continue

		var cost = _get_cost_for_action(action_name, action_info)
		var has_cost = _set_cost_display(btn_data, cost)
		_adjust_label_for_cost(btn_data, has_cost)


func _adjust_label_for_cost(btn_data: Dictionary, has_cost: bool, cost_width: int = 130) -> void:
	var base_offset = btn_data.get("base_label_offset", 0)
	if btn_data.has("label"):
		btn_data.label.offset_left = base_offset
		if has_cost:
			btn_data.label.offset_right = -cost_width * scale_factor
		else:
			btn_data.label.offset_right = 0


func _get_action_info(action_key: String) -> Dictionary:
	if active_overlay_node and active_overlay_node.has_method("get_action_info"):
		return active_overlay_node.get_action_info(action_key)
	
	if current_submenu != "" and current_submenu_actions:
		return current_submenu_actions.get(action_key, {})
	return ToolConfig.get_action(current_tool, action_key)


func _get_cost_for_action(action_name: String, action_info: Dictionary = {}) -> Dictionary:
	if action_name == "":
		return {}

	var shift_action = action_info.get("shift_action", "")
	if shift_action != "":
		return _get_cost_for_action_name(shift_action, action_info)

	return _get_cost_for_action_name(action_name, action_info)


func _get_cost_for_action_name(action_name: String, action_info: Dictionary = {}) -> Dictionary:
	# Special cases that need context
	match action_name:
		"inject_vocabulary":
			var pair = action_info.get("vocab_pair", {})
			var context = {"south_emoji": pair.get("south", "")}
			return EconomyConstants.get_action_cost(action_name, context)
		"drain", "pump":
			var emoji = _resolve_selected_north_emoji()
			if emoji == "":
				return {}
			return {
				emoji: LindbladHandler.PLACEMENT_COST_CREDITS,
				LindbladHandler.GEAR_COST_EMOJI: LindbladHandler.GEAR_COST_CREDITS
			}
		_:
			# Use unified cost system for all standard actions
			# (explore, measure, reap, harvest_all, explore_biome, etc.)
			return EconomyConstants.get_action_cost(action_name)


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var parts: Array = []
	var keys = cost.keys()
	keys.sort()
	if keys.has(LindbladHandler.GEAR_COST_EMOJI):
		keys.erase(LindbladHandler.GEAR_COST_EMOJI)
		keys.append(LindbladHandler.GEAR_COST_EMOJI)
	for emoji in keys:
		var amount = cost[emoji]
		if amount == 0:
			continue
		parts.append("%s%d" % [emoji, amount])
	return " ".join(parts)


func _set_cost_display(btn_data: Dictionary, cost: Dictionary) -> bool:
	if not btn_data.has("cost_container"):
		return false

	var container: HBoxContainer = btn_data.cost_container
	for child in container.get_children():
		child.queue_free()

	if cost.is_empty():
		container.visible = false
		return false

	_build_cost_entries(container, cost)
	container.visible = true
	return true


func _set_combined_cost_display(btn_data: Dictionary, normal_cost: Dictionary, shift_cost: Dictionary) -> bool:
	if not btn_data.has("cost_container"):
		return false

	var container: HBoxContainer = btn_data.cost_container
	for child in container.get_children():
		child.queue_free()

	if normal_cost.is_empty() and shift_cost.is_empty():
		container.visible = false
		return false

	# Build normal costs
	_build_cost_entries(container, normal_cost)

	# Slash separator
	var slash = Label.new()
	slash.text = "/"
	slash.add_theme_font_size_override("font_size", int(18 * scale_factor))
	slash.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(slash)

	# Shift indicator (⇧)
	var shift_icon = Label.new()
	shift_icon.text = "⇧"
	shift_icon.add_theme_font_size_override("font_size", int(18 * scale_factor))
	shift_icon.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	shift_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(shift_icon)

	# Build shift costs
	_build_cost_entries(container, shift_cost)

	container.visible = true
	# Increase container size for combined cost
	container.custom_minimum_size.x = 160 * scale_factor
	return true


func _build_cost_entries(container: HBoxContainer, cost: Dictionary) -> void:
	var keys = cost.keys()
	keys.sort()
	if keys.has(LindbladHandler.GEAR_COST_EMOJI):
		keys.erase(LindbladHandler.GEAR_COST_EMOJI)
		keys.append(LindbladHandler.GEAR_COST_EMOJI)

	for emoji in keys:
		var amount = cost[emoji]
		if amount == 0:
			continue
		var entry = HBoxContainer.new()
		entry.add_theme_constant_override("separation", int(2 * scale_factor))
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var amount_label = Label.new()
		amount_label.text = str(amount)
		amount_label.add_theme_font_size_override("font_size", int(18 * scale_factor))
		amount_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
		amount_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		amount_label.add_theme_constant_override("shadow_offset_x", 1)
		amount_label.add_theme_constant_override("shadow_offset_y", 1)
		amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(amount_label)

		var display = EmojiDisplay.new()
		display.emoji = emoji
		display.font_size = int(22 * scale_factor)
		display.custom_minimum_size = Vector2(40 * scale_factor, 40 * scale_factor)
		display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		display.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(display)

		container.add_child(entry)


func _resolve_selected_north_emoji() -> String:
	if not farm:
		return ""
	var selected: Array = []
	if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
		selected = plot_grid_display.get_selected_plots()
	var pos: Vector2i = Vector2i(-1, -1)
	if selected.is_empty():
		# Fallback to QuantumInstrumentInput selection if UI selection isn't set
		var handler = quantum_input if quantum_input else input_handler
		if handler and handler.has_method("get_current_selection") and farm and farm.has_method("get_biome_row"):
			var selection = handler.get_current_selection()
			var plot_idx = selection.get("plot_idx", -1)
			var biome_name = selection.get("biome", "")
			if plot_idx >= 0:
				var biome_row = farm.get_biome_row(biome_name)
				pos = Vector2i(plot_idx, biome_row)
	else:
		pos = selected[0]
	if pos.x < 0:
		return ""

	if farm.plot_pool:
		var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
		if terminal and terminal.is_bound and terminal.has_method("get_emoji_pair"):
			var pair = terminal.get_emoji_pair()
			var north = pair.get("north", "")
			if north != "":
				return north

	var plot = farm.grid.get_plot(pos) if farm and farm.grid else null
	if plot and plot.is_planted:
		return plot.north_emoji if plot.north_emoji else ""
	return ""


func _on_action_button_input(event: InputEvent, action_key: String) -> void:
	"""Handle input on action button container."""
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


func _on_action_button_hover(action_key: String, is_hovering: bool) -> void:
	"""Handle mouse hover on action button."""
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
