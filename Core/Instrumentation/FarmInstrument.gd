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


func get_grid_snapshot() -> Dictionary:
	"""Return a minimal grid snapshot for QA turn-by-turn rigs."""
	if not farm or not ("grid" in farm) or not farm.grid:
		return {"ok": false, "error": "no_grid"}
	var grid = farm.grid
	var snapshot: Dictionary = {"ok": true}
	if "grid_width" in grid:
		snapshot["grid_width"] = grid.grid_width
	if "grid_height" in grid:
		snapshot["grid_height"] = grid.grid_height
	if "biomes" in grid and grid.biomes:
		var biome_names = grid.biomes.keys()
		biome_names.sort()
		snapshot["biomes"] = biome_names
	if snapshot.has("grid_width") and snapshot.has("grid_height"):
		snapshot["plot_count"] = int(snapshot["grid_width"]) * int(snapshot["grid_height"])
	return snapshot


func add_resource(emoji: String, credits_amount: int, reason: String = "rig_seed") -> bool:
	"""Add emoji-credits directly to economy (used by QA rigs)."""
	if not farm or not ("economy" in farm) or not farm.economy:
		return false
	if not farm.economy.has_method("add_resource"):
		return false
	farm.economy.add_resource(emoji, credits_amount, reason)
	return true


func get_active_quests() -> Array:
	if quest_manager and quest_manager.has_method("get_active_quests"):
		return quest_manager.get_active_quests()
	return []


func get_quest_offers_for_current_biome() -> Array:
	"""Return quest offers for the current biome (does not accept)."""
	if not quest_manager or not farm:
		return []
	if not quest_manager.has_method("offer_all_faction_quests"):
		return []
	var current_biome = farm.get_current_biome() if farm.has_method("get_current_biome") else null
	if not current_biome and farm.grid and farm.grid.biomes and not farm.grid.biomes.is_empty():
		current_biome = farm.grid.biomes.values()[0]
	if not current_biome:
		return []
	return quest_manager.offer_all_faction_quests(current_biome)


func accept_quest_data(quest_data: Dictionary) -> bool:
	if not quest_manager:
		return false
	return quest_manager.accept_quest(quest_data)


func complete_quest(quest_id: int) -> bool:
	if not quest_manager:
		return false
	return quest_manager.complete_quest(quest_id)


func claim_quest(quest_id: int) -> bool:
	if not quest_manager:
		return false
	return quest_manager.claim_quest(quest_id)


func get_known_vocab_pairs() -> Array:
	if farm and farm.has_method("get_known_pairs"):
		return farm.get_known_pairs()
	return []


func get_known_vocab_emojis() -> Array:
	if farm and farm.has_method("get_known_emojis"):
		return farm.get_known_emojis()
	return []


func get_biome_positions(biome_name: String) -> Array:
	"""Return plot positions for a biome name."""
	if not farm or not ("grid" in farm) or not farm.grid:
		return []
	if not ("plot_biome_assignments" in farm.grid):
		return []
	var positions: Array = []
	for pos in farm.grid.plot_biome_assignments:
		if farm.grid.plot_biome_assignments[pos] == biome_name:
			positions.append(pos)
	return positions


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
	if not current_biome and farm.grid and farm.grid.biomes and not farm.grid.biomes.is_empty():
		current_biome = farm.grid.biomes.values()[0]
	if current_biome:
		quest_manager.offer_all_faction_quests(current_biome)


func log_action(action: String, details: Dictionary = {}) -> void:
	if _verbose:
		_verbose.info("instrument", "✍️", "%s %s" % [action, str(details)])
