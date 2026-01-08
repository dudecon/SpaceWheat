# Touch Q Button Issue - Investigation Findings
**Date:** 2026-01-06

## Test Results from Game Session

### Keyboard Q - WORKS ✅
```
   Tool action: action='submenu_plant', label='Plant ▸', has_submenu=true
🚪 _enter_submenu('plant') called
🔄 Generated dynamic submenu: plant
📂 Entered submenu: Plant Type
   Q = Wheat
   E = Mushroom
   R = Tomato
   📡 Emitting submenu_changed signal...
📂 Submenu entered: Plant Type  ← FarmUI receives signal
🔄 ActionPreviewRow.update_for_submenu() called: submenu_name='plant'  ← Buttons update!
   → Button Q: '[Q] 🌾 Plant ▸' → '[Q] 🌾 Wheat'
   → Button E: '[E] 🔗 Entangle (Bell φ+)' → '[E] 🍄 Mushroom'
   → Button R: '[R] ✂️ Measure + Harvest' → '[R] 🍅 Tomato'
```

### Touch Q - DOESN'T WORK ❌
```
🖱️  Action button clicked: Q (current_tool=1, current_submenu='')
📞 FarmInputHandler.execute_action('Q') called - current_tool=1, current_submenu=''
   Tool action: action='submenu_plant', label='Plant ▸', has_submenu=true
   → Opening submenu: 'plant'
🚪 _enter_submenu('plant') called
🔄 Generated dynamic submenu: plant
📂 Entered submenu: Plant Type
   Q = Wheat
   E = Mushroom
   R = Tomato
   📡 Emitting submenu_changed signal...
   ✅ Signal emitted
   After _execute_tool_action: current_submenu='plant'
   After execute_action: current_submenu='plant'
⚡ Action Q pressed: Plant ▸  ← Button handler returns

NO "🔄 ActionPreviewRow.update_for_submenu()" log! ← Buttons DON'T update!
```

## Key Finding

**Signal IS emitted** but **ActionPreviewRow does NOT receive it** when triggered by touch!

## Hypothesis

The signal connection chain:
```
FarmInputHandler.submenu_changed signal
  ↓
PlayerShell lambda handler (line 323)
  ↓
ActionBarManager.update_for_submenu()
  ↓
ActionPreviewRow.update_for_submenu()
```

Something in this chain breaks ONLY for touch input, not keyboard.

## Added Logging

Added print statement to ActionBarManager.update_for_submenu() to see if it's being called.

Next test will show:
- **If we see "📋 ActionBarManager.update_for_submenu"** → Problem is between ActionBarManager and ActionPreviewRow
- **If we DON'T see that log** → Signal isn't reaching ActionBarManager (connection issue in PlayerShell)

## Possible Root Causes

### Theory A: Timing/Order Issue
Touch button press happens during signal emission, causing reentrant call or signal queue corruption.

### Theory B: Signal Connection Not Established
PlayerShell's signal connection (line 323) might not be set up correctly when FarmUI is created via touch path vs keyboard path.

### Theory C: Signal Blocked by Button State
Button being in "pressed" state somehow blocks signal processing (though this seems unlikely).

## Next Test

Run game again with new ActionBarManager logging and check:
1. Press "1" key
2. Tap Q button (touch)
3. Look for "📋 ActionBarManager.update_for_submenu" in logs
4. If missing → signal connection broken
5. If present but no ActionPreviewRow update → forwarding broken

## Resolution Path

Once we identify which link in the chain is broken, we can fix it directly instead of working around it.
