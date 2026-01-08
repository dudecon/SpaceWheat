# Source Files - Quest Board Input Issue

This folder contains copies of the key game files involved in the input flow issue.

---

## Files Included

### 1. InputController.gd.txt
**Path:** `UI/Controllers/InputController.gd`
**Role:** First-priority input handler
**Key sections:**
- Line 72: `func _input(event)` - Highest priority input handler
- Line 55: `var quest_board_visible` - Flag for blocking game input
- Line 71: `func _on_overlay_toggled()` - Sets blocking flag
- Line 127-129: Quest board blocking check

**Why relevant:** This runs BEFORE QuestBoard's input handler. If blocking doesn't work here, game gets the input instead of quest board.

**Critical code:**
```gdscript
# Line 127-129
if quest_board_visible:
    print("  → Quest board is visible - blocking game input")
    return  # Should block all game input
```

---

### 2. QuestBoard.gd.txt
**Path:** `UI/Panels/QuestBoard.gd`
**Role:** Modal quest board that should capture UIOP/ESC
**Key sections:**
- Line 46: `func _init()` - Modal setup (PRESET_FULL_RECT, PROCESS_MODE_ALWAYS)
- Line 80: `func _unhandled_key_input(event)` - Input handler (LOWEST priority)
- Line 99: `func _handle_board_input(event)` - Key matching (U/I/O/P/ESC/Q/E/R)
- Line 236: `func open_board()` - Opens the modal
- Line 242: `func close_board()` - Closes and emits signal

**Why relevant:** This should capture input but uses `_unhandled_key_input()` which runs AFTER `_input()`. If InputController doesn't block, this never sees the keys.

**Critical code:**
```gdscript
# Line 80-94
func _unhandled_key_input(event: InputEvent) -> void:
    if not visible or not event is InputEventKey or not event.pressed or event.echo:
        return
    # ... (never reached if InputController already processed input)
```

---

### 3. OverlayManager.gd.txt
**Path:** `UI/Managers/OverlayManager.gd`
**Role:** Manages all overlays (quests, vocabulary, ESC menu, etc.)
**Key sections:**
- Line 41: `var farm` - Stores farm reference (architectural issue!)
- Line 119: Quest board creation
- Line 228: `func toggle_overlay(name)` - Router for overlay toggles
- Line 474: `func toggle_quest_board()` - Opens/closes quest board
- Line 491: `overlay_toggled.emit("quest_board", true)` - Signal emission
- Line 982: `func _on_quest_board_closed()` - Handles close signal

**Why relevant:** This emits the signal that should tell InputController to block input. If signal doesn't reach InputController, blocking won't work.

**Critical code:**
```gdscript
# Line 489-491
quest_board.open_board()
overlay_states["quest_board"] = true
overlay_toggled.emit("quest_board", true)  # ← Should trigger blocking
```

---

### 4. FarmView.gd.txt
**Path:** `UI/FarmView.gd`
**Role:** Main scene entry point, creates everything and wires signals
**Key sections:**
- Line 28-43: Creates PlayerShell from scene
- Line 39-43: Creates Farm programmatically
- Line 121: `shell.overlay_manager.farm = farm` - Passes farm reference (bad!)
- Line 133: Connects C key to quest overlay
- Line 163-165: Connects overlay_toggled signal
- Line 190: `func _on_overlay_state_changed()` - Forwards overlay changes to InputController

**Why relevant:** This is the "glue" that connects everything. If signal routing breaks here, InputController never knows about quest board state.

**Critical code:**
```gdscript
# Line 200-202
# Forward all overlay changes to InputController for modal blocking
if input_controller.has_method("_on_overlay_toggled"):
    input_controller._on_overlay_toggled(overlay_name, visible)
```

---

### 5. PlayerShell.gd.txt
**Path:** `UI/PlayerShell.gd`
**Role:** UI layer container, manages farm UI and overlays
**Key sections:**
- Line 24: `func _ready()` - Initialization
- Line 56-60: Creates OverlayManager
- Line 63: Creates overlays
- Line 69: `func load_farm(farm_ref)` - Loads farm into UI

**Why relevant:** This is the UI layer that SHOULD be the outermost layer, but is currently nested inside FarmView.

**Architectural issue:**
```
FarmView (main) ← Wrong! This is an orchestrator, not root
└── PlayerShell ← Should be root!
    └── OverlayManager
```

---

### 6. EscapeMenu.gd.txt
**Path:** `UI/Panels/EscapeMenu.gd`
**Role:** ESC menu modal (WORKS CORRECTLY - reference implementation)
**Key sections:**
- Line 12: `func _init()` - Same modal setup as QuestBoard
- Line 29: `func _unhandled_key_input(event)` - Same input pattern
- Line 56: `match event.keycode` - Direct keycode matching

**Why relevant:** This modal WORKS while QuestBoard doesn't, but they use the SAME pattern. The difference is:
- ESC key is ONLY used by ESC menu (no conflicts)
- UIOP keys are ALSO used by game (conflicts!)

**Why ESC menu works:**
```gdscript
# InputController.gd sets menu_visible directly in _input()
KEY_ESCAPE:
    menu_visible = true  # ← Set immediately, same function
    menu_toggled.emit()

# Quest board uses signal (timing delay?)
KEY_C:
    contracts_toggled.emit()  # ← Signal chain
    # ... later: quest_board_visible = true
```

---

## Signal Flow Chain

### When C is Pressed (Quest Board Opens)

```
1. User presses C
   ↓
2. InputController._input(KEY_C)
   └─ Line 190: contracts_toggled.emit()
   ↓
3. FarmView receives signal (connected on line 133)
   └─ Calls: shell.overlay_manager.toggle_overlay("quests")
   ↓
4. OverlayManager.toggle_overlay("quests") - Line 231
   └─ Calls: toggle_quest_board()
   ↓
5. OverlayManager.toggle_quest_board() - Line 474
   └─ Line 489: quest_board.open_board()
   └─ Line 491: overlay_toggled.emit("quest_board", true)
   ↓
6. FarmView._on_overlay_state_changed() - Line 190
   └─ Connected on line 164
   └─ Line 202: input_controller._on_overlay_toggled(overlay_name, visible)
   ↓
7. InputController._on_overlay_toggled() - Line 71
   └─ Line 74: quest_board_visible = is_visible
   └─ Print: "Quest board visibility: true (game input BLOCKED)"
```

**Question:** Is step 7 actually happening? Check console output!

### When U is Pressed (Quest Board Open)

```
1. User presses U
   ↓
2. InputController._input(KEY_U) - Line 72
   ↓
3. Check: if quest_board_visible: return - Line 127
   ↓
   IF flag is TRUE:
       return ← Game input blocked ✅
       QuestBoard._unhandled_key_input() runs
       Quest board selects slot 0 ✅
   ↓
   IF flag is FALSE:
       Continue to game input processing ❌
       Game selects plot ❌
       QuestBoard never sees input ❌
```

**Current behavior:** Flag appears to be FALSE (game sees input)

---

## Debugging Checklist

Use these files to add debug prints and trace the flow:

### Step 1: Verify Signal Emission
**File:** OverlayManager.gd.txt
**Add after line 491:**
```gdscript
overlay_toggled.emit("quest_board", true)
print("🔔 DEBUG: Emitted overlay_toggled('quest_board', true)")
```

### Step 2: Verify Signal Reception
**File:** FarmView.gd.txt
**Add at line 191 (start of _on_overlay_state_changed):**
```gdscript
print("🔔 DEBUG: FarmView received overlay_toggled('%s', %s)" % [overlay_name, visible])
```

### Step 3: Verify InputController Call
**File:** InputController.gd.txt
**Add at line 72 (start of _on_overlay_toggled):**
```gdscript
print("🔔 DEBUG: InputController._on_overlay_toggled('%s', %s)" % [overlay_name, is_visible])
print("🔔 DEBUG: quest_board_visible is now: %s" % quest_board_visible)
```

### Step 4: Verify Blocking Check
**File:** InputController.gd.txt
**Modify line 80:**
```gdscript
print("⌨️ KEY PRESSED: %s (quest_board_visible=%s)" % [event.keycode, quest_board_visible])
```

### Expected Console Output

**When C pressed:**
```
⌨️ KEY PRESSED: 67 (quest_board_visible=false)
🔔 DEBUG: Emitted overlay_toggled('quest_board', true)
🔔 DEBUG: FarmView received overlay_toggled('quest_board', true)
🔔 DEBUG: InputController._on_overlay_toggled('quest_board', true)
🔔 DEBUG: quest_board_visible is now: true
  → Quest board visibility: true (game input BLOCKED)
```

**When U pressed (board open):**
```
⌨️ KEY PRESSED: 85 (quest_board_visible=true)
  → Quest board is visible - blocking game input
```

**If you see quest_board_visible=false when U is pressed, the signal chain is broken!**

---

## File Sizes

- InputController.gd.txt: ~8KB
- QuestBoard.gd.txt: ~27KB (largest, has all quest logic)
- OverlayManager.gd.txt: ~32KB (manages all overlays)
- FarmView.gd.txt: ~9KB
- PlayerShell.gd.txt: ~6KB
- EscapeMenu.gd.txt: ~7KB

**Total:** ~89KB of source code

---

## Next Steps

1. Read through these files to understand the flow
2. Add debug prints as suggested above
3. Run the game and check console output
4. Determine where the signal chain breaks
5. Choose a fix strategy (quick hack, partial refactor, or full refactor)
