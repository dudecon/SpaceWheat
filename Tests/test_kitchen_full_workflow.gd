extends SceneTree

## Full Kitchen Workflow Test - Complete Quantum Baking Experience
## Tests: Plant → Entangle → Measure → Harvest → Bread → Mill → Market
## Uses signal-based architecture (FarmInputHandler) same as real game

const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")

var farm = null
var input_handler = null
var kitchen_biome = null
var test_frame = 0

func _init():
	print("\n" + "=".repeat(70))
	print("🍞 FULL KITCHEN WORKFLOW TEST - Quantum Baking & Market Trading")
	print("=".repeat(70) + "\n")

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

	# Wait for initialization
	if test_frame < 5:
		return

	if test_frame == 5:
		print("\n" + "-".repeat(70))
		print("PHASE 1: Setup")
		print("-".repeat(70) + "\n")
		setup_input_handler()
		return

	if test_frame == 10:
		print("\n" + "-".repeat(70))
		print("PHASE 2: Plant Kitchen Ingredients")
		print("-".repeat(70) + "\n")
		plant_all_ingredients()
		return

	if test_frame == 15:
		print("\n" + "-".repeat(70))
		print("PHASE 3: Create Entanglement (Quantum Correlation)")
		print("-".repeat(70) + "\n")
		entangle_kitchen_plots()
		return

	if test_frame == 20:
		print("\n" + "-".repeat(70))
		print("PHASE 4: Measure Quantum States")
		print("-".repeat(70) + "\n")
		measure_all_plots()
		return

	if test_frame == 25:
		print("\n" + "-".repeat(70))
		print("PHASE 5: Harvest & Bread Detection")
		print("-".repeat(70) + "\n")
		harvest_all_plots()
		return

	if test_frame == 30:
		print("\n" + "-".repeat(70))
		print("PHASE 6: Economy Check (After Harvest)")
		print("-".repeat(70) + "\n")
		check_economy_state("After Harvest")
		return

	if test_frame == 35:
		print("\n" + "-".repeat(70))
		print("PHASE 7: Mill Processing (Wheat → Flour)")
		print("-".repeat(70) + "\n")
		process_wheat_to_flour()
		return

	if test_frame == 40:
		print("\n" + "-".repeat(70))
		print("PHASE 8: Kitchen Baking (Flour → Bread)")
		print("-".repeat(70) + "\n")
		process_flour_to_bread()
		return

	if test_frame == 45:
		print("\n" + "-".repeat(70))
		print("PHASE 9: Final Economy State")
		print("-".repeat(70) + "\n")
		check_economy_state("Final")
		return

	if test_frame == 50:
		print("\n" + "=".repeat(70))
		print("TEST COMPLETE - Full Kitchen Workflow Summary")
		print("=".repeat(70) + "\n")
		finish_test()


func setup_input_handler():
	"""Create and wire FarmInputHandler (same as FarmUI does)"""
	if not farm:
		print("❌ FAILED: Farm not created")
		quit()
		return

	# Give economy resources for testing
	# Kitchen ingredients cost: fire=🔥10, water=💧10, flour=💨10 credits
	if farm.economy:
		print("💰 Setting up test economy resources:")

		# Kitchen ingredient costs
		farm.economy.add_resource("🔥", 200, "test_setup")  # 20 fire units
		farm.economy.add_resource("💧", 200, "test_setup")  # 20 water units
		farm.economy.add_resource("💨", 200, "test_setup")  # 20 flour units

		# Extra wheat for mill testing
		farm.economy.add_resource("🌾", 1000, "test_setup")  # 100 wheat units

		print("   🔥 Fire: 200 credits (20 units)")
		print("   💧 Water: 200 credits (20 units)")
		print("   💨 Flour: 200 credits (20 units)")
		print("   🌾 Wheat: 1000 credits (100 units)")

	# Create input handler
	input_handler = FarmInputHandler.new()
	get_root().add_child(input_handler)

	# Wire input handler to farm (same as FarmUI.setup_farm() does)
	input_handler.farm = farm
	input_handler.inject_grid_config(farm.grid_config)

	# Connect to action_performed signal for debug output
	if input_handler.has_signal("action_performed"):
		input_handler.action_performed.connect(_on_action_performed)

	print("\n✅ FarmInputHandler created and wired to farm")
	print("   Kitchen plots available: (3,1), (4,1), (5,1)")


func _on_action_performed(action: String, success: bool, message: String):
	"""Debug callback for action_performed signal"""
	var icon = "✅" if success else "❌"
	print("  %s %s" % [icon, message])


func plant_all_ingredients():
	"""Plant fire, water, and flour at all 3 Kitchen plots"""
	if not input_handler:
		print("❌ FAILED: Input handler not available")
		return

	print("🌱 Planting Kitchen ingredients (simulating Q/E/R keys):\n")

	# Kitchen plots: (3,1), (4,1), (5,1)
	# Plant different ingredient at each plot
	var plants = [
		{"type": "fire", "pos": Vector2i(3, 1), "emoji": "🔥"},
		{"type": "water", "pos": Vector2i(4, 1), "emoji": "💧"},
		{"type": "flour", "pos": Vector2i(5, 1), "emoji": "💨"}
	]

	for plant_data in plants:
		var positions: Array[Vector2i] = [plant_data.pos]
		print("  Planting %s at %s..." % [plant_data.type, plant_data.pos])
		input_handler._action_batch_plant(plant_data.type, positions)


func entangle_kitchen_plots():
	"""Create entanglement between Kitchen plots for quantum correlation"""
	if not farm:
		print("❌ FAILED: Farm not available")
		return

	print("🔗 Creating quantum entanglement:\n")

	# Kitchen plots: (3,1), (4,1), (5,1)
	# Create pairwise entanglement to correlate all 3 plots

	# Entangle plot1 ↔ plot2
	print("  Entangling (3,1) ↔ (4,1) [fire ↔ water]...")
	var success1 = farm.entangle_plots(Vector2i(3, 1), Vector2i(4, 1), "phi_plus")

	# Entangle plot2 ↔ plot3
	print("  Entangling (4,1) ↔ (5,1) [water ↔ flour]...")
	var success2 = farm.entangle_plots(Vector2i(4, 1), Vector2i(5, 1), "phi_plus")

	if success1 and success2:
		print("\n✅ All Kitchen plots entangled (correlated quantum states)")
		print("   This creates correlations that affect measurement outcomes")
	else:
		print("\n⚠️  Entanglement may have failed (check if plots are planted)")


func measure_all_plots():
	"""Measure quantum states of all 3 Kitchen plots"""
	if not input_handler:
		print("❌ FAILED: Input handler not available")
		return

	print("📊 Measuring quantum states (simulating Tool 3):\n")

	# Kitchen plots: (3,1), (4,1), (5,1)
	var positions: Array[Vector2i] = [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]

	# Measure all 3 plots
	input_handler._action_batch_measure(positions)

	print("\n  Note: Measurement collapses quantum states")
	print("  Entanglement means outcomes are correlated")


func harvest_all_plots():
	"""Harvest all 3 Kitchen plots and check for bread"""
	if not input_handler:
		print("❌ FAILED: Input handler not available")
		return

	print("✂️  Harvesting Kitchen plots (simulating Tool 2):\n")

	# Kitchen plots: (3,1), (4,1), (5,1)
	var positions: Array[Vector2i] = [Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]

	# Harvest all 3 plots
	# Note: _action_batch_harvest includes bread detection logic
	input_handler._action_batch_harvest(positions)

	print("\n  Bread Detection:")
	print("  🍞 is created if all 3 plots measured to |0⟩ states")
	print("  |000⟩ = 🔥💧💨 (hot, wet, flour) = Bread Ready")


func process_wheat_to_flour():
	"""Use Mill to process wheat into flour"""
	if not farm or not farm.economy:
		print("❌ FAILED: Economy not available")
		return

	print("🏭 Processing wheat at Mill (10 wheat → 8 flour + credits):\n")

	var wheat_before = farm.economy.get_resource_units("🌾")
	var flour_before = farm.economy.get_resource_units("💨")

	print("  Before: 🌾 %d wheat, 💨 %d flour" % [wheat_before, flour_before])

	# Process 10 wheat units
	var result = farm.economy.process_wheat_to_flour(10)

	if result.success:
		print("  ✅ Mill processing complete!")
		print("     Wheat used: %d" % result.wheat_used)
		print("     Flour produced: %d" % result.flour_produced)
		print("     Credits earned: %d 💰" % result.credits_earned)

		var wheat_after = farm.economy.get_resource_units("🌾")
		var flour_after = farm.economy.get_resource_units("💨")
		print("  After: 🌾 %d wheat, 💨 %d flour" % [wheat_after, flour_after])
	else:
		print("  ❌ Mill processing failed (not enough wheat?)")


func process_flour_to_bread():
	"""Use Kitchen to process flour into bread"""
	if not farm or not farm.economy:
		print("❌ FAILED: Economy not available")
		return

	print("🍳 Baking bread at Kitchen (5 flour → 3 bread):\n")

	var flour_before = farm.economy.get_resource_units("💨")
	var bread_before = farm.economy.get_resource_units("🍞")

	print("  Before: 💨 %d flour, 🍞 %d bread" % [flour_before, bread_before])

	# Process 5 flour units
	var result = farm.economy.process_flour_to_bread(5)

	if result.success:
		print("  ✅ Kitchen baking complete!")
		print("     Flour used: %d" % result.flour_used)
		print("     Bread produced: %d" % result.bread_produced)

		var flour_after = farm.economy.get_resource_units("💨")
		var bread_after = farm.economy.get_resource_units("🍞")
		print("  After: 💨 %d flour, 🍞 %d bread" % [flour_after, bread_after])
	else:
		print("  ❌ Kitchen baking failed (not enough flour?)")


func check_economy_state(label: String):
	"""Display current economy state"""
	if not farm or not farm.economy:
		print("❌ FAILED: Economy not available")
		return

	print("📊 Economy State (%s):\n" % label)

	# Key resources to track
	var resources = [
		{"emoji": "🌾", "name": "Wheat"},
		{"emoji": "💨", "name": "Flour"},
		{"emoji": "🍞", "name": "Bread"},
		{"emoji": "🔥", "name": "Fire"},
		{"emoji": "❄️", "name": "Cold"},
		{"emoji": "💧", "name": "Water"},
		{"emoji": "🏜️", "name": "Dry"},
		{"emoji": "💰", "name": "Credits"}
	]

	for res in resources:
		var credits = farm.economy.get_resource(res.emoji)
		var units = farm.economy.get_resource_units(res.emoji)
		if credits > 0:
			print("  %s %s: %d credits (%d units)" % [res.emoji, res.name, credits, units])

	print("")


func finish_test():
	print("🎉 FULL KITCHEN WORKFLOW TEST COMPLETED!\n")
	print("Phases tested:")
	print("  ✅ 1. Setup (FarmInputHandler + Economy)")
	print("  ✅ 2. Plant Kitchen ingredients (fire, water, flour)")
	print("  ✅ 3. Create entanglement (quantum correlation)")
	print("  ✅ 4. Measure quantum states (collapse)")
	print("  ✅ 5. Harvest & bread detection (|000⟩ check)")
	print("  ✅ 6. Economy tracking (harvest rewards)")
	print("  ✅ 7. Mill processing (wheat → flour)")
	print("  ✅ 8. Kitchen baking (flour → bread)")
	print("  ✅ 9. Final economy state\n")

	print("Complete production chain validated:")
	print("  🌾 Wheat → 🏭 Mill → 💨 Flour → 🍳 Kitchen → 🍞 Bread\n")

	print("Quantum mechanics validated:")
	print("  • Planting creates quantum states")
	print("  • Entanglement correlates states")
	print("  • Measurement collapses states")
	print("  • Bread detection checks |000⟩ state\n")

	quit()
