extends Node

## Comprehensive Tool Evaluation Test
## Tests all 12 tool actions to identify what works and what needs fixing

var farm: Node
var input_handler: Node
var plot_grid_display: Node
var test_results: Dictionary = {}
var test_log: Array[String] = []

func _ready():
	var sep = ""
	for i in range(80):
		sep += "="
	print("\n" + sep)
	print("COMPREHENSIVE TOOL EVALUATION TEST")
	print(sep + "\n")

	# Wait for UI to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Find components
	var farm_view = get_tree().root.find_child("FarmView", true, false)
	if not farm_view:
		_log("ERROR: FarmView not found")
		return

	var player_shell = farm_view.find_child("PlayerShell", true, false)
	if not player_shell:
		_log("ERROR: PlayerShell not found")
		return

	var farm_ui = farm_view.find_child("FarmUI", true, false)
	if not farm_ui:
		_log("ERROR: FarmUI not found")
		return

	farm = farm_view.get_farm()
	if not farm:
		_log("ERROR: Farm not found")
		return

	input_handler = farm_ui.get("input_handler")
	if not input_handler:
		_log("ERROR: FarmInputHandler not found")
		return

	plot_grid_display = farm_ui.get("plot_grid_display")
	if not plot_grid_display:
		_log("ERROR: PlotGridDisplay not found")
		return

	_log("✅ All components found and initialized")

	# Give the farm time to fully initialize
	await get_tree().process_frame

	# Run tests
	_test_tool_1_grower()
	await get_tree().process_frame

	_test_tool_2_quantum()
	await get_tree().process_frame

	_test_tool_3_industry()
	await get_tree().process_frame

	_test_tool_4_energy()
	await get_tree().process_frame

	_test_tool_5_6_placeholders()

	# Print summary
	_print_summary()

	get_tree().quit()


func _test_tool_1_grower():
	_log("\n" + "-"*80)
	_log("TOOL 1: GROWER (🌱)")
	_log("-"*80)

	# Select first plot
	input_handler.current_selection = Vector2i(0, 0)
	plot_grid_display._update_tile_display()

	# Test Q: plant_batch
	_log("\n[Q] plant_batch")
	var wheat_before = farm.economy.wheat_inventory
	input_handler._on_action_key_pressed("Q")
	await get_tree().process_frame
	var wheat_after = farm.economy.wheat_inventory
	var plant_result = "PASS" if farm.grid.get_plot(Vector2i(0, 0)).is_planted else "FAIL"
	_log("  Result: %s (wheat: %d → %d)" % [plant_result, wheat_before, wheat_after])
	test_results["Tool1_plant_batch"] = plant_result

	# Select 2 plots for entangle
	input_handler.current_selection = Vector2i(0, 0)
	plot_grid_display._update_tile_display()
	plot_grid_display._toggle_plot_selection(Vector2i(0, 0))
	plot_grid_display._toggle_plot_selection(Vector2i(1, 0))

	# Test E: entangle_batch
	_log("\n[E] entangle_batch")
	input_handler._on_action_key_pressed("E")
	await get_tree().process_frame
	var plot_0 = farm.grid.get_plot(Vector2i(0, 0))
	var entangle_result = "PASS" if plot_0.entangled_plots.size() > 0 else "FAIL"
	_log("  Result: %s (plot (0,0) entanglements: %d)" % [entangle_result, plot_0.entangled_plots.size()])
	test_results["Tool1_entangle_batch"] = entangle_result

	# Test R: measure_and_harvest
	_log("\n[R] measure_and_harvest")
	var yield_before = farm.grid.get_plot(Vector2i(0, 0)).yield_amount
	input_handler._on_action_key_pressed("R")
	await get_tree().process_frame
	var yield_after = farm.grid.get_plot(Vector2i(0, 0)).yield_amount
	var harvest_result = "PASS" if yield_after > yield_before else "FAIL"
	_log("  Result: %s (yield: %d → %d)" % [harvest_result, yield_before, yield_after])
	test_results["Tool1_measure_and_harvest"] = harvest_result


func _test_tool_2_quantum():
	_log("\n" + "-"*80)
	_log("TOOL 2: QUANTUM (⚛️)")
	_log("-"*80)

	# Plant 3 plots for quantum operations
	for i in range(3):
		input_handler.current_selection = Vector2i(i, 1)
		plot_grid_display._toggle_plot_selection(Vector2i(i, 1))
		farm.build(Vector2i(i, 1), "wheat")

	# Switch to tool 2
	input_handler.current_tool = 2

	# Test Q: cluster
	_log("\n[Q] cluster")
	input_handler._on_action_key_pressed("Q")
	await get_tree().process_frame
	var cluster_count = 0
	for i in range(3):
		var plot = farm.grid.get_plot(Vector2i(i, 1))
		if plot.entangled_plots.size() > 0:
			cluster_count += 1
	var cluster_result = "PASS" if cluster_count > 0 else "FAIL"
	_log("  Result: %s (plots with entanglement: %d/3)" % [cluster_result, cluster_count])
	test_results["Tool2_cluster"] = cluster_result

	# Test E: measure_plot
	_log("\n[E] measure_plot")
	input_handler.current_selection = Vector2i(0, 1)
	plot_grid_display._update_tile_display()
	var plot_before = farm.grid.get_plot(Vector2i(0, 1))
	var entangled_before = plot_before.entangled_plots.size()
	input_handler._on_action_key_pressed("E")
	await get_tree().process_frame
	var plot_after = farm.grid.get_plot(Vector2i(0, 1))
	var entangled_after = plot_after.entangled_plots.size()
	var measure_result = "PASS" if entangled_after < entangled_before else "FAIL"
	_log("  Result: %s (entanglements: %d → %d)" % [measure_result, entangled_before, entangled_after])
	test_results["Tool2_measure_plot"] = measure_result

	# Test R: break_entanglement
	_log("\n[R] break_entanglement")
	input_handler._on_action_key_pressed("R")
	await get_tree().process_frame
	var final_entangle = farm.grid.get_plot(Vector2i(0, 1)).entangled_plots.size()
	var break_result = "PASS" if final_entangle == 0 else "FAIL"
	_log("  Result: %s (entanglements: %d)" % [break_result, final_entangle])
	test_results["Tool2_break_entanglement"] = break_result


func _test_tool_3_industry():
	_log("\n" + "-"*80)
	_log("TOOL 3: INDUSTRY (🏭)")
	_log("-"*80)

	# Switch to tool 3
	input_handler.current_tool = 3

	# Clear some plots for building
	for i in range(3):
		var plot = farm.grid.get_plot(Vector2i(3+i, 0))
		if plot:
			plot.is_planted = false

	# Test Q: place_mill
	_log("\n[Q] place_mill")
	input_handler.current_selection = Vector2i(3, 0)
	plot_grid_display._toggle_plot_selection(Vector2i(3, 0))
	input_handler._on_action_key_pressed("Q")
	await get_tree().process_frame
	var mill_plot = farm.grid.get_plot(Vector2i(3, 0))
	var mill_result = "PASS" if mill_plot.is_planted and "mill" in mill_plot.plant_type else "FAIL"
	_log("  Result: %s (plot type: %s)" % [mill_result, mill_plot.plant_type if mill_plot.is_planted else "empty"])
	test_results["Tool3_place_mill"] = mill_result

	# Test E: place_market
	_log("\n[E] place_market")
	input_handler.current_selection = Vector2i(4, 0)
	plot_grid_display._toggle_plot_selection(Vector2i(4, 0))
	input_handler._on_action_key_pressed("E")
	await get_tree().process_frame
	var market_plot = farm.grid.get_plot(Vector2i(4, 0))
	var market_result = "PASS" if market_plot.is_planted and "market" in market_plot.plant_type else "FAIL"
	_log("  Result: %s (plot type: %s)" % [market_result, market_plot.plant_type if market_plot.is_planted else "empty"])
	test_results["Tool3_place_market"] = market_result

	# Test R: place_kitchen
	_log("\n[R] place_kitchen")
	input_handler.current_selection = Vector2i(5, 0)
	plot_grid_display._toggle_plot_selection(Vector2i(5, 0))
	input_handler._on_action_key_pressed("R")
	await get_tree().process_frame
	var kitchen_plot = farm.grid.get_plot(Vector2i(5, 0))
	var kitchen_result = "PASS" if kitchen_plot.is_planted and "kitchen" in kitchen_plot.plant_type else "FAIL"
	_log("  Result: %s (plot type: %s)" % [kitchen_result, kitchen_plot.plant_type if kitchen_plot.is_planted else "empty"])
	test_results["Tool3_place_kitchen"] = kitchen_result


func _test_tool_4_energy():
	_log("\n" + "-"*80)
	_log("TOOL 4: ENERGY (⚡)")
	_log("-"*80)

	# Switch to tool 4
	input_handler.current_tool = 4

	# Plant a plot with quantum state
	farm.build(Vector2i(0, 0), "wheat")

	# Test Q: inject_energy
	_log("\n[Q] inject_energy")
	input_handler.current_selection = Vector2i(0, 0)
	plot_grid_display._toggle_plot_selection(Vector2i(0, 0))
	var plot = farm.grid.get_plot(Vector2i(0, 0))
	var energy_before = plot.quantum_state.energy if plot.quantum_state else 0.0
	input_handler._on_action_key_pressed("Q")
	await get_tree().process_frame
	var energy_after = plot.quantum_state.energy if plot.quantum_state else 0.0
	var inject_result = "PASS" if energy_after > energy_before else "FAIL"
	_log("  Result: %s (energy: %.2f → %.2f)" % [inject_result, energy_before, energy_after])
	test_results["Tool4_inject_energy"] = inject_result

	# Test E: drain_energy
	_log("\n[E] drain_energy")
	var wheat_before = farm.economy.wheat_inventory
	input_handler._on_action_key_pressed("E")
	await get_tree().process_frame
	var wheat_after = farm.economy.wheat_inventory
	var energy_final = plot.quantum_state.energy if plot.quantum_state else 0.0
	var drain_result = "PASS" if wheat_after > wheat_before and energy_final < energy_after else "FAIL"
	_log("  Result: %s (wheat: %d → %d, energy: %.2f)" % [drain_result, wheat_before, wheat_after, energy_final])
	test_results["Tool4_drain_energy"] = drain_result

	# Test R: place_energy_tap
	_log("\n[R] place_energy_tap")
	input_handler.current_selection = Vector2i(1, 1)
	plot_grid_display._toggle_plot_selection(Vector2i(1, 1))
	input_handler._on_action_key_pressed("R")
	await get_tree().process_frame
	var tap_plot = farm.grid.get_plot(Vector2i(1, 1))
	var tap_result = "PASS" if tap_plot.is_planted and "tap" in tap_plot.plant_type else "FAIL"
	_log("  Result: %s (plot type: %s)" % [tap_result, tap_plot.plant_type if tap_plot.is_planted else "empty"])
	test_results["Tool4_place_energy_tap"] = tap_result


func _test_tool_5_6_placeholders():
	_log("\n" + "-"*80)
	_log("TOOLS 5 & 6: PLACEHOLDERS")
	_log("-"*80)

	input_handler.current_tool = 5
	_log("\nTool 5: Not yet implemented (placeholder)")
	test_results["Tool5"] = "NOT_IMPLEMENTED"

	input_handler.current_tool = 6
	_log("Tool 6: Not yet implemented (placeholder)")
	test_results["Tool6"] = "NOT_IMPLEMENTED"


func _print_summary():
	_log("\n" + "="*80)
	_log("TEST SUMMARY")
	_log("="*80)

	var passed = 0
	var failed = 0
	var not_impl = 0

	for action in test_results.keys():
		var result = test_results[action]
		if result == "PASS":
			passed += 1
			_log("  ✅ %s: PASS" % action)
		elif result == "FAIL":
			failed += 1
			_log("  ❌ %s: FAIL" % action)
		elif result == "NOT_IMPLEMENTED":
			not_impl += 1
			_log("  ⏸️  %s: NOT IMPLEMENTED" % action)

	_log("\nResults: %d passed, %d failed, %d not implemented (out of %d)" % [passed, failed, not_impl, test_results.size()])

	# Save results to file
	var results_file = "user://tool_evaluation_results.txt"
	var log_text = "\n".join(test_log)
	var f = FileAccess.open(results_file, FileAccess.WRITE)
	if f:
		f.store_string(log_text)
		_log("\n✅ Results saved to: %s" % results_file)


func _log(message: String):
	print(message)
	test_log.append(message)


func _on_action_key_pressed(action_key: String):
	"""Simulate action key press"""
	var key_map = {"Q": KEY_Q, "E": KEY_E, "R": KEY_R}
	var keycode = key_map.get(action_key, KEY_Q)
	var event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
