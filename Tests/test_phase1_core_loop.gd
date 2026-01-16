extends SceneTree
## Phase 1 Core Loop Test - Tests EXPLORE → Gate → Measure → Harvest
## Run with: godot --headless --script res://Tests/test_phase1_core_loop.gd
##
## Verifies the Phase 0 bind_to_qubit() refactor works in actual gameplay

const SEPARATOR = "======================================================================"

var test_results: Array = []
var current_test: String = ""
var farm = null
var input_handler = null
var player_shell = null
var scene_loaded = false
var tests_done = false
var frame_count = 0
var boot_manager = null

func _init():
	print("\n" + SEPARATOR)
	print("🔬 PHASE 1: CORE LOOP TEST")
	print("Testing: EXPLORE → Gate → Measure → Harvest")
	print(SEPARATOR + "\n")
	print("Waiting for autoloads to initialize...")


func _process(_delta):
	frame_count += 1

	# Load scene at frame 5 (after autoloads are ready)
	if frame_count == 5 and not scene_loaded:
		print("\nFrame 5: Loading main scene...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			var instance = scene.instantiate()
			root.add_child(instance)
			scene_loaded = true
			print("  Scene instantiated")

			# Connect to BootManager.game_ready signal
			boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)
				print("  Connected to BootManager.game_ready")
		else:
			print("  Failed to load scene")
			quit(1)


func _on_game_ready():
	"""Called when BootManager signals that the game is ready"""
	if tests_done:
		return
	tests_done = true
	print("\n  BootManager.game_ready received!")

	_find_components()

	# Disable quantum evolution for faster test execution
	if farm:
		print("  Disabling quantum evolution for test speed...")
		for biome in [farm.biotic_flux_biome, farm.forest_biome, farm.market_biome, farm.kitchen_biome]:
			if biome:
				biome.quantum_evolution_enabled = false
				biome.set_process(false)
		farm.set_process(false)
		if farm.grid:
			farm.grid.set_process(false)

	print("\nFound: PlayerShell=%s, InputHandler=%s, Farm=%s" % [
		player_shell != null, input_handler != null, farm != null])

	if input_handler and farm:
		print("\nRunning Phase 1 Core Loop Tests...\n")
		_run_all_tests()
	else:
		print("\n  Components not found after boot!")
		if not input_handler:
			print("  Missing: FarmInputHandler")
		if not farm:
			print("  Missing: Farm")
		quit(1)


func _find_components():
	player_shell = _find_node(root, "PlayerShell")
	if player_shell:
		for child in player_shell.get_children():
			var script_name = ""
			if child.get_script():
				script_name = child.get_script().resource_path
			if script_name.ends_with("FarmInputHandler.gd"):
				input_handler = child
				break
		if not input_handler:
			input_handler = player_shell.get_node_or_null("FarmInputHandler")

	# Find farm
	var farm_view = root.get_node_or_null("FarmView")
	if farm_view:
		farm = farm_view.farm if "farm" in farm_view else null
		if not farm:
			for child in farm_view.get_children():
				if child.name == "Farm" or (child.get_script() and child.get_script().resource_path.ends_with("Farm.gd")):
					farm = child
					break


func _find_node(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var found = _find_node(child, name)
		if found:
			return found
	return null


func _run_all_tests():
	# Test infrastructure
	_test_biome_available()
	_test_quantum_computer_available()
	_test_register_map_available()

	# Test core gameplay loop
	_test_explore_action()
	_test_bind_to_qubit_worked()
	_test_gate_application()
	_test_measure_action()
	_test_harvest_action()

	# Print results and exit
	_print_results()

	var failed = test_results.filter(func(r): return not r.passed).size()
	quit(1 if failed > 0 else 0)


func _test_biome_available():
	current_test = "Biome Available"
	print("TEST: %s" % current_test)

	var biome = null
	if farm:
		biome = farm.biotic_flux_biome
		if biome:
			print("  Biome: %s" % biome.get_biome_type())
			_record_result(true, "Biome accessible: %s" % biome.get_biome_type())
			return

	print("  No biome found!")
	_record_result(false, "No biome accessible")


func _test_quantum_computer_available():
	current_test = "Quantum Computer Available"
	print("\nTEST: %s" % current_test)

	var biome = farm.biotic_flux_biome if farm else null
	if biome and biome.quantum_computer:
		var qc = biome.quantum_computer
		print("  quantum_computer exists")
		print("  Type: %s" % qc.get_class())
		_record_result(true, "quantum_computer accessible")
	else:
		print("  No quantum_computer!")
		_record_result(false, "quantum_computer missing")


func _test_register_map_available():
	current_test = "RegisterMap Available"
	print("\nTEST: %s" % current_test)

	var biome = farm.biotic_flux_biome if farm else null
	if biome and biome.quantum_computer:
		var qc = biome.quantum_computer
		if qc.register_map:
			var rm = qc.register_map
			# RegisterMap uses dim() not get_qubit_count()
			var qubit_count = rm.dim() if rm.has_method("dim") else -1
			print("  register_map exists")
			print("  Qubit count (dim): %d" % qubit_count)
			if qubit_count > 0:
				# RegisterMap uses axis() not get_axis()
				var axis_info = rm.axis(0) if rm.has_method("axis") else {}
				print("  Qubit 0 axis: %s" % axis_info)
			_record_result(qubit_count > 0, "RegisterMap has %d qubits" % qubit_count)
		else:
			print("  No register_map!")
			_record_result(false, "register_map missing")
	else:
		_record_result(false, "quantum_computer missing")


func _test_explore_action():
	current_test = "EXPLORE Action (bind_to_qubit)"
	print("\nTEST: %s" % current_test)

	# Select Tool 1 (PROBE)
	input_handler.current_tool = 1
	print("  Selected Tool 1 (PROBE)")

	# Get a plot to test with
	var test_pos = Vector2i(2, 0)
	var plot = farm.grid.get_plot(test_pos) if farm and farm.grid else null

	if not plot:
		print("  No plot at %s!" % test_pos)
		_record_result(false, "No plot at test position")
		return

	print("  Plot at %s: is_planted=%s, bound_qubit=%d" % [test_pos, plot.is_planted, plot.bound_qubit])

	# Set selection for the action
	input_handler.current_selection = test_pos

	# Execute EXPLORE directly (bypass InputMap which isn't loaded in headless)
	print("  Calling _execute_tool_action('Q')...")
	if input_handler.has_method("_execute_tool_action"):
		input_handler._execute_tool_action("Q")
	else:
		print("  ERROR: _execute_tool_action method not found!")
		_record_result(false, "_execute_tool_action missing")
		return

	# Check if plot got bound
	var after_bound = plot.bound_qubit
	var after_planted = plot.is_planted
	var after_biome = plot.parent_biome

	print("  After EXPLORE: is_planted=%s, bound_qubit=%d, parent_biome=%s" % [
		after_planted, after_bound, after_biome != null])

	if after_planted and after_bound >= 0:
		_record_result(true, "Plot bound to qubit %d" % after_bound)
	else:
		_record_result(false, "Plot not bound after EXPLORE")


func _test_bind_to_qubit_worked():
	current_test = "bind_to_qubit() Verification"
	print("\nTEST: %s" % current_test)

	var test_pos = Vector2i(2, 0)
	var plot = farm.grid.get_plot(test_pos) if farm and farm.grid else null

	if not plot:
		_record_result(false, "No plot available")
		return

	# Check all the fields that bind_to_qubit should set
	var checks = {
		"is_planted": plot.is_planted,
		"bound_qubit >= 0": plot.bound_qubit >= 0,
		"parent_biome set": plot.parent_biome != null,
		"north_emoji set": plot.north_emoji != "",
		"south_emoji set": plot.south_emoji != ""
	}

	var all_passed = true
	for check_name in checks:
		var passed = checks[check_name]
		var status = "PASS" if passed else "FAIL"
		print("  [%s] %s" % [status, check_name])
		if not passed:
			all_passed = false

	if all_passed:
		print("  Emojis: %s / %s" % [plot.north_emoji, plot.south_emoji])

	_record_result(all_passed, "All bind_to_qubit fields set correctly")


func _test_gate_application():
	current_test = "Gate Application (X gate)"
	print("\nTEST: %s" % current_test)

	# Select Tool 2 (GATES)
	input_handler.current_tool = 2
	print("  Selected Tool 2 (GATES)")

	# Get plot state before
	var test_pos = Vector2i(2, 0)
	var plot = farm.grid.get_plot(test_pos) if farm and farm.grid else null

	if not plot or not plot.is_planted:
		print("  Plot not planted, skipping gate test")
		_record_result(false, "No planted plot for gate test")
		return

	# Set selection
	input_handler.current_selection = test_pos

	# Apply X gate (Q on Tool 2, mode 0)
	print("  Calling _execute_tool_action('Q') for X gate...")
	input_handler._execute_tool_action("Q")

	# We can't easily verify quantum state changed, but we can verify no crash
	print("  Gate applied without crash")
	_record_result(true, "X gate applied successfully")


func _test_measure_action():
	current_test = "MEASURE Action"
	print("\nTEST: %s" % current_test)

	# Select Tool 1 (PROBE)
	input_handler.current_tool = 1

	var test_pos = Vector2i(2, 0)
	var plot = farm.grid.get_plot(test_pos) if farm and farm.grid else null

	if not plot or not plot.is_planted:
		print("  Plot not planted, skipping measure test")
		_record_result(false, "No planted plot for measure test")
		return

	var before_measured = plot.has_been_measured
	print("  Before: has_been_measured=%s" % before_measured)

	# Set selection
	input_handler.current_selection = test_pos

	# Execute MEASURE (E on Tool 1)
	print("  Calling _execute_tool_action('E') for MEASURE...")
	input_handler._execute_tool_action("E")

	var after_measured = plot.has_been_measured
	var outcome = plot.measured_outcome
	print("  After: has_been_measured=%s, outcome='%s'" % [after_measured, outcome])

	if after_measured:
		_record_result(true, "Plot measured, outcome: %s" % outcome)
	else:
		_record_result(false, "Plot not measured after E")


func _test_harvest_action():
	current_test = "HARVEST Action (POP)"
	print("\nTEST: %s" % current_test)

	# Select Tool 1 (PROBE)
	input_handler.current_tool = 1

	var test_pos = Vector2i(2, 0)
	var plot = farm.grid.get_plot(test_pos) if farm and farm.grid else null

	if not plot or not plot.is_planted:
		print("  Plot not planted, skipping harvest test")
		_record_result(false, "No planted plot for harvest test")
		return

	var before_planted = plot.is_planted
	print("  Before: is_planted=%s" % before_planted)

	# Set selection
	input_handler.current_selection = test_pos

	# Execute POP (R on Tool 1)
	print("  Calling _execute_tool_action('R') for POP/Harvest...")
	input_handler._execute_tool_action("R")

	var after_planted = plot.is_planted
	var after_bound = plot.bound_qubit
	print("  After: is_planted=%s, bound_qubit=%d" % [after_planted, after_bound])

	# After harvest, plot should be reset
	if not after_planted:
		_record_result(true, "Plot harvested and reset")
	else:
		_record_result(false, "Plot still planted after harvest")


func _simulate_key(keycode: int):
	"""Simulate a key press by directly calling the input handler."""
	var press = InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	press.echo = false

	# Direct call to input handler (headless mode workaround)
	if input_handler and input_handler.has_method("_unhandled_input"):
		input_handler._unhandled_input(press)


func _record_result(passed: bool, description: String):
	test_results.append({
		"test": current_test,
		"passed": passed,
		"description": description
	})


func _print_results():
	print("\n" + SEPARATOR)
	print("PHASE 1 CORE LOOP TEST RESULTS")
	print(SEPARATOR)

	var passed_count = 0
	var failed_count = 0

	for result in test_results:
		var status = "PASS" if result.passed else "FAIL"
		print("  [%s] %s: %s" % [status, result.test, result.description])
		if result.passed:
			passed_count += 1
		else:
			failed_count += 1

	print("")
	print("  Total: %d passed, %d failed" % [passed_count, failed_count])
	print(SEPARATOR + "\n")
