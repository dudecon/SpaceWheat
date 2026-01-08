#!/usr/bin/env -S godot --headless -s
## Test: Plant → Measure → Harvest Spam Creates Zero-Loss Chaotic Output
##
## Validates that spamming the plant-measure-harvest cycle:
## 1. Has ZERO LOSS (resources in = resources out)
## 2. Creates CHAOTIC OUTPUT (random wheat/labor distribution)
## 3. Can be repeated indefinitely (self-sustaining)

extends SceneTree

const Farm = preload("res://Core/Farm.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")

var farm: Farm
var economy: FarmEconomy

# Tracking variables
var initial_wheat: int
var initial_labor: int
var cycles_completed: int = 0
var wheat_harvested_count: int = 0
var labor_harvested_count: int = 0
var total_wheat_gained: int = 0
var total_labor_gained: int = 0
var total_wheat_spent: int = 0

func _sep(char: String, count: int) -> String:
	var result = ""
	for _i in range(count):
		result += char
	return result

func _initialize():
	print("\n" + _sep("═", 80))
	print("🌀 TEST: Plant → Measure → Harvest Spam")
	print("🎯 Verify: Zero-Loss + Chaotic Output")
	print(_sep("═", 80) + "\n")

	_setup()
	_run_spam_test()
	_report_results()

	quit(0)


func _setup():
	"""Initialize test infrastructure"""
	print("🔧 Setting up...\n")

	# Create farm
	farm = Farm.new()
	farm._ready()
	print("   ✓ Farm created")

	# Get economy
	economy = farm.economy
	economy.add_credits(1000)
	economy.add_wheat(1000)  # Lots of wheat to spam with
	economy.add_labor(1000)  # Starting labor
	print("   ✓ Economy: 1000 credits, 1000 wheat, 1000 labor")

	# Track initial state
	initial_wheat = economy.wheat_inventory
	initial_labor = economy.labor_inventory
	print("   ✓ Initial state tracked\n")


func _run_spam_test():
	"""Spam the plant→measure→harvest cycle 30 times"""
	print("🌱 SPAM CYCLE: Plant → Measure → Harvest (30 iterations)\n")
	print(_sep("─", 80))

	var plot_pos = Vector2i(0, 0)

	for cycle in range(1, 31):
		# Track wheat spent at start
		var wheat_before_plant = economy.wheat_inventory

		# STEP 1: PLANT
		farm.build(plot_pos, "wheat")
		var wheat_spent = wheat_before_plant - economy.wheat_inventory
		total_wheat_spent += wheat_spent

		# STEP 2: MEASURE (collapses quantum state randomly to 🌾 or 👥)
		var plot = farm.get_plot(plot_pos)
		farm.measure_plot(plot_pos)

		# STEP 3: HARVEST (get back what the quantum state collapsed to)
		var labor_before = economy.labor_inventory
		var wheat_before = economy.wheat_inventory
		farm.harvest_plot(plot_pos)

		# Track what was gained
		var wheat_gained = economy.wheat_inventory - wheat_before
		var labor_gained = economy.labor_inventory - labor_before

		if wheat_gained > 0:
			wheat_harvested_count += 1
			total_wheat_gained += wheat_gained
		if labor_gained > 0:
			labor_harvested_count += 1
			total_labor_gained += labor_gained

		# Print cycle result (every 10 cycles, or all if verbose)
		if cycle % 10 == 0 or cycle <= 5:
			var outcome = "?"
			if wheat_gained > 0:
				outcome = "🌾 wheat"
			elif labor_gained > 0:
				outcome = "👥 labor"
			print("[%2d/30] Spent %d 🌾 → Harvested %s | Balance: W:%+d L:%+d" % [
				cycle,
				wheat_spent,
				outcome,
				(total_wheat_gained - total_wheat_spent),
				total_labor_gained
			])

		cycles_completed += 1

	print(_sep("─", 80) + "\n")


func _report_results():
	"""Analyze resource balance"""
	print("\n" + _sep("═", 80))
	print("📊 ZERO-LOSS ANALYSIS")
	print(_sep("═", 80) + "\n")

	# Resource accounting
	print("📈 RESOURCES TRACKING:")
	print("   Cycles completed: %d" % cycles_completed)
	print("   🌾 Wheat spent (planting): %d" % total_wheat_spent)
	print("   🌾 Wheat harvested: %d (%d times)" % [total_wheat_gained, wheat_harvested_count])
	print("   👥 Labor harvested: %d (%d times)" % [total_labor_gained, labor_harvested_count])
	print()

	# Balance calculation (wheat and labor are equivalent currencies)
	var total_spent = total_wheat_spent
	var total_gained = total_wheat_gained + total_labor_gained
	var net_balance = total_gained - total_spent

	print("💰 BALANCE SHEET (all resources equivalent):")
	print("   Total spent: %d (wheat only)" % total_spent)
	print("   Total gained: %d (%d wheat + %d labor)" % [total_gained, total_wheat_gained, total_labor_gained])
	print("   Net balance: %+d (should be 0 for zero-loss)" % net_balance)
	print()

	# Zero-loss verification (all resources are equivalent currencies)
	var is_zero_loss = net_balance == 0
	print("✅ ZERO-LOSS CHECK: %s" % ("PASS ✓" if is_zero_loss else "FAIL ✗"))

	if is_zero_loss:
		print("   ✓ Perfect 1:1 recycling across chaos")
		print("   ✓ Resources in = Resources out")
		print("   ✓ Measurement creates chaotic but balanced output")
	else:
		print("   ⚠️  Net difference: %+d resources" % net_balance)
		if net_balance > 0:
			print("   ⚠️  System is inflating resources (gain > cost)")
		else:
			print("   ⚠️  System is losing resources (cost > gain)")

	print()

	# Chaos analysis
	print("🌀 CHAOS DISTRIBUTION:")
	var total_harvests = wheat_harvested_count + labor_harvested_count
	if total_harvests > 0:
		var wheat_pct = float(wheat_harvested_count) / total_harvests * 100
		var labor_pct = float(labor_harvested_count) / total_harvests * 100
		print("   🌾 Wheat outcomes: %d/%d (%.1f%%)" % [wheat_harvested_count, total_harvests, wheat_pct])
		print("   👥 Labor outcomes: %d/%d (%.1f%%)" % [labor_harvested_count, total_harvests, labor_pct])

		# Expected distribution should be ~50/50 for random quantum collapse
		var distribution_ok = wheat_pct > 30 and wheat_pct < 70
		print("   %s Random distribution looks good (30-70%% range)" % ("✓" if distribution_ok else "⚠️ "))
	print()

	# Current inventory
	print("📦 FINAL INVENTORY:")
	print("   🌾 Wheat: %d (started: %d, net: %+d)" % [
		economy.wheat_inventory,
		initial_wheat,
		economy.wheat_inventory - initial_wheat
	])
	print("   👥 Labor: %d (started: %d, net: %+d)" % [
		economy.labor_inventory,
		initial_labor,
		economy.labor_inventory - initial_labor
	])
	print()

	# Conclusion
	print(_sep("═", 80))
	if is_zero_loss:
		print("✅ TEST PASSED: Plant→Measure→Harvest spam is self-sustaining!")
		print("   • Zero loss: Resources perfectly recycled")
		print("   • Chaotic output: Random wheat/labor distribution")
		print("   • Indefinite: Can repeat forever without loss")
	else:
		print("❌ TEST FAILED: Resource leak detected!")
		print("   • Net imbalance: %+d resources" % net_balance)
	print(_sep("═", 80) + "\n")
