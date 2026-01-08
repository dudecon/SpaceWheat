#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test vocabulary-based quest generation
## Verifies that quests only use emojis from faction vocabulary ∩ player vocabulary

const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const QuestTheming = preload("res://Core/Quests/QuestTheming.gd")
const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")

var tests_passed = 0
var tests_total = 0

func _init():
	print("\n" + "=".repeat(80))
	print("🔬 VOCABULARY-BASED QUEST GENERATION TEST")
	print("=".repeat(80))

	test_faction_vocabulary_computation()
	test_vocabulary_overlap()
	test_starter_emojis()
	test_quest_with_limited_vocabulary()
	test_quest_with_full_vocabulary()
	test_inaccessible_faction()
	test_vocabulary_discovery_progression()

	print("\n" + "=".repeat(80))
	if tests_passed == tests_total:
		print("✅ ALL TESTS PASSED (%d/%d)" % [tests_passed, tests_total])
	else:
		print("❌ SOME TESTS FAILED (%d/%d passed)" % [tests_passed, tests_total])
	print("=".repeat(80))

	quit(0 if tests_passed == tests_total else 1)


func test_faction_vocabulary_computation():
	print("\n📋 TEST 1: Faction Vocabulary Computation")
	tests_total += 1

	var faction = FactionDatabase.MILLWRIGHTS_UNION
	var vocab = FactionDatabase.get_faction_vocabulary(faction)

	print("  Faction: %s" % faction.name)
	print("  Bits: %s" % str(faction.bits))
	print("  Axial emojis: %s" % str(vocab.axial))
	print("  Signature emojis: %s" % str(vocab.signature))
	print("  Total vocabulary: %s" % str(vocab.all))

	# Check that axial emojis are computed (12 bits → 12 emojis)
	if vocab.axial.size() != 12:
		print("  ❌ Expected 12 axial emojis, got %d" % vocab.axial.size())
		return

	# Check that signature is included
	if vocab.signature.is_empty():
		print("  ❌ Signature should not be empty")
		return

	# Check that all vocabulary is present
	if vocab.all.size() < vocab.axial.size():
		print("  ❌ Total vocabulary should include all axial emojis")
		return

	print("  ✓ Vocabulary computed correctly")
	tests_passed += 1


func test_vocabulary_overlap():
	print("\n📋 TEST 2: Vocabulary Overlap")
	tests_total += 1

	var faction = FactionDatabase.MILLWRIGHTS_UNION
	var vocab = FactionDatabase.get_faction_vocabulary(faction)

	# Test with starter emojis only
	var player_vocab = ["🌾", "🍄"]
	var overlap = FactionDatabase.get_vocabulary_overlap(vocab.all, player_vocab)

	print("  Player vocabulary: %s" % str(player_vocab))
	print("  Faction vocabulary: %s emojis" % vocab.all.size())
	print("  Overlap: %s" % str(overlap))

	if overlap.is_empty():
		print("  ❌ Expected overlap with starter emojis")
		return

	# Verify overlap only contains emojis in BOTH sets
	for emoji in overlap:
		if emoji not in player_vocab or emoji not in vocab.all:
			print("  ❌ Overlap contains emoji not in both sets: %s" % emoji)
			return

	print("  ✓ Overlap computed correctly")
	tests_passed += 1


func test_starter_emojis():
	print("\n📋 TEST 3: Starter Emoji Magic (🌾 and 🍄)")
	tests_total += 1

	# 🌾 is on axis bit[2]=0 (Common)
	# 🍄 is on axis bit[10]=0 (Emergent)

	var starter_vocab = ["🌾", "🍄"]
	var accessible_count = 0

	for faction in FactionDatabase.ALL_FACTIONS:
		var vocab = FactionDatabase.get_faction_vocabulary(faction)
		var overlap = FactionDatabase.get_vocabulary_overlap(vocab.all, starter_vocab)

		if not overlap.is_empty():
			accessible_count += 1

	var pct = float(accessible_count) / FactionDatabase.ALL_FACTIONS.size() * 100

	print("  Starter vocabulary: %s" % str(starter_vocab))
	print("  Accessible factions: %d/%d (%.1f%%)" % [accessible_count, FactionDatabase.ALL_FACTIONS.size(), pct])

	# Should be roughly 50% accessible (factions with Common OR Emergent bits)
	if accessible_count < 20:  # At least 20 out of 64
		print("  ❌ Expected more factions accessible with starter emojis")
		return

	print("  ✓ Starter emojis unlock ~50%% of factions")
	tests_passed += 1


func test_quest_with_limited_vocabulary():
	print("\n📋 TEST 4: Quest Generation with Limited Vocabulary")
	tests_total += 1

	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄", "💨", "🍂", "⚙"])

	var faction = FactionDatabase.MILLWRIGHTS_UNION
	var player_vocab = ["🌾", "🍄"]  # Only starter emojis!

	var quest = QuestTheming.generate_quest(faction, bath, player_vocab)

	print("  Player vocabulary: %s" % str(player_vocab))
	print("  Available emojis: %s" % str(quest.get("available_emojis", [])))

	if quest.has("error"):
		print("  ❌ Quest should be accessible (faction has wheat/mushroom)")
		print("     Error: %s" % quest.message)
		return

	var resource = quest.get("resource", "")
	print("  Quest resource: %s" % resource)

	if resource not in player_vocab:
		print("  ❌ Quest resource '%s' not in player vocabulary!" % resource)
		return

	print("  ✓ Quest resource constrained to player vocabulary")
	tests_passed += 1


func test_quest_with_full_vocabulary():
	print("\n📋 TEST 5: Quest Generation with Full Vocabulary")
	tests_total += 1

	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄", "💨", "🍂", "⚙", "🏭"])

	var faction = FactionDatabase.MILLWRIGHTS_UNION
	var vocab = FactionDatabase.get_faction_vocabulary(faction)

	# Player knows EVERYTHING the faction cares about
	var player_vocab = vocab.all.duplicate()

	var quest = QuestTheming.generate_quest(faction, bath, player_vocab)

	print("  Player vocabulary: %d emojis (full faction vocabulary)" % player_vocab.size())
	print("  Available emojis: %d emojis" % quest.get("available_emojis", []).size())

	if quest.has("error"):
		print("  ❌ Quest should be accessible with full vocabulary")
		return

	var overlap_pct = quest.get("vocabulary_overlap_pct", 0.0)
	print("  Vocabulary overlap: %.1f%%" % (overlap_pct * 100))

	if overlap_pct < 0.99:
		print("  ❌ Expected 100%% overlap with full vocabulary")
		return

	print("  ✓ Full vocabulary enables maximum quest variety")
	tests_passed += 1


func test_inaccessible_faction():
	print("\n📋 TEST 6: Inaccessible Faction (No Overlap)")
	tests_total += 1

	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄"])

	# Find a faction that doesn't have wheat or mushroom
	var inaccessible_faction = null
	for faction in FactionDatabase.ALL_FACTIONS:
		var vocab = FactionDatabase.get_faction_vocabulary(faction)
		var overlap = FactionDatabase.get_vocabulary_overlap(vocab.all, ["🌾", "🍄"])

		if overlap.is_empty():
			inaccessible_faction = faction
			break

	if inaccessible_faction == null:
		print("  ⚠️  All factions accessible with starter emojis (skipping test)")
		tests_total -= 1
		return

	var quest = QuestTheming.generate_quest(inaccessible_faction, bath, ["🌾", "🍄"])

	print("  Faction: %s" % inaccessible_faction.name)
	print("  Player vocabulary: [🌾, 🍄]")

	if not quest.has("error"):
		print("  ❌ Expected error for inaccessible faction")
		return

	print("  Error message: %s" % quest.message)
	print("  Required emojis: %s" % str(quest.get("required_emojis", [])))

	if quest.error != "no_vocabulary_overlap":
		print("  ❌ Expected 'no_vocabulary_overlap' error")
		return

	print("  ✓ Inaccessible faction returns error correctly")
	tests_passed += 1


func test_vocabulary_discovery_progression():
	print("\n📋 TEST 7: Vocabulary Discovery Progression")
	tests_total += 1

	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄", "💨", "⚙", "🏭"])

	var faction = FactionDatabase.MILLWRIGHTS_UNION
	var vocab = FactionDatabase.get_faction_vocabulary(faction)

	# Stage 1: Starter emojis only
	var player_vocab_stage1 = ["🌾", "🍄"]
	var quest1 = QuestTheming.generate_quest(faction, bath, player_vocab_stage1)
	var avail1 = quest1.get("available_emojis", []).size()

	# Stage 2: Discover mechanical emoji
	var player_vocab_stage2 = ["🌾", "🍄", "⚙"]
	var quest2 = QuestTheming.generate_quest(faction, bath, player_vocab_stage2)
	var avail2 = quest2.get("available_emojis", []).size()

	# Stage 3: Discover factory emoji
	var player_vocab_stage3 = ["🌾", "🍄", "⚙", "🏭"]
	var quest3 = QuestTheming.generate_quest(faction, bath, player_vocab_stage3)
	var avail3 = quest3.get("available_emojis", []).size()

	print("  Stage 1 (starters): %d available emojis" % avail1)
	print("  Stage 2 (+⚙): %d available emojis" % avail2)
	print("  Stage 3 (+🏭): %d available emojis" % avail3)

	if avail1 >= avail2 or avail2 >= avail3:
		print("  ❌ Expected vocabulary to expand with discovery")
		return

	print("  ✓ Vocabulary expands as player discovers new emojis")
	tests_passed += 1
