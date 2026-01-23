class_name FarmEconomy
extends Node

## Farm Economy - Unified Emoji-Credits System
## ALL resources are "emoji-credits" stored in a single dictionary
## Conversion rates defined in EconomyConstants.gd
## Example: 50 wheat = 500 🌾-credits

const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")

@onready var _verbose = get_node_or_null("/root/VerboseConfig")

# Universal resource change signal
signal resource_changed(emoji: String, new_amount: int)

# Other signals
signal purchase_failed(reason: String)
signal flour_processed(wheat_amount: int, flour_produced: int)
signal flour_sold(flour_amount: int, credits_received: int)

# Initial resources in emoji-credits (10 credits = 1 quantum energy unit)
# Start with 0 - player must gather all resources through gameplay
const INITIAL_RESOURCES = {
	# BioticFlux crops
	"🌾": 0,    # wheat (agriculture)
	"👥": 0,    # labor (work)
	"🍄": 0,    # mushroom (fungal)
	"🍂": 0,    # detritus (decay)
	"🍅": 0,    # tomato (life/conspiracy)
	"🌌": 0,    # cosmic chaos (entropy/void)
	# Market commodities
	"💨": 0,    # flour (processed grain)
	"🍞": 0,    # bread (finished product)
	# Kitchen ingredients
	"🔥": 0,    # fire (heat)
	"💧": 0,    # water (moisture)
	"❄️": 0,    # cold (opposite of fire)
	"🏜️": 0,    # dry (opposite of water)
	# Forest organisms
	"🌿": 0,    # vegetation (producer)
	"🐇": 0,    # rabbit (herbivore)
	"🐺": 0,    # wolf (predator)
	# Other
	"👑": 0,    # imperium
	"💰": 0,    # credits (legacy)
}

## ========================================
## Kitchen v2: Resource ID Mapping (Guardrail)
## ========================================
## Maps emoji strings to logical resource types for kitchen mechanics
## Ensures same emoji in different biomes routes to same economy resource
## Example: BioticFlux 🌾 and Kitchen 🌾 both route to RESOURCE_IDS["🌾"] = "wheat"
const RESOURCE_IDS = {
	"🌾": "wheat",      # Grain (produced in BioticFlux, consumed in Kitchen)
	"💨": "flour",      # Processed grain (produced via Mill, consumed in Kitchen)
	"🔥": "fire",       # Heat energy (tapped from Kitchen biome, consumed in Kitchen)
	"💧": "water",      # Moisture (tapped from Forest biome, consumed in Kitchen)
	"🍞": "bread",      # Finished product (measurement outcome of Kitchen)
	"❄️": "cold",       # Opposite of fire
	"🏜️": "dry",        # Opposite of water
}

# Unified emoji-credits dictionary - THE source of truth
var emoji_credits: Dictionary = {}

# Stats
var total_wheat_harvested: int = 0  # For contract tracking

# Imperium Icon reference (linked to conspiracy network)
var imperium_icon = null


func _ready():
	# Initialize from INITIAL_RESOURCES
	for emoji in INITIAL_RESOURCES:
		emoji_credits[emoji] = INITIAL_RESOURCES[emoji]

	if _verbose: _verbose.info("economy", "⚛️", "Unified Emoji-Credits Economy initialized (1 quantum = %d credits)" % EconomyConstants.QUANTUM_TO_CREDITS)


func _print_resources():
	var output = ""
	for emoji in emoji_credits:
		var quantum_units = emoji_credits[emoji] / EconomyConstants.QUANTUM_TO_CREDITS
		output += "%s: %d  " % [emoji, quantum_units]
	if _verbose: _verbose.debug("economy", "📊", output)


## ============================================================================
## UNIFIED API - Primary methods for all resource operations
## ============================================================================

func add_resource(emoji: String, credits_amount: int, reason: String = "") -> void:
	"""Add emoji-credits to any resource"""
	if not emoji_credits.has(emoji):
		emoji_credits[emoji] = 0

	emoji_credits[emoji] += credits_amount
	_emit_resource_change(emoji)

	var quantum_units = credits_amount / EconomyConstants.QUANTUM_TO_CREDITS
	if reason != "":
		if _verbose: _verbose.info("economy", "+", "%d %s-credits (%d units) from %s" % [credits_amount, emoji, quantum_units, reason])


func remove_resource(emoji: String, credits_amount: int, reason: String = "") -> bool:
	"""Remove emoji-credits from a resource. Returns false if insufficient."""
	if not can_afford_resource(emoji, credits_amount):
		purchase_failed.emit("Not enough %s! Need %d, have %d" % [emoji, credits_amount, get_resource(emoji)])
		return false

	emoji_credits[emoji] -= credits_amount
	_emit_resource_change(emoji)

	var quantum_units = credits_amount / EconomyConstants.QUANTUM_TO_CREDITS
	if reason != "":
		if _verbose: _verbose.info("economy", "-", "%d %s-credits (%d units) for %s" % [credits_amount, emoji, quantum_units, reason])
	return true


func get_resource(emoji: String) -> int:
	"""Get emoji-credits for any resource"""
	return emoji_credits.get(emoji, 0)


func get_resource_units(emoji: String) -> int:
	"""Get resource in quantum units (credits / 10)"""
	return get_resource(emoji) / EconomyConstants.QUANTUM_TO_CREDITS


func can_afford_resource(emoji: String, credits_amount: int) -> bool:
	"""Check if player has enough emoji-credits"""
	return get_resource(emoji) >= credits_amount


func can_afford_cost(cost: Dictionary) -> bool:
	"""Check if player can afford a multi-resource cost

	cost format: {"🌾": 10, "👥": 5} meaning 10 wheat-credits + 5 labor-credits
	"""
	for emoji in cost.keys():
		if not can_afford_resource(emoji, cost[emoji]):
			return false
	return true


func spend_cost(cost: Dictionary, reason: String = "") -> bool:
	"""Spend a multi-resource cost. Atomic: all or nothing."""
	if not can_afford_cost(cost):
		var missing = _get_missing_resources(cost)
		purchase_failed.emit("Cannot afford: " + missing)
		return false

	for emoji in cost.keys():
		emoji_credits[emoji] -= cost[emoji]
		_emit_resource_change(emoji)

	if reason != "":
		if _verbose: _verbose.info("economy", "💸", "Spent %s on %s" % [_format_cost(cost), reason])
	return true


func receive_harvest(emoji: String, quantum_energy: float, reason: String = "harvest") -> int:
	"""Convert quantum energy from harvest to emoji-credits

	1 quantum energy = 10 credits
	Returns: number of credits added
	"""
	var credits_amount = int(quantum_energy * EconomyConstants.QUANTUM_TO_CREDITS)
	add_resource(emoji, credits_amount, reason)
	return credits_amount


func _emit_resource_change(emoji: String) -> void:
	"""Emit universal resource_changed signal"""
	var amount = emoji_credits.get(emoji, 0)
	resource_changed.emit(emoji, amount)


func _get_missing_resources(cost: Dictionary) -> String:
	var missing = []
	for emoji in cost.keys():
		var have = get_resource(emoji)
		var need = cost[emoji]
		if have < need:
			missing.append("%d more %s" % [(need - have) / EconomyConstants.QUANTUM_TO_CREDITS, emoji])
	return ", ".join(missing)


func _format_cost(cost: Dictionary) -> String:
	var parts = []
	for emoji in cost.keys():
		parts.append("%d %s" % [cost[emoji] / EconomyConstants.QUANTUM_TO_CREDITS, emoji])
	return ", ".join(parts)


## ============================================================================
## PRODUCTION CHAIN: Wheat → Flour → Money
## ============================================================================

func process_wheat_to_flour(wheat_amount: int) -> Dictionary:
	"""Convert wheat to flour using Mill economics

	Mill efficiency: 10 wheat → 8 flour + 40 💰-credits (5 per flour as labor value)
	Amount is in quantum units (will be converted to credits internally)
	"""
	var wheat_credits = wheat_amount * EconomyConstants.QUANTUM_TO_CREDITS

	if not can_afford_resource("🌾", wheat_credits):
		purchase_failed.emit("Not enough wheat to mill! Need %d, have %d" % [wheat_amount, get_resource_units("🌾")])
		return {"success": false, "flour_produced": 0, "credits_earned": 0, "wheat_used": 0}

	# Remove wheat
	remove_resource("🌾", wheat_credits, "mill_input")

	# Mill economics: efficiency ratio (10 wheat → 8 flour)
	var flour_gained = int(wheat_amount * EconomyConstants.MILL_EFFICIENCY)
	var credit_bonus = flour_gained * 5  # 5 💰-units per flour produced

	# Add flour and 💰 from mill processing
	add_resource("💨", flour_gained * EconomyConstants.QUANTUM_TO_CREDITS, "mill_output")
	add_resource("💰", credit_bonus * EconomyConstants.QUANTUM_TO_CREDITS, "mill_processing")

	flour_processed.emit(wheat_amount, flour_gained)

	if _verbose: _verbose.info("economy", "🏭", "Milled %d wheat → %d flour + %d 💰" % [wheat_amount, flour_gained, credit_bonus])

	return {
		"success": true,
		"flour_produced": flour_gained,
		"credits_earned": credit_bonus,
		"wheat_used": wheat_amount
	}



func process_flour_to_bread(flour_amount: int) -> Dictionary:
	"""Convert flour to bread using Kitchen

	Kitchen efficiency: 5 flour → 3 bread (60% yield)
	Amount is in quantum units (will be converted to credits internally)
	"""
	var flour_credits = flour_amount * EconomyConstants.QUANTUM_TO_CREDITS

	if not can_afford_resource("💨", flour_credits):
		purchase_failed.emit("Not enough flour to bake! Need %d, have %d" % [flour_amount, get_resource_units("💨")])
		return {"success": false, "bread_produced": 0, "flour_used": 0}

	# Remove flour
	remove_resource("💨", flour_credits, "kitchen_input")

	# Kitchen efficiency (5 flour → 3 bread)
	var bread_gained = int(flour_amount * EconomyConstants.KITCHEN_EFFICIENCY)

	# Add bread (using 🍞 emoji)
	add_resource("🍞", bread_gained * EconomyConstants.QUANTUM_TO_CREDITS, "kitchen_output")

	if _verbose: _verbose.info("economy", "🍳", "Baked %d flour → %d bread" % [flour_amount, bread_gained])

	return {
		"success": true,
		"bread_produced": bread_gained,
		"flour_used": flour_amount
	}


## ============================================================================
## QUOTA SYSTEM
## ============================================================================

func can_fulfill_quota(wheat_required: int) -> bool:
	return get_resource_units("🌾") >= wheat_required

func fulfill_quota(wheat_required: int) -> bool:
	if not can_fulfill_quota(wheat_required):
		return false
	return remove_resource("🌾", wheat_required * EconomyConstants.QUANTUM_TO_CREDITS, "quota")


## ============================================================================
## STATS
## ============================================================================

func get_stats() -> Dictionary:
	"""Get economic statistics"""
	return {
		# Statistics
		"total_wheat_harvested": total_wheat_harvested,
		# All resources as emoji-credits
		"emoji_credits": emoji_credits.duplicate()
	}


func reset_harvest_counter():
	"""Reset harvest counter (called when contract completes)"""
	total_wheat_harvested = 0
	if _verbose: _verbose.debug("economy", "📊", "Harvest counter reset")


func print_stats():
	"""Debug: Print economic stats (uses if _verbose: _verbose.debug)"""
	if _verbose: _verbose.debug("economy", "📊", "=== FARM ECONOMY (Emoji-Credits) ===")
	for emoji in emoji_credits:
		var credits_val = emoji_credits[emoji]
		var units = credits_val / EconomyConstants.QUANTUM_TO_CREDITS
		if _verbose: _verbose.debug("economy", "  ", "%s: %d units (%d credits)" % [emoji, units, credits_val])
	if _verbose: _verbose.debug("economy", "📊", "Total wheat harvested: %d" % total_wheat_harvested)
