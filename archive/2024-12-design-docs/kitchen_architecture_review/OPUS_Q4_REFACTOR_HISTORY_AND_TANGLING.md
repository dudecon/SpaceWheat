# Q4: Refactor History - What Tangled the Machinery

**Question**: What was the last major refactor? Are there dead code paths or vestigial handlers? Is there a mismatch between UI and physics layers?

**Answer**: Model A → Model B migration is incomplete. Two parallel systems coexist. This creates the tangling.

---

## The Great Refactoring Timeline

### Phase 0: Original Model A (Pre-Current)

**What It Was**:
```
Each plot: quantum_state: DualEmojiQubit

PlotA (0,0): |ψ_A⟩ = wheat state
PlotB (1,0): |ψ_B⟩ = mushroom state

Entanglement: Stored in separate EntangledPair objects
Measurement: Inconsistent (per-plot logic)
Scalability: Manual state tracking
```

**Problems**:
- No canonical quantum state
- Measurement side effects unpredictable
- Entanglement logic split between plot and grid
- Cross-biome impossible

### Phase 1: Model B (Current - Partial Migration)

**What It Is** (NEW):
```
Biome owns quantum_computer: QuantumComputer

BiomeBase:
  quantum_computer (ONE source of truth)
    ├─ QuantumComponent 0: registers [0,1] (entangled wheat+mushroom)
    ├─ QuantumComponent 1: register [2] (isolated wheat)
    └─ QuantumComponent 2: register [3] (flour qubit)

Plots: Just hold register_id and parent_biome reference
```

**Advantages**:
- Single source of truth
- Automatic entanglement tracking
- Proper density matrix evolution
- Cross-biome routing possible

**Status**: INCOMPLETE MIGRATION

---

## The Tangling: Two Systems Running Simultaneously

### What's Still Using Model A

**Files with Model A patterns**:

1. **FarmGrid.gd**:
```gdscript
# Line 66: LEGACY single biome (Model A)
var biome = null

# Lines 68-74: NEW multi-biome system (Model B)
var biomes: Dictionary = {}
var plot_biome_assignments: Dictionary = {}
var plot_register_mapping: Dictionary = {}
var plot_to_biome_quantum_computer: Dictionary = {}
```

2. **FarmInputHandler.gd**:
```gdscript
# Line 1388: Assumes plot-level structures (Model A thinking)
if not plot or not plot.is_planted:
    continue

# But physics layer expects biome-level (Model B)
var biome = farm.grid.get_biome_for_plot(pos)
if biome and biome.place_energy_tap(target_emoji, 0.05):
```

3. **BiomeBase.gd**:
```gdscript
# Line 32: NEW quantum_computer (Model B)
var quantum_computer: QuantumComputer = null

# Line 38: OLD quantum bath (Model A, deprecated)
var bath: QuantumBath = null  # TODO: Remove after full migration

# Code uses BOTH:
# - quantum_computer.measure_register() (Model B)
# - bath.evolve() (Model A)
```

4. **BasePlot.gd**:
```gdscript
# New Model B style:
var parent_biome: Node = null
var register_id: int = -1

# But still has legacy quantum_state references in comments
# Old: var quantum_state: DualEmojiQubit
```

---

## Vestigial Code and Dead Paths

### 1. The QuantumBath Layer

**File**: `Core/QuantumSubstrate/QuantumBath.gd`

```gdscript
var _density_matrix  # New (Model B)
var _hamiltonian
var _lindblad
var _evolver

# But ALSO legacy storage:
var hamiltonian_sparse: Dictionary = {}
var lindblad_terms: Array[Dictionary] = []
var amplitudes: Array[Complex]  # Computed on-demand, unused
var emoji_list: Array[String]  # Computed on-demand, unused
```

**Status**: ⚠️ Maintained for backward compatibility, marked for deletion

**Should be deleted when**:
- All biomes fully migrated to quantum_computer
- Code stops calling bath.evolve()
- Tests stop using bath directly

### 2. Legacy Projection System

**File**: `Core/GameMechanics/FarmGrid.gd`

```gdscript
var active_projections: Dictionary = {}  # Line 41 in BiomeBase

# In BiomeBase._process():
var total_probability = 0.0
for emoji in biome.active_projections.values():
    total_probability += emoji.get("probability", 0.0)

# This code exists but is NEVER called in current flow
# ✅ Calculation: correct
# ⚠️ Usage: orphaned
```

**Status**: Dead code (not used, but not harmful)

### 3. Redundant Register Mappings

**FarmGrid.gd Lines 72-74**:
```gdscript
var plot_register_mapping: Dictionary = {}              # plots → register IDs
var plot_to_biome_quantum_computer: Dictionary = {}     # plots → quantum computers

# Both track the same information!
# plot_register_mapping[pos] = register_id
# plot_to_biome_quantum_computer[pos] = biome.quantum_computer

# Could be: plot_biome_mapping[pos] = biome_name
# Then: register_id = biome.plot_registers[pos].register_id
```

**Status**: ⚠️ Redundant but not harmful (just memory overhead)

---

## Layer Mismatches: Where the Real Tangling Shows

### Mismatch 1: Plot-Level UI vs. Biome-Level Physics (Energy Taps)

**UI Layer** (FarmInputHandler.gd:1388):
```gdscript
for pos in positions:
    var plot = farm.grid.get_plot(pos)
    if not plot or not plot.is_planted:
        continue  # ← Assumes: Taps are plot structures
```

**Physics Layer** (BiomeBase.place_energy_tap):
```gdscript
func place_energy_tap(target_emoji: String, drain_rate: float = 0.05) -> bool:
    # Operates on: bath.active_icons (biome-level)
    # Creates: Lindblad operator in biome quantum state
    # Doesn't need: Any plot information!
```

**The Problem**:
```
Energy tap is biome-level operation that doesn't require a plot.
But UI handler blocks it if no plot is planted.
Result: Can't place tap on empty plot
        Can't place tap without planted anything
```

**Should Be**:
```
if biome.place_energy_tap(target_emoji, drain_rate):
    success_count += 1

No plot check needed!
```

### Mismatch 2: Mill Lifecycle (Non-Destructive Abstraction)

**Mill Code** (QuantumMill.gd):
```gdscript
# Queries purity (Model B correct)
var purity = biome.quantum_computer.get_marginal_purity(comp, register_id)

# Uses as outcome probability
var flour_outcome = randf() < purity

if flour_outcome:
    # Marks as measured but DOESN'T collapse
    plot.has_been_measured = true
    plot.measured_outcome = plot.south_emoji
    # ⚠️ NOT removed: plot.is_planted = false
    # ⚠️ NOT removed: biome.quantum_computer.remove_register(register_id)
```

**User Expectation** (from gameplay):
```
Mill measures wheat once → Flour produced
Wheat can't be measured again (consumed or locked)
```

**Actual Behavior**:
```
Mill measures wheat frame 1 → +10 flour ✓
Mill measures wheat frame 2 → +10 flour ✓ (SAME WHEAT!)
Mill measures wheat frame 3 → +10 flour ✓ (SAME WHEAT!)
Total: Infinite flour from one wheat ✗
```

**This is intentional?** Or oversight?
- If intentional: Document it as design choice
- If bug: Fix by actually collapsing state

---

## Last Major Refactor: Model A → Model B Migration

### When
**Approximately** (from code comments): December 2024 - January 2025

**Markers in code**:
```
Phase 0.5: MODEL B: Register allocation
Phase 1: QuantumComputer owned by biome
Phase 2: Multi-biome support (plot assignments)
Phase 2c: Route operations to correct biome
Phase 3: Icons as Hamiltonian terms
Phase 4: Energy taps with Lindblad drains
```

### What Was Changed

**Before**:
```
- Biome or null
- Per-plot quantum_state: DualEmojiQubit
- Manual entanglement tracking
- Measurement ad-hoc
```

**After**:
```
- Multiple biomes (registry)
- Per-biome quantum_computer (QuantumComputer)
- Automatic entanglement (component merging)
- Measurement via density matrix
```

### Why It's Incomplete

**Effort Required to Complete**:

1. **Remove QuantumBath** (~100 lines affected)
   - Replace bath.evolve() with quantum_computer.evolve()
   - Remove legacy amplitudes property
   - Delete backward compatibility layer

2. **Fix Mill Measurement** (~50 lines affected)
   - Make it actually destructive
   - Implement outcome locking
   - Remove infinite flour possibility

3. **Fix Energy Tap Placement** (~30 lines affected)
   - Remove plot.is_planted check
   - Let biome-level operation work freely

4. **Clarify Kitchen Physics** (~200 lines affected)
   - Define cross-biome Bell state semantics
   - Either merge baths or accept abstraction
   - Document quantum rigor level

5. **Test & Validate** (~1000s lines test code)
   - Verify measurement statistics
   - Verify entanglement dynamics
   - Verify energy conservation

**Estimate**: 2-3 days for full completion + testing

---

## Code Debt Summary

### What's Paid Off ✅
- QuantumComputer implementation (solid)
- Multi-biome registry (working)
- Gate operations (correct)
- Measurement via purity (correct)

### What's Still Owed ⚠️
- Remove QuantumBath (marked for deletion)
- Fix layer mismatches (UI vs. Physics)
- Clarify kitchen semantics (cross-biome)
- Mill measurement (destructive vs. non)
- Energy tap placement (plot gate)

### Interest Cost 📈
Every line of new code must account for:
- Legacy QuantumBath references
- Plot-level vs. biome-level decisions
- Ambiguous measurement semantics
- Undefined cross-biome access

---

## Why The Tangling Happened

### 1. Incremental Development
```
Phase 1: New QuantumComputer working
Phase 2: Old QuantumBath still used
Phase 3: Both systems coexist
Phase 4: New features built on both

Result: "It works" but "both systems run"
```

### 2. Backward Compatibility Cruft
```
Old tests still use QuantumBath
Old UI handlers use plot-level checks
Old measurement logic works but incomplete

Removing it breaks tests/gameplay temporarily
```

### 3. Undefined Specifications
```
Is energy tap plot-level or biome-level? (Nobody decided)
Is mill destructive or non-destructive? (Nobody decided)
Does kitchen access cross-biome states? (Nobody decided)

Code defaults to whatever worked first
```

---

## Recommendations for Cleanup

### Short Term (1-2 days)
1. Remove energy tap plot check (unblock keyboard)
2. Add "TODO: Define mill semantics" comment
3. Add "TODO: Define kitchen cross-biome access" comment
4. Document current behavior

### Medium Term (1 week)
1. Complete Model B migration
2. Delete QuantumBath
3. Fix mill measurement (choose destructive/non-destructive)
4. Validate measurement statistics

### Long Term (Architecture Review)
1. Decide kitchen architecture (Option A, B, or C)
2. Implement cross-biome mechanism (if needed)
3. Full quantum rigor verification (smoke tests)
4. Performance optimization (if needed)

---

## Tangling Checklist

| Issue | Type | Impact | Fix Effort |
|-------|------|--------|-----------|
| QuantumBath still used | Legacy code | Memory, confusion | 1 day |
| Plot check on taps | Layer mismatch | Blocks functionality | 30 min |
| Mill non-destructive | Ambiguous spec | Infinite flour | 2 hours |
| Kitchen cross-biome | Undefined | Physics gap | 4 hours |
| Redundant mappings | Code debt | Memory only | 1 hour |
| Active projections unused | Dead code | Harmless | 1 hour |
| Bath evolution unused | Dead code | Harmless | 30 min |

**Total Cleanup**: ~2 days

This is **not tangling in the physics sense** (that's clean).
This is **tangling in the integration sense** (old + new systems coexist).

---

## Conclusion

The "tangling" is **architectural**, not physical:
- ✅ Physics is clean and correct (Model B solid)
- ⚠️ Integration layer is incomplete (old + new systems running)
- ❓ Some specifications undefined (kitchen, taps, mill)

**Recommendation**: Complete the Model B migration and clarify specifications. The hard part (physics) is done. The tedious part (cleanup) remains.
