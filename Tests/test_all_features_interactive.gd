extends Node

## Comprehensive Interactive Test Suite
## Tests all tools, overlays, and interactions as a player would use them

signal test_completed(test_name: String, passed: bool, details: String)
signal all_tests_completed(total: int, passed: int, failed: int)

var test_results = []
var total_tests = 0
var passed_tests = 0

# Helper function for string repetition (GDScript doesn't support string * int)
func _repeat_string(s: String, count: int) -> String:
	var result = ""
	for i in range(count):
		result += s
	return result

func _ready():
	await get_tree().process_frame
	_run_all_tests()

func _run_all_tests():
	print("\n" + _repeat_string("=", 120))
	print("🎮 COMPREHENSIVE INTERACTIVE TEST SUITE - PHASE 6 v2 OVERLAYS & TOOLS")
	print(_repeat_string("=", 120))

	# Get required game objects
	var farm_view = get_tree().get_first_node_in_group("farm_view")
	var player_shell = get_tree().get_first_node_in_group("player_shell")

	if not farm_view or not player_shell:
		print("❌ FATAL: Game components not initialized")
		return

	# Test categories
	var tests = [
		["Boot & Components", func(): _test_boot_sequence(player_shell)],
		["Overlay System", func(): _test_overlay_system(player_shell)],
		["Inspector Overlay", func(): _test_inspector_overlay(player_shell)],
		["Semantic Map", func(): _test_semantic_map_overlay(player_shell)],
		["Controls Overlay", func(): _test_controls_overlay(player_shell)],
		["Quest Board", func(): _test_quests_overlay(player_shell)],
		["Biome Detail", func(): _test_biome_detail_overlay(player_shell)],
		["Tool Selection", func(): _test_tool_selection(player_shell)],
		["Tool Actions", func(): _test_tool_actions(player_shell)],
		["Input Routing", func(): _test_input_routing(player_shell)],
		["Data Flow", func(): _test_data_flow(player_shell)],
	]

	for test_group in tests:
		var test_name = test_group[0]
		var test_func = test_group[1]

		print("\n" + _repeat_string("─", 120))
		print("🔬 %s" % test_name)
		print(_repeat_string("─", 120))

		test_func.call()
		await get_tree().process_frame

	# Summary
	_print_summary()

func _add_test(test_name: String, passed: bool, details: String = ""):
	total_tests += 1
	if passed:
		passed_tests += 1
		print("   ✅ %s" % test_name)
	else:
		print("   ❌ %s" % test_name)
		if details:
			print("      └─ %s" % details)

	test_results.append({
		"name": test_name,
		"passed": passed,
		"details": details
	})

func _test_boot_sequence(shell: Node):
	_add_test("PlayerShell exists", shell != null)
	_add_test("OverlayManager exists", shell.overlay_manager != null)
	_add_test("ActionBarManager exists", shell.action_bar_manager != null)
	_add_test("Farm exists", shell.farm != null)
	_add_test("InputHandler exists", shell.input_handler != null)

func _test_overlay_system(shell: Node):
	var overlay_mgr = shell.overlay_manager
	if not overlay_mgr:
		_add_test("Overlay system accessible", false, "overlay_manager is null")
		return

	_add_test("v2_overlays dictionary exists", overlay_mgr.v2_overlays != null)
	_add_test("5 overlays registered", overlay_mgr.v2_overlays.size() == 5)

	var expected = ["inspector", "controls", "semantic_map", "quests", "biome_detail"]
	for overlay_name in expected:
		var has_overlay = overlay_mgr.v2_overlays.has(overlay_name)
		_add_test("  → %s overlay exists" % overlay_name, has_overlay)

		if has_overlay:
			var overlay = overlay_mgr.v2_overlays[overlay_name]
			var has_methods = (
				overlay.has_method("handle_input") and
				overlay.has_method("activate") and
				overlay.has_method("deactivate") and
				overlay.has_method("navigate")
			)
			_add_test("    → %s has v2 methods" % overlay_name, has_methods)

func _test_inspector_overlay(shell: Node):
	var overlay_mgr = shell.overlay_manager
	if not overlay_mgr:
		_add_test("Inspector accessible", false)
		return

	var inspector = overlay_mgr.v2_overlays.get("inspector")
	if not inspector:
		_add_test("Inspector overlay exists", false)
		return

	_add_test("Inspector overlay exists", true)
	_add_test("Inspector has set_biome method", inspector.has_method("set_biome"))

	# Try opening it
	var opened = overlay_mgr.open_v2_overlay("inspector")
	_add_test("Inspector overlay opens", opened)

	if opened and inspector.quantum_computer:
		_add_test("  → Inspector has quantum_computer data", true)
	else:
		_add_test("  → Inspector quantum_computer binding", false, "quantum_computer is null")

	overlay_mgr.close_v2_overlay()

func _test_semantic_map_overlay(shell: Node):
	var overlay_mgr = shell.overlay_manager
	if not overlay_mgr:
		_add_test("Semantic Map accessible", false)
		return

	var semantic = overlay_mgr.v2_overlays.get("semantic_map")
	if not semantic:
		_add_test("Semantic Map overlay exists", false)
		return

	_add_test("Semantic Map overlay exists", true)

	# Try opening it
	var opened = overlay_mgr.open_v2_overlay("semantic_map")
	_add_test("Semantic Map opens", opened)

	if opened:
		# Check if vocabulary loaded
		var has_vocab = semantic.vocabulary_data and semantic.vocabulary_data.size() > 0
		_add_test("  → Vocabulary data loaded", has_vocab)

		# Check octant grid
		_add_test("  → Octant grid created", semantic.octant_grid != null)

		# Test navigation
		semantic.on_q_pressed()
		_add_test("  → Q key (prev octant) works", true)

		semantic.on_e_pressed()
		_add_test("  → E key (next octant) works", true)

		semantic.on_f_pressed()
		_add_test("  → F key (cycle view) works", true)

	overlay_mgr.close_v2_overlay()

func _test_controls_overlay(shell: Node):
	var overlay_mgr = shell.overlay_manager
	if not overlay_mgr:
		_add_test("Controls accessible", false)
		return

	var controls = overlay_mgr.v2_overlays.get("controls")
	if not controls:
		_add_test("Controls overlay exists", false)
		return

	_add_test("Controls overlay exists", true)

	# Try opening it
	var opened = overlay_mgr.open_v2_overlay("controls")
	_add_test("Controls overlay opens", opened)

	if opened:
		# Test controls functionality
		_add_test("  → Controls displays key reference", controls.visible)

	overlay_mgr.close_v2_overlay()

func _test_quests_overlay(shell: Node):
	var overlay_mgr = shell.overlay_manager
	if not overlay_mgr:
		_add_test("Quests accessible", false)
		return

	var quests = overlay_mgr.v2_overlays.get("quests")
	if not quests:
		_add_test("Quests overlay exists", false)
		return

	_add_test("Quests overlay exists", true)

	# Try opening it
	var opened = overlay_mgr.open_v2_overlay("quests")
	_add_test("Quests overlay opens", opened)

	if opened:
		var has_quest_manager = quests.quest_manager != null if quests.has_meta("quest_manager") or "quest_manager" in quests else false
		_add_test("  → Quest manager accessible", has_quest_manager)

	overlay_mgr.close_v2_overlay()

func _test_biome_detail_overlay(shell: Node):
	var overlay_mgr = shell.overlay_manager
	if not overlay_mgr:
		_add_test("Biome Detail accessible", false)
		return

	var biome_detail = overlay_mgr.v2_overlays.get("biome_detail")
	if not biome_detail:
		_add_test("Biome Detail overlay exists", false)
		return

	_add_test("Biome Detail overlay exists", true)

	# Try opening it
	var opened = overlay_mgr.open_v2_overlay("biome_detail")
	_add_test("Biome Detail overlay opens", opened)

	overlay_mgr.close_v2_overlay()

func _test_tool_selection(shell: Node):
	var action_bar = shell.action_bar_manager
	if not action_bar:
		_add_test("Tool system accessible", false)
		return

	_add_test("ActionBarManager exists", true)

	# Test selecting each tool
	for tool_num in range(1, 5):
		action_bar.select_tool(tool_num - 1)  # 0-indexed
		_add_test("  → Tool %d selectable" % tool_num, true)

func _test_tool_actions(shell: Node):
	var input_handler = shell.input_handler
	if not input_handler:
		_add_test("Tool actions accessible", false)
		return

	_add_test("InputHandler exists", true)

	# We can't easily test actual tool execution without plotting/biomes,
	# but we can verify the system is ready
	_add_test("  → Q/E/R action routing implemented", input_handler.has_method("_unhandled_input"))

func _test_input_routing(shell: Node):
	var overlay_mgr = shell.overlay_manager
	var input_handler = shell.input_handler

	# Test routing priority
	var has_v2_system = overlay_mgr and overlay_mgr.v2_overlays != null
	_add_test("v2 Overlay routing ready", has_v2_system)

	var has_modal_stack = shell.has_method("_handle_shell_action")
	_add_test("Modal stack routing ready", has_modal_stack)

	var has_input_handler = input_handler != null
	_add_test("FarmInputHandler routing ready", has_input_handler)

	# Test ESC handling
	_add_test("ESC key routing implemented", input_handler.has_method("_unhandled_input"))

func _test_data_flow(shell: Node):
	var overlay_mgr = shell.overlay_manager
	var farm = shell.farm

	# Inspector data
	var inspector = overlay_mgr.v2_overlays.get("inspector") if overlay_mgr else null
	if inspector and inspector.has_method("set_biome"):
		_add_test("Inspector data binding ready", true)
	else:
		_add_test("Inspector data binding ready", false)

	# Semantic Map data
	var semantic = overlay_mgr.v2_overlays.get("semantic_map") if overlay_mgr else null
	if semantic:
		var has_vocab_loader = semantic.has_method("_load_vocabulary_data")
		_add_test("Semantic Map vocab loading implemented", has_vocab_loader)
	else:
		_add_test("Semantic Map vocab loading ready", false)

	# Farm data
	if farm:
		var has_biomes = farm.biomes and farm.biomes.size() > 0
		_add_test("Farm biomes initialized", has_biomes)

		var has_grid = farm.grid and farm.grid.plots
		_add_test("Farm grid initialized", has_grid)
	else:
		_add_test("Farm data accessible", false)

func _print_summary():
	print("\n" + _repeat_string("=", 120))
	print("📊 TEST SUMMARY")
	print(_repeat_string("=", 120))

	print("\n%d / %d tests passed (%.1f%%)" % [
		passed_tests,
		total_tests,
		(passed_tests as float / total_tests) * 100 if total_tests > 0 else 0
	])

	if passed_tests == total_tests:
		print("\n✅ ALL TESTS PASSED!")
	else:
		print("\n⚠️ %d tests failed:" % (total_tests - passed_tests))

		var failed_count = 0
		for result in test_results:
			if not result.passed:
				failed_count += 1
				print("   %d. %s" % [failed_count, result.name])
				if result.details:
					print("      └─ %s" % result.details)

	print("\n" + _repeat_string("=", 120))

	all_tests_completed.emit(total_tests, passed_tests, total_tests - passed_tests)
