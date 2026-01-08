extends SceneTree

## Automated test: Keyboard Q vs Touch Q button
## Tests if both paths trigger submenu display update

func _init():
	print("\n")
	print("================================================================================")
	print("AUTOMATED TEST: Keyboard Q vs Touch Q Button")
	print("================================================================================")
	print("")

	# Load the game scene
	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		print("❌ Failed to load FarmView scene")
		quit()
		return

	var farm_view = scene.instantiate()
	root.add_child(farm_view)

	print("✅ Game scene loaded")
	print("")

	# Wait for scene to initialize
	await create_timer(2.0).timeout

	print("Scene tree structure:")
	_print_tree(farm_view, 0)
	print("")

	# Find the action preview row
	var action_bar = _find_action_preview_row(farm_view)
	if not action_bar:
		print("❌ Could not find ActionPreviewRow")
		quit()
		return

	print("✅ Found ActionPreviewRow")
	print("")

	# Get the Q button
	var q_button = action_bar.action_buttons.get("Q")
	if not q_button:
		print("❌ Could not find Q button")
		quit()
		return

	print("✅ Found Q button, initial text: '%s'" % q_button.text)
	print("")

	# Get the input handler
	var input_handler = farm_view.input_handler
	if not input_handler:
		print("❌ Could not find input handler")
		quit()
		return

	print("✅ Found FarmInputHandler")
	print("")

	# TEST 1: Keyboard Q
	print("================================================================================")
	print("TEST 1: Keyboard Q (simulated)")
	print("================================================================================")
	print("")

	# Select tool 1
	input_handler._select_tool(1)
	await create_timer(0.3).timeout

	print("Current tool: %d" % input_handler.current_tool)
	print("Current submenu: '%s'" % input_handler.current_submenu)
	print("Q button text BEFORE: '%s'" % q_button.text)
	print("")

	# Simulate keyboard Q press
	print("Simulating keyboard Q press via _execute_tool_action()...")
	input_handler._execute_tool_action("Q")

	await create_timer(0.5).timeout

	print("")
	print("After keyboard Q:")
	print("  Current submenu: '%s'" % input_handler.current_submenu)
	print("  Q button text AFTER: '%s'" % q_button.text)
	var keyboard_worked = input_handler.current_submenu == "plant" and "Wheat" in q_button.text
	print("  Result: %s" % ("✅ WORKED" if keyboard_worked else "❌ FAILED"))
	print("")

	# Reset
	input_handler._exit_submenu()
	await create_timer(0.3).timeout

	# TEST 2: Touch Q (button click)
	print("================================================================================")
	print("TEST 2: Touch Q (button click)")
	print("================================================================================")
	print("")

	# Select tool 1 again
	input_handler._select_tool(1)
	await create_timer(0.3).timeout

	print("Current tool: %d" % input_handler.current_tool)
	print("Current submenu: '%s'" % input_handler.current_submenu)
	print("Q button text BEFORE: '%s'" % q_button.text)
	print("")

	# Simulate touch by calling execute_action (public method used by button)
	print("Simulating touch Q press via execute_action()...")
	input_handler.execute_action("Q")

	await create_timer(0.5).timeout

	print("")
	print("After touch Q:")
	print("  Current submenu: '%s'" % input_handler.current_submenu)
	print("  Q button text AFTER: '%s'" % q_button.text)
	var touch_worked = input_handler.current_submenu == "plant" and "Wheat" in q_button.text
	print("  Result: %s" % ("✅ WORKED" if touch_worked else "❌ FAILED"))
	print("")

	# Summary
	print("================================================================================")
	print("TEST SUMMARY")
	print("================================================================================")
	print("Keyboard Q: %s" % ("✅ PASSED" if keyboard_worked else "❌ FAILED"))
	print("Touch Q:    %s" % ("✅ PASSED" if touch_worked else "❌ FAILED"))
	print("")

	if keyboard_worked and not touch_worked:
		print("⚠️  ISSUE CONFIRMED: Touch path broken, keyboard works")
	elif not keyboard_worked and not touch_worked:
		print("⚠️  Both paths broken - different issue")
	elif keyboard_worked and touch_worked:
		print("✅ Both paths working!")

	print("")
	print("Check logs above for signal chain traces")
	print("================================================================================")

	quit()


func _print_tree(node: Node, depth: int) -> void:
	"""Print scene tree for debugging"""
	if depth > 5:  # Limit depth
		return

	var indent = "  ".repeat(depth)
	var script_name = ""
	if node.get_script():
		var script = node.get_script()
		if script.get_global_name() != "":
			script_name = " (" + script.get_global_name() + ")"

	print("%s- %s%s" % [indent, node.name, script_name])

	for child in node.get_children():
		_print_tree(child, depth + 1)


func _find_action_preview_row(node: Node) -> Node:
	"""Recursively find ActionPreviewRow in scene tree"""
	# Check node class name
	var script = node.get_script()
	if script and script.get_global_name() == "ActionPreviewRow":
		return node

	# Check node name
	if node.name == "ActionPreviewRow" or "ActionPreview" in node.name:
		return node

	# Recursively search children
	for child in node.get_children():
		var result = _find_action_preview_row(child)
		if result:
			return result

	return null
