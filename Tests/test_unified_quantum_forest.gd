extends SceneTree

func _init():
	print("\n=== TEST: Forest Unified Quantum (5 qubits) ===")

	var Forest = load("res://Core/Environment/ForestEcosystem_Biome.gd")
	var biome = Forest.new()
	biome._ready()

	print("✓ Forest loaded")
	print("  quantum_computer: ", biome.quantum_computer != null)
	print("  bath (deprecated): ", biome.bath)

	if not biome.quantum_computer:
		print("❌ FAILED: No quantum_computer!")
		quit(1)

	var num_qubits = biome.quantum_computer.register_map.num_qubits
	var dim = biome.quantum_computer.register_map.dim()
	print("  Qubits: ", num_qubits)
	print("  Dimension: ", dim)

	# Check all 10 registered emojis
	print("\n🌲 Checking emoji registration:")
	var emojis = ["☀", "🌙", "🌿", "🍂", "🐇", "🐺", "💧", "🔥", "🌲", "🏡"]
	for emoji in emojis:
		if biome.quantum_computer.register_map.has(emoji):
			var coord = biome.quantum_computer.register_map.qubit(emoji)
			var pole = biome.quantum_computer.register_map.pole(emoji)
			print("  ✓ %s → qubit %d, pole %d" % [emoji, coord, pole])
		else:
			print("  ✗ %s not registered" % emoji)

	# Get initial populations
	var v0 = biome.get_vegetation_level()
	var pred0 = biome.get_predator_level()
	var prey0 = biome.get_prey_level()
	var w0 = biome.get_water_level()

	print("\n📊 Initial ecosystem:")
	print("  Vegetation P(🌿) = %.3f" % v0)
	print("  Predator P(🐺) = %.3f" % pred0)
	print("  Prey P(🐇) = %.3f" % prey0)
	print("  Water P(💧) = %.3f" % w0)

	# Evolve
	print("\n⏱️ Evolving for 3 seconds...")
	for i in range(30):
		biome.advance_simulation(0.1)

	var v1 = biome.get_vegetation_level()
	var pred1 = biome.get_predator_level()
	var prey1 = biome.get_prey_level()
	var w1 = biome.get_water_level()

	print("📊 After evolution:")
	print("  Vegetation P(🌿) = %.3f (Δ=%.3f)" % [v1, v1 - v0])
	print("  Predator P(🐺) = %.3f (Δ=%.3f)" % [pred1, pred1 - pred0])
	print("  Prey P(🐇) = %.3f (Δ=%.3f)" % [prey1, prey1 - prey0])
	print("  Water P(💧) = %.3f (Δ=%.3f)" % [w1, w1 - w0])

	var health = biome.get_forest_health()
	print("\n🌳 Forest health: %.1f%%" % (health * 100))

	print("\n✅ Forest TEST PASSED")
	quit()
