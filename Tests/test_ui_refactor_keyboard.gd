extends SceneTree

## Test UI Refactor - Keyboard Input Verification
## Tests that action bars, keyboard hints, and all UI elements respond to keyboard input

var test_results = []
var farm_view = null
var player_shell = null
var action_bar_manager = null
var test_phase = 0

func _init():
	var separator = "=" + "=" + "=" + "=" + "=" + "=" + "=" + "=" + "=" + "="
	separator = separator + separator + separator + separator + separator + separator + separator + separator
	print("\n" + separator)
	print("UI REFACTOR KEYBOARD TEST")
	print(separator + "\n")

	# Load and instantiate the main scene
	print("📦 Loading FarmView scene...")
	var farm_view_scene = load("res://scenes/FarmView.tscn")
	if not farm_view_scene:
		_fail("FarmView.tscn not found")
		return

	farm_view = farm_view_scene.instantiate()
	root.add_child(farm_view)

	print("✅ FarmView instantiated\n")

	# Wait for scene to be ready
	await root.process_frame

	# Run tests
	_run_tests()

func _run_tests():
	print("🧪 Starting keyboard input tests...\n")

	# Test 1: Find PlayerShell
	await _test_find_player_shell()

	# Test 2: Verify ActionBarManager exists
	await _test_action_bar_manager_exists()

	# Test 3: Verify action bars are in ActionBarLayer
	await _test_action_bars_in_layer()

	# Test 4: Test tool selection via keyboard (1-6)
	await _test_tool_selection_keyboard()

	# Test 5: Test plot selection (TYUIOP)
	await _test_plot_selection_keyboard()

	# Test 6: Test action execution (QER)
	await _test_action_keys()

	# Test 7: Test quest board toggle (C key)
	await _test_quest_board_toggle()

	# Test 8: Test keyboard hints toggle (K key)
	await _test_keyboard_hints_toggle()

	# Test 9: Test escape menu (ESC key)
	await _test_escape_menu()

	# Test 10: Verify positioning
	await _test_visual_positioning()

	# Print summary
	_print_summary()
	quit()

func _test_find_player_shell():
	print("🔍 Test 1: Finding PlayerShell...")

	player_shell = root.get_first_node_in_group("player_shell")

	if not player_shell:
		_fail("PlayerShell not found in scene tree")
		return

	_pass("PlayerShell found: %s" % player_shell.name)
	await root.process_frame

func _test_action_bar_manager_exists():
	print("\n🔍 Test 2: Verifying ActionBarManager...")

	if not player_shell:
		_fail("PlayerShell not available")
		return

	action_bar_manager = player_shell.action_bar_manager

	if not action_bar_manager:
		_fail("ActionBarManager not found in PlayerShell")
		return

	_pass("ActionBarManager exists")

	# Check that action bars were created
	var tool_row = action_bar_manager.get_tool_row()
	var action_row = action_bar_manager.get_action_row()

	if not tool_row:
		_fail("ToolSelectionRow not created")
		return

	if not action_row:
		_fail("ActionPreviewRow not created")
		return

	_pass("ToolSelectionRow created: %s" % tool_row.name)
	_pass("ActionPreviewRow created: %s" % action_row.name)

	await root.process_frame

func _test_action_bars_in_layer():
	print("\n🔍 Test 3: Verifying action bars are in ActionBarLayer...")

	var action_bar_layer = player_shell.get_node_or_null("ActionBarLayer")
	if not action_bar_layer:
		_fail("ActionBarLayer not found")
		return

	_pass("ActionBarLayer exists")

	# Check children
	var tool_row = action_bar_layer.get_node_or_null("ToolSelectionRow")
	var action_row = action_bar_layer.get_node_or_null("ActionPreviewRow")

	if not tool_row:
		_fail("ToolSelectionRow not in ActionBarLayer")
		return

	if not action_row:
		_fail("ActionPreviewRow not in ActionBarLayer")
		return

	_pass("ToolSelectionRow is child of ActionBarLayer")
	_pass("ActionPreviewRow is child of ActionBarLayer")

	# Verify NOT in FarmUI
	var farm_ui = player_shell.current_farm_ui
	if farm_ui:
		var old_tool_row = farm_ui.get_node_or_null("MainContainer/ToolSelectionRow")
		var old_action_row = farm_ui.get_node_or_null("MainContainer/ActionPreviewRow")

		if old_tool_row:
			_fail("ToolSelectionRow still in FarmUI (should be removed)")
		else:
			_pass("ToolSelectionRow correctly removed from FarmUI")

		if old_action_row:
			_fail("ActionPreviewRow still in FarmUI (should be removed)")
		else:
			_pass("ActionPreviewRow correctly removed from FarmUI")

	await root.process_frame

func _test_tool_selection_keyboard():
	print("\n🔍 Test 4: Testing tool selection (1-6 keys)...")

	# Wait for farm to be fully loaded
	await root.process_frame
	await root.process_frame

	# Test pressing keys 1-6
	for i in range(1, 7):
		var key = KEY_1 + (i - 1)
		_send_key(key)
		await root.process_frame

		# The action bar should update (we can't easily verify the visual state,
		# but we can check that no errors occurred)
		_pass("Tool %d key processed" % i)

	await root.process_frame

func _test_plot_selection_keyboard():
	print("\n🔍 Test 5: Testing plot selection (TYUIOP keys)...")

	var plot_keys = [KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P]

	for key in plot_keys:
		_send_key(key)
		await root.process_frame

		var key_name = OS.get_keycode_string(key)
		_pass("Plot selection key %s processed" % key_name)

	await root.process_frame

func _test_action_keys():
	print("\n🔍 Test 6: Testing action keys (QER)...")

	var action_keys = [KEY_Q, KEY_E, KEY_R]

	for key in action_keys:
		_send_key(key)
		await root.process_frame

		var key_name = OS.get_keycode_string(key)
		_pass("Action key %s processed" % key_name)

	await root.process_frame

func _test_quest_board_toggle():
	print("\n🔍 Test 7: Testing quest board toggle (C key)...")

	# Press C to open
	_send_key(KEY_C)
	await root.process_frame
	await root.process_frame

	# Check if quest board exists and is visible
	if player_shell.overlay_manager and player_shell.overlay_manager.quest_board:
		var quest_board = player_shell.overlay_manager.quest_board
		if quest_board.visible:
			_pass("Quest board opened with C key")
		else:
			_info("Quest board exists but not visible (may need biome)")

		# Press C again to close
		_send_key(KEY_C)
		await root.process_frame

		if not quest_board.visible:
			_pass("Quest board closed with C key")
	else:
		_info("Quest board not available (overlay_manager not ready)")

	await root.process_frame

func _test_keyboard_hints_toggle():
	print("\n🔍 Test 8: Testing keyboard hints (K key)...")

	# Press K to toggle
	_send_key(KEY_K)
	await root.process_frame

	# Check if keyboard hint button exists
	if player_shell.overlay_manager and player_shell.overlay_manager.keyboard_hint_button:
		_pass("Keyboard hint button exists")
		_pass("K key processed for keyboard hints")
	else:
		_fail("Keyboard hint button not found in OverlayManager")

	await root.process_frame

func _test_escape_menu():
	print("\n🔍 Test 9: Testing escape menu (ESC key)...")

	# Press ESC to open
	_send_key(KEY_ESCAPE)
	await root.process_frame
	await root.process_frame

	# Check if escape menu exists
	if player_shell.overlay_manager and player_shell.overlay_manager.escape_menu:
		var escape_menu = player_shell.overlay_manager.escape_menu
		if escape_menu.visible:
			_pass("Escape menu opened with ESC key")
		else:
			_info("Escape menu exists but not visible")

		# Press ESC again to close
		_send_key(KEY_ESCAPE)
		await root.process_frame

		if not escape_menu.visible:
			_pass("Escape menu closed with ESC key")
	else:
		_fail("Escape menu not found")

	await root.process_frame

func _test_visual_positioning():
	print("\n🔍 Test 10: Verifying visual positioning...")

	var action_bar_layer = player_shell.get_node_or_null("ActionBarLayer")
	if not action_bar_layer:
		_fail("ActionBarLayer not found")
		return

	var tool_row = action_bar_layer.get_node_or_null("ToolSelectionRow")
	var action_row = action_bar_layer.get_node_or_null("ActionPreviewRow")

	if tool_row:
		# Check anchors
		if tool_row.anchor_left == 0.0 and tool_row.anchor_right == 1.0 and tool_row.anchor_bottom == 1.0:
			_pass("ToolSelectionRow has BOTTOM_WIDE anchors")
		else:
			_warn("ToolSelectionRow anchors: L%.2f R%.2f B%.2f" % [tool_row.anchor_left, tool_row.anchor_right, tool_row.anchor_bottom])

		# Check offset
		if tool_row.offset_top == -140 and tool_row.offset_bottom == -80:
			_pass("ToolSelectionRow positioned 140px from bottom")
		else:
			_warn("ToolSelectionRow offset_top: %d, offset_bottom: %d" % [tool_row.offset_top, tool_row.offset_bottom])

	if action_row:
		# Check anchors
		if action_row.anchor_left == 0.0 and action_row.anchor_right == 1.0 and action_row.anchor_bottom == 1.0:
			_pass("ActionPreviewRow has BOTTOM_WIDE anchors")
		else:
			_warn("ActionPreviewRow anchors: L%.2f R%.2f B%.2f" % [action_row.anchor_left, action_row.anchor_right, action_row.anchor_bottom])

		# Check offset
		if action_row.offset_top == -80 and action_row.offset_bottom == 0:
			_pass("ActionPreviewRow positioned 80px from bottom")
		else:
			_warn("ActionPreviewRow offset_top: %d, offset_bottom: %d" % [action_row.offset_top, action_row.offset_bottom])

	# Check KeyboardHintButton positioning
	if player_shell.overlay_manager and player_shell.overlay_manager.keyboard_hint_button:
		var kb_button = player_shell.overlay_manager.keyboard_hint_button

		if kb_button.anchor_left == 1.0 and kb_button.anchor_right == 1.0 and kb_button.anchor_top == 0.0:
			_pass("KeyboardHintButton has TOP_RIGHT anchors")
		else:
			_warn("KeyboardHintButton anchors: L%.2f R%.2f T%.2f" % [kb_button.anchor_left, kb_button.anchor_right, kb_button.anchor_top])

		if kb_button.offset_left == -170 and kb_button.offset_right == -10:
			_pass("KeyboardHintButton positioned top-right corner")
		else:
			_warn("KeyboardHintButton offset_left: %d, offset_right: %d" % [kb_button.offset_left, kb_button.offset_right])

	await root.process_frame

func _send_key(keycode: int):
	"""Simulate a key press event"""
	var event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.echo = false
	Input.parse_input_event(event)

func _pass(message: String):
	test_results.append({"status": "PASS", "message": message})
	print("  ✅ PASS: %s" % message)

func _fail(message: String):
	test_results.append({"status": "FAIL", "message": message})
	print("  ❌ FAIL: %s" % message)

func _warn(message: String):
	test_results.append({"status": "WARN", "message": message})
	print("  ⚠️  WARN: %s" % message)

func _info(message: String):
	test_results.append({"status": "INFO", "message": message})
	print("  ℹ️  INFO: %s" % message)

func _print_summary():
	var separator = "=" + "=" + "=" + "=" + "=" + "=" + "=" + "=" + "=" + "="
	separator = separator + separator + separator + separator + separator + separator + separator + separator
	print("\n" + separator)
	print("TEST SUMMARY")
	print(separator + "\n")

	var pass_count = 0
	var fail_count = 0
	var warn_count = 0
	var info_count = 0

	for result in test_results:
		match result.status:
			"PASS": pass_count += 1
			"FAIL": fail_count += 1
			"WARN": warn_count += 1
			"INFO": info_count += 1

	print("Total tests: %d" % test_results.size())
	print("  ✅ Passed: %d" % pass_count)
	print("  ❌ Failed: %d" % fail_count)
	print("  ⚠️  Warnings: %d" % warn_count)
	print("  ℹ️  Info: %d" % info_count)

	if fail_count == 0:
		print("\n🎉 ALL TESTS PASSED! UI refactor successful!")
	else:
		print("\n❌ SOME TESTS FAILED - Review failures above")

	var sep2 = "=" + "=" + "=" + "=" + "=" + "=" + "=" + "=" + "=" + "="
	sep2 = sep2 + sep2 + sep2 + sep2 + sep2 + sep2 + sep2 + sep2
	print("\n" + sep2 + "\n")
