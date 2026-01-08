#!/usr/bin/env -S godot --headless -s
## Test: 3-Day Biotic Flux Soak vs No Biotic Flux
##
## Compare crop growth/energy evolution with and without biotic flux environment
## - Scenario A: Plant, wait 3 days WITH biotic flux, harvest
## - Scenario B: Plant, wait 3 days WITHOUT biotic flux, harvest
## - Compare yields and energy evolution

extends SceneTree

const Farm = preload("res://Core/Farm.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")

var farm_with_biome: Farm
var farm_without_biome: Farm
var economy: FarmEconomy

# Test parameters
const SOAK_DAYS = 3
const SECONDS_PER_DAY = 86400  # 24 * 60 * 60
const SOAK_TIME_SECONDS = SOAK_DAYS * SECONDS_PER_DAY

func _sep(char: String, count: int) -> String:
	var result = ""
	for _i in range(count):
		result += char
	return result

func _initialize():
	print("\n" + _sep("═", 80))
	print("🌱 TEST: 3-Day Biotic Flux Soak")
	print("Compare WITH vs WITHOUT biotic flux environment")
	print(_sep("═", 80) + "\n")

	_run_scenario_a()
	_run_scenario_b()
	_compare_results()

	quit(0)


func _run_scenario_a():
	"""Scenario A: Plant, soak 3 days WITH biotic flux, harvest"""
	print("🧪 SCENARIO A: WITH Biotic Flux Environment")
	print(_sep("─", 80))

	# Create farm WITH biome (biotic flux enabled)
	farm_with_biome = Farm.new()
	farm_with_biome._ready()
	economy = farm_with_biome.economy
	economy.add_wheat(100)

	print("\n  ✓ Farm created WITH biotic flux")
	print("  ✓ Biome enabled: %s" % farm_with_biome.biome_enabled)

	# Plant wheat at (0,0)
	var plant_pos = Vector2i(0, 0)
	farm_with_biome.build(plant_pos, "wheat")
	print("  ✓ Planted wheat at %s" % plant_pos)

	var plot_a = farm_with_biome.get_plot(plant_pos)
	var state_a_before = plot_a.quantum_state

	print("\n  📊 Before soak:")
	print("     Energy: %.3f" % state_a_before.energy)
	print("     Radius: %.3f" % state_a_before.radius)
	print("     Theta: %.3f rad" % state_a_before.theta)
	print("     Berry phase: %.3f" % state_a_before.berry_phase)

	# Simulate 3 days of biotic flux evolution
	print("\n  ⏳ Simulating %d days of biotic flux..." % SOAK_DAYS)
	_simulate_biome_evolution(farm_with_biome, plant_pos, SOAK_TIME_SECONDS)

	var state_a_after = plot_a.quantum_state
	print("\n  📊 After %d-day soak (WITH biotic flux):" % SOAK_DAYS)
	print("     Energy: %.3f (Δ %+.3f)" % [state_a_after.energy, state_a_after.energy - state_a_before.energy])
	print("     Radius: %.3f (Δ %+.3f)" % [state_a_after.radius, state_a_after.radius - state_a_before.radius])
	print("     Theta: %.3f rad (Δ %+.3f)" % [state_a_after.theta, state_a_after.theta - state_a_before.theta])
	print("     Berry phase: %.3f (Δ %+.3f)" % [state_a_after.berry_phase, state_a_after.berry_phase - state_a_before.berry_phase])

	# Measure and harvest
	print("\n  👁️  Measuring and harvesting...")
	farm_with_biome.measure_plot(plant_pos)
	var harvest_a = farm_with_biome.harvest_plot(plant_pos)

	var outcome_a = harvest_a.get("outcome", "?")
	var yield_a = harvest_a.get("yield", 0)

	print("     Outcome: %s" % outcome_a)
	print("     Yield: %d" % yield_a)
	print()


func _run_scenario_b():
	"""Scenario B: Plant, soak 3 days WITHOUT biotic flux, harvest"""
	print("\n🧪 SCENARIO B: WITHOUT Biotic Flux Environment")
	print(_sep("─", 80))

	# Create farm WITHOUT biome (biotic flux disabled)
	farm_without_biome = Farm.new()
	# Disable biome BEFORE initialization
	farm_without_biome.biome_enabled = false
	farm_without_biome._ready()
	var economy_b = farm_without_biome.economy
	economy_b.add_wheat(100)

	print("\n  ✓ Farm created WITHOUT biotic flux")
	print("  ✓ Biome enabled: %s" % farm_without_biome.biome_enabled)

	# Plant wheat at (0,0)
	var plant_pos = Vector2i(0, 0)
	farm_without_biome.build(plant_pos, "wheat")
	print("  ✓ Planted wheat at %s" % plant_pos)

	var plot_b = farm_without_biome.get_plot(plant_pos)
	var state_b_before = plot_b.quantum_state

	print("\n  📊 Before soak:")
	print("     Energy: %.3f" % state_b_before.energy)
	print("     Radius: %.3f" % state_b_before.radius)
	print("     Theta: %.3f rad" % state_b_before.theta)
	print("     Berry phase: %.3f" % state_b_before.berry_phase)

	# Simulate 3 days WITHOUT biotic flux evolution (just time passing)
	print("\n  ⏳ Simulating %d days (NO biotic flux)..." % SOAK_DAYS)
	_simulate_time_passage(farm_without_biome, SOAK_TIME_SECONDS)

	var state_b_after = plot_b.quantum_state
	print("\n  📊 After %d-day soak (NO biotic flux):" % SOAK_DAYS)
	print("     Energy: %.3f (Δ %+.3f)" % [state_b_after.energy, state_b_after.energy - state_b_before.energy])
	print("     Radius: %.3f (Δ %+.3f)" % [state_b_after.radius, state_b_after.radius - state_b_before.radius])
	print("     Theta: %.3f rad (Δ %+.3f)" % [state_b_after.theta, state_b_after.theta - state_b_before.theta])
	print("     Berry phase: %.3f (Δ %+.3f)" % [state_b_after.berry_phase, state_b_after.berry_phase - state_b_before.berry_phase])

	# Measure and harvest
	print("\n  👁️  Measuring and harvesting...")
	farm_without_biome.measure_plot(plant_pos)
	var harvest_b = farm_without_biome.harvest_plot(plant_pos)

	var outcome_b = harvest_b.get("outcome", "?")
	var yield_b = harvest_b.get("yield", 0)

	print("     Outcome: %s" % outcome_b)
	print("     Yield: %d" % yield_b)
	print()


func _simulate_biome_evolution(farm: Farm, plant_pos: Vector2i, time_seconds: float):
	"""Simulate biome evolution over time"""
	if not farm.biome_enabled or not farm.biome:
		print("     ⚠️  Biome not available, skipping evolution")
		return

	# The biome evolves qubits over time
	# We'll call the evolution multiple times to simulate passage of time
	var plot = farm.get_plot(plant_pos)
	if not plot or not plot.quantum_state:
		return

	# Simulate evolution in chunks (every hour for 3 days)
	var hours_to_simulate = int(time_seconds / 3600.0)
	var evolution_calls = minf(hours_to_simulate, 72)  # Cap at 72 calls to avoid infinite loop

	for hour in range(evolution_calls):
		if farm.biome and plot.quantum_state:
			# Call biome's evolution method if it exists
			# (This will naturally evolve the quantum state)
			farm.biome._process(3600.0)  # Simulate 1 hour of processing


func _simulate_time_passage(farm: Farm, time_seconds: float):
	"""Simulate time passage without biome evolution"""
	# Without biome, just let time pass (quantum state doesn't evolve)
	# In a real implementation, this would call _process() with delta time
	var plot = farm.get_plot(Vector2i(0, 0))
	if plot and plot.quantum_state:
		# Quantum state stays static without biome driving evolution
		pass


func _compare_results():
	"""Compare results from both scenarios"""
	print("\n" + _sep("═", 80))
	print("📊 COMPARISON: Biotic Flux Effect")
	print(_sep("═", 80))

	var plot_a = farm_with_biome.get_plot(Vector2i(0, 0))
	var plot_b = farm_without_biome.get_plot(Vector2i(0, 0))

	if plot_a and plot_b:
		print("\n🔬 QUANTUM STATE EVOLUTION:")
		print("\nWith Biotic Flux (A):")
		if plot_a.quantum_state:
			print("  Energy:      %.3f" % plot_a.quantum_state.energy)
			print("  Radius:      %.3f" % plot_a.quantum_state.radius)
			print("  Berry Phase: %.3f" % plot_a.quantum_state.berry_phase)

		print("\nWithout Biotic Flux (B):")
		if plot_b.quantum_state:
			print("  Energy:      %.3f" % plot_b.quantum_state.energy)
			print("  Radius:      %.3f" % plot_b.quantum_state.radius)
			print("  Berry Phase: %.3f" % plot_b.quantum_state.berry_phase)

		print("\n⚡ EFFECT OF BIOTIC FLUX (A - B):")
		if plot_a.quantum_state and plot_b.quantum_state:
			var energy_diff = plot_a.quantum_state.energy - plot_b.quantum_state.energy
			var radius_diff = plot_a.quantum_state.radius - plot_b.quantum_state.radius
			var berry_diff = plot_a.quantum_state.berry_phase - plot_b.quantum_state.berry_phase

			print("  Energy gain from flux:      %+.3f" % energy_diff)
			print("  Radius change from flux:    %+.3f" % radius_diff)
			print("  Berry phase gain from flux: %+.3f" % berry_diff)

			if energy_diff > 0.01:
				print("\n  ✓ Biotic flux INCREASES energy (crop gets stronger)")
			elif energy_diff < -0.01:
				print("\n  ✗ Biotic flux DECREASES energy (crop gets weaker)")
			else:
				print("\n  ~ Biotic flux has NO EFFECT on energy")

	print("\n" + _sep("═", 80) + "\n")
