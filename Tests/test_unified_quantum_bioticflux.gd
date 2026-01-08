extends SceneTree

func _init():
	print("\n=== TEST: BioticFlux Unified Quantum ===")

	# Load biome
	var BioticFlux = load("res://Core/Environment/BioticFluxBiome.gd")
	var biome = BioticFlux.new()
	biome._ready()

	print("✓ BioticFlux loaded")
	print("  quantum_computer: ", biome.quantum_computer != null)
	print("  bath (deprecated): ", biome.bath)

	if not biome.quantum_computer:
		print("❌ FAILED: No quantum_computer!")
		quit(1)

	# Check qubits
	var num_qubits = biome.quantum_computer.register_map.num_qubits
	var dim = biome.quantum_computer.register_map.dim()
	print("  Qubits: ", num_qubits)
	print("  Dimension: ", dim)

	# Plant a plot
	var plot_pos = Vector2i(0, 0)
	var subplot_id = biome.allocate_subplot_for_plot(plot_pos, "🌾", "🍄")
	print("\n✓ Planted wheat plot")
	print("  Subplot ID: ", subplot_id)

	# Get initial populations
	var p_wheat_0 = biome.quantum_computer.get_population("🌾")
	var p_mushroom_0 = biome.quantum_computer.get_population("🍄")
	print("\n📊 Initial populations:")
	print("  P(🌾) = %.3f" % p_wheat_0)
	print("  P(🍄) = %.3f" % p_mushroom_0)

	# Evolve
	print("\n⏱️ Evolving for 1 second...")
	for i in range(10):
		biome.advance_simulation(0.1)

	# Check populations after evolution
	var p_wheat_1 = biome.quantum_computer.get_population("🌾")
	var p_mushroom_1 = biome.quantum_computer.get_population("🍄")
	print("📊 After evolution:")
	print("  P(🌾) = %.3f (Δ=%.3f)" % [p_wheat_1, p_wheat_1 - p_wheat_0])
	print("  P(🍄) = %.3f (Δ=%.3f)" % [p_mushroom_1, p_mushroom_1 - p_mushroom_0])

	# Measure
	if biome.quantum_computer.has_method("measure_axis"):
		print("\n🎲 Measuring axis...")
		var outcome = biome.quantum_computer.measure_axis("🌾", "🍄")
		print("  Outcome: ", outcome)

		var p_wheat_2 = biome.quantum_computer.get_population("🌾")
		var p_mushroom_2 = biome.quantum_computer.get_population("🍄")
		print("📊 Post-measurement:")
		print("  P(🌾) = %.3f (collapsed)" % p_wheat_2)
		print("  P(🍄) = %.3f (collapsed)" % p_mushroom_2)

	print("\n✅ BioticFlux TEST PASSED")
	quit()
