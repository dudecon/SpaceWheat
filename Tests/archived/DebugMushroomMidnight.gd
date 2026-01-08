extends Node

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

func _ready() -> void:
	var sep = "════════════════════════════════════════════════════════════════"
	print("\n" + sep)
	print("DEBUG: MOON ALIGNMENT & ENERGY")
	print(sep)
	
	# Create biome
	var biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame
	
	# Create mushroom at midnight position
	var mushroom = DualEmojiQubit.new()
	mushroom.north_emoji = "🍂"
	mushroom.south_emoji = "🍄"
	mushroom.theta = PI  # Midnight
	mushroom.phi = 0.0
	mushroom.radius = 0.5
	mushroom.energy = 1.0
	
	# Register mushroom
	biome.quantum_states[Vector2i(0, 0)] = mushroom
	biome.plots_by_type[biome.PlotType.FARM] = [Vector2i(0, 0)]
	biome.plot_types[Vector2i(0, 0)] = biome.PlotType.FARM
	
	print("\nTracking mushroom energy as sun/moon cycle")
	print("Time | Sun θ  | Sun φ  | Moon θ | Moon φ | Moon Bright | 🍄 Energy | Growth")
	print(sep)
	
	var prev_energy = mushroom.energy
	var dt = 0.016666
	var total_time = 0.0
	var next_sample = 0.5
	
	while total_time < 20.0:
		total_time += dt
		biome.time_tracker.update(dt)
		biome._apply_celestial_oscillation(dt)
		biome._apply_hamiltonian_evolution(dt)
		biome._apply_spring_attraction(dt)
		biome._apply_energy_transfer(dt)
		
		if total_time >= next_sample:
			var moon_theta = PI - biome.sun_qubit.theta
			var moon_phi = biome.sun_qubit.phi + PI
			var moon_brightness = 1.0 - biome.sun_qubit.radius
			var growth = mushroom.energy - prev_energy
			
			print("%.1fs | %5.0f° | %5.0f° | %5.0f° | %5.0f° | %.2f | %.4f | %+.5f" % [
				total_time,
				biome.sun_qubit.theta * 180 / PI,
				fmod(biome.sun_qubit.phi * 180 / PI, 360.0),
				fmod(moon_theta * 180 / PI, 360.0),
				fmod(moon_phi * 180 / PI, 360.0),
				moon_brightness,
				mushroom.energy,
				growth
			])
			prev_energy = mushroom.energy
			next_sample += 0.5
	
	print(sep + "\n")
	get_tree().quit()
