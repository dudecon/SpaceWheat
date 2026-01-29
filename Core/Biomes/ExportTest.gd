## Temporary test script - runs exporter and exits
extends Node

func _ready():
	print("\n" + "="*80)
	print("BIOME ICON EXPORT TEST")
	print("="*80 + "\n")

	# Create exporter
	var exporter = load("res://Core/Biomes/BiomeExporter.gd").new()

	print(">>> Exporting all biomes...\n")

	# Export all biomes
	var all_data = exporter.export_all_biomes()

	# Print summary
	print("\n" + "="*80)
	print("EXPORT SUMMARY")
	print("="*80)
	print("Total biomes: %d" % all_data["summary"]["total_biomes"])
	print("Discovered: %d" % all_data["summary"]["discovered_count"])
	print("Total unique emojis: %d" % all_data["summary"]["total_emojis"])
	print("All emojis: %s\n" % ", ".join(all_data["summary"]["all_unique_emojis"]))

	# Print each biome
	for biome_data in all_data["biomes"]:
		print("\n" + "-"*80)
		print("BIOME: %s" % biome_data["name"])
		print("-"*80)
		print("Discovered: %s" % ("Yes" if biome_data["discovered"] else "No"))
		print("Tags: %s" % ", ".join(biome_data["tags"]))
		print("Emojis: %s" % ", ".join(biome_data["emojis"]))
		print("Icon count: %d\n" % biome_data["icons"].size())

		# Print each icon in this biome
		for emoji in biome_data["emojis"]:
			if emoji in biome_data["icons"]:
				var icon = biome_data["icons"][emoji]
				print("  %s (%s):" % [emoji, icon.get("display_name", "?")])
				print("    - self_energy: %.3f" % icon.get("self_energy", 0.0))

				var h = icon.get("hamiltonian_couplings", {})
				if h.size() > 0:
					var couplings = []
					for target in h:
						couplings.append("%s(%.2f)" % [target, h[target]])
					print("    - hamiltonian: %s" % ", ".join(couplings))

				var lout = icon.get("lindblad_outgoing", {})
				if lout.size() > 0:
					var transfers = []
					for target in lout:
						transfers.append("%s(%.2f)" % [target, lout[target]])
					print("    - lindblad_out: %s" % ", ".join(transfers))

				var lin = icon.get("lindblad_incoming", {})
				if lin.size() > 0:
					var transfers = []
					for source in lin:
						transfers.append("%s(%.2f)" % [source, lin[source]])
					print("    - lindblad_in: %s" % ", ".join(transfers))

				if icon.get("decay_rate", 0.0) > 0:
					print("    - decay: %.3f → %s" % [icon["decay_rate"], icon.get("decay_target", "?")])

				print()

	print("\n" + "="*80)
	print("FACTION ROSTER ANALYSIS")
	print("="*80 + "\n")

	exporter.analyze_faction_roster()

	print("="*80)
	print("EMOJI COVERAGE ANALYSIS")
	print("="*80 + "\n")

	exporter.analyze_emoji_coverage()

	print("="*80)
	print("EXPORT TEST COMPLETE")
	print("="*80 + "\n")

	# Exit
	get_tree().quit()
