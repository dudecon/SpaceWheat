extends Node

## EXPERIMENT 2: EQUATOR Φ EVOLUTION TEST
## Hypothesis: At the equator (θ=π/2), φ MATTERS and spring torque should pull it toward target
## A qubit at (θ=π/2, φ=π) should rotate toward (θ=π/2, φ=0)
## This tests the cross product torque in the meaningful part of Bloch space

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var biome: BioticFluxBiome
var test_qubit: DualEmojiQubit
var measurements: Array = []

func _ready() -> void:
	var sep = "=================================================================================="
	print("\n" + sep)
	print("EXPERIMENT 2: EQUATOR Φ EVOLUTION TEST")
	print("At equator (θ=π/2), φ matters! Testing spring torque on φ at the equator")
	print(sep)

	# Create biome
	biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame

	# Create test qubit: at EQUATOR with φ offset from target
	# Wheat target is (θ=0, φ=0), so spring should pull θ down and φ toward 0
	test_qubit = DualEmojiQubit.new()
	test_qubit.north_emoji = "🌾"
	test_qubit.south_emoji = "💧"
	test_qubit.theta = PI / 2.0  # Equator - where φ has maximum meaning
	test_qubit.phi = PI  # Opposite side of equator (180° away)
	test_qubit.radius = 0.3
	test_qubit.energy = 0.3

	# Register with biome
	var pos = Vector2i(0, 0)
	biome.quantum_states[pos] = test_qubit
	biome.plots_by_type[biome.PlotType.FARM].append(pos)
	biome.plot_types[pos] = biome.PlotType.FARM

	print("\n🎯 Initial State:")
	print("   θ = %.3f rad (%.0f°) - AT EQUATOR (maximum φ meaning)" % [test_qubit.theta, test_qubit.theta * 180 / PI])
	print("   φ = %.3f rad (%.0f°)" % [test_qubit.phi, test_qubit.phi * 180 / PI])
	print("   Target: θ = 0.0 (north pole), φ = 0.0")
	print("   Spring constant: 0.5")
	print("\n   Bloch vector: (x=%.3f, y=%.3f, z=%.3f)" % [
		sin(test_qubit.theta) * cos(test_qubit.phi),
		sin(test_qubit.theta) * sin(test_qubit.phi),
		cos(test_qubit.theta)
	])
	print("   Initial distance: %.3f" % _calculate_bloch_distance())

	# Record initial state
	_record_measurement(0.0)

	# Run for 10 seconds - spring should pull rapidly toward north pole
	var total_time = 0.0
	var dt = 0.016666  # ~60 FPS
	var next_sample_time = 0.5  # Sample every 0.5 seconds for finer detail

	while total_time < 10.0:
		total_time += dt

		# Update biome
		biome._apply_spring_attraction(dt)
		biome._apply_hamiltonian_evolution(dt)

		# Sample every 0.5 seconds
		if total_time >= next_sample_time:
			_record_measurement(total_time)
			next_sample_time += 0.5

	print("\n📊 RESULTS:")
	_print_measurements()

	# Analysis
	var theta_start = measurements[0]["theta"]
	var theta_end = measurements[-1]["theta"]
	var theta_change = theta_start - theta_end

	var phi_start = measurements[0]["phi"]
	var phi_end = measurements[-1]["phi"]
	# Handle φ wrapping (π and -π are the same)
	var phi_change = phi_start - phi_end
	if phi_change > PI:
		phi_change -= TAU
	elif phi_change < -PI:
		phi_change += TAU

	var distance_start = measurements[0]["distance"]
	var distance_end = measurements[-1]["distance"]

	print("\n✓ Analysis:")
	print("   Θ:  %.3f → %.3f rad  (change: %.3f)" % [theta_start, theta_end, theta_change])
	print("   Φ:  %.3f → %.3f rad  (change: %.3f)" % [phi_start, phi_end, phi_change])
	print("   Distance: %.3f → %.3f (improvement: %.3f)" % [distance_start, distance_end, distance_start - distance_end])

	var converged = distance_end < 0.1
	var moving_toward_north = theta_change > 0.01 or (theta_change >= 0 and abs(phi_change) > 0.01)

	if converged:
		print("\n   ✅ SUCCESS: Qubit converged toward north pole!")
	elif moving_toward_north:
		print("\n   ✅ GOOD: Qubit moving toward target (spring working)")
	else:
		print("\n   ⚠️  WARNING: Qubit not moving as expected")

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
	"""Calculate distance on Bloch sphere to target (0, 0)"""
	var current = Vector3(
		sin(test_qubit.theta) * cos(test_qubit.phi),
		sin(test_qubit.theta) * sin(test_qubit.phi),
		cos(test_qubit.theta)
	)
	var target = Vector3(0.0, 0.0, 1.0)  # North pole
	return current.distance_to(target)


func _print_measurements() -> void:
	print("   Time | θ(deg) | φ(deg) | Distance |  Bloch Vector")
	print("   " + "------------------------------------------------------------")
	for m in measurements:
		var theta_deg = m["theta"] * 180 / PI
		var phi_deg = m["phi"] * 180 / PI
		var bx = sin(m["theta"]) * cos(m["phi"])
		var by = sin(m["theta"]) * sin(m["phi"])
		var bz = cos(m["theta"])
		print("   %.1fs | %5.0f° | %5.0f° | %.3f    | (%.3f, %.3f, %.3f)" % [
			m["time"],
			theta_deg,
			phi_deg,
			m["distance"],
			bx, by, bz
		])
