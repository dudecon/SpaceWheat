class_name BiomeAffinityCalculator
extends RefCounted

## Biome Affinity Calculator
## Calculates quantum affinity between vocab pairs and biomes
## Uses graph-based connection weights from VocabularyPairing

static func calculate_affinity(vocab_pair: Dictionary, biome, player_vocab_qc = null) -> float:
	"""Calculate quantum affinity between vocab pair and biome.

	Uses: Graph-based connection strength (|H| + L_in + L_out)
		  between vocab pair emojis and biome emojis

	Args:
		vocab_pair: {north: String, south: String}
		biome: Biome with quantum_computer
		player_vocab_qc: Optional player vocabulary quantum computer (unused for now, future use)

	Returns:
		float: Weighted connection strength (higher = better match)

	Algorithm:
	1. Get emojis from vocab pair
	2. Get all emojis from biome QC
	3. For each (vocab_emoji, biome_emoji) pair:
	   - Look up connection weight: |H| + L_in + L_out (VocabularyPairing)
	   - Accumulate total weight
	4. Normalize by number of connections
	"""
	var vocab_emojis = [vocab_pair.get("north", ""), vocab_pair.get("south", "")]
	var biome_emojis = _get_biome_emojis(biome)

	# Filter out empty emojis
	var filtered_emojis = []
	for emoji in vocab_emojis:
		if not emoji.is_empty():
			filtered_emojis.append(emoji)
	vocab_emojis = filtered_emojis

	if vocab_emojis.is_empty() or biome_emojis.is_empty():
		return 0.0

	var total_weight = 0.0
	var connection_count = 0
	var icon_registry = _get_icon_registry()

	# Calculate connection strengths between all vocab-biome emoji pairs
	for vocab_emoji in vocab_emojis:
		var connections = VocabularyPairing.get_connection_weights(vocab_emoji, icon_registry)

		for biome_emoji in biome_emojis:
			if connections.has(biome_emoji):
				var conn_data = connections[biome_emoji]
				var weight = conn_data.get("weight", 0.0) if conn_data is Dictionary else 0.0
				total_weight += weight
				connection_count += 1

	return total_weight / connection_count if connection_count > 0 else 0.0

static func calculate_affinity_with_populations(vocab_pair: Dictionary, biome, player_vocab_qc = null) -> float:
	"""Calculate affinity weighted by biome quantum state populations.

	This variant multiplies connection weights by current quantum populations,
	making affinity dynamic and state-dependent.

	Args:
		vocab_pair: {north: String, south: String}
		biome: Biome with quantum_computer
		player_vocab_qc: Optional player vocabulary quantum computer

	Returns:
		float: Population-weighted connection strength
	"""
	var vocab_emojis = [vocab_pair.get("north", ""), vocab_pair.get("south", "")]
	var biome_emojis = _get_biome_emojis(biome)

	# Filter out empty emojis
	var filtered_emojis = []
	for emoji in vocab_emojis:
		if not emoji.is_empty():
			filtered_emojis.append(emoji)
	vocab_emojis = filtered_emojis

	if vocab_emojis.is_empty() or biome_emojis.is_empty():
		return 0.0

	# Get current quantum populations (viz_cache-backed)
	var populations: Dictionary = {}
	for emoji in biome_emojis:
		populations[emoji] = biome.get_emoji_probability(emoji)

	var total_weight = 0.0
	var connection_count = 0
	var icon_registry = _get_icon_registry()

	# Calculate connection strengths weighted by populations
	for vocab_emoji in vocab_emojis:
		var connections = VocabularyPairing.get_connection_weights(vocab_emoji, icon_registry)

		for biome_emoji in biome_emojis:
			if connections.has(biome_emoji):
				var conn_data = connections[biome_emoji]
				var connection_weight = conn_data.get("weight", 0.0) if conn_data is Dictionary else 0.0
				var population = populations.get(biome_emoji, 0.0)

				# Weight by population (higher population = more relevant)
				total_weight += connection_weight * (1.0 + population)
				connection_count += 1

	return total_weight / connection_count if connection_count > 0 else 0.0

static func _get_biome_emojis(biome) -> Array[String]:
	"""Get all emojis registered in biome's quantum computer."""
	if not biome:
		return []

	if biome.viz_cache:
		return biome.viz_cache.get_emojis()
	return []

static func _get_icon_registry():
	"""Get the icon registry from GameStateManager."""
	# Try to get from autoload
	if Engine.has_singleton("GameStateManager"):
		var gsm = Engine.get_singleton("GameStateManager")
		if gsm and gsm.has_method("get_icon_registry"):
			return gsm.get_icon_registry()

	# Fallback: try to get from scene tree
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		var gsm = tree.root.get_node_or_null("GameStateManager")
		if gsm and gsm.has_method("get_icon_registry"):
			return gsm.get_icon_registry()

		# Last resort: try direct IconRegistry autoload access
		push_warning("BiomeAffinityCalculator: Could not find IconRegistry via GameStateManager, trying direct access")
		var icon_reg = tree.root.get_node_or_null("/root/IconRegistry")
		if icon_reg:
			return icon_reg

	push_error("BiomeAffinityCalculator: Could not find IconRegistry at all")
	return null
