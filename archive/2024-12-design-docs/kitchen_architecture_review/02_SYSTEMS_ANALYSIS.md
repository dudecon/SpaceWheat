# ⚙️ Systems Analysis - How Things Work

**Purpose**: Deep dive into each system's implementation and interactions
**Audience**: Developers implementing the architecture decisions

---

## System 1: Wheat + Harvest

### Wheat Planting
**Code**: `Core/Farm.gd:build()` + `Core/GameMechanics/FarmGrid.gd:plant_wheat()`

```gdscript
farm.build(Vector2i(0, 0), "wheat")
```

**Process**:
```
1. FarmGrid.plant_wheat(position)
2. Get plot at position
3. Allocate quantum register in parent_biome.quantum_computer
4. Initialize state as superposition: |wheat⟩ ⊗ |labor⟩
   - north_emoji = "🌾" (wheat/growth)
   - south_emoji = "👥" (labor/work)
5. Register enters biome's quantum bath
6. Hamiltonian evolution begins (wheat grows under sunlight coupling)
```

**State Storage**:
- **Old Model**: Quantum state stored on `FarmPlot` (plot.quantum_state)
- **Current Model B**: State lives in `biome.quantum_computer` (density matrix)
- **Plot reference**: `plot.register_id` (index into density matrix)

**Purity Evolution**:
- **New wheat**: purity ≈ 0.5 (balanced superposition)
- **Growing wheat**: purity ≈ 0.6-0.8 (more in wheat state)
- **Ready wheat**: purity ≈ 1.0 (almost pure wheat)

**Biome Context**:
- Wheat planted in **BioticFlux** biome
- BioticFlux has Hamiltonian: H = sunlight coupling
- Sunlight drives wheat state toward north (🌾)

---

### Wheat Harvest
**Code**: `Core/Farm.gd:harvest_plot()` + `Core/GameMechanics/FarmGrid.gd`

```gdscript
farm.harvest_plot(Vector2i(0, 0))
```

**Process**:
```
1. Get plot's register_id from biome.quantum_computer
2. Measure wheat in {🌾, 👥} basis
3. Get purity: P(🌾 outcome)
4. Calculate yield: purity × yield_multiplier
5. Produce wheat credits to economy
6. Remove register from quantum_computer
7. Clear plot (set is_planted = false)
```

**Measurement Semantics**:
- **Destructive**: Register removed from bath after measurement
- **Outcome-dependent**:
  - If measured as 🌾: Full wheat credits
  - If measured as 👥: Reduced labor credits
- **No re-measurement**: Plot is empty after harvest

**Yield Calculation**:
```
yield_multiplier = 2.0  (hardcoded)
purity = quantum_computer.get_marginal_purity(register)
wheat_units = int(purity * yield_multiplier)
wheat_credits = wheat_units * 10  (quantum-to-credits conversion)

Example: purity=1.0 → 2.0 units → 20 credits ✓
```

---

## System 2: Mill Measurement

### Mill Placement
**Code**: `Core/GameMechanics/FarmGrid.gd:place_mill()`

```gdscript
farm.grid.place_mill(Vector2i(1, 0))  // adjacent to wheat at (0,0)
```

**Process**:
```
1. Get plot at position
2. Mark as MILL (plot.plot_type = MILL)
3. Create QuantumMill object
4. Find all ADJACENT wheat plots (4-connected)
5. Link wheat registers to mill
6. Add mill to grid.quantum_mills dictionary
7. Mill enters processing loop
```

**Adjacent Wheat Detection**:
```gdscript
func _get_adjacent_wheat(position: Vector2i) -> Array:
    var adjacent = []
    for direction in [UP, DOWN, LEFT, RIGHT]:
        var adj_pos = position + direction
        var adj_plot = get_plot(adj_pos)
        if adj_plot and adj_plot.is_planted and
           adj_plot.plot_type == PlotType.WHEAT:
            adjacent.append(adj_plot)
    return adjacent
```

**Critical**: Mill MUST be adjacent to wheat!
```
✓ Wheat at (0,0), Mill at (1,0) → Adjacent
✓ Wheat at (0,0), Mill at (0,1) → Adjacent
✗ Wheat at (0,0), Mill at (3,0) → NOT adjacent (3 spaces away)
```

---

### Mill Measurement Loop
**Code**: `Core/GameMechanics/QuantumMill.gd:_process()` + `perform_quantum_measurement()`

```gdscript
func _process(delta: float):
    last_measurement_time += delta
    if last_measurement_time >= measurement_interval:  // 1.0 second
        perform_quantum_measurement()
        last_measurement_time = 0.0
```

**Measurement Process**:
```
For each entangled wheat:

1. Get wheat's parent biome
2. Get quantum_computer from biome
3. Get component containing wheat's register
4. Query purity: P(🌾 | wheat_register)
   - purity = probability of measuring wheat state as 🌾
   - High purity = wheat is well-developed
   - Low purity = wheat still developing

5. Determine flour outcome: rand() < purity
   - If true: Flour outcome ✓
   - If false: No flour this frame

6. If flour outcome:
   - Mark plot: plot.has_been_measured = true
   - Record outcome: plot.measured_outcome = plot.south_emoji
   - Increment flour counter
```

**Key Code Section** (QuantumMill.gd:100-110):
```gdscript
# Flour outcome: probabilistic based on purity
var flour_outcome = randf() < purity

if flour_outcome:
    total_flour += 1
    accumulated_wheat += 1
    plot.has_been_measured = true
    plot.measured_outcome = plot.south_emoji  // 👥
    print("    ✓ Flour produced!")
```

**Flour Conversion**:
```
flour_units = total_flour_count
flour_credits = flour_units * 10

Example: 1 flour per second × 5 seconds = 50 flour units = 500 credits
But test shows: 160 credits (16 units)
```

---

### Critical Issue: Wheat Not Consumed
**Code**: `Core/GameMechanics/QuantumMill.gd:100-110`

```
PROBLEM:
  plot.has_been_measured = true  ✓ (marked)
  plot.measured_outcome = "👥"   ✓ (recorded)
  ✗ plot.is_planted = true       (STILL TRUE!)
  ✗ Wheat NOT removed from quantum_computer

RESULT:
  Next measurement (t=2s): Wheat STILL THERE
  Measurement repeats: Flour produced AGAIN
  = Same wheat measured infinitely
```

**Evidence**:
```
t=1s: Wheat at (0,0) is_planted=true, purity=1.0 → flour ✓
t=2s: Wheat at (0,0) is_planted=true, purity=1.0 → flour ✓
t=3s: Wheat at (0,0) is_planted=true, purity=1.0 → flour ✓
...
= Infinite flour from single wheat ✗
```

**Implication**:
This is either:
- **A Bug**: Wheat should be consumed after first measurement
- **Intentional**: Wheat is like a renewable resource
- **Design Gap**: Missing "outcome tracking" system

---

## System 3: Energy Taps (Lindblad Drains)

### Architecture (Model B)
**Code**: `Core/Environment/BiomeBase.gd:place_energy_tap()`

```
Tap is NOT a plot structure.
Tap is NOT a building.
Tap is a BIOME-LEVEL quantum operation.

Tap = Lindblad drain operator: L = √κ |⬇️⟩⟨target|
```

**Process**:
```
1. Get biome's quantum_computer (bath)
2. Find target emoji in bath.active_icons (e.g., 🔥)
3. Get sink emoji (⬇️)
4. Add drain: icon.lindblad_outgoing[sink_emoji] += drain_rate
5. Rebuild Lindblad matrix with new drain
6. Flux accumulates in sink state over time
```

**Lindblad Equation**:
```
dρ/dt = -i[H, ρ] + L_drain(ρ)
where L_drain(ρ) = √κ * (|sink⟩⟨target| ρ |target⟩⟨sink| - 0.5{L†L, ρ})

This causes target_emoji population to drain into sink_emoji.
```

**Code**:
```gdscript
func place_energy_tap(target_emoji: String, drain_rate: float = 0.05) -> bool:
    var target_icon: Icon = null
    for icon in bath.active_icons:
        if icon.emoji == target_emoji:
            target_icon = icon
            break

    if not target_icon:
        push_warning("Target icon %s not found in biome %s" %
                     [target_emoji, get_biome_type()])
        return false

    # Add drain operator
    var sink_emoji = "⬇️"
    if not target_icon.lindblad_outgoing.has(sink_emoji):
        target_icon.lindblad_outgoing[sink_emoji] = 0.0

    target_icon.lindblad_outgoing[sink_emoji] += drain_rate
    bath.build_lindblad_from_icons(bath.active_icons)

    return true
```

---

### Flux Accumulation
**Code**: `Core/GameMechanics/FarmGrid.gd:_process_energy_taps()`

```gdscript
func _process_energy_taps(delta: float) -> void:
    for plot_pos in plots:
        var plot = plots[plot_pos]
        if plot.plot_type != PlotType.ENERGY_TAP:
            continue

        var target_emoji = plot.tap_target_emoji
        var biome = get_biome_for_plot(plot_pos)

        # Get flux drained into sink this frame
        var flux = biome.get_tap_flux(target_emoji)

        # Accumulate
        plot.tap_accumulated_resource += flux

        # When accumulated enough, emit to economy
        if plot.tap_accumulated_resource >= 10.0:
            var resource_units = int(plot.tap_accumulated_resource / 10.0)
            farm_economy.add_resource(target_emoji, resource_units * 10, "energy_tap_drain")
            plot.tap_accumulated_resource = 0.0
```

---

### Current Problem: Tap Placement Fails

**Two-Layer Mismatch**:

**Layer 1: UI Handler** (`FarmInputHandler.gd:1388`)
```gdscript
func _action_place_energy_tap_for(positions: Array[Vector2i], target_emoji: String):
    for pos in positions:
        var plot = farm.grid.get_plot(pos)
        if not plot or not plot.is_planted:
            continue  // ← SKIPS if plot empty!

        var biome = farm.grid.get_biome_for_plot(pos)
        if biome and biome.place_energy_tap(target_emoji, 0.05):
            success_count += 1
```

**Layer 2: Physics** (`BiomeBase.gd:710-717`)
```gdscript
var target_icon: Icon = null
for icon in bath.active_icons:
    if icon.emoji == target_emoji:
        target_icon = icon
        break

if not target_icon:
    push_warning("Target icon %s not found in biome %s" %
                 [target_emoji, get_biome_type()])
    return false
```

**Actual Failure**:
```
User Action: Tool 4 → Select plot in BioticFlux → Q → Q (Fire Tap)

Handler: "Is plot planted?" Yes → Call biome.place_energy_tap("🔥")
Physics: "Does BioticFlux have 🔥 icon?" No → WARNING
Result: Silent failure

Output: "Target icon 🔥 not found in biome BioticFlux"
```

**Why No Fire in BioticFlux?**
```
BioticFlux.active_icons = [
    🌾 (wheat),
    ☀️ (sunlight),
    🌙 (moonlight),
    🍄 (mushroom),
    🍂 (detritus),
    ❌ (decay)
]

Fire (🔥) is in Kitchen biome, not BioticFlux!
```

---

## System 4: Kitchen (3-Qubit Bell State)

### Kitchen Input Collection
**Code**: `Core/Environment/QuantumKitchen_Biome.gd`

```
Kitchen monitors economy for:
  🔥 Fire (≥10 units)
  💧 Water (≥10 units)
  💨 Flour (≥10 units)
```

### Bell State Creation
**Code**: `QuantumKitchen_Biome.gd:create_bread_entanglement()`

```gdscript
func create_bread_entanglement(fire_units, water_units, flour_units):
    # Create 3-qubit state
    var fire_qubit = DualEmojiQubit.new("🔥", "❄️")
    var water_qubit = DualEmojiQubit.new("💧", "❄️")
    var flour_qubit = DualEmojiQubit.new("💨", "🌾")

    # Store amounts in metadata (not in radius)
    fire_qubit.set_meta("resource_units", float(fire_units))
    water_qubit.set_meta("resource_units", float(water_units))
    flour_qubit.set_meta("resource_units", float(flour_units))

    # Create entangled state
    var bell_state = bell_detector.create_superposition(
        [fire_qubit, water_qubit, flour_qubit],
        "🍞"  // measurement basis
    )

    return bell_state
```

**Entanglement Form**:
```
|ψ_kitchen⟩ = α|🔥⟩|💧⟩|💨⟩ + β|🍞⟩

Where:
  |🔥⟩|💧⟩|💨⟩ = "input state" (separate resources)
  |🍞⟩ = "bread outcome" (single unified resource)

Amplitudes:
  α² ≈ 0.2 (small chance of staying separated)
  β² ≈ 0.8 (high chance of becoming bread)
```

### Measurement (Bread Basis)
**Code**: `QuantumKitchen_Biome.gd:measure_as_bread()`

```gdscript
func measure_as_bread(bell_state) -> int:
    # Measure in bread basis
    var outcome = bell_detector.measure_in_basis(bell_state, "🍞")

    if outcome == "🍞":
        # Got bread!
        var total_units = 0
        for qubit in [fire, water, flour]:
            total_units += qubit.get_meta("resource_units", 0)

        # Apply efficiency
        var bread_units = int(total_units * bread_production_efficiency)  // 0.8

        return bread_units * 10  // Convert to credits
    else:
        // Measured as separate resources (rare)
        return 0
```

**Efficiency**: 80% (0.8)
```
Input: 🔥10 + 💧10 + 💨16 = 36 total units
Efficiency loss: 36 × 0.8 = 28.8 units
Output: 28.8 × 10 = 288 bread credits

But test shows: 280 credits
Difference: Rounding or FLOOR() instead of ROUND()
```

---

## System Interactions

### The Complete Chain
```
1. Plant Wheat (BioticFlux)
   ↓
2. Mill Adjacent
   ├─ Measures wheat
   ├─ Produces flour (to economy)
   └─ Wheat stays planted ⚠️
   ↓
3. Harvest Wheat
   ├─ Measures remaining state
   ├─ Produces wheat (to economy)
   └─ Clears plot
   ↓
4. Energy Taps
   ├─ Fire from Kitchen bath
   ├─ Water from Forest bath
   └─ Produce to economy
   ↓
5. Kitchen
   ├─ Takes inputs: fire+water+flour
   ├─ Creates Bell state
   ├─ Measures → bread
   └─ Produces bread (to economy)
```

### Cross-Biome Issues
```
BioticFlux bath:  🌾 wheat
Kitchen bath:     🔥 fire, 🍞 bread
Forest bath:      💧 water, 🐺 predators, etc.
Market bath:      💨 flour (or produced by mill)

Kitchen needs to access:
  🔥 from Kitchen bath
  💧 from Forest bath
  💨 from Mill (in BioticFlux)

Current: No mechanism to query across biome boundaries!
```

---

## Summary: What Works vs. What Doesn't

### ✅ Working
- Wheat planting and quantum register allocation
- Wheat evolution under Hamiltonian
- Wheat harvest measurement and removal
- Mill measurement and flour production
- Kitchen Bell state creation
- Kitchen measurement and bread production
- Keyboard controls (wheat/kitchen)

### ⚠️ Ambiguous
- Mill consumption semantics (destructive? non-destructive? partial?)
- Wheat after measurement (why does it stay planted?)
- Harvest interaction with mill (what if mill already measured?)

### ❌ Broken
- Energy tap placement via keyboard (emoji not in biome)
- Fire/water tap UI (can't select target biome)
- Cross-biome resource access (kitchen can't see fire/water)

---

## Next Steps

1. **Read**: `03_QUANTUM_MECHANICS_REQUIREMENTS.md` (rigor questions)
2. **Review**: `05_DESIGN_DECISION_FRAMEWORK.md` (what to decide)
3. **Examine**: `06_SIMULATION_EVIDENCE.md` (test traces)
