# Analog Upgrade Implementation Plan v2 (CORRECTED)
## Model C: RegisterMap-Based Architecture

**Status**: SPECIFICATION COMPLETE - READY TO IMPLEMENT
**Date**: 2026-01-05 (Corrected)
**Scope**: Replace Bell state entanglement with analog population transfer
**Reference**: `llm_inbox/analogue_upgrade_1/BREAD_WORKFLOW_IMPLEMENTATION.gd`

---

## ⚠️ CORRECTIONS FROM v1

### 1. Icon Coupling Example (Lines 53-56)
**CHANGED**: Removed confusing `🔥→🍞` coupling example
**REASON**: 🍞 is NOT a dimension - it's a measurement outcome. Using it in coupling examples confuses implementers.

**NEW EXAMPLE**:
```gdscript
icons["🔥"].hamiltonian_couplings = {
    "❄️": Complex(0.3, 0),  # Same-qubit: σ_x rotation on qubit 0
    "💧": Complex(0.1, 0)   # Cross-qubit: conditional transition
}
```

### 2. Resource Consumption Timing (Lines 585-601)
**CHANGED**: Workflow is now **Spend → Drive → Wait → Harvest**
**REASON**: Old model had backwards timing (measure first, then consume)

**CORRECT WORKFLOW**:
```
1. Player spends resources (fire/water/flour credits)
2. Credits activate Lindblad drives for duration
3. Kitchen evolves automatically in _process()
4. Player manually triggers harvest when P(bread) is high
5. Measurement produces bread (or doesn't)
```

### 3. Phase vs Population Clarification
**ADDED**: Explicit note about off-diagonal elements

**IMPORTANT**: The density matrix ρ has:
- **Diagonal elements** ρ[i,i]: Populations (probabilities) - what we track for gameplay
- **Off-diagonal elements** ρ[i,j] (i≠j): Coherences (contain phase φ information)

The Hamiltonian evolution affects BOTH, but for gameplay we primarily query:
- `get_population(emoji)` → Marginal probabilities (diagonals)
- `get_basis_probability(i)` → Specific basis state (diagonal)
- `p_bread()` → P(|000⟩) = ρ[0,0]

Off-diagonals exist and evolve correctly, but player doesn't directly see them.

---

## Executive Summary

### What's Changing

**REMOVED**:
- ❌ GHZ/Bell state entanglement (the three methods I just added)
- ❌ `set_quantum_inputs_with_units()`
- ❌ `create_bread_entanglement()`
- ❌ `measure_as_bread()`
- ❌ Direct emoji → matrix index mapping
- ❌ DualEmojiQubit in kitchen processing
- ❌ "Population pumping" concept

**ADDED**:
- ✅ RegisterMap: emoji ↔ coordinate translation layer
- ✅ HamiltonianBuilder: Build H from filtered Icons
- ✅ LindbladBuilder: Build L operators from filtered Icons
- ✅ BiomeFactory: Dynamic biome generation
- ✅ Analog population transfer on three independent axes
- ✅ Detuning Hamiltonian for resonance control
- ✅ Coordinate-based partial traces
- ✅ Automatic kitchen evolution in _process()
- ✅ Manual harvest trigger by player

### New Philosophy

```
OLD: Create entangled superposition (|000⟩ + |111⟩)/√2
NEW: Drive population |111⟩ → |000⟩ via resonance

OLD: Bread = measurement of Bell state
NEW: Bread = high P(|000⟩) via detuning sweet spot

OLD: Emojis as dimensions
NEW: Emojis as labels on qubit poles

OLD: Consume resources after measurement
NEW: Spend resources to activate drives, measure when ready
```

---

## Complete Bread Workflow (FROM REFERENCE IMPLEMENTATION)

### Step-by-Step Player Experience

1. **Player accumulates resources** (via farming, tapping, milling)
   - Fire credits (🔥) from kitchen tap or player fire action
   - Water credits (💧) from forest biome Lindblad drain
   - Flour credits (💨) from mill processing

2. **Player spends resources to activate drives**
   ```gdscript
   // Player clicks "Add 50 fire" button
   farm_economy.remove_resource("🔥", 50, "kitchen_input")
   kitchen.add_fire(50)  // Activates 5-second drive (50 * 0.1)
   ```

3. **Kitchen evolves automatically** (in `_process(delta)`)
   - Lindblad drives push populations toward |0⟩ on each axis
   - Detuning Hamiltonian rotates |111⟩ ↔ |000⟩ when near resonance
   - Natural decay pulls back toward |111⟩ (time pressure)

4. **Player monitors bread probability**
   ```gdscript
   var p = kitchen.p_bread()  // P(|000⟩) shown in UI
   if p > 0.7:  // Good chance!
       harvest_kitchen()
   ```

5. **Player triggers harvest**
   ```gdscript
   var result = kitchen.harvest()
   // Samples basis state from ρ diagonal
   // Collapses to outcome
   // Returns bread if |000⟩, partial if {|001⟩,|010⟩,|100⟩}, fail otherwise
   ```

6. **Bread added to economy** (if successful)
   ```gdscript
   if result["got_bread"]:
       farm_economy.add_resource("🍞", result["yield"], "kitchen_harvest")
   ```

7. **Kitchen resets to |111⟩**, ready for next bake

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ LAYER 1: GLOBAL PHYSICS (IconRegistry)                      │
│                                                              │
│  icons["🔥"].hamiltonian_couplings = {                       │
│      "❄️": Complex(0.3, 0),  ← Fire↔cold (same qubit)       │
│      "💧": Complex(0.1, 0)   ← Fire↔water (cross qubit)     │
│  }                                                           │
│                                                              │
│  Defines HOW emojis interact (physics laws)                 │
│  NOTE: No 🍞 coupling - bread is measurement outcome!       │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ FILTERING
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ LAYER 2: LOCAL COORDINATES (RegisterMap)                    │
│                                                              │
│  Kitchen.register_map.coordinates = {                        │
│      "🔥": {qubit: 0, pole: NORTH},  ← Fire IS in kitchen   │
│      "❄️": {qubit: 0, pole: SOUTH},  ← Cold IS in kitchen   │
│      "💧": {qubit: 1, pole: NORTH},  ← Water IS in kitchen  │
│      "🏜️": {qubit: 1, pole: SOUTH},  ← Dry IS in kitchen    │
│      "💨": {qubit: 2, pole: NORTH},  ← Flour IS in kitchen  │
│      "🌾": {qubit: 2, pole: SOUTH}   ← Grain IS in kitchen  │
│  }                                                           │
│                                                              │
│  Defines WHERE emojis live in this biome's Hilbert space    │
│  6 emojis → 3 axes → 8D Hilbert space (2^3)                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ LAYER 3: QUANTUM STATE (ComplexMatrix 8×8)                  │
│                                                              │
│  ρ[i, j] ← Integer indices only                             │
│                                                              │
│  DIAGONAL (populations - player sees these):                │
│    ρ[0,0] = P(|000⟩) = P(🔥💧💨) = bread probability       │
│    ρ[7,7] = P(|111⟩) = P(❄️🏜️🌾) = ground state            │
│                                                              │
│  OFF-DIAGONAL (coherences - contain phase info):            │
│    ρ[0,7] = ⟨000|ρ|111⟩ (complex, evolves under H)         │
│    ρ[i,j] for i≠j (exist, evolve, but not directly shown) │
│                                                              │
│  RegisterMap.basis_to_emojis(0) → ["🔥", "💧", "💨"]        │
│  RegisterMap.basis_to_emojis(7) → ["❄️", "🏜️", "🌾"]        │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Core Infrastructure (NEW FILES)

**Priority**: CRITICAL - Everything else depends on this

#### 1.1 RegisterMap.gd (NEW)
**Path**: `Core/QuantumSubstrate/RegisterMap.gd`
**Lines**: ~150 lines
**Purpose**: Emoji ↔ coordinate translation
**Reference**: MODEL_C_REGISTERMAP_DIRECTIVE.md lines 74-176

**Complete implementation provided in directive** ✅

---

#### 1.2 HamiltonianBuilder.gd (NEW)
**Path**: `Core/QuantumSubstrate/HamiltonianBuilder.gd`
**Lines**: ~100 lines
**Purpose**: Build Hamiltonian from Icons, filtered by RegisterMap
**Reference**: MODEL_C_REGISTERMAP_DIRECTIVE.md lines 341-453

**Complete implementation provided in directive** ✅

---

#### 1.3 LindbladBuilder.gd (NEW)
**Path**: `Core/QuantumSubstrate/LindbladBuilder.gd`
**Lines**: ~80 lines
**Purpose**: Build Lindblad operators from Icons, filtered by RegisterMap
**Reference**: MODEL_C_REGISTERMAP_DIRECTIVE.md lines 457-541

**Complete implementation provided in directive** ✅

---

#### 1.4 BiomeFactory.gd (NEW)
**Path**: `Core/Environment/BiomeFactory.gd`
**Lines**: ~60 lines
**Purpose**: Dynamic biome generation from axis configurations
**Reference**: MODEL_C_REGISTERMAP_DIRECTIVE.md lines 554-616

**Complete implementation provided in directive** ✅

---

### Phase 2: Modify QuantumComputer

**File**: `Core/QuantumSubstrate/QuantumComputer.gd`

**ADD**:
```gdscript
var register_map: RegisterMap = RegisterMap.new()

func allocate_axis(north_emoji: String, south_emoji: String) -> int:
    """Allocate qubit axis. Returns qubit index."""
    # Validate emojis in IconRegistry
    # Call register_map.register_axis()
    # Resize density matrix
    # Return qubit index

func get_marginal(qubit: int, target_pole: int) -> float:
    """P(qubit = pole) via partial trace."""
    # Sum ρ[i,i] where bit matches pole
    # Reference: KITCHEN_UPGRADE_DIRECTIVE_v2.md lines 192-224

func get_population(emoji: String) -> float:
    """RegisterMap lookup + marginal."""
    var q = register_map.qubit(emoji)
    var p = register_map.pole(emoji)
    return get_marginal(q, p)

func get_basis_probability(index: int) -> float:
    """P(|index⟩) = ρ[index, index]."""
    return density_matrix.get_element(index, index).re

func apply_drive(emoji: String, rate: float, dt: float) -> bool:
    """Lindblad drive toward emoji's pole."""
    # Reference: KITCHEN_UPGRADE_DIRECTIVE_v2.md lines 303-376

func transfer_population(from_basis: int, to_basis: int, amount: float) -> void:
    """Transfer population between basis states (for Hamiltonian)."""
    # Reference: BREAD_WORKFLOW_IMPLEMENTATION.gd lines 409-423

func apply_decay(emoji: String, rate: float, dt: float) -> void:
    """Decay toward south pole (opposite of drive)."""
    # Reference: BREAD_WORKFLOW_IMPLEMENTATION.gd lines 426-439

func get_trace() -> float:
    """Return Tr(ρ) for validation."""
    # Reference: BREAD_WORKFLOW_IMPLEMENTATION.gd lines 442-447
```

---

### Phase 3: Complete Kitchen Rewrite

**File**: `Core/Environment/QuantumKitchen_Biome.gd`

**REFERENCE IMPLEMENTATION**: `llm_inbox/analogue_upgrade_1/BREAD_WORKFLOW_IMPLEMENTATION.gd`

**This is the authoritative implementation - COPY IT DIRECTLY**

Key sections:
- Lines 1-60: Initialization with RegisterMap
- Lines 62-120: Player actions (spend credits → activate drives)
- Lines 122-152: Population queries (p_fire, p_water, p_flour, p_bread)
- Lines 154-181: Detuning and baking rate calculation
- Lines 183-243: Physics evolution (_process, drives, Hamiltonian, decay)
- Lines 245-310: Harvest (measurement) with partial credit
- Lines 312-326: UI helpers

**DELETE FROM CURRENT FILE**:
- Lines 439-588: All Bell state methods
- `bell_inputs`, `bell_entanglement`, `bell_resource_units` variables

**IMPORTANT CONSTANTS** (from reference):
```gdscript
const IDEAL_FIRE = 0.7    # Sweet spot: 70% hot
const IDEAL_WATER = 0.5   # Sweet spot: 50% wet
const IDEAL_FLOUR = 0.6   # Sweet spot: 60% flour

const COUPLING_OMEGA = 0.15  # |111⟩ ↔ |000⟩ strength
const DRIVE_RATE = 0.5       # Lindblad drive rate
const DECAY_RATE = 0.05      # Natural decay rate
```

---

### Phase 4: FarmGrid Integration (CORRECTED)

**File**: `Core/GameMechanics/FarmGrid.gd`
**Function**: `_process_kitchens(delta)` - Lines 521-609

**REFERENCE**: BREAD_WORKFLOW_IMPLEMENTATION.gd lines 329-399

**WRONG (OLD - DELETE THIS)**:
```gdscript
// Create DualEmojiQubits
// Call set_quantum_inputs_with_units()
// Call create_bread_entanglement()
// Call measure_as_bread()
// THEN consume resources ← BACKWARDS!
```

**CORRECT (NEW - IMPLEMENT THIS)**:
```gdscript
func _process_kitchens(delta: float) -> void:
    """Kitchen evolution happens automatically in kitchen._process().

    This method just handles player-triggered actions.
    """
    # Kitchen physics runs automatically - nothing to do here
    pass


func kitchen_add_resource(emoji: String, credits: int) -> bool:
    """Called when player clicks "Add Fire/Water/Flour" button.

    Flow:
      1. Check player has credits
      2. Consume credits from economy
      3. Activate drive in kitchen
    """
    var kitchen = biomes.get("Kitchen") as QuantumKitchen_Biome
    if not kitchen:
        return false

    # Validate credits
    if farm_economy.get_resource(emoji) < credits:
        print("Not enough %s!" % emoji)
        return false

    # SPEND FIRST (new model)
    farm_economy.remove_resource(emoji, credits, "kitchen_input")

    # THEN activate drive
    match emoji:
        "🔥":
            return kitchen.add_fire(credits)
        "💧":
            return kitchen.add_water(credits)
        "💨":
            return kitchen.add_flour(credits)
        _:
            push_error("Unknown kitchen resource: %s" % emoji)
            return false


func kitchen_harvest() -> Dictionary:
    """Called when player clicks "Harvest" button.

    Flow:
      1. Kitchen measures basis state
      2. Determines bread outcome
      3. Adds bread to economy if successful
      4. Resets kitchen to ground
    """
    var kitchen = biomes.get("Kitchen") as QuantumKitchen_Biome
    if not kitchen:
        return {"success": false}

    var result = kitchen.harvest()

    # Add bread to economy (AFTER measurement, not before)
    if result["got_bread"]:
        var bread_credits = result["yield"] * FarmEconomy.QUANTUM_TO_CREDITS
        farm_economy.add_resource("🍞", bread_credits, "kitchen_harvest")

    return result
```

**KEY DIFFERENCE**: Resources are spent WHEN PLAYER ACTS, not when measurement happens.

---

## Testing & Validation

### Unit Tests

**Create**: `Tests/test_register_map.gd`

```gdscript
func test_register_axis():
    var rm = RegisterMap.new()
    rm.register_axis(0, "🔥", "❄️")
    rm.register_axis(1, "💧", "🏜️")

    assert(rm.qubit("🔥") == 0)
    assert(rm.pole("🔥") == RegisterMap.NORTH)
    assert(rm.dim() == 4)  # 2^2

func test_basis_conversion():
    var rm = RegisterMap.new()
    rm.register_axis(0, "🔥", "❄️")
    rm.register_axis(1, "💧", "🏜️")
    rm.register_axis(2, "💨", "🌾")

    # |000⟩ = Hot, Wet, Flour
    assert(rm.basis_to_emojis(0) == ["🔥", "💧", "💨"])

    # |111⟩ = Cold, Dry, Grain
    assert(rm.basis_to_emojis(7) == ["❄️", "🏜️", "🌾"])

    # Round-trip
    assert(rm.emojis_to_basis(["🔥", "💧", "💨"]) == 0)

func test_phase_vs_population():
    """Verify we track populations (diagonals) correctly.

    Off-diagonal elements (coherences) exist but are not directly queried.
    """
    var qc = QuantumComputer.new("Test")
    qc.allocate_axis("🔥", "❄️")
    qc.allocate_axis("💧", "🏜️")

    # Apply drive - affects both diagonal and off-diagonal
    qc.apply_drive("🔥", 0.5, 0.1)

    # Query population (diagonal)
    var p_fire = qc.get_population("🔥")
    assert(p_fire > 0.0, "Fire population increased")

    # Trace preserved
    var trace = qc.get_trace()
    assert(abs(trace - 1.0) < 0.01, "Trace = 1.0")

    # Off-diagonals exist (coherences) but we don't query them in gameplay
    # They evolve correctly under Hamiltonian but player doesn't see phase
```

### Integration Tests

**Create**: `Tests/test_kitchen_analog.gd`

```gdscript
func test_kitchen_workflow():
    """Test complete bread workflow: spend → drive → measure."""

    var kitchen = QuantumKitchen_Biome.new()
    kitchen._initialize_kitchen()

    # Start in ground |111⟩
    assert(kitchen.p_ground() > 0.99)
    assert(kitchen.p_bread() < 0.01)

    # Player spends 50 fire credits
    kitchen.add_fire(50)  # 5 seconds of driving

    # Simulate 5 seconds
    for i in range(int(5.0 / 0.016)):  # ~312 frames
        kitchen._process(0.016)

    # Fire population should increase
    assert(kitchen.p_fire() > 0.1)

    # Add water and flour
    kitchen.add_water(50)
    kitchen.add_flour(50)

    # Simulate more
    for i in range(int(10.0 / 0.016)):
        kitchen._process(0.016)

    # Bread probability should be non-zero
    var p_bread = kitchen.p_bread()
    print("Bread probability: %.3f" % p_bread)

    # Harvest
    if p_bread > 0.3:
        var result = kitchen.harvest()
        print("Harvest result: %s" % result)
        assert(result["success"] == true)
```

---

## File Modification Summary

### New Files (4)
1. `Core/QuantumSubstrate/RegisterMap.gd` (150 lines) ← Copy from directive
2. `Core/QuantumSubstrate/HamiltonianBuilder.gd` (100 lines) ← Copy from directive
3. `Core/QuantumSubstrate/LindbladBuilder.gd` (80 lines) ← Copy from directive
4. `Core/Environment/BiomeFactory.gd` (60 lines) ← Copy from directive

### Modified Files (4)
1. **QuantumComputer.gd** - Add RegisterMap + helper methods (~200 lines added)
2. **QuantumKitchen_Biome.gd** - COMPLETE REWRITE using BREAD_WORKFLOW_IMPLEMENTATION.gd
3. **FarmGrid.gd** - REWRITE `_process_kitchens()` with corrected timing
4. **Icon.gd** - VERIFY structure (hamiltonian_couplings, lindblad_couplings)

### Test Files (2)
1. `Tests/test_register_map.gd` (unit tests)
2. `Tests/test_kitchen_analog.gd` (integration tests)

---

## Implementation Order (CORRECTED)

1. **RegisterMap.gd** ← Start here, copy from directive
2. **HamiltonianBuilder.gd** ← Copy from directive
3. **LindbladBuilder.gd** ← Copy from directive
4. **BiomeFactory.gd** ← Copy from directive
5. **QuantumComputer.gd** ← Add methods from directives
6. **QuantumKitchen_Biome.gd** ← COPY BREAD_WORKFLOW_IMPLEMENTATION.gd
7. **FarmGrid.gd** ← Rewrite kitchen integration with correct timing
8. **Create tests** ← Verify everything works
9. **Integration test** ← Full gameplay loop

---

## Critical Validation Points

### Physics Correctness
- [ ] Trace preserved: Tr(ρ) = 1.0 after every operation
- [ ] Hermiticity: H = H† (Hamiltonian is Hermitian)
- [ ] Probabilities sum: Σ P(|i⟩) = 1.0
- [ ] Marginals sum: P(north) + P(south) = 1.0 for each qubit
- [ ] Lindblad preserves positivity: ρ remains positive semidefinite
- [ ] Off-diagonals evolve correctly (even if not displayed)

### Architecture Correctness
- [ ] No direct emoji → index mapping without RegisterMap
- [ ] Icon couplings filtered by RegisterMap.has()
- [ ] Same emoji in different biomes → different coordinates
- [ ] RegisterMap.basis_to_emojis() round-trips correctly
- [ ] North ≠ South for all axes (validated at allocation)

### Workflow Correctness (CORRECTED)
- [ ] Resources SPENT FIRST to activate drives
- [ ] Kitchen evolves automatically in _process()
- [ ] Player manually triggers harvest
- [ ] Bread added to economy AFTER successful measurement
- [ ] Kitchen resets to |111⟩ after measurement

---

## Summary of Corrections

| Issue | Old (Wrong) | New (Correct) |
|-------|-------------|---------------|
| **Icon Example** | 🔥→🍞 coupling | 🔥→❄️ coupling (same qubit) |
| **Resource Timing** | Measure → consume | Spend → drive → measure |
| **Kitchen Processing** | Manual call each frame | Automatic _process() |
| **Harvest Trigger** | Automatic when ready | Player clicks button |
| **Phase Information** | Not mentioned | Exists in off-diagonals (unstated) |

---

## Estimated Implementation Time

- RegisterMap: 30 min (copy from directive)
- Builders: 30 min (copy from directive)
- BiomeFactory: 15 min (copy from directive)
- QuantumComputer: 1 hour (add methods)
- QuantumKitchen: 30 min (copy BREAD_WORKFLOW_IMPLEMENTATION.gd)
- FarmGrid: 1 hour (rewrite integration)
- Testing: 2 hours

**Total**: ~6 hours (reduced from 10 hours due to reference implementations)

---

## Reference Documents

1. `llm_inbox/analogue_upgrade_1/IMPORTANT_ADENDUM_NOT_ENTANGLED.md` - Philosophy
2. `llm_inbox/analogue_upgrade_1/SPACEWHEAT_MODEL_C_REGISTERMAP_DIRECTIVE.md` - Infrastructure
3. `llm_inbox/analogue_upgrade_1/SPACEWHEAT_KITCHEN_UPGRADE_DIRECTIVE_v2.md` - Kitchen physics
4. `llm_inbox/analogue_upgrade_1/BREAD_WORKFLOW_IMPLEMENTATION.gd` - **AUTHORITATIVE IMPLEMENTATION**

The BREAD_WORKFLOW_IMPLEMENTATION.gd file is the complete, working implementation. When in doubt, defer to it.
