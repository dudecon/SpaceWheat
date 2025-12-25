extends Node

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

func _ready() -> void:
	var sep = "════════════════════════════════════════════════════════════════"
	print("\n" + sep)
	print("MUSHROOM MIDNIGHT ENERGY TEST")
	print("Verify mushrooms absorb energy at night, wheat during day")
	print(sep)
	
	# Create biome
	var biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame
	
	# Create wheat crop (should grow during day, lose energy at night)
	var wheat = DualEmojiQubit.new()
	wheat.north_emoji = "🌾"
	wheat.south_emoji = "🏰"
	wheat.theta = PI / 4.0  # Morning position
	wheat.phi = 3.0 * PI / 2.0
	wheat.radius = 0.5
	wheat.energy = 0.5
	
	# Create mushroom crop (should lose energy during day, grow at night)
	var mushroom = DualEmojiQubit.new()
	mushroom.north_emoji = "🍂"
	mushroom.south_emoji = "🍄"
	mushroom.theta = PI  # Midnight position
	mushroom.phi = 0.0
	mushroom.radius = 0.5
	mushroom.energy = 0.5
	
	# Register crops
	biome.quantum_states[Vector2i(0, 0)] = wheat
	biome.quantum_states[Vector2i(1, 0)] = mushroom
	biome.plots_by_type[biome.PlotType.FARM] = [Vector2i(0, 0), Vector2i(1, 0)]
	biome.plot_types[Vector2i(0, 0)] = biome.PlotType.FARM
	biome.plot_types[Vector2i(1, 0)] = biome.PlotType.FARM
	
	print("\n🌾 WHEAT initial energy: %.3f" % wheat.energy)
	print("🍄 MUSHROOM initial energy: %.3f" % mushroom.energy)
	print("\n" + sep)
	print("Time   | Sun θ  | ☀️ Rad | 🌾 Energy | 🍄 Energy | 🌾 Growth | 🍄 Growth")
	print(sep)
	
	var prev_wheat_energy = wheat.energy
	var prev_mushroom_energy = mushroom.energy
	var dt = 0.016666
	var total_time = 0.0
	var next_sample = 2.0
	
	while total_time < 30.0:
		total_time += dt
		biome.time_tracker.update(dt)
		biome._apply_celestial_oscillation(dt)
		biome._apply_hamiltonian_evolution(dt)
		biome._apply_spring_attraction(dt)
		biome._apply_energy_transfer(dt)
		
		if total_time >= next_sample:
			var wheat_growth = wheat.energy - prev_wheat_energy
			var mushroom_growth = mushroom.energy - prev_mushroom_energy
			print("%.1fs | %5.0f° | %.2f | %.4f | %.4f | %+.5f | %+.5f" % [
				total_time,
				biome.sun_qubit.theta * 180 / PI,
				biome.sun_qubit.radius,
				wheat.energy,
				mushroom.energy,
				wheat_growth,
				mushroom_growth
			])
			prev_wheat_energy = wheat.energy
			prev_mushroom_energy = mushroom.energy
			next_sample += 2.0
	
	print("\n" + sep)
	print("FINAL ENERGY:")
	print("🌾 Wheat:    %.4f (should grow when sun is bright)" % wheat.energy)
	print("🍄 Mushroom: %.4f (should grow when sun is dark/moon is bright)" % mushroom.energy)
	print(sep + "\n")
	get_tree().quit()
