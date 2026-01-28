# Biome Exploration System

## Overview

The game now starts with only 2 unlocked biomes (StarterForest and Village), and players discover new biomes dynamically using the **4E exploration action**.

## Player Experience

### Starting State
- **Unlocked biomes:** StarterForest (T), Village (Y)
- **Locked biomes:** BioticFlux (U), StellarForges (I), FungalNetworks (O), VolcanicWorlds (P)
- **Starter resources:** Includes 50 eagles (🦅) from StarterForest

### Exploration Action (4E)
- **Action:** Press `4` (Meta tool), then `E` (Explore)
- **Effect:** Unlocks a random unexplored biome
- **Assignment:** New biome assigned to next available slot (U → I → O → P)
- **Transition:** Automatically switches view to newly discovered biome
- **Visual:** Slide-right animation shows new biome appearing

### Example Progression
```
Boot:        T Y _ _ _ _  (StarterForest, Village unlocked)
Press 4E:    T Y U _ _ _  (Discovered BioticFlux)
Press 4E:    T Y U I _ _  (Discovered StellarForges)
Press 4E:    T Y U I O _  (Discovered FungalNetworks)
Press 4E:    T Y U I O P  (Discovered VolcanicWorlds - all unlocked!)
Press 4E:    "All biomes already explored!"
```

---

## Technical Architecture

### Core Changes

#### 1. GameState (Persistent)
**File:** `Core/GameState/GameState.gd`

```gdscript
@export var unlocked_biomes: Array[String] = ["StarterForest", "Village"]
@export var unexplored_biome_pool: Array[String] = ["BioticFlux", "StellarForges", "FungalNetworks", "VolcanicWorlds"]
```

- **unlocked_biomes:** Persisted array of accessible biomes
- **unexplored_biome_pool:** Remaining biomes to discover (shrinks as player explores)

#### 2. ObservationFrame (Biome Tracking)
**File:** `Core/GameState/ObservationFrame.gd`

```gdscript
const ALL_BIOMES: Array[String] = [...]  # All 6 biomes (reference)
var BIOME_ORDER: Array[String] = ["StarterForest", "Village"]  # Dynamic, grows with exploration
```

**New Methods:**
- `unlock_biome(biome_name: String) -> bool` - Adds biome to BIOME_ORDER, syncs to GameState
- `get_unlocked_biomes() -> Array[String]` - Returns current unlocked list
- `get_unexplored_biomes() -> Array[String]` - Returns remaining locked biomes
- `_load_unlocked_biomes()` - Restores from GameState on boot

**Key Logic:**
- BIOME_ORDER is now **dynamic** (was constant)
- Starts with 2 biomes, grows to 6 max
- Syncs with GameState for save/load persistence

#### 3. ActiveBiomeManager (Display Sync)
**File:** `Core/GameState/ActiveBiomeManager.gd`

```gdscript
const ALL_BIOMES: Array[String] = [...]  # All 6 biomes (reference)
var BIOME_ORDER: Array[String] = ["StarterForest", "Village"]  # Synced with ObservationFrame
```

**Changes:**
- BIOME_ORDER synced from ObservationFrame on init
- Updated in `_connect_to_observation_frame()` and `reset()`
- Biome cycling respects unlocked list

#### 4. Farm (Biome Loading)
**File:** `Core/Farm.gd`

**Conditional Loading:**
```gdscript
func _ready():
    var observation_frame = get_node_or_null("/root/ObservationFrame")
    var unlocked_biomes = observation_frame.get_unlocked_biomes()

    # Only load unlocked biomes
    if "StarterForest" in unlocked_biomes:
        starter_forest_biome = _safe_load_biome(...)
    if "Village" in unlocked_biomes:
        village_biome = _safe_load_biome(...)
    # ... etc
```

**New Methods:**
```gdscript
func explore_biome() -> Dictionary:
    # 1. Get unexplored biomes from ObservationFrame
    # 2. Pick random biome
    # 3. Unlock via ObservationFrame.unlock_biome()
    # 4. Load biome dynamically via _load_biome_dynamically()
    # 5. Sync with ActiveBiomeManager
    # 6. Switch to new biome with slide animation
    return {success: true, biome_name: "BioticFlux", message: "Discovered BioticFlux!"}

func _load_biome_dynamically(biome_name: String) -> bool:
    # Runtime biome loading (checks if already loaded)
    # Calls _safe_load_biome() for the specific biome
```

#### 5. Action Dispatch
**Files:**
- `Core/GameState/ToolConfig.gd` - Tool 4, Action E changed from "cycle_biome" to "explore_biome"
- `UI/Core/ActionDispatcher.gd` - Added dispatch entry for "explore_biome"
- `UI/Handlers/BiomeHandler.gd` - Added `explore_biome()` static method

**Flow:**
```
User presses 4E
  → ToolConfig.TOOL_GROUPS[4]["E"] = "explore_biome"
  → FarmInputHandler routes to ActionDispatcher
  → ActionDispatcher.DISPATCH_TABLE["explore_biome"] → BiomeHandler
  → BiomeHandler.explore_biome() → Farm.explore_biome()
  → Farm unlocks random biome, loads it, switches view
```

#### 6. Starter Resources
**File:** `Core/GameMechanics/FarmEconomy.gd`

```gdscript
const INITIAL_RESOURCES = {
    # ... existing resources ...
    "🦅": 500,  # eagle (apex predator) - 50 quantum units
}
```

Added 50 eagles (500 credits = 50 quantum units) to starter pack.

---

## Save/Load Behavior

### Saving
When game saves:
```gdscript
GameState.unlocked_biomes = ["StarterForest", "Village", "BioticFlux", "StellarForges"]
GameState.unexplored_biome_pool = ["FungalNetworks", "VolcanicWorlds"]
```

### Loading
When game loads:
```gdscript
ObservationFrame._load_unlocked_biomes():
    BIOME_ORDER = GameState.unlocked_biomes.duplicate()
    # Clamp neutral_index if needed

ActiveBiomeManager._connect_to_observation_frame():
    BIOME_ORDER = ObservationFrame.get_unlocked_biomes()

Farm._ready():
    var unlocked = ObservationFrame.get_unlocked_biomes()
    # Only load biomes in unlocked list
```

**Persistence guarantees:**
- Player's exploration progress saved
- Unlocked biomes remain unlocked across sessions
- Active biome restored correctly

---

## UI/UX Considerations

### Biome Tab Bar
**File:** `UI/BiomeTabBar.gd`

Currently shows all 6 tabs. **Future enhancement:** Show only unlocked biomes, with locked slots grayed out or hidden.

### Plot Grid Display
**File:** `UI/PlotGridDisplay.gd`

Currently positions all 6 biomes. **Works as-is** because only unlocked biomes are loaded in Farm, so locked biomes have no plots.

### Biome Background
**File:** `Core/Visualization/BiomeBackground.gd`

**Works as-is** - BIOME_TEXTURES dictionary includes all 6 biomes, but only unlocked biomes are switchable.

---

## Edge Cases Handled

### 1. All Biomes Explored
```gdscript
Press 4E when all 6 unlocked:
  → ObservationFrame.get_unexplored_biomes() returns []
  → Farm.explore_biome() returns {success: false, message: "All biomes already explored!"}
  → No-op, message shown to player
```

### 2. Biome Load Failure
```gdscript
Farm._load_biome_dynamically("BioticFlux"):
  → _safe_load_biome() fails (script error, missing file)
  → Returns false
  → Farm.explore_biome() returns {success: false, message: "Biome unlocked but failed to load"}
  → Biome is marked as unlocked in GameState, but not functional
  → Player can try again (will skip to next biome)
```

### 3. Save File Migration
Old saves have no `unlocked_biomes` field:
```gdscript
ObservationFrame._load_unlocked_biomes():
    if "unlocked_biomes" not in GameState:
        # Defaults to ["StarterForest", "Village"]
        # Player starts exploration fresh
```

**Graceful degradation:** Old saves default to starter biomes, existing progress unaffected.

### 4. Dev Restart (Shift+R)
```gdscript
ObservationFrame.reset():
    BIOME_ORDER = ["StarterForest", "Village"]
    neutral_index = 0

ActiveBiomeManager.reset():
    active_biome = "StarterForest"
    BIOME_ORDER = ["StarterForest", "Village"]
```

Resets exploration progress to initial state.

---

## Testing Checklist

### Boot Behavior
- [ ] Game starts with only StarterForest and Village visible
- [ ] BiomeBackground shows StarterForest
- [ ] Music plays "Peripheral Arbor" (StarterForest theme)
- [ ] BiomeTabBar shows T and Y highlighted (if UI updated)
- [ ] Pressing U/I/O/P does nothing (biomes not unlocked)

### Exploration Flow
- [ ] Press 4 → Tool group indicator shows "*" (Meta)
- [ ] Press E → Random biome unlocked
- [ ] Message displays: "Discovered [BiomeName]!"
- [ ] View switches to new biome with slide animation
- [ ] New biome background loads correctly
- [ ] New biome music plays
- [ ] Pressing T/Y still works (starter biomes)
- [ ] Newly unlocked key (U/I/O/P) now works

### Progression
- [ ] Explore 4 times → All 6 biomes unlocked
- [ ] 5th press → "All biomes already explored!" message
- [ ] All TYUIOP keys functional

### Save/Load
- [ ] Unlock 2 biomes → Save game
- [ ] Load game → 4 biomes unlocked (2 starter + 2 explored)
- [ ] Switch between all 4 unlocked biomes works
- [ ] Explore from loaded game → 5th biome unlocks correctly

### Starter Resources
- [ ] Check economy at boot: 🦅 = 500 credits (50 eagles)

---

## Future Enhancements

### 1. Exploration Requirements
Add prerequisites for exploration:
```gdscript
const EXPLORATION_COSTS = {
    "BioticFlux": {"🌾": 100, "🍞": 50},  # Requires wheat + bread
    "StellarForges": {"⚙": 50},            # Requires gears
    # ...
}
```

### 2. Discovery Narrative
Show biome description on unlock:
```gdscript
func explore_biome() -> Dictionary:
    # ... unlock logic ...
    return {
        success: true,
        biome_name: "BioticFlux",
        message: "Discovered BioticFlux!",
        description: "A realm where organic matter pulses with quantum energy..."
    }
```

### 3. Visual Locked State
Update BiomeTabBar to show locked slots:
```gdscript
func _create_tab_button(biome_name: String) -> Button:
    # ...
    if biome_name not in unlocked_biomes:
        button.disabled = true
        button.modulate = Color(0.5, 0.5, 0.5, 0.5)  # Gray out
        button.text += " 🔒"  # Lock icon
```

### 4. Directional Assignment
Instead of random, assign to next keyboard slot:
```gdscript
var slot_order = ["U", "I", "O", "P"]
var next_slot = slot_order[unlocked_biomes.size() - 2]  # -2 for T,Y
```

---

## Related Files

### Modified
- `Core/GameState/GameState.gd` - Added unlocked_biomes, unexplored_biome_pool
- `Core/GameState/ObservationFrame.gd` - Dynamic BIOME_ORDER, unlock methods
- `Core/GameState/ActiveBiomeManager.gd` - Syncs with ObservationFrame
- `Core/GameState/ToolConfig.gd` - Changed 4E action to explore_biome
- `Core/Farm.gd` - Conditional loading, explore_biome(), _load_biome_dynamically()
- `Core/GameMechanics/FarmEconomy.gd` - Added 50 eagles to INITIAL_RESOURCES
- `UI/Core/ActionDispatcher.gd` - Added explore_biome dispatch
- `UI/Handlers/BiomeHandler.gd` - Added explore_biome() method

### Unchanged (But Relevant)
- `UI/BiomeTabBar.gd` - Still shows all tabs (future: lock/hide)
- `UI/PlotGridDisplay.gd` - Works with dynamic biome list
- `Core/Visualization/BiomeBackground.gd` - Textures for all biomes loaded

---

## Debug Commands

For testing exploration system:

```gdscript
# In Godot console:
var obs = get_node("/root/ObservationFrame")
obs.get_unlocked_biomes()  # Check current unlocked
obs.get_unexplored_biomes()  # Check remaining

var farm = get_node("/root/Farm")  # Adjust path as needed
farm.explore_biome()  # Manually trigger exploration

obs.unlock_biome("BioticFlux")  # Manually unlock specific biome
```

---

## Summary

The biome exploration system adds **progression and discovery** to the game:

1. **Start small:** Only 2 biomes accessible
2. **Discover:** Press 4E to unlock random biome
3. **Expand:** New biomes assigned to UIOP keyboard slots
4. **Persist:** Exploration progress saved across sessions
5. **Complete:** Unlock all 6 biomes through gameplay

**Key architectural wins:**
- Conditional biome loading (performance at boot)
- Dynamic keyboard layout (grows with exploration)
- Clean separation of concerns (ObservationFrame = truth, Farm = loading, ActionDispatcher = input)
