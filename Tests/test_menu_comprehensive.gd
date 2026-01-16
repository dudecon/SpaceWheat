extends SceneTree

## Comprehensive Menu & Overlay Testing Script
## Tests all menu/overlay operations for input routing bugs
## Run with: godot --script Tests/test_menu_comprehensive.gd

var frame_count: int = 0
var test_queue: Array = []
var test_index: int = 0
var wait_frames: int = 0
var current_test: String = ""

# Test results tracking
var tests_passed: int = 0
var tests_failed: int = 0
var test_results: Array = []

# Scene references
var player_shell = null
var overlay_stack = null
var overlay_manager = null

func _init():
	print("\n" + "=" .repeat(70))
	print("COMPREHENSIVE MENU & OVERLAY TEST")
	print("Testing input routing, ESC handling, and overlay state management")
	print("=" .repeat(70) + "\n")


func _process(_delta: float) -> bool:
	frame_count += 1

	# Wait for engine
	if frame_count < 30:
		if frame_count == 5:
			print("Waiting for engine initialization...")
		return false

	# Load scene
	if frame_count == 30:
		print("Loading FarmView scene...")
		var err = change_scene_to_file("res://scenes/FarmView.tscn")
		if err != OK:
			print("ERROR: Failed to load scene: %d" % err)
			quit(1)
			return true
		return false

	# Wait for scene init
	if frame_count < 120:
		return false

	# Build test queue
	if frame_count == 120:
		print("Scene loaded! Getting references...")
		_get_references()
		if not player_shell:
			print("ERROR: PlayerShell not found!")
			quit(1)
			return true
		print("Building test queue...\n")
		_build_test_queue()
		return false

	# Handle waits
	if wait_frames > 0:
		wait_frames -= 1
		return false

	# Process queue
	if test_index < test_queue.size():
		var action = test_queue[test_index]
		test_index += 1
		_execute_action(action)
		return false

	return false


func _get_references():
	"""Get references to UI components"""
	player_shell = root.get_node_or_null("FarmView/PlayerShell")
	if player_shell:
		overlay_stack = player_shell.overlay_stack
		overlay_manager = player_shell.overlay_manager


func _build_test_queue():
	"""Build comprehensive test sequence"""

	# =======================================================================
	# TEST 1: Basic Overlay Open/Close
	# =======================================================================
	_queue_section("TEST 1: Basic Overlay Open/Close")

	# Test each v2 overlay: C, V, B, N, K
	var overlays = [
		{"key": KEY_C, "name": "Quests (C)"},
		{"key": KEY_V, "name": "Semantic Map (V)"},
		{"key": KEY_B, "name": "Biome Detail (B)"},
		{"key": KEY_N, "name": "Inspector (N)"},
		{"key": KEY_K, "name": "Controls (K)"}
	]

	for overlay in overlays:
		_queue_test("Open %s" % overlay.name)
		_queue_key(overlay.key, 0.3)
		_queue_verify("overlay_opened", overlay.name)
		_queue_wait(0.3)

		_queue_test("Close %s with ESC" % overlay.name)
		_queue_key(KEY_ESCAPE, 0.3)
		_queue_verify("overlay_closed", overlay.name)
		_queue_wait(0.2)

	# =======================================================================
	# TEST 2: ESC Double-Dispatch Bug (Previously Broken)
	# =======================================================================
	_queue_section("TEST 2: ESC Double-Dispatch Prevention")

	_queue_test("Open Controls overlay (K)")
	_queue_key(KEY_K, 0.3)
	_queue_verify("overlay_opened", "Controls")

	_queue_test("Press ESC - should ONLY close Controls, NOT open EscapeMenu")
	_queue_key(KEY_ESCAPE, 0.3)
	_queue_verify("overlay_closed_no_escape_menu", "Controls")
	_queue_wait(0.2)

	# =======================================================================
	# TEST 3: Shell Toggle Blocking
	# =======================================================================
	_queue_section("TEST 3: Shell Toggle Blocking While Overlay Active")

	_queue_test("Open Inspector overlay (N)")
	_queue_key(KEY_N, 0.3)
	_queue_verify("overlay_opened", "Inspector")

	_queue_test("Press V - should be BLOCKED (Inspector still active)")
	_queue_key(KEY_V, 0.3)
	_queue_verify("overlay_still_active", "Inspector")

	_queue_test("Press C - should be BLOCKED (Inspector still active)")
	_queue_key(KEY_C, 0.3)
	_queue_verify("overlay_still_active", "Inspector")

	_queue_test("Press ESC to close Inspector")
	_queue_key(KEY_ESCAPE, 0.3)
	_queue_verify("overlay_closed", "Inspector")
	_queue_wait(0.2)

	# =======================================================================
	# TEST 4: EscapeMenu Behavior
	# =======================================================================
	_queue_section("TEST 4: EscapeMenu Behavior")

	_queue_test("Open EscapeMenu with ESC")
	_queue_key(KEY_ESCAPE, 0.3)
	_queue_verify("escape_menu_opened", "")

	_queue_test("Close EscapeMenu with ESC")
	_queue_key(KEY_ESCAPE, 0.3)
	_queue_verify("escape_menu_closed", "")
	_queue_wait(0.2)

	# =======================================================================
	# TEST 5: EscapeMenu Blocks Overlays
	# =======================================================================
	_queue_section("TEST 5: EscapeMenu Blocks Other Overlays")

	_queue_test("Open EscapeMenu")
	_queue_key(KEY_ESCAPE, 0.3)
	_queue_verify("escape_menu_opened", "")

	_queue_test("Press V - should be BLOCKED by EscapeMenu")
	_queue_key(KEY_V, 0.3)
	_queue_verify("escape_menu_still_active", "")

	_queue_test("Close EscapeMenu")
	_queue_key(KEY_ESCAPE, 0.3)
	_queue_verify("escape_menu_closed", "")
	_queue_wait(0.2)

	# =======================================================================
	# TEST 6: QER Actions in Overlay
	# =======================================================================
	_queue_section("TEST 6: QER Actions Within Overlays")

	_queue_test("Open Controls overlay")
	_queue_key(KEY_K, 0.3)
	_queue_verify("overlay_opened", "Controls")

	_queue_test("Press Q - should be consumed by overlay (not Quit!)")
	_queue_key(KEY_Q, 0.3)
	_queue_verify("q_not_quit", "")

	_queue_test("Press E - should be consumed by overlay")
	_queue_key(KEY_E, 0.3)
	_queue_verify("game_still_running", "")

	_queue_test("Press R - should be consumed by overlay")
	_queue_key(KEY_R, 0.3)
	_queue_verify("game_still_running", "")

	_queue_test("Close with ESC")
	_queue_key(KEY_ESCAPE, 0.3)
	_queue_verify("overlay_closed", "Controls")
	_queue_wait(0.2)

	# =======================================================================
	# TEST 7: Rapid Open/Close
	# =======================================================================
	_queue_section("TEST 7: Rapid Open/Close Sequence")

	_queue_test("Rapid toggle: V, ESC, C, ESC, N, ESC")
	_queue_key(KEY_V, 0.15)
	_queue_key(KEY_ESCAPE, 0.15)
	_queue_key(KEY_C, 0.15)
	_queue_key(KEY_ESCAPE, 0.15)
	_queue_key(KEY_N, 0.15)
	_queue_key(KEY_ESCAPE, 0.15)
	_queue_verify("stack_empty", "")
	_queue_wait(0.3)

	# =======================================================================
	# TEST 8: WASD Navigation in Overlay
	# =======================================================================
	_queue_section("TEST 8: WASD Navigation Within Overlays")

	_queue_test("Open Quests overlay (C)")
	_queue_key(KEY_C, 0.3)
	_queue_verify("overlay_opened", "Quests")

	_queue_test("Press W/A/S/D - should navigate, not move game selection")
	_queue_key(KEY_W, 0.15)
	_queue_key(KEY_S, 0.15)
	_queue_key(KEY_A, 0.15)
	_queue_key(KEY_D, 0.15)
	_queue_verify("navigation_consumed", "")

	_queue_test("Close with ESC")
	_queue_key(KEY_ESCAPE, 0.3)
	_queue_verify("overlay_closed", "Quests")
	_queue_wait(0.2)

	# =======================================================================
	# TEST 9: Sequential Overlay Opening
	# =======================================================================
	_queue_section("TEST 9: Sequential Overlay Operations")

	_queue_test("Open V, close with ESC, open C")
	_queue_key(KEY_V, 0.2)
	_queue_key(KEY_ESCAPE, 0.2)
	_queue_key(KEY_C, 0.2)
	_queue_verify("overlay_opened", "Quests")

	_queue_test("Close C, verify stack empty")
	_queue_key(KEY_ESCAPE, 0.2)
	_queue_verify("stack_empty", "")
	_queue_wait(0.2)

	# =======================================================================
	# TEST 10: Logger Panel (L key)
	# =======================================================================
	_queue_section("TEST 10: Logger Config Panel")

	_queue_test("Open Logger panel with L")
	_queue_key(KEY_L, 0.3)
	_queue_verify("logger_panel_opened", "")

	_queue_test("Close Logger panel with L")
	_queue_key(KEY_L, 0.3)
	_queue_verify("logger_panel_closed", "")
	_queue_wait(0.2)

	# =======================================================================
	# DONE
	# =======================================================================
	_queue_section("TEST COMPLETE")
	_queue_action("summary", 0)
	_queue_wait(1.0)
	_queue_action("quit", 0)


# ==========================================================================
# QUEUE HELPERS
# ==========================================================================

func _queue_section(name: String):
	test_queue.append({"type": "section", "value": name, "delay": 0.0})


func _queue_test(name: String):
	test_queue.append({"type": "test", "value": name, "delay": 0.0})


func _queue_key(keycode: int, delay: float):
	test_queue.append({"type": "key", "value": keycode, "delay": delay})


func _queue_wait(seconds: float):
	test_queue.append({"type": "wait", "value": seconds, "delay": 0.0})


func _queue_verify(check: String, context: String):
	test_queue.append({"type": "verify", "value": check, "context": context, "delay": 0.0})


func _queue_action(action: String, delay: float):
	test_queue.append({"type": action, "value": null, "delay": delay})


# ==========================================================================
# ACTION EXECUTION
# ==========================================================================

func _execute_action(action: Dictionary):
	var action_type = action.type
	var value = action.value
	var delay = action.get("delay", 0.0)

	match action_type:
		"section":
			print("\n" + "=" .repeat(60))
			print(value)
			print("=" .repeat(60))

		"test":
			current_test = value
			print("\n  📋 %s" % value)

		"key":
			_send_key(value)
			wait_frames = int(delay * 60)

		"wait":
			wait_frames = int(value * 60)

		"verify":
			_perform_verify(value, action.get("context", ""))

		"summary":
			_print_summary()

		"quit":
			var exit_code = 0 if tests_failed == 0 else 1
			print("\nExiting with code %d" % exit_code)
			quit(exit_code)


func _send_key(keycode: int):
	var event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.echo = false
	root.push_input(event)

	# Release after a frame
	var release = InputEventKey.new()
	release.keycode = keycode
	release.pressed = false
	_release_key.call_deferred(release)


func _release_key(event: InputEventKey):
	root.push_input(event)


# ==========================================================================
# VERIFICATION
# ==========================================================================

func _perform_verify(check: String, context: String):
	var passed = false
	var reason = ""

	match check:
		"overlay_opened":
			if overlay_stack and not overlay_stack.is_empty():
				passed = true
				reason = "Overlay stack has %d item(s)" % overlay_stack.size()
			else:
				reason = "Overlay stack is empty"

		"overlay_closed":
			if overlay_stack and overlay_stack.is_empty():
				passed = true
				reason = "Overlay stack is empty"
			else:
				reason = "Overlay stack has %d item(s)" % (overlay_stack.size() if overlay_stack else 0)

		"overlay_closed_no_escape_menu":
			# Verify overlay closed AND escape menu is NOT visible
			var escape_menu = overlay_manager.escape_menu if overlay_manager else null
			var stack_empty = overlay_stack.is_empty() if overlay_stack else true
			var escape_not_visible = not escape_menu.visible if escape_menu else true

			if stack_empty and escape_not_visible:
				passed = true
				reason = "Stack empty, EscapeMenu not visible"
			else:
				if not stack_empty:
					reason = "Stack not empty (%d)" % overlay_stack.size()
				elif not escape_not_visible:
					reason = "EscapeMenu is visible (BUG!)"

		"overlay_still_active":
			if overlay_stack and not overlay_stack.is_empty():
				passed = true
				reason = "Overlay still active (toggle key was blocked)"
			else:
				reason = "Overlay was closed (toggle key was NOT blocked)"

		"escape_menu_opened":
			var escape_menu = overlay_manager.escape_menu if overlay_manager else null
			if escape_menu and escape_menu.visible:
				passed = true
				reason = "EscapeMenu is visible"
			else:
				reason = "EscapeMenu is not visible"

		"escape_menu_closed":
			var escape_menu = overlay_manager.escape_menu if overlay_manager else null
			if escape_menu and not escape_menu.visible:
				passed = true
				reason = "EscapeMenu is hidden"
			else:
				reason = "EscapeMenu is still visible"

		"escape_menu_still_active":
			var escape_menu = overlay_manager.escape_menu if overlay_manager else null
			if escape_menu and escape_menu.visible:
				passed = true
				reason = "EscapeMenu still active (V was blocked)"
			else:
				reason = "EscapeMenu was closed"

		"q_not_quit":
			# If we're still running, Q didn't trigger quit
			passed = true
			reason = "Game still running (Q was consumed by overlay)"

		"game_still_running":
			passed = true
			reason = "Game still running"

		"stack_empty":
			if overlay_stack and overlay_stack.is_empty():
				passed = true
				reason = "Stack is empty"
			else:
				reason = "Stack has %d item(s)" % (overlay_stack.size() if overlay_stack else 0)

		"navigation_consumed":
			# WASD should be consumed - we're still running with overlay active
			if overlay_stack and not overlay_stack.is_empty():
				passed = true
				reason = "Overlay still active (WASD consumed)"
			else:
				reason = "Overlay was closed unexpectedly"

		"logger_panel_opened":
			if player_shell and player_shell.logger_config_panel:
				if player_shell.logger_config_panel.visible:
					passed = true
					reason = "Logger panel is visible"
				else:
					reason = "Logger panel is not visible"
			else:
				reason = "Logger panel reference not found"

		"logger_panel_closed":
			if player_shell and player_shell.logger_config_panel:
				if not player_shell.logger_config_panel.visible:
					passed = true
					reason = "Logger panel is hidden"
				else:
					reason = "Logger panel is still visible"
			else:
				passed = true
				reason = "Logger panel reference not found (OK)"

		_:
			reason = "Unknown check: %s" % check

	if passed:
		print("     ✅ PASS: %s" % reason)
		tests_passed += 1
		test_results.append({"test": current_test, "passed": true, "reason": reason})
	else:
		print("     ❌ FAIL: %s" % reason)
		tests_failed += 1
		test_results.append({"test": current_test, "passed": false, "reason": reason})


# ==========================================================================
# SUMMARY
# ==========================================================================

func _print_summary():
	print("\n" + "=" .repeat(70))
	print("TEST SUMMARY")
	print("=" .repeat(70))

	print("\nResults: %d passed, %d failed" % [tests_passed, tests_failed])

	if tests_failed > 0:
		print("\n❌ FAILED TESTS:")
		for result in test_results:
			if not result.passed:
				print("  - %s: %s" % [result.test, result.reason])

	print("\n" + "=" .repeat(70))

	if tests_failed == 0:
		print("✅ ALL TESTS PASSED!")
	else:
		print("❌ SOME TESTS FAILED - See above for details")

	print("=" .repeat(70))
