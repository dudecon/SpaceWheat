extends SceneTree

## Test OVERLAY mode QER+F actions
## Run with: godot --headless --script res://Tests/test_overlay_actions.gd
##
## Tests:
##   Quest Board (C key): action_q_on_selected, action_e_on_selected, action_r_on_selected, on_f_pressed
##   Inspector (N key): on_q_pressed, on_e_pressed, on_r_pressed, on_f_pressed
##   Semantic Map (V key): on_q_pressed, on_e_pressed, on_r_pressed, on_f_pressed
##   Controls (K key): on_q_pressed, on_e_pressed, on_r_pressed, on_f_pressed

var frame_count := 0
var test_results := []
var scene_loaded := false
var tests_started := false
var overlay_manager = null
var quest_board = null

func _init():
	print("")
	print("======================================================================")
	print("  OVERLAY MODE ACTIONS TEST - QER+F")
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
	print("\nGame ready! Finding overlay components...")

	# Find OverlayManager via PlayerShell's overlay_manager property
	var player_shell = _find_node(root, "PlayerShell")
	if player_shell:
		# Access the overlay_manager property directly (it's a public variable)
		if player_shell.get("overlay_manager"):
			overlay_manager = player_shell.overlay_manager

	# Find QuestBoard (either from OverlayManager or by node search)
	if overlay_manager and overlay_manager.get("quest_board"):
		quest_board = overlay_manager.quest_board
	else:
		quest_board = _find_node(root, "QuestBoard")

	print("OverlayManager: %s" % (overlay_manager != null))
	print("QuestBoard: %s" % (quest_board != null))

	if overlay_manager:
		var keys = overlay_manager.v2_overlays.keys() if overlay_manager.get("v2_overlays") else []
		print("v2 Overlays registered: %s" % [keys])

	# Run overlay tests
	print("\n" + "─".repeat(70))
	print("QUEST BOARD (C key)")
	print("─".repeat(70))
	_test_quest_board()

	print("\n" + "─".repeat(70))
	print("INSPECTOR OVERLAY (N key)")
	print("─".repeat(70))
	_test_inspector_overlay()

	print("\n" + "─".repeat(70))
	print("SEMANTIC MAP OVERLAY (V key)")
	print("─".repeat(70))
	_test_semantic_map_overlay()

	print("\n" + "─".repeat(70))
	print("CONTROLS OVERLAY (K key)")
	print("─".repeat(70))
	_test_controls_overlay()

	_finish()

# ============================================================================
# QUEST BOARD (C key)
# ============================================================================

func _test_quest_board():
	if not quest_board:
		_fail("QuestBoard not found")
		return

	# Check action_labels
	if quest_board.get("action_labels"):
		print("  Action labels: %s" % quest_board.action_labels)
		_pass("QUEST_BOARD: action_labels defined")
	else:
		_fail("QUEST_BOARD: action_labels missing")

	# Test Q: action_q_on_selected (Accept/Complete)
	print("\n[Q] Testing ACTION_Q (Accept/Complete)...")
	if quest_board.has_method("action_q_on_selected"):
		_pass("ACTION_Q: Method exists")
	else:
		_fail("ACTION_Q: Method not found")

	# Test E: action_e_on_selected (Reroll/Abandon)
	print("\n[E] Testing ACTION_E (Reroll/Abandon)...")
	if quest_board.has_method("action_e_on_selected"):
		_pass("ACTION_E: Method exists")
	else:
		_fail("ACTION_E: Method not found")

	# Test R: action_r_on_selected (Lock/Unlock)
	print("\n[R] Testing ACTION_R (Lock/Unlock)...")
	if quest_board.has_method("action_r_on_selected"):
		_pass("ACTION_R: Method exists")
	else:
		_fail("ACTION_R: Method not found")

	# Test F: on_f_pressed (Browse Factions)
	print("\n[F] Testing ON_F_PRESSED (Browse Factions)...")
	if quest_board.has_method("on_f_pressed"):
		_pass("ON_F_PRESSED: Method exists")
	else:
		_fail("ON_F_PRESSED: Method not found")

# ============================================================================
# INSPECTOR OVERLAY (N key)
# ============================================================================

func _test_inspector_overlay():
	var inspector = _get_v2_overlay("inspector")

	if not inspector:
		_fail("Inspector overlay not found")
		return

	# Check action_labels
	if inspector.get("action_labels"):
		print("  Action labels: %s" % inspector.action_labels)
		_pass("INSPECTOR: action_labels defined")
	else:
		_fail("INSPECTOR: action_labels missing")

	# Test QER+F methods
	_test_v2_overlay_methods(inspector, "INSPECTOR")

# ============================================================================
# SEMANTIC MAP OVERLAY (V key)
# ============================================================================

func _test_semantic_map_overlay():
	var semantic_map = _get_v2_overlay("semantic_map")

	if not semantic_map:
		_fail("SemanticMap overlay not found")
		return

	# Check action_labels
	if semantic_map.get("action_labels"):
		print("  Action labels: %s" % semantic_map.action_labels)
		_pass("SEMANTIC_MAP: action_labels defined")
	else:
		_fail("SEMANTIC_MAP: action_labels missing")

	# Test QER+F methods
	_test_v2_overlay_methods(semantic_map, "SEMANTIC_MAP")

# ============================================================================
# CONTROLS OVERLAY (K key)
# ============================================================================

func _test_controls_overlay():
	var controls = _get_v2_overlay("controls")

	if not controls:
		_fail("Controls overlay not found")
		return

	# Check action_labels
	if controls.get("action_labels"):
		print("  Action labels: %s" % controls.action_labels)
		_pass("CONTROLS: action_labels defined")
	else:
		_fail("CONTROLS: action_labels missing")

	# Test QER+F methods
	_test_v2_overlay_methods(controls, "CONTROLS")

# ============================================================================
# UTILITIES
# ============================================================================

func _get_v2_overlay(name: String):
	"""Get v2 overlay by name from OverlayManager"""
	if not overlay_manager:
		return null

	if overlay_manager.get("v2_overlays"):
		return overlay_manager.v2_overlays.get(name)

	return null

func _test_v2_overlay_methods(overlay, prefix: String):
	"""Test that a v2 overlay has QER+F methods"""

	# Test Q
	print("\n[Q] Testing ON_Q_PRESSED...")
	if overlay.has_method("on_q_pressed"):
		_pass("%s.ON_Q_PRESSED: Method exists" % prefix)
	else:
		_fail("%s.ON_Q_PRESSED: Method not found" % prefix)

	# Test E
	print("\n[E] Testing ON_E_PRESSED...")
	if overlay.has_method("on_e_pressed"):
		_pass("%s.ON_E_PRESSED: Method exists" % prefix)
	else:
		_fail("%s.ON_E_PRESSED: Method not found" % prefix)

	# Test R
	print("\n[R] Testing ON_R_PRESSED...")
	if overlay.has_method("on_r_pressed"):
		_pass("%s.ON_R_PRESSED: Method exists" % prefix)
	else:
		_fail("%s.ON_R_PRESSED: Method not found" % prefix)

	# Test F
	print("\n[F] Testing ON_F_PRESSED...")
	if overlay.has_method("on_f_pressed"):
		_pass("%s.ON_F_PRESSED: Method exists" % prefix)
	else:
		_fail("%s.ON_F_PRESSED: Method not found" % prefix)

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
		print("  ALL OVERLAY ACTIONS WORKING!")
	else:
		print("  SOME OVERLAYS NEED FIXES")
		print("")
		print("  Failed tests:")
		for result in test_results:
			if not result.passed:
				print("    - %s" % result.message)

	print("")
	print("======================================================================")

	quit(0 if failed == 0 else 1)
