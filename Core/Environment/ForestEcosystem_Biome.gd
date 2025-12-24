class_name ForestEcosystem_Biome
extends "res://Core/Environment/BiomeBase.gd"

const BiomePlot = preload("res://Core/GameMechanics/BiomePlot.gd")
const QuantumOrganism = preload("res://Core/Environment/QuantumOrganism.gd")

## Quantum Forest Ecosystem Biome
##
## A complete predator-prey ecosystem modeled as quantum state transitions.
## Uses Markov chains for ecological succession and population dynamics.
##
## All organisms and states are quantum icons (dual-emoji qubits).
## No classical energy tracking - pure quantum superpositions.
##
## Food Web:
##   🌱🌿🌲 (Producers)
##   ↓
##   🐰🐛🐭 (Herbivores)
##   ↓
##   🐦🐱🐺 (Carnivores)
##   ↓
##   🦅 (Apex)
##
## Resources:
##   🐺 Wolf → 💧 Water
##   🦅 Eagle → 🌬️ Wind
##   🐦 Bird → 🥚 Eggs
##   🌲 Forest → 🍎 Apples

## Ecological state enum
enum EcologicalState {
	BARE_GROUND,      # 🏜️
	SEEDLING,         # 🌱
	SAPLING,          # 🌿
	MATURE_FOREST,    # 🌲
	DEAD_FOREST       # ☠️
}

## Grid of patches
var patches: Dictionary = {}  # Vector2i → EcosystemPatch (stored as dict for now)
var grid_width: int = 0
var grid_height: int = 0

## Global weather state (quantum)
var weather_qubit: DualEmojiQubit  # (🌬️ wind, 💧 water)
var season_qubit: DualEmojiQubit   # (☀️ sun, 🌧️ rain)

## Update period for ecosystem simulation
var update_period: float = 1.0

## Resource tracking
var total_water_harvested: float = 0.0
var total_apples_harvested: float = 0.0
var total_eggs_harvested: float = 0.0

## Organism definitions (icons and what they produce/eat)
var organism_definitions: Dictionary = {
	"🐺": {"name": "Wolf", "produces": "💧", "eats": ["🐰", "🐭"], "level": "carnivore"},
	"🦅": {"name": "Eagle", "produces": "🌬️", "eats": ["🐦", "🐰", "🐭"], "level": "apex"},
	"🐦": {"name": "Bird", "produces": "🥚", "eats": ["🐛"], "level": "carnivore"},
	"🐱": {"name": "Cat", "produces": "🐱", "eats": ["🐭", "🐰"], "level": "carnivore"},
	"🐰": {"name": "Rabbit", "produces": "🌱", "eats": ["🌱"], "level": "herbivore"},
	"🐛": {"name": "Caterpillar", "produces": "🐛", "eats": ["🌱"], "level": "herbivore"},
	"🐭": {"name": "Mouse", "produces": "🐭", "eats": ["🌱"], "level": "herbivore"}
}


func _init(width: int = 6, height: int = 1):
	"""Backward compatibility: Set grid dimensions before _ready()"""
	grid_width = width
	grid_height = height


func _ready():
	"""Initialize forest ecosystem with grid of patches"""
	super._ready()

	# HAUNTED UI FIX: Guard against double-initialization
	if weather_qubit != null:
		if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_FOREST") == "1":
			print("⚠️  ForestEcosystem_Biome._ready() called multiple times, skipping re-initialization")
		return

	# Create weather qubits
	weather_qubit = BiomeUtilities.create_qubit("🌬️", "💧", PI / 2.0)
	weather_qubit.radius = 1.0

	season_qubit = BiomeUtilities.create_qubit("☀️", "🌧️", PI / 2.0)
	season_qubit.radius = 1.0

	# Use defaults if not set by _init()
	if grid_width == 0:
		grid_width = 6
	if grid_height == 0:
		grid_height = 1

	# Initialize patches
	for x in range(grid_width):
		for y in range(grid_height):
			var pos = Vector2i(x, y)
			patches[pos] = _create_patch(pos)

	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_FOREST") == "1":
		print("🌲 Forest Ecosystem initialized (%dx%d)" % [grid_width, grid_height])

	# Configure visual properties for QuantumForceGraph
	visual_color = Color(0.3, 0.7, 0.3, 0.3)  # Green
	visual_label = "🌲 Forest"
	visual_center_offset = Vector2(0.8, -0.7)   # Far edge - suggests bigger scope
	visual_oval_width = 350.0   # Larger oval
	visual_oval_height = 216.0  # Golden ratio: 350/1.618

	# Initialize forest icons (if grid available)
	if grid:
		_initialize_forest_icons()


func _update_quantum_substrate(dt: float) -> void:
	"""Override parent: Update weather and all patches"""
	# Update weather
	_update_weather()

	# Update all patches
	for pos in patches.keys():
		_update_patch(pos, dt)


func _create_patch(position: Vector2i) -> BiomePlot:
	"""Create ecosystem patch with Markov transition graph"""
	var plot = BiomePlot.new(BiomePlot.BiomePlotType.ENVIRONMENT)
	plot.plot_id = "forest_patch_%d_%d" % [position.x, position.y]
	plot.grid_position = position
	plot.parent_biome = self

	# Ecosystem state qubit (succession: 🏜️→🌱→🌿→🌲)
	var state_qubit = DualEmojiQubit.new("🏜️", "🌱", PI / 2.0)
	state_qubit.radius = 0.1  # Bare ground has low energy
	state_qubit.phi = 0.0
	state_qubit.add_graph_edge("🔄", "🌱")  # Bare → Seedling
	plot.quantum_state = state_qubit

	# Store ecosystem metadata
	plot.set_meta("ecological_state", EcologicalState.BARE_GROUND)
	plot.set_meta("organisms", {})  # icon → QuantumOrganism
	plot.set_meta("time_in_state", 0.0)

	return plot


func _initialize_forest_icons():
	"""Initialize forest icons and register them with the grid (scoped to Forest biome)"""
	# Load icon classes
	var ForestEcosystemIcon = load("res://Core/Icons/ForestEcosystemIcon.gd")
	var ForestWeatherIcon = load("res://Core/Icons/ForestWeatherIcon.gd")

	if not ForestEcosystemIcon or not ForestWeatherIcon:
		push_error("Failed to load forest icon classes!")
		return

	# Create and register Ecosystem Icon
	var ecosystem_icon = ForestEcosystemIcon.new()
	ecosystem_icon.set_activation(0.8)
	grid.add_scoped_icon(ecosystem_icon, ["Forest"])

	# Create and register Weather Icon
	var weather_icon = ForestWeatherIcon.new()
	weather_icon.weather_type = "wind"
	weather_icon.set_activation(0.6)
	grid.add_scoped_icon(weather_icon, ["Forest"])


func _update_weather():
	"""Simulate weather changes"""
	# Slow oscillation between wind and water
	weather_qubit.theta += 0.01
	if weather_qubit.theta > TAU:
		weather_qubit.theta = 0.0

	# Seasonal oscillation
	season_qubit.theta += 0.005
	if season_qubit.theta > TAU:
		season_qubit.theta = 0.0


func _update_patch(position: Vector2i, delta: float):
	"""Update a single patch: ecology + quantum organisms"""
	var patch = patches[position]

	var time_in_state = patch.get_meta("time_in_state") if patch.has_meta("time_in_state") else 0.0
	patch.set_meta("time_in_state", time_in_state + delta)

	# Step 1: Apply ecological succession (Markov transition)
	_apply_ecological_transition(patch)

	# Step 2: Quantum organism dynamics (predation, survival, reproduction)
	_update_quantum_organisms(patch, delta)

	# Step 3: Update patch qubit state
	_update_patch_qubit(patch)


func _update_quantum_organisms(patch: BiomePlot, delta: float):
	"""Update all organisms in patch using quantum mechanics and graph topology"""
	var organisms_dict = patch.get_meta("organisms") if patch.has_meta("organisms") else {}
	var organisms_list = []
	var predators_list = []

	# Collect organisms and identify predators
	for icon in organisms_dict.keys():
		var org = organisms_dict[icon]
		if org.alive:
			organisms_list.append(org)
			# Check if this organism hunts others (has 🍴 edges)
			if org.qubit.get_graph_targets("🍴").size() > 0:
				predators_list.append(org)

	# Update each organism
	for org in organisms_list:
		if not org.alive:
			continue

		# Find predators that hunt THIS organism
		var my_predators = []
		for pred in predators_list:
			if pred.qubit.has_graph_edge("🍴", org.icon):
				my_predators.append(pred)

		# Quantum update: survival instinct, hunting, reproduction, eating
		var available_food = _get_patch_food_energy(patch)
		org.update(delta, organisms_list, available_food, my_predators)

		# Handle reproduction - create offspring
		if org.offspring_created > 0:
			for i in range(org.offspring_created):
				var spec = org.get_offspring_spec()
				var baby = QuantumOrganism.new(spec["icon"], spec["type"])
				baby.qubit.radius = spec["health"]
				# Use unique key for multiple organisms of same type
				var unique_key = spec["icon"] + "_" + str(randi())
				organisms_dict[unique_key] = baby
			org.offspring_created = 0

	# Remove dead organisms
	var dead_icons = []
	for icon in organisms_dict.keys():
		if not organisms_dict[icon].alive:
			dead_icons.append(icon)
	for icon in dead_icons:
		organisms_dict.erase(icon)

	# Update patch metadata
	patch.set_meta("organisms", organisms_dict)


func _get_patch_food_energy(patch: BiomePlot) -> float:
	"""Calculate available food energy based on ecological state"""
	var state = patch.get_meta("ecological_state") if patch.has_meta("ecological_state") else EcologicalState.BARE_GROUND
	match state:
		EcologicalState.SEEDLING:
			return 2.0
		EcologicalState.SAPLING:
			return 4.0
		EcologicalState.MATURE_FOREST:
			return 8.0
		_:
			return 0.0


func _apply_ecological_transition(patch: BiomePlot):
	"""Markov chain transition based on current state"""
	var current_state = patch.get_meta("ecological_state") if patch.has_meta("ecological_state") else EcologicalState.BARE_GROUND
	var organisms = patch.get_meta("organisms") if patch.has_meta("organisms") else {}
	var wind_prob = sin(weather_qubit.theta / 2.0) ** 2
	var water_prob = cos(weather_qubit.theta / 2.0) ** 2
	var sun_prob = sin(season_qubit.theta / 2.0) ** 2

	# Determine transition probabilities
	var transition_prob = 0.0

	match current_state:
		EcologicalState.BARE_GROUND:
			# Bare → Seedling requires wind + water
			transition_prob = wind_prob * water_prob * 0.7
			if randf() < transition_prob:
				patch.set_meta("ecological_state", EcologicalState.SEEDLING)
				patch.set_meta("time_in_state", 0.0)
				if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_FOREST") == "1":
					print("🏜️ → 🌱 Seedling sprouted at %s" % patch.grid_position)

		EcologicalState.SEEDLING:
			# Seedling → Sapling requires survival + growth
			var base_prob = 0.3
			if organisms.has("🐺"):  # Wolf eats rabbits
				base_prob = 0.4
			if organisms.has("🦅"):  # Eagle eats herbivores
				base_prob = 0.35
			if water_prob > 0.6:
				base_prob += 0.1

			transition_prob = base_prob
			if randf() < transition_prob:
				patch.set_meta("ecological_state", EcologicalState.SAPLING)
				patch.set_meta("time_in_state", 0.0)
				if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_FOREST") == "1":
					print("🌱 → 🌿 Sapling grown at %s" % patch.grid_position)

			# Could also die from herbivores
			if organisms.has("🐰") and randf() < 0.1:
				patch.set_meta("ecological_state", EcologicalState.BARE_GROUND)
				patch.set_meta("time_in_state", 0.0)
				if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_FOREST") == "1":
					print("🌱 → 🏜️ Eaten by rabbits at %s" % patch.grid_position)

		EcologicalState.SAPLING:
			# Sapling → Mature Forest
			transition_prob = 0.2 + (water_prob * 0.1) + (sun_prob * 0.05)
			if randf() < transition_prob:
				patch.set_meta("ecological_state", EcologicalState.MATURE_FOREST)
				patch.set_meta("time_in_state", 0.0)
				if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_FOREST") == "1":
					print("🌿 → 🌲 Mature forest at %s" % patch.grid_position)

		EcologicalState.MATURE_FOREST:
			# Forest can die (rare)
			transition_prob = 0.02  # Background death rate
			if (1.0 - water_prob) > 0.8:  # Drought
				transition_prob = 0.1
			if randf() < transition_prob:
				patch.set_meta("ecological_state", EcologicalState.BARE_GROUND)
				patch.set_meta("time_in_state", 0.0)
				if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_FOREST") == "1":
					print("🌲 → 🏜️ Forest died at %s" % patch.grid_position)

	# Update Markov transition graph to reflect new state
	_update_patch_transition_graph(patch)




func _update_patch_transition_graph(patch: BiomePlot):
	"""Update Markov transition graph based on current ecological state (pure emoji topology)"""
	var state_qubit = patch.quantum_state
	if not state_qubit:
		return
	# Clear old transitions
	state_qubit.entanglement_graph.clear()

	# Build transition graph based on current state (🔄 = can transition to)
	var current_state = patch.get_meta("ecological_state") if patch.has_meta("ecological_state") else EcologicalState.BARE_GROUND
	match current_state:
		EcologicalState.BARE_GROUND:
			state_qubit.add_graph_edge("🔄", "🌱")  # Can become seedling

		EcologicalState.SEEDLING:
			state_qubit.add_graph_edge("🔄", "🌿")  # Can become sapling
			state_qubit.add_graph_edge("🔄", "🏜️")  # Can be eaten (back to bare)

		EcologicalState.SAPLING:
			state_qubit.add_graph_edge("🔄", "🌲")  # Can become forest
			state_qubit.add_graph_edge("🔄", "🌱")  # Can regress under stress

		EcologicalState.MATURE_FOREST:
			state_qubit.add_graph_edge("🔄", "🏜️")  # Can die (fire/disease)
			state_qubit.add_graph_edge("💧", "🍎")  # Produces apples
			state_qubit.add_graph_edge("💧", "☀️")  # Produces energy


func _update_patch_qubit(patch: BiomePlot):
	"""Update the patch's state qubit to reflect ecological state"""
	var state = patch.get_meta("ecological_state") if patch.has_meta("ecological_state") else EcologicalState.BARE_GROUND
	match state:
		EcologicalState.BARE_GROUND:
			patch.quantum_state.radius = 0.1
		EcologicalState.SEEDLING:
			patch.quantum_state.radius = 0.3
		EcologicalState.SAPLING:
			patch.quantum_state.radius = 0.6
		EcologicalState.MATURE_FOREST:
			patch.quantum_state.radius = 0.9
		EcologicalState.DEAD_FOREST:
			patch.quantum_state.radius = 0.0


func add_organism(position: Vector2i, organism_icon: String) -> bool:
	"""Add a quantum organism to a patch"""
	if not patches.has(position):
		return false

	var patch = patches[position]
	var organisms = patch.get_meta("organisms") if patch.has_meta("organisms") else {}

	# Create QuantumOrganism instead of bare qubit
	# This gives us full behavioral instincts and graph topology
	var organism = QuantumOrganism.new(organism_icon, "")  # Auto-detects type
	organism.qubit.radius = 0.5  # Start at medium strength

	organisms[organism_icon] = organism
	patch.set_meta("organisms", organisms)
	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_FOREST") == "1":
		print("➕ Added %s at %s" % [organism_icon, position])
	return true


func get_biome_type() -> String:
	"""Return biome type identifier"""
	return "ForestEcosystem"


func harvest_water(position: Vector2i = Vector2i(-1, -1)) -> DualEmojiQubit:
	"""
	Harvest water from wolves in a patch.
	If position is (-1,-1), harvest from first patch with wolves.
	"""
	var target_patch = null

	if position != Vector2i(-1, -1):
		target_patch = patches.get(position)
	else:
		# Find patch with wolves
		for pos in patches.keys():
			var patch = patches[pos]
			var organisms = patch.get_meta("organisms") if patch.has_meta("organisms") else {}
			if organisms.has("🐺"):
				target_patch = patch
				break

	if not target_patch:
		return null

	var organisms = target_patch.get_meta("organisms") if target_patch.has_meta("organisms") else {}
	if not organisms.has("🐺"):
		return null

	var wolf = organisms["🐺"]
	var water_amount = wolf.radius * 0.3

	var water_qubit = BiomeUtilities.create_qubit("💧", "☀️", PI / 2.0)
	water_qubit.radius = water_amount

	total_water_harvested += water_amount

	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_FOREST") == "1":
		print("💧 Harvested %.2f water from wolf at %s" % [water_amount, target_patch.grid_position])
	return water_qubit


func get_ecosystem_status() -> Dictionary:
	"""Get current state of all patches"""
	var status = {
		"patches": [],
		"organisms_count": 0,
		"weather": {
			"wind_prob": sin(weather_qubit.theta / 2.0) ** 2,
			"water_prob": cos(weather_qubit.theta / 2.0) ** 2,
			"sun_prob": sin(season_qubit.theta / 2.0) ** 2
		},
		"total_water_harvested": total_water_harvested,
		"simulation_time": time_tracker.time_elapsed
	}

	for pos in patches.keys():
		var patch = patches[pos]
		var organisms = patch.get_meta("organisms") if patch.has_meta("organisms") else {}
		var patch_state = patch.get_meta("ecological_state") if patch.has_meta("ecological_state") else EcologicalState.BARE_GROUND
		var organism_list = []
		for icon in organisms.keys():
			organism_list.append({
				"icon": icon,
				"strength": organisms[icon].radius
			})

		status["patches"].append({
			"position": pos,
			"state": EcologicalState.keys()[patch_state],
			"organisms": organism_list
		})
		status["organisms_count"] += organism_list.size()

	return status


func get_state_name(state: int) -> String:
	"""Get readable name for ecological state"""
	match state:
		EcologicalState.BARE_GROUND:
			return "Bare Ground (🏜️)"
		EcologicalState.SEEDLING:
			return "Seedling (🌱)"
		EcologicalState.SAPLING:
			return "Sapling (🌿)"
		EcologicalState.MATURE_FOREST:
			return "Mature Forest (🌲)"
		EcologicalState.DEAD_FOREST:
			return "Dead Forest (☠️)"
		_:
			return "Unknown"


func _reset_custom() -> void:
	"""Override parent: Reset ecosystem to initial state"""
	patches.clear()
	total_water_harvested = 0.0
	total_apples_harvested = 0.0
	total_eggs_harvested = 0.0

	for x in range(grid_width):
		for y in range(grid_height):
			var pos = Vector2i(x, y)
			patches[pos] = _create_patch(pos)

	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_FOREST") == "1":
		print("🌲 Forest Ecosystem reset")

func render_biome_content(graph: Node2D, center: Vector2, radius: float) -> void:
	"""Render forest ecosystem state + weather/season qubits inside forest circle"""
	var font = ThemeDB.fallback_font

	# 1. DOMINANT ECOSYSTEM STATE (center, large emoji)
	var dominant_state = _get_dominant_state()
	var state_emoji = _get_ecosystem_emoji(dominant_state)

	# Shadow for visibility against green background
	var emoji_pos = center + Vector2(0, 5)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx != 0 or dy != 0:
				graph.draw_string(font, emoji_pos + Vector2(dx, dy), state_emoji,
						   HORIZONTAL_ALIGNMENT_CENTER, -1, 48, Color(0, 0, 0, 0.8))
	graph.draw_string(font, emoji_pos, state_emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, 48, Color.WHITE)

	# 2. WEATHER QUBIT (top-left mini Bloch sphere)
	if weather_qubit:
		_draw_mini_bloch_sphere(graph, center + Vector2(-50, -radius + 50),
							   weather_qubit, 15.0)

	# 3. SEASON QUBIT (top-right mini Bloch sphere)
	if season_qubit:
		_draw_mini_bloch_sphere(graph, center + Vector2(50, -radius + 50),
							   season_qubit, 15.0)

	# 4. ORGANISM COUNT (bottom)
	var count = _count_organisms()
	var count_pos = center + Vector2(0, radius - 30)
	graph.draw_string(font, count_pos, "%d 🐾" % count, HORIZONTAL_ALIGNMENT_CENTER, -1, 12,
			   Color(0.9, 0.9, 0.9, 0.8))


func _get_dominant_state() -> int:
	"""Get the dominant ecological state across all forest patches"""
	var state_counts = {}
	for pos in patches.keys():
		var patch = patches[pos]
		var state = patch.get_meta("ecological_state") if patch.has_meta("ecological_state") else 0
		state_counts[state] = state_counts.get(state, 0) + 1

	var max_count = 0
	var dominant = 0
	for state in state_counts.keys():
		if state_counts[state] > max_count:
			max_count = state_counts[state]
			dominant = state
	return dominant


func _get_ecosystem_emoji(state: int) -> String:
	"""Convert ecological state to emoji"""
	match state:
		0: return "🏜️"  # BARE_GROUND
		1: return "🌱"  # SEEDLING
		2: return "🌿"  # SAPLING
		3: return "🌲"  # MATURE_FOREST
		4: return "☠️"  # DEAD_FOREST
		_: return "?"


func _count_organisms() -> int:
	"""Count total organisms across all forest patches"""
	var total = 0
	for pos in patches.keys():
		var patch = patches[pos]
		if patch.has_meta("organisms"):
			total += patch.get_meta("organisms").size()
	return total


func _draw_mini_bloch_sphere(graph: Node2D, center: Vector2, qubit: DualEmojiQubit, radius: float) -> void:
	"""Draw a mini Bloch sphere representation for a qubit"""
	var font = ThemeDB.fallback_font

	# Circle outline
	graph.draw_arc(center, radius, 0, TAU, 32, Color(1, 1, 1, 0.3), 1.0)

	# North/south emojis (poles)
	graph.draw_string(font, center + Vector2(0, -radius - 8), qubit.north_emoji,
			   HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(1, 1, 1, 0.7))
	graph.draw_string(font, center + Vector2(0, radius + 8), qubit.south_emoji,
			   HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(1, 1, 1, 0.7))

	# State pointer (from center towards state angle)
	var pointer_end = center + Vector2(0, -radius * 0.7).rotated(qubit.theta - PI/2)
	graph.draw_line(center, pointer_end, Color(1, 1, 1, 0.9), 1.5, true)
	graph.draw_circle(pointer_end, 2.0, Color(1, 1, 1, 0.9))
