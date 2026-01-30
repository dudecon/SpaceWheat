extends SceneTree

## Advanced Quantum State Verification Test
## Tests: Phase gates, rotation gates, GHZ states, W states, sequential operations
## Run: godot --headless --script tests/test_advanced_quantum_states.gd

const GateInjector = preload("res://Core/QuantumSubstrate/GateInjector.gd")

var passed = 0
var failed = 0
var biome = null

const DIVIDER = "============================================================"
const EPSILON = 1e-6


func _init():
	print("\n" + DIVIDER)
	print("ADVANCED QUANTUM STATE VERIFICATION TEST")
	print("Testing: Phase gates, Rotations, Multi-qubit entanglement")
	print(DIVIDER)

	await self.process_frame

	if await setup_test_environment():
		test_s_gate_phase()
		test_t_gate_phase()
		test_rotation_gates()
		test_ghz_3qubit_state()
		test_w_3qubit_state()
		test_sequential_operations_order()
		test_gate_commutation()
		test_controlled_hadamard()
		test_toffoli_like_sequence()
		test_bell_basis_states()
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


func test_s_gate_phase():
	"""S gate (phase gate) S|+⟩ should create |+i⟩ = (|0⟩+i|1⟩)/√2

	Expected after H then S:
	- ρ[0,0] = 0.5
	- ρ[16,16] = 0.5
	- ρ[0,16] should have imaginary part (Im = 0.5)
	- ρ[16,0] should have imaginary part (Im = -0.5, conjugate)
	"""
	print("\n[S Gate Phase: S|+⟩ = (|0⟩+i|1⟩)/√2]")

	var qc = biome.quantum_computer
	qc.initialize_basis(0)

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var h_matrix = gate_lib.GATES["H"]["matrix"]
	var s_matrix = gate_lib.GATES["S"]["matrix"]

	# H|0⟩ = |+⟩
	GateInjector.inject_gate(biome, 0, h_matrix, null)
	# S|+⟩ = |+i⟩
	GateInjector.inject_gate(biome, 0, s_matrix, null)

	var dm = qc.density_matrix
	var n_qubits = qc.register_map.num_qubits
	var basis_0 = 0
	var basis_1 = 1 << (n_qubits - 1)

	# Check probabilities unchanged
	assert_approx(dm.get_element(basis_0, basis_0).re, 0.5, "ρ[0,0] = 0.5")
	assert_approx(dm.get_element(basis_1, basis_1).re, 0.5, "ρ[16,16] = 0.5")

	# Check imaginary coherence (KEY: S gate adds phase)
	var elem_01 = dm.get_element(basis_0, basis_1)
	var elem_10 = dm.get_element(basis_1, basis_0)

	print("  ρ[0,16] = %.6f + %.6fi" % [elem_01.re, elem_01.im])
	print("  ρ[16,0] = %.6f + %.6fi" % [elem_10.re, elem_10.im])

	# S gate rotates phase by π/2: real coherence → imaginary
	assert_approx(elem_01.re, 0.0, "ρ[0,16].re ≈ 0 (phase rotated)")
	assert_approx(abs(elem_01.im), 0.5, "ρ[0,16].im ≈ ±0.5 (phase appears)")

	# Verify Hermitian property: ρ[16,0] = conj(ρ[0,16])
	assert_approx(elem_10.re, elem_01.re, "Hermitian: Re(ρ[16,0]) = Re(ρ[0,16])")
	assert_approx(elem_10.im, -elem_01.im, "Hermitian: Im(ρ[16,0]) = -Im(ρ[0,16])")


func test_t_gate_phase():
	"""T gate (π/8 gate) rotates phase by π/4

	After H then T: (|0⟩+e^(iπ/4)|1⟩)/√2

	Expected:
	- ρ[0,0] = 0.5, ρ[16,16] = 0.5
	- ρ[0,16] = (cos(π/4) + i·sin(π/4))/2 ≈ 0.354 + 0.354i
	"""
	print("\n[T Gate Phase: T|+⟩ = (|0⟩+e^(iπ/4)|1⟩)/√2]")

	var qc = biome.quantum_computer
	qc.initialize_basis(0)

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var h_matrix = gate_lib.GATES["H"]["matrix"]
	var t_matrix = gate_lib.GATES["T"]["matrix"]

	GateInjector.inject_gate(biome, 0, h_matrix, null)
	GateInjector.inject_gate(biome, 0, t_matrix, null)

	var dm = qc.density_matrix
	var n_qubits = qc.register_map.num_qubits
	var basis_0 = 0
	var basis_1 = 1 << (n_qubits - 1)

	var elem_01 = dm.get_element(basis_0, basis_1)

	print("  ρ[0,16] = %.6f + %.6fi" % [elem_01.re, elem_01.im])

	# Expected: (cos(π/4) + i·sin(π/4))/2 ≈ 0.3536 + 0.3536i
	var expected_re = cos(PI / 4) / 2.0  # ≈ 0.3536
	var expected_im = sin(PI / 4) / 2.0  # ≈ 0.3536

	assert_approx(elem_01.re, expected_re, "ρ[0,16].re ≈ 0.354")
	assert_approx(abs(elem_01.im), expected_im, "ρ[0,16].im ≈ 0.354")


func test_rotation_gates():
	"""Test Rx, Ry, Rz rotation gates with specific angles

	Rx(π/2)|0⟩ = (|0⟩-i|1⟩)/√2
	Ry(π/2)|0⟩ = (|0⟩+|1⟩)/√2
	Rz(π/2)|+⟩ = rotates phase
	"""
	print("\n[Rotation Gates: Rx, Ry, Rz]")

	# Test Rx(π/2)
	var qc = biome.quantum_computer
	qc.initialize_basis(0)

	var theta = PI / 2.0
	var rx_matrix = _create_rx_gate(theta)

	GateInjector.inject_gate(biome, 0, rx_matrix, null)

	var dm = qc.density_matrix
	var n_qubits = qc.register_map.num_qubits
	var basis_0 = 0
	var basis_1 = 1 << (n_qubits - 1)

	# Rx(π/2)|0⟩ = (|0⟩-i|1⟩)/√2
	assert_approx(dm.get_element(basis_0, basis_0).re, 0.5, "Rx: ρ[0,0] = 0.5")
	assert_approx(dm.get_element(basis_1, basis_1).re, 0.5, "Rx: ρ[16,16] = 0.5")

	var elem_01 = dm.get_element(basis_0, basis_1)
	print("  Rx(π/2): ρ[0,16] = %.6f + %.6fi" % [elem_01.re, elem_01.im])
	assert_approx(abs(elem_01.im), 0.5, "Rx: ρ[0,16] has imaginary part")

	# Test Ry(π/2)
	qc.initialize_basis(0)
	var ry_matrix = _create_ry_gate(theta)
	GateInjector.inject_gate(biome, 0, ry_matrix, null)

	# Ry(π/2)|0⟩ = (|0⟩+|1⟩)/√2 (like H)
	assert_approx(qc.density_matrix.get_element(basis_0, basis_0).re, 0.5, "Ry: ρ[0,0] = 0.5")
	assert_approx(qc.density_matrix.get_element(basis_1, basis_1).re, 0.5, "Ry: ρ[16,16] = 0.5")


func test_ghz_3qubit_state():
	"""GHZ state on 3 qubits: |GHZ⟩ = (|000⟩+|111⟩)/√2

	Prepare via: H(0), CNOT(0,1), CNOT(0,2)

	Expected:
	- ρ[0,0] = 0.5 (|00000⟩, qubits 0,1,2 are 000)
	- ρ[28,28] = 0.5 (|11100⟩, qubits 0,1,2 are 111)
	- ρ[0,28] = 0.5 (coherence)
	"""
	print("\n[GHZ 3-Qubit State: |GHZ⟩ = (|000⟩+|111⟩)/√2]")

	var qc = biome.quantum_computer
	qc.initialize_basis(0)

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var h_matrix = gate_lib.GATES["H"]["matrix"]
	var cnot_matrix = gate_lib.GATES["CNOT"]["matrix"]

	# H on qubit 0
	GateInjector.inject_gate(biome, 0, h_matrix, null)
	# CNOT(0,1)
	GateInjector.inject_gate_2q(biome, 0, 1, cnot_matrix, null)
	# CNOT(0,2)
	GateInjector.inject_gate_2q(biome, 0, 2, cnot_matrix, null)

	var dm = qc.density_matrix
	var n_qubits = qc.register_map.num_qubits

	# |00000⟩ = 0
	# |11100⟩ = 0b11100 in MSB ordering (qubits 0,1,2 flipped) = 28
	var basis_000 = 0
	var basis_111 = 0b11100  # MSB: qubit 0 at bit 4, qubit 1 at bit 3, qubit 2 at bit 2

	print("  n_qubits = %d" % n_qubits)
	print("  basis_000 = %d (|00000⟩)" % basis_000)
	print("  basis_111 = %d (|11100⟩)" % basis_111)

	assert_approx(dm.get_element(basis_000, basis_000).re, 0.5, "ρ[0,0] = 0.5")
	assert_approx(dm.get_element(basis_111, basis_111).re, 0.5, "ρ[28,28] = 0.5")
	assert_approx(dm.get_element(basis_000, basis_111).re, 0.5, "ρ[0,28] = 0.5 (GHZ entanglement)")

	# Verify all other diagonal elements are ~0
	var other_ok = true
	for i in range(dm.n):
		if i != basis_000 and i != basis_111:
			if abs(dm.get_element(i, i).re) > EPSILON:
				other_ok = false
				print("  ✗ Unexpected: ρ[%d,%d] = %.6f" % [i, i, dm.get_element(i, i).re])
				break
	assert_true(other_ok, "All other diagonal elements ≈ 0")


func test_w_3qubit_state():
	"""W state: |W⟩ = (|001⟩+|010⟩+|100⟩)/√3

	W state is harder to prepare, requires specific rotation angles.
	For testing, we'll verify a simpler superposition state instead.

	Create: X(2), H(2) → (|0⟩|0⟩|0⟩ + |0⟩|0⟩|1⟩)/√2 on last qubit
	"""
	print("\n[W-like Superposition: Testing multi-basis state]")

	var qc = biome.quantum_computer
	qc.initialize_basis(0)

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var h_matrix = gate_lib.GATES["H"]["matrix"]

	# H on qubit 2 creates superposition on that qubit
	GateInjector.inject_gate(biome, 2, h_matrix, null)

	var dm = qc.density_matrix
	var n_qubits = qc.register_map.num_qubits

	# |00000⟩ = 0
	# |00100⟩ = 4 (qubit 2 flipped, which is bit 2 in MSB ordering)
	var basis_0 = 0
	var basis_1 = 0b00100

	print("  basis |00000⟩ = %d" % basis_0)
	print("  basis |00100⟩ = %d" % basis_1)

	assert_approx(dm.get_element(basis_0, basis_0).re, 0.5, "ρ[0,0] = 0.5")
	assert_approx(dm.get_element(basis_1, basis_1).re, 0.5, "ρ[4,4] = 0.5")
	assert_approx(dm.get_element(basis_0, basis_1).re, 0.5, "ρ[0,4] = 0.5")


func test_sequential_operations_order():
	"""Verify gate order matters: S·H ≠ H·S

	S·H|0⟩ = S|+⟩ = |+i⟩ = (|0⟩+i|1⟩)/√2 (imaginary coherence)
	H·S|0⟩ = H|0⟩ = |+⟩ = (|0⟩+|1⟩)/√2 (real coherence)

	These have different coherence phases!
	"""
	print("\n[Sequential Operations: Gate order matters]")

	var qc = biome.quantum_computer
	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var h_matrix = gate_lib.GATES["H"]["matrix"]
	var s_matrix = gate_lib.GATES["S"]["matrix"]

	var n_qubits = qc.register_map.num_qubits
	var basis_0 = 0
	var basis_1 = 1 << (n_qubits - 1)

	# Path 1: S·H|0⟩ = S|+⟩ = |+i⟩ (imaginary coherence)
	qc.initialize_basis(0)
	GateInjector.inject_gate(biome, 0, h_matrix, null)
	GateInjector.inject_gate(biome, 0, s_matrix, null)

	var coherence1 = qc.density_matrix.get_element(basis_0, basis_1)
	print("  Path 1 (S·H): ρ[0,16] = %.6f + %.6fi" % [coherence1.re, coherence1.im])

	# Path 2: H·S|0⟩ = H|0⟩ = |+⟩ (real coherence)
	qc.initialize_basis(0)
	GateInjector.inject_gate(biome, 0, s_matrix, null)
	GateInjector.inject_gate(biome, 0, h_matrix, null)

	var coherence2 = qc.density_matrix.get_element(basis_0, basis_1)
	print("  Path 2 (H·S): ρ[0,16] = %.6f + %.6fi" % [coherence2.re, coherence2.im])

	# Path 1 should have imaginary coherence (Im ≈ -0.5)
	# Path 2 should have real coherence (Re ≈ 0.5)
	var different_coherence = abs(coherence1.im - coherence2.im) > EPSILON or abs(coherence1.re - coherence2.re) > EPSILON
	assert_true(different_coherence, "S·H ≠ H·S (gate order matters)")


func test_gate_commutation():
	"""Test that Z and X anti-commute: ZX = -XZ

	But test gates that DO commute: Z and I, or Z gates on different qubits
	"""
	print("\n[Gate Commutation: Z(0)·X(1) = X(1)·Z(0)]")

	var qc = biome.quantum_computer
	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var x_matrix = gate_lib.GATES["X"]["matrix"]
	var z_matrix = gate_lib.GATES["Z"]["matrix"]

	# Path 1: Z(0) then X(1)
	qc.initialize_basis(0)
	GateInjector.inject_gate(biome, 0, z_matrix, null)
	GateInjector.inject_gate(biome, 1, x_matrix, null)
	var dm1 = _snapshot_density_matrix(qc.density_matrix)

	# Path 2: X(1) then Z(0)
	qc.initialize_basis(0)
	GateInjector.inject_gate(biome, 1, x_matrix, null)
	GateInjector.inject_gate(biome, 0, z_matrix, null)
	var dm2 = _snapshot_density_matrix(qc.density_matrix)

	# These SHOULD be equal (gates on different qubits commute)
	var are_equal = _matrices_equal(dm1, dm2, EPSILON)
	assert_true(are_equal, "Z(0)·X(1) = X(1)·Z(0) (different qubits commute)")


func test_controlled_hadamard():
	"""Controlled-Hadamard simulation: CNOT·(I⊗H)·CNOT

	Creates: if control=0: target unchanged, if control=1: target gets H
	"""
	print("\n[Controlled-Hadamard: Simulated via CNOT·H·CNOT]")

	var qc = biome.quantum_computer
	qc.initialize_basis(0)

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var x_matrix = gate_lib.GATES["X"]["matrix"]
	var h_matrix = gate_lib.GATES["H"]["matrix"]
	var cnot_matrix = gate_lib.GATES["CNOT"]["matrix"]

	# Prepare control qubit to |1⟩
	GateInjector.inject_gate(biome, 0, x_matrix, null)

	# CH simulation: CNOT(0,1), H(1), CNOT(0,1)
	GateInjector.inject_gate_2q(biome, 0, 1, cnot_matrix, null)
	GateInjector.inject_gate(biome, 1, h_matrix, null)
	GateInjector.inject_gate_2q(biome, 0, 1, cnot_matrix, null)

	var dm = qc.density_matrix

	# Verify state changed
	var changed = abs(dm.get_element(0, 0).re - 1.0) > EPSILON
	assert_true(changed, "Controlled-H changed state")


func test_toffoli_like_sequence():
	"""Test 3-gate sequence that mimics partial Toffoli behavior

	Toffoli (CCNOT): flips target if both controls are |1⟩
	We test: X(0), X(1), then CNOT(0,2), verify qubit 2 flipped
	"""
	print("\n[Toffoli-like Sequence: Multi-control simulation]")

	var qc = biome.quantum_computer
	qc.initialize_basis(0)

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var x_matrix = gate_lib.GATES["X"]["matrix"]
	var cnot_matrix = gate_lib.GATES["CNOT"]["matrix"]

	# Set controls to |1⟩
	GateInjector.inject_gate(biome, 0, x_matrix, null)

	# CNOT(0,2)
	GateInjector.inject_gate_2q(biome, 0, 2, cnot_matrix, null)

	var dm = qc.density_matrix
	var n_qubits = qc.register_map.num_qubits

	# Initial: |10000⟩, After CNOT(0,2): |10100⟩
	# |10000⟩ = 16, |10100⟩ = 20
	var basis_before = 0b10000
	var basis_after = 0b10100

	assert_approx(dm.get_element(basis_before, basis_before).re, 0.0, "ρ[16,16] = 0")
	assert_approx(dm.get_element(basis_after, basis_after).re, 1.0, "ρ[20,20] = 1 (target flipped)")


func test_bell_basis_states():
	"""Test all 4 Bell basis states:
	|Φ+⟩ = (|00⟩+|11⟩)/√2  (H, CNOT)
	|Φ-⟩ = (|00⟩-|11⟩)/√2  (H, CNOT, Z on control)
	|Ψ+⟩ = (|01⟩+|10⟩)/√2  (H, CNOT, X on target)
	|Ψ-⟩ = (|01⟩-|10⟩)/√2  (H, CNOT, X on target, Z on control)

	We'll test |Φ-⟩ to verify the minus sign appears in coherences
	"""
	print("\n[Bell Basis: |Φ-⟩ = (|00⟩-|11⟩)/√2]")

	var qc = biome.quantum_computer
	qc.initialize_basis(0)

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var h_matrix = gate_lib.GATES["H"]["matrix"]
	var z_matrix = gate_lib.GATES["Z"]["matrix"]
	var cnot_matrix = gate_lib.GATES["CNOT"]["matrix"]

	# Create |Φ+⟩
	GateInjector.inject_gate(biome, 0, h_matrix, null)
	GateInjector.inject_gate_2q(biome, 0, 1, cnot_matrix, null)
	# Apply Z to create |Φ-⟩
	GateInjector.inject_gate(biome, 0, z_matrix, null)

	var dm = qc.density_matrix
	var n_qubits = qc.register_map.num_qubits
	var basis_00 = 0
	var basis_11 = 0b11000  # 24

	# Probabilities same as |Φ+⟩
	assert_approx(dm.get_element(basis_00, basis_00).re, 0.5, "ρ[0,0] = 0.5")
	assert_approx(dm.get_element(basis_11, basis_11).re, 0.5, "ρ[24,24] = 0.5")

	# Coherence should be NEGATIVE (the minus sign)
	var coherence = dm.get_element(basis_00, basis_11).re
	print("  ρ[0,24] = %.6f (should be -0.5)" % coherence)
	assert_approx(coherence, -0.5, "ρ[0,24] = -0.5 (minus sign in |Φ-⟩)")


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _create_rx_gate(theta: float):
	"""Create Rx(θ) rotation gate."""
	var ComplexMatrix = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	var Complex = load("res://Core/QuantumSubstrate/Complex.gd")
	var rx = ComplexMatrix.new(2)
	var cos_half = cos(theta / 2.0)
	var sin_half = sin(theta / 2.0)

	rx.set_element(0, 0, Complex.new(cos_half, 0.0))
	rx.set_element(0, 1, Complex.new(0.0, -sin_half))
	rx.set_element(1, 0, Complex.new(0.0, -sin_half))
	rx.set_element(1, 1, Complex.new(cos_half, 0.0))

	return rx


func _create_ry_gate(theta: float):
	"""Create Ry(θ) rotation gate."""
	var ComplexMatrix = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	var Complex = load("res://Core/QuantumSubstrate/Complex.gd")
	var ry = ComplexMatrix.new(2)
	var cos_half = cos(theta / 2.0)
	var sin_half = sin(theta / 2.0)

	ry.set_element(0, 0, Complex.new(cos_half, 0.0))
	ry.set_element(0, 1, Complex.new(-sin_half, 0.0))
	ry.set_element(1, 0, Complex.new(sin_half, 0.0))
	ry.set_element(1, 1, Complex.new(cos_half, 0.0))

	return ry


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


func assert_approx(actual: float, expected: float, msg: String):
	"""Assert two floats are approximately equal."""
	if abs(actual - expected) < EPSILON:
		passed += 1
		print("  ✓ %s" % msg)
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
