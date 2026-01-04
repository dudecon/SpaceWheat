#!/usr/bin/env godot
extends Node

func _ready():
	print("\n" + "="*70)
	print("PHASE 4 METHOD VERIFICATION TEST")
	print("="*70 + "\n")

	var results = {}

	# Load BiomeBase script class
	var BiomeBase = load("res://Core/Environment/BiomeBase.gd")
	var FarmInputHandler = load("res://UI/FarmInputHandler.gd")

	if not BiomeBase:
		print("❌ Failed to load BiomeBase.gd")
		get_tree().quit()
		return

	if not FarmInputHandler:
		print("❌ Failed to load FarmInputHandler.gd")
		get_tree().quit()
		return

	print("✅ BiomeBase.gd loaded")
	print("✅ FarmInputHandler.gd loaded\n")

	# ========================================
	# Phase 4.1: Icon Modification API
	# ========================================
	print("[Phase 4.1] Icon Modification API")
	print("-" * 70)
	var phase41_methods = ["boost_coupling", "tune_decoherence", "add_time_dependent_driver"]
	var phase41_count = 0

	for method in phase41_methods:
		if BiomeBase.has_method(method):
			print("  ✅ BiomeBase.%s()" % method)
			phase41_count += 1
		else:
			print("  ❌ BiomeBase.%s() - MISSING" % method)

	results["Phase 4.1"] = phase41_count == 3
	print("  Result: %d/3 methods found\n" % phase41_count)

	# ========================================
	# Phase 4.2: Lindblad Operations
	# ========================================
	print("[Phase 4.2] Lindblad Channel Operations")
	print("-" * 70)
	var phase42_methods = ["pump_to_emoji", "reset_to_pure_state", "reset_to_mixed_state"]
	var phase42_count = 0

	for method in phase42_methods:
		if BiomeBase.has_method(method):
			print("  ✅ BiomeBase.%s()" % method)
			phase42_count += 1
		else:
			print("  ❌ BiomeBase.%s() - MISSING" % method)

	results["Phase 4.2"] = phase42_count == 3
	print("  Result: %d/3 methods found\n" % phase42_count)

	# ========================================
	# Phase 4.3: Gate Infrastructure
	# ========================================
	print("[Phase 4.3] Gate Infrastructure")
	print("-" * 70)
	var phase43_methods = ["create_cluster_state", "set_measurement_trigger", "remove_entanglement", "batch_entangle"]
	var phase43_count = 0

	for method in phase43_methods:
		if BiomeBase.has_method(method):
			print("  ✅ BiomeBase.%s()" % method)
			phase43_count += 1
		else:
			print("  ❌ BiomeBase.%s() - MISSING" % method)

	results["Phase 4.3"] = phase43_count == 4
	print("  Result: %d/4 methods found\n" % phase43_count)

	# ========================================
	# Phase 4.4: Energy Tap System
	# ========================================
	print("[Phase 4.4] Energy Tap System")
	print("-" * 70)
	var phase44_methods = ["place_energy_tap", "initialize_energy_tap_system", "get_tap_flux", "clear_tap_flux"]
	var phase44_count = 0

	for method in phase44_methods:
		if BiomeBase.has_method(method):
			print("  ✅ BiomeBase.%s()" % method)
			phase44_count += 1
		else:
			print("  ❌ BiomeBase.%s() - MISSING" % method)

	results["Phase 4.4"] = phase44_count == 4
	print("  Result: %d/4 methods found\n" % phase44_count)

	# ========================================
	# Verify FarmInputHandler Actions
	# ========================================
	print("[FarmInputHandler] Action Methods")
	print("-" * 70)
	var action_methods = [
		"_action_boost_coupling",
		"_action_tune_decoherence",
		"_action_add_driver",
		"_action_pump_to_wheat",
		"_action_reset_to_pure",
		"_action_reset_to_mixed",
		"_action_entangle_batch",
		"_action_cluster",
		"_action_measure_trigger",
		"_action_remove_gates",
		"_action_place_energy_tap"
	]
	var action_count = 0

	for method in action_methods:
		if FarmInputHandler.has_method(method):
			print("  ✅ FarmInputHandler.%s()" % method)
			action_count += 1
		else:
			print("  ❌ FarmInputHandler.%s() - MISSING" % method)

	results["FarmInputHandler"] = action_count == 11
	print("  Result: %d/11 action methods found\n" % action_count)

	# ========================================
	# Summary
	# ========================================
	print("="*70)
	print("SUMMARY")
	print("="*70 + "\n")

	var total_passed = 0
	for phase in results.keys():
		var status = "✅ PASS" if results[phase] else "❌ FAIL"
		print("%s: %s" % [phase.to_upper(), status])
		if results[phase]:
			total_passed += 1

	print("\nTotal: %d/5 test suites passed" % total_passed)

	if total_passed == 5:
		print("\n✅ ALL PHASE 4 TESTS PASSED")
		print("All 11 BiomeBase API methods and 11 action methods verified!\n")
	else:
		print("\n⚠️  SOME TESTS FAILED\n")

	print("="*70 + "\n")

	# Count total methods verified
	var total_methods = phase41_count + phase42_count + phase43_count + phase44_count + action_count
	print("TOTAL METHODS VERIFIED: %d/22" % total_methods)
	print("  - BiomeBase API Methods: %d/11" % (phase41_count + phase42_count + phase43_count + phase44_count))
	print("  - FarmInputHandler Actions: %d/11\n" % action_count)

	get_tree().quit()
