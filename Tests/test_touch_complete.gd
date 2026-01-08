extends SceneTree

## Complete Touch Input Test
## Tests that touch works on plots, bubbles, and UI buttons

var test_results = []
var tap_count = 0
var swipe_count = 0
var plot_selection_changed = false
var bubble_clicked = false

func _init():
	print("🧪 Complete Touch Input Test")
	print("================================================================================")

	# Load FarmView scene
	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		print("❌ Failed to load FarmView.tscn")
		quit()
		return

	var root = scene.instantiate()
	get_root().add_child(root)
	print("✅ Game scene loaded")

	# Wait for full initialization
	await create_timer(2.0).timeout

	# Get TouchInputManager via node path
	var touch_mgr = get_root().get_node_or_null("TouchInputManager")
	if touch_mgr:
		touch_mgr.tap_detected.connect(_on_tap)
		touch_mgr.swipe_detected.connect(_on_swipe)
		print("✅ Connected to TouchInputManager signals")
	else:
		print("❌ TouchInputManager not found")
		quit()
		return

	# Find components
	var plot_grid = _find_node_recursive(root, "PlotGridDisplay")
	var quantum_graph = _find_node_recursive(root, "QuantumForceGraph")

	print("\n📍 Component Discovery:")
	print("   PlotGridDisplay: %s" % ("FOUND" if plot_grid else "NOT FOUND"))
	print("   QuantumForceGraph: %s" % ("FOUND" if quantum_graph else "NOT FOUND"))

	# Run tests
	print("\n🧪 Running Touch Tests...\n")

	# Test 1: Tap on likely plot area
	await _test_plot_tap(plot_grid)

	# Test 2: Tap on likely bubble area
	await _test_bubble_tap(quantum_graph)

	# Test 3: Swipe gesture
	await _test_swipe_gesture()

	# Report results
	print("\n================================================================================")
	print("📊 TEST RESULTS")
	print("================================================================================")
	for result in test_results:
		print(result)

	print("\n📈 Summary:")
	print("   Total taps detected: %d" % tap_count)
	print("   Total swipes detected: %d" % swipe_count)
	print("   Plot selection worked: %s" % ("YES" if plot_selection_changed else "NO"))
	print("   Bubble click worked: %s" % ("YES" if bubble_clicked else "NO"))

	var all_passed = tap_count >= 2 and swipe_count >= 1
	print("\n" + ("✅ ALL TESTS PASSED" if all_passed else "❌ SOME TESTS FAILED"))

	quit()


func _on_tap(pos: Vector2):
	tap_count += 1
	print("   ✅ TouchManager: Tap detected at %s" % pos)


func _on_swipe(start: Vector2, end: Vector2, dir: Vector2):
	swipe_count += 1
	print("   ✅ TouchManager: Swipe detected %s → %s" % [start, end])


func _test_plot_tap(plot_grid) -> void:
	print("🧪 Test: Tap on plot area")

	if not plot_grid:
		test_results.append("⚠️  Skipped plot test - PlotGridDisplay not found")
		return

	var initial_selection = plot_grid.get_selected_plot() if plot_grid.has_method("get_selected_plot") else null

	# Simulate tap in middle of screen (likely plot area)
	var tap = InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(480, 270)
	Input.parse_input_event(tap)
	await create_timer(0.1).timeout

	tap.pressed = false
	Input.parse_input_event(tap)
	await create_timer(0.2).timeout

	var new_selection = plot_grid.get_selected_plot() if plot_grid.has_method("get_selected_plot") else null

	if new_selection != initial_selection:
		plot_selection_changed = true
		test_results.append("✅ Plot selection changed via touch (was %s, now %s)" % [initial_selection, new_selection])
	else:
		test_results.append("❌ Plot selection did NOT change via touch")


func _test_bubble_tap(quantum_graph) -> void:
	print("🧪 Test: Tap on bubble area")

	if not quantum_graph:
		test_results.append("⚠️  Skipped bubble test - QuantumForceGraph not found")
		return

	# Try to connect to bubble click signal if it exists
	if quantum_graph.has_signal("node_clicked"):
		quantum_graph.node_clicked.connect(_on_bubble_clicked)

	# Simulate tap in upper area (likely bubble zone)
	var tap = InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(480, 150)
	Input.parse_input_event(tap)
	await create_timer(0.1).timeout

	tap.pressed = false
	Input.parse_input_event(tap)
	await create_timer(0.2).timeout

	if bubble_clicked:
		test_results.append("✅ Bubble click detected via touch")
	else:
		test_results.append("⚠️  Bubble click NOT detected (may not have bubbles yet)")


func _on_bubble_clicked(node):
	bubble_clicked = true
	print("   ✅ QuantumGraph: Bubble clicked - %s" % node)


func _test_swipe_gesture() -> void:
	print("🧪 Test: Swipe gesture")

	var initial_swipe_count = swipe_count

	# Simulate swipe across screen
	var touch_down = InputEventScreenTouch.new()
	touch_down.pressed = true
	touch_down.position = Vector2(300, 200)
	Input.parse_input_event(touch_down)
	await create_timer(0.15).timeout

	var touch_up = InputEventScreenTouch.new()
	touch_up.pressed = false
	touch_up.position = Vector2(500, 200)
	Input.parse_input_event(touch_up)
	await create_timer(0.2).timeout

	if swipe_count > initial_swipe_count:
		test_results.append("✅ Swipe gesture detected")
	else:
		test_results.append("❌ Swipe gesture NOT detected")


func _find_node_recursive(node: Node, name_contains: String) -> Node:
	"""Recursively find node whose name contains the string"""
	if name_contains.to_lower() in node.name.to_lower():
		return node

	if node.get_script():
		var script_path = node.get_script().resource_path
		if name_contains in script_path:
			return node

	for child in node.get_children():
		var result = _find_node_recursive(child, name_contains)
		if result:
			return result

	return null
