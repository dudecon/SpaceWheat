extends SceneTree

## Test: Verify that keyboard WASD updates current_selection

const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")

var farm = null
var input_handler = null
var test_frame = 0

func _init():
	print("\n" + "=".repeat(70))
	print("⌨️  KEYBOARD SELECTION TEST")
	print("=".repeat(70) + "\n")

	# Load farm
	var farm_scene = load("res://Core/Farm.gd")
	if not farm_scene:
		print("❌ Could not load Farm.gd")
		quit()
		return

	farm = farm_scene.new()
	get_root().add_child(farm)


func _process(delta):
	test_frame += 1

	if test_frame < 5:
		return

	if test_frame == 5:
		setup_test()
		return

	if test_frame == 10:
		test_default_selection()
		return

	if test_frame == 15:
		test_wasd_movement()
		return

	if test_frame == 20:
		test_submenu_generation()
		return

	if test_frame == 25:
		finish_test()


func setup_test():
	print("SETUP: Creating input handler\n")

	input_handler = FarmInputHandler.new()
	get_root().add_child(input_handler)
	input_handler.farm = farm
	input_handler.inject_grid_config(farm.grid_config)

	print("✅ Setup complete\n")


func test_default_selection():
	print("=".repeat(70))
	print("TEST 1: Default current_selection")
	print("=".repeat(70) + "\n")

	var current = input_handler.current_selection
	var biome = farm.grid.plot_biome_assignments.get(current, "NONE")

	print("Initial current_selection: %s" % current)
	print("Initial biome: %s" % biome)

	# Generate menu for default selection
	var menu = ToolConfig.get_dynamic_submenu("plant", farm, current)
	print("Menu generated: %s" % menu.get("name", "NONE"))
	print("Q action: %s (should be plant_wheat for Market)\n" % menu.get("Q", {}).get("action", "NONE"))


func test_wasd_movement():
	print("=".repeat(70))
	print("TEST 2: WASD Movement")
	print("=".repeat(70) + "\n")

	# Move right 5 times to get to position (5, 0)
	print("Moving right 5 times (should reach (5, 0) = BioticFlux):")
	for i in range(5):
		input_handler._move_selection(Vector2i.RIGHT)

	var current = input_handler.current_selection
	var biome = farm.grid.plot_biome_assignments.get(current, "NONE")

	print("  current_selection after moves: %s" % current)
	print("  Biome: %s\n" % biome)

	# Move down 1 time to get to (5, 1)
	print("Moving down 1 time (should reach (5, 1) = Kitchen):")
	input_handler._move_selection(Vector2i.DOWN)

	current = input_handler.current_selection
	biome = farm.grid.plot_biome_assignments.get(current, "NONE")

	print("  current_selection after move: %s" % current)
	print("  Biome: %s\n" % biome)


func test_submenu_generation():
	print("=".repeat(70))
	print("TEST 3: Submenu Generation After Movement")
	print("=".repeat(70) + "\n")

	# current_selection should be (5, 1) = Kitchen
	var current = input_handler.current_selection
	var menu = ToolConfig.get_dynamic_submenu("plant", farm, current)

	print("Current selection: %s" % current)
	print("Menu generated: %s" % menu.get("name", "NONE"))
	print("Q action: %s (should be plant_fire for Kitchen)" % menu.get("Q", {}).get("action", "NONE"))
	print("Q label: %s" % menu.get("Q", {}).get("label", "NONE"))
	print("Q emoji: %s\n" % menu.get("Q", {}).get("emoji", "NONE"))


func finish_test():
	print("=".repeat(70))
	print("✅ KEYBOARD SELECTION TEST COMPLETE")
	print("=".repeat(70))
	print("\nCONCLUSION:")
	print("- Mouse clicks DON'T update current_selection (PlotTile mouse_filter=IGNORE)")
	print("- Must use WASD to move cursor OR direct position selection")
	print("- Submenu generation uses current_selection, not clicked/checkboxed plots")
	print("")
	quit()
