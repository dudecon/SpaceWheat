extends Control

## Test scene for QuantumForceGraph visualization
## Displays colorful qubits with force-directed layout and entanglement

const QuantumForceGraphScript = preload("res://Core/Visualization/QuantumForceGraph.gd")
const QuantumNodeScript = preload("res://Core/Visualization/QuantumNode.gd")
const FarmPlotScript = preload("res://Core/GameMechanics/FarmPlot.gd")
const DualEmojiQubitScript = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

# Load Forest V3 at runtime (not a constant)
var ForestV3Script = null

@onready var graph_node = $QuantumForceGraph
@onready var qubit_count_label = $UI/InfoPanel/MarginContainer/VBoxContainer/QubitCountLabel
@onready var entanglement_label = $UI/InfoPanel/MarginContainer/VBoxContainer/EntanglementLabel
@onready var coherence_label = $UI/InfoPanel/MarginContainer/VBoxContainer/CoherenceLabel

var graph: Node2D = null
var forest: Node = null
var qubits = {}  # trophic_level -> QuantumNode
var update_timer = 0.0

# Forest trophic levels mapped to emoji
var trophic_levels = {
	"plant": {"emoji": "🌿", "pair": "🌱"},
	"herbivore": {"emoji": "🐰", "pair": "🐭"},
	"predator": {"emoji": "🐦", "pair": "🦅"},
	"apex": {"emoji": "🐺", "pair": "🦁"},
	"decomposer": {"emoji": "🪦", "pair": "🌰"},
	"pollinator": {"emoji": "🐝", "pair": "🦋"},
	"parasite": {"emoji": "🧬", "pair": "🦠"},
	"nitrogen_fixer": {"emoji": "🌍", "pair": "💨"},
	"mycorrhizal": {"emoji": "🍄", "pair": "🌳"},
}


func _ready():
	"""Initialize the test scene with sample qubits from Forest V3"""
	print("⚛️  QuantumForceGraph Test Scene initializing...")

	# Load and initialize forest simulation
	ForestV3Script = load("res://Core/Environment/ForestEcosystem_Biome_v3_quantum_field.gd")
	if ForestV3Script:
		forest = ForestV3Script.new(1, 1)
		forest._ready()
		print("   🌲 Forest V3 quantum field initialized")
	else:
		print("   ⚠️  Warning: Could not load Forest V3 script")

	# Create and add the QuantumForceGraph to the scene
	graph = QuantumForceGraphScript.new()
	graph_node.add_child(graph)

	# Create sample qubits from forest simulation
	_create_sample_qubits()

	# Add quantum nodes to graph
	for level_name in qubits.keys():
		var quantum_node = qubits[level_name]
		graph.quantum_nodes.append(quantum_node)
		if quantum_node.plot_id:
			graph.node_by_plot_id[quantum_node.plot_id] = quantum_node

	# Manually initialize the graph's visual properties
	graph.center_position = Vector2(640, 360)
	graph.graph_radius = 250.0

	# Tell graph to set up for rendering
	graph.set_process(true)

	print("✅ QuantumForceGraph test scene ready")
	print("   🔵 %d qubits (trophic levels) with force-directed layout" % qubits.size())
	print("   🌀 Coupled interactions based on Hamiltonian")
	print("   ✨ Real-time quantum field evolution visualization")


func _create_sample_qubits():
	"""Create quantum nodes from Forest V3 occupation numbers"""
	if not forest:
		print("   ⚠️  No forest instance, cannot create qubits")
		return

	var center = Vector2(640, 360)
	var radius = 250.0
	var patch_pos = Vector2i(0, 0)

	# Get occupation numbers for this patch
	var N = forest.get_occupation_numbers(patch_pos)
	if N.is_empty():
		print("   ⚠️  No occupation data for patch %s" % patch_pos)
		return

	var level_names = trophic_levels.keys()
	var idx = 0
	var max_population = 1.0  # For normalization

	# First pass: find max population for normalization
	for level_name in level_names:
		if level_name in N:
			max_population = max(max_population, N[level_name])

	# Second pass: create quantum nodes
	for level_name in level_names:
		if level_name not in N:
			continue

		var population = N[level_name]
		var emoji_data = trophic_levels[level_name]

		# Create forest plot with quantum state
		var plot = FarmPlotScript.new()
		plot.plot_id = "forest_%s" % level_name
		plot.grid_position = patch_pos

		# Create qubit representing this trophic level
		var qubit = DualEmojiQubitScript.new(emoji_data["emoji"], emoji_data["pair"])

		# Radius represents population (normalized to 0-1)
		qubit.radius = population / max_population
		qubit.theta = randf_range(0.0, PI)
		qubit.phi = randf_range(0.0, TAU)

		plot.quantum_state = qubit

		# Calculate circular position for this trophic level
		var angle = idx * TAU / level_names.size()
		var anchor_pos = center + Vector2(cos(angle) * radius, sin(angle) * radius)

		# Create QuantumNode
		var quantum_node = QuantumNodeScript.new(plot, anchor_pos, Vector2i(idx, 0), center)
		quantum_node.color = Color.from_hsv(float(idx) / level_names.size(), 0.8, 0.9)
		quantum_node.emoji_north = emoji_data["emoji"]
		quantum_node.emoji_south = emoji_data["pair"]

		qubits[level_name] = quantum_node
		idx += 1

	print("   ✅ Created %d trophic level qubits from forest simulation" % qubits.size())


func _update_qubits_from_forest():
	"""Update qubit properties every frame from the living forest simulation"""
	if not forest or qubits.is_empty():
		return

	# Step the forest simulation (Hamiltonian evolution)
	forest._update_quantum_substrate(0.016)  # ~60fps timestep

	var patch_pos = Vector2i(0, 0)
	var N = forest.get_occupation_numbers(patch_pos)
	if N.is_empty():
		return

	# Find max population for normalization
	var max_population = 1.0
	for level_name in N.keys():
		max_population = max(max_population, N[level_name])

	# Update each qubit from current forest state
	for level_name in qubits.keys():
		if level_name not in N:
			continue

		var quantum_node = qubits[level_name]
		var population = N[level_name]

		# Update qubit radius to match population (coherence)
		if quantum_node.plot and quantum_node.plot.quantum_state:
			quantum_node.plot.quantum_state.radius = population / max(max_population, 1.0)

		# Update visual properties based on population
		# Color brightness ∝ energy (population level)
		var energy_brightness = clamp(0.3 + (population / 5.0) * 0.1, 0.3, 1.0)
		var hue = fmod(float(qubits.keys().find(level_name)) / qubits.size(), 1.0)
		quantum_node.color = Color.from_hsv(hue, 0.8, energy_brightness)

		# Update emoji opacity based on population (higher population = more opaque)
		quantum_node.emoji_north_opacity = clamp(population / 3.0, 0.0, 1.0)

	# Tell the graph to redraw
	if graph:
		graph.queue_redraw()


func _process(delta):
	"""Update qubits from forest simulation and update metrics"""
	# Update qubits from the living forest simulation
	_update_qubits_from_forest()

	# Update metrics display
	update_timer += delta
	if update_timer > 0.5:
		_update_metrics()
		update_timer = 0.0

	# Close on Q
	if Input.is_key_pressed(KEY_Q):
		get_tree().quit()


func _update_metrics():
	"""Update the displayed metrics from forest simulation"""
	if qubits.is_empty() or not forest:
		return

	var qubit_count = qubits.size()
	var total_coherence = 0.0
	var patch_pos = Vector2i(0, 0)
	var N = forest.get_occupation_numbers(patch_pos)

	# Collect coherence from all quantum nodes
	for quantum_node in qubits.values():
		if quantum_node.plot and quantum_node.plot.quantum_state:
			total_coherence += quantum_node.plot.quantum_state.radius

	# Calculate total ecosystem population as measure of "entanglement"
	var total_population = 0.0
	for level_name in N.keys():
		total_population += N[level_name]

	# Update labels
	qubit_count_label.text = "Trophic Levels: %d" % qubit_count
	entanglement_label.text = "Total Population: %.1f" % total_population

	if qubit_count > 0:
		var avg_coherence = total_coherence / qubit_count
		coherence_label.text = "Avg Coherence: %.2f" % avg_coherence
	else:
		coherence_label.text = "Avg Coherence: ────"
