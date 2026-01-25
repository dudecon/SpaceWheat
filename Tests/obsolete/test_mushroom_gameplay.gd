extends SceneTree

## Simple mushroom economy gameplay test
## No manual time simulation - just test the mechanics

const Farm = preload("res://Core/Farm.gd")

var farm: Farm

func _ready():
	print("\n" + "═".repeat(80))
	print("🍄 MUSHROOM ECONOMY GAMEPLAY TEST")
	print("═".repeat(80) + "\n")

	farm = Farm.new()
	add_child(farm)
	await get_tree().create_timer(0.5).timeout

	print("📊 Initial state:")
	_print_resources()
	print("")

	# Test 1: Forest harvest
	print("─".repeat(80))
	print("TEST 1: FOREST HARVEST")
	print("─".repeat(80))
	test_forest_harvest()
	print("")

	# Test 2: Mushroom planting
	print("─".repeat(80))
	print("TEST 2: MUSHROOM PLANTING")
	print("─".repeat(80))
	test_mushroom_planting()
	print("")

	# Test 3: Composting
	print("─".repeat(80))
	print("TEST 3: PASSIVE COMPOSTING")
	print("─".repeat(80))
	await test_composting()

	print("\n" + "═".repeat(80))
	print("✅ ALL TESTS COMPLETE")
	print("═".repeat(80) + "\n")

	get_tree().quit()

func test_forest_harvest():
	var detritus_before = farm.economy.get_resource("🍂")
	print("🌲 Gathering from Forest plot F (3,1)...")

	var forest_pos = Vector2i(3, 1)
	var success = farm.build(forest_pos, "forest_harvest")

	if success:
		var detritus_after = farm.economy.get_resource("🍂")
		var gained = detritus_after - detritus_before
		print("   ✅ Gathered %d detritus credits!" % gained)
	else:
		print("   ❌ Failed to gather from forest")

	_print_resources()

func test_mushroom_planting():
	var mushroom_before = farm.economy.get_resource("🍄")
	var detritus_before = farm.economy.get_resource("🍂")

	print("🍄 Planting mushroom at plot T (2,0)...")
	print("   Costs: 1 🍄 + 1 🍂")

	if mushroom_before < 10:
		print("   ⚠️  Not enough mushrooms! Have %d, need 10" % mushroom_before)
		return

	if detritus_before < 10:
		print("   ⚠️  Not enough detritus! Have %d, need 10" % detritus_before)
		return

	var plot_pos = Vector2i(2, 0)
	var success = farm.build(plot_pos, "mushroom")

	if success:
		var mushroom_after = farm.economy.get_resource("🍄")
		var detritus_after = farm.economy.get_resource("🍂")
		var spent_m = mushroom_before - mushroom_after
		var spent_d = detritus_before - detritus_after

		print("   ✅ Planted!")
		print("   Spent: %d 🍄, %d 🍂" % [spent_m, spent_d])

		var plot = farm.grid.get_plot(plot_pos)
		if plot and plot.is_planted:
			print("   ✓ Plot is planted")
			if plot.quantum_state:
				print("   ✓ Quantum state created: %s ↔ %s" % [plot.quantum_state.north_emoji, plot.quantum_state.south_emoji])
	else:
		print("   ❌ Failed to plant mushroom")

	_print_resources()

func test_composting():
	print("🍂→🍄 Testing passive composting system...")

	# Plant a mushroom to activate composting
	var plot_pos = Vector2i(1, 0)
	var plot = farm.grid.get_plot(plot_pos)

	if not plot or plot.is_planted:
		print("   Using existing planted mushroom")
	else:
		print("   Planting mushroom to activate composting...")
		farm.build(plot_pos, "mushroom")

	# Add extra detritus to see composting clearly
	farm.economy.add_resource("🍂", 100, "test")

	var mushroom_before = farm.economy.get_resource("🍄")
	var detritus_before = farm.economy.get_resource("🍂")
	print("   Before: 🍄 %d  🍂 %d" % [mushroom_before, detritus_before])

	print("   ⏰ Waiting 10 seconds for passive composting...")

	# Use actual game timer instead of manual simulation
	await get_tree().create_timer(10.0).timeout

	var mushroom_after = farm.economy.get_resource("🍄")
	var detritus_after = farm.economy.get_resource("🍂")
	var gained_m = mushroom_after - mushroom_before
	var lost_d = detritus_before - detritus_after

	print("   After:  🍄 %d  🍂 %d" % [mushroom_after, detritus_after])
	print("   Change: 🍄 +%d  🍂 -%d" % [gained_m, lost_d])

	if gained_m > 0:
		var ratio = float(lost_d) / float(gained_m) if gained_m > 0 else 0.0
		print("   ✅ Composting worked! Ratio: %.1f:1 (expected 2:1)" % ratio)
	else:
		print("   ⚠️  No composting occurred")

	_print_resources()

func _print_resources():
	print("   Resources: 🌾 %d  🍄 %d  🍂 %d" % [
		farm.economy.get_resource("🌾"),
		farm.economy.get_resource("🍄"),
		farm.economy.get_resource("🍂")
	])
