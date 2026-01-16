class_name MarketBiome
extends "res://Core/Environment/BiomeBase.gd"

## Quantum Market Biome v3: Unified QuantumComputer Architecture
##
## Architecture: QuantumComputer with 3-qubit tensor product
##
## Core Market State (8D):
##   Qubit 0 (Sentiment): 🐂 Bull / 🐻 Bear
##   Qubit 1 (Liquidity): 💰 Money / 💳 Debt
##   Qubit 2 (Stability): 🏛️ Order / 🏚️ Chaos
##
## Basis States (tensor product):
##   |000⟩ = 🐂💰🏛️ (Bull + Money + Stable) - best market
##   |001⟩ = 🐂💰🏚️ (Bull + Money + Chaos)
##   |010⟩ = 🐂💳🏛️ (Bull + Debt + Stable)
##   |011⟩ = 🐂💳🏚️ (Bull + Debt + Chaos)
##   |100⟩ = 🐻💰🏛️ (Bear + Money + Stable)
##   |101⟩ = 🐻💰🏚️ (Bear + Money + Chaos)
##   |110⟩ = 🐻💳🏛️ (Bear + Debt + Stable)
##   |111⟩ = 🐻💳🏚️ (Bear + Debt + Chaos) - crash state
##
## Physics:
##   - Emergent pricing from Hamiltonian spectral overlap
##   - Lindblad-driven exchange (trace conserving)
##   - Detuning modulation (sentiment affects price)

# ═══════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════

const BASE_PRICE = 1.0
const SENTIMENT_CYCLE_PERIOD = 60.0
const TRADE_DRIVE_RATE = 5.0
const LARGE_TRADE_THRESHOLD = 100
const MARKET_IMPACT_STRENGTH = 0.05
const MARKET_LIQUIDITY_POOL = 10000
const GAMMA_SQUARED = 1.0

const BULL_BOOST = 1.5
const BEAR_DISCOUNT = 0.5
const CHAOS_PENALTY = 0.7
const STABLE_BONUS = 1.0

const CORE_DECAY_RATE = 0.02
const COMMODITY_DECAY_RATE = 0.01

# ═══════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════

var farm_economy = null
var active_commodities: Array[String] = []
var active_trade_drives: Dictionary = {}

# ═══════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	super._ready()

	# Register emoji pairings for 3-qubit system
	register_emoji_pair("🐂", "🐻")  # Sentiment axis
	register_emoji_pair("💰", "💳")  # Liquidity axis
	register_emoji_pair("🏛️", "🏚️")  # Stability axis

	# Register planting capabilities (Parametric System - Phase 1)
	# Market commodities (trading goods)
	register_planting_capability("🍞", "💨", "bread", {"🍞": 10}, "Bread", false)
	register_planting_capability("💨", "🌾", "flour", {"💨": 10}, "Flour", false)

	# Configure visual properties for QuantumForceGraph
	visual_color = Color(1.0, 0.55, 0.0, 0.3)
	visual_label = "📈 Market"
	visual_center_offset = Vector2(-1.15, -0.25)
	visual_oval_width = 400.0
	visual_oval_height = 250.0

	print("  ✅ MarketBiome v3 initialized (QuantumComputer, 3 qubits)")


func _initialize_bath() -> void:
	"""Initialize QuantumComputer for Market biome (3 qubits)."""
	print("📈 Initializing Market QuantumComputer...")

	# Create QuantumComputer with RegisterMap
	quantum_computer = QuantumComputer.new("Market")

	# Allocate 3 qubits with emoji axes
	quantum_computer.allocate_axis(0, "🐂", "🐻")  # Sentiment: Bull/Bear
	quantum_computer.allocate_axis(1, "💰", "💳")  # Liquidity: Money/Debt
	quantum_computer.allocate_axis(2, "🏛️", "🏚️")  # Stability: Order/Chaos

	# Initialize to weighted distribution (neutral market, bias toward stability)
	# Start with |000⟩ and let operators create the distribution
	quantum_computer.initialize_basis(0)

	print("  📊 RegisterMap configured (3 qubits, 8 basis states)")

	# Get Icons from IconRegistry
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		push_error("📈 IconRegistry not available!")
		return

	# Get or create Icons for market emojis
	var market_emojis = ["🐂", "🐻", "💰", "💳", "🏛️", "🏚️"]
	var icons = {}

	for emoji in market_emojis:
		var icon = icon_registry.get_icon(emoji)
		if not icon:
			# Create basic market icon if not found
			icon = _create_market_emoji_icon(emoji)
			icon_registry.register_icon(icon)
		icons[emoji] = icon

	# Configure market-specific dynamics
	_configure_market_dynamics(icons, icon_registry)

	# Build operators using cached method
	build_operators_cached("MarketBiome", icons)

	print("  ✅ Hamiltonian: %dx%d matrix" % [
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0,
		quantum_computer.hamiltonian.n if quantum_computer.hamiltonian else 0
	])
	print("  ✅ Lindblad: %d operators + %d gated configs" % [
		quantum_computer.lindblad_operators.size(),
		quantum_computer.gated_lindblad_configs.size()])
	print("  📈 Market QuantumComputer ready!")


func _create_market_emoji_icon(emoji: String) -> Icon:
	"""Create basic Icon for market emoji."""
	var icon = Icon.new()
	icon.emoji = emoji
	icon.display_name = "Market " + emoji

	# Set up basic couplings based on emoji role
	match emoji:
		"🐂":  # Bull - couples to bear (sentiment flip)
			icon.hamiltonian_couplings = {"🐻": 0.1}
			icon.self_energy = 0.5
		"🐻":  # Bear - couples to bull
			icon.hamiltonian_couplings = {"🐂": 0.1}
			icon.self_energy = -0.5
		"💰":  # Money - couples to debt
			icon.hamiltonian_couplings = {"💳": 0.2}
			icon.self_energy = 0.3
		"💳":  # Debt - couples to money
			icon.hamiltonian_couplings = {"💰": 0.2}
			icon.self_energy = -0.3
		"🏛️":  # Order - stable
			icon.hamiltonian_couplings = {"🏚️": 0.05}
			icon.self_energy = 0.2
			icon.decay_rate = 0.02
			icon.decay_target = "🏚️"
		"🏚️":  # Chaos - absorbing tendency
			icon.hamiltonian_couplings = {"🏛️": 0.03}
			icon.self_energy = -0.4

	return icon


func _configure_market_dynamics(icons: Dictionary, icon_registry) -> void:
	"""Configure market-specific Icon dynamics."""
	# Sentiment oscillation (bull ↔ bear)
	if icons.has("🐂") and icons.has("🐻"):
		icons["🐂"].hamiltonian_couplings["🐻"] = 0.1
		icons["🐻"].hamiltonian_couplings["🐂"] = 0.1

	# Liquidity flow (money ↔ debt)
	if icons.has("💰") and icons.has("💳"):
		icons["💰"].hamiltonian_couplings["💳"] = 0.2
		icons["💳"].hamiltonian_couplings["💰"] = 0.2

	# Stability decay (order → chaos entropy)
	if icons.has("🏛️"):
		icons["🏛️"].decay_rate = 0.05
		icons["🏛️"].decay_target = "🏚️"


func rebuild_quantum_operators() -> void:
	"""Rebuild operators after IconRegistry is ready."""
	if not quantum_computer:
		return

	print("  🔧 Market: Rebuilding quantum operators...")

	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		return

	var market_emojis = ["🐂", "🐻", "💰", "💳", "🏛️", "🏚️"]
	var icons = {}

	for emoji in market_emojis:
		var icon = icon_registry.get_icon(emoji)
		if icon:
			icons[emoji] = icon

	_configure_market_dynamics(icons, icon_registry)

	build_operators_cached("MarketBiome", icons)

	print("  ✅ Market: Rebuilt operators")


func _update_quantum_substrate(dt: float) -> void:
	"""Evolve market quantum state."""
	if quantum_computer:
		quantum_computer.evolve(dt)

		# SEMANTIC TOPOLOGY: Record phase space trajectory
		_record_attractor_snapshot()

	# Apply semantic drift game mechanics (🌀 chaos vs ✨ stability)
	super._update_quantum_substrate(dt)


# ═══════════════════════════════════════════════════════════════════════════
# MARGINAL PROBABILITIES (Qubit Queries)
# ═══════════════════════════════════════════════════════════════════════════

func get_marginal_sentiment() -> float:
	"""P(🐂) = marginal probability of bull sentiment."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_marginal(0, 0)  # Qubit 0, pole 0 (north = 🐂)


func get_marginal_liquidity() -> float:
	"""P(💰) = marginal probability of money (vs debt)."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_marginal(1, 0)  # Qubit 1, pole 0 (north = 💰)


func get_marginal_stability() -> float:
	"""P(🏛️) = marginal probability of order (vs chaos)."""
	if not quantum_computer:
		return 0.5
	return quantum_computer.get_marginal(2, 0)  # Qubit 2, pole 0 (north = 🏛️)


# ═══════════════════════════════════════════════════════════════════════════
# EMERGENT PRICING
# ═══════════════════════════════════════════════════════════════════════════

func get_commodity_price(emoji: String) -> float:
	"""Calculate emergent price from market state."""
	if not quantum_computer:
		return BASE_PRICE

	var sentiment = get_marginal_sentiment()
	var liquidity = get_marginal_liquidity()
	var stability = get_marginal_stability()

	# Price modulated by market conditions
	var sentiment_factor = lerp(BEAR_DISCOUNT, BULL_BOOST, sentiment)
	var stability_factor = lerp(CHAOS_PENALTY, STABLE_BONUS, stability)
	var liquidity_factor = 0.5 + 0.5 * liquidity  # More money = slightly higher prices

	var price = BASE_PRICE * sentiment_factor * stability_factor * liquidity_factor

	# Detuning correction
	var detuning = 2.0 * (1.0 - sentiment)
	var omega_eff = price / (1.0 + detuning * detuning / GAMMA_SQUARED)

	return max(0.1, omega_eff)


# ═══════════════════════════════════════════════════════════════════════════
# COMMODITY INJECTION
# ═══════════════════════════════════════════════════════════════════════════

func inject_commodity(emoji: String) -> bool:
	"""Add commodity to market for trading."""
	if emoji in active_commodities:
		return true

	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		return false

	var existing_icon = icon_registry.get_icon(emoji)
	if not existing_icon:
		# Create commodity icon
		var commodity_icon = _create_commodity_icon(emoji)
		icon_registry.register_icon(commodity_icon)

	active_commodities.append(emoji)
	print("📈 Market: Injected commodity %s" % emoji)
	return true


func _create_commodity_icon(emoji: String) -> Icon:
	"""Create Icon for generic commodity."""
	var icon = Icon.new()
	icon.emoji = emoji
	icon.display_name = "Commodity " + emoji

	# Commodities couple to money states
	icon.hamiltonian_couplings = {
		"💰": BASE_PRICE * BULL_BOOST,
	}
	icon.decay_rate = COMMODITY_DECAY_RATE
	icon.decay_target = "🍂"

	return icon


# ═══════════════════════════════════════════════════════════════════════════
# TRADING API
# ═══════════════════════════════════════════════════════════════════════════

func buy_resource(emoji: String, amount: int) -> bool:
	"""Player buys resource from Market."""
	if not farm_economy:
		push_error("📈 Market: No economy reference!")
		return false

	if not emoji in active_commodities:
		inject_commodity(emoji)

	var price_per_unit = get_commodity_price(emoji)
	var units = int(amount / price_per_unit)
	if units <= 0:
		return false

	var actual_cost = int(units * price_per_unit)

	if farm_economy.get_resource("💰") < actual_cost:
		print("❌ Market: Not enough 💰!")
		return false

	if not _check_liquidity_available(actual_cost):
		print("⚠️ Market: Liquidity crisis!")
		return false

	farm_economy.remove_resource("💰", actual_cost, "market_purchase")
	farm_economy.add_resource(emoji, units, "market_purchase")

	print("📈 Market: Bought %d %s for %d 💰 (price: %.2f)" % [
		units, emoji, actual_cost, price_per_unit])

	if actual_cost > LARGE_TRADE_THRESHOLD:
		_apply_market_impact(-MARKET_IMPACT_STRENGTH)

	return true


func sell_resource(emoji: String, amount: int) -> bool:
	"""Player sells resource to Market."""
	if not farm_economy:
		push_error("📈 Market: No economy reference!")
		return false

	if not emoji in active_commodities:
		inject_commodity(emoji)

	if farm_economy.get_resource(emoji) < amount:
		print("❌ Market: Not enough %s!" % emoji)
		return false

	var price_per_unit = get_commodity_price(emoji)
	var reward = int(amount * price_per_unit)

	farm_economy.remove_resource(emoji, amount, "market_sale")
	farm_economy.add_resource("💰", reward, "market_sale")

	print("📈 Market: Sold %d %s for %d 💰 (price: %.2f)" % [
		amount, emoji, reward, price_per_unit])

	if amount > LARGE_TRADE_THRESHOLD:
		_apply_market_impact(+MARKET_IMPACT_STRENGTH)

	return true


func _apply_market_impact(sentiment_shift: float) -> void:
	"""Apply market impact via density matrix perturbation."""
	if not quantum_computer:
		return

	# For now, just log the impact - full implementation would
	# apply a small rotation to the sentiment qubit
	print("📈 Market impact: %.3f sentiment shift" % sentiment_shift)


func _check_liquidity_available(amount: int) -> bool:
	"""Check if market has enough liquidity."""
	var money_prob = get_marginal_liquidity()
	var available_money = int(money_prob * MARKET_LIQUIDITY_POOL)
	return available_money >= amount


# ═══════════════════════════════════════════════════════════════════════════
# MARKET STATUS
# ═══════════════════════════════════════════════════════════════════════════

func get_market_status() -> Dictionary:
	"""Get full market state for UI display."""
	var crash_prob = 0.0
	if quantum_computer:
		# Crash state = |111⟩ = Bear + Debt + Chaos
		# Calculate from marginals (approximation)
		var bear = 1.0 - get_marginal_sentiment()
		var debt = 1.0 - get_marginal_liquidity()
		var chaos = 1.0 - get_marginal_stability()
		crash_prob = bear * debt * chaos

	return {
		"sentiment": get_marginal_sentiment(),
		"sentiment_label": _get_sentiment_label(),
		"liquidity": get_marginal_liquidity(),
		"stability": get_marginal_stability(),
		"crash_probability": crash_prob,
		"active_commodities": active_commodities.size(),
		"liquidity_pool": int(get_marginal_liquidity() * MARKET_LIQUIDITY_POOL),
	}


func _get_sentiment_label() -> String:
	"""Convert sentiment probability to human label."""
	var sentiment = get_marginal_sentiment()
	if sentiment > 0.7:
		return "🐂 Strong Bull"
	elif sentiment > 0.5:
		return "🐂 Mild Bull"
	elif sentiment > 0.3:
		return "🐻 Mild Bear"
	else:
		return "🐻 Strong Bear"


func get_biome_type() -> String:
	"""Return biome type identifier."""
	return "Market"
