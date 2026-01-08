#!/usr/bin/env -S godot --headless -s
extends SceneTree

const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const QuestTheming = preload("res://Core/Quests/QuestTheming.gd")
const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")

func _init():
	print("\n🔍 Debugging Quest Generation")

	# Create bath
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄", "💨", "🍂"])

	# Get faction
	var faction = FactionDatabase.MILLWRIGHTS_UNION
	print("\nFaction: %s" % faction.name)
	print("Bits: %s" % str(faction.bits))

	# Generate quest
	print("\nGenerating quest...")
	var quest = QuestTheming.generate_quest(faction, bath)

	print("\nQuest keys: %s" % str(quest.keys()))
	print("\nQuest contents:")
	for key in quest.keys():
		print("  %s: %s" % [key, str(quest[key])])

	quit(0)
