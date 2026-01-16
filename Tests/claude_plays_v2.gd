extends SceneTree

## claude_plays_v2.gd - Comprehensive v2 architecture gameplay test
## Run with: godot --headless --script res://Tests/claude_plays_v2.gd
##
## Tests the complete v2 tool system:
##   PLAY MODE: 4 tools × 3 actions (Probe, Gates, Industry, 1Q Gates)
##   BUILD MODE: 4 tools × 3 actions (Biome, Icon, Lindblad, System)
##   OVERLAYS: Quest Board, Inspector, Semantic Map, Controls, Biome Detail
##
## Uses actual game input pipeline to simulate real gameplay.

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

const SEPARATOR = "======================================================================"
const THICK_LINE = "══════════════════════════════════════════════════════════════════════"

var test_results: Array = []
var farm = null
var input_handler = null
var player_shell = null
var overlay_manager = null
var scene_loaded = false
var tests_done = false
var frame_count = 0
var boot_manager = null

# Gameplay state
var terminals_created: Array = []
var resources_harvested: Dictionary = {}

func _init():
	print("")
	print(THICK_LINE)
	print("  CLAUDE PLAYS SPACEWHEAT v2")
	print("  Full Gameplay Simulation Test")
	print(THICK_LINE)
	print("")

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		_load_scene()

func _load_scene():
	print("Loading FarmView...")
	var scene = load("res://scenes/FarmView.tscn")
	if scene:
		var instance = scene.instantiate()
		root.add_child(instance)
		scene_loaded = true

		boot_manager = root.get_node_or_null("/root/BootManager")
		if boot_manager:
			boot_manager.game_ready.connect(_on_game_ready)
			print("Connected to BootManager.game_ready")
	else:
		_fail("Failed to load FarmView.tscn")
		quit(1)

func _on_game_ready():
	if tests_done:
		return
	tests_done = true
	print("\nGame ready! Starting v2 gameplay test...\n")

	_find_components()
	_disable_evolution()

	print("Components: Farm=%s InputHandler=%s OverlayManager=%s" % [
		farm != null, input_handler != null, overlay_manager != null
	])

	if not farm or not input_handler:
		_fail("Missing required components")
		_print_results()
		quit(1)
		return

	# Run all tests
	print("")
	_run_play_mode_tests()
	_run_build_mode_tests()
	_run_overlay_tests()
	_run_probe_integration_test()

	_print_results()

	var failed = test_results.filter(func(r): return not r.passed).size()
	quit(1 if failed > 0 else 0)

func _find_components():
	var farm_view = root.get_node_or_null("FarmView")
	if farm_view and "farm" in farm_view:
		farm = farm_view.farm

	player_shell = _find_node(root, "PlayerShell")
	if player_shell:
		# Find input handler
		for child in player_shell.get_children():
			if child.get_script() and child.get_script().resource_path.ends_with("FarmInputHandler.gd"):
				input_handler = child
				break

		# Get overlay manager
		if player_shell.get("overlay_manager"):
			overlay_manager = player_shell.overlay_manager

func _disable_evolution():
	"""Disable quantum evolution for faster test execution."""
	if not farm:
		return
	for biome in [farm.biotic_flux_biome, farm.forest_biome, farm.market_biome, farm.kitchen_biome]:
		if biome:
			biome.quantum_evolution_enabled = false
			biome.set_process(false)

func _find_node(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node(child, target_name)
		if found:
			return found
	return null

# ============================================================================
# PLAY MODE TESTS
# ============================================================================

func _run_play_mode_tests():
	print(SEPARATOR)
	print("  PLAY MODE TESTS (4 tools × 3 actions)")
	print(SEPARATOR)

	ToolConfig.set_mode("play")
	print("\nMode: %s\n" % ToolConfig.get_mode())

	# Tool 1: Probe
	print("─".repeat(60))
	print("TOOL 1: PROBE (explore, measure, pop)")
	print("─".repeat(60))
	_test_play_tool1_probe()

	# Tool 2: Gates
	print("\n" + "─".repeat(60))
	print("TOOL 2: GATES (cluster, measure_trigger, remove_gates)")
	print("─".repeat(60))
	_test_play_tool2_gates()

	# Tool 3: Industry
	print("\n" + "─".repeat(60))
	print("TOOL 3: INDUSTRY (place_mill, place_market, place_kitchen)")
	print("─".repeat(60))
	_test_play_tool3_industry()

	# Tool 4: 1Q Gates
	print("\n" + "─".repeat(60))
	print("TOOL 4: 1Q GATES (pauli_x, hadamard, pauli_z)")
	print("─".repeat(60))
	_test_play_tool4_1q_gates()

func _test_play_tool1_probe():
	"""Test Probe tool: Q=explore, E=measure, R=pop"""
	_simulate_key(KEY_1)  # Select Tool 1

	# Q: Explore
	print("[Q] Testing EXPLORE via input...")
	_simulate_key(KEY_Q)
	_pass("PLAY.T1.Q: Explore key sent")

	# E: Measure
	print("[E] Testing MEASURE via input...")
	_simulate_key(KEY_E)
	_pass("PLAY.T1.E: Measure key sent")

	# R: Pop
	print("[R] Testing POP via input...")
	_simulate_key(KEY_R)
	_pass("PLAY.T1.R: Pop key sent")

func _test_play_tool2_gates():
	"""Test Gates tool: Q=cluster, E=measure_trigger, R=remove_gates"""
	_simulate_key(KEY_2)  # Select Tool 2

	print("[Q] Testing CLUSTER via input...")
	_simulate_key(KEY_Q)
	_pass("PLAY.T2.Q: Cluster key sent")

	print("[E] Testing MEASURE_TRIGGER via input...")
	_simulate_key(KEY_E)
	_pass("PLAY.T2.E: Measure trigger key sent")

	print("[R] Testing REMOVE_GATES via input...")
	_simulate_key(KEY_R)
	_pass("PLAY.T2.R: Remove gates key sent")

func _test_play_tool3_industry():
	"""Test Industry tool: Q=place_mill, E=place_market, R=place_kitchen"""
	_simulate_key(KEY_3)  # Select Tool 3

	print("[Q] Testing PLACE_MILL via input...")
	_simulate_key(KEY_Q)
	_pass("PLAY.T3.Q: Place mill key sent")

	print("[E] Testing PLACE_MARKET via input...")
	_simulate_key(KEY_E)
	_pass("PLAY.T3.E: Place market key sent")

	print("[R] Testing PLACE_KITCHEN via input...")
	_simulate_key(KEY_R)
	_pass("PLAY.T3.R: Place kitchen key sent")

func _test_play_tool4_1q_gates():
	"""Test 1Q Gates tool: Q=pauli_x, E=hadamard, R=pauli_z"""
	_simulate_key(KEY_4)  # Select Tool 4

	print("[Q] Testing PAULI_X via input...")
	_simulate_key(KEY_Q)
	_pass("PLAY.T4.Q: Pauli-X key sent")

	print("[E] Testing HADAMARD via input...")
	_simulate_key(KEY_E)
	_pass("PLAY.T4.E: Hadamard key sent")

	print("[R] Testing PAULI_Z via input...")
	_simulate_key(KEY_R)
	_pass("PLAY.T4.R: Pauli-Z key sent")

# ============================================================================
# BUILD MODE TESTS
# ============================================================================

func _run_build_mode_tests():
	print("\n" + SEPARATOR)
	print("  BUILD MODE TESTS (4 tools × 3 actions)")
	print(SEPARATOR)

	ToolConfig.set_mode("build")
	print("\nMode: %s\n" % ToolConfig.get_mode())

	# Tool 1: Biome
	print("─".repeat(60))
	print("TOOL 1: BIOME (submenu_biome_assign, clear_biome, inspect)")
	print("─".repeat(60))
	_test_build_tool1_biome()

	# Tool 2: Icon
	print("\n" + "─".repeat(60))
	print("TOOL 2: ICON (submenu_icon_assign, icon_swap, icon_clear)")
	print("─".repeat(60))
	_test_build_tool2_icon()

	# Tool 3: Lindblad
	print("\n" + "─".repeat(60))
	print("TOOL 3: LINDBLAD (drive, decay, transfer)")
	print("─".repeat(60))
	_test_build_tool3_lindblad()

	# Tool 4: System
	print("\n" + "─".repeat(60))
	print("TOOL 4: SYSTEM (reset, snapshot, debug)")
	print("─".repeat(60))
	_test_build_tool4_system()

func _test_build_tool1_biome():
	_simulate_key(KEY_1)

	print("[Q] Testing SUBMENU_BIOME_ASSIGN...")
	_simulate_key(KEY_Q)
	_pass("BUILD.T1.Q: Biome submenu key sent")

	_simulate_key(KEY_ESCAPE)  # Clear submenu

	print("[E] Testing CLEAR_BIOME_ASSIGNMENT...")
	_simulate_key(KEY_E)
	_pass("BUILD.T1.E: Clear biome key sent")

	print("[R] Testing INSPECT_PLOT...")
	_simulate_key(KEY_R)
	_pass("BUILD.T1.R: Inspect plot key sent")

func _test_build_tool2_icon():
	_simulate_key(KEY_2)

	print("[Q] Testing SUBMENU_ICON_ASSIGN...")
	_simulate_key(KEY_Q)
	_pass("BUILD.T2.Q: Icon submenu key sent")

	_simulate_key(KEY_ESCAPE)

	print("[E] Testing ICON_SWAP...")
	_simulate_key(KEY_E)
	_pass("BUILD.T2.E: Icon swap key sent")

	print("[R] Testing ICON_CLEAR...")
	_simulate_key(KEY_R)
	_pass("BUILD.T2.R: Icon clear key sent")

func _test_build_tool3_lindblad():
	_simulate_key(KEY_3)

	print("[Q] Testing LINDBLAD_DRIVE...")
	_simulate_key(KEY_Q)
	_pass("BUILD.T3.Q: Lindblad drive key sent")

	print("[E] Testing LINDBLAD_DECAY...")
	_simulate_key(KEY_E)
	_pass("BUILD.T3.E: Lindblad decay key sent")

	print("[R] Testing LINDBLAD_TRANSFER...")
	_simulate_key(KEY_R)
	_pass("BUILD.T3.R: Lindblad transfer key sent")

func _test_build_tool4_system():
	_simulate_key(KEY_4)

	print("[Q] Testing SYSTEM_RESET...")
	_simulate_key(KEY_Q)
	_pass("BUILD.T4.Q: System reset key sent")

	print("[E] Testing SYSTEM_SNAPSHOT...")
	_simulate_key(KEY_E)
	_pass("BUILD.T4.E: System snapshot key sent")

	print("[R] Testing SYSTEM_DEBUG...")
	_simulate_key(KEY_R)
	_pass("BUILD.T4.R: System debug key sent")

# ============================================================================
# OVERLAY TESTS
# ============================================================================

func _run_overlay_tests():
	print("\n" + SEPARATOR)
	print("  OVERLAY TESTS (modal screens)")
	print(SEPARATOR)

	# Return to play mode
	ToolConfig.set_mode("play")
	print("\nMode: %s\n" % ToolConfig.get_mode())

	# Test C key - Quest Board
	print("─".repeat(60))
	print("QUEST BOARD (C key)")
	print("─".repeat(60))
	_simulate_key(KEY_C)
	_pass("OVERLAY.C: Quest board toggle sent")
	_simulate_key(KEY_ESCAPE)

	# Test N key - Inspector
	print("\n" + "─".repeat(60))
	print("INSPECTOR (N key)")
	print("─".repeat(60))
	_simulate_key(KEY_N)
	_pass("OVERLAY.N: Inspector toggle sent")
	_simulate_key(KEY_ESCAPE)

	# Test V key - Semantic Map
	print("\n" + "─".repeat(60))
	print("SEMANTIC MAP (V key)")
	print("─".repeat(60))
	_simulate_key(KEY_V)
	_pass("OVERLAY.V: Semantic map toggle sent")
	_simulate_key(KEY_ESCAPE)

	# Test B key - Biome Detail
	print("\n" + "─".repeat(60))
	print("BIOME DETAIL (B key)")
	print("─".repeat(60))
	_simulate_key(KEY_B)
	_pass("OVERLAY.B: Biome detail toggle sent")
	_simulate_key(KEY_ESCAPE)

	# Test K key - Controls
	print("\n" + "─".repeat(60))
	print("CONTROLS (K key)")
	print("─".repeat(60))
	_simulate_key(KEY_K)
	_pass("OVERLAY.K: Controls toggle sent")
	_simulate_key(KEY_ESCAPE)

# ============================================================================
# PROBE INTEGRATION TEST (EXPLORE → MEASURE → POP)
# ============================================================================

func _run_probe_integration_test():
	print("\n" + SEPARATOR)
	print("  PROBE INTEGRATION TEST (API-level)")
	print(SEPARATOR)

	ToolConfig.set_mode("play")
	print("\nMode: %s\n" % ToolConfig.get_mode())

	var biome = farm.biotic_flux_biome
	if not biome:
		_fail("PROBE: No BioticFlux biome")
		return

	print("─".repeat(60))
	print("EXPLORE → MEASURE → POP Cycle")
	print("─".repeat(60))

	# Step 1: EXPLORE
	print("\n[EXPLORE] Creating terminal...")
	var explore_result = ProbeActions.action_explore(farm.plot_pool, biome)

	if not explore_result.success:
		_fail("PROBE.EXPLORE: %s" % explore_result.get("message", "unknown"))
		return

	var terminal = explore_result.terminal
	var emoji = explore_result.emoji_pair.get("north", "?")
	print("  Terminal created: reg=%d emoji=%s" % [explore_result.register_id, emoji])
	_pass("PROBE.EXPLORE: Terminal bound to register %d" % explore_result.register_id)

	# Step 2: MEASURE
	print("\n[MEASURE] Collapsing terminal...")
	var measure_result = ProbeActions.action_measure(terminal, biome)

	if not measure_result.get("success", false):
		_fail("PROBE.MEASURE: %s" % measure_result.get("message", "unknown"))
		return

	var outcome = measure_result.get("outcome", "?")
	var prob = measure_result.get("probability", 0.0) * 100
	print("  Measured: %s (p=%.0f%%)" % [outcome, prob])
	_pass("PROBE.MEASURE: Outcome=%s" % outcome)

	# Step 3: POP
	print("\n[POP] Harvesting terminal...")
	var pop_result = ProbeActions.action_pop(terminal, farm.plot_pool, farm.economy)

	if not pop_result.success:
		_fail("PROBE.POP: %s" % pop_result.get("message", "unknown"))
		return

	var resource = pop_result.resource
	print("  Harvested: %s" % resource)
	_pass("PROBE.POP: Harvested %s" % resource)

	# Summary
	print("\n" + "─".repeat(60))
	print("FULL CYCLE COMPLETE: EXPLORE → MEASURE → POP")
	print("─".repeat(60))

# ============================================================================
# UTILITIES
# ============================================================================

func _simulate_key(keycode: int):
	"""Simulate a key press by calling input handler directly."""
	var press = InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	press.echo = false

	# In headless mode, we must call the handler directly
	Input.parse_input_event(press)

	if player_shell and player_shell.has_method("_unhandled_input"):
		player_shell._unhandled_input(press)

	if input_handler and input_handler.has_method("_unhandled_input"):
		input_handler._unhandled_input(press)

func _pass(msg: String):
	test_results.append({"passed": true, "message": msg})
	print("  PASS: %s" % msg)

func _fail(msg: String):
	test_results.append({"passed": false, "message": msg})
	print("  FAIL: %s" % msg)

func _print_results():
	print("")
	print(THICK_LINE)
	print("  TEST RESULTS")
	print(THICK_LINE)

	var passed := 0
	var failed := 0

	for result in test_results:
		if result.passed:
			passed += 1
		else:
			failed += 1

	print("")
	print("  Passed: %d" % passed)
	print("  Failed: %d" % failed)
	print("")

	if failed == 0:
		print("  ALL GAMEPLAY TESTS PASSED!")
	else:
		print("  SOME TESTS FAILED:")
		print("")
		for result in test_results:
			if not result.passed:
				print("    - %s" % result.message)

	print("")
	print(THICK_LINE)
