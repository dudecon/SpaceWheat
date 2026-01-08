extends SceneTree

## Automated test that clicks on actual bubble positions
## This simulates real user taps on quantum bubbles

var tap_count = 0
var bubble_tap_count = 0
var plot_tap_count = 0

func _init():
	print("\n======================================================================")
	print("🧪 Testing Bubble Touch (Automated - Real Positions)")
	print("======================================================================")

	# Load and instantiate the main scene
	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		print("❌ Failed to load FarmView scene")
		quit()
		return

	var root = scene.instantiate()
	get_root().add_child(root)

	# Wait for initialization
	await create_timer(2.0).timeout

	print("\n📍 Finding quantum bubbles...")

	# Find QuantumForceGraph
	var force_graph = _find_quantum_force_graph(root)
	if not force_graph:
		print("❌ QuantumForceGraph not found")
		quit()
		return

	print("✅ QuantumForceGraph found: %s" % force_graph)
	print("   Nodes: %d" % force_graph.quantum_nodes.size())

	# Find TouchInputManager
	var touch_mgr = null
	for child in get_root().get_children():
		if child.name == "TouchInputManager":
			touch_mgr = child
			break

	if not touch_mgr:
		print("❌ TouchInputManager not found")
		quit()
		return

	# Connect to signals
	touch_mgr.tap_detected.connect(func(pos): tap_count += 1)
	force_graph.node_clicked.connect(func(grid_pos, button):
		bubble_tap_count += 1
		print("   ✅ Bubble action triggered! Grid: %s" % grid_pos)
	)

	print("✅ Signals connected")

	# Wait for bubbles to be created
	await create_timer(1.0).timeout

	# Get bubble positions
	var bubble_positions = []
	for node in force_graph.quantum_nodes:
		if node.plot and node.plot.is_planted:
			# Convert local node position to global screen position
			var global_pos = force_graph.get_global_transform() * node.position
			bubble_positions.append({
				"grid_pos": node.grid_position,
				"screen_pos": global_pos,
				"radius": node.radius
			})

	if bubble_positions.is_empty():
		print("⚠️  No planted bubbles found - planting some first...")

		# Find farm
		var farm = _find_farm(root)
		if farm:
			# Plant a few plots
			farm.plant_wheat(Vector2i(0, 0))
			farm.plant_wheat(Vector2i(1, 0))
			farm.plant_wheat(Vector2i(2, 0))

			await create_timer(1.0).timeout

			# Re-scan for bubbles
			for node in force_graph.quantum_nodes:
				if node.plot and node.plot.is_planted:
					var global_pos = force_graph.get_global_transform() * node.position
					bubble_positions.append({
						"grid_pos": node.grid_position,
						"screen_pos": global_pos,
						"radius": node.radius
					})

	print("\n📊 Found %d bubbles to tap:" % bubble_positions.size())
	for i in range(min(3, bubble_positions.size())):
		var b = bubble_positions[i]
		print("   Bubble at grid %s: screen pos (%.1f, %.1f), radius %.1f" % [
			b.grid_pos, b.screen_pos.x, b.screen_pos.y, b.radius
		])

	# Test 1: Tap each bubble
	print("\n--- Test 1: Tapping bubbles at actual positions ---")
	for bubble in bubble_positions:
		print("\n🖱️  Tapping bubble at grid %s (screen: %.1f, %.1f)" % [
			bubble.grid_pos, bubble.screen_pos.x, bubble.screen_pos.y
		])
		await _tap_position(bubble.screen_pos)
		await create_timer(0.2).timeout

	# Results
	print("\n======================================================================")
	print("📊 TEST RESULTS")
	print("======================================================================")
	print("Bubbles tested: %d" % bubble_positions.size())
	print("Total taps detected by TouchInputManager: %d" % tap_count)
	print("Bubble actions triggered: %d" % bubble_tap_count)

	if bubble_tap_count == bubble_positions.size():
		print("\n✅ SUCCESS: All bubble taps triggered actions!")
	elif bubble_tap_count > 0:
		print("\n⚠️  PARTIAL: %d/%d bubble taps worked" % [bubble_tap_count, bubble_positions.size()])
	else:
		print("\n❌ FAILURE: No bubble taps triggered actions")
		print("   TouchInputManager detected taps: %s" % ("YES" if tap_count > 0 else "NO"))
		print("   This suggests coordinate transformation or signal routing issue")

	print("======================================================================")

	quit()


func _find_quantum_force_graph(node: Node) -> Node:
	"""Recursively find QuantumForceGraph node"""
	if node.get_class() == "Node2D" and node.get_script():
		var script = node.get_script()
		if script and script.resource_path.contains("QuantumForceGraph"):
			return node

	for child in node.get_children():
		var result = _find_quantum_force_graph(child)
		if result:
			return result

	return null


func _find_farm(node: Node) -> Node:
	"""Recursively find Farm node"""
	if node.name == "Farm" or (node.get_script() and str(node.get_script()).contains("Farm.gd")):
		return node

	for child in node.get_children():
		var result = _find_farm(child)
		if result:
			return result

	return null


func _tap_position(position: Vector2) -> void:
	"""Simulate touch tap at specific position"""
	# Use touch-generated mouse events (device=0) since that's what the platform generates
	var down = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = position
	down.device = 0  # Touch-generated

	Input.parse_input_event(down)
	await create_timer(0.05).timeout

	var up = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = position
	up.device = 0  # Touch-generated

	Input.parse_input_event(up)
