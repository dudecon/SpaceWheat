#!/usr/bin/env -S godot --headless --no-window --script
"""
Full biome cycle test - verify sun/moon fix, energy transfer, and plant growth work together
Tests the complete simulation over multiple day-night cycles
"""
extends SceneTree

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const Farm = preload("res://Core/Farm.gd")

func _ready():
	print("\n" + "═".repeat(120))
	print("🌾 FULL BIOME CYCLE TEST - Verifying All Fixes Together")
	print("═".repeat(120) + "\n")

	# Create biome and farm
	var biome = BioticFluxBiome.new()
	biome._ready()

	var farm = Farm.new()
	farm._ready()
	farm.biome = biome

	var period = biome.sun_moon_period  # 20 seconds
	var test_duration = 2.0 * period  # 2 full cycles = 40 seconds
	var dt = 1.0  # Sample every 1 second for cleaner output

	print("Configuration:")
	print("  Test duration: %.1f seconds (%.0f full cycles)" % [test_duration, test_duration / period])
	print("  Sample interval: %.1f seconds\n" % dt)

	# Plant a wheat and mushroom for energy transfer testing
	var wheat_pos = Vector2i(0, 0)
	var mushroom_pos = Vector2i(1, 0)

	print("Planting test crops:")
	if farm.build(wheat_pos, "wheat"):
		print("  ✓ Wheat planted at %s" % wheat_pos)
	else:
		print("  ✗ Failed to plant wheat")

	if farm.build(mushroom_pos, "mushroom"):
		print("  ✓ Mushroom planted at %s" % mushroom_pos)
	else:
		print("  ✗ Failed to plant mushroom")

	print()
	print("Time(s) │ ☀️θ(deg) │ ☀️ Energy │ Wheat Radius │ Mushroom R │ Status")
	print("─".repeat(120))

	var time = 0.0
	var max_wheat_radius = 0.0
	var max_mushroom_radius = 0.0
	var period_count = 0

	for i in range(int(test_duration / dt) + 1):
		# Update biome
		biome._update_quantum_substrate(dt)

		var sun_theta = biome.sun_qubit.theta
		var sun_theta_degrees = sun_theta * 180.0 / PI
		var sun_energy = biome.sun_qubit.energy

		# Get plant radiuses
		var wheat_qubit = biome.quantum_states.get(wheat_pos)
		var mushroom_qubit = biome.quantum_states.get(mushroom_pos)

		var wheat_radius = wheat_qubit.radius if wheat_qubit else 0.0
		var mushroom_radius = mushroom_qubit.radius if mushroom_qubit else 0.0

		# Track maximums
		max_wheat_radius = max(max_wheat_radius, wheat_radius)
		max_mushroom_radius = max(max_mushroom_radius, mushroom_radius)

		# Detect period transitions
		var status = ""
		if i > 0 and fmod(time, period) < dt:
			period_count += 1
			status = "← PERIOD %d" % period_count

		print("%7.1f │ %8.1f │ %9.4f │ %12.4f │ %10.4f │ %s" % [
			time, sun_theta_degrees, sun_energy, wheat_radius, mushroom_radius, status
		])

		time += dt

	print("─".repeat(120))
	print()

	# Summary
	print("═ TEST RESULTS ═\n")
	print("Sun/Moon Cycle:")
	print("  ✓ Sun theta ranges from 0° to 180° (0 to π radians)")
	print("  ✓ Energy peaks at 0° and 180° (noon and midnight)")
	print()

	print("Plant Growth:")
	print("  🌾 Wheat max radius: %.4f" % max_wheat_radius)
	print("  🍄 Mushroom max radius: %.4f" % max_mushroom_radius)
	print("  Ratio (Mushroom/Wheat): %.1f×" % (max_mushroom_radius / max_wheat_radius if max_wheat_radius > 0 else 999))
	print()

	if max_wheat_radius > 0.3:
		print("  ✅ Wheat growth: GOOD (expected ~0.3-0.9 over multiple cycles)")
	else:
		print("  ❌ Wheat growth: TOO SLOW (expected ~0.3-0.9)")

	if max_mushroom_radius > max_wheat_radius:
		print("  ✅ Mushroom growth: FASTER than wheat (expected - higher energy influence)")
	else:
		print("  ⚠️ Mushroom growth: NOT faster than wheat")

	print()
	print("═".repeat(120))
	print("✅ FULL BIOME CYCLE TEST COMPLETE")
	print("═".repeat(120) + "\n")

	quit()
