class_name CoreFactions
extends RefCounted

## CoreFactions: The foundational factions of SpaceWheat
##
## These 7 factions are refactored from the original CoreIcons.
## Each faction defines a closed dynamical system over its signature.
## Icons are built by merging contributions from all factions.
##
## Faction Map:
##   Celestial Archons (outer) - ☀️🌙⛰️🌬️ - cosmic drivers
##   Verdant Pulse (center)    - 🌱🌿🌾🍂 - growth cycle
##   Mycelial Web (center)     - 🍄🍂🌙   - decomposition
##   Swift Herd (center)       - 🐇🦌🌿   - grazing
##   Pack Lords (second)       - 🐺🦅🐇🦌💀 - predation
##   Market Spirits (second)   - 🐂🐻💰📦🏛️🏚️ - economics
##   Hearth Keepers (center)   - 🔥❄️💧🏜️💨🍞 - production
##
## Shared Emojis (contested dynamics):
##   🌙 → Celestial + Mycelial
##   🍂 → Verdant + Mycelial
##   🌿 → Verdant + Swift
##   🐇 → Swift + Pack
##   🦌 → Swift + Pack

const Faction = preload("res://Core/Factions/Faction.gd")

## Get all core factions
static func get_all() -> Array:
	return [
		create_celestial_archons(),
		create_verdant_pulse(),
		create_mycelial_web(),
		create_swift_herd(),
		create_pack_lords(),
		create_market_spirits(),
		create_hearth_keepers(),
		create_pollinator_guild(),
		create_plague_vectors(),
		create_wildfire_dynamics(),
	]

## ========================================
## Celestial Archons (outer ring)
## The abiotic natural world: sun, moon, earth, water, air
## These are the eternal drivers that everything else responds to
## ========================================

static func create_celestial_archons() -> Faction:
	var f = Faction.new()
	f.name = "Celestial Archons"
	f.description = "The eternal substrate. Sun and moon, the four elements. The abiotic foundation."
	f.ring = "outer"
	f.signature = ["☀", "🌙", "🔥", "💧", "⛰", "🌬"]
	f.tags = ["celestial", "driver", "eternal", "abiotic", "elements"]
	
	# Self-energies (high for celestial bodies, grounded for elements)
	f.self_energies = {
		"☀": 1.0,    # Sun is primary energy source
		"🌙": 0.8,   # Moon is secondary
		"🔥": 0.6,   # Fire - active, consuming
		"💧": 0.3,   # Water - flows and cycles
		"⛰": 0.2,   # Earth is stable, grounded
		"🌬": 0.1,   # Air is ephemeral
	}
	
	# Drivers: Sun and Moon are inverted sine waves (the cosmic clock)
	# Same mechanic as 🔌 AC power, but at celestial frequency (0.05 Hz = 20 sec period)
	f.drivers = {
		"☀": {"type": "sine", "freq": 0.05, "phase": 0.0, "amp": 1.0},      # Day
		"🌙": {"type": "sine", "freq": 0.05, "phase": PI, "amp": 1.0},      # Night (inverted)
	}
	
	# Hamiltonian: elemental couplings (the classical element wheel)
	f.hamiltonian = {
		"☀": {
			"🌙": 0.8,   # Sun-Moon opposition (day/night)
			"🔥": 0.7,   # Sun feeds fire
			"💧": 0.4,   # Sun evaporates water
			"⛰": 0.3,   # Sun warms earth
			"🌬": 0.4,   # Sun drives wind
		},
		"🌙": {
			"☀": 0.8,   # Opposition
			"💧": 0.5,   # Moon affects tides
			"🌬": 0.3,   # Moon affects air
		},
		"🔥": {
			"☀": 0.7,   # Fire from sun
			"💧": 0.6,   # Fire-water opposition
			"🌬": 0.5,   # Fire needs air, air feeds fire
			"⛰": 0.3,   # Fire on earth
		},
		"💧": {
			"☀": 0.4,   # Evaporation
			"🌙": 0.5,   # Tides
			"🔥": 0.6,   # Opposition
			"⛰": 0.4,   # Groundwater
			"🌬": 0.6,   # Rain/weather
		},
		"⛰": {
			"☀": 0.3,
			"🔥": 0.3,
			"💧": 0.4,   # Earth holds water
			"🌬": 0.5,   # Earth-air interface
		},
		"🌬": {
			"☀": 0.4,
			"🔥": 0.5,   # Air feeds fire
			"💧": 0.6,   # Weather
			"⛰": 0.5,
			"🌙": 0.3,
		},
	}
	
	# No Lindblad transfers - celestial bodies are eternal, they cycle not transfer
	# No decay - eternal
	
	return f


## ========================================
## Verdant Pulse (center ring)
## The growth cycle: seed → vegetation/tree → grain → decay
## 🌲 is the stable endpoint for seeds not consumed
## ========================================

static func create_verdant_pulse() -> Faction:
	var f = Faction.new()
	f.name = "Verdant Pulse"
	f.description = "The green rhythm of growth and decay. Seeds become grass or trees, grain returns to earth."
	f.ring = "center"
	f.signature = ["🌱", "🌿", "🌾", "🌲", "🍂"]
	f.tags = ["flora", "producer", "cycle"]
	
	# Self-energies
	f.self_energies = {
		"🌱": 0.05,  # Seedling - potential energy
		"🌿": 0.1,   # Vegetation - active growth
		"🌾": 0.1,   # Wheat - cultivated
		"🌲": 0.3,   # Tree - stable, high energy reservoir
		"🍂": 0.0,   # Organic matter - ground state
	}
	
	# Hamiltonian: growth resonances
	f.hamiltonian = {
		"🌱": {
			"🌿": 0.6,   # Seedling → vegetation (fast)
			"🌲": 0.4,   # Seedling → tree (slower, if undisturbed)
			"🌾": 0.3,   # Seedling → wheat (if cultivated)
		},
		"🌿": {
			"🌱": 0.6,
			"🌾": 0.4,   # Vegetation can become grain
			"🍂": 0.4,   # All plants return to earth
		},
		"🌾": {
			"🌱": 0.3,
			"🍂": 0.5,   # Wheat decays to organic
		},
		"🌲": {
			"🌱": 0.4,   # Trees drop seeds
			"🍂": 0.2,   # Trees decay slowly
		},
		"🍂": {
			"🌿": 0.4,
			"🌾": 0.5,
			"🌱": 0.5,   # Nutrients feed new growth
			"🌲": 0.2,   # Slow contribution to trees
		},
	}
	
	# Lindblad: irreversible growth transfers
	f.lindblad_outgoing = {
		"🌱": {
			"🌿": 0.06,  # Seedling grows into vegetation
			"🌲": 0.02,  # Seedling grows into tree (slower)
		},
		"🍂": {
			"⛰": 0.005,  # Organic matter slowly becomes earth (geological time)
		},
	}
	
	f.lindblad_incoming = {
		"🌿": {
			"🍂": 0.04,  # Vegetation draws from organic matter
		},
		"🌾": {
			"🍂": 0.02,  # Wheat draws nutrients more slowly
		},
		"🌲": {
			"🍂": 0.01,  # Trees draw nutrients very slowly but steadily
			"🌬": 0.02,  # Trees drink air (CO2!) to strengthen
		},
	}
	
	# Decay: plants return to organic matter
	# 🌲 decays very slowly - it's the stable reservoir
	f.decay = {
		"🌱": {"rate": 0.04, "target": "🍂"},
		"🌿": {"rate": 0.025, "target": "🍂"},
		"🌾": {"rate": 0.02, "target": "🍂"},
		"🌲": {"rate": 0.005, "target": "🍂"},  # Trees are stable
	}
	
	# Alignment couplings: growth enhanced by celestial elements
	# These are CROSS-FACTION effects (Celestial → Verdant)
	# When P(☀️) is high, plant growth rates are enhanced
	f.alignment_couplings = {
		"🌱": {
			"☀": +0.06,   # Seedlings love sun
			"💧": +0.08,  # Seedlings need water most
			"⛰": +0.03,  # Soil helps
		},
		"🌿": {
			"☀": +0.10,   # Vegetation thrives in sun
			"💧": +0.06,  # Water helps
			"⛰": +0.02,  # Soil helps
		},
		"🌾": {
			"☀": +0.08,   # Wheat loves sun
			"💧": +0.05,  # Water helps
			"⛰": +0.04,  # Wheat draws from soil
		},
		"🌲": {
			"☀": +0.04,   # Trees like sun but are hardy
			"💧": +0.03,  # Trees need water
			"⛰": +0.05,  # Deep roots
		},
	}
	
	return f


## ========================================
## Mycelial Web (center ring)
## Moon-linked decomposition: the recyclers
## ========================================

static func create_mycelial_web() -> Faction:
	var f = Faction.new()
	f.name = "Mycelial Web"
	f.description = "The hidden network beneath. Moon-touched, death-fed, eternal recyclers. Spooky symbiosis with death itself."
	f.ring = "center"
	f.signature = ["🍄", "🍂", "🌙", "💀"]
	f.tags = ["decomposer", "lunar", "underground", "death"]
	
	# Self-energies
	# Note: 🌙 self_energy comes from Celestial Archons, we don't add here
	f.self_energies = {
		"🍄": 0.05,  # Mushroom - emerges from dark
		"🍂": 0.0,   # Organic matter - ground state
		"💀": -0.1,  # Death - the void pulls
		# "🌙" intentionally omitted - Celestial owns the moon's energy
	}
	
	# Hamiltonian: moon drives decomposition, death-mushroom resonance
	f.hamiltonian = {
		"🍄": {
			"🌙": 0.6,   # Strong moon coupling
			"🍂": 0.5,   # Feeds on decay
			"💀": 0.4,   # Spooky resonance with death
		},
		"🍂": {
			"🍄": 0.5,   # Reciprocal
			"💀": 0.3,   # Death and decay linked
		},
		"🌙": {
			"🍄": 0.6,   # Moon awakens fungi
		},
		"💀": {
			"🍄": 0.4,   # Death-mushroom resonance
			"🍂": 0.3,   # Death feeds decay
		},
	}
	
	# Lindblad: mushrooms consume organic matter, death-mushroom cycle
	f.lindblad_incoming = {
		"🍄": {
			"🌙": 0.06,  # Moon-driven emergence
			"🍂": 0.12,  # Rapid consumption of decay
			"💀": 0.03,  # Death spawns mushrooms (spooky!)
		},
		"🍂": {
			"💀": 0.08,  # Death becomes organic matter (from Pack Lords too)
		},
	}
	
	# Decay: mushrooms return to organic... and to death
	f.decay = {
		"🍄": {"rate": 0.03, "target": "🍂"},
	}
	
	# Lindblad outgoing: mushrooms also feed death slightly
	f.lindblad_outgoing = {
		"🍄": {
			"💀": 0.01,  # Mushrooms feed death a little (the cycle completes)
		},
	}
	
	# Alignment couplings: mushrooms love moon and water, SUN KILLS THEM
	f.alignment_couplings = {
		"🍄": {
			"🌙": +0.40,  # Strong moon alignment - mushrooms thrive at night
			"💧": +0.35,  # Mushrooms LOVE wet conditions
			"☀": -0.35,   # Sun actively withers mushrooms (stronger negative)
		},
	}
	
	return f


## ========================================
## Swift Herd (center ring)
## Grazing dynamics: prey animals
## ========================================

static func create_swift_herd() -> Faction:
	var f = Faction.new()
	f.name = "Swift Herd"
	f.description = "The gentle grazers. They eat the green and feed the strong."
	f.ring = "center"
	f.signature = ["🐇", "🦌", "🌿"]
	f.tags = ["fauna", "herbivore", "prey"]
	
	# Self-energies (slight positive - reproductive)
	f.self_energies = {
		"🐇": 0.02,  # Rabbits reproduce quickly
		"🦌": 0.01,  # Deer are more stable
		"🌿": 0.1,   # Vegetation (shared with Verdant)
	}
	
	# Hamiltonian: grazing awareness
	f.hamiltonian = {
		"🐇": {
			"🌿": 0.5,   # Rabbits sense vegetation
			"🦌": 0.3,   # Herd awareness
		},
		"🦌": {
			"🌿": 0.6,   # Deer graze heavily
			"🐇": 0.3,   # Share grazing grounds
		},
		"🌿": {
			"🐇": 0.5,
			"🦌": 0.6,
		},
	}
	
	# Lindblad: herbivory
	f.lindblad_incoming = {
		"🐇": {
			"🌿": 0.10,  # Rabbits gain from vegetation
		},
		"🦌": {
			"🌿": 0.08,  # Deer gain from vegetation
		},
	}
	
	# Decay: prey animals die (to 💀, handled by Pack Lords)
	# Note: we don't define decay here - Pack Lords owns 💀
	
	return f


## ========================================
## Pack Lords (second ring)
## Predation and death: apex dynamics
## ========================================

static func create_pack_lords() -> Faction:
	var f = Faction.new()
	f.name = "Pack Lords"
	f.description = "The hunters. They cull the weak and shepherd death."
	f.ring = "second"
	f.signature = ["🐺", "🦅", "🐇", "🦌", "💀"]
	f.tags = ["fauna", "predator", "apex", "death"]
	
	# Self-energies (slight negative - need to hunt)
	f.self_energies = {
		"🐺": -0.05,  # Wolf needs prey
		"🦅": -0.03,  # Eagle needs prey
		"🐇": 0.02,   # (shared with Swift)
		"🦌": 0.01,   # (shared with Swift)
		"💀": -0.1,   # Death is the sink
	}
	
	# Hamiltonian: predator-prey awareness
	f.hamiltonian = {
		"🐺": {
			"🐇": 0.6,   # Wolf hunts rabbit
			"🦌": 0.5,   # Wolf hunts deer
			"🦅": 0.2,   # Minimal competition
		},
		"🦅": {
			"🐇": 0.5,   # Eagle hunts rabbit
			"🦌": 0.3,   # Less effective on deer
			"🐺": 0.2,   # Minimal competition
		},
		"🐇": {
			"🐺": 0.6,   # Danger awareness
			"🦅": 0.5,
		},
		"🦌": {
			"🐺": 0.5,
			"🦅": 0.3,
		},
		"💀": {
			"🐺": 0.3,   # Death awaits all
			"🦅": 0.3,
			"🐇": 0.4,
			"🦌": 0.4,
		},
	}
	
	# Lindblad: predation transfers
	f.lindblad_incoming = {
		"🐺": {
			"🐇": 0.15,  # Wolf gains from rabbit
			"🦌": 0.12,  # Wolf gains from deer
		},
		"🦅": {
			"🐇": 0.12,  # Eagle gains from rabbit
		},
	}
	
	# Decay: all fauna eventually dies
	f.decay = {
		"🐺": {"rate": 0.03, "target": "💀"},
		"🦅": {"rate": 0.025, "target": "💀"},
		"🐇": {"rate": 0.05, "target": "💀"},
		"🦌": {"rate": 0.04, "target": "💀"},
	}
	
	return f


## ========================================
## Market Spirits (second ring)
## Economic oscillations: bull/bear, order/chaos
## ========================================

static func create_market_spirits() -> Faction:
	var f = Faction.new()
	f.name = "Market Spirits"
	f.description = "The invisible hands that push and pull. Greed and fear dance eternal."
	f.ring = "second"
	f.signature = ["🐂", "🐻", "💰", "📦", "🏛️", "🏚️"]
	f.tags = ["market", "economy", "oscillation"]
	
	# Self-energies
	f.self_energies = {
		"🐂": 0.5,   # Bull - positive momentum
		"🐻": -0.5,  # Bear - negative momentum
		"💰": 0.1,   # Money - slight positive
		"📦": 0.0,   # Goods - neutral
		"🏛️": 0.2,   # Stability - positive
		"🏚️": -0.1,  # Chaos - slight negative
	}
	
	# Drivers: Bull/Bear are inverted sine waves (market cycle)
	# Same mechanic as ☀🌙 and 🔌, at market frequency (0.033 Hz = 30 sec period)
	# Note: Eventually these should be reactive (driven by player actions)
	f.drivers = {
		"🐂": {"type": "sine", "freq": 1.0/30.0, "phase": 0.0, "amp": 0.8},    # Bull
		"🐻": {"type": "sine", "freq": 1.0/30.0, "phase": PI, "amp": 0.8},     # Bear (inverted)
	}
	
	# Hamiltonian: market dynamics
	f.hamiltonian = {
		"🐂": {
			"🐻": 0.9,   # Bull-bear opposition
			"💰": 0.4,   # Money flows to bulls
			"🏛️": 0.3,   # Stability moderates
		},
		"🐻": {
			"🐂": 0.9,
			"📦": 0.4,   # Goods accumulate in downturns
			"🏚️": 0.3,   # Chaos amplifies bears
		},
		"💰": {
			"📦": 0.6,   # Money ↔ goods exchange
			"🐂": 0.3,
			"🏛️": 0.2,
		},
		"📦": {
			"💰": 0.6,
			"🐻": 0.2,
		},
		"🏛️": {
			"🏚️": 0.7,   # Stability-chaos opposition
			"💰": 0.3,
			"🐂": 0.2,
		},
		"🏚️": {
			"🏛️": 0.7,
			"🐻": 0.4,
		},
	}
	
	# Lindblad: economic transfers
	f.lindblad_incoming = {
		"🐂": {
			"💰": 0.08,  # Bull runs attract money
		},
		"🐻": {
			"📦": 0.06,  # Bear markets accumulate goods
		},
	}
	
	f.lindblad_outgoing = {
		"💰": {
			"📦": 0.05,  # Money converts to goods
		},
		"📦": {
			"💰": 0.04,  # Goods convert to money
		},
		"🏚️": {
			"🏛️": 0.03,  # Chaos decays to order
		},
	}
	
	# Decay: chaos decays to stability
	f.decay = {
		"🏚️": {"rate": 0.02, "target": "🏛️"},
	}
	
	return f


## ========================================
## Hearth Keepers (center ring)
## Production: temperature × moisture × substance
## ========================================

static func create_hearth_keepers() -> Faction:
	var f = Faction.new()
	f.name = "Hearth Keepers"
	f.description = "The tenders of flame and dough. Where wheat becomes bread."
	f.ring = "center"
	f.signature = ["🔥", "❄️", "💧", "🏜️", "💨", "🍞"]
	f.tags = ["kitchen", "production", "transformation"]
	
	# Self-energies
	f.self_energies = {
		"🔥": 0.8,   # Fire - high energy
		"❄️": -0.3,  # Cold - low energy
		"💧": 0.0,   # Water - neutral
		"🏜️": 0.0,   # Dry - neutral
		"💨": 0.1,   # Flour - slight positive
		"🍞": 0.0,   # Bread - product state
	}
	
	# Drivers: Fire/Cold are inverted sine waves (kitchen cycle)
	# Same mechanic as ☀🌙 and 🔌, at kitchen frequency (0.067 Hz = 15 sec period)
	f.drivers = {
		"🔥": {"type": "sine", "freq": 1.0/15.0, "phase": 0.0, "amp": 1.0},   # Heat
		"❄️": {"type": "sine", "freq": 1.0/15.0, "phase": PI, "amp": 1.0},   # Cold (inverted)
	}
	
	# Hamiltonian: production couplings
	f.hamiltonian = {
		"🔥": {
			"❄️": 0.8,   # Hot-cold opposition
			"🍞": 0.5,   # Fire creates bread
			"💧": 0.2,   # Fire evaporates water
		},
		"❄️": {
			"🔥": 0.8,
			"💧": 0.3,   # Cold preserves moisture
		},
		"💧": {
			"🔥": 0.2,
			"❄️": 0.3,
			"🏜️": 0.0,   # Orthogonal (same axis)
			"🍞": 0.3,   # Water needed for bread
		},
		"🏜️": {
			"🔥": 0.3,   # Heat causes drying
		},
		"💨": {
			"🍞": 0.4,   # Flour becomes bread
		},
		"🍞": {
			"🔥": 0.4,
			"💨": 0.4,
			"💧": 0.3,
		},
	}
	
	# Lindblad: production transfers
	f.lindblad_incoming = {
		"🔥": {
			"🍞": 0.1,   # Fire helps create bread
		},
		"💨": {
			# Note: 🌾→💨 is cross-faction (Verdant → Hearth)
			# This coupling will be added when composing biomes
		},
		"🍞": {
			"💨": 0.08,  # Flour becomes bread
			"🔥": 0.05,  # Heat helps baking
		},
	}
	
	# No decay for kitchen items (consumed, not decayed)
	
	return f


## ========================================
## Utility Functions
## ========================================

## Find all factions that speak a given emoji
static func get_factions_for_emoji(emoji: String) -> Array:
	var result: Array = []
	for faction in get_all():
		if faction.speaks(emoji):
			result.append(faction)
	return result


## ========================================
## Pollinator Guild (center ring)
## The critical link: no pollinators = no grain
## ========================================

static func create_pollinator_guild() -> Faction:
	var f = Faction.new()
	f.name = "Pollinator Guild"
	f.description = "The tiny workers without whom no seed sets. Their absence collapses agriculture."
	f.ring = "center"
	f.signature = ["🐝", "🌿", "🌾", "🌱"]
	f.tags = ["fauna", "pollinator", "critical", "fragile"]
	
	# Self-energies
	f.self_energies = {
		"🐝": 0.02,   # Pollinators are fragile but reproductive
	}
	
	# Hamiltonian: pollinators sense flowers
	f.hamiltonian = {
		"🐝": {
			"🌿": 0.5,   # Attracted to vegetation (flowers)
			"🌾": 0.4,   # Attracted to grain fields
			"🌱": 0.3,   # Visit seedlings
		},
	}
	
	# Lindblad: pollinators feed on vegetation
	f.lindblad_incoming = {
		"🐝": {
			"🌿": 0.06,  # Pollinators multiply when vegetation abundant
		},
	}
	
	# GATED LINDBLAD: The key mechanic!
	# Grain production REQUIRES pollinators
	f.gated_lindblad = {
		"🌾": [
			{
				"source": "🌿",   # Vegetation → Grain
				"rate": 0.05,     # Base pollination rate
				"gate": "🐝",     # REQUIRES pollinators
				"power": 1.0,     # Linear: rate × P(🐝)
			},
			{
				"source": "🌱",   # Seedling → Grain (cultivated path)
				"rate": 0.03,
				"gate": "🐝",
				"power": 0.8,     # Slightly sublinear (seeds need less pollination)
			},
		],
	}
	
	# Decay: short-lived
	f.decay = {
		"🐝": {"rate": 0.06, "target": "🍂"},  # Fast lifecycle
	}
	
	# Alignment: pollinators love sun, hate cold
	f.alignment_couplings = {
		"🐝": {
			"☀": +0.15,   # Active in sunshine
			"💧": -0.10,  # Rain suppresses activity
		},
	}
	
	return f


## ========================================
## Plague Vectors (second ring)
## Density-dependent disease, prevents monoculture
## ========================================

static func create_plague_vectors() -> Faction:
	var f = Faction.new()
	f.name = "Plague Vectors"
	f.description = "The invisible cullers. They thrive on density and crash on scarcity."
	f.ring = "second"
	f.signature = ["🦠", "🐇", "🌾", "🐝", "💀"]
	f.tags = ["disease", "balance", "density-dependent"]
	
	# Self-energies
	f.self_energies = {
		"🦠": -0.05,  # Disease needs hosts, decays without them
	}
	
	# Hamiltonian: disease resonates with dense populations
	f.hamiltonian = {
		"🦠": {
			"🐇": 0.5,   # Disease tracks rabbit density
			"🌾": 0.4,   # Blight tracks wheat density
			"🐝": 0.6,   # Colony collapse - pollinators very vulnerable
			"💀": 0.3,   # Death follows disease
		},
	}
	
	# Lindblad: disease grows from dense populations
	f.lindblad_incoming = {
		"🦠": {
			"🐇": 0.08,   # Rabbits breed disease when dense
			"🌾": 0.06,   # Monoculture wheat breeds blight
			"🐝": 0.10,   # Hive collapse spreads fast
		},
	}
	
	# Lindblad outgoing: disease kills hosts
	f.lindblad_outgoing = {
		"🦠": {
			"💀": 0.05,   # Disease itself burns out to death
		},
	}
	
	# GATED LINDBLAD: Disease kills things, but only when disease is present
	f.gated_lindblad = {
		"💀": [
			{
				"source": "🐇",
				"rate": 0.12,
				"gate": "🦠",      # Rabbits die when disease high
				"power": 1.5,      # Superlinear - epidemics accelerate
			},
			{
				"source": "🌾",
				"rate": 0.10,
				"gate": "🦠",      # Wheat dies to blight
				"power": 1.2,
			},
			{
				"source": "🐝",
				"rate": 0.15,
				"gate": "🦠",      # Pollinators very vulnerable
				"power": 1.5,
			},
		],
	}
	
	# Decay: disease burns out fast
	f.decay = {
		"🦠": {"rate": 0.15, "target": "🍂"},  # Rapid burnout
	}
	
	# Alignment: disease thrives on density, hates dispersion
	f.alignment_couplings = {
		"🦠": {
			"🐇": +0.30,  # More rabbits = more disease spread
			"🌾": +0.25,  # Monoculture enables blight
			"🐝": +0.35,  # Colony density enables collapse
			"🌬": -0.20,  # Wind disperses disease
		},
	}
	
	return f


## ========================================
## Wildfire Dynamics (integrated into Celestial interactions)
## Fire spreads, burns, fertilizes
## ========================================

static func create_wildfire_dynamics() -> Faction:
	var f = Faction.new()
	f.name = "Wildfire"
	f.description = "The great destroyer and renewer. Burns hot, leaves fertility behind."
	f.ring = "second"
	f.signature = ["🔥", "🌿", "🌲", "🍂", "🌬"]
	f.tags = ["destruction", "renewal", "fire", "disturbance"]
	
	# Note: 🔥 self_energy comes from Celestial Archons
	f.self_energies = {}
	
	# Hamiltonian: fire resonates with fuel
	f.hamiltonian = {
		"🔥": {
			"🍂": 0.7,   # Fire loves dry organic matter
			"🌿": 0.5,   # Fire threatens vegetation
			"🌲": 0.4,   # Fire threatens trees
			"🌬": 0.6,   # Wind spreads fire
		},
	}
	
	# Lindblad: fire consumes and transforms
	f.lindblad_incoming = {
		"🔥": {
			"🍂": 0.10,  # Dry material feeds fire (feedback!)
			"🌬": 0.05,  # Wind fans flames
		},
		"🍂": {
			"🌿": 0.15,  # Burning vegetation → organic matter (ash)
			"🌲": 0.08,  # Burning trees → ash (slower)
		},
	}
	
	# Lindblad outgoing: fire destroys
	f.lindblad_outgoing = {
		"🔥": {
			"🍂": 0.08,  # Fire exhausts itself into ash
		},
	}
	
	# GATED LINDBLAD: Fire destruction requires fire presence
	f.gated_lindblad = {
		"🍂": [
			{
				"source": "🌿",   # Vegetation burns to ash
				"rate": 0.20,
				"gate": "🔥",
				"power": 1.2,     # Superlinear - wildfires accelerate
			},
			{
				"source": "🌲",   # Trees burn to ash
				"rate": 0.08,
				"gate": "🔥",
				"power": 1.0,     # Linear - trees resist more
			},
		],
	}
	
	# Decay: fire burns out
	f.decay = {
		"🔥": {"rate": 0.10, "target": "🍂"},  # Fire → ash
	}
	
	# Alignment: fire loves wind and fuel, hates water
	f.alignment_couplings = {
		"🔥": {
			"🌬": +0.30,  # Wind spreads fire
			"🍂": +0.40,  # Dry fuel intensifies fire
			"💧": -0.50,  # Water suppresses fire strongly
		},
	}
	
	return f

## Get all unique emojis across all factions
static func get_all_emojis() -> Array:
	var emojis: Array = []
	for faction in get_all():
		for emoji in faction.get_all_emojis():
			if emoji not in emojis:
				emojis.append(emoji)
	return emojis

## Get shared emojis between two factions
static func get_shared_emojis(f1: Faction, f2: Faction) -> Array:
	var shared: Array = []
	for emoji in f1.signature:
		if emoji in f2.signature:
			shared.append(emoji)
	return shared

## Debug: Print faction summary
static func debug_print_all() -> void:
	print("\n=== Core Factions ===")
	for faction in get_all():
		print("%s (%s): %s" % [faction.name, faction.ring, faction.signature])
	
	print("\n=== Shared Emojis ===")
	var factions = get_all()
	for i in range(factions.size()):
		for j in range(i + 1, factions.size()):
			var shared = get_shared_emojis(factions[i], factions[j])
			if shared.size() > 0:
				print("  %s ∩ %s: %s" % [factions[i].name, factions[j].name, shared])
	print("=====================\n")
