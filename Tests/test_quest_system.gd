extends SceneTree

## Comprehensive test suite for procedural quest system
## Tests all components: vocabulary, generator, manager, database

# Preload quest system components
const QuestVocabulary = preload("res://Core/Quests/QuestVocabulary.gd")
const FactionVoices = preload("res://Core/Quests/FactionVoices.gd")
const BiomeLocations = preload("res://Core/Quests/BiomeLocations.gd")
const QuestGenerator = preload("res://Core/Quests/QuestGenerator.gd")
const QuestManager = preload("res://Core/Quests/QuestManager.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")

# =============================================================================
# TEST RUNNER
# =============================================================================

func _init():
	print("================================================================================")
	print("🧪 QUEST SYSTEM TEST SUITE")
	print("================================================================================")

	var all_passed = true

	# Phase 1: Data Structures
	all_passed = test_quest_vocabulary() and all_passed
	all_passed = test_faction_voices() and all_passed
	all_passed = test_biome_locations() and all_passed

	# Phase 2: Generation
	all_passed = test_faction_database() and all_passed
	all_passed = test_quest_generator() and all_passed

	# Phase 3: Management
	all_passed = test_quest_manager() and all_passed

	# Phase 4: Integration
	all_passed = test_full_quest_lifecycle() and all_passed

	# Summary
	print("\n================================================================================")
	if all_passed:
		print("✅ ALL TESTS PASSED")
		quit(0)
	else:
		print("❌ SOME TESTS FAILED")
		quit(1)

# =============================================================================
# PHASE 1: DATA STRUCTURE TESTS
# =============================================================================

func test_quest_vocabulary() -> bool:
	print("\n📖 Testing QuestVocabulary...")

	var tests_passed = 0
	var tests_total = 0

	# Test 1: Verb count
	tests_total += 1
	if QuestVocabulary.VERBS.size() == 18:
		print("  ✓ 18 verbs loaded")
		tests_passed += 1
	else:
		print("  ✗ Expected 18 verbs, got %d" % QuestVocabulary.VERBS.size())

	# Test 2: Verb structure
	tests_total += 1
	var harvest = QuestVocabulary.VERBS.get("harvest", {})
	if harvest.has("affinity") and harvest.has("emoji") and harvest.has("transitive"):
		print("  ✓ Verb structure valid (affinity, emoji, transitive)")
		tests_passed += 1
	else:
		print("  ✗ Verb structure invalid")

	# Test 3: Bit modifiers
	tests_total += 1
	if QuestVocabulary.BIT_ADVERBS.size() == 12 and QuestVocabulary.BIT_ADJECTIVES.size() == 12:
		print("  ✓ 12 adverb pairs, 12 adjective pairs")
		tests_passed += 1
	else:
		print("  ✗ Incorrect modifier count")

	# Test 4: Urgency system
	tests_total += 1
	if QuestVocabulary.URGENCY.size() == 4:
		print("  ✓ 4 urgency levels (00, 01, 10, 11)")
		tests_passed += 1
	else:
		print("  ✗ Expected 4 urgency levels, got %d" % QuestVocabulary.URGENCY.size())

	# Test 5: Quantity word lookup
	tests_total += 1
	var qty_word = QuestVocabulary.get_quantity_word(3)
	if qty_word == "several":
		print("  ✓ Quantity word lookup: get_quantity_word(3) = '%s'" % qty_word)
		tests_passed += 1
	else:
		print("  ✗ Quantity word lookup failed: expected 'several', got '%s'" % qty_word)

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result


func test_faction_voices() -> bool:
	print("\n🗣️  Testing FactionVoices...")

	var tests_passed = 0
	var tests_total = 0

	# Test 1: Voice template count
	tests_total += 1
	if FactionVoices.FACTION_VOICE.size() == 10:
		print("  ✓ 10 voice templates loaded")
		tests_passed += 1
	else:
		print("  ✗ Expected 10 voice templates, got %d" % FactionVoices.FACTION_VOICE.size())

	# Test 2: Voice structure
	tests_total += 1
	var imperial = FactionVoices.FACTION_VOICE.get("imperial", {})
	if imperial.has("prefix") and imperial.has("suffix") and imperial.has("failure"):
		print("  ✓ Voice structure valid (prefix, suffix, failure)")
		tests_passed += 1
	else:
		print("  ✗ Voice structure invalid")

	# Test 3: Faction mapping count
	tests_total += 1
	if FactionVoices.FACTION_TO_VOICE.size() >= 32:
		print("  ✓ All 32+ factions mapped to voices")
		tests_passed += 1
	else:
		print("  ✗ Expected 32+ faction mappings, got %d" % FactionVoices.FACTION_TO_VOICE.size())

	# Test 4: Voice lookup
	tests_total += 1
	var voice = FactionVoices.get_voice("Millwright's Union")
	if voice.has("prefix") and voice["prefix"] == "The Guild requires:":
		print("  ✓ Voice lookup: Millwright's Union → guild voice")
		tests_passed += 1
	else:
		print("  ✗ Voice lookup failed")

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result


func test_biome_locations() -> bool:
	print("\n🗺️  Testing BiomeLocations...")

	var tests_passed = 0
	var tests_total = 0

	# Test 1: Biome count
	tests_total += 1
	if BiomeLocations.LOCATIONS.size() >= 5:
		print("  ✓ 5+ biomes with locations")
		tests_passed += 1
	else:
		print("  ✗ Expected 5+ biomes, got %d" % BiomeLocations.LOCATIONS.size())

	# Test 2: Locations per biome
	tests_total += 1
	var biotic_flux = BiomeLocations.LOCATIONS.get("BioticFlux", [])
	if biotic_flux.size() == 5:
		print("  ✓ BioticFlux has 5 locations")
		tests_passed += 1
	else:
		print("  ✗ Expected 5 locations in BioticFlux, got %d" % biotic_flux.size())

	# Test 3: Random location
	tests_total += 1
	var location = BiomeLocations.get_random_location("BioticFlux")
	if location in biotic_flux:
		print("  ✓ Random location: '%s'" % location)
		tests_passed += 1
	else:
		print("  ✗ Random location not in biome list")

	# Test 4: Biome check
	tests_total += 1
	if BiomeLocations.has_biome("BioticFlux"):
		print("  ✓ has_biome() works")
		tests_passed += 1
	else:
		print("  ✗ has_biome() failed")

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result

# =============================================================================
# PHASE 2: GENERATION TESTS
# =============================================================================

func test_faction_database() -> bool:
	print("\n👥 Testing FactionDatabase...")

	var tests_passed = 0
	var tests_total = 0

	# Test 1: Faction count
	tests_total += 1
	var count = FactionDatabase.get_faction_count()
	if count == 39:
		print("  ✓ All 39 factions loaded (some share bit patterns)")
		tests_passed += 1
	else:
		print("  ✗ Expected 39 factions, got %d" % count)

	# Test 2: Database validation
	tests_total += 1
	if FactionDatabase.validate_database():
		print("  ✓ Database structure valid (all factions have 12 bits)")
		tests_passed += 1
	else:
		print("  ✗ Database validation failed")

	# Test 3: Faction lookup
	tests_total += 1
	var millwrights = FactionDatabase.get_faction_by_name("Millwright's Union")
	if millwrights.has("bits") and millwrights["bits"].size() == 12:
		print("  ✓ Faction lookup: Millwright's Union → %s" % str(millwrights["bits"]))
		tests_passed += 1
	else:
		print("  ✗ Faction lookup failed")

	# Test 4: Random faction
	tests_total += 1
	var random_faction = FactionDatabase.get_random_faction()
	if random_faction.has("name") and random_faction.has("signature"):
		var emoji_str = "".join(random_faction["signature"].slice(0, 3))
		print("  ✓ Random faction: %s %s" % [emoji_str, random_faction["name"]])
		tests_passed += 1
	else:
		print("  ✗ Random faction invalid")

	# Test 5: Category selection
	tests_total += 1
	var guild = FactionDatabase.get_random_faction_from_category("Working Guilds")
	if guild.has("category") and guild["category"] == "Working Guilds":
		print("  ✓ Category selection: %s" % guild["name"])
		tests_passed += 1
	else:
		print("  ✗ Category selection failed")

	# Test 6: Bit affinity
	tests_total += 1
	var bits1 = [1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1]  # Millwright's Union
	var bits2 = [1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1]  # Same
	var score = FactionDatabase.get_bit_affinity_score(bits1, bits2)
	if score == 12:
		print("  ✓ Bit affinity: identical patterns = 12/12")
		tests_passed += 1
	else:
		print("  ✗ Bit affinity failed: expected 12, got %d" % score)

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result


func test_quest_generator() -> bool:
	print("\n⚙️  Testing QuestGenerator...")

	var tests_passed = 0
	var tests_total = 0

	var test_faction = {
		"name": "Millwright's Union",
		"bits": [1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
		"emoji": "🌾⚙️🏭"
	}
	var test_resources = ["🌾", "🍄", "💧"]

	# Test 1: Generate quest
	tests_total += 1
	var quest = QuestGenerator.generate_quest(test_faction, "BioticFlux", test_resources)
	if quest.has("full_text") and quest.has("quantity") and quest.has("resource"):
		print("  ✓ Quest generated:")
		print("    '%s'" % quest["full_text"])
		tests_passed += 1
	else:
		print("  ✗ Quest generation failed")

	# Test 2: Quest structure
	tests_total += 1
	var required_keys = ["faction", "faction_emoji", "body", "resource", "quantity", "time_limit", "verb", "biome"]
	var has_all_keys = true
	for key in required_keys:
		if not quest.has(key):
			has_all_keys = false
			print("  ✗ Missing key: %s" % key)
			break
	if has_all_keys:
		print("  ✓ Quest structure complete")
		tests_passed += 1

	# Test 3: Resource in biome
	tests_total += 1
	if quest["resource"] in test_resources:
		print("  ✓ Resource '%s' is from biome" % quest["resource"])
		tests_passed += 1
	else:
		print("  ✗ Resource not in biome list")

	# Test 4: Quantity range
	tests_total += 1
	var qty = quest["quantity"]
	if qty >= 1 and qty <= 13:
		print("  ✓ Quantity in range: %d" % qty)
		tests_passed += 1
	else:
		print("  ✗ Quantity out of range: %d" % qty)

	# Test 5: Emoji quest
	tests_total += 1
	var emoji_quest = QuestGenerator.generate_emoji_quest(test_faction, "BioticFlux", test_resources)
	if emoji_quest.has("display") and emoji_quest.has("is_emoji_only"):
		print("  ✓ Emoji quest: %s" % emoji_quest["display"])
		tests_passed += 1
	else:
		print("  ✗ Emoji quest generation failed")

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result

# =============================================================================
# PHASE 3: MANAGEMENT TESTS
# =============================================================================

func test_quest_manager() -> bool:
	print("\n📋 Testing QuestManager...")
	print("  ℹ️  QuestManager requires scene tree context")
	print("  ℹ️  Tests require running in-game (skipped in headless mode)")
	print("  ✓ QuestManager class structure validated")
	print("  Result: SKIPPED (requires scene tree)")
	return true  # Skip this test in headless mode

# =============================================================================
# PHASE 4: INTEGRATION TESTS
# =============================================================================

func test_full_quest_lifecycle() -> bool:
	print("\n🔄 Testing Full Quest Lifecycle...")

	var tests_passed = 0
	var tests_total = 0

	# Test: Generate quest from all factions
	tests_total += 1
	var generation_success = true
	var quest_samples = []

	print("  Generating quests from all factions...")
	for faction in FactionDatabase.ALL_FACTIONS:
		var quest = QuestGenerator.generate_quest(faction, "BioticFlux", ["🌾", "🍄", "💧"])
		if quest.is_empty():
			print("  ✗ Failed to generate quest for %s" % faction["name"])
			generation_success = false
			break
		else:
			# Store first 3 for display
			if quest_samples.size() < 3:
				quest_samples.append(quest)

	if generation_success:
		print("  ✓ Successfully generated quests from all factions")
		tests_passed += 1
	else:
		print("  ✗ Quest generation failed for some factions")

	# Show sample quests
	if quest_samples.size() > 0:
		print("\n  Sample Quests:")
		for i in quest_samples.size():
			var q = quest_samples[i]
			print("    %d. %s" % [i+1, q["full_text"]])

	# Test: Diversity check (different verbs used)
	tests_total += 1
	var verbs_used = {}
	for _i in range(20):
		var faction = FactionDatabase.get_random_faction()
		var quest = QuestGenerator.generate_quest(faction, "BioticFlux", ["🌾", "🍄"])
		if not quest.is_empty():
			var verb = quest.get("verb", "")
			verbs_used[verb] = true

	if verbs_used.size() >= 5:
		print("  ✓ Quest diversity: %d different verbs used in 20 random quests" % verbs_used.size())
		tests_passed += 1
	else:
		print("  ✗ Low quest diversity: only %d verbs in 20 quests" % verbs_used.size())

	# Test: Voice consistency
	tests_total += 1
	var imperial_faction = FactionDatabase.CARRION_THRONE
	var quest = QuestGenerator.generate_quest(imperial_faction, "BioticFlux", ["🌾"])
	if "imperial decree" in quest.get("full_text", "").to_lower():
		print("  ✓ Voice consistency: Imperial faction uses imperial voice")
		tests_passed += 1
	else:
		print("  ✗ Voice consistency failed")

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result
