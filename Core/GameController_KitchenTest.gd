"""
Kitchen Playthrough Test - Runs within the game context
Tests: plant → entangle → measure → harvest → mill → market
"""
extends Node

var test_active = false
var phase = 0

func _ready():
	if not test_active:
		return

	print("\n" + "=".repeat(60))
	print("🍳 KITCHEN PLAYTHROUGH TEST STARTING")
	print("=".repeat(60))

	phase = 0
	call_deferred("_run_next_phase")


func _run_next_phase():
	match phase:
		0:
			_phase_0_plant_wheat()
		1:
			_phase_1_create_entanglement()
		2:
			_phase_2_verify_entanglement()
		3:
			_phase_3_measure_harvest()
		4:
			_phase_4_mill()
		5:
			_phase_5_market()
		_:
			print("\n✅ TEST COMPLETE")
			get_tree().quit()

	phase += 1
	call_deferred("_run_next_phase")


func _phase_0_plant_wheat():
	print("\n📋 PHASE 0: Plant wheat")
	var farm = get_node("/root/FarmView/Farm")
	if not farm:
		print("  ERROR: Farm not found")
		return

	var grid = farm.grid
	if not grid:
		print("  ERROR: Grid not found")
		return

	# Plant in U, I, O (BioticFlux biome)
	var positions = [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
	for pos in positions:
		var result = farm.do_action("plant", {"position": pos, "plant_type": "wheat"})
		if result.get("success", false):
			print("  ✓ Planted at %s" % pos)
		else:
			print("  ✗ Failed at %s: %s" % [pos, result.get("message", "unknown error")])

	await get_tree().create_timer(0.5).timeout


func _phase_1_create_entanglement():
	print("\n🔗 PHASE 1: Create entanglement")
	var farm = get_node("/root/FarmView/Farm")
	var grid = farm.grid

	var entangle_pairs = [
		[Vector2i(2, 0), Vector2i(3, 0)],
		[Vector2i(3, 0), Vector2i(4, 0)],
	]

	for plot_pair in entangle_pairs:
		var pos_a = plot_pair[0]
		var pos_b = plot_pair[1]
		var result = farm.do_action("entangle", {
			"position_a": pos_a,
			"position_b": pos_b
		})

		if result.get("success", false):
			print("  ✓ Entangled %s ↔ %s" % [pos_a, pos_b])
		else:
			print("  ✗ Failed: %s" % result.get("message", "unknown"))

	await get_tree().create_timer(0.5).timeout


func _phase_2_verify_entanglement():
	print("\n📊 PHASE 2: Verify entanglement")
	var farm = get_node("/root/FarmView/Farm")
	var grid = farm.grid

	for pos in [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]:
		var plot = grid.get_plot(pos)
		if plot:
			var num_entangled = plot.entangled_plots.size()
			var num_infra = plot.plot_infrastructure_entanglements.size()
			print("  📍 %s: %d quantum, %d infrastructure links" % [pos, num_entangled, num_infra])

	await get_tree().create_timer(0.5).timeout


func _phase_3_measure_harvest():
	print("\n🌾 PHASE 3: Measure & Harvest")
	var farm = get_node("/root/FarmView/Farm")

	for pos in [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]:
		farm.do_action("measure", {"position": pos})
		var harvest_result = farm.do_action("harvest", {"position": pos})
		if harvest_result.get("success", false):
			var yield_amount = harvest_result.get("yield", 0)
			print("  ✓ Harvested %s: %d units" % [pos, yield_amount])

	print("  🌾 Wheat: %d" % farm.economy.wheat_inventory)
	await get_tree().create_timer(0.5).timeout


func _phase_4_mill():
	print("\n🏭 PHASE 4: Mill wheat")
	var farm = get_node("/root/FarmView/Farm")

	if farm.economy.wheat_inventory >= 10:
		var result = farm.do_action("mill", {"wheat_amount": 10})
		if result.get("success", false):
			var flour = result.get("flour_produced", 0)
			var credits = result.get("credits_earned", 0)
			print("  ✓ Milled: 10 wheat → %d flour + %d credits" % [flour, credits])

	print("  🌻 Flour: %d" % farm.economy.flour)
	print("  💰 Credits: %d" % farm.economy.credits)
	await get_tree().create_timer(0.5).timeout


func _phase_5_market():
	print("\n💰 PHASE 5: Market sale")
	var farm = get_node("/root/FarmView/Farm")

	if farm.economy.flour > 0:
		var result = farm.do_action("market", {"flour_amount": farm.economy.flour})
		if result.get("success", false):
			var credits = result.get("credits_received", 0)
			print("  ✓ Sold flour → %d credits" % credits)

	print("  Final state:")
	print("    💰 Credits: %d" % farm.economy.credits)
	print("    🌾 Wheat: %d" % farm.economy.wheat_inventory)
	print("    🌻 Flour: %d" % farm.economy.flour)
	await get_tree().create_timer(0.5).timeout
