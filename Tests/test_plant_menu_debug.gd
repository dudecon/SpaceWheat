extends SceneTree

## Debug test: Trace plant submenu generation for each biome

const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")

var farm = null
var input_handler = null
var test_frame = 0

func _init():
	print("\n" + "=".repeat(70))
	print("🔍 PLANT MENU DEBUG TEST")
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
		test_biome_lookup()
		return

	if test_frame == 15:
		test_menu_generation()
		return

	if test_frame == 20:
		finish_test()


func setup_test():
	print("=".repeat(70))
	print("SETUP: Creating input handler")
	print("=".repeat(70) + "\n")

	# Create input handler
	input_handler = FarmInputHandler.new()
	get_root().add_child(input_handler)
	input_handler.farm = farm
	input_handler.inject_grid_config(farm.grid_config)

	print("✅ Test setup complete\n")


func test_biome_lookup():
	print("=".repeat(70))
	print("TEST 1: Biome Lookup for Each Plot")
	print("=".repeat(70) + "\n")

	var test_positions = {
		Vector2i(5, 0): "BioticFlux",
		Vector2i(1, 0): "Market",
		Vector2i(1, 1): "Forest",
		Vector2i(5, 1): "Kitchen"
	}

	for pos in test_positions.keys():
		var expected_biome = test_positions[pos]
		var actual_biome = farm.grid.plot_biome_assignments.get(pos, "NONE")
		var match_status = "✅" if actual_biome == expected_biome else "❌"
		print("%s Plot %s: Expected '%s', Got '%s'" % [match_status, pos, expected_biome, actual_biome])

	print("")


func test_menu_generation():
	print("=".repeat(70))
	print("TEST 2: Dynamic Menu Generation")
	print("=".repeat(70) + "\n")

	var test_cases = [
		{"pos": Vector2i(5, 0), "biome": "BioticFlux", "expected_q": "plant_wheat"},
		{"pos": Vector2i(1, 0), "biome": "Market", "expected_q": "plant_wheat"},
		{"pos": Vector2i(1, 1), "biome": "Forest", "expected_q": "plant_vegetation"},
		{"pos": Vector2i(5, 1), "biome": "Kitchen", "expected_q": "plant_fire"}
	]

	for test in test_cases:
		var pos = test["pos"]
		var biome = test["biome"]
		var expected_q = test["expected_q"]

		print("📍 Testing %s plot at %s:" % [biome, pos])

		# Generate dynamic submenu for this position
		var submenu = ToolConfig.get_dynamic_submenu("plant", farm, pos)

		print("   Menu name: %s" % submenu.get("name", "MISSING"))
		print("   Q action: %s" % submenu.get("Q", {}).get("action", "MISSING"))
		print("   Q label: %s" % submenu.get("Q", {}).get("label", "MISSING"))
		print("   Q emoji: %s" % submenu.get("Q", {}).get("emoji", "MISSING"))

		var actual_q = submenu.get("Q", {}).get("action", "MISSING")
		var match = "✅" if actual_q == expected_q else "❌"
		print("   %s Expected action '%s', got '%s'\n" % [match, expected_q, actual_q])


func finish_test():
	print("=".repeat(70))
	print("✅ PLANT MENU DEBUG TEST COMPLETE")
	print("=".repeat(70))
	print("\nRECOMMENDATION:")
	print("If biome lookup shows ❌ NONE, the plot_biome_assignments aren't set correctly")
	print("If menu generation shows wrong actions, the _generate_plant_submenu() logic has a bug")
	print("")
	quit()
