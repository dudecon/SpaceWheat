# 🎮 Kitchen Gameplay Loop - Specification

**What It Is**: The complete player workflow from planting wheat to making bread
**What It Teaches**: Quantum mechanics, farming, resource management, measurement
**What It Tests**: Real quantum entanglement, not toy physics

---

## The Complete Kitchen Loop (7 Steps)

### 🌾 Step 1: Plant Wheat

**Player Action**:
```
Keyboard: 1 (Grower tool) → T (select plot) → Q → Q (plant wheat)
```

**What Happens**:
```
Plot (0,0) gets allocated a quantum register in BioticFlux biome
Wheat state: |ψ_wheat⟩ = α|🌾⟩ + β|👥⟩
             (north = 🌾 Wheat, south = 👥 Labor)

Physical Reality:
  - Wheat qubit enters superposition
  - Starts entangled with biome environment
  - Can evolve under Hamiltonian (growing)
  - Can decohere if measured badly
```

**What Player Learns**:
- "I planted something quantum"
- Visible: Resource cost (-1 wheat), plot shows wheat emoji
- Hidden: State is superposition, not classical

---

### 🏭 Step 2: Place Mill BEFORE Harvest

**Player Action**:
```
Keyboard: 3 (Industry tool) → Y (different plot) → Q → Q (place mill)
         (CRITICAL: Must be ADJACENT to wheat plots!)
```

**What Happens**:
```
Mill couples to all adjacent wheat via ancilla measurement:

For each wheat plot:
  Mill queries: quantumComputer.get_marginal_purity(wheat_register)
  Result: purity P (probability of measuring wheat in north state)

  Outcome: rand() < P  →  Flour produced ✓
           rand() > P  →  No flour this frame ✗

Loop: Every 1.0 second, mill performs measurement
      (purity ≈ 0.8-1.0 for young wheat → flour probability high)
```

**What Player Learns**:
- "Mill couples to wheat"
- "Measurement produces flour (probabilistically)"
- "I'm not destroying wheat, just measuring it"
- Visible: Flour accumulates (10+ credits/second)
- Hidden: Non-destructive measurement, purity-based outcome

---

### 💨 Step 3: Wait for Flour Production

**Player Action**:
```
Nothing - just watch it happen
Keyboard: ESC (open menu) → check economy panel
```

**What Happens**:
```
For 5 seconds:
  Mill measures wheat at t=1s, t=2s, t=3s, t=4s, t=5s
  Each measurement: wheat has ~high purity → flour outcome likely
  Total flour: ~50-100 credits (depends on purity)
```

**What Player Learns**:
- "Measurement is probabilistic"
- "More measurements = more flour"
- "But wheat is still there (not consumed)"
- Visible: Flour counter rising
- Hidden: Purity-based quantum behavior

**PHYSICS QUESTION #1**:
> Is this correct? Should wheat stay planted after measurement?
>
> Current: Yes, wheat stays (non-destructive)
> Problem: Can be re-measured infinitely
>
> Options:
> - A: Mill should CONSUME wheat (destructive)
> - B: Mill should LOCK outcome (track measured state)
> - C: This is correct (wheat renewable?)

---

### 🌾 Step 4: Harvest Wheat

**Player Action**:
```
Keyboard: 1 (Grower tool) → T (wheat plot) → R (measure + harvest)
```

**What Happens**:
```
harvest_plot(position) calls:

  1. Measure wheat in its basis: |🌾⟩ or |👥⟩
  2. Get purity from quantum_computer
  3. Calculate yield based on purity
  4. Remove wheat register from biome bath
  5. Emit wheat credits to economy

Result: ~20 wheat credits (from 2x purity multiplier)
        Wheat plot becomes empty
```

**What Player Learns**:
- "Harvest is a MEASUREMENT (not separate from mill)"
- "Harvest gives you wheat credits"
- "Plot is now empty"
- Visible: Wheat credits appear, plot cleared
- Hidden: Harvest outcome depends on purity history

**PHYSICS QUESTION #2**:
> Does harvest measure the SAME state that mill measured?
> Or a FRESH measurement of whatever's left?
>
> Current: Fresh measurement of remaining state
> Issue: If mill already measured, what's left?
>
> Options:
> - A: Mill and harvest measure DIFFERENT bases
> - B: Harvest gets the OUTCOME of last mill measurement
> - C: Wheat is in TWO registers (one for mill, one for harvest)

---

### ⚡ Step 5: Place Energy Taps

**Player Action** (intended):
```
Keyboard: 4 (Biome Control) → [select plot in KITCHEN biome]
          → Q (Energy Tap submenu) → Q (Fire Tap)

Then:     4 → [select plot in FOREST biome]
          → Q → E (Water Tap)
```

**What Should Happen**:
```
Fire Tap on Kitchen biome:
  Creates Lindblad drain: L = √κ |⬇️⟩⟨🔥|
  Kitchen bath's fire state → sink state
  Flux accumulates in sink over 5 seconds
  FarmGrid._process_energy_taps() routes flux → economy
  Result: ~100 fire credits

Water Tap on Forest biome:
  Creates Lindblad drain: L = √κ |⬇️⟩⟨💧|
  Forest bath's water state → sink state
  Similar result: ~100 water credits
```

**What Player Should Learn**:
- "Taps harvest energy from biome quantum states"
- "Fire comes from Kitchen biome"
- "Water comes from Forest biome"
- "Measurement produces classical resources"
- Visible: Fire and water credits appear
- Hidden: Lindblad drains, Markovian dynamics

**CURRENT STATUS**: ❌ BROKEN
```
Error: "Target icon 🔥 not found in biome BioticFlux"

Issues:
  1. Fire emoji doesn't exist in BioticFlux
  2. FarmInputHandler blocks empty plots
  3. No clear biome-to-tap mapping

PHYSICS QUESTION #3**:
> Where do fire and water qubits live?
> How does kitchen access them?
>
> Current Problem:
>   Fire in Kitchen bath
>   Water in Forest bath
>   Kitchen placed on BioticFlux plots
>   No connection
>
> Options:
> - A: Taps auto-inject emojis into all biomes
> - B: Kitchen is cross-biome aware
> - C: Kitchen only placed in Kitchen biome
> - D: Fire/water are special (not in specific biome)
```

---

### 🍳 Step 6: Place Kitchen

**Player Action**:
```
Keyboard: 3 (Industry) → T,Y,U (select 3 plots) → R (place kitchen)
```

**What Happens**:
```
Kitchen takes three inputs from economy:
  - 🔥 Fire (≥10 units from energy tap)
  - 💧 Water (≥10 units from energy tap)
  - 💨 Flour (≥10 units from mill)

Creates 3-qubit Bell state:
  |ψ_kitchen⟩ = α|🔥⟩|💧⟩|💨⟩ + β|🍞⟩

Hamiltonian evolution (bread icon drives toward 🍞):
  H = bread_icon (Hamiltonian)

Measurement (collapses in bread basis):
  Outcome: |🍞⟩ (with probability p)

Bread produced:
  bread_units = (fire + water + flour) × 0.8 efficiency
  Example: 10 + 10 + 16 = 36 units → 36 × 0.8 = 28.8 units
           = 288 bread credits ✓
```

**What Player Learns**:
- "Bell states = quantum entanglement"
- "Measurement collapses superposition"
- "Efficiency = quantum energy loss"
- "Complex resources → bread (staple)"
- Visible: Bread credits accumulate
- Hidden: 3-qubit entanglement mechanics

**CURRENT STATUS**: ✅ WORKS!
```
Kitchen successfully:
  - Creates Bell states
  - Measures and collapses
  - Produces bread

Test result: 10+10+16 units → 280 bread credits ✓
Efficiency: 80% as designed ✓
```

---

### 🍞 Step 7: Watch Bread Accumulate

**Player Action**:
```
Just watch the counter rise
Or ESC to check economy panel
```

**What Happens**:
```
Kitchen repeats measurement every frame:
  - Monitor economy for 🔥, 💧, 💨
  - If available, create Bell state
  - Measure and produce bread
  - Consume inputs

Bread accumulates until:
  - One resource runs out
  - Kitchen is removed
  - Player builds something else
```

**What Player Learns**:
- "Quantum cooking is FAST"
- "Resources → bread in real-time"
- "Economy is visible feedback loop"
- Visible: Bread counter climbing
- Hidden: Nothing (all visible now)

---

## Tutorial Arc (What Player Learns)

### Beginning (Steps 1-2)
**Concept**: Quantum superposition and non-destructive measurement
```
"I planted wheat and it's in superposition.
 Mill can measure it without destroying it.
 This is not classical."
```

### Middle (Steps 3-4)
**Concept**: Probabilistic outcomes and destructive measurement
```
"Mill gives probabilistic flour outcomes.
 Harvest is also a measurement.
 Probability comes from quantum purity."
```

### Advanced (Step 5)
**Concept**: Energy drains and Lindblad evolution
```
"Biomes have quantum states that can drain energy.
 Lindblad operators model energy loss.
 Measurement extracts classical resources."
```

### Expert (Steps 6-7)
**Concept**: Multi-qubit entanglement and Bell states
```
"Complex systems: 3-qubit entanglement.
 Bell state measurement is quantum signature.
 This is REAL quantum, not approximation."
```

---

## Smoke Test: What Proves This Is Real Quantum

### Test 1: Purity Matters
```
Expected: Purity directly affects flour outcome probability
Proof: Modify wheat purity, see flour rate change
Quantum: True probabilistic outcome (not random seed)
```

### Test 2: Entanglement
```
Expected: 3-qubit Bell state produces bread
Proof: Measure 3-qubit system, get Bell state signature
Quantum: True multi-qubit correlation
```

### Test 3: Measurement Collapse
```
Expected: After harvest, wheat is gone (measurement collapsed it)
Proof: Second harvest attempt returns error or zero
Quantum: True state collapse (not reset)
```

### Test 4: Energy Conservation
```
Expected: Input energy (fire+water+flour) → bread with efficiency loss
Proof: (input_units) × 0.8 = bread_units (with quantum fluctuation)
Quantum: Real energy transfer, not just multiplication
```

### Test 5: Biome Dynamics
```
Expected: Fire/water accumulate following Lindblad drains
Proof: Measure accumulation rate, matches theoretical prediction
Quantum: True Markovian evolution
```

---

## Current Blockers

| Step | Status | Blocker |
|------|--------|---------|
| 1: Plant | ✅ Works | None |
| 2: Mill | ✅ Works | Mill doesn't consume wheat |
| 3: Wait | ✅ Works | N/A |
| 4: Harvest | ✅ Works | Ambiguous interaction with mill |
| 5: Taps | ❌ Broken | Fire emoji not in BioticFlux; tap placement fails |
| 6: Kitchen | ✅ Works | Depends on taps working |
| 7: Watch | ✅ Works | Depends on taps working |

---

## Design Decisions Needed

### For Step 2: Mill Physics
- Destructive or non-destructive?
- Can wheat be re-measured?
- What does "measured_outcome" actually mean?

### For Step 5: Energy Taps
- Where do taps live in architecture?
- How to map keyboard UI to physics?
- How to inject emojis into biomes?

### For Step 6: Kitchen Cross-Biome Access
- How does kitchen query fire/water from other biomes?
- Should kitchen be in all biomes or just Kitchen?
- How to handle resource ownership?

---

## Next: Systems Analysis

Read `02_SYSTEMS_ANALYSIS.md` to understand how each step actually works in code.
