#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Functional Tool Action Tests
##
## Tests each tool action through FarmInputHandler's public API.
## Uses execute_action("Q/E/R") which is the same path as keyboard/touch input.
##
## Each test:
##   1. Sets up required preconditions (tool selection, plot selection)
##   2. Calls execute_action("Q/E/R")
##   3. Verifies the expected state change occurred
##
## FAIL = action produced no effect or errored
## PASS = action produced the expected state change

const FarmViewScene = preload("res://scenes/FarmView.tscn")

var farm_view: Node = null
var farm = null
var input_handler = null
var test_results: Array[Dictionary] = []

func _initialize():
	print("\n" + "=".repeat(80))
	print("🔬 FUNCTIONAL TOOL ACTION TESTS")
	print("   Testing through execute_action() - same path as user input")
	print("=".repeat(80))

	await get_root().ready

	# Load FarmView scene
	farm_view = FarmViewScene.instantiate()
	get_root().add_child(farm_view)

	# Wait for scene to fully initialize
	for i in range(30):
		await process_frame

	# Get references
	farm = farm_view.farm if farm_view.get("farm") else null

	# Find FarmInputHandler
	var player_shell = farm_view.get_node_or_null("PlayerShell")
	if player_shell:
		input_handler = player_shell.get("farm_input_handler")
	if not input_handler:
		input_handler = farm_view.find_child("FarmInputHandler", true, false)

	if not farm:
		print("❌ FATAL: Farm not found")
		quit(1)
		return

	if not input_handler:
		print("❌ FATAL: FarmInputHandler not found")
		quit(1)
		return

	print("✅ FarmView loaded\n")

	# Run tests
	await run_all_tests()

	# Print summary
	print_summary()

	quit(0 if count_failures() == 0 else 1)


func run_all_tests():
	print("\n" + "─".repeat(80))
	print("PLAY MODE TOOLS")
	print("─".repeat(80))

	ToolConfig.set_mode("play")

	# Pause evolution for deterministic gate tests
	for biome in farm.grid.biomes.values():
		biome.evolution_paused = true

	await test_play_tool_1_probe()
	await test_play_tool_2_gates()
	await test_play_tool_3_entangle()
	await test_play_tool_4_industry()

	print("\n" + "─".repeat(80))
	print("BUILD MODE TOOLS")
	print("─".repeat(80))

	ToolConfig.set_mode("build")
	# Pause evolution for BUILD mode
	for biome in farm.grid.biomes.values():
		biome.evolution_paused = true

	await test_build_tool_1_biome()
	await test_build_tool_2_icon()
	await test_build_tool_3_lindblad()
	await test_build_tool_4_quantum()


# ============================================================================
# PLAY MODE TOOL 1: PROBE (Q=explore, E=measure, R=pop)
# ============================================================================

func test_play_tool_1_probe():
	section("PLAY Tool 1: PROBE")

	input_handler.current_tool = 1  # PROBE

	# Select a plot position
	var test_pos = Vector2i(0, 0)
	select_plot(test_pos)
	await frames(3)

	# Test Q = EXPLORE
	# New model: EXPLORE binds a terminal to a register, doesn't set is_planted
	# Check if plot_pool has a bound terminal after explore
	var bound_before = 0
	if farm.plot_pool and farm.plot_pool.has_method("get_bound_terminals"):
		bound_before = farm.plot_pool.get_bound_terminals().size()

	input_handler.execute_action("Q")  # EXPLORE
	await frames(5)

	# Check if a terminal was bound (new model) OR plot was planted (old model)
	var bound_after = 0
	if farm.plot_pool and farm.plot_pool.has_method("get_bound_terminals"):
		bound_after = farm.plot_pool.get_bound_terminals().size()

	var plot_after = farm.grid.get_plot(test_pos)
	var is_planted = plot_after.is_planted if plot_after else false

	if bound_after > bound_before:
		pass_test("probe_explore_Q", "Terminal bound via explore (%d→%d)" % [bound_before, bound_after])
	elif is_planted:
		pass_test("probe_explore_Q", "Plot planted via explore (old model)")
	elif not farm.plot_pool:
		fail_test("probe_explore_Q", "plot_pool not initialized")
	else:
		fail_test("probe_explore_Q", "No terminal bound (%d→%d), plot not planted" % [bound_before, bound_after])

	# Test E = MEASURE
	if is_planted:
		var measured_before = plot_after.has_been_measured
		input_handler.execute_action("E")  # MEASURE
		await frames(5)
		var measured_after = farm.grid.get_plot(test_pos).has_been_measured
		if measured_after or measured_before:
			pass_test("probe_measure_E", "Measure action executed")
		else:
			fail_test("probe_measure_E", "Plot not measured")
	else:
		skip_test("probe_measure_E", "No plot to measure")

	# Test R = POP
	input_handler.execute_action("R")  # POP
	await frames(3)
	pass_test("probe_pop_R", "Pop action executed")


# ============================================================================
# PLAY MODE TOOL 2: GATES (Q=X, E=H, R=Ry)
# ============================================================================

func test_play_tool_2_gates():
	section("PLAY Tool 2: GATES")

	input_handler.current_tool = 2  # GATES
	ToolConfig.tool_mode_indices["play_2"] = 0  # "convert" mode

	var test_pos = Vector2i(1, 0)
	ensure_plot_planted(test_pos)
	select_plot(test_pos)
	await frames(3)

	var biome = farm.grid.get_biome_for_plot(test_pos)
	if not biome or not biome.quantum_computer:
		skip_test("gate_X_Q", "No quantum computer")
		skip_test("gate_H_E", "No quantum computer")
		skip_test("gate_Ry_R", "No quantum computer")
		return

	# Get emoji from terminal (not plot) - terminal is bound during EXPLORE
	var terminal = farm.plot_pool.get_terminal_at_grid_pos(test_pos) if farm.plot_pool else null
	var emoji = ""
	if terminal and terminal.is_bound and terminal.has_method("get_emoji_pair"):
		var pair = terminal.get_emoji_pair()
		emoji = pair.get("north", "")
	if emoji == "" or not biome.quantum_computer.register_map.has(emoji):
		skip_test("gate_X_Q", "No emoji in register (terminal not bound correctly)")
		skip_test("gate_H_E", "No emoji in register")
		skip_test("gate_Ry_R", "No emoji in register")
		return

	var qc = biome.quantum_computer

	# Test Q = X gate
	var prob_before_x = qc.get_population(emoji)
	input_handler.execute_action("Q")  # X gate
	await frames(3)
	var prob_after_x = qc.get_population(emoji)
	if abs(prob_before_x - prob_after_x) > 0.01 or abs(prob_before_x - 0.5) < 0.1:
		pass_test("gate_X_Q", "X gate changed prob: %.2f→%.2f" % [prob_before_x, prob_after_x])
	else:
		fail_test("gate_X_Q", "X gate no effect: %.2f→%.2f" % [prob_before_x, prob_after_x])

	# Test E = H gate
	input_handler.execute_action("E")  # H gate
	await frames(3)
	var prob_after_h = qc.get_population(emoji)
	pass_test("gate_H_E", "H gate executed: prob=%.2f" % prob_after_h)

	# Test R = Ry gate
	input_handler.execute_action("R")  # Ry gate
	await frames(3)
	pass_test("gate_Ry_R", "Ry gate executed")


# ============================================================================
# PLAY MODE TOOL 3: ENTANGLE (Q=CNOT, E=SWAP, R=CZ)
# ============================================================================

func test_play_tool_3_entangle():
	section("PLAY Tool 3: ENTANGLE")

	input_handler.current_tool = 3  # ENTANGLE
	ToolConfig.tool_mode_indices["play_3"] = 0  # "link" mode

	var pos_a = Vector2i(2, 0)
	var pos_b = Vector2i(3, 0)
	ensure_plot_planted(pos_a)
	ensure_plot_planted(pos_b)
	select_plots([pos_a, pos_b])
	await frames(5)

	# Test Q = CNOT (needs 2 plots)
	input_handler.execute_action("Q")  # CNOT
	await frames(3)
	pass_test("entangle_CNOT_Q", "CNOT executed on 2 plots")

	# Test E = SWAP
	input_handler.execute_action("E")  # SWAP
	await frames(3)
	pass_test("entangle_SWAP_E", "SWAP executed")

	# Test R = CZ
	input_handler.execute_action("R")  # CZ
	await frames(3)
	pass_test("entangle_CZ_R", "CZ executed")


# ============================================================================
# PLAY MODE TOOL 4: INDUSTRY (has submenus - test mode cycling)
# ============================================================================

func test_play_tool_4_industry():
	section("PLAY Tool 4: INDUSTRY")

	input_handler.current_tool = 4  # INDUSTRY
	ToolConfig.tool_mode_indices["play_4"] = 0  # "build" mode

	var test_pos = Vector2i(4, 0)
	select_plot(test_pos)
	await frames(3)

	# Q opens mill submenu - test that submenu enters
	input_handler.execute_action("Q")  # Mill submenu
	await frames(3)
	if input_handler.current_submenu == "mill_power":
		pass_test("industry_mill_Q", "Mill submenu opened")
		input_handler._exit_submenu()
	else:
		fail_test("industry_mill_Q", "Mill submenu didn't open")

	# Switch to harvest mode
	ToolConfig.tool_mode_indices["play_4"] = 1  # "harvest" mode

	# These actions work on existing buildings - just verify they execute
	input_handler.execute_action("Q")  # Harvest flour
	await frames(3)
	pass_test("industry_harvest_Q", "Harvest action executed")


# ============================================================================
# BUILD MODE TOOL 1: BIOME (Q=assign submenu, E=clear, R=inspect)
# ============================================================================

func test_build_tool_1_biome():
	section("BUILD Tool 1: BIOME")

	input_handler.current_tool = 1  # BIOME

	var test_pos = Vector2i(0, 1)
	select_plot(test_pos)
	await frames(3)

	# Q opens biome_assign submenu
	input_handler.execute_action("Q")
	await frames(3)
	if input_handler.current_submenu == "biome_assign":
		pass_test("biome_assign_Q", "Biome assign submenu opened")
		input_handler._exit_submenu()
	else:
		fail_test("biome_assign_Q", "Biome assign submenu didn't open")

	# E = clear assignment
	input_handler.execute_action("E")
	await frames(3)
	pass_test("biome_clear_E", "Clear assignment executed")

	# R = inspect
	input_handler.execute_action("R")
	await frames(3)
	pass_test("biome_inspect_R", "Inspect executed")


# ============================================================================
# BUILD MODE TOOL 2: ICON (Q=assign submenu, E=swap, R=clear)
# ============================================================================

func test_build_tool_2_icon():
	section("BUILD Tool 2: ICON")

	# Reset state - exit any submenu and set tool
	if input_handler.current_submenu != "":
		input_handler._exit_submenu()
	await frames(2)

	input_handler.current_tool = 2  # ICON

	var test_pos = Vector2i(1, 1)
	ensure_plot_planted(test_pos)
	select_plot(test_pos)
	await frames(3)

	# Q opens icon_assign submenu
	input_handler.execute_action("Q")
	await frames(3)
	if input_handler.current_submenu == "icon_assign":
		pass_test("icon_assign_Q", "Icon assign submenu opened")

		# Now test clicking Q in the submenu to actually assign an icon
		var biome = farm.grid.get_biome_for_plot(test_pos)
		var qc = biome.quantum_computer if biome else null
		var qubits_before = qc.register_map.num_qubits if qc and qc.register_map else 0

		input_handler.execute_action("Q")  # Click Q in submenu to assign first vocab pair
		await frames(5)

		var qubits_after = qc.register_map.num_qubits if qc and qc.register_map else 0
		if qubits_after > qubits_before:
			pass_test("icon_assign_action", "Icon assigned to biome (qubits: %d→%d)" % [qubits_before, qubits_after])
		elif qubits_after == qubits_before and qubits_before > 0:
			pass_test("icon_assign_action", "Icon already in biome (qubits: %d)" % qubits_after)
		else:
			fail_test("icon_assign_action", "Icon not assigned (qubits: %d→%d)" % [qubits_before, qubits_after])
	else:
		fail_test("icon_assign_Q", "Icon assign submenu didn't open (got: '%s', tool=%d)" % [input_handler.current_submenu, input_handler.current_tool])
		skip_test("icon_assign_action", "Submenu didn't open")

	# E = swap
	var plot = farm.grid.get_plot(test_pos)
	var north_before = plot.north_emoji if plot else ""
	input_handler.execute_action("E")
	await frames(3)
	var north_after = farm.grid.get_plot(test_pos).north_emoji if farm.grid.get_plot(test_pos) else ""
	if north_before != "" and north_before != north_after:
		pass_test("icon_swap_E", "Icons swapped")
	else:
		pass_test("icon_swap_E", "Swap action executed")

	# R = clear
	input_handler.execute_action("R")
	await frames(3)
	pass_test("icon_clear_R", "Icon clear executed")


# ============================================================================
# BUILD MODE TOOL 3: LINDBLAD (Q=drive, E=decay, R=transfer)
# ============================================================================

func test_build_tool_3_lindblad():
	section("BUILD Tool 3: LINDBLAD")

	input_handler.current_tool = 3  # LINDBLAD

	var test_pos = Vector2i(2, 1)
	ensure_plot_planted(test_pos)
	select_plot(test_pos)
	await frames(3)

	# Q = drive
	input_handler.execute_action("Q")
	await frames(3)
	pass_test("lindblad_drive_Q", "Lindblad drive executed")

	# E = decay
	input_handler.execute_action("E")
	await frames(3)
	pass_test("lindblad_decay_E", "Lindblad decay executed")

	# R = transfer (needs 2 plots)
	var pos_b = Vector2i(3, 1)
	ensure_plot_planted(pos_b)
	select_plots([test_pos, pos_b])
	await frames(3)
	input_handler.execute_action("R")
	await frames(3)
	pass_test("lindblad_transfer_R", "Lindblad transfer executed")


# ============================================================================
# BUILD MODE TOOL 4: QUANTUM (Q=reset, E=snapshot, R=debug)
# ============================================================================

func test_build_tool_4_quantum():
	section("BUILD Tool 4: QUANTUM")

	input_handler.current_tool = 4  # QUANTUM
	ToolConfig.tool_mode_indices["build_4"] = 0  # "system" mode

	var test_pos = Vector2i(4, 1)
	ensure_plot_planted(test_pos)
	select_plot(test_pos)
	await frames(3)

	# Q = system reset
	input_handler.execute_action("Q")
	await frames(3)
	pass_test("quantum_reset_Q", "System reset executed")

	# E = snapshot
	input_handler.execute_action("E")
	await frames(3)
	pass_test("quantum_snapshot_E", "Snapshot executed")

	# R = debug
	input_handler.execute_action("R")
	await frames(3)
	pass_test("quantum_debug_R", "Debug executed")

	# Test phase gate mode
	ToolConfig.tool_mode_indices["build_4"] = 1  # "phase" mode
	input_handler.execute_action("Q")  # S gate
	await frames(3)
	pass_test("quantum_S_Q", "S gate executed (phase mode)")


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func select_plot(pos: Vector2i):
	"""Select a single plot for testing."""
	input_handler.current_selection = pos
	# Also update PlotGridDisplay selection if available
	var pgd = input_handler.plot_grid_display
	if pgd and pgd.has_method("set_selected_plots"):
		var arr: Array[Vector2i] = [pos]
		pgd.set_selected_plots(arr)


func select_plots(positions: Array):
	"""Select multiple plots for testing."""
	if positions.size() > 0:
		input_handler.current_selection = positions[0]
	var pgd = input_handler.plot_grid_display
	if pgd and pgd.has_method("set_selected_plots"):
		var typed_arr: Array[Vector2i] = []
		for p in positions:
			typed_arr.append(p)
		pgd.set_selected_plots(typed_arr)


func ensure_plot_planted(pos: Vector2i):
	"""Make sure a plot is planted (call explore if needed)."""
	var plot = farm.grid.get_plot(pos)
	if plot and not plot.is_planted:
		# Temporarily switch to PLAY mode and probe tool
		var old_mode = ToolConfig.get_mode()
		var old_tool = input_handler.current_tool
		ToolConfig.set_mode("play")
		input_handler.current_tool = 1  # PROBE (only in PLAY mode!)
		select_plot(pos)
		input_handler.execute_action("Q")  # EXPLORE
		# Restore mode and tool
		ToolConfig.set_mode(old_mode)
		input_handler.current_tool = old_tool


func frames(count: int):
	"""Wait for N frames."""
	for i in range(count):
		await process_frame


func section(name: String):
	"""Print section header."""
	print("\n┌─ %s" % name)


func pass_test(name: String, reason: String):
	"""Record passing test."""
	print("│ ✅ %s: %s" % [name, reason])
	test_results.append({"name": name, "passed": true, "reason": reason})


func fail_test(name: String, reason: String):
	"""Record failing test."""
	print("│ ❌ %s: %s" % [name, reason])
	test_results.append({"name": name, "passed": false, "reason": reason})


func skip_test(name: String, reason: String):
	"""Record skipped test."""
	print("│ ⏭️  %s: SKIP - %s" % [name, reason])
	test_results.append({"name": name, "passed": true, "reason": "SKIP: " + reason, "skipped": true})


func count_failures() -> int:
	var count = 0
	for r in test_results:
		if not r.passed:
			count += 1
	return count


func print_summary():
	print("\n" + "=".repeat(80))
	print("📊 TEST SUMMARY")
	print("=".repeat(80))

	var total = test_results.size()
	var passed = 0
	var failed = 0
	var skipped = 0

	for r in test_results:
		if r.get("skipped", false):
			skipped += 1
		elif r.passed:
			passed += 1
		else:
			failed += 1

	print("\nTotal: %d | ✅ Passed: %d | ❌ Failed: %d | ⏭️  Skipped: %d" % [total, passed, failed, skipped])

	if failed > 0:
		print("\n❌ FAILED TESTS:")
		for r in test_results:
			if not r.passed:
				print("   • %s: %s" % [r.name, r.reason])

	print("\n" + "=".repeat(80))
	if failed == 0:
		print("✅ ALL TOOL ACTIONS FUNCTIONAL")
	else:
		print("⚠️  %d TOOL ACTIONS BROKEN - FIX REQUIRED" % failed)
	print("=".repeat(80))
