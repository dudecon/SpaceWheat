# Faction Icon Build Instructions

## Overview

SpaceWheat has **68 factions** that give quests, but only **27 factions** have Icons (quantum operators) implemented. Your task is to build out the remaining **51 factions** with proper Icon definitions.

**IMPORTANT DESIGN PHILOSOPHY:**
- Underdesign each faction. Keep them simple and distinct.
- The complexity of the game emerges from COLLISION between factions, not from individual faction complexity.
- Each faction should have 1-2 clear mechanics. That's it.
- Boring center, exotic edges. Inner ring factions are mundane. Outer ring factions get weird.

---

## Architecture Reference

### Quest System (gives quests, has lore)
- **File:** `Core/Quests/FactionDatabaseV2.gd`
- **Contains:** 68 factions with `name`, `sig` (signature emojis), `bits`, `motto`, `description`
- **Purpose:** Quest generation, vocabulary rewards, faction accessibility

### Icon System (defines quantum physics)
- **Files:**
  - `Core/Factions/CoreFactions.gd` - 10 core ecosystem factions
  - `Core/Factions/CivilizationFactions.gd` - 7 civilization factions
  - `Core/Factions/Tier2Factions.gd` - 10 tier 2 factions
  - `Core/Factions/AllFactions.gd` - aggregates all three
  - `Core/Factions/Faction.gd` - the Faction class definition
- **Purpose:** Builds Icons with Hamiltonian couplings, Lindblad operators, self-energies

### Icon Builder
- **File:** `Core/Factions/IconBuilder.gd`
- **Purpose:** Converts Faction definitions into Icon objects with quantum operators
- **Called by:** `Core/QuantumSubstrate/IconRegistry.gd` at game start

---

## What's Currently Implemented

### Core Ecosystem (10 factions) - ICONS ONLY, NO QUESTS
These power biome physics. They don't give quests.

| Faction | Signature | Purpose |
|---------|-----------|---------|
| Celestial Archons | ☀🌙 | Day/night cycle, sun qubit |
| Verdant Pulse | 🌾🌱 | Plant growth, wheat production |
| Mycelial Web | 🍄🍂💀 | Decomposition, mushroom cycle |
| Swift Herd | 🐇🌿 | Prey dynamics |
| Pack Lords | 🐺🐇 | Predator dynamics |
| Market Spirits | 🐂🐻💰💳🏛️🏚️ | Market oscillation |
| Hearth Keepers | 🔥❄️💧🏜️💨🌾🍞 | Kitchen thermodynamics |
| Pollinator Guild | 🐝🌸🍯 | Pollination |
| Plague Vectors | 🦗🌾🍂 | Crop disease |
| Wildfire | 🔥🌲🏡💨 | Fire dynamics |

### Civilization + Tier 2 (17 factions) - HAVE BOTH ICONS AND QUESTS
These are fully playable.

| Faction | Ring | Signature |
|---------|------|-----------|
| Granary Guilds | center | 🌾🌱🍞💰🧺 |
| Irrigation Jury | center | 🌾🌱💧⚖🪣 |
| Millwright's Union | center | ⚙🏭🔩🍞🔨 |
| Yeast Prophets | center | 🍞🧪🌾⏳🕯️ |
| Station Lords | center | 👥🚢🛂📋🏢 |
| Void Serfs | fringe | 👥⛓🚀🪨⚒️ |
| Carrion Throne | fringe | 👥💀👑🦴🩸 |
| The Scavenged Psithurism | fringe | 🍂♻️🦗🪲🌀 |
| Kilowatt Collective | center | 🔋🔌⚙⚡ |
| Gearwright Circle | center | ⚙🛠🔩🧰🏷️ |
| Rocketwright Institute | center | 🚀🔬⚙🧰🔩 |
| Ledger Bailiffs | center | ⚖💰📒📘🚔 |
| The Indelible Precept | center | 🛂📋💳⚖ |
| The Gilded Legacy | center | ⛏💎💰✨ |
| House of Thorns | fringe | 🌹🪞🍷⚖🧶 |
| Quay Rooks | fringe | 🚢💰💧🪝⚓🕵️ |
| Bone Merchants | fringe | 🦴💀💰🗝️🕯️ |

---

## What Needs Building: 51 Factions

These factions exist in `FactionDatabaseV2.gd` but have NO Icon definitions. They give quests but their emojis have no quantum operators.

### Priority Order: Inner to Outer

Build in this order. Inner ring = boring/stable. Outer ring = exotic/unstable.

#### CENTER RING (build first - keep boring)
- Tinker Team: 🧰🪛🔌♻️🚐
- Seedvault Curators: 🌱🔬🧪🧫🧬
- Relay Lattice: 📡🧩🗺📶🧭
- Terrarium Collective: 🌿🫙♻️💧
- Clan of the Hidden Root: 🌱⛏🪨🪤
- Scythe Provosts: 🌱⚔🛡🏇
- Measure Scribes: 📐📊🧮📘📋
- Engram Freighters: 📡💾🧩📶
- Quarantine Sealwrights: 🧪🦗🧫🚫🩺🧬
- Nexus Wardens: 🛂📋🚧🗝🚪
- Seamstress Syndicate: 🪡🧵🧶📡👘
- Symphony Smiths: 🎵🔊🔨⚙📡
- The Liminal Osmosis: 📶📻📡🗣
- Star-Charter Enclave: 🔭🌠🛰📡
- Monolith Masons: 🧱🏛🏺📐
- Obsidian Will: 🪨⛓🧱📘🕴️
- The Sovereign Ukase: 🧪💊📦🚛
- Helix Conservatory: 🧪🔬🧬🧫⚗️🕳
- Starforge Reliquary: 🌞🌀⚙🚀

#### FRINGE RING (middle priority - getting weirder)
- Umbra Exchange: 🌑🕵️💰🗝🧿⛓
- Salt-Runners: 🧂🛶💧⛓🔓🕵️
- Fencebreakers: 🔓🚧⛓🔨🗝
- Syndicate of Glass: 🔮💎🪞💰🕵️
- Veiled Sisters: 🧵🕯️🪞🌑👁
- Memory Merchants: 💭💾📜🧠💰
- Cartographers: 🗺🧭📐🔭✒️
- Locusts: 🦗🌾💨🔥🌀
- Brotherhood of Ash: 🔥💀⚱️🌑🕯️
- Children of the Ember: 🔥🌱♻️🌅🕯️
- Iron Shepherds: ⚙🐑🔩🛡📿
- Order of the Crimson Scale: 🐉🔥💎👑⚔
- Hearth Witches: 🔥🌿🍵🕯️🧹
- Lantern Cant: 🕯️📜🔮👁🗝
- Mossline Brokers: 🌿💧🪨💰🐌
- Loom Priests: 🧵🕸🌀📿🕯️
- Knot-Shriners: 🪢🧵📿🕯️🔮
- Iron Confessors: ⛓⚙📿💀🔨
- Sacred Flame Keepers: 🔥🕯️📿✨🏛
- Keepers of Silence: 🤫🕯️📿🌑👁
- The Liminal Taper: 🕯️🌑🚪👁🌀

#### OUTER RING (last - get weird here)
- Void Troubadours: 🎸🎼💫🏮
- The Vitreous Scrutiny: 👁🔮💎🌀🕳
- Resonance Dancers: 🎵🌀💫🩰✨
- The Opalescent Hegemon: 💎👑🌈✨🦚
- Void Emperors: 🌑👑🕳⛓💀
- Flesh Architects: 🧬🦴🩸🔬🕳
- Cult of the Drowned Star: 🌊🌟💀🌀🕳
- Laughing Court: 🎭😈🃏🎪👑
- Chorus of Oblivion: 🎵🌑💀🌀🕳
- Black Horizon: 🌑🕳⛓👁🌀
- Reality Midwives: 🌀🔮👁🧬🕳

---

## How to Build a Faction Icon

### Step 1: Read the existing faction data
Look up the faction in `Core/Quests/FactionDatabaseV2.gd` to get:
- `sig`: signature emojis
- `bits`: 12-bit encoding
- `motto` and `description`: for theming

### Step 2: Create a Faction function
Add to the appropriate file based on ring:
- `center` ring → `Core/Factions/Tier2Factions.gd` or new `Tier3Factions.gd`
- `fringe` ring → new file or extend existing
- `outer` ring → new file

### Step 3: Define the faction structure
Follow this template from existing factions:

```gdscript
static func create_example_faction() -> Faction:
    var f = Faction.new()
    f.name = "Example Faction"
    f.ring = "center"  # or "fringe" or "outer"
    f.signature = ["emoji1", "emoji2", "emoji3"]

    # Self-energies: How much each emoji "wants to exist"
    # Positive = stable, Negative = unstable/decaying
    f.self_energies = {
        "emoji1": 0.5,   # Moderately stable
        "emoji2": -0.2,  # Slightly unstable
    }

    # Hamiltonian couplings: Coherent oscillation between states
    # These create quantum superpositions
    f.hamiltonian_couplings = {
        "emoji1": {"emoji2": 0.3},  # emoji1 ↔ emoji2 oscillation
    }

    # Lindblad operators: Irreversible transitions (dissipation)
    # These create classical probability flow
    f.lindblad_operators = {
        "emoji1": {"emoji2": 0.1},  # emoji1 → emoji2 decay
    }

    return f
```

### Step 4: Register in AllFactions.gd
Add to the appropriate `get_*()` function.

---

## Physics Guidelines

### Self-Energies
- **Positive:** Emoji is stable, population tends to stay
- **Negative:** Emoji is unstable, population tends to leave
- **Magnitude 0.1-0.5:** Subtle effect
- **Magnitude 0.5-1.5:** Strong effect
- **Magnitude > 2.0:** Very dominant

### Hamiltonian Couplings
- Create **oscillation** between emojis (quantum coherence)
- Symmetric: if A→B exists, B→A should too
- Strength 0.1-0.5: Slow oscillation
- Strength 0.5-1.0: Fast oscillation
- Creates superposition states

### Lindblad Operators
- Create **irreversible flow** (classical dissipation)
- Asymmetric: A→B doesn't require B→A
- Models decay, transfer, consumption
- Strength 0.01-0.1: Slow decay
- Strength 0.1-0.5: Fast decay

### Gated Lindblad (Advanced)
- Lindblad that only activates when a gate emoji is present
- Use for conditional mechanics

```gdscript
f.gated_lindblad = {
    "wheat": [
        {"target": "bread", "rate": 0.2, "gate": "fire", "inverse": false}
    ]
}
# wheat → bread only when fire is present
```

---

## Theming Guidelines

### DO:
- Pick 1-2 core mechanics per faction
- Make the mechanic match the faction's lore
- Use emojis that feel thematically coherent
- Keep operators simple

### DON'T:
- Add more than 3 Hamiltonian couplings
- Add more than 3 Lindblad operators
- Make complex conditional chains
- Duplicate mechanics from other factions

### Ring-Specific Theming

**CENTER (boring, stable):**
- Simple production/consumption cycles
- Straightforward resource conversion
- Predictable behavior
- Example: Granary Guilds just makes wheat→bread work

**FRINGE (interesting, trade-offs):**
- Some instability
- Negative self-energies for risky resources
- Conditional mechanics
- Example: Bone Merchants - death creates value

**OUTER (weird, dangerous):**
- Strong negative energies
- Destructive Lindblad operators
- Reality-bending coherences
- Example: Void Emperors - everything decays to nothing

---

## Example: Building "Tinker Team"

From FactionDatabaseV2:
```
"name": "Tinker Team",
"sig": ["🧰", "🪛", "🔌", "♻️", "🚐"],
"motto": "If it breaks, we fix it better.",
"ring": "center"
```

Implementation:
```gdscript
static func create_tinker_team() -> Faction:
    var f = Faction.new()
    f.name = "Tinker Team"
    f.ring = "center"
    f.signature = ["🧰", "🪛", "🔌", "♻️", "🚐"]

    # Tools are stable
    f.self_energies = {
        "🧰": 0.3,
        "🪛": 0.2,
    }

    # Recycling loop: broken stuff ↔ fixed stuff
    f.hamiltonian_couplings = {
        "♻️": {"🔌": 0.2},  # Recycling restores power
    }

    # Tools slowly wear out
    f.lindblad_operators = {
        "🧰": {"♻️": 0.05},  # Tools become recyclables
    }

    return f
```

---

## Verification

After building a faction:

1. Run the game and check `IconRegistry` loads without errors
2. Check the faction's quests are accessible (if player has vocabulary overlap)
3. Observe the biome to see if the operators create interesting dynamics

---

## Files to Create/Modify

- `Core/Factions/Tier3Factions.gd` - New file for additional center/fringe factions
- `Core/Factions/OuterFactions.gd` - New file for outer ring factions
- `Core/Factions/AllFactions.gd` - Register new faction groups

---

## Final Notes

Remember: **The game's complexity comes from faction COLLISION, not from individual faction design.**

If faction A produces 🌾 and faction B consumes 🌾, that's interesting.
If faction A has 17 operators and gated conditions and drivers... that's a mess.

Keep it simple. One faction = one idea. Let the quantum bath do the mixing.
