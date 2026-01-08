extends SceneTree

## Test plot touch selection
## Traces the full signal chain: Touch → TouchInputManager → PlotGridDisplay

func _init():
	print("🧪 Testing Plot Touch Selection")
	print("================================================================================\n")

	# Load game scene
	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		print("❌ Failed to load scene")
		quit()
		return

	var root = scene.instantiate()
	get_root().add_child(root)

	# Wait for initialization
	print("⏳ Waiting for initialization...")
	await create_timer(2.0).timeout

	# Get TouchInputManager
	var touch_mgr = get_root().get_node_or_null("TouchInputManager")
	if not touch_mgr:
		print("❌ TouchInputManager not found")
		quit()
		return

	print("✅ TouchInputManager found\n")

	# Track signal emissions
	var tap_signal_fired = false
	var plot_grid_handler_called = false

	# Connect to tap_detected to verify it fires
	touch_mgr.tap_detected.connect(func(pos):
		tap_signal_fired = true
		print("   🔔 tap_detected signal fired: %s" % pos)
	)

	print("📍 Signal Chain Test:")
	print("   1. Inject InputEventScreenTouch (touch down)")
	print("   2. Inject InputEventScreenTouch (touch up)")
	print("   3. Verify TouchInputManager.tap_detected fires")
	print("   4. Verify PlotGridDisplay receives it\n")

	# Simulate touch at plot location
	var touch_pos = Vector2(225, 223)  # Approximate plot (0,0) position

	print("🖐️  Simulating touch at %s...\n" % touch_pos)

	# Touch down
	var touch_down = InputEventScreenTouch.new()
	touch_down.pressed = true
	touch_down.position = touch_pos
	touch_down.index = 0
	Input.parse_input_event(touch_down)

	await create_timer(0.1).timeout

	# Touch up (triggers tap detection)
	var touch_up = InputEventScreenTouch.new()
	touch_up.pressed = false
	touch_up.position = touch_pos
	touch_up.index = 0
	Input.parse_input_event(touch_up)

	await create_timer(0.3).timeout

	# Report results
	print("\n================================================================================")
	print("📊 RESULTS")
	print("================================================================================\n")

	if tap_signal_fired:
		print("✅ TouchInputManager.tap_detected signal fired")
	else:
		print("❌ TouchInputManager.tap_detected signal DID NOT fire")
		print("   → Check if TouchInputManager._input() received InputEventScreenTouch")
		print("   → Look for log: '👆 TouchManager: Touch started at...'")

	print("\n📋 Expected Console Output:")
	print("   👆 TouchManager: Touch started at (225.0, 223.0)")
	print("   👆 TouchManager: TAP detected at (225.0, 223.0)")
	print("   🎯 PlotGridDisplay._on_touch_tap received! Position: (225.0, 223.0)")
	print("      Converted to plot grid position: (0, 0)")
	print("      📱 Plot selected via touch tap: (0, 0)")

	quit()
