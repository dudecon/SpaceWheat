# Plant vs Explore Actions - Tangling Map

**Date:** 2026-01-17
**Status:** Identified tangling points
**Impact:** Semantic confusion in signals, visualization triggers, and game logic

---

## Quick Summary

**EXPLORE** (Quantum Discovery - PLAY MODE):
- Binds a terminal to a quantum register
- No crops are created
- No biome expansion
- Returns emoji pair as quantum basis labels

**PLANT** (Crop Expansion - BUILD MODE):
- Creates physical crops in the biome
- Expands biome's quantum structure
- Costs resources
- Updates plot visual state

**THE PROBLEM:**
These two fundamentally different actions share the same signal (`plot_planted`), causing visualization and game logic to conflate them.

---

## Tangling Point #1: EXPLORE Emits "PLANTED" Signal

**Location:** `UI/FarmInputHandler.gd` - Line 1432

```gdscript
func _action_explore():
    # ... code ...
    if result.success:
        var terminal = result.terminal
        var emoji = result.emoji_pair.get("north", "?")

        # ❌ TANGLING: EXPLORE action emits "planted" signal
        # This signal is semantically for PLANT, not EXPLORE
        farm.plot_planted.emit(plot_pos, emoji)  # Line 1432
```

**Problem:**
- `farm.plot_planted` signal defined in `Core/Farm.gd` line 83
- Semantically means "a crop was planted here"
- But EXPLORE doesn't plant anything - it binds a terminal to existing quantum structure
- This causes the visualization layer to treat EXPLORE as if it were PLANT

**Impact:**
- Visualization code receives wrong semantic meaning
- Comments in BathQuantumVisualizationController say "planted" but actually means "explored"
- Future developers will be confused about what "planted" means

---

## Tangling Point #2: Signal Definition Ambiguity

**Location:** `Core/Farm.gd` - Line 83

```gdscript
signal plot_planted(position: Vector2i, plant_type: String)
```

**Location:** `Core/GameMechanics/FarmGrid.gd` - Line 12

```gdscript
signal plot_planted(position: Vector2i)
```

**Problem:**
- Two different signal definitions with same name
- Different parameters (Farm version has plant_type, FarmGrid doesn't)
- Both used for different purposes:
  - FarmGrid.plot_planted: Actual crop planting in grid
  - Farm.plot_planted: Used as proxy trigger for visualization (actually from EXPLORE)

**Impact:**
- Inconsistent signal contract
- Visualization code can't reliably know what "planted" means
- Emission site (EXPLORE in FarmInputHandler) doesn't match definition intent

---

## Tangling Point #3: Visualization Connects to Wrong Signal

**Location:** `Core/Visualization/BathQuantumVisualizationController.gd` - Lines 129-170

```gdscript
# Connect to farm signals to auto-request bubbles when plots are planted
# NOTE: "planted" here actually means EXPLORED (NOT physically planted!)
if farm.has_signal("plot_planted"):
    farm.plot_planted.connect(func(pos, plant_type):
        print("🔔 BathQuantumViz: Received plot_planted signal for %s at %s" % [plant_type, pos])

        # Create bubble visualization
        _request_bubble_for_position(pos, plant_type)
```

**Problem:**
- Comment says "when plots are planted"
- Actually receives signal from EXPLORE action
- plant_type parameter receives emoji from terminal binding, not actual plant type
- Visualization logic conflates two different operations

**Expected:**
- Should connect to `terminal_bound` or `plot_explored` signal
- Should receive emoji_pair data, not plant_type
- Should understand it's visualizing quantum discovery, not crop growth

---

## Tangling Point #4: ToolConfig Actions Are Separate (CORRECT)

**Location:** `Core/GameState/ToolConfig.gd` - Lines 27-137

```gdscript
# ✅ CORRECT: v2 has only EXPLORE in PLAY_TOOLS
var PLAY_TOOLS: Array[Dictionary] = [
    # Tool 1: PROBE
    {
        "name": "PROBE",
        "actions": [
            {"action": "explore", ...},  # Line 34
            {"action": "measure", ...},
            {"action": "pop", ...},
        ]
    },
    # Tools 2, 3, 4 ...
]

# ✅ CORRECT: BUILD_TOOLS don't have PLANT action
var BUILD_TOOLS: Array[Dictionary] = [
    # Tool 1: BIOME
    # Tool 2: ICON
    # Tool 3: LINDBLAD
    # Tool 4: QUANTUM
    # No "plant" action defined
]
```

**Status:** ✅ This is correct - actions are properly separated in v2

---

## Tangling Point #5: Legacy PLANT Action Still Present

**Location:** `UI/FarmInputHandler.gd` - Line 800-801

```gdscript
# Legacy v1 planting system (still accessible)
"plant_batch" → _action_plant_batch(selected_plots)  # Line 800

func _action_plant_batch(positions: Array[Vector2i]):
    # Lines 1593-1644
    # Legacy implementation - detects biome and calls _action_batch_plant()
```

**Location:** `UI/FarmInputHandler.gd` - Lines 977-1049

```gdscript
func _action_batch_plant(plant_type: String, positions: Array[Vector2i]):
    # Calls farm.build(pos, plant_type) for each plot
    # Properly handles resource costs
    # Updates plot state
```

**Problem:**
- These legacy methods still exist but aren't in v2 ToolConfig
- Could be triggered if someone references "plant_batch" action
- Will cause confusion about which planting system is active
- No corresponding signal emission for actual planting (that happens in farm.build() → FarmGrid.place_*())

**Status:** ⚠️ Legacy code that should be removed or clarified

---

## Tangling Point #6: Actual Planting Signal Not Emitted

**Location:** `Core/GameMechanics/FarmGrid.gd` - Line 964+

```gdscript
func place_mill(position: Vector2i) -> bool:
    # ... creates and initializes mill ...
    add_child(mill)

    # ❌ NO SIGNAL EMITTED
    # Should emit something like plot_planted or plot_structure_built
    # But FarmGrid.place_*() methods don't emit any signals
```

**Location:** `Core/Farm.gd` - build() method

```gdscript
func build(position: Vector2i, building_type: String) -> bool:
    # Calls FarmGrid.place_*() methods
    # ❌ NO SIGNAL EMITTED after building
    # Should emit plot_planted when actual building succeeds
```

**Problem:**
- When you actually PLANT something (via build/place_*), no signal fires
- Only EXPLORE (which doesn't plant) emits "plot_planted"
- Signal flow is backwards

**Status:** ❌ Actual planting doesn't signal, exploration signals incorrectly

---

## The Signal Flow Diagram

### Current (TANGLED):
```
EXPLORE action (_action_explore)
    ↓
ProbeActions.action_explore() [binds terminal to register]
    ↓
emit farm.plot_planted (WRONG - this means planting, not exploring)
    ↓
BathQuantumVisualizationController receives "planted" signal
    ↓
Creates bubble visualization
```

### Expected (UNTANGLED):
```
EXPLORE action (_action_explore)
    ↓
ProbeActions.action_explore() [binds terminal to register]
    ↓
emit farm.terminal_bound or farm.plot_explored (CORRECT semantic)
    ↓
BathQuantumVisualizationController receives "explored" signal
    ↓
Creates bubble visualization for terminal binding

PLANT action (_action_batch_plant or via build)
    ↓
farm.build() → FarmGrid.place_*()
    ↓
emit farm.plot_planted (CORRECT semantic)
    ↓
Game logic updates crop production chains, etc.
```

---

## Complete Tangling Map

| Tangling Point | File | Line(s) | Issue | Severity |
|---|---|---|---|---|
| 1 | FarmInputHandler.gd | 1432 | EXPLORE emits `plot_planted` signal | 🔴 HIGH |
| 2 | Farm.gd, FarmGrid.gd | 83, 12 | Two inconsistent signal definitions | 🟡 MEDIUM |
| 3 | BathQuantumVisualizationController.gd | 129-170 | Connects to wrong signal with confusing comments | 🔴 HIGH |
| 4 | FarmInputHandler.gd | 800-801, 1593-1644, 977-1049 | Legacy PLANT methods still present | 🟡 MEDIUM |
| 5 | FarmGrid.gd, Farm.gd | 964+, build() | Actual planting doesn't emit signals | 🔴 HIGH |
| 6 | ToolConfig.gd | 27-137 | ✅ Actions properly separated (CORRECT) | 🟢 LOW |

---

## Files to Modify for Untangling

### Priority 1: Signal Refactoring
1. **Core/Farm.gd** - Define separate signals:
   - `terminal_bound(position, emoji_pair)` - for EXPLORE
   - `plot_planted(position, building_type)` - for PLANT

2. **UI/FarmInputHandler.gd** - Line 1432:
   - Change from `farm.plot_planted.emit(plot_pos, emoji)`
   - To `farm.terminal_bound.emit(plot_pos, terminal.get_emoji_pair())`

3. **Core/GameMechanics/FarmGrid.gd**:
   - Remove ambiguous `signal plot_planted(position: Vector2i)`
   - Add to place_mill/place_market/place_kitchen: emit farm.plot_planted()

4. **Core/Visualization/BathQuantumVisualizationController.gd**:
   - Disconnect from `plot_planted`
   - Connect to `terminal_bound`
   - Update parameter handling

### Priority 2: Legacy Cleanup
1. **UI/FarmInputHandler.gd** - Lines 800-801, 977-1049, 1593-1644:
   - Remove legacy `_action_plant_batch()` if not used in v2
   - Or clearly mark as deprecated
   - Or update to use new signal semantics

---

## Untangling Verification Checklist

- [ ] New signal `terminal_bound` created in Core/Farm.gd
- [ ] New signal `plot_planted` distinct from terminal_bound in Core/Farm.gd
- [ ] FarmInputHandler._action_explore() emits terminal_bound (not plot_planted)
- [ ] FarmGrid.place_*() methods emit plot_planted
- [ ] Farm.build() method verifies plot_planted is emitted
- [ ] BathQuantumVisualizationController connects to terminal_bound
- [ ] BathQuantumVisualizationController comments updated
- [ ] Legacy PLANT methods removed or deprecated
- [ ] Test: EXPLORE visualization works with new signal
- [ ] Test: PLANT visualization works with new signal
- [ ] Test: No conflicts between signals

---

## Summary

**Current State:** Actions are separate but signals are tangled
**Root Cause:** v1→v2 migration used `plot_planted` as proxy for "bubble visualization trigger" without introducing proper signal names
**Impact:** Semantic confusion, wrong signal flowing to visualization layer, future maintenance risk
**Solution:** Introduce `terminal_bound` signal for EXPLORE, keep `plot_planted` for PLANT
**Effort:** ~2-3 hours (4 files, 10 locations)
