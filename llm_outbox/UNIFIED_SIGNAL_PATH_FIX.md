# Unified Signal Path Fix - Touch and Keyboard ✅

## Problem Identified

You were correct! I had created **duplicate signal paths** instead of making touch and keyboard converge at the same point.

**Old Architecture (WRONG):**
```
Keyboard: _unhandled_input() → _execute_tool_action("Q")

Touch:    Button.pressed
          → ActionPreviewRow.action_pressed signal
          → PlayerShell._on_action_pressed_from_bar()
          → FarmUI._on_action_pressed()
          → (deferred) input_handler.execute_action()
          → _execute_tool_action("Q")
```

Touch went through **4 extra hops** before reaching the same destination!

## Solution: Unified Signal Path

**New Architecture (CORRECT):**
```
Keyboard: _unhandled_input() → _execute_tool_action("Q")

Touch:    Button.pressed
          → ActionPreviewRow.action_pressed signal
          → _execute_tool_action("Q")    ← SAME ENTRY POINT!
```

Now they **converge immediately** at FarmInputHandler!

## Files Changed

### 1. UI/PlayerShell.gd

**Line 190-191:** Removed old connection
```gdscript
# OLD (removed):
# action_preview_row.action_pressed.connect(_on_action_pressed_from_bar)

# NEW:
# Connect action button signal - will be connected to FarmInputHandler later
# (after farm setup completes and input_handler is available)
```

**Line 330-336:** Added direct connection
```gdscript
# CRITICAL: Connect ActionPreviewRow directly to FarmInputHandler
# This makes touch and keyboard share the same code path
if action_bar_manager:
    var action_row = action_bar_manager.get_action_row()
    if action_row and action_row.has_signal("action_pressed"):
        action_row.action_pressed.connect(farm_ui.input_handler._execute_tool_action)
        print("   ✔ ActionPreviewRow → FarmInputHandler (direct connection)")
```

**Line 408-415:** Marked old handler as unused
```gdscript
func _on_action_pressed_from_bar(action_key: String) -> void:
    """NOTE: This method is now UNUSED"""
    push_warning("PlayerShell._on_action_pressed_from_bar() called but ActionPreviewRow should connect directly to FarmInputHandler!")
```

### 2. UI/FarmUI.gd

**Line 160-167:** Marked old handler as unused
```gdscript
func _on_action_pressed(action_key: String) -> void:
    """NOTE: This method is now UNUSED - ActionPreviewRow connects directly to
    FarmInputHandler._execute_tool_action() to share the same code path as keyboard.
    """
    push_warning("FarmUI._on_action_pressed() called but ActionPreviewRow should connect directly to FarmInputHandler!")
```

### 3. UI/FarmInputHandler.gd

**Line 644:** Added diagnostic logging
```gdscript
func _execute_tool_action(action_key: String):
    """Called by BOTH keyboard (_unhandled_input) and touch (ActionPreviewRow signal)"""
    print("⚡ _execute_tool_action('%s') - tool=%d, submenu='%s'" % [action_key, current_tool, current_submenu])
```

## How It Works Now

1. **ActionPreviewRow.action_pressed** signal fires when Q button is touched
2. Signal goes **directly** to **FarmInputHandler._execute_tool_action()**
3. **Same code path** as keyboard input!
4. _execute_tool_action() calls _enter_submenu()
5. _enter_submenu() emits submenu_changed
6. PlayerShell lambda receives signal ✅
7. ActionBarManager updates ✅
8. ActionPreviewRow updates buttons ✅

## Expected Log Sequence

For **both keyboard and touch**:

```
⚡ _execute_tool_action('Q') - tool=1, submenu=''
   Tool action: action='submenu_plant', label='Plant ▸', has_submenu=true
   → Opening submenu: 'plant'
🚪 _enter_submenu('plant') called
🔄 Generated dynamic submenu: plant
📂 Entered submenu: BioticFlux Crops
   📡 Emitting submenu_changed signal...
   ✅ Signal emitted
📂 Submenu entered: BioticFlux Crops     ← PlayerShell lambda
📋 ActionBarManager.update_for_submenu   ← ActionBarManager
🔄 ActionPreviewRow.update_for_submenu   ← ActionPreviewRow
   → Button Q: '[Q] 🌾 Plant ▸' → '[Q] 🌾 Wheat'
```

## Why Previous Attempts Failed

1. **Attempt 1:** `button.button_pressed = false` - Wrong layer, didn't address routing
2. **Attempt 2:** `call_deferred("emit_signal", ...)` - Still in button chain when scheduled
3. **Attempt 3:** `call_deferred("execute_action", ...)` - Added a workaround instead of fixing architecture

**Root Issue:** Touch was going through a completely different code path with extra intermediaries (PlayerShell → FarmUI) that keyboard didn't use.

## Testing

Run the game and:

1. **Touch a plot** to select it
2. **Touch Q button** on action bar
3. **Expected:** QER buttons update to show plant options immediately
4. **Touch Q again** to plant
5. **Repeat** 5-7 times

**Look for this log:**
```
✔ ActionPreviewRow → FarmInputHandler (direct connection)
```

This confirms the unified path is connected.

## Benefits

1. ✅ **Single code path** - easier to maintain
2. ✅ **No signal chain issues** - no nested Button.pressed handlers
3. ✅ **Same behavior** - keyboard and touch are now identical
4. ✅ **Cleaner architecture** - removed unnecessary intermediaries

---

**Fix completed by:** Claude Sonnet 4.5
**Date:** 2026-01-07
**Key insight:** Make touch and keyboard converge at the same entry point (FarmInputHandler), don't route them through different intermediaries!
