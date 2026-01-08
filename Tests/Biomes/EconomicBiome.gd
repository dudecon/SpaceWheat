class_name EconomicBiome
extends BiomeBase

## Unified Economic Biome: Market + Granary Guilds Integration
##
## Combines quantum market measurement system with guild consumption/stabilization effects
##
## Subsystems:
## 1. MARKET: (🌾 flour, 💰 coins) superposition with measurement-based exchange rates
## 2. GUILDS: (📦🌻🌾💧) quantum icons affecting market through pure theta-pushing
## 3. BREAD: (🍞, 👥) qubit that guilds drain, player produces in kitchen
##
## Flow:
## - Player trades flour → Market measures → Guild perceives flour scarcity
## - Guilds apply pressure to market theta to stabilize supplies
## - Bread draining creates demand for kitchen production
## - Mill injection and trading injection create boom/bust cycles
## - Guild consumption acts as energy sink (opposite of production)

## ========== MARKET SUBSYSTEM ==========
## Market qubit in (🌾 flour, 💰 coins) superposition
var market_qubit: DualEmojiQubit

## Measurement history for price trends
var measurement_history: Array = []
var max_history: int = 20

## Base exchange rate
var base_flour_value: int = 100

## Injection and decay parameters
var injection_strength: float = 0.01
var energy_decay_rate: float = 0.99

## ========== GUILD SUBSYSTEM ==========
## Guild icons representing internal state (pure quantum, no classical resources)
var storage_icon: DualEmojiQubit   # 📦 bread storage level
var flour_icon: DualEmojiQubit     # 🌻 flour satisfaction
var wheat_icon: DualEmojiQubit     # 🌾 wheat reserves
var water_icon: DualEmojiQubit     # 💧 water reserves

## Guild behavior parameters
var bread_consumption_rate: float = 0.02  # Energy drain per second
var target_flour_probability: float = 0.5  # Equilibrium target
var target_bread_supply: float = 0.3  # Keep bread 30% (scarce)
var supply_push_strength: float = 0.05  # How much guilds push market

## Guild time tracking
var guild_check_in_period: float = 15.0

## ========== BREAD SUBSYSTEM ==========
## Bread qubit (🍞, 👥) - guilds drain this, player produces in kitchen
var bread_qubit: DualEmojiQubit = null


func _ready():
	"""Initialize unified economic biome"""
	super._ready()

	# Market subsystem: balanced superposition
	market_qubit = BiomeUtilities.create_qubit("🌾", "💰", PI / 2.0)
	market_qubit.radius = 1.0

	# Guild subsystem: icons in balanced states
	storage_icon = BiomeUtilities.create_qubit("📦", "🍞", PI / 2.0)
	storage_icon.radius = 0.5  # Half-full initially

	flour_icon = BiomeUtilities.create_qubit("🌻", "🌾", PI / 2.0)
	flour_icon.radius = 1.0

	wheat_icon = BiomeUtilities.create_qubit("🌾", "💼", PI / 2.0)
	wheat_icon.radius = 1.0

	water_icon = BiomeUtilities.create_qubit("💧", "☀️", PI / 2.0)
	water_icon.radius = 1.0

	# Bread subsystem: will be set externally by player
	# (Guilds drain this as it's produced by kitchen)

	print("🏢💰 Unified Economic Biome initialized (Market + Guilds)")


func _update_quantum_substrate(dt: float) -> void:
	"""Override parent: Economic biome has no continuous evolution"""
	pass  # Measurement-based system, not continuous evolution


## ========== MARKET INTERFACE ==========

func get_measurement_probabilities() -> Dictionary:
	"""Get current measurement probabilities without collapsing"""
	if not market_qubit:
		return {"flour": 0.5, "coins": 0.5, "theta": 0.0}

	var flour_prob = sin(market_qubit.theta / 2.0) ** 2
	var coins_prob = cos(market_qubit.theta / 2.0) ** 2

	return {
		"flour": flour_prob,
		"coins": coins_prob,
		"theta": market_qubit.theta,
		"energy": market_qubit.radius
	}


func measure_market() -> String:
	"""
	MEASUREMENT: Collapse market qubit to classical state

	Returns: "flour" or "coins" based on sin²(θ/2) / cos²(θ/2)
	"""
	if not market_qubit:
		return "balanced"

	var flour_prob = sin(market_qubit.theta / 2.0) ** 2

	# Measurement collapses to one outcome
	var outcome = "flour" if randf() < flour_prob else "coins"

	# Record measurement
	measurement_history.append({
		"outcome": outcome,
		"flour_prob": flour_prob,
		"theta": market_qubit.theta,
		"energy": market_qubit.radius,
		"timestamp": Time.get_ticks_msec()
	})

	# Keep history bounded
	if measurement_history.size() > max_history:
		measurement_history.pop_front()

	print("📊 Market measured: %s state (P(flour)=%.1f%%)" % [outcome, flour_prob * 100])

	return outcome


func get_exchange_rate_for_flour(flour_amount: int) -> Dictionary:
	"""
	Calculate exchange rate BEFORE measurement
	Based on measurement probabilities (what COULD happen)
	"""
	var probs = get_measurement_probabilities()
	var flour_prob = probs["flour"]
	var coins_prob = probs["coins"]

	var rate_if_flour_measured = int(base_flour_value * (1.0 - flour_prob))
	var rate_if_coins_measured = int(base_flour_value * (1.0 + coins_prob))

	var expected_rate = int(
		rate_if_flour_measured * flour_prob +
		rate_if_coins_measured * coins_prob
	)

	return {
		"flour_sold": flour_amount,
		"expected_credits": flour_amount * expected_rate,
		"best_case": flour_amount * rate_if_coins_measured,
		"worst_case": flour_amount * rate_if_flour_measured,
		"best_case_rate": rate_if_coins_measured,
		"worst_case_rate": rate_if_flour_measured,
		"expected_rate": expected_rate,
		"flour_probability": flour_prob,
		"coins_probability": coins_prob,
		"energy": market_qubit.radius
	}


func trade_flour_for_coins(flour_amount: int) -> Dictionary:
	"""
	Complete trade: MEASURE → COLLAPSE → EXCHANGE → INJECT

	Process:
	1. Measure market state (quantum collapse)
	2. Determine classical exchange rate from measurement
	3. Execute trade (classical)
	4. Inject: flour sold pushes market toward coins-abundant
	5. Energy decays slightly
	6. Guild perceives change and applies pressure
	"""
	if not market_qubit or flour_amount <= 0:
		return {"success": false}

	# Step 1: MEASUREMENT
	var measurement = measure_market()
	var probs = get_measurement_probabilities()

	# Step 2: EXCHANGE RATE (post-measurement, classical)
	var rate_if_flour = int(base_flour_value * (1.0 - probs["flour"]))
	var rate_if_coins = int(base_flour_value * (1.0 + probs["coins"]))

	var actual_rate = rate_if_flour if measurement == "flour" else rate_if_coins
	var credits_received = flour_amount * actual_rate

	# Step 3: INJECTION
	# Flour sold → pushes market toward coins-abundant state
	var theta_injection = flour_amount * injection_strength
	market_qubit.theta -= theta_injection  # Push toward 0 (coins-rich)

	# Keep theta in bounds
	market_qubit.theta = fmod(market_qubit.theta, TAU)
	if market_qubit.theta < 0:
		market_qubit.theta += TAU

	# Step 4: ENERGY DECAY
	market_qubit.radius *= energy_decay_rate

	print("💰 Traded %d flour → %d credits (rate: %d/flour) [%s state]" % [
		flour_amount, credits_received, actual_rate, measurement
	])

	# Step 5: Guild perceives and responds
	_apply_guild_pressure()

	return {
		"success": true,
		"flour_sold": flour_amount,
		"credits_received": credits_received,
		"rate_achieved": actual_rate,
		"measurement": measurement,
		"flour_probability": probs["flour"],
		"new_theta": market_qubit.theta,
		"new_energy": market_qubit.radius
	}


func inject_flour_from_mill(flour_amount: int) -> Dictionary:
	"""
	Mill produces flour and injects it into market

	Effect:
	- Increases flour supply in market
	- Pushes theta toward π (flour-abundant)
	- Increases market energy (new volume)
	- Guild perceives and applies pressure
	"""
	if not market_qubit or flour_amount <= 0:
		return {
			"flour_injected": 0,
			"new_theta": market_qubit.theta if market_qubit else 0.0,
			"new_energy": market_qubit.radius if market_qubit else 1.0,
			"flour_probability": 0.0
		}

	# Flour injection pushes toward flour-abundant state
	var theta_injection = flour_amount * injection_strength * 0.5  # Mill is gentler than trading
	market_qubit.theta += theta_injection  # Push toward π (flour-rich)

	# Keep bounded
	market_qubit.theta = fmod(market_qubit.theta, TAU)

	# Mill injection adds energy (new production)
	var energy_addition = min(0.05, flour_amount * 0.001)
	market_qubit.radius = min(1.0, market_qubit.radius + energy_addition)

	print("🏭 Mill injected %d flour → Market pushed toward flour-abundance" % flour_amount)

	# Guild perceives and applies pressure
	_apply_guild_pressure()

	return {
		"flour_injected": flour_amount,
		"new_theta": market_qubit.theta,
		"new_energy": market_qubit.radius,
		"flour_probability": sin(market_qubit.theta / 2.0) ** 2
	}


## ========== GUILD INTERFACE ==========

func set_bread_qubit(bread: DualEmojiQubit):
	"""Set the bread qubit that guilds will drain"""
	bread_qubit = bread


func drain_bread_energy(delta: float = 0.02):
	"""
	Guilds constantly consume bread, draining its energy

	This is called periodically (or per update step) to simulate consumption
	"""
	if not bread_qubit:
		return

	var drained = bread_consumption_rate * bread_qubit.radius
	bread_qubit.radius *= (1.0 - bread_consumption_rate)

	# As bread is consumed, guild storage fills
	storage_icon.radius = min(1.0, storage_icon.radius + drained * 0.1)

	print("🍞 Guild consuming bread energy (drained: %.3f, storage now: %.2f)" % [
		drained,
		storage_icon.radius
	])


func _apply_guild_pressure():
	"""
	Guild applies pressure to market based on current supplies

	Pure quantum force - no coins, no resources tracked
	Just effects on the (🌾, 💰) market state
	"""
	if not market_qubit:
		return

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


func get_market_state() -> Dictionary:
	"""Full market state for display/analysis"""
	var probs = get_measurement_probabilities()

	return {
		"theta": market_qubit.theta,
		"phi": market_qubit.phi,
		"energy": market_qubit.radius,
		"flour_probability": probs["flour"],
		"coins_probability": probs["coins"],
		"flour_value": int(base_flour_value * (1.0 + probs["coins"])),
		"coin_scarcity": 1.0 - probs["coins"],
		"last_measurements": measurement_history.slice(-5),
		"theta_degrees": market_qubit.theta * 180.0 / PI
	}


func get_biome_type() -> String:
	"""Return biome type identifier"""
	return "Economic"


func get_guild_status() -> Dictionary:
	"""Current guild state for monitoring/display"""
	return {
		"storage_level": storage_icon.radius,
		"storage_theta": storage_icon.theta,
		"flour_satisfaction": cos(flour_icon.theta / 2.0) ** 2,
		"wheat_reserves": cos(wheat_icon.theta / 2.0) ** 2,
		"water_reserves": cos(water_icon.theta / 2.0) ** 2,
		"consumption_rate": bread_consumption_rate,
		"time_until_check": guild_check_in_period - time_tracker.time_elapsed
	}


func _reset_custom() -> void:
	"""Override parent: Reset economic biome to initial state"""
	# Market
	market_qubit.theta = PI / 2.0
	market_qubit.radius = 1.0
	measurement_history.clear()

	# Guilds
	storage_icon.theta = PI / 2.0
	storage_icon.radius = 0.5
	flour_icon.theta = PI / 2.0
	wheat_icon.theta = PI / 2.0
	water_icon.theta = PI / 2.0

	# Bread
	if bread_qubit:
		bread_qubit.theta = PI / 2.0
		bread_qubit.radius = 1.0

	print("🔄 Economic biome reset to initial state")
