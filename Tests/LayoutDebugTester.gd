class_name LayoutDebugTester
extends Control

## Comprehensive layout debugging and testing tool
## Shows actual vs expected positions and sizes

var ui_controller: Node
var test_results: Array = []

func _ready() -> void:
	print("\n" + "="*70)
	print("🔍 LAYOUT DEBUG TESTER STARTING")
	print("="*70)

	# Wait a frame for UI to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	_measure_layout()
	_test_keyboard_input()
	_print_test_results()

func _measure_layout() -> void:
	"""Measure actual positions and sizes of all UI elements"""
	print("\n📐 MEASURING ACTUAL LAYOUT...")

	# Find FarmUIController
	var farm_view = get_tree().root.get_child(0).find_child("FarmView", true, false)
	if not farm_view:
		print("❌ FarmView not found")
		return

	ui_controller = farm_view.find_child("FarmUIController", true, false)
	if not ui_controller:
		print("❌ FarmUIController not found")
		return

	print("✅ Found FarmUIController")

	# Measure key containers
	_measure_container("TopBar", ui_controller.get("top_bar"))
	_measure_container("PlotsRow", ui_controller.get("plots_row"))
	_measure_container("PlayArea", ui_controller.get("play_area"))
	_measure_container("ActionsRow", ui_controller.get("actions_row"))
	_measure_container("BottomBar", ui_controller.get("bottom_bar"))

	# Verify vertical layout
	_verify_vertical_layout()

func _measure_container(name: String, container: Node) -> void:
	"""Measure position and size of a container"""
	if not container:
		print("⚠️  %s: NOT FOUND" % name)
		return

	if not container is Control:
		print("⚠️  %s: NOT A CONTROL" % name)
		return

	var ctrl = container as Control
	var pos = ctrl.global_position
	var size = ctrl.size
	var anchors = "L:%.2f T:%.2f R:%.2f B:%.2f" % [
		ctrl.anchor_left, ctrl.anchor_top, ctrl.anchor_right, ctrl.anchor_bottom
	]

	print("📍 %s:" % name)
	print("   Position: (%.1f, %.1f)" % [pos.x, pos.y])
	print("   Size: %.1f × %.1f" % [size.x, size.y])
	print("   Anchors: %s" % anchors)
	print("   Size Flags: H=%d V=%d" % [ctrl.size_flags_horizontal, ctrl.size_flags_vertical])

	test_results.append({
		"name": name,
		"position": pos,
		"size": size,
		"anchors": anchors
	})

func _verify_vertical_layout() -> void:
	"""Check if vertical layout adds up correctly"""
	print("\n📊 VERTICAL LAYOUT VERIFICATION:")

	var viewport_height = get_viewport().get_visible_rect().size.y
	var total_measured = 0
	var top_y = 0

	# Expected order: TopBar → PlotsRow → PlayArea → ActionsRow → BottomBar
	for result in test_results:
		var expected_y = top_y
		var actual_y = result["position"].y
		var height = result["size"].y

		var match = "✓" if abs(actual_y - expected_y) < 1.0 else "✗"
		print("%s %s: Y=%.1f (expected %.1f), H=%.1f" % [match, result["name"], actual_y, expected_y, height])

		total_measured += height
		top_y += height

	print("\n   Total measured height: %.1f / %.1f (%.1f%%)" % [
		total_measured, viewport_height, (total_measured / viewport_height) * 100
	])

	if abs(total_measured - viewport_height) < 10.0:
		print("   ✅ Layout fits viewport correctly")
	else:
		print("   ❌ Layout does NOT fit viewport (difference: %.1f px)" % abs(total_measured - viewport_height))

func _test_keyboard_input() -> void:
	"""Test keyboard input routing"""
	print("\n⌨️  TESTING KEYBOARD INPUT...")

	# Try to find input handlers
	if ui_controller:
		var input_handler = ui_controller.get("input_handler")
		if input_handler:
			print("✅ FarmInputHandler found")
			if input_handler.has_signal("tool_changed"):
				print("   ✅ tool_changed signal exists")
			if input_handler.has_signal("selection_changed"):
				print("   ✅ selection_changed signal exists")
		else:
			print("❌ FarmInputHandler NOT found")

		var tool_row = ui_controller.get("tool_selection_row")
		if tool_row:
			print("✅ ToolSelectionRow found")
			if tool_row is Control:
				var ctrl = tool_row as Control
				print("   Can focus: %s" % ctrl.focus_mode != Control.FOCUS_NONE)
				print("   Mouse filter: %d" % ctrl.mouse_filter)
		else:
			print("❌ ToolSelectionRow NOT found")

func _print_test_results() -> void:
	"""Print comprehensive test summary"""
	print("\n" + "="*70)
	print("📋 TEST SUMMARY")
	print("="*70)
	print("Viewport: %s" % get_viewport().get_visible_rect().size)
	print("FarmUIController found: %s" % (ui_controller != null))
	print("\nUI Elements checked: %d" % test_results.size())
	for result in test_results:
		print("  - %s: %s" % [result["name"], "✓" if result["size"].y > 0 else "✗"])
	print("="*70 + "\n")

func _input(event: InputEvent) -> void:
	"""Log input events for debugging"""
	if event is InputEventKey and event.pressed:
		print("🎮 Key pressed: %s (keycode: %d)" % [OS.get_keycode_string(event.keycode), event.keycode])
		if event.keycode >= KEY_1 and event.keycode <= KEY_6:
			print("   → Tool selection key detected (should select tool %d)" % (event.keycode - KEY_0))
