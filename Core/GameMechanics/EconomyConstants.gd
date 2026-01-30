class_name EconomyConstants
extends RefCounted

## ===========================================
## UNIFIED ECONOMIC CONSTANTS
## ===========================================
## Single source of truth for all economic values.
## No universal currency - all resources are [emoji]-credits.

## ===========================================
## QUANTUM ↔ CLASSICAL CONVERSION
## ===========================================

## Base conversion rate: 1 quantum probability unit = X emoji-credits
const QUANTUM_TO_CREDITS: float = 10.0

## Reality Midwife token emoji (display + economy tracking)
const MIDWIFE_EMOJI: String = "🍼"

## DEPRECATED: Harvest-all cost is now dynamic (1 if >2 tokens, half if <=2)
## Kept for backward compatibility with UI preview
const MIDWIFE_ACTION_COST: int = 1

## Drain factor: fraction of probability removed during MEASURE
const DRAIN_FACTOR: float = 0.5

## ===========================================
## PRODUCTION EFFICIENCY
## ===========================================

const MILL_EFFICIENCY: float = 0.8    # 10 wheat → 8 flour + 40 💰
const KITCHEN_EFFICIENCY: float = 0.6 # 5 flour → 3 bread

## ===========================================
## ACTION COSTS (Classical Resources as Sink)
## ===========================================
## All costs are in raw credits (the numbers stored in emoji_credits).
## Unified table: action_name → cost dictionary

const ACTION_COSTS: Dictionary = {
	"explore": {"🍞": 1},       # Send probe
	"measure": {"❄️": 1},       # Measure (3E) - cold/ice
	"reap": {"👥": 1},          # Claim harvest (labor)
	"harvest_all": {"🍼": 1},   # End of turn harvest (costs 1 Reality Midwife token)
	"quest_reroll": {"🐇": 1},   # Reroll quest slot
	"quest_lock": {"🌲": 1},     # Lock quest slot
	"explore_biome": {"🦅": 20},# Scout new biome
	"remove_vocabulary": {"🐺": 20} # Remove vocabulary: penalize with wolf cost
	# vocab_injection is dynamic - use get_action_cost()
}

## ===========================================
## QUANTUM GATE COSTS
## ===========================================
## All quantum gate operations cost resources from starter biomes.
## Costs are in emoji-credits (1 emoji = base cost).

const GATE_COSTS: Dictionary = {
	# Pauli gates - fundamental bit/phase flips
	"pauli_x": {"☀": 1},        # Sun - bit flip (most common)
	"pauli_y": {"🌙": 1},        # Moon - bit+phase flip
	"pauli_z": {"🍂": 1},        # Detritus - phase flip only

	# Other single-qubit gates
	"hadamard": {"🔥": 1},       # Fire - superposition
	"s_gate": {"🌱": 1},         # Sprout - phase rotation
	"t_gate": {"🌿": 1},         # Herb - π/8 phase

	# Two-qubit gates - entanglement and control
	"cnot": {"🍄": 1},           # Mushroom - entanglement (mycelial networks)
	"cz": {"🦌": 1},             # Deer - controlled-phase
	"swap": {"🐺": 1},           # Wolf - swap qubits
}

## Vocab injection dynamic costs
const VOCAB_INJECTION_SOUTH_COST: int = 100
const VOCAB_INJECTION_SPROUT_COST: Dictionary = {"🌱": 10}

## ===========================================
## BUILD MODE COSTS (Legacy)
## ===========================================

## DEPRECATED: Use VOCAB_INJECTION_SOUTH_COST + VOCAB_INJECTION_SPROUT_COST instead
const VOCAB_INJECTION_BASE_COST: int = 150

## Hard cap on biome qubits (enforced by actions, not by the quantum computer)
const MAX_BIOME_QUBITS: int = 12

## Planting costs (emoji → cost in 💰-credits)
const PLANTING_COSTS: Dictionary = {
	"🌾": 10,   # wheat - basic
	"🌻": 15,   # sunflower
	"🍄": 20,   # mushroom
	"🔥": 50,   # fire - dangerous
	"⚡": 50,   # energy - volatile
}

const DEFAULT_PLANTING_COST: int = 25

## ===========================================
## PLANT TYPE → EMOJI PAIR MAPPING
## ===========================================
## Central registry for all plant types and their quantum axes.
## Used for dynamic capability creation in BUILD mode.

const PLANT_TYPE_EMOJIS: Dictionary = {
	"wheat": {"north": "🌾", "south": "🍄"},
	"mushroom": {"north": "🍄", "south": "🌾"},
	"tomato": {"north": "🍅", "south": "🌿"},
	"vegetation": {"north": "🌿", "south": "🍂"},
	"rabbit": {"north": "🐇", "south": "🐺"},
	"wolf": {"north": "🐺", "south": "🐇"},
	"fire": {"north": "🔥", "south": "❄️"},
	"water": {"north": "💧", "south": "🏜️"},
	"flour": {"north": "💨", "south": "🌾"},
	"bread": {"north": "🍞", "south": "💨"},
	"bull": {"north": "🐂", "south": "🐻"},
	"bear": {"north": "🐻", "south": "🐂"},
	"money": {"north": "💰", "south": "💳"},
	"credit": {"north": "💳", "south": "💰"},
	"sun": {"north": "☀", "south": "🌙"},
	"moon": {"north": "🌙", "south": "☀"},
}

## ===========================================
## CONVERSION FUNCTIONS
## ===========================================

static func quantum_to_credits(probability: float) -> int:
	"""Convert quantum probability to emoji-credits"""
	return int(probability * QUANTUM_TO_CREDITS)


static func get_planting_cost(emoji: String) -> int:
	"""Get cost in 💰-credits to plant a specific emoji"""
	return PLANTING_COSTS.get(emoji, DEFAULT_PLANTING_COST)


static func get_plant_type_emojis(plant_type: String) -> Dictionary:
	"""Get emoji pair for a plant type.

	Returns {"north": emoji, "south": emoji} or empty dict if not found.
	"""
	return PLANT_TYPE_EMOJIS.get(plant_type, {})


static func get_vocab_injection_cost(south_emoji: String) -> Dictionary:
	"""Get cost dictionary for vocabulary injection.

	Cost = 100 of south-pole emoji + 10 sprouts (🌱)
	Returns dictionary of {emoji: amount} for costs.

	Args:
		south_emoji: The south pole emoji of the pair being injected
	"""
	if south_emoji == "":
		return VOCAB_INJECTION_SPROUT_COST.duplicate()

	var cost = VOCAB_INJECTION_SPROUT_COST.duplicate()
	cost[south_emoji] = VOCAB_INJECTION_SOUTH_COST
	return cost


static func can_afford(economy, costs: Dictionary) -> bool:
	"""Check if economy can afford the given costs"""
	if not economy:
		print("DEBUG can_afford: economy is null")
		return false
	if economy.has_method("can_afford_cost"):
		var result = economy.can_afford_cost(costs)
		print("DEBUG can_afford: can_afford_cost returned ", result, " for costs ", costs)
		return result
	if economy.has_method("can_afford_resource"):
		for emoji in costs:
			var amount = costs[emoji]
			var has = economy.get_resource(emoji) if economy.has_method("get_resource") else -1
			print("DEBUG can_afford: checking emoji '", emoji, "' (", emoji.length(), " chars) need ", amount, " have ", has)
			if not economy.can_afford_resource(emoji, amount):
				print("DEBUG can_afford: FAILED - cannot afford ", emoji)
				return false
		return true
	print("DEBUG can_afford: economy has no can_afford methods")
	return false


static func spend(economy, costs: Dictionary, reason: String = "purchase") -> bool:
	"""Spend resources from economy. Returns true if successful."""
	if not can_afford(economy, costs):
		return false
	if economy.has_method("spend_cost"):
		return economy.spend_cost(costs, reason)
	if economy.has_method("spend_resource"):
		for emoji in costs:
			var amount = costs[emoji]
			economy.spend_resource(emoji, amount, reason)
		return true
	return false


static func preflight_cost(costs: Dictionary, economy) -> Dictionary:
	"""Check affordability for a cost dictionary without spending.

	Returns: {ok: bool, cost: Dictionary, message?: String}
	"""
	if costs.is_empty():
		return {"ok": true, "cost": costs}
	if not economy:
		return {"ok": false, "cost": costs, "message": "Economy not available"}
	if not can_afford(economy, costs):
		return {"ok": false, "cost": costs, "message": "Insufficient resources"}
	return {"ok": true, "cost": costs}


static func commit_cost(costs: Dictionary, economy, reason: String = "") -> bool:
	"""Spend a preflighted cost dictionary."""
	if costs.is_empty():
		return true
	if not economy:
		return false
	var spend_reason = reason if reason != "" else "action"
	return spend(economy, costs, spend_reason)


## ===========================================
## UNIFIED ACTION COST API
## ===========================================

static func get_action_cost(action: String, context: Dictionary = {}) -> Dictionary:
	"""Get cost dictionary for an action.

	Args:
		action: Action name (explore, measure, reap, explore_biome, vocab_injection)
		context: Optional context for dynamic costs (e.g., {south_emoji: "🌾"})

	Returns:
		Dictionary of {emoji: amount} costs
	"""
	if action == "vocab_injection":
		return get_vocab_injection_cost(context.get("south_emoji", ""))
	return ACTION_COSTS.get(action, {})


static func get_gate_cost(gate_name: String) -> Dictionary:
	"""Get cost dictionary for a quantum gate.

	Args:
		gate_name: Gate name (pauli_x, pauli_y, pauli_z, hadamard, s_gate, t_gate, cnot, cz, swap)

	Returns:
		Dictionary of {emoji: amount} costs
	"""
	return GATE_COSTS.get(gate_name, {})


static func preflight_action(action: String, economy, context: Dictionary = {}) -> Dictionary:
	"""Check affordability for an action without spending."""
	var cost = get_action_cost(action, context)
	return preflight_cost(cost, economy)


static func preflight_gate(gate_name: String, economy) -> Dictionary:
	"""Check affordability for a quantum gate without spending."""
	var cost = get_gate_cost(gate_name)
	return preflight_cost(cost, economy)


static func commit_action(action: String, economy, context: Dictionary = {}) -> bool:
	"""Spend cost for an action after success."""
	var cost = get_action_cost(action, context)
	return commit_cost(cost, economy, action)


static func commit_gate(gate_name: String, economy) -> bool:
	"""Spend cost for a quantum gate after success."""
	var cost = get_gate_cost(gate_name)
	return commit_cost(cost, economy, gate_name)

