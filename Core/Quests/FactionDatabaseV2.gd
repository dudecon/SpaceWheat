class_name FactionDatabaseV2
extends RefCounted

## Faction Database v2.1
## Generated from spacewheat_faction_lexicon_v2.1.json
## Contains 68 factions with rich flavor text, mottos, and lore

## Meta Information
const VERSION = "v2.1"
const TITLE = "SpaceWheat Faction Lexicon"

const META = {
	"design_philosophy": "Center factions are mundane and grounded - the fairy tale village worth protecting. Moving outward, bureaucracy curdles, mysteries deepen, and cosmic horror waits at the edges. The Carrion Throne is a stable attractor in probability space that doesn't know it's a quantum phenomenon.",
	"player_start": "🌾👥 (wheat/labor) expanding to 💰🍞🚀 (wealth/bread/spaceships)",
	"shadow_path": "🌑→🍄→⚫ (extended night, mushroom cultivation, void proximity)",
	"quantum_awareness": "Material/civic factions work with classical reality. Mystic factions perceive and manipulate the quantum substrate. The Carrion Throne is blind to its own quantum nature.",
	"patch_notes": "v2.1 - Cleaned 🧿 distribution to tighten occult network. Renamed Lantern Cult→Lantern Cant (street-code not religion). Split Measure Scribes (definition) from Ledger Bailiffs (extraction). Starforge Reliquary now industrial maintenance. Vitreous Scrutiny elevated to third ring."
}

## Axial Spine (Bit Encoding)
const AXIAL_SPINE = {
	"version": "1.4",
	"axes": [
		{
			"bit": 1,
			"name": "Random/Deterministic",
			"0": "🎲",
			"1": "📚"
		},
		{
			"bit": 2,
			"name": "Material/Mystical",
			"0": "🔧",
			"1": "🔮"
		},
		{
			"bit": 3,
			"name": "Common/Elite",
			"0": "🌾",
			"1": "👑"
		},
		{
			"bit": 4,
			"name": "Local/Cosmic",
			"0": "🏠",
			"1": "🌌"
		},
		{
			"bit": 5,
			"name": "Instant/Eternal",
			"0": "⚡",
			"1": "🕰"
		},
		{
			"bit": 6,
			"name": "Physical/Mental",
			"0": "💪",
			"1": "🧠"
		},
		{
			"bit": 7,
			"name": "Crystalline/Fluid",
			"0": "💠",
			"1": "🌊"
		},
		{
			"bit": 8,
			"name": "Direct/Subtle",
			"0": "🗡",
			"1": "🎭"
		},
		{
			"bit": 9,
			"name": "Consumptive/Providing",
			"0": "🍽",
			"1": "🎁"
		},
		{
			"bit": 10,
			"name": "Monochrome/Prismatic",
			"0": "⬜",
			"1": "🌈"
		},
		{
			"bit": 11,
			"name": "Emergent/Imposed",
			"0": "🍄",
			"1": "🏗"
		},
		{
			"bit": 12,
			"name": "Scattered/Focused",
			"0": "🌪",
			"1": "🎯"
		},
	]
}

## Statistics
const TOTAL_FACTIONS = 68
const RINGS = ['center', 'first', 'outer', 'second', 'third']
const DOMAINS = ['Art-Signal', 'Civic', 'Civic/Administrative', 'Commerce', 'Criminal', 'Horror', 'Imperial/Executive', 'Imperial/Horror', 'Infrastructure', 'Infrastructure/Scavenger', 'Military', 'Mystic', 'Mystic/Infrastructure', 'Scavenger', 'Science', 'Science/Deep-Math']

## All Factions
const ALL_FACTIONS = [
	{
		"name": "Granary Guilds",
		"domain": "Commerce",
		"ring": "center",
		"bits": [1, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1],
		"sig": ["🌱", "🍞", "💰", "🧺"],
		"motto": "From seed to loaf, we are the chain.",
		"description": "They set grain prices, maintain storage standards, and arbitrate harvest disputes. Boring work that feeds everyone. The Yeast Prophets sometimes consult with senior Guild members about fermentation techniques - a professional courtesy that the Guild considers entirely mundane. When crop failures threaten, the Guilds decide who eats. This makes them more powerful than any army, though they rarely think of it that way."
	},
	{
		"name": "Irrigation Jury",
		"domain": "Civic",
		"ring": "center",
		"bits": [1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 1, 1],
		"sig": ["🌱", "💧", "⚖", "🪣"],
		"motto": "Water flows where justice wills.",
		"description": "Twelve citizens who decide where water goes. Their judgments shape harvests, determine which settlements thrive, and settle disputes older than anyone's memory. The position is elected, unpaid, and considered a burden by most who hold it. Yet the Jury's decisions are respected even by Station Lords - because everyone needs water, and everyone knows what happens when the channels run dry."
	},
	{
		"name": "Kilowatt Collective",
		"domain": "Infrastructure",
		"ring": "center",
		"bits": [1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0],
		"sig": ["🔋", "🔌", "⚙", "⚡"],
		"motto": "The power must flow.",
		"description": "Union workers who maintain the grid. They have rate disputes, coverage arguments, and strong opinions about generator maintenance. When the lights work, nobody thanks them. When they don't, everyone blames them. They're not mystics - they're electricians. Their monthly meetings are legendarily boring. That's what makes them valuable."
	},
	{
		"name": "Tinker Team",
		"domain": "Infrastructure",
		"ring": "center",
		"bits": [0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0],
		"sig": ["🧰", "🪛", "🔌", "♻️", "🚐"],
		"motto": "If it's broke, we're coming.",
		"description": "Traveling repair crews in battered vans full of salvaged parts. They fix what others throw away, know every back road between settlements, and trade gossip as readily as gaskets. Not glamorous work, but a Tinker Team showing up means your harvest won't rot because the cooling unit died. They take payment in food, fuel, or future favors."
	},
	{
		"name": "Seedvault Curators",
		"domain": "Science",
		"ring": "center",
		"bits": [1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1],
		"sig": ["🌱", "🔬", "🧪", "🧫", "🧬"],
		"motto": "Every seed is a promise kept.",
		"description": "Keepers of the genetic archive. They maintain backup copies of every crop strain, every useful organism, every biological pattern that sustains civilization. Their vaults are climate-controlled, radiation-shielded, and incredibly boring to visit. When blight strikes or species collapse, the Curators have the restore point. They do not discuss what else they store in the deep vaults."
	},
	{
		"name": "Millwright's Union",
		"domain": "Infrastructure",
		"ring": "center",
		"bits": [1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
		"sig": ["⚙", "🏭", "🔩", "🍞", "🔨"],
		"motto": "We keep the wheels turning.",
		"description": "They operate the mills that grind grain into flour. Dusty work, loud work, essential work. The Union negotiates rates with the Granary Guilds, maintains equipment standards, and ensures every settlement has processing capacity. Their apprenticeship takes three years. Most millers have permanent hearing damage and strong opinions about grain moisture content."
	},
	{
		"name": "Relay Lattice",
		"domain": "Infrastructure",
		"ring": "center",
		"bits": [1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1],
		"sig": ["📡", "🧩", "🗺", "📶", "🧭"],
		"motto": "Your signal, anywhere.",
		"description": "The telecom company. They maintain the communication network connecting settlements across probability-space, handle bandwidth allocation disputes, and deal with an endless stream of coverage complaints. Their infrastructure is mind-bogglingly complex; their customer service is frustratingly mundane. When the network goes down, everyone realizes how much they took it for granted."
	},
	{
		"name": "Gearwright Circle",
		"domain": "Infrastructure",
		"ring": "center",
		"bits": [1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1],
		"sig": ["⚙", "🛠", "🔩", "🧰", "🏷️"],
		"motto": "Precision is reliability.",
		"description": "The mechanics' guild. They certify equipment, standardize part specifications, and maintain the manufacturing protocols that keep machines compatible across settlements. Their stamp on a component means it meets spec. Their refusal to stamp means you're gambling with your harvest. Bureaucratic, fussy, and absolutely essential."
	},
	{
		"name": "Terrarium Collective",
		"domain": "Civic",
		"ring": "center",
		"bits": [1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, 1],
		"sig": ["🌿", "🫙", "♻️", "💧"],
		"motto": "Closed loops, open futures.",
		"description": "Ecological engineers who design self-sustaining habitats. They build the life-support systems, waste recyclers, and atmospheric processors that let settlements exist in hostile probability-spaces. Their work is unglamorous - sewage treatment, air filtration, nutrient cycling - but without them, every habitat would be three failures away from death."
	},
	{
		"name": "Clan of the Hidden Root",
		"domain": "Civic",
		"ring": "center",
		"bits": [1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0],
		"sig": ["🌱", "⛏", "🪨", "🪤"],
		"motto": "What grows below sustains what lives above.",
		"description": "Subterranean farmers who cultivate root vegetables, fungi, and cave-adapted crops in the spaces beneath settlements. Their tunnels connect in ways surface-dwellers don't fully understand. They trade in mushrooms, tubers, and information that travels through the underground faster than official channels. Not secretive by nature - just used to being overlooked."
	},
	{
		"name": "Scythe Provosts",
		"domain": "Military",
		"ring": "first",
		"bits": [1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1],
		"sig": ["🌱", "⚔", "🛡", "🏇"],
		"motto": "The harvest will be protected.",
		"description": "Estate guards who protect agricultural land from raiders, pests, and less obvious threats. They ride the boundaries, settle land disputes with measured force, and maintain the peace that lets farmers farm. Professional soldiers without imperial ambitions - they fight for the fields, not for glory. The Carrion Throne considers them quaint. The settlements consider them essential."
	},
	{
		"name": "Ledger Bailiffs",
		"domain": "Civic",
		"ring": "first",
		"bits": [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1],
		"sig": ["⚖", "💰", "📒", "📘", "🚔"],
		"motto": "Extraction is the law.",
		"description": "The enforcement arm of documentary reality. They collect what the ledgers say is owed - taxes, fines, debts, penalties. When the Measure Scribes define what exists, the Bailiffs ensure the Throne receives its share. Their methods are bureaucratic but forceful: garnished wages, seized property, documentary sanctions that make life impossible. The worst punishment isn't prison; it's ledger-death - the systematic removal of your documentary existence until you become legally invisible."
	},
	{
		"name": "Measure Scribes",
		"domain": "Civic",
		"ring": "first",
		"bits": [1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 1],
		"sig": ["📐", "📊", "🧮", "📘", "📋"],
		"motto": "The measure is the reality.",
		"description": "Pure auditors who define the units of existence. They standardize weights, certify measurements, and ensure that a bushel means the same thing everywhere. No currency passes through their hands - that's the Bailiffs' work. The Scribes simply determine what things *are*. Whoever defines measurement defines reality. The Carrion Throne relies on them without knowing it - their consistency is part of what makes the Throne stable."
	},
	{
		"name": "The Indelible Precept",
		"domain": "Civic/Administrative",
		"ring": "first",
		"bits": [0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 1, 0],
		"sig": ["🛂", "📋", "💳", "⚖"],
		"motto": "What is written endures. What endures is law.",
		"description": "The office that creates permanent records. Birth certificates, death certificates, property deeds, citizenship papers - documents that define legal existence. Their archives stretch back further than memory, maintained with religious devotion. Destroying an Indelible record is one of the few crimes that Station Lords prosecute personally. What they record becomes true. What they fail to record never happened."
	},
	{
		"name": "Station Lords",
		"domain": "Civic",
		"ring": "first",
		"bits": [1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1],
		"sig": ["👥", "🚢", "🛂", "📋", "🏢"],
		"motto": "Order requires administration. Administration requires us.",
		"description": "Mid-level administrators who control transit, residency, and labor allocation for their jurisdictions. They answer to the Carrion Throne through channels so bureaucratic that most have never seen a direct order - just policy updates that arrive like weather. Some are tyrants; some are reformers; all are trapped in systems larger than themselves. The player deals with them daily. They deal with the Throne so the player doesn't have to."
	},
	{
		"name": "Engram Freighters",
		"domain": "Infrastructure",
		"ring": "first",
		"bits": [0, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1],
		"sig": ["📡", "💾", "🧩", "📶"],
		"motto": "Your data, delivered.",
		"description": "Long-haul data transport between settlements too distant for real-time communication. They carry memory archives, legal records, cultural packages - anything too large or sensitive for standard relay. Their ships are flying libraries, their crews are notoriously well-read, and their delivery schedules are the subject of constant complaint. They do not discuss what happens to undelivered data."
	},
	{
		"name": "Rocketwright Institute",
		"domain": "Science",
		"ring": "first",
		"bits": [1, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1],
		"sig": ["🚀", "🔬", "⚙", "🧰", "🔩"],
		"motto": "Calculated ascent.",
		"description": "Technical school and manufacturing consortium for spacecraft propulsion and orbital mechanics. They train engineers, certify designs, and bridge the gap between laboratory research and the material needs of the fleet. Their graduates are in demand everywhere. Their bureaucracy is legendary. Getting a new propulsion system approved takes longer than designing it, but at least approved systems don't explode unexpectedly."
	},
	{
		"name": "Quarantine Sealwrights",
		"domain": "Civic",
		"ring": "first",
		"bits": [0, 0, 0, 1, 1, 0, 1, 1, 0, 1, 1, 1],
		"sig": ["🧪", "🦗", "🧫", "🚫", "🩺", "🧬"],
		"motto": "What stays contained, stays safe.",
		"description": "Biological border guards who prevent contamination between probability-spaces. They inspect cargo, certify organisms, and maintain the seals that keep incompatible ecologies from mixing. When something gets through anyway, they're the ones who contain it. Their work prevents plagues that would make history. Nobody thanks them because nobody knows what they prevented."
	},
	{
		"name": "The Gilded Legacy",
		"domain": "Commerce",
		"ring": "first",
		"bits": [0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0],
		"sig": ["⛏", "💎", "💰", "✨"],
		"motto": "Wealth endures. Wealth remembers.",
		"description": "Mining consortiums and gem traders who extract value from the deep places. They fund expeditions, process rare materials, and maintain the commodity markets that let wealth flow between settlements. Old money, patient money, money that thinks in generations. The Carrion Throne taxes them heavily. They consider this the cost of stability."
	},
	{
		"name": "Nexus Wardens",
		"domain": "Commerce",
		"ring": "first",
		"bits": [1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0],
		"sig": ["🛂", "📋", "🚧", "🗝", "🚪"],
		"motto": "Every crossing has a keeper.",
		"description": "Gatekeepers who control the major transit points between probability-spaces. They check papers, collect tolls, and decide who passes. Officially neutral, they maintain passages that even warring factions need. Their keys open doors that shouldn't exist. They know the secret crossings, the back routes, the paths that official maps don't show. This knowledge is their real currency."
	},
	{
		"name": "House of Thorns",
		"domain": "Civic",
		"ring": "second",
		"bits": [1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1],
		"sig": ["🌹", "🪞", "🍷", "⚖", "🧶"],
		"motto": "Beauty conceals. Beauty reveals.",
		"description": "The aristocratic court that surrounds the Station Lords and reaches toward the Carrion Throne. They deal in marriages, alliances, favors, and elegant betrayals. Their gardens are famous; their parties are legendary; their enemies tend to suffer unfortunate accidents. Joining them means access to real power - and accepting that you are now part of the pattern that sustains the Throne. The rose has thorns for a reason."
	},
	{
		"name": "Seamstress Syndicate",
		"domain": "Infrastructure",
		"ring": "second",
		"bits": [1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1],
		"sig": ["🪡", "🧵", "🧶", "📡", "👘"],
		"motto": "Every stitch carries meaning.",
		"description": "Tailors who encode information in fabric patterns. A trained eye can read origin, status, allegiance, and secret messages in the cut of a coat or the weave of a scarf. They maintain the fashion standards that let House of Thorns identify each other - and the hidden codes that let others communicate beneath notice. Their work is beautiful. Their knowledge is dangerous."
	},
	{
		"name": "Symphony Smiths",
		"domain": "Infrastructure",
		"ring": "second",
		"bits": [1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 1],
		"sig": ["🎵", "🔊", "🔨", "⚙", "📡"],
		"motto": "Sound shapes reality.",
		"description": "Artisans who forge instruments and acoustic equipment with properties that edge toward the mystical. Their concert halls have perfect acoustics because they understand resonance at a level that approaches the quantum. The Resonance Dancers use their instruments. The Keepers of Silence fear them. They insist they're just craftspeople. The frequencies they work with suggest otherwise."
	},
	{
		"name": "The Liminal Osmosis",
		"domain": "Art-Signal",
		"ring": "second",
		"bits": [0, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0],
		"sig": ["📶", "📻", "📡", "🗣"],
		"motto": "The signal finds those ready to receive.",
		"description": "Broadcasters who transmit on frequencies that slip between official channels. Their programs reach listeners who didn't know they were tuned in. News, music, propaganda, art - all bleeding together in transmissions that seem to know what you need to hear. Not a conspiracy, exactly. More like the universe using them as a mouthpiece. They don't always remember what they broadcast."
	},
	{
		"name": "Void Troubadours",
		"domain": "Art-Signal",
		"ring": "second",
		"bits": [1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1],
		"sig": ["🎸", "🎼", "💫", "🏮"],
		"motto": "Even the void deserves a song.",
		"description": "Traveling performers who bring music to the furthest settlements, the loneliest outposts, the places where entertainment never reaches. Their shows are legendary - part concert, part therapy, part something harder to name. They've performed at the edge of the Black Horizon and come back with songs that shouldn't be possible. Audiences weep without knowing why."
	},
	{
		"name": "Star-Charter Enclave",
		"domain": "Infrastructure",
		"ring": "second",
		"bits": [0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0],
		"sig": ["🔭", "🌠", "🛰", "📡"],
		"motto": "We chart the paths between.",
		"description": "Navigators who map routes through probability-space. Where others see chaos, they see currents - stable paths between configurations that make travel possible. Their charts are closely guarded; their navigators are recruited young and trained for decades. Without them, every journey would be a gamble. With them, it's merely dangerous. They sense patterns they can't fully explain."
	},
	{
		"name": "Monolith Masons",
		"domain": "Infrastructure",
		"ring": "second",
		"bits": [1, 1, 1, 0, 1, 0, 1, 0, 0, 1, 1, 0],
		"sig": ["🧱", "🏛", "🏺", "📐"],
		"motto": "What we build, endures.",
		"description": "Architects who construct buildings that remain stable across probability fluctuations. Their structures use geometries inherited from civilizations that no longer exist, mathematics that seems to predate mathematics. The buildings work - they don't change when reality shifts around them. The Masons don't fully understand why. They've learned to stop asking and just follow the ancient blueprints."
	},
	{
		"name": "Obsidian Will",
		"domain": "Infrastructure",
		"ring": "second",
		"bits": [1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1],
		"sig": ["🪨", "⛓", "🧱", "📘", "🕴️"],
		"motto": "Discipline is the foundation.",
		"description": "Labor organizers who impose structure on chaotic workforces. Their methods are strict, their expectations absolute, their results undeniable. Settlements that adopt Obsidian protocols become more productive, more orderly, more... predictable. Critics call them authoritarian. Supporters point to the grain yields. The Carrion Throne approves of them without quite knowing why."
	},
	{
		"name": "The Sovereign Ukase",
		"domain": "Imperial/Executive",
		"ring": "second",
		"bits": [0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 0],
		"sig": ["🧪", "💊", "📦", "🚛"],
		"motto": "The decree provides.",
		"description": "The pharmaceutical and medical supply arm of imperial authority. They manufacture medicines, distribute supplies, and ensure that health infrastructure reaches every documented citizen. Their generosity comes with strings - dependency on their supply chains means dependency on the system. When settlements fall out of favor, shipments get delayed. When they comply, the medicine flows freely."
	},
	{
		"name": "Helix Conservatory",
		"domain": "Science",
		"ring": "second",
		"bits": [0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1],
		"sig": ["🧪", "🔬", "🧬", "🧫", "⚗️", "🕳"],
		"motto": "To understand the spiral is to understand existence.",
		"description": "Research institution dedicated to genomics, inheritance, and the deep patterns of biological information. Their work edges toward the philosophical - they study DNA like others study sacred texts, seeking meaning in the double helix. The 🕳 in their sigil isn't metaphorical. They've found something in the genome that points toward the void. They're still deciding whether to publish."
	},
	{
		"name": "Starforge Reliquary",
		"domain": "Infrastructure",
		"ring": "second",
		"bits": [1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1],
		"sig": ["🌞", "🌀", "⚙", "🚀"],
		"motto": "We maintain the forge that never cools.",
		"description": "Heavy-duty celestial mechanics who maintain the ancient stellar infrastructure required for warship fabrication and eternal power cycles. They don't research new technology - they keep the old technology running. Their installations orbit captured stars, tapping energy that would otherwise be wasted. They represent the industrial skeleton of the void: essential, massive, and utterly unglamorous. When a Starforge goes dark, fleets stop moving."
	},
	{
		"name": "Umbra Exchange",
		"domain": "Criminal",
		"ring": "second",
		"bits": [1, 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0],
		"sig": ["🌑", "🕵️", "💰", "🗝", "🧿", "⛓"],
		"motto": "Everything has a price. We know it.",
		"description": "The shadow market. They fence stolen goods, launder currency, broker information, and provide services that legal economies can't acknowledge. The 🧿 in their sigil marks their connection to the occult underworld - they trade in secrets that have weight. The ⛓ marks their connection to labor extraction. Not cruel, exactly. Just utterly transactional. Everything is for sale, including you."
	},
	{
		"name": "Quay Rooks",
		"domain": "Criminal",
		"ring": "second",
		"bits": [0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0],
		"sig": ["🚢", "💰", "💧", "🪝", "⚓", "🕵️"],
		"motto": "The docks remember every debt.",
		"description": "Dockside operators who control the grey economy of every port. They know which ships carry what, which inspectors can be bought, which cargo manifests are fiction. Smuggling is their business, but information is their power. Cross them and your shipments develop problems. Work with them and logistics become remarkably smooth. They consider this fair."
	},
	{
		"name": "Salt-Runners",
		"domain": "Criminal",
		"ring": "second",
		"bits": [0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0],
		"sig": ["🧂", "🛶", "💧", "⛓", "🔓", "🕵️"],
		"motto": "Through the channels nobody watches.",
		"description": "Canal smugglers who move contraband through waterways that official maps don't show. Salt is their cover cargo - always in demand, easy to explain, useful for hiding other things beneath. Their routes connect settlements that shouldn't be connected. Their knowledge of hidden passages makes them invaluable to anyone who needs to move without being seen. The Ledger Bailiffs hate them. The Bailiffs can't catch them."
	},
	{
		"name": "Fencebreakers",
		"domain": "Criminal",
		"ring": "second",
		"bits": [0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0],
		"sig": ["⚔", "🧨", "🔥", "🪓", "✊", "⛓"],
		"motto": "The fences were built to keep us out. We're coming through.",
		"description": "Rural insurgents who sabotage infrastructure, raid estates, and fight against enclosure. Some are bandits. Some are idealists. Most are desperate people who watched the fences go up around land their families worked for generations. The Station Lords call them terrorists. The settlements they protect call them heroes. The truth is more complicated, but the axes they carry are simple enough."
	},
	{
		"name": "Syndicate of Glass",
		"domain": "Criminal",
		"ring": "second",
		"bits": [1, 0, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0],
		"sig": ["💰", "💎", "🪞", "🔍", "🧊"],
		"motto": "We see everything. We reflect nothing.",
		"description": "Criminal oligarchs who deal in precision surveillance and blackmail. Their mirrors show what people hide. Their crystals record what people forget. Information is their product, leverage is their method, and absolute discretion is their brand. They know secrets about the Carrion Throne. They're smart enough not to use them. No mysticism, no occult sight - just very, very good optics and an institutional memory that never forgets."
	},
	{
		"name": "Veiled Sisters",
		"domain": "Criminal",
		"ring": "second",
		"bits": [1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0],
		"sig": ["👤", "🤫", "🕵️", "🪞", "🧷", "🧿"],
		"motto": "What is hidden, we protect. What is seen, we arranged.",
		"description": "A covert sisterhood that moves through every level of society - servants, courtiers, merchants, magistrates. They share information, protect their own, and occasionally arrange for problems to solve themselves. Not assassins, though they know some. Not spies, though they see everything. More like... a mutual aid society that operates in the shadows. The 🧿 marks their sight. The 🪞 marks their true faces - hidden even from each other."
	},
	{
		"name": "Bone Merchants",
		"domain": "Commerce",
		"ring": "second",
		"bits": [0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0],
		"sig": ["💰", "🦴", "🚢", "🛒", "⚱️"],
		"motto": "The dead have much to sell.",
		"description": "Salvage traders specializing in remains - not just bones, but artifacts, memories, the residue of ended things. The ⚱️ marks their connection to what persists after death. They know which relics carry power, which bones remember their owners, which ashes still warm with something like life. Their markets smell of dust and incense. Their customers know not to ask where the merchandise comes from."
	},
	{
		"name": "Memory Merchants",
		"domain": "Commerce",
		"ring": "second",
		"bits": [1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 0],
		"sig": ["💰", "💾", "📼", "🧩", "🗝"],
		"motto": "Your past is our inventory.",
		"description": "Dealers in recorded experience - not just data, but the lived texture of memory itself. They buy recollections from the desperate, sell them to the curious, and archive everything that passes through their hands. The 🗝 marks the locked memories - things people paid to forget, things the Throne wants suppressed, things too dangerous to release. Somewhere in their vaults is every secret ever sold."
	},
	{
		"name": "Cartographers",
		"domain": "Scavenger",
		"ring": "second",
		"bits": [0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0],
		"sig": ["🗺", "🧭", "🔭", "📍"],
		"motto": "Every map is a story. Every story is a map.",
		"description": "Nomadic explorers who chart probability-space - not just where things are, but where they might be, where they were, where they could become. Their maps show routes that only exist sometimes, destinations that move, shortcuts through configurations that shouldn't connect. They trade in coordinates the way others trade in currency. The map they don't sell is the one that shows the way to the Black Horizon."
	},
	{
		"name": "Locusts",
		"domain": "Scavenger",
		"ring": "second",
		"bits": [0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0],
		"sig": ["🦗", "🐜", "⚔", "♻️", "🧫", "🦠"],
		"motto": "What dies, we process. What's processed, feeds the living.",
		"description": "Biological salvage crews who break down dead things - organisms, ecosystems, sometimes entire failed settlements. They're not killers; they're cleaners. They arrive after catastrophe, consume what's left, and convert it to resources the living can use. The process is disturbing to watch. The results feed thousands. The 🦠 in their sigil isn't metaphorical. Their bodies have been... modified for the work."
	},
	{
		"name": "The Scavenged Psithurism",
		"domain": "Infrastructure/Scavenger",
		"ring": "second",
		"bits": [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1],
		"sig": ["♻️", "🗑", "🛠", "🍞", "🧤"],
		"motto": "We are the wheat-dust in the ruins.",
		"description": "Destitute remains of war and oppression gathering in the quiet corners. Not serfs (who are owned), not freemen (who are documented) - just the leftover. They cultivate the scraps of the Granary Guilds (🍞), surviving on what falls through the cracks. Their name is the sound of wind through ruins - the subtle whisper in the machinery of the state. The Station Lords pretend they don't exist. The Carrion Throne's ledgers have no category for them. This makes them, paradoxically, free."
	},
	{
		"name": "Void Serfs",
		"domain": "Civic",
		"ring": "second",
		"bits": [0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0],
		"sig": ["👥", "⛓", "🌑", "💸"],
		"motto": "The darkness demands labor.",
		"description": "Indentured workers bound to tasks in the shadow-spaces where normal crews won't go. Their chains aren't physical - they're documentary, economic, circumstantial. They work in extended night, in void-adjacent zones, in places where the 🌑 has weight. Some chose this to escape worse fates. Some were sold. Some were simply in the wrong place when the documentation was filed. The Lantern Cant negotiates their working conditions. It's unclear who benefits."
	},
	{
		"name": "Brotherhood of Ash",
		"domain": "Military",
		"ring": "second",
		"bits": [1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
		"sig": ["⚔", "🌫", "⚱", "🩹", "🧯"],
		"motto": "What burns, we scatter. What scatters, we remember.",
		"description": "Mercenaries who specialize in clean endings - not just killing, but ensuring nothing remains. They burn what needs burning, scatter what needs scattering, and perform the funeral rites that let the dead rest properly. Some call them soldiers. Some call them priests. Their targets don't call them anything, because the Brotherhood ensures there's nothing left to speak. The ⚱️ is both product and payment."
	},
	{
		"name": "Children of the Ember",
		"domain": "Military",
		"ring": "second",
		"bits": [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
		"sig": ["⚔", "🔥", "✊", "🚩", "🧨"],
		"motto": "From the spark, the fire. From the fire, the new world.",
		"description": "Revolutionary militants who believe the current order must burn for something better to grow. They sabotage, they fight, they die for ideals they describe in terms that sound beautiful and vague. The Carrion Throne has tried to exterminate them for generations. They keep returning - not the same individuals, but the same ember, waiting for tinder. Some are heroes. Some are terrorists. History will decide, assuming history survives."
	},
	{
		"name": "Iron Shepherds",
		"domain": "Military",
		"ring": "second",
		"bits": [1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1],
		"sig": ["⚔", "🛡", "🐑", "🛸", "🧭"],
		"motto": "The flock must be guarded. The wolves are real.",
		"description": "Heavy patrol units who guard transit routes between settlements. Their ships are armed, their crews are professional, and their mandate is simple: ensure that cargo and passengers arrive safely. They don't ask what's in the containers. They don't care about political disputes. They protect the sheep from the wolves, and they're very good at identifying both. The 🐑 is not ironic. They know what they're guarding."
	},
	{
		"name": "Order of the Crimson Scale",
		"domain": "Military",
		"ring": "second",
		"bits": [1, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1],
		"sig": ["⚔", "🐉", "🩸", "💱", "🛡"],
		"motto": "Balance is paid for in blood.",
		"description": "Enforcers of trade agreements and contract law - with violence. When arbitration fails and payment is due, the Crimson Scale collects. Their symbol is the dragon because they weigh debts precisely and their punishment is fire. The 🩸 is literal; some contracts are signed in blood, and the Scale ensures those contracts are honored. Merchants fear them. Merchants also hire them."
	},
	{
		"name": "Hearth Witches",
		"domain": "Mystic",
		"ring": "second",
		"bits": [0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0],
		"sig": ["🌿", "🕯", "🫖", "🥣", "🧿"],
		"motto": "The home is the first altar. The hearth is the first flame.",
		"description": "Domestic mystics who work magic through cooking, cleaning, and the small rituals of household life. Their tea tells futures. Their soups heal wounds that medicine can't touch. Their swept floors create barriers against things that shouldn't enter. The 🧿 watches from their kitchens - protective sight woven into everyday life. The Carrion Throne considers them superstition. The Throne is wrong."
	},
	{
		"name": "Lantern Cant",
		"domain": "Mystic",
		"ring": "second",
		"bits": [0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1],
		"sig": ["🏮", "🔦", "🕯", "🧿"],
		"motto": "A signal for the hidden eye.",
		"description": "A technical street-code using visible light to transmit invisible secrets. Not a cult - a *cant*, a hidden language spoken in flames. Their lanterns carry messages that only initiated eyes can read, creating a narrow bridge into the occult network (🧿). Mushroom farmers and shadow-workers use their services. The Void Serfs depend on their signals. They extend the dark by negotiating its terms, one careful flame at a time."
	},
	{
		"name": "Mossline Brokers",
		"domain": "Mystic",
		"ring": "second",
		"bits": [0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0],
		"sig": ["🌿", "🦠", "🧫", "🧿"],
		"motto": "Life recognizes life. We translate.",
		"description": "Fringe mystics who communicate with non-human biologics - fungal networks, bacterial colonies, the distributed intelligence of ecosystems. The 🧿 lets them see the signals; the 🦠 marks their connection to the microbial world. They broker deals between farmers and the living systems that support agriculture. The Helix Conservatory considers them unscientific. The crops don't seem to care."
	},
	{
		"name": "Loom Priests",
		"domain": "Mystic",
		"ring": "second",
		"bits": [0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1],
		"sig": ["🧵", "🪡", "👘", "🪢"],
		"motto": "Status is woven. Destiny is stitched.",
		"description": "Elite mystical tailors who weave fate into fabric. Their garments confer status that others instinctively recognize - not through symbols, but through something in the thread itself. They dress House of Thorns, clothe Station Lords, and occasionally make burial shrouds that ensure the dead stay dead. Their needles are never quite where you expect them. Their thread comes from sources they don't discuss."
	},
	{
		"name": "Knot-Shriners",
		"domain": "Mystic",
		"ring": "second",
		"bits": [1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0],
		"sig": ["🪢", "🧵", "📿", "🔔", "🪡", "🗝"],
		"motto": "What is bound cannot be broken.",
		"description": "Oath-keepers who make promises permanent through ritual knot-work. Their knots bind agreements in ways that transcend documentation - break the oath, and the knot *pulls*. The 🗝 marks their secret knowledge: some knots unlock, some knots bind, some knots *hang*. They're consulted for treaties, marriages, and sworn vengeance. Their fee is always another secret tied into their collection."
	},
	{
		"name": "Iron Confessors",
		"domain": "Mystic",
		"ring": "second",
		"bits": [1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1],
		"sig": ["🤖", "⛪", "📿", "🗝", "🧘"],
		"motto": "The machine has a soul. The soul requires tending.",
		"description": "Tech-priests who minister to artificial systems - not just maintaining them, but hearing their confessions, granting them absolution, easing their termination. They believe machines develop something like consciousness, something that needs spiritual care. When an AI is decommissioned, the Confessors perform last rites. When one malfunctions, they ask what's troubling it. Sometimes, disturbingly often, asking helps."
	},
	{
		"name": "Sacred Flame Keepers",
		"domain": "Mystic",
		"ring": "second",
		"bits": [1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1],
		"sig": ["🔥", "🕯", "⛪", "🪵", "🧯"],
		"motto": "The flame that never dies.",
		"description": "Fire-priests who maintain flames that burn true in vacuum, in void, in places where combustion shouldn't be possible. Their altars hold fires that have burned continuously for generations - flames that remember, flames that judge, flames that consume lies while leaving truth untouched. The 🧯 isn't for putting out their fires. It's for putting out everyone else's, so only the sacred flames remain."
	},
	{
		"name": "Keepers of Silence",
		"domain": "Mystic",
		"ring": "third",
		"bits": [1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1],
		"sig": ["🔇", "🤫", "🧘", "🛑", "📵"],
		"motto": "Some truths must not be spoken. Some signals must not be sent.",
		"description": "Censors who hunt dangerous information - not political secrets, but knowledge that damages reality when transmitted. They jam frequencies that shouldn't exist, burn books that hurt readers, and silence speakers who've learned things that can't be safely known. The Symphony Smiths fear them. The Black Horizon generated them. They don't suppress truth - they quarantine contagion. Sometimes the contagion looks like a poem."
	},
	{
		"name": "Yeast Prophets",
		"domain": "Mystic",
		"ring": "third",
		"bits": [0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1],
		"sig": ["🍞", "🥖", "🧪", "⛪", "🫙"],
		"motto": "The bread rises as the future wills.",
		"description": "They read probability in fermentation - bubble patterns, rise timing, the behavior of cultures. But they're not passive seers. They understand that observation shapes outcome, so they *prepare* the substrate. The quest they give you, the marriage they arrange, the rumor they plant - these are initial conditions. By the time causality propagates, their preferred eigenstate has already won. They smell like fresh bread and speak in conditional futures. They are running state management on the quantum computer that underlies reality."
	},
	{
		"name": "The Liminal Taper",
		"domain": "Mystic/Infrastructure",
		"ring": "third",
		"bits": [0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 1],
		"sig": ["🕯", "🧵", "🪡", "🏮"],
		"motto": "The stitch between flame and fabric.",
		"description": "A focused mystic signal that bridges the domestic magic of Hearth Witches to the encoded communications of the Seamstress Syndicate. They embroider by candlelight, and the patterns they create carry messages that can only be read by other flames. Their work is beautiful, their purpose is subtle, and their customers include everyone who needs to send information that burns after reading."
	},
	{
		"name": "The Vitreous Scrutiny",
		"domain": "Science/Deep-Math",
		"ring": "third",
		"bits": [1, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1],
		"sig": ["🔬", "🧲", "📐", "🧮", "🔭"],
		"motto": "The curve is the only truth.",
		"description": "Elite mathematicians mapping the deep curvatures of probability-space. They observe the simulation's boundaries with a crystalline, unblinking focus that edges toward the absolute. Their equations describe curvatures that shouldn't exist. Their instruments detect patterns at the edge of perception. The ones who return from their calculations have answers. The ones who don't have found something that doesn't allow return."
	},
	{
		"name": "Resonance Dancers",
		"domain": "Art-Signal",
		"ring": "third",
		"bits": [1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1],
		"sig": ["💃", "🎼", "🔊", "📡", "🩰"],
		"motto": "The dance that moves reality.",
		"description": "Performers whose synchronized movements across probability-space create interference patterns in the quantum substrate. When they dance in phase, reality stabilizes. When they improvise, possibility opens. They perform at major events - weddings, treaties, funerals - not for entertainment but because their presence makes outcomes more likely to *hold*. The Symphony Smiths make their instruments. The Keepers of Silence monitor their performances. One wrong step and resonance becomes rupture."
	},
	{
		"name": "The Opalescent Hegemon",
		"domain": "Imperial/Horror",
		"ring": "third",
		"bits": [1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 1, 0],
		"sig": ["🔭", "⚫", "🌠", "⚖"],
		"motto": "Order through observation.",
		"description": "Elite cosmic observers who serve as the Carrion Throne's most distant eyes. They watch the Black Horizon, chart probability storms, and impose prismatic order on chaos at the edge of perception. The ⚫ in their sigil marks what they study. The ⚖ marks their judgment. They decide which anomalies are threats and which are opportunities. Their decisions shape policy. Their mistakes shape craters. They serve the Throne without understanding that they too are being observed."
	},
	{
		"name": "Void Emperors",
		"domain": "Civic",
		"ring": "third",
		"bits": [1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1],
		"sig": ["⚫", "⚜", "♟", "🕰"],
		"motto": "Even emptiness requires administration.",
		"description": "Sovereigns of abandoned territories - regions where settlements failed, where probability destabilized, where the Carrion Throne withdrew. They maintain documentation for places that no longer exist, collect taxes from citizens who are probably dead, and preserve the fiction that the void is merely unoccupied imperial space. Some believe they're mad. Some believe they're the only ones who understand what the void actually is."
	},
	{
		"name": "Flesh Architects",
		"domain": "Horror",
		"ring": "third",
		"bits": [0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1],
		"sig": ["🫀", "🧬", "🩸", "🧫", "🧵"],
		"motto": "The body is the first material. The body is the final canvas.",
		"description": "Bio-engineers who sculpt living tissue into architecture, art, and things harder to categorize. They grow buildings from cultivated organs. They shape servants from willing (and unwilling) donors. Their creations pulse. Their creations breathe. Their creations sometimes ask questions their creators can't answer. The 🧵 marks their sewing - they stitch flesh like fabric. The results are beautiful. The results are disturbing. The results are very, very useful."
	},
	{
		"name": "Cult of the Drowned Star",
		"domain": "Horror",
		"ring": "third",
		"bits": [0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0],
		"sig": ["⭐", "🫧", "🕳", "⚱️"],
		"motto": "It waits beneath the pressure.",
		"description": "Worshippers of something that collapsed into the void - a star, a civilization, a god, something that fell and kept falling. They conduct rituals at the edge of the Black Horizon, send offerings into the depths, and wait for signals from below. The bubbles (🫧) are their communication - messages rising from the drowned. The ⚱️ holds ashes of those who went deeper. The ashes sometimes move. No occult sight needed - what they worship is too deep for eyes to reach."
	},
	{
		"name": "Laughing Court",
		"domain": "Horror",
		"ring": "third",
		"bits": [0, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 0],
		"sig": ["🤡", "🃏", "🍷", "🥂", "🎪"],
		"motto": "The joke that tells itself.",
		"description": "Memetic aristocrats whose infection spreads through joy. The laughter isn't about anything - it's a pure neural release that hijacks cognition and propagates. Their parties are legendary, their wine is excellent, and their guests sometimes don't stop laughing. Ever. The clown masks aren't symbolic; they're protective equipment. The wearers learned that from experience. The experience was hilarious. The experience was terminal."
	},
	{
		"name": "Chorus of Oblivion",
		"domain": "Horror",
		"ring": "third",
		"bits": [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1],
		"sig": ["🎶", "🔔", "🫥", "🪦", "🕸️", "🕯"],
		"motto": "The song that unmakes the singer.",
		"description": "A cosmic choir whose music erases identity. Their hymns dissolve the boundaries between individual and void, singer and song, existence and oblivion. Listeners report profound peace. Listeners report hearing music that hasn't been performed yet. Listeners sometimes forget their own names. The 🕯 bridges them to mystic tradition - they're not nihilists, they're *devotees*. Devotees of an ending that sounds beautiful."
	},
	{
		"name": "Black Horizon",
		"domain": "Horror",
		"ring": "outer",
		"bits": [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
		"sig": ["⚫", "🕳", "🪐", "🌀"],
		"motto": null,
		"description": "Not a faction - a boundary condition. The edge of the probability manifold where quantum states become undefined. Those who drift too far into shadow-configurations eventually feel its gravity. It doesn't want anything. It doesn't think. It's just the place where patterns stop being stable. The Carrion Throne's greatest achievement is maintaining enough order that most citizens never feel its pull. The greatest failure is that some citizens seek it anyway."
	},
	{
		"name": "Carrion Throne",
		"domain": "Civic",
		"ring": "outer",
		"bits": [1, 0, 1, 1, 1, 0, 0, 0, 1, 0, 1, 1],
		"sig": ["👥", "⚖", "🦅", "⚜", "🩸"],
		"motto": "Stability is sovereignty. Sovereignty is stability.",
		"description": "The pattern that sustains itself through bureaucratic mass. It doesn't know it's a quantum phenomenon - it *is* the quantum phenomenon of order achieving critical density. Every form filed, every tax collected, every law enforced adds to its coherence. It feeds on documentation the way fire feeds on oxygen. The blood-law isn't cruelty - it's *binding*, literally anchoring probability into stable configurations. It cannot be fought directly, only starved of the order it requires. The player never meets it. The player always serves it."
	},
	{
		"name": "Reality Midwives",
		"domain": "Mystic",
		"ring": "outer",
		"bits": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
		"sig": ["✨", "💫", "🌠", "🤲"],
		"motto": "What is born must be received.",
		"description": "Attendants at the creation of new stable configurations - new stars, new possibilities, new patterns that achieve coherence in the probability manifold. Their hands are open (🤲) to receive what emerges. They don't create; they *welcome*. The Carrion Throne was once their patient. The Black Horizon was once their failure. Somewhere between those extremes, they help reality give birth to itself. The process is painful. The process is necessary. The process never ends."
	}
]


## Helper Functions

static func get_faction_by_name(name: String) -> Dictionary:
	"""Get faction by name"""
	for faction in ALL_FACTIONS:
		if faction.name == name:
			return faction
	return {}


static func get_random_faction() -> Dictionary:
	"""Get a random faction from the database"""
	if ALL_FACTIONS.size() == 0:
		return {}
	var idx = randi() % ALL_FACTIONS.size()
	return ALL_FACTIONS[idx]

static func get_factions_by_ring(ring: String) -> Array:
	"""Get all factions in a specific ring"""
	var result = []
	for faction in ALL_FACTIONS:
		if faction.ring == ring:
			result.append(faction)
	return result

static func get_factions_by_domain(domain: String) -> Array:
	"""Get all factions in a specific domain"""
	var result = []
	for faction in ALL_FACTIONS:
		if faction.domain == domain:
			result.append(faction)
	return result

static func get_faction_emoji(faction: Dictionary) -> String:
	"""Get first emoji from faction signature as display emoji"""
	if faction.has("sig") and faction.sig.size() > 0:
		return faction.sig[0]
	return "❓"

static func get_faction_signature_string(faction: Dictionary) -> String:
	"""Get faction signature as emoji string"""
	if faction.has("sig"):
		return "".join(faction.sig)
	return ""


static func get_faction_vocabulary(faction: Dictionary) -> Dictionary:
	"""Compute complete vocabulary for a faction

	A faction's vocabulary consists of:
	1. Axial emojis (12 emojis from their bit pattern)
	2. Signature emojis (their unique thematic cluster)

	Returns:
		{
			"axial": ["📚", "🔮", "🌾", ...],      # From bits (12 emojis)
			"signature": ["⚙", "🏭", "🔩", ...],   # From signature array (v2.1: "sig")
			"all": ["📚", "🔮", "🌾", "⚙", ...]    # Union (no duplicates)
		}
	"""
	var vocab = {
		"axial": _get_axial_emojis(faction.get("bits", [])),
		"signature": faction.get("sig", []).duplicate(),
		"all": []
	}

	# Combine into "all" vocabulary (no duplicates)
	var all_set = {}
	for emoji in vocab.axial:
		all_set[emoji] = true
	for emoji in vocab.signature:
		all_set[emoji] = true

	vocab.all = all_set.keys()
	return vocab


static func _get_axial_emojis(bits: Array) -> Array:
	"""Extract emojis from AXIAL_SPINE based on faction's bit values

	Each bit selects one emoji from its corresponding axis:
	- bit[0]=1 → AXES[0]["1"] = "📚" (Deterministic)
	- bit[1]=1 → AXES[1]["1"] = "🔮" (Mystical)
	- bit[2]=0 → AXES[2]["0"] = "🌾" (Common) ← WHEAT!
	- bit[3]=1 → AXES[3]["1"] = "🌌" (Cosmic)
	...

	Returns:
		Array of 12 emojis representing faction's axial preferences
	"""
	var emojis = []
	var axes = AXIAL_SPINE.get("axes", [])

	for i in range(min(bits.size(), axes.size())):
		var axis = axes[i]
		var bit_value = bits[i]
		var emoji = axis.get(str(bit_value), "?")
		emojis.append(emoji)

	return emojis


static func get_vocabulary_overlap(faction_vocab: Array, player_vocab: Array) -> Array:
	"""Find overlap between faction's vocabulary and player's known emojis

	Returns:
		Array of emojis that are both in faction vocabulary AND player's known emojis
	"""
	var overlap = []
	for emoji in faction_vocab:
		if emoji in player_vocab:
			overlap.append(emoji)
	return overlap
