class_name EscapeMenu
extends Control

## Escape Menu
## Shows when ESC is pressed, provides restart and quit options

signal restart_pressed()
signal resume_pressed()
signal quit_pressed()
signal save_pressed()
signal load_pressed()
signal reload_last_save_pressed()

var background: ColorRect
var menu_vbox: VBoxContainer

# Keyboard navigation
var menu_buttons: Array[Button] = []
var selected_button_index: int = 0


func _init():
	name = "EscapeMenu"

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

	# Menu box - Fixed size, manually centered using anchors
	var menu_panel = PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(450, 500)
	# Anchor to center point
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_top = 0.5
	menu_panel.anchor_bottom = 0.5
	# Offset by half the size to center (450x500)
	menu_panel.offset_left = -225
	menu_panel.offset_right = 225
	menu_panel.offset_top = -250
	menu_panel.offset_bottom = 250
	menu_panel.layout_mode = 1
	add_child(menu_panel)

	menu_vbox = VBoxContainer.new()
	menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_vbox.add_theme_constant_override("separation", 20)
	menu_panel.add_child(menu_vbox)

	# Title
	var title = Label.new()
	title.text = "⚙️ PAUSED ⚙️"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_vbox.add_child(title)

	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	menu_vbox.add_child(spacer1)

	# Resume button
	var resume_btn = _create_menu_button("Resume [ESC]", Color(0.3, 0.6, 0.3))
	resume_btn.pressed.connect(_on_resume_pressed)
	menu_vbox.add_child(resume_btn)
	menu_buttons.append(resume_btn)

	# Save Game button
	var save_btn = _create_menu_button("Save Game [S]", Color(0.2, 0.5, 0.7))
	save_btn.pressed.connect(_on_save_pressed)
	menu_vbox.add_child(save_btn)
	menu_buttons.append(save_btn)

	# Load Game button
	var load_btn = _create_menu_button("Load Game [L]", Color(0.5, 0.4, 0.7))
	load_btn.pressed.connect(_on_load_pressed)
	menu_vbox.add_child(load_btn)
	menu_buttons.append(load_btn)

	# Reload Last Save button
	var reload_btn = _create_menu_button("Reload Last Save [D]", Color(0.7, 0.4, 0.2))
	reload_btn.pressed.connect(_on_reload_last_save_pressed)
	menu_vbox.add_child(reload_btn)
	menu_buttons.append(reload_btn)

	# Restart button
	var restart_btn = _create_menu_button("Restart [R]", Color(0.6, 0.5, 0.2))
	restart_btn.pressed.connect(_on_restart_pressed)
	menu_vbox.add_child(restart_btn)
	menu_buttons.append(restart_btn)

	# Quit button
	var quit_btn = _create_menu_button("Quit [Q]", Color(0.6, 0.3, 0.3))
	quit_btn.pressed.connect(_on_quit_pressed)
	menu_vbox.add_child(quit_btn)
	menu_buttons.append(quit_btn)

	# Start hidden
	visible = false


func _create_menu_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	# Fixed size for 960×540 base resolution
	btn.custom_minimum_size = Vector2(380, 55)
	btn.add_theme_font_size_override("font_size", 20)

	# FLASH GAME STYLE - Chunky borders matching quest board
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.7, 0.7, 0.7, 0.8)  # Brighter border
	style.border_width_left = 4  # THICKER borders!
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 12  # Rounder corners
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 20  # MORE PADDING!
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", style)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = color.lightened(0.2)
	style_hover.border_color = Color(0.9, 0.9, 0.9, 1.0)  # Even brighter on hover
	style_hover.border_width_left = 4
	style_hover.border_width_right = 4
	style_hover.border_width_top = 4
	style_hover.border_width_bottom = 4
	style_hover.corner_radius_top_left = 12
	style_hover.corner_radius_top_right = 12
	style_hover.corner_radius_bottom_left = 12
	style_hover.corner_radius_bottom_right = 12
	style_hover.content_margin_left = 20
	style_hover.content_margin_right = 20
	style_hover.content_margin_top = 12
	style_hover.content_margin_bottom = 12
	btn.add_theme_stylebox_override("hover", style_hover)

	return btn


func handle_input(event: InputEvent) -> bool:
	"""Modal input handler - called by PlayerShell when on modal stack

	Returns true if input was consumed, false otherwise.
	"""
	if not visible:
		return false

	if not event is InputEventKey or not event.pressed or event.echo:
		return false

	# Only process if SaveLoadMenu is NOT visible
	# (SaveLoadMenu will have already handled input if it's visible)
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child.name == "SaveLoadMenu" and child.visible:
				# SaveLoadMenu is visible and handling input - don't process
				return false

	print("  📋 EscapeMenu.handle_input() KEY: %s" % event.keycode)

	match event.keycode:
		KEY_ESCAPE:
			# ESC closes menu (activates Resume)
			_on_resume_pressed()
			return true
		KEY_UP:
			_navigate_menu(-1)
			return true
		KEY_DOWN:
			_navigate_menu(1)
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_activate_selected_button()
			return true
		KEY_S:
			# S = Save
			_on_save_pressed()
			return true
		KEY_L:
			# L = Load
			_on_load_pressed()
			return true
		KEY_D:
			# D = Reload Last Save (D for "do-over")
			_on_reload_last_save_pressed()
			return true
		KEY_R:
			# R = Restart
			_on_restart_pressed()
			return true
		KEY_Q:
			# Q = Quit
			_on_quit_pressed()
			return true

	return false  # Input not consumed


func _navigate_menu(direction: int):
	"""Navigate menu selection up (-1) or down (1)"""
	if menu_buttons.is_empty():
		return

	selected_button_index = (selected_button_index + direction) % menu_buttons.size()
	if selected_button_index < 0:
		selected_button_index = menu_buttons.size() - 1

	_update_button_highlights()


func _activate_selected_button():
	"""Activate the currently selected button"""
	if selected_button_index >= 0 and selected_button_index < menu_buttons.size():
		menu_buttons[selected_button_index].emit_signal("pressed")


func _update_button_highlights():
	"""Update visual highlight for selected button"""
	for i in range(menu_buttons.size()):
		var btn = menu_buttons[i]
		if i == selected_button_index:
			# Highlight selected button
			btn.modulate = Color(1.3, 1.3, 1.0)  # Brighter/yellow tint
		else:
			# Normal appearance
			btn.modulate = Color(1.0, 1.0, 1.0)


func show_menu():
	visible = true
	selected_button_index = 0  # Reset to first button
	_update_button_highlights()

	if is_inside_tree():
		get_tree().paused = true
		print("📋 Menu opened - Game PAUSED")


func hide_menu():
	visible = false
	if is_inside_tree():
		get_tree().paused = false
		print("📋 Menu closed - Game RESUMED")


func _on_resume_pressed():
	print("▶️ Resume pressed")
	hide_menu()
	resume_pressed.emit()


func _on_restart_pressed():
	print("🔄 Restart pressed")
	restart_pressed.emit()
	hide_menu()


func _on_quit_pressed():
	print("🚪 Quit pressed from menu")
	quit_pressed.emit()
	get_tree().quit()


func _on_save_pressed():
	print("💾 Save pressed")
	save_pressed.emit()


func _on_load_pressed():
	print("📂 Load pressed")
	load_pressed.emit()


func _on_reload_last_save_pressed():
	print("🔄 Reload last save pressed")
	reload_last_save_pressed.emit()
