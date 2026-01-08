#!/usr/bin/env godot --headless -s
## Comprehensive test of all tools and their Q/E/R actions

extends SceneTree

const Farm = preload("res://Core/Farm.gd")
const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")

var farm: Farm
var input_handler: FarmInputHandler
var test_results = {}

func _ready():
	_print_header("COMPREHENSIVE TOOL AND ACTION TEST")
	
	# Initialize farm
	farm = Farm.new()
	farm._ready()
	add_child(farm)
	print("✓ Farm initialized\n")
	
	# Initialize input handler
	input_handler = FarmInputHandler.new()
	input_handler.farm = farm
	add_child(input_handler)
	
	# Connect to action signals
	input_handler.action_performed.connect(_on_action_performed)
	print("✓ Input handler initialized\n")
	
	# Start testing
	await _test_all_tools()
	
	# Print results
	_print_results()
	
	quit()


func _test_all_tools():
	print("\n" + "=" * 100)
	print("TESTING ALL TOOLS (1-4) AND ACTIONS (Q/E/R)")
	print("=" * 100 + "\n")
	
	# Test each tool
	for tool_num in range(1, 5):
		await _test_tool(tool_num)
		await get_tree().create_timer(0.5).timeout


func _test_tool(tool_num: int):
	var tool_names = {
		1: "Grower",
		2: "Quantum",
		3: "Industry",
		4: "Energy"
	}
	var tool_name = tool_names.get(tool_num, "Unknown")
	
	print("\n" + "-" * 80)
	print("TOOL %d: %s" % [tool_num, tool_name])
	print("-" * 80)
	
	# Select tool
	input_handler._select_tool(tool_num)
	await get_tree().create_timer(0.1).timeout
	
	# Test Q action
	print("\n  Testing Q action...")
	_execute_action(tool_num, "Q")
	await get_tree().create_timer(0.2).timeout
	
	# Test E action
	print("\n  Testing E action...")
	_execute_action(tool_num, "E")
	await get_tree().create_timer(0.2).timeout
	
	# Test R action
	print("\n  Testing R action...")
	_execute_action(tool_num, "R")
	await get_tree().create_timer(0.2).timeout


func _execute_action(tool_num: int, action_key: String):
	var tool_actions = input_handler.TOOL_ACTIONS.get(tool_num, {})
	var action_info = tool_actions.get(action_key, {})
	var action_name = action_info.get("action", "unknown")
	var label = action_info.get("label", "?")
	var emoji = action_info.get("emoji", "")
	
	# Select a plot first
	input_handler._set_selection(Vector2i(0, 0))
	
	# Execute action
	print("    Executing: %s %s (%s)" % [emoji, label, action_name])
	input_handler.execute_tool_action(action_key)


func _on_action_performed(action: String, success: bool, message: String):
	var status = "✓" if success else "✗"
	print("    [%s] %s - %s" % [status, action, message])
	
	if not test_results.has(action):
		test_results[action] = {"success": 0, "failed": 0}
	
	if success:
		test_results[action]["success"] += 1
	else:
		test_results[action]["failed"] += 1


func _print_results():
	print("\n" + "=" * 100)
	print("TEST RESULTS SUMMARY")
	print("=" * 100)
	
	var total_success = 0
	var total_failed = 0
	
	for action in test_results.keys().sorted():
		var result = test_results[action]
		var success = result["success"]
		var failed = result["failed"]
		total_success += success
		total_failed += failed
		
		var status = "✓" if failed == 0 else "⚠"
		print("%s %s: %d success, %d failed" % [status, action, success, failed])
	
	print("\n" + "=" * 100)
	if total_failed == 0:
		print("✅ ALL ACTIONS PASSED!")
	else:
		print("⚠  %d actions failed" % total_failed)
	print("=" * 100 + "\n")


func _print_header(title: String):
	var line = ""
	for i in range(100):
		line += "="
	print("\n" + line)
	print(title)
	print(line + "\n")

