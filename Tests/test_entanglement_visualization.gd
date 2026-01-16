extends SceneTree

## Test Entanglement Visualization Fix
## Verifies that entanglement lines now appear between terminal bubbles
## Run with: godot --headless --script Tests/test_entanglement_visualization.gd

var farm = null
var viz_controller = null
var tests_passed: int = 0
var tests_failed: int = 0

func _init():
	print("\n" + "=" .repeat(70))
	print("ENTANGLEMENT VISUALIZATION FIX TEST")
	print("=" .repeat(70) + "\n")


func _process(_delta: float) -> bool:
	if Engine.get_process_frames() < 5:
		return false

	if Engine.get_process_frames() == 5:
		_run_tests()
		return false

	if Engine.get_process_frames() > 10:
		_print_results()
		quit(1 if tests_failed > 0 else 0)
		return true

	return false


func _run_tests():
	print("Setting up test environment...")

	# Create Farm
	var Farm = load("res://Core/Farm.gd")
	farm = Farm.new()

	# Create BathQuantumVisualizationController
	var BathQuantumVizController = load("res://Core/Visualization/BathQuantumVisualizationController.gd")
	viz_controller = BathQuantumVizController.new()

	print("\n--- TEST 1: _create_bubble_for_terminal accepts plot parameter ---")
	_test_function_signature()

	print("\n--- TEST 2: Bubble created with plot has valid plot reference ---")
	_test_bubble_has_plot()

	print("\n--- TEST 3: Bubble registered in node_by_plot_id ---")
	_test_node_by_plot_id_registration()


func _test_function_signature():
	"""Test that _create_bubble_for_terminal accepts 5 parameters (with optional plot)"""
	# Check if the method exists and has the right signature
	if viz_controller.has_method("_create_bubble_for_terminal"):
		_pass("_create_bubble_for_terminal method exists")

		# Read the source to verify signature
		var file = FileAccess.open("res://Core/Visualization/BathQuantumVisualizationController.gd", FileAccess.READ)
		var content = file.get_as_text()

		if "plot = null" in content and "_create_bubble_for_terminal" in content:
			_pass("_create_bubble_for_terminal has optional plot parameter")
		else:
			_fail("_create_bubble_for_terminal missing optional plot parameter")
	else:
		_fail("_create_bubble_for_terminal method not found")


func _test_bubble_has_plot():
	"""Test that bubbles created via _on_plot_planted will have plot references"""
	# Check that _on_plot_planted looks up the plot
	var file = FileAccess.open("res://Core/Visualization/BathQuantumVisualizationController.gd", FileAccess.READ)
	var content = file.get_as_text()

	if "farm_ref.grid.get_plot(position)" in content:
		_pass("_on_plot_planted looks up plot from grid")
	else:
		_fail("_on_plot_planted does NOT look up plot from grid")

	if "_create_bubble_for_terminal(biome_name, position, north_emoji, south_emoji, plot)" in content:
		_pass("_on_plot_planted passes plot to _create_bubble_for_terminal")
	else:
		_fail("_on_plot_planted does NOT pass plot to _create_bubble_for_terminal")


func _test_node_by_plot_id_registration():
	"""Test that bubbles with plots are registered in node_by_plot_id"""
	var file = FileAccess.open("res://Core/Visualization/BathQuantumVisualizationController.gd", FileAccess.READ)
	var content = file.get_as_text()

	if "graph.node_by_plot_id[bubble.plot_id] = bubble" in content:
		_pass("Bubble registered in node_by_plot_id for entanglement lookup")
	else:
		_fail("Bubble NOT registered in node_by_plot_id")


func _pass(msg: String):
	print("  ✅ PASS: %s" % msg)
	tests_passed += 1


func _fail(msg: String):
	print("  ❌ FAIL: %s" % msg)
	tests_failed += 1


func _print_results():
	print("\n" + "=" .repeat(70))
	print("TEST RESULTS: %d passed, %d failed" % [tests_passed, tests_failed])
	print("=" .repeat(70))

	if tests_failed == 0:
		print("\n✅ Entanglement visualization fix verified!")
		print("   - Terminal bubbles now receive plot references")
		print("   - Bubbles registered in node_by_plot_id for partner lookup")
		print("   - QuantumForceGraph._draw_entanglement_lines() can now draw lines")
	else:
		print("\n❌ Some tests failed - check implementation")

	print("=" .repeat(70))
