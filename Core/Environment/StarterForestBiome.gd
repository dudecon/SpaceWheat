class_name StarterForestBiome
extends "res://Core/Environment/BiomeBase.gd"

const Icon = preload("res://Core/QuantumSubstrate/Icon.gd")

## Starter Forest Biome - Classic ecosystem with predator/prey dynamics
## Celestial cycle (sun/moon), wolves/rabbits, eagles/deer, forest lifecycle, plant growth
##
## Faction themes: Pack Lords + Swift Herd + Verdant Pulse + Celestial Archons

# ═══════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════

const PREDATION_RATE = 0.15  # Wolves hunt rabbits
const APEX_HUNT_RATE = 0.12  # Eagles hunt deer
const DECAY_RATE = 0.1      # Trees decay
const GROWTH_RATE = 0.1     # Seedlings grow

# ═══════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	super._ready()

	# Register emoji pairings for 5-qubit system
	register_emoji_pair("☀", "🌙")   # Celestial axis
	register_emoji_pair("🐺", "🐇")  # Predator/Prey axis
	register_emoji_pair("🦅", "🦌")  # Apex/Herbivore axis
	register_emoji_pair("🌲", "🍂")  # Forest Lifecycle axis
	register_emoji_pair("🌱", "🌿")  # Growth axis

	# Configure visual properties for QuantumForceGraph
	visual_color = Color(0.2, 0.7, 0.3, 0.3)  # Forest green
	visual_label = "🌲 Starter Forest"
	visual_center_offset = Vector2(-0.45, -0.45)  # Top-left (T position)
	visual_oval_width = 640.0
	visual_oval_height = 400.0

	print("  ✅ StarterForestBiome initialized (QuantumComputer, 5 qubits)")


func _initialize_bath() -> void:
	"""Initialize QuantumComputer for Starter Forest biome (5 qubits)."""
	print("🌲 Initializing Starter Forest QuantumComputer...")

	# Create QuantumComputer with RegisterMap
	quantum_computer = QuantumComputer.new("StarterForest")

	# Allocate 5 qubits with emoji axes
	quantum_computer.allocate_axis(0, "☀", "🌙")   # Celestial: Sun/Moon
	quantum_computer.allocate_axis(1, "🐺", "🐇")  # Predator/Prey: Wolf/Rabbit
	quantum_computer.allocate_axis(2, "🦅", "🦌")  # Apex/Herbivore: Eagle/Deer
	quantum_computer.allocate_axis(3, "🌲", "🍂")  # Forest Lifecycle: Tree/Decay
	quantum_computer.allocate_axis(4, "🌱", "🌿")  # Growth: Seedling/Vegetation

	# Initialize to day state with balanced ecosystem |00000⟩ = ☀🐺🦅🌲🌱
	quantum_computer.initialize_basis(0)

	print("  📊 RegisterMap configured (5 qubits, 32 basis states)")

	# Get Icons from IconRegistry
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_error("🌲 IconRegistry not available!")
		return

	# Get or create Icons for forest emojis
	var forest_emojis = ["☀", "🌙", "🐺", "🐇", "🦅", "🦌", "🌲", "🍂", "🌱", "🌿"]
	var icons = {}

	for emoji in forest_emojis:
		var icon = icon_registry.get_icon(emoji)
		if not icon:
			# Create basic forest icon if not found
			icon = _create_forest_emoji_icon(emoji)
			icon_registry.register_icon(icon)
		icons[emoji] = icon

	# Configure forest-specific dynamics
	_configure_forest_dynamics(icons, icon_registry)

	# Build operators using cached method
	build_operators_cached("StarterForestBiome", icons)

	print("  ✅ Hamiltonian: %dx%d matrix" % [
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0,
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0
	])
	print("  ✅ Lindblad: %d operators + %d gated configs" % [
		quantum_computer.lindblad_operators.size(),
		quantum_computer.gated_lindblad_configs.size()])
	print("  🌲 Starter Forest QuantumComputer ready!")


func _create_forest_emoji_icon(emoji: String) -> Icon:
	"""Create basic Icon for forest emoji."""
	var icon = Icon.new()
	icon.emoji = emoji
	icon.display_name = "Forest " + emoji

	# Set up basic couplings based on emoji role
	match emoji:
		"☀":  # Sun - drives day cycle
			icon.hamiltonian_couplings = {"🌙": 0.8}
			icon.self_energy = 0.5
		"🌙":  # Moon - night cycle
			icon.hamiltonian_couplings = {"☀": 0.8}
			icon.self_energy = -0.5
		"🐺":  # Wolf - hunts rabbits
			icon.hamiltonian_couplings = {"🐇": PREDATION_RATE, "🌙": 0.04}
			icon.self_energy = 0.3
		"🐇":  # Rabbit - prey
			icon.hamiltonian_couplings = {"🐺": PREDATION_RATE}
			icon.self_energy = -0.2
		"🦅":  # Eagle - apex predator
			icon.hamiltonian_couplings = {"🦌": APEX_HUNT_RATE}
			icon.self_energy = 0.4
		"🦌":  # Deer - large herbivore
			icon.hamiltonian_couplings = {"🦅": APEX_HUNT_RATE}
			icon.self_energy = -0.1
		"🌲":  # Tree - decays over time
			icon.hamiltonian_couplings = {"🍂": DECAY_RATE}
			icon.self_energy = 0.2
			icon.decay_rate = DECAY_RATE
			icon.decay_target = "🍂"
		"🍂":  # Decay - fertilizes growth
			icon.hamiltonian_couplings = {"🌲": DECAY_RATE, "🌱": 0.08}
			icon.self_energy = -0.3
		"🌱":  # Seedling - grows into vegetation
			icon.hamiltonian_couplings = {"🌿": GROWTH_RATE, "☀": 0.05}
			icon.self_energy = 0.1
		"🌿":  # Vegetation - mature plants
			icon.hamiltonian_couplings = {"🌱": GROWTH_RATE}
			icon.self_energy = 0.2

	return icon


func _configure_forest_dynamics(icons: Dictionary, icon_registry) -> void:
	"""Configure forest-specific Icon dynamics."""
	# Enhance sun → growth coupling
	if icons.has("☀") and icons.has("🌱"):
		icons["☀"].lindblad_incoming["🌱"] = 0.02

	# Moon enhances wolf hunting
	if icons.has("🌙") and icons.has("🐺"):
		icons["🌙"].lindblad_incoming["🐺"] = 0.015

	# Decay fertilizes seedlings
	if icons.has("🍂") and icons.has("🌱"):
		icons["🍂"].lindblad_incoming["🌱"] = 0.03


func get_biome_type() -> String:
	return "StarterForest"


func get_paired_emoji(emoji: String) -> String:
	"""Get the paired emoji for this biome's quantum axis"""
	return emoji_pairings.get(emoji, "?")


func _update_quantum_substrate(dt: float) -> void:
	"""Evolve quantum substrate under Lindblad dynamics."""
	if quantum_computer:
		quantum_computer.evolve(dt, max_evolution_dt)

	# Apply semantic drift game mechanics (🌀 chaos vs ✨ stability)
	super._update_quantum_substrate(dt)


func _rebuild_quantum_operators_impl() -> void:
	"""Rebuild operators when IconRegistry changes."""
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry or not quantum_computer:
		return

	var forest_emojis = ["☀", "🌙", "🐺", "🐇", "🦅", "🦌", "🌲", "🍂", "🌱", "🌿"]
	var icons = {}

	for emoji in forest_emojis:
		var icon = icon_registry.get_icon(emoji)
		if icon:
			icons[emoji] = icon

	if icons.size() > 0:
		_configure_forest_dynamics(icons, icon_registry)
		build_operators_cached("StarterForestBiome", icons)
