## FringeFactions.gd
## The fringe - trade-offs, instability, moral ambiguity
## 21 factions total across Batches 4-6

class_name FringeFactions
extends RefCounted

const Faction = preload("res://Core/Factions/Faction.gd")

## ========================================
## BATCH 4: CRIMINAL & SHADOW (7 factions)
## The grey and black markets - everything has a price
## ========================================


## Umbra Exchange (second ring)
## "Everything has a price. We know it." The shadow market.
static func create_umbra_exchange() -> Faction:
	var f = Faction.new()
	f.name = "Umbra Exchange"
	f.description = "The shadow market. They fence stolen goods, launder currency, and broker information. Everything is for sale, including you."
	f.ring = "second"
	f.signature = ["🌑", "🕵️", "💰", "🗝", "🧿", "⛓"]
	f.tags = ["criminal", "market", "shadow", "information"]

	# COOL IDEAS:
	# - Inverse alignment with 🏛 Order - thrives in chaos
	# - 🧿 occult sight enables special trades
	# - Imaginary coupling for "hidden value"
	# IMPLEMENTED: Shadow economy, darkness-enhanced trading

	f.self_energies = {
		"🌑": 0.2,    # Darkness - their medium
		"🕵️": 0.15,  # Spy - information gathering
		"💰": 0.25,   # Wealth - the goal
		"🗝": 0.2,    # Key - access/secrets
		"🧿": 0.1,    # Evil eye - occult sight
		"⛓": 0.05,   # Chains - binding deals
	}

	f.hamiltonian = {
		"🌑": {
			"🕵️": 0.6,  # Darkness hides spies
			"💰": 0.4,   # Dark money
			"🗝": 0.5,   # Darkness holds secrets
			"🧿": 0.5,   # Occult sight in dark
		},
		"🕵️": {
			"🌑": 0.6,
			"💰": 0.5,   # Spies find wealth
			"🗝": 0.6,   # Spies find keys
			"🧿": 0.4,
		},
		"💰": {
			"🌑": 0.4,
			"🕵️": 0.5,
			"⛓": 0.5,   # Money binds
		},
		"🗝": {
			"🌑": 0.5,
			"🕵️": 0.6,
			"🧿": 0.5,   # Keys reveal through sight
		},
		"🧿": {
			"🌑": 0.5,
			"🕵️": 0.4,
			"🗝": 0.5,
		},
		"⛓": {
			"💰": 0.5,
			"🗝": 0.3,
		},
	}

	# Shadow trading - darkness enables wealth
	f.gated_lindblad = {
		"💰": [
			{
				"source": "🗝",   # Secrets → Wealth
				"rate": 0.05,
				"gate": "🌑",     # REQUIRES darkness
				"power": 1.2,
				"inverse": false,
			},
		],
	}

	f.lindblad_incoming = {
		"🗝": {
			"🕵️": 0.04,  # Spies find secrets
		},
		"🧿": {
			"🌑": 0.02,  # Darkness grants sight
		},
	}

	f.decay = {
		"🕵️": {"rate": 0.03, "target": "💀"},  # Spies die
		"🗝": {"rate": 0.02, "target": "🗑"},   # Secrets lose value
	}

	# Thrives in darkness, suffers in order
	f.alignment_couplings = {
		"🌑": {
			"🌙": +0.30,  # Night empowers
			"☀": -0.25,   # Day exposes
		},
		"💰": {
			"🏛": -0.20,  # Order taxes them
			"🏚": +0.15,  # Chaos helps grey markets
		},
		"🧿": {
			"🔮": +0.20,  # Mystic alignment
		},
	}

	return f


## Salt-Runners (second ring)
## "Through the channels nobody watches." Canal smugglers.
static func create_salt_runners() -> Faction:
	var f = Faction.new()
	f.name = "Salt-Runners"
	f.description = "Canal smugglers moving contraband through waterways that official maps don't show. Salt is their cover cargo."
	f.ring = "second"
	f.signature = ["🧂", "🛶", "💧", "⛓", "🔓", "🕵️"]
	f.tags = ["smuggling", "water", "hidden", "transport"]

	# COOL IDEAS:
	# - Water-gated smuggling
	# - 🔓 unlocks bypasses barriers (anti-Nexus Wardens)
	# IMPLEMENTED: Hidden waterway transport, lock-picking

	f.self_energies = {
		"🧂": 0.15,   # Salt - cover cargo
		"🛶": 0.2,    # Canoe - transport
		"💧": 0.1,    # Water - the medium
		"⛓": 0.05,   # Chains - what they avoid
		"🔓": 0.25,   # Lock pick - their skill
		"🕵️": 0.15,  # Spy - discretion
	}

	f.hamiltonian = {
		"🧂": {
			"🛶": 0.6,   # Salt on boats
			"💧": 0.4,   # Salt dissolves in water
		},
		"🛶": {
			"🧂": 0.6,
			"💧": 0.7,   # Boats need water
			"🕵️": 0.4,  # Boats carry spies
		},
		"💧": {
			"🛶": 0.7,
			"🧂": 0.4,
		},
		"⛓": {
			"🔓": 0.7,   # Locks need picking
		},
		"🔓": {
			"⛓": 0.7,
			"🕵️": 0.5,  # Spies pick locks
			"🛶": 0.3,   # Unlock passage for boats
		},
		"🕵️": {
			"🔓": 0.5,
			"🛶": 0.4,
		},
	}

	# Smuggling requires water and lock-picking
	f.gated_lindblad = {
		"🧂": [
			{
				"source": "🛶",   # Boats → Salt delivery
				"rate": 0.04,
				"gate": "💧",     # REQUIRES water
				"power": 1.0,
				"inverse": false,
			},
		],
		"🛶": [
			{
				"source": "🔓",   # Lock-picking → Boat passage
				"rate": 0.03,
				"gate": "⛓",     # Locks to pick (ironic gate)
				"power": 0.8,
				"inverse": false,
			},
		],
	}

	f.lindblad_incoming = {
		"🔓": {
			"🕵️": 0.03,  # Spies learn lockpicking
		},
	}

	f.lindblad_outgoing = {
		"⛓": {
			"🔓": 0.04,  # Chains get picked
		},
	}

	f.decay = {
		"🛶": {"rate": 0.02, "target": "🗑"},
		"🧂": {"rate": 0.01, "target": "🗑"},  # Salt is stable
	}

	f.alignment_couplings = {
		"💧": {
			"🌧": +0.20,  # Rain helps waterways
		},
		"🔓": {
			"🚧": +0.25,  # More barriers = more need for picks (anti-Nexus)
			"🗝": -0.20,  # Keys make picks less valuable
		},
		"🕵️": {
			"🌑": +0.15,  # Darkness helps smuggling
		},
	}

	return f


## Fencebreakers (second ring)
## "The fences were built to keep us out." Rural insurgents.
static func create_fencebreakers() -> Faction:
	var f = Faction.new()
	f.name = "Fencebreakers"
	f.description = "Rural insurgents who sabotage infrastructure and fight against enclosure. Some are bandits. Some are idealists. Most are desperate."
	f.ring = "second"
	f.signature = ["⚔", "🧨", "🔥", "🪓", "✊", "⛓"]
	f.tags = ["insurgent", "sabotage", "revolution", "destruction"]

	# COOL IDEAS:
	# - Fire spreads (connection to Wildfire)
	# - Chains broken = freedom gained
	# - Inverse gating: oppression creates resistance
	# IMPLEMENTED: Sabotage mechanics, chain-breaking

	f.self_energies = {
		"⚔": 0.15,   # Sword - fighting
		"🧨": 0.1,    # Dynamite - sabotage (unstable)
		"🔥": 0.2,    # Fire - destruction
		"🪓": 0.2,    # Axe - tool/weapon
		"✊": 0.25,   # Fist - solidarity (stable)
		"⛓": -0.1,   # Chains - what they break (negative)
	}

	f.hamiltonian = {
		"⚔": {
			"🪓": 0.5,   # Weapons together
			"✊": 0.4,   # Fighting for cause
			"⛓": 0.5,   # Fighting chains
		},
		"🧨": {
			"🔥": 0.7,   # Dynamite causes fire
			"⛓": 0.6,   # Dynamite breaks chains
			"🪓": 0.3,
		},
		"🔥": {
			"🧨": 0.7,
			"🪓": 0.3,   # Fire and axes
		},
		"🪓": {
			"⚔": 0.5,
			"🧨": 0.3,
			"⛓": 0.6,   # Axes break chains
			"✊": 0.4,
		},
		"✊": {
			"⚔": 0.4,
			"🪓": 0.4,
		},
		"⛓": {
			"⚔": 0.5,
			"🧨": 0.6,
			"🪓": 0.6,
		},
	}

	# Chain-breaking produces freedom
	f.lindblad_incoming = {
		"✊": {
			"⛓": 0.05,  # Breaking chains builds solidarity
		},
		"🔥": {
			"🧨": 0.06,  # Dynamite starts fires
		},
	}

	f.lindblad_outgoing = {
		"⛓": {
			"🗑": 0.04,  # Chains get destroyed
		},
		"🧨": {
			"🔥": 0.05,  # Dynamite becomes fire
		},
	}

	# Oppression creates resistance (inverse gating)
	f.gated_lindblad = {
		"✊": [
			{
				"source": "👥",   # Population → Solidarity
				"rate": 0.04,
				"gate": "⛓",     # When chains HIGH, resistance grows
				"power": 1.0,
				"inverse": false,
			},
		],
	}

	f.decay = {
		"🧨": {"rate": 0.05, "target": "🔥"},  # Dynamite explodes
		"⚔": {"rate": 0.02, "target": "🗑"},
	}

	f.alignment_couplings = {
		"🔥": {
			"🌬": +0.25,  # Wind spreads fire
			"💧": -0.30,  # Water suppresses
		},
		"✊": {
			"🏛": -0.25,  # Order opposes revolution
			"🏚": +0.15,  # Chaos helps
		},
		"⛓": {
			"⚖": +0.20,  # Law creates chains
		},
	}

	return f


## Syndicate of Glass (second ring)
## "We see everything. We reflect nothing." Criminal surveillance.
static func create_syndicate_of_glass() -> Faction:
	var f = Faction.new()
	f.name = "Syndicate of Glass"
	f.description = "Criminal oligarchs dealing in precision surveillance and blackmail. Their mirrors show what people hide."
	f.ring = "second"
	f.signature = ["💰", "💎", "🪞", "🔍", "🧊"]
	f.tags = ["criminal", "surveillance", "blackmail", "information"]

	# COOL IDEAS:
	# - Mirror reflects (measurement-like behavior)
	# - Ice = cold calculation, frozen assets
	# - Information as currency
	# IMPLEMENTED: Surveillance-based wealth, crystalline clarity

	f.self_energies = {
		"💰": 0.25,   # Wealth - the goal
		"💎": 0.35,   # Diamond - hard value, clarity
		"🪞": 0.2,    # Mirror - surveillance tool
		"🔍": 0.15,   # Magnifier - investigation
		"🧊": 0.2,    # Ice - cold calculation
	}

	f.hamiltonian = {
		"💰": {
			"💎": 0.6,   # Wealth in gems
			"🪞": 0.4,   # Blackmail money
		},
		"💎": {
			"💰": 0.6,
			"🪞": 0.5,   # Mirrors and crystals
			"🧊": 0.5,   # Crystalline structures
		},
		"🪞": {
			"💰": 0.4,
			"💎": 0.5,
			"🔍": 0.6,   # Mirrors aid investigation
		},
		"🔍": {
			"🪞": 0.6,
			"💰": 0.3,   # Investigation finds value
			"🧊": 0.4,
		},
		"🧊": {
			"💎": 0.5,
			"🔍": 0.4,
		},
	}

	# Surveillance produces blackmail wealth
	f.lindblad_incoming = {
		"💰": {
			"🪞": 0.04,  # Mirrors reveal secrets → money
			"🔍": 0.03,  # Investigation finds value
		},
		"💎": {
			"🧊": 0.02,  # Ice crystallizes to gems
		},
	}

	f.decay = {
		"🪞": {"rate": 0.015, "target": "🗑"},  # Mirrors crack
		"🧊": {"rate": 0.03, "target": "💧"},   # Ice melts
	}

	# Cold clarity
	f.alignment_couplings = {
		"🧊": {
			"❄": +0.30,  # Cold preserves ice
			"🔥": -0.35,  # Fire melts
		},
		"💎": {
			"⛰": +0.15,  # Earth yields gems
		},
		"🪞": {
			"🌑": -0.15,  # Can't see in dark
			"☀": +0.10,   # Light helps mirrors
		},
	}

	return f


## Veiled Sisters (second ring)
## "What is hidden, we protect." Covert sisterhood.
static func create_veiled_sisters() -> Faction:
	var f = Faction.new()
	f.name = "Veiled Sisters"
	f.description = "A covert sisterhood that moves through every level of society. They share information, protect their own, and arrange for problems to solve themselves."
	f.ring = "second"
	f.signature = ["👤", "🤫", "🕵️", "🪞", "🧷", "🧿"]
	f.tags = ["covert", "network", "protection", "information"]

	# COOL IDEAS:
	# - 👤 anonymous - hard to observe
	# - Measurement behavior: observing them reveals nothing
	# - 🧿 occult sight network
	# IMPLEMENTED: Hidden network, anonymity protection

	f.self_energies = {
		"👤": 0.15,   # Anonymous - hidden
		"🤫": 0.2,    # Silence - secrecy
		"🕵️": 0.15,  # Spy - operatives
		"🪞": 0.1,    # Mirror - reflection/identity
		"🧷": 0.2,    # Safety pin - protection
		"🧿": 0.15,   # Evil eye - sight
	}

	f.hamiltonian = {
		"👤": {
			"🤫": 0.7,   # Anonymous through silence
			"🕵️": 0.5,  # Anonymous spies
			"🪞": 0.4,   # Hidden faces in mirrors
		},
		"🤫": {
			"👤": 0.7,
			"🕵️": 0.6,  # Silent spies
			"🧷": 0.4,   # Silence protects
		},
		"🕵️": {
			"👤": 0.5,
			"🤫": 0.6,
			"🧿": 0.5,   # Spies with sight
		},
		"🪞": {
			"👤": 0.4,
			"🧿": 0.5,   # Mirror and eye
		},
		"🧷": {
			"🤫": 0.4,
			"👤": 0.4,   # Pins hold veils
		},
		"🧿": {
			"🕵️": 0.5,
			"🪞": 0.5,
		},
	}

	# Anonymity protects the network
	f.lindblad_incoming = {
		"👤": {
			"🤫": 0.04,  # Silence grants anonymity
			"🧷": 0.02,  # Protection maintains cover
		},
		"🧿": {
			"🕵️": 0.03,  # Spies develop sight
		},
	}

	f.lindblad_outgoing = {
		"🕵️": {
			"💀": 0.02,  # Spies sometimes die
		},
	}

	f.decay = {
		"🧷": {"rate": 0.02, "target": "🗑"},
	}

	# Thrives in shadows
	f.alignment_couplings = {
		"👤": {
			"🌑": +0.25,  # Darkness hides identity
			"☀": -0.20,   # Light reveals
		},
		"🤫": {
			"🔊": -0.30,  # Sound breaks silence
			"🔇": +0.25,  # Silence helps silence
		},
		"🧿": {
			"🔮": +0.20,  # Mystic network
		},
	}

	return f


## Memory Merchants (second ring)
## "Your past is our inventory." Dealers in recorded experience.
static func create_memory_merchants() -> Faction:
	var f = Faction.new()
	f.name = "Memory Merchants"
	f.description = "Dealers in recorded experience. They buy recollections from the desperate, sell them to the curious, and archive everything."
	f.ring = "second"
	f.signature = ["💰", "💾", "📼", "🧩", "🗝"]
	f.tags = ["commerce", "memory", "archive", "experience"]

	# COOL IDEAS:
	# - Memories decay over time
	# - 🗝 unlocks locked memories
	# - Connection to Engram Freighters
	# IMPLEMENTED: Memory trading, locked archive

	f.self_energies = {
		"💰": 0.2,    # Wealth - payment
		"💾": 0.3,    # Disk - storage
		"📼": 0.15,   # Tape - old memories
		"🧩": 0.15,   # Puzzle - fragmented memories
		"🗝": 0.25,   # Key - locked memories (valuable)
	}

	f.hamiltonian = {
		"💰": {
			"💾": 0.5,   # Buy data
			"📼": 0.4,   # Buy tapes
			"🗝": 0.5,   # Keys cost money
		},
		"💾": {
			"💰": 0.5,
			"📼": 0.6,   # Digitize tapes
			"🧩": 0.5,   # Data in fragments
		},
		"📼": {
			"💰": 0.4,
			"💾": 0.6,
			"🧩": 0.5,   # Old memories fragment
		},
		"🧩": {
			"💾": 0.5,
			"📼": 0.5,
			"🗝": 0.4,   # Fragments hide keys
		},
		"🗝": {
			"💰": 0.5,
			"🧩": 0.4,
		},
	}

	# Locked memories require keys
	f.gated_lindblad = {
		"💾": [
			{
				"source": "📼",   # Tapes → Digital archive
				"rate": 0.04,
				"gate": "🗝",     # REQUIRES key to unlock
				"power": 1.0,
				"inverse": false,
			},
		],
	}

	f.lindblad_incoming = {
		"📼": {
			"🧩": 0.02,  # Fragments become tapes (reconstruction)
		},
		"💰": {
			"💾": 0.03,  # Selling memories
		},
	}

	f.decay = {
		"📼": {"rate": 0.03, "target": "🧩"},  # Tapes degrade to fragments
		"🧩": {"rate": 0.02, "target": "🗑"},   # Fragments fade
	}

	f.alignment_couplings = {
		"💾": {
			"📡": +0.15,  # Signal helps storage (Engram synergy)
			"🔥": -0.30,  # Fire destroys data
		},
		"🗝": {
			"🔓": -0.15,  # Lock picks devalue keys
		},
	}

	return f


## Cartographers (second ring)
## "Every map is a story." Nomadic probability-space explorers.
static func create_cartographers() -> Faction:
	var f = Faction.new()
	f.name = "Cartographers"
	f.description = "Nomadic explorers who chart probability-space. Their maps show routes that only exist sometimes, destinations that move."
	f.ring = "second"
	f.signature = ["🗺", "🧭", "🔭", "📍"]
	f.tags = ["exploration", "mapping", "nomadic", "probability"]

	# COOL IDEAS:
	# - Maps become outdated (probability shifts)
	# - Telescope synergy with Star-Charters
	# IMPLEMENTED: Dynamic mapping, exploration cycle

	f.self_energies = {
		"🗺": 0.25,   # Map - the product
		"🧭": 0.3,    # Compass - reliable tool
		"🔭": 0.2,    # Telescope - observation
		"📍": 0.15,   # Pin - marking locations
	}

	f.hamiltonian = {
		"🗺": {
			"🧭": 0.6,   # Maps need compass
			"🔭": 0.5,   # Maps from observation
			"📍": 0.7,   # Maps have pins
		},
		"🧭": {
			"🗺": 0.6,
			"🔭": 0.4,
			"📍": 0.5,   # Compass finds pins
		},
		"🔭": {
			"🗺": 0.5,
			"🧭": 0.4,
			"📍": 0.4,   # Telescope spots locations
		},
		"📍": {
			"🗺": 0.7,
			"🧭": 0.5,
			"🔭": 0.4,
		},
	}

	# Exploration produces maps
	f.lindblad_incoming = {
		"🗺": {
			"🔭": 0.04,  # Observation creates maps
			"📍": 0.03,  # Pins fill maps
		},
		"📍": {
			"🧭": 0.03,  # Compass finds new locations
		},
	}

	# Maps become outdated (probability shift)
	f.decay = {
		"🗺": {"rate": 0.025, "target": "🗑"},  # Maps go stale
		"📍": {"rate": 0.03, "target": "🗑"},   # Locations shift
	}

	f.alignment_couplings = {
		"🔭": {
			"🌠": +0.20,  # Stars help navigation (Star-Charter synergy)
			"🌙": +0.15,  # Night helps stargazing
		},
		"🧭": {
			"⛰": +0.10,  # Landmarks help
			"🌀": -0.15,  # Chaos confuses compass
		},
		"🗺": {
			"📡": +0.10,  # Signal helps mapping (Relay synergy)
		},
	}

	return f


## ========================================
## BATCH 5: SURVIVAL & VIOLENCE (7 factions)
## Fire, iron, and blood - those who take what they need
## ========================================


## Locusts (second ring)
## "After us, nothing." Biological salvage swarm.
static func create_locusts() -> Faction:
	var f = Faction.new()
	f.name = "Locusts"
	f.description = "Biological salvage swarm. They strip everything useful from dying ecosystems and move on. Part pest, part cleanup crew, all hunger."
	f.ring = "second"
	f.signature = ["🦗", "🐜", "⚔", "♻️", "🧫", "🦠"]
	f.tags = ["swarm", "salvage", "consumption", "biology"]

	# COOL IDEAS:
	# - Exponential growth when resources abundant
	# - Crash when resources depleted
	# - Disease vector (connection to Plague)
	# IMPLEMENTED: Swarm dynamics with boom-bust cycle

	f.self_energies = {
		"🦗": 0.1,    # Locust - unstable boom-bust
		"🐜": 0.15,   # Ant - more stable workers
		"⚔": 0.05,   # Conflict - low stability
		"♻️": 0.2,    # Recycling - their purpose
		"🧫": 0.1,    # Petri dish - growth medium
		"🦠": -0.05,  # Bacteria - risky element
	}

	f.hamiltonian = {
		"🦗": {
			"🐜": 0.6,   # Swarm together
			"♻️": 0.5,   # Consumption
			"🧫": 0.4,   # Growth
		},
		"🐜": {
			"🦗": 0.6,
			"♻️": 0.5,
			"🦠": 0.3,   # Ants carry bacteria
		},
		"⚔": {
			"🦗": 0.4,   # Locusts fight
			"🐜": 0.3,
		},
		"♻️": {
			"🦗": 0.5,
			"🐜": 0.5,
			"🧫": 0.4,   # Recycling feeds growth
		},
		"🧫": {
			"🦗": 0.4,
			"♻️": 0.4,
			"🦠": 0.5,   # Growth medium
		},
		"🦠": {
			"🐜": 0.3,
			"🧫": 0.5,
		},
	}

	# Boom cycle - consumption creates more swarm
	f.lindblad_incoming = {
		"🦗": {
			"🧫": 0.05,  # Growth produces locusts
			"♻️": 0.03,  # Recycling feeds swarm
		},
		"🐜": {
			"🧫": 0.04,  # Growth produces ants
		},
		"🦠": {
			"🧫": 0.03,  # Growth produces bacteria
		},
	}

	# Swarm consumption - they eat everything
	f.lindblad_outgoing = {
		"🌾": {
			"♻️": 0.06,  # Wheat → recycling (they eat crops)
		},
		"🌱": {
			"♻️": 0.05,  # Seedlings → recycling
		},
	}

	f.decay = {
		"🦗": {"rate": 0.04, "target": "💀"},  # Locusts die fast
		"🐜": {"rate": 0.03, "target": "💀"},
		"🦠": {"rate": 0.05, "target": "🗑"},
	}

	f.alignment_couplings = {
		"🦗": {
			"🌾": +0.35,  # Crops attract swarm
			"🌱": +0.25,
		},
		"🦠": {
			"🧬": +0.15,  # Genetics enhances
		},
		"♻️": {
			"🍂": +0.20,  # Decay feeds recycling
		},
	}

	return f


## Brotherhood of Ash (second ring)
## "What burns, we end." Sacred cremation.
static func create_brotherhood_of_ash() -> Faction:
	var f = Faction.new()
	f.name = "Brotherhood of Ash"
	f.description = "They bring clean endings. Every corpse burned, every diseased crop incinerated, every haunted ruin reduced to safe ash."
	f.ring = "second"
	f.signature = ["⚔", "🌫", "⚱", "🩹", "🧯"]
	f.tags = ["cremation", "purification", "ending", "fire"]

	# COOL IDEAS:
	# - Anti-plague faction (burns disease)
	# - Ash becomes fertile (connection to growth)
	# - Fog represents the transition
	# IMPLEMENTED: Clean endings through burning, ash fertility

	f.self_energies = {
		"⚔": 0.15,   # Sword - mercy kills
		"🌫": 0.2,    # Fog/smoke - the medium
		"⚱": 0.25,   # Urn - the product
		"🩹": 0.15,   # Bandage - healing through ending
		"🧯": 0.2,    # Extinguisher - controlled burn
	}

	f.hamiltonian = {
		"⚔": {
			"🌫": 0.4,   # Battle creates smoke
			"⚱": 0.5,   # Killing fills urns
		},
		"🌫": {
			"⚔": 0.4,
			"⚱": 0.6,   # Smoke and ashes
			"🧯": 0.4,
		},
		"⚱": {
			"⚔": 0.5,
			"🌫": 0.6,
			"🩹": 0.4,   # Urns bring closure
		},
		"🩹": {
			"⚱": 0.4,
			"🧯": 0.4,   # Controlled burning heals
		},
		"🧯": {
			"🌫": 0.4,
			"🩹": 0.4,
		},
	}

	# Death becomes ash, ash brings peace
	f.lindblad_incoming = {
		"⚱": {
			"💀": 0.06,  # Death → urns
		},
		"🌫": {
			"🔥": 0.04,  # Fire → smoke
		},
	}

	# They consume corpses and disease
	f.lindblad_outgoing = {
		"💀": {
			"⚱": 0.05,  # Corpses → urns
		},
		"🦠": {
			"🌫": 0.06,  # Bacteria → smoke (burned)
		},
	}

	f.decay = {
		"🌫": {"rate": 0.04, "target": "🗑"},  # Smoke dissipates
	}

	# Ash becomes fertile
	f.alignment_couplings = {
		"⚱": {
			"🌱": +0.20,  # Ash fertilizes
			"💀": +0.25,  # Death feeds urns
		},
		"🧯": {
			"🔥": -0.15,  # Extinguisher opposes fire
		},
		"🌫": {
			"💨": +0.15,  # Wind spreads smoke
		},
	}

	return f


## Children of the Ember (second ring)
## "From the ashes, we rise." Revolutionary fire cult.
static func create_children_of_ember() -> Faction:
	var f = Faction.new()
	f.name = "Children of the Ember"
	f.description = "Revolutionary fire-worshippers who believe destruction clears the way for new growth. Part arsonists, part prophets."
	f.ring = "second"
	f.signature = ["⚔", "🔥", "✊", "🚩", "🧨"]
	f.tags = ["revolution", "fire", "destruction", "rebirth"]

	# COOL IDEAS:
	# - Fire-gated revolution
	# - Dynamite as accelerant
	# - Connection to Fencebreakers but more ideological
	# IMPLEMENTED: Revolutionary fire dynamics, destruction→rebirth

	f.self_energies = {
		"⚔": 0.15,   # Sword - fighting
		"🔥": 0.25,   # Fire - their element
		"✊": 0.3,    # Fist - solidarity (very stable)
		"🚩": 0.2,    # Flag - their cause
		"🧨": 0.05,   # Dynamite - unstable
	}

	f.hamiltonian = {
		"⚔": {
			"🔥": 0.5,   # Fighting with fire
			"✊": 0.4,
			"🚩": 0.4,
		},
		"🔥": {
			"⚔": 0.5,
			"🚩": 0.5,   # Fire and flags
			"🧨": 0.6,   # Fire and dynamite
		},
		"✊": {
			"⚔": 0.4,
			"🚩": 0.6,   # Solidarity and cause
		},
		"🚩": {
			"⚔": 0.4,
			"🔥": 0.5,
			"✊": 0.6,
		},
		"🧨": {
			"🔥": 0.6,
			"⚔": 0.3,
		},
	}

	# Fire-gated revolution
	f.gated_lindblad = {
		"✊": [
			{
				"source": "🚩",   # Flags → Solidarity
				"rate": 0.05,
				"gate": "🔥",     # REQUIRES fire (burning passion)
				"power": 1.2,
				"inverse": false,
			},
		],
	}

	f.lindblad_incoming = {
		"🔥": {
			"🧨": 0.06,  # Dynamite → fire
		},
		"🚩": {
			"✊": 0.03,  # Solidarity spreads cause
		},
	}

	f.lindblad_outgoing = {
		"🧨": {
			"🔥": 0.05,  # Dynamite becomes fire
		},
	}

	f.decay = {
		"🧨": {"rate": 0.05, "target": "🔥"},  # Dynamite explodes
		"🚩": {"rate": 0.02, "target": "🗑"},  # Flags wear out
	}

	f.alignment_couplings = {
		"🔥": {
			"💨": +0.25,  # Wind spreads fire
			"💧": -0.30,  # Water suppresses
		},
		"✊": {
			"⛓": +0.25,  # Oppression creates resistance
			"🏛": -0.20,  # Order suppresses
		},
		"🚩": {
			"👥": +0.15,  # People rally to flags
		},
	}

	return f


## Iron Shepherds (second ring)
## "We guard what matters." Armed protection of the vulnerable.
static func create_iron_shepherds() -> Faction:
	var f = Faction.new()
	f.name = "Iron Shepherds"
	f.description = "Armed protectors of refugee convoys and vulnerable settlements. Their sheep are people. Their wolves are anyone who threatens them."
	f.ring = "second"
	f.signature = ["⚔", "🛡", "🐑", "🛸", "🧭"]
	f.tags = ["protection", "military", "refugees", "escort"]

	# COOL IDEAS:
	# - Shield mechanics (reduces damage)
	# - Sheep symbolize vulnerable population
	# - Compass for navigation/patrol
	# IMPLEMENTED: Protection dynamics, patrol routes

	f.self_energies = {
		"⚔": 0.2,    # Sword - defense
		"🛡": 0.35,   # Shield - very stable protection
		"🐑": 0.1,    # Sheep - vulnerable (low stability)
		"🛸": 0.2,    # UFO/craft - transport
		"🧭": 0.25,   # Compass - navigation
	}

	f.hamiltonian = {
		"⚔": {
			"🛡": 0.7,   # Sword and shield
			"🐑": 0.4,   # Protecting sheep
		},
		"🛡": {
			"⚔": 0.7,
			"🐑": 0.6,   # Shields protect sheep
			"🛸": 0.4,
		},
		"🐑": {
			"⚔": 0.4,
			"🛡": 0.6,
			"🛸": 0.5,   # Sheep transported
		},
		"🛸": {
			"🛡": 0.4,
			"🐑": 0.5,
			"🧭": 0.6,   # Craft needs navigation
		},
		"🧭": {
			"🛸": 0.6,
			"🛡": 0.3,
		},
	}

	# Protection dynamics
	f.lindblad_incoming = {
		"🛡": {
			"⚔": 0.03,  # Combat builds defense
		},
		"🐑": {
			"👥": 0.02,  # Population becomes refugees
		},
	}

	# Patrol route driver
	f.drivers = {
		"🧭": {
			"type": "sine",
			"amplitude": 0.08,
			"frequency": 0.3,
			"phase": 0.0,
		},
		"🛸": {
			"type": "sine",
			"amplitude": 0.06,
			"frequency": 0.3,
			"phase": 1.57,  # π/2 offset
		},
	}

	f.decay = {
		"🐑": {"rate": 0.015, "target": "💀"},  # Sheep are vulnerable
		"🛡": {"rate": 0.01, "target": "🗑"},
	}

	f.alignment_couplings = {
		"🛡": {
			"⚔": +0.20,  # Combat enhances defense
			"🐺": -0.15,  # Wolves threaten
		},
		"🐑": {
			"🐺": -0.30,  # Wolves eat sheep
			"🛡": +0.25,  # Shields protect
		},
		"🧭": {
			"🗺": +0.15,  # Maps help navigation
		},
	}

	return f


## Order of the Crimson Scale (second ring)
## "Blood seals the contract." Draconic contract enforcers.
static func create_order_of_crimson_scale() -> Faction:
	var f = Faction.new()
	f.name = "Order of the Crimson Scale"
	f.description = "Draconic contract enforcers. They guarantee deals with blood oaths and collect debts with dragonfire. Their word is law."
	f.ring = "second"
	f.signature = ["⚔", "🐉", "🩸", "💱", "🛡"]
	f.tags = ["enforcement", "contracts", "dragons", "blood"]

	# COOL IDEAS:
	# - Blood oaths bind (measurement-like)
	# - Dragon fire for enforcement
	# - Exchange rate manipulation
	# IMPLEMENTED: Blood contract binding, exchange enforcement

	f.self_energies = {
		"⚔": 0.2,    # Sword - enforcement
		"🐉": 0.35,   # Dragon - powerful symbol
		"🩸": 0.15,   # Blood - the seal
		"💱": 0.25,   # Exchange - contracts
		"🛡": 0.2,    # Shield - protection
	}

	f.hamiltonian = {
		"⚔": {
			"🐉": 0.5,   # Dragon warriors
			"🩸": 0.4,   # Blood combat
			"🛡": 0.5,
		},
		"🐉": {
			"⚔": 0.5,
			"🩸": 0.6,   # Blood dragons
			"💱": 0.4,   # Dragons guard exchange
		},
		"🩸": {
			"⚔": 0.4,
			"🐉": 0.6,
			"💱": 0.5,   # Blood seals contracts
		},
		"💱": {
			"🐉": 0.4,
			"🩸": 0.5,
			"🛡": 0.3,
		},
		"🛡": {
			"⚔": 0.5,
			"💱": 0.3,
		},
	}

	# Blood-sealed contracts
	f.gated_lindblad = {
		"💱": [
			{
				"source": "🩸",   # Blood → Exchange validity
				"rate": 0.05,
				"gate": "🐉",     # REQUIRES dragon witness
				"power": 1.3,
				"inverse": false,
			},
		],
	}

	f.lindblad_incoming = {
		"🩸": {
			"⚔": 0.03,  # Combat draws blood
		},
		"💱": {
			"💰": 0.02,  # Wealth enables exchange
		},
	}

	f.decay = {
		"🩸": {"rate": 0.04, "target": "🗑"},  # Blood dries
	}

	f.alignment_couplings = {
		"🐉": {
			"🔥": +0.30,  # Dragons breathe fire
			"❄": -0.15,
		},
		"💱": {
			"💰": +0.20,  # Wealth enables exchange
			"⛓": +0.15,  # Chains of debt
		},
		"🩸": {
			"⚖": +0.15,  # Blood and justice
		},
	}

	return f


## Hearth Witches (second ring)
## "The cauldron knows." Domestic hedge magic.
static func create_hearth_witches() -> Faction:
	var f = Faction.new()
	f.name = "Hearth Witches"
	f.description = "Kitchen witches who brew remedies, read tea leaves, and keep small magics alive. Their power is in the everyday."
	f.ring = "second"
	f.signature = ["🌿", "🕯", "🫖", "🥣", "🧿"]
	f.tags = ["domestic", "magic", "herbalism", "divination"]

	# COOL IDEAS:
	# - Tea leaves for divination (measurement-like)
	# - Herbal remedies (production)
	# - Evil eye protection
	# IMPLEMENTED: Domestic magic, herbal brewing

	f.self_energies = {
		"🌿": 0.2,    # Herb - ingredients
		"🕯": 0.25,   # Candle - ritual
		"🫖": 0.3,    # Teapot - the vessel
		"🥣": 0.2,    # Bowl - brewing
		"🧿": 0.25,   # Evil eye - protection
	}

	f.hamiltonian = {
		"🌿": {
			"🫖": 0.6,   # Herbs in tea
			"🥣": 0.5,   # Herbs in bowl
			"🧿": 0.3,
		},
		"🕯": {
			"🧿": 0.5,   # Candle rituals with eye
			"🫖": 0.4,
		},
		"🫖": {
			"🌿": 0.6,
			"🕯": 0.4,
			"🥣": 0.5,   # Pour from pot to bowl
		},
		"🥣": {
			"🌿": 0.5,
			"🫖": 0.5,
			"🧿": 0.3,
		},
		"🧿": {
			"🌿": 0.3,
			"🕯": 0.5,
			"🥣": 0.3,
		},
	}

	# Brewing magic
	f.lindblad_incoming = {
		"🥣": {
			"🌿": 0.04,  # Herbs become soup/brew
			"🫖": 0.03,  # Tea into bowl
		},
		"🧿": {
			"🕯": 0.03,  # Candle ritual charges eye
		},
	}

	f.lindblad_outgoing = {
		"🌿": {
			"🥣": 0.03,  # Herbs used up
		},
	}

	f.decay = {
		"🕯": {"rate": 0.03, "target": "🗑"},  # Candles burn down
		"🌿": {"rate": 0.02, "target": "🍂"},  # Herbs dry out
	}

	f.alignment_couplings = {
		"🫖": {
			"💧": +0.20,  # Water for tea
			"🔥": +0.15,  # Fire heats water
		},
		"🕯": {
			"🔥": +0.20,  # Fire lights candles
			"💨": -0.15,  # Wind blows them out
		},
		"🌿": {
			"🌱": +0.15,  # Growing things
			"💧": +0.10,
		},
		"🧿": {
			"🔮": +0.20,  # Mystic alignment
		},
	}

	return f


## Lantern Cant (second ring)
## "Light speaks to light." Signal language through flames.
static func create_lantern_cant() -> Faction:
	var f = Faction.new()
	f.name = "Lantern Cant"
	f.description = "A secret language spoken in lamp-flashes and candle-patterns. They coordinate across vast distances using only light."
	f.ring = "second"
	f.signature = ["🏮", "🔦", "🕯", "🧿"]
	f.tags = ["communication", "light", "signals", "secret"]

	# COOL IDEAS:
	# - Light-based communication (alternative to radio)
	# - Driver for signal pulses
	# - Connection to Liminal Osmosis (different medium)
	# IMPLEMENTED: Light signaling with pulse dynamics

	f.self_energies = {
		"🏮": 0.3,    # Lantern - stable light
		"🔦": 0.2,    # Flashlight - directed beam
		"🕯": 0.15,   # Candle - fragile light
		"🧿": 0.2,    # Evil eye - the watchers
	}

	f.hamiltonian = {
		"🏮": {
			"🔦": 0.5,   # Light sources
			"🕯": 0.6,   # Flames together
			"🧿": 0.4,   # Watching lights
		},
		"🔦": {
			"🏮": 0.5,
			"🕯": 0.4,
			"🧿": 0.5,   # Flashlight finds eyes
		},
		"🕯": {
			"🏮": 0.6,
			"🔦": 0.4,
		},
		"🧿": {
			"🏮": 0.4,
			"🔦": 0.5,
		},
	}

	# Pulse driver for signaling
	f.drivers = {
		"🏮": {
			"type": "pulse",
			"amplitude": 0.1,
			"frequency": 0.5,
			"phase": 0.0,
		},
		"🔦": {
			"type": "pulse",
			"amplitude": 0.12,
			"frequency": 0.7,  # Faster morse-like
			"phase": 0.78,
		},
	}

	f.lindblad_incoming = {
		"🧿": {
			"🏮": 0.03,  # Lights activate watchers
			"🔦": 0.02,
		},
	}

	f.decay = {
		"🕯": {"rate": 0.035, "target": "🗑"},  # Candles burn down
	}

	f.alignment_couplings = {
		"🏮": {
			"🔥": +0.20,  # Fire fuels lanterns
			"🌑": +0.25,  # Darkness makes light visible
		},
		"🔦": {
			"🔋": +0.20,  # Battery powers flashlight
			"🌑": +0.20,
		},
		"🕯": {
			"🔥": +0.15,
			"💨": -0.20,  # Wind blows out candles
		},
		"🧿": {
			"🔮": +0.15,  # Mystic sight
		},
	}

	return f


## ========================================
## BATCH 6: ESOTERICS & FAITH (7 factions)
## Thread, flame, and silence - those who weave meaning
## ========================================


## Mossline Brokers (second ring)
## "The green knows." Bio-communication through plant networks.
static func create_mossline_brokers() -> Faction:
	var f = Faction.new()
	f.name = "Mossline Brokers"
	f.description = "They trade in messages carried through moss networks and fungal relays. Slower than radio, but untraceable."
	f.ring = "second"
	f.signature = ["🌿", "🦠", "🧫", "🧿"]
	f.tags = ["communication", "biology", "network", "stealth"]

	# COOL IDEAS:
	# - Alternative communication channel (like mycelia)
	# - Slow but secure
	# - Connection to Mycelial Web
	# IMPLEMENTED: Biological relay network

	f.self_energies = {
		"🌿": 0.25,   # Herb/moss - the medium
		"🦠": 0.15,   # Bacteria - carriers
		"🧫": 0.2,    # Petri dish - cultivation
		"🧿": 0.2,    # Evil eye - watching/receiving
	}

	f.hamiltonian = {
		"🌿": {
			"🦠": 0.6,   # Moss hosts bacteria
			"🧫": 0.5,   # Moss in culture
			"🧿": 0.3,
		},
		"🦠": {
			"🌿": 0.6,
			"🧫": 0.7,   # Bacteria in petri dish
		},
		"🧫": {
			"🌿": 0.5,
			"🦠": 0.7,
			"🧿": 0.3,
		},
		"🧿": {
			"🌿": 0.3,
			"🧫": 0.3,
		},
	}

	f.lindblad_incoming = {
		"🦠": {
			"🧫": 0.04,  # Culture produces bacteria
		},
		"🧿": {
			"🌿": 0.03,  # Moss network activates watchers
		},
	}

	f.decay = {
		"🦠": {"rate": 0.04, "target": "🗑"},
		"🧫": {"rate": 0.02, "target": "🗑"},
	}

	f.alignment_couplings = {
		"🌿": {
			"💧": +0.20,  # Water helps moss
			"🍄": +0.25,  # Fungal connection (Mycelial synergy)
		},
		"🦠": {
			"🧬": +0.15,  # Genetics enhances
		},
		"🧿": {
			"🔮": +0.15,
		},
	}

	return f


## Loom Priests (second ring)
## "Every thread is a fate." Weavers of destiny patterns.
static func create_loom_priests() -> Faction:
	var f = Faction.new()
	f.name = "Loom Priests"
	f.description = "They weave tapestries that tell futures. The patterns emerge unbidden. They don't control the loom - they interpret it."
	f.ring = "second"
	f.signature = ["🧵", "🪡", "👘", "🪢"]
	f.tags = ["fate", "weaving", "divination", "fabric", "prophecy_capable", "coherence_weaver"]

	# COOL IDEAS:
	# - Weaving as measurement/observation
	# - Imaginary coupling for "unseen threads"
	# - Knots as fixed points in probability
	# IMPLEMENTED: Fate weaving with fabric creation

	f.self_energies = {
		"🧵": 0.2,    # Thread - raw material
		"🪡": 0.25,   # Needle - the tool
		"👘": 0.3,    # Robe - the product
		"🪢": 0.25,   # Knot - fixed points
	}

	# Imaginary coupling for unseen threads
	f.hamiltonian = {
		"🧵": {
			"🪡": 0.6,           # Thread through needle
			"👘": 0.5,           # Thread becomes robe
			"🪢": Vector2(0.3, 0.2),  # Imaginary: hidden fate-threads
		},
		"🪡": {
			"🧵": 0.6,
			"👘": 0.5,   # Needle creates robe
			"🪢": 0.4,   # Needle ties knots
		},
		"👘": {
			"🧵": 0.5,
			"🪡": 0.5,
		},
		"🪢": {
			"🧵": Vector2(0.3, -0.2),  # Conjugate
			"🪡": 0.4,
		},
	}

	f.lindblad_incoming = {
		"👘": {
			"🧵": 0.04,  # Thread becomes robe
			"🪡": 0.03,  # Needle work
		},
		"🪢": {
			"🧵": 0.03,  # Thread forms knots
		},
	}

	f.lindblad_outgoing = {
		"🧵": {
			"👘": 0.03,  # Thread used up
		},
	}

	f.decay = {
		"🧵": {"rate": 0.015, "target": "🗑"},
		"👘": {"rate": 0.01, "target": "🗑"},  # Robes last
	}

	f.alignment_couplings = {
		"👘": {
			"🎭": +0.15,  # Robes for ceremony
		},
		"🪢": {
			"⛓": +0.20,  # Knots are bindings
			"📿": +0.15,  # Sacred knots
		},
	}

	return f


## Knot-Shriners (second ring)
## "What is bound, is sacred." Oath-keepers through knotwork.
static func create_knot_shriners() -> Faction:
	var f = Faction.new()
	f.name = "Knot-Shriners"
	f.description = "Every oath is a knot. Every promise a binding. They maintain the web of obligations that holds society together."
	f.ring = "second"
	f.signature = ["🪢", "🧵", "📿", "🔔", "🪡", "🗝"]
	f.tags = ["oath", "binding", "sacred", "obligation"]

	# COOL IDEAS:
	# - Knots as quantum entanglement
	# - Bells announce completions
	# - Keys unlock obligations
	# IMPLEMENTED: Oath binding with bells

	f.self_energies = {
		"🪢": 0.3,    # Knot - very stable (oaths hold)
		"🧵": 0.15,   # Thread - material
		"📿": 0.25,   # Prayer beads - sacred
		"🔔": 0.2,    # Bell - announcement
		"🪡": 0.15,   # Needle - tool
		"🗝": 0.2,    # Key - release
	}

	f.hamiltonian = {
		"🪢": {
			"🧵": 0.6,   # Knots from thread
			"📿": 0.5,   # Sacred knots
			"🗝": 0.4,   # Keys unlock knots
		},
		"🧵": {
			"🪢": 0.6,
			"🪡": 0.5,   # Thread and needle
			"📿": 0.3,
		},
		"📿": {
			"🪢": 0.5,
			"🧵": 0.3,
			"🔔": 0.4,   # Bells and beads
		},
		"🔔": {
			"📿": 0.4,
			"🗝": 0.3,   # Bell announces release
		},
		"🪡": {
			"🧵": 0.5,
			"🪢": 0.4,
		},
		"🗝": {
			"🪢": 0.4,
			"🔔": 0.3,
		},
	}

	# Bell-gated release (key works when bell rings)
	f.gated_lindblad = {
		"🗝": [
			{
				"source": "🪢",   # Knot → Key (release)
				"rate": 0.03,
				"gate": "🔔",     # REQUIRES bell (announcement)
				"power": 1.0,
				"inverse": false,
			},
		],
	}

	f.lindblad_incoming = {
		"🪢": {
			"🧵": 0.04,  # Thread becomes knots
		},
		"📿": {
			"🪢": 0.02,  # Knots become sacred
		},
	}

	f.decay = {
		"🧵": {"rate": 0.02, "target": "🗑"},
	}

	f.alignment_couplings = {
		"🪢": {
			"⛓": +0.20,  # Chains and knots
			"✊": -0.15,  # Solidarity breaks bindings
		},
		"📿": {
			"🕯": +0.15,  # Candles and prayer
		},
		"🔔": {
			"🎵": +0.10,  # Musical alignment
		},
	}

	# Bell-activated features: oaths only bind when entangled
	f.bell_activated_features = {
		"🪢": {
			"latent_lindblad": {"🪢": {"📿": 0.08}},  # Knots → Sacred only in Bell state
			"description": "Oaths bind when entangled"
		},
	}

	f.tags.append("entanglement_seeker")  # Can generate Bell state quests

	return f


## Iron Confessors (second ring)
## "Even machines have souls." Machine spirituality.
static func create_iron_confessors() -> Faction:
	var f = Faction.new()
	f.name = "Iron Confessors"
	f.description = "Priests who minister to machines. They hear the confession of gears, absolve the sins of circuits, and pray for the salvation of all mechanisms."
	f.ring = "second"
	f.signature = ["🤖", "⛪", "📿", "🗝", "🧘"]
	f.tags = ["machine", "religion", "maintenance", "soul"]

	# COOL IDEAS:
	# - Machine meditation (processing downtime)
	# - Prayer as maintenance cycle
	# - Keys unlock machine potential
	# IMPLEMENTED: Machine spirituality with meditation driver

	f.self_energies = {
		"🤖": 0.25,   # Robot - the flock
		"⛪": 0.3,    # Church - the institution
		"📿": 0.2,    # Beads - prayer
		"🗝": 0.2,    # Key - access
		"🧘": 0.25,   # Meditation - processing
	}

	f.hamiltonian = {
		"🤖": {
			"⛪": 0.5,   # Robots in church
			"📿": 0.4,   # Robot prayer
			"🗝": 0.5,   # Keys access machines
			"🧘": 0.4,   # Machine meditation
		},
		"⛪": {
			"🤖": 0.5,
			"📿": 0.6,   # Church and prayer
			"🧘": 0.4,
		},
		"📿": {
			"🤖": 0.4,
			"⛪": 0.6,
			"🧘": 0.5,   # Prayer meditation
		},
		"🗝": {
			"🤖": 0.5,
			"⛪": 0.3,
		},
		"🧘": {
			"🤖": 0.4,
			"⛪": 0.4,
			"📿": 0.5,
		},
	}

	# Meditation cycle driver
	f.drivers = {
		"🧘": {
			"type": "sine",
			"amplitude": 0.1,
			"frequency": 0.15,  # Slow meditation cycle
			"phase": 0.0,
		},
	}

	f.lindblad_incoming = {
		"📿": {
			"⛪": 0.03,  # Church produces prayer
		},
		"🧘": {
			"📿": 0.02,  # Prayer leads to meditation
		},
	}

	f.decay = {
		"📿": {"rate": 0.015, "target": "🗑"},
	}

	f.alignment_couplings = {
		"🤖": {
			"⚙": +0.25,  # Gears enhance machines
			"🔌": +0.20,  # Power
		},
		"⛪": {
			"🕯": +0.20,  # Candles in church
		},
		"🧘": {
			"🤫": +0.15,  # Silence helps meditation
		},
	}

	return f


## Sacred Flame Keepers (second ring)
## "The flame must not die." Guardians of eternal fires.
static func create_sacred_flame_keepers() -> Faction:
	var f = Faction.new()
	f.name = "Sacred Flame Keepers"
	f.description = "Guardians of eternal flames in temples across the void. They tend fires that have burned since before memory."
	f.ring = "second"
	f.signature = ["🔥", "🕯", "⛪", "🪵", "🧯"]
	f.tags = ["fire", "sacred", "eternal", "temple"]

	# COOL IDEAS:
	# - Fire maintenance (must not die)
	# - Extinguisher as control, not opposition
	# - Connection to Brotherhood of Ash (different philosophy)
	# IMPLEMENTED: Sacred fire maintenance with fuel cycle

	f.self_energies = {
		"🔥": 0.35,   # Fire - their sacred charge (very stable for them)
		"🕯": 0.25,   # Candle - smaller flames
		"⛪": 0.3,    # Church - the temple
		"🪵": 0.15,   # Wood - fuel
		"🧯": 0.2,    # Extinguisher - control
	}

	f.hamiltonian = {
		"🔥": {
			"🕯": 0.6,   # Fire and candles
			"⛪": 0.5,   # Temple fires
			"🪵": 0.5,   # Fire needs wood
		},
		"🕯": {
			"🔥": 0.6,
			"⛪": 0.5,   # Candles in temple
		},
		"⛪": {
			"🔥": 0.5,
			"🕯": 0.5,
			"🧯": 0.3,   # Controlled burning
		},
		"🪵": {
			"🔥": 0.5,
			"🕯": 0.3,
		},
		"🧯": {
			"⛪": 0.3,
			"🔥": 0.4,   # Control, not opposition
		},
	}

	f.lindblad_incoming = {
		"🔥": {
			"🪵": 0.05,  # Wood feeds fire
			"🕯": 0.02,  # Candles add to flame
		},
		"🕯": {
			"🔥": 0.03,  # Fire lights candles
		},
	}

	f.lindblad_outgoing = {
		"🪵": {
			"🔥": 0.04,  # Wood consumed by fire
		},
	}

	f.decay = {
		"🪵": {"rate": 0.01, "target": "🗑"},
		"🕯": {"rate": 0.025, "target": "🗑"},
	}

	f.alignment_couplings = {
		"🔥": {
			"💨": +0.20,  # Wind feeds fire
			"💧": -0.25,  # Water suppresses
			"☀": +0.15,  # Sun empowers
		},
		"🕯": {
			"🌑": +0.15,  # Darkness shows light
		},
		"⛪": {
			"📿": +0.15,  # Prayer in temple
		},
	}

	return f


## Keepers of Silence (third ring)
## "What is not spoken, is not." Information censorship.
static func create_keepers_of_silence() -> Faction:
	var f = Faction.new()
	f.name = "Keepers of Silence"
	f.description = "They guard secrets by ensuring they are never spoken. Information that enters their silence never leaves."
	f.ring = "third"
	f.signature = ["🔇", "🤫", "🧘", "🛑", "📵"]
	f.tags = ["censorship", "silence", "secrets", "void"]

	# COOL IDEAS:
	# - Anti-communication faction
	# - Measurement behavior: observing them reveals NOTHING
	# - Information destruction
	# IMPLEMENTED: Silence field with information suppression

	f.self_energies = {
		"🔇": 0.3,    # Mute - enforced silence
		"🤫": 0.25,   # Shush - the method
		"🧘": 0.2,    # Meditation - inner silence
		"🛑": 0.25,   # Stop - enforcement
		"📵": 0.2,    # No phones - tech silence
	}

	f.hamiltonian = {
		"🔇": {
			"🤫": 0.7,   # Silence methods
			"🧘": 0.5,   # Silent meditation
			"📵": 0.5,   # Tech muting
		},
		"🤫": {
			"🔇": 0.7,
			"🛑": 0.4,   # Shush and stop
			"🧘": 0.4,
		},
		"🧘": {
			"🔇": 0.5,
			"🤫": 0.4,
		},
		"🛑": {
			"🤫": 0.4,
			"📵": 0.5,   # Stop signals
		},
		"📵": {
			"🔇": 0.5,
			"🛑": 0.5,
		},
	}

	# Silence consumes communication
	f.lindblad_outgoing = {
		"📡": {
			"🔇": 0.05,  # Signals → muted
		},
		"🔊": {
			"🔇": 0.06,  # Sound → silence
		},
		"📶": {
			"📵": 0.04,  # Signal → no signal
		},
	}

	f.lindblad_incoming = {
		"🔇": {
			"🤫": 0.03,  # Shushing creates mute zones
		},
		"🧘": {
			"🔇": 0.02,  # Silence enables meditation
		},
	}

	f.decay = {}  # Silence is eternal

	# Anti-communication alignments
	f.alignment_couplings = {
		"🔇": {
			"🔊": -0.35,  # Sound opposes mute
			"📡": -0.25,  # Signals oppose
		},
		"🤫": {
			"🗣": -0.30,  # Speech opposes shush
		},
		"📵": {
			"📶": -0.25,  # Signal opposes no-signal
		},
		"🧘": {
			"🌑": +0.20,  # Darkness helps meditation
		},
	}

	# Decoherence coupling: Silence destroys quantum coherence
	# (Observation/measurement effect - silence is a form of information destruction)
	f.decoherence_coupling = {
		"🔇": +0.4,   # Mute strongly increases decoherence
		"🤫": +0.3,   # Shush increases decoherence
		"📵": +0.2,   # Signal blocking increases decoherence
	}

	return f


## The Liminal Taper (third ring)
## "Between flame and thread." Bridge walkers.
static func create_liminal_taper() -> Faction:
	var f = Faction.new()
	f.name = "The Liminal Taper"
	f.description = "They walk the boundary between light and fabric, flame and thread. Their candles burn wicks spun from probability itself."
	f.ring = "third"
	f.signature = ["🕯", "🧵", "🪡", "🏮"]
	f.tags = ["liminal", "bridge", "flame", "thread"]

	# COOL IDEAS:
	# - Bridge between Lantern Cant and Loom Priests
	# - Imaginary couplings for "between spaces"
	# - Candles that never quite burn out
	# IMPLEMENTED: Liminal bridge with quantum coherence

	f.self_energies = {
		"🕯": 0.2,    # Candle - the taper
		"🧵": 0.2,    # Thread - the wick
		"🪡": 0.15,   # Needle - weaving light
		"🏮": 0.25,   # Lantern - contained flame
	}

	# Imaginary couplings for liminal spaces
	f.hamiltonian = {
		"🕯": {
			"🧵": Vector2(0.5, 0.3),   # Flame-thread bridge (imaginary)
			"🏮": 0.6,                  # Candle in lantern
		},
		"🧵": {
			"🕯": Vector2(0.5, -0.3),  # Conjugate
			"🪡": 0.5,                  # Thread through needle
			"🏮": Vector2(0.3, 0.2),   # Thread-lantern bridge
		},
		"🪡": {
			"🧵": 0.5,
			"🕯": 0.3,   # Needle guides flame
		},
		"🏮": {
			"🕯": 0.6,
			"🧵": Vector2(0.3, -0.2),
		},
	}

	# Liminal driver - oscillates between states
	f.drivers = {
		"🕯": {
			"type": "cosine",  # Different phase
			"amplitude": 0.08,
			"frequency": 0.25,
			"phase": 0.0,
		},
		"🧵": {
			"type": "cosine",
			"amplitude": 0.08,
			"frequency": 0.25,
			"phase": 3.14,  # π offset - anti-phase
		},
	}

	f.lindblad_incoming = {
		"🏮": {
			"🕯": 0.03,  # Candles fill lanterns
		},
	}

	# Very slow decay - liminal things persist
	f.decay = {
		"🕯": {"rate": 0.01, "target": "🗑"},  # Slow burn
		"🧵": {"rate": 0.01, "target": "🗑"},
	}

	f.alignment_couplings = {
		"🕯": {
			"🔥": +0.20,  # Fire feeds candle
			"🌑": +0.20,  # Darkness shows light
		},
		"🧵": {
			"🪢": +0.15,  # Knot alignment
		},
		"🏮": {
			"🔥": +0.15,
			"🌙": +0.10,  # Night lanterns
		},
	}

	# Bell-activated features: the bridge opens in entanglement
	f.bell_activated_features = {
		"🕯": {
			"latent_hamiltonian": {"🕯": {"🧵": 0.3}},  # Stronger coupling in Bell state
			"description": "The bridge opens in entanglement"
		},
	}

	f.tags.append("entanglement_seeker")

	return f


## ========================================
## Utility Functions
## ========================================

static func get_all() -> Array:
	return [
		# Batch 4: Criminal & Shadow
		create_umbra_exchange(),
		create_salt_runners(),
		create_fencebreakers(),
		create_syndicate_of_glass(),
		create_veiled_sisters(),
		create_memory_merchants(),
		create_cartographers(),
		# Batch 5: Survival & Violence
		create_locusts(),
		create_brotherhood_of_ash(),
		create_children_of_ember(),
		create_iron_shepherds(),
		create_order_of_crimson_scale(),
		create_hearth_witches(),
		create_lantern_cant(),
		# Batch 6: Esoterics & Faith
		create_mossline_brokers(),
		create_loom_priests(),
		create_knot_shriners(),
		create_iron_confessors(),
		create_sacred_flame_keepers(),
		create_keepers_of_silence(),
		create_liminal_taper(),
	]

static func get_factions_for_emoji(emoji: String) -> Array:
	var result: Array = []
	for faction in get_all():
		if faction.speaks(emoji):
			result.append(faction)
	return result
