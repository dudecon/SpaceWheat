# Biome Exploration System - Implementation Summary

## What Changed

### Game Start
- **Before:** All 6 biomes unlocked (T, Y, U, I, O, P)
- **After:** Only 2 starter biomes unlocked (T=StarterForest, Y=Village)

### New Exploration Mechanic
- **Action:** Press `4` (Meta tool) + `E` (Explore)
- **Effect:** Unlocks random unexplored biome
- **Assignment:** Next available UIOP slot (U → I → O → P)
- **Visual:** Slides to newly discovered biome

### Starter Resources
- Added **50 eagles** (🦅) to initial inventory

---

## Files Modified (8 files)

### 1. Core/GameState/GameState.gd
**Added:**
```gdscript
@export var unlocked_biomes: Array[String] = ["StarterForest", "Village"]
@export var unexplored_biome_pool: Array[String] = ["BioticFlux", "StellarForges", "FungalNetworks", "VolcanicWorlds"]
```

### 2. Core/GameState/ObservationFrame.gd
**Changed:**
- `BIOME_ORDER` from constant to dynamic variable
- Starts with 2 biomes, grows to 6

**Added methods:**
- `unlock_biome(biome_name)` - Adds biome to order
- `get_unlocked_biomes()` - Returns current list
- `get_unexplored_biomes()` - Returns locked biomes
- `_load_unlocked_biomes()` - Restores from save

### 3. Core/GameState/ActiveBiomeManager.gd
**Changed:**
- `BIOME_ORDER` synced with ObservationFrame
- Updates in `_connect_to_observation_frame()` and `reset()`

### 4. Core/GameState/ToolConfig.gd
**Changed Tool 4E:**
- **Before:** `"cycle_biome"` (cycle through all biomes)
- **After:** `"explore_biome"` (discover new biome)

### 5. Core/Farm.gd
**Modified `_ready()`:**
- Only loads unlocked biomes (checks ObservationFrame)
- Conditional loading for each biome

**Added methods:**
- `explore_biome()` - Main exploration logic
- `_load_biome_dynamically()` - Runtime biome loading

### 6. Core/GameMechanics/FarmEconomy.gd
**Modified INITIAL_RESOURCES:**
```gdscript
"🦅": 500,  # eagle (apex predator) - 50 quantum units
```

### 7. UI/Core/ActionDispatcher.gd
**Added to DISPATCH_TABLE:**
```gdscript
"explore_biome": ["BiomeHandler", "explore_biome", "Discovered {biome_name}!"]
```

### 8. UI/Handlers/BiomeHandler.gd
**Added method:**
```gdscript
static func explore_biome(farm, _positions) -> Dictionary:
    return farm.explore_biome()
```

---

## Player Experience

### Initial Boot
```
Unlocked:   T (StarterForest)  Y (Village)
Locked:     U (???)             I (???)     O (???)     P (???)
Resources:  50 eagles, starter resources
```

### Exploration Flow
```
Boot:        [T] [Y] [ ] [ ] [ ] [ ]
Press 4E:    [T] [Y] [U] [ ] [ ] [ ]  → "Discovered BioticFlux!"
Press 4E:    [T] [Y] [U] [I] [ ] [ ]  → "Discovered StellarForges!"
Press 4E:    [T] [Y] [U] [I] [O] [ ]  → "Discovered FungalNetworks!"
Press 4E:    [T] [Y] [U] [I] [O] [P]  → "Discovered VolcanicWorlds!"
Press 4E:    "All biomes already explored!"
```

---

## Architecture Pattern

### Biome Unlocking Flow
```
User presses 4E
  ↓
ToolConfig: action = "explore_biome"
  ↓
FarmInputHandler → ActionDispatcher
  ↓
ActionDispatcher → BiomeHandler.explore_biome()
  ↓
BiomeHandler → Farm.explore_biome()
  ↓
Farm:
  1. Gets unexplored biomes from ObservationFrame
  2. Picks random biome
  3. Calls ObservationFrame.unlock_biome()
  4. Loads biome via _load_biome_dynamically()
  5. Syncs with ActiveBiomeManager
  6. Switches view to new biome (slide animation)
  ↓
Returns: {success: true, biome_name: "BioticFlux", message: "Discovered BioticFlux!"}
```

### State Management
```
ObservationFrame (Source of Truth)
  ↓ syncs ↓
ActiveBiomeManager (Display)
  ↓ uses ↓
BiomeBackground, BiomeTabBar, PlotGridDisplay
```

---

## Save/Load Behavior

### Saving
```gdscript
GameState saves:
  unlocked_biomes = ["StarterForest", "Village", "BioticFlux"]
  unexplored_biome_pool = ["StellarForges", "FungalNetworks", "VolcanicWorlds"]
```

### Loading
```gdscript
ObservationFrame._load_unlocked_biomes():
  BIOME_ORDER = GameState.unlocked_biomes
  ↓
ActiveBiomeManager syncs BIOME_ORDER
  ↓
Farm loads only unlocked biomes
```

**Result:** Exploration progress persists across sessions

---

## Testing Quick Guide

### Verify Boot
1. Start new game
2. Check only T and Y keys work for biome switching
3. Check 50 eagles in inventory (🦅 = 500 credits)

### Test Exploration
1. Press `4` (tool indicator shows `*`)
2. Press `E`
3. See message: "Discovered [BiomeName]!"
4. View slides to new biome
5. New biome key (U/I/O/P) now works
6. Repeat 3 more times to unlock all

### Test Persistence
1. Unlock 2-3 biomes
2. Save game
3. Close + reopen
4. Load save
5. Verify unlocked biomes still accessible
6. Continue exploring from where you left off

---

## Key Benefits

1. **Progression:** Players unlock biomes through gameplay
2. **Discovery:** Random assignment creates variety
3. **Performance:** Only 2 biomes loaded at boot (faster startup)
4. **Persistence:** Progress saved across sessions
5. **Scalability:** Easy to add more biomes later

---

## Edge Cases Handled

- **All biomes explored:** Message shown, no-op
- **Load failure:** Error returned, player can retry
- **Old saves:** Default to starter biomes
- **Dev restart:** Resets to initial state

---

## Documentation

- **BIOME_EXPLORATION_SYSTEM.md** - Full technical details
- **BIOME_EXPLORATION_SUMMARY.md** - This file (quick reference)
- **BIOME_INITIALIZATION_FIX.md** - Related initialization architecture

---

## Implementation Stats

- **Files modified:** 8
- **Lines changed:** ~300 (added/modified)
- **New methods:** 7
- **Save format changes:** 2 new fields in GameState
- **Backward compatible:** Yes (old saves default gracefully)
