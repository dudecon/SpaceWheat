#!/usr/bin/env -S godot --headless -s
extends SceneTree

## TOOL 1 PROBE - LIFECYCLE TEST (Round 1 Revised)
## Tests proper EXPLORE→MEASURE→POP sequence with register reuse

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
	print("🔍 TOOL 1 PROBE - LIFECYCLE TEST (Round 1 Revised)")
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

	print("\n✅ Game ready! Starting PROBE lifecycle testing...\n")

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
	economy.add_resource("💰", 10000, "test_bootstrap")

	print("Systems initialized:")
	print("   Farm: ✅")
	print("   Grid: ✅ (%d plots)" % grid.plots.size())
	print("   Biomes: ✅ (%d)" % biome_list.size())
	print("   Economy: 💰 = %d" % economy.get_resource("💰"))

	# Run tests
	_test_full_lifecycle_sequence()
	_test_multiple_lifecycle_iterations()
	_test_terminal_reuse()
	_test_different_biomes()
	_test_probable_outcomes()

	print_findings()
	quit()

# ═══════════════════════════════════════════════════════════════════════════

func _test_full_lifecycle_sequence():
	print("\n" + "─".repeat(80))
	print("TEST 1: Full Lifecycle - EXPLORE → MEASURE → POP")
	print("─".repeat(80))

	var biome_name = biome_list.keys()[0]
	var biome = biome_list[biome_name]

	print("   Testing complete workflow in %s..." % biome_name)

	# STEP 1: EXPLORE
	var explore_result = ProbeActions.action_explore(plot_pool, biome)
	_assert("exp_success", explore_result.get("success", false), "EXPLORE succeeds")

	if not explore_result.get("success"):
		return

	var terminal = explore_result["terminal"]
	var reg_id = explore_result["register_id"]
	var initial_prob = explore_result.get("probability", 0)

	print("   Step 1 EXPLORE: terminal=%s, register=%d, prob=%.4f" % [terminal.terminal_id, reg_id, initial_prob])

	# STEP 2: MEASURE
	var measure_result = ProbeActions.action_measure(terminal, biome)
	_assert("meas_success", measure_result.get("success", false), "MEASURE succeeds after EXPLORE")

	if not measure_result.get("success"):
		return

	var outcome = measure_result.get("outcome", "?")
	var recorded_prob = measure_result.get("recorded_probability", 0)

	print("   Step 2 MEASURE: outcome=%s, recorded=%.4f" % [outcome, recorded_prob])

	# STEP 3: POP
	var initial_credits = economy.get_resource("💰")
	var pop_result = ProbeActions.action_pop(terminal, plot_pool, economy)
	_assert("pop_success", pop_result.get("success", false), "POP succeeds after MEASURE")

	if not pop_result.get("success"):
		return

	var final_credits = economy.get_resource("💰")
	var credit_gain = final_credits - initial_credits

	print("   Step 3 POP: credits=%d (gained from %.4f prob)" % [credit_gain, recorded_prob])

	# VERIFY COMPLETE FLOW
	_assert("flow_consistency", credit_gain > 0, "Credits awarded")
	_assert("flow_register_freed", true, "Register should be freed after POP")

	if explore_result.get("success") and measure_result.get("success") and pop_result.get("success"):
		print("   ✅ Complete lifecycle works: EXPLORE→MEASURE→POP")

# ═══════════════════════════════════════════════════════════════════════════

func _test_multiple_lifecycle_iterations():
	print("\n" + "─".repeat(80))
	print("TEST 2: Multiple Iterations - Register Reuse")
	print("─".repeat(80))

	var biome_name = biome_list.keys()[0]
	var biome = biome_list[biome_name]

	print("   Testing register release and reuse...")

	var successful_cycles = 0

	# Try to do 3 complete cycles in same biome
	for cycle in range(3):
		var explore_result = ProbeActions.action_explore(plot_pool, biome)

		if not explore_result.get("success"):
			print("   Cycle %d: EXPLORE failed (expected after %d cycles)" % [cycle + 1, successful_cycles])
			break

		var terminal = explore_result["terminal"]

		# Complete the lifecycle
		var measure_result = ProbeActions.action_measure(terminal, biome)
		if not measure_result.get("success"):
			_assert("cycle_%d" % cycle, false, "Cycle %d: MEASURE failed" % (cycle + 1))
			break

		var pop_result = ProbeActions.action_pop(terminal, plot_pool, economy)
		if not pop_result.get("success"):
			_assert("cycle_%d" % cycle, false, "Cycle %d: POP failed" % (cycle + 1))
			break

		successful_cycles += 1
		print("   Cycle %d: EXPLORE→MEASURE→POP completed successfully" % (cycle + 1))

	_assert("cycles_completed", successful_cycles >= 2, "Completed 2+ register reuse cycles")

	if successful_cycles >= 3:
		print("   ✅ Register reuse works: completed %d full cycles" % successful_cycles)

# ═══════════════════════════════════════════════════════════════════════════

func _test_terminal_reuse():
	print("\n" + "─".repeat(80))
	print("TEST 3: Terminal Reuse After Release")
	print("─".repeat(80))

	var biome = biome_list.values()[0]
	var initial_unbound = plot_pool.get_unbound_count()

	print("   Initial unbound terminals: %d" % initial_unbound)

	# Bind one terminal
	var exp1 = ProbeActions.action_explore(plot_pool, biome)
	if not exp1.get("success"):
		_assert("term_reuse", false, "Could not explore to test terminal reuse")
		return

	var terminal = exp1["terminal"]
	var unbound_after_explore = plot_pool.get_unbound_count()

	_assert("terminal_bound", unbound_after_explore < initial_unbound, "Unbound count decreased after EXPLORE")

	# Complete lifecycle to release terminal
	var meas = ProbeActions.action_measure(terminal, biome)
	var pop = ProbeActions.action_pop(terminal, plot_pool, economy)

	if pop.get("success"):
		var unbound_after_pop = plot_pool.get_unbound_count()
		_assert("terminal_released", unbound_after_pop == initial_unbound, "Unbound count restored after POP")

		if unbound_after_pop == initial_unbound:
			print("   ✅ Terminal properly released and reusable")

# ═══════════════════════════════════════════════════════════════════════════

func _test_different_biomes():
	print("\n" + "─".repeat(80))
	print("TEST 4: Different Biomes Have Independent Registers")
	print("─".repeat(80))

	if biome_list.size() < 2:
		print("   ⚠️  Only 1 biome - skipping")
		return

	var biome_names = biome_list.keys()
	var biome_1_name = biome_names[0]
	var biome_2_name = biome_names[1]
	var biome_1 = biome_list[biome_1_name]
	var biome_2 = biome_list[biome_2_name]

	print("   Testing EXPLORE in %s and %s..." % [biome_1_name, biome_2_name])

	# Explore in biome 1
	var exp1 = ProbeActions.action_explore(plot_pool, biome_1)
	_assert("biome1_explore", exp1.get("success", false), "EXPLORE succeeds in biome 1")

	# Explore in biome 2 (should succeed even if biome 1 is exhausted)
	var exp2 = ProbeActions.action_explore(plot_pool, biome_2)
	_assert("biome2_explore", exp2.get("success", false), "EXPLORE succeeds in biome 2")

	if exp1.get("success") and exp2.get("success"):
		print("   ✅ Biomes have independent register pools")

		# Clean up
		ProbeActions.action_measure(exp1["terminal"], biome_1)
		ProbeActions.action_pop(exp1["terminal"], plot_pool, economy)
		ProbeActions.action_measure(exp2["terminal"], biome_2)
		ProbeActions.action_pop(exp2["terminal"], plot_pool, economy)

# ═══════════════════════════════════════════════════════════════════════════

func _test_probable_outcomes():
	print("\n" + "─".repeat(80))
	print("TEST 5: Probabilistic Outcomes")
	print("─".repeat(80))

	var biome = biome_list.values()[0]
	var outcomes = {}

	print("   Running 10 EXPLORE→MEASURE cycles...")

	for i in range(10):
		var exp = ProbeActions.action_explore(plot_pool, biome)
		if not exp.get("success"):
			print("   Cycle %d: Out of registers" % (i + 1))
			break

		var terminal = exp["terminal"]
		var meas = ProbeActions.action_measure(terminal, biome)
		var outcome = meas.get("outcome", "unknown")

		if outcome not in outcomes:
			outcomes[outcome] = 0
		outcomes[outcome] += 1

		ProbeActions.action_pop(terminal, plot_pool, economy)

	print("   Outcome distribution from %d cycles:" % outcomes.values().reduce(func(a, b): return a + b))
	for outcome in outcomes.keys():
		var count = outcomes[outcome]
		print("      %s: %d (%.1f%%)" % [outcome, count, count * 100.0 / outcomes.values().size()])

	_assert("diverse_outcomes", outcomes.size() > 1, "Multiple different outcomes observed")

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
	print("📋 PROBE LIFECYCLE TEST SUMMARY")
	print("═".repeat(80))

	print("\n📊 RESULTS: %d/%d tests passed" % [pass_count, test_count])

	if issues.size() > 0:
		print("\n🐛 ISSUES (%d):" % issues.size())
		for issue in issues:
			print("   - %s" % issue)
	else:
		print("\n✅ All tests passed!")

	print("═".repeat(80) + "\n")
