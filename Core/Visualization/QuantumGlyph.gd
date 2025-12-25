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

# Decoherence dust particles
var dust_particles: Array = []  # Array of {pos, vel, age, max_age, color}
var last_coherence: float = 1.0

# Measurement flash effect
var measurement_flash = null  # {start_time, outcome_color} or null
var MEASUREMENT_FLASH_DURATION: float = 0.3

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

	# === SPAWN DECOHERENCE DUST (when coherence drops) ===
	_update_dust_particles(dt)
	_spawn_dust_if_decohering(dt)

	# === MEASUREMENT FLASH CLEANUP ===
	if measurement_flash:
		var flash_age = time_accumulated - measurement_flash.start_time
		if flash_age > MEASUREMENT_FLASH_DURATION:
			measurement_flash = null


func draw(canvas: CanvasItem, emoji_font: Font) -> void:
	"""Render 6-layer quantum glyph visualization"""
	if not qubit:
		return

	# === LAYER 1: GLOW (energy-based) ===
	if energy > 0.1:
		var glow_color = Color(1.0, 0.9, 0.5, energy * 0.3)
		var glow_radius = BASE_RADIUS * (1.5 + energy * 0.5)
		canvas.draw_circle(position, glow_radius, glow_color)

	# === LAYER 2: THETA-BASED RGB BACKGROUND ===
	# Background color represents theta angle: Red (θ≈0) → Green (θ≈π/2) → Blue (θ≈π)
	var theta_normalized = qubit.theta / PI  # 0.0 to 1.0
	var bg_color: Color
	if theta_normalized < 0.5:
		# θ: 0→π/2, Color: Red → Green
		var t = theta_normalized * 2.0  # 0→1 in first half
		bg_color = Color(1.0 - t, t, 0.0, 0.4)  # Red to Green
	else:
		# θ: π/2→π, Color: Green → Blue
		var t = (theta_normalized - 0.5) * 2.0  # 0→1 in second half
		bg_color = Color(0.0, 1.0 - t, t, 0.4)  # Green to Blue
	canvas.draw_circle(position, BASE_RADIUS * 0.85, bg_color)

	# === LAYER 3: CORE GRADIENT CIRCLE (superposition visualization) ===
	var north_color = _get_emoji_color(qubit.north_emoji)
	var south_color = _get_emoji_color(qubit.south_emoji)
	var blend = south_opacity / (north_opacity + south_opacity + 0.001)
	var core_color = north_color.lerp(south_color, blend)
	canvas.draw_circle(position, BASE_RADIUS * 0.7, core_color)

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

	# === LAYER 6.3: MEASUREMENT FLASH (wavefunction collapse) ===
	_draw_measurement_flash(canvas)

	# === LAYER 6.5: DECOHERENCE DUST PARTICLES ===
	_draw_dust_particles(canvas)

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

	# Create measurement flash
	var flash_color = Color(0.9, 0.9, 0.95, 0.9) if outcome == "north" else Color(0.3, 0.3, 0.35, 0.9)
	measurement_flash = {
		"start_time": time_accumulated,
		"outcome_color": flash_color
	}


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


func _update_dust_particles(dt: float) -> void:
	"""Update dust particle positions and remove aged particles"""
	var to_remove = []

	for i in range(dust_particles.size()):
		var particle = dust_particles[i]
		particle.age += dt

		# Move particle outward with velocity
		particle.pos += particle.vel * dt

		# Apply drag
		particle.vel *= 0.95

		# Mark for removal if too old
		if particle.age >= particle.max_age:
			to_remove.append(i)

	# Remove aged particles (in reverse order to preserve indices)
	for i in range(to_remove.size() - 1, -1, -1):
		dust_particles.remove_at(to_remove[i])


func _spawn_dust_if_decohering(dt: float) -> void:
	"""Spawn dust particles when coherence is dropping"""
	# Only spawn if coherence is low
	if coherence < 0.6 and coherence < last_coherence:
		# Spawn 1-3 particles per frame when decohering
		var spawn_count = int((last_coherence - coherence) * 5.0)
		spawn_count = clampi(spawn_count, 1, 3)

		for _i in range(spawn_count):
			var angle = randf() * TAU
			var speed = randf() * 40.0 + 20.0  # 20-60 pixels/sec
			var vel = Vector2(cos(angle), sin(angle)) * speed

			# Dust color is reddish (indicating decoherence)
			var dust_color = Color(1.0, 0.4 + randf() * 0.3, 0.3, 0.8)

			dust_particles.append({
				"pos": Vector2(position.x, position.y),
				"vel": vel,
				"age": 0.0,
				"max_age": 0.5 + randf() * 0.5,  # 0.5-1.0 seconds
				"color": dust_color,
				"size": 2.0 + randf() * 2.0  # 2-4 pixel radius
			})

	last_coherence = coherence


func _draw_measurement_flash(canvas: CanvasItem) -> void:
	"""Render measurement collapse flash"""
	if not measurement_flash:
		return

	var flash_age = time_accumulated - measurement_flash.start_time
	var progress = flash_age / MEASUREMENT_FLASH_DURATION  # 0.0 to 1.0
	var alpha = (1.0 - progress) * 0.6  # Fade out

	# Expand outward
	var flash_radius = BASE_RADIUS + progress * 50.0  # Expands from core to 75px away
	var flash_color = measurement_flash.outcome_color
	flash_color.a = alpha

	# Draw expanding rings
	canvas.draw_circle(position, flash_radius, flash_color)


func _draw_dust_particles(canvas: CanvasItem) -> void:
	"""Render decoherence dust particles"""
	for particle in dust_particles:
		# Fade out as particle ages
		var alpha = 1.0 - (particle.age / particle.max_age)
		var color = particle.color
		color.a = alpha * 0.8

		# Draw as small circle
		canvas.draw_circle(particle.pos, particle.size, color)
