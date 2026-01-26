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
var _plot_manager = null  # GridPlotManager
var _biome_routing = null  # BiomeRoutingManager
var _economy = null  # FarmEconomy
var _entanglement = null  # EntanglementManager
var _verbose = null


func set_dependencies(plot_manager, biome_routing, economy, entanglement, _topology_analyzer = null) -> void:
	"""Inject component dependencies."""
	_plot_manager = plot_manager
	_biome_routing = biome_routing
	_economy = economy
	_entanglement = entanglement
	# Note: topology_analyzer param kept for API compatibility but no longer used


func set_verbose(verbose_ref) -> void:
	"""Set verbose logger reference."""
	_verbose = verbose_ref


func harvest_wheat(position: Vector2i) -> Dictionary:
	"""Harvest wheat at position (quantum-only: must be planted)"""
	var plot = _plot_manager.get_plot(position)
	if plot == null or not plot.is_planted:
		return {"success": false}

	var yield_data = plot.harvest()
	if yield_data["success"]:
		_biome_routing.clear_register_tracking(position)

		# Remove projection from biome
		var plot_biome = _biome_routing.get_biome_for_plot(position)
		if plot_biome and plot_biome.has_method("remove_projection"):
			plot_biome.remove_projection(position)
			if _verbose:
				_verbose.debug("farm", "🗑️", "Removed projection from biome at %s" % position)

		plot_harvested.emit(position, yield_data)

		# Emit generic signals for visualization update
		plot_changed.emit(position, "harvested", {"yield": yield_data})
		visualization_changed.emit()

	return yield_data


func measure_plot(position: Vector2i) -> String:
	"""Measure quantum state (observer effect). Entanglement means measuring one collapses entire network!

	Uses biome's quantum_computer for register-based measurement.
	"""
	var plot = _plot_manager.get_plot(position)
	if plot == null or not plot.is_planted:
		return ""

	# Get biome for this plot
	var biome = _biome_routing.get_biome_for_plot(position)
	if not biome:
		if _verbose:
			_verbose.warn("farm", "⚠️", "No biome for plot at %s" % position)
		return ""

	var result = ""

	if not biome.quantum_computer:
		if _verbose:
			_verbose.warn("farm", "⚠️", "No quantum system for plot at %s" % position)
		return plot.north_emoji  # Default fallback

	if plot.north_emoji == "" or plot.south_emoji == "":
		return plot.north_emoji  # Default fallback

	# Model C: Use measure_axis directly
	var outcome_emoji = biome.quantum_computer.measure_axis(plot.north_emoji, plot.south_emoji)
	result = outcome_emoji if outcome_emoji != "" else plot.north_emoji
	var basis_outcome = "north" if outcome_emoji == plot.north_emoji else "south"
	if _verbose:
		_verbose.debug("farm", "📊", "Measure operation (Model C): %s collapsed to %s" % [position, result])

	# UPDATE PLOT STATE
	plot.has_been_measured = true
	plot.measured_outcome = basis_outcome  # "north" or "south"

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
		var current_pos = _plot_manager.find_plot_by_id(current_id)
		if current_pos == Vector2i(-1, -1):
			continue

		var current_plot = _plot_manager.get_plot(current_pos)
		if not current_plot or not current_plot.is_planted:
			continue

		# Mark as measured (quantum_computer already handled the measurement)
		if _verbose:
			_verbose.debug("quantum", "↪", "Entanglement network collapsed %s (via quantum_computer)" % current_id)
		measured_ids[current_id] = true

		# Add its entangled partners to the queue
		for next_id in current_plot.entangled_plots.keys():
			if not measured_ids.has(next_id):
				to_check.append(next_id)

	# MEASUREMENT COLLAPSES TO CLASSICAL STATE: (Model B)
	# Break ALL entanglements for measured plots (quantum → classical transition)
	for measured_id in measured_ids.keys():
		var measured_pos = _plot_manager.find_plot_by_id(measured_id)
		if measured_pos == Vector2i(-1, -1):
			continue

		var measured_plot = _plot_manager.get_plot(measured_pos)
		if not measured_plot:
			continue

		# Clear all entanglements for this plot (FarmGrid metadata only)
		if not measured_plot.entangled_plots.is_empty():
			var num_broken = measured_plot.entangled_plots.size()
			measured_plot.entangled_plots.clear()
			if _verbose:
				_verbose.debug("quantum", "🔓", "Measurement broke %d entanglements for %s (classical state)" % [num_broken, measured_id])

	# Emit signals for visualization update
	plot_changed.emit(position, "measured", {"outcome": result})
	visualization_changed.emit()

	return result
