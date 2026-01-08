class_name ForestEcosystem_Biome
extends "res://Core/Environment/BiomeBase.gd"

const BiomePlot = preload("res://Core/GameMechanics/BiomePlot.gd")
const QuantumOrganism = preload("res://Core/Environment/QuantumOrganism.gd")

## Forest Markov Chain (from forest_emoji_simulation_v11.json)
## Used to derive Icon interactions for bath-first mode
const FOREST_MARKOV = {
	"⛰": {"🌳": 0.6, "☔": 0.4},
	"☀": {"🌳": 0.5, "🌱": 0.3, "🌿": 0.2},
	"☔": {"💧": 0.5, "☀": 0.3, "💨": 0.2},
	"🌳": {"⛰": 0.3, "🌲": 0.3, "🏡": 0.2, "🌿": 0.2, "🌳": 0.1},
	"🌰": {"🍯": 0.2, "🌼": 0.2, "🍂": 0.2, "🌱": 0.4},
	"🐝": {"🌼": 0.5, "🍯": 0.5},
	"🌲": {"🏡": 0.3, "🍂": 0.3, "🐦": 0.4, "🌰": 0.2, "🌳": 0.2},
	"🌱": {"⛰": 0.4, "☀": 0.3, "🌲": 0.3},
	"🐇": {"🏡": 0.5, "🍂": 0.3, "🐺": 0.2, "🦅": 0.1},
	"🦌": {"🏡": 0.5, "🍂": 0.3, "🐺": 0.3},
	"🦅": {"💨": 0.3, "🌳": 0.5, "🐜": 0.2},
	"💧": {"🌳": 0.4, "🌲": 0.3, "⛰": 0.3},
	"💨": {"🌼": 0.3, "🌱": 0.3, "⛰": 0.4},
	"🐺": {"🌳": 0.5, "💧": 0.3, "🌿": 0.2},
	"🌿": {"🍂": 0.2, "🐇": 0.5, "🦌": 0.3},
	"🍄": {"🍂": 0.5, "⛰": 0.5},
	"🐜": {"🍯": 0.3, "🌰": 0.3, "🐦": 0.2, "🦅": 0.2},
	"🐦": {"🐜": 0.3, "🌱": 0.3, "🦅": 0.2, "🌲": 0.2, "🏡": 0.2},
	"🍂": {"🍄": 0.5, "🐜": 0.5},
	"🌼": {"🐝": 0.4, "🍯": 0.2, "🌱": 0.4},
	"🍯": {"🌰": 0.5, "🐜": 0.5},
	"🏡": {"🐇": 0.3, "🦌": 0.3, "🐦": 0.4}
}

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


func _initialize_bath_forest() -> void:
	"""Initialize quantum bath for Forest biome (Phase 5 - Bath-First)

	Forest emojis (22 total): ⛰ ☀ ☔ 🌳 🌰 🐝 🌲 🌱 🐇 🦌 🦅 💧 💨 🐺 🌿 🍄 🐜 🐦 🍂 🌼 🍯 🏡
	Dynamics:
	  - Predator-prey: 🐺 eats 🐇/🦌, 🦅 eats 🐦/🐜/🐇
	  - Herbivores: 🐇/🦌 eat 🌿, 🐦 eats 🐜
	  - Producers: 🌱/🌿/🌲 grow from ☀/💧/⛰
	  - Decomposition: 🍂 → 🍄 → ⛰ (nutrient cycling)
	  - Emergent Lotka-Volterra oscillations expected
	"""
	print("🛁 Initializing Forest quantum bath...")

	# Get IconRegistry (now guaranteed to be first autoload)
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_error("🛁 IconRegistry not available!")
		return

	# Derive Icons from Markov chain
	# This automatically creates Icons with H (symmetric) and L (asymmetric) terms
	# Only derive if not already present (avoid overwriting faction-built Icons)
	var icons_to_derive = {}
	for emoji in FOREST_MARKOV:
		if not icon_registry.has_icon(emoji):
			icons_to_derive[emoji] = FOREST_MARKOV[emoji]

	if not icons_to_derive.is_empty():
		# Lindblad rate scale: 10x slower for amplitude-based bath physics
		icon_registry.derive_from_markov(icons_to_derive, 0.3, 0.015)  # Was 0.15
		print("  ✅ Derived %d Icons from Markov chain" % icons_to_derive.size())
	else:
		print("  ✅ All %d emojis already have Icons" % FOREST_MARKOV.size())

	# Tune predator-prey dynamics for realistic oscillations
	# Increase Lindblad transfer rates for predation
	_tune_predator_prey_icons(icon_registry)

	# Create bath with forest emoji basis
	bath = QuantumBath.new()
	var emojis = FOREST_MARKOV.keys()
	bath.initialize_with_emojis(emojis)

	# Initialize weighted distribution based on trophic levels
	# More base resources (soil, water, vegetation) than predators
	bath.initialize_weighted({
		"⛰": 0.10,   # Soil - foundation
		"☀": 0.08,   # Sunlight - driver
		"💧": 0.08,   # Water - essential
		"☔": 0.04,   # Weather - driver
		"💨": 0.04,   # Wind - dispersal
		"🌳": 0.08,   # Forest - structure
		"🌲": 0.08,   # Tree - structure
		"🌱": 0.06,   # Seedling - growth
		"🌿": 0.10,   # Vegetation - base producer
		"🌰": 0.02,   # Brazilian nut - special
		"🐝": 0.02,   # Orchid bee - pollinator
		"🌼": 0.03,   # Pollination - process
		"🍯": 0.02,   # Nectar - resource
		"🍄": 0.04,   # Fungus - decomposer
		"🍂": 0.06,   # Organic matter - recycling
		"🐜": 0.04,   # Bugs - base prey
		"🐇": 0.05,   # Rabbit - primary prey
		"🦌": 0.03,   # Deer - large herbivore
		"🐦": 0.03,   # Bird - small predator
		"🐺": 0.02,   # Wolf - apex predator
		"🦅": 0.01,   # Eagle - apex predator
		"🏡": 0.03    # Shelter - protection
	})

	# Collect Icons from registry
	var icons: Array[Icon] = []
	for emoji in emojis:
		var icon = icon_registry.get_icon(emoji)
		if icon:
			icons.append(icon)
		else:
			push_warning("🛁 Icon not found for emoji: " + emoji)

	# Build Hamiltonian and Lindblad operators
	bath.active_icons = icons
	bath.build_hamiltonian_from_icons(icons)
	bath.build_lindblad_from_icons(icons)

	print("  ✅ Bath initialized with %d emojis, %d icons" % [emojis.size(), icons.size()])
	print("  ✅ Hamiltonian: %d non-zero terms" % bath.hamiltonian_sparse.size())
	print("  ✅ Lindblad: %d transfer terms" % bath.lindblad_terms.size())
	print("  🌲 Forest ecosystem ready for emergent Lotka-Volterra dynamics!")


func _tune_predator_prey_icons(icon_registry) -> void:
	"""Tune predator-prey Icons for realistic dynamics

	Increase Lindblad transfer rates for predation to ensure
	strong enough coupling for Lotka-Volterra oscillations
	"""
	# Wolf predation (🐺 gains from 🐇 rabbit, 🦌 deer)
	# 10x slower rates for amplitude-based bath physics
	var wolf = icon_registry.get_icon("🐺")
	if wolf:
		wolf.lindblad_incoming["🐇"] = 0.012  # Strong predation on rabbits (was 0.12)
		wolf.lindblad_incoming["🦌"] = 0.008  # Moderate predation on deer (was 0.08)
		wolf.decay_rate = 0.03  # Wolves die without food
		wolf.decay_target = "🍂"
		print("  🐺 Wolf: Predation tuned (🐇: 0.012, 🦌: 0.008, decay: 0.03)")

	# Eagle predation (🦅 gains from 🐦 bird, 🐜 bugs, 🐇 rabbit)
	var eagle = icon_registry.get_icon("🦅")
	if eagle:
		eagle.lindblad_incoming["🐦"] = 0.010  # Was 0.10, 10x slower
		eagle.lindblad_incoming["🐜"] = 0.008  # Was 0.08, 10x slower
		eagle.lindblad_incoming["🐇"] = 0.006  # Was 0.06, 10x slower
		eagle.decay_rate = 0.04  # Eagles die without prey
		eagle.decay_target = "🍂"
		print("  🦅 Eagle: Predation tuned (🐦: 0.010, 🐜: 0.008, 🐇: 0.006, decay: 0.04)")

	# Rabbit herbivory (🐇 gains from 🌿 vegetation)
	var rabbit = icon_registry.get_icon("🐇")
	if rabbit:
		rabbit.lindblad_incoming["🌿"] = 0.015  # Strong herbivory (was 0.15, 10x slower)
		rabbit.decay_rate = 0.02  # Natural death rate
		rabbit.decay_target = "🍂"
		print("  🐇 Rabbit: Herbivory tuned (🌿: 0.015, decay: 0.02)")

	# Deer herbivory (🦌 gains from 🌿 vegetation)
	var deer = icon_registry.get_icon("🦌")
	if deer:
		deer.lindblad_incoming["🌿"] = 0.012  # Moderate herbivory (was 0.12, 10x slower)
		deer.decay_rate = 0.02
		deer.decay_target = "🍂"
		print("  🦌 Deer: Herbivory tuned (🌿: 0.012, decay: 0.02)")

	# Vegetation growth (🌿 gains from ☀ sunlight, 💧 water, 🍂 organic matter)
	var vegetation = icon_registry.get_icon("🌿")
	if vegetation:
		# These should already be set by faction-built Icons, but ensure they're strong enough
		if not vegetation.lindblad_incoming.has("☀"):
			vegetation.lindblad_incoming["☀"] = 0.10
		if not vegetation.lindblad_incoming.has("💧"):
			vegetation.lindblad_incoming["💧"] = 0.06
		if not vegetation.lindblad_incoming.has("🍂"):
			vegetation.lindblad_incoming["🍂"] = 0.04
		print("  🌿 Vegetation: Growth rates ensured (☀: 0.10, 💧: 0.06, 🍂: 0.04)")


func _ready():
	"""Initialize forest ecosystem with grid of patches"""
	super._ready()

	# Configure visual properties for QuantumForceGraph (BEFORE early return!)
	# Layout: Forest (7890) in top-right corner - moved right by 1/10 screen width
	visual_color = Color(0.3, 0.7, 0.3, 0.3)  # Green
	visual_label = "🌲 Forest"
	visual_center_offset = Vector2(0.65, -0.25)  # Moved right: 0.45 + 0.2 for extra 1/10
	visual_oval_width = 560.0   # 2x larger
	visual_oval_height = 350.0  # Golden ratio maintained

	print("  ✅ ForestEcosystem initialized (bath-Lindblad, 22 emojis)")


func _initialize_bath() -> void:
	"""Initialize quantum bath for Forest biome (Bath-First)"""
	_initialize_bath_forest()


func _update_quantum_substrate(dt: float) -> void:
	"""Override parent: Evolve forest quantum bath (Lindblad evolution)

	Forest uses bath-based architecture due to 22-dimensional emoji space
	(2^22 = 4M states would be too large for dense matrix Model C).
	The bath.evolve() performs sparse Lindblad evolution efficiently.
	"""
	if bath:
		bath.evolve(dt)


func _create_patch(position: Vector2i) -> BiomePlot:
	"""Create ecosystem patch with Markov transition graph"""
	var plot = BiomePlot.new(BiomePlot.BiomePlotType.ENVIRONMENT)
	plot.plot_id = "forest_patch_%d_%d" % [position.x, position.y]
	plot.grid_position = position
	plot.parent_biome = self

	# Model B: Ecosystem state tracked via metadata only
	# (State evolution would happen through quantum_computer if needed)
	# State qubit left unregistered - forest succession is deterministic Markov, not quantum

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
	"""Model B: Markov state transitions tracked via metadata (not quantum evolution)"""
	# Transitions are deterministic based on ecological state
	# No quantum state qubit to update - transitions happen via _update_patch_qubit()
	pass


func _update_patch_qubit(patch: BiomePlot):
	"""Model B: Ecological state reflected through quantum_computer when needed

	Patch succession (🏜️→🌱→🌿→🌲) is tracked via metadata (ecological_state).
	Quantum evolution would happen through parent biome's quantum_computer if interactions needed.
	"""
	# Metadata-only tracking - no qubit manipulation needed
	pass


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
			var org = organisms[icon]
			var strength = org.qubit.radius if org and org.qubit else 0.0
			organism_list.append({
				"icon": icon,
				"strength": strength
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
