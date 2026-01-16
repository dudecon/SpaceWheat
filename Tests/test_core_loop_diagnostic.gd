extends SceneTree
## Core Loop Diagnostic Test
## Run with: godot --headless --script res://Tests/test_core_loop_diagnostic.gd
##
## Tests the FULL EXPLORE → MEASURE → POP workflow with detailed logging

const SEPARATOR = "======================================================================"

var farm = null
var input_handler = null
var scene_loaded = false
var tests_done = false
var frame_count = 0
var boot_manager = null

func _init():
	print("\n" + SEPARATOR)
	print("🔬 CORE LOOP DIAGNOSTIC TEST")
	print("Testing: SELECT → EXPLORE → MEASURE → POP workflow")
	print(SEPARATOR + "\n")


func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		print("Loading scene...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			var instance = scene.instantiate()
			root.add_child(instance)
			scene_loaded = true
			boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)
		else:
			print("✗ Failed to load scene")
			quit(1)


func _on_game_ready():
	if tests_done:
		return
	tests_done = true
	print("\n✅ Game ready!\n")

	_find_components()

	# Disable evolution for test speed
	if farm:
		for biome in [farm.biotic_flux_biome, farm.forest_biome, farm.market_biome, farm.kitchen_biome]:
			if biome:
				biome.quantum_evolution_enabled = false
				biome.set_process(false)
		farm.set_process(false)
		if farm.grid:
			farm.grid.set_process(false)

	if input_handler and farm:
		_run_diagnostic()
	else:
		print("✗ Components not found (input_handler=%s, farm=%s)" % [input_handler != null, farm != null])
		quit(1)


func _find_components():
	var player_shell = _find_node(root, "PlayerShell")
	if player_shell:
		input_handler = player_shell.get_node_or_null("FarmInputHandler")

	var farm_view = root.get_node_or_null("FarmView")
	if farm_view:
		farm = farm_view.farm if "farm" in farm_view else null


func _find_node(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var found = _find_node(child, name)
		if found:
			return found
	return null


func _run_diagnostic():
	print(SEPARATOR)
	print("STEP 1: CHECK INITIAL STATE")
	print(SEPARATOR)

	# Check tool state
	print("  Current tool: %d" % input_handler.current_tool)

	# Check plot grid display
	var pgd = input_handler.plot_grid_display
	if pgd:
		var selected = pgd.get_selected_plots() if pgd.has_method("get_selected_plots") else []
		print("  PlotGridDisplay: Found")
		print("  Selected plots: %d" % selected.size())
	else:
		print("  ✗ PlotGridDisplay NOT found on input_handler!")
		quit(1)

	# Check current selection fallback
	print("  Fallback selection: %s" % input_handler.current_selection)

	# Check biome for (0,0)
	var pos = Vector2i(0, 0)
	var biome = farm.grid.get_biome_for_plot(pos)
	print("  Biome for %s: %s" % [pos, biome.biome_name if biome else "NONE"])

	# Check plot state
	var plot = farm.grid.get_plot(pos)
	if plot:
		print("  Plot %s exists: is_planted=%s" % [pos, plot.is_planted])
	else:
		print("  ✗ No plot at %s!" % pos)
		quit(1)

	print("\n" + SEPARATOR)
	print("STEP 2: SELECT PLOT (Press T)")
	print(SEPARATOR)

	_simulate_key(KEY_T)

	var selected_after_t = pgd.get_selected_plots() if pgd.has_method("get_selected_plots") else []
	print("  Selected after T: %s" % str(selected_after_t))

	if selected_after_t.is_empty():
		print("  ✗ No plots selected after pressing T!")
		print("  Checking current_selection fallback: %s" % input_handler.current_selection)
		# Force selection for testing
		input_handler.current_selection = Vector2i(0, 0)
		print("  Forced current_selection to (0,0)")

	print("\n" + SEPARATOR)
	print("STEP 3: SELECT PROBE TOOL (Press 1)")
	print(SEPARATOR)

	_simulate_key(KEY_1)
	print("  Current tool after pressing 1: %d" % input_handler.current_tool)

	print("\n" + SEPARATOR)
	print("STEP 4: EXPLORE (Press Q) - Bind plot to qubit")
	print(SEPARATOR)

	# Check pre-EXPLORE state
	var plot_before = farm.grid.get_plot(pos)
	print("  Before EXPLORE: is_planted=%s" % plot_before.is_planted)

	# Connect to action_performed signal to capture result
	var result_captured = {"success": false, "message": "No signal received"}
	if input_handler.has_signal("action_performed"):
		input_handler.action_performed.connect(func(action, success, msg):
			result_captured = {"action": action, "success": success, "message": msg}
		)

	_simulate_key(KEY_Q)

	print("  Action result: %s" % str(result_captured))

	# Check post-EXPLORE state
	var plot_after = farm.grid.get_plot(pos)
	print("  After EXPLORE: is_planted=%s" % plot_after.is_planted)

	if plot_after.is_planted:
		print("  ✅ Plot is now planted/bound!")
		print("    bound_qubit: %d" % plot_after.bound_qubit)
		print("    parent_biome: %s" % (plot_after.parent_biome.biome_name if plot_after.parent_biome else "NONE"))
		print("    north_emoji: %s" % plot_after.north_emoji)
		print("    south_emoji: %s" % plot_after.south_emoji)
	else:
		print("  ✗ Plot is NOT planted after EXPLORE!")
		print("  Checking why EXPLORE might have failed...")
		# Re-check all preconditions
		print("    farm: %s" % (farm != null))
		print("    biome: %s" % (biome.biome_name if biome else "NONE"))
		print("    biome.quantum_computer: %s" % (biome.quantum_computer != null if biome else false))
		if biome and biome.quantum_computer:
			print("    qc.register_map: %s" % (biome.quantum_computer.register_map != null))
			if biome.quantum_computer.register_map:
				print("    num_qubits: %d" % biome.quantum_computer.register_map.num_qubits)

	print("\n" + SEPARATOR)
	print("STEP 5: MEASURE (Press E) - Collapse wavefunction")
	print(SEPARATOR)

	result_captured = {"success": false, "message": "No signal received"}
	_simulate_key(KEY_E)

	print("  Action result: %s" % str(result_captured))

	if plot_after.is_planted:
		print("  has_been_measured: %s" % plot_after.has_been_measured)
		print("  measured_outcome: %s" % plot_after.measured_outcome)

	print("\n" + SEPARATOR)
	print("STEP 6: POP (Press R) - Harvest and unbind")
	print(SEPARATOR)

	result_captured = {"success": false, "message": "No signal received"}
	_simulate_key(KEY_R)

	print("  Action result: %s" % str(result_captured))

	# Check final state
	var plot_final = farm.grid.get_plot(pos)
	print("  Final state: is_planted=%s" % plot_final.is_planted)

	print("\n" + SEPARATOR)
	print("DIAGNOSTIC COMPLETE")
	print(SEPARATOR + "\n")

	quit(0)


func _simulate_key(keycode: int):
	var press = InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	press.echo = false

	Input.parse_input_event(press)

	if input_handler and input_handler.has_method("_unhandled_input"):
		input_handler._unhandled_input(press)
