class_name FarmEconomy
extends Node

## Farm Economy - Unified Emoji-Credits System
## ALL resources are "emoji-credits" stored in a single dictionary
## Conversion rates defined in EconomyConstants.gd
## Example: 50 wheat = 500 🌾-credits

const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")

@onready var _verbose = get_node_or_null("/root/VerboseConfig")

signal resource_changed(emoji: String, new_amount: int)
signal purchase_failed(reason: String)
signal flour_processed(wheat_amount: int, flour_produced: int)
signal flour_sold(flour_amount: int, credits_received: int)

const RESOURCE_IDS = {
	"🌾": "wheat",
	"💨": "flour",
	"🔥": "fire",
	"💧": "water",
	"🍞": "bread",
	"❄️": "cold",
	"🏜️": "dry",
}

var emoji_credits: Dictionary = {}
var total_wheat_harvested: int = 0
var imperium_icon = null


func _ready():
	if _verbose: _verbose.info("economy", "⚛️", "Emoji-Credits Economy ready (1 quantum = %d credits)" % EconomyConstants.QUANTUM_TO_CREDITS)


func _print_resources():
	var output = ""
	for emoji in emoji_credits:
		var quantum_units = emoji_credits[emoji] / EconomyConstants.QUANTUM_TO_CREDITS
		output += "%s: %d  " % [emoji, quantum_units]
	if _verbose: _verbose.debug("economy", "📊", output)


## ============================================================================
## UNIFIED API - Primary methods for all resource operations
## ============================================================================

func add_resource(emoji: String, credits_amount, reason: String = "") -> void:
	"""Add emoji-credits to any resource

	Note: Vocabulary bonus now applied in action phase (ProbeActions).
	This keeps bonus calculation transparent and trackable at the source.
	"""
	if not emoji_credits.has(emoji):
		emoji_credits[emoji] = 0

	# No multiplier here - bonuses applied in action phase
	var final_amount = int(credits_amount)

	emoji_credits[emoji] += final_amount
	_emit_resource_change(emoji)

	var quantum_units = final_amount / EconomyConstants.QUANTUM_TO_CREDITS
	if reason != "":
		if _verbose: _verbose.info("economy", "+", "%d %s-credits (%d units) from %s" % [final_amount, emoji, quantum_units, reason])


func _get_vocabulary_purity_multiplier(emoji: String) -> float:
	"""Get purity multiplier for vocabulary match.

	If emoji is in player's vocabulary: 2x multiplier, squared = 4.0x bonus
	Otherwise: 1.0x (no bonus, but still allowed)
	"""
	var gsm = get_node_or_null("/root/GameStateManager")
	if not gsm:
		return 1.0


	var is_in_vocabulary = false

	# Prefer farm-owned vocabulary when available
	if "active_farm" in gsm and gsm.active_farm and gsm.active_farm.has_method("get_known_emojis"):
		var known_emojis = gsm.active_farm.get_known_emojis()
		is_in_vocabulary = emoji in known_emojis
	# Fallback to saved state (legacy)
	elif gsm.current_state and gsm.current_state.has_method("get_known_emojis"):
		var known = gsm.current_state.get_known_emojis()
		is_in_vocabulary = emoji in known

	# Purity bonus: 2x before squaring = 4x total
	if is_in_vocabulary:
		return 2.0 * 2.0  # Squared multiplier
	else:
		return 1.0  # Always allow, just no bonus


func _resource_allowed_by_iconmap(emoji: String) -> bool:
	"""Only allow gains for emojis present in the current IconMap vocabulary."""
	var gsm = get_node_or_null("/root/GameStateManager")
	if not gsm or not ("active_farm" in gsm):
		return true
	var farm = gsm.active_farm
	if not farm or not ("biome_evolution_batcher" in farm):
		return true
	var batcher = farm.biome_evolution_batcher
	if not batcher or not batcher.has_method("get_global_icon_map"):
		return true
	var icon_map = batcher.get_global_icon_map()
	if icon_map.is_empty():
		return true
	var by_emoji = icon_map.get("by_emoji", {})
	return by_emoji.has(emoji)
func remove_resource(emoji: String, credits_amount, reason: String = "") -> bool:
	"""Remove emoji-credits from a resource. Returns false if insufficient. Supports float amounts."""
	if not can_afford_resource(emoji, credits_amount):
		purchase_failed.emit("Not enough %s! Need %.2f, have %.2f" % [emoji, credits_amount, get_resource(emoji)])
		return false

	emoji_credits[emoji] -= credits_amount
	_emit_resource_change(emoji)

	var quantum_units = credits_amount / EconomyConstants.QUANTUM_TO_CREDITS
	if reason != "":
		if _verbose: _verbose.info("economy", "-", "%.2f %s-credits (%.2f units) for %s" % [credits_amount, emoji, quantum_units, reason])
	return true


func set_resource(emoji: String, credits_amount, reason: String = "") -> void:
	"""Set emoji-credits directly (bypasses gain gate). Supports float amounts."""
	if not emoji_credits.has(emoji):
		emoji_credits[emoji] = 0
	emoji_credits[emoji] = max(0, credits_amount)
	_emit_resource_change(emoji)
	if reason != "":
		if _verbose: _verbose.info("economy", "=", "%.2f %s-credits from %s" % [credits_amount, emoji, reason])


func get_resource(emoji: String):
	"""Get emoji-credits for any resource (supports float amounts)"""
	return emoji_credits.get(emoji, 0)


func get_resource_units(emoji: String) -> int:
	"""Get resource in quantum units (credits / 10)"""
	return get_resource(emoji) / EconomyConstants.QUANTUM_TO_CREDITS


func get_all_resources() -> Dictionary:
	"""Get all emoji-credits as dictionary. Returns copy to prevent mutation."""
	return emoji_credits.duplicate()


func can_afford_resource(emoji: String, credits_amount) -> bool:
	"""Check if player has enough emoji-credits (supports float amounts)"""
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
