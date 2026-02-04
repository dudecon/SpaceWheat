extends SceneTree

## Quick verification script for native engines
## Usage: godot --headless -s verify_native_engines.gd

func _init():
	print("\n" + "=".repeat(60))
	print("NATIVE ENGINE VERIFICATION")
	print("=".repeat(60))

	# Check class registration
	var classes = {
		"QuantumMatrixNative": ClassDB.class_exists("QuantumMatrixNative"),
		"QuantumEvolutionEngine": ClassDB.class_exists("QuantumEvolutionEngine"),
		"MultiBiomeLookaheadEngine": ClassDB.class_exists("MultiBiomeLookaheadEngine"),
		"ForceGraphEngine": ClassDB.class_exists("ForceGraphEngine")
	}

	print("\nClass Registration:")
	for class_name in classes.keys():
		var status = "✓" if classes[class_name] else "✗"
		print("  %s %s" % [status, class_name])

	# Try to instantiate each
	print("\nInstantiation Tests:")
	for class_name in classes.keys():
		if classes[class_name]:
			var obj = ClassDB.instantiate(class_name)
			if obj:
				print("  ✓ %s instantiated successfully" % class_name)
				obj.free()
			else:
				print("  ✗ %s failed to instantiate" % class_name)

	# Summary
	var registered_count = 0
	for registered in classes.values():
		if registered:
			registered_count += 1

	print("\n" + "=".repeat(60))
	print("RESULT: %d/%d classes registered" % [registered_count, classes.size()])

	if registered_count == 4:
		print("✅ All native engines available!")
	elif registered_count >= 2:
		print("⚠️  Partial success - evolution engines ready, force graph pending")
	else:
		print("❌ Native engines not available")

	print("=".repeat(60) + "\n")

	quit()
