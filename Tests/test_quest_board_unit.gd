extends SceneTree

## Unit test for QuestBoard class

const QuestBoard = preload("res://UI/Panels/QuestBoard.gd")
const Farm = preload("res://Core/Farm.gd")

var farm: Farm
var quest_board: QuestBoard

func _init():
	print("\n" + "=".repeat(60))
	print("🧪 QUEST BOARD UNIT TEST")
	print("=".repeat(60))

	# Create farm first
	farm = Farm.new()
	root.add_child(farm)

	# Wait for farm initialization
	var timer = Timer.new()
	root.add_child(timer)
	timer.wait_time = 0.2
	timer.one_shot = true
	timer.timeout.connect(_start_tests)
	timer.start()


func _start_tests():
	print("\n✅ Farm initialized")

	# Create quest board
	quest_board = QuestBoard.new()
	root.add_child(quest_board)

	print("✅ Quest board created")

	# Test basic properties
	_test_initial_state()
	_test_slot_structure()
	_test_set_biome()

	# Print results
	print("\n" + "=".repeat(60))
	print("✅ ALL UNIT TESTS PASSED!")
	print("=".repeat(60))

	quit()


func _test_initial_state():
	print("\n📋 TEST: Initial state")

	# Should start closed
	if quest_board.visible:
		_fail("Quest board should start closed")
		return

	print("   ✅ Quest board starts closed")

	# Should have 4 slot states
	if quest_board.slot_states.size() != 4:
		_fail("Quest board should have 4 slots, got: " + str(quest_board.slot_states.size()))
		return

	print("   ✅ Quest board has 4 slots")


func _test_slot_structure():
	print("\n🎯 TEST: Slot structure")

	# Each slot should be initialized
	for i in range(4):
		var slot = quest_board.slot_states[i]
		if slot == null:
			_fail("Slot %d is null" % i)
			return

		if not slot.has("state"):
			_fail("Slot %d missing 'state' field" % i)
			return

		if not slot.has("is_locked"):
			_fail("Slot %d missing 'is_locked' field" % i)
			return

	print("   ✅ All slots have proper structure")


func _test_set_biome():
	print("\n🌾 TEST: Set biome")

	var biome = farm.biotic_flux_biome
	if not biome:
		print("   ⚠️  No biome found (skipping)")
		return

	quest_board.set_biome(biome)

	if quest_board.current_biome != biome:
		_fail("Biome not set correctly")
		return

	print("   ✅ Biome set successfully")

	# Check if slots auto-filled
	quest_board._refresh_all_slots()

	var filled_count = 0
	for i in range(4):
		var slot = quest_board.slot_states[i]
		if slot and slot.get("state", 0) > 0:  # Not EMPTY
			filled_count += 1

	print("   ✅ Auto-filled %d/%d slots" % [filled_count, 4])


func _fail(message: String):
	print("   ❌ FAIL: " + message)
	quit(1)
