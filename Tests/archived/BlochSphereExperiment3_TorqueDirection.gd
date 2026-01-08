extends Node

## EXPERIMENT 3: SPRING TORQUE DIRECTION DIAGNOSTIC
## Question: Why is the spring pulling toward south pole instead of north?
## Let's test different starting positions to map the spring field

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var biome: BioticFluxBiome

func _ready() -> void:
	var sep = "=================================================================================="
	print("\n" + sep)
	print("EXPERIMENT 3: SPRING TORQUE DIRECTION TEST")
	print("Testing wheat spring at various points on Bloch sphere")
	print("Target is: (θ=0, φ=0) = North pole")
	print(sep)

	# Create biome
	biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame

	# Test at different points
	var test_points = [
		{"theta": 0.0, "phi": 0.0, "name": "North Pole (target)"},
		{"theta": PI / 4.0, "phi": 0.0, "name": "30° from north"},
		{"theta": PI / 2.0, "phi": 0.0, "name": "Equator φ=0"},
		{"theta": PI / 2.0, "phi": PI, "name": "Equator φ=π (opposite)"},
		{"theta": PI / 2.0, "phi": PI / 2.0, "name": "Equator φ=π/2"},
		{"theta": 3.0 * PI / 4.0, "phi": 0.0, "name": "150° from north"},
	]

	print("\n📊 Testing spring force at different points:")
	print("Position          | Initial θ,φ        | After 0.1s  | Change in θ,φ   | Direction")
	print("----------------------------------------------------------------------------------------------------")

	for test in test_points:
		var qubit = DualEmojiQubit.new()
		qubit.north_emoji = "🌾"
		qubit.south_emoji = "💧"
		qubit.theta = test.theta
		qubit.phi = test.phi
		qubit.radius = 0.3
		qubit.energy = 0.3

		var pos = Vector2i(int(randf() * 100) - 50, int(randf() * 100) - 50)
		biome.quantum_states[pos] = qubit
		biome.plots_by_type[biome.PlotType.FARM].append(pos)
		biome.plot_types[pos] = biome.PlotType.FARM

		# Record initial state
		var theta_before = qubit.theta
		var phi_before = qubit.phi

		# Apply spring for 0.1 seconds
		for i in range(6):  # 6 * 0.016666 ≈ 0.1 seconds
			biome._apply_spring_attraction(0.016666)

		var theta_after = qubit.theta
		var phi_after = qubit.phi
		var theta_change = theta_after - theta_before
		var phi_change = phi_after - phi_before

		# Normalize phi change to [-π, π]
		while phi_change > PI:
			phi_change -= TAU
		while phi_change < -PI:
			phi_change += TAU

		var direction = ""
		if theta_change < -0.01:
			direction = "↑ North"
		elif theta_change > 0.01:
			direction = "↓ South"
		else:
			direction = "→ Stay"

		if abs(phi_change) > 0.01:
			direction += " | φ change"

		print("%-17s | (%.1f°, %.1f°)      | (%.1f°, %.1f°) | Δθ=%.3f Δφ=%.3f | %s" % [
			test.name,
			test.theta * 180 / PI,
			test.phi * 180 / PI,
			theta_after * 180 / PI,
			phi_after * 180 / PI,
			theta_change,
			phi_change,
			direction
		])

		# Clean up
		biome.quantum_states.erase(pos)
		biome.plots_by_type[biome.PlotType.FARM].erase(pos)
		biome.plot_types.erase(pos)

	print("\n" + sep)
	print("ANALYSIS:")
	print("If spring is working correctly, all forces should point toward north pole")
	print("- Points near north pole (low θ) should be repelled away (increasing θ)")
	print("- Points at south pole (high θ) should be attracted back (decreasing θ)")
	print("If reversed, there may be a sign error in the torque calculation")
	print(sep + "\n")

	get_tree().quit()
