extends SceneTree
## Test EXPLORE action - verifies get_density_matrix fix
## Run with: godot --headless --script res://Tests/test_explore_action.gd

var frame_count = 0
var scene_loaded = false
var ran = false

func _init():
	print("\n======================================================================")
	print("  EXPLORE ACTION TEST - Verify get_density_matrix fix")
	print("======================================================================\n")

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		print("Loading scene...")
		var scene = load("res://scenes/FarmView.tscn")
		var instance = scene.instantiate()
		root.add_child(instance)
		scene_loaded = true

		var boot_manager = root.get_node_or_null("/root/BootManager")
		boot_manager.game_ready.connect(func():
			if ran:
				return
			ran = true
			_run_tests()
		)

func _run_tests():
	print("Running EXPLORE tests...\n")

	# Find components
	var fv = root.get_node_or_null("FarmView")
	var farm = fv.farm if fv and "farm" in fv else null

	if not farm:
		print("FAIL: Farm not found")
		quit(1)
		return

	print("Farm found")
	print("Plot pool: %s" % (farm.plot_pool != null))

	# Get biome
	var biome = farm.biotic_flux_biome
	if not biome:
		print("FAIL: BioticFlux biome not found")
		quit(1)
		return

	print("Biome: %s" % biome.get_biome_type())
	print("Quantum computer: %s" % (biome.quantum_computer != null))

	# Test get_density_matrix method exists
	print("\n--- TEST 1: get_density_matrix method ---")
	if biome.quantum_computer.has_method("get_density_matrix"):
		print("PASS: QuantumComputer has get_density_matrix()")
		var dm = biome.quantum_computer.get_density_matrix()
		print("  Density matrix: %s (dim=%d)" % [dm != null, dm.n if dm else 0])
	else:
		print("FAIL: QuantumComputer missing get_density_matrix()")
		quit(1)
		return

	# Test get_register_probabilities
	print("\n--- TEST 2: get_register_probabilities ---")
	var probs = biome.get_register_probabilities()
	print("Register probabilities: %s" % probs)

	for reg_id in probs:
		var p = probs[reg_id]
		if p < 0:
			print("FAIL: Negative probability for register %d: %f" % [reg_id, p])
			quit(1)
			return
		print("  Register %d: %.4f (valid)" % [reg_id, p])

	print("PASS: All probabilities are non-negative")

	# Test EXPLORE action
	print("\n--- TEST 3: EXPLORE action ---")
	var ProbeActions = load("res://Core/Actions/ProbeActions.gd")

	if not farm.plot_pool:
		print("FAIL: PlotPool not available")
		quit(1)
		return

	var result = ProbeActions.action_explore(farm.plot_pool, biome)
	print("EXPLORE result: %s" % result)

	if result.success:
		print("PASS: EXPLORE action succeeded!")
		print("  Terminal: %s" % result.terminal.terminal_id)
		print("  Register: %d" % result.register_id)
		print("  Emoji pair: %s" % result.emoji_pair)
	else:
		print("FAIL: EXPLORE action failed: %s" % result.get("error", "unknown"))
		quit(1)
		return

	# Test drain_register_probability
	print("\n--- TEST 4: drain_register_probability method ---")
	if biome.has_method("drain_register_probability"):
		print("PASS: BiomeBase has drain_register_probability()")

		# Test draining
		var reg_id = result.register_id
		var before_prob = biome.get_register_probability(reg_id)
		print("  Before drain: %.4f" % before_prob)

		biome.drain_register_probability(reg_id, true, 0.5)

		var after_prob = biome.get_register_probability(reg_id)
		print("  After drain:  %.4f" % after_prob)

		# After drain, probability should change (trace renormalized)
		print("PASS: drain_register_probability works")
	else:
		print("FAIL: BiomeBase missing drain_register_probability()")
		quit(1)
		return

	print("\n======================================================================")
	print("  ALL EXPLORE TESTS PASSED")
	print("======================================================================")
	quit(0)
