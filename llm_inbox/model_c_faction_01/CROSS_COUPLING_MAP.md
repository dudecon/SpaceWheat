# SpaceWheat Cross-Coupling Map

## Updated Faction Signatures (v3)

```
CORE FACTIONS (7 original):
Celestial Archons: ☀️  🌙  🔥  💧  ⛰️  🌬️   (6 - elements + luminaries)
Verdant Pulse:     🌱  🌿  🌾  🌲  🍂        (5 - plant cycle + trees)
Mycelial Web:          🌙      🍂  🍄  💀   (4 - decomposition + death link)
Swift Herd:            🌿          🐇  🦌   (3 - herbivores)
Pack Lords:                        🐇  🦌  🐺  🦅  💀 (5 - predators + death)
Market Spirits:    🐂  🐻  💰  📦  🏛️  🏚️   (6 - economy)
Hearth Keepers:    🔥  ❄️  💧  🏜️  💨  🍞   (6 - production)

NEW FACTIONS (3):
Pollinator Guild:  🐝  🌿  🌾  🌱            (4 - critical bottleneck)
Plague Vectors:    🦠  🐇  🌾  🐝  💀        (5 - density-dependent disease)
Wildfire:          🔥  🌿  🌲  🍂  🌬️        (5 - destruction/renewal)
```

---

## NEW: Gated Lindblad (Multiplicative Dependencies)

Unlike regular Lindblad (additive rates), **gated Lindblad** creates hard dependencies:

```
effective_rate = base_rate × P(gate)^power
```

When P(gate) = 0, the transfer **stops entirely**.

### Pollinator Gating

| Target | Source | Base Rate | Gate | Power | Effect |
|--------|--------|-----------|------|-------|--------|
| 🌾 | 🌿 | 0.05 | 🐝 | 1.0 | No pollinators = no grain from vegetation |
| 🌾 | 🌱 | 0.03 | 🐝 | 0.8 | Seeds need less pollination |

**Gameplay**: If 🐝 population crashes (disease, fire), grain production halts even with abundant sun/water/vegetation.

### Disease Gating

| Target | Source | Base Rate | Gate | Power | Effect |
|--------|--------|-----------|------|-------|--------|
| 💀 | 🐇 | 0.12 | 🦠 | 1.5 | Rabbits die to disease (superlinear!) |
| 💀 | 🌾 | 0.10 | 🦠 | 1.2 | Wheat dies to blight |
| 💀 | 🐝 | 0.15 | 🦠 | 1.5 | Colony collapse (very vulnerable) |

**Gameplay**: Disease appears when populations get dense, crashes them, then burns out. Prevents monoculture.

### Wildfire Gating

| Target | Source | Base Rate | Gate | Power | Effect |
|--------|--------|-----------|------|-------|--------|
| 🍂 | 🌿 | 0.20 | 🔥 | 1.2 | Vegetation burns to ash (accelerates) |
| 🍂 | 🌲 | 0.08 | 🔥 | 1.0 | Trees burn slower |

**Gameplay**: Fire spreads when 🍂 (dry fuel) is high. Burns everything to ash, then dies out. Ash → mushroom bloom.

---

## Emergent Gameplay Loops

### The Burn-Flood-Mushroom Exploit
```
1. Let 🍂 accumulate (don't harvest dead material)
2. Introduce 🔥 (or let it spread)
3. Fire consumes 🌿🌲 → massive 🍂 (ash)
4. Dump 💧 on the ash
5. 🍄 explodes (🍄 aligned to 💧 +0.35, fed by 🍂)
6. Harvest mushrooms!
```

### The Pollinator Collapse Cascade
```
1. High 🐝 population → high 🌾 production
2. High 🌾 density → 🦠 blight appears
3. 🦠 spreads to 🐝 (colony collapse, rate 0.15)
4. 🐝 crashes → 🌾 production stops (gated!)
5. 🦠 burns out (no more hosts)
6. Slow 🐝 recovery...
```

### The Fire Containment Challenge
```
Fire alignment:
  🌬️: +0.30 (wind spreads fire)
  🍂: +0.40 (fuel intensifies fire)
  💧: -0.50 (water suppresses fire)

Strategy: Keep 💧 high near valuable crops.
          Clear 🍂 regularly (composting).
          Build firebreaks (gaps with no 🌿🌲).
```

---

## Complete Forest Biome (v3)

### Emojis: 21 total
```
Celestial:   ☀️ 🌙 🔥 💧 ⛰️ 🌬️
Verdant:     🌱 🌿 🌾 🌲 🍂
Mycelial:    🍄 (+ shared 🌙 🍂 💀)
Swift:       🐇 🦌 (+ shared 🌿)
Pack:        🐺 🦅 💀 (+ shared 🐇 🦌)
Pollinator:  🐝 (+ shared 🌿 🌾 🌱)
Plague:      🦠 (+ shared 🐇 🌾 🐝 💀)
Wildfire:    (shared 🔥 🌿 🌲 🍂 🌬️)
```

### Shared Emoji Density

| Emoji | Factions | Contestation Level |
|-------|----------|-------------------|
| 💀 | Pack + Mycelial + Plague | HIGH - death gateway |
| 🍂 | Verdant + Mycelial + Wildfire | HIGH - nutrient/fuel hub |
| 🌿 | Verdant + Swift + Pollinator + Wildfire | VERY HIGH - vegetation contested |
| 🐇 | Swift + Pack + Plague | HIGH - prey + disease vector |
| 🌾 | Verdant + Pollinator + Plague | HIGH - agriculture hub |
| 🐝 | Pollinator + Plague | MEDIUM - critical but vulnerable |
| 🔥 | Celestial + Wildfire (+ Hearth) | MEDIUM - element + destruction |

---

## Alignment Coupling Summary

| Icon | Observable | Alignment | Emergent Niche |
|------|------------|-----------|----------------|
| 🍄 | 🌙 | +0.40 | Nocturnal emergence |
| 🍄 | 💧 | +0.35 | Wet conditions bloom |
| 🍄 | ☀️ | -0.35 | Daylight withering |
| 🔥 | 🌬️ | +0.30 | Wind spreads fire |
| 🔥 | 🍂 | +0.40 | Fuel intensifies |
| 🔥 | 💧 | -0.50 | Water suppresses |
| 🐝 | ☀️ | +0.15 | Daytime activity |
| 🐝 | 💧 | -0.10 | Rain suppresses |
| 🦠 | 🐇 | +0.30 | Density enables disease |
| 🦠 | 🌾 | +0.25 | Monoculture blight |
| 🦠 | 🐝 | +0.35 | Colony collapse risk |
| 🦠 | 🌬️ | -0.20 | Wind disperses disease |

---

## Cross-Coupling Matrix

### Shared Emojis (Automatic Merging)

| Emoji | Factions | Coupling Type |
|-------|----------|---------------|
| 🌙 | Celestial + Mycelial | Moon drives both day/night AND mushroom emergence |
| 🍂 | Verdant + Mycelial | Organic matter: plants decay into it, fungi consume it |
| 🌿 | Verdant + Swift | Vegetation: grows AND gets grazed |
| 🐇 | Swift + Pack | Rabbits: reproduce AND get eaten |
| 🦌 | Swift + Pack | Deer: graze AND get hunted |
| 💧 | Celestial + Hearth | Water: weather cycle AND cooking ingredient |

---

### Explicit Cross-Faction Couplings (Forest Biome)

#### Celestial → Verdant (Sun/Water Drive Plant Growth)

| Source | Target | Type | Rate | Effect |
|--------|--------|------|------|--------|
| 🌾 | ☀️ | lindblad_in | 0.027 | Wheat gains from sunlight |
| 🌿 | ☀️ | lindblad_in | 0.05 | Vegetation gains from sun |
| 🌱 | ☀️ | lindblad_in | 0.03 | Seedlings gain from sun |
| 🌲 | ☀️ | lindblad_in | 0.02 | Trees gain from sun (slow) |
| 🌾 | 💧 | lindblad_in | 0.017 | Wheat gains from water |
| 🌿 | 💧 | lindblad_in | 0.04 | Vegetation gains from water |
| 🌱 | 💧 | lindblad_in | 0.05 | Seedlings need water most |
| 🌲 | 💧 | lindblad_in | 0.015 | Trees need water |
| 🌾 | ⛰️ | lindblad_in | 0.007 | Wheat draws from soil |
| 🌿 | ⛰️ | lindblad_in | 0.02 | Vegetation draws from soil |
| 🌲 | ⛰️ | lindblad_in | 0.025 | Trees have deep roots |

#### Celestial → Mycelial (Moon Drives Mushrooms)

| Source | Target | Type | Rate | Effect |
|--------|--------|------|------|--------|
| 🍄 | 🌙 | lindblad_in | 0.06 | Mushrooms emerge under moon |

#### Pack → Mycelial (Death Feeds Decomposition)

| Source | Target | Type | Rate | Effect |
|--------|--------|------|------|--------|
| 🍂 | 💀 | lindblad_in | 0.08 | Death becomes organic matter |

#### Hamiltonian Cross-Couplings (Coherent Awareness)

| Source | Target | Coupling | Effect |
|--------|--------|----------|--------|
| 🌾 | ☀️ | 0.5 | Wheat resonates with sun |
| 🌾 | 💧 | 0.4 | Wheat senses water |
| 🌿 | ☀️ | 0.6 | Vegetation strongly couples to sun |
| 🌿 | 💧 | 0.5 | Vegetation couples to water |
| 🌲 | ☀️ | 0.4 | Trees couple to sun |
| 🌲 | 💧 | 0.3 | Trees couple to water |

---

### Alignment Couplings (Parametric Effects)

These are **multiplicative modifiers** — when P(observable) is high, the icon's rates are scaled.

#### Verdant Pulse → Celestial Alignment

| Icon | Observable | Alignment | Effect |
|------|------------|-----------|--------|
| 🌱 | ☀️ | +0.06 | Seedlings grow faster in sun |
| 🌱 | 💧 | +0.08 | Seedlings need water most |
| 🌱 | ⛰️ | +0.03 | Soil helps seedlings |
| 🌿 | ☀️ | +0.10 | Vegetation thrives in sun |
| 🌿 | 💧 | +0.06 | Water helps vegetation |
| 🌿 | ⛰️ | +0.02 | Soil helps vegetation |
| 🌾 | ☀️ | +0.08 | Wheat loves sun |
| 🌾 | 💧 | +0.05 | Water helps wheat |
| 🌾 | ⛰️ | +0.04 | Wheat draws from soil |
| 🌲 | ☀️ | +0.04 | Trees like sun but hardy |
| 🌲 | 💧 | +0.03 | Trees need water |
| 🌲 | ⛰️ | +0.05 | Deep roots help trees |

#### Mycelial Web → Celestial Alignment

| Icon | Observable | Alignment | Effect |
|------|------------|-----------|--------|
| 🍄 | 🌙 | +0.40 | **Strong** — mushrooms thrive at night |
| 🍄 | ☀️ | -0.20 | **Negative** — sun suppresses mushrooms |

---

## Complete Forest Biome Flow Diagram

```
                     CELESTIAL ARCHONS
           ┌─────────────────────────────────────┐
           │  ☀️ ←──0.8──→ 🌙                    │
           │   │           │                     │
           │  0.4        0.5                     │
           │   ↓           ↓                     │
           │  💧 ←──0.6──→ 🌬️                    │
           │   │                                 │
           │  0.4                                │
           │   ↓                                 │
           │  ⛰️                                 │
           └───┬───────────┬─────────────────────┘
               │           │
    ┌──────────┼───────────┼──────────┐
    │          │ LINDBLAD  │          │
    │          ↓           ↓          │
    │   ┌──────────────────────────┐  │
    │   │     VERDANT PULSE        │  │
    │   │                          │  │
    │   │  🌱 ──0.06→ 🌿           │  │
    │   │   │                      │  │
    │   │  0.02↓     ↓0.04         │  │
    │   │   🌲       🌾            │  │
    │   │   │         │            │  │
    │   │  0.005    0.02           │  │
    │   │   ↓         ↓            │  │
    │   │   └────→ 🍂 ←────┘       │  │
    │   └──────────┬───────────────┘  │
    │              │                  │
    │         (shared 🍂)             │
    │              │                  │
    │   ┌──────────▼───────────────┐  │
    │   │     MYCELIAL WEB         │  │
    │   │                          │  │
    │   │      🌙 (shared)         │  │
    │   │       │                  │  │
    │   │      0.6                 │  │
    │   │       ↓                  │  │
    │   │  🍂 ←──0.12── 🍄         │  │
    │   │   │                      │  │
    │   └───┼──────────────────────┘  │
    │       │                         │
    │  (💀 feeds 🍂)                  │
    │       │                         │
    │   ┌───▼──────────────────────┐  │
    │   │     PACK LORDS           │  │
    │   │                          │  │
    │   │  🐺 ←─0.15── 🐇 (shared) │  │
    │   │   │           ↑          │  │
    │   │  0.12        0.10        │  │
    │   │   ↓           │          │  │
    │   │  🦌 ←────────┼── 🌿      │  │
    │   │   │          │  (Swift)  │  │
    │   │   ↓          │           │  │
    │   │  💀 ─────────┘           │  │
    │   │                          │  │
    │   └──────────────────────────┘  │
    │                                 │
    │         SWIFT HERD              │
    │   (🐇, 🦌 consume 🌿)           │
    └─────────────────────────────────┘
```

---

## Kitchen Biome Cross-Couplings

#### Verdant → Hearth (Wheat becomes Flour)

| Source | Target | Type | Rate | Effect |
|--------|--------|------|------|--------|
| 💨 | 🌾 | lindblad_in | 0.08 | Mill converts wheat to flour |

---

## Summary: All Cross-Faction Interactions

| From Faction | To Faction | Via Emoji | Coupling Type |
|--------------|------------|-----------|---------------|
| Celestial | Verdant | ☀️💧⛰️ | Lindblad + Alignment |
| Celestial | Mycelial | 🌙 | Shared + Alignment |
| Verdant | Mycelial | 🍂 | Shared |
| Verdant | Swift | 🌿 | Shared |
| Swift | Pack | 🐇🦌 | Shared |
| Pack | Mycelial | 💀→🍂 | Explicit Lindblad |
| Verdant | Hearth | 🌾→💨 | Explicit Lindblad |
| Celestial | Hearth | 💧 | Shared |

---

## Design Notes

### The 🌲 Tree Endpoint
Seeds (🌱) that aren't consumed have two fates:
- Fast path: 🌱 → 🌿 (vegetation, 0.06 rate)
- Slow path: 🌱 → 🌲 (tree, 0.02 rate)

Trees are **stable reservoirs** — they decay very slowly (0.005) and represent accumulated ecological capital.

### The ☀️↔🌾 Alignment Effect
The alignment coupling means:
```
effective_growth_rate(🌾) = base_rate * (1 + alignment * P(☀️))
```
When P(☀️) ≈ 1 (daytime), wheat grows ~8% faster.
When P(☀️) ≈ 0 (nighttime), wheat grows at base rate.

### The 🌙↔🍄 Opposition
Mushrooms have:
- Positive alignment to 🌙 (+0.40)
- Negative alignment to ☀️ (-0.20)

This creates a **day/night niche**: mushrooms thrive at night, wither in daylight.

### The 💀→🍂 Death Cycle
Pack Lords own death (💀). When predators kill prey, probability flows to 💀.
Then 💀 feeds into 🍂 (organic matter), which Mycelial Web consumes.

This is the **nutrient cycle**: animals → death → organic matter → fungi → (back to soil).
