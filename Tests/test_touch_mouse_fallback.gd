extends SceneTree

## Test TouchInputManager fallback to handle touch-generated mouse events
## Some platforms generate InputEventMouseButton instead of InputEventScreenTouch
## This test verifies TouchInputManager handles both correctly

var tap_count = 0
var swipe_count = 0

func _init():
	print("\n======================================================================")
	print("🧪 Testing TouchInputManager Mouse Event Fallback")
	print("======================================================================")
	print("\nProblem: Some platforms generate InputEventMouseButton (device=0)")
	print("         instead of InputEventScreenTouch for touch input")
	print("\nSolution: TouchInputManager now handles BOTH event types")
	print("======================================================================")

	# Wait for autoloads to initialize
	await create_timer(0.1).timeout

	# Connect to TouchInputManager signals
	if Engine.has_singleton("TouchInputManager"):
		var touch_mgr = Engine.get_singleton("TouchInputManager")
		touch_mgr.tap_detected.connect(_on_tap)
		touch_mgr.swipe_detected.connect(_on_swipe)
		print("✅ Connected to TouchInputManager")
	else:
		# Autoload might be in scene tree instead
		var autoloads = get_root().get_children()
		for node in autoloads:
			if node.name == "TouchInputManager":
				node.tap_detected.connect(_on_tap)
				node.swipe_detected.connect(_on_swipe)
				print("✅ Connected to TouchInputManager (via scene tree)")
				break

	# Test 1: Touch-generated mouse tap (device=0)
	print("\n--- Test 1: Touch-generated mouse tap ---")
	await _test_mouse_tap(Vector2(300, 200))

	# Test 2: Touch-generated mouse swipe (device=0)
	print("\n--- Test 2: Touch-generated mouse swipe ---")
	await _test_mouse_swipe(Vector2(200, 200), Vector2(400, 200))

	# Test 3: Real mouse click (device=-1) should still work normally
	print("\n--- Test 3: Real mouse click (should be ignored by TouchInputManager) ---")
	await _test_real_mouse_click(Vector2(300, 300))

	# Results
	print("\n======================================================================")
	print("📊 TEST RESULTS")
	print("======================================================================")
	print("Touch-generated mouse taps detected: %d (expected 1)" % tap_count)
	print("Touch-generated mouse swipes detected: %d (expected 1)" % swipe_count)

	if tap_count == 1 and swipe_count == 1:
		print("\n✅ SUCCESS: TouchInputManager correctly handles touch-generated mouse events!")
	else:
		print("\n❌ FAILURE: TouchInputManager did not detect gestures")

	print("======================================================================")

	quit()


func _test_mouse_tap(position: Vector2) -> void:
	"""Simulate touch-generated mouse tap (device=0)"""
	print("Injecting: Touch-generated mouse click at %s (device=0)" % position)

	# Mouse down (touch-generated)
	var down = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = position
	down.device = 0  # ← Touch-generated!

	Input.parse_input_event(down)
	await create_timer(0.05).timeout

	# Mouse up (touch-generated)
	var up = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = position
	up.device = 0  # ← Touch-generated!

	Input.parse_input_event(up)
	await create_timer(0.1).timeout


func _test_mouse_swipe(start_pos: Vector2, end_pos: Vector2) -> void:
	"""Simulate touch-generated mouse swipe (device=0)"""
	print("Injecting: Touch-generated mouse swipe %s → %s (device=0)" % [start_pos, end_pos])

	# Mouse down (touch-generated)
	var down = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = start_pos
	down.device = 0  # ← Touch-generated!

	Input.parse_input_event(down)
	await create_timer(0.05).timeout

	# Mouse motion (simulate drag)
	var motion = InputEventMouseMotion.new()
	motion.position = end_pos
	motion.device = 0
	Input.parse_input_event(motion)
	await create_timer(0.05).timeout

	# Mouse up (touch-generated)
	var up = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = end_pos
	up.device = 0  # ← Touch-generated!

	Input.parse_input_event(up)
	await create_timer(0.1).timeout


func _test_real_mouse_click(position: Vector2) -> void:
	"""Simulate real mouse click (device=-1) - should be ignored by TouchInputManager"""
	print("Injecting: REAL mouse click at %s (device=-1)" % position)

	# Real mouse down
	var down = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = position
	down.device = -1  # ← Real mouse!

	Input.parse_input_event(down)
	await create_timer(0.05).timeout

	# Real mouse up
	var up = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = position
	up.device = -1  # ← Real mouse!

	Input.parse_input_event(up)
	await create_timer(0.1).timeout


func _on_tap(position: Vector2) -> void:
	print("✅ tap_detected signal received at %s" % position)
	tap_count += 1


func _on_swipe(start_pos: Vector2, end_pos: Vector2, direction: Vector2) -> void:
	print("✅ swipe_detected signal received: %s → %s" % [start_pos, end_pos])
	swipe_count += 1
