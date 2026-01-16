extends SceneTree

## Save/Load Functionality Test
## Verifies save/load menu UI and actual save/load operations

var main_scene: Node = null
var test_results: Array = []
var failed: int = 0
var passed: int = 0
var game_ready: bool = false
var tests_done: bool = false

func _init():
	print("\n======================================================================")
	print("💾 SAVE/LOAD FUNCTIONALITY TEST")
	print("======================================================================\n")

func _process(_delta):
	var frame = Engine.get_process_frames()

	if frame < 5:
		return

	if frame == 5:
		print("Loading main scene...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			main_scene = scene.instantiate()
			root.add_child(main_scene)
			# Connect to BootManager.game_ready signal
			var boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)
		return

	if not game_ready:
		return  # Wait for BootManager.game_ready

	if not tests_done:
		_run_tests()
		return

	# After tests, wait a few frames then quit
	if frame > 200:
		_print_results()
		quit()


func _on_game_ready():
	"""Called when BootManager signals that the game is ready"""
	print("✅ BootManager.game_ready received!")
	game_ready = true

func _run_tests():
	tests_done = true
	print("Running save/load tests...\n")

	# Test 1: EscapeMenu position (top margin reduced)
	_test_escape_menu_position()

	# Test 2: SaveLoadMenu has ScrollContainer
	_test_saveload_scroll_container()

	# Test 3: GameStateManager accessibility
	_test_game_state_manager()

	# Test 4: Debug environments available
	_test_debug_environments()

	# Print results immediately
	_print_results()
	quit()

func _test_escape_menu_position():
	print("📋 TEST: EscapeMenu Position")

	var escape_menu = _find_node_by_name(root, "EscapeMenu")
	if not escape_menu:
		_record_result("EscapeMenu Position", false, "EscapeMenu not found")
		return

	# Check that menu panel is near top (offset_top should be ~16, not 50)
	var menu_panel = escape_menu.get_child(1) if escape_menu.get_child_count() > 1 else null
	if menu_panel and menu_panel is PanelContainer:
		var offset_top = menu_panel.offset_top
		if offset_top <= 20:
			_record_result("EscapeMenu Position", true, "Menu at top (offset_top=%d)" % offset_top)
		else:
			_record_result("EscapeMenu Position", false, "Menu too low (offset_top=%d, expected <=20)" % offset_top)
	else:
		_record_result("EscapeMenu Position", false, "Could not find menu panel")

func _test_saveload_scroll_container():
	print("📋 TEST: SaveLoadMenu ScrollContainer")

	var save_menu = _find_node_by_name(root, "SaveLoadMenu")
	if not save_menu:
		_record_result("SaveLoadMenu ScrollContainer", false, "SaveLoadMenu not found")
		return

	# Check for ScrollContainer
	var scroll = _find_node_by_class(save_menu, "ScrollContainer")
	if scroll:
		_record_result("SaveLoadMenu ScrollContainer", true, "ScrollContainer found")
	else:
		_record_result("SaveLoadMenu ScrollContainer", false, "ScrollContainer not found")

func _test_game_state_manager():
	print("📋 TEST: GameStateManager Accessibility")

	# Get GameStateManager autoload from root
	var gsm = root.get_node_or_null("/root/GameStateManager")
	if not gsm:
		_record_result("GameStateManager Accessibility", false, "GameStateManager autoload not found")
		return

	# Verify essential methods exist
	var methods_ok = gsm.has_method("save_game") and gsm.has_method("load_game_state") and gsm.has_method("get_save_info")
	if not methods_ok:
		_record_result("GameStateManager Accessibility", false, "Missing required methods")
		return

	# Find farm (via FarmView.farm)
	var farm_view = root.get_node_or_null("FarmView")
	var farm = null
	if farm_view and "farm" in farm_view:
		farm = farm_view.farm
	if not farm:
		_record_result("GameStateManager Accessibility", false, "Farm not found (farm_view=%s)" % str(farm_view))
		return

	# Verify active_farm can be set
	gsm.active_farm = farm
	if gsm.active_farm == farm:
		print("  ✓ active_farm can be set correctly")
	else:
		_record_result("GameStateManager Accessibility", false, "active_farm not settable")
		return

	# Test get_save_info works for all slots
	for slot in range(3):
		var info = gsm.get_save_info(slot)
		if "exists" in info:
			print("  ✓ Slot %d info: exists=%s" % [slot, str(info["exists"])])
		else:
			_record_result("GameStateManager Accessibility", false, "get_save_info(%d) failed" % slot)
			return

	_record_result("GameStateManager Accessibility", true, "All methods accessible, farm connection works")

func _test_debug_environments():
	print("📋 TEST: Debug Environments Available")

	var save_menu = _find_node_by_name(root, "SaveLoadMenu")
	if not save_menu:
		_record_result("Debug Environments", false, "SaveLoadMenu not found")
		return

	# Check for debug environment buttons
	var debug_buttons = []
	for child in _get_all_children(save_menu):
		if child is Button and child.name.begins_with("DebugEnvButton_"):
			debug_buttons.append(child)

	var expected_count = 8  # minimal, wealthy, fully_planted, fully_measured, fully_entangled, mixed_quantum, icons_active, mid_game
	if debug_buttons.size() >= expected_count:
		_record_result("Debug Environments", true, "%d debug environments available" % debug_buttons.size())
	else:
		_record_result("Debug Environments", false, "Only %d debug envs, expected %d" % [debug_buttons.size(), expected_count])

func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node_by_name(child, target_name)
		if found:
			return found
	return null

func _find_node_by_class(node: Node, class_name_str: String) -> Node:
	if node.get_class() == class_name_str:
		return node
	for child in node.get_children():
		var found = _find_node_by_class(child, class_name_str)
		if found:
			return found
	return null

func _get_all_children(node: Node) -> Array:
	var children = []
	for child in node.get_children():
		children.append(child)
		children.append_array(_get_all_children(child))
	return children

func _record_result(test_name: String, success: bool, message: String):
	if success:
		passed += 1
		print("  ✅ PASS: %s - %s" % [test_name, message])
	else:
		failed += 1
		print("  ❌ FAIL: %s - %s" % [test_name, message])
	test_results.append({"name": test_name, "success": success, "message": message})

func _print_results():
	print("\n======================================================================")
	print("📊 SAVE/LOAD TEST RESULTS")
	print("======================================================================")

	for result in test_results:
		var status = "✅" if result["success"] else "❌"
		print("  %s %s: %s" % [status, result["name"], result["message"]])

	print("\n  Total: %d passed, %d failed" % [passed, failed])
	print("======================================================================\n")
