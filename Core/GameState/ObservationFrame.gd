extends Node

## ObservationFrame - Manages the spindle (which biome is neutral in the fractal address)
##
## The observation frame determines the reference point for fractal navigation:
## - NEUTRAL (UIOP row): Current biome at neutral_index
## - UP (7890 row): Parent biome at neutral_index - 1
## - DOWN (JKL; row): Child biome at neutral_index + 1
##
## Selecting plots in UP or DOWN rows shifts the spindle, making that biome
## the new neutral reference point.

## Full biome order (loadable biomes from registry + icon build)
var ALL_BIOMES: Array[String] = []

## Current available biomes (filtered by unlocked status from GameState)
## Starts with ["StarterForest", "Village"], grows as player explores
var BIOME_ORDER: Array[String] = ["StarterForest", "Village"]

## Current neutral index in BIOME_ORDER
var neutral_index: int = 0

const BiomeRegistry = preload("res://Core/Biomes/BiomeRegistry.gd")
const BiomeIconCache = preload("res://Core/Biomes/BiomeIconCache.gd")

var _biome_registry: BiomeRegistry = null
var _icon_cache: BiomeIconCache = null

## Signals
signal frame_shifted(old_biome: String, new_biome: String, direction: int)
signal neutral_changed(biome: String)


func _ready() -> void:
	add_to_group("observation_frame")
	# Initialize from GameState if available
	call_deferred("_load_unlocked_biomes")


## Get the current neutral biome
func get_neutral_biome() -> String:
	return BIOME_ORDER[neutral_index]


## Get biome at a given offset from neutral
## offset: -1 = DOWN (JKL; row), 0 = NEUTRAL (UIOP row), +1 = UP (7890 row)
func get_biome_at_offset(offset: int) -> String:
	# UP (+1) means we go to earlier index, DOWN (-1) means later index
	# This creates the hierarchical parent/child relationship
	var idx = (neutral_index - offset) % BIOME_ORDER.size()
	if idx < 0:
		idx += BIOME_ORDER.size()
	return BIOME_ORDER[idx]


## Shift the observation frame
## direction: -1 = shift DOWN (selected child becomes neutral)
##            +1 = shift UP (selected parent becomes neutral)
func shift(direction: int) -> void:
	if direction == 0:
		return

	var old_biome = get_neutral_biome()

	# Shift the neutral index
	# When selecting UP (+1), we shift neutral_index down (-1) so that biome becomes new neutral
	# When selecting DOWN (-1), we shift neutral_index up (+1) so that biome becomes new neutral
	neutral_index = (neutral_index - direction) % BIOME_ORDER.size()
	if neutral_index < 0:
		neutral_index += BIOME_ORDER.size()

	var new_biome = get_neutral_biome()

	frame_shifted.emit(old_biome, new_biome, direction)
	neutral_changed.emit(new_biome)


## Set the neutral biome directly by name
func set_neutral_biome(biome_name: String) -> void:
	var idx = BIOME_ORDER.find(biome_name)
	if idx >= 0 and idx != neutral_index:
		var old_biome = get_neutral_biome()
		neutral_index = idx
		frame_shifted.emit(old_biome, biome_name, 0)
		neutral_changed.emit(biome_name)


## Get the direction to shift from current neutral to reach target biome
func get_direction_to(target_biome: String) -> int:
	var target_idx = BIOME_ORDER.find(target_biome)
	if target_idx < 0:
		return 0

	if target_idx == neutral_index:
		return 0

	# Calculate shortest path direction
	var forward_dist = (target_idx - neutral_index + BIOME_ORDER.size()) % BIOME_ORDER.size()
	var backward_dist = (neutral_index - target_idx + BIOME_ORDER.size()) % BIOME_ORDER.size()

	if forward_dist <= backward_dist:
		return -1  # DOWN direction gets us there
	else:
		return 1   # UP direction gets us there


## Get index of a biome in BIOME_ORDER
func get_biome_index(biome_name: String) -> int:
	return BIOME_ORDER.find(biome_name)


## Get biome at a specific index
func get_biome_at_index(index: int) -> String:
	if index >= 0 and index < BIOME_ORDER.size():
		return BIOME_ORDER[index]
	return ""


## Get total number of biomes
func get_biome_count() -> int:
	return BIOME_ORDER.size()


## Check if a biome is currently the neutral reference
func is_neutral(biome_name: String) -> bool:
	return biome_name == get_neutral_biome()


## Get the current neutral index
func get_neutral_index() -> int:
	return neutral_index


func _load_unlocked_biomes() -> void:
	"""Load unlocked biomes from GameState"""
	_refresh_loadable_biomes()
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state and "unlocked_biomes" in gsm.current_state:
		var unlocked = gsm.current_state.unlocked_biomes
		# Clamp unlocked biomes to loadable list (keeps save data sane)
		unlocked = unlocked.filter(func(b): return b in ALL_BIOMES)
		if unlocked.size() > 0:
			BIOME_ORDER = unlocked.duplicate()
			# Clamp neutral_index to valid range
			if neutral_index >= BIOME_ORDER.size():
				neutral_index = 0

	# Refresh unexplored pool against loadable list
	if gsm and gsm.current_state and "unexplored_biome_pool" in gsm.current_state:
		var pool = gsm.current_state.unexplored_biome_pool
		var refreshed: Array[String] = []
		# Preserve existing order where possible
		for biome_name in pool:
			if biome_name in ALL_BIOMES and biome_name not in BIOME_ORDER and biome_name not in refreshed:
				refreshed.append(biome_name)
		# Add any missing loadable biomes
		for biome_name in ALL_BIOMES:
			if biome_name not in BIOME_ORDER and biome_name not in refreshed:
				refreshed.append(biome_name)
		gsm.current_state.unexplored_biome_pool = refreshed


func unlock_biome(biome_name: String) -> bool:
	"""Add a biome to the unlocked list

	Returns true if biome was newly unlocked, false if already unlocked
	"""
	if biome_name in BIOME_ORDER:
		return false  # Already unlocked

	if biome_name not in ALL_BIOMES:
		push_warning("ObservationFrame: Unknown biome '%s'" % biome_name)
		return false

	BIOME_ORDER.append(biome_name)

	# Persist to GameState
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state:
		gsm.current_state.unlocked_biomes = BIOME_ORDER.duplicate()
		# Remove from unexplored pool
		if "unexplored_biome_pool" in gsm.current_state:
			var pool = gsm.current_state.unexplored_biome_pool
			var idx = pool.find(biome_name)
			if idx >= 0:
				pool.remove_at(idx)

	return true


func get_unlocked_biomes() -> Array[String]:
	"""Get list of unlocked biomes"""
	return BIOME_ORDER.duplicate()


func get_explored_biomes() -> Array[String]:
	"""Alias for unlocked biomes (preferred terminology)."""
	return get_unlocked_biomes()


func get_loadable_biomes() -> Array[String]:
	"""Get biomes that are valid/loadable (icon build succeeded)."""
	_refresh_loadable_biomes()
	return ALL_BIOMES.duplicate()


func get_unexplored_biomes() -> Array[String]:
	"""Get list of biomes not yet unlocked"""
	var unexplored: Array[String] = []
	for biome in ALL_BIOMES:
		if biome not in BIOME_ORDER:
			unexplored.append(biome)
	return unexplored


## Reset to initial state (for dev restart)
func reset() -> void:
	BIOME_ORDER = ["StarterForest", "Village"]
	neutral_index = 0


func _refresh_loadable_biomes() -> void:
	"""Build icon sets for biomes and refresh the loadable biome list."""
	if _biome_registry == null:
		_biome_registry = BiomeRegistry.new()
	if _icon_cache == null:
		_icon_cache = BiomeIconCache.new()

	var loadable: Array[String] = []
	for biome in _biome_registry.get_all():
		if not biome:
			continue
		var name = biome.name
		# Build icons (cached) to validate biome is loadable
		var icons = _icon_cache.get_icons_for_biome(name)
		if icons.size() > 0:
			loadable.append(name)

	# Fallback to defaults if nothing built
	if loadable.is_empty():
		loadable = ["StarterForest", "Village"]

	ALL_BIOMES = loadable
