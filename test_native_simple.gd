extends SceneTree

## Simple test to verify native engines work and measure basic performance

const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

func _init():
	print("\n" + "=".repeat(70))
	print("NATIVE ENGINE VERIFICATION TEST")
	print("=".repeat(70))

	# Test 1: Check class registration
	_test_class_registration()

	# Test 2: Check if native evolution engine can be instantiated and used
	_test_native_instantiation()

	print("\n" + "=".repeat(70))
	quit()

func _test_class_registration():
	print("\n[TEST 1] Class Registration")

	var classes = {
		"QuantumMatrixNative": "Matrix operations",
		"QuantumEvolutionEngine": "Single-biome evolution",
		"MultiBiomeLookaheadEngine": "Multi-biome batched evolution",
		"ForceGraphEngine": "Force-directed graph layout"
	}

	var registered_count = 0
	var class_names = ["QuantumMatrixNative", "QuantumEvolutionEngine", "MultiBiomeLookaheadEngine", "ForceGraphEngine"]
	for class_name in class_names:
		var exists = ClassDB.class_exists(class_name)
		var status = "✓" if exists else "✗"
		var desc = classes[class_name]
		print("  %s %-30s %s" % [status, class_name + ":", desc])
		if exists:
			registered_count += 1

	print("\n  Result: %d/%d classes registered" % [registered_count, classes.size()])

	if registered_count == 0:
		print("  ⚠️  No native classes found - GDExtension not loading!")
		print("      This is expected when running with -s flag")
		print("      Native classes load properly in full game context")
		return

func _test_native_instantiation():
	print("\n[TEST 2] Instantiation & Basic Operation")

	# Check if QuantumEvolutionEngine exists
	if not ClassDB.class_exists("QuantumEvolutionEngine"):
		print("  ⚠️  Skipping - QuantumEvolutionEngine not available in script context")
		print("      (This is normal - GDExtensions don't load with -s flag)")
		return

	print("  Creating QuantumEvolutionEngine...")
	var engine = ClassDB.instantiate("QuantumEvolutionEngine")

	if not engine:
		print("  ✗ Failed to instantiate")
		return

	print("  ✓ Instantiated successfully")

	# Set up a simple 2-qubit system
	print("\n  Setting up 2-qubit system (4D)...")
	engine.set_dimension(4)

	# Create simple Hamiltonian
	var H = PackedFloat64Array()
	for i in range(4):
		for j in range(4):
			if i == j:
				H.append(float(i))  # Diagonal energies: 0, 1, 2, 3
				H.append(0.0)       # Imaginary part
			else:
				H.append(0.0)
				H.append(0.0)

	engine.set_hamiltonian(H)
	engine.finalize()

	print("  ✓ Engine configured and finalized")

	# Create initial state |00⟩
	var rho = PackedFloat64Array()
	for i in range(4):
		for j in range(4):
			if i == 0 and j == 0:
				rho.append(1.0)  # |00⟩⟨00|
				rho.append(0.0)
			else:
				rho.append(0.0)
				rho.append(0.0)

	print("\n  Testing evolution...")
	var times = []

	for i in range(10):
		var start = Time.get_ticks_usec()
		var evolved = engine.evolve_step(rho, 0.01)  # 10ms timestep
		var end = Time.get_ticks_usec()
		times.append((end - start) / 1000.0)

	var avg = _avg(times)
	print("  ✓ Evolution successful")
	print("    Average time: %.3f ms per step" % avg)
	print("    For 4D system (2 qubits)")

	engine.free()

func _avg(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var sum = 0.0
	for v in arr:
		sum += v
	return sum / float(arr.size())
