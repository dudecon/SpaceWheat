extends SceneTree

## Full Gameplay Visual Test - Non-Headless
## Tests all 4 tools, overlays, quest board, and harvest loop
## Run with: godot --script Tests/full_gameplay_test.gd

var action_queue: Array = []
var action_index: int = 0
var frame_count: int = 0
var wait_frames: int = 0
var current_phase: String = "boot"

func _init():
	print("\n" + "=" .repeat(70))
	print("FULL GAMEPLAY VISUAL TEST")
	print("=" .repeat(70))
	print("\nThis test will exercise:")
	print("  - All 4 tools (1=Probe, 2=Entangle, 3=Industry, 4=Unitary)")
	print("  - Q/E/R actions for each tool")
	print("  - All overlays (V=Vocab, B=Biome, N=Inspector, C=Quests, K=Controls)")
	print("  - Quest board pinning (Lock with R, Accept with Q)")
	print("  - Full harvest loop")
	print("=" .repeat(70) + "\n")


func _process(delta: float) -> bool:
	frame_count += 1

	# Wait for game to load
	if frame_count < 30:
		if frame_count == 5:
			print("Waiting for game to load...")
		return false

	# Load main scene
	if frame_count == 30:
		print("\nLoading FarmView scene...")
		var err = change_scene_to_file("res://scenes/FarmView.tscn")
		if err != OK:
			print("ERROR: Failed to load scene: %d" % err)
			quit(1)
			return true
		return false

	# Wait for scene to initialize
	if frame_count < 120:
		return false

	# Build action queue once
	if frame_count == 120:
		print("\nScene loaded! Building test sequence...")
		_build_action_queue()
		return false

	# Handle wait frames
	if wait_frames > 0:
		wait_frames -= 1
		return false

	# Process action queue
	if action_index < action_queue.size():
		var action = action_queue[action_index]
		action_index += 1
		_execute_action(action)

	return false


func _build_action_queue():
	# =========================================================
	# PHASE 1: OVERLAYS TEST
	# =========================================================
	_queue_phase("OVERLAYS")

	# Test Vocabulary (V)
	_queue_note("Opening Vocabulary panel (V)...")
	_queue_key(KEY_V, 1.5)
	_queue_note("Should show: known_emojis + accessible factions")
	_queue_key(KEY_V, 0.5)  # Close

	# Test Controls (K)
	_queue_note("Opening Controls panel (K)...")
	_queue_key(KEY_K, 1.5)
	_queue_key(KEY_K, 0.5)  # Close

	# Test Biome Inspector (B)
	_queue_note("Opening Biome Inspector (B)...")
	_queue_key(KEY_B, 2.0)
	_queue_note("Should show: purity %, harvest prediction, emoji bath")
	_queue_key(KEY_B, 0.5)  # Close

	# Test Inspector (N) - density matrix
	_queue_note("Opening Inspector (N)...")
	_queue_key(KEY_N, 2.0)
	_queue_note("Should show: density matrix heatmap")
	_queue_key(KEY_F, 1.0)  # Cycle view
	_queue_note("Cycled to probability bars view")
	_queue_key(KEY_N, 0.5)  # Close

	# =========================================================
	# PHASE 2: TOOL 1 - PROBE (Explore/Measure/Pop)
	# =========================================================
	_queue_phase("TOOL 1: PROBE")

	_queue_key(KEY_1, 0.5)  # Select Tool 1
	_queue_note("Selected Tool 1 (Probe)")

	# Select plot T
	_queue_key(KEY_T, 0.3)
	_queue_note("Selected plot T")

	# Q = Explore
	_queue_key(KEY_Q, 0.8)
	_queue_note("Q: EXPLORE - spawned terminal bubble")

	# E = Measure
	_queue_key(KEY_E, 0.8)
	_queue_note("E: MEASURE - collapsed quantum state")

	# R = Pop/Harvest
	_queue_key(KEY_R, 0.8)
	_queue_note("R: POP - harvested resources")

	# Do another harvest on plot Y
	_queue_key(KEY_Y, 0.3)
	_queue_key(KEY_Q, 0.5)
	_queue_key(KEY_E, 0.5)
	_queue_key(KEY_R, 0.5)
	_queue_note("Completed harvest cycle on plot Y")

	# =========================================================
	# PHASE 3: TOOL 2 - ENTANGLE
	# =========================================================
	_queue_phase("TOOL 2: ENTANGLE")

	_queue_key(KEY_2, 0.5)  # Select Tool 2
	_queue_note("Selected Tool 2 (Entangle)")

	# First explore two plots to entangle
	_queue_key(KEY_1, 0.3)  # Back to probe
	_queue_key(KEY_U, 0.3)
	_queue_key(KEY_Q, 0.5)  # Explore U
	_queue_key(KEY_I, 0.3)
	_queue_key(KEY_Q, 0.5)  # Explore I
	_queue_note("Explored plots U and I")

	# Now entangle them
	_queue_key(KEY_2, 0.3)  # Tool 2
	_queue_key(KEY_BRACKETLEFT, 0.2)  # Deselect all
	_queue_key(KEY_U, 0.2)  # Select U
	_queue_key(KEY_I, 0.2)  # Select I (multi-select)
	_queue_note("Selected U and I for entanglement")

	# Q = Create Bell pair
	_queue_key(KEY_Q, 1.0)
	_queue_note("Q: CREATE BELL PAIR - entangled U and I")

	# Measure one to see correlation
	_queue_key(KEY_1, 0.3)  # Back to probe
	_queue_key(KEY_U, 0.3)
	_queue_key(KEY_E, 0.8)
	_queue_note("Measured U - check if I correlates")

	# =========================================================
	# PHASE 4: TOOL 3 - INDUSTRY (Plant/Water/Fertilize)
	# =========================================================
	_queue_phase("TOOL 3: INDUSTRY")

	_queue_key(KEY_3, 0.5)  # Select Tool 3
	_queue_note("Selected Tool 3 (Industry)")

	_queue_key(KEY_O, 0.3)  # Select plot O
	_queue_note("Selected plot O")

	# Q = Opens plant submenu
	_queue_key(KEY_Q, 0.8)
	_queue_note("Q: Opened PLANT submenu")

	# Q again = Plant first option
	_queue_key(KEY_Q, 0.8)
	_queue_note("Q: Planted crop")

	# E = Water
	_queue_key(KEY_E, 0.8)
	_queue_note("E: WATER - added moisture")

	# R = Fertilize
	_queue_key(KEY_R, 0.8)
	_queue_note("R: FERTILIZE - boosted growth")

	# =========================================================
	# PHASE 5: TOOL 4 - UNITARY (Rotate/Phase/Hadamard)
	# =========================================================
	_queue_phase("TOOL 4: UNITARY")

	_queue_key(KEY_4, 0.5)  # Select Tool 4
	_queue_note("Selected Tool 4 (Unitary)")

	# First need an active terminal
	_queue_key(KEY_1, 0.3)
	_queue_key(KEY_P, 0.3)
	_queue_key(KEY_Q, 0.5)  # Explore P
	_queue_note("Explored plot P for unitary operations")

	_queue_key(KEY_4, 0.3)  # Back to unitary
	_queue_key(KEY_P, 0.3)

	# Q = Rotate
	_queue_key(KEY_Q, 0.8)
	_queue_note("Q: ROTATE - applied rotation gate")

	# E = Phase shift
	_queue_key(KEY_E, 0.8)
	_queue_note("E: PHASE - applied phase gate")

	# R = Hadamard
	_queue_key(KEY_R, 0.8)
	_queue_note("R: HADAMARD - created superposition")

	# =========================================================
	# PHASE 6: QUEST BOARD + PINNING
	# =========================================================
	_queue_phase("QUEST BOARD + PINNING")

	_queue_key(KEY_C, 1.0)  # Open quest board
	_queue_note("Opened Quest Board (C)")

	# Select slot U and lock it
	_queue_key(KEY_U, 0.3)
	_queue_key(KEY_R, 0.5)  # Lock
	_queue_note("Locked quest in slot U")

	# Select slot I and accept it
	_queue_key(KEY_I, 0.3)
	_queue_key(KEY_Q, 0.5)  # Accept
	_queue_note("Accepted quest in slot I")

	# Cycle with F - pinned quests should stay
	_queue_key(KEY_F, 0.8)
	_queue_note("F: Cycled page - U (locked) and I (active) should remain")
	_queue_key(KEY_F, 0.8)
	_queue_note("F: Cycled again")

	# Close quest board
	_queue_key(KEY_ESCAPE, 0.5)
	_queue_note("Closed Quest Board")

	# =========================================================
	# PHASE 7: FINAL HARVEST LOOP
	# =========================================================
	_queue_phase("FINAL HARVEST LOOP")

	_queue_key(KEY_1, 0.3)  # Tool 1

	# Harvest remaining explored plots
	_queue_key(KEY_I, 0.2)
	_queue_key(KEY_E, 0.3)
	_queue_key(KEY_R, 0.3)

	_queue_key(KEY_P, 0.2)
	_queue_key(KEY_E, 0.3)
	_queue_key(KEY_R, 0.3)

	_queue_note("Harvested remaining plots")

	# Check biome state after all operations
	_queue_key(KEY_B, 1.5)
	_queue_note("Final biome state check")
	_queue_key(KEY_B, 0.5)

	# =========================================================
	# DONE
	# =========================================================
	_queue_phase("TEST COMPLETE")
	_queue_note("All tools and features exercised!")
	_queue_note("Check the game window for visual results.")
	_queue_action("wait", 3.0)
	_queue_action("quit", 0)


func _queue_phase(name: String):
	action_queue.append({"type": "phase", "value": name, "delay": 0.5})


func _queue_note(text: String):
	action_queue.append({"type": "note", "value": text, "delay": 0.0})


func _queue_key(keycode: int, delay: float):
	action_queue.append({"type": "key", "value": keycode, "delay": delay})


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
			wait_frames = int(delay * 60)

		"quit":
			print("\n" + "=" .repeat(70))
			print("GAMEPLAY TEST COMPLETE")
			print("=" .repeat(70))
			print("\nAll 4 tools tested:")
			print("  1. Probe: Explore/Measure/Pop")
			print("  2. Entangle: Bell pair creation")
			print("  3. Industry: Plant/Water/Fertilize")
			print("  4. Unitary: Rotate/Phase/Hadamard")
			print("\nOverlays tested: V, B, N, C, K")
			print("Quest board pinning tested: Lock + Accept + F cycle")
			print("=" .repeat(70))
			quit(0)


func _send_key(keycode: int):
	var event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.echo = false
	root.push_input(event)

	# Release after short delay
	var release = InputEventKey.new()
	release.keycode = keycode
	release.pressed = false

	# Use call_deferred to release key next frame
	_release_key.call_deferred(release)


func _release_key(event: InputEventKey):
	root.push_input(event)
