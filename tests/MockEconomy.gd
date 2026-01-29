## Mock Economy for testing
class_name MockEconomy extends RefCounted

var resources: Dictionary = {
	"🌲": 100,  # Trees
	"🐇": 100,  # Rabbits
	"☀️": 100,  # Default resources for everything
}

var action_log: Array[String] = []
var always_approve: bool = true

func _init():
	pass

func has_resource(resource_type: String, amount: int = 1) -> bool:
	if not always_approve:
		return resources.get(resource_type, 0) >= amount
	return true

func spend_resource(resource_type: String, amount: int = 1) -> bool:
	action_log.append("Spend %d×%s" % [amount, resource_type])
	if always_approve:
		return true
	if resources.get(resource_type, 0) >= amount:
		resources[resource_type] -= amount
		return true
	return false

func get_debug_info() -> String:
	return "Resources: %s, Actions: %d" % [resources, action_log.size()]
