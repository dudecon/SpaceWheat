extends Node

## Test of QuantumGlyph visualization with ForestEcosystem_Biome_v3
## Shows visualization driven by real Hamiltonian quantum evolution

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const QuantumGlyph = preload("res://Core/Visualization/QuantumGlyph.gd")
const DetailPanel = preload("res://Core/Visualization/DetailPanel.gd")
const ForestBiome = preload("res://Core/Environment/ForestEcosystem_Biome_v3_quantum_field.gd")

var glyphs: Array = []
var selected_glyph = null
var canvas: Control = null
var detail_panel = null
var emoji_font: Font = null
var time_elapsed: float = 0.0
var forest_biome = null


func _ready() -> void:
	print("\n=======================================================================")
	print("QUANTUM GLYPH TEST - Driven by ForestEcosystem_Biome_v3 Physics")
	print("=======================================================================\n")

	# Load font (optional - will use system font if not found)
	emoji_font = load("res://Assets/Fonts/NotoColorEmoji.ttf")
	if not emoji_font:
		print("⚠️  NotoColorEmoji font not found - using system font")
		emoji_font = ThemeDB.fallback_font

	# Create detail panel
	detail_panel = DetailPanel.new()

	# Initialize ForestEcosystem_Biome_v3 for real quantum physics FIRST
	print("\n🌲 Initializing ForestEcosystem_Biome_v3...")
	forest_biome = ForestBiome.new()
	add_child(forest_biome)

	print("   ✓ Biome created")
	print("   ✓ Quantum states: %d trophic levels" % forest_biome.quantum_states.size())

	# Create test canvas
	canvas = Control.new()
	canvas.anchor_left = 0.0
	canvas.anchor_top = 0.0
	canvas.anchor_right = 1.0
	canvas.anchor_bottom = 1.0
	canvas.offset_left = 0
	canvas.offset_top = 0
	canvas.offset_right = 0
	canvas.offset_bottom = 0
	add_child(canvas)
	print("   ✓ Canvas created and added")

	# Create glyphs from biome's occupation numbers
	# Map trophic levels to emoji pairs
	var trophic_pairs = [
		{"north": "🌾", "south": "💧", "level": "plant"},           # Plants ↔ Water
		{"north": "🐰", "south": "🌾", "level": "herbivore"},       # Herbivores ↔ Plants
		{"north": "🐺", "south": "🦅", "level": "predator"},        # Predators ↔ Apex
		{"north": "🍄", "south": "🌍", "level": "decomposer"},      # Fungi ↔ Soil
	]

	var positions = [
		Vector2(300, 200),
		Vector2(900, 200),
		Vector2(300, 600),
		Vector2(900, 600),
	]

	# Create glyphs from first position's occupation numbers
	if forest_biome.patches.size() > 0:
		var first_patch_pos = forest_biome.patches.keys()[0]
		var occupation_numbers = forest_biome.get_occupation_numbers(first_patch_pos)

		print("   🌍 Occupation numbers at %s:" % first_patch_pos)
		for level in occupation_numbers.keys():
			print("      %s: %.2f" % [level, occupation_numbers[level]])

		for idx in range(min(trophic_pairs.size(), positions.size())):
			var pair = trophic_pairs[idx]
			var qubit = DualEmojiQubit.new()
			qubit.north_emoji = pair.north
			qubit.south_emoji = pair.south

			# Map occupation number to quantum state
			# Use occupation as theta (0 = north pole, PI = south pole)
			var max_occ = 10.0  # Normalize to this max value
			var occ_value = occupation_numbers.get(pair.level, 0.0)
			qubit.theta = (occ_value / max_occ) * PI  # Map [0, 10] → [0, π]
			qubit.phi = randf() * TAU  # Random phase

			var glyph = QuantumGlyph.new()
			glyph.qubit = qubit
			glyph.position = positions[idx]
			glyphs.append(glyph)

			print("   [%d] %s ↔ %s (θ=%.2f) at (%.0f, %.0f)" % [
				idx+1, pair.north, pair.south,
				qubit.theta,
				positions[idx].x, positions[idx].y
			])

	# Setup canvas
	print("   ✓ Connecting draw signal...")
	canvas.draw.connect(_on_canvas_draw)
	print("   ✓ Draw signal connected")

	canvas.gui_input.connect(_on_canvas_input)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.queue_redraw()
	print("   ✓ Canvas configured and queued for redraw")


	print("\n✅ Test initialized with %d quantum glyphs from biome:\n" % glyphs.size())
	for i in range(glyphs.size()):
		var g = glyphs[i]
		var glyph_idx = i + 1
		var x = int(g.position.x)
		var y = int(g.position.y)
		print("   %d. %s %s at (%d, %d)" % [glyph_idx, g.qubit.north_emoji, g.qubit.south_emoji, x, y])

	print("\n🎮 CONTROLS:")
	print("   • Click on any glyph to see details")
	print("   • Watch emoji fade in/out (superposition)")
	print("   • Watch phase ring rotate (quantum phase)")
	print("\n✨ Watch the console below for real-time state\n")


func _process(delta: float) -> void:
	# Update all glyphs (animation only for now)
	for glyph in glyphs:
		glyph.update_from_qubit(delta)

	time_elapsed += delta
	canvas.queue_redraw()


func _on_canvas_draw() -> void:
	"""Render everything"""
	if canvas == null:
		print("ERROR: Canvas is null in _on_canvas_draw!")
		return

	if emoji_font == null:
		print("WARNING: emoji_font is null, using fallback")

	# Dark background
	var bg_rect = Rect2(Vector2.ZERO, canvas.get_rect().size)
	canvas.draw_rect(bg_rect, Color(0.05, 0.05, 0.12))

	# Title
	canvas.draw_string(emoji_font, Vector2(50, 40),
		"Quantum Glyphs Driven by ForestEcosystem_Biome_v3 Hamiltonian Physics",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.7, 0.9))

	# Instructions
	canvas.draw_string(emoji_font, Vector2(50, 70),
		"Click any glyph to inspect | Watch emoji and ring animation",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.5, 0.7))

	# Draw all glyphs
	for glyph in glyphs:
		glyph.draw(canvas, emoji_font)

	# Draw selection highlight
	if selected_glyph:
		var ring_color = Color(1.0, 0.8, 0.2, 0.8)
		var ring_radius = 40.0
		var ring_points = 32
		for i in range(ring_points):
			var angle1 = (i / float(ring_points)) * TAU
			var angle2 = ((i + 1) / float(ring_points)) * TAU
			var p1 = selected_glyph.position + Vector2(cos(angle1), sin(angle1)) * ring_radius
			var p2 = selected_glyph.position + Vector2(cos(angle2), sin(angle2)) * ring_radius
			canvas.draw_line(p1, p2, ring_color, 2.5)

	# Draw detail panel if selected
	if selected_glyph:
		detail_panel.panel_position = Vector2(50, 150)
		detail_panel.draw(canvas, selected_glyph, emoji_font)

		# Draw selection info
		var info = "🔍 Selected: %s %s" % [
			selected_glyph.qubit.north_emoji,
			selected_glyph.qubit.south_emoji
		]
		canvas.draw_string(emoji_font, Vector2(50, 130), info,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 1.0, 0.8))


func _on_canvas_input(event: InputEvent) -> void:
	"""Handle click selection"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var clicked = _find_glyph_at(event.position)
			if clicked:
				selected_glyph = clicked
				print("Selected glyph: %s %s" % [
					clicked.qubit.north_emoji,
					clicked.qubit.south_emoji
				])
				var theta_deg = clicked.qubit.theta * 180.0 / PI
				var phi_deg = clicked.qubit.phi * 180.0 / PI
				print("theta = %.2f rad (%.1f deg)" % [clicked.qubit.theta, theta_deg])
				print("phi = %.2f rad (%.1f deg)" % [clicked.qubit.phi, phi_deg])
			else:
				selected_glyph = null
				print("\n❌ Deselected")

			canvas.queue_redraw()


func _find_glyph_at(pos: Vector2) -> QuantumGlyph:
	"""Find glyph at screen position"""
	for glyph in glyphs:
		if pos.distance_to(glyph.position) < 35:
			return glyph
	return null
