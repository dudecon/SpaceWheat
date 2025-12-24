class_name QuantumVisualizationController
extends Control

## Main controller for simplified quantum visualization
## Manages glyphs, edges, and detail panel with minimal UI complexity

var glyphs: Array = []
var detail_panel = null
var selected_glyph = null

var emoji_font: Font = null


func _ready() -> void:
	emoji_font = load("res://Assets/Fonts/NotoColorEmoji.ttf")
	detail_panel = DetailPanel.new()
	mouse_filter = Control.MOUSE_FILTER_STOP


func connect_to_biome(biome_ref) -> void:
	"""Connect to biome and build glyphs from quantum states"""
	glyphs.clear()

	if not biome_ref:
		return

	# Create glyph for each quantum state
	for position_key in biome_ref.quantum_states.keys():
		var qubit = biome_ref.quantum_states[position_key]
		if not qubit:
			continue

		var glyph = QuantumGlyph.new()
		glyph.qubit = qubit
		glyph.position = _grid_to_screen(position_key)

		# Check if measured
		if biome_ref.grid:
			var plot = biome_ref.grid.get_plot(position_key)
			if plot:
				glyph.is_measured = plot.has_been_measured

		glyphs.append(glyph)


func _process(delta: float) -> void:
	"""Update glyphs each frame"""
	for glyph in glyphs:
		glyph.update_from_qubit(delta)

	queue_redraw()


func _draw() -> void:
	"""Render all glyphs and optional detail panel"""

	# Draw glyphs
	for glyph in glyphs:
		glyph.draw(self, emoji_font)

	# Selection highlight
	if selected_glyph:
		draw_arc(selected_glyph.position, 35, 0, TAU, 32,
			Color(1.0, 0.8, 0.2, 0.8), 2.0)

	# Detail panel (only if selected)
	if selected_glyph:
		detail_panel.draw(self, selected_glyph, emoji_font)


func _input(event: InputEvent) -> void:
	"""Handle mouse click for glyph selection"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var clicked = _get_glyph_at(event.position)
			selected_glyph = clicked
			queue_redraw()
			get_tree().root.set_input_as_handled()


func _get_glyph_at(pos: Vector2) -> QuantumGlyph:
	"""Find glyph at screen position"""
	for glyph in glyphs:
		if pos.distance_to(glyph.position) < 30:
			return glyph
	return null


func _grid_to_screen(grid_pos: Vector2i) -> Vector2:
	"""Convert grid position to screen coordinates"""
	var center = get_viewport_rect().size / 2.0
	var spacing = 100.0
	return center + Vector2(grid_pos.x * spacing, grid_pos.y * spacing)


func apply_measurement(grid_pos: Vector2i, outcome: String) -> void:
	"""Apply measurement result to a specific glyph (game mechanic, separate from selection)"""
	for glyph in glyphs:
		# Match glyph position to grid position
		if _screen_to_grid(glyph.position) == grid_pos:
			glyph.apply_measurement(outcome)
			return


func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	"""Convert screen position back to grid coordinates"""
	var center = get_viewport_rect().size / 2.0
	var spacing = 100.0
	var relative = screen_pos - center
	return Vector2i(
		int(round(relative.x / spacing)),
		int(round(relative.y / spacing))
	)


func deselect() -> void:
	"""Clear selection"""
	selected_glyph = null
	queue_redraw()
