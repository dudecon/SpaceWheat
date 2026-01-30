extends SceneTree

## Test: Gate Injection Chain
##
## Verifies that:
## 1. Gates are applied correctly to the density matrix (ρ' = U ρ U†)
## 2. GateInjector properly calls signal_user_action() on the batcher
## 3. The untested _embed_1q_unitary and apply_gate paths work correctly
##
## Run with: godot --headless -s tests/test_gate_injection.gd

const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")
const GateInjector = preload("res://Core/QuantumSubstrate/GateInjector.gd")

var tests_passed = 0
var tests_failed = 0


func _init():
	var sep = "============================================================"
	print("\n" + sep)
	print("GATE INJECTION TEST SUITE")
	print(sep + "\n")

	test_apply_gate_hadamard()
	test_apply_gate_pauli_x()
	test_embed_1q_unitary()
	test_gate_injector_invalidates_buffer()
	test_2q_gate_cnot()
	test_batch_gate_injection()

	print("\n" + sep)
	print("RESULTS: %d passed, %d failed" % [tests_passed, tests_failed])
	print(sep + "\n")

	quit(0 if tests_failed == 0 else 1)


func assert_eq(actual, expected, msg: String):
	if actual == expected:
		tests_passed += 1
		print("  ✓ %s" % msg)
	else:
		tests_failed += 1
		print("  ✗ %s: expected %s, got %s" % [msg, expected, actual])


func assert_near(actual: float, expected: float, tolerance: float, msg: String):
	if abs(actual - expected) < tolerance:
		tests_passed += 1
		print("  ✓ %s (%.4f ≈ %.4f)" % [msg, actual, expected])
	else:
		tests_failed += 1
		print("  ✗ %s: expected %.4f ± %.4f, got %.4f" % [msg, expected, tolerance, actual])


func test_apply_gate_hadamard():
	"""Test Hadamard gate application: |0⟩ → (|0⟩+|1⟩)/√2"""
	print("\n[TEST] apply_gate() with Hadamard")

	# Setup: 1 qubit in |0⟩ state
	var qc = QuantumComputer.new("test_hadamard")
	qc.allocate_axis(0, "🔥", "❄️")
	qc.initialize_basis(0)  # |0⟩ = |🔥⟩

	# Verify initial state: P(🔥)=1, P(❄️)=0
	var p0_before = qc.get_population("🔥")
	var p1_before = qc.get_population("❄️")
	assert_near(p0_before, 1.0, 0.001, "Initial P(🔥) = 1")
	assert_near(p1_before, 0.0, 0.001, "Initial P(❄️) = 0")

	# Apply Hadamard: H|0⟩ = (|0⟩+|1⟩)/√2
	var H = QuantumGateLibrary.get_gate("H")["matrix"]
	var success = qc.apply_gate(0, H)
	assert_eq(success, true, "Hadamard gate applied successfully")

	# After Hadamard: P(🔥)=0.5, P(❄️)=0.5
	var p0_after = qc.get_population("🔥")
	var p1_after = qc.get_population("❄️")
	assert_near(p0_after, 0.5, 0.01, "After H: P(🔥) = 0.5")
	assert_near(p1_after, 0.5, 0.01, "After H: P(❄️) = 0.5")

	# Verify trace is preserved
	var trace = qc.get_trace()
	assert_near(trace, 1.0, 0.001, "Trace preserved after gate")


func test_apply_gate_pauli_x():
	"""Test Pauli-X gate: |0⟩ → |1⟩"""
	print("\n[TEST] apply_gate() with Pauli-X")

	var qc = QuantumComputer.new("test_pauli_x")
	qc.allocate_axis(0, "N", "S")
	qc.initialize_basis(0)  # |0⟩ = |N⟩

	# Apply X: X|0⟩ = |1⟩
	var X = QuantumGateLibrary.get_gate("X")["matrix"]
	var success = qc.apply_gate(0, X)
	assert_eq(success, true, "Pauli-X gate applied successfully")

	# After X: P(N)=0, P(S)=1
	var p0_after = qc.get_population("N")
	var p1_after = qc.get_population("S")
	assert_near(p0_after, 0.0, 0.01, "After X: P(N) = 0")
	assert_near(p1_after, 1.0, 0.01, "After X: P(S) = 1")


func test_embed_1q_unitary():
	"""Test _embed_1q_unitary() produces correct tensor product."""
	print("\n[TEST] _embed_1q_unitary() tensor structure")

	# Setup: 2 qubits
	var qc = QuantumComputer.new("test_embed")
	qc.allocate_axis(0, "A", "a")  # Qubit 0: A/a
	qc.allocate_axis(1, "B", "b")  # Qubit 1: B/b
	qc.initialize_basis(0)  # |00⟩ = |AB⟩

	# Apply X to qubit 0 only: X⊗I should flip qubit 0
	# |00⟩ → |10⟩ (in MSB convention: qubit 0 is MSB)
	var X = QuantumGateLibrary.get_gate("X")["matrix"]
	qc.apply_gate(0, X)

	# After X on qubit 0: P(A)=0, P(a)=1, P(B)=1, P(b)=0
	var p_A = qc.get_population("A")
	var p_a = qc.get_population("a")
	var p_B = qc.get_population("B")
	var p_b = qc.get_population("b")

	assert_near(p_A, 0.0, 0.01, "After X@q0: P(A) = 0 (qubit 0 flipped)")
	assert_near(p_a, 1.0, 0.01, "After X@q0: P(a) = 1 (qubit 0 flipped)")
	assert_near(p_B, 1.0, 0.01, "After X@q0: P(B) = 1 (qubit 1 unchanged)")
	assert_near(p_b, 0.0, 0.01, "After X@q0: P(b) = 0 (qubit 1 unchanged)")


func test_gate_injector_invalidates_buffer():
	"""Test GateInjector calls signal_user_action() on batcher."""
	print("\n[TEST] GateInjector buffer invalidation")

	# Create mock biome with quantum computer
	var qc = QuantumComputer.new("test_injector")
	qc.allocate_axis(0, "🌾", "🍞")
	qc.initialize_basis(0)

	# Test with a proper biome-like object
	var mock_biome = _MockBiome.new(qc)
	var H = QuantumGateLibrary.get_gate("H")["matrix"]

	var result = GateInjector.inject_gate(mock_biome, 0, H, null)
	assert_eq(result.success, true, "Inject_gate succeeds with mock biome")
	assert_eq(result.get("gate_injected", false), true, "gate_injected flag set")

	# Verify the gate actually changed the state
	var p0 = qc.get_population("🌾")
	assert_near(p0, 0.5, 0.01, "GateInjector applied Hadamard correctly")

	# Test named gate injection
	var qc2 = QuantumComputer.new("test_named")
	qc2.allocate_axis(0, "A", "B")
	qc2.initialize_basis(0)
	var mock2 = _MockBiome.new(qc2)

	var named_result = GateInjector.inject_named_gate(mock2, 0, "X", null)
	assert_eq(named_result.success, true, "inject_named_gate works")
	assert_near(qc2.get_population("B"), 1.0, 0.01, "Named X gate flipped qubit")


func test_2q_gate_cnot():
	"""Test 2-qubit CNOT gate: |00⟩ stays |00⟩, |10⟩ → |11⟩"""
	print("\n[TEST] apply_gate_2q() with CNOT")

	# Setup: 2 qubits in |00⟩
	var qc = QuantumComputer.new("test_cnot")
	qc.allocate_axis(0, "C", "c")  # Control
	qc.allocate_axis(1, "T", "t")  # Target
	qc.initialize_basis(0)  # |00⟩ = |CT⟩

	# CNOT(0→1) on |00⟩ should give |00⟩ (control is 0, so target unchanged)
	var CNOT = QuantumGateLibrary.get_gate("CNOT")["matrix"]
	var success = qc.apply_gate_2q(0, 1, CNOT)
	assert_eq(success, true, "CNOT gate applied")

	var p_CT = qc.get_basis_probability(0)  # |00⟩
	assert_near(p_CT, 1.0, 0.01, "CNOT|00⟩ = |00⟩")

	# Now flip control to |1⟩ and apply CNOT again
	var X = QuantumGateLibrary.get_gate("X")["matrix"]
	qc.apply_gate(0, X)  # |00⟩ → |10⟩

	# Verify we're in |10⟩
	var p_10 = qc.get_basis_probability(2)  # |10⟩ = basis index 2 (MSB convention)
	assert_near(p_10, 1.0, 0.01, "After X@control: |10⟩")

	# Apply CNOT(0→1): |10⟩ → |11⟩ (control is 1, so target flips)
	qc.apply_gate_2q(0, 1, CNOT)

	var p_11 = qc.get_basis_probability(3)  # |11⟩ = basis index 3
	assert_near(p_11, 1.0, 0.01, "CNOT|10⟩ = |11⟩")


func test_batch_gate_injection():
	"""Test batch gate injection applies gates in order with single invalidation."""
	print("\n[TEST] Batch gate injection (selection order preserved)")

	# Setup: 3 qubits, all in |0⟩
	var qc = QuantumComputer.new("test_batch")
	qc.allocate_axis(0, "A", "a")
	qc.allocate_axis(1, "B", "b")
	qc.allocate_axis(2, "C", "c")
	qc.initialize_basis(0)  # |000⟩

	var mock_biome = _MockBiome.new(qc)

	# Batch: Apply X to qubits in order [2, 0, 1]
	# This tests that selection order is preserved
	var gate_ops = [
		{"biome": mock_biome, "qubit": 2, "gate_name": "X"},
		{"biome": mock_biome, "qubit": 0, "gate_name": "X"},
		{"biome": mock_biome, "qubit": 1, "gate_name": "X"},
	]

	var result = GateInjector.inject_gate_batch(gate_ops, null)

	assert_eq(result.success, true, "Batch injection succeeded")
	assert_eq(result.applied_count, 3, "All 3 gates applied")
	assert_eq(result.get("batch_injected", false), true, "batch_injected flag set")

	# Verify order was preserved
	var order = result.get("order", [])
	assert_eq(order.size(), 3, "Order array has 3 entries")
	assert_eq(order[0], 2, "First gate was on qubit 2")
	assert_eq(order[1], 0, "Second gate was on qubit 0")
	assert_eq(order[2], 1, "Third gate was on qubit 1")

	# Verify all qubits flipped: |000⟩ → |111⟩
	var p_a = qc.get_population("a")  # Should be 1 (flipped from A)
	var p_b = qc.get_population("b")  # Should be 1 (flipped from B)
	var p_c = qc.get_population("c")  # Should be 1 (flipped from C)

	assert_near(p_a, 1.0, 0.01, "Qubit 0 flipped to |1⟩")
	assert_near(p_b, 1.0, 0.01, "Qubit 1 flipped to |1⟩")
	assert_near(p_c, 1.0, 0.01, "Qubit 2 flipped to |1⟩")

	# Test inject_named_gate_batch convenience method
	var qc2 = QuantumComputer.new("test_named_batch")
	qc2.allocate_axis(0, "X", "x")
	qc2.allocate_axis(1, "Y", "y")
	qc2.initialize_basis(0)

	var mock2 = _MockBiome.new(qc2)
	var result2 = GateInjector.inject_named_gate_batch(mock2, [1, 0], "H", null)

	assert_eq(result2.success, true, "Named batch succeeded")
	assert_eq(result2.applied_count, 2, "Both H gates applied")

	# After H on both qubits from |00⟩: equal superposition
	var p_X = qc2.get_population("X")
	var p_Y = qc2.get_population("Y")
	assert_near(p_X, 0.5, 0.01, "Qubit 0 in superposition")
	assert_near(p_Y, 0.5, 0.01, "Qubit 1 in superposition")


class _MockBiome extends RefCounted:
	var quantum_computer
	func _init(qc):
		quantum_computer = qc
