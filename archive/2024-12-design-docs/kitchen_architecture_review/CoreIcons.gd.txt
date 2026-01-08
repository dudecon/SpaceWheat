class_name CoreIcons
extends RefCounted

## CoreIcons: Built-in Icon definitions for SpaceWheat
## Defines the fundamental emoji interactions in the quantum bath

## Helper to create typed String arrays for tags
static func make_tags(tag_list: Array) -> Array[String]:
	var result: Array[String] = []
	for tag in tag_list:
		result.append(tag)
	return result

## Register all core Icons with the IconRegistry
## Pass registry instance to avoid circular dependency
static func register_all(registry) -> void:
	_register_celestial(registry)
	_register_flora(registry)
	_register_fauna(registry)
	_register_elements(registry)
	_register_abstract(registry)
	_register_reserved(registry)
	_register_market(registry)
	_register_kitchen(registry)

## ========================================
## Celestial Icons (Drivers)
## ========================================

static func _register_celestial(registry) -> void:
	# ☀ Sun - Primary driver, day/night cycle
	var sun = Icon.new()
	sun.emoji = "☀"
	sun.display_name = "Sol"
	sun.description = "The eternal light that drives all life"
	sun.self_energy = 1.0
	sun.self_energy_driver = "cosine"
	sun.driver_frequency = 0.05  # Cycles per second
	sun.driver_phase = 0.0
	sun.driver_amplitude = 1.0
	sun.hamiltonian_couplings = {
		"🌙": 0.8,  # Coupled to moon (day/night opposition)
		"🌿": 0.3,  # Couples to vegetation
		"🌾": 0.4,  # Couples to wheat
		"🌱": 0.3   # Couples to seedlings
	}
	sun.tags = make_tags(["celestial", "driver", "light", "eternal"])
	sun.is_driver = true
	sun.is_eternal = true
	registry.register_icon(sun)

	# 🌙 Moon - Secondary driver, lunar cycle
	var moon = Icon.new()
	moon.emoji = "🌙"
	moon.display_name = "Luna"
	moon.description = "The pale companion, ruler of night and tides"
	moon.self_energy = 0.8
	moon.self_energy_driver = "sine"  # 90° phase shift from sun
	moon.driver_frequency = 0.05
	moon.driver_phase = PI / 2.0
	moon.driver_amplitude = 1.0
	moon.hamiltonian_couplings = {
		"☀": 0.8,   # Coupled to sun
		"🍄": 0.6,  # Strong coupling to mushrooms
		"💧": 0.4   # Coupling to water (tides)
	}
	moon.tags = make_tags(["celestial", "driver", "lunar", "eternal"])
	moon.is_driver = true
	moon.is_eternal = true
	registry.register_icon(moon)

## ========================================
## Flora Icons (Producers)
## ========================================

static func _register_flora(registry) -> void:
	# 🌾 Wheat - Cultivated crop
	var wheat = Icon.new()
	wheat.emoji = "🌾"
	wheat.display_name = "Wheat"
	wheat.description = "The golden grain, sustainer of civilizations"
	wheat.self_energy = 0.1
	wheat.hamiltonian_couplings = {
		"☀": 0.5,   # Couples to sun
		"💧": 0.4,  # Couples to water
		"⛰": 0.3   # Couples to soil
	}
	# Lindblad rates in amplitude transfer/sec (not energy/sec)
	# Wheat is slow-growing crop: 30x slower than original energy-based rates
	wheat.lindblad_incoming = {
		"☀": 0.00267,  # Grows from sunlight (was 0.08)
		"💧": 0.00167, # Grows from water (was 0.05)
		"⛰": 0.00067  # Draws from soil (was 0.02)
	}
	wheat.decay_rate = 0.02
	wheat.decay_target = "🍂"
	wheat.energy_couplings = {
		"☀": +0.08,  # Grows from sun (positive coupling)
		"💧": +0.05  # Grows from water (positive coupling)
	}
	wheat.trophic_level = 1  # Producer
	wheat.tags = make_tags(["flora", "cultivated", "producer"])
	registry.register_icon(wheat)

	# 🍄 Mushroom - Decomposer, moon-linked
	var mushroom = Icon.new()
	mushroom.emoji = "🍄"
	mushroom.display_name = "Mushroom"
	mushroom.description = "The moon-child, decomposer of dead things"
	mushroom.self_energy = 0.05
	mushroom.hamiltonian_couplings = {
		"🌙": 0.6,  # Strong coupling to moon
		"🍂": 0.5   # Coupling to organic matter
	}
	# Mushrooms pop up overnight: 10x slower than original rates
	mushroom.lindblad_incoming = {
		"🌙": 0.006,  # Grows from moon influence (was 0.06)
		"🍂": 0.012   # Grows from organic matter (was 0.12)
	}
	mushroom.decay_rate = 0.03
	mushroom.decay_target = "🍂"
	mushroom.energy_couplings = {
		"☀": -0.20,  # Take damage from sun (negative coupling - proximity-based depletion)
		"🌙": +0.40   # Grow from moon (positive coupling - proximity-based growth)
	}
	mushroom.trophic_level = 1  # Producer/Decomposer
	mushroom.tags = make_tags(["flora", "decomposer", "lunar"])
	registry.register_icon(mushroom)

	# 🌿 Vegetation - Base producer
	var vegetation = Icon.new()
	vegetation.emoji = "🌿"
	vegetation.display_name = "Vegetation"
	vegetation.description = "The green foundation of all ecosystems"
	vegetation.self_energy = 0.1
	vegetation.hamiltonian_couplings = {
		"☀": 0.6,   # Strong coupling to sun
		"💧": 0.5,  # Coupling to water
		"🍂": 0.3   # Coupling to organic matter (nutrient cycling)
	}
	# Vegetation: 10x slower rates
	vegetation.lindblad_incoming = {
		"☀": 0.010,  # Grows from sunlight (was 0.10)
		"💧": 0.006, # Grows from water (was 0.06)
		"🍂": 0.004  # Grows from decomposed matter (was 0.04)
	}
	vegetation.decay_rate = 0.025
	vegetation.decay_target = "🍂"
	vegetation.trophic_level = 1  # Producer
	vegetation.tags = make_tags(["flora", "producer", "foundation"])
	registry.register_icon(vegetation)

	# 🌱 Seedling - Potential, growth
	var seedling = Icon.new()
	seedling.emoji = "🌱"
	seedling.display_name = "Seedling"
	seedling.description = "The promise of life, pure potential"
	seedling.self_energy = 0.05
	seedling.hamiltonian_couplings = {
		"☀": 0.4,   # Coupling to sun
		"💧": 0.6,  # Strong coupling to water (needs it to germinate)
		"⛰": 0.4   # Coupling to soil
	}
	# Seedling: 10x slower rates
	seedling.lindblad_outgoing = {
		"🌿": 0.008   # Grows into vegetation (was 0.08)
	}
	seedling.decay_rate = 0.04  # Higher decay (many seeds fail)
	seedling.decay_target = "🍂"
	seedling.trophic_level = 1  # Producer
	seedling.tags = make_tags(["flora", "potential", "fragile"])
	registry.register_icon(seedling)

## ========================================
## Fauna Icons (Consumers)
## ========================================

static func _register_fauna(registry) -> void:
	# 🐺 Wolf - Apex predator
	var wolf = Icon.new()
	wolf.emoji = "🐺"
	wolf.display_name = "Wolf"
	wolf.description = "The apex hunter, keeper of balance"
	wolf.self_energy = -0.05  # Slight negative (needs food to survive)
	wolf.hamiltonian_couplings = {
		"🐇": 0.6,  # Strong coupling to rabbits (hunting awareness)
		"🦌": 0.5,  # Coupling to deer
		"🌳": 0.2   # Weak coupling to forest (shelter)
	}
	# Wolf: 10x slower predation rates
	wolf.lindblad_incoming = {
		"🐇": 0.015,  # Gains from eating rabbits (was 0.15)
		"🦌": 0.012   # Gains from eating deer (was 0.12)
	}
	wolf.decay_rate = 0.03
	wolf.decay_target = "💀"
	wolf.trophic_level = 3  # Carnivore
	wolf.tags = make_tags(["fauna", "predator", "apex"])
	registry.register_icon(wolf)

	# 🐇 Rabbit - Primary prey, reproducer
	var rabbit = Icon.new()
	rabbit.emoji = "🐇"
	rabbit.display_name = "Rabbit"
	rabbit.description = "The swift reproducer, food for many"
	rabbit.self_energy = 0.02  # Slight positive (reproductive)
	rabbit.hamiltonian_couplings = {
		"🌿": 0.5,  # Coupling to vegetation (food)
		"🐺": 0.6,  # Strong coupling to wolf (danger awareness)
		"🦅": 0.4   # Coupling to eagle (danger)
	}
	# Rabbit: 10x slower herbivory rate
	rabbit.lindblad_incoming = {
		"🌿": 0.010   # Gains from eating vegetation (was 0.10)
	}
	rabbit.decay_rate = 0.05
	rabbit.decay_target = "💀"
	rabbit.trophic_level = 2  # Herbivore
	rabbit.tags = make_tags(["fauna", "herbivore", "prey"])
	registry.register_icon(rabbit)

	# 🦌 Deer - Large herbivore
	var deer = Icon.new()
	deer.emoji = "🦌"
	deer.display_name = "Deer"
	deer.description = "The graceful grazer of the forest"
	deer.self_energy = 0.01
	deer.hamiltonian_couplings = {
		"🌿": 0.6,  # Strong coupling to vegetation
		"🌳": 0.4,  # Coupling to forest
		"🐺": 0.5   # Coupling to wolf (danger)
	}
	# Deer: 10x slower herbivory rate
	deer.lindblad_incoming = {
		"🌿": 0.008   # Gains from vegetation (was 0.08)
	}
	deer.decay_rate = 0.04
	deer.decay_target = "💀"
	deer.trophic_level = 2  # Herbivore
	deer.tags = make_tags(["fauna", "herbivore", "large"])
	registry.register_icon(deer)

	# 🦅 Eagle - Apex aerial predator
	var eagle = Icon.new()
	eagle.emoji = "🦅"
	eagle.display_name = "Eagle"
	eagle.description = "The sky-lord, swift death from above"
	eagle.self_energy = -0.03
	eagle.hamiltonian_couplings = {
		"🐇": 0.5,  # Coupling to rabbits
		"🐭": 0.4   # Coupling to mice
	}
	# Eagle: 10x slower predation rates
	eagle.lindblad_incoming = {
		"🐇": 0.010,  # Gains from rabbits (was 0.10)
		"🐭": 0.008   # Gains from mice (was 0.08)
	}
	eagle.decay_rate = 0.025
	eagle.decay_target = "💀"
	eagle.trophic_level = 3  # Carnivore
	eagle.tags = make_tags(["fauna", "predator", "aerial"])
	registry.register_icon(eagle)

## ========================================
## Elemental Icons (Abiotic)
## ========================================

static func _register_elements(registry) -> void:
	# 💧 Water - Flow, life sustainer
	var water = Icon.new()
	water.emoji = "💧"
	water.display_name = "Water"
	water.description = "The flow of life, essence of all things"
	water.self_energy = 0.0  # Neutral
	water.hamiltonian_couplings = {
		"🌙": 0.4,  # Coupling to moon (tides)
		"🌿": 0.3,  # Coupling to vegetation
		"🌾": 0.3   # Coupling to wheat
	}
	water.trophic_level = 0  # Abiotic
	water.tags = make_tags(["element", "water", "abiotic", "essential"])
	water.is_eternal = true
	registry.register_icon(water)

	# ⛰ Soil - Foundation, nutrients
	var soil = Icon.new()
	soil.emoji = "⛰"
	soil.display_name = "Soil"
	soil.description = "The foundation, holder of minerals and memory"
	soil.self_energy = 0.0
	soil.hamiltonian_couplings = {
		"🌿": 0.3,  # Coupling to vegetation
		"🌾": 0.3,  # Coupling to wheat
		"🍂": 0.4   # Coupling to organic matter
	}
	# Soil: 10x slower accumulation
	soil.lindblad_incoming = {
		"🍂": 0.002   # Slowly accumulates from decay (was 0.02)
	}
	soil.trophic_level = 0  # Abiotic
	soil.tags = make_tags(["element", "soil", "abiotic", "foundation"])
	water.is_eternal = true
	registry.register_icon(soil)

	# 🍂 Organic Matter - Recycling node
	var organic_matter = Icon.new()
	organic_matter.emoji = "🍂"
	organic_matter.display_name = "Organic Matter"
	organic_matter.description = "The cycle's currency, death's gift to life"
	organic_matter.self_energy = 0.0
	organic_matter.hamiltonian_couplings = {
		"🌿": 0.3,  # Couples to vegetation (nutrient cycling)
		"🍄": 0.5,  # Strong coupling to mushrooms
		"⛰": 0.3   # Coupling to soil
	}
	# Note: Receives from many decay_rate terms, no need to specify lindblad_incoming here
	organic_matter.trophic_level = 0  # Abiotic/decomposed
	organic_matter.tags = make_tags(["element", "decay", "recycling", "foundation"])
	registry.register_icon(organic_matter)

## ========================================
## Abstract Icons (Conceptual)
## ========================================

static func _register_abstract(registry) -> void:
	# 💀 Death/Labor - Terminus/Human input
	var death = Icon.new()
	death.emoji = "💀"
	death.display_name = "Death/Labor"
	death.description = "The end and the beginning, the price of life"
	death.self_energy = 0.0
	death.hamiltonian_couplings = {
		"🍂": 0.4,  # Coupling to organic matter
		"👥": 0.3   # Coupling to human effort
	}
	# Death: 10x slower decay rate
	death.lindblad_outgoing = {
		"🍂": 0.005   # Decay to organic matter (was 0.05)
	}
	# Note: Receives from many decay_target terms
	death.trophic_level = 0  # Abstract
	death.tags = make_tags(["abstract", "death", "transformation"])
	registry.register_icon(death)

	# 👥 Human Effort - Labor input
	var labor = Icon.new()
	labor.emoji = "👥"
	labor.display_name = "Human Effort"
	labor.description = "The will applied, civilization's engine"
	labor.self_energy = 0.05
	labor.hamiltonian_couplings = {
		"🌾": 0.5,  # Strong coupling to wheat (cultivation)
		"💀": 0.3,  # Coupling to death/labor
		"⛰": 0.3   # Coupling to soil (working the land)
	}
	labor.trophic_level = 0  # Abstract
	labor.tags = make_tags(["abstract", "labor", "human", "cultivation"])
	registry.register_icon(labor)

## ========================================
## Reserved Icons (Future expansion)
## ========================================

static func _register_reserved(registry) -> void:
	# 🌳 Forest - Ecosystem anchor
	var forest = Icon.new()
	forest.emoji = "🌳"
	forest.display_name = "Forest"
	forest.description = "The living cathedral, home to multitudes"
	forest.self_energy = 0.0
	forest.hamiltonian_couplings = {
		"🌿": 0.4,  # Coupling to vegetation
		"🐺": 0.2,  # Weak coupling to wolf (shelter)
		"🦌": 0.3   # Coupling to deer
	}
	forest.trophic_level = 0  # Ecosystem
	forest.tags = make_tags(["ecosystem", "forest", "structure"])
	registry.register_icon(forest)

	# 🐭 Mouse - Small prey
	var mouse = Icon.new()
	mouse.emoji = "🐭"
	mouse.display_name = "Mouse"
	mouse.description = "The tiny survivor, food for many"
	mouse.self_energy = 0.01
	mouse.hamiltonian_couplings = {
		"🌿": 0.4,  # Coupling to vegetation
		"🦅": 0.5,  # Coupling to eagle (danger)
		"🐜": 0.2   # Weak coupling to bugs
	}
	mouse.lindblad_incoming = {"🌿": 0.006}  # 10x slower (was 0.06)
	mouse.decay_rate = 0.06
	mouse.decay_target = "💀"
	mouse.trophic_level = 2  # Herbivore
	mouse.tags = make_tags(["fauna", "herbivore", "small", "prey"])
	registry.register_icon(mouse)

	# 🐦 Bird - Disperser, small predator
	var bird = Icon.new()
	bird.emoji = "🐦"
	bird.display_name = "Bird"
	bird.description = "The wanderer, seed-carrier and singer"
	bird.self_energy = 0.0
	bird.hamiltonian_couplings = {
		"🌿": 0.3,  # Coupling to vegetation
		"🐜": 0.4,  # Coupling to bugs
		"🌱": 0.3   # Coupling to seedlings (dispersal)
	}
	bird.lindblad_incoming = {"🐜": 0.007}  # 10x slower (was 0.07)
	bird.decay_rate = 0.04
	bird.decay_target = "💀"
	bird.trophic_level = 2  # Omnivore
	bird.tags = make_tags(["fauna", "omnivore", "disperser"])
	registry.register_icon(bird)

	# 🐜 Bug - Decomposer, base prey
	var bug = Icon.new()
	bug.emoji = "🐜"
	bug.display_name = "Bug"
	bug.description = "The tireless recycler, foundation of the food web"
	bug.self_energy = 0.02
	bug.hamiltonian_couplings = {
		"🍂": 0.5,  # Strong coupling to organic matter
		"🌿": 0.3,  # Coupling to vegetation
		"🐦": 0.4   # Coupling to birds (danger)
	}
	bug.lindblad_incoming = {"🍂": 0.008}  # 10x slower (was 0.08)
	bug.decay_rate = 0.05
	bug.decay_target = "🍂"
	bug.trophic_level = 1  # Decomposer/Detritivore
	bug.tags = make_tags(["fauna", "decomposer", "small"])
	registry.register_icon(bug)

	# 🏪 Market - Exchange node (placeholder for future)
	var market = Icon.new()
	market.emoji = "🏪"
	market.display_name = "Market"
	market.description = "The meeting place, where value flows"
	market.self_energy = 0.0
	market.hamiltonian_couplings = {
		"🌾": 0.4,  # Coupling to wheat
		"👥": 0.5   # Coupling to labor
	}
	market.trophic_level = 0  # Abstract/Economic
	market.tags = make_tags(["abstract", "economy", "exchange"])
	registry.register_icon(market)


## ========================================
## Market Icons (Economic Dynamics)
## ========================================

static func _register_market(registry) -> void:
	# 🐂 Bull - Rising markets/prices
	var bull = Icon.new()
	bull.emoji = "🐂"
	bull.display_name = "Bull Market"
	bull.description = "Rising prices, optimistic sentiment"
	bull.self_energy = 0.5
	bull.self_energy_driver = "cosine"  # Oscillates with market cycle
	bull.driver_frequency = 1.0 / 30.0  # 30-second period
	bull.driver_phase = 0.0
	bull.driver_amplitude = 0.8
	bull.hamiltonian_couplings = {
		"🐻": 0.9,  # Strong coupling to bear (opposition)
		"💰": 0.4,  # Money flows to bull markets
		"🏛️": 0.3   # Stability moderates bulls
	}
	bull.lindblad_incoming = {"💰": 0.008}  # Money flows in during bull runs (was 0.08, 10x slower)
	bull.tags = make_tags(["market", "driver", "sentiment", "rising"])
	bull.is_driver = true
	registry.register_icon(bull)

	# 🐻 Bear - Falling markets/prices
	var bear = Icon.new()
	bear.emoji = "🐻"
	bear.display_name = "Bear Market"
	bear.description = "Falling prices, pessimistic sentiment"
	bear.self_energy = -0.5
	bear.self_energy_driver = "sine"  # Oscillates opposite to bull
	bear.driver_frequency = 1.0 / 30.0  # 30-second period
	bear.driver_phase = PI  # 180° out of phase with bull
	bear.driver_amplitude = 0.8
	bear.hamiltonian_couplings = {
		"🐂": 0.9,  # Strong coupling to bull (opposition)
		"📦": 0.4,  # Goods accumulate in bear markets
		"🏚️": 0.3   # Chaos amplifies bears
	}
	bear.lindblad_incoming = {"📦": 0.006}  # Goods accumulate during downturns (was 0.06, 10x slower)
	bear.tags = make_tags(["market", "driver", "sentiment", "falling"])
	bear.is_driver = true
	registry.register_icon(bear)

	# 💰 Money - Liquid capital
	var money = Icon.new()
	money.emoji = "💰"
	money.display_name = "Money"
	money.description = "Liquid capital, ready to trade"
	money.self_energy = 0.1
	money.hamiltonian_couplings = {
		"📦": 0.6,  # Money exchanges for goods
		"🐂": 0.3,  # Flows toward bull markets
		"🏛️": 0.2   # Stable markets attract capital
	}
	money.lindblad_outgoing = {"📦": 0.005}  # Money converts to goods (was 0.05, 10x slower)
	money.tags = make_tags(["market", "currency", "liquidity"])
	registry.register_icon(money)

	# 📦 Goods - Commodities/inventory
	var goods = Icon.new()
	goods.emoji = "📦"
	goods.display_name = "Goods"
	goods.description = "Commodities and inventory"
	goods.self_energy = 0.0
	goods.hamiltonian_couplings = {
		"💰": 0.6,  # Goods exchange for money
		"🐻": 0.2   # Accumulate in bear markets
	}
	goods.lindblad_outgoing = {"💰": 0.004}  # Goods convert to money (was 0.04, 10x slower)
	goods.tags = make_tags(["market", "commodity", "inventory"])
	registry.register_icon(goods)

	# 🏛️ Stable - Granary Guilds stability
	var stable = Icon.new()
	stable.emoji = "🏛️"
	stable.display_name = "Stable Markets"
	stable.description = "Orderly, predictable trading"
	stable.self_energy = 0.2
	stable.hamiltonian_couplings = {
		"🏚️": 0.7,  # Opposition to chaos
		"💰": 0.3,  # Attracts capital
		"🐂": 0.2   # Moderates bulls
	}
	stable.tags = make_tags(["market", "stability", "order"])
	registry.register_icon(stable)

	# 🏚️ Chaotic - Market volatility/panic
	var chaotic = Icon.new()
	chaotic.emoji = "🏚️"
	chaotic.display_name = "Chaotic Markets"
	chaotic.description = "Volatile, unpredictable swings"
	chaotic.self_energy = -0.1
	chaotic.hamiltonian_couplings = {
		"🏛️": 0.7,  # Opposition to stability
		"🐻": 0.4   # Amplifies bear markets
	}
	chaotic.lindblad_outgoing = {"🏛️": 0.003}  # Chaos decays to order over time (was 0.03, 10x slower)
	chaotic.decay_rate = 0.02
	chaotic.decay_target = "🏛️"
	chaotic.tags = make_tags(["market", "volatility", "chaos"])
	registry.register_icon(chaotic)


## ========================================
## Kitchen Icons (Production/Cooking)
## ========================================

static func _register_kitchen(registry) -> void:
	# 🔥 Fire/Heat - Oven temperature (hot)
	var fire = Icon.new()
	fire.emoji = "🔥"
	fire.display_name = "Heat"
	fire.description = "The oven's fire, transforming ingredients"
	fire.self_energy = 0.8
	fire.self_energy_driver = "cosine"  # Oscillates with oven cycle
	fire.driver_frequency = 1.0 / 15.0  # 15-second period
	fire.driver_phase = 0.0
	fire.driver_amplitude = 1.0
	fire.hamiltonian_couplings = {
		"❄️": 0.8,  # Opposition to cold
		"🍞": 0.5,  # Drives bread production
		"🌾": 0.3   # Transforms wheat
	}
	fire.lindblad_incoming = {"🍞": 0.01}  # Fire helps create bread (was 0.1, 10x slower)
	fire.tags = make_tags(["kitchen", "driver", "heat", "transformation"])
	fire.is_driver = true
	registry.register_icon(fire)

	# ❄️ Cold - Oven temperature (cold)
	var cold = Icon.new()
	cold.emoji = "❄️"
	cold.display_name = "Cold"
	cold.description = "The oven rests, preserving ingredients"
	cold.self_energy = -0.3
	cold.self_energy_driver = "sine"  # Oscillates opposite to fire
	cold.driver_frequency = 1.0 / 15.0  # 15-second period
	cold.driver_phase = PI  # 180° out of phase
	cold.driver_amplitude = 0.8
	cold.hamiltonian_couplings = {
		"🔥": 0.8,  # Opposition to heat
		"🌾": 0.4   # Preserves raw wheat
	}
	cold.tags = make_tags(["kitchen", "driver", "cold", "preservation"])
	cold.is_driver = true
	registry.register_icon(cold)

	# 🍞 Bread - Finished product
	var bread = Icon.new()
	bread.emoji = "🍞"
	bread.display_name = "Bread"
	bread.description = "The fruit of labor and fire"
	bread.self_energy = 0.0
	bread.hamiltonian_couplings = {
		"🌾": 0.5,  # Connection to wheat input
		"🔥": 0.4   # Created by heat
	}
	# Bread: 10x slower production rates
	bread.lindblad_incoming = {"🌾": 0.008, "🔥": 0.005}  # Produced from wheat + heat (was 0.08/0.05, 10x slower)
	bread.tags = make_tags(["kitchen", "product", "food", "processed"])
	registry.register_icon(bread)

	# Note: 🌾 (Wheat) is already defined in Flora section
