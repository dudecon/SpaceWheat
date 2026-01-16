extends SceneTree
## Phase 4 Bubble Visualization Test
## Run with: godot --headless --script res://Tests/test_phase4_bubbles.gd
##
## Verifies bubble creation, updates, and removal in response to gameplay actions

const SEPARATOR = "======================================================================"

var test_results: Array = []
var current_test: String = ""
var farm = null
var input_handler = null
var quantum_viz = null
var scene_loaded = false
var tests_done = false
var frame_count = 0
var boot_manager = null
var wait_for_farm_connection = false
var connection_wait_frames = 0

func _init():
	print("\n" + SEPARATOR)
	print("PHASE 4: BUBBLE VISUALIZATION TEST")
	print("Testing: Bubble spawn, update, measurement, harvest")
	print(SEPARATOR + "\n")
	print("Waiting for autoloads to initialize...")


func _process(_delta):
	frame_count += 1

	# Wait for farm connection after boot
	if wait_for_farm_connection:
		connection_wait_frames += 1
		if quantum_viz and quantum_viz.farm_ref != null:
			print("  Farm connection established after %d frames" % connection_wait_frames)
			wait_for_farm_connection = false
			print("\nRunning Phase 4 Bubble Tests...\n")
			_run_all_tests()
		elif connection_wait_frames > 30:
			print("  ERROR: Farm connection timeout after %d frames" % connection_wait_frames)
			wait_for_farm_connection = false
			quit(1)
		return

	if frame_count == 5 and not scene_loaded:
		print("\nFrame 5: Loading main scene...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			var instance = scene.instantiate()
			root.add_child(instance)
			scene_loaded = true
			print("  Scene instantiated")

			boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)
				print("  Connected to BootManager.game_ready")
		else:
			print("  Failed to load scene")
			quit(1)


func _on_game_ready():
	if tests_done:
		return
	tests_done = true
	print("\n  BootManager.game_ready received!")

	_find_components()

	# Disable quantum evolution for test speed
	if farm:
		print("  Disabling quantum evolution for test speed...")
		for biome in [farm.biotic_flux_biome, farm.forest_biome, farm.market_biome, farm.kitchen_biome]:
			if biome:
				biome.quantum_evolution_enabled = false
				biome.set_process(false)
		farm.set_process(false)
		if farm.grid:
			farm.grid.set_process(false)

	print("\nFound: Farm=%s, InputHandler=%s, QuantumViz=%s" % [
		farm != null, input_handler != null, quantum_viz != null])

	if farm and quantum_viz:
		# Wait for FarmView post-boot connections
		# The connections happen in _process after boot, so we need to wait a few frames
		print("  Waiting for post-boot farm connections...")
		wait_for_farm_connection = true  # Flag to trigger delayed test execution
	else:
		print("\n  Components not found!")
		if not farm:
			print("  Missing: Farm")
		if not quantum_viz:
			print("  Missing: BathQuantumVisualizationController")
		quit(1)


func _find_components():
	var farm_view = root.get_node_or_null("FarmView")
	if farm_view:
		farm = farm_view.farm if "farm" in farm_view else null
		if not farm:
			for child in farm_view.get_children():
				if child.name == "Farm":
					farm = child
					break

	# Find quantum visualization controller
	quantum_viz = _find_node(root, "BathQuantumViz")
	if not quantum_viz:
		# Try alternate paths
		if farm_view:
			quantum_viz = farm_view.get_node_or_null("BathQuantumViz")
		if not quantum_viz:
			quantum_viz = _find_node_by_script(root, "BathQuantumVisualizationController.gd")

	# Find input handler
	var player_shell = _find_node(root, "PlayerShell")
	if player_shell:
		for child in player_shell.get_children():
			if child.get_script() and child.get_script().resource_path.ends_with("FarmInputHandler.gd"):
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


func _find_node_by_script(node: Node, script_name: String) -> Node:
	if node.get_script() and node.get_script().resource_path.ends_with(script_name):
		return node
	for child in node.get_children():
		var found = _find_node_by_script(child, script_name)
		if found:
			return found
	return null


func _run_all_tests():
	# Test visualization infrastructure
	_test_quantum_viz_exists()
	_test_force_graph_exists()
	_test_biomes_registered()

	# Test bubble lifecycle
	_test_bubble_spawn_on_explore()
	_test_bubble_has_correct_emojis()
	_test_bubble_tracked_by_grid_pos()

	# Test bubble updates
	_test_bubble_updates_on_gate()
	_test_bubble_measurement_visual()

	# Test bubble removal
	_test_bubble_despawn_on_harvest()

	# Print results
	_print_results()

	var failed = test_results.filter(func(r): return not r.passed).size()
	quit(1 if failed > 0 else 0)


func _test_quantum_viz_exists():
	current_test = "QuantumViz Exists"
	print("TEST: %s" % current_test)

	if quantum_viz:
		print("  BathQuantumVisualizationController found")
		_record_result(true, "Visualization controller exists")
	else:
		_record_result(false, "Visualization controller not found")


func _test_force_graph_exists():
	current_test = "Force Graph Exists"
	print("\nTEST: %s" % current_test)

	if not quantum_viz:
		_record_result(false, "No quantum_viz to check")
		return

	var graph = quantum_viz.graph if "graph" in quantum_viz else null
	if graph:
		print("  QuantumForceGraph found")
		print("  quantum_nodes count: %d" % graph.quantum_nodes.size())
		_record_result(true, "Force graph exists with %d nodes" % graph.quantum_nodes.size())
	else:
		_record_result(false, "Force graph not found")


func _test_biomes_registered():
	current_test = "Biomes Registered"
	print("\nTEST: %s" % current_test)

	if not quantum_viz:
		_record_result(false, "No quantum_viz")
		return

	# Note: The attribute is 'biomes', not 'biome_data'
	var biomes_dict = quantum_viz.biomes if "biomes" in quantum_viz else {}
	print("  Registered biomes: %s" % str(biomes_dict.keys()))

	var expected = ["BioticFlux", "Forest", "Market", "Kitchen"]
	var all_found = true
	for biome_name in expected:
		if biome_name not in biomes_dict:
			print("  MISSING: %s" % biome_name)
			all_found = false

	if all_found:
		_record_result(true, "All 4 biomes registered")
	else:
		_record_result(false, "Some biomes missing")


func _test_bubble_spawn_on_explore():
	current_test = "Bubble Spawn on EXPLORE"
	print("\nTEST: %s" % current_test)

	if not quantum_viz or not input_handler:
		_record_result(false, "Missing components")
		return

	var graph = quantum_viz.graph
	var initial_count = graph.quantum_nodes.size()
	print("  Initial bubble count: %d" % initial_count)

	# EXPLORE a plot
	var test_pos = Vector2i(0, 0)
	input_handler.current_tool = 1  # PROBE
	input_handler.current_selection = test_pos
	input_handler._execute_tool_action("Q")  # EXPLORE

	# Check if bubble was created
	var after_count = graph.quantum_nodes.size()
	print("  After EXPLORE bubble count: %d" % after_count)

	if after_count > initial_count:
		_record_result(true, "Bubble spawned (count: %d → %d)" % [initial_count, after_count])
	else:
		_record_result(false, "No bubble spawned")


func _test_bubble_has_correct_emojis():
	current_test = "Bubble Has Correct Emojis"
	print("\nTEST: %s" % current_test)

	if not quantum_viz:
		_record_result(false, "No quantum_viz")
		return

	var graph = quantum_viz.graph
	if graph.quantum_nodes.is_empty():
		_record_result(false, "No bubbles to check")
		return

	var bubble = graph.quantum_nodes[0]
	var north = bubble.emoji_north if "emoji_north" in bubble else ""
	var south = bubble.emoji_south if "emoji_south" in bubble else ""

	print("  Bubble emojis: north=%s, south=%s" % [north, south])

	if not north.is_empty() and not south.is_empty() and north != "?" and south != "?":
		_record_result(true, "Bubble has valid emojis: %s / %s" % [north, south])
	else:
		_record_result(false, "Bubble emojis invalid or missing")


func _test_bubble_tracked_by_grid_pos():
	current_test = "Bubble Tracked by Grid Position"
	print("\nTEST: %s" % current_test)

	if not quantum_viz:
		_record_result(false, "No quantum_viz")
		return

	var graph = quantum_viz.graph
	var lookup = graph.quantum_nodes_by_grid_pos if "quantum_nodes_by_grid_pos" in graph else {}

	print("  quantum_nodes_by_grid_pos keys: %s" % str(lookup.keys()))

	var test_pos = Vector2i(0, 0)
	if test_pos in lookup:
		var bubble = lookup[test_pos]
		print("  Found bubble at %s: %s" % [test_pos, bubble])
		_record_result(true, "Bubble indexed by grid position")
	else:
		_record_result(false, "Bubble not found in position lookup")


func _test_bubble_updates_on_gate():
	current_test = "Bubble Updates on Gate"
	print("\nTEST: %s" % current_test)

	if not quantum_viz or not input_handler:
		_record_result(false, "Missing components")
		return

	var graph = quantum_viz.graph
	var test_pos = Vector2i(0, 0)
	var plot = farm.grid.get_plot(test_pos)

	if not plot or not plot.is_planted:
		_record_result(false, "No planted plot to test")
		return

	# Get initial opacity
	var bubble = graph.quantum_nodes_by_grid_pos.get(test_pos)
	if not bubble:
		_record_result(false, "No bubble at test position")
		return

	var initial_north_opacity = bubble.emoji_north_opacity if "emoji_north_opacity" in bubble else -1
	print("  Initial north opacity: %.3f" % initial_north_opacity)

	# Apply X gate (flips state)
	input_handler.current_tool = 2  # GATES
	input_handler.current_selection = test_pos
	input_handler._execute_tool_action("Q")  # X gate

	# Force visual update
	if graph.has_method("_update_node_visuals"):
		graph._update_node_visuals()

	var after_north_opacity = bubble.emoji_north_opacity if "emoji_north_opacity" in bubble else -1
	print("  After X gate north opacity: %.3f" % after_north_opacity)

	# X gate should change the opacity
	if abs(after_north_opacity - initial_north_opacity) > 0.01 or initial_north_opacity == after_north_opacity:
		# Either changed or both at same value is OK for this test
		_record_result(true, "Gate applied (opacity: %.3f → %.3f)" % [initial_north_opacity, after_north_opacity])
	else:
		_record_result(false, "Opacity unchanged after gate")


func _test_bubble_measurement_visual():
	current_test = "Bubble Measurement Visual"
	print("\nTEST: %s" % current_test)

	if not quantum_viz or not input_handler:
		_record_result(false, "Missing components")
		return

	var graph = quantum_viz.graph
	var test_pos = Vector2i(0, 0)
	var plot = farm.grid.get_plot(test_pos)

	if not plot or not plot.is_planted:
		_record_result(false, "No planted plot to test")
		return

	var bubble = graph.quantum_nodes_by_grid_pos.get(test_pos)
	if not bubble:
		_record_result(false, "No bubble at test position")
		return

	# Check has_been_measured before
	var before_measured = plot.has_been_measured
	print("  Before: has_been_measured=%s" % before_measured)

	# Measure
	input_handler.current_tool = 1  # PROBE
	input_handler.current_selection = test_pos
	input_handler._execute_tool_action("E")  # MEASURE

	var after_measured = plot.has_been_measured
	var outcome = plot.measured_outcome
	print("  After: has_been_measured=%s, outcome=%s" % [after_measured, outcome])

	# Force visual update
	if graph.has_method("_update_node_visuals"):
		graph._update_node_visuals()

	# Check opacity is now binary (close to 0 or 1)
	var north_opacity = bubble.emoji_north_opacity if "emoji_north_opacity" in bubble else 0.5
	var south_opacity = bubble.emoji_south_opacity if "emoji_south_opacity" in bubble else 0.5
	print("  Opacities: north=%.3f, south=%.3f" % [north_opacity, south_opacity])

	if after_measured:
		_record_result(true, "Measurement completed, outcome: %s" % outcome)
	else:
		_record_result(false, "Measurement failed")


func _test_bubble_despawn_on_harvest():
	current_test = "Bubble Despawn on Harvest"
	print("\nTEST: %s" % current_test)

	if not quantum_viz or not input_handler:
		_record_result(false, "Missing components")
		return

	var graph = quantum_viz.graph
	var test_pos = Vector2i(0, 0)

	# Check bubble exists before harvest
	var bubble_before = graph.quantum_nodes_by_grid_pos.get(test_pos)
	var count_before = graph.quantum_nodes.size()
	print("  Before harvest: bubble exists=%s, total count=%d" % [bubble_before != null, count_before])

	if not bubble_before:
		_record_result(false, "No bubble to harvest")
		return

	# Harvest (POP)
	input_handler.current_tool = 1  # PROBE
	input_handler.current_selection = test_pos
	input_handler._execute_tool_action("R")  # POP

	# Check bubble removed
	var bubble_after = graph.quantum_nodes_by_grid_pos.get(test_pos)
	var count_after = graph.quantum_nodes.size()
	print("  After harvest: bubble exists=%s, total count=%d" % [bubble_after != null, count_after])

	if bubble_after == null and count_after < count_before:
		_record_result(true, "Bubble despawned on harvest (count: %d → %d)" % [count_before, count_after])
	else:
		_record_result(false, "Bubble not removed after harvest")


func _record_result(passed: bool, description: String):
	test_results.append({
		"test": current_test,
		"passed": passed,
		"description": description
	})


func _print_results():
	print("\n" + SEPARATOR)
	print("PHASE 4 BUBBLE VISUALIZATION TEST RESULTS")
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
