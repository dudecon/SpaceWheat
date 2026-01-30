# Faction-Hamiltonian / Biome-Lindblad Architecture

## Overview

**Date:** 2026-01-29  
**Status:** Proof-of-Concept (StarterForest biome)

This document describes the new architecture that separates **coherent dynamics (Hamiltonian)** from **dissipative dynamics (Lindblad)** by aligning them with the game's conceptual hierarchy.

---

## Core Principle

### **Factions → Hamiltonian (Universal Laws)**
Factions define the **intrinsic nature** of emojis—their energy levels and reversible interactions. These are **context-independent**:
- `self_energy`: What an emoji "is" (wolves are high-energy, rabbits low)
- `hamiltonian_couplings`: Universal relationships (predator-prey oscillations)
- These apply **everywhere** (same wolf behavior in Forest or Market)

### **Biomes → Lindblad (Environmental Context)**
Biomes define **environmental flows**—irreversible processes that only make sense in specific contexts:
- `lindblad_pumps`: Environmental energy injection (sun pumps plants)
- `lindblad_drains`: Decay and consumption (trees → leaf litter)
- `gated_lindblad`: Context-dependent transitions (mushrooms only grow when wet)
- These are **biome-specific** (Forest has different dissipation than Desert)

### **Icons = Hamiltonian Snapshot**
Icons are built **purely from faction contributions** (no Lindblad terms). They represent the "ideal" behavior of an emoji across all contexts, weighted by current faction standings.

### **Evolution = H (universal) + L (local)**
Each biome gets:
- The **same Hamiltonian** (universal laws from factions)
- **Different Lindblad operators** (local environmental effects)

---

## Architecture Components

### 1. **BiomeLindblad.gd** (New)
Resource type for biome-specific dissipation:
```gdscript
var L = BiomeLindblad.new()
L.add_pump("🌱", "☀", 0.03)      # Sun pumps seedlings
L.add_drain("🌲", "🍂", 0.1)     # Trees decay
L.add_gated("🍄", "🌙", "💧", 0.06)  # Mushrooms grow when wet
```

### 2. **BiomeBuilder.gd** (New)
Unified machinery for building biome quantum systems:
- **INVARIANT:** Boot and live-rebuild use the **SAME** code path
- `build_biome_quantum_system()`: Complete H+L build
- `rebuild_icons_for_standings()`: Rebuild H when faction power shifts
- No difference between boot-time and runtime rebuilds

### 3. **StarterForestBiome.gd** (Refactored)
Example implementation:
- `_initialize_bath()`: Calls BiomeBuilder with emoji pairs + Lindblad spec
- `_create_forest_lindblad_spec()`: Defines Forest-specific dissipation
- `_rebuild_quantum_operators_impl()`: Live rebuild using same BiomeBuilder

### 4. **IconBuilder.gd** (To Be Simplified)
Future work:
- Strip all Lindblad merging logic
- Only merge `self_energy` and `hamiltonian_couplings`
- Icons become Hamiltonian-only

---

## Key Benefits

### 1. **Conceptual Clarity**
- Factions = "what things are" (timeless, universal)
- Biomes = "how things change here" (irreversible, contextual)

### 2. **Live Rebuild Capability**
- **Faction standings change** → Rebuild Hamiltonian (universal laws shift)
- **New biome discovered** → Build new Lindblad (new environmental context)
- Boot and live-rebuild use **identical machinery** (no divergence bugs)

### 3. **Dynamic Faction System**
- Player reputation affects H matrix weights
- Same emoji has different energy/couplings based on faction power
- Example: 💧 is weak when Water faction is suppressed

### 4. **On-Demand Biome Building**
- Don't build all biomes at boot (expensive, unnecessary)
- Build biomes when discovered from random pool
- Each biome = new Lindblad spec, same Hamiltonian base

---

## Usage Flow

### Boot Time
```gdscript
# In StarterForestBiome._initialize_bath()
var emoji_pairs = [{north: "☀", south: "🌙"}, ...]
var lindblad_spec = _create_forest_lindblad_spec()
var result = BiomeBuilder.build_biome_quantum_system(
    "StarterForest", emoji_pairs, {}, lindblad_spec
)
quantum_computer = result.quantum_computer
```

### Live Rebuild (Faction Standings Change)
```gdscript
# When player reputation shifts
var new_standings = {"Pack Lords": 0.5, "Swift Herd": 1.5}
var new_icons = BiomeBuilder.rebuild_icons_for_standings(
    quantum_computer.register_map, new_standings
)
# Rebuild H, keep L unchanged
quantum_computer.hamiltonian = HamiltonianBuilder.build(new_icons, ...)
```

### New Biome Discovery
```gdscript
# When player discovers "VolcanicWorlds"
var emoji_pairs = get_volcanic_axes()
var lindblad_spec = create_volcanic_lindblad()
var result = BiomeBuilder.build_biome_quantum_system(
    "VolcanicWorlds", emoji_pairs, current_standings, lindblad_spec
)
# Exact same call as boot
```

---

## Migration Path

### Phase 1: ✅ Proof-of-Concept (DONE)
- Created `BiomeLindblad.gd`
- Created `BiomeBuilder.gd`
- Refactored `StarterForestBiome` to use new architecture

### Phase 2: Test & Validate
- [ ] Boot the game with new StarterForest
- [ ] Verify operators are built correctly
- [ ] Test live rebuild when faction standings change
- [ ] Compare output with old architecture

### Phase 3: Migrate Remaining Biomes
- [ ] Village biome
- [ ] BioticFlux biome
- [ ] StellarForges biome
- [ ] FungalNetworks biome
- [ ] VolcanicWorlds biome

### Phase 4: Strip Lindblad from Factions
- [ ] Update `factions.json` schema (remove `lindblad_*` fields)
- [ ] Simplify `IconBuilder.gd` (H-only merging)
- [ ] Archive old faction Lindblad data for reference

---

## Testing Checklist

### Boot Test
- [ ] Game boots without errors
- [ ] StarterForest quantum system initializes
- [ ] H matrix is correct size (32x32 for 5 qubits)
- [ ] L operators are built from BiomeLindblad spec
- [ ] Console shows "(H=factions, L=biome)"

### Live Rebuild Test
- [ ] Call `rebuild_quantum_operators()` during gameplay
- [ ] Hamiltonian changes
- [ ] Lindblad operators stay the same
- [ ] Evolution continues without crashes

### Discovery Test
- [ ] Build a new biome on-demand (not at boot)
- [ ] Uses same BiomeBuilder path
- [ ] Biome works identically to boot-loaded biomes

---

## Open Questions

1. **Cross-biome couplings** - Currently in `IconBuilder.build_forest_biome()`. Should these:
   - Move to Biome Lindblad specs? (most are dissipative)
   - Split between H and L?

2. **Gated Lindblad** - Currently faction-based. Should they:
   - Stay with factions as metadata?
   - Move entirely to biomes?

3. **Backward compatibility** - Old saves with mixed H+L icons:
   - Graceful degradation?
   - Hard reset?

4. **Faction standings source** - Where to get current reputation?
   - `ObservationFrame.get_faction_standings()`?
   - New `FactionReputationManager`?

---

## Next Steps

1. **Boot Test**: Run the game and verify StarterForest works
2. **Debug**: Fix any initialization issues
3. **Expand**: Add one more biome (Village) to test reusability
4. **Integration**: Hook up faction standings system
5. **Migration**: Convert remaining biomes and strip old Lindblad from factions
