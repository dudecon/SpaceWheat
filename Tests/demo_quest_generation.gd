extends SceneTree

## Interactive quest generation demo
## Shows quests from different faction categories

const QuestGenerator = preload("res://Core/Quests/QuestGenerator.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")

func _init():
	print("================================================================================")
	print("🎲 QUEST GENERATION DEMO - 32-Faction System")
	print("================================================================================")

	var biome_resources = {
		"BioticFlux": ["🌾", "🍄", "💧", "☀️", "🌑"],
		"Kitchen": ["🔥", "❄️", "🍞", "🧪", "⚙️"],
		"Forest": ["💧", "🐺", "🦅", "🐰", "🌲"],
		"Market": ["💰", "📈", "🐂", "🐻", "🏦"],
		"GranaryGuilds": ["🌾", "💨", "🍞", "💧", "⚖️"]
	}

	print("\n📊 Generating quests from each faction category...\n")

	# Test each category
	var category_dict = FactionDatabase.get_category_dict()
	for category in category_dict.keys():
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("🏛️  %s" % category)
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

		var factions = category_dict[category]
		var faction = factions[0]  # Get first faction from category

		# Generate text quest
		var quest = QuestGenerator.generate_quest(
			faction,
			"BioticFlux",
			biome_resources["BioticFlux"]
		)

		# Generate emoji quest
		var emoji_quest = QuestGenerator.generate_emoji_quest(
			faction,
			"BioticFlux",
			biome_resources["BioticFlux"]
		)

		var emoji_str = "".join(faction["signature"].slice(0, 3))
		print("%s %s" % [emoji_str, faction["name"]])
		print("Bits: %s" % str(faction["bits"]))
		print("")
		print("📜 Text Quest:")
		print("  %s" % quest["full_text"])
		print("")
		print("🎨 Emoji Quest:")
		print("  %s" % emoji_quest["display"])
		print("")
		print("⚙️  Details:")
		print("  Verb: %s" % quest["verb"])
		print("  Resource: %s × %d" % [quest["resource"], quest["quantity"]])
		print("  Location: %s" % quest["location"])
		print("  Time Limit: %s" % ("∞" if quest["time_limit"] < 0 else "%ds" % quest["time_limit"]))
		print("")

	print("================================================================================")
	print("\n🎯 Testing Quest Variety Across Biomes...\n")

	var millwrights = FactionDatabase.MILLWRIGHTS_UNION

	for biome in biome_resources.keys():
		var quest = QuestGenerator.generate_quest(
			millwrights,
			biome,
			biome_resources[biome]
		)
		print("🌍 %s: %s" % [biome, quest["body"]])

	print("\n================================================================================")
	print("\n🔀 Testing Bit Affinity - Similar Factions...\n")

	# Find factions with similar bit patterns
	var test_faction = FactionDatabase.MILLWRIGHTS_UNION
	var similar = FactionDatabase.find_similar_factions(test_faction, 8)

	var ref_emoji = "".join(test_faction["signature"].slice(0, 3))
	print("Reference: %s %s" % [ref_emoji, test_faction["name"]])
	print("Bits: %s\n" % str(test_faction["bits"]))

	if similar.size() > 0:
		print("Similar factions (≥8 matching bits):")
		for entry in similar:
			var f = entry["faction"]
			var score = entry["similarity"]
			var f_emoji = "".join(f["signature"].slice(0, 3))
			print("  %s %s - %d/12 match" % [f_emoji, f["name"], score])

			# Generate quest to show similar but unique flavor
			var quest = QuestGenerator.generate_quest(f, "BioticFlux", biome_resources["BioticFlux"])
			print("    → %s" % quest["body"])
	else:
		print("No factions with ≥8 matching bits (Millwright's Union is unique!)")

	print("\n================================================================================")
	print("\n🎲 Random Quest Showcase (10 random factions)...\n")

	for i in range(10):
		var faction = FactionDatabase.get_random_faction()
		var biome = biome_resources.keys()[randi() % biome_resources.size()]
		var quest = QuestGenerator.generate_quest(
			faction,
			biome,
			biome_resources[biome]
		)
		var emoji_quest = QuestGenerator.generate_emoji_quest(
			faction,
			biome,
			biome_resources[biome]
		)

		var emoji_str = "".join(faction["signature"].slice(0, 3))
		print("%d. %s %s" % [i+1, emoji_str, faction["name"]])
		print("   Text: %s" % quest["full_text"])
		print("   Emoji: %s" % emoji_quest["display"])
		print("")

	print("================================================================================")
	print("✅ Quest Generation Demo Complete")
	print("================================================================================")

	quit(0)
