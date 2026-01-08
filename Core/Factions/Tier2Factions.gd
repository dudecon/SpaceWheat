## Tier2Factions.gd
## Commerce (💰), Industry (⚙), and Governance (⚖) branches
## Learned from Granary Guilds, Millwright's Union, and Carrion Throne

class_name Tier2Factions
extends RefCounted

# Preload Faction class
const Faction = preload("res://Core/Factions/Faction.gd")

## ========================================
## TIER 2A: COMMERCE BRANCH (from 💰)
## ========================================


## Ledger Bailiffs (first ring)
## "Extraction is the law." Documentary enforcement, ledger-death.
static func create_ledger_bailiffs() -> Faction:
	var f = Faction.new()
	f.name = "Ledger Bailiffs"
	f.description = "The enforcement arm of documentary reality. They collect what the ledgers say is owed. The worst punishment is ledger-death."
	f.ring = "first"
	f.signature = ["⚖", "💰", "📒", "📘", "🚔"]
	f.tags = ["enforcement", "extraction", "bureaucracy", "commerce"]
	
	f.self_energies = {
		"📒": 0.2,    # Debt ledger - documentary power
		"🚔": 0.15,   # Enforcement capacity
		"⚖": 0.25,   # Justice/law
		"💰": 0.3,    # Wealth (extracted)
		"📘": 0.1,    # Law (consumed from Station Lords)
	}
	
	f.hamiltonian = {
		"📒": {
			"💰": 0.6,   # Ledger tracks wealth
			"💸": 0.7,   # Ledger tracks debt
			"📘": 0.5,   # Ledger backed by law
			"🚔": 0.4,   # Ledger enables enforcement
		},
		"🚔": {
			"📒": 0.4,
			"⚖": 0.5,   # Enforcement serves justice
			"👥": 0.5,   # Enforcement targets population
		},
		"⚖": {
			"📒": 0.5,
			"📘": 0.6,   # Justice from law
			"🚔": 0.5,
		},
		"💰": {
			"📒": 0.6,
			"👥": 0.4,   # Wealth from population
		},
	}
	
	# GATED: Extraction requires law
	f.gated_lindblad = {
		"💰": [
			{
				"source": "👥",   # Tax population
				"rate": 0.06,
				"gate": "📘",     # REQUIRES codified law
				"power": 1.0,
				"inverse": false,
			},
		],
		"💸": [
			{
				"source": "👥",   # Impose debt
				"rate": 0.04,
				"gate": "📒",     # REQUIRES ledger entry
				"power": 1.0,
				"inverse": false,
			},
		],
	}
	
	f.lindblad_incoming = {
		"📒": {
			"📘": 0.03,  # Law enables ledger entries
		},
		"🚔": {
			"📒": 0.02,  # Ledger entries enable enforcement
		},
	}
	
	f.lindblad_outgoing = {
		"📒": {
			"🗑": 0.005, # Old ledgers decay
		},
	}
	
	f.decay = {
		"📒": {"rate": 0.005, "target": "🗑"},
	}
	
	f.alignment_couplings = {
		"📒": {
			"🏛": +0.20,  # Order strengthens records
			"🔥": -0.25,  # Fire destroys records
		},
		"🚔": {
			"⚖": +0.15,  # Justice empowers enforcement
			"🏚": -0.20,  # Chaos weakens enforcement
		},
	}
	
	return f


## The Gilded Legacy (first ring)
## "Wealth endures. Wealth remembers." Mining consortiums, old money.
static func create_gilded_legacy() -> Faction:
	var f = Faction.new()
	f.name = "The Gilded Legacy"
	f.description = "Mining consortiums and gem traders. Old money, patient money, money that thinks in generations."
	f.ring = "first"
	f.signature = ["⛏", "💎", "💰", "✨"]
	f.tags = ["mining", "wealth", "commerce", "patience"]
	
	f.self_energies = {
		"⛏": 0.15,   # Mining - extraction potential
		"💎": 0.4,    # Gems - concentrated value
		"💰": 0.3,    # Wealth
		"✨": 0.2,    # Refined/processed value
	}
	
	f.hamiltonian = {
		"⛏": {
			"💎": 0.6,   # Mining finds gems
			"⛰": 0.5,   # Mining extracts from earth (cross-faction)
			"✨": 0.3,
		},
		"💎": {
			"⛏": 0.6,
			"💰": 0.7,   # Gems become wealth
			"✨": 0.5,   # Gems are refined
		},
		"💰": {
			"💎": 0.7,
			"✨": 0.4,
		},
		"✨": {
			"💎": 0.5,
			"💰": 0.4,
		},
	}
	
	f.lindblad_incoming = {
		"💎": {
			"⛏": 0.02,   # Mining produces gems (slow, patient)
			"⛰": 0.01,   # Earth yields gems (cross-faction)
		},
		"💰": {
			"💎": 0.03,  # Gems become wealth
			"✨": 0.02,  # Refined goods become wealth
		},
		"✨": {
			"💎": 0.02,  # Gems refined
		},
	}
	
	# Very slow decay - wealth endures
	f.decay = {
		"💎": {"rate": 0.001, "target": "⛰"},  # Gems return to earth (geological)
	}
	
	f.alignment_couplings = {
		"💎": {
			"⛰": +0.15,  # Deep earth yields gems
			"🔥": -0.10,  # Heat can damage some gems
		},
		"💰": {
			"🏛": +0.20,  # Order protects wealth
			"🏚": -0.15,  # Chaos threatens wealth
		},
	}
	
	return f


## Quay Rooks (second ring)
## "The docks remember every debt." Port authority, interface to town economy.
static func create_quay_rooks() -> Faction:
	var f = Faction.new()
	f.name = "Quay Rooks"
	f.description = "Dockside operators who control port operations. They know which ships carry what and which cargo is fiction."
	f.ring = "second"
	f.signature = ["🚢", "⚓", "💰", "🪝"]
	f.tags = ["port", "commerce", "shipping", "information"]
	
	f.self_energies = {
		"🚢": 0.25,   # Ship - logistics
		"⚓": 0.2,    # Anchor - port control
		"💰": 0.3,    # Wealth from trade
		"🪝": 0.15,   # Hook - dock operations
	}
	
	f.hamiltonian = {
		"🚢": {
			"⚓": 0.6,   # Ships need ports
			"💰": 0.5,  # Ships carry wealth
			"🪝": 0.4,  # Dock operations
			"💧": 0.3,  # Ships need water (cross-faction)
		},
		"⚓": {
			"🚢": 0.6,
			"🪝": 0.5,
			"💰": 0.3,
		},
		"💰": {
			"🚢": 0.5,
			"⚓": 0.3,
		},
		"🪝": {
			"🚢": 0.4,
			"⚓": 0.5,
			"💰": 0.3,
		},
	}
	
	f.lindblad_incoming = {
		"💰": {
			"🚢": 0.04,  # Shipping generates wealth
		},
		"🪝": {
			"⚓": 0.03,  # Port enables dock ops
		},
	}
	
	# Ships require port infrastructure
	f.gated_lindblad = {
		"🚢": [
			{
				"source": "💰",   # Wealth funds ships
				"rate": 0.03,
				"gate": "⚓",      # REQUIRES port
				"power": 1.0,
				"inverse": false,
			},
		],
	}
	
	f.decay = {
		"🪝": {"rate": 0.02, "target": "🗑"},
	}
	
	f.alignment_couplings = {
		"🚢": {
			"💧": +0.20,  # Water enables shipping
			"🌬": +0.10,  # Wind helps sailing
		},
		"⚓": {
			"🏛": +0.15,  # Order helps port operations
		},
	}
	
	return f


## Bone Merchants (second ring)
## "The dead have much to sell." Grey market body modifications.
static func create_bone_merchants() -> Faction:
	var f = Faction.new()
	f.name = "Bone Merchants"
	f.description = "Grey market dealers in body modifications. Cybernetic, biological, skeletal. They upgrade what nature provided."
	f.ring = "second"
	f.signature = ["🦴", "💉", "🔧", "💰"]
	f.tags = ["biomod", "grey-market", "cybernetic", "commerce"]
	
	f.self_energies = {
		"🦴": 0.2,    # Skeletal/structural mods
		"💉": 0.15,   # Injections/biological mods
		"🔧": 0.15,   # Surgical tools
		"💰": 0.3,    # Wealth (grey market premium)
	}
	
	f.hamiltonian = {
		"🦴": {
			"💉": 0.5,   # Skeletal + biological integration
			"🔧": 0.6,   # Tools for bone work
			"💰": 0.4,   # Mods cost money
			"👥": 0.5,   # Mods for population (cross-faction)
		},
		"💉": {
			"🦴": 0.5,
			"🔧": 0.4,
			"💰": 0.3,
			"🧪": 0.4,   # Alchemy connection (cross-faction)
		},
		"🔧": {
			"🦴": 0.6,
			"💉": 0.4,
			"⚙": 0.4,   # Tools need gears (cross-faction)
		},
		"💰": {
			"🦴": 0.4,
			"💉": 0.3,
		},
	}
	
	# Body mods require tools AND population
	f.gated_lindblad = {
		"🦴": [
			{
				"source": "👥",   # Modify population
				"rate": 0.03,
				"gate": "🔧",      # REQUIRES tools
				"power": 1.0,
				"inverse": false,
			},
		],
		"💰": [
			{
				"source": "🦴",   # Mods generate wealth
				"rate": 0.05,
				"gate": "👥",      # REQUIRES customers
				"power": 0.8,
				"inverse": false,
			},
		],
	}
	
	f.lindblad_incoming = {
		"🔧": {
			"⚙": 0.02,   # Gears enable surgical tools
		},
	}
	
	f.decay = {
		"💉": {"rate": 0.03, "target": "🗑"},  # Injectables expire
	}
	
	f.alignment_couplings = {
		"🦴": {
			"💀": +0.10,  # Death provides... materials
			"🏛": -0.15,  # Official order frowns on grey market
		},
		"💉": {
			"🦠": -0.20,  # Disease threatens biologics
		},
	}
	
	return f


## ========================================
## TIER 2B: INDUSTRY BRANCH (from ⚙)
## ========================================


## Kilowatt Collective (center ring)
## "The power must flow." Union electricians, AC circuit clock signal.
static func create_kilowatt_collective() -> Faction:
	var f = Faction.new()
	f.name = "Kilowatt Collective"
	f.description = "Union workers who maintain the grid. Their monthly meetings are legendarily boring. The power must flow."
	f.ring = "center"
	f.signature = ["🔋", "🔌", "⚙", "⚡"]
	f.tags = ["infrastructure", "power", "union", "clock-signal"]
	
	f.self_energies = {
		"🔋": 0.3,    # Battery - storage
		"🔌": 0.1,    # Plug - oscillator (driven)
		"⚙": 0.15,   # Gears - mechanical coupling
		"⚡": 0.2,    # Lightning - power
	}
	
	# 🔌 is a SINE DRIVER at 1 Hz - the clock signal
	f.drivers = {
		"🔌": {
			"type": "sine",
			"freq": 1.0,      # 1 Hz clock signal
			"phase": 0.0,
			"amp": 0.5,
		},
	}
	
	f.hamiltonian = {
		"🔌": {
			"🔋": 0.7,   # Plug drains battery
			"⚡": 0.5,   # Plug distributes power
			"⚙": 0.4,   # Mechanical coupling
		},
		"🔋": {
			"🔌": 0.7,
			"⚡": 0.8,   # Battery stores lightning
		},
		"⚡": {
			"🔋": 0.8,   # Lightning charges battery
			"🔌": 0.5,
		},
		"⚙": {
			"🔌": 0.4,
			"🏭": 0.5,   # Gears power factory (cross-faction)
		},
	}
	
	# AC CIRCUIT DYNAMICS:
	# ⚡ charges 🔋, 🔌 depletes 🔋, 🔌 outputs ⚡
	f.lindblad_incoming = {
		"🔋": {
			"⚡": 0.06,  # Lightning charges battery
		},
	}
	
	f.lindblad_outgoing = {
		"🔋": {
			"🔌": 0.04,  # Plug drains battery (slower than charge)
		},
		"🔌": {
			"⚡": 0.03,  # Plug outputs power (to grid)
		},
	}
	
	# No decay on core components - maintained
	f.decay = {}
	
	f.alignment_couplings = {
		"⚡": {
			"🌬": +0.10,  # Wind power
			"💧": +0.15,  # Hydro power
			"☀": +0.10,   # Solar power
		},
		"🔌": {
			"💧": -0.20,  # Water shorts circuits
		},
	}
	
	return f


## Gearwright Circle (center ring)
## "Precision is reliability." Certify equipment, produce gears.
static func create_gearwright_circle() -> Faction:
	var f = Faction.new()
	f.name = "Gearwright Circle"
	f.description = "The mechanics' guild. Their stamp means it meets spec. Their refusal means you're gambling."
	f.ring = "center"
	f.signature = ["⚙", "🛠", "🔩", "🧰", "🏷️"]
	f.tags = ["infrastructure", "certification", "manufacturing", "standards"]
	
	f.self_energies = {
		"⚙": 0.2,     # Gears - core product
		"🛠": 0.15,    # Tools
		"🔩": 0.1,     # Parts/components
		"🧰": 0.2,     # Toolbox - capability
		"🏷️": 0.25,   # Certification tag - quality stamp
	}
	
	f.hamiltonian = {
		"⚙": {
			"🛠": 0.6,   # Tools make gears
			"🔩": 0.5,   # Parts become gears
			"🧰": 0.4,
			"🏷️": 0.5,  # Gears get certified
		},
		"🛠": {
			"⚙": 0.6,
			"🔩": 0.5,
			"🧰": 0.6,
		},
		"🔩": {
			"⚙": 0.5,
			"🛠": 0.5,
		},
		"🧰": {
			"🛠": 0.6,
			"🔩": 0.4,
			"⚙": 0.4,
		},
		"🏷️": {
			"⚙": 0.5,   # Tags certify gears
			"🛠": 0.3,   # Tags certify tools
		},
	}
	
	# Gearwrights PRODUCE gears (core output)
	f.lindblad_incoming = {
		"⚙": {
			"🔩": 0.04,  # Parts become gears
			"🛠": 0.03,  # Tools enable gear production
		},
		"🏷️": {
			"⚙": 0.03,  # Good gears get certified
		},
	}
	
	f.lindblad_outgoing = {
		"⚙": {
			"🏭": 0.02,  # Gears flow to factories (cross-faction)
		},
	}
	
	# Certification reduces decay rate (handled in alignment)
	f.decay = {
		"⚙": {"rate": 0.01, "target": "🔩"},  # Uncertified gears wear faster
		"🔩": {"rate": 0.02, "target": "🗑"},
	}
	
	f.alignment_couplings = {
		"⚙": {
			"🏷️": +0.20,  # Certification improves gear life
			"💧": -0.10,  # Water rusts gears
		},
		"🛠": {
			"🏷️": +0.15,  # Certified tools last longer
		},
	}
	
	return f


## Rocketwright Institute (first ring)
## "Calculated ascent." Spacecraft school, produces rockets.
static func create_rocketwright_institute() -> Faction:
	var f = Faction.new()
	f.name = "Rocketwright Institute"
	f.description = "Technical school for spacecraft propulsion. Their bureaucracy is legendary. Their approved systems don't explode unexpectedly."
	f.ring = "first"
	f.signature = ["🚀", "🔬", "⚙", "📋"]
	f.tags = ["science", "aerospace", "certification", "research"]
	
	f.self_energies = {
		"🚀": 0.35,   # Rocket - high value output
		"🔬": 0.25,   # Research
		"⚙": 0.15,   # Gears (consumed)
		"📋": 0.2,    # Documentation/approval
	}
	
	f.hamiltonian = {
		"🚀": {
			"🔬": 0.6,   # Research enables rockets
			"⚙": 0.5,   # Rockets need gears
			"📋": 0.5,   # Rockets need approval
			"⚡": 0.4,   # Rockets need power (cross-faction)
		},
		"🔬": {
			"🚀": 0.6,
			"📋": 0.4,   # Research generates docs
			"🧪": 0.3,   # Research connects to alchemy (cross-faction)
		},
		"⚙": {
			"🚀": 0.5,
			"🔬": 0.3,
		},
		"📋": {
			"🚀": 0.5,
			"🔬": 0.4,
		},
	}
	
	# GATED: Rockets require approval AND gears
	f.gated_lindblad = {
		"🚀": [
			{
				"source": "🔬",   # Research → Rockets
				"rate": 0.03,
				"gate": "📋",     # REQUIRES documentation
				"power": 1.0,
				"inverse": false,
			},
			{
				"source": "⚙",   # Gears → Rockets
				"rate": 0.02,
				"gate": "📋",     # REQUIRES approval
				"power": 1.0,
				"inverse": false,
			},
		],
	}
	
	f.lindblad_incoming = {
		"📋": {
			"🔬": 0.04,  # Research generates documentation
		},
	}
	
	f.lindblad_outgoing = {
		"🚀": {
			"🚢": 0.01,  # Rockets integrate with shipping network (cross-faction)
		},
	}
	
	f.decay = {
		"📋": {"rate": 0.01, "target": "🗑"},  # Old specs become obsolete
	}
	
	f.alignment_couplings = {
		"🚀": {
			"🌌": +0.20,  # Cosmic alignment helps space travel
			"🔥": -0.15,  # Uncontrolled fire bad for rockets
		},
		"🔬": {
			"🏛": +0.15,  # Order helps research
		},
	}
	
	return f


## ========================================
## TIER 2C: GOVERNANCE BRANCH (from ⚖)
## ========================================


## Irrigation Jury (center ring)
## "Water flows where justice wills." 12 citizens decide water allocation.
static func create_irrigation_jury() -> Faction:
	var f = Faction.new()
	f.name = "Irrigation Jury"
	f.description = "Twelve citizens who decide where water goes. Their decisions shape harvests and settle disputes older than memory."
	f.ring = "center"
	f.signature = ["🌱", "💧", "⚖", "🪣"]
	f.tags = ["civic", "water", "justice", "agriculture"]
	
	f.self_energies = {
		"💧": 0.3,    # Water - the resource they control
		"⚖": 0.25,   # Justice - their authority
		"🪣": 0.15,   # Bucket - distribution
		"🌱": 0.1,    # Seedling - what they serve
	}
	
	f.hamiltonian = {
		"💧": {
			"⚖": 0.6,   # Water controlled by justice
			"🪣": 0.5,  # Water distributed via bucket
			"🌱": 0.5,  # Water feeds seedlings
			"🔥": -0.6, # Water opposes fire (cross-faction)
		},
		"⚖": {
			"💧": 0.6,
			"🪣": 0.4,  # Justice enables distribution
			"📜": 0.3,  # Justice receives edicts (cross-faction)
		},
		"🪣": {
			"💧": 0.5,
			"🌱": 0.4,
			"🌾": 0.4,  # Bucket waters wheat (cross-faction)
		},
		"🌱": {
			"💧": 0.5,
			"🪣": 0.4,
		},
	}
	
	# Water allocation GATED on justice
	f.gated_lindblad = {
		"🌱": [
			{
				"source": "💧",   # Water → Seedlings
				"rate": 0.05,
				"gate": "⚖",      # REQUIRES jury decision
				"power": 1.0,
				"inverse": false,
			},
		],
		"🌾": [
			{
				"source": "💧",   # Water → Wheat (cross-faction)
				"rate": 0.04,
				"gate": "⚖",
				"power": 1.0,
				"inverse": false,
			},
		],
	}
	
	f.lindblad_incoming = {
		"💧": {
			"🌧": 0.05,  # Rain fills water (cross-faction, if exists)
		},
	}
	
	f.lindblad_outgoing = {
		"💧": {
			"🔥": 0.08,  # Water suppresses fire (cross-faction)
		},
	}
	
	f.decay = {
		"🪣": {"rate": 0.02, "target": "🗑"},
	}
	
	f.alignment_couplings = {
		"💧": {
			"🌙": +0.15,  # Moon affects tides/water
			"☀": -0.10,  # Sun evaporates water
		},
		"⚖": {
			"🏛": +0.20,  # Order strengthens justice
			"🏰": +0.10,  # Crown validates jury
		},
	}
	
	return f


## The Indelible Precept (first ring)
## "What is written endures." Permanent records define existence.
static func create_indelible_precept() -> Faction:
	var f = Faction.new()
	f.name = "The Indelible Precept"
	f.description = "The office that creates permanent records. Birth, death, property, citizenship. What they record becomes true."
	f.ring = "first"
	f.signature = ["📋", "💳", "⚖", "📜"]
	f.tags = ["bureaucracy", "records", "identity", "governance"]
	
	f.self_energies = {
		"📋": 0.2,    # Documentation
		"💳": 0.25,   # Identity card - documentary existence
		"⚖": 0.2,    # Justice
		"📜": 0.15,   # Edicts (received from Throne)
	}
	
	f.hamiltonian = {
		"📋": {
			"💳": 0.6,   # Docs create identity
			"⚖": 0.5,   # Docs backed by justice
			"📜": 0.5,   # Docs from edicts
		},
		"💳": {
			"📋": 0.6,
			"👥": 0.6,   # Identity for population
			"⚖": 0.4,
		},
		"⚖": {
			"📋": 0.5,
			"💳": 0.4,
			"📜": 0.5,
		},
		"📜": {
			"📋": 0.5,
			"⚖": 0.5,
			"🏰": 0.4,   # Edicts from castle (cross-faction)
		},
	}
	
	# Creates identity documents
	f.lindblad_incoming = {
		"💳": {
			"📋": 0.04,  # Documentation creates identity
			"👥": 0.02,  # Population needs identity
		},
		"📜": {
			"🏰": 0.03,  # Edicts from Throne (cross-faction)
		},
	}
	
	f.lindblad_outgoing = {
		"📜": {
			"📘": 0.04,  # Edicts become law (flows to Station Lords)
		},
	}
	
	# Identity can be destroyed (ledger-death from Bailiffs)
	f.decay = {
		"💳": {"rate": 0.005, "target": "🗑"},  # Very slow - identity endures
		"📋": {"rate": 0.01, "target": "🗑"},
	}
	
	f.alignment_couplings = {
		"📋": {
			"🏛": +0.25,  # Order preserves records
			"🔥": -0.30,  # Fire destroys records
			"💧": -0.15,  # Water damages records
		},
		"💳": {
			"🧤": -0.20,  # Refugees have no identity
		},
	}
	
	return f


## House of Thorns (second ring)
## "Beauty conceals. Beauty reveals." Aristocratic court, hub faction.
static func create_house_of_thorns() -> Faction:
	var f = Faction.new()
	f.name = "House of Thorns"
	f.description = "The aristocratic court. They deal in marriages, alliances, favors, and elegant betrayals. The rose has thorns."
	f.ring = "second"
	f.signature = ["🌹", "🪞", "🍷", "⚖"]
	f.tags = ["aristocracy", "politics", "hub", "luxury"]
	
	f.self_energies = {
		"🌹": 0.25,   # Rose - beauty and danger
		"🪞": 0.2,    # Mirror - truth and reflection
		"🍷": 0.3,    # Wine - avarice, hedonic consumption
		"⚖": 0.2,    # Justice - legal influence
	}
	
	f.hamiltonian = {
		"🌹": {
			"🪞": 0.5,   # Beauty reflected
			"🍷": 0.6,   # Beauty and luxury
			"⚖": 0.4,   # Beauty influences justice
			"⚜": 0.5,   # Rose serves crown (cross-faction)
		},
		"🪞": {
			"🌹": 0.5,
			"🍷": 0.4,   # Mirror shows indulgence
			"⚖": 0.3,   # Mirror reveals truth
		},
		"🍷": {
			"🌹": 0.6,
			"🪞": 0.4,
			"⚖": 0.3,
			"💰": 0.5,  # Wine costs wealth (cross-faction)
		},
		"⚖": {
			"🌹": 0.4,
			"🪞": 0.3,
			"📜": 0.4,  # Justice from edicts (cross-faction)
		},
	}
	
	# Hub dynamics - connects to many factions
	f.lindblad_incoming = {
		"🍷": {
			"💰": 0.03,  # Wealth buys wine
		},
		"🌹": {
			"🍷": 0.02,  # Wine enables social roses
		},
	}
	
	f.lindblad_outgoing = {
		"🍷": {
			"💀": 0.01,  # Wine leads to death (eventually)
		},
		"🌹": {
			"🩸": 0.01,  # Thorns draw blood (cross-faction)
		},
	}
	
	f.decay = {
		"🍷": {"rate": 0.02, "target": "🗑"},  # Wine consumed
		"🌹": {"rate": 0.03, "target": "🍂"},  # Roses wilt
	}
	
	# Hub alignments - connects to many things
	f.alignment_couplings = {
		"🌹": {
			"☀": +0.10,   # Roses like sun
			"💧": +0.15,  # Roses need water
			"🏛": +0.15,  # Order helps nobility
		},
		"🍷": {
			"🔥": +0.10,  # Wine warmed by fire
			"⚜": +0.20,  # Crown loves wine
			"🌑": +0.10,  # Wine flows in darkness (connection to horror, future)
		},
		"🪞": {
			"🌙": +0.15,  # Mirror magic at night
		},
	}
	
	return f


## ========================================
## Utility Functions
## ========================================

static func get_all() -> Array:
	return [
		# Commerce branch
		create_ledger_bailiffs(),
		create_gilded_legacy(),
		create_quay_rooks(),
		create_bone_merchants(),
		# Industry branch
		create_kilowatt_collective(),
		create_gearwright_circle(),
		create_rocketwright_institute(),
		# Governance branch
		create_irrigation_jury(),
		create_indelible_precept(),
		create_house_of_thorns(),
	]

static func get_commerce_factions() -> Array:
	return [
		create_ledger_bailiffs(),
		create_gilded_legacy(),
		create_quay_rooks(),
		create_bone_merchants(),
	]

static func get_industry_factions() -> Array:
	return [
		create_kilowatt_collective(),
		create_gearwright_circle(),
		create_rocketwright_institute(),
	]

static func get_governance_factions() -> Array:
	return [
		create_irrigation_jury(),
		create_indelible_precept(),
		create_house_of_thorns(),
	]

static func get_factions_for_emoji(emoji: String) -> Array:
	var result: Array = []
	for faction in get_all():
		if faction.speaks(emoji):
			result.append(faction)
	return result
