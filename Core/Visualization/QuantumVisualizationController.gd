class_name QuantumVisualizationController
extends Control

## Main controller for simplified quantum visualization
## Manages glyphs, edges, and detail panel with minimal UI complexity

const QuantumGlyph = preload("res://Core/Visualization/QuantumGlyph.gd")
const DetailPanel = preload("res://Core/Visualization/DetailPanel.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var glyphs: Array = []
var detail_panel = null
var selected_glyph = null

var emoji_font: Font = null
var biome = null  # Reference to the connected biome
var plot_positions: Dictionary = {}  # Vector2i (grid) → Vector2 (screen)


func _ready() -> void:
	emoji_font = load("res://Assets/Fonts/NotoColorEmoji.ttf")
	if not emoji_font:
		emoji_font = ThemeDB.fallback_font
	detail_panel = DetailPanel.new()
	mouse_filter = Control.MOUSE_FILTER_STOP


func connect_to_biome(biome_ref, plot_positions_dict: Dictionary = {}) -> void:
	"""Connect to biome and build glyphs from occupation numbers"""
	glyphs.clear()
	biome = biome_ref
	plot_positions = plot_positions_dict

	if not biome_ref:
		return

	if not biome_ref.patches:
		print("⚠️  QuantumVisualizationController: No patches in biome")
		return

	# Map trophic levels to emoji pairs
	var trophic_pairs = [
		{"north": "🌾", "south": "💧", "level": "plant"},           # Plants ↔ Water
		{"north": "🐰", "south": "🌾", "level": "herbivore"},       # Herbivores ↔ Plants
		{"north": "🐺", "south": "🦅", "level": "predator"},        # Predators ↔ Apex
		{"north": "🍄", "south": "🌍", "level": "decomposer"},      # Fungi ↔ Soil
	]

	# Create glyphs for each patch position
	for patch_pos in biome_ref.patches.keys():
		var occupation_numbers = biome_ref.get_occupation_numbers(patch_pos)

		if occupation_numbers.is_empty():
			continue

		# Create glyphs from trophic pairs
		for idx in range(min(trophic_pairs.size(), 4)):  # Limit to 4 glyphs per patch
			var pair = trophic_pairs[idx]

			# Create qubit from occupation data
			var qubit = DualEmojiQubit.new()
			qubit.north_emoji = pair.north
			qubit.south_emoji = pair.south

			# Map occupation to quantum state
			var max_occ = 10.0
			var occ_value = occupation_numbers.get(pair.level, 0.0)
			qubit.theta = (occ_value / max_occ) * PI
			qubit.phi = randf() * TAU

			# Create glyph
			var glyph = QuantumGlyph.new()
			glyph.qubit = qubit

			# Position the glyph
			if plot_positions.has(patch_pos):
				# Use provided plot position
				var base_pos = plot_positions[patch_pos]
				# Offset each trophic glyph slightly
				glyph.position = base_pos + Vector2(idx * 40 - 60, 0)
			else:
				# Fallback to simple grid positioning
				glyph.position = _grid_to_screen(patch_pos) + Vector2(idx * 40 - 60, 0)

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

	# Selection highlight (circle)
	if selected_glyph:
		var ring_color = Color(1.0, 0.8, 0.2, 0.8)
		var ring_radius = 35.0
		var ring_points = 32
		for i in range(ring_points):
			var angle1 = (i / float(ring_points)) * TAU
			var angle2 = ((i + 1) / float(ring_points)) * TAU
			var p1 = selected_glyph.position + Vector2(cos(angle1), sin(angle1)) * ring_radius
			var p2 = selected_glyph.position + Vector2(cos(angle2), sin(angle2)) * ring_radius
			draw_line(p1, p2, ring_color, 2.0)

	# Detail panel (only if selected)
	if selected_glyph:
		detail_panel.panel_position = Vector2(50, 100)
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
