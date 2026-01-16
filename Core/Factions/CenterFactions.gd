## CenterFactions.gd
## The mundane, stable factions - boring center, complexity from collision
## 19 factions total: center ring (5) + first ring (5) + second ring center-adjacent (9)

class_name CenterFactions
extends RefCounted

const Faction = preload("res://Core/Factions/Faction.gd")

## ========================================
## BATCH 1: TRUE CENTER (5 factions)
## The most mundane - infrastructure, repair, preservation
## ========================================


## Tinker Team (center ring)
## "If it's broke, we're coming." Traveling repair crews.
static func create_tinker_team() -> Faction:
	var f = Faction.new()
	f.name = "Tinker Team"
	f.description = "Traveling repair crews in battered vans. They fix what others throw away."
	f.ring = "center"
	f.signature = ["🧰", "🪛", "🔌", "♻️", "🚐"]
	f.tags = ["repair", "salvage", "infrastructure", "mobile"]

	# COOL IDEAS:
	# - Inverse gating: broken things pile up when no tinkers around
	# - Driver for "repair cycles" - tinkers travel in waves
	# IMPLEMENTED: Recycling loop with tool stability

	f.self_energies = {
		"🧰": 0.25,   # Toolbox - stable capability
		"🪛": 0.15,   # Screwdriver - active tool
		"🔌": 0.1,    # Plug - connection point
		"♻️": 0.05,   # Recycling - neutral flow
		"🚐": 0.2,    # Van - mobile platform
	}

	f.hamiltonian = {
		"🧰": {
			"🪛": 0.5,   # Toolbox contains tools
			"🔌": 0.4,   # Tools fix electrical
			"♻️": 0.3,   # Tools enable recycling
		},
		"🪛": {
			"🧰": 0.5,
			"🔌": 0.6,   # Screwdriver fixes plugs
			"♻️": 0.4,
		},
		"🔌": {
			"🧰": 0.4,
			"🪛": 0.6,
			"🚐": 0.3,   # Van needs power
		},
		"♻️": {
			"🧰": 0.3,
			"🪛": 0.4,
			"🗑": 0.5,   # Recycling pulls from waste (cross-faction)
		},
		"🚐": {
			"🧰": 0.4,   # Van carries tools
			"🔌": 0.3,
		},
	}

	# Recycling converts waste to usable parts
	f.lindblad_incoming = {
		"🔌": {
			"♻️": 0.04,  # Recycling produces parts
		},
		"🧰": {
			"🪛": 0.02,  # Tools maintain toolbox
		},
	}

	f.lindblad_outgoing = {
		"♻️": {
			"🗑": 0.03,  # Some recycling still produces waste
		},
	}

	f.decay = {
		"🪛": {"rate": 0.02, "target": "♻️"},  # Tools wear out, get recycled
		"🔌": {"rate": 0.03, "target": "♻️"},  # Parts wear out
	}

	f.alignment_couplings = {
		"🧰": {
			"🏛": +0.15,  # Order helps organization
			"🏚": -0.10,  # Chaos disorganizes tools
		},
		"♻️": {
			"🗑": +0.25,  # More waste = more recycling opportunity
		},
	}

	return f


## Seedvault Curators (center ring)
## "Every seed is a promise kept." Genetic archive keepers.
static func create_seedvault_curators() -> Faction:
	var f = Faction.new()
	f.name = "Seedvault Curators"
	f.description = "Keepers of the genetic archive. Every biological pattern that sustains civilization."
	f.ring = "center"
	f.signature = ["🌱", "🔬", "🧪", "🧫", "🧬"]
	f.tags = ["preservation", "science", "genetics", "archive"]

	# COOL IDEAS:
	# - Gated production: seeds only viable when properly stored (🧫 gate)
	# - Negative coupling to 🦠 - disease threatens archive
	# IMPLEMENTED: Preservation loop with research output

	f.self_energies = {
		"🌱": 0.1,    # Seeds - potential
		"🔬": 0.3,    # Microscope - observation/research
		"🧪": 0.2,    # Alchemy - transformation
		"🧫": 0.25,   # Petri dish - cultivation
		"🧬": 0.35,   # DNA - the core asset, high stability
	}

	f.hamiltonian = {
		"🌱": {
			"🧫": 0.6,   # Seeds go in dishes
			"🧬": 0.5,   # Seeds contain DNA
			"🔬": 0.3,   # Seeds studied
		},
		"🔬": {
			"🧬": 0.7,   # Microscope reveals DNA
			"🧫": 0.5,   # Microscope examines cultures
			"🧪": 0.4,   # Research needs alchemy
		},
		"🧪": {
			"🔬": 0.4,
			"🧫": 0.5,   # Alchemy on cultures
			"🧬": 0.4,
		},
		"🧫": {
			"🌱": 0.6,
			"🧬": 0.6,   # Cultures preserve DNA
			"🔬": 0.5,
		},
		"🧬": {
			"🌱": 0.5,
			"🧫": 0.6,
			"🔬": 0.7,
		},
	}

	# Vault preserves genetic material
	f.lindblad_incoming = {
		"🧬": {
			"🌱": 0.03,  # Seeds contribute to archive
			"🧫": 0.04,  # Cultures preserve DNA
		},
		"🧫": {
			"🧪": 0.03,  # Alchemy produces cultures
		},
	}

	# Very slow decay - archives are stable
	f.decay = {
		"🧫": {"rate": 0.01, "target": "🗑"},  # Cultures eventually expire
		"🧪": {"rate": 0.015, "target": "🗑"}, # Reagents expire
	}

	f.alignment_couplings = {
		"🧬": {
			"❄": +0.30,   # Cold storage preserves DNA
			"🔥": -0.35,  # Heat destroys archive
		},
		"🧫": {
			"🦠": -0.25,  # Disease threatens cultures
		},
		"🌱": {
			"💧": +0.10,  # Seeds need some moisture
		},
	}

	return f


## Relay Lattice (center ring)
## "Your signal, anywhere." The telecom company.
static func create_relay_lattice() -> Faction:
	var f = Faction.new()
	f.name = "Relay Lattice"
	f.description = "The telecom company. Mind-bogglingly complex infrastructure, frustratingly mundane service."
	f.ring = "center"
	f.signature = ["📡", "🧩", "🗺", "📶", "🧭"]
	f.tags = ["communication", "infrastructure", "network", "signal"]

	# COOL IDEAS:
	# - Signal driver oscillating at communication frequency
	# - Gated: maps only useful when signal present
	# IMPLEMENTED: Signal relay with driver, map generation

	f.self_energies = {
		"📡": 0.3,    # Antenna - primary asset
		"🧩": 0.15,   # Puzzle piece - network node
		"🗺": 0.2,    # Map - coverage/routing
		"📶": 0.1,    # Signal strength - varies
		"🧭": 0.2,    # Compass - navigation aid
	}

	# Signal oscillates like a carrier wave
	f.drivers = {
		"📶": {
			"type": "sine",
			"freq": 0.2,      # 5 second period - communication frequency
			"phase": 0.0,
			"amp": 0.4,
		},
	}

	f.hamiltonian = {
		"📡": {
			"📶": 0.7,   # Antenna broadcasts signal
			"🧩": 0.5,   # Antenna is network node
			"🗺": 0.4,   # Coverage mapping
		},
		"📶": {
			"📡": 0.7,
			"🧩": 0.6,   # Signal flows through nodes
			"🧭": 0.4,   # Signal aids navigation
		},
		"🧩": {
			"📡": 0.5,
			"📶": 0.6,
			"🗺": 0.5,   # Nodes build network map
		},
		"🗺": {
			"📡": 0.4,
			"🧩": 0.5,
			"🧭": 0.6,   # Maps and compass linked
		},
		"🧭": {
			"🗺": 0.6,
			"📶": 0.4,
		},
	}

	# Network builds coverage
	f.lindblad_incoming = {
		"🗺": {
			"🧩": 0.03,  # Network nodes build map
			"📡": 0.02,  # Antennas contribute to coverage
		},
	}

	f.lindblad_outgoing = {
		"📶": {
			"🧩": 0.02,  # Signal distributes to nodes
		},
	}

	f.decay = {
		"📡": {"rate": 0.008, "target": "🗑"},  # Infrastructure degrades slowly
		"🧩": {"rate": 0.01, "target": "🗑"},
	}

	f.alignment_couplings = {
		"📶": {
			"⛰": -0.15,  # Mountains block signal
			"🌬": +0.05,  # Clear air helps
		},
		"📡": {
			"⚡": +0.20,  # Power helps transmission
			"💧": -0.15,  # Water damages electronics
		},
	}

	return f


## Terrarium Collective (center ring)
## "Closed loops, open futures." Ecological engineers.
static func create_terrarium_collective() -> Faction:
	var f = Faction.new()
	f.name = "Terrarium Collective"
	f.description = "Ecological engineers who design self-sustaining habitats. Sewage, air, nutrients - the unglamorous essentials."
	f.ring = "center"
	f.signature = ["🌿", "🫙", "♻️", "💧"]
	f.tags = ["ecology", "sustainability", "closed-loop", "life-support"]

	# COOL IDEAS:
	# - Perfect closed loop: everything cycles back
	# - Alignment with 🌙 for circadian rhythms
	# IMPLEMENTED: Closed-loop cycling, jar as containment

	f.self_energies = {
		"🌿": 0.2,    # Vegetation - the life
		"🫙": 0.3,    # Jar - containment, stability
		"♻️": 0.15,   # Recycling - the process
		"💧": 0.1,    # Water - the medium
	}

	f.hamiltonian = {
		"🌿": {
			"🫙": 0.6,   # Plants in jars
			"💧": 0.7,   # Plants need water
			"♻️": 0.4,   # Plants feed cycle
		},
		"🫙": {
			"🌿": 0.6,
			"💧": 0.5,   # Jar holds water
			"♻️": 0.5,   # Jar enables cycling
		},
		"♻️": {
			"🌿": 0.4,
			"🫙": 0.5,
			"💧": 0.6,   # Water cycles
		},
		"💧": {
			"🌿": 0.7,
			"🫙": 0.5,
			"♻️": 0.6,
		},
	}

	# Closed loop: everything feeds back
	f.lindblad_incoming = {
		"🌿": {
			"💧": 0.04,  # Water feeds plants
			"♻️": 0.03,  # Nutrients from recycling
		},
		"💧": {
			"♻️": 0.04,  # Recycled water
		},
	}

	f.lindblad_outgoing = {
		"🌿": {
			"♻️": 0.03,  # Plants produce recyclable matter
		},
	}

	# Minimal decay in closed system
	f.decay = {
		"🫙": {"rate": 0.005, "target": "🗑"},  # Containers eventually crack
	}

	f.alignment_couplings = {
		"🌿": {
			"☀": +0.15,  # Plants like light
			"🌙": +0.05,  # Some circadian benefit
		},
		"💧": {
			"🔥": -0.20,  # Heat evaporates water out of system
		},
		"🫙": {
			"⛰": +0.10,  # Stable ground helps
		},
	}

	return f


## Clan of the Hidden Root (center ring)
## "What grows below sustains what lives above." Subterranean farmers.
static func create_hidden_root() -> Faction:
	var f = Faction.new()
	f.name = "Clan of the Hidden Root"
	f.description = "Subterranean farmers cultivating root vegetables and fungi. Their tunnels connect in ways surface-dwellers don't understand."
	f.ring = "center"
	f.signature = ["🌱", "⛏", "🪨", "🪤"]
	f.tags = ["underground", "farming", "tunnels", "hidden"]

	# COOL IDEAS:
	# - Inverse alignment with ☀ - they work in darkness
	# - Gated: root growth requires mining (⛏ gate)
	# - Connection to 🍄 Mycelial Web through underground
	# IMPLEMENTED: Underground growth cycle, mining enables planting

	f.self_energies = {
		"🌱": 0.1,    # Seeds/roots - potential
		"⛏": 0.2,    # Pickaxe - tool for expansion
		"🪨": 0.25,   # Rock - the medium they work
		"🪤": 0.15,   # Trap - pest control, also traps information
	}

	f.hamiltonian = {
		"🌱": {
			"⛏": 0.5,   # Mining creates planting space
			"🪨": 0.4,   # Roots grow in rock crevices
			"🪤": 0.2,   # Traps protect crops
		},
		"⛏": {
			"🌱": 0.5,
			"🪨": 0.7,   # Pickaxe works rock
			"🪤": 0.3,   # Mining reveals trap locations
		},
		"🪨": {
			"⛏": 0.7,
			"🌱": 0.4,
			"⛰": 0.5,   # Rock connects to earth (cross-faction)
		},
		"🪤": {
			"🌱": 0.2,
			"⛏": 0.3,
			"🐇": 0.4,   # Traps catch pests (cross-faction)
		},
	}

	# Mining creates growing space
	f.gated_lindblad = {
		"🌱": [
			{
				"source": "🪨",   # Rock → root space
				"rate": 0.04,
				"gate": "⛏",      # REQUIRES mining
				"power": 1.0,
				"inverse": false,
			},
		],
	}

	f.lindblad_incoming = {
		"🪨": {
			"⛰": 0.02,   # Earth provides rock (cross-faction)
		},
	}

	f.decay = {
		"⛏": {"rate": 0.02, "target": "🗑"},  # Tools wear out
		"🪤": {"rate": 0.03, "target": "🗑"}, # Traps degrade
	}

	# Underground = inverse sun relationship
	f.alignment_couplings = {
		"🌱": {
			"☀": -0.15,   # Underground crops don't need sun
			"🌙": +0.10,  # Moon-linked (like mushrooms)
			"💧": +0.15,  # Water seeps down
		},
		"🪨": {
			"⛰": +0.20,  # More earth = more rock to work
		},
		"⛏": {
			"⚙": +0.10,  # Tools benefit from gears
		},
	}

	return f


## ========================================
## BATCH 2: FIRST RING (5 factions)
## Slightly more structured - enforcement, measurement, transport
## ========================================


## Scythe Provosts (first ring)
## "The harvest will be protected." Estate guards.
static func create_scythe_provosts() -> Faction:
	var f = Faction.new()
	f.name = "Scythe Provosts"
	f.description = "Estate guards who protect agricultural land. They fight for the fields, not for glory."
	f.ring = "first"
	f.signature = ["🌱", "⚔", "🛡", "🏇"]
	f.tags = ["military", "protection", "agriculture", "patrol"]

	# COOL IDEAS:
	# - Gated protection: crops only safe when shields present
	# - Alignment with 🌾 - they protect wheat specifically
	# - Inverse gating: raiders attack when no provosts
	# IMPLEMENTED: Protection aura via alignment, patrol cycle

	f.self_energies = {
		"🌱": 0.1,    # Seeds - what they protect
		"⚔": 0.2,    # Sword - offensive capability
		"🛡": 0.25,   # Shield - defensive capability
		"🏇": 0.15,   # Horse - mobility, patrol
	}

	f.hamiltonian = {
		"🌱": {
			"🛡": 0.5,   # Shields protect seeds
			"🏇": 0.3,   # Patrols check on crops
		},
		"⚔": {
			"🛡": 0.6,   # Sword and shield together
			"🏇": 0.5,   # Cavalry charges
		},
		"🛡": {
			"🌱": 0.5,
			"⚔": 0.6,
			"🏇": 0.4,
		},
		"🏇": {
			"⚔": 0.5,
			"🛡": 0.4,
			"🌱": 0.3,
		},
	}

	f.lindblad_incoming = {
		"🛡": {
			"⚔": 0.02,  # Combat experience strengthens defense
		},
	}

	f.lindblad_outgoing = {
		"⚔": {
			"💀": 0.02,  # Combat leads to death (cross-faction)
		},
	}

	f.decay = {
		"⚔": {"rate": 0.015, "target": "🗑"},  # Weapons dull
		"🛡": {"rate": 0.01, "target": "🗑"},   # Shields crack
	}

	# Protection aura - their presence helps crops
	f.alignment_couplings = {
		"🛡": {
			"🌾": +0.20,  # Shields protect wheat (cross-faction)
			"🌱": +0.15,  # Shields protect seedlings
			"🐇": -0.10,  # Shields scare off pests
		},
		"🏇": {
			"🐺": -0.15,  # Patrols deter predators (cross-faction)
		},
		"⚔": {
			"🔥": -0.10,  # Combat can suppress fires
		},
	}

	return f


## Measure Scribes (first ring)
## "The measure is the reality." Pure auditors defining existence.
static func create_measure_scribes() -> Faction:
	var f = Faction.new()
	f.name = "Measure Scribes"
	f.description = "Pure auditors who define the units of existence. Whoever defines measurement defines reality."
	f.ring = "first"
	f.signature = ["📐", "📊", "🧮", "📘", "📋"]
	f.tags = ["bureaucracy", "measurement", "standards", "definition"]

	# COOL IDEAS:
	# - Measurement collapse mechanic - their presence forces definition
	# - Complex coupling: imaginary component for "potential measurement"
	# IMPLEMENTED: Definition stabilizes other things via alignment

	f.self_energies = {
		"📐": 0.3,    # Square - geometric truth
		"📊": 0.25,   # Chart - data visualization
		"🧮": 0.2,    # Abacus - calculation
		"📘": 0.35,   # Book - codified knowledge (high stability)
		"📋": 0.15,   # Clipboard - working documents
	}

	f.hamiltonian = {
		"📐": {
			"📊": 0.5,   # Geometry informs charts
			"🧮": 0.6,   # Geometry is calculation
			"📘": 0.4,   # Standards become codified
		},
		"📊": {
			"📐": 0.5,
			"🧮": 0.5,   # Charts from calculations
			"📋": 0.4,   # Charts on clipboards
		},
		"🧮": {
			"📐": 0.6,
			"📊": 0.5,
			"📘": 0.5,   # Calculations become formulas
		},
		"📘": {
			"📐": 0.4,
			"🧮": 0.5,
			"📋": 0.3,   # Books reference working docs
		},
		"📋": {
			"📊": 0.4,
			"📘": 0.3,
			"🧮": 0.3,
		},
	}

	# Standards production
	f.lindblad_incoming = {
		"📘": {
			"📐": 0.03,  # Standards become books
			"🧮": 0.02,  # Formulas get recorded
		},
		"📊": {
			"🧮": 0.03,  # Calculations produce charts
		},
	}

	f.lindblad_outgoing = {
		"📋": {
			"📘": 0.02,  # Working docs become codified
		},
	}

	f.decay = {
		"📋": {"rate": 0.02, "target": "🗑"},  # Working docs expire
	}

	# Measurement stabilizes reality - their presence makes things more defined
	f.alignment_couplings = {
		"📐": {
			"🏛": +0.25,  # Order loves precision
			"🏚": -0.20,  # Chaos hates measurement
		},
		"📘": {
			"⚖": +0.15,  # Law relies on definitions
			"🔥": -0.25,  # Fire destroys books
		},
		"🧮": {
			"💰": +0.10,  # Money needs counting
		},
	}

	return f


## Engram Freighters (first ring)
## "Your data, delivered." Long-haul data transport.
static func create_engram_freighters() -> Faction:
	var f = Faction.new()
	f.name = "Engram Freighters"
	f.description = "Long-haul data transport. Their ships are flying libraries, their crews notoriously well-read."
	f.ring = "first"
	f.signature = ["📡", "💾", "🧩", "📶"]
	f.tags = ["transport", "data", "archive", "logistics"]

	# COOL IDEAS:
	# - Data accumulation mechanic - they hoard information
	# - Gated delivery: data only moves when signal present
	# - Phase coupling: data in transit has imaginary component
	# IMPLEMENTED: Data transport gated on signal strength

	f.self_energies = {
		"📡": 0.25,   # Antenna - receive/transmit
		"💾": 0.3,    # Disk - storage (stable)
		"🧩": 0.15,   # Puzzle - data packets
		"📶": 0.1,    # Signal - carrier
	}

	f.hamiltonian = {
		"📡": {
			"💾": 0.5,   # Antenna loads data
			"🧩": 0.4,   # Antenna receives packets
			"📶": 0.7,   # Antenna needs signal
		},
		"💾": {
			"📡": 0.5,
			"🧩": 0.6,   # Disk stores packets
		},
		"🧩": {
			"📡": 0.4,
			"💾": 0.6,
			"📶": 0.5,   # Packets ride signal
		},
		"📶": {
			"📡": 0.7,
			"🧩": 0.5,
		},
	}

	# Data transport requires signal
	f.gated_lindblad = {
		"💾": [
			{
				"source": "🧩",   # Packets → Storage
				"rate": 0.05,
				"gate": "📶",     # REQUIRES signal
				"power": 1.0,
				"inverse": false,
			},
		],
	}

	f.lindblad_incoming = {
		"🧩": {
			"📡": 0.03,  # Antenna receives packets
		},
	}

	f.decay = {
		"📶": {"rate": 0.05, "target": "🗑"},   # Signal fades fast
		"🧩": {"rate": 0.02, "target": "🗑"},   # Undelivered packets expire
	}

	f.alignment_couplings = {
		"📶": {
			"📡": +0.20,  # More antennas = better signal (Relay Lattice synergy)
			"⛰": -0.15,  # Mountains block signal
		},
		"💾": {
			"🔥": -0.30,  # Fire destroys data
			"❄": +0.10,   # Cold preserves
		},
	}

	return f


## Quarantine Sealwrights (first ring)
## "What stays contained, stays safe." Biological border guards.
static func create_quarantine_sealwrights() -> Faction:
	var f = Faction.new()
	f.name = "Quarantine Sealwrights"
	f.description = "Biological border guards preventing contamination. Their work prevents plagues nobody knows about."
	f.ring = "first"
	f.signature = ["🧪", "🦗", "🧫", "🚫", "🩺", "🧬"]
	f.tags = ["containment", "medical", "prevention", "quarantine"]

	# COOL IDEAS:
	# - Inverse gating: disease spreads when containment low
	# - Measurement behavior: observing 🦗 collapses to contained state
	# - Negative coupling to 🦠 - they suppress disease
	# IMPLEMENTED: Containment suppresses pests, medical response

	f.self_energies = {
		"🧪": 0.2,    # Alchemy - testing
		"🦗": -0.1,   # Pests - what they contain (negative = unstable)
		"🧫": 0.25,   # Petri dish - controlled study
		"🚫": 0.3,    # Prohibition - the seal itself
		"🩺": 0.2,    # Stethoscope - medical care
		"🧬": 0.15,   # DNA - understanding the threat
	}

	f.hamiltonian = {
		"🧪": {
			"🧫": 0.6,   # Testing uses cultures
			"🦗": 0.4,   # Testing examines pests
			"🧬": 0.5,   # Testing reveals DNA
		},
		"🦗": {
			"🧪": 0.4,
			"🚫": 0.5,   # Pests meet prohibition
			"🧫": 0.3,   # Pests studied in dishes
		},
		"🧫": {
			"🧪": 0.6,
			"🦗": 0.3,
			"🧬": 0.5,   # Cultures reveal genetics
		},
		"🚫": {
			"🦗": 0.5,
			"🩺": 0.4,   # Prohibition enables treatment
		},
		"🩺": {
			"🚫": 0.4,
			"🧪": 0.4,
			"🧬": 0.3,
		},
		"🧬": {
			"🧪": 0.5,
			"🧫": 0.5,
			"🩺": 0.3,
		},
	}

	# Containment suppresses threats
	f.lindblad_outgoing = {
		"🦗": {
			"🚫": 0.04,  # Pests get contained
		},
	}

	f.lindblad_incoming = {
		"🚫": {
			"🧪": 0.03,  # Testing strengthens protocols
			"🩺": 0.02,  # Medical response builds containment
		},
	}

	f.decay = {
		"🧪": {"rate": 0.02, "target": "🗑"},   # Reagents expire
		"🩺": {"rate": 0.01, "target": "🗑"},   # Equipment wears
	}

	# Containment aura - their presence suppresses biological threats
	f.alignment_couplings = {
		"🚫": {
			"🦠": -0.35,  # Strong disease suppression (cross-faction)
			"🦗": -0.25,  # Pest suppression
		},
		"🧫": {
			"🦠": +0.10,  # Controlled disease study (attracts samples)
		},
		"🩺": {
			"💀": -0.15,  # Medical care reduces death
			"👥": +0.10,  # Population trusts doctors
		},
	}

	return f


## Nexus Wardens (first ring)
## "Every crossing has a keeper." Gatekeepers of transit points.
static func create_nexus_wardens() -> Faction:
	var f = Faction.new()
	f.name = "Nexus Wardens"
	f.description = "Gatekeepers who control major transit points. Their keys open doors that shouldn't exist."
	f.ring = "first"
	f.signature = ["🛂", "📋", "🚧", "🗝", "🚪"]
	f.tags = ["transit", "control", "gatekeeping", "keys"]

	# COOL IDEAS:
	# - Gated passage: movement requires key
	# - Driver: gates open/close on schedule
	# - Complex coupling: keys have "potential" (imaginary) aspect
	# IMPLEMENTED: Gate control cycle, key enables passage

	f.self_energies = {
		"🛂": 0.25,   # Passport control - authority
		"📋": 0.15,   # Documents - paperwork
		"🚧": 0.2,    # Barrier - the obstruction
		"🗝": 0.3,    # Key - access (high value)
		"🚪": 0.1,    # Door - the passage (neutral, varies)
	}

	# Gate cycle - doors open and close periodically
	f.drivers = {
		"🚪": {
			"type": "sine",
			"freq": 0.1,      # 10 second period
			"phase": 0.0,
			"amp": 0.3,
		},
	}

	f.hamiltonian = {
		"🛂": {
			"📋": 0.6,   # Control requires documents
			"🚧": 0.5,   # Control at barriers
			"🗝": 0.4,   # Control grants keys
		},
		"📋": {
			"🛂": 0.6,
			"🚧": 0.4,   # Papers at checkpoints
			"🚪": 0.3,   # Documents enable passage
		},
		"🚧": {
			"🛂": 0.5,
			"📋": 0.4,
			"🚪": 0.6,   # Barrier blocks door
		},
		"🗝": {
			"🛂": 0.4,
			"🚪": 0.7,   # Key opens door
			"🚧": 0.3,   # Key bypasses barrier
		},
		"🚪": {
			"🚧": 0.6,
			"🗝": 0.7,
			"📋": 0.3,
		},
	}

	# Keys enable passage through barriers
	f.gated_lindblad = {
		"🚪": [
			{
				"source": "🚧",   # Barrier → Door (passage)
				"rate": 0.04,
				"gate": "🗝",     # REQUIRES key
				"power": 1.2,     # Superlinear - good keys very effective
				"inverse": false,
			},
		],
	}

	f.lindblad_incoming = {
		"📋": {
			"🛂": 0.03,  # Control generates paperwork
		},
		"🗝": {
			"🛂": 0.02,  # Authority grants keys (slowly)
		},
	}

	f.decay = {
		"📋": {"rate": 0.025, "target": "🗑"},  # Documents expire
		"🚧": {"rate": 0.01, "target": "🗑"},   # Barriers degrade
	}

	f.alignment_couplings = {
		"🗝": {
			"🏛": +0.15,  # Order recognizes keys
			"🏚": -0.10,  # Chaos ignores keys
		},
		"🚧": {
			"🚢": -0.10,  # Shipping slowed by barriers
			"👥": -0.05,  # Population slowed by barriers
		},
		"🛂": {
			"📘": +0.15,  # Law backs passport control
		},
	}

	return f


## ========================================
## BATCH 3: SECOND RING CENTER-ADJACENT (9 factions)
## More structured, specialized - still fundamentally mundane
## ========================================


## Seamstress Syndicate (second ring)
## "Every stitch carries meaning." Information encoded in fabric.
static func create_seamstress_syndicate() -> Faction:
	var f = Faction.new()
	f.name = "Seamstress Syndicate"
	f.description = "Tailors who encode information in fabric patterns. A trained eye reads origin, status, and secrets in the weave."
	f.ring = "second"
	f.signature = ["🪡", "🧵", "🧶", "📡", "👘"]
	f.tags = ["craft", "information", "fashion", "encoding"]

	# COOL IDEAS:
	# - Imaginary coupling for "hidden messages" in fabric
	# - Alignment with House of Thorns (aristocracy needs fashion)
	# IMPLEMENTED: Fabric production, signal encoding in cloth

	f.self_energies = {
		"🪡": 0.15,   # Needle - the tool
		"🧵": 0.1,    # Thread - raw material
		"🧶": 0.12,   # Yarn - bulk material
		"📡": 0.08,   # Signal - encoded information
		"👘": 0.25,   # Garment - finished product
	}

	f.hamiltonian = {
		"🪡": {
			"🧵": 0.7,   # Needle uses thread
			"🧶": 0.5,   # Needle works yarn
			"👘": 0.6,   # Needle makes garments
		},
		"🧵": {
			"🪡": 0.7,
			"🧶": 0.4,   # Thread from yarn
			"👘": 0.5,   # Thread in garments
			"📡": 0.3,   # Thread carries signal (encoding)
		},
		"🧶": {
			"🪡": 0.5,
			"🧵": 0.4,
			"👘": 0.4,
		},
		"📡": {
			"🧵": 0.3,
			"👘": 0.5,   # Garments carry signals
		},
		"👘": {
			"🪡": 0.6,
			"🧵": 0.5,
			"📡": 0.5,
		},
	}

	# Garment production
	f.lindblad_incoming = {
		"👘": {
			"🧵": 0.04,  # Thread becomes garment
			"🧶": 0.03,  # Yarn becomes garment
		},
		"📡": {
			"👘": 0.02,  # Garments carry encoded signals
		},
	}

	f.lindblad_outgoing = {
		"🧶": {
			"🧵": 0.03,  # Yarn becomes thread
		},
	}

	f.decay = {
		"🧵": {"rate": 0.02, "target": "🗑"},   # Thread frays
		"👘": {"rate": 0.015, "target": "🗑"},  # Garments wear
	}

	f.alignment_couplings = {
		"👘": {
			"🌹": +0.20,  # House of Thorns loves fashion (cross-faction)
			"👥": +0.10,  # Population needs clothes
		},
		"📡": {
			"🕵️": +0.15,  # Spies use encoded messages
		},
	}

	return f


## Symphony Smiths (second ring)
## "Sound shapes reality." Acoustic craftspeople.
static func create_symphony_smiths() -> Faction:
	var f = Faction.new()
	f.name = "Symphony Smiths"
	f.description = "Artisans who forge instruments with properties that edge toward the mystical. They understand resonance at a level that approaches the quantum."
	f.ring = "second"
	f.signature = ["🎵", "🔊", "🔨", "⚙", "📡"]
	f.tags = ["craft", "acoustic", "resonance", "instruments"]

	# COOL IDEAS:
	# - Sound driver at musical frequency
	# - Imaginary coupling for "harmonic resonance"
	# - Connection to Resonance Dancers
	# IMPLEMENTED: Acoustic oscillation driver, instrument forging

	f.self_energies = {
		"🎵": 0.2,    # Music - the product
		"🔊": 0.15,   # Sound - the medium
		"🔨": 0.2,    # Hammer - forging tool
		"⚙": 0.15,   # Gear - mechanical precision
		"📡": 0.1,    # Signal - transmission
	}

	# Sound oscillates - harmonic driver
	f.drivers = {
		"🎵": {
			"type": "sine",
			"freq": 0.5,      # 2 second period - musical tempo
			"phase": 0.0,
			"amp": 0.35,
		},
	}

	f.hamiltonian = {
		"🎵": {
			"🔊": 0.8,   # Music is sound
			"📡": 0.4,   # Music broadcasts
		},
		"🔊": {
			"🎵": 0.8,
			"🔨": 0.5,   # Forging makes sound
			"📡": 0.5,   # Sound transmits
		},
		"🔨": {
			"🔊": 0.5,
			"⚙": 0.6,   # Hammer works gears
		},
		"⚙": {
			"🔨": 0.6,
			"🔊": 0.3,   # Mechanical resonance
		},
		"📡": {
			"🎵": 0.4,
			"🔊": 0.5,
		},
	}

	# Instrument creation
	f.lindblad_incoming = {
		"🎵": {
			"🔨": 0.03,  # Forging creates instruments
			"⚙": 0.02,  # Precision enables music
		},
	}

	f.decay = {
		"🔨": {"rate": 0.02, "target": "🗑"},
		"🔊": {"rate": 0.04, "target": "🗑"},  # Sound fades
	}

	f.alignment_couplings = {
		"🎵": {
			"💃": +0.25,  # Dancers love music (cross-faction)
			"⛪": +0.15,  # Sacred music
		},
		"🔊": {
			"🔇": -0.30,  # Keepers of Silence oppose sound (cross-faction)
		},
	}

	return f


## The Liminal Osmosis (second ring)
## "The signal finds those ready to receive." Broadcasters.
static func create_liminal_osmosis() -> Faction:
	var f = Faction.new()
	f.name = "The Liminal Osmosis"
	f.description = "Broadcasters who transmit on frequencies that slip between official channels. Their programs reach listeners who didn't know they were tuned in."
	f.ring = "second"
	f.signature = ["📶", "📻", "📡", "🗣"]
	f.tags = ["broadcast", "signal", "information", "liminal"]

	# COOL IDEAS:
	# - Multiple phase-shifted drivers for "channel hopping"
	# - Measurement behavior: observing collapses the broadcast
	# IMPLEMENTED: Broadcast pulse driver, signal propagation

	f.self_energies = {
		"📶": 0.15,   # Signal strength
		"📻": 0.2,    # Radio - receiver/transmitter
		"📡": 0.25,   # Antenna - infrastructure
		"🗣": 0.1,    # Voice - content
	}

	# Broadcast pulses - like radio transmission bursts
	f.drivers = {
		"📻": {
			"type": "pulse",
			"freq": 0.15,     # ~7 second period
			"phase": 0.0,
			"amp": 0.4,
		},
	}

	f.hamiltonian = {
		"📶": {
			"📻": 0.7,   # Signal through radio
			"📡": 0.6,   # Signal through antenna
			"🗣": 0.4,   # Signal carries voice
		},
		"📻": {
			"📶": 0.7,
			"📡": 0.5,   # Radio needs antenna
			"🗣": 0.5,   # Radio broadcasts voice
		},
		"📡": {
			"📶": 0.6,
			"📻": 0.5,
		},
		"🗣": {
			"📶": 0.4,
			"📻": 0.5,
		},
	}

	# Signal propagation
	f.lindblad_incoming = {
		"📶": {
			"📻": 0.04,  # Radio generates signal
			"📡": 0.03,  # Antenna amplifies signal
		},
	}

	f.lindblad_outgoing = {
		"🗣": {
			"📶": 0.03,  # Voice becomes signal
		},
	}

	f.decay = {
		"📶": {"rate": 0.06, "target": "🗑"},  # Signal fades fast
		"🗣": {"rate": 0.05, "target": "🗑"},  # Voice fades
	}

	f.alignment_couplings = {
		"📶": {
			"🔇": -0.25,  # Silence suppresses signal
			"📡": +0.20,  # More antennas help (Relay Lattice synergy)
		},
		"📻": {
			"⚡": +0.15,  # Power helps transmission
		},
	}

	return f


## Star-Charter Enclave (second ring)
## "We chart the paths between." Navigators of probability-space.
static func create_star_charter_enclave() -> Faction:
	var f = Faction.new()
	f.name = "Star-Charter Enclave"
	f.description = "Navigators who map routes through probability-space. Where others see chaos, they see currents."
	f.ring = "second"
	f.signature = ["🔭", "🌠", "🛰", "📡"]
	f.tags = ["navigation", "cosmic", "mapping", "probability"]

	# COOL IDEAS:
	# - Alignment with celestial bodies (☀🌙)
	# - Gated: navigation only works when stars visible
	# IMPLEMENTED: Celestial observation, satellite network

	f.self_energies = {
		"🔭": 0.3,    # Telescope - observation
		"🌠": 0.2,    # Shooting star - celestial marker
		"🛰": 0.25,   # Satellite - infrastructure
		"📡": 0.15,   # Antenna - communication
	}

	f.hamiltonian = {
		"🔭": {
			"🌠": 0.7,   # Telescope observes stars
			"🛰": 0.5,   # Telescope tracks satellites
			"📡": 0.3,   # Data transmission
		},
		"🌠": {
			"🔭": 0.7,
			"🛰": 0.4,   # Stars guide satellites
		},
		"🛰": {
			"🔭": 0.5,
			"🌠": 0.4,
			"📡": 0.6,   # Satellite needs antenna
		},
		"📡": {
			"🔭": 0.3,
			"🛰": 0.6,
		},
	}

	# Celestial observation gated on night sky
	f.gated_lindblad = {
		"🌠": [
			{
				"source": "🔭",   # Observation → Star sighting
				"rate": 0.04,
				"gate": "🌙",     # REQUIRES night (cross-faction)
				"power": 1.0,
				"inverse": false,
			},
		],
	}

	f.lindblad_incoming = {
		"🛰": {
			"📡": 0.02,  # Communication maintains satellites
		},
	}

	f.decay = {
		"🌠": {"rate": 0.08, "target": "🗑"},  # Stars fade from view
		"🛰": {"rate": 0.01, "target": "🗑"},  # Satellites degrade slowly
	}

	f.alignment_couplings = {
		"🔭": {
			"🌙": +0.30,  # Night helps observation
			"☀": -0.20,   # Day blinds telescopes
		},
		"🌠": {
			"🌌": +0.20,  # Cosmic alignment (cross-faction)
		},
		"🛰": {
			"⚡": +0.15,  # Power keeps satellites running
		},
	}

	return f


## Monolith Masons (second ring)
## "What we build, endures." Architects of stable structures.
static func create_monolith_masons() -> Faction:
	var f = Faction.new()
	f.name = "Monolith Masons"
	f.description = "Architects who construct buildings that remain stable across probability fluctuations. Their geometries were inherited from civilizations that no longer exist."
	f.ring = "second"
	f.signature = ["🧱", "🏛", "🏺", "📐"]
	f.tags = ["construction", "architecture", "stability", "ancient"]

	# COOL IDEAS:
	# - Very high stability self-energies
	# - Alignment bonus to 🏛 Order
	# IMPLEMENTED: Ultra-stable construction, ancient knowledge

	f.self_energies = {
		"🧱": 0.3,    # Brick - building block
		"🏛": 0.5,    # Temple/Order - very stable
		"🏺": 0.35,   # Artifact - preserved knowledge
		"📐": 0.4,    # Square - geometric precision
	}

	f.hamiltonian = {
		"🧱": {
			"🏛": 0.6,   # Bricks build temples
			"🏺": 0.3,   # Bricks hold artifacts
			"📐": 0.5,   # Bricks need precision
		},
		"🏛": {
			"🧱": 0.6,
			"🏺": 0.5,   # Temples hold artifacts
			"📐": 0.6,   # Temples need geometry
		},
		"🏺": {
			"🧱": 0.3,
			"🏛": 0.5,
			"📐": 0.4,   # Artifacts encode geometry
		},
		"📐": {
			"🧱": 0.5,
			"🏛": 0.6,
			"🏺": 0.4,
		},
	}

	# Stable construction
	f.lindblad_incoming = {
		"🏛": {
			"🧱": 0.03,  # Bricks become temples
			"📐": 0.02,  # Geometry enables temples
		},
	}

	# Very slow decay - these things ENDURE
	f.decay = {
		"🧱": {"rate": 0.005, "target": "🗑"},
		"🏺": {"rate": 0.003, "target": "🗑"},  # Artifacts nearly eternal
	}

	f.alignment_couplings = {
		"🏛": {
			"🏚": -0.30,  # Order opposes chaos strongly
			"⛰": +0.20,   # Solid ground helps
		},
		"📐": {
			"🧮": +0.15,  # Calculation helps geometry (Measure Scribes synergy)
		},
		"🧱": {
			"🔥": -0.15,  # Fire damages structures
			"💧": -0.10,  # Water erodes
		},
	}

	return f


## Obsidian Will (second ring)
## "Discipline is the foundation." Labor organizers imposing structure.
static func create_obsidian_will() -> Faction:
	var f = Faction.new()
	f.name = "Obsidian Will"
	f.description = "Labor organizers who impose structure on chaotic workforces. Their methods are strict, their results undeniable."
	f.ring = "second"
	f.signature = ["🪨", "⛓", "🧱", "📘", "🕴️"]
	f.tags = ["discipline", "labor", "organization", "structure"]

	# COOL IDEAS:
	# - Chains (⛓) have negative energy for workers but positive for order
	# - Alignment bonus to productivity
	# IMPLEMENTED: Discipline enforcement, structure production

	f.self_energies = {
		"🪨": 0.35,   # Obsidian - hard, unyielding
		"⛓": 0.1,    # Chains - binding (low but stable)
		"🧱": 0.25,   # Brick - structure
		"📘": 0.3,    # Book - codified rules
		"🕴️": 0.2,   # Suit - authority figure
	}

	f.hamiltonian = {
		"🪨": {
			"⛓": 0.5,   # Obsidian will chains
			"🧱": 0.6,   # Obsidian builds
			"📘": 0.3,   # Obsidian principles in book
		},
		"⛓": {
			"🪨": 0.5,
			"🕴️": 0.5,  # Suits wield chains
			"📘": 0.4,   # Chains codified
		},
		"🧱": {
			"🪨": 0.6,
			"📘": 0.4,   # Building codes
		},
		"📘": {
			"🪨": 0.3,
			"⛓": 0.4,
			"🧱": 0.4,
			"🕴️": 0.5,  # Suits write rules
		},
		"🕴️": {
			"⛓": 0.5,
			"📘": 0.5,
		},
	}

	# Discipline creates structure
	f.lindblad_incoming = {
		"🧱": {
			"⛓": 0.03,  # Chains enable building (forced labor)
			"🪨": 0.02,  # Will creates structure
		},
		"📘": {
			"🕴️": 0.03, # Suits codify rules
		},
	}

	f.decay = {
		"⛓": {"rate": 0.015, "target": "🗑"},
		"🕴️": {"rate": 0.02, "target": "🗑"},
	}

	# Discipline aura - their presence increases productivity but costs freedom
	f.alignment_couplings = {
		"🪨": {
			"🏛": +0.25,  # Order loves discipline
			"🏚": -0.20,  # Chaos hates it
		},
		"⛓": {
			"👥": -0.15,  # Population dislikes chains
			"🏭": +0.20,  # Factories benefit (cross-faction)
		},
		"📘": {
			"⚖": +0.15,  # Law recognizes their rules
		},
	}

	return f


## The Sovereign Ukase (second ring)
## "The decree provides." Medical supply arm of imperial authority.
static func create_sovereign_ukase() -> Faction:
	var f = Faction.new()
	f.name = "The Sovereign Ukase"
	f.description = "Pharmaceutical and medical supply arm of imperial authority. Their generosity comes with strings - dependency on their supply chains."
	f.ring = "second"
	f.signature = ["🧪", "💊", "📦", "🚛"]
	f.tags = ["medical", "supply", "imperial", "dependency"]

	# COOL IDEAS:
	# - Gated: medicine only flows to compliant populations
	# - Inverse gating: non-compliance leads to shortages
	# IMPLEMENTED: Medical supply chain, compliance gating

	f.self_energies = {
		"🧪": 0.2,    # Alchemy - production
		"💊": 0.3,    # Pills - the product
		"📦": 0.15,   # Package - distribution
		"🚛": 0.2,    # Truck - logistics
	}

	f.hamiltonian = {
		"🧪": {
			"💊": 0.7,   # Alchemy makes pills
			"📦": 0.4,   # Alchemy packaged
		},
		"💊": {
			"🧪": 0.7,
			"📦": 0.6,   # Pills packaged
			"🚛": 0.4,   # Pills shipped
		},
		"📦": {
			"🧪": 0.4,
			"💊": 0.6,
			"🚛": 0.7,   # Packages on trucks
		},
		"🚛": {
			"💊": 0.4,
			"📦": 0.7,
		},
	}

	# Medical supply gated on imperial compliance
	f.gated_lindblad = {
		"💊": [
			{
				"source": "🧪",   # Alchemy → Medicine
				"rate": 0.05,
				"gate": "📜",     # REQUIRES edicts/compliance (cross-faction)
				"power": 0.8,
				"inverse": false,
			},
		],
	}

	f.lindblad_incoming = {
		"📦": {
			"💊": 0.03,  # Pills get packaged
		},
	}

	f.lindblad_outgoing = {
		"📦": {
			"🚛": 0.04,  # Packages ship out
		},
	}

	f.decay = {
		"💊": {"rate": 0.025, "target": "🗑"},  # Medicine expires
		"📦": {"rate": 0.02, "target": "🗑"},
	}

	f.alignment_couplings = {
		"💊": {
			"💀": -0.20,  # Medicine reduces death
			"👥": +0.15,  # Population needs medicine
			"🩺": +0.15,  # Doctors use medicine (Quarantine synergy)
		},
		"🚛": {
			"🚧": -0.15,  # Barriers slow shipping
			"🏛": +0.10,  # Order helps logistics
		},
	}

	return f


## Helix Conservatory (second ring)
## "To understand the spiral is to understand existence." Genomics research.
static func create_helix_conservatory() -> Faction:
	var f = Faction.new()
	f.name = "Helix Conservatory"
	f.description = "Research institution dedicated to genomics. They study DNA like others study sacred texts, seeking meaning in the double helix."
	f.ring = "second"
	f.signature = ["🧪", "🔬", "🧬", "🧫", "⚗️", "🕳"]
	f.tags = ["research", "genetics", "science", "void-adjacent"]

	# COOL IDEAS:
	# - 🕳 has negative energy - void connection
	# - Gated: void discoveries require deep research
	# IMPLEMENTED: Deep research, void-adjacent discovery

	f.self_energies = {
		"🧪": 0.2,    # Alchemy
		"🔬": 0.3,    # Microscope
		"🧬": 0.35,   # DNA - core asset
		"🧫": 0.25,   # Petri dish
		"⚗️": 0.2,   # Alembic - transformation
		"🕳": -0.15,  # Void - what they found (negative, destabilizing)
	}

	f.hamiltonian = {
		"🧪": {
			"🔬": 0.5,
			"🧫": 0.6,
			"⚗️": 0.7,  # Alchemy uses alembic
		},
		"🔬": {
			"🧪": 0.5,
			"🧬": 0.7,   # Microscope reveals DNA
			"🧫": 0.6,
			"🕳": 0.3,   # Deep observation finds void
		},
		"🧬": {
			"🔬": 0.7,
			"🧫": 0.5,
			"🕳": 0.4,   # DNA points to void
		},
		"🧫": {
			"🧪": 0.6,
			"🔬": 0.6,
			"🧬": 0.5,
		},
		"⚗️": {
			"🧪": 0.7,
			"🧬": 0.4,
		},
		"🕳": {
			"🔬": 0.3,
			"🧬": 0.4,
		},
	}

	# Deep research can reveal void
	f.gated_lindblad = {
		"🕳": [
			{
				"source": "🧬",   # DNA → Void discovery
				"rate": 0.02,
				"gate": "🔬",     # REQUIRES deep observation
				"power": 1.5,     # Superlinear - more research = faster discovery
				"inverse": false,
			},
		],
	}

	f.lindblad_incoming = {
		"🧬": {
			"🧫": 0.03,  # Cultures produce DNA
			"⚗️": 0.02,  # Transformation reveals DNA
		},
	}

	f.decay = {
		"🧪": {"rate": 0.02, "target": "🗑"},
		"🧫": {"rate": 0.025, "target": "🗑"},
	}

	f.alignment_couplings = {
		"🧬": {
			"🌱": +0.15,  # Seeds have DNA (Seedvault synergy)
		},
		"🕳": {
			"⚫": +0.25,  # Void connects to Black Horizon (cross-faction)
			"🌑": +0.15,  # Darkness helps void perception
		},
		"🔬": {
			"🏛": +0.10,  # Order funds research
		},
	}

	return f


## Starforge Reliquary (second ring)
## "We maintain the forge that never cools." Celestial infrastructure.
static func create_starforge_reliquary() -> Faction:
	var f = Faction.new()
	f.name = "Starforge Reliquary"
	f.description = "Heavy-duty celestial mechanics maintaining ancient stellar infrastructure. They don't research new tech - they keep the old tech running."
	f.ring = "second"
	f.signature = ["🌞", "🌀", "⚙", "🚀"]
	f.tags = ["infrastructure", "celestial", "maintenance", "industrial"]

	# COOL IDEAS:
	# - Solar driver synced with Celestial Archons
	# - Rocket production requires stellar power
	# IMPLEMENTED: Stellar-powered industry, maintenance cycle

	f.self_energies = {
		"🌞": 0.4,    # Sun - power source (high)
		"🌀": 0.2,    # Spiral - energy flow
		"⚙": 0.25,   # Gear - machinery
		"🚀": 0.3,    # Rocket - output
	}

	# Solar power cycle - synced with day
	f.drivers = {
		"🌞": {
			"type": "sine",
			"freq": 0.05,     # Same as Celestial Archons
			"phase": 0.0,     # In phase with sun
			"amp": 0.6,
		},
	}

	f.hamiltonian = {
		"🌞": {
			"🌀": 0.7,   # Sun drives spiral
			"⚙": 0.5,   # Sun powers gears
			"🚀": 0.4,   # Sun launches rockets
		},
		"🌀": {
			"🌞": 0.7,
			"⚙": 0.6,   # Spiral turns gears
			"🚀": 0.5,   # Spiral propels rockets
		},
		"⚙": {
			"🌞": 0.5,
			"🌀": 0.6,
			"🚀": 0.6,   # Gears build rockets
		},
		"🚀": {
			"🌞": 0.4,
			"🌀": 0.5,
			"⚙": 0.6,
		},
	}

	# Stellar-powered production
	f.gated_lindblad = {
		"🚀": [
			{
				"source": "⚙",   # Gears → Rockets
				"rate": 0.04,
				"gate": "🌞",    # REQUIRES solar power
				"power": 1.0,
				"inverse": false,
			},
		],
	}

	f.lindblad_incoming = {
		"🌀": {
			"🌞": 0.03,  # Sun creates energy spiral
		},
		"⚙": {
			"🌀": 0.02,  # Spiral maintains gears
		},
	}

	f.decay = {
		"⚙": {"rate": 0.015, "target": "🗑"},
		"🚀": {"rate": 0.01, "target": "🗑"},
	}

	f.alignment_couplings = {
		"🌞": {
			"☀": +0.35,  # Synergy with Celestial sun
			"🌙": -0.20, # Night reduces power
		},
		"🚀": {
			"🔬": +0.15,  # Research helps rockets (Rocketwright synergy)
		},
		"⚙": {
			"🛠": +0.10,  # Tools help maintenance (Gearwright synergy)
		},
	}

	return f


## ========================================
## Utility Functions
## ========================================

static func get_all() -> Array:
	return [
		# Batch 1: True center
		create_tinker_team(),
		create_seedvault_curators(),
		create_relay_lattice(),
		create_terrarium_collective(),
		create_hidden_root(),
		# Batch 2: First ring
		create_scythe_provosts(),
		create_measure_scribes(),
		create_engram_freighters(),
		create_quarantine_sealwrights(),
		create_nexus_wardens(),
		# Batch 3: Second ring center-adjacent
		create_seamstress_syndicate(),
		create_symphony_smiths(),
		create_liminal_osmosis(),
		create_star_charter_enclave(),
		create_monolith_masons(),
		create_obsidian_will(),
		create_sovereign_ukase(),
		create_helix_conservatory(),
		create_starforge_reliquary(),
	]

static func get_factions_for_emoji(emoji: String) -> Array:
	var result: Array = []
	for faction in get_all():
		if faction.speaks(emoji):
			result.append(faction)
	return result
