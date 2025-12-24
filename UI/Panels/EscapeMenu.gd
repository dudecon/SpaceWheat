class_name EscapeMenu
extends PanelContainer

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
	# Full screen overlay - fill entire screen
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP  # Block input to game

	# Process even when game is paused (so menu still works)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Semi-transparent dark background
	background = ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.7)
	background.anchor_left = 0.0
	background.anchor_top = 0.0
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.layout_mode = Control.LAYOUT_MODE_FILL_PARENT
	add_child(background)

	# Center container for menu - child of THIS node for proper centering
	var center = CenterContainer.new()
	center.anchor_left = 0.0
	center.anchor_top = 0.0
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.layout_mode = Control.LAYOUT_MODE_FILL_PARENT
	add_child(center)

	# Menu box
	var menu_panel = PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(400, 600)  # Increased for extra buttons
	center.add_child(menu_panel)

	menu_vbox = VBoxContainer.new()
	menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_vbox.add_theme_constant_override("separation", 20)
	menu_panel.add_child(menu_vbox)

	# Title
	var title = Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 48)
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
	btn.custom_minimum_size = Vector2(300, 60)
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


func _input(event):
	"""Handle keyboard navigation in menu"""
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_ESCAPE:
			# ESC closes menu (activates Resume)
			_on_resume_pressed()
			get_viewport().set_input_as_handled()
		KEY_UP:
			_navigate_menu(-1)
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			_navigate_menu(1)
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			_activate_selected_button()
			get_viewport().set_input_as_handled()
		KEY_S:
			# S = Save
			_on_save_pressed()
			get_viewport().set_input_as_handled()
		KEY_L:
			# L = Load
			_on_load_pressed()
			get_viewport().set_input_as_handled()
		KEY_D:
			# D = Reload Last Save (D for "do-over")
			_on_reload_last_save_pressed()
			get_viewport().set_input_as_handled()
		KEY_R:
			# R = Restart
			_on_restart_pressed()
			get_viewport().set_input_as_handled()
		KEY_Q:
			# Q = Quit
			_on_quit_pressed()
			get_viewport().set_input_as_handled()


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
