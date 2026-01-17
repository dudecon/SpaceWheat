#!/usr/bin/env -S godot --headless -s
extends SceneTree

## TEST: Cross-biome register exhaustion
## Tests if exploring in multiple biomes causes register pool exhaustion issues

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
	print("🌍 CROSS-BIOME REGISTER EXHAUSTION TEST")
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

	print("\n✅ Game ready! Testing cross-biome register exhaustion...\n")

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

	_test_cross_biome()

	quit()

# ═══════════════════════════════════════════════════════════════════════════

func _test_cross_biome():
	print("─".repeat(80))
	print("TEST: Exploring in BioticFlux (3 regs) exhausts pool terminals")
	print("      Then exploring in Forest (5 regs) should still work")
	print("─".repeat(80))

	var bioticflux = grid.biomes["BioticFlux"]
	var forest = grid.biomes["Forest"]

	print("\n📊 Initial state:")
	print("   Pool: %d total terminals" % plot_pool.get_all_terminals().size())
	print("   BioticFlux: %d registers (max)" % bioticflux.get_total_register_count())
	print("   Forest: %d registers (max)" % forest.get_total_register_count())

	# EXPLORE all 3 BioticFlux registers
	print("\n▶️  PHASE 1: Exhausting BioticFlux (3 EXPLOREs)")
	var bioticflux_terminals: Array[RefCounted] = []

	for i in range(3):
		print("   EXPLORE BioticFlux %d..." % (i+1))
		var result = ProbeActions.action_explore(plot_pool, bioticflux)

		if not result.get("success"):
			print("   ❌ EXPLORE failed: %s" % result.get("error"))
			break

		bioticflux_terminals.append(result["terminal"])
		print("   ✅ Terminal %s → Register %d" % [result["terminal"].terminal_id, result["register_id"]])

	print("   BioticFlux unbound: %s" % str(bioticflux.get_unbound_registers()))
	print("   Pool terminals unbound: %d" % plot_pool.get_unbound_terminals().size())

	# Try to EXPLORE in Forest (different biome, different register pool, same terminal pool)
	print("\n▶️  PHASE 2: Exploring Forest (should work despite exhausted terminal pool)")
	var forest_terminals: Array[RefCounted] = []

	for i in range(3):
		print("   EXPLORE Forest %d..." % (i+1))
		var result = ProbeActions.action_explore(plot_pool, forest)

		if not result.get("success"):
			print("   ❌ EXPLORE failed: %s" % result.get("error"))
			print("      This might indicate a terminal pool exhaustion issue")
			break

		forest_terminals.append(result["terminal"])
		print("   ✅ Terminal %s → Register %d" % [result["terminal"].terminal_id, result["register_id"]])

	print("   Forest unbound: %s" % str(forest.get_unbound_registers()))
	print("   Pool terminals unbound: %d" % plot_pool.get_unbound_terminals().size())

	# Now MEASURE and POP all BioticFlux terminals
	print("\n▶️  PHASE 3: MEASURE & POP BioticFlux terminals (release terminals)")
	for i in range(bioticflux_terminals.size()):
		var terminal = bioticflux_terminals[i]
		var mresult = ProbeActions.action_measure(terminal, bioticflux)
		if mresult.get("success"):
			var presult = ProbeActions.action_pop(terminal, plot_pool, economy)
			print("   ✅ Terminal %s POPped" % terminal.terminal_id)

	print("   Pool terminals unbound: %d" % plot_pool.get_unbound_terminals().size())

	# Now try to EXPLORE in BioticFlux again
	print("\n▶️  PHASE 4: Re-EXPLORE BioticFlux (should work with released terminals)")
	for i in range(3):
		print("   EXPLORE BioticFlux round2 %d..." % (i+1))
		var result = ProbeActions.action_explore(plot_pool, bioticflux)

		if not result.get("success"):
			print("   ❌ EXPLORE failed: %s" % result.get("error"))
			print("      🔴 BUG: Released terminals not being reused!")
			return

		print("   ✅ Terminal %s → Register %d" % [result["terminal"].terminal_id, result["register_id"]])

	print("\n" + "═".repeat(80))
	print("✅ TEST PASSED: Registers properly reused across biomes")
	print("═".repeat(80) + "\n")
