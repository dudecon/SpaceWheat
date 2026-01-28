# Simulation Speed Controls

## Overview

Added keyboard controls to adjust quantum simulation speed in real-time:
- **`-` key:** Halve the simulation speed (slower)
- **`=` key:** Double the simulation speed (faster)

## How It Works

### Architecture
The speed control adjusts `quantum_time_scale` for all biomes simultaneously:
- **Physics updates:** Still at 10 Hz (no stutter)
- **Rendering:** Still at 30+ Hz (smooth visuals)
- **Simulated time:** Scales based on quantum_time_scale

### Speed Range
- **Minimum:** 0.001x (1/1000th speed) - ultra slow-mo for frame-by-frame observation
- **Default:** 0.5x (half speed) - smooth gameplay
- **Maximum:** 16.0x (16x speed) - extreme fast-forward mode

### How Doubling/Halving Works
```
Speed progression (each press):
0.001x → 0.002x → ... → 0.25x → 0.5x → 1.0x → 2.0x → 4.0x → 8.0x → 16.0x
  ^                           (default)                                  ^
  min                                                                   max
```

Press `-` to go left (slower), `=` to go right (faster).

---

## Implementation

### Files Modified
1. **`UI/Core/QuantumInstrumentInput.gd`**
   - Added key handling for `-` and `=`
   - Added `_decrease_simulation_speed()` function (min: 0.001x, max: 16.0x)
   - Added `_increase_simulation_speed()` function
   - Updated `_keycode_to_string()` to recognize KEY_MINUS and KEY_EQUAL
   - Updated documentation header
   - Updates GameStateManager.current_state after speed change

2. **`Core/Environment/BiomeBase.gd`** (previous fix)
   - Applied `quantum_time_scale` to actual_dt (line 237-239)

3. **`Core/GameState/GameState.gd`**
   - Added `@export var quantum_time_scale: float = 0.5`

4. **`Core/GameState/GameStateManager.gd`**
   - Captures speed in `capture_state_from_game()` (saves to disk)
   - Restores speed in `apply_state_to_game()` (loads from disk)

### Key Code
```gdscript
# In _unhandled_key_input():
if key == "-":
    _decrease_simulation_speed()
    get_viewport().set_input_as_handled()
    return
if key == "=":
    _increase_simulation_speed()
    get_viewport().set_input_as_handled()
    return
```

### Speed Functions
```gdscript
func _decrease_simulation_speed() -> void:
    """Halve the quantum simulation speed (- key)."""
    var current_speed = [get from first biome]
    var new_speed = max(current_speed * 0.5, 0.001)  # Min: 0.001x

    # Apply to all biomes
    for biome in farm.grid.biomes.values():
        biome.quantum_time_scale = new_speed

    # Update GameState for persistence
    var gsm = get_node_or_null("/root/GameStateManager")
    if gsm and gsm.current_state:
        gsm.current_state.quantum_time_scale = new_speed

func _increase_simulation_speed() -> void:
    """Double the quantum simulation speed (= key)."""
    var current_speed = [get from first biome]
    var new_speed = min(current_speed * 2.0, 16.0)  # Max: 16.0x

    # Apply to all biomes
    for biome in farm.grid.biomes.values():
        biome.quantum_time_scale = new_speed

    # Update GameState for persistence
    var gsm = get_node_or_null("/root/GameStateManager")
    if gsm and gsm.current_state:
        gsm.current_state.quantum_time_scale = new_speed
```

---

## Usage

### In-Game
1. **Boot the game** normally
2. **Press `-`** to slow down simulation (halves speed each press)
3. **Press `=`** to speed up simulation (doubles speed each press)
4. **Watch console** for speed change confirmation:
   ```
   [INFO][input] ⏬ Simulation speed: 0.5000x → 0.2500x (6 biomes)
   [INFO][input] ⏫ Simulation speed: 0.2500x → 0.5000x (6 biomes)
   ```

### Use Cases

**Learning Mode (0.0625x - 0.25x):**
- Observe quantum evolution in slow motion
- See coherence/decoherence dynamics unfold
- Study entanglement formation
- Debug quantum behavior

**Standard Play (0.5x - 1.0x):**
- Default gameplay experience
- Balanced pacing for strategic decisions
- Time to react to state changes

**Fast-Forward (2.0x - 4.0x):**
- Speed through early game grinding
- Test long-term evolution quickly
- Speedrun challenges

---

## Console Feedback

Speed changes log to console with emojis:
```
[INFO][input] ⏬ Simulation speed: 1.0000x → 0.5000x (6 biomes)
[INFO][input] ⏫ Simulation speed: 0.5000x → 1.0000x (6 biomes)
```

Shows:
- Direction: ⏬ (decrease) or ⏫ (increase)
- Old speed → New speed
- Number of biomes affected

---

## Technical Details

### Why Apply to All Biomes?
All biomes run on the same timeline for consistency:
- Synchronized evolution across farm
- Prevents time-travel paradoxes
- Maintains causal relationships (entanglement, etc.)

### Why Min/Max Limits?
- **Min (0.001x):** Below this, simulation effectively frozen (1ms per 1s real time)
- **Max (16.0x):** Above this, numerical stability issues + hard to observe state changes

### Performance Impact
**None!** Speed scaling only affects simulated time, not computation:
- 0.0625x: 6.25ms of simulation per 100ms real time
- 4.0x: 400ms of simulation per 100ms real time
- CPU usage same (10 updates/second regardless)

The quantum computer runs the same number of steps, just with different dt values.

---

## Examples

### Slow-Mo Observation
```
Start: 0.5x (default)
Press - many times: 0.5x → 0.25x → 0.125x → ... → 0.001x
Result: 1/1000th speed - watch superposition evolve frame-by-frame
```

### Fast Grinding
```
Start: 0.5x (default)
Press = four times: 0.5x → 1.0x → 2.0x → 4.0x → 8.0x → 16.0x
Result: 16x speed - harvest cycles complete 32x faster than default
```

### Fine Tuning
```
Too slow at 0.25x but too fast at 0.5x?
- Set to 0.25x
- Press = once: 0.25x → 0.5x
- Press - once: 0.5x → 0.25x
- Repeat until you find your sweet spot
```

---

## Troubleshooting

### Speed Changes Not Working?
1. Check console for warnings: "Cannot adjust speed - no farm/grid"
2. Verify biomes have quantum_time_scale property
3. Ensure farm is initialized (wait a few frames after boot)

### Speed Persists After Save/Load?
✅ **Yes!** Speed is now saved to GameState and restored on load. Your preferred speed setting will persist across game sessions.

### Keys Not Responding?
1. Check no UI element has focus (click on viewport)
2. Verify VerboseConfig is enabled to see console logs
3. Check no other input handler is consuming `-` or `=` keys

---

## Future Enhancements

### Possible Extensions
1. **HUD Display:** Show current speed on-screen
2. **Persistence:** Save speed setting to disk
3. **Per-Biome Speed:** Different speeds for different biomes
4. **Speed Presets:** Hotkeys for specific speeds (Ctrl+1 = 0.25x, etc.)
5. **Audio Pitch Scaling:** Lower pitch at low speed, higher at high speed

### Integration with Time Crystals
When time crystal biomes are added, speed control could:
- Affect time crystal formation rate
- Create temporal loops at extreme speeds
- Enable "time debugging" by slowing near singularities

---

**Last Updated:** 2026-01-26
**Status:** ✅ Implemented
**Commit:** [current]
