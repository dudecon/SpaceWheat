@tool
extends Control
class_name EmojiDisplay

## EmojiDisplay: Unified emoji/glyph display component
##
## Automatically uses SVG glyph if available via VisualAssetRegistry,
## falls back to emoji text if no glyph exists.
##
## Usage:
##   var display = EmojiDisplay.new()
##   display.emoji = "🌾"
##   display.font_size = 36
##   add_child(display)
##
## The component handles the fallback logic internally:
##   - If VisualAssetRegistry has SVG for "🌾" → shows SVG texture
##   - If no SVG available → shows emoji text "🌾"
##
## This keeps emoji strings as source of truth while enabling
## gradual migration to custom glyphs.

@export var emoji: String = "":
	set(value):
		emoji = value
		_update_display()

@export var font_size: int = 16:
	set(value):
		font_size = value
		_update_display()

@export var modulate_color: Color = Color.WHITE:
	set(value):
		modulate_color = value
		_update_display()

# Child nodes (created in _ready)
var texture_rect: TextureRect
var label: Label

# Track initialization state
var _ready_called: bool = false


func _ready():
	_create_children()
	_ready_called = true
	_update_display()


func _create_children():
	"""Create child nodes for texture and text display."""
	if texture_rect != null:
		return  # Already created

	# TextureRect for SVG glyphs (primary display)
	texture_rect = TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(texture_rect)

	# Label for emoji text fallback (secondary display)
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(label)


func _update_display():
	"""Update display based on current emoji value."""
	if not _ready_called or not is_inside_tree():
		return

	# Safety checks for children
	if not texture_rect or not label:
		return

	if emoji.is_empty():
		# No emoji set - hide everything
		texture_rect.visible = false
		label.visible = false
		return

	# Try to load SVG glyph from registry (safe access to autoload)
	var texture: Texture2D = null
	var registry = get_node_or_null("/root/VisualAssetRegistry")
	if registry and registry.has_method("get_texture"):
		texture = registry.get_texture(emoji)
	elif not registry:
		# Registry not ready yet - defer update until next frame
		if is_inside_tree():
			call_deferred("_update_display")
		return

	if texture:
		# Use SVG glyph (primary path)
		texture_rect.texture = texture
		texture_rect.modulate = modulate_color
		texture_rect.visible = true
		texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

		label.visible = false
	else:
		# Fallback to emoji text (secondary path)
		label.text = emoji
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", modulate_color)
		label.visible = true
		label.set_anchors_preset(Control.PRESET_FULL_RECT)

		texture_rect.visible = false


func set_opacity(opacity: float) -> void:
	"""Set opacity for quantum superposition blending.

	Used by PlotTile for dual-emoji display with weighted opacity.
	"""
	modulate_color = Color(modulate_color.r, modulate_color.g, modulate_color.b, opacity)
	_update_display()
