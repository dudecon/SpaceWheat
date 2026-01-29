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

static func action_explore(plot_pool, biome, economy = null) -> Dictionary:
	"""Execute EXPLORE action: discover a register in the quantum soup.

	Algorithm:
	1. Check cost (🍞 bread)
	2. Get unbound terminal from pool
	3. Get unbound registers with probabilities from biome
	4. Weighted random selection (higher probability = more likely)
	5. Bind terminal to selected register
	6. Return result with emoji for bubble spawn

	Args:
		plot_pool: PlotPool instance
		biome: BiomeBase instance (the quantum soup to probe)
		economy: FarmEconomy instance (for cost deduction)

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
			"message": "All terminals are bound. POP a measured terminal to free one.",
			"blocked": true
		}

	# 2. Check for unbound registers (availability gate)
	var available_registers = biome.get_available_registers_v2(plot_pool) if biome.has_method("get_available_registers_v2") else []
	if available_registers.is_empty():
		return {
			"success": false,
			"error": "no_registers",
			"message": "Explore blocked: no unbound registers in this biome.",
			"blocked": true
		}

	# 2b. Check and deduct cost (after availability gates)
	if economy and not EconomyConstants.try_action("explore", economy):
		var cost = EconomyConstants.get_action_cost("explore")
		var missing = cost.keys()[0] if cost.size() > 0 else "resources"
		return {
			"success": false,
			"error": "insufficient_resources",
			"message": "Need %s to explore." % missing
		}

	# 3. Get unbound registers with probabilities (queries PlotPool for binding state)
	var probabilities = biome.get_register_probabilities(plot_pool)
	if probabilities.is_empty():
		return {
			"success": false,
			"error": "no_registers",
			"message": "Explore blocked: no unbound registers in this biome.",
			"blocked": true
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
			"message": "Explore blocked: weighted selection failed (all weights zero?).",
			"blocked": true
		}

	var selected_register = register_ids[selected_index]
	var selected_probability = weights[selected_index]

	# 4. Get emoji pair for this register
	var emoji_pair = biome.get_register_emoji_pair(selected_register)

	# 5. Get biome name for binding (decouple from object reference)
	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name

	# 6. Bind terminal to register with biome NAME (Terminal is now the single source of truth)
	var bound = plot_pool.bind_terminal(terminal, selected_register, biome_name, emoji_pair)
	if not bound:
		return {
			"success": false,
			"error": "binding_failed",
			"message": "Failed to bind terminal to register (already bound?).",
			"blocked": true
		}

	# NOTE: No need to call mark_register_bound() - Terminal.is_bound is the source of truth
	# PlotPool.is_register_bound() queries Terminal directly

	return {
		"success": true,
		"terminal": terminal,
		"register_id": selected_register,
		"emoji_pair": emoji_pair,
		"probability": selected_probability,
		"biome_name": biome_name
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
			"message": "No terminal to measure. Use EXPLORE first.",
			"blocked": true
		}
	if not biome:
		return {
			"success": false,
			"error": "no_biome",
			"message": "Biome not initialized.",
			"blocked": true
		}

	# 1. Validate terminal state consistency
	var state_error = terminal.validate_state()
	if state_error != "":
		return {
			"success": false,
			"error": "invalid_terminal_state",
			"message": "Terminal in invalid state: %s" % state_error,
			"blocked": true
		}

	# 2. Validate terminal can be measured
	if not terminal.can_measure():
		if not terminal.is_bound:
			return {
				"success": false,
				"error": "not_bound",
				"message": "Terminal is not bound. Use EXPLORE first.",
				"blocked": true
			}
		if terminal.is_measured:
			return {
				"success": false,
				"error": "already_measured",
				"message": "Terminal already measured. Use POP to harvest.",
				"blocked": true
			}
		return {
			"success": false,
			"error": "cannot_measure",
			"message": "Terminal cannot be measured.",
			"blocked": true
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
	var measured_purity = 1.0
	if biome and biome.quantum_computer:
		measured_purity = biome.quantum_computer.get_purity()
	terminal.mark_measured(outcome, recorded_probability, measured_purity)

	# 9. FREE THE REGISTER - allow another terminal to bind to it
	# Terminal keeps its measurement snapshot for REAP to harvest
	terminal.release_register()

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
	_log("warn", "quantum", "⚠️", "ProbeActions: drain_register called but biome doesn't support drain")
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

static func action_pop(terminal, plot_pool, economy = null, farm = null) -> Dictionary:
	"""Pop action: harvest the terminal and clean up relay."""
	var harvest_result = _prepare_pop_result(terminal, plot_pool, economy, farm)
	if not harvest_result.get("success", false):
		return harvest_result

	# Capture biome name before unbinding
	var biome_name = harvest_result.get("biome_name", "")
	if biome_name == "":
		biome_name = terminal.measured_biome_name if terminal.measured_biome_name != "" else terminal.bound_biome_name
	var register_id = harvest_result.get("register_id", -1)

	plot_pool.unbind_terminal(terminal)
	_log("info", "farm", "📤", "Register %d released in %s" % [register_id, biome_name if biome_name else "biome"])

	return harvest_result


static func action_reap(terminal, plot_pool, economy = null, farm = null) -> Dictionary:
	"""Reap action: harvest the terminal and unbind it.

	Costs 1 👥 labor to claim the harvest.
	Harvests the recorded probability (captured at MEASURE time, after 50% drain).
	Terminal is unbound after reaping, ready for a new EXPLORE.
	"""
	# Preflight: ensure terminal can be harvested before charging
	var preflight = _prepare_pop_result(terminal, plot_pool, null, farm)
	if not preflight.get("success", false):
		return preflight

	# Check and deduct cost (after preflight)
	if economy and not EconomyConstants.try_action("reap", economy):
		return {
			"success": false,
			"error": "insufficient_resources",
			"message": "Need 👥 labor to reap harvest."
		}

	var harvest_result = _prepare_pop_result(terminal, plot_pool, economy, farm)

	# Capture biome name before unbinding (String, not object)
	var biome_name = harvest_result.get("biome_name", "")
	if biome_name == "":
		biome_name = terminal.measured_biome_name if terminal.measured_biome_name != "" else terminal.bound_biome_name

	# Unbind terminal after reaping (returns it to pool)
	plot_pool.unbind_terminal(terminal)
	_log("info", "farm", "📤", "Terminal reaped in %s" % [biome_name if biome_name else "biome"])

	return harvest_result


static func _prepare_pop_result(terminal, plot_pool, economy = null, farm = null) -> Dictionary:
	"""Shared harvesting logic used by both pop/reap."""
	if not terminal:
		return {
			"success": false,
			"error": "no_terminal",
			"message": "No terminal to harvest. Use MEASURE first.",
			"blocked": true
		}
	if not plot_pool:
		return {
			"success": false,
			"error": "no_pool",
			"message": "Plot pool not initialized.",
			"blocked": true
		}

	var state_error = terminal.validate_state()
	if state_error != "":
		return {
			"success": false,
			"error": "invalid_terminal_state",
			"message": "Terminal in invalid state: %s" % state_error,
			"blocked": true
		}

	if not terminal.can_pop():
		if not terminal.is_measured:
			return {
				"success": false,
				"error": "not_measured",
				"message": "Terminal not measured. Use MEASURE first.",
				"blocked": true
			}
		return {
			"success": false,
			"error": "cannot_pop",
			"message": "Terminal cannot be popped.",
			"blocked": true
		}

	var resource = terminal.measured_outcome
	var recorded_prob = terminal.measured_probability
	var terminal_id = terminal.terminal_id
	var register_id = terminal.measured_register_id
	var biome_name = terminal.measured_biome_name
	var purity = terminal.measured_purity

	if purity <= 0.0:
		purity = 1.0

	var neighbor_count = 4
	if farm and farm.grid and terminal.grid_position != Vector2i(-1, -1):
		var neighbors = farm.grid.get_neighbors(terminal.grid_position)
		neighbor_count = neighbors.size()

	var credits = recorded_prob * purity * neighbor_count

	if economy:
		var resource_amount = int(credits)
		if resource_amount < 1:
			resource_amount = 1
		economy.add_resource(resource, resource_amount, "pop")

	var resource_amount = int(credits)
	if resource_amount < 1:
		resource_amount = 1

	return {
		"success": true,
		"resource": resource,
		"amount": resource_amount,
		"recorded_probability": recorded_prob,
		"purity": purity,
		"neighbor_count": neighbor_count,
		"credits": credits,
		"terminal_id": terminal_id,
		"register_id": register_id,
		"biome_name": biome_name
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
## HARVEST ALL ACTION - End of Turn (3R)
## ============================================================================

static func action_harvest_all(plot_pool, economy = null, biome = null) -> Dictionary:
	"""Execute HARVEST ALL action: end of turn, pop all terminals, collect resources.

	Harvests all bound terminals and applies Reality Midwife token multiplier.

	System:
	- Multiplier = token count (before cost deduction)
	- Cost = 1 token (fixed cost, same as other actions)
	- Resources = base × multiplier

	Examples:
	  1 token → 1x resources, costs 1, leaves 0
	  2 tokens → 2x resources, costs 1, leaves 1
	  3 tokens → 3x resources, costs 1, leaves 2
	  5 tokens → 5x resources, costs 1, leaves 4

	Args:
		plot_pool: PlotPool instance with bound terminals
		economy: FarmEconomy instance (optional, for credit tracking)
		biome: BiomeBase instance (optional, for state snapshot)

	Returns:
		Dictionary with keys:
		- success: bool
		- state_saved: bool
		- terminals_harvested: int
		- midwife_multiplier: float (token count)
		- token_cost: float (amount deducted)
		- resource_totals: Dictionary of harvested resources
		- bonus_applied: Dictionary of bonus resources
	"""
	# 0. Null check for plot_pool
	if not plot_pool:
		return {
			"success": false,
			"error": "no_pool",
			"message": "Plot pool not initialized."
		}

	# 1. Get midwife token count BEFORE deduction (determines multiplier)
	var token_emoji = EconomyConstants.MIDWIFE_EMOJI
	var midwife_token_count = 0
	if economy and economy.has_method("get_resource"):
		midwife_token_count = economy.get_resource(token_emoji)

	# Multiplier = token count (snapshot before cost)
	var midwife_multiplier: float = float(midwife_token_count)

	# 2. Deduct fixed cost (1 token)
	var token_cost: float = 0.0
	if economy and not EconomyConstants.try_action("harvest_all", economy):
		# Insufficient tokens - harvest fails
		return {
			"success": false,
			"error": "insufficient_resources",
			"message": "Need 🍼 Reality Midwife token to harvest."
		}

	# Cost was deducted, record it
	var cost_dict = EconomyConstants.get_action_cost("harvest_all")
	token_cost = cost_dict.get(token_emoji, 0.0)

	# 3. Save density matrix state snapshot
	var state_snapshot = _save_density_matrices(biome)

	# 4. Harvest density matrix directly (no measurement collapse)
	# Get resources from BOTH north and south emojis weighted by probability
	var harvest_results: Array = []
	var total_credits: float = 0.0
	var terminals_to_harvest: Array = []
	var resource_totals: Dictionary = {}  # Track harvested resources by emoji

	# Collect all measured terminals first (to avoid modifying while iterating)
	# Note: After MEASURE, terminals are no longer bound (register released)
	# but they still have their measurement data (is_measured=true)
	if plot_pool.has_method("get_all_terminals"):
		for terminal in plot_pool.get_all_terminals():
			if terminal and terminal.is_measured:
				terminals_to_harvest.append(terminal)

	# Harvest each terminal using saved measurement data
	for terminal in terminals_to_harvest:
		# Use saved measurement probability (from when terminal was measured)
		# Note: After measure + release_register, terminal is no longer bound
		# but still has measured_probability and measured_outcome
		var probability = terminal.measured_probability if terminal.measured_probability > 0 else 0.5
		var outcome = terminal.measured_outcome

		# Determine north/south probabilities based on outcome
		var north_prob = 0.5
		var south_prob = 0.5
		if outcome == terminal.north_emoji:
			# Measured north - use saved probability
			north_prob = probability
			south_prob = 1.0 - probability
		elif outcome == terminal.south_emoji:
			# Measured south - use saved probability
			south_prob = probability
			north_prob = 1.0 - probability

		# Get purity bonus from biome (use first available biome if terminal not bound)
		var terminal_biome = biome
		var purity = 1.0
		if terminal_biome and terminal_biome.quantum_computer:
			purity = terminal_biome.quantum_computer.get_purity()

		# Harvest BOTH emojis weighted by probability
		var north_credits = int(north_prob * purity * 10)  # Scale by 10 for meaningful amounts
		var south_credits = int(south_prob * purity * 10)

		if north_credits > 0 and terminal.north_emoji != "":
			if not resource_totals.has(terminal.north_emoji):
				resource_totals[terminal.north_emoji] = 0
			resource_totals[terminal.north_emoji] += north_credits
			total_credits += north_credits

		if south_credits > 0 and terminal.south_emoji != "":
			if not resource_totals.has(terminal.south_emoji):
				resource_totals[terminal.south_emoji] = 0
			resource_totals[terminal.south_emoji] += south_credits
			total_credits += south_credits

		# Store grid position before unbinding (needed for signal emission)
		var grid_pos = terminal.grid_position

		# Unbind terminal after harvesting
		plot_pool.unbind_terminal(terminal)

		harvest_results.append({
			"terminal_id": terminal.terminal_id,
			"grid_position": grid_pos,
			"north_emoji": terminal.north_emoji,
			"north_prob": north_prob,
			"north_credits": north_credits,
			"south_emoji": terminal.south_emoji,
			"south_prob": south_prob,
			"south_credits": south_credits,
			"total_credits": north_credits + south_credits
		})

	# 5. Apply multiplier to harvested resources (resources = base × multiplier)
	var bonus_applied: Dictionary = {}
	if midwife_multiplier > 0 and economy and economy.has_method("add_resource"):
		for emoji in resource_totals:
			var base_amount = resource_totals[emoji]
			var total_amount = int(base_amount * midwife_multiplier)
			economy.add_resource(emoji, total_amount, "density_harvest")

			# Track bonus for logging (bonus = total - base)
			var bonus_amount = total_amount - base_amount
			if bonus_amount > 0:
				bonus_applied[emoji] = bonus_amount

		if bonus_applied.size() > 0:
			_log("info", "economy", "🍼", "Midwife %.1fx multiplier applied (cost: %.1f tokens)" % [midwife_multiplier, token_cost])
			for emoji in bonus_applied:
				var total_resources = int(resource_totals[emoji] * midwife_multiplier)
				_log("info", "economy", "   ", "%s: +%d bonus (total: %d)" % [emoji, bonus_applied[emoji], total_resources])
	elif midwife_multiplier == 0 and economy:
		_log("warn", "economy", "⚠️", "No Reality Midwife tokens - harvest yields 0 resources")

	return {
		"success": true,
		"state_saved": state_snapshot != null,
		"terminals_harvested": harvest_results.size(),
		"total_credits": total_credits,
		"midwife_multiplier": midwife_multiplier,
		"token_cost": token_cost,
		"bonus_applied": bonus_applied,
		"resource_totals": resource_totals,
		"harvest_results": harvest_results,
		"state_snapshot": state_snapshot
	}


static func action_clear_all(plot_pool) -> Dictionary:
	"""Clear all terminals: unbind without harvesting.

	Releases all bound terminals and their registers without collecting resources.
	Use this to reset the grid and start fresh exploration.

	Args:
		plot_pool: PlotPool instance

	Returns:
		Dictionary with keys:
		- success: bool
		- terminals_cleared: int (number of terminals unbound)
	"""
	if not plot_pool:
		return {
			"success": false,
			"error": "no_pool",
			"message": "Plot pool not initialized."
		}

	var cleared_count = 0
	var terminals_to_clear: Array = []

	# Collect all bound terminals
	if plot_pool.has_method("get_all_terminals"):
		for terminal in plot_pool.get_all_terminals():
			if terminal and terminal.is_bound:
				terminals_to_clear.append(terminal)

	# Unbind each terminal (no harvesting)
	for terminal in terminals_to_clear:
		plot_pool.unbind_terminal(terminal)
		cleared_count += 1
	
	_log("info", "farm", "🧹", "Cleared %d terminals (no harvest)" % cleared_count)

	return {
		"success": true,
		"terminals_cleared": cleared_count
	}


static func _save_density_matrices(biome) -> Dictionary:
	"""Save density matrix state snapshot for all registers.

	Returns a dictionary with serialized density matrix data.
	"""
	if not biome:
		return {}

	var snapshot = {
		"timestamp": Time.get_ticks_msec(),
		"biome_type": biome.get_biome_type() if biome.has_method("get_biome_type") else "unknown"
	}

	# Try to get density matrix from biome
	if biome.has_method("get_density_matrix"):
		var dm = biome.get_density_matrix()
		if dm and dm.has_method("serialize"):
			snapshot["density_matrix"] = dm.serialize()
		elif dm and dm.has_method("get_state"):
			snapshot["density_matrix"] = dm.get_state()

	# Try to get register states
	if biome.has_method("get_register_probabilities"):
		snapshot["probabilities"] = biome.get_register_probabilities()

	return snapshot


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

# ============================================================================
# INTERNAL HELPERS
# ============================================================================


static func _log(level: String, category: String, emoji: String, message: String) -> void:
	var tree = Engine.get_main_loop()
	if not tree: return
	var verbose = tree.root.get_node_or_null("/root/VerboseConfig")
	if not verbose:
		if level == "error": push_error("[%s] %s" % [category.to_upper(), message])
		elif level == "warn": push_warning("[%s] %s" % [category.to_upper(), message])
		else: print("[%s] %s" % [category.to_upper(), message])
		return

	match level:
		"trace": verbose.trace(category, emoji, message)
		"debug": verbose.debug(category, emoji, message)
		"info": verbose.info(category, emoji, message)
		"warn": verbose.warn(category, emoji, message)
		"error": verbose.error(category, emoji, message)
