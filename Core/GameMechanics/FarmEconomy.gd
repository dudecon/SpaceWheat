class_name FarmEconomy
extends Node

## Farm Economy Singleton - Quantum Energy Currency System
## ALL resources are "units of quantum energy" tied to emoji states
## Starting with minimal resources forces strategic gameplay

signal wheat_changed(new_amount: int)          # 🌾 Quantum energy (wheat state)
signal labor_changed(new_amount: int)          # 👥 Quantum energy (labor/people)
signal flour_changed(new_amount: int)          # 🍞 Quantum energy (processed grain)
signal flower_changed(new_amount: int)         # 🌻 Quantum energy (flowers)
signal imperium_changed(new_amount: int)       # 👑 Quantum energy (order/structure)
signal credits_changed(new_amount: int)        # 💰 Quantum energy (exchange/value)
signal mushroom_changed(new_amount: int)       # 🍄 Quantum energy (fungi)
signal detritus_changed(new_amount: int)       # 🍂 Quantum energy (decay)
signal purchase_failed(reason: String)
signal flour_processed(wheat_amount: int, flour_produced: int)  # Mill processing event
signal flour_sold(flour_amount: int, credits_received: int)     # Flour sale event
signal emoji_resource_changed(emoji: String, new_amount: int)   # Generic emoji resource change

# Quantum Energy Currency System - Each emoji represents one type of quantum energy
# Starting with VERY LITTLE forces strategic choices and makes growth meaningful
var wheat_inventory: int = 2          # 🌾 Quantum energy (primary harvest)
var labor_inventory: int = 1          # 👥 Quantum energy (from 👥 measurements)
var flour_inventory: int = 0          # 🍞 Quantum energy (from mill processing)
var flower_inventory: int = 0         # 🌻 Quantum energy (rare yields)
var mushroom_inventory: int = 1       # 🍄 Quantum energy (nocturnal growth)
var detritus_inventory: int = 1       # 🍂 Quantum energy (compost/decay)
var imperium_resource: int = 0        # 👑 Quantum energy (imperial influence)
var credits: int = 1                  # 💰 Quantum energy (exchange medium, very scarce)

# Generic emoji resources dictionary (for extensible resource system)
var emoji_resources: Dictionary = {}  # Map emoji strings to integer quantities

# Stats
var total_wheat_harvested: int = 0  # For contract tracking

# Imperium Icon reference (linked to conspiracy network)
var imperium_icon = null  # Set by FarmView or whoever manages Icons


func _ready():
	print("⚛️  Quantum Energy Economy initialized - All resources are emoji-quantum currencies")
	print("  🌾 Wheat: %d | 👥 Labor: %d | 🍄 Mushroom: %d | 🍂 Detritus: %d" % [wheat_inventory, labor_inventory, mushroom_inventory, detritus_inventory])
	print("  💰 Credits: %d (exchange medium) | Starting minimal to force strategic growth" % credits)


## Wheat Management (Primary Currency)

func can_afford_wheat(cost: int) -> bool:
	"""Check if player has enough wheat"""
	return wheat_inventory >= cost


func spend_wheat(amount: int, reason: String = "action") -> bool:
	"""Spend wheat on an action (like planting)"""
	if not can_afford_wheat(amount):
		purchase_failed.emit("Not enough wheat! Need %d, have %d" % [amount, wheat_inventory])
		return false

	wheat_inventory -= amount
	wheat_changed.emit(wheat_inventory)
	print("💸 Spent %d wheat on %s (remaining: %d)" % [amount, reason, wheat_inventory])
	return true


func earn_wheat(amount: int, reason: String = "harvest") -> void:
	"""Earn wheat (from harvest)"""
	wheat_inventory += amount
	wheat_changed.emit(wheat_inventory)
	print("💰 Earned %d wheat from %s (total: %d)" % [amount, reason, wheat_inventory])


## Wheat Inventory

func add_wheat(amount: int):
	"""Add wheat to inventory"""
	wheat_inventory += amount
	wheat_changed.emit(wheat_inventory)
	print("🌾 Added %d wheat to inventory (total: %d)" % [amount, wheat_inventory])


func record_harvest(amount: int):
	"""Record wheat harvest (for contract tracking)"""
	total_wheat_harvested += amount
	add_wheat(amount)
	print("📊 Total wheat harvested: %d" % total_wheat_harvested)


func remove_wheat(amount: int) -> bool:
	"""Remove wheat from inventory"""
	if wheat_inventory < amount:
		return false

	wheat_inventory -= amount
	wheat_changed.emit(wheat_inventory)
	return true


## Labor Inventory (👥 People)

func add_labor(amount: int):
	"""Add labor/people to inventory (from measuring 👥 quantum state)"""
	labor_inventory += amount
	labor_changed.emit(labor_inventory)
	print("👥 Added %d labor to inventory (total: %d)" % [amount, labor_inventory])


func remove_labor(amount: int) -> bool:
	"""Remove labor from inventory"""
	if labor_inventory < amount:
		return false

	labor_inventory -= amount
	labor_changed.emit(labor_inventory)
	return true


## Flour Inventory

func add_flour(amount: int):
	"""Add flour to inventory (mill output)"""
	flour_inventory += amount
	flour_changed.emit(flour_inventory)
	print("💨 Added %d flour to inventory (total: %d)" % [amount, flour_inventory])


func remove_flour(amount: int) -> bool:
	"""Remove flour from inventory"""
	if flour_inventory < amount:
		return false

	flour_inventory -= amount
	flour_changed.emit(flour_inventory)
	return true


## Production Chain: Wheat → Flour → Credits

func process_wheat_to_flour(wheat_amount: int) -> Dictionary:
	"""
	Convert wheat to flour using Mill economics

	Mill efficiency: 10 wheat → 8 flour + 40 credits (5 credits per flour as processing labor)

	Returns: {
		"success": bool,
		"flour_produced": int,
		"credits_earned": int,
		"wheat_used": int
	}
	"""
	if wheat_inventory < wheat_amount:
		purchase_failed.emit("Not enough wheat to mill! Need %d, have %d" % [wheat_amount, wheat_inventory])
		return {"success": false, "flour_produced": 0, "credits_earned": 0, "wheat_used": 0}

	# Remove wheat
	if not remove_wheat(wheat_amount):
		return {"success": false, "flour_produced": 0, "credits_earned": 0, "wheat_used": 0}

	# Mill economics: 0.8 ratio (10 wheat → 8 flour)
	var flour_gained = int(wheat_amount * 0.8)
	var credit_bonus = flour_gained * 5  # 5 credits per flour produced (labor value)

	# Add flour and credits from mill processing
	add_flour(flour_gained)
	add_credits(credit_bonus, "mill_processing")

	flour_processed.emit(wheat_amount, flour_gained)

	print("🏭 Milled %d wheat → %d flour + %d credits" % [wheat_amount, flour_gained, credit_bonus])

	return {
		"success": true,
		"flour_produced": flour_gained,
		"credits_earned": credit_bonus,
		"wheat_used": wheat_amount
	}


func sell_flour_at_market(flour_amount: int) -> Dictionary:
	"""
	Sell flour at the market

	Market pricing: Flour is worth 100 credits gross, but market takes 20% margin
	So farmer gets 80 credits per flour

	Returns: {
		"success": bool,
		"flour_sold": int,
		"credits_received": int,
		"market_margin": int
	}
	"""
	if flour_inventory < flour_amount:
		purchase_failed.emit("Not enough flour to sell! Need %d, have %d" % [flour_amount, flour_inventory])
		return {"success": false, "flour_sold": 0, "credits_received": 0, "market_margin": 0}

	# Remove flour
	if not remove_flour(flour_amount):
		return {"success": false, "flour_sold": 0, "credits_received": 0, "market_margin": 0}

	# Market economics: 100 credits per flour gross, 20% margin to market
	var flour_price_gross = flour_amount * 100
	var market_cut = int(flour_price_gross * 0.20)
	var farmer_cut = flour_price_gross - market_cut

	# Add credits from market sale
	add_credits(farmer_cut, "market_sale")

	flour_sold.emit(flour_amount, farmer_cut)

	print("💰 Sold %d flour at market → %d credits (market took %d)" % [flour_amount, farmer_cut, market_cut])

	return {
		"success": true,
		"flour_sold": flour_amount,
		"credits_received": farmer_cut,
		"market_margin": market_cut
	}


## Credits Management (Classical Currency)

func add_credits(amount: int, reason: String = "transaction"):
	"""Add classical credits to inventory"""
	credits += amount
	credits_changed.emit(credits)
	print("💵 Earned %d credits from %s (total: %d)" % [amount, reason, credits])


func remove_credits(amount: int, reason: String = "transaction") -> bool:
	"""Spend classical credits"""
	if credits < amount:
		purchase_failed.emit("Not enough credits! Need %d, have %d" % [amount, credits])
		return false

	credits -= amount
	credits_changed.emit(credits)
	print("💸 Spent %d credits on %s (remaining: %d)" % [amount, reason, credits])
	return true


func can_afford_credits(amount: int) -> bool:
	"""Check if player has enough classical credits"""
	return credits >= amount


func can_afford(amount: int) -> bool:
	"""Unified affordability check - checks classical credits

	This is the GameController API method.
	"""
	return can_afford_credits(amount)


func spend_credits(amount: int, reason: String = "action") -> bool:
	"""Spend classical credits - GameController API method"""
	return remove_credits(amount, reason)


func earn_credits(amount: int, reason: String = "reward") -> void:
	"""Earn classical credits - GameController API method"""
	add_credits(amount, reason)


## Flower Inventory

func add_flower(amount: int):
	"""Add flowers to inventory"""
	flower_inventory += amount
	flower_changed.emit(flower_inventory)
	print("🌻 Added %d flowers to inventory (total: %d)" % [amount, flower_inventory])


func remove_flower(amount: int) -> bool:
	"""Remove flowers from inventory"""
	if flower_inventory < amount:
		return false

	flower_inventory -= amount
	flower_changed.emit(flower_inventory)
	return true


## Mushroom & Detritus Inventory

func add_mushroom(amount: int):
	"""Add mushrooms to inventory (from moon-phase harvest)"""
	mushroom_inventory += amount
	mushroom_changed.emit(mushroom_inventory)
	print("🍄 Added %d mushrooms to inventory (total: %d)" % [amount, mushroom_inventory])


func remove_mushroom(amount: int) -> bool:
	"""Remove mushrooms from inventory"""
	if mushroom_inventory < amount:
		return false

	mushroom_inventory -= amount
	mushroom_changed.emit(mushroom_inventory)
	return true


func add_detritus(amount: int):
	"""Add detritus to inventory (compost, from failed mushroom harvest)"""
	detritus_inventory += amount
	detritus_changed.emit(detritus_inventory)
	print("🍂 Added %d detritus to inventory (total: %d)" % [amount, detritus_inventory])


func remove_detritus(amount: int) -> bool:
	"""Remove detritus from inventory"""
	if detritus_inventory < amount:
		return false

	detritus_inventory -= amount
	detritus_changed.emit(detritus_inventory)
	return true


## Quota System (for Carrion Throne integration later)

func can_fulfill_quota(wheat_required: int) -> bool:
	"""Check if player can fulfill a quota"""
	return wheat_inventory >= wheat_required


func fulfill_quota(wheat_required: int) -> bool:
	"""Fulfill a quota, removing wheat from inventory"""
	if not can_fulfill_quota(wheat_required):
		return false

	return remove_wheat(wheat_required)


## Imperium Resource Management 🏰

func get_imperium() -> int:
	"""Get current imperium resource"""
	return imperium_resource


func add_imperium(amount: int):
	"""Add imperium (for special events)"""
	imperium_resource += amount
	imperium_changed.emit(imperium_resource)
	print("🏰 Gained %d imperium (total: %d)" % [amount, imperium_resource])


func remove_imperium(amount: int) -> bool:
	"""Spend imperium resource"""
	if imperium_resource < amount:
		return false

	imperium_resource -= amount
	imperium_changed.emit(imperium_resource)
	print("🏰 Spent %d imperium (remaining: %d)" % [amount, imperium_resource])
	return true


## Dynamic Emoji Resources (for harvested items)

func add_emoji_resource(emoji: String, amount: int):
	"""Add a dynamic emoji resource to inventory
	Called when harvesting any quantum emoji item
	"""
	if not emoji_resources.has(emoji):
		emoji_resources[emoji] = 0

	emoji_resources[emoji] += amount
	emoji_resource_changed.emit(emoji, emoji_resources[emoji])
	print("✨ Added %d %s to inventory (total: %d)" % [amount, emoji, emoji_resources[emoji]])


func remove_emoji_resource(emoji: String, amount: int) -> bool:
	"""Remove a dynamic emoji resource from inventory"""
	if not emoji_resources.has(emoji) or emoji_resources[emoji] < amount:
		return false

	emoji_resources[emoji] -= amount
	emoji_resource_changed.emit(emoji, emoji_resources[emoji])
	return true


func get_emoji_resource(emoji: String) -> int:
	"""Get amount of a specific emoji resource"""
	return emoji_resources.get(emoji, 0)


func get_all_emoji_resources() -> Dictionary:
	"""Get all emoji resources as a copy of the dictionary"""
	return emoji_resources.duplicate()


## Stats

func get_stats() -> Dictionary:
	"""Get economic statistics"""
	return {
		# Quantum resources (from farming)
		"wheat": wheat_inventory,
		"labor": labor_inventory,
		"flour": flour_inventory,
		"flower": flower_inventory,
		"mushroom": mushroom_inventory,
		"detritus": detritus_inventory,
		"imperium": imperium_resource,
		# Classical resources (from production chain)
		"credits": credits,
		# Statistics
		"total_wheat_harvested": total_wheat_harvested,
		"emoji_resources": emoji_resources.duplicate()
	}


func reset_harvest_counter():
	"""Reset harvest counter (called when contract completes)"""
	total_wheat_harvested = 0
	print("📊 Harvest counter reset")


func print_stats():
	"""Debug: Print economic stats"""
	var stats = get_stats()
	print("\n=== FARM ECONOMY ===")
	print("🌾 Wheat: %d units (currency)" % stats["wheat"])
	print("👥 Labor: %d" % stats["labor"])
	print("💨 Flour: %d" % stats["flour"])
	print("🌻 Flower: %d" % stats["flower"])
	print("🍄 Mushroom: %d" % stats["mushroom"])
	print("🍂 Detritus: %d" % stats["detritus"])
	print("🏰 Imperium: %d" % stats["imperium"])
	print("Total harvested: %d wheat" % stats["total_wheat_harvested"])
	print("====================\n")
