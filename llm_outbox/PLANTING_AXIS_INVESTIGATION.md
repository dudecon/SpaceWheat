# 🔍 PLANTING EMOJI-BIOME AXIS MISMATCH - Detailed Investigation

**Status:** Issue Identified - No Fix Applied (as requested)
**Date:** 2026-01-16

---

## 📊 SUMMARY

When planting an emoji in a biome, the system:
1. **Checks** if the biome's quantum_computer supports the emoji pair (warns if not)
2. **Registers** the measurement axis anyway (no blocking)
3. **Returns success** - plant proceeds normally
4. **Result:** Plot is planted but has no quantum backing in that biome's quantum state

---

## 🔴 THE ISSUE

### Test Case That Triggered It
```
Test: Edge Cases → Plant 🍞 (bread) in Market biome
Biome Quantum State: Has axes [🐂/🐻, 💰/💳, 🏛️/🏚️]
Planted Axis: 🍞/💨
Result: ⚠️ Warning printed, but plant SUCCEEDS

Output:
  ⚠️ Biome Market quantum system doesn't have 🍞/💨 axis
  🌱 Plot (0, 0): registered measurement axis (🍞/💨) in Market biome bath
```

---

## 🔧 TECHNICAL FLOW

### Step 1: FarmGrid.plant() - Line 774-778

```gdscript
# VALIDATION: Check if biome quantum system supports this emoji pair
if plot_biome.has_method("supports_emoji_pair"):
    if not plot_biome.supports_emoji_pair(plot.north_emoji, plot.south_emoji):
        push_warning("⚠️ Biome %s quantum system doesn't have %s/%s axis - plant may not function correctly" % [
            plot_biome.get_biome_type(), plot.north_emoji, plot.south_emoji])
        # Don't block planting, but warn - allows player experimentation
```

**Key:** Comment explicitly says "Don't block planting" - this is intentional design

### Step 2: BasePlot.plant() - Line 216-220

```gdscript
if biome.has_method("allocate_subplot_for_plot"):
    bath_subplot_id = biome.allocate_subplot_for_plot(grid_position, north_emoji, south_emoji)
    if bath_subplot_id < 0:
        push_error("Failed to allocate subplot for plot %s!" % grid_position)
        return false
```

**Action:** Allocates subplot (registers metadata, doesn't validate axis exists)

Immediately after (line 231-232):
```gdscript
print("🌱 Plot %s: registered measurement axis (%s/%s) in %s biome bath" % [
    grid_position, north_emoji, south_emoji, biome.get_biome_type()])
```

**Result:** Print happens REGARDLESS of whether axis was validated

---

## 🧬 HOW AXIS VALIDATION WORKS

### BiomeBase.supports_emoji_pair() - Line 2068-2102

```gdscript
func supports_emoji_pair(north: String, south: String) -> bool:
    # 1. Check registered pairings
    if emoji_pairings.has(north) and emoji_pairings[north] == south:
        return true

    # 2. Check bath emoji list (Model B)
    if bath and bath.emoji_list:
        # Both emojis must be in bath
        for state in bath.emoji_list:
            if north in state: has_north = true
            if south in state: has_south = true
        if has_north and has_south: return true

    # 3. Check quantum_computer (Model C - current)
    if quantum_computer and quantum_computer.has_method("has_emoji"):
        if quantum_computer.has_emoji(north) and quantum_computer.has_emoji(south):
            return true

    return false
```

### For Market Biome (Model C)

**Quantum Computer State:** 3 qubits
```
Qubit 0: |0⟩=🐂 |1⟩=🐻
Qubit 1: |0⟩=💰 |1⟩=💳
Qubit 2: |0⟩=🏛️ |1⟩=🏚️
```

**Valid Axes:** Only these pairs are supported:
- 🐂/🐻
- 💰/💳
- 🏛️/🏚️

**Attempted Plant:** 🍞/💨
- ✗ 🍞 not in quantum_computer eigenstate decomposition
- ✗ 💨 not in quantum_computer eigenstate decomposition
- **Result:** `supports_emoji_pair("🍞", "💨")` returns `false`

---

## ⚠️ WHAT HAPPENS NEXT

When the planted plot is used (MEASURE/POP/HARVEST), the quantum operation may:

### Scenario A: If using bath.measure_marginal_axis()
```gdscript
# BasePlot.measure() - Line 278
var outcome_emoji = parent_biome.bath.measure_marginal_axis(north_emoji, south_emoji)
if outcome_emoji == "":
    push_error("Bath measurement failed for plot %s!" % grid_position)
    return ""
```

**What happens:**
- If bath is a QuantumBath instance, it sums over states containing 🍞 or 💨
- If no states contain those emojis, sum = 0
- Returns "" (empty string)
- MEASURE fails with error

### Scenario B: If using quantum_computer.measure_register()
```gdscript
# QuantumComputer.measure_register(component, register_id)
```

**What happens:**
- If 🍞/💨 axes don't exist in the register map, lookup fails
- Returns undefined/error outcome
- Measurement undefined behavior

---

## 🤔 DESIGN INTENT vs IMPLEMENTATION

### Current Design (From code comment)
> "Don't block planting, but warn - allows player experimentation"

**Explicit intent:** Allow planting "weird" emoji combinations

### But Implementation is Incomplete

**Missing Pieces:**
1. **No graceful fallback** - What should measurement return?
2. **No auto-expansion** - Should quantum system expand to add new axis?
3. **No documentation** - What are the implications?
4. **Inconsistent handling** - Some paths may fail, others may silently return wrong values

---

## 🔍 WHICH BIOMES ARE AFFECTED?

### Market Biome
- **Type:** Model C (QuantumComputer)
- **Registered Axes:** [🐂/🐻, 💰/💳, 🏛️/🏚️]
- **Plantable:** All PlantingCapability emojis (may mismatch)
- **Risk:** **HIGH** - Can plant wheat/tomato/mushroom which don't exist in quantum state

### QuantumKitchen Biome
- **Type:** Model C (QuantumComputer)
- **Registered Axes:** [🔥/❄️, 💧/🏜️, 💨/🌾]
- **Plantable:** All PlantingCapability emojis
- **Risk:** **MEDIUM** - Kitchen has flour/bread axes, but can still plant incompatible items

### BioticFlux Biome
- **Type:** Model C (QuantumComputer)
- **Registered Axes:** [☀/🌙, 🌾/🍄, 🍂/💀]
- **Plantable:** All PlantingCapability emojis
- **Risk:** **MEDIUM** - Has wheat/mushroom axes, but can plant others

### ForestEcosystem Biome
- **Type:** Model C (QuantumComputer)
- **Registered Axes:** [☀/🌙, 🌿/🍂, 🐇/🐺, 💧/🔥, 🌲/🏡]
- **Plantable:** All PlantingCapability emojis
- **Risk:** **LOW** - Has many axes, fewer incompatibilities

---

## 📋 SPECIFIC SCENARIOS

### Scenario 1: Plant Wheat (🌾) in Market
```
Biome: Market
Axes: [🐂/🐻, 💰/💳, 🏛️/🏚️]
Plant: 🌾 (wheat)

Check: supports_emoji_pair("🌾", "?")
  ✗ 🌾 not in Market quantum_computer
  ✗ No pairing for 🌾
  Result: false (WARNS)

But plant SUCCEEDS anyway

Later MEASURE:
  plot.north_emoji = "🌾"
  bath.measure_marginal_axis("🌾", south_emoji)
  → Sums over states containing "🌾"
  → No states have "🌾"
  → Returns ""
  → plot.measure() fails with error
```

### Scenario 2: Plant Bread (🍞) in Market (from test)
```
Test output:
  ⚠️ Biome Market quantum system doesn't have 🍞/💨 axis - plant may not function correctly
  🌱 Plot (0, 0): registered measurement axis (🍞/💨) in Market biome bath
  ✅ Plant succeeded on empty plot

This demonstrates the issue perfectly:
  1. Warning issued ✓
  2. Plant succeeded ✓
  3. But no way to measure/harvest later ✗
```

### Scenario 3: Entanglement with Mismatched Axis
```
Plot A: 🍞/💨 (bread - in Kitchen, valid)
Plot B: 🍞/💨 (bread - in Market, INVALID)

Entangle A-B:
  → Try to create cross-biome entanglement
  → But Plot B's axes don't exist in Market quantum state
  → Gate application: undefined behavior
```

---

## 🎯 KEY QUESTIONS

1. **Should we prevent planting incompatible emojis?**
   - Current: Warning only
   - Alternative: Block with error

2. **Should we auto-expand the quantum system?**
   - Current: No - axes are fixed at biome init
   - Alternative: Dynamically add new axes on plant

3. **What should measurement return for invalid axes?**
   - Current: Crashes or returns ""
   - Alternative: Return random outcome? Return default emoji?

4. **Should there be multiple plantable capabilities per biome?**
   - Current: All plots can plant same emojis
   - Alternative: Restrict planting by biome

5. **Is this a feature or a bug?**
   - The code comment suggests feature ("allows experimentation")
   - But behavior is undefined/broken

---

## 📊 CURRENT BEHAVIOR TABLE

| Scenario | Plant | Quantum Axis Exists | Measurement | POP | Status |
|----------|-------|-------------------|-------------|-----|--------|
| Wheat in BioticFlux | ✅ | ✅ (🌾/🍄) | ✅ | ✅ | **OK** |
| Wheat in Market | ✅ (WARN) | ❌ | ❌ Fails | ❌ | **BROKEN** |
| Bread in Kitchen | ✅ | ✅ (💨/🌾) | ✅ | ✅ | **OK** |
| Bread in Market | ✅ (WARN) | ❌ | ❌ Fails | ❌ | **BROKEN** |
| Mushroom in BioticFlux | ✅ | ✅ (🌾/🍄) | ✅ | ✅ | **OK** |
| Mushroom in Market | ✅ (WARN) | ❌ | ❌ Fails | ❌ | **BROKEN** |

---

## 🔗 Related Code Locations

- **Detection:** `Core/GameMechanics/FarmGrid.gd:774-778`
- **Validation:** `Core/Environment/BiomeBase.gd:2068-2102`
- **Registration:** `Core/GameMechanics/BasePlot.gd:216-232`
- **Measurement:** `Core/GameMechanics/BasePlot.gd:278`
- **Biome Definitions:**
  - `Core/Environment/MarketBiome.gd`
  - `Core/Environment/QuantumKitchen_Biome.gd`
  - `Core/Environment/BioticFluxBiome.gd`
  - `Core/Environment/ForestEcosystem_Biome.gd`

---

## 💭 CONCLUSION

The planting system allows emoji-biome mismatches **intentionally** but **incompletely**:

✓ **Allows experimentation** (as intended by design comment)
✗ **Fails silently** (when you try to use the mismatched plant)
✗ **No feedback mechanism** (user doesn't know it will break until measurement)
✗ **No recovery** (can't measure/harvest the broken plant)

This is a **Semantic Violation** - the plot appears planted but the quantum system doesn't recognize it.

