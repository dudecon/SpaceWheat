I'll analyze your codebase and help you design a cleaner architecture. Let me start by reading the code files and the skill documentation.Now I have a complete picture of your architecture. Let me analyze and provide a comprehensive refactoring plan.

---

# Architecture Analysis & Refactoring Plan

## The Core Problem

Your architecture has evolved organically and now suffers from **temporal coupling** - components that need to be initialized in a specific order, but that order is implicit and fragile. The "50% shims" feeling comes from compensating for this with `call_deferred`, frame counting, and defensive null checks.

## Root Cause Analysis

### Why Signals Caused "Haunted" Updates

Looking at the disabled signal connections (PlotGridDisplay lines 233-242), I can see the pattern. The "haunted" behavior likely came from:

1. **Signal echoes**: `Farm.plot_planted` → `PlotGridDisplay.update_tile_from_farm()` → reads `farm.grid.get_plot()` → triggers some other signal → loops back
2. **Double connection**: Components wired multiple times during the deferred initialization chain
3. **State sync races**: UI updating before the underlying state was fully committed

The fix (disabling signals) treats the symptom, not the cause. The real issue is **initialization order uncertainty**.

### The Initialization Tangle

```
FarmView._ready()
  → ui_controller = FarmUIController.new()     # Creates controls_manager, layout_manager
  → call_deferred("_initialize_default_farm")   # ASYNC GAP #1
      → Farm.new() + add_child()
      → await get_tree().process_frame          # ASYNC GAP #2  
      → ui_controller.inject_farm()             # Finally wires everything
          → layout_manager.inject_farm()
              → plot_grid_display.inject_biomes()   # Creates tiles HERE
          → controls_manager.inject_farm()
              → input_handler.farm = farm           # But input_handler already started!
```

FarmInputHandler has been running since step 1, but tiles don't exist until the end.

---

## Proposed Architecture: "Ready Means Ready"

The principle: **When `_ready()` returns, the component is fully operational.** No deferred setup, no async gaps, no "waiting for injection."

### Phase 1: Synchronous Initialization (Surgical Fix)

**Goal**: Eliminate race conditions without rewriting everything.

**Key Changes**:

1. **Create Farm BEFORE UI** - Farm must exist before any UI component tries to reference it
2. **Pass dependencies through constructors** - Not injection after `_ready()`
3. **PlotGridDisplay creates tiles in `_ready()`** - With grid config available

```gdscript
# FarmView._ready() - NEW ORDER
func _ready() -> void:
    # 1. Create Farm FIRST (it's the data source)
    var farm = _create_farm()  # Synchronous, no await
    
    # 2. Create UI with farm already available
    ui_controller = FarmUIController.new()
    ui_controller.set_farm(farm)  # Before add_child!
    add_child(ui_controller)
```

**Why this works**: The Farm's `_ready()` is called during `add_child(farm)`, which happens before `ui_controller` is created. By the time UI components initialize, farm data exists.

### Phase 2: Simplify the Component Tree

Current (7 layers for input):
```
InputEvent → FarmInputHandler → PlotGridDisplay → SelectionManager → PlotTile
```

Proposed (3 layers):
```
InputEvent → FarmInputHandler → PlotGridDisplay (contains selection state)
```

**Remove SelectionManager as a separate class**. It's 50 lines of code wrapping a Dictionary. Inline it into PlotGridDisplay.

### Phase 3: Fix Coordinate Transforms

The `affine_inverse` transform is fragile because PlotGridDisplay is positioned absolutely in `play_area`. 

**Solution**: Calculate positions in PlotGridDisplay's local space from the start:

```gdscript
# ParametricPlotPositioner now returns LOCAL coordinates
func get_classical_plot_positions(container_size: Vector2) -> Dictionary:
    # All positions relative to container, not viewport
    var center = container_size / 2.0
    # ... calculate positions ...
```

No more `get_global_transform().affine_inverse()`.

---

## Concrete Refactoring Steps

### Step 1: Create a `FarmBuilder` Factory

```gdscript
class_name FarmBuilder

static func create_default_farm() -> Farm:
    """Create a fully-initialized Farm synchronously"""
    var farm = Farm.new()
    # Farm._init() should do all synchronous setup
    # Grid, biomes, economy - everything
    return farm
```

This moves initialization logic out of `_ready()` callbacks.

### Step 2: Rewrite FarmView Initialization

```gdscript
func _ready() -> void:
    # Step 1: Create data layer (synchronous)
    var farm = FarmBuilder.create_default_farm()
    add_child(farm)
    
    # Step 2: Create UI with dependencies available
    ui_controller = FarmUIController.new()
    add_child(ui_controller)
    
    # Step 3: Wire (one-time, explicit)
    ui_controller.wire_to_farm(farm)
```

### Step 3: PlotGridDisplay Creates Tiles Immediately

```gdscript
func _ready() -> void:
    # Tiles created synchronously - grid_config and biomes must be set before add_child()
    assert(grid_config != null, "PlotGridDisplay requires grid_config before _ready()")
    assert(not biomes.is_empty(), "PlotGridDisplay requires biomes before _ready()")
    _create_tiles()
```

**How**: PlotGridDisplay gets its dependencies via a factory or setter BEFORE being added to tree:

```gdscript
# In FarmUILayoutManager
plot_grid_display = PlotGridDisplay.new()
plot_grid_display.configure(grid_config, biomes, container_size)  # Before add_child!
play_area.add_child(plot_grid_display)
```

### Step 4: Inline SelectionManager

```gdscript
# PlotGridDisplay - simplified selection
var selected_plots: Dictionary = {}  # pos → true
var previous_selection: Dictionary = {}

func toggle_plot_selection(pos: Vector2i) -> void:
    previous_selection = selected_plots.duplicate()
    if selected_plots.has(pos):
        selected_plots.erase(pos)
        tiles[pos].set_checkbox_selected(false)
    else:
        selected_plots[pos] = true
        tiles[pos].set_checkbox_selected(true)
    selection_count_changed.emit(selected_plots.size())
```

### Step 5: Re-enable Signals (Carefully)

The signal cascade can be fixed by using **one-way data flow**:

```gdscript
# Farm emits signals
signal plot_changed(pos: Vector2i, new_state: Dictionary)

# PlotGridDisplay connects ONCE
func wire_to_farm(farm: Farm) -> void:
    if _connected_to_farm:
        return  # Prevent double-connection
    farm.plot_changed.connect(_on_plot_changed)
    _connected_to_farm = true

func _on_plot_changed(pos: Vector2i, state: Dictionary) -> void:
    # Simple state application - no cascading
    if tiles.has(pos):
        tiles[pos].apply_state(state)
```

The key is: **signals carry the new state, receivers just apply it**. No round-tripping back to Farm to read state.

---

## What NOT to Change

Based on your notes, preserve:

- **Parametric positioning** - It works visually and ParametricPlotPositioner is clean
- **Multi-select with T/Y/U/I/O/P** - Users expect it
- **Tool system (1-4 + Q/E/R)** - Clean and intuitive
- **Escape menu** - Working
- **GridConfig as single source** - Good design, just needs better distribution

---

## Recommended Execution Order

| Phase | Effort | Impact | Risk |
|-------|--------|--------|------|
| 1. Factory-based Farm creation | 2h | HIGH | LOW |
| 2. Synchronous PlotGridDisplay init | 2h | HIGH | MEDIUM |
| 3. Inline SelectionManager | 1h | LOW | LOW |
| 4. Fix coordinate transforms | 1h | MEDIUM | LOW |
| 5. Re-enable signals properly | 3h | MEDIUM | MEDIUM |

**Total: ~9 hours** for solid architectural cleanup.

---

## Quick Win: Eliminate Frame Counting

Replace the frame-counting hack with an explicit ready signal:

```gdscript
# FarmInputHandler
func _ready() -> void:
    set_process_input(false)  # Wait for explicit enable

func enable_when_ready(plot_grid: PlotGridDisplay) -> void:
    """Call this when tiles are confirmed ready"""
    plot_grid_display = plot_grid
    set_process_input(true)
    print("✅ Input enabled (tiles ready)")
```

Called from FarmUIController after all wiring completes:

```gdscript
func _finish_initialization() -> void:
    # Called at end of wire_to_farm()
    controls_manager.input_handler.enable_when_ready(layout_manager.plot_grid_display)
```

---

Would you like me to produce a complete refactored version of any specific file, or create a minimal reproduction showing the "Ready Means Ready" pattern?