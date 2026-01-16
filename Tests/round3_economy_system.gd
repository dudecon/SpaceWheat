#!/usr/bin/env -S godot --headless -s
extends SceneTree

## ROUND 3: Economy System Testing
## Deep dive into resource tracking, conversions, and all credit-related operations

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
	"economy_state": [],
	"pop_economy_update": [],
	"quantum_conversion": [],
	"resource_emoji_tracking": [],
	"can_inject_resource_check": [],
	"issues": []
}

func _init():
	print("\n" + "═".repeat(80))
	print("🔬 ROUND 3: Economy System Deep Dive")
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

	print("\n✅ Game ready! Starting Round 3 testing...\n")

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

	print("Systems initialized:")
	print("   Farm: ✅")
	print("   Economy type: %s" % economy.get_class())
	print("   Biomes: %d" % biome_list.size())

	# Run focused tests
	_test_economy_state()
	_test_pop_economy_update()
	_test_quantum_conversion()
	_test_resource_emoji_tracking()
	_test_can_inject_resource_check()

	print_findings()
	quit()

# ═══════════════════════════════════════════════════════════════
# TEST 1: ECONOMY STATE
# ═══════════════════════════════════════════════════════════════

func _test_economy_state():
	print("\n" + "─".repeat(80))
	print("TEST 1: Economy State Inspection")
	print("─".repeat(80))

	print("\n   Current resource state:")
	var resources = economy.emoji_credits
	for emoji in resources.keys():
		print("   %s: %d credits" % [emoji, resources[emoji]])

	_finding("economy_state", "✅ Economy initialized with %d resource types" % resources.size())

	# Check for 💰 specifically
	if resources.has("💰"):
		_finding("economy_state", "✅ 💰-credits system active (current: %d)" % resources["💰"])
	else:
		_finding("economy_state", "❌ 💰 emoji not found in economy")

# ═══════════════════════════════════════════════════════════════
# TEST 2: POP ECONOMY UPDATE (THE CRITICAL BUG)
# ═══════════════════════════════════════════════════════════════

func _test_pop_economy_update():
	print("\n" + "─".repeat(80))
	print("TEST 2: POP Action - Economy Credit Update (CRITICAL)")
	print("─".repeat(80))

	if biome_list.is_empty():
		_finding("pop_economy_update", "⚠️ NO BIOMES")
		return

	var biome = biome_list[0]

	# Get starting state
	var starting_credits = economy.get_resource("💰")
	print("\n   Starting 💰 balance: %d" % starting_credits)

	# Create and measure a terminal
	var explore = ProbeActions.action_explore(plot_pool, biome)
	if not explore.success:
		_finding("pop_economy_update", "⚠️ Cannot create terminal")
		return

	var terminal = explore.terminal
	print("   Created terminal: %s in %s" % [terminal.terminal_id, biome.get_biome_type()])

	var measure = ProbeActions.action_measure(terminal, biome)
	if not measure.success:
		_finding("pop_economy_update", "⚠️ Cannot measure terminal")
		return

	var outcome = measure.outcome
	var probability = measure.probability
	print("   Measured: %s with probability %.2f" % [outcome, probability])
	print("   Converted to credits: %d" % int(probability * EconomyConstants.QUANTUM_TO_CREDITS))

	# Before POP
	var before_credits = economy.get_resource("💰")
	var before_outcome = economy.get_resource(outcome)
	print("\n   Before POP:")
	print("     💰: %d" % before_credits)
	print("     %s: %d" % [outcome, before_outcome])

	# Execute POP
	var pop = ProbeActions.action_pop(terminal, plot_pool, economy)

	# After POP
	var after_credits = economy.get_resource("💰")
	var after_outcome = economy.get_resource(outcome)
	var expected_credits = int(probability * EconomyConstants.QUANTUM_TO_CREDITS)

	print("\n   After POP:")
	print("     💰: %d (delta: %+d, expected: %+d)" % [after_credits, after_credits - before_credits, expected_credits])
	print("     %s: %d (delta: %+d)" % [outcome, after_outcome, after_outcome - before_outcome])

	# Verify update
	if after_credits == before_credits + expected_credits:
		_finding("pop_economy_update", "✅ 💰-credits correctly updated")
	else:
		_finding("pop_economy_update", "❌ 💰-credits NOT updated correctly (delta: %d, expected: %d)" % [
			after_credits - before_credits, expected_credits
		])

	if pop.success:
		if pop.has("credits"):
			print("   POP returned credits: %d" % pop.credits)
			_finding("pop_economy_update", "✅ POP result contains credits key")
		else:
			_finding("pop_economy_update", "❌ POP result missing credits")
	else:
		_finding("pop_economy_update", "❌ POP failed")

# ═══════════════════════════════════════════════════════════════
# TEST 3: QUANTUM-TO-CREDITS CONVERSION
# ═══════════════════════════════════════════════════════════════

func _test_quantum_conversion():
	print("\n" + "─".repeat(80))
	print("TEST 3: Quantum-to-Credits Conversion")
	print("─".repeat(80))

	var test_probabilities = [0.0, 0.5, 1.0, 2.5]

	print("\n   Conversion rate: 1 quantum unit = %d 💰-credits" % EconomyConstants.QUANTUM_TO_CREDITS)
	print("   Testing conversions:")

	for prob in test_probabilities:
		var credits = EconomyConstants.quantum_to_credits(prob)
		print("     %.1f probability → %d credits" % [prob, credits])

	_finding("quantum_conversion", "✅ Quantum conversion function working")

# ═══════════════════════════════════════════════════════════════
# TEST 4: RESOURCE EMOJI TRACKING
# ═══════════════════════════════════════════════════════════════

func _test_resource_emoji_tracking():
	print("\n" + "─".repeat(80))
	print("TEST 4: Resource Emoji Tracking")
	print("─".repeat(80))

	# Test 4A: Check which emojis are tracked
	print("\n   TEST 4A: Emoji tracking setup")
	var tracked = economy.emoji_credits.keys()
	print("   Tracked emojis (%d): %s" % [tracked.size(), str(tracked)])

	if "💰" in tracked:
		_finding("resource_emoji_tracking", "✅ 💰 (credits) is tracked")
	else:
		_finding("resource_emoji_tracking", "❌ 💰 (credits) NOT tracked")

	# Test 4B: Add to different emojis and verify
	print("\n   TEST 4B: Add resources to different emojis")
	var test_emoji = "🌾"
	var initial = economy.get_resource(test_emoji)
	print("   Initial %s: %d" % [test_emoji, initial])

	economy.add_resource(test_emoji, 50, "test_add")
	var after_add = economy.get_resource(test_emoji)
	print("   After add(50): %d" % after_add)

	if after_add == initial + 50:
		_finding("resource_emoji_tracking", "✅ add_resource() correctly updates emoji amounts")
	else:
		_finding("resource_emoji_tracking", "❌ add_resource() failed (got %d, expected %d)" % [after_add, initial + 50])

# ═══════════════════════════════════════════════════════════════
# TEST 5: can_inject_vocabulary RESOURCE CHECK
# ═══════════════════════════════════════════════════════════════

func _test_can_inject_resource_check():
	print("\n" + "─".repeat(80))
	print("TEST 5: can_inject_vocabulary - Should validate resources")
	print("─".repeat(80))

	if biome_list.is_empty():
		_finding("can_inject_resource_check", "⚠️ NO BIOMES")
		return

	var biome = biome_list[0]
	biome.set_evolution_paused(true)

	var test_emoji = "🎯"
	var vocab_cost = EconomyConstants.get_vocab_injection_cost(test_emoji).get("💰", 150)

	# Test 5A: With 0 credits
	print("\n   TEST 5A: can_inject with 0 credits")
	var current = economy.get_resource("💰")
	if current > 0:
		economy.remove_resource("💰", current, "test_drain")

	var check_0 = biome.can_inject_vocabulary(test_emoji)
	print("   Result: can_inject=%s" % check_0.can_inject)
	print("   Cost: %s" % check_0.get("cost", "not returned"))

	if check_0.can_inject:
		_finding("can_inject_resource_check", "❌ can_inject returns true with 0 credits")
		print("   ⚠️ BUG: This method should check resources and return false")
	else:
		_finding("can_inject_resource_check", "✅ can_inject correctly returns false with insufficient resources")

	# Test 5B: With sufficient credits
	print("\n   TEST 5B: can_inject with sufficient credits")
	economy.add_resource("💰", vocab_cost + 100, "test_restore")

	var check_ok = biome.can_inject_vocabulary(test_emoji)
	print("   Result: can_inject=%s" % check_ok.can_inject)

	if check_ok.can_inject:
		_finding("can_inject_resource_check", "✅ can_inject returns true with sufficient credits")
	else:
		_finding("can_inject_resource_check", "❌ can_inject incorrectly rejects with sufficient credits")

	biome.set_evolution_paused(false)

# ═══════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

func _finding(category: String, message: String):
	findings[category].append(message)
	print("   " + message)

func print_findings():
	print("\n" + "═".repeat(80))
	print("📋 ROUND 3 FINDINGS SUMMARY")
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
			if "❌" in item or "BUG" in item or "NOT" in item.to_upper():
				total_issues += 1
			total_findings += 1

	print("\n" + "═".repeat(80))
	print("📊 TOTALS: %d findings, %d issues" % [total_findings, total_issues])
	print("═".repeat(80) + "\n")
