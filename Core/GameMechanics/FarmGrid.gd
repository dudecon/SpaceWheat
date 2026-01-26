class_name FarmGrid
extends Node

## FarmGrid - Orchestrator for farm grid management (Decomposed)
##
## This is a FACADE that delegates to focused components:
## - GridPlotManager: Plot lifecycle and queries
## - BiomeRoutingManager: Multi-biome registry and routing
## - EntanglementManager: Quantum entanglement operations
## - PlantingManager: Crop planting with parametric capabilities
## - BuildingManager: Mill, market, kitchen placement
## - HarvestMeasurementManager: Harvest and measurement operations
##
## All public methods are preserved for backward compatibility.

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = get_node("/root/VerboseConfig")

# ═══════════════════════════════════════════════════════════════════════════════
# SIGNALS (unchanged API)
# ═══════════════════════════════════════════════════════════════════════════════

# Internal signals (for FarmGrid-level operations)
signal plot_planted(position: Vector2i)
signal plot_harvested(position: Vector2i, yield_data: Dictionary)

signal entanglement_created(from: Vector2i, to: Vector2i)
signal entanglement_removed(from: Vector2i, to: Vector2i)

# Generic signals for visualization and biome updates
signal plot_changed(position: Vector2i, change_type: String, details: Dictionary)
signal visualization_changed()

# ═══════════════════════════════════════════════════════════════════════════════
# COMPONENT PRELOADS
# ═══════════════════════════════════════════════════════════════════════════════

const GridPlotManager = preload("res://Core/GameMechanics/Grid/GridPlotManager.gd")
const BiomeRoutingManager = preload("res://Core/GameMechanics/Grid/BiomeRoutingManager.gd")
const EntanglementManager = preload("res://Core/GameMechanics/Grid/EntanglementManager.gd")
const PlantingManager = preload("res://Core/GameMechanics/Grid/PlantingManager.gd")
const BuildingManager = preload("res://Core/GameMechanics/Grid/BuildingManager.gd")
const HarvestMeasurementManager = preload("res://Core/GameMechanics/Grid/HarvestMeasurementManager.gd")

const FarmPlot = preload("res://Core/GameMechanics/FarmPlot.gd")
const Icon = preload("res://Core/QuantumSubstrate/Icon.gd")

# ═══════════════════════════════════════════════════════════════════════════════
# COMPONENTS (internal)
# ═══════════════════════════════════════════════════════════════════════════════

var _plot_manager: GridPlotManager
var _biome_routing: BiomeRoutingManager
var _entanglement: EntanglementManager
var _planting: PlantingManager
var _buildings: BuildingManager
var _harvest: HarvestMeasurementManager

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION & STATE (preserved for backward compatibility)
# ═══════════════════════════════════════════════════════════════════════════════

# Grid configuration
@export var grid_width: int = 5
@export var grid_height: int = 5

# External references (injected by Farm.gd)
var conspiracy_network = null
var faction_territory_manager = null
var farm_economy = null
var vocabulary_evolution = null

# Legacy biome reference (for backward compatibility)
var biome = null

# Environmental parameters
var base_temperature: float = 20.0
var active_icons: Array = []
var icon_scopes: Dictionary = {}  # Icon → Array[String]

# Stats
var total_plots_planted: int = 0

# PERFORMANCE: Throttle slower subsystems
const MILL_MARKET_UPDATE_INTERVAL: float = 0.1
var _mill_market_accumulator: float = 0.0

# ═══════════════════════════════════════════════════════════════════════════════
# FACADE ACCESSORS (for direct access when needed)
# ═══════════════════════════════════════════════════════════════════════════════

## Direct access to plots dictionary (for backward compatibility)
var plots: Dictionary:
	get:
		return _plot_manager.plots if _plot_manager else {}

## Direct access to biomes dictionary
var biomes: Dictionary:
	get:
		return _biome_routing.biomes if _biome_routing else {}

## Direct access to plot_biome_assignments
var plot_biome_assignments: Dictionary:
	get:
		return _biome_routing.plot_biome_assignments if _biome_routing else {}

## Direct access to plot_register_mapping
var plot_register_mapping: Dictionary:
	get:
		return _biome_routing.plot_register_mapping if _biome_routing else {}

## Direct access to plot_to_biome_quantum_computer
var plot_to_biome_quantum_computer: Dictionary:
	get:
		return _biome_routing.plot_to_biome_quantum_computer if _biome_routing else {}

## Direct access to entangled_pairs
var entangled_pairs: Array:
	get:
		return _entanglement.entangled_pairs if _entanglement else []

## Direct access to entangled_clusters
var entangled_clusters: Array:
	get:
		return _entanglement.entangled_clusters if _entanglement else []

## Direct access to quantum_mills
var quantum_mills: Dictionary:
	get:
		return _buildings.quantum_mills if _buildings else {}

## Direct access to quantum_markets
var quantum_markets: Dictionary:
	get:
		return _buildings.quantum_markets if _buildings else {}

# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _init(width: int = 6, height: int = 4):
	# Set dimensions BEFORE creating GridPlotManager
	grid_width = width
	grid_height = height

	# Create components EARLY so they're available before _ready()
	# This fixes initialization order issues where Farm._ready() calls
	# register_biome() before FarmGrid._ready() runs.
	_plot_manager = GridPlotManager.new(grid_width, grid_height)
	_biome_routing = BiomeRoutingManager.new()
	_entanglement = EntanglementManager.new()
	_planting = PlantingManager.new()
	_buildings = BuildingManager.new()
	_harvest = HarvestMeasurementManager.new()


func _ready():
	_verbose.info("farm", "🌾", "FarmGrid initialized: %dx%d = %d plots" % [grid_width, grid_height, grid_width * grid_height])

	# Wire verbose logger to all components (requires @onready _verbose)
	_plot_manager.set_verbose(_verbose)
	_biome_routing.set_verbose(_verbose)
	_entanglement.set_verbose(_verbose)
	_planting.set_verbose(_verbose)
	_buildings.set_verbose(_verbose)
	_harvest.set_verbose(_verbose)

	# Wire component dependencies
	_entanglement.set_dependencies(_plot_manager, _biome_routing)
	_planting.set_dependencies(_plot_manager, _biome_routing, farm_economy, _entanglement)
	_buildings.set_dependencies(_plot_manager, _biome_routing, _entanglement)
	_buildings.set_parent_node(self)
	_harvest.set_dependencies(_plot_manager, _biome_routing, farm_economy, _entanglement)

	# Wire external references
	_plot_manager.faction_territory_manager = faction_territory_manager

	# Forward signals from components
	_entanglement.entanglement_created.connect(func(a, b): entanglement_created.emit(a, b))
	_entanglement.entanglement_removed.connect(func(a, b): entanglement_removed.emit(a, b))

	_planting.plot_planted.connect(func(pos): plot_planted.emit(pos))
	_planting.plot_changed.connect(func(pos, t, d): plot_changed.emit(pos, t, d))
	_planting.visualization_changed.connect(func(): visualization_changed.emit())

	_harvest.plot_harvested.connect(func(pos, data): plot_harvested.emit(pos, data))
	_harvest.plot_changed.connect(func(pos, t, d): plot_changed.emit(pos, t, d))
	_harvest.visualization_changed.connect(func(): visualization_changed.emit())

	# Pre-initialize all plots
	_plot_manager.initialize_all_plots()

	# Check biome state
	if _biome_routing.is_biomes_empty() and not biome:
		_verbose.info("farm", "ℹ️", "No biomes registered - running in simple mode")

	set_process(true)


func _process(delta):
	# Skip processing if no biomes registered
	if _biome_routing.is_biomes_empty() and not biome:
		return

	# Build icon_network for growth modifiers
	var icon_network = _build_icon_network()

	# Grow all planted plots
	for position in _plot_manager.plots.keys():
		var plot = _plot_manager.plots[position]
		if plot.is_planted:
			var plot_biome = _biome_routing.get_biome_for_plot(position)
			plot.grow(delta, plot_biome, faction_territory_manager, icon_network, conspiracy_network)

	# PERFORMANCE: Throttle slower subsystems to 10 Hz
	_mill_market_accumulator += delta
	if _mill_market_accumulator >= MILL_MARKET_UPDATE_INTERVAL:
		_mill_market_accumulator = 0.0
		# Mills and markets are now passive (no per-frame processing needed)


# ═══════════════════════════════════════════════════════════════════════════════
# MULTI-BIOME REGISTRY (delegates to BiomeRoutingManager)
# ═══════════════════════════════════════════════════════════════════════════════

func register_biome(biome_name: String, biome_instance) -> void:
	"""Register a biome in the grid's biome registry"""
	_biome_routing.register_biome(biome_name, biome_instance)


func assign_plot_to_biome(position: Vector2i, biome_name: String) -> void:
	"""Assign a specific plot to a biome"""
	if not _plot_manager.is_valid_position(position):
		push_error("Cannot assign plot at invalid position: %s" % position)
		return
	_biome_routing.assign_plot_to_biome(position, biome_name)


func get_biome_for_plot(position: Vector2i):
	"""Get the biome responsible for a specific plot"""
	return _biome_routing.get_biome_for_plot(position)


func get_entanglement_graph() -> Dictionary:
	"""Export aggregated entanglement graph from all biomes"""
	return _biome_routing.get_entanglement_graph()


func get_plot_to_register_mapping() -> Dictionary:
	"""Export plot position → register_id mapping"""
	return _biome_routing.get_plot_to_register_mapping()


func get_quantum_computer_for_plot(position: Vector2i) -> Resource:
	"""Get the QuantumComputer instance for a plot's biome"""
	return _biome_routing.get_quantum_computer_for_plot(position)


# ═══════════════════════════════════════════════════════════════════════════════
# PLOT MANAGEMENT (delegates to GridPlotManager)
# ═══════════════════════════════════════════════════════════════════════════════

func get_plot(position: Vector2i) -> FarmPlot:
	"""Get or create plot at position"""
	return _plot_manager.get_plot(position)


func is_valid_position(position: Vector2i) -> bool:
	"""Check if position is within grid bounds"""
	return _plot_manager.is_valid_position(position)


func _find_plot_by_id(plot_id: String) -> Vector2i:
	"""Find grid position of a plot by its ID"""
	return _plot_manager.find_plot_by_id(plot_id)


func _get_plot_by_id(plot_id: String) -> FarmPlot:
	"""Get plot directly by ID"""
	return _plot_manager.get_plot_by_id(plot_id)


func is_plot_empty(position: Vector2i) -> bool:
	"""Check if plot is empty (not planted)"""
	return _plot_manager.is_plot_empty(position)


func is_plot_mature(position: Vector2i) -> bool:
	"""Check if plot has planted wheat"""
	return _plot_manager.is_plot_mature(position)


func get_neighbors(position: Vector2i) -> Array[Vector2i]:
	"""Get valid neighbor positions (4-directional)"""
	return _plot_manager.get_neighbors(position)


func get_all_planted_positions() -> Array[Vector2i]:
	"""Get positions of all planted plots"""
	return _plot_manager.get_all_planted_positions()


func get_all_mature_positions() -> Array[Vector2i]:
	"""Get positions of all mature plots"""
	return _plot_manager.get_all_mature_positions()


func get_grid_stats() -> Dictionary:
	"""Get current grid statistics"""
	return _plot_manager.get_grid_stats()


func print_grid_state():
	"""Debug: Print current grid state"""
	_plot_manager.print_grid_state()


# ═══════════════════════════════════════════════════════════════════════════════
# FARMING OPERATIONS (delegates to PlantingManager)
# ═══════════════════════════════════════════════════════════════════════════════

func plant(position: Vector2i, plant_type: String, quantum_state: Resource = null) -> bool:
	"""Generic plant method - handles all crop types (PARAMETRIC)"""
	# Ensure economy is wired (may be set after _ready)
	if farm_economy and not _planting._economy:
		_planting.set_dependencies(_plot_manager, _biome_routing, farm_economy, _entanglement)

	var result = _planting.plant(position, plant_type, quantum_state)
	if result:
		total_plots_planted = _planting.total_plots_planted
	return result


func _get_adjacent_wheat(position: Vector2i) -> Array:
	"""Get all wheat plots adjacent to a position"""
	return _planting.get_adjacent_wheat(position)


# ═══════════════════════════════════════════════════════════════════════════════
# BUILDING OPERATIONS (delegates to BuildingManager)
# ═══════════════════════════════════════════════════════════════════════════════

func place_mill(position: Vector2i) -> bool:
	"""Place quantum mill building"""
	return _buildings.place_mill(position)


func place_market(position: Vector2i, target_emoji: String = "🌾") -> bool:
	"""Place market building"""
	return _buildings.place_market(position, target_emoji)


func place_kitchen(position: Vector2i) -> bool:
	"""Place kitchen building"""
	return _buildings.place_kitchen(position)


func place_kitchen_triplet(positions: Array[Vector2i]) -> bool:
	"""Place kitchen with triplet entanglement"""
	return _buildings.place_kitchen_triplet(positions)


# ═══════════════════════════════════════════════════════════════════════════════
# HARVEST & MEASUREMENT (delegates to HarvestMeasurementManager)
# ═══════════════════════════════════════════════════════════════════════════════

func harvest_wheat(position: Vector2i) -> Dictionary:
	"""Harvest wheat at position"""
	# Ensure economy is wired
	if farm_economy and not _harvest._economy:
		_harvest.set_dependencies(_plot_manager, _biome_routing, farm_economy, _entanglement)
	return _harvest.harvest_wheat(position)


func measure_plot(position: Vector2i) -> String:
	"""Measure quantum state (observer effect)"""
	return _harvest.measure_plot(position)


# ═══════════════════════════════════════════════════════════════════════════════
# ENTANGLEMENT (delegates to EntanglementManager)
# ═══════════════════════════════════════════════════════════════════════════════

func create_entanglement(pos_a: Vector2i, pos_b: Vector2i, bell_type: String = "phi_plus") -> bool:
	"""Create entanglement between two plots"""
	var result = _entanglement.create_entanglement(pos_a, pos_b, bell_type)
	if result:
		plot_changed.emit(pos_a, "entangled", {"partner": pos_b})
		plot_changed.emit(pos_b, "entangled", {"partner": pos_a})
		visualization_changed.emit()
	return result


func create_triplet_entanglement(pos_a: Vector2i, pos_b: Vector2i, pos_c: Vector2i) -> bool:
	"""Create triple entanglement (3-qubit Bell state)"""
	return _entanglement.create_triplet_entanglement(pos_a, pos_b, pos_c)


func remove_entanglement(pos_a: Vector2i, pos_b: Vector2i):
	"""Remove entanglement between two plots"""
	_entanglement.remove_entanglement(pos_a, pos_b)


func are_plots_entangled(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	"""Check if two plots are entangled"""
	return _entanglement.are_plots_entangled(pos_a, pos_b)


func _auto_entangle_from_infrastructure(position: Vector2i):
	"""Auto-entangle quantum states when planting"""
	_entanglement.auto_entangle_from_infrastructure(position)


func _auto_apply_persistent_gates(position: Vector2i) -> void:
	"""Apply persistent gate infrastructure to newly planted qubit"""
	_entanglement.auto_apply_persistent_gates(position)


func _update_cluster_gameplay_connections(cluster):
	"""Update WheatPlot.entangled_plots for cluster"""
	_entanglement.update_cluster_gameplay_connections(cluster)


func _add_to_cluster(cluster, new_plot, control_index: int) -> bool:
	"""Add new qubit to existing cluster"""
	return _entanglement.add_to_cluster(cluster, new_plot, control_index)


func _upgrade_pair_to_cluster(pair, new_plot) -> bool:
	"""Upgrade 2-qubit pair to 3-qubit cluster"""
	return _entanglement.upgrade_pair_to_cluster(pair, new_plot)


func _handle_cluster_collapse(cluster):
	"""Handle measurement cascade when cluster is measured"""
	_entanglement.handle_cluster_collapse(cluster)


func _create_quantum_entanglement(pos_a: Vector2i, pos_b: Vector2i, bell_type: String = "phi_plus") -> bool:
	"""Create quantum state entanglement (internal helper)"""
	return _entanglement._create_quantum_entanglement(pos_a, pos_b, bell_type)


# ═══════════════════════════════════════════════════════════════════════════════
# ICON MANAGEMENT (kept in FarmGrid)
# ═══════════════════════════════════════════════════════════════════════════════

func add_icon(icon) -> void:
	"""Add Icon to farm for quantum effects"""
	if icon not in active_icons:
		active_icons.append(icon)
		_verbose.info("farm", "✨", "Added Icon to farm: %s" % icon.icon_name)


func add_scoped_icon(icon, biome_names: Array[String]) -> void:
	"""Add Icon that only affects plots in specific biomes"""
	if icon not in active_icons:
		active_icons.append(icon)
		icon_scopes[icon] = biome_names
		_verbose.info("farm", "✨", "Scoped Icon added to farm: %s → %s" % [icon.icon_name, biome_names])
	else:
		icon_scopes[icon] = biome_names
		_verbose.info("farm", "📍", "Updated scope for %s → %s" % [icon.icon_name, biome_names])


func remove_icon(icon) -> void:
	"""Remove Icon from farm"""
	if icon in active_icons:
		active_icons.erase(icon)
		_verbose.info("farm", "🚫", "Removed Icon from farm: %s" % icon.icon_name)


func get_effective_temperature() -> float:
	"""Get effective farm temperature from base + all Icons"""
	var temp = base_temperature
	for icon in active_icons:
		if icon.active_strength > 0.0:
			temp += icon.get_effective_temperature() - icon.base_temperature
	return temp


func _build_icon_network() -> Dictionary:
	"""Build icon_network dictionary from active_icons array"""
	var icon_network = {}

	for icon in active_icons:
		if icon.icon_emoji == "🌾":  # Biotic Flux
			icon_network["biotic"] = icon
		elif icon.icon_emoji == "🍅":  # Chaos Vortex
			icon_network["chaos"] = icon
		elif icon.icon_emoji == "🏰":  # Imperium/Carrion Throne
			icon_network["imperium"] = icon

	return icon_network


# ═══════════════════════════════════════════════════════════════════════════════
# ECONOMY INTEGRATION (kept for mill processing)
# ═══════════════════════════════════════════════════════════════════════════════

func process_mill_flour(flour_amount: int) -> void:
	"""Convert mill-produced flour to economy resources.

	Called by QuantumMill.perform_quantum_measurement() when flour outcomes occur.
	"""
	if not farm_economy or flour_amount <= 0:
		_verbose.error("farm", "❌", "process_mill_flour called with invalid params (amount=%d)" % flour_amount)
		return

	const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
	var flour_credits = flour_amount * EconomyConstants.QUANTUM_TO_CREDITS
	farm_economy.add_resource("💨", flour_credits, "mill_quantum_measurement")

	_verbose.info("economy", "🏭", "Mill: Produced %d flour → %d credits" % [flour_amount, flour_credits])


# ═══════════════════════════════════════════════════════════════════════════════
# REGISTER MANAGEMENT (for visualization - delegates to BiomeRoutingManager)
# ═══════════════════════════════════════════════════════════════════════════════

func get_register_for_plot(position: Vector2i) -> int:
	"""Get the RegisterId for a plot"""
	return _biome_routing.get_register_for_plot(position)


func clear_register_for_plot(position: Vector2i) -> void:
	"""Clear register allocation for a plot (called after harvest)"""
	_biome_routing.clear_register_tracking(position)

	# Also clear in biome
	var plot_biome = _biome_routing.get_biome_for_plot(position)
	if plot_biome and plot_biome.has_method("clear_register_for_plot"):
		plot_biome.clear_register_for_plot(position)
