extends Node

## ICON REST LOCATION DIAGNOSTIC TEST
## Minimal setup: 1 wheat, 1 mushroom, track all theta/phi changes over 3 sun revolutions

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var biome: BioticFluxBiome
var measurements: Array = []

func _ready() -> void:
	var sep = "═" * 100
	print("\n" + sep)
	print("ICON REST LOCATION DIAGNOSTIC TEST")
	print("1 Wheat + 1 Mushroom, 3 full sun revolutions (60 seconds)")
	print(sep)

	# Create biome
	biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame

	# Single WHEAT qubit at origin
	var wheat = DualEmojiQubit.new()
	wheat.north_emoji = "🌾"
	wheat.south_emoji = "🏰"
	wheat.theta = PI / 3.0  # Start at 60°
	wheat.phi = 0.0
	wheat.radius = 0.3
	wheat.energy = 0.3

	biome.quantum_states[Vector2i(0, 0)] = wheat
	biome.plots_by_type[biome.PlotType.FARM].append(Vector2i(0, 0))
	biome.plot_types[Vector2i(0, 0)] = biome.PlotType.FARM

	# Single MUSHROOM qubit nearby
	var mushroom = DualEmojiQubit.new()
	mushroom.north_emoji = "🍂"
	mushroom.south_emoji = "🍄"
	mushroom.theta = 2.0 * PI / 3.0  # Start at 120°
	mushroom.phi = PI  # Opposite side
	mushroom.radius = 0.3
	mushroom.energy = 0.3

	biome.quantum_states[Vector2i(1, 0)] = mushroom
	biome.plots_by_type[biome.PlotType.FARM].append(Vector2i(1, 0))
	biome.plot_types[Vector2i(1, 0)] = biome.PlotType.FARM

	print("\n🎯 INITIAL STATE:")
	print("   Wheat:     θ=%.1f° φ=%.1f°" % [wheat.theta * 180 / PI, wheat.phi * 180 / PI])
	print("   Mushroom:  θ=%.1f° φ=%.1f°" % [mushroom.theta * 180 / PI, mushroom.phi * 180 / PI])
	print("   Sun:       θ=%.1f° φ=%.1f°" % [biome.sun_qubit.theta * 180 / PI, biome.sun_qubit.phi * 180 / PI])

	print("\n🎯 EXPECTED BEHAVIOR:")
	print("   Wheat Icon rest point:    θ=45° φ=270°")
	print("   Mushroom Icon rest point: θ=180° φ=0°")
	print("   Sun oscillates around ecliptic continuously")
	print("   Crops should follow sun/moon with weak drift toward icon rests")

	# Record initial
	_record_measurement(0.0, wheat, mushroom)

	# Run for 3 full sun revolutions (3 × 20 seconds = 60 seconds)
	var total_time = 0.0
	var dt = 0.016666  # ~60fps
	var next_sample = 0.5  # Sample every 0.5 seconds

	while total_time < 60.0:
		total_time += dt
		biome.time_tracker.update(dt)
		biome._apply_celestial_oscillation(dt)
		biome._apply_hamiltonian_evolution(dt)
		biome._apply_spring_attraction(dt)
		biome._apply_icon_rest_attraction(dt)
		biome._apply_energy_transfer(dt)

		if total_time >= next_sample:
			_record_measurement(total_time, wheat, mushroom)
			next_sample += 0.5

	print("\n📊 FULL DATA TRACE (every 0.5 seconds):")
	print("Time | ☀️θ    | ☀️φ    | 🌾θ    | 🌾φ    | 🍄θ    | 🍄φ")
	print("─" * 100)
	for m in measurements:
		print("%.1fs | %5.0f° | %5.0f° | %5.0f° | %5.0f° | %5.0f° | %5.0f°" % [
			m["time"],
			m["sun_theta"] * 180 / PI,
			m["sun_phi"] * 180 / PI,
			m["wheat_theta"] * 180 / PI,
			m["wheat_phi"] * 180 / PI,
			m["mushroom_theta"] * 180 / PI,
			m["mushroom_phi"] * 180 / PI,
		])

	# ANALYSIS
	print("\n" + sep)
	print("ANALYSIS:")
	print(sep)

	var sun_thetas = measurements.map(func(m): return m["sun_theta"])
	var sun_phis = measurements.map(func(m): return m["sun_phi"])
	var wheat_thetas = measurements.map(func(m): return m["wheat_theta"])
	var wheat_phis = measurements.map(func(m): return m["wheat_phi"])
	var mushroom_thetas = measurements.map(func(m): return m["mushroom_theta"])
	var mushroom_phis = measurements.map(func(m): return m["mushroom_phi"])

	print("\n☀️ SUN (should oscillate on ecliptic):")
	print("   θ range: %.1f° → %.1f°" % [sun_thetas.min() * 180 / PI, sun_thetas.max() * 180 / PI])
	print("   φ range: %.1f° → %.1f° (should complete ~3 full rotations)" % [
		sun_phis.min() * 180 / PI, sun_phis.max() * 180 / PI])
	print("   Expected: θ ≈ 66.5° to 113.5°, φ ≈ 0° to 360° × 3")

	print("\n🌾 WHEAT (should follow sun but drift toward π/4, 3π/2):")
	print("   θ range: %.1f° → %.1f°" % [wheat_thetas.min() * 180 / PI, wheat_thetas.max() * 180 / PI])
	print("   φ range: %.1f° → %.1f°" % [wheat_phis.min() * 180 / PI, wheat_phis.max() * 180 / PI])
	print("   Expected rest: θ=45° φ=270°")
	print("   Should drift toward rest while following sun")

	print("\n🍄 MUSHROOM (should follow moon but drift toward π, 0):")
	print("   θ range: %.1f° → %.1f°" % [mushroom_thetas.min() * 180 / PI, mushroom_thetas.max() * 180 / PI])
	print("   φ range: %.1f° → %.1f°" % [mushroom_phis.min() * 180 / PI, mushroom_phis.max() * 180 / PI])
	print("   Expected rest: θ=180° φ=0°")
	print("   Should drift toward rest while following moon")

	print("\n🔍 ROTATION DIRECTION CHECK:")
	var early_sun_phi = measurements[0]["sun_phi"]
	var late_sun_phi = measurements[measurements.size() - 1]["sun_phi"]
	var phi_change = late_sun_phi - early_sun_phi
	print("   Sun φ change: %.1f° (positive=counterclockwise, negative=clockwise)" % [phi_change * 180 / PI])

	var early_wheat_theta = measurements[0]["wheat_theta"]
	var late_wheat_theta = measurements[measurements.size() - 1]["wheat_theta"]
	var theta_change = late_wheat_theta - early_wheat_theta
	print("   Wheat θ change: %.1f°" % [theta_change * 180 / PI])

	print("\n" + sep + "\n")
	get_tree().quit()


func _record_measurement(time: float, wheat: DualEmojiQubit, mushroom: DualEmojiQubit) -> void:
	measurements.append({
		"time": time,
		"sun_theta": biome.sun_qubit.theta,
		"sun_phi": biome.sun_qubit.phi,
		"wheat_theta": wheat.theta,
		"wheat_phi": wheat.phi,
		"mushroom_theta": mushroom.theta,
		"mushroom_phi": mushroom.phi,
	})
