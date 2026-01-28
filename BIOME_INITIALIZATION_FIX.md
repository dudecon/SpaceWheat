# Biome Initialization Race Condition Fix

## Problem Statement

At game boot, the background displayed BioticFlux while music and simulation correctly showed StarterForest. After manually switching biomes once, everything synced correctly.

## Root Cause

**Distributed initialization state bug** - A race condition between:

1. **ActiveBiomeManager** hardcoded `active_biome = "BioticFlux"`
2. **ObservationFrame** initialized to `neutral_index = 0` (maps to "StarterForest")
3. **ActiveBiomeManager** deferred syncing with ObservationFrame via `call_deferred()`
4. **BiomeBackground** and **BiomeTabBar** queried ActiveBiomeManager immediately during `_ready()`

### Race Condition Timeline

```
Frame 0 (boot):
  T=0ms: FarmView creates BiomeBackground
  T=0ms: BiomeBackground._ready() executes
    └─ Queries ActiveBiomeManager.get_active_biome()
    └─ Returns "BioticFlux" (hardcoded, not synced yet)
    └─ set_biome("BioticFlux") → WRONG BACKGROUND ❌

  T=0ms: BiomeTabBar._ready() executes
    └─ Queries ActiveBiomeManager.get_active_biome()
    └─ Returns "BioticFlux" (wrong tab highlighted)

  T=0ms: ActiveBiomeManager._ready() executes
    └─ call_deferred("_connect_to_observation_frame")  ← Deferred!

  T=0ms: MusicManager._ready() executes
    └─ call_deferred("_play_current_biome_track")  ← Also deferred!

Frame 1 (deferred calls execute):
  T≈5ms: ActiveBiomeManager._connect_to_observation_frame() runs
    └─ active_biome = "StarterForest" (correct!)
    └─ Emits active_biome_changed signal

  T≈5ms: MusicManager._play_current_biome_track() runs
    └─ Gets "StarterForest" (correct!) ✅
    └─ Plays correct music
```

**BiomeBackground and BiomeTabBar queried BEFORE sync completed.**

**MusicManager queried AFTER sync (used `call_deferred`).**

### Why Manual Switching Fixed It

After the first manual biome switch:
- ActiveBiomeManager was already synced with ObservationFrame
- Signal `active_biome_changed` was emitted immediately
- All systems received the signal and synchronized correctly

## Solution

Applied the pattern that MusicManager uses successfully:

### 1. Fixed Hardcoded Default
**File:** `Core/GameState/ActiveBiomeManager.gd:47`

```gdscript
# BEFORE
var active_biome: String = "BioticFlux"

# AFTER
var active_biome: String = "StarterForest"  # Matches ObservationFrame initial state
```

**Also updated:**
- `ActiveBiomeManager.reset()` line 199

### 2. Made BiomeBackground Defer Initialization
**File:** `Core/Visualization/BiomeBackground.gd:63-76`

```gdscript
# BEFORE
if _biome_manager:
    # ... connect signals ...
    set_biome(_biome_manager.get_active_biome())  # ← Immediate query!
else:
    set_biome("BioticFlux")

# AFTER
if _biome_manager:
    # ... connect signals ...
    call_deferred("_set_initial_biome")  # ← Deferred query!
else:
    set_biome("StarterForest")  # ← Updated fallback

# NEW FUNCTION
func _set_initial_biome() -> void:
    """Deferred call to set initial biome after ActiveBiomeManager syncs with ObservationFrame"""
    if _biome_manager:
        set_biome(_biome_manager.get_active_biome())
```

### 3. Made BiomeTabBar Defer Initialization
**File:** `UI/BiomeTabBar.gd:60-71`

```gdscript
# BEFORE
if active_biome_manager:
    # ... connect signals ...
    _update_tab_states(active_biome_manager.get_active_biome())  # ← Immediate query!
else:
    _update_tab_states("BioticFlux")

# AFTER
if active_biome_manager:
    # ... connect signals ...
    call_deferred("_set_initial_tab_state")  # ← Deferred query!
else:
    _update_tab_states("StarterForest")  # ← Updated fallback

# NEW FUNCTION
func _set_initial_tab_state() -> void:
    """Deferred call to set initial tab state after ActiveBiomeManager syncs with ObservationFrame"""
    if active_biome_manager:
        _update_tab_states(active_biome_manager.get_active_biome())
```

## Architectural Pattern

This fix establishes a clear pattern for initializing systems that depend on ActiveBiomeManager:

### ✅ CORRECT Pattern (Deferred Query)
```gdscript
func _ready() -> void:
    _biome_manager = get_node_or_null("/root/ActiveBiomeManager")
    if _biome_manager:
        _biome_manager.active_biome_changed.connect(_on_biome_changed)
        # Defer initial query to wait for ActiveBiomeManager sync
        call_deferred("_set_initial_biome")

func _set_initial_biome() -> void:
    if _biome_manager:
        set_biome(_biome_manager.get_active_biome())
```

### ❌ WRONG Pattern (Immediate Query)
```gdscript
func _ready() -> void:
    _biome_manager = get_node_or_null("/root/ActiveBiomeManager")
    if _biome_manager:
        _biome_manager.active_biome_changed.connect(_on_biome_changed)
        # RACE CONDITION: Queries before ActiveBiomeManager syncs!
        set_biome(_biome_manager.get_active_biome())
```

## Systems Using Correct Pattern

| System | File | Pattern |
|--------|------|---------|
| **MusicManager** | `Core/Audio/MusicManager.gd:77` | ✅ Uses `call_deferred("_play_current_biome_track")` |
| **PlotGridDisplay** | `UI/PlotGridDisplay.gd:292` | ✅ Uses `call_deferred("_position_tiles_deferred")` |
| **BiomeBackground** | `Core/Visualization/BiomeBackground.gd:71` | ✅ Fixed - now uses `call_deferred("_set_initial_biome")` |
| **BiomeTabBar** | `UI/BiomeTabBar.gd:67` | ✅ Fixed - now uses `call_deferred("_set_initial_tab_state")` |

## Testing Checklist

- [x] Game boots with StarterForest background (not BioticFlux)
- [x] Music plays "Peripheral Arbor" at boot
- [x] BiomeTabBar highlights StarterForest tab at boot
- [x] Switching biomes works correctly
- [x] Background transitions smoothly
- [x] Music changes correctly
- [x] Tab highlighting follows active biome
- [x] Dev restart (Shift+R) resets to StarterForest

## Files Modified

1. **Core/GameState/ActiveBiomeManager.gd**
   - Line 47: Changed default from "BioticFlux" to "StarterForest"
   - Line 199: Updated reset() default

2. **Core/Visualization/BiomeBackground.gd**
   - Line 71: Changed to `call_deferred("_set_initial_biome")`
   - Line 75: Updated fallback from "BioticFlux" to "StarterForest"
   - Line 78-82: Added `_set_initial_biome()` function

3. **UI/BiomeTabBar.gd**
   - Line 67: Changed to `call_deferred("_set_initial_tab_state")`
   - Line 71: Updated fallback from "BioticFlux" to "StarterForest"
   - Line 125-128: Added `_set_initial_tab_state()` function

## Related Issues

This fix addresses the broader class of "first render vs normal render" bugs mentioned by the user. The pattern applies to any UI system that queries autoload state during `_ready()`.

**Key Insight:** When an autoload uses `call_deferred()` for its own initialization, dependent systems must also defer their queries to avoid race conditions.
