## Mock QuestManager for testing QuestBoard
class_name MockQuestManager extends RefCounted

signal active_quests_changed(active_quests: Dictionary)
signal quest_completed(quest_id: int)

var active_quests: Dictionary = {}
var completed_quests: Array[int] = []
var economy: MockEconomy

var _quest_counter = 0

func _init(economy: MockEconomy = null):
	self.economy = economy if economy else MockEconomy.new()

## Generate a test quest with known properties
func create_test_quest(faction: String, reward_north: String = "✓", reward_south: String = "✗", level: int = 1) -> Dictionary:
	var quest_id = _quest_counter
	_quest_counter += 1

	return {
		"id": quest_id,
		"faction": faction,
		"type": 1,  # Non-delivery
		"level": level,
		"reward_vocab_north": reward_north,
		"reward_vocab_south": reward_south,
		"required_resources": {"🌲": 1},
		"emoji_pair": [reward_north, reward_south],
		"description": "Test quest %d from %s" % [quest_id, faction]
	}

func accept_quest(quest_id: int) -> bool:
	if quest_id not in active_quests:
		active_quests[quest_id] = {"id": quest_id, "status": "active"}
		active_quests_changed.emit(active_quests)
		return true
	return false

func complete_quest(quest_id: int) -> bool:
	if quest_id in active_quests:
		active_quests.erase(quest_id)
		completed_quests.append(quest_id)
		quest_completed.emit(quest_id)
		active_quests_changed.emit(active_quests)
		return true
	return false

func abandon_quest(quest_id: int) -> bool:
	if quest_id in active_quests:
		active_quests.erase(quest_id)
		active_quests_changed.emit(active_quests)
		return true
	return false

func offer_all_faction_quests(biome) -> Array:
	# This would normally rebuild from factions
	# For testing, we return empty - test sets pool directly
	return []

func get_known_emojis() -> Array:
	return []  # Mock always returns empty, test controls this
