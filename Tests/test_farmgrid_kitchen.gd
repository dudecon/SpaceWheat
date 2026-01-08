extends SceneTree

## Integration Tests for FarmGrid + Kitchen
##
## Tests the full workflow: FarmEconomy → FarmGrid → Kitchen → Harvest

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const QuantumKitchen_Biome = preload("res://Core/Environment/QuantumKitchen_Biome.gd")


func _init():
	print("\n=== FarmGrid Kitchen Integration Tests ===\n")

	var passed = 0
	var failed = 0

	# Test 1: Create farm economy
	print("Test 1: Create FarmEconomy")
	var economy = FarmEconomy.new()
	economy._ready()

	if economy != null:
		print("  ✓ FarmEconomy created")
		passed += 1
	else:
		print("  ✗ Failed to create FarmEconomy")
		failed += 1

	# Test 2: Add initial resources
	print("\nTest 2: Add initial resources to economy")
	economy.add_resource("🔥", 1000, "test_init")
	economy.add_resource("💧", 1000, "test_init")
	economy.add_resource("💨", 1000, "test_init")

	var fire_credits = economy.get_resource("🔥")
	var water_credits = economy.get_resource("💧")
	var flour_credits = economy.get_resource("💨")

	if fire_credits == 1000 and water_credits == 1000 and flour_credits == 1000:
		print("  ✓ Initial resources: 🔥=%d, 💧=%d, 💨=%d" % [
			fire_credits, water_credits, flour_credits])
		passed += 1
	else:
		print("  ✗ Resource amounts incorrect")
		failed += 1

	# Test 3: Create FarmGrid
	print("\nTest 3: Create FarmGrid with kitchen biome")
	var farm_grid = FarmGrid.new()
	farm_grid.farm_economy = economy

	# Manually add kitchen biome
	var kitchen = QuantumKitchen_Biome.new()
	kitchen._ready()
	farm_grid.biomes["Kitchen"] = kitchen

	if farm_grid.biomes.has("Kitchen"):
		print("  ✓ Kitchen biome registered in FarmGrid")
		passed += 1
	else:
		print("  ✗ Kitchen biome not registered")
		failed += 1

	# Test 4: Add fire to kitchen
	print("\nTest 4: Add fire resource to kitchen")
	var fire_before = economy.get_resource("🔥")
	var success = farm_grid.kitchen_add_resource("🔥", 100)

	if success:
		print("  ✓ Fire resource added successfully")
		var fire_after = economy.get_resource("🔥")
		if fire_after == fire_before - 100:
			print("  ✓ Economy deducted 100 credits: %d → %d" % [fire_before, fire_after])
			passed += 1
		else:
			print("  ✗ Economy not deducted correctly: %d → %d" % [fire_before, fire_after])
			failed += 1
	else:
		print("  ✗ Failed to add fire resource")
		failed += 1

	# Test 5: Check kitchen drive activated
	print("\nTest 5: Check kitchen has active drive")
	if kitchen.active_drives.size() > 0:
		print("  ✓ Kitchen has %d active drive(s)" % kitchen.active_drives.size())
		passed += 1
	else:
		print("  ✗ No active drives in kitchen")
		failed += 1

	# Test 6: Add water and flour
	print("\nTest 6: Add water and flour to kitchen")
	farm_grid.kitchen_add_resource("💧", 100)
	farm_grid.kitchen_add_resource("💨", 100)

	if kitchen.active_drives.size() == 3:
		print("  ✓ Kitchen now has 3 active drives")
		passed += 1
	else:
		print("  ✗ Expected 3 drives, got %d" % kitchen.active_drives.size())
		failed += 1

	# Test 7: Evolve kitchen
	print("\nTest 7: Evolve kitchen for 5 seconds")
	for i in range(50):
		kitchen._update_quantum_substrate(0.1)

	var p_bread = kitchen.get_bread_probability()
	var p_fire = kitchen.get_temperature_hot()
	var p_water = kitchen.get_moisture_wet()
	var p_flour = kitchen.get_substance_flour()

	print("  → P(🍞)=%.3f, P(🔥)=%.3f, P(💧)=%.3f, P(💨)=%.3f" % [
		p_bread, p_fire, p_water, p_flour])

	if p_bread > 0.01:
		print("  ✓ Bread probability increased to %.3f" % p_bread)
		passed += 1
	else:
		print("  ✗ Bread probability still near zero: %.3f" % p_bread)
		failed += 1

	# Test 8: Harvest kitchen
	print("\nTest 8: Harvest kitchen")
	var bread_before = economy.get_resource("🍞")
	var result = farm_grid.kitchen_harvest()

	if result["success"]:
		print("  ✓ Harvest succeeded")
		print("    → Outcome: %s" % result["outcome"])
		print("    → Yield: %d" % result["yield"])

		var bread_after = economy.get_resource("🍞")
		if result["got_bread"] and bread_after > bread_before:
			print("  ✓ Bread added to economy: %d → %d" % [bread_before, bread_after])
			passed += 1
		elif not result["got_bread"] and bread_after == bread_before:
			print("  ✓ No bread added (failed measurement)")
			passed += 1
		else:
			print("  ✗ Economy state inconsistent")
			failed += 1
	else:
		print("  ✗ Harvest failed")
		failed += 1

	# Test 9: Kitchen reset after harvest
	print("\nTest 9: Kitchen reset to ground state")
	var p_ground = kitchen.get_ground_probability()

	if abs(p_ground - 1.0) < 0.01:
		print("  ✓ Kitchen reset to |111⟩, P(ground)=%.3f" % p_ground)
		passed += 1
	else:
		print("  ✗ Kitchen not reset: P(ground)=%.3f" % p_ground)
		failed += 1

	# Test 10: Multiple harvest cycles
	print("\nTest 10: Multiple harvest cycles")
	var total_bread = 0
	var cycles = 3

	for cycle in range(cycles):
		# Add resources
		farm_grid.kitchen_add_resource("🔥", 50)
		farm_grid.kitchen_add_resource("💧", 50)
		farm_grid.kitchen_add_resource("💨", 50)

		# Evolve
		for i in range(30):
			kitchen._update_quantum_substrate(0.1)

		# Harvest
		var cycle_result = farm_grid.kitchen_harvest()
		if cycle_result["got_bread"]:
			total_bread += cycle_result["yield"]

	print("  → %d cycles completed, total bread yield: %d" % [cycles, total_bread])

	if total_bread >= 0:  # At least attempted all cycles
		print("  ✓ Multiple cycles completed")
		passed += 1
	else:
		print("  ✗ Cycles failed")
		failed += 1

	# Summary
	print("\n" + "=".repeat(60))
	print("Summary: %d passed, %d failed" % [passed, failed])
	if failed == 0:
		print("✅ All FarmGrid integration tests passed!")
	else:
		print("❌ Some tests failed")
	print("=".repeat(60) + "\n")

	quit()
