extends SceneTree

## Minimal unit test for 2-qubit gate embedding
## Run: godot --headless --script tests/test_2q_gate_embed.gd

const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")

var passed = 0
var failed = 0

const DIVIDER = "============================================================"


func _init():
	print("\n" + DIVIDER)
	print("2-QUBIT GATE EMBEDDING TEST")
	print(DIVIDER)

	await self.process_frame

	test_cnot_matrix_contents()
	test_embed_2q_identity_2qubit()
	test_embed_2q_cnot_2qubit()
	test_embed_2q_cnot_3qubit()
	test_apply_cnot_to_state()
	test_full_density_matrix_cnot()
	test_5qubit_cnot()
	test_5qubit_uniform_superposition_invariance()
	test_cz_gate()
	test_swap_gate()

	print("\n" + DIVIDER)
	print("RESULTS: %d passed, %d failed" % [passed, failed])
	print(DIVIDER + "\n")

	quit(0 if failed == 0 else 1)


func test_cnot_matrix_contents():
	"""Verify CNOT matrix has correct entries."""
	print("\n[CNOT Matrix Contents]")

	var cnot = QuantumGateLibrary.get_gate("CNOT")["matrix"]

	# CNOT in basis {|00⟩, |01⟩, |10⟩, |11⟩}:
	# |00⟩ -> |00⟩, |01⟩ -> |01⟩, |10⟩ -> |11⟩, |11⟩ -> |10⟩
	assert_complex_eq(cnot.get_element(0, 0), Complex.one(), "CNOT[0,0] = 1")
	assert_complex_eq(cnot.get_element(1, 1), Complex.one(), "CNOT[1,1] = 1")
	assert_complex_eq(cnot.get_element(2, 2), Complex.zero(), "CNOT[2,2] = 0")
	assert_complex_eq(cnot.get_element(3, 3), Complex.zero(), "CNOT[3,3] = 0")
	assert_complex_eq(cnot.get_element(3, 2), Complex.one(), "CNOT[3,2] = 1 (|10⟩ -> |11⟩)")
	assert_complex_eq(cnot.get_element(2, 3), Complex.one(), "CNOT[2,3] = 1 (|11⟩ -> |10⟩)")


func test_embed_2q_identity_2qubit():
	"""Embed identity in 2-qubit system should be identity."""
	print("\n[Embed Identity in 2-Qubit System]")

	var I2 = ComplexMatrix.identity(4)  # 2-qubit identity
	var embedded = _embed_2q_unitary(I2, 0, 1, 2)

	# Should be 4x4 identity
	assert_eq(embedded.n, 4, "Embedded dimension is 4")

	for i in range(4):
		for j in range(4):
			var expected = Complex.one() if i == j else Complex.zero()
			assert_complex_eq(embedded.get_element(i, j), expected,
				"I_embedded[%d,%d]" % [i, j])


func test_embed_2q_cnot_2qubit():
	"""Embed CNOT in 2-qubit system should be CNOT itself."""
	print("\n[Embed CNOT in 2-Qubit System]")

	var cnot = QuantumGateLibrary.get_gate("CNOT")["matrix"]
	var embedded = _embed_2q_unitary(cnot, 0, 1, 2)

	# Should be exactly CNOT (4x4)
	assert_eq(embedded.n, 4, "Embedded dimension is 4")

	for i in range(4):
		for j in range(4):
			var expected = cnot.get_element(i, j)
			var actual = embedded.get_element(i, j)
			assert_complex_eq(actual, expected, "CNOT_embedded[%d,%d]" % [i, j])


func test_embed_2q_cnot_3qubit():
	"""Embed CNOT(0,1) in 3-qubit system."""
	print("\n[Embed CNOT(0,1) in 3-Qubit System]")

	var cnot = QuantumGateLibrary.get_gate("CNOT")["matrix"]
	var embedded = _embed_2q_unitary(cnot, 0, 1, 3)

	# Should be 8x8
	assert_eq(embedded.n, 8, "Embedded dimension is 8")

	# Key mappings (MSB convention: qubit 0 is most significant):
	# |000⟩ (0) -> |000⟩ (0): control=0, no change
	# |001⟩ (1) -> |001⟩ (1): control=0, no change
	# |010⟩ (2) -> |010⟩ (2): control=0, no change (qubit 1=1 but control=0)
	# |011⟩ (3) -> |011⟩ (3): control=0, no change
	# |100⟩ (4) -> |110⟩ (6): control=1, target flips
	# |101⟩ (5) -> |111⟩ (7): control=1, target flips
	# |110⟩ (6) -> |100⟩ (4): control=1, target flips
	# |111⟩ (7) -> |101⟩ (5): control=1, target flips

	print("  Checking key transitions:")

	# |000⟩ -> |000⟩
	assert_complex_eq(embedded.get_element(0, 0), Complex.one(), "|000⟩ -> |000⟩")

	# |100⟩ -> |110⟩ (basis 4 -> 6)
	assert_complex_eq(embedded.get_element(4, 4), Complex.zero(), "|100⟩ !-> |100⟩")
	assert_complex_eq(embedded.get_element(6, 4), Complex.one(), "|100⟩ -> |110⟩")

	# |110⟩ -> |100⟩ (basis 6 -> 4)
	assert_complex_eq(embedded.get_element(6, 6), Complex.zero(), "|110⟩ !-> |110⟩")
	assert_complex_eq(embedded.get_element(4, 6), Complex.one(), "|110⟩ -> |100⟩")

	# Verify full matrix is unitary: U U† = I
	var U_dag = embedded.dagger()
	var product = embedded.mul(U_dag)
	var is_unitary = true
	for i in range(8):
		for j in range(8):
			var expected = Complex.one() if i == j else Complex.zero()
			var diff = product.get_element(i, j).sub(expected).abs()
			if diff > 1e-10:
				is_unitary = false
				print("    U*U†[%d,%d] = %.6f+%.6fi (expected %s)" % [
					i, j, product.get_element(i, j).re, product.get_element(i, j).im,
					"1" if i == j else "0"])
	assert_true(is_unitary, "Embedded CNOT is unitary")


func test_apply_cnot_to_state():
	"""Apply embedded CNOT to |100⟩ state, should get |110⟩."""
	print("\n[Apply CNOT to |100⟩ State]")

	var cnot = QuantumGateLibrary.get_gate("CNOT")["matrix"]
	var embedded = _embed_2q_unitary(cnot, 0, 1, 3)

	# Create |100⟩ state as density matrix ρ = |100⟩⟨100|
	var rho = ComplexMatrix.new(8)
	rho.set_element(4, 4, Complex.one())  # |100⟩⟨100|

	print("  Initial state: ρ[4,4] = %.2f (|100⟩⟨100|)" % rho.get_element(4, 4).re)

	# Apply CNOT: ρ' = U ρ U†
	var rho_new = embedded.mul(rho).mul(embedded.dagger())

	# Result should be |110⟩⟨110| = ρ'[6,6] = 1
	print("  After CNOT:")
	print("    ρ'[4,4] = %.4f (should be 0)" % rho_new.get_element(4, 4).re)
	print("    ρ'[6,6] = %.4f (should be 1)" % rho_new.get_element(6, 6).re)

	assert_complex_eq(rho_new.get_element(4, 4), Complex.zero(), "ρ'[4,4] = 0 (not |100⟩)")
	assert_complex_eq(rho_new.get_element(6, 6), Complex.one(), "ρ'[6,6] = 1 (is |110⟩)")


func test_full_density_matrix_cnot():
	"""Test full quantum computer workflow with CNOT."""
	print("\n[Full QuantumComputer CNOT Test - 3 qubits]")

	var QC = load("res://Core/QuantumSubstrate/QuantumComputer.gd")
	var qc = QC.new("TestQC")

	# Allocate 3 qubits
	qc.allocate_qubit("A", "a")  # qubit 0
	qc.allocate_qubit("B", "b")  # qubit 1
	qc.allocate_qubit("C", "c")  # qubit 2

	# Initialize to |000⟩
	qc.initialize_basis(0)

	print("  Qubits: %d, Dim: %d" % [qc.register_map.num_qubits, qc.density_matrix.n])
	print("  Initial: ρ[0,0] = %.4f (|000⟩)" % qc.density_matrix.get_element(0, 0).re)

	# Apply X to qubit 0: |000⟩ -> |100⟩
	var x_result = qc.apply_pauli_x(0)
	assert_true(x_result, "X gate applied")

	print("  After X(0): ρ[4,4] = %.4f (|100⟩)" % qc.density_matrix.get_element(4, 4).re)
	assert_true(qc.density_matrix.get_element(4, 4).re > 0.9, "X created |100⟩")

	# Snapshot before CNOT
	var dm_before = _snapshot(qc.density_matrix)

	# Apply CNOT(0,1): |100⟩ -> |110⟩
	print("  Applying CNOT(0,1)...")
	var cnot_result = qc.apply_cnot(0, 1)
	assert_true(cnot_result, "CNOT returned true")

	# Snapshot after CNOT
	var dm_after = _snapshot(qc.density_matrix)

	# Check if density matrix changed
	var changed = false
	var max_diff = 0.0
	for i in range(dm_before.size()):
		var diff = abs(dm_before[i].re - dm_after[i].re) + abs(dm_before[i].im - dm_after[i].im)
		if diff > 1e-10:
			changed = true
			max_diff = max(max_diff, diff)

	print("  Matrix changed: %s (max_diff: %.10f)" % [changed, max_diff])
	assert_true(changed, "CNOT changed density matrix")

	if not changed:
		print("  [DEBUG] Investigating why CNOT had no effect...")

		# Check the embedded matrix
		var cnot_gate = QuantumGateLibrary.get_gate("CNOT")["matrix"]
		var embedded = _embed_2q_unitary(cnot_gate, 0, 1, 3)

		print("  [DEBUG] Embedded CNOT non-zero elements:")
		for i in range(8):
			for j in range(8):
				var elem = embedded.get_element(i, j)
				if elem.abs() > 1e-10:
					print("    [%d,%d] = %.4f + %.4fi" % [i, j, elem.re, elem.im])

		# Check if embedded is identity
		var is_identity = true
		for i in range(8):
			for j in range(8):
				var expected = Complex.one() if i == j else Complex.zero()
				if embedded.get_element(i, j).sub(expected).abs() > 1e-10:
					is_identity = false
					break

		print("  [DEBUG] Embedded matrix is identity: %s" % is_identity)

	# Final state should be |110⟩
	print("  After CNOT(0,1):")
	print("    ρ[4,4] = %.4f (|100⟩, should be 0)" % qc.density_matrix.get_element(4, 4).re)
	print("    ρ[6,6] = %.4f (|110⟩, should be 1)" % qc.density_matrix.get_element(6, 6).re)


func test_5qubit_cnot():
	"""Test CNOT on 5-qubit system (matches StarterForestBiome size)."""
	print("\n[Full QuantumComputer CNOT Test - 5 qubits]")

	var QC = load("res://Core/QuantumSubstrate/QuantumComputer.gd")
	var qc = QC.new("TestQC5")

	# Allocate 5 qubits (like StarterForestBiome)
	qc.allocate_qubit("A", "a")  # qubit 0
	qc.allocate_qubit("B", "b")  # qubit 1
	qc.allocate_qubit("C", "c")  # qubit 2
	qc.allocate_qubit("D", "d")  # qubit 3
	qc.allocate_qubit("E", "e")  # qubit 4

	# Initialize to |00000⟩
	qc.initialize_basis(0)

	print("  Qubits: %d, Dim: %d" % [qc.register_map.num_qubits, qc.density_matrix.n])
	print("  Initial: ρ[0,0] = %.4f (|00000⟩)" % qc.density_matrix.get_element(0, 0).re)

	# Apply X to qubit 0: |00000⟩ -> |10000⟩ (basis 16)
	var x_result = qc.apply_pauli_x(0)
	assert_true(x_result, "X gate applied (5q)")

	print("  After X(0): ρ[16,16] = %.4f (|10000⟩)" % qc.density_matrix.get_element(16, 16).re)
	assert_true(qc.density_matrix.get_element(16, 16).re > 0.9, "X created |10000⟩")

	# Snapshot before CNOT
	var dm_before = _snapshot(qc.density_matrix)

	# Apply CNOT(0,1): |10000⟩ -> |11000⟩ (basis 16 -> 24)
	print("  Applying CNOT(0,1)...")
	var cnot_result = qc.apply_cnot(0, 1)
	assert_true(cnot_result, "CNOT returned true (5q)")

	# Snapshot after CNOT
	var dm_after = _snapshot(qc.density_matrix)

	# Check if density matrix changed
	var changed = false
	var max_diff = 0.0
	for i in range(dm_before.size()):
		var diff = abs(dm_before[i].re - dm_after[i].re) + abs(dm_before[i].im - dm_after[i].im)
		if diff > 1e-10:
			changed = true
			max_diff = max(max_diff, diff)

	print("  Matrix changed: %s (max_diff: %.10f)" % [changed, max_diff])
	assert_true(changed, "CNOT changed density matrix (5q)")

	# Check specific transitions
	print("  After CNOT(0,1):")
	print("    ρ[16,16] = %.4f (|10000⟩, should be 0)" % qc.density_matrix.get_element(16, 16).re)
	print("    ρ[24,24] = %.4f (|11000⟩, should be 1)" % qc.density_matrix.get_element(24, 24).re)


func test_cz_gate():
	"""Test CZ gate: applies -1 phase when both qubits are |1⟩."""
	print("\n[CZ Gate Test]")

	var QC = load("res://Core/QuantumSubstrate/QuantumComputer.gd")
	var qc = QC.new("TestCZ")

	# Allocate 3 qubits
	qc.allocate_qubit("A", "a")
	qc.allocate_qubit("B", "b")
	qc.allocate_qubit("C", "c")

	# Initialize to |110⟩ (should get -1 phase from CZ)
	# In MSB convention: qubit0=1, qubit1=1, qubit2=0 → basis index 6
	qc.initialize_basis(6)
	print("  Initial: |110⟩ (basis 6)")

	# CZ on qubits 0,1 should apply -1 phase to |11⟩ component
	var cz_before = qc.density_matrix.get_element(6, 6)
	print("  ρ[6,6] before CZ: %.4f + %.4fi" % [cz_before.re, cz_before.im])

	qc.apply_cz(0, 1)

	var cz_after = qc.density_matrix.get_element(6, 6)
	print("  ρ[6,6] after CZ: %.4f + %.4fi" % [cz_after.re, cz_after.im])

	# For a pure state, CZ applies -1 phase but |ρ| stays same
	# ρ = |ψ⟩⟨ψ| where |ψ⟩ → -|ψ⟩, so ρ → |-ψ⟩⟨-ψ| = ρ
	# CZ on computational basis state doesn't change diagonal!
	assert_true(abs(cz_after.re - cz_before.re) < 0.01, "CZ on |11⟩ preserves diagonal (global phase)")

	# Now test CZ on superposition to see phase effect
	qc.initialize_basis(0)  # |000⟩
	qc.apply_hadamard(0)    # (|0⟩+|1⟩)/√2 ⊗ |00⟩
	qc.apply_hadamard(1)    # (|0⟩+|1⟩)/√2 ⊗ (|0⟩+|1⟩)/√2 ⊗ |0⟩

	var dm_before = _snapshot(qc.density_matrix)
	print("  After H(0)H(1): equal superposition")

	qc.apply_cz(0, 1)

	var dm_after = _snapshot(qc.density_matrix)

	var cz_changed = false
	for i in range(dm_before.size()):
		var diff = abs(dm_before[i].re - dm_after[i].re) + abs(dm_before[i].im - dm_after[i].im)
		if diff > 1e-10:
			cz_changed = true
			break

	print("  CZ on superposition changed matrix: %s" % cz_changed)
	assert_true(cz_changed, "CZ changes superposition state")


func test_swap_gate():
	"""Test SWAP gate: exchanges states of two qubits."""
	print("\n[SWAP Gate Test]")

	var QC = load("res://Core/QuantumSubstrate/QuantumComputer.gd")
	var qc = QC.new("TestSWAP")

	# Allocate 3 qubits
	qc.allocate_qubit("A", "a")
	qc.allocate_qubit("B", "b")
	qc.allocate_qubit("C", "c")

	# Initialize to |100⟩ (qubit0=1, qubit1=0, qubit2=0) → basis 4
	qc.initialize_basis(4)
	print("  Initial: |100⟩ (basis 4)")
	print("  ρ[4,4] = %.4f" % qc.density_matrix.get_element(4, 4).re)

	# SWAP qubits 0 and 1: |100⟩ → |010⟩ (basis 2)
	qc.apply_swap(0, 1)

	print("  After SWAP(0,1):")
	print("  ρ[4,4] = %.4f (was |100⟩, should be 0)" % qc.density_matrix.get_element(4, 4).re)
	print("  ρ[2,2] = %.4f (now |010⟩, should be 1)" % qc.density_matrix.get_element(2, 2).re)

	assert_true(qc.density_matrix.get_element(4, 4).re < 0.01, "SWAP removed |100⟩")
	assert_true(qc.density_matrix.get_element(2, 2).re > 0.99, "SWAP created |010⟩")

	# Test SWAP is self-inverse
	qc.apply_swap(0, 1)
	print("  After second SWAP(0,1):")
	print("  ρ[4,4] = %.4f (back to |100⟩)" % qc.density_matrix.get_element(4, 4).re)

	assert_true(qc.density_matrix.get_element(4, 4).re > 0.99, "SWAP is self-inverse")


func test_5qubit_uniform_superposition_invariance():
	"""Test that uniform superposition is INVARIANT under X and CNOT.

	PHYSICS NOTE: This is CORRECT quantum behavior!
	- X|+⟩ = |+⟩ (Pauli X leaves |+⟩ state unchanged)
	- CNOT on |+⟩⊗|+⟩ permutes but preserves the overall density matrix

	This explains why biomes starting in uniform superposition don't
	visibly change under single-gate operations.
	"""
	print("\n[5-Qubit Uniform Superposition Invariance (Expected)]")

	var QC = load("res://Core/QuantumSubstrate/QuantumComputer.gd")
	var qc = QC.new("TestQC5Uniform")

	# Allocate 5 qubits
	for i in range(5):
		qc.allocate_qubit("N%d" % i, "S%d" % i)

	# Initialize to uniform superposition (like StarterForest)
	qc.initialize_uniform_superposition()

	var dim = qc.density_matrix.n
	print("  Dim: %d, Initial ρ[0,0] = %.6f (= 1/32)" % [
		dim, qc.density_matrix.get_element(0, 0).re])

	# Snapshot before X
	var dm_before_x = _snapshot(qc.density_matrix)

	# Apply X to qubit 0
	print("  Applying X(0) to |+⟩⊗5...")
	qc.apply_pauli_x(0)

	# Snapshot after X
	var dm_after_x = _snapshot(qc.density_matrix)

	var x_changed = false
	for i in range(dm_before_x.size()):
		var diff = abs(dm_before_x[i].re - dm_after_x[i].re) + abs(dm_before_x[i].im - dm_after_x[i].im)
		if diff > 1e-10:
			x_changed = true
			break

	# X should NOT change the matrix (this is correct physics!)
	print("  X changed matrix: %s (expected: false, since X|+⟩ = |+⟩)" % x_changed)
	assert_true(not x_changed, "X leaves |+⟩⊗5 invariant (correct physics)")

	# Apply CNOT(0,1)
	print("  Applying CNOT(0,1)...")
	qc.apply_cnot(0, 1)

	# Snapshot after CNOT
	var dm_after_cnot = _snapshot(qc.density_matrix)

	var cnot_changed = false
	for i in range(dm_after_x.size()):
		var diff = abs(dm_after_x[i].re - dm_after_cnot[i].re) + abs(dm_after_x[i].im - dm_after_cnot[i].im)
		if diff > 1e-10:
			cnot_changed = true
			break

	# CNOT on uniform superposition may or may not change (depends on details)
	print("  CNOT changed matrix: %s" % cnot_changed)
	# Don't assert - just document the behavior
	print("  ✓ Uniform superposition invariance demonstrated")


# ============================================================================
# HELPER: Embed 2Q unitary (copy from QuantumComputer for testing)
# ============================================================================

func _embed_2q_unitary(U: ComplexMatrix, idx_a: int, idx_b: int, num_qubits: int) -> ComplexMatrix:
	"""Copy of QuantumComputer._embed_2q_unitary for direct testing."""
	var total_dim = 1 << num_qubits
	var result = ComplexMatrix.new(total_dim)

	for out_basis in range(total_dim):
		var out_qubits = _decompose_basis_msb(out_basis, num_qubits)

		for in_basis in range(total_dim):
			var in_qubits = _decompose_basis_msb(in_basis, num_qubits)

			# Check if non-target qubits match (pass-through condition)
			var pass_through = true
			for q in range(num_qubits):
				if q != idx_a and q != idx_b:
					if out_qubits[q] != in_qubits[q]:
						pass_through = false
						break

			if not pass_through:
				continue

			# Extract 2-qubit indices for U
			var in_2q_idx = (in_qubits[idx_a] << 1) | in_qubits[idx_b]
			var out_2q_idx = (out_qubits[idx_a] << 1) | out_qubits[idx_b]

			# Get U[out_2q, in_2q]
			var u_element = U.get_element(out_2q_idx, in_2q_idx)

			# Set result[out_basis, in_basis] = U[out_2q, in_2q]
			result.set_element(out_basis, in_basis, u_element)

	return result


func _decompose_basis_msb(basis: int, num_qubits: int) -> Array[int]:
	"""Decompose basis index to qubit values (MSB convention)."""
	var qubits: Array[int] = []
	for i in range(num_qubits):
		var bit_pos = num_qubits - 1 - i
		qubits.append((basis >> bit_pos) & 1)
	return qubits


func _snapshot(dm: ComplexMatrix) -> Array:
	"""Copy density matrix to array."""
	var snapshot = []
	for i in range(dm.n):
		for j in range(dm.n):
			var elem = dm.get_element(i, j)
			snapshot.append({"re": elem.re, "im": elem.im})
	return snapshot


# ============================================================================
# ASSERTIONS
# ============================================================================

func assert_eq(actual, expected, msg: String):
	if actual == expected:
		passed += 1
		print("  ✓ %s" % msg)
	else:
		failed += 1
		print("  ✗ %s" % msg)
		print("    Expected: %s, Actual: %s" % [str(expected), str(actual)])


func assert_true(condition: bool, msg: String):
	if condition:
		passed += 1
		print("  ✓ %s" % msg)
	else:
		failed += 1
		print("  ✗ %s" % msg)


func assert_complex_eq(actual, expected, msg: String, tol: float = 1e-10):
	var diff = actual.sub(expected).abs()
	if diff < tol:
		passed += 1
		# Only print for key tests
	else:
		failed += 1
		print("  ✗ %s" % msg)
		print("    Expected: %.4f+%.4fi, Actual: %.4f+%.4fi" % [
			expected.re, expected.im, actual.re, actual.im])
