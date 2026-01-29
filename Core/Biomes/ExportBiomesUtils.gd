## Standalone utility for exporting biome definitions
## This script is NOT part of the game - it's for analysis only
## Usage: Call from debug console or a test scene

extends Node

## Generate complete biome exports (includes all faction contributions)
static func generate_all_exports() -> void:
	print("\n🌍 BIOME EXPORTER: Generating complete biome definitions...\n")

	var exporter = preload("res://Core/Biomes/BiomeExporter.gd").new()

	# Export as JSON (machine-readable)
	var json_path = "res://exports/biomes_complete.json"
	exporter.export_all_biomes_to_file(json_path)

	# Export as text (human-readable)
	var text_path = "res://exports/biomes_complete.txt"
	exporter.export_all_biomes_as_text_file(text_path)

	# Analyze coverage and factions
	exporter.analyze_emoji_coverage()
	exporter.analyze_faction_roster()

	print("✅ Exports complete!")
	print("   JSON: %s" % json_path)
	print("   Text: %s" % text_path)


## Export specific biome (with optional faction standings)
static func export_biome_with_standings(biome_name: String, standings: Dictionary) -> void:
	var exporter = preload("res://Core/Biomes/BiomeExporter.gd").new()

	# Example standings
	var data = exporter.export_biome(biome_name, standings)

	print("\n🌍 BIOME: %s\n" % biome_name)
	print(JSON.stringify(data))


## Print single biome in readable format
static func print_biome(biome_name: String) -> void:
	var exporter = preload("res://Core/Biomes/BiomeExporter.gd").new()
	var text = exporter.export_biome_as_text(biome_name)
	print("\n" + text)
