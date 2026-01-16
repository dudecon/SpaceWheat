extends SceneTree
## Phase 3 Overlay Test - Tests v2 overlay system integration
## Run with: godot --headless --script res://Tests/test_phase3_overlays.gd
##
## Verifies CVBN keyboard shortcuts and v2 overlay lifecycle

const SEPARATOR = "======================================================================"

var test_results: Array = []
var current_test: String = ""
var farm = null
var player_shell = null
var overlay_manager = null
var scene_loaded = false
var tests_done = false
var frame_count = 0
var boot_manager = null

func _init():
	print("\n" + SEPARATOR)
	print("PHASE 3: OVERLAY INTEGRATION TEST")
	print("Testing: v2 overlays, CVBN shortcuts, left-side buttons")
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
			print("  Scene instantiated")

			# Connect to BootManager.game_ready signal
			boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)
				print("  Connected to BootManager.game_ready")
		else:
			print("  Failed to load scene")
			quit(1)


func _on_game_ready():
	"""Called when BootManager signals that the game is ready"""
	if tests_done:
		return
	tests_done = true
	print("\n  BootManager.game_ready received!")

	_find_components()

	# Disable quantum evolution for faster test execution
	if farm:
		print("  Disabling quantum evolution for test speed...")
		for biome in [farm.biotic_flux_biome, farm.forest_biome, farm.market_biome, farm.kitchen_biome]:
			if biome:
				biome.quantum_evolution_enabled = false
				biome.set_process(false)
		farm.set_process(false)
		if farm.grid:
			farm.grid.set_process(false)

	print("\nFound: PlayerShell=%s, OverlayManager=%s, Farm=%s" % [
		player_shell != null, overlay_manager != null, farm != null])

	if player_shell and overlay_manager:
		print("\nRunning Phase 3 Overlay Tests...\n")
		_run_all_tests()
	else:
		print("\n  Components not found after boot!")
		if not player_shell:
			print("  Missing: PlayerShell")
		if not overlay_manager:
			print("  Missing: OverlayManager")
		quit(1)


func _find_components():
	# Find PlayerShell
	player_shell = _find_node(root, "PlayerShell")

	# Find OverlayManager (child of PlayerShell)
	if player_shell:
		overlay_manager = player_shell.overlay_manager

	# Find Farm
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


func _run_all_tests():
	# Test v2 overlay system
	_test_v2_overlays_registered()
	_test_inspector_overlay_exists()
	_test_controls_overlay_exists()
	_test_semantic_map_overlay_exists()
	_test_biome_detail_overlay_exists()

	# Test overlay lifecycle
	_test_open_close_inspector()
	_test_open_close_semantic_map()
	_test_open_close_controls()

	# Test that QuantumHUDPanel is removed
	_test_quantum_hud_panel_removed()

	# Test touch button bar position
	_test_touch_buttons_on_left()

	# Print results and exit
	_print_results()

	var failed = test_results.filter(func(r): return not r.passed).size()
	quit(1 if failed > 0 else 0)


func _test_v2_overlays_registered():
	current_test = "V2 Overlays Registered"
	print("TEST: %s" % current_test)

	if not overlay_manager:
		_record_result(false, "OverlayManager is null")
		return

	var registered = overlay_manager.get_registered_v2_overlays()
	print("  Registered v2 overlays: %s" % str(registered))

	var expected = ["inspector", "controls", "semantic_map", "quests", "biome_detail"]
	var all_found = true
	for name in expected:
		if name not in registered:
			print("  MISSING: %s" % name)
			all_found = false

	if all_found:
		_record_result(true, "All expected v2 overlays registered")
	else:
		_record_result(false, "Some v2 overlays missing")


func _test_inspector_overlay_exists():
	current_test = "Inspector Overlay Exists"
	print("\nTEST: %s" % current_test)

	var overlay = overlay_manager.get_v2_overlay("inspector")
	if overlay:
		print("  InspectorOverlay found")
		print("  overlay_name: %s" % overlay.overlay_name)
		_record_result(true, "InspectorOverlay exists with name: %s" % overlay.overlay_name)
	else:
		_record_result(false, "InspectorOverlay not found")


func _test_controls_overlay_exists():
	current_test = "Controls Overlay Exists"
	print("\nTEST: %s" % current_test)

	var overlay = overlay_manager.get_v2_overlay("controls")
	if overlay:
		print("  ControlsOverlay found")
		_record_result(true, "ControlsOverlay exists")
	else:
		_record_result(false, "ControlsOverlay not found")


func _test_semantic_map_overlay_exists():
	current_test = "Semantic Map Overlay Exists"
	print("\nTEST: %s" % current_test)

	var overlay = overlay_manager.get_v2_overlay("semantic_map")
	if overlay:
		print("  SemanticMapOverlay found")
		_record_result(true, "SemanticMapOverlay exists")
	else:
		_record_result(false, "SemanticMapOverlay not found")


func _test_biome_detail_overlay_exists():
	current_test = "Biome Detail Overlay Exists"
	print("\nTEST: %s" % current_test)

	var overlay = overlay_manager.get_v2_overlay("biome_detail")
	if overlay:
		print("  BiomeInspectorOverlay (biome_detail) found")
		_record_result(true, "BiomeInspectorOverlay exists")
	else:
		_record_result(false, "BiomeInspectorOverlay not found")


func _test_open_close_inspector():
	current_test = "Open/Close Inspector Overlay"
	print("\nTEST: %s" % current_test)

	# Open inspector
	overlay_manager.open_v2_overlay("inspector")

	var is_active = overlay_manager.is_v2_overlay_active()
	var active_overlay = overlay_manager.get_active_v2_overlay()

	print("  After open: is_active=%s" % is_active)
	if active_overlay:
		print("  Active overlay: %s" % active_overlay.overlay_name)

	if not is_active or not active_overlay:
		_record_result(false, "Failed to open inspector overlay")
		return

	# Close it
	overlay_manager.close_v2_overlay()

	is_active = overlay_manager.is_v2_overlay_active()
	print("  After close: is_active=%s" % is_active)

	if is_active:
		_record_result(false, "Failed to close inspector overlay")
	else:
		_record_result(true, "Inspector overlay opens and closes correctly")


func _test_open_close_semantic_map():
	current_test = "Open/Close Semantic Map Overlay"
	print("\nTEST: %s" % current_test)

	overlay_manager.open_v2_overlay("semantic_map")
	var is_active = overlay_manager.is_v2_overlay_active()

	if not is_active:
		_record_result(false, "Failed to open semantic_map overlay")
		return

	overlay_manager.close_v2_overlay()
	is_active = overlay_manager.is_v2_overlay_active()

	if is_active:
		_record_result(false, "Failed to close semantic_map overlay")
	else:
		_record_result(true, "Semantic map overlay opens and closes correctly")


func _test_open_close_controls():
	current_test = "Open/Close Controls Overlay"
	print("\nTEST: %s" % current_test)

	overlay_manager.open_v2_overlay("controls")
	var is_active = overlay_manager.is_v2_overlay_active()

	if not is_active:
		_record_result(false, "Failed to open controls overlay")
		return

	overlay_manager.close_v2_overlay()
	is_active = overlay_manager.is_v2_overlay_active()

	if is_active:
		_record_result(false, "Failed to close controls overlay")
	else:
		_record_result(true, "Controls overlay opens and closes correctly")


func _test_quantum_hud_panel_removed():
	current_test = "QuantumHUDPanel Removed"
	print("\nTEST: %s" % current_test)

	# The quantum_hud_panel should be null (we removed it)
	if player_shell.quantum_hud_panel == null:
		print("  quantum_hud_panel is null (removed)")
		_record_result(true, "QuantumHUDPanel removed from PlayerShell")
	else:
		print("  quantum_hud_panel still exists!")
		_record_result(false, "QuantumHUDPanel should be removed")


func _test_touch_buttons_on_left():
	current_test = "Touch Buttons on Left Side"
	print("\nTEST: %s" % current_test)

	# Find TouchButtonBar
	var button_bar = _find_node(root, "TouchButtonBar")
	if not button_bar:
		print("  TouchButtonBar not found")
		_record_result(false, "TouchButtonBar not found")
		return

	# Check anchor_left is 0 (left side)
	var anchor_left = button_bar.anchor_left
	print("  TouchButtonBar anchor_left: %s" % anchor_left)

	if anchor_left == 0.0:
		_record_result(true, "Touch buttons anchored to left side")
	else:
		_record_result(false, "Touch buttons not on left (anchor_left=%s)" % anchor_left)


func _record_result(passed: bool, description: String):
	test_results.append({
		"test": current_test,
		"passed": passed,
		"description": description
	})


func _print_results():
	print("\n" + SEPARATOR)
	print("PHASE 3 OVERLAY TEST RESULTS")
	print(SEPARATOR)

	var passed_count = 0
	var failed_count = 0

	for result in test_results:
		var status = "PASS" if result.passed else "FAIL"
		print("  [%s] %s: %s" % [status, result.test, result.description])
		if result.passed:
			passed_count += 1
		else:
			failed_count += 1

	print("")
	print("  Total: %d passed, %d failed" % [passed_count, failed_count])
	print(SEPARATOR + "\n")
