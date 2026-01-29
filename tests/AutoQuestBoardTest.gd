## Automatic quest board test - runs after game boot, detects pool rebuild bug
extends Node

var test_active: bool = false
var test_phase: String = "waiting"
var offer_called_during_test: bool = false
var original_offer_func: Callable

# Test state
var farm: Node
var quest_manager: Node
var quest_board: Node
var active_quest_id: int = -1

func _sep() -> String:
	return "================================================================================"

func _dash() -> String:
	return "--------------------------------------------------------------------------------"

func _ready():
	print("\n" + _sep())
	print("AUTO QUEST BOARD TEST HARNESS")
	print(_sep() + "\n")

	# Load main game if not already loaded
	_ensure_game_loaded()

	# Wait for game to boot
	await _wait_for_boot()

	# Get references
	_get_references()

	if not farm or not quest_manager or not quest_board:
		print("❌ Failed to get game references\n")
		print("  Farm: %s" % farm)
		print("  QuestManager: %s" % quest_manager)
		print("  QuestBoard: %s" % quest_board)
		print()
		get_tree().quit()
		return

	print("✓ Game ready, references obtained\n")

	# Hook offer_all_faction_quests to detect calls
	_hook_offer_function()

	# Run test
	await _run_auto_test()

	# Quit
	get_tree().quit()

func _ensure_game_loaded():
	"""Game boots via BootManager autoload, just wait for it"""
	print("BootManager will handle game loading...")

func _wait_for_boot():
	"""Wait for game boot to complete"""
	print("Waiting for game boot...")

	# Wait for Farm to exist (boot is complete when Farm exists)
	var timeout_frames = 0
	var max_frames = 600  # ~10 seconds at 60fps

	while not get_tree().get_first_node_in_group("farm") and timeout_frames < max_frames:
		await get_tree().process_frame
		timeout_frames += 1

	if timeout_frames >= max_frames:
		print("⚠️ Boot timeout after ~10 seconds")
		print("   Attempting to proceed anyway...")
	else:
		print("✓ Farm found, boot complete")

	# Extra frames to let everything settle
	for i in range(5):
		await get_tree().process_frame

func _get_references():
	"""Get references to game components"""
	farm = get_tree().get_first_node_in_group("farm")
	quest_manager = get_node_or_null("/root/QuestManager")

	# Find quest board - try multiple paths
	if not quest_board:
		var overlay_mgr = get_node_or_null("/root/OverlayManager")
		if overlay_mgr and overlay_mgr.has_node("QuestBoard"):
			quest_board = overlay_mgr.get_node("QuestBoard")

	if not quest_board:
		# Search tree for any node with QuestBoard script
		for node in get_tree().get_nodes_in_group("quest_board"):
			if "QuestBoard" in node.get_script().resource_path:
				quest_board = node
				break

	print("Farm: %s" % ("✓" if farm else "❌"))
	print("QuestManager: %s" % ("✓" if quest_manager else "❌"))
	print("QuestBoard: %s" % ("✓" if quest_board else "❌"))

func _hook_offer_function():
	"""Hook offer_all_faction_quests to track calls during test"""
	if not quest_manager.has_method("offer_all_faction_quests"):
		return

	original_offer_func = quest_manager.offer_all_faction_quests

	var hook = func(biome) -> Array:
		if test_active:
			print("   ⚠️ offer_all_faction_quests CALLED during test phase: %s" % test_phase)
			offer_called_during_test = true

		return original_offer_func.call(biome)

	quest_manager.offer_all_faction_quests = hook

func _run_auto_test():
	"""Run the automatic test sequence"""
	print(_sep())
	print("TEST SEQUENCE")
	print(_sep() + "\n")

	# Phase 1: Generate initial pool
	test_active = true
	test_phase = "initial_generation"
	offer_called_during_test = false

	print("[1] Generating initial quest pool...")
	var initial_pool = quest_manager.offer_all_faction_quests(farm)
	if initial_pool.is_empty():
		print("❌ No quests generated\n")
		return

	print("✓ Generated %d quests\n" % initial_pool.size())
	quest_board.all_available_quests = initial_pool.duplicate()
	quest_board._generate_and_display_page(0)
	await get_tree().process_frame

	# Phase 2: Accept quest
	test_active = true
	test_phase = "quest_accept"
	offer_called_during_test = false

	print("[2] Accepting a quest...")
	var quest_to_accept = initial_pool[0]
	active_quest_id = quest_to_accept.get("id", -1)

	if not quest_manager.has_method("accept_quest"):
		print("❌ No accept_quest method\n")
		return

	quest_manager.accept_quest(quest_to_accept)
	print("✓ Quest %d accepted" % active_quest_id)
	if offer_called_during_test:
		print("⚠️ offer_all_faction_quests called during accept\n")
	else:
		print("✓ Pool not rebuilt during accept\n")

	await get_tree().process_frame

	# Phase 3: Prepare for completion (give resources)
	test_phase = "prepare_resources"
	print("[3] Preparing for completion...")

	# Get what resources are needed
	if quest_manager.active_quests and active_quest_id in quest_manager.active_quests:
		var quest = quest_manager.active_quests[active_quest_id]
		var resource_needed = quest.get("resource", "📜")
		var quantity = quest.get("quantity", 20)
		print("  Quest needs: %d×%s" % [quantity, resource_needed])

		# Try to give resources to economy
		var economy = farm.economy if farm and "economy" in farm else null
		if economy and economy.has_method("add_resource"):
			economy.add_resource(resource_needed, quantity + 10)
			print("  ✓ Gave player %d×%s" % [quantity + 10, resource_needed])
		else:
			print("  ⚠️ Could not give resources (no economy)")

	print()


	# Phase 4: Complete quest (THE CRITICAL TEST)
	test_active = true
	test_phase = "quest_completion"
	offer_called_during_test = false

	print("[4] COMPLETING QUEST (critical test)...")
	print(_dash())

	var before_pool = quest_board.all_available_quests.map(func(q): return q.get("id", -1)) if quest_board.all_available_quests else []
	print("Before completion:")
	print("  Pool IDs: %s" % before_pool)
	print("  Pool size: %d" % (quest_board.all_available_quests.size() if quest_board.all_available_quests else 0))

	var completion_success = false
	# Try direct completion
	if quest_manager.has_method("complete_quest"):
		completion_success = quest_manager.complete_quest(active_quest_id)
		print("  complete_quest() returned: %s" % completion_success)
		if not completion_success:
			print("  ⚠️ Completion failed - may lack resources or other issue")

	await get_tree().process_frame
	await get_tree().process_frame

	var after_pool = quest_board.all_available_quests.map(func(q): return q.get("id", -1)) if quest_board.all_available_quests else []
	print("\nAfter completion:")
	print("  Pool IDs: %s" % after_pool)
	print("  Pool size: %d" % (quest_board.all_available_quests.size() if quest_board.all_available_quests else 0))
	print(_dash() + "\n")

	test_active = false

	# Phase 5: Report results
	print(_sep())
	print("TEST RESULTS")
	print(_sep() + "\n")

	var bug_detected = false

	# Check 1: Was offer_all_faction_quests called during completion?
	if offer_called_during_test:
		print("❌ PRIMARY BUG: offer_all_faction_quests called during completion")
		print("   This rebuilds the quest pool with NEW quest IDs!")
		print("   Result: QUESTS GET NUKED\n")
		bug_detected = true
	else:
		print("✅ offer_all_faction_quests NOT called during completion\n")

	# Check 2: Pool integrity
	if before_pool.size() > 0:
		var ids_unchanged = true
		var quest_removed = false

		for id in before_pool:
			if id == active_quest_id:
				if id not in after_pool:
					quest_removed = true
			elif id not in after_pool:
				ids_unchanged = false
				print("❌ SECONDARY BUG: Quest ID %d disappeared (not the completed one)" % id)
				bug_detected = true
				break

		if ids_unchanged:
			print("✅ All quest IDs stable (except completed quest)")
		else:
			print("❌ Quest IDs changed unexpectedly")

		if quest_removed:
			print("✅ Completed quest properly removed from pool\n")
		elif completion_success:
			print("⚠️ Completed quest still in pool\n")
		else:
			print("⚠️ Completion failed, pool unchanged (expected)\n")
	else:
		print("⚠️ Pool was empty, could not verify\n")

	# Final verdict
	print(_dash())
	if bug_detected:
		print("🔴 VERDICT: BUG PRESENT - Quests are being nuked on completion")
	else:
		print("🟢 VERDICT: NO BUG - Quest system appears to be working correctly")
	print(_dash() + "\n")

	print(_sep() + "\n")
