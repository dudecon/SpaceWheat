# Quest Board Input Issue - Root Cause Analysis

## Problem Statement

**Quest board opens visually when C is pressed, but UIOP and ESC keys still control the game instead of the quest board.**

- ✅ C opens the quest board (visual appears)
- ✅ C again closes the quest board
- ❌ UIOP keys select game plots instead of quest slots
- ❌ ESC key affects game instead of closing quest board

## Expected Behavior

When quest board is open:
- UIOP keys should select quest slots (0-3)
- ESC should close the quest board
- QER should perform quest actions
- Game should NOT respond to any of these keys

## Actual Behavior

Quest board is visible but "transparent" to input - all keys pass through to the game layer.

---

## Root Cause Analysis

### Architecture Problem 1: Inverted Hierarchy

**Current (WRONG):**
```
FarmView (main scene entry point)
├── PlayerShell (UI layer - NESTED INSIDE GAME)
│   ├── OverlayManager (menus)
│   │   └── QuestBoard (modal)
│   └── InputController (input router)
└── Farm (game logic)
    └── FarmView passes farm reference DOWN to OverlayManager
```

**Should be:**
```
PlayerShell (main scene entry point - OUTERMOST)
├── Farm (game logic - owned by shell)
├── InputController (input router)
└── OverlayManager (menus - gets data via methods, NOT references)
    └── QuestBoard (modal)
```

**Why this matters:** UI layer should wrap game logic, not be nested inside it.

---

### Architecture Problem 2: Input Execution Order

Godot input processing order:
```
1. _input() ← InputController runs HERE (highest priority)
2. _gui_input() (Control nodes)
3. _unhandled_input()
4. _unhandled_key_input() ← QuestBoard runs HERE (lowest priority)
```

**Current flow when U is pressed:**
```
User presses U
    ↓
InputController._input() catches it FIRST ← PROBLEM!
    ↓
Checks: if quest_board_visible: return
    ↓
(Should block here, but doesn't)
    ↓
Emits plot_selection signal
    ↓
Game selects plot
    ↓
QuestBoard._unhandled_key_input() ← Never gets the input!
```

---

## Attempted Fixes (All Failed)

### Attempt 1: Modal Pattern from ESC Menu
- Added `process_mode = ALWAYS`
- Added `mouse_filter = STOP`
- Added `_unhandled_key_input()` handler
- Added `get_viewport().set_input_as_handled()` calls
- **Result:** Still doesn't work (ESC menu uses different keys)

### Attempt 2: Input Blocking Flag
- Added `quest_board_visible` flag to InputController
- Added blocking check: `if quest_board_visible: return`
- Connected `overlay_toggled` signal to update flag
- **Result:** Still doesn't work

### Attempt 3: Fixed `.has()` Errors
- Changed `node.has("property")` to `"property" in node`
- Fixed compilation errors
- **Result:** Errors fixed, but input still doesn't work

---

## Why Input Blocking Doesn't Work

### Theory 1: Signal Not Reaching InputController
The signal chain:
```
QuestBoard opens
    ↓
OverlayManager.toggle_quest_board()
    ↓
overlay_toggled.emit("quest_board", true)
    ↓
FarmView._on_overlay_state_changed()
    ↓
InputController._on_overlay_toggled() ← Should set quest_board_visible = true
    ↓
InputController._input() checks quest_board_visible
    ↓
(Should block, but doesn't)
```

**Possible issue:** Signal connection might not be working, or timing issue.

### Theory 2: InputController Runs Before Flag Is Set
If the C key press that opens the quest board runs through InputController._input() BEFORE the signal updates the flag, subsequent inputs might not be blocked.

### Theory 3: Something Else Consuming Input First
There might be another input handler with higher priority than InputController._input().

---

## Critical Files Involved

### Input Flow
1. **UI/Controllers/InputController.gd** - First input handler, uses `_input()`
   - Line 72: `func _input(event)` ← Runs FIRST
   - Line 127-129: Quest board blocking check (not working)
   - Line 55: `var quest_board_visible: bool = false` flag

2. **UI/FarmView.gd** - Wiring layer
   - Line 133: Connects C key to `toggle_overlay("quests")`
   - Line 201-202: Forwards overlay signals to InputController

3. **UI/Managers/OverlayManager.gd** - Overlay manager
   - Line 228-249: `toggle_overlay()` router
   - Line 474-498: `toggle_quest_board()` implementation
   - Line 491: Emits `overlay_toggled("quest_board", true)`

4. **UI/Panels/QuestBoard.gd** - Modal quest board
   - Line 80-94: `_unhandled_key_input()` ← Runs LAST (too late!)
   - Line 99-130: `_handle_board_input()` key handlers

### Farm Reference Issue
5. **OverlayManager.gd** line 41: `var farm` reference
   - Line 486: Uses farm to get biome
   - **Problem:** OverlayManager shouldn't need direct Farm reference

---

## Why ESC Menu Works But Quest Board Doesn't

**ESC Menu:**
- ESC key is ONLY used by ESC menu (no conflicts)
- InputController sets `menu_visible = true` directly in `_input()`
- Blocking happens immediately in same function
- No signal delay

**Quest Board:**
- UIOP keys are ALSO used by game (conflicts!)
- Quest board visibility set via signal (timing delay?)
- Signal goes: OverlayManager → FarmView → InputController
- By the time flag is set, input already processed?

---

## Proposed Solutions

### Option A: Quick Fix (Minimal Changes)
**Change InputController to check modals BEFORE processing keys:**
```gdscript
func _input(event):
    # Check if ANY modal is open FIRST
    if _is_any_modal_open():
        return  # Block ALL input

    # Then process game input
    match event.keycode:
        KEY_U: # ...
```

**Problems:**
- Still inverted architecture
- Still has farm reference coupling
- Band-aid solution

### Option B: Move Quest Board to _input() Priority
**Change QuestBoard to use `_input()` instead of `_unhandled_key_input()`:**
```gdscript
# QuestBoard.gd
func _input(event):  # Higher priority than _unhandled_key_input
    if not visible: return

    match event.keycode:
        KEY_U, KEY_I, KEY_O, KEY_P:
            # Handle slot selection
            get_viewport().set_input_as_handled()
```

**Problems:**
- Goes against Godot best practices (modals should use _unhandled_input)
- Still doesn't fix architecture

### Option C: Proper Refactor (Recommended)
**Fix the architecture:**
1. Make PlayerShell the main scene entry point
2. Remove FarmView layer (or make it just create a Farm)
3. InputController becomes a child of PlayerShell
4. OverlayManager gets data via method parameters, not stored references
5. Quest board priority is automatic (no flag needed)

**Benefits:**
- Correct Godot architecture
- UI wraps game logic (not nested inside)
- Clean separation of concerns
- Input priority naturally correct
- No farm reference coupling

**Drawbacks:**
- Bigger refactor (2-4 hours)
- Need to test all existing functionality

---

## Recommended Path Forward

### Phase 1: Immediate Fix (Option B)
Change QuestBoard to use `_input()` with high priority. This will work but is a hack.

### Phase 2: Architecture Refactor (Option C)
1. Create new main scene: `PlayerShell.tscn` (becomes project main scene)
2. PlayerShell creates Farm as a child
3. Remove FarmView layer entirely
4. OverlayManager gets biome via method parameters:
   ```gdscript
   func toggle_quest_board(biome: Node):
       quest_board.set_biome(biome)
       quest_board.open_board()
   ```
5. InputController naturally blocks lower-priority input

---

## Testing Checklist

After fix is applied:
- [ ] C opens quest board visually
- [ ] UIOP keys select quest slots (0-3) when board open
- [ ] Game does NOT respond to UIOP when board open
- [ ] ESC closes quest board when board open
- [ ] Game does NOT respond to ESC when board open (unless entangle mode)
- [ ] C closes quest board when board already open
- [ ] QER actions work on selected slot
- [ ] Game DOES respond to UIOP after quest board closes

---

## Questions for User

1. **Quick hack or proper refactor?**
   - Quick: Change QuestBoard to `_input()` (~30 min)
   - Proper: Refactor architecture (~2-4 hours)

2. **Is FarmView serving a purpose?**
   - Can we eliminate it entirely?
   - Or does it need to exist for scene orchestration?

3. **Should OverlayManager have a Farm reference?**
   - Current: `overlay_manager.farm = farm`
   - Better: `overlay_manager.show_quest_board(biome)`

4. **Input priority philosophy:**
   - Modal-first (modals use `_input()`, game uses `_unhandled_input()`)
   - OR Layer-based (use flags to block input propagation)
