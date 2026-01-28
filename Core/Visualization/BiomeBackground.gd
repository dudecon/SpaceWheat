class_name BiomeBackground
extends Control

## BiomeBackground - Full-screen biome background with swipe transitions
##
## Displays the current biome's background image and handles smooth
## horizontal swipe transitions when switching between biomes.
##
## Sits at z_index -100 (or CanvasLayer -1) to render behind everything.

const BIOME_TEXTURES: Dictionary = {
	"BioticFlux": preload("res://Assets/Biomes/Quantum_Fields.png"),
	"StellarForges": preload("res://Assets/Biomes/Stellar_Forges.png"),
	"FungalNetworks": preload("res://Assets/Biomes/Fungal_Networks.png"),
	"VolcanicWorlds": preload("res://Assets/Biomes/Volcanic_Worlds.png"),
	"StarterForest": preload("res://Assets/Biomes/Starter_Forest.png"),
	"Village": preload("res://Assets/Biomes/Village.png"),
}

## Transition duration in seconds
@export var transition_duration: float = 0.3

## Current biome being displayed
var current_biome: String = ""

## TextureRect for current background
var _current_bg: TextureRect

## TextureRect for incoming background (during transition)
var _incoming_bg: TextureRect

## Active tween for transitions
var _tween: Tween

## Reference to ActiveBiomeManager (set in _ready)
var _biome_manager: Node


func _ready() -> void:
	# When added to CanvasLayer, anchors don't work - must set size explicitly
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Set size to viewport (CanvasLayer has no parent size for anchors)
	var viewport_size = get_viewport_rect().size
	size = viewport_size
	position = Vector2.ZERO

	# Create current background TextureRect
	_current_bg = _create_texture_rect()
	_current_bg.size = viewport_size
	add_child(_current_bg)

	# Create incoming background TextureRect (hidden initially)
	_incoming_bg = _create_texture_rect()
	_incoming_bg.size = viewport_size
	_incoming_bg.visible = false
	add_child(_incoming_bg)

	# Update size when viewport changes
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	# Connect to ActiveBiomeManager (with guards to prevent duplicate connections)
	_biome_manager = get_node_or_null("/root/ActiveBiomeManager")
	if _biome_manager:
		if not _biome_manager.active_biome_changed.is_connected(_on_active_biome_changed):
			_biome_manager.active_biome_changed.connect(_on_active_biome_changed)
		if not _biome_manager.biome_transition_requested.is_connected(_on_transition_requested):
			_biome_manager.biome_transition_requested.connect(_on_transition_requested)

		# Defer setting initial biome (wait for ActiveBiomeManager to sync with ObservationFrame)
		# Similar pattern to MusicManager - prevents race condition at boot
		call_deferred("_set_initial_biome")
	else:
		push_warning("BiomeBackground: ActiveBiomeManager not found")
		# Default to StarterForest (matches ObservationFrame initial state)
		set_biome("StarterForest")


func _set_initial_biome() -> void:
	"""Deferred call to set initial biome after ActiveBiomeManager syncs with ObservationFrame"""
	if _biome_manager:
		set_biome(_biome_manager.get_active_biome())


func _on_viewport_size_changed() -> void:
	"""Update size when viewport changes"""
	var viewport_size = get_viewport_rect().size
	size = viewport_size
	_current_bg.size = viewport_size
	_incoming_bg.size = viewport_size


func _create_texture_rect() -> TextureRect:
	"""Create a TextureRect configured for full-screen background"""
	var rect = TextureRect.new()
	# Don't use anchors - we set size explicitly for CanvasLayer compatibility
	rect.position = Vector2.ZERO
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func set_biome(biome_name: String) -> void:
	"""Set biome instantly (no transition)"""
	if not BIOME_TEXTURES.has(biome_name):
		push_warning("BiomeBackground: Unknown biome '%s'" % biome_name)
		return

	current_biome = biome_name
	_current_bg.texture = BIOME_TEXTURES[biome_name]
	_current_bg.position = Vector2.ZERO


func transition_to_biome(biome_name: String, direction: int) -> void:
	"""Transition to a new biome with swipe animation

	Args:
		biome_name: Target biome
		direction: -1 = slide from left, 1 = slide from right
	"""
	if not BIOME_TEXTURES.has(biome_name):
		push_warning("BiomeBackground: Unknown biome '%s'" % biome_name)
		return

	if biome_name == current_biome:
		return

	# Cancel any existing transition
	if _tween and _tween.is_valid():
		_tween.kill()

	# Notify manager that transition is starting
	if _biome_manager and _biome_manager.has_method("set_transitioning"):
		_biome_manager.set_transitioning(true)

	var viewport_width = get_viewport_rect().size.x

	# Set up incoming background
	_incoming_bg.texture = BIOME_TEXTURES[biome_name]
	_incoming_bg.visible = true

	# Position based on direction
	if direction > 0:
		# Sliding right: incoming comes from the right
		_incoming_bg.position = Vector2(viewport_width, 0)
	else:
		# Sliding left: incoming comes from the left
		_incoming_bg.position = Vector2(-viewport_width, 0)

	# Create tween
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)

	# Animate current out
	var current_target = Vector2(-viewport_width if direction > 0 else viewport_width, 0)
	_tween.tween_property(_current_bg, "position", current_target, transition_duration)

	# Animate incoming in
	_tween.tween_property(_incoming_bg, "position", Vector2.ZERO, transition_duration)

	# When complete, swap references
	_tween.chain().tween_callback(_on_transition_complete.bind(biome_name))


func _on_transition_complete(biome_name: String) -> void:
	"""Called when swipe transition finishes"""
	current_biome = biome_name

	# Swap the TextureRects
	var temp = _current_bg
	_current_bg = _incoming_bg
	_incoming_bg = temp

	# Hide and reset the old background
	_incoming_bg.visible = false
	_incoming_bg.position = Vector2.ZERO

	# Ensure current is at origin
	_current_bg.position = Vector2.ZERO

	# Notify manager that transition is complete
	if _biome_manager and _biome_manager.has_method("set_transitioning"):
		_biome_manager.set_transitioning(false)


func _on_active_biome_changed(new_biome: String, _old_biome: String) -> void:
	"""Handle instant biome change (when direction = 0)"""
	# Only instant-set if not already transitioning
	if not _tween or not _tween.is_valid():
		if new_biome != current_biome:
			set_biome(new_biome)


func _on_transition_requested(from_biome: String, to_biome: String, direction: int) -> void:
	"""Handle animated biome transition"""
	transition_to_biome(to_biome, direction)


func get_current_biome() -> String:
	"""Get the currently displayed biome"""
	return current_biome
