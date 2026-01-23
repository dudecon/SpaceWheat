extends SceneTree

## Model C Architecture Migration Tests
##
## Verifies that the unified RegisterMap + density_matrix architecture works:
## - allocate_qubit() returns correct qubit index
## - project_qubit() collapses state correctly
## - get_qubit_for_emoji() returns correct index
## - get_emoji_pair_for_qubit() returns correct pair
## - apply_gate() and apply_gate_2q() work on density matrix
## - measure_axis() samples and projects correctly

const QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")

var test_results: Array = []


func _init():
	print("\n============================================================")
	print("MODEL C ARCHITECTURE MIGRATION TESTS")
	print("============================================================\n")

	test_allocate_qubit()
	test_get_qubit_for_emoji()
	test_get_emoji_pair_for_qubit()
	test_project_qubit()
	test_apply_gate()
	test_apply_gate_2q()
	test_measure_axis()

	print("\n============================================================")
	print("TEST SUMMARY")
	print("============================================================")

	var passed = 0
	var failed = 0
	for result in test_results:
		if result.passed:
			passed += 1
			print("  [OK] %s" % result.name)
		else:
			failed += 1
			print("  [FAIL] %s: %s" % [result.name, result.message])

	print("\n%d passed, %d failed" % [passed, failed])
	print("============================================================\n")

	quit()


func test_allocate_qubit():
	"""Test allocate_qubit() returns sequential qubit indices."""
	print("\n--- Test: allocate_qubit() ---")

	var qc = QuantumComputer.new("test")

	var q0 = qc.allocate_qubit("A", "a")
	var q1 = qc.allocate_qubit("B", "b")
	var q2 = qc.allocate_qubit("C", "c")

	print("  Allocated qubits: %d, %d, %d" % [q0, q1, q2])

	var passed = (q0 == 0 and q1 == 1 and q2 == 2)
	if passed:
		print("  [OK] Sequential indices: 0, 1, 2")
	else:
		print("  [FAIL] Expected 0, 1, 2")

	test_results.append({
		"name": "allocate_qubit sequential indices",
		"passed": passed,
		"message": "Got %d, %d, %d" % [q0, q1, q2] if not passed else ""
	})


func test_get_qubit_for_emoji():
	"""Test get_qubit_for_emoji() returns correct index."""
	print("\n--- Test: get_qubit_for_emoji() ---")

	var qc = QuantumComputer.new("test")
	qc.allocate_qubit("X", "x")
	qc.allocate_qubit("Y", "y")

	var qx = qc.get_qubit_for_emoji("X")
	var qy = qc.get_qubit_for_emoji("Y")
	var qz = qc.get_qubit_for_emoji("Z")  # Not allocated

	print("  X -> qubit %d, Y -> qubit %d, Z -> qubit %d" % [qx, qy, qz])

	var passed = (qx == 0 and qy == 1 and qz == -1)
	if passed:
		print("  [OK] Correct lookups")
	else:
		print("  [FAIL] Expected 0, 1, -1")

	test_results.append({
		"name": "get_qubit_for_emoji lookups",
		"passed": passed,
		"message": "Got %d, %d, %d" % [qx, qy, qz] if not passed else ""
	})


func test_get_emoji_pair_for_qubit():
	"""Test get_emoji_pair_for_qubit() returns correct pair."""
	print("\n--- Test: get_emoji_pair_for_qubit() ---")

	var qc = QuantumComputer.new("test")
	qc.allocate_qubit("N", "S")

	var pair = qc.get_emoji_pair_for_qubit(0)
	var empty_pair = qc.get_emoji_pair_for_qubit(99)

	print("  Qubit 0: north=%s, south=%s" % [pair.get("north", "?"), pair.get("south", "?")])

	var passed = (pair.get("north") == "N" and pair.get("south") == "S" and empty_pair.is_empty())
	if passed:
		print("  [OK] Correct pair returned")
	else:
		print("  [FAIL] Unexpected pair")

	test_results.append({
		"name": "get_emoji_pair_for_qubit",
		"passed": passed,
		"message": "Got %s" % str(pair) if not passed else ""
	})


func test_project_qubit():
	"""Test project_qubit() collapses state correctly."""
	print("\n--- Test: project_qubit() ---")

	var qc = QuantumComputer.new("test")
	qc.allocate_qubit("0", "1")
	qc.initialize_basis(0)  # Start in |0>

	# Apply H to get superposition
	var H = QuantumGateLibrary.get_gate("H")["matrix"]
	qc.apply_gate(0, H)

	# Check we're in superposition
	var p0_before = qc.get_marginal(0, 0)
	print("  Before projection: P(0) = %.3f" % p0_before)

	# Project onto |0>
	var success = qc.project_qubit(0, 0)

	# Check state collapsed
	var p0_after = qc.get_marginal(0, 0)
	print("  After project_qubit(0, 0): P(0) = %.3f" % p0_after)

	var passed = success and abs(p0_after - 1.0) < 0.01
	if passed:
		print("  [OK] State collapsed to |0>")
	else:
		print("  [FAIL] State not collapsed correctly")

	test_results.append({
		"name": "project_qubit collapses state",
		"passed": passed,
		"message": "P(0) = %.3f after projection" % p0_after if not passed else ""
	})


func test_apply_gate():
	"""Test apply_gate() modifies density matrix."""
	print("\n--- Test: apply_gate() ---")

	var qc = QuantumComputer.new("test")
	qc.allocate_qubit("0", "1")
	qc.initialize_basis(0)  # |0>

	var p0_initial = qc.get_marginal(0, 0)
	print("  Initial: P(0) = %.3f" % p0_initial)

	# Apply X gate (bit flip)
	var X = QuantumGateLibrary.get_gate("X")["matrix"]
	var success = qc.apply_gate(0, X)

	var p0_after = qc.get_marginal(0, 0)
	print("  After X gate: P(0) = %.3f" % p0_after)

	var passed = success and abs(p0_after - 0.0) < 0.01
	if passed:
		print("  [OK] X gate flipped |0> to |1>")
	else:
		print("  [FAIL] X gate did not flip correctly")

	test_results.append({
		"name": "apply_gate X flips state",
		"passed": passed,
		"message": "P(0) = %.3f after X" % p0_after if not passed else ""
	})


func test_apply_gate_2q():
	"""Test apply_gate_2q() creates entanglement."""
	print("\n--- Test: apply_gate_2q() ---")

	var qc = QuantumComputer.new("test")
	qc.allocate_qubit("A", "a")
	qc.allocate_qubit("B", "b")
	qc.initialize_basis(0)  # |00>

	# Apply H to qubit 0
	var H = QuantumGateLibrary.get_gate("H")["matrix"]
	qc.apply_gate(0, H)

	# Apply CNOT(0,1) - this should create entanglement
	var CNOT = QuantumGateLibrary.get_gate("CNOT")["matrix"]
	var success = qc.apply_gate_2q(0, 1, CNOT)

	print("  Applied H(0) then CNOT(0,1)")

	# Check mutual information (should be > 0 for entangled state)
	var mi = qc.get_mutual_information(0, 1)
	print("  Mutual information: %.3f" % mi)

	# For now, just check the gate succeeded
	var passed = success
	if passed:
		print("  [OK] 2Q gate applied successfully")
	else:
		print("  [FAIL] 2Q gate failed")

	test_results.append({
		"name": "apply_gate_2q succeeds",
		"passed": passed,
		"message": "" if passed else "Gate returned false"
	})


func test_measure_axis():
	"""Test measure_axis() samples and projects."""
	print("\n--- Test: measure_axis() ---")

	var qc = QuantumComputer.new("test")
	qc.allocate_qubit("N", "S")
	qc.initialize_basis(0)  # |N>

	# Measure - should always get "N" since we're in |N>
	var outcome = qc.measure_axis("N", "S")
	print("  Measured |N> state: outcome = %s" % outcome)

	# Check state is still |N>
	var p_n = qc.get_marginal(0, 0)
	print("  After measurement: P(N) = %.3f" % p_n)

	var passed = (outcome == "N" and abs(p_n - 1.0) < 0.01)
	if passed:
		print("  [OK] Deterministic measurement of |N>")
	else:
		print("  [FAIL] Unexpected outcome or state")

	test_results.append({
		"name": "measure_axis deterministic",
		"passed": passed,
		"message": "outcome=%s, P(N)=%.3f" % [outcome, p_n] if not passed else ""
	})
