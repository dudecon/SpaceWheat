extends SceneTree

## Test v2 EXPLORE/MEASURE/POP actions

var frame_count := 0
var farm = null
var test_results := []

func _init():
	print("")
	print("======================================================================")
	print("V2 PROBE ACTIONS TEST")
	print("======================================================================")
	print("")

func _process(_delta):
	frame_count += 1
	
	if frame_count == 10:
		_load_main_scene()
	
	if frame_count == 30:
		_run_tests()

func _load_main_scene():
	print("Loading main scene...")
	var scene = load("res://scenes/FarmView.tscn")
	var root_node = scene.instantiate()
	get_root().add_child(root_node)

func _run_tests():
	print("\nRunning v2 Probe Action Tests...\n")
	
	# Find farm
	farm = _find_farm()
	if not farm:
		_fail("Could not find Farm instance")
		_finish()
		return
	
	print("Farm found")
	
	# Test 1: PlotPool exists
	if not farm.plot_pool:
		_fail("farm.plot_pool is null")
	else:
		print("PlotPool exists with %d terminals" % farm.plot_pool.pool_size)
		_pass("PlotPool created")
	
	# Test 2: Get biome
	var biome = farm.grid.get_biome_for_plot(Vector2i(2, 0))  # BioticFlux position
	if not biome:
		_fail("Could not get biome for plot (2,0)")
	else:
		print("Biome: %s" % biome.get_biome_type())
		_pass("Biome accessible")
	
	# Test 3: EXPLORE action
	const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
	
	print("\nTesting EXPLORE...")
	var explore_result = ProbeActions.action_explore(farm.plot_pool, biome)
	
	if explore_result.success:
		print("  EXPLORE succeeded!")
		print("    Terminal: %s" % explore_result.terminal.terminal_id)
		print("    Register: %d" % explore_result.register_id)
		print("    Emoji: %s" % explore_result.emoji_pair.get("north", "?"))
		print("    Probability: %.1f%%" % (explore_result.probability * 100))
		_pass("EXPLORE action works")
		
		# Test 4: MEASURE action
		print("\nTesting MEASURE...")
		var terminal = explore_result.terminal
		var measure_result = ProbeActions.action_measure(terminal, biome)
		
		if measure_result.success:
			print("  MEASURE succeeded!")
			print("    Outcome: %s" % measure_result.outcome)
			print("    Probability: %.1f%%" % (measure_result.probability * 100))
			_pass("MEASURE action works")
			
			# Test 5: POP action
			print("\nTesting POP...")
			var pop_result = ProbeActions.action_pop(terminal, farm.plot_pool, farm.economy)
			
			if pop_result.success:
				print("  POP succeeded!")
				print("    Harvested: %s" % pop_result.resource)
				_pass("POP action works")
			else:
				_fail("POP failed: %s" % pop_result.get("message", "unknown"))
		else:
			_fail("MEASURE failed: %s" % measure_result.get("message", "unknown"))
	else:
		_fail("EXPLORE failed: %s" % explore_result.get("message", "unknown"))
	
	_finish()

func _find_farm():
	# Try common locations
	var farm_view = get_root().get_node_or_null("FarmView")
	if farm_view and farm_view.has_node("Farm"):
		return farm_view.get_node("Farm")
	
	# Search recursively
	return _find_node_by_type(get_root(), "Farm")

func _find_node_by_type(node, type_name: String):
	if node.get_class() == type_name or (node.get_script() and node.get_script().get_global_name() == type_name):
		return node
	for child in node.get_children():
		var found = _find_node_by_type(child, type_name)
		if found:
			return found
	return null

func _pass(test_name: String):
	test_results.append({"name": test_name, "passed": true})

func _fail(test_name: String):
	test_results.append({"name": test_name, "passed": false})
	print("  FAIL: %s" % test_name)

func _finish():
	print("")
	print("======================================================================")
	print("TEST RESULTS")
	print("======================================================================")
	
	var passed := 0
	var failed := 0
	
	for result in test_results:
		if result.passed:
			passed += 1
			print("  PASS: %s" % result.name)
		else:
			failed += 1
			print("  FAIL: %s" % result.name)
	
	print("\n  Total: %d passed, %d failed" % [passed, failed])
	print("======================================================================")
	print("")
	
	quit(0 if failed == 0 else 1)
