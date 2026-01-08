# Visual Issue Diagram

**Date:** 2026-01-05

---

## The Problem (Visual)

### EXPECTED (What Should Happen)

```
┌─────────────────────────────────────────────────┐
│  [🌾 Resources]          [K] Keyboard ← Upper R │ ← ResourcePanel + KeyboardHintButton
│                                                 │
│  [C]                                            │ ← TouchButtonBar (left center)
│  [V]          PLAY AREA                         │
│  [B]          (Plots & Biomes)                  │
│                                                 │
│                                                 │
│                                                 │
│  ┌───────────────────────────────────────────┐  │
│  │  [1] [2] [3] [4] [5] [6]  ← Tool buttons │  │ ← ToolSelectionRow (140px from bottom)
│  └───────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────┐  │
│  │      [Q]    [E]    [R]  ← Action buttons │  │ ← ActionPreviewRow (80px from bottom)
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

### ACTUAL (What User Sees)

```
┌─────────────────────────────────────────────────┐
│🌾 Resources]                             (no K) │ ← KeyboardHintButton MISSING
│[Q][E][R] ← Half off screen!                    │ ← ActionPreviewRow WRONG POSITION
│[1][2][3]                                        │ ← ToolSelectionRow WRONG POSITION
│  [C]                                            │ ← TouchButtonBar (working)
│  [V]          PLAY AREA                         │
│  [B]          (Plots & Biomes work correctly)   │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│               (empty space where bars          │
│                should be)                      │
└─────────────────────────────────────────────────┘
```

---

## Component Status Summary

| Component | Expected Position | Actual Position | Status |
|-----------|-------------------|-----------------|---------|
| ResourcePanel | Top left | Top left | ✅ CORRECT |
| KeyboardHintButton | Top right | ??? | ❌ MISSING |
| TouchButtonBar [C][V][B] | Left center | Left center | ✅ CORRECT |
| Plots & Biomes | Center | Center | ✅ CORRECT |
| ToolSelectionRow [1-6] | Bottom center (140px up) | **Top left** | ❌ WRONG |
| ActionPreviewRow [QER] | Bottom center (80px up) | **Top left** | ❌ WRONG |
| Quest Board (C key) | Center overlay | Center overlay | ✅ CORRECT |
| ESC Menu | Center overlay | Center overlay | ✅ CORRECT |

---

## Positioning Methods Comparison

### ✅ WORKING: TouchButtonBar (Left Center)

**Method:** Direct anchor positioning, created in OverlayManager
```gdscript
var button_bar = VBoxContainer.new()
button_bar.anchor_left = 0.0
button_bar.anchor_right = 0.0
button_bar.anchor_top = 0.5      # Center vertically
button_bar.anchor_bottom = 0.5
button_bar.offset_left = 10
button_bar.offset_right = 80
button_bar.offset_top = -120
button_bar.offset_bottom = 120
button_bar.z_index = 1500
parent.add_child(button_bar)  # Never reparented
```
**Result:** ✅ Works perfectly

### ✅ WORKING: QuestBoard (Center)

**Method:** Direct anchor positioning, created in OverlayManager
```gdscript
quest_board = QuestBoard.new()
quest_board.set_anchors_preset(Control.PRESET_CENTER)
quest_board.custom_minimum_size = Vector2(900, 600)
quest_board.z_index = 1003
parent.add_child(quest_board)  # Never reparented
```
**Result:** ✅ Works perfectly

### ❌ BROKEN: ActionPreviewRow (Bottom Center)

**Method:** Created in .tscn, reparented at runtime, then positioned
```gdscript
# Step 1: Created in FarmUI.tscn as VBoxContainer child
[node name="ActionPreviewRow" type="HBoxContainer" parent="MainContainer"]
layout_mode = 2  # Container child
size_flags_horizontal = 3  # EXPAND_FILL

# Step 2: Reparented at runtime (PlayerShell.gd:349-359)
main_container.remove_child(action_bar)
action_bar_layer.add_child(action_bar)
action_bar.layout_mode = 1  # Try to clear container properties
action_bar.size_flags_horizontal = Control.SIZE_FILL

# Step 3: Positioned in deferred function (PlayerShell.gd:378-396)
await get_tree().process_frame
action_preview_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
action_preview_row.offset_top = -80
action_preview_row.offset_bottom = 0
```
**Result:** ❌ Appears half off screen in top-left instead of bottom center

---

## The Key Difference

### WORKING Components:
- ✅ Created directly in OverlayManager.gd (code)
- ✅ Added to parent ONCE
- ✅ NEVER reparented
- ✅ Position set IMMEDIATELY when created
- ✅ No timing issues

### BROKEN Components:
- ❌ Created in FarmUI.tscn (scene file)
- ❌ Originally children of VBoxContainer
- ❌ REPARENTED at runtime to ActionBarLayer
- ❌ Position set AFTER reparenting (deferred + await)
- ❌ Timing issues, property conflicts

---

## Hypothesis: Reparenting is the Problem

**Evidence:**
1. All working components created in final parent
2. All broken components reparented from different parent
3. Reparented nodes retain hidden properties
4. Even with `await process_frame`, positioning fails

**Possible causes:**
- Transform/position cached from old parent
- Size calculated before parent is ready
- Anchors not being respected after reparenting
- Hidden layout properties not being cleared

---

## Proposed Solutions to Test

### Solution 1: Create in ActionBarLayer from Start
Instead of creating in FarmUI.tscn and reparenting:
```gdscript
# In PlayerShell._ready() or FarmUI._ready()
var action_bar = preload("res://UI/Panels/ActionPreviewRow.gd").new()
action_bar_layer.add_child(action_bar)
action_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
action_bar.offset_top = -80
action_bar.offset_bottom = 0
```
**Skip reparenting entirely**

### Solution 2: Wait Multiple Frames
```gdscript
await get_tree().process_frame
await get_tree().process_frame  # Second frame
await get_tree().process_frame  # Third frame
# Then position
```
**Give layout engine more time**

### Solution 3: Use Fixed Positioning Instead of Anchors
```gdscript
var viewport_size = get_viewport().get_visible_rect().size
action_bar.position = Vector2(0, viewport_size.y - 80)
action_bar.size = Vector2(viewport_size.x, 80)
# No anchors, explicit pixel positioning
```
**Bypass anchor system entirely**

### Solution 4: Reset All Properties
```gdscript
# After reparenting, reset EVERYTHING
action_bar.layout_mode = 0  # Try mode 0 (position)
action_bar.position = Vector2.ZERO
action_bar.size = Vector2.ZERO
action_bar.anchor_left = 0.0
action_bar.anchor_right = 0.0
action_bar.anchor_top = 0.0
action_bar.anchor_bottom = 0.0
action_bar.offset_left = 0
action_bar.offset_right = 0
action_bar.offset_top = 0
action_bar.offset_bottom = 0
# Then set desired position
```
**Complete property reset**

---

## Files Containing Evidence

1. **OverlayManager.gd.txt** - Lines 770-832
   - TouchButtonBar creation (WORKS)
   - Shows direct creation pattern

2. **OverlayManager.gd.txt** - Lines 120-140
   - QuestBoard creation (WORKS)
   - Shows center positioning pattern

3. **PlayerShell.gd.txt** - Lines 333-396
   - Action bar reparenting (BROKEN)
   - Shows failed reparenting pattern

4. **FarmUI.tscn.txt**
   - Original location of action bars
   - Shows VBoxContainer properties

5. **PlayerShell.tscn.txt**
   - ActionBarLayer definition
   - Shows target parent structure

---

## Debug Questions to Answer

1. **What is ActionBarLayer.size when positioning happens?**
   - Print it in _position_action_bars_deferred()
   - Is it zero? Is it final size?

2. **What is action_preview_row.global_position after setting anchors?**
   - Should be near bottom of screen
   - Actually where is it?

3. **Do the anchors actually get set?**
   - Print anchor values after set_anchors_preset()
   - Are they (0,1) to (1,1) as expected?

4. **What properties still have old values?**
   - Print ALL properties before and after reparenting
   - Look for anything unexpected

---

## Recommended Investigation Steps

1. Add debug prints to _position_action_bars_deferred():
   ```gdscript
   print("ActionBarLayer size: %s" % action_bar_layer.size)
   print("Viewport size: %s" % get_viewport().get_visible_rect().size)
   print("Before positioning - action_bar global_pos: %s" % action_bar.global_position)

   action_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
   action_bar.offset_top = -80

   print("After positioning - action_bar global_pos: %s" % action_bar.global_position)
   print("After positioning - action_bar anchors: %.1f,%.1f to %.1f,%.1f" % [
       action_bar.anchor_left,
       action_bar.anchor_top,
       action_bar.anchor_right,
       action_bar.anchor_bottom
   ])
   ```

2. Test creating directly in ActionBarLayer (skip reparenting)

3. Compare with working TouchButtonBar code

4. Try fixed positioning instead of anchors

---

**Status:** Investigation complete, all evidence exported for analysis.
