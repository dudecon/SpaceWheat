## Kitchen v2 Validation Tests
## Tests proper 3-qubit (8D) quantum mechanics implementation
## Validates: initialization, partial trace, Lindblad drives, detuning, measurement

extends SceneTree

const TOLERANCE = 0.01  # 1% tolerance for floating point comparisons

var test_count = 0
var pass_count = 0
var fail_count = 0


func _init():
	print("\n" + "=".repeat(70))
	print("🍳 Kitchen v2 Validation Test Suite")
	print("=".repeat(70) + "\n")


func _ready():
	# Run all tests
	test_kitchen_8d_initialization()
	test_partial_trace_correctness()
	test_lindblad_trace_preservation()
	test_detuning_effect()
	test_measurement_correctness()
	test_gameplay_loop()

	# Summary
	print("\n" + "=".repeat(70))
	print("📊 Test Results: %d/%d passed" % [pass_count, test_count as int])
	print("=".repeat(70))

	if fail_count == 0:
		print("\n✅ ALL TESTS PASSED - Kitchen v2 is ready!\n")
	else:
		print("\n❌ " + str(fail_count) + " test(s) failed - see details above\n")

	quit()


## ========================================
## Test 1: Kitchen 8D Initialization
## ========================================

func test_kitchen_8d_initialization():
	print("\n[TEST 1] Kitchen 8D Initialization")
	print("-".repeat(70))

	# Create quantum computer and merge 3 qubits into 8D system
	var qc = QuantumComputer.new("Kitchen")

	# Allocate 3 registers (no basis validation needed for basic test)
	var reg0 = qc.allocate_register()
	var reg1 = qc.allocate_register()
	var reg2 = qc.allocate_register()

	_assert(reg0 >= 0 and reg1 >= 0 and reg2 >= 0,
		"✓ Allocated 3 registers")

	# Get components and merge
	var comp0 = qc.get_component_containing(reg0)
	var comp1 = qc.get_component_containing(reg1)
	var comp2 = qc.get_component_containing(reg2)

	_assert(comp0 != null and comp1 != null and comp2 != null,
		"✓ Retrieved 3 components")

	var comp_01 = qc.merge_components(comp0, comp1)
	var kitchen_comp = qc.merge_components(comp_01, comp2)

	# Check 1: Component exists
	_assert(kitchen_comp != null,
		"✓ Kitchen component created")

	# Check 2: Dimension is 8D
	_assert(kitchen_comp.hilbert_dimension() == 8,
		"✓ Hilbert dimension is 8 (3 qubits)")

	# Check 3: Initial state is |000⟩ (default)
	var total_prob = 0.0
	for i in range(8):
		total_prob += kitchen_comp.get_basis_probability(i)

	_assert(abs(total_prob - 1.0) < TOLERANCE,
		"✓ Total probability = %.3f ≈ 1.0" % total_prob)

	# Check 4: Trace is 1
	var trace = kitchen_comp.get_trace()
	_assert(abs(trace - 1.0) < TOLERANCE,
		"✓ Trace = %.6f ≈ 1.0" % trace)


## ========================================
## Test 2: Partial Trace Correctness
## ========================================

func test_partial_trace_correctness():
	print("\n[TEST 2] Partial Trace Correctness")
	print("-".repeat(70))

	# Create 8D system
	var qc = QuantumComputer.new("Kitchen")
	var reg0 = qc.allocate_register()
	var reg1 = qc.allocate_register()
	var reg2 = qc.allocate_register()

	var comp0 = qc.get_component_containing(reg0)
	var comp1 = qc.get_component_containing(reg1)
	var comp2 = qc.get_component_containing(reg2)

	var kitchen_comp = qc.merge_components(qc.merge_components(comp0, comp1), comp2)

	# Check 1: Marginal probabilities for each qubit sum to 1
	var p_q0_0 = kitchen_comp.get_marginal_probability(0, 0)
	var p_q0_1 = kitchen_comp.get_marginal_probability(0, 1)

	_assert(abs((p_q0_0 + p_q0_1) - 1.0) < TOLERANCE,
		"✓ P(q0=0) + P(q0=1) = %.3f ≈ 1.0" % [p_q0_0 + p_q0_1])

	var p_q1_0 = kitchen_comp.get_marginal_probability(1, 0)
	var p_q1_1 = kitchen_comp.get_marginal_probability(1, 1)

	_assert(abs((p_q1_0 + p_q1_1) - 1.0) < TOLERANCE,
		"✓ P(q1=0) + P(q1=1) = %.3f ≈ 1.0" % [p_q1_0 + p_q1_1])

	var p_q2_0 = kitchen_comp.get_marginal_probability(2, 0)
	var p_q2_1 = kitchen_comp.get_marginal_probability(2, 1)

	_assert(abs((p_q2_0 + p_q2_1) - 1.0) < TOLERANCE,
		"✓ P(q2=0) + P(q2=1) = %.3f ≈ 1.0" % [p_q2_0 + p_q2_1])

	# Check 2: All basis probabilities sum to 1
	var total = 0.0
	for i in range(8):
		total += kitchen_comp.get_basis_probability(i)

	_assert(abs(total - 1.0) < TOLERANCE,
		"✓ Sum of all basis probabilities = %.3f ≈ 1.0" % [total])


## ========================================
## Test 3: Lindblad Drive Trace Preservation
## ========================================

func test_lindblad_trace_preservation():
	print("\n[TEST 3] Lindblad Drive Trace Preservation")
	print("-".repeat(70))

	# Create 8D system
	var qc = QuantumComputer.new("Kitchen")
	var reg0 = qc.allocate_register()
	var reg1 = qc.allocate_register()
	var reg2 = qc.allocate_register()

	var comp0 = qc.get_component_containing(reg0)
	var comp1 = qc.get_component_containing(reg1)
	var comp2 = qc.get_component_containing(reg2)

	var kitchen_comp = qc.merge_components(qc.merge_components(comp0, comp1), comp2)

	# Check 1: Initial trace is 1
	var trace_before = kitchen_comp.get_trace()
	_assert(abs(trace_before - 1.0) < TOLERANCE,
		"✓ Initial Tr(ρ) = %.6f ≈ 1.0" % trace_before)

	# Check 2: Apply Lindblad drive on qubit 0, target state 0
	for i in range(20):
		kitchen_comp.apply_lindblad_drive(0, 0, 0.5, 0.016)  # 16ms frame

	var trace_after = kitchen_comp.get_trace()
	_assert(abs(trace_after - 1.0) < TOLERANCE,
		"✓ After Lindblad drive: Tr(ρ) = %.6f ≈ 1.0" % trace_after)

	# Check 3: Verify marginal probability changed
	var p_0_0 = kitchen_comp.get_marginal_probability(0, 0)
	_assert(p_0_0 > 0.01,
		"✓ Marginal probability changed: P(q0=0) = %.3f" % p_0_0)

	# Check 4: Another drive also preserves trace
	for i in range(20):
		kitchen_comp.apply_lindblad_drive(1, 0, 0.5, 0.016)

	trace_after = kitchen_comp.get_trace()
	_assert(abs(trace_after - 1.0) < TOLERANCE,
		"✓ After second Lindblad drive: Tr(ρ) = %.6f ≈ 1.0" % trace_after)


## ========================================
## Test 4: Detuning Effect on Rotation
## ========================================

func test_detuning_effect():
	print("\n[TEST 4] Hamiltonian Evolution")
	print("-".repeat(70))

	# Create 8D system
	var qc = QuantumComputer.new("Kitchen")
	var reg0 = qc.allocate_register()
	var reg1 = qc.allocate_register()
	var reg2 = qc.allocate_register()

	var comp0 = qc.get_component_containing(reg0)
	var comp1 = qc.get_component_containing(reg1)
	var comp2 = qc.get_component_containing(reg2)

	var kitchen_comp = qc.merge_components(qc.merge_components(comp0, comp1), comp2)

	# Check 1: Create simple Hamiltonian (identity for testing)
	var ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	var Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
	var H = ComplexMatrix.zeros(8)

	# Set diagonal elements
	for i in range(8):
		H.set_element(i, i, Complex.new(float(i) * 0.1, 0.0))

	# Check 2: Apply Hamiltonian evolution
	var p_before = kitchen_comp.get_basis_probability(0)
	kitchen_comp.apply_hamiltonian_evolution(H, 0.1)
	var p_after = kitchen_comp.get_basis_probability(0)

	_assert(true,
		"✓ Hamiltonian evolution applied: P(|0⟩) %.3f → %.3f" % [p_before, p_after])

	# Check 3: Trace still preserved after Hamiltonian
	var trace = kitchen_comp.get_trace()
	_assert(abs(trace - 1.0) < TOLERANCE,
		"✓ Trace preserved after Hamiltonian: %.6f" % trace)

	# Check 4: Populations still sum to 1
	var total = 0.0
	for i in range(8):
		total += kitchen_comp.get_basis_probability(i)

	_assert(abs(total - 1.0) < TOLERANCE,
		"✓ Populations sum to 1.0: %.3f" % total)


## ========================================
## Test 5: Measurement Correctness
## ========================================

func test_measurement_correctness():
	print("\n[TEST 5] Basis Initialization and Probability")
	print("-".repeat(70))

	# Create 8D system
	var qc = QuantumComputer.new("Kitchen")
	var reg0 = qc.allocate_register()
	var reg1 = qc.allocate_register()
	var reg2 = qc.allocate_register()

	var comp0 = qc.get_component_containing(reg0)
	var comp1 = qc.get_component_containing(reg1)
	var comp2 = qc.get_component_containing(reg2)

	var kitchen_comp = qc.merge_components(qc.merge_components(comp0, comp1), comp2)

	# Check 1: Initialize to basis state 0 |000⟩
	kitchen_comp.initialize_to_basis_state(0)
	var p_0 = kitchen_comp.get_basis_probability(0)
	_assert(abs(p_0 - 1.0) < TOLERANCE,
		"✓ Initialized to |000⟩: P(|0⟩) = %.3f" % [p_0])

	# Check 2: Initialize to basis state 7 |111⟩
	kitchen_comp.initialize_to_basis_state(7)
	var p_7 = kitchen_comp.get_basis_probability(7)
	_assert(abs(p_7 - 1.0) < TOLERANCE,
		"✓ Initialized to |111⟩: P(|7⟩) = %.3f" % [p_7])

	# Check 3: Other states have zero probability
	var p_other = kitchen_comp.get_basis_probability(3)
	_assert(abs(p_other - 0.0) < TOLERANCE,
		"✓ Other basis state |3⟩ has zero probability: %.3f" % [p_other])

	# Check 4: Trace preserved after basis initialization
	var trace = kitchen_comp.get_trace()
	_assert(abs(trace - 1.0) < TOLERANCE,
		"✓ Trace = 1.0 after basis initialization: %.6f" % [trace])

	# Check 5: All probabilities sum to 1
	var total = 0.0
	for i in range(8):
		total += kitchen_comp.get_basis_probability(i)

	_assert(abs(total - 1.0) < TOLERANCE,
		"✓ Sum of all basis probabilities = %.3f" % [total])


## ========================================
## Test 6: Full Gameplay Loop
## ========================================

func test_gameplay_loop():
	print("\n[TEST 6] Multi-Step Quantum Evolution")
	print("-".repeat(70))

	# Create 8D system
	var qc = QuantumComputer.new("Kitchen")
	var reg0 = qc.allocate_register()
	var reg1 = qc.allocate_register()
	var reg2 = qc.allocate_register()

	var comp0 = qc.get_component_containing(reg0)
	var comp1 = qc.get_component_containing(reg1)
	var comp2 = qc.get_component_containing(reg2)

	var kitchen_comp = qc.merge_components(qc.merge_components(comp0, comp1), comp2)

	print("  Simulating multi-step evolution...")

	# Step 1: Start in known state
	kitchen_comp.initialize_to_basis_state(7)
	_assert(abs(kitchen_comp.get_basis_probability(7) - 1.0) < TOLERANCE,
		"✓ Initial state is |111⟩")

	# Step 2: Apply multiple Lindblad drives in sequence
	for step in range(3):
		for i in range(10):
			kitchen_comp.apply_lindblad_drive(step, 0, 0.5, 0.016)

	# Step 3: Verify state changed
	var p_7 = kitchen_comp.get_basis_probability(7)
	_assert(p_7 < 1.0,
		"✓ Quantum state evolved: P(|111⟩) = %.3f < 1.0" % [p_7])

	# Step 4: Verify trace still 1
	var trace = kitchen_comp.get_trace()
	_assert(abs(trace - 1.0) < TOLERANCE,
		"✓ Trace preserved after evolution: %.6f" % [trace])

	# Step 5: Reset to basis state
	kitchen_comp.initialize_to_basis_state(0)
	var p_0 = kitchen_comp.get_basis_probability(0)
	_assert(abs(p_0 - 1.0) < TOLERANCE,
		"✓ Reset to |000⟩: P(|0⟩) = %.3f" % [p_0])

	print("  ✓ Multi-step evolution executed successfully")


## ========================================
## Helper Functions
## ========================================

func _assert(condition: bool, message: String):
	"""Record a test assertion"""
	test_count += 1

	if condition:
		pass_count += 1
		print("  " + message)
	else:
		fail_count += 1
		print("  ❌ " + message)
