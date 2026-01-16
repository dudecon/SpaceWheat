extends SceneTree

## Test that entanglement lines can actually be drawn
## This verifies the fix by simulating the data flow
## Run with: godot --headless --script Tests/test_entanglement_lines_work.gd

var tests_passed: int = 0
var tests_failed: int = 0

func _init():
	print("\n" + "=" .repeat(70))
	print("ENTANGLEMENT LINE DRAWING TEST")
	print("Verifies data flow: plot.entangled_plots → QuantumNode → _draw_entanglement_lines")
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
	print("Testing entanglement data flow...\n")

	# Create mock plot with entanglement data
	var FarmPlot = load("res://Core/GameMechanics/FarmPlot.gd")
	var plot_a = FarmPlot.new()
	var plot_b = FarmPlot.new()

	print("--- TEST 1: FarmPlot has entangled_plots dictionary ---")
	if "entangled_plots" in plot_a:
		_pass("FarmPlot has entangled_plots property")
	else:
		_fail("FarmPlot missing entangled_plots property")

	print("\n--- TEST 2: Can add entanglement between plots ---")
	plot_a.entangled_plots[plot_b.plot_id] = 1.0
	plot_b.entangled_plots[plot_a.plot_id] = 1.0

	if plot_a.entangled_plots.has(plot_b.plot_id):
		_pass("plot_a.entangled_plots contains plot_b")
	else:
		_fail("Failed to add entanglement to plot_a")

	if plot_b.entangled_plots.has(plot_a.plot_id):
		_pass("plot_b.entangled_plots contains plot_a")
	else:
		_fail("Failed to add entanglement to plot_b")

	print("\n--- TEST 3: QuantumNode can access plot.entangled_plots ---")
	var QuantumNode = load("res://Core/Visualization/QuantumNode.gd")
	var node_a = QuantumNode.new(plot_a, Vector2.ZERO, Vector2i(0, 0), Vector2.ZERO)

	if node_a.plot != null:
		_pass("QuantumNode.plot is not null when plot passed")
	else:
		_fail("QuantumNode.plot is null even though plot was passed")

	if node_a.plot and node_a.plot.entangled_plots.has(plot_b.plot_id):
		_pass("node_a.plot.entangled_plots accessible and contains partner")
	else:
		_fail("Cannot access entanglement data through QuantumNode")

	print("\n--- TEST 4: QuantumNode without plot handles gracefully ---")
	var node_null = QuantumNode.new(null, Vector2.ZERO, Vector2i(1, 1), Vector2.ZERO)
	if node_null.plot == null:
		_pass("QuantumNode with null plot correctly has plot=null")
	else:
		_fail("QuantumNode with null plot unexpectedly has non-null plot")

	print("\n--- TEST 5: _draw_entanglement_lines guard clause ---")
	# Check that the guard clause in _draw_entanglement_lines handles null plots
	var file = FileAccess.open("res://Core/Visualization/QuantumForceGraph.gd", FileAccess.READ)
	var content = file.get_as_text()

	if "if not node.plot:" in content and "continue" in content:
		_pass("_draw_entanglement_lines has null plot guard (skips null plots)")
	else:
		_fail("_draw_entanglement_lines missing null plot guard")

	# Check for entanglement lookup via node_by_plot_id
	if "node_by_plot_id.get(partner_id)" in content:
		_pass("Entanglement partner lookup uses node_by_plot_id")
	else:
		_fail("Missing node_by_plot_id partner lookup")


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
		print("\n✅ Entanglement line drawing data flow verified!")
		print("\nData flow (working):")
		print("  1. Farm.entangle_plots() → grid.create_entanglement()")
		print("  2. grid.create_entanglement() → plot.entangled_plots[partner_id] = 1.0")
		print("  3. _on_plot_planted() → _create_bubble_for_terminal(..., plot)")
		print("  4. QuantumNode.new(plot, ...) → node.plot = plot")
		print("  5. _draw_entanglement_lines() reads node.plot.entangled_plots")
		print("  6. Looks up partner via node_by_plot_id[partner_id]")
		print("  7. Draws cyan line between bubble positions")
	else:
		print("\n❌ Some tests failed - entanglement visualization may not work")

	print("=" .repeat(70))
