# Issues and Symptoms Manifest

## Critical Issues (Block Forward Progress)

### 1. Race Conditions on Boot
**Symptom**: Input events processed before plot tiles created
**Occurs**: During FarmView initialization
**Manifests as**: "Invalid plot position" errors when keyboard input arrives too early
**Root cause**: FarmInputHandler processes input immediately in _ready(), but PlotGridDisplay defers tile creation until biomes injected

**Current workaround**:
```gdscript
set_process_input(false)
call_deferred("_enable_input_processing")  # Wait 1 frame
_process() {
  input_enable_frame_count -= 1
  if input_enable_frame_count <= 0:
    set_process_input(true)
}
```

**Problem with workaround**: Fragile, arbitrary frame count, doesn't actually check if tiles exist

---

### 2. Coordinate System Mismatch
**Symptom**: Parametric positions calculated in screen space, but tiles positioned in PlotGridDisplay local space

**Code**:
```gdscript
var local_pos = get_global_transform().affine_inverse() * screen_pos
tile.position = local_pos - tile.custom_minimum_size / 2
```

**Problem**:
- Non-obvious what's happening
- Breaks if PlotGridDisplay is rotated or scaled
- Different code path needed for grid vs parametric
- Hard to debug positioning issues

---

### 3. Biome Injection Timing
**Symptom**: Multiple systems depend on biomes being injected, but it happens late

**Sequence**:
1. PlotGridDisplay._ready() says "waiting for biomes"
2. Farm created (async via call_deferred)
3. Farm's biomes now available
4. FarmUIController extracts and injects biomes
5. PlotGridDisplay._create_tiles() finally called

**Problem**: Any system trying to use biomes before step 4 will fail

---

### 4. Signal Cascade Causes "Haunted" Updates
**Symptom**: When plot changes, visualization updates multiple times

**Original design**:
- Farm emits `plot_planted` signal
- PlotGridDisplay listens and updates tile

**Problem**: Signal fires, updates cascade, feedback loops, visualization "haunted"

**Current workaround**:
```gdscript
# DISABLED: Farm simulation signals
# Signal cascade disabled - using direct state reading instead
```

**Problem with workaround**: Manual state reading means no reactive updates, have to call `update_tile_from_farm()` manually

---

## High-Priority Issues (Cause Pain)

### 5. Too Many Injection Points
Every component requires injection:
```
FarmUIController.inject_farm()
FarmUILayoutManager.inject_farm()
FarmUIControlsManager.inject_farm()
FarmInputHandler.inject_farm()
PlotGridDisplay.inject_farm()
PlotGridDisplay.inject_biomes()
PlotGridDisplay.inject_ui_state()
```

Plus wiring multi-select components:
```
controls_manager.set_plot_grid_display(plot_grid_display)
input_handler.plot_grid_display = plot_grid_display
```

**Problem**: Fragile, easy to miss a wiring step, hard to trace dependencies

---

### 6. Deferred Initialization Everywhere
```gdscript
# In FarmView
call_deferred("_initialize_default_farm")

# In FarmInputHandler
call_deferred("_enable_input_processing")

# Various places
await get_tree().process_frame

# PlotGridDisplay
# DEFER tile creation until after biomes are injected
print("⏳ PlotGridDisplay ready (tiles will be created once biomes are injected)")
```

**Problem**: Makes it hard to understand boot sequence, creates timing bugs

---

### 7. Defensive Null Checks Everywhere
```gdscript
if not plot_grid_display:
    print("ERROR: PlotGridDisplay not wired!")
    return

if not layout_manager:
    print("ERROR: layout_manager missing!")
    return

if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
    selected_plots = plot_grid_display.get_selected_plots()
```

**Problem**: Sign that dependencies aren't being managed well

---

### 8. Frame Counting Hacks
```gdscript
var input_enable_frame_count: int = 0

func _enable_input_processing() -> void:
    set_process(true)
    input_enable_frame_count = 10

func _process(_delta: float) -> void:
    if not get_tree().root.is_input_handled():
        input_enable_frame_count -= 1
        if input_enable_frame_count <= 0:
            set_process(false)
            set_process_input(true)
```

**Problem**: Arbitrary magic number (10 frames), doesn't actually verify state

---

## Medium-Priority Issues (Maintenance)

### 9. ParametricPlotPositioner Adds Complexity
**New class**: 116 lines of code
**Purpose**: Calculate oval ring positions around biome centers

**Problems**:
- Requires coordinate transforms
- Adds another layer to initialization
- Breaks if PlotGridDisplay moves/scales
- Alternative (simple grid): Would be 2-3 lines

---

### 10. SelectionManager Feels Like Extra Layer
```gdscript
func _create_selection_manager() -> void:
    selection_manager = PlotSelectionManager.new()
    selection_manager.selection_changed.connect(_on_selection_changed)
    print("  🔄 PlotSelectionManager created")

func toggle_plot_selection(pos: Vector2i) -> void:
    selection_manager.save_state()
    var now_selected = selection_manager.toggle_plot(pos)
```

**Question**: Why not just use a Dictionary directly?
```gdscript
var selected_plots: Dictionary = {}  # pos → tile

func toggle_plot(pos: Vector2i):
    if selected_plots.has(pos):
        selected_plots.erase(pos)
    else:
        selected_plots[pos] = true
```

---

### 11. Manual State Reading vs Signals
**Current approach**:
```gdscript
func update_tile_from_farm(pos: Vector2i) -> void:
    var plot = farm.grid.get_plot(pos)
    if not plot:
        return

    # Manually read state and update tile visual
    var has_plant = plot.has_plant
    var plant_emoji = plot.plant_type_emoji
    # ... more manual copying ...
```

**Problem**: Not reactive, have to call this manually everywhere

**Better approach**:
```gdscript
# Connect once
farm.plot_planted.connect(func(pos, plant_type):
    tiles[pos].set_plant(plant_type)
)
```

But this had the "haunted" problem... why?

---

### 12. Input Routing Too Many Layers
```
InputMap event detected
  → FarmInputHandler._input(event)
  → _toggle_plot_selection(pos)
  → PlotGridDisplay.toggle_plot_selection(pos)
  → selection_manager.toggle_plot(pos)
  → PlotTile.set_selected(true)
```

Could be:
```
InputMap event detected
  → PlotTile._on_click()
  → PlotTile.selected = true
  → PlotTile emits selected_changed
  → UI responds
```

---

## Low-Priority Issues (Code Smell)

### 13. GridConfig is "Single Source of Truth" but Injected Everywhere
- Farm creates it
- FarmUIController extracts and distributes
- 4+ components receive it
- Could be singleton/autoload

---

### 14. Verbose Logging During Boot
~300+ print statements during boot makes debugging hard
- Need verbosity levels
- Or dedicated logger class

---

### 15. Coordinate Transforms Are Fragile
```gdscript
var local_pos = get_global_transform().affine_inverse() * screen_pos
```

If PlotGridDisplay ever gets parent transformation, this breaks

---

## What's Working Well

✅ Multi-select with checkboxes (T/Y/U/I/O/P/0/9/8/7 keys)
✅ Visual rendering of plots with parametric positioning
✅ Escape menu toggle (ESC key)
✅ Tool system (1-4 switches tools, Q/E/R execute actions)
✅ Farm simulation runs independently
✅ Keyboard shortcuts (V/C/N/K overlay toggles)

Don't break these while refactoring!

---

## Refactoring Priority Matrix

| Issue | Frequency | Severity | Effort | Priority |
|-------|-----------|----------|--------|----------|
| Race conditions | Sometimes | HIGH | Medium | 1 |
| Coordinate transforms | Often | MEDIUM | Low | 2 |
| Too many injections | Always | MEDIUM | Medium | 3 |
| Deferred init | Hard to debug | MEDIUM | High | 4 |
| Signal cascade | Occasional | HIGH | High | 5 |
| SelectionManager layer | Never | LOW | Low | 6 |
| Frame counting | Sometimes | MEDIUM | Low | 7 |

---

## Questions to Answer First

Before refactoring, understand:

1. Why did signal cascade cause "haunted" updates?
2. What was being updated multiple times?
3. Can we track down and fix the root cause instead of disabling signals?

If signals can be re-enabled with proper filtering, that solves many issues.
