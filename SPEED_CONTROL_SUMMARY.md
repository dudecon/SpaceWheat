# Simulation Speed Control - Summary of Changes

## What Was Changed

### 1. **Wider Speed Range** 🏎️ → 🐌
- **Minimum:** 0.001x (was 0.0625x) - **1/1000th speed** for ultra slow-mo
- **Maximum:** 16.0x (was 4.0x) - **16x speed** for extreme fast-forward
- **Range increased by ~250x** (from 64:1 to 16000:1)

### 2. **Speed Persistence** 💾
Speed now saves/loads with game state:
- ✅ Captured during save
- ✅ Restored during load
- ✅ Persists across game sessions

---

## Files Modified

### Core Files
1. **`Core/GameState/GameState.gd`**
   - Added: `@export var quantum_time_scale: float = 0.5`
   - Line: 23

2. **`Core/GameState/GameStateManager.gd`**
   - **Save:** Capture speed from first biome (line ~347)
   - **Load:** Restore speed to all biomes (line ~901)

### Input & Controls
3. **`UI/Core/QuantumInstrumentInput.gd`**
   - **Min/Max:** Changed from 0.0625/4.0 to 0.001/16.0 (lines 1588, 1615)
   - **Persistence:** Update GameStateManager.current_state after speed change (lines 1598, 1627)

### Documentation
4. **`SIMULATION_SPEED_CONTROLS.md`**
   - Updated speed range documentation
   - Added persistence information
   - Updated code examples

---

## Technical Details

### Speed Capture (Save)
```gdscript
# GameStateManager.capture_state_from_game() line ~347
if farm.grid.biomes and not farm.grid.biomes.is_empty():
    var first_biome = farm.grid.biomes.values()[0]
    if "quantum_time_scale" in first_biome:
        state.quantum_time_scale = first_biome.quantum_time_scale
        _verbose.debug("save", "⏱️", "Captured simulation speed: %.4fx" % state.quantum_time_scale)
```

### Speed Restoration (Load)
```gdscript
# GameStateManager.apply_state_to_game() line ~901
if farm.grid and farm.grid.biomes:
    var biome_count = 0
    for biome in farm.grid.biomes.values():
        if "quantum_time_scale" in biome:
            biome.quantum_time_scale = state.quantum_time_scale
            biome_count += 1
    _verbose.debug("save", "⏱️", "Applied simulation speed %.4fx to %d biomes" % [state.quantum_time_scale, biome_count])
```

### Speed Change with Persistence
```gdscript
# QuantumInstrumentInput._decrease_simulation_speed() line ~1598
# QuantumInstrumentInput._increase_simulation_speed() line ~1627

# Update GameState so it's saved
var gsm = get_node_or_null("/root/GameStateManager")
if gsm and gsm.current_state:
    gsm.current_state.quantum_time_scale = new_speed
```

---

## Usage

### Speed Progression Table
| Presses | From 0.5x (Default) |
|---------|---------------------|
| -1      | 0.25x               |
| -2      | 0.125x              |
| -3      | 0.0625x             |
| -4      | 0.03125x            |
| -5      | 0.015625x           |
| -6      | 0.0078125x          |
| -7      | 0.00390625x         |
| -8      | 0.001953125x        |
| -9      | 0.001x (min)        |
| +1      | 1.0x                |
| +2      | 2.0x                |
| +3      | 4.0x                |
| +4      | 8.0x                |
| +5      | 16.0x (max)         |

### Console Output
```
# Decreasing speed
[DEBUG][save] ⏱️ Captured simulation speed: 0.5000x
[INFO][input] ⏬ Simulation speed: 0.5000x → 0.2500x (6 biomes)

# Increasing speed
[DEBUG][save] ⏱️ Captured simulation speed: 0.2500x
[INFO][input] ⏫ Simulation speed: 0.2500x → 0.5000x (6 biomes)

# On save
[DEBUG][save] ⏱️ Captured simulation speed: 2.0000x
[INFO][save] 💾 Game saved to slot 1: user://saves/save_slot_0.tres

# On load
[DEBUG][save] ⏱️ Applied simulation speed 2.0000x to 6 biomes
[INFO][save] 📂 Loaded save from slot 1
```

---

## Verification

### Test 1: Speed Range
```
1. Boot game
2. Press - repeatedly until minimum
3. Check console: "0.5000x → 0.2500x → ... → 0.0010x"
4. Press = repeatedly until maximum
5. Check console: "0.0010x → 0.0020x → ... → 16.0000x"
```

### Test 2: Persistence
```
1. Boot game (default: 0.5x)
2. Press = twice (0.5x → 1.0x → 2.0x)
3. Save game (F1 → Save Slot 1)
4. Quit game
5. Load game (F1 → Load Slot 1)
6. Check console: "Applied simulation speed 2.0000x to 6 biomes"
7. Verify: Simulation runs at 2.0x speed
```

### Test 3: Cross-Biome Consistency
```
1. Set speed to 4.0x
2. Switch biomes (U/I/O/P)
3. All biomes should run at same speed
4. Check console: "Applied... to 6 biomes" (not 1 biome)
```

---

## Performance Impact

### Memory
- **GameState:** +4 bytes per save (1 float)
- **Runtime:** No additional memory

### CPU
- **Speed change:** Loops through biomes once (~6 iterations)
- **Save/Load:** One extra float read/write
- **Cost:** Negligible (<1μs)

### Simulation
- 0.001x: 1ms simulated time per 1000ms real time
- 16.0x: 160ms simulated time per 10ms real time
- CPU usage unchanged (same # of steps, different dt)

---

## Edge Cases Handled

### Missing Biomes
```gdscript
if farm.grid.biomes and not farm.grid.biomes.is_empty():
    # Only access biomes if they exist
```

### Missing quantum_time_scale
```gdscript
if "quantum_time_scale" in biome:
    # Only set if property exists
```

### No GameStateManager
```gdscript
var gsm = get_node_or_null("/root/GameStateManager")
if gsm and gsm.current_state:
    # Only update if manager exists
```

### Old Save Files
- Default value: 0.5x if not present in save
- Backward compatible (old saves work)

---

## Future Enhancements

### Possible Extensions
1. **HUD Display:** Show current speed on-screen (overlay)
2. **Speed Presets:** Hotkeys for common speeds (Ctrl+1 = 0.25x, etc.)
3. **Per-Biome Speed:** Different speeds for different biomes (time dilation)
4. **Audio Pitch Scaling:** Lower pitch at low speed, higher at high speed
5. **Pause Button:** 0.0x speed (freeze simulation)
6. **Speed Slider:** UI control instead of/in addition to keyboard

---

**Last Updated:** 2026-01-27
**Status:** ✅ Complete
**Commits:** [current]

**Key Benefits:**
- 🎯 Ultra slow-mo for learning/observation (0.001x)
- 🏎️ Extreme fast-forward for grinding (16.0x)
- 💾 Persistent across sessions (saves/loads)
- 🔄 Works seamlessly with existing save system
