class_name QuantumBubbleRenderer
extends RefCounted

## Quantum Bubble Renderer
##
## Renders individual quantum bubbles with physics-grounded visual encoding:
##
## VISUAL CHANNEL → PHYSICS DATA
## - Emoji opacity: P(n)/mass, P(s)/mass (measurement probability)
## - Color hue: arg(ρ_01) (coherence phase)
## - Color saturation: |ρ_01| (coherence magnitude)
## - Glow intensity: Tr(ρ²) + berry_phase (purity + unbounded evolution experience)
## - Berry phase glow: Unbounded accumulation (grows indefinitely with evolution)
## - Inner purity ring: Individual Tr(ρ²) (local purity vs biome)
## - Outer probability ring: P(n)+P(s) globally (total probability mass)
## - Measurement uncertainty ring: 2×√(p_n×p_s) (outcome spread)
## - Sink flux particles: sink_flux_per_emoji (decoherence rate)
## - Measured halo: is_measured flag (collapsed state)

# Debug mode
var DEBUG_MODE: bool = false


func draw(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw all quantum bubbles.

	Args:
	    graph: The QuantumForceGraph node (for drawing calls)
	    ctx: Context with {quantum_nodes, biomes, time_accumulator, plot_pool, etc.}
	"""
	var quantum_nodes = ctx.get("quantum_nodes", [])
	var biomes = ctx.get("biomes", {})
	var time_accumulator = ctx.get("time_accumulator", 0.0)
	var plot_pool = ctx.get("plot_pool")
	var frame_count = ctx.get("frame_count", 0)

	for node in quantum_nodes:
		# Skip hidden nodes (single-biome view)
		if not node.visible:
			continue

		# v2: Terminal bubbles may have null plot but valid emoji data
		if not node.plot and node.emoji_north.is_empty():
			continue

		# NOTE: Visuals are updated by QuantumNodeManager (including terminal bubbles)

		# Draw the bubble
		_draw_quantum_bubble(graph, node, biomes, time_accumulator, plot_pool, false)


func draw_sun_qubit(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw the sun/moon qubit node with celestial styling.

	Args:
	    graph: The QuantumForceGraph node
	    ctx: Context dictionary
	"""
	var sun_qubit_node = ctx.get("sun_qubit_node")
	var biotic_flux_biome = ctx.get("biotic_flux_biome")
	var biomes = ctx.get("biomes", {})
	var time_accumulator = ctx.get("time_accumulator", 0.0)
	var plot_pool = ctx.get("plot_pool")

	if not sun_qubit_node:
		return

	# Ensure full visibility
	sun_qubit_node.visual_scale = 1.0
	sun_qubit_node.visual_alpha = 1.0

	# Draw pulsing energy aura
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

	# Draw with celestial styling
	_draw_quantum_bubble(graph, sun_qubit_node, biomes, time_accumulator, plot_pool, true)

	# Celestial label
	var font = ThemeDB.fallback_font
	var label_color = Color(1.0, 0.85, 0.3, 0.7)
	var label_pos = sun_qubit_node.position + Vector2(0, sun_qubit_node.radius + 25)
	graph.draw_string(font, label_pos, "Celestial", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, label_color)


func _draw_quantum_bubble(graph: Node2D, node, biomes: Dictionary, time_accumulator: float, plot_pool, is_celestial: bool) -> void:
	"""Draw a single quantum bubble with all visual encodings."""
	var anim_scale = node.visual_scale
	var anim_alpha = node.visual_alpha

	if anim_scale <= 0.0:
		return

	# Check if measured
	var is_measured = _is_node_measured(node, plot_pool)

	# Pulse animation disabled - berry phase now affects glow only
	# var pulse_rate = node.get_pulse_rate()  # Berry phase (evolution speed)
	# var measurement_uncertainty = _get_measurement_uncertainty(node, biomes, is_celestial)
	# var pulse_amplitude = 0.12 * measurement_uncertainty  # 0-12% breathing amplitude
	# var pulse_phase = sin(time_accumulator * pulse_rate * TAU) * 0.5 + 0.5
	# var pulse_scale = 1.0 + pulse_phase * pulse_amplitude
	var pulse_scale = 1.0  # Fixed scale - no breathing

	# Color scheme
	var base_color: Color
	var glow_tint: Color

	if is_celestial:
		base_color = Color(1.0, 0.8, 0.2)
		glow_tint = base_color
	else:
		base_color = node.color
		glow_tint = Color.from_hsv(
			fmod(node.color.h + 0.5, 1.0),
			min(node.color.s * 1.3, 1.0),
			max(node.color.v * 0.6, 0.3)
		)

	# Glow based on berry phase (will be real when C++ computes geometric phase)
	var berry_glow = node.berry_phase * 0.05
	var glow_alpha = (0.5 + berry_glow) * anim_alpha  # Base glow without purity
	var effective_radius = node.radius * anim_scale  # Removed pulse_scale

	# === LAYER 1-2: OUTER GLOWS ===
	if is_measured and not is_celestial:
		_draw_measured_glow(graph, node, anim_scale, anim_alpha, time_accumulator)
	else:
		_draw_unmeasured_glow(graph, node, effective_radius, glow_tint, glow_alpha, is_celestial)

	# === LAYER 3: Dark background ===
	var dark_bg = Color(0.1, 0.1, 0.15, 0.85)
	var bg_mult = 1.12 if is_celestial else 1.08
	graph.draw_circle(node.position, effective_radius * bg_mult, dark_bg)

	# === LAYER 4: Main bubble ===
	var main_color = base_color.lightened(0.15 if not is_celestial else 0.1)
	main_color.s = min(main_color.s * 1.2, 1.0)
	main_color.a = 0.75 * anim_alpha
	graph.draw_circle(node.position, effective_radius, main_color)

	# === LAYER 5: Glossy center ===
	var bright_center = base_color.lightened(0.6)
	bright_center.a = 0.8 * anim_alpha
	var spot_size = 0.4 if is_celestial else 0.5
	graph.draw_circle(
		node.position + Vector2(-effective_radius * 0.25, -effective_radius * 0.25),
		effective_radius * spot_size,
		bright_center
	)

	# === LAYER 6: Outline ===
	if is_measured and not is_celestial:
		_draw_measured_outline(graph, node, anim_scale, anim_alpha, time_accumulator)
	else:
		_draw_unmeasured_outline(graph, node, effective_radius, is_celestial, anim_alpha)

	# === LAYER 6b: Individual purity ring ===
	if not is_celestial and node.biome_name != "":
		_draw_purity_ring(graph, node, biomes, effective_radius, anim_alpha)

	# === LAYER 6c: Global probability outer ring ===
	if not is_celestial and node.biome_name != "":
		_draw_probability_ring(graph, node, biomes, effective_radius, anim_alpha)

	# === LAYER 6d: Measurement uncertainty ring ===
	# Ring thickness = 2 × √(p_n × p_s) - Maximum at 50/50, zero when collapsed
	if not is_celestial and node.biome_name != "":
		_draw_measurement_uncertainty_ring(graph, node, biomes, effective_radius, anim_alpha)

	# === LAYER 6e: Sink flux particles ===
	if not is_celestial and node.biome_name != "":
		_draw_sink_flux_particles(graph, node, biomes, effective_radius, anim_alpha, time_accumulator)

	# === LAYER 6f: AZIMUTHAL SEASON RINGS ===
	# Three colored arcs showing phi decomposition into RGB-like "seasons"
	if not is_celestial and node.biome_name != "":
		_draw_season_rings(graph, node, effective_radius, anim_alpha, time_accumulator)

	# === LAYER 6g: BERRY PHASE RING ===
	# Golden ring showing accumulated geometric phase (Bloch sphere path integral)
	if not is_celestial and node.biome_name != "":
		_draw_berry_phase_ring(graph, node, effective_radius, anim_alpha)

	# === LAYER 7: Dual emoji system ===
	_draw_emojis(graph, node, is_celestial)


func _draw_measured_glow(graph: Node2D, node, anim_scale: float, anim_alpha: float, time: float) -> void:
	"""Draw pronounced glow for measured (ready to harvest) nodes."""
	var measured_pulse = 0.5 + 0.5 * sin(time * 4.0)

	var outer_ring = Color(0.0, 1.0, 1.0)
	outer_ring.a = (0.4 + 0.3 * measured_pulse) * anim_alpha
	graph.draw_circle(node.position, node.radius * (2.2 + 0.3 * measured_pulse) * anim_scale, outer_ring)

	var measured_glow = Color(0.2, 0.95, 1.0)
	measured_glow.a = 0.8 * anim_alpha
	graph.draw_circle(node.position, node.radius * 1.6 * anim_scale, measured_glow)

	var inner_glow = Color(0.8, 1.0, 1.0)
	inner_glow.a = 0.95 * anim_alpha
	graph.draw_circle(node.position, node.radius * 1.3 * anim_scale, inner_glow)


func _draw_unmeasured_glow(graph: Node2D, node, effective_radius: float, glow_tint: Color, glow_alpha: float, is_celestial: bool) -> void:
	"""Draw complementary/golden glow for unmeasured nodes."""
	var outer_glow = glow_tint
	outer_glow.a = glow_alpha * 0.4

	var outer_mult = 2.2 if is_celestial else 1.6
	graph.draw_circle(node.position, effective_radius * outer_mult, outer_glow)

	var mid_glow = glow_tint
	mid_glow.a = glow_alpha * 0.6
	var mid_mult = 1.8 if is_celestial else 1.3
	graph.draw_circle(node.position, effective_radius * mid_mult, mid_glow)

	if is_celestial and glow_alpha > 0:
		var inner_glow = glow_tint.lightened(0.2)
		inner_glow.a = glow_alpha * 0.8
		graph.draw_circle(node.position, effective_radius * 1.4, inner_glow)


func _draw_measured_outline(graph: Node2D, node, anim_scale: float, anim_alpha: float, time: float) -> void:
	"""Draw thick pulsing outline for measured nodes."""
	var measured_pulse = 0.5 + 0.5 * sin(time * 4.0)

	var measured_outline = Color(0.0, 1.0, 1.0)
	measured_outline.a = (0.85 + 0.15 * measured_pulse) * anim_alpha
	graph.draw_arc(node.position, node.radius * 1.08 * anim_scale, 0, TAU, 64, measured_outline, 5.0, true)

	var inner_outline = Color.WHITE
	inner_outline.a = 0.95 * anim_alpha
	graph.draw_arc(node.position, node.radius * 1.0 * anim_scale, 0, TAU, 64, inner_outline, 3.0, true)

	# Checkmark indicator
	var check_pos = node.position + Vector2(node.radius * 0.7, -node.radius * 0.7) * anim_scale
	var check_color = Color(0.2, 1.0, 0.4, 0.95 * anim_alpha)
	graph.draw_circle(check_pos, 6.0 * anim_scale, check_color)


func _draw_unmeasured_outline(graph: Node2D, node, effective_radius: float, is_celestial: bool, anim_alpha: float) -> void:
	"""Draw subtle outline for unmeasured nodes."""
	var outline_color: Color
	var outline_width: float

	if is_celestial:
		outline_color = Color(1.0, 0.9, 0.3)
		outline_width = 3.0
	else:
		outline_color = Color.WHITE
		outline_width = 2.5

	outline_color.a = 0.95 * anim_alpha
	graph.draw_arc(node.position, effective_radius * 1.02, 0, TAU, 64, outline_color, outline_width, true)


func _draw_purity_ring(graph: Node2D, node, biomes: Dictionary, effective_radius: float, anim_alpha: float) -> void:
	"""Draw inner ring showing individual purity vs biome average."""
	var biome = biomes.get(node.biome_name)
	if not biome or not biome.viz_cache:
		return

	var biome_purity = biome.viz_cache.get_purity()
	if biome_purity < 0.0:
		biome_purity = 0.5

	# Calculate individual purity
	var individual_purity = node.energy if node.energy > 0.0 else 0.5

	# Color based on comparison
	var purity_color: Color
	if individual_purity > biome_purity + 0.05:
		purity_color = Color(0.4, 0.9, 1.0, 0.6)  # Cyan: purer
	elif individual_purity < biome_purity - 0.05:
		purity_color = Color(1.0, 0.4, 0.8, 0.6)  # Magenta: more mixed
	else:
		purity_color = Color(0.9, 0.9, 0.9, 0.4)  # White: average

	purity_color.a *= anim_alpha

	var purity_ring_radius = effective_radius * 0.6
	var purity_extent = individual_purity * TAU

	if individual_purity > 0.01:
		graph.draw_arc(node.position, purity_ring_radius, -PI/2, -PI/2 + purity_extent, 24, purity_color, 2.0, true)


func _draw_probability_ring(graph: Node2D, node, biomes: Dictionary, effective_radius: float, anim_alpha: float) -> void:
	"""Draw outer ring showing global probability mass."""
	var global_prob = clampf(node.emoji_north_opacity + node.emoji_south_opacity, 0.0, 1.0)

	if global_prob > 0.01:
		var arc_color = Color(1.0, 1.0, 1.0, 0.4 * anim_alpha)
		var arc_radius = effective_radius * 1.25
		var arc_extent = global_prob * TAU
		graph.draw_arc(node.position, arc_radius, -PI/2, -PI/2 + arc_extent, 32, arc_color, 2.0, true)

		if global_prob > 0.05:
			var prob_font = ThemeDB.fallback_font
			var prob_text = "%d%%" % int(global_prob * 100)
			var prob_pos = node.position + Vector2(effective_radius * 0.9, -effective_radius * 0.9)
			graph.draw_string(prob_font, prob_pos, prob_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.5 * anim_alpha))


func _draw_measurement_uncertainty_ring(graph: Node2D, node, biomes: Dictionary, effective_radius: float, anim_alpha: float) -> void:
	"""Draw ring showing measurement outcome uncertainty.

	Physics: Ring thickness = 2 × √(p_n × p_s)
	- Maximum at 50/50 superposition (thickness = 1.0)
	- Zero when collapsed to either pole (thickness = 0)
	- Shows measurement outcome spread at a glance

	This helps players identify which bubbles have high measurement uncertainty
	(good candidates for quantum operations) vs which are nearly classical.
	"""
	var p_n = node.emoji_north_opacity
	var p_s = node.emoji_south_opacity
	var mass = p_n + p_s
	if mass < 0.001:
		return
	p_n = p_n / mass
	p_s = p_s / mass

	# Measurement uncertainty: 2 × √(p_n × p_s)
	# Maximum = 1.0 at 50/50 (p_n = p_s = 0.5 → 2 × √0.25 = 1.0)
	# Minimum = 0.0 when collapsed (p_n = 0 or p_s = 0)
	var uncertainty = 2.0 * sqrt(p_n * p_s)

	if uncertainty < 0.05:
		return  # Nearly collapsed - no ring needed

	# Draw uncertainty ring with thickness proportional to uncertainty
	var ring_radius = effective_radius * 1.15  # Slightly outside bubble
	var max_thickness = 6.0  # Maximum ring thickness at 50/50
	var thickness = max_thickness * uncertainty

	# Color: gradient from blue (low uncertainty) to magenta (high uncertainty)
	var hue = 0.75 - uncertainty * 0.15  # Blue→Magenta
	var ring_color = Color.from_hsv(hue, 0.7, 0.9, 0.6 * anim_alpha * uncertainty)

	# Draw as thick arc (full circle)
	graph.draw_arc(node.position, ring_radius, 0, TAU, 32, ring_color, thickness, true)

	# Inner glow for emphasis at high uncertainty
	if uncertainty > 0.7:
		var glow_color = ring_color
		glow_color.a = 0.3 * anim_alpha
		graph.draw_arc(node.position, ring_radius, 0, TAU, 32, glow_color, thickness * 2.0, true)


func _draw_sink_flux_particles(graph: Node2D, node, biomes: Dictionary, effective_radius: float, anim_alpha: float, time: float) -> void:
	"""Draw particles showing decoherence rate."""
	# Disabled: sink flux is not provided by native viz cache.
	return


func _draw_season_rings(graph: Node2D, node, effective_radius: float, anim_alpha: float, time: float) -> void:
	"""Draw three azimuthal 'season' rings showing phi decomposition.

	Physics: phi is projected onto 3 basis vectors at 0°, 120°, 240°
	Each ring's intensity = (1 + cos(phi - season_angle)) / 2 × coherence

	Visual: Three colored arcs that "whirlpool" based on quantum phase evolution.
	- Red (0°), Green (120°), Blue (240°) - like RGB primaries
	- Arc length/opacity shows projection strength
	- Position rotates with phi for visual coherence

	The rings create emergent angular force when combined across nodes.
	"""
	# Season ring constants
	const SEASON_ANGLES: Array[float] = [0.0, TAU / 3.0, 2.0 * TAU / 3.0]
	const SEASON_COLORS: Array[Color] = [
		Color(1.0, 0.3, 0.3),  # Season 0: Red
		Color(0.3, 1.0, 0.4),  # Season 1: Green
		Color(0.4, 0.4, 1.0),  # Season 2: Blue
	]

	var ring_radius = effective_radius * 1.4  # Outside the main bubble
	var max_arc_length = TAU / 4.0  # Each season covers up to 90° of arc
	var ring_width = 3.0

	# Get season data from node (properties added to QuantumNode)
	var projections: Array[float] = node.season_projections
	var angular_momentum: float = node.season_angular_momentum
	var phi: float = node.phi_raw

	# Rotation offset: phi drives the ring rotation so it "points" in the phase direction
	var rotation_offset = phi

	for i in range(3):
		var intensity = projections[i] if i < projections.size() else 0.33

		# Skip very weak projections
		if intensity < 0.05:
			continue

		# Arc parameters
		var base_angle = SEASON_ANGLES[i] + rotation_offset
		var arc_length = max_arc_length * intensity
		var start_angle = base_angle - arc_length / 2.0
		var end_angle = base_angle + arc_length / 2.0

		# Color with intensity-based alpha
		var ring_color = SEASON_COLORS[i]
		ring_color.a = 0.4 + 0.5 * intensity  # 0.4 to 0.9 alpha
		ring_color.a *= anim_alpha

		# Draw the arc
		graph.draw_arc(node.position, ring_radius, start_angle, end_angle, 16, ring_color, ring_width, true)

		# Draw glow for strong projections
		if intensity > 0.5:
			var glow_color = ring_color
			glow_color.a *= 0.4
			graph.draw_arc(node.position, ring_radius, start_angle, end_angle, 16, glow_color, ring_width * 2.5, true)

	# Draw angular momentum indicator (whirlpool direction)
	if absf(angular_momentum) > 0.01:
		var indicator_radius = effective_radius * 1.6
		var spin_color = Color(1.0, 1.0, 1.0, 0.3 * anim_alpha)
		var spin_length = clampf(absf(angular_momentum) * 5.0, 0.1, 0.5)

		# Arrow showing spin direction
		var arrow_angle = phi + (PI / 2.0 if angular_momentum > 0 else -PI / 2.0)
		var arrow_start = node.position + Vector2(cos(arrow_angle - spin_length), sin(arrow_angle - spin_length)) * indicator_radius
		var arrow_end = node.position + Vector2(cos(arrow_angle + spin_length), sin(arrow_angle + spin_length)) * indicator_radius
		graph.draw_line(arrow_start, arrow_end, spin_color, 2.0, true)


func _draw_berry_phase_ring(graph: Node2D, node, effective_radius: float, anim_alpha: float) -> void:
	"""Draw golden ring showing accumulated berry (geometric) phase.

	Physics: Berry phase = solid angle enclosed by Bloch sphere path
	- Computed from: dβ = -(1/2) × (1 - cos(θ)) × dφ
	- Wraps at 2π (full geometric cycle)

	Visual: Golden arc that fills clockwise as berry phase accumulates.
	Full circle = one complete geometric cycle through parameter space.
	"""
	var berry = node.berry_phase
	if berry < 0.01:
		return

	var ring_radius = effective_radius * 1.55  # Outside the season rings
	var ring_width = 2.5

	# Berry phase as fraction of full cycle [0, 1]
	var berry_fraction = berry / TAU

	# Golden color that brightens with accumulation
	var berry_color = Color(1.0, 0.85, 0.3, 0.6 + 0.3 * berry_fraction)
	berry_color.a *= anim_alpha

	# Draw arc from top, clockwise
	var start_angle = -PI / 2.0
	var end_angle = start_angle + berry * sign(node.season_angular_momentum + 0.001)

	graph.draw_arc(node.position, ring_radius, start_angle, end_angle, 24, berry_color, ring_width, true)

	# Glow for high berry phase (approaching full cycle)
	if berry_fraction > 0.5:
		var glow_color = berry_color
		glow_color.a = 0.3 * (berry_fraction - 0.5) * 2.0 * anim_alpha
		graph.draw_arc(node.position, ring_radius, start_angle, end_angle, 24, glow_color, ring_width * 3.0, true)


func _draw_emojis(graph: Node2D, node, is_celestial: bool) -> void:
	"""Draw dual emoji overlay with quantum opacity."""
	var font = ThemeDB.fallback_font
	var font_size = int(node.radius * (1.1 if is_celestial else 1.0))
	var text_pos = node.position - Vector2(font_size * 0.4, -font_size * 0.25)

	# South emoji (behind)
	if node.emoji_south != "" and node.emoji_south_opacity > 0.01:
		var south_opacity = node.emoji_south_opacity * (0.9 if is_celestial else 1.0)
		_draw_emoji_with_opacity(graph, font, text_pos, node.emoji_south, font_size, south_opacity)

	# North emoji (front)
	if node.emoji_north != "" and node.emoji_north_opacity > 0.01:
		_draw_emoji_with_opacity(graph, font, text_pos, node.emoji_north, font_size, node.emoji_north_opacity)


func _draw_emoji_with_opacity(graph: Node2D, font, text_pos: Vector2, emoji: String, font_size: int, opacity: float) -> void:
	"""Draw emoji with shadow and opacity - SVG glyph or text fallback.

	Rendering chain:
	1. Try VisualAssetRegistry.get_texture(emoji) → SVG glyph
	2. If null → fallback to emoji text

	This keeps emoji strings as source of truth while enabling
	gradual migration to custom glyphs.
	"""

	# Try SVG glyph first (safe autoload access)
	var texture: Texture2D = null
	var visual_asset_registry = graph.get_node_or_null("/root/VisualAssetRegistry")
	if visual_asset_registry and visual_asset_registry.has_method("get_texture"):
		texture = visual_asset_registry.get_texture(emoji)

	if texture:
		# Render SVG glyph
		var glyph_size = Vector2(font_size, font_size) * 1.2
		var glyph_pos = text_pos - glyph_size / 2.0
		var glyph_color = Color(1, 1, 1, opacity)

		# Shadow
		var shadow_offset = Vector2(2, 2)
		var shadow_color = Color(0, 0, 0, 0.7 * opacity)
		graph.draw_texture_rect(texture, Rect2(glyph_pos + shadow_offset, glyph_size), false, shadow_color)

		# Main glyph
		graph.draw_texture_rect(texture, Rect2(glyph_pos, glyph_size), false, glyph_color)
	else:
		# Fallback to emoji text (original code path)
		var shadow_color = Color(0, 0, 0, 0.7 * opacity)
		graph.draw_string(font, text_pos + Vector2(2, 2), emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow_color)

		var outline_color = Color(0, 0, 0, 0.5 * opacity)
		graph.draw_string(font, text_pos + Vector2(1, 1), emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, outline_color)

		var main_color = Color(1, 1, 1, opacity)
		graph.draw_string(font, text_pos, emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, main_color)


func _get_measurement_uncertainty(node, biomes: Dictionary, is_celestial: bool) -> float:
	"""Calculate measurement uncertainty for a node.

	Physics: 2 × √(p_n × p_s)
	- Maximum = 1.0 at 50/50 superposition
	- Minimum = 0.0 when collapsed to either pole

	Returns:
		Uncertainty value [0.0, 1.0]
	"""
	if is_celestial or node.biome_name == "":
		return 0.0

	var p_n = node.emoji_north_opacity
	var p_s = node.emoji_south_opacity
	var mass = p_n + p_s
	if mass < 0.001:
		return 0.0
	p_n = p_n / mass
	p_s = p_s / mass

	# Measurement uncertainty: 2 × √(p_n × p_s)
	return 2.0 * sqrt(p_n * p_s)


func _is_node_measured(node, plot_pool) -> bool:
	"""Check if node has been measured."""
	if not node:
		return false

	# Check plot-based measurement (v1)
	if node.plot != null and node.plot.has_been_measured:
		return true

	# Check terminal directly on node (v2 - preferred)
	if node.terminal and node.terminal.is_measured:
		return true

	# Fallback: lookup terminal from plot_pool by grid position
	if plot_pool and node.grid_position != Vector2i(-1, -1):
		var terminal = plot_pool.get_terminal_at_grid_pos(node.grid_position) if plot_pool.has_method("get_terminal_at_grid_pos") else null
		if terminal and terminal.is_measured:
			return true

	return false
