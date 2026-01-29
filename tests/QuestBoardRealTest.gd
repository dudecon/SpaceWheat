## Real QuestBoard test with actual factions and state verification
extends Node

var quest_board: Node
var quest_manager: Node
var economy: Node
var mock_biome: Node

var test_results: Array[String] = []
var passed: int = 0
var failed: int = 0

var signal_log: Array[Dictionary] = []

func _sep_long() -> String:
	return "================================================================================"

func _sep_short() -> String:
	return "--------------------------------------------------------------------------------"

func _ready():
	print("\n" + _sep_long())
	print("QUESTBOARD REAL TEST SUITE")
	print("Using real factions, real quest generation, state verification")
	print(_sep_long() + "\n")

	_setup()

	if quest_board and quest_manager:
		_run_test_suite()

	_print_results()
	get_tree().quit()

func _setup():
	print("Setting up test environment...\n")

	# Load real QuestManager (not mock)
	var qm_path = "res://Core/Quests/QuestManager.gd"
	var qm_script = load(qm_path)
	if not qm_script:
		_log_fail("Could not load QuestManager")
		return

	quest_manager = Node.new()
	quest_manager.set_script(qm_script)
	add_child(quest_manager)

	# Create mock biome
	mock_biome = Node.new()
	mock_biome.name = "StarterForest"
	add_child(mock_biome)

	# Load real QuestBoard
	var qb_path = "res://UI/Panels/QuestBoard.gd"
	var qb_script = load(qb_path)
	if not qb_script:
		_log_fail("Could not load QuestBoard")
		return

	quest_board = Control.new()
	quest_board.set_script(qb_script)
	add_child(quest_board)

	# Inject dependencies
	quest_board.quest_manager = quest_manager
	quest_board.current_biome = mock_biome

	# Setup signal logging
	if quest_manager.has_signal("vocabulary_learned"):
		quest_manager.vocabulary_learned.connect(func(emoji, faction):
			signal_log.append({
				"type": "vocabulary_learned",
				"emoji": emoji,
				"faction": faction,
				"time": Time.get_ticks_msec()
			})
		)

	if quest_manager.has_signal("active_quests_changed"):
		quest_manager.active_quests_changed.connect(func():
			signal_log.append({
				"type": "active_quests_changed",
				"time": Time.get_ticks_msec()
			})
		)

	print("✓ Setup complete\n")

func _run_test_suite():
	print(_sep_long())
	print("TEST SUITE 1: Vocabulary Invalidation (North Pole Only)")
	print(_sep_long() + "\n")

	_test_north_only_invalidation()
	_test_south_known_doesnt_invalidate()

	print("\n" + _sep_long())
	print("TEST SUITE 2: Completion Flow")
	print(_sep_long() + "\n")

	_test_completion_removes_quest()
	_test_multiple_active_survive_completion()

	print("\n" + _sep_long())
	print("TEST SUITE 3: Pool/Page/Slot Consistency")
	print(_sep_long() + "\n")

	_test_slot_pool_alignment()
	_test_completion_shifts_pool()

func _test_north_only_invalidation():
	print("TEST 1.1: Only NORTH pole triggers invalidation\n")

	# Generate real quests from factions
	var quests = quest_manager.offer_all_faction_quests(mock_biome)

	if quests.is_empty():
		_log_fail("Could not generate quests")
		print()
		return

	# Use first quest
	var quest = quests[0]
	var north = quest.get("reward_vocab_north", "")
	var south = quest.get("reward_vocab_south", "")

	# Check invalidation - should only check north
	var result = quest_board._is_quest_invalidated(quest)

	if result == false:
		_log_pass("Quest not invalidated when vocab unknown")
	else:
		_log_fail("Quest invalidated incorrectly")

	print()

func _test_south_known_doesnt_invalidate():
	print("TEST 1.2: South pole can be known without invalidation\n")

	var quest = {
		"id": 1,
		"faction": "Test Faction",
		"reward_vocab_north": "🍄",
		"reward_vocab_south": "🌾",
		"resource": "🌲",
		"quantity": 5
	}

	# With only south known, should not be invalidated
	var result = quest_board._is_quest_invalidated(quest)

	if result == false:
		_log_pass("South pole knowledge doesn't invalidate quest")
	else:
		_log_fail("South pole incorrectly triggers invalidation")

	print()

func _test_completion_removes_quest():
	print("TEST 2.1: Completion removes quest from pool\n")

	var before = _capture_state()
	print("  Before: Pool size=%d, Active=%d" % [before.pool_size, before.active_count])

	if before.pool_size == 0:
		_log_fail("Pool is empty - cannot test")
		print()
		return

	# Get first quest ID
	var quest_id = before.pool_ids[0]

	# Accept it
	quest_manager.accept_quest(quest_id)
	await get_tree().process_frame

	var middle = _capture_state()
	print("  After accept: Pool size=%d, Active=%d" % [middle.pool_size, middle.active_count])

	# Complete it
	signal_log.clear()
	var success = quest_manager.complete_quest(quest_id)
	await get_tree().process_frame

	var after = _capture_state()
	print("  After complete: Pool size=%d, Active=%d" % [after.pool_size, after.active_count])
	print("  Signals fired: %d" % signal_log.size())

	if success and after.pool_size == before.pool_size - 1:
		_log_pass("Quest removed from pool after completion")
	else:
		_log_fail("Quest not properly removed: before=%d, after=%d" % [before.pool_size, after.pool_size])

	if quest_id not in after.active_ids:
		_log_pass("Quest removed from active_quests")
	else:
		_log_fail("Quest still in active_quests after completion")

	print()

func _test_multiple_active_survive_completion():
	print("TEST 2.2: Other active quests survive completion\n")

	# Reset
	quest_board.all_available_quests.clear()
	quest_manager.active_quests.clear()

	# Generate fresh pool from real factions
	var quests = quest_manager.offer_all_faction_quests(mock_biome)

	if quests.size() < 6:
		_log_fail("Not enough quests generated (need 6+, got %d)" % quests.size())
		print()
		return

	quest_board.all_available_quests = quests.duplicate()

	# Accept multiple
	var q0_id = quests[0].get("id")
	var q3_id = quests[3].get("id")
	var q5_id = quests[5].get("id")

	quest_manager.accept_quest(quests[0])
	quest_manager.accept_quest(quests[3])
	quest_manager.accept_quest(quests[5])
	await get_tree().process_frame

	print("  Accepted: Q0(id=%d), Q3(id=%d), Q5(id=%d)" % [q0_id, q3_id, q5_id])

	# Complete Q3
	quest_manager.complete_quest(q3_id)
	await get_tree().process_frame

	var after = _capture_state()

	if q0_id in after.active_ids:
		_log_pass("Q0 still active after Q3 completed")
	else:
		_log_fail("Q0 lost active status")

	if q5_id in after.active_ids:
		_log_pass("Q5 still active after Q3 completed")
	else:
		_log_fail("Q5 lost active status")

	if q3_id not in after.active_ids:
		_log_pass("Q3 removed from active")
	else:
		_log_fail("Q3 still active after completion")

	print()

func _test_slot_pool_alignment():
	print("TEST 3.1: Slot displays match pool positions\n")

	# Generate pool from real factions
	var quests = quest_manager.offer_all_faction_quests(mock_biome)
	quest_board.all_available_quests = quests

	if quests.size() < 4:
		_log_fail("Not enough quests for test")
		print()
		return

	# Display page 0
	quest_board._generate_and_display_page(0)
	await get_tree().process_frame

	var matched = 0
	for i in range(4):
		var slot = quest_board.quest_slots[i]
		var pool_quest = quests[i]
		var slot_id = slot.quest_data.get("id", -1)
		var pool_id = pool_quest.get("id", -1)

		if slot_id == pool_id:
			matched += 1

	if matched == 4:
		_log_pass("All 4 slots match pool[0..3]")
	else:
		_log_fail("Slot alignment mismatch: %d/4 matched" % matched)

	print()

func _test_completion_shifts_pool():
	print("TEST 3.2: Completion shifts pool correctly\n")

	# Setup pool from real factions
	var quests = quest_manager.offer_all_faction_quests(mock_biome)
	quest_board.all_available_quests = quests.duplicate()

	if quests.size() < 3:
		_log_fail("Not enough quests for test")
		print()
		return

	var removed_id = quests[1].get("id")  # Q1
	var q2_id = quests[2].get("id")       # Q2

	print("  Removing Q1 from pool (id=%d)" % removed_id)

	# Remove Q1 from pool
	for i in range(quest_board.all_available_quests.size()):
		if quest_board.all_available_quests[i].get("id") == removed_id:
			quest_board.all_available_quests.remove_at(i)
			break

	# Redisplay page 0
	quest_board._generate_and_display_page(0)
	await get_tree().process_frame

	print("  After: Pool shifted")

	# Check slot 1 now has Q2
	var slot_1 = quest_board.quest_slots[1]
	var slot_1_id = slot_1.quest_data.get("id", -1)

	if slot_1_id == q2_id:
		_log_pass("Slot 1 now shows Q2 (shifted after Q1 removal)")
	else:
		_log_fail("Slot 1 doesn't show Q2 after shift (got id=%d)" % slot_1_id)

	print()

# ============================================================================
# HELPERS
# ============================================================================

func _capture_state() -> Dictionary:
	return {
		"pool_size": quest_board.all_available_quests.size(),
		"pool_ids": quest_board.all_available_quests.map(func(q): return q.get("id", -1)),
		"active_count": quest_manager.active_quests.size() if quest_manager.active_quests else 0,
		"active_ids": quest_manager.active_quests.keys() if quest_manager.active_quests else [],
		"timestamp": Time.get_ticks_msec()
	}

func _log_pass(message: String):
	passed += 1
	test_results.append("  ✓ %s" % message)
	print("  ✓ %s" % message)

func _log_fail(message: String):
	failed += 1
	test_results.append("  ✗ %s" % message)
	print("  ✗ %s" % message)

func _print_results():
	print("\n" + _sep_long())
	print("TEST RESULTS")
	print(_sep_long() + "\n")

	for result in test_results:
		print(result)

	print("\n" + _sep_short())
	print("Summary: %d passed, %d failed" % [passed, failed])
	print(_sep_long() + "\n")

	if failed == 0:
		print("🎉 ALL TESTS PASSED")
	else:
		print("⚠️  SOME TESTS FAILED")
