extends Node

## ActiveBiomeManager - Singleton tracking which biome is currently active/visible
## Note: No class_name needed - accessed via autoload singleton "ActiveBiomeManager"
##
## Manages biome switching with swipe transitions. All biomes continue to evolve
## in the background; this only controls which one is displayed.
##
## Keyboard:
##   7 = BioticFlux, 8 = Market, 9 = Forest, 0 = Kitchen
##   , = Previous biome, . = Next biome
##
## Signals emitted for UI updates (background, tabs, plot display, quantum graph)

signal active_biome_changed(new_biome: String, old_biome: String)
signal biome_transition_requested(from_biome: String, to_biome: String, direction: int)

## Biome order for cycling (matches keyboard layout left-to-right conceptually)
const BIOME_ORDER: Array[String] = ["BioticFlux", "StellarForges", "FungalNetworks", "VolcanicWorlds"]

## Key-to-biome mapping
const BIOME_KEYS: Dictionary = {
	KEY_7: "BioticFlux",
	KEY_8: "StellarForges",
	KEY_9: "FungalNetworks",
	KEY_0: "VolcanicWorlds",
}

## Biome display info (for UI)
const BIOME_INFO: Dictionary = {
	"BioticFlux": {"key": "7", "emoji": "🌿", "label": "Flux"},
	"StellarForges": {"key": "8", "emoji": "🚀", "label": "Forge"},
	"FungalNetworks": {"key": "9", "emoji": "🍄", "label": "Fungal"},
	"VolcanicWorlds": {"key": "0", "emoji": "🌋", "label": "Volcanic"},
}

## Current active biome
var active_biome: String = "BioticFlux"

## Whether a transition is currently in progress (prevents rapid switching)
var _transitioning: bool = false


func _ready() -> void:
	add_to_group("active_biome_manager")


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
	if BIOME_KEYS.has(keycode):
		var biome_name = BIOME_KEYS[keycode]
		var direction = _get_direction_to(biome_name)
		set_active_biome(biome_name, direction)
		return true
	return false


func handle_cycle_input(keycode: int) -> bool:
	"""Handle biome cycling keys (, and .)

	Returns: true if key was handled, false otherwise
	"""
	if keycode == KEY_COMMA:
		cycle_prev()
		return true
	elif keycode == KEY_PERIOD:
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


func get_biome_info(biome_name: String) -> Dictionary:
	"""Get display info for a biome"""
	return BIOME_INFO.get(biome_name, {})
