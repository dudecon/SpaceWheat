extends Node

## EXPERIMENT 4: HYBRID CROP STABILITY
## Hypothesis: A hybrid crop should find equilibrium between wheat (θ=0) and mushroom (θ=π)
## Should converge to θ=π/2 (equator) where both forces balance

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var biome: BioticFluxBiome
var test_qubit: DualEmojiQubit
var measurements: Array = []

func _ready() -> void:
	var sep = "=================================================================================="
	print("\n" + sep)
	print("EXPERIMENT 4: HYBRID CROP STABILITY")
	print("Wheat wants θ=0 (north), Mushroom wants θ=π (south)")
	print("Hybrid should equilibrate between them (θ≈π/2 at equator)")
	print(sep)

	# Create biome
	biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame

	# Create hybrid qubit - has BOTH wheat and mushroom emojis
	test_qubit = DualEmojiQubit.new()
	test_qubit.north_emoji = "🌾"  # Wheat
	test_qubit.south_emoji = "🍄"  # Mushroom (making it a hybrid)
	test_qubit.theta = PI / 2.0  # Start at EQUATOR (not at pole where springs have zero force!)
	test_qubit.phi = 0.0
	test_qubit.radius = 0.3
	test_qubit.energy = 0.3

	# Register with biome as FARM (both wheat and mushroom)
	var pos = Vector2i(0, 0)
	biome.quantum_states[pos] = test_qubit
	biome.plots_by_type[biome.PlotType.FARM].append(pos)
	biome.plot_types[pos] = biome.PlotType.FARM

	print("\n🎯 Initial State:")
	print("   Hybrid crop: 🌾 (north/wheat) ↔ 🍄 (south/mushroom)")
	print("   θ = %.3f rad (%.0f°) - STARTING AT EQUATOR" % [test_qubit.theta, test_qubit.theta * 180 / PI])
	print("   Spring targets: wheat at 0°, mushroom at 180°")
	print("   Expected equilibrium: θ ≈ 90° (equator, where forces should balance)")

	# Debug: Check if hybrid is detected correctly
	var is_wheat = test_qubit.north_emoji == "🌾" or test_qubit.south_emoji == "🌾"
	var is_mushroom = test_qubit.north_emoji == "🍄" or test_qubit.south_emoji == "🍄"
	print("\n   DEBUG: is_wheat=%s, is_mushroom=%s, is_hybrid=%s" % [is_wheat, is_mushroom, is_wheat and is_mushroom])

	# Record initial state
	_record_measurement(0.0)

	# Run for 15 seconds
	var total_time = 0.0
	var dt = 0.016666  # ~60 FPS
	var next_sample_time = 0.5

	while total_time < 15.0:
		total_time += dt

		# Update biome (hybrid will feel BOTH spring forces at 0.5 weight each)
		biome._apply_spring_attraction(dt)
		biome._apply_hamiltonian_evolution(dt)

		if total_time >= next_sample_time:
			_record_measurement(total_time)
			next_sample_time += 0.5

	print("\n📊 RESULTS:")
	_print_measurements()

	# Analysis
	var theta_start = measurements[0]["theta"]
	var theta_end = measurements[-1]["theta"]
	var theta_avg = 0.0
	for m in measurements:
		theta_avg += m["theta"]
	theta_avg /= measurements.size()

	print("\n✓ Analysis:")
	print("   Initial θ:  %.1f°" % [theta_start * 180 / PI])
	print("   Final θ:    %.1f°" % [theta_end * 180 / PI])
	print("   Average θ:  %.1f°" % [theta_avg * 180 / PI])
	print("   Expected:   90° (equator)")

	var error_from_equilibrium = abs(theta_end * 180 / PI - 90.0)

	if error_from_equilibrium < 5.0:
		print("\n   ✅ SUCCESS: Hybrid found stable equilibrium at equator!")
	elif error_from_equilibrium < 20.0:
		print("\n   ✅ GOOD: Hybrid converging toward equatorial equilibrium")
	else:
		print("\n   ⚠️  WARNING: Hybrid not converging to expected equilibrium")

	print("\n" + sep + "\n")
	get_tree().quit()


func _record_measurement(time: float) -> void:
	measurements.append({
		"time": time,
		"theta": test_qubit.theta,
		"phi": test_qubit.phi,
	})


func _print_measurements() -> void:
	print("   Time | θ(deg) |  Status")
	print("   " + "-----------------------------------")
	for m in measurements:
		var theta_deg = m["theta"] * 180 / PI
		var status = ""
		if theta_deg < 30.0:
			status = "near wheat (north)"
		elif theta_deg > 150.0:
			status = "near mushroom (south)"
		elif theta_deg > 70.0 and theta_deg < 110.0:
			status = "at equilibrium ✓"
		else:
			status = "transitioning"
		print("   %.1fs | %5.0f° | %s" % [m["time"], theta_deg, status])
