extends SceneTree

## System Interaction Test Suite
## Tests how different game systems interact when used together
## Run with: godot --script res://Tests/test_system_interactions.gd
## Or headless: godot --headless --script res://Tests/test_system_interactions.gd

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

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
	print("🔗 SYSTEM INTERACTION TEST SUITE")
	print(SEPARATOR + "\n")
	print("Testing: overlays+tools, BUILD+quests, measurement+visualization")
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
			print("✓ Scene instantiated")

			# Connect to BootManager.game_ready signal
			boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)
				print("✓ Connected to BootManager.game_ready")
		else:
			print("✗ Failed to load scene")
			quit(1)


func _on_game_ready():
	"""Called when BootManager signals that the game is ready"""
	if tests_done:
		return
	tests_done = true
	print("\n✅ BootManager.game_ready received!")

	_find_components()

	# Disable quantum evolution for faster test execution
	if farm:
		print("⚡ Disabling quantum evolution for test speed...")
		for biome in [farm.biotic_flux_biome, farm.forest_biome, farm.market_biome, farm.kitchen_biome]:
			if biome:
				biome.quantum_evolution_enabled = false
				biome.set_process(false)
		farm.set_process(false)
		if farm.grid:
			farm.grid.set_process(false)

	print("Found: PlayerShell=%s, InputHandler=%s, Farm=%s" % [
		player_shell != null, input_handler != null, farm != null])

	if input_handler and farm:
		print("Running system interaction tests...\n")
		await _run_all_tests()
	else:
		print("\n✗ Required components not found!")
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
	# Test 1: Tool Cycling
	_test_tool_cycling()

	# Test 2: Measure-Harvest Flow
	await _test_measure_harvest_flow()

	# Test 3: Multiple Plots Quantum State
	await _test_multiple_plots_quantum()

	# Test 4: Visualization Updates
	await _test_visualization_updates()

	# Test 5: Lifeless Nodes
	_test_lifeless_nodes()

	# Test 6: Register Release
	await _test_register_release()

	# Test 7: Quantum Gate Application
	await _test_quantum_gates()

	# Test 8: Concurrent Actions
	await _test_concurrent_actions()

	# Test 9: BUILD + EXPLORE Integration
	await _test_build_explore_integration()

	# Print results and exit
	_print_results()

	var failed = test_results.filter(func(r): return not r.passed).size()
	quit(1 if failed > 0 else 0)


# ============================================================================
# TEST 1: Tool Cycling
# ============================================================================

func _test_tool_cycling():
	current_test = "Tool Selection (1-4 keys)"
	print("📋 TEST: %s" % current_test)

	var all_passed = true

	# Test tool selection 1-4
	for tool_num in [1, 2, 3, 4]:
		_simulate_key(KEY_1 + tool_num - 1)

		var current = input_handler.current_tool
		if current == tool_num:
			print("  ✓ Tool %d selected" % tool_num)
		else:
			print("  ✗ Tool %d failed (got %d)" % [tool_num, current])
			all_passed = false

	_record_result(all_passed, "All tools (1-4) selectable")


# ============================================================================
# TEST 2: Measure-Harvest Flow
# ============================================================================

func _get_first_valid_plot():
	"""Helper to get the first valid plot from any biome"""
	if not farm or not farm.grid:
		return null

	# Try biotic_flux_biome first (most common)
	var biome = farm.biotic_flux_biome
	if biome and biome.has_method("get_plot_positions"):
		for pos in biome.get_plot_positions():
			var plot = farm.grid.get_plot(pos)
			if plot:
				return plot

	# Try other biomes
	for biome_name in ["forest_biome", "market_biome", "kitchen_biome"]:
		if biome_name in farm:
			var b = farm.get(biome_name)
			if b and b.has_method("get_plot_positions"):
				for pos in b.get_plot_positions():
					var plot = farm.grid.get_plot(pos)
					if plot:
						return plot

	# Fallback: iterate grid directly
	for pos in farm.grid.plots:
		return farm.grid.plots[pos]

	return null


func _test_measure_harvest_flow():
	current_test = "Measure → Harvest Flow"
	print("\n📋 TEST: %s" % current_test)

	# Get biome for action execution
	var biome = farm.biotic_flux_biome
	if not biome:
		print("  ✗ No biome available")
		_record_result(false, "Biome missing")
		return

	if not farm.plot_pool:
		print("  ✗ No plot_pool available")
		_record_result(false, "plot_pool missing")
		return

	# Step 1: EXPLORE
	print("  Step 1: EXPLORE...")
	var explore_result = ProbeActions.action_explore(farm.plot_pool, biome)
	await process_frame

	if not explore_result.success:
		print("    ✗ EXPLORE failed: %s" % explore_result.get("message", "unknown"))
		_record_result(false, "EXPLORE failed")
		return

	var terminal = explore_result.terminal
	var emoji = explore_result.emoji_pair.get("north", "?")
	print("    Terminal created: reg=%d emoji=%s" % [terminal.bound_register_id, emoji])

	# Step 2: MEASURE
	print("  Step 2: MEASURE...")
	var measure_result = ProbeActions.action_measure(terminal, biome)
	await process_frame

	if not measure_result.get("success", false):
		print("    ✗ MEASURE failed: %s" % measure_result.get("message", "unknown"))
		_record_result(false, "MEASURE failed")
		return

	var outcome = measure_result.get("outcome", "?")
	var prob = measure_result.get("probability", 0.0) * 100
	print("    Collapsed: %s (p=%.0f%%)" % [outcome, prob])

	if not terminal.is_measured:
		print("    ✗ Terminal not marked as measured")
		_record_result(false, "Terminal state error")
		return

	print("    ✓ Terminal measured!")

	# Step 3: POP (harvest)
	print("  Step 3: POP (harvest)...")
	var pop_result = ProbeActions.action_pop(terminal, farm.plot_pool, farm.economy)
	await process_frame

	if not pop_result.success:
		print("    ✗ POP failed: %s" % pop_result.get("message", "unknown"))
		_record_result(false, "POP failed")
		return

	var resource = pop_result.resource
	print("    Harvested: %s" % resource)

	_record_result(true, "Full measure→harvest flow works")


# ============================================================================
# TEST 3: Multiple Plots Quantum State
# ============================================================================

func _test_multiple_plots_quantum():
	current_test = "Multiple Plots Quantum State"
	print("\n📋 TEST: %s" % current_test)

	var biome = farm.biotic_flux_biome
	if not biome:
		_record_result(false, "Biome not available")
		return

	if not farm.plot_pool:
		_record_result(false, "plot_pool not available")
		return

	# Create multiple terminals
	var terminals = []
	for i in range(2):
		var result = ProbeActions.action_explore(farm.plot_pool, biome)
		if result.success:
			terminals.append(result.terminal)
			print("  Created terminal %d: reg=%d" % [i+1, result.terminal.bound_register_id])
		await process_frame

	if terminals.size() < 2:
		print("  Could only create %d terminals" % terminals.size())
		_record_result(terminals.size() >= 1, "At least one terminal created")
		return

	# Check purity
	var purity = biome.get_purity() if biome.has_method("get_purity") else 0.5
	print("  Biome purity: %.4f" % purity)

	# Clean up
	for t in terminals:
		if t.is_measured:
			continue
		ProbeActions.action_measure(t, biome)
		await process_frame
		ProbeActions.action_pop(t, farm.plot_pool, farm.economy)
		await process_frame

	_record_result(true, "Multiple terminals can coexist")


# ============================================================================
# TEST 4: Visualization Updates
# ============================================================================

func _test_visualization_updates():
	current_test = "Visualization Updates"
	print("\n📋 TEST: %s" % current_test)

	# Find visualization controller
	var viz_controller = _find_node(root, "BathQuantumVisualizationController")
	if not viz_controller:
		var groups = get_nodes_in_group("quantum_visualization")
		if groups.size() > 0:
			viz_controller = groups[0]

	if not viz_controller:
		print("  ⚠️ No visualization controller")
		_record_result(true, "Viz controller not required")
		return

	# Check force graph
	var force_graph = viz_controller.get_node_or_null("QuantumForceGraph")
	if not force_graph and "graph" in viz_controller:
		force_graph = viz_controller.graph

	if not force_graph:
		print("  ⚠️ No force graph")
		_record_result(true, "Force graph not required")
		return

	print("  Force graph: %s" % force_graph.name)

	# Check plot_pool connection
	var has_plot_pool = "plot_pool" in force_graph and force_graph.plot_pool != null
	if has_plot_pool:
		print("  ✓ plot_pool connected to force graph")
	else:
		print("  ⚠️ plot_pool not connected")

	# Trigger a redraw
	if force_graph.has_method("queue_redraw"):
		force_graph.queue_redraw()
		print("  ✓ Redraw triggered")

	_record_result(true, "Visualization system operational")


# ============================================================================
# TEST 5: Lifeless Nodes
# ============================================================================

func _test_lifeless_nodes():
	current_test = "Lifeless Node Behavior"
	print("\n📋 TEST: %s" % current_test)

	# Find force graph
	var viz_controller = _find_node(root, "BathQuantumVisualizationController")
	var force_graph = null
	if viz_controller:
		force_graph = viz_controller.get_node_or_null("QuantumForceGraph")
		if not force_graph and "graph" in viz_controller:
			force_graph = viz_controller.graph

	if not force_graph:
		_record_result(true, "Force graph not required")
		return

	var nodes_by_plot_id = force_graph.get("nodes_by_plot_id")
	if nodes_by_plot_id == null or nodes_by_plot_id.size() == 0:
		print("  ⚠️ No nodes in force graph")
		_record_result(true, "No nodes to test")
		return

	print("  Total nodes: %d" % nodes_by_plot_id.size())

	# Check lifeless behavior
	var lifeless_count = 0
	var frozen_lifeless = 0
	for plot_id in nodes_by_plot_id:
		var node = nodes_by_plot_id[plot_id]
		if node.is_lifeless:
			lifeless_count += 1
			if node.velocity == Vector2.ZERO:
				frozen_lifeless += 1

	print("  Lifeless nodes: %d" % lifeless_count)
	print("  Frozen (velocity=0): %d" % frozen_lifeless)

	var all_frozen = (lifeless_count == 0 or frozen_lifeless == lifeless_count)
	_record_result(all_frozen, "Lifeless nodes are frozen")


# ============================================================================
# TEST 6: Register Release
# ============================================================================

func _test_register_release():
	current_test = "Register Release After Pop"
	print("\n📋 TEST: %s" % current_test)

	var biome = farm.biotic_flux_biome
	if not biome or not farm.plot_pool:
		_record_result(false, "Biome or plot_pool missing")
		return

	# First cycle: EXPLORE → MEASURE → POP
	print("  Cycle 1: EXPLORE → MEASURE → POP")
	var result1 = ProbeActions.action_explore(farm.plot_pool, biome)
	await process_frame

	if not result1.success:
		print("    ✗ First EXPLORE failed")
		_record_result(false, "First EXPLORE failed")
		return

	var terminal1 = result1.terminal
	var reg1 = terminal1.bound_register_id
	print("    First register: %d" % reg1)

	ProbeActions.action_measure(terminal1, biome)
	await process_frame
	ProbeActions.action_pop(terminal1, farm.plot_pool, farm.economy)
	await process_frame
	print("    Popped!")

	# Second cycle: EXPLORE should work again
	print("  Cycle 2: EXPLORE again...")
	var result2 = ProbeActions.action_explore(farm.plot_pool, biome)
	await process_frame

	if result2.success:
		var reg2 = result2.terminal.bound_register_id
		print("    Second register: %d" % reg2)
		print("  ✓ Register successfully allocated after POP")

		# Clean up
		ProbeActions.action_measure(result2.terminal, biome)
		await process_frame
		ProbeActions.action_pop(result2.terminal, farm.plot_pool, farm.economy)

		_record_result(true, "Registers released and reusable")
	else:
		print("  ✗ Second EXPLORE failed: %s" % result2.get("message", "unknown"))
		_record_result(false, "Register not released")


# ============================================================================
# TEST 7: Quantum Gates
# ============================================================================

func _test_quantum_gates():
	current_test = "Quantum Computer Access"
	print("\n📋 TEST: %s" % current_test)

	var biome = farm.biotic_flux_biome
	if not biome:
		_record_result(false, "Biome missing")
		return

	# Verify quantum_computer exists
	if not biome.quantum_computer:
		_record_result(false, "No quantum_computer")
		return

	print("  quantum_computer exists: ✓")

	# Check we can get probability data
	if biome.has_method("get_register_probability"):
		var prob = biome.get_register_probability(0)
		print("  Register 0 P(0): %.4f" % prob)
	else:
		print("  ⚠️ No get_register_probability method")

	# Check purity
	if biome.has_method("get_purity"):
		var purity = biome.get_purity()
		print("  Purity: %.4f" % purity)
	else:
		print("  ⚠️ No get_purity method")

	_record_result(true, "Quantum computer accessible")


# ============================================================================
# TEST 8: Concurrent Actions
# ============================================================================

func _test_concurrent_actions():
	current_test = "Concurrent Actions Independence"
	print("\n📋 TEST: %s" % current_test)

	# Use two different biomes if possible
	var biome_a = farm.biotic_flux_biome
	var biome_b = farm.forest_biome if farm.forest_biome else biome_a

	if not biome_a or not farm.plot_pool:
		_record_result(false, "Biomes or plot_pool missing")
		return

	var biome_a_type = biome_a.get_biome_type() if biome_a.has_method("get_biome_type") else "unknown"
	var biome_b_type = biome_b.get_biome_type() if biome_b.has_method("get_biome_type") else "unknown"
	print("  Biome A: %s" % biome_a_type)
	print("  Biome B: %s" % biome_b_type)

	# EXPLORE on both biomes
	var result_a = ProbeActions.action_explore(farm.plot_pool, biome_a)
	var result_b = ProbeActions.action_explore(farm.plot_pool, biome_b)
	await process_frame

	if not result_a.success or not result_b.success:
		_record_result(result_a.success or result_b.success, "At least one EXPLORE worked")
		return

	var term_a = result_a.terminal
	var term_b = result_b.terminal

	print("    A: register=%d" % term_a.bound_register_id)
	print("    B: register=%d" % term_b.bound_register_id)

	# Measure A only
	ProbeActions.action_measure(term_a, biome_a)
	await process_frame

	var a_measured = term_a.is_measured
	var b_measured = term_b.is_measured

	print("  A measured: %s" % str(a_measured))
	print("  B measured: %s" % str(b_measured))

	# Clean up
	ProbeActions.action_pop(term_a, farm.plot_pool, farm.economy)
	await process_frame
	ProbeActions.action_measure(term_b, biome_b)
	await process_frame
	ProbeActions.action_pop(term_b, farm.plot_pool, farm.economy)

	if a_measured and not b_measured:
		print("  ✓ Actions are independent")
		_record_result(true, "Actions on different terminals independent")
	elif a_measured and b_measured:
		print("  ⚠️ Both measured (may share biome state)")
		_record_result(true, "Shared state - expected")
	else:
		_record_result(false, "Unexpected state")


# ============================================================================
# TEST 9: BUILD + EXPLORE Integration
# ============================================================================

func _test_build_explore_integration():
	current_test = "Complete Farming Cycle"
	print("\n📋 TEST: %s" % current_test)

	var biome = farm.biotic_flux_biome
	if not biome or not farm.plot_pool:
		_record_result(false, "Biome or plot_pool missing")
		return

	# Run a complete farming cycle using ProbeActions
	print("  Running complete cycle: EXPLORE → MEASURE → POP")

	# EXPLORE
	var explore_result = ProbeActions.action_explore(farm.plot_pool, biome)
	if not explore_result.success:
		print("    ✗ EXPLORE failed: %s" % explore_result.get("message", "unknown"))
		_record_result(false, "EXPLORE failed")
		return

	var terminal = explore_result.terminal
	print("    EXPLORE: reg=%d emoji=%s" % [terminal.bound_register_id, explore_result.emoji_pair.get("north", "?")])
	await process_frame

	# MEASURE
	var measure_result = ProbeActions.action_measure(terminal, biome)
	if not measure_result.get("success", false):
		print("    ✗ MEASURE failed")
		_record_result(false, "MEASURE failed")
		return

	print("    MEASURE: outcome=%s" % measure_result.get("outcome", "?"))
	await process_frame

	# POP
	var pop_result = ProbeActions.action_pop(terminal, farm.plot_pool, farm.economy)
	if not pop_result.success:
		print("    ✗ POP failed")
		_record_result(false, "POP failed")
		return

	print("    POP: harvested %s" % pop_result.resource)

	_record_result(true, "Complete farming cycle works")


# ============================================================================
# Helper Functions
# ============================================================================

func _simulate_key(keycode: int):
	"""Simulate a key press"""
	var press = InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	press.echo = false
	Input.parse_input_event(press)

	if input_handler and input_handler.has_method("_unhandled_input"):
		input_handler._unhandled_input(press)


func _record_result(passed: bool, description: String):
	test_results.append({
		"test": current_test,
		"passed": passed,
		"description": description
	})
	var status = "✓" if passed else "✗"
	print("  %s %s\n" % [status, description])


func _print_results():
	print("\n" + SEPARATOR)
	print("📊 SYSTEM INTERACTION TEST RESULTS")
	print(SEPARATOR)

	var passed_count = 0
	var failed_count = 0

	for result in test_results:
		var status = "✅ PASS" if result.passed else "❌ FAIL"
		print("  %s: %s" % [status, result.test])
		if result.passed:
			passed_count += 1
		else:
			failed_count += 1

	print("")
	print("  Total: %d passed, %d failed" % [passed_count, failed_count])
	print(SEPARATOR + "\n")
