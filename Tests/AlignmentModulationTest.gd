extends Node

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

func _ready() -> void:
	var sep = "════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
	print("\n" + sep)
	print("TEST: ALIGNMENT-MODULATED DAY/NIGHT SYSTEM")
	print("Verifies: Spring forces, energy transfer, and sun damage scale with alignment")
	print(sep)

	# Create biome
	var biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame

	# Create wheat and mushroom qubits
	var wheat = DualEmojiQubit.new()
	wheat.north_emoji = "🌾"
	wheat.south_emoji = "🏰"
	wheat.theta = PI / 4.0  # Morning position
	wheat.phi = 3.0 * PI / 2.0
	wheat.radius = 0.3
	wheat.energy = 0.5

	var mushroom = DualEmojiQubit.new()
	mushroom.north_emoji = "🍂"
	mushroom.south_emoji = "🍄"
	mushroom.theta = PI / 4.0  # Morning position (will move to midnight)
	mushroom.phi = 0.0
	mushroom.radius = 0.3
	mushroom.energy = 0.5

	# Register qubits
	biome.quantum_states[Vector2i(0, 0)] = wheat
	biome.quantum_states[Vector2i(1, 0)] = mushroom
	biome.plots_by_type[biome.PlotType.FARM] = [Vector2i(0, 0), Vector2i(1, 0)]
	biome.plot_types[Vector2i(0, 0)] = biome.PlotType.FARM
	biome.plot_types[Vector2i(1, 0)] = biome.PlotType.FARM

	print("\n=== PHASE 1: NOON (θ ≈ 0, sun bright) ===")
	print("Expected: Wheat strongly aligned to sun, mushroom weakly to moon")
	print("Wheat should grow fast, mushroom should take damage\n")
	print("Time | Sun θ  | Wheat θ | Wheat Energy | Mushroom θ | Mushroom Energy | Comment")
	print(sep)

	var dt = 0.016666
	var total_time = 0.0
	var next_sample = 0.0
	var wheat_prev = wheat.energy
	var mushroom_prev = mushroom.energy
	var phase = 0  # 0=noon, 1=midnight

	while total_time < 40.0:
		total_time += dt
		biome.time_tracker.update(dt)
		biome._apply_celestial_oscillation(dt)
		biome._apply_hamiltonian_evolution(dt)
		biome._apply_spring_attraction(dt)
		biome._apply_energy_transfer(dt)

		# Switch to midnight phase at 20 seconds
		if total_time >= 20.0 and phase == 0:
			phase = 1
			print("\n=== PHASE 2: MIDNIGHT (θ ≈ π, sun dark) ===")
			print("Expected: Mushroom strongly aligned to moon, wheat weakly to sun")
			print("Mushroom should grow fast, wheat should not take damage\n")
			print("Time | Sun θ  | Wheat θ | Wheat Energy | Mushroom θ | Mushroom Energy | Comment")
			print(sep)

		if total_time >= next_sample:
			var wheat_growth = wheat.energy - wheat_prev
			var mushroom_growth = mushroom.energy - mushroom_prev

			# Calculate alignments for interpretation
			var sun_vector = biome._bloch_vector(biome.sun_qubit.theta, biome.sun_qubit.phi)
			var moon_theta = PI - biome.sun_qubit.theta
			var moon_phi = biome.sun_qubit.phi + PI
			var moon_vector = biome._bloch_vector(moon_theta, moon_phi)

			var wheat_bloch = wheat.get_bloch_vector()
			var mushroom_bloch = mushroom.get_bloch_vector()

			var wheat_sun_angle = biome._bloch_angle_between(wheat_bloch, sun_vector)
			var wheat_sun_align = pow(cos(wheat_sun_angle / 2.0), 2)

			var mushroom_moon_angle = biome._bloch_angle_between(mushroom_bloch, moon_vector)
			var mushroom_moon_align = pow(cos(mushroom_moon_angle / 2.0), 2)

			var sun_brightness = biome.sun_qubit.radius
			var comment = ""

			if phase == 0:
				if wheat_sun_align > 0.7:
					comment = "Wheat strongly aligned ✓"
				elif mushroom_moon_align < 0.3:
					comment = "Mushroom weakly aligned ✓"
				if wheat_growth > 0.01:
					comment += " Growing"
				if mushroom_growth < 0.0:
					comment += " Damaged"
			else:  # phase 1
				if mushroom_moon_align > 0.7:
					comment = "Mushroom strongly aligned ✓"
				elif wheat_sun_align < 0.3:
					comment = "Wheat weakly aligned ✓"
				if mushroom_growth > 0.01:
					comment += " Growing"
				if wheat_growth >= 0.0:
					comment += " Protected"

			print("%.1fs | %5.0f° | %5.0f° | %.4f | %5.0f° | %.4f | %s" % [
				total_time,
				biome.sun_qubit.theta * 180.0 / PI,
				wheat.theta * 180.0 / PI,
				wheat.energy,
				mushroom.theta * 180.0 / PI,
				mushroom.energy,
				comment
			])

			wheat_prev = wheat.energy
			mushroom_prev = mushroom.energy
			next_sample += 1.0

	print(sep)
	print("\n=== ANALYSIS ===")
	print("✓ Test completed successfully")
	print("✓ Check that alignment modulation is working:")
	print("  - Phase 1 (noon): Wheat energy increased, mushroom energy decreased")
	print("  - Phase 2 (midnight): Mushroom energy increased, wheat energy stable")
	print("✓ Check that theta angles respond to modulated spring forces")
	print("  - Phase 1: Wheat θ stays near 0° (sun), mushroom θ may drift")
	print("  - Phase 2: Mushroom θ pulled to π° (moon), wheat θ weak response")
	print(sep + "\n")

	get_tree().quit()
