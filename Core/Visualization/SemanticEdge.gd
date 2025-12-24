class_name SemanticEdge
extends RefCounted

## Renders relationship between two quantum nodes with semantic meaning
## Edges visualize entanglement and coupling between organisms

# Connection
var from_glyph = null
var to_glyph = null
var relationship_emoji: String = ""
var coupling_strength: float = 0.0

# Animation state
var current_interaction: float = 0.0  # √(Nᵢ × Nⱼ)
var particles: Array = []  # Array[Dictionary] with {progress: float, speed: float}
var time_accumulated: float = 0.0

# Visual constants
const BASE_WIDTH: float = 2.0
const MAX_WIDTH: float = 12.0
const PARTICLE_SPEED: float = 100.0  # pixels per second
const MAX_PARTICLES: int = 8


func update(dt: float, from_qubit, to_qubit) -> void:
	"""Update edge state from quantum data"""
	time_accumulated += dt

	# Calculate current interaction strength
	if from_qubit and to_qubit:
		var from_energy = from_qubit.energy if "energy" in from_qubit else 0.3
		var to_energy = to_qubit.energy if "energy" in to_qubit else 0.3
		current_interaction = sqrt(from_energy * to_energy)

	# Spawn particles based on interaction strength
	if current_interaction > 0.1 and particles.size() < MAX_PARTICLES:
		if randf() < current_interaction * dt * 5.0:
			particles.append({
				"progress": 0.0,
				"speed": PARTICLE_SPEED * (0.8 + randf() * 0.4)
			})

	# Update existing particles
	var new_particles: Array = []
	for p in particles:
		var edge_length = _get_edge_length()
		if edge_length > 0:
			p.progress += p.speed * dt / edge_length
		if p.progress < 1.0:
			new_particles.append(p)
	particles = new_particles


func draw(canvas: CanvasItem, font: Font) -> void:
	"""Render the edge"""
	if not from_glyph or not to_glyph:
		return

	var from_pos = from_glyph.position
	var to_pos = to_glyph.position
	var midpoint = (from_pos + to_pos) / 2.0
	var direction = (to_pos - from_pos).normalized()

	# === EDGE LINE ===
	var edge_width = BASE_WIDTH + coupling_strength * (MAX_WIDTH - BASE_WIDTH)
	var edge_color = _get_relationship_color()

	# Modulate alpha by interaction strength
	edge_color.a = 0.3 + current_interaction * 0.7

	# Draw main line
	canvas.draw_line(from_pos, to_pos, edge_color, edge_width)

	# Draw glow for active edges
	if current_interaction > 0.3:
		var glow_color = edge_color
		glow_color.a = current_interaction * 0.2
		canvas.draw_line(from_pos, to_pos, glow_color, edge_width * 2.5)

	# === RELATIONSHIP EMOJI (at midpoint) ===
	var emoji_bg_color = Color(0, 0, 0, 0.7)
	canvas.draw_circle(midpoint, 12, emoji_bg_color)
	canvas.draw_string(font, midpoint + Vector2(-8, 6), relationship_emoji,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	# === DIRECTIONAL ARROW (for asymmetric relationships) ===
	if _is_directional():
		_draw_arrow(canvas, to_pos - direction * 35, direction, edge_color)

	# === FLOW PARTICLES ===
	for p in particles:
		var particle_pos = from_pos.lerp(to_pos, p.progress)
		var particle_color = edge_color
		particle_color.a = 1.0 - abs(p.progress - 0.5) * 2.0  # Fade at ends
		canvas.draw_circle(particle_pos, 3.0, particle_color)


func _get_relationship_color() -> Color:
	"""Get color based on relationship type"""
	match relationship_emoji:
		"🍴": return Color(0.9, 0.3, 0.2)   # Red (predation)
		"🃏": return Color(0.9, 0.6, 0.2)   # Orange (escape)
		"🌱": return Color(0.3, 0.8, 0.3)   # Green (consumption/feeding)
		"💧": return Color(0.3, 0.6, 0.9)   # Blue (production)
		"🔄": return Color(0.7, 0.4, 0.9)   # Purple (transformation)
		"⚡": return Color(1.0, 0.95, 0.5)  # Yellow (coherence)
		"👶": return Color(0.95, 0.6, 0.8)  # Pink (reproduction)
		_: return Color(0.7, 0.7, 0.7)      # Gray (unknown)


func _is_directional() -> bool:
	"""Check if relationship is asymmetric (needs arrow)"""
	return relationship_emoji in ["🍴", "🌱", "💧", "👶"]


func _draw_arrow(canvas: CanvasItem, tip: Vector2, direction: Vector2, color: Color) -> void:
	"""Draw arrowhead at tip pointing in direction"""
	var arrow_size = 8.0
	var perpendicular = Vector2(-direction.y, direction.x)
	var base_left = tip - direction * arrow_size + perpendicular * arrow_size * 0.5
	var base_right = tip - direction * arrow_size - perpendicular * arrow_size * 0.5
	canvas.draw_polygon([tip, base_left, base_right], [color])


func _get_edge_length() -> float:
	"""Get pixel length of edge"""
	if from_glyph and to_glyph:
		return from_glyph.position.distance_to(to_glyph.position)
	return 100.0
