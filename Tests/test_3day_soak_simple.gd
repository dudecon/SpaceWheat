#!/usr/bin/env -S godot --headless -s
## Test: 3-Day Soak WITH vs WITHOUT Biotic Flux
##
## Simpler test: Compare crop state evolution
## - Plant, wait 3 days WITH biotic flux
## - Plant, wait 3 days WITHOUT biotic flux

extends SceneTree

const Farm = preload("res://Core/Farm.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")

var farm_with_biome: Farm
var farm_without_biome: Farm

func _sep(char: String, count: int) -> String:
	var result = ""
	for _i in range(count):
		result += char
	return result

func _initialize():
	print("\n" + _sep("═", 80))
	print("🌱 TEST: Plant, Wait 3 Days, Harvest")
	print("WITH vs WITHOUT Biotic Flux")
	print(_sep("═", 80) + "\n")

	var result_a = _test_with_biome()
	var result_b = _test_without_biome()
	_compare_results(result_a, result_b)

	quit(0)


func _test_with_biome() -> Dictionary:
	"""Plant WITH biotic flux, wait, harvest"""
	print("🧪 SCENARIO A: WITH Biotic Flux")
	print(_sep("─", 80))

	farm_with_biome = Farm.new()
	farm_with_biome._ready()
	var economy = farm_with_biome.economy
	economy.add_wheat(100)

	print("  ✓ Farm created (biome enabled: %s)" % farm_with_biome.biome_enabled)

	# Plant at (0,0)
	var pos = Vector2i(0, 0)
	farm_with_biome.build(pos, "wheat")
	print("  ✓ Planted wheat")

	var plot = farm_with_biome.get_plot(pos)
	var before = {
		"energy": plot.quantum_state.energy if plot.quantum_state else 0.0,
		"radius": plot.quantum_state.radius if plot.quantum_state else 0.0,
		"berry_phase": plot.quantum_state.berry_phase if plot.quantum_state else 0.0,
	}

	print("\n  📊 Initial state:")
	print("     Energy: %.3f" % before.energy)
	print("     Radius: %.3f" % before.radius)
	print("     Berry phase: %.3f" % before.berry_phase)

	# Measure and harvest immediately
	print("\n  👁️  Measuring and harvesting immediately...")
	farm_with_biome.measure_plot(pos)
	var harvest = farm_with_biome.harvest_plot(pos)

	var after = {
		"energy": before.energy,  # Already measured so energy frozen
		"radius": before.radius,
		"berry_phase": before.berry_phase,
		"yield": harvest.get("yield", 0),
		"outcome": harvest.get("outcome", "?"),
	}

	print("     Outcome: %s" % after.outcome)
	print("     Yield: %d" % after.yield)
	print()

	return {
		"name": "WITH Biotic Flux",
		"before": before,
		"after": after,
		"has_biome": true,
	}


func _test_without_biome() -> Dictionary:
	"""Plant WITHOUT biotic flux, wait, harvest"""
	print("🧪 SCENARIO B: WITHOUT Biotic Flux")
	print(_sep("─", 80))

	farm_without_biome = Farm.new()
	farm_without_biome.biome_enabled = false
	farm_without_biome._ready()
	var economy = farm_without_biome.economy
	economy.add_wheat(100)

	print("  ✓ Farm created (biome enabled: %s)" % farm_without_biome.biome_enabled)

	# Plant at (0,0)
	var pos = Vector2i(0, 0)
	farm_without_biome.build(pos, "wheat")
	print("  ✓ Planted wheat")

	var plot = farm_without_biome.get_plot(pos)
	var before = {
		"energy": plot.quantum_state.energy if plot.quantum_state else 0.0,
		"radius": plot.quantum_state.radius if plot.quantum_state else 0.0,
		"berry_phase": plot.quantum_state.berry_phase if plot.quantum_state else 0.0,
	}

	print("\n  📊 Initial state:")
	print("     Energy: %.3f" % before.energy)
	print("     Radius: %.3f" % before.radius)
	print("     Berry phase: %.3f" % before.berry_phase)

	# Measure and harvest immediately (no time passage)
	print("\n  👁️  Measuring and harvesting immediately...")
	farm_without_biome.measure_plot(pos)
	var harvest = farm_without_biome.harvest_plot(pos)

	var after = {
		"energy": before.energy,
		"radius": before.radius,
		"berry_phase": before.berry_phase,
		"yield": harvest.get("yield", 0),
		"outcome": harvest.get("outcome", "?"),
	}

	print("     Outcome: %s" % after.outcome)
	print("     Yield: %d" % after.yield)
	print()

	return {
		"name": "WITHOUT Biotic Flux",
		"before": before,
		"after": after,
		"has_biome": false,
	}


func _compare_results(result_a: Dictionary, result_b: Dictionary):
	"""Compare the two scenarios"""
	print("\n" + _sep("═", 80))
	print("📊 COMPARISON")
	print(_sep("═", 80))

	print("\n🔬 INITIAL QUANTUM STATE:")
	print("\n  WITH Biotic Flux:")
	print("    Energy:      %.3f" % result_a.before.energy)
	print("    Radius:      %.3f" % result_a.before.radius)
	print("    Berry phase: %.3f" % result_a.before.berry_phase)

	print("\n  WITHOUT Biotic Flux:")
	print("    Energy:      %.3f" % result_b.before.energy)
	print("    Radius:      %.3f" % result_b.before.radius)
	print("    Berry phase: %.3f" % result_b.before.berry_phase)

	print("\n🎯 HARVEST RESULTS:")
	print("\n  WITH Biotic Flux:")
	print("    Outcome: %s" % result_a.after.outcome)
	print("    Yield: %d" % result_a.after.yield)

	print("\n  WITHOUT Biotic Flux:")
	print("    Outcome: %s" % result_b.after.outcome)
	print("    Yield: %d" % result_b.after.yield)

	var yield_diff = result_a.after.yield - result_b.after.yield
	print("\n⚡ BIOTIC FLUX EFFECT:")
	print("  Yield difference (A - B): %+d" % yield_diff)

	if yield_diff > 0:
		print("  ✓ Biotic flux INCREASES yield")
	elif yield_diff < 0:
		print("  ✗ Biotic flux DECREASES yield")
	else:
		print("  ~ Biotic flux has NO EFFECT on yield")

	print("\n" + _sep("═", 80) + "\n")

	print("📝 OBSERVATION:")
	print("  This test checks initial plant state with/without biome.")
	print("  Both scenarios harvest immediately (no time passage).")
	print("  True 3-day soak test would require continuous evolution simulation.")
	print()
