class_name ProbeActions
extends RefCounted

## ProbeActions - Core EXPLORE → MEASURE → POP gameplay loop (v2 Architecture)
##
## Implements the "Ensemble + Drain" model:
##   - ρ represents an ensemble of identically-prepared quantum systems
##   - EXPLORE: Bind terminal to register (no quantum effect)
##   - MEASURE: Sample via Born rule, DRAIN probability from ρ, record claim
##   - POP: Convert recorded probability to credits (no quantum effect)
##   - HARVEST: Global collapse, convert all probability, end level
##
## Physics:
##   - Ensemble interpretation: MEASURE samples without full collapse
##   - Drain simulates "extracting" from the ensemble
##   - External pump (sun) replenishes probability over time
##   - Creates sustainable farming loop: grow → harvest → regrow

const WeightedRandom = preload("res://Core/Utilities/WeightedRandom.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")


## ============================================================================
## EXPLORE ACTION - Bind terminal to register with probability weighting
## ============================================================================

static func action_explore(plot_pool, biome) -> Dictionary:
	"""Execute EXPLORE action: discover a register in the quantum soup.

	Algorithm:
	1. Get unbound terminal from pool
	2. Get unbound registers with probabilities from biome
	3. Weighted random selection (higher probability = more likely)
	4. Bind terminal to selected register
	5. Return result with emoji for bubble spawn

	Args:
		plot_pool: PlotPool instance
		biome: BiomeBase instance (the quantum soup to probe)

	Returns:
		Dictionary with keys:
		- success: bool
		- terminal: Terminal (if success)
		- register_id: int (if success)
		- emoji_pair: {north, south} (if success)
		- error: String (if failure)
	"""
	# 0. Null checks for required parameters
	if not plot_pool:
		return {
			"success": false,
			"error": "no_pool",
			"message": "Plot pool not initialized."
		}
	if not biome:
		return {
			"success": false,
			"error": "no_biome",
			"message": "Biome not initialized."
		}

	# 1. Get unbound terminal
	var terminal = plot_pool.get_unbound_terminal()
	if not terminal:
		return {
			"success": false,
			"error": "no_terminals",
			"message": "All terminals are bound. POP a measured terminal to free one."
		}

	# 2. Get unbound registers with probabilities (queries PlotPool for binding state)
	var probabilities = biome.get_register_probabilities(plot_pool)
	if probabilities.is_empty():
		return {
			"success": false,
			"error": "no_registers",
			"message": "No unbound registers available in this biome."
		}

	# 3. Weighted random selection using squared probabilities
	# This makes high-probability registers MORE likely to be discovered
	# Squaring ensures weights are always positive and emphasizes differences
	var register_ids: Array[int] = []
	var weights: Array[float] = []

	for reg_id in probabilities:
		register_ids.append(reg_id)
		var prob = probabilities[reg_id]
		# Use prob² for weighting (ensures positive, emphasizes high-prob states)
		weights.append(prob * prob)

	var selected_index = WeightedRandom.weighted_choice_index(weights)
	if selected_index < 0:
		return {
			"success": false,
			"error": "selection_failed",
			"message": "Weighted selection failed (all weights zero?)."
		}

	var selected_register = register_ids[selected_index]
	var selected_probability = weights[selected_index]

	# 4. Get emoji pair for this register
	var emoji_pair = biome.get_register_emoji_pair(selected_register)

	# 5. Bind terminal to register (Terminal is now the single source of truth)
	var bound = plot_pool.bind_terminal(terminal, selected_register, biome, emoji_pair)
	if not bound:
		return {
			"success": false,
			"error": "binding_failed",
			"message": "Failed to bind terminal to register (already bound?)."
		}

	# NOTE: No need to call mark_register_bound() - Terminal.is_bound is the source of truth
	# PlotPool.is_register_bound() queries Terminal directly

	return {
		"success": true,
		"terminal": terminal,
		"register_id": selected_register,
		"emoji_pair": emoji_pair,
		"probability": selected_probability
	}


## ============================================================================
## MEASURE ACTION - Sample from ensemble and drain probability
## ============================================================================

static func action_measure(terminal, biome) -> Dictionary:
	"""Execute MEASURE action: sample from ensemble, record claim, drain ρ.

	Ensemble Model:
	- ρ represents a statistical ensemble of quantum systems
	- MEASURE samples one outcome via Born rule
	- The sampled probability is RECORDED (the "claim" for POP)
	- ρ is DRAINED (probability reduced) but NOT fully collapsed
	- Sun/pump can replenish drained probability over time

	Algorithm:
	1. Validate terminal state
	2. Get current probability from ρ (this is the "claim")
	3. Born rule sampling → outcome
	4. Record the probability (stored on terminal)
	5. DRAIN ρ (reduce probability by DRAIN_FACTOR)
	6. Handle entangled registers (drain them too)
	7. Mark terminal as measured

	Args:
		terminal: Terminal instance (must be bound)
		biome: BiomeBase instance

	Returns:
		Dictionary with keys:
		- success: bool
		- outcome: String (emoji result)
		- recorded_probability: float (the "claim" for POP)
		- was_drained: bool
		- error: String (if failure)
	"""
	# 0. Null checks - terminal and biome must exist
	if not terminal:
		return {
			"success": false,
			"error": "no_terminal",
			"message": "No terminal to measure. Use EXPLORE first."
		}
	if not biome:
		return {
			"success": false,
			"error": "no_biome",
			"message": "Biome not initialized."
		}

	# 1. Validate terminal state consistency
	var state_error = terminal.validate_state()
	if state_error != "":
		push_warning("ProbeActions.action_measure: Terminal state invalid - %s" % state_error)
		return {
			"success": false,
			"error": "invalid_terminal_state",
			"message": "Terminal in invalid state: %s" % state_error
		}

	# 2. Validate terminal can be measured
	if not terminal.can_measure():
		if not terminal.is_bound:
			return {
				"success": false,
				"error": "not_bound",
				"message": "Terminal is not bound. Use EXPLORE first."
			}
		if terminal.is_measured:
			return {
				"success": false,
				"error": "already_measured",
				"message": "Terminal already measured. Use POP to harvest."
			}
		return {
			"success": false,
			"error": "cannot_measure",
			"message": "Terminal cannot be measured."
		}

	# 2. Get current probability from ρ (this becomes our "claim")
	var register_id = terminal.bound_register_id
	var north_prob = biome.get_register_probability(register_id) if biome else 0.5
	var south_prob = 1.0 - north_prob

	# 3. Born rule sampling
	var outcome: String
	var outcome_prob: float
	var is_north: bool

	if randf() < north_prob:
		outcome = terminal.north_emoji
		outcome_prob = north_prob
		is_north = true
	else:
		outcome = terminal.south_emoji
		outcome_prob = south_prob
		is_north = false

	# Handle edge case where emoji not set
	if outcome.is_empty():
		outcome = "?"

	# 4. Record the probability - this is the "claim" that POP will convert
	var recorded_probability = outcome_prob

	# 5. Check entanglement before drain
	var was_entangled = _check_entanglement(register_id, biome)
	var entangled_drains: Array = []

	# 6. DRAIN: Reduce probability in ρ (ensemble depletion)
	var drain_success = _drain_register(register_id, is_north, biome)

	# 7. Handle entangled registers (drain them too)
	if was_entangled and biome and biome.has_method("get_entangled_registers"):
		var entangled = biome.get_entangled_registers(register_id)
		for ent_reg_id in entangled:
			# Drain entangled partner with correlated outcome
			_drain_register(ent_reg_id, is_north, biome)  # Same direction for correlation
			entangled_drains.append(ent_reg_id)

	# 8. Mark terminal as measured with RECORDED probability
	terminal.mark_measured(outcome, recorded_probability)

	return {
		"success": true,
		"outcome": outcome,
		"probability": recorded_probability,  # Primary key (consistent with action_explore)
		"recorded_probability": recorded_probability,  # Alias for backward compatibility
		"was_entangled": was_entangled,
		"was_drained": drain_success,
		"drain_factor": EconomyConstants.DRAIN_FACTOR,
		"entangled_drains": entangled_drains,
		"register_id": register_id
	}


static func _check_entanglement(register_id: int, biome) -> bool:
	"""Check if register has significant off-diagonal coherence (entanglement)."""
	if not biome:
		return false
	if biome.has_method("get_coherence_with_other_registers"):
		var coherence = biome.get_coherence_with_other_registers(register_id)
		return coherence > 0.1  # Threshold for "visible" entanglement
	return false


static func _drain_register(register_id: int, is_north: bool, biome) -> bool:
	"""Drain probability from measured outcome in density matrix.

	Ensemble Model: We're "extracting" copies from the ensemble that
	were in the measured state. This reduces probability without full collapse.

	Args:
		register_id: Which register was measured
		is_north: true if outcome was north emoji
		biome: BiomeBase with density matrix

	Returns:
		true if drain was applied, false otherwise
	"""
	if not biome:
		return false

	# Try biome's drain method first (preferred)
	if biome.has_method("drain_register_probability"):
		biome.drain_register_probability(register_id, is_north, EconomyConstants.DRAIN_FACTOR)
		return true

	# Fallback: try to access density matrix directly
	if biome.has_method("get_density_matrix"):
		var dm = biome.get_density_matrix()
		if dm and dm.has_method("drain_diagonal"):
			dm.drain_diagonal(register_id, EconomyConstants.DRAIN_FACTOR)
			return true

	# Last resort: log warning
	print("ProbeActions: drain_register called but biome doesn't support drain")
	return false


static func _collapse_density_matrix(register_id: int, is_north: bool, biome) -> void:
	"""DEPRECATED: Use _drain_register for ensemble model.

	Full collapse is reserved for GLOBAL HARVEST action.
	Kept for backward compatibility.
	"""
	# For ensemble model, drain instead of collapse
	_drain_register(register_id, is_north, biome)


## ============================================================================
## POP ACTION - Convert recorded probability to credits
## ============================================================================

static func action_pop(terminal, plot_pool, economy = null) -> Dictionary:
	"""Execute POP action: convert recorded probability to credits.

	Ensemble Model:
	- The quantum effect (drain) already happened at MEASURE time
	- POP is purely classical bookkeeping
	- Credits = recorded_probability × CONVERSION_RATE
	- No further interaction with ρ

	Algorithm:
	1. Check terminal is measured
	2. Get recorded probability (the "claim" from MEASURE)
	3. Convert to credits: P × CONVERSION_RATE
	4. Add credits to economy
	5. Unbind terminal (return to pool)

	Args:
		terminal: Terminal instance (must be measured)
		plot_pool: PlotPool instance
		economy: FarmEconomy instance (optional, for credit tracking)

	Returns:
		Dictionary with keys:
		- success: bool
		- resource: String (emoji that was harvested)
		- recorded_probability: float (from MEASURE)
		- credits: float (probability × conversion rate)
		- terminal_id: String
	"""
	# 0. Null checks - terminal and plot_pool must exist
	if not terminal:
		return {
			"success": false,
			"error": "no_terminal",
			"message": "No terminal to harvest. Use MEASURE first."
		}
	if not plot_pool:
		return {
			"success": false,
			"error": "no_pool",
			"message": "Plot pool not initialized."
		}

	# 1. Validate terminal state consistency
	var state_error = terminal.validate_state()
	if state_error != "":
		push_warning("ProbeActions.action_pop: Terminal state invalid - %s" % state_error)
		return {
			"success": false,
			"error": "invalid_terminal_state",
			"message": "Terminal in invalid state: %s" % state_error
		}

	# 2. Validate terminal can be popped
	if not terminal.can_pop():
		if not terminal.is_bound:
			return {
				"success": false,
				"error": "not_bound",
				"message": "Terminal is not bound."
			}
		if not terminal.is_measured:
			return {
				"success": false,
				"error": "not_measured",
				"message": "Terminal not measured. Use MEASURE first."
			}
		return {
			"success": false,
			"error": "cannot_pop",
			"message": "Terminal cannot be popped."
		}

	# 2. Get recorded probability (the "claim" from MEASURE time)
	var resource = terminal.measured_outcome
	var recorded_prob = terminal.measured_probability
	var terminal_id = terminal.terminal_id
	var register_id = terminal.bound_register_id
	var biome = terminal.bound_biome

	# 3. Convert probability to credits (10x probability)
	var credits = recorded_prob * EconomyConstants.QUANTUM_TO_CREDITS

	# 4. Add resource to economy - use the MEASURED EMOJI as the resource type
	# Each emoji type becomes its own classical resource (🌾, 🍄, etc.)
	if economy:
		var resource_amount = int(credits)
		if resource_amount < 1:
			resource_amount = 1  # Minimum 1 unit per harvest
		economy.add_resource(resource, resource_amount, "pop")

	# 5. Unbind terminal (this is the ONLY mutation point for binding state)
	# Terminal.unbind() makes the register available again for future EXPLORE
	plot_pool.unbind_terminal(terminal)
	print("📤 Register %d released in %s" % [register_id, biome.get_biome_type() if biome.has_method("get_biome_type") else "biome"])

	# Calculate the resource amount that was added
	var resource_amount = int(credits)
	if resource_amount < 1:
		resource_amount = 1

	return {
		"success": true,
		"resource": resource,  # The emoji that was harvested (🌾, 🍄, etc.)
		"amount": resource_amount,  # Credits added (10x probability)
		"recorded_probability": recorded_prob,
		"credits": credits,
		"terminal_id": terminal_id,
		"register_id": register_id
	}


## ============================================================================
## HARVEST ACTION - Global collapse, end level
## ============================================================================

static func action_harvest_global(biome, plot_pool = null, economy = null) -> Dictionary:
	"""Execute HARVEST: collapse entire ensemble, convert all probability to credits.

	This is the "end of turn" action - true projective measurement of
	the entire quantum system. Unlike MEASURE (which drains), HARVEST
	fully collapses ρ and ends the level.

	Algorithm:
	1. Get all register probabilities from ρ
	2. Convert each to credits: P × CONVERSION_RATE
	3. Sum total credits
	4. Collapse ρ (make diagonal / fully decohered)
	5. Stop evolution
	6. Signal level complete

	Args:
		biome: BiomeBase instance
		plot_pool: PlotPool instance (optional, to clean up terminals)
		economy: FarmEconomy instance (optional, for credit tracking)

	Returns:
		Dictionary with keys:
		- success: bool
		- total_credits: float
		- harvested: Array[{register, outcome, probability, credits}]
		- level_complete: bool
	"""
	if not biome:
		return {
			"success": false,
			"error": "no_biome",
			"message": "No biome to harvest."
		}

	var total_credits: float = 0.0
	var harvested: Array = []

	# 1. Get all register probabilities
	var probabilities = biome.get_register_probabilities() if biome.has_method("get_register_probabilities") else {}

	if probabilities.is_empty():
		# Fallback: try to get register count and individual probabilities
		var num_registers = biome.get_register_count() if biome.has_method("get_register_count") else 0
		for reg_id in range(num_registers):
			var prob = biome.get_register_probability(reg_id) if biome.has_method("get_register_probability") else 0.5
			probabilities[reg_id] = prob

	# 2. Convert each register to credits (10x probability)
	for reg_id in probabilities:
		var prob = probabilities[reg_id]
		var credits = prob * EconomyConstants.QUANTUM_TO_CREDITS
		total_credits += credits

		# Get emoji for display
		var emoji_pair = biome.get_register_emoji_pair(reg_id) if biome.has_method("get_register_emoji_pair") else {}
		var outcome = emoji_pair.get("north", "?") if prob > 0.5 else emoji_pair.get("south", "?")

		harvested.append({
			"register": reg_id,
			"outcome": outcome,
			"probability": prob,
			"credits": credits
		})

	# 3. Add total credits to economy
	if economy:
		if economy.has_method("add_credits"):
			economy.add_credits(total_credits, "global_harvest")
		elif economy.has_method("add_resource"):
			economy.add_resource("credits", int(total_credits))

	# 4. Collapse density matrix (full decoherence)
	if biome.has_method("collapse_all_registers"):
		biome.collapse_all_registers()
	elif biome.has_method("decohere"):
		biome.decohere()

	# 5. Stop evolution
	if biome.has_method("stop_evolution"):
		biome.stop_evolution()

	# 6. Clean up any bound terminals
	if plot_pool and plot_pool.has_method("unbind_all_terminals"):
		plot_pool.unbind_all_terminals()

	return {
		"success": true,
		"total_credits": total_credits,
		"harvested": harvested,
		"level_complete": true
	}


## ============================================================================
## UTILITY FUNCTIONS
## ============================================================================

static func get_explore_preview(plot_pool, biome) -> Dictionary:
	"""Get preview info for EXPLORE action (for UI display).

	Returns:
		Dictionary with:
		- can_explore: bool
		- available_terminals: int
		- available_registers: int
		- top_probabilities: Array[{emoji, probability}]
	"""
	var available_terminals = plot_pool.get_unbound_count()
	var probabilities = biome.get_register_probabilities() if biome else {}

	# Get top 3 register probabilities for display
	var top_probs: Array = []
	var sorted_regs = probabilities.keys()
	sorted_regs.sort_custom(func(a, b): return probabilities[a] > probabilities[b])

	for i in range(min(3, sorted_regs.size())):
		var reg_id = sorted_regs[i]
		var emoji_pair = biome.get_register_emoji_pair(reg_id) if biome else {}
		top_probs.append({
			"emoji": emoji_pair.get("north", "?"),
			"probability": probabilities[reg_id]
		})

	return {
		"can_explore": available_terminals > 0 and not probabilities.is_empty(),
		"available_terminals": available_terminals,
		"available_registers": probabilities.size(),
		"top_probabilities": top_probs
	}


static func get_measure_preview(terminal, biome) -> Dictionary:
	"""Get preview info for MEASURE action (for UI display).

	Returns:
		Dictionary with:
		- can_measure: bool
		- north_emoji: String
		- south_emoji: String
		- north_probability: float
		- south_probability: float
	"""
	if not terminal or not terminal.is_bound or terminal.is_measured:
		return {
			"can_measure": false,
			"north_emoji": "",
			"south_emoji": "",
			"north_probability": 0.0,
			"south_probability": 0.0
		}

	var north_prob = biome.get_register_probability(terminal.bound_register_id) if biome else 0.5

	return {
		"can_measure": true,
		"north_emoji": terminal.north_emoji,
		"south_emoji": terminal.south_emoji,
		"north_probability": north_prob,
		"south_probability": 1.0 - north_prob
	}


static func get_pop_preview(terminal: RefCounted) -> Dictionary:
	"""Get preview info for POP action (for UI display).

	Returns:
		Dictionary with:
		- can_pop: bool
		- resource: String (emoji to harvest)
		- probability: float (what probability was at measure time)
	"""
	if not terminal or not terminal.is_measured:
		return {
			"can_pop": false,
			"resource": "",
			"probability": 0.0
		}

	return {
		"can_pop": true,
		"resource": terminal.measured_outcome,
		"probability": terminal.measured_probability
	}
