class_name HarvestMeasurementManager
extends RefCounted

## HarvestMeasurementManager - Quantum measurement, harvesting, topology-based yield
##
## Extracted from FarmGrid.gd as part of decomposition.
## Handles measurement, harvest, topology bonus, coherence penalty.

# Signals
signal plot_harvested(position: Vector2i, yield_data: Dictionary)
signal plot_changed(position: Vector2i, change_type: String, details: Dictionary)
signal visualization_changed()

# Component dependencies (injected via set_dependencies)
var _plot_manager = null  # GridPlotManager (legacy)
var _biome_routing = null  # BiomeRoutingManager
var _economy = null  # FarmEconomy
var _entanglement = null  # EntanglementManager (legacy)
var _plot_pool = null  # PlotPool (terminal source of truth)
var _farm = null  # Farm (optional, for neighbor-based yield)
var _verbose = null

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")


func set_dependencies(plot_manager, biome_routing, economy, entanglement, plot_pool = null, farm_ref = null, _topology_analyzer = null) -> void:
	"""Inject component dependencies."""
	_plot_manager = plot_manager
	_biome_routing = biome_routing
	_economy = economy
	_entanglement = entanglement
	_plot_pool = plot_pool
	_farm = farm_ref
	# Note: topology_analyzer param kept for API compatibility but no longer used


func set_verbose(verbose_ref) -> void:
	"""Set verbose logger reference."""
	_verbose = verbose_ref


func harvest_wheat(position: Vector2i) -> Dictionary:
	"""Harvest a measured terminal at position (terminal-first)."""
	if not _plot_pool:
		return {"success": false, "error": "no_pool"}

	var terminal = _plot_pool.get_terminal_at_grid_pos(position)
	if not terminal:
		return {"success": false, "error": "no_terminal"}

	var harvest_result = ProbeActions.action_pop(terminal, _plot_pool, _economy, _farm)
	if not harvest_result.get("success", false):
		return harvest_result

	# Map to legacy keys for compatibility
	var outcome = harvest_result.get("resource", "")
	var amount = harvest_result.get("amount", 0)
	var credits = harvest_result.get("credits", 0.0)
	var yield_data = {
		"success": true,
		"outcome": outcome,
		"yield": amount,
		"energy": credits,
		"purity": harvest_result.get("purity", 0.0),
		"recorded_probability": harvest_result.get("recorded_probability", 0.0),
		"terminal_id": harvest_result.get("terminal_id", ""),
		"register_id": harvest_result.get("register_id", -1),
		"biome_name": harvest_result.get("biome_name", "")
	}

	plot_harvested.emit(position, yield_data)
	plot_changed.emit(position, "harvested", {"yield": yield_data})
	visualization_changed.emit()

	return yield_data


func measure_plot(position: Vector2i) -> String:
	"""Measure terminal at position (terminal-first)."""
	if not _plot_pool:
		return ""

	var terminal = _plot_pool.get_terminal_at_grid_pos(position)
	if not terminal:
		return ""

	var biome = null
	if _biome_routing and terminal.bound_biome_name != "":
		biome = _biome_routing.biomes.get(terminal.bound_biome_name, null)

	var result = ProbeActions.action_measure(terminal, biome)
	if not result.get("success", false):
		return ""

	var outcome = result.get("outcome", "")
	plot_changed.emit(position, "measured", {"outcome": outcome})
	visualization_changed.emit()

	return outcome
