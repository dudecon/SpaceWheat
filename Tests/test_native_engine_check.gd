extends SceneTree

func _init():
	print("Checking native classes...")

	print("  QuantumEvolutionEngine: %s" % str(ClassDB.class_exists("QuantumEvolutionEngine")))
	print("  QuantumSparseNative: %s" % str(ClassDB.class_exists("QuantumSparseNative")))

	if ClassDB.class_exists("QuantumEvolutionEngine"):
		print("  Attempting instantiation...")
		var engine = ClassDB.instantiate("QuantumEvolutionEngine")
		if engine:
			print("  ✓ Successfully created QuantumEvolutionEngine")
			engine.set_dimension(32)
			print("  ✓ Set dimension to 32")
		else:
			print("  ✗ Failed to instantiate")

	quit()
