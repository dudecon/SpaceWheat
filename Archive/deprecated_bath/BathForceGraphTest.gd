extends Control

## Bath-First QuantumForceGraph Test
## Visualizes quantum BATHS (not individual qubits)
## Each bubble = one BASIS STATE (emoji) in the bath
## Bubble size = sqrt(probability) from bath amplitude
## Steals visuals from QuantumForceGraphTest, upgrades simulation to bath-first

const QuantumForceGraphScript = preload("res://Core/Visualization/QuantumForceGraph.gd")
const QuantumNodeScript = preload("res://Core/Visualization/QuantumNode.gd")
const FarmPlotScript = preload("res://Core/GameMechanics/FarmPlot.gd")
const DualEmojiQubitScript = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const BioticFluxBiomeScript = preload("res://Core/Environment/BioticFluxBiome.gd")
const ForestEcosystemBiomeScript = preload("res://Core/Environment/ForestEcosystem_Biome.gd")

@onready var graph_node = $QuantumForceGraph
@onready var qubit_count_label = $UI/InfoPanel/MarginContainer/VBoxContainer/QubitCountLabel
@onready var entanglement_label = $UI/InfoPanel/MarginContainer/VBoxContainer/EntanglementLabel
@onready var coherence_label = $UI/InfoPanel/MarginContainer/VBoxContainer/CoherenceLabel

var graph: Node2D = null

# Biomes (running in bath mode)
var biotic_flux_biome = null
var forest_biome = null

# Basis state bubbles (READ bath, don't own state)
var biotic_flux_bubbles: Array = []  # 6 bubbles for bath basis states
var forest_bubbles: Array = []        # 22 bubbles for bath basis states

var stored_center: Vector2
var stored_radius: float

# Visual tuning for bath-first (power law scaling for better differentiation)
var base_bubble_size: float = 8.0   # Small minimum so tiny probabilities are visible
var size_scale: float = 60.0         # Scale factor for probability → radius
var size_exponent: float = 0.3       # Power law: prob^0.3 gives differentiation at low end

# Force parameters (stolen from old system)
var skating_rink_strength: float = 150.0


func _ready():
	"""Initialize bath-first visualization"""
	var sep = "════════════════════════════════════════════════════════════════════════════"
	print("\n" + sep)
	print("🛁 BATH-FIRST QuantumForceGraph Test")
	print("   Visualizing quantum BATHS (not individual qubits)")
	print("   Each bubble = one BASIS STATE in the bath")
	print("   Bubble size = sqrt(probability)")
	print(sep)

	# Create graph
	graph = QuantumForceGraphScript.new()
	graph_node.add_child(graph)
	await get_tree().process_frame

	# Initialize viewport dimensions
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x < 200 or viewport_size.y < 200:
		viewport_size = Vector2(1280, 720)

	stored_center = viewport_size / 2.0
	stored_radius = min(viewport_size.x, viewport_size.y) * 0.35

	graph.center_position = stored_center
	graph.graph_radius = stored_radius
	graph.lock_dimensions = false
	print("   📐 Graph: center=%s radius=%.0f" % [stored_center, stored_radius])

	# ═══════════════════════════════════════════════════════════════
	# CREATE BIOMES (bath mode enabled)
	# ═══════════════════════════════════════════════════════════════
	print("   🔧 Creating BioticFlux biome...")
	biotic_flux_biome = BioticFluxBiomeScript.new()
	add_child(biotic_flux_biome)
	await get_tree().process_frame

	# Verify bath mode
	print("   🔍 Checking BioticFlux bath mode: use_bath=%s, has_bath=%s" % [biotic_flux_biome.use_bath_mode, biotic_flux_biome.bath != null])
	if not biotic_flux_biome.use_bath_mode or not biotic_flux_biome.bath:
		push_error("❌ BioticFlux not in bath mode!")
		get_tree().quit()
		return

	graph.biomes["BioticFlux"] = biotic_flux_biome
	print("   🌾 BioticFlux: bath with %d emojis" % biotic_flux_biome.bath.emoji_list.size())
	var bf_config = biotic_flux_biome.get_visual_config()
	print("      Visual: center_offset=%s, oval=%sx%s" % [bf_config.center_offset, bf_config.oval_width, bf_config.oval_height])

	forest_biome = ForestEcosystemBiomeScript.new(4, 1)
	add_child(forest_biome)
	await get_tree().process_frame

	if not forest_biome.use_bath_mode or not forest_biome.bath:
		push_error("❌ Forest not in bath mode!")
		return

	graph.biomes["Forest"] = forest_biome
	print("   🌲 Forest: bath with %d emojis" % forest_biome.bath.emoji_list.size())
	var forest_config = forest_biome.get_visual_config()
	print("      Visual: center_offset=%s, oval=%sx%s" % [forest_config.center_offset, forest_config.oval_width, forest_config.oval_height])

	# ═══════════════════════════════════════════════════════════════
	# COMPUTE LAYOUT from biome configs
	# ═══════════════════════════════════════════════════════════════
	print("\n   📐 Computing biome layout...")
	graph.update_layout(true)

	# Verify ovals were computed
	var bf_oval = graph.layout_calculator.get_biome_oval("BioticFlux")
	var forest_oval = graph.layout_calculator.get_biome_oval("Forest")
	if bf_oval.is_empty():
		push_error("❌ BioticFlux oval not computed!")
	else:
		print("      ✅ BioticFlux oval: center=%s, semi=%sx%s" % [bf_oval.center, bf_oval.semi_a, bf_oval.semi_b])
	if forest_oval.is_empty():
		push_error("❌ Forest oval not computed!")
	else:
		print("      ✅ Forest oval: center=%s, semi=%sx%s" % [forest_oval.center, forest_oval.semi_a, forest_oval.semi_b])

	# ═══════════════════════════════════════════════════════════════
	# CREATE BASIS STATE BUBBLES (one per emoji in bath)
	# ═══════════════════════════════════════════════════════════════
	_create_biotic_flux_basis_bubbles()
	_create_forest_basis_bubbles()

	graph.set_process(true)

	var total = biotic_flux_bubbles.size() + forest_bubbles.size()
	print("\n✅ Bath visualization ready")
	print("   🔵 %d basis state bubbles total" % total)
	print("   🌾 BioticFlux: %d basis states" % biotic_flux_bubbles.size())
	print("   🌲 Forest: %d basis states" % forest_bubbles.size())
	print("   ✨ Bubbles update from bath each frame (no individual evolution)")
	print(sep + "\n")


func _create_biotic_flux_basis_bubbles():
	"""Create one bubble per BASIS STATE in BioticFlux bath"""
	if not biotic_flux_biome or not biotic_flux_biome.bath:
		return

	# Get emoji basis from bath
	var emojis = biotic_flux_biome.bath.emoji_list  # ["☀", "🌙", "🌾", "🍄", "💀", "🍂"]

	for i in range(emojis.size()):
		var emoji = emojis[i]

		# Create dummy qubit (just for QuantumNode interface compatibility)
		var dummy_qubit = DualEmojiQubitScript.new(emoji, emoji)
		dummy_qubit.theta = PI / 2.0
		dummy_qubit.phi = 0.0
		dummy_qubit.radius = 0.5

		var plot = FarmPlotScript.new()
		plot.plot_id = "biotic_basis_%s" % emoji
		plot.grid_position = Vector2i(i, 0)
		plot.quantum_state = dummy_qubit
		plot.is_planted = true

		# Parametric placement in biome oval
		var t = float(i) / float(emojis.size())
		var ring = 0.3 + (i % 3) * 0.15  # Spread across rings
		var anchor = graph.layout_calculator.get_parametric_position("BioticFlux", t, ring)

		var node = QuantumNodeScript.new(plot, anchor, Vector2i(i, 0), stored_center)
		node.biome_name = "BioticFlux"
		node.has_farm_tether = false
		node.parametric_t = t
		node.parametric_ring = ring
		node.emoji_north = emoji
		node.emoji_south = emoji
		node.radius = base_bubble_size

		# Color by emoji type
		node.color = _get_emoji_color(emoji)

		graph.quantum_nodes.append(node)
		graph.node_by_plot_id[plot.plot_id] = node
		biotic_flux_bubbles.append(node)

	print("   ✅ Created %d BioticFlux basis bubbles" % biotic_flux_bubbles.size())


func _create_forest_basis_bubbles():
	"""Create one bubble per BASIS STATE in Forest bath"""
	if not forest_biome or not forest_biome.bath:
		return

	# Get emoji basis from bath
	var emojis = forest_biome.bath.emoji_list  # 22 forest emojis

	for i in range(emojis.size()):
		var emoji = emojis[i]

		# Create dummy qubit
		var dummy_qubit = DualEmojiQubitScript.new(emoji, emoji)
		dummy_qubit.theta = PI / 2.0
		dummy_qubit.phi = 0.0
		dummy_qubit.radius = 0.5

		var plot = FarmPlotScript.new()
		plot.plot_id = "forest_basis_%s" % emoji
		plot.grid_position = Vector2i(i + 100, 0)
		plot.quantum_state = dummy_qubit
		plot.is_planted = true

		# Parametric placement in forest oval
		var t = float(i) / float(emojis.size())
		var ring = 0.25 + (i % 4) * 0.12  # Spread across multiple rings
		var anchor = graph.layout_calculator.get_parametric_position("Forest", t, ring)

		var node = QuantumNodeScript.new(plot, anchor, Vector2i(i + 100, 0), stored_center)
		node.biome_name = "Forest"
		node.has_farm_tether = false
		node.parametric_t = t
		node.parametric_ring = ring
		node.emoji_north = emoji
		node.emoji_south = emoji
		node.radius = base_bubble_size * 0.7  # Smaller for forest

		# Color by emoji type
		node.color = _get_emoji_color(emoji)

		graph.quantum_nodes.append(node)
		graph.node_by_plot_id[plot.plot_id] = node
		forest_bubbles.append(node)

	print("   ✅ Created %d Forest basis bubbles" % forest_bubbles.size())


func _get_emoji_color(emoji: String) -> Color:
	"""Get color for emoji based on type"""
	match emoji:
		"☀": return Color(1.0, 0.9, 0.3)  # Golden sun
		"🌙": return Color(0.7, 0.7, 0.9)  # Pale moon
		"🌾": return Color(0.9, 0.8, 0.3)  # Wheat gold
		"🍄": return Color(0.7, 0.4, 0.6)  # Mushroom purple
		"💀": return Color(0.9, 0.9, 0.9)  # Death white
		"🍂": return Color(0.7, 0.5, 0.3)  # Autumn brown
		"🐺": return Color(0.6, 0.5, 0.4)  # Wolf grey
		"🦅": return Color(0.6, 0.4, 0.2)  # Eagle brown
		"🐇": return Color(0.8, 0.7, 0.6)  # Rabbit tan
		"🦌": return Color(0.7, 0.6, 0.4)  # Deer brown
		"🌿": return Color(0.3, 0.8, 0.4)  # Vegetation green
		"🌱": return Color(0.5, 0.9, 0.5)  # Seedling bright green
		"🌳": return Color(0.3, 0.6, 0.3)  # Forest dark green
		"🌲": return Color(0.2, 0.5, 0.3)  # Tree green
		"💧": return Color(0.3, 0.6, 0.9)  # Water blue
		"⛰": return Color(0.6, 0.5, 0.4)  # Soil brown-grey
		_: return Color.from_hsv(randf(), 0.7, 0.7)


func _update_bubble_visuals_from_bath():
	"""Update bubble sizes and colors from bath amplitudes

	This is the KEY method - we READ the bath, we don't evolve individual bubbles!
	"""
	# Update BioticFlux bubbles
	for bubble in biotic_flux_bubbles:
		var emoji = bubble.emoji_north
		var prob = biotic_flux_biome.bath.get_probability(emoji)
		var amp = biotic_flux_biome.bath.get_amplitude(emoji)

		# Size: Power law scaling (prob^0.3) for better low-end differentiation
		# min + scaling formula ensures tiny probabilities are still visible
		bubble.radius = base_bubble_size + pow(prob, size_exponent) * size_scale

		# Color modulation from phase (coherence indicator)
		var phase = amp.arg()
		var base_color = _get_emoji_color(emoji)
		var brightness = 0.5 + prob * 0.5  # Brighter when higher probability
		bubble.color = base_color.lightened(brightness - 0.5)

		# Update dummy qubit for angular forces only (no radial orbit)
		if bubble.plot and bubble.plot.quantum_state:
			bubble.plot.quantum_state.phi = phase

	# Update Forest bubbles
	for bubble in forest_bubbles:
		var emoji = bubble.emoji_north
		var prob = forest_biome.bath.get_probability(emoji)
		var amp = forest_biome.bath.get_amplitude(emoji)

		# Size: Same power law scaling
		bubble.radius = base_bubble_size + pow(prob, size_exponent) * size_scale

		# Color
		var phase = amp.arg()
		var base_color = _get_emoji_color(emoji)
		var brightness = 0.5 + prob * 0.5
		bubble.color = base_color.lightened(brightness - 0.5)

		# Update dummy qubit (angular only)
		if bubble.plot and bubble.plot.quantum_state:
			bubble.plot.quantum_state.phi = phase


func _apply_skating_rink_forces(delta: float):
	"""Apply forces based on phi angle only (radial orbit removed for bath-first)

	Bath-first change: We don't use probability/radius for radial positioning anymore.
	All bubbles orbit around a fixed ring, with phi determining angular position.
	"""
	if not graph or not graph.layout_calculator:
		return

	for bubble in biotic_flux_bubbles + forest_bubbles:
		if not bubble.plot or not bubble.plot.quantum_state:
			continue

		var qubit = bubble.plot.quantum_state
		var oval = graph.layout_calculator.get_biome_oval(bubble.biome_name)
		if oval.is_empty():
			continue

		var center = oval.get("center", Vector2.ZERO)
		var semi_a = oval.get("semi_a", 100.0)
		var semi_b = oval.get("semi_b", 60.0)

		# Phi → angular position on perimeter
		var phi = qubit.phi if "phi" in qubit else 0.0

		# Fixed ring at 70% radius (not probability-based!)
		var ring_distance = 0.7

		var target_pos = center + Vector2(
			semi_a * cos(phi) * ring_distance,
			semi_b * sin(phi) * ring_distance
		)

		# Apply force toward target
		var to_target = target_pos - bubble.position
		var distance = to_target.length()

		if distance > 1.0:
			var force_dir = to_target.normalized()
			var force_magnitude = skating_rink_strength * min(distance / 50.0, 2.0)
			bubble.velocity += force_dir * force_magnitude * delta


func _update_metrics():
	"""Update displayed metrics from bath states"""
	if not biotic_flux_biome or not biotic_flux_biome.bath:
		return
	if not forest_biome or not forest_biome.bath:
		return

	var total_bubbles = biotic_flux_bubbles.size() + forest_bubbles.size()

	# Get dominant emojis
	var bf_dominant = _get_dominant_emoji(biotic_flux_biome.bath)
	var forest_dominant = _get_dominant_emoji(forest_biome.bath)

	# Update labels
	if qubit_count_label:
		qubit_count_label.text = "Basis States: %d (🌾%d + 🌲%d)" % [
			total_bubbles, biotic_flux_bubbles.size(), forest_bubbles.size()
		]
	if entanglement_label:
		entanglement_label.text = "Dominant: %s (%.1f%%) | %s (%.1f%%)" % [
			bf_dominant.emoji, bf_dominant.prob * 100,
			forest_dominant.emoji, forest_dominant.prob * 100
		]
	if coherence_label:
		var bf_norm = biotic_flux_biome.bath.get_total_probability()
		var forest_norm = forest_biome.bath.get_total_probability()
		coherence_label.text = "Bath Norm: BF=%.3f, Forest=%.3f" % [bf_norm, forest_norm]


func _get_dominant_emoji(bath) -> Dictionary:
	"""Get emoji with highest probability in bath"""
	var max_prob = 0.0
	var max_emoji = ""

	for emoji in bath.emoji_list:
		var prob = bath.get_probability(emoji)
		if prob > max_prob:
			max_prob = prob
			max_emoji = emoji

	return {"emoji": max_emoji, "prob": max_prob}


func _process(delta):
	"""Main update loop - READ bath, update visuals"""
	# Baths evolve automatically (BiomeBase handles it)

	# Update bubble visuals from bath state
	_update_bubble_visuals_from_bath()

	# Apply forces (visual layout)
	_apply_skating_rink_forces(delta)

	# Update metrics
	var timer = 0.0
	timer += delta
	if timer > 0.5:
		_update_metrics()
		timer = 0.0

	# Redraw
	if graph:
		graph.queue_redraw()

	# Quit on Q
	if Input.is_key_pressed(KEY_Q):
		get_tree().quit()
