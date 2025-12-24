class_name QuantumGlyph
extends RefCounted

## Enhanced quantum state visualization with 6-layer glyph system
## Displays: glow, core gradient, phase ring, emojis, berry bar, pulse

var qubit = null
var position: Vector2 = Vector2.ZERO
var is_measured: bool = false

# Cached visual state (updated each frame)
var north_opacity: float = 0.5
var south_opacity: float = 0.5
var phase_hue: float = 0.0
var coherence: float = 1.0
var energy: float = 0.3
var berry_phase: float = 0.0
var pulse_rate: float = 1.0
var pulse_phase: float = 0.0

# Animation state
var time_accumulated: float = 0.0

# Visual constants
const BASE_RADIUS: float = 25.0
const EMOJI_OFFSET: float = 25.0
const RING_THICKNESS: float = 3.0
const RING_MAX_THICKNESS: float = 8.0
const BERRY_BAR_WIDTH: float = 50.0
const BERRY_BAR_HEIGHT: float = 6.0


func update_from_qubit(dt: float) -> void:
	"""Sync visual state from quantum data"""
	if not qubit:
		return

	time_accumulated += dt

	# === EMOJI OPACITY (Born rule: cos²(θ/2) and sin²(θ/2)) ===
	var theta = qubit.theta
	north_opacity = pow(cos(theta / 2.0), 2.0)
	south_opacity = pow(sin(theta / 2.0), 2.0)

	# Measured states snap to 0 or 1
	if is_measured:
		if north_opacity > 0.5:
			north_opacity = 1.0
			south_opacity = 0.0
		else:
			north_opacity = 0.0
			south_opacity = 1.0

	# Low coherence: add flicker to opacities
	coherence = _get_coherence()
	if coherence < 0.6 and not is_measured:
		var flicker = sin(time_accumulated * (1.0 - coherence) * 8.0) * 0.15
		north_opacity = clamp(north_opacity + flicker, 0.0, 1.0)
		south_opacity = clamp(south_opacity - flicker, 0.0, 1.0)

	# === PHASE HUE (azimuthal angle φ) ===
	var phi = qubit.phi
	phase_hue = fmod((phi + PI) / TAU, 1.0)

	# === RING THICKNESS (based on coherence) ===
	# Thicker ring = more coherent
	var ring_scale = coherence

	# === ENERGY (glow intensity) ===
	energy = qubit.energy if qubit.has_method("get_energy") or "energy" in qubit else 0.3

	# === BERRY PHASE (accumulated evolution) ===
	berry_phase = qubit.berry_phase if qubit.has_meta("berry_phase") or "berry_phase" in qubit else time_accumulated * 0.1

	# === PULSE RATE (decoherence threat indicator) ===
	# Faster pulse = more incoherent
	pulse_rate = 0.2 + (1.0 - coherence) * 1.8  # 0.2 Hz (stable) to 2.0 Hz (chaotic)
	pulse_phase = sin(time_accumulated * pulse_rate * TAU) * 0.5 + 0.5


func draw(canvas: CanvasItem, emoji_font: Font) -> void:
	"""Render 6-layer quantum glyph visualization"""
	if not qubit:
		return

	# === LAYER 1: GLOW (energy-based) ===
	if energy > 0.1:
		var glow_color = Color(1.0, 0.9, 0.5, energy * 0.3)
		var glow_radius = BASE_RADIUS * (1.5 + energy * 0.5)
		canvas.draw_circle(position, glow_radius, glow_color)

	# === LAYER 2: CORE GRADIENT CIRCLE (superposition visualization) ===
	var north_color = _get_emoji_color(qubit.north_emoji)
	var south_color = _get_emoji_color(qubit.south_emoji)
	var blend = south_opacity / (north_opacity + south_opacity + 0.001)
	var core_color = north_color.lerp(south_color, blend)
	canvas.draw_circle(position, BASE_RADIUS * 0.7, core_color)

	# === LAYER 3: PHASE RING (coherence-weighted thickness) ===
	var ring_color = Color.from_hsv(phase_hue, 0.8, 0.9, 0.9)

	# Animate hue for unmeasured qubits
	if not is_measured:
		ring_color = Color.from_hsv(
			fmod(phase_hue + time_accumulated * 0.05, 1.0),
			0.8, 0.9, 0.9
		)

	# Draw ring with coherence-based thickness
	var ring_thickness_scaled = RING_THICKNESS + coherence * (RING_MAX_THICKNESS - RING_THICKNESS)
	var ring_points = 32
	for i in range(ring_points):
		var angle1 = (i / float(ring_points)) * TAU
		var angle2 = ((i + 1) / float(ring_points)) * TAU
		var p1 = position + Vector2(cos(angle1), sin(angle1)) * BASE_RADIUS
		var p2 = position + Vector2(cos(angle2), sin(angle2)) * BASE_RADIUS
		canvas.draw_line(p1, p2, ring_color, ring_thickness_scaled)

	# === LAYER 4: NORTH EMOJI ===
	if north_opacity > 0.05:
		# Add flicker effect for low coherence
		var north_display_opacity = north_opacity
		if coherence < 0.6 and not is_measured:
			north_display_opacity *= (0.5 + pulse_phase * 0.5)

		var north_color_display = Color(1, 1, 1, north_display_opacity)
		canvas.draw_string(emoji_font,
			position + Vector2(0, -EMOJI_OFFSET),
			qubit.north_emoji,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 24, north_color_display)

	# === LAYER 5: SOUTH EMOJI ===
	if south_opacity > 0.05:
		# Add flicker effect for low coherence
		var south_display_opacity = south_opacity
		if coherence < 0.6 and not is_measured:
			south_display_opacity *= (0.5 + pulse_phase * 0.5)

		var south_color_display = Color(1, 1, 1, south_display_opacity)
		canvas.draw_string(emoji_font,
			position + Vector2(0, EMOJI_OFFSET),
			qubit.south_emoji,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 24, south_color_display)

	# === LAYER 6: BERRY PHASE BAR (accumulated evolution) ===
	var bar_pos = position + Vector2(-BERRY_BAR_WIDTH / 2.0, BASE_RADIUS + 15)
	_draw_berry_bar(canvas, bar_pos)

	# === LAYER 7: PULSE OVERLAY (decoherence warning) ===
	if pulse_rate > 0.5 and not is_measured:
		var pulse_alpha = pulse_phase * 0.2 * (pulse_rate / 2.0)
		var pulse_color = Color(1.0, 0.3, 0.3, pulse_alpha)
		canvas.draw_circle(position, BASE_RADIUS * 1.1, pulse_color)


func apply_measurement(outcome: String) -> void:
	"""Apply measurement result - collapse wavefunction"""
	is_measured = true

	# Collapse to outcome
	if outcome == "north":
		qubit.theta = 0.0  # Snap to north pole
	else:
		qubit.theta = PI   # Snap to south pole

	# Could emit particle effect here
	# particles.spawn_measurement_flash(position, outcome_color)


func _get_coherence() -> float:
	"""Get coherence level from qubit (default 1.0 if not available)"""
	if qubit.has_method("get_coherence"):
		return qubit.get_coherence()
	# Fallback: estimate from energy or use default
	if "coherence_time_T2" in qubit:
		return clamp(1.0 - qubit.get("coherence_time_T2", 50.0) / 100.0, 0.0, 1.0)
	return 0.8  # Default reasonable coherence


func _draw_berry_bar(canvas: CanvasItem, pos: Vector2) -> void:
	"""Draw berry phase accumulation bar"""
	# Background
	canvas.draw_rect(Rect2(pos, Vector2(BERRY_BAR_WIDTH, BERRY_BAR_HEIGHT)),
		Color(0.2, 0.2, 0.2, 0.5))

	# Fill (normalized berry phase)
	var max_berry = 10.0  # Cap for visualization
	var normalized_berry = clamp(berry_phase / max_berry, 0.0, 1.0)
	var fill_width = BERRY_BAR_WIDTH * normalized_berry
	var fill_color = Color(0.3, 0.8, 0.3, 0.8)  # Green for accumulated experience
	canvas.draw_rect(Rect2(pos, Vector2(fill_width, BERRY_BAR_HEIGHT)), fill_color)


func _get_emoji_color(emoji: String) -> Color:
	"""Map emoji to representative color for core gradient"""
	match emoji:
		"🌾", "🌿", "🌱": return Color(0.6, 0.8, 0.3)  # Green-gold (plants)
		"☀️": return Color(1.0, 0.9, 0.3)  # Bright yellow
		"🌙": return Color(0.3, 0.3, 0.6)  # Deep blue-purple
		"💧": return Color(0.3, 0.6, 0.9)  # Blue (water)
		"🍄", "🍵": return Color(0.6, 0.4, 0.7)  # Purple (fungi)
		"🐰", "🐺", "🦅": return Color(0.8, 0.6, 0.4)  # Warm brown (animals)
		"🍴": return Color(0.8, 0.4, 0.4)  # Red (predation)
		"🌍": return Color(0.4, 0.6, 0.5)  # Earth tone
		_: return Color(0.7, 0.7, 0.7)  # Default gray
