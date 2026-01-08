# Input Flow Trace - Quest Board Issue

## Scenario: User presses U key while quest board is open

### Expected Flow
```
User presses U
    ↓
Quest board captures U
    ↓
Quest board selects slot 0
    ↓
Game does NOT see U key
```

### Actual Flow
```
User presses U
    ↓
InputController._input() sees U
    ↓
(Should block here if quest_board_visible, but doesn't)
    ↓
InputController emits plot_selection signal
    ↓
Game selects plot
    ↓
Quest board never sees U key
```

---

## Code Trace

### Step 1: User Presses U

Godot engine processes input in this order:
1. `_input()` handlers (highest priority)
2. `_gui_input()` handlers (UI controls)
3. `_unhandled_input()` handlers
4. `_unhandled_key_input()` handlers (lowest priority)

### Step 2: InputController._input() (Line 72)

**File:** `UI/Controllers/InputController.gd:72`

```gdscript
func _input(event):
	"""Handle keyboard shortcuts"""
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	print("⌨️ KEY PRESSED: %s" % event.keycode)  # ← Would print "KEY_U"

	# Handle menu-related keys first (ESC, Q, R)
	match event.keycode:
		KEY_ESCAPE:
			# ... handles ESC
		KEY_Q:
			# ... handles Q when menu visible
		KEY_R:
			# ... handles R when menu visible

	# BLOCK ALL GAME INPUT when menu or quest board is visible
	if menu_visible:
		print("  → Menu is visible - blocking game input")
		return
	if quest_board_visible:  # ← Should block here!
		print("  → Quest board is visible - blocking game input")
		return  # ← Should exit here, never reaching game input below

	# Game input (only processed when menu is NOT visible)
	match event.keycode:
		# DISABLED: These keys are now used by FarmInputHandler for plot selection (T/Y/U/I/O/P)
		# ... but U/I/O/P are handled by FarmInputHandler, not here
```

**Question:** Does this code actually run when quest_board_visible = true?

### Step 3: Signal Emission Path (When Quest Board Opens)

**File:** `UI/Managers/OverlayManager.gd:489-491`

```gdscript
func toggle_quest_board():
	# ... (opens quest board)
	quest_board.open_board()
	overlay_states["quest_board"] = true
	overlay_toggled.emit("quest_board", true)  # ← Signal emitted
```

**File:** `UI/FarmView.gd:201-202`

```gdscript
func _on_overlay_state_changed(overlay_name: String, visible: bool):
	# ... (handles escape_menu)

	# Forward all overlay changes to InputController for modal blocking
	if input_controller.has_method("_on_overlay_toggled"):
		input_controller._on_overlay_toggled(overlay_name, visible)  # ← Calls InputController
```

**File:** `UI/Controllers/InputController.gd:71-75`

```gdscript
func _on_overlay_toggled(overlay_name: String, is_visible: bool):
	"""Called when overlays open/close - block game input for modal overlays"""
	if overlay_name == "quest_board":
		quest_board_visible = is_visible  # ← Should set flag to true
		print("  → Quest board visibility: %s (game input %s)" % [is_visible, "BLOCKED" if is_visible else "ENABLED"])
```

**Critical Question:** Is this function being called? Check console for the print statement!

### Step 4: Quest Board Input Handler (Never Reached)

**File:** `UI/Panels/QuestBoard.gd:80-94`

```gdscript
func _unhandled_key_input(event: InputEvent) -> void:
	"""Modal input handling - hijacks controls when open"""
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return

	# If browser is open, it handles input first
	if is_browser_open and faction_browser and faction_browser.visible:
		return

	_handle_board_input(event)  # ← Never gets here because input already consumed
```

**File:** `UI/Panels/QuestBoard.gd:107-109`

```gdscript
func _handle_board_input(event: InputEvent) -> void:
	match event.keycode:
		KEY_U:
			select_slot(0)
			get_viewport().set_input_as_handled()  # ← Never executes
```

---

## Debugging Steps

### Check 1: Is the signal being emitted?
**Add debug print in OverlayManager.gd:491:**
```gdscript
overlay_toggled.emit("quest_board", true)
print("🔔 EMITTED overlay_toggled('quest_board', true)")  # ADD THIS
```

### Check 2: Is FarmView receiving the signal?
**Check console for this print in FarmView.gd:202:**
```gdscript
# Should print when overlay changes
```

**Add debug print:**
```gdscript
func _on_overlay_state_changed(overlay_name: String, visible: bool):
	print("🔔 FarmView received overlay_toggled('%s', %s)" % [overlay_name, visible])  # ADD THIS
	# ...
```

### Check 3: Is InputController receiving the call?
**Check console for this print in InputController.gd:75:**
```gdscript
print("  → Quest board visibility: %s (game input %s)" % [is_visible, "BLOCKED" if is_visible else "ENABLED"])
```

**Expected output when C is pressed:**
```
🔔 EMITTED overlay_toggled('quest_board', true)
🔔 FarmView received overlay_toggled('quest_board', true)
  → Quest board visibility: true (game input BLOCKED)
```

### Check 4: Is the blocking check working?
**Add debug print in InputController._input():**
```gdscript
func _input(event):
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	print("⌨️ KEY PRESSED: %s, quest_board_visible=%s" % [event.keycode, quest_board_visible])  # ADD THIS

	# ... rest of function
```

**Expected output when U is pressed (quest board open):**
```
⌨️ KEY PRESSED: KEY_U, quest_board_visible=true
  → Quest board is visible - blocking game input
```

**If you see:**
```
⌨️ KEY PRESSED: KEY_U, quest_board_visible=false  # ← FLAG NOT SET!
```

Then the signal connection is broken.

---

## Possible Failure Points

### Failure Point 1: Signal Not Connected
**Check:** Does FarmView actually connect the signal?

**File:** `UI/FarmView.gd:163-165`
```gdscript
if shell.overlay_manager.has_signal("overlay_toggled"):
	shell.overlay_manager.overlay_toggled.connect(_on_overlay_state_changed)
	print("   ✅ Overlay state sync connected")  # ← Check console for this!
```

### Failure Point 2: InputController Method Doesn't Exist
**Check:** Does InputController actually have `_on_overlay_toggled` method?

**File:** `UI/Controllers/InputController.gd:71`
```gdscript
func _on_overlay_toggled(overlay_name: String, is_visible: bool):
	# ...
```

### Failure Point 3: Timing Issue
If C key press goes through InputController._input() BEFORE the signal sets the flag, the very first keypress might not be blocked.

But subsequent keypresses (like U) should definitely be blocked.

### Failure Point 4: Something Else Consuming Input First
Is there another `_input()` handler running before InputController?

**Check scene tree order:**
- Nodes process input in tree order (depth-first)
- If InputController is a child of something else that consumes input, it might never run

---

## Console Output Analysis

### What You Should See (Working)

**When C is pressed:**
```
⌨️ KEY PRESSED: KEY_C
🔄 toggle_quest_board() called
  quest_board exists, visible = false
    → Board is hidden, opening
  ✅ Quest board opened
🔔 EMITTED overlay_toggled('quest_board', true)
🔔 FarmView received overlay_toggled('quest_board', true)
  → Quest board visibility: true (game input BLOCKED)
```

**When U is pressed (board open):**
```
⌨️ KEY PRESSED: KEY_U, quest_board_visible=true
  → Quest board is visible - blocking game input
```

### What You Might See (Broken)

**When C is pressed:**
```
⌨️ KEY PRESSED: KEY_C
🔄 toggle_quest_board() called
  ✅ Quest board opened
(No signal emission prints - signal not emitted or not received!)
```

**When U is pressed:**
```
⌨️ KEY PRESSED: KEY_U, quest_board_visible=false  # ← FLAG NEVER SET!
(Game processes U key - plot selection happens)
```

---

## Next Steps

1. **Add all debug prints above**
2. **Run the game and press C**
3. **Check console output**
4. **Press U**
5. **Check console output again**
6. **Report which prints appear/don't appear**

This will tell us exactly where the signal chain breaks.
