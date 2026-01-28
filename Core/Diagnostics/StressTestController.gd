## Lightweight stress test controller that can be added to running farm
## Attach this to a node in the game scene to run stress tests during gameplay

extends Node

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

var farm: Node = null
var biotic_flux: Node = null
var plot_pool: Node = null
var economy: Node = null

# Test state
var test_active: bool = false
var num_cycles: int = 20
var cycle_count: int = 0

# Results
var cycle_history: Array = []
var terminal_count_history: Array = []
var coherence_history: Array = []
var sun_theta_history: Array = []

func _ready():
	# Try to find farm reference
	farm = get_node_or_null("/root/FarmView/Farm")
	if farm:
		biotic_flux = farm.biotic_flux_biome
		plot_pool = farm.plot_pool
		economy = farm.economy

func start_stress_test(cycles: int = 20):
	"""Start collecting stress test data"""
	if not farm or not biotic_flux or not plot_pool:
		push_error("StressTestController: Farm not initialized")
		return

	num_cycles = cycles
	cycle_count = 0
	test_active = true
	cycle_history.clear()
	terminal_count_history.clear()
	coherence_history.clear()
	sun_theta_history.clear()

	print("\n" + "=".repeat(80))
	print("STRESS TEST STARTED: %d cycles" % cycles)
	print("=".repeat(80))

func _process(_delta):
	if not test_active or cycle_count >= num_cycles:
		if test_active and cycle_count >= num_cycles:
			_print_results()
			test_active = false
		return

	_run_cycle()
	cycle_count += 1

	if cycle_count % 5 == 0:
		_print_progress()

func _run_cycle():
	"""Execute one EXPLORE → MEASURE → POP cycle"""
	var cycle_data = {
		"cycle": cycle_count,
		"bound_before": plot_pool.get_bound_terminals().size(),
		"unbound_before": plot_pool.get_unbound_terminals().size(),
		"explore_ok": false,
		"measure_ok": false,
		"pop_ok": false,
		"bound_after": 0,
		"coherence": 0.0,
		"sun_theta": 0.0,
		"trace": 1.0,
	}

	# EXPLORE
	var exp_result = ProbeActions.action_explore(plot_pool, biotic_flux)
	if not exp_result or not exp_result.success:
		cycle_history.append(cycle_data)
		return

	cycle_data["explore_ok"] = true
	var terminal = exp_result.terminal

	# MEASURE
	var meas_result = ProbeActions.action_measure(terminal, biotic_flux)
	if not meas_result or not meas_result.success:
		cycle_history.append(cycle_data)
		return

	cycle_data["measure_ok"] = true

	# POP
	var pop_result = ProbeActions.action_pop(terminal, plot_pool, economy, farm)
	cycle_data["pop_ok"] = pop_result and pop_result.success

	# COLLECT DATA
	cycle_data["bound_after"] = plot_pool.get_bound_terminals().size()

	# Coherence
	var coherences = []
	for t in plot_pool.get_bound_terminals():
		if t.bound_biome and t.north_emoji and t.south_emoji:
			var coh = biotic_flux.get_emoji_coherence(t.north_emoji, t.south_emoji)
			if coh:
				coherences.append(coh.abs())

	if coherences.size() > 0:
		var sum_coh = 0.0
		for c in coherences:
			sum_coh += c
		cycle_data["coherence"] = sum_coh / coherences.size()

	# Sun theta
	var p_sun = biotic_flux.quantum_computer.get_population("☀")
	var p_moon = biotic_flux.quantum_computer.get_population("🌙")
	if p_sun + p_moon > 0.001:
		cycle_data["sun_theta"] = 2.0 * acos(clamp(sqrt(p_sun / (p_sun + p_moon)), 0.0, 1.0))

	# Trace
	if biotic_flux.quantum_computer and biotic_flux.quantum_computer.density_matrix:
		cycle_data["trace"] = biotic_flux.quantum_computer.density_matrix.trace().re

	cycle_history.append(cycle_data)
	terminal_count_history.append(cycle_data["bound_after"])
	coherence_history.append(cycle_data["coherence"])
	sun_theta_history.append(cycle_data["sun_theta"])

func _print_progress():
	"""Print current progress"""
	if cycle_history.is_empty():
		return

	var latest = cycle_history[-1]
	print("Cycle %2d: bound=%d coh=%.4f sun=%.4f trace=%.4f %s" % [
		latest["cycle"],
		latest["bound_after"],
		latest["coherence"],
		latest["sun_theta"],
		latest["trace"],
		"✓" if (latest["explore_ok"] and latest["measure_ok"] and latest["pop_ok"]) else "✗"
	])

func _print_results():
	"""Print comprehensive test results"""
	print("\n" + "=".repeat(80))
	print("STRESS TEST RESULTS (%d cycles)" % cycle_count)
	print("=".repeat(80))

	# Success rate
	var explore_ok = 0
	var measure_ok = 0
	var pop_ok = 0

	for data in cycle_history:
		if data["explore_ok"]:
			explore_ok += 1
		if data["measure_ok"]:
			measure_ok += 1
		if data["pop_ok"]:
			pop_ok += 1

	print("\nSuccess Rate:")
	print("  EXPLORE: %d / %d" % [explore_ok, cycle_count])
	print("  MEASURE: %d / %d" % [measure_ok, cycle_count])
	print("  POP: %d / %d" % [pop_ok, cycle_count])

	# Terminal analysis
	print("\nTerminal Recycling:")
	if terminal_count_history.size() > 0:
		print("  Start: %d bound" % terminal_count_history[0])
		print("  End: %d bound" % terminal_count_history[-1])

		var max_bound = terminal_count_history.max()
		var min_bound = terminal_count_history.min()
		print("  Range: %d to %d" % [min_bound, max_bound])

		if terminal_count_history[-1] > 0:
			print("  ⚠️  ISSUE: Terminals not being recycled!")
		else:
			print("  ✓ Terminals properly recycled")

	# Coherence analysis
	print("\nCoherence:")
	var non_zero = coherence_history.filter(func(x): return x > 1e-6)
	if non_zero.size() > 0:
		var avg = non_zero.reduce(func(a, b): return a + b) / non_zero.size()
		print("  Avg (non-zero): %.6f" % avg)
		print("  Range: %.6f to %.6f" % [non_zero.min(), non_zero.max()])
		print("  ✓ Coherence varies (bubbles should look different)")
	else:
		print("  ❌ ISSUE: All coherence values are zero!")

	# Sun theta analysis
	print("\nSun Oscillation:")
	if sun_theta_history.size() > 1:
		var velocities = []
		for i in range(1, sun_theta_history.size()):
			velocities.append(abs(sun_theta_history[i] - sun_theta_history[i-1]))

		if velocities.size() > 0:
			var avg_vel = velocities.reduce(func(a, b): return a + b) / velocities.size()
			print("  Avg velocity: %.6f rad/cycle" % avg_vel)

			if velocities.size() >= 10:
				var early = velocities.slice(0, 5).reduce(func(a, b): return a + b) / 5.0
				var late = velocities.slice(-5).reduce(func(a, b): return a + b) / 5.0
				print("  Early avg: %.6f | Late avg: %.6f" % [early, late])
				if late > early * 1.5:
					print("  ⚠️  ISSUE: Oscillation is speeding up!")
				else:
					print("  ✓ Oscillation stable")
