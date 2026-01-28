class_name VocabularyPairing
extends RefCounted

## Vocabulary Pairing System (South-First Design)
##
## NEW ORDER: South pole is calculated FIRST, then North pole.
##
## 1. SOUTH pole: Rolled first, biased heavily by player's resource quantities.
##    This is the "cost" side - players spend what they have.
##
## 2. NORTH pole: Rolled second, based on connections to the South emoji.
##    This is the "discovery" side - players learn something new.
##    North cannot be an emoji already in player's vocabulary.
##
## The pair forms a qubit axis that can be planted in biomes.


## Get IconRegistry from scene tree
static func _get_icon_registry():
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		return tree.root.get_node_or_null("/root/IconRegistry")
	return null


## Roll a complete vocabulary pair (South first, then North)
## Returns: {"north": emoji, "south": emoji, "weight": float, ...}
##
## Algorithm:
## 1. Roll SOUTH pole first (biased by player resources)
## 2. Roll NORTH pole second (connected to South, can't be in known vocab)
static func roll_pair(known_vocab: Array = []) -> Dictionary:
	var icon_registry = _get_icon_registry()

	if not icon_registry:
		push_error("VocabularyPairing: IconRegistry not found")
		return {"error": "no_icon_registry"}

	# Step 1: Roll SOUTH pole (biased by player resources)
	var south_result = _roll_south_pole(icon_registry)
	if south_result.get("error"):
		return south_result

	var south_emoji = south_result.south

	# Step 2: Roll NORTH pole (connected to South, not in known vocab)
	var north_result = _roll_north_pole(south_emoji, known_vocab, icon_registry)
	if north_result.get("error"):
		return north_result

	return {
		"north": north_result.north,
		"south": south_emoji,
		"south_weight": south_result.weight,
		"north_weight": north_result.weight,
		"south_connections": south_result.connections,
		"north_connections": north_result.connections
	}


## Roll SOUTH pole - biased heavily by player resource quantities
static func _roll_south_pole(icon_registry) -> Dictionary:
	var economy = _get_economy()
	if not economy:
		return {"error": "no_economy", "message": "Economy not available"}

	# Get all emojis player has resources for
	var candidates = {}
	var all_resources = {}
	if economy.has_method("get_all_resources"):
		all_resources = economy.get_all_resources()
	elif "emoji_credits" in economy:
		all_resources = economy.emoji_credits

	# Build weighted candidates from player's resources
	for emoji in all_resources:
		var amount = all_resources[emoji]
		if amount <= 0:
			continue

		# Check if this emoji has connections (can be paired)
		var connections = get_connection_weights(emoji, icon_registry)
		if connections.is_empty():
			continue

		# Weight = resource bias using raw credit values
		var weight = 1.0 + log(1.0 + amount) / 3.0
		candidates[emoji] = {"weight": weight, "amount": amount, "connections": connections}

	if candidates.is_empty():
		return {"error": "no_resources", "message": "No resources available for pairing"}

	# Weighted random selection
	var total_weight = 0.0
	for emoji in candidates:
		total_weight += candidates[emoji].weight

	var roll = randf() * total_weight
	var cumulative = 0.0

	for emoji in candidates:
		cumulative += candidates[emoji].weight
		if roll <= cumulative:
			return {
				"south": emoji,
				"weight": candidates[emoji].weight,
				"amount": candidates[emoji].amount,
				"connections": candidates[emoji].connections
			}

	# Fallback
	var first = candidates.keys()[0]
	return {
		"south": first,
		"weight": candidates[first].weight,
		"amount": candidates[first].amount,
		"connections": candidates[first].connections
	}


## Roll SOUTH pole from faction signature (weighted by player inventory)
static func _roll_south_pole_from_signature(icon_registry, faction_signature: Array) -> Dictionary:
	"""Roll south pole from faction signature, weighted by player inventory

	South pole can be known OR unknown to player.
	Weights use log formula: weight = 1.0 + log(1.0 + amount) / 3.0

	Args:
		icon_registry: IconRegistry for connection data
		faction_signature: Faction's signature emojis

	Returns:
		{south, weight, amount, connections} or {error, message}
	"""
	var economy = _get_economy()
	if not economy:
		return {"error": "no_economy", "message": "Economy not available"}

	# Get all resources
	var all_resources = {}
	if economy.has_method("get_all_resources"):
		all_resources = economy.get_all_resources()
	elif "emoji_credits" in economy:
		all_resources = economy.emoji_credits

	# Build weighted candidates from faction signature
	var candidates = {}
	for emoji in faction_signature:
		# Get player's inventory amount for this emoji (0 if none)
		var amount = all_resources.get(emoji, 0)

		# Check if this emoji has connections (can be paired)
		var connections = get_connection_weights(emoji, icon_registry)
		if connections.is_empty():
			continue

		# Weight = inventory bias using log formula (even if amount is 0)
		# Formula: 1.0 + log(1.0 + amount) / 3.0
		#   0 credits → 1.0 (base weight)
		#   50 credits → ~1.6x
		#   500 credits → ~2.4x
		var weight = 1.0 + log(1.0 + amount) / 3.0
		candidates[emoji] = {"weight": weight, "amount": amount, "connections": connections}

	if candidates.is_empty():
		return {"error": "no_candidates", "message": "No pairable emojis in faction signature"}

	# Weighted random selection
	var total_weight = 0.0
	for emoji in candidates:
		total_weight += candidates[emoji].weight

	var roll = randf() * total_weight
	var cumulative = 0.0

	for emoji in candidates:
		cumulative += candidates[emoji].weight
		if roll <= cumulative:
			return {
				"south": emoji,
				"weight": candidates[emoji].weight,
				"amount": candidates[emoji].amount,
				"connections": candidates[emoji].connections
			}

	# Fallback
	var first = candidates.keys()[0]
	return {
		"south": first,
		"weight": candidates[first].weight,
		"amount": candidates[first].amount,
		"connections": candidates[first].connections
	}


## Roll SOUTH pole - constrained to specific vocabulary (for faction quests)
static func _roll_south_pole_constrained(icon_registry, allowed_vocab: Array) -> Dictionary:
	"""Roll south pole from a constrained vocabulary list (faction-specific)

	Similar to _roll_south_pole() but only considers emojis in allowed_vocab.
	Used for faction quests where south pole must come from faction signature.

	Args:
		icon_registry: IconRegistry for connection data
		allowed_vocab: Array of allowed emoji strings (e.g., faction signature)

	Returns:
		{south, weight, amount, connections} or {error, message}
	"""
	var economy = _get_economy()
	if not economy:
		return {"error": "no_economy", "message": "Economy not available"}

	# Get all resources
	var all_resources = {}
	if economy.has_method("get_all_resources"):
		all_resources = economy.get_all_resources()
	elif "emoji_credits" in economy:
		all_resources = economy.emoji_credits

	# Build weighted candidates from ALLOWED vocabulary only
	var candidates = {}
	for emoji in allowed_vocab:
		# Must have resources for this emoji
		var amount = all_resources.get(emoji, 0)
		if amount <= 0:
			continue

		# Must have connections (can be paired)
		var connections = get_connection_weights(emoji, icon_registry)
		if connections.is_empty():
			continue

		# Weight = resource bias using raw credit values
		var weight = 1.0 + log(1.0 + amount) / 3.0
		candidates[emoji] = {"weight": weight, "amount": amount, "connections": connections}

	if candidates.is_empty():
		return {"error": "no_resources", "message": "No resources available in allowed vocabulary"}

	# Weighted random selection
	var total_weight = 0.0
	for emoji in candidates:
		total_weight += candidates[emoji].weight

	var roll = randf() * total_weight
	var cumulative = 0.0

	for emoji in candidates:
		cumulative += candidates[emoji].weight
		if roll <= cumulative:
			return {
				"south": emoji,
				"weight": candidates[emoji].weight,
				"amount": candidates[emoji].amount,
				"connections": candidates[emoji].connections
			}

	# Fallback
	var first = candidates.keys()[0]
	return {
		"south": first,
		"weight": candidates[first].weight,
		"amount": candidates[first].amount,
		"connections": candidates[first].connections
	}


## Roll NORTH pole - connected to South, excluding known vocabulary
static func _roll_north_pole(south_emoji: String, known_vocab: Array, icon_registry) -> Dictionary:
	var connections = get_connection_weights(south_emoji, icon_registry)

	if connections.is_empty():
		return {"error": "no_connections", "message": "No connections for %s" % south_emoji}

	# Filter out emojis already in player's vocabulary
	var filtered = {}
	for target in connections:
		if target not in known_vocab and target != south_emoji:
			filtered[target] = connections[target]

	if filtered.is_empty():
		# All connections are known - allow any connection as fallback
		push_warning("VocabularyPairing: All connections for %s are known, using unfiltered" % south_emoji)
		filtered = connections.duplicate()
		# Still remove self
		filtered.erase(south_emoji)

	if filtered.is_empty():
		return {"error": "no_valid_north", "message": "No valid north pole for %s" % south_emoji}

	# Calculate total weight
	var total_weight = 0.0
	for target in filtered:
		total_weight += filtered[target]["weight"]

	if total_weight <= 0:
		return {"error": "zero_weight", "message": "Zero total weight for north candidates"}

	# Weighted random roll
	var roll = randf() * total_weight
	var cumulative = 0.0

	for target in filtered:
		cumulative += filtered[target]["weight"]
		if roll <= cumulative:
			return {
				"north": target,
				"weight": filtered[target]["weight"],
				"probability": filtered[target]["weight"] / total_weight,
				"connections": filtered
			}

	# Fallback
	var first = filtered.keys()[0]
	return {
		"north": first,
		"weight": filtered[first]["weight"],
		"probability": filtered[first]["weight"] / total_weight,
		"connections": filtered
	}


## LEGACY: Roll a partner (South) for a given North emoji
## Kept for backward compatibility - prefer roll_pair() for new code
static func roll_partner(north_emoji: String) -> Dictionary:
	var icon_registry = _get_icon_registry()

	if not icon_registry:
		push_error("VocabularyPairing: IconRegistry not found")
		return {"south": "", "error": "no_icon_registry"}

	var connections = get_connection_weights(north_emoji, icon_registry)

	if connections.is_empty():
		push_warning("VocabularyPairing: No connections for %s" % north_emoji)
		return {"south": "", "error": "no_connections", "north": north_emoji}

	# Apply resource quantity bias to weights
	_apply_resource_bias(connections)

	# Calculate total weight (after resource bias applied)
	var total_weight = 0.0
	for target in connections:
		total_weight += connections[target]["weight"]

	if total_weight <= 0:
		return {"south": "", "error": "zero_weight", "north": north_emoji}

	# Weighted random roll
	var roll = randf() * total_weight
	var cumulative = 0.0

	for target in connections:
		cumulative += connections[target]["weight"]
		if roll <= cumulative:
			return {
				"north": north_emoji,
				"south": target,
				"weight": connections[target]["weight"],
				"probability": connections[target]["weight"] / total_weight,
				"connections": connections,
				"total_weight": total_weight
			}

	# Fallback (shouldn't reach here)
	var first_target = connections.keys()[0]
	return {
		"north": north_emoji,
		"south": first_target,
		"weight": connections[first_target]["weight"],
		"probability": connections[first_target]["weight"] / total_weight,
		"connections": connections,
		"total_weight": total_weight
	}


## Apply resource quantity bias to connection weights
## Modifies weights in-place based on player's emoji-credit resources
## Formula: weight *= (1.0 + log(1 + credits) / 3.0)
##   0 credits → 1.0x (no bias)
##   50 credits → ~1.6x
##   500 credits → ~2.4x
static func _apply_resource_bias(connections: Dictionary) -> void:
	var economy = _get_economy()
	if not economy or not economy.has_method("get_resource"):
		return  # No economy available, skip bias

	for target in connections:
		var credits = economy.get_resource(target)

		if credits <= 0:
			continue  # No bias for resources player doesn't have

		# Logarithmic bias using raw credit values
		var bias_multiplier = 1.0 + log(1.0 + credits) / 3.0

		# Apply bias to existing weight
		connections[target]["weight"] *= bias_multiplier
		connections[target]["resource_bias"] = bias_multiplier


## Get FarmEconomy from scene tree
static func _get_economy():
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var gsm = tree.root.get_node_or_null("/root/GameStateManager")
		if gsm and "active_farm" in gsm and gsm.active_farm:
			return gsm.active_farm.get("economy")
	return null


## Calculate vocabulary connectivity: sum of connection weights to player's known emojis
## Used for weighting North pole candidates by how well-connected they are to player's vocab
static func calculate_vocab_connectivity(emoji: String, player_vocab: Array, icon_registry) -> float:
	"""Calculate sum of connection weights from emoji to player's known vocabulary

	Returns sum of (|H| + L_in + L_out) for all connections to player_vocab emojis.

	Example:
		emoji 🔥 connected to:
			🌾 (weight 0.5), 👥 (weight 0.8), ⚡ (weight 0.3)
		player_vocab = [🌾, 👥, 💰]
		Returns: 0.5 + 0.8 = 1.3 (sum of weights to known emojis)

	Args:
		emoji: The emoji to check connectivity for
		player_vocab: Player's known emojis
		icon_registry: IconRegistry for connection data

	Returns:
		Sum of connection weights to player_vocab (0.0 if no connections)
	"""
	var connections = get_connection_weights(emoji, icon_registry)

	var total_connectivity = 0.0
	for target in connections:
		if target in player_vocab:
			total_connectivity += connections[target]["weight"]

	return total_connectivity


## Get all connection weights for an emoji
## Uses: |H| + L_in + L_out (absolute values, merged)
static func get_connection_weights(emoji: String, icon_registry) -> Dictionary:
	if not icon_registry:
		push_warning("VocabularyPairing.get_connection_weights: icon_registry is null")
		return {}

	var icon = icon_registry.get_icon(emoji)
	if not icon:
		return {}

	var connections = {}  # target -> {weight, h, l_in, l_out}

	# Hamiltonian couplings (absolute value)
	for target in icon.hamiltonian_couplings:
		var val = icon.hamiltonian_couplings[target]
		if val is float or val is int:
			if not connections.has(target):
				connections[target] = {"h": 0.0, "l_in": 0.0, "l_out": 0.0, "weight": 0.0}
			connections[target]["h"] = abs(val)

	# Lindblad outgoing (absolute value)
	for target in icon.lindblad_outgoing:
		var val = icon.lindblad_outgoing[target]
		if val is float or val is int:
			if not connections.has(target):
				connections[target] = {"h": 0.0, "l_in": 0.0, "l_out": 0.0, "weight": 0.0}
			connections[target]["l_out"] = abs(val)

	# Lindblad incoming (absolute value)
	for source in icon.lindblad_incoming:
		var val = icon.lindblad_incoming[source]
		if val is float or val is int:
			if not connections.has(source):
				connections[source] = {"h": 0.0, "l_in": 0.0, "l_out": 0.0, "weight": 0.0}
			connections[source]["l_in"] = abs(val)

	# Calculate total weights
	for target in connections:
		var c = connections[target]
		c["weight"] = c["h"] + c["l_in"] + c["l_out"]

	# Remove zero-weight connections
	var to_remove = []
	for target in connections:
		if connections[target]["weight"] <= 0:
			to_remove.append(target)
	for target in to_remove:
		connections.erase(target)

	return connections


## Get sorted connection list for display/debugging
static func get_sorted_connections(emoji: String, icon_registry) -> Array:
	var connections = get_connection_weights(emoji, icon_registry)

	var total_weight = 0.0
	for target in connections:
		total_weight += connections[target]["weight"]

	var sorted_list = []
	for target in connections:
		sorted_list.append({
			"emoji": target,
			"weight": connections[target]["weight"],
			"probability": connections[target]["weight"] / total_weight if total_weight > 0 else 0,
			"h": connections[target]["h"],
			"l_in": connections[target]["l_in"],
			"l_out": connections[target]["l_out"]
		})

	sorted_list.sort_custom(func(a, b): return a.weight > b.weight)
	return sorted_list


## Reroll partner (same distribution, fresh roll)
static func reroll_partner(north_emoji: String) -> Dictionary:
	return roll_partner(north_emoji)


## Format pair for display
static func format_pair(north: String, south: String) -> String:
	return "%s/%s" % [north, south]


## Check if an emoji has any connections (can be paired)
static func can_be_paired(emoji: String) -> bool:
	var icon_registry = _get_icon_registry()
	if not icon_registry:
		return false

	var connections = get_connection_weights(emoji, icon_registry)
	return not connections.is_empty()
