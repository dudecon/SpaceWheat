# UI Display Investigation Export

**Date:** 2026-01-05
**Purpose:** Complete investigation of broken UI display system

---

## What's In This Folder

### Documentation:
1. **UI_DISPLAY_SUMMARY.md** - Complete visual hierarchy, issues, and investigation
2. **README.md** (this file) - Guide to the export

### Core UI Scripts (renamed .gd → .gd.txt):
- `PlayerShell.gd.txt` - Root UI container and orchestration
- `PlayerShell.tscn.txt` - PlayerShell scene structure
- `FarmView.gd.txt` - Viewport and root setup
- `FarmUI.gd.txt` - Main farm interface
- `FarmUI.tscn.txt` - Farm UI scene structure
- `PlotGridDisplay.gd.txt` - Plot tile grid manager

### Broken Components (Action Bars):
- `ActionPreviewRow.gd.txt` - QER action buttons (WRONG POSITION)
- `ToolSelectionRow.gd.txt` - 1-6 tool buttons (WRONG POSITION)

### Working Components (Overlays):
- `OverlayManager.gd.txt` - Manages all overlay panels
- `QuestBoard.gd.txt` - Quest interface (WORKS)
- `EscapeMenu.gd.txt` - Pause menu (WORKS)
- `SaveLoadMenu.gd.txt` - Save/load interface (WORKS)
- `KeyboardHintButton.gd.txt` - Keyboard help button (NOT VISIBLE)

### Visualization:
- `BathQuantumVisualizationController.gd.txt` - Quantum biome renderer (WORKS)

---

## TL;DR - The Problem

**User sees:**
- ✅ Overlays work (quest board, ESC menu, etc.)
- ✅ Biome visualization works
- ❌ **Action bars (QER buttons) - HALF OFF SCREEN TOP-LEFT** (should be bottom center)
- ❌ **Tool selection (1-6 tools) - HALF OFF SCREEN TOP-LEFT** (should be bottom center)
- ❌ **Keyboard hints button - NOT VISIBLE** (should be upper right)

**What we've tried:**
1. Clearing container properties when reparenting ✅
2. Using `set_deferred()` ❌
3. Using `await get_tree().process_frame` ❌
4. Multiple timing strategies ❌

**ALL FAILED - Bars still in wrong position**

---

## The Core Issue: Dynamic Reparenting

### What Happens:
1. ActionPreviewRow and ToolSelectionRow created in **FarmUI.tscn** as children of **VBoxContainer**
2. At runtime, moved to **ActionBarLayer** (plain Control) for z-ordering
3. Container properties (layout_mode=2, size_flags) cleared
4. Anchors set to PRESET_BOTTOM_WIDE
5. **FAILS** - Bars appear half off screen in top-left instead of bottom center

### Code Location:
- Reparenting: `PlayerShell.gd:333-375`
- Positioning: `PlayerShell.gd:378-396`

---

## Files to Review (Priority Order)

### Priority 1 (Broken Components):
1. **PlayerShell.gd.txt** - Lines 333-396 (reparenting logic)
2. **ActionPreviewRow.gd.txt** - The QER button bar
3. **ToolSelectionRow.gd.txt** - The 1-6 tool bar
4. **PlayerShell.tscn.txt** - ActionBarLayer structure

### Priority 2 (Context):
5. **FarmUI.tscn.txt** - Where bars are originally created
6. **FarmUI.gd.txt** - Farm UI setup
7. **UI_DISPLAY_SUMMARY.md** - Complete investigation

### Priority 3 (Working Examples):
8. **OverlayManager.gd.txt** - See how overlays position correctly
9. **KeyboardHintButton.gd.txt** - Another positioning issue (not visible)

---

## Key Code Snippets

### The Reparenting (PlayerShell.gd:349-371)
```gdscript
# Remove from VBoxContainer
var action_bar = current_farm_ui.get_node_or_null("MainContainer/ActionPreviewRow")
if action_bar:
    main_container.remove_child(action_bar)
    action_bar_layer.add_child(action_bar)

    # Clear container properties
    action_bar.layout_mode = 1  # Anchors mode
    action_bar.size_flags_horizontal = Control.SIZE_FILL
    action_bar.size_flags_vertical = Control.SIZE_FILL

    action_preview_row = action_bar

# Call deferred positioning
_position_action_bars_deferred.call_deferred()
```

### The Positioning (PlayerShell.gd:378-396)
```gdscript
func _position_action_bars_deferred() -> void:
    """Position action bars after ActionBarLayer is sized"""
    # Wait for layout pass
    await get_tree().process_frame

    # Set bottom-center anchors
    if action_preview_row:
        action_preview_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        action_preview_row.offset_top = -80
        action_preview_row.offset_bottom = 0
        action_preview_row.custom_minimum_size = Vector2(0, 80)
```

**RESULT:** ❌ Bars appear half off screen in top-left

---

## Questions That Need Answers

1. **Is dynamic reparenting viable in Godot 4.5?**
   - Should we create bars in ActionBarLayer from the start?
   - Is there a proper way to "reset" a reparented node?

2. **Why doesn't `await get_tree().process_frame` work?**
   - Is ActionBarLayer not sized after one frame?
   - Should we wait for multiple frames?
   - Is there a better signal to await?

3. **What properties persist when reparenting?**
   - We clear layout_mode and size_flags
   - Is there something else?
   - Transform? Position? Cached sizes?

4. **Why is KeyboardHintButton not visible?**
   - Logs show it's created
   - Z-index issue? Position calculation? Parent clipping?

5. **What's the correct Godot 4.5 pattern?**
   - For bottom-anchored toolbars
   - For dynamic UI repositioning
   - For z-layering with Control nodes

---

## Diagnostic Information

### From Boot Logs:
```
⌨️  KeyboardHintButton initialized (upper right)
⌨️  Keyboard hint button created (K to toggle)
```
→ Button IS created but NOT visible

```
✅ Both toolbars moved to ActionBarLayer (positioning next frame)
✅ ActionPreviewRow positioned at bottom center
✅ ToolSelectionRow positioned above action bar
```
→ Code THINKS it positioned correctly, but it didn't

### Z-Index Hierarchy (Intended):
```
-10    PlotGridDisplay (plots)
50     Biome visualization
100    FarmUI MainContainer
1000   OverlayLayer
1000   KeyboardHintButton (same as parent)
1500   TouchButtonBar
3000   ActionBarLayer ← BROKEN
3500   EscapeMenu
4000   SaveLoadMenu
```

---

## Recommended Next Steps

1. **Add debug logging**
   - Print ActionBarLayer.size when positioning
   - Print action_bar.global_position after setting anchors
   - Print action_bar.size after positioning

2. **Test direct creation**
   - Create ActionPreviewRow directly in ActionBarLayer.gd
   - Skip reparenting entirely
   - See if positioning works

3. **Test fixed positioning**
   - Instead of anchors, use:
     ```gdscript
     action_bar.position = Vector2(0, viewport_height - 80)
     action_bar.size = Vector2(viewport_width, 80)
     ```
   - See if problem is anchor-specific

4. **Investigate KeyboardHintButton**
   - Add debug to check if button exists in tree
   - Print button.global_position
   - Print button.visible and button.modulate

---

## Status

🔴 **CRITICAL - UI COMPLETELY BROKEN**

Multiple attempts to fix positioning have failed. Need expert Godot 4.5 guidance on:
- Dynamic reparenting patterns
- Anchor-based positioning
- Z-index layering with Control nodes
- Proper timing for layout operations

**All code and scene files exported for investigation.**
