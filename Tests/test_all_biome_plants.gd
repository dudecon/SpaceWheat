extends SceneTree

## Test all biome-specific planting + plot inspection

const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")

var farm = null
var input_handler = null
var test_frame = 0

func _init():
	print("\n" + "=".repeat(70))
	print("🧪 ALL BIOME PLANTS TEST")
	print("=".repeat(70) + "\n")

	# Load farm
	var farm_scene = load("res://Core/Farm.gd")
	if not farm_scene:
		print("❌ FAILED: Could not load Farm.gd")
		quit()
		return

	farm = farm_scene.new()
	get_root().add_child(farm)

	print("⏳ Waiting for farm initialization...\n")


func _process(delta):
	test_frame += 1

	if test_frame < 5:
		return

	if test_frame == 5:
		setup_test()
		return

	if test_frame == 10:
		test_bioticflux_plants()
		return

	if test_frame == 15:
		test_forest_plants()
		return

	if test_frame == 20:
		test_market_plants()
		return

	if test_frame == 25:
		test_kitchen_plants()
		return

	if test_frame == 30:
		inspect_all_plots()
		return

	if test_frame == 35:
		finish_test()


func setup_test():
	print("=".repeat(70))
	print("SETUP: Creating test economy")
	print("=".repeat(70) + "\n")

	# Give economy resources for all plant types
	farm.economy.add_resource("🌾", 1000, "test")  # Wheat
	farm.economy.add_resource("🍄", 1000, "test")  # Mushroom
	farm.economy.add_resource("🍅", 1000, "test")  # Tomato (costs wheat but we have plenty)
	farm.economy.add_resource("🌿", 1000, "test")  # Vegetation
	farm.economy.add_resource("🐇", 1000, "test")  # Rabbit
	farm.economy.add_resource("🐺", 1000, "test")  # Wolf
	farm.economy.add_resource("💨", 1000, "test")  # Flour
	farm.economy.add_resource("🍞", 1000, "test")  # Bread
	farm.economy.add_resource("🔥", 1000, "test")  # Fire
	farm.economy.add_resource("💧", 1000, "test")  # Water

	# Create input handler
	input_handler = FarmInputHandler.new()
	get_root().add_child(input_handler)
	input_handler.farm = farm
	input_handler.inject_grid_config(farm.grid_config)

	print("✅ Test setup complete\n")


func test_bioticflux_plants():
	print("=".repeat(70))
	print("TEST 1: BioticFlux Plants (plot 3,0 / 4,0 / 5,0)")
	print("=".repeat(70) + "\n")

	# Plant wheat at (3,0)
	print("🌾 Planting wheat at BioticFlux plot (3,0)...")
	var result1 = farm.build(Vector2i(3, 0), "wheat")
	print("   Result: %s\n" % ("✅ SUCCESS" if result1 else "❌ FAILED"))

	# Plant mushroom at (4,0)
	print("🍄 Planting mushroom at BioticFlux plot (4,0)...")
	var result2 = farm.build(Vector2i(4, 0), "mushroom")
	print("   Result: %s\n" % ("✅ SUCCESS" if result2 else "❌ FAILED"))

	# Plant tomato at (5,0)
	print("🍅 Planting tomato at BioticFlux plot (5,0)...")
	var result3 = farm.build(Vector2i(5, 0), "tomato")
	print("   Result: %s\n" % ("✅ SUCCESS" if result3 else "❌ FAILED"))


func test_forest_plants():
	print("=".repeat(70))
	print("TEST 2: Forest Plants (plot 0,1 / 1,1 / 2,1)")
	print("=".repeat(70) + "\n")

	# Plant vegetation at (0,1)
	print("🌿 Planting vegetation at Forest plot (0,1)...")
	var result1 = farm.build(Vector2i(0, 1), "vegetation")
	print("   Result: %s\n" % ("✅ SUCCESS" if result1 else "❌ FAILED"))

	# Plant rabbit at (1,1)
	print("🐇 Planting rabbit at Forest plot (1,1)...")
	var result2 = farm.build(Vector2i(1, 1), "rabbit")
	print("   Result: %s\n" % ("✅ SUCCESS" if result2 else "❌ FAILED"))

	# Plant wolf at (2,1)
	print("🐺 Planting wolf at Forest plot (2,1)...")
	var result3 = farm.build(Vector2i(2, 1), "wolf")
	print("   Result: %s\n" % ("✅ SUCCESS" if result3 else "❌ FAILED"))


func test_market_plants():
	print("=".repeat(70))
	print("TEST 3: Market Plants (plot 0,0 / 1,0 / 2,0)")
	print("=".repeat(70) + "\n")

	# Plant wheat at (0,0)
	print("🌾 Planting wheat at Market plot (0,0)...")
	var result1 = farm.build(Vector2i(0, 0), "wheat")
	print("   Result: %s\n" % ("✅ SUCCESS" if result1 else "❌ FAILED"))

	# Plant flour at (1,0)
	print("💨 Planting flour at Market plot (1,0)...")
	var result2 = farm.build(Vector2i(1, 0), "flour")
	print("   Result: %s\n" % ("✅ SUCCESS" if result2 else "❌ FAILED"))

	# Plant bread at (2,0)
	print("🍞 Planting bread at Market plot (2,0)...")
	var result3 = farm.build(Vector2i(2, 0), "bread")
	print("   Result: %s\n" % ("✅ SUCCESS" if result3 else "❌ FAILED"))


func test_kitchen_plants():
	print("=".repeat(70))
	print("TEST 4: Kitchen Plants (plot 3,1 / 4,1 / 5,1)")
	print("=".repeat(70) + "\n")

	# Plant fire at (3,1)
	print("🔥 Planting fire at Kitchen plot (3,1)...")
	var result1 = farm.build(Vector2i(3, 1), "fire")
	print("   Result: %s\n" % ("✅ SUCCESS" if result1 else "❌ FAILED"))

	# Plant water at (4,1)
	print("💧 Planting water at Kitchen plot (4,1)...")
	var result2 = farm.build(Vector2i(4, 1), "water")
	print("   Result: %s\n" % ("✅ SUCCESS" if result2 else "❌ FAILED"))

	# Plant flour at (5,1)
	print("💨 Planting flour at Kitchen plot (5,1)...")
	var result3 = farm.build(Vector2i(5, 1), "flour")
	print("   Result: %s\n" % ("✅ SUCCESS" if result3 else "❌ FAILED"))


func inspect_all_plots():
	print("=".repeat(70))
	print("INSPECTION: All planted plots")
	print("=".repeat(70) + "\n")

	var test_positions: Array[Vector2i] = [
		Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0),  # BioticFlux
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),  # Forest
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),  # Market
		Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)   # Kitchen
	]

	# Use FarmInputHandler's inspect action
	input_handler._action_inspect_plot(test_positions)


func finish_test():
	print("\n" + "=".repeat(70))
	print("✅ ALL BIOME PLANTS TEST COMPLETE")
	print("=".repeat(70))
	quit()
