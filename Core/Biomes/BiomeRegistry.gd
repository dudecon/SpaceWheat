class_name BiomeRegistry
extends RefCounted

## BiomeRegistry: Data-driven biome management
##
## Mirrors FactionRegistry but for biomes.
## Provides O(1) lookup by name, emoji, and tag via pre-built indexes.
##
## Usage:
##   var registry = BiomeRegistry.new()
##   var biomes = registry.get_all()
##   var forest = registry.get_by_name("StarterForest")
##   var emojis = registry.get_emojis_for_biome("StarterForest")

const Biome = preload("res://Core/Biomes/Biome.gd")
const JSON_PATH = "res://Core/Biomes/data/biomes.json"

# Biome storage
var _biomes: Array = []

# Pre-built indexes for O(1) lookup
var _name_index: Dictionary = {}    # name -> Biome
var _emoji_index: Dictionary = {}   # emoji -> [Biome]
var _tag_index: Dictionary = {}     # tag -> [Biome]

var _loaded: bool = false


## ========================================
## Initialization
## ========================================

func _init():
	load_biomes()


## Load all biomes from JSON
func load_biomes() -> bool:
	_biomes.clear()
	_name_index.clear()
	_emoji_index.clear()
	_tag_index.clear()

	var file = FileAccess.open(JSON_PATH, FileAccess.READ)
	if not file:
		push_error("BiomeRegistry: Could not open %s" % JSON_PATH)
		return false

	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_error("BiomeRegistry: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return false

	var data = json.data
	if not data is Array:
		push_error("BiomeRegistry: Expected array at root of JSON")
		return false

	# Load each biome
	for biome_data in data:
		var biome = Biome.from_dict(biome_data)
		_biomes.append(biome)

	_build_indexes()
	_loaded = true

	return true


## Build lookup indexes for O(1) access
func _build_indexes() -> void:
	for biome in _biomes:
		# Name index
		_name_index[biome.name] = biome

		# Emoji index
		for emoji in biome.emojis:
			if not _emoji_index.has(emoji):
				_emoji_index[emoji] = []
			_emoji_index[emoji].append(biome)

		# Tag index
		for tag in biome.tags:
			if not _tag_index.has(tag):
				_tag_index[tag] = []
			_tag_index[tag].append(biome)


## ========================================
## Query API
## ========================================

## Get all biomes
func get_all() -> Array:
	return _biomes


## Get biome by exact name
func get_by_name(biome_name: String) -> Biome:
	return _name_index.get(biome_name, null)


## Find all biomes that contain a given emoji
func get_biomes_for_emoji(emoji: String) -> Array:
	return _emoji_index.get(emoji, [])


## Get all biomes with a given tag
func get_biomes_by_tag(tag: String) -> Array:
	return _tag_index.get(tag, [])


## Get all unique emojis across all biomes
func get_all_emojis() -> Array:
	return _emoji_index.keys()


## Get emoji distribution map (which biomes contain each emoji)
func get_emoji_distribution() -> Dictionary:
	var result: Dictionary = {}
	for emoji in _emoji_index:
		result[emoji] = []
		for biome in _emoji_index[emoji]:
			result[emoji].append(biome.name)
	return result


## ========================================
## Debug Utilities
## ========================================

## Print summary of all biomes
func debug_print_all() -> void:
	print("\n========== BIOME REGISTRY ==========")
	print("Loaded: %d biomes" % _biomes.size())
	print("Unique emojis: %d" % _emoji_index.size())

	print("\nBiomes:")
	for biome in _biomes:
		var discovered = "✓" if biome.discovered else "✗"
		print("  %s %s: %d emojis" % [discovered, biome.name, biome.emojis.size()])

	print("\nEmoji distribution:")
	var distribution = get_emoji_distribution()
	var sorted_emojis = distribution.keys()
	sorted_emojis.sort_custom(func(a, b): return distribution[a].size() > distribution[b].size())

	for i in range(min(10, sorted_emojis.size())):
		var emoji = sorted_emojis[i]
		print("  %s: %d biomes" % [emoji, distribution[emoji].size()])

	print("==================================\n")


## Validate all biomes
func validate_all() -> bool:
	var all_valid = true
	for biome in _biomes:
		if not biome.validate():
			all_valid = false
	return all_valid
