class_name ProbeHandler
extends RefCounted

## ProbeHandler - Static handler for probe operations (v2 EXPLORE/MEASURE/POP)
##
## Wraps ProbeActions.gd with batch operation support and signal-compatible returns.
##
## Follows ProbeActions pattern:
## - Static methods only
## - Explicit parameters (no implicit state)
## - Dictionary returns with {success: bool, ...data, error?: String}

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")


## ============================================================================
## EXPLORE OPERATION - Batch bind terminals to registers
## ============================================================================

static func explore(farm, plot_pool, positions: Array[Vector2i]) -> Dictionary:
	"""Execute EXPLORE action: discover registers at selected positions.

	Binds unbound terminals to registers for each position that has a biome.
	Uses probability-weighted selection from the density matrix.

	Args:
		farm: Farm instance with grid
		plot_pool: PlotPool instance
		positions: Array of grid positions to explore

	Returns:
		Dictionary with:
		- success: bool
		- explored_count: int
		- last_emoji: String (for display)
		- results: Array of individual explore results
	"""
	if not farm or not plot_pool:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm or plot pool not ready"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var success_count = 0
	var last_emoji = ""
	var results: Array = []

	for pos in positions:
		if not farm.grid:
			continue

		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome:
			continue

		# Execute EXPLORE via ProbeActions
		var result = ProbeActions.action_explore(plot_pool, biome)

		if result.success:
			var terminal = result.terminal
			var emoji = result.emoji_pair.get("north", "?")
			last_emoji = emoji

			# Link terminal to grid position for bubble tap lookup
			terminal.grid_position = pos

			success_count += 1
			results.append({
				"position": pos,
				"terminal_id": terminal.terminal_id,
				"register_id": result.register_id,
				"emoji_pair": result.emoji_pair,
				"probability": result.probability
			})

	return {
		"success": success_count > 0,
		"explored_count": success_count,
		"last_emoji": last_emoji,
		"results": results
	}


## ============================================================================
## MEASURE OPERATION - Batch collapse terminals
## ============================================================================

static func measure(farm, plot_pool, positions: Array[Vector2i]) -> Dictionary:
	"""Execute MEASURE action: collapse terminals at selected positions.

	V2.2 Architecture: Processes ALL active terminals at selected positions.

	Args:
		farm: Farm instance with grid
		plot_pool: PlotPool instance
		positions: Array of grid positions to measure

	Returns:
		Dictionary with:
		- success: bool
		- measured_count: int
		- total_probability: float
		- outcomes: Array[String]
		- results: Array of individual measure results
	"""
	if not farm or not plot_pool:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm or plot pool not ready"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var measured_count = 0
	var total_probability = 0.0
	var outcomes: Array = []
	var results: Array = []

	for pos in positions:
		var terminal = plot_pool.get_terminal_at_grid_pos(pos)
		if not terminal or not terminal.can_measure():
			continue

		# Resolve biome from terminal's biome name
		var biome_name = terminal.bound_biome_name
		if biome_name == "":
			continue
		var biome = farm.grid.biomes.get(biome_name, null) if farm.grid else null
		if not biome:
			continue

		# Execute MEASURE via ProbeActions
		var result = ProbeActions.action_measure(terminal, biome)

		if result.success:
			measured_count += 1
			total_probability += result.recorded_probability
			outcomes.append(result.outcome)

			results.append({
				"position": pos,
				"terminal_id": terminal.terminal_id,
				"outcome": result.outcome,
				"probability": result.recorded_probability,
				"was_entangled": result.was_entangled,
				"was_drained": result.was_drained
			})

	return {
		"success": measured_count > 0,
		"measured_count": measured_count,
		"total_probability": total_probability,
		"outcomes": outcomes,
		"results": results
	}


## ============================================================================
## POP OPERATION - Batch harvest terminals
## ============================================================================

static func pop(farm, plot_pool, economy, positions: Array[Vector2i]) -> Dictionary:
	"""Execute POP action: harvest terminals at selected positions.

	V2.2 Architecture: Processes ALL measured terminals at selected positions.

	Args:
		farm: Farm instance with grid
		plot_pool: PlotPool instance
		economy: FarmEconomy instance
		positions: Array of grid positions to pop

	Returns:
		Dictionary with:
		- success: bool
		- popped_count: int
		- total_credits: float
		- resources: Array[String]
		- results: Array of individual pop results
	"""
	if not farm or not plot_pool:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm or plot pool not ready"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var popped_count = 0
	var total_credits = 0.0
	var resources: Array = []
	var results: Array = []

	for pos in positions:
		var terminal = plot_pool.get_terminal_at_grid_pos(pos)
		if not terminal or not terminal.can_pop():
			continue

		# Save grid position and terminal_id before unbind clears them
		var grid_pos = terminal.grid_position
		var terminal_id = terminal.terminal_id

		# Execute POP via ProbeActions
		var result = ProbeActions.action_pop(terminal, plot_pool, economy, farm)

		if result.success:
			popped_count += 1
			var credits = result.get("credits", 0)
			total_credits += credits
			resources.append(result.resource)

			results.append({
				"position": grid_pos,
				"terminal_id": terminal_id,
				"resource": result.resource,
				"amount": result.amount,
				"credits": credits,
				"recorded_probability": result.recorded_probability
			})

	return {
		"success": popped_count > 0,
		"popped_count": popped_count,
		"total_credits": total_credits,
		"resources": resources,
		"results": results
	}


## ============================================================================
## HARVEST GLOBAL OPERATION - End-of-turn collapse
## ============================================================================

static func harvest_global(farm, current_selection: Vector2i) -> Dictionary:
	"""Execute HARVEST: global collapse of biome, end level.

	Ensemble Model: True projective measurement that collapses the
	entire quantum system and converts all probability to credits.

	Args:
		farm: Farm instance
		current_selection: Current cursor position (determines biome)

	Returns:
		Dictionary with:
		- success: bool
		- total_credits: float
		- harvested: Array of per-register results
		- level_complete: bool
	"""
	if not farm or not farm.plot_pool:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not ready"
		}

	# Get biome for current selection
	var biome = farm.grid.get_biome_for_plot(current_selection) if farm.grid else null
	if not biome:
		return {
			"success": false,
			"error": "no_biome",
			"message": "No biome at current selection"
		}

	# Execute HARVEST via ProbeActions
	return ProbeActions.action_harvest_global(biome, farm.plot_pool, farm.economy)


## ============================================================================
## PREVIEW OPERATIONS - For UI display
## ============================================================================

static func get_explore_preview(plot_pool, biome) -> Dictionary:
	"""Get preview info for EXPLORE action."""
	return ProbeActions.get_explore_preview(plot_pool, biome)


static func get_measure_preview(terminal, biome) -> Dictionary:
	"""Get preview info for MEASURE action."""
	return ProbeActions.get_measure_preview(terminal, biome)


static func get_pop_preview(terminal) -> Dictionary:
	"""Get preview info for POP action."""
	return ProbeActions.get_pop_preview(terminal)
