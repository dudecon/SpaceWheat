class_name BiomeHandler
extends RefCounted

## BiomeHandler - Static handler for biome management operations
##
## Follows ProbeActions pattern:
## - Static methods only
## - Explicit parameters (no implicit state)
## - Dictionary returns with {success: bool, ...data, error?: String}

const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")


## ============================================================================
## BIOME ASSIGNMENT OPERATIONS
## ============================================================================

static func assign_plots_to_biome(farm, positions: Array[Vector2i], biome_name: String) -> Dictionary:
	"""Assign selected plots to a specific biome.

	Updates plot_biome_assignments in FarmGrid.
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

	# Validate biome exists
	if not farm.grid.biomes.has(biome_name):
		return {
			"success": false,
			"error": "biome_not_found",
			"message": "Biome '%s' not found" % biome_name
		}

	var assigned_count = 0
	var results: Array = []

	for pos in positions:
		# Check if plot exists
		if not farm.grid.is_valid_position(pos):
			continue

		# Get previous assignment
		var prev_biome = farm.grid.plot_biome_assignments.get(pos, "")

		# Assign to new biome
		farm.grid.plot_biome_assignments[pos] = biome_name

		# Update plot if it exists
		var plot = farm.grid.get_plot(pos)
		if plot:
			# Reset plot state for new biome
			if plot.is_planted and prev_biome != biome_name:
				plot.is_planted = false
				plot.north_emoji = ""
				plot.south_emoji = ""

		assigned_count += 1
		results.append({
			"position": pos,
			"previous_biome": prev_biome,
			"new_biome": biome_name
		})

	return {
		"success": assigned_count > 0,
		"biome_name": biome_name,
		"assigned_count": assigned_count,
		"results": results
	}


static func clear_biome_assignment(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Clear biome assignment from selected plots.

	Removes plots from biome registry (sets to default/unassigned).
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

	var cleared_count = 0
	var results: Array = []

	for pos in positions:
		# Get current assignment
		var current_biome = farm.grid.plot_biome_assignments.get(pos, "")

		if current_biome != "":
			# Remove from assignment dictionary
			farm.grid.plot_biome_assignments.erase(pos)

			# Reset plot state
			var plot = farm.grid.get_plot(pos)
			if plot:
				plot.is_planted = false
				plot.north_emoji = ""
				plot.south_emoji = ""

			cleared_count += 1
			results.append({
				"position": pos,
				"previous_biome": current_biome
			})

	return {
		"success": cleared_count > 0,
		"cleared_count": cleared_count,
		"results": results
	}


## ============================================================================
## PLOT INSPECTION OPERATIONS
## ============================================================================

static func inspect_plot(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Get detailed information about selected plots.

	Returns biome, quantum state, and economy info for each plot.
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

	var inspections: Array = []

	for pos in positions:
		var info: Dictionary = {
			"position": pos,
			"valid": false
		}

		# Get plot
		var plot = farm.grid.get_plot(pos)
		if not plot:
			inspections.append(info)
			continue

		info.valid = true
		info.is_planted = plot.is_planted
		info.north_emoji = plot.north_emoji if plot.north_emoji else ""
		info.south_emoji = plot.south_emoji if plot.south_emoji else ""

		# Get biome info
		var biome_name = farm.grid.plot_biome_assignments.get(pos, "unassigned")
		info.biome_name = biome_name

		var biome = farm.grid.get_biome_for_plot(pos)
		if biome:
			info.biome_type = biome.get_biome_type() if biome.has_method("get_biome_type") else biome_name

			# Get quantum state info if available
			if biome.quantum_computer:
				var qc = biome.quantum_computer
				info.qubit_count = qc.num_qubits if qc.has_method("num_qubits") else -1

				# Get probability for this plot's emoji
				if plot.is_planted and plot.north_emoji != "":
					if qc.register_map.has(plot.north_emoji):
						var reg_id = qc.register_map.get(plot.north_emoji, -1)
						if reg_id >= 0 and qc.has_method("get_register_probability"):
							info.north_probability = qc.get_register_probability(reg_id)

		# Get terminal info (v2 model)
		if farm.plot_pool:
			var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
			if terminal:
				info.has_terminal = true
				info.terminal_id = terminal.terminal_id
				info.terminal_bound = terminal.is_bound
				info.terminal_measured = terminal.is_measured
				if terminal.is_measured:
					info.measured_outcome = terminal.measured_outcome
					info.measured_probability = terminal.measured_probability
			else:
				info.has_terminal = false

		inspections.append(info)

	return {
		"success": true,
		"inspections": inspections,
		"count": inspections.size()
	}


## ============================================================================
## BIOME QUERY OPERATIONS
## ============================================================================

static func get_biome_list(farm) -> Dictionary:
	"""Get list of available biomes."""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	var biomes: Array = []

	for biome_name in farm.grid.biomes:
		var biome = farm.grid.biomes[biome_name]
		var info: Dictionary = {
			"name": biome_name,
			"type": biome.get_biome_type() if biome.has_method("get_biome_type") else biome_name
		}

		# Get producible emojis
		if biome.producible_emojis:
			info.producible_emojis = biome.producible_emojis

		# Get qubit count
		if biome.quantum_computer:
			info.qubit_count = biome.quantum_computer.num_qubits if biome.quantum_computer.has_method("num_qubits") else -1

		biomes.append(info)

	return {
		"success": true,
		"biomes": biomes,
		"count": biomes.size()
	}


static func get_plots_for_biome(farm, biome_name: String) -> Dictionary:
	"""Get all plots assigned to a specific biome."""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	var plots: Array[Vector2i] = []

	for pos in farm.grid.plot_biome_assignments:
		if farm.grid.plot_biome_assignments[pos] == biome_name:
			plots.append(pos)

	return {
		"success": true,
		"biome_name": biome_name,
		"positions": plots,
		"count": plots.size()
	}


## ============================================================================
## VOCABULARY INJECTION OPERATIONS
## ============================================================================

static func inject_vocabulary(farm, positions: Array[Vector2i], vocab_pair: Dictionary) -> Dictionary:
	"""Execute vocab injection with user-selected pair.

	Args:
		farm: Farm instance
		positions: Selected plot positions
		vocab_pair: {north: String, south: String} from submenu

	Returns:
		{success: bool, north_emoji: String, south_emoji: String, cost: int, error: String}
	"""
	if positions.is_empty():
		return {"success": false, "error": "no_selection"}

	var pos = positions[0]
	var biome = farm.grid.get_biome_for_plot(pos)

	if not biome:
		return {"success": false, "error": "no_biome"}
	if biome.quantum_computer and biome.quantum_computer.register_map.num_qubits >= EconomyConstants.MAX_BIOME_QUBITS:
		return {
			"success": false,
			"error": "qubit_cap_reached",
			"message": "Biome is at max capacity (%d qubits)" % EconomyConstants.MAX_BIOME_QUBITS
		}

	# Check if vocab pair is valid
	var north = vocab_pair.get("north", "")
	var south = vocab_pair.get("south", "")

	if north.is_empty() or south.is_empty():
		return {"success": false, "error": "invalid_pair"}

	# Calculate cost
	var cost = EconomyConstants.get_vocab_injection_cost(south)

	# Check affordability
	if not EconomyConstants.can_afford(farm.economy, cost):
		return {
			"success": false,
			"error": "insufficient_funds",
			"cost": cost,
			"current": farm.economy.get("energy", 0)
		}

	# Perform expansion
	var result = biome.expand_quantum_system(north, south)

	if result.get("success", false):
		# Deduct cost
		EconomyConstants.spend(farm.economy, cost, "vocab_injection")

		return {
			"success": true,
			"north_emoji": north,
			"south_emoji": south,
			"cost": cost,
			"biome": biome.name
		}

	return {
		"success": false,
		"error": result.get("error", "expansion_failed"),
		"details": result
	}


## ============================================================================
## BIOME EXPLORATION OPERATIONS
## ============================================================================

static func explore_biome(farm, _positions: Array[Vector2i]) -> Dictionary:
	"""Explore and unlock a new biome (4E action).

	Randomly selects an unexplored biome and unlocks it.
	The biome is loaded dynamically and added to the keyboard layout.

	Returns:
		{success: bool, biome_name: String, message: String}
	"""
	print("🗺️ BiomeHandler.explore_biome() called")

	if not farm:
		print("❌ Farm not available")
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	print("✅ Farm found, calling farm.explore_biome()")
	# Call Farm's explore_biome method
	var result = farm.explore_biome()
	print("🗺️ BiomeHandler result: %s" % str(result))
	return result


static func get_biome_info(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Get information about biome at position.

	Args:
		farm: Farm instance
		positions: Selected plot positions

	Returns:
		{
			success: bool,
			biome_name: String,
			emoji_count: int,
			qubit_count: int,
			emojis: Array[String]
		}
	"""
	if positions.is_empty():
		return {"success": false, "error": "no_selection"}

	var pos = positions[0]
	var biome = farm.grid.get_biome_for_plot(pos)

	if not biome:
		return {"success": false, "error": "no_biome"}

	var emojis: Array[String] = []
	var qubit_count = 0

	if biome.quantum_computer:
		var coordinates = biome.quantum_computer.register_map.coordinates
		emojis = coordinates.keys()
		qubit_count = biome.quantum_computer.register_map.num_qubits

	return {
		"success": true,
		"biome_name": biome.name,
		"emoji_count": emojis.size(),
		"qubit_count": qubit_count,
		"emojis": emojis
	}
