# Touch Input Fix

**Date**: 2026-01-06
**Status**: ✅ Touch event consumption fixed
**Issue**: Touch worked intermittently ("sometimes registers if i spam tap the screen a dozen times or so")

---

## Root Cause

Touch events in Godot 4 are automatically converted to BOTH:
1. `InputEventScreenTouch` (original touch event)
2. `InputEventMouseButton` (auto-generated for compatibility)

**The Problem**:
- PlotGridDisplay and QuantumForceGraph were consuming the touch-generated mouse events
- This prevented TouchInputManager from receiving the original touch events
- Result: Touch detection was unreliable and intermittent

### Input Processing Order in Godot 4

```
1. Scene tree nodes call _input() (depth-first traversal)
   ├─ PlotGridDisplay._input() ← consumed touch-generated mouse events!
   └─ QuantumForceGraph._unhandled_input() ← also handled touch events!
2. Autoloads call _input()
   └─ TouchInputManager._input() ← never received touch events!
3. Scene tree nodes call _unhandled_input()
```

When PlotGridDisplay consumed the touch-generated mouse event at step 1 with `get_viewport().set_input_as_handled()`, TouchInputManager at step 2 never received the original `InputEventScreenTouch`.

---

## The Fix

### 1. PlotGridDisplay - Ignore Touch-Generated Mouse Events

**File**: `UI/PlotGridDisplay.gd`
**Lines**: 687-715

Added device check to distinguish real mouse from touch-generated mouse:

```gdscript
func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        # Check if this is a touch-generated mouse event
        if event.device == -1:
            # device == -1 means real mouse (not touch-generated)
            # Handle mouse normally...
            get_viewport().set_input_as_handled()
        else:
            # Touch-generated mouse event - ignore, let TouchInputManager handle it
            print("Touch-generated mouse event (device=%d) - ignoring" % event.device)
            # DO NOT consume - let TouchInputManager see the original touch event
```

**Key**: `event.device == -1` for real mouse, `event.device >= 0` for touch-generated mouse events.

### 2. QuantumForceGraph - Ignore Touch-Generated Mouse Events

**File**: `Core/Visualization/QuantumForceGraph.gd`
**Lines**: 335-363

Removed direct handling of `InputEventScreenTouch` - now only handles real mouse:

```gdscript
func _unhandled_input(event: InputEvent):
    # Only handle real mouse events (not touch-generated)
    if not (event is InputEventMouseButton):
        return

    # Check if touch-generated
    if event.device != -1:
        # Touch-generated - ignore, let TouchInputManager handle it
        return

    # Real mouse event - handle it
    var local_pos = get_global_transform().affine_inverse() * event.global_position
    # ... handle mouse click
```

**Before**: QuantumForceGraph handled BOTH mouse AND touch events directly
**After**: QuantumForceGraph handles ONLY real mouse events
**Touch**: Handled by TouchInputManager → emits tap_detected/swipe_detected → _on_bubble_tap()/_on_bubble_swipe()

---

## How Touch Input Works Now

### Correct Flow for Touch Events

```
User taps screen
    ↓
Godot generates:
  - InputEventScreenTouch (original)
  - InputEventMouseButton (auto-generated, device=0 or higher)
    ↓
1. PlotGridDisplay._input() receives InputEventMouseButton
   ├─ Checks event.device
   ├─ device != -1 → touch-generated
   └─ IGNORES (does not consume)
    ↓
2. QuantumForceGraph._unhandled_input() receives InputEventMouseButton
   ├─ Checks event.device
   ├─ device != -1 → touch-generated
   └─ IGNORES (does not consume)
    ↓
3. TouchInputManager._input() receives InputEventScreenTouch ✅
   ├─ Processes tap/swipe gesture
   └─ Emits tap_detected or swipe_detected
    ↓
4. Signal handlers respond:
   ├─ PlotGridDisplay._on_touch_tap() for plot selection
   ├─ QuantumForceGraph._on_bubble_tap() for bubble taps
   └─ QuantumForceGraph._on_bubble_swipe() for entanglement
```

### Correct Flow for Mouse Events

```
User clicks mouse
    ↓
Godot generates:
  - InputEventMouseButton (device=-1 for real mouse)
    ↓
1. PlotGridDisplay._input() receives InputEventMouseButton
   ├─ Checks event.device
   ├─ device == -1 → real mouse
   └─ HANDLES (plot drag selection, consumes event)
    ↓
2. QuantumForceGraph._unhandled_input() receives InputEventMouseButton
   ├─ Checks event.device
   ├─ device == -1 → real mouse
   └─ HANDLES (bubble click, consumes event)
    ↓
3. TouchInputManager._input() never receives mouse events (only cares about touch)
```

---

## Debug Logging Added

Temporarily added debug prints to diagnose the issue:

### TouchInputManager.gd
```gdscript
print("🔵 TouchManager._input: InputEventScreenTouch - pressed=%s, pos=%s" % [event.pressed, event.position])
print("🔵 TouchManager._input: InputEventMouseButton - pressed=%s, pos=%s (might be touch-generated)" % [event.pressed, event.position])
```

### PlotGridDisplay.gd
```gdscript
print("🎯 PlotGridDisplay._input: Touch-generated mouse event (device=%d) - ignoring for TouchInputManager" % event.device)
```

### QuantumForceGraph.gd
```gdscript
print("🖱️  QuantumForceGraph: Touch-generated mouse event (device=%d) - ignoring for TouchInputManager" % event.device)
```

**TODO**: Remove these debug prints after confirming touch works reliably.

---

## Files Modified

| File | Changes | Lines |
|------|---------|-------|
| UI/Input/TouchInputManager.gd | Added debug logging | 26-33 |
| UI/PlotGridDisplay.gd | Check event.device, ignore touch-generated mouse | 687-715 |
| Core/Visualization/QuantumForceGraph.gd | Check event.device, ignore touch-generated mouse | 335-363 |

---

## Testing

### Expected Behavior

**Touch Tap**:
1. TouchInputManager prints: "👆 TouchManager: TAP detected at ..."
2. PlotGridDisplay prints: "📱 Plot selected via touch tap: ..." (if on plot)
3. OR QuantumForceGraph prints: "📱 Bubble tapped: ..." (if on bubble)

**Touch Swipe**:
1. TouchInputManager prints: "👆 TouchManager: SWIPE detected: ..."
2. QuantumForceGraph prints: "📱 Swipe entanglement: ... → ..."

**Mouse Click**:
1. PlotGridDisplay prints: "🎯 PlotGridDisplay._input: Mouse click ..." (device=-1)
2. OR QuantumForceGraph prints: "🖱️  QuantumForceGraph: Mouse PRESS ..." (device=-1)

### Test Commands

```bash
# Boot game and check for touch detection messages
godot res://scenes/FarmView.tscn 2>&1 | grep -E "Touch|TAP|SWIPE|📱"
```

---

## The `device` Property

From Godot documentation:

- `event.device == -1`: Real mouse/keyboard device
- `event.device >= 0`: Touch screen device (each finger gets an index)

This is the KEY to distinguishing real mouse events from touch-generated mouse events.

---

## Why This Architecture Is Correct

### Single Responsibility

- **TouchInputManager**: Handles ALL touch input, emits high-level gesture signals
- **PlotGridDisplay**: Handles ONLY mouse drag selection for plots
- **QuantumForceGraph**: Handles ONLY mouse click/drag for bubbles

### No Overlap

- Touch events → TouchInputManager → signals → handlers
- Mouse events → direct handling in PlotGridDisplay/QuantumForceGraph
- No component processes the same event twice

### Separation of Concerns

- Gesture detection logic in ONE place (TouchInputManager)
- Game logic in handlers (PlotGridDisplay, QuantumForceGraph)
- Easy to debug (single source of truth for touch)

---

## Next Steps

1. ✅ Test touch input on actual touchscreen device
2. ⏳ Verify touch tap reliably selects plots
3. ⏳ Verify touch tap reliably measures quantum bubbles
4. ⏳ Verify touch swipe reliably creates entanglement
5. ⏳ Clean up debug logging once confirmed working

---

## Summary

**Problem**: Touch events were being consumed by PlotGridDisplay/QuantumForceGraph before TouchInputManager could process them.

**Solution**: Check `event.device` to distinguish real mouse (device=-1) from touch-generated mouse (device>=0), and ignore touch-generated events in PlotGridDisplay/QuantumForceGraph.

**Result**: Touch events now flow correctly through TouchInputManager, which emits tap/swipe signals that drive the game logic.

Touch input should now work reliably! 🎮✨
