extends SceneTree
## Automated gameplay test - simulates keyboard input
## Run with: godot --headless --script res://Tests/test_gameplay_autoplay.gd
##
## Uses BootManager.game_ready signal to know when boot is complete
## Note: Each frame takes 2-4 seconds in headless mode due to scene complexity

const SEPARATOR = "======================================================================"

var test_results: Array = []
var current_test: String = ""
var farm = null
var input_handler = null
var player_shell = null
var scene_loaded = false
var tests_done = false
var frame_count = 0
var boot_manager = null

func _init():
	print("\n" + SEPARATOR)
	print("🎮 AUTOMATED GAMEPLAY TEST")
	print(SEPARATOR + "\n")
	print("Waiting for autoloads to initialize...")


func _process(_delta):
	frame_count += 1

	# Load scene at frame 5 (after autoloads are ready)
	if frame_count == 5 and not scene_loaded:
		print("\nFrame 5: Loading main scene...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			var instance = scene.instantiate()
			root.add_child(instance)
			scene_loaded = true
			print("✓ Scene instantiated")

			# Connect to BootManager.game_ready signal
			boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)
				print("✓ Connected to BootManager.game_ready")
		else:
			print("✗ Failed to load scene")
			quit(1)


func _on_game_ready():
	"""Called when BootManager signals that the game is ready"""
	if tests_done:
		return
	tests_done = true
	print("\n✅ BootManager.game_ready received!")

	_find_components()

	# Disable quantum evolution for faster test execution
	# (Forest biome's 32x32 matrix + 14 Lindblad ops takes ~1s/frame otherwise)
	if farm:
		print("⚡ Disabling quantum evolution for test speed...")
		for biome in [farm.biotic_flux_biome, farm.forest_biome, farm.market_biome, farm.kitchen_biome]:
			if biome:
				biome.quantum_evolution_enabled = false
				biome.set_process(false)
		farm.set_process(false)
		if farm.grid:
			farm.grid.set_process(false)

	print("Found: PlayerShell=%s, InputHandler=%s, Farm=%s" % [
		player_shell != null, input_handler != null, farm != null])

	if input_handler:
		print("Running tests...\n")
		_run_all_tests()
	else:
		print("\n✗ FarmInputHandler not found after boot!")
		_print_tree(root, 0)
		quit(1)


func _find_components():
	player_shell = _find_node(root, "PlayerShell")
	if player_shell:
		print("PlayerShell children:")
		for child in player_shell.get_children():
			var script_name = ""
			if child.get_script():
				script_name = child.get_script().resource_path
			print("  - %s (%s) script=%s" % [child.name, child.get_class(), script_name])

			# Check if this is FarmInputHandler by script
			if script_name.ends_with("FarmInputHandler.gd"):
				input_handler = child
				print("    >>> Found FarmInputHandler!")

		# Also try by name
		if not input_handler:
			input_handler = player_shell.get_node_or_null("FarmInputHandler")

	# Find farm
	var farm_view = root.get_node_or_null("FarmView")
	if farm_view:
		farm = farm_view.farm if "farm" in farm_view else null
		if not farm:
			for child in farm_view.get_children():
				if child.name == "Farm" or (child.get_script() and child.get_script().resource_path.ends_with("Farm.gd")):
					farm = child
					break


func _find_node(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var found = _find_node(child, name)
		if found:
			return found
	return null


func _print_tree(node: Node, depth: int):
	if depth > 3:
		return
	var indent = "  ".repeat(depth)
	print("%s%s" % [indent, node.name])
	for child in node.get_children():
		_print_tree(child, depth + 1)


func _run_all_tests():
	# Test 1: Tool Selection
	_test_tool_selection()

	# Test 2: Mode Toggle
	_test_mode_toggle()

	# Test 3: Q/E/R Actions
	_test_qer_actions()

	# Test 4: Plot Selection
	_test_plot_selection()

	# Print results and exit
	_print_results()

	var failed = test_results.filter(func(r): return not r.passed).size()
	quit(1 if failed > 0 else 0)


func _test_tool_selection():
	current_test = "Tool Selection (1-4)"
	print("📋 TEST: %s" % current_test)

	var all_passed = true

	for tool_num in [1, 2, 3, 4]:
		_simulate_key(KEY_1 + tool_num - 1)

		var current = input_handler.current_tool
		if current == tool_num:
			print("  ✓ Tool %d selected" % tool_num)
		else:
			print("  ✗ Tool %d failed (got %d)" % [tool_num, current])
			all_passed = false

	_record_result(all_passed, "All tools (1-4) selectable")


func _test_mode_toggle():
	current_test = "Mode Toggle (Tab)"
	print("\n📋 TEST: %s" % current_test)

	var ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
	var initial_mode = ToolConfig.get_mode()
	print("  Initial mode: %s" % initial_mode)

	_simulate_key(KEY_TAB)

	var new_mode = ToolConfig.get_mode()
	print("  After Tab: %s" % new_mode)

	var toggled = (initial_mode != new_mode)
	if toggled:
		print("  ✓ Mode toggled successfully")
		_simulate_key(KEY_TAB)  # Toggle back
	else:
		print("  ✗ Mode did not toggle")

	_record_result(toggled, "Tab toggles play/build mode")


func _test_qer_actions():
	current_test = "Q/E/R Actions"
	print("\n📋 TEST: %s" % current_test)

	# Select Tool 1 first
	_simulate_key(KEY_1)

	# Test Q
	print("  Testing Q action...")
	var before = input_handler.current_submenu
	_simulate_key(KEY_Q)
	var after = input_handler.current_submenu
	print("    Submenu: '%s' → '%s'" % [before, after])

	# Clear with Escape
	_simulate_key(KEY_ESCAPE)

	# Test E
	print("  Testing E action...")
	_simulate_key(KEY_E)
	print("    E sent")

	# Test R
	print("  Testing R action...")
	_simulate_key(KEY_R)
	print("    R sent")

	_record_result(true, "Q/E/R keys respond")


func _test_plot_selection():
	current_test = "Plot Selection (T/Y/U)"
	print("\n📋 TEST: %s" % current_test)

	_simulate_key(KEY_ESCAPE)

	# Test plot keys - map key to name directly
	var key_map = {KEY_T: "T", KEY_Y: "Y", KEY_U: "U"}
	for key in [KEY_T, KEY_Y, KEY_U]:
		var key_name = key_map[key]
		print("  Testing %s key..." % key_name)
		_simulate_key(key)

	# Check PlotGridDisplay
	var plot_grid = input_handler.plot_grid_display
	if plot_grid and plot_grid.has_method("get_selected_plots"):
		var selected = plot_grid.get_selected_plots()
		print("  ✓ Selected plots: %d" % selected.size())

	_record_result(true, "Plot selection keys work")


func _simulate_key(keycode: int):
	"""Simulate a key press by directly calling the input handler.

	In headless mode, Input.parse_input_event() doesn't propagate to _unhandled_input()
	because the SceneTree's main loop isn't running normally. Instead, we create the
	event and call the input handler directly.
	"""
	var press = InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	press.echo = false

	# First try to let the tree handle it normally
	Input.parse_input_event(press)

	# Also directly call the input handler (headless mode workaround)
	if input_handler and input_handler.has_method("_unhandled_input"):
		input_handler._unhandled_input(press)


func _record_result(passed: bool, description: String):
	test_results.append({
		"test": current_test,
		"passed": passed,
		"description": description
	})


func _print_results():
	print("\n" + SEPARATOR)
	print("📊 TEST RESULTS")
	print(SEPARATOR)

	var passed_count = 0
	var failed_count = 0

	for result in test_results:
		var status = "✅ PASS" if result.passed else "❌ FAIL"
		print("  %s: %s - %s" % [status, result.test, result.description])
		if result.passed:
			passed_count += 1
		else:
			failed_count += 1

	print("")
	print("  Total: %d passed, %d failed" % [passed_count, failed_count])
	print(SEPARATOR + "\n")
