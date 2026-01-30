class_name BiomeGateOperations
extends RefCounted

## Gate Operations Component
##
## Extracted from BiomeBase to handle:
## - Gate application (1Q and 2Q gates)
## - Entanglement operations (Bell pairs, cluster states)
## - Batch measurement across entangled components

const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")

# Injected dependencies
var quantum_computer = null
var register_manager = null  # Legacy plot→register resolver (deprecated)
var bell_gate_tracker = null  # BiomeBellGateTracker
var time_tracker = null  # BiomeTimeTracker

# Verbose logging
var _verbose_log_callback: Callable


func set_dependencies(qc, reg_mgr, bell_tracker, time_track = null) -> void:
	"""Set all required dependencies"""
	quantum_computer = qc
	register_manager = reg_mgr
	bell_gate_tracker = bell_tracker
	time_tracker = time_track


func set_verbose_log_callback(callback: Callable) -> void:
	"""Set callback for verbose logging"""
	_verbose_log_callback = callback


func _verbose_log(level: String, category: String, emoji: String, message: String) -> void:
	"""Forward to verbose log callback if set"""
	if _verbose_log_callback.is_valid():
		_verbose_log_callback.call(level, category, emoji, message)


# ============================================================================
# Gate Operations (Tool 5 Backend)
# ============================================================================

func apply_gate_1q(position: Vector2i, gate_name: String) -> bool:
	"""Apply 1-qubit unitary gate to a plot's register.

	Model C: Validates plot is unmeasured, applies gate via apply_gate().

	Args:
		position: Plot position
		gate_name: Gate name (e.g., "X", "H", "Z")

	Returns:
		true if successful, false if failed
	"""
	if not register_manager:
		# Plot-based gates not supported without register_manager
		return false

	var reg = register_manager.get_register_for_plot(position)
	if not reg or not reg.is_planted:
		push_error("Plot %s not planted!" % position)
		return false

	# Validate: no gates on measured plots
	if reg.has_been_measured:
		push_error("Cannot apply gates to measured plots!")
		return false

	# Get gate matrix from library
	var gate_dict = QuantumGateLibrary.get_gate(gate_name)
	if not gate_dict or not gate_dict.has("matrix"):
		push_error("Gate not found: %s" % gate_name)
		return false

	var U = gate_dict["matrix"]

	# Model C: Apply gate directly using qubit index
	var success = quantum_computer.apply_gate(reg.register_id, U)

	if success and time_tracker:
		reg.record_gate_application(gate_name, time_tracker.turn_count)

	return success


func apply_gate_2q(position_a: Vector2i, position_b: Vector2i, gate_name: String) -> bool:
	"""Apply 2-qubit unitary gate to two plots' registers.

	Model C: Validates both plots are unmeasured, applies gate via apply_gate_2q().

	Args:
		position_a: Control plot position
		position_b: Target plot position
		gate_name: Gate name (e.g., "CNOT", "CZ", "SWAP")

	Returns:
		true if successful, false if failed
	"""
	if not register_manager:
		# Plot-based gates not supported without register_manager
		return false

	var reg_a = register_manager.get_register_for_plot(position_a)
	var reg_b = register_manager.get_register_for_plot(position_b)

	if not reg_a or not reg_a.is_planted or not reg_b or not reg_b.is_planted:
		push_error("One or both plots not planted!")
		return false

	# Validate: no gates on measured plots
	if reg_a.has_been_measured or reg_b.has_been_measured:
		push_error("Cannot apply gates to measured plots!")
		return false

	# Get gate matrix from library
	var gate_dict = QuantumGateLibrary.get_gate(gate_name)
	if not gate_dict or gate_dict["arity"] != 2:
		push_error("Invalid 2-qubit gate: %s" % gate_name)
		return false

	var U = gate_dict["matrix"]

	# Model C: Apply gate directly using qubit indices
	var success = quantum_computer.apply_gate_2q(reg_a.register_id, reg_b.register_id, U)

	if success and time_tracker:
		reg_a.record_gate_application(gate_name + "(ctrl)", time_tracker.turn_count)
		reg_b.record_gate_application(gate_name + "(tgt)", time_tracker.turn_count)

	return success


# ============================================================================
# Entanglement Operations (Tool 1 Backend)
# ============================================================================

func entangle_plots(position_a: Vector2i, position_b: Vector2i) -> bool:
	"""Entangle two plots using Bell circuit (Model B version)

	Creates Bell Phi+ = (|00> + |11>)/sqrt(2) between two registers.
	Automatically merges their components into one.

	Args:
		position_a: First plot
		position_b: Second plot

	Returns:
		true if successful, false if failed
	"""
	if not register_manager:
		# Plot-based gates not supported without register_manager
		return false

	var reg_a = register_manager.get_register_for_plot(position_a)
	var reg_b = register_manager.get_register_for_plot(position_b)

	if not reg_a or not reg_b or not reg_a.is_planted or not reg_b.is_planted:
		push_error("Both plots must be planted to entangle!")
		return false

	# Validate: no entangling measured plots
	if reg_a.has_been_measured or reg_b.has_been_measured:
		push_error("Cannot entangle measured plots!")
		return false

	# Call quantum_computer entanglement
	var success = quantum_computer.entangle_plots(reg_a.register_id, reg_b.register_id)

	if success:
		# Record entanglement
		reg_a.entangled_with.append(reg_b.register_id)
		reg_b.entangled_with.append(reg_a.register_id)

		# Mark bell gate if tracker available
		if bell_gate_tracker:
			bell_gate_tracker.mark_bell_gate([position_a, position_b])

		_verbose_log("info", "quantum", "🔗", "Entangled plots %s <-> %s" % [position_a, position_b])

	return success


func create_cluster_state(positions: Array[Vector2i]) -> bool:
	"""Create multi-qubit cluster state from selected plots (Model B)

	Entangles multiple plots into a chain topology (linear cluster).
	Uses sequential Bell pair entanglement: plot[0]<->plot[1]<->plot[2]<->...

	Args:
		positions: Array of plot positions to cluster

	Returns:
		true if cluster successfully created
	"""
	if not quantum_computer or positions.size() < 2:
		return false

	_verbose_log("debug", "quantum", "🌐", "Creating cluster state with %d plots" % positions.size())

	var success_count = 0
	for i in range(positions.size() - 1):
		var pos_a = positions[i]
		var pos_b = positions[i + 1]

		# Get register IDs
		var reg_a = register_manager.get_register_id_for_plot(pos_a)
		var reg_b = register_manager.get_register_id_for_plot(pos_b)

		if reg_a < 0 or reg_b < 0:
			push_warning("Invalid registers for cluster: %d, %d" % [reg_a, reg_b])
			continue

		# Create Bell pair entanglement
		if quantum_computer.entangle_plots(reg_a, reg_b):
			success_count += 1
			_verbose_log("debug", "quantum", "🔗", "Entangled %s <-> %s" % [pos_a, pos_b])

	# Store in bell_gates history for UI visualization
	if success_count > 0 and bell_gate_tracker:
		bell_gate_tracker.mark_bell_gate(positions)

	_verbose_log("info", "quantum", "✅", "Cluster created with %d entanglements" % success_count)
	return success_count > 0


func batch_entangle(positions: Array[Vector2i]) -> bool:
	"""Create Bell pairs between all adjacent plot pairs (Model B)

	Entangles all consecutive plot pairs in the selection.
	Creates multiple independent Bell pairs: (0,1), (1,2), (2,3), etc.

	Args:
		positions: Array of plot positions

	Returns:
		true if at least one entanglement succeeded
	"""
	if not quantum_computer or positions.size() < 2:
		return false

	_verbose_log("debug", "quantum", "🔗", "Batch entangling %d plots" % positions.size())

	var success_count = 0
	for i in range(positions.size() - 1):
		var pos_a = positions[i]
		var pos_b = positions[i + 1]

		var reg_a = register_manager.get_register_id_for_plot(pos_a)
		var reg_b = register_manager.get_register_id_for_plot(pos_b)

		if reg_a < 0 or reg_b < 0:
			continue

		if quantum_computer.entangle_plots(reg_a, reg_b):
			success_count += 1
			_verbose_log("debug", "quantum", "🔗", "Entangled %s <-> %s" % [pos_a, pos_b])

	if success_count > 0 and bell_gate_tracker:
		bell_gate_tracker.mark_bell_gate(positions)

	_verbose_log("info", "quantum", "✅", "Created %d Bell pairs" % success_count)
	return success_count > 0


func set_measurement_trigger(trigger_pos: Vector2i, target_positions: Array[Vector2i]) -> bool:
	"""Set up conditional measurement trigger.

	Model C: Uses entanglement_graph to verify qubits are connected.
	When trigger_pos is measured, its outcome affects measurements at target_positions.

	Args:
		trigger_pos: Plot whose measurement triggers condition
		target_positions: Plots affected by trigger measurement

	Returns:
		true if trigger successfully set up
	"""
	if not quantum_computer:
		return false

	var trigger_reg = register_manager.get_register_id_for_plot(trigger_pos)
	if trigger_reg < 0:
		push_warning("Invalid trigger register at %s" % trigger_pos)
		return false

	# Model C: Get entangled qubits from entanglement graph
	var entangled_ids = quantum_computer.get_entangled_component(trigger_reg)
	if entangled_ids.is_empty():
		push_warning("Trigger not in entanglement graph")
		return false

	var valid_targets = 0
	for target_pos in target_positions:
		var target_reg = register_manager.get_register_id_for_plot(target_pos)
		if target_reg < 0:
			continue

		# Check if target is in same entangled component
		if target_reg in entangled_ids:
			valid_targets += 1

	if valid_targets == 0:
		push_warning("No valid targets in trigger component")
		return false

	_verbose_log("info", "quantum", "✅", "Measurement trigger set: %s -> %d targets" % [trigger_pos, valid_targets])
	return true


func remove_entanglement(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	"""Remove entanglement between two plots (Model B - Phase 4 Infrastructure)

	Decouples two plots by clearing their entanglement metadata.
	Actual quantum state remains entangled (full disentanglement requires projection).

	Args:
		pos_a: First plot
		pos_b: Second plot

	Returns:
		true if decoupling successful
	"""
	if not quantum_computer:
		return false

	var reg_a = register_manager.get_register_id_for_plot(pos_a)
	var reg_b = register_manager.get_register_id_for_plot(pos_b)

	if reg_a < 0 or reg_b < 0:
		push_warning("Invalid registers for removal: %d, %d" % [reg_a, reg_b])
		return false

	# Clear entanglement graph edges
	if quantum_computer.entanglement_graph.has(reg_a):
		quantum_computer.entanglement_graph[reg_a].erase(reg_b)
	if quantum_computer.entanglement_graph.has(reg_b):
		quantum_computer.entanglement_graph[reg_b].erase(reg_a)

	_verbose_log("info", "quantum", "✅", "Removed entanglement between %s and %s" % [pos_a, pos_b])
	return true


# ============================================================================
# Batch Measurement
# ============================================================================

func batch_measure_plots(position: Vector2i, qubit_measured_callback: Callable = Callable()) -> Dictionary:
	"""Measure entire entangled component when one plot is measured (Phase 3 - Spooky Action at Distance)

	When you measure one qubit in an entangled component, all qubits in that component collapse.
	This implements batch measurement across the entire entangled network.

	Model C: Uses entanglement_graph to find connected qubits, measures each with measure_axis().

	Args:
		position: Position of plot to trigger measurement
		qubit_measured_callback: Optional callback(position, outcome) for each measurement

	Returns:
		Dictionary mapping register_ids to measurement outcomes
		Example: {reg_0: "north", reg_1: "south", reg_2: "north"}
	"""
	if not register_manager:
		return {}

	var reg = register_manager.get_register_for_plot(position)
	if not reg:
		return {}

	# Model C: Get entangled qubits from entanglement graph
	var entangled_ids = quantum_computer.get_entangled_component(reg.register_id)
	if entangled_ids.is_empty():
		entangled_ids = [reg.register_id]

	# Measure all qubits in the entangled component
	var outcomes: Dictionary = {}

	for reg_id in entangled_ids:
		# Get emoji pair from quantum_computer.register_map
		if quantum_computer and quantum_computer.register_map and quantum_computer.register_map.has(reg_id):
			var qubit = quantum_computer.register_map.get(reg_id)
			if qubit:
				var outcome_emoji = quantum_computer.measure_axis(qubit.north_emoji, qubit.south_emoji)
				var outcome = "north" if outcome_emoji == qubit.north_emoji else "south"
				outcomes[reg_id] = outcome

	_verbose_log("debug", "quantum", "🌀", "Batch measurement: %s" % outcomes)
	return outcomes
