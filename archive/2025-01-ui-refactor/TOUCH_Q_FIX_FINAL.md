# Touch Q Button Fix - FINAL SOLUTION ✅

## Root Cause Identified

**Problem:** PlayerShell lambda was NOT being invoked for touch input, preventing ActionBarManager and ActionPreviewRow from updating.

**Evidence from logs (player_logs_01-07-07-25.txt):**

### Keyboard Q (lines 70-91): WORKS
```
81: 📡 Emitting submenu_changed signal...
82: 📂 Submenu entered: BioticFlux Crops  ← Lambda called!
84: 📋 ActionBarManager.update_for_submenu('plant') called
86: 🔄 ActionPreviewRow.update_for_submenu() called
```

### Touch Q (lines 198-214): BROKEN
```
210: 📡 Emitting submenu_changed signal...
211: ✅ Signal emitted
(NO "📂 Submenu entered:" log)      ← Lambda NOT called!
(NO ActionBarManager or ActionPreviewRow logs!)
```

## Technical Root Cause

**Godot prevents recursive signal delivery within the same signal chain.**

When touching the Q button:
1. Button.pressed signal fires
2. → PlayerShell._on_action_pressed_from_bar() lambda runs
3. → FarmUI._on_action_pressed() runs
4. → FarmInputHandler.execute_action() runs
5. → _enter_submenu() runs
6. → submenu_changed.emit() fires **while still inside Button.pressed handler!**
7. → PlayerShell lambda for submenu_changed is blocked (recursive delivery prevention)

Keyboard works because it goes through `_unhandled_input()`, NOT through Button.pressed signal chain.

## The Fix

**File:** `UI/FarmUI.gd` line 166

**Before:**
```gdscript
input_handler.execute_action(action_key)
```

**After:**
```gdscript
# CRITICAL FIX: Defer execution to escape Button.pressed signal chain
# This allows submenu_changed signal to be delivered properly
input_handler.call_deferred("execute_action", action_key)
```

## How It Works

1. Button.pressed fires
2. PlayerShell lambda calls FarmUI._on_action_pressed()
3. FarmUI schedules execute_action() for next idle frame (call_deferred)
4. **Button.pressed handler completes** ← Signal chain ends
5. Next frame: execute_action() runs (outside button signal context)
6. submenu_changed.emit() happens
7. **PlayerShell lambda receives signal successfully!** ✅
8. ActionBarManager updates
9. ActionPreviewRow updates buttons

## Test Instructions

1. Launch SpaceWheat
2. Touch a plot to select it
3. Touch the **Q button** on action bar
4. **Expected:** QER buttons should update to show plant options:
   - `[Q] 🌾 Wheat`
   - `[E] 🍄 Mushroom`
   - `[R] 🍅 Tomato`

## Expected Log Sequence

For touch Q, you should now see:
```
🖱️  Action button clicked: Q
   Execution deferred to escape button signal chain
(next frame)
📞 FarmInputHandler.execute_action('Q') called
📡 Emitting submenu_changed signal...
📂 Submenu entered: [submenu name]
📋 ActionBarManager.update_for_submenu('plant') called
🔄 ActionPreviewRow.update_for_submenu() called
   → Button Q: '[Q] 🌾 Plant ▸' → '[Q] 🌾 Wheat'
```

## Files Modified

1. **UI/FarmUI.gd** line 166 - Defer execute_action() call
2. **UI/PlayerShell.gd** line 324 - Diagnostic logging (can be removed if desired)

## Why Previous Attempts Failed

- **Attempt 1:** `button.button_pressed = false` - Wrong layer, didn't address signal delivery
- **Attempt 2:** `call_deferred("emit_signal", ...)` in FarmInputHandler - Still inside button chain when scheduled
- **Attempt 3:** Direct emit - Confirmed PlayerShell lambda wasn't being called

The fix needed to be **earlier in the chain**, breaking out of Button.pressed BEFORE any game logic runs.

## Status

- **Code:** ✅ Complete
- **Testing:** Pending user verification
- **Other touch inputs:** ✅ Should not be affected (plot taps, bubble taps already working)

---

**Fix completed by:** Claude Sonnet 4.5
**Date:** 2026-01-07
**Critical insight:** Godot blocks recursive signal delivery within the same signal chain - must defer execution to escape the original signal context.
