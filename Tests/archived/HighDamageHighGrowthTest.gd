extends Node

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

func _ready() -> void:
	var sep = "════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
	print("\n" + sep)
	print("TEST: INCREASED DAMAGE & 2X WHEAT GROWTH")
	print("Sun damage 4x (0.05→0.20), Wheat energy 2x (0.017→0.034)")
	print(sep)

	# Create biome
	var biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame

	print("\n🌾 Wheat energy influence: %.3f (was 0.017)" % biome.wheat_energy_influence)
	print("Testing with sun damage coefficient 0.20x (4x higher than before)\n")

	# Create wheat and mushroom at opposite poles
	var wheat = DualEmojiQubit.new()
	wheat.north_emoji = "🌾"
	wheat.south_emoji = "🏰"
	wheat.theta = PI / 4.0  # Near sun position
	wheat.phi = 3.0 * PI / 2.0
	wheat.radius = 0.3
	wheat.energy = 0.5

	var mushroom = DualEmojiQubit.new()
	mushroom.north_emoji = "🍂"
	mushroom.south_emoji = "🍄"
	mushroom.theta = PI  # At moon position (opposite of sun)
	mushroom.phi = 0.0
	mushroom.radius = 0.3
	mushroom.energy = 0.5

	# Register qubits
	biome.quantum_states[Vector2i(0, 0)] = wheat
	biome.quantum_states[Vector2i(1, 0)] = mushroom
	biome.plots_by_type[biome.PlotType.FARM] = [Vector2i(0, 0), Vector2i(1, 0)]
	biome.plot_types[Vector2i(0, 0)] = biome.PlotType.FARM
	biome.plot_types[Vector2i(1, 0)] = biome.PlotType.FARM

	print("Time  | Sun θ  | Wheat E | Wheat Δ | Mushroom E | Mushroom Δ | Notes")
	print(sep)

	var dt = 0.016666
	var total_time = 0.0
	var next_sample = 0.0
	var wheat_prev = wheat.energy
	var mushroom_prev = mushroom.energy

	while total_time < 20.0:
		total_time += dt
		biome.time_tracker.update(dt)
		biome._apply_celestial_oscillation(dt)
		biome._apply_hamiltonian_evolution(dt)
		biome._apply_spring_attraction(dt)
		biome._apply_energy_transfer(dt)

		if total_time >= next_sample:
			var wheat_delta = wheat.energy - wheat_prev
			var mushroom_delta = mushroom.energy - mushroom_prev
			var notes = ""

			if total_time < 10.0:
				if wheat_delta > 0.02:
					notes = "Wheat growing strong ✓"
				if mushroom_delta < -0.02:
					notes = "Mushroom wilting ✓"
			else:
				if mushroom_delta > 0.02:
					notes = "Mushroom recovering ✓"

			print("%.1fs | %5.0f° | %.4f | %+.4f | %.4f | %+.4f | %s" % [
				total_time,
				biome.sun_qubit.theta * 180.0 / PI,
				wheat.energy,
				wheat_delta,
				mushroom.energy,
				mushroom_delta,
				notes
			])

			wheat_prev = wheat.energy
			mushroom_prev = mushroom.energy
			next_sample += 1.0

	print(sep)
	print("\n=== RESULTS ===")
	print("Wheat final: %.4f (started 0.5000)" % wheat.energy)
	print("Mushroom final: %.4f (started 0.5000)" % mushroom.energy)
	print("✓ Wheat should show stronger growth with 2x energy influence")
	print("✓ Mushroom should show wilting when sun-opposite then recovery when sun-aligned")
	print(sep + "\n")

	get_tree().quit()
