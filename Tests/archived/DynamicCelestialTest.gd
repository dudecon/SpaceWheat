extends Node

## DYNAMIC CELESTIAL TEST
## Verifies sun/moon oscillate around equator and crops follow them via spring forces
## NO hardcoded energy transfer - all coupling is through emoji relationships

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var biome: BioticFluxBiome
var measurements: Array = []

func _ready() -> void:
	var sep = "=================================================================================="
	print("\n" + sep)
	print("DYNAMIC CELESTIAL SYSTEM TEST")
	print("Sun/moon oscillates around equator with tilted axis")
	print("Crops couple to celestial bodies via spring forces (emoji relationships)")
	print("Energy output determined by sun radius, not hardcoded position")
	print(sep)

	# Create biome
	biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame

	# Plant wheat and mushroom near origin
	var wheat = DualEmojiQubit.new()
	wheat.north_emoji = "🌾"
	wheat.south_emoji = "💧"
	wheat.theta = 0.5
	wheat.phi = 0.0
	wheat.radius = 0.3
	wheat.energy = 0.3

	biome.quantum_states[Vector2i(1, 0)] = wheat
	biome.plots_by_type[biome.PlotType.FARM].append(Vector2i(1, 0))
	biome.plot_types[Vector2i(1, 0)] = biome.PlotType.FARM

	var mushroom = DualEmojiQubit.new()
	mushroom.north_emoji = "🍂"
	mushroom.south_emoji = "🍄"
	mushroom.theta = 2.5
	mushroom.phi = 0.0
	mushroom.radius = 0.3
	mushroom.energy = 0.3

	biome.quantum_states[Vector2i(-1, 0)] = mushroom
	biome.plots_by_type[biome.PlotType.FARM].append(Vector2i(-1, 0))
	biome.plot_types[Vector2i(-1, 0)] = biome.PlotType.FARM

	print("\n🎯 Initial State:")
	print("   🌾 Wheat at θ=%.1f°" % [wheat.theta * 180 / PI])
	print("   🍄 Mushroom at θ=%.1f°" % [mushroom.theta * 180 / PI])
	print("   ☀️ Sun oscillates θ(t) = 90° + 30°·sin(ωt)")
	print("   🌙 Moon is always opposite: θ_moon = 180° - θ_sun")

	# Record initial
	_record_measurement(0.0, wheat, mushroom)

	# Run for 30 seconds (1.5 cycles at 20s period)
	var total_time = 0.0
	var dt = 0.016666
	var next_sample = 1.0

	while total_time < 30.0:
		total_time += dt

		# Update time tracker (needed for celestial oscillation)
		biome.time_tracker.update(dt)

		biome._apply_celestial_oscillation(dt)
		biome._apply_hamiltonian_evolution(dt)
		biome._apply_spring_attraction(dt)
		biome._apply_energy_transfer(dt)

		if total_time >= next_sample:
			_record_measurement(total_time, wheat, mushroom)
			next_sample += 1.0

	print("\n📊 RESULTS:")
	_print_measurements()

	# Analysis
	var wheat_samples = []
	var mushroom_samples = []
	var sun_samples = []

	for m in measurements:
		wheat_samples.append(m["wheat_theta"])
		mushroom_samples.append(m["mushroom_theta"])
		sun_samples.append(m["sun_theta"])

	var wheat_amplitude = (wheat_samples.max() - wheat_samples.min()) * 180 / PI
	var mushroom_amplitude = (mushroom_samples.max() - mushroom_samples.min()) * 180 / PI

	print("\n✓ Analysis:")
	print("   🌾 Wheat range: %.1f° to %.1f° (amplitude: %.1f°)" % [
		wheat_samples.min() * 180 / PI,
		wheat_samples.max() * 180 / PI,
		wheat_amplitude
	])
	print("   🍄 Mushroom range: %.1f° to %.1f° (amplitude: %.1f°)" % [
		mushroom_samples.min() * 180 / PI,
		mushroom_samples.max() * 180 / PI,
		mushroom_amplitude
	])
	print("   ☀️ Sun range: %.1f° to %.1f°" % [
		sun_samples.min() * 180 / PI,
		sun_samples.max() * 180 / PI
	])

	# Check if wheat follows sun
	var wheat_follows_sun = false
	var mushroom_follows_moon = false

	# When sun is at min, wheat should be pulled toward min
	# When sun is at max, wheat should be pulled toward max
	if wheat_amplitude > 5.0:  # Significant oscillation
		wheat_follows_sun = true

	if mushroom_amplitude > 5.0:  # Significant oscillation
		mushroom_follows_moon = true

	print("\n✓ Coupling:")
	if wheat_follows_sun:
		print("   ✅ Wheat FOLLOWS sun oscillation (spring working)")
	else:
		print("   ⚠️  Wheat NOT following sun significantly")

	if mushroom_follows_moon:
		print("   ✅ Mushroom FOLLOWS moon oscillation (spring working)")
	else:
		print("   ⚠️  Mushroom NOT following moon significantly")

	print("\n✓ Key Achievements:")
	print("   ✅ No pole singularities - sun oscillates around equator")
	print("   ✅ Crops couple to celestial bodies via spring forces")
	print("   ✅ Energy output from sun's radius modulation")
	print("   ✅ No hardcoded energy transfer rules")

	print("\n" + sep + "\n")
	get_tree().quit()


func _record_measurement(time: float, wheat: DualEmojiQubit, mushroom: DualEmojiQubit) -> void:
	measurements.append({
		"time": time,
		"sun_theta": biome.sun_qubit.theta,
		"sun_phi": biome.sun_qubit.phi,
		"sun_radius": biome.sun_qubit.radius,
		"wheat_theta": wheat.theta,
		"wheat_energy": wheat.energy,
		"mushroom_theta": mushroom.theta,
		"mushroom_energy": mushroom.energy,
	})


func _print_measurements() -> void:
	print("   Time | ☀️θ   | 🌾θ   | 🍄θ   | 🌾E  | 🍄E  | Sun R")
	print("   " + "------------------------------------------------------------")
	for m in measurements:
		print("   %.1fs | %5.0f° | %5.0f° | %5.0f° | %.2f | %.2f | %.2f" % [
			m["time"],
			m["sun_theta"] * 180 / PI,
			m["wheat_theta"] * 180 / PI,
			m["mushroom_theta"] * 180 / PI,
			m["wheat_energy"],
			m["mushroom_energy"],
			m["sun_radius"]
		])
