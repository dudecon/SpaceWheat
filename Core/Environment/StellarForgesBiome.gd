class_name StellarForgesBiome
extends "res://Core/Environment/BiomeBase.gd"

const Icon = preload("res://Core/QuantumSubstrate/Icon.gd")

## Stellar Forges Biome - Industrial space production with ship building
##
## Architecture: QuantumComputer with 3-qubit tensor product
##
## Core Forge State (8D):
##   Qubit 0 (Energy):     ⚡ Power / 🔋 Storage
##   Qubit 1 (Production): ⚙ Fabrication / 🔩 Raw Materials
##   Qubit 2 (Output):     🚀 Rocket / 🛸 Saucer
##
## Basis States (tensor product):
##   |000⟩ = ⚡⚙🚀 (Powered + Fabricating + Rockets) - peak production
##   |001⟩ = ⚡⚙🛸 (Powered + Fabricating + Saucers)
##   |010⟩ = ⚡🔩🚀 (Powered + Raw + Rockets)
##   |011⟩ = ⚡🔩🛸 (Powered + Raw + Saucers)
##   |100⟩ = 🔋⚙🚀 (Stored + Fabricating + Rockets)
##   |101⟩ = 🔋⚙🛸 (Stored + Fabricating + Saucers)
##   |110⟩ = 🔋🔩🚀 (Stored + Raw + Rockets)
##   |111⟩ = 🔋🔩🛸 (Stored + Raw + Saucers) - idle state
##
## Physics:
##   - Energy oscillation drives production cycles
##   - Gated Lindblad: Gears + Energy → Ships
##   - Primary exports: 🚀 and 🛸

# ═══════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════

const ENERGY_CYCLE_PERIOD = 30.0  # 30-second power cycles
const PRODUCTION_RATE = 0.02  # Base ship production rate
const ENERGY_DECAY_RATE = 0.01  # Battery discharge rate

# ═══════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════

var total_rockets_produced: int = 0
var total_saucers_produced: int = 0

# ═══════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	super._ready()

	# Register emoji pairings for 3-qubit system
	register_emoji_pair("⚡", "🔋")  # Energy axis
	register_emoji_pair("⚙", "🔩")  # Production axis
	register_emoji_pair("🚀", "🛸")  # Output axis

	# Legacy planting capabilities removed (vocabulary injection is the only expansion path)

	# Configure visual properties for QuantumForceGraph
	visual_color = Color(1.0, 0.8, 0.2, 0.3)  # Golden yellow
	visual_label = "🚀 Stellar Forge"
	visual_center_offset = Vector2(-1.15, -0.25)
	visual_oval_width = 400.0
	visual_oval_height = 250.0

	print("  ✅ StellarForgesBiome initialized (QuantumComputer, 3 qubits)")


func _initialize_bath() -> void:
	"""Initialize QuantumComputer for Stellar Forges biome (3 qubits)."""
	print("🚀 Initializing Stellar Forges QuantumComputer...")

	# Create QuantumComputer with RegisterMap
	quantum_computer = QuantumComputer.new("StellarForges")

	# Allocate 3 qubits with emoji axes
	quantum_computer.allocate_axis(0, "⚡", "🔋")  # Energy: Power/Storage
	quantum_computer.allocate_axis(1, "⚙", "🔩")  # Production: Active/Raw
	quantum_computer.allocate_axis(2, "🚀", "🛸")  # Output: Rocket/Saucer

	# Initialize to powered idle state |010⟩ = ⚡🔩🚀 (energy ready, raw materials)
	quantum_computer.initialize_basis(2)

	print("  📊 RegisterMap configured (3 qubits, 8 basis states)")

	# Get Icons from IconRegistry
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_error("🚀 IconRegistry not available!")
		return

	# Get or create Icons for forge emojis
	var forge_emojis = ["⚡", "🔋", "⚙", "🔩", "🚀", "🛸"]
	var icons = {}

	for emoji in forge_emojis:
		var icon = icon_registry.get_icon(emoji)
		if not icon:
			# Create basic forge icon if not found
			icon = _create_forge_emoji_icon(emoji)
			icon_registry.register_icon(icon)
		icons[emoji] = icon

	# Configure forge-specific dynamics
	_configure_forge_dynamics(icons, icon_registry)

	# Build operators using cached method
	build_operators_cached("StellarForgesBiome", icons)

	print("  ✅ Hamiltonian: %dx%d matrix" % [
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0,
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0
	])
	print("  ✅ Lindblad: %d operators + %d gated configs" % [
		quantum_computer.lindblad_operators.size(),
		quantum_computer.gated_lindblad_configs.size()])
	print("  🚀 Stellar Forges QuantumComputer ready!")


func _create_forge_emoji_icon(emoji: String) -> Icon:
	"""Create basic Icon for forge emoji."""
	var icon = Icon.new()
	icon.emoji = emoji
	icon.display_name = "Forge " + emoji

	# Set up basic couplings based on emoji role
	match emoji:
		"⚡":  # Energy - couples to battery (charging cycle)
			icon.hamiltonian_couplings = {"🔋": 0.3}
			icon.self_energy = 0.5
		"🔋":  # Battery - couples to energy
			icon.hamiltonian_couplings = {"⚡": 0.3}
			icon.self_energy = -0.2
			icon.decay_rate = ENERGY_DECAY_RATE
			icon.decay_target = "⚡"
		"⚙":  # Gears - active fabrication
			icon.hamiltonian_couplings = {"🔩": 0.2}
			icon.self_energy = 0.3
		"🔩":  # Bolts - raw materials
			icon.hamiltonian_couplings = {"⚙": 0.2}
			icon.self_energy = -0.1
		"🚀":  # Rocket - output option 1
			icon.hamiltonian_couplings = {"🛸": 0.05}
			icon.self_energy = 0.4
		"🛸":  # Saucer - output option 2
			icon.hamiltonian_couplings = {"🚀": 0.05}
			icon.self_energy = 0.4

	return icon


func _configure_forge_dynamics(icons: Dictionary, _icon_registry) -> void:
	"""Configure forge-specific Icon dynamics."""
	# Energy oscillation (power ↔ storage)
	if icons.has("⚡") and icons.has("🔋"):
		icons["⚡"].hamiltonian_couplings["🔋"] = 0.3
		icons["🔋"].hamiltonian_couplings["⚡"] = 0.3

	# Production cycle (fabrication ↔ raw materials)
	if icons.has("⚙") and icons.has("🔩"):
		icons["⚙"].hamiltonian_couplings["🔩"] = 0.2
		icons["🔩"].hamiltonian_couplings["⚙"] = 0.2

	# Output preference (slow drift between rocket/saucer)
	if icons.has("🚀") and icons.has("🛸"):
		icons["🚀"].hamiltonian_couplings["🛸"] = 0.05
		icons["🛸"].hamiltonian_couplings["🚀"] = 0.05

	# Energy powers production
	if icons.has("⚡") and icons.has("⚙"):
		icons["⚡"].lindblad_outgoing["⚙"] = 0.15

	# Gated production: Gears + Energy → Rockets
	if icons.has("⚙"):
		icons["⚙"].gated_lindblad["🚀"] = [{
			"source": "⚙",
			"rate": PRODUCTION_RATE,
			"gate": "⚡",
		}]
		# Gears + Battery → Saucers
		icons["⚙"].gated_lindblad["🛸"] = [{
			"source": "⚙",
			"rate": PRODUCTION_RATE,
			"gate": "🔋",
		}]

	# Raw materials → active production
	if icons.has("🔩") and icons.has("⚙"):
		icons["🔩"].lindblad_outgoing["⚙"] = 0.05

	# Battery decay (discharge)
	if icons.has("🔋"):
		icons["🔋"].decay_rate = ENERGY_DECAY_RATE
		icons["🔋"].decay_target = "⚡"

	# Energy driver (30-second power cycles)
	if icons.has("⚡"):
		icons["⚡"].drivers["pulse"] = {
			"type": "oscillator",
			"period": ENERGY_CYCLE_PERIOD,
			"amplitude": 0.4,
		}


func rebuild_quantum_operators() -> void:
	"""Rebuild operators after IconRegistry is ready."""
	if not quantum_computer:
		return

	print("  🔧 StellarForges: Rebuilding quantum operators...")

	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		return

	var forge_emojis = ["⚡", "🔋", "⚙", "🔩", "🚀", "🛸"]
	var icons = {}

	for emoji in forge_emojis:
		var icon = icon_registry.get_icon(emoji)
		if icon:
			icons[emoji] = icon

	_configure_forge_dynamics(icons, icon_registry)

	build_operators_cached("StellarForgesBiome", icons)

	print("  ✅ StellarForges: Rebuilt operators")


func _update_quantum_substrate(dt: float) -> void:
	"""Evolve forge quantum state."""
	if quantum_computer:
		quantum_computer.evolve(dt, max_evolution_dt)

		# SEMANTIC TOPOLOGY: Record phase space trajectory
		_record_attractor_snapshot()

	# Apply semantic drift game mechanics
	super._update_quantum_substrate(dt)


# ═══════════════════════════════════════════════════════════════════════════
# MARGINAL PROBABILITIES (Qubit Queries)
# ═══════════════════════════════════════════════════════════════════════════

func get_marginal_energy() -> float:
	"""P(⚡) = marginal probability of active power."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_marginal(0, 0)  # Qubit 0, pole 0 (north = ⚡)


func get_marginal_production() -> float:
	"""P(⚙) = marginal probability of active fabrication."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_marginal(1, 0)  # Qubit 1, pole 0 (north = ⚙)


func get_marginal_rockets() -> float:
	"""P(🚀) = marginal probability of rocket output preference."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_marginal(2, 0)  # Qubit 2, pole 0 (north = 🚀)


# ═══════════════════════════════════════════════════════════════════════════
# PRODUCTION QUERIES
# ═══════════════════════════════════════════════════════════════════════════

func get_production_efficiency() -> float:
	"""Calculate current production efficiency from quantum state."""
	if not quantum_computer:
		return 0.5

	var energy = get_marginal_energy()
	var production = get_marginal_production()

	# Efficiency = energy * production (both need to be high)
	return energy * production


func get_output_bias() -> String:
	"""Get current output bias (Rockets vs Saucers)."""
	var rocket_prob = get_marginal_rockets()
	if rocket_prob > 0.6:
		return "🚀 Rockets"
	elif rocket_prob < 0.4:
		return "🛸 Saucers"
	else:
		return "⚖️ Balanced"


# ═══════════════════════════════════════════════════════════════════════════
# FORGE STATUS
# ═══════════════════════════════════════════════════════════════════════════

func get_forge_status() -> Dictionary:
	"""Get full forge state for UI display."""
	return {
		"energy": get_marginal_energy(),
		"energy_label": _get_energy_label(),
		"production": get_marginal_production(),
		"efficiency": get_production_efficiency(),
		"rocket_bias": get_marginal_rockets(),
		"output_label": get_output_bias(),
		"total_rockets": total_rockets_produced,
		"total_saucers": total_saucers_produced,
	}


func _get_energy_label() -> String:
	"""Convert energy probability to human label."""
	var energy = get_marginal_energy()
	if energy > 0.7:
		return "⚡ High Power"
	elif energy > 0.4:
		return "⚡ Normal"
	else:
		return "🔋 Low Power"


func get_biome_type() -> String:
	"""Return biome type identifier."""
	return "StellarForges"
