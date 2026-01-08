# Analog Upgrade Implementation Plan
## Model C: RegisterMap-Based Architecture

**Status**: SPECIFICATION COMPLETE - READY TO IMPLEMENT
**Date**: 2026-01-05
**Scope**: Replace Bell state entanglement with analog population transfer

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

### New Philosophy

```
OLD: Create entangled superposition (|000⟩ + |111⟩)/√2
NEW: Drive population |111⟩ → |000⟩ via resonance

OLD: Bread = measurement of Bell state
NEW: Bread = high P(|000⟩) via detuning sweet spot

OLD: Emojis as dimensions
NEW: Emojis as labels on qubit poles
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ LAYER 1: GLOBAL PHYSICS (IconRegistry)                      │
│                                                              │
│  icons["🔥"].hamiltonian_couplings = {                       │
│      "❄️": Complex(0.3, 0),  ← "Fire couples to cold"       │
│      "🍞": Complex(0.15, 0)  ← "Fire couples to bread"      │
│  }                                                           │
│                                                              │
│  Defines HOW emojis interact (physics laws)                 │
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
│      "🍞": NOT PRESENT               ← Bread NOT registered │
│  }                                                           │
│                                                              │
│  Defines WHERE emojis live in this biome's Hilbert space    │
│                                                              │
│  Result: 🔥→🍞 coupling is SKIPPED (no error, just ignored) │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ LAYER 3: QUANTUM STATE (ComplexMatrix)                      │
│                                                              │
│  ρ[i, j] ← Integer indices only                             │
│  ρ[0,0] = P(|000⟩) = P(bread ready)                         │
│  ρ[7,7] = P(|111⟩) = P(ground state)                        │
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

**Key Functions**:
```gdscript
func register_axis(qubit_index: int, north_emoji: String, south_emoji: String)
func has(emoji: String) -> bool
func get(emoji: String) -> Dictionary  # {qubit: int, pole: int}
func qubit(emoji: String) -> int
func pole(emoji: String) -> int
func axis(qubit_index: int) -> Dictionary  # {north: emoji, south: emoji}
func dim() -> int  # 2^num_qubits
func basis_to_emojis(index: int) -> Array[String]
func emojis_to_basis(emojis: Array[String]) -> int
```

**Data Structures**:
```gdscript
const NORTH = 0  # |0⟩ state
const SOUTH = 1  # |1⟩ state

var coordinates: Dictionary = {}  # emoji → {qubit, pole}
var axes: Dictionary = {}  # qubit → {north, south}
var num_qubits: int = 0
```

**Status**: Complete specification provided ✅

---

#### 1.2 HamiltonianBuilder.gd (NEW)
**Path**: `Core/QuantumSubstrate/HamiltonianBuilder.gd`
**Lines**: ~100 lines
**Purpose**: Build Hamiltonian from Icons, filtered by RegisterMap

**Key Function**:
```gdscript
static func build(icons: Dictionary, register_map: RegisterMap) -> ComplexMatrix:
    """
    Iterate icons dictionary:
      For each source_emoji in icons:
        If source NOT in register_map: SKIP
        For each target_emoji in icon.hamiltonian_couplings:
          If target NOT in register_map: SKIP (print warning)
          Add coupling term to H

    Return hermitianized H = (H + H†)/2
    """
```

**Coupling Types**:
- **Self-energy**: Diagonal terms where source = target
- **Same-qubit**: σ_x rotation (|0⟩↔|1⟩)
- **Cross-qubit**: Conditional transitions

**Status**: Complete specification provided ✅

---

#### 1.3 LindbladBuilder.gd (NEW)
**Path**: `Core/QuantumSubstrate/LindbladBuilder.gd`
**Lines**: ~80 lines
**Purpose**: Build Lindblad operators from Icons, filtered by RegisterMap

**Key Function**:
```gdscript
static func build(icons: Dictionary, register_map: RegisterMap) -> Array[ComplexMatrix]:
    """
    Iterate icons dictionary:
      For each source_emoji in icons:
        If source NOT in register_map: SKIP
        For each target_emoji in icon.lindblad_couplings:
          If target NOT in register_map: SKIP
          Create L = amplitude * |to⟩⟨from|
          Append to operators array

    Return Array of L_k matrices
    """
```

**Status**: Complete specification provided ✅

---

#### 1.4 BiomeFactory.gd (NEW)
**Path**: `Core/Environment/BiomeFactory.gd`
**Lines**: ~60 lines
**Purpose**: Dynamic biome generation from axis configurations

**Key Function**:
```gdscript
static func create(axes: Array[Dictionary], biome_name: String) -> BiomeBase:
    """
    Example:
      BiomeFactory.create([
          {"north": "🔥", "south": "❄️"},
          {"north": "💧", "south": "🏜️"},
          {"north": "💨", "south": "🌾"}
      ], "Kitchen")

    Steps:
      1. Create BiomeBase
      2. Create QuantumComputer with RegisterMap
      3. Register each axis
      4. Gather relevant icons
      5. Build H and L operators
      6. Initialize to ground state |11...1⟩
    """
```

**Status**: Complete specification provided ✅

---

### Phase 2: Modify Existing Infrastructure

#### 2.1 QuantumComputer.gd (MODIFY)
**Additions**:
```gdscript
var register_map: RegisterMap = RegisterMap.new()  # ADD THIS

func allocate_axis(north_emoji: String, south_emoji: String) -> int:
    """Replace allocate_register. Returns qubit index."""
    # Validate emojis in IconRegistry
    # Call register_map.register_axis()
    # Resize density matrix
    # Initialize to ground

func has(emoji: String) -> bool:
    return register_map.has(emoji)

func qubit(emoji: String) -> int:
    return register_map.qubit(emoji)

func pole(emoji: String) -> int:
    return register_map.pole(emoji)

func get_marginal(qubit: int, target_pole: int) -> float:
    """Partial trace: P(qubit = pole)"""
    # Sum ρ[i,i] where bit matches target_pole

func get_population(emoji: String) -> float:
    """RegisterMap lookup + marginal"""
    var q = register_map.qubit(emoji)
    var p = register_map.pole(emoji)
    return get_marginal(q, p)

func get_basis_probability(index: int) -> float:
    """P(|index⟩) = ρ[index, index]"""
    return density_matrix.get_element(index, index).re

func apply_drive(emoji: String, rate: float, dt: float) -> bool:
    """Lindblad drive toward emoji's pole"""
    # RegisterMap lookup
    # Apply single-qubit Lindblad: L = √γ |target⟩⟨source|
    # Renormalize
```

**Remove**:
- Old `allocate_register()` signature (if it doesn't use RegisterMap)
- Direct emoji → index mappings

**Status**: Specification complete ✅

---

#### 2.2 QuantumComponent.gd (MODIFY - If used)
**Check**: Does kitchen still use QuantumComponent or QuantumComputer?

If QuantumComponent is still used:
```gdscript
func get_marginal_probability(qubit_index: int, target_state: int) -> float
func apply_lindblad_drive(qubit_index: int, target_state: int, rate: float, dt: float)
func get_basis_probability(basis_index: int) -> float
```

**Status**: Needs investigation ⚠️

---

#### 2.3 Icon.gd (VERIFY STRUCTURE)
**Check existing**:
```gdscript
@export var hamiltonian_couplings: Dictionary = {}  # emoji → Complex
@export var lindblad_couplings: Dictionary = {}  # emoji → Complex
@export var self_energy: Complex = null
```

**If missing**: Add these fields
**If different type**: Convert to Dictionary[String, Complex]

**Status**: Needs verification ⚠️

---

### Phase 3: Rewrite QuantumKitchen_Biome

#### 3.1 Remove Bell State Methods
**Delete**:
- `set_quantum_inputs_with_units()` (lines 439-467)
- `create_bread_entanglement()` (lines 470-514)
- `measure_as_bread()` (lines 517-566)
- `_measure_kitchen_basis_state()` (lines 569-588)
- `bell_inputs`, `bell_entanglement`, `bell_resource_units` variables

**Why**: These implement GHZ state creation, which is abandoned

---

#### 3.2 Rewrite Initialization
**OLD**:
```gdscript
func _initialize_kitchen_3qubit():
    # Manually allocate 3 registers
    # Manually merge components
```

**NEW**:
```gdscript
func _initialize_kitchen() -> void:
    """Use BiomeFactory to create 3-qubit system."""

    # Option A: Direct allocation
    quantum_computer = QuantumComputer.new("Kitchen")
    quantum_computer.register_map.register_axis(0, "🔥", "❄️")
    quantum_computer.register_map.register_axis(1, "💧", "🏜️")
    quantum_computer.register_map.register_axis(2, "💨", "🌾")

    # Build operators
    var icons = _gather_relevant_icons()
    hamiltonian = HamiltonianBuilder.build(icons, quantum_computer.register_map)
    lindblad_ops = LindbladBuilder.build(icons, quantum_computer.register_map)

    # Initialize to ground |111⟩
    quantum_computer.initialize_basis(7)

    # OR Option B: Use BiomeFactory
    # var kitchen = BiomeFactory.create([...], "Kitchen")
```

---

#### 3.3 Rewrite Hamiltonian
**OLD**:
```gdscript
func _build_kitchen_hamiltonian() -> ComplexMatrix:
    # Manually construct 8×8 matrix
    # Add detuning and coupling
```

**NEW**:
```gdscript
func build_hamiltonian() -> ComplexMatrix:
    """Build Kitchen H = H_icons + H_bread_resonance."""

    # Start with Icon-derived terms
    var icons = _gather_relevant_icons()
    var H = HamiltonianBuilder.build(icons, quantum_computer.register_map)

    # Add bread resonance coupling
    _add_bread_resonance(H)

    return H


func _add_bread_resonance(H: ComplexMatrix) -> void:
    """Add |000⟩ ↔ |111⟩ coupling with detuning.

    H_bread = Δ/2 (|0⟩⟨0| - |7⟩⟨7|) + Ω (|0⟩⟨7| + |7⟩⟨0|)
    """
    var omega = 0.15
    var delta = _compute_detuning()

    # Detuning: raise |000⟩, lower |111⟩
    H.set_element(0, 0, H.get_element(0, 0).add(Complex.new(delta / 2.0, 0.0)))
    H.set_element(7, 7, H.get_element(7, 7).add(Complex.new(-delta / 2.0, 0.0)))

    # Coupling
    H.set_element(0, 7, H.get_element(0, 7).add(Complex.new(omega, 0.0)))
    H.set_element(7, 0, H.get_element(7, 0).add(Complex.new(omega, 0.0)))


func _compute_detuning() -> float:
    """Detuning from ideal conditions."""
    var d2 = 0.0
    d2 += 2.0 * pow(p_fire() - 0.7, 2)   # Ideal: 70%
    d2 += 2.0 * pow(p_water() - 0.5, 2)  # Ideal: 50%
    d2 += 2.0 * pow(p_flour() - 0.6, 2)  # Ideal: 60%
    return sqrt(d2) * 5.0


func _gather_relevant_icons() -> Dictionary:
    """Get icons for emojis in kitchen."""
    var icons = {}
    for emoji in quantum_computer.register_map.coordinates:
        if IconRegistry.icons.has(emoji):
            icons[emoji] = IconRegistry.icons[emoji]
    return icons
```

---

#### 3.4 Rewrite Marginal Queries
**OLD**:
```gdscript
func get_temperature_hot() -> float:
    return kitchen_component.get_marginal_probability(0, 0)
```

**NEW**:
```gdscript
func p_fire() -> float:
    return quantum_computer.get_population("🔥")

func p_cold() -> float:
    return quantum_computer.get_population("❄️")

func p_water() -> float:
    return quantum_computer.get_population("💧")

func p_dry() -> float:
    return quantum_computer.get_population("🏜️")

func p_flour() -> float:
    return quantum_computer.get_population("💨")

func p_grain() -> float:
    return quantum_computer.get_population("🌾")

func p_bread() -> float:
    """P(|000⟩) = bread ready probability"""
    return quantum_computer.get_basis_probability(0)

func p_ground() -> float:
    """P(|111⟩) = ground state probability"""
    return quantum_computer.get_basis_probability(7)
```

---

#### 3.5 Rewrite Player Actions
**OLD**:
```gdscript
func add_fire(amount: float):
    active_drives.append({...})
```

**NEW**:
```gdscript
var active_drives: Array = []

func add_fire(amount: float) -> void:
    active_drives.append({
        "emoji": "🔥",
        "rate": 0.5,  # probability/second
        "remaining": amount * 2.0  # duration in seconds
    })

func add_water(amount: float) -> void:
    active_drives.append({"emoji": "💧", "rate": 0.5, "remaining": amount * 2.0})

func add_flour(amount: float) -> void:
    active_drives.append({"emoji": "💨", "rate": 0.5, "remaining": amount * 2.0})

func _process_drives(dt: float) -> void:
    """Apply queued drives each frame."""
    for drive in active_drives:
        if drive["remaining"] > 0:
            quantum_computer.apply_drive(drive["emoji"], drive["rate"], dt)
            drive["remaining"] -= dt

    # Remove completed
    active_drives = active_drives.filter(func(d): return d["remaining"] > 0)
```

---

#### 3.6 Rewrite Measurement
**OLD**:
```gdscript
func harvest() -> Dictionary:
    # Complex Bell state measurement
```

**NEW**:
```gdscript
func harvest() -> Dictionary:
    """Measure kitchen state, collapse to basis state.

    Outcome determined by current bread probability P(|000⟩).
    """
    if not quantum_computer:
        return {"success": false, "outcome": "💀"}

    # Sample basis state from probability distribution
    var outcome_basis = _sample_basis_state()

    # Determine bread yield
    var bread_yield = 0
    var outcome_emoji = "💀"

    if outcome_basis == 0:
        # Perfect: |000⟩ = 🔥💧💨
        bread_yield = 100
        outcome_emoji = "🍞"
    elif outcome_basis in [1, 2, 4]:
        # Partial: one axis wrong
        bread_yield = 50
        outcome_emoji = "🍞"
    else:
        # Failure: two or more axes wrong
        bread_yield = 0
        outcome_emoji = "💀"

    # Collapse to measured state
    quantum_computer.initialize_basis(outcome_basis)

    # Reset to ground for next bake
    reset_to_ground_state()

    return {
        "success": bread_yield > 0,
        "outcome": outcome_emoji,
        "basis_state": outcome_basis,
        "yield": bread_yield
    }


func _sample_basis_state() -> int:
    """Monte Carlo sampling from ρ diagonal."""
    var rho = quantum_computer.density_matrix
    var roll = randf()
    var cumulative = 0.0

    for i in range(8):
        cumulative += rho.get_element(i, i).re
        if roll < cumulative:
            return i

    return 7  # Default to ground
```

---

### Phase 4: Update FarmGrid Integration

#### 4.1 Remove DualEmojiQubit Creation
**File**: `Core/GameMechanics/FarmGrid.gd`
**Function**: `_process_kitchens(delta)` (lines 521-609)

**DELETE**:
```gdscript
# Lines 559-574: DualEmojiQubit creation
var fire_qubit = DualEmojiQubit.new("🔥", "❄️")
fire_qubit.theta = 0.0
# ... etc

# Lines 577-581: Bell state calls
kitchen_biome.set_quantum_inputs_with_units(...)
var bread_qubit = kitchen_biome.create_bread_entanglement()
var measured_bread = kitchen_biome.measure_as_bread()
```

**REPLACE WITH**:
```gdscript
# Check resource availability (lines 545-552 - KEEP)
var fire_credits = farm_economy.get_resource("🔥")
var water_credits = farm_economy.get_resource("💧")
var flour_credits = farm_economy.get_resource("💨")

if fire_credits < 10 or water_credits < 10 or flour_credits < 10:
    continue

# Convert to units
var fire_units = fire_credits / 10
var water_units = water_credits / 10
var flour_units = flour_credits / 10

# Activate Lindblad drives
kitchen_biome.add_fire(fire_units)
kitchen_biome.add_water(water_units)
kitchen_biome.add_flour(flour_units)

# Wait for drives to complete (or check if ready)
# Option A: Check bread probability
if kitchen_biome.p_bread() > 0.5:
    var result = kitchen_biome.harvest()

    if result["success"]:
        var bread_yield = result["yield"]
        var bread_credits = bread_yield * FarmEconomy.QUANTUM_TO_CREDITS

        # Consume inputs
        farm_economy.remove_resource("🔥", fire_credits, "kitchen_bake")
        farm_economy.remove_resource("💧", water_credits, "kitchen_bake")
        farm_economy.remove_resource("💨", flour_credits, "kitchen_bake")

        # Produce bread
        farm_economy.add_resource("🍞", bread_credits, "kitchen_bake")

        print("🍳 Kitchen: Baked %d bread (P(bread)=%.2f)" %
              [bread_yield, kitchen_biome.p_bread()])

# Option B: Drive continuously, measure when player chooses
```

**Status**: Needs design decision on trigger timing ⚠️

---

### Phase 5: Testing & Validation

#### 5.1 Unit Tests
**Create**: `Tests/test_register_map.gd`

```gdscript
func test_register_axis():
    var rm = RegisterMap.new()
    rm.register_axis(0, "🔥", "❄️")
    rm.register_axis(1, "💧", "🏜️")

    assert(rm.qubit("🔥") == 0)
    assert(rm.pole("🔥") == RegisterMap.NORTH)
    assert(rm.qubit("❄️") == 0)
    assert(rm.pole("❄️") == RegisterMap.SOUTH)

    assert(rm.dim() == 4)  # 2^2
    assert(rm.num_qubits == 2)

func test_basis_conversion():
    var rm = RegisterMap.new()
    rm.register_axis(0, "🔥", "❄️")
    rm.register_axis(1, "💧", "🏜️")
    rm.register_axis(2, "💨", "🌾")

    # |000⟩ = Hot, Wet, Flour
    var emojis_0 = rm.basis_to_emojis(0)
    assert(emojis_0 == ["🔥", "💧", "💨"])

    # |111⟩ = Cold, Dry, Grain
    var emojis_7 = rm.basis_to_emojis(7)
    assert(emojis_7 == ["❄️", "🏜️", "🌾"])

    # Round-trip
    assert(rm.emojis_to_basis(["🔥", "💧", "💨"]) == 0)
    assert(rm.emojis_to_basis(["❄️", "🏜️", "🌾"]) == 7)

func test_biome_isolation():
    # Same emoji in different biomes
    var biotic_rm = RegisterMap.new()
    biotic_rm.register_axis(0, "🌾", "👥")  # Wheat is north

    var kitchen_rm = RegisterMap.new()
    kitchen_rm.register_axis(2, "💨", "🌾")  # Wheat is south

    # Different coordinates, no collision
    assert(biotic_rm.qubit("🌾") == 0)
    assert(biotic_rm.pole("🌾") == RegisterMap.NORTH)

    assert(kitchen_rm.qubit("🌾") == 2)
    assert(kitchen_rm.pole("🌾") == RegisterMap.SOUTH)
```

#### 5.2 Integration Tests
**Create**: `Tests/test_kitchen_analog.gd`

```gdscript
func test_kitchen_initialization():
    var kitchen = BiomeFactory.create([
        {"north": "🔥", "south": "❄️"},
        {"north": "💧", "south": "🏜️"},
        {"north": "💨", "south": "🌾"}
    ], "Kitchen")

    # Should start in ground state |111⟩
    assert(kitchen.quantum_computer.get_basis_probability(7) > 0.99)
    assert(kitchen.quantum_computer.get_population("❄️") > 0.99)
    assert(kitchen.quantum_computer.get_population("🏜️") > 0.99)
    assert(kitchen.quantum_computer.get_population("🌾") > 0.99)

func test_lindblad_drives():
    var kitchen = BiomeFactory.create([...], "Kitchen")

    # Drive fire for 1 second at rate 0.5
    for i in range(60):  # 60 frames at 16ms
        kitchen.quantum_computer.apply_drive("🔥", 0.5, 0.016)

    # Fire population should increase
    var p_fire = kitchen.quantum_computer.get_population("🔥")
    assert(p_fire > 0.1, "Fire drive should increase 🔥 population")

    # Trace should be preserved
    var trace = kitchen.quantum_computer.get_trace()
    assert(abs(trace - 1.0) < 0.01, "Trace should be 1.0")

func test_detuning_effect():
    var kitchen = BiomeFactory.create([...], "Kitchen")

    # Far from ideal: high detuning
    var delta_initial = kitchen._compute_detuning()
    assert(delta_initial > 1.0)

    # Drive toward ideal conditions
    for i in range(100):
        kitchen.quantum_computer.apply_drive("🔥", 0.5, 0.016)
        kitchen.quantum_computer.apply_drive("💧", 0.5, 0.016)
        kitchen.quantum_computer.apply_drive("💨", 0.5, 0.016)

    # Detuning should decrease
    var delta_after = kitchen._compute_detuning()
    assert(delta_after < delta_initial)
```

---

## File Modification Summary

### New Files (4)
1. `Core/QuantumSubstrate/RegisterMap.gd` (150 lines)
2. `Core/QuantumSubstrate/HamiltonianBuilder.gd` (100 lines)
3. `Core/QuantumSubstrate/LindbladBuilder.gd` (80 lines)
4. `Core/Environment/BiomeFactory.gd` (60 lines)

### Modified Files (4)
1. `Core/QuantumSubstrate/QuantumComputer.gd`
   - Add `register_map: RegisterMap`
   - Add `allocate_axis()`, `get_marginal()`, `get_population()`, `apply_drive()`
   - Remove old `allocate_register()` if incompatible

2. `Core/Environment/QuantumKitchen_Biome.gd`
   - DELETE Bell state methods (lines 439-588, ~150 lines)
   - REWRITE initialization with RegisterMap
   - REWRITE Hamiltonian with HamiltonianBuilder
   - REWRITE marginal queries with `get_population()`
   - SIMPLIFY measurement (no more Bell state collapse)

3. `Core/GameMechanics/FarmGrid.gd`
   - REWRITE `_process_kitchens()` (lines 521-609)
   - REMOVE DualEmojiQubit creation
   - REPLACE Bell state calls with Lindblad drives
   - ADD bread probability check before harvest

4. `Core/QuantumSubstrate/Icon.gd` (VERIFY ONLY)
   - Check that `hamiltonian_couplings` and `lindblad_couplings` are Dictionaries

### Test Files (2 new)
1. `Tests/test_register_map.gd` (unit tests)
2. `Tests/test_kitchen_analog.gd` (integration tests)

---

## Implementation Order

1. **RegisterMap.gd** ← Start here, everything depends on this
2. **HamiltonianBuilder.gd**
3. **LindbladBuilder.gd**
4. **BiomeFactory.gd**
5. **Modify QuantumComputer.gd** to use RegisterMap
6. **Rewrite QuantumKitchen_Biome.gd** to use new architecture
7. **Update FarmGrid._process_kitchens()** to remove Bell state
8. **Create unit tests**
9. **Integration test in gameplay**

---

## Critical Validation Points

### Physics Correctness
- [ ] Trace preserved: Tr(ρ) = 1.0 after every operation
- [ ] Hermiticity: H = H† (Hamiltonian is Hermitian)
- [ ] Probabilities sum: Σ P(|i⟩) = 1.0
- [ ] Marginals sum: P(north) + P(south) = 1.0 for each qubit
- [ ] Lindblad preserves positivity: ρ remains positive semidefinite

### Architecture Correctness
- [ ] No direct emoji → index mapping without RegisterMap
- [ ] Icon couplings filtered by RegisterMap.has()
- [ ] Same emoji in different biomes → different coordinates
- [ ] RegisterMap.basis_to_emojis() round-trips correctly
- [ ] North ≠ South for all axes (validated at allocation)

### Gameplay Correctness
- [ ] Player can add fire/water/flour
- [ ] Drives increase corresponding populations
- [ ] Bread probability increases at resonance
- [ ] Measurement collapses to basis state
- [ ] Resources consumed and produced correctly

---

## Estimated Implementation Time

- RegisterMap: 1 hour
- Builders (Hamiltonian + Lindblad): 2 hours
- BiomeFactory: 30 minutes
- QuantumComputer modifications: 1 hour
- QuantumKitchen rewrite: 2 hours
- FarmGrid integration: 1 hour
- Testing: 2 hours

**Total**: ~10 hours

---

## Key Differences from Previous Implementation

| Aspect | Bell State (OLD) | Analog Transfer (NEW) |
|--------|------------------|------------------------|
| **Quantum State** | (|000⟩ + |111⟩)/√2 superposition | Population in |111⟩ → |000⟩ |
| **Player Action** | Inject DualEmojiQubits | Activate Lindblad drives |
| **Bread Creation** | Measure Bell state collapse | High P(|000⟩) via resonance |
| **Complexity** | Entanglement creation methods | Simple drive activation |
| **Physics** | GHZ state entanglement | Independent axis alignment |
| **Code Lines** | 150 lines of Bell state logic | 20 lines of drive queueing |

---

## Summary

**Philosophy**: Simplify from exotic entanglement to classical-ish population transfer with quantum mechanics flavor (coherent rotation, resonance, measurement).

**Infrastructure**: RegisterMap is the critical new layer that separates physics (Icons) from coordinates (RegisterMap) from state (density matrix).

**Kitchen**: Three independent axes that player must align simultaneously. Detuning Hamiltonian provides "sweet spot" physics - when conditions are right, population flows |111⟩ → |000⟩.

**Implementation**: Start with RegisterMap, build outward. Remove Bell state complexity, replace with simple Lindblad drives.
