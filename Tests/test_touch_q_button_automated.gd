extends SceneTree

## Automated test: Touch Q button multiple times to verify display updates
## Tests if the fix for signal chain blocking works reliably

var test_passed = true
var test_count = 0

func _init():
	print("\n")
	print("================================================================================")
	print("AUTOMATED TEST: Touch Q Button - Multiple Iterations")
	print("================================================================================")
	print("")

	# Load the game scene
	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		_fail("Failed to load FarmView scene")
		return

	var farm_view = scene.instantiate()
	root.add_child(farm_view)

	print("✅ Game scene loaded")
	print("")

	# Wait for scene to initialize
	await create_timer(2.0).timeout

	# Find components
	var input_handler = _find_input_handler(farm_view)
	if not input_handler:
		_fail("Could not find FarmInputHandler")
		return

	var plot_grid = _find_plot_grid_display(farm_view)
	if not plot_grid:
		_fail("Could not find PlotGridDisplay")
		return

	var action_bar = _find_action_preview_row(farm_view)
	if not action_bar:
		_fail("Could not find ActionPreviewRow")
		return

	print("✅ Found all components:")
	print("   - FarmInputHandler")
	print("   - PlotGridDisplay")
	print("   - ActionPreviewRow")
	print("")

	# Get Q button reference
	var q_button = action_bar.action_buttons.get("Q")
	if not q_button:
		_fail("Could not find Q button")
		return

	print("✅ Found Q button, initial text: '%s'" % q_button.text)
	print("")

	# Select a plot first (required for actions)
	print("📍 Selecting plot (2, 0) for testing...")
	plot_grid.toggle_plot_selection(Vector2i(2, 0))
	await create_timer(0.3).timeout

	# Select tool 1 (Grower)
	print("🔧 Selecting Tool 1 (Grower)...")
	input_handler._select_tool(1)
	await create_timer(0.3).timeout

	print("")
	print("================================================================================")
	print("RUNNING TESTS")
	print("================================================================================")
	print("")

	# Test 1: First touch Q
	await _test_touch_q(action_bar, q_button, input_handler, 1)

	# Test 2: Touch Q again (plant action)
	await create_timer(0.5).timeout
	await _test_touch_q(action_bar, q_button, input_handler, 2)

	# Reset: Exit submenu if needed
	if input_handler.current_submenu != "":
		input_handler._exit_submenu()
		await create_timer(0.5).timeout

	# Test 3: Third touch Q
	await _test_touch_q(action_bar, q_button, input_handler, 3)

	# Test 4: Fourth touch Q (plant action again)
	await create_timer(0.5).timeout
	await _test_touch_q(action_bar, q_button, input_handler, 4)

	# Test 5: Fifth touch Q (after reset)
	if input_handler.current_submenu != "":
		input_handler._exit_submenu()
		await create_timer(0.5).timeout
	await _test_touch_q(action_bar, q_button, input_handler, 5)

	# Print summary
	print("")
	print("================================================================================")
	print("TEST SUMMARY")
	print("================================================================================")
	if test_passed:
		print("✅ ALL TESTS PASSED (%d iterations)" % test_count)
	else:
		print("❌ TESTS FAILED")
	print("================================================================================")
	print("")

	quit()


func _test_touch_q(action_bar, q_button, input_handler, iteration: int) -> void:
	"""Test a single touch Q interaction"""
	test_count = iteration

	print("────────────────────────────────────────────────────────────────────────────────")
	print("TEST %d: Touch Q Button" % iteration)
	print("────────────────────────────────────────────────────────────────────────────────")

	var initial_submenu = input_handler.current_submenu
	var initial_text = q_button.text

	print("  BEFORE:")
	print("    Submenu: '%s'" % initial_submenu)
	print("    Q button text: '%s'" % initial_text)
	print("")

	# Simulate touch by emitting action_pressed signal
	print("  ⚡ Emitting action_pressed('Q')...")
	action_bar.action_pressed.emit("Q")

	# Wait for deferred execution to complete
	await create_timer(0.2).timeout

	var final_submenu = input_handler.current_submenu
	var final_text = q_button.text

	print("")
	print("  AFTER:")
	print("    Submenu: '%s'" % final_submenu)
	print("    Q button text: '%s'" % final_text)
	print("")

	# Determine expected behavior based on initial state
	var expected_submenu_change = false
	var expected_text_change = false

	if initial_submenu == "":
		# Should enter submenu
		expected_submenu_change = true
		expected_text_change = true
		if final_submenu != "plant":
			_fail("TEST %d: Expected submenu='plant', got '%s'" % [iteration, final_submenu])
			return
		if final_text == initial_text:
			_fail("TEST %d: Q button text did not change! Still: '%s'" % [iteration, final_text])
			return
		if not ("Wheat" in final_text or "Flour" in final_text or "Bread" in final_text):
			_fail("TEST %d: Q button text doesn't show expected plant options: '%s'" % [iteration, final_text])
			return
	else:
		# Should execute submenu action (plant)
		expected_submenu_change = true  # Should exit back to ""
		if final_submenu != "":
			_fail("TEST %d: Expected submenu to exit, still: '%s'" % [iteration, final_submenu])
			return

	print("  RESULT: ✅ PASSED")
	print("")


func _fail(message: String) -> void:
	"""Mark test as failed and quit"""
	print("")
	print("❌ FAILURE: %s" % message)
	print("")
	test_passed = false
	quit()


func _find_input_handler(node: Node) -> Node:
	"""Recursively find FarmInputHandler"""
	if node.name == "FarmInputHandler" or "InputHandler" in node.name:
		return node

	var script = node.get_script()
	if script and script.get_global_name() == "FarmInputHandler":
		return node

	for child in node.get_children():
		var result = _find_input_handler(child)
		if result:
			return result

	return null


func _find_plot_grid_display(node: Node) -> Node:
	"""Recursively find PlotGridDisplay"""
	if node.name == "PlotGridDisplay":
		return node

	var script = node.get_script()
	if script and "PlotGridDisplay" in str(script.resource_path):
		return node

	for child in node.get_children():
		var result = _find_plot_grid_display(child)
		if result:
			return result

	return null


func _find_action_preview_row(node: Node) -> Node:
	"""Recursively find ActionPreviewRow"""
	var script = node.get_script()
	if script and script.get_global_name() == "ActionPreviewRow":
		return node

	if node.name == "ActionPreviewRow" or "ActionPreview" in node.name:
		return node

	for child in node.get_children():
		var result = _find_action_preview_row(child)
		if result:
			return result

	return null
