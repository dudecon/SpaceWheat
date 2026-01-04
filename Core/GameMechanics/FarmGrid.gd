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

# Generic signals for visualization and biome updates
# plot_changed: Unified signal for any plot state change (plant, harvest, gate, entangle)
#   change_type: "planted", "harvested", "gate_added", "gate_removed", "entangled", "disentangled"
#   details: {"plant_type": "wheat"} or {"gate_type": "cluster"} etc.
signal plot_changed(position: Vector2i, change_type: String, details: Dictionary)

# visualization_changed: Simple trigger for UI components that just need to redraw
signal visualization_changed()

# Preload classes
const FarmPlot = preload("res://Core/GameMechanics/FarmPlot.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
# const Biome = preload("res://Core/Environment/Biome.gd")  # Legacy - REMOVED: file no longer exists
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

# MODEL B: Register allocation (Phase 0.5)
var plot_register_mapping: Dictionary = {}  # Vector2i → int (plot position → register_id in biome)
var plot_to_biome_quantum_computer: Dictionary = {}  # Vector2i → QuantumComputer reference

# VOCABULARY EVOLUTION - Quantum concept discovery system (injected by Farm)
var vocabulary_evolution = null  # Reference to VocabularyEvolution

# Environmental parameters
var base_temperature: float = 20.0  # Base farm temperature (Kelvin or relative)
var active_icons: Array = []  # Array of LindbladIcon affecting the farm
var icon_scopes: Dictionary = {}  # Icon → Array[String] (biome names the icon affects)

# Stats
var total_plots_planted: int = 0


func _ready():
	print("🌾 FarmGrid initialized: %dx%d = %d plots" % [grid_width, grid_height, grid_width * grid_height])

	# Initialize topology analyzer
	topology_analyzer = TopologyAnalyzer.new()

	# Initialize Biome ONLY if not already injected by Farm
	# Farm will handle Biome creation and pass it if available
	if not biome:
		print("   ℹ️  No biome injected - running in simple mode")
		# Don't create biome here - let Farm control it

	# Pre-initialize all plots for headless testing compatibility
	_initialize_all_plots()

	# Note: Quantum states are initialized later in FarmView after plots are created

	set_process(true)


func _initialize_all_plots() -> void:
	"""Pre-initialize all plots in the grid for headless testing compatibility.
	Without this, the plots dictionary is only populated on-demand via get_plot(),
	causing tests that check plots.size() to fail."""
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			if not plots.has(pos):
				var plot = FarmPlot.new()
				plot.plot_id = "plot_%d_%d" % [x, y]
				plot.grid_position = pos
				plots[pos] = plot
				if faction_territory_manager:
					faction_territory_manager.register_plot(pos)


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

	# PHASE 4: Process energy taps (collect Lindblad drain flux)
	_process_energy_taps(delta)

	# Update vocabulary mutation pressure from active energy taps
	if vocabulary_evolution:
		var tap_boost = get_tap_mutation_pressure_boost()

		# Apply boost (additive, capped at 2.0)
		vocabulary_evolution.mutation_pressure = min(
			0.15 + tap_boost,  # Base 0.15 + tap boost
			2.0  # Max cap
		)

	# Process quantum mills (QuantumMill objects with non-destructive measurement)
	_process_quantum_mills(delta)

	# Process markets (sell flour for credits)
	_process_markets(delta)

	# Process kitchens (convert flour to bread)
	_process_kitchens(delta)

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


## MODEL B: REGISTER ALLOCATION (Phase 0.5)

func allocate_register_for_plot(position: Vector2i, north_emoji: String, south_emoji: String) -> int:
	"""Allocate a quantum register for a plot in its biome's quantum computer

	Model B: Each plot gets a logical qubit RegisterId in the parent biome's QuantumComputer.
	Called by BasePlot.plant() during planting.

	Args:
		position: Grid position of the plot
		north_emoji: Basis label for |0⟩ state
		south_emoji: Basis label for |1⟩ state

	Returns:
		Register ID (int) if successful, -1 if failed
	"""
	# Get biome for this plot
	var plot_biome = get_biome_for_plot(position)
	if not plot_biome or not plot_biome.has_method("allocate_register_for_plot"):
		push_error("Cannot allocate register: biome missing quantum_computer for plot %s" % position)
		return -1

	# Delegate to biome's quantum computer
	var register_id = plot_biome.allocate_register_for_plot(position, north_emoji, south_emoji)

	if register_id < 0:
		push_error("Failed to allocate register for plot %s" % position)
		return -1

	# Track mapping for FarmGrid (visualization team)
	plot_register_mapping[position] = register_id
	plot_to_biome_quantum_computer[position] = plot_biome.quantum_computer

	return register_id


func get_register_for_plot(position: Vector2i) -> int:
	"""Get the RegisterId for a plot

	Returns:
		Register ID (int) if plot is planted, -1 if not found
	"""
	return plot_register_mapping.get(position, -1)


func clear_register_for_plot(position: Vector2i) -> void:
	"""Clear register allocation for a plot (called after harvest)

	Model B: Removes register from biome's quantum computer and clears FarmGrid tracking.
	"""
	var register_id = plot_register_mapping.get(position, -1)
	if register_id < 0:
		return

	# Get biome and delegate cleanup
	var plot_biome = get_biome_for_plot(position)
	if plot_biome and plot_biome.has_method("clear_register_for_plot"):
		plot_biome.clear_register_for_plot(position)

	# Clear FarmGrid tracking
	plot_register_mapping.erase(position)
	plot_to_biome_quantum_computer.erase(position)


## ENTANGLEMENT GRAPH EXPORT (Phase 0.5 - for Visualization Team)

func get_entanglement_graph() -> Dictionary:
	"""Export aggregated entanglement graph from all biomes

	Returns a consolidated entanglement_graph showing which registers are entangled across all biomes.
	Format: {register_id → Array[register_id]} (adjacency list)

	Used by visualization team to render entanglement relationships.
	"""
	var consolidated_graph: Dictionary = {}

	# Collect entanglement graphs from all biomes
	for biome_name in biomes.keys():
		var biome = biomes[biome_name]
		if biome and biome.has_method("quantum_computer"):
			var quantum_comp = biome.quantum_computer
			if quantum_comp and quantum_comp.entanglement_graph:
				# Merge this biome's graph into consolidated graph
				for reg_id in quantum_comp.entanglement_graph.keys():
					var entangled_with = quantum_comp.entanglement_graph[reg_id]
					if not consolidated_graph.has(reg_id):
						consolidated_graph[reg_id] = []

					# Add unique entanglements
					for partner_id in entangled_with:
						if not consolidated_graph[reg_id].has(partner_id):
							consolidated_graph[reg_id].append(partner_id)

	return consolidated_graph


func get_plot_to_register_mapping() -> Dictionary:
	"""Export plot position → register_id mapping for visualization team

	Returns: {Vector2i position → int register_id}
	Used to correlate visual grid with quantum register structure.
	"""
	return plot_register_mapping.duplicate()


func get_quantum_computer_for_plot(position: Vector2i) -> Resource:
	"""Get the QuantumComputer instance for a plot's biome

	Returns: QuantumComputer resource, or null if not available
	"""
	return plot_to_biome_quantum_computer.get(position, null)


func _apply_icon_effects(delta: float):
	"""Model B: Quantum evolution now handled by BiomeBase.quantum_computer

	This method is deprecated. Quantum evolution happens through:
	1. QuantumBath Lindblad evolution in BiomeBase
	2. Icon Hamiltonians registered in quantum_computer (via build_hamiltonian_from_icons)
	3. Per-plot effects handled by quantum_computer projections

	Legacy plot.quantum_state per-plot evolution no longer used.
	"""
	# Quantum evolution moved to BiomeBase and QuantumComputer
	pass


func _apply_entangled_pair_decoherence(delta: float):
	"""Model B: Entangled pair decoherence handled by quantum_computer

	Lindblad evolution for entangled states now happens in:
	- BiomeBase.quantum_computer via QuantumBath Lindblad evolution
	- LindbladSuperoperator applies two-qubit operators automatically
	"""
	# Entanglement decoherence moved to QuantumComputer
	pass


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


func _process_energy_taps(delta: float) -> void:
	"""Process energy taps: collect Lindblad drain flux and accumulate in plots.

	Called each frame to harvest energy from active drain operators in the quantum bath.
	For each tapped emoji, queries the biome's quantum computer for accumulated flux
	and adds it to the corresponding energy tap plot's accumulated resource pool.

	Manifest Section 4.1: Implements gozouta ("energy exit") from quantum system.
	"""
	# For each biome, process its energy taps
	for biome_name in biomes.keys():
		var plot_biome = biomes[biome_name]
		if not plot_biome:
			continue

		# Call biome's process_energy_taps to collect Lindblad flux
		var fluxes = plot_biome.process_energy_taps(delta)
		if fluxes.is_empty():
			continue

		# Accumulate flux in corresponding energy tap plots
		for position in plots.keys():
			var plot = plots[position]
			if plot.plot_type != FarmPlot.PlotType.ENERGY_TAP or not plot.is_planted:
				continue

			# Check if this plot is in the current biome
			var plot_biome_check = get_biome_for_plot(position)
			if plot_biome_check != plot_biome:
				continue

			# Get target emoji for this tap
			var target_emoji = plot.tap_target_emoji
			if target_emoji == "":
				continue

			# Add accumulated flux to plot's resource pool
			if fluxes.has(target_emoji):
				var flux = fluxes[target_emoji]
				plot.tap_accumulated_resource += flux

				# Debug output (can be disabled in production)
				if flux > 0.001:  # Only log meaningful flux
					print("⚡ Energy tap at %s accumulated %.4f from %s" % [
						plot.plot_id, flux, target_emoji
					])


func _process_quantum_mills(delta: float) -> void:
	"""Process quantum mills each frame - trigger measurement cycles.

	Called from _process() to run QuantumMill measurement routines.
	Each mill performs periodic quantum measurements on adjacent wheat plots
	and accumulates flour through the game loop.
	"""
	if quantum_mills.is_empty():
		return

	for position in quantum_mills.keys():
		var mill = quantum_mills[position]
		if mill:
			# Let mill run its measurement cycle
			mill._process(delta)


func process_mill_flour(flour_amount: int) -> void:
	"""Convert mill-produced flour to economy resources.

	Called by QuantumMill.perform_quantum_measurement() when flour outcomes occur.
	Routes flour through FarmEconomy to convert to classical resources.

	Args:
		flour_amount: Number of flour units produced by mill measurement
	"""
	if not farm_economy or flour_amount <= 0:
		return

	# Convert flour through economy system
	# 10 quantum units of flour → economy resource
	var result = farm_economy.process_wheat_to_flour(flour_amount)

	if result.get("success", false):
		print("🌾→💨 Mill: %d flour → %d credits" % [
			flour_amount,
			result.get("credits_gained", 0)
		])


func _process_markets(delta: float) -> void:
	"""Process market buildings each frame - auto-sell accumulated flour.

	Called from _process() to handle automatic market sales.
	Each market building automatically sells accumulated flour for credits.
	Implements the flour → credits conversion step of the production chain.
	"""
	if not farm_economy or plots.is_empty():
		return

	for position in plots.keys():
		var plot = plots[position]
		if plot.plot_type != FarmPlot.PlotType.MARKET or not plot.is_planted:
			continue

		# Check if any flour is available for sale
		var flour_available = farm_economy.get_resource("💨")
		if flour_available <= 0:
			continue

		# Market operates on integer flour units, convert from quantum units
		# Quantum to flour ratio: 10 quantum = 1 flour unit
		var flour_units = int(flour_available / 10.0)
		if flour_units <= 0:
			continue

		# Sell flour at market
		var result = farm_economy.sell_flour_at_market(flour_units)

		if result.get("success", false):
			var credits_gained = result.get("credits_gained", 0)
			var market_cut = result.get("market_cut", 0)
			print("💨→💰 Market at %s: sold %d flour → %d credits (market took %d)" % [
				plot.plot_id, flour_units, credits_gained, market_cut
			])


func _process_kitchens(delta: float) -> void:
	"""Process kitchen buildings each frame - auto-convert flour to bread.

	Called from _process() to handle automatic bread baking.
	Each kitchen building automatically converts accumulated flour to bread.
	Implements the flour → bread conversion step of the production chain (optional).
	"""
	if not farm_economy or plots.is_empty():
		return

	for position in plots.keys():
		var plot = plots[position]
		if plot.plot_type != FarmPlot.PlotType.KITCHEN or not plot.is_planted:
			continue

		# Check if any flour is available for baking
		var flour_available = farm_economy.get_resource("💨")
		if flour_available <= 0:
			continue

		# Kitchen operates on integer flour units, convert from quantum units
		# Quantum to flour ratio: 10 quantum = 1 flour unit
		var flour_units = int(flour_available / 10.0)
		if flour_units <= 0:
			continue

		# Convert flour to bread
		var result = farm_economy.process_flour_to_bread(flour_units)

		if result.get("success", false):
			var bread_produced = result.get("bread_produced", 0)
			print("💨→🍞 Kitchen at %s: baked %d flour → %d bread" % [
				plot.plot_id, flour_units, bread_produced
			])


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


# REMOVED: _initialize_quantum_states() - Legacy Model A method
# Model B: Quantum states are created on-demand when plots are planted, not pre-initialized


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

	# Plant with biome injection (Model B)
	# Get plot-specific biome from multi-biome registry
	var plot_biome = null
	if plot_biome_assignments.has(position):
		var biome_name = plot_biome_assignments[position]
		plot_biome = biomes.get(biome_name, null)
	else:
		# Fallback to BioticFlux if no assignment
		plot_biome = biomes.get("BioticFlux", biome)

	# Plant through biome's quantum computer (Model B)
	plot.plant(0.0, 0.1, plot_biome)  # 0.1 quantum wheat, 0 labor

	# MODEL B: Track register allocation (Phase 0.5)
	# After plot.plant() succeeds, sync FarmGrid's register tracking
	if plot.register_id >= 0:
		plot_register_mapping[position] = plot.register_id
		plot_biome = get_biome_for_plot(position)
		if plot_biome and plot_biome.has_method("quantum_computer"):
			plot_to_biome_quantum_computer[position] = plot_biome.quantum_computer

	total_plots_planted += 1
	plot_planted.emit(position)

	# Emit generic signals for visualization and biome updates
	plot_changed.emit(position, "planted", {"plant_type": plant_type})
	visualization_changed.emit()

	# AUTO-ENTANGLE: If this plot has infrastructure entanglements, entangle quantum states
	_auto_entangle_from_infrastructure(position)

	# AUTO-APPLY PERSISTENT GATES: Apply any persistent gate infrastructure to new qubit
	_auto_apply_persistent_gates(position)

	return true


# REMOVED: Deprecated plant_wheat/plant_tomato/plant_mushroom wrappers
# Use plant(position, "wheat"|"tomato"|"mushroom") instead


func plant_energy_tap(position: Vector2i, target_emoji: String, drain_rate: float = 0.1) -> bool:
	"""Plant an energy tap plot configured to drain a specific emoji

	Energy taps continuously pull energy from target emojis using Lindblad drain operators.
	The tapped energy flows to sink state and accumulates as classical resources.

	PROGRESSION: Energy taps can only target emojis from discovered vocabulary. This restricts
	tap availability to emojis the player has encountered through the vocabulary evolution system.

	Manifest Section 4.1: Energy taps use L_e = |sink⟩⟨e| drain operators.

	Args:
		position: Grid position to plant the tap at
		target_emoji: The emoji to tap (must be in discovered vocabulary)
		drain_rate: Drain rate κ in probability/sec (default: 0.1)

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

	# Get biome for this plot
	var plot_biome = get_biome_for_plot(position)
	if not plot_biome or not plot_biome.bath:
		push_error("⚠️  Cannot plant tap: No bath available for plot %s" % position)
		return false

	# Get Icon for target emoji from IconRegistry
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_error("⚠️  Cannot plant tap: IconRegistry not found")
		return false

	var target_icon = icon_registry.get_icon(target_emoji)
	if not target_icon:
		push_error("⚠️  Cannot plant tap: Icon not found for %s" % target_emoji)
		return false

	# Configure Icon as drain target (Manifest Section 4.1)
	target_icon.is_drain_target = true
	target_icon.drain_to_sink_rate = drain_rate

	# Ensure target emoji is in bath
	var bath = plot_biome.bath
	if not bath.has_emoji(target_emoji):
		print("   ℹ️  Injecting %s into bath for energy tap" % target_emoji)
		bath.inject_emoji(target_emoji, target_icon)

	# Ensure sink state is in bath
	if not bath.has_emoji(bath.sink_emoji):
		print("   ℹ️  Injecting sink state %s into bath" % bath.sink_emoji)
		var sink_icon = Icon.new()
		sink_icon.emoji = bath.sink_emoji
		sink_icon.display_name = "Sink"
		sink_icon.is_eternal = true  # Sink never decays
		bath.inject_emoji(bath.sink_emoji, sink_icon)

	# Rebuild operators to include drain (Manifest Section 4.1)
	bath.build_hamiltonian_from_icons(bath.active_icons)
	bath.build_lindblad_from_icons(bath.active_icons)

	# Configure plot as energy tap
	plot.plot_type = FarmPlot.PlotType.ENERGY_TAP
	plot.tap_target_emoji = target_emoji
	plot.tap_accumulated_resource = 0.0
	plot.tap_drain_rate = drain_rate
	plot.tap_last_flux_check = 0.0

	plot.is_planted = true
	total_plots_planted += 1
	plot_planted.emit(position)

	print("⚡ Planted energy tap at %s targeting %s (κ=%.3f/sec, sink-based drain)" % [
		plot.plot_id, target_emoji, drain_rate
	])
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


func place_kitchen(position: Vector2i) -> bool:
	"""Place kitchen building - converts flour to bread"""
	var plot = get_plot(position)
	if plot == null or plot.is_planted:
		return false

	# Mark as occupied (buildings are instantly "mature")
	plot.plot_type = FarmPlot.PlotType.KITCHEN
	plot.is_planted = true
	plot_planted.emit(position)

	print("🍳 Placed kitchen at %s" % position)
	return true


func harvest_wheat(position: Vector2i) -> Dictionary:
	"""Harvest wheat at position (quantum-only: must be planted)"""
	var plot = get_plot(position)
	if plot == null or not plot.is_planted:
		return {"success": false}

	var yield_data = plot.harvest()
	if yield_data["success"]:
		# MODEL B: Clear register allocation (Phase 0.5)
		clear_register_for_plot(position)

		# Remove projection from biome (clears bath tracking)
		var plot_biome = get_biome_for_plot(position)
		if plot_biome and plot_biome.has_method("remove_projection"):
			plot_biome.remove_projection(position)
			print("   🗑️  Removed projection from biome at %s" % position)

		plot_harvested.emit(position, yield_data)

		# Emit generic signals for visualization update
		plot_changed.emit(position, "harvested", {"yield": yield_data})
		visualization_changed.emit()

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
	# Model B: Use FarmGrid metadata instead of plot.quantum_state
	if not center_plot:
		return []

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


# REMOVED: _find_plot_by_qubit() - Legacy Model A method
# Model B: No direct qubit objects; all access through QuantumComputer and register_id


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

	# 3. Check coherence via quantum_computer (Model B)
	var coherence = 1.0
	var biome = get_biome_for_plot(position)
	var register_id = plot_register_mapping.get(position, -1)

	if biome and biome.quantum_computer and register_id >= 0:
		var comp = biome.quantum_computer.get_component_containing(register_id)
		if comp:
			coherence = biome.quantum_computer.get_marginal_coherence(comp, register_id)
			coherence = clamp(coherence, 0.0, 1.0)

	# 4. Measure quantum state via quantum_computer (Model B)
	# quantum_computer.measure_register() handles ALL cascading internally:
	# - Cluster collapse (all qubits in component)
	# - Pair collapse (both qubits)
	# - Single qubit measurement
	var measurement_result = ""
	if biome and biome.quantum_computer and register_id >= 0:
		var comp = biome.quantum_computer.get_component_containing(register_id)
		if comp:
			# Unified measurement - returns "north" or "south" basis label
			var basis_outcome = biome.quantum_computer.measure_register(comp, register_id)
			# Map basis outcome to emoji
			measurement_result = plot.north_emoji if basis_outcome == "north" else plot.south_emoji
			print("📊 Harvest measurement at %s: outcome = %s" % [position, measurement_result])
		else:
			# Register not in any component - unentangled single qubit
			# This shouldn't happen in normal gameplay, but handle gracefully
			measurement_result = plot.north_emoji  # Default to north state

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

	# 10. Break entanglements (Model B: quantum_computer handled collapse)
	# quantum_computer.measure_register() already handled:
	# - Cluster/pair collapse at quantum level
	# - Register state updates
	# - Component cleanup
	#
	# We only clear FarmGrid metadata tracking:

	# Clear WheatPlot entanglement tracking
	for partner_id in plot.entangled_plots.keys():
		var partner_pos = _find_plot_by_id(partner_id)
		if partner_pos != Vector2i(-1, -1):
			var partner_plot = get_plot(partner_pos)
			if partner_plot:
				partner_plot.entangled_plots.erase(plot.plot_id)
	plot.entangled_plots.clear()

	# Note: EntangledPair objects no longer tracked - they were Model A artifacts
	# quantum_computer manages entanglement via register_id and components

	# 11. Reset plot
	plot.reset()

	# MODEL B: Clear register allocation (Phase 0.5)
	clear_register_for_plot(position)

	# 12. Emit signal with full data
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
	"""Measure quantum state (observer effect). Entanglement means measuring one collapses entire network!

	Model B: Delegates measurement to quantum_computer, which handles all cascading.
	Entanglement network collapse is automatic via quantum_computer.measure_register().
	"""
	var plot = get_plot(position)
	if plot == null or not plot.is_planted:
		return ""

	# Get biome and register for primary plot
	var biome = get_biome_for_plot(position)
	var register_id = plot_register_mapping.get(position, -1)

	if not biome or not biome.quantum_computer or register_id < 0:
		# Fallback: No quantum computer available - return default
		print("⚠️  No quantum computer for plot at %s - measurement unavailable" % position)
		return plot.north_emoji

	var comp = biome.quantum_computer.get_component_containing(register_id)
	if not comp:
		# Unentangled single qubit - shouldn't happen but handle gracefully
		return plot.north_emoji

	# Model B: Single unified measurement call handles ALL cascading
	# quantum_computer automatically:
	# 1. Measures primary register
	# 2. Collapses entire component (all entangled qubits)
	# 3. Updates all register states
	# 4. Returns basis outcome ("north" or "south")
	var basis_outcome = biome.quantum_computer.measure_register(comp, register_id)
	# Map basis outcome to emoji
	var result = plot.north_emoji if basis_outcome == "north" else plot.south_emoji
	print("📊 Measure operation: %s collapsed to %s" % [position, result])

	# For compatibility, still track which plots were in the component
	# (This is purely for logging/visualization - quantum collapse already happened in quantum_computer)
	var measured_ids = {plot.plot_id: true}

	# Flood-fill through FarmGrid entanglement metadata to find component
	# (This mirrors the quantum measurement - all plots in component are now measured)
	var to_check = []
	for entangled_id in plot.entangled_plots.keys():
		to_check.append(entangled_id)

	# Flood-fill through the entanglement network
	while not to_check.is_empty():
		var current_id = to_check.pop_front()

		# Skip if already processed
		if measured_ids.has(current_id):
			continue

		# Find this plot
		var current_pos = _find_plot_by_id(current_id)
		if current_pos == Vector2i(-1, -1):
			continue

		var current_plot = get_plot(current_pos)
		if not current_plot or not current_plot.is_planted:
			continue

		# Mark as measured (quantum_computer already handled the measurement)
		print("  ↪ Entanglement network collapsed %s (via quantum_computer)" % current_id)
		measured_ids[current_id] = true

		# Add its entangled partners to the queue
		for next_id in current_plot.entangled_plots.keys():
			if not measured_ids.has(next_id):
				to_check.append(next_id)

	# MEASUREMENT COLLAPSES TO CLASSICAL STATE: (Model B)
	# Break ALL entanglements for measured plots (quantum → classical transition)
	# Measured plots become classical and no longer participate in quantum network
	# Note: quantum_computer already handled the collapse - we only clear metadata
	for measured_id in measured_ids.keys():
		var measured_pos = _find_plot_by_id(measured_id)
		if measured_pos == Vector2i(-1, -1):
			continue

		var measured_plot = get_plot(measured_pos)
		if not measured_plot:
			continue

		# Clear all entanglements for this plot (FarmGrid metadata only)
		if not measured_plot.entangled_plots.is_empty():
			var num_broken = measured_plot.entangled_plots.size()
			measured_plot.entangled_plots.clear()
			print("  🔓 Measurement broke %d entanglements for %s (classical state)" % [num_broken, measured_id])

	# Note: EntangledPair objects were Model A artifacts managed via plot.quantum_state
	# Model B: Entanglement is managed by quantum_computer via registers and components
	# No manual pair cleanup needed

	# Emit signals for visualization update (CRITICAL for visual feedback!)
	# Measure operation changes plot state from unmeasured → measured
	plot_changed.emit(position, "measured", {"outcome": result})
	visualization_changed.emit()

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


func _add_to_cluster(cluster, new_plot: FarmPlot, control_index: int) -> bool:
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


func _upgrade_pair_to_cluster(pair, new_plot: FarmPlot) -> bool:
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


func _auto_apply_persistent_gates(position: Vector2i) -> void:
	"""Apply persistent gate infrastructure to newly planted qubit.

	Called automatically from plant() after _auto_entangle_from_infrastructure().
	Gates marked as 'active' on the plot are applied to the new quantum state.
	"""
	var plot = get_plot(position)
	if not plot or not plot.is_planted or plot.register_id < 0:
		return

	var active_gates = plot.get_active_gates()
	if active_gates.is_empty():
		return

	print("🔧 Auto-applying %d persistent gates to %s" % [active_gates.size(), position])

	for gate in active_gates:
		var gate_type = gate.get("type", "")
		var linked_plots = gate.get("linked_plots", [])

		match gate_type:
			"bell":
				# Bell gate - 2-qubit persistent entanglement
				_auto_cluster_from_gate(position, linked_plots)
			"cluster":
				# Cluster gate - N-qubit persistent entanglement
				_auto_cluster_from_gate(position, linked_plots)
			"measure_trigger":
				# Mark plot for cascade measurement when triggered
				print("  👁️ Measure trigger active on %s" % position)
			_:
				print("  ⚠️ Unknown gate type: %s" % gate_type)


func _auto_cluster_from_gate(position: Vector2i, linked_plots: Array) -> void:
	"""Create cluster entanglement from persistent gate infrastructure.

	Called when planting in a plot that has a cluster gate.
	Entangles with all other planted plots in the linked_plots array.
	"""
	var plot = get_plot(position)
	if not plot or not plot.quantum_state:
		return

	for linked_pos in linked_plots:
		if linked_pos == position:
			continue  # Skip self

		var linked_plot = get_plot(linked_pos)
		if linked_plot and linked_plot.is_planted and linked_plot.quantum_state:
			# Check if already entangled
			if not plot.entangled_plots.has(linked_plot.plot_id):
				_create_quantum_entanglement(position, linked_pos)
				print("  🔗 Cluster gate: entangled %s ↔ %s" % [position, linked_pos])


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
	plot_a.add_entanglement(plot_b.plot_id, 1.0)
	plot_b.add_entanglement(plot_a.plot_id, 1.0)

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
		# Emit generic signals
		plot_changed.emit(pos_a, "entangled", {"partner": pos_b})
		plot_changed.emit(pos_b, "entangled", {"partner": pos_a})
		visualization_changed.emit()
		return true  # Infrastructure created successfully

	# Both plots are planted → Create quantum entanglement using helper
	var success = _create_quantum_entanglement(pos_a, pos_b, bell_type)
	if success:
		entanglement_created.emit(pos_a, pos_b)
		# Emit generic signals
		plot_changed.emit(pos_a, "entangled", {"partner": pos_b})
		plot_changed.emit(pos_b, "entangled", {"partner": pos_a})
		visualization_changed.emit()
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
		"entanglements": entanglement_count
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
