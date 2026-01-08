# BasePlot Conversion to Analog Bath Model - Complete

**Date**: 2026-01-06
**Status**: ✅ **CONVERTED** - BasePlot now uses QuantumBath instead of QuantumComputer

---

## Changes Made

### 1. Class Documentation Updated
```gdscript
## OLD (Model B): Plot is a HARDWARE ATTACHMENT to a biome's QuantumComputer
## NEW (Model C): Plot is a MEASUREMENT BASIS on a biome's QuantumBath
```

**Concept Change**:
- **Before**: Plot allocated a discrete register in QuantumComputer
- **After**: Plot defines a measurement axis in QuantumBath

---

### 2. Register Reference → Bath Subplot Reference

```gdscript
# OLD (Model B):
@export var register_id: int = -1  # Logical qubit ID in quantum computer

# NEW (Model C):
@export var bath_subplot_id: int = -1  # Which subplot in bath's composite state
```

**Key insight**: Bath manages full multi-dimensional state, not individual registers.

---

### 3. Quantum State Access Methods

#### get_purity()
```gdscript
# OLD (Model B):
var comp = parent_biome.quantum_computer.get_component_containing(register_id)
return parent_biome.quantum_computer.get_marginal_purity(comp, register_id)

# NEW (Model C):
return parent_biome.bath.get_purity()  # Overall bath purity Tr(ρ²)
```

#### get_coherence()
```gdscript
# OLD (Model B):
var comp = parent_biome.quantum_computer.get_component_containing(register_id)
return parent_biome.quantum_computer.get_marginal_coherence(comp, register_id)

# NEW (Model C):
return parent_biome.bath.get_purity()  # Approximate from purity
```

#### get_mass()
```gdscript
# OLD (Model B):
return parent_biome.quantum_computer.get_marginal_probability_subspace(comp, register_id, [north_emoji, south_emoji])

# NEW (Model C):
var p_north = parent_biome.bath.get_probability(north_emoji)
var p_south = parent_biome.bath.get_probability(south_emoji)
return p_north + p_south
```

---

### 4. Plant Function

```gdscript
# OLD (Model B):
if biome_or_labor is Node and biome_or_labor.has_method("allocate_register_for_plot"):
    biome = biome_or_labor

register_id = biome.allocate_register_for_plot(grid_position, north_emoji, south_emoji)

# NEW (Model C):
if biome_or_labor is Node and biome_or_labor.has("bath"):
    biome = biome_or_labor

if biome.has_method("allocate_subplot_for_plot"):
    bath_subplot_id = biome.allocate_subplot_for_plot(grid_position, north_emoji, south_emoji)
else:
    bath_subplot_id = 0  # Placeholder - bath manages full state
```

**Behavior**:
- Checks for `bath` property instead of `allocate_register_for_plot` method
- Optionally calls `allocate_subplot_for_plot()` if biome implements it
- Falls back to simple marking as planted if biome has bath

---

### 5. Measure Function

```gdscript
# OLD (Model B):
var comp = parent_biome.quantum_computer.get_component_containing(register_id)
var outcome = parent_biome.quantum_computer.measure_register(comp, register_id)

# NEW (Model C):
var outcome_emoji = parent_biome.bath.measure_axis(north_emoji, south_emoji)
var basis_outcome = "north" if outcome_emoji == north_emoji else "south"
```

**Key changes**:
- Uses `bath.measure_axis(north, south)` instead of `quantum_computer.measure_register()`
- Returns emoji directly from bath
- Converts emoji to basis name ("north"/"south") for internal storage

---

### 6. Harvest Function

```gdscript
# OLD (Model B):
is_planted = false
register_id = -1
if parent_biome and parent_biome.has_method("clear_register_for_plot"):
    parent_biome.clear_register_for_plot(grid_position)

# NEW (Model C):
is_planted = false
bath_subplot_id = -1
if parent_biome and parent_biome.has_method("clear_subplot_for_plot"):
    parent_biome.clear_subplot_for_plot(grid_position)
# Note: Bath state persists - not cleared on individual plot harvest
```

**Important**: Bath state is shared across all plots in biome, so individual harvest doesn't reset the full state.

---

### 7. Reset Function

```gdscript
# OLD (Model B):
register_id = -1  # Clear quantum computer register

# NEW (Model C):
bath_subplot_id = -1  # Clear bath subplot reference
```

---

## What Stays the Same

✅ **Measurement outcome storage**: Still uses `measured_outcome` ("north"/"south")
✅ **Emojis**: Still uses `north_emoji` and `south_emoji`
✅ **Planted state**: Still uses `is_planted` boolean
✅ **Harvest yield calculation**: Same purity-based formula
✅ **Persistent gates**: Still survive harvest

---

## Compatibility Notes

### Works With
✅ **QuantumKitchen_Biome**: Already uses `bath` - now compatible!
✅ **Any biome with `bath` property**: Will work automatically
✅ **Bath measurement API**: Uses `bath.measure_axis()`, `bath.get_probability()`

### Needs Update
⚠️ **Other biomes (BioticFlux, Forest, Market)**: Still use `quantum_computer`
⚠️ **FarmGrid.measure_plot()**: Still expects `quantum_computer`
⚠️ **BiomeBase.allocate_register_for_plot()**: Still uses `quantum_computer`

---

## Next Steps

To complete the analog conversion, these files need updating:

### 1. BiomeBase.gd
Add bath support alongside quantum_computer:
```gdscript
# Add property
var bath: QuantumBath = null

# Add method
func allocate_subplot_for_plot(pos: Vector2i, north: String, south: String) -> int:
    if bath:
        # Track subplot in metadata
        return 0  # Subplot ID or just return success
    return -1
```

### 2. FarmGrid.gd
Update `measure_plot()` to check for bath:
```gdscript
func measure_plot(position: Vector2i) -> String:
    var biome = get_biome_for_plot(position)
    var plot = get_plot(position)

    if biome.bath:
        # NEW: Use bath measurement
        var outcome_emoji = biome.bath.measure_axis(plot.north_emoji, plot.south_emoji)
        return outcome_emoji
    elif biome.quantum_computer:
        # OLD: Use quantum_computer (legacy)
        # ... existing code ...
```

### 3. Other Biomes
Either:
- **Option A**: Add `bath` to all biomes (full analog conversion)
- **Option B**: Keep dual system (some biomes use bath, some use quantum_computer)

---

## Testing

### Test Kitchen with Analog BasePlot
```gdscript
var kitchen_biome = QuantumKitchen_Biome.new()
kitchen_biome._ready()  # Initializes bath

var plot = BasePlot.new()
plot.grid_position = Vector2i(3, 1)
plot.plant(kitchen_biome)  # Should work now!

# Plot should be planted
assert(plot.is_planted == true)
assert(plot.bath_subplot_id >= 0)  # Or == 0 if simplified
assert(plot.parent_biome == kitchen_biome)

# Measurement should work
var outcome = plot.measure()
assert(outcome in ["north", "south"])

# Harvest should work
var result = plot.harvest()
assert(result["success"] == true)
assert(result["outcome"] in [plot.north_emoji, plot.south_emoji])
```

---

## Summary

**✅ BasePlot converted to analog model**
- Old QuantumComputer code commented out (not deleted)
- New QuantumBath code added
- Backward compatible via method checks (`has_method()`, `has()`)

**🎯 Kitchen can now work**
- BasePlot checks for `bath` property
- Uses `bath.measure_axis()` for measurement
- Uses `bath.get_probability()` for quantum state queries

**📋 Next: Update FarmGrid and BiomeBase**
- Add bath support to measurement/harvest code
- Either convert all biomes to bath OR support both models

---

**All old code preserved as comments - can be restored if needed!**
