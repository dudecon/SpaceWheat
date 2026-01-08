extends Node

## QUICK DIAGNOSTIC: Test hybrid with ONLY spring, no Hamiltonian

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var biome: BioticFluxBiome
var test_qubit: DualEmojiQubit

func _ready() -> void:
	print("\n=== DIAGNOSTIC: Hybrid Spring Only (No Hamiltonian) ===")

	biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame

	# Create hybrid
	test_qubit = DualEmojiQubit.new()
	test_qubit.north_emoji = "🌾"
	test_qubit.south_emoji = "🍄"
	test_qubit.theta = 0.2  # 11°
	test_qubit.phi = 0.0
	test_qubit.radius = 0.3
	test_qubit.energy = 0.3

	var pos = Vector2i(0, 0)
	biome.quantum_states[pos] = test_qubit
	biome.plots_by_type[biome.PlotType.FARM].append(pos)
	biome.plot_types[pos] = biome.PlotType.FARM

	print("Initial θ: %.1f°" % [test_qubit.theta * 180 / PI])

	# Apply ONLY spring 10 times
	for i in range(600):  # 10 seconds at 60fps
		biome._apply_spring_attraction(0.016666)
		# NO _apply_hamiltonian_evolution

	print("After 10s (spring only): θ = %.1f°" % [test_qubit.theta * 180 / PI])
	print("Change: %.1f°" % [(test_qubit.theta - 0.2) * 180 / PI])

	if abs(test_qubit.theta - 0.2) > 0.01:
		print("✓ Spring IS moving the hybrid")
	else:
		print("✗ Spring is NOT moving the hybrid")

	get_tree().quit()
