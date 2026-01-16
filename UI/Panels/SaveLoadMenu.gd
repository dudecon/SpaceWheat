class_name SaveLoadMenu
extends Control

## Save/Load Menu
## Shows 3 save slots with save information
## Can operate in "save" or "load" mode
##
## OverlayStackManager Integration:
##   System-tier overlay (Z_TIER_SYSTEM = 4000)
##   Implements: handle_input(), activate(), deactivate(), get_overlay_tier()

signal slot_selected(slot: int, mode: String)
signal debug_environment_selected(env_name: String)
signal menu_closed()

enum Mode { SAVE, LOAD }

# Overlay interface
var overlay_name: String = "save_load_menu"
var overlay_tier: int = 4000  # Z_TIER_SYSTEM - highest priority

var current_mode: Mode = Mode.LOAD
var background: ColorRect
var menu_vbox: VBoxContainer
var slot_buttons: Array[Button] = []
var debug_env_buttons: Array[Button] = []
var selected_slot_index: int = 0  # Currently selected slot for keyboard navigation
var selected_is_debug: bool = false  # Track if selected item is a debug environment

# Reference to InputController to disable/enable when menu opens/closes
var input_controller: Node = null

# Debug environments: name -> display name
var debug_environments = {
	"minimal_farm": "🌱 Minimal Farm",
	"wealthy_farm": "💰 Wealthy Farm",
	"fully_planted_farm": "🌾 Fully Planted",
	"fully_measured_farm": "🔬 Fully Measured",
	"fully_entangled_farm": "🔗 Entangled Chain",
	"mixed_quantum_farm": "⚛️ Mixed Quantum",
	"icons_active_farm": "✨ Icons Active",
	"mid_game_farm": "🎮 Mid-Game State"
}


var scroll_container: ScrollContainer
var content_vbox: VBoxContainer

func _init():
	name = "SaveLoadMenu"

	# Fill entire screen - proper Godot 4 anchors-based design
	set_anchors_preset(Control.PRESET_FULL_RECT)
	layout_mode = 1
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Background - fill screen
	background = ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.7)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.layout_mode = 1
	add_child(background)

	# Menu panel - positioned near top with max height
	var menu_panel = PanelContainer.new()
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_top = 0.0
	menu_panel.anchor_bottom = 0.0
	menu_panel.offset_left = -300
	menu_panel.offset_right = 300
	menu_panel.offset_top = 10
	menu_panel.offset_bottom = 530  # 10 + 520 = fits in 540 screen
	menu_panel.layout_mode = 1
	add_child(menu_panel)

	menu_vbox = VBoxContainer.new()
	menu_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	menu_vbox.add_theme_constant_override("separation", 8)
	menu_panel.add_child(menu_vbox)

	# Title (will be updated based on mode)
	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "LOAD GAME"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_vbox.add_child(title)

	# Keyboard hints
	var hints = Label.new()
	hints.text = "↑↓ to select  |  ENTER to confirm  |  ESC to cancel"
	hints.add_theme_font_size_override("font_size", 14)
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	menu_vbox.add_child(hints)

	# Scrollable content area
	scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(580, 380)  # Fixed height for scrolling
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	menu_vbox.add_child(scroll_container)

	content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 8)
	scroll_container.add_child(content_vbox)

	# === SAVE SLOTS SECTION ===
	var saves_label = Label.new()
	saves_label.name = "SavesLabel"
	saves_label.text = "💾 SAVE SLOTS"
	saves_label.add_theme_font_size_override("font_size", 18)
	saves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	saves_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	content_vbox.add_child(saves_label)

	# Create 3 save slot buttons
	for slot in range(3):
		var slot_btn = _create_slot_button(slot)
		slot_buttons.append(slot_btn)
		content_vbox.add_child(slot_btn)

	# === DEBUG SCENARIOS SECTION ===
	var debug_section_label = Label.new()
	debug_section_label.name = "DebugSectionLabel"
	debug_section_label.text = "🧪 DEBUG SCENARIOS"
	debug_section_label.add_theme_font_size_override("font_size", 18)
	debug_section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_section_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	debug_section_label.visible = false  # Hidden in SAVE mode
	content_vbox.add_child(debug_section_label)

	# Create debug environment buttons
	var debug_list = debug_environments.keys()
	for env_name in debug_list:
		var display_name = debug_environments[env_name]
		var env_btn = _create_debug_env_button(env_name, display_name)
		debug_env_buttons.append(env_btn)
		content_vbox.add_child(env_btn)
		env_btn.visible = false  # Hidden in SAVE mode

	# Cancel button (outside scroll area)
	var cancel_btn = _create_menu_button("Cancel (ESC)", Color(0.6, 0.3, 0.3))
	cancel_btn.pressed.connect(_on_cancel_pressed)
	menu_vbox.add_child(cancel_btn)

	# Start hidden
	visible = false
	set_process_input(false)  # Disable input until menu is shown


func handle_input(event: InputEvent) -> bool:
	"""Modal input handler - called by PlayerShell when on modal stack

	Returns true if input was consumed, false otherwise.
	"""
	if not visible:
		return false

	if not event is InputEventKey or not event.pressed or event.echo:
		return false

	# Handle keyboard input
	match event.keycode:
		KEY_ESCAPE:
			_on_cancel_pressed()
			return true  # Consumed!

		KEY_UP:
			_select_previous_slot()
			return true

		KEY_DOWN:
			_select_next_slot()
			return true

		KEY_1:
			_select_slot(0)
			return true

		KEY_2:
			_select_slot(1)
			return true

		KEY_3:
			_select_slot(2)
			return true

		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_confirm_selection()
			return true

	return false  # Not consumed


func _create_slot_button(slot: int) -> Button:
	var btn = Button.new()
	btn.name = "SlotButton" + str(slot)
	# Default sizing (will be adjusted when shown)
	btn.custom_minimum_size = Vector2(550, 80)
	btn.add_theme_font_size_override("font_size", 20)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.4, 0.5)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.4, 0.5, 0.6)
	style_hover.corner_radius_top_left = 8
	style_hover.corner_radius_top_right = 8
	style_hover.corner_radius_bottom_left = 8
	style_hover.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("hover", style_hover)

	btn.pressed.connect(_on_slot_pressed.bind(slot))

	return btn


func _create_debug_env_button(env_name: String, display_name: String) -> Button:
	var btn = Button.new()
	btn.name = "DebugEnvButton_" + env_name
	btn.text = display_name
	btn.custom_minimum_size = Vector2(550, 60)
	btn.add_theme_font_size_override("font_size", 18)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.35, 0.2)  # Golden/brownish tint for debug
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.5, 0.45, 0.3)
	style_hover.corner_radius_top_left = 8
	style_hover.corner_radius_top_right = 8
	style_hover.corner_radius_bottom_left = 8
	style_hover.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("hover", style_hover)

	btn.pressed.connect(_on_debug_env_pressed.bind(env_name))

	return btn


func _create_menu_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 50)
	btn.add_theme_font_size_override("font_size", 24)

	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = color.lightened(0.2)
	style_hover.corner_radius_top_left = 8
	style_hover.corner_radius_top_right = 8
	style_hover.corner_radius_bottom_left = 8
	style_hover.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("hover", style_hover)

	return btn


func _unhandled_key_input(event):
	"""Handle keyboard navigation - ONLY if not already handled by children

	Using _unhandled_key_input() instead of _input() ensures that:
	1. This is called AFTER children have had a chance to handle input
	2. set_process_input(false) on parent actually prevents input
	3. Input can be properly consumed with set_input_as_handled()
	"""
	# If menu is not visible, don't handle input
	if not visible:
		return

	# Only handle key events
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# Handle raw key events
	match event.keycode:
		# Escape: Cancel and return to pause menu (not quit)
		# CRITICAL: Handle ESC first and immediately mark as handled
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()  # Mark handled IMMEDIATELY
			_on_cancel_pressed()
			return

		# Arrow keys: Navigate between slots and debug environments
		KEY_UP:
			_select_previous_slot()
			get_viewport().set_input_as_handled()
			return
		KEY_DOWN:
			_select_next_slot()
			get_viewport().set_input_as_handled()
			return

		# Number keys: Select slot directly
		KEY_1:
			_select_slot(0)
			get_viewport().set_input_as_handled()
			return
		KEY_2:
			_select_slot(1)
			get_viewport().set_input_as_handled()
			return
		KEY_3:
			_select_slot(2)
			get_viewport().set_input_as_handled()
			return

		# Enter or Space: Confirm selection
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_confirm_selection()
			get_viewport().set_input_as_handled()
			return


func _select_slot(slot_index: int):
	"""Select a specific slot"""
	if slot_index < 0 or slot_index >= slot_buttons.size():
		return

	# Don't select disabled slots in load mode
	if current_mode == Mode.LOAD and slot_buttons[slot_index].disabled:
		return

	selected_slot_index = slot_index
	_update_visual_selection()


func _select_next_slot():
	"""Move selection to next available slot or debug environment"""
	# If currently on a debug env, cycle through debug envs
	if selected_is_debug:
		var next_debug_idx = (selected_slot_index + 1) % debug_env_buttons.size()
		selected_slot_index = next_debug_idx
		_update_visual_selection()
		return

	# If on a slot, try to move to the next slot
	var next_slot = (selected_slot_index + 1) % 3

	# Check if we're wrapping around (slot 2 -> slot 0)
	var is_wrapping = next_slot == 0 and selected_slot_index == 2

	if current_mode == Mode.LOAD:
		# If not wrapping and next slot is available, move to it
		if not is_wrapping and not slot_buttons[next_slot].disabled:
			selected_slot_index = next_slot
			selected_is_debug = false
			_update_visual_selection()
			return

		# If wrapping or next slot disabled, move to first debug env
		if debug_env_buttons.size() > 0:
			selected_slot_index = 0
			selected_is_debug = true
			_update_visual_selection()
			return
	else:
		# In save mode, just cycle through slots
		selected_slot_index = next_slot
		_update_visual_selection()
		return


func _select_previous_slot():
	"""Move selection to previous available slot or debug environment"""
	# If currently on a debug env, cycle through debug envs
	if selected_is_debug:
		var prev_debug_idx = (selected_slot_index - 1 + debug_env_buttons.size()) % debug_env_buttons.size()
		selected_slot_index = prev_debug_idx
		_update_visual_selection()
		return

	# If on a slot, try to move to the previous slot
	var prev_slot = (selected_slot_index - 1 + 3) % 3

	# Check if we're wrapping around (slot 0 -> slot 2)
	var is_wrapping = prev_slot == 2 and selected_slot_index == 0

	if current_mode == Mode.LOAD:
		# If not wrapping and previous slot is available, move to it
		if not is_wrapping and not slot_buttons[prev_slot].disabled:
			selected_slot_index = prev_slot
			selected_is_debug = false
			_update_visual_selection()
			return

		# If wrapping or previous slot disabled, move to last debug env
		if debug_env_buttons.size() > 0:
			selected_slot_index = debug_env_buttons.size() - 1
			selected_is_debug = true
			_update_visual_selection()
			return
	else:
		# In save mode, just cycle through slots
		selected_slot_index = prev_slot
		_update_visual_selection()
		return


func _update_visual_selection():
	"""Update visual feedback for keyboard selection"""
	var selected_control: Control = null

	# Update slot buttons
	for i in range(slot_buttons.size()):
		var btn = slot_buttons[i]
		var style = btn.get_theme_stylebox("normal") as StyleBoxFlat

		if i == selected_slot_index and not selected_is_debug and not btn.disabled:
			# Highlight selected slot
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_width_top = 4
			style.border_width_bottom = 4
			style.border_color = Color(1.0, 0.8, 0.0)  # Yellow border
			selected_control = btn
		else:
			# Remove highlight
			style.border_width_left = 0
			style.border_width_right = 0
			style.border_width_top = 0
			style.border_width_bottom = 0

	# Update debug environment buttons
	for i in range(debug_env_buttons.size()):
		var btn = debug_env_buttons[i]
		var style = btn.get_theme_stylebox("normal") as StyleBoxFlat

		if i == selected_slot_index and selected_is_debug:
			# Highlight selected debug env
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_width_top = 4
			style.border_width_bottom = 4
			style.border_color = Color(1.0, 0.8, 0.0)  # Yellow border
			selected_control = btn
		else:
			# Remove highlight
			style.border_width_left = 0
			style.border_width_right = 0
			style.border_width_top = 0
			style.border_width_bottom = 0

	# Scroll to make selected item visible
	if selected_control and scroll_container:
		_scroll_to_control(selected_control)


func _scroll_to_control(ctrl: Control):
	"""Scroll to make the given control visible in the scroll container"""
	if not scroll_container or not ctrl:
		return

	# Get control's position relative to content_vbox
	var ctrl_pos = ctrl.position.y
	var ctrl_height = ctrl.size.y
	var scroll_pos = scroll_container.scroll_vertical
	var view_height = scroll_container.size.y

	# Check if control is above visible area
	if ctrl_pos < scroll_pos:
		scroll_container.scroll_vertical = int(ctrl_pos)
	# Check if control is below visible area
	elif ctrl_pos + ctrl_height > scroll_pos + view_height:
		scroll_container.scroll_vertical = int(ctrl_pos + ctrl_height - view_height)


func _confirm_selection():
	"""Confirm the currently selected slot or debug environment"""
	if selected_is_debug:
		# Confirm debug environment selection
		var env_name = debug_env_buttons[selected_slot_index].name
		# Extract environment name from button name (remove "DebugEnvButton_" prefix)
		env_name = env_name.trim_prefix("DebugEnvButton_")
		_on_debug_env_pressed(env_name)
	else:
		# Confirm slot selection
		if slot_buttons[selected_slot_index].disabled:
			return
		_on_slot_pressed(selected_slot_index)


func inject_input_controller(controller: Node) -> void:
	"""Inject InputController so we can disable it when menu opens"""
	input_controller = controller
	print("💉 InputController injected into SaveLoadMenu")


func show_menu(mode: Mode):
	current_mode = mode

	# CRITICAL: Disable InputController so all input goes to SaveLoadMenu
	if input_controller:
		input_controller.set_process_input(false)
		print("🔒 InputController disabled - SaveLoadMenu now handling all input")

	# Update title
	var title = menu_vbox.get_node("TitleLabel") as Label
	if mode == Mode.SAVE:
		title.text = "SAVE GAME"
	else:
		title.text = "LOAD GAME"

	# Update slot button labels
	_update_slot_info()

	# Show/hide debug environments section
	var debug_label = content_vbox.get_node("DebugSectionLabel") as Label
	if debug_label:
		debug_label.visible = (mode == Mode.LOAD)

	for env_btn in debug_env_buttons:
		env_btn.visible = (mode == Mode.LOAD)

	# Reset selection to first available slot
	selected_slot_index = 0
	selected_is_debug = false

	# Find first non-disabled slot in load mode
	if mode == Mode.LOAD:
		for i in range(3):
			if not slot_buttons[i].disabled:
				selected_slot_index = i
				break

	_update_visual_selection()

	visible = true
	set_process_input(true)  # Enable keyboard input when menu is shown

	# Disable EscapeMenu's input while SaveLoadMenu is open
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child.name == "EscapeMenu":
				child.set_process_input(false)
				break

	print("📋 Save/Load menu opened - Mode: " + ("SAVE" if mode == Mode.SAVE else "LOAD"))


func hide_menu():
	visible = false
	set_process_input(false)  # Disable keyboard input when menu is hidden

	# Re-enable EscapeMenu's input when SaveLoadMenu closes
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child.name == "EscapeMenu":
				child.set_process_input(true)
				break

	# CRITICAL: Re-enable InputController when menu closes
	if input_controller:
		input_controller.set_process_input(true)
		print("🔓 InputController re-enabled")

	print("📋 Save/Load menu closed")


func _update_slot_info():
	"""Update slot buttons with save information from GameStateManager"""
	# Check if GameStateManager is available (it's an autoload)
	if not is_node_ready():
		return  # Can't access GameStateManager yet

	for slot in range(3):
		var btn = slot_buttons[slot]
		var save_info = GameStateManager.get_save_info(slot)

		if save_info["exists"]:
			# Save exists - show info
			var info_text = "Slot %d\n%s\n💰%d credits | Goal %d" % [
				slot + 1,
				save_info["display_name"],
				save_info["credits"],
				save_info["goal_index"] + 1
			]
			btn.text = info_text

			# Make button more vibrant if save exists
			var style = btn.get_theme_stylebox("normal") as StyleBoxFlat
			style.bg_color = Color(0.2, 0.5, 0.7)  # Blue tint for existing saves
		else:
			# Empty slot
			if current_mode == Mode.SAVE:
				btn.text = "Slot %d\n[Empty - Click to Save]" % [slot + 1]
			else:
				btn.text = "Slot %d\n[Empty]" % [slot + 1]

			# Gray out empty slots in load mode
			var style = btn.get_theme_stylebox("normal") as StyleBoxFlat
			if current_mode == Mode.LOAD:
				style.bg_color = Color(0.2, 0.2, 0.2)  # Dark gray
				btn.disabled = true
			else:
				style.bg_color = Color(0.3, 0.4, 0.5)  # Normal color for save mode
				btn.disabled = false


func _on_slot_pressed(slot: int):
	print("🎮 Slot " + str(slot + 1) + " selected - Mode: " + ("SAVE" if current_mode == Mode.SAVE else "LOAD"))
	slot_selected.emit(slot, "save" if current_mode == Mode.SAVE else "load")
	hide_menu()


func _on_debug_env_pressed(env_name: String):
	print("🧪 Debug environment selected: " + env_name)
	debug_environment_selected.emit(env_name)
	hide_menu()


func _on_cancel_pressed():
	print("❌ Save/Load cancelled")
	menu_closed.emit()
	hide_menu()


# ============================================================================
# OVERLAY STACK INTERFACE
# ============================================================================

func get_overlay_tier() -> int:
	"""Get z-index tier for OverlayStackManager."""
	return overlay_tier


func activate() -> void:
	"""Overlay lifecycle: Called when pushed onto stack.

	Note: SaveLoadMenu requires mode to be set before showing.
	Use show_menu(mode) directly, or set current_mode first.
	"""
	show_menu(current_mode)


func deactivate() -> void:
	"""Overlay lifecycle: Called when popped from stack."""
	hide_menu()
