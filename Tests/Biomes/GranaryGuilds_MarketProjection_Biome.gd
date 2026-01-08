class_name GranaryGuilds_MarketProjection_Biome
extends BiomeBase

## Granary Guilds: Quantum Market Equilibrium System
##
## NOT a competitor or profit-seeker
## ROLE: Consume bread, stabilize input supplies
##
## Behavior:
## - Constantly drain 🍞 energy (consumption demand sink)
## - Buy/sell 🌾, 💧, flour to maintain stable supply levels
## - Adjust market pressure (theta shifts) to keep bread at medium-low
##
## Icons (no classical resources, pure quantum effects):
## 📦 - Storage/Surplus level (how much bread they've accumulated)
## 🌻 - Flour balance (goal: maintain flour availability)
## 🌾 - Wheat sourcing (goal: stable wheat supply)
## 💧 - Water sourcing (goal: stable water supply)
##
## They affect market through pure quantum forces, not transactions

## Guild consumption: constantly draining bread energy
var bread_consumption_rate: float = 0.02  # Energy drain per second

## Guild target supply levels (what they try to maintain)
var target_flour_probability: float = 0.5  # Want flour at equilibrium
var target_bread_supply: float = 0.3  # Keep bread 30% of potential (scarce)

## Guild icons representing their internal state
var storage_icon: DualEmojiQubit  # 📦 bread storage level (emptiness vs fullness)
var flour_icon: DualEmojiQubit    # 🌻 flour satisfaction
var wheat_icon: DualEmojiQubit    # 🌾 wheat reserves
var water_icon: DualEmojiQubit    # 💧 water reserves

## Pressure parameters (how strongly guilds affect market)
var bread_drain_force: float = 0.1  # How much they drain 🍞
var supply_push_strength: float = 0.05  # How much they push on market

## Time tracking for periodic checks
var check_in_period: float = 15.0  # Guilds evaluate situation every 15 seconds

func _ready():
	super._ready()
	_initialize_guild_icons()
	print("🏢 Granary Guilds Market Projection initialized")


func _initialize_guild_icons():
	"""Initialize guild icons in balanced superposition"""

	# Storage: start half-full
	storage_icon = BiomeUtilities.create_qubit("📦", "🍞", PI / 2.0)
	storage_icon.radius = 0.5  # Half-full storage

	# Flour: start satisfied
	flour_icon = BiomeUtilities.create_qubit("🌻", "🌾", PI / 2.0)
	flour_icon.radius = 1.0

	# Wheat: start at equilibrium
	wheat_icon = BiomeUtilities.create_qubit("🌾", "💼", PI / 2.0)
	wheat_icon.radius = 1.0

	# Water: start at equilibrium
	water_icon = BiomeUtilities.create_qubit("💧", "☀️", PI / 2.0)
	water_icon.radius = 1.0


func _update_quantum_substrate(dt: float) -> void:
	"""Override parent: Update guild behavior"""
	if time_tracker.time_elapsed >= check_in_period:
		_check_in()
		time_tracker.time_elapsed = 0.0


func drain_bread_energy(bread_qubit: DualEmojiQubit) -> Dictionary:
	"""
	Guilds constantly consume bread, draining its energy

	This is how they affect the market:
	- High bread supply (high energy) → Guilds drain it down
	- Creates scarcity pressure
	- Player must keep producing to maintain supply
	"""
	if not bread_qubit:
		return {"drained": 0.0}

	var drained = bread_consumption_rate * bread_qubit.radius
	bread_qubit.radius *= (1.0 - bread_consumption_rate)

	# As storage fills with bread, update storage icon
	storage_icon.radius = min(1.0, storage_icon.radius + drained * 0.1)

	return {
		"drained": drained,
		"remaining_radius": bread_qubit.radius,
		"storage_level": storage_icon.radius
	}


func apply_guild_pressure_to_market(market_qubit: DualEmojiQubit) -> Dictionary:
	"""
	Guilds push on market qubit based on their needs

	Pure quantum force - no coins, no resources tracked
	Just effects on the (🌾, 💰) market state
	"""
	if not market_qubit:
		return {}

	var flour_prob = sin(market_qubit.theta / 2.0) ** 2
	var pressure_applied = 0.0

	# FLOUR STABILIZATION
	# If flour too cheap (probability high), reduce supply pressure
	if flour_prob > target_flour_probability + 0.2:
		# Flour abundant - guilds sell flour to suppress price
		market_qubit.theta -= supply_push_strength
		flour_icon.theta = lerp(flour_icon.theta, 0.0, 0.05)  # Move toward satisfied
		pressure_applied -= supply_push_strength
		print("🏢 Guilds: Flour abundant, selling (suppress price)")

	# If flour too expensive (probability low), increase supply pressure
	elif flour_prob < target_flour_probability - 0.2:
		# Flour scarce - guilds buy flour to raise price (encourage production)
		market_qubit.theta += supply_push_strength
		flour_icon.theta = lerp(flour_icon.theta, PI, 0.05)  # Move toward hungry
		pressure_applied += supply_push_strength
		print("🏢 Guilds: Flour scarce, buying (raise price)")

	# BREAD SCARCITY PRESSURE
	# If storage getting full, guilds are drowning in bread
	# Push market toward coins (suppress bread production incentive)
	if storage_icon.radius > 0.7:
		market_qubit.theta -= 0.02
		storage_icon.radius *= 0.95  # Gradually consume the bread
		print("🏢 Guilds: Storage full, suppressing bread value")

	# If storage getting empty, guilds are hungry for bread
	# Push market toward higher prices (encourage production)
	elif storage_icon.radius < 0.2:
		market_qubit.theta += 0.03
		print("🏢 Guilds: Storage empty, encouraging bread production")

	return {
		"flour_prob": flour_prob,
		"target": target_flour_probability,
		"pressure_applied": pressure_applied,
		"storage_level": storage_icon.radius
	}


func _check_in():
	"""
	Periodic evaluation: guilds assess their needs and adjust strategy
	(We don't simulate buying/selling, just the effects on market)
	"""
	print("\n🏢 Guilds check in (time: %.1fs)" % time_tracker.time_elapsed)

	# Slow convergence of icon states toward equilibrium
	# (Guild learns/adapts to market)
	flour_icon.theta = lerp(flour_icon.theta, PI / 2.0, 0.1)
	wheat_icon.theta = lerp(wheat_icon.theta, PI / 2.0, 0.1)
	water_icon.theta = lerp(water_icon.theta, PI / 2.0, 0.1)

	# Storage naturally decays (consumption without production means lower storage)
	storage_icon.radius *= 0.95


func get_biome_type() -> String:
	"""Return biome type identifier"""
	return "GranaryGuilds"


func get_guild_status() -> Dictionary:
	"""Current guild state for monitoring/display"""
	return {
		"storage_level": storage_icon.radius,
		"storage_theta": storage_icon.theta,
		"flour_satisfaction": cos(flour_icon.theta / 2.0) ** 2,
		"wheat_reserves": cos(wheat_icon.theta / 2.0) ** 2,
		"water_reserves": cos(water_icon.theta / 2.0) ** 2,
		"consumption_rate": bread_consumption_rate,
		"time_until_check": check_in_period - time_tracker.time_elapsed
	}


func _reset_custom() -> void:
	"""Override parent: Reset guild to initial state"""
	storage_icon.theta = PI / 2.0
	storage_icon.radius = 0.5
	flour_icon.theta = PI / 2.0
	water_icon.theta = PI / 2.0
	wheat_icon.theta = PI / 2.0
	print("🏢 Granary Guilds reset to initial state")
