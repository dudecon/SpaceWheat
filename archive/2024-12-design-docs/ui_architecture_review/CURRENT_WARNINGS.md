# Current UI Warnings & Errors

**Date:** 2026-01-04

---

## Primary Warning: Anchor/Size Conflicts

### Full Warning Message:
```
WARNING: Nodes with non-equal opposite anchors will have their size overridden after _ready().
If you want to set size, change the anchors or consider using set_deferred().
     at: _set_size (scene/gui/control.cpp:1476)
     GDScript backtrace (most recent call first):
         [0] _layout_elements (res://UI/PlotTile.gd:439)
         [1] _ready (res://UI/PlotTile.gd:86)
         [2] _create_tiles (res://UI/PlotGridDisplay.gd:319)
         [3] inject_layout_calculator (res://UI/PlotGridDisplay.gd:152)
         [4] _stage_ui (res://Core/Boot/BootManager.gd:131)
```

### What Triggers It:
PlotTile.gd line 439 in `_layout_elements()`:
```gdscript
func _layout_elements(layout_calc) -> void:
    # ... setup code ...

    # Territory border - ANCHOR-BASED positioning
    territory_border.anchor_left = 0.0
    territory_border.anchor_right = 1.0
    territory_border.anchor_top = 0.0
    territory_border.anchor_bottom = 1.0

    # ⚠️ WARNING HAPPENS HERE - setting size with non-equal anchors
    territory_border.size = tile_size  # CONFLICTS with anchors!

    # Similar for other child elements...
    selection_border.size = tile_size
    emoji_label_north.size = tile_size
    # etc.
```

### Why It's Wrong:
- When `anchor_left ≠ anchor_right` (0.0 vs 1.0), the node's width is determined by the anchors
- Setting `size` directly conflicts with this
- Godot overrides the size after `_ready()` completes
- Result: Size is ignored, or position breaks

### Happens Frequently In:
1. PlotTile._layout_elements() - Every plot tile (6+ elements per tile)
2. PlotGridDisplay._create_tiles() - Creates all tiles
3. Any UI element using anchors + explicit size

---

## Secondary Issue: Toolbar Positioning Failure

### Expected Behavior:
- ActionPreviewRow (QER buttons): Bottom center, 80px from bottom
- ToolSelectionRow (1-6 tools): Bottom center, 140px from bottom

### Actual Behavior:
- ActionPreviewRow: Upper left corner
- ToolSelectionRow: Upper left corner

### Code That Should Work But Doesn't:
PlayerShell.gd lines 370-378:
```gdscript
# Using set_deferred to avoid conflicts
action_bar.set_deferred("anchor_left", 0.0)
action_bar.set_deferred("anchor_right", 1.0)
action_bar.set_deferred("anchor_top", 1.0)      # Bottom anchor
action_bar.set_deferred("anchor_bottom", 1.0)   # Bottom anchor
action_bar.set_deferred("offset_left", 0)
action_bar.set_deferred("offset_right", 0)
action_bar.set_deferred("offset_top", -80)      # 80px from bottom
action_bar.set_deferred("offset_bottom", 0)
action_bar.set_deferred("custom_minimum_size", Vector2(0, 80))
```

### Why It Fails:
1. Node was originally in VBoxContainer (FarmUI/MainContainer)
2. Has `layout_mode = 2` from scene file
3. Has `size_flags_horizontal/vertical` from being in container
4. When moved to ActionBarLayer (plain Control), these properties persist
5. set_deferred() is too late - layout already calculated
6. Properties from old parent conflict with new positioning

---

## Code Pattern That Causes Issues

### ❌ ANTI-PATTERN (What We're Doing):

**In .tscn file:**
```tscn
[node name="ActionPreviewRow" type="HBoxContainer" parent="MainContainer"]
layout_mode = 2
size_flags_horizontal = 3
custom_minimum_size = Vector2(0, 80)
```

**In runtime code:**
```gdscript
# Remove from VBoxContainer parent
main_container.remove_child(action_bar)

# Add to Control parent
action_bar_layer.add_child(action_bar)

# Try to reposition (FAILS - old properties persist)
action_bar.set_deferred("anchor_top", 1.0)  # Doesn't work!
```

**Result:** Node keeps `layout_mode = 2` and `size_flags` from scene, which are meaningless in new parent.

---

## Sizing Conflicts Matrix

| Scenario | Anchors | Size Flags | Custom Min Size | Result |
|----------|---------|------------|-----------------|---------|
| VBoxContainer child | N/A | EXPAND_FILL | Vector2(0, 80) | ✅ Works |
| Control with anchors | (0,0) to (1,1) | N/A | N/A | ✅ Works |
| Control with anchors | (0,0) to (1,1) | N/A | Vector2(0, 80) | ⚠️ WARNING |
| Moved from container | (0,0) to (1,1) | EXPAND_FILL | Vector2(0, 80) | ❌ BREAKS |
| Set after _ready() | (0,0) to (1,1) | N/A | Vector2(0, 80) | ⚠️ Too late |
| set_deferred() | (0,0) to (1,1) | N/A | Vector2(0, 80) | ❓ Unreliable |

---

## Call Stack When Warning Occurs

```
1. BootManager._stage_ui()
   └─> Calls inject_layout_calculator()

2. PlotGridDisplay.inject_layout_calculator()
   └─> Calls _create_tiles()

3. PlotGridDisplay._create_tiles()
   └─> For each tile: instantiates PlotTile

4. PlotTile._ready()
   └─> Calls _layout_elements()

5. PlotTile._layout_elements()
   └─> Sets size on elements with non-equal anchors
       ⚠️ WARNING TRIGGERED HERE

6. Godot engine (control.cpp:1476)
   └─> Detects conflict, prints warning
   └─> Overrides size property
```

---

## Specific Problem Nodes

### PlotTile Elements (6 per tile):
```gdscript
# All of these trigger warnings:
territory_border.size = tile_size       # Has anchors (0,0) to (1,1)
selection_border.size = tile_size       # Has anchors (0,0) to (1,1)
emoji_label_north.size = tile_size      # Has anchors (0,0) to (1,1)
emoji_label_south.size = tile_size      # Has anchors (0,0) to (1,1)
number_label.size = tile_size          # Has anchors (0,0) to (1,1)
center_state_indicator.size = tile_size # Has anchors (0,0) to (1,1)
```

**Why we do this:**
- Tiles need to be specific size (calculated from grid)
- Also need to fill their parent (hence anchors)
- These two requirements conflict

---

## Attempted Fixes & Results

### Fix Attempt 1: Use set_deferred()
```gdscript
territory_border.set_deferred("size", tile_size)
```
**Result:** ❌ Still warns, doesn't help

### Fix Attempt 2: Only set anchors, no size
```gdscript
# Remove: territory_border.size = tile_size
# Keep: anchors only
```
**Result:** ❓ Untested - might fix warnings but break sizing

### Fix Attempt 3: Use custom_minimum_size instead
```gdscript
territory_border.custom_minimum_size = tile_size
```
**Result:** ⚠️ Different warning, still conflicts

### Fix Attempt 4: Remove anchors, use only size
```gdscript
# Remove anchor settings
territory_border.size = tile_size
territory_border.position = Vector2.ZERO
```
**Result:** ❓ Untested - might not respond to parent size changes

---

## Questions for Resolution

1. **For PlotTile elements:**
   - Should we use anchors OR size, not both?
   - If anchors, how do we ensure specific tile size?
   - If size, how do we ensure they fill the tile?

2. **For dynamic reparenting (ActionPreviewRow):**
   - Should we create nodes in code instead of .tscn?
   - How to clear layout properties from old parent?
   - Is there a "reset layout mode" function?

3. **For deferred positioning:**
   - Does set_deferred() actually help here?
   - Or is it just delaying the inevitable conflict?
   - What's the right frame to set positioning?

4. **General:**
   - Is there a Godot-approved pattern for our use case?
   - What do well-architected Godot games do?
   - Should we refactor the entire UI system?

---

## Files With Sizing Issues

**High Priority (cause warnings):**
- `UI/PlotTile.gd` - Lines 439-500
- `UI/PlotGridDisplay.gd` - Lines 319-350

**Medium Priority (positioning broken):**
- `UI/PlayerShell.gd` - Lines 331-405
- `UI/FarmUI.gd` - Lines 61-75

**Low Priority (potential future issues):**
- `UI/Managers/OverlayManager.gd` - Lines 770-832
- `UI/Panels/KeyboardHintButton.gd` - Lines 19-38, 73-81

---

**Next Steps:** Need expert Godot UI architecture review to determine correct patterns.
