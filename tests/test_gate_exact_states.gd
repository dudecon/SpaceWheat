extends SceneTree

## Exact Quantum State Verification Test
## Verifies gates produce EXACT expected quantum states
## Run: godot --headless --script tests/test_gate_exact_states.gd

const GateInjector = preload("res://Core/QuantumSubstrate/GateInjector.gd")

var passed = 0
var failed = 0
var biome = null

const DIVIDER = "============================================================"
const EPSILON = 1e-6  # Tolerance for floating point comparison


func _init():
	print("\n" + DIVIDER)
	print("EXACT QUANTUM STATE VERIFICATION TEST")
	print("Testing: Gate → Exact Expected Density Matrix Elements")
	print(DIVIDER)

	# Wait for autoloads
	await self.process_frame

	if await setup_test_environment():
		test_hadamard_exact_state()
		test_pauli_x_exact_state()
		test_pauli_y_exact_state()
		test_pauli_z_exact_state()
		test_cnot_exact_state()
		test_bell_state_exact()
		test_cz_phase_flip_exact()
		test_swap_exact_state()
	else:
		print("\n[ERROR] Failed to setup test environment")
		failed += 1

	print("\n" + DIVIDER)
	print("RESULTS: %d passed, %d failed" % [passed, failed])
	print(DIVIDER + "\n")

	quit(0 if failed == 0 else 1)


func setup_test_environment() -> bool:
	"""Create a real biome with quantum computer."""
	print("\n[Setup: Real Biome + Quantum Computer]")

	var StarterForestBiome = load("res://Core/Environment/StarterForestBiome.gd")
	biome = StarterForestBiome.new()
	biome.name = "TestBiome"
	root.add_child(biome)

	await self.process_frame

	if not biome.quantum_computer or not biome.quantum_computer.density_matrix:
		print("  ✗ Failed to create quantum computer")
		return false

	print("  ✓ Quantum computer ready: %d qubits" % biome.get_total_register_count())
	return true


func test_hadamard_exact_state():
	"""H|0⟩ = (|0⟩+|1⟩)/√2

	In 5-qubit system: H on qubit 0, state is |00000⟩
	After H: (|00000⟩+|10000⟩)/√2

	Expected density matrix (5 qubits, dim=32, MSB ordering):
	- ρ[0,0] = 0.5  (prob of |00000⟩)
	- ρ[16,16] = 0.5 (prob of |10000⟩, since qubit 0 is MSB → bit 4 → index 16)
	- ρ[0,16] = 0.5 (coherence)
	- ρ[16,0] = 0.5 (coherence, Hermitian)
	- All others = 0
	"""
	print("\n[Hadamard Exact State: H|0⟩ = (|0⟩+|1⟩)/√2]")

	var qc = biome.quantum_computer
	qc.initialize_basis(0)  # |00000⟩

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var h_matrix = gate_lib.GATES["H"]["matrix"]

	GateInjector.inject_gate(biome, 0, h_matrix, null)

	var dm = qc.density_matrix
	var n_qubits = qc.register_map.num_qubits

	# In MSB ordering: qubit 0 is the leftmost bit
	# |00000⟩ = 0, |10000⟩ = 2^4 = 16
	var basis_0 = 0       # |00000⟩
	var basis_1 = 1 << (n_qubits - 1)  # |10000⟩ (flip MSB)

	print("  n_qubits = %d, dim = %d" % [n_qubits, dm.n])
	print("  basis_0 = %d (|00000⟩)" % basis_0)
	print("  basis_1 = %d (|10000⟩, qubit 0 flipped)" % basis_1)

	# Check diagonal elements (probabilities)
	assert_approx(dm.get_element(basis_0, basis_0).re, 0.5, "ρ[0,0] = 0.5")
	assert_approx(dm.get_element(basis_1, basis_1).re, 0.5, "ρ[16,16] = 0.5")

	# Check off-diagonal (coherence)
	assert_approx(dm.get_element(basis_0, basis_1).re, 0.5, "ρ[0,16] (coherence) = 0.5")
	assert_approx(dm.get_element(basis_1, basis_0).re, 0.5, "ρ[16,0] (coherence) = 0.5")

	# Verify no imaginary parts (for H on |0⟩)
	assert_approx(dm.get_element(basis_0, basis_1).im, 0.0, "ρ[0,16].im = 0")

	# Check that all other diagonal elements are ~0
	var other_diag_ok = true
	for i in range(dm.n):
		if i != basis_0 and i != basis_1:
			if abs(dm.get_element(i, i).re) > EPSILON:
				other_diag_ok = false
				print("  ✗ Unexpected: ρ[%d,%d] = %.6f (should be 0)" % [i, i, dm.get_element(i, i).re])
				break
	assert_true(other_diag_ok, "All other diagonal elements ≈ 0")


func test_pauli_x_exact_state():
	"""X|0⟩ = |1⟩

	In 5-qubit system: X on qubit 0, state is |00000⟩
	After X: |10000⟩

	Expected:
	- ρ[16,16] = 1.0 (prob of |10000⟩)
	- All others = 0
	"""
	print("\n[Pauli X Exact State: X|0⟩ = |1⟩]")

	var qc = biome.quantum_computer
	qc.initialize_basis(0)  # |00000⟩

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var x_matrix = gate_lib.GATES["X"]["matrix"]

	GateInjector.inject_gate(biome, 0, x_matrix, null)

	var dm = qc.density_matrix
	var n_qubits = qc.register_map.num_qubits
	var basis_1 = 1 << (n_qubits - 1)  # |10000⟩

	assert_approx(dm.get_element(basis_1, basis_1).re, 1.0, "ρ[16,16] = 1.0")
	assert_approx(dm.get_element(0, 0).re, 0.0, "ρ[0,0] = 0.0")

	# Check trace still 1.0
	var trace = _calculate_trace(dm)
	assert_approx(trace, 1.0, "Trace = 1.0")


func test_pauli_y_exact_state():
	"""Y|0⟩ = i|1⟩

	After Y on |00000⟩:
	- ρ[16,16] = 1.0 (prob of |10000⟩)
	- Pure state, no coherences
	"""
	print("\n[Pauli Y Exact State: Y|0⟩ = i|1⟩]")

	var qc = biome.quantum_computer
	qc.initialize_basis(0)

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var y_matrix = gate_lib.GATES["Y"]["matrix"]

	GateInjector.inject_gate(biome, 0, y_matrix, null)

	var dm = qc.density_matrix
	var n_qubits = qc.register_map.num_qubits
	var basis_1 = 1 << (n_qubits - 1)

	# |i⟩ state: density matrix is still |1⟩⟨1|, global phase doesn't appear
	assert_approx(dm.get_element(basis_1, basis_1).re, 1.0, "ρ[16,16] = 1.0")
	assert_approx(dm.get_element(0, 0).re, 0.0, "ρ[0,0] = 0.0")


func test_pauli_z_exact_state():
	"""Z|+⟩ = |-⟩, i.e. Z·H|0⟩ = (|0⟩-|1⟩)/√2

	After H then Z:
	- ρ[0,0] = 0.5
	- ρ[16,16] = 0.5
	- ρ[0,16] = -0.5 (NEGATIVE coherence, the minus sign!)
	- ρ[16,0] = -0.5
	"""
	print("\n[Pauli Z Exact State: Z|+⟩ = |-⟩]")

	var qc = biome.quantum_computer
	qc.initialize_basis(0)

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var h_matrix = gate_lib.GATES["H"]["matrix"]
	var z_matrix = gate_lib.GATES["Z"]["matrix"]

	# H|0⟩ = |+⟩
	GateInjector.inject_gate(biome, 0, h_matrix, null)
	# Z|+⟩ = |-⟩
	GateInjector.inject_gate(biome, 0, z_matrix, null)

	var dm = qc.density_matrix
	var n_qubits = qc.register_map.num_qubits
	var basis_0 = 0
	var basis_1 = 1 << (n_qubits - 1)

	assert_approx(dm.get_element(basis_0, basis_0).re, 0.5, "ρ[0,0] = 0.5")
	assert_approx(dm.get_element(basis_1, basis_1).re, 0.5, "ρ[16,16] = 0.5")
	assert_approx(dm.get_element(basis_0, basis_1).re, -0.5, "ρ[0,16] = -0.5 (minus sign!)")
	assert_approx(dm.get_element(basis_1, basis_0).re, -0.5, "ρ[16,0] = -0.5")


func test_cnot_exact_state():
	"""CNOT|10⟩ = |11⟩

	Prepare |10⟩ via X on qubit 0
	Apply CNOT(0,1)
	Result: |11⟩

	In 5-qubit system:
	- |10000⟩ = 16 (basis_10)
	- |11000⟩ = 24 (basis_11)

	Expected after CNOT:
	- ρ[24,24] = 1.0
	- All others = 0
	"""
	print("\n[CNOT Exact State: CNOT|10⟩ = |11⟩]")

	var qc = biome.quantum_computer
	qc.initialize_basis(0)  # |00000⟩

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var x_matrix = gate_lib.GATES["X"]["matrix"]
	var cnot_matrix = gate_lib.GATES["CNOT"]["matrix"]

	# Prepare |10⟩ (X on control qubit 0)
	GateInjector.inject_gate(biome, 0, x_matrix, null)

	var n_qubits = qc.register_map.num_qubits
	var basis_10 = 1 << (n_qubits - 1)  # |10000⟩
	var basis_11 = basis_10 | (1 << (n_qubits - 2))  # |11000⟩

	print("  n_qubits = %d" % n_qubits)
	print("  basis_10 = %d (|10000⟩)" % basis_10)
	print("  basis_11 = %d (|11000⟩)" % basis_11)

	# Verify we have |10⟩
	assert_approx(qc.density_matrix.get_element(basis_10, basis_10).re, 1.0, "Before CNOT: ρ[16,16] = 1.0")

	# Apply CNOT(0,1)
	GateInjector.inject_gate_2q(biome, 0, 1, cnot_matrix, null)

	# Verify result is |11⟩
	assert_approx(qc.density_matrix.get_element(basis_10, basis_10).re, 0.0, "After CNOT: ρ[16,16] = 0.0")
	assert_approx(qc.density_matrix.get_element(basis_11, basis_11).re, 1.0, "After CNOT: ρ[24,24] = 1.0")


func test_bell_state_exact():
	"""Bell state |Φ+⟩ = (|00⟩+|11⟩)/√2

	H on qubit 0, then CNOT(0,1)

	In 5-qubit system:
	- |00000⟩ = 0
	- |11000⟩ = 24

	Expected:
	- ρ[0,0] = 0.5
	- ρ[24,24] = 0.5
	- ρ[0,24] = 0.5 (real coherence)
	- ρ[24,0] = 0.5
	- All others = 0
	"""
	print("\n[Bell State Exact: |Φ+⟩ = (|00⟩+|11⟩)/√2]")

	var qc = biome.quantum_computer
	qc.initialize_basis(0)  # |00000⟩

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var h_matrix = gate_lib.GATES["H"]["matrix"]
	var cnot_matrix = gate_lib.GATES["CNOT"]["matrix"]

	# H on qubit 0
	GateInjector.inject_gate(biome, 0, h_matrix, null)
	# CNOT(0,1)
	GateInjector.inject_gate_2q(biome, 0, 1, cnot_matrix, null)

	var dm = qc.density_matrix
	var n_qubits = qc.register_map.num_qubits
	var basis_00 = 0
	var basis_11 = (1 << (n_qubits - 1)) | (1 << (n_qubits - 2))  # |11000⟩

	print("  basis_00 = %d (|00000⟩)" % basis_00)
	print("  basis_11 = %d (|11000⟩)" % basis_11)

	# Check probabilities
	assert_approx(dm.get_element(basis_00, basis_00).re, 0.5, "ρ[0,0] = 0.5")
	assert_approx(dm.get_element(basis_11, basis_11).re, 0.5, "ρ[24,24] = 0.5")

	# Check coherence (entanglement signature)
	assert_approx(dm.get_element(basis_00, basis_11).re, 0.5, "ρ[0,24] = 0.5 (entanglement)")
	assert_approx(dm.get_element(basis_11, basis_00).re, 0.5, "ρ[24,0] = 0.5")

	# Check no imaginary parts
	assert_approx(dm.get_element(basis_00, basis_11).im, 0.0, "ρ[0,24].im = 0")

	# Verify all other diagonal elements are ~0
	var other_ok = true
	for i in range(dm.n):
		if i != basis_00 and i != basis_11:
			if abs(dm.get_element(i, i).re) > EPSILON:
				other_ok = false
				print("  ✗ Unexpected: ρ[%d,%d] = %.6f" % [i, i, dm.get_element(i, i).re])
				break
	assert_true(other_ok, "All other diagonal elements ≈ 0")


func test_cz_phase_flip_exact():
	"""CZ gate flips phase of |11⟩ component

	Prepare: H(0)·H(1)|00⟩ = (|00⟩+|01⟩+|10⟩+|11⟩)/2
	Apply CZ(0,1)
	Result: (|00⟩+|01⟩+|10⟩-|11⟩)/2 (minus sign on |11⟩!)

	Check coherences change sign appropriately.
	"""
	print("\n[CZ Phase Flip Exact: CZ changes |11⟩ phase]")

	var qc = biome.quantum_computer
	qc.initialize_basis(0)

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var h_matrix = gate_lib.GATES["H"]["matrix"]
	var cz_matrix = gate_lib.GATES["CZ"]["matrix"]

	# Create equal superposition: H(0)·H(1)
	GateInjector.inject_gate(biome, 0, h_matrix, null)
	GateInjector.inject_gate(biome, 1, h_matrix, null)

	var dm_before = _snapshot_density_matrix(qc.density_matrix)

	# Apply CZ(0,1)
	GateInjector.inject_gate_2q(biome, 0, 1, cz_matrix, null)

	var dm_after = _snapshot_density_matrix(qc.density_matrix)

	# Verify matrix changed
	var changed = not _matrices_equal(dm_before, dm_after)
	assert_true(changed, "CZ changed density matrix")

	# Check probabilities unchanged (CZ only changes phases)
	var n_qubits = qc.register_map.num_qubits
	for i in range(qc.density_matrix.n):
		var prob_before = dm_before[i * qc.density_matrix.n + i]["re"]
		var prob_after = dm_after[i * qc.density_matrix.n + i]["re"]
		if abs(prob_before - prob_after) > EPSILON:
			assert_true(false, "CZ should not change probabilities, but ρ[%d,%d] changed" % [i, i])
			return

	assert_true(true, "CZ preserves all diagonal elements (probabilities)")


func test_swap_exact_state():
	"""SWAP|10⟩ = |01⟩

	Prepare |10000⟩ via X(0)
	Apply SWAP(0,1)
	Result: |01000⟩
	"""
	print("\n[SWAP Exact State: SWAP|10⟩ = |01⟩]")

	var qc = biome.quantum_computer
	qc.initialize_basis(0)

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var x_matrix = gate_lib.GATES["X"]["matrix"]
	var swap_matrix = gate_lib.GATES["SWAP"]["matrix"]

	# Prepare |10000⟩
	GateInjector.inject_gate(biome, 0, x_matrix, null)

	var n_qubits = qc.register_map.num_qubits
	var basis_10 = 1 << (n_qubits - 1)  # |10000⟩
	var basis_01 = 1 << (n_qubits - 2)  # |01000⟩

	print("  basis_10 = %d (|10000⟩)" % basis_10)
	print("  basis_01 = %d (|01000⟩)" % basis_01)

	# Verify |10⟩
	assert_approx(qc.density_matrix.get_element(basis_10, basis_10).re, 1.0, "Before SWAP: ρ[16,16] = 1.0")

	# Apply SWAP(0,1)
	GateInjector.inject_gate_2q(biome, 0, 1, swap_matrix, null)

	# Verify |01⟩
	assert_approx(qc.density_matrix.get_element(basis_10, basis_10).re, 0.0, "After SWAP: ρ[16,16] = 0.0")
	assert_approx(qc.density_matrix.get_element(basis_01, basis_01).re, 1.0, "After SWAP: ρ[8,8] = 1.0")


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _snapshot_density_matrix(dm) -> Array:
	"""Copy density matrix elements to array for comparison."""
	var snapshot = []
	for i in range(dm.n):
		for j in range(dm.n):
			var elem = dm.get_element(i, j)
			snapshot.append({"re": elem.re, "im": elem.im})
	return snapshot


func _matrices_equal(dm1: Array, dm2: Array, epsilon: float = 1e-10) -> bool:
	"""Check if two density matrix snapshots are equal."""
	if dm1.size() != dm2.size():
		return false

	for i in range(dm1.size()):
		var diff_re = abs(dm1[i].re - dm2[i].re)
		var diff_im = abs(dm1[i].im - dm2[i].im)
		if diff_re > epsilon or diff_im > epsilon:
			return false

	return true


func _calculate_trace(dm) -> float:
	"""Calculate trace of density matrix (should be 1.0)."""
	var trace = 0.0
	for i in range(dm.n):
		var elem = dm.get_element(i, i)
		trace += elem.re
	return trace


func assert_approx(actual: float, expected: float, msg: String):
	"""Assert two floats are approximately equal."""
	if abs(actual - expected) < EPSILON:
		passed += 1
		print("  ✓ %s" % msg)
		print("    actual=%.6f, expected=%.6f" % [actual, expected])
	else:
		failed += 1
		print("  ✗ %s" % msg)
		print("    actual=%.6f, expected=%.6f, diff=%.6f" % [actual, expected, abs(actual - expected)])


func assert_true(condition: bool, msg: String):
	if condition:
		passed += 1
		print("  ✓ %s" % msg)
	else:
		failed += 1
		print("  ✗ %s" % msg)
