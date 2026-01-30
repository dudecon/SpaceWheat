class_name DataDrivenBiome
extends "res://Core/Environment/BiomeBase.gd"

## DataDrivenBiome
## Generic biome that builds its quantum system from BiomeRegistry data.
## Used for dynamically discovered biomes that don't have bespoke scripts.

const BiomeRegistry = preload("res://Core/Biomes/BiomeRegistry.gd")
const BiomeBuilder = preload("res://Core/Biomes/BiomeBuilder.gd")
const BiomeLindblad = preload("res://Core/Biomes/BiomeLindblad.gd")

var _biome_data = null
var _emoji_pairs: Array = []


func _ready() -> void:
	# Let BiomeBase initialize and call _initialize_bath().
	super._ready()

	# Register emoji pairs with the resource registry (gameplay layer).
	for pair in _emoji_pairs:
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north != "" and south != "":
			register_emoji_pair(north, south)

	# Basic visual label (can be overridden by biome data later).
	if visual_label == "":
		visual_label = name


func _initialize_bath() -> void:
	"""Build quantum computer from biome JSON data."""
	var registry = BiomeRegistry.new()
	_biome_data = registry.get_by_name(name)
	if not _biome_data:
		push_error("DataDrivenBiome: Biome not found in registry: %s" % name)
		return

	# Build emoji pairs from ordered emoji list (pairs are [0,1], [2,3], ...)
	_emoji_pairs = _build_pairs_from_emojis(_biome_data.emojis)
	if _emoji_pairs.is_empty():
		push_error("DataDrivenBiome: No emoji pairs for biome %s" % name)
		return

	# Build Lindblad spec from biome icon_components
	var lindblad_spec = _build_lindblad_spec(_biome_data.icon_components)

	# Build quantum system using unified builder (H from factions, L from biome)
	var result = BiomeBuilder.build_biome_quantum_system(
		name,
		_emoji_pairs,
		{},  # Faction standings default to full strength
		lindblad_spec
	)

	if not result.success:
		push_error("DataDrivenBiome: Failed to build quantum system for %s: %s" % [name, result.error])
		return

	quantum_computer = result.quantum_computer


func _build_pairs_from_emojis(emojis: Array) -> Array:
	var pairs: Array = []
	if emojis.size() < 2:
		return pairs
	if emojis.size() % 2 != 0:
		push_warning("DataDrivenBiome: Emoji list odd length for %s (dropping last): %d" % [name, emojis.size()])
	var limit = emojis.size() - (emojis.size() % 2)
	for i in range(0, limit, 2):
		var north = emojis[i]
		var south = emojis[i + 1]
		pairs.append({"north": north, "south": south})
	return pairs


func _build_lindblad_spec(icon_components: Dictionary) -> BiomeLindblad:
	var L = BiomeLindblad.new()
	if not icon_components:
		return L

	for emoji in icon_components.keys():
		var comp = icon_components[emoji]
		if not comp is Dictionary:
			continue

		# Incoming flows: source -> emoji (pump)
		var incoming = comp.get("lindblad_incoming", {})
		for source in incoming.keys():
			L.add_pump(emoji, source, float(incoming[source]))

		# Outgoing flows: emoji -> target (drain)
		var outgoing = comp.get("lindblad_outgoing", {})
		for target in outgoing.keys():
			L.add_drain(emoji, target, float(outgoing[target]))

		# Decay process
		var decay = comp.get("decay", {})
		if decay is Dictionary and decay.has("rate") and decay.has("target"):
			L.add_decay(emoji, decay.get("target", ""), float(decay.get("rate", 0.0)))

		# Gated Lindblad (per-emoji source)
		var gated_list = comp.get("gated_lindblad_source", [])
		if gated_list is Array:
			for gated in gated_list:
				if not gated is Dictionary:
					continue
				var target = gated.get("target", "")
				var gate = gated.get("gate", "")
				var rate = float(gated.get("rate", 0.0))
				var power = float(gated.get("power", 1.0))
				var inverse = bool(gated.get("inverse", false))
				if target != "" and gate != "" and rate > 0.0:
					L.add_gated(emoji, target, gate, rate, power, inverse)

	return L
