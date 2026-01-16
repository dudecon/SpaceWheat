extends SceneTree
## Bubble click test v4 - find correct biome
## Run with: godot --headless --script res://Tests/test_bubble_click_v4.gd

var frame_count = 0
var scene_loaded = false
var ran = false

func _init():
	print("\n======================================================================")
	print("  BUBBLE CLICK TEST v4")
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

	if not farm or not fg:
		print("FAIL: Components missing")
		quit(1)
		return

	print("Components found OK\n")

	# Find a plot in BioticFlux biome that supports wheat
	print("Looking for wheat-plantable plot...")
	var wheat_pos = Vector2i(-1, -1)

	for y in range(2):
		for x in range(6):
			var pos = Vector2i(x, y)
			var biome = farm.grid.get_biome_for_plot(pos)
			if biome:
				for cap in biome.get_plantable_capabilities():
					if cap.plant_type == "wheat":
						wheat_pos = pos
						print("  Found wheat at (%d,%d) in %s" % [x, y, biome.get_biome_type()])
						break
				if wheat_pos != Vector2i(-1, -1):
					break
		if wheat_pos != Vector2i(-1, -1):
			break

	if wheat_pos == Vector2i(-1, -1):
		print("FAIL: No plot supports wheat planting")
		quit(1)
		return

	# Check plot is empty
	var plot = farm.grid.get_plot(wheat_pos)
	print("\nPlot at %s:" % wheat_pos)
	print("  is_planted: %s" % plot.is_planted)

	# Plant wheat
	print("\nPlanting wheat at %s..." % wheat_pos)
	var result = farm.build(wheat_pos, "wheat")
	print("Result: %s" % result)

	if not result:
		print("FAIL: Could not plant wheat")
		quit(1)
		return

	# Check bubbles
	print("\nBubbles: %d" % fg.quantum_nodes.size())

	if fg.quantum_nodes.size() == 0:
		print("\n(Waiting for bubble creation...)")
		# Try manual request
		plot = farm.grid.get_plot(wheat_pos)
		if plot.is_planted:
			var biome_name = plot.parent_biome.name if plot.parent_biome else "BioticFlux"
			qv.request_plot_bubble(biome_name, wheat_pos, plot)
			print("After manual request: %d bubbles" % fg.quantum_nodes.size())

	if fg.quantum_nodes.size() == 0:
		print("FAIL: No bubbles created")
		quit(1)
		return

	# Get the bubble
	var bubble = fg.quantum_nodes[0]
	print("\nBubble:")
	print("  grid_pos: %s" % bubble.grid_position)
	print("  position: %s" % bubble.position)
	print("  radius: %.1f" % bubble.radius)

	# Test hit detection
	print("\nHit Detection:")
	var hit1 = fg.get_node_at_position(bubble.position)
	print("  Exact position: %s" % ("PASS" if hit1 else "FAIL"))

	var hit2 = fg.get_node_at_position(bubble.position + Vector2(5, 5))
	print("  Offset +5,5: %s" % ("PASS" if hit2 else "FAIL"))

	if not hit1:
		print("\nFAIL: Hit detection failed")
		quit(1)
		return

	# Test coordinate transform
	print("\nCoordinate Transform:")
	var gt = fg.get_global_transform()
	print("  Origin: %s" % gt.origin)
	var bubble_global = gt * bubble.position
	print("  Bubble global: %s" % bubble_global)

	# Test click signal
	print("\nClick Signal Test:")
	var click_result = {"received": false, "pos": Vector2i(-1, -1)}  # Use dict for mutable capture

	# Check existing connections
	var conns = fg.node_clicked.get_connections()
	print("  Existing connections: %d" % conns.size())
	for c in conns:
		print("    -> %s.%s" % [c.callable.get_object(), c.callable.get_method()])

	# Add our test connection
	fg.node_clicked.connect(func(gp, bi):
		print("  TEST CALLBACK: gp=%s, bi=%d" % [gp, bi])
		click_result.received = true
		click_result.pos = gp
	)
	print("  Added test connection")

	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.device = -1
	press.global_position = bubble_global
	press.position = bubble_global

	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.device = -1
	release.global_position = bubble_global
	release.position = bubble_global

	print("  Sending click at %s..." % bubble_global)
	fg._unhandled_input(press)
	fg._unhandled_input(release)

	print("  Received: %s" % click_result.received)
	if click_result.received:
		print("  Position: %s" % click_result.pos)

	if click_result.received:
		print("\n======================================================================")
		print("  ALL TESTS PASSED")
		print("======================================================================")
		quit(0)
	else:
		# Debug
		print("\nDEBUG: Click failed")
		var local = gt.affine_inverse() * bubble_global
		print("  Computed local: %s" % local)
		var manual_hit = fg.get_node_at_position(local)
		print("  Manual hit: %s" % ("HIT" if manual_hit else "MISS"))

		print("\nFAIL: Click not detected")
		quit(1)
