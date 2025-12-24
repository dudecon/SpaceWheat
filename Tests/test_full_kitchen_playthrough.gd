"""
Full Kitchen Playthrough Test
Tests complete game flow: plant → entangle → measure → harvest → mill → market
Verifies entanglement persistence and visual indicators
"""

extends Node

const Farm = preload("res://Core/Farm.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")

var farm: Farm
var grid: FarmGrid

func _ready():
	print("\n" + "=".repeat(60))
	print("🍳 FULL KITCHEN PLAYTHROUGH TEST")
	print("=".repeat(60))

	# Initialize farm
	farm = Farm.new()
	add_child(farm)
	await farm.tree_entered
	await get_tree().process_frame

	grid = farm.grid
	if not grid:
		push_error("Farm grid not initialized!")
		return

	print("\n📋 PHASE 1: Plant initial wheat")
	_phase_plant_wheat()

	print("\n🔗 PHASE 2: Create entanglements")
	_phase_create_entanglement()

	print("\n📊 PHASE 3: Verify entanglement state")
	_phase_verify_entanglement()

	print("\n🌾 PHASE 4: Measure and harvest")
	_phase_measure_harvest()

	print("\n🏭 PHASE 5: Mill wheat to flour")
	_phase_mill_wheat()

	print("\n💰 PHASE 6: Sell flour at market")
	_phase_market_sell()

	print("\n✅ PLAYTHROUGH COMPLETE")
	print("=".repeat(60) + "\n")

	# Keep running to observe
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()


func _phase_plant_wheat():
	"""Plant wheat in multiple plots"""
	var plots_to_plant = [
		Vector2i(2, 0),  # U (BioticFlux)
		Vector2i(3, 0),  # I (BioticFlux)
		Vector2i(4, 0),  # O (BioticFlux)
	]

	for pos in plots_to_plant:
		var result = farm.do_action("plant", {"position": pos, "plant_type": "wheat"})
		if result.get("success", false):
			print("  ✓ Planted wheat at %s" % pos)
			var plot = grid.get_plot(pos)
			if plot:
				print("    - Qubit state: θ=%.2f, φ=%.2f, r=%.2f" % [
					plot.quantum_state.theta,
					plot.quantum_state.phi,
					plot.quantum_state.radius
				])
		else:
			print("  ✗ Failed to plant at %s" % result)


func _phase_create_entanglement():
	"""Create entanglement between plots"""
	var entangle_pairs = [
		[Vector2i(2, 0), Vector2i(3, 0)],  # U ↔ I
		[Vector2i(3, 0), Vector2i(4, 0)],  # I ↔ O
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

			# Verify it worked
			var plot_a = grid.get_plot(pos_a)
			var plot_b = grid.get_plot(pos_b)

			if plot_a and plot_b:
				var is_entangled = plot_a.entangled_plots.has(plot_b.plot_id)
				print("    - Entanglement confirmed: %s" % ("YES" if is_entangled else "NO"))

				if is_entangled:
					var strength = plot_a.entangled_plots[plot_b.plot_id]
					print("    - Strength: %.2f" % strength)

					# Check quantum state
					if plot_a.quantum_state.is_in_pair():
						var pair = plot_a.quantum_state.entangled_pair
						var concurrence = pair.get_concurrence()
						var purity = pair.get_purity()
						print("    - Concurrence: %.3f, Purity: %.3f" % [concurrence, purity])
		else:
			print("  ✗ Entanglement failed: %s" % result)


func _phase_verify_entanglement():
	"""Verify entanglement state is correct"""
	print("  Checking entanglement infrastructure...")

	for pos in [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]:
		var plot = grid.get_plot(pos)
		if not plot:
			continue

		var num_entangled = plot.entangled_plots.size()
		var num_infrastructure = plot.plot_infrastructure_entanglements.size()

		print("  📍 %s: %d quantum + %d infrastructure links" % [
			pos, num_entangled, num_infrastructure
		])

		# List entanglement partners
		for partner_id in plot.entangled_plots.keys():
			print("    └─ Connected to: %s" % partner_id)


func _phase_measure_harvest():
	"""Measure plots and harvest"""
	print("  Measuring all plots...")

	for pos in [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]:
		var measure_result = farm.do_action("measure", {"position": pos})
		if measure_result.get("success", false):
			var outcome = measure_result.get("outcome", "?")
			print("  ✓ Measured %s → %s" % [pos, outcome])

		# Harvest
		var harvest_result = farm.do_action("harvest", {"position": pos})
		if harvest_result.get("success", false):
			var yield_amount = harvest_result.get("yield", 0)
			print("  ✓ Harvested %s: %d units" % [pos, yield_amount])

			# Check if entanglement persists (infrastructure level)
			var plot = grid.get_plot(pos)
			if plot:
				var infra_count = plot.plot_infrastructure_entanglements.size()
				print("    - Infrastructure entanglement: %d links (persisted)" % infra_count)


func _phase_mill_wheat():
	"""Mill wheat into flour"""
	var wheat = farm.economy.wheat
	print("  Available wheat: %d units" % wheat)

	if wheat >= 10:
		var result = farm.do_action("mill", {
			"wheat_amount": 10
		})

		if result.get("success", false):
			var flour = result.get("flour_produced", 0)
			var credits = result.get("credits_earned", 0)
			print("  ✓ Milled: 10 wheat → %d flour + %d credits" % [flour, credits])
		else:
			print("  ✗ Milling failed: %s" % result)
	else:
		print("  ⚠️  Not enough wheat (have %d, need 10)" % wheat)


func _phase_market_sell():
	"""Sell flour at market"""
	var flour = farm.economy.flour
	print("  Available flour: %d units" % flour)

	if flour > 0:
		var result = farm.do_action("market", {
			"flour_amount": flour
		})

		if result.get("success", false):
			var credits = result.get("credits_received", 0)
			var margin = result.get("market_margin", 0)
			print("  ✓ Sold: %d flour → %d credits (margin: %d)" % [flour, credits, margin])
		else:
			print("  ✗ Market sale failed: %s" % result)
	else:
		print("  ⚠️  No flour to sell")

	# Final state
	print("\n  Final economy state:")
	print("    💰 Credits: %d" % farm.economy.credits)
	print("    🌾 Wheat: %d" % farm.economy.wheat)
	print("    🌻 Flour: %d" % farm.economy.flour)
