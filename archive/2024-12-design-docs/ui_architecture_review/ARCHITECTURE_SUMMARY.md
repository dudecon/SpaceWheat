# UI Architecture Review - Summary

## Current Architecture Overview

```
FarmView (entry point)
  └─ FarmUIController (orchestrator)
       ├─ FarmUILayoutManager (layout)
       │   ├─ PlotGridDisplay (plot tiles - parametric positioning)
       │   ├─ QuantumForceGraph (visualization)
       │   └─ OverlayManager (menus/overlays)
       └─ FarmUIControlsManager (input coordination)
           ├─ InputController (key detection)
           └─ FarmInputHandler (action execution)
```

## Key Files & Responsibility

| File | Lines | Purpose | Status |
|------|-------|---------|--------|
| FarmUIController.gd | 538 | Orchestrates all UI subsystems, injects dependencies | Functional but complex |
| FarmUILayoutManager.gd | 350+ | Creates and positions UI elements | Working but deferring tile creation |
| FarmInputHandler.gd | 775+ | Handles keyboard input, executes actions | Just fixed - race condition |
| PlotGridDisplay.gd | 400+ | Manages plot tiles, parametric positioning | Working but coordinate transforms ugly |
| ParametricPlotPositioner.gd | ~100 | Calculates oval ring positions around biomes | New, adds complexity |
| FarmUIControlsManager.gd | 200+ | Routes input signals to handlers | Working |
| FarmView.gd | 288 | Top-level scene, creates default farm | Working but deferred initialization |

## The Tangle - Core Problems

### 1. **Deferred Initialization Chain**
Currently: `FarmView._ready()` → `call_deferred()` → `_initialize_default_farm()` → Farm creation → UI injection

**Problem**: Multiple async initialization steps hide dependencies. When does each component become ready?
- Farm._ready() creates grid_config
- FarmView._initialize_default_farm() waits 1 frame
- FarmUIController.inject_farm() extracts grid_config
- FarmInputHandler needs to wait until tiles exist

**Result**: Frame counting, call_deferred hacks, race conditions

### 2. **Biome Injection Happens Too Late**
Sequence:
1. PlotGridDisplay._ready() → prints "tiles will be created once biomes are injected"
2. FarmView initializes farm
3. FarmUILayoutManager.inject_farm() → PlotGridDisplay.inject_biomes()
4. PlotGridDisplay._create_tiles() finally creates tiles
5. Meanwhile, FarmInputHandler tries to process input but tiles don't exist yet

### 3. **Parametric Positioning Adds Layers**
New system added: ParametricPlotPositioner → calculates positions → PlotGridDisplay uses them

**Problems**:
- Coordinate transforms: screen → local PlotGridDisplay coords (ugly affine_inverse code)
- Tiles positioned absolutely, not grid-aligned
- Position recalculation happens each time biomes inject
- Another dependency: "FarmUIController → PlotGridDisplay → ParametricPlotPositioner"

### 4. **Signal Cascade = "Haunted" Behavior**
PlotGridDisplay intentionally **disconnects** farm signals because:
- Before: Plot tile visual updates triggered by farm signals
- Problem: Visualization updated multiple times (haunted)
- "Solution": Don't use signals, read state directly

**But this creates brittleness**: Manual state reading instead of reactive updates

### 5. **Too Many Layers of Indirection**
User selects plot T:
1. InputMap detects key press
2. FarmInputHandler._input() routes to _toggle_plot_selection()
3. Calls PlotGridDisplay.toggle_plot_selection()
4. PlotGridDisplay calls SelectionManager.toggle_plot()
5. PlotTile visual updates

Each layer adds:
- Null checks
- Wiring/injection code
- Error messages
- Coordinate transforms

### 6. **GridConfig Complexity**
GridConfig is single source of truth but:
- Created in Farm._ready()
- Extracted in FarmUIController.inject_farm()
- Injected into FarmUILayoutManager AND FarmUIControlsManager AND FarmInputHandler
- Multiple validation/checking methods: is_position_valid(), has_active_plot_at(), get_all_active_plots()

## Recent Fixes (This Session)

1. **GridConfig Injection** - Fixed farm.grid_config not being passed to components
2. **Input Race Condition** - Deferred FarmInputHandler input processing until tiles created
3. **Overlay Signal Connections** - Restored ESC/V/C/N/K/Q/R menu key handlers

## What Works
- ✅ Parametric plot positioning renders correctly
- ✅ All 10 plot tiles created and positioned
- ✅ Keyboard input routes correctly (T/Y/U/I/O/P/0/9/8/7)
- ✅ Escape menu can toggle
- ✅ Multi-select works

## What's Fragile
- ❌ Timing dependencies everywhere
- ❌ Frame counting hacks
- ❌ Coordinate transforms (screen ↔ local)
- ❌ Manual state reading instead of signals
- ❌ Too many call_deferred() calls
- ❌ Deep dependency injection chains

## Architectural Debt

Lines that are "shims" (workarounds):
- `call_deferred("_enable_input_processing")` - waiting for async init
- `await get_tree().process_frame` - waiting for ready()
- `get_global_transform().affine_inverse() * screen_pos` - coordinate ugliness
- `set_process_input(false)` then `set_process(true)` for frame counting - race condition workaround
- Multiple `has_method()` checks - defensive programming against missing wiring
- `grid_config = null` initialization then later checking `if grid_config:` - null checks everywhere

## What Should Be Simpler

1. **Single initialization order** - No async, no deferring
2. **Tiles created early** - Not deferred to biome injection
3. **Parametric = Optional** - Works with or without parametric positioning
4. **Signals everywhere** - Not manual state reading
5. **Fewer layers** - Input → Action, not Input → Handler → Manager → Display → Tile
6. **No coordinate transforms** - Use native Godot layout system

## Questions for Review

See REFACTORING_QUESTIONS.md
