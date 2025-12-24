class_name WheatPlot
extends "res://Core/GameMechanics/FarmPlot.gd"

## WheatPlot - Wheat crop with quantum constraints
## Specialized FarmPlot that adds wheat-specific quantum evolution
## Only handles: 🌾 (Natural Growth) ↔ 👥 (Labor) states

# Wheat-specific quantum parameters
var wheat_theta_stable: float = PI / 4.0  # Stable point for wheat growth
var wheat_spring_constant: float = 0.5    # Spring attraction strength

# Icon network references (for spring attraction)
var wheat_icon = null  # Icon that wheat is attracted to
var mushroom_icon = null  # Icon that competes with wheat
var icon_network = null  # Reference to icon network


func _init():
	super._init()
	plot_type = PlotType.WHEAT  # Always wheat
	theta_drift_rate = 0.1
	theta_entangled_target = PI / 2.0  # Entangled qubits stay uncertain
	theta_isolated_target = PI / 4.0   # Isolated wheat drifts toward growth


## Wheat-Specific Growth


func grow_wheat(delta: float, biome = null, icon_network_ref = null) -> float:
	"""Quantum evolution specific to wheat crops with spring attraction"""
	if not is_planted or not quantum_state:
		return 0.0

	# Update icon references if provided
	if icon_network_ref:
		icon_network = icon_network_ref

	# Apply spring attraction toward stable point (wheat growth)
	if icon_network and icon_network.has_method("get_icon"):
		wheat_icon = icon_network.get_icon("wheat")
		mushroom_icon = icon_network.get_icon("mushroom")

	# Spring attraction: pull theta toward stable point
	if wheat_icon:
		var spring_torque = wheat_spring_constant * (wheat_theta_stable - quantum_state.theta)
		quantum_state.theta += spring_torque * delta

	# Clamp theta to [0, PI]
	quantum_state.theta = clampf(quantum_state.theta, 0.0, PI)

	# Energy growth (biome evolution)
	if biome and biome.has_method("_evolve_quantum_substrate"):
		biome._evolve_quantum_substrate(delta)

	# Apply phase constraints
	if phase_constraint:
		phase_constraint.apply(quantum_state)

	return 0.0


## Wheat Harvest with Bonuses


func harvest_wheat() -> Dictionary:
	"""Harvest wheat with crop-specific bonuses"""
	if not is_planted or not quantum_state:
		return {"success": false}

	# Measure quantum state
	var outcome = quantum_state.measure()
	has_been_measured = true
	theta_frozen = true

	# Base yield for wheat (quantum energy units)
	# QUANTUM ECONOMY: Starting with 2 wheat, need 2x yield to sustain growth
	# With this yield (2), players can: plant 2 → harvest 4 → build mill (cost 3) in 2 cycles
	var base_yield = 2

	# Wheat-specific bonuses
	var bonus = 0.0

	# Entanglement bonus (each entangled plot adds 20%)
	if not entangled_plots.is_empty():
		bonus += entanglement_bonus * entangled_plots.size()

	# Berry phase bonus (5% per replant cycle)
	bonus += berry_phase_bonus * replant_cycles

	# Outcome factor (measuring in north state favors crop)
	if outcome == "north":  # Measured in 🌾 state = good
		bonus += 0.1  # Extra 10% bonus
	elif outcome == "south":  # Measured in 👥 state = reduced
		bonus -= observer_penalty

	var final_yield = max(0, base_yield + bonus)

	# Clear for next cycle
	is_planted = false
	replant_cycles += 1
	entangled_plots.clear()

	return {
		"success": true,
		"yield": final_yield,
		"outcome": outcome,
		"bonus": bonus,
		"crop_type": "wheat"
	}


## Override to ensure wheat-specific emojis


func get_plot_emojis() -> Dictionary:
	"""Wheat always has 🌾 ↔ 👥"""
	return {"north": "🌾", "south": "👥"}
