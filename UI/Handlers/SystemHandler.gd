class_name SystemHandler
extends RefCounted

## SystemHandler - Static handler for system/debug operations
##
## Follows ProbeActions pattern:
## - Static methods only
## - Explicit parameters (no implicit state)
## - Dictionary returns with {success: bool, ...data, error?: String}


## ============================================================================
## SYSTEM CONTROL OPERATIONS
## ============================================================================

static func system_reset(farm, positions: Array[Vector2i], current_selection: Vector2i = Vector2i.ZERO) -> Dictionary:
	"""Reset quantum bath to initial/thermal state.

	Reinitializes the density matrix for the biome.
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	# Get target position
	var target_pos = positions[0] if not positions.is_empty() else current_selection
	var biome = farm.grid.get_biome_for_plot(target_pos)

	if not biome or not biome.quantum_computer:
		return {
			"success": false,
			"error": "no_quantum_computer",
			"message": "No quantum computer at selection"
		}

	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else "biome"

	# Reset to initial basis state |0...0>
	biome.quantum_computer.initialize_basis(0)

	return {
		"success": true,
		"biome_name": biome_name,
		"reset_to": "ground_state"
	}


static func system_snapshot(farm, positions: Array[Vector2i], current_selection: Vector2i = Vector2i.ZERO) -> Dictionary:
	"""Save current quantum state snapshot.

	Captures the current density matrix state for analysis.
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	# Get target position
	var target_pos = positions[0] if not positions.is_empty() else current_selection
	var biome = farm.grid.get_biome_for_plot(target_pos)

	if not biome or not biome.quantum_computer:
		return {
			"success": false,
			"error": "no_quantum_computer",
			"message": "No quantum computer at selection"
		}

	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else "biome"

	# Get density matrix info
	var rho = biome.quantum_computer.get_density_matrix()
	if not rho:
		return {
			"success": false,
			"error": "no_density_matrix",
			"message": "No density matrix to snapshot"
		}

	# Calculate trace for validation
	var trace_val = 1.0
	if rho.has_method("trace"):
		var trace_result = rho.trace()
		trace_val = trace_result.re if trace_result else 1.0

	return {
		"success": true,
		"biome_name": biome_name,
		"dimension": rho.n if rho else -1,
		"trace": trace_val,
		"timestamp": Time.get_unix_time_from_system()
	}


static func system_debug(farm, positions: Array[Vector2i], current_selection: Vector2i = Vector2i.ZERO) -> Dictionary:
	"""Get debug information for the quantum system.

	Returns detailed state information for debugging.
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	# Get target position
	var target_pos = positions[0] if not positions.is_empty() else current_selection
	var biome = farm.grid.get_biome_for_plot(target_pos)

	if not biome:
		return {
			"success": false,
			"error": "no_biome",
			"message": "No biome at selection"
		}

	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else "biome"
	var debug_info: Dictionary = {
		"biome_name": biome_name,
		"position": target_pos
	}

	# Quantum computer info
	if biome.quantum_computer:
		var qc = biome.quantum_computer
		debug_info.quantum_computer = {
			"exists": true,
			"num_qubits": qc.num_qubits if "num_qubits" in qc else -1
		}

		# Register map info
		if qc.register_map:
			debug_info.register_map = {
				"coordinates": qc.register_map.coordinates.keys() if qc.register_map.coordinates else []
			}

		# Density matrix info
		var rho = qc.get_density_matrix() if qc.has_method("get_density_matrix") else null
		if rho:
			debug_info.density_matrix = {
				"exists": true,
				"dimension": rho.n
			}

			# Calculate trace and purity
			if rho.has_method("trace"):
				var trace_result = rho.trace()
				debug_info.density_matrix.trace = trace_result.re if trace_result else -1.0

			if rho.has_method("purity"):
				debug_info.density_matrix.purity = rho.purity()
	else:
		debug_info.quantum_computer = {"exists": false}

	# Terminal info (v2 model)
	if farm.plot_pool:
		var terminal = farm.plot_pool.get_terminal_at_grid_pos(target_pos)
		if terminal:
			debug_info.terminal = {
				"exists": true,
				"id": terminal.terminal_id,
				"is_bound": terminal.is_bound,
				"is_measured": terminal.is_measured
			}

			if terminal.is_bound:
				debug_info.terminal.bound_register_id = terminal.bound_register_id
				debug_info.terminal.north_emoji = terminal.north_emoji
				debug_info.terminal.south_emoji = terminal.south_emoji

			if terminal.is_measured:
				debug_info.terminal.measured_outcome = terminal.measured_outcome
				debug_info.terminal.measured_probability = terminal.measured_probability
		else:
			debug_info.terminal = {"exists": false}

	return {
		"success": true,
		"debug_info": debug_info
	}


## ============================================================================
## STATE INSPECTION OPERATIONS
## ============================================================================

static func peek_state(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Non-destructive peek at quantum state probabilities.

	Shows measurement probabilities WITHOUT collapsing the state.
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

	var peek_results: Array = []

	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome:
			continue

		var emoji = ""
		var register_id = -1

		if farm.plot_pool:
			var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
			if terminal and terminal.is_bound:
				emoji = terminal.north_emoji
				register_id = terminal.bound_register_id

		if register_id < 0:
			var plot = farm.grid.get_plot(pos)
			if not plot or not plot.is_planted:
				continue
			emoji = plot.north_emoji if plot.north_emoji else ""
			if biome.viz_cache:
				register_id = biome.viz_cache.get_qubit(emoji)

		if register_id < 0:
			continue

		var north_prob = biome.get_register_probability(register_id)
		peek_results.append({
			"position": pos,
			"emoji": emoji,
			"north_probability": north_prob,
			"south_probability": 1.0 - north_prob
		})

	return {
		"success": peek_results.size() > 0,
		"peek_results": peek_results,
		"count": peek_results.size()
	}


## ============================================================================
## EVOLUTION CONTROL OPERATIONS
## ============================================================================

static func set_biomes_paused(farm, paused: bool) -> Dictionary:
	"""Pause or resume quantum evolution on all biomes."""
	if not farm or not farm.grid or not farm.grid.biomes:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	var affected_count = 0

	for biome_name in farm.grid.biomes:
		var biome = farm.grid.biomes[biome_name]
		if biome and biome.has_method("set_evolution_paused"):
			biome.set_evolution_paused(paused)
			affected_count += 1

	return {
		"success": affected_count > 0,
		"paused": paused,
		"affected_biomes": affected_count
	}


static func get_evolution_status(farm) -> Dictionary:
	"""Get evolution pause status for all biomes."""
	if not farm or not farm.grid or not farm.grid.biomes:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	var statuses: Dictionary = {}

	for biome_name in farm.grid.biomes:
		var biome = farm.grid.biomes[biome_name]
		if biome and biome.has_method("is_evolution_paused"):
			statuses[biome_name] = biome.is_evolution_paused()
		else:
			statuses[biome_name] = null

	return {
		"success": true,
		"biome_statuses": statuses
	}
