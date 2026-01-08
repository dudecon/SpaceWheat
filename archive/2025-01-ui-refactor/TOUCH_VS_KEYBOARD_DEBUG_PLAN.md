# Touch vs Keyboard Divergence - Debug Plan
**Date:** 2026-01-06

## Current Status

**Working:**
- ✅ Planting works
- ✅ Bubble taps measure
- ✅ Measured bubble taps harvest
- ✅ Keyboard Q triggers submenu (QER button labels update)

**Broken:**
- ❌ Touch Q press doesn't trigger submenu (QER labels don't update)

## Debug Logging Added

Added trace logging at every step of the signal chain:

### Touch Path
```
1. Button.pressed signal
2. ActionPreviewRow._on_action_button_pressed("Q")
3. ActionPreviewRow.action_pressed.emit("Q")
4. PlayerShell receives signal → forwards to FarmUI
5. FarmUI._on_action_pressed("Q") [LOGGED]
   → "🖱️  Action button clicked: Q (current_tool=X, current_submenu='')"
6. FarmInputHandler.execute_action("Q") [LOGGED]
   → "📞 FarmInputHandler.execute_action('Q') called - current_tool=X, current_submenu=''"
7. FarmInputHandler._execute_tool_action("Q")
   → "Tool action: action='X', label='X', has_submenu=true/false"
8. If has submenu: _enter_submenu() [LOGGED]
   → "🚪 _enter_submenu('plant') called"
   → "📂 Entered submenu: Plant Crops"
   → "📡 Emitting submenu_changed signal..."
   → "✅ Signal emitted"
9. PlayerShell receives submenu_changed → ActionBarManager
10. ActionPreviewRow.update_for_submenu() [LOGGED]
    → "🔄 ActionPreviewRow.update_for_submenu() called: submenu_name='plant'"
    → "Button Q: '[Q] 🔨 Plant' → '[Q] 🌾 Wheat'"
```

### Keyboard Path
```
1. FarmInputHandler._unhandled_input() detects KEY_Q
2. FarmInputHandler._execute_tool_action("Q")
   [Same as touch path from step 7 onward]
```

## Test Instructions

**Test both paths and compare console output:**

### Test 1: Keyboard Q (WORKING)
```
1. Select Tool 1 (press "1" key)
2. Press Q key
3. Watch console for logging chain
4. Expected: Full chain executes, buttons update
```

### Test 2: Touch Q (BROKEN)
```
1. Select Tool 1 (tap "1" button)
2. Tap Q button
3. Watch console for logging chain
4. Expected: Should show same chain as keyboard, but something breaks
```

## What to Look For

Compare the two log outputs to find where they diverge:

### Possible Issues

**Issue A: Signal Never Reaches FarmInputHandler**
If you see:
- ✅ "🖱️  Action button clicked: Q"
- ❌ No "📞 FarmInputHandler.execute_action"

Then: Signal routing broken between FarmUI and FarmInputHandler

**Issue B: Action Doesn't Have Submenu Field**
If you see:
- ✅ "📞 FarmInputHandler.execute_action"
- ✅ "Tool action: action='X', label='X', has_submenu=false"

Then: ToolConfig not configured correctly for touch vs keyboard

**Issue C: Submenu Not Entered**
If you see:
- ✅ "has_submenu=true"
- ❌ No "🚪 _enter_submenu"

Then: Logic error in _execute_tool_action()

**Issue D: Signal Not Emitted**
If you see:
- ✅ "🚪 _enter_submenu"
- ✅ "📡 Emitting submenu_changed signal..."
- ❌ No "🔄 ActionPreviewRow.update_for_submenu()"

Then: Signal connection broken between FarmInputHandler and ActionBarManager

**Issue E: Signal Emitted But UI Not Updated**
If you see:
- ✅ "🔄 ActionPreviewRow.update_for_submenu()"
- ✅ "Button Q: '[Q] X' → '[Q] Y'"
- ❌ Buttons don't visually update

Then: Button rendering issue (original Phase 1 problem)

## Expected Output (Working Path)

```
🖱️  Action button clicked: Q (current_tool=1, current_submenu='')
📞 FarmInputHandler.execute_action('Q') called - current_tool=1, current_submenu=''
   Tool action: action='plant', label='Plant', has_submenu=true
   → Opening submenu: 'plant'
🚪 _enter_submenu('plant') called
📂 Entered submenu: Plant Crops
   Q = Wheat
   E = Mushroom
   R = Tomato
   📡 Emitting submenu_changed signal...
   ✅ Signal emitted
   After _execute_tool_action: current_submenu='plant'
   After execute_action: current_submenu='plant'
🔄 ActionPreviewRow.update_for_submenu() called: submenu_name='plant'
   → Button Q: '[Q] 🔨 Plant' → '[Q] 🌾 Wheat'
   → Button E: '[E] ⚗️ Craft' → '[E] 🍄 Mushroom'
   → Button R: '[R] ✂️ Harvest' → '[R] 🍅 Tomato'
📂 ActionPreviewRow showing submenu: Plant Crops
```

## Next Steps

1. **Run both tests** and copy console output
2. **Compare logs** to find divergence point
3. **Fix the specific break** in signal chain
4. **Verify fix** with both keyboard and touch

The debug logging will show us exactly where touch and keyboard paths diverge!
