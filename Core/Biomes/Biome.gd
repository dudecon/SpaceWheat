class_name Biome
extends RefCounted

## Biome: Environmental quantum system (peer to Faction)
##
## Biomes define the intrinsic quantum mechanics of an ecosystem.
## They are merged with faction contributions (weighted by faction standing)
## to produce final Icon definitions.
##
## Each biome has:
## - Icon components: base quantum parameters for each emoji in this biome
## - Metadata: name, description, image, music, discovery info
## - Faction roster: which factions are native to this biome (for emergent overlay)

## ========================================
## Identity & Metadata
## ========================================

var name: String = ""
var description: String = ""
var image_path: String = ""  # res://assets/biomes/...
var music_path: String = ""  # res://assets/music/...
var discovered: bool = false  # Whether player has unlocked this biome

## The emojis native to this biome
var emojis: Array = []

## ========================================
## Icon Components (Biome Quantum Parameters)
## ========================================

## Base icon components: {emoji: {quantum_params}}
## Each emoji has the same structure as in factions:
## {
##   "self_energy": float,
##   "hamiltonian": {target: coupling},
##   "lindblad_outgoing": {target: rate},
##   "lindblad_incoming": {source: rate},
##   "decay": {rate, target},
##   ... (other quantum fields)
## }
var icon_components: Dictionary = {}

## Cross-biome couplings (within this biome, between emojis)
## Format: [{source: emoji, target: emoji, type: str, rate: float}]
var cross_couplings: Array = []

## ========================================
## Faction Roster (for emergent overlay)
## ========================================

## Factions present in this biome (for UI/narrative)
## Not used in quantum build - purely informational
var native_factions: Array = []  # Array of faction names

## ========================================
## Metadata
## ========================================

var tags: Array = []


## ========================================
## Methods
## ========================================

## Get all emojis this biome defines
func get_all_emojis() -> Array:
	return emojis.duplicate()


## Get quantum component for an emoji
func get_icon_component(emoji: String) -> Dictionary:
	if not emoji in emojis:
		return {}
	return icon_components.get(emoji, {})


## Validate that all couplings reference defined emojis
func validate() -> bool:
	var valid = true

	# Check icon_components reference valid emojis
	for emoji in icon_components:
		if emoji not in emojis:
			push_error("Biome %s: icon_component for emoji %s not in emojis list" % [name, emoji])
			valid = false

	# Check hamiltonian targets are in biome
	for emoji in icon_components:
		var component = icon_components[emoji]
		var h = component.get("hamiltonian", {})
		for target in h:
			if target not in emojis:
				push_warning("Biome %s: hamiltonian from %s to %s (external target OK)" % [name, emoji, target])

	# Check cross-coupling references
	for coupling in cross_couplings:
		var src = coupling.get("source", "")
		var tgt = coupling.get("target", "")
		if src not in emojis:
			push_error("Biome %s: cross-coupling source %s not in emojis" % [name, src])
			valid = false
		if tgt not in emojis:
			push_error("Biome %s: cross-coupling target %s not in emojis" % [name, tgt])
			valid = false

	return valid


## ========================================
## Serialization (JSON Data-Driven Support)
## ========================================

## Convert biome to dictionary for JSON export
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"name": name,
		"description": description,
		"image_path": image_path,
		"music_path": music_path,
		"discovered": discovered,
		"emojis": emojis,
		"icon_components": icon_components,
		"tags": tags,
	}

	if cross_couplings.size() > 0:
		data["cross_couplings"] = cross_couplings

	if native_factions.size() > 0:
		data["native_factions"] = native_factions

	return data


## Load biome from dictionary (JSON import)
func load_from_dict(data: Dictionary) -> void:
	name = data.get("name", "")
	description = data.get("description", "")
	image_path = data.get("image_path", "")
	music_path = data.get("music_path", "")
	discovered = data.get("discovered", false)
	emojis = data.get("emojis", [])
	icon_components = data.get("icon_components", {})
	cross_couplings = data.get("cross_couplings", [])
	native_factions = data.get("native_factions", [])
	tags = data.get("tags", [])


## Create biome from dictionary (static factory)
static func from_dict(data: Dictionary) -> Biome:
	var biome = load("res://Core/Biomes/Biome.gd").new()
	biome.load_from_dict(data)
	return biome


## Debug representation
func _to_string() -> String:
	return "Biome<%s>(%d emojis)" % [name, emojis.size()]
