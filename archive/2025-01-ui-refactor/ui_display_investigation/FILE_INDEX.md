# File Index - UI Display Investigation

**Export Date:** 2026-01-05
**Total Files:** 17
**Total Size:** 260KB

---

## Start Here

1. **README.md** (6.7KB) - Overview and guide
2. **UI_DISPLAY_SUMMARY.md** (15KB) - Complete investigation with visual hierarchy
3. **DIAGNOSTIC_SCRIPT.gd.txt** (5.1KB) - Debug helper functions

---

## Core Files (Broken Components)

### PlayerShell - Root UI Container
- **PlayerShell.gd.txt** (14KB) - ⚠️ CRITICAL - Lines 333-396 contain failed reparenting logic
- **PlayerShell.tscn.txt** (1.1KB) - Scene structure with ActionBarLayer

**Key issues:**
- _move_action_bar_to_top_layer() (lines 333-375)
- _position_action_bars_deferred() (lines 378-396)
- Multiple timing strategies all failed

### Action Bars - Bottom Toolbars (BROKEN)
- **ActionPreviewRow.gd.txt** (12KB) - QER action buttons (half off screen top-left)
- **ToolSelectionRow.gd.txt** (7.8KB) - 1-6 tool buttons (half off screen top-left)

**Status:** ❌ Should be bottom center, appearing top-left instead

### Farm UI - Main Interface
- **FarmUI.gd.txt** (13KB) - Farm interface setup
- **FarmUI.tscn.txt** (2.0KB) - Scene where ActionPreviewRow/ToolSelectionRow originally created
- **FarmView.gd.txt** (7.2KB) - Root viewport setup
- **PlotGridDisplay.gd.txt** (37KB) - Plot tile grid (working correctly)

---

## Working Components (For Reference)

### Overlays - Fullscreen Panels
- **OverlayManager.gd.txt** (36KB) - ✅ Manages all overlays successfully
- **QuestBoard.gd.txt** (26KB) - ✅ Quest interface (works correctly)
- **EscapeMenu.gd.txt** (7.0KB) - ✅ Pause menu (works correctly)
- **SaveLoadMenu.gd.txt** (18KB) - ✅ Save/load interface (works correctly)

**Note:** These position correctly - can be used as examples

### Keyboard Hints - Missing UI Element
- **KeyboardHintButton.gd.txt** (5.8KB) - ❌ Button created but NOT VISIBLE

**Status:** Logs show creation, user doesn't see it

### Biome Visualization
- **BathQuantumVisualizationController.gd.txt** (19KB) - ✅ Quantum biome renderer (works correctly)

**Note:** Uses CanvasLayer instead of Control nodes

---

## Files by Size (Largest First)

| Size | File | Status |
|------|------|--------|
| 37KB | PlotGridDisplay.gd.txt | ✅ Working |
| 36KB | OverlayManager.gd.txt | ✅ Working (reference) |
| 26KB | QuestBoard.gd.txt | ✅ Working (reference) |
| 19KB | BathQuantumVisualizationController.gd.txt | ✅ Working |
| 18KB | SaveLoadMenu.gd.txt | ✅ Working (reference) |
| 15KB | UI_DISPLAY_SUMMARY.md | 📄 Investigation doc |
| 14KB | PlayerShell.gd.txt | ❌ BROKEN - main issue |
| 13KB | FarmUI.gd.txt | ℹ️ Context |
| 12KB | ActionPreviewRow.gd.txt | ❌ BROKEN |
| 7.8KB | ToolSelectionRow.gd.txt | ❌ BROKEN |
| 7.2KB | FarmView.gd.txt | ℹ️ Context |
| 7.0KB | EscapeMenu.gd.txt | ✅ Working (reference) |
| 6.7KB | README.md | 📄 Guide |
| 5.8KB | KeyboardHintButton.gd.txt | ❌ Not visible |
| 5.1KB | DIAGNOSTIC_SCRIPT.gd.txt | 🔧 Debug tool |
| 2.0KB | FarmUI.tscn.txt | ℹ️ Scene structure |
| 1.1KB | PlayerShell.tscn.txt | ℹ️ Scene structure |

---

## Investigation Priority

### Priority 1 - Fix Action Bar Positioning
1. Read **UI_DISPLAY_SUMMARY.md** (complete context)
2. Review **PlayerShell.gd.txt** lines 333-396 (the broken code)
3. Check **PlayerShell.tscn.txt** (ActionBarLayer definition)
4. Compare with **OverlayManager.gd.txt** (working positioning examples)

### Priority 2 - Fix Keyboard Hints Visibility
5. Review **KeyboardHintButton.gd.txt** (button creation)
6. Check **OverlayManager.gd.txt** lines 172-178 (where it's added)
7. Use **DIAGNOSTIC_SCRIPT.gd.txt** to debug visibility

### Priority 3 - Understand Working Examples
8. Study **OverlayManager.gd.txt** (how overlays position correctly)
9. Study **QuestBoard.gd.txt** (working center positioning)
10. Study **EscapeMenu.gd.txt** (working fullscreen overlay)

---

## Key Code Locations

### Broken Reparenting (PlayerShell.gd.txt)
- Lines 333-375: `_move_action_bar_to_top_layer()`
  - Removes bars from VBoxContainer
  - Adds to ActionBarLayer
  - Clears container properties
  - Calls deferred positioning

- Lines 378-396: `_position_action_bars_deferred()`
  - Awaits process_frame
  - Sets PRESET_BOTTOM_WIDE anchors
  - **FAILS** - bars appear in wrong position

### Scene Definitions
- PlayerShell.tscn.txt: ActionBarLayer with z_index 3000
- FarmUI.tscn.txt: Original location of action bars (in VBoxContainer)

### Working Examples
- OverlayManager.gd.txt lines 120-140: QuestBoard positioning (WORKS)
- OverlayManager.gd.txt lines 156-170: EscapeMenu positioning (WORKS)
- OverlayManager.gd.txt lines 770-832: TouchButtonBar left-center (WORKS)

---

## Debug Tools

### DIAGNOSTIC_SCRIPT.gd.txt
Add these functions to PlayerShell.gd for debugging:

```gdscript
_debug_action_bars()        # Print action bar positions/sizes
_debug_keyboard_hints()     # Print keyboard button visibility
_debug_print_ui_hierarchy() # Print entire UI tree
```

Call from _ready() or bind to F12 key for runtime inspection.

---

## Critical Questions

1. **Why does reparenting fail?**
   - Is it a Godot 4.5 limitation?
   - Should we create in ActionBarLayer from start?

2. **Why doesn't `await process_frame` work?**
   - Need more frames?
   - Better signal to await?

3. **What properties persist when reparenting?**
   - We clear layout_mode and size_flags
   - Is there something else?

4. **Why is KeyboardHintButton not visible?**
   - Z-index issue?
   - Position calculation wrong?
   - Parent clipping?

5. **What's the correct Godot 4.5 pattern?**
   - For bottom-anchored toolbars
   - For dynamic repositioning
   - For z-layering

---

## Status

🔴 **CRITICAL - NEEDS EXPERT GUIDANCE**

All code exported and ready for investigation. Multiple fix attempts have failed.

**Need guidance on:**
- Proper dynamic reparenting in Godot 4.5
- Anchor-based positioning timing
- Z-index layering with Control nodes
- Why working examples (overlays) succeed but action bars fail
