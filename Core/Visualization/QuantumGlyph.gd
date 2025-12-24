class_name QuantumGlyph
extends RefCounted

## Minimal quantum state visualization - dual emoji + phase ring only
## Full details appear only in DetailPanel when selected

var qubit = null
var position: Vector2 = Vector2.ZERO
var is_measured: bool = false

# Animation state
var time_accumulated: float = 0.0

# Visual constants
const BASE_RADIUS: float = 25.0
const EMOJI_OFFSET: float = 20.0
const RING_THICKNESS: float = 3.0


func update_from_qubit(dt: float) -> void:
	"""Sync visual state from quantum data"""
	if not qubit:
		return
	time_accumulated += dt


func draw(canvas: CanvasItem, emoji_font: Font) -> void:
	"""Render minimal glyph: just dual emoji + phase ring"""
	if not qubit:
		return

	var theta = qubit.theta
	var phi = qubit.phi
	var north_opacity = pow(cos(theta / 2.0), 2.0)
	var south_opacity = pow(sin(theta / 2.0), 2.0)

	# Measured state: snap to 0 or 1
	if is_measured:
		north_opacity = 1.0 if north_opacity > 0.5 else 0.0
		south_opacity = 1.0 - north_opacity

	# === PHASE RING (hue cycles with phi) ===
	var phase_hue = fmod((phi + PI) / TAU, 1.0)
	var ring_color = Color.from_hsv(phase_hue, 0.7, 0.85, 0.8)

	# Animate hue for unmeasured qubits
	if not is_measured:
		ring_color = Color.from_hsv(
			fmod(phase_hue + time_accumulated * 0.05, 1.0),
			0.7, 0.85, 0.8
		)

	# Draw ring as a circle outline
	var ring_points = 32
	for i in range(ring_points):
		var angle1 = (i / float(ring_points)) * TAU
		var angle2 = ((i + 1) / float(ring_points)) * TAU
		var p1 = position + Vector2(cos(angle1), sin(angle1)) * BASE_RADIUS
		var p2 = position + Vector2(cos(angle2), sin(angle2)) * BASE_RADIUS
		canvas.draw_line(p1, p2, ring_color, RING_THICKNESS)

	# === NORTH EMOJI ===
	if north_opacity > 0.05:
		var north_color = Color(1, 1, 1, north_opacity)
		canvas.draw_string(emoji_font,
			position + Vector2(0, -EMOJI_OFFSET),
			qubit.north_emoji,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 20, north_color)

	# === SOUTH EMOJI ===
	if south_opacity > 0.05:
		var south_color = Color(1, 1, 1, south_opacity)
		canvas.draw_string(emoji_font,
			position + Vector2(0, EMOJI_OFFSET),
			qubit.south_emoji,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 20, south_color)


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
