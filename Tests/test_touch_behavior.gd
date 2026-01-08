extends SceneTree

## Touch Behavior Test
## Tests what happens on 1st, 2nd, 3rd touch of plots and bubbles

var test_log = []

func _init():
	print("🧪 Touch Behavior Test - What do touches DO?")
	print("================================================================================\n")

	# Load game scene
	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		print("❌ Failed to load scene")
		quit()
		return

	var root = scene.instantiate()
	get_root().add_child(root)

	# Wait for full initialization
	print("⏳ Waiting for game initialization...")
	await create_timer(2.5).timeout

	# Find components
	var plot_grid = _find_node_recursive(root, "PlotGridDisplay")
	var quantum_graph = _find_node_recursive(root, "QuantumForceGraph")
	var input_handler = _find_node_recursive(root, "FarmInputHandler")
	var farm = _find_node_recursive(root, "Farm")

	print("\n📍 Components Found:")
	print("   PlotGridDisplay: %s" % ("✅" if plot_grid else "❌"))
	print("   QuantumForceGraph: %s" % ("✅" if quantum_graph else "❌"))
	print("   FarmInputHandler: %s" % ("✅" if input_handler else "❌"))
	print("   Farm: %s" % ("✅" if farm else "❌"))

	if not plot_grid:
		print("\n❌ Cannot test without PlotGridDisplay")
		quit()
		return

	# Connect to TouchInputManager
	var touch_mgr = get_root().get_node_or_null("TouchInputManager")
	if not touch_mgr:
		print("❌ TouchInputManager not found")
		quit()
		return

	# Test sequence
	print("\n================================================================================")
	print("TESTING PLOT TOUCHES")
	print("================================================================================\n")

	await _test_plot_touches(plot_grid, touch_mgr, input_handler, farm)

	print("\n================================================================================")
	print("TESTING BUBBLE TOUCHES")
	print("================================================================================\n")

	await _test_bubble_touches(quantum_graph, touch_mgr)

	# Report
	print("\n================================================================================")
	print("📊 TOUCH BEHAVIOR SUMMARY")
	print("================================================================================")
	for line in test_log:
		print(line)

	quit()


func _test_plot_touches(plot_grid, touch_mgr, input_handler, farm) -> void:
	"""Test what happens when touching plots multiple times"""

	# Get initial state
	var initial_selection = plot_grid.get_selected_plot() if plot_grid.has_method("get_selected_plot") else null
	print("📍 Initial selection: %s\n" % initial_selection)

	# Touch 1: Select a plot
	print("🧪 TOUCH 1: Tap on plot area (should select plot)")
	var plot_pos_screen = _get_plot_screen_position(plot_grid, Vector2i(0, 0))
	await _simulate_tap(plot_pos_screen)
	await create_timer(0.2).timeout

	var selection_after_1 = plot_grid.get_selected_plot() if plot_grid.has_method("get_selected_plot") else null
	print("   Result: Selection = %s" % selection_after_1)
	if selection_after_1 != initial_selection:
		test_log.append("✅ Touch 1 on plot: Changed selection from %s to %s" % [initial_selection, selection_after_1])
	else:
		test_log.append("⚠️  Touch 1 on plot: Selection unchanged (%s)" % selection_after_1)

	# Touch 2: Tap same plot again
	print("\n🧪 TOUCH 2: Tap same plot again (should keep selection)")
	await _simulate_tap(plot_pos_screen)
	await create_timer(0.2).timeout

	var selection_after_2 = plot_grid.get_selected_plot() if plot_grid.has_method("get_selected_plot") else null
	print("   Result: Selection = %s" % selection_after_2)
	if selection_after_2 == selection_after_1:
		test_log.append("✅ Touch 2 on same plot: Selection unchanged (%s)" % selection_after_2)
	else:
		test_log.append("❌ Touch 2 on same plot: Selection changed unexpectedly to %s" % selection_after_2)

	# Touch 3: Tap different plot
	print("\n🧪 TOUCH 3: Tap different plot (should change selection)")
	var plot2_pos_screen = _get_plot_screen_position(plot_grid, Vector2i(1, 0))
	await _simulate_tap(plot2_pos_screen)
	await create_timer(0.2).timeout

	var selection_after_3 = plot_grid.get_selected_plot() if plot_grid.has_method("get_selected_plot") else null
	print("   Result: Selection = %s" % selection_after_3)
	if selection_after_3 != selection_after_2:
		test_log.append("✅ Touch 3 on different plot: Changed selection from %s to %s" % [selection_after_2, selection_after_3])
	else:
		test_log.append("❌ Touch 3 on different plot: Selection did not change")

	# Bonus: What does selection DO?
	print("\n🧪 BONUS: Testing if selection triggers actions automatically")
	if farm and farm.has_method("get_plot_state"):
		var plot_state_before = farm.get_plot_state(selection_after_3)
		print("   Plot state before: %s" % plot_state_before)

		# Wait a moment to see if anything happens automatically
		await create_timer(0.5).timeout

		var plot_state_after = farm.get_plot_state(selection_after_3)
		print("   Plot state after: %s" % plot_state_after)

		if plot_state_before == plot_state_after:
			test_log.append("📝 Plot selection is PASSIVE - selecting does not trigger actions")
		else:
			test_log.append("📝 Plot selection is ACTIVE - selecting triggered state change!")


func _test_bubble_touches(quantum_graph, touch_mgr) -> void:
	"""Test what happens when touching bubbles multiple times"""

	if not quantum_graph:
		test_log.append("⚠️  Skipped bubble test - QuantumForceGraph not found")
		print("⚠️  QuantumForceGraph not found - skipping bubble tests\n")
		return

	# Connect to bubble click signal
	var bubble_clicks = []
	if quantum_graph.has_signal("node_clicked"):
		quantum_graph.node_clicked.connect(func(grid_pos, button_idx):
			bubble_clicks.append({"pos": grid_pos, "button": button_idx})
			print("   💥 Bubble clicked: grid_pos=%s, button=%s" % [grid_pos, button_idx])
		)
	else:
		test_log.append("⚠️  QuantumForceGraph doesn't have node_clicked signal")
		return

	# Get bubble positions (if any exist)
	var bubble_nodes = []
	if quantum_graph.has_method("get_all_nodes"):
		bubble_nodes = quantum_graph.get_all_nodes()

	print("📍 Bubbles available: %d" % bubble_nodes.size())

	if bubble_nodes.is_empty():
		test_log.append("⚠️  No bubbles found to test (quantum visualization not initialized)")
		print("⚠️  No bubbles to test\n")
		return

	# Touch 1: Tap a bubble
	print("\n🧪 TOUCH 1: Tap on bubble (should trigger measurement/collapse)")
	var bubble_screen_pos = Vector2(480, 150)  # Approximate bubble area
	await _simulate_tap(bubble_screen_pos)
	await create_timer(0.3).timeout

	var clicks_after_1 = bubble_clicks.size()
	print("   Result: %d bubble click(s) detected" % clicks_after_1)
	if clicks_after_1 > 0:
		test_log.append("✅ Touch 1 on bubble: Triggered measurement (click detected)")
	else:
		test_log.append("⚠️  Touch 1 on bubble: No click detected (may have missed bubble)")

	# Touch 2: Tap same area again
	print("\n🧪 TOUCH 2: Tap same bubble area again (should trigger another measurement)")
	await _simulate_tap(bubble_screen_pos)
	await create_timer(0.3).timeout

	var clicks_after_2 = bubble_clicks.size()
	print("   Result: Total %d bubble click(s)" % clicks_after_2)
	if clicks_after_2 > clicks_after_1:
		test_log.append("✅ Touch 2 on bubble: Triggered another measurement (total %d clicks)" % clicks_after_2)
	else:
		test_log.append("⚠️  Touch 2 on bubble: No additional click (may have missed bubble)")

	# Touch 3: Tap different bubble area
	print("\n🧪 TOUCH 3: Tap different bubble area")
	var bubble2_screen_pos = Vector2(600, 150)
	await _simulate_tap(bubble2_screen_pos)
	await create_timer(0.3).timeout

	var clicks_after_3 = bubble_clicks.size()
	print("   Result: Total %d bubble click(s)" % clicks_after_3)
	if clicks_after_3 > clicks_after_2:
		test_log.append("✅ Touch 3 on different bubble: Triggered measurement (total %d clicks)" % clicks_after_3)
	else:
		test_log.append("⚠️  Touch 3: No additional click")

	# Summary
	if clicks_after_3 > 0:
		test_log.append("📝 Bubble taps are ACTIVE - each tap triggers immediate measurement/collapse")
	else:
		test_log.append("📝 Unable to verify bubble behavior (no bubbles hit)")


func _simulate_tap(position: Vector2) -> void:
	"""Simulate a touch tap at given screen position"""
	var touch_down = InputEventScreenTouch.new()
	touch_down.pressed = true
	touch_down.position = position
	Input.parse_input_event(touch_down)

	await create_timer(0.1).timeout

	var touch_up = InputEventScreenTouch.new()
	touch_up.pressed = false
	touch_up.position = position
	Input.parse_input_event(touch_up)


func _get_plot_screen_position(plot_grid, grid_pos: Vector2i) -> Vector2:
	"""Get approximate screen position of a plot tile"""
	# Try to get tile position
	if plot_grid.has_method("get_tile_position"):
		return plot_grid.get_tile_position(grid_pos)

	# Fallback: estimate based on grid position and typical spacing
	var base_x = 225.0
	var base_y = 223.0
	var spacing_x = 75.0
	var spacing_y = 130.0

	return Vector2(base_x + grid_pos.x * spacing_x, base_y + grid_pos.y * spacing_y)


func _find_node_recursive(node: Node, name_contains: String) -> Node:
	"""Recursively find node whose name or script contains the string"""
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
