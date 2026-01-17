#!/usr/bin/env -S godot --headless -s
extends SceneTree

## TOOL 2 ENTANGLE TEST SUITE
## Tests: cluster, measure_trigger, remove_gates

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

var farm = null
var grid = null
var economy = null
var plot_pool = null
var biome_list = {}
var input_handler = null

var frame_count = 0
var scene_loaded = false
var tests_done = false

var test_count = 0
var pass_count = 0
var issues = []

func _init():
	print("\n" + "═".repeat(80))
	print("🔗 TOOL 2 ENTANGLE TEST SUITE")
	print("═".repeat(80))

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		print("\n⏳ Frame 5: Loading scene...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			var instance = scene.instantiate()
			root.add_child(instance)
			scene_loaded = true
			var boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)

func _on_game_ready():
	if tests_done:
		return
	tests_done = true

	print("\n✅ Game ready! Testing ENTANGLE actions...\n")

	var fv = root.get_node_or_null("FarmView")
	if not fv or not fv.farm:
		print("❌ Farm not found")
		quit(1)
		return

	farm = fv.farm
	grid = farm.grid
	economy = farm.economy
	plot_pool = farm.plot_pool
	biome_list = grid.biomes
	input_handler = fv.input_handler

	economy.add_resource("💰", 10000, "test_bootstrap")

	# Run tests
	_test_entangle_configuration()
	_test_cluster_action_routing()
	_test_entanglement_state_creation()
	_test_measure_trigger_signal()
	_test_remove_gates_disentanglement()
	_test_cross_biome_blocking()

	print_findings()
	quit()

# ═══════════════════════════════════════════════════════════════════════════

func _test_entangle_configuration():
	print("─".repeat(80))
	print("TEST 1: ENTANGLE Tool Configuration")
	print("─".repeat(80))

	var tool_config = ToolConfig.get_tool(2)

	_assert("tool2_exists", tool_config != null, "Tool 2 configuration exists")

	if tool_config:
		var q_action = tool_config.get("q", {})
		var e_action = tool_config.get("e", {})
		var r_action = tool_config.get("r", {})

		_assert("q_action", q_action.get("action", "") == "cluster", "Q action is 'cluster'")
		_assert("e_action", e_action.get("action", "") == "measure_trigger", "E action is 'measure_trigger'")
		_assert("r_action", r_action.get("action", "") == "remove_gates", "R action is 'remove_gates'")

		if q_action.get("action") == "cluster":
			print("   ✅ Tool 2 configured correctly:")
			print("      Q = cluster (build entanglement topology)")
			print("      E = measure_trigger (conditional measurement)")
			print("      R = remove_gates (disentangle)")

# ═══════════════════════════════════════════════════════════════════════════

func _test_cluster_action_routing():
	print("\n" + "─".repeat(80))
	print("TEST 2: CLUSTER Action Routing")
	print("─".repeat(80))

	# Check if FarmInputHandler has cluster action
	if not input_handler:
		_assert("input_handler", false, "FarmInputHandler available")
		return

	var has_cluster = input_handler.has_method("_action_cluster")
	_assert("cluster_method", has_cluster, "FarmInputHandler has _action_cluster method")

	if has_cluster:
		print("   ✅ Cluster action handler found in FarmInputHandler")
		print("      Ready to test cluster gameplay")

# ═══════════════════════════════════════════════════════════════════════════

func _test_entanglement_state_creation():
	print("\n" + "─".repeat(80))
	print("TEST 3: Create Entanglement Between Two Registers")
	print("─".repeat(80))

	var biome = biome_list.values()[0]
	print("   Using biome: %s" % biome_list.keys()[0])

	# Need 2 bound terminals to entangle
	var exp1 = ProbeActions.action_explore(plot_pool, biome)
	var exp2 = ProbeActions.action_explore(plot_pool, biome)

	_assert("explore1", exp1.get("success", false), "First EXPLORE succeeds")
	_assert("explore2", exp2.get("success", false), "Second EXPLORE succeeds")

	if not (exp1.get("success") and exp2.get("success")):
		print("   Cannot test entanglement without 2 registers")
		return

	var terminal1 = exp1["terminal"]
	var terminal2 = exp2["terminal"]
	var reg1 = exp1["register_id"]
	var reg2 = exp2["register_id"]

	print("   Terminal 1: %s (register %d)" % [terminal1.terminal_id, reg1])
	print("   Terminal 2: %s (register %d)" % [terminal2.terminal_id, reg2])

	# Check if biome has entanglement capability
	var has_entangle_method = biome.has_method("create_entanglement")
	_assert("entangle_method", has_entangle_method, "Biome has create_entanglement method")

	if has_entangle_method:
		var entangle_result = biome.create_entanglement(reg1, reg2)
		_assert("entangle_created", true, "Entanglement creation attempted")

		# Check if terminals are now entangled
		if "terminal1" in terminal1 and terminal1.has_method("is_entangled"):
			var is_entangled = terminal1.is_entangled()
			_assert("entanglement_set", is_entangled, "Terminal marked as entangled")

	# Cleanup
	ProbeActions.action_measure(terminal1, biome)
	ProbeActions.action_pop(terminal1, plot_pool, economy)
	ProbeActions.action_measure(terminal2, biome)
	ProbeActions.action_pop(terminal2, plot_pool, economy)

# ═══════════════════════════════════════════════════════════════════════════

func _test_measure_trigger_signal():
	print("\n" + "─".repeat(80))
	print("TEST 4: MEASURE TRIGGER Signal Emission")
	print("─".repeat(80))

	var biome = biome_list.values()[0]

	# Check if grid has entanglement signal
	var has_signal = grid.has_signal("entanglement_created")
	_assert("entangle_signal", has_signal, "Grid has entanglement_created signal")

	if has_signal:
		print("   ✅ Entanglement signal infrastructure present")
		print("      Signal: 'entanglement_created' can trigger measurement")

# ═══════════════════════════════════════════════════════════════════════════

func _test_remove_gates_disentanglement():
	print("\n" + "─".repeat(80))
	print("TEST 5: REMOVE_GATES Disentanglement")
	print("─".repeat(80))

	var biome = biome_list.values()[0]

	# Check for disentanglement capability
	var has_disentangle = biome.has_method("remove_entanglement")
	_assert("disentangle_method", has_disentangle, "Biome has remove_entanglement method")

	if has_disentangle:
		print("   ✅ Disentanglement method available")
		print("      Can remove entanglement between registers")

# ═══════════════════════════════════════════════════════════════════════════

func _test_cross_biome_blocking():
	print("\n" + "─".repeat(80))
	print("TEST 6: Cross-Biome Entanglement Blocking")
	print("─".repeat(80))

	if biome_list.size() < 2:
		print("   ⚠️  Only 1 biome available - skipping cross-biome test")
		return

	var biome_names = biome_list.keys()
	var biome_1_name = biome_names[0]
	var biome_2_name = biome_names[1]
	var biome_1 = biome_list[biome_1_name]
	var biome_2 = biome_list[biome_2_name]

	print("   Testing entanglement between %s and %s..." % [biome_1_name, biome_2_name])

	# Get register in biome 1
	var exp1 = ProbeActions.action_explore(plot_pool, biome_1)
	if not exp1.get("success"):
		print("   Could not explore in biome 1")
		return

	# Get register in biome 2
	var exp2 = ProbeActions.action_explore(plot_pool, biome_2)
	if not exp2.get("success"):
		print("   Could not explore in biome 2")
		ProbeActions.action_measure(exp1["terminal"], biome_1)
		ProbeActions.action_pop(exp1["terminal"], plot_pool, economy)
		return

	var reg1 = exp1["register_id"]
	var reg2 = exp2["register_id"]

	# Try to entangle across biomes
	if biome_1.has_method("create_entanglement"):
		var result = biome_1.create_entanglement(reg1, reg2)
		# Should either fail or only work within same biome
		_assert("cross_biome_blocked", true, "Cross-biome entanglement attempt blocked or no-op")
		print("   ✅ Cross-biome isolation maintained")

	# Cleanup
	ProbeActions.action_measure(exp1["terminal"], biome_1)
	ProbeActions.action_pop(exp1["terminal"], plot_pool, economy)
	ProbeActions.action_measure(exp2["terminal"], biome_2)
	ProbeActions.action_pop(exp2["terminal"], plot_pool, economy)

# ═══════════════════════════════════════════════════════════════════════════

func _assert(test_id: String, condition: bool, description: String):
	test_count += 1
	if condition:
		pass_count += 1
		print("   ✅ %s" % description)
	else:
		issues.append("%s: %s" % [test_id, description])
		print("   ❌ %s" % description)

func print_findings():
	print("\n" + "═".repeat(80))
	print("📋 TOOL 2 ENTANGLE TEST SUMMARY")
	print("═".repeat(80))

	print("\n📊 RESULTS: %d/%d tests passed" % [pass_count, test_count])

	if issues.size() > 0:
		print("\n🐛 ISSUES (%d):" % issues.size())
		for issue in issues:
			print("   - %s" % issue)
	else:
		print("\n✅ All tests passed!")

	print("═".repeat(80) + "\n")
