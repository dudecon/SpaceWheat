# Refactoring Questions for Review

## High-Level Architecture Questions

### 1. **Should we eliminate parametric positioning entirely?**
- Current approach: ParametricPlotPositioner calculates oval ring positions
- Requires coordinate transforms: screen space → PlotGridDisplay local space
- Adds complexity but enables "organic" biome-based positioning
- Question: Is the visual benefit worth the complexity cost?

### 2. **What's the right initialization order?**
Currently:
```
FarmView._ready()
  → FarmUIController._ready()
    → FarmUILayoutManager._ready() [creates UI, tiles deferred]
    → FarmInputHandler._ready() [defers input processing]
  → Farm is created via call_deferred()
    → Farm._ready() creates grid_config
    → FarmUIController.inject_farm() extracted grid_config
    → PlotGridDisplay.inject_biomes() creates tiles
    → FarmInputHandler finally enables input
```

Simpler approach: Create everything in order before any _ready() completes?

### 3. **Should we use Signals or Direct State Reading?**
**Current approach**: No signals between Farm and UI (to avoid "haunted" updates)

**Question**:
- Why was signal cascade causing "haunted" behavior?
- Was the problem the signals, or the connections being made wrong?
- Could we fix it with proper signal filtering instead of disabling signals?

### 4. **Do we need ParametricPlotPositioner as separate class?**
Current:
```
PlotGridDisplay ← calls → ParametricPlotPositioner
```

Could instead:
```
PlotGridDisplay._calculate_positions_internal()
```

Is the separation useful, or does it just add a layer?

---

## Specific Architectural Issues

### 5. **Coordinate Transforms are Ugly**
```gdscript
var local_pos = get_global_transform().affine_inverse() * screen_pos
tile.position = local_pos - tile.custom_minimum_size / 2
```

This is doing:
- Get PlotGridDisplay's global position/rotation/scale
- Inverse it (to go from global → local)
- Apply to screen position
- Center the tile

**Question**: Why not use MarginContainer or CenterContainer instead?

### 6. **SelectionManager - Necessary Abstraction or Extra Layer?**
PlotGridDisplay creates a SelectionManager to track multi-select state.

**Question**: Could this just be a Dictionary in PlotGridDisplay directly?

### 7. **GridConfig - Single Source of Truth, But Injected Everywhere**
GridConfig is created in Farm, but needs to be injected into:
- FarmUILayoutManager
- FarmUIControlsManager
- FarmInputHandler
- PlotGridDisplay

**Question**: Should GridConfig be a singleton/autoload instead?

---

## Implementation Questions

### 8. **How Should Input → Action Flow Work?**

Current (complex):
```
Input event → InputController → FarmInputHandler._input()
  → _toggle_plot_selection(pos)
  → PlotGridDisplay.toggle_plot_selection(pos)
  → SelectionManager.toggle_plot(pos)
  → PlotTile visual update
```

Simpler option:
```
Input event → PlotTile directly detects which tile was clicked
  → PlotTile signals selection changed
  → ActionPreviewRow updates buttons
```

Would direct tile selection be better than routing through handler?

### 9. **Pause State on Escape Menu**
Currently escape menu doesn't pause simulation.

**Question**: Where should pause logic live?
- In Farm?
- In OverlayManager?
- In FarmUIController?
- In separate GameStateManager?

### 10. **Test Mode - Too Many Async Steps**
FarmView has complex async initialization for default farm creation.

**Question**: Can we simplify this by:
- Pre-creating a default scene?
- Using a Factory instead of deferred creation?

---

## Code Quality Questions

### 11. **Error Handling - Too Defensive?**
Every method checks:
```gdscript
if not ui_controller:
if not controls_manager:
if not layout_manager:
if not plot_grid_display:
```

**Question**: Should we use assertions/assumes instead? Or accept that wiring might fail?

### 12. **Logging - Too Verbose or Just Right?**
Every component prints status messages. During a boot, hundreds of print statements.

**Question**: Should we:
- Filter by verbosity level?
- Remove non-error logs?
- Use logger class instead?

---

## Refactoring Scope

### What's the minimum viable simplification?

Option A: **Surgical Fixes** (~1-2 hours)
- Fix coordinate transform ugliness
- Simplify frame-counting hack
- Clean up error handling

Option B: **Moderate Refactor** (~4-8 hours)
- Remove ParametricPlotPositioner, use simple grid
- Eliminate SelectionManager, use Dictionary
- Streamline initialization order
- Re-enable signals with proper filtering

Option C: **Architecture Rewrite** (~16+ hours)
- New initialization system (dependency injection framework?)
- Simplified input routing
- Proper state management (separate from UI)
- Scene composition instead of programmatic layout

### What's causing the most pain right now?
1. Race conditions and frame counting
2. Coordinate transforms
3. Too many injection points
4. Deferred initialization

### What should we NOT change?
- Parametric positioning (it's working visually)
- Multi-select checkbox system (it's intuitive)
- Escape menu system (it's working)
- Tool system (straightforward and clean)

---

## Review Priorities

Please analyze in this order:

1. **Initialization Order** (CRITICAL) - This causes most timing issues
2. **Signal Architecture** (HIGH) - Affects how components communicate
3. **Coordinate Transforms** (MEDIUM) - Code smell but not breaking
4. **Dependency Injection** (MEDIUM) - Too many manual wiring points
5. **Layer Count** (LOW) - Works but feels excessive

---

## Context

- Game: Quantum wheat farming simulator (Godot 4.5)
- Current status: All features working but architecture feels like "50% shims"
- Team: Just one developer (me) trying to keep complexity manageable
- Goal: Make code maintainable enough for next feature additions without rewriting every time

What would a fresh perspective suggest?
