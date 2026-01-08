# Model C Transition - Recommendations and Next Steps

**Date:** 2026-01-07
**Purpose:** Actionable recommendations for transitioning to Model C analog architecture

---

## Executive Summary

**Current State:** SpaceWheat has well-designed Model C infrastructure (QuantumComputer, RegisterMap, builders) but doesn't use it. All biomes use Legacy QuantumBath.

**Goal:** Transition to Model C for better scalability, modularity, and quantum mechanics correctness.

**Recommendation:** **Incremental transition starting with Kitchen** as proof-of-concept.

---

## Priority 1: Icon Review and Cleanup

### Issues Found

**1. Water Double-Definition**
```gdscript
// CoreIcons.gd line 269-283 (Elements section)
var water = Icon.new()
water.emoji = "💧"
// ...

// CoreIcons.gd line ~500 (Kitchen section)
if not registry.has_icon("💧"):
    var water = Icon.new()
    water.emoji = "💧"
    // ... different definition
```

**Action:** Decide if Kitchen needs custom Water Icon or should use Element Water.
- **Option A:** Remove Kitchen water, use Element water (simpler)
- **Option B:** Rename Kitchen water to different emoji (e.g. "💦" steam)

**2. Eternal Flag Bug**
```gdscript
// CoreIcons.gd line 302
water.is_eternal = true
// Should be: soil.is_eternal = true
```

**Action:** Fix the bug, soil should be eternal (not water again).

**3. Inconsistent Rate Scaling**
```gdscript
// Some rates 10x faster
wheat.lindblad_incoming["☀"] = 0.0267  // Was 0.00267
// Others not scaled
moon.driver_frequency = 0.05  // Same as original
```

**Action:** Review all rates for consistency. Document which are 10x faster and why.

### Recommended Icon Adjustments

**Gameplay Visibility:**
- ✅ Current 10x speedup is good (37.5s wheat growth is visible)
- Consider 20x speedup if still too slow (18.75s growth)
- OR keep 10x but add visual feedback (particle effects, sound)

**Balance Issues:**
- Mushroom lindblad_incoming["🌙"] = 0.40 (very fast!)
- Wheat lindblad_incoming["☀"] = 0.0267 (much slower)
- **Result:** Mushrooms dominate BioticFlux biome
- **Action:** Either speed up wheat or slow down mushrooms for balance

**Driver Frequencies:**
- Celestial (20s period) - fine
- Market (30s period) - fine
- Kitchen (15s period) - might be too fast (dizzying oscillations)
- **Action:** Consider 25s period for Kitchen drivers

**Decay Rates:**
- Most icons: 0.02-0.05 /s (reasonable)
- Seedling: 0.04 /s (high - "many seeds fail")
- **Action:** Decay rates seem balanced, keep as-is

---

## Priority 2: Kitchen Model C Conversion

### Why Start With Kitchen?

1. **Simplest biome** (3 qubits, 8 basis states)
2. **Clear structure** (temperature, moisture, substance axes)
3. **Well-defined physics** (known bread production dynamics)
4. **Small Hilbert space** (8×8 matrix = trivial performance)
5. **Already has clean Icon definitions** (mostly)

### Conversion Steps

**Step 1: Define RegisterMap**
```gdscript
// QuantumKitchen_Biome.gd

func _initialize_quantum_computer() -> void:
    quantum_computer = QuantumComputer.new("Kitchen")

    # Register 3 axes
    quantum_computer.allocate_axis(0, "🔥", "❄️")  # Temperature
    quantum_computer.allocate_axis(1, "💧", "🏜️")  # Moisture
    quantum_computer.allocate_axis(2, "💨", "🌾")  # Substance

    # Initialize to ground state |111⟩ = cold, dry, grain
    quantum_computer.initialize_basis(7)
```

**Step 2: Build Operators from Icons**
```gdscript
    # Get Icons
    var icon_registry = get_node("/root/IconRegistry")
    var icon_dict = {}
    for emoji in ["🔥", "❄️", "💧", "🏜️", "💨", "🌾"]:
        var icon = icon_registry.get_icon(emoji)
        if icon:
            icon_dict[emoji] = icon

    # Build Hamiltonian and Lindblad operators
    var H = HamiltonianBuilder.build(icon_dict, quantum_computer.register_map)
    var L_ops = LindbladBuilder.build(icon_dict, quantum_computer.register_map)

    print("🍳 Kitchen operators: %d H-terms, %d L-terms" % [
        H.count_nonzero(), L_ops.size()
    ])
```

**Step 3: Replace Drive Functions**
```gdscript
# Old (Legacy Bath)
func add_fire(amount: float) -> void:
    # Modify Icon.lindblad_outgoing rates
    # Rebuild bath operators
    bath.build_lindblad_from_icons(bath.active_icons)

# New (Model C)
func add_fire(amount: float) -> void:
    # Use QuantumComputer.apply_drive()
    quantum_computer.apply_drive("🔥", DRIVE_RATE * amount, dt)
```

**Step 4: Update State Queries**
```gdscript
# Old (Legacy Bath)
var p_bread = bath.get_probability("🔥💧💨")

# New (Model C) - Option A: Basis index
var p_bread = quantum_computer.get_basis_probability(0)  # |000⟩

# New (Model C) - Option B: Emoji array (if implemented)
var p_bread = quantum_computer.get_population(["🔥", "💧", "💨"])
```

**Step 5: Update Evolution Loop**
```gdscript
# BiomeBase._update_quantum_substrate()

# Old (Legacy Bath)
if bath:
    bath.evolve(dt)

# New (Model C)
if quantum_computer:
    quantum_computer.evolve(dt)  # Need to implement this!
```

### Challenges

**Challenge 1: Multi-Emoji Basis Labels**
- Legacy: Uses "🔥💧💨" as single basis label
- Model C: Uses qubit product state |000⟩

**Solution:** Treat as visualization layer only. Internally use |0⟩-|7⟩, externally show emoji arrays.

**Challenge 2: Icon-Based Drive Modification**
- Legacy: Modifies Icon.lindblad_outgoing rates dynamically
- Model C: Uses apply_drive() with fixed rates

**Solution:** Store drive strengths separately, rebuild operators when drives change.

**Challenge 3: No QuantumComputer.evolve() Yet**
- Model C has apply_drive(), but no master evolution loop

**Solution:** Implement evolve() method using Lindblad master equation (copy from QuantumBath).

---

## Priority 3: BioticFlux Model C Conversion

### Structure

**6 Emojis:** ☀ 🌙 🌾 🍄 💀 🍂

**RegisterMap Strategy:**

**Option A: 3 Qubits (with unused states)**
```
Qubit 0 (Celestial): |☀⟩ = |0⟩, |🌙⟩ = |1⟩
Qubit 1 (Life/Death): |🌾⟩ = |0⟩, |💀⟩ = |1⟩
Qubit 2 (Flora Type): |🍄⟩ = |0⟩, |🍂⟩ = |1⟩
```
- 8 basis states, 2 unused (e.g. |🌙🌾🍂⟩ doesn't make sense)

**Option B: Sparse 6-State System**
- Don't use RegisterMap at all
- Keep as Legacy Bath with 6×6 density matrix
- Wait for RegisterMap to support non-qubit systems

**Recommendation: Option A (3 qubits)**
- Fits Model C architecture
- Small overhead (8×8 vs 6×6 matrix is trivial)
- Enables proper quantum gates later

### Icon Review

**Driver Icons:**
- ☀ Sun: cosine driver, 20s period ✅
- 🌙 Moon: sine driver, 20s period ✅

**Transfer Rates:**
- Wheat: 0.0267 /s from Sun (slow)
- Mushroom: 0.40 /s from Moon (VERY fast)

**Issue:** Mushroom dominates. After 10s, P(🍄) >> P(🌾).

**Recommendation:** Reduce mushroom rate to 0.10 /s for balance.

---

## Priority 4: Market Model C Conversion

### Structure

**8 Emojis:** 🐂 🐻 💰 📦 🏛️ 🏚️ 🏪 💳

**RegisterMap: 3 Qubits**
```
Qubit 0 (Sentiment): |🐂⟩ = |0⟩ (bull), |🐻⟩ = |1⟩ (bear)
Qubit 1 (Faction): |🏛️⟩ = |0⟩ (stability), |🏚️⟩ = |1⟩ (chaos)
Qubit 2 (Resource): |💰⟩ = |0⟩ (money), |📦⟩ = |1⟩ (goods)
```

**Unused emojis:** 🏪 (market), 💳 (credit)

**Options:**
- **A:** Add 4th qubit for market/credit axis (16D Hilbert space)
- **B:** Treat market/credit as classical variables (not quantum)
- **C:** Merge into existing axes (e.g. 💳 = money variant)

**Recommendation: Option A (4 qubits)** - Clean structure, 16×16 matrix is still trivial.

---

## Priority 5: Forest - Special Case

### Challenge

**22 Emojis!** (full food web)

**RegisterMap: 5 Qubits Minimum**
- 2^5 = 32 basis states
- 10 unused states
- 32×32 = 1024 element density matrix (manageable)

**Alternative: Keep as Markov-Derived System**
- Forest already uses Markov chain for Icon generation
- Don't use RegisterMap at all
- Keep as 22×22 density matrix

**Recommendation:** Keep Forest as Legacy Bath for now.
- Most complex biome
- Convert last after Kitchen/BioticFlux/Market validated
- May need RegisterMap enhancements (non-binary systems)

---

## Priority 6: Visualization Updates

### Required Changes

**1. Query Interface**
```gdscript
// QuantumNode.gd

# Old (Legacy Bath)
var p_north = plot_biome.bath.get_probability(north_emoji)
var p_south = plot_biome.bath.get_probability(south_emoji)

# New (Model C)
var p_north = plot_biome.quantum_computer.get_population(north_emoji)
var p_south = plot_biome.quantum_computer.get_population(south_emoji)
```

**2. Coherence Queries**
```gdscript
# Old
var coherence = plot_biome.bath.get_off_diagonal(north_emoji, south_emoji)

# New
var coherence = plot_biome.quantum_computer.get_marginal_coherence(register_id)
```

**Problem:** QuantumNode doesn't know register_id, only knows emojis.

**Solution:** Add RegisterMap lookup:
```gdscript
var register_id = plot_biome.quantum_computer.register_map.???
# Need method: get_register_id_for_plot(north_emoji, south_emoji)
```

**3. Multi-Emoji Basis States (Kitchen)**
```gdscript
# Current Kitchen uses "🔥💧💨" as basis label
# Model C uses |000⟩

# Solution: RegisterMap.basis_to_emojis(0) → ["🔥", "💧", "💨"]
# Visualization concatenates: "🔥💧💨"
```

### Performance Considerations

**Current:** 60 Hz × 12 bubbles = 720 queries/sec

**Model C Impact:**
- RegisterMap lookup: negligible (hash table)
- Marginal trace: O(2^n) per query
- Expected: No noticeable slowdown for n ≤ 5 qubits

**Optimization:** Cache marginals if density matrix unchanged.

---

## Priority 7: Cross-Biome Interactions

### Current System (Unclear)

**Icon simulation objects:**
- BioticFluxIcon (wanders scene)
- ImperiumIcon (wanders scene)
- ChaosIcon (wanders scene)

**Supposed behavior:**
- Proximity affects Lindblad rates
- Unclear implementation

**Problem:** How does Icon object affect multiple biomes?

### Model C Design

**Option A: Icon Objects as Rate Modulators**
```gdscript
# Icon object has position
# Each biome queries nearby Icons
# Modulates Lindblad rates based on distance

func _process(dt):
    var nearby_icons = get_icons_in_range(100.0)
    for icon in nearby_icons:
        var rate_modifier = icon.get_influence(distance)
        # Rebuild Lindblad operators with modified rates
```

**Option B: Icon Objects as Hamiltonian Terms**
```gdscript
# Icon adds coupling between biomes
# Creates entanglement between biome Hilbert spaces

# BioticFlux ⊗ Kitchen = 8D ⊗ 8D = 64D system
# Icon creates H_coupling that entangles them
```

**Option C: Icon Objects as Classical Parameters**
```gdscript
# Icon doesn't affect quantum state
# Just affects game economy/resources
# Quantum and classical layers decoupled
```

**Recommendation: Option A (Rate Modulators)**
- Simpler than cross-biome entanglement
- Matches current design intent
- Performance-friendly (no giant tensor products)

---

## Technical Improvements

### 1. Add QuantumComputer.evolve()

**Missing:** Master evolution loop for Model C

**Needed:**
```gdscript
func evolve(dt: float) -> void:
    # Apply Lindblad master equation
    # dρ/dt = -i[H,ρ] + Σ γ(LρL† - ½{L†L,ρ})
    # Use RK4 integration (copy from QuantumBath)
```

### 2. Add RegisterMap Composite Emoji Support

**Problem:** Kitchen uses "🔥💧💨" (3-char string) as basis label

**Solution:**
```gdscript
func register_composite(composite_emoji: String, basis_index: int) -> void:
    # Direct mapping without qubit structure
    composite_coordinates[composite_emoji] = basis_index
```

### 3. Add Icon Rate Modulation API

**Problem:** Kitchen modifies Icon.lindblad_outgoing dynamically

**Solution:**
```gdscript
# In Icon class
var rate_modifiers: Dictionary = {}  # emoji → multiplier

func get_effective_lindblad_rate(target: String) -> float:
    var base_rate = lindblad_outgoing.get(target, 0.0)
    var modifier = rate_modifiers.get(target, 1.0)
    return base_rate * modifier
```

### 4. Optimize Visualization Queries

**Current:** 720 queries/sec, no caching

**Improvement:**
```gdscript
# QuantumComputer class
var _marginal_cache: Dictionary = {}  # qubit → marginal matrix
var _cache_valid: bool = false

func evolve(dt):
    density_matrix = ...
    _cache_valid = false  # Invalidate cache

func get_marginal(q, p):
    if not _cache_valid:
        _rebuild_marginal_cache()
    return _marginal_cache[q][p]
```

**Expected:** 80% reduction in marginal trace computations.

---

## Decision Matrix

Before proceeding, answer these questions:

| Question | Option A | Option B | Recommendation |
|----------|----------|----------|----------------|
| Kitchen multi-emoji labels? | Pure qubits | Composite emoji support | **Option A** (simpler) |
| Water Icon duplication? | Use Element water | Rename Kitchen water | **Option A** (less duplication) |
| Mushroom growth rate? | Keep 0.40 /s | Reduce to 0.10 /s | **Option B** (better balance) |
| Forest biome? | 5-qubit RegisterMap | Keep Legacy Bath | **Option B** (defer complexity) |
| Cross-biome Icons? | Rate modulators | Entangled Hilbert spaces | **Option A** (simpler) |
| Transition strategy? | Big bang (all biomes) | Incremental (Kitchen first) | **Option B** (lower risk) |

---

## Implementation Roadmap

### Phase 1: Icon Cleanup (1-2 days)
- [ ] Fix water double-definition bug
- [ ] Fix soil eternal flag bug
- [ ] Review and adjust all Icon rates for balance
- [ ] Document rate scaling strategy (which are 10x faster and why)
- [ ] Test that all biomes still work after Icon changes

### Phase 2: Kitchen Model C (3-5 days)
- [ ] Implement QuantumComputer.evolve() method
- [ ] Create Kitchen RegisterMap (3 qubits)
- [ ] Build Hamiltonian/Lindblad operators from Icons
- [ ] Replace drive functions with apply_drive()
- [ ] Update state queries to use QuantumComputer
- [ ] Test bread production still works
- [ ] Verify visualization still displays correctly

### Phase 3: BioticFlux Model C (2-3 days)
- [ ] Create BioticFlux RegisterMap (3 qubits, 2 unused states)
- [ ] Build operators from Icons
- [ ] Test wheat growth and mushroom dynamics
- [ ] Verify sun/moon oscillation visible

### Phase 4: Market Model C (2-3 days)
- [ ] Create Market RegisterMap (4 qubits)
- [ ] Build operators from Icons
- [ ] Test bull/bear cycles and faction dynamics

### Phase 5: Visualization Update (2-3 days)
- [ ] Update QuantumNode to query QuantumComputer
- [ ] Add RegisterMap-aware coherence queries
- [ ] Test performance (should still be 60 FPS)
- [ ] Add marginal caching for optimization

### Phase 6: Cross-Biome Interactions (3-4 days)
- [ ] Design Icon rate modulation system
- [ ] Implement proximity-based rate changes
- [ ] Test Icon objects affecting multiple biomes

### Phase 7: Deprecate Legacy Bath (1-2 days)
- [ ] Remove QuantumBath class
- [ ] Clean up old code paths
- [ ] Update all documentation

**Total Estimated Time: 16-24 days**

---

## Risk Mitigation

### Risk 1: Kitchen Conversion Breaks Gameplay
**Mitigation:** Keep Legacy Bath code until Model C validated
**Rollback:** Feature flag to switch between Legacy and Model C

### Risk 2: Performance Regression
**Mitigation:** Profile before/after, optimize hot paths
**Target:** Maintain 60 FPS with 20 plots

### Risk 3: Visualization Artifacts
**Mitigation:** Screenshot comparisons Legacy vs Model C
**Validation:** Visual parity tests

### Risk 4: Icon Balance Issues
**Mitigation:** Playtest after rate adjustments
**Rollback:** Keep old rates in comments for easy revert

---

## Success Criteria

**Phase 1 Complete When:**
- ✅ All Icons have consistent rate scaling
- ✅ No duplicate Icon definitions
- ✅ All eternal flags correct
- ✅ Biomes still run without errors

**Phase 2 Complete When:**
- ✅ Kitchen uses QuantumComputer (not Legacy Bath)
- ✅ Bread production works (flour + air + fire → bread)
- ✅ Visualization shows correct probabilities
- ✅ Performance is same or better than Legacy

**Final Success When:**
- ✅ All biomes (except Forest) use Model C
- ✅ Visualization uses RegisterMap
- ✅ Cross-biome Icon interactions work
- ✅ Legacy Bath code removed
- ✅ Documentation updated

---

## Questions for Review

Before starting implementation, please decide:

1. **Icon rates:** Keep 10x speedup or adjust further?
2. **Kitchen labels:** Pure qubits or composite emoji support?
3. **Water duplication:** Remove or rename?
4. **Mushroom balance:** Keep fast growth or slow down?
5. **Forest strategy:** Convert to Model C or keep Legacy?
6. **Cross-biome design:** Rate modulators, entanglement, or classical?
7. **Transition timing:** Big bang or incremental?

---

This roadmap provides a clear path from current Legacy system to full Model C architecture. Recommend starting with Icon cleanup (low risk) and Kitchen conversion (high value proof-of-concept).
