# Biome Quantum Dynamics Upgrade Plan

## Problem Statement

Current biomes reach **boring steady states** because:
1. **Hamiltonians are static** - `Icon.get_self_energy(time)` exists but is never called
2. **No time-dependent driving** - sun/moon 20s cycle isn't implemented
3. **All biomes collapse to attractors** - Lindblad dissipation dominates
4. **No stochastic events** - eruptions, swarms, etc. are just labels
5. **No player energy injection** - StellarForges should require input

## Architecture Discovery

The infrastructure **already exists** but isn't wired up:

### Icon Class (Core/QuantumSubstrate/Icon.gd)
```gdscript
# These fields exist but are never used:
@export var self_energy_driver: String = ""  # "cosine", "sine", "pulse"
@export var driver_frequency: float = 0.0    # Hz
@export var driver_phase: float = 0.0        # Radians
@export var driver_amplitude: float = 1.0    # Multiplier
@export var drivers: Dictionary = {}         # Named drivers

# This method exists but is never called:
func get_self_energy(time: float) -> float:
    match self_energy_driver:
        "cosine": return base * amplitude * cos(frequency * time * TAU + phase)
        "sine":   return base * amplitude * sin(frequency * time * TAU + phase)
        "pulse":  # ... pulse logic
```

### QuantumComputer.evolve() (line 979-982)
```gdscript
# Time is tracked but Hamiltonian is static:
# NOTE: Hamiltonian is static (time-independent for now)
elapsed_time += dt
```

### Data Flow
```
factions.json → FactionRegistry → IconBuilder → Icons → HamiltonianBuilder → Static H
                                                                              ↑
                                              MISSING: pass elapsed_time to get_self_energy(t)
```

### Current Simulation Results (Static Hamiltonians)
| Biome | Steady Purity | Decoherence | Dominant State | Problem |
|-------|---------------|-------------|----------------|---------|
| BioticFlux | 0.549 | 23.7s | 🍂 93% | No day/night oscillation |
| FungalNetworks | 0.404 | 11.6s | 🧫 97% | Nutrient trap, no boom-bust |
| StellarForges | 0.309 | 5.6s | ⚙ 83% | Decays too fast, no production rhythm |
| VolcanicWorlds | 0.278 | 15.0s | 🪨 86% | No eruptions, just cooling |

---

## Architecture Upgrade: Data-Driven Time-Dependent Dynamics

### Principle: All tuning in factions.json, not hardcoded

The fix requires two changes:
1. **factions.json**: Add `drivers` field to relevant factions
2. **HamiltonianBuilder**: Use `Icon.get_self_energy(elapsed_time)` instead of static `self_energy`

### Step 1: Add drivers to factions.json

```json
{
  "name": "Solar Covenant",
  "signature": ["☀", "🌙", "🌅", "🌄"],
  "self_energies": {
    "☀": 0.3,
    "🌙": -0.3
  },
  "drivers": {
    "☀": {
      "type": "cosine",
      "frequency": 0.05,
      "amplitude": 1.0,
      "phase": 0.0
    },
    "🌙": {
      "type": "cosine",
      "frequency": 0.05,
      "amplitude": 1.0,
      "phase": 3.14159
    }
  }
}
```

### Step 2: Update IconBuilder to parse drivers

```gdscript
# In IconBuilder.build_icons_for_factions():
if faction.has("drivers"):
    for emoji in faction.drivers:
        var driver = faction.drivers[emoji]
        icon.self_energy_driver = driver.get("type", "")
        icon.driver_frequency = driver.get("frequency", 0.0)
        icon.driver_amplitude = driver.get("amplitude", 1.0)
        icon.driver_phase = driver.get("phase", 0.0)
```

### Step 3: Modify QuantumComputer to use time-dependent H

Option A: Rebuild H each step (simple but slow)
```gdscript
func evolve(dt: float) -> void:
    elapsed_time += dt

    # Rebuild Hamiltonian with time-dependent terms
    _update_hamiltonian_drivers(elapsed_time)

    # ... rest of evolution
```

Option B: Separate static H from driver modulation (faster)
```gdscript
# Store base Hamiltonian and driver terms separately
var hamiltonian_static: ComplexMatrix  # H_0
var hamiltonian_drivers: Array         # [{qubit, base_energy, driver_config}]

func _compute_effective_hamiltonian(t: float) -> ComplexMatrix:
    var H = hamiltonian_static.duplicate()

    for driver in hamiltonian_drivers:
        var energy = _compute_driver_energy(driver, t)
        _add_diagonal_term(H, driver.qubit, driver.pole, energy)

    return H
```

### Step 4: Pass Icons + time to HamiltonianBuilder

```gdscript
# Modified HamiltonianBuilder.build():
static func build(icons: Dictionary, register_map: RegisterMap,
                  verbose = null, time: float = 0.0) -> ComplexMatrix:
    # ...
    for source_emoji in icons:
        var icon = icons[source_emoji]

        # Use time-dependent self-energy
        var energy = icon.get_self_energy(time)  # <-- KEY CHANGE
        if abs(energy) > 1e-10:
            _add_self_energy(H, source_q, source_p, energy, num_qubits)
```

---

## Per-Biome Tuning Plans (via factions.json)

### 1. BioticFlux: Day/Night Cycle (20s period)

**Design Goal:** Visible 20-second oscillation between ☀ and 🌙

**Current Issue:** Static ☀↔🌙 coupling gives ~240s natural period (boring!)

**factions.json changes - Find/create "Solar Covenant" or celestial faction:**
```json
{
  "name": "Solar Covenant",
  "signature": ["☀", "🌙", "🌅", "🌄"],
  "self_energies": {
    "☀": 0.5,
    "🌙": -0.5
  },
  "drivers": {
    "☀": {
      "type": "cosine",
      "frequency": 0.05,
      "amplitude": 0.8,
      "phase": 0.0
    },
    "🌙": {
      "type": "cosine",
      "frequency": 0.05,
      "amplitude": 0.8,
      "phase": 3.14159
    }
  },
  "hamiltonian": {
    "☀": { "🌙": 0.1 }
  }
}
```

**Key parameters:**
- `frequency: 0.05` Hz = 20-second period (1/20 = 0.05)
- `amplitude: 0.8` = strong modulation
- `phase: π` for 🌙 = 180° out of phase with ☀

**Lindblad rebalancing - Find agricultural factions:**
```json
{
  "name": "Verdant Pulse",
  "lindblad_incoming": {
    "🌾": { "☀": 0.04 },
    "🍄": { "🌙": 0.04 }
  },
  "decay": {
    "🍂": { "rate": 0.002, "target": "💀" }
  }
}
```

**Expected Result:**
- ☀/🌙 oscillates visibly over 20s
- 🌾 grows during day, 🍄 grows at night
- 🍂 slowly decays (breaks 93% trap)

---

### 2. FungalNetworks: Boom-Bust Colony Dynamics

**Design Goal:** Visible 120s locust swarm cycles, shifting colony dominance

**Current Issue:** 🧫 nutrients at 97% - nutrient sink trap

**factions.json changes - Create/modify insect faction:**
```json
{
  "name": "Swarm Collective",
  "signature": ["🦗", "🐜", "🐝", "🦟"],
  "self_energies": {
    "🦗": 0.4,
    "🐜": 0.2
  },
  "drivers": {
    "🦗": {
      "type": "pulse",
      "frequency": 0.00833,
      "amplitude": 1.2,
      "duty_cycle": 0.3
    }
  },
  "hamiltonian": {
    "🦗": { "🐜": 0.3 }
  },
  "lindblad_outgoing": {
    "🦗": { "🍂": 0.04 }
  }
}
```

**Key parameters:**
- `frequency: 0.00833` Hz = 120-second period (1/120)
- `duty_cycle: 0.3` = swarm active 30% of time
- `amplitude: 1.2` = strong surge

**Break nutrient trap - modify decomposer faction:**
```json
{
  "name": "Mycelium Network",
  "signature": ["🍄", "🦠", "🧫", "🍂"],
  "lindblad_outgoing": {
    "🧫": { "🦗": 0.03, "🐜": 0.03 }
  },
  "gated_lindblad": {
    "🦗": [
      { "source": "🧫", "rate": 0.05, "gate": "🌙", "threshold": 0.5 }
    ],
    "🐜": [
      { "source": "🧫", "rate": 0.05, "gate": "☀", "threshold": 0.5 }
    ]
  }
}
```

**Expected Result:**
- Locust swarms every 2 minutes
- Colony competition shifts dominance
- Nutrients consumed by both colonies (breaks trap)

---

### 3. StellarForges: Energy-Starved Production

**Design Goal:** System slowly dies without player energy injection

**Current Issue:** Decays in 5.6s to ⚙-dominated state, then boring

**factions.json changes - Create energy/industrial faction:**
```json
{
  "name": "Stellar Engineers",
  "signature": ["⚡", "🔋", "⚙", "🔩", "🚀", "🛸"],
  "self_energies": {
    "⚡": 0.6,
    "🔋": -0.3,
    "⚙": 0.3,
    "🔩": -0.1
  },
  "drivers": {
    "⚡": {
      "type": "decay",
      "amplitude": 1.0,
      "decay_time": 45.0,
      "requires_injection": true
    },
    "⚙": {
      "type": "cosine",
      "frequency": 0.033,
      "amplitude": 0.3,
      "phase": 0.0
    }
  },
  "hamiltonian": {
    "⚡": { "🔋": 0.2 },
    "⚙": { "🔩": 0.15 }
  },
  "lindblad_outgoing": {
    "⚡": { "⚙": 0.08 },
    "🔋": { "⚡": 0.02 }
  },
  "gated_lindblad": {
    "🚀": [
      { "source": "⚙", "rate": 0.04, "gate": "⚡", "threshold": 0.4 }
    ],
    "🛸": [
      { "source": "⚙", "rate": 0.04, "gate": "🔋", "threshold": 0.4 }
    ]
  }
}
```

**Key parameters:**
- `decay_time: 45.0` = energy halves every 45s without injection
- Production `frequency: 0.033` Hz = 30-second rhythm
- Gated production: 🚀 needs ⚡, 🛸 needs 🔋

**Player Injection (biome code, not factions.json):**
```gdscript
# In StellarForgesBiome.gd:
func inject_energy(amount: float) -> void:
    """Player action: inject energy via Lindblad kick"""
    _apply_population_kick("⚡", amount * 0.3)  # 30% efficiency
    energy_last_injection = elapsed_time
```

**Expected Result:**
- Without injection: ⚡ decays, production stops
- With injection: rhythmic 🚀/🛸 production
- Choice: immediate power (⚡→🚀) vs storage (🔋→🛸)

---

### 4. VolcanicWorlds: Stochastic Eruptions

**Design Goal:** Irregular eruption events that inject energy/chaos

**Current Issue:** Just cools to 🪨 86%, completely dormant

**factions.json changes - Create volcanic faction:**
```json
{
  "name": "Magma Collective",
  "signature": ["🔥", "🪨", "💎", "⛏", "🌫", "✨"],
  "self_energies": {
    "🔥": 0.6,
    "🪨": -0.3,
    "💎": 0.5,
    "✨": 0.4
  },
  "drivers": {
    "🔥": {
      "type": "stochastic_pulse",
      "base_rate": 0.008,
      "amplitude": 1.5,
      "min_interval": 45.0,
      "max_interval": 120.0,
      "duration": 12.0
    }
  },
  "hamiltonian": {
    "🔥": { "🪨": 0.15 },
    "💎": { "⛏": 0.08 },
    "🌫": { "✨": 0.12 }
  },
  "lindblad_outgoing": {
    "🔥": { "🪨": 0.025, "🌫": 0.04 },
    "💎": { "⛏": 0.008 }
  },
  "gated_lindblad": {
    "💎": [
      { "source": "⛏", "rate": 0.06, "gate": "🔥", "threshold": 0.5 }
    ],
    "✨": [
      { "source": "🌫", "rate": 0.08, "gate": "🔥", "threshold": 0.4 }
    ]
  }
}
```

**Key design:**
- `stochastic_pulse` = new driver type for irregular events
- Base cooling: 🔥→🪨 at 0.025/s (slow dormant decay)
- Gated crystal formation: ⛏→💎 only when 🔥 > 50%

**Stochastic driver implementation (biome code):**
```gdscript
# In VolcanicWorldsBiome.gd:
var eruption_state = {
    "active": false,
    "cooldown": 0.0,
    "next_eruption": randf_range(45.0, 120.0)
}

func _process_eruption_dynamics(dt: float) -> void:
    eruption_state.cooldown += dt

    if not eruption_state.active:
        if eruption_state.cooldown >= eruption_state.next_eruption:
            _trigger_eruption()
    else:
        # Apply continuous heat injection during eruption
        _apply_eruption_lindblad(dt)
        if eruption_state.cooldown >= eruption_state.duration:
            _end_eruption()

func _trigger_eruption() -> void:
    eruption_state.active = true
    eruption_state.cooldown = 0.0
    eruption_state.duration = randf_range(8.0, 15.0)
    eruption_state.intensity = randf_range(0.6, 1.0)

    # Massive population kick
    _apply_population_kick("🔥", 0.4 * eruption_state.intensity)
    _apply_population_kick("✨", 0.3 * eruption_state.intensity)

    print("🌋 ERUPTION! Intensity: %.1f" % eruption_state.intensity)

func _end_eruption() -> void:
    eruption_state.active = false
    eruption_state.next_eruption = randf_range(45.0, 120.0)
    print("🌋 Eruption subsiding... next in %.0fs" % eruption_state.next_eruption)
```

**Expected Result:**
- Dormant: slow cooling, 🪨 86%, 💎 rare
- Eruption: sudden 🔥 spike → 💎 formation window → ✨ sparks
- Irregular 45-120s timing creates tension
- Players harvest 💎 during/after eruptions

---

## Implementation Priority

### Phase 1: Core Infrastructure (Required) - Wire up existing system ✅ COMPLETED
1. **HamiltonianBuilder.gd**: ✅ Added `time` parameter, uses `icon.get_self_energy(time)`
2. **QuantumComputer.gd**: ✅ Added `driven_icons` storage and `update_driven_self_energies(time)` method
3. **IconBuilder.gd**: ✅ Already parses `drivers` field from faction data (was implemented)
4. **Faction.gd**: ✅ Already has `drivers` field in data model (was implemented)
5. **BiomeBase.gd**: ✅ Now calls `set_driven_icons()` after building operators
6. **evolve()**: ✅ Calls `update_driven_self_energies(elapsed_time)` each frame

**Verification**: Tests in `Tests/test_time_dependent_drivers.gd` pass:
- `Icon.get_self_energy(time)` correctly oscillates with sine/cosine drivers
- `HamiltonianBuilder.get_driven_icons()` extracts driven icon configs
- `HamiltonianBuilder.build(time)` produces different H for different times

### Phase 2: Data Entry (factions.json) ✅ ALREADY COMPLETE
1. ✅ `drivers` for celestial factions already present (☀/🌙 at 0.05 Hz = 20s period)
2. Add `drivers` to swarm factions (🦗 pulse) - PENDING
3. Add `drivers` to energy factions (⚡ decay) - PENDING
4. Add `drivers` to volcanic factions (🔥 stochastic) - PENDING
5. Rebalance Lindblad rates to break attractor traps - PENDING

### Phase 3: Biome-Specific Logic
1. **VolcanicWorldsBiome.gd**: Stochastic eruption state machine
2. **StellarForgesBiome.gd**: Player energy injection API
3. Test each biome in isolation with simulator

### Phase 4: Integration Testing
1. Run biome_quantum_simulator.gd with new parameters
2. Verify oscillations, eruptions, production cycles
3. Tune rates for gameplay feel

---

## Expected Outcomes After Upgrade

| Biome | Character | Key Dynamic | Player Strategy |
|-------|-----------|-------------|-----------------|
| BioticFlux | **Rhythmic** | 20s day/night oscillation | Time harvests to day (🌾) or night (🍄) |
| FungalNetworks | **Chaotic** | Boom-bust swarms, shifting dominance | Exploit swarm peaks, avoid crashes |
| StellarForges | **Strategic** | Decays without input, gated production | Manage energy budget, choose 🚀 vs 🛸 |
| VolcanicWorlds | **Dramatic** | Irregular eruptions create windows | React to eruptions, harvest 💎 |

---

## Files to Modify

### Core Infrastructure
- `Core/QuantumSubstrate/HamiltonianBuilder.gd` - Add time parameter
- `Core/QuantumSubstrate/QuantumComputer.gd` - Periodic H rebuild or driver accumulator
- `Core/Factions/IconBuilder.gd` - Parse drivers from factions
- `Core/Factions/Faction.gd` - Add drivers field
- `Core/Environment/BiomeBase.gd` - Add `_apply_population_kick()`

### Data (main tuning location)
- `Core/Factions/data/factions.json` - Add drivers, rebalance rates

### Biome-Specific
- `Core/Environment/VolcanicWorldsBiome.gd` - Eruption state machine
- `Core/Environment/StellarForgesBiome.gd` - Energy injection API

### Testing
- `Tests/biome_quantum_simulator.gd` - Update to use time-dependent H
