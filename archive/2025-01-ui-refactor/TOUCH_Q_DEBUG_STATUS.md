# Touch Q Button Debug Status

## Problem

Touch Q button enters submenu functionally BUT QER button labels don't update visually.
Keyboard Q works perfectly for both function and display.

## Investigation History

### Attempt 1: Force button_pressed = false
**File:** UI/Panels/ActionPreviewRow.gd line 138
**Change:** Added `button.button_pressed = false` before text update
**Result:** ❌ No effect

### Attempt 2: call_deferred() signal emission
**Files:** UI/FarmInputHandler.gd lines 412, 424, 461
**Change:** Changed `emit()` to `call_deferred("emit_signal", ...)`
**Theory:** Escape button press call stack to allow signal delivery
**Result:** ❌ Keyboard worked, touch didn't - deferred signal never delivered!

### Attempt 3: Revert to direct emission + diagnostic logging
**Files:**
- UI/FarmInputHandler.gd - Reverted to direct `emit()`
- UI/PlayerShell.gd line 324 - Added logging to lambda

**Status:** 🔍 Waiting for user test results

## Key Evidence from Logs

### Keyboard Q (WORKS) - player_logs_01-07-07-15.txt lines 59-78
```
69: 📡 Emitting submenu_changed signal (deferred)...
70: ✅ Signal emission scheduled
72: 📋 ActionBarManager.update_for_submenu('plant') called
74: 🔄 ActionPreviewRow.update_for_submenu() called
75:    → Button Q: '[Q] 🌾 Plant ▸' → '[Q] 🌾 Wheat'
```
Signal chain complete!

### Touch Q (BROKEN) - player_logs_01-07-07-15.txt lines 205-220
```
216: 📡 Emitting submenu_changed signal (deferred)...
217: ✅ Signal emission scheduled
218: After _execute_tool_action: current_submenu='plant'
219: After execute_action: current_submenu='plant'
220: ⚡ Action Q pressed: Plant ▸
```
**MISSING:** Lines 72-78! No ActionBarManager or ActionPreviewRow logs!

## Signal Chain

1. **ActionPreviewRow._on_action_button_pressed()** → action_pressed.emit()
2. **PlayerShell._on_action_pressed_from_bar()** → forwards to FarmUI
3. **FarmUI._on_action_pressed()** → input_handler.execute_action()
4. **FarmInputHandler.execute_action()** → _execute_tool_action() → _enter_submenu()
5. **FarmInputHandler._enter_submenu()** → submenu_changed.emit()
6. **PlayerShell lambda (line 323-329)** → SHOULD receive signal
7. **ActionBarManager.update_for_submenu()** → SHOULD be called
8. **ActionPreviewRow.update_for_submenu()** → SHOULD update buttons

**BREAK POINT:** Step 6 - PlayerShell lambda is NOT being invoked for touch input!

## Current Hypothesis

The signal is being emitted (`📡 Emitting submenu_changed signal...` log appears) but the PlayerShell lambda connection is not receiving it for touch input.

Possible causes:
1. **Signal connection is broken/invalid** - But why would keyboard work?
2. **Godot bug** - Button.pressed handler chains block signal delivery differently than keyboard input
3. **Timing issue** - Signal emits but lambda hasn't been connected yet (unlikely - keyboard works)
4. **Context issue** - Something about the execution context prevents the lambda from being invoked

## Next Steps

Need user to test with diagnostic logging to confirm if:
- `📂 Submenu entered:` log appears for touch input (if not, lambda isn't being called)
- If lambda is called but ActionBarManager isn't, then action_bar_manager is null
- If ActionBarManager is called but ActionPreviewRow doesn't update, the problem is in ActionPreviewRow

## Files Modified

1. `UI/FarmInputHandler.gd` - Reverted deferred emissions to direct (lines 412, 424, 461)
2. `UI/PlayerShell.gd` - Added lambda diagnostic logging (line 324)
3. `UI/Panels/ActionPreviewRow.gd` - Has button.button_pressed = false fix (line 138)

## Waiting On

User test with diagnostic logs saved to `llm_inbox/player_logs/player_logs_diagnostic.txt`
