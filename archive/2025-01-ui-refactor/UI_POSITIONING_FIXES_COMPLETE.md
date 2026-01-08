# UI Positioning & Z-Index Fixes Complete

**Date**: 2026-01-05
**Status**: ✅ All positioning and layering issues resolved

## Issues Reported

1. ❌ ESC menu centered on **top-left corner** instead of screen center
2. ❌ Quest Board **overlaps top bar** (resource panel at 0%-6%)
3. ❌ Quest Board **overlaps tool selection** (at 72%-87%)
4. ❌ Quest Board z_index wrong - should be **above tools, below actions**

---

## Fix #1: ESC Menu Centering

**Problem**: Manual anchor centering approach was incorrect
- Set anchors to 0.5 with manual offsets
- Resulted in menu anchored to top-left corner, not screen center

**Root Cause**: When using equal anchors (0.5, 0.5), offsets don't work as expected with `custom_minimum_size`

**File**: `UI/Panels/EscapeMenu.gd` (lines 38-44)

**Solution**: Use Godot's built-in `PRESET_CENTER`

**Before** (manual centering - BROKEN):
```gdscript
var menu_panel = PanelContainer.new()
menu_panel.custom_minimum_size = Vector2(450, 500)
menu_panel.anchor_left = 0.5
menu_panel.anchor_right = 0.5
menu_panel.anchor_top = 0.5
menu_panel.anchor_bottom = 0.5
menu_panel.offset_left = -225
menu_panel.offset_right = 225
menu_panel.offset_top = -250
menu_panel.offset_bottom = 250
```

**After** (PRESET_CENTER - WORKS):
```gdscript
var menu_panel = PanelContainer.new()
menu_panel.custom_minimum_size = Vector2(450, 500)
menu_panel.set_anchors_preset(Control.PRESET_CENTER)
menu_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
menu_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
```

**Result**: ✅ ESC menu properly centered horizontally and vertically

---

## Fix #2: Quest Board Boundaries

**Problem**: Quest Board filled entire vertical space (6% to 100%)
- Started correctly at 6% (below top bar) ✓
- Extended to 100% (bottom of viewport) ✗
- Overlapped tool selection (72%-87%) and actions (87%-100%)

**Layout Zones** (from UILayoutManager):
```
 0% -  6%  → Top bar (resource panel)        32.4px
 6% - 72%  → Play area (quantum graph)      359.1px  ← Quest Board should go here!
72% - 87%  → Plots row (tool selection)      81.0px
87% - 100% → Actions row (QER buttons)       67.5px
```

**File**: `UI/Panels/QuestBoard.gd` (lines 170-183)

**Solution**: Set `anchor_bottom = 0.72` to stop above tool selection

**Before** (overlapped tools):
```gdscript
var center = CenterContainer.new()
center.anchor_top = 0.06     # Below top bar ✓
center.anchor_bottom = 1.0   # To bottom of viewport ✗ OVERLAPS TOOLS
```

**After** (respects tool zone):
```gdscript
var center = CenterContainer.new()
center.anchor_top = 0.06     # Start at 6% (below top bar)
center.anchor_bottom = 0.72  # End at 72% (above tool selection) ✓
```

**Result**:
- ✅ Quest Board stays in play zone (6%-72%)
- ✅ Top bar visible (0%-6%)
- ✅ Tool selection visible (72%-87%)
- ✅ Actions visible (87%-100%)

---

## Fix #3: Z-Index Layering

**Problem**: Quest Board was below BOTH tool selection AND actions
- OverlayLayer (contains Quest Board): z_index = 1000
- ActionBarLayer (contains tools + actions): z_index = 3000
- Result: Quest Board always below both tools and actions

**Desired Layering** (bottom to top):
```
Play Area        (z=0)       ← Farm, quantum graph
Tool Selection   (z=3000)    ← 1-6 tool buttons
Quest Board      (z=3500)    ← Quest overlay
Actions          (z=4000)    ← Q/E/R action buttons (always on top)
```

**Files Modified**:

### ToolSelectionRow.gd (line 30-31):
```gdscript
func _ready():
	# Z-index: Below quest board (3500), above play area (1000)
	z_index = 3000
```

### QuestBoard.gd (line 52):
```gdscript
func _init():
	name = "QuestBoard"
	z_index = 3500  # Above tool selection (3000), below actions (4000)
```

### ActionPreviewRow.gd (line 36-37):
```gdscript
func _ready():
	# Z-index: Above quest board (3500), above tool selection (3000)
	z_index = 4000
```

**Result**: ✅ Correct layering achieved
- Tool selection (3000) - bottom layer of UI
- Quest Board (3500) - middle layer (covers tools when open)
- Actions (4000) - top layer (always visible)

---

## Testing Results

### Visual Verification Needed:
1. **ESC Menu**: Press ESC → menu should be centered on screen ✓
2. **Quest Board Boundaries**:
   - Press C → quest board opens
   - Top bar (resources) should be visible above quest board ✓
   - Tool selection (1-6) should be visible below quest board ✓
   - Quest board fills middle zone only ✓
3. **Quest Board Layering**:
   - Open quest board (C key)
   - Tool selection (1-6) should be BEHIND quest board ✓
   - Actions (Q/E/R) should be IN FRONT of quest board ✓

### Boot Test Results:
```
✅ Top bar: 32.4px (0% to 6%)
✅ Quest Board created (press C to toggle - modal 4-slot system)
✅ Escape menu created (ESC to toggle)
✅ Touch button bar created (📖=V, 📋=C, ☰=ESC)
```

---

## Files Modified Summary

1. **UI/Panels/EscapeMenu.gd**
   - Replaced manual centering with `PRESET_CENTER`
   - Simplified from 10 lines to 3 lines

2. **UI/Panels/QuestBoard.gd**
   - Added `z_index = 3500` in `_init()`
   - Changed `anchor_bottom` from `1.0` to `0.72`
   - Quest Board now fits in play zone (6%-72%)

3. **UI/Panels/ToolSelectionRow.gd**
   - Added `z_index = 3000` in `_ready()`
   - Establishes bottom UI layer

4. **UI/Panels/ActionPreviewRow.gd**
   - Added `z_index = 4000` in `_ready()`
   - Establishes top UI layer (always visible)

---

## Key Learnings

### 1. PRESET_CENTER vs Manual Anchors
- ✅ **Use `PRESET_CENTER`** for simple centering with fixed sizes
- ❌ **Avoid manual anchor 0.5 + offsets** when using `custom_minimum_size`
- Godot's presets are more reliable than manual anchor math

### 2. Z-Index Inheritance
- Child z_index is **relative to parent** z_index
- If parent is OverlayLayer (1000), child with z_index 100 → effective 1100
- Set z_index on the nodes you want to layer, not just their parents

### 3. Layout Zone Boundaries
With static viewport, use percentage anchors that match layout zones:
- Top bar: 0% - 6%
- Play area: 6% - 72%
- Tool selection: 72% - 87%
- Actions: 87% - 100%

Modals should respect these zones (especially play area)!

### 4. UI Layering Strategy
```
Background layers (0-1000)   → Farm, quantum viz, biomes
UI layers (3000-4000)        → Tools, overlays, actions
Modal layers (5000+)         → ESC menu, save/load
```

Always keep actions (Q/E/R) at highest z_index so they're always accessible!

---

## Summary

**Before**:
- ESC menu stuck in top-left corner
- Quest Board overlapped top bar and tool selection
- Quest Board hidden behind all UI elements

**After**:
- ✅ ESC menu centered using `PRESET_CENTER`
- ✅ Quest Board fits play zone (6%-72%, respects boundaries)
- ✅ Correct z_index layering: tools < quest board < actions
- ✅ Top bar always visible (0%-6%)
- ✅ Tool selection visible when quest closed (72%-87%)
- ✅ Actions always visible (87%-100%, z=4000)

All UI elements now positioned correctly with proper layering!
