# SaveLoadMenu Input Conflicts - Complete Fix

## Problem Summary

Three persistent UI issues that prevented proper SaveLoadMenu/EscapeMenu operation:

### Issue 1: SaveLoadMenu ESC Key Behavior
**Symptom:** Pressing ESC in SaveLoadMenu closed the main pause menu instead of just closing the SaveLoadMenu submenu.

**Root Cause:** SaveLoadMenu.input_controller was null, so SaveLoadMenu couldn't disable InputController when it opened. This caused both systems to process input events simultaneously, creating a race condition.

**Evidence:** SaveLoadMenu.show_menu() (line 424-427):
```gdscript
# CRITICAL: Disable InputController so all input goes to SaveLoadMenu
if input_controller:  # ← NULL! Never executes
    input_controller.set_process_input(false)
```

### Issue 2: Pause Menu Not Centered
**Symptom:** EscapeMenu appeared on the left side instead of centered on screen.

**Root Cause:** Manual anchor setup instead of using Godot 4's `set_anchors_preset()` method.

### Issue 3: Tool Bar Buttons Not Stretching
**Symptom:** ActionPreviewRow and ToolSelectionRow buttons were scrunched to the left instead of stretching across full width.

**Root Cause:** Missing `size_flags_horizontal = Control.SIZE_EXPAND_FILL` for button distribution.

---

## Complete Architecture

### Input Processing Pipeline (Fixed)
```
User presses key
    ↓
InputController._input() [FIRST - always runs]
  ├─→ Detects key (ESC, S, Q, R, V, C, N, K, etc)
  ├─→ Sets menu_visible flag
  ├─→ Emits signals (menu_toggled, vocabulary_requested, etc)
  ├─→ Calls get_viewport().set_input_as_handled()
    ↓
FarmView signal handlers [SECOND]
  ├─→ Routes signal to OverlayManager
  ├─→ Syncs InputController.menu_visible state
    ↓
OverlayManager [THIRD]
  ├─→ Shows/hides overlays
  ├─→ Calls SaveLoadMenu.show_menu(Mode)
  ├─→ Emits overlay_toggled signal
    ↓
SaveLoadMenu.show_menu() [FOURTH - when opened]
  ├─→ Disables InputController (prevents duplicate processing)
  ├─→ Disables EscapeMenu (prevents input conflicts)
  ├─→ Sets visible = true
  ├─→ Now SaveLoadMenu has exclusive input handling
    ↓
SaveLoadMenu._unhandled_key_input() [FIFTH - if still needed]
  ├─→ Only processes if visible AND InputController is disabled
  ├─→ Handles ESC to close menu
    ↓
SaveLoadMenu.hide_menu() [CLEANUP]
  ├─→ Sets visible = false
  ├─→ Re-enables InputController
  ├─→ Re-enables EscapeMenu
  ├─→ Back to normal input flow
```

### Input State Management (Critical)

**Normal Game State:**
- InputController.menu_visible = false
- EscapeMenu.visible = false
- SaveLoadMenu.visible = false
- InputController enabled, can process game input (WASD, 1-4, Q/E/R for actions)

**Pause Menu Open:**
- InputController.menu_visible = true
- EscapeMenu.visible = true
- SaveLoadMenu.visible = false
- InputController enabled, routes menu keys (ESC, S, L, D, R, Q)
- Game input blocked (InputController checks menu_visible and returns early)

**SaveLoadMenu Open:**
- InputController.menu_visible = true (still)
- EscapeMenu.visible = true (but process_input = false)
- SaveLoadMenu.visible = true
- InputController disabled (set_process_input(false))
- SaveLoadMenu handles all input, EscapeMenu doesn't process
- Menu navigation keys work (arrows, 1-3, Enter, ESC, S/L/D)

---

## Fixes Applied

### 1. Inject InputController into SaveLoadMenu (FarmView.gd)

**Change:** Added dependency injection after component initialization
```gdscript
# CRITICAL: Inject InputController into SaveLoadMenu so it can manage input
# SaveLoadMenu needs to disable InputController when it opens to prevent conflicts
if shell.overlay_manager.save_load_menu:
    shell.overlay_manager.save_load_menu.inject_input_controller(input_controller)
    print("   ✅ InputController injected into SaveLoadMenu")
```

**Why:** SaveLoadMenu.show_menu() needs a reference to InputController to disable it:
```gdscript
if input_controller:  # ← Now set via inject_input_controller()!
    input_controller.set_process_input(false)
```

**Impact:** When SaveLoadMenu opens, it can now properly disable InputController and EscapeMenu, preventing input conflicts.

### 2. Proper Input Hierarchy with _unhandled_key_input()

**SaveLoadMenu._unhandled_key_input()** (line 218)
```gdscript
if not visible:
    return
match event.keycode:
    KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        _on_cancel_pressed()
        return
```
- Only processes when visible
- Marks input as handled immediately
- Prevents parent (EscapeMenu) from seeing the event

**EscapeMenu._unhandled_key_input()** (line 134)
```gdscript
if not visible:
    return
# Check if SaveLoadMenu is visible first
var parent = get_parent()
if parent:
    for child in parent.get_children():
        if child.name == "SaveLoadMenu" and child.visible:
            return  # Don't process, SaveLoadMenu is handling it
match event.keycode:
    # Handle ESC, S, L, D, R, Q...
```
- Only processes when visible
- Checks if SaveLoadMenu is visible and defers to it
- Handles menu navigation keys

### 3. State Synchronization (FarmView.gd)

**Added signal listener:**
```gdscript
if shell.overlay_manager.has_signal("overlay_toggled"):
    shell.overlay_manager.overlay_toggled.connect(_on_overlay_state_changed)

func _on_overlay_state_changed(overlay_name: String, visible: bool) -> void:
    """Sync InputController.menu_visible when escape menu state changes"""
    if overlay_name == "escape_menu":
        input_controller.menu_visible = visible
```

**Why:** Ensures InputController's internal state matches actual menu visibility.
- Prevents input blocking when menu fails to show
- Keeps state machines synchronized
- Enables reliable input routing

### 4. Proper Layout with Godot 4 Patterns

**EscapeMenu._init():**
```gdscript
set_anchors_preset(Control.PRESET_FULL_RECT)  # Fills entire screen
background.set_anchors_preset(Control.PRESET_FULL_RECT)

center = CenterContainer.new()
center.set_anchors_preset(Control.PRESET_FULL_RECT)
center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
center.size_flags_vertical = Control.SIZE_EXPAND_FILL
```
Result: Menu centered on screen automatically

**ActionPreviewRow/ToolSelectionRow:**
```gdscript
button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
button.custom_minimum_size = Vector2(0, 50)  # 0 width = no minimum width
```
Result: Buttons expand equally to fill available width

---

## Detailed Flow Examples

### Example 1: Open Menu (ESC pressed in game)

```
User presses ESC in game
    ↓
InputController._input(event) [KEY_ESCAPE detected]
    ├─→ menu_visible = true
    ├─→ menu_toggled.emit()
    ├─→ get_viewport().set_input_as_handled()
    ↓
FarmView._on_menu_toggled() [Signal handler]
    ├─→ shell.overlay_manager.toggle_escape_menu()
    ↓
OverlayManager.toggle_escape_menu() [line 349]
    ├─→ escape_menu.is_visible() = false
    ├─→ show_overlay("escape_menu")
    ├─→ escape_menu.show_menu() [sets visible = true, game paused]
    ├─→ overlay_toggled.emit("escape_menu", true)
    ↓
FarmView._on_overlay_state_changed("escape_menu", true) [Signal listener]
    ├─→ input_controller.menu_visible = true [SYNC]
    ↓
Result: Menu visible, game paused, input synchronized ✓
```

### Example 2: Open SaveLoadMenu (S pressed in menu)

```
User presses S with menu open
    ↓
InputController._input(event) [KEY_S]
    ├─→ menu_visible = true, so process key
    ├─→ NOT mapped to a game action, so no signal emitted
    ✓ Signal passes through to next handler
    ↓
EscapeMenu._unhandled_key_input(event) [KEY_S]
    ├─→ visible = true
    ├─→ SaveLoadMenu.visible = false, so process
    ├─→ _on_save_pressed()
    ├─→ save_pressed.emit()
    ↓
OverlayManager._on_save_pressed() [Signal handler in OverlayManager line 111]
    ├─→ save_load_menu.show_menu(Mode.SAVE)
    ↓
SaveLoadMenu.show_menu(Mode.SAVE) [Line 421]
    ├─→ input_controller.set_process_input(false)
    │   └─→ Prevents InputController from running
    ├─→ EscapeMenu.set_process_input(false)
    │   └─→ Prevents EscapeMenu from running
    ├─→ visible = true
    ├─→ set_process_input(true)  # Enable for SaveLoadMenu input
    ↓
Result: SaveLoadMenu visible, both parents disabled, SaveLoadMenu handles input ✓
```

### Example 3: Close SaveLoadMenu (ESC pressed in SaveLoadMenu)

```
User presses ESC with SaveLoadMenu open
    ↓
InputController._input(event) [KEY_ESCAPE]
    ├─→ set_process_input(false) was called, so _input() doesn't run
    ✓ Input passes through, unhandled
    ↓
EscapeMenu._unhandled_key_input(event) [KEY_ESCAPE]
    ├─→ set_process_input(false) was called, so _unhandled_key_input() doesn't run
    ✓ Input passes through, unhandled
    ↓
SaveLoadMenu._unhandled_key_input(event) [KEY_ESCAPE]
    ├─→ visible = true, so process
    ├─→ get_viewport().set_input_as_handled()
    ├─→ _on_cancel_pressed()
    ├─→ hide_menu()
    ↓
SaveLoadMenu.hide_menu() [Line 474]
    ├─→ visible = false
    ├─→ input_controller.set_process_input(true)
    │   └─→ Re-enables InputController
    ├─→ EscapeMenu.set_process_input(true)
    │   └─→ Re-enables EscapeMenu
    ↓
Result: SaveLoadMenu closed, menu still visible, input control returned ✓
```

---

## Verification Checklist

### Boot-Time Checks
- ✅ "💉 InputController injected into SaveLoadMenu" appears in console
- ✅ "✅ InputController injected into SaveLoadMenu" appears in console
- ✅ "✅ Overlay state sync connected" appears in console
- ✅ All signal connections established (ESC, V, C, N, K, Q, R)

### Runtime Behavior

**Test 1: ESC Menu Open/Close**
- [ ] Press ESC in game → Menu opens
- [ ] Menu appears CENTERED on screen
- [ ] Game is paused (trees stop moving, etc)
- [ ] Press ESC again → Menu closes
- [ ] Game resumes

**Test 2: SaveLoadMenu**
- [ ] Menu open, press S → SaveLoadMenu opens
- [ ] SaveLoadMenu appears on top
- [ ] Can navigate with arrow keys, 1-3, Enter
- [ ] Press ESC in SaveLoadMenu → SaveLoadMenu closes
- [ ] Main menu (EscapeMenu) still visible

**Test 3: Overlay Keys (when menu NOT visible)**
- [ ] Press V → Vocabulary overlay appears
- [ ] Press C → Contracts overlay appears
- [ ] Press N → Network overlay appears
- [ ] Press K → Keyboard help appears
- [ ] Each overlay can be toggled on/off

**Test 4: Menu Action Keys (when menu IS visible)**
- [ ] Press S → SaveLoadMenu opens
- [ ] Press L → SaveLoadMenu opens in LOAD mode
- [ ] Press D → Reload Last Save dialog
- [ ] Press R → Restart game
- [ ] Press Q → Quit game
- [ ] All work without freezing

**Test 5: Button Layout**
- [ ] ActionPreviewRow buttons (Q, E, R) stretch across full width
- [ ] ToolSelectionRow buttons (1, 2, 3, 4) stretch across full width
- [ ] Buttons are evenly distributed

**Test 6: No Input Blocking**
- [ ] No random freezes or input hangs
- [ ] No scenario where pressing a key quits unexpectedly
- [ ] State transitions smooth without lag

---

## Technical Details

### State Synchronization Logic

**Why it's critical:** InputController and OverlayManager are decoupled components. They don't have direct knowledge of each other's state. Without synchronization:

```
InputController thinks: menu_visible = true
OverlayManager actually: escape_menu.visible = false
Result: Game blocks input but menu not shown → Frozen game
```

**Solution:** FarmView acts as the state synchronizer:
```
OverlayManager emits: overlay_toggled("escape_menu", true/false)
    ↓
FarmView listens: _on_overlay_state_changed(name, visible)
    ↓
FarmView syncs: input_controller.menu_visible = visible
    ↓
Result: Both systems always in sync ✓
```

### Input Disabling Mechanism

**Why disable InputController when SaveLoadMenu opens?**

Without disabling:
```
SaveLoadMenu: ESC → hide SaveLoadMenu
InputController: ESC → menu_visible = false
Both run simultaneously → race condition
```

With disabling:
```
SaveLoadMenu: ESC → hide SaveLoadMenu → re-enable InputController
InputController: stays disabled until SaveLoadMenu closes
Result: Single source of truth ✓
```

### Layout Pattern (Godot 4 Best Practice)

**Before (Manual):**
```
EscapeMenu
├─→ anchor_left = 0
├─→ anchor_top = 0
├─→ anchor_right = 1
├─→ anchor_bottom = 1
├─→ offset_left = 0
├─→ offset_top = 0
├─→ (etc... fragile, breaks on viewport changes)
```

**After (Proper):**
```
set_anchors_preset(Control.PRESET_FULL_RECT)
├─→ Atomically sets all anchors/offsets to fill screen
├─→ Responsive to viewport resizes
├─→ One-line setup, no room for error
```

---

## Summary

**Three UI issues → One root cause: InputController not disabled when SaveLoadMenu opened**

**Five fixes applied:**
1. Inject InputController into SaveLoadMenu (FarmView)
2. Use _unhandled_key_input() for proper input hierarchy
3. Add state synchronization (FarmView listener)
4. Use set_anchors_preset() for layout
5. Use SIZE_EXPAND_FILL for button distribution

**Result:** Clean, predictable UI with proper input handling and visual positioning.
