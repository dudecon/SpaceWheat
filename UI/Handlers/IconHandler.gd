class_name IconHandler
extends RefCounted

## IconHandler - Static handler for icon/vocabulary management operations
##
## Follows ProbeActions pattern:
## - Static methods only
## - Explicit parameters (no implicit state)
## - Dictionary returns with {success: bool, ...data, error?: String}

const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")


static func _has_emoji(biome, emoji: String) -> bool:
	"""Check if emoji exists in biome via viz_cache metadata."""
	if not biome or emoji == "":
		return false
	if biome.viz_cache and biome.viz_cache.has_metadata():
		return biome.viz_cache.get_qubit(emoji) >= 0
	return false


## ============================================================================
## ICON ASSIGNMENT OPERATIONS
## ============================================================================

static func icon_assign(farm, positions: Array[Vector2i], emoji: String, _game_state_manager = null) -> Dictionary:
	"""Assign a vocabulary emoji to the biome's quantum system.

	Injects a new qubit axis (north/south pair) into the biome's quantum computer.
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	# Look up the pair from farm-owned vocabulary
	if not farm or not farm.has_method("get_pair_for_emoji"):
		return {
			"success": false,
			"error": "no_vocab_owner",
			"message": "Farm vocabulary not available"
		}

	var pair = farm.get_pair_for_emoji(emoji)
	if not pair:
		return {
			"success": false,
			"error": "emoji_not_in_vocabulary",
			"message": "Emoji %s not in vocabulary" % emoji
		}

	var north = pair.get("north", "")
	var south = pair.get("south", "")
	if north == "" or south == "":
		return {
			"success": false,
			"error": "invalid_pair",
			"message": "Invalid pair for %s" % emoji
		}

	# Get the biome for the first selected plot
	var pos = positions[0]
	var biome = farm.grid.get_biome_for_plot(pos)
	if not biome:
		return {
			"success": false,
			"error": "no_biome",
			"message": "No biome at position"
		}
	if not biome.viz_cache or not biome.viz_cache.has_metadata():
		return {
			"success": false,
			"error": "no_viz_cache",
			"message": "Biome visualization data not ready"
		}
	var qubit_count = biome.get_total_register_count() if biome.has_method("get_total_register_count") else 0
	if qubit_count >= EconomyConstants.MAX_BIOME_QUBITS:
		return {
			"success": false,
			"error": "qubit_cap_reached",
			"message": "Biome is at max capacity (%d qubits)" % EconomyConstants.MAX_BIOME_QUBITS
		}

	# Check if either emoji already exists in biome (prevent axis conflicts)
	if _has_emoji(biome, north):
		return {
			"success": false,
			"error": "already_exists",
			"message": "%s already in biome" % north
		}
	if _has_emoji(biome, south):
		return {
			"success": false,
			"error": "already_exists",
			"message": "%s already in biome" % south
		}

	# Expand quantum system with the pair
	var result = biome.expand_quantum_system(north, south)
	if result.success:
		return {
			"success": true,
			"north_emoji": north,
			"south_emoji": south,
			"biome_type": biome.get_biome_type() if biome.has_method("get_biome_type") else "unknown"
		}
	else:
		return {
			"success": false,
			"error": result.get("error", "expansion_failed"),
			"message": result.get("message", "Failed to expand quantum system")
		}


static func icon_swap(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Swap north/south emojis on selected plots.

	Exchanges which outcome is considered "success" vs "failure".
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var swap_count = 0
	var results: Array = []

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_active():
			continue

		# Swap north and south emojis via terminal
		var old_north = plot.get_north_emoji()
		var old_south = plot.get_south_emoji()

		if plot.bound_terminal and plot.bound_terminal.has_method("set_emoji_pair"):
			plot.bound_terminal.set_emoji_pair({"north": old_south, "south": old_north})
		elif plot.bound_terminal:
			plot.bound_terminal.north_emoji = old_south
			plot.bound_terminal.south_emoji = old_north

		swap_count += 1
		results.append({
			"position": pos,
			"old_north": old_north,
			"old_south": old_south,
			"new_north": plot.get_north_emoji(),
			"new_south": plot.get_south_emoji()
		})

	return {
		"success": swap_count > 0,
		"swap_count": swap_count,
		"results": results
	}


static func icon_clear(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Clear icon assignment from selected plots.

	Resets plots to their default biome icons.
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var clear_count = 0
	var results: Array = []

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot:
			continue

		var old_north = plot.get_north_emoji()
		var old_south = plot.get_south_emoji()

		# Get default icons from biome and set on terminal
		var biome = farm.grid.get_biome_for_plot(pos)
		if plot.bound_terminal:
			if biome and biome.producible_emojis.size() >= 2:
				var new_pair = {"north": biome.producible_emojis[0], "south": biome.producible_emojis[1]}
				if plot.bound_terminal.has_method("set_emoji_pair"):
					plot.bound_terminal.set_emoji_pair(new_pair)
				else:
					plot.bound_terminal.north_emoji = new_pair["north"]
					plot.bound_terminal.south_emoji = new_pair["south"]

		clear_count += 1
		results.append({
			"position": pos,
			"old_north": old_north,
			"old_south": old_south,
			"new_north": plot.get_north_emoji(),
			"new_south": plot.get_south_emoji()
		})

	return {
		"success": clear_count > 0,
		"clear_count": clear_count,
		"results": results
	}


## ============================================================================
## VOCABULARY QUERY OPERATIONS
## ============================================================================

static func get_available_icons(farm = null) -> Dictionary:
	"""Get list of available icons from player's vocabulary."""
	if not farm:
		return {
			"success": false,
			"error": "no_farm",
			"message": "Farm not available"
		}

	var icons: Array = []

	if farm.has_method("get_known_pairs"):
		var pairs = farm.get_known_pairs()
		for pair in pairs:
			icons.append({
				"north": pair.get("north", ""),
				"south": pair.get("south", "")
			})

	return {
		"success": true,
		"icons": icons,
		"count": icons.size()
	}


static func get_biome_icons(farm, position: Vector2i) -> Dictionary:
	"""Get icons currently in use by biome at position."""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	var biome = farm.grid.get_biome_for_plot(position)
	if not biome:
		return {
			"success": false,
			"error": "no_biome",
			"message": "No biome at position"
		}

	var icons: Array = []

	# Get from viz_cache metadata
	if biome.viz_cache:
		icons = biome.viz_cache.get_emojis()

	# Also include producible emojis
	var producible = biome.producible_emojis if biome.producible_emojis else []

	return {
		"success": true,
		"register_icons": icons,
		"producible_icons": producible,
		"biome_type": biome.get_biome_type() if biome.has_method("get_biome_type") else "unknown"
	}
