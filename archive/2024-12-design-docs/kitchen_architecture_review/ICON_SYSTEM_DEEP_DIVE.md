# Icon System: How Icons Compose to Create Biomes

**Purpose**: Understand how Icons (emoji-based Hamiltonian definitions) compose together to create emergent biome behavior through quantum evolution

---

## Overview: Icons are the Verbs

### Core Philosophy

> **Icons are the eternal Hamiltonians attached to an emoji. They define how this emoji interacts with others in any biome. Icons are the VERBS of the quantum universe.**

Each emoji (🌾 wheat, 🌙 moon, 🍄 mushroom, etc.) has an associated **Icon** resource that defines:
1. **Unitary evolution** - How it oscillates with other emojis (Hamiltonian terms)
2. **Dissipative evolution** - How it transfers population to other emojis (Lindblad terms)
3. **External forcing** - Time-dependent driving (day/night cycles)
4. **Decay & growth** - Spontaneous transfers and drains

### The Icon Architecture

```
Icon (Resource)
├─ Hamiltonian terms (unitary evolution)
│  ├─ self_energy: diagonal element H[i,i]
│  └─ hamiltonian_couplings: off-diagonal H[i,j]
├─ Lindblad terms (dissipative evolution)
│  ├─ lindblad_outgoing: transfers to other emojis
│  ├─ lindblad_incoming: receives from other emojis
│  └─ decay_rate: spontaneous decay to sink
├─ Energy taps
│  ├─ is_drain_target: Can this be tapped?
│  └─ drain_to_sink_rate: Drain strength κ
├─ Bath-projection couplings
│  └─ energy_couplings: Response to other emojis
└─ Metadata
   ├─ trophic_level: 0=abiotic, 1=producer, 2=consumer, 3=predator
   ├─ tags: ["celestial", "driver", "eternal", etc.]
   └─ Behavioral flags: is_driver, is_adaptive, is_eternal
```

---

## Part 1: The Icon Definition

### Icon Class Structure

**File**: `Core/QuantumSubstrate/Icon.gd` (155 lines)

```gdscript
class_name Icon
extends Resource

# Identity
@export var emoji: String = ""
@export var display_name: String = ""
@export var description: String = ""

# Hamiltonian terms (unitary evolution)
@export var self_energy: float = 0.0
@export var hamiltonian_couplings: Dictionary = {}  # emoji → coupling_strength

# Time-dependent driving
@export var self_energy_driver: String = ""  # "cosine", "sine", "pulse", or ""
@export var driver_frequency: float = 0.0    # Hz (cycles per second)
@export var driver_phase: float = 0.0        # Radians
@export var driver_amplitude: float = 1.0

# Lindblad terms (dissipative evolution)
@export var lindblad_outgoing: Dictionary = {}  # emoji → transfer_rate_γ
@export var lindblad_incoming: Dictionary = {}  # emoji → transfer_rate_γ
@export var decay_rate: float = 0.0
@export var decay_target: String = "🍂"

# Energy tap configuration
@export var is_drain_target: bool = false
@export var drain_to_sink_rate: float = 0.0

# Bath-projection couplings
@export var energy_couplings: Dictionary = {}  # observable_emoji → coupling_strength

# Metadata
@export var trophic_level: int = 0
@export var tags: Array[String] = []
@export var is_driver: bool = false      # External forcing (like sun)
@export var is_adaptive: bool = false    # Dynamically changes
@export var is_eternal: bool = false     # Never decays
```

### Example: The Sun Icon (Celestial Driver)

From `CoreIcons.gd`:

```gdscript
var sun = Icon.new()
sun.emoji = "☀"
sun.display_name = "Sol"
sun.description = "The eternal light that drives all life"

# Hamiltonian: self-oscillation + couplings
sun.self_energy = 1.0
sun.self_energy_driver = "cosine"  # Day/night cycle
sun.driver_frequency = 0.05        # Hz (5% of frame rate)
sun.driver_amplitude = 1.0
sun.hamiltonian_couplings = {
    "🌙": 0.8,   # Couples to moon (opposition)
    "🌿": 0.3,   # Couples to vegetation
    "🌾": 0.4,   # Couples to wheat
    "🌱": 0.3    # Couples to seedlings
}

# Tags & metadata
sun.tags = ["celestial", "driver", "light", "eternal"]
sun.is_driver = true
sun.is_eternal = true  # Never decays
```

### Example: Wheat Icon (Producer)

```gdscript
var wheat = Icon.new()
wheat.emoji = "🌾"
wheat.display_name = "Wheat"
wheat.description = "The golden grain, sustainer of civilizations"

# Hamiltonian: Growth interactions
wheat.self_energy = 0.1
wheat.hamiltonian_couplings = {
    "☀": 0.5,   # Couples to sun
    "💧": 0.4,  # Couples to water
    "⛰": 0.3    # Couples to soil
}

# Lindblad: Growth transfers (in amplitude/sec)
wheat.lindblad_incoming = {
    "☀": 0.00267,  # Grows from sunlight
    "💧": 0.00167, # Grows from water
    "⛰": 0.00067  # Draws from soil
}

# Decay
wheat.decay_rate = 0.02
wheat.decay_target = "🍂"  # Decays to organic matter

# Energy couplings for bath projection
wheat.energy_couplings = {
    "☀": +0.08,  # Gains energy from sun
    "💧": +0.05  # Gains energy from water
}

wheat.trophic_level = 1  # Producer
wheat.tags = ["flora", "crop", "edible"]
```

---

## Part 2: Icon Registry - The Central Catalog

### How Icons Are Registered

**File**: `Core/QuantumSubstrate/IconRegistry.gd`

```gdscript
extends Node

# Preload CoreIcons module
const CoreIcons = preload("res://Core/Icons/CoreIcons.gd")

# Dictionary mapping emoji → Icon resource
var icons: Dictionary = {}

func _ready():
    print("📜 IconRegistry initializing...")
    _load_builtin_icons()  # Calls CoreIcons.register_all()
    print("📜 IconRegistry ready: %d icons registered" % icons.size())

func register_icon(icon: Icon) -> void:
    """Register an Icon by its emoji"""
    if icon == null or icon.emoji == "":
        push_error("IconRegistry: Null or empty Icon")
        return

    icons[icon.emoji] = icon
    # print("  ✓ Registered Icon: %s (%s)" % [icon.emoji, icon.display_name])

func _load_builtin_icons() -> void:
    # Load from CoreIcons.gd
    CoreIcons.register_all(self)
```

### All Registered Icons Flow

**File**: `Core/Icons/CoreIcons.gd`

```gdscript
static func register_all(registry) -> void:
    _register_celestial(registry)      # ☀ Sun, 🌙 Moon
    _register_flora(registry)          # 🌾 Wheat, 🌿 Vegetation, 🌱 Seedlings
    _register_fauna(registry)          # 🍄 Mushroom, 🦟 Predators
    _register_elements(registry)       # 💧 Water, ⛰ Soil, 🍂 Detritus
    _register_abstract(registry)       # 🔥 Fire, 💨 Flour
    _register_reserved(registry)       # Empty, unused states
    _register_market(registry)         # Market emojis
    _register_kitchen(registry)        # Kitchen emojis
```

**Total Icons**: ~30-50 registered, depending on configuration

---

## Part 3: Icons Compose into Biome Behavior

### How Composition Works

1. **Biome stores active_icons** (a subset of all registered icons)
2. **Each frame, bath builds Hamiltonian from icons**:
   - Iterates through `active_icons`
   - Collects all `self_energy` and `hamiltonian_couplings`
   - Builds dense Hamiltonian matrix H
3. **Each frame, bath builds Lindblad from icons**:
   - Iterates through `active_icons`
   - Collects all `lindblad_outgoing` and `lindblad_incoming`
   - Builds Lindblad superoperator with jump operators L_k
4. **Evolve density matrix using proper master equation**:
   - dρ/dt = -i[H, ρ] + Σ_k (L_k ρ L_k† - 1/2{L_k†L_k, ρ})

### Example: BioticFlux Biome Composition

**What icons are active in BioticFlux?**

```
active_icons = [
    Icon("☀"),   # Sun (driver)
    Icon("🌙"),  # Moon (driver)
    Icon("🌾"),  # Wheat
    Icon("🍄"),  # Mushroom
    Icon("💧"),  # Water
    Icon("⛰"),   # Soil
    Icon("🍂"),  # Detritus
    ...
]
```

**How they compose the Hamiltonian:**

```
H matrix (N×N, N = number of active emojis)

Diagonal terms (self-energies):
H[i,i] = sun.self_energy(t) + moon.self_energy(t) + wheat.self_energy + ...

Off-diagonal terms (couplings):
H[wheat, sun] = wheat.hamiltonian_couplings["☀"]  = 0.5
H[wheat, water] = wheat.hamiltonian_couplings["💧"] = 0.4
H[mushroom, moon] = mushroom.hamiltonian_couplings["🌙"] = 0.6
...

The matrix becomes:
H = [
    [sun_E(t),     0.3,      0.4,      0.6,    0.0,  ...]  ☀ (row 0)
    [0.3,      moon_E(t),    0.0,      0.2,    0.4,  ...]  🌙 (row 1)
    [0.4,          0.0,    wheat_E,    0.0,    0.1,  ...]  🌾 (row 2)
    [0.6,          0.2,      0.0,    mushroom_E, 0.0, ...]  🍄 (row 3)
    [0.0,          0.4,      0.1,      0.0,    water_E...] 💧 (row 4)
    ...
]
```

**How they compose the Lindblad operator:**

```
L_wheat_growth = √(lindblad_incoming["☀"]) |wheat⟩⟨sun|
L_wheat_water = √(lindblad_incoming["💧"]) |wheat⟩⟨water|
L_wheat_decay = √(decay_rate) |detritus⟩⟨wheat|
L_mushroom_shadow = √(lindblad_outgoing["☀"]) |shadow⟩⟨mushroom|

Superoperator computes:
ρ' += L_k ρ L_k† - 1/2{L_k†L_k, ρ}  for all k
```

---

## Part 4: How Bath Builds Operators from Icons

### Building the Hamiltonian

**File**: `Core/QuantumSubstrate/QuantumBath.gd:395`

```gdscript
func build_hamiltonian_from_icons(icons: Array) -> void:
    hamiltonian_sparse.clear()

    # Build using new Hamiltonian class
    _hamiltonian.build_from_icons(icons, _density_matrix.emoji_list)

    # Also populate legacy storage for compatibility
    for i in range(_hamiltonian.dimension()):
        for j in range(_hamiltonian.dimension()):
            var elem = _hamiltonian.get_element(i, j)
            if elem.abs() > 1e-10:
                if not hamiltonian_sparse.has(i):
                    hamiltonian_sparse[i] = {}
                hamiltonian_sparse[i][j] = elem

    operators_dirty = false
```

### Building the Lindblad Operator

**File**: `Core/QuantumSubstrate/QuantumBath.gd:413`

```gdscript
func build_lindblad_from_icons(icons: Array) -> void:
    lindblad_terms.clear()

    # Build using new Lindblad class
    _lindblad.build_from_icons(icons, _density_matrix.emoji_list)

    # Also populate legacy lindblad_terms for compatibility
    for term in _lindblad.get_terms():
        var source_idx = _density_matrix.emoji_to_index.get(term.source, -1)
        var target_idx = _density_matrix.emoji_to_index.get(term.target, -1)
        if source_idx >= 0 and target_idx >= 0:
            lindblad_terms.append({
                "source": source_idx,
                "target": target_idx,
                "rate": term.rate
            })

    # Initialize evolver with new operators
    _evolver.initialize(_hamiltonian, _lindblad)
```

### Time Evolution Using Both

**File**: `Core/QuantumSubstrate/QuantumBath.gd:445`

```gdscript
func evolve(dt: float) -> void:
    if _density_matrix.dimension() == 0:
        return

    bath_time += dt

    # 1. Update time-dependent Hamiltonian (for sun/moon drivers)
    update_time_dependent()  # Uses driver_frequency, driver_phase

    # 2. Track energy tap flux (for economy)
    reset_sink_flux()
    for term in _lindblad.get_terms():
        if term.type == "drain":
            var p_source = get_probability(term.source)
            var flux = term.rate * dt * p_source
            if not sink_flux_per_emoji.has(term.source):
                sink_flux_per_emoji[term.source] = 0.0
            sink_flux_per_emoji[term.source] += flux

    # 3. Set evolver time for time-dependent terms
    _evolver.set_time(bath_time)

    # 4. Evolve using proper quantum mechanics (Lindblad master equation)
    _evolver.evolve_in_place(_density_matrix, dt)

    bath_evolved.emit()
```

---

## Part 5: Icon Composition Example - Complete Trace

### Scenario: Wheat grows under sun and water

**Initial state**:
```
ρ = 0.5|☀⟩⟨☀| + 0.2|💧⟩⟨💧| + 0.3|🌾⟩⟨🌾|
```

**At frame t=0.016s (60 FPS)**:

**Step 1: Query active_icons from BioticFlux biome**
```
active_icons = [Icon("☀"), Icon("🌙"), Icon("🌾"), Icon("💧"), Icon("⛰"), Icon("🍄"), ...]
```

**Step 2: Build Hamiltonian H from icons**

Sun icon contributes:
- H[0,0] = sun.get_self_energy(t=0.016) = 1.0 × cos(0.05 × 0.016 × 2π) ≈ 0.995
- H[0,2] = sun.hamiltonian_couplings["🌾"] = 0.4
- H[0,3] = sun.hamiltonian_couplings["🍄"] = 0.2

Wheat icon contributes:
- H[2,2] = wheat.self_energy = 0.1
- H[2,0] = wheat.hamiltonian_couplings["☀"] = 0.5
- H[2,4] = wheat.hamiltonian_couplings["💧"] = 0.4

Water icon contributes:
- H[4,4] = water.self_energy = 0.05
- H[4,2] = water.hamiltonian_couplings["🌾"] = 0.3

**Result: H matrix (symmetric)**
```
H = [
    [0.995,  0.0,  0.4,  0.2,  0.0,  ...]  ☀
    [0.0,    ...,  ...,  ...,  ...,  ...]  🌙
    [0.4,    0.0,  0.1,  0.0,  0.4,  ...]  🌾
    [0.2,    0.0,  0.0,  ...,  0.0,  ...]  🍄
    [0.0,    0.0,  0.4,  0.0,  0.05, ...]  💧
    ...
]
```

**Step 3: Build Lindblad L from icons**

Wheat icon contributes:
- L_grow_sun = √(0.00267) |🌾⟩⟨☀| (wheat grows from sun)
- L_grow_water = √(0.00167) |🌾⟩⟨💧| (wheat grows from water)
- L_decay = √(0.02) |🍂⟩⟨🌾| (wheat decays)

Water icon contributes:
- L_evaporate = √(0.001) |evaporated⟩⟨💧|

**Lindblad superoperator**: For each L_k:
```
ρ_next += L_k ρ L_k† - 1/2{L_k†L_k, ρ}
```

**Step 4: Evolve density matrix**

Using Euler stepping with dt=0.016:
```
ρ(t=0.016) = ρ(t=0) - i[H, ρ]·dt + Σ_k (L_k ρ L_k† - 1/2{L_k†L_k, ρ})·dt

Result:
- Wheat amplitude increases (from sun and water couplings)
- Sun amplitude decreases slightly (coupling to wheat)
- Water amplitude decreases slightly (coupling to wheat)
- Overall trace remains 1.0 (conservation)
```

**Step 5: Observable effects**

- Wheat `get_purity()` slightly increases
- Wheat growth rate increases (via `get_marginal_purity()`)
- Mill measurement becomes slightly more likely to produce flour

---

## Part 6: Special Features

### Time-Dependent Driving

Icons can have time-varying self-energies via external drivers:

```gdscript
sun.self_energy_driver = "cosine"
sun.driver_frequency = 0.05        # 0.05 Hz = 5% of frame rate
sun.driver_amplitude = 1.0

# At frame t, effective self-energy is:
H_eff = sun.self_energy × driver_amplitude × cos(driver_frequency × t × 2π + driver_phase)
```

This creates day/night cycles naturally via the Hamiltonian.

### Energy Couplings (Bath Projection)

Separate from Hamiltonian, icons can define "energy" effects (for gameplay):

```gdscript
wheat.energy_couplings = {
    "☀": +0.08,  # Gains energy from sun (growth boost)
    "💧": +0.05  # Gains energy from water (growth boost)
}

# Used in: plot.grow() for computing actual growth rate
# Formula: growth_rate = base_rate + Σ(coupling × probability_of_interaction)
```

### Energy Taps (Lindblad Drains)

Icons can be configured as drain targets:

```gdscript
wheat.is_drain_target = true
wheat.drain_to_sink_rate = 0.05

# When energy tap placed: Add L_drain = √(0.05) |sink⟩⟨wheat|
# Population in wheat drains to sink state
```

### Trophic Levels & Tags

Metadata for organization:

```gdscript
wheat.trophic_level = 1        # Producer
wheat.tags = ["flora", "crop", "edible", "slow-growing"]

# Used for:
# - Querying icons: registry.get_icons_by_trophic_level(2)
# - Organizing UI displays
# - Future AI agents (who eats whom)
```

---

## Part 7: Biome Composition Patterns

### Pattern 1: Forest Ecosystem

```
active_icons = [
    ☀ (driver),              # External forcing (sun)
    🌙 (driver),             # External forcing (moon)
    🌿 (vegetation, producer),
    🦟 (herbivore, consumer),
    🦁 (predator, consumer),
    💧 (resource),
    🍂 (sink/decay)
]

H interactions:
- Sun ↔ Moon (day/night opposition)
- Sun → Vegetation (growth)
- Vegetation → Herbivore (predation)
- Herbivore → Predator (predation)

L terms:
- Vegetation + sun → Vegetation (growth)
- Vegetation → Decay (natural mortality)
- Herbivore + vegetation → Herbivore (growth)
- Herbivore → Predator (predation as transfer)
- Everything → Decay (entropy)
```

### Pattern 2: Wheat-Mushroom Entanglement

```
active_icons = [
    ☀ (driver),
    🌙 (driver),
    🌾 (wheat, day-loving),
    🍄 (mushroom, night-loving),
    💧 (water),
    ⛰ (soil)
]

H interactions:
- Wheat couples strongly to sun (0.4)
- Mushroom couples strongly to moon (0.6)
- Both couple to water and soil

Result: Anti-correlated evolution
- When sun is high: wheat amplitude increases, mushroom decreases
- When moon is high: mushroom amplitude increases, wheat decreases
```

### Pattern 3: Kitchen (Cross-Biome Composition)

```
# Kitchen has its own biome with:
active_icons = [
    🔥 (fire),
    💧 (water),
    💨 (flour),
    🍞 (bread - result)
]

# Plus gates that entangle:
Bell state: |fire⟩ + |water⟩ + |flour⟩ → |bread⟩

# Bath evolved under:
H = coupling(fire, water) + coupling(water, flour) + ...
L = growth terms from inputs, collapse to bread outcome
```

---

## Summary: The Icon Composition Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│ CoreIcons.register_all() - Define all Icon resources        │
│ (30-50 icons with Hamiltonian & Lindblad terms)            │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────────────────┐
│ IconRegistry - Central catalog (emoji → Icon)               │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────────────────┐
│ Biome creates active_icons = subset of registered icons     │
│ (e.g., BioticFlux uses 10-15 icons)                        │
└──────────────────┬──────────────────────────────────────────┘
                   │
       ┌───────────┴───────────┐
       ↓                       ↓
   ┌───────────┐           ┌──────────┐
   │ Build H   │           │ Build L  │
   │ from icons│           │ from icons
   │ (each dt) │           │ (each dt)
   └────┬──────┘           └────┬─────┘
        │                       │
        ↓                       ↓
   ┌──────────────────────────────────┐
   │ QuantumEvolver.evolve(ρ, H, L)   │
   │ Lindblad master equation:        │
   │ dρ/dt = -i[H, ρ] + Σ_k L_k      │
   └────────┬─────────────────────────┘
            │
            ↓
   ┌──────────────────────────────┐
   │ Evolved density matrix        │
   │ (new population probabilities)│
   └────────┬─────────────────────┘
            │
       ┌────┴─────┬────────────┬──────────┐
       │           │            │          │
       ↓           ↓            ↓          ↓
    Growth    Entanglement  Measurement  Energy
   probabilities dynamics   statistics   harvesting
```

---

## Key Takeaways

1. **Icons are definitions**: Each emoji has fixed Hamiltonian & Lindblad coefficients
2. **Biomes select subsets**: Not all icons active in all biomes
3. **Composition is linear in Hamiltonian**: H_total = Σ(icon.self_energy + icon.couplings)
4. **Composition is additive in Lindblad**: L_total = √Σ(icon.lindblad_outgoing + others)
5. **Time evolution is proper quantum**: Uses full Lindblad master equation
6. **Emergence comes from**: Nonlinear interactions in density matrix evolution, not the icons themselves
7. **Icons decouple physics from gameplay**: Same icons work in different biomes with different compositions

---

## Code References

| Topic | File | Lines |
|-------|------|-------|
| Icon definition | `Core/QuantumSubstrate/Icon.gd` | 1-155 |
| Icon registry | `Core/QuantumSubstrate/IconRegistry.gd` | 1-124 |
| Core icons (celestial, flora, fauna) | `Core/Icons/CoreIcons.gd` | 1-500+ |
| Hamiltonian building | `Core/QuantumSubstrate/QuantumBath.gd` | 395-410 |
| Lindblad building | `Core/QuantumSubstrate/QuantumBath.gd` | 413-431 |
| Time evolution | `Core/QuantumSubstrate/QuantumBath.gd` | 445-471 |
| Biome initialization | `Core/Environment/BiomeBase.gd` | 250-290 |
| Active icons usage | `Core/Environment/BiomeBase.gd` | 261, 301, 347 |

