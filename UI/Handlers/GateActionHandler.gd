class_name GateActionHandler
extends RefCounted

## GateActionHandler - Static handler for quantum gate operations
##
## Follows ProbeActions pattern:
## - Static methods only
## - Explicit parameters (no implicit state)
## - Dictionary returns with {success: bool, ...data, error?: String}
## - Single responsibility per method

const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")


## ============================================================================
## SINGLE-QUBIT GATE OPERATIONS
## ============================================================================

static func apply_pauli_x(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Apply Pauli-X gate (bit flip) to selected positions.

	Flips the qubit state: |0> -> |1>, |1> -> |0>
	"""
	return _apply_gate_batch(farm, positions, "X", "Pauli-X")


static func apply_pauli_y(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Apply Pauli-Y gate to selected positions.

	Combines X and Z rotations: |0> -> i|1>, |1> -> -i|0>
	"""
	return _apply_gate_batch(farm, positions, "Y", "Pauli-Y")


static func apply_pauli_z(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Apply Pauli-Z gate (phase flip) to selected positions.

	Applies phase flip: |0> -> |0>, |1> -> -|1>
	"""
	return _apply_gate_batch(farm, positions, "Z", "Pauli-Z")


static func apply_hadamard(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Apply Hadamard gate (superposition) to selected positions.

	Creates equal superposition from basis states:
	|0> -> (|0> + |1>)/sqrt(2), |1> -> (|0> - |1>)/sqrt(2)
	"""
	return _apply_gate_batch(farm, positions, "H", "Hadamard")


static func apply_s_gate(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Apply S gate (pi/2 phase) to selected positions.

	S = [[1, 0], [0, i]] (square root of Z gate)
	"""
	return _apply_gate_batch(farm, positions, "S", "S-gate")


static func apply_t_gate(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Apply T gate (pi/4 phase) to selected positions.

	T = [[1, 0], [0, e^(i*pi/4)]] (enables universal computation)
	"""
	return _apply_gate_batch(farm, positions, "T", "T-gate")


static func apply_sdg_gate(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Apply S-dagger gate (-pi/2 phase) to selected positions.

	S-dagger = [[1, 0], [0, -i]] (inverse of S gate)
	"""
	return _apply_gate_batch(farm, positions, "Sdg", "S-dagger")


static func apply_tdg_gate(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Apply T-dagger gate (-pi/4 phase) to selected positions.

	T-dagger = [[1, 0], [0, e^(-i*pi/4)]] (inverse of T gate)
	"""
	return _apply_gate_batch(farm, positions, "Tdg", "T-dagger")


static func apply_rx_gate(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Apply Rx rotation gate to selected positions.

	Rx(theta) rotation around X-axis. Default theta = pi/4.
	"""
	return _apply_gate_batch(farm, positions, "Rx", "Rx-gate")


static func apply_ry_gate(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Apply Ry rotation gate to selected positions.

	Ry(theta) rotation around Y-axis. Default theta = pi/4.
	"""
	return _apply_gate_batch(farm, positions, "Ry", "Ry-gate")


static func apply_rz_gate(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Apply Rz rotation gate to selected positions.

	Rz(theta) rotation around Z-axis. Default theta = pi/4.
	"""
	return _apply_gate_batch(farm, positions, "Rz", "Rz-gate")


## ============================================================================
## TWO-QUBIT GATE OPERATIONS
## ============================================================================

static func apply_cnot(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Apply CNOT gate to position pairs.

	Processes sequential pairs: (0,1), (2,3), etc.
	Control qubit at first position, target at second.
	"""
	return _apply_two_qubit_gate_batch(farm, positions, "CNOT", "CNOT")


static func apply_cz(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Apply CZ gate to position pairs.

	Controlled-Z gate between sequential position pairs.
	"""
	return _apply_two_qubit_gate_batch(farm, positions, "CZ", "CZ")


static func apply_swap(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Apply SWAP gate to position pairs.

	Swaps qubit states between sequential position pairs.
	"""
	return _apply_two_qubit_gate_batch(farm, positions, "SWAP", "SWAP")


static func create_bell_pair(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Create Bell pair (H + CNOT) - maximally entangled state.

	Requires exactly 2 positions. Creates |Phi+> = (|00> + |11>) / sqrt(2)
	"""
	if positions.size() < 2:
		return {
			"success": false,
			"error": "need_two_positions",
			"message": "Select 2 plots to create Bell pair"
		}

	var pos_a = positions[0]
	var pos_b = positions[1]

	# Step 1: Apply Hadamard to first qubit
	var h_result = _apply_single_qubit_gate(farm, pos_a, "H")
	if not h_result.success:
		return {
			"success": false,
			"error": "hadamard_failed",
			"message": "Failed to apply Hadamard"
		}

	# Step 2: Apply CNOT (control=a, target=b)
	var cnot_result = _apply_two_qubit_gate(farm, pos_a, pos_b, "CNOT")
	if not cnot_result.success:
		return {
			"success": false,
			"error": "cnot_failed",
			"message": "Failed to apply CNOT"
		}

	return {
		"success": true,
		"positions": [pos_a, pos_b],
		"state": "Bell pair |Phi+> = (|00>+|11>)/sqrt(2)"
	}


## ============================================================================
## ENTANGLEMENT OPERATIONS
## ============================================================================

static func cluster(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Build entanglement cluster between terminals at selected positions.

	Creates linear chain: plot[0] <-> plot[1] <-> plot[2] <-> ...
	"""
	if not farm or not farm.grid or not farm.plot_pool:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.size() < 2:
		return {
			"success": false,
			"error": "need_two_positions",
			"message": "Need at least 2 plots for cluster"
		}

	# Get biome from first plot
	var biome = farm.grid.get_biome_for_plot(positions[0])
	if not biome or not biome.quantum_computer:
		return {
			"success": false,
			"error": "no_quantum_computer",
			"message": "Could not access biome quantum computer"
		}

	# Collect terminals at these positions
	var terminals: Array = []
	for pos in positions:
		var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
		if terminal and terminal.is_bound and not terminal.is_measured:
			terminals.append(terminal)

	if terminals.size() < 2:
		return {
			"success": false,
			"error": "not_enough_terminals",
			"message": "Need at least 2 active terminals. EXPLORE first."
		}

	# Create entanglements between adjacent terminals
	var success_count = 0
	var entanglements: Array = []

	for i in range(terminals.size() - 1):
		var reg_a = terminals[i].bound_register_id
		var reg_b = terminals[i + 1].bound_register_id

		if biome.quantum_computer.entangle_plots(reg_a, reg_b):
			success_count += 1
			entanglements.append([reg_a, reg_b])

	return {
		"success": success_count > 0,
		"entanglements": entanglements,
		"terminal_count": terminals.size(),
		"entanglement_count": success_count
	}


static func disentangle(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Break entanglement between qubits by measuring and resetting.

	Performs measurement to collapse entangled state.
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

	var success_count = 0
	var results: Array = []

	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome:
			continue

		var reg = biome.get_register_for_plot(pos)
		if not reg:
			continue

		# Measure to collapse entanglement
		var measure_result = biome.quantum_computer.measure_axis(reg.north_emoji, reg.south_emoji)
		if measure_result != "":
			success_count += 1
			results.append({"position": pos, "outcome": measure_result})

	return {
		"success": success_count > 0,
		"disentangled_count": success_count,
		"results": results
	}


static func inspect_entanglement(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Show entanglement information for selected qubits.

	Returns which qubits are entangled with the selected ones.
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

	var info: Array = []

	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue

		var reg = biome.get_register_for_plot(pos)
		if not reg:
			continue

		var qc = biome.quantum_computer
		var entangled = qc.get_entangled_component(reg.register_id)

		var partners: Array = []
		if entangled.size() > 1:
			for r_id in entangled:
				if r_id != reg.register_id:
					partners.append(r_id)

		info.append({
			"position": pos,
			"register_id": reg.register_id,
			"entangled_with": partners,
			"is_entangled": partners.size() > 0
		})

	return {
		"success": true,
		"entanglement_info": info
	}


## ============================================================================
## HELPER METHODS
## ============================================================================

static func _apply_gate_batch(farm, positions: Array[Vector2i], gate_name: String, display_name: String) -> Dictionary:
	"""Apply a single-qubit gate to all positions in batch."""
	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var success_count = 0
	var results: Array = []

	for pos in positions:
		var result = _apply_single_qubit_gate(farm, pos, gate_name)
		if result.success:
			success_count += 1
		results.append(result)

	return {
		"success": success_count > 0,
		"gate": gate_name,
		"display_name": display_name,
		"applied_count": success_count,
		"total_count": positions.size(),
		"results": results
	}


static func _apply_two_qubit_gate_batch(farm, positions: Array[Vector2i], gate_name: String, display_name: String) -> Dictionary:
	"""Apply a two-qubit gate to sequential position pairs."""
	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var success_count = 0
	var results: Array = []

	for i in range(0, positions.size() - 1, 2):
		var pos_a = positions[i]
		var pos_b = positions[i + 1]
		var result = _apply_two_qubit_gate(farm, pos_a, pos_b, gate_name)
		if result.success:
			success_count += 1
		results.append(result)

	return {
		"success": success_count > 0,
		"gate": gate_name,
		"display_name": display_name,
		"pair_count": success_count,
		"results": results
	}


static func _apply_single_qubit_gate(farm, position: Vector2i, gate_name: String) -> Dictionary:
	"""Apply a single-qubit gate at a position.

	Supports both v2 terminal-based and v1 plot-based models.
	"""
	if not farm:
		return {
			"success": false,
			"error": "no_farm",
			"message": "Farm not loaded"
		}

	var biome = null
	var register_id: int = -1

	# V2 MODEL: Try terminal-based approach first
	if farm.plot_pool:
		var terminal = farm.plot_pool.get_terminal_at_grid_pos(position)
		if terminal and terminal.is_bound:
			# Resolve biome from terminal's biome name
			var biome_name = terminal.bound_biome_name
			if biome_name != "" and farm.grid:
				biome = farm.grid.biomes.get(biome_name, null)
			register_id = terminal.bound_register_id

	# V1 MODEL: Fall back to plot-based approach (Model C: use register_map)
	if register_id < 0 and farm.grid:
		var plot = farm.grid.get_plot(position)
		if plot and plot.is_planted:
			biome = farm.grid.get_biome_for_plot(position)
			# Model C: Look up qubit via register_map using plot's emoji
			if biome and biome.quantum_computer and plot.north_emoji:
				var emoji = plot.north_emoji
				if biome.quantum_computer.register_map.has(emoji):
					register_id = biome.quantum_computer.register_map.qubit(emoji)

	# Validate biome and register
	if not biome or not biome.quantum_computer or register_id < 0:
		return {
			"success": false,
			"error": "no_quantum_state",
			"message": "No valid quantum state at position",
			"position": position
		}

	# Get gate matrix from library
	var gate_lib = QuantumGateLibrary.new()
	if not gate_lib.GATES.has(gate_name):
		return {
			"success": false,
			"error": "unknown_gate",
			"message": "Unknown gate: %s" % gate_name
		}

	var gate_matrix = gate_lib.GATES[gate_name]["matrix"]
	if not gate_matrix:
		return {
			"success": false,
			"error": "no_matrix",
			"message": "No matrix for gate: %s" % gate_name
		}

	# Check density matrix exists
	if biome.quantum_computer.density_matrix == null:
		return {
			"success": false,
			"error": "no_density_matrix",
			"message": "Density matrix not initialized"
		}

	var success = biome.quantum_computer.apply_gate(register_id, gate_matrix)

	return {
		"success": success,
		"gate": gate_name,
		"register_id": register_id,
		"position": position
	}


static func _apply_two_qubit_gate(farm, position_a: Vector2i, position_b: Vector2i, gate_name: String) -> Dictionary:
	"""Apply a two-qubit gate between two positions.

	Supports both v2 terminal-based and v1 plot-based models.
	Both positions must be in the same biome.
	"""
	if not farm:
		return {
			"success": false,
			"error": "no_farm",
			"message": "Farm not loaded"
		}

	var biome_a = null
	var biome_b = null
	var reg_a: int = -1
	var reg_b: int = -1

	# V2 MODEL: Try terminal-based approach first
	if farm.plot_pool:
		var terminal_a = farm.plot_pool.get_terminal_at_grid_pos(position_a)
		var terminal_b = farm.plot_pool.get_terminal_at_grid_pos(position_b)

		if terminal_a and terminal_a.is_bound and not terminal_a.is_measured:
			# Resolve biome from terminal's biome name
			var biome_name_a = terminal_a.bound_biome_name
			if biome_name_a != "" and farm.grid:
				biome_a = farm.grid.biomes.get(biome_name_a, null)
			reg_a = terminal_a.bound_register_id

		if terminal_b and terminal_b.is_bound and not terminal_b.is_measured:
			# Resolve biome from terminal's biome name
			var biome_name_b = terminal_b.bound_biome_name
			if biome_name_b != "" and farm.grid:
				biome_b = farm.grid.biomes.get(biome_name_b, null)
			reg_b = terminal_b.bound_register_id

	# V1 MODEL: Fall back to plot-based approach (Model C: use register_map)
	if (reg_a < 0 or reg_b < 0) and farm.grid:
		var plot_a = farm.grid.get_plot(position_a)
		var plot_b = farm.grid.get_plot(position_b)

		if plot_a and plot_a.is_planted and reg_a < 0:
			biome_a = farm.grid.get_biome_for_plot(position_a)
			# Model C: Look up qubit via register_map
			if biome_a and biome_a.quantum_computer and plot_a.north_emoji:
				var emoji_a = plot_a.north_emoji
				if biome_a.quantum_computer.register_map.has(emoji_a):
					reg_a = biome_a.quantum_computer.register_map.qubit(emoji_a)

		if plot_b and plot_b.is_planted and reg_b < 0:
			biome_b = farm.grid.get_biome_for_plot(position_b)
			# Model C: Look up qubit via register_map
			if biome_b and biome_b.quantum_computer and plot_b.north_emoji:
				var emoji_b = plot_b.north_emoji
				if biome_b.quantum_computer.register_map.has(emoji_b):
					reg_b = biome_b.quantum_computer.register_map.qubit(emoji_b)

	# Both positions must have valid registers in the SAME biome
	if biome_a != biome_b or not biome_a or not biome_a.quantum_computer:
		return {
			"success": false,
			"error": "different_biomes",
			"message": "Both plots must be in same biome"
		}

	if reg_a < 0 or reg_b < 0:
		return {
			"success": false,
			"error": "missing_registers",
			"message": "Missing valid quantum states"
		}

	# Get gate matrix from library
	var gate_lib = QuantumGateLibrary.new()
	if not gate_lib.GATES.has(gate_name):
		return {
			"success": false,
			"error": "unknown_gate",
			"message": "Unknown gate: %s" % gate_name
		}

	var gate_matrix = gate_lib.GATES[gate_name]["matrix"]
	if not gate_matrix:
		return {
			"success": false,
			"error": "no_matrix",
			"message": "No matrix for gate: %s" % gate_name
		}

	# Check density matrix exists
	if biome_a.quantum_computer.density_matrix == null:
		return {
			"success": false,
			"error": "no_density_matrix",
			"message": "Density matrix not initialized"
		}

	var success = biome_a.quantum_computer.apply_gate_2q(reg_a, reg_b, gate_matrix)

	return {
		"success": success,
		"gate": gate_name,
		"register_a": reg_a,
		"register_b": reg_b,
		"position_a": position_a,
		"position_b": position_b
	}
