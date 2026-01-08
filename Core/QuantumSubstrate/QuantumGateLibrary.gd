class_name QuantumGateLibrary
extends Resource

## Centralized quantum gate definitions for research-grade tool backend
##
## This is the single source of truth for all gate matrices and properties.
## Prevents Tool 2 and Tool 5 from diverging on gate semantics.

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")

const SQRT2 = 1.4142135623730951

## Gate registry: maps gate_name → {arity, matrix, description}
static var GATES: Dictionary = {}

func _init():
	_init_gates()

static func _init_gates() -> void:
	"""Initialize all gate matrices."""
	if GATES.size() > 0:
		return  # Already initialized

	# ========== 1-QUBIT GATES ==========

	# Pauli-X (NOT gate): [[0, 1], [1, 0]]
	GATES["X"] = {
		"arity": 1,
		"matrix": _pauli_x(),
		"description": "Pauli-X (NOT gate)",
		"requires_unmeasured": true
	}

	# Pauli-Z: [[1, 0], [0, -1]]
	GATES["Z"] = {
		"arity": 1,
		"matrix": _pauli_z(),
		"description": "Pauli-Z",
		"requires_unmeasured": true
	}

	# Hadamard: (1/√2) [[1, 1], [1, -1]]
	GATES["H"] = {
		"arity": 1,
		"matrix": _hadamard(),
		"description": "Hadamard gate",
		"requires_unmeasured": true
	}

	# Pauli-Y (not commonly used, but complete): [[0, -i], [i, 0]]
	GATES["Y"] = {
		"arity": 1,
		"matrix": _pauli_y(),
		"description": "Pauli-Y",
		"requires_unmeasured": true
	}

	# S (phase) gate: [[1, 0], [0, i]]
	GATES["S"] = {
		"arity": 1,
		"matrix": _s_gate(),
		"description": "Phase gate",
		"requires_unmeasured": true
	}

	# T gate: [[1, 0], [0, e^(iπ/4)]]
	GATES["T"] = {
		"arity": 1,
		"matrix": _t_gate(),
		"description": "T gate",
		"requires_unmeasured": true
	}

	# ========== 2-QUBIT GATES ==========

	# CNOT (CX): control-qubit X gate [[1,0,0,0], [0,1,0,0], [0,0,0,1], [0,0,1,0]]
	GATES["CNOT"] = {
		"arity": 2,
		"matrix": _cnot(),
		"description": "Controlled-NOT (CNOT)",
		"requires_same_biome": true,
		"requires_distinct_indices": true,
		"requires_unmeasured": true
	}

	# CZ: controlled phase [[1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,-1]]
	GATES["CZ"] = {
		"arity": 2,
		"matrix": _cz(),
		"description": "Controlled-Z (CZ)",
		"requires_same_biome": true,
		"requires_distinct_indices": true,
		"requires_unmeasured": true
	}

	# SWAP: exchange two qubits [[1,0,0,0], [0,0,1,0], [0,1,0,0], [0,0,0,1]]
	GATES["SWAP"] = {
		"arity": 2,
		"matrix": _swap(),
		"description": "SWAP gate",
		"requires_same_biome": true,
		"requires_distinct_indices": true,
		"requires_unmeasured": true
	}

static func get_gate(gate_name: String) -> Dictionary:
	"""Get gate definition by name. Returns empty dict if not found."""
	_init_gates()

	if gate_name in GATES:
		return GATES[gate_name].duplicate(true)

	push_error("Gate not found: %s" % gate_name)
	return {
		"arity": 0,
		"matrix": null,
		"description": "INVALID"
	}

static func list_gates() -> Array:
	"""Get list of all available gate names."""
	_init_gates()
	return GATES.keys()

static func list_1q_gates() -> Array:
	"""Get all 1-qubit gates."""
	_init_gates()
	var result = []
	for name in GATES.keys():
		if GATES[name]["arity"] == 1:
			result.append(name)
	return result

static func list_2q_gates() -> Array:
	"""Get all 2-qubit gates."""
	_init_gates()
	var result = []
	for name in GATES.keys():
		if GATES[name]["arity"] == 2:
			result.append(name)
	return result

# ============================================================================
# MATRIX DEFINITIONS
# ============================================================================

static func _pauli_x() -> ComplexMatrix:
	"""Pauli-X: [[0, 1], [1, 0]]"""
	var m = ComplexMatrix.new(2)
	m.set_element(0, 1, Complex.one())
	m.set_element(1, 0, Complex.one())
	return m

static func _pauli_y() -> ComplexMatrix:
	"""Pauli-Y: [[0, -i], [i, 0]]"""
	var m = ComplexMatrix.new(2)
	m.set_element(0, 1, Complex.new(0, -1))
	m.set_element(1, 0, Complex.new(0, 1))
	return m

static func _pauli_z() -> ComplexMatrix:
	"""Pauli-Z: [[1, 0], [0, -1]]"""
	var m = ComplexMatrix.new(2)
	m.set_element(0, 0, Complex.one())
	m.set_element(1, 1, Complex.new(-1, 0))
	return m

static func _hadamard() -> ComplexMatrix:
	"""Hadamard: (1/√2) [[1, 1], [1, -1]]"""
	var m = ComplexMatrix.new(2)
	var inv_sqrt2 = Complex.new(1.0 / SQRT2, 0.0)
	m.set_element(0, 0, inv_sqrt2)
	m.set_element(0, 1, inv_sqrt2)
	m.set_element(1, 0, inv_sqrt2)
	m.set_element(1, 1, inv_sqrt2.mul(Complex.new(-1, 0)))
	return m

static func _s_gate() -> ComplexMatrix:
	"""S gate (phase): [[1, 0], [0, i]]"""
	var m = ComplexMatrix.new(2)
	m.set_element(0, 0, Complex.one())
	m.set_element(1, 1, Complex.new(0, 1))
	return m

static func _t_gate() -> ComplexMatrix:
	"""T gate: [[1, 0], [0, e^(iπ/4)]]"""
	var m = ComplexMatrix.new(2)
	m.set_element(0, 0, Complex.one())
	# e^(iπ/4) = cos(π/4) + i*sin(π/4) = 1/√2 + i/√2
	var phase = Complex.new(1.0 / SQRT2, 1.0 / SQRT2)
	m.set_element(1, 1, phase)
	return m

static func _cnot() -> ComplexMatrix:
	"""
	CNOT (CX): [[1,0,0,0], [0,1,0,0], [0,0,0,1], [0,0,1,0]]

	Control qubit (first) doesn't change.
	Target qubit (second) is flipped if control is |1⟩.
	Basis order: |00⟩, |01⟩, |10⟩, |11⟩
	"""
	var m = ComplexMatrix.new(4)
	# Diagonal (|00⟩, |01⟩ → unchanged)
	m.set_element(0, 0, Complex.one())
	m.set_element(1, 1, Complex.one())
	# Off-diagonal (|10⟩ ↔ |11⟩ when control is 1)
	m.set_element(2, 3, Complex.one())
	m.set_element(3, 2, Complex.one())
	return m

static func _cz() -> ComplexMatrix:
	"""
	Controlled-Z: [[1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,-1]]

	Applies Z to target only if control is |1⟩.
	Diagonal matrix: identity except |11⟩ → -|11⟩
	"""
	var m = ComplexMatrix.new(4)
	m.set_element(0, 0, Complex.one())
	m.set_element(1, 1, Complex.one())
	m.set_element(2, 2, Complex.one())
	m.set_element(3, 3, Complex.new(-1, 0))
	return m

static func _swap() -> ComplexMatrix:
	"""
	SWAP: [[1,0,0,0], [0,0,1,0], [0,1,0,0], [0,0,0,1]]

	Exchanges the two qubits.
	"""
	var m = ComplexMatrix.new(4)
	m.set_element(0, 0, Complex.one())
	m.set_element(1, 2, Complex.one())
	m.set_element(2, 1, Complex.one())
	m.set_element(3, 3, Complex.one())
	return m
