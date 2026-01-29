class_name SelectionButtonRow
extends HBoxContainer

## SelectionButtonRow - Shared textured button row for tool/biome selectors.
## Subclasses provide button specs and handle selection events.

# Button texture path
const BTN_TEXTURE_PATH = "res://Assets/UI/Chrome/BtnBtmMidl.svg"

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

# Button data array - each element is {container, texture, label, icon, id, disabled}
var buttons: Array[Dictionary] = []
var selected_id: int = -1

signal button_selected(id: int)


func _ready():
	# Load button texture
	btn_texture = load(BTN_TEXTURE_PATH)
	if not btn_texture:
		push_warning("%s: Could not load button texture from %s" % [name, BTN_TEXTURE_PATH])

	# Container setup
	add_theme_constant_override("separation", 8)
	add_theme_constant_override("margin_left", 8)
	add_theme_constant_override("margin_right", 8)
	add_theme_constant_override("margin_top", 4)
	add_theme_constant_override("margin_bottom", 4)

	# Allow keyboard input to pass through, but buttons can still receive clicks
	mouse_filter = MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func build_buttons(button_specs: Array[Dictionary]) -> void:
	"""Rebuild buttons from specs.

	Spec fields:
	- id: int
	- text: String
	- icon_path: String (optional)
	- enabled: bool (optional, default true)
	"""
	_clear_buttons()
	for spec in button_specs:
		var btn_data = _create_button(spec)
		add_child(btn_data.container)
		buttons.append(btn_data)


func _create_button(spec: Dictionary) -> Dictionary:
	"""Create a single button from a spec."""
	var button_id = spec.get("id", -1)
	var label_text = spec.get("text", "")
	var icon_path = spec.get("icon_path", "")
	var enabled = spec.get("enabled", true)

	# Container to hold texture, icon, and label
	var container = Control.new()
	container.name = "SelectBtn_%d" % button_id
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

	# TextureRect for icon glyph (left side)
	var icon_rect = TextureRect.new()
	icon_rect.name = "BtnIcon"
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	icon_rect.offset_left = 8 * scale_factor
	icon_rect.offset_right = 40 * scale_factor
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var has_icon = false
	if icon_path != "":
		var icon_tex = load(icon_path)
		if icon_tex:
			icon_rect.texture = icon_tex
			has_icon = true
		else:
			icon_rect.visible = false
	else:
		icon_rect.visible = false

	container.add_child(icon_rect)

	# Label for button text
	var label = Label.new()
	label.name = "ButtonLabel"
	label.text = label_text
	if has_icon:
		label.offset_left = 40 * scale_factor
	else:
		label.offset_left = 0
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
	container.gui_input.connect(_on_button_input.bind(button_id))
	container.mouse_entered.connect(_on_button_hover.bind(button_id, true))
	container.mouse_exited.connect(_on_button_hover.bind(button_id, false))

	var btn_data = {
		"container": container,
		"texture": texture_rect,
		"icon": icon_rect,
		"label": label,
		"id": button_id,
		"disabled": not enabled
	}

	if not enabled:
		texture_rect.modulate = disabled_color

	return btn_data


func _clear_buttons() -> void:
	for btn_data in buttons:
		if btn_data.container and btn_data.container.get_parent() == self:
			btn_data.container.queue_free()
	buttons.clear()


func _on_button_input(event: InputEvent, button_id: int) -> void:
	var btn_data = _get_button_data(button_id)
	if not btn_data or btn_data.disabled:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				btn_data.texture.modulate = pressed_color
			else:
				set_selected(button_id)
				button_selected.emit(button_id)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var viewport = get_viewport()
		if viewport:
			viewport.set_input_as_handled()


func _on_button_hover(button_id: int, is_hovering: bool) -> void:
	var btn_data = _get_button_data(button_id)
	if not btn_data or btn_data.disabled:
		return

	if button_id == selected_id:
		return

	if is_hovering:
		btn_data.texture.modulate = hover_color
	else:
		btn_data.texture.modulate = normal_color


func _get_button_data(button_id: int) -> Dictionary:
	for btn_data in buttons:
		if btn_data.id == button_id:
			return btn_data
	return {}


func set_selected(button_id: int) -> void:
	selected_id = button_id
	for btn_data in buttons:
		if btn_data.disabled:
			btn_data.texture.modulate = disabled_color
		elif btn_data.id == button_id:
			btn_data.texture.modulate = selected_color
		else:
			btn_data.texture.modulate = normal_color


func set_button_enabled(button_id: int, enabled: bool) -> void:
	var btn_data = _get_button_data(button_id)
	if btn_data.is_empty():
		return
	btn_data.disabled = not enabled
	if not enabled:
		btn_data.texture.modulate = disabled_color
	else:
		if btn_data.id == selected_id:
			btn_data.texture.modulate = selected_color
		else:
			btn_data.texture.modulate = normal_color


func set_layout_manager(mgr) -> void:
	layout_manager = mgr
	if layout_manager:
		scale_factor = layout_manager.scale_factor
