# Touch Code Cleanup & Simplified Plan - Summary

**Date**: 2026-01-06
**Status**: ✅ Cleanup complete, simplified plan ready

---

## What Was Done

### 1. Audited All Touch Code ✅
**Document**: `/home/tehcr33d/ws/SpaceWheat/llm_outbox/TOUCH_CODE_AUDIT.md`

**Found**:
- ❌ Broken Godot 3 API: `InputEventScreenDrag` (doesn't exist in Godot 4)
- ⚠️ Incomplete: Quantum bubble swipe (no motion tracking)
- ✅ Working: PanelTouchButton (uses `_gui_input()` correctly)

### 2. Removed Broken Code ✅

**UI/PlotGridDisplay.gd**:
- Removed lines 712-732 (broken `InputEventScreenDrag` handler)
- Added TODO with migration notes

**Core/Visualization/QuantumForceGraph.gd**:
- Added TODO about incomplete swipe detection
- Kept basic press/release code (partially works)

**UI/Panels/BiomeInspectorOverlay.gd**:
- Added TODO about gesture discrimination
- Kept simple tap-to-close

### 3. Created Simplified Implementation Plan ✅
**Document**: `/home/tehcr33d/.claude/plans/touch_simplified.md`

---

## Simplified Scope (Per Your Feedback)

### What We're Implementing ✅
1. **Tap plots to select** (simple tap, no drag)
2. **Tap quantum bubbles to measure**
3. **Swipe between bubbles to entangle**
4. **Tool buttons (1-6) respond to touch** (debug why they don't work)
5. **Action buttons (Q/E/R) respond to touch** (debug why they don't work)

### What We're NOT Implementing ❌
- ❌ Long-press context menus (not needed)
- ❌ Pinch-to-zoom (no zoom in game)
- ❌ Drag selection for plots (just single tap)
- ❌ Multi-touch gestures (not needed)

---

## Implementation Plan (Simplified)

### **Phase 1: TouchInputManager** (3-4 hours)
Create minimal touch manager with just tap and swipe detection.

**File**: `UI/Input/TouchInputManager.gd`

```gdscript
class_name TouchInputManager
extends Node

# Simple gestures only
const TAP_MAX_DURATION: float = 0.3
const TAP_MAX_MOVEMENT: float = 10.0
const SWIPE_MIN_DISTANCE: float = 30.0

signal tap_detected(position: Vector2)
signal swipe_detected(start_pos: Vector2, end_pos: Vector2, direction: Vector2)

# Single touch tracking
var touch_start_pos: Vector2
var touch_start_time: float
var is_touching: bool = false
```

### **Phase 2: Plot Touch Selection** (2-3 hours)
Connect PlotGridDisplay to tap signals.

**File**: `UI/PlotGridDisplay.gd`

```gdscript
func _ready():
    TouchInputManager.tap_detected.connect(_on_touch_tap)

func _on_touch_tap(position: Vector2):
    var plot_pos = _get_plot_at_screen_position(position)
    if plot_pos != Vector2i(-1, -1):
        select_plot(plot_pos)  # Single plot selection
```

### **Phase 3: Quantum Bubble Touch** (3-4 hours)
Fix swipe detection for entanglement.

**File**: `Core/Visualization/QuantumForceGraph.gd`

```gdscript
func _ready():
    TouchInputManager.tap_detected.connect(_on_bubble_tap)
    TouchInputManager.swipe_detected.connect(_on_bubble_swipe)

func _on_bubble_tap(position: Vector2):
    var node = get_node_at_position(transform * position)
    if node:
        measure_quantum_node(node)

func _on_bubble_swipe(start_pos, end_pos, direction):
    var start_node = get_node_at_position(transform * start_pos)
    var end_node = get_node_at_position(transform * end_pos)
    if start_node and end_node:
        create_entanglement(start_node, end_node)
```

### **Phase 4: Debug Button Touch** (2-3 hours)
Figure out why tool/action buttons don't respond to touch.

**Investigation**: Tool and action buttons are `Button` nodes, which should automatically handle touch via `_gui_input()`. Godot converts touch → mouse events for UI Controls.

**Possible causes**:
1. Z-index blocking touches
2. Mouse filter settings
3. Touch events not reaching buttons

**Files to check**:
- `UI/Panels/ToolSelectionRow.gd` - has `mouse_filter = PASS` (correct)
- `UI/Panels/ActionPreviewRow.gd` - has `mouse_filter = PASS` (correct)
- `UI/PlayerShell.tscn` - ActionBarLayer settings

**Expected**: Buttons should already work, just need to test and debug.

---

## Total Implementation Time

| Phase | Feature | Time |
|-------|---------|------|
| 1 | TouchInputManager | 3-4h |
| 2 | Plot Selection | 2-3h |
| 3 | Quantum Bubbles | 3-4h |
| 4 | Debug Buttons | 2-3h |
| **Total** | | **10-14h** |

**Much simpler than original 40-55 hour plan!**

---

## Button Investigation Results

### Tool Selection Buttons (ToolSelectionRow)
**Code Analysis**:
- Uses `Button.new()` - ✅ Correct (Control node)
- Parent has `mouse_filter = MOUSE_FILTER_PASS` - ✅ Correct (lets keyboard through)
- Buttons have default `mouse_filter = MOUSE_FILTER_STOP` - ✅ Should catch events
- Size: Already touch-friendly per user
- Z-index: 3000 (set in _ready) - ✅ Above play area

**Expected**: Should already respond to touch
**Status**: Needs testing to confirm

### Action Buttons (ActionPreviewRow)
**Code Analysis**:
- Uses `Button.new()` - ✅ Correct (Control node)
- Parent has `mouse_filter = MOUSE_FILTER_PASS` - ✅ Correct
- Buttons have default `mouse_filter = MOUSE_FILTER_STOP` - ✅ Should catch events
- Size: Already touch-friendly per user
- Z-index: 4000 (set in _ready) - ✅ Above everything

**Expected**: Should already respond to touch
**Status**: Needs testing to confirm

### ActionBarLayer (Parent Container)
**Scene Settings** (PlayerShell.tscn):
- `mouse_filter = 0` (STOP) - ✅ Correct
- `z_index = 3000` - ✅ Correct
- Anchors: Proper Godot 4 syntax (fixed earlier)

**Expected**: Not blocking events
**Status**: Should be fine

---

## Key Finding

**Buttons SHOULD already work with touch!**

Godot 4 automatically converts `InputEventScreenTouch` → `InputEventMouseButton` for Control nodes. Since:
- Tool/action buttons are Button nodes (Control)
- They use default `_gui_input()` handling
- Mouse filter settings are correct
- Z-index is above other elements

**They should respond to touch identically to mouse clicks.**

**Next Step**: Test on actual touchscreen device to verify. If they don't work, debug with prints to see where events are being blocked.

---

## Testing Plan

### Phase 1 Test (TouchInputManager):
1. Add TouchInputManager as autoload
2. Add debug prints to tap/swipe signals
3. Touch screen → verify tap detected
4. Swipe screen → verify swipe detected

### Phase 2 Test (Plots):
1. Tap plot → verify selection
2. Tap different plot → verify selection changes
3. Visual feedback working

### Phase 3 Test (Bubbles):
1. Tap bubble → verify measure/collapse
2. Swipe bubble-to-bubble → verify entanglement
3. Swipe detection reliable

### Phase 4 Test (Buttons):
1. Tap tool button → verify tool switches
2. Tap action button → verify action executes
3. If not working: Add debug prints to find blocker

---

## Next Steps

**Option A - Start implementing** (recommended):
1. Create TouchInputManager skeleton
2. Implement Phase 1 (tap/swipe detection)
3. Test on touchscreen device
4. Continue to Phase 2-4

**Option B - Test buttons first**:
1. Test current buttons on touchscreen
2. If they work: Skip Phase 4, just do 1-3
3. If they don't work: Debug and fix first

**Recommendation**: Start with Phase 1 since it's needed regardless of button status.

---

## Files Modified Summary

### Cleanup (Already Done):
- ✅ UI/PlotGridDisplay.gd - Removed broken touch code
- ✅ Core/Visualization/QuantumForceGraph.gd - Added TODO
- ✅ UI/Panels/BiomeInspectorOverlay.gd - Added TODO

### To Create:
- UI/Input/TouchInputManager.gd - New touch gesture manager

### To Modify:
- UI/PlotGridDisplay.gd - Connect to touch signals
- Core/Visualization/QuantumForceGraph.gd - Connect to touch signals
- project.godot - Add TouchInputManager autoload

### To Debug:
- UI/Panels/ToolSelectionRow.gd - Test touch response
- UI/Panels/ActionPreviewRow.gd - Test touch response

---

## Success Criteria

✅ **Touch input feels natural**
- Tap responds quickly (<100ms)
- Swipe detection is reliable
- No false positives/negatives

✅ **All interactions work**
- Tap plot → selects
- Tap bubble → measures
- Swipe bubble → entangles
- Tap buttons → activates

✅ **Mouse/keyboard still work**
- No regression in existing functionality
- All three input methods coexist

✅ **Simple codebase**
- Minimal complexity (no unnecessary features)
- Easy to maintain and extend
- Clear separation of concerns

---

## Documents Created

1. **TOUCH_CODE_AUDIT.md** - What was broken and why
2. **touch_clean_slate.md** - Original comprehensive plan (40-55h)
3. **touch_simplified.md** - Simplified plan (10-14h) ← Use this one
4. **TOUCH_CLEANUP_SUMMARY.md** - This document

Ready to start implementation! 🎮
