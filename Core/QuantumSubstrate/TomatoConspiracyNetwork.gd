class_name TomatoConspiracyNetwork
extends Node

## Minimal 12-Node Quantum Tomato Conspiracy Network
## Manages energy flow and conspiracy activation

# Preload TomatoNode to avoid circular dependency issues
const TomatoNode = preload("res://Core/QuantumSubstrate/TomatoNode.gd")

signal conspiracy_activated(conspiracy_name: String)
signal conspiracy_deactivated(conspiracy_name: String)

# The 12 nodes
var nodes: Dictionary = {}  # node_id -> TomatoNode

# The 15 entanglement connections
var connections: Array[Dictionary] = []  # [{from: String, to: String, strength: float}]

# Active conspiracies
var active_conspiracies: Dictionary = {}  # conspiracy_name -> bool

# Icon Hamiltonian system
var active_icons: Array = []  # Array of IconHamiltonian instances

# Biome reference (for sun/moon phase synchronization)
var biome = null  # Reference to Biome if available, falls back to own cycle

# Conspiracy activation thresholds
const CONSPIRACY_THRESHOLDS = {
	"growth_acceleration": 0.8,
	"quantum_germination": 1.0,
	"observer_effect": 0.5,
	"data_harvesting": 1.5,
	"mycelial_internet": 0.6,
	"tomato_hive_mind": 1.2,
	"RNA_memory": 0.7,
	"genetic_quantum_computation": 1.0,
	"retroactive_ripening": 0.9,
	"temporal_freshness": 1.1,
	"tomato_standard": 0.8,
	"ketchup_economy": 1.3,
	"umami_quantum": 0.6,
	"flavor_entanglement": 0.9,
	"fruit_vegetable_duality": 0.5,
	"botanical_legal_paradox": 1.5,
	"solar_panel_tomatoes": 1.0,
	"photon_harvesting": 1.2,
	"water_memory": 0.7,
	"irrigation_intelligence": 0.9,
	"tomato_wisdom": 0.8,
	"agricultural_enlightenment": 1.1,
	"tomato_simulating_tomatoes": 2.0,
	"recursive_agriculture": 1.8
}


func _ready():
	_create_12_nodes()
	_create_15_connections()
	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_NETWORK") == "1":
		print("🍅 TomatoConspiracyNetwork initialized with %d nodes and %d connections" % [nodes.size(), connections.size()])


func _process(dt: float):
	# Always evolve network (for sun/moon cycle and other systems)
	evolve_network(dt)

	# Only check conspiracies if there are tomato plots
	# (get_parent() is FarmView, which has farm_grid)
	if _has_tomato_plots():
		check_all_conspiracies()


## Initialization

func _create_12_nodes():
	"""Create the 12 conspiracy nodes with initial states"""

	# Hard-coded initial states (simplified from JSON)
	var node_data = {
		"seed": {
			"emoji": "🌱→🍅",
			"meaning": "potential_to_fruit",
			"conspiracies": ["growth_acceleration", "quantum_germination"],
			"theta": 0.191, "phi": 0.219, "q": 0.561, "p": -0.983
		},
		"observer": {
			"emoji": "👁️→📊",
			"meaning": "measurement_collapse",
			"conspiracies": ["observer_effect", "data_harvesting"],
			"theta": 1.762, "phi": 0.219, "q": -0.738, "p": -0.621
		},
		"underground": {
			"emoji": "🕳️→🌐",
			"meaning": "root_network_communications",
			"conspiracies": ["mycelial_internet", "tomato_hive_mind"],
			"theta": 3.333, "phi": 3.361, "q": 0.044, "p": 1.542
		},
		"genetic": {
			"emoji": "🧬→📝",
			"meaning": "information_transcription",
			"conspiracies": ["RNA_memory", "genetic_quantum_computation"],
			"theta": 1.239, "phi": 1.790, "q": -0.300, "p": -0.992
		},
		"ripening": {
			"emoji": "⏰→🔴",
			"meaning": "time_color_entanglement",
			"conspiracies": ["retroactive_ripening", "temporal_freshness"],
			"theta": 2.286, "phi": 1.005, "q": 0.133, "p": -1.144
		},
		"market": {
			"emoji": "💰→📈",
			"meaning": "value_superposition",
			"conspiracies": ["tomato_standard", "ketchup_economy"],
			"theta": 0.977, "phi": 4.932, "q": -0.909, "p": 0.242
		},
		"sauce": {
			"emoji": "🍅→🍝",
			"meaning": "state_transformation",
			"conspiracies": ["umami_quantum", "flavor_entanglement"],
			"theta": 2.809, "phi": 0.743, "q": 0.834, "p": 0.030
		},
		"identity": {
			"emoji": "🤔→❓",
			"meaning": "categorical_superposition",
			"conspiracies": ["fruit_vegetable_duality", "botanical_legal_paradox"],
			"theta": 1.762, "phi": 3.361, "q": 0.049, "p": 0.018
		},
		"solar": {
			"emoji": "☀️→⚡",
			"meaning": "light_energy_conversion",
			"conspiracies": ["solar_panel_tomatoes", "photon_harvesting"],
			"theta": 0.291, "phi": 0.219, "q": -1.381, "p": -1.329
		},
		"water": {
			"emoji": "💧→🌊",
			"meaning": "fluid_information_storage",
			"conspiracies": ["water_memory", "irrigation_intelligence"],
			"theta": 1.762, "phi": 1.790, "q": -0.112, "p": -1.567
		},
		"meaning": {
			"emoji": "📖→💭",
			"meaning": "semantic_field_generator",
			"conspiracies": ["tomato_wisdom", "agricultural_enlightenment"],
			"theta": 2.548, "phi": 4.146, "q": 0.863, "p": -0.545
		},
		"meta": {
			"emoji": "🔄→☯️",
			"meaning": "self_referential_loop",
			"conspiracies": ["tomato_simulating_tomatoes", "recursive_agriculture"],
			"theta": 3.333, "phi": 0.219, "q": -0.320, "p": -4.870
		}
	}

	for node_id in node_data.keys():
		var data = node_data[node_id]
		var node = TomatoNode.new()
		node.node_id = node_id
		node.emoji_transform = data["emoji"]
		node.meaning = data["meaning"]
		# Manually copy conspiracies to typed array
		for c in data["conspiracies"]:
			node.conspiracies.append(c)
		node.theta = data["theta"]
		node.phi = data["phi"]
		node.q = data["q"]
		node.p = data["p"]
		node.update_energy()
		nodes[node_id] = node


func _create_15_connections():
	"""Create the 15 entanglement connections"""
	connections = [
		{"from": "seed", "to": "solar", "strength": 0.9, "meaning": "photosynthetic_growth"},
		{"from": "seed", "to": "water", "strength": 0.85, "meaning": "hydration_activation"},
		{"from": "observer", "to": "ripening", "strength": 0.7, "meaning": "watched_pot_syndrome"},
		{"from": "underground", "to": "genetic", "strength": 0.95, "meaning": "root_RNA_network"},
		{"from": "genetic", "to": "meaning", "strength": 0.8, "meaning": "semantic_encoding"},
		{"from": "ripening", "to": "market", "strength": 0.75, "meaning": "value_timing"},
		{"from": "sauce", "to": "identity", "strength": 0.9, "meaning": "culinary_transformation"},
		{"from": "solar", "to": "meta", "strength": 0.6, "meaning": "energy_recursion"},
		{"from": "water", "to": "underground", "strength": 0.88, "meaning": "irrigation_network"},
		{"from": "market", "to": "sauce", "strength": 0.82, "meaning": "economic_transformation"},
		{"from": "identity", "to": "meta", "strength": 1.0, "meaning": "paradox_loop"},
		{"from": "meaning", "to": "observer", "strength": 0.77, "meaning": "semantic_collapse"},
		{"from": "seed", "to": "sauce", "strength": 0.66, "meaning": "lifecycle_completion"},
		{"from": "genetic", "to": "identity", "strength": 0.91, "meaning": "essence_encoding"},
		{"from": "meta", "to": "seed", "strength": 0.99, "meaning": "eternal_return"}
	]

	# Build connection dictionary for each node
	for conn in connections:
		var from_node = nodes[conn["from"]]
		var to_node = nodes[conn["to"]]
		var strength = conn["strength"]

		# Bidirectional connections
		from_node.connections[conn["to"]] = strength
		to_node.connections[conn["from"]] = strength


## Evolution

func evolve_network(dt: float):
	"""Evolve all nodes and process energy diffusion"""
	# Step 1: Evolve each node independently
	for node_id in nodes:
		# SKIP solar node - it's driven externally by sun/moon cycle, not internal evolution
		if node_id == "solar":
			continue
		nodes[node_id].evolve(dt)

	# Step 1.5: Sun/Moon oscillation (drives quantum production chains!)
	_evolve_sun_moon_cycle(dt)

	# Step 2: Apply Icon modulation
	apply_icon_modulation(dt)

	# Step 3: Energy diffusion through entanglement
	process_energy_diffusion(dt)


func process_energy_diffusion(dt: float):
	"""Energy flows between entangled nodes"""
	var coupling = dt * 0.1

	# Calculate all deltas first (prevents order dependency)
	var deltas = {}
	for node_id in nodes.keys():
		deltas[node_id] = 0.0

	# Calculate energy flow for each connection
	for conn in connections:
		var from_id = conn["from"]
		var to_id = conn["to"]
		var node_a = nodes[from_id]
		var node_b = nodes[to_id]
		var strength = conn["strength"]

		# Energy flows from high to low
		var delta = (node_b.energy - node_a.energy) * strength * coupling

		deltas[from_id] += delta
		deltas[to_id] -= delta

	# Apply all deltas at once
	for node_id in deltas:
		# SKIP solar node - it's an external driver, NOT part of network dynamics
		if node_id == "solar":
			continue
		nodes[node_id].energy += deltas[node_id]


## Sun/Moon Quantum Cycle

# Sun/moon cycle tracking
var sun_moon_phase: float = 0.0  # 0.0 to TAU (2π) radians
var sun_moon_period: float = 20.0  # Seconds for full day/night cycle
var is_sun_phase: bool = true

func _evolve_sun_moon_cycle(dt: float):
	"""Evolve the sun/moon quantum oscillation

	The solar node oscillates between sun (north pole, θ=0) and moon (south pole, θ=π).
	This drives energy into the system during sun phase, creating a quantum pump.

	Energy flows: sun → wheat (absorb) → classical harvest
	              moon → mushrooms (absorb) → classical harvest

	This is quantum mechanics all the way down - no separate environment system!
	"""
	var solar_node = nodes.get("solar")
	if not solar_node:
		return

	# Sync with Biome's sun/moon phase if available, otherwise maintain own cycle
	if biome and biome.has_method("_sync_sun_moon_phase"):
		# Use Biome as source of truth
		sun_moon_phase = biome.sun_moon_phase
	else:
		# Fallback: advance phase independently
		sun_moon_phase += (TAU / sun_moon_period) * dt
		sun_moon_phase = fmod(sun_moon_phase, TAU)

	# Determine if we're in sun or moon phase
	var was_sun = is_sun_phase
	is_sun_phase = sun_moon_phase < PI  # Sun for first half, moon for second half

	# Phase transition detection
	if was_sun and not is_sun_phase:
		if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_NETWORK") == "1":
					print("🌙 Moon rises (phase: %.2f)" % sun_moon_phase)
	elif not was_sun and is_sun_phase:
		if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_NETWORK") == "1":
					print("☀️ Sun rises (phase: %.2f)" % sun_moon_phase)

	# Oscillate theta between 0 (sun) and π (moon)
	# Use smooth sine wave for continuous quantum evolution
	# Direct assignment (no lerp) to maintain sinusoidal shape
	solar_node.theta = (PI / 2.0) * (1.0 - cos(sun_moon_phase))  # 0 at phase=0, π at phase=π

	# Energy as direct sinusoidal value (not accumulated)
	# TWO peaks per cycle: dawn LOW → noon HIGH → sunset LOW → midnight HIGH → dawn LOW
	# Using sin²(phase) gives smooth sinusoid: 0 at dawn/sunset, peak at noon/midnight
	var sin_val = sin(sun_moon_phase)
	var energy_strength = sin_val * sin_val  # sin² - smooth, no sharp corners at zero

	# Debug: Print every 30° of phase to show sinusoidal pattern (DISABLED - working correctly)
	# var phase_deg = int(rad_to_deg(sun_moon_phase))
	# if phase_deg % 30 == 0 and phase_deg != int(rad_to_deg(sun_moon_phase - (TAU / sun_moon_period) * dt)):
	# 	print("☀️🌙 Phase: %3d° | sin=%.3f | Energy: %.2f | %s" % [
	# 		phase_deg,
	# 		energy_strength,
	# 		solar_node.energy,
	# 		"☀️ SUN" if is_sun_phase else "🌙 MOON"
	# 	])

	# Solar energy directly follows the sinusoid (doesn't accumulate)
	# Energy range: 0-8 for both sun and moon
	var base_peak_energy = 8.0
	solar_node.energy = base_peak_energy * energy_strength

	# Set Gaussian state from energy (using sqrt to maintain energy = (q²+p²)/2)
	var amplitude = sqrt(2.0 * solar_node.energy)
	solar_node.q = amplitude * 0.707  # sqrt(2)/2
	solar_node.p = amplitude * 0.707  # sqrt(2)/2

	# Update visual emoji based on phase
	if is_sun_phase:
		solar_node.emoji_transform = "☀️→⚡"
	else:
		solar_node.emoji_transform = "🌙→✨"

	# DON'T call update_energy() - we explicitly set energy to sinusoid
	# Calling update_energy() would recalculate from q,p,theta and distort the sine wave


func get_sun_moon_phase() -> float:
	"""Get current sun/moon phase (0 to 2π)"""
	return sun_moon_phase


func is_currently_sun() -> bool:
	"""Check if currently in sun phase"""
	return is_sun_phase


## Conspiracy Management

func check_all_conspiracies():
	"""Check activation thresholds for all conspiracies"""
	for node in nodes.values():
		for conspiracy in node.conspiracies:
			check_conspiracy(conspiracy, node)


func check_conspiracy(conspiracy_name: String, node: TomatoNode):
	"""Check if a conspiracy should activate or deactivate"""
	var threshold = CONSPIRACY_THRESHOLDS.get(conspiracy_name, 1.0)
	var is_active = node.energy > threshold
	var was_active = active_conspiracies.get(conspiracy_name, false)

	# State change detection
	if is_active and not was_active:
		activate_conspiracy(conspiracy_name)
	elif not is_active and was_active:
		deactivate_conspiracy(conspiracy_name)


func activate_conspiracy(name: String):
	"""Activate a conspiracy"""
	active_conspiracies[name] = true
	conspiracy_activated.emit(name)
	# print("🔴 CONSPIRACY ACTIVATED: %s" % name)  # Disabled to reduce debug spam


func deactivate_conspiracy(name: String):
	"""Deactivate a conspiracy"""
	active_conspiracies[name] = false
	conspiracy_deactivated.emit(name)
	# print("🟢 Conspiracy deactivated: %s" % name)  # Disabled to reduce debug spam


## Utility

func get_total_energy() -> float:
	"""Get total energy of entire network"""
	var total = 0.0
	for node in nodes.values():
		total += node.energy
	return total


func get_tomato_node(node_id: String) -> TomatoNode:
	"""Get node by ID"""
	return nodes.get(node_id)


func get_node_energy(node_id: String) -> float:
	"""Get energy of a specific node by ID"""
	var node = nodes.get(node_id)
	if node:
		return node.energy
	return 0.0


func print_network_state():
	"""Debug: Print current state of all nodes"""
	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_NETWORK") == "1":
			print("=== TOMATO CONSPIRACY NETWORK STATE ===")
			print("Total Energy: %.3f" % get_total_energy())
			print("Active Conspiracies: %d" % active_conspiracies.size())
			for node in nodes.values():
				print("  %s" % node.get_debug_string())
			print("======================================")


## Icon Management

func add_icon(icon) -> void:
	"""Add an Icon to influence the network"""
	if icon not in active_icons:
		active_icons.append(icon)
		if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_NETWORK") == "1":
					print("✨ Added Icon: %s" % icon.get_debug_string())


func remove_icon(icon) -> void:
	"""Remove an Icon from the network"""
	if icon in active_icons:
		active_icons.erase(icon)
		if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_NETWORK") == "1":
					print("✨ Removed Icon: %s" % icon.icon_name)


func apply_icon_modulation(dt: float):
	"""Apply Icon Hamiltonian modulation to all nodes"""
	if active_icons.is_empty():
		return

	for icon in active_icons:
		for node_id in nodes:
			# SKIP solar node - it's an external driver
			if node_id == "solar":
				continue
			if icon.influences_node(node_id):
				icon.modulate_node_evolution(nodes[node_id], dt)


func get_active_icon_count() -> int:
	"""Get number of active Icons"""
	return active_icons.size()


func get_discovered_conspiracies() -> Array:
	"""Get list of all conspiracies that have been activated (for contract evaluation)"""
	var discovered = []
	for conspiracy_name in active_conspiracies.keys():
		if active_conspiracies[conspiracy_name]:
			discovered.append(conspiracy_name)
	return discovered


func get_active_conspiracy_count() -> int:
	"""Get count of currently active conspiracies (for contract evaluation)"""
	var count = 0
	for is_active in active_conspiracies.values():
		if is_active:
			count += 1
	return count


func _has_tomato_plots() -> bool:
	"""Check if there are any tomato plots in the farm"""
	var parent = get_parent()
	if not parent:
		return false

	# Access farm_grid property using get() method with default value
	var farm_grid = parent.get("farm_grid")
	if not farm_grid:
		return false

	# Access plots dictionary directly
	var plots = farm_grid.get("plots")
	if not plots:
		return false

	# Check if any plots are tomatoes (PlotType.TOMATO = 1)
	for plot in plots.values():
		if plot and plot.plot_type == 1:
			return true

	return false
