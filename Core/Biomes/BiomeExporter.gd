class_name BiomeExporter
extends RefCounted

## BiomeExporter: Generate complete icon definitions for biomes
##
## For each biome:
##   1. Get all emojis in the biome
##   2. Build Icon objects (biome component + faction contributions)
##   3. Export to JSON format for analysis
##
## Usage:
##   var exporter = BiomeExporter.new()
##   var biome_data = exporter.export_biome("Village")
##   exporter.export_all_biomes_to_file("res://exports/biomes_complete.json")

const BiomeRegistry = preload("res://Core/Biomes/BiomeRegistry.gd")
const FactionRegistry = preload("res://Core/Factions/FactionRegistry.gd")
const IconBuilder = preload("res://Core/Factions/IconBuilder.gd")
const Icon = preload("res://Core/QuantumSubstrate/Icon.gd")


## ========================================
## Export Single Biome
## ========================================

## Export complete icon definitions for a single biome
func export_biome(biome_name: String, faction_standings: Dictionary = {}) -> Dictionary:
	## Args:
	##   biome_name: Name of biome to export
	##   faction_standings: {faction_name: standing} (optional, defaults to 1.0)
	##
	## Returns:
	##   {
	##     "name": "BiomeName",
	##     "emojis": [...],
	##     "icons": {emoji: icon_data}
	##   }

	var biome_registry = BiomeRegistry.new()
	var biome = biome_registry.get_by_name(biome_name)
	if not biome:
		push_error("BiomeExporter: Biome not found: %s" % biome_name)
		return {}

	# Build complete icons for this biome
	var icons = IconBuilder.build_biome_with_factions(biome_name, faction_standings)

	# Export each icon to data format
	var icons_data: Dictionary = {}
	for emoji in icons:
		var icon = icons[emoji]
		icons_data[emoji] = _serialize_icon(icon)

	return {
		"name": biome_name,
		"emojis": biome.get_all_emojis(),
		"discovered": biome.discovered,
		"tags": biome.tags,
		"icons": icons_data
	}


## ========================================
## Export All Biomes
## ========================================

## Export all biomes to a single dictionary
func export_all_biomes(faction_standings: Dictionary = {}) -> Dictionary:
	var biome_registry = BiomeRegistry.new()
	var all_biomes = biome_registry.get_all()

	var result: Dictionary = {
		"biomes": [],
		"summary": {
			"total_biomes": all_biomes.size(),
			"total_emojis": 0,
			"discovered_count": 0
		}
	}

	var all_emojis: Array = []

	for biome in all_biomes:
		var biome_export = export_biome(biome.name, faction_standings)
		if not biome_export.is_empty():
			result["biomes"].append(biome_export)

			if biome.discovered:
				result["summary"]["discovered_count"] += 1

			for emoji in biome_export["emojis"]:
				if emoji not in all_emojis:
					all_emojis.append(emoji)

	result["summary"]["total_emojis"] = all_emojis.size()
	result["summary"]["all_unique_emojis"] = all_emojis

	return result


## ========================================
## File Export
## ========================================

## Export all biomes to a JSON file
func export_all_biomes_to_file(path: String, faction_standings: Dictionary = {}) -> bool:
	var data = export_all_biomes(faction_standings)
	var json_str = JSON.stringify(data)

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("BiomeExporter: Could not write to %s" % path)
		return false

	file.store_string(json_str)
	print("✅ BiomeExporter: Exported to %s" % path)
	return true


## Export single biome to file
func export_biome_to_file(biome_name: String, path: String, faction_standings: Dictionary = {}) -> bool:
	var data = export_biome(biome_name, faction_standings)
	if data.is_empty():
		return false

	var json_str = JSON.stringify(data)

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("BiomeExporter: Could not write to %s" % path)
		return false

	file.store_string(json_str)
	print("✅ BiomeExporter: Exported %s to %s" % [biome_name, path])
	return true


## ========================================
## Human-Readable Export
## ========================================

## Export biome as readable text (markdown-ish format)
func export_biome_as_text(biome_name: String, faction_standings: Dictionary = {}) -> String:
	var data = export_biome(biome_name, faction_standings)
	if data.is_empty():
		return ""

	var text = ""
	text += "# %s\n\n" % data["name"]
	text += "**Emojis:** %s\n" % ", ".join(data["emojis"])
	text += "**Tags:** %s\n" % ", ".join(data["tags"])
	text += "**Discovered:** %s\n\n" % ("Yes" if data["discovered"] else "No")

	text += "## Icons\n\n"

	for emoji in data["icons"]:
		var icon_data = data["icons"][emoji]
		text += "### %s (%s)\n" % [emoji, icon_data.get("display_name", "?")]
		text += "- **Self-energy:** %.3f\n" % icon_data.get("self_energy", 0.0)

		var h = icon_data.get("hamiltonian_couplings", {})
		if h.size() > 0:
			text += "- **Hamiltonian couplings:** "
			var couplings: Array = []
			for target in h:
				couplings.append("%s→%s(%.2f)" % [emoji, target, h[target]])
			text += ", ".join(couplings) + "\n"

		var lout = icon_data.get("lindblad_outgoing", {})
		if lout.size() > 0:
			text += "- **Lindblad outgoing:** "
			var transfers: Array = []
			for target in lout:
				transfers.append("%s→%s(%.2f)" % [emoji, target, lout[target]])
			text += ", ".join(transfers) + "\n"

		var lin = icon_data.get("lindblad_incoming", {})
		if lin.size() > 0:
			text += "- **Lindblad incoming:** "
			var transfers: Array = []
			for source in lin:
				transfers.append("%s←%s(%.2f)" % [emoji, source, lin[source]])
			text += ", ".join(transfers) + "\n"

		if icon_data.get("decay_rate", 0.0) > 0:
			text += "- **Decay:** %.3f → %s\n" % [icon_data["decay_rate"], icon_data.get("decay_target", "?")]

		text += "\n"

	return text


## Export all biomes as readable text
func export_all_biomes_as_text(faction_standings: Dictionary = {}) -> String:
	var biome_registry = BiomeRegistry.new()
	var all_biomes = biome_registry.get_all()

	var text = "# Biome Icon Exports\n\n"

	for biome in all_biomes:
		text += export_biome_as_text(biome.name, faction_standings)
		text += "\n---\n\n"

	return text


## Save text export to file
func export_all_biomes_as_text_file(path: String, faction_standings: Dictionary = {}) -> bool:
	var text = export_all_biomes_as_text(faction_standings)

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("BiomeExporter: Could not write to %s" % path)
		return false

	file.store_string(text)
	print("✅ BiomeExporter: Exported as text to %s" % path)
	return true


## ========================================
## Icon Serialization
## ========================================

## Serialize Icon object to exportable dictionary
func _serialize_icon(icon) -> Dictionary:
	if not icon:
		return {}

	var data: Dictionary = {
		"emoji": icon.emoji,
		"display_name": icon.display_name,
		"description": icon.description,
		"self_energy": icon.self_energy,
		"hamiltonian_couplings": icon.hamiltonian_couplings.duplicate(),
		"lindblad_outgoing": icon.lindblad_outgoing.duplicate(),
		"lindblad_incoming": icon.lindblad_incoming.duplicate(),
		"decay_rate": icon.decay_rate,
		"decay_target": icon.decay_target,
		"energy_couplings": icon.energy_couplings.duplicate(),
		"is_driver": icon.is_driver,
		"is_eternal": icon.is_eternal,
	}

	# Optional fields
	if icon.self_energy_driver != "":
		data["driver"] = {
			"type": icon.self_energy_driver,
			"frequency": icon.driver_frequency,
			"phase": icon.driver_phase,
			"amplitude": icon.driver_amplitude
		}

	if icon.has_meta("gated_lindblad"):
		data["gated_lindblad"] = icon.get_meta("gated_lindblad")

	if icon.has_meta("bell_activated_features"):
		data["bell_activated_features"] = icon.get_meta("bell_activated_features")

	if icon.has_meta("decoherence_coupling"):
		data["decoherence_coupling"] = icon.get_meta("decoherence_coupling")

	if icon.has_meta("measurement_behavior"):
		data["measurement_behavior"] = icon.get_meta("measurement_behavior")

	return data


## ========================================
## Debug/Analysis
## ========================================

## Print emoji coverage across biomes
func analyze_emoji_coverage() -> void:
	var biome_registry = BiomeRegistry.new()
	var biome_distribution = biome_registry.get_emoji_distribution()

	print("\n========== EMOJI COVERAGE ANALYSIS ==========")

	var single_biome: Array = []
	var multi_biome: Array = []

	for emoji in biome_distribution:
		var biomes = biome_distribution[emoji]
		if biomes.size() == 1:
			single_biome.append(emoji)
		else:
			multi_biome.append(emoji)

	print("Total unique emojis: %d" % biome_distribution.size())
	print("Single-biome emojis: %d" % single_biome.size())
	print("Multi-biome emojis: %d" % multi_biome.size())

	if multi_biome.size() > 0:
		print("\nCross-biome emojis (faction candidates):")
		for emoji in multi_biome:
			var biomes = biome_distribution[emoji]
			print("  %s: %s" % [emoji, ", ".join(biomes)])

	print("============================================\n")


## Print faction roster for each biome
func analyze_faction_roster() -> void:
	var faction_registry = FactionRegistry.new()
	var all_factions = faction_registry.get_all()
	var biome_registry = BiomeRegistry.new()

	print("\n========== FACTION ROSTER BY BIOME ==========")

	for biome in biome_registry.get_all():
		var biome_emojis = biome.get_all_emojis()
		var biome_factions: Dictionary = {}

		for emoji in biome_emojis:
			var claiming_factions = faction_registry.get_factions_for_emoji(emoji)
			for faction in claiming_factions:
				if not biome_factions.has(faction.name):
					biome_factions[faction.name] = []
				biome_factions[faction.name].append(emoji)

		print("\n%s:" % biome.name)
		for faction_name in biome_factions.keys():
			var emojis = biome_factions[faction_name]
			print("  - %s: %s" % [faction_name, ", ".join(emojis)])

	print("============================================\n")
