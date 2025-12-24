extends Control

## Test scene for QuantumForceGraph visualization
## Displays colorful qubits with force-directed layout and entanglement

const QuantumForceGraphScript = preload("res://Core/Visualization/QuantumForceGraph.gd")
const DualEmojiQubitScript = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

@onready var graph_node = $QuantumForceGraph
@onready var qubit_count_label = $UI/InfoPanel/MarginContainer/VBoxContainer/QubitCountLabel
@onready var entanglement_label = $UI/InfoPanel/MarginContainer/VBoxContainer/EntanglementLabel
@onready var coherence_label = $UI/InfoPanel/MarginContainer/VBoxContainer/CoherenceLabel

var graph: Node2D = null
var qubits = []
var update_timer = 0.0


func _ready():
	"""Initialize the test scene with sample qubits"""
	print("⚛️  QuantumForceGraph Test Scene initializing...")

	# Create and add the QuantumForceGraph to the scene
	graph = QuantumForceGraphScript.new()
	graph_node.add_child(graph)

	# Create sample qubits directly (without full farm grid)
	_create_sample_qubits()

	# Manually initialize the graph's visual properties
	graph.center_position = Vector2(640, 360)
	graph.graph_radius = 250.0
	graph.quantum_nodes = qubits

	# Tell graph to set up for rendering
	graph.set_process(true)

	print("✅ QuantumForceGraph test scene ready")
	print("   🔵 15 colorful qubits with force-directed layout")
	print("   🌀 Entanglement lines between coupled qubits")
	print("   ✨ Real-time dynamics and coherence visualization")


func _create_sample_qubits():
	"""Create sample qubits directly"""
	var emojis = ["🌿", "🐰", "🐦", "🐺", "💫", "🌟", "⭐", "✨", "🔮", "💎", "🌻", "🦋", "🐝", "🐛", "🦗"]
	var center = Vector2(640, 360)
	var radius = 250.0

	for i in range(emojis.size()):
		# Create a mock plot with qubit
		var plot = {
			"plot_id": "test_plot_%d" % i,
			"grid_position": Vector2i(i % 5, i / 5),
			"quantum_state": DualEmojiQubitScript.new(emojis[i], emojis[(i + 1) % emojis.size()]),
			"entangled_plots": {},
			"has_been_measured": false
		}

		# Random quantum state
		plot.quantum_state.theta = randf_range(0.0, PI)
		plot.quantum_state.phi = randf_range(0.0, TAU)
		plot.quantum_state.radius = randf_range(0.4, 1.0)

		# Create QuantumNode for the graph
		var quantum_node = {
			"plot_id": plot["plot_id"],
			"plot": plot,
			"position": center + Vector2(cos(i * TAU / emojis.size()) * radius, sin(i * TAU / emojis.size()) * radius),
			"velocity": Vector2.ZERO,
			"radius": 30.0,
			"color": Color.from_hsv(float(i) / emojis.size(), 0.8, 0.9)
		}

		# Randomly entangle some qubits
		if i > 0 and randf() < 0.5:
			var prev_idx = i - 1
			plot["entangled_plots"]["test_plot_%d" % prev_idx] = {
				"entanglement_strength": randf_range(0.3, 0.9),
				"bell_gate": "CNOT"
			}

		qubits.append(quantum_node)


func _process(delta):
	"""Update metrics display"""
	update_timer += delta
	if update_timer > 0.5:
		_update_metrics()
		update_timer = 0.0

	# Close on Q
	if Input.is_key_pressed(KEY_Q):
		get_tree().quit()


func _update_metrics():
	"""Update the displayed metrics"""
	if qubits.is_empty():
		return

	# Count qubits and entanglements
	var qubit_count = qubits.size()
	var entangled_count = 0
	var total_coherence = 0.0

	for quantum_node in qubits:
		var plot = quantum_node["plot"]
		if plot and "quantum_state" in plot and plot.quantum_state:
			total_coherence += plot.quantum_state.radius
			entangled_count += plot["entangled_plots"].size()

	# Update labels
	qubit_count_label.text = "Qubits: %d" % qubit_count
	entanglement_label.text = "Entangled: %d" % entangled_count

	if qubit_count > 0:
		var avg_coherence = total_coherence / qubit_count
		coherence_label.text = "Avg Coherence: %.2f" % avg_coherence
	else:
		coherence_label.text = "Avg Coherence: ────"
