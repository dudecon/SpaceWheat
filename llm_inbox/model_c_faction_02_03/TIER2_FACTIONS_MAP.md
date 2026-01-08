# SpaceWheat Tier 2 Factions - Cross-Coupling Map

## Branch Structure

```
                    STARTER FACTIONS
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
    Granary Guilds  Millwright's   Carrion Throne
         💰             ⚙              ⚖
          │              │              │
          ▼              ▼              ▼
    ┌─────┴─────┐   ┌────┴────┐   ┌────┴────┐
    │ COMMERCE  │   │INDUSTRY │   │GOVERNANCE│
    └───────────┘   └─────────┘   └──────────┘
```

---

## TIER 2A: Commerce Branch (from 💰)

| Faction | Ring | Signature | Key Mechanic |
|---------|------|-----------|--------------|
| **Ledger Bailiffs** | first | ⚖💰📒📘🚔 | Extracts wealth GATED on 📘 law |
| **Gilded Legacy** | first | ⛏💎💰✨ | Mining, patient wealth, very slow decay |
| **Quay Rooks** | second | 🚢⚓💰🪝 | Port authority, dock operations |
| **Bone Merchants** | second | 🦴💉🔧💰 | Grey market body modifications |

### Commerce Flow
```
         ⛏ mining          🚢 shipping
            │                    │
            ▼                    ▼
           💎 gems          ⚓ ports
            │                    │
            └────────┬───────────┘
                     ▼
                    💰 wealth
                     │
            ┌────────┴────────┐
            ▼                 ▼
      📒 ledger           🦴 body mods
      (extraction)        (grey market)
```

---

## TIER 2B: Industry Branch (from ⚙)

| Faction | Ring | Signature | Key Mechanic |
|---------|------|-----------|--------------|
| **Kilowatt Collective** | center | 🔋🔌⚙⚡ | **AC circuit clock signal** (1 Hz sine) |
| **Gearwright Circle** | center | ⚙🛠🔩🧰🏷️ | Produces ⚙ gears, 🏷️ certification |
| **Rocketwright Institute** | first | 🚀🔬⚙📋 | Produces 🚀 GATED on 📋 approval |

### The AC Circuit Clock (Kilowatt Collective)
```
      ⚡ lightning
         │
         │ charges (0.06/s)
         ▼
       🔋 battery ◄──── storage
         │
         │ drains (0.04/s)
         ▼
       🔌 plug ◄──── SINE DRIVER @ 1 Hz
         │
         │ outputs (0.03/s)
         ▼
       ⚡ to grid

The 🔌 oscillates at 1 Hz, creating a clock signal.
Players can entangle systems to the grid for synchronization.
```

### Industry Flow
```
    Gearwright Circle        Kilowatt Collective
         🔩 parts                 ⚡ power
            │                        │
            ▼                        ▼
           ⚙ gears ◄────────────► 🔋 battery
            │                        │
       ┌────┴────┐                   │
       ▼         ▼                   ▼
     🏭 factory  🚀 rockets ◄──── 🔌 grid
                  │
                  │ GATED on 📋
                  ▼
            Rocketwright Institute
```

---

## TIER 2C: Governance Branch (from ⚖)

| Faction | Ring | Signature | Key Mechanic |
|---------|------|-----------|--------------|
| **Irrigation Jury** | center | 🌱💧⚖🪣 | Controls 💧, GATES agriculture |
| **Indelible Precept** | first | 📋💳⚖📜 | Creates 💳 identity, processes 📜 |
| **House of Thorns** | second | 🌹🪞🍷⚖ | HUB faction, aristocratic politics |

### Governance Flow
```
              Carrion Throne
                   🏰
                    │
                   📜 edicts
                    │
         ┌──────────┼──────────┐
         ▼          ▼          ▼
   Irrigation    Indelible    House of
      Jury        Precept      Thorns
        │            │            │
       💧           💳          🍷
     (water)     (identity)   (luxury)
        │            │            │
        ▼            ▼            ▼
   Agriculture   Population   Influence
      🌱🌾           👥         ⚜🏛
```

### Water Law
```
Irrigation Jury controls water allocation:

     💧 water ─────┐
        │         │
    GATED on ⚖   │
        │         │
        ▼         ▼
       🌱        🔥 (suppression)
    seedling      │
        │         │
        ▼         ▼
       🌾        💀 (fire death)
     wheat
```

---

## New Emojis Summary

| Emoji | Faction | Role |
|-------|---------|------|
| 📒 | Ledger Bailiffs | Debt ledger |
| 🚔 | Ledger Bailiffs | Enforcement |
| ⛏ | Gilded Legacy | Mining |
| 💎 | Gilded Legacy | Gems |
| ✨ | Gilded Legacy | Refined value |
| ⚓ | Quay Rooks | Port anchor |
| 🪝 | Quay Rooks | Dock hooks |
| 🦴 | Bone Merchants | Skeletal mods |
| 💉 | Bone Merchants | Biological mods |
| 🔋 | Kilowatt | Battery |
| 🔌 | Kilowatt | **SINE DRIVER @ 1 Hz** |
| ⚡ | Kilowatt | Power |
| 🏷️ | Gearwright | Certification tag |
| 🚀 | Rocketwright + Station Lords | Space vehicle |
| 🔬 | Rocketwright | Research |
| 🪣 | Irrigation | Water bucket |
| 💳 | Indelible | Identity card |
| 🌹 | House of Thorns | Beauty/danger |
| 🪞 | House of Thorns | Mirror/truth |
| 🍷 | House of Thorns | Wine/avarice |

---

## Cross-Branch Connections

### Commerce ↔ Industry
```
Gearwright ─── ⚙ ───→ Bone Merchants (🔧 surgical tools)
Kilowatt ───── ⚡ ───→ Rocketwright (power for 🚀)
```

### Commerce ↔ Governance
```
Ledger Bailiffs ← 📘 ─── Station Lords (law enables extraction)
Gilded Legacy ←── 💰 ───→ House of Thorns (wealth buys 🍷)
```

### Industry ↔ Governance
```
Rocketwright ─── 🚀 ───→ Station Lords (space gateway)
Gearwright ──── ⚙ ────→ Irrigation (machinery)
Kilowatt ────── ⚡ ────→ All (power grid)
```

---

## Gated Dependencies

### Production Gates
| Output | Source | Gate | Faction |
|--------|--------|------|---------|
| 💰 | 👥 | 📘 | Ledger Bailiffs |
| 💸 | 👥 | 📒 | Ledger Bailiffs |
| 🦴 | 👥 | 🔧 | Bone Merchants |
| 🚀 | 🔬 | 📋 | Rocketwright |
| 🚀 | ⚙ | 📋 | Rocketwright |
| 🚢 | 💰 | ⚓ | Quay Rooks |
| 🌱 | 💧 | ⚖ | Irrigation Jury |
| 🌾 | 💧 | ⚖ | Irrigation Jury |

---

## Alignment Summary

### Fire Vulnerabilities (bureaucracy burns)
| Icon | 🔥 Effect |
|------|----------|
| 📒 | -0.25 |
| 📋 | -0.30 |
| 🏢 | -0.30 |

### Order Alignments
| Icon | 🏛 Effect |
|------|----------|
| 📒 | +0.20 |
| 💰 | +0.20 |
| 📋 | +0.25 |
| ⚖ | +0.20 |
| 🌹 | +0.15 |

### Water Alignments
| Icon | 💧 Effect |
|------|----------|
| 🚢 | +0.20 |
| 🔌 | -0.20 (shorts!) |
| 🌹 | +0.15 |
| 📋 | -0.15 (damages) |

---

## Station Lords Update

Station Lords now includes 🚀 as the gateway between terrestrial and space:

```
Signature: [👥, 🚢, 🚀, 🛂, 📜, 🏢, 📘]

Terrestrial commerce: 🚢 ⚓ (boats, ports)
Space commerce:       🚀 (rockets)
Gateway:              🛂 (passport control)

The Station Lords control both sea and space transit.
Rocketwright Institute produces the 🚀 they regulate.
```

---

## Future Connections (noted for later)

### House of Thorns → Horror
```
🍷 wine ── 🌑 ──→ Laughing Court (future)
          (avarice leads to darkness)
```

### Bone Merchants → Flesh Architects
```
🦴 body mods ── ??? ──→ Flesh Architects (outer ring horror)
                       (grey market → horror cult)
```

### Irrigation Jury → Fire Suppression
```
💧 water ──→ 🔥 fire (lindblad_out: 0.08)
            (jury can suppress wildfires)
```
