@tool
extends SceneTree

## Run this script to generate factions.json from existing GDScript faction definitions
## Usage: godot --headless --script Core/Factions/generate_factions_json.gd

const AllFactions = preload("res://Core/Factions/AllFactions.gd")

func _init():
	print("Generating factions.json from GDScript definitions...")

	var all_factions = AllFactions.get_all()
	print("Found %d factions" % all_factions.size())

	# Convert all factions to dictionaries
	var factions_data: Array = []
	for faction in all_factions:
		var data = faction.to_dict()
		factions_data.append(data)
		print("  - %s (%d emojis)" % [faction.name, faction.signature.size()])

	# Sort by name for consistent ordering
	factions_data.sort_custom(func(a, b): return a["name"] < b["name"])

	# Write to JSON
	var json_path = "res://Core/Factions/data/factions.json"

	# Ensure directory exists
	var dir = DirAccess.open("res://Core/Factions")
	if dir and not dir.dir_exists("data"):
		dir.make_dir("data")

	var file = FileAccess.open(json_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(factions_data, "\t")
		file.store_string(json_string)
		file.close()
		print("\nWritten to: %s" % json_path)
		print("Total size: %d bytes" % json_string.length())
	else:
		push_error("Failed to write to %s" % json_path)

	# Print stats
	print("\n=== Statistics ===")
	var total_emojis: Dictionary = {}
	var contested: int = 0
	for faction_data in factions_data:
		for emoji in faction_data.get("signature", []):
			if not total_emojis.has(emoji):
				total_emojis[emoji] = 0
			total_emojis[emoji] += 1

	for emoji in total_emojis:
		if total_emojis[emoji] > 1:
			contested += 1

	print("Total factions: %d" % factions_data.size())
	print("Total unique emojis: %d" % total_emojis.size())
	print("Contested emojis: %d" % contested)

	quit()
