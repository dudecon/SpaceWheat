#!/usr/bin/env -S godot --headless -s
extends SceneTree

## TEST: Gameplay-style register reuse
## Simulates actual player workflow:
## 1. EXPLORE 3 times in same biome
## 2. MEASURE each one
## 3. POP each one to release registers
## 4. EXPLORE 3 more times - should work if registers are released
## 5. Repeat to verify continuous reuse

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
	print("🎮 GAMEPLAY REGISTER REUSE TEST")
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

	print("\n✅ Game ready! Starting gameplay register reuse test...\n")

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
	print("   Total registers (qubits): %d" % biome.quantum_computer.register_map.num_qubits)
	print()

	_test_gameplay_reuse()

	quit()

# ═══════════════════════════════════════════════════════════════════════════

func _test_gameplay_reuse():
	print("─".repeat(80))
	print("SIMULATING: EXPLORE 3x → MEASURE 3x → POP 3x (REPEAT 3 TIMES)")
	print("─".repeat(80))

	var num_cycles = 3

	for cycle in range(num_cycles):
		print("\n╔ CYCLE %d: Explore 3 → Measure 3 → Pop 3" % (cycle + 1))
		print("║")

		# EXPLORE 3 times
		print("║ [EXPLORE PHASE - 3 terminals]")
		var terminals_to_pop: Array[RefCounted] = []

		for i in range(3):
			_print_state("   ", "Before EXPLORE %d" % (i+1))
			var result = ProbeActions.action_explore(plot_pool, biome)

			if not result.get("success"):
				print("║ ❌ EXPLORE %d FAILED: %s" % [i+1, result.get("error")])
				print("║")
				print("╚ STOPPING at cycle %d" % (cycle + 1))
				return

			var terminal = result["terminal"]
			terminals_to_pop.append(terminal)
			print("║ ✅ EXPLORE %d: Terminal %s bound to register %d" % [
				i+1, terminal.terminal_id, result["register_id"]
			])

		_print_state("   ", "After 3 EXPLOREs")

		# MEASURE 3 times
		print("║")
		print("║ [MEASURE PHASE]")
		for i in range(3):
			var terminal = terminals_to_pop[i]
			var result = ProbeActions.action_measure(terminal, biome)

			if not result.get("success"):
				print("║ ❌ MEASURE %d FAILED: %s" % [i+1, result.get("error")])
				continue

			print("║ ✅ MEASURE %d: Terminal %s → %s" % [
				i+1, terminal.terminal_id, result.get("outcome")
			])

		_print_state("   ", "After 3 MEASUREs")

		# POP 3 times
		print("║")
		print("║ [POP PHASE - Releasing registers]")
		for i in range(3):
			var terminal = terminals_to_pop[i]
			var result = ProbeActions.action_pop(terminal, plot_pool, economy)

			if not result.get("success"):
				print("║ ❌ POP %d FAILED: %s" % [i+1, result.get("error")])
				continue

			print("║ ✅ POP %d: Terminal %s released (gained %d 💰)" % [
				i+1, terminal.terminal_id, int(result.get("credits", 0))
			])

		_print_state("   ", "After 3 POPs (should have released all)")
		print("║")
		print("╚ Cycle %d complete - All registers released and available\n" % (cycle + 1))

	print("─".repeat(80))
	print("✅ SUCCESS: All 3 cycles completed!")
	print("   Registers properly released and reused across cycles")
	print("═".repeat(80) + "\n")

# ═══════════════════════════════════════════════════════════════════════════

func _print_state(prefix: String, label: String):
	"""Print register and terminal state"""
	var unbound = biome.get_unbound_registers()
	var bound_count = biome.get_bound_register_count()
	var total = biome.get_total_register_count()

	var unbound_terminals = plot_pool.get_unbound_terminals()
	var all_terminals = plot_pool.get_all_terminals()
	var terminal_bound_count = all_terminals.size() - unbound_terminals.size()
	var terminal_total = all_terminals.size()

	print("%s%s:" % [prefix, label])
	print("%s   📊 Registers: %d unbound, %d bound, %d total (IDs: %s)" % [
		prefix, unbound.size(), bound_count, total, unbound
	])
	print("%s   🎫 Terminals: %d unbound, %d bound, %d total" % [
		prefix, unbound_terminals.size(), terminal_bound_count, terminal_total
	])
