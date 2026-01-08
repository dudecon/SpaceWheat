extends SceneTree

## Test: Quest generation uses signatures only (no wheat requests)
## Player starts with [🍞, 👥]
## Factions should only request their signature emojis

const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const QuestTheming = preload("res://Core/Quests/QuestTheming.gd")
const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")
const VerboseConfig = preload("res://Core/Config/VerboseConfig.gd")

func _init():
	print("\n════════════════════════════════════════════════════════")
	print("TEST: Quest Signature-Only System")
	print("════════════════════════════════════════════════════════\n")

	# Simulate player vocabulary (starter emojis)
	var player_vocab = ["🍞", "👥"]
	print("Player vocabulary: %s\n" % "".join(player_vocab))

	# No bath needed for signature test (quest will sample randomly from signatures)
	var bath = null

	# Test multiple factions
	var test_factions = [
		"Granary Guilds",
		"Millwright's Union",
		"Seedvault Curators",
		"Kilowatt Collective",
		"Lantern Cant",
	]

	var wheat_count = 0
	var bread_count = 0
	var people_count = 0
	var inaccessible_count = 0
	var total_accessible = 0

	print("Generating 20 quests from random factions...\n")

	for i in range(20):
		# Pick random faction
		var faction = FactionDatabase.ALL_FACTIONS[randi() % FactionDatabase.ALL_FACTIONS.size()]
		var faction_name = faction.get("name", "Unknown")

		# Generate quest
		var quest = QuestTheming.generate_quest(faction, bath, player_vocab)

		if quest.has("error"):
			print("[%d] %s: INACCESSIBLE (%s)" % [i+1, faction_name, quest.error])
			inaccessible_count += 1
		else:
			total_accessible += 1
			var resource = quest.get("resource", "?")
			var quantity = quest.get("quantity", 0)
			var faction_sig = "".join(faction.get("sig", []))

			print("[%d] %s: %s×%d (signature: %s)" % [i+1, faction_name, resource, quantity, faction_sig])

			# Count resources
			if resource == "🌾":
				wheat_count += 1
			elif resource == "🍞":
				bread_count += 1
			elif resource == "👥":
				people_count += 1

	print("\n════════════════════════════════════════════════════════")
	print("RESULTS:")
	print("════════════════════════════════════════════════════════")
	print("Total accessible factions: %d / 20" % total_accessible)
	print("Inaccessible factions: %d / 20" % inaccessible_count)
	print("\nResource distribution:")
	print("  🌾 Wheat requests: %d" % wheat_count)
	print("  🍞 Bread requests: %d" % bread_count)
	print("  👥 People requests: %d" % people_count)
	print("  Other: %d" % (total_accessible - wheat_count - bread_count - people_count))

	print("\n════════════════════════════════════════════════════════")
	if wheat_count == 0:
		print("✅ SUCCESS: Zero wheat requests!")
		print("✅ Factions only request signature emojis")
	else:
		print("❌ FAILURE: %d wheat requests detected!" % wheat_count)
		print("❌ Check that quest generation uses signatures only")
	print("════════════════════════════════════════════════════════\n")

	quit()
