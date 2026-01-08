# 🎯 Design Decision Framework

**Purpose**: Three critical architectural decisions that must be made
**Status**: Waiting for your choices
**Impact**: Determines entire implementation approach

---

## Decision A: Mill Measurement Semantics

### The Question
**What happens to wheat after the mill measures it?**

### Current Behavior
```
t=0: Wheat planted at (0,0), is_planted=true
t=1s: Mill measures → flour produced, plot.has_been_measured=true
t=2s: Mill measures AGAIN → flour produced (AGAIN!)
t=5s: Same wheat measured 5 times
Result: Infinite flour from one wheat ✗
```

### Option A1: Destructive Measurement
**"Mill consumes wheat when measuring"**

```
Design:
  Mill measures wheat at t=1s
  ├─ On success: wheat → flour (consumptive)
  │  plot.is_planted = false
  │  plot.plot_type = EMPTY
  ├─ On failure: no change (wheat stays)
  └─ Can't measure twice

Advantages:
  ✓ Clear semantics (measurement = harvest)
  ✓ No infinite flour
  ✓ Matches user expectation ("mill processes wheat")

Disadvantages:
  ✗ Mill and Harvest are now redundant
  ✗ Flour output divorced from harvest
  ✗ Two ways to get crop → confusion

Quantum Rigor:
  ✓ Matches projective measurement (destructive)
  ✗ Loses non-destructive measurement advantage

Implementation:
  - Mill measures, gets outcome
  - On flour: Remove register from bath
  - Set plot.is_planted = false
```

---

### Option A2: Non-Destructive + Outcome Locking
**"Mill measures but locks outcome, preventing re-measurement"**

```
Design:
  Mill measures wheat at t=1s
  ├─ On success: flour produced
  │  plot.measured_outcome = south_emoji (👥)
  │  plot.has_been_measured = true
  │  plot.quantum_state = LOCKED (can't evolve)
  ├─ On failure: plot stays unlocked
  └─ Harvest reads locked outcome

Advantages:
  ✓ True non-destructive measurement
  ✓ Outcome tracking (what it measured)
  ✓ Harvest can use measurement result
  ✓ More complex = more learning

Disadvantages:
  ✗ Need outcome tracking system
  ✗ Need state locking mechanism
  ✗ Harvest must check locked state
  ✗ More complex UI (show lock state?)

Quantum Rigor:
  ✓ Matches measurement in computational basis
  ✓ Non-destructive (state stays, outcome fixed)
  ✓ Can verify consistency (harvest = mill outcome)

Implementation:
  - Mill measures, gets outcome
  - Store outcome on plot
  - LOCK quantum state (disable Hamiltonian evolution)
  - Harvest reads locked outcome OR re-measures
```

---

### Option A3: Renewable Wheat
**"This is intentional - wheat is renewable like crops"**

```
Design:
  Wheat can be measured infinitely
  - Same wheat → multiple flour batches
  - Simulates "constant harvest" farming
  - Biome level doesn't deplete

Advantages:
  ✓ Simple (no changes needed)
  ✓ Renewable resources (strategic depth)
  ✓ Mill is tool, not harvest replacement
  ✓ Allows grinding wheat repeatedly

Disadvantages:
  ✗ Unrealistic (magic infinite wheat)
  ✗ Can spam flour infinitely
  ✗ Breaks economy scaling
  ✗ Doesn't match "smoke test" intent

Quantum Rigor:
  ✗ Violates measurement semantics
  ✗ Measurement should reduce uncertainty
  ✗ Not actually testing quantum mechanics

Implementation:
  - Do nothing (already works this way)
  - Document intentional behavior
  - Add balance: flour → bread efficiently
```

---

### Recommendation: Choose One
**Option A2** is recommended:
- Maintains quantum rigor (non-destructive measurement)
- Adds learning complexity (outcome tracking)
- Allows verification (harvest confirms mill)
- Requires implementation (good testing opportunity)

**But this is YOUR decision.** The game might be better with A1 or A3.

---

## Decision B: Energy Tap Architecture

### The Question
**How do energy taps fit into the game architecture?**

### Current Broken State
```
Handler tries:
  ├─ Check if plot.is_planted
  └─ Call biome.place_energy_tap("🔥")

Physics tries:
  ├─ Find "🔥" in biome.active_icons
  └─ Create Lindblad drain

Problem:
  Fire (🔥) doesn't exist in BioticFlux bath
  Fire only exists in Kitchen bath
  But user is selecting plots in BioticFlux
```

---

### Option B1: Plot-Level Tap Buildings
**"Taps are physical structures like mill/kitchen"**

```
Design:
  Energy Tap is a PlotType (like MILL, KITCHEN)
  ├─ Player selects plot (any plot)
  ├─ UI opens tap submenu (fire/water/flour options)
  ├─ Player chooses tap target
  ├─ System creates tap building on plot
  └─ Tap operates within plot's biome

Process:
  plot.plot_type = ENERGY_TAP
  plot.tap_target_emoji = "🔥"
  plot.tap_biome_source = "Kitchen"  // where the emoji lives
  ↓
  FarmGrid._process_energy_taps() fetches from source biome
  ↓
  Kitchen_biome.get_tap_flux("🔥") returns drained flux
  ↓
  Economy += flux

Advantages:
  ✓ Fits current architecture (plot-based)
  ✓ UI intuitive (place tap like building)
  ✓ Clear player action (select + place)
  ✓ Can show tap visually

Disadvantages:
  ✗ Taps use biome data (not plot data)
  ✗ Requires biome lookup by tap target
  ✗ Tap consumes a plot (limited space)
  ✗ Need to differentiate: tap in which biome?

Quantum Rigor:
  ✓ Makes taps observable (give them physical form)
  ✗ Might confuse measurement vs. structure

Implementation:
  - Add ENERGY_TAP plot type
  - Store tap_target_emoji on plot
  - In _process_energy_taps(): lookup biome by target emoji
  - Feed flux to economy
```

---

### Option B2: Biome-Level Tap Operators
**"Taps modify the biome's quantum bath directly"**

```
Design:
  Energy Tap is a biome OPERATION (not plot structure)
  ├─ Player selects ANY plot in target biome
  ├─ System identifies which biome
  ├─ Call biome.place_energy_tap("🔥")
  ├─ Creates Lindblad drain in that biome
  └─ All flux from that biome → economy

Process:
  UI: "Select plots in Kitchen biome"
      "Select plots in Forest biome"
  ↓
  FarmInputHandler identifies biome
  ↓
  biome.place_energy_tap("🔥", drain_rate=0.1)
  ↓
  Lindblad drain added to Kitchen bath
  ↓
  Kitchen_quantum_computer evolves with drain
  ↓
  Flux accumulates in sink state

Advantages:
  ✓ Pure quantum operation (no plot-level hack)
  ✓ Works within Model B architecture
  ✓ No plot consumption (infinite taps)
  ✓ Matches Lindblad formalism

Disadvantages:
  ✗ Less visible to player (no physical tap)
  ✗ Player "does" what exactly? (abstract)
  ✗ Need to communicate: "tap Kitchen → get fire"
  ✗ Biome identification from plot selection (UX?)

Quantum Rigor:
  ✓ True Lindblad drain (proper quantum)
  ✓ No fake "plot-level" structure
  ✓ Model B native

Implementation:
  - Modify handler to identify plot's biome
  - Call biome.place_energy_tap(emoji, rate)
  - NO plot type needed
  - Taps can stack (multiple drains same biome)
```

---

### Option B3: Auto-Injected Emoji Reservoir
**"All emojis exist in all biomes automatically"**

```
Design:
  Fire (🔥), Water (💧), Flour (💨) are GLOBAL RESOURCES
  ├─ Exist in all biomes simultaneously
  ├─ User places taps anywhere
  ├─ Drains from global reservoir

Process:
  Biome initialization:
    BioticFlux.inject_emoji("🔥")  // add fire to BioticFlux
    BioticFlux.inject_emoji("💧") // add water to BioticFlux
    BioticFlux.inject_emoji("💨") // add flour to BioticFlux
  ↓
  Now all biomes have same emojis
  ↓
  User: "Tool 4 → place fire tap"
  ↓
  Any biome → place fire tap works

Advantages:
  ✓ Simplest solution (universal emoji set)
  ✓ No biome identification needed
  ✓ No boundary issues
  ✓ Kitchen can always find fire/water/flour

Disadvantages:
  ✗ Loses biome thematic separation
  ✗ Kitchen biome has fire (thematic)
  ✗ Forest biome has water (thematic)
  ✗ Breaks emergent gameplay (where to tap?)

Quantum Rigor:
  ✗ Breaks biome autonomy
  ✗ Forces unphysical emoji overlap
  ✗ Loses quantum habitat concept

Implementation:
  - In each biome _ready(): inject all emojis
  - Handler: place_energy_tap works anywhere
  - No biome lookup needed
```

---

### Recommendation: Choose One
**Option B2** is recommended:
- Matches Model B (biome-level bath)
- Maintains biome autonomy
- Proper quantum Lindblad drains
- Requires good UI communication

**Option B1** works if you want taps to be visible structures.

---

## Decision C: Cross-Biome Resource Access

### The Question
**How does kitchen access fire/water from different biomes?**

### Current Problem
```
Kitchen placed on BioticFlux plots
Kitchen qubit created with fire/water/flour inputs
Fire lives in Kitchen bath (not BioticFlux)
Water lives in Forest bath (not BioticFlux)
Flour from Mill (in BioticFlux)

Kitchen needs to QUERY:
  🔥 from Kitchen bath
  💧 from Forest bath
  💨 from Mill output

But biomes are isolated quantum systems!
No message passing between baths.
```

---

### Option C1: Kitchen Biome Only
**"Kitchen can only be placed IN Kitchen biome"**

```
Design:
  - Kitchen is a building (like Mill)
  - Can ONLY be placed on Kitchen biome plots
  - Accesses fire/water/flour from local Kitchen bath
  - Flour comes from (imported) Mill output

Architecture:
  Kitchen biome:
    ├─ Local fire (🔥) quantum state
    ├─ Local water (💧) from ecosystem
    ├─ Local flour (📥 imported from BioticFlux mill)
    ├─ Kitchen buildings placed here
    └─ Ready to bake

Advantages:
  ✓ Clear: "go to kitchen to bake"
  ✓ Simple: local biome bath access
  ✓ Thematic: kitchen is a specific location
  ✓ No cross-biome complexity

Disadvantages:
  ✗ Kitchen not on farm grid (separate location?)
  ✗ Flour must be transported (new UI?)
  ✗ Breaks "integrated farm" feel
  ✗ More game structure needed

Quantum Rigor:
  ✓ Each biome operates independently
  ✓ No cross-bath entanglement
  ✓ Clean quantum separation

Implementation:
  - Create Kitchen-specific grid section
  - Mill output → Kitchen input (delivery system)
  - Kitchen only placed on Kitchen plots
```

---

### Option C2: Kitchen Cross-Biome Aware
**"Kitchen queries resources from multiple biome baths"**

```
Design:
  Kitchen is a special structure
  ├─ Can be placed anywhere (like mill)
  ├─ Queries fire from Kitchen bath
  ├─ Queries water from Forest bath
  ├─ Queries flour from local mill
  └─ Aggregates and creates Bell state

Architecture:
  kitchen_biome = farm.kitchen_biome
  forest_biome = farm.forest_biome
  local_biome = get_biome_for_plot(kitchen_plot)

  fire_flux = kitchen_biome.get_tap_flux("🔥")
  water_flux = forest_biome.get_tap_flux("💧")
  flour_flux = local_biome.get_mill_flour()

  bell_state = create_bell(fire_flux, water_flux, flour_flux)

Advantages:
  ✓ Placed anywhere (flexible)
  ✓ Integrates multiple biome systems
  ✓ Teaches multi-system interaction
  ✓ Complex = more learning

Disadvantages:
  ✗ Kitchen "knows" about other biomes (coupling)
  ✗ Fragile: dependency on Kitchen/Forest/etc.
  ✗ What if biome not available? (error state)
  ✗ Quantum violation? (entangling across baths?)

Quantum Rigor:
  ⚠️ Debatable: Is cross-bath entanglement valid?
  Argument for: Bell state uses qubits from different baths
  Argument against: Baths are independent quantum computers
  Need decision: Can we create entanglement across baths?

Implementation:
  - Kitchen._process() queries multiple biomes
  - Fallback if biome missing (produce less bread?)
  - Careful with quantum state combination
```

---

### Option C3: Unified Global Quantum Computer
**"All biomes feed into one global bath"**

```
Design:
  Instead of per-biome quantum_computer:
  ├─ One GLOBAL quantum_computer (farm.quantum_computer)
  ├─ All emojis live in global state
  ├─ All Hamiltonians feed into global H
  ├─ All Lindblad operators in global L
  └─ Kitchen just measures global state

Architecture:
  farm.quantum_computer (size = total emojis across all biomes)
  ├─ Wheat register (from BioticFlux)
  ├─ Fire register (from Kitchen)
  ├─ Water register (from Forest)
  ├─ etc...

  H_global = H_bioticflux + H_kitchen + H_forest + ...
  L_global = [all Lindblad operators]

Advantages:
  ✓ Natural cross-system entanglement
  ✓ Kitchen naturally accesses all resources
  ✓ Maximalist quantum approach
  ✓ True multi-system quantum

Disadvantages:
  ✗ Complete architecture rewrite
  ✗ Massive quantum computer (all emojis)
  ✗ Computational cost (exponential in size)
  ✗ Loses biome autonomy/isolation
  ✗ Breaks current Model B

Quantum Rigor:
  ✓ True quantum (everything entangled)
  ✗ Computationally intractable
  ✗ Loses emergent biome structures

Implementation:
  - Rewrite entire Farm initialization
  - Merge all biome baths
  - Redirect all plot registers to global computer
  - Update all simulation code
  [NOT RECOMMENDED for this scope]
```

---

### Recommendation: Choose One
**Option C2** is recommended:
- Balances localization and integration
- Teaches complex systems interaction
- Requires careful quantum handling
- Rich learning potential

**Option C1** is simpler if you want to separate Kitchen physically.

---

## Summary: Your Decisions

### Decision A: Mill Measurement
Choose: **A1 (Destructive)**, **A2 (Non-Destructive + Locking)**, or **A3 (Renewable)**

### Decision B: Energy Tap Architecture
Choose: **B1 (Plot-Level)**, **B2 (Biome-Level)**, or **B3 (Auto-Injected)**

### Decision C: Cross-Biome Access
Choose: **C1 (Kitchen Biome Only)**, **C2 (Cross-Biome Aware)**, or **C3 (Global Bath)**

---

## Making the Decision

### Alignment Questions
1. **Quantum Rigor**: How "real" should kitchen be?
   - Option: Toybox-ish (C3) → Educational (A2, B2, C2) → Realistic (A1, B1)

2. **Complexity**: How much learning should it enable?
   - Option: Simple (A3, B3, C1) → Moderate (B2, C2) → Complex (A2, B1)

3. **Thematic**: What's the kitchen conceptually?
   - Option: Renewable farm tool (A3) → Scientific apparatus (A2, B2) → Sacred place (C1)

4. **Scope**: How much architecture change is acceptable?
   - Option: Minimal (A3, B3, C1) → Moderate (A2, B2) → Major (C3)

### Recommended Combination
For "tutorial + smoke test" intent:
```
A2: Non-destructive measurement (teaches measurement physics)
B2: Biome-level taps (teaches Lindblad mechanics)
C2: Cross-biome aware kitchen (teaches system integration)
```

This gives maximum learning while staying coherent.

---

## Next Steps

1. **Review** each option carefully
2. **Pick** your choice for A, B, C
3. **Return** with decisions
4. **Implement** according to design
5. **Test** against smoke tests

Ready when you are!
