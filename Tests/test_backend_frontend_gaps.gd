extends SceneTree

## Backend-to-Frontend Gap Analysis Test
## Tests signal connections between simulation and UI layers
## Run with: godot --headless --script Tests/test_backend_frontend_gaps.gd

var farm = null
var results: Array = []
var tests_passed: int = 0
var tests_failed: int = 0

func _init():
	print("\n" + "=" .repeat(70))
	print("BACKEND → FRONTEND SIGNAL GAP ANALYSIS")
	print("Testing if backend signals are properly connected to UI handlers")
	print("=" .repeat(70) + "\n")


func _process(_delta: float) -> bool:
	# Wait for engine to initialize
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

	# Create minimal Farm for signal testing
	var Farm = load("res://Core/Farm.gd")
	farm = Farm.new()

	# Check what signals Farm has
	print("\n--- PHASE 1: Signal Definition Check ---")
	_test_signal_exists("action_rejected")
	_test_signal_exists("plot_planted")
	_test_signal_exists("plot_harvested")
	_test_signal_exists("plot_measured")
	_test_signal_exists("plots_entangled")
	_test_signal_exists("resource_changed")  # economy signal

	# Check signal connection requirements
	print("\n--- PHASE 2: Signal Connection Gap Analysis ---")
	_analyze_signal_connections()

	print("\n--- PHASE 3: InspectorOverlay Auto-Refresh Check ---")
	_analyze_inspector_overlay()


func _test_signal_exists(signal_name: String):
	if farm.has_signal(signal_name):
		_pass("Farm.%s signal EXISTS" % signal_name)
	else:
		_fail("Farm.%s signal MISSING" % signal_name)


func _analyze_signal_connections():
	"""Analyze which signals have UI subscribers vs which don't"""

	print("\nAnalyzing signal → UI handler connections...")

	# Signals that SHOULD be connected to visualization/UI
	var critical_signals = {
		"plots_entangled": {
			"expected_subscriber": "BathQuantumVisualizationController or QuantumForceGraph",
			"purpose": "Show visual lines between entangled plots"
		},
		"plot_measured": {
			"expected_subscriber": "PlotGridDisplay._on_farm_plot_measured",
			"purpose": "Update plot tile visual after measurement"
		},
		"plot_planted": {
			"expected_subscriber": "BathQuantumVisualizationController._on_plot_planted",
			"purpose": "Spawn quantum bubble visualization"
		},
		"plot_harvested": {
			"expected_subscriber": "BathQuantumVisualizationController._on_plot_harvested",
			"purpose": "Despawn quantum bubble"
		},
		"action_rejected": {
			"expected_subscriber": "PlotGridDisplay.show_rejection_effect",
			"purpose": "Show red pulse animation when action fails"
		}
	}

	# Check by reading source files
	var viz_controller = FileAccess.open("res://Core/Visualization/BathQuantumVisualizationController.gd", FileAccess.READ)
	var viz_content = viz_controller.get_as_text() if viz_controller else ""

	var plot_grid = FileAccess.open("res://UI/PlotGridDisplay.gd", FileAccess.READ)
	var grid_content = plot_grid.get_as_text() if plot_grid else ""

	var farm_ui = FileAccess.open("res://UI/FarmUI.gd", FileAccess.READ)
	var ui_content = farm_ui.get_as_text() if farm_ui else ""

	# Test each signal connection
	print("")

	# 1. plots_entangled - NOTE: Entanglement visualization uses POLLING, not signals
	# The fix was to pass plot reference to bubbles, enabling _draw_entanglement_lines() to work
	# Check for the fixed pattern: passing plot to _create_bubble_for_terminal
	if "farm_ref.grid.get_plot(position)" in viz_content and "_create_bubble_for_terminal" in viz_content:
		_pass("plots_entangled: Entanglement viz works via plot reference (polling pattern)")
	elif "plots_entangled.connect" in viz_content:
		_pass("plots_entangled: BathQuantumVisualizationController subscribes")
	else:
		_fail("plots_entangled: Entanglement visualization broken - bubbles missing plot reference")
		results.append("  └─ Gap: BathQuantumVisualizationController bubbles don't have plot references")

	# 2. plot_measured
	if "plot_measured.connect" in grid_content:
		_pass("plot_measured: PlotGridDisplay subscribes")
	else:
		_fail("plot_measured: PlotGridDisplay NOT subscribed")

	# 3. plot_planted
	if "plot_planted.connect" in viz_content:
		_pass("plot_planted: BathQuantumVisualizationController subscribes")
	else:
		_fail("plot_planted: BathQuantumVisualizationController NOT subscribed")

	# 4. plot_harvested
	if "plot_harvested.connect" in viz_content:
		_pass("plot_harvested: BathQuantumVisualizationController subscribes")
	else:
		_fail("plot_harvested: BathQuantumVisualizationController NOT subscribed")

	# 5. action_rejected
	if "action_rejected.connect" in ui_content or "action_rejected" in ui_content:
		_pass("action_rejected: FarmUI connects to PlotGridDisplay")
	else:
		_fail("action_rejected: NOT connected to PlotGridDisplay")


func _analyze_inspector_overlay():
	"""Check if InspectorOverlay auto-refreshes on quantum state changes"""

	var inspector = FileAccess.open("res://UI/Overlays/InspectorOverlay.gd", FileAccess.READ)
	var content = inspector.get_as_text() if inspector else ""

	print("\nInspectorOverlay analysis:")

	# Check for auto-refresh via EITHER signal subscription OR _process timer
	var has_auto_refresh = false

	# Option 1: Signal subscription patterns
	var subscription_patterns = [
		"state_changed.connect",
		"quantum_state_updated.connect",
		"density_matrix_changed.connect",
		"biome_updated.connect",
		"register_changed.connect"
	]

	for pattern in subscription_patterns:
		if pattern in content:
			has_auto_refresh = true
			_pass("InspectorOverlay subscribes to: %s" % pattern.replace(".connect", ""))
			break

	# Option 2: Periodic refresh via _process (BiomeInspectorOverlay pattern)
	if not has_auto_refresh:
		# Check for _process with update_timer and _refresh_data
		var has_process = "func _process(delta" in content
		var has_timer = "update_timer" in content
		var has_refresh_in_process = "_refresh_data()" in content and "update_timer >= update_interval" in content

		if has_process and has_timer and has_refresh_in_process:
			has_auto_refresh = true
			_pass("InspectorOverlay has periodic _process() refresh (timer pattern)")

	if not has_auto_refresh:
		_fail("InspectorOverlay has NO auto-refresh - must close/reopen to see changes")
		results.append("  └─ Gap: InspectorOverlay only refreshes in activate(), not on state change")

	# Check if _refresh_data is called anywhere besides activate
	var refresh_call_count = content.count("_refresh_data()")
	print("   _refresh_data() calls found: %d" % refresh_call_count)


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

	if results.size() > 0:
		print("\n📋 IDENTIFIED GAPS (Backend → Frontend):")
		for r in results:
			print(r)

	print("\n🔧 RECOMMENDED FIXES:")

	if tests_failed > 0:
		print("""
1. plots_entangled Signal Gap:
   - BathQuantumVisualizationController.connect_to_farm() should connect to farm.plots_entangled
   - Add handler to draw entanglement lines between bubbles
   - QuantumForceGraph needs entanglement edge rendering

2. InspectorOverlay Auto-Refresh Gap:
   - Subscribe to biome/quantum_computer state change signals
   - Call _refresh_data() when density matrix changes
   - OR add a periodic refresh timer (less elegant)

3. General Pattern:
   - Every Farm signal should have at least one UI subscriber
   - Use signal spy pattern in tests to verify connections
""")

	print("=" .repeat(70))
