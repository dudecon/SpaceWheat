#!/usr/bin/env -S godot --headless -s
## Test: Energy Transfer System Diagnostic
##
## Trace actual energy_rate values and growth vs decay per step
## to understand why energy is decreasing instead of growing

extends SceneTree

const Farm = preload("res://Core/Farm.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")

var farm: Farm
var biome_diagnostics: Dictionary = {}

const BIOME_DAY_SECONDS = 20.0
const TEST_DURATION = 60.0  # 3 biome days
const STEP_SIZE = 0.01  # 10ms per step

func _sep(char: String, count: int) -> String:
	var result = ""
	for _i in range(count):
		result += char
	return result

func _initialize():
	print("\n" + _sep("═", 80))
	print("🔬 DIAGNOSTIC: Energy Transfer System")
	print("Trace: energy_rate, alignment, growth vs decay per frame")
	print(_sep("═", 80) + "\n")

	_setup()
	_run_diagnostic()

	quit(0)


func _setup():
	print("🔧 Setting up...\n")

	# Create farm WITH biome
	farm = Farm.new()
	farm._ready()
	var economy = farm.economy
	economy.add_wheat(100)

	print("   ✓ Farm created WITH biome")
	print("   ✓ Biome day = %.1f seconds" % BIOME_DAY_SECONDS)
	print("   ✓ Test duration = %.1f seconds" % TEST_DURATION + "\n")


func _run_diagnostic():
	print("🧪 DIAGNOSTIC RUN\n")
	print(_sep("─", 80))

	# Plant a wheat crop
	var pos = Vector2i(0, 0)
	farm.build(pos, "wheat")

	var plot = farm.get_plot(pos)
	var qubit = plot.quantum_state

	print("Planted wheat at %s" % pos)
	print("Initial state: Energy=%.6f, Radius=%.6f, Theta=%.6f rad\n" % [
		qubit.energy,
		qubit.radius,
		qubit.theta
	])

	# Simulate frame by frame, logging data
	var step_count = 0
	var max_steps = int(TEST_DURATION / STEP_SIZE)
	var sample_interval = 100  # Log every 100 steps (1 second)

	print("Step | Time | Energy | Δ Energy | Alignment | EnergyRate | Θ_crop | Θ_sun")
	print(_sep("─", 80))

	for step in range(max_steps):
		var energy_before = qubit.energy
		var theta_crop = qubit.theta

		# Run biome evolution
		farm.biome._process(STEP_SIZE)

		var energy_after = qubit.energy
		var energy_delta = energy_after - energy_before

		# Get sun qubit for alignment calculation
		var sun_qubit = farm.biome.sun_qubit
		var alignment = 0.0
		if sun_qubit:
			alignment = pow(cos((theta_crop - sun_qubit.theta) / 2.0), 2)

		# Log at intervals
		if (step + 1) % sample_interval == 0 or step < 5:
			var time_elapsed = (step + 1) * STEP_SIZE
			var theta_sun = sun_qubit.theta if sun_qubit else 0.0

			print("%4d | %5.2f | %.6f | %+.6f | %.6f | %-10s | %.3f | %.3f" % [
				step + 1,
				time_elapsed,
				energy_after,
				energy_delta,
				alignment,
				"(need trace)",
				theta_crop,
				theta_sun
			])

		step_count += 1

	print(_sep("─", 80) + "\n")

	# Final comparison
	var final_energy = qubit.energy
	var initial_energy = 0.3  # Wheat initial state
	var total_change = final_energy - initial_energy

	print("📊 SUMMARY AFTER %.1f SECONDS (%.0f steps):" % [TEST_DURATION, step_count])
	print("   Initial energy: %.6f" % initial_energy)
	print("   Final energy: %.6f" % final_energy)
	print("   Net change: %+.6f" % total_change)
	print()

	if total_change > 0.01:
		print("   ✓ Energy is GROWING")
	elif total_change < -0.01:
		print("   ✗ Energy is DECREASING")
	else:
		print("   ~ Energy is STABLE (no significant change)")

	print("\n" + _sep("═", 80) + "\n")

	# ANALYSIS
	print("🔍 ANALYSIS:\n")
	print("Expected behavior:")
	print("   • Alignment should be high (cos²) when crop and sun phases match")
	print("   • High alignment + positive energy_rate = energy should GROW")
	print("   • If energy DECREASES, either:")
	print("     1. Alignment is too small (phase misalignment)")
	print("     2. Energy_rate is very small (weak icon_influence)")
	print("     3. Energy_rate is NEGATIVE (formula error)")
	print("     4. Decoherence (dissipation) is too strong")
	print()
	print("Key parameters in system:")
	print("   • base_energy_rate = 2.45 (Biome.gd:28)")
	print("   • wheat_energy_influence = 0.017 (Biome.gd:27)")
	print("   • mushroom_energy_influence = 0.025 (Biome.gd:29)")
	print("   • T1_base_rate = 0.001 (Biome.gd:53)")
	print("   • T2_base_rate = 0.002 (Biome.gd:54)")
	print()
	print("Expected energy_rate for wheat at alignment=0.5:")
	print("   energy_rate ≈ 2.45 * amplitude * 0.5 * 0.017")
	print("   If amplitude ≈ 1.0: energy_rate ≈ 0.0208 per second")
	print("   With exp growth: energy *= exp(0.0208 * 0.01) ≈ 1.000208 per 10ms")
	print()
	print("Decoherence decay per 10ms step:")
	print("   decay = exp(-T1_rate * dt) = exp(-0.001 * 0.01) ≈ 0.99999")
	print("   So 0.001% loss per 10ms step")
	print()
	print("Issue hypothesis:")
	print("   Growth (0.0208% per step) >> Decay (0.001% per step)")
	print("   So growth SHOULD overcome decay!")
	print("   BUT we observe energy DECREASING...")
	print("   This suggests alignment is VERY SMALL or energy_rate is NEGATIVE!")
	print()

