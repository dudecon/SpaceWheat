# Architecture Refactor Plan

## Goal: Fix Inverted Hierarchy & Input Blocking

**Current Problem:** FarmView → PlayerShell → OverlayManager (inverted!)
**Target:** PlayerShell → Farm, OverlayManager (correct!)

---

## Phase 1: Understand Current Architecture

### Current Entry Point
**Project main scene:** `scenes/FarmView.tscn`

**FarmView.gd responsibilities:**
1. Creates PlayerShell (from scene)
2. Creates Farm (programmatically)
3. Creates QuantumVisualization
4. Wires all signals together
5. Passes farm reference to OverlayManager

### Current Scene Hierarchy
```
FarmView.tscn (main scene)
└── (Created in _ready())
    ├── PlayerShell (from PlayerShell.tscn)
    │   ├── OverlayLayer (CanvasLayer)
    │   │   ├── QuestBoard
    │   │   ├── EscapeMenu
    │   │   └── Other overlays
    │   └── FarmUIContainer
    │       └── FarmUI (from FarmUI.tscn)
    ├── Farm (created programmatically)
    │   ├── BioticFluxBiome
    │   ├── MarketBiome
    │   └── Other biomes
    └── QuantumVisualization (on CanvasLayer)
```

---

## Phase 2: Design Target Architecture

### Target Entry Point
**Project main scene:** `scenes/PlayerShell.tscn` (or new `scenes/Game.tscn`)

### Target Scene Hierarchy
```
PlayerShell.tscn (main scene)
├── Farm (created in _ready())
│   ├── BioticFluxBiome
│   └── Other biomes
├── InputController
├── OverlayLayer (CanvasLayer)
│   ├── QuestBoard
│   ├── EscapeMenu
│   └── Other overlays
├── FarmUILayer
│   └── FarmUI (from FarmUI.tscn)
└── VisualizationLayer (CanvasLayer)
    └── QuantumVisualization
```

### Key Changes
1. **PlayerShell is the root** - no FarmView wrapper
2. **Farm is a child of PlayerShell** - owned by UI layer
3. **InputController is sibling to overlays** - same level in tree
4. **No farm reference passed** - OverlayManager calls methods with data

---

## Phase 3: Migration Steps

### Step 1: Create New Main Scene
**Create:** `scenes/Game.tscn` (or modify PlayerShell.tscn)

**Root node:** Control (PlayerShell script)

**Children:**
- InputController (Node)
- OverlayLayer (CanvasLayer)
- FarmUILayer (Control)
- VisualizationLayer (CanvasLayer)

### Step 2: Move FarmView Logic to PlayerShell
**Copy from FarmView._ready() to PlayerShell._ready():**
- Farm creation
- QuantumVisualization creation
- Signal wiring

**Changes needed:**
```gdscript
# OLD (FarmView.gd)
var shell = load("res://UI/PlayerShell.tscn").instantiate()
add_child(shell)
shell.overlay_manager.farm = farm

# NEW (PlayerShell.gd)
var farm = Farm.new()
add_child(farm)
# Don't pass farm reference!
# Instead: overlay_manager gets data via method calls
```

### Step 3: Remove Farm Reference from OverlayManager
**Change:** `OverlayManager.toggle_quest_board()`

```gdscript
# OLD
func toggle_quest_board():
	var biome = farm.biotic_flux_biome if "biotic_flux_biome" in farm else null
	quest_board.set_biome(biome)

# NEW
func toggle_quest_board(biome: Node = null):
	if not biome:
		push_warning("No biome provided to quest board")
		return
	quest_board.set_biome(biome)
```

**Change:** Signal connections

```gdscript
# OLD (FarmView.gd)
input_controller.contracts_toggled.connect(
	func(): shell.overlay_manager.toggle_overlay("quests")
)

# NEW (PlayerShell.gd)
input_controller.contracts_toggled.connect(
	func():
		var biome = farm.biotic_flux_biome if farm else null
		overlay_manager.toggle_quest_board(biome)
)
```

### Step 4: Fix Input Priority
**Option A:** Keep current approach, but fix signal timing
- Ensure InputController gets flag BEFORE processing next input
- Use direct method call instead of signal?

**Option B:** Change QuestBoard to use `_input()` instead of `_unhandled_key_input()`
- Higher priority, captures input before game
- Less "correct" but works

**Option C:** Move all game input to `_unhandled_input()`
- InputController uses `_input()` for global keys (ESC, C, V, etc.)
- Game input (UIOP for plot selection) uses `_unhandled_input()`
- Modals (QuestBoard) use `_input()` to intercept before game
- Most Godot-idiomatic approach

### Step 5: Update Project Settings
**Change:** `project.godot`
```
[application]
run/main_scene="res://scenes/PlayerShell.tscn"  # Was: FarmView.tscn
```

### Step 6: Test Everything
- [ ] Game boots
- [ ] Farm initializes
- [ ] Visualization appears
- [ ] Input works (plant, measure, harvest)
- [ ] ESC menu works
- [ ] Quest board opens with C
- [ ] UIOP blocked when quest board open
- [ ] Quest board controls work
- [ ] Save/load works

---

## Phase 4: Optional Cleanups

### Cleanup 1: Remove FarmView Entirely
If FarmView no longer serves a purpose, delete:
- `UI/FarmView.gd`
- `scenes/FarmView.tscn`

### Cleanup 2: Rename for Clarity
Consider renaming:
- `PlayerShell` → `GameRoot` or `MainScene`
- Makes it clearer that this is the entry point

### Cleanup 3: Extract Input Router
Consider moving InputController to its own layer:
```
GameRoot
├── InputLayer (Node)
│   └── InputController
├── GameLayer (Control)
│   ├── Farm
│   └── FarmUI
└── UILayer (CanvasLayer)
    ├── QuestBoard
    └── Other overlays
```

---

## Estimated Effort

**Quick hack (change QuestBoard to _input()):** 30 minutes
- Just change one function
- Test input blocking
- Done

**Partial refactor (remove farm reference):** 2 hours
- Remove `overlay_manager.farm = farm`
- Pass biome via method parameters
- Update all overlay methods
- Test everything

**Full refactor (fix hierarchy):** 4-6 hours
- Create new main scene
- Move all FarmView logic to PlayerShell
- Update all signal connections
- Fix input priority architecture
- Test everything thoroughly
- Handle edge cases
- Update documentation

---

## Risks & Mitigations

### Risk 1: Breaking Existing Functionality
**Mitigation:**
- Keep FarmView.gd as backup
- Test each step incrementally
- Have save files ready for testing

### Risk 2: Signal Connection Breakage
**Mitigation:**
- Add debug prints to verify all signals
- Test each overlay individually
- Check console for connection errors

### Risk 3: Input System Confusion
**Mitigation:**
- Document new input flow clearly
- Add comments explaining priority
- Test all input scenarios

---

## Recommendation

**For immediate fix:** Use quick hack (30 min)
- Change QuestBoard to `_input()`
- Gets quest board working NOW
- Can refactor later

**For long-term health:** Do full refactor (4-6 hours)
- Fixes architecture properly
- Makes future features easier
- Cleaner, more maintainable code
- Better matches Godot best practices

**Compromise:** Partial refactor (2 hours)
- Remove farm reference coupling
- Fix input blocking properly
- Don't change scene hierarchy yet
- Improvement without full rewrite
