# Menu, SaveLoad, and Layout Issues - Analysis for External Review

## Summary
After 4+ iterations of debugging, three critical UI issues remain **completely unresolved** despite multiple attempted fixes. The issues suggest a fundamental architectural problem with the UI layout system or input handling that requires fresh perspective.

---

## Issue #1: SaveLoadMenu ESC Key Not Working

### Expected Behavior
When the user presses ESC in the Save/Load submenu, it should:
1. Close ONLY the SaveLoadMenu
2. Return to the main Escape Menu (pause menu)
3. NOT close the Escape Menu itself

### Actual Behavior
- Pressing ESC in SaveLoadMenu closes the Escape Menu entirely
- SaveLoadMenu remains open
- Pressing ESC again reopens Escape Menu behind SaveLoadMenu
- Escape Menu becomes inaccessible until SaveLoadMenu is manually closed

### Root Cause Analysis
The input is being consumed by EscapeMenu._input() before SaveLoadMenu._input() gets a chance to process it.

### Attempted Fixes (All Failed)
1. **Added SaveLoadMenu visibility check to EscapeMenu._input()** - Still doesn't work
   - Check: `if child.name == "SaveLoadMenu" and child.visible: return`
   - Result: EscapeMenu still processes ESC

2. **Added set_process_input(false) to disable EscapeMenu** - Still doesn't work
   - SaveLoadMenu.show_menu(): `escape_menu.set_process_input(false)`
   - SaveLoadMenu.hide_menu(): `escape_menu.set_process_input(true)`
   - Result: EscapeMenu still receives input despite process_input being false

3. **Added name assignments** - Fixed technical issue but behavior unchanged
   - `name = "EscapeMenu"` in EscapeMenu._init()
   - `name = "SaveLoadMenu"` in SaveLoadMenu._init()
   - Result: Names are set, but ESC issue persists

### Key Code Flow
```
User presses ESC
  ↓
EscapeMenu._input(event) called first (added to tree before SaveLoadMenu)
  ↓
Check: Is SaveLoadMenu visible? (YES)
  ↓
Should return early... but DOESN'T
  ↓
EscapeMenu calls _on_resume_pressed() → hide_menu() → closes EscapeMenu
  ↓
SaveLoadMenu._input() never gets called (or too late)
```

### Files Involved
- `EscapeMenu.gd` - Lines 145-185 (_input method)
- `SaveLoadMenu.gd` - Lines 478-487 (show_menu), Lines 490-507 (hide_menu)
- `OverlayManager.gd` - Lines 102-140 (creation and setup)

---

## Issue #2: Pause Menu Not Centered

### Expected Behavior
EscapeMenu should appear centered on screen, with semi-transparent dark background filling the viewport and the menu box centered within it.

### Actual Behavior
- Pause menu appears on the LEFT side of the screen
- Background fills correctly, but menu is positioned left instead of center

### Root Cause Hypothesis
CenterContainer is not working as expected in Godot 4. Multiple approaches attempted with no visual change.

### Attempted Fixes (All Failed)
1. **Changed CenterContainer layout_mode from 1 (anchors) to 0 (free positioning)**
   - Attempted to set size and position explicitly
   - Result: `get_viewport()` null error (can't access in _init)
   - Reverted to anchors mode

2. **Added SIZE_EXPAND_FILL flags to CenterContainer**
   - Added `size_flags_horizontal` and `size_flags_vertical` = SIZE_EXPAND_FILL
   - Result: No visual change

3. **Fixed PlayerShell to fill viewport**
   - Changed PlayerShell.tscn: `layout_mode = 2` → `layout_mode = 1` with anchors 0-1
   - Result: No visual change to menu position

### Current Implementation
```gdscript
# EscapeMenu._init()
var center = CenterContainer.new()
center.anchor_left = 0.0
center.anchor_top = 0.0
center.anchor_right = 1.0
center.anchor_bottom = 1.0
center.layout_mode = 1  # LAYOUT_MODE_FULLRECT
add_child(center)

var menu_panel = PanelContainer.new()
menu_panel.custom_minimum_size = Vector2(400, 600)
center.add_child(menu_panel)
```

This is textbook correct implementation for centering in Godot, but produces LEFT-aligned menu.

### Files Involved
- `EscapeMenu.gd` - Lines 22-67 (_init method)
- `PlayerShell.tscn` - Lines 5-15 (PlayerShell node definition)
- `OverlayManager.gd` - Lines 102-115 (EscapeMenu creation)

---

## Issue #3: Tool Bar Buttons Not Stretching Horizontally

### Expected Behavior
ActionPreviewRow and ToolSelectionRow buttons should:
1. Stretch across the full width of the container
2. Distribute equally among available space
3. Appear spread out, not clustered on the left

### Actual Behavior
- All buttons appear "scrunched" on the LEFT side
- Large empty space on the right
- No change despite size_flags_horizontal = 3 (SIZE_EXPAND_FILL)

### Root Cause Hypothesis
Either:
1. Parent containers (MainContainer) not giving child containers full width
2. HBoxContainer not properly expanding children with SIZE_EXPAND_FILL
3. Buttons' custom_minimum_size limiting expansion improperly
4. Layout cascade from PlayerShell → FarmUI → MainContainer not working

### Attempted Fixes (All Failed)
1. **Changed button alignment from ALIGNMENT_CENTER to ALIGNMENT_BEGIN**
   - Result: No visual change
   - Reverted because made semantic situation worse

2. **Verified size_flags_horizontal in scene file**
   - FarmUI.tscn: MainContainer has `size_flags_horizontal = 3`
   - FarmUI.tscn: ActionPreviewRow has `size_flags_horizontal = 3`
   - FarmUI.tscn: ToolSelectionRow has `size_flags_horizontal = 3`
   - Result: All correctly set, but buttons still don't stretch

3. **Verified size_flags in button creation code**
   - ActionPreviewRow.gd line 68: `button.size_flags_horizontal = Control.SIZE_EXPAND_FILL`
   - ToolSelectionRow.gd line 57: `button.size_flags_horizontal = Control.SIZE_EXPAND_FILL`
   - Result: Correctly set, but buttons still don't stretch

4. **Added parametric sizing in FarmUI.gd**
   - _apply_parametric_sizing() sets custom_minimum_size with Vector2(0, height)
   - X component is 0 (should allow full expansion)
   - Result: No visual change

### Layout Hierarchy
```
PlayerShell (layout_mode=1, anchors 0-1)
  ├─ FarmUIContainer (layout_mode=1, anchors 0-1)
  │  └─ FarmUI (layout_mode=1, anchors 0-1)
  │     └─ MainContainer (layout_mode=1, anchors 0-1, size_flags=3)
  │        ├─ ResourcePanel (HBoxContainer, size_flags_horizontal=3)
  │        ├─ PlotGridDisplay
  │        ├─ ActionPreviewRow (HBoxContainer, size_flags_horizontal=3)
  │        │  └─ Button (x3, size_flags_horizontal=SIZE_EXPAND_FILL)
  │        └─ ToolSelectionRow (HBoxContainer, size_flags_horizontal=3)
  │           └─ Button (x6, size_flags_horizontal=SIZE_EXPAND_FILL)
  └─ OverlayLayer
```

Everything is correctly configured, but visual layout doesn't match.

### Files Involved
- `FarmUI.tscn` - Scene hierarchy and size_flags
- `FarmUI.gd` - Lines 154-187 (_apply_parametric_sizing)
- `ActionPreviewRow.gd` - Lines 54-84 (_ready method, button creation)
- `ToolSelectionRow.gd` - Lines 35-97 (_ready method, button creation)
- `PlayerShell.tscn` - Root layout
- `PlayerShell.gd` - Scene loading

---

## Why External Review Is Needed

### Pattern of Failures
- All attempted fixes are **semantically correct** for Godot 4
- All fixes follow documented best practices
- **Zero visual changes** across 4+ iterations suggest architectural issue
- Different approach every iteration, no cumulative progress

### Possible Root Causes
1. **Godot 4 Version-Specific Issue**
   - Using Godot 4.5.stable
   - Possible regression or undocumented behavior change
   - CenterContainer or size_flags behavior different than expected

2. **Input System Issue**
   - `set_process_input(false)` not actually preventing _input() calls
   - Input event handling order different than documented
   - _ready() timing issues with process_input state

3. **Scene Hierarchy Problem**
   - FarmUI loaded via `.instantiate()` might not properly inherit parent layout
   - MainContainer anchors conflicting with parent anchors
   - Layout_mode cascade not working as expected

4. **Deeper Architectural Issue**
   - Scene-based composition (using .tscn files) might have unforeseen constraints
   - Dynamic node creation not properly respecting parent layout
   - Missing initialization or signal connection

---

## Test Environment
- Godot Engine v4.5.stable.official.876b29033
- GDScript
- Platform: Linux (WSL2)
- Resolution tested: 1280×720, 64×64 (headless)

---

## Files for Review
1. `EscapeMenu.gd.txt` - Pause menu with broken centering
2. `SaveLoadMenu.gd.txt` - Save/load submenu with broken ESC handling
3. `ActionPreviewRow.gd.txt` - Tool action buttons not stretching
4. `ToolSelectionRow.gd.txt` - Tool selection buttons not stretching
5. `FarmUI.gd.txt` - Farm UI controller
6. `FarmUI.tscn.txt` - Farm UI scene (layout configuration)
7. `PlayerShell.tscn.txt` - Player shell scene (root layout)
8. `PlayerShell.gd.txt` - Player shell loader
9. `OverlayManager.gd.txt` - Menu creation and management
10. `UILayoutManager.gd.txt` - Layout system reference

---

## Next Steps for External Reviewer
1. Check if there's a known Godot 4.5 issue with CenterContainer centering
2. Verify input event handling and `set_process_input()` behavior
3. Test if HBoxContainer with SIZE_EXPAND_FILL works differently than expected
4. Review scene-based composition patterns in Godot 4
5. Consider if there's missing initialization or signal connection causing layout to not be applied
