## CivilizationFactions.gd
## The 7 factions accessible from 🍞👥 starting vocabulary
## These form the civilization layer that orbits wheat without touching it directly

class_name CivilizationFactions
extends RefCounted


## ========================================
## Granary Guilds (center ring)
## Bread storage, trade, seed banking
## The keepers of surplus - civilization's buffer
## ========================================

static func create_granary_guilds() -> Faction:
	var f = Faction.new()
	f.name = "Granary Guilds"
	f.description = "Keepers of the surplus. They turn bread into wealth and seeds into futures."
	f.ring = "center"
	f.signature = ["🌱", "🍞", "💰", "🧺"]
	f.tags = ["storage", "trade", "agriculture", "civilization"]
	
	f.self_energies = {
		"🧺": 0.2,   # Basket - storage potential
		"💰": 0.3,   # Wealth accumulates
		"🍞": 0.1,   # Bread (shared with Hearth)
		"🌱": 0.05,  # Seeds (shared with Verdant)
	}
	
	f.hamiltonian = {
		"🧺": {
			"🍞": 0.6,   # Baskets hold bread
			"🌱": 0.5,   # Baskets hold seeds
			"💰": 0.4,   # Storage creates value
		},
		"🍞": {
			"🧺": 0.6,   # Bread seeks storage
			"💰": 0.5,   # Bread can be sold
		},
		"🌱": {
			"🧺": 0.5,   # Seeds stored for planting
			"💰": 0.3,   # Seed trade
		},
		"💰": {
			"🧺": 0.4,
			"🍞": 0.5,
			"🌱": 0.3,
		},
	}
	
	f.lindblad_incoming = {
		"💰": {
			"🍞": 0.04,  # Selling bread
			"🌱": 0.02,  # Selling seeds
		},
		"🧺": {
			"🍞": 0.03,  # Storing bread
		},
	}
	
	f.decay = {
		"🧺": {"rate": 0.01, "target": "🍂"},
	}
	
	f.alignment_couplings = {
		"💰": {
			"🏛": +0.20,
			"🏚": -0.15,
		},
		"🧺": {
			"💧": -0.10,
			"🔥": -0.25,
		},
	}
	
	return f


## ========================================
## Millwright's Union (second ring)
## Industrial transformation: flour → bread
## The mechanical heart of civilization
## ========================================

static func create_millwrights_union() -> Faction:
	var f = Faction.new()
	f.name = "Millwright's Union"
	f.description = "Masters of the grinding stone. They turn flour into bread at industrial scale."
	f.ring = "second"
	f.signature = ["⚙", "🏭", "💨", "🍞", "🔨"]
	f.tags = ["industrial", "transformation", "mechanical", "labor"]
	
	f.self_energies = {
		"⚙": 0.15,   # Gears - mechanical potential
		"🏭": 0.25,   # Factory - production capacity
		"💨": 0.1,    # Flour - input material
		"🔨": 0.10,   # Tools - work capacity
		"🍞": 0.1,    # Bread output
	}
	
	f.hamiltonian = {
		"⚙": {
			"🏭": 0.7,   # Gears power factory
			"🔨": 0.5,   # Tools maintain gears
			"💨": 0.3,   # Gears process flour
		},
		"🏭": {
			"⚙": 0.7,
			"🍞": 0.6,   # Factory produces bread
			"💨": 0.5,   # Factory consumes flour
		},
		"💨": {
			"🏭": 0.5,   # Flour goes to factory
			"🍞": 0.4,   # Flour becomes bread
		},
		"🔨": {
			"⚙": 0.5,
			"🏭": 0.3,
		},
		"🍞": {
			"🏭": 0.6,
			"💨": 0.4,
		},
	}
	
	# GATED: Factory bread production requires labor (👥) AND working gears (⚙)
	f.gated_lindblad = {
		"🍞": [
			{
				"source": "💨",   # Flour → Bread
				"rate": 0.08,
				"gate": "👥",     # REQUIRES labor
				"power": 0.8,
				"inverse": false,
			},
			{
				"source": "🏭",   # Factory capacity → Bread
				"rate": 0.05,
				"gate": "⚙",      # REQUIRES working gears
				"power": 1.0,
				"inverse": false,
			},
		],
	}
	
	f.lindblad_incoming = {
		"⚙": {
			"🔨": 0.03,  # Tools repair gears
		},
		"💨": {
			"🌾": 0.05,  # Wheat → Flour (cross-faction, from milling)
		},
	}
	
	f.decay = {
		"⚙": {"rate": 0.015, "target": "🗑"},
		"🏭": {"rate": 0.005, "target": "🗑"},
	}
	
	f.alignment_couplings = {
		"🏭": {
			"💧": +0.15,  # Water wheels
			"🌬": +0.10,  # Wind mills
			"🔥": -0.20,
		},
		"⚙": {
			"💧": -0.05,  # Water rusts
		},
	}
	
	return f


## ========================================
## The Scavenged Psithurism (outer ring)
## Refugees, the consumed, entropy spreaders
## They drain probability and starve without waste
## ========================================

static func create_scavenged_psithurism() -> Faction:
	var f = Faction.new()
	f.name = "The Scavenged Psithurism"
	f.description = "The rustling of the displaced. They appear from refuse and fade into death. Unmeasurable."
	f.ring = "outer"
	f.signature = ["🧤", "🗑", "💀"]
	f.tags = ["refugee", "entropy", "unmeasurable", "consumed"]
	
	f.self_energies = {
		"🧤": 0.0,    # Refugees - neutral, produce nothing
		"🗑": -0.1,   # Waste - sink
		"💀": -0.15,  # Death - stronger sink
	}
	
	f.hamiltonian = {
		"🧤": {
			"🗑": 0.6,   # Refugees cluster near waste
			"💀": 0.4,   # Refugees face death
		},
		"🗑": {
			"🧤": 0.6,   # Waste attracts refugees
			"💀": 0.3,   # Neglected waste leads to death
		},
		"💀": {
			"🧤": 0.4,
			"🗑": 0.3,
			"⚫": 0.5,   # Death couples to true void (cross-faction)
		},
	}
	
	# Refugees are POWERED by waste
	f.lindblad_incoming = {
		"🧤": {
			"🗑": 0.05,  # Waste produces refugees
		},
		"🗑": {
			"🍞": 0.02,  # Stale bread → waste (cross-faction)
			"🍂": 0.03,  # Organic matter → waste
		},
	}
	
	f.lindblad_outgoing = {
		"🧤": {
			"💀": 0.02,  # Base death rate (starvation amplifies this)
		},
	}
	
	# INVERSE GATED: Refugees die MORE when waste is LOW (starvation)
	f.gated_lindblad = {
		"💀": [
			{
				"source": "🧤",   # Refugees → Death
				"rate": 0.06,
				"gate": "🗑",     # When waste is LOW
				"power": 1.2,     # Superlinear starvation
				"inverse": true,  # ⚠️ INVERSE: rate × (1 - P(🗑))^power
			},
		],
	}
	
	f.decay = {
		"🧤": {"rate": 0.03, "target": "💀"},  # Base starvation
	}
	
	# MEASUREMENT BEHAVIOR: 🧤 inverts to opposite pole when measured
	# This is a quantum mask - measuring reveals the opposite basis state
	# On axis (🧤, 🗑): measuring 🧤 → collapses to 🗑
	# Use this to "sneak mass" into a basis state - refugees appear as waste/death
	f.measurement_behavior = {
		"🧤": {
			"inverts": true,  # Collapse to opposite pole of axis
		},
	}
	
	f.alignment_couplings = {
		"🧤": {
			"🗑": +0.30,   # More waste = better survival
			"🏰": -0.25,   # Empire hunts them
			"📜": -0.15,   # Edicts target them
		},
		"💀": {
			"⚫": +0.20,   # Death feeds true void (cross-faction)
			"🌑": +0.10,   # Death feeds mystic dark
		},
	}
	
	return f


## ========================================
## Yeast Prophets (center ring)
## Fermentation mystics, quantum state preparers
## They read probability in bubbles
## ========================================

static func create_yeast_prophets() -> Faction:
	var f = Faction.new()
	f.name = "Yeast Prophets"
	f.description = "The fermentation mystics. They read futures in rising dough and set initial conditions through sacred cultivation."
	f.ring = "center"
	f.signature = ["🍞", "🥖", "🧪", "⛪", "🫙"]
	f.tags = ["fermentation", "mystic", "quantum", "preparation"]
	
	f.self_energies = {
		"🫙": 0.2,    # Jar - cultivation vessel (the starter)
		"🧪": 0.15,   # Alchemy - transformation
		"⛪": 0.3,    # Temple - sacred space (coherence)
		"🥖": 0.12,   # Baguette - refined bread
		"🍞": 0.1,    # Common bread
	}
	
	f.hamiltonian = {
		"🫙": {
			"🍞": 0.6,
			"🥖": 0.7,
			"🧪": 0.5,
			"⛪": 0.4,
		},
		"🧪": {
			"🫙": 0.5,
			"🍞": 0.4,
			"🥖": 0.5,
			"🍄": 0.4,   # Fungal alchemy (cross-faction)
		},
		"⛪": {
			"🫙": 0.4,
			"🧪": 0.3,
			"🌙": 0.3,   # Night rituals (cross-faction)
		},
		"🍞": {
			"🫙": 0.6,
			"🥖": 0.5,
		},
		"🥖": {
			"🫙": 0.7,
			"🍞": 0.5,
		},
	}
	
	# GATED: Fine bread requires living starter
	f.gated_lindblad = {
		"🥖": [
			{
				"source": "🍞",
				"rate": 0.06,
				"gate": "🫙",     # REQUIRES healthy starter
				"power": 1.2,
				"inverse": false,
			},
		],
		"🍞": [
			{
				"source": "💨",   # Flour → Bread (prophetic method)
				"rate": 0.04,
				"gate": "🫙",
				"power": 1.0,
				"inverse": false,
			},
		],
	}
	
	f.lindblad_incoming = {
		"🫙": {
			"🍞": 0.02,  # Feed the starter
			"💧": 0.03,  # Water the starter
		},
	}
	
	f.decay = {
		"🫙": {"rate": 0.04, "target": "🍂"},  # Neglected starter dies
	}
	
	f.alignment_couplings = {
		"🫙": {
			"🔥": +0.15,
			"❄": -0.25,
			"🌙": +0.10,
		},
		"⛪": {
			"🌙": +0.20,
			"💀": +0.05,
		},
		"🧪": {
			"🍄": +0.15,
		},
	}
	
	return f


## ========================================
## Station Lords (second ring)
## Bureaucratic control, logistics, permits
## Metabolize 📜 edicts into 📘 trade law
## ========================================

static func create_station_lords() -> Faction:
	var f = Faction.new()
	f.name = "Station Lords"
	f.description = "Masters of the checkpoint. They receive edicts and forge them into law."
	f.ring = "second"
	f.signature = ["👥", "🚢", "🛂", "📜", "🏢", "📘"]
	f.tags = ["bureaucracy", "logistics", "control", "law"]
	
	f.self_energies = {
		"🏢": 0.3,    # Building - institutional power
		"📜": 0.1,    # Edict - imperial command (consumed)
		"📘": 0.25,   # Law book - codified authority
		"🛂": 0.2,    # Passport control - gatekeeping
		"🚢": 0.25,   # Ship - logistics capacity
		"👥": 0.02,   # Population
	}
	
	f.hamiltonian = {
		"🏢": {
			"📜": 0.5,   # Buildings receive edicts
			"📘": 0.6,   # Buildings house law
			"🛂": 0.5,
			"👥": 0.4,
		},
		"📜": {
			"🏢": 0.5,   # Edicts go to buildings
			"📘": 0.7,   # Edicts become law
			"🛂": 0.4,
		},
		"📘": {
			"📜": 0.7,   # Law from edicts
			"🛂": 0.6,   # Law enables control
			"🚢": 0.5,   # Law enables shipping
			"👥": 0.5,   # Law binds population
		},
		"🛂": {
			"📘": 0.6,
			"👥": 0.6,
			"🚢": 0.4,
		},
		"🚢": {
			"📘": 0.5,
			"🛂": 0.4,
			"💰": 0.5,   # Trade (cross-faction)
		},
		"👥": {
			"🏢": 0.4,
			"📘": 0.5,
			"🛂": 0.6,
		},
	}
	
	# Metabolize edicts into law
	f.lindblad_incoming = {
		"📘": {
			"📜": 0.06,  # Edicts become law
		},
		"🛂": {
			"📘": 0.04,  # Law enables checkpoints
		},
	}
	
	f.lindblad_outgoing = {
		"📜": {
			"📘": 0.06,  # Edicts consumed into law
			"🗑": 0.01,  # Old edicts become waste
		},
	}
	
	# GATED: Population control requires law
	f.gated_lindblad = {
		"🚢": [
			{
				"source": "💰",   # Wealth → Shipping
				"rate": 0.05,
				"gate": "📘",     # REQUIRES law
				"power": 1.0,
				"inverse": false,
			},
		],
	}
	
	f.decay = {
		"📜": {"rate": 0.02, "target": "🗑"},  # Unfiled edicts decay
		"📘": {"rate": 0.005, "target": "🗑"}, # Laws decay slowly
	}
	
	f.alignment_couplings = {
		"🏢": {
			"🏛": +0.25,
			"🏚": -0.20,
			"🔥": -0.30,
		},
		"📜": {
			"🏰": +0.20,  # Edicts come from throne
		},
		"📘": {
			"💧": -0.10,  # Water damages books
		},
	}
	
	return f


## ========================================
## Void Serfs (outer ring)
## Exploited labor, mystic darkness, debt bondage
## Connected to ⚫ true void but don't speak it
## ========================================

static func create_void_serfs() -> Faction:
	var f = Faction.new()
	f.name = "Void Serfs"
	f.description = "The chained ones. Bound by debt to the mystic dark. They sense the true void but cannot name it."
	f.ring = "outer"
	f.signature = ["👥", "⛓", "🌑", "💸"]
	# NOTE: ⚫ is referenced in dynamics but NOT in signature
	f.tags = ["labor", "exploitation", "void", "debt", "mystic"]
	
	f.self_energies = {
		"⛓": 0.1,     # Chains - bondage
		"🌑": -0.1,    # Mystic dark - strange pull
		"💸": -0.3,    # Debt - NEGATIVE wealth (anti-money)
		"👥": 0.02,
	}
	
	f.hamiltonian = {
		"⛓": {
			"👥": 0.7,   # Chains bind population
			"💸": 0.6,   # Chains from debt
			"🌑": 0.4,   # Chains to dark
		},
		"🌑": {
			"⛓": 0.4,
			"💸": 0.5,   # Debt pulls toward dark
			"👥": 0.3,
			"💀": 0.5,   # Dark touches death (cross-faction)
			"⚫": 0.6,   # Dark couples to true void (cross-faction)
		},
		"💸": {
			"⛓": 0.6,
			"👥": 0.5,
			"🌑": 0.5,
			"💰": -0.8,  # NEGATIVE coupling - debt annihilates wealth
		},
		"👥": {
			"⛓": 0.7,
			"💸": 0.5,
		},
	}
	
	# GATED: Wealth extraction requires bondage
	f.gated_lindblad = {
		"💰": [
			{
				"source": "👥",   # Population → Wealth (extraction)
				"rate": 0.06,
				"gate": "⛓",      # REQUIRES bondage
				"power": 1.0,
				"inverse": false,
			},
		],
	}
	
	f.lindblad_incoming = {
		"⛓": {
			"💸": 0.05,  # Debt creates bondage
		},
		"💸": {
			"👥": 0.03,  # Population accrues debt
		},
		"🌑": {
			"💀": 0.03,  # Death feeds dark
			"⛓": 0.02,
		},
	}
	
	f.lindblad_outgoing = {
		"👥": {
			"💀": 0.02,  # Exploitation kills
		},
		"🌑": {
			"⚫": 0.01,  # Dark slowly drains to true void (cross-faction)
		},
	}
	
	f.decay = {
		"⛓": {"rate": 0.005, "target": "🗑"},
	}
	
	f.alignment_couplings = {
		"🌑": {
			"🌙": +0.25,  # Night strengthens dark
			"☀": -0.30,   # Sun banishes dark
			"💀": +0.15,
			"🔮": +0.20,  # Mystic alignment (future cross-faction)
		},
		"⛓": {
			"🏛": +0.15,  # Order enables bondage
			"🔥": -0.10,  # Revolution breaks chains
		},
		"💸": {
			"💰": -0.25,  # Wealth and debt in tension
		},
	}
	
	return f


## ========================================
## Carrion Throne (outer ring)
## Imperial authority, edict generation, blood law
## The crown that feeds on its subjects
## ========================================

static func create_carrion_throne() -> Faction:
	var f = Faction.new()
	f.name = "Carrion Throne"
	f.description = "The crown of bones. They rule through blood right and inscribe their will in edicts."
	f.ring = "outer"
	f.signature = ["👥", "⚖", "🦅", "⚜", "🩸", "🏰", "📜"]
	f.tags = ["imperial", "authority", "extraction", "blood", "law", "edict"]
	
	f.self_energies = {
		"⚜": 0.4,     # Crown - supreme authority
		"🏰": 0.5,    # Castle - seat of power
		"⚖": 0.25,    # Scales - justice
		"📜": 0.15,   # Edict - imperial command
		"🦅": 0.2,    # Eagle - imperial symbol
		"🩸": 0.1,    # Blood - sacrifice, lineage
		"👥": 0.02,
	}
	
	f.hamiltonian = {
		"🏰": {
			"⚜": 0.8,   # Castle houses crown
			"📜": 0.6,  # Castle generates edicts
			"⚖": 0.5,
			"🦅": 0.4,
		},
		"⚜": {
			"🏰": 0.8,
			"⚖": 0.7,   # Crown makes law
			"📜": 0.6,  # Crown issues edicts
			"🦅": 0.6,
			"🩸": 0.5,   # Blood right
			"👥": 0.4,
		},
		"📜": {
			"🏰": 0.6,
			"⚜": 0.6,
			"⚖": 0.5,   # Edicts are proto-law
			"🏢": 0.4,  # Edicts flow to bureaucracy (cross-faction)
		},
		"⚖": {
			"⚜": 0.7,
			"📜": 0.5,
			"👥": 0.6,   # Law binds population
			"🩸": 0.4,
		},
		"🦅": {
			"⚜": 0.6,
			"👥": 0.5,
			"🩸": 0.4,
			"💀": 0.5,   # Eagle brings death (cross-faction)
		},
		"🩸": {
			"⚜": 0.5,
			"⚖": 0.4,
			"👥": 0.6,
			"💀": 0.4,
		},
		"👥": {
			"⚜": 0.4,
			"⚖": 0.6,
			"🩸": 0.6,
		},
	}
	
	# Castle generates edicts
	f.lindblad_incoming = {
		"📜": {
			"🏰": 0.04,  # Castle generates edicts
			"⚜": 0.02,   # Crown inspires edicts
		},
		"⚜": {
			"💰": 0.02,  # Wealth strengthens crown
			"🩸": 0.02,
		},
		"🦅": {
			"💀": 0.03,  # Death feeds the eagle
		},
	}
	
	f.lindblad_outgoing = {
		"📜": {
			"🏢": 0.05,  # Edicts flow to bureaucracy (cross-faction)
		},
		"🩸": {
			"💀": 0.04,  # Blood leads to death
		},
		"👥": {
			"💸": 0.02,  # Imperial debt on population
		},
	}
	
	# GATED: Imperial extraction requires legal framework or crown
	f.gated_lindblad = {
		"💰": [
			{
				"source": "👥",   # Tax the population
				"rate": 0.08,
				"gate": "⚖",      # REQUIRES legal framework
				"power": 1.0,
				"inverse": false,
			},
		],
		"🩸": [
			{
				"source": "👥",   # Blood sacrifice
				"rate": 0.03,
				"gate": "⚜",      # Crown demands blood
				"power": 1.2,
				"inverse": false,
			},
		],
	}
	
	f.decay = {
		"⚜": {"rate": 0.002, "target": "🏚"},  # Crown → ruin (very slow)
		"🏰": {"rate": 0.001, "target": "🏚"}, # Castle → ruin (slower)
		"📜": {"rate": 0.03, "target": "🗑"},  # Edicts decay if not processed
	}
	
	f.alignment_couplings = {
		"⚜": {
			"🏛": +0.30,
			"🏚": -0.25,
			"🔥": -0.20,
		},
		"🏰": {
			"🏛": +0.25,
			"🔥": -0.35,
		},
		"📜": {
			"🏢": +0.15,  # Bureaucracy processes edicts
		},
		"🦅": {
			"☀": +0.10,
			"🐇": +0.20,  # Eagle tracks prey (cross-faction)
		},
		"🩸": {
			"💀": +0.15,
			"🌙": +0.10,
		},
	}
	
	return f


## ========================================
## Utility Functions
## ========================================

static func get_all() -> Array[Faction]:
	return [
		create_granary_guilds(),
		create_millwrights_union(),
		create_scavenged_psithurism(),
		create_yeast_prophets(),
		create_station_lords(),
		create_void_serfs(),
		create_carrion_throne(),
	]

static func get_starter_accessible() -> Array[Faction]:
	return get_all()

static func get_factions_for_emoji(emoji: String) -> Array[Faction]:
	var result: Array[Faction] = []
	for faction in get_all():
		if faction.speaks(emoji):
			result.append(faction)
	return result
