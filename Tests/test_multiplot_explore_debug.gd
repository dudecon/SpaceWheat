#!/usr/bin/env -S godot --headless -s
extends SceneTree

## TEST: Multi-plot EXPLORE behavior
## Simulates selecting multiple plots and exploring all at once
## This mimics the actual FarmInputHandler._action_explore loop

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

var farm = null
var grid = null
var economy = null
var plot_pool = null
var biome = null

var frame_count = 0
var scene_loaded = false
var tests_done = false

func _init():
	print("\n" + "═".repeat(80))
	print("🎯 MULTI-PLOT EXPLORE DEBUG")
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

	print("\n✅ Game ready! Starting multi-plot explore debug...\n")

	var fv = root.get_node_or_null("FarmView")
	if not fv or not fv.farm:
		print("❌ Farm not found")
		quit(1)
		return

	farm = fv.farm
	grid = farm.grid
	economy = farm.economy
	plot_pool = farm.plot_pool
	biome = grid.biomes.values()[0]

	economy.add_resource("💰", 10000, "test_bootstrap")

	print("   Biome: %s" % biome.get_biome_type())
	print("   Total registers: %d" % biome.quantum_computer.register_map.num_qubits)
	print()

	_test_multiplot_explore()

	quit()

# ═══════════════════════════════════════════════════════════════════════════

func _test_multiplot_explore():
	print("─".repeat(80))
	print("TEST: Multi-plot EXPLORE in same biome")
	print("─".repeat(80))

	# Simulate what _action_explore does: iterate through selected plots and explore
	print("\nRound 1: EXPLORE 3 plots at once (like checkbox select)")
	_print_state("Before")

	var explored_terminals: Array[RefCounted] = []

	# Simulate selecting 3 plots in the same biome
	for i in range(3):
		print("\n   Exploring plot %d..." % (i+1))
		var result = ProbeActions.action_explore(plot_pool, biome)

		if not result.get("success"):
			print("   ❌ EXPLORE failed: %s" % result.get("error"))
			break

		var terminal = result["terminal"]
		explored_terminals.append(terminal)
		print("   ✅ Terminal %s bound to register %d" % [terminal.terminal_id, result["register_id"]])

	_print_state("After 3 EXPLOREs")

	# Now measure all 3
	print("\nRound 2: MEASURE the 3 explored terminals")
	for i in range(explored_terminals.size()):
		var terminal = explored_terminals[i]
		var result = ProbeActions.action_measure(terminal, biome)

		if not result.get("success"):
			print("   ❌ MEASURE %d failed: %s" % [i+1, result.get("error")])
			continue

		print("   ✅ Terminal %s measured → %s" % [terminal.terminal_id, result.get("outcome")])

	_print_state("After 3 MEASUREs")

	# Pop all 3
	print("\nRound 3: POP the 3 measured terminals (should release all registers)")
	for i in range(explored_terminals.size()):
		var terminal = explored_terminals[i]
		var result = ProbeActions.action_pop(terminal, plot_pool, economy)

		if not result.get("success"):
			print("   ❌ POP %d failed: %s" % [i+1, result.get("error")])
			continue

		print("   ✅ Terminal %s popped → released register %d" % [terminal.terminal_id, result.get("register_id")])

	_print_state("After 3 POPs")

	# Try to EXPLORE again immediately
	print("\nRound 4: Try EXPLORE again (should succeed with released registers)")
	for i in range(3):
		print("\n   Exploring plot %d (round 2)..." % (i+1))
		var result = ProbeActions.action_explore(plot_pool, biome)

		if not result.get("success"):
			print("   ❌ EXPLORE %d FAILED: %s" % [i+1, result.get("error")])
			print("   🔴 PROBLEM DETECTED: Should have succeeded with released registers!")
			break

		print("   ✅ Terminal %s bound to register %d" % [result["terminal"].terminal_id, result["register_id"]])

	_print_state("After second round of 3 EXPLOREs")

	print("\n" + "═".repeat(80))
	print("Test complete")
	print("═".repeat(80) + "\n")

# ═══════════════════════════════════════════════════════════════════════════

func _print_state(label: String):
	var unbound = biome.get_unbound_registers()
	var bound_count = biome.get_bound_register_count()
	var total = biome.get_total_register_count()

	var unbound_terminals = plot_pool.get_unbound_terminals()
	var all_terminals = plot_pool.get_all_terminals()
	var terminal_bound_count = all_terminals.size() - unbound_terminals.size()

	print("   [%s]" % label)
	print("      📊 Registers: %d unbound, %d bound, %d total (IDs: %s)" % [
		unbound.size(), bound_count, total, unbound
	])
	print("      🎫 Terminals: %d unbound, %d bound, %d total" % [
		unbound_terminals.size(), terminal_bound_count, all_terminals.size()
	])
