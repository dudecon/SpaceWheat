class_name FarmGrid
extends Node

## Farm Grid Manager
## Manages a grid of wheat plots and their interactions
## NOTE: plot_planted/plot_harvested signals are internal (Farm.gd is the public API)

# Internal signals (for FarmGrid-level operations, not listened to by UI)
signal plot_planted(position: Vector2i)
signal plot_harvested(position: Vector2i, yield_data: Dictionary)

signal entanglement_created(from: Vector2i, to: Vector2i)
signal entanglement_removed(from: Vector2i, to: Vector2i)

# Preload classes
const FarmPlot = preload("res://Core/GameMechanics/FarmPlot.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const Biome = preload("res://Core/Environment/Biome.gd")  # Legacy - for backward compatibility
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const QuantumMill = preload("res://Core/GameMechanics/QuantumMill.gd")
const FlowRateCalculator = preload("res://Core/GameMechanics/FlowRateCalculator.gd")
const TopologyAnalyzer = preload("res://Core/QuantumSubstrate/TopologyAnalyzer.gd")
const EntangledPair = preload("res://Core/QuantumSubstrate/EntangledPair.gd")
const EntangledCluster = preload("res://Core/QuantumSubstrate/EntangledCluster.gd")

# Grid configuration
@export var grid_width: int = 5
@export var grid_height: int = 5

# Plot storage
var plots: Dictionary = {}  # Vector2i -> FarmPlot (or subclasses: WheatPlot, etc.)

# Entangled pairs (NEW - density matrix representation)
var entangled_pairs: Array = []  # Array of EntangledPair objects

# Entangled clusters (N-qubit states via sequential gates)
var entangled_clusters: Array = []  # Array of EntangledCluster objects

# Quantum Mills (for non-destructive measurement)
var quantum_mills: Dictionary = {}  # Vector2i -> QuantumMill

# Conspiracy network (for tomato growth)
var conspiracy_network = null

# Faction territory manager (for territorial effects)
var faction_territory_manager = null

# Farm economy (for mill/market processing)
var farm_economy = null

# Topology analyzer (for knot bonuses)
var topology_analyzer: TopologyAnalyzer

# BIOME - Environmental layer (sun/moon, temperature, decoherence)
# Can be Biome or NullBiome (or any compatible biome implementation)
var biome = null  # Legacy: kept for backward compatibility

# MULTI-BIOME SUPPORT (Phase 2)
var biomes: Dictionary = {}  # String → BiomeBase (registry of all biomes)
var plot_biome_assignments: Dictionary = {}  # Vector2i → String (plot position → biome name)

# VOCABULARY EVOLUTION - Quantum concept discovery system (injected by Farm)
var vocabulary_evolution = null  # Reference to VocabularyEvolution

# Environmental parameters
var base_temperature: float = 20.0  # Base farm temperature (Kelvin or relative)
var active_icons: Array = []  # Array of LindbladIcon affecting the farm
var icon_scopes: Dictionary = {}  # Icon → Array[String] (biome names the icon affects)

# Stats
var total_plots_planted: int = 0
var total_wheat_harvested: int = 0


func _ready():
	print("🌾 FarmGrid initialized: %dx%d = %d plots" % [grid_width, grid_height, grid_width * grid_height])

	# Initialize topology analyzer
	topology_analyzer = TopologyAnalyzer.new()

	# Initialize Biome ONLY if not already injected by Farm
	# Farm will handle Biome creation and pass it if available
	if not biome:
		print("   ℹ️  No biome injected - running in simple mode")
		# Don't create biome here - let Farm control it

	# Note: Quantum states are initialized later in FarmView after plots are created

	set_process(true)


func _process(delta):
	# Skip quantum evolution if no biome (simple mode)
	if not biome:
		return

	# Apply Icon effects to quantum states (Lindblad evolution)
	_apply_icon_effects(delta)

	# Apply decoherence to entangled pairs
	_apply_entangled_pair_decoherence(delta)

	# Build icon_network for growth modifiers (QUANTUM LAYER)
	var icon_network = _build_icon_network()

	# Grow all planted plots
	for position in plots.keys():
		var plot = plots[position]
		if plot.is_planted:
			var plot_biome = get_biome_for_plot(position)  # Phase 2c: Route to correct biome
			plot.grow(delta, plot_biome, faction_territory_manager, icon_network, conspiracy_network)

	# Update vocabulary mutation pressure from active energy taps
	if vocabulary_evolution:
		var tap_boost = get_tap_mutation_pressure_boost()

		# Apply boost (additive, capped at 2.0)
		vocabulary_evolution.mutation_pressure = min(
			0.15 + tap_boost,  # Base 0.15 + tap boost
			2.0  # Max cap
		)

	# Process mills and markets (buildings)
	if farm_economy:
		for position in plots.keys():
			var plot = plots[position]
			if plot.plot_type == FarmPlot.PlotType.MILL:
				plot.process_mill(delta, self, farm_economy, conspiracy_network)
			elif plot.plot_type == FarmPlot.PlotType.MARKET:
				plot.process_market(delta, farm_economy, conspiracy_network)


## MULTI-BIOME REGISTRY (Phase 2b) - Methods for biome management and routing

func register_biome(biome_name: String, biome_instance) -> void:
	"""Register a biome in the grid's biome registry

	Called by Farm._ready() during initialization.
	Enables the grid to route plot operations to the correct biome.
	"""
	if not biome_name or not biome_instance:
		push_error("Cannot register biome: invalid name or instance")
		return

	biomes[biome_name] = biome_instance
	print("   📍 Biome registered: %s" % biome_name)


func assign_plot_to_biome(position: Vector2i, biome_name: String) -> void:
	"""Assign a specific plot to a biome

	Called by Farm._ready() during initialization.
	Configures which biome manages each plot's quantum evolution.
	"""
	if not is_valid_position(position):
		push_error("Cannot assign plot at invalid position: %s" % position)
		return

	if not biomes.has(biome_name):
		push_error("Cannot assign to unregistered biome: %s" % biome_name)
		return

	plot_biome_assignments[position] = biome_name


func get_biome_for_plot(position: Vector2i):
	"""Get the biome responsible for a specific plot

	Returns the biome instance for the given plot position.
	If no assignment exists, returns the BioticFlux biome (default).
	"""
	# Check if plot has explicit assignment
	if plot_biome_assignments.has(position):
		var biome_name = plot_biome_assignments[position]
		if biomes.has(biome_name):
			return biomes[biome_name]

	# Fallback to BioticFlux (default biome)
	if biomes.has("BioticFlux"):
		return biomes["BioticFlux"]

	# Final fallback to legacy biome variable (for backward compatibility)
	return biome


func _apply_icon_effects(delta: float):
	"""Apply quantum evolution in correct order:
	1. Icon Hamiltonians (UNITARY evolution only)
	2. Biome dissipation (Lindblad terms: T1 amplitude damping + T2 phase damping)

	Icons are PURE - they provide Hamiltonian terms
	Dissipation is handled by Biome based on temperature

	Icon scoping: If an icon has scopes defined, it only affects plots in those biomes
	"""
	# Apply to all planted plots with quantum states
	for position in plots.keys():
		var plot = plots[position]
		if not plot.is_planted or not plot.quantum_state:
			continue

		var plot_biome_name = plot_biome_assignments.get(position, "BioticFlux")

		# STEP 1: Apply Icon Hamiltonians (unitary evolution)
		for icon in active_icons:
			# Check if icon has scope restrictions
			if icon_scopes.has(icon):
				var allowed_biomes = icon_scopes[icon]
				if not allowed_biomes.has(plot_biome_name):
					continue  # Skip this icon for this plot (not in allowed biome)

			# Apply Hamiltonian
			icon.apply_hamiltonian_evolution(plot.quantum_state, delta)

		# STEP 2: Apply Biome dissipation (Lindblad: T1 + T2)
		var plot_biome = get_biome_for_plot(position)  # Phase 2c: Route to correct biome
		if plot_biome:
			plot_biome.apply_dissipation(plot.quantum_state, position, delta)
	# Entangled pairs automatically evolve via Lindblad operators on each qubit
	# No separate apply_to_entangled_pair() method needed

	# Apply Icon effects to entangled clusters (simplified - per-qubit decoherence)
	# Update at reduced rate (10 FPS instead of 60 FPS) for performance
	if Engine.get_frames_drawn() % 6 == 0:
		for cluster in entangled_clusters:
			for i in range(cluster.get_qubit_count()):
				var plot_id = cluster.qubit_ids[i]
				var plot = _get_plot_by_id(plot_id)
				if plot and plot.quantum_state:
					# Find plot position for biome lookup
					var plot_pos = _find_plot_by_id(plot_id)
					if plot_pos == Vector2i(-1, -1):
						continue

					var plot_biome_name = plot_biome_assignments.get(plot_pos, "BioticFlux")

					# Apply Icon effects to each qubit individually (with scoping)
					for icon in active_icons:
						# Check if icon has scope restrictions
						if icon_scopes.has(icon):
							var allowed_biomes = icon_scopes[icon]
							if not allowed_biomes.has(plot_biome_name):
								continue  # Skip this icon for this qubit (not in allowed biome)

						icon.apply_to_qubit(plot.quantum_state, delta * 6)


func _apply_entangled_pair_decoherence(delta: float):
	"""Apply realistic decoherence to entangled pairs"""
	const Lindblad = preload("res://Core/QuantumSubstrate/LindbladEvolution.gd")

	for pair in entangled_pairs:
		# Get effective temperature
		var temp = base_temperature
		for icon in active_icons:
			if icon.active_strength > 0.0:
				temp = max(temp, icon.get_effective_temperature())

		# Apply decoherence via Lindblad equation
		pair.density_matrix = Lindblad.apply_two_qubit_decoherence_4x4(
			pair.density_matrix,
			delta,
			temp,
			pair.coherence_time_T1
		)


func _build_icon_network() -> Dictionary:
	"""Build icon_network dictionary from active_icons array

	Creates a lookup table for WheatPlot to access Icons by name
	for growth modifiers and measurement bias.

	Returns:
		Dictionary with keys: "biotic", "chaos", "imperium"
	"""
	var icon_network = {}

	for icon in active_icons:
		if icon.icon_emoji == "🌾":  # Biotic Flux
			icon_network["biotic"] = icon
		elif icon.icon_emoji == "🍅":  # Chaos Vortex
			icon_network["chaos"] = icon
		elif icon.icon_emoji == "🏰":  # Imperium/Carrion Throne
			icon_network["imperium"] = icon

	return icon_network


## Plot Management

func get_plot(position: Vector2i) -> FarmPlot:
	"""Get or create plot at position (returns FarmPlot or subclass)"""
	if not is_valid_position(position):
		return null

	if not plots.has(position):
		var plot = FarmPlot.new()
		plot.plot_id = "plot_%d_%d" % [position.x, position.y]
		plot.grid_position = position
		plots[position] = plot

		# Register with faction territory manager
		if faction_territory_manager:
			faction_territory_manager.register_plot(position)

	return plots[position]


func _initialize_quantum_states():
	"""Initialize quantum states for all plots so quantum bubbles are visible from the start

	Each plot gets a default quantum state in superposition, even if not planted yet.
	This allows the quantum bubble visualization to be visible immediately.
	When a plot is actually planted, its quantum state will be updated.
	"""
	for position in plots.keys():
		var plot = plots[position]
		if plot and not plot.quantum_state:
			# Create a default quantum state (superposition of wheat and labor)
			var emojis = plot.get_plot_emojis()
			plot.quantum_state = DualEmojiQubit.new(emojis["north"], emojis["south"], PI / 2.0)
			plot.quantum_state.phi = randf() * TAU  # Random initial phase
	print("⚛️ Initialized quantum states for all %d plots (quantum bubbles visible)" % plots.size())


func is_valid_position(position: Vector2i) -> bool:
	"""Check if position is within grid bounds"""
	return (position.x >= 0 and position.x < grid_width and
			position.y >= 0 and position.y < grid_height)


func _find_plot_by_id(plot_id: String) -> Vector2i:
	"""Find grid position of a plot by its ID"""
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			var plot = get_plot(pos)
			if plot and plot.plot_id == plot_id:
				return pos
	return Vector2i(-1, -1)


func _get_plot_by_id(plot_id: String) -> FarmPlot:
	"""Get plot directly by ID (convenience wrapper for cluster operations)"""
	var pos = _find_plot_by_id(plot_id)
	if pos != Vector2i(-1, -1):
		return get_plot(pos)
	return null


func is_plot_empty(position: Vector2i) -> bool:
	"""Check if plot is empty (not planted)"""
	var plot = get_plot(position)
	return plot != null and not plot.is_planted


func is_plot_mature(position: Vector2i) -> bool:
	"""Check if plot has planted wheat (quantum-only: instant full size)"""
	var plot = get_plot(position)
	return plot != null and plot.is_planted


## Farming Operations

func plant(position: Vector2i, plant_type: String, quantum_state: Resource = null) -> bool:
	"""Generic plant method - handles all crop types

	Args:
		position: Grid position to plant at
		plant_type: "wheat", "tomato", or "mushroom"
		quantum_state: DEPRECATED - kept for backward compatibility

	Returns: true if planting succeeded, false otherwise
	"""
	var plot = get_plot(position)
	if plot == null or plot.is_planted:
		return false

	# Set plot type
	var plot_type_map = {
		"wheat": FarmPlot.PlotType.WHEAT,
		"tomato": FarmPlot.PlotType.TOMATO,
		"mushroom": FarmPlot.PlotType.MUSHROOM
	}

	if not plot_type_map.has(plant_type):
		push_error("Unknown plant type: %s" % plant_type)
		return false

	plot.plot_type = plot_type_map[plant_type]

	# Special handling for tomato: assign conspiracy node
	if plant_type == "tomato":
		var node_ids = ["seed", "observer", "underground", "genetic", "ripening", "market",
						"sauce", "identity", "solar", "water", "meaning", "meta"]
		var node_index = total_plots_planted % node_ids.size()
		plot.conspiracy_node_id = node_ids[node_index]
		print("🍅 Planted tomato at %s connected to node: %s" % [plot.plot_id, plot.conspiracy_node_id])

	# Plant with biome injection (NEW SYSTEM)
	# Biome will create quantum state and inject resources
	if quantum_state != null:
		# BACKWARD COMPATIBILITY: Old API passes quantum state directly
		plot.plant(quantum_state)
	else:
		# NEW API: Pass biome reference for resource injection
		# Default inputs: 0.08 labor + 0.22 wheat
		plot.plant(0.08, 0.22, biome)

	total_plots_planted += 1
	plot_planted.emit(position)

	# AUTO-ENTANGLE: If this plot has infrastructure entanglements, entangle quantum states
	_auto_entangle_from_infrastructure(position)

	return true


# Backward-compatibility wrappers (deprecated)
func plant_wheat(position: Vector2i, quantum_state: Resource = null) -> bool:
	"""Deprecated: Use plant(position, "wheat", quantum_state) instead"""
	return plant(position, "wheat", quantum_state)


func plant_tomato(position: Vector2i, quantum_state: Resource = null, conspiracy_network = null) -> bool:
	"""Deprecated: Use plant(position, "tomato", quantum_state) instead"""
	return plant(position, "tomato", quantum_state)


func plant_mushroom(position: Vector2i, quantum_state: Resource = null) -> bool:
	"""Deprecated: Use plant(position, "mushroom", quantum_state) instead"""
	return plant(position, "mushroom", quantum_state)


func plant_energy_tap(position: Vector2i, target_emoji: String) -> bool:
	"""Plant an energy tap plot configured to drain a specific emoji

	Energy taps continuously pull energy from target emojis using Bloch sphere cos² coupling.
	The tapped energy accumulates and can be harvested as classical resources.

	PROGRESSION: Energy taps can only target emojis from discovered vocabulary. This restricts
	tap availability to emojis the player has encountered through the vocabulary evolution system.

	Args:
		position: Grid position to plant the tap at
		target_emoji: The emoji to tap (must be in discovered vocabulary)

	Returns: true if planting succeeded, false otherwise
	"""
	var plot = get_plot(position)
	if plot == null or plot.is_planted:
		return false

	# VALIDATION: Check if emoji is in discovered vocabulary
	var available_emojis = get_available_tap_emojis()
	if not available_emojis.has(target_emoji):
		print("⚠️  Cannot plant tap: %s not in discovered vocabulary" % target_emoji)
		return false

	# Configure as energy tap
	plot.plot_type = FarmPlot.PlotType.ENERGY_TAP
	plot.tap_target_emoji = target_emoji
	plot.tap_theta = 3.0 * PI / 4.0  # Near south pole
	plot.tap_phi = PI / 4.0           # 45° off axis
	plot.tap_accumulated_resource = 0.0
	plot.tap_base_rate = 0.5

	plot.is_planted = true
	total_plots_planted += 1
	plot_planted.emit(position)

	print("⚡ Planted energy tap at %s targeting %s (discovered vocab)" % [plot.plot_id, target_emoji])
	return true


func place_mill(position: Vector2i) -> bool:
	"""Place quantum mill building - non-destructive measurement via ancilla

	Creates a QuantumMill that couples to adjacent wheat qubits via
	controlled operations. Measures ancilla periodically to produce flour.
	"""
	var plot = get_plot(position)
	if plot == null or plot.is_planted:
		return false

	# Mark as occupied (buildings are instantly "mature")
	plot.plot_type = FarmPlot.PlotType.MILL
	plot.conspiracy_node_id = "sauce"  # Entangle with transformation node
	plot.is_planted = true

	# Create QuantumMill
	var mill = QuantumMill.new()
	mill.grid_position = position
	mill.farm_grid = self
	add_child(mill)

	# Link adjacent wheat to mill
	var adjacent_wheat = _get_adjacent_wheat(position)
	mill.set_entangled_wheat(adjacent_wheat)

	# Track mill
	quantum_mills[position] = mill

	plot_planted.emit(position)
	print("🏭 Placed quantum mill at %s with %d adjacent wheat" % [plot.plot_id, adjacent_wheat.size()])
	return true


func _get_adjacent_wheat(position: Vector2i) -> Array:
	"""Get all wheat plots adjacent to a position (4-connected)

	Returns: Array of adjacent WheatPlot references
	"""
	var adjacent = []
	var directions = [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.RIGHT
	]

	for direction in directions:
		var adj_pos = position + direction
		if is_valid_position(adj_pos):
			var adj_plot = get_plot(adj_pos)
			if adj_plot and adj_plot.is_planted and adj_plot.plot_type == FarmPlot.PlotType.WHEAT:
				adjacent.append(adj_plot)

	return adjacent


func place_market(position: Vector2i) -> bool:
	"""Place market building - sells flour for credits"""
	var plot = get_plot(position)
	if plot == null or plot.is_planted:
		return false

	# Mark as occupied (buildings are instantly "mature")
	plot.plot_type = FarmPlot.PlotType.MARKET
	plot.conspiracy_node_id = "market"  # Entangle with market node
	plot.is_planted = true
	# Quantum-only: No is_mature property (instant full size)
	plot_planted.emit(position)

	print("💰 Placed market at %s → entangled with 💰→📈 market node (value fluctuation)" % plot.plot_id)
	return true


func harvest_wheat(position: Vector2i) -> Dictionary:
	"""Harvest wheat at position (quantum-only: must be planted)"""
	var plot = get_plot(position)
	if plot == null or not plot.is_planted:
		return {"success": false}

	var yield_data = plot.harvest()
	if yield_data["success"]:
		total_wheat_harvested += yield_data["yield"]

		# Add wheat to economy inventory
		if farm_economy:
			farm_economy.record_harvest(yield_data["yield"])

		plot_harvested.emit(position, yield_data)

	return yield_data


func harvest_energy_tap(position: Vector2i) -> Dictionary:
	"""Harvest accumulated resources from energy tap plot

	Extracts accumulated energy and converts to classical resources.
	The target emoji resource is returned, quantity based on accumulated energy.

	Args:
		position: Grid position of the energy tap

	Returns: Dictionary with:
		- success: true if harvest succeeded
		- emoji: The resource emoji that was tapped
		- amount: Quantity of resource obtained
		- error: Error message if failed
	"""
	var plot = get_plot(position)
	if plot == null or not plot.is_planted:
		return {"success": false, "error": "Plot not planted"}

	if plot.plot_type != FarmPlot.PlotType.ENERGY_TAP:
		return {"success": false, "error": "Not an energy tap"}

	var accumulated = plot.tap_accumulated_resource
	if accumulated < 0.01:
		return {"success": false, "error": "Nothing accumulated"}

	# Convert energy to resource units (1 energy = 1 resource)
	var resource_amount = floor(accumulated)
	var target_emoji = plot.tap_target_emoji

	# Reset accumulator (keep fractional part for next accumulation)
	plot.tap_accumulated_resource = accumulated - resource_amount

	# Optional: Add to economy if available
	if farm_economy and resource_amount > 0:
		farm_economy.record_harvest(resource_amount)

	plot_harvested.emit(position, {
		"success": true,
		"emoji": target_emoji,
		"amount": resource_amount
	})

	print("⚡ Harvested %d × %s from energy tap at %s" % [resource_amount, target_emoji, plot.plot_id])

	return {
		"success": true,
		"emoji": target_emoji,
		"amount": resource_amount
	}


func get_available_tap_emojis() -> Array[String]:
	"""Get list of emojis that can be tapped (from discovered vocabulary)

	Returns array of emojis from discovered vocabulary plus basic fallback emojis.
	This ensures energy taps can only target emojis the player has encountered through
	the vocabulary evolution system (progression mechanic).

	Returns:
		Array[String] of emoji characters available for tapping
	"""
	var available_emojis: Array[String] = []

	if vocabulary_evolution:
		# Extract emojis from discovered vocabulary
		for vocab in vocabulary_evolution.discovered_vocabulary:
			# Add both north and south emoji from each vocabulary pair
			if not available_emojis.has(vocab["north"]):
				available_emojis.append(vocab["north"])
			if not available_emojis.has(vocab["south"]):
				available_emojis.append(vocab["south"])

	# Always include basic game emojis (starting vocabulary)
	for basic in ["🌾", "👥", "🍅", "🍄"]:
		if not available_emojis.has(basic):
			available_emojis.append(basic)

	return available_emojis


func _count_active_energy_taps() -> Dictionary:
	"""Count active energy taps and their accumulated energy

	Scans all plots to find active energy taps and sum their accumulated resources.
	Used to calculate mutation pressure boost from active taps.

	Returns:
		Dictionary with:
		- "count": int - Number of active energy taps
		- "total_energy": float - Sum of accumulated energy across all taps
		- "target_emojis": Array[String] - List of unique emojis being tapped
	"""
	var active_count = 0
	var total_energy = 0.0
	var target_set = {}

	for position in plots.keys():
		var plot = plots[position]
		if plot.plot_type == FarmPlot.PlotType.ENERGY_TAP and plot.is_planted:
			active_count += 1
			total_energy += plot.tap_accumulated_resource

			if plot.tap_target_emoji != "":
				target_set[plot.tap_target_emoji] = true

	return {
		"count": active_count,
		"total_energy": total_energy,
		"target_emojis": target_set.keys()
	}


func get_tap_mutation_pressure_boost() -> float:
	"""Calculate mutation pressure boost from active energy taps

	Active taps accelerate vocabulary evolution by increasing mutation_pressure.
	Formula: boost = active_taps × 0.02 + (total_energy / 100) × 0.01

	This creates positive feedback: More taps → Faster vocabulary discovery → More tap targets

	Returns:
		float - Mutation pressure boost to add to base vocabulary mutation rate
	"""
	var tap_stats = _count_active_energy_taps()

	# Base boost from number of active taps (0.02 per tap)
	var count_boost = tap_stats["count"] * 0.02

	# Energy boost from accumulated resources (0.01 per 100 energy units)
	var energy_boost = (tap_stats["total_energy"] / 100.0) * 0.01

	return count_boost + energy_boost


func get_local_network(center_plot: FarmPlot, radius: int = 2) -> Array:
	"""Get plots within entanglement distance from center plot

	Args:
		center_plot: The plot at the center of the local network
		radius: Number of entanglement hops to include

	Returns:
		Array of WheatPlot forming the local entanglement network
	"""
	if not center_plot or not center_plot.quantum_state:
		return [center_plot] if center_plot else []

	var local = [center_plot]
	var visited = {center_plot: true}
	var current_layer = [center_plot]

	for hop in range(radius):
		var next_layer = []
		for plot in current_layer:
			if not plot.is_planted:
				continue

			# Get entangled partners via WheatPlot.entangled_plots
			for partner_id in plot.entangled_plots.keys():
				var partner_pos = _find_plot_by_id(partner_id)
				if partner_pos != Vector2i(-1, -1):
					var partner_plot = get_plot(partner_pos)
					if partner_plot and not visited.has(partner_plot):
						local.append(partner_plot)
						next_layer.append(partner_plot)
						visited[partner_plot] = true

		current_layer = next_layer
		if current_layer.is_empty():
			break

	return local


func _find_plot_by_qubit(qubit) -> FarmPlot:
	"""Find plot containing a specific qubit"""
	for plot in plots.values():
		if plot.quantum_state == qubit:
			return plot
	return null


func harvest_with_topology(position: Vector2i, local_radius: int = 2) -> Dictionary:
	"""Harvest wheat with local topology bonus and coherence penalty

	This is the NEW harvest method that implements the quantum-classical divide:
	- Analyzes local entanglement topology for bonus
	- Applies coherence penalty (decoherence reduces yield)
	- Measures quantum state (collapses superposition)
	- Breaks entanglements (measurement destroys quantum state)

	Args:
		position: Grid position to harvest
		local_radius: Entanglement hops to include in local network (default 2)

	Returns:
		Dictionary with harvest results:
		{
			"success": bool,
			"yield": float,
			"base_yield": float,
			"state": String (🌾 or 👥),
			"state_bonus": float,
			"topology_bonus": float,
			"coherence": float,
			"pattern_name": String,
			"jones": float
		}
	"""
	var plot = get_plot(position)
	if plot == null or not plot.is_planted:
		return {"success": false}

	# 1. Get local entanglement network
	var local_plots = get_local_network(plot, local_radius)

	# 2. Analyze local topology
	var local_topology = topology_analyzer.analyze_entanglement_network(local_plots)

	# 3. Check coherence (decoherence reduces yield)
	var coherence = 1.0
	if plot.quantum_state:
		coherence = plot.quantum_state.get_coherence()

	# 4. Measure quantum state (collapse superposition)
	var measurement_result = ""
	if plot.quantum_state:
		# If part of entangled cluster, measure via cluster
		if plot.quantum_state.is_in_cluster():
			var cluster = plot.quantum_state.entangled_cluster
			var index = plot.quantum_state.cluster_qubit_index

			# Measure qubit in cluster (collapses entire cluster!)
			var outcome = cluster.measure_qubit(index)
			measurement_result = cluster.qubits[index].north_emoji if outcome == 0 else cluster.qubits[index].south_emoji

			# Handle cluster collapse
			_handle_cluster_collapse(cluster)

		# If part of entangled pair, measure via pair
		elif plot.quantum_state.entangled_pair != null:
			var pair = plot.quantum_state.entangled_pair
			var is_a = plot.quantum_state.is_qubit_a

			# Measure via pair (collapses density matrix)
			if is_a:
				measurement_result = pair.measure_qubit_a()
			else:
				measurement_result = pair.measure_qubit_b()

			# CRITICAL: Update partner qubit's Bloch sphere state to match collapsed density matrix
			var other_plot_id = pair.qubit_b_id if is_a else pair.qubit_a_id
			var other_pos = _find_plot_by_id(other_plot_id)
			if other_pos != Vector2i(-1, -1):
				var other_plot = get_plot(other_pos)
				if other_plot and other_plot.quantum_state:
					# Get the collapsed state from density matrix
					var rho_other = pair._partial_trace_a() if is_a else pair._partial_trace_b()

					# Update other qubit's Bloch sphere to match
					other_plot.quantum_state.from_density_matrix(rho_other)

					# Unlink from pair
					other_plot.quantum_state.entangled_pair = null

					print("  ↪ Cascade: Partner qubit %s collapsed to θ=%.2f" % [other_plot_id, other_plot.quantum_state.theta])

			# Remove pair from tracking (measurement breaks entanglement)
			if pair in entangled_pairs:
				entangled_pairs.erase(pair)

			# Unlink this qubit
			plot.quantum_state.entangled_pair = null
		else:
			# Single qubit measurement
			measurement_result = plot.quantum_state.measure()

	# 5. Calculate base yield from growth
	var growth_factor = plot.growth_progress  # 0.0 to 1.0
	var base_yield = 10.0 * growth_factor

	# 6. Quantum state modifier
	var state_modifier = 1.5 if measurement_result == "👥" else 1.0

	# 7. Local topology bonus (parametric from Jones polynomial)
	var topology_bonus = local_topology.bonus_multiplier  # 1.0x to 3.0x

	# 8. Coherence penalty (decoherence reduces yield)
	var coherence_factor = coherence  # 0.0 to 1.0

	# 9. Faction territory value modifier
	var territory_value_modifier = 1.0
	if faction_territory_manager:
		var territory_effects = faction_territory_manager.get_territory_effects(position)
		if territory_effects.has("harvest_value_multiplier"):
			territory_value_modifier = territory_effects.harvest_value_multiplier

	# 10. Final yield calculation
	var final_yield = base_yield * state_modifier * topology_bonus * coherence_factor * territory_value_modifier

	# 10. Break entanglements (measurement destroys quantum state)
	# Clear WheatPlot entanglement tracking
	for partner_id in plot.entangled_plots.keys():
		var partner_pos = _find_plot_by_id(partner_id)
		if partner_pos != Vector2i(-1, -1):
			var partner_plot = get_plot(partner_pos)
			if partner_plot:
				partner_plot.entangled_plots.erase(plot.plot_id)
	plot.entangled_plots.clear()

	# Clear EntangledPair if exists
	if plot.quantum_state and plot.quantum_state.entangled_pair:
		var pair = plot.quantum_state.entangled_pair
		entangled_pairs.erase(pair)
		# Also clear partner's reference
		if plot.quantum_state.is_qubit_a and pair.qubit_b_id:
			var partner_pos = _find_plot_by_id(pair.qubit_b_id)
			if partner_pos != Vector2i(-1, -1):
				var partner = get_plot(partner_pos)
				if partner and partner.quantum_state:
					partner.quantum_state.entangled_pair = null
		elif not plot.quantum_state.is_qubit_a and pair.qubit_a_id:
			var partner_pos = _find_plot_by_id(pair.qubit_a_id)
			if partner_pos != Vector2i(-1, -1):
				var partner = get_plot(partner_pos)
				if partner and partner.quantum_state:
					partner.quantum_state.entangled_pair = null

	# 11. Reset plot
	plot.reset()

	# 12. Update stats
	total_wheat_harvested += int(final_yield)

	# 13. Emit signal with full data
	var yield_data = {
		"success": true,
		"yield": final_yield,
		"base_yield": base_yield,
		"state": measurement_result,
		"state_bonus": state_modifier,
		"topology_bonus": topology_bonus,
		"coherence": coherence,
		"coherence_penalty": coherence_factor,
		"pattern_name": local_topology.pattern.name,
		"jones": local_topology.features.jones_approximation,
		"protection": local_topology.pattern.protection_level,
		"glow_color": local_topology.pattern.glow_color
	}

	plot_harvested.emit(position, yield_data)

	return yield_data


func measure_plot(position: Vector2i) -> String:
	"""Measure quantum state (observer effect). Entanglement means measuring one collapses entire network!"""
	var plot = get_plot(position)
	if plot == null or not plot.is_planted:
		return ""

	# Build icon_network for Imperium collapse bias (QUANTUM LAYER)
	var icon_network = _build_icon_network()

	# IMPORTANT: Save entanglement network BEFORE measuring
	# (because measure() will detangle the plot)
	var initial_entanglements = plot.entangled_plots.keys()

	# Measure the primary plot (with Icon effects)
	var result = plot.measure(icon_network)

	# Spooky action at a distance: measure ALL plots in the entangled network!
	# Use flood-fill to find entire connected component
	var measured_ids = {plot.plot_id: true}
	var to_check = []

	# Add all direct partners to queue (from saved entanglements)
	for entangled_id in initial_entanglements:
		to_check.append(entangled_id)

	# Flood-fill through the entanglement network
	while not to_check.is_empty():
		var current_id = to_check.pop_front()

		# Skip if already measured
		if measured_ids.has(current_id):
			continue

		# Find and measure this plot
		var current_pos = _find_plot_by_id(current_id)
		if current_pos == Vector2i(-1, -1):
			continue

		var current_plot = get_plot(current_pos)
		if not current_plot or not current_plot.is_planted:
			continue

		# Measure it (with Icon effects)
		if not current_plot.has_been_measured:
			current_plot.measure(icon_network)
			print("  ↪ Entanglement network collapsed %s!" % current_id)

		measured_ids[current_id] = true

		# Add its entangled partners to the queue
		for next_id in current_plot.entangled_plots.keys():
			if not measured_ids.has(next_id):
				to_check.append(next_id)

	# MEASUREMENT COLLAPSES TO CLASSICAL STATE:
	# Break ALL entanglements for measured plots (quantum → classical transition)
	# Measured plots become classical and no longer participate in quantum network
	for measured_id in measured_ids.keys():
		var measured_pos = _find_plot_by_id(measured_id)
		if measured_pos == Vector2i(-1, -1):
			continue

		var measured_plot = get_plot(measured_pos)
		if not measured_plot:
			continue

		# Clear all entanglements for this plot
		if not measured_plot.entangled_plots.is_empty():
			var num_broken = measured_plot.entangled_plots.size()
			measured_plot.entangled_plots.clear()
			print("  🔓 Measurement broke %d entanglements for %s (classical state)" % [num_broken, measured_id])

	# Also clean up density matrices for broken entangled pairs
	var pairs_to_remove = []
	for i in range(entangled_pairs.size()):
		var pair = entangled_pairs[i]
		var plot1 = _get_plot_by_id(pair.qubit_a_id)
		var plot2 = _get_plot_by_id(pair.qubit_b_id)

		# Remove pair if either plot has been measured
		if (plot1 and plot1.has_been_measured) or (plot2 and plot2.has_been_measured):
			pairs_to_remove.append(i)

	# Remove in reverse order to avoid index shifting
	pairs_to_remove.reverse()
	for i in pairs_to_remove:
		entangled_pairs.remove_at(i)

	return result


## Cluster Entanglement Helpers

func _update_cluster_gameplay_connections(cluster):
	"""Update WheatPlot.entangled_plots for all qubits in cluster (for topology)"""
	var plot_ids = cluster.get_all_plot_ids()

	# Each plot should be connected to all others in cluster
	for plot_id in plot_ids:
		var plot = _get_plot_by_id(plot_id)
		if not plot:
			continue

		# Clear old connections, rebuild from cluster
		plot.entangled_plots.clear()

		# Add all other plots in cluster
		for other_id in plot_ids:
			if other_id != plot_id:
				plot.entangled_plots[other_id] = 1.0  # Full strength


func _add_to_cluster(cluster, new_plot: WheatPlot, control_index: int) -> bool:
	"""Add new qubit to existing cluster via CNOT gate"""

	# Check cluster size limit (recommend 6-qubit max)
	if cluster.get_qubit_count() >= 6:
		print("⚠️ Cluster at max size (6 qubits)")
		return false

	# Add qubit to cluster with CNOT gate
	cluster.entangle_new_qubit_cnot(new_plot.quantum_state, new_plot.plot_id, control_index)

	# Link qubit to cluster
	new_plot.quantum_state.entangled_cluster = cluster
	new_plot.quantum_state.cluster_qubit_index = cluster.get_qubit_count() - 1

	# Update gameplay entanglement tracking (for topology)
	_update_cluster_gameplay_connections(cluster)

	print("🔗 Added %s to cluster (size: %d)" % [new_plot.plot_id, cluster.get_qubit_count()])
	return true


func _upgrade_pair_to_cluster(pair, new_plot: WheatPlot) -> bool:
	"""Upgrade 2-qubit pair to 3-qubit cluster"""

	# Create new cluster
	var cluster = EntangledCluster.new()

	# Find the two plots in the pair
	var plot_a = _get_plot_by_id(pair.qubit_a_id)
	var plot_b = _get_plot_by_id(pair.qubit_b_id)

	if not plot_a or not plot_b:
		print("⚠️ Cannot find plots in pair")
		return false

	# Add both qubits to cluster
	cluster.add_qubit(plot_a.quantum_state, plot_a.plot_id)
	cluster.add_qubit(plot_b.quantum_state, plot_b.plot_id)

	# Create GHZ state (|00⟩ + |11⟩) - equivalent to Bell state
	cluster.create_ghz_state()

	# Add third qubit via CNOT
	cluster.entangle_new_qubit_cnot(new_plot.quantum_state, new_plot.plot_id, 0)

	# Update qubit references
	plot_a.quantum_state.entangled_pair = null
	plot_a.quantum_state.entangled_cluster = cluster
	plot_a.quantum_state.cluster_qubit_index = 0

	plot_b.quantum_state.entangled_pair = null
	plot_b.quantum_state.entangled_cluster = cluster
	plot_b.quantum_state.cluster_qubit_index = 1

	new_plot.quantum_state.entangled_cluster = cluster
	new_plot.quantum_state.cluster_qubit_index = 2

	# Remove old pair, add cluster
	entangled_pairs.erase(pair)
	entangled_clusters.append(cluster)

	# Update gameplay connections
	_update_cluster_gameplay_connections(cluster)

	print("✨ Upgraded pair to 3-qubit cluster: %s" % cluster.get_state_string())
	return true


func _handle_cluster_collapse(cluster):
	"""Handle measurement cascade when cluster is measured"""
	var plot_ids = cluster.get_all_plot_ids()

	# Update all qubits from collapsed cluster state
	for i in range(cluster.get_qubit_count()):
		var plot_id = plot_ids[i]
		var plot = _get_plot_by_id(plot_id)
		if not plot:
			continue

		# Get reduced density matrix for this qubit (partial trace)
		# For now: simplified - cluster measurement collapses to product state
		# Qubits become separable after measurement

		# Clear cluster reference
		plot.quantum_state.entangled_cluster = null
		plot.quantum_state.cluster_qubit_index = -1

		# Clear gameplay connections
		plot.entangled_plots.clear()

	# Remove cluster from tracking
	entangled_clusters.erase(cluster)

	print("💥 Cluster collapsed - %d qubits now separable" % plot_ids.size())


## Entanglement (Density Matrix System)

func _auto_entangle_from_infrastructure(position: Vector2i):
	"""Auto-entangle quantum states when planting in infrastructurally entangled plot"""
	var plot = get_plot(position)
	if not plot or not plot.is_planted:
		return

	# Check all infrastructure entanglement links
	for partner_pos in plot.plot_infrastructure_entanglements:
		var partner_plot = get_plot(partner_pos)

		# If partner is planted, entangle their quantum states
		if partner_plot and partner_plot.is_planted:
			# Check if already entangled (avoid duplicates)
			if not plot.entangled_plots.has(partner_plot.plot_id):
				# Recursively call create_entanglement to set up quantum state entanglement
				# This will skip the infrastructure setup (already done) and go straight to quantum entanglement
				_create_quantum_entanglement(position, partner_pos)
				print("  ⚡ Auto-entangled %s ↔ %s (infrastructure activated)" % [position, partner_pos])


func _create_quantum_entanglement(pos_a: Vector2i, pos_b: Vector2i, bell_type: String = "phi_plus") -> bool:
	"""Create quantum state entanglement (internal helper)"""
	var plot_a = get_plot(pos_a)
	var plot_b = get_plot(pos_b)

	if not plot_a or not plot_b or not plot_a.is_planted or not plot_b.is_planted:
		return false

	# Smart entanglement logic: Cluster upgrade system (existing code)
	# Case 1: Plot A in cluster → Add B to cluster
	if plot_a.quantum_state.is_in_cluster():
		return _add_to_cluster(
			plot_a.quantum_state.entangled_cluster,
			plot_b,
			plot_a.quantum_state.cluster_qubit_index
		)

	# Case 2: Plot B in cluster → Add A to cluster
	if plot_b.quantum_state.is_in_cluster():
		return _add_to_cluster(
			plot_b.quantum_state.entangled_cluster,
			plot_a,
			plot_b.quantum_state.cluster_qubit_index
		)

	# Case 3: Plot A in pair → Upgrade to cluster
	if plot_a.quantum_state.is_in_pair():
		return _upgrade_pair_to_cluster(plot_a.quantum_state.entangled_pair, plot_b)

	# Case 4: Plot B in pair → Upgrade to cluster
	if plot_b.quantum_state.is_in_pair():
		return _upgrade_pair_to_cluster(plot_b.quantum_state.entangled_pair, plot_a)

	# Case 5: Neither entangled → Create new EntangledPair
	var pair = EntangledPair.new()
	pair.qubit_a_id = plot_a.plot_id
	pair.qubit_b_id = plot_b.plot_id
	pair.north_emoji_a = plot_a.quantum_state.north_emoji
	pair.south_emoji_a = plot_a.quantum_state.south_emoji
	pair.north_emoji_b = plot_b.quantum_state.north_emoji
	pair.south_emoji_b = plot_b.quantum_state.south_emoji

	# Create Bell state
	match bell_type:
		"phi_plus": pair.create_bell_phi_plus()
		"phi_minus": pair.create_bell_phi_minus()
		"psi_plus": pair.create_bell_psi_plus()
		"psi_minus": pair.create_bell_psi_minus()
		_: pair.create_bell_phi_plus()

	# Link qubits to pair
	plot_a.quantum_state.entangled_pair = pair
	plot_a.quantum_state.is_qubit_a = true
	plot_b.quantum_state.entangled_pair = pair
	plot_b.quantum_state.is_qubit_a = false

	# Add to pairs array
	entangled_pairs.append(pair)

	# Update gameplay entanglement tracking
	plot_a.create_entanglement(plot_b.plot_id, 1.0)
	plot_b.create_entanglement(plot_a.plot_id, 1.0)

	return true


func create_entanglement(pos_a: Vector2i, pos_b: Vector2i, bell_type: String = "phi_plus") -> bool:
	"""Create entanglement between two plots (PLOT INFRASTRUCTURE MODEL)

	NEW: Entanglement is plot-level infrastructure (like gates)
	- Plots remember entanglement links even after harvest/replant
	- When planting in an entangled plot, quantum states auto-entangle

	Args:
		pos_a: Position of first plot
		pos_b: Position of second plot
		bell_type: Type of Bell state (used when both plots are planted)

	Returns:
		true if entanglement infrastructure created successfully
	"""
	if not is_valid_position(pos_a) or not is_valid_position(pos_b):
		return false

	if pos_a == pos_b:
		return false

	var plot_a = get_plot(pos_a)
	var plot_b = get_plot(pos_b)

	if plot_a == null or plot_b == null:
		return false

	# NEW: Set up plot infrastructure FIRST (works even if not planted)
	if not plot_a.plot_infrastructure_entanglements.has(pos_b):
		plot_a.plot_infrastructure_entanglements.append(pos_b)
		print("🏗️ Plot infrastructure: %s ↔ %s (entanglement gate installed)" % [pos_a, pos_b])

	if not plot_b.plot_infrastructure_entanglements.has(pos_a):
		plot_b.plot_infrastructure_entanglements.append(pos_a)

	# Mark Bell gate in biome layer (historical entanglement record)
	var biome_a = get_biome_for_plot(pos_a)  # Phase 2c: Use first plot's biome
	if biome_a and biome_a.has_method("mark_bell_gate"):
		biome_a.mark_bell_gate([pos_a, pos_b])

	# If both plots are NOT planted, just set up infrastructure and return
	if not plot_a.is_planted or not plot_b.is_planted:
		print("  → Infrastructure ready. Quantum entanglement will auto-activate when both plots are planted.")
		entanglement_created.emit(pos_a, pos_b)
		return true  # Infrastructure created successfully

	# Both plots are planted → Create quantum entanglement using helper
	var success = _create_quantum_entanglement(pos_a, pos_b, bell_type)
	if success:
		entanglement_created.emit(pos_a, pos_b)
	return success


func create_triplet_entanglement(pos_a: Vector2i, pos_b: Vector2i, pos_c: Vector2i) -> bool:
	"""Create triple entanglement (3-qubit Bell state) for kitchen measurement

	This marks three plots as a potential kitchen measurement target.
	The spatial arrangement of the plots determines the Bell state type:
	- Horizontal/Vertical/Diagonal → GHZ state
	- L-shape → W state
	- T-shape → Cluster state

	Args:
		pos_a, pos_b, pos_c: Positions of the three plots

	Returns:
		true if triplet entanglement infrastructure created successfully
	"""
	if not is_valid_position(pos_a) or not is_valid_position(pos_b) or not is_valid_position(pos_c):
		return false

	# All positions must be different
	if pos_a == pos_b or pos_b == pos_c or pos_a == pos_c:
		return false

	var plot_a = get_plot(pos_a)
	var plot_b = get_plot(pos_b)
	var plot_c = get_plot(pos_c)

	if plot_a == null or plot_b == null or plot_c == null:
		return false

	# Mark as triplet Bell gate in biome (kitchen can query these)
	var biome_a = get_biome_for_plot(pos_a)  # Phase 2c: Use first plot's biome
	if biome_a and biome_a.has_method("mark_bell_gate"):
		biome_a.mark_bell_gate([pos_a, pos_b, pos_c])
		print("🔔 Triple entanglement marked: %s, %s, %s (kitchen ready)" % [pos_a, pos_b, pos_c])

	# Emit signal for UI feedback
	entanglement_created.emit(pos_a, pos_b)  # Use first two positions for signal

	return true


func remove_entanglement(pos_a: Vector2i, pos_b: Vector2i):
	"""Remove entanglement between two plots"""
	var plot_a = get_plot(pos_a)
	var plot_b = get_plot(pos_b)

	# Find and remove EntangledPair if it exists
	if plot_a and plot_a.quantum_state.entangled_pair != null:
		var pair = plot_a.quantum_state.entangled_pair
		if pair in entangled_pairs:
			entangled_pairs.erase(pair)

		# Unlink from both qubits
		if plot_a:
			plot_a.quantum_state.entangled_pair = null
		if plot_b:
			plot_b.quantum_state.entangled_pair = null

	# Also remove legacy entanglement tracking
	if plot_a:
		plot_a.remove_entanglement(plot_b.plot_id if plot_b else "")
	if plot_b:
		plot_b.remove_entanglement(plot_a.plot_id if plot_a else "")

	entanglement_removed.emit(pos_a, pos_b)


func are_plots_entangled(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	"""Check if two plots are entangled"""
	var plot_a = get_plot(pos_a)
	var plot_b = get_plot(pos_b)

	if plot_a == null or plot_b == null:
		return false

	return plot_a.entangled_plots.has(plot_b.plot_id)


## Icon Management

func add_icon(icon) -> void:
	"""Add Icon to farm for quantum effects"""
	if icon not in active_icons:
		active_icons.append(icon)
		print("✨ Added Icon to farm: %s" % icon.icon_name)


func add_scoped_icon(icon, biome_names: Array[String]) -> void:
	"""Add Icon that only affects plots in specific biomes

	Args:
		icon: The icon instance to add
		biome_names: Array of biome names this icon affects (e.g., ["Forest"])
	"""
	if icon not in active_icons:
		active_icons.append(icon)
		icon_scopes[icon] = biome_names
		print("✨ Scoped Icon added to farm: %s → %s" % [icon.icon_name, biome_names])
	else:
		# Icon already active - just update scope
		icon_scopes[icon] = biome_names
		print("   📍 Updated scope for %s → %s" % [icon.icon_name, biome_names])


func remove_icon(icon) -> void:
	"""Remove Icon from farm"""
	if icon in active_icons:
		active_icons.erase(icon)
		print("🚫 Removed Icon from farm: %s" % icon.icon_name)


func get_effective_temperature() -> float:
	"""Get effective farm temperature from base + all Icons"""
	var temp = base_temperature
	for icon in active_icons:
		if icon.active_strength > 0.0:
			temp += icon.get_effective_temperature() - icon.base_temperature
	return temp


## Utility

func get_neighbors(position: Vector2i) -> Array[Vector2i]:
	"""Get valid neighbor positions (4-directional)"""
	var neighbors: Array[Vector2i] = []

	var directions = [
		Vector2i(0, -1),  # Up
		Vector2i(1, 0),   # Right
		Vector2i(0, 1),   # Down
		Vector2i(-1, 0)   # Left
	]

	for dir in directions:
		var neighbor_pos = position + dir
		if is_valid_position(neighbor_pos):
			neighbors.append(neighbor_pos)

	return neighbors


func get_all_planted_positions() -> Array[Vector2i]:
	"""Get positions of all planted plots"""
	var planted: Array[Vector2i] = []
	for position in plots.keys():
		if plots[position].is_planted:
			planted.append(position)
	return planted


func get_all_mature_positions() -> Array[Vector2i]:
	"""Get positions of all mature plots"""
	var mature: Array[Vector2i] = []
	for position in plots.keys():
		if plots[position].is_planted:  # Quantum-only: all planted plots are "mature"
			mature.append(position)
	return mature


func get_grid_stats() -> Dictionary:
	"""Get current grid statistics"""
	var planted_count = 0
	var mature_count = 0
	var entanglement_count = 0

	for plot in plots.values():
		if plot.is_planted:
			planted_count += 1
			mature_count += 1  # Quantum-only: all planted = mature
		entanglement_count += plot.get_entanglement_count()

	# Each entanglement is counted twice (bidirectional)
	entanglement_count /= 2

	return {
		"total_plots": plots.size(),
		"planted": planted_count,
		"mature": mature_count,
		"entanglements": entanglement_count,
		"total_harvested": total_wheat_harvested
	}


## Debug

func print_grid_state():
	"""Debug: Print current grid state"""
	print("\n=== FARM GRID STATE ===")
	var stats = get_grid_stats()
	print("Plots: %d | Planted: %d | Mature: %d | Entangled: %d" % [
		stats["total_plots"],
		stats["planted"],
		stats["mature"],
		stats["entanglements"]
	])
	print("Total Harvested: %d wheat" % total_wheat_harvested)

	for y in range(grid_height):
		var row = ""
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			var plot = plots.get(pos)

			if plot == null or not plot.is_planted:
				row += "[ ]"
			else:
				# Quantum-only: all planted plots shown as [M]
				row += "[M]"

		print(row)

	print("======================\n")
