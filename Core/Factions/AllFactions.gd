class_name AllFactions
extends RefCounted

## AllFactions: Unified access to all faction groups
##
## This provides a single point of access for all factions in SpaceWheat:
## - Core Ecosystem Factions (10): Nature, markets, kitchen
## - Civilization Factions (7): Bread/population accessible starter factions
## - Tier 2 Factions (10): Commerce, Industry, Governance branches
##
## Total: 27 factions defining 100+ unique emojis
##
## Usage:
##   var all_factions = AllFactions.get_all()
##   var icons = IconBuilder.build_icons_for_factions(all_factions)

# Preload faction group scripts
const CoreFactions = preload("res://Core/Factions/CoreFactions.gd")
const CivilizationFactions = preload("res://Core/Factions/CivilizationFactions.gd")
const Tier2Factions = preload("res://Core/Factions/Tier2Factions.gd")
const CenterFactions = preload("res://Core/Factions/CenterFactions.gd")
const FringeFactions = preload("res://Core/Factions/FringeFactions.gd")
const OuterFactions = preload("res://Core/Factions/OuterFactions.gd")

## ========================================
## Faction Collections
## ========================================

## Get ALL factions (Core + Civilization + Tier 2 + Center + Fringe + Outer)
## Returns Array with all registered factions
static func get_all() -> Array:
	var factions: Array = []

	# Core ecosystem factions (10)
	for f in CoreFactions.get_all():
		factions.append(f)

	# Civilization factions (7)
	for f in CivilizationFactions.get_all():
		factions.append(f)

	# Tier 2 factions (10)
	for f in Tier2Factions.get_all():
		factions.append(f)

	# Center ring factions (new)
	for f in CenterFactions.get_all():
		factions.append(f)

	# Fringe ring factions
	for f in FringeFactions.get_all():
		factions.append(f)

	# Outer ring factions
	for f in OuterFactions.get_all():
		factions.append(f)

	return factions

## Get core ecosystem factions only (nature, markets, kitchen)
static func get_core() -> Array:
	return CoreFactions.get_all()

## Get civilization factions only (bread/population accessible)
static func get_civilization() -> Array:
	return CivilizationFactions.get_all()

## Get tier 2 factions only (commerce, industry, governance)
static func get_tier2() -> Array:
	return Tier2Factions.get_all()

## Get factions accessible from starter emojis (🍞 + 👥)
static func get_starter_accessible() -> Array:
	var factions: Array = []

	# Hearth Keepers (🍞 producer)
	factions.append(CoreFactions.create_hearth_keepers())

	# All civilization factions are accessible from 🍞👥
	for f in CivilizationFactions.get_all():
		factions.append(f)

	return factions

## ========================================
## Faction Queries
## ========================================

## Find all factions that speak a given emoji
static func get_factions_for_emoji(emoji: String) -> Array:
	var result: Array = []
	for faction in get_all():
		if faction.speaks(emoji):
			result.append(faction)
	return result

## Get all unique emojis across all factions
static func get_all_emojis() -> Array:
	var emojis: Array[String] = []
	for faction in get_all():
		for emoji in faction.get_all_emojis():
			if emoji not in emojis:
				emojis.append(emoji)
	return emojis

## Count how many factions speak each emoji (contestation map)
static func get_emoji_contestation() -> Dictionary:
	var contestation: Dictionary = {}
	for faction in get_all():
		for emoji in faction.signature:
			if not contestation.has(emoji):
				contestation[emoji] = []
			contestation[emoji].append(faction.name)
	return contestation

## ========================================
## Biome Presets
## ========================================

## Get factions for a specific biome type
static func get_biome_factions(biome_type: String) -> Array:
	match biome_type:
		"BioticFlux":
			return [
				CoreFactions.create_celestial_archons(),
				CoreFactions.create_verdant_pulse(),
				CoreFactions.create_mycelial_web(),
			]

		"Kitchen":
			return [
				CoreFactions.create_celestial_archons(),
				CoreFactions.create_hearth_keepers(),
				CoreFactions.create_verdant_pulse(),
			]

		"Market":
			return [
				CoreFactions.create_market_spirits(),
			]

		"Forest":
			return [
				CoreFactions.create_celestial_archons(),
				CoreFactions.create_verdant_pulse(),
				CoreFactions.create_mycelial_web(),
				CoreFactions.create_swift_herd(),
				CoreFactions.create_pack_lords(),
				CoreFactions.create_pollinator_guild(),
				CoreFactions.create_plague_vectors(),
				CoreFactions.create_wildfire_dynamics(),
			]

		"Village":
			# Early civilization
			return [
				CoreFactions.create_celestial_archons(),
				CoreFactions.create_verdant_pulse(),
				CoreFactions.create_hearth_keepers(),
				CivilizationFactions.create_granary_guilds(),
				CivilizationFactions.create_millwrights_union(),
				CivilizationFactions.create_yeast_prophets(),
			]

		"Imperial":
			# Full civilization with extraction
			return [
				CoreFactions.create_market_spirits(),
				CivilizationFactions.create_granary_guilds(),
				CivilizationFactions.create_millwrights_union(),
				CivilizationFactions.create_station_lords(),
				CivilizationFactions.create_void_serfs(),
				CivilizationFactions.create_carrion_throne(),
			]

		"Scavenger":
			# Waste economy
			return [
				CoreFactions.create_hearth_keepers(),
				CivilizationFactions.create_scavenged_psithurism(),
				CivilizationFactions.create_millwrights_union(),
			]

		_:
			push_warning("Unknown biome type: %s, returning empty faction list" % biome_type)
			return []

## ========================================
## Debug Utilities
## ========================================

## Print summary of all factions
static func debug_print_all() -> void:
	print("\n========== ALL FACTIONS ==========")

	print("\n--- CORE ECOSYSTEM (10) ---")
	for f in CoreFactions.get_all():
		print("  %s [%s]: %s" % [f.name, f.ring, ", ".join(f.signature)])

	print("\n--- CIVILIZATION (7) ---")
	for f in CivilizationFactions.get_all():
		print("  %s [%s]: %s" % [f.name, f.ring, ", ".join(f.signature)])

	print("\n--- TIER 2 (10) ---")
	for f in Tier2Factions.get_all():
		print("  %s [%s]: %s" % [f.name, f.ring, ", ".join(f.signature)])

	print("\nTotal factions: %d" % get_all().size())
	print("Total unique emojis: %d" % get_all_emojis().size())
	print("==================================\n")

## Print emoji contestation map (which emojis are shared)
static func debug_print_contestation() -> void:
	print("\n========== EMOJI CONTESTATION ==========")
	var contestation = get_emoji_contestation()
	var contested_emojis: Array[String] = []

	for emoji in contestation.keys():
		if contestation[emoji].size() > 1:
			contested_emojis.append(emoji)

	contested_emojis.sort_custom(func(a, b): return contestation[a].size() > contestation[b].size())

	print("Contested emojis (shared by multiple factions):")
	for emoji in contested_emojis:
		print("  %s: %s (%d factions)" % [emoji, ", ".join(contestation[emoji]), contestation[emoji].size()])

	print("\nTotal contested emojis: %d / %d" % [contested_emojis.size(), contestation.size()])
	print("=========================================\n")

## Print statistics about new mechanics
static func debug_print_mechanics() -> void:
	print("\n========== NEW MECHANICS ==========")
	var inverse_gates = 0
	var measurement_inversions = 0
	var negative_energies = 0
	var drivers = 0

	for faction in get_all():
		# Count inverse gating
		for emoji in faction.gated_lindblad:
			for gate_config in faction.gated_lindblad[emoji]:
				if gate_config.get("inverse", false):
					inverse_gates += 1

		# Count measurement inversions
		for emoji in faction.measurement_behavior:
			if faction.measurement_behavior[emoji].get("inverts", false):
				measurement_inversions += 1

		# Count negative energies
		for emoji in faction.self_energies:
			if faction.self_energies[emoji] < 0:
				negative_energies += 1

		# Count drivers
		drivers += faction.drivers.size()

	print("Inverse gates (starvation): %d" % inverse_gates)
	print("Measurement inversions: %d" % measurement_inversions)
	print("Negative self-energies: %d" % negative_energies)
	print("Time-dependent drivers: %d" % drivers)
	print("===================================\n")
