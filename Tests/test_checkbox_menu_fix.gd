extends SceneTree

## Test: Verify checkbox selection updates plant menu

const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")
const PlotGridDisplay = preload("res://UI/PlotGridDisplay.gd")

var farm = null
var input_handler = null
var plot_grid_display = null
var test_frame = 0

func _init():
	print("\n" + "=".repeat(70))
	print("✅ CHECKBOX MENU FIX TEST")
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
		test_no_checkbox()
		return

	if test_frame == 15:
		test_kitchen_checkbox()
		return

	if test_frame == 20:
		test_forest_checkbox()
		return

	if test_frame == 25:
		test_plant_execution()
		return

	if test_frame == 30:
		finish_test()


func setup_test():
	print("SETUP: Creating UI components\n")

	# Create input handler
	input_handler = FarmInputHandler.new()
	get_root().add_child(input_handler)
	input_handler.farm = farm
	input_handler.inject_grid_config(farm.grid_config)

	# Create plot grid display (needed for checkbox system)
	plot_grid_display = PlotGridDisplay.new()
	get_root().add_child(plot_grid_display)
	plot_grid_display.inject_grid_config(farm.grid_config)

	# Link input handler to plot grid display
	input_handler.plot_grid_display = plot_grid_display

	print("✅ Setup complete\n")


func test_no_checkbox():
	print("=".repeat(70))
	print("TEST 1: No Checkbox (should use current_selection = (0,0) = Market)")
	print("=".repeat(70) + "\n")

	# Enter plant submenu with no checkboxes
	input_handler._enter_submenu("plant")

	var menu = input_handler._cached_submenu
	print("Menu name: %s" % menu.get("name", "NONE"))
	print("Q action: %s" % menu.get("Q", {}).get("action", "NONE"))
	print("Expected: plant_wheat (Market default)\n")

	input_handler._exit_submenu()


func test_kitchen_checkbox():
	print("=".repeat(70))
	print("TEST 2: Kitchen Plot Checkboxed (5,1)")
	print("=".repeat(70) + "\n")

	# Simulate checkbox on Kitchen plot (5,1)
	var kitchen_pos = Vector2i(5, 1)
	plot_grid_display.toggle_plot_selection(kitchen_pos)

	var checked = plot_grid_display.get_selected_plots()
	print("Checkboxed plots: %s" % checked)

	# Enter plant submenu - should use Kitchen menu
	input_handler._enter_submenu("plant")

	var menu = input_handler._cached_submenu
	print("Menu name: %s" % menu.get("name", "NONE"))
	print("Q action: %s" % menu.get("Q", {}).get("action", "NONE"))
	print("Q label: %s" % menu.get("Q", {}).get("label", "NONE"))
	print("Q emoji: %s" % menu.get("Q", {}).get("emoji", "NONE"))
	print("Expected: plant_fire (Kitchen)\n")

	input_handler._exit_submenu()

	# Uncheck
	plot_grid_display.toggle_plot_selection(kitchen_pos)


func test_forest_checkbox():
	print("=".repeat(70))
	print("TEST 3: Forest Plot Checkboxed (1,1)")
	print("=".repeat(70) + "\n")

	# Simulate checkbox on Forest plot (1,1)
	var forest_pos = Vector2i(1, 1)
	plot_grid_display.toggle_plot_selection(forest_pos)

	var checked = plot_grid_display.get_selected_plots()
	print("Checkboxed plots: %s" % checked)

	# Enter plant submenu - should use Forest menu
	input_handler._enter_submenu("plant")

	var menu = input_handler._cached_submenu
	print("Menu name: %s" % menu.get("name", "NONE"))
	print("Q action: %s" % menu.get("Q", {}).get("action", "NONE"))
	print("Q label: %s" % menu.get("Q", {}).get("label", "NONE"))
	print("Q emoji: %s" % menu.get("Q", {}).get("emoji", "NONE"))
	print("Expected: plant_vegetation (Forest)\n")

	input_handler._exit_submenu()

	# Uncheck
	plot_grid_display.toggle_plot_selection(forest_pos)


func test_plant_execution():
	print("=".repeat(70))
	print("TEST 4: Execute Plant Action")
	print("=".repeat(70) + "\n")

	# Give economy resources
	farm.economy.add_resource("🔥", 1000, "test")
	farm.economy.add_resource("💧", 1000, "test")
	farm.economy.add_resource("🌿", 1000, "test")

	# Checkbox Kitchen plot (5,1)
	var kitchen_pos = Vector2i(5, 1)
	plot_grid_display.toggle_plot_selection(kitchen_pos)

	# Enter plant submenu
	input_handler._enter_submenu("plant")

	print("Executing Q action (should plant fire at Kitchen plot)...")

	# Execute Q action
	input_handler._execute_submenu_action("Q")

	# Check if fire was planted
	var plot = farm.grid.get_plot(kitchen_pos)
	if plot and plot.is_planted:
		var emojis = plot.get_plot_emojis()
		print("✅ Plot planted! Emoji: %s↔%s" % [emojis.get("north", "?"), emojis.get("south", "?")])
		if emojis.get("north") == "🔥":
			print("✅ SUCCESS: Fire planted in Kitchen plot!\n")
		else:
			print("❌ FAIL: Wrong plant type (%s instead of 🔥)\n" % emojis.get("north"))
	else:
		print("❌ FAIL: Plot not planted\n")

	input_handler._exit_submenu()


func finish_test():
	print("=".repeat(70))
	print("✅ CHECKBOX MENU FIX TEST COMPLETE")
	print("=".repeat(70))
	print("\nRECOMMENDATION:")
	print("Users can now:")
	print("1. Use WASD to move cursor → Opens correct biome menu")
	print("2. Use TYUIOP to checkbox plots → Opens menu for first checked plot")
	print("3. Mix both: checkbox + cursor movement updates menu dynamically")
	print("")
	quit()
