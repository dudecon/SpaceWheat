class_name QuantumVisualizationController
extends Control

## Main controller for simplified quantum visualization
## Manages glyphs, edges, and detail panel with minimal UI complexity

const QuantumGlyph = preload("res://Core/Visualization/QuantumGlyph.gd")
const DetailPanel = preload("res://Core/Visualization/DetailPanel.gd")
const SemanticEdge = preload("res://Core/Visualization/SemanticEdge.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var glyphs: Array = []
var edges: Array = []  # SemanticEdge connections
var detail_panel = null
var selected_glyph = null

var emoji_font: Font = null
var biome = null  # Reference to the connected biome
var plot_positions: Dictionary = {}  # Vector2i (grid) → Vector2 (screen)
var glyph_map: Dictionary = {}  # Qubit → Glyph for edge lookup


func _ready() -> void:
	# Try to load emoji font, but use fallback if it doesn't exist
	var font_path = "res://Assets/Fonts/NotoColorEmoji.ttf"
	if ResourceLoader.exists(font_path):
		emoji_font = load(font_path)
	else:
		emoji_font = ThemeDB.fallback_font

	if not emoji_font:
		emoji_font = ThemeDB.fallback_font

	detail_panel = DetailPanel.new()
	mouse_filter = Control.MOUSE_FILTER_STOP


func connect_to_biome_simple(biome_ref, plot_positions_dict: Dictionary = {}) -> void:
	"""Simplified version: Create glyphs directly from BioticFlux qubits"""
	glyphs.clear()
	biome = biome_ref
	plot_positions = plot_positions_dict

	if not biome_ref or not ("quantum_states" in biome_ref):
		print("⚠️  QuantumVisualizationController: No quantum_states in biome")
		return

	# Create one glyph per qubit
	for pos in biome_ref.quantum_states.keys():
		var qubit = biome_ref.quantum_states[pos]
		if not qubit:
			continue

		var glyph = QuantumGlyph.new()
		glyph.qubit = qubit

		if plot_positions.has(pos):
			glyph.position = plot_positions[pos]
		else:
			glyph.position = _grid_to_screen(pos)

		glyphs.append(glyph)
		glyph_map[qubit] = glyph

	_build_edges()


func connect_to_biome(biome_ref, plot_positions_dict: Dictionary = {}) -> void:
	"""Connect to biome and build glyphs from occupation numbers"""
	glyphs.clear()
	biome = biome_ref
	plot_positions = plot_positions_dict

	if not biome_ref:
		return

	# Handle both ForestEcosystem (patches) and BioticFlux (quantum_states) biomes
	var qubit_positions = []
	if biome_ref.has_method("get_occupation_numbers") and biome_ref.has_meta("patches"):
		# ForestEcosystem style with patches
		if not biome_ref.patches:
			print("⚠️  QuantumVisualizationController: No patches in biome")
			return
		qubit_positions = biome_ref.patches.keys()
	elif "quantum_states" in biome_ref:
		# BioticFlux style with quantum_states
		qubit_positions = biome_ref.quantum_states.keys()
	else:
		print("⚠️  QuantumVisualizationController: Biome has no patches or quantum_states")
		return

	# Map trophic levels to emoji pairs
	var trophic_pairs = [
		{"north": "🌾", "south": "💧", "level": "plant"},           # Plants ↔ Water
		{"north": "🐰", "south": "🌾", "level": "herbivore"},       # Herbivores ↔ Plants
		{"north": "🐺", "south": "🦅", "level": "predator"},        # Predators ↔ Apex
		{"north": "🍄", "south": "🌍", "level": "decomposer"},      # Fungi ↔ Soil
	]

	# Create glyphs for each qubit position
	for patch_pos in qubit_positions:
		# Get qubit directly for BioticFlux, or occupation numbers for ForestEcosystem
		var qubit = null
		if "quantum_states" in biome_ref:
			qubit = biome_ref.quantum_states.get(patch_pos)
		else:
			# ForestEcosystem - need to extract from occupation numbers
			var occupation_numbers = biome_ref.get_occupation_numbers(patch_pos)
			if occupation_numbers.is_empty():
				continue

		if not qubit and ("quantum_states" in biome_ref):
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
			# Map qubit to glyph for edge lookup
			glyph_map[qubit] = glyph

	# Build semantic edges from entanglement relationships
	_build_edges()


func _process(delta: float) -> void:
	"""Update glyphs from evolved biome state each frame"""
	if not biome or glyphs.is_empty():
		return

	# Rebuild glyphs from current biome occupation numbers
	# Map trophic levels to emoji pairs (must match connect_to_biome)
	var trophic_pairs = [
		{"north": "🌾", "south": "💧", "level": "plant"},
		{"north": "🐰", "south": "🌾", "level": "herbivore"},
		{"north": "🐺", "south": "🦅", "level": "predator"},
		{"north": "🍄", "south": "🌍", "level": "decomposer"},
	]

	var glyph_idx = 0
	for patch_pos in biome.patches.keys():
		var occupation_numbers = biome.get_occupation_numbers(patch_pos)

		if occupation_numbers.is_empty():
			continue

		# Update each trophic glyph
		for trophic_idx in range(min(trophic_pairs.size(), 4)):
			if glyph_idx >= glyphs.size():
				break

			var pair = trophic_pairs[trophic_idx]
			var glyph = glyphs[glyph_idx]

			# Update qubit state from current occupation
			var max_occ = 10.0
			var occ_value = occupation_numbers.get(pair.level, 0.0)
			var new_theta = (occ_value / max_occ) * PI
			var new_phi = (biome.get_energy_conservation_check(patch_pos) * TAU) if biome.has_method("get_energy_conservation_check") else glyph.qubit.phi

			# Update theta directly (faster response to evolution)
			# Store old theta to detect change
			var old_theta = glyph.qubit.theta
			glyph.qubit.theta = new_theta

			# Continuous phase rotation (animated)
			glyph.qubit.phi += 0.05
			if glyph.qubit.phi > TAU:
				glyph.qubit.phi -= TAU

			glyph.update_from_qubit(delta)
			glyph_idx += 1

		if glyph_idx >= glyphs.size():
			break

	# Update all edges
	for edge in edges:
		if glyph_map.size() > 0:
			# Get qubits from glyph map (need to reverse lookup)
			var from_qubit = null
			var to_qubit = null
			for qubit in glyph_map.keys():
				if glyph_map[qubit] == edge.from_glyph:
					from_qubit = qubit
				if glyph_map[qubit] == edge.to_glyph:
					to_qubit = qubit
			if from_qubit and to_qubit:
				edge.update(delta, from_qubit, to_qubit)

	queue_redraw()


func _draw() -> void:
	"""Render all glyphs and optional detail panel"""

	# Draw temperature gradient field background
	_draw_temperature_field()

	# Draw edges (behind glyphs)
	for edge in edges:
		edge.draw(self, emoji_font)

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


func _build_edges() -> void:
	"""Extract entanglement relationships and create SemanticEdge objects"""
	edges.clear()

	# Create edges from entanglement_graph in qubits
	for idx in range(glyphs.size()):
		for idx2 in range(idx + 1, glyphs.size()):
			var glyph1 = glyphs[idx]
			var glyph2 = glyphs[idx2]

			if not glyph1.qubit or not glyph2.qubit:
				continue

			# Check for entanglement relationships in glyph1's entanglement_graph
			if "entanglement_graph" in glyph1.qubit:
				var graph = glyph1.qubit.entanglement_graph
				for relationship in graph.keys():
					# Create edge for this relationship
					var edge = SemanticEdge.new()
					edge.from_glyph = glyph1
					edge.to_glyph = glyph2
					edge.relationship_emoji = relationship
					edge.coupling_strength = _get_coupling_strength(relationship)
					edges.append(edge)


func _get_coupling_strength(relationship: String) -> float:
	"""Get default coupling strength for relationship type"""
	match relationship:
		"🍴": return 0.8  # Predation (strong)
		"🌱": return 0.7  # Feeding (strong)
		"💧": return 0.6  # Production (moderate)
		"🔄": return 0.5  # Transformation (moderate)
		"⚡": return 0.9  # Coherence (very strong)
		"👶": return 0.4  # Reproduction (weak)
		"🃏": return 0.6  # Escape (moderate)
		_: return 0.3  # Unknown (weak)


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


func _draw_temperature_field() -> void:
	"""Draw temperature gradient field background (visual context for quantum evolution)"""
	var viewport_rect = get_viewport_rect()
	var width = viewport_rect.size.x
	var height = viewport_rect.size.y
	var cell_size = 40.0  # Size of each gradient cell

	# Create temperature map based on position
	var x = 0.0
	while x < width:
		var y = 0.0
		while y < height:
			# Temperature based on position (left = cool, right = hot, top = cool, bottom = hot)
			var temp_x = (x / width) * 2.0 - 1.0  # -1 to 1
			var temp_y = (y / height) * 2.0 - 1.0  # -1 to 1
			var temperature = (temp_x + temp_y) * 0.5  # Average: -1 to 1

			# Map temperature to color (cool blue to hot red)
			var field_color: Color
			if temperature < 0:
				# Cool region (blue)
				field_color = Color.from_hsv(0.6 + temperature * 0.1, 0.5, 0.3 + abs(temperature) * 0.15, 0.15)
			else:
				# Hot region (red)
				field_color = Color.from_hsv(0.0 + temperature * 0.05, 0.6, 0.3 + temperature * 0.2, 0.15)

			# Draw cell
			draw_rect(Rect2(Vector2(x, y), Vector2(cell_size, cell_size)), field_color)

			y += cell_size

		x += cell_size

	# Add subtle diagonal gradient overlay (reinforces direction)
	var corner_tl = Color(0.2, 0.4, 0.6, 0.05)  # Cool blue
	var corner_br = Color(0.8, 0.3, 0.2, 0.05)  # Warm red

	var points = PackedVector2Array()
	var colors = PackedColorArray()

	# Create a subtle 2-point gradient by drawing with many small rectangles
	for i in range(10):
		var progress = float(i) / 10.0
		var blend_color = corner_tl.lerp(corner_br, progress)
		var rect_height = height / 10.0
		draw_rect(Rect2(0, i * rect_height, width, rect_height), blend_color)

