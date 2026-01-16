extends SceneTree
## Bubble touch test - tests TouchInputManager → QuantumForceGraph flow
## Run with: godot --headless --script res://Tests/test_bubble_touch.gd

var frame_count = 0
var scene_loaded = false
var ran = false

func _init():
	print("\n======================================================================")
	print("  BUBBLE TOUCH TEST")
	print("======================================================================\n")

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		print("Loading scene...")
		var scene = load("res://scenes/FarmView.tscn")
		var instance = scene.instantiate()
		root.add_child(instance)
		scene_loaded = true

		var boot_manager = root.get_node_or_null("/root/BootManager")
		boot_manager.game_ready.connect(func():
			if ran:
				return
			ran = true
			_run_tests()
		)

func _run_tests():
	print("Running tests...\n")

	# Find components
	var fv = root.get_node_or_null("FarmView")
	var farm = fv.farm if fv and "farm" in fv else null
	var qv = fv.quantum_viz if fv and "quantum_viz" in fv else null
	var fg = qv.graph if qv and "graph" in qv else null
	var tim = root.get_node_or_null("/root/TouchInputManager")

	if not farm or not fg or not tim:
		print("FAIL: Components missing (farm=%s, fg=%s, tim=%s)" % [farm != null, fg != null, tim != null])
		quit(1)
		return

	print("Components found OK")
	print("TouchInputManager: %s\n" % tim)

	# Find wheat-plantable plot
	var wheat_pos = Vector2i(-1, -1)
	for y in range(2):
		for x in range(6):
			var pos = Vector2i(x, y)
			var biome = farm.grid.get_biome_for_plot(pos)
			if biome:
				for cap in biome.get_plantable_capabilities():
					if cap.plant_type == "wheat":
						wheat_pos = pos
						break
				if wheat_pos != Vector2i(-1, -1):
					break
		if wheat_pos != Vector2i(-1, -1):
			break

	print("Wheat plot: %s" % wheat_pos)

	# Plant wheat
	var result = farm.build(wheat_pos, "wheat")
	print("Plant result: %s" % result)

	if not result:
		print("FAIL: Could not plant")
		quit(1)
		return

	# Manual bubble request
	var plot = farm.grid.get_plot(wheat_pos)
	if fg.quantum_nodes.size() == 0 and plot.is_planted:
		qv.request_plot_bubble("BioticFlux", wheat_pos, plot)

	print("Bubbles: %d" % fg.quantum_nodes.size())

	if fg.quantum_nodes.size() == 0:
		print("FAIL: No bubbles")
		quit(1)
		return

	var bubble = fg.quantum_nodes[0]
	var gt = fg.get_global_transform()
	var bubble_global = gt * bubble.position

	print("\nBubble at global: %s" % bubble_global)

	# Track click signal
	var click_result = {"received": false, "pos": Vector2i(-1, -1)}
	fg.node_clicked.connect(func(gp, bi):
		print("  NODE_CLICKED: %s" % gp)
		click_result.received = true
		click_result.pos = gp
	)

	# Track tap_detected signal
	var tap_result = {"received": false, "pos": Vector2.ZERO}
	tim.tap_detected.connect(func(pos):
		print("  TAP_DETECTED: %s" % pos)
		tap_result.received = true
		tap_result.pos = pos
	)

	print("\n--- TEST 1: Direct _on_bubble_tap() call ---")
	print("Calling fg._on_bubble_tap(%s)..." % bubble_global)
	fg._on_bubble_tap(bubble_global)
	print("Click result: received=%s, pos=%s" % [click_result.received, click_result.pos])

	if not click_result.received:
		print("FAIL: Direct _on_bubble_tap didn't trigger signal")

		# Debug
		print("\nDEBUG:")
		print("  is_current_tap_consumed: %s" % tim.is_current_tap_consumed())
		var local = gt.affine_inverse() * bubble_global
		print("  Computed local: %s" % local)
		var hit = fg.get_node_at_position(local)
		print("  Hit test: %s" % ("HIT" if hit else "MISS"))

		quit(1)
		return

	print("PASS: Direct call works\n")

	# Reset
	click_result.received = false
	click_result.pos = Vector2i(-1, -1)
	tap_result.received = false
	tap_result.pos = Vector2.ZERO

	print("--- TEST 2: tap_detected signal emission ---")
	print("Emitting tim.tap_detected(%s)..." % bubble_global)

	# Reset consumed flag
	tim.current_tap_consumed = false

	# Emit tap_detected signal
	tim.tap_detected.emit(bubble_global)

	print("tap_result: received=%s, pos=%s" % [tap_result.received, tap_result.pos])
	print("click_result: received=%s, pos=%s" % [click_result.received, click_result.pos])

	if not click_result.received:
		print("FAIL: tap_detected signal didn't result in node_clicked")

		# Check if PlotGridDisplay consumed it
		print("\nDEBUG:")
		print("  is_current_tap_consumed: %s" % tim.is_current_tap_consumed())

		quit(1)
		return

	print("PASS: Signal flow works\n")

	# Reset
	click_result.received = false
	tap_result.received = false

	print("--- TEST 3: Full touch simulation ---")
	print("Simulating touch at %s..." % bubble_global)

	# Reset consumed flag
	tim.current_tap_consumed = false

	# Simulate touch down
	var touch_down = InputEventScreenTouch.new()
	touch_down.pressed = true
	touch_down.position = bubble_global
	touch_down.index = 0

	# Simulate touch up (quick tap)
	var touch_up = InputEventScreenTouch.new()
	touch_up.pressed = false
	touch_up.position = bubble_global
	touch_up.index = 0

	print("Sending touch down...")
	tim._input(touch_down)

	# Wait a tiny bit (simulate quick tap)
	print("Sending touch up (quick tap)...")
	tim._input(touch_up)

	print("tap_result: received=%s" % tap_result.received)
	print("click_result: received=%s, pos=%s" % [click_result.received, click_result.pos])

	if click_result.received:
		print("\n======================================================================")
		print("  ALL TESTS PASSED")
		print("======================================================================")
		quit(0)
	else:
		print("\nFAIL: Full touch simulation didn't work")
		print("  tap_detected emitted: %s" % tap_result.received)
		print("  node_clicked received: %s" % click_result.received)
		quit(1)
