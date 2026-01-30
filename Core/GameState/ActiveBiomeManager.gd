extends Node

## ActiveBiomeManager - Singleton tracking which biome is currently active/visible
## Note: No class_name needed - accessed via autoload singleton "ActiveBiomeManager"
##
## Manages biome switching with swipe transitions. All biomes continue to evolve
## in the background; this only controls which one is displayed.
##
## Now integrates with ObservationFrame for spindle-based navigation.
## The ObservationFrame is the source of truth for which biome is "neutral".
##
## Keyboard (new layout):
##   7890 = UP row (parent biome)
##   UIOP = NEUTRAL row (current biome)
##   JKL; = DOWN row (child biome)
##   - = Previous biome, = = Next biome
##
## Signals emitted for UI updates (background, tabs, plot display, quantum graph)

signal active_biome_changed(new_biome: String, old_biome: String)
signal biome_transition_requested(from_biome: String, to_biome: String, direction: int)
signal biome_order_changed(new_order: Array)

## Full biome order (for reference)
const ALL_BIOMES: Array[String] = ["StarterForest", "Village", "BioticFlux", "StellarForges", "FungalNetworks", "VolcanicWorlds"]

## Current available biomes (filtered by unlocked status - synced with ObservationFrame)
var BIOME_ORDER: Array[String] = ["StarterForest", "Village"]

## Key-to-slot mapping (UIOP slots are assigned as biomes are unlocked)
const BIOME_KEY_ORDER: Array[String] = ["T", "Y", "U", "I", "O", "P"]
const BIOME_KEYCODES: Dictionary = {
	KEY_T: 0,
	KEY_Y: 1,
	KEY_U: 2,
	KEY_I: 3,
	KEY_O: 4,
	KEY_P: 5,
}

## Slot assignment (index -> biome name or "")
var _slot_assignment: Array[String] = ["StarterForest", "Village", "", "", "", ""]

## Biome display info (for UI)
const BIOME_INFO: Dictionary = {
	"StarterForest": {"key": "T", "emoji": "🌲", "label": "Forest"},
	"Village": {"key": "Y", "emoji": "🏘️", "label": "Village"},
	"BioticFlux": {"key": "U", "emoji": "~", "label": "Flux"},
	"StellarForges": {"key": "I", "emoji": "*", "label": "Forge"},
	"FungalNetworks": {"key": "O", "emoji": ".", "label": "Fungal"},
	"VolcanicWorlds": {"key": "P", "emoji": "^", "label": "Volcanic"},
}

## Current active biome (default matches ObservationFrame's initial neutral_index = 0)
var active_biome: String = "StarterForest"

## Whether a transition is currently in progress (prevents rapid switching)
var _transitioning: bool = false

## Reference to ObservationFrame for spindle-based navigation
var _observation_frame: Node = null


func _ready() -> void:
	add_to_group("active_biome_manager")

	# Connect to ObservationFrame when it's ready
	call_deferred("_connect_to_observation_frame")


func _connect_to_observation_frame() -> void:
	"""Connect to ObservationFrame for spindle-based biome tracking."""
	_observation_frame = get_node_or_null("/root/ObservationFrame")
	if _observation_frame:
		if not _observation_frame.neutral_changed.is_connected(_on_neutral_changed):
			_observation_frame.neutral_changed.connect(_on_neutral_changed)
		# Sync initial state
		active_biome = _observation_frame.get_neutral_biome()
		# Sync unlocked biomes
		set_biome_order(_observation_frame.get_unlocked_biomes())


func _on_neutral_changed(biome: String) -> void:
	"""Handle neutral biome change from ObservationFrame."""
	if biome != active_biome:
		var old_biome = active_biome
		active_biome = biome
		active_biome_changed.emit(biome, old_biome)


func get_active_biome() -> String:
	"""Get the currently active biome name"""
	return active_biome


func set_active_biome(biome_name: String, direction: int = 0) -> void:
	"""Set the active biome with optional transition direction

	Args:
		biome_name: Name of biome to switch to
		direction: -1 = slide left, 0 = instant, 1 = slide right
	"""
	if biome_name == active_biome:
		return

	if not biome_name in BIOME_ORDER:
		push_warning("ActiveBiomeManager: Unknown biome '%s'" % biome_name)
		return

	if _transitioning:
		return  # Ignore if already transitioning

	var old_biome = active_biome
	active_biome = biome_name

	# Sync with ObservationFrame if available
	if _observation_frame and _observation_frame.get_neutral_biome() != biome_name:
		_observation_frame.set_neutral_biome(biome_name)

	# Emit transition request (for animated transitions)
	if direction != 0:
		biome_transition_requested.emit(old_biome, biome_name, direction)

	# Emit change notification (for immediate updates)
	active_biome_changed.emit(biome_name, old_biome)


func cycle_next() -> void:
	"""Cycle to the next biome (slide right animation)"""
	var idx = BIOME_ORDER.find(active_biome)
	var next_idx = (idx + 1) % BIOME_ORDER.size()
	set_active_biome(BIOME_ORDER[next_idx], 1)  # direction = 1 (right)


func cycle_prev() -> void:
	"""Cycle to the previous biome (slide left animation)"""
	var idx = BIOME_ORDER.find(active_biome)
	var prev_idx = (idx - 1 + BIOME_ORDER.size()) % BIOME_ORDER.size()
	set_active_biome(BIOME_ORDER[prev_idx], -1)  # direction = -1 (left)


func select_biome_by_key(keycode: int) -> bool:
	"""Handle direct biome selection by key (7, 8, 9, 0)

	Returns: true if key was handled, false otherwise
	"""
	if BIOME_KEYCODES.has(keycode):
		var slot_idx = BIOME_KEYCODES[keycode]
		var biome_name = get_biome_for_slot(slot_idx)
		if biome_name == "":
			return true  # Slot is unassigned, consume the key
		var direction = _get_direction_to(biome_name)
		set_active_biome(biome_name, direction)
		return true
	return false


func handle_cycle_input(keycode: int) -> bool:
	"""Handle biome cycling keys (- and =)

	Returns: true if key was handled, false otherwise
	"""
	if keycode == KEY_MINUS:
		cycle_prev()
		return true
	elif keycode == KEY_EQUAL:
		cycle_next()
		return true
	return false


func _get_direction_to(target_biome: String) -> int:
	"""Calculate slide direction from current to target biome"""
	var current_idx = BIOME_ORDER.find(active_biome)
	var target_idx = BIOME_ORDER.find(target_biome)

	if target_idx > current_idx:
		return 1  # Slide right
	elif target_idx < current_idx:
		return -1  # Slide left
	return 0  # Same biome


func set_transitioning(value: bool) -> void:
	"""Called by BiomeBackground when transition starts/ends"""
	_transitioning = value


func get_biome_index(biome_name: String) -> int:
	"""Get the index of a biome in BIOME_ORDER"""
	return BIOME_ORDER.find(biome_name)


func get_biome_at_index(index: int) -> String:
	"""Get biome name at index"""
	if index >= 0 and index < BIOME_ORDER.size():
		return BIOME_ORDER[index]
	return ""


func get_biome_count() -> int:
	"""Get total number of biomes"""
	return BIOME_ORDER.size()


func get_biome_for_slot(slot_idx: int) -> String:
	"""Get the biome assigned to a key slot (T/Y/U/I/O/P)."""
	if slot_idx < 0:
		return ""
	if slot_idx >= _slot_assignment.size():
		return ""
	return _slot_assignment[slot_idx]


func get_slot_key(slot_idx: int) -> String:
	"""Get the key label for a slot index."""
	if slot_idx < 0 or slot_idx >= BIOME_KEY_ORDER.size():
		return ""
	return BIOME_KEY_ORDER[slot_idx]


func get_slot_count() -> int:
	"""Total number of biome slots (UIOP row)."""
	return BIOME_KEY_ORDER.size()


func get_open_slot_count() -> int:
	"""Number of unassigned biome slots available."""
	if _slot_assignment.size() != BIOME_KEY_ORDER.size():
		_rebuild_slot_assignment()
	var open_count = 0
	for slot in _slot_assignment:
		if slot == "":
			open_count += 1
	return open_count


func has_open_biome_slot() -> bool:
	"""True if there is at least one unassigned biome slot."""
	return get_open_slot_count() > 0


func get_biome_order() -> Array[String]:
	"""Get the current unlocked biome order."""
	return BIOME_ORDER.duplicate()


func set_biome_order(new_order: Array) -> void:
	"""Replace the current unlocked biome order and notify listeners."""
	BIOME_ORDER = new_order.duplicate()
	if not active_biome in BIOME_ORDER and BIOME_ORDER.size() > 0:
		active_biome = BIOME_ORDER[0]
	_rebuild_slot_assignment()
	biome_order_changed.emit(BIOME_ORDER.duplicate())


func get_biome_info(biome_name: String) -> Dictionary:
	"""Get display info for a biome"""
	return BIOME_INFO.get(biome_name, {})


func reset() -> void:
	"""Reset to initial state (for dev restart)."""
	active_biome = "StarterForest"
	set_biome_order(["StarterForest", "Village"])
	_transitioning = false
	_observation_frame = null


func _rebuild_slot_assignment() -> void:
	"""Rebuild slot->biome mapping with T/Y fixed and extras on UIOP."""
	_slot_assignment = ["", "", "", "", "", ""]

	# Slot 0 (T) = StarterForest if unlocked
	if "StarterForest" in BIOME_ORDER:
		_slot_assignment[0] = "StarterForest"

	# Slot 1 (Y) = Village if unlocked
	if "Village" in BIOME_ORDER:
		_slot_assignment[1] = "Village"

	# Fill remaining slots in unlock order, skipping fixed biomes
	var slot_idx = 2
	for biome_name in BIOME_ORDER:
		if biome_name == "StarterForest" or biome_name == "Village":
			continue
		if slot_idx >= _slot_assignment.size():
			break
		_slot_assignment[slot_idx] = biome_name
		slot_idx += 1
