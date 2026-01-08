extends SceneTree

## Test mushroom farming vs wheat farming
## Compare yields, timing, and quest compatibility

const Farm = preload("res://Core/Farm.gd")
const QuestManager = preload("res://Core/Quests/QuestManager.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")

var farm: Farm
var quest_manager: QuestManager
var test_phase: int = 0

func _init():
	print("\n══════════════════════════════════════════════")
	print("🍄 MUSHROOM FARMING TEST")
	print("══════════════════════════════════════════════\n")

	_setup_game()
	# Note: Can't use await in _init(), so run tests immediately
	call_deferred("_run_tests")

func _setup_game():
	# Note: IconRegistry is automatically created by biome fallback if needed
	farm = Farm.new()
	root.add_child(farm)

	quest_manager = QuestManager.new()
	root.add_child(quest_manager)

	# Connect after adding to tree
	call_deferred("_connect_quest_manager")

func _connect_quest_manager():
	if farm and farm.economy and quest_manager:
		quest_manager.connect_to_economy(farm.economy)

func _run_tests():
	print("\n=== TEST 1: Can we plant mushrooms? ===")
	var starting_mushrooms = farm.economy.get_resource("🍄")
	print("Starting 🍄: %d" % starting_mushrooms)

	if starting_mushrooms < 10:
		print("❌ Not enough mushrooms to plant! (need 10, have %d)" % starting_mushrooms)
		print("💡 Setting mushrooms to 50 for testing...")
		farm.economy.add_resource("🍄", 50, "test_setup")

	var pos = Vector2i(0, 0)
	var success = farm.build(pos, "mushroom")

	if success:
		print("✅ Planted mushroom at %s" % pos)
		var plot = farm.grid.get_plot(pos)
		if plot and plot.is_planted:
			print("   Plot state: planted=%s, measured=%s" % [plot.is_planted, plot.has_been_measured])
			if plot.quantum_state:
				print("   Quantum state exists: energy=%.3f" % plot.quantum_state.energy)
		else:
			print("❌ Plot not planted correctly!")
	else:
		print("❌ Failed to plant mushroom!")

	print("\n=== TEST 2: Mushroom growth over time ===")
	print("Waiting 2 days (40 seconds)...")

	# Simulate 40 seconds of growth
	if farm.biotic_flux_biome:
		farm.biotic_flux_biome._process(40.0)

	var plot = farm.grid.get_plot(pos)
	if plot and plot.quantum_state:
		print("After 40s: energy=%.3f" % plot.quantum_state.energy)

	print("\n=== TEST 3: Measure mushroom ===")
	var outcome = farm.measure_plot(pos)
	if outcome:
		print("✅ Measured! Outcome: %s" % outcome)
	else:
		print("❌ Failed to measure!")

	print("\n=== TEST 4: Harvest mushroom ===")
	var before_mushroom = farm.economy.get_resource("🍄")
	var before_labor = farm.economy.get_resource("👥")

	var result = farm.harvest_plot(pos)

	var after_mushroom = farm.economy.get_resource("🍄")
	var after_labor = farm.economy.get_resource("👥")

	if result.get("success", false):
		print("✅ Harvested: %s" % result.get("outcome"))
		print("   Yield: %d credits" % result.get("yield", 0))
		print("   🍄: %d → %d (change: %+d)" % [before_mushroom, after_mushroom, after_mushroom - before_mushroom])
		print("   👥: %d → %d (change: %+d)" % [before_labor, after_labor, after_labor - before_labor])
	else:
		print("❌ Failed to harvest!")

	print("\n=== TEST 5: Quest compatibility ===")
	print("Generating 5 random quests to see resource distribution...")

	var resource_counts = {}
	for i in range(5):
		var faction = FactionDatabase.get_random_faction()
		var resources = farm.biotic_flux_biome.get_harvestable_emojis()
		var quest = quest_manager.offer_quest(faction, "BioticFlux", resources)

		if not quest.is_empty():
			var res = quest.get("resource", "")
			resource_counts[res] = resource_counts.get(res, 0) + 1
			print("  Quest %d: [%s] wants %d %s" % [i+1, quest.get("faction"), quest.get("quantity"), res])

	print("\nResource frequency:")
	for res in resource_counts.keys():
		print("  %s: %d/%d quests (%.0f%%)" % [res, resource_counts[res], 5, resource_counts[res] * 20.0])

	print("\n=== TEST COMPLETE ===")
	quit(0)
