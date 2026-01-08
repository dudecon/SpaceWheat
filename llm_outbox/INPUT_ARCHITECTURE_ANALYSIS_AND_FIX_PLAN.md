# SpaceWheat Input & Touch Architecture Analysis and Fix Plan
**Date:** 2026-01-06
**Status:** PLAN MODE - Investigation Complete

## Executive Summary

After comprehensive investigation of the UI, input, and touch screen handling, I've identified **critical architectural fragmentation** across multiple layers that is causing the reported issues:

1. **Q Button Display Update Issue**: Touch button press doesn't update ActionPreviewRow display (but functions correctly)
2. **Bubble Tap Not Working**: User cannot tap quantum bubbles despite signal connections being in place

The root cause is **inconsistent signal routing** and **conflicting input layers** that create race conditions and signal blocking.

---

## Current Architecture Map

### Input Layer Stack (Priority Order)
```
Layer 1: PlayerShell._input()           [HIGHEST PRIORITY]
  ├─ Modal stack (quest board, ESC menu)
  └─ Shell actions (C, K, ESC keys)

Layer 2: FarmInputHandler._unhandled_input()  [MEDIUM PRIORITY]
  ├─ Tool selection (1-6)
  ├─ Action execution (Q/E/R)
  ├─ Plot selection (T/Y/U/I/O/P)
  └─ Movement (WASD)

Layer 3: PlotGridDisplay._input()       [PLOT-SPECIFIC]
  ├─ Mouse click on plot tiles
  ├─ Drag selection across plots
  └─ Touch tap on plot tiles (via TouchInputManager.tap_detected)

Layer 4: TouchInputManager._input()     [GLOBAL TOUCH GESTURES]
  ├─ Detects InputEventScreenTouch
  ├─ Detects touch-generated InputEventMouseButton
  ├─ Emits tap_detected signal
  └─ Emits swipe_detected signal

Layer 5: QuantumForceGraph._unhandled_input()  [LOWEST PRIORITY]
  ├─ Mouse click on bubbles (real mouse only)
  ├─ Bubble tap (via TouchInputManager.tap_detected)
  └─ Bubble swipe (via TouchInputManager.swipe_detected)
```

### Signal Flow Chains

#### A. Keyboard Q Button → ActionPreviewRow Display Update
```
1. User presses Q key
2. FarmInputHandler._unhandled_input() detects KEY_Q
3. Calls _execute_tool_action("Q")
4. If action opens submenu: _enter_submenu()
5. Emits FarmInputHandler.submenu_changed signal
6. PlayerShell receives via connection (line 323)
7. Calls ActionBarManager.update_for_submenu()
8. Calls ActionPreviewRow.update_for_submenu()
9. Updates button.text for Q/E/R buttons
✅ WORKING
```

#### B. Touch Q Button → ActionPreviewRow Display Update
```
1. User taps Q button in ActionPreviewRow
2. Button._pressed signal fires
3. ActionPreviewRow._on_action_button_pressed("Q")
4. Emits ActionPreviewRow.action_pressed signal
5. PlayerShell._on_action_pressed_from_bar("Q")
6. FarmUI._on_action_pressed("Q")
7. FarmInputHandler.execute_action("Q")
8. Calls _execute_tool_action("Q")
9. If action opens submenu: _enter_submenu()
10. Emits FarmInputHandler.submenu_changed signal
11. PlayerShell receives via connection (line 323)
12. Calls ActionBarManager.update_for_submenu()
13. Calls ActionPreviewRow.update_for_submenu()
14. Updates button.text for Q/E/R buttons
❌ NOT UPDATING DISPLAY (but action executes correctly)
```

#### C. Touch Tap on Bubble
```
1. User taps screen where bubble is
2. TouchInputManager._input() receives InputEventScreenTouch OR InputEventMouseButton (device >= 0)
3. Records touch_start_pos, touch_start_time
4. On touch release, classifies as TAP (distance < 10px, duration < 300ms)
5. Emits TouchInputManager.tap_detected(position)
6. BOTH PlotGridDisplay AND QuantumForceGraph connected to this signal

PlotGridDisplay._on_touch_tap():
  - Converts position to grid coordinates
  - If position matches a plot tile → toggle_plot_selection()
  - If position doesn't match a plot → does nothing

QuantumForceGraph._on_bubble_tap():
  - Converts global position to local coordinates
  - Searches quantum_nodes for node at position
  - If bubble found → emits node_clicked signal
  - FarmView._on_quantum_node_clicked() → farm.measure_plot()
❌ NOT WORKING (signal never reaches bubble handler)
```

---

## Identified Issues

### Issue 1: Q Button Touch Display Update Failure

**Symptoms:**
- Touch Q button → submenu functions execute correctly
- Touch Q button → button labels don't update to show submenu actions
- Keyboard Q → works perfectly (both function AND display update)

**Root Cause Analysis:**

The signal chain is **IDENTICAL** for both keyboard and touch paths. The debug logging shows:
1. FarmInputHandler.execute_action() is called ✅
2. _enter_submenu() is called ✅
3. submenu_changed signal is emitted ✅
4. ActionBarManager.update_for_submenu() is called ✅
5. ActionPreviewRow.update_for_submenu() is called ✅
6. button.text is updated ✅

**BUT** the visual update doesn't render on screen for touch input.

**Hypothesis:** This is a **Godot 4 button state caching issue**. When a button is pressed via touch, Godot may be in a "button pressed" visual state that prevents text updates from rendering until the button returns to normal state. The keyboard path doesn't trigger button visual states.

**Evidence:**
- ActionPreviewRow.gd:142 shows button.text is being set
- Debug log confirms text change happens
- User sees text update AFTER touching something else

### Issue 2: Bubble Taps Not Working

**Symptoms:**
- User taps bubbles repeatedly → no response
- Bubble tap signal handler has debug logging that never fires
- Mouse clicks on bubbles work in dev environment

**Root Cause Analysis:**

Signal connection order creates a **tap capture conflict**:

```gdscript
// PlotGridDisplay._create_tiles() - line 335
TouchInputManager.tap_detected.connect(_on_touch_tap)

// QuantumForceGraph._ready() - line 138
TouchInputManager.tap_detected.connect(_on_bubble_tap)
```

**BOTH handlers** receive EVERY tap. The execution order is:
1. TouchInputManager emits tap_detected
2. PlotGridDisplay._on_touch_tap() processes FIRST (connected first)
3. QuantumForceGraph._on_bubble_tap() processes SECOND

**The Critical Bug:**
PlotGridDisplay._on_touch_tap() does NOT call `get_viewport().set_input_as_handled()` when it FAILS to find a plot. This means:
- Tap on plot → PlotGridDisplay handles it ✅
- Tap on empty space → PlotGridDisplay does nothing, doesn't consume event
- Tap on bubble → PlotGridDisplay does nothing, doesn't consume event
- **But the tap was still "processed" in Godot's signal system**

The QuantumForceGraph._on_bubble_tap() handler receives the tap, but by this point:
1. PlotGridDisplay already tried to find a plot
2. The tap position was converted to grid coordinates (incorrect for bubbles)
3. The event didn't get properly forwarded to bubble detection

**Evidence:**
- PlotGridDisplay.gd:753-763 shows _on_touch_tap implementation
- QuantumForceGraph.gd:413-428 shows _on_bubble_tap implementation
- No `set_input_as_handled()` call in PlotGridDisplay when plot not found
- Signal connection order means PlotGridDisplay processes first

---

## Architectural Problems

### 1. **Dual Signal Handler Conflict**
TouchInputManager broadcasts `tap_detected` to ALL connected handlers. Both PlotGridDisplay and QuantumForceGraph connect to it, creating ambiguity about which system should handle the tap.

### 2. **No Spatial Hierarchy**
There's no clear spatial ownership of screen regions. PlotGridDisplay and QuantumForceGraph overlap visually but have no coordination about who "owns" each tap target.

### 3. **Inconsistent Event Consumption**
- PlotGridDisplay._input() properly calls `set_input_as_handled()` for plot clicks
- PlotGridDisplay._on_touch_tap() does NOT call it when plot not found
- QuantumForceGraph._on_bubble_tap() doesn't consume events (signal handler, not input handler)

### 4. **Button State Caching in ActionPreviewRow**
Godot's Button node may cache visual state during touch press, preventing text updates from rendering immediately.

### 5. **Signal Chain Indirection**
Q button touch goes through 7 indirection layers before reaching ActionPreviewRow.update_for_submenu(). Any step that blocks the rendering loop prevents visual update.

---

## Proposed Fix Plan

### Phase 1: Fix Q Button Display Update (IMMEDIATE)

**Option A: Force Button Redraw**
```gdscript
# In ActionPreviewRow.update_for_submenu()
button.text = new_text
button.queue_redraw()  # Force immediate visual update
button.update_minimum_size()  # Recalculate layout
```

**Option B: Defer Update After Touch Release**
```gdscript
# In ActionPreviewRow.update_for_submenu()
# Defer update by 1 frame to let button state reset
await get_tree().process_frame
button.text = new_text
```

**Option C: Use StyleBoxFlat Override**
```gdscript
# Create custom StyleBox that doesn't cache state
# Force text to redraw on every frame while button is in pressed state
```

**Recommended:** Try Option A first (simplest), fall back to Option B if needed.

### Phase 2: Fix Bubble Tap Detection (HIGH PRIORITY)

**Strategy: Implement Spatial Hit Testing Hierarchy**

Replace broadcast signal approach with explicit spatial hierarchy:

```gdscript
# TouchInputManager.tap_detected remains as broadcast
# But handlers implement priority-based consumption

# In PlotGridDisplay._on_touch_tap()
func _on_touch_tap(position: Vector2) -> void:
    var plot_pos = _get_plot_at_screen_position(position)
    if plot_pos != Vector2i(-1, -1):
        toggle_plot_selection(plot_pos)
        return true  # Consumed
    return false  # Not consumed, try next handler

# In QuantumForceGraph._on_bubble_tap()
func _on_bubble_tap(position: Vector2) -> void:
    # Only process if PlotGridDisplay didn't consume
    if PlotGridDisplay.tap_was_consumed:
        return

    var local_pos = get_global_transform().affine_inverse() * position
    var tapped_node = get_node_at_position(local_pos)
    if tapped_node:
        node_clicked.emit(tapped_node.grid_position, 0)
```

**Alternative: Implement Z-Index Hit Testing**

Use Control nodes' z-index and mouse_filter to create proper spatial hierarchy:

```gdscript
# QuantumForceGraph should have higher z-index than PlotGridDisplay
# Use Area2D nodes for bubble hit detection instead of manual position checking
# Godot's built-in input handling respects z-index automatically
```

**Recommended:** Implement spatial hierarchy with explicit consumption flags.

### Phase 3: Architectural Refactor (LONG-TERM)

**Goal:** Clean separation of input responsibilities

```
TouchInputManager (Autoload)
  ├─ Gesture Detection Only
  └─ Emits: tap_detected, swipe_detected, long_press_detected

InputCoordinator (NEW - Autoload)
  ├─ Receives all touch gestures
  ├─ Implements spatial hit testing hierarchy
  ├─ Routes events to appropriate handlers
  └─ Ensures only ONE handler processes each event

Handlers (No longer directly connected to TouchInputManager)
  ├─ PlotGridDisplay: Register hit boxes for plot tiles
  ├─ QuantumForceGraph: Register hit boxes for bubbles
  ├─ ActionBar: Register hit boxes for buttons
  └─ Modals: Register full-screen overlay when active
```

**Benefits:**
- Single source of truth for event consumption
- Clear spatial ownership
- No signal connection order dependencies
- Easy to debug (all routing in one place)

---

## Implementation Steps

### Step 1: Quick Fix - Q Button Display (30 min)
1. Add `queue_redraw()` call to ActionPreviewRow.update_for_submenu()
2. Test with touch Q button
3. If still not working, try `await get_tree().process_frame` defer
4. Commit fix

### Step 2: Quick Fix - Bubble Tap Priority (1 hour)
1. Modify PlotGridDisplay._on_touch_tap() to return bool
2. Add `tap_consumed` flag to TouchInputManager
3. Modify QuantumForceGraph._on_bubble_tap() to check flag
4. Test bubble taps
5. Commit fix

### Step 3: Add Debug Logging (30 min)
1. Add comprehensive logging to all signal handlers
2. Log signal connection order at startup
3. Log tap position, handler order, consumption status
4. Create debug overlay showing active input handlers
5. Commit debug tools

### Step 4: Architectural Refactor (4 hours)
1. Design InputCoordinator API
2. Implement spatial hit testing system
3. Migrate handlers to registration pattern
4. Remove direct TouchInputManager connections
5. Update all input handling code
6. Test thoroughly
7. Document new architecture
8. Commit refactor

---

## Testing Plan

### Test Case 1: Q Button Touch Display
```
Setup: Load game, select tool 1 (Grower)
Action: Touch Q button in action bar
Expected: Button labels change to show plant submenu (🌾 Wheat, 🍄 Mushroom, 🍅 Tomato)
Actual (Before Fix): Labels don't change visually
Actual (After Fix): Labels update immediately
```

### Test Case 2: Bubble Tap Detection
```
Setup: Plant wheat at plot (0,0), wait for bubble to appear
Action: Tap directly on quantum bubble
Expected: Measure action executes, bubble collapses to definite state
Actual (Before Fix): No response to tap
Actual (After Fix): Bubble responds immediately
```

### Test Case 3: Plot vs Bubble Tap Priority
```
Setup: Plant wheat at (0,0), position plot tile and bubble overlapping
Action: Tap on overlap area
Expected: Plot tile gets priority (checkbox toggle)
Actual: Verify plot responds, not bubble
```

### Test Case 4: Empty Space Tap
```
Setup: Game running
Action: Tap on empty space (no plot, no bubble)
Expected: No action, no error
Actual: Verify no handlers consume event
```

---

## Risk Assessment

### Q Button Fix
- **Risk: Low** - Isolated change to single function
- **Impact: High** - Fixes critical UX issue
- **Rollback: Easy** - Remove queue_redraw() call

### Bubble Tap Fix
- **Risk: Medium** - Changes signal flow pattern
- **Impact: High** - Enables core gameplay mechanic
- **Rollback: Medium** - Revert to broadcast pattern

### Architectural Refactor
- **Risk: High** - Touches all input handling code
- **Impact: Very High** - Prevents future input bugs
- **Rollback: Hard** - Would require careful git revert

**Recommendation:** Implement fixes in phases, test thoroughly between each phase.

---

## Success Criteria

1. ✅ Touch Q button → Action bar buttons update text immediately
2. ✅ Keyboard Q button → Still works (no regression)
3. ✅ Tap on quantum bubble → Measure action executes
4. ✅ Tap on plot tile → Checkbox toggles
5. ✅ Tap on empty space → No error
6. ✅ Rapid tapping bubbles → All taps processed correctly
7. ✅ Touch and keyboard both work identically
8. ✅ No console errors or warnings

---

## Next Steps

**USER APPROVAL REQUIRED** before implementing fixes.

1. Review this architectural analysis
2. Approve fix approach for Q button issue
3. Approve fix approach for bubble tap issue
4. Decide whether to proceed with architectural refactor
5. Begin implementation in approved order

---

## Files Requiring Changes

### Quick Fixes (Steps 1-2)
- `UI/Panels/ActionPreviewRow.gd` - Add queue_redraw() for button updates
- `UI/PlotGridDisplay.gd` - Add return bool to _on_touch_tap()
- `UI/Input/TouchInputManager.gd` - Add tap_consumed flag
- `Core/Visualization/QuantumForceGraph.gd` - Check consumption flag

### Architectural Refactor (Step 4)
- `UI/Input/InputCoordinator.gd` - NEW FILE - Central input routing
- `UI/Input/TouchInputManager.gd` - Simplify to gesture detection only
- `UI/PlotGridDisplay.gd` - Register hit boxes with coordinator
- `Core/Visualization/QuantumForceGraph.gd` - Register hit boxes
- `UI/PlayerShell.gd` - Connect coordinator instead of direct handlers
- `UI/FarmView.gd` - Update signal connections

---

## Conclusion

The input architecture suffers from **conflicting signal handlers** and **lack of spatial hierarchy**. The proposed fixes address immediate bugs while setting up for a cleaner long-term architecture.

**Recommendation:** Implement Phase 1 and Phase 2 fixes immediately, then evaluate whether architectural refactor is needed based on user feedback and future development plans.
