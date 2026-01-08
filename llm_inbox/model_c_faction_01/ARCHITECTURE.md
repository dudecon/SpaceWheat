# SpaceWheat Faction → Icon Architecture

## Core Principle

```
┌─────────────────────────────────────────────────────────────────┐
│  FACTION = Closed dynamical system over 3-7 signature emojis   │
│                                                                 │
│  • Faction couplings ONLY between signature emojis              │
│  • One emoji can belong to MULTIPLE factions                    │
│  • Icon = ADDITIVE union of all faction contributions           │
│  • Contested emojis (👥, 🍂, 🌿) get dense coupling terms       │
│  • Alignment couplings create parametric cross-faction effects  │
│                                                                 │
│  BIOME = Union of 2-3 factions + cross-faction couplings        │
│        = 6-18 emojis → RegisterMap assigns qubits               │
└─────────────────────────────────────────────────────────────────┘
```

## The 7 Core Factions (v2)

| Faction | Ring | Signature | Internal Dynamics |
|---------|------|-----------|-------------------|
| **Celestial Archons** | outer | ☀️🌙⛰️💧🌬️ | Abiotic drivers: day/night, weather, water cycle |
| **Verdant Pulse** | center | 🌱🌿🌾🌲🍂 | Growth + Trees: seed→veg/tree→grain→decay |
| **Mycelial Web** | center | 🍄🍂🌙 | Moon-linked decomposition |
| **Swift Herd** | center | 🐇🦌🌿 | Grazing dynamics, population growth |
| **Pack Lords** | second | 🐺🦅🐇🦌💀 | Predation, death cycle |
| **Market Spirits** | second | 🐂🐻💰📦🏛️🏚️ | Bull/bear oscillation, order/chaos |
| **Hearth Keepers** | center | 🔥❄️💧🏜️💨🍞 | Temp × moisture × substance |

## Shared Emojis (Contested Dynamics)

These emojis belong to multiple factions, creating rich interaction:

| Emoji | Factions | Emergent Dynamics |
|-------|----------|-------------------|
| 🌙 | Celestial + Mycelial | Moon drives both night cycle AND decomposition |
| 🍂 | Verdant + Mycelial | Plant death feeds fungal growth |
| 🌿 | Verdant + Swift | Vegetation grows AND gets grazed |
| 🐇 | Swift + Pack | Rabbits reproduce AND get eaten |
| 🦌 | Swift + Pack | Deer graze AND get hunted |
| 💧 | Celestial + Hearth | Water: weather AND cooking ingredient |

## Alignment Couplings (NEW)

Alignment couplings are **parametric effects** where one emoji's rates scale based on another emoji's probability:

```
effective_rate(🌾) = base_rate * (1 + alignment(☀️) * P(☀️))
```

Examples:
- **🌾 aligned to ☀️ (+0.08)**: Wheat grows faster when sun is high
- **🍄 aligned to 🌙 (+0.40)**: Mushrooms thrive at night
- **🍄 aligned to ☀️ (-0.20)**: Mushrooms suppressed by sunlight

This creates **day/night niches** without complex driver logic.

## File Structure

```
Core/Factions/
├── Faction.gd         # Faction class definition
├── CoreFactions.gd    # The 7 core factions
├── IconBuilder.gd     # Merges factions → Icons
└── test_factions.gd   # Demo script
```

## Usage

### Building Icons for a Biome

```gdscript
# Option 1: Use preset
var forest_icons = IconBuilder.build_forest_biome()

# Option 2: Custom composition
var factions = [
    CoreFactions.create_celestial_archons(),
    CoreFactions.create_verdant_pulse(),
    CoreFactions.create_mycelial_web(),
]

# Cross-faction couplings (where faction boundaries interact)
var cross = [
    {"source": "🌾", "target": "☀", "type": "lindblad_in", "rate": 0.027},
]

var icons = IconBuilder.build_biome_icons(factions, cross)
```

### Registering with IconRegistry

```gdscript
# In your biome initialization
var icons = IconBuilder.build_forest_biome()
for emoji in icons:
    IconRegistry.register_icon(icons[emoji])
```

## Example: 🍂 Icon (Contested)

The 🍂 emoji belongs to both Verdant Pulse and Mycelial Web:

```
From Verdant Pulse:
  - H coupling to 🌿: 0.4 (nutrient return)
  - H coupling to 🌾: 0.5 (wheat draws nutrients)
  - H coupling to 🌱: 0.3 (feeds new growth)
  - L incoming from 🌿: 0.04
  - L incoming from 🌾: 0.02

From Mycelial Web:
  - H coupling to 🍄: 0.5 (feeds mushrooms)
  - H coupling to 🌙: (indirect, through 🍄)
  - L outgoing to 🍄: 0.12 (rapid decomposition)

MERGED Icon:
  - self_energy: 0.0 (ground state)
  - H couplings: {🌿: 0.4, 🌾: 0.5, 🌱: 0.3, 🍄: 0.5}
  - L incoming: {🌿: 0.04, 🌾: 0.02}
  - L outgoing: {🍄: 0.12}
  - description: "Contested by: Verdant Pulse, Mycelial Web"
```

## Adding New Factions

To add a faction from the v2.1 lexicon:

```gdscript
static func create_irrigation_jury() -> Faction:
    var f = Faction.new()
    f.name = "Irrigation Jury"
    f.ring = "center"
    f.signature = ["🌱", "💧", "⚖️", "🪣"]
    
    f.hamiltonian = {
        "💧": {"🌱": 0.6, "🪣": 0.4},
        "🌱": {"💧": 0.6},
        "⚖️": {"💧": 0.3, "🌱": 0.3},
        "🪣": {"💧": 0.4},
    }
    
    # Water-parametric growth (the key Irrigation Jury mechanic)
    f.lindblad_incoming = {
        "🌱": {"💧": 0.08},  # Growth rate scales with water
    }
    
    return f
```

Then 🌱 would get contributions from BOTH Verdant Pulse AND Irrigation Jury.

## Cross-Faction Coupling Philosophy

Factions define **internal** dynamics only. Cross-faction couplings are added at biome composition time:

```gdscript
# This coupling crosses Verdant → Hearth faction boundary
{"source": "💨", "target": "🌾", "type": "lindblad_in", "rate": 0.08}
# Flour (Hearth) gains from Wheat (Verdant)
```

This keeps factions modular and reusable while allowing biomes to define how factions interact.

## The 👥 Emoji (Future)

When we add civilizational factions, 👥 (labor/population) will be claimed by:
- Carrion Throne (bureaucratic extraction)
- Granary Guilds (bread production)
- Irrigation Jury (canal labor)
- Iron Shepherds (military protection)
- etc.

The 👥 Icon will have **dozens** of coupling terms, making it the most contested resource in the game. This is intentional - labor is what everyone wants.

## Next Steps

1. **Test**: Run the demo script to verify dynamics
2. **Integrate**: Replace CoreIcons.gd with IconBuilder calls
3. **Expand**: Add Granary Guilds, Irrigation Jury, Yeast Prophets
4. **Tune**: Adjust rates based on gameplay testing
5. **Document**: Update ALL_ICONS_INVENTORY.md from new system
