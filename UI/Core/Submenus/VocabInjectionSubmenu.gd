class_name VocabInjectionSubmenu
extends RefCounted

## Vocabulary Injection Submenu
## Dynamic submenu for Tool 4Q action showing vocab options sorted by biome affinity
## Supports F-cycling through multiple pages of options

const BaseSubmenu = preload("res://UI/Core/Submenus/BaseSubmenu.gd")
const BiomeAffinityCalculator = preload("res://Core/Quantum/BiomeAffinityCalculator.gd")


static func generate_submenu(biome, farm, page: int = 0) -> Dictionary:
	"""Generate dynamic submenu for vocab injection.

	Args:
		biome: Current biome
		farm: Farm instance (vocab owner)
		page: Page number for F-cycling (0 = first 3, 1 = next 3, etc.)

	Returns:
		Submenu with vocab options sorted by affinity
	"""
	var options = _collect_options(biome, farm)

	if options.is_empty():
		return BaseSubmenu.empty_submenu(
			"vocab_injection",
			"Inject Vocabulary",
			"No vocab available"
		)

	# Sort by affinity and apply costs
	options = _sort_by_affinity(options, biome)
	options = BaseSubmenu.apply_cost_to_options(options, farm.economy if farm else null)

	var pagination = BaseSubmenu.paginate(options, page)
	var actions = BaseSubmenu.build_actions(pagination.page_options, _build_vocab_action)

	return BaseSubmenu.build_result(
		"vocab_injection",
		"Inject Vocabulary",
		pagination,
		actions
	)


static func _collect_options(biome, farm) -> Array:
	"""Collect vocab pairs that can be injected into biome.

	A pair is injectable if:
	- Player has learned it (in known_pairs)
	- NOT already in biome's quantum computer
	"""
	var options: Array = []

	if not farm:
		return options

	# Gather all known pairs
	var pairs: Array = []
	if farm.has_method("get_known_pairs"):
		pairs.append_array(farm.get_known_pairs())
	if "vocabulary_evolution" in farm and farm.vocabulary_evolution:
		if farm.vocabulary_evolution.has_method("get_discovered_vocabulary"):
			var discovered = farm.vocabulary_evolution.get_discovered_vocabulary()
			if discovered is Array:
				pairs.append_array(discovered)

	# Filter to injectable pairs
	var biome_emojis = _get_biome_emojis(biome)
	var seen: Dictionary = {}

	for pair in pairs:
		if not (pair is Dictionary):
			continue

		var north = pair.get("north", "")
		var south = pair.get("south", "")

		if north == "" or south == "" or north == south:
			continue

		# Skip if already in biome
		if north in biome_emojis or south in biome_emojis:
			continue

		# Dedupe
		var key = "%s|%s" % [north, south]
		if seen.has(key):
			continue
		seen[key] = true

		# Build option with cost
		options.append({
			"north": north,
			"south": south,
			"label": "%s/%s" % [north, south],
			"cost": _get_injection_cost(south),
			"enabled": true
		})

	return options


static func _sort_by_affinity(options: Array, biome) -> Array:
	"""Sort vocab options by descending affinity to biome."""
	var player_vocab_qc = _get_player_vocab_qc()

	for option in options:
		var pair = {"north": option.get("north", ""), "south": option.get("south", "")}
		var affinity = BiomeAffinityCalculator.calculate_affinity(pair, biome, player_vocab_qc)
		option["affinity"] = affinity
		option["hint"] = "Affinity: %.2f" % affinity

	return BaseSubmenu.sort_by_field(options, "affinity", true)


static func _build_vocab_action(option: Dictionary) -> Dictionary:
	"""Build action data for a vocab option."""
	return {
		"action": "inject_vocabulary",
		"vocab_pair": {
			"north": option.get("north", ""),
			"south": option.get("south", "")
		},
		"label": option.get("label", ""),
		"hint": option.get("hint", ""),
		"affinity": option.get("affinity", 0.0),
		"cost": option.get("cost", {}),
		"cost_display": option.get("cost_display", ""),
		"can_afford": option.get("can_afford", true),
		"enabled": option.get("enabled", true)
	}


static func _get_injection_cost(south_emoji: String) -> Dictionary:
	"""Get cost for injecting a vocab pair."""
	# TODO: Pull from EconomyConstants when that's wired up
	# For now, base cost with modifier based on emoji rarity
	return {"energy": 1}


static func _get_biome_emojis(biome) -> Array[String]:
	"""Get all emojis in biome's quantum computer."""
	if not biome:
		return [] as Array[String]
	if biome.viz_cache:
		var emojis = biome.viz_cache.get_emojis()
		return emojis as Array[String]
	return [] as Array[String]


static func _get_player_vocab_qc():
	"""Get player vocabulary quantum computer from autoload."""
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		var player_vocab = tree.root.get_node_or_null("PlayerVocabulary")
		if player_vocab and player_vocab.vocab_qc:
			return player_vocab.vocab_qc
	return null
