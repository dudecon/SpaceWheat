class_name BubbleAtlasBatcher
extends RefCounted

## Bubble Atlas Batcher - GPU-Accelerated Bubble Rendering
##
## PRE-RENDERS grayscale geometric templates (circles, rings) to a texture atlas
## at startup, then batches all bubble draw calls into ONE RenderingServer call
## per frame using per-vertex color modulation.
##
## Performance impact:
##   Before: ~200 triangles per bubble via CPU (C++ triangulation)
##   After:  ~18 triangles per bubble via GPU atlas (2 triangles per layer)
##
## Usage:
##   var batcher = BubbleAtlasBatcher.new()
##   batcher.build_atlas()  # Call once at startup
##
##   # Each frame:
##   batcher.begin(canvas_item)
##   batcher.add_circle_layer("circle_100", pos, radius, color)
##   batcher.add_arc_layer(pos, radius, from_angle, to_angle, color)
##   batcher.flush()

# Atlas configuration
const ATLAS_WIDTH: int = 1024
const ATLAS_HEIGHT: int = 256
const CELL_SIZE: int = 128  # Each template cell is 128x128
const SMALL_CELL_SIZE: int = 64  # For small templates like highlight

# Template definitions: [name, cell_index, radius_factor, is_ring, thickness]
# radius_factor: What fraction of cell_size/2 the radius should be
# For rings: inner_radius = radius - thickness/2
const TEMPLATES: Array = [
	["circle_100", 0, 1.0, false, 0.0],    # Main bubble body (full cell)
	["circle_110", 1, 1.0, false, 0.0],    # Dark background layer
	["circle_160", 2, 1.0, false, 0.0],    # Mid glow layer (soft edge)
	["circle_220", 3, 1.0, false, 0.0],    # Outer glow layer (very soft)
	["circle_050", 4, 1.0, false, 0.0],    # Glossy highlight (half size cell)
	["ring_thin", 5, 0.9, true, 2.5],      # Outline ring, 2.5px width
	["ring_data", 6, 0.9, true, 2.0],      # Purity/probability rings, 2.0px width
	["ring_thick", 7, 0.9, true, 4.0],     # Uncertainty ring, thicker
	["wedge_gradient", 8, 1.0, false, 0.0],  # Triangular gradient (40° wide) for season broadcast
	["spin_spiral", 9, 1.0, false, 0.0],     # Rotating internal pattern for spin illusion
]

# Season angles (in radians): 0°, 120°, 240°
const SEASON_ANGLES: Array[float] = [0.0, TAU / 3.0, 2.0 * TAU / 3.0]
const SEASON_COLORS: Array[Color] = [
	Color(1.0, 0.3, 0.3, 0.8),  # Season 0: Red
	Color(0.3, 1.0, 0.3, 0.8),  # Season 1: Green
	Color(0.3, 0.3, 1.0, 0.8),  # Season 2: Blue
]

# Atlas texture (generated at startup)
var _atlas_texture: ImageTexture = null
var _atlas_image: Image = null

# Template name → UV rect mapping (normalized 0-1 coordinates)
var _template_uvs: Dictionary = {}

# Current canvas item we're drawing to
var _canvas_item: RID = RID()

# Batch data (single texture = single batch!)
var _points: PackedVector2Array = PackedVector2Array()
var _uvs: PackedVector2Array = PackedVector2Array()
var _colors: PackedColorArray = PackedColorArray()

# Arc geometry (dynamic, but batched together)
var _arc_points: PackedVector2Array = PackedVector2Array()
var _arc_colors: PackedColorArray = PackedColorArray()

# Capacity tracking to avoid frequent reallocations
var _last_vertex_count: int = 0
var _last_arc_count: int = 0

# Empty arrays for RenderingServer call
var _empty_bones := PackedInt32Array()
var _empty_weights := PackedFloat32Array()

# Pre-allocated indices arrays (reused each frame to avoid GDScript loop)
var _indices: PackedInt32Array = PackedInt32Array()
var _arc_indices: PackedInt32Array = PackedInt32Array()
var _max_indices_size: int = 0
var _max_arc_indices_size: int = 0

# Stats
var _layer_count: int = 0
var _arc_count: int = 0
var _draw_calls: int = 0
var _atlas_built: bool = false

# Software rendering mode - reduces visual complexity for llvmpipe
# Set via configure_for_software_rendering()
var software_mode: bool = false
var draw_glow_layers: bool = true
var draw_data_rings: bool = true
var enable_spin_pattern: bool = true
var enable_season_wedges: bool = true


func configure_for_software_rendering(enabled: bool = true) -> void:
	"""Enable simplified rendering for software renderers (llvmpipe).

	Reduces layers from ~12 to ~4 per bubble for ~3x FPS improvement.
	"""
	software_mode = enabled
	draw_glow_layers = not enabled
	draw_data_rings = not enabled
	enable_spin_pattern = not enabled
	enable_season_wedges = not enabled
	if enabled:
		print("[BubbleAtlasBatcher] Software rendering mode: ENABLED (simplified visuals)")

# Arc configuration
const ARC_SEGMENTS: int = 24  # Segments for full circle arc

# =============================================================================
# PURITY BAND CACHING - Pre-computed arc geometry for fast rendering
# =============================================================================
# Bands: 0=[0-0.25], 1=[0.25-0.5], 2=[0.5-0.75], 3=[0.75-1.0]
# Arc angles: 45°, 135°, 225°, 315° (midpoint of each band × 360°)
const PURITY_BAND_ANGLES: Array[float] = [
	0.125 * TAU,   # Band 0: 45°
	0.375 * TAU,   # Band 1: 135°
	0.625 * TAU,   # Band 2: 225°
	0.875 * TAU,   # Band 3: 315°
]

# Pre-computed unit arc geometry (relative to center, unit radius)
# Format: PackedFloat64Array of [cos1, sin1, cos2, sin2] per segment, flattened
var _purity_arc_cache: Array[PackedFloat64Array] = []  # Band index → flat array
var _purity_arc_segment_counts: PackedInt32Array = PackedInt32Array()  # Segments per band
var _purity_arc_cache_built: bool = false


func _build_purity_arc_cache() -> void:
	"""Pre-compute arc geometry for each purity band (call once at startup)."""
	if _purity_arc_cache_built:
		return

	_purity_arc_cache.clear()
	_purity_arc_segment_counts.clear()

	for band in range(4):
		var angle_span = PURITY_BAND_ANGLES[band]
		var segments = maxi(8, int(absf(angle_span) * ARC_SEGMENTS / TAU))
		var data = PackedFloat64Array()
		data.resize(segments * 4)  # 4 floats per segment: cos1, sin1, cos2, sin2

		for i in range(segments):
			var t1 = float(i) / float(segments)
			var t2 = float(i + 1) / float(segments)

			var a1 = -PI / 2 + angle_span * t1  # Start from top (-PI/2)
			var a2 = -PI / 2 + angle_span * t2

			var base = i * 4
			data[base + 0] = cos(a1)
			data[base + 1] = sin(a1)
			data[base + 2] = cos(a2)
			data[base + 3] = sin(a2)

		_purity_arc_cache.append(data)
		_purity_arc_segment_counts.append(segments)

	_purity_arc_cache_built = true


func add_purity_ring_from_band(pos: Vector2, radius: float, width: float,
							   band: int, color: Color) -> void:
	"""Add purity ring using pre-cached geometry (FAST path).

	Uses pre-computed cos/sin values in packed array - minimal overhead.
	"""
	if color.a < 0.01 or radius < 0.5 or width < 0.5:
		return
	if band < 0 or band > 3:
		band = 1  # Default to middle band

	var inner_radius = maxf(0.0, radius - width * 0.5)
	var outer_radius = radius + width * 0.5

	# Use pre-cached segment geometry (packed array for fast access)
	var data = _purity_arc_cache[band]
	var segments = _purity_arc_segment_counts[band]

	for i in range(segments):
		var base = i * 4
		var cos1 = data[base + 0]
		var sin1 = data[base + 1]
		var cos2 = data[base + 2]
		var sin2 = data[base + 3]

		var inner1 = pos + Vector2(cos1 * inner_radius, sin1 * inner_radius)
		var outer1 = pos + Vector2(cos1 * outer_radius, sin1 * outer_radius)
		var inner2 = pos + Vector2(cos2 * inner_radius, sin2 * inner_radius)
		var outer2 = pos + Vector2(cos2 * outer_radius, sin2 * outer_radius)

		# Triangle 1: inner1, outer1, inner2
		_arc_points.append(inner1)
		_arc_points.append(outer1)
		_arc_points.append(inner2)
		_arc_colors.append(color)
		_arc_colors.append(color)
		_arc_colors.append(color)

		# Triangle 2: inner2, outer1, outer2
		_arc_points.append(inner2)
		_arc_points.append(outer1)
		_arc_points.append(outer2)
		_arc_colors.append(color)
		_arc_colors.append(color)
		_arc_colors.append(color)

	_arc_count += 1


func _ensure_indices_capacity(size: int) -> void:
	"""Ensure pre-allocated indices array is large enough."""
	if size <= _max_indices_size:
		return
	# Grow with headroom to avoid frequent reallocations
	var new_size = maxi(size, _max_indices_size * 2)
	new_size = maxi(new_size, 2048)  # Minimum reasonable size
	_indices.resize(new_size)
	# Fill new indices (only need to fill newly allocated portion)
	for i in range(_max_indices_size, new_size):
		_indices[i] = i
	_max_indices_size = new_size


func _ensure_arc_indices_capacity(size: int) -> void:
	"""Ensure pre-allocated arc indices array is large enough."""
	if size <= _max_arc_indices_size:
		return
	var new_size = maxi(size, _max_arc_indices_size * 2)
	new_size = maxi(new_size, 2048)
	_arc_indices.resize(new_size)
	for i in range(_max_arc_indices_size, new_size):
		_arc_indices[i] = i
	_max_arc_indices_size = new_size


func _init():
	# Pre-allocate typical capacity
	var typical_verts = 2048
	var typical_arc_verts = 4096

	# Pre-allocate indices array (avoids slow GDScript loop in flush())
	_ensure_indices_capacity(typical_verts)
	_ensure_arc_indices_capacity(typical_arc_verts)


func build_atlas() -> bool:
	"""Pre-render all geometric templates to a GPU texture atlas.

	Call this ONCE at startup.

	Returns:
		true if atlas was built successfully
	"""
	var start_time = Time.get_ticks_msec()

	# Create atlas image (RGBA8 for transparency)
	_atlas_image = Image.create(ATLAS_WIDTH, ATLAS_HEIGHT, false, Image.FORMAT_RGBA8)
	_atlas_image.fill(Color(0, 0, 0, 0))  # Transparent background

	# Render each template to its cell
	for template_def in TEMPLATES:
		var template_name: String = template_def[0]
		var cell_index: int = template_def[1]
		var radius_factor: float = template_def[2]
		var is_ring: bool = template_def[3]
		var thickness: float = template_def[4]

		# Calculate cell position (wrap to second row if needed)
		# Atlas is 1024x256, cells are 128x128, so 8 cells per row, 2 rows
		var cells_per_row = ATLAS_WIDTH / CELL_SIZE  # 8
		var cell_x = (cell_index % cells_per_row) * CELL_SIZE
		var cell_y = (cell_index / cells_per_row) * CELL_SIZE

		# Determine actual cell size (smaller for highlight template)
		var actual_cell_size = CELL_SIZE
		if template_name == "circle_050":
			actual_cell_size = SMALL_CELL_SIZE

		# Render template to image
		var template_img = _render_template(template_name, actual_cell_size, radius_factor, is_ring, thickness)
		if template_img:
			# Blit to atlas
			var src_rect = Rect2i(0, 0, actual_cell_size, actual_cell_size)
			_atlas_image.blit_rect(template_img, src_rect, Vector2i(cell_x, cell_y))

		# Store UV coordinates (normalized 0-1)
		var uv_x = float(cell_x) / float(ATLAS_WIDTH)
		var uv_y = float(cell_y) / float(ATLAS_HEIGHT)
		var uv_w = float(actual_cell_size) / float(ATLAS_WIDTH)
		var uv_h = float(actual_cell_size) / float(ATLAS_HEIGHT)

		_template_uvs[template_name] = Rect2(uv_x, uv_y, uv_w, uv_h)

	# Create GPU texture from atlas image
	_atlas_texture = ImageTexture.create_from_image(_atlas_image)
	_atlas_built = true

	# Pre-compute purity band arc geometry (avoids per-frame trig calls)
	_build_purity_arc_cache()

	var elapsed = Time.get_ticks_msec() - start_time
	print("[BubbleAtlasBatcher] Atlas built: %dx%d (%d templates) + %d purity bands in %dms" % [
		ATLAS_WIDTH, ATLAS_HEIGHT, _template_uvs.size(), _purity_arc_cache.size(), elapsed
	])

	return true


func _render_template(template_name: String, cell_size: int, radius_factor: float, is_ring: bool, thickness: float) -> Image:
	"""Render a single geometric template to an Image.

	Creates grayscale/white shapes with anti-aliased edges.
	Color modulation is applied per-vertex at draw time.
	"""
	# Special templates with custom rendering
	if template_name == "wedge_gradient":
		return _render_wedge_template(cell_size)
	elif template_name == "spin_spiral":
		return _render_spin_spiral_template(cell_size)

	var img = Image.create(cell_size, cell_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var center = Vector2(cell_size / 2.0, cell_size / 2.0)
	var base_radius = (cell_size / 2.0 - 4.0) * radius_factor  # 4px margin for AA

	# Determine softness based on template type
	var edge_softness = 2.0  # Default anti-alias width

	# Special soft edges for glow templates
	if template_name == "circle_160":
		edge_softness = 16.0  # Very soft for mid glow
	elif template_name == "circle_220":
		edge_softness = 24.0  # Very soft for outer glow
	elif template_name == "circle_050":
		edge_softness = 3.0  # Slightly softer for highlight

	for y in range(cell_size):
		for x in range(cell_size):
			var pos = Vector2(x + 0.5, y + 0.5)  # Sample at pixel center
			var dist = pos.distance_to(center)
			var alpha = 0.0

			if is_ring:
				# Ring shape: visible between inner and outer radius
				var inner_radius = base_radius - thickness
				var outer_radius = base_radius + thickness

				if dist >= inner_radius and dist <= outer_radius:
					# Distance from ring center
					var ring_dist = absf(dist - base_radius)
					alpha = 1.0 - smoothstep(0.0, thickness, ring_dist)
			else:
				# Filled circle with soft edge
				if dist < base_radius:
					alpha = 1.0
				elif dist < base_radius + edge_softness:
					# Smooth falloff
					alpha = 1.0 - smoothstep(base_radius, base_radius + edge_softness, dist)

			if alpha > 0.001:
				# White template - color applied via vertex colors
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return img


func _render_wedge_template(cell_size: int) -> Image:
	"""Render a triangular gradient wedge for season broadcast.

	The wedge:
	- Points upward (0° = up, will be rotated at draw time)
	- Inner radius = 0.5 (starts at bubble edge when scaled)
	- Outer radius = 1.0 (extends to 2× bubble radius)
	- Angular span = 40° (20° each side)
	- Gradient: alpha 1.0 at inner → 0.0 at outer
	- Soft angular falloff at edges
	"""
	var img = Image.create(cell_size, cell_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var center = Vector2(cell_size / 2.0, cell_size / 2.0)
	var max_radius = cell_size / 2.0 - 2.0  # Small margin for AA

	# Wedge parameters
	var inner_radius_ratio = 0.3  # Start at 30% of cell radius
	var outer_radius_ratio = 1.0  # Extend to full cell radius
	var half_angle = deg_to_rad(20.0)  # 40° total width

	for y in range(cell_size):
		for x in range(cell_size):
			var pos = Vector2(x + 0.5, y + 0.5)
			var to_pixel = pos - center
			var dist = to_pixel.length()
			var pixel_angle = to_pixel.angle()

			# Wedge points upward (negative Y = -PI/2)
			# Normalize angle relative to up direction
			var angle_from_up = _wrap_angle(pixel_angle + PI / 2.0)

			# Check if within angular span
			var angle_factor = 1.0 - smoothstep(half_angle * 0.7, half_angle, absf(angle_from_up))
			if angle_factor < 0.001:
				continue

			# Check if within radial span
			var normalized_dist = dist / max_radius
			if normalized_dist < inner_radius_ratio or normalized_dist > outer_radius_ratio:
				continue

			# Radial gradient: full alpha at inner, zero at outer
			var radial_t = (normalized_dist - inner_radius_ratio) / (outer_radius_ratio - inner_radius_ratio)
			var radial_alpha = 1.0 - smoothstep(0.0, 1.0, radial_t)

			# Combine angular and radial factors
			var alpha = radial_alpha * angle_factor

			if alpha > 0.001:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return img


func _render_spin_spiral_template(cell_size: int) -> Image:
	"""Render a subtle spiral pattern for spinning illusion.

	Creates radial lines with slight spiral twist that, when rotated,
	create the illusion of a spinning disk.
	"""
	var img = Image.create(cell_size, cell_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var center = Vector2(cell_size / 2.0, cell_size / 2.0)
	var max_radius = cell_size / 2.0 - 4.0

	# Spiral parameters
	var num_arms = 6  # Number of spiral arms
	var twist_amount = 0.3  # How much the arms twist (radians per unit radius)
	var arm_width = 0.15  # Width of each arm in radians

	for y in range(cell_size):
		for x in range(cell_size):
			var pos = Vector2(x + 0.5, y + 0.5)
			var to_pixel = pos - center
			var dist = to_pixel.length()
			var pixel_angle = to_pixel.angle()

			if dist < 2.0 or dist > max_radius:
				continue

			# Spiral twist: angle increases with distance
			var twisted_angle = pixel_angle - twist_amount * (dist / max_radius)

			# Calculate proximity to nearest arm
			var arm_angle = fmod(twisted_angle * num_arms / TAU + 1000.0, 1.0)  # 0 to 1
			var dist_to_arm = absf(arm_angle - 0.5)  # Distance to arm center (0.5)
			if dist_to_arm > 0.5:
				dist_to_arm = 1.0 - dist_to_arm

			# Soft falloff from arm center
			var arm_factor = 1.0 - smoothstep(0.0, arm_width, dist_to_arm)

			# Radial fade: stronger in center, fading at edges
			var radial_factor = 1.0 - smoothstep(0.3, 1.0, dist / max_radius)

			var alpha = arm_factor * radial_factor * 0.6  # Max 60% opacity

			if alpha > 0.001:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return img


func _wrap_angle(angle: float) -> float:
	"""Wrap angle to [-PI, PI] range."""
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle


func smoothstep(edge0: float, edge1: float, x: float) -> float:
	"""Smooth interpolation between edges."""
	var t = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func begin(canvas_item: RID) -> void:
	"""Begin a new batch frame.

	Args:
		canvas_item: The canvas item RID to draw to (from get_canvas_item())
	"""
	_canvas_item = canvas_item
	_points.clear()
	_uvs.clear()
	_colors.clear()
	_arc_points.clear()
	_arc_colors.clear()
	_layer_count = 0
	_arc_count = 0
	_draw_calls = 0


func add_circle_layer(template: String, pos: Vector2, radius: float, color: Color) -> void:
	"""Add a circle layer using pre-rendered atlas template.

	Args:
		template: Template name (e.g., "circle_100", "circle_160")
		pos: Center position in screen space
		radius: Desired radius in pixels
		color: Color to modulate (applied via per-vertex colors)
	"""
	if not _template_uvs.has(template):
		push_warning("[BubbleAtlasBatcher] Unknown template: %s" % template)
		return

	if color.a < 0.01:
		return  # Skip nearly invisible layers

	if radius < 0.5:
		return  # Skip tiny circles

	var uv_rect: Rect2 = _template_uvs[template]
	_add_quad_to_batch(pos, radius, uv_rect, color)
	_layer_count += 1


func _add_quad_to_batch(center: Vector2, radius: float, uv_rect: Rect2, color: Color) -> void:
	"""Add a textured quad to the batch arrays.

	Creates 2 triangles (6 vertices) for the quad.
	"""
	var half_size = Vector2(radius, radius)

	# Quad corners
	var tl = center - half_size
	var tr = center + Vector2(half_size.x, -half_size.y)
	var bl = center + Vector2(-half_size.x, half_size.y)
	var br = center + half_size

	# UV coordinates from atlas rect
	var uv_tl = Vector2(uv_rect.position.x, uv_rect.position.y)
	var uv_tr = Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y)
	var uv_bl = Vector2(uv_rect.position.x, uv_rect.position.y + uv_rect.size.y)
	var uv_br = Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y + uv_rect.size.y)

	# Triangle 1: tl, tr, br
	_points.append(tl); _uvs.append(uv_tl); _colors.append(color)
	_points.append(tr); _uvs.append(uv_tr); _colors.append(color)
	_points.append(br); _uvs.append(uv_br); _colors.append(color)

	# Triangle 2: tl, br, bl
	_points.append(tl); _uvs.append(uv_tl); _colors.append(color)
	_points.append(br); _uvs.append(uv_br); _colors.append(color)
	_points.append(bl); _uvs.append(uv_bl); _colors.append(color)


func add_rotated_quad(template: String, center: Vector2, radius: float,
					  rotation: float, color: Color) -> void:
	"""Add a rotated textured quad using pre-rendered atlas template.

	Rotates the quad corners around the center while keeping UV mapping fixed.
	This allows the wedge template to be drawn at any angle without multiple atlas entries.

	Args:
		template: Template name (e.g., "wedge_gradient")
		center: Center position in screen space
		radius: Desired radius in pixels (half the quad size)
		rotation: Rotation angle in radians
		color: Color to modulate (applied via per-vertex colors)
	"""
	if not _template_uvs.has(template):
		push_warning("[BubbleAtlasBatcher] Unknown template: %s" % template)
		return

	if color.a < 0.01:
		return  # Skip nearly invisible layers

	if radius < 0.5:
		return  # Skip tiny quads

	var uv_rect: Rect2 = _template_uvs[template]

	# Pre-compute rotation
	var cos_r = cos(rotation)
	var sin_r = sin(rotation)

	# Unrotated quad corners (relative to center)
	var half = radius
	var offsets = [
		Vector2(-half, -half),  # top-left
		Vector2(half, -half),   # top-right
		Vector2(-half, half),   # bottom-left
		Vector2(half, half)     # bottom-right
	]

	# Rotate each offset around center
	var rotated = []
	for offset in offsets:
		var rotated_offset = Vector2(
			offset.x * cos_r - offset.y * sin_r,
			offset.x * sin_r + offset.y * cos_r
		)
		rotated.append(center + rotated_offset)

	var tl = rotated[0]
	var tr = rotated[1]
	var bl = rotated[2]
	var br = rotated[3]

	# UV coordinates from atlas rect (NOT rotated - texture stays fixed)
	var uv_tl = Vector2(uv_rect.position.x, uv_rect.position.y)
	var uv_tr = Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y)
	var uv_bl = Vector2(uv_rect.position.x, uv_rect.position.y + uv_rect.size.y)
	var uv_br = Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y + uv_rect.size.y)

	# Triangle 1: tl, tr, br
	_points.append(tl); _uvs.append(uv_tl); _colors.append(color)
	_points.append(tr); _uvs.append(uv_tr); _colors.append(color)
	_points.append(br); _uvs.append(uv_br); _colors.append(color)

	# Triangle 2: tl, br, bl
	_points.append(tl); _uvs.append(uv_tl); _colors.append(color)
	_points.append(br); _uvs.append(uv_br); _colors.append(color)
	_points.append(bl); _uvs.append(uv_bl); _colors.append(color)

	_layer_count += 1


func add_arc_layer(pos: Vector2, radius: float, from_angle: float, to_angle: float, width: float, color: Color) -> void:
	"""Add an arc layer using dynamic geometry (batched).

	For variable-angle arcs that can't be pre-rendered.
	"""
	if color.a < 0.01:
		return

	if radius < 0.5 or width < 0.5:
		return

	var inner_radius = radius - width * 0.5
	var outer_radius = radius + width * 0.5
	if inner_radius < 0:
		inner_radius = 0

	var angle_span = to_angle - from_angle
	if absf(angle_span) < 0.01:
		return

	# Calculate segments based on arc length
	var segments = maxi(8, int(absf(angle_span) * ARC_SEGMENTS / TAU))

	for i in range(segments):
		var t1 = float(i) / float(segments)
		var t2 = float(i + 1) / float(segments)

		var a1 = from_angle + angle_span * t1
		var a2 = from_angle + angle_span * t2

		var cos1 = cos(a1)
		var sin1 = sin(a1)
		var cos2 = cos(a2)
		var sin2 = sin(a2)

		var inner1 = pos + Vector2(cos1 * inner_radius, sin1 * inner_radius)
		var outer1 = pos + Vector2(cos1 * outer_radius, sin1 * outer_radius)
		var inner2 = pos + Vector2(cos2 * inner_radius, sin2 * inner_radius)
		var outer2 = pos + Vector2(cos2 * outer_radius, sin2 * outer_radius)

		# Triangle 1: inner1, outer1, inner2
		_arc_points.append(inner1)
		_arc_points.append(outer1)
		_arc_points.append(inner2)
		_arc_colors.append(color)
		_arc_colors.append(color)
		_arc_colors.append(color)

		# Triangle 2: inner2, outer1, outer2
		_arc_points.append(inner2)
		_arc_points.append(outer1)
		_arc_points.append(outer2)
		_arc_colors.append(color)
		_arc_colors.append(color)
		_arc_colors.append(color)

	_arc_count += 1


func add_filled_arc(pos: Vector2, radius: float, from_angle: float, to_angle: float, color: Color) -> void:
	"""Add a filled arc (pie slice) using dynamic geometry."""
	if color.a < 0.01:
		return

	if radius < 0.5:
		return

	var angle_span = to_angle - from_angle
	if absf(angle_span) < 0.01:
		return

	var segments = maxi(8, int(absf(angle_span) * ARC_SEGMENTS / TAU))

	for i in range(segments):
		var t1 = float(i) / float(segments)
		var t2 = float(i + 1) / float(segments)

		var a1 = from_angle + angle_span * t1
		var a2 = from_angle + angle_span * t2

		var p1 = pos + Vector2(cos(a1), sin(a1)) * radius
		var p2 = pos + Vector2(cos(a2), sin(a2)) * radius

		# Triangle: center, p1, p2 (fan triangulation)
		_arc_points.append(pos)
		_arc_points.append(p1)
		_arc_points.append(p2)
		_arc_colors.append(color)
		_arc_colors.append(color)
		_arc_colors.append(color)

	_arc_count += 1


func flush() -> void:
	"""Submit all batched draws to RenderingServer.

	ONE draw call for textured quads (atlas), ONE for arcs (untextured).
	Uses pre-allocated indices arrays to avoid slow GDScript loops.
	"""
	if not _canvas_item.is_valid():
		return

	# Track counts for pre-allocation next frame
	_last_vertex_count = _points.size()
	_last_arc_count = _arc_points.size()

	# Draw atlas-textured geometry (circles from templates)
	var point_count = _points.size()
	if point_count > 0 and _atlas_texture:
		# Ensure indices array is large enough
		_ensure_indices_capacity(point_count)

		# Submit with indices slice
		RenderingServer.canvas_item_add_triangle_array(
			_canvas_item,
			_indices.slice(0, point_count),
			_points,
			_colors,
			_uvs,
			_empty_bones,
			_empty_weights,
			_atlas_texture.get_rid()
		)
		_draw_calls += 1

	# Draw untextured arc geometry
	var arc_count = _arc_points.size()
	if arc_count > 0:
		_ensure_arc_indices_capacity(arc_count)

		RenderingServer.canvas_item_add_triangle_array(
			_canvas_item,
			_arc_indices.slice(0, arc_count),
			_arc_points,
			_arc_colors,
			PackedVector2Array(),  # No UVs for solid color
			_empty_bones,
			_empty_weights
			# No texture RID = solid color triangles
		)
		_draw_calls += 1


func is_atlas_built() -> bool:
	"""Check if atlas is ready for use."""
	return _atlas_built


func get_atlas_texture() -> ImageTexture:
	"""Get the atlas texture (for debugging/visualization)."""
	return _atlas_texture


func get_stats() -> Dictionary:
	"""Get batching statistics for performance monitoring."""
	var total_verts = _last_vertex_count + _last_arc_count
	return {
		"layer_count": _layer_count,
		"arc_count": _arc_count,
		"draw_calls": _draw_calls,
		"templates": _template_uvs.size(),
		"atlas_size": Vector2i(ATLAS_WIDTH, ATLAS_HEIGHT),
		"vertex_count": total_verts,
		"triangle_count": total_verts / 3,
	}


# =============================================================================
# HIGH-LEVEL BUBBLE DRAWING API
# =============================================================================
# These methods mirror the C++ batched_bubble_renderer.cpp visual layers
# for easy migration. Call these instead of low-level add_circle_layer().

func draw_bubble(pos: Vector2, base_radius: float, anim_scale: float, anim_alpha: float,
				 base_color: Color, energy: float, time: float,
				 is_measured: bool, is_celestial: bool,
				 individual_purity: float = 0.5, biome_purity: float = 0.5,
				 global_prob: float = 0.0, p_north: float = 0.0, p_south: float = 0.0,
				 sink_flux: float = 0.0, pulse_phase: float = 0.0,
				 phi_raw: float = 0.0, season_projections: Array = [],
				 coherence: float = 0.0, shadow_influence: Dictionary = {}) -> void:
	"""Draw a complete bubble with all visual layers.

	Replicates the C++ batched_bubble_renderer visual appearance.
	Now includes spinning bubbles with triangular seasonal broadcast.

	New parameters for spinning/wedges:
		phi_raw: Raw phase angle (drives rotation)
		season_projections: [R, G, B] intensities at 0°, 120°, 240°
		coherence: Coherence magnitude for spin pattern visibility
		shadow_influence: Optional {tint: Color, strength: float} from nearby bubbles
	"""
	if anim_scale <= 0.0:
		return

	# Calculate effective radius with pulse
	var pulse_scale = 1.0 + pulse_phase * 0.08
	var effective_radius = base_radius * anim_scale * pulse_scale

	# Glow tint (complementary hue)
	var glow_tint = _get_complementary_color(base_color)
	var glow_alpha = (energy * 0.5 + 0.3) * anim_alpha

	# === LAYERS 1-2: OUTER GLOWS ===
	if draw_glow_layers:
		if is_measured and not is_celestial:
			_draw_measured_glow(pos, base_radius, anim_scale, anim_alpha, time)
		else:
			_draw_unmeasured_glow(pos, effective_radius, glow_tint, glow_alpha, is_celestial)

	# === LAYER 3: Dark background ===
	var bg_mult = 1.12 if is_celestial else 1.08
	add_circle_layer("circle_110", pos, effective_radius * bg_mult,
		Color(0.1, 0.1, 0.15, 0.85 * anim_alpha))

	# === LAYER 4: Main bubble ===
	var lighten_amount = 0.1 if is_celestial else 0.15
	var main_color = _lighten(base_color, lighten_amount)
	main_color.a = 0.75 * anim_alpha
	add_circle_layer("circle_100", pos, effective_radius, main_color)

	# === LAYER 4b: Spinning internal pattern (before highlight) ===
	if enable_spin_pattern and not is_celestial and not is_measured and coherence > 0.05:
		draw_spin_pattern(pos, effective_radius, phi_raw, coherence, anim_alpha)

	# === LAYER 5: Glossy highlight ===
	var highlight_offset = Vector2(-effective_radius * 0.25, -effective_radius * 0.25)
	var highlight_color = _lighten(base_color, 0.6)
	highlight_color.a = 0.8 * anim_alpha
	var highlight_size = 0.4 if is_celestial else 0.5
	add_circle_layer("circle_050", pos + highlight_offset,
		effective_radius * highlight_size, highlight_color)

	# === LAYER 6: Outline ===
	if is_measured and not is_celestial:
		_draw_measured_outline(pos, base_radius, anim_scale, anim_alpha, time)
	else:
		var outline_color: Color
		var outline_width: float
		if is_celestial:
			outline_color = Color(1.0, 0.9, 0.3, 0.95 * anim_alpha)
			outline_width = 3.0
		else:
			outline_color = Color(1.0, 1.0, 1.0, 0.95 * anim_alpha)
			outline_width = 2.5
		add_arc_layer(pos, effective_radius * 1.02, 0, TAU, outline_width, outline_color)

	# === LAYER 6b-6e: Data rings (non-celestial only) ===
	if draw_data_rings and not is_celestial:
		_draw_data_rings(pos, effective_radius, anim_alpha,
			individual_purity, biome_purity, global_prob, p_north, p_south, sink_flux, time)

	# === LAYER 7: Season wedges (non-celestial, non-measured only) ===
	if enable_season_wedges and not is_celestial and not is_measured and season_projections.size() >= 3:
		draw_season_wedges(pos, effective_radius, phi_raw, season_projections, anim_alpha, shadow_influence)


func _draw_measured_glow(pos: Vector2, base_radius: float, anim_scale: float, anim_alpha: float, time: float) -> void:
	"""Draw cyan pulsing glow for measured bubbles."""
	var measured_pulse = 0.5 + 0.5 * sin(time * 4.0)

	# Outer pulsing ring
	var outer_alpha = (0.4 + 0.3 * measured_pulse) * anim_alpha
	add_circle_layer("circle_220", pos,
		base_radius * (2.2 + 0.3 * measured_pulse) * anim_scale,
		Color(0.0, 1.0, 1.0, outer_alpha))

	# Mid glow
	add_circle_layer("circle_160", pos, base_radius * 1.6 * anim_scale,
		Color(0.2, 0.95, 1.0, 0.8 * anim_alpha))

	# Inner glow
	add_circle_layer("circle_110", pos, base_radius * 1.3 * anim_scale,
		Color(0.8, 1.0, 1.0, 0.95 * anim_alpha))


func _draw_unmeasured_glow(pos: Vector2, effective_radius: float, glow_tint: Color, glow_alpha: float, is_celestial: bool) -> void:
	"""Draw complementary-hued glow for unmeasured bubbles."""
	# Outer glow
	var outer_mult = 2.2 if is_celestial else 1.6
	var outer_glow = glow_tint
	outer_glow.a = glow_alpha * 0.4
	add_circle_layer("circle_220", pos, effective_radius * outer_mult, outer_glow)

	# Mid glow
	var mid_mult = 1.8 if is_celestial else 1.3
	var mid_glow = glow_tint
	mid_glow.a = glow_alpha * 0.6
	add_circle_layer("circle_160", pos, effective_radius * mid_mult, mid_glow)

	# Extra inner glow for celestial
	if is_celestial and glow_alpha > 0:
		var inner_glow = _lighten(glow_tint, 0.2)
		inner_glow.a = glow_alpha * 0.8
		add_circle_layer("circle_110", pos, effective_radius * 1.4, inner_glow)


func _draw_measured_outline(pos: Vector2, base_radius: float, anim_scale: float, anim_alpha: float, time: float) -> void:
	"""Draw cyan outline with checkmark indicator for measured bubbles."""
	var measured_pulse = 0.5 + 0.5 * sin(time * 4.0)

	# Outer cyan ring
	var outline_alpha = (0.85 + 0.15 * measured_pulse) * anim_alpha
	add_arc_layer(pos, base_radius * 1.08 * anim_scale, 0, TAU, 5.0,
		Color(0.0, 1.0, 1.0, outline_alpha))

	# Inner white ring
	add_arc_layer(pos, base_radius * 1.0 * anim_scale, 0, TAU, 3.0,
		Color(1.0, 1.0, 1.0, 0.95 * anim_alpha))

	# Checkmark indicator circle
	var check_pos = pos + Vector2(base_radius * 0.7 * anim_scale, -base_radius * 0.7 * anim_scale)
	add_circle_layer("circle_050", check_pos, 6.0 * anim_scale,
		Color(0.2, 1.0, 0.4, 0.95 * anim_alpha))


func _draw_data_rings(pos: Vector2, effective_radius: float, anim_alpha: float,
					  individual_purity: float, biome_purity: float,
					  global_prob: float, p_north: float, p_south: float,
					  sink_flux: float, time: float) -> void:
	"""Draw purity, probability, and uncertainty data rings."""

	# Purity ring (inner) - OPTIMIZED: uses pre-cached arc geometry
	if individual_purity > 0.01:
		# Bucket purity into bands for color + cached arc geometry
		var purity_band = clampi(int(individual_purity * 4.0), 0, 3)
		var biome_band = clampi(int(biome_purity * 4.0), 0, 3)

		var purity_color: Color
		if purity_band > biome_band:
			purity_color = Color(0.4, 0.9, 1.0, 0.6 * anim_alpha)  # Cyan: purer
		elif purity_band < biome_band:
			purity_color = Color(1.0, 0.4, 0.8, 0.6 * anim_alpha)  # Magenta: mixed
		else:
			purity_color = Color(0.9, 0.9, 0.9, 0.4 * anim_alpha)  # White: average

		var purity_radius = effective_radius * 0.6
		# Use cached arc geometry (no per-frame trig calls!)
		add_purity_ring_from_band(pos, purity_radius, 2.0, purity_band, purity_color)

	# Probability ring (outer)
	if global_prob > 0.01:
		var arc_color = Color(1.0, 1.0, 1.0, 0.4 * anim_alpha)
		var arc_radius = effective_radius * 1.25
		var arc_extent = global_prob * TAU
		add_arc_layer(pos, arc_radius, -PI / 2, -PI / 2 + arc_extent, 2.0, arc_color)

	# Uncertainty ring
	var mass = p_north + p_south
	if mass > 0.001:
		var p_n = p_north / mass
		var p_s = p_south / mass
		var uncertainty = 2.0 * sqrt(p_n * p_s)

		if uncertainty > 0.05:
			var ring_radius = effective_radius * 1.15
			var max_thickness = 6.0
			var thickness = max_thickness * uncertainty

			# Blue to magenta gradient based on uncertainty
			var hue = 0.75 - uncertainty * 0.15
			var ring_color = Color.from_hsv(hue, 0.7, 0.9, 0.6 * anim_alpha * uncertainty)
			add_arc_layer(pos, ring_radius, 0, TAU, thickness, ring_color)

			# Inner glow at high uncertainty
			if uncertainty > 0.7:
				var glow_color = ring_color
				glow_color.a = 0.3 * anim_alpha
				add_arc_layer(pos, ring_radius, 0, TAU, thickness * 2.0, glow_color)

	# Sink flux particles (dynamic circles)
	if sink_flux > 0.001:
		var particle_count = int(clampf(sink_flux * 20.0, 1.0, 6.0))
		for i in range(particle_count):
			var particle_time = time * 0.5 + float(i) * 0.3
			var particle_phase = fmod(particle_time, 1.0)

			var angle = (float(i) / particle_count) * TAU + particle_time * 2.0
			var dist = effective_radius * (1.2 + particle_phase * 0.8)

			var px = pos.x + cos(angle) * dist
			var py = pos.y + sin(angle) * dist
			var particle_alpha = (1.0 - particle_phase) * 0.6 * anim_alpha
			var particle_color = Color(0.8, 0.4, 0.2, particle_alpha)
			var particle_size = 3.0 * (1.0 - particle_phase * 0.5)

			add_circle_layer("circle_050", Vector2(px, py), particle_size, particle_color)


func _get_complementary_color(base: Color) -> Color:
	"""Calculate complementary glow color (180° hue shift)."""
	var h = fmod(base.h + 0.5, 1.0)
	var s = minf(base.s * 1.3, 1.0)
	var v = maxf(base.v * 0.6, 0.3)
	return Color.from_hsv(h, s, v, 1.0)


func _lighten(color: Color, amount: float) -> Color:
	"""Lighten a color by blending toward white."""
	return Color(
		minf(1.0, color.r + (1.0 - color.r) * amount),
		minf(1.0, color.g + (1.0 - color.g) * amount),
		minf(1.0, color.b + (1.0 - color.b) * amount),
		color.a
	)


# =============================================================================
# SPINNING BUBBLES - SEASONAL WEDGE BROADCAST
# =============================================================================
# Bubbles visually spin, broadcasting phi colors via triangular wedges.
# Angular coupling creates emergent swirling - bubbles in each other's
# "seasonal shadow" synchronize their rotation.

func draw_season_wedges(pos: Vector2, radius: float, phi_raw: float,
						season_projections: Array, anim_alpha: float,
						shadow_influence: Dictionary = {}) -> void:
	"""Draw 3 RGB wedges per bubble at 0°, 120°, 240° rotated by phi_raw.

	Args:
		pos: Bubble center position
		radius: Bubble radius
		phi_raw: Raw phase angle (drives rotation)
		season_projections: [R, G, B] intensities at 0°, 120°, 240°
		anim_alpha: Animation alpha for fade-in
		shadow_influence: Optional {tint: Color, strength: float} from nearby bubbles
	"""
	if anim_alpha < 0.01:
		return

	# Wedge extends from bubble edge outward
	var wedge_radius = radius * 1.8  # Size of wedge quad
	var wedge_offset = radius * 1.2  # Distance from bubble center to wedge center

	for i in range(3):
		var intensity = season_projections[i] if i < season_projections.size() else 0.5
		if intensity < 0.05:
			continue  # Skip very dim wedges

		# Angle for this season (0°, 120°, 240°) plus phi rotation
		var angle = SEASON_ANGLES[i] + phi_raw

		# Get base season color
		var wedge_color = SEASON_COLORS[i]
		wedge_color.a = (0.2 + 0.5 * intensity) * anim_alpha

		# Apply shadow influence tinting if present
		if shadow_influence.has("tint") and shadow_influence.has("strength"):
			var influence_strength = shadow_influence["strength"]
			if influence_strength > 0.05:
				wedge_color = wedge_color.lerp(shadow_influence["tint"], influence_strength * 0.4)

		# Position wedge at bubble edge, extending outward
		var wedge_center = pos + Vector2.from_angle(angle) * wedge_offset

		# Draw wedge rotated to point outward from bubble
		# The template points "up" (-Y), so we rotate to match angle
		add_rotated_quad("wedge_gradient", wedge_center, wedge_radius, angle + PI / 2.0, wedge_color)


func draw_spin_pattern(pos: Vector2, radius: float, phi_raw: float,
					   coherence: float, anim_alpha: float) -> void:
	"""Draw subtle rotating internal spiral pattern.

	Creates "spinning disk" illusion without disturbing bubble's main appearance.

	Args:
		pos: Bubble center position
		radius: Bubble radius
		phi_raw: Raw phase angle (drives rotation)
		coherence: Coherence magnitude (higher = more visible pattern)
		anim_alpha: Animation alpha for fade-in
	"""
	if anim_alpha < 0.01 or coherence < 0.05:
		return  # Skip if invisible or decoherent

	# Subtle spin pattern - scales with coherence
	var spin_alpha = anim_alpha * 0.2 * coherence
	if spin_alpha < 0.02:
		return

	var spin_color = Color(1.0, 1.0, 1.0, spin_alpha)

	# Draw spin pattern rotated by phi
	add_rotated_quad("spin_spiral", pos, radius * 0.85, phi_raw, spin_color)
