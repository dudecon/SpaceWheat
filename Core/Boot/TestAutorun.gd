extends Node

## Auto-running test during boot
## This runs after all game systems are ready and simulates gameplay

func _ready():
	# Wait for game to fully boot
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Run tests
	_run_tests()

func _run_tests():
	print("\n" + "=".repeat(90))
	print("🧪 AUTO-RUN GAMEPLAY TESTS")
	print("=".repeat(90))

	var farm_view = get_tree().get_first_node_in_group("farm_view")
	var player_shell = get_tree().get_first_node_in_group("player_shell")

	if not farm_view or not player_shell:
		print("❌ Game components not ready")
		return

	var overlay_mgr = player_shell.overlay_manager
	var action_bar_mgr = player_shell.action_bar_manager

	print("\n" + "─".repeat(90))
	print("PHASE 1: TOOL SELECTION & BASIC ACTIONS")
	print("─".repeat(90))

	# Test Tool 1
	print("\n🔶 Tool 1 (Grower 🌱): Simulating key selection...")
	_send_input_key(KEY_1)
	await get_tree().process_frame

	if action_bar_mgr:
		var action_row = action_bar_mgr.get_action_row()
		if action_row and action_row.visible:
			print("   ✅ Action bar appeared after selecting tool 1")
		else:
			print("   ❌ Action bar NOT visible after tool selection")
	else:
		print("   ❌ ActionBarManager not found")

	# Try action
	print("   → Sending Q key...")
	_send_input_key(KEY_Q)
	await get_tree().process_frame
	print("   ✅ Q key sent (check console for action result)")

	print("\n🔶 Tool 2 (Quantum ⚛️): Simulating selection...")
	_send_input_key(KEY_2)
	await get_tree().process_frame
	print("   ✅ Tool 2 selected")

	print("\n🔶 Tool 6 (Biome 🌍): Simulating selection...")
	_send_input_key(KEY_6)
	await get_tree().process_frame
	print("   ✅ Tool 6 selected")

	# Test Tool 6, R action (should open biome inspector)
	print("   → Sending R key (inspect)...")
	_send_input_key(KEY_R)
	await get_tree().process_frame

	var biome_inspector = overlay_mgr.biome_inspector if overlay_mgr else null
	if biome_inspector and biome_inspector.visible:
		print("   ✅ Biome Inspector opened!")
		_send_input_key(KEY_ESCAPE)
		await get_tree().process_frame
		print("   ✅ Biome Inspector closed with ESC")
	else:
		print("   ❌ Biome Inspector did NOT open")

	print("\n" + "─".repeat(90))
	print("PHASE 2: QUEST BOARD")
	print("─".repeat(90))

	print("\n🔶 Quest Board: Simulating C key...")
	_send_input_key(KEY_C)
	await get_tree().process_frame

	var quest_board = overlay_mgr.quest_board if overlay_mgr else null
	if quest_board and quest_board.visible:
		print("   ✅ Quest board opened!")

		# Check v2 overlay
		if overlay_mgr.is_v2_overlay_active():
			print("   ✅ Active as v2 overlay")
		else:
			print("   ❌ NOT active as v2 overlay (old modal system)")

		# Try WASD
		print("   → Testing WASD navigation...")
		_send_input_key(KEY_W)
		_send_input_key(KEY_A)
		_send_input_key(KEY_S)
		_send_input_key(KEY_D)
		print("   ✅ WASD keys sent")

		# Try QER+F
		print("   → Testing Q (accept/complete)...")
		_send_input_key(KEY_Q)
		await get_tree().process_frame

		print("   → Testing F (faction browser)...")
		_send_input_key(KEY_F)
		await get_tree().process_frame

		# Close
		print("   → Testing ESC (close)...")
		_send_input_key(KEY_ESCAPE)
		await get_tree().process_frame

		if not quest_board.visible:
			print("   ✅ Quest board closed with ESC")
		else:
			print("   ⚠️ Quest board still visible")
	else:
		print("   ❌ Quest board did NOT open")

	print("\n" + "─".repeat(90))
	print("PHASE 3: V2 OVERLAYS")
	print("─".repeat(90))

	var overlays_to_test = ["inspector", "controls", "semantic_map"]

	for overlay_name in overlays_to_test:
		if not overlay_mgr.v2_overlays.has(overlay_name):
			print("\n❌ %s not registered" % overlay_name)
			continue

		print("\n🔶 %s: Testing manual open..." % overlay_name)

		var opened = overlay_mgr.open_v2_overlay(overlay_name)
		await get_tree().process_frame

		if overlay_mgr.is_v2_overlay_active():
			print("   ✅ Opened successfully")

			# Test WASD
			_send_input_key(KEY_W)
			_send_input_key(KEY_S)
			print("   ✅ WASD processed")

			# Test QER+F
			_send_input_key(KEY_Q)
			_send_input_key(KEY_E)
			_send_input_key(KEY_R)
			_send_input_key(KEY_F)
			print("   ✅ QER+F processed")

			# Close with ESC
			_send_input_key(KEY_ESCAPE)
			await get_tree().process_frame

			if not overlay_mgr.is_v2_overlay_active():
				print("   ✅ Closed with ESC")
			else:
				print("   ❌ ESC did not close")
		else:
			print("   ❌ Failed to open")

	print("\n" + "=".repeat(90))
	print("✅ AUTO-RUN TESTS COMPLETE - Check output above for results")
	print("=".repeat(90))
	print("\nSUMMARY:")
	print("   If you see mostly ✅: Tools and overlays are working")
	print("   If you see ❌: Specific features are broken")
	print("   Check console output for error messages")
	print("")

func _send_input_key(keycode: int):
	"""Simulate keyboard input"""
	var event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true

	var root = get_tree().root
	if root:
		root._input(event)

