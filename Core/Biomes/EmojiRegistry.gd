class_name EmojiRegistry
extends RefCounted

## EmojiRegistry: Unified emoji collection from all sources
##
## Replaces duplicated emoji collection logic (~130 lines) in
## BootManager and TestBootManager.
##
## Provides single source of truth for emoji atlas building by
## collecting emojis from:
## - BiomeRegistry: All biomes in biomes_merged.json
## - FactionRegistry: All factions in factions_merged.json
##
## Usage:
##   var registry = EmojiRegistry.new()
##   var all_emojis = registry.get_all_emojis()
##   var biome_emojis = registry.get_biome_emojis()
##   var faction_emojis = registry.get_faction_emojis()

const BiomeRegistry = preload("res://Core/Biomes/BiomeRegistry.gd")
const FactionRegistry = preload("res://Core/Factions/FactionRegistry.gd")

# Emoji storage
var _biome_emojis: Dictionary = {}   # emoji -> true (from biomes)
var _faction_emojis: Dictionary = {}  # emoji -> true (from factions)
var _all_emojis: Dictionary = {}      # emoji -> true (union of both)

var _loaded: bool = false


## ========================================
## Initialization
## ========================================

func _init():
	load_emojis()


## Load all emojis from BiomeRegistry and FactionRegistry
func load_emojis() -> bool:
	_biome_emojis.clear()
	_faction_emojis.clear()
	_all_emojis.clear()

	# Load from BiomeRegistry
	var biome_registry = BiomeRegistry.new()
	var biome_emoji_list = biome_registry.get_all_emojis()
	for emoji in biome_emoji_list:
		_biome_emojis[emoji] = true
		_all_emojis[emoji] = true

	# Load from FactionRegistry
	var faction_registry = FactionRegistry.new()
	var all_factions = faction_registry.get_all()

	for faction in all_factions:
		# Get emojis from icon_components
		var icon_components = faction.icon_components
		for emoji in icon_components:
			_faction_emojis[emoji] = true
			_all_emojis[emoji] = true

		# Get emojis from hamiltonian couplings (target emojis)
		for source_emoji in icon_components:
			var component = icon_components[source_emoji]
			var h_couplings = component.get("hamiltonian", {})
			for target_emoji in h_couplings:
				_faction_emojis[target_emoji] = true
				_all_emojis[target_emoji] = true

			# Get emojis from alignment couplings
			var align_couplings = component.get("alignment", {})
			for observable_emoji in align_couplings:
				_faction_emojis[observable_emoji] = true
				_all_emojis[observable_emoji] = true

	_loaded = true
	return true


## ========================================
## Query API
## ========================================

## Get all unique emojis from all sources
func get_all_emojis() -> Array:
	return _all_emojis.keys()


## Get emojis from biomes only
func get_biome_emojis() -> Array:
	return _biome_emojis.keys()


## Get emojis from factions only
func get_faction_emojis() -> Array:
	return _faction_emojis.keys()


## Get total emoji count
func get_emoji_count() -> int:
	return _all_emojis.size()


## Check if an emoji is registered
func has_emoji(emoji: String) -> bool:
	return _all_emojis.has(emoji)


## ========================================
## Debug Utilities
## ========================================

## Print summary of emoji sources
func debug_print_summary() -> void:
	print("\n========== EMOJI REGISTRY ==========")
	print("Total unique emojis: %d" % _all_emojis.size())
	print("From biomes: %d" % _biome_emojis.size())
	print("From factions: %d" % _faction_emojis.size())
	print("====================================\n")
