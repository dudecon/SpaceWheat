class_name BathQuantumVisualizationController
extends Node2D

## Bath-First Quantum Visualization Controller
## Visualizes quantum BATHS (not individual qubits)
## Each bubble represents one BASIS STATE (emoji) in a biome's bath
## Bubble size scales with probability using power law for better differentiation
##
## Usage:
##   var viz = BathQuantumVisualizationController.new()
##   add_child(viz)
##   viz.add_biome("BioticFlux", biotic_flux_biome)
##   viz.add_biome("Forest", forest_biome)
##   viz.initialize()

const QuantumForceGraph = preload("res://Core/Visualization/QuantumForceGraph.gd")
const QuantumNode = preload("res://Core/Visualization/QuantumNode.gd")
const FarmPlot = preload("res://Core/GameMechanics/FarmPlot.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

# Graph engine
var graph: Node2D = null

# Biomes to visualize (name → biome reference)
var biomes: Dictionary = {}

# Farm reference (for plot-to-biome lookups)
var farm_ref = null

# Basis state bubbles (biome_name → Array[QuantumNode])
var basis_bubbles: Dictionary = {}

# Requested emojis per biome (biome_name → Array[String])
# Only emojis that plots have requested will have bubbles
var requested_emojis: Dictionary = {}

# Emoji to bubble mapping for quick lookup (biome_name → {emoji → QuantumNode})
var emoji_to_bubble: Dictionary = {}

# Visual tuning (power law scaling for better differentiation at low probabilities)
var base_bubble_size: float = 8.0   # Small minimum so tiny probabilities are visible
var size_scale: float = 60.0        # Scale factor for probability → radius
var size_exponent: float = 0.3      # Power law: prob^0.3 gives differentiation at low end

# Force parameters
var skating_rink_strength: float = 150.0

# Cached layout info
var stored_center: Vector2
var stored_radius: float


func _ready() -> void:
	"""Set up basic properties - call initialize() after adding biomes"""
	# Position at origin (Node2D doesn't use anchors)
	position = Vector2.ZERO
	set_process(true)


func add_biome(biome_name: String, biome_ref) -> void:
	"""Register a biome for visualization

	Args:
		biome_name: Identifier for the biome (e.g., "BioticFlux", "Forest")
		biome_ref: BiomeBase instance with bath mode enabled
	"""
	if not biome_ref:
		push_warning("BathQuantumViz: null biome reference for %s" % biome_name)
		return

	# All biomes now use bath mode, just check for bath existence
	if not biome_ref.bath:
		push_warning("BathQuantumViz: biome %s has no bath" % biome_name)
		return

	biomes[biome_name] = biome_ref
	print("🛁 BathQuantumViz: Added biome '%s' with %d basis states" % [biome_name, biome_ref.bath.emoji_list.size()])


func initialize() -> void:
	"""Initialize visualization after all biomes are added

	Call this after add_biome() for all biomes. Creates graph, computes layout,
	spawns basis state bubbles.
	"""
	if biomes.is_empty():
		push_error("BathQuantumViz: No biomes registered before initialize()")
		return

	print("🛁 BathQuantumViz: Initializing with %d biomes..." % biomes.size())

	# Create graph engine
	graph = QuantumForceGraph.new()
	add_child(graph)
	await get_tree().process_frame

	# Register biomes with graph BEFORE layout calculation
	for biome_name in biomes:
		graph.biomes[biome_name] = biomes[biome_name]

	# CRITICAL: Let update_layout() compute center/radius from actual viewport
	# This will handle small viewports correctly (e.g., 64×64 in headless mode)
	graph.lock_dimensions = false
	graph.update_layout(true)  # Force layout calculation before first _draw()

	# Cache the computed values for reference
	stored_center = graph.center_position
	stored_radius = graph.graph_radius

	# Initialize tracking structures (but don't create bubbles yet - wait for requests)
	for biome_name in biomes:
		requested_emojis[biome_name] = []
		emoji_to_bubble[biome_name] = {}
		basis_bubbles[biome_name] = []

	graph.set_process(true)

	print("✅ BathQuantumViz: Ready (plot-driven mode - bubbles will spawn on demand)")
	print("   📍 Position: %s" % position)
	print("   📊 QuantumForceGraph exists: %s" % (graph != null))
	if graph:
		print("   📊 QuantumForceGraph center: %s, radius: %.1f" % [graph.center_position, graph.graph_radius])


func connect_to_farm(farm) -> void:
	"""Connect to farm signals to auto-request bubbles when plots are planted

	Args:
		farm: Farm instance with plot_planted signal
	"""
	if not farm:
		push_warning("BathQuantumViz: null farm reference")
		return

	# Store farm reference for plot-to-biome lookups
	farm_ref = farm

	if farm.has_signal("plot_planted"):
		farm.plot_planted.connect(_on_plot_planted)
		print("   📡 Connected to farm.plot_planted for auto-requesting bubbles")
	else:
		push_warning("BathQuantumViz: farm has no plot_planted signal")

	if farm.has_signal("plot_harvested"):
		farm.plot_harvested.connect(_on_plot_harvested)
		print("   📡 Connected to farm.plot_harvested for auto-despawning bubbles")
	else:
		push_warning("BathQuantumViz: farm has no plot_harvested signal")

	# NOTE: Rejection visual feedback is now handled by PlotGridDisplay (UI layer)
	# Not using QuantumForceGraph for this anymore to avoid duplicate systems
	# (see FarmUI.gd setup_farm() for the PlotGridDisplay connection)


# REMOVED: Rejection visual feedback now handled by PlotGridDisplay (UI layer)
# This was creating duplicate rejection effects - PlotGridDisplay is the correct layer
# func _on_action_rejected(action: String, position: Vector2i, reason: String) -> void:
#	"""Handle action rejected event - show red pulsing circle at plot"""
#	print("🚫 Action rejected at %s: %s" % [position, reason])
#	if graph:
#		graph.show_rejection_effect(position, reason)


func _on_plot_planted(position: Vector2i, plant_type: String) -> void:
	"""Handle plot planted event - request bubble for the planted plot

	This automatically spawns bubbles when the player plants crops.
	Uses plot-driven interface: ONE bubble per plot showing dual-emoji superposition.
	"""
	print("🔔 BathQuantumViz: Received plot_planted signal for %s at %s" % [plant_type, position])

	# Get plot's biome assignment from stored farm reference
	if not farm_ref or not farm_ref.grid:
		print("   ⚠️  No farm reference or grid found")
		return

	var biome_name = farm_ref.grid.plot_biome_assignments.get(position, "")
	if biome_name.is_empty():
		print("   ⚠️  No biome assignment for position %s" % position)
		return

	print("   📍 Plot at %s assigned to biome: %s" % [position, biome_name])

	# Get the actual plot instance
	var plot = farm_ref.grid.get_plot(position)
	if not plot:
		print("   ⚠️  No plot found at position %s" % position)
		return

	# Request ONE bubble for this plot (shows both emojis in superposition)
	request_plot_bubble(biome_name, position, plot)


func _on_plot_harvested(position: Vector2i, yield_data: Dictionary) -> void:
	"""Handle plot harvested event - despawn bubble for the harvested plot

	This automatically removes bubbles when the player harvests crops.
	"""
	print("✂️  BathQuantumViz: Received plot_harvested signal at %s" % position)

	if not graph:
		print("   ⚠️  No graph found")
		return

	# Find and remove bubble by grid position
	var bubble = graph.quantum_nodes_by_grid_pos.get(position)
	if not bubble:
		print("   ⚠️  No bubble found at position %s" % position)
		return

	# Get biome name for cleanup
	var biome_name = bubble.biome_name

	# Remove from graph tracking
	graph.quantum_nodes_by_grid_pos.erase(position)
	graph.quantum_nodes.erase(bubble)

	# Remove from biome bubble tracking
	if basis_bubbles.has(biome_name):
		basis_bubbles[biome_name].erase(bubble)
		print("   🗑️  Removed bubble from %s (remaining: %d)" % [biome_name, basis_bubbles[biome_name].size()])

	# Trigger redraw to hide bubble
	graph.queue_redraw()
	print("   ✅ Bubble despawned at %s" % position)


func request_plot_bubble(biome_name: String, grid_pos: Vector2i, plot) -> void:
	"""Request bubble for a specific plot - PLOT-DRIVEN INTERFACE

	Creates ONE bubble for the plot that shows both emojis in superposition.
	This is how the full game creates bubbles.

	Args:
		biome_name: Which biome this plot belongs to
		grid_pos: Grid position of the plot
		plot: The plot instance (FarmPlot or subclass)
	"""
	if not biomes.has(biome_name):
		push_warning("BathQuantumViz: Unknown biome '%s'" % biome_name)
		return

	var biome = biomes.get(biome_name)
	if not biome or not biome.bath:
		return

	# Get emojis from plot (Model B: emojis are plot metadata, not quantum state)
	if not plot.is_planted or not plot.parent_biome or plot.register_id < 0:
		print("   ⚠️  Plot at %s not properly initialized!" % grid_pos)
		return

	# Model B: Emojis are measurement basis labels stored on plot
	var north_emoji = plot.north_emoji
	var south_emoji = plot.south_emoji

	print("   🌱 Requesting plot bubble at %s: %s/%s" % [grid_pos, north_emoji, south_emoji])

	# Remove any existing bubble at this grid position (from previous harvest cycle)
	if graph.quantum_nodes_by_grid_pos.has(grid_pos):
		var old_bubble = graph.quantum_nodes_by_grid_pos[grid_pos]
		if old_bubble:
			# Remove from graph's node array
			var idx = graph.quantum_nodes.find(old_bubble)
			if idx >= 0:
				graph.quantum_nodes.remove_at(idx)
				print("   🗑️  Removed old bubble at grid %s" % grid_pos)

			# Remove from basis_bubbles array
			if basis_bubbles.has(biome_name):
				var basis_idx = basis_bubbles[biome_name].find(old_bubble)
				if basis_idx >= 0:
					basis_bubbles[biome_name].remove_at(basis_idx)

	# Create ONE bubble for this plot (it will show both emojis via update_from_quantum_state)
	var bubble = _create_plot_bubble(biome_name, grid_pos, plot)

	if bubble:
		basis_bubbles[biome_name].append(bubble)
		graph.quantum_nodes.append(bubble)  # Add to graph for rendering!
		graph.quantum_nodes_by_grid_pos[grid_pos] = bubble  # Index by grid pos
		print("   🔵 Created plot bubble (%s/%s) at grid %s" % [north_emoji, south_emoji, grid_pos])

		# Trigger graph redraw to show new bubble
		graph.queue_redraw()


func request_emoji_bubble(biome_name: String, emoji: String) -> void:
	"""Request a bubble for a specific emoji in a biome (LEGACY - basis state bubbles)

	This creates "floating" bubbles not associated with any plot.
	Use request_plot_bubble() for plot-driven bubbles instead.

	Args:
		biome_name: Which biome bath to project from
		emoji: The emoji to create a bubble for
	"""
	if not biomes.has(biome_name):
		push_warning("BathQuantumViz: Unknown biome '%s'" % biome_name)
		return

	var biome = biomes[biome_name]
	if not biome or not biome.bath:
		return

	# Check if emoji is in this biome's bath
	if not biome.bath.emoji_list.has(emoji):
		push_warning("BathQuantumViz: Emoji %s not in %s bath" % [emoji, biome_name])
		return

	# Skip if already requested
	if requested_emojis[biome_name].has(emoji):
		return

	# Mark as requested
	requested_emojis[biome_name].append(emoji)

	# Create the bubble (with dummy grid position for basis state bubbles)
	var bubble = _create_single_bubble(biome_name, emoji, Vector2i(0, 0))
	if bubble:
		basis_bubbles[biome_name].append(bubble)
		emoji_to_bubble[biome_name][emoji] = bubble
		print("   🔵 Created bubble for %s in %s (total: %d)" % [emoji, biome_name, basis_bubbles[biome_name].size()])


func _create_plot_bubble(biome_name: String, grid_pos: Vector2i, plot) -> QuantumNode:
	"""Create a bubble associated with a specific plot

	This is the plot-driven version - the bubble knows which plot it belongs to.
	The bubble's emojis will be set by update_from_quantum_state() from the plot's qubit.

	Args:
		biome_name: Which biome bath to project from
		grid_pos: Grid position of the plot this bubble represents
		plot: The actual plot instance (for quantum_state reference)

	Returns: The created QuantumNode, or null if creation failed
	"""
	var biome = biomes.get(biome_name)
	if not biome or not biome.bath:
		return null

	# Determine initial position (scatter around oval perimeter)
	var initial_pos = stored_center
	var oval = graph.layout_calculator.get_biome_oval(biome_name)
	if not oval.is_empty():
		var center = oval.get("center", stored_center)
		var semi_a = oval.get("semi_a", 100.0)
		var semi_b = oval.get("semi_b", 60.0)

		# Random angle for initial scatter
		var angle = randf() * TAU
		initial_pos = center + Vector2(
			semi_a * cos(angle) * 0.7,
			semi_b * sin(angle) * 0.7
		)

	# Create QuantumNode bubble (with REAL grid position from plot!)
	var bubble = QuantumNode.new(plot, initial_pos, grid_pos, stored_center)
	bubble.biome_name = biome_name

	# Emojis will be set by update_from_quantum_state() during first render
	# This ensures they always match the plot's current quantum state

	# Set initial visual properties (will be updated by update_from_quantum_state)
	bubble.radius = 40.0  # MAX_RADIUS from QuantumNode
	bubble.color = Color(0.8, 0.8, 0.8, 0.8)

	return bubble


func _create_single_bubble(biome_name: String, emoji: String, grid_pos: Vector2i = Vector2i.ZERO) -> QuantumNode:
	"""Create a single bubble for one emoji

	Returns: The created QuantumNode, or null if creation failed
	"""
	var biome = biomes.get(biome_name)
	if not biome or not biome.bath:
		return null

	# Create dummy qubit for interface compatibility (QuantumNode expects one)
	# This qubit doesn't evolve - we just update its phi from bath
	var dummy_qubit = DualEmojiQubit.new(emoji, "💀", PI/2)

	# Create dummy FarmPlot to hold qubit (QuantumNode expects plot.quantum_state)
	var dummy_plot = FarmPlot.new()
	dummy_plot.quantum_state = dummy_qubit

	# Determine initial position (scatter around oval perimeter)
	var initial_pos = stored_center
	var oval = graph.layout_calculator.get_biome_oval(biome_name)
	if not oval.is_empty():
		var center = oval.get("center", stored_center)
		var semi_a = oval.get("semi_a", 100.0)
		var semi_b = oval.get("semi_b", 60.0)

		# Random angle for initial scatter
		var angle = randf() * TAU
		initial_pos = center + Vector2(
			semi_a * cos(angle) * 0.7,
			semi_b * sin(angle) * 0.7
		)

	# Create QuantumNode bubble (requires: plot, anchor_pos, grid_pos, center_pos)
	# Use passed grid_pos (defaults to (0,0) for basis state bubbles)
	var bubble = QuantumNode.new(dummy_plot, initial_pos, grid_pos, stored_center)
	bubble.emoji_north = emoji
	bubble.emoji_south = "💀"
	bubble.biome_name = biome_name

	# Set initial visual properties
	var prob = biome.bath.get_probability(emoji)
	bubble.radius = base_bubble_size + pow(prob, size_exponent) * size_scale
	bubble.color = _get_emoji_color(emoji)

	# Store in graph arrays (don't add_child - QuantumNode extends RefCounted, not Node)
	graph.quantum_nodes.append(bubble)
	graph.node_by_plot_id[dummy_plot.plot_id] = bubble

	return bubble


func _create_basis_bubbles(biome_name: String) -> void:
	"""DEPRECATED - use request_emoji_bubble() instead

	This method is kept for backward compatibility but does nothing in plot-driven mode.
	"""
	pass


func _process(delta: float) -> void:
	"""Update bubble visuals from bath state and apply forces"""
	if not graph:
		return

	_update_bubble_visuals_from_bath()
	_apply_skating_rink_forces(delta)


func _update_bubble_visuals_from_bath() -> void:
	"""Update bubble size and color from bath probabilities

	Power law scaling (prob^0.3) gives better differentiation at low probabilities:
	- prob=0.01: pow=0.215 (2x better than sqrt)
	- prob=0.10: pow=0.464 (vs sqrt=0.316)
	- prob=0.50: pow=0.812 (vs sqrt=0.707)
	"""
	for biome_name in basis_bubbles:
		var biome = biomes.get(biome_name)
		if not biome or not biome.bath:
			continue

		var bubbles = basis_bubbles[biome_name]
		for bubble in bubbles:
			var emoji = bubble.emoji_north
			var prob = biome.bath.get_probability(emoji)
			var amp = biome.bath.get_amplitude(emoji)

			# Size: Power law scaling for better low-end differentiation
			bubble.radius = base_bubble_size + pow(prob, size_exponent) * size_scale

			# Color: Modulate brightness by probability
			var phase = amp.arg()
			var base_color = _get_emoji_color(emoji)
			var brightness = 0.5 + prob * 0.5
			bubble.color = base_color.lightened(brightness - 0.5)

			# Update dummy qubit phi for angular positioning (no radial orbit)
			# Model B: quantum_state no longer exists on plots - skip phi update


func _apply_skating_rink_forces(delta: float) -> void:
	"""Apply forces to position bubbles on biome ovals

	Bath-first change: We don't use probability/radius for radial positioning.
	All bubbles orbit around a fixed ring (70% of oval), with phi determining
	angular position.
	"""
	if not graph or not graph.layout_calculator:
		return

	for biome_name in basis_bubbles:
		var bubbles = basis_bubbles[biome_name]
		var oval = graph.layout_calculator.get_biome_oval(biome_name)
		if oval.is_empty():
			continue

		var center = oval.get("center", Vector2.ZERO)
		var semi_a = oval.get("semi_a", 100.0)
		var semi_b = oval.get("semi_b", 60.0)

		for bubble in bubbles:
			if not bubble.plot:
				continue

			# Model B: quantum_state no longer exists - use default phi from position
			var phi = 0.0

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


func _get_emoji_color(emoji: String) -> Color:
	"""Get base color for emoji"""
	match emoji:
		"☀", "☀️":
			return Color(1.0, 0.9, 0.3, 0.8)
		"🌙", "🌑":
			return Color(0.7, 0.7, 0.9, 0.8)
		"🌾":
			return Color(0.9, 0.8, 0.4, 0.8)
		"🍄":
			return Color(0.9, 0.3, 0.3, 0.8)
		"💀", "👥":
			return Color(0.8, 0.8, 0.8, 0.8)
		"🍂":
			return Color(0.7, 0.5, 0.3, 0.8)
		"🐺":
			return Color(0.6, 0.6, 0.6, 0.8)
		"🐇":
			return Color(0.9, 0.9, 0.9, 0.8)
		"🦌":
			return Color(0.7, 0.5, 0.4, 0.8)
		"🌿":
			return Color(0.3, 0.7, 0.3, 0.8)
		"🌲", "🌳":
			return Color(0.2, 0.6, 0.2, 0.8)
		"💧":
			return Color(0.3, 0.5, 0.9, 0.8)
		"⛰":
			return Color(0.5, 0.5, 0.5, 0.8)
		_:
			return Color(0.7, 0.7, 0.7, 0.8)
