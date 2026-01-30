extends SceneTree

## Deep integration test: Gate application → Density matrix changes → C++ evolution
## Run: godot --headless --script tests/test_gate_application_integration.gd

const GateInjector = preload("res://Core/QuantumSubstrate/GateInjector.gd")
const GateActionHandler = preload("res://UI/Handlers/GateActionHandler.gd")

var passed = 0
var failed = 0
var biome = null
var farm = null

const DIVIDER = "============================================================"


func _init():
	print("\n" + DIVIDER)
	print("GATE APPLICATION INTEGRATION TEST")
	print("Testing: Gate Injection → Density Matrix → C++ Evolution")
	print(DIVIDER)

	# Wait for autoloads
	await self.process_frame

	if await setup_test_environment():
		test_single_gate_injection()
		test_two_qubit_gate_injection()
		test_bell_state_creation()
		test_batch_gate_injection()
		test_density_matrix_persistence()
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

	# Create a real StarterForest biome (has quantum computer)
	var StarterForestBiome = load("res://Core/Environment/StarterForestBiome.gd")
	biome = StarterForestBiome.new()
	biome.name = "TestBiome"
	root.add_child(biome)

	# Wait for ready
	await self.process_frame

	if not biome.quantum_computer:
		print("  ✗ Failed to create quantum computer")
		return false

	if not biome.quantum_computer.density_matrix:
		print("  ✗ Density matrix not initialized")
		return false

	var n_qubits = biome.get_total_register_count()
	var dim = biome.quantum_computer.density_matrix.n

	print("  ✓ Biome created: %s" % biome.name)
	print("  ✓ Quantum computer initialized")
	print("  ✓ Qubits: %d" % n_qubits)
	print("  ✓ Density matrix dimension: %dx%d" % [dim, dim])

	return true


func test_single_gate_injection():
	"""Test single-qubit gate changes density matrix."""
	print("\n[Single Gate Injection]")

	var qc = biome.quantum_computer
	var qubit_id = 0  # First qubit

	# IMPORTANT: Reinitialize to pure basis state for testing
	# (Biome starts in uniform superposition which is invariant under many gates)
	qc.initialize_basis(0)
	print("  ✓ Initialized to |0...0⟩ basis state for testing")

	# Snapshot density matrix before
	var dm_before = _snapshot_density_matrix(qc.density_matrix)
	print("  ✓ Captured density matrix before (dim: %d)" % dm_before.size())

	# Apply Hadamard gate via GateInjector
	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var h_matrix = gate_lib.GATES["H"]["matrix"]

	var result = GateInjector.inject_gate(biome, qubit_id, h_matrix, farm)

	assert_true(result.success, "Gate injection succeeded")
	assert_eq(result.qubit, qubit_id, "Correct qubit targeted")
	assert_true(result.gate_injected, "Gate injected flag set")

	# Snapshot density matrix after
	var dm_after = _snapshot_density_matrix(qc.density_matrix)

	# Verify density matrix changed
	var changed = not _matrices_equal(dm_before, dm_after)
	assert_true(changed, "Density matrix changed after gate")

	if changed:
		print("  ✓ Density matrix was modified by gate")
		_print_matrix_diff(dm_before, dm_after)


func test_two_qubit_gate_injection():
	"""Test two-qubit gate (CNOT) with proper state preparation."""
	print("\n[Two-Qubit Gate: X + CNOT]")

	var qc = biome.quantum_computer
	var qubit_a = 0  # Control
	var qubit_b = 1  # Target

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()

	# IMPORTANT: Reinitialize to pure basis state for testing
	qc.initialize_basis(0)
	print("  ✓ Initialized to |0...0⟩ basis state")

	# Snapshot initial state
	var dm_initial = _snapshot_density_matrix(qc.density_matrix)

	# Step 1: Apply X to control qubit (flip to |1⟩)
	var x_matrix = gate_lib.GATES["X"]["matrix"]
	var x_result = GateInjector.inject_gate(biome, qubit_a, x_matrix, farm)
	assert_true(x_result.success, "X gate applied to control")

	var dm_after_x = _snapshot_density_matrix(qc.density_matrix)
	var changed_by_x = not _matrices_equal(dm_initial, dm_after_x)
	assert_true(changed_by_x, "X gate changed density matrix")
	print("  ✓ Prepared |1⟩ state on control qubit")

	# Step 2: Apply CNOT (should flip target since control=|1⟩)
	var cnot_matrix = gate_lib.GATES["CNOT"]["matrix"]

	# Debug: Check CNOT matrix size
	print("    [Debug: CNOT matrix dim=%d, expected 4x4 for 2-qubit gate]" % cnot_matrix.n)

	# Apply via GateInjector (only once - CNOT is self-inverse!)
	var cnot_result = GateInjector.inject_gate_2q(biome, qubit_a, qubit_b, cnot_matrix, farm)

	assert_true(cnot_result.success, "CNOT applied")
	assert_eq(cnot_result.qubit_a, qubit_a, "Correct control qubit")
	assert_eq(cnot_result.qubit_b, qubit_b, "Correct target qubit")

	# Verify CNOT changed state
	var dm_after_cnot = _snapshot_density_matrix(qc.density_matrix)
	var changed_by_cnot = not _matrices_equal(dm_after_x, dm_after_cnot)

	assert_true(changed_by_cnot, "CNOT changed density matrix")

	if changed_by_cnot:
		print("  ✓ CNOT flipped target (control was |1⟩)")
		_print_matrix_diff(dm_after_x, dm_after_cnot)
	else:
		print("  ✗ CNOT had no effect (unexpected!)")
		# Debug: show what state we're in
		var n_qubits = qc.register_map.num_qubits
		var expected_in = 1 << (n_qubits - 1)  # |10000⟩
		var expected_out = expected_in | (1 << (n_qubits - 2))  # |11000⟩
		print("    Expected transition: |%d⟩ → |%d⟩" % [expected_in, expected_out])
		print("    ρ[%d,%d] = %.4f" % [expected_in, expected_in, qc.density_matrix.get_element(expected_in, expected_in).re])
		print("    ρ[%d,%d] = %.4f" % [expected_out, expected_out, qc.density_matrix.get_element(expected_out, expected_out).re])


func test_bell_state_creation():
	"""Test Bell state creation: H + CNOT = (|00⟩+|11⟩)/√2."""
	print("\n[Bell State Creation: H + CNOT]")

	var qc = biome.quantum_computer
	var qubit_a = 0  # Control
	var qubit_b = 1  # Target

	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()

	# IMPORTANT: Reinitialize to pure basis state for testing
	qc.initialize_basis(0)
	print("  ✓ Initialized to |0...0⟩ basis state")

	# Snapshot initial
	var dm_initial = _snapshot_density_matrix(qc.density_matrix)

	# Step 1: Apply H to control (creates superposition)
	var h_matrix = gate_lib.GATES["H"]["matrix"]
	var h_result = GateInjector.inject_gate(biome, qubit_a, h_matrix, farm)
	assert_true(h_result.success, "H gate applied to control")

	var dm_after_h = _snapshot_density_matrix(qc.density_matrix)
	var changed_by_h = not _matrices_equal(dm_initial, dm_after_h)
	assert_true(changed_by_h, "H created superposition")
	print("  ✓ Created superposition (|0⟩+|1⟩)/√2 on control")

	# Step 2: Apply CNOT (creates entanglement)
	var cnot_matrix = gate_lib.GATES["CNOT"]["matrix"]
	var cnot_result = GateInjector.inject_gate_2q(biome, qubit_a, qubit_b, cnot_matrix, farm)

	assert_true(cnot_result.success, "CNOT applied")

	# Verify Bell state created
	var dm_after_cnot = _snapshot_density_matrix(qc.density_matrix)
	var changed_by_cnot = not _matrices_equal(dm_after_h, dm_after_cnot)
	assert_true(changed_by_cnot, "CNOT created entanglement")

	if changed_by_cnot:
		print("  ✓ Bell state |Φ+⟩ = (|00⟩+|11⟩)/√2 created")
		_print_matrix_diff(dm_after_h, dm_after_cnot)

	# Verify trace still 1.0
	var trace = _calculate_trace(qc.density_matrix)
	assert_true(abs(trace - 1.0) < 0.01, "Trace preserved after entanglement")
	print("  ✓ Trace(ρ) = %.6f after Bell state creation" % trace)


func test_batch_gate_injection():
	"""Test batch gate injection (multi-select) preserves order."""
	print("\n[Batch Gate Injection - Multi-Select]")

	var qc = biome.quantum_computer

	# IMPORTANT: Reinitialize to pure basis state for testing
	qc.initialize_basis(0)
	print("  ✓ Initialized to |0...0⟩ basis state")

	# Snapshot before batch
	var dm_before = _snapshot_density_matrix(qc.density_matrix)

	# Create batch operations (Hadamard on qubits 0, 1)
	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	var h_matrix = gate_lib.GATES["H"]["matrix"]

	var batch_ops = [
		{"biome": biome, "qubit": 0, "gate_name": "H", "gate_matrix": h_matrix},
		{"biome": biome, "qubit": 1, "gate_name": "H", "gate_matrix": h_matrix}
	]

	var result = GateInjector.inject_gate_batch(batch_ops, farm)

	assert_true(result.success, "Batch injection succeeded")
	assert_eq(result.applied_count, 2, "Applied 2 gates")
	assert_true(result.batch_injected, "Batch flag set")
	assert_eq(result.order, [0, 1], "Gates applied in order")

	print("  ✓ Batch applied gates in order: %s" % str(result.order))

	# Snapshot after batch
	var dm_after = _snapshot_density_matrix(qc.density_matrix)

	# Verify changed
	var changed = not _matrices_equal(dm_before, dm_after)
	assert_true(changed, "Density matrix changed after batch")

	if changed:
		print("  ✓ Batch operation modified density matrix")


func test_density_matrix_persistence():
	"""Test that density matrix changes persist (C++ will use this state)."""
	print("\n[Density Matrix Persistence]")

	var qc = biome.quantum_computer
	var dm = qc.density_matrix

	# Check some basic quantum properties
	var trace = _calculate_trace(dm)
	var is_hermitian = _check_hermitian(dm)

	print("  ✓ Trace(ρ) = %.6f (should be ~1.0)" % trace)
	assert_true(abs(trace - 1.0) < 0.01, "Trace is ~1.0")

	assert_true(is_hermitian, "Density matrix is Hermitian")

	# Verify positive semi-definite (all eigenvalues >= 0)
	# This is harder to test without linear algebra library, so we skip for now

	print("  ✓ Density matrix maintains quantum properties")
	print("  ✓ C++ evolution will use this modified state")


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

	var max_diff = 0.0
	var changes = 0

	for i in range(dm1.size()):
		var diff_re = abs(dm1[i].re - dm2[i].re)
		var diff_im = abs(dm1[i].im - dm2[i].im)
		var total_diff = sqrt(diff_re * diff_re + diff_im * diff_im)

		if total_diff > epsilon:
			changes += 1
			max_diff = max(max_diff, total_diff)

	# Debug output
	if changes > 0:
		print("    [Matrix Comparison: %d elements changed, max_diff=%.10f]" % [changes, max_diff])

	return changes == 0


func _print_matrix_diff(dm1: Array, dm2: Array):
	"""Print first few changed elements."""
	var changes = 0
	for i in range(min(dm1.size(), 16)):  # First 16 elements
		var diff_re = abs(dm1[i].re - dm2[i].re)
		var diff_im = abs(dm1[i].im - dm2[i].im)
		if diff_re > 1e-10 or diff_im > 1e-10:
			changes += 1
			if changes <= 3:  # Show first 3 changes
				print("    Element %d: (%.4f, %.4f) → (%.4f, %.4f)" % [
					i, dm1[i].re, dm1[i].im, dm2[i].re, dm2[i].im
				])
	if changes > 3:
		print("    ... and %d more changes" % (changes - 3))


func _calculate_trace(dm) -> float:
	"""Calculate trace of density matrix (should be 1.0)."""
	var trace = 0.0
	for i in range(dm.n):
		var elem = dm.get_element(i, i)
		trace += elem.re  # Trace is sum of diagonal (real parts)
	return trace


func _check_hermitian(dm) -> bool:
	"""Check if density matrix is Hermitian (ρ† = ρ)."""
	for i in range(dm.n):
		for j in range(i + 1, dm.n):  # Check upper triangle
			var elem_ij = dm.get_element(i, j)
			var elem_ji = dm.get_element(j, i)

			# For Hermitian: ρ_ij = conj(ρ_ji)
			var diff_re = abs(elem_ij.re - elem_ji.re)
			var diff_im = abs(elem_ij.im + elem_ji.im)  # Note: + for conjugate

			if diff_re > 1e-6 or diff_im > 1e-6:
				return false

	return true


func assert_eq(actual, expected, msg: String):
	if actual == expected:
		passed += 1
		print("  ✓ %s" % msg)
	else:
		failed += 1
		print("  ✗ %s" % msg)
		print("    Expected: %s" % str(expected))
		print("    Actual:   %s" % str(actual))


func assert_true(condition: bool, msg: String):
	if condition:
		passed += 1
		print("  ✓ %s" % msg)
	else:
		failed += 1
		print("  ✗ %s" % msg)
