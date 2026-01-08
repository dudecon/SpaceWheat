#!/usr/bin/env -S godot --headless -s
## Test: 4-Tool System Initialization
## Verify FarmInputHandler loads with new 4-tool TOOL_ACTIONS

extends SceneTree

const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")

func _initialize():
	print("\n" + _sep("═", 80))
	print("🧪 Testing 4-Tool System Initialization")
	print(_sep("═", 80) + "\n")

	var handler = FarmInputHandler.new()
	print("✓ FarmInputHandler created\n")

	# Verify all 4 tools exist
	print("🛠️  Tool System:")
	var all_tools_valid = true
	for tool_num in range(1, 5):
		if handler.TOOL_ACTIONS.has(tool_num):
			var tool = handler.TOOL_ACTIONS[tool_num]
			print("  Tool %d: %s" % [tool_num, tool["name"]])
			print("    Q: %s" % tool["Q"]["label"])
			print("    E: %s" % tool["E"]["label"])
			print("    R: %s" % tool["R"]["label"])
		else:
			print("  ❌ Tool %d MISSING!" % tool_num)
			all_tools_valid = false

	print()
	if all_tools_valid:
		print("✅ All 4 tools configured correctly")
	else:
		print("❌ Tool configuration incomplete")

	print("\n" + _sep("═", 80) + "\n")
	quit(0 if all_tools_valid else 1)


func _sep(char: String, count: int) -> String:
	var result = ""
	for _i in range(count):
		result += char
	return result
