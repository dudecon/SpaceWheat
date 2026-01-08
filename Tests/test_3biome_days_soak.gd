#!/usr/bin/env -S godot --headless -s
## Test: 3 Biome Days Soak WITH vs WITHOUT Biotic Flux
##
## Biome day = 20 seconds (one sun-moon cycle)
## 3 biome days = 60 seconds
##
## Expected: Energy grows 0.3→0.9 in WITH biome scenario
## Actual: Compare actual energy evolution and harvest yields

extends SceneTree

const Farm = preload("res://Core/Farm.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")

var farm_with_biome: Farm
var farm_no_biome: Farm

const BIOME_DAY_SECONDS = 20.0
const SOAK_BIOME_DAYS = 3
const SOAK_TIME_SECONDS = BIOME_DAY_SECONDS * SOAK_BIOME_DAYS  # 60 seconds

var total_yield_with = 0
var total_yield_without = 0

func _sep(char: String, count: int) -> String:
	var result = ""
	for _i in range(count):
		result += char
	return result

func _initialize():
	print("\n" + _sep("═", 80))
	print("🌱 TEST: 3 Biome Days Soak")
	print("Biome day = 20 seconds (1 sun-moon cycle)")
	print("Total: 60 seconds of biotic evolution")
	print(_sep("═", 80) + "\n")

	_test_scenario_a()
	_test_scenario_b()
	_compare_results()

	quit(0)


func _test_scenario_a():
	"""Scenario A: Plant WITH biotic flux, soak 3 days, harvest"""
	print("🧪 SCENARIO A: WITH Biotic Flux (60 seconds)")
	print(_sep("─", 80))

	farm_with_biome = Farm.new()
	farm_with_biome._ready()
	var economy = farm_with_biome.economy
	economy.add_wheat(300)

	print("  ✓ Farm created WITH biome (biome_enabled: %s)" % farm_with_biome.biome_enabled)

	# Plant 3 crops at different positions
	var positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var plots_before = []

	for pos in positions:
		farm_with_biome.build(pos, "wheat")
		var plot = farm_with_biome.get_plot(pos)
		plots_before.append({
			"pos": pos,
			"energy_before": plot.quantum_state.energy if plot.quantum_state else 0.0,
			"radius_before": plot.quantum_state.radius if plot.quantum_state else 0.0,
		})

	print("  ✓ Planted 3 wheat crops")
	print("\n  📊 Initial state (all crops):")
	for data in plots_before:
		print("     [%s] Energy: %.3f, Radius: %.3f" % [data.pos, data.energy_before, data.radius_before])

	# Simulate 3 biome days (60 seconds)
	print("\n  ⏳ Soaking for %d biome days (%d seconds)..." % [SOAK_BIOME_DAYS, int(SOAK_TIME_SECONDS)])
	_simulate_biome_time(farm_with_biome, SOAK_TIME_SECONDS)

	# Check state after soak
	print("\n  📊 After %d-day soak WITH biotic flux:" % SOAK_BIOME_DAYS)
	var plots_after = []
	for i in range(positions.size()):
		var pos = positions[i]
		var plot = farm_with_biome.get_plot(pos)
		var energy_after = plot.quantum_state.energy if plot.quantum_state else 0.0
		var radius_after = plot.quantum_state.radius if plot.quantum_state else 0.0
		var energy_gain = energy_after - plots_before[i].energy_before

		print("     [%s] Energy: %.3f (Δ%+.3f), Radius: %.3f (Δ%+.3f)" % [
			pos,
			energy_after,
			energy_gain,
			radius_after,
			radius_after - plots_before[i].radius_before
		])
		plots_after.append({"pos": pos, "energy_after": energy_after})

	# Measure and harvest
	print("\n  👁️  Measuring and harvesting all 3 crops...")
	var harvest_results = []
	for pos in positions:
		farm_with_biome.measure_plot(pos)
		var harvest = farm_with_biome.harvest_plot(pos)
		var outcome = harvest.get("outcome", "?")
		var yield_val = harvest.get("yield", 0)
		total_yield_with += yield_val
		harvest_results.append({"pos": pos, "outcome": outcome, "yield": yield_val})
		print("     [%s] → %s (yield: %d)" % [pos, outcome, yield_val])

	print("  💰 Total yield WITH biome: %d" % total_yield_with)
	print()


func _test_scenario_b():
	"""Scenario B: Plant WITHOUT biotic flux, wait same time, harvest"""
	print("🧪 SCENARIO B: WITHOUT Biotic Flux (60 seconds, no evolution)")
	print(_sep("─", 80))

	farm_no_biome = Farm.new()
	# Try to create without biome by not enabling it
	farm_no_biome.biome_enabled = false
	farm_no_biome._ready()
	var economy = farm_no_biome.economy
	economy.add_wheat(300)

	print("  ✓ Farm created (biome_enabled: %s, biome exists: %s)" % [farm_no_biome.biome_enabled, farm_no_biome.biome != null])

	# Plant 3 crops at different positions
	var positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var plots_before = []

	for pos in positions:
		farm_no_biome.build(pos, "wheat")
		var plot = farm_no_biome.get_plot(pos)
		plots_before.append({
			"pos": pos,
			"energy_before": plot.quantum_state.energy if plot.quantum_state else 0.0,
			"radius_before": plot.quantum_state.radius if plot.quantum_state else 0.0,
		})

	print("  ✓ Planted 3 wheat crops")
	print("\n  📊 Initial state (all crops):")
	for data in plots_before:
		print("     [%s] Energy: %.3f, Radius: %.3f" % [data.pos, data.energy_before, data.radius_before])

	# Without biome, time just passes (no evolution)
	print("\n  ⏳ Time passes for %d seconds (no biotic evolution)..." % int(SOAK_TIME_SECONDS))
	# Just wait, don't call biome evolution

	# Check state after (should be unchanged)
	print("\n  📊 After %d-day wait WITHOUT biotic flux:" % SOAK_BIOME_DAYS)
	for i in range(positions.size()):
		var pos = positions[i]
		var plot = farm_no_biome.get_plot(pos)
		var energy_after = plot.quantum_state.energy if plot.quantum_state else 0.0
		var radius_after = plot.quantum_state.radius if plot.quantum_state else 0.0
		var energy_gain = energy_after - plots_before[i].energy_before

		print("     [%s] Energy: %.3f (Δ%+.3f), Radius: %.3f (Δ%+.3f)" % [
			pos,
			energy_after,
			energy_gain,
			radius_after,
			radius_after - plots_before[i].radius_before
		])

	# Measure and harvest
	print("\n  👁️  Measuring and harvesting all 3 crops...")
	var harvest_results = []
	for pos in positions:
		farm_no_biome.measure_plot(pos)
		var harvest = farm_no_biome.harvest_plot(pos)
		var outcome = harvest.get("outcome", "?")
		var yield_val = harvest.get("yield", 0)
		total_yield_without += yield_val
		harvest_results.append({"pos": pos, "outcome": outcome, "yield": yield_val})
		print("     [%s] → %s (yield: %d)" % [pos, outcome, yield_val])

	print("  💰 Total yield WITHOUT biome: %d" % total_yield_without)
	print()


func _simulate_biome_time(farm: Farm, elapsed_seconds: float):
	"""Simulate biome evolution over time"""
	if not farm.biome_enabled or not farm.biome:
		print("     ⚠️  Biome not active, skipping evolution")
		return

	# Simulate in small increments (10ms steps = 6000 steps for 60 seconds)
	var dt = 0.01  # 10ms per step
	var steps = int(elapsed_seconds / dt)

	for step in range(steps):
		farm.biome._process(dt)
		# Print progress every 20 days (400 steps of 20 per day = 100 steps per biome day)
		if (step + 1) % 100 == 0:
			var days_passed = float(step + 1) / (BIOME_DAY_SECONDS / dt)
			print("     ... %.1f biome days passed" % days_passed)


func _compare_results():
	"""Compare WITH vs WITHOUT biome"""
	print("\n" + _sep("═", 80))
	print("📊 BIOTIC FLUX EFFECT (3 Biome Days)")
	print(_sep("═", 80))

	var yield_diff = total_yield_with - total_yield_without
	var yield_pct = 0.0
	if total_yield_without > 0:
		yield_pct = (float(yield_diff) / float(total_yield_without)) * 100.0

	print("\n🎯 HARVEST TOTALS (3 crops × 3 scenarios):")
	print("  WITH biotic flux:    %d" % total_yield_with)
	print("  WITHOUT biotic flux: %d" % total_yield_without)
	print("  Difference (A - B):  %+d (%+.1f%%)" % [yield_diff, yield_pct])

	print("\n⚡ INTERPRETATION:")
	if yield_diff > 0.1:
		print("  ✓ Biotic flux INCREASES yield (crops grew stronger)")
		print("  ✓ Energy transfer system working: biome evolves crops over time")
	elif yield_diff < -0.1:
		print("  ✗ Biotic flux DECREASES yield (unexpected)")
	else:
		print("  ~ Biotic flux has NO MEASURABLE EFFECT on yield")
		print("  ⚠️  Possible causes:")
		print("     1. Energy transfer not implemented")
		print("     2. Biome evolution doesn't affect yield")
		print("     3. Yield calculation doesn't use energy (uses frozen_energy instead)")

	print("\n" + _sep("═", 80) + "\n")
