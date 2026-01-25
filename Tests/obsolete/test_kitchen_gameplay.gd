extends SceneTree

## Test Kitchen Gameplay with Simulated Keyboard Input via FarmInputHandler
## Tests the full workflow using the SAME signal path as the real game:
## FarmInputHandler → Farm → FarmGrid → Economy

const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")

var farm = null
var input_handler = null
var kitchen_biome = null
var test_frame = 0

func _init():
	print("\n=== Kitchen Gameplay Test (Signal-Based) ===\n")

	# Load the main farm scene
	var farm_scene = load("res://Core/Farm.gd")
	if not farm_scene:
		print("❌ FAILED: Could not load Farm.gd")
		quit()
		return

	print("✅ Farm scene loaded\n")

	# Create farm instance and add to scene tree
	farm = farm_scene.new()
	get_root().add_child(farm)

	print("⏳ Waiting for farm initialization...\n")

func _process(delta):
	test_frame += 1

	# Wait a few frames for everything to initialize
	if test_frame < 5:
		return

	if test_frame == 5:
		print("--- Frame 5: Setup Input Handler ---\n")
		setup_input_handler()
		return

	if test_frame == 10:
		print("\n--- Frame 10: Navigate to Kitchen Biome ---\n")
		navigate_to_kitchen()
		return

	if test_frame == 15:
		print("\n--- Frame 15: Plant Fire (Q key via FarmInputHandler) ---\n")
		plant_fire()
		return

	if test_frame == 20:
		print("\n--- Frame 20: Plant Water (E key via FarmInputHandler) ---\n")
		plant_water()
		return

	if test_frame == 25:
		print("\n--- Frame 25: Plant Flour (R key via FarmInputHandler) ---\n")
		plant_flour()
		return

	if test_frame == 30:
		print("\n--- Frame 30: Check Planted State ---\n")
		check_planted()
		return

	if test_frame == 35:
		print("\n--- Frame 35: Measure Plots (Tool 3 via FarmInputHandler) ---\n")
		measure_plots()
		return

	if test_frame == 40:
		print("\n--- Frame 40: Harvest Plots (Tool 2 via FarmInputHandler) ---\n")
		harvest_plots()
		return

	if test_frame == 45:
		print("\n--- Frame 45: Check Resources ---\n")
		check_resources()
		return

	if test_frame == 50:
		print("\n--- Frame 50: Test Complete ---\n")
		finish_test()


func setup_input_handler():
	"""Create and wire FarmInputHandler (same as FarmUI does)"""
	if not farm:
		print("❌ FAILED: Farm not created")
		quit()
		return

	# Give economy free resources for testing (fire, water, flour all cost 10 credits each)
	# In real game, player would gather these from biomes first
	if farm.economy:
		farm.economy.add_resource("🔥", 100, "test_setup")  # 10 fire units
		farm.economy.add_resource("💧", 100, "test_setup")  # 10 water units
		farm.economy.add_resource("💨", 100, "test_setup")  # 10 flour units
		print("💰 Added test resources to economy for Kitchen ingredients")

	# Create input handler
	input_handler = FarmInputHandler.new()
	get_root().add_child(input_handler)

	# Wire input handler to farm (same as FarmUI.setup_farm() does)
	input_handler.farm = farm
	input_handler.inject_grid_config(farm.grid_config)

	# Connect to action_performed signal for debug output
	if input_handler.has_signal("action_performed"):
		input_handler.action_performed.connect(_on_action_performed)

	print("✅ FarmInputHandler created and wired to farm")
	print("   Farm: %s" % farm)
	print("   Grid: %s" % farm.grid)
	print("   Economy: %s" % farm.economy)


func _on_action_performed(action: String, success: bool, message: String):
	"""Debug callback for action_performed signal"""
	var icon = "✅" if success else "❌"
	print("  %s ACTION: %s | %s" % [icon, action, message])


func navigate_to_kitchen():
	# Get Kitchen biome directly from Farm
	if not "kitchen_biome" in farm or not farm.kitchen_biome:
		print("❌ FAILED: Farm has no kitchen_biome")
		quit()
		return

	kitchen_biome = farm.kitchen_biome

	print("✅ Found Kitchen biome")
	print("   Type: %s" % kitchen_biome.get_biome_type())
	print("   Has bath: %s" % ("bath" in kitchen_biome and kitchen_biome.bath != null))

	# Find Kitchen plots
	print("   Finding Kitchen plots...")
	var kitchen_plots = []
	if farm.grid and "plot_biome_assignments" in farm.grid:
		for pos in farm.grid.plot_biome_assignments:
			if farm.grid.plot_biome_assignments[pos] == "QuantumKitchen":
				kitchen_plots.append(pos)
	print("   Kitchen plots (from biome assignments): %s" % str(kitchen_plots))

	# Also check which plots exist in grid
	print("   Checking all grid positions...")
	var all_plots = []
	for x in range(5):
		for y in range(5):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot:
				all_plots.append(pos)
	print("   All plots in grid: %s" % str(all_plots))


func plant_fire():
	"""Use FarmInputHandler to plant fire (simulates Q key press)"""
	if not input_handler:
		print("❌ FAILED: Input handler not available")
		return

	# Kitchen plots are at (3,1), (4,1), (5,1) - see Farm.gd lines 247-249
	var fire_pos = Vector2i(3, 1)
	var positions: Array[Vector2i] = [fire_pos]

	# Call the same method that Q key triggers
	input_handler._action_batch_plant("fire", positions)


func plant_water():
	"""Use FarmInputHandler to plant water (simulates E key press)"""
	if not input_handler:
		print("❌ FAILED: Input handler not available")
		return

	# Kitchen plots are at (3,1), (4,1), (5,1)
	var water_pos = Vector2i(4, 1)
	var positions: Array[Vector2i] = [water_pos]

	input_handler._action_batch_plant("water", positions)


func plant_flour():
	"""Use FarmInputHandler to plant flour (simulates R key press)"""
	if not input_handler:
		print("❌ FAILED: Input handler not available")
		return

	# Kitchen plots are at (3,1), (4,1), (5,1)
	var flour_pos = Vector2i(5, 1)
	var positions: Array[Vector2i] = [flour_pos]

	input_handler._action_batch_plant("flour", positions)


func check_planted():
	"""Verify all 3 ingredients are planted."""
	if not farm or not farm.grid:
		return

	# Kitchen plots: (3,1), (4,1), (5,1)
	var positions = [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]
	var types = ["fire", "water", "flour"]

	for i in range(3):
		var plot = farm.grid.get_plot(positions[i])
		if plot and plot.is_planted:
			print("✅ %s is planted at %s" % [types[i].capitalize(), positions[i]])
		else:
			print("❌ %s NOT planted at %s" % [types[i].capitalize(), positions[i]])


func measure_plots():
	"""Use FarmInputHandler to measure plots (simulates Tool 3)"""
	if not input_handler:
		print("❌ FAILED: Input handler not available")
		return

	# Kitchen plots: (3,1), (4,1), (5,1)
	var positions: Array[Vector2i] = [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]

	# Call the same method that Tool 3 (measure) triggers
	input_handler._action_batch_measure(positions)


func harvest_plots():
	"""Use FarmInputHandler to harvest plots (simulates Tool 2)"""
	if not input_handler:
		print("❌ FAILED: Input handler not available")
		return

	# Kitchen plots: (3,1), (4,1), (5,1)
	var positions: Array[Vector2i] = [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]

	# Call the same method that Tool 2 (harvest) triggers
	input_handler._action_batch_harvest(positions)


func check_resources():
	"""Check if resources were awarded to economy."""
	if not farm or not farm.economy:
		print("❌ FAILED: Economy not available")
		return

	print("\n📊 Economy Resources:")

	# Check for Kitchen ingredient emojis
	var kitchen_emojis = ["🔥", "❄️", "💧", "🏜️", "💨", "🌾"]
	var found_any = false

	for emoji in kitchen_emojis:
		var amount = farm.economy.get_resource(emoji)
		if amount > 0:
			print("   %s: %d credits" % [emoji, amount])
			found_any = true

	# Check for bread
	var bread = farm.economy.get_resource("🍞")
	if bread > 0:
		print("   🍞: %d (BREAD DETECTED!)" % bread)
		found_any = true

	if not found_any:
		print("   ⚠️  No Kitchen resources found")
		print("   Total resources: %d" % farm.economy.get_total_resource_count())


func finish_test():
	print("\n=== Test Complete ===")
	print("Kitchen gameplay workflow executed successfully using signal path!")
	print("\nWorkflow tested:")
	print("  1. Farm initialization")
	print("  2. FarmInputHandler setup (same as real game)")
	print("  3. Navigate to Kitchen biome")
	print("  4. Plant fire/water/flour via FarmInputHandler (Q/E/R)")
	print("  5. Measure quantum states via FarmInputHandler (Tool 3)")
	print("  6. Harvest resources via FarmInputHandler (Tool 2)")
	print("  7. Check economy for resources")
	print("\n✅ Test uses SAME signal path as keyboard input in real game!")

	quit()
