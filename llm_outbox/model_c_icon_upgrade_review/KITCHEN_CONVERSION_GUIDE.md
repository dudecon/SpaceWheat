# Kitchen Model C Conversion Guide - Step-by-Step

**Date:** 2026-01-07
**Purpose:** Detailed instructions for converting QuantumKitchen_Biome from Legacy Bath to Model C

---

## Overview

This guide provides **concrete, copy-paste-ready code** for converting Kitchen from QuantumBath to QuantumComputer. Kitchen is the ideal first biome because:

1. **Perfect fit:** Already 3-qubit system (8 basis states)
2. **Simple structure:** Temperature × Moisture × Substance
3. **Well-defined:** Clear ground state and bread state
4. **Isolated:** Minimal dependencies on other biomes

---

## Current State (Legacy Bath)

### Current Initialization (Lines ~50-80)

```gdscript
# Current Kitchen initialization (Legacy)
func _initialize_bath() -> void:
    bath = QuantumBath.new()

    # 8 basis states (3-emoji strings)
    var basis_emojis = [
        "🔥💧💨",  # |000⟩ Hot, Wet, Flour = BREAD READY
        "🔥💧🌾",  # |001⟩ Hot, Wet, Grain
        "🔥🏜️💨",  # |010⟩ Hot, Dry, Flour
        "🔥🏜️🌾",  # |011⟩ Hot, Dry, Grain
        "❄️💧💨",  # |100⟩ Cold, Wet, Flour
        "❄️💧🌾",  # |101⟩ Cold, Wet, Grain
        "❄️🏜️💨",  # |110⟩ Cold, Dry, Flour
        "❄️🏜️🌾",  # |111⟩ Cold, Dry, Grain = GROUND STATE
    ]

    bath.initialize_with_emojis(basis_emojis)

    # Initialize to ground state |111⟩ (index 7)
    bath.set_pure_state(7)

    # Get Icons from IconRegistry
    var icon_registry = get_node("/root/IconRegistry")
    var icons = []
    for emoji_str in basis_emojis:
        for char in emoji_str:
            var icon = icon_registry.get_icon(char)
            if icon and icon not in icons:
                icons.append(icon)

    # Build operators from Icons
    bath.build_hamiltonian_from_icons(icons)
    bath.build_lindblad_from_icons(icons)
```

### Current Evolution (Lines ~120-150)

```gdscript
# Current evolution loop (Legacy)
func _process(delta: float):
    if not bath:
        return

    # Evolve bath
    bath.evolve(delta * evolution_speed)

    # Check for bread production
    var p_bread = bath.get_probability("🔥💧💨")
    if p_bread > BREAD_THRESHOLD:
        _produce_bread()
```

---

## Target State (Model C)

### New Initialization (Model C)

```gdscript
# NEW: Model C initialization
var quantum_computer: QuantumComputer = null

func _initialize_quantum_computer() -> void:
    # Create QuantumComputer
    quantum_computer = QuantumComputer.new("Kitchen")

    # Allocate 3 qubits with RegisterMap
    quantum_computer.allocate_axis(0, "🔥", "❄️")  # Temperature
    quantum_computer.allocate_axis(1, "💧", "🏜️")  # Moisture
    quantum_computer.allocate_axis(2, "💨", "🌾")  # Substance

    print("🍳 Kitchen RegisterMap:")
    print("  Qubit 0 (Temp):      |0⟩=🔥 (Hot)  |1⟩=❄️ (Cold)")
    print("  Qubit 1 (Moisture):  |0⟩=💧 (Wet)  |1⟩=🏜️ (Dry)")
    print("  Qubit 2 (Substance): |0⟩=💨 (Flour) |1⟩=🌾 (Grain)")
    print("  Hilbert space: 8 basis states (2^3)")

    # Initialize to ground state |111⟩ = |❄️🏜️🌾⟩ (Cold, Dry, Grain)
    quantum_computer.initialize_basis(7)  # Binary 111 = 7

    # Get Icons from IconRegistry
    var icon_registry = get_node("/root/IconRegistry")
    var icon_emojis = ["🔥", "❄️", "💧", "🏜️", "💨", "🌾"]
    var icons = {}

    for emoji in icon_emojis:
        var icon = icon_registry.get_icon(emoji)
        if icon:
            icons[emoji] = icon
        else:
            push_warning("⚠️ Kitchen Icon not found: %s" % emoji)

    print("  Icons loaded: %d" % icons.size())

    # Build operators using Hamiltonian/LindbladBuilder
    var H = HamiltonianBuilder.build(icons, quantum_computer.register_map)
    var L_ops = LindbladBuilder.build(icons, quantum_computer.register_map)

    # Store operators in QuantumComputer
    quantum_computer.hamiltonian = H
    quantum_computer.lindblad_operators = L_ops

    print("  Hamiltonian: %dx%d matrix" % [H.rows, H.cols])
    print("  Lindblad operators: %d terms" % L_ops.size())
    print("✅ Kitchen quantum computer initialized\n")
```

### New Evolution (Model C)

```gdscript
# NEW: Model C evolution loop
func _process(delta: float):
    if not quantum_computer:
        return

    # Apply player drives (if any energy spent)
    if pending_heat_drive > 0:
        quantum_computer.apply_drive("🔥", pending_heat_drive, delta)
        pending_heat_drive = 0

    if pending_moisture_drive > 0:
        quantum_computer.apply_drive("💧", pending_moisture_drive, delta)
        pending_moisture_drive = 0

    # Apply decay (relaxation toward ground state)
    quantum_computer.apply_decay(delta * evolution_speed)

    # Evolve under Hamiltonian + Lindblad
    quantum_computer.evolve(delta * evolution_speed)

    # Check for bread production
    var bread_emojis = ["🔥", "💧", "💨"]  # Hot, Wet, Flour
    var p_bread = quantum_computer.get_population(bread_emojis)

    if p_bread > BREAD_THRESHOLD:
        _produce_bread()
```

### New State Queries (Model C)

```gdscript
# NEW: Query state populations
func get_bread_probability() -> float:
    return quantum_computer.get_population(["🔥", "💧", "💨"])

func get_temperature() -> float:
    # P(Hot) - P(Cold)
    var p_hot = quantum_computer.get_population("🔥")
    var p_cold = quantum_computer.get_population("❄️")
    return p_hot - p_cold

func get_moisture() -> float:
    # P(Wet) - P(Dry)
    var p_wet = quantum_computer.get_population("💧")
    var p_dry = quantum_computer.get_population("🏜️")
    return p_wet - p_dry

func get_substance() -> float:
    # P(Flour) - P(Grain)
    var p_flour = quantum_computer.get_population("💨")
    var p_grain = quantum_computer.get_population("🌾")
    return p_flour - p_grain
```

### New Measurement (Model C)

```gdscript
# NEW: Measure and collapse
func harvest_plot(plot_index: int) -> Dictionary:
    # Measure substance qubit (index 2)
    var measurement = quantum_computer.measure_register(2)

    var result = {}
    if measurement == 0:  # North pole = 💨 (Flour)
        result["type"] = "flour"
        result["emoji"] = "💨"
    else:  # South pole = 🌾 (Grain)
        result["type"] = "grain"
        result["emoji"] = "🌾"

    # State has collapsed to measurement result
    return result
```

---

## Step-by-Step Conversion

### Step 1: Add QuantumComputer Member Variable

**File:** `Core/Environment/QuantumKitchen_Biome.gd`
**Location:** Top of class (around line 10)

```gdscript
# Add this member variable
var quantum_computer: QuantumComputer = null
```

---

### Step 2: Replace Bath Initialization

**File:** `Core/Environment/QuantumKitchen_Biome.gd`
**Location:** Replace `_initialize_bath()` function

**Before:**
```gdscript
func _initialize_bath() -> void:
    bath = QuantumBath.new()
    # ... Legacy initialization
```

**After:**
```gdscript
func _initialize_bath() -> void:
    # Call Model C initialization instead
    _initialize_quantum_computer()

func _initialize_quantum_computer() -> void:
    # Copy code from "New Initialization (Model C)" section above
    quantum_computer = QuantumComputer.new("Kitchen")
    # ... (see above for full implementation)
```

---

### Step 3: Update Evolution Loop

**File:** `Core/Environment/QuantumKitchen_Biome.gd`
**Location:** Replace `_process()` function

**Before:**
```gdscript
func _process(delta: float):
    if bath:
        bath.evolve(delta * evolution_speed)
```

**After:**
```gdscript
func _process(delta: float):
    if quantum_computer:
        # Apply drives (player actions)
        if pending_heat_drive > 0:
            quantum_computer.apply_drive("🔥", pending_heat_drive, delta)
            pending_heat_drive = 0

        # Apply decay
        quantum_computer.apply_decay(delta * evolution_speed)

        # Evolve
        quantum_computer.evolve(delta * evolution_speed)
```

---

### Step 4: Update State Queries

**File:** `Core/Environment/QuantumKitchen_Biome.gd`
**Location:** Find all `bath.get_probability()` calls

**Before:**
```gdscript
var p_bread = bath.get_probability("🔥💧💨")
```

**After:**
```gdscript
var p_bread = quantum_computer.get_population(["🔥", "💧", "💨"])
```

**Search pattern:** Look for all calls to:
- `bath.get_probability()`
- `bath.get_complex_amplitude()`
- `bath.set_pure_state()`

Replace with Model C equivalents:
- `quantum_computer.get_population()`
- `quantum_computer.get_basis_probability()`
- `quantum_computer.initialize_basis()`

---

### Step 5: Update Visualization

**File:** `Core/Visualization/QuantumNode.gd`
**Location:** Update state query logic

**Before:**
```gdscript
func _update_from_bath():
    if bath:
        var prob = bath.get_probability(current_emoji)
        opacity = prob
```

**After:**
```gdscript
func _update_from_quantum_computer():
    if quantum_computer:
        var prob = quantum_computer.get_population(current_emoji)
        opacity = prob
```

**Note:** This requires QuantumNode to support both Bath and QuantumComputer queries during transition.

---

### Step 6: Add Imports

**File:** `Core/Environment/QuantumKitchen_Biome.gd`
**Location:** Top of file

```gdscript
# Add these preloads
const QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
const HamiltonianBuilder = preload("res://Core/QuantumSubstrate/HamiltonianBuilder.gd")
const LindbladBuilder = preload("res://Core/QuantumSubstrate/LindbladBuilder.gd")
const RegisterMap = preload("res://Core/QuantumSubstrate/RegisterMap.gd")
```

---

### Step 7: Update Rebuild Method

**File:** `Core/Environment/QuantumKitchen_Biome.gd`
**Location:** Replace `_rebuild_bath_operators()`

**Before:**
```gdscript
func _rebuild_bath_operators() -> void:
    if bath:
        bath.build_hamiltonian_from_icons(icons)
        bath.build_lindblad_from_icons(icons)
```

**After:**
```gdscript
func _rebuild_quantum_operators() -> void:
    if not quantum_computer:
        return

    # Rebuild operators from Icons
    var icon_registry = get_node("/root/IconRegistry")
    var icon_emojis = ["🔥", "❄️", "💧", "🏜️", "💨", "🌾"]
    var icons = {}

    for emoji in icon_emojis:
        var icon = icon_registry.get_icon(emoji)
        if icon:
            icons[emoji] = icon

    # Rebuild H and L operators
    quantum_computer.hamiltonian = HamiltonianBuilder.build(icons, quantum_computer.register_map)
    quantum_computer.lindblad_operators = LindbladBuilder.build(icons, quantum_computer.register_map)

    print("🔧 Kitchen operators rebuilt")
```

---

## Testing Checklist

### Unit Tests

- [ ] **Test 1: Initialization**
  ```gdscript
  # Verify RegisterMap setup
  assert(quantum_computer.register_map.num_qubits == 3)
  assert(quantum_computer.register_map.dim() == 8)
  assert(quantum_computer.register_map.qubit("🔥") == 0)
  assert(quantum_computer.register_map.pole("🔥") == RegisterMap.NORTH)
  ```

- [ ] **Test 2: Ground State**
  ```gdscript
  # Verify initial state is |111⟩ = |❄️🏜️🌾⟩
  var p_ground = quantum_computer.get_population(["❄️", "🏜️", "🌾"])
  assert(abs(p_ground - 1.0) < 0.01)  # Should be ~100%
  ```

- [ ] **Test 3: Hamiltonian**
  ```gdscript
  # Verify Hermiticity
  var H = quantum_computer.hamiltonian
  for i in range(H.rows):
      for j in range(H.cols):
          var Hij = H.get(i, j)
          var Hji_conj = H.get(j, i).conjugate()
          assert(Hij.equals(Hji_conj, 1e-10))
  ```

- [ ] **Test 4: Evolution**
  ```gdscript
  # Apply heat drive, verify state changes
  quantum_computer.apply_drive("🔥", 1.0, 1.0)
  quantum_computer.evolve(1.0)
  var p_hot = quantum_computer.get_population("🔥")
  assert(p_hot > 0.0)  # Should increase from 0
  ```

- [ ] **Test 5: Bread Production**
  ```gdscript
  # Drive toward bread state, verify threshold
  quantum_computer.apply_drive("🔥", 10.0, 1.0)
  quantum_computer.apply_drive("💧", 10.0, 1.0)
  quantum_computer.apply_drive("💨", 10.0, 1.0)
  quantum_computer.evolve(10.0)

  var p_bread = quantum_computer.get_population(["🔥", "💧", "💨"])
  assert(p_bread > 0.5)  # Should approach bread state
  ```

---

### Integration Tests

- [ ] **Test 6: Full Gameplay Loop**
  1. Start Kitchen biome
  2. Plant plots
  3. Apply heat/moisture/flour energy
  4. Wait for bread probability > threshold
  5. Harvest plots
  6. Verify bread produced
  7. Check resource accounting

- [ ] **Test 7: Visualization**
  1. Open Kitchen biome
  2. Verify bubbles appear
  3. Verify bubbles animate (opacity changes)
  4. Verify emoji labels correct
  5. Check performance (< 16ms per frame)

- [ ] **Test 8: Persistence**
  1. Save game with Kitchen in mid-evolution
  2. Reload game
  3. Verify quantum state preserved
  4. Verify evolution continues correctly

---

### Performance Tests

- [ ] **Test 9: Evolution Speed**
  ```gdscript
  # Measure time for 1000 evolution steps
  var start = Time.get_ticks_usec()
  for i in range(1000):
      quantum_computer.evolve(0.016)  # 60 FPS timestep
  var elapsed = (Time.get_ticks_usec() - start) / 1000.0  # ms
  print("1000 evolutions: %.2f ms (%.2f ms/step)" % [elapsed, elapsed/1000.0])
  assert(elapsed < 1000)  # Should be < 1 second total
  ```

- [ ] **Test 10: Query Speed**
  ```gdscript
  # Measure time for 1000 population queries
  var start = Time.get_ticks_usec()
  for i in range(1000):
      quantum_computer.get_population(["🔥", "💧", "💨"])
  var elapsed = (Time.get_ticks_usec() - start) / 1000.0  # ms
  print("1000 queries: %.2f ms (%.2f ms/query)" % [elapsed, elapsed/1000.0])
  assert(elapsed < 100)  # Should be < 0.1 ms per query
  ```

---

## Expected Behavior

### Before Conversion (Legacy)

```
Kitchen initialized with 8 basis states:
  |0⟩ = "🔥💧💨" (Bread Ready)
  |7⟩ = "❄️🏜️🌾" (Ground State)

Evolution:
  ❄️🏜️🌾 → (apply heat/moisture/flour) → 🔥💧💨

Bread production:
  P("🔥💧💨") > 0.7 → produce bread → collapse to ground state
```

### After Conversion (Model C)

```
Kitchen initialized with 3 qubits (8 basis states):
  Qubit 0: 🔥 (Hot) / ❄️ (Cold)
  Qubit 1: 💧 (Wet) / 🏜️ (Dry)
  Qubit 2: 💨 (Flour) / 🌾 (Grain)

  |000⟩ = |🔥💧💨⟩ (Bread Ready)
  |111⟩ = |❄️🏜️🌾⟩ (Ground State)

Evolution:
  |111⟩ → (apply drives) → |000⟩

Bread production:
  P(|🔥💧💨⟩) > 0.7 → produce bread → collapse to ground state
```

**Key difference:** Same physics, different representation.
- Legacy: Direct emoji strings
- Model C: Qubit product states

**User experience:** Identical (same visual effects, same gameplay).

---

## Migration Strategy

### Option 1: Clean Break (Recommended)

1. Create `QuantumKitchen_Biome_ModelC.gd` as new file
2. Copy current Kitchen, apply all changes
3. Swap in Farm.gd: `kitchen_biome = QuantumKitchen_Biome_ModelC.new()`
4. Test thoroughly
5. Delete old `QuantumKitchen_Biome.gd` when confident

**Pros:** Easy to revert, clear comparison
**Cons:** Temporary code duplication

---

### Option 2: In-Place Conversion

1. Modify `QuantumKitchen_Biome.gd` directly
2. Keep `bath` and `quantum_computer` both present
3. Add flag: `const USE_MODEL_C = true`
4. Branch on flag in all methods
5. Remove Legacy code when confident

**Pros:** Single file, gradual transition
**Cons:** Messy during transition

---

### Option 3: Adapter Pattern

1. Create `QuantumBackend` interface
2. Implement `LegacyBathBackend` and `ModelCBackend`
3. Kitchen uses interface methods
4. Swap backend at runtime

**Pros:** Clean abstraction, easy A/B testing
**Cons:** Most complex, over-engineered for single biome

---

**Recommendation:** Use **Option 1 (Clean Break)** for Kitchen. It's simple, safe, and easy to test side-by-side.

---

## Rollback Plan

If Model C conversion fails or has issues:

1. **Immediate rollback:**
   ```gdscript
   # In Farm.gd
   # kitchen_biome = QuantumKitchen_Biome_ModelC.new()  # Broken
   kitchen_biome = QuantumKitchen_Biome.new()  # Restore Legacy
   ```

2. **Debug in isolation:**
   - Keep Model C version in separate file
   - Fix issues without affecting live game
   - Re-attempt when ready

3. **Preserve Legacy:**
   - Don't delete `QuantumKitchen_Biome.gd` until ALL biomes converted
   - Keep as reference implementation

---

## Common Issues and Solutions

### Issue 1: "Hamiltonian not Hermitian"

**Symptom:** Warning during operator build

**Cause:** Icon couplings not symmetric

**Solution:** Check Icon definitions, ensure `A → B` coupling equals `B → A` coupling

---

### Issue 2: "Population queries return 0"

**Symptom:** All `get_population()` calls return 0

**Cause:** Emoji not in RegisterMap

**Solution:** Verify RegisterMap has all 6 emojis registered:
```gdscript
print(quantum_computer.register_map.has("🔥"))  # Should be true
```

---

### Issue 3: "Evolution is too slow"

**Symptom:** Bread never reaches threshold

**Cause:** Lindblad rates too small

**Solution:** Increase `evolution_speed` multiplier or review Icon rates

---

### Issue 4: "Bread probability > 1.0"

**Symptom:** Invalid probability returned

**Cause:** Multi-emoji query bug

**Solution:** Ensure emoji array passed correctly:
```gdscript
# Wrong
var p = quantum_computer.get_population("🔥💧💨")  # Single string

# Right
var p = quantum_computer.get_population(["🔥", "💧", "💨"])  # Array
```

---

### Issue 5: "Visualization doesn't update"

**Symptom:** Bubbles frozen

**Cause:** QuantumNode still queries `bath` instead of `quantum_computer`

**Solution:** Update QuantumNode to support both:
```gdscript
if quantum_computer:
    prob = quantum_computer.get_population(emoji)
elif bath:
    prob = bath.get_probability(emoji)
```

---

## Success Criteria

Kitchen Model C conversion is **complete** when:

✅ Kitchen uses QuantumComputer (not QuantumBath)
✅ Bread production works identically to Legacy
✅ All unit tests pass
✅ All integration tests pass
✅ Performance within 20% of Legacy (< 1ms per evolution step)
✅ Visualization looks identical
✅ No compilation errors or warnings
✅ Code is clean (no commented-out Legacy code)

---

## Next Steps After Kitchen

Once Kitchen conversion is proven successful:

1. **Document learnings** - What worked, what didn't
2. **Refine process** - Update this guide with discoveries
3. **Convert BioticFlux** - Apply same pattern (6 emojis → 3 qubits)
4. **Convert Market** - 8 emojis → 3 qubits
5. **Convert Forest** - 22 emojis → 5 qubits (most complex)
6. **Update visualization** - Full QuantumComputer support
7. **Remove Legacy** - Delete QuantumBath.gd

---

This guide provides everything needed to convert Kitchen from Legacy Bath to Model C. Follow step-by-step, test thoroughly, and document any issues for future biome conversions.
