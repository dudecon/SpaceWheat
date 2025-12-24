class_name MarketBiome
extends "res://Core/Environment/BiomeBase.gd"

## Market Biome: Parallel quantum system for trading/economics
## Represents supply/demand dynamics controlled by Granary Guilds
##
## The MarketBiome is a separate quantum system that evolves independently:
## - Represents market supply/demand as a qubit on the Bloch sphere
## - Coupled to Granary Guilds icon (like wheat/mushroom in farming biome)
## - High supply (high θ) = low prices
## - Low supply (low θ) = high prices
## - Farm must navigate both biome_market supply curves simultaneously
##
## Architecture mirrors wheat-farming biome but for economics:
## - sun_qubit → market_qubit (represents overall market conditions)
## - wheat_icon → granary_guilds_icon (supply management)
## - emoji qubits → flour inventory pricing

const TIME_SCALE = 1.0  # Market evolution speed

# Market state qubit (represents overall market conditions)
var market_qubit: DualEmojiQubit = null  # θ: supply level, φ: seasonal pattern

# Granary Guilds icon (merchant collective avatar)
var granary_guilds_icon: Dictionary = {}  # Manages supply/demand

# Market-specific constants
var base_flour_price: int = 100  # Starting price
var price_per_supply_theta: float = 50.0  # Price modifier based on θ


func _ready():
	super._ready()

	# HAUNTED UI FIX: Guard against double-initialization
	if market_qubit != null:
		print("⚠️  MarketBiome._ready() called multiple times, skipping re-initialization")
		return

	_initialize_market_qubits()
	print("💰 MarketBiome initialized")

	# Configure visual properties for QuantumForceGraph
	visual_color = Color(1.0, 0.55, 0.0, 0.3)  # Sunset orange
	visual_label = "💰 Market"
	visual_center_offset = Vector2(-0.6, -0.5)  # Top-left (offset from center)
	visual_oval_width = 200.0   # Even smaller oval
	visual_oval_height = 123.0  # Golden ratio: 200/1.618


func _initialize_market_qubits():
	"""Set up quantum state for market"""

	# Market qubit represents supply level
	# θ near π = high supply (low prices)
	# θ near 0 = low supply (high prices)
	market_qubit = BiomeUtilities.create_qubit("📉", "📈", PI / 2.0)  # Down/Up emojis for supply
	market_qubit.energy = 1.0

	# Granary Guilds icon (merchant collective)
	# Stable point: θ ≈ π (abundant supply profits merchants)
	granary_guilds_icon = {
		"name": "Granary Guilds",
		"emoji": "🏢",
		"internal_qubit": BiomeUtilities.create_qubit("💰", "📊", PI)
	}
	granary_guilds_icon["internal_qubit"].energy = 1.0


func _update_quantum_substrate(dt: float) -> void:
	"""Override parent: Evolve market quantum state"""
	if not market_qubit or not granary_guilds_icon:
		return

	# Market qubit evolves toward Granary Guilds icon stable point
	# (Merchants push for high supply to maximize profit)
	_evolve_market_qubit(dt)


func _evolve_market_qubit(delta: float):
	"""Market qubit gravitates toward Granary Guilds stable point"""
	if not market_qubit or not granary_guilds_icon:
		return

	var guilds_theta = granary_guilds_icon["internal_qubit"].theta
	var current_theta = market_qubit.theta

	# Spring force: market trends toward merchant stability
	var theta_diff = guilds_theta - current_theta
	var coupling_strength = 0.1  # How strongly merchants influence market
	var drift = theta_diff * coupling_strength * 0.016  # delta ≈ 0.016 at 60fps

	market_qubit.theta += drift

	# Keep theta in [0, 2π]
	if market_qubit.theta > TAU:
		market_qubit.theta -= TAU
	elif market_qubit.theta < 0:
		market_qubit.theta += TAU

	# Slow energy decay (market loses vitality over time)
	market_qubit.radius *= 0.9995  # ~0.05% decay per frame


func get_flour_price() -> int:
	"""
	Calculate current flour price based on market state

	Price equation:
	- Base price: 100 credits
	- Supply modifier: π - θ (low θ = high demand = high price)
	- Result: prices range from ~50 to ~150 based on supply

	When market_theta ≈ 0: Low supply, high prices (150)
	When market_theta ≈ π/2: Neutral supply, neutral prices (100)
	When market_theta ≈ π: High supply, low prices (50)
	"""
	if not market_qubit:
		return base_flour_price

	# Supply ratio: 1.0 means equilibrium, >1 means oversupply, <1 means shortage
	var supply_ratio = (PI - market_qubit.theta) / PI

	# Price modifier: oversupply = lower prices, shortage = higher prices
	var price = int(base_flour_price * (0.5 + supply_ratio))

	return max(20, min(200, price))  # Clamp between 20-200


func get_biome_type() -> String:
	"""Return biome type identifier"""
	return "Market"


func get_market_conditions() -> Dictionary:
	"""Get full market state info"""
	if not market_qubit:
		return {}

	return {
		"flour_price": get_flour_price(),
		"supply_theta": market_qubit.theta,
		"supply_level": (PI - market_qubit.theta) / PI,  # 0=shortage, 1=equilibrium, >1=oversupply
		"market_energy": market_qubit.radius,
		"time_elapsed": time_tracker.time_elapsed,
		"guilds_stability": granary_guilds_icon["internal_qubit"].theta
	}


func apply_player_sale(flour_amount: int):
	"""
	When player sells flour, it affects market supply

	More flour sold = higher supply = lower future prices
	"""
	if not market_qubit:
		return

	# Each 10 flour sold slightly increases supply (pushes theta toward π)
	var supply_shock = flour_amount * 0.01  # 10 flour = 0.1 rad push
	market_qubit.theta += supply_shock

	# Keep in bounds
	if market_qubit.theta > TAU:
		market_qubit.theta -= TAU

	print("📊 Market absorbed " + str(flour_amount) + " flour - supply increased")


func set_granary_guilds_state(theta: float, phi: float):
	"""
	Externally modify Granary Guilds influence (tribute effect)

	High tributes to guilds = more merchant influence = push prices down
	"""
	if not granary_guilds_icon:
		return

	granary_guilds_icon["internal_qubit"].theta = fmod(theta, TAU)
	granary_guilds_icon["internal_qubit"].phi = fmod(phi, TAU)


func reset_to_neutral():
	"""Reset market to neutral supply state"""
	if market_qubit:
		market_qubit.theta = PI / 2.0  # Neutral supply
		market_qubit.radius = 1.0


## NEW: Direct Planting System

func inject_planting(position: Vector2i, wheat_amount: float, labor_amount: float, plot_type: int) -> Resource:
	"""
	Inject wheat directly into market biome (like planting in farming biome)

	MARKET BIOME GAMEPLAY:
	- Player plants: 0.22🌾 + 0.08👥
	- Market converts wheat into coin energy (💰)
	- Coin energy grows over time (market supply dynamics)
	- Harvest = get credits based on coin energy amount

	Returns: Qubit representing the coin injection
	"""
	if not market_qubit:
		return null

	# Create coin qubit to represent this wheat injection
	var coin_qubit = DualEmojiQubit.new("💰", "💵", PI / 2.0)

	# Coin qubit starts at specific position based on wheat amount
	# More wheat = more initial energy
	coin_qubit.phi = 0.0
	coin_qubit.radius = min(1.0, wheat_amount / 0.22)  # Scale by wheat amount (0.22 = full)
	coin_qubit.energy = wheat_amount * 100.0  # Convert wheat to coin energy

	# Labor enhances coin production
	coin_qubit.energy *= (1.0 + labor_amount * 5.0)  # 0.08 labor = 1.4x multiplier

	print("💰 Market injection: %.2f🌾 + %.2f👥 → %.1f coin energy" %
		[wheat_amount, labor_amount, coin_qubit.energy])

	return coin_qubit


func get_coin_energy(coin_qubit: Resource) -> float:
	"""Get current coin energy from injected qubit"""
	if coin_qubit and coin_qubit is DualEmojiQubit:
		return coin_qubit.energy
	return 0.0


func harvest_coin_energy(coin_qubit: Resource) -> Dictionary:
	"""
	Harvest coin energy from market biome
	Converts accumulated energy into classical credits

	Returns: {
		"success": bool,
		"credits": int,
		"coin_energy": float
	}
	"""
	if not coin_qubit:
		return {"success": false, "credits": 0, "coin_energy": 0.0}

	var coin_energy = get_coin_energy(coin_qubit)
	if coin_energy <= 0:
		return {"success": false, "credits": 0, "coin_energy": 0.0}

	# Convert coin energy to credits
	# Base rate: 1 energy = 10 credits
	var credits_earned = int(coin_energy * 10.0)

	print("💵 Market harvest: %.1f coin energy → %d credits" % [coin_energy, credits_earned])

	return {
		"success": true,
		"credits": credits_earned,
		"coin_energy": coin_energy
	}
