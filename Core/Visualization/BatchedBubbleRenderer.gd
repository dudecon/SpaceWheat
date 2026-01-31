class_name BatchedBubbleRenderer
extends RefCounted

## Batched Bubble Renderer
##
## High-performance renderer that batches all bubble draw calls into ONE
## GDScript→C++ call per frame, structured like a density matrix.
##
## Data layout per bubble (32 floats = 1 row of the matrix):
## [0-1]   x, y position
## [2]     base_radius
## [3-4]   anim_scale, anim_alpha
## [5]     pulse_phase (0-1)
## [6-7]   is_measured, is_celestial (0 or 1)
## [8]     energy (glow intensity)
## [9-11]  base_color RGB
## [12-14] base_color HSV (for glow calculations)
## [15-16] individual_purity, biome_purity
## [17]    global_prob
## [18-19] p_north, p_south
## [20]    sink_flux
## [21]    time_accumulator
## [22-23] emoji_north_opacity, emoji_south_opacity
## [24-31] reserved

# Native renderer (will be instantiated if available)
var _native_renderer = null
var _use_native: bool = false

# Fallback GDScript renderer
var _fallback_renderer: QuantumBubbleRenderer = null

# Constants matching C++ BubbleParam enum
const STRIDE = 32
const P_X = 0
const P_Y = 1
const P_BASE_RADIUS = 2
const P_ANIM_SCALE = 3
const P_ANIM_ALPHA = 4
const P_PULSE_PHASE = 5
const P_IS_MEASURED = 6
const P_IS_CELESTIAL = 7
const P_ENERGY = 8
const P_COLOR_R = 9
const P_COLOR_G = 10
const P_COLOR_B = 11
const P_COLOR_H = 12
const P_COLOR_S = 13
const P_COLOR_V = 14
const P_INDIVIDUAL_PURITY = 15
const P_BIOME_PURITY = 16
const P_GLOBAL_PROB = 17
const P_P_NORTH = 18
const P_P_SOUTH = 19
const P_SINK_FLUX = 20
const P_TIME = 21
const P_EMOJI_NORTH_OPACITY = 22
const P_EMOJI_SOUTH_OPACITY = 23

# Reusable buffer for bubble data
var _bubble_data: PackedFloat64Array = PackedFloat64Array()
var _num_bubbles: int = 0

# Emoji draw queue (emojis can't be batched - separate pass)
var _emoji_queue: Array = []

# Emoji batcher for reduced draw calls (group by texture)
var _emoji_batcher: EmojiAtlasBatcher = null


func _init():
	# Try to instantiate native renderer (different name to avoid GDScript class_name collision)
	if ClassDB.class_exists("NativeBubbleRenderer"):
		_native_renderer = ClassDB.instantiate("NativeBubbleRenderer")
		_use_native = _native_renderer != null
		if _use_native:
			print("[BatchedBubbleRenderer] Native renderer available - batching enabled")

	if not _use_native:
		print("[BatchedBubbleRenderer] Using GDScript fallback renderer")
		_fallback_renderer = QuantumBubbleRenderer.new()

	# Pre-allocate for 32 bubbles (24 + sun + margin)
	_bubble_data.resize(32 * STRIDE)

	# Initialize emoji batcher for efficient emoji rendering
	_emoji_batcher = EmojiAtlasBatcher.new()


func set_emoji_atlas_batcher(atlas_batcher: EmojiAtlasBatcher) -> void:
	"""Set a pre-built emoji atlas batcher for GPU-accelerated emoji rendering.

	Call this after building the atlas during boot to enable fast batched drawing.
	"""
	if atlas_batcher and atlas_batcher._atlas_built:
		_emoji_batcher = atlas_batcher
		print("[BatchedBubbleRenderer] 🎨 Using pre-built emoji atlas (%d emojis)" % atlas_batcher._emoji_uvs.size())


func draw(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw all quantum bubbles.

	Args:
	    graph: The QuantumForceGraph node (for drawing calls)
	    ctx: Context with {quantum_nodes, biomes, time_accumulator, plot_pool, etc.}
	"""
	if not _use_native:
		# Fallback to original renderer
		_fallback_renderer.draw(graph, ctx)
		return

	# Check for pre-built atlas in context (first-time setup)
	var atlas_batcher = ctx.get("emoji_atlas_batcher")
	if atlas_batcher and atlas_batcher != _emoji_batcher and atlas_batcher._atlas_built:
		set_emoji_atlas_batcher(atlas_batcher)

	var quantum_nodes = ctx.get("quantum_nodes", [])
	var biomes = ctx.get("biomes", {})
	var time_accumulator = ctx.get("time_accumulator", 0.0)
	var plot_pool = ctx.get("plot_pool")
	var batcher = ctx.get("biome_evolution_batcher", null)

	_num_bubbles = 0
	_emoji_queue.clear()

	# Ensure buffer is big enough
	var max_bubbles = quantum_nodes.size() + 1  # +1 for sun
	if _bubble_data.size() < max_bubbles * STRIDE:
		_bubble_data.resize(max_bubbles * STRIDE)

	# Collect all bubble data into matrix
	for node in quantum_nodes:
		if not node.visible:
			continue
		if not node.plot and node.emoji_north.is_empty():
			continue

		# Update terminal bubbles with interpolation for smooth 60fps
		if node.is_terminal_bubble and node.terminal and node.terminal.is_bound:
			node.update_from_quantum_state(batcher)

		_pack_bubble_data(node, biomes, time_accumulator, plot_pool, false)

	# Generate and draw batched geometry
	if _num_bubbles > 0:
		var batches = _native_renderer.generate_draw_batches(_bubble_data, _num_bubbles, STRIDE)
		var points: PackedVector2Array = batches.get("points", PackedVector2Array())
		var colors: PackedColorArray = batches.get("colors", PackedColorArray())
		var indices: PackedInt32Array = batches.get("indices", PackedInt32Array())

		if points.size() > 0 and indices.size() > 0:
			# ONE draw call for all circles and arcs using pre-triangulated geometry!
			# RenderingServer.canvas_item_add_triangle_array() accepts raw triangles
			RenderingServer.canvas_item_add_triangle_array(
				graph.get_canvas_item(),
				indices,
				points,
				colors,
				PackedVector2Array(),  # UVs (empty)
				PackedInt32Array(),    # bones (empty)
				PackedFloat32Array()   # weights (empty)
			)

	# Draw emojis (batched via GPU atlas when available)
	_draw_emoji_pass(graph)


func draw_sun_qubit(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw the sun/moon qubit node with celestial styling."""
	if not _use_native:
		_fallback_renderer.draw_sun_qubit(graph, ctx)
		return

	var sun_qubit_node = ctx.get("sun_qubit_node")
	var biotic_flux_biome = ctx.get("biotic_flux_biome")
	var biomes = ctx.get("biomes", {})
	var time_accumulator = ctx.get("time_accumulator", 0.0)
	var plot_pool = ctx.get("plot_pool")

	if not sun_qubit_node:
		return

	sun_qubit_node.visual_scale = 1.0
	sun_qubit_node.visual_alpha = 1.0

	# Draw pulsing energy aura (special sun effect)
	if biotic_flux_biome:
		var sun_vis = biotic_flux_biome.get_sun_visualization()
		var energy_strength = abs(cos(sun_vis["theta"]))

		var aura_radius = sun_qubit_node.radius * (1.5 + energy_strength * 0.5)
		var aura_color = sun_vis["color"]
		aura_color.a = energy_strength * 0.3
		graph.draw_circle(sun_qubit_node.position, aura_radius, aura_color)

		# Sun rays
		if energy_strength > 0.3:
			for i in range(8):
				var angle = (TAU / 8.0) * i
				var ray_start = sun_qubit_node.position + Vector2(cos(angle), sin(angle)) * sun_qubit_node.radius
				var ray_end = sun_qubit_node.position + Vector2(cos(angle), sin(angle)) * (sun_qubit_node.radius + 15.0 * energy_strength)
				var ray_color = aura_color
				ray_color.a = energy_strength * 0.6
				graph.draw_line(ray_start, ray_end, ray_color, 1.5, true)

	# Pack sun bubble data and render via batch
	_num_bubbles = 0
	_emoji_queue.clear()
	_pack_bubble_data(sun_qubit_node, biomes, time_accumulator, plot_pool, true)

	if _num_bubbles > 0:
		var batches = _native_renderer.generate_draw_batches(_bubble_data, _num_bubbles, STRIDE)
		var points: PackedVector2Array = batches.get("points", PackedVector2Array())
		var colors: PackedColorArray = batches.get("colors", PackedColorArray())
		var indices: PackedInt32Array = batches.get("indices", PackedInt32Array())

		if points.size() > 0 and indices.size() > 0:
			RenderingServer.canvas_item_add_triangle_array(
				graph.get_canvas_item(),
				indices,
				points,
				colors,
				PackedVector2Array(),  # UVs
				PackedInt32Array(),    # bones
				PackedFloat32Array()   # weights
			)

	# Draw sun emoji
	_draw_emoji_pass(graph)

	# Celestial label
	var font = ThemeDB.fallback_font
	var label_color = Color(1.0, 0.85, 0.3, 0.7)
	var label_pos = sun_qubit_node.position + Vector2(0, sun_qubit_node.radius + 25)
	graph.draw_string(font, label_pos, "Celestial", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, label_color)


func _pack_bubble_data(node, biomes: Dictionary, time_accumulator: float, plot_pool, is_celestial: bool) -> void:
	"""Pack a single bubble's data into the matrix."""
	var offset = _num_bubbles * STRIDE

	var anim_scale = node.visual_scale
	var anim_alpha = node.visual_alpha

	if anim_scale <= 0.0:
		return

	# Check if measured
	var is_measured = _is_node_measured(node, plot_pool)

	# Calculate pulse phase (map sin output to 0-1)
	var pulse_rate = node.get_pulse_rate()
	var pulse_phase = sin(time_accumulator * pulse_rate * TAU) * 0.5 + 0.5

	# Get base color
	var base_color: Color
	if is_celestial:
		base_color = Color(1.0, 0.8, 0.2)
	else:
		base_color = node.color

	# Calculate purity and probability data
	var individual_purity = 0.5
	var biome_purity = 0.5
	var global_prob = 0.0
	var p_north = 0.0
	var p_south = 0.0
	var sink_flux = 0.0

	var biome = biomes.get(node.biome_name)
	if biome and biome.viz_cache:
		biome_purity = biome.viz_cache.get_purity()
		if biome_purity < 0.0:
			biome_purity = 0.5

		p_north = node.emoji_north_opacity
		p_south = node.emoji_south_opacity
		global_prob = clampf(p_north + p_south, 0.0, 1.0)

		individual_purity = node.energy if node.energy > 0.0 else 0.5

	# Pack into buffer
	_bubble_data[offset + P_X] = node.position.x
	_bubble_data[offset + P_Y] = node.position.y
	_bubble_data[offset + P_BASE_RADIUS] = node.radius
	_bubble_data[offset + P_ANIM_SCALE] = anim_scale
	_bubble_data[offset + P_ANIM_ALPHA] = anim_alpha
	_bubble_data[offset + P_PULSE_PHASE] = pulse_phase
	_bubble_data[offset + P_IS_MEASURED] = 1.0 if is_measured else 0.0
	_bubble_data[offset + P_IS_CELESTIAL] = 1.0 if is_celestial else 0.0
	_bubble_data[offset + P_ENERGY] = node.energy
	_bubble_data[offset + P_COLOR_R] = base_color.r
	_bubble_data[offset + P_COLOR_G] = base_color.g
	_bubble_data[offset + P_COLOR_B] = base_color.b
	_bubble_data[offset + P_COLOR_H] = base_color.h
	_bubble_data[offset + P_COLOR_S] = base_color.s
	_bubble_data[offset + P_COLOR_V] = base_color.v
	_bubble_data[offset + P_INDIVIDUAL_PURITY] = individual_purity
	_bubble_data[offset + P_BIOME_PURITY] = biome_purity
	_bubble_data[offset + P_GLOBAL_PROB] = global_prob
	_bubble_data[offset + P_P_NORTH] = p_north
	_bubble_data[offset + P_P_SOUTH] = p_south
	_bubble_data[offset + P_SINK_FLUX] = sink_flux
	_bubble_data[offset + P_TIME] = time_accumulator
	_bubble_data[offset + P_EMOJI_NORTH_OPACITY] = node.emoji_north_opacity
	_bubble_data[offset + P_EMOJI_SOUTH_OPACITY] = node.emoji_south_opacity

	# Queue emoji drawing (can't be batched)
	_emoji_queue.append({
		"position": node.position,
		"radius": node.radius,
		"emoji_north": node.emoji_north,
		"emoji_south": node.emoji_south,
		"emoji_north_opacity": node.emoji_north_opacity,
		"emoji_south_opacity": node.emoji_south_opacity,
		"is_celestial": is_celestial
	})

	_num_bubbles += 1


func _draw_emoji_pass(graph: Node2D) -> void:
	"""Draw all emojis using GPU-batched atlas rendering.

	When atlas is built: ONE draw call for all emojis (fast!)
	Fallback: Text rendering for emojis not in atlas (slow but works)
	"""
	if not _emoji_batcher:
		_draw_emoji_pass_legacy(graph)
		return

	_emoji_batcher.begin(graph.get_canvas_item())

	for emoji_data in _emoji_queue:
		var pos = emoji_data["position"]
		var radius = emoji_data["radius"]
		var is_celestial = emoji_data["is_celestial"]
		var font_size = int(radius * (1.1 if is_celestial else 1.0))
		var size = Vector2(font_size, font_size) * 1.2

		# South emoji (behind) - draw first for correct z-order
		var emoji_south = emoji_data["emoji_south"]
		var south_opacity = emoji_data["emoji_south_opacity"]
		if emoji_south != "" and south_opacity > 0.01:
			south_opacity *= (0.9 if is_celestial else 1.0)
			# Use atlas-based rendering (fast path)
			_emoji_batcher.add_emoji_by_name(pos, size, emoji_south, Color(1, 1, 1, south_opacity))

		# North emoji (front)
		var emoji_north = emoji_data["emoji_north"]
		var north_opacity = emoji_data["emoji_north_opacity"]
		if emoji_north != "" and north_opacity > 0.01:
			# Use atlas-based rendering (fast path)
			_emoji_batcher.add_emoji_by_name(pos, size, emoji_north, Color(1, 1, 1, north_opacity))

	# Flush batched atlas emojis (ONE DRAW CALL!)
	_emoji_batcher.flush()

	# Flush any text fallbacks (emojis not in atlas)
	_emoji_batcher.flush_text_fallbacks(graph)


func _draw_emoji_pass_legacy(graph: Node2D) -> void:
	"""Legacy emoji rendering path (no atlas)."""
	var visual_asset_registry = graph.get_node_or_null("/root/VisualAssetRegistry")

	# Legacy path: no batcher (should not happen)
	var font = ThemeDB.fallback_font
	for emoji_data in _emoji_queue:
		var pos = emoji_data["position"]
		var radius = emoji_data["radius"]
		var is_celestial = emoji_data["is_celestial"]
		var font_size = int(radius * (1.1 if is_celestial else 1.0))
		var text_pos = pos - Vector2(font_size * 0.4, -font_size * 0.25)

		# South emoji (behind)
		var emoji_south = emoji_data["emoji_south"]
		var south_opacity = emoji_data["emoji_south_opacity"]
		if emoji_south != "" and south_opacity > 0.01:
			south_opacity *= (0.9 if is_celestial else 1.0)
			_draw_emoji(graph, visual_asset_registry, font, text_pos, emoji_south, font_size, south_opacity)

		# North emoji (front)
		var emoji_north = emoji_data["emoji_north"]
		var north_opacity = emoji_data["emoji_north_opacity"]
		if emoji_north != "" and north_opacity > 0.01:
			_draw_emoji(graph, visual_asset_registry, font, text_pos, emoji_north, font_size, north_opacity)


func _draw_emoji(graph: Node2D, visual_asset_registry, font, text_pos: Vector2, emoji: String, font_size: int, opacity: float) -> void:
	"""Draw a single emoji with shadow."""
	var texture: Texture2D = null
	if visual_asset_registry and visual_asset_registry.has_method("get_texture"):
		texture = visual_asset_registry.get_texture(emoji)

	if texture:
		var glyph_size = Vector2(font_size, font_size) * 1.2
		var glyph_pos = text_pos - glyph_size / 2.0
		var glyph_color = Color(1, 1, 1, opacity)
		var shadow_offset = Vector2(2, 2)
		var shadow_color = Color(0, 0, 0, 0.7 * opacity)
		graph.draw_texture_rect(texture, Rect2(glyph_pos + shadow_offset, glyph_size), false, shadow_color)
		graph.draw_texture_rect(texture, Rect2(glyph_pos, glyph_size), false, glyph_color)
	else:
		var shadow_color = Color(0, 0, 0, 0.7 * opacity)
		graph.draw_string(font, text_pos + Vector2(2, 2), emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow_color)
		var outline_color = Color(0, 0, 0, 0.5 * opacity)
		graph.draw_string(font, text_pos + Vector2(1, 1), emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, outline_color)
		var main_color = Color(1, 1, 1, opacity)
		graph.draw_string(font, text_pos, emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, main_color)


func _is_node_measured(node, plot_pool) -> bool:
	"""Check if node has been measured."""
	if not node:
		return false
	if node.plot != null and node.plot.has_been_measured:
		return true
	if node.terminal and node.terminal.is_measured:
		return true
	if plot_pool and node.grid_position != Vector2i(-1, -1):
		var terminal = plot_pool.get_terminal_at_grid_pos(node.grid_position) if plot_pool.has_method("get_terminal_at_grid_pos") else null
		if terminal and terminal.is_measured:
			return true
	return false


func get_emoji_stats() -> Dictionary:
	"""Get emoji batching statistics for performance monitoring."""
	if _emoji_batcher:
		return _emoji_batcher.get_stats()
	return {"emoji_count": 0, "draw_calls": 0, "unique_textures": 0, "savings": 0}


func is_native_enabled() -> bool:
	"""Check if native bubble renderer is being used."""
	return _use_native
