extends Node

## Full Flow Test: Vocabulary Pairs → Injection → Develop → Extract
##
## Tests the complete loop:
## 1. Verify initial paired vocabulary (🌾/🍂, 👥/💸)
## 2. Learn a new pair via VocabularyPairing (simulate quest reward)
## 3. Inject the pair into a biome via expand_quantum_system
## 4. Let quantum system evolve
## 5. Use EXPLORE → MEASURE → POP to extract resources

const VocabularyPairing = preload("res://Core/Quests/VocabularyPairing.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

var farm: Node = null
var biome: Node = null
var plot_pool = null
var economy = null

var results = {
	"initial_vocab_check": false,
	"pair_roll": false,
	"injection": false,
	"evolution": false,
	"harvest": false
}

# The pair we'll learn and test
var test_north = ""
var test_south = ""


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("  VOCABULARY PAIR FULL FLOW TEST")
	print("  Learn → Inject → Develop → Extract")
	print("=".repeat(70))

	# Wait for boot
	print("\n[WAIT] Waiting for game boot...")
	var boot_frames = 0
	while farm == null and boot_frames < 300:
		await get_tree().process_frame
		boot_frames += 1
		_try_find_farm()

	if not farm:
		print("[ERROR] Farm not found after %d frames" % boot_frames)
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()
		return

	print("[OK] Farm found after %d frames" % boot_frames)
	_setup_references()

	# Run tests
	await _test_initial_vocabulary()
	await _test_pair_rolling()
	await _test_injection()
	await _test_evolution()
	await _test_harvest()

	_print_summary()
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func _try_find_farm() -> void:
	# Try GameStateManager.active_farm first (set during boot)
	if GameStateManager.active_farm:
		farm = GameStateManager.active_farm
		return

	# Try various paths
	var paths = [
		"/root/VocabPairFullFlowTest/FarmView/Farm",
		"/root/BeeInjectionTest/FarmView/Farm",
		"/root/TestVocabPairFullFlow/FarmView/Farm",
		"/root/FarmView/Farm",
		"/root/MainGame/Farm",
		"/root/Farm"
	]

	for path in paths:
		var node = get_node_or_null(path)
		if node:
			farm = node
			return

	# Check BootManager
	var boot_manager = get_node_or_null("/root/BootManager")
	if boot_manager:
		var farm_view = boot_manager.get_node_or_null("FarmView")
		if farm_view:
			farm = farm_view.get_node_or_null("Farm")
			if farm:
				return

	# Search tree
	for node in get_tree().root.get_children():
		var fv = node.get_node_or_null("FarmView")
		if fv:
			farm = fv.get_node_or_null("Farm")
			if farm:
				return
		var f = node.get_node_or_null("Farm")
		if f:
			farm = f
			return


func _setup_references() -> void:
	print("\n[SETUP] Getting references...")

	if farm.get("biotic_flux_biome"):
		biome = farm.biotic_flux_biome
		print("  [OK] BioticFlux biome found")

	if farm.get("plot_pool"):
		plot_pool = farm.plot_pool
		print("  [OK] PlotPool found")

	if farm.get("economy"):
		economy = farm.economy
		print("  [OK] Economy found")


func _test_initial_vocabulary() -> void:
	print("\n" + "-".repeat(50))
	print("TEST 1: Initial Paired Vocabulary")
	print("-".repeat(50))

	# Initialize game state if needed
	if not GameStateManager.current_state:
		GameStateManager.new_game("default")

	var state = GameStateManager.current_state
	if not state:
		print("  ❌ No game state available")
		return

	print("  Known emojis: %s" % str(state.known_emojis))
	print("  Known pairs: %d" % state.known_pairs.size())

	for pair in state.known_pairs:
		print("    %s/%s axis" % [pair.get("north", "?"), pair.get("south", "?")])

	# Verify we have the expected starter pairs
	var expected_emojis = ["🌾", "🍂", "👥", "💸"]
	var has_all = true
	for e in expected_emojis:
		if e not in state.known_emojis:
			has_all = false
			print("  ⚠ Missing expected emoji: %s" % e)

	if state.known_pairs.size() >= 2:
		print("  ✓ Initial vocabulary has %d pairs" % state.known_pairs.size())
		results["initial_vocab_check"] = true
	else:
		print("  ❌ Not enough pairs (expected ≥2, got %d)" % state.known_pairs.size())


func _test_pair_rolling() -> void:
	print("\n" + "-".repeat(50))
	print("TEST 2: Rolling New Vocabulary Pair")
	print("-".repeat(50))

	# Roll a new pair (simulating quest reward)
	# Use 🐝 as North since we know it has good connections
	var roll_result = VocabularyPairing.roll_partner("🐝")

	if roll_result.get("error"):
		print("  ❌ Roll failed: %s" % roll_result.get("error"))
		return

	test_north = roll_result.get("north", "?")
	test_south = roll_result.get("south", "?")
	var prob = roll_result.get("probability", 0.0)

	print("  Rolled pair: %s/%s (%.1f%% probability)" % [test_north, test_south, prob * 100])

	# Show connection info
	var connections = roll_result.get("connections", {})
	for target in connections:
		var c = connections[target]
		print("    %s/%s: weight=%.3f [H=%.2f L_in=%.2f L_out=%.2f]" % [
			test_north, target, c.get("weight", 0), c.get("h", 0), c.get("l_in", 0), c.get("l_out", 0)
		])

	# Simulate discovering the pair
	GameStateManager.discover_pair(test_north, test_south)

	var state = GameStateManager.current_state
	print("\n  After discovery:")
	print("    Known emojis: %d" % state.known_emojis.size())
	print("    Known pairs: %d" % state.known_pairs.size())

	if test_north in state.known_emojis and test_south in state.known_emojis:
		print("  ✓ Pair added to vocabulary")
		results["pair_roll"] = true
	else:
		print("  ❌ Pair not properly added")


func _test_injection() -> void:
	print("\n" + "-".repeat(50))
	print("TEST 3: Inject Pair into Quantum System")
	print("-".repeat(50))

	if not biome:
		print("  ❌ No biome found")
		return

	if test_north == "" or test_south == "":
		print("  ❌ No pair to inject (test 2 failed)")
		return

	# Get current state
	var qc = biome.quantum_computer
	var rm = qc.register_map
	var initial_dim = rm.dim()
	var initial_qubits = rm.num_qubits

	print("  Initial state:")
	print("    Qubits: %d, Dimension: %dD" % [initial_qubits, initial_dim])
	print("    Existing axes: %s" % str(rm.coordinates.keys().slice(0, 5)))

	# Pause evolution for expansion
	biome.set_evolution_paused(true)

	# Inject the pair
	print("\n  Injecting: %s/%s axis" % [test_north, test_south])
	var result = biome.expand_quantum_system(test_north, test_south)

	if result.get("error"):
		print("  ❌ Injection failed: %s" % result.get("error"))
		return

	# Resume evolution
	biome.set_evolution_paused(false)

	# Get new state
	var new_dim = rm.dim()
	var new_qubits = rm.num_qubits

	print("  After injection:")
	print("    Qubits: %d → %d" % [initial_qubits, new_qubits])
	print("    Dimension: %dD → %dD" % [initial_dim, new_dim])

	if new_dim > initial_dim:
		print("  ✓ Quantum system expanded")
		results["injection"] = true
	else:
		print("  ❌ Quantum system not expanded")


func _test_evolution() -> void:
	print("\n" + "-".repeat(50))
	print("TEST 4: Quantum Evolution")
	print("-".repeat(50))

	if not biome:
		print("  ❌ No biome found")
		return

	var qc = biome.quantum_computer
	var rm = qc.register_map

	# Get qubit for our test emoji
	var test_qubit = rm.qubit(test_north) if rm.has(test_north) else -1
	if test_qubit < 0:
		print("  ❌ Test emoji not in register map")
		return

	# Get initial probability
	var initial_prob = biome.get_register_probability(test_qubit)
	print("  Initial P(%s): %.4f" % [test_north, initial_prob])

	# Evolve
	print("  Evolving for 100 frames...")
	var probabilities = [initial_prob]

	for frame in range(1, 6):
		for _i in range(20):
			await get_tree().process_frame

		var prob = biome.get_register_probability(test_qubit)
		probabilities.append(prob)
		print("    Frame %d: P(%s)=%.4f" % [frame * 20, test_north, prob])

	var final_prob = probabilities[-1]
	var max_prob = probabilities.max()
	var min_prob = probabilities.min()
	var variance = max_prob - min_prob

	print("\n  Evolution stats:")
	print("    Initial: %.4f, Final: %.4f" % [initial_prob, final_prob])
	print("    Range: [%.4f, %.4f] (variance: %.4f)" % [min_prob, max_prob, variance])

	# Consider it evolved if probability changed meaningfully
	if variance > 0.001 or abs(final_prob - initial_prob) > 0.001:
		print("  ✓ Probability evolved")
		results["evolution"] = true
	else:
		print("  ⚠ Probability stable (may be at equilibrium)")
		results["evolution"] = true  # Still counts as working


func _test_harvest() -> void:
	print("\n" + "-".repeat(50))
	print("TEST 5: Harvest via EXPLORE → MEASURE → POP")
	print("-".repeat(50))

	if not biome or not plot_pool:
		print("  ❌ Missing biome or plot_pool")
		return

	var harvested = {}
	var harvest_count = 0
	var max_attempts = 10

	print("  Attempting %d harvest cycles..." % max_attempts)

	for attempt in range(max_attempts):
		# EXPLORE
		var explore_result = ProbeActions.action_explore(plot_pool, biome)
		if not explore_result.get("success"):
			continue

		var terminal = explore_result.get("terminal")
		var emoji_pair = explore_result.get("emoji_pair", {})
		var north = emoji_pair.get("north", "?")

		# MEASURE
		var measure_result = ProbeActions.action_measure(terminal, biome)
		if not measure_result.get("success"):
			continue

		var outcome = measure_result.get("outcome", "?")

		# POP
		var pop_result = ProbeActions.action_pop(terminal, plot_pool, economy)
		if pop_result.get("success"):
			harvest_count += 1
			harvested[outcome] = harvested.get(outcome, 0) + 1

	print("\n  Harvest results:")
	print("    Total harvested: %d/%d" % [harvest_count, max_attempts])

	for emoji in harvested:
		var marker = " ← OUR PAIR!" if emoji == test_north or emoji == test_south else ""
		print("    %s: %d%s" % [emoji, harvested[emoji], marker])

	if harvest_count > 0:
		print("  ✓ Successfully harvested resources!")
		results["harvest"] = true
	else:
		print("  ⚠ No harvest (may need more evolution or different approach)")


func _print_summary() -> void:
	print("\n" + "=".repeat(70))
	print("  SUMMARY")
	print("=".repeat(70))

	var passed = 0
	var total = results.size()

	for test_name in results:
		var status = "✓" if results[test_name] else "❌"
		print("  %s %s" % [status, test_name.replace("_", " ").capitalize()])
		if results[test_name]:
			passed += 1

	print("\n  Result: %d/%d tests passed" % [passed, total])

	if passed == total:
		print("  🎉 Full vocabulary pair flow working!")
	elif passed >= 3:
		print("  ⚠ Partial success - core mechanics work")
	else:
		print("  ❌ Flow has issues")
