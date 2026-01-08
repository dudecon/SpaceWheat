# Touch Input Debug Test

**Purpose**: Determine if TouchInputManager is receiving touch events when tapping the play area

---

## How to Test

1. **Run the game normally** (not headless):
   ```bash
   godot res://scenes/FarmView.tscn
   ```

2. **Watch the console output**

3. **Tap in different areas**:
   - Tap a tool button (1-6)
   - Tap an action button (Q, E, or R)
   - Tap the play area (where plots/bubbles are)
   - Tap a plot tile
   - Tap a quantum bubble

---

## What to Look For

### If TouchInputManager IS Receiving Touch Events

You'll see this EVERY time you tap:
```
================================================================================
🔵 TouchManager._input: InputEventScreenTouch received!
   pressed=true, position=(X, Y), index=0
================================================================================
👆 TouchManager: Touch started at (X, Y)
```

And when you release:
```
================================================================================
🔵 TouchManager._input: InputEventScreenTouch received!
   pressed=false, position=(X, Y), index=0
================================================================================
👆 TouchManager: TAP detected at (X, Y) (moved 0.0px in 0.123s)
```

### If TouchInputManager IS NOT Receiving Touch Events

You'll see:
- Touch-generated mouse event messages from PlotGridDisplay/QuantumForceGraph
- But NO "InputEventScreenTouch received!" banners
- This means something is consuming the touch event before TouchInputManager sees it

### If Buttons Work But Play Area Doesn't

**Tap a button** → See InputEventScreenTouch banner ✅
**Tap play area** → See NO InputEventScreenTouch banner ❌

This means something over the play area is blocking touch events.

---

## Common Messages and What They Mean

### Message: "TouchManager._input: InputEventMouseButton - device=0"
**Meaning**: TouchInputManager seeing touch-generated mouse event
**Good/Bad**: Neither - this is normal, but we care about InputEventScreenTouch

### Message: "PlotGridDisplay._input: Touch-generated mouse event (device=0)"
**Meaning**: PlotGridDisplay correctly identified and ignored touch-generated mouse event
**Good/Bad**: Good - means our device check is working

### Message: "QuantumForceGraph: Touch-generated mouse event (device=0)"
**Meaning**: QuantumForceGraph correctly identified and ignored touch-generated mouse event
**Good/Bad**: Good - means our device check is working

### NO "InputEventScreenTouch received!" banner
**Meaning**: TouchInputManager never received the original touch event
**Good/Bad**: BAD - something is consuming it before TouchInputManager sees it

---

## Test Results to Report

Please report:

1. **When tapping a button (works)**:
   - [ ] Do you see InputEventScreenTouch banner?
   - [ ] Do you see TouchManager TAP detected?
   - [ ] Does the button respond?

2. **When tapping the play area (doesn't work)**:
   - [ ] Do you see InputEventScreenTouch banner?
   - [ ] Do you see TouchManager TAP detected?
   - [ ] Do you see "Touch-generated mouse event" messages?
   - [ ] Does anything happen?

3. **When tapping a plot tile**:
   - [ ] Do you see InputEventScreenTouch banner?
   - [ ] Do you see "📱 Plot selected via touch tap"?
   - [ ] Does the plot selection change?

4. **When tapping a quantum bubble**:
   - [ ] Do you see InputEventScreenTouch banner?
   - [ ] Do you see "📱 Bubble tapped"?
   - [ ] Does the bubble collapse/measure?

---

## Possible Results

### Scenario A: TouchInputManager receives events but handlers don't work
**Symptom**: You see InputEventScreenTouch banners everywhere
**Meaning**: TouchInputManager is working, but signal connections broken
**Fix**: Check signal connections in PlotGridDisplay._ready() and QuantumForceGraph._ready()

### Scenario B: TouchInputManager receives events on buttons but NOT play area
**Symptom**: InputEventScreenTouch banner appears when tapping buttons, but NOT when tapping play area
**Meaning**: Something over the play area is consuming touch events
**Fix**: Find the node blocking touch and set its mouse_filter to IGNORE

### Scenario C: TouchInputManager never receives any touch events
**Symptom**: No InputEventScreenTouch banners anywhere
**Meaning**: Touch events are being consumed before TouchInputManager (autoload) processes them
**Fix**: Find what's consuming touch events in scene tree _input() handlers

---

## Quick Terminal Test (Alternative)

If you can't watch the console while touching:

```bash
# Run game in background, redirect output to file
godot res://scenes/FarmView.tscn 2>&1 > /tmp/touch_test.log &

# Let it run for a bit, tap around
# Then kill it and check the log
pkill godot

# Search for touch events
grep "InputEventScreenTouch" /tmp/touch_test.log
grep "TAP detected" /tmp/touch_test.log
grep "Plot selected" /tmp/touch_test.log
grep "Bubble tapped" /tmp/touch_test.log
```

---

## Next Steps Based on Results

**If banners appear everywhere**: Signal connections issue
**If banners only on buttons**: Play area blocking touch
**If no banners anywhere**: Something consuming all touch before TouchInputManager

Let me know what you see!
