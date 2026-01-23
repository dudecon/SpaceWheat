class_name CacheKey
extends RefCounted

## Cache Key Generator for Operator Caching
## Generates deterministic hash keys from Icon configurations
## Key automatically changes when Icon data changes, invalidating cache

## Generate cache key for a biome's quantum operators
## Returns 8-character hash that changes when Icon configs change
static func for_biome(biome_name: String, icon_registry) -> String:
	"""
	Generate cache key for a biome's operators.
	Key = Hash(biome structure + Icon configs used)

	The key automatically invalidates when:
	- Icon self_energy changes
	- Icon hamiltonian_couplings change
	- Icon lindblad_incoming/outgoing changes
	- Icon decay_rate/decay_target changes
	"""
	var config_data = {
		"biome_name": biome_name,
		"version": 1,  # Increment when algorithm changes
		"icons": _collect_icon_configs(biome_name, icon_registry)
	}

	return _hash_config(config_data)

## Collect all Icon data that affects this biome's operators
static func _collect_icon_configs(biome_name: String, icon_registry) -> Dictionary:
	var configs = {}

	# Get list of emojis used by this biome
	var emojis = _get_biome_emojis(biome_name)

	for emoji in emojis:
		if not icon_registry.icons.has(emoji):
			continue

		var icon = icon_registry.icons[emoji]

		# Extract ONLY fields that affect operators
		# Changes to other fields (display_name, description, etc.) don't invalidate cache
		configs[emoji] = {
			"self_energy": icon.self_energy,
			"hamiltonian_couplings": icon.hamiltonian_couplings.duplicate(),
			"lindblad_incoming": icon.lindblad_incoming.duplicate(),
			"lindblad_outgoing": icon.lindblad_outgoing.duplicate(),
			"decay_rate": icon.decay_rate,
			"decay_target": icon.decay_target,
			"energy_couplings": icon.energy_couplings.duplicate() if icon.energy_couplings else {}
		}

	return configs

## Get list of emojis that affect each biome's operators
## TODO: Make this dynamic by reading biome.OPERATOR_EMOJIS constant
static func _get_biome_emojis(biome_name: String) -> Array:
	match biome_name:
		"BioticFluxBiome":
			return ["☀", "🌙", "🌾", "🏰", "🍄", "🐰", "🐺", "🍂", "🌲", "🌿", "💀"]
		"StellarForgesBiome":
			return ["⚡", "🔋", "⚙", "🔩", "🚀", "🛸"]
		"FungalNetworksBiome":
			return ["🦗", "🐜", "🍄", "🦠", "🧫", "🍂", "🌙", "☀"]
		"VolcanicWorldsBiome":
			return ["🔥", "🪨", "💎", "⛏", "🌫", "✨"]
		# Legacy biomes (kept for cache compatibility)
		"MarketBiome":
			return ["⚖️", "💰", "🌾", "🍄", "🐰", "🐺", "🏰"]
		"QuantumKitchen_Biome":
			return ["🔥", "❄️", "💧", "🏜️", "💨", "🌾", "🍞"]
		"ForestEcosystem_Biome":
			return ["🌲", "🌿", "🍂", "🌾", "🐰", "🐺", "☀️", "🌙"]
		_:
			push_warning("Unknown biome for cache key: %s" % biome_name)
			return []

## Generate deterministic hash from config Dictionary
static func _hash_config(config: Dictionary) -> String:
	# Sort keys for deterministic JSON (Dictionary iteration order may vary)
	var json_str = JSON.stringify(config, "\t", true)  # Sort keys

	# MD5 hash, truncated to 8 characters (sufficient for uniqueness)
	return json_str.md5_text().substr(0, 8)
