#!/usr/bin/env -S godot --headless -s
## Comprehensive test of all tools and their Q/E/R actions
##
## Tests each tool (1-4) and verifies Q/E/R actions execute correctly

extends SceneTree

const Farm = preload("res://Core/Farm.gd")
const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")

var farm: Farm
var input_handler: FarmInputHandler
var test_results = {}
var action_log = []

func _sep(char: String, count: int) -> String:
	var result = ""
	for _i in range(count):
		result += char
	return result


func _initialize():
	print("\n" + _sep("═", 100))
	print("🔧 COMPREHENSIVE TOOL & ACTION TEST")
	print("Testing all 4 tools with Q/E/R actions")
	print(_sep("═", 100) + "\n")

	_setup()
	_test_all_tools()
	_print_results()

	quit(0)


func _setup():
	print("📋 SETUP\n")

	# Create farm
	farm = Farm.new()
	farm._ready()
	print("  ✓ Farm initialized")

	# Create input handler
	input_handler = FarmInputHandler.new()
	input_handler.farm = farm
	input_handler.action_performed.connect(_on_action_performed)
	print("  ✓ Input handler initialized")

	# Set a starting plot for testing
	input_handler._set_selection(Vector2i(0, 0))
	print("  ✓ Selected starting plot (0,0)\n")


func _test_all_tools():
	print("\n" + _sep("═", 100))
	print("TESTING ALL TOOLS (1-4) AND ACTIONS (Q/E/R)")
	print(_sep("═", 100) + "\n")

	var tool_names = {
		1: "Grower 🌱",
		2: "Quantum ⚛️",
		3: "Industry 🏭",
		4: "Energy ⚡",
	}

	for tool_num in range(1, 5):
		var tool_name = tool_names.get(tool_num, "Unknown")

		print("\n" + _sep("─", 100))
		print("TOOL %d: %s" % [tool_num, tool_name])
		print(_sep("─", 100))

		# Select tool
		input_handler._select_tool(tool_num)
		print("  Selected tool %d\n" % tool_num)

		# Get tool actions
		var tool_actions = input_handler.TOOL_ACTIONS.get(tool_num, {})

		# Test each action (Q, E, R)
		for action_key in ["Q", "E", "R"]:
			var action_info = tool_actions.get(action_key, {})
			var action_name = action_info.get("action", "unknown")
			var label = action_info.get("label", "?")
			var emoji = action_info.get("emoji", "")

			print("  [%s] %s" % [action_key, label])
			print("      Action: %s %s" % [emoji, action_name])

			# Execute action by calling it with current selection
			var selected_plots: Array[Vector2i] = [Vector2i(0, 0)]
			_execute_action(action_name, selected_plots)
			print("")


func _execute_action(action_name: String, positions: Array[Vector2i]):
	"""Execute a specific action handler"""
	match action_name:
		"plant_batch":
			input_handler._action_plant_batch(positions)
		"entangle_batch":
			input_handler._action_entangle_batch(positions)
		"measure_and_harvest":
			input_handler._action_batch_measure_and_harvest(positions)
		"cluster":
			input_handler._action_cluster(positions)
		"measure_plot":
			input_handler._action_batch_measure(positions)
		"break_entanglement":
			input_handler._action_break_entanglement(positions)
		"place_mill":
			input_handler._action_batch_build("mill", positions)
		"place_market":
			input_handler._action_batch_build("market", positions)
		"place_kitchen":
			input_handler._action_batch_build("kitchen", positions)
		"inject_energy":
			input_handler._action_inject_energy(positions)
		"drain_energy":
			input_handler._action_drain_energy(positions)
		"place_energy_tap":
			input_handler._action_place_energy_tap(positions)
		_:
			print("      WARNING: Unknown action: %s" % action_name)


func _on_action_performed(action: String, success: bool, message: String):
	var status = "✓" if success else "✗"
	var line = "      Result: [%s] %s" % [status, message]
	print(line)

	action_log.append({
		"action": action,
		"success": success,
		"message": message
	})

	if not test_results.has(action):
		test_results[action] = {"success": 0, "failed": 0}

	if success:
		test_results[action]["success"] += 1
	else:
		test_results[action]["failed"] += 1


func _print_results():
	print("\n" + _sep("═", 100))
	print("TEST RESULTS SUMMARY")
	print(_sep("═", 100) + "\n")

	var total_success = 0
	var total_failed = 0

	# Sort actions
	var actions = test_results.keys()
	actions.sort()

	for action in actions:
		var result = test_results[action]
		var success = result["success"]
		var failed = result["failed"]
		total_success += success
		total_failed += failed

		var status = "✓" if failed == 0 else "⚠"
		print("  %s %s: %d success, %d failed" % [status, action, success, failed])

	print("\n" + _sep("═", 100))
	if total_failed == 0:
		print("✅ ALL %d ACTIONS PASSED!" % total_success)
	else:
		print("⚠  %d actions succeeded, %d failed" % [total_success, total_failed])
	print(_sep("═", 100) + "\n")
