class_name BatchedBubbleRenderer
extends RefCounted

# Shared constants
const VisualizationConstants = preload("res://Core/Visualization/VisualizationConstants.gd")
const QuantumBubbleRenderer = preload("res://Core/Visualization/QuantumBubbleRenderer.gd")
const EmojiAtlasBatcher = preload("res://Core/Visualization/EmojiAtlasBatcher.gd")

## Batched Bubble Renderer - Rendering Tier Coordinator
##
## Routes bubble rendering to one of three implementations based on availability:
##
## RENDERING TIER DECISION (checked in draw() at line ~140):
##   1. ✅ BubbleAtlasBatcher (GPU texture atlas) - PRODUCTION PATH
##      - Fastest: ~18 triangles/bubble, 1-2 draw calls total
##      - Pre-rendered templates with per-vertex color modulation
##      - Used when: bubble_atlas_batcher in context AND atlas built
##      - Status: ALWAYS ACTIVE in production (atlas build succeeds)
##
##   2. 🔶 NativeBubbleRenderer (C++ triangulation) - UNUSED FALLBACK
##      - Fast: ~200 triangles/bubble, 1 draw call (batched)
##      - Lazy-init: Only instantiated if atlas unavailable
##      - Status: NEVER REACHED (atlas always available)
##
##   3. 🔴 QuantumBubbleRenderer (GDScript) - LEGACY FALLBACK
##      - Slow: individual draw calls per layer
##      - Always instantiated but only used if both above fail
##      - Status: NEVER EXECUTED in production (safety net only)
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

# Atlas renderer (GPU texture batching - fastest)
# Note: Untyped to avoid circular dependency with BubbleAtlasBatcher.gd load order
var _bubble_atlas_batcher = null
var _use_atlas: bool = false

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

# Shadow influence cache (computed once per frame)
var _shadow_influences: Dictionary = {}  # node_instance_id → {tint: Color, strength: float}
var _shadow_compute_enabled: bool = false  # DISABLED by default - GDScript O(n²) too slow!
# TODO: Enable when GPU compute is wired up via GPUQuantumCompute.compute_shadow_gpu()
var _gpu_compute: Node = null  # Optional GPUQuantumCompute for fast shadow calc

# Season constants - imported from shared source
const SEASON_ANGLES = VisualizationConstants.SEASON_ANGLES
const SEASON_COLORS = VisualizationConstants.SEASON_COLORS


func _init():
	# IMPORTANT: Do NOT instantiate native renderer here - defer until needed
	# This allows the atlas renderer (when available) to completely bypass C++ code
	# Native renderer will only be created if:
	#   1. Atlas is not available AND
	#   2. Native code is needed (lazy initialization)

	# Always create GDScript fallback (lightweight, used if native unavailable)
	print("[BatchedBubbleRenderer] Initializing renderers (native deferred, atlas-priority)")
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
		print("[BatchedBubbleRenderer] Using pre-built emoji atlas (%d emojis)" % atlas_batcher._emoji_uvs.size())


func set_bubble_atlas_batcher(atlas_batcher) -> void:
	"""Set a pre-built bubble atlas batcher for GPU-accelerated bubble rendering.

	Call this after building the atlas during boot to enable fast batched drawing.
	Priority: Atlas → Native → GDScript
	"""
	if atlas_batcher and atlas_batcher.is_atlas_built():
		_bubble_atlas_batcher = atlas_batcher
		_use_atlas = true
		print("[BatchedBubbleRenderer] Using pre-built bubble atlas (priority over C++)")


func is_atlas_enabled() -> bool:
	"""Check if GPU atlas bubble renderer is being used."""
	return _use_atlas


func draw(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw all quantum bubbles.

	Rendering priority: Atlas (GPU) → Native C++ (GPU triangles) → GDScript (CPU)

	IMPORTANT: When using atlas, C++ renderer is NEVER instantiated or called.
	Early return at line below ensures complete bypass of native code.

	Args:
	    graph: The QuantumForceGraph node (for drawing calls)
	    ctx: Context with {quantum_nodes, biomes, time_accumulator, terminal_pool, etc.}
	"""
	# Check for pre-built bubble atlas in context (first-time setup)
	var bubble_atlas = ctx.get("bubble_atlas_batcher")
	if bubble_atlas and bubble_atlas != _bubble_atlas_batcher and bubble_atlas.is_atlas_built():
		set_bubble_atlas_batcher(bubble_atlas)

	# Pass geometry batcher to emoji batcher for batched placeholder rendering (once)
	var geometry_batcher = ctx.get("geometry_batcher")
	if geometry_batcher and _emoji_batcher and _emoji_batcher._geometry_batcher != geometry_batcher:
		_emoji_batcher.set_geometry_batcher(geometry_batcher)

	# Priority 1: GPU Atlas rendering (fastest) - COMPLETELY BYPASSES C++ CODE
	if _use_atlas and _bubble_atlas_batcher:
		_draw_with_atlas(graph, ctx)
		return  # <-- C++ native renderer is NOT instantiated or executed when atlas is used

	# Priority 2: Native C++ rendering
	if _use_native:
		_draw_with_native(graph, ctx)
		return

	# Priority 3: GDScript fallback (slowest)
	_fallback_renderer.draw(graph, ctx)


var _perf_loop_us: int = 0
var _perf_flush_us: int = 0
var _perf_emoji_us: int = 0
var _perf_frame_count: int = 0

func _draw_with_atlas(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw all bubbles using GPU texture atlas batching.

	This is the fastest path - pre-rendered templates + per-vertex color modulation.
	"""
	var t0 = Time.get_ticks_usec()

	# Check for pre-built emoji atlas in context
	var emoji_atlas = ctx.get("emoji_atlas_batcher")
	if emoji_atlas and emoji_atlas != _emoji_batcher and emoji_atlas._atlas_built:
		set_emoji_atlas_batcher(emoji_atlas)

	var quantum_nodes = ctx.get("quantum_nodes", [])
	var biomes = ctx.get("biomes", {})
	var time_accumulator = ctx.get("time_accumulator", 0.0)
	var terminal_pool = ctx.get("terminal_pool")
	var batcher = ctx.get("biome_evolution_batcher", null)

	# Compute shadow influences once per frame (O(n²) but n is small)
	if _shadow_compute_enabled:
		_compute_shadow_influences(quantum_nodes, biomes)

	_emoji_queue.clear()
	_bubble_atlas_batcher.begin(graph.get_canvas_item())

	for node in quantum_nodes:
		if not node.visible:
			continue
		if not node.plot and node.emoji_north.is_empty():
			continue

		# FAST PATH: Get interpolated phi for smooth wedge rotation
		# Avoids expensive full update_from_quantum_state() call
		var interpolated_phi = node.phi_raw
		var interpolated_coherence = node.coherence
		var biome = biomes.get(node.biome_name) if node.biome_name != "" else null
		if batcher and batcher.lookahead_enabled and biome and biome.viz_cache:
			var qubit_idx = biome.viz_cache.get_qubit(node.emoji_north)
			if qubit_idx >= 0:
				var snap = batcher.get_interpolated_snapshot(node.biome_name, qubit_idx)
				if not snap.is_empty():
					interpolated_phi = snap.get("phi", node.phi_raw)
					var r_xy = snap.get("r_xy", 0.0)
					interpolated_coherence = r_xy * 0.5
					# Update season projections from interpolated phi
					for i in range(3):
						var angle_diff = interpolated_phi - node.SEASON_ANGLES[i]
						node.season_projections[i] = (1.0 + cos(angle_diff)) * 0.5 * interpolated_coherence

		# Get bubble parameters
		var anim_scale = node.visual_scale
		var anim_alpha = node.visual_alpha
		if anim_scale <= 0.0:
			continue

		var is_measured = _is_node_measured(node, terminal_pool)
		var is_celestial = false  # Regular bubbles, not sun

		# Calculate pulse phase
		var pulse_rate = node.get_pulse_rate()
		var pulse_phase = sin(time_accumulator * pulse_rate * TAU) * 0.5 + 0.5

		# Get purity and probability data
		var individual_purity = 0.5
		var biome_purity = 0.5
		var global_prob = 0.0
		var p_north = 0.0
		var p_south = 0.0
		var sink_flux = 0.0

		# HIGH-TRUST: biome already looked up above (line 228)
		biome_purity = biome.viz_cache.get_purity()
		if biome_purity < 0.0:
			biome_purity = 0.5

		p_north = node.emoji_north_opacity
		p_south = node.emoji_south_opacity
		global_prob = clampf(p_north + p_south, 0.0, 1.0)
		individual_purity = node.energy if node.energy > 0.0 else 0.5

		# Get shadow influence for this node (computed earlier this frame)
		var shadow_influence = _shadow_influences.get(node.get_instance_id(), {})

		# Compute phi-driven color from season projections
		var phi_color = _compute_phi_color(node)
		# Blend phi color with original (70% phi, 30% original for stability)
		var base_color = phi_color.lerp(node.color, 0.3)

		# Draw bubble with all visual layers (including spinning wedges)
		# Use interpolated phi/coherence for smooth 60fps wedge rotation
		_bubble_atlas_batcher.draw_bubble(
			node.position,
			node.radius,
			anim_scale,
			anim_alpha,
			base_color,  # Phi-driven color
			node.energy,
			time_accumulator,
			is_measured,
			is_celestial,
			individual_purity,
			biome_purity,
			global_prob,
			p_north,
			p_south,
			sink_flux,
			pulse_phase,
			interpolated_phi,
			node.season_projections,
			interpolated_coherence,
			shadow_influence,
			node.berry_phase  # Berry phase drives glow intensity
		)

		# Queue emoji for drawing
		_emoji_queue.append({
			"position": node.position,
			"radius": node.radius,
			"emoji_north": node.emoji_north,
			"emoji_south": node.emoji_south,
			"emoji_north_opacity": node.emoji_north_opacity,
			"emoji_south_opacity": node.emoji_south_opacity,
			"is_celestial": false
		})

	var t1 = Time.get_ticks_usec()

	# Flush bubble atlas (ONE or TWO draw calls for all bubbles!)
	_bubble_atlas_batcher.flush()

	var t2 = Time.get_ticks_usec()

	# Draw emojis (batched via GPU atlas when available)
	_draw_emoji_pass(graph)

	var t3 = Time.get_ticks_usec()

	# Accumulate timing
	_perf_loop_us += (t1 - t0)
	_perf_flush_us += (t2 - t1)
	_perf_emoji_us += (t3 - t2)
	_perf_frame_count += 1

	# Report every 120 frames
	if _perf_frame_count >= 120:
		var loop_ms = _perf_loop_us / 1000.0 / _perf_frame_count
		var flush_ms = _perf_flush_us / 1000.0 / _perf_frame_count
		var emoji_ms = _perf_emoji_us / 1000.0 / _perf_frame_count
		var total_ms = loop_ms + flush_ms + emoji_ms
		print("[BUBBLE_PERF] loop=%.2fms flush=%.2fms emoji=%.2fms total=%.2fms" % [
			loop_ms, flush_ms, emoji_ms, total_ms
		])
		_perf_loop_us = 0
		_perf_flush_us = 0
		_perf_emoji_us = 0
		_perf_frame_count = 0


func _draw_with_native(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw all bubbles using native C++ triangulation.

	Fallback when atlas is not available. Still fast, but more triangles.

	LAZY INITIALIZATION: C++ renderer only instantiated when actually needed
	(i.e., when atlas is not available).
	"""
	# Lazily instantiate native renderer only if not yet created
	if not _native_renderer and not _use_native:
		if ClassDB.class_exists("NativeBubbleRenderer"):
			_native_renderer = ClassDB.instantiate("NativeBubbleRenderer")
			_use_native = _native_renderer != null
			if _use_native:
				print("[BatchedBubbleRenderer] Native renderer instantiated (lazy init)")
			else:
				print("[BatchedBubbleRenderer] Native renderer instantiation failed - falling back to GDScript")
				_fallback_renderer.draw(graph, ctx)
				return
		else:
			print("[BatchedBubbleRenderer] NativeBubbleRenderer not available - using GDScript fallback")
			_fallback_renderer.draw(graph, ctx)
			return

	# If we got here without native renderer, fallback to GDScript
	if not _use_native:
		_fallback_renderer.draw(graph, ctx)
		return

	# Check for pre-built emoji atlas in context
	var emoji_atlas = ctx.get("emoji_atlas_batcher")
	if emoji_atlas and emoji_atlas != _emoji_batcher and emoji_atlas._atlas_built:
		set_emoji_atlas_batcher(emoji_atlas)

	var quantum_nodes = ctx.get("quantum_nodes", [])
	var biomes = ctx.get("biomes", {})
	var time_accumulator = ctx.get("time_accumulator", 0.0)
	var terminal_pool = ctx.get("terminal_pool")
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

		_pack_bubble_data(node, biomes, time_accumulator, terminal_pool, false)

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
	"""Draw the sun/moon qubit node with celestial styling.

	Rendering priority: Atlas (GPU) → Native C++ (GPU triangles) → GDScript (CPU)

	IMPORTANT: When using atlas, C++ renderer is NEVER instantiated or called.
	"""
	var sun_qubit_node = ctx.get("sun_qubit_node")
	if not sun_qubit_node:
		return

	# Priority 1: GPU Atlas rendering - COMPLETELY BYPASSES C++ CODE
	if _use_atlas and _bubble_atlas_batcher:
		_draw_sun_qubit_with_atlas(graph, ctx)
		return  # <-- C++ native renderer is NOT instantiated or executed when atlas is used

	# Priority 2: Native C++ rendering
	if _use_native:
		_draw_sun_qubit_with_native(graph, ctx)
		return

	# Priority 3: GDScript fallback
	_fallback_renderer.draw_sun_qubit(graph, ctx)


func _draw_sun_qubit_with_atlas(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw sun qubit using GPU atlas rendering."""
	var sun_qubit_node = ctx.get("sun_qubit_node")
	var biotic_flux_biome = ctx.get("biotic_flux_biome")
	var time_accumulator = ctx.get("time_accumulator", 0.0)

	if not sun_qubit_node:
		return

	sun_qubit_node.visual_scale = 1.0
	sun_qubit_node.visual_alpha = 1.0

	_emoji_queue.clear()
	_bubble_atlas_batcher.begin(graph.get_canvas_item())

	# Draw pulsing energy aura (special sun effect - direct draw, not batched)
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

	# Calculate pulse phase
	var pulse_rate = sun_qubit_node.get_pulse_rate()
	var pulse_phase = sin(time_accumulator * pulse_rate * TAU) * 0.5 + 0.5

	# Sun uses celestial color (golden yellow)
	var base_color = Color(1.0, 0.8, 0.2)

	# Draw sun bubble with celestial styling
	_bubble_atlas_batcher.draw_bubble(
		sun_qubit_node.position,
		sun_qubit_node.radius,
		1.0,  # anim_scale
		1.0,  # anim_alpha
		base_color,
		sun_qubit_node.energy,
		time_accumulator,
		false,  # is_measured
		true,   # is_celestial
		0.5, 0.5, 0.0, 0.0, 0.0, 0.0,  # data ring params (unused for celestial)
		pulse_phase,
		0.0,  # phi_raw (celestial doesn't spin)
		[],   # season_projections (none for celestial)
		0.0,  # coherence (none for celestial)
		{},   # shadow_influence (none for celestial)
		sun_qubit_node.berry_phase  # Berry phase drives sun glow
	)

	# Flush bubble atlas
	_bubble_atlas_batcher.flush()

	# Queue sun emoji
	_emoji_queue.append({
		"position": sun_qubit_node.position,
		"radius": sun_qubit_node.radius,
		"emoji_north": sun_qubit_node.emoji_north,
		"emoji_south": sun_qubit_node.emoji_south,
		"emoji_north_opacity": sun_qubit_node.emoji_north_opacity,
		"emoji_south_opacity": sun_qubit_node.emoji_south_opacity,
		"is_celestial": true
	})

	# Draw sun emoji
	_draw_emoji_pass(graph)

	# Celestial label
	var font = ThemeDB.fallback_font
	var label_color = Color(1.0, 0.85, 0.3, 0.7)
	var label_pos = sun_qubit_node.position + Vector2(0, sun_qubit_node.radius + 25)
	graph.draw_string(font, label_pos, "Celestial", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, label_color)


func _draw_sun_qubit_with_native(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw sun qubit using native C++ triangulation.

	LAZY INITIALIZATION: C++ renderer only instantiated when actually needed.
	"""
	# Lazily instantiate native renderer if needed
	if not _native_renderer and not _use_native:
		if ClassDB.class_exists("NativeBubbleRenderer"):
			_native_renderer = ClassDB.instantiate("NativeBubbleRenderer")
			_use_native = _native_renderer != null
			if not _use_native:
				_fallback_renderer.draw_sun_qubit(graph, ctx)
				return
		else:
			_fallback_renderer.draw_sun_qubit(graph, ctx)
			return

	if not _use_native:
		_fallback_renderer.draw_sun_qubit(graph, ctx)
		return

	var sun_qubit_node = ctx.get("sun_qubit_node")
	var biotic_flux_biome = ctx.get("biotic_flux_biome")
	var biomes = ctx.get("biomes", {})
	var time_accumulator = ctx.get("time_accumulator", 0.0)
	var terminal_pool = ctx.get("terminal_pool")

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
	_pack_bubble_data(sun_qubit_node, biomes, time_accumulator, terminal_pool, true)

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


func _pack_bubble_data(node, biomes: Dictionary, time_accumulator: float, terminal_pool, is_celestial: bool) -> void:
	"""Pack a single bubble's data into the matrix."""
	var offset = _num_bubbles * STRIDE

	var anim_scale = node.visual_scale
	var anim_alpha = node.visual_alpha

	if anim_scale <= 0.0:
		return

	# Check if measured
	var is_measured = _is_node_measured(node, terminal_pool)

	# Calculate pulse phase (map sin output to 0-1)
	var pulse_rate = node.get_pulse_rate()
	var pulse_phase = sin(time_accumulator * pulse_rate * TAU) * 0.5 + 0.5

	# Get base color (phi-driven for non-celestial bubbles)
	var base_color: Color
	if is_celestial:
		base_color = Color(1.0, 0.8, 0.2)
	else:
		# Compute phi-driven color from season projections
		var phi_color = _compute_phi_color(node)
		# Blend phi color with original (70% phi, 30% original for stability)
		base_color = phi_color.lerp(node.color, 0.3)

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


func _is_node_measured(node, terminal_pool) -> bool:
	"""Check if node has been measured."""
	if not node:
		return false
	if node.plot != null and node.plot.has_been_measured:
		return true
	if node.terminal and node.terminal.is_measured:
		return true
	if terminal_pool and node.grid_position != Vector2i(-1, -1):
		var terminal = terminal_pool.get_terminal_at_grid_pos(node.grid_position) if terminal_pool.has_method("get_terminal_at_grid_pos") else null
		if terminal and terminal.is_measured:
			return true
	return false


func _compute_shadow_influences(nodes: Array, biomes: Dictionary) -> void:
	"""Compute shadow influences for all nodes (O(n²) but n is small ~24).

	When bubble B is in bubble A's dominant wedge direction AND they have
	Hamiltonian coupling, B's wedges get tinted toward A's dominant season.
	"""
	_shadow_influences.clear()

	var node_count = nodes.size()
	if node_count < 2:
		return

	# Build lookup for fast node access
	var visible_nodes = []
	for node in nodes:
		if node.visible and node.coherence > 0.05:
			visible_nodes.append(node)

	var n = visible_nodes.size()
	if n < 2:
		return

	# For each node B, accumulate influences from all nodes A
	for node_b in visible_nodes:
		var accumulated_tint = Color.WHITE
		var accumulated_strength = 0.0

		for node_a in visible_nodes:
			if node_a == node_b:
				continue

			# Skip if A has weak coherence (no clear season)
			if node_a.coherence < 0.1:
				continue

			# Get A's season projections
			var proj_a = node_a.season_projections
			if proj_a.size() < 3:
				continue

			# Find A's dominant season
			var dominant_idx = 0
			var dominant_intensity = proj_a[0]
			for i in range(1, 3):
				if proj_a[i] > dominant_intensity:
					dominant_idx = i
					dominant_intensity = proj_a[i]

			# Skip if dominant season is weak
			if dominant_intensity < 0.15:
				continue

			# A's wedge angle = season angle + phi rotation
			var wedge_angle = SEASON_ANGLES[dominant_idx] + node_a.phi_raw

			# Vector from A to B
			var a_to_b = node_b.position - node_a.position
			var dist = a_to_b.length()

			# Skip if too far (max influence distance 300px)
			if dist > 300.0 or dist < 1.0:
				continue

			var angle_to_b = a_to_b.angle()

			# Check if B is within A's wedge cone (30° half-angle)
			var angle_diff = _wrap_angle(wedge_angle - angle_to_b)
			var wedge_half_angle = PI / 6.0  # 30 degrees

			if absf(angle_diff) > wedge_half_angle:
				continue

			# Get coupling strength from biome viz_cache
			var coupling = 0.0
			if node_a.biome_name != "" and biomes.has(node_a.biome_name):
				var biome = biomes[node_a.biome_name]
				if biome and biome.viz_cache:
					var couplings = biome.viz_cache.get_hamiltonian_couplings(node_a.emoji_north)
					coupling = couplings.get(node_b.emoji_north, 0.0)

			# Skip if no coupling
			if coupling < 0.01:
				continue

			# Compute influence strength
			var distance_factor = 1.0 - clampf(dist / 300.0, 0.0, 1.0)
			var angle_factor = 1.0 - absf(angle_diff) / wedge_half_angle
			var strength = coupling * distance_factor * angle_factor * dominant_intensity

			# Accumulate weighted tint
			var season_color = SEASON_COLORS[dominant_idx]
			accumulated_tint = accumulated_tint.lerp(season_color, strength * 0.4)
			accumulated_strength = minf(accumulated_strength + strength, 1.0)

		# Store influence for this node
		if accumulated_strength > 0.05:
			_shadow_influences[node_b.get_instance_id()] = {
				"tint": accumulated_tint,
				"strength": accumulated_strength
			}


func _wrap_angle(angle: float) -> float:
	"""Wrap angle to [-PI, PI] range."""
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle


func get_emoji_stats() -> Dictionary:
	"""Get emoji batching statistics for performance monitoring."""
	if _emoji_batcher:
		return _emoji_batcher.get_stats()
	return {"emoji_count": 0, "draw_calls": 0, "unique_textures": 0, "savings": 0}


func get_bubble_stats() -> Dictionary:
	"""Get bubble batching statistics for performance monitoring."""
	if _bubble_atlas_batcher:
		return _bubble_atlas_batcher.get_stats()
	return {"layer_count": 0, "arc_count": 0, "draw_calls": 0, "templates": 0}


func is_native_enabled() -> bool:
	"""Check if native bubble renderer is being used."""
	return _use_native and not _use_atlas


func is_shadow_compute_enabled() -> bool:
	"""Check if shadow influence computation is enabled."""
	return _shadow_compute_enabled


func set_shadow_compute_enabled(enabled: bool) -> void:
	"""Enable or disable shadow influence computation.

	When enabled: O(n²) GDScript computation per frame (disabled by default).
	Shadow influence tints wedges based on angular coupling between bubbles.

	Args:
		enabled: True to enable shadow influence, False to disable
	"""
	_shadow_compute_enabled = enabled
	if not enabled:
		_shadow_influences.clear()
	print("[BatchedBubbleRenderer] Shadow compute: %s" % ("ENABLED" if enabled else "DISABLED"))


func get_renderer_type() -> String:
	"""Get the current active renderer type."""
	if _use_atlas:
		return "atlas"
	elif _use_native:
		return "native"
	else:
		return "gdscript"


func _compute_phi_color(node) -> Color:
	"""Compute bubble interior color driven by phi and season projections.

	Blends the three season colors (Red/Green/Blue at 0°/120°/240°)
	based on how strongly phi projects onto each season basis.

	Args:
		node: QuantumNode with season_projections array

	Returns:
		Color blended from season projections (defaults to neutral gray if no data)
	"""
	var projections: Array = node.season_projections
	if projections.size() < 3:
		# No season data - return neutral gray
		return Color(0.5, 0.5, 0.5)

	var r_proj = projections[0]
	var g_proj = projections[1]
	var b_proj = projections[2]

	# Blend season colors weighted by projections
	var blended_color = (
		VisualizationConstants.SEASON_COLORS[0] * r_proj +
		VisualizationConstants.SEASON_COLORS[1] * g_proj +
		VisualizationConstants.SEASON_COLORS[2] * b_proj
	)

	# Normalize by total projection
	var total_proj = r_proj + g_proj + b_proj
	if total_proj > 0.01:
		blended_color = blended_color / total_proj
	else:
		# No projections - default to neutral
		blended_color = Color(0.5, 0.5, 0.5)

	return blended_color


func compact_buffer() -> void:
	"""Shrink buffer to current node count (called after bulk node removal)"""
	var required_size = (_num_bubbles + 1) * STRIDE
	if _bubble_data.size() > required_size * 2:  # Only shrink if >2x oversized
		_bubble_data.resize(required_size)
		print("[BatchedBubbleRenderer] Buffer compacted to %d floats" % required_size)
