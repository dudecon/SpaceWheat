class_name AllFactions
extends RefCounted

## AllFactions: Backward-compatible wrapper for FactionRegistry
##
## DEPRECATED: Use FactionRegistry directly for new code.
## This wrapper maintains API compatibility with existing code.
##
## Migration:
##   OLD: var factions = AllFactions.get_all()
##   NEW: var registry = FactionRegistry.new()
##        var factions = registry.get_all()

const FactionRegistry = preload("res://Core/Factions/FactionRegistry.gd")

# Cached registry instance
static var _registry: FactionRegistry = null

## Get or create registry instance
static func _get_registry() -> FactionRegistry:
	if _registry == null:
		_registry = FactionRegistry.new()
	return _registry


## ========================================
## Faction Collections (delegated to FactionRegistry)
## ========================================

## Get ALL factions
static func get_all() -> Array:
	return _get_registry().get_all()


## Get core ecosystem factions only
static func get_core() -> Array:
	return _get_registry().get_core()


## Get civilization factions only
static func get_civilization() -> Array:
	return _get_registry().get_civilization()


## Get tier 2 factions only
static func get_tier2() -> Array:
	return _get_registry().get_tier2()


## Get factions accessible from starter emojis
static func get_starter_accessible() -> Array:
	return _get_registry().get_starter_accessible()


## ========================================
## Faction Queries (delegated to FactionRegistry)
## ========================================

## Find all factions that speak a given emoji
static func get_factions_for_emoji(emoji: String) -> Array:
	return _get_registry().get_factions_for_emoji(emoji)


## Get all unique emojis across all factions
static func get_all_emojis() -> Array:
	return _get_registry().get_all_emojis()


## Count how many factions speak each emoji
static func get_emoji_contestation() -> Dictionary:
	return _get_registry().get_emoji_contestation()


## ========================================
## Biome Presets (delegated to FactionRegistry)
## ========================================

## Get factions for a specific biome type
static func get_biome_factions(biome_type: String) -> Array:
	return _get_registry().get_biome_factions(biome_type)


## ========================================
## Debug Utilities
## ========================================

## Print summary of all factions
static func debug_print_all() -> void:
	_get_registry().debug_print_all()


## Print emoji contestation map
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


## Print statistics about mechanics
static func debug_print_mechanics() -> void:
	print("\n========== MECHANICS STATISTICS ==========")
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
	print("==========================================\n")
