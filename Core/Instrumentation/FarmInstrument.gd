class_name FarmInstrument
extends Node

## FarmInstrument - Bridge between classical resources, the quest/vocabulary UI, and QII tooling.
##
## Provides a single API for external scripts (like the emoji bash runners) to:
##   1. Query economy/output information (resources, farm grid)
##   2. Control modal overlays (quest board, vocabulary)
##   3. Interact with the quest manager (offer, accept, read status)
##
## This node is created by BootManager after FarmUI and the PlayerShell overlays exist.

@onready var _verbose = get_node_or_null("/root/VerboseConfig")

var farm: Node = null
var player_shell: Node = null
var overlay_manager = null
var quest_manager = null
var action_bar_manager = null


func setup(farm_ref: Node, shell_ref: Node) -> void:
	farm = farm_ref
	player_shell = shell_ref
	if not shell_ref:
		return

	if "overlay_manager" in shell_ref:
		overlay_manager = shell_ref.overlay_manager
	if "quest_manager" in shell_ref:
		quest_manager = shell_ref.quest_manager
	if overlay_manager:
		overlay_manager.farm = farm_ref
	if "action_bar_manager" in shell_ref:
		action_bar_manager = shell_ref.action_bar_manager

	if _verbose:
		_verbose.info("instrument", "🎛️", "FarmInstrument initialized (farm=%s, shell=%s)" % [
			farm_ref.name if farm_ref else "null",
			shell_ref.name if shell_ref else "null"
		])


func open_quest_board() -> bool:
	return _open_overlay("quests")


func open_vocabulary_panel() -> bool:
	return _open_overlay("vocabulary")


func open_controls_panel() -> bool:
	return _open_overlay("controls")


func _open_overlay(name: String) -> bool:
	if not overlay_manager:
		return false
	return overlay_manager.open_v2_overlay(name)


func get_resource_amount(emoji: String) -> float:
	if farm and "economy" in farm and farm.economy:
		if farm.economy.has_method("get_resource"):
			return farm.economy.get_resource(emoji)
	return 0


func describe_resources() -> Dictionary:
	if farm and "economy" in farm and farm.economy:
		if farm.economy.has_method("get_all_resources"):
			return farm.economy.get_all_resources()
	return {}


func get_resource_snapshot() -> Dictionary:
	"""Return a stable snapshot of resources for turn-by-turn rigs."""
	var resources = describe_resources()
	var keys: Array = resources.keys()
	keys.sort()
	return {
		"resources": resources,
		"ordered": keys
	}


func get_active_quests() -> Array:
	if quest_manager and quest_manager.has_method("get_active_quests"):
		return quest_manager.get_active_quests()
	return []


func accept_quest_by_id(quest_id: int) -> bool:
	if not quest_manager:
		return false
	var quest = quest_manager.get_quest_by_id(quest_id) if quest_manager.has_method("get_quest_by_id") else {}
	if quest.is_empty():
		return false
	return quest_manager.accept_quest(quest)


func offer_all_quests_for_current_biome() -> void:
	if not quest_manager or not farm:
		return
	if not quest_manager.has_method("offer_all_faction_quests"):
		return
	var current_biome = farm.get_current_biome() if farm.has_method("get_current_biome") else null
	var biome_name = current_biome.get_biome_type() if current_biome and current_biome.has_method("get_biome_type") else ""
	quest_manager.offer_all_faction_quests(biome_name)


func log_action(action: String, details: Dictionary = {}) -> void:
	if _verbose:
		_verbose.info("instrument", "✍️", "%s %s" % [action, str(details)])
