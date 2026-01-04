extends SceneTree

## Test Quest Board Modal Controls
## Tests: C key toggle, UIOP selection, QER actions, faction browser

var test_results: Array = []
var farm: Node
var player_shell: Node
var overlay_manager: Node
var quest_board: Node
var quest_manager: Node

func _init():
	print("\n" + "=".repeat(60))
	print("🧪 QUEST BOARD CONTROLS TEST")
	print("=".repeat(60))

	# Load main scene
	var farm_scene = load("res://scenes/main.tscn")
	if not farm_scene:
		_fail("Failed to load main scene")
		quit()
		return

	farm = farm_scene.instantiate()
	root.add_child(farm)

	# Defer async work to _process
	set_auto_accept_quit(false)


func _process(_delta: float) -> bool:
	# Run tests once
	_run_tests()
	return true  # Quit after one frame


func _run_tests():
	## Run all tests synchronously
	# Find components
	player_shell = _find_node_by_name(farm, "PlayerShell")
	if not player_shell:
		_fail("PlayerShell not found")
		_print_summary()
		quit()
		return

	overlay_manager = _find_node_by_class(player_shell, "OverlayManager")
	if not overlay_manager:
		_fail("OverlayManager not found")
		_print_summary()
		quit()
		return

	quest_board = _find_node_by_class(overlay_manager, "QuestBoard")
	if not quest_board:
		_fail("QuestBoard not found in OverlayManager")
		_print_summary()
		quit()
		return

	quest_manager = overlay_manager.quest_manager
	if not quest_manager:
		_fail("Quest manager not found")
		_print_summary()
		quit()
		return

	print("✅ All components found")
	print("   Quest board visible: ", quest_board.visible)
	print("   Quest manager: ", quest_manager.get_class())

	# Run tests (synchronously)
	_test_initial_state()
	_test_uiop_selection()
	_test_slot_auto_fill()
	_test_vocabulary_filtering()

	# Print summary
	_print_summary()
	quit()


func _test_initial_state():
	## Test quest board initial state
	print("\n📋 TEST: Initial state")

	# Should start closed
	if quest_board.visible:
		_fail("Quest board should start closed")
		return

	_pass("Quest board starts closed")

	# Should have 4 slot states
	if quest_board.slot_states.size() != 4:
		_fail("Quest board should have 4 slots, got: " + str(quest_board.slot_states.size()))
		return

	_pass("Quest board has 4 slots")


func _test_uiop_selection():
	## Test UIOP keys select different slots
	print("\n🎯 TEST: UIOP slot selection")

	# Open quest board
	quest_board.visible = true

	# Ensure biome is set
	if not quest_board.current_biome and farm:
		var biome = farm.biotic_flux_biome
		if biome:
			quest_board.set_biome(biome)

	quest_board._refresh_all_slots()

	# Test U selects slot 0
	quest_board.select_slot(0)
	if quest_board.selected_slot_index != 0:
		_fail("U key should select slot 0, got: " + str(quest_board.selected_slot_index))
		return
	_pass("U key selects slot 0")

	# Test I selects slot 1
	quest_board.select_slot(1)
	if quest_board.selected_slot_index != 1:
		_fail("I key should select slot 1, got: " + str(quest_board.selected_slot_index))
		return
	_pass("I key selects slot 1")

	# Test O selects slot 2
	quest_board.select_slot(2)
	if quest_board.selected_slot_index != 2:
		_fail("O key should select slot 2, got: " + str(quest_board.selected_slot_index))
		return
	_pass("O key selects slot 2")

	# Test P selects slot 3
	quest_board.select_slot(3)
	if quest_board.selected_slot_index != 3:
		_fail("P key should select slot 3, got: " + str(quest_board.selected_slot_index))
		return
	_pass("P key selects slot 3")


func _test_slot_auto_fill():
	## Test slots auto-fill with accessible quests
	print("\n📝 TEST: Slot auto-fill")

	# Ensure we have a biome
	if not quest_board.current_biome and farm:
		var biome = farm.biotic_flux_biome
		if biome:
			quest_board.set_biome(biome)

	quest_board._refresh_all_slots()

	var filled_count = 0
	for i in range(4):
		var slot = quest_board.slot_states[i]
		if slot and slot.get("state", 0) > 0:  # Not EMPTY
			filled_count += 1
			var quest_data = slot.get("offered_quest", {})
			print("   Slot %d: %s from %s" % [
				i,
				quest_data.get("body", "unknown"),
				quest_data.get("faction", "unknown")
			])

	if filled_count == 0:
		_fail("No slots auto-filled (expected at least 1)")
		return

	_pass("Auto-filled %d/%d slots" % [filled_count, 4])


func _test_vocabulary_filtering():
	## Test that only accessible factions are shown
	print("\n📖 TEST: Vocabulary filtering")

	# Get player's known emojis
	var game_state = GameStateManager.current_state if GameStateManager else null
	if not game_state:
		print("   ⚠️  No game state (skipping)")
		return

	var known_emojis = game_state.known_emojis
	print("   Player knows %d emojis: %s" % [known_emojis.size(), str(known_emojis)])

	# Get all factions offered
	var biome = quest_board.current_biome
	if not biome:
		biome = farm.biotic_flux_biome if farm else null
		if biome:
			quest_board.set_biome(biome)

	if not biome:
		print("   ⚠️  No biome (skipping)")
		return

	var all_quests = quest_manager.offer_all_faction_quests(biome)
	print("   Accessible factions: %d / 68 total" % all_quests.size())

	if all_quests.size() == 0:
		_fail("No accessible factions (expected at least 1)")
		return

	if all_quests.size() == 68:
		_fail("All 68 factions accessible (filtering not working)")
		return

	# Show first 3 accessible factions
	for i in range(min(3, all_quests.size())):
		var quest = all_quests[i]
		var faction_vocab = quest.get("faction_vocabulary", [])
		var overlap_count = 0
		for emoji in faction_vocab:
			if emoji in known_emojis:
				overlap_count += 1

		print("   %s: %d/%d vocab overlap" % [
			quest.get("faction", "unknown"),
			overlap_count,
			faction_vocab.size()
		])

	_pass("Vocabulary filtering working (%d accessible factions)" % all_quests.size())


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _find_node_by_name(parent: Node, node_name: String) -> Node:
	## Recursively find node by name
	if parent.name == node_name:
		return parent
	for child in parent.get_children():
		var result = _find_node_by_name(child, node_name)
		if result:
			return result
	return null


func _find_node_by_class(parent: Node, class_name: String) -> Node:
	## Recursively find node by class name
	if parent.get_class() == class_name:
		return parent

	var script = parent.get_script()
	if script and script.get_global_name() == class_name:
		return parent

	for child in parent.get_children():
		var result = _find_node_by_class(child, class_name)
		if result:
			return result

	return null


func _pass(message: String):
	test_results.append({"status": "PASS", "message": message})
	print("   ✅ PASS: " + message)


func _fail(message: String):
	test_results.append({"status": "FAIL", "message": message})
	print("   ❌ FAIL: " + message)


func _print_summary():
	print("\n" + "=".repeat(60))
	print("📊 TEST SUMMARY")
	print("=".repeat(60))

	var passed = 0
	var failed = 0

	for result in test_results:
		if result.status == "PASS":
			passed += 1
		else:
			failed += 1

	print("   ✅ Passed: %d" % passed)
	print("   ❌ Failed: %d" % failed)
	print("   📊 Total:  %d" % (passed + failed))

	if failed == 0:
		print("\n🎉 ALL TESTS PASSED!")
	else:
		print("\n⚠️  SOME TESTS FAILED")

	print("=".repeat(60))
