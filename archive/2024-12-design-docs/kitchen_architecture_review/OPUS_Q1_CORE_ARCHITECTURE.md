# Q1: Core Architecture Files - Detailed Analysis

**Question**: I need to see the key implementation files to understand what "tangling" has occurred.

**Status**: Physics-correct Model B implementation with layer mismatch in UI-Physics boundary

---

## The Three Core Files Examined

### 1. FarmGrid.gd - Orchestration Layer

**File**: `Core/GameMechanics/FarmGrid.gd` (1500+ lines)

**Key Characteristics**:
- Central orchestrator for all game mechanics
- Owns plot storage and biome registry
- Coordinates with quantum_mills, markets, kitchens
- Implements Model B register allocation

**Critical Sections**:

```gdscript
# Lines 36-75: Data Structures (The Entanglement)
var plots: Dictionary = {}           # Vector2i → FarmPlot
var entangled_pairs: Array = []      # Array of EntangledPair objects
var entangled_clusters: Array = []   # Array of EntangledCluster objects
var quantum_mills: Dictionary = {}   # Vector2i → QuantumMill
var biomes: Dictionary = {}          # String → BiomeBase (NEW: Multi-biome)
var plot_biome_assignments: Dictionary = {}  # Vector2i → String (NEW)
var plot_register_mapping: Dictionary = {}   # Vector2i → int (NEW: Model B)
var plot_to_biome_quantum_computer: Dictionary = {}  # Vector2i → QuantumComputer ref
```

**The Tangling Issue** (Lines 65-74):
```
Legacy layer (single biome):
  var biome = null  # Old architecture

New layer (multi-biome):
  var biomes: Dictionary = {}
  var plot_biome_assignments: Dictionary = {}
  var plot_register_mapping: Dictionary = {}
  var plot_to_biome_quantum_computer: Dictionary = {}

Both exist side-by-side! Code checks both.
Example line 131-133:
  var has_biomes = not biomes.is_empty()
  if not biome and not has_biomes:
      return
```

**Processing Loop** (Lines 124-150):
```gdscript
func _process(delta):
    # Checks BOTH legacy and new biome modes
    var has_biomes = not biomes.is_empty()
    if not biome and not has_biomes:
        return

    _apply_icon_effects(delta)
    _apply_entangled_pair_decoherence(delta)

    # Routes each plot to CORRECT biome
    for position in plots.keys():
        var plot = plots[position]
        if plot.is_planted:
            var plot_biome = get_biome_for_plot(position)  # Multi-biome aware
            plot.grow(delta, plot_biome, ...)
```

**Key Function** (Lines ~860):
```gdscript
func get_biome_for_plot(position: Vector2i):
    """Route plot to correct biome (fallback chain)"""
    # Check explicit assignment
    if plot_biome_assignments.has(position):
        var biome_name = plot_biome_assignments[position]
        if biomes.has(biome_name):
            return biomes[biome_name]

    # Default to BioticFlux
    if biomes.has("BioticFlux"):
        return biomes["BioticFlux"]

    # Legacy fallback
    return biome
```

---

### 2. QuantumMill.gd - Measurement Behavior

**File**: `Core/GameMechanics/QuantumMill.gd` (~150 lines)

**Design**: Non-destructive measurement with purity-based outcomes

**Key Method** (Lines 52-130):
```gdscript
func perform_quantum_measurement() -> void:
    """Measure wheat plots based on purity"""
    if entangled_wheat.is_empty():
        return

    var total_flour = 0

    for plot in entangled_wheat:
        if not plot or not plot.is_planted:
            continue

        # Model B: Query biome's quantum_computer
        var biome = plot.parent_biome
        if not biome or not biome.quantum_computer:
            continue

        # Get component containing wheat register
        var comp = biome.quantum_computer.get_component_containing(plot.register_id)
        if not comp:
            continue

        # Get purity (P of measuring |north⟩ = wheat)
        var purity = biome.quantum_computer.get_marginal_purity(comp, plot.register_id)

        # Probabilistic outcome based on purity
        var flour_outcome = randf() < purity

        if flour_outcome:
            total_flour += 1
            plot.has_been_measured = true
            plot.measured_outcome = plot.south_emoji
            print("    ✓ Flour produced!")

    # Convert to economy
    if total_flour > 0 and farm_grid:
        if farm_grid.has_method("process_mill_flour"):
            farm_grid.process_mill_flour(total_flour)
```

**Physics Correct**: ✅
- Queries marginal purity from density matrix
- Uses purity as measurement probability
- Non-destructive: doesn't collapse state

**Issue**: Wheat marked as `has_been_measured=true` but never consumed
- Can be measured again next frame
- No outcome locking mechanism
- Infinite flour possible

---

### 3. FarmInputHandler.gd - Energy Tap Placement

**File**: `UI/FarmInputHandler.gd` (~1500 lines)

**Energy Tap Handler** (Lines 1368-1399):

```gdscript
func _action_place_energy_tap_for(positions: Array[Vector2i], target_emoji: String):
    """Place energy tap targeting specific emoji (Model B)"""

    if not farm or not farm.grid:
        action_performed.emit("place_energy_tap", false, "Farm not loaded")
        return

    if positions.is_empty():
        action_performed.emit("place_energy_tap", false, "No plots selected")
        return

    print("💧 Placing energy taps targeting %s on %d plots..." % [target_emoji, positions.size()])

    var success_count = 0

    for pos in positions:
        var plot = farm.grid.get_plot(pos)
        # ⚠️  THIS IS THE TANGLING: Requires plot.is_planted
        if not plot or not plot.is_planted:
            continue

        # Get the biome and place energy tap
        var biome = farm.grid.get_biome_for_plot(pos)
        if biome and biome.place_energy_tap(target_emoji, 0.05):
            success_count += 1
            print("  💧 Tap on %s placed at %s" % [target_emoji, pos])

    action_performed.emit("place_energy_tap", success_count > 0,
        "%s Placed %d energy taps targeting %s" % ["✅" if success_count > 0 else "❌", success_count, target_emoji])
```

**The Layer Mismatch**:
```
UI Layer (line 1388):
  "if not plot.is_planted: continue"
  Assumes: Taps are plot-level structures

Physics Layer (BiomeBase.place_energy_tap):
  Creates Lindblad drain on biome quantum_computer
  No plot-level structure created

Result:
  Handler skips empty plots
  Physics layer creates drain anyway
  UI never calls biome.place_energy_tap() for empty plots
  = Taps can't be placed
```

---

## Summary: The "Tangling"

### What's Tangled
1. **Legacy vs. New Biome System** (FarmGrid)
   - Old: Single `var biome`
   - New: `var biomes[String]`, `plot_biome_assignments[Vector2i]`
   - Both exist, code checks both

2. **UI Layer Assumptions vs. Physics Layer** (FarmInputHandler)
   - UI assumes: Taps need `plot.is_planted` (plot-level structures)
   - Physics: Taps operate on `biome.quantum_computer` (biome-level drains)
   - Gate check at UI layer blocks valid physics operations

3. **Register Mapping Redundancy** (FarmGrid)
   - `plot_register_mapping: Dictionary` - plots to register IDs
   - `plot_to_biome_quantum_computer: Dictionary` - plots to quantum computers
   - Both track the same relationship

### What's NOT Tangled
- ✅ Model B quantum_computer implementation (clean)
- ✅ BiomeBase physics (correct density matrix formalism)
- ✅ Measurement logic (proper purity-based probabilistic outcomes)
- ✅ Gate operations (CNOT, CZ, SWAP implemented correctly)

### Recommendations
1. **Remove redundant mappings**: Keep only plot_register_mapping (simpler)
2. **Fix layer boundary**: Remove `plot.is_planted` check from energy tap handler
3. **Clarify API contract**: Is energy_tap a plot-level or biome-level operation?
4. **Document Model B transition**: Mark legacy biome field as deprecated

---

## File Dependencies

```
FarmGrid.gd (orchestrator)
  ├─→ uses QuantumMill.gd (measurement)
  ├─→ uses BiomeBase.gd (quantum state owner)
  │   └─→ uses QuantumComputer.gd (density matrix engine)
  ├─→ uses FarmPlot.gd (plot metadata, parent_biome ref)
  └─→ used by FarmInputHandler.gd (game input)
       └─→ calls biome.place_energy_tap() (line 1393)
```

---

## Physics Correctness Assessment

| Component | Status | Evidence |
|-----------|--------|----------|
| Quantum registers | ✅ Correct | Model B allocation, proper indexing |
| Density matrix evolution | ✅ Correct | Lindblad master equation implemented |
| Measurement (mill) | ✅ Correct | Purity-based probabilistic outcomes |
| Unitary gates | ✅ Correct | CNOT, CZ, SWAP properly embedded |
| Energy drains | ✅ Correct | Lindblad drain operators L = √κ\|sink⟩⟨target\| |
| Multi-qubit entanglement | ✅ Correct | Component merging on gate application |
| **UI-Physics boundary** | ❌ Misaligned | plot.is_planted check blocks valid taps |

---

## Code Locations Summary

| Query | File | Lines | Status |
|-------|------|-------|--------|
| Plot storage | FarmGrid.gd | 40-41 | ✅ |
| Biome registry | FarmGrid.gd | 68-70 | ✅ |
| Register mapping | FarmGrid.gd | 72-74 | ⚠️ Redundant |
| Biome routing | FarmGrid.gd | ~860 | ✅ |
| Mill measurement | QuantumMill.gd | 52-130 | ✅ Physics correct, ⚠️ No outcome locking |
| Tap placement | FarmInputHandler.gd | 1368-1399 | ❌ Layer mismatch |
| Quantum computer | BiomeBase.gd | 32 | ✅ |
| Bath (legacy) | BiomeBase.gd | 38 | ⚠️ Deprecated |

---

## What This Means for Kitchen Pipeline

1. **Mill works but doesn't consume wheat**: Purity measurement correct, but wheat stays planted for re-measurement
2. **Taps can't place via keyboard**: UI gate blocks valid physics operation
3. **Kitchen quantum state creation works**: Bell state mechanics are correct, no issue there
4. **Cross-biome access undefined**: No mechanism for kitchen to query fire/water from different biomes

These are **architectural questions, not physics errors**. The physics is sound; the integration layer needs clarity.
