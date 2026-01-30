class_name FactionRegistry
extends RefCounted

## FactionRegistry: Data-driven faction management
##
## Replaces AllFactions.gd with JSON-backed faction loading.
## Provides O(1) lookup by emoji, name, and tag via pre-built indexes.
##
## Usage:
##   var registry = FactionRegistry.new()
##   var factions = registry.get_all()
##   var verdant = registry.get_by_name("Verdant Pulse")
##   var sun_factions = registry.get_factions_for_emoji("☀")

const Faction = preload("res://Core/Factions/Faction.gd")
const JSON_PATH = "res://Core/Factions/data/factions_merged.json"

# Faction storage
var _factions: Array = []

# Pre-built indexes for O(1) lookup
var _emoji_index: Dictionary = {}   # emoji -> [Faction]
var _name_index: Dictionary = {}    # name -> Faction
var _tag_index: Dictionary = {}     # tag -> [Faction]
var _ring_index: Dictionary = {}    # ring -> [Faction]

var _loaded: bool = false


## ========================================
## Initialization
## ========================================

func _init():
	load_factions()


## Load all factions from JSON
func load_factions() -> bool:
	_factions.clear()
	_emoji_index.clear()
	_name_index.clear()
	_tag_index.clear()
	_ring_index.clear()

	var file = FileAccess.open(JSON_PATH, FileAccess.READ)
	if not file:
		push_error("FactionRegistry: Could not open %s" % JSON_PATH)
		return false

	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_error("FactionRegistry: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return false

	var data = json.data
	if not data is Array:
		push_error("FactionRegistry: Expected array at root of JSON")
		return false

	# Load each faction
	for faction_data in data:
		var faction = Faction.from_dict(faction_data)
		_factions.append(faction)

	_build_indexes()
	_loaded = true

	return true


## Build lookup indexes for O(1) access
func _build_indexes() -> void:
	for faction in _factions:
		# Name index
		_name_index[faction.name] = faction

		# Ring index
		if not _ring_index.has(faction.ring):
			_ring_index[faction.ring] = []
		_ring_index[faction.ring].append(faction)

		# Emoji index
		for emoji in faction.signature:
			if not _emoji_index.has(emoji):
				_emoji_index[emoji] = []
			_emoji_index[emoji].append(faction)

		# Tag index
		for tag in faction.tags:
			if not _tag_index.has(tag):
				_tag_index[tag] = []
			_tag_index[tag].append(faction)


## ========================================
## Query API (replaces AllFactions static methods)
## ========================================

## Get all factions
func get_all() -> Array:
	return _factions


## Get faction by exact name
func get_by_name(faction_name: String) -> Faction:
	return _name_index.get(faction_name, null)


## Find all factions that speak a given emoji (O(1) lookup)
func get_factions_for_emoji(emoji: String) -> Array:
	return _emoji_index.get(emoji, [])


## Get all factions with a given tag
func get_factions_by_tag(tag: String) -> Array:
	return _tag_index.get(tag, [])


## Get all factions in a given ring
func get_factions_by_ring(ring: String) -> Array:
	return _ring_index.get(ring, [])


## Get all unique emojis across all factions
func get_all_emojis() -> Array:
	return _emoji_index.keys()


## Get emoji contestation map (which factions share each emoji)
func get_emoji_contestation() -> Dictionary:
	var result: Dictionary = {}
	for emoji in _emoji_index:
		result[emoji] = []
		for faction in _emoji_index[emoji]:
			result[emoji].append(faction.name)
	return result


## ========================================
## Biome Presets
## ========================================

## Get factions for a specific biome type
func get_biome_factions(biome_type: String) -> Array:
	match biome_type:
		"BioticFlux":
			return _get_factions_by_names([
				"Celestial Archons",
				"Verdant Pulse",
				"Mycelial Web",
			])

		"StellarForges":
			return _get_factions_by_names([
				"Market Spirits",
				"Memory Merchants",
				"Iron Shepherds",
			])

		"FungalNetworks":
			return _get_factions_by_names([
				"Mycelial Web",
				"Celestial Archons",
				"Locusts",
				"Mossline Brokers",
			])

		"VolcanicWorlds":
			return _get_factions_by_names([
				"Volcanic Foundry",
				"Brotherhood of Ash",
				"Children of the Ember",
				"Wildfire",
			])

		"Village":
			return _get_factions_by_names([
				"Celestial Archons",
				"Verdant Pulse",
				"Hearth Keepers",
				"Granary Guilds",
				"Millwright's Union",
				"Yeast Prophets",
			])

		"Imperial":
			return _get_factions_by_names([
				"Market Spirits",
				"Granary Guilds",
				"Millwright's Union",
				"Station Lords",
				"Void Serfs",
				"Carrion Throne",
			])

		"Scavenger":
			return _get_factions_by_names([
				"Hearth Keepers",
				"Scavenged Psithurism",
				"Millwright's Union",
			])

		_:
			push_warning("FactionRegistry: Unknown biome type: %s" % biome_type)
			return []


## Helper: Get multiple factions by name
func _get_factions_by_names(names: Array) -> Array:
	var result: Array = []
	for faction_name in names:
		var faction = get_by_name(faction_name)
		if faction:
			result.append(faction)
		else:
			push_warning("FactionRegistry: Faction not found: %s" % faction_name)
	return result


## ========================================
## Starter Factions
## ========================================

## Get factions accessible from starter emojis (🍞 + 👥)
func get_starter_accessible() -> Array:
	var result: Array = []

	# Hearth Keepers (🍞 producer)
	var hearth = get_by_name("Hearth Keepers")
	if hearth:
		result.append(hearth)

	# Civilization factions
	for faction_name in ["Granary Guilds", "Millwright's Union", "Yeast Prophets",
						  "Station Lords", "Void Serfs", "Carrion Throne", "Scavenged Psithurism"]:
		var faction = get_by_name(faction_name)
		if faction:
			result.append(faction)

	return result


## ========================================
## Category Accessors (for compatibility)
## ========================================

## Get core ecosystem factions
func get_core() -> Array:
	return _get_factions_by_names([
		"Celestial Archons", "Verdant Pulse", "Mycelial Web", "Swift Herd",
		"Pack Lords", "Market Spirits", "Hearth Keepers", "Pollinator Guild",
		"Plague Vectors", "Wildfire"
	])


## Get civilization factions
func get_civilization() -> Array:
	return _get_factions_by_names([
		"Granary Guilds", "Millwright's Union", "Yeast Prophets",
		"Station Lords", "Void Serfs", "Carrion Throne", "Scavenged Psithurism"
	])


## Get tier 2 factions
func get_tier2() -> Array:
	return _get_factions_by_names([
		"Tinker Team", "Seedvault Curators", "Relay Lattice", "Gearwright Circle",
		"Terrarium Collective", "Clan of the Hidden Root", "Scythe Provosts",
		"Ledger Bailiffs", "Measure Scribes", "The Indelible Precept"
	])


## ========================================
## Debug Utilities
## ========================================

## Print summary of all factions
func debug_print_all() -> void:
	print("\n========== FACTION REGISTRY ==========")
	print("Loaded: %d factions" % _factions.size())
	print("Unique emojis: %d" % _emoji_index.size())

	print("\nBy ring:")
	for ring in _ring_index:
		print("  %s: %d factions" % [ring, _ring_index[ring].size()])

	print("\nMost contested emojis:")
	var contestation = get_emoji_contestation()
	var sorted_emojis = contestation.keys()
	sorted_emojis.sort_custom(func(a, b): return contestation[a].size() > contestation[b].size())

	for i in range(min(10, sorted_emojis.size())):
		var emoji = sorted_emojis[i]
		print("  %s: %d factions" % [emoji, contestation[emoji].size()])

	print("=======================================\n")


## Validate all factions
func validate_all() -> bool:
	var all_valid = true
	for faction in _factions:
		if not faction.validate():
			all_valid = false
	return all_valid
