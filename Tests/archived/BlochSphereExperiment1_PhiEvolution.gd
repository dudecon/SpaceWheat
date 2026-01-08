extends Node

## EXPERIMENT 1: Φ EVOLUTION TEST
## Hypothesis: Spring attraction should pull φ toward the target φ=0
## A qubit starting at φ=π/2 should gradually rotate toward φ=0
## This tests the cross product torque affecting the azimuthal angle

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var biome: BioticFluxBiome
var test_qubit: DualEmojiQubit
var measurements: Array = []

func _ready() -> void:
	var sep = "=================================================================================="
	print("\n" + sep)
	print("EXPERIMENT 1: Φ EVOLUTION TEST")
	print("Testing if spring torque pulls φ toward target (0)")
	print(sep)

	# Create biome
	biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame

	# Create test qubit: wheat at θ=0 (north pole) but φ=π/2 (90° off target)
	test_qubit = DualEmojiQubit.new()
	test_qubit.north_emoji = "🌾"
	test_qubit.south_emoji = "💧"
	test_qubit.theta = 0.0  # Aligned with day (wheat state)
	test_qubit.phi = PI / 2.0  # Offset by 90°
	test_qubit.radius = 0.3
	test_qubit.energy = 0.3

	# Register with biome
	var pos = Vector2i(0, 0)
	biome.quantum_states[pos] = test_qubit
	biome.plots_by_type[biome.PlotType.FARM].append(pos)
	biome.plot_types[pos] = biome.PlotType.FARM

	print("\n🎯 Initial State:")
	print("   θ = %.3f rad (%.0f°)" % [test_qubit.theta, test_qubit.theta * 180 / PI])
	print("   φ = %.3f rad (%.0f°)" % [test_qubit.phi, test_qubit.phi * 180 / PI])
	print("   Target: θ = 0.0, φ = 0.0")
	print("   Spring constant: 0.5")
	print("\n   If φ is pulled by cross product, it should DECREASE toward 0")
	print("   Initial distance in Bloch space: %.3f rad" % _calculate_bloch_distance())

	# Record initial state
	_record_measurement(0.0)

	# Run for 15 seconds
	var total_time = 0.0
	var dt = 0.016666  # ~60 FPS
	var next_sample_time = 1.0

	while total_time < 15.0:
		total_time += dt

		# Update biome
		biome._apply_spring_attraction(dt)
		biome._apply_hamiltonian_evolution(dt)

		# Sample every 1 second
		if total_time >= next_sample_time:
			_record_measurement(total_time)
			next_sample_time += 1.0

	print("\n📊 RESULTS:")
	_print_measurements()

	# Analysis
	var phi_start = measurements[0]["phi"]
	var phi_end = measurements[-1]["phi"]
	var phi_change = phi_start - phi_end
	var elapsed_time = measurements[-1]["time"] - measurements[0]["time"]
	var phi_decrease_per_second = phi_change / elapsed_time if elapsed_time > 0 else 0.0

	print("\n✓ Analysis:")
	print("   Initial φ: %.3f rad (%.1f°)" % [phi_start, phi_start * 180 / PI])
	print("   Final φ:   %.3f rad (%.1f°)" % [phi_end, phi_end * 180 / PI])
	print("   Change:    %.3f rad (%.1f°) over %.1f seconds" % [phi_change, phi_change * 180 / PI, elapsed_time])
	print("   Rate:      %.4f rad/s" % phi_decrease_per_second)

	if phi_change > 0.01:  # Significant decrease
		print("\n   ✅ SUCCESS: Φ is decreasing toward target!")
		print("      Spring torque is working correctly")
	else:
		print("\n   ⚠️  WARNING: Φ is not decreasing significantly")
		print("      Spring torque may not be affecting φ properly")

	print("\n" + sep + "\n")
	get_tree().quit()


func _record_measurement(time: float) -> void:
	measurements.append({
		"time": time,
		"theta": test_qubit.theta,
		"phi": test_qubit.phi,
		"distance": _calculate_bloch_distance(),
	})


func _calculate_bloch_distance() -> float:
	"""Calculate distance between current state and target (θ=0, φ=0)"""
	var current = Vector3(
		sin(test_qubit.theta) * cos(test_qubit.phi),
		sin(test_qubit.theta) * sin(test_qubit.phi),
		cos(test_qubit.theta)
	)
	var target = Vector3(0.0, 0.0, 1.0)  # North pole is at (0,0,1) on Bloch sphere
	return current.distance_to(target)


func _print_measurements() -> void:
	print("   Time(s) | θ(rad)  | φ(rad)  [6 decimals] | Distance")
	print("   " + "------------------------------------------------------------")
	for m in measurements:
		print("   %.1f     | %.3f   | %.6f       | %.3f" % [
			m["time"],
			m["theta"],
			m["phi"],
			m["distance"]
		])
