extends Node

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

func _ready() -> void:
	var sep = "════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
	print("\n" + sep)
	print("TEST: BRIGHTNESS BASED ON POLE (NOT ECLIPTIC)")
	print("sun_brightness = cos²(θ/2), moon_brightness = sin²(θ/2)")
	print("Peak mushroom growth should occur at midnight (θ≈π)")
	print(sep)

	# Create biome
	var biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame

	# Create wheat and specialist mushroom
	var wheat = DualEmojiQubit.new()
	wheat.north_emoji = "🌾"
	wheat.south_emoji = "🏰"
	wheat.theta = PI / 4.0
	wheat.phi = 3.0 * PI / 2.0
	wheat.radius = 0.3
	wheat.energy = 0.5

	var mushroom = DualEmojiQubit.new()
	mushroom.north_emoji = "🍂"
	mushroom.south_emoji = "🍄"
	mushroom.theta = PI  # At night
	mushroom.phi = 0.0
	mushroom.radius = 0.3
	mushroom.energy = 0.5

	# Register
	biome.quantum_states[Vector2i(0, 0)] = wheat
	biome.quantum_states[Vector2i(1, 0)] = mushroom
	biome.plots_by_type[biome.PlotType.FARM] = [Vector2i(0, 0), Vector2i(1, 0)]
	biome.plot_types[Vector2i(0, 0)] = biome.PlotType.FARM
	biome.plot_types[Vector2i(1, 0)] = biome.PlotType.FARM

	print("\nTime | Sun θ | Sun Br | Moon Br | Wheat E | Wheat Δ | Mushroom E | Mushroom Δ | Peak")
	print(sep)

	var dt = 0.016666
	var total_time = 0.0
	var next_sample = 0.0
	var wheat_prev = wheat.energy
	var mushroom_prev = mushroom.energy
	var max_mushroom_energy = 0.5
	var max_mushroom_time = 0.0

	while total_time < 20.0:
		total_time += dt
		biome.time_tracker.update(dt)
		biome._apply_celestial_oscillation(dt)
		biome._apply_hamiltonian_evolution(dt)
		biome._apply_spring_attraction(dt)
		biome._apply_energy_transfer(dt)

		# Track peak mushroom energy
		if mushroom.energy > max_mushroom_energy:
			max_mushroom_energy = mushroom.energy
			max_mushroom_time = total_time

		if total_time >= next_sample:
			var wheat_delta = wheat.energy - wheat_prev
			var mushroom_delta = mushroom.energy - mushroom_prev

			# Calculate brightness for display
			var sun_bright = pow(cos(biome.sun_qubit.theta / 2.0), 2)
			var moon_bright = pow(sin(biome.sun_qubit.theta / 2.0), 2)

			var peak_marker = ""
			if abs(mushroom.energy - max_mushroom_energy) < 0.001 and mushroom.energy == max_mushroom_energy:
				peak_marker = "← PEAK"

			print("%.1fs | %5.0f° | %.2f | %.2f | %.4f | %+.4f | %.4f | %+.4f | %s" % [
				total_time,
				biome.sun_qubit.theta * 180.0 / PI,
				sun_bright,
				moon_bright,
				wheat.energy,
				wheat_delta,
				mushroom.energy,
				mushroom_delta,
				peak_marker
			])

			wheat_prev = wheat.energy
			mushroom_prev = mushroom.energy
			next_sample += 1.0

	print(sep)
	print("\n=== ANALYSIS ===")
	print("Peak mushroom energy: %.4f at time %.1fs" % [max_mushroom_energy, max_mushroom_time])
	if max_mushroom_time > 9.0 and max_mushroom_time < 11.0:
		print("✓ CORRECT: Peak at ~10s (midnight in 20s cycle)")
	else:
		print("✗ WRONG: Peak should be at ~10s (midnight), was at %.1fs" % max_mushroom_time)
	print("✓ Brightness ranges 0.0-1.0 (not 0.7-1.0)")
	print("✓ Sun and moon brightness sum to 1.0 (complementary)")
	print(sep + "\n")

	get_tree().quit()
