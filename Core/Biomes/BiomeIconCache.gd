class_name BiomeIconCache
extends RefCounted

## BiomeIconCache: Lazy-load and cache built biome icons
##
## Builds complete icon sets for biomes on-demand.
## Caches the result so C++ quantum operators don't rebuild constantly.
##
## Usage:
##   var cache = BiomeIconCache.new()
##   var icons = cache.get_icons_for_biome("StarterForest")
##   # Or with faction standings:
##   var icons = cache.get_icons_for_biome("Village", {"Granary Guilds": 0.8})

const BiomeRegistry = preload("res://Core/Biomes/BiomeRegistry.gd")
const IconBuilder = preload("res://Core/Factions/IconBuilder.gd")

# Cache: {biome_name: {icons: Dictionary, standings_hash: String}}
var _cache: Dictionary = {}

# Biome registry
var _biome_registry: BiomeRegistry = null


## ========================================
## Initialization
## ========================================

func _init():
	_biome_registry = BiomeRegistry.new()


## ========================================
## Cache Access
## ========================================

## Get built icons for a biome (with optional faction standing weights)
func get_icons_for_biome(
	biome_name: String,
	faction_standings: Dictionary = {}
) -> Dictionary:
	## Args:
	##   biome_name: Name of biome to build icons for
	##   faction_standings: {faction_name: standing_float} (optional)
	##                      0.0 = muted, 1.0 = full strength
	##
	## Returns:
	##   Dictionary[emoji] -> Icon

	# Generate cache key based on standings
	var standings_hash = _hash_standings(faction_standings)
	var cache_key = "%s:%s" % [biome_name, standings_hash]

	# Check cache
	if _cache.has(cache_key):
		return _cache[cache_key].duplicate()  # Return copy, not reference

	# Not in cache - build it
	var icons = IconBuilder.build_biome_with_factions(biome_name, faction_standings)

	if icons.is_empty():
		push_warning("BiomeIconCache: Failed to build icons for %s" % biome_name)
		return {}

	# Cache the result
	_cache[cache_key] = icons

	return icons.duplicate()


## Get cached icons WITHOUT building (returns empty if not cached)
func get_cached_icons(biome_name: String, faction_standings: Dictionary = {}) -> Dictionary:
	var standings_hash = _hash_standings(faction_standings)
	var cache_key = "%s:%s" % [biome_name, standings_hash]
	return _cache.get(cache_key, {}).duplicate()


## Check if icons are cached for this biome/standings combo
func is_cached(biome_name: String, faction_standings: Dictionary = {}) -> bool:
	var standings_hash = _hash_standings(faction_standings)
	var cache_key = "%s:%s" % [biome_name, standings_hash]
	return _cache.has(cache_key)


## Invalidate cache for a biome (forces rebuild on next request)
func invalidate(biome_name: String, faction_standings: Dictionary = {}) -> void:
	var standings_hash = _hash_standings(faction_standings)
	var cache_key = "%s:%s" % [biome_name, standings_hash]
	_cache.erase(cache_key)


## Invalidate all cached entries
func invalidate_all() -> void:
	_cache.clear()


## ========================================
## Cache Utilities
## ========================================

## Generate hash of standings dictionary for cache key
func _hash_standings(faction_standings: Dictionary) -> String:
	if faction_standings.is_empty():
		return "default"

	var items: Array = []
	for faction_name in faction_standings.keys():
		var standing = faction_standings[faction_name]
		items.append("%s:%.2f" % [faction_name, standing])

	items.sort()
	return items[0] if items.size() == 1 else "%d_standings" % hash(str(items))


## ========================================
## Batch Operations
## ========================================

## Pre-cache all biome icons (useful for startup)
func precache_all_biomes() -> void:
	var biomes = _biome_registry.get_all()

	for biome in biomes:
		if not biome.discovered:
			continue  # Skip undiscovered biomes

		var icons = get_icons_for_biome(biome.name)
		if not icons.is_empty():
			print("BiomeIconCache: Cached icons for %s (%d emojis)" % [biome.name, icons.size()])


## ========================================
## Debug Utilities
## ========================================

## Print cache statistics
func debug_print_stats() -> void:
	print("\n========== BIOME ICON CACHE ==========")
	print("Cache entries: %d" % _cache.size())

	var biomes_cached: Dictionary = {}
	for cache_key in _cache.keys():
		var biome_name = cache_key.split(":")[0]
		if not biomes_cached.has(biome_name):
			biomes_cached[biome_name] = 0
		biomes_cached[biome_name] += 1

	print("\nCached biomes:")
	for biome_name in biomes_cached.keys():
		print("  %s: %d cache entries" % [biome_name, biomes_cached[biome_name]])

	print("=====================================\n")
