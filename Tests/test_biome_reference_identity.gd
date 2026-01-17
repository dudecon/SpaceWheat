#!/usr/bin/env -S godot --headless -s
extends SceneTree

## TEST: Biome reference identity
## Checks if the biome returned by get_biome_for_plot() is the SAME object reference
## used throughout the game (crucial for register binding)

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

var farm = null
var grid = null
var economy = null
var plot_pool = null

var frame_count = 0
var scene_loaded = false
var tests_done = false

func _init():
	print("\n" + "═".repeat(80))
	print("🔗 BIOME REFERENCE IDENTITY TEST")
	print("═".repeat(80))

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		print("\n⏳ Frame 5: Loading scene...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			var instance = scene.instantiate()
			root.add_child(instance)
			scene_loaded = true
			var boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)

func _on_game_ready():
	if tests_done:
		return
	tests_done = true

	print("\n✅ Game ready! Testing biome reference identity...\n")

	var fv = root.get_node_or_null("FarmView")
	if not fv or not fv.farm:
		print("❌ Farm not found")
		quit(1)
		return

	farm = fv.farm
	grid = farm.grid
	economy = farm.economy
	plot_pool = farm.plot_pool

	economy.add_resource("💰", 10000, "test_bootstrap")

	_test_biome_identity()

	quit()

# ═══════════════════════════════════════════════════════════════════════════

func _test_biome_identity():
	print("─".repeat(80))
	print("TESTING: Are biome references identical across multiple calls?")
	print("─".repeat(80))

	# Get biome multiple times and check if they're the same object
	var test_pos = Vector2i(2, 0)  # BioticFlux position

	print("\n1️⃣ Getting biome reference multiple times:")
	var biome1 = grid.get_biome_for_plot(test_pos)
	var biome2 = grid.get_biome_for_plot(test_pos)
	var biome3 = grid.get_biome_for_plot(test_pos)

	print("   biome1: %s" % biome1.get_biome_type())
	print("   biome2: %s" % biome2.get_biome_type())
	print("   biome3: %s" % biome3.get_biome_type())

	if biome1 == biome2 and biome2 == biome3:
		print("   ✅ All references are IDENTICAL (same object)")
	else:
		print("   ❌ DIFFERENT REFERENCES! This could cause issues!")

	# Now test with EXPLORE/MEASURE/POP
	print("\n2️⃣ Testing with actual EXPLORE/MEASURE/POP:")

	var biome_at_explore = grid.get_biome_for_plot(test_pos)
	print("   Biome at EXPLORE: %s" % biome_at_explore.get_biome_type())

	var result = ProbeActions.action_explore(plot_pool, biome_at_explore)
	if not result.get("success"):
		print("   ❌ EXPLORE failed")
		return

	var terminal = result["terminal"]
	var register_id = result["register_id"]
	print("   ✅ EXPLORE succeeded: Terminal %s → Register %d" % [terminal.terminal_id, register_id])

	# Check if terminal's biome is same as the one we used
	if terminal.bound_biome == biome_at_explore:
		print("   ✅ Terminal's bound_biome matches EXPLORE biome (same reference)")
	else:
		print("   ❌ Terminal's bound_biome is DIFFERENT from EXPLORE biome!")
		print("      This could prevent proper unbinding!")

	# Now get biome for same position again (like in MEASURE)
	var biome_at_measure = grid.get_biome_for_plot(test_pos)
	print("   Biome at MEASURE: %s" % biome_at_measure.get_biome_type())

	if biome_at_measure == terminal.bound_biome:
		print("   ✅ MEASURE biome matches terminal's bound_biome")
	else:
		print("   ❌ MEASURE biome is DIFFERENT! Will cause unbinding issues!")

	# Perform MEASURE
	var measure_result = ProbeActions.action_measure(terminal, biome_at_measure)
	if not measure_result.get("success"):
		print("   ❌ MEASURE failed")
		return

	print("   ✅ MEASURE succeeded")

	# Perform POP
	var pop_result = ProbeActions.action_pop(terminal, plot_pool, economy)
	if not pop_result.get("success"):
		print("   ❌ POP failed")
		return

	print("   ✅ POP succeeded")

	# Check register state after POP
	print("\n3️⃣ Checking register state after POP:")
	print("   Unbound registers: %s" % str(biome_at_explore.get_unbound_registers()))

	if register_id in biome_at_explore.get_unbound_registers():
		print("   ✅ Register %d is now UNBOUND (correct!)" % register_id)
	else:
		print("   ❌ Register %d is still BOUND! POP didn't release it!" % register_id)

	# Now check with a fresh biome reference
	var biome_after_pop = grid.get_biome_for_plot(test_pos)
	print("   Fresh biome unbound registers: %s" % str(biome_after_pop.get_unbound_registers()))

	if register_id in biome_after_pop.get_unbound_registers():
		print("   ✅ Register visible as unbound in fresh reference")
	else:
		print("   ⚠️  Register NOT visible in fresh reference!")

	print("\n" + "═".repeat(80))
	print("Test complete")
	print("═".repeat(80) + "\n")
