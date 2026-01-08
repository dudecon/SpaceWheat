extends Node

## EXPERIMENT 6: CELESTIAL IMMOBILITY TEST
## Verify that sun/moon qubits don't move (marked as CELESTIAL in plot_types)

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")

var biome: BioticFluxBiome

func _ready() -> void:
	var sep = "=================================================================================="
	print("\n" + sep)
	print("EXPERIMENT 6: CELESTIAL IMMOBILITY TEST")
	print("Sun/Moon qubits should be immutable and not affected by forces")
	print(sep)

	# Create biome
	biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame

	# Get sun/moon qubit
	var sun_pos = Vector2i(-1, -1)  # Standard sun/moon position in biome
	var sun_qubit = biome.quantum_states.get(sun_pos)

	if not sun_qubit:
		print("\n⚠️  ERROR: Could not find sun/moon qubit at standard position")
		get_tree().quit()
		return

	print("\n🎯 Initial Sun/Moon State:")
	print("   θ = %.3f rad (%.0f°)" % [sun_qubit.theta, sun_qubit.theta * 180 / PI])
	print("   φ = %.3f rad (%.0f°)" % [sun_qubit.phi, sun_qubit.phi * 180 / PI])
	print("   Position marked as PlotType.CELESTIAL: %s" % [biome.plot_types.get(sun_pos) == biome.PlotType.CELESTIAL])

	# Record initial state
	var theta_initial = sun_qubit.theta
	var phi_initial = sun_qubit.phi

	# Run for 10 seconds with ALL force updates
	for i in range(600):  # 10 seconds at 60fps
		biome._apply_spring_attraction(0.016666)
		biome._apply_hamiltonian_evolution(0.016666)
		biome._apply_energy_transfer(0.016666)

	print("\n📊 RESULTS:")
	print("   After 10 seconds of all force updates:")
	print("   θ = %.3f rad (%.0f°)" % [sun_qubit.theta, sun_qubit.theta * 180 / PI])
	print("   φ = %.3f rad (%.0f°)" % [sun_qubit.phi, sun_qubit.phi * 180 / PI])

	var theta_change = abs(sun_qubit.theta - theta_initial)
	var phi_change = abs(sun_qubit.phi - phi_initial)

	print("\n✓ Analysis:")
	print("   Δθ: %.6f rad (%.4f°)" % [theta_change, theta_change * 180 / PI])
	print("   Δφ: %.6f rad (%.4f°)" % [phi_change, phi_change * 180 / PI])

	var epsilon = 0.00001  # Allow tiny numerical errors

	if theta_change < epsilon and phi_change < epsilon:
		print("\n   ✅ SUCCESS: Sun/Moon is completely immobile (as expected)")
	else:
		print("\n   ⚠️  WARNING: Sun/Moon moved despite being celestial!")
		print("      This suggests the celestial skip in force updates isn't working")

	print("\n" + sep + "\n")
	get_tree().quit()
