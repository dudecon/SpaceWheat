class_name PanelTouchButton
extends Control

## Touch-Friendly Panel Toggle Button
## Large button for opening panels on touch devices
## Uses BtnBtmMidl.svg texture to match ToolSelectionRow style

signal button_activated

const BTN_TEXTURE_PATH = "res://Assets/UI/Chrome/BtnBtmMidl.svg"

@export var button_emoji: String = ""
@export var button_label: String = ""
@export var keyboard_hint: String = ""

var layout_manager: Node = null
var btn_texture: Texture2D = null
var texture_rect: TextureRect = null
var label: Label = null

# Styling colors (matching ToolSelectionRow)
var normal_color: Color = Color(1.0, 1.0, 1.0)
var hover_color: Color = Color(1.2, 1.2, 1.2)
var pressed_color: Color = Color(0.6, 0.6, 0.6)


func set_layout_manager(manager: Node) -> void:
	"""Set layout manager for scaling"""
	layout_manager = manager


func _ready() -> void:
	"""Initialize button appearance and behavior"""
	var scale = layout_manager.scale_factor if layout_manager else 1.0
	var font_size = layout_manager.get_scaled_font_size(18) if layout_manager else 18

	# Load button texture
	btn_texture = load(BTN_TEXTURE_PATH)

	# Large size for touch accessibility
	custom_minimum_size = Vector2(70 * scale, 50 * scale)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# TextureRect for button background
	texture_rect = TextureRect.new()
	texture_rect.name = "BtnTexture"
	texture_rect.texture = btn_texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(texture_rect)

	# Label for emoji + keyboard hint (centered)
	label = Label.new()
	label.name = "ButtonLabel"
	label.text = button_emoji
	if keyboard_hint:
		label.text += "\n" + keyboard_hint
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	# Connect input events
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_gui_input(event: InputEvent) -> void:
	"""Handle input on button."""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				texture_rect.modulate = pressed_color
			else:
				texture_rect.modulate = hover_color
				button_activated.emit()
			get_viewport().set_input_as_handled()


func _on_mouse_entered() -> void:
	"""Handle mouse hover."""
	texture_rect.modulate = hover_color


func _on_mouse_exited() -> void:
	"""Handle mouse exit."""
	texture_rect.modulate = normal_color
