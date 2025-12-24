class_name EcosystemGraphVisualizer
extends Control

## Hamiltonian Coupling Graph Visualization
##
## Real-time visualization of forest ecosystem as quantum graph:
##   Nodes = Trophic levels (size ∝ population)
##   Edges = Coupling strengths (width ∝ gᵢⱼ)
##   Color = Energy contribution (ωᵢ × Nᵢ)
##   Animation = Population dynamics
##
## This demonstrates force-directed graph principles suitable for
## transferring to QuantumForceGraph in main game.

## Node structure for graph layout
class EcosystemGraphNode:
	var icon: String
	var position: Vector2
	var velocity: Vector2 = Vector2.ZERO
	var population: float = 1.0
	var energy: float = 0.0
	var color: Color = Color.WHITE

	func _init(icon_str: String) -> void:
		icon = icon_str

## Edge structure for couplings
class EcosystemGraphEdge:
	var from_icon: String
	var to_icon: String
	var coupling_strength: float
	var current_interaction: float = 0.0  # |⟨aᵢ† aⱼ⟩| for pulsing

	func _init(from: String, to: String, strength: float) -> void:
		from_icon = from
		to_icon = to
		coupling_strength = strength

## Graph data
var nodes: Dictionary = {}  # icon → EcosystemGraphNode
var edges: Array[EcosystemGraphEdge] = []

## Forest reference (will be initialized in _ready)
var forest: Node = null
var patch_position: Vector2i = Vector2i(0, 0)

## Display parameters
var node_base_radius: float = 25.0
var node_max_radius: float = 80.0
var edge_base_width: float = 2.0
var edge_max_width: float = 12.0

## Force-directed layout parameters
var spring_strength: float = 0.3  # Attraction to center
var repulsion_strength: float = 50.0  # Node repulsion
var damping: float = 0.95  # Velocity damping
var center: Vector2

## Animation
var time_elapsed: float = 0.0
var pulse_speed: float = 3.0

## Colors (energy-based)
var color_scheme: Dictionary = {
	"plant": Color.from_hsv(0.3, 0.8, 0.9),      # Green
	"herbivore": Color.from_hsv(0.15, 0.9, 0.8), # Yellow
	"predator": Color.from_hsv(0.0, 0.9, 0.7),   # Red
	"apex": Color.from_hsv(0.7, 0.8, 0.8),       # Purple
	"decomposer": Color.from_hsv(0.05, 0.7, 0.6), # Brown
	"pollinator": Color.from_hsv(0.8, 0.9, 0.9),  # Pink
	"parasite": Color.from_hsv(0.5, 0.6, 0.7),    # Cyan
	"nitrogen_fixer": Color.from_hsv(0.4, 0.8, 0.8), # Teal
	"mycorrhizal": Color.from_hsv(0.55, 0.7, 0.7)    # Blue
}


func _ready() -> void:
	"""Initialize visualization"""
	size = get_viewport_rect().size
	center = size / 2.0

	# Create forest (load script dynamically)
	var ForestScript = load("res://Core/Environment/ForestEcosystem_Biome_v3_quantum_field.gd")
	if ForestScript:
		forest = ForestScript.new(1, 1)
		forest._ready()
	else:
		print("ERROR: Could not load ForestEcosystemBiomeV3 script")
		return

	# Initialize graph nodes and edges
	_setup_graph()

	# Start animation
	set_process(true)


func _setup_graph() -> void:
	"""Create graph nodes and edges from Hamiltonian structure"""

	# Define node layout (organized by trophic level)
	var node_layout = {
		# Core food chain (left side)
		"plant": Vector2(-300, -150),
		"herbivore": Vector2(-300, 0),
		"predator": Vector2(-300, 150),
		"apex": Vector2(-100, 75),

		# Ecosystem services (right side)
		"decomposer": Vector2(100, -150),
		"pollinator": Vector2(300, -150),
		"parasite": Vector2(100, 0),
		"nitrogen_fixer": Vector2(300, 0),
		"mycorrhizal": Vector2(200, 150)
	}

	# Create nodes
	for icon in node_layout.keys():
		var node = EcosystemGraphNode.new(icon)
		node.position = node_layout[icon] + center
		nodes[icon] = node

	# Define edges (couplings from Hamiltonian)
	var hamiltonian_couplings: Array[EcosystemGraphEdge] = [
		# Core food chain
		EcosystemGraphEdge.new("plant", "herbivore", 0.15),
		EcosystemGraphEdge.new("herbivore", "predator", 0.12),
		EcosystemGraphEdge.new("predator", "apex", 0.10),
		EcosystemGraphEdge.new("herbivore", "apex", 0.08),

		# Ecosystem services
		EcosystemGraphEdge.new("plant", "pollinator", 0.10),
		EcosystemGraphEdge.new("herbivore", "parasite", 0.06),  # Negative coupling
		EcosystemGraphEdge.new("decomposer", "plant", 0.08),
		EcosystemGraphEdge.new("decomposer", "herbivore", 0.05),
		EcosystemGraphEdge.new("decomposer", "predator", 0.04),
		EcosystemGraphEdge.new("mycorrhizal", "plant", 0.07),
		EcosystemGraphEdge.new("nitrogen_fixer", "decomposer", 0.05),
	]

	edges = hamiltonian_couplings


func _process(delta: float) -> void:
	"""Update and render graph"""
	time_elapsed += delta

	# Get current ecosystem state
	var N = forest.get_occupation_numbers(patch_position)

	# Update node data
	_update_node_populations(N)

	# Apply force-directed layout (optional: uncomment for dynamic layout)
	# _apply_forces(delta)

	# Update coupling interactions for pulsing
	_update_coupling_interactions(N)

	# Redraw
	queue_redraw()


func _update_node_populations(N: Dictionary) -> void:
	"""Update node sizes and colors based on populations"""
	for icon in nodes.keys():
		var node = nodes[icon]
		var population = N.get(icon, 1.0)

		# Population affects node size
		var radius_ratio = population / 5.0  # Normalize to ~1.0 at equilibrium
		node.population = population

		# Color based on energy (ωᵢ × Nᵢ)
		var base_color = color_scheme.get(icon, Color.WHITE)

		# Brightness ∝ energy contribution
		var energy_contribution = population  # Simplified; could use ωᵢ from Hamiltonian
		var brightness = clamp(0.3 + energy_contribution * 0.1, 0.3, 1.0)

		node.color = base_color * Color(brightness, brightness, brightness, 1.0)
		node.energy = energy_contribution


func _update_coupling_interactions(N: Dictionary) -> void:
	"""Update interaction strength for pulsing animation"""
	for edge in edges:
		# Interaction strength ∝ √(Nᵢ × Nⱼ) from Hamiltonian
		var from_pop = N.get(edge.from_icon, 1.0)
		var to_pop = N.get(edge.to_icon, 1.0)

		edge.current_interaction = sqrt(from_pop * to_pop)


func _apply_forces(delta: float) -> void:
	"""
	Apply force-directed layout to make graph adaptive
	(Optional: can be disabled for fixed layout)
	"""
	# Center attraction force
	for node in nodes.values():
		var direction_to_center = (center - node.position).normalized()
		var distance = node.position.distance_to(center)
		var spring_force = direction_to_center * spring_strength * distance

		node.velocity += spring_force

	# Repulsion between nodes (prevent overlap)
	var node_list = nodes.values()
	for i in range(node_list.size()):
		for j in range(i + 1, node_list.size()):
			var node_a = node_list[i]
			var node_b = node_list[j]

			var direction = (node_a.position - node_b.position).normalized()
			var distance = node_a.position.distance_to(node_b.position)

			if distance > 0.1:
				var repulsion = repulsion_strength / (distance * distance)
				node_a.velocity += direction * repulsion
				node_b.velocity -= direction * repulsion

	# Apply damping and update positions
	for node in nodes.values():
		node.velocity *= damping
		node.position += node.velocity * delta


func _draw() -> void:
	"""Render the graph"""
	# Draw edges (couplings) first (so they appear behind nodes)
	_draw_edges()

	# Draw nodes
	_draw_nodes()

	# Draw labels
	_draw_labels()


func _draw_edges() -> void:
	"""Draw coupling edges with varying width based on interaction strength"""
	for edge in edges:
		var from_node = nodes.get(edge.from_icon)
		var to_node = nodes.get(edge.to_icon)

		if not from_node or not to_node:
			continue

		# Base line width from coupling strength
		var base_width = edge_base_width + edge.coupling_strength * edge_max_width

		# Add pulsing based on current interaction
		var pulse = sin(time_elapsed * pulse_speed) * 0.5 + 0.5  # 0 to 1
		var interaction_pulse = edge.current_interaction * pulse
		var final_width = base_width + interaction_pulse * 3.0

		# Color based on coupling type
		var edge_color: Color
		if edge.coupling_strength > 0.10:
			edge_color = Color.WHITE  # Strong coupling
		elif edge.coupling_strength > 0.05:
			edge_color = Color(0.8, 0.8, 0.8, 0.8)  # Medium
		else:
			edge_color = Color(0.5, 0.5, 0.5, 0.6)  # Weak

		# Draw line with glow effect
		draw_line(from_node.position, to_node.position, edge_color, final_width)

		# Draw subtle glow (wider, more transparent)
		draw_line(from_node.position, to_node.position,
			Color(edge_color.r, edge_color.g, edge_color.b, 0.2),
			final_width * 2.5)


func _draw_nodes() -> void:
	"""Draw population nodes with size based on Nᵢ"""
	for node in nodes.values():
		# Node size ∝ population
		var radius_ratio = clamp(node.population / 5.0, 0.3, 2.0)
		var node_radius = node_base_radius * radius_ratio

		# Draw node with glow
		draw_circle(node.position, node_radius * 1.3,
			Color(node.color.r, node.color.g, node.color.b, 0.2))

		draw_circle(node.position, node_radius, node.color)

		# Draw outline
		draw_circle(node.position, node_radius, Color.WHITE, 2.0)

		# Draw energy indicator (inner circle brightness)
		var energy_ratio = clamp(node.energy / 5.0, 0.1, 1.0)
		var inner_radius = node_radius * 0.4 * energy_ratio
		draw_circle(node.position, inner_radius,
			Color(1.0, 1.0, 1.0, 0.6))


func _draw_labels() -> void:
	"""Draw icon labels on nodes"""
	var label_font = get_theme_font("font")
	var label_size = get_theme_font_size("font_size")

	for node in nodes.values():
		var text = node.icon

		# Measure text to center it
		var text_size = label_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size)
		var text_pos = node.position - text_size / 2.0

		draw_string(label_font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			label_size, Color.BLACK)


func update_forest() -> void:
	"""Manually trigger forest update (call this each frame from game loop)"""
	forest._update_quantum_substrate(get_physics_process_delta_time())


# Information methods for game integration
func get_ecosystem_health() -> float:
	"""Get overall ecosystem health metric"""
	return forest.get_ecosystem_health(patch_position)


func get_coupling_strength() -> float:
	"""Get overall coupling/cascade strength"""
	return forest.get_trophic_cascade_indicator(patch_position)


func get_node_position(icon: String) -> Vector2:
	"""Get screen position of a node (for connecting to other UI)"""
	if icon in nodes:
		return nodes[icon].position
	return Vector2.ZERO


func get_node_energy(icon: String) -> float:
	"""Get energy contribution of a trophic level"""
	if icon in nodes:
		return nodes[icon].energy
	return 0.0
