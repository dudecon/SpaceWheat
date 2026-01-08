extends SceneTree

## Automated Touch Input Test
## Simulates touch events and verifies they work correctly

var test_results = []
var tap_detected_count = 0
var swipe_detected_count = 0
var plot_selected_count = 0

func _init():
	print("🧪 Starting Touch Input Automated Test")
	print("================================================================================")

	# Load the main game scene first (this triggers autoload initialization)
	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		print("❌ Failed to load FarmView.tscn")
		quit()
		return

	var root = scene.instantiate()
	if not root:
		print("❌ Failed to instantiate scene")
		quit()
		return

	# Add to tree so _ready() is called
	get_root().add_child(root)
	print("✅ Game scene loaded and added to tree")

	# Wait for autoloads and scene to initialize
	await create_timer(1.0).timeout

	# NOW try to access TouchInputManager (after autoloads have initialized)
	var touch_manager = get_root().get_node_or_null("TouchInputManager")
	if touch_manager:
		touch_manager.tap_detected.connect(_on_tap_detected)
		touch_manager.swipe_detected.connect(_on_swipe_detected)
		print("✅ Connected to TouchInputManager signals")
	else:
		print("❌ TouchInputManager not found!")
		quit()
		return

	# Find PlotGridDisplay to check plot selection
	var plot_grid = _find_node_by_type(root, "PlotGridDisplay")
	if plot_grid:
		print("✅ Found PlotGridDisplay")
	else:
		print("⚠️  PlotGridDisplay not found")

	# Run tests
	await _run_tests(root, plot_grid)

	# Report results
	print("")
	print("================================================================================")
	print("📊 TEST RESULTS")
	print("================================================================================")
	for result in test_results:
		print(result)
	print("")
	print("📈 Signal Counts:")
	print("   tap_detected: %d" % tap_detected_count)
	print("   swipe_detected: %d" % swipe_detected_count)
	print("   plot selections: %d" % plot_selected_count)

	quit()


func _on_tap_detected(position: Vector2):
	tap_detected_count += 1
	print("   ✅ tap_detected signal fired: %s" % position)


func _on_swipe_detected(start_pos: Vector2, end_pos: Vector2, direction: Vector2):
	swipe_detected_count += 1
	print("   ✅ swipe_detected signal fired: %s → %s" % [start_pos, end_pos])


func _run_tests(root: Node, plot_grid) -> void:
	print("")
	print("🧪 Running Touch Input Tests...")
	print("")

	# Test 1: Simulate tap in center of screen (likely on play area)
	await _test_tap(Vector2(480, 270), "Center of screen (play area)")

	# Test 2: Simulate tap on likely plot location
	await _test_tap(Vector2(400, 300), "Likely plot location")

	# Test 3: Simulate swipe gesture
	await _test_swipe(Vector2(300, 250), Vector2(400, 250), "Horizontal swipe")

	# Test 4: Check if PlotGridDisplay received tap
	if plot_grid:
		var initial_selection = plot_grid.get_selected_plot() if plot_grid.has_method("get_selected_plot") else null
		await _test_tap(Vector2(450, 300), "Plot selection test")
		await create_timer(0.1).timeout
		var new_selection = plot_grid.get_selected_plot() if plot_grid.has_method("get_selected_plot") else null
		if new_selection != initial_selection:
			plot_selected_count += 1
			test_results.append("✅ Plot selection changed after tap")
		else:
			test_results.append("❌ Plot selection did not change")


func _test_tap(position: Vector2, description: String) -> void:
	print("🧪 Test: Tap at %s (%s)" % [position, description])

	var initial_tap_count = tap_detected_count

	# Create touch down event
	var touch_down = InputEventScreenTouch.new()
	touch_down.pressed = true
	touch_down.position = position
	touch_down.index = 0

	# Create touch up event
	var touch_up = InputEventScreenTouch.new()
	touch_up.pressed = false
	touch_up.position = position
	touch_up.index = 0

	# Inject events
	Input.parse_input_event(touch_down)
	await create_timer(0.1).timeout  # Short delay
	Input.parse_input_event(touch_up)
	await create_timer(0.1).timeout  # Wait for processing

	# Check if tap was detected
	if tap_detected_count > initial_tap_count:
		test_results.append("✅ Tap detected at %s" % position)
	else:
		test_results.append("❌ Tap NOT detected at %s" % position)


func _test_swipe(start_pos: Vector2, end_pos: Vector2, description: String) -> void:
	print("🧪 Test: Swipe %s → %s (%s)" % [start_pos, end_pos, description])

	var initial_swipe_count = swipe_detected_count

	# Create touch down event
	var touch_down = InputEventScreenTouch.new()
	touch_down.pressed = true
	touch_down.position = start_pos
	touch_down.index = 0

	# Create touch up event at different location
	var touch_up = InputEventScreenTouch.new()
	touch_up.pressed = false
	touch_up.position = end_pos
	touch_up.index = 0

	# Inject events
	Input.parse_input_event(touch_down)
	await create_timer(0.15).timeout  # Longer delay for swipe
	Input.parse_input_event(touch_up)
	await create_timer(0.1).timeout  # Wait for processing

	# Check if swipe was detected
	if swipe_detected_count > initial_swipe_count:
		test_results.append("✅ Swipe detected: %s → %s" % [start_pos, end_pos])
	else:
		test_results.append("❌ Swipe NOT detected: %s → %s" % [start_pos, end_pos])


func _find_node_by_type(node: Node, type_name: String) -> Node:
	"""Recursively find a node by its script/class name"""
	if node.get_script():
		var script_path = node.get_script().resource_path
		if type_name in script_path:
			return node

	for child in node.get_children():
		var result = _find_node_by_type(child, type_name)
		if result:
			return result

	return null
