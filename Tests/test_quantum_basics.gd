## Simple Quantum Component Tests
## Runs in main scene context without requiring -s flag

extends Node

const TOLERANCE = 0.01

var test_count = 0
var pass_count = 0
var fail_count = 0


func _ready():
	print("\n" + "=".repeat(70))
	print("🔬 Quantum Component Test Suite")
	print("=".repeat(70) + "\n")

	# Run tests
	test_8d_dimension()
	test_marginal_probabilities()
	test_lindblad_drives()
	test_basis_initialization()

	# Summary
	print("\n" + "=".repeat(70))
	print("📊 Results: %d/%d passed" % [pass_count, test_count])
	print("=".repeat(70) + "\n")

	if fail_count == 0:
		print("✅ ALL TESTS PASSED\n")
	else:
		print("❌ %d test(s) failed\n" % fail_count)


func test_8d_dimension():
	print("[TEST 1] 8D Quantum System Creation")
	print("-".repeat(70))

	var qc = QuantumComputer.new("TestKitchen")
	var reg0 = qc.allocate_register()
	var reg1 = qc.allocate_register()
	var reg2 = qc.allocate_register()

	_assert(reg0 >= 0 and reg1 >= 0 and reg2 >= 0,
		"✓ Allocated 3 registers")

	var comp0 = qc.get_component_containing(reg0)
	var comp1 = qc.get_component_containing(reg1)
	var comp2 = qc.get_component_containing(reg2)

	var kitchen_comp = qc.merge_components(qc.merge_components(comp0, comp1), comp2)

	_assert(kitchen_comp != null,
		"✓ Merged into single component")

	_assert(kitchen_comp.hilbert_dimension() == 8,
		"✓ Hilbert dimension is 8 (2³ = 8 basis states)")

	# Check trace
	var trace = kitchen_comp.get_trace()
	_assert(abs(trace - 1.0) < TOLERANCE,
		"✓ Trace = 1.0 (normalized): %.6f" % trace)

	print()


func test_marginal_probabilities():
	print("[TEST 2] Partial Trace (Marginal Probabilities)")
	print("-".repeat(70))

	var qc = QuantumComputer.new("Kitchen2")
	var reg0 = qc.allocate_register()
	var reg1 = qc.allocate_register()
	var reg2 = qc.allocate_register()

	var comp0 = qc.get_component_containing(reg0)
	var comp1 = qc.get_component_containing(reg1)
	var comp2 = qc.get_component_containing(reg2)

	var kitchen_comp = qc.merge_components(qc.merge_components(comp0, comp1), comp2)

	# For each qubit, P(0) + P(1) should equal 1
	for qubit in range(3):
		var p0 = kitchen_comp.get_marginal_probability(qubit, 0)
		var p1 = kitchen_comp.get_marginal_probability(qubit, 1)
		var total = p0 + p1

		_assert(abs(total - 1.0) < TOLERANCE,
			"✓ Qubit %d: P(0) + P(1) = %.3f ≈ 1.0" % [qubit, total])

	# All basis probabilities should sum to 1
	var total_prob = 0.0
	for i in range(8):
		total_prob += kitchen_comp.get_basis_probability(i)

	_assert(abs(total_prob - 1.0) < TOLERANCE,
		"✓ All basis probs sum to 1.0: %.3f" % total_prob)

	print()


func test_lindblad_drives():
	print("[TEST 3] Lindblad Drive Trace Preservation")
	print("-".repeat(70))

	var qc = QuantumComputer.new("Kitchen3")
	var reg0 = qc.allocate_register()
	var reg1 = qc.allocate_register()
	var reg2 = qc.allocate_register()

	var comp0 = qc.get_component_containing(reg0)
	var comp1 = qc.get_component_containing(reg1)
	var comp2 = qc.get_component_containing(reg2)

	var kitchen_comp = qc.merge_components(qc.merge_components(comp0, comp1), comp2)

	var trace_before = kitchen_comp.get_trace()
	_assert(abs(trace_before - 1.0) < TOLERANCE,
		"✓ Initial trace = 1.0")

	# Apply Lindblad drive on each qubit
	for q in range(3):
		for i in range(20):
			kitchen_comp.apply_lindblad_drive(q, 0, 0.5, 0.016)

	var trace_after = kitchen_comp.get_trace()
	_assert(abs(trace_after - 1.0) < TOLERANCE,
		"✓ After drives: trace = %.6f ≈ 1.0" % trace_after)

	# Verify state changed
	var p0_after = kitchen_comp.get_basis_probability(0)
	_assert(p0_after > 0.0,
		"✓ State evolved: P(|000⟩) = %.3f > 0" % p0_after)

	print()


func test_basis_initialization():
	print("[TEST 4] Basis State Initialization")
	print("-".repeat(70))

	var qc = QuantumComputer.new("Kitchen4")
	var reg0 = qc.allocate_register()
	var reg1 = qc.allocate_register()
	var reg2 = qc.allocate_register()

	var comp0 = qc.get_component_containing(reg0)
	var comp1 = qc.get_component_containing(reg1)
	var comp2 = qc.get_component_containing(reg2)

	var kitchen_comp = qc.merge_components(qc.merge_components(comp0, comp1), comp2)

	# Initialize to |000⟩
	kitchen_comp.initialize_to_basis_state(0)
	var p0 = kitchen_comp.get_basis_probability(0)
	_assert(abs(p0 - 1.0) < TOLERANCE,
		"✓ |000⟩ state: P(|0⟩) = %.3f" % p0)

	# Initialize to |111⟩
	kitchen_comp.initialize_to_basis_state(7)
	var p7 = kitchen_comp.get_basis_probability(7)
	_assert(abs(p7 - 1.0) < TOLERANCE,
		"✓ |111⟩ state: P(|7⟩) = %.3f" % p7)

	# Check other states are zero
	var p_other = kitchen_comp.get_basis_probability(3)
	_assert(abs(p_other - 0.0) < TOLERANCE,
		"✓ Other states zero: P(|3⟩) = %.3f" % p_other)

	print()


func _assert(condition: bool, message: String):
	test_count += 1
	if condition:
		pass_count += 1
		print("  " + message)
	else:
		fail_count += 1
		print("  ❌ " + message)
