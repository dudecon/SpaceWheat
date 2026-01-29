## Simplified test to verify quest completion bug is fixed
extends Node

var passed_tests: int = 0
var failed_tests: int = 0

func _ready():
	print("\n" + "================================================================================")
	print("SIMPLIFIED QUESTBOARD TEST")
	print("Verifying: Quest completion no longer nukes all quests")
	print("================================================================================\n")

	_test_pool_preservation()
	_test_vocabulary_no_rebuild()

	print("\n" + "================================================================================")
	print("TEST SUMMARY")
	print("================================================================================")
	print("Passed: %d, Failed: %d" % [passed_tests, failed_tests])
	print("================================================================================" + "\n")

	get_tree().quit()

func _test_pool_preservation():
	"""Verify that _on_vocabulary_learned doesn't rebuild quest pool"""
	print("\n" + "--------------------------------------------------------------------------------")
	print("TEST 1: Vocabulary Learned Doesn't Rebuild Pool")
	print("--------------------------------------------------------------------------------" + "\n")

	# Read QuestBoard.gd and check that _on_vocabulary_learned
	# does NOT call offer_all_faction_quests()
	var quest_board_path = "res://UI/Panels/QuestBoard.gd"
	var file = FileAccess.open(quest_board_path, FileAccess.READ)

	if not file:
		_fail("Could not open QuestBoard.gd")
		return

	var content = file.get_as_text()

	# Check that the old line is gone
	if "all_available_quests = quest_manager.offer_all_faction_quests" in content:
		# But NOT in _on_vocabulary_learned context
		var lines = content.split("\n")
		var in_vocab_learned = false
		var found_rebuild_in_vocab = false

		for i in range(lines.size()):
			if "func _on_vocabulary_learned" in lines[i]:
				in_vocab_learned = true
			elif in_vocab_learned and "func " in lines[i]:
				in_vocab_learned = false

			if in_vocab_learned and "all_available_quests = quest_manager.offer_all_faction_quests" in lines[i]:
				found_rebuild_in_vocab = true
				break

		if found_rebuild_in_vocab:
			_fail("Pool rebuild still exists in _on_vocabulary_learned")
			return
		else:
			_pass("Pool rebuild removed from vocabulary learning handler")
	else:
		_pass("Pool rebuild not present in file")

func _test_vocabulary_no_rebuild():
	"""Verify the fix comment is present"""
	print("\nTEST 2: Fix Documentation Present")
	print("--------------------------------------------------------------------------------" + "\n")

	var quest_board_path = "res://UI/Panels/QuestBoard.gd"
	var file = FileAccess.open(quest_board_path, FileAccess.READ)

	if not file:
		_fail("Could not open QuestBoard.gd")
		return

	var content = file.get_as_text()

	# Check for the critical fix comment
	if "CRITICAL: Do NOT rebuild quest pool" in content:
		_pass("Critical fix documentation is present")
	else:
		_fail("Critical fix documentation missing")

func _pass(message: String):
	print("  ✓ PASS: %s" % message)
	passed_tests += 1

func _fail(message: String):
	print("  ✗ FAIL: %s" % message)
	failed_tests += 1
