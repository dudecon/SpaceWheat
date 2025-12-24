class_name DetailPanel
extends RefCounted

## Shows full quantum state info when glyph selected
## Only appears when user clicks on a glyph for inspection (not measurement)

var selected_glyph = null
var panel_position: Vector2 = Vector2.ZERO
var panel_size: Vector2 = Vector2(350, 400)


func draw(canvas: CanvasItem, glyph, font: Font) -> void:
	"""Render detail panel for selected glyph"""

	if not glyph or not glyph.qubit:
		return

	# Panel background
	var bg_color = Color(0.1, 0.1, 0.15, 0.95)
	canvas.draw_rect(Rect2(panel_position, panel_size), bg_color)

	# Panel border (draw as lines since draw_rect doesn't support colored borders in Godot 4)
	var border_color = Color(0.8, 0.8, 0.9, 0.8)
	var p = panel_position
	var sz = panel_size
	canvas.draw_line(p, p + Vector2(sz.x, 0), border_color, 2.0)
	canvas.draw_line(p, p + Vector2(0, sz.y), border_color, 2.0)
	canvas.draw_line(p + Vector2(sz.x, 0), p + sz, border_color, 2.0)
	canvas.draw_line(p + Vector2(0, sz.y), p + sz, border_color, 2.0)

	# Title
	var title = "%s (%s)" % [glyph.qubit.north_emoji, glyph.qubit.south_emoji]
	canvas.draw_string(font, panel_position + Vector2(15, 20), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	var y = 50
	var line_height = 20

	# === STATE METRICS ===
	var metrics_text = [
		"θ = %.2f rad" % glyph.qubit.theta,
		"φ = %.2f rad" % glyph.qubit.phi,
		"r = %.2f (coherence)" % glyph.qubit.get_coherence(),
		"Measured: %s" % ("Yes" if glyph.is_measured else "No"),
		"Energy: %.2f J" % glyph.qubit.energy,
	]

	for text in metrics_text:
		canvas.draw_string(font, panel_position + Vector2(15, y), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.8))
		y += line_height

	y += 10

	# === SUPERPOSITION ===
	var north_prob = pow(cos(glyph.qubit.theta / 2.0), 2.0)
	var south_prob = 1.0 - north_prob

	canvas.draw_string(font, panel_position + Vector2(15, y), "SUPERPOSITION:",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 1.0, 0.8))
	y += line_height

	# North bar
	canvas.draw_string(font, panel_position + Vector2(25, y),
		"%s %.0f%%" % [glyph.qubit.north_emoji, north_prob * 100],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	_draw_probability_bar(canvas, panel_position + Vector2(70, y - 5),
		200, north_prob, Color(0.3, 0.8, 0.3))
	y += line_height

	# South bar
	canvas.draw_string(font, panel_position + Vector2(25, y),
		"%s %.0f%%" % [glyph.qubit.south_emoji, south_prob * 100],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	_draw_probability_bar(canvas, panel_position + Vector2(70, y - 5),
		200, south_prob, Color(0.3, 0.6, 0.9))
	y += line_height * 2

	# === CONNECTIONS (if available) ===
	if glyph.qubit and glyph.qubit.entanglement_graph.size() > 0:
		canvas.draw_string(font, panel_position + Vector2(15, y), "CONNECTIONS:",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 1.0, 0.8))
		y += line_height

		for relationship in glyph.qubit.entanglement_graph.keys():
			var targets = glyph.qubit.entanglement_graph[relationship]
			var strength = glyph.qubit.get_coupling_strength(relationship)

			var conn_text = "%s → %s [%.2f]" % [relationship, targets[0], strength]
			canvas.draw_string(font, panel_position + Vector2(25, y), conn_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.9, 0.7))
			y += line_height - 2


func _draw_probability_bar(canvas: CanvasItem, pos: Vector2,
		width: float, fill: float, color: Color) -> void:
	"""Draw probability bar"""
	# Background
	canvas.draw_rect(Rect2(pos, Vector2(width, 10)),
		Color(0.2, 0.2, 0.2, 0.5))
	# Fill
	canvas.draw_rect(Rect2(pos, Vector2(width * fill, 10)), color)
