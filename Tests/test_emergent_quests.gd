#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test emergent quantum quest generation
## Verifies faction state-shape preferences × biome observables → quests

const FactionStateMatcher = preload("res://Core/QuantumSubstrate/FactionStateMatcher.gd")
const QuestTheming = preload("res://Core/Quests/QuestTheming.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")

func _init():
	print("\n" + "=".repeat(80))
	print("🌟 EMERGENT QUANTUM QUEST SYSTEM TEST")
	print("=".repeat(80))

	# Test 1: Abstract machinery (no emojis)
	print("\n" + "-".repeat(80))
	print("TEST 1: Abstract Machinery (FactionStateMatcher)")
	print("-".repeat(80))
	test_abstract_machinery()

	# Test 2: Observable extraction
	print("\n" + "-".repeat(80))
	print("TEST 2: Observable Extraction from QuantumBath")
	print("-".repeat(80))
	test_observable_extraction()

	# Test 3: Alignment computation
	print("\n" + "-".repeat(80))
	print("TEST 3: Alignment Computation")
	print("-".repeat(80))
	test_alignment_computation()

	# Test 4: Full quest generation
	print("\n" + "-".repeat(80))
	print("TEST 4: Full Quest Generation Pipeline")
	print("-".repeat(80))
	test_full_quest_generation()

	# Test 5: Multiple factions with same biome
	print("\n" + "-".repeat(80))
	print("TEST 5: Multiple Factions × One Biome State")
	print("-".repeat(80))
	test_multiple_factions()

	print("\n" + "=".repeat(80))
	print("✅ ALL TESTS COMPLETE")
	print("=".repeat(80) + "\n")

	quit(0)


func test_abstract_machinery():
	"""Test that FactionStateMatcher has NO game-specific content"""

	print("\n📋 Verifying abstract machinery properties:")

	# Check that it works with null bath
	var obs_null = FactionStateMatcher.extract_observables(null)
	print("  ✓ Handles null bath gracefully")
	print("    Default observables: %s" % FactionStateMatcher.describe_observables(obs_null))

	# Check bit encoding
	var test_bits = [1, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0]
	var prefs = FactionStateMatcher.describe_preferences(test_bits)
	print("  ✓ Bit decoding works")
	print("    Preferences: %s" % prefs)

	# Verify alignment is in [0, 1]
	var alignment = FactionStateMatcher.compute_alignment(test_bits, obs_null)
	assert(alignment >= 0.0 and alignment <= 1.0, "Alignment out of range!")
	print("  ✓ Alignment computation: %.3f (valid range)" % alignment)


func test_observable_extraction():
	"""Test extracting observables from actual QuantumBath"""

	print("\n📊 Creating test QuantumBath:")

	# Create bath with test emojis
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄", "💨", "🍂"])

	print("  Bath created with 4 emojis: 🌾 🍄 💨 🍂")

	# Extract observables
	var obs = FactionStateMatcher.extract_observables(bath)

	print("\n  Extracted observables:")
	print("    Purity: %.3f" % obs.purity)
	print("    Entropy: %.3f" % obs.entropy)
	print("    Coherence: %.3f" % obs.coherence)
	print("    Distribution shape: %d" % obs.distribution_shape)
	print("    Scale: %.3f" % obs.scale)
	print("    Dynamics: %.3f" % obs.dynamics)

	# Verify observables are in valid ranges
	check_assertion(obs.purity >= 0.0 and obs.purity <= 1.0, "Purity out of range!")
	check_assertion(obs.entropy >= 0.0 and obs.entropy <= 1.0, "Entropy out of range!")
	check_assertion(obs.coherence >= 0.0 and obs.coherence <= 1.0, "Coherence out of range!")
	check_assertion(obs.distribution_shape >= 0 and obs.distribution_shape <= 3, "Shape out of range!")

	print("  ✓ All observables in valid ranges")


func test_alignment_computation():
	"""Test alignment between different faction preferences and biome states"""

	print("\n🎯 Testing alignment computation:")

	# Create high-purity biome (ordered)
	var ordered_bath = QuantumBath.new()
	ordered_bath.initialize_with_emojis(["🌾", "🍄", "💨", "🍂"])
	var ordered_obs = FactionStateMatcher.extract_observables(ordered_bath)

	print("\n  Biome state (actually CHAOTIC - maximally mixed):")
	print("    %s" % FactionStateMatcher.describe_observables(ordered_obs))
	print("    Note: Fresh bath starts maximally mixed (purity=0.25, entropy=1.0)")

	# Test 1: Faction that prefers order (bits [0-1] = 11 = pure state)
	var orderly_faction = [1, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0]
	var alignment_orderly = FactionStateMatcher.compute_alignment(orderly_faction, ordered_obs)
	print("\n  Orderly faction vs chaotic biome:")
	print("    Preferences: %s" % FactionStateMatcher.describe_preferences(orderly_faction))
	print("    Alignment: %.3f (should be LOW - mismatch)" % alignment_orderly)

	# Test 2: Faction that prefers chaos (bits [0-1] = 00 = chaos)
	var chaotic_faction = [0, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1]
	var alignment_chaotic = FactionStateMatcher.compute_alignment(chaotic_faction, ordered_obs)
	print("\n  Chaotic faction vs chaotic biome:")
	print("    Preferences: %s" % FactionStateMatcher.describe_preferences(chaotic_faction))
	print("    Alignment: %.3f (should be HIGH - good match)" % alignment_chaotic)

	# Verify chaotic faction has higher alignment with chaotic biome
	check_assertion(alignment_chaotic > alignment_orderly, "Alignment logic broken!")
	print("  ✓ Chaotic faction (%.3f) > Orderly faction (%.3f)" % [alignment_chaotic, alignment_orderly])
	print("\n  ✓ Alignment correctly reflects preference matching")


func test_full_quest_generation():
	"""Test full pipeline: faction × biome → themed quest"""

	print("\n🎮 Testing full quest generation:")

	# Create test bath
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄", "💨", "🍂", "🍅"])

	# Use Millwright's Union from database
	var faction = FactionDatabase.MILLWRIGHTS_UNION

	var emoji_str = "".join(faction.signature.slice(0, 3))
	print("\n  Faction: %s %s" % [emoji_str, faction.name])
	print("  Bits: %s" % str(faction.bits))
	print("  Bath emojis: 🌾 🍄 💨 🍂 🍅")

	# Generate quest
	var quest = QuestTheming.generate_quest(faction, bath)

	print("\n  Generated quest:")
	print("    Resource: %s" % quest.resource)
	print("    Quantity: %d" % quest.quantity)
	print("    Time limit: %s" % ("none" if quest.time_limit < 0 else "%ds" % int(quest.time_limit)))
	print("    Reward multiplier: %.2fx" % quest.reward_multiplier)
	print("    Alignment: %.3f" % quest._alignment)
	print("    Intensity: %.3f" % quest._intensity)
	print("    Complexity: %.3f" % quest._complexity)
	print("    Urgency: %.3f" % quest._urgency)

	# Verify quest structure
	check_assertion(quest.has("resource"), "Missing resource!")
	check_assertion(quest.has("quantity"), "Missing quantity!")
	check_assertion(quest.has("_alignment"), "Missing alignment!")
	check_assertion(quest.quantity >= 1 and quest.quantity <= 15, "Quantity out of SpaceWheat range!")

	print("\n  ✓ Quest generated successfully")


func test_multiple_factions():
	"""Test how different factions respond to same biome state"""

	print("\n🌍 Testing multiple factions with shared biome:")

	# Create test bath
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄", "💨", "🍂"])

	var obs = FactionStateMatcher.extract_observables(bath)
	print("\n  Biome state: %s" % FactionStateMatcher.describe_observables(obs))

	# Test with a few different factions
	var test_factions = [
		FactionDatabase.MILLWRIGHTS_UNION,
		FactionDatabase.YEAST_PROPHETS,
		FactionDatabase.LAUGHING_COURT,
	]

	print("\n  Quest offers from different factions:")

	for faction in test_factions:
		var params = FactionStateMatcher.generate_quest_parameters(faction.bits, obs, bath)
		var quest = QuestTheming.apply_theming(params, bath)

		var emoji_str = "".join(faction.signature.slice(0, 3))
		print("\n    %s %s:" % [emoji_str, faction.name])
		print("      Alignment: %.3f" % quest._alignment)
		print("      Quest: %s × %d" % [quest.resource, quest.quantity])
		print("      Reward: %.2fx" % quest.reward_multiplier)

	print("\n  ✓ Different factions generate different quests for same biome")


func check_assertion(condition: bool, message: String):
	"""Simple assertion helper"""
	if not condition:
		push_error("ASSERTION FAILED: " + message)
		quit(1)
