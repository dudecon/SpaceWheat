#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Demo: Vocabulary Discovery Progression
## Shows how discovering emojis unlocks factions and expands quest variety

const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const QuestTheming = preload("res://Core/Quests/QuestTheming.gd")
const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")

func _init():
	print("\n" + "=".repeat(80))
	print("🎮 VOCABULARY DISCOVERY PROGRESSION DEMO")
	print("=".repeat(80))

	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄", "💨", "🍂", "⚙", "🏭", "🔩", "🛠"])

	# Get Millwright's Union for demo
	var faction = FactionDatabase.MILLWRIGHTS_UNION
	var vocab = FactionDatabase.get_faction_vocabulary(faction)

	print("\n⚙🏭🔩 Millwright's Union")
	print("  Description: Grain processors who know cosmic rhythms through mill vibrations")
	print("  Axial vocabulary: %s" % str(vocab.axial))
	print("  Signature vocabulary: %s" % str(vocab.signature))
	print("  Total vocabulary: %d emojis" % vocab.all.size())

	print("\n" + "━".repeat(80))
	print("STAGE 1: Tutorial (Starter Emojis Only)")
	print("━".repeat(80))

	var stage1_vocab = ["🌾", "🍄"]
	show_stage(faction, bath, stage1_vocab, "New player, just started farming")

	print("\n" + "━".repeat(80))
	print("STAGE 2: Discovered Mechanical Parts (+⚙)")
	print("━".repeat(80))

	var stage2_vocab = ["🌾", "🍄", "⚙"]
	show_stage(faction, bath, stage2_vocab, "Found a gear emoji while exploring")

	print("\n" + "━".repeat(80))
	print("STAGE 3: Unlocked Factory (+🏭)")
	print("━".repeat(80))

	var stage3_vocab = ["🌾", "🍄", "⚙", "🏭"]
	show_stage(faction, bath, stage3_vocab, "Built a mill structure")

	print("\n" + "━".repeat(80))
	print("STAGE 4: Full Mill Vocabulary (+🔩, 🛠)")
	print("━".repeat(80))

	var stage4_vocab = ["🌾", "🍄", "⚙", "🏭", "🔩", "🛠"]
	show_stage(faction, bath, stage4_vocab, "Mastered milling mechanics")

	# Show faction unlock counts
	print("\n" + "━".repeat(80))
	print("FACTION UNLOCK PROGRESSION")
	print("━".repeat(80))

	var stages = [
		["🌾", "🍄"],
		["🌾", "🍄", "⚙"],
		["🌾", "🍄", "⚙", "🏭"],
		["🌾", "🍄", "⚙", "🏭", "🔩", "🛠", "💨", "🍂"]
	]

	for i in range(stages.size()):
		var player_vocab = stages[i]
		var accessible = count_accessible_factions(player_vocab)
		var pct = float(accessible) / FactionDatabase.ALL_FACTIONS.size() * 100

		print("  Stage %d (%d emojis): %d/%d factions (%.1f%%)" % [
			i + 1,
			player_vocab.size(),
			accessible,
			FactionDatabase.ALL_FACTIONS.size(),
			pct
		])

	print("\n" + "=".repeat(80))
	print("✨ Vocabulary discovery creates natural progression!")
	print("=".repeat(80))

	quit(0)


func show_stage(faction: Dictionary, bath, player_vocab: Array, context: String):
	"""Show quest generation for a specific vocabulary stage"""

	print("\n📖 Player Vocabulary: %s" % str(player_vocab))
	print("   Context: %s" % context)

	# Generate quest
	var quest = QuestTheming.generate_quest(faction, bath, player_vocab)

	if quest.has("error"):
		print("\n   🔒 FACTION INACCESSIBLE")
		print("      Error: %s" % quest.message)
		print("      Required: %s" % str(quest.get("required_emojis", [])))
		return

	var available = quest.get("available_emojis", [])
	var overlap_pct = quest.get("vocabulary_overlap_pct", 0.0)

	print("\n   Available emojis: %s (%d/%d)" % [str(available), available.size(), 20])
	print("   Vocabulary overlap: %.1f%%" % (overlap_pct * 100))

	# Show 3 sample quests
	print("\n   Sample Quests:")
	for i in range(3):
		var sample_quest = QuestTheming.generate_quest(faction, bath, player_vocab)
		if not sample_quest.has("error"):
			var resource = sample_quest.get("resource", "?")
			var quantity = sample_quest.get("quantity", 0)
			var time = sample_quest.get("time_limit", -1)
			var time_str = ("∞" if time < 0 else "%ds" % int(time))

			print("   %d. Deliver %d %s (time: %s)" % [i + 1, quantity, resource, time_str])


func count_accessible_factions(player_vocab: Array) -> int:
	"""Count how many factions have vocabulary overlap"""
	var count = 0

	for faction in FactionDatabase.ALL_FACTIONS:
		var vocab = FactionDatabase.get_faction_vocabulary(faction)
		var overlap = FactionDatabase.get_vocabulary_overlap(vocab.all, player_vocab)

		if not overlap.is_empty():
			count += 1

	return count
