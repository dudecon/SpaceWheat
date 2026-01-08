extends SceneTree

## Phase 2 test: Verify gated Lindblad integration

func _init():
	print("=== Phase 2: Testing Gated Lindblad Integration ===")

	# Test 1: Verify LindbladBuilder returns new format
	print("\n--- Test 1: LindbladBuilder Return Format ---")
	var LindbladBuilder = load("res://Core/QuantumSubstrate/LindbladBuilder.gd")
	var RegisterMap = load("res://Core/QuantumSubstrate/RegisterMap.gd")
	var IconRegistry = load("res://Core/QuantumSubstrate/IconRegistry.gd")

	if LindbladBuilder:
		print("✓ LindbladBuilder loaded")
	else:
		print("✗ LindbladBuilder failed to load")
		quit()
		return

	# Test 2: Verify QuantumComputer has gated_lindblad_configs
	print("\n--- Test 2: QuantumComputer Gated Configs ---")
	var QuantumComputer = load("res://Core/QuantumSubstrate/QuantumComputer.gd")
	if QuantumComputer:
		var qc = QuantumComputer.new("test")
		if "gated_lindblad_configs" in qc:
			print("✓ QuantumComputer has gated_lindblad_configs property")
		else:
			print("✗ QuantumComputer missing gated_lindblad_configs")
	else:
		print("✗ QuantumComputer failed to load")

	# Test 3: Check LindbladBuilder.build returns Dictionary
	print("\n--- Test 3: LindbladBuilder.build Return Type ---")
	var register_map = RegisterMap.new()
	register_map.register_axis(0, "🌾", "💨")
	register_map.register_axis(1, "🔥", "❄️")

	var icons = {}  # Empty icons for minimal test
	var result = LindbladBuilder.build(icons, register_map)

	if result is Dictionary:
		print("✓ LindbladBuilder.build returns Dictionary")
		if result.has("operators"):
			print("  ✓ Has 'operators' key")
		else:
			print("  ✗ Missing 'operators' key")
		if result.has("gated_configs"):
			print("  ✓ Has 'gated_configs' key")
		else:
			print("  ✗ Missing 'gated_configs' key")
	else:
		print("✗ LindbladBuilder.build does not return Dictionary")

	print("\n=== Phase 2 Tests Complete ===")
	quit()
