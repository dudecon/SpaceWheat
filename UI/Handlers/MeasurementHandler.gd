class_name MeasurementHandler
extends RefCounted

## MeasurementHandler - Static handler for measurement-related operations
##
## Follows ProbeActions pattern:
## - Static methods only
## - Explicit parameters (no implicit state)
## - Dictionary returns with {success: bool, ...data, error?: String}
##
## Note: Core EXPLORE/MEASURE/POP operations are in ProbeActions.gd
## This handler focuses on supplementary measurement operations.


## ============================================================================
## MEASUREMENT TRIGGER OPERATIONS
## ============================================================================

static func measure_trigger(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Build measure trigger for controlled collapse.

	Creates conditional measurement infrastructure.
	First plot in selection is trigger, remaining are targets.
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.size() < 2:
		return {
			"success": false,
			"error": "need_trigger_and_target",
			"message": "Need trigger plot and at least one target"
		}

	var trigger_pos = positions[0]
	var target_positions = positions.slice(1)

	var biome = farm.grid.get_biome_for_plot(trigger_pos)
	if not biome:
		return {
			"success": false,
			"error": "no_biome",
			"message": "Could not access biome"
		}

	# Get trigger plot info
	var trigger_plot = farm.grid.get_plot(trigger_pos)
	if not trigger_plot or not trigger_plot.is_planted:
		return {
			"success": false,
			"error": "invalid_trigger",
			"message": "Trigger plot not planted"
		}

	var trigger_emoji = trigger_plot.north_emoji

	# Set up measurement trigger
	var success = false
	if biome.has_method("set_measurement_trigger"):
		success = biome.set_measurement_trigger(trigger_emoji, target_positions)

	if not success:
		return {
			"success": false,
			"error": "trigger_setup_failed",
			"message": "Failed to set measurement trigger"
		}

	return {
		"success": true,
		"trigger_position": trigger_pos,
		"trigger_emoji": trigger_emoji,
		"target_count": target_positions.size()
	}


## ============================================================================
## BATCH MEASUREMENT OPERATIONS
## ============================================================================

static func batch_measure(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Batch measure selected plots.

	Collapses quantum state at each position.
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var measured_count = 0
	var harvest_count = 0
	var total_value = 0.0
	var results: Array = []

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			continue

		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue

		var north_emoji = plot.north_emoji
		var south_emoji = plot.south_emoji

		# Perform measurement
		var outcome = biome.quantum_computer.measure_axis(north_emoji, south_emoji)
		if outcome == "":
			continue

		measured_count += 1

		# Record outcome probability for value calculation
		var probability = 0.5
		if biome.viz_cache:
			var reg_id = biome.viz_cache.get_qubit(north_emoji)
			if reg_id >= 0:
				probability = biome.get_register_probability(reg_id)

		results.append({
			"position": pos,
			"outcome": outcome,
			"probability": probability
		})

		total_value += probability

	return {
		"success": measured_count > 0,
		"measured_count": measured_count,
		"total_value": total_value,
		"results": results
	}


static func batch_harvest(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Batch harvest measured terminals.

	V1 legacy operation for plot-based harvesting.
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var harvest_count = 0
	var total_credits = 0
	var results: Array = []

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			continue

		# Get value from plot
		var value = 1.0
		if plot.has_method("get_harvest_value"):
			value = plot.get_harvest_value()

		# Add to economy if available
		if farm.economy:
			var emoji = plot.north_emoji if plot.north_emoji else "?"
			farm.economy.add_resource(emoji, int(value), "harvest")

		harvest_count += 1
		total_credits += int(value)

		results.append({
			"position": pos,
			"value": value
		})

	return {
		"success": harvest_count > 0,
		"harvest_count": harvest_count,
		"total_credits": total_credits,
		"results": results
	}


static func batch_measure_and_harvest(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Combined measure and harvest operation.

	Legacy operation for v1 architecture.
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	# First measure
	var measure_result = batch_measure(farm, positions)
	if not measure_result.success:
		return measure_result

	# Then harvest
	var harvest_result = batch_harvest(farm, positions)

	return {
		"success": harvest_result.success,
		"measured_count": measure_result.measured_count,
		"harvest_count": harvest_result.harvest_count,
		"total_credits": harvest_result.total_credits,
		"measure_results": measure_result.results,
		"harvest_results": harvest_result.results
	}


## ============================================================================
## REMOVE GATES OPERATION
## ============================================================================

static func remove_gates(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Remove gate infrastructure from selected plots.

	Clears any persistent gate configurations.
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var removed_count = 0

	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome:
			continue

		# Clear gate infrastructure if supported
		if biome.has_method("clear_gate_at_position"):
			if biome.clear_gate_at_position(pos):
				removed_count += 1
		elif biome.has_method("remove_gate_infrastructure"):
			if biome.remove_gate_infrastructure(pos):
				removed_count += 1

	return {
		"success": removed_count > 0,
		"removed_count": removed_count,
		"total_positions": positions.size()
	}
