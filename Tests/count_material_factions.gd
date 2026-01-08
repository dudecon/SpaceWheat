#!/usr/bin/env -S godot --headless -s
extends SceneTree

const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")

func _init():
	var material_count = 0
	var mystical_count = 0

	print("\nFactions with bit[1]=0 (Material):")
	for faction in FactionDatabase.ALL_FACTIONS:
		if faction.bits[1] == 0:
			material_count += 1
			var emoji_str = "".join(faction.signature.slice(0, 3))
			print("  - %s %s" % [emoji_str, faction.name])
		else:
			mystical_count += 1

	var total_count = FactionDatabase.ALL_FACTIONS.size()
	print("\n" + "=".repeat(60))
	print("Total: %d Material (%.1f%%), %d Mystical (%.1f%%)" % [
		material_count,
		100.0 * material_count / total_count,
		mystical_count,
		100.0 * mystical_count / total_count
	])
	print("=".repeat(60))

	quit(0)
