#!/usr/bin/env -S godot --headless -s
extends SceneTree

## ROUND 2: Focused Testing on Resource Constraints & Cross-Biome
## Tests: Economics, cross-biome blocking, vocabulary injection

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")

var farm = null
var grid = null
var economy = null
var plot_pool = null
var biome_list = []

var frame_count = 0
var scene_loaded = false
var tests_done = false

var findings = {
	"resource_validation": [],
	"vocab_injection": [],
	"cross_biome_blocking": [],
	"pop_resource_tracking": [],
	"issues": []
}

func _init():
	print("\n" + "═".repeat(80))
	print("🔬 ROUND 2: Resource Constraints & Cross-Biome Testing")
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
			print("   ✅ Scene instantiated")

			var boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)
				print("   ✅ Connected to BootManager.game_ready")
		else:
			print("   ❌ Failed to load scene")
			quit(1)

func _on_game_ready():
	if tests_done:
		return
	tests_done = true

	print("\n✅ Game ready! Starting Round 2 testing...\n")

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
	biome_list = grid.biomes.values()

	# Bootstrap resources for testing
	economy.add_resource("💰", 2000, "test_bootstrap")

	print("Systems initialized:")
	print("   Farm: ✅")
	print("   Grid: ✅ (%d plots)" % grid.plots.size())
	print("   Biomes: ✅ (%d)" % biome_list.size())
	print("   Bootstrapped 💰: 2000")

	# Run focused tests
	_test_resource_validation()
	_test_vocab_injection_resource_check()
	_test_pop_resource_tracking()
	_test_cross_biome_blocking()

	print_findings()
	quit()

# ═══════════════════════════════════════════════════════════════
# TEST 1: RESOURCE VALIDATION
# ═══════════════════════════════════════════════════════════════

func _test_resource_validation():
	print("\n" + "─".repeat(80))
	print("TEST 1: RESOURCE VALIDATION - Planting with insufficient credits")
	print("─".repeat(80))

	if grid.plots.is_empty():
		_finding("resource_validation", "⚠️ NO PLOTS")
		return

	var test_pos = Vector2i(0, 0)
	var plot = grid.get_plot(test_pos)
	if not plot:
		_finding("resource_validation", "⚠️ Cannot access plot")
		return

	var biome = grid.get_biome_for_plot(test_pos)
	if not biome:
		_finding("resource_validation", "⚠️ Cannot find biome for plot")
		return

	# Get a plantable capability
	var caps = biome.get_plantable_capabilities()
	if caps.is_empty():
		_finding("resource_validation", "⚠️ No plantable capabilities")
		return

	var cap = caps[0]
	var plant_cost = cap.cost.get("💰", 25)
	print("   Test setup: %s biome, plant type: %s, cost: %d 💰" % [
		biome.get_biome_type(), cap.plant_type, plant_cost
	])

	# Test 1A: Plant with insufficient resources
	print("\n   TEST 1A: Plant with cost > available credits")
	var current_credits = economy.get_resource("💰")
	if current_credits < plant_cost:
		print("   ✅ Already below cost threshold (%d < %d)" % [current_credits, plant_cost])
	else:
		# Drain credits
		economy.remove_resource("💰", current_credits - (plant_cost - 1), "test_drain")
		current_credits = economy.get_resource("💰")
		print("   Drained to: %d 💰" % current_credits)

	var fail_result = grid.plant(test_pos, cap.plant_type)
	if fail_result:
		_finding("resource_validation", "❌ PLANT SUCCEEDED WITH INSUFFICIENT CREDITS")
	else:
		_finding("resource_validation", "✅ Plant correctly rejected (insufficient funds)")

	# Test 1B: Plant with exactly matching credits
	print("\n   TEST 1B: Plant with cost == available credits")
	economy.add_resource("💰", plant_cost, "test_exact_match")
	current_credits = economy.get_resource("💰")
	print("   Credits: %d, Cost: %d" % [current_credits, plant_cost])

	var test_pos_b = Vector2i(1, 0)
	var plot_b = grid.get_plot(test_pos_b)
	if plot_b:
		var succeed_result = grid.plant(test_pos_b, cap.plant_type)
		if succeed_result:
			_finding("resource_validation", "✅ Plant succeeded with exact credits")
			var remaining = economy.get_resource("💰")
			if remaining == 0:
				_finding("resource_validation", "✅ Credits correctly deducted (now 0)")
			else:
				_finding("resource_validation", "❌ Credits not fully deducted (remaining: %d)" % remaining)
		else:
			_finding("resource_validation", "❌ Plant failed with exact credits (should succeed)")

	# Restore
	economy.add_resource("💰", 2000, "test_restore")

# ═══════════════════════════════════════════════════════════════
# TEST 2: VOCABULARY INJECTION RESOURCE CHECK
# ═══════════════════════════════════════════════════════════════

func _test_vocab_injection_resource_check():
	print("\n" + "─".repeat(80))
	print("TEST 2: VOCABULARY INJECTION - Resource cost validation")
	print("─".repeat(80))

	if biome_list.is_empty():
		_finding("vocab_injection", "⚠️ NO BIOMES")
		return

	var biome = biome_list[0]
	biome.set_evolution_paused(true)
	print("   Enabled BUILD mode on %s" % biome.get_biome_type())

	var test_emoji = "🚀"

	# Test 2A: can_inject_vocabulary SHOULD check resources
	print("\n   TEST 2A: can_inject_vocabulary with zero credits")
	var all_credits = economy.get_resource("💰")
	if all_credits > 0:
		economy.remove_resource("💰", all_credits, "test_drain_for_injection")
		print("   Drained all credits (now: %d)" % economy.get_resource("💰"))

	var check = biome.can_inject_vocabulary(test_emoji)
	print("   can_inject_vocabulary result:")
	print("     can_inject: %s" % check.can_inject)
	if check.has("cost"):
		print("     cost: %s" % check.cost)

	if check.can_inject:
		_finding("vocab_injection", "❌ can_inject_vocabulary returns true with 0 credits (SHOULD CHECK COST)")
		print("   ⚠️ ISSUE: This method doesn't validate resource availability!")
	else:
		_finding("vocab_injection", "✅ can_inject_vocabulary correctly rejects zero credits")

	# Test 2B: inject_vocabulary should also reject
	print("\n   TEST 2B: inject_vocabulary with zero credits")
	var inject_result = biome.inject_vocabulary(test_emoji)
	if inject_result.success:
		_finding("vocab_injection", "❌ inject_vocabulary SUCCEEDED with 0 credits")
	else:
		_finding("vocab_injection", "✅ inject_vocabulary correctly rejected (insufficient resources)")
		print("   Error: %s" % inject_result.error)

	# Test 2C: inject_vocabulary with sufficient credits
	print("\n   TEST 2C: inject_vocabulary with sufficient credits")
	var vocab_cost = EconomyConstants.get_vocab_injection_cost(test_emoji)
	var cost_amount = vocab_cost.get("💰", 150)
	economy.add_resource("💰", cost_amount + 100, "test_restore_for_injection")
	print("   Added %d 💰 (total: %d, needed: %d)" % [
		cost_amount + 100, economy.get_resource("💰"), cost_amount
	])

	var success_inject = biome.inject_vocabulary(test_emoji)
	if success_inject.success:
		_finding("vocab_injection", "✅ inject_vocabulary succeeded with sufficient credits")
		var remaining = economy.get_resource("💰")
		print("   Remaining credits: %d" % remaining)
		if remaining == 100:
			_finding("vocab_injection", "✅ Cost correctly deducted")
		else:
			_finding("vocab_injection", "⚠️ Cost deduction unclear (remaining: %d, expected: 100)" % remaining)
	else:
		_finding("vocab_injection", "❌ inject_vocabulary failed despite sufficient credits")
		print("   Error: %s" % success_inject.error)

	biome.set_evolution_paused(false)
	economy.add_resource("💰", 2000, "test_final_restore")

# ═══════════════════════════════════════════════════════════════
# TEST 3: POP RESOURCE TRACKING
# ═══════════════════════════════════════════════════════════════

func _test_pop_resource_tracking():
	print("\n" + "─".repeat(80))
	print("TEST 3: POP ACTION - Resource tracking and key names")
	print("─".repeat(80))

	if biome_list.is_empty():
		_finding("pop_resource_tracking", "⚠️ NO BIOMES")
		return

	var biome = biome_list[0]

	# Create and measure a terminal
	var explore = ProbeActions.action_explore(plot_pool, biome)
	if not explore.success:
		_finding("pop_resource_tracking", "⚠️ Cannot create terminal for POP test")
		return

	var terminal = explore.terminal
	var measure = ProbeActions.action_measure(terminal, biome)
	if not measure.success:
		_finding("pop_resource_tracking", "⚠️ Cannot measure terminal for POP test")
		return

	print("   Terminal measured: %s → %.2f" % [measure.outcome, measure.probability])

	# Test 3A: POP return format
	print("\n   TEST 3A: Check POP result dictionary keys")
	var credits_before = economy.get_resource("💰")
	var pop = ProbeActions.action_pop(terminal, plot_pool, economy)

	if pop.success:
		_finding("pop_resource_tracking", "✅ POP succeeded")
		print("   Result keys: %s" % str(pop.keys()))

		# Check for correct key names
		if pop.has("credits"):
			_finding("pop_resource_tracking", "✅ POP returns 'credits' key")
			print("   Credits gained: %d" % pop.credits)
		elif pop.has("credits_gained"):
			_finding("pop_resource_tracking", "⚠️ POP returns 'credits_gained' (expected 'credits')")
		else:
			_finding("pop_resource_tracking", "❌ POP missing credits key")

		# Verify credits were added to economy
		var credits_after = economy.get_resource("💰")
		var added = credits_after - credits_before
		if added > 0:
			_finding("pop_resource_tracking", "✅ Economy credits increased by %d" % added)
		else:
			_finding("pop_resource_tracking", "❌ Economy credits not updated (before: %d, after: %d)" % [
				credits_before, credits_after
			])
	else:
		_finding("pop_resource_tracking", "❌ POP failed: %s" % pop.error)

# ═══════════════════════════════════════════════════════════════
# TEST 4: CROSS-BIOME BLOCKING
# ═══════════════════════════════════════════════════════════════

func _test_cross_biome_blocking():
	print("\n" + "─".repeat(80))
	print("TEST 4: CROSS-BIOME BLOCKING - Operations should not cross biomes")
	print("─".repeat(80))

	if biome_list.size() < 2:
		print("   ⚠️ Need 2+ biomes for cross-biome test (have: %d)" % biome_list.size())
		return

	var biome_a = biome_list[0]
	var biome_b = biome_list[1]

	print("   Biome A: %s" % biome_a.get_biome_type())
	print("   Biome B: %s" % biome_b.get_biome_type())

	# Test 4A: Try to measure a terminal bound to biome A in context of biome B
	print("\n   TEST 4A: Cross-biome measurement blocking")
	var explore_a = ProbeActions.action_explore(plot_pool, biome_a)
	if not explore_a.success:
		_finding("cross_biome_blocking", "⚠️ Cannot create terminal in biome A")
		return

	var term_a = explore_a.terminal
	print("   Created terminal in %s: %s" % [biome_a.get_biome_type(), term_a.terminal_id])

	# Try to measure with wrong biome context
	# (This depends on implementation - measurement might work if it's just reading the terminal)
	_finding("cross_biome_blocking", "📝 TODO: Implement measurement cross-biome blocking test")

	# Test 4B: Try to apply gate across biomes
	print("\n   TEST 4B: Cross-biome gate blocking (CNOT)")
	_finding("cross_biome_blocking", "📝 TODO: Create 2 terminals in different biomes and try CNOT")

	# Test 4C: Try to entangle across biomes
	print("\n   TEST 4C: Cross-biome entanglement blocking")
	_finding("cross_biome_blocking", "📝 TODO: Try entangling terminals from A and B")

# ═══════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

func _finding(category: String, message: String):
	findings[category].append(message)
	print("   " + message)

func print_findings():
	print("\n" + "═".repeat(80))
	print("📋 ROUND 2 FINDINGS SUMMARY")
	print("═".repeat(80))

	var total_findings = 0
	var total_issues = 0

	for category in findings.keys():
		var items = findings[category]
		if items.is_empty():
			continue

		print("\n🔹 %s (%d)" % [category.to_upper(), items.size()])
		for item in items:
			print("   " + item)
			if "❌" in item or "FAILED" in item or "ISSUE" in item:
				total_issues += 1
			total_findings += 1

	print("\n" + "═".repeat(80))
	print("📊 TOTALS: %d findings, %d issues" % [total_findings, total_issues])
	print("═".repeat(80) + "\n")
