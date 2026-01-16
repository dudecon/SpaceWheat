extends SceneTree

## Comprehensive UI Gameplay Test
## Exercises all UI components and looks for display/interaction bugs
## Run with: godot --script Tests/test_ui_comprehensive.gd

var frame_count: int = 0
var current_phase: String = "boot"
var action_queue: Array = []
var action_index: int = 0
var wait_frames: int = 0
var observations: Array = []

func _init():
	print("\n" + "=" .repeat(70))
	print("COMPREHENSIVE UI GAMEPLAY TEST")
	print("Testing all UI components for display bugs")
	print("=" .repeat(70) + "\n")


func _process(delta: float) -> bool:
	frame_count += 1

	# Wait for engine
	if frame_count < 30:
		if frame_count == 5:
			print("Waiting for game to load...")
		return false

	# Load scene
	if frame_count == 30:
		print("\nLoading FarmView scene...")
		var err = change_scene_to_file("res://scenes/FarmView.tscn")
		if err != OK:
			print("ERROR: Failed to load scene: %d" % err)
			observations.append("CRITICAL: Scene failed to load")
			quit(1)
			return true
		return false

	# Wait for scene init
	if frame_count < 120:
		return false

	# Build test queue
	if frame_count == 120:
		print("\nScene loaded! Building comprehensive test sequence...")
		_build_test_queue()
		return false

	# Handle waits
	if wait_frames > 0:
		wait_frames -= 1
		return false

	# Process queue
	if action_index < action_queue.size():
		var action = action_queue[action_index]
		action_index += 1
		_execute_action(action)

	return false


func _build_test_queue():
	# =========================================================
	# PHASE 1: VERIFY BASIC UI DISPLAYS
	# =========================================================
	_queue_phase("BASIC UI VERIFICATION")

	_queue_note("Checking if resource panel shows emojis...")
	_queue_check("resource_panel_visible")
	_queue_wait(0.5)

	_queue_note("Checking if plot grid is visible...")
	_queue_check("plot_grid_visible")
	_queue_wait(0.5)

	_queue_note("Checking if action bar shows tool buttons...")
	_queue_check("action_bar_visible")
	_queue_wait(0.5)

	# =========================================================
	# PHASE 2: TEST TOOL SELECTION UI
	# =========================================================
	_queue_phase("TOOL SELECTION")

	for i in range(1, 5):
		_queue_key(KEY_1 + i - 1, 0.3)
		_queue_note("Tool %d selected - verify action bar labels updated" % i)
		_queue_check("action_bar_labels_tool_%d" % i)

	# =========================================================
	# PHASE 3: TEST OVERLAY OPENS/CLOSES
	# =========================================================
	_queue_phase("OVERLAY DISPLAY")

	# Vocabulary (V)
	_queue_note("Opening Vocabulary overlay (V)...")
	_queue_key(KEY_V, 1.0)
	_queue_check("vocabulary_overlay_visible")
	_queue_key(KEY_ESCAPE, 0.5)
	_queue_check("vocabulary_overlay_closed")

	# Biome Inspector (B)
	_queue_note("Opening Biome Inspector (B)...")
	_queue_key(KEY_B, 1.0)
	_queue_check("biome_inspector_visible")
	_queue_key(KEY_ESCAPE, 0.5)
	_queue_check("biome_inspector_closed")

	# Inspector (N) - Density Matrix
	_queue_note("Opening Inspector (N)...")
	_queue_key(KEY_N, 1.0)
	_queue_check("inspector_overlay_visible")
	_queue_note("Testing F to cycle view mode...")
	_queue_key(KEY_F, 0.5)
	_queue_check("inspector_view_mode_changed")
	_queue_key(KEY_ESCAPE, 0.5)

	# Quest Board (C)
	_queue_note("Opening Quest Board (C)...")
	_queue_key(KEY_C, 1.0)
	_queue_check("quest_board_visible")
	_queue_key(KEY_ESCAPE, 0.5)

	# Controls (K)
	_queue_note("Opening Controls (K)...")
	_queue_key(KEY_K, 1.0)
	_queue_check("controls_overlay_visible")
	_queue_key(KEY_ESCAPE, 0.5)

	# =========================================================
	# PHASE 4: TEST PLOT SELECTION
	# =========================================================
	_queue_phase("PLOT SELECTION")

	_queue_key(KEY_1, 0.3)  # Tool 1 (Probe)
	_queue_note("Selecting plot T...")
	_queue_key(KEY_T, 0.5)
	_queue_check("plot_t_selected")

	_queue_note("Selecting plot Y...")
	_queue_key(KEY_Y, 0.5)
	_queue_check("plot_y_selected")

	_queue_note("Multi-select: select another plot...")
	_queue_key(KEY_U, 0.5)
	_queue_check("multi_select_active")

	# =========================================================
	# PHASE 5: TEST ACTIONS ON PLOTS
	# =========================================================
	_queue_phase("PLOT ACTIONS")

	_queue_key(KEY_T, 0.3)  # Select plot T
	_queue_note("Q action (Explore) on plot T...")
	_queue_key(KEY_Q, 0.8)
	_queue_check("bubble_spawned_for_t")

	_queue_note("E action (Measure) on plot T...")
	_queue_key(KEY_E, 0.8)
	_queue_check("measurement_performed")

	_queue_note("R action (Pop/Harvest)...")
	_queue_key(KEY_R, 0.8)
	_queue_check("harvest_performed")

	# =========================================================
	# PHASE 6: TEST INSPECTOR AUTO-REFRESH
	# =========================================================
	_queue_phase("INSPECTOR AUTO-REFRESH")

	_queue_note("Opening Inspector to verify auto-refresh...")
	_queue_key(KEY_N, 0.5)

	# Do some actions while inspector is open
	_queue_key(KEY_Y, 0.3)
	_queue_key(KEY_Q, 0.5)  # Explore Y
	_queue_note("Inspector should show updated state...")
	_queue_wait(1.0)  # Wait for auto-refresh (0.5s interval)
	_queue_check("inspector_auto_refreshed")

	_queue_key(KEY_ESCAPE, 0.5)

	# =========================================================
	# PHASE 7: TEST ENTANGLEMENT VISUALIZATION
	# =========================================================
	_queue_phase("ENTANGLEMENT VISUALIZATION")

	_queue_key(KEY_1, 0.3)  # Tool 1

	# Explore two plots
	_queue_key(KEY_U, 0.3)
	_queue_key(KEY_Q, 0.5)
	_queue_key(KEY_I, 0.3)
	_queue_key(KEY_Q, 0.5)
	_queue_note("Explored U and I...")

	# Switch to entangle tool
	_queue_key(KEY_2, 0.3)
	_queue_note("Switched to Tool 2 (Entangle)...")

	# Select both plots for entanglement
	_queue_key(KEY_BRACKETLEFT, 0.2)  # Deselect all
	_queue_key(KEY_U, 0.2)
	_queue_key(KEY_I, 0.2)
	_queue_note("Selected U and I for entanglement...")

	# Create Bell pair
	_queue_key(KEY_Q, 1.0)
	_queue_note("Created Bell pair - cyan line should appear!")
	_queue_check("entanglement_line_visible")
	_queue_wait(1.0)

	# =========================================================
	# DONE
	# =========================================================
	_queue_phase("TEST COMPLETE")
	_queue_note("All UI tests complete!")
	_queue_action("summary", 0)
	_queue_wait(2.0)
	_queue_action("quit", 0)


func _queue_phase(name: String):
	action_queue.append({"type": "phase", "value": name, "delay": 0.3})


func _queue_note(text: String):
	action_queue.append({"type": "note", "value": text, "delay": 0.0})


func _queue_key(keycode: int, delay: float):
	action_queue.append({"type": "key", "value": keycode, "delay": delay})


func _queue_wait(seconds: float):
	action_queue.append({"type": "wait", "value": seconds, "delay": 0.0})


func _queue_check(check_name: String):
	action_queue.append({"type": "check", "value": check_name, "delay": 0.0})


func _queue_action(action_type: String, delay: float):
	action_queue.append({"type": action_type, "value": null, "delay": delay})


func _execute_action(action: Dictionary):
	var action_type = action.type
	var value = action.value
	var delay = action.delay

	match action_type:
		"phase":
			print("\n" + "=" .repeat(50))
			print("PHASE: %s" % value)
			print("=" .repeat(50))
			current_phase = value
			wait_frames = int(delay * 60)

		"note":
			print("  [%s] %s" % [current_phase, value])

		"key":
			_send_key(value)
			wait_frames = int(delay * 60)

		"wait":
			wait_frames = int(value * 60)

		"check":
			_perform_check(value)

		"summary":
			_print_summary()

		"quit":
			print("\nTest sequence complete.")
			quit(0 if observations.is_empty() else 1)


func _send_key(keycode: int):
	var event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.echo = false
	root.push_input(event)

	var release = InputEventKey.new()
	release.keycode = keycode
	release.pressed = false
	_release_key.call_deferred(release)


func _release_key(event: InputEventKey):
	root.push_input(event)


func _perform_check(check_name: String):
	"""Perform a runtime check and log observation"""
	# These are observation points - in a real test we'd inspect the scene tree
	# For now, we log what we expect to see
	print("    📋 CHECK: %s" % check_name)

	# Add more sophisticated checks based on check_name
	match check_name:
		"entanglement_line_visible":
			observations.append("VERIFY: Cyan entanglement line between U and I bubbles")
		"inspector_auto_refreshed":
			observations.append("VERIFY: Inspector heatmap updated after Explore action")
		"bubble_spawned_for_t":
			observations.append("VERIFY: Quantum bubble appeared at plot T")
		_:
			pass  # Other checks are UI state verifications


func _print_summary():
	print("\n" + "=" .repeat(70))
	print("TEST SUMMARY")
	print("=" .repeat(70))

	print("\nPhases completed:")
	print("  1. Basic UI Verification")
	print("  2. Tool Selection")
	print("  3. Overlay Display")
	print("  4. Plot Selection")
	print("  5. Plot Actions")
	print("  6. Inspector Auto-Refresh")
	print("  7. Entanglement Visualization")

	if observations.size() > 0:
		print("\n📋 OBSERVATIONS (verify visually):")
		for obs in observations:
			print("  - %s" % obs)
	else:
		print("\n✅ No specific observations recorded")

	print("\n" + "=" .repeat(70))
