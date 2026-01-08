# Q3: Biome-Plot Relationship and Grid Structure

**Question**: Does each plot have a parent_biome reference? Are there multiple biome types that overlay the same grid, or are grid regions dedicated to specific biomes?

**Answer**: Each plot has a `parent_biome` reference. Multiple biome types CAN overlay the same grid, but currently default to BioticFlux.

---

## The Biome-Plot Bond

### Each Plot Owns a Parent Biome Reference

**File**: `Core/GameMechanics/BasePlot.gd`

```gdscript
class_name BasePlot extends Resource

var parent_biome: Node = null  # Reference to BiomeBase that owns quantum state (line 25)

func set_biome(biome: BiomeBase) -> void:
    """Assign this plot to a biome (Model B)"""
    parent_biome = biome
    print("  📍 Plot %s assigned to biome %s" % [plot_id, biome.get_biome_type()])
```

**This is the connection point:**
```
┌─────────────────┐          ┌──────────────────────┐
│ Plot (0, 0)     │          │ BiomeBase (BioticFlux)
│                 │          │                      │
│ parent_biome ───┼──────→───│ quantum_computer     │
│ register_id: 0  │          │                      │
│ is_planted: true│          │ components: [...]    │
└─────────────────┘          └──────────────────────┘
```

### Query Operations via Parent Biome

All quantum operations go through parent_biome:

```gdscript
# Get purity of wheat measurement
func get_purity() -> float:
    if not is_planted or not parent_biome:
        return 0.0

    var reg = parent_biome.get_register_for_plot(grid_position)
    var comp = parent_biome.quantum_computer.get_component_containing(register_id)
    if not comp:
        return 0.0

    return parent_biome.quantum_computer.get_marginal_purity(comp, register_id)

# Measure the plot
func measure() -> String:
    if not parent_biome or register_id < 0:
        return ""

    var comp = parent_biome.quantum_computer.get_component_containing(register_id)
    if not comp:
        return ""

    var outcome = parent_biome.quantum_computer.measure_register(comp, register_id)
    has_been_measured = true
    return outcome
```

---

## Grid Structure: Multiple Biome Types Overlaid

### How It Works

**File**: `Core/GameMechanics/FarmGrid.gd`

```gdscript
# Multi-biome registry (line 68-70)
var biomes: Dictionary = {}                    # String → BiomeBase (e.g., "BioticFlux", "Kitchen", "Forest", "Market")
var plot_biome_assignments: Dictionary = {}    # Vector2i → String (e.g., pos → "BioticFlux")
```

**Allocation Process**:

```
Step 1: Create plots (generic grid)
┌────────────────────────────────┐
│ Plot (0,0) │ Plot (1,0) │ ...  │
│ Plot (0,1) │ Plot (1,1) │ ...  │
└────────────────────────────────┘

Step 2: Register biomes
biomes["BioticFlux"] = BioticFluxBiome.new()
biomes["Kitchen"] = QuantumKitchen_Biome.new()
biomes["Forest"] = ForestEcosystem_Biome.new()
biomes["Market"] = MarketBiome.new()

Step 3: Assign plots to biomes (default to BioticFlux)
plot_biome_assignments = {
    Vector2i(0, 0): "BioticFlux",  # Wheat grows here
    Vector2i(1, 0): "BioticFlux",  # Mushroom grows here
    Vector2i(0, 1): "Kitchen",     # Kitchen placed here (own biome)
    Vector2i(2, 0): "Forest"       # Forest dynamics
}
```

### The Routing Function

**File**: `Core/GameMechanics/FarmGrid.gd` (~line 860)

```gdscript
func get_biome_for_plot(position: Vector2i):
    """Get the biome responsible for a specific plot"""

    # Check explicit assignment
    if plot_biome_assignments.has(position):
        var biome_name = plot_biome_assignments[position]
        if biomes.has(biome_name):
            return biomes[biome_name]

    # Fallback: Default to BioticFlux
    if biomes.has("BioticFlux"):
        return biomes["BioticFlux"]

    # Final fallback: Legacy single biome (for backward compatibility)
    return biome
```

**Fallback Chain**:
```
1. Is plot explicitly assigned?  → Use that biome
2. Does BioticFlux exist?        → Use BioticFlux (default)
3. Fallback to legacy biome      → For old code paths
```

---

## Current Grid Configuration

### The 6×2 Grid (Default)

**Dimensions**: 6 columns × 2 rows = 12 plots

**Default Assignment** (all to BioticFlux):
```
(0,0) BioticFlux
(1,0) BioticFlux
(2,0) BioticFlux
(3,0) BioticFlux (mill site)
(4,0) BioticFlux
(5,0) BioticFlux

(0,1) BioticFlux
(1,1) BioticFlux
(2,1) BioticFlux
(3,1) BioticFlux (kitchen site)
(4,1) BioticFlux
(5,1) BioticFlux
```

### Multi-Biome Scenario (Future)

You COULD assign:
```
BioticFlux region (top rows):
  (0,0)-(5,0): Wheat, mushroom farming

Kitchen region (middle):
  (0,1)-(2,1): Kitchen biome plots
  (3,1)-(5,1): Still BioticFlux but physically separated

Forest region (if expanded grid):
  (0,2)-(3,3): Forest biome (predators, water)

Market region:
  (4,2)-(5,3): Market biome (trading, flour)
```

**But this is OPTIONAL.** Currently, everything defaults to BioticFlux.

---

## How Kitchen Placement Works

### Kitchen is Treated as a Building, Not a Biome Assignment

**File**: `Core/GameMechanics/FarmGrid.gd` (~line 908)

```gdscript
func place_kitchen(position: Vector2i) -> bool:
    """Place kitchen building on 3 selected plots"""

    var plot = get_plot(position)
    if plot == null or plot.is_planted:
        return false

    # Mark as occupied (buildings are instantly "mature")
    plot.plot_type = FarmPlot.PlotType.KITCHEN
    plot.is_planted = true

    plot_planted.emit(position)

    print("🍳 Placed kitchen at plot_0_1")
    return true
```

**The Issue**:
```
Kitchen is placed on BioticFlux plots
But kitchen needs fire from Kitchen biome
And water from Forest biome

Currently:
- Kitchen building created as "structure" (plot_type = KITCHEN)
- No biome reassignment occurs
- Kitchen has NO access to Kitchen/Forest quantum computers

Should be:
- Option A: Reassign plot to "Kitchen" biome, enable local quantum evolution
- Option B: Create explicit cross-biome query mechanism
- Option C: Kitchen is a special "floating" entity, not plot-bound
```

---

## The Parent Biome Lifecycle

### When a Plot Gets a Biome

**Code Path**:

1. **Planting** (FarmGrid.plant_wheat):
```gdscript
func plant_wheat(position: Vector2i) -> bool:
    var plot = get_plot(position)

    # Allocate quantum register in PARENT BIOME
    var parent_biome = get_biome_for_plot(position)  # Get biome for plot
    var register_id = parent_biome.allocate_register("🌾", "👥")

    # Bind plot to biome
    plot.set_biome(parent_biome)
    plot.register_id = register_id
    plot.is_planted = true
    plot.plant_type = "wheat"
```

2. **Growing** (BasePlot.grow):
```gdscript
func grow(delta: float, biome: BiomeBase, ...):
    """Grow plot under biome evolution"""
    if not is_planted or not parent_biome:
        return

    # Ask biome: How much has my state evolved?
    var purity = get_purity()  # Uses parent_biome.quantum_computer
    # ... growth calculation using purity
```

3. **Measurement** (BasePlot.measure):
```gdscript
func measure() -> String:
    """Measure state via parent biome"""
    var outcome = parent_biome.quantum_computer.measure_register(...)
    has_been_measured = true
    return outcome
```

4. **Harvest** (FarmGrid.harvest_plot):
```gdscript
func harvest_plot(position: Vector2i):
    var plot = get_plot(position)
    var parent_biome = get_biome_for_plot(position)

    # Measure and remove from quantum computer
    var outcome = plot.measure()  # Uses parent_biome

    # Remove register from biome
    parent_biome.clear_register_for_plot(position)

    # Clear plot
    plot.is_planted = false
    plot.parent_biome = null
```

---

## The Confusing Case: Kitchen

### Kitchen in BioticFlux with Kitchen Biome References

**Current Reality**:
```
Kitchen building placed at (3,1) in BioticFlux grid
plot.parent_biome = BioticFlux  ✓
plot.plot_type = KITCHEN        ✓

But then:
kitchen_biome = farm.kitchen_biome  # Separate instance!
kitchen_biome.quantum_computer has fire, bread states

Kitchen building reads from:
  - BioticFlux.quantum_computer (for flour from mill)
  - Kitchen.quantum_computer (for... fire? Not implemented!)
  - Forest.quantum_computer (for... water? Not implemented!)
```

**The Mismatch**:
```
Question: Which biome does the kitchen belong to?

If Kitchen biome:
  - parent_biome = Kitchen
  - Has fire, bread states
  - No access to flour from BioticFlux mill

If BioticFlux biome:
  - parent_biome = BioticFlux
  - No fire state (not in BioticFlux)
  - Has flour from mill
  - Current implementation
```

**Answer needed**: Is kitchen plot-tied to a biome, or biome-independent?

---

## Summary: Biome-Plot Structure

| Aspect | Current | Designed For |
|--------|---------|-------------|
| Plot owns parent_biome | ✅ Yes | Single quantum state owner |
| Multiple biome types | ✅ Yes (registry) | Multi-region gameplay |
| Default biome | ✅ BioticFlux | Backward compatibility |
| Biome assignment | ✅ Optional | Dynamic region changes |
| Kitchen biome handling | ❌ Undefined | Cross-biome access |
| Energy tap biome binding | ⚠️ Plot-based gate, physics-based operation | Needs clarification |

**Physics Correctness**: ✅ Parent biome structure is sound
**Integration Clarity**: ⚠️ Kitchen and cross-biome access undefined

---

## Recommendation for Kitchen

Define explicitly:
1. **Is kitchen a plot-level structure or a biome-level operation?**
2. **If plot-level: Which biome should kitchen plot.parent_biome reference?**
3. **How does kitchen access fire/water from other biomes?**

These are architectural questions, not physics errors. The parent_biome system is correct; it just needs clear semantics for kitchen.
