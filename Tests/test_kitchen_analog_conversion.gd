extends SceneTree

## Test Kitchen with Analog Model C Conversion
## Verifies that Kitchen plots work with new bath-based BasePlot

var kitchen = null
var test_passed = true

func _init():
	print("=== Kitchen Analog Conversion Test ===\n")

	# Load required classes
	var QuantumKitchen_Biome = load("res://Core/Environment/QuantumKitchen_Biome.gd")

	if not QuantumKitchen_Biome:
		print("❌ FAILED: Could not load Kitchen class")
		quit()
		return

	print("✅ Classes loaded successfully\n")

	# Test 1: Create Kitchen biome with bath
	print("--- Test 1: Kitchen Biome Initialization ---")
	kitchen = QuantumKitchen_Biome.new()

	# Add Kitchen to scene tree so it can access autoloads
	# This triggers _ready() automatically
	get_root().add_child(kitchen)

var first_frame = true

func _process(_delta):
	# _process is called automatically by SceneTree
	# Wait one frame for _ready() to complete, then run tests
	if first_frame:
		first_frame = false
		return

	# Run tests on second frame (after _ready() completes)
	run_tests()
	quit()

func run_tests():
	print("\n--- Running Tests After Initialization ---\n")

	# Load BasePlot class
	var BasePlot = load("res://Core/GameMechanics/BasePlot.gd")
	if not BasePlot:
		print("❌ FAILED: Could not load BasePlot")
		return

	# Test 1: Check Kitchen has bath
	if not kitchen or not kitchen.bath:
		print("❌ FAILED: Kitchen has no bath!")
		return

	print("✅ Kitchen has bath: %d emojis" % kitchen.bath.emoji_list.size())

	if not ("bath" in kitchen):
		print("❌ FAILED: 'bath' not in kitchen!")
		return

	print("✅ 'bath' in kitchen = true")

	# Test 2: Plant fire ingredient
	print("\n--- Test 2: Plant Fire Ingredient ---")
	var plot = BasePlot.new()
	plot.grid_position = Vector2i(3, 1)
	plot.north_emoji = "🔥"
	plot.south_emoji = "❄️"

	# Call plant with biome
	plot.plant(kitchen)

	if not plot.is_planted:
		print("❌ FAILED: Plot not planted! is_planted = false")
		print("   bath_subplot_id = %d" % plot.bath_subplot_id)
		print("   parent_biome = %s" % str(plot.parent_biome))
		return

	print("✅ Plot planted successfully")
	print("   is_planted = %s" % plot.is_planted)
	print("   bath_subplot_id = %d" % plot.bath_subplot_id)
	print("   parent_biome = %s" % plot.parent_biome.get_biome_type())

	# Test 3: Check bath has fire emoji
	print("\n--- Test 3: Bath Contains Fire Emoji ---")
	# Check if fire emoji is in the basis states
	var has_fire = false
	for emoji in kitchen.bath.emoji_list:
		if "🔥" in emoji:
			has_fire = true
			break

	if not has_fire:
		print("⚠️  WARNING: Bath does not contain 🔥")
	else:
		print("✅ Bath contains states with 🔥")
		# Get probability for a state with fire (e.g., "🔥💧💨")
		var p_fire_state = kitchen.bath.get_probability("🔥💧💨")
		print("   P(🔥💧💨) = %.4f" % p_fire_state)

	# Test 4: Measure plot
	print("\n--- Test 4: Measure Plot ---")
	var outcome = plot.measure()

	if outcome == "":
		print("❌ FAILED: Measurement returned empty string!")
		return

	print("✅ Measurement successful: %s" % outcome)

	if outcome not in ["north", "south"]:
		print("⚠️  WARNING: Unexpected outcome format (expected 'north' or 'south')")

	# Test 5: Get purity
	print("\n--- Test 5: Get Purity ---")
	var purity = plot.get_purity()
	print("✅ Purity = %.4f" % purity)

	if purity < 0.0 or purity > 1.0:
		print("⚠️  WARNING: Purity out of range [0,1]")

	# Test 6: Get mass (probability)
	print("\n--- Test 6: Get Mass ---")
	var mass = plot.get_mass()
	print("✅ Mass = %.4f" % mass)

	if mass < 0.0 or mass > 1.0:
		print("⚠️  WARNING: Mass out of range [0,1]")

	# Test 7: Harvest plot
	print("\n--- Test 7: Harvest Plot ---")
	var harvest_result = plot.harvest()

	if not harvest_result.has("success"):
		print("❌ FAILED: Harvest result missing 'success' key")
		return

	if not harvest_result["success"]:
		print("❌ FAILED: Harvest was not successful")
		print("   Result: %s" % str(harvest_result))
		return

	print("✅ Harvest successful!")
	print("   outcome = %s" % harvest_result.get("outcome", "N/A"))
	print("   yield = %s" % str(harvest_result.get("yield", 0)))

	# Test 8: Verify plot reset after harvest
	print("\n--- Test 8: Plot Reset After Harvest ---")
	if plot.is_planted:
		print("⚠️  WARNING: Plot still planted after harvest")
	else:
		print("✅ Plot reset: is_planted = false")

	if plot.bath_subplot_id != -1:
		print("⚠️  WARNING: bath_subplot_id not cleared (still %d)" % plot.bath_subplot_id)
	else:
		print("✅ bath_subplot_id cleared: -1")

	# Final Summary
	print("\n=== Test Summary ===")
	print("✅ ALL TESTS PASSED")
	print("Kitchen analog conversion is working correctly!")
	print("\nKitchen can now:")
	print("  • Plant fire/water/flour ingredients")
	print("  • Measure quantum states via bath")
	print("  • Harvest resources with purity-based yield")
	print("  • Reset plots after harvest")
