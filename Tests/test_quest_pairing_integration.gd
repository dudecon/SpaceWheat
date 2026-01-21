extends Node

## Test VocabularyPairing integration with QuestRewards

const QuestRewards = preload("res://Core/Quests/QuestRewards.gd")
const VocabularyPairing = preload("res://Core/Quests/VocabularyPairing.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("  QUEST PAIRING INTEGRATION TEST")
	print("=".repeat(60))

	await get_tree().process_frame

	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		print("[ERROR] IconRegistry not found")
		_finish()
		return

	print("IconRegistry: %d icons\n" % icon_registry.icons.size())

	# Test 1: Direct VocabularyPairing (should still work)
	print("-".repeat(50))
	print("Test 1: Direct VocabularyPairing.roll_partner()")
	print("-".repeat(50))
	_test_direct_pairing()

	# Test 2: QuestRewards.generate_reward() produces pairs
	print("\n" + "-".repeat(50))
	print("Test 2: QuestRewards.generate_reward() produces pairs")
	print("-".repeat(50))
	_test_quest_reward_pairing()

	# Test 3: Multiple factions produce different pairs
	print("\n" + "-".repeat(50))
	print("Test 3: Multiple factions produce pairs")
	print("-".repeat(50))
	_test_multiple_factions()

	# Test 4: Format output
	print("\n" + "-".repeat(50))
	print("Test 4: Reward text formatting")
	print("-".repeat(50))
	_test_format_output()

	_finish()


func _test_direct_pairing() -> void:
	var result = VocabularyPairing.roll_partner("🐝")

	if result.get("error"):
		print("  ❌ Error: %s" % result.get("error"))
		return

	var north = result.get("north", "?")
	var south = result.get("south", "?")
	var prob = result.get("probability", 0.0)

	print("  Rolled: %s/%s (%.1f%% probability)" % [north, south, prob * 100])
	print("  ✓ Direct pairing works")


func _test_quest_reward_pairing() -> void:
	# Create a mock quest from a faction with known vocabulary
	var test_faction = null
	for faction in FactionDatabase.ALL_FACTIONS:
		var sig = faction.get("sig", faction.get("signature", []))
		if sig.size() > 0:
			test_faction = faction
			break

	if not test_faction:
		print("  ❌ No faction found with vocabulary")
		return

	var faction_name = test_faction.get("name", "Unknown")
	var faction_sig = test_faction.get("sig", test_faction.get("signature", []))
	print("  Testing faction: %s" % faction_name)
	print("  Faction signature: %s" % str(faction_sig))

	# Create mock quest
	var quest = {
		"faction": faction_name,
		"quantity": 5,
		"reward_multiplier": 1.0
	}

	# Empty player vocabulary so we get a reward
	var player_vocab: Array = []

	# Generate reward
	var reward = QuestRewards.generate_reward(quest, null, player_vocab)

	print("  Reward generated:")
	print("    💰: %d" % reward.money_amount)
	print("    learned_vocabulary: %s" % str(reward.learned_vocabulary))
	print("    learned_pairs: %d pairs" % reward.learned_pairs.size())

	for pair in reward.learned_pairs:
		print("      %s/%s (%.1f%% prob, weight %.3f)" % [
			pair.get("north", "?"),
			pair.get("south", "?"),
			pair.get("probability", 0.0) * 100,
			pair.get("weight", 0.0)
		])

	# Verify we got a pair
	if reward.learned_pairs.size() > 0:
		print("  ✓ Quest reward produces paired vocabulary")
	elif reward.learned_vocabulary.size() > 0:
		print("  ⚠ Got vocabulary but no pair (emoji has no connections)")
	else:
		print("  ❌ No vocabulary reward generated")


func _test_multiple_factions() -> void:
	var factions_tested = 0
	var pairs_generated = 0

	for faction in FactionDatabase.ALL_FACTIONS:
		var faction_name = faction.get("name", "Unknown")
		var faction_sig = faction.get("sig", faction.get("signature", []))

		if faction_sig.is_empty():
			continue

		var quest = {
			"faction": faction_name,
			"quantity": 5,
			"reward_multiplier": 1.0
		}

		var reward = QuestRewards.generate_reward(quest, null, [])
		factions_tested += 1

		if reward.learned_pairs.size() > 0:
			pairs_generated += 1
			var pair = reward.learned_pairs[0]
			print("  %s: %s/%s" % [faction_name, pair.get("north"), pair.get("south")])

		if factions_tested >= 5:
			break

	print("\n  Tested %d factions, %d generated pairs" % [factions_tested, pairs_generated])
	if pairs_generated > 0:
		print("  ✓ Multiple factions produce pairs")
	else:
		print("  ❌ No pairs generated from any faction")


func _test_format_output() -> void:
	# Create a reward with a pair
	var reward = QuestRewards.QuestReward.new()
	reward.money_amount = 50
	reward.learned_vocabulary.append("🐝")
	reward.learned_vocabulary.append("🌿")
	reward.learned_pairs.append({
		"north": "🐝",
		"south": "🌿",
		"weight": 0.56,
		"probability": 0.444
	})

	var text = QuestRewards.format_reward_text(reward)
	print("  Formatted reward text:")
	for line in text.split("\n"):
		print("    %s" % line)

	if "axis" in text:
		print("  ✓ Format shows axis notation")
	else:
		print("  ❌ Format missing axis notation")


func _finish() -> void:
	print("\n" + "=".repeat(60))
	print("Test complete.")
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
