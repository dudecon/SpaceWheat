extends Node

## TouchInputManager - Simplified Touch Input Manager for SpaceWheat
## Registered as autoload singleton - access globally via TouchInputManager
## Handles tap and swipe gestures only - no long-press, no pinch, no multi-touch
## Designed for Godot 4 with clean, minimal complexity

# Gesture detection thresholds (following iOS HIG and Material Design)
const TAP_MAX_DURATION: float = 0.3      # 300ms max for tap
const TAP_MAX_MOVEMENT: float = 10.0     # 10px max movement for tap
const SWIPE_MIN_DISTANCE: float = 30.0   # 30px minimum swipe distance

# Signals for game systems to connect to
signal tap_detected(position: Vector2)
signal swipe_detected(start_pos: Vector2, end_pos: Vector2, direction: Vector2)

# Single touch tracking (simplified - no multi-touch)
var touch_start_pos: Vector2 = Vector2.ZERO
var touch_start_time: float = 0.0
var is_touching: bool = false

# PHASE 2 FIX: Spatial hit testing - track if current tap was consumed
var current_tap_consumed: bool = false


func _input(event: InputEvent) -> void:
	"""Track touch down/up events globally"""
	if event is InputEventScreenTouch:
		# Native touch event (preferred)
		print("🔍 TouchInputManager._input() received InputEventScreenTouch: pressed=%s, position=%s, index=%s" % [event.pressed, event.position, event.index])
		if event.pressed:
			_touch_started(event)
		else:
			_touch_ended(event)
	elif event is InputEventMouseButton and event.device >= 0:
		# Touch-generated mouse event (fallback for platforms without InputEventScreenTouch)
		print("🔍 TouchInputManager._input() received touch-generated mouse event: device=%s, pressed=%s, position=%s" % [event.device, event.pressed, event.position])
		if event.pressed:
			_touch_started_from_mouse(event)
		else:
			_touch_ended_from_mouse(event)


func _touch_started(event: InputEventScreenTouch) -> void:
	"""Record new touch - start tracking for gesture detection"""
	touch_start_pos = event.position
	touch_start_time = Time.get_ticks_msec() / 1000.0
	is_touching = true

	print("👆 TouchManager: Touch started at %s" % event.position)


func _touch_started_from_mouse(event: InputEventMouseButton) -> void:
	"""Record touch start from mouse button event (fallback for platforms without InputEventScreenTouch)"""
	touch_start_pos = event.position
	touch_start_time = Time.get_ticks_msec() / 1000.0
	is_touching = true

	print("👆 TouchManager: Touch started at %s (from mouse event)" % event.position)


func _touch_ended(event: InputEventScreenTouch) -> void:
	"""Classify gesture on touch release"""
	if not is_touching:
		return  # Ignore if we didn't track the start

	var end_pos = event.position
	var duration = (Time.get_ticks_msec() / 1000.0) - touch_start_time
	var distance = touch_start_pos.distance_to(end_pos)

	# Classify gesture based on movement and duration
	if distance < TAP_MAX_MOVEMENT and duration < TAP_MAX_DURATION:
		# TAP: Quick touch with minimal movement
		print("👆 TouchManager: TAP detected at %s (moved %.1fpx in %.3fs)" % [end_pos, distance, duration])
		# PHASE 2 FIX: Reset consumed flag before emitting (spatial hierarchy)
		current_tap_consumed = false
		tap_detected.emit(end_pos)

	elif distance >= SWIPE_MIN_DISTANCE:
		# SWIPE: Moved significant distance
		var direction = (end_pos - touch_start_pos).normalized()
		print("👆 TouchManager: SWIPE detected: %s → %s (%.1fpx, direction %s)" %
			[touch_start_pos, end_pos, distance, direction])
		swipe_detected.emit(touch_start_pos, end_pos, direction)

	else:
		# Neither tap nor swipe - just a touch that moved a bit
		print("👆 TouchManager: Touch ended (no gesture, moved %.1fpx in %.3fs)" % [distance, duration])

	is_touching = false


func _touch_ended_from_mouse(event: InputEventMouseButton) -> void:
	"""Classify gesture on touch release from mouse event (fallback for platforms without InputEventScreenTouch)"""
	if not is_touching:
		return  # Ignore if we didn't track the start

	var end_pos = event.position
	var duration = (Time.get_ticks_msec() / 1000.0) - touch_start_time
	var distance = touch_start_pos.distance_to(end_pos)

	# Classify gesture based on movement and duration
	if distance < TAP_MAX_MOVEMENT and duration < TAP_MAX_DURATION:
		# TAP: Quick touch with minimal movement
		print("👆 TouchManager: TAP detected at %s (moved %.1fpx in %.3fs) [from mouse event]" % [end_pos, distance, duration])
		# PHASE 2 FIX: Reset consumed flag before emitting (spatial hierarchy)
		current_tap_consumed = false
		tap_detected.emit(end_pos)

	elif distance >= SWIPE_MIN_DISTANCE:
		# SWIPE: Moved significant distance
		var direction = (end_pos - touch_start_pos).normalized()
		print("👆 TouchManager: SWIPE detected: %s → %s (%.1fpx, direction %s) [from mouse event]" %
			[touch_start_pos, end_pos, distance, direction])
		swipe_detected.emit(touch_start_pos, end_pos, direction)

	else:
		# Neither tap nor swipe - just a touch that moved a bit
		print("👆 TouchManager: Touch ended (no gesture, moved %.1fpx in %.3fs) [from mouse event]" % [distance, duration])

	is_touching = false


func is_touch_active() -> bool:
	"""Check if any touch is currently active"""
	return is_touching


func get_current_touch_position() -> Vector2:
	"""Get current touch position (or zero if not touching)"""
	if is_touching:
		return touch_start_pos  # Note: We don't track motion in simplified version
	return Vector2.ZERO


# PHASE 2 FIX: Spatial hit testing helpers

func consume_current_tap() -> void:
	"""Mark the current tap as consumed (handled by a specific system)

	Call this from tap_detected signal handlers to prevent other handlers
	from also processing the same tap. Implements spatial hierarchy.
	"""
	current_tap_consumed = true


func is_current_tap_consumed() -> bool:
	"""Check if the current tap was already consumed by another handler

	Returns:
		true if tap was consumed, false if still available to handle
	"""
	return current_tap_consumed
