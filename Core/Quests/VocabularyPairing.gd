class_name VocabularyPairing
extends RefCounted

## Vocabulary Pairing System
##
## When a player learns a new emoji (North) from a faction quest,
## this system rolls for a partner emoji (South) based on
## physics connections: |H| + L_in + L_out
##
## The pair forms a qubit axis that can be planted in biomes.


## Get IconRegistry from scene tree
static func _get_icon_registry():
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		return tree.root.get_node_or_null("/root/IconRegistry")
	return null


## Roll a partner (South) for a given North emoji
## Returns: {"south": emoji, "weight": float, "connections": Dictionary}
static func roll_partner(north_emoji: String) -> Dictionary:
	var icon_registry = _get_icon_registry()

	if not icon_registry:
		push_error("VocabularyPairing: IconRegistry not found")
		return {"south": "", "error": "no_icon_registry"}

	var connections = get_connection_weights(north_emoji, icon_registry)

	if connections.is_empty():
		push_warning("VocabularyPairing: No connections for %s" % north_emoji)
		return {"south": "", "error": "no_connections", "north": north_emoji}

	# Calculate total weight
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


## Get all connection weights for an emoji
## Uses: |H| + L_in + L_out (absolute values, merged)
static func get_connection_weights(emoji: String, icon_registry) -> Dictionary:
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
