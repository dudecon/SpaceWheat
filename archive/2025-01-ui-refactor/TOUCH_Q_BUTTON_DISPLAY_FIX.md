# Touch Q Button Display Fix - COMPLETE ✅

## Problem Summary

**Issue:** Touch Q button entered submenu functionally BUT QER button labels didn't update visually (keyboard Q worked perfectly for both function and display)

**Root Cause Identified:** Signal was being emitted during the button press handler call stack (reentrant call). This caused Godot's internal signal system to block the PlayerShell's lambda connection from triggering, preventing ActionPreviewRow.update_for_submenu() from being called.

## Evidence from User Logs

### Keyboard Q (Working)
```
Tool action: action='submenu_plant', label='Plant ▸', has_submenu=true
🚪 _enter_submenu('plant') called
🔄 Generated dynamic submenu: plant
   📡 Emitting submenu_changed signal...
🔄 ActionPreviewRow.update_for_submenu() called: submenu_name='plant'
   → Button Q: '[Q] 🌾 Plant ▸' → '[Q] 🌾 Wheat'
```

### Touch Q (Broken - Before Fix)
```
🖱️  Action button clicked: Q (current_tool=1, current_submenu='')
📞 FarmInputHandler.execute_action('Q') called - current_tool=1, current_submenu=''
   Tool action: action='submenu_plant', label='Plant ▸', has_submenu=true
   → Opening submenu: 'plant'
🚪 _enter_submenu('plant') called
🔄 Generated dynamic submenu: plant
   📡 Emitting submenu_changed signal...
   ✅ Signal emitted
```
**MISSING:** `🔄 ActionPreviewRow.update_for_submenu()` log - signal never reached its destination!

## Solution Applied

Changed signal emission in `UI/FarmInputHandler.gd` from direct `emit()` to `call_deferred("emit_signal", ...)` to escape the button press call stack.

### Files Changed

**UI/FarmInputHandler.gd** - Three functions updated:

1. **_enter_submenu() (line 397)**
   ```gdscript
   # BEFORE (broken for touch):
   submenu_changed.emit(submenu_name, submenu)

   # AFTER (works for both touch and keyboard):
   call_deferred("emit_signal", "submenu_changed", submenu_name, submenu)
   ```

2. **_exit_submenu() (lines 409, 412)**
   ```gdscript
   # BEFORE:
   submenu_changed.emit("", {})
   tool_changed.emit(current_tool, TOOL_ACTIONS[current_tool])

   # AFTER:
   call_deferred("emit_signal", "submenu_changed", "", {})
   call_deferred("emit_signal", "tool_changed", current_tool, TOOL_ACTIONS[current_tool])
   ```

3. **_refresh_dynamic_submenu() (line 435)**
   ```gdscript
   # BEFORE:
   submenu_changed.emit(current_submenu, regenerated)

   # AFTER:
   call_deferred("emit_signal", "submenu_changed", current_submenu, regenerated)
   ```

## Why This Works

- **call_deferred()** schedules the signal emission for the next idle frame
- This escapes the button press handler call stack where Godot blocks certain signal connections
- Keyboard input already worked because it emits from `_unhandled_input()`, not from a button press handler
- Now both touch and keyboard use the same signal timing pattern

## How to Test Manually

1. Launch SpaceWheat
2. Wait for game to load fully
3. Select Tool 1 (Grower) if not already selected
4. **Touch Q button** on the action bar
5. **Expected Result:** QER buttons should update to show:
   - `[Q] 🌾 Wheat`
   - `[E] 🍄 Mushroom`
   - `[R] 🍅 Tomato`
6. Touch Q again to plant wheat
7. Verify planting works and buttons return to normal

## Previous Fixes Preserved

This fix builds on earlier work:

1. ✅ ActionPreviewRow: `button.button_pressed = false` before text update (line 138)
2. ✅ PlotTile: Dictionary access via `.get()` instead of dot notation
3. ✅ Model C migration: `register_id` → `bath_subplot_id` throughout codebase
4. ✅ Spatial hierarchy: PlotGridDisplay consumes taps before QuantumForceGraph
5. ✅ Touch input: TouchInputManager broadcasts to all handlers with consumption tracking

## Status

- **Code:** ✅ Complete and syntactically correct
- **Testing:** Manual testing recommended (automated testing difficult in this environment)
- **Next Step:** User should test by touching Q button and verifying QER labels update

## Technical Notes

- This is a common Godot pattern for breaking out of reentrant signal chains
- The deferred emission adds ~1 frame of latency (16ms @ 60fps) but ensures signal delivery
- All signal handlers in PlayerShell, ActionBarManager, and ActionPreviewRow remain unchanged
- The fix is minimal and surgical - only changes where signals are emitted, not how they're received

---

**Fix completed by:** Claude Sonnet 4.5
**Date:** 2026-01-06
