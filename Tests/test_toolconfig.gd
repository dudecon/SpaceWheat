extends SceneTree

func _init():
	print("Testing ToolConfig...")
	var ToolConfig = load("res://Core/GameState/ToolConfig.gd")

	# Test Tool 1, Q action
	var action_info = ToolConfig.get_action(1, "Q")
	print("Tool 1, Q action: %s" % str(action_info))

	var action = action_info.get("action", "")
	print("Action name: '%s'" % action)

	# Test Tool 2
	var action_info_2 = ToolConfig.get_action(2, "Q")
	print("Tool 2, Q action: %s" % str(action_info_2))

	quit(0)
