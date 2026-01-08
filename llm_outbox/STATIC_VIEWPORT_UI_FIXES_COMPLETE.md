# Static Viewport UI Fixes Complete

**Date**: 2026-01-05
**Status**: ✅ All UI elements restored and working at 960×540 base resolution

## Problems Fixed

After transitioning to static viewport (960×540), several UI elements were broken or missing:

1. ❌ Top bar (ResourcePanel) invisible - only 3.8px tall instead of ~32px
2. ❌ Quest Oracle (Quest Board) starting too high - not respecting play zone
3. ❌ ESC menu pasted to left side - not centered
4. ❌ CVN touch buttons nowhere to be found
5. ❌ Keyboard hint missing from upper right

---

## Fix #1: Top Bar (ResourcePanel) - UILayoutManager Base Resolution

**Problem**: UILayoutManager was using wrong base resolution and viewport query method
- BASE_RESOLUTION was still 1920×1080 (old value)
- Viewport query used `get_viewport().size` (window size) instead of `get_visible_rect().size` (logical viewport)
- Result: Top bar calculated as 3.8px instead of 32.4px (6% of viewport)

**File**: `UI/Managers/UILayoutManager.gd`

**Changes**:
```gdscript
# Line 12: Updated base resolution
-const BASE_RESOLUTION = Vector2(1920, 1080)
+const BASE_RESOLUTION = Vector2(960, 540)  # Static viewport base resolution

# Line 110: Fixed viewport query for canvas_items stretch mode
-viewport_size = get_viewport().size
+viewport_size = get_viewport().get_visible_rect().size  # Logical viewport (960×540 with canvas_items)
```

**Result**:
- ✅ Top bar now 32.4px (6% of 540)
- ✅ Viewport recognized as (960, 540) instead of (64, 64)
- ✅ Scale factor 1.00× (correct for base resolution)

---

## Fix #2: Quest Oracle Positioning - Respect Play Zone

**Problem**: Quest Board filled entire viewport (0,0 to 960×540), ignoring top bar
- CenterContainer used `PRESET_FULL_RECT`, centering in full viewport
- Should center in play zone (starting at 6% down, below top bar)

**File**: `UI/Panels/QuestBoard.gd`

**Changes** (lines 170-183):
```gdscript
# Before: Full screen centering
var center = CenterContainer.new()
center.set_anchors_preset(Control.PRESET_FULL_RECT)

# After: Play zone centering (below top bar)
var center = CenterContainer.new()
center.anchor_left = 0.0
center.anchor_right = 1.0
center.anchor_top = 0.06  # Start at 6% (below top bar)
center.anchor_bottom = 1.0
center.offset_left = 0
center.offset_right = 0
center.offset_top = 0
center.offset_bottom = 0
```

**Result**:
- ✅ Quest Board now centered in play zone
- ✅ Top bar remains visible when Quest Board opens
- ✅ Proper visual hierarchy: top bar → play zone → modals

---

## Fix #3: ESC Menu Centering - Manual Anchor Positioning

**Problem**: ESC menu using CenterContainer with PRESET_FULL_RECT caused warning
- "Nodes with non-equal opposite anchors will have their size overridden after _ready()"
- CenterContainer + custom_minimum_size conflict
- Menu appeared stuck on left side

**File**: `UI/Panels/EscapeMenu.gd`

**Changes** (lines 31-53):
```gdscript
# Before: CenterContainer approach (caused conflicts)
var center = CenterContainer.new()
center.set_anchors_preset(Control.PRESET_FULL_RECT)
add_child(center)
var menu_panel = PanelContainer.new()
menu_panel.custom_minimum_size = Vector2(450, 500)
center.add_child(menu_panel)

# After: Manual centering with anchors
var menu_panel = PanelContainer.new()
menu_panel.custom_minimum_size = Vector2(450, 500)
# Center at 50% horizontal and vertical using anchors
menu_panel.anchor_left = 0.5
menu_panel.anchor_right = 0.5
menu_panel.anchor_top = 0.5
menu_panel.anchor_bottom = 0.5
# Offset by half the size to truly center
menu_panel.offset_left = -225  # -450/2
menu_panel.offset_right = 225   # +450/2
menu_panel.offset_top = -250    # -500/2
menu_panel.offset_bottom = 250  # +500/2
menu_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
menu_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
add_child(menu_panel)
```

**Result**:
- ✅ ESC menu properly centered horizontally and vertically
- ✅ No anchor warnings
- ✅ Works correctly with static viewport scaling

---

## Fix #4: CVN Buttons + Keyboard Hint - Godot 3 → 4 Anchor Syntax

**Problem**: OverlayLayer and ActionBarLayer used old Godot 3 anchor syntax
- Properties: `anchors_left`, `anchors_top`, etc. (with 's')
- Godot 4 uses: `anchor_left`, `anchor_top`, etc. (without 's')
- Result: Layers didn't size/position correctly, hiding child elements

**File**: `UI/PlayerShell.tscn`

**Changes**:

### OverlayLayer (lines 36-46):
```ini
# Before (Godot 3 syntax):
[node name="OverlayLayer" type="Control" parent="."]
layout_mode = 1
anchors_left = 0.0
anchors_top = 0.0
anchors_right = 1.0
anchors_bottom = 1.0
z_index = 1000

# After (Godot 4 syntax):
[node name="OverlayLayer" type="Control" parent="."]
layout_mode = 1
anchor_left = 0.0
anchor_top = 0.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 0.0
offset_top = 0.0
offset_right = 0.0
offset_bottom = 0.0
z_index = 1000
```

### ActionBarLayer (lines 48-57):
```ini
# Before (Godot 3 syntax):
[node name="ActionBarLayer" type="Control" parent="."]
layout_mode = 1
anchors_left = 0.0
anchors_top = 0.0
anchors_right = 1.0
anchors_bottom = 1.0

# After (Godot 4 syntax):
[node name="ActionBarLayer" type="Control" parent="."]
layout_mode = 1
anchor_left = 0.0
anchor_top = 0.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 0.0
offset_top = 0.0
offset_right = 0.0
offset_bottom = 0.0
```

**Result**:
- ✅ OverlayLayer now fills viewport correctly
- ✅ CVN touch buttons (📖=V, 📋=C, ☰=ESC) visible on right side
- ✅ Keyboard hint button (K key) visible in upper right
- ✅ Touch button bar positioned at right center (z_index 4090)

---

## Testing Results

### Final Boot Test (960×540):

```
✅ Viewport: 960 × 540
✅ UILayoutManager: Viewport=(960.0, 540.0), Scale=1.00×, Breakpoint=FHD
✅ Top bar: 32.4px (0% to 6%)
✅ ResourcePanel connected to economy.resource_changed
✅ ResourcePanel wired to economy
✅ Quest Board created (press C to toggle - modal 4-slot system)
✅ Escape menu created (ESC to toggle)
✅ Keyboard hint button created (top-right)
✅ Touch button bar created (📖=V, 📋=C, ☰=ESC)
```

### Before vs After:

| Element | Before | After |
|---------|--------|-------|
| Top bar height | 3.8px (invisible) | 32.4px (visible ✅) |
| Quest Board position | Full viewport | Play zone (below top bar ✅) |
| ESC menu | Stuck on left | Centered ✅ |
| CVN buttons | Missing | Visible on right ✅ |
| Keyboard hint | Missing | Visible upper right ✅ |
| Viewport recognition | (64, 64) wrong | (960, 540) correct ✅ |

---

## Files Modified

1. **UI/Managers/UILayoutManager.gd**
   - Updated BASE_RESOLUTION to 960×540
   - Fixed viewport query to use `get_visible_rect().size`

2. **UI/Panels/QuestBoard.gd**
   - Changed CenterContainer to respect play zone (anchor_top = 0.06)

3. **UI/Panels/EscapeMenu.gd**
   - Removed CenterContainer approach
   - Implemented manual centering with anchors and offsets

4. **UI/PlayerShell.tscn**
   - Fixed OverlayLayer: Godot 3 → 4 anchor syntax
   - Fixed ActionBarLayer: Godot 3 → 4 anchor syntax
   - Added proper offset values

---

## Key Learnings

### 1. Static Viewport Queries
With Godot's `canvas_items` stretch mode:
- ✅ Use `get_viewport().get_visible_rect().size` for logical viewport (960×540)
- ❌ NOT `get_viewport().size` (returns window size, variable)

### 2. BASE_RESOLUTION Consistency
All layout managers must use the same base resolution as project.godot:
- project.godot: `window/size/viewport_width=960, viewport_height=540`
- UILayoutManager: `const BASE_RESOLUTION = Vector2(960, 540)`

### 3. CenterContainer Limitations
CenterContainer + custom_minimum_size can conflict:
- Works: CenterContainer with flexible child sizes
- Breaks: CenterContainer with fixed `custom_minimum_size` on children
- Solution: Use manual anchor positioning (anchor at 0.5, offset by -size/2)

### 4. Godot 3 → 4 Migration
.tscn files may retain old syntax:
- Old: `anchors_left`, `anchors_top` (with 's')
- New: `anchor_left`, `anchor_top` (without 's')
- Must update manually + add `offset_` properties

### 5. Modal Safe Zones
Modals should respect UI layout zones:
- Background: Fill entire viewport (darken everything)
- Content: Center within PLAY ZONE, not full viewport
- Top bar remains visible above all modals

---

## Summary

**Problem**: Static viewport transition (960×540) broke several UI elements due to:
- Wrong base resolution in layout manager (1920×1080 vs 960×540)
- Wrong viewport query method (window size vs logical viewport)
- Godot 3 anchor syntax in .tscn files
- Modals ignoring play zone boundaries
- CenterContainer conflicts with fixed sizes

**Solution**:
1. Updated UILayoutManager to match new base resolution
2. Fixed viewport queries for canvas_items stretch mode
3. Updated modal positioning to respect play zone
4. Replaced CenterContainer with manual anchor centering
5. Migrated .tscn anchor syntax from Godot 3 to 4

**Result**: All UI elements restored and working correctly at 960×540 base resolution with proper Godot canvas_items scaling!
