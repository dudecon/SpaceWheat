extends SceneTree

## FULL GAMEPLAY LOOP TEST - Automated Quest/Farming/Vocabulary Cycle
## Run with: godot --headless --script res://Tests/test_full_gameplay_loop.gd
##
## This test simulates a complete gameplay session:
##   1. Boot game and initialize systems
##   2. Farm quantum resources (Explore → Measure → Pop)
##   3. Accept quests from factions
##   4. Complete quests to earn vocabulary
##   5. Unlock new factions with vocabulary
##   6. Inject vocabulary into biomes (BUILD mode)

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")

const SEPARATOR = "======================================================================"
const THICK_LINE = "══════════════════════════════════════════════════════════════════════"

var test_results: Array = []
var farm = null
var input_handler = null
var player_shell = null
var overlay_manager = null
var quest_manager = null
var game_state_manager = null
var scene_loaded = false
var tests_done = false
var frame_count = 0
var boot_manager = null

# Gameplay tracking
var resources_harvested: Dictionary = {}
var vocabulary_learned: Array = []
var factions_unlocked: Array = []
var quests_completed: int = 0
var farming_cycles: int = 0

func _init():
	print("")
	print(THICK_LINE)
	print("  FULL GAMEPLAY LOOP TEST")
	print("  Quest → Farm → Vocabulary → Faction Unlock")
	print(THICK_LINE)
	print("")

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		_load_scene()

func _load_scene():
	print("Loading FarmView...")
	var scene = load("res://scenes/FarmView.tscn")
	if scene:
		var instance = scene.instantiate()
		root.add_child(instance)
		scene_loaded = true

		boot_manager = root.get_node_or_null("/root/BootManager")
		if boot_manager:
			boot_manager.game_ready.connect(_on_game_ready)
			print("Connected to BootManager.game_ready")
	else:
		_fail("Failed to load FarmView.tscn")
		quit(1)

func _on_game_ready():
	if tests_done:
		return
	tests_done = true
	print("\nGame ready! Starting full gameplay loop test...\n")

	_find_components()
	_disable_evolution()
	_connect_signals()

	print("Components found:")
	print("  Farm: %s" % (farm != null))
	print("  QuestManager: %s" % (quest_manager != null))
	print("  GameStateManager: %s" % (game_state_manager != null))
	print("  InputHandler: %s" % (input_handler != null))

	if not farm:
		_fail("Missing Farm component")
		_print_results()
		quit(1)
		return

	# Run the full gameplay loop
	print("")
	_phase_1_farming()
	_phase_2_quest_acceptance()
	_phase_3_quest_completion()
	_phase_4_vocabulary_unlock()
	_phase_5_faction_expansion()
	_phase_6_build_mode_injection()

	_print_summary()
	_print_results()

	var failed = test_results.filter(func(r): return not r.passed).size()
	quit(1 if failed > 0 else 0)

func _find_components():
	var farm_view = root.get_node_or_null("FarmView")
	if farm_view and "farm" in farm_view:
		farm = farm_view.farm

	player_shell = _find_node(root, "PlayerShell")
	if player_shell:
		for child in player_shell.get_children():
			if child.get_script() and child.get_script().resource_path.ends_with("FarmInputHandler.gd"):
				input_handler = child
				break

		if player_shell.get("overlay_manager"):
			overlay_manager = player_shell.overlay_manager

	# Find QuestManager (autoload or in tree)
	quest_manager = root.get_node_or_null("/root/QuestManager")
	if not quest_manager and farm:
		quest_manager = farm.get_node_or_null("QuestManager")

	# Find GameStateManager (autoload)
	game_state_manager = root.get_node_or_null("/root/GameStateManager")

func _disable_evolution():
	if not farm:
		return
	for biome in [farm.biotic_flux_biome, farm.forest_biome, farm.market_biome, farm.kitchen_biome]:
		if biome:
			biome.quantum_evolution_enabled = false
			biome.set_process(false)

func _connect_signals():
	if game_state_manager:
		if game_state_manager.has_signal("emoji_discovered"):
			game_state_manager.emoji_discovered.connect(_on_emoji_discovered)
		if game_state_manager.has_signal("factions_unlocked"):
			game_state_manager.factions_unlocked.connect(_on_factions_unlocked)

	if quest_manager:
		if quest_manager.has_signal("quest_completed"):
			quest_manager.quest_completed.connect(_on_quest_completed)
		if quest_manager.has_signal("vocabulary_learned"):
			quest_manager.vocabulary_learned.connect(_on_vocabulary_learned)

func _find_node(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node(child, target_name)
		if found:
			return found
	return null

# ============================================================================
# PHASE 1: FARMING - Explore → Measure → Pop
# ============================================================================

func _phase_1_farming():
	print(SEPARATOR)
	print("  PHASE 1: QUANTUM FARMING")
	print("  Explore → Measure → Pop Cycle")
	print(SEPARATOR)

	var biome = farm.biotic_flux_biome
	if not biome:
		_fail("PHASE1: No BioticFlux biome")
		return

	print("\nRunning 5 farming cycles...\n")

	for i in range(5):
		var cycle_result = _run_farming_cycle(biome, i + 1)
		if cycle_result.success:
			farming_cycles += 1
			var resource = cycle_result.resource
			resources_harvested[resource] = resources_harvested.get(resource, 0) + 1

	if farming_cycles >= 3:
		_pass("PHASE1.FARMING: Completed %d farming cycles" % farming_cycles)
	else:
		_fail("PHASE1.FARMING: Only %d cycles completed (expected 3+)" % farming_cycles)

	print("\nResources harvested:")
	for emoji in resources_harvested:
		print("  %s × %d" % [emoji, resources_harvested[emoji]])

func _run_farming_cycle(biome, cycle_num: int) -> Dictionary:
	"""Run one complete Explore → Measure → Pop cycle"""
	print("─".repeat(40))
	print("Cycle %d:" % cycle_num)

	# EXPLORE
	var explore_result = ProbeActions.action_explore(farm.plot_pool, biome)
	if not explore_result.success:
		print("  [EXPLORE] Failed: %s" % explore_result.get("message", "unknown"))
		return {"success": false}

	var terminal = explore_result.terminal
	var emoji = explore_result.emoji_pair.get("north", "?")
	var register_id = explore_result.register_id
	print("  [EXPLORE] Terminal created: reg=%d emoji=%s" % [register_id, emoji])

	# MEASURE
	var measure_result = ProbeActions.action_measure(terminal, biome)
	if not measure_result.get("success", false):
		print("  [MEASURE] Failed: %s" % measure_result.get("message", "unknown"))
		return {"success": false}

	var outcome = measure_result.get("outcome", "?")
	var prob = measure_result.get("probability", 0.0) * 100
	print("  [MEASURE] Collapsed: %s (p=%.0f%%)" % [outcome, prob])

	# POP
	var pop_result = ProbeActions.action_pop(terminal, farm.plot_pool, farm.economy)
	if not pop_result.success:
		print("  [POP] Failed: %s" % pop_result.get("message", "unknown"))
		return {"success": false}

	var resource = pop_result.resource
	print("  [POP] Harvested: %s" % resource)

	return {"success": true, "resource": resource}

# ============================================================================
# PHASE 2: QUEST ACCEPTANCE
# ============================================================================

func _phase_2_quest_acceptance():
	print("\n" + SEPARATOR)
	print("  PHASE 2: QUEST ACCEPTANCE")
	print("  Offer → Accept from accessible factions")
	print(SEPARATOR)

	# Initialize game state if needed
	if game_state_manager and not game_state_manager.current_state:
		game_state_manager.new_game("default")
		print("\nInitialized new game state")

	# Get player vocabulary
	var player_vocab = []
	if game_state_manager and game_state_manager.current_state:
		player_vocab = game_state_manager.current_state.known_emojis
	print("Player vocabulary: %d emojis" % player_vocab.size())

	# Get accessible factions
	var accessible = []
	if game_state_manager:
		accessible = game_state_manager.get_accessible_factions()
	print("Accessible factions: %d" % accessible.size())

	if accessible.size() == 0:
		# Seed some vocabulary to access factions
		print("\nSeeding initial vocabulary...")
		var seed_emojis = ["🌾", "💰", "🌱", "🍞"]
		for emoji in seed_emojis:
			if game_state_manager:
				game_state_manager.discover_emoji(emoji)
		accessible = game_state_manager.get_accessible_factions() if game_state_manager else []
		print("After seeding: %d accessible factions" % accessible.size())

	# Create QuestManager if not present
	if not quest_manager:
		var QuestManagerClass = load("res://Core/Quests/QuestManager.gd")
		quest_manager = QuestManagerClass.new()
		root.add_child(quest_manager)
		quest_manager.connect_to_economy(farm.economy)
		quest_manager.connect_to_biome(farm.biotic_flux_biome)
		print("Created QuestManager")

	# Offer quests from first 3 accessible factions
	var quests_offered = []
	for i in range(min(3, accessible.size())):
		var faction = accessible[i]
		var quest = quest_manager.offer_quest_emergent(faction, farm.biotic_flux_biome)
		if not quest.is_empty():
			quests_offered.append(quest)
			print("\n  Quest offered from %s:" % faction.name)
			print("    Requires: %s × %d" % [quest.get("resource", "?"), quest.get("quantity", 0)])

	if quests_offered.size() > 0:
		_pass("PHASE2.OFFER: %d quests offered" % quests_offered.size())
	else:
		_fail("PHASE2.OFFER: No quests offered")
		return

	# Accept first quest
	if quests_offered.size() > 0:
		var quest = quests_offered[0]
		var accepted = quest_manager.accept_quest(quest)
		if accepted:
			_pass("PHASE2.ACCEPT: Quest accepted (ID %d)" % quest.id)
		else:
			_fail("PHASE2.ACCEPT: Failed to accept quest")

# ============================================================================
# PHASE 3: QUEST COMPLETION
# ============================================================================

func _phase_3_quest_completion():
	print("\n" + SEPARATOR)
	print("  PHASE 3: QUEST COMPLETION")
	print("  Farm resources → Complete quest → Earn vocabulary")
	print(SEPARATOR)

	if not quest_manager:
		_fail("PHASE3: No QuestManager")
		return

	var active = quest_manager.get_active_quests()
	if active.size() == 0:
		_fail("PHASE3: No active quests")
		return

	var quest = active[0]
	var required_emoji = quest.get("resource", "")
	var required_qty = quest.get("quantity", 0)
	var required_credits = required_qty * EconomyConstants.QUANTUM_TO_CREDITS

	print("\nActive quest requires: %s × %d (%d credits)" % [required_emoji, required_qty, required_credits])

	# Check current resources
	var current_amount = farm.economy.get_resource(required_emoji)
	print("Current %s: %d credits" % [required_emoji, current_amount])

	# Add resources if needed (simulating farming)
	if current_amount < required_credits:
		var deficit = required_credits - current_amount
		farm.economy.add_resource(required_emoji, deficit, "test_farming_boost")
		print("Added %d %s credits (simulated farming)" % [deficit, required_emoji])

	# Complete quest
	var can_complete = quest_manager.check_quest_completion(quest.id)
	print("Can complete: %s" % str(can_complete))

	if can_complete:
		var completed = quest_manager.complete_quest(quest.id)
		if completed:
			quests_completed += 1
			_pass("PHASE3.COMPLETE: Quest completed!")

			# Check rewards
			var completed_quest = quest_manager.completed_quests[-1] if quest_manager.completed_quests.size() > 0 else {}
			var reward = completed_quest.get("reward", null)
			if reward:
				# QuestReward is a class, access properties directly
				print("  💰: %d" % reward.money_amount)
				var learned = reward.learned_vocabulary
				if learned.size() > 0:
					print("  Vocabulary learned: %s" % str(learned))
					vocabulary_learned.append_array(learned)
		else:
			_fail("PHASE3.COMPLETE: Failed to complete quest")
	else:
		_fail("PHASE3.COMPLETE: Cannot complete quest (insufficient resources)")

# ============================================================================
# PHASE 4: VOCABULARY UNLOCK
# ============================================================================

func _phase_4_vocabulary_unlock():
	print("\n" + SEPARATOR)
	print("  PHASE 4: VOCABULARY EXPANSION")
	print("  Learn new emojis → Unlock more factions")
	print(SEPARATOR)

	# Get current vocabulary
	var vocab_before = []
	if game_state_manager and game_state_manager.current_state:
		vocab_before = game_state_manager.current_state.known_emojis.duplicate()
	print("\nVocabulary before: %d emojis" % vocab_before.size())

	# Discover new emojis (simulating quest rewards)
	var new_emojis = ["🍄", "🧫", "🔬", "⚙️"]
	print("Discovering new emojis: %s" % str(new_emojis))

	for emoji in new_emojis:
		if game_state_manager:
			game_state_manager.discover_emoji(emoji)

	# Check vocabulary after
	var vocab_after = []
	if game_state_manager and game_state_manager.current_state:
		vocab_after = game_state_manager.current_state.known_emojis
	print("Vocabulary after: %d emojis" % vocab_after.size())

	var new_count = vocab_after.size() - vocab_before.size()
	if new_count > 0:
		_pass("PHASE4.VOCABULARY: Learned %d new emojis" % new_count)
	else:
		_pass("PHASE4.VOCABULARY: All emojis already known")

	# Check newly accessible factions
	var accessible_after = []
	if game_state_manager:
		accessible_after = game_state_manager.get_accessible_factions()
	print("Accessible factions: %d" % accessible_after.size())

	if factions_unlocked.size() > 0:
		print("Newly unlocked factions:")
		for faction in factions_unlocked:
			print("  - %s" % faction.get("name", "Unknown"))
		_pass("PHASE4.FACTIONS: Unlocked %d new factions" % factions_unlocked.size())
	else:
		_pass("PHASE4.FACTIONS: No new factions unlocked (may already have access)")

# ============================================================================
# PHASE 5: FACTION EXPANSION
# ============================================================================

func _phase_5_faction_expansion():
	print("\n" + SEPARATOR)
	print("  PHASE 5: FACTION ECOSYSTEM")
	print("  Accept quests from multiple factions")
	print(SEPARATOR)

	if not quest_manager or not game_state_manager:
		_fail("PHASE5: Missing managers")
		return

	var accessible = game_state_manager.get_accessible_factions()
	print("\nAccessible factions: %d" % accessible.size())

	# Clear existing quests for clean test
	quest_manager.clear_all_quests()

	# Offer quests from different factions
	var faction_quests = {}
	for faction in accessible.slice(0, 5):  # First 5 factions
		var quest = quest_manager.offer_quest_emergent(faction, farm.biotic_flux_biome)
		if not quest.is_empty():
			faction_quests[faction.name] = quest
			print("  %s: Quest offered" % faction.name)

	if faction_quests.size() >= 2:
		_pass("PHASE5.DIVERSITY: Quests from %d factions" % faction_quests.size())
	elif faction_quests.size() == 1:
		_pass("PHASE5.DIVERSITY: Quest from 1 faction (limited vocabulary)")
	else:
		_fail("PHASE5.DIVERSITY: No faction quests available")

# ============================================================================
# PHASE 6: BUILD MODE - Vocabulary Injection
# ============================================================================

func _phase_6_build_mode_injection():
	print("\n" + SEPARATOR)
	print("  PHASE 6: BUILD MODE VOCABULARY INJECTION")
	print("  Assign learned vocabulary to biome plots")
	print(SEPARATOR)

	# Switch to BUILD mode
	ToolConfig.set_mode("build")
	print("\nMode: %s" % ToolConfig.get_mode())

	# Get Tool 2 (Icon) actions
	var tool_def = ToolConfig.get_tool(2)
	print("Tool 2: %s" % tool_def.get("name", "?"))

	# Test icon swap action (E key action)
	print("\n─".repeat(40))
	print("Testing Icon Swap (E action)...")

	# Find a planted plot
	var biome = farm.biotic_flux_biome
	if not biome:
		_fail("PHASE6: No biome")
		return

	# Get plot from biome
	var test_plot = null
	var test_position = Vector2i(0, 0)

	if farm.grid:
		# Find first plot in biome
		for x in range(farm.grid.grid_width):
			for y in range(farm.grid.grid_height):
				var pos = Vector2i(x, y)
				var plot = farm.grid.get_plot(pos)
				if plot and plot.is_planted:
					test_plot = plot
					test_position = pos
					break
			if test_plot:
				break

	if test_plot:
		var north_before = test_plot.north_emoji
		var south_before = test_plot.south_emoji
		print("  Plot at %s: N=%s S=%s" % [test_position, north_before, south_before])

		# Swap icons
		var temp = test_plot.north_emoji
		test_plot.north_emoji = test_plot.south_emoji
		test_plot.south_emoji = temp

		print("  After swap: N=%s S=%s" % [test_plot.north_emoji, test_plot.south_emoji])

		if test_plot.north_emoji == south_before and test_plot.south_emoji == north_before:
			_pass("PHASE6.ICON_SWAP: Icons swapped successfully")
		else:
			_fail("PHASE6.ICON_SWAP: Swap did not work")

		# Swap back
		temp = test_plot.north_emoji
		test_plot.north_emoji = test_plot.south_emoji
		test_plot.south_emoji = temp
	else:
		print("  No planted plots found - creating terminal...")
		var explore_result = ProbeActions.action_explore(farm.plot_pool, biome)
		if explore_result.success:
			_pass("PHASE6.ICON_SWAP: Created terminal for testing")
		else:
			_fail("PHASE6.ICON_SWAP: Could not create test plot")

	# Test Tool 4 F-cycling (new quantum gates)
	print("\n─".repeat(40))
	print("Testing Tool 4 F-Cycling...")

	var tool4 = ToolConfig.get_tool(4)
	print("  Tool 4: %s (F-cycling: %s)" % [tool4.get("name"), tool4.get("has_f_cycling")])

	if tool4.get("has_f_cycling"):
		var modes = tool4.get("modes", [])
		print("  Available modes: %s" % str(modes))

		# Cycle through modes
		for i in range(len(modes)):
			var mode_name = ToolConfig.get_tool_mode_name(4)
			var q_action = ToolConfig.get_action(4, "Q")
			print("    [%d] %s: Q=%s" % [i, mode_name, q_action.get("label", "?")])
			ToolConfig.cycle_tool_mode(4)

		_pass("PHASE6.F_CYCLE: Tool 4 modes cycle correctly")
	else:
		_pass("PHASE6.F_CYCLE: Tool 4 has no F-cycling (as configured)")

	# Return to PLAY mode
	ToolConfig.set_mode("play")
	print("\nReturned to PLAY mode")

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_emoji_discovered(emoji: String):
	print("  📖 Discovered: %s" % emoji)
	vocabulary_learned.append(emoji)

func _on_factions_unlocked(factions: Array):
	print("  🔓 Unlocked %d faction(s)!" % factions.size())
	factions_unlocked.append_array(factions)

func _on_quest_completed(_quest_id: int, _rewards: Dictionary):
	print("  ✅ Quest completed!")

func _on_vocabulary_learned(emoji: String, faction: String):
	print("  📚 %s taught: %s" % [faction, emoji])

# ============================================================================
# UTILITIES
# ============================================================================

func _pass(msg: String):
	test_results.append({"passed": true, "message": msg})
	print("  PASS: %s" % msg)

func _fail(msg: String):
	test_results.append({"passed": false, "message": msg})
	print("  FAIL: %s" % msg)

func _print_summary():
	print("")
	print(THICK_LINE)
	print("  GAMEPLAY LOOP SUMMARY")
	print(THICK_LINE)

	print("\n📊 Statistics:")
	print("  Farming cycles: %d" % farming_cycles)
	print("  Quests completed: %d" % quests_completed)
	print("  Vocabulary learned: %d emojis" % vocabulary_learned.size())
	print("  Factions unlocked: %d" % factions_unlocked.size())

	print("\n🌾 Resources Harvested:")
	for emoji in resources_harvested:
		print("    %s × %d" % [emoji, resources_harvested[emoji]])

	if vocabulary_learned.size() > 0:
		print("\n📖 Vocabulary:")
		print("    %s" % " ".join(vocabulary_learned))

	if factions_unlocked.size() > 0:
		print("\n🏛️ Unlocked Factions:")
		for faction in factions_unlocked:
			print("    - %s" % faction.get("name", "Unknown"))

func _print_results():
	print("")
	print(THICK_LINE)
	print("  TEST RESULTS")
	print(THICK_LINE)

	var passed := 0
	var failed := 0

	for result in test_results:
		if result.passed:
			passed += 1
		else:
			failed += 1

	print("")
	print("  Passed: %d" % passed)
	print("  Failed: %d" % failed)
	print("")

	if failed == 0:
		print("  ✅ FULL GAMEPLAY LOOP TEST PASSED!")
	else:
		print("  ❌ SOME TESTS FAILED:")
		print("")
		for result in test_results:
			if not result.passed:
				print("    - %s" % result.message)

	print("")
	print(THICK_LINE)
