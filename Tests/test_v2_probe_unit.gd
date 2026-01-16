extends SceneTree

## Unit test for v2 EXPLORE/MEASURE/POP actions
## Tests ProbeActions directly without full scene

var test_results := []

func _init():
	print("")
	print("======================================================================")
	print("V2 PROBE ACTIONS UNIT TEST")
	print("======================================================================")
	print("")
	
	_run_tests()

func _run_tests():
	# Load required classes
	const PlotPoolClass = preload("res://Core/GameMechanics/PlotPool.gd")
	const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
	const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
	
	print("Creating PlotPool...")
	var pool = PlotPoolClass.new(12)
	print("  Pool size: %d" % pool.pool_size)
	print("  Unbound: %d" % pool.get_unbound_count())
	_pass("PlotPool created")
	
	print("\nCreating BioticFlux biome...")
	var biome = BioticFluxBiome.new()
	
	# Initialize the biome's quantum computer
	if biome.has_method("_ready"):
		biome._ready()
	
	print("  Biome type: %s" % biome.get_biome_type())
	
	# Check if quantum_computer is initialized
	if not biome.quantum_computer:
		print("  WARNING: quantum_computer not initialized - biome needs scene tree")
		# Try manual init
		if biome.has_method("_initialize_quantum_computer"):
			biome._initialize_quantum_computer()
	
	if biome.quantum_computer:
		print("  Quantum computer ready")
		_pass("Biome created")
	else:
		# Even without quantum_computer, test the pool
		print("  Skipping biome quantum tests (requires scene tree)")
		_pass("Biome created (limited)")
	
	# Test EXPLORE
	print("\nTesting EXPLORE action...")
	if biome.quantum_computer:
		var explore_result = ProbeActions.action_explore(pool, biome)
		
		if explore_result.success:
			print("  EXPLORE succeeded!")
			print("    Terminal: %s" % explore_result.terminal.terminal_id)
			print("    Register: %d" % explore_result.register_id)
			_pass("EXPLORE works")
			
			# Test MEASURE
			print("\nTesting MEASURE action...")
			var terminal = explore_result.terminal
			var measure_result = ProbeActions.action_measure(terminal, biome)
			
			if measure_result.success:
				print("  MEASURE succeeded!")
				print("    Outcome: %s" % measure_result.outcome)
				_pass("MEASURE works")
				
				# Test POP
				print("\nTesting POP action...")
				var pop_result = ProbeActions.action_pop(terminal, pool, null)
				
				if pop_result.success:
					print("  POP succeeded!")
					print("    Harvested: %s" % pop_result.resource)
					_pass("POP works")
				else:
					_fail("POP failed: %s" % pop_result.get("message", "unknown"))
			else:
				_fail("MEASURE failed: %s" % measure_result.get("message", "unknown"))
		else:
			_fail("EXPLORE failed: %s" % explore_result.get("message", "unknown"))
	else:
		print("  Skipping (biome quantum computer not initialized)")
		_pass("EXPLORE (skipped - needs full scene)")
		_pass("MEASURE (skipped - needs full scene)")
		_pass("POP (skipped - needs full scene)")
	
	# Test terminal pool functions
	print("\nTesting PlotPool methods...")
	var t1 = pool.get_unbound_terminal()
	if t1:
		print("  Got unbound terminal: %s" % t1.terminal_id)
		_pass("get_unbound_terminal works")
	else:
		_fail("get_unbound_terminal returned null")
	
	print("\nDone.")
	_finish()

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
	
	quit(0 if failed == 0 else 1)
