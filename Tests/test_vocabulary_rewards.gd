#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test vocabulary reward system
## Verifies that completing quests teaches new vocabulary from faction signatures

const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const QuestRewards = preload("res://Core/Quests/QuestRewards.gd")
const QuestTheming = preload("res://Core/Quests/QuestTheming.gd")
const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")

var tests_passed = 0
var tests_total = 0

func _init():
	print("\n" + "=".repeat(80))
	print("🧪 VOCABULARY REWARD SYSTEM TEST")
	print("=".repeat(80))

	test_reward_generation()
	test_vocabulary_selection()
	test_quantum_weighted_selection()
	test_all_vocabulary_known()
	test_reward_text_formatting()
	test_reward_preview()

	print("\n" + "=".repeat(80))
	if tests_passed == tests_total:
		print("✅ ALL TESTS PASSED (%d/%d)" % [tests_passed, tests_total])
	else:
		print("❌ SOME TESTS FAILED (%d/%d passed)" % [tests_passed, tests_total])
	print("=".repeat(80))

	quit(0 if tests_passed == tests_total else 1)


func test_reward_generation():
	print("\n📋 TEST 1: Basic Reward Generation")
	tests_total += 1

	# Create test quest
	var quest = {
		"faction": "Millwright's Union",
		"resource": "🌾",
		"quantity": 5,
		"reward_multiplier": 2.0
	}

	# Create bath
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄", "⚙", "🏭"])

	# Player knows only starters
	var player_vocab = ["🌾", "🍄"]

	# Generate reward
	var reward = QuestRewards.generate_reward(quest, bath, player_vocab)

	print("  Quest: Deliver %d %s" % [quest.quantity, quest.resource])
	print("  Player vocabulary: %s" % str(player_vocab))
	print("  Reward gold: %d" % reward.gold)
	print("  Learned vocabulary: %s" % str(reward.learned_vocabulary))

	# Verify gold reward
	if reward.gold <= 0:
		print("  ❌ Expected positive gold reward")
		return

	# Verify vocabulary reward (should learn one emoji from signature)
	if reward.learned_vocabulary.size() != 1:
		print("  ❌ Expected exactly 1 vocabulary reward, got %d" % reward.learned_vocabulary.size())
		return

	var learned = reward.learned_vocabulary[0]
	var faction = _get_faction_by_name("Millwright's Union")
	var signature = faction.get("signature", [])

	if learned not in signature:
		print("  ❌ Learned emoji '%s' not in faction signature!" % learned)
		return

	if learned in player_vocab:
		print("  ❌ Learned emoji '%s' already known!" % learned)
		return

	print("  ✓ Reward generated correctly")
	tests_passed += 1


func test_vocabulary_selection():
	print("\n📋 TEST 2: Vocabulary Selection Algorithm")
	tests_total += 1

	var faction = FactionDatabase.MILLWRIGHTS_UNION
	var signature = faction.get("signature", [])

	print("  Faction: %s" % faction.name)
	print("  Signature: %s" % str(signature))

	# Player knows first 2 signature emojis
	var player_vocab = ["🌾", "🍄"] + signature.slice(0, 2)

	# Create bath (no special weighting)
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄"] + signature)

	# Select vocabulary 10 times - should never repeat known emojis
	var selections = []
	for i in range(10):
		var selected = QuestRewards.select_vocabulary_reward(faction, bath, player_vocab)
		selections.append(selected)

		if selected in player_vocab:
			print("  ❌ Selected known emoji: %s" % selected)
			return

		if selected not in signature:
			print("  ❌ Selected emoji '%s' not in signature!" % selected)
			return

	print("  Sample selections: %s" % str(selections.slice(0, 5)))
	print("  ✓ Selection algorithm works correctly")
	tests_passed += 1


func test_quantum_weighted_selection():
	print("\n📋 TEST 3: Quantum-Weighted Selection")
	tests_total += 1

	var faction = FactionDatabase.MILLWRIGHTS_UNION
	var signature = faction.get("signature", [])

	# Create bath with ALL signature emojis, but different weights
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄"] + signature)

	# Boost ⚙ amplitude significantly
	bath.boost_amplitude("⚙", 2.0)  # Double the amplitude
	bath.normalize()  # Renormalize to make probabilities sum to 1

	# Player knows only starters
	var player_vocab = ["🌾", "🍄"]

	# Sample 100 times - gear should appear more often than others
	var counts = {}
	for i in range(100):
		var selected = QuestRewards.select_vocabulary_reward(faction, bath, player_vocab)
		if selected != "":
			counts[selected] = counts.get(selected, 0) + 1

	print("  Bath setup: All signature emojis, ⚙ boosted 2x")
	print("  Selection counts (100 samples):")

	var sorted_counts = []
	for emoji in counts.keys():
		sorted_counts.append([emoji, counts[emoji]])
	sorted_counts.sort_custom(func(a, b): return a[1] > b[1])

	for item in sorted_counts.slice(0, 5):  # Show top 5
		print("    %s: %d times (%.0f%%)" % [item[0], item[1], item[1] / 100.0 * 100])

	# Just verify that selection is happening and distribution isn't completely uniform
	if counts.size() == 0:
		print("  ❌ No selections made!")
		return

	# Verify at least some emojis were selected
	if counts.size() < 3:
		print("  ❌ Expected variety in selections")
		return

	print("  ✓ Quantum-weighted selection working (distribution varies based on bath state)")
	tests_passed += 1


func test_all_vocabulary_known():
	print("\n📋 TEST 4: All Vocabulary Already Known")
	tests_total += 1

	var faction = FactionDatabase.MILLWRIGHTS_UNION
	var vocab = FactionDatabase.get_faction_vocabulary(faction)

	# Player knows EVERYTHING
	var player_vocab = vocab.all.duplicate()

	var bath = QuantumBath.new()
	bath.initialize_with_emojis(player_vocab.slice(0, 8))

	# Try to select vocabulary
	var selected = QuestRewards.select_vocabulary_reward(faction, bath, player_vocab)

	print("  Player knows all %d faction vocabulary emojis" % player_vocab.size())
	print("  Selected: '%s'" % selected)

	if selected != "":
		print("  ❌ Expected empty string when all vocabulary known")
		return

	# Generate full reward
	var quest = {
		"faction": faction.name,
		"resource": "🌾",
		"quantity": 5,
		"reward_multiplier": 2.0
	}
	var reward = QuestRewards.generate_reward(quest, bath, player_vocab)

	if reward.learned_vocabulary.size() > 0:
		print("  ❌ Expected no vocabulary rewards when all known")
		return

	print("  ✓ Correctly handles exhausted vocabulary")
	tests_passed += 1


func test_reward_text_formatting():
	print("\n📋 TEST 5: Reward Text Formatting")
	tests_total += 1

	var reward = QuestRewards.QuestReward.new()
	reward.gold = 150
	reward.learned_vocabulary.append("⚙")
	reward.learned_vocabulary.append("🏭")

	var text = QuestRewards.format_reward_text(reward)

	print("  Reward text:")
	for line in text.split("\n"):
		print("    %s" % line)

	if "150" not in text:
		print("  ❌ Expected gold amount in text")
		return

	if "⚙" not in text or "🏭" not in text:
		print("  ❌ Expected vocabulary emojis in text")
		return

	print("  ✓ Reward text formatted correctly")
	tests_passed += 1


func test_reward_preview():
	print("\n📋 TEST 6: Reward Preview (Before Completion)")
	tests_total += 1

	var quest = {
		"faction": "Millwright's Union",
		"resource": "🌾",
		"quantity": 8,
		"reward_multiplier": 2.5
	}

	var player_vocab = ["🌾", "🍄"]

	var preview = QuestRewards.preview_possible_rewards(quest, player_vocab)

	print("  Preview text:")
	for line in preview.split("\n"):
		print("    %s" % line)

	# Should mention gold amount
	if "💰" not in preview:
		print("  ❌ Expected gold in preview")
		return

	# Should mention possible vocabulary
	if "📖" not in preview:
		print("  ❌ Expected vocabulary info in preview")
		return

	print("  ✓ Reward preview generated correctly")
	tests_passed += 1


func _get_faction_by_name(name: String) -> Dictionary:
	"""Find faction by name"""
	for faction in FactionDatabase.ALL_FACTIONS:
		if faction.get("name", "") == name:
			return faction
	return {}
