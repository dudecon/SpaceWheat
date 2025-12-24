extends Control

## Test scene for QuantumForceGraph visualization
## Displays colorful qubits with force-directed layout and entanglement

const QuantumForceGraphScript = preload("res://Core/Visualization/QuantumForceGraph.gd")
const FarmGridScript = preload("res://Core/GameMechanics/FarmGrid.gd")
const WheatPlotScript = preload("res://Core/GameMechanics/WheatPlot.gd")
const DualEmojiQubitScript = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

@onready var graph_node = $QuantumForceGraph
@onready var qubit_count_label = $UI/InfoPanel/MarginContainer/VBoxContainer/QubitCountLabel
@onready var entanglement_label = $UI/InfoPanel/MarginContainer/VBoxContainer/EntanglementLabel
@onready var coherence_label = $UI/InfoPanel/MarginContainer/VBoxContainer/CoherenceLabel

var graph: Node2D = null
var farm_grid: Node = null
var update_timer = 0.0


func _ready():
	"""Initialize the test scene with sample qubits"""
	print("⚛️  QuantumForceGraph Test Scene initializing...")

	# Create a simple farm grid (5x3 = 15 plots)
	farm_grid = FarmGridScript.new(5, 3)

	# Create sample qubits in plots
	_create_sample_qubits()

	# Create and initialize the QuantumForceGraph
	graph = QuantumForceGraphScript.new()
	graph_node.add_child(graph)

	# Initialize the graph with our farm grid
	var center = Vector2(640, 360)  # Center of 1280x720 viewport
	var radius = 250.0
	graph.initialize(farm_grid, center, radius)

	print("✅ QuantumForceGraph test scene ready")
	print("   🔵 Colorful qubits with force-directed layout")
	print("   🌀 Entanglement lines between coupled qubits")
	print("   ✨ Real-time dynamics and coherence visualization")


func _create_sample_qubits():
	"""Create sample qubits in the farm grid"""
	# Create some plots with qubits
	var emojis = ["🌿", "🐰", "🐦", "🐺", "💫", "🌟", "⭐", "✨", "🔮", "💎"]
	var idx = 0

	for y in range(farm_grid.grid_height):
		for x in range(farm_grid.grid_width):
			if idx >= emojis.size():
				idx = 0

			var grid_pos = Vector2i(x, y)
			var plot = farm_grid.get_plot(grid_pos)

			if plot == null:
				plot = WheatPlotScript.new(WheatPlotScript.BiomePlotType.STANDARD)
				plot.plot_id = "test_plot_%d_%d" % [x, y]
				plot.grid_position = grid_pos
				farm_grid.set_plot(grid_pos, plot)

			# Create a qubit for this plot
			var north_emoji = emojis[idx]
			var south_emoji = emojis[(idx + 1) % emojis.size()]

			var qubit = DualEmojiQubitScript.new(north_emoji, south_emoji)
			qubit.theta = randf_range(0.0, PI)
			qubit.phi = randf_range(0.0, TAU)
			qubit.radius = randf_range(0.4, 1.0)  # Random coherence

			plot.quantum_state = qubit

			# Randomly entangle some qubits
			if idx > 0 and randf() < 0.4:
				var prev_plot = farm_grid.get_plot(Vector2i(x - 1 if x > 0 else 0, y))
				if prev_plot and prev_plot.quantum_state:
					plot.entangled_plots[prev_plot.plot_id] = {
						"entanglement_strength": randf_range(0.3, 0.9),
						"bell_gate": "CNOT"
					}

			idx += 1


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
	if not farm_grid:
		return

	# Count qubits
	var qubit_count = 0
	var entangled_count = 0
	var total_coherence = 0.0

	for y in range(farm_grid.grid_height):
		for x in range(farm_grid.grid_width):
			var plot = farm_grid.get_plot(Vector2i(x, y))
			if plot and plot.quantum_state:
				qubit_count += 1
				total_coherence += plot.quantum_state.radius
				entangled_count += plot.entangled_plots.size()

	# Update labels
	qubit_count_label.text = "Qubits: %d" % qubit_count
	entanglement_label.text = "Entangled: %d" % entangled_count

	if qubit_count > 0:
		var avg_coherence = total_coherence / qubit_count
		coherence_label.text = "Avg Coherence: %.2f" % avg_coherence
	else:
		coherence_label.text = "Avg Coherence: ────"
