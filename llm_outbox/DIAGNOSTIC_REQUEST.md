# Diagnostic Request - Touch Q Button

## Problem Status

The touch Q button still doesn't update the display even after reverting to direct signal emission (which works for keyboard).

## Changes Made

1. **Reverted FarmInputHandler.gd** - Changed back from `call_deferred()` to direct `emit()`:
   - Line 412: `submenu_changed.emit(submenu_name, submenu)`
   - Line 424: `submenu_changed.emit("", {})`
   - Line 461: `submenu_changed.emit(current_submenu, regenerated)`

2. **Added Diagnostic Logging to PlayerShell.gd** - Line 324:
   ```gdscript
   farm_ui.input_handler.submenu_changed.connect(func(name: String, info: Dictionary):
       print("📂 Submenu entered: %s" % (info.get("name", name) if info else name))
       if action_bar_manager:
           action_bar_manager.update_for_submenu(name, info)
       else:
           print("   ⚠️ action_bar_manager is NULL!")
   )
   ```

## Test Request

Please run the game and:

1. **Test Keyboard Q** (for baseline):
   - Press `1` to select Grower tool
   - Press `Q` key
   - Look for these log lines in sequence:
     ```
     📡 Emitting submenu_changed signal...
     ✅ Signal emitted
     📂 Submenu entered: [submenu name]
     📋 ActionBarManager.update_for_submenu() called
     🔄 ActionPreviewRow.update_for_submenu() called
     ```

2. **Test Touch Q**:
   - Touch the Q button on screen
   - Look for the SAME sequence of logs
   - **Key question:** Does `📂 Submenu entered:` appear for touch?

## Critical Diagnostic

The missing piece is whether the PlayerShell lambda (line 323-329) is being invoked at all when the signal is emitted from touch input.

**If the lambda IS called:** The problem is in ActionBarManager or ActionPreviewRow
**If the lambda is NOT called:** The problem is with signal delivery or connection

## Current Hypothesis

I suspect the lambda is NOT being called for touch input, which means:
- Either the signal isn't actually being emitted (contradicts logs)
- Or the signal connection is somehow invalid/broken for the button press context
- Or there's a Godot bug with signal delivery during Button.pressed handler chains

Please save logs to `llm_inbox/player_logs/player_logs_diagnostic.txt` with both keyboard and touch tests.
