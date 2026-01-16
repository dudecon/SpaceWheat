extends SceneTree

## Test ALL 12 BUILD mode actions
## Run with: godot --headless --script res://Tests/test_build_mode_actions.gd
##
## Tests:
##   Tool 1 (Biome): submenu_biome_assign, clear_biome_assignment, inspect_plot
##   Tool 2 (Icon): submenu_icon_assign, icon_swap, icon_clear
##   Tool 3 (Lindblad): lindblad_drive, lindblad_decay, lindblad_transfer
##   Tool 4 (System): system_reset, system_snapshot, system_debug

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

var frame_count := 0
var farm = null
var input_handler = null
var test_results := []
var scene_loaded := false
var tests_started := false

func _init():
	print("")
	print("======================================================================")
	print("  BUILD MODE ACTIONS TEST - All 12 Actions")
	print("======================================================================")
	print("")

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		_load_scene()

	if scene_loaded and not tests_started:
		var boot = root.get_node_or_null("/root/BootManager")
		if boot and boot.is_game_ready:
			tests_started = true
			_run_all_tests()

func _load_scene():
	print("Loading FarmView...")
	var scene = load("res://scenes/FarmView.tscn")
	if scene:
		var instance = scene.instantiate()
		root.add_child(instance)
		scene_loaded = true
		print("Scene loaded, waiting for game_ready...")

		var boot = root.get_node_or_null("/root/BootManager")
		if boot:
			boot.game_ready.connect(func():
				if not tests_started:
					tests_started = true
					_run_all_tests()
			)
	else:
		_fail("Failed to load FarmView.tscn")
		_finish()

func _run_all_tests():
	print("\nGame ready! Finding components...")

	# Find farm
	var farm_view = root.get_node_or_null("FarmView")
	if farm_view and "farm" in farm_view:
		farm = farm_view.farm

	if not farm:
		_fail("Could not find Farm")
		_finish()
		return

	# Find input handler
	var player_shell = _find_node(root, "PlayerShell")
	if player_shell:
		for child in player_shell.get_children():
			if child.get_script() and child.get_script().resource_path.ends_with("FarmInputHandler.gd"):
				input_handler = child
				break

	print("Farm: %s" % (farm != null))
	print("InputHandler: %s" % (input_handler != null))

	# Disable quantum evolution for faster tests
	_disable_evolution()

	# Ensure BUILD mode
	ToolConfig.set_mode("build")
	print("\nMode: %s" % ToolConfig.get_mode())

	# Run tool tests
	print("\n" + "─".repeat(70))
	print("TOOL 1: BIOME (submenu_biome_assign, clear_biome_assignment, inspect_plot)")
	print("─".repeat(70))
	_test_tool1_biome()

	print("\n" + "─".repeat(70))
	print("TOOL 2: ICON (submenu_icon_assign, icon_swap, icon_clear)")
	print("─".repeat(70))
	_test_tool2_icon()

	print("\n" + "─".repeat(70))
	print("TOOL 3: LINDBLAD (lindblad_drive, lindblad_decay, lindblad_transfer)")
	print("─".repeat(70))
	_test_tool3_lindblad()

	print("\n" + "─".repeat(70))
	print("TOOL 4: SYSTEM (system_reset, system_snapshot, system_debug)")
	print("─".repeat(70))
	_test_tool4_system()

	_finish()

func _disable_evolution():
	for biome in [farm.biotic_flux_biome, farm.forest_biome, farm.market_biome, farm.kitchen_biome]:
		if biome:
			biome.quantum_evolution_enabled = false
			biome.set_process(false)

# ============================================================================
# TOOL 1: BIOME (submenu_biome_assign, clear_biome_assignment, inspect_plot)
# ============================================================================

func _test_tool1_biome():
	var test_pos = Vector2i(2, 0)  # BioticFlux position

	# Test Q: submenu_biome_assign
	print("\n[Q] Testing SUBMENU_BIOME_ASSIGN...")
	var submenu = ToolConfig.get_submenu("biome_assign")
	if submenu:
		_pass("SUBMENU_BIOME_ASSIGN: Submenu defined")
		print("    Available: %s" % submenu.keys())
	else:
		_fail("SUBMENU_BIOME_ASSIGN: Submenu not found")

	# Test E: clear_biome_assignment
	print("\n[E] Testing CLEAR_BIOME_ASSIGNMENT...")
	if input_handler and input_handler.has_method("_action_clear_biome_assignment"):
		var plots: Array[Vector2i] = [test_pos]
		input_handler._action_clear_biome_assignment(plots)
		_pass("CLEAR_BIOME_ASSIGNMENT: Method callable")
	else:
		_fail("CLEAR_BIOME_ASSIGNMENT: Method not found")

	# Test R: inspect_plot
	print("\n[R] Testing INSPECT_PLOT...")
	if input_handler and input_handler.has_method("_action_inspect_plot"):
		var plots: Array[Vector2i] = [test_pos]
		input_handler._action_inspect_plot(plots)
		_pass("INSPECT_PLOT: Method callable")
	else:
		_fail("INSPECT_PLOT: Method not found")

# ============================================================================
# TOOL 2: ICON (submenu_icon_assign, icon_swap, icon_clear)
# ============================================================================

func _test_tool2_icon():
	var test_pos = Vector2i(2, 0)

	# Test Q: submenu_icon_assign
	print("\n[Q] Testing SUBMENU_ICON_ASSIGN...")
	var submenu = ToolConfig.get_submenu("icon_assign")
	if submenu:
		_pass("SUBMENU_ICON_ASSIGN: Submenu defined")
	else:
		_fail("SUBMENU_ICON_ASSIGN: Submenu not found")

	# Test E: icon_swap
	print("\n[E] Testing ICON_SWAP...")
	if input_handler and input_handler.has_method("_action_icon_swap"):
		var plots: Array[Vector2i] = [test_pos]
		input_handler._action_icon_swap(plots)
		_pass("ICON_SWAP: Method callable")
	else:
		_fail("ICON_SWAP: Method not found")

	# Test R: icon_clear
	print("\n[R] Testing ICON_CLEAR...")
	if input_handler and input_handler.has_method("_action_icon_clear"):
		var plots: Array[Vector2i] = [test_pos]
		input_handler._action_icon_clear(plots)
		_pass("ICON_CLEAR: Method callable")
	else:
		_fail("ICON_CLEAR: Method not found")

# ============================================================================
# TOOL 3: LINDBLAD (lindblad_drive, lindblad_decay, lindblad_transfer)
# ============================================================================

func _test_tool3_lindblad():
	var test_pos1 = Vector2i(2, 0)
	var test_pos2 = Vector2i(3, 0)

	# Test Q: lindblad_drive
	print("\n[Q] Testing LINDBLAD_DRIVE...")
	if input_handler and input_handler.has_method("_action_lindblad_drive"):
		var plots: Array[Vector2i] = [test_pos1]
		input_handler._action_lindblad_drive(plots)
		_pass("LINDBLAD_DRIVE: Method callable")
	else:
		_fail("LINDBLAD_DRIVE: Method not found")

	# Test E: lindblad_decay
	print("\n[E] Testing LINDBLAD_DECAY...")
	if input_handler and input_handler.has_method("_action_lindblad_decay"):
		var plots: Array[Vector2i] = [test_pos1]
		input_handler._action_lindblad_decay(plots)
		_pass("LINDBLAD_DECAY: Method callable")
	else:
		_fail("LINDBLAD_DECAY: Method not found")

	# Test R: lindblad_transfer
	print("\n[R] Testing LINDBLAD_TRANSFER...")
	if input_handler and input_handler.has_method("_action_lindblad_transfer"):
		var plots: Array[Vector2i] = [test_pos1, test_pos2]
		input_handler._action_lindblad_transfer(plots)
		_pass("LINDBLAD_TRANSFER: Method callable")
	else:
		_fail("LINDBLAD_TRANSFER: Method not found")

# ============================================================================
# TOOL 4: SYSTEM (system_reset, system_snapshot, system_debug)
# ============================================================================

func _test_tool4_system():
	var test_pos = Vector2i(2, 0)

	# Test Q: system_reset
	print("\n[Q] Testing SYSTEM_RESET...")
	if input_handler and input_handler.has_method("_action_system_reset"):
		var plots: Array[Vector2i] = [test_pos]
		input_handler._action_system_reset(plots)
		_pass("SYSTEM_RESET: Method callable")
	else:
		_fail("SYSTEM_RESET: Method not found")

	# Test E: system_snapshot
	print("\n[E] Testing SYSTEM_SNAPSHOT...")
	if input_handler and input_handler.has_method("_action_system_snapshot"):
		var plots: Array[Vector2i] = [test_pos]
		input_handler._action_system_snapshot(plots)
		_pass("SYSTEM_SNAPSHOT: Method callable")
	else:
		_fail("SYSTEM_SNAPSHOT: Method not found")

	# Test R: system_debug
	print("\n[R] Testing SYSTEM_DEBUG...")
	if input_handler and input_handler.has_method("_action_system_debug"):
		var plots: Array[Vector2i] = [test_pos]
		input_handler._action_system_debug(plots)
		_pass("SYSTEM_DEBUG: Method callable")
	else:
		_fail("SYSTEM_DEBUG: Method not found")

# ============================================================================
# UTILITIES
# ============================================================================

func _find_node(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node(child, target_name)
		if found:
			return found
	return null

func _pass(msg: String):
	test_results.append({"passed": true, "message": msg})
	print("  PASS: %s" % msg)

func _fail(msg: String):
	test_results.append({"passed": false, "message": msg})
	print("  FAIL: %s" % msg)

func _finish():
	print("")
	print("======================================================================")
	print("  TEST RESULTS")
	print("======================================================================")

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
		print("  ALL BUILD MODE ACTIONS WORKING!")
	else:
		print("  SOME ACTIONS NEED FIXES")
		print("")
		print("  Failed tests:")
		for result in test_results:
			if not result.passed:
				print("    - %s" % result.message)

	print("")
	print("======================================================================")

	quit(0 if failed == 0 else 1)
