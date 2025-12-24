class_name QuantumGlyphTest
extends Node

## Test scene for simplified quantum glyph visualization
## Tests: minimal emoji rendering + phase ring + detail panel on selection

var glyphs: Array[QuantumGlyph] = []
var selected_glyph: QuantumGlyph = null
var emoji_font: Font = null
var detail_panel: DetailPanel = null
var test_canvas: Control = null


func _ready() -> void:
	print("=== Quantum Glyph Test ===")

	# Load emoji font
	emoji_font = load("res://Assets/Fonts/NotoColorEmoji.ttf")
	if not emoji_font:
		print("❌ ERROR: NotoColorEmoji font not found")
		return

	# Create detail panel
	detail_panel = DetailPanel.new()

	# Create test canvas
	test_canvas = Control.new()
	test_canvas.size = Vector2(1024, 768)
	test_canvas.custom_minimum_size = Vector2(1024, 768)
	add_child(test_canvas)

	# Create test qubits (4 sample quantum states)
	var test_qubits = [
		_create_test_qubit("🌾", "💧", 0.5, 0.0),   # Wheat-Water superposition
		_create_test_qubit("🐰", "🌾", 1.0, PI/4),  # Herbivore-Plant entanglement
		_create_test_qubit("🐺", "🦅", PI/2, PI/2), # Predator-Predator interaction
		_create_test_qubit("🍄", "🌍", 1.5, PI),    # Fungi-Soil relationship
	]

	# Create glyphs and position them
	var positions = [
		Vector2(200, 150),
		Vector2(800, 150),
		Vector2(200, 600),
		Vector2(800, 600),
	]

	for i in range(test_qubits.size()):
		var glyph = QuantumGlyph.new()
		glyph.qubit = test_qubits[i]
		glyph.position = positions[i]
		glyphs.append(glyph)

	# Connect draw
	test_canvas.draw.connect(_on_canvas_draw)
	test_canvas.gui_input.connect(_on_canvas_input)
	test_canvas.mouse_filter = Control.MOUSE_FILTER_STOP

	print("✅ Test scene created with 4 glyphs")
	print("   1. 🌾💧 - Superposition (theta=0.5)")
	print("   2. 🐰🌾 - Entanglement (theta=1.0)")
	print("   3. 🐺🦅 - Predator interaction (theta=π/2)")
	print("   4. 🍄🌍 - Soil-fungi (theta=1.5)")
	print("")
	print("✨ FEATURES:")
	print("   ✓ Minimal glyph: dual emoji + phase ring")
	print("   ✓ Real-time animation (phase ring hue rotation)")
	print("   ✓ Superposition opacity (birth of quantum visualization)")
	print("   ✓ Detail panel on selection (measurement separate from inspection)")
	print("")


func _process(delta: float) -> void:
	# Update glyphs
	for glyph in glyphs:
		glyph.update_from_qubit(delta)

	test_canvas.queue_redraw()


func _on_canvas_draw() -> void:
	"""Render all glyphs"""
	# Background
	test_canvas.draw_rect(Rect2(Vector2.ZERO, test_canvas.size), Color(0.05, 0.05, 0.1))

	# Draw all glyphs
	for glyph in glyphs:
		glyph.draw(test_canvas, emoji_font)

	# Draw selection highlight
	if selected_glyph:
		test_canvas.draw_arc(selected_glyph.position, 35, 0, TAU, 32,
			Color(1.0, 0.8, 0.2, 0.8), 2.0)

	# Draw detail panel if selected
	if selected_glyph:
		detail_panel.panel_position = Vector2(50, 50)
		detail_panel.draw(test_canvas, selected_glyph, emoji_font)

	# Draw info text
	var info_text = "Click on any glyph to see details | Currently selected: %s" % (
		"[%s %s]" % [selected_glyph.qubit.north_emoji, selected_glyph.qubit.south_emoji] if selected_glyph else "None"
	)
	test_canvas.draw_string(emoji_font, Vector2(50, 20), info_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.7, 0.7))


func _on_canvas_input(event: InputEvent) -> void:
	"""Handle mouse click for selection"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			selected_glyph = _get_glyph_at(event.position)
			test_canvas.queue_redraw()


func _get_glyph_at(pos: Vector2) -> QuantumGlyph:
	"""Find glyph at position"""
	for glyph in glyphs:
		if pos.distance_to(glyph.position) < 30:
			return glyph
	return null


func _create_test_qubit(north_emoji: String, south_emoji: String, theta: float, phi: float) -> DualEmojiQubit:
	"""Create a test quantum state"""
	var qubit = DualEmojiQubit.new()
	qubit.theta = theta
	qubit.phi = phi
	qubit.north_emoji = north_emoji
	qubit.south_emoji = south_emoji
	qubit.energy = randf_range(0.3, 0.9)
	return qubit


