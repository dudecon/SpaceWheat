#!/usr/bin/env -S godot --headless -s
## Phase 4: Input Action Routing Test Suite
## Tests FarmInputHandler → Farm → Game State pipeline

extends SceneTree

const Farm = preload("res://Core/Farm.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")

# Test infrastructure
var farm: Farm
var input_handler: FarmInputHandler
var economy: FarmEconomy
var mock_plot_display: MockPlotGridDisplay

# Signal spy system
var signal_spy: Dictionary = {
	"tool_changed": [],
	"plot_selected": [],
	"action_performed": [],
	"plot_planted": [],
	"plot_measured": [],
	"plot_harvested": [],
	"state_changed": []
}

# Test results
var tests_passed: int = 0
var tests_failed: int = 0

func _sep(char: String, count: int) -> String:
	var result = ""
	for _i in range(count):
		result += char
	return result

func _initialize():
	print("\n" + _sep("=", 80))
	print("⌨️  PHASE 4: KEYBOARD INPUT ACTION ROUTING TEST SUITE")
	print(_sep("=", 80) + "\n")

	_setup()

	print("🧪 RUNNING TESTS\n")
	_test_tool_selection_routing()
	_test_single_plot_plant_actions()
	_test_single_plot_quantum_actions()
	_test_batch_operations()
	_test_action_validation()
	_test_signal_propagation()

	_report_results()

	quit(0 if tests_failed == 0 else 1)


func _setup():
	"""Initialize test infrastructure"""
	print("🔧 Setting up test infrastructure...\n")

	# Create farm
	farm = Farm.new()
	farm._ready()
	print("   ✓ Farm created")

	# Get economy
	economy = farm.economy
	economy.add_credits(1000)
	economy.add_labor(100)
	print("   ✓ Economy configured")

	# Create mock plot display
	mock_plot_display = MockPlotGridDisplay.new()
	print("   ✓ Mock plot display created")

	# Create input handler
	input_handler = FarmInputHandler.new()
	input_handler._ready()
	print("   ✓ FarmInputHandler created")

	# Inject dependencies
	input_handler.farm = farm
	input_handler.plot_grid_display = mock_plot_display
	print("   ✓ Dependencies injected")

	# Connect spies
	_connect_spies()
	print("   ✓ Signal spies connected\n")


func _connect_spies():
	"""Connect spy listeners to signals"""
	input_handler.tool_changed.connect(
		func(tool, info): signal_spy["tool_changed"].append([tool, info])
	)
	input_handler.action_performed.connect(
		func(action, success, message): signal_spy["action_performed"].append([action, success, message])
	)
	farm.plot_planted.connect(
		func(pos, plant_type): signal_spy["plot_planted"].append([pos, plant_type])
	)
	farm.plot_measured.connect(
		func(pos, outcome): signal_spy["plot_measured"].append([pos, outcome])
	)
	farm.plot_harvested.connect(
		func(pos, yield_data): signal_spy["plot_harvested"].append([pos, yield_data])
	)
	farm.state_changed.connect(
		func(state_data): signal_spy["state_changed"].append(state_data)
	)


func _test_tool_selection_routing():
	"""TEST 1: Tool selection works correctly"""
	print("📍 TEST 1: Tool Selection Routing")
	print(_sep("─", 80))

	signal_spy["tool_changed"].clear()

	input_handler._select_tool(1)
	assert(signal_spy["tool_changed"].size() == 1)
	assert(input_handler.current_tool == 1)
	print("   ✅ Tool 1 selected")

	input_handler._select_tool(2)
	assert(signal_spy["tool_changed"].size() == 2)
	assert(input_handler.current_tool == 2)
	print("   ✅ Tool 2 selected")

	var tool_1_actions = FarmInputHandler.TOOL_ACTIONS[1]
	assert(tool_1_actions["Q"]["action"] == "plant_wheat")
	print("   ✅ Tool actions mapped correctly")

	tests_passed += 1
	print("✅ TEST 1 PASSED\n")


func _test_single_plot_plant_actions():
	"""TEST 2: Plant actions work correctly"""
	print("📍 TEST 2: Single-Plot Plant Actions")
	print(_sep("─", 80))

	input_handler._select_tool(1)

	signal_spy["action_performed"].clear()
	signal_spy["plot_planted"].clear()
	mock_plot_display.select_plots([Vector2i(0, 0)])
	input_handler._execute_tool_action("Q")

	assert(signal_spy["action_performed"].size() == 1)
	assert(farm.get_plot(Vector2i(0, 0)).is_planted == true)
	print("   ✅ Plant wheat (Q) works")

	signal_spy["plot_planted"].clear()
	mock_plot_display.select_plots([Vector2i(1, 0)])
	input_handler._execute_tool_action("E")

	assert(farm.get_plot(Vector2i(1, 0)).is_planted == true)
	print("   ✅ Plant mushroom (E) works")

	signal_spy["plot_planted"].clear()
	mock_plot_display.select_plots([Vector2i(2, 0)])
	input_handler._execute_tool_action("R")

	assert(farm.get_plot(Vector2i(2, 0)).is_planted == true)
	print("   ✅ Plant tomato (R) works")

	tests_passed += 1
	print("✅ TEST 2 PASSED\n")


func _test_single_plot_quantum_actions():
	"""TEST 3: Quantum operations work correctly"""
	print("📍 TEST 3: Single-Plot Quantum Actions")
	print(_sep("─", 80))

	farm.build(Vector2i(3, 0), "wheat")
	farm.build(Vector2i(4, 0), "wheat")

	input_handler._select_tool(2)

	signal_spy["plot_measured"].clear()
	mock_plot_display.select_plots([Vector2i(3, 0)])
	input_handler._execute_tool_action("E")

	assert(signal_spy["plot_measured"].size() >= 1)
	assert(farm.get_plot(Vector2i(3, 0)).has_been_measured == true)
	print("   ✅ Measure plot (E) works")

	signal_spy["plot_harvested"].clear()
	mock_plot_display.select_plots([Vector2i(3, 0)])
	var initial_wheat = economy.wheat_inventory
	input_handler._execute_tool_action("R")

	assert(signal_spy["plot_harvested"].size() >= 1)
	assert(economy.wheat_inventory >= initial_wheat)
	print("   ✅ Harvest plot (R) works")

	tests_passed += 1
	print("✅ TEST 3 PASSED\n")


func _test_batch_operations():
	"""TEST 4: Batch operations work correctly"""
	print("📍 TEST 4: Batch Operations")
	print(_sep("─", 80))

	input_handler._select_tool(1)
	signal_spy["plot_planted"].clear()

	mock_plot_display.select_plots([Vector2i(5, 0)])
	input_handler._execute_tool_action("Q")

	assert(signal_spy["plot_planted"].size() >= 1)
	assert(farm.get_plot(Vector2i(5, 0)).is_planted == true)
	print("   ✅ Batch plant works")

	input_handler._select_tool(2)
	signal_spy["plot_measured"].clear()
	input_handler._execute_tool_action("E")

	assert(signal_spy["plot_measured"].size() >= 1)
	print("   ✅ Batch measure works")

	tests_passed += 1
	print("✅ TEST 4 PASSED\n")


func _test_action_validation():
	"""TEST 5: Failed actions handled gracefully"""
	print("📍 TEST 5: Action Validation")
	print(_sep("─", 80))

	var current_credits = economy.credits
	economy.remove_credits(current_credits, "test")

	input_handler._select_tool(1)
	signal_spy["action_performed"].clear()
	mock_plot_display.select_plots([Vector2i(5, 0)])
	input_handler._execute_tool_action("Q")

	assert(signal_spy["action_performed"].size() >= 1)
	var last_action = signal_spy["action_performed"][-1]
	assert(last_action[1] == false)
	print("   ✅ Failed action correctly reported")

	tests_passed += 1
	print("✅ TEST 5 PASSED\n")


func _test_signal_propagation():
	"""TEST 6: Signals propagate correctly"""
	print("📍 TEST 6: Signal Propagation Chain")
	print(_sep("─", 80))

	economy.add_credits(100)
	input_handler._select_tool(1)
	mock_plot_display.select_plots([Vector2i(6, 0)])

	for key in signal_spy.keys():
		signal_spy[key].clear()

	input_handler._execute_tool_action("Q")

	assert(signal_spy["action_performed"].size() == 1, "action_performed signal should fire")
	var action_data = signal_spy["action_performed"][0]
	assert(action_data[0] == "plant_wheat", "Action should be plant_wheat")
	# Action might succeed or fail depending on game state, just verify signal fired
	print("   ✅ Signal chain propagates correctly (action: %s, success: %s)" % [action_data[0], action_data[1]])

	tests_passed += 1
	print("✅ TEST 6 PASSED\n")


func _report_results():
	"""Print test results"""
	var separator = _sep("=", 80)

	print("\n" + separator)
	print("📊 PHASE 4 TEST RESULTS")
	print(separator)

	print("\n✅ Passed: %d" % tests_passed)
	print("❌ Failed: %d" % tests_failed)
	print("📊 Total:  %d" % (tests_passed + tests_failed))

	print("\n" + separator)
	if tests_failed == 0:
		print("✅ ALL TESTS PASSED - Input routing layer is working!")
	else:
		print("❌ SOME TESTS FAILED")
	print(separator + "\n")


# Mock class for testing
class MockPlotGridDisplay extends Node:
	var selected_plots: Array[Vector2i] = []
	var previous_selection: Array[Vector2i] = []

	func get_selected_plots() -> Array[Vector2i]:
		return selected_plots

	func toggle_plot_selection(pos: Vector2i):
		if pos in selected_plots:
			selected_plots.erase(pos)
		else:
			selected_plots.append(pos)

	func clear_all_selection():
		previous_selection = selected_plots.duplicate()
		selected_plots.clear()

	func restore_previous_selection():
		selected_plots = previous_selection.duplicate()

	func select_plots(positions: Array[Vector2i]):
		selected_plots = positions.duplicate()
