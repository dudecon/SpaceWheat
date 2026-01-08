# Menu, SaveLoad, and Layout Issues - External Review Package

## Overview
This package contains a detailed analysis and all relevant source files for three critical UI issues that have remained **completely unresolved** after 4+ debugging iterations.

## Quick Start
1. **Read ANALYSIS.md first** - Comprehensive breakdown of all three issues, attempted fixes, and why they failed
2. **Review the key files** listed below in order
3. **Focus areas** are marked in each file for quick navigation

## The Three Issues

### Issue 1: SaveLoadMenu ESC Key Not Working ⚠️
- **Severity:** High (breaks menu navigation)
- **Status:** Unfixed after 3 separate fix attempts
- **Key Files:** SaveLoadMenu.gd.txt, EscapeMenu.gd.txt, OverlayManager.gd.txt

### Issue 2: Pause Menu Not Centered 🖼️
- **Severity:** Medium (visual/UX issue)
- **Status:** Unfixed despite correct CenterContainer implementation
- **Key Files:** EscapeMenu.gd.txt, PlayerShell.tscn.txt, PlayerShell.gd.txt

### Issue 3: Tool Bar Buttons Not Stretching 📊
- **Severity:** Medium (visual/UX issue)
- **Status:** Unfixed despite correct size_flags configuration
- **Key Files:** ActionPreviewRow.gd.txt, ToolSelectionRow.gd.txt, FarmUI.tscn.txt

## File Guide

### Start Here
- **ANALYSIS.md** - Complete analysis of all issues, attempted fixes, root cause hypotheses
- **README.md** (this file) - Navigation guide

### Core Problem Files (in order of priority)

1. **EscapeMenu.gd.txt** (7.4 KB)
   - Pause menu implementation
   - Focus: Lines 22-67 (_init method - CenterContainer setup)
   - Focus: Lines 145-185 (_input method - ESC handling)
   - Issue: Menu appears on LEFT instead of CENTERED

2. **SaveLoadMenu.gd.txt** (18 KB)
   - Save/Load submenu
   - Focus: Lines 38-40 (name assignment for identification)
   - Focus: Lines 478-487 (show_menu - disable EscapeMenu input)
   - Focus: Lines 490-507 (hide_menu - re-enable EscapeMenu input)
   - Focus: Lines 232-289 (_input method - ESC key handling)
   - Issue: ESC key doesn't close submenu, closes main menu instead

3. **OverlayManager.gd.txt** (19 KB)
   - Creates and manages menus
   - Focus: Lines 102-115 (EscapeMenu creation)
   - Focus: Lines 127-140 (SaveLoadMenu creation and setup)
   - Focus: Lines 450-475 (toggle methods for menus)
   - Issue: Input order/priority not respecting attempted disables

4. **ActionPreviewRow.gd.txt** (5.3 KB)
   - Action button row (Q/E/R buttons)
   - Focus: Lines 54-84 (_ready method)
   - Issue: Buttons scrunched to left instead of stretching full width

5. **ToolSelectionRow.gd.txt** (5.1 KB)
   - Tool selection row (1-6 buttons)
   - Focus: Lines 35-97 (_ready method)
   - Issue: Buttons scrunched to left instead of stretching full width

### Layout Configuration Files

6. **FarmUI.tscn.txt** (1.9 KB)
   - Farm UI scene hierarchy
   - Contains: MainContainer with size_flags_horizontal=3
   - Contains: ActionPreviewRow and ToolSelectionRow with size_flags_horizontal=3
   - All settings appear correct but visual result is wrong

7. **PlayerShell.tscn.txt** (930 B)
   - Root player shell scene
   - Focus: Lines 5-15 (PlayerShell node - fixed to layout_mode=1)
   - Contains: FarmUIContainer, OverlayLayer

8. **FarmUI.gd.txt** (6.6 KB)
   - Farm UI controller
   - Focus: Lines 154-187 (_apply_parametric_sizing method)
   - Uses parametric sizing for responsive layout

9. **PlayerShell.gd.txt** (5.0 KB)
   - Player shell loader
   - Focus: Lines 49-75 (load_farm method)
   - Creates overlay manager and menus

10. **UILayoutManager.gd.txt** (12 KB)
    - Layout system
    - For reference to understand parametric sizing system

## Key Observations

### What's Correct (But Not Working)
```gdscript
// EscapeMenu centering - textbook correct but produces left-aligned menu
var center = CenterContainer.new()
center.anchor_left = 0.0
center.anchor_top = 0.0
center.anchor_right = 1.0
center.anchor_bottom = 1.0
center.layout_mode = 1  // LAYOUT_MODE_FULLRECT
add_child(center)
```

```gdscript
// Button stretching - correctly configured but buttons don't stretch
button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
```

```gdscript
// Scene file - correct configuration
[node name="MainContainer" type="VBoxContainer" parent="."]
size_flags_horizontal = 3  // SIZE_EXPAND_FILL

[node name="ActionPreviewRow" type="HBoxContainer" parent="MainContainer"]
size_flags_horizontal = 3  // SIZE_EXPAND_FILL
```

### Pattern of Failure
- ✅ Syntax correct
- ✅ Follows Godot 4 documentation
- ✅ Matches recommended patterns
- ❌ Zero visual effect across iterations

This pattern suggests:
- Godot 4.5 version-specific issue
- Fundamental architectural problem with scene-based composition
- Undocumented behavior in layout system
- Missing initialization or signal connection

## Questions for External Reviewer

1. Is there a known Godot 4.5 regression with CenterContainer centering?
2. Does `set_process_input(false)` actually prevent `_input()` from being called?
3. Why would HBoxContainer with SIZE_EXPAND_FILL not stretch children?
4. Is there an issue with scene-based composition (`.instantiate()`) and layout inheritance?
5. Could there be missing initialization in the layout cascade?

## Environment
- **Engine:** Godot 4.5.stable (876b29033)
- **Language:** GDScript
- **Platform:** Linux/WSL2
- **Game:** SpaceWheat (Quantum Farm Conspiracy Simulator)

## Export Date
December 24, 2025

---

**Note:** This export is for detailed external code review. The issue appears to be architectural rather than a simple bug, requiring fresh perspective on Godot 4's layout and input systems.
