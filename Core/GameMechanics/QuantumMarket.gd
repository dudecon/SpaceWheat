class_name QuantumMarket
extends Node2D

## QuantumMarket: DualEmojiQubit Pairing with 💰
##
## The Market creates a paired superposition between a target emoji (X) and 💰 (money).
## This implements the quantum "sell" mechanic - when you measure, the collapse
## determines whether you get credits (💰) or keep your resource (X).
##
## Quantum Mechanics:
##   - Pairs plot's emoji X with 💰 in superposition: α|X⟩ + β|💰⟩
##   - Creates X ↔ 💰 dual state via CNOT-like coupling
##   - Player measures to "sell" - collapse determines credits
##   - Higher P(💰) = more likely to get money

# Access autoloads safely
@onready var _verbose = get_node("/root/VerboseConfig")

## Configuration
var grid_position: Vector2i = Vector2i.ZERO
var parent_biome = null
var is_active: bool = false
var paired_emoji: String = ""  # The emoji being paired with 💰

## Statistics
var total_sales: int = 0
var total_credits_earned: int = 0


func _ready():
	print("🏪 QuantumMarket initialized at %s" % grid_position)


## ========================================
## Activation
## ========================================

func activate(biome, target_emoji: String = "🌾") -> bool:
	"""
	Activate market by creating X ↔ 💰 pairing in biome.

	The market injects 💰 (money) into the parent biome's quantum system
	and couples it to the target emoji. This creates a superposition where
	measurement can collapse to either money or the original resource.

	Args:
	    biome: Parent BiomeBase that owns the quantum computer
	    target_emoji: Emoji to pair with 💰 (default: 🌾 wheat)

	Returns:
	    true if activation successful, false otherwise
	"""
	parent_biome = biome
	paired_emoji = target_emoji

	if not parent_biome:
		push_error("Market: has no parent biome!")
		return false

	# Check biome has quantum_computer
	if not parent_biome.quantum_computer:
		push_error("Market: Parent biome has no quantum_computer!")
		return false

	# Verify target emoji exists in biome
	if not _has_emoji(parent_biome, target_emoji):
		print("🏪 Market: Target emoji %s not in biome - market inactive" % target_emoji)
		is_active = false
		return false

	# Add 💰 axis if not present
	if not _has_emoji(parent_biome, "💰"):
		print("🏪 Market: Adding 💰 axis to quantum system...")

		if parent_biome.has_method("expand_quantum_system"):
			var result = parent_biome.expand_quantum_system("💰", target_emoji)
			if not (result.success or result.get("already_exists", false)):
				print("🏪 Market: Could not expand quantum system: %s" % result.get("message", "unknown"))
				print("🏪 Market: Try pressing TAB to enter BUILD mode first")
				is_active = false
				return false
		else:
			# Fallback: Use MarketBiome's inject_commodity if available
			if parent_biome.has_method("inject_commodity"):
				parent_biome.inject_commodity("💰")
			else:
				print("🏪 Market: Biome doesn't support quantum expansion")
				is_active = false
				return false

	is_active = true
	print("🏪 Market active at %s: %s ↔ 💰 pairing enabled" % [grid_position, paired_emoji])
	return true


## ========================================
## Measurement / Sale
## ========================================

func measure_for_sale() -> Dictionary:
	"""
	Measure the market quantum state to sell.

	Performs a measurement that collapses the X ↔ 💰 superposition.
	The outcome determines the sale result:
	  - Collapse to 💰: Full sale - player gets max credits
	  - Collapse to X: Partial sale - player gets reduced credits

	Returns:
	    Dictionary with:
	    - success: bool
	    - credits: int (credits earned)
	    - got_money: bool (true if collapsed to 💰 state)
	    - probability: float (the probability that determined outcome)
	"""
	if not is_active or not parent_biome or not parent_biome.quantum_computer:
		return {"success": false, "credits": 0, "got_money": false, "probability": 0.0}

	# Get P(💰) from quantum computer (Model C)
	var money_prob = 0.5  # Default
	if _has_emoji(parent_biome, "💰"):
		money_prob = parent_biome.get_emoji_probability("💰")

	# Perform measurement (Born rule)
	var got_money = randf() < money_prob

	# Calculate credits based on outcome
	var credits: int
	if got_money:
		# Full sale: max credits
		credits = int(money_prob * 100)
	else:
		# Partial sale: reduced credits (you kept the resource but got some money)
		credits = int(money_prob * 20)

	# Track statistics
	total_sales += 1
	total_credits_earned += credits

	print("🏪 Market sale at %s: P(💰)=%.2f → %s (%d credits)" % [
		grid_position, money_prob, "💰 SOLD!" if got_money else "📦 Kept", credits
	])

	return {
		"success": true,
		"credits": credits,
		"got_money": got_money,
		"probability": money_prob
	}


func get_current_price() -> float:
	"""Get current market price (P(💰) probability)."""
	if not is_active or not parent_biome or not parent_biome.quantum_computer:
		return 0.5

	if _has_emoji(parent_biome, "💰"):
		return parent_biome.get_emoji_probability("💰")
	return 0.5


## ========================================
## Status
## ========================================

func get_debug_info() -> Dictionary:
	"""Return market state for debugging."""
	return {
		"position": grid_position,
		"is_active": is_active,
		"paired_emoji": paired_emoji,
		"parent_biome": parent_biome.get_biome_type() if parent_biome else "none",
		"current_price": get_current_price(),
		"total_sales": total_sales,
		"total_credits": total_credits_earned,
	}


func is_working() -> bool:
	"""Check if market is actively trading."""
	return is_active


func _has_emoji(biome, emoji: String) -> bool:
	"""Check emoji presence via viz_cache metadata (fallback to register_map)."""
	if not biome or emoji == "":
		return false
	if biome.viz_cache:
		return biome.viz_cache.get_qubit(emoji) >= 0
	if biome.quantum_computer and biome.quantum_computer.register_map:
		return biome.quantum_computer.register_map.has(emoji)
	return false
