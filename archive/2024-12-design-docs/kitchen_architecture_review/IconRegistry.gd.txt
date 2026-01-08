extends Node

## IconRegistry: Singleton registry of all Icons in the game
## Automatically loaded at game start

# Preload CoreIcons
const CoreIcons = preload("res://Core/Icons/CoreIcons.gd")

## Dictionary mapping emoji → Icon resource
var icons: Dictionary = {}

func _ready():
	print("📜 IconRegistry initializing...")
	_load_builtin_icons()
	print("📜 IconRegistry ready: %d icons registered" % icons.size())

## Register an Icon
func register_icon(icon: Icon) -> void:
	if icon == null or icon.emoji == "":
		push_error("IconRegistry: Attempted to register null or empty Icon")
		return

	if icons.has(icon.emoji):
		push_warning("IconRegistry: Overwriting existing Icon for %s" % icon.emoji)

	icons[icon.emoji] = icon
	# print("  ✓ Registered Icon: %s (%s)" % [icon.emoji, icon.display_name])

## Get an Icon by emoji
func get_icon(emoji: String) -> Icon:
	return icons.get(emoji, null)

## Check if an Icon exists
func has_icon(emoji: String) -> bool:
	return icons.has(emoji)

## Get all registered emojis
func get_all_emojis() -> Array[String]:
	var result: Array[String] = []
	for emoji in icons.keys():
		result.append(emoji)
	return result

## Get all Icons (for building bath operators)
func get_all_icons() -> Array[Icon]:
	var result: Array[Icon] = []
	for icon in icons.values():
		result.append(icon)
	return result

## Get Icons by tag
func get_icons_by_tag(tag: String) -> Array[Icon]:
	var result: Array[Icon] = []
	for icon_variant in icons.values():
		var icon: Icon = icon_variant as Icon
		if icon and tag in icon.tags:
			result.append(icon)
	return result

## Get Icons by trophic level
func get_icons_by_trophic_level(level: int) -> Array[Icon]:
	var result: Array[Icon] = []
	for icon_variant in icons.values():
		var icon: Icon = icon_variant as Icon
		if icon and icon.trophic_level == level:
			result.append(icon)
	return result

## Load built-in Icons from CoreIcons
func _load_builtin_icons() -> void:
	# Core Icons will be loaded from CoreIcons.gd
	# Pass self to avoid circular dependency
	CoreIcons.register_all(self)

## Derive Icons from a Markov chain
## Useful for bootstrapping biome Icons from transition probabilities
func derive_from_markov(markov: Dictionary, h_scale: float = 0.5, l_scale: float = 0.3) -> void:
	print("📜 Deriving Icons from Markov chain...")

	for source in markov:
		# Skip if Icon already exists
		if has_icon(source):
			continue

		var icon = Icon.new()
		icon.emoji = source
		icon.display_name = "Markov: " + source

		var transitions = markov[source]

		for target in transitions:
			var prob = transitions[target]

			# Calculate reverse probability
			var reverse = 0.0
			if markov.has(target) and markov[target].has(source):
				reverse = markov[target][source]

			# Symmetric part → Hamiltonian coupling
			var symmetric = (prob + reverse) / 2.0
			if symmetric > 0.05:
				icon.hamiltonian_couplings[target] = symmetric * h_scale

			# Asymmetric part → Lindblad transfer
			var asymmetric = prob - symmetric
			if asymmetric > 0.02:
				icon.lindblad_outgoing[target] = asymmetric * l_scale

		register_icon(icon)

	print("  ✓ Derived %d Icons from Markov" % markov.size())

## Debug: Print all registered Icons
func debug_print_all() -> void:
	print("\n=== IconRegistry: %d Icons ===" % icons.size())
	for emoji in icons.keys():
		var icon: Icon = icons[emoji]
		print("  %s - %s" % [emoji, icon.display_name])
		if not icon.hamiltonian_couplings.is_empty():
			print("    H couplings: %s" % str(icon.hamiltonian_couplings.keys()))
		if not icon.lindblad_outgoing.is_empty():
			print("    L outgoing: %s" % str(icon.lindblad_outgoing.keys()))
	print("===========================\n")
