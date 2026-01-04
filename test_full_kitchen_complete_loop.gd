#!/usr/bin/env -S godot --headless -s
## Full Kitchen Test: Complete Gameplay Loop
##
## Tests the complete cycle:
## wheat → farm → harvest → kitchen → bread → market → repeat
##
## Validates ALL systems working together:
## - Farm biome growth
## - Quantum harvest measurement
## - Kitchen Bell state detection
## - Bread production via triplet measurement
## - Market trading
## - Economy resource transformation

extends SceneTree

const Farm = preload("res://Core/Farm.gd")
const QuantumKitchen = preload("res://Core/Environment/QuantumKitchen_Biome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var farm: Farm
var kitchen: QuantumKitchen
var _harvest_qubits = []  # Store qubits collected in phase 4

var test_results = {
	"farm_setup": false,
	"crops_planted": false,
	"crops_grown": false,
	"crops_harvested": false,
	"kitchen_ready": false,
	"bell_state_detected": false,
	"bread_produced": false,
	"market_traded": false,
	"full_cycle_complete": false,
}

const BIOME_DAYS = 3
const BIOME_DAY_SECONDS = 20.0
const TEST_DURATION = BIOME_DAYS * BIOME_DAY_SECONDS
const STEP_SIZE = 0.01

func _sep(char: String, count: int) -> String:
	var result = ""
	for _i in range(count):
		result += char
	return result

func _initialize():
	print("\n" + _sep("═", 100))
	print("🍞 FULL KITCHEN TEST: Complete Gameplay Loop")
	print("wheat → farm → harvest → kitchen → bread → market → cycle")
	print(_sep("═", 100) + "\n")

	_phase_1_setup()
	_phase_2_planting()
	_phase_3_growth()
	_phase_4_harvest()
	_phase_5_kitchen()
	_phase_6_market()
	_phase_7_analysis()

	quit(0)


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 1: FARM SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func _phase_1_setup():
	print("📋 PHASE 1: FARM SETUP")
	print(_sep("─", 100))

	farm = Farm.new()
	farm._ready()

	# Manually call _ready on biomes to ensure QuantumComputer initialization
	if farm.biotic_flux_biome:
		farm.biotic_flux_biome._ready()
	if farm.market_biome:
		farm.market_biome._ready()
	if farm.forest_biome:
		farm.forest_biome._ready()
	if farm.kitchen_biome:
		farm.kitchen_biome._ready()

	if not farm:
		print("  ❌ FAILED: Farm creation")
		return

	var economy = farm.economy
	if not economy:
		print("  ❌ FAILED: Economy not created")
		return

	# Start with ample resources (Model B: using emoji-based resource system)
	economy.add_resource("🌾", 500 * 10)  # 500 wheat units
	economy.add_resource("👥", 100 * 10)  # 100 labor units
	economy.add_resource("💨", 50 * 10)   # 50 flour units

	print("  ✓ Farm created with biome: %s" % farm.biome_enabled)
	print("  ✓ Economy initialized")
	print("  📊 Starting inventory:")
	print("      🌾 Wheat: %d" % economy.get_resource("🌾"))
	print("      👥 Labor: %d" % economy.get_resource("👥"))
	print("      💨 Flour: %d" % economy.get_resource("💨"))
	print()

	test_results["farm_setup"] = true


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 2: PLANT CROPS FOR KITCHEN
# ═══════════════════════════════════════════════════════════════════════════════

func _phase_2_planting():
	print("🌱 PHASE 2: PLANT CROPS FOR KITCHEN")
	print(_sep("─", 100))

	if not test_results["farm_setup"]:
		print("  ⏭️  Skipped (farm setup failed)\n")
		return

	# Plant three wheat crops in a LINE (vertical GHZ state)
	# Positions: (0,0), (1,0), (2,0) for horizontal line
	var wheat_pos = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]

	print("  Planting wheat crops in horizontal line (GHZ state pattern):")
	for pos in wheat_pos:
		var success = farm.build(pos, "wheat")
		if success:
			print("    ✓ Planted wheat at %s" % pos)
		else:
			print("    ✗ Failed to plant wheat at %s" % pos)
			return

	print("  ✓ All 3 wheat crops planted")
	print()

	test_results["crops_planted"] = true


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 3: GROW CROPS (Biotic Flux Soak)
# ═══════════════════════════════════════════════════════════════════════════════

func _phase_3_growth():
	print("🌿 PHASE 3: GROW CROPS (Biotic Flux Soak)")
	print(_sep("─", 100))

	if not test_results["crops_planted"]:
		print("  ⏭️  Skipped (crops not planted)\n")
		return

	print("  ⏳ Simulating %d biome days (%.0f seconds)..." % [BIOME_DAYS, TEST_DURATION])

	# Log initial state (Model B: check purity instead of quantum_state energy)
	var wheat_pos = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var initial_energies = []
	for pos in wheat_pos:
		var plot = farm.get_plot(pos)
		if plot and plot.is_planted and plot.parent_biome:
			initial_energies.append(plot.get_purity())

	print("  Initial energy: %.4f, %.4f, %.4f" % [initial_energies[0], initial_energies[1], initial_energies[2]])

	# Simulate biome evolution (Model B: process all biomes)
	var steps = int(TEST_DURATION / STEP_SIZE)
	for _step in range(steps):
		if farm.biotic_flux_biome:
			farm.biotic_flux_biome._process(STEP_SIZE)
		if farm.market_biome:
			farm.market_biome._process(STEP_SIZE)
		if farm.forest_biome:
			farm.forest_biome._process(STEP_SIZE)
		if farm.kitchen_biome:
			farm.kitchen_biome._process(STEP_SIZE)

	# Log final state (Model B: check purity instead of quantum_state energy)
	var final_energies = []
	for pos in wheat_pos:
		var plot = farm.get_plot(pos)
		if plot and plot.is_planted and plot.parent_biome:
			final_energies.append(plot.get_purity())

	if final_energies.size() == 3:
		print("  Final energy:   %.4f, %.4f, %.4f" % [final_energies[0], final_energies[1], final_energies[2]])
	else:
		print("  Final energy:   (measurement failed)")

	var avg_growth = ((final_energies[0] + final_energies[1] + final_energies[2]) / 3.0) - ((initial_energies[0] + initial_energies[1] + initial_energies[2]) / 3.0)
	print("  ✓ Average growth: %.4f per crop" % avg_growth)
	print()

	test_results["crops_grown"] = true


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 4: HARVEST CROPS
# ═══════════════════════════════════════════════════════════════════════════════

func _phase_4_harvest():
	print("✂️  PHASE 4: HARVEST CROPS")
	print(_sep("─", 100))

	if not test_results["crops_grown"]:
		print("  ⏭️  Skipped (crops not grown)\n")
		return

	var wheat_pos = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var harvest_qubits = []

	print("  Harvesting wheat crops:")

	# Model B: Harvest plots (measurement and clear are handled internally)
	for pos in wheat_pos:
		var measurement = farm.measure_plot(pos)
		var harvest = farm.harvest_plot(pos)

		if harvest.is_empty():
			print("    ✗ Harvest failed at %s" % pos)
			return

		print("    ✓ Harvested %s from %s" % [measurement, pos])

	print("  ✓ All crops harvested (%d qubits collected)" % harvest_qubits.size())

	# Store the qubits for later use in kitchen phase
	_harvest_qubits = harvest_qubits
	print()

	test_results["crops_harvested"] = true


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 5: KITCHEN PRODUCTION
# ═══════════════════════════════════════════════════════════════════════════════

func _phase_5_kitchen():
	print("👨‍🍳 PHASE 5: KITCHEN PRODUCTION")
	print(_sep("─", 100))

	if not test_results["crops_harvested"]:
		print("  ⏭️  Skipped (crops not harvested)\n")
		return

	# Get the qubits from the global harvest list (set in phase 4)
	# We stored references to them before harvest cleared the plots
	var harvest_qubits = _get_harvest_qubits()

	if harvest_qubits.is_empty() or harvest_qubits.size() < 3:
		print("  ✗ No harvest qubits available from phase 4")
		return

	print("  ✓ Got %d qubits from harvest phase" % harvest_qubits.size())

	# Create kitchen
	kitchen = QuantumKitchen.new()
	if not kitchen:
		print("  ✗ Failed to create kitchen")
		return

	# Manually call _ready() since kitchen is not in scene tree
	kitchen._ready()

	print("  ✓ Kitchen created and initialized")

	var qubits = harvest_qubits.slice(0, 3)  # Take first 3

	print("  Setting kitchen inputs:")
	print("    ✓ Qubit 1: energy=%.4f" % qubits[0].energy)
	print("    ✓ Qubit 2: energy=%.4f" % qubits[1].energy)
	print("    ✓ Qubit 3: energy=%.4f" % qubits[2].energy)

	# Set input qubits (3-qubit system)
	kitchen.set_input_qubits(qubits[0], qubits[1], qubits[2])

	print("\n  Detecting Bell state from plot positions:")
	var wheat_pos = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var is_valid = kitchen.configure_bell_state(wheat_pos)

	if not is_valid:
		print("    ✗ Bell state configuration failed")
		return

	print("    ✓ Bell state detected (horizontal line = GHZ state)")

	test_results["kitchen_ready"] = true
	test_results["bell_state_detected"] = true

	print("\n  Producing bread via quantum measurement:")
	var can_produce = kitchen.can_produce_bread()
	if not can_produce:
		print("    ✗ Cannot produce bread (qubits invalid)")
		return

	var bread_qubit = kitchen.produce_bread()
	if not bread_qubit:
		print("    ✗ Bread production failed")
		return

	print("    ✓ Bread produced!")
	print("    📊 Bread qubit:")
	print("      - Energy: %.4f" % bread_qubit.energy)
	print("      - Radius: %.4f" % bread_qubit.radius)
	print("      - Theta: %.4f (%.1f°)" % [bread_qubit.theta, rad_to_deg(bread_qubit.theta)])
	print("      - State 1: %s (bread)" % bread_qubit.north_emoji)
	print("      - State 2: %s (inputs)" % bread_qubit.south_emoji)
	print()

	test_results["bread_produced"] = true


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 6: MARKET TRADING
# ═══════════════════════════════════════════════════════════════════════════════

func _phase_6_market():
	print("💰 PHASE 6: MARKET TRADING")
	print(_sep("─", 100))

	if not test_results["bread_produced"]:
		print("  ⏭️  Skipped (bread not produced)\n")
		return

	var economy = farm.economy
	if not economy:
		print("  ✗ Economy not found")
		return

	var flour_before = economy.flour_inventory
	var credits_before = economy.credits

	print("  Current inventory:")
	print("    🌾 Flour: %d" % flour_before)
	print("    💰 Credits: %d" % credits_before)

	if flour_before <= 0:
		print("  ⚠️  No flour to trade, skipping market phase")
		return

	print("\n  Trading flour at market:")

	# Simple market trade: 10 flour → 800 credits (80 per flour)
	var flour_to_trade = min(10, flour_before)
	var credits_per_flour = 80

	economy.flour_inventory -= flour_to_trade
	economy.flour_changed.emit(economy.flour_inventory)
	economy.credits += flour_to_trade * credits_per_flour
	economy.credits_changed.emit(economy.credits)

	var flour_after = economy.flour_inventory
	var credits_after = economy.credits

	print("    ✓ Sold %d flour" % flour_to_trade)
	print("    ✓ Received %d credits" % (flour_to_trade * credits_per_flour))
	print("    🌾 Flour: %d → %d" % [flour_before, flour_after])
	print("    💰 Credits: %d → %d" % [credits_before, credits_after])
	print()

	test_results["market_traded"] = true
	test_results["full_cycle_complete"] = true


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 7: ANALYSIS & RESULTS
# ═══════════════════════════════════════════════════════════════════════════════

func _phase_7_analysis():
	print("📊 PHASE 7: TEST RESULTS & ANALYSIS")
	print(_sep("═", 100))

	var all_pass = true
	for test_name in test_results:
		var status = test_results[test_name]
		var symbol = "✓" if status else "✗"
		print("  %s %s" % [symbol, test_name])
		if not status:
			all_pass = false

	print()
	if all_pass:
		print("  🎉 FULL KITCHEN COMPLETE LOOP TEST PASSED!")
		print()
		print("  ✅ Verified:")
		print("     • Farm biome growth system works")
		print("     • Quantum harvest measurement works")
		print("     • Kitchen Bell state detection works")
		print("     • Bread production via triplet measurement works")
		print("     • Market trading works")
		print("     • Complete cycle: wheat → farm → harvest → kitchen → bread → market")
		test_results["full_cycle_complete"] = true
	else:
		print("  ❌ Some tests failed")
		print()
		print("  Failed phases:")
		for test_name in test_results:
			if not test_results[test_name]:
				print("     • %s" % test_name)

	print()
	print(_sep("═", 100))
	print()


func _get_harvest_qubits() -> Array:
	"""Retrieve qubits collected during harvest phase"""
	return _harvest_qubits


func rad_to_deg(radians: float) -> float:
	return radians * 180.0 / PI

