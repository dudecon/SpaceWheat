extends Node

## MusicManager - Autoload singleton for background music
##
## Features:
## - Biome-specific tracks with crossfade transitions
## - Volume control with persistence
## - Dual AudioStreamPlayer for smooth crossfading
##
## Usage:
##   MusicManager.play_biome_track("BioticFlux")
##   MusicManager.set_volume(0.8)
##   MusicManager.stop()

signal volume_changed(new_volume: float)
signal track_changed(track_name: String)

## Track paths (relative to res://Assets/Audio/Music/)
const TRACKS: Dictionary = {
	"quantum_harvest": "res://Assets/Audio/Music/Quantum Harvest Dawn.mp3",
	"fungal_lattice": "res://Assets/Audio/Music/Fungal Lattice Symphony.mp3",
	"black_horizon": "res://Assets/Audio/Music/Black Horizon Whisper.mp3",
	"entropic_bread": "res://Assets/Audio/Music/Entropic Bread Rise.mp3",
	"yeast_prophet": "res://Assets/Audio/Music/Yeast Prophet_s Eclipse.mp3",
	"end_credits": "res://Assets/Audio/Music/SpaceWheat (End Credits).mp3",
	"heisenberg_township": "res://Assets/Audio/Music/Heisenberg Township, Poppenoff-ulation.mp3",
	"peripheral_arbor": "res://Assets/Audio/Music/Peripheral Arbor.mp3",
}

## Biome to track mapping
const BIOME_TRACKS: Dictionary = {
	"BioticFlux": "quantum_harvest",
	"StellarForges": "black_horizon",
	"FungalNetworks": "fungal_lattice",
	"VolcanicWorlds": "entropic_bread",
	"StarterForest": "peripheral_arbor",
	"Village": "heisenberg_township",
}

## Menu/special tracks
const MENU_TRACK: String = "end_credits"
const FALLBACK_TRACK: String = "yeast_prophet"

## Crossfade duration in seconds
const CROSSFADE_DURATION: float = 0.8

## Volume settings
var _volume: float = 0.7  # 0.0 to 1.0
var _muted: bool = false

## Audio players for crossfading
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _inactive_player: AudioStreamPlayer

## Current state
var _current_track: String = ""
var _crossfade_tween: Tween = null
var _last_crossfade_time: float = 0.0
var _health_check_timer: float = 0.0  # 10Hz health check

## Loaded streams cache
var _stream_cache: Dictionary = {}
var _disabled: bool = false


func _ready() -> void:
	if _is_headless():
		_disabled = true
		return

	process_mode = Node.PROCESS_MODE_ALWAYS  # Volume control works when paused
	_setup_audio_players()
	_connect_biome_manager()
	_load_volume_preference()

	# Try to play current biome track on next frame (when ActiveBiomeManager is ready)
	call_deferred("_play_current_biome_track")

	# Monitor playback health - restart if it unexpectedly stops
	set_process(true)


func _process(delta: float) -> void:
	"""Monitor playback health at 10Hz - restart if it unexpectedly stops"""
	if _disabled:
		return

	_health_check_timer += delta
	if _health_check_timer < 0.1:  # 10Hz = check every 0.1 seconds
		return
	_health_check_timer = 0.0

	# If we should be playing music but aren't, restart it
	if not _current_track.is_empty() and not _active_player.playing and (_crossfade_tween == null or not _crossfade_tween.is_valid()):
		push_warning("MusicManager: Playback stopped unexpectedly, restarting track: %s" % _current_track)
		var stream = _get_or_load_stream(_current_track)
		if stream:
			_active_player.stream = stream
			_active_player.volume_db = _volume_to_db(_volume)
			_active_player.play()


func _unhandled_key_input(event: InputEvent) -> void:
	"""Global volume controls: , = down, . = up, / = mute"""
	if _disabled:
		return

	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_COMMA:
			set_volume(_volume - 0.1)
			get_viewport().set_input_as_handled()
		KEY_PERIOD:
			set_volume(_volume + 0.1)
			get_viewport().set_input_as_handled()
		KEY_SLASH:
			set_muted(not _muted)
			get_viewport().set_input_as_handled()


func _setup_audio_players() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_a.name = "MusicPlayerA"
	_player_a.bus = "Master"  # Will use Music bus if available
	add_child(_player_a)

	_player_b = AudioStreamPlayer.new()
	_player_b.name = "MusicPlayerB"
	_player_b.bus = "Master"
	add_child(_player_b)

	_active_player = _player_a
	_inactive_player = _player_b

	# Set initial volumes
	_apply_volume()


func _connect_biome_manager() -> void:
	# Connect to ActiveBiomeManager when available
	if ActiveBiomeManager:
		ActiveBiomeManager.active_biome_changed.connect(_on_biome_changed)
	else:
		# Fallback: try connecting after tree is ready
		await get_tree().process_frame
		if ActiveBiomeManager:
			ActiveBiomeManager.active_biome_changed.connect(_on_biome_changed)


func _on_biome_changed(new_biome: String, _old_biome: String) -> void:
	play_biome_track(new_biome)


func _play_current_biome_track() -> void:
	if ActiveBiomeManager:
		play_biome_track(ActiveBiomeManager.get_active_biome())
	else:
		play_track(FALLBACK_TRACK)


## ============================================================================
## PUBLIC API
## ============================================================================

func play_biome_track(biome_name: String) -> void:
	"""Play the track associated with a biome"""
	if _disabled:
		return

	var track_key = BIOME_TRACKS.get(biome_name, FALLBACK_TRACK)
	crossfade_to(track_key)


func play_track(track_key: String, instant: bool = false) -> void:
	"""Play a track by key name

	Args:
		track_key: Key from TRACKS dictionary
		instant: If true, skip crossfade
	"""
	if _disabled:
		return

	if track_key == _current_track:
		return

	if not TRACKS.has(track_key):
		push_warning("MusicManager: Unknown track '%s'" % track_key)
		return

	var stream = _get_or_load_stream(track_key)
	if not stream:
		return

	if instant or not _active_player.playing:
		_play_instant(stream, track_key)
	else:
		crossfade_to(track_key)


func crossfade_to(track_key: String) -> void:
	"""Crossfade to a new track"""
	if _disabled:
		return

	if track_key == _current_track:
		return

	# Prevent rapid successive crossfades (minimum 0.5s between crossfades)
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_crossfade_time < 0.5:
		return
	_last_crossfade_time = now

	if not TRACKS.has(track_key):
		push_warning("MusicManager: Unknown track '%s'" % track_key)
		return

	var stream = _get_or_load_stream(track_key)
	if not stream:
		return

	# Cancel any existing crossfade
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	# Swap players
	var old_player = _active_player
	_active_player = _inactive_player
	_inactive_player = old_player

	# Setup new track
	_active_player.stream = stream
	_active_player.volume_db = -80.0  # Start silent
	_active_player.play()

	# Crossfade tween
	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)

	# Fade in new track (ease out for smooth start)
	var target_db = _volume_to_db(_volume)
	_crossfade_tween.tween_property(_active_player, "volume_db", target_db, CROSSFADE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Fade out old track (ease in for smooth finish)
	_crossfade_tween.tween_property(_inactive_player, "volume_db", -80.0, CROSSFADE_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_crossfade_tween.chain().tween_callback(_inactive_player.stop)

	_current_track = track_key
	track_changed.emit(track_key)


func stop(fade_out: bool = true) -> void:
	"""Stop music playback"""
	if _disabled:
		return

	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	if fade_out and _active_player.playing:
		var tween = create_tween()
		tween.tween_property(_active_player, "volume_db", -80.0, 1.0)
		tween.chain().tween_callback(_active_player.stop)
	else:
		_active_player.stop()
		_inactive_player.stop()

	_current_track = ""


func set_volume(value: float) -> void:
	"""Set music volume (0.0 to 1.0)"""
	if _disabled:
		return

	_volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save_volume_preference()
	volume_changed.emit(_volume)


func get_volume() -> float:
	"""Get current volume (0.0 to 1.0)"""
	return _volume


func set_muted(muted: bool) -> void:
	"""Mute/unmute music"""
	if _disabled:
		return

	_muted = muted
	_apply_volume()


func is_muted() -> bool:
	return _muted


func is_playing() -> bool:
	if _disabled or not _active_player:
		return false
	return _active_player.playing


func get_current_track() -> String:
	return _current_track


func play_menu_music() -> void:
	"""Play menu/credits music"""
	if _disabled:
		return

	crossfade_to(MENU_TRACK)


func reset() -> void:
	"""Reset music manager completely - stop all playback and clear state"""
	if _disabled:
		return

	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	_player_a.stop()
	_player_b.stop()
	_player_a.stream = null
	_player_b.stream = null
	_current_track = ""
	_stream_cache.clear()
	_last_crossfade_time = 0.0
	_health_check_timer = 0.0


## ============================================================================
## INTERNAL
## ============================================================================

func _get_or_load_stream(track_key: String) -> AudioStream:
	if _disabled:
		return null

	if _stream_cache.has(track_key):
		return _stream_cache[track_key]

	var path = TRACKS.get(track_key, "")
	if path.is_empty():
		push_warning("MusicManager: Track key '%s' not found in TRACKS" % track_key)
		return null

	if not ResourceLoader.exists(path):
		push_error("MusicManager: Track file not found: %s" % path)
		return null

	var stream = load(path) as AudioStream
	if stream:
		_stream_cache[track_key] = stream
	else:
		push_error("MusicManager: Failed to load stream from: %s" % path)
	return stream


func _play_instant(stream: AudioStream, track_key: String) -> void:
	_active_player.stream = stream
	_active_player.volume_db = _volume_to_db(_volume)
	_active_player.play()
	_current_track = track_key
	track_changed.emit(track_key)


func _apply_volume() -> void:
	if _disabled:
		return

	var db = -80.0 if _muted else _volume_to_db(_volume)
	if _active_player and _active_player.playing:
		_active_player.volume_db = db


func _volume_to_db(linear: float) -> float:
	"""Convert linear volume (0-1) to decibels"""
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)


func _save_volume_preference() -> void:
	"""Save volume to user preferences"""
	if _disabled:
		return

	var config = ConfigFile.new()
	var path = "user://settings.cfg"
	config.load(path)  # Ignore error if file doesn't exist
	config.set_value("audio", "music_volume", _volume)
	config.save(path)


func _load_volume_preference() -> void:
	"""Load volume from user preferences"""
	if _disabled:
		return

	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		_volume = config.get_value("audio", "music_volume", 0.7)


func _is_headless() -> bool:
	return OS.has_feature("headless") or DisplayServer.get_name() == "headless"
