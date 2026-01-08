# Touch Input Debug Instructions

## What to Test

I've added debug logging to TouchInputManager to see exactly what's happening when you touch the screen.

## How to Test

1. **Start the game** (on your touch device or with touch simulation)
2. **Touch different areas** and watch the console

### Test Sequence

**Test A: Touch on tool buttons (we know this works)**
- Touch one of the tool selection buttons at the bottom
- **Expected**: Should see both:
  ```
  🔍 TouchInputManager._input() received InputEventScreenTouch: pressed=true, position=...
  🔍 TouchInputManager._input() received InputEventScreenTouch: pressed=false, position=...
  ```

**Test B: Touch on plot tile (user reports this doesn't work)**
- Touch a plot tile in the bottom grid
- **Question**: Do you see the TouchInputManager logs?

**Test C: Touch on bubble (user reports this doesn't work)**
- Touch a quantum bubble in the visualization area
- **Question**: Do you see the TouchInputManager logs?

## What the Logs Tell Us

### Scenario 1: TouchInputManager DOES receive events
```
🔍 TouchInputManager._input() received InputEventScreenTouch: pressed=true, position=(X, Y)
👆 TouchManager: Touch started at (X, Y)
🔍 TouchInputManager._input() received InputEventScreenTouch: pressed=false, position=(X, Y)
👆 TouchManager: TAP detected at (X, Y)
```

If you see this, TouchInputManager is working. The problem is downstream (signal not reaching handlers).

### Scenario 2: TouchInputManager does NOT receive events
```
(nothing - no logs from TouchInputManager)
```

If you DON'T see the TouchInputManager logs, something is consuming the InputEventScreenTouch events BEFORE TouchInputManager gets them.

### Scenario 3: Only seeing mouse events
```
🔍 TouchInputManager._input() received touch-generated mouse event (ignoring): device=0, pressed=true
```

If you ONLY see mouse event logs (no InputEventScreenTouch logs), then Godot isn't generating touch events properly, or something is converting them to mouse events before TouchInputManager sees them.

## What to Report

Please test touching:
1. Tool button (bottom area)
2. Plot tile (bottom grid)
3. Bubble (upper visualization)

For each, tell me:
- Do you see "🔍 TouchInputManager._input() received InputEventScreenTouch" logs?
- Do you see "👆 TouchManager: Touch started" logs?
- Do you see "👆 TouchManager: TAP detected" logs?

## Next Steps Based on Results

### If TouchInputManager receives events for buttons but NOT for plots/bubbles:
→ Something in the scene structure is consuming touch events selectively

### If TouchInputManager doesn't receive ANY touch events (only mouse events):
→ Input configuration issue or something is converting touches to mouse before autoloads see them

### If TouchInputManager receives ALL touch events but plot/bubble handlers don't fire:
→ Signal connection issue between TouchInputManager and the handlers
