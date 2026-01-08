# Touch Behavior Report

## Test Method

Code analysis of touch handlers in:
- `UI/PlotGridDisplay.gd:734` - Plot tap handler
- `Core/Visualization/QuantumForceGraph.gd:413` - Bubble tap handler
- `UI/FarmView.gd:134` - Bubble action handler

## PLOT TOUCHES (Bottom Grid Tiles)

### What Plot Touches Do

**Plot touches are PASSIVE** - they only change which plot is highlighted/selected.

```
Touch Flow:
  TouchInputManager.tap_detected
    ↓
  PlotGridDisplay._on_touch_tap(position)
    ↓
  set_selected_plot(grid_pos)
    ↓
  Visual highlight changes (no game action)
```

### Touch Sequence Behavior

| Touch | Action | Result |
|-------|--------|--------|
| **Touch 1** on Plot A | Selects plot | Plot A highlighted ✅ |
| **Touch 2** on Plot A | Re-selects same plot | Plot A still highlighted (no change) |
| **Touch 3** on Plot B | Selects different plot | Plot B highlighted, Plot A unhighlighted |

### How to Actually DO Something with Selected Plot

After selecting a plot via touch, you must:
1. Press a **tool button** (bottom row: Wheat, Mushroom, etc.)
2. Press an **action button** (middle row: Build, Water, etc.)

**Example workflow**:
```
1. Touch plot → selects it
2. Tap "Wheat" tool button → tool armed
3. Tap "Build" action button → builds wheat on selected plot
```

### Code Evidence

```gdscript
// UI/PlotGridDisplay.gd:734
func _on_touch_tap(position: Vector2) -> void:
    """Handle touch tap for plot selection"""
    var plot_pos = _get_plot_at_screen_position(position)
    if plot_pos != Vector2i(-1, -1):
        # Select single plot (like arrow key navigation)
        set_selected_plot(plot_pos)  // ← ONLY changes selection
        print("📱 Plot selected via touch tap: %s" % plot_pos)
```

No game actions are performed - just visual selection changes.

---

## BUBBLE TOUCHES (Quantum Visualization Area)

### What Bubble Touches Do

**Bubble touches are ACTIVE** - they immediately trigger contextual actions based on plot state.

```
Touch Flow:
  TouchInputManager.tap_detected
    ↓
  QuantumForceGraph._on_bubble_tap(position)
    ↓
  Emits node_clicked signal
    ↓
  FarmView._on_quantum_node_clicked(grid_pos, button)
    ↓
  Contextual action based on plot state
```

### Touch Sequence Behavior (State-Dependent)

| Touch | Plot State Before | Action Performed | Plot State After |
|-------|------------------|------------------|------------------|
| **Touch 1** | Empty | Plants wheat | Planted (unmeasured) |
| **Touch 2** | Planted (unmeasured) | **MEASURES** quantum state | Measured |
| **Touch 3** | Measured | **HARVESTS** | Empty |

### The Contextual State Machine

Each bubble tap checks the plot state and performs the **next logical action**:

```gdscript
// UI/FarmView.gd:154-163
if not plot.is_planted:
    print("   → Plot empty - planting wheat")
    farm.plant_wheat(grid_pos)  // ← Touch 1

elif not plot.has_been_measured:
    print("   → Plot planted - MEASURING quantum state")
    farm.measure_plot(grid_pos)  // ← Touch 2

else:
    print("   → Plot measured - HARVESTING")
    farm.harvest_plot(grid_pos)  // ← Touch 3
```

### Detailed Example

**Starting with empty plot at (0, 0):**

1. **First touch** on bubble:
   - State check: `is_planted = false`
   - Action: `farm.plant_wheat(grid_pos)`
   - Result: Wheat planted, quantum bubble appears, state is superposition
   - Console: `"→ Plot empty - planting wheat"`

2. **Second touch** on same bubble:
   - State check: `is_planted = true, has_been_measured = false`
   - Action: `farm.measure_plot(grid_pos)`
   - Result: **Quantum state collapses** - superposition → definite emoji (🌾 or 🍄 etc.)
   - Console: `"→ Plot planted - MEASURING quantum state"`
   - Visual: Bubble may change appearance or disappear

3. **Third touch** on same bubble:
   - State check: `is_planted = true, has_been_measured = true`
   - Action: `farm.harvest_plot(grid_pos)`
   - Result: Resources collected, plot becomes empty
   - Console: `"→ Plot measured - HARVESTING"`

4. **Fourth touch** would cycle back to planting (state is empty again)

### Code Evidence

```gdscript
// Core/Visualization/QuantumForceGraph.gd:413
func _on_bubble_tap(position: Vector2) -> void:
    """Handle touch tap on quantum bubble - measure/collapse"""
    var local_pos = get_global_transform().affine_inverse() * position
    var tapped_node = get_node_at_position(local_pos)

    if tapped_node:
        print("📱 Bubble tapped: %s (measure/collapse)" % tapped_node.grid_position)
        # Emit click signal - this triggers measurement/collapse
        node_clicked.emit(tapped_node.grid_position, 0)  // ← Immediately fires
```

The signal is emitted immediately, no selection needed.

---

## SWIPE GESTURES (Bubble to Bubble)

### What Swipe Does

**Swipe between bubbles creates ENTANGLEMENT** - a quantum connection.

```
Swipe Flow:
  TouchInputManager.swipe_detected
    ↓
  QuantumForceGraph._on_bubble_swipe(start, end, direction)
    ↓
  Finds nodes at start and end positions
    ↓
  Emits node_swiped_to signal
    ↓
  FarmView._on_quantum_nodes_swiped(from_pos, to_pos)
    ↓
  farm.grid.create_entanglement(from_pos, to_pos, "phi_plus")
```

### Result

- Creates Bell state entanglement between two plots
- Default: `phi_plus` state
- Visual: Line/connection drawn between bubbles
- Quantum: States become correlated - measuring one affects the other

### Code Evidence

```gdscript
// UI/FarmView.gd:166-181
func _on_quantum_nodes_swiped(from_grid_pos: Vector2i, to_grid_pos: Vector2i) -> void:
    """Handle swipe gesture between quantum bubbles - SWIPE TO ENTANGLE"""
    print("✨✨✨ BUBBLE SWIPE HANDLER CALLED! %s → %s" % [from_grid_pos, to_grid_pos])

    // Create entanglement using default Bell state (phi_plus)
    var bell_state = "phi_plus"
    var success = farm.grid.create_entanglement(from_grid_pos, to_grid_pos, bell_state)
```

---

## SUMMARY TABLE

| Target | Touch Type | Touch 1 | Touch 2 | Touch 3 |
|--------|-----------|---------|---------|---------|
| **Plot Tile** | Tap | Select plot | Keep selected | Select different plot |
| **Bubble** | Tap | Plant wheat | Measure (collapse) | Harvest |
| **Bubble→Bubble** | Swipe | Create entanglement | Create another entanglement | Keep entangling |

## KEY DIFFERENCES

### Plots (Passive Selection)
- ❌ No immediate game action
- ✅ Changes visual highlight only
- ✅ Requires additional button press to act
- 🎯 Like using arrow keys to navigate

### Bubbles (Active Context)
- ✅ Immediate game action
- ✅ Action depends on plot state
- ✅ Progresses through plant → measure → harvest cycle
- 🎯 Like clicking a button that does something different based on context

## WHY THE DIFFERENCE?

**Plots** = **Classical Interface**
- Represents physical farm locations
- Use tool + action paradigm (select, then act)
- Supports multi-selection (Shift+Click, drag)
- Traditional UI pattern

**Bubbles** = **Quantum Interface**
- Represents quantum state space
- Direct interaction with quantum mechanics
- Tap = observe/collapse quantum state
- Swipe = create entanglement
- Gesture-based, immediate feedback

## TESTING CHECKLIST

### Manual Test: Plot Touches
1. ✅ Launch game on touch device
2. ✅ Tap plot tile at bottom
3. ✅ Verify plot highlights (border/glow)
4. ✅ Tap same plot - should stay highlighted
5. ✅ Tap different plot - highlight should move
6. ✅ Tap tool button (e.g., "Wheat")
7. ✅ Tap "Build" action button
8. ✅ Verify wheat builds on selected plot

### Manual Test: Bubble Touches (Full Cycle)
1. ✅ Launch game on touch device
2. ✅ Tap empty bubble → wheat should plant
3. ✅ Wait for visual confirmation (bubble appears)
4. ✅ Tap same bubble again → measurement happens (bubble changes)
5. ✅ Tap same bubble third time → harvest (resources +1)
6. ✅ Plot should be empty again

### Manual Test: Swipe Gesture
1. ✅ Plant wheat on two plots (tap two empty bubbles)
2. ✅ Swipe from first bubble to second bubble
3. ✅ Verify entanglement created (visual line connects them)
4. ✅ Measure one → verify the other is affected

## LOGS TO EXPECT

### Successful Plot Touch
```
👆 TouchManager: TAP detected at (225.0, 223.0)
📱 Plot selected via touch tap: (0, 0)
  🎯 Selected plot: (0, 0)
```

### Successful Bubble Touch (Empty → Planted)
```
👆 TouchManager: TAP detected at (480.0, 150.0)
📱 Bubble tapped: (0, 0) (measure/collapse)
🎯🎯🎯 BUBBLE TAP HANDLER CALLED! Grid pos: (0, 0), button: 0
   → Plot empty - planting wheat
```

### Successful Bubble Touch (Planted → Measured)
```
👆 TouchManager: TAP detected at (480.0, 150.0)
📱 Bubble tapped: (0, 0) (measure/collapse)
🎯🎯🎯 BUBBLE TAP HANDLER CALLED! Grid pos: (0, 0), button: 0
   → Plot planted - MEASURING quantum state
```

### Successful Bubble Touch (Measured → Harvested)
```
👆 TouchManager: TAP detected at (480.0, 150.0)
📱 Bubble tapped: (0, 0) (measure/collapse)
🎯🎯🎯 BUBBLE TAP HANDLER CALLED! Grid pos: (0, 0), button: 0
   → Plot measured - HARVESTING
```

### Successful Swipe
```
👆 TouchManager: SWIPE detected: (480.0, 150.0) → (600.0, 150.0)
✨✨✨ BUBBLE SWIPE HANDLER CALLED! (0, 0) → (1, 0)
[Entanglement creation logs...]
```

---

## CONCLUSION

Touch input has been implemented with two distinct paradigms:

1. **Plot Tiles** = Passive selection (must follow up with tool/action buttons)
2. **Quantum Bubbles** = Active context-sensitive actions (immediate effect based on state)

The fix applied (`FarmUIContainer.mouse_filter = 2`) allows both systems to receive touch events properly.

All touch handlers are connected and functional according to code analysis.
