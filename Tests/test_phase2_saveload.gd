extends SceneTree
## Phase 2 Save/Load Test - Tests serialization of Model C plot bindings
## Run with: godot --headless --script res://Tests/test_phase2_saveload.gd
##
## Verifies bound_qubit, parent_biome reference, emojis serialize/deserialize correctly

const SEPARATOR = "======================================================================"

var test_results: Array = []
var current_test: String = ""
var farm = null
var input_handler = null
var state_manager = null
var scene_loaded = false
var tests_done = false
var frame_count = 0
var boot_manager = null

func _init():
	print("\n" + SEPARATOR)
	print("PHASE 2: SAVE/LOAD TEST")
	print("Testing: Model C plot binding serialization")
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

	print("\nFound: Farm=%s, StateManager=%s, InputHandler=%s" % [
		farm != null, state_manager != null, input_handler != null])

	if farm and state_manager:
		print("\nRunning Phase 2 Save/Load Tests...\n")
		_run_all_tests()
	else:
		print("\n  Components not found after boot!")
		if not farm:
			print("  Missing: Farm")
		if not state_manager:
			print("  Missing: GameStateManager")
		quit(1)


func _find_components():
	# Find Farm
	var farm_view = root.get_node_or_null("FarmView")
	if farm_view:
		farm = farm_view.farm if "farm" in farm_view else null
		if not farm:
			for child in farm_view.get_children():
				if child.name == "Farm" or (child.get_script() and child.get_script().resource_path.ends_with("Farm.gd")):
					farm = child
					break

	# Find GameStateManager (autoload)
	state_manager = root.get_node_or_null("/root/GameStateManager")

	# Find PlayerShell and FarmInputHandler
	var player_shell = _find_node(root, "PlayerShell")
	if player_shell:
		for child in player_shell.get_children():
			var script_name = ""
			if child.get_script():
				script_name = child.get_script().resource_path
			if script_name.ends_with("FarmInputHandler.gd"):
				input_handler = child
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
	# Setup: Create game state with bound plots
	_test_setup_game_state()

	# Test serialization captures Model C fields
	_test_capture_state_contains_bound_qubit()
	_test_capture_state_contains_emojis()
	_test_capture_state_contains_measured_outcome()

	# Test deserialization restores Model C fields
	_test_apply_state_restores_bound_qubit()
	_test_apply_state_restores_parent_biome()
	_test_apply_state_restores_emojis()

	# Print results and exit
	_print_results()

	var failed = test_results.filter(func(r): return not r.passed).size()
	quit(1 if failed > 0 else 0)


func _test_setup_game_state():
	"""Setup: Create a game state with bound plots for testing"""
	current_test = "Setup Game State"
	print("TEST: %s" % current_test)

	if not input_handler:
		print("  ERROR: No input handler - skipping setup")
		_record_result(false, "No input handler")
		return

	# Select Tool 1 (PROBE)
	input_handler.current_tool = 1

	# EXPLORE 3 plots to bind them to qubits
	var test_positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]

	for pos in test_positions:
		input_handler.current_selection = pos
		input_handler._execute_tool_action("Q")  # EXPLORE

	# Verify at least one plot got bound
	var plot = farm.grid.get_plot(test_positions[0])
	if plot and plot.is_planted and plot.bound_qubit >= 0:
		print("  Created 3 bound plots")
		print("  Plot 0: bound_qubit=%d, north=%s, south=%s" % [
			plot.bound_qubit, plot.north_emoji, plot.south_emoji])
		_record_result(true, "Setup complete: 3 plots bound")
	else:
		print("  Failed to bind plots!")
		_record_result(false, "Plot binding failed")


func _test_capture_state_contains_bound_qubit():
	"""Test that capture_state_from_game includes bound_qubit"""
	current_test = "Capture State - bound_qubit"
	print("\nTEST: %s" % current_test)

	# Capture state
	var captured = state_manager.capture_state_from_game()

	if not captured or captured.plots.is_empty():
		print("  ERROR: No plots in captured state!")
		_record_result(false, "No plots captured")
		return

	# Check first planted plot for bound_qubit
	var found_bound_qubit = false
	for plot_data in captured.plots:
		if plot_data.get("is_planted", false):
			if plot_data.has("bound_qubit"):
				var bq = plot_data.get("bound_qubit", -1)
				print("  Found plot with bound_qubit=%d" % bq)
				if bq >= 0:
					found_bound_qubit = true
					break
			else:
				print("  MISSING: bound_qubit key not in plot_data!")
			break

	if found_bound_qubit:
		_record_result(true, "bound_qubit serialized correctly")
	else:
		_record_result(false, "bound_qubit NOT serialized")


func _test_capture_state_contains_emojis():
	"""Test that capture_state_from_game includes north/south_emoji"""
	current_test = "Capture State - emojis"
	print("\nTEST: %s" % current_test)

	var captured = state_manager.capture_state_from_game()

	var found_emojis = false
	for plot_data in captured.plots:
		if plot_data.get("is_planted", false):
			var has_north = plot_data.has("north_emoji")
			var has_south = plot_data.has("south_emoji")
			print("  has north_emoji: %s, has south_emoji: %s" % [has_north, has_south])

			if has_north and has_south:
				print("  Emojis: %s / %s" % [plot_data["north_emoji"], plot_data["south_emoji"]])
				found_emojis = true
			break

	if found_emojis:
		_record_result(true, "emojis serialized correctly")
	else:
		_record_result(false, "emojis NOT serialized")


func _test_capture_state_contains_measured_outcome():
	"""Test that measured_outcome is serialized"""
	current_test = "Capture State - measured_outcome"
	print("\nTEST: %s" % current_test)

	# First, measure a plot
	var test_pos = Vector2i(0, 0)
	var plot = farm.grid.get_plot(test_pos)

	if plot and plot.is_planted and not plot.has_been_measured:
		input_handler.current_selection = test_pos
		input_handler.current_tool = 1  # PROBE
		input_handler._execute_tool_action("E")  # MEASURE
		print("  Measured plot at %s, outcome: %s" % [test_pos, plot.measured_outcome])

	# Now capture state
	var captured = state_manager.capture_state_from_game()

	var found_measured_outcome = false
	for plot_data in captured.plots:
		if plot_data.get("has_been_measured", false):
			if plot_data.has("measured_outcome"):
				print("  Found measured_outcome: %s" % plot_data["measured_outcome"])
				found_measured_outcome = true
			else:
				print("  MISSING: measured_outcome key!")
			break

	if found_measured_outcome:
		_record_result(true, "measured_outcome serialized correctly")
	else:
		_record_result(false, "measured_outcome NOT serialized")


func _test_apply_state_restores_bound_qubit():
	"""Test that apply_state_to_game restores bound_qubit"""
	current_test = "Restore - bound_qubit"
	print("\nTEST: %s" % current_test)

	# Capture current state
	var captured = state_manager.capture_state_from_game()

	# Get original bound_qubit value from a planted plot
	var test_pos = Vector2i(1, 0)  # Use plot we haven't measured
	var original_plot = farm.grid.get_plot(test_pos)
	var original_bound_qubit = original_plot.bound_qubit if original_plot else -1
	print("  Original bound_qubit: %d" % original_bound_qubit)

	# Reset the plot manually
	if original_plot:
		original_plot.bound_qubit = -1
		original_plot.is_planted = false
		original_plot.parent_biome = null
		print("  Cleared plot: bound_qubit=%d" % original_plot.bound_qubit)

	# Apply saved state
	state_manager.apply_state_to_game(captured)

	# Check if bound_qubit was restored
	var restored_plot = farm.grid.get_plot(test_pos)
	var restored_bound_qubit = restored_plot.bound_qubit if restored_plot else -1
	print("  Restored bound_qubit: %d" % restored_bound_qubit)

	if restored_bound_qubit == original_bound_qubit and restored_bound_qubit >= 0:
		_record_result(true, "bound_qubit restored: %d" % restored_bound_qubit)
	else:
		_record_result(false, "bound_qubit NOT restored (expected %d, got %d)" % [
			original_bound_qubit, restored_bound_qubit])


func _test_apply_state_restores_parent_biome():
	"""Test that apply_state_to_game restores parent_biome reference"""
	current_test = "Restore - parent_biome"
	print("\nTEST: %s" % current_test)

	var test_pos = Vector2i(1, 0)
	var plot = farm.grid.get_plot(test_pos)

	if not plot:
		_record_result(false, "No plot to check")
		return

	var parent = plot.parent_biome
	print("  parent_biome: %s" % (parent.get_biome_type() if parent else "NULL"))

	if parent != null:
		_record_result(true, "parent_biome restored: %s" % parent.get_biome_type())
	else:
		_record_result(false, "parent_biome NOT restored (is null)")


func _test_apply_state_restores_emojis():
	"""Test that north/south_emoji are restored after load"""
	current_test = "Restore - emojis"
	print("\nTEST: %s" % current_test)

	var test_pos = Vector2i(1, 0)
	var plot = farm.grid.get_plot(test_pos)

	if not plot:
		_record_result(false, "No plot to check")
		return

	var north = plot.north_emoji
	var south = plot.south_emoji
	print("  north_emoji: %s, south_emoji: %s" % [north, south])

	if not north.is_empty() and not south.is_empty() and north != "?" and south != "?":
		_record_result(true, "emojis restored: %s / %s" % [north, south])
	else:
		_record_result(false, "emojis NOT restored properly")


func _record_result(passed: bool, description: String):
	test_results.append({
		"test": current_test,
		"passed": passed,
		"description": description
	})


func _print_results():
	print("\n" + SEPARATOR)
	print("PHASE 2 SAVE/LOAD TEST RESULTS")
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
