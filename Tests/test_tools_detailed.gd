#!/usr/bin/env -S godot --headless -s
## Detailed tool action test with proper preconditions

extends SceneTree

const Farm = preload("res://Core/Farm.gd")
const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")

var farm: Farm
var input_handler: FarmInputHandler
var test_cases = []

func _sep(char: String, count: int) -> String:
	var result = ""
	for _i in range(count):
		result += char
	return result


func _initialize():
	print("\n" + _sep("═", 100))
	print("🔧 DETAILED TOOL ACTION TEST WITH PRECONDITIONS")
	print(_sep("═", 100) + "\n")

	_setup()
	_run_tests()
	_print_results()

	quit(0)


func _setup():
	print("📋 SETUP\n")

	farm = Farm.new()
	farm._ready()
	print("  ✓ Farm initialized (6x1 grid)")

	input_handler = FarmInputHandler.new()
	input_handler.farm = farm
	input_handler.action_performed.connect(_on_action_performed)
	print("  ✓ Input handler initialized\n")


func _run_tests():
	print("\n" + _sep("═", 100))
	print("EXECUTING TEST CASES")
	print(_sep("═", 100) + "\n")

	# Tool 1: Grower
	print("TOOL 1: GROWER 🌱\n")
	input_handler._select_tool(1)
	_test_case("Plant wheat on plot 0", Vector2i(0, 0), "plant_batch", [Vector2i(0, 0)])
	_test_case("Plant wheat on plot 1", Vector2i(1, 0), "plant_batch", [Vector2i(1, 0)])
	_test_case("Plant wheat on plot 2", Vector2i(2, 0), "plant_batch", [Vector2i(2, 0)])
	_test_case("Entangle plots 0,1 (2 plots)", Vector2i(0, 0), "entangle_batch", [Vector2i(0, 0), Vector2i(1, 0)])
	_test_case("Harvest plot 2", Vector2i(2, 0), "measure_and_harvest", [Vector2i(2, 0)])

	# Tool 2: Quantum
	print("\nTOOL 2: QUANTUM ⚛️\n")
	input_handler._select_tool(2)
	_test_case("Cluster plots 0,1,2 (3 plots - but only 0,1 have crops)", Vector2i(0, 0), "cluster", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	_test_case("Measure plot 0", Vector2i(0, 0), "measure_plot", [Vector2i(0, 0)])
	_test_case("Break entanglement on plot 1", Vector2i(1, 0), "break_entanglement", [Vector2i(1, 0)])

	# Tool 3: Industry
	print("\nTOOL 3: INDUSTRY 🏭\n")
	input_handler._select_tool(3)
	_test_case("Build mill on plot 3", Vector2i(3, 0), "place_mill", [Vector2i(3, 0)])
	_test_case("Build market on plot 4", Vector2i(4, 0), "place_market", [Vector2i(4, 0)])
	_test_case("Build kitchen on plot 5", Vector2i(5, 0), "place_kitchen", [Vector2i(5, 0)])

	# Tool 4: Energy
	print("\nTOOL 4: ENERGY ⚡\n")
	input_handler._select_tool(4)
	_test_case("Inject energy into plot 0", Vector2i(0, 0), "inject_energy", [Vector2i(0, 0)])
	_test_case("Drain energy from plot 0", Vector2i(0, 0), "drain_energy", [Vector2i(0, 0)])
	_test_case("Place energy tap on plot 3", Vector2i(3, 0), "place_energy_tap", [Vector2i(3, 0)])


func _test_case(description: String, plot_pos: Vector2i, action_name: String, positions: Array[Vector2i]):
	"""Execute a single test case"""
	print("  Testing: %s" % description)
	input_handler._set_selection(plot_pos)
	_execute_action(action_name, positions)
	print("")


func _execute_action(action_name: String, positions: Array[Vector2i]):
	"""Execute a specific action handler"""
	match action_name:
		"plant_batch":
			input_handler._action_plant_batch(positions)
		"entangle_batch":
			input_handler._action_entangle_batch(positions)
		"measure_and_harvest":
			input_handler._action_batch_measure_and_harvest(positions)
		"cluster":
			input_handler._action_cluster(positions)
		"measure_plot":
			input_handler._action_batch_measure(positions)
		"break_entanglement":
			input_handler._action_break_entanglement(positions)
		"place_mill":
			input_handler._action_batch_build("mill", positions)
		"place_market":
			input_handler._action_batch_build("market", positions)
		"place_kitchen":
			input_handler._action_batch_build("kitchen", positions)
		"inject_energy":
			input_handler._action_inject_energy(positions)
		"drain_energy":
			input_handler._action_drain_energy(positions)
		"place_energy_tap":
			input_handler._action_place_energy_tap(positions)
		_:
			print("    WARNING: Unknown action: %s" % action_name)


func _on_action_performed(action: String, success: bool, message: String):
	var status = "✓" if success else "✗"
	print("    [%s] %s - %s" % [status, action, message])

	test_cases.append({
		"action": action,
		"success": success,
		"message": message
	})


func _print_results():
	print("\n" + _sep("═", 100))
	print("RESULTS SUMMARY")
	print(_sep("═", 100) + "\n")

	var total_success = 0
	var total_failed = 0
	var by_action = {}

	for test in test_cases:
		var action = test["action"]
		if not by_action.has(action):
			by_action[action] = {"success": 0, "failed": 0}

		if test["success"]:
			by_action[action]["success"] += 1
			total_success += 1
		else:
			by_action[action]["failed"] += 1
			total_failed += 1

	# Sort and print
	var actions = by_action.keys()
	for action in actions:
		var result = by_action[action]
		var status = "✓" if result["failed"] == 0 else "⚠"
		print("  %s %s: %d success, %d failed" % [status, action, result["success"], result["failed"]])

	print("\n" + _sep("═", 100))
	if total_failed == 0:
		print("✅ ALL %d ACTIONS PASSED!" % total_success)
	else:
		print("⚠  %d actions succeeded, %d failed" % [total_success, total_failed])
	print(_sep("═", 100) + "\n")
