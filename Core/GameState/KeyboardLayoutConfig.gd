class_name KeyboardLayoutConfig
extends Resource

## KeyboardLayoutConfig - Maps keyboard actions to grid positions and vice versa
## Decouples input system from grid layout

@export var action_to_position: Dictionary = {}  # "select_plot_t" → Vector2i(0,0)
@export var position_to_label: Dictionary = {}   # Vector2i(0,0) → "T"


func get_position_for_action(action: String) -> Vector2i:
	"""Get grid position for a keyboard action"""
	return action_to_position.get(action, Vector2i(-1, -1))


func get_label_for_position(pos: Vector2i) -> String:
	"""Get keyboard label for a grid position"""
	return position_to_label.get(pos, "")


func get_all_actions() -> Array[String]:
	"""Get all configured input actions"""
	var actions: Array[String] = []
	for action in action_to_position.keys():
		actions.append(str(action))
	return actions


func is_action_valid(action: String) -> bool:
	"""Check if action is configured"""
	return action_to_position.has(action)


func _to_string() -> String:
	return "KeyboardLayoutConfig(%d actions, %d positions)" % [action_to_position.size(), position_to_label.size()]
