#!/usr/bin/env -S godot --headless -s
extends SceneTree

## ⚠️ OUT OF SYNC WITH V2 ARCHITECTURE ⚠️
## This test uses the OLD Plot-based API (farm.build, farm.measure_plot, farm.harvest_plot)
## The v2 architecture uses Terminals via ProbeActions (action_explore, action_measure, action_pop)
## DO NOT RUN - needs rewrite to use ProbeActions + Terminal system
##
## CLAUDE'S COMPREHENSIVE SPACEWHEAT PLAYTEST
## Testing: Full kitchen production chain + save/load + profit strategies + bug hunting
## Looking for: Quantum<->classical bridging issues, unusual profit mechanics, edge cases

const Farm = preload("res://Core/Farm.gd")

var farm: Farm = null
var test_results = {
	"bugs_found": [],
	"profit_strategies": [],
	"quantum_classical_issues": [],
	"save_load_status": "NOT_TESTED"
}

func _initialize():
	print("\n" + "=".repeat(80))
	print("🎮 CLAUDE'S COMPREHENSIVE SPACEWHEAT PLAYTEST")
	print("=".repeat(80))
	print("Testing: Production chain + Save/Load + Profit strategies + Bug hunting")
	print()

	await get_root().ready

	# Phase 1: Full kitchen production chain
	print("\n" + "─".repeat(80))
	print("PHASE 1: Full Kitchen Production Chain")
	print("─".repeat(80))
	await run_full_kitchen_test()

	# Phase 2: Save/Load mid-game
	print("\n" + "─".repeat(80))
	print("PHASE 2: Save/Load Testing (Mid-Game)")
	print("─".repeat(80))
	await test_save_load_midgame()

	# Phase 3: Unusual profit strategies
	print("\n" + "─".repeat(80))
	print("PHASE 3: Unusual Profit Strategies")
	print("─".repeat(80))
	await test_profit_strategies()

	# Phase 4: Quantum<->Classical bridging tests
	print("\n" + "─".repeat(80))
	print("PHASE 4: Quantum<->Classical Bridging Tests")
	print("─".repeat(80))
	await test_quantum_classical_bridge()

	# Report findings
	print_final_report()

	quit(0 if test_results.bugs_found.is_empty() else 1)


func run_full_kitchen_test():
	"""Full kitchen production chain: plant → entangle → measure → harvest → mill → market"""

	print("🍳 Starting full kitchen production chain...")

	# Create farm
	farm = Farm.new()
	get_root().add_child(farm)

	# Wait for initialization
	for i in range(10):
		await process_frame

	var grid = farm.grid
	if not grid:
		record_bug("Farm grid not initialized after 10 frames")
		return

	print("✅ Farm initialized: %dx%d grid, 4 biomes" % [grid.grid_width, grid.grid_height])

	# Step 1: Plant wheat in BioticFlux
	print("\n📌 Step 1: Planting wheat...")
	var plant_positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]

	for pos in plant_positions:
		var success = farm.build(pos, "wheat")
		if success:
			print("  ✓ Planted wheat at %s" % pos)
		else:
			record_bug("Failed to plant wheat at %s" % pos)

	await advance_time(3.0)  # Let quantum evolution run

	# Step 2: Create entanglements
	print("\n📌 Step 2: Creating entanglements...")

	# Try to entangle plots (0,0) ↔ (1,0) and (1,0) ↔ (2,0)
	# This creates a chain: 0 ↔ 1 ↔ 2
	var entangle_result_1 = farm.entangle_plots(Vector2i(0, 0), Vector2i(1, 0))
	if entangle_result_1:
		print("  ✓ Entangled (0,0) ↔ (1,0)")
	else:
		record_bug("Failed to entangle (0,0) ↔ (1,0)")

	var entangle_result_2 = farm.entangle_plots(Vector2i(1, 0), Vector2i(2, 0))
	if entangle_result_2:
		print("  ✓ Entangled (1,0) ↔ (2,0)")
	else:
		record_bug("Failed to entangle (1,0) ↔ (2,0)")

	await advance_time(2.0)

	# Step 3: Measure plots
	print("\n📌 Step 3: Measuring plots...")

	for pos in plant_positions:
		var outcome = farm.measure_plot(pos)
		if outcome:
			print("  ✓ Measured %s → %s" % [pos, outcome])
		else:
			record_bug("Failed to measure plot at %s" % pos)

	await advance_time(1.0)

	# Step 4: Harvest
	print("\n📌 Step 4: Harvesting...")
	var wheat_before = farm.economy.get_resource("🌾")

	for pos in plant_positions:
		var result = farm.harvest_plot(pos)
		if result.get("success", false):
			var yield_amount = result.get("yield", 0)
			print("  ✓ Harvested %s: %d yield" % [pos, yield_amount])
		else:
			record_bug("Failed to harvest plot at %s: %s" % [pos, result])

	var wheat_after = farm.economy.get_resource("🌾")
	var wheat_gained = wheat_after - wheat_before
	print("  💰 Wheat: %d → %d (gained %d)" % [wheat_before, wheat_after, wheat_gained])

	if wheat_gained <= 0:
		record_quantum_classical_issue("Harvest yielded no wheat gain (before: %d, after: %d)" % [wheat_before, wheat_after])

	await advance_time(1.0)

	# Step 5: Mill wheat → flour
	print("\n📌 Step 5: Milling wheat to flour...")

	# Find a mill plot (type 3) or build one
	var mill_pos = find_plot_of_type(3)  # PlotType.MILL = 3
	if mill_pos == Vector2i(-1, -1):
		# Build a mill
		mill_pos = Vector2i(3, 0)
		var mill_built = farm.build(mill_pos, "mill")
		if mill_built:
			print("  ✓ Built mill at %s" % mill_pos)
		else:
			record_bug("Failed to build mill at %s" % mill_pos)
			return

	# Try to mill wheat
	var wheat_to_mill = min(10, farm.economy.get_resource("🌾"))
	var flour_before = farm.economy.get_resource("🍞")

	# NOTE: Mill production not yet implemented in Farm
	# farm.activate_production() doesn't exist - mills are structural only
	print("  ⚠️  Mill production not implemented (structural only)")
	# if wheat_to_mill >= 10:
	# 	var mill_result = farm.activate_production(mill_pos, "mill")
	# 	if mill_result.get("success", false):
	# 		var flour_after = farm.economy.get_resource("🍞")
	# 		print("  ✓ Milled %d wheat → %d flour" % [wheat_to_mill, flour_after - flour_before])
	# 	else:
	# 		record_bug("Failed to mill wheat: %s" % mill_result)
	# else:
	# 	print("  ⚠️  Not enough wheat to mill (have %d, need 10)" % wheat_to_mill)

	await advance_time(1.0)

	# Step 6: Sell at market
	print("\n📌 Step 6: Selling flour at market...")

	var market_pos = find_plot_of_type(4)  # PlotType.MARKET = 4
	if market_pos == Vector2i(-1, -1):
		# Build a market
		market_pos = Vector2i(4, 0)
		var market_built = farm.build(market_pos, "market")
		if market_built:
			print("  ✓ Built market at %s" % market_pos)
		else:
			record_bug("Failed to build market at %s" % market_pos)
			return

	var flour_to_sell = farm.economy.get_resource("🍞")
	var credits_before = farm.economy.get_resource("💰")

	# NOTE: Market trading not yet implemented in Farm
	# farm.activate_production() doesn't exist - markets are structural only
	print("  ⚠️  Market trading not implemented (structural only)")
	# if flour_to_sell > 0:
	# 	var market_result = farm.activate_production(market_pos, "market")
	# 	if market_result.get("success", false):
	# 		var credits_after = farm.economy.get_resource("💰")
	# 		var profit = credits_after - credits_before
	# 		print("  ✓ Sold %d flour → %d credits (profit: %d)" % [flour_to_sell, credits_after, profit])
	# 		if profit <= 0:
	# 			record_quantum_classical_issue("Market sale yielded no profit (before: %d, after: %d)" % [credits_before, credits_after])
	# 	else:
	# 		record_bug("Failed to sell at market: %s" % market_result)
	# else:
	# 	print("  ⚠️  No flour to sell")

	print("\n✅ Full kitchen test complete!")
	print_economy_state()


func test_save_load_midgame():
	"""Test save/load in the middle of gameplay"""

	print("💾 Testing save/load during active gameplay...")

	# Capture pre-save state
	var pre_save = capture_game_state()
	print("\n📊 Pre-save state:")
	print_state_summary(pre_save)

	# SAVE
	var gsm = get_root().get_node_or_null("/root/GameStateManager")
	if not gsm:
		record_bug("GameStateManager singleton not found - save/load unavailable")
		test_results.save_load_status = "FAILED - No GameStateManager"
		return

	gsm.active_farm = farm
	var save_success = gsm.save_game(0)

	if not save_success:
		record_bug("Save game failed!")
		test_results.save_load_status = "FAILED - Save error"
		return

	print("\n✅ Game saved to slot 0")

	# Destroy farm (simulate quit)
	gsm.active_farm = null
	farm.queue_free()
	for i in range(5):
		await process_frame
	farm = null

	print("🗑️  Farm destroyed (simulating quit)")

	# Recreate farm (simulate restart)
	farm = Farm.new()
	get_root().add_child(farm)

	for i in range(10):
		await process_frame

	print("🔄 Farm recreated (simulating restart)")

	# LOAD
	gsm.active_farm = farm
	var load_success = gsm.load_game_state(0)

	if not load_success:
		record_bug("Load game failed!")
		test_results.save_load_status = "FAILED - Load error"
		return

	print("✅ Game loaded from slot 0")

	# Wait for state application
	for i in range(5):
		await process_frame

	# Capture post-load state
	var post_load = capture_game_state()
	print("\n📊 Post-load state:")
	print_state_summary(post_load)

	# Compare states
	var diffs = compare_states(pre_save, post_load)

	if diffs.is_empty():
		print("\n✅ PERFECT MATCH - All state preserved!")
		test_results.save_load_status = "PASSED"
	else:
		print("\n❌ STATE MISMATCH - %d differences:" % diffs.size())
		for diff in diffs:
			print("  - %s" % diff)
			record_bug("Save/Load: %s" % diff)
		test_results.save_load_status = "FAILED - State mismatch"


func test_profit_strategies():
	"""Test unusual profit strategies and edge cases"""

	print("💡 Testing unusual profit strategies...")

	# Strategy 1: Measure-before-growth (does early measurement yield different results?)
	print("\n🧪 Strategy 1: Early vs Late Measurement")

	# Plant two plots
	var early_pos = Vector2i(0, 1)
	var late_pos = Vector2i(1, 1)

	farm.build(early_pos, "wheat")
	farm.build(late_pos, "wheat")

	# Measure early plot immediately
	await advance_time(0.5)
	var early_outcome = farm.measure_plot(early_pos)
	print("  Early measurement (0.5s): %s" % early_outcome)

	var early_harvest = farm.harvest_plot(early_pos)
	var early_yield = early_harvest.get("yield", 0)
	print("  Early yield: %d" % early_yield)

	# Wait for late plot to mature
	await advance_time(10.0)
	var late_outcome = farm.measure_plot(late_pos)
	print("  Late measurement (10.5s): %s" % late_outcome)

	var late_harvest = farm.harvest_plot(late_pos)
	var late_yield = late_harvest.get("yield", 0)
	print("  Late yield: %d" % late_yield)

	var yield_diff = late_yield - early_yield
	if abs(yield_diff) > 0:
		var strategy = "Wait for quantum evolution - %d more yield!" % yield_diff if yield_diff > 0 else "Early harvest preferred - %d yield penalty for waiting" % abs(yield_diff)
		record_profit_strategy(strategy)

	# Strategy 2: Entanglement farming (does entanglement boost yields?)
	print("\n🧪 Strategy 2: Entanglement Yield Boost")

	# Plant 3 plots
	var solo_pos = Vector2i(2, 1)
	var entangled_a = Vector2i(3, 1)
	var entangled_b = Vector2i(4, 1)

	farm.build(solo_pos, "wheat")
	farm.build(entangled_a, "wheat")
	farm.build(entangled_b, "wheat")

	await advance_time(1.0)

	# Entangle two plots
	farm.entangle_plots(entangled_a, entangled_b)

	await advance_time(5.0)

	# Measure and harvest all
	farm.measure_plot(solo_pos)
	farm.measure_plot(entangled_a)
	farm.measure_plot(entangled_b)

	var solo_result = farm.harvest_plot(solo_pos)
	var entangled_a_result = farm.harvest_plot(entangled_a)
	var entangled_b_result = farm.harvest_plot(entangled_b)

	var solo_yield = solo_result.get("yield", 0)
	var entangled_avg = (entangled_a_result.get("yield", 0) + entangled_b_result.get("yield", 0)) / 2.0

	print("  Solo yield: %d" % solo_yield)
	print("  Entangled average: %.1f" % entangled_avg)

	if entangled_avg > solo_yield * 1.1:  # 10% boost
		record_profit_strategy("Entanglement farming yields %.0f%% more!" % ((entangled_avg / solo_yield - 1.0) * 100))


func test_quantum_classical_bridge():
	"""Test quantum<->classical bridging - are quantum states properly converted to economy resources?"""

	print("⚛️  Testing quantum<->classical bridging...")

	# Test 1: Energy conservation (does quantum energy → credits properly?)
	print("\n🧪 Test 1: Energy Conservation")

	var pos = Vector2i(5, 1)
	farm.build(pos, "wheat")

	await advance_time(1.0)

	# Check quantum state before measurement
	var biome = farm.biotic_flux_biome
	# Note: In bath-first mode, use get_qubit_at() instead of direct quantum_states access
	var qubit = biome.get_qubit_at(pos) if biome and biome.has_method("get_qubit_at") else null

	if qubit:
		var quantum_energy = qubit.energy
		print("  Quantum energy before measurement: %.3f" % quantum_energy)

		# Measure
		var credits_before = farm.economy.get_resource("💰")
		farm.measure_plot(pos)

		# Harvest
		var harvest_result = farm.harvest_plot(pos)
		var credits_after = farm.economy.get_resource("💰")
		var yield_gained = harvest_result.get("yield", 0)
		var credits_gained = credits_after - credits_before

		print("  Yield: %d, Credits gained: %d" % [yield_gained, credits_gained])
		print("  Quantum→Classical conversion ratio: %.3f credits per quantum energy" % (credits_gained / quantum_energy if quantum_energy > 0 else 0))

		# Check if conversion makes sense (quantum energy should map to credits somehow)
		if quantum_energy > 0.5 and credits_gained == 0:
			record_quantum_classical_issue("High quantum energy (%.3f) produced 0 credits" % quantum_energy)

	else:
		record_bug("Cannot access quantum state for plot %s (bath-first mode issue?)" % pos)

	# Test 2: Bath amplitude → plot state bridging
	print("\n🧪 Test 2: Bath Amplitude Bridging")

	if biome and "bath" in biome and biome.bath:
		var bath = biome.bath

		# Check wheat amplitude
		var wheat_amp = bath.get_amplitude("🌾")
		print("  Bath wheat amplitude: %.3f + %.3fi (norm: %.3f)" % [wheat_amp.re, wheat_amp.im, wheat_amp.abs()])

		# Plant a wheat plot
		var test_pos = Vector2i(0, 1)
		farm.build(test_pos, "wheat")

		await advance_time(5.0)

		# Check if plot inherited bath amplitude
		var plot_qubit = biome.get_qubit_at(test_pos) if biome.has_method("get_qubit_at") else null

		if plot_qubit:
			print("  Plot qubit energy after 5s: %.3f" % plot_qubit.energy)

			# Energy should have grown from bath interaction
			if plot_qubit.energy < 0.1:
				record_quantum_classical_issue("Plot energy (%.3f) very low despite bath amplitude (%.3f)" % [plot_qubit.energy, wheat_amp.norm()])
		else:
			record_bug("Cannot access plot qubit at %s (bath-first mode issue?)" % test_pos)
	else:
		print("  ⚠️  Bath not available in biome")


func advance_time(seconds: float):
	"""Advance simulation time"""
	for i in range(int(seconds * 2)):  # 2 frames per second
		await process_frame


func find_plot_of_type(plot_type: int) -> Vector2i:
	"""Find a plot of specific type"""
	for y in range(farm.grid.grid_height):
		for x in range(farm.grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot and plot.plot_type == plot_type:
				return pos
	return Vector2i(-1, -1)


func capture_game_state() -> Dictionary:
	"""Capture comprehensive game state for comparison"""
	var state = {}

	# Economy
	state.economy = {
		"credits": farm.economy.get_resource("💰"),
		"wheat": farm.economy.get_resource("🌾"),
		"labor": farm.economy.get_resource("👥"),
		"flour": farm.economy.get_resource("🍞"),
		"mushroom": farm.economy.get_resource("🍄"),
		"detritus": farm.economy.get_resource("🍂")
	}

	# Grid
	state.grid_width = farm.grid.grid_width
	state.grid_height = farm.grid.grid_height

	# Plots
	state.plots = []
	for y in range(farm.grid.grid_height):
		for x in range(farm.grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot:
				state.plots.append({
					"position": pos,
					"type": plot.plot_type,
					"is_planted": plot.is_planted,
					"has_been_measured": plot.has_been_measured
				})

	# Goals
	state.goal_index = farm.goals.current_goal_index if farm.goals else 0

	return state


func compare_states(pre: Dictionary, post: Dictionary) -> Array:
	"""Compare two game states and return differences"""
	var diffs = []

	# Economy
	for resource in ["credits", "wheat", "labor", "flour", "mushroom", "detritus"]:
		if pre.economy[resource] != post.economy[resource]:
			diffs.append("Economy %s: %d → %d" % [resource, pre.economy[resource], post.economy[resource]])

	# Grid
	if pre.grid_width != post.grid_width or pre.grid_height != post.grid_height:
		diffs.append("Grid size: %dx%d → %dx%d" % [pre.grid_width, pre.grid_height, post.grid_width, post.grid_height])

	# Plots
	if pre.plots.size() != post.plots.size():
		diffs.append("Plot count: %d → %d" % [pre.plots.size(), post.plots.size()])

	for i in range(min(pre.plots.size(), post.plots.size())):
		var p1 = pre.plots[i]
		var p2 = post.plots[i]

		if p1.is_planted != p2.is_planted:
			diffs.append("Plot %s planted: %s → %s" % [p1.position, p1.is_planted, p2.is_planted])
		if p1.has_been_measured != p2.has_been_measured:
			diffs.append("Plot %s measured: %s → %s" % [p1.position, p1.has_been_measured, p2.has_been_measured])

	# Goals
	if pre.goal_index != post.goal_index:
		diffs.append("Goal index: %d → %d" % [pre.goal_index, post.goal_index])

	return diffs


func print_state_summary(state: Dictionary):
	"""Print summary of game state"""
	print("  💰 Economy:")
	print("    - Credits: %d" % state.economy.credits)
	print("    - Wheat: %d" % state.economy.wheat)
	print("    - Flour: %d" % state.economy.flour)
	print("  📏 Grid: %dx%d (%d plots)" % [state.grid_width, state.grid_height, state.plots.size()])
	print("  🎯 Goal: %d" % state.goal_index)


func print_economy_state():
	"""Print current economy state"""
	print("\n💰 Economy State:")
	print("  🌾 Wheat: %d" % farm.economy.get_resource("🌾"))
	print("  💰 Credits: %d" % farm.economy.get_resource("💰"))
	print("  👥 Labor: %d" % farm.economy.get_resource("👥"))
	print("  🍞 Flour: %d" % farm.economy.get_resource("🍞"))
	print("  🍄 Mushroom: %d" % farm.economy.get_resource("🍄"))
	print("  🍂 Detritus: %d" % farm.economy.get_resource("🍂"))


func record_bug(message: String):
	"""Record a bug found during testing"""
	print("  ❌ BUG: %s" % message)
	test_results.bugs_found.append(message)


func record_profit_strategy(message: String):
	"""Record an unusual profit strategy discovered"""
	print("  💡 STRATEGY: %s" % message)
	test_results.profit_strategies.append(message)


func record_quantum_classical_issue(message: String):
	"""Record a quantum<->classical bridging issue"""
	print("  ⚛️  BRIDGE ISSUE: %s" % message)
	test_results.quantum_classical_issues.append(message)


func print_final_report():
	"""Print comprehensive test report"""

	print("\n\n" + "=".repeat(80))
	print("📊 COMPREHENSIVE PLAYTEST RESULTS")
	print("=".repeat(80))

	print("\n💾 Save/Load Status: %s" % test_results.save_load_status)

	print("\n❌ Bugs Found: %d" % test_results.bugs_found.size())
	for bug in test_results.bugs_found:
		print("  - %s" % bug)

	print("\n💡 Profit Strategies Discovered: %d" % test_results.profit_strategies.size())
	for strategy in test_results.profit_strategies:
		print("  - %s" % strategy)

	print("\n⚛️  Quantum<->Classical Bridging Issues: %d" % test_results.quantum_classical_issues.size())
	for issue in test_results.quantum_classical_issues:
		print("  - %s" % issue)

	print("\n" + "=".repeat(80))

	if test_results.bugs_found.is_empty() and test_results.quantum_classical_issues.is_empty():
		print("✅ ALL TESTS PASSED - No critical issues found!")
	else:
		print("⚠️  ISSUES FOUND - See details above")

	print("=".repeat(80) + "\n")
