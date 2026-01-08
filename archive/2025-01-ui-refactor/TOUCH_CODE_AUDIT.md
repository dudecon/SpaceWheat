# Touch Code Audit - Non-Functional Code Analysis

**Date**: 2026-01-06
**Status**: 🔴 BROKEN - Touch input has not worked for many updates

## Executive Summary

Touch input code exists in the codebase but **does not work**. The code uses a mix of:
1. **Godot 3 APIs** that don't exist in Godot 4 (`InputEventScreenDrag`)
2. **Incomplete implementations** missing motion tracking
3. **Scattered touch handling** without unified architecture

**Recommendation**: Remove all broken touch code and start fresh with Godot 4 best practices.

---

## Files with Touch Code

### 1. **UI/PlotGridDisplay.gd** ❌ BROKEN
**Lines**: 712-733
**Problem**: Uses non-existent `InputEventScreenDrag` (Godot 3 API)

```gdscript
# Line 728 - DOES NOT WORK IN GODOT 4
elif event is InputEventScreenDrag:
    if is_dragging:
        var plot_pos = _get_plot_at_screen_position(event.position)
```

**What it tries to do**:
- Touch down on plot → start drag selection
- Touch drag → expand selection
- Touch up → end selection

**Why it fails**:
- `InputEventScreenDrag` doesn't exist in Godot 4
- No motion tracking between touch down/up
- Missing multi-touch support

**Code to remove**: Lines 712-732 (entire touch handling section)

---

### 2. **Core/Visualization/QuantumForceGraph.gd** ⚠️ INCOMPLETE
**Lines**: 350-394
**Problem**: Only handles touch down/up, no motion tracking for swipes

```gdscript
# Line 350 - Partial implementation
elif event is InputEventScreenTouch:
    local_pos = get_global_transform().affine_inverse() * event.position
    is_press = event.pressed
    is_release = not event.pressed
```

**What it tries to do**:
- Tap bubble → measure/collapse
- Swipe between bubbles → create entanglement

**Why it doesn't work fully**:
- No `InputEventScreenTouch` motion tracking
- Swipe detection relies on press/release positions only (no intermediate points)
- No multi-finger gesture support
- Missing cancel on interrupted gestures

**Code to review**: Lines 330-420 (entire `_unhandled_input` touch section)

---

### 3. **UI/Components/PanelTouchButton.gd** ✅ WORKS (Buttons Only)
**Lines**: Entire file
**Status**: This actually works - uses Control's built-in `_gui_input()`

```gdscript
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        # Works for both mouse and touch automatically
```

**Why this works**:
- Control nodes handle touch/mouse automatically via `_gui_input()`
- Godot converts touch to mouse events for UI controls
- No manual `InputEventScreenTouch` handling needed

**Action**: KEEP AS-IS - this is the correct approach for buttons

---

### 4. **UI/Panels/BiomeInspectorOverlay.gd** ⚠️ PARTIAL
**Lines**: 229-232
**Problem**: Only handles background tap to close

```gdscript
# Line 229 - Very minimal
elif event is InputEventScreenTouch:
    if event.pressed:
        print("🔍 BiomeInspectorOverlay: Background tapped (touch), closing")
        hide_overlay()
```

**What it tries to do**: Close overlay on background tap

**Why it's incomplete**:
- No prevention of accidental touches
- Doesn't distinguish from intentional UI interactions
- No touch state tracking

**Code to review**: Lines 227-232

---

### 5. **UI/FarmInputHandler.gd** 🔍 TO INVESTIGATE
**Contains**: Keyboard/mouse input routing
**Touch handling**: None found (all keyboard-based)

**What's missing**:
- Touch-to-keyboard translation for tool selection (1-6)
- Touch-to-keyboard translation for actions (Q/E/R)
- Touch navigation (arrows)

**Action**: This file doesn't need removal, but needs NEW touch input routing

---

## Summary of Broken Touch Code

### Non-Existent Godot 4 APIs Used:
1. **`InputEventScreenDrag`** (PlotGridDisplay.gd:728)
   - This class does not exist in Godot 4
   - Was removed between Godot 3 and 4
   - Must use motion tracking with `InputEventScreenTouch` instead

### Incomplete Implementations:
1. **Plot drag selection** (PlotGridDisplay.gd)
   - Touch down/up handlers exist
   - No motion tracking between touches
   - Can't drag across multiple plots

2. **Quantum bubble swipe** (QuantumForceGraph.gd)
   - Press/release detection works
   - Swipe detection based only on start/end points (unreliable)
   - No intermediate position tracking

3. **Overlay background tap** (BiomeInspectorOverlay.gd)
   - Works for closing
   - No gesture discrimination (tap vs accidental touch)

### What Works (Don't Remove):
1. **PanelTouchButton** - Uses `_gui_input()` correctly
2. **UI button interactions** - Godot handles automatically

---

## Godot 3 vs Godot 4 Touch API Changes

### Godot 3 Touch Events:
```gdscript
# OLD - These don't exist in Godot 4:
InputEventScreenTouch    # Press/release only
InputEventScreenDrag     # Dragging motion (REMOVED)
```

### Godot 4 Touch Events:
```gdscript
# NEW - Godot 4 approach:
InputEventScreenTouch    # Handles both press/release AND motion
  - .pressed: bool       # Touch down (true) or up (false)
  - .index: int          # Finger ID (0-9 for multi-touch)
  - .position: Vector2   # Screen position

# Motion tracking in Godot 4:
# Must track press/release with same .index
# No separate "drag" event - monitor position changes between frames
```

---

## Recommended Removal Plan

### Phase 1: Remove Broken Code

**Files to modify**:

1. **UI/PlotGridDisplay.gd**
   - DELETE lines 712-732 (entire `InputEventScreenDrag` section)
   - Keep mouse-only drag selection for now
   - Comment: "# TODO: Implement Godot 4 touch drag selection"

2. **Core/Visualization/QuantumForceGraph.gd**
   - KEEP `InputEventScreenTouch` press/release (lines 350-394)
   - ADD comment: "# NOTE: Swipe detection incomplete - needs motion tracking"
   - Mark as "partial implementation" for future fix

3. **UI/Panels/BiomeInspectorOverlay.gd**
   - KEEP simple background tap (lines 229-232)
   - ADD TODO: "# TODO: Add gesture discrimination"

### Phase 2: Document Clean Slate

Create: `/home/tehcr33d/.claude/plans/touch_clean_slate.md`

**Contents**:
1. Current state after removal
2. Godot 4 touch API reference
3. Architecture design for new touch system
4. Implementation phases (start fresh)

---

## Why Starting Fresh is Better

### Problems with Fixing Existing Code:
1. **API mismatch**: Code designed for Godot 3 touch model
2. **Architecture debt**: Touch handling scattered across files
3. **Incomplete state**: Multiple half-finished implementations
4. **Testing burden**: Unknown what works vs what's broken

### Benefits of Clean Slate:
1. **Godot 4 native**: Use proper APIs from start
2. **Unified architecture**: Single touch manager component
3. **Testable**: Build incrementally with clear success criteria
4. **Modern patterns**: Gestures, multi-touch, accessibility

---

## Next Steps

1. ✅ **Audit complete** (this document)
2. ⏳ **Remove broken code** (Phase 1 above)
3. ⏳ **Create clean slate plan** (Phase 2 above)
4. ⏳ **Implement fresh touch system** (following new plan)

---

## Files Requiring Changes

### To Remove Touch Code:
- `UI/PlotGridDisplay.gd` - Remove lines 712-732
- (Others: keep with TODOs added)

### To Keep As-Is:
- `UI/Components/PanelTouchButton.gd` - Already correct
- All test files in `Tests/` - Archive for reference

### To Create New:
- `UI/Input/TouchInputManager.gd` - New unified touch handler
- Updated plan document with Godot 4 approach

---

## Godot 4 Touch Best Practices (For Future Implementation)

### Use `_gui_input()` for UI Controls:
```gdscript
# Correct approach for buttons, panels, etc:
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:  # Handles touch automatically
        if event.pressed:
            # Touch/click handled identically
```

### Use `_input()` for Game World Touches:
```gdscript
# For plot tiles, quantum bubbles, etc:
func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            # Track touch start with event.index
        else:
            # Track touch end with event.index
        # Must manually track motion between frames
```

### Multi-Touch Pattern:
```gdscript
var active_touches: Dictionary = {}  # index -> TouchData

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            active_touches[event.index] = {
                "start_pos": event.position,
                "current_pos": event.position,
                "start_time": Time.get_ticks_msec()
            }
        else:
            active_touches.erase(event.index)

func _process(delta: float) -> void:
    # Update touch positions each frame
    for index in active_touches:
        # Track motion, detect gestures
```

---

## Conclusion

The codebase has **non-functional touch code** due to:
1. Godot 3 → 4 API migration issues
2. Incomplete implementations
3. Scattered architecture

**Recommendation**: Remove broken code, start fresh with Godot 4 best practices.
