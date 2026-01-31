class_name EmojiAtlasBatcher
extends RefCounted

## Emoji Atlas Batcher - GPU-Accelerated Emoji Rendering
##
## PRE-RENDERS all emojis to a texture atlas at startup, then batches
## all emoji draw calls into ONE RenderingServer call per frame.
##
## Performance impact:
##   Before: 48+ draw_string() calls @ ~2ms
##   After:  1 triangle_array call @ ~0.1ms
##
## Usage:
##   var batcher = EmojiAtlasBatcher.new()
##   batcher.build_atlas(["🌾", "👥", "🔥", ...])  # Call once at startup
##
##   # Each frame:
##   batcher.begin(canvas_item)
##   batcher.add_emoji(pos, size, "🌾", color)
##   batcher.flush()

# Atlas configuration
const ATLAS_CELL_SIZE: int = 64  # Size of each emoji cell in atlas
const ATLAS_PADDING: int = 2      # Padding between cells
const MAX_ATLAS_SIZE: int = 2048  # Maximum atlas dimension

# Atlas texture (generated at startup)
var _atlas_texture: ImageTexture = null
var _atlas_image: Image = null

# Emoji → UV mapping (emoji string → Rect2 in UV coordinates 0-1)
var _emoji_uvs: Dictionary = {}

# Emoji → cell index mapping
var _emoji_cells: Dictionary = {}

# Atlas dimensions
var _atlas_width: int = 0
var _atlas_height: int = 0
var _cells_per_row: int = 0

# Current canvas item we're drawing to
var _canvas_item: RID = RID()

# Batch data (single texture = single batch!)
var _points: PackedVector2Array = PackedVector2Array()
var _uvs: PackedVector2Array = PackedVector2Array()
var _colors: PackedColorArray = PackedColorArray()

# Empty arrays for reuse
var _empty_bones := PackedInt32Array()
var _empty_weights := PackedFloat32Array()

# Stats
var _emoji_count: int = 0
var _draw_calls: int = 0
var _atlas_built: bool = false

# Fallback for visual asset registry textures
var _visual_asset_registry = null


func _init():
	# Try to get visual asset registry for SVG fallback
	var tree = Engine.get_main_loop()
	if tree and tree is SceneTree:
		_visual_asset_registry = tree.root.get_node_or_null("/root/VisualAssetRegistry")


func build_atlas(emoji_list: Array, font_size: int = 48) -> bool:
	"""Pre-render all emojis to a GPU texture atlas.

	Call this ONCE at startup with all emojis you'll use.

	Args:
	    emoji_list: Array of emoji strings to include
	    font_size: Font size for rendering (default 48 for crisp scaling)

	Returns:
	    true if atlas was built successfully
	"""
	if emoji_list.is_empty():
		push_warning("[EmojiAtlasBatcher] No emojis provided for atlas")
		return false

	var start_time = Time.get_ticks_msec()

	# Calculate atlas dimensions
	var num_emojis = emoji_list.size()
	var cell_total = ATLAS_CELL_SIZE + ATLAS_PADDING

	# Find optimal square-ish atlas size
	_cells_per_row = ceili(sqrt(float(num_emojis)))
	_atlas_width = mini(_cells_per_row * cell_total, MAX_ATLAS_SIZE)
	_cells_per_row = _atlas_width / cell_total

	var rows_needed = ceili(float(num_emojis) / float(_cells_per_row))
	_atlas_height = mini(rows_needed * cell_total, MAX_ATLAS_SIZE)

	# Create atlas image (RGBA8 for transparency)
	_atlas_image = Image.create(_atlas_width, _atlas_height, false, Image.FORMAT_RGBA8)
	_atlas_image.fill(Color(0, 0, 0, 0))  # Transparent background

	# Get font for rendering
	var font = ThemeDB.fallback_font
	if not font:
		push_error("[EmojiAtlasBatcher] No font available for atlas rendering")
		return false

	# Render each emoji to its cell
	var cell_index = 0
	for emoji in emoji_list:
		if cell_index >= _cells_per_row * (MAX_ATLAS_SIZE / cell_total):
			push_warning("[EmojiAtlasBatcher] Atlas full, skipping remaining emojis")
			break

		var row = cell_index / _cells_per_row
		var col = cell_index % _cells_per_row

		var cell_x = col * cell_total + ATLAS_PADDING / 2
		var cell_y = row * cell_total + ATLAS_PADDING / 2

		# Render emoji to a temporary image using SubViewport
		var emoji_image = _render_emoji_to_image(emoji, font, font_size)
		if emoji_image:
			# Blit emoji image to atlas
			var dest_rect = Rect2i(cell_x, cell_y, ATLAS_CELL_SIZE, ATLAS_CELL_SIZE)
			var src_rect = Rect2i(0, 0, mini(emoji_image.get_width(), ATLAS_CELL_SIZE),
								   mini(emoji_image.get_height(), ATLAS_CELL_SIZE))
			_atlas_image.blit_rect(emoji_image, src_rect, Vector2i(cell_x, cell_y))

		# Calculate UV coordinates (0-1 range)
		var uv_x = float(cell_x) / float(_atlas_width)
		var uv_y = float(cell_y) / float(_atlas_height)
		var uv_w = float(ATLAS_CELL_SIZE) / float(_atlas_width)
		var uv_h = float(ATLAS_CELL_SIZE) / float(_atlas_height)

		_emoji_uvs[emoji] = Rect2(uv_x, uv_y, uv_w, uv_h)
		_emoji_cells[emoji] = cell_index

		cell_index += 1

	# Create GPU texture from atlas image
	_atlas_texture = ImageTexture.create_from_image(_atlas_image)
	_atlas_built = true

	var elapsed = Time.get_ticks_msec() - start_time
	print("[EmojiAtlasBatcher] Atlas built: %dx%d (%d emojis) in %dms" % [
		_atlas_width, _atlas_height, _emoji_uvs.size(), elapsed
	])

	return true


func _render_emoji_to_image(emoji: String, font: Font, font_size: int) -> Image:
	"""Render a single emoji to an Image using SubViewport.

	Creates a temporary viewport, renders the emoji text, captures the result.
	This is called at startup time, not per-frame.
	"""
	# Check if we already have an SVG texture for this emoji
	if _visual_asset_registry and _visual_asset_registry.has_texture(emoji):
		var tex = _visual_asset_registry.get_texture(emoji)
		if tex:
			return tex.get_image()

	# Create SubViewport for rendering
	var viewport = SubViewport.new()
	viewport.size = Vector2i(ATLAS_CELL_SIZE, ATLAS_CELL_SIZE)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# Create Label to render the emoji
	var label = Label.new()
	label.text = emoji
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(ATLAS_CELL_SIZE, ATLAS_CELL_SIZE)
	label.position = Vector2.ZERO

	viewport.add_child(label)

	# Add viewport to scene tree temporarily
	var tree = Engine.get_main_loop()
	if not tree or not tree is SceneTree:
		viewport.queue_free()
		return null

	tree.root.add_child(viewport)

	# Force render
	RenderingServer.force_draw()

	# Capture the image
	var img = viewport.get_texture().get_image()

	# Cleanup
	viewport.queue_free()

	return img


func build_atlas_async(emoji_list: Array, parent_node: Node, font_size: int = 48) -> void:
	"""Build atlas asynchronously using SubViewport rendering.

	Must be called from scene tree context (e.g., during _ready).
	Uses coroutines to avoid blocking.
	"""
	if emoji_list.is_empty():
		push_warning("[EmojiAtlasBatcher] No emojis provided for atlas")
		return

	var start_time = Time.get_ticks_msec()

	# Calculate atlas dimensions
	var num_emojis = emoji_list.size()
	var cell_total = ATLAS_CELL_SIZE + ATLAS_PADDING

	_cells_per_row = ceili(sqrt(float(num_emojis)))
	_atlas_width = mini(_cells_per_row * cell_total, MAX_ATLAS_SIZE)
	_cells_per_row = _atlas_width / cell_total

	var rows_needed = ceili(float(num_emojis) / float(_cells_per_row))
	_atlas_height = mini(rows_needed * cell_total, MAX_ATLAS_SIZE)

	# Create atlas image
	_atlas_image = Image.create(_atlas_width, _atlas_height, false, Image.FORMAT_RGBA8)
	_atlas_image.fill(Color(0, 0, 0, 0))

	# Create single SubViewport for all emoji rendering
	var viewport = SubViewport.new()
	viewport.size = Vector2i(ATLAS_CELL_SIZE, ATLAS_CELL_SIZE)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.name = "EmojiAtlasViewport"

	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(ATLAS_CELL_SIZE, ATLAS_CELL_SIZE)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	viewport.add_child(label)

	parent_node.add_child(viewport)

	# Render each emoji
	var cell_index = 0
	var successful_count = 0
	var svg_count = 0
	var viewport_count = 0
	var failed_count = 0
	for emoji in emoji_list:
		if cell_index >= _cells_per_row * (MAX_ATLAS_SIZE / cell_total):
			break

		var row = cell_index / _cells_per_row
		var col = cell_index % _cells_per_row
		var cell_x = col * cell_total + ATLAS_PADDING / 2
		var cell_y = row * cell_total + ATLAS_PADDING / 2

		# Check for SVG texture first
		var emoji_image: Image = null
		if _visual_asset_registry and _visual_asset_registry.has_texture(emoji):
			var tex = _visual_asset_registry.get_texture(emoji)
			if tex:
				emoji_image = tex.get_image()
				if emoji_image:
					emoji_image = emoji_image.duplicate()
					emoji_image.resize(ATLAS_CELL_SIZE, ATLAS_CELL_SIZE)
					svg_count += 1

		# Fall back to viewport text rendering
		if not emoji_image:
			label.text = emoji
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await parent_node.get_tree().process_frame
			await parent_node.get_tree().process_frame  # Need 2 frames for viewport
			RenderingServer.force_draw()  # Force render
			# Check for null texture (happens in headless mode)
			var vp_texture = viewport.get_texture()
			if vp_texture:
				emoji_image = vp_texture.get_image()
				if emoji_image:
					viewport_count += 1
			# In headless mode, texture is null - that's expected, atlas won't work
			if not emoji_image:
				failed_count += 1

		# Only add to atlas if emoji was successfully rendered
		if emoji_image:
			var src_rect = Rect2i(0, 0, mini(emoji_image.get_width(), ATLAS_CELL_SIZE),
								   mini(emoji_image.get_height(), ATLAS_CELL_SIZE))
			_atlas_image.blit_rect(emoji_image, src_rect, Vector2i(cell_x, cell_y))

			# Store UV coordinates ONLY for successfully rendered emojis
			var uv_x = float(cell_x) / float(_atlas_width)
			var uv_y = float(cell_y) / float(_atlas_height)
			var uv_w = float(ATLAS_CELL_SIZE) / float(_atlas_width)
			var uv_h = float(ATLAS_CELL_SIZE) / float(_atlas_height)
			_emoji_uvs[emoji] = Rect2(uv_x, uv_y, uv_w, uv_h)
			_emoji_cells[emoji] = cell_index
			successful_count += 1
		else:
			print("[EmojiAtlasBatcher] DEBUG: emoji_image is null for '%s' (svg=%s, vp=%s, failed=%s)" % [emoji, svg_count, viewport_count, failed_count])

		cell_index += 1

	# Log rendering breakdown and stored emojis
	print("[EmojiAtlasBatcher] Rendering breakdown: SVG=%d, Viewport=%d, Failed=%d, Total=%d" % [svg_count, viewport_count, failed_count, emoji_list.size()])
	print("[EmojiAtlasBatcher] Stored %d emojis in UV map:" % _emoji_uvs.size())
	for e in _emoji_uvs.keys():
		print("  - '%s'" % e)

	# Cleanup viewport
	viewport.queue_free()

	# Create GPU texture
	_atlas_texture = ImageTexture.create_from_image(_atlas_image)
	_atlas_built = true

	var elapsed = Time.get_ticks_msec() - start_time
	print("[EmojiAtlasBatcher] 🎨 Atlas built: %dx%d (%d emojis) in %dms" % [
		_atlas_width, _atlas_height, _emoji_uvs.size(), elapsed
	])


func begin(canvas_item: RID) -> void:
	"""Begin a new batch frame.

	Args:
	    canvas_item: The canvas item RID to draw to (from get_canvas_item())
	"""
	_canvas_item = canvas_item
	_points.clear()
	_uvs.clear()
	_colors.clear()
	_emoji_count = 0
	_draw_calls = 0
	_fallback_count = 0
	_atlas_hit_count = 0


func add_emoji(position: Vector2, size: Vector2, texture: Texture2D, color: Color, shadow_offset: Vector2 = Vector2(2, 2)) -> void:
	"""Add an emoji to the batch using provided texture.

	This is the SVG texture path - uses individual textures.
	For best performance, use add_emoji_by_name() with the atlas.
	"""
	if not texture:
		return

	# For individual textures, we need separate batches
	# Fall back to direct drawing
	_draw_textured_quad_immediate(texture, position, size, color, shadow_offset)


func add_emoji_by_name(position: Vector2, size: Vector2, emoji: String, color: Color, shadow_offset: Vector2 = Vector2(2, 2)) -> void:
	"""Add an emoji to the batch by name (uses pre-built atlas).

	This is the FAST path - all emojis batch into one draw call!
	"""
	if not _atlas_built or not _emoji_uvs.has(emoji):
		_fallback_count += 1
		if not _missing_emojis.has(emoji):
			_missing_emojis[emoji] = true
			# Only warn once per emoji to avoid spam
			push_warning("[EmojiAtlasBatcher] Missing emoji: '%s' (UV map has %d emojis)" % [emoji, _emoji_uvs.size()])
		# Fallback: try SVG texture
		if _visual_asset_registry:
			var tex = _visual_asset_registry.get_texture(emoji)
			if tex:
				_draw_textured_quad_immediate(tex, position, size, color, shadow_offset)
				return
		# Ultimate fallback: queue for text rendering
		_text_fallback_queue.append({
			"pos": position,
			"size": size,
			"emoji": emoji,
			"color": color
		})
		return

	_atlas_hit_count += 1
	var uv_rect = _emoji_uvs[emoji]
	_add_quad_to_batch(position, size, uv_rect, color, shadow_offset)
	_emoji_count += 1


# Queue for text fallback (emojis not in atlas)
var _text_fallback_queue: Array = []

# Track fallback usage for debugging
var _fallback_count: int = 0
var _atlas_hit_count: int = 0
var _missing_emojis: Dictionary = {}  # Track which emojis are missing


func _add_quad_to_batch(position: Vector2, size: Vector2, uv_rect: Rect2, color: Color, shadow_offset: Vector2) -> void:
	"""Add a textured quad to the batch arrays."""
	var half_size = size * 0.5
	var tl = position - half_size
	var tr = position + Vector2(half_size.x, -half_size.y)
	var bl = position + Vector2(-half_size.x, half_size.y)
	var br = position + half_size

	# UV coordinates from atlas rect
	var uv_tl = Vector2(uv_rect.position.x, uv_rect.position.y)
	var uv_tr = Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y)
	var uv_bl = Vector2(uv_rect.position.x, uv_rect.position.y + uv_rect.size.y)
	var uv_br = Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y + uv_rect.size.y)

	# Add shadow quad first (behind main)
	if shadow_offset != Vector2.ZERO:
		var shadow_color = Color(0, 0, 0, 0.7 * color.a)
		var s_tl = tl + shadow_offset
		var s_tr = tr + shadow_offset
		var s_bl = bl + shadow_offset
		var s_br = br + shadow_offset

		# Shadow triangle 1
		_points.append(s_tl); _uvs.append(uv_tl); _colors.append(shadow_color)
		_points.append(s_tr); _uvs.append(uv_tr); _colors.append(shadow_color)
		_points.append(s_br); _uvs.append(uv_br); _colors.append(shadow_color)
		# Shadow triangle 2
		_points.append(s_tl); _uvs.append(uv_tl); _colors.append(shadow_color)
		_points.append(s_br); _uvs.append(uv_br); _colors.append(shadow_color)
		_points.append(s_bl); _uvs.append(uv_bl); _colors.append(shadow_color)

	# Main emoji quad - triangle 1 (tl, tr, br)
	_points.append(tl); _uvs.append(uv_tl); _colors.append(color)
	_points.append(tr); _uvs.append(uv_tr); _colors.append(color)
	_points.append(br); _uvs.append(uv_br); _colors.append(color)

	# Main emoji quad - triangle 2 (tl, br, bl)
	_points.append(tl); _uvs.append(uv_tl); _colors.append(color)
	_points.append(br); _uvs.append(uv_br); _colors.append(color)
	_points.append(bl); _uvs.append(uv_bl); _colors.append(color)


func _draw_textured_quad_immediate(texture: Texture2D, position: Vector2, size: Vector2, color: Color, shadow_offset: Vector2) -> void:
	"""Draw a single textured quad immediately (for non-atlas textures)."""
	if not _canvas_item.is_valid() or not texture:
		return

	var half_size = size * 0.5
	var rect = Rect2(position - half_size, size)

	# Shadow
	if shadow_offset != Vector2.ZERO:
		var shadow_rect = Rect2(rect.position + shadow_offset, rect.size)
		RenderingServer.canvas_item_add_texture_rect(
			_canvas_item, shadow_rect, texture.get_rid(), false, Color(0, 0, 0, 0.7 * color.a)
		)
		_draw_calls += 1

	# Main
	RenderingServer.canvas_item_add_texture_rect(
		_canvas_item, rect, texture.get_rid(), false, color
	)
	_draw_calls += 1
	_emoji_count += 1


func add_emoji_text_fallback(graph: Node2D, position: Vector2, emoji: String, font_size: int, color: Color) -> void:
	"""Fallback for emojis without textures - uses immediate draw_string.

	This breaks batching but ensures emojis still render.
	Should be called AFTER flush() to maintain z-order.
	"""
	var font = ThemeDB.fallback_font
	var text_pos = position - Vector2(font_size * 0.4, -font_size * 0.25)

	# Shadow
	var shadow_color = Color(0, 0, 0, 0.7 * color.a)
	graph.draw_string(font, text_pos + Vector2(2, 2), emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow_color)

	# Main
	graph.draw_string(font, text_pos, emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


func flush() -> void:
	"""Submit all batched emoji draws to RenderingServer.

	ONE draw call for all atlas-batched emojis!
	"""
	if not _canvas_item.is_valid():
		return

	# Draw atlas-batched emojis (ONE DRAW CALL!)
	if _points.size() > 0 and _atlas_texture:
		var indices = PackedInt32Array()
		indices.resize(_points.size())
		for i in range(_points.size()):
			indices[i] = i

		RenderingServer.canvas_item_add_triangle_array(
			_canvas_item,
			indices,
			_points,
			_colors,
			_uvs,
			_empty_bones,
			_empty_weights,
			_atlas_texture.get_rid()
		)
		_draw_calls += 1


func flush_text_fallbacks(graph: Node2D) -> void:
	"""Flush any queued text fallback emojis."""
	var font = ThemeDB.fallback_font
	var font_size = 24  # Default size

	for fb in _text_fallback_queue:
		var text_pos = fb["pos"] - Vector2(font_size * 0.4, -font_size * 0.25)
		var color = fb["color"]
		var emoji = fb["emoji"]

		# Shadow
		var shadow_color = Color(0, 0, 0, 0.7 * color.a)
		graph.draw_string(font, text_pos + Vector2(2, 2), emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow_color)

		# Main
		graph.draw_string(font, text_pos, emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

	_text_fallback_queue.clear()


func has_emoji(emoji: String) -> bool:
	"""Check if emoji is in the atlas."""
	return _emoji_uvs.has(emoji)


func _count_non_empty_cells() -> int:
	"""Count atlas cells that have non-transparent content."""
	if not _atlas_image:
		return 0

	var non_empty = 0
	var cell_total = ATLAS_CELL_SIZE + ATLAS_PADDING

	for emoji in _emoji_cells.keys():
		var cell_idx = _emoji_cells[emoji]
		var row = cell_idx / _cells_per_row
		var col = cell_idx % _cells_per_row
		var cell_x = col * cell_total + ATLAS_PADDING / 2
		var cell_y = row * cell_total + ATLAS_PADDING / 2

		# Sample center of cell
		var sample_x = cell_x + ATLAS_CELL_SIZE / 2
		var sample_y = cell_y + ATLAS_CELL_SIZE / 2
		if sample_x < _atlas_image.get_width() and sample_y < _atlas_image.get_height():
			var pixel = _atlas_image.get_pixel(sample_x, sample_y)
			if pixel.a > 0.01:
				non_empty += 1

	return non_empty


func get_atlas_texture() -> ImageTexture:
	"""Get the atlas texture (for debugging/visualization)."""
	return _atlas_texture


func get_stats() -> Dictionary:
	"""Get batching statistics for performance monitoring."""
	return {
		"emoji_count": _emoji_count,
		"draw_calls": _draw_calls,
		"atlas_emojis": _emoji_uvs.size(),
		"atlas_size": Vector2i(_atlas_width, _atlas_height),
		"savings": max(0, _emoji_count * 2 - _draw_calls),  # Each emoji would be 2 calls (shadow + main)
		"atlas_hits": _atlas_hit_count,
		"fallbacks": _fallback_count,
		"hit_rate": _atlas_hit_count / max(1.0, float(_atlas_hit_count + _fallback_count)) * 100.0
	}
