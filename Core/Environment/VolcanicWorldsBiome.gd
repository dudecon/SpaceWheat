class_name VolcanicWorldsBiome
extends "res://Core/Environment/BiomeBase.gd"

## Volcanic Worlds Biome - Lava flows, crystal formation, and steam dynamics
##
## Architecture: QuantumComputer with 3-qubit tensor product
##
## Core Volcanic State (8D):
##   Qubit 0 (Temperature): 🔥 Lava / 🪨 Basalt
##   Qubit 1 (Resource):    💎 Crystals / ⛏ Raw Ore
##   Qubit 2 (Phase):       🌫 Steam / ✨ Sparks
##
## Basis States (tensor product):
##   |000⟩ = 🔥💎🌫 (Hot + Crystals + Steam) - active volcanic
##   |001⟩ = 🔥💎✨ (Hot + Crystals + Sparks) - eruption
##   |010⟩ = 🔥⛏🌫 (Hot + Ore + Steam) - mining opportunity
##   |011⟩ = 🔥⛏✨ (Hot + Ore + Sparks) - dangerous
##   |100⟩ = 🪨💎🌫 (Cool + Crystals + Steam) - formation zone
##   |101⟩ = 🪨💎✨ (Cool + Crystals + Sparks) - stable harvest
##   |110⟩ = 🪨⛏🌫 (Cool + Ore + Steam) - dormant
##   |111⟩ = 🪨⛏✨ (Cool + Ore + Sparks) - quiet state
##
## Physics:
##   - Temperature gradients drive crystal formation
##   - Lava cooling → basalt → crystals
##   - Steam vents at thermal interfaces

# ═══════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════

const ERUPTION_CYCLE_PERIOD = 90.0  # 90-second eruption cycles
const COOLING_RATE = 0.03  # Lava cools to rock
const CRYSTAL_FORMATION_RATE = 0.02  # Rock → Crystals (when hot)
const STEAM_GENERATION_RATE = 0.05  # Heat creates steam

# ═══════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════

var eruption_active: bool = false
var crystals_harvested: int = 0
var current_temperature_label: String = "🔥 Hot"

# ═══════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	super._ready()

	# Register emoji pairings for 3-qubit system
	register_emoji_pair("🔥", "🪨")  # Temperature axis
	register_emoji_pair("💎", "⛏")   # Resource axis
	register_emoji_pair("🌫", "✨")  # Phase axis

	# Register planting capabilities (mining operations)
	register_planting_capability("💎", "⛏", "crystal", {"🪨": 30}, "Crystal Mining", false)
	register_planting_capability("⛏", "💎", "ore", {"🪨": 10}, "Ore Extraction", false)

	# Configure visual properties for QuantumForceGraph
	visual_color = Color(1.0, 0.3, 0.1, 0.3)  # Lava orange-red
	visual_label = "🌋 Volcanic World"
	visual_center_offset = Vector2(1.15, -0.25)
	visual_oval_width = 400.0
	visual_oval_height = 250.0

	print("  ✅ VolcanicWorldsBiome initialized (QuantumComputer, 3 qubits)")


func _initialize_bath() -> void:
	"""Initialize QuantumComputer for Volcanic Worlds biome (3 qubits)."""
	print("🌋 Initializing Volcanic Worlds QuantumComputer...")

	# Create QuantumComputer with RegisterMap
	quantum_computer = QuantumComputer.new("VolcanicWorlds")

	# Allocate 3 qubits with emoji axes
	quantum_computer.allocate_axis(0, "🔥", "🪨")  # Temperature: Lava/Basalt
	quantum_computer.allocate_axis(1, "💎", "⛏")   # Resource: Crystal/Ore
	quantum_computer.allocate_axis(2, "🌫", "✨")  # Phase: Steam/Sparks

	# Initialize to dormant volcanic state |110⟩ = 🪨⛏🌫 (cool, ore, steam)
	quantum_computer.initialize_basis(6)

	print("  📊 RegisterMap configured (3 qubits, 8 basis states)")

	# Get Icons from IconRegistry
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_error("🌋 IconRegistry not available!")
		return

	# Get or create Icons for volcanic emojis
	var volcanic_emojis = ["🔥", "🪨", "💎", "⛏", "🌫", "✨"]
	var icons = {}

	for emoji in volcanic_emojis:
		var icon = icon_registry.get_icon(emoji)
		if not icon:
			# Create basic volcanic icon if not found
			icon = _create_volcanic_emoji_icon(emoji)
			icon_registry.register_icon(icon)
		icons[emoji] = icon

	# Configure volcanic-specific dynamics
	_configure_volcanic_dynamics(icons, icon_registry)

	# Build operators using cached method
	build_operators_cached("VolcanicWorldsBiome", icons)

	print("  ✅ Hamiltonian: %dx%d matrix" % [
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0,
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0
	])
	print("  ✅ Lindblad: %d operators + %d gated configs" % [
		quantum_computer.lindblad_operators.size(),
		quantum_computer.gated_lindblad_configs.size()])
	print("  🌋 Volcanic Worlds QuantumComputer ready!")


func _create_volcanic_emoji_icon(emoji: String) -> Icon:
	"""Create basic Icon for volcanic emoji."""
	var icon = Icon.new()
	icon.emoji = emoji
	icon.display_name = "Volcanic " + emoji

	# Set up basic couplings based on emoji role
	match emoji:
		"🔥":  # Fire/Lava - high energy, couples to rock
			icon.hamiltonian_couplings = {"🪨": 0.2}
			icon.self_energy = 0.5
			icon.decay_rate = COOLING_RATE
			icon.decay_target = "🪨"
		"🪨":  # Rock/Basalt - cool, stable
			icon.hamiltonian_couplings = {"🔥": 0.2}
			icon.self_energy = -0.2
		"💎":  # Crystal - valuable, formed from cooling
			icon.hamiltonian_couplings = {"⛏": 0.1}
			icon.self_energy = 0.4
		"⛏":  # Ore - raw resource
			icon.hamiltonian_couplings = {"💎": 0.1}
			icon.self_energy = -0.1
		"🌫":  # Steam - phase transition
			icon.hamiltonian_couplings = {"✨": 0.15}
			icon.self_energy = 0.1
		"✨":  # Sparks - energy release
			icon.hamiltonian_couplings = {"🌫": 0.15}
			icon.self_energy = 0.3

	return icon


func _configure_volcanic_dynamics(icons: Dictionary, _icon_registry) -> void:
	"""Configure volcanic-specific Icon dynamics."""
	# Temperature oscillation (lava ↔ rock)
	if icons.has("🔥") and icons.has("🪨"):
		icons["🔥"].hamiltonian_couplings["🪨"] = 0.2
		icons["🪨"].hamiltonian_couplings["🔥"] = 0.2

	# Crystal formation cycle (crystal ↔ ore)
	if icons.has("💎") and icons.has("⛏"):
		icons["💎"].hamiltonian_couplings["⛏"] = 0.1
		icons["⛏"].hamiltonian_couplings["💎"] = 0.1

	# Phase transitions (steam ↔ sparks)
	if icons.has("🌫") and icons.has("✨"):
		icons["🌫"].hamiltonian_couplings["✨"] = 0.15
		icons["✨"].hamiltonian_couplings["🌫"] = 0.15

	# Lindblad transfers: Heat creates steam
	if icons.has("🔥") and icons.has("🌫"):
		icons["🔥"].lindblad_outgoing["🌫"] = STEAM_GENERATION_RATE

	# Gated: Hot rock + cooling → crystals
	if icons.has("🪨"):
		icons["🪨"].gated_lindblad["💎"] = [{
			"source": "🪨",
			"rate": CRYSTAL_FORMATION_RATE,
			"gate": "🔥",  # Requires heat nearby
		}]

	# Mining yields crystals (ore → crystal)
	if icons.has("⛏") and icons.has("💎"):
		icons["⛏"].lindblad_outgoing["💎"] = 0.01

	# Steam discharges as sparks
	if icons.has("🌫") and icons.has("✨"):
		icons["🌫"].lindblad_outgoing["✨"] = 0.03

	# Decay: Lava cools to rock
	if icons.has("🔥"):
		icons["🔥"].decay_rate = COOLING_RATE
		icons["🔥"].decay_target = "🪨"

	# Crystals slowly degrade
	if icons.has("💎"):
		icons["💎"].decay_rate = 0.005
		icons["💎"].decay_target = "⛏"

	# Eruption driver (90-second cycles)
	if icons.has("🔥"):
		icons["🔥"].drivers["eruption"] = {
			"type": "periodic_eruption",
			"period": ERUPTION_CYCLE_PERIOD,
			"amplitude": 0.7,
		}


func rebuild_quantum_operators() -> void:
	"""Rebuild operators after IconRegistry is ready."""
	if not quantum_computer:
		return

	print("  🔧 VolcanicWorlds: Rebuilding quantum operators...")

	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		return

	var volcanic_emojis = ["🔥", "🪨", "💎", "⛏", "🌫", "✨"]
	var icons = {}

	for emoji in volcanic_emojis:
		var icon = icon_registry.get_icon(emoji)
		if icon:
			icons[emoji] = icon

	_configure_volcanic_dynamics(icons, icon_registry)

	build_operators_cached("VolcanicWorldsBiome", icons)

	print("  ✅ VolcanicWorlds: Rebuilt operators")


func _update_quantum_substrate(dt: float) -> void:
	"""Evolve volcanic quantum state."""
	if quantum_computer:
		quantum_computer.evolve(dt)

		# SEMANTIC TOPOLOGY: Record phase space trajectory
		_record_attractor_snapshot()

		# Update eruption state tracking
		_update_eruption_state()

	# Apply semantic drift game mechanics
	super._update_quantum_substrate(dt)


func _update_eruption_state() -> void:
	"""Track volcanic activity state."""
	var fire_pop = get_marginal_fire()
	var sparks_pop = get_marginal_sparks()

	# Eruption active when fire AND sparks are high
	eruption_active = fire_pop > 0.6 and sparks_pop > 0.5

	# Update temperature label
	if fire_pop > 0.7:
		current_temperature_label = "🔥 Extreme Heat"
	elif fire_pop > 0.5:
		current_temperature_label = "🔥 Hot"
	elif fire_pop > 0.3:
		current_temperature_label = "🪨 Warm"
	else:
		current_temperature_label = "🪨 Cool"


# ═══════════════════════════════════════════════════════════════════════════
# MARGINAL PROBABILITIES (Qubit Queries)
# ═══════════════════════════════════════════════════════════════════════════

func get_marginal_fire() -> float:
	"""P(🔥) = marginal probability of lava/heat."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_marginal(0, 0)  # Qubit 0, pole 0 (north = 🔥)


func get_marginal_crystals() -> float:
	"""P(💎) = marginal probability of crystals."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_marginal(1, 0)  # Qubit 1, pole 0 (north = 💎)


func get_marginal_steam() -> float:
	"""P(🌫) = marginal probability of steam."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_marginal(2, 0)  # Qubit 2, pole 0 (north = 🌫)


func get_marginal_sparks() -> float:
	"""P(✨) = marginal probability of sparks."""
	return 1.0 - get_marginal_steam()


# ═══════════════════════════════════════════════════════════════════════════
# VOLCANIC QUERIES
# ═══════════════════════════════════════════════════════════════════════════

func get_volcanic_intensity() -> float:
	"""Calculate volcanic activity intensity."""
	if not quantum_computer:
		return 0.5

	var fire = get_marginal_fire()
	var sparks = get_marginal_sparks()

	# Intensity = fire * sparks (both need to be high for eruption)
	return fire * sparks


func get_crystal_yield_potential() -> float:
	"""Calculate potential for crystal harvesting."""
	if not quantum_computer:
		return 0.5

	var crystals = get_marginal_crystals()
	var rock = 1.0 - get_marginal_fire()  # Cooler = more stable crystals

	# Best yield when crystals high AND temperature is moderate
	return crystals * rock


func is_erupting() -> bool:
	"""Check if volcano is currently erupting."""
	return eruption_active


# ═══════════════════════════════════════════════════════════════════════════
# VOLCANIC STATUS
# ═══════════════════════════════════════════════════════════════════════════

func get_volcanic_status() -> Dictionary:
	"""Get full volcanic state for UI display."""
	return {
		"fire": get_marginal_fire(),
		"rock": 1.0 - get_marginal_fire(),
		"temperature_label": current_temperature_label,
		"crystals": get_marginal_crystals(),
		"ore": 1.0 - get_marginal_crystals(),
		"steam": get_marginal_steam(),
		"sparks": get_marginal_sparks(),
		"eruption_active": eruption_active,
		"volcanic_intensity": get_volcanic_intensity(),
		"crystal_yield": get_crystal_yield_potential(),
		"crystals_harvested": crystals_harvested,
	}


func get_biome_type() -> String:
	"""Return biome type identifier."""
	return "VolcanicWorlds"
