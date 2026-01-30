class_name GateInjector
extends RefCounted

## GateInjector - Coordinates gate application with evolution buffer invalidation
##
## This module handles the handoff between UI gate operations and the quantum
## computer, ensuring that the C++ lookahead buffer is invalidated after gates
## are applied (otherwise the pre-computed evolution frames become stale).
##
## Flow:
##   UI keypress → GateActionHandler → GateInjector.inject_gate()
##        ↓
##   QuantumComputer.apply_gate()  +  BiomeEvolutionBatcher.signal_user_action()
##
## Batch Flow (for multi-select):
##   UI Shift+E → GateInjector.inject_gate_batch(ordered_gates)
##        ↓
##   Apply all gates in order → SINGLE signal_user_action() at end
##
## Why this exists:
##   The BiomeEvolutionBatcher pre-computes 5 lookahead frames in C++ for smooth
##   visualization. If a gate is applied directly to density_matrix, the buffer
##   contains stale states. This module ensures buffer invalidation happens
##   atomically with gate application.

const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")


## ============================================================================
## BATCH GATE INJECTION (Multi-select operations)
## ============================================================================

static func inject_gate_batch(gate_ops: Array, farm = null) -> Dictionary:
	"""Apply multiple gates in order, invalidate buffer ONCE at end.

	Args:
		gate_ops: Array of gate operations, each is a Dictionary:
			{
				biome: BiomeBase,
				qubit: int,
				gate_name: String (e.g., "H", "X", "Rx"),
				gate_matrix: ComplexMatrix (optional, if not using gate_name)
			}
		farm: Farm reference for batcher access

	Returns:
		Dictionary with:
			- success: bool (true if any gate succeeded)
			- applied_count: int
			- failed_count: int
			- results: Array of per-gate results
			- order: Array of qubit indices in application order
	"""
	if gate_ops.is_empty():
		return {"success": false, "error": "empty_batch", "applied_count": 0}

	var results: Array = []
	var applied_count = 0
	var failed_count = 0
	var order: Array = []
	var any_biome = null  # Track for invalidation

	# Apply gates in order WITHOUT invalidating buffer
	for op in gate_ops:
		var biome = op.get("biome")
		var qubit = op.get("qubit", -1)
		var gate_name = op.get("gate_name", "")
		var gate_matrix = op.get("gate_matrix")

		if not biome or not biome.quantum_computer:
			results.append({"success": false, "error": "no_quantum_computer", "qubit": qubit})
			failed_count += 1
			continue

		any_biome = biome

		# Get gate matrix from library if not provided
		if gate_matrix == null and gate_name != "":
			var gate_lib = QuantumGateLibrary.new()
			if gate_lib.GATES.has(gate_name):
				gate_matrix = gate_lib.GATES[gate_name]["matrix"]

		if gate_matrix == null:
			results.append({"success": false, "error": "no_gate_matrix", "qubit": qubit, "gate": gate_name})
			failed_count += 1
			continue

		# Apply gate directly (no invalidation yet)
		var success = biome.quantum_computer.apply_gate(qubit, gate_matrix)

		if success:
			applied_count += 1
			order.append(qubit)
			results.append({"success": true, "qubit": qubit, "gate": gate_name})
		else:
			failed_count += 1
			results.append({"success": false, "error": "apply_failed", "qubit": qubit, "gate": gate_name})

	# SINGLE invalidation after all gates applied
	if applied_count > 0 and any_biome:
		_invalidate_lookahead(any_biome, farm)

	return {
		"success": applied_count > 0,
		"applied_count": applied_count,
		"failed_count": failed_count,
		"results": results,
		"order": order,
		"batch_injected": true
	}


static func inject_named_gate_batch(biome, qubits: Array, gate_name: String, farm = null) -> Dictionary:
	"""Apply the same named gate to multiple qubits in order.

	Convenience wrapper for inject_gate_batch when applying same gate to multiple qubits.

	Args:
		biome: Biome containing the quantum computer
		qubits: Array of qubit indices in application order
		gate_name: Gate name (H, X, Y, Z, Rx, Ry, Rz, etc.)
		farm: Farm reference for batcher access

	Returns:
		Same as inject_gate_batch
	"""
	var gate_ops: Array = []
	for qubit in qubits:
		gate_ops.append({
			"biome": biome,
			"qubit": qubit,
			"gate_name": gate_name
		})

	return inject_gate_batch(gate_ops, farm)


static func inject_gate(biome, qubit: int, gate_matrix, farm = null) -> Dictionary:
	"""Apply a 1-qubit gate and invalidate lookahead buffer.

	Args:
		biome: Biome containing the quantum computer
		qubit: Target qubit index
		gate_matrix: 2x2 ComplexMatrix unitary
		farm: Farm reference for batcher access (optional, extracted from biome if null)

	Returns:
		Dictionary with success/error
	"""
	if not biome or not biome.quantum_computer:
		return {"success": false, "error": "no_quantum_computer"}

	if biome.quantum_computer.density_matrix == null:
		return {"success": false, "error": "no_density_matrix"}

	# Apply gate to density matrix
	var success = biome.quantum_computer.apply_gate(qubit, gate_matrix)

	if success:
		# Invalidate lookahead buffer
		_invalidate_lookahead(biome, farm)

	return {
		"success": success,
		"qubit": qubit,
		"gate_injected": true
	}


static func inject_gate_2q(biome, qubit_a: int, qubit_b: int, gate_matrix, farm = null) -> Dictionary:
	"""Apply a 2-qubit gate and invalidate lookahead buffer.

	Args:
		biome: Biome containing the quantum computer
		qubit_a: First qubit (control for CNOT)
		qubit_b: Second qubit (target for CNOT)
		gate_matrix: 4x4 ComplexMatrix unitary
		farm: Farm reference for batcher access (optional)

	Returns:
		Dictionary with success/error
	"""
	if not biome or not biome.quantum_computer:
		return {"success": false, "error": "no_quantum_computer"}

	if biome.quantum_computer.density_matrix == null:
		return {"success": false, "error": "no_density_matrix"}

	# Apply 2-qubit gate to density matrix
	var success = biome.quantum_computer.apply_gate_2q(qubit_a, qubit_b, gate_matrix)

	if success:
		# Invalidate lookahead buffer
		_invalidate_lookahead(biome, farm)

	return {
		"success": success,
		"qubit_a": qubit_a,
		"qubit_b": qubit_b,
		"gate_injected": true
	}


static func inject_named_gate(biome, qubit: int, gate_name: String, farm = null) -> Dictionary:
	"""Apply a named gate from the library and invalidate lookahead.

	Args:
		biome: Biome containing the quantum computer
		qubit: Target qubit index
		gate_name: Gate name (H, X, Y, Z, S, T, Rx, Ry, Rz, etc.)
		farm: Farm reference for batcher access

	Returns:
		Dictionary with success/error
	"""
	var gate_lib = QuantumGateLibrary.new()
	if not gate_lib.GATES.has(gate_name):
		return {"success": false, "error": "unknown_gate", "gate": gate_name}

	var gate_matrix = gate_lib.GATES[gate_name]["matrix"]
	if not gate_matrix:
		return {"success": false, "error": "no_matrix", "gate": gate_name}

	var result = inject_gate(biome, qubit, gate_matrix, farm)
	result["gate"] = gate_name
	return result


static func inject_named_gate_2q(biome, qubit_a: int, qubit_b: int, gate_name: String, farm = null) -> Dictionary:
	"""Apply a named 2-qubit gate from the library and invalidate lookahead.

	Args:
		biome: Biome containing the quantum computer
		qubit_a: First qubit
		qubit_b: Second qubit
		gate_name: Gate name (CNOT, CZ, SWAP, etc.)
		farm: Farm reference for batcher access

	Returns:
		Dictionary with success/error
	"""
	var gate_lib = QuantumGateLibrary.new()
	if not gate_lib.GATES.has(gate_name):
		return {"success": false, "error": "unknown_gate", "gate": gate_name}

	var gate_matrix = gate_lib.GATES[gate_name]["matrix"]
	if not gate_matrix:
		return {"success": false, "error": "no_matrix", "gate": gate_name}

	var result = inject_gate_2q(biome, qubit_a, qubit_b, gate_matrix, farm)
	result["gate"] = gate_name
	return result


static func _invalidate_lookahead(biome, farm = null) -> void:
	"""Notify the evolution batcher that lookahead buffer is stale.

	Called after any gate injection to force refill of pre-computed frames.
	"""
	var batcher = null

	# Try to get batcher from farm
	if farm and "biome_evolution_batcher" in farm and farm.biome_evolution_batcher:
		batcher = farm.biome_evolution_batcher

	# Fallback: try to get farm from scene tree
	if batcher == null:
		var tree = Engine.get_main_loop()
		if tree and tree is SceneTree:
			var root = tree.root
			var farm_node = root.get_node_or_null("Farm")
			if farm_node and "biome_evolution_batcher" in farm_node:
				batcher = farm_node.biome_evolution_batcher

	# Signal the batcher to invalidate lookahead
	if batcher and batcher.has_method("signal_user_action"):
		batcher.signal_user_action()
