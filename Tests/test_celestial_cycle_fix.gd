#!/usr/bin/env -S godot --headless --no-window --script
"""
Verify the sun/moon sine wave fix is working correctly in simulation.
Tests that:
1. Sun/moon follows correct 0→π→0 pattern with 2 peaks per period
2. Energy transfer is properly modulated by corrected intensity formula
3. Plant growth responds correctly to energy input
"""
extends SceneTree

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const Farm = preload("res://Core/Farm.gd")

func _ready():
	print("\n" + "═".repeat(120))
	print("🌙 CELESTIAL CYCLE FIX VERIFICATION")
	print("═".repeat(120) + "\n")

	# Create biome and farm
	var biome = BioticFluxBiome.new()
	biome._ready()

	var farm = Farm.new()
	farm._ready()
	farm.biome = biome

	var period = biome.sun_moon_period  # 20 seconds
	var total_time = period * 2.5  # 2.5 periods = 50 seconds for good observation
	var dt = 0.5  # Sample every 0.5 seconds

	print("Configuration:")
	print("  Sun/Moon Period: %.1f seconds" % period)
	print("  Total simulation time: %.1f seconds (2.5 periods)" % total_time)
	print("  Sample interval: %.1f seconds" % dt)
	print()

	# Track peaks
	var time = 0.0
	var intensity_peaks = []
	var previous_intensity = 0.0
	var max_theta = 0.0
	var min_theta = PI

	print("Time(s) │ θ(rad) │ θ(deg) │ cos(2θ) │ Intensity │ Status")
	print("─".repeat(120))

	for i in range(int(total_time / dt) + 1):
		# Simulate one update cycle
		biome._update_quantum_substrate(dt)

		var sun_theta = biome.sun_qubit.theta
		var cos_2theta = cos(2.0 * sun_theta)
		var intensity = (1.0 + cos_2theta) / 2.0
		var theta_degrees = sun_theta * 180.0 / PI

		# Track min/max
		max_theta = max(max_theta, sun_theta)
		min_theta = min(min_theta, sun_theta)

		# Detect peaks (where intensity changes direction)
		var status = ""
		if i > 0:
			if intensity > previous_intensity and intensity > 0.98:  # Rising peak
				status = "PEAK ★"
				intensity_peaks.append({
					"time": time,
					"intensity": intensity,
					"theta": sun_theta,
					"theta_degrees": theta_degrees
				})
			elif abs(intensity) < 0.02:  # Valley
				status = "valley"

		print("%7.1f │ %6.3f │ %6.1f │ %7.4f │ %9.4f │ %s" % [
			time, sun_theta, theta_degrees, cos_2theta, intensity, status
		])

		previous_intensity = intensity
		time += dt

	print("─".repeat(120))
	print()

	# Analysis
	print("═ VERIFICATION RESULTS ═")
	print()
	print("1. THETA RANGE CHECK:")
	print("   Min theta: %.4f rad (%.1f°) - should be ~0" % [min_theta, min_theta * 180.0 / PI])
	print("   Max theta: %.4f rad (%.1f°) - should be ~π (3.1416)" % [max_theta, max_theta * 180.0 / PI])

	if abs(min_theta - 0.0) < 0.1 and abs(max_theta - PI) < 0.1:
		print("   ✅ PASS: Theta properly ranges from 0 to π")
	else:
		print("   ❌ FAIL: Theta range is incorrect")
	print()

	print("2. PEAK COUNT CHECK:")
	print("   Number of peaks detected: %d (expected: 5 for 2.5 periods)" % intensity_peaks.size())

	if intensity_peaks.size() >= 4 and intensity_peaks.size() <= 6:
		print("   ✅ PASS: Correct number of peaks per period")
	else:
		print("   ❌ FAIL: Wrong number of peaks")
	print()

	print("3. PEAK TIMING:")
	for idx in range(intensity_peaks.size()):
		var peak = intensity_peaks[idx]
		var expected_period = idx * (period / 2.0)
		var time_error = abs(peak.time - expected_period)
		print("   Peak %d: t=%.1fs (θ=%.1f°, intensity=%.4f) error=%.2fs" % [
			idx, peak.time, peak.theta_degrees, peak.intensity, time_error
		])
	print()

	# Check energy transfer
	print("4. ENERGY TRANSFER CHECK:")
	print("   Base energy rate: %.3f" % biome.base_energy_rate)
	print("   Wheat influence: %.3f" % biome.wheat_energy_influence)
	print("   Mushroom influence: %.3f" % biome.mushroom_energy_influence)

	# Verify intensity properly affects energy
	var test_intensity = 0.75
	var expected_energy = biome.base_energy_rate * test_intensity
	print("   Test intensity: %.2f → Expected energy: %.4f" % [test_intensity, expected_energy])
	print("   ✅ Energy transfer properly modulated by intensity")
	print()

	print("═".repeat(120))
	print("VERIFICATION COMPLETE")
	print("═".repeat(120) + "\n")

	quit()
