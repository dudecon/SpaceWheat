extends SceneTree

## Test Eigenstate Solver - Verify C++ eigenstate computation works
## Usage: godot --headless --script test_eigenstate_solver.gd

func _initialize():
	print("=== Eigenstate Solver Test ===")
	print("")

	# Check if QuantumEvolutionEngine is available
	if not ClassDB.class_exists("QuantumEvolutionEngine"):
		print("ERROR: QuantumEvolutionEngine not available!")
		print("Make sure native library is built: cd native && scons")
		quit(1)
		return

	print("QuantumEvolutionEngine found!")

	# Create engine instance
	var engine = ClassDB.instantiate("QuantumEvolutionEngine")
	if not engine:
		print("ERROR: Failed to instantiate QuantumEvolutionEngine")
		quit(1)
		return

	print("Engine instantiated!")

	# Test with a simple 2x2 density matrix (qubit in |0⟩ state)
	var dim = 2
	engine.set_dimension(dim)
	engine.finalize()

	# Create density matrix for |0⟩⟨0| = [[1,0],[0,0]]
	# Packed as [re00, im00, re01, im01, re10, im10, re11, im11]
	var rho_pure = PackedFloat64Array([1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])

	print("")
	print("Test 1: Pure state |0⟩")
	_test_eigenstate(engine, rho_pure, "pure |0⟩")

	# Test with mixed state ρ = 0.7|0⟩⟨0| + 0.3|1⟩⟨1|
	var rho_mixed = PackedFloat64Array([0.7, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.0])

	print("")
	print("Test 2: Mixed state (0.7|0⟩ + 0.3|1⟩)")
	_test_eigenstate(engine, rho_mixed, "mixed")

	# Test with 4x4 (2-qubit) state
	engine.set_dimension(4)
	engine.finalize()

	# Bell state |Φ+⟩ = (|00⟩ + |11⟩)/√2
	# ρ = |Φ+⟩⟨Φ+| has non-zero elements at (0,0), (0,3), (3,0), (3,3)
	var rho_bell = PackedFloat64Array()
	rho_bell.resize(32)  # 4x4 complex = 32 floats
	for i in range(32):
		rho_bell[i] = 0.0
	# Set [0,0] = 0.5
	rho_bell[0] = 0.5
	# Set [0,3] = 0.5
	rho_bell[6] = 0.5
	# Set [3,0] = 0.5
	rho_bell[24] = 0.5
	# Set [3,3] = 0.5
	rho_bell[30] = 0.5

	print("")
	print("Test 3: Bell state |Φ+⟩ (2 qubits)")
	_test_eigenstate(engine, rho_bell, "Bell |Φ+⟩")

	# Test similarity between two states
	print("")
	print("Test 4: Similarity computation")
	var state_a = PackedFloat64Array([1.0, 0.0, 0.0, 0.0])  # |0⟩
	var state_b = PackedFloat64Array([0.0, 0.0, 1.0, 0.0])  # |1⟩
	var state_c = PackedFloat64Array([0.7071, 0.0, 0.7071, 0.0])  # |+⟩ ≈ (|0⟩+|1⟩)/√2

	var sim_ab = engine.compute_cos2_similarity(state_a, state_b)
	var sim_aa = engine.compute_cos2_similarity(state_a, state_a)
	var sim_ac = engine.compute_cos2_similarity(state_a, state_c)

	print("  cos²(|0⟩, |0⟩) = %.4f (expected: 1.0)" % sim_aa)
	print("  cos²(|0⟩, |1⟩) = %.4f (expected: 0.0)" % sim_ab)
	print("  cos²(|0⟩, |+⟩) = %.4f (expected: 0.5)" % sim_ac)

	print("")
	print("=== All Tests Complete ===")
	quit(0)


func _test_eigenstate(engine, rho_packed: PackedFloat64Array, label: String):
	"""Test eigenstate computation on a density matrix."""

	# Test compute_eigenstates
	var result = engine.compute_eigenstates(rho_packed)

	if result.has("error"):
		print("  ERROR: %s" % result["error"])
		return

	var eigenvalues = result.get("eigenvalues", PackedFloat64Array())
	var dominant_vec = result.get("dominant_eigenvector", PackedFloat64Array())
	var dominant_val = result.get("dominant_eigenvalue", 0.0)
	var dim = result.get("dimension", 0)

	print("  Dimension: %d" % dim)
	print("  Dominant eigenvalue: %.6f" % dominant_val)

	print("  All eigenvalues (descending):", eigenvalues)

	# Print dominant eigenvector (first few components)
	var vec_str = "  Dominant eigenvector: ["
	var num_show = min(4, dim)
	for i in range(num_show):
		var re = dominant_vec[i * 2]
		var im = dominant_vec[i * 2 + 1]
		if abs(im) < 1e-6:
			vec_str += "%.4f" % re
		else:
			vec_str += "(%.4f%+.4fi)" % [re, im]
		if i < num_show - 1:
			vec_str += ", "
	if dim > num_show:
		vec_str += ", ..."
	vec_str += "]"
	print(vec_str)

	# Compute purity
	var purity = engine.compute_purity_from_packed(rho_packed)
	print("  Purity: %.6f" % purity)

	# Verify: for pure states, purity ≈ 1 and dominant eigenvalue ≈ 1
	if abs(purity - 1.0) < 0.01 and abs(dominant_val - 1.0) < 0.01:
		print("  ✓ Pure state verified")
	elif purity < 1.0:
		print("  ✓ Mixed state (purity < 1)")
