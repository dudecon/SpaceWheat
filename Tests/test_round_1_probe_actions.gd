#!/usr/bin/env -S godot --headless -s
extends SceneTree

## TOOL 1 PROBE TEST SUITE - Round 1
## Tests Explore → Measure → Pop action sequence

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

var farm = null
var grid = null
var economy = null
var plot_pool = null
var biome_list = {}

var frame_count = 0
var scene_loaded = false
var tests_done = false

var issues = []
var test_count = 0
var pass_count = 0

func _init():
	print("\n" + "═".repeat(80))
	print("🔍 TOOL 1 PROBE ACTIONS TEST - Round 1")
	print("═".repeat(80))

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		print("\n⏳ Frame 5: Loading main scene...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			var instance = scene.instantiate()
			root.add_child(instance)
			scene_loaded = true

			var boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)
		else:
			print("   ❌ Failed to load scene")
			quit(1)

func _on_game_ready():
	if tests_done:
		return
	tests_done = true

	print("\n✅ Game ready! Starting PROBE action testing...\n")

	var fv = root.get_node_or_null("FarmView")
	if not fv or not fv.farm:
		print("❌ Farm not found")
		print_findings()
		quit()
		return

	farm = fv.farm
	grid = farm.grid
	economy = farm.economy
	plot_pool = farm.plot_pool
	biome_list = grid.biomes

	# Bootstrap resources
	economy.add_resource("💰", 5000, "test_bootstrap")

	print("Systems initialized:")
	print("   Farm: ✅")
	print("   Grid: ✅ (%d plots)" % grid.plots.size())
	print("   Biomes: ✅ (%d)" % biome_list.size())
	print("   Economy: 💰 = %d" % economy.get_resource("💰"))

	# Run tests
	_test_explore_basic()
	_test_explore_multiple()
	_test_measure_and_drain()
	_test_pop_credit_conversion()
	_test_explore_measure_pop_sequence()
	_test_cross_biome()

	print_findings()
	quit()

# ═══════════════════════════════════════════════════════════════════════════

func _test_explore_basic():
	print("\n" + "─".repeat(80))
	print("TEST 1: EXPLORE - Basic Functionality")
	print("─".repeat(80))

	var biome_name = biome_list.keys()[0]
	var biome = biome_list[biome_name]

	var result = ProbeActions.action_explore(plot_pool, biome)

	_assert("explore_success", result.get("success", false), "EXPLORE returns success")
	_assert("terminal_allocated", "terminal" in result and result["terminal"] != null, "Terminal allocated")
	_assert("register_allocated", result.get("register_id", -1) >= 0, "Register ID valid (>= 0)")
	_assert("probability_valid", result.get("probability", -1) >= 0.0 and result.get("probability", 2.0) <= 1.0, "Probability 0.0-1.0")

	if result.get("success"):
		print("   ✅ Basic explore works: terminal=%s, register=%d, prob=%.4f" % [
			result["terminal"].terminal_id,
			result["register_id"],
			result.get("probability", 0)
		])

# ═══════════════════════════════════════════════════════════════════════════

func _test_explore_multiple():
	print("\n" + "─".repeat(80))
	print("TEST 2: EXPLORE - Multiple Allocations")
	print("─".repeat(80))

	var biome_name = biome_list.keys()[0]
	var biome = biome_list[biome_name]

	var allocated_registers = []

	# Try 3 explores
	for i in range(3):
		var result = ProbeActions.action_explore(plot_pool, biome)
		if result.get("success"):
			allocated_registers.append(result["register_id"])
			print("   Explore %d: register=%d" % [i+1, result["register_id"]])
		else:
			_assert("explore_%d" % i, false, "EXPLORE %d succeeded" % (i+1))
			print("   ✅ Out of registers after %d explores (expected)" % i)
			break

	_assert("multiple_registers", allocated_registers.size() >= 2, "Allocated 2+ registers (limited by %d-qubit biome)" % allocated_registers.size())

	# Check for duplicates using a set
	var unique_set = {}
	for reg in allocated_registers:
		unique_set[reg] = true

	_assert("registers_unique", unique_set.size() == allocated_registers.size(), "All registers unique")

# ═══════════════════════════════════════════════════════════════════════════

func _test_measure_and_drain():
	print("\n" + "─".repeat(80))
	print("TEST 3: MEASURE - Probability Drain")
	print("─".repeat(80))

	var biome_name = biome_list.keys()[0]
	var biome = biome_list[biome_name]

	# Explore to get terminal
	var explore_result = ProbeActions.action_explore(plot_pool, biome)
	if not explore_result.get("success"):
		_assert("measure_explore", false, "EXPLORE succeeded for MEASURE test")
		return

	var terminal = explore_result["terminal"]
	var initial_prob = explore_result.get("probability", 0)

	# Measure
	var measure_result = ProbeActions.action_measure(terminal, biome)

	_assert("measure_success", measure_result.get("success", false), "MEASURE returns success")
	_assert("measure_outcome", measure_result.get("outcome", "") != "", "MEASURE returns outcome emoji")
	_assert("recorded_probability", measure_result.get("recorded_probability", -1) >= 0, "MEASURE records probability")

	var recorded = measure_result.get("recorded_probability", 0)
	var drained = measure_result.get("was_drained", false)

	_assert("drain_applied", drained, "Probability was drained")

	if measure_result.get("success"):
		print("   ✅ MEASURE works: outcome=%s, recorded=%.4f, drained=%s" % [
			measure_result.get("outcome"),
			recorded,
			drained
		])

# ═══════════════════════════════════════════════════════════════════════════

func _test_pop_credit_conversion():
	print("\n" + "─".repeat(80))
	print("TEST 4: POP - Credit Conversion")
	print("─".repeat(80))

	var biome_name = biome_list.keys()[0]
	var biome = biome_list[biome_name]

	# Explore
	var explore_result = ProbeActions.action_explore(plot_pool, biome)
	if not explore_result.get("success"):
		_assert("pop_explore", false, "EXPLORE succeeded for POP test")
		return

	var terminal = explore_result["terminal"]

	# Measure
	var measure_result = ProbeActions.action_measure(terminal, biome)
	if not measure_result.get("success"):
		_assert("pop_measure", false, "MEASURE succeeded for POP test")
		return

	var recorded_prob = measure_result.get("recorded_probability", 0)
	var initial_credits = economy.get_resource("💰")

	# Pop
	var pop_result = ProbeActions.action_pop(terminal, plot_pool, economy)

	_assert("pop_success", pop_result.get("success", false), "POP returns success")
	_assert("pop_resource", pop_result.get("resource", "") != "", "POP returns resource emoji")
	_assert("pop_credits", pop_result.get("credits", 0) > 0, "POP converts to credits")

	var final_credits = economy.get_resource("💰")
	var credit_gain = final_credits - initial_credits
	var expected_credits = int(recorded_prob * 10.0)

	_assert("credit_amount", abs(credit_gain - expected_credits) <= 1, "Credits = probability × 10")

	if pop_result.get("success"):
		print("   ✅ POP works: resource=%s, credits=%d (prob=%.4f × 10)" % [
			pop_result.get("resource"),
			credit_gain,
			recorded_prob
		])

# ═══════════════════════════════════════════════════════════════════════════

func _test_explore_measure_pop_sequence():
	print("\n" + "─".repeat(80))
	print("TEST 5: Full Sequence - Explore → Measure → Pop")
	print("─".repeat(80))

	var biome_name = biome_list.keys()[0]
	var biome = biome_list[biome_name]

	# Explore
	var explore_result = ProbeActions.action_explore(plot_pool, biome)
	var exp_ok = explore_result.get("success", false)
	_assert("seq_explore", exp_ok, "Sequence: EXPLORE succeeds")

	if not exp_ok:
		return

	var terminal = explore_result["terminal"]

	# Measure
	var measure_result = ProbeActions.action_measure(terminal, biome)
	var meas_ok = measure_result.get("success", false)
	_assert("seq_measure", meas_ok, "Sequence: MEASURE succeeds")

	if not meas_ok:
		return

	# Pop
	var pop_result = ProbeActions.action_pop(terminal, plot_pool, economy)
	var pop_ok = pop_result.get("success", false)
	_assert("seq_pop", pop_ok, "Sequence: POP succeeds")

	if pop_ok:
		print("   ✅ Full sequence works: EXPLORE → MEASURE → POP")

# ═══════════════════════════════════════════════════════════════════════════

func _test_cross_biome():
	print("\n" + "─".repeat(80))
	print("TEST 6: Cross-Biome EXPLORE")
	print("─".repeat(80))

	if biome_list.size() < 2:
		print("   ⚠️  Only 1 biome - skipping cross-biome test")
		return

	var biome_names = biome_list.keys()

	# Explore in each biome
	var results = []
	for i in range(min(2, biome_names.size())):
		var biome = biome_list[biome_names[i]]
		var result = ProbeActions.action_explore(plot_pool, biome)
		results.append({
			"biome": biome_names[i],
			"success": result.get("success", false),
			"register": result.get("register_id", -1)
		})

	var both_ok = results.all(func(r): return r["success"])
	_assert("cross_biome_both", both_ok, "EXPLORE works in both biomes")

	if both_ok:
		print("   ✅ Cross-biome works:")
		for r in results:
			print("      - %s: register=%d" % [r["biome"], r["register"]])

# ═══════════════════════════════════════════════════════════════════════════

func _assert(test_id: String, condition: bool, description: String):
	test_count += 1
	if condition:
		pass_count += 1
		print("   ✅ %s" % description)
	else:
		issues.append("%s: %s" % [test_id, description])
		print("   ❌ %s" % description)

func print_findings():
	print("\n" + "═".repeat(80))
	print("📋 PROBE ACTIONS TEST SUMMARY")
	print("═".repeat(80))

	print("\n📊 RESULTS: %d/%d tests passed" % [pass_count, test_count])

	if issues.size() > 0:
		print("\n🐛 ISSUES (%d):" % issues.size())
		for issue in issues:
			print("   - %s" % issue)
	else:
		print("\n✅ All tests passed!")

	print("═".repeat(80) + "\n")
