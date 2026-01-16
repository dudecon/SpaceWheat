class_name ForestEcosystem_Biome
extends "res://Core/Environment/BiomeBase.gd"

const BiomePlot = preload("res://Core/GameMechanics/BiomePlot.gd")
const QuantumOrganism = preload("res://Core/Environment/QuantumOrganism.gd")

## Quantum Forest Ecosystem Biome v3: Unified QuantumComputer Architecture
##
## Architecture: QuantumComputer with 5-qubit tensor product (32 states)
## 22 forest emojis mapped to 11 north/south pairs on 5 qubits + 1 auxiliary
##
## Qubit Structure:
##   Qubit 0 (Weather): ☀ Sun / 🌙 Moon (drives growth cycles)
##   Qubit 1 (Vegetation): 🌿 Green / 🍂 Decay (producer layer)
##   Qubit 2 (Herbivore): 🐇 Prey / 🐺 Predator (consumer layer)
##   Qubit 3 (Resources): 💧 Water / 🔥 Fire (environmental drivers)
##   Qubit 4 (Structure): 🌲 Forest / 🏡 Shelter (ecosystem structure)
##
## Dynamics (via Icon-defined operators):
##   - Weather: Hamiltonian oscillation (day/night cycle)
##   - Vegetation: Lindblad transfer (growth from sun/water)
##   - Predation: Lindblad transfer (🐺 gains from 🐇)
##   - Decay: Lindblad relaxation (organic → decomposition)

## Ecological state enum (legacy - for patch metadata)
enum EcologicalState {
	BARE_GROUND,
	SEEDLING,
	SAPLING,
	MATURE_FOREST,
	DEAD_FOREST
}

# Grid of patches
var patches: Dictionary = {}
var grid_width: int = 0
var grid_height: int = 0

# Global weather state (derived from quantum computer)
var weather_qubit: DualEmojiQubit
var season_qubit: DualEmojiQubit

# Update period for ecosystem simulation
var update_period: float = 1.0

# Resource tracking
var total_water_harvested: float = 0.0
var total_apples_harvested: float = 0.0
var total_eggs_harvested: float = 0.0

# Organism definitions
var organism_definitions: Dictionary = {
	"🐺": {"name": "Wolf", "produces": "💧", "eats": ["🐇"], "level": "predator"},
	"🦅": {"name": "Eagle", "produces": "🌬️", "eats": ["🐦", "🐇"], "level": "apex"},
	"🐦": {"name": "Bird", "produces": "🥚", "eats": ["🐛"], "level": "carnivore"},
	"🐇": {"name": "Rabbit", "produces": "🌱", "eats": ["🌿"], "level": "herbivore"},
}


func _init(width: int = 6, height: int = 1):
	"""Set grid dimensions before _ready()"""
	grid_width = width
	grid_height = height


func _ready():
	"""Initialize forest ecosystem"""
	super._ready()

	# Register emoji pairings for 5-qubit system
	register_emoji_pair("☀", "🌙")   # Weather axis
	register_emoji_pair("🌿", "🍂")  # Vegetation axis
	register_emoji_pair("🐇", "🐺")  # Consumer axis
	register_emoji_pair("💧", "🔥")  # Resource axis
	register_emoji_pair("🌲", "🏡")  # Structure axis

	# Register planting capabilities (Parametric System - Phase 1)
	# Forest-exclusive organisms (require Forest biome)
	register_planting_capability("🌿", "🍂", "vegetation", {"🌿": 10}, "Vegetation", true)
	register_planting_capability("🐇", "🍂", "rabbit", {"🐇": 10}, "Rabbit", true)
	register_planting_capability("🐺", "🍂", "wolf", {"🐺": 10}, "Wolf", true)

	# Configure visual properties for QuantumForceGraph
	visual_color = Color(0.3, 0.7, 0.3, 0.3)
	visual_label = "🌲 Forest"
	visual_center_offset = Vector2(0.65, -0.25)
	visual_oval_width = 560.0
	visual_oval_height = 350.0

	# Initialize legacy weather qubits for compatibility
	weather_qubit = BiomeUtilities.create_qubit("🌬️", "💧", 0.0)
	season_qubit = BiomeUtilities.create_qubit("☀", "🌧️", 0.0)

	print("  ✅ ForestEcosystem v3 initialized (QuantumComputer, 5 qubits)")


func _initialize_bath() -> void:
	"""Initialize QuantumComputer for Forest biome (5 qubits)."""
	print("🌲 Initializing Forest QuantumComputer...")

	# Create QuantumComputer with RegisterMap
	quantum_computer = QuantumComputer.new("Forest")

	# Allocate 5 qubits with emoji axes
	quantum_computer.allocate_axis(0, "☀", "🌙")   # Weather: Sun/Moon
	quantum_computer.allocate_axis(1, "🌿", "🍂")  # Vegetation: Green/Decay
	quantum_computer.allocate_axis(2, "🐇", "🐺")  # Consumer: Prey/Predator
	quantum_computer.allocate_axis(3, "💧", "🔥")  # Resource: Water/Fire
	quantum_computer.allocate_axis(4, "🌲", "🏡")  # Structure: Forest/Shelter

	# Initialize to balanced forest state
	# |00000⟩ = ☀🌿🐇💧🌲 (sunny, green, prey, water, forest)
	quantum_computer.initialize_basis(0)

	print("  📊 RegisterMap configured (5 qubits, 32 basis states)")

	# Get Icons from IconRegistry
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_error("🌲 IconRegistry not available!")
		return

	# Get or create Icons for forest emojis
	var forest_emojis = ["☀", "🌙", "🌿", "🍂", "🐇", "🐺", "💧", "🔥", "🌲", "🏡"]
	var icons = {}

	for emoji in forest_emojis:
		var icon = icon_registry.get_icon(emoji)
		if not icon:
			icon = _create_forest_emoji_icon(emoji)
			icon_registry.register_icon(icon)
		icons[emoji] = icon

	# Configure forest-specific dynamics
	_configure_forest_dynamics(icons, icon_registry)

	# Build operators using cached method
	build_operators_cached("ForestEcosystem_Biome", icons)

	print("  ✅ Hamiltonian: %dx%d matrix" % [
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0,
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0
	])
	print("  ✅ Lindblad: %d operators + %d gated configs" % [
		quantum_computer.lindblad_operators.size(),
		quantum_computer.gated_lindblad_configs.size()])
	print("  🌲 Forest QuantumComputer ready!")


func _create_forest_emoji_icon(emoji: String) -> Icon:
	"""Create basic Icon for forest emoji."""
	var icon = Icon.new()
	icon.emoji = emoji
	icon.display_name = "Forest " + emoji

	match emoji:
		"☀":  # Sun drives growth
			icon.hamiltonian_couplings = {"🌙": 0.15}
			icon.self_energy = 1.0
		"🌙":  # Moon (night)
			icon.hamiltonian_couplings = {"☀": 0.15}
			icon.self_energy = -0.5
		"🌿":  # Vegetation - grows from sun/water
			icon.hamiltonian_couplings = {"🍂": 0.05}
			icon.lindblad_incoming = {"☀": 0.08, "💧": 0.06}
			icon.self_energy = 0.3
		"🍂":  # Decay - natural death
			icon.hamiltonian_couplings = {"🌿": 0.05}
			icon.self_energy = -0.2
		"🐇":  # Prey - grows from vegetation
			icon.hamiltonian_couplings = {"🐺": 0.1}
			icon.lindblad_incoming = {"🌿": 0.12}
			icon.decay_rate = 0.02
			icon.decay_target = "🍂"
			icon.self_energy = 0.2
		"🐺":  # Predator - grows from prey
			icon.hamiltonian_couplings = {"🐇": 0.1}
			icon.lindblad_incoming = {"🐇": 0.10}
			icon.decay_rate = 0.03
			icon.decay_target = "🍂"
			icon.self_energy = 0.4
		"💧":  # Water - environmental driver
			icon.hamiltonian_couplings = {"🔥": 0.08}
			icon.self_energy = 0.1
		"🔥":  # Fire - destructive
			icon.hamiltonian_couplings = {"💧": 0.08}
			icon.lindblad_outgoing = {"🍂": 0.15}  # Fire creates decay
			icon.self_energy = -0.3
		"🌲":  # Forest structure
			icon.hamiltonian_couplings = {"🏡": 0.03}
			icon.lindblad_incoming = {"🌿": 0.05, "💧": 0.04}
			icon.self_energy = 0.5
		"🏡":  # Shelter - provides protection
			icon.hamiltonian_couplings = {"🌲": 0.03}
			icon.lindblad_incoming = {"🌲": 0.02}
			icon.self_energy = 0.1

	return icon


func _configure_forest_dynamics(icons: Dictionary, icon_registry) -> void:
	"""Configure forest-specific Lotka-Volterra dynamics."""
	# Predator-prey oscillations
	if icons.has("🐺") and icons.has("🐇"):
		icons["🐺"].lindblad_incoming["🐇"] = 0.10  # Wolf eats rabbit
		icons["🐇"].lindblad_outgoing["🐺"] = 0.08  # Rabbit dies to wolf

	# Vegetation growth from resources
	if icons.has("🌿"):
		if icons.has("☀"):
			icons["🌿"].lindblad_incoming["☀"] = 0.08
		if icons.has("💧"):
			icons["🌿"].lindblad_incoming["💧"] = 0.06

	# Forest growth from vegetation
	if icons.has("🌲") and icons.has("🌿"):
		icons["🌲"].lindblad_incoming["🌿"] = 0.04


func rebuild_quantum_operators() -> void:
	"""Rebuild operators after IconRegistry is ready."""
	if not quantum_computer:
		return

	print("  🔧 Forest: Rebuilding quantum operators...")

	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		return

	var forest_emojis = ["☀", "🌙", "🌿", "🍂", "🐇", "🐺", "💧", "🔥", "🌲", "🏡"]
	var icons = {}

	for emoji in forest_emojis:
		var icon = icon_registry.get_icon(emoji)
		if icon:
			icons[emoji] = icon

	_configure_forest_dynamics(icons, icon_registry)

	build_operators_cached("ForestEcosystem_Biome", icons)

	print("  ✅ Forest: Rebuilt operators")


func _update_quantum_substrate(dt: float) -> void:
	"""Evolve forest quantum state."""
	if quantum_computer:
		quantum_computer.evolve(dt)

		# SEMANTIC TOPOLOGY: Record phase space trajectory
		_record_attractor_snapshot()

	# Apply semantic drift game mechanics (🌀 chaos vs ✨ stability)
	super._update_quantum_substrate(dt)

	# Update legacy weather qubits from quantum state
	_update_weather_from_quantum()


func _update_weather_from_quantum() -> void:
	"""Update legacy weather qubits from quantum computer state."""
	if not quantum_computer:
		return

	# Get sun/moon populations
	var p_sun = quantum_computer.get_population("☀")
	var p_water = quantum_computer.get_population("💧")

	# Update legacy qubits for compatibility
	if weather_qubit:
		weather_qubit.theta = PI * (1.0 - p_water)
	if season_qubit:
		season_qubit.theta = PI * (1.0 - p_sun)


# ═══════════════════════════════════════════════════════════════════════════
# ECOSYSTEM QUERIES
# ═══════════════════════════════════════════════════════════════════════════

func get_vegetation_level() -> float:
	"""P(🌿) = probability of healthy vegetation."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_population("🌿")


func get_predator_level() -> float:
	"""P(🐺) = probability of predator dominance."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_population("🐺")


func get_prey_level() -> float:
	"""P(🐇) = probability of prey abundance."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_population("🐇")


func get_water_level() -> float:
	"""P(💧) = probability of water availability."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_population("💧")


func get_forest_health() -> float:
	"""Combined forest health metric."""
	var vegetation = get_vegetation_level()
	var water = get_water_level()
	var forest = quantum_computer.get_population("🌲") if quantum_computer else 0.5
	return (vegetation + water + forest) / 3.0


# ═══════════════════════════════════════════════════════════════════════════
# PATCH MANAGEMENT (Legacy Compatibility)
# ═══════════════════════════════════════════════════════════════════════════

func _create_patch(position: Vector2i) -> BiomePlot:
	"""Create ecosystem patch."""
	var plot = BiomePlot.new(BiomePlot.BiomePlotType.ENVIRONMENT)
	plot.plot_id = "forest_patch_%d_%d" % [position.x, position.y]
	plot.grid_position = position
	plot.parent_biome = self

	plot.set_meta("ecological_state", EcologicalState.BARE_GROUND)
	plot.set_meta("organisms", {})
	plot.set_meta("time_in_state", 0.0)

	return plot


func add_organism(position: Vector2i, organism_icon: String) -> bool:
	"""Add organism to patch."""
	if not patches.has(position):
		return false

	var patch = patches[position]
	var organisms = patch.get_meta("organisms") if patch.has_meta("organisms") else {}

	var organism = QuantumOrganism.new(organism_icon, "")
	organism.qubit.radius = 0.5

	organisms[organism_icon] = organism
	patch.set_meta("organisms", organisms)
	return true


# ═══════════════════════════════════════════════════════════════════════════
# RESOURCE HARVESTING
# ═══════════════════════════════════════════════════════════════════════════

func harvest_water(position: Vector2i = Vector2i(-1, -1)) -> DualEmojiQubit:
	"""Harvest water from ecosystem."""
	var water_amount = get_water_level() * 0.3

	var water_qubit = BiomeUtilities.create_qubit("💧", "☀️", PI / 2.0)
	water_qubit.radius = water_amount

	total_water_harvested += water_amount
	return water_qubit


# ═══════════════════════════════════════════════════════════════════════════
# STATUS AND RENDERING
# ═══════════════════════════════════════════════════════════════════════════

func get_ecosystem_status() -> Dictionary:
	"""Get current ecosystem state."""
	return {
		"vegetation": get_vegetation_level(),
		"predators": get_predator_level(),
		"prey": get_prey_level(),
		"water": get_water_level(),
		"forest_health": get_forest_health(),
		"patches": patches.size(),
		"total_water_harvested": total_water_harvested,
		"simulation_time": time_tracker.time_elapsed
	}


func get_biome_type() -> String:
	"""Return biome type identifier."""
	return "ForestEcosystem"


func render_biome_content(graph: Node2D, center: Vector2, radius: float) -> void:
	"""Render forest state inside force graph circle."""
	var font = ThemeDB.fallback_font

	# Dominant state emoji
	var health = get_forest_health()
	var state_emoji = "🌲" if health > 0.6 else ("🌿" if health > 0.3 else "🍂")

	# Shadow for visibility
	var emoji_pos = center + Vector2(0, 5)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx != 0 or dy != 0:
				graph.draw_string(font, emoji_pos + Vector2(dx, dy), state_emoji,
						   HORIZONTAL_ALIGNMENT_CENTER, -1, 48, Color(0, 0, 0, 0.8))
	graph.draw_string(font, emoji_pos, state_emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, 48, Color.WHITE)

	# Health indicator
	var health_pos = center + Vector2(0, radius - 30)
	graph.draw_string(font, health_pos, "%.0f%% 🌳" % (health * 100), HORIZONTAL_ALIGNMENT_CENTER, -1, 12,
			   Color(0.9, 0.9, 0.9, 0.8))


func _reset_custom() -> void:
	"""Reset ecosystem to initial state."""
	patches.clear()
	total_water_harvested = 0.0
	total_apples_harvested = 0.0
	total_eggs_harvested = 0.0

	for x in range(grid_width):
		for y in range(grid_height):
			var pos = Vector2i(x, y)
			patches[pos] = _create_patch(pos)

	print("🌲 Forest Ecosystem reset")
