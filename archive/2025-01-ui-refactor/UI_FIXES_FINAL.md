# UI Fixes - Final Round (Z-Index Limit Fix)

**Date**: 2026-01-05
**Status**: ✅ All fixes applied - ready for visual testing

## Critical Bug Found: Z-Index Exceeded 4096 Limit

### The Problem
Godot's z_index maximum is **4096**. My previous fixes set:
- OverlayLayer: z=4000
- Touch buttons child: z=4090
- **Total: 4000 + 4090 = 8090** ← EXCEEDS 4096!

This caused:
- Touch buttons to wrap around or fail entirely
- CVN buttons completely invisible
- Z-index math broken throughout UI

### How Z-Index Works in Godot
- Child z_index is **ADDITIVE** with parent z_index
- Rendering order: Parent's z-index determines which layer renders first
- Within a layer, child z-index determines order

**Example**:
```
ActionBarLayer (z=50)
  ├─ Tools (child z=5) → effective z = 50+5 = 55
  └─ Actions (child z=150) → effective z = 50+150 = 200

OverlayLayer (z=100)
  ├─ QuestBoard (child z=0) → effective z = 100+0 = 100
  └─ TouchButtons (child z=300) → effective z = 100+300 = 400

Render order: Tools(55) < Quest(100) < Actions(200) < Touch(400)
```

---

## All Fixes Applied

### Fix #1: ESC Menu - Added Missing layout_mode

**File**: `UI/Panels/EscapeMenu.gd` (line 40)

**Problem**: Anchors weren't working because `layout_mode` was missing

**Before**:
```gdscript
var center = CenterContainer.new()
center.anchor_left = 0.0
center.anchor_right = 1.0
center.anchor_top = 0.06
center.anchor_bottom = 0.72
# Missing layout_mode!
add_child(center)
```

**After**:
```gdscript
var center = CenterContainer.new()
center.layout_mode = 1  # CRITICAL: Required for anchors in Godot 4
center.anchor_left = 0.0
center.anchor_right = 1.0
center.anchor_top = 0.06  # Start at 6% (below top bar)
center.anchor_bottom = 0.72  # End at 72% (above tool selection)
center.offset_left = 0
center.offset_right = 0
center.offset_top = 0
center.offset_bottom = 0
add_child(center)
```

**Result**: ✅ ESC menu now centered in play area (6%-72%)

---

### Fix #2: Z-Index Hierarchy - Stay Under 4096 Limit

**Files**:
- `UI/PlayerShell.tscn` (lines 46, 58)
- `UI/Panels/ToolSelectionRow.gd` (line 31)
- `UI/Panels/ActionPreviewRow.gd` (line 37)
- `UI/Panels/QuestBoard.gd` (line 52)
- `UI/Managers/OverlayManager.gd` (lines 782, 813)

**New Z-Index Hierarchy**:

```
┌──────────────────────────────────────────────┐
│ Layer                    │ Z-Index │ Total  │
├──────────────────────────────────────────────┤
│ ActionBarLayer (parent)  │    50   │        │
│   ├─ ToolSelectionRow    │    +5   │   55   │
│   └─ ActionPreviewRow    │  +150   │  200   │
├──────────────────────────────────────────────┤
│ OverlayLayer (parent)    │   100   │        │
│   ├─ QuestBoard          │    +0   │  100   │
│   ├─ KeyboardHintButton  │  +300   │  400   │
│   └─ TouchButtonBar      │  +300   │  400   │
└──────────────────────────────────────────────┘

Render Order (bottom to top):
  Tools(55) → Quest(100) → Actions(200) → Touch/Keyboard(400)
```

**All values under 4096!** ✅

**Visual Result**:
- Tool selection (1-6): Lowest layer, covered by Quest Board when open
- Quest Board: Middle layer, covers tools, but not actions
- Actions (Q/E/R): High layer, always visible even when Quest open
- Touch buttons & keyboard hint: Highest layer, always visible

---

### Fix #3: Quest Board Boundaries (Already Correct)

**File**: `UI/Panels/QuestBoard.gd` (lines 171-184)

**Status**: No changes needed - already correctly positioned

```gdscript
var center = CenterContainer.new()
center.layout_mode = 1
center.anchor_left = 0.0
center.anchor_right = 1.0
center.anchor_top = 0.06    # Below top bar (6%)
center.anchor_bottom = 0.72  # Above tool selection (72%)
```

**Layout Zones**:
```
0% - 6%     → Top bar (resources)       [Quest avoids]
6% - 72%    → Play area                 [Quest lives here] ✓
72% - 87%   → Tool selection (1-6)      [Quest avoids]
87% - 100%  → Actions (Q/E/R)           [Always visible]
```

---

## Files Modified Summary

1. **UI/PlayerShell.tscn**
   - OverlayLayer z_index: 4000 → **100**
   - ActionBarLayer z_index: 3000 → **50**

2. **UI/Panels/EscapeMenu.gd**
   - Added `layout_mode = 1` to CenterContainer

3. **UI/Panels/QuestBoard.gd**
   - Child z_index: 2500 → **0** (parent changed to 100)

4. **UI/Panels/ToolSelectionRow.gd**
   - Child z_index: 3000 → **5** (parent changed to 50)

5. **UI/Panels/ActionPreviewRow.gd**
   - Child z_index: 4000 → **150** (parent changed to 50)

6. **UI/Managers/OverlayManager.gd**
   - Touch button bar z_index: 4090 → **300**
   - Keyboard hint z_index: 1000 → **300**

---

## Visual Testing Checklist

### 1. ESC Menu (Press ESC)
- [ ] Menu appears **centered horizontally** in play area
- [ ] Menu appears **centered vertically** in play area (not at top-left corner)
- [ ] Top bar (resources) **visible** above menu
- [ ] Tool selection (1-6) **visible** below menu
- [ ] Actions (Q/E/R) **visible** below menu

### 2. Quest Board (Press C)
- [ ] Board appears **centered** in play area
- [ ] Top bar (resources) **NOT occluded** - visible above board
- [ ] Tool selection (1-6) **covered/hidden** when board open
- [ ] Actions (Q/E/R) **visible/clickable** above board

### 3. CVN Touch Buttons (Right Side of Screen)
- [ ] **Three buttons visible** stacked vertically on right
- [ ] Buttons show emojis: 📋 [C], 📖 [V], 🌍 [B]
- [ ] Buttons positioned at **right-center** of screen
- [ ] Buttons are **clickable** and work
- [ ] Buttons size approximately **70×70 pixels** each

### 4. Keyboard Hint Button (Top-Right Corner)
- [ ] Button **visible** in top-right corner
- [ ] Button shows keyboard icon or text
- [ ] Button is **clickable**
- [ ] Pressing **K key** toggles keyboard hints

### 5. Z-Index Layering
- [ ] Quest Board **covers** tool selection when open
- [ ] Quest Board **does NOT cover** actions (Q/E/R)
- [ ] Actions always **above** Quest Board
- [ ] CVN buttons always **above** everything
- [ ] Keyboard hint always **above** everything

---

## Expected Visual Layout

```
┌──────────────────────────────────────────────────┐ 0%
│ 💰 Resources: 100🌾 50🍄          [K Help] ⌨️  │
├──────────────────────────────────────────────────┤ 6%
│                                                  │
│            ┌─────────────────┐           📋    │
│            │ ⚙️ PAUSED ⚙️    │          [C]   │
│            │                 │                  │
│            │ [Resume ESC]    │           📖    │ Play Area
│            │ [Save S]        │          [V]   │ (6%-72%)
│            │ [Load L]        │                  │
│            │ [Restart R]     │           🌍    │
│            │ [Quit Q]        │          [B]   │
│            └─────────────────┘                  │
│                                                  │
├──────────────────────────────────────────────────┤ 72%
│ [1 Grower] [2 Picker] [3 Mixer] [4] [5] [6 Tap]│ Tools
├──────────────────────────────────────────────────┤ 87%
│     [Q Plant]   [E Measure]   [R Harvest]       │ Actions
└──────────────────────────────────────────────────┘ 100%
```

---

## Debugging If Issues Persist

### If CVN buttons still not visible:

1. **Check positioning**: Buttons should be at right-center
   ```gdscript
   anchor_left = 1.0, anchor_right = 1.0  # Right side
   anchor_top = 0.5, anchor_bottom = 0.5  # Center vertically
   offset_left = -80, offset_right = -10  # 10px from edge
   ```

2. **Check size**: At 960×540 with scale=1.0
   - Button size: 70×70 pixels
   - Total bar height: ~240 pixels (3 buttons + spacing)

3. **Check z_index**: Should be 400 total (100+300)

4. **Check visibility**:
   ```bash
   # Boot game and check logs
   grep "Touch button bar created" /tmp/game_log.txt
   ```

### If keyboard hint not visible:

1. **Check positioning**: Should be top-right corner
   ```gdscript
   set_anchors_preset(PRESET_TOP_RIGHT)
   offset_left = -170  # 160px wide + 10px padding
   offset_right = -10   # 10px from right edge
   offset_top = 10      # 10px from top
   ```

2. **Check size**: 160×40 pixels

3. **Check z_index**: Should be 400 total (100+300)

### If ESC menu still wrong position:

1. **Verify layout_mode is set**: Check line 40 of EscapeMenu.gd
2. **Check anchors**: Should be 0.06 to 0.72
3. **Check that CenterContainer has the menu as child**

---

## Key Learnings

### 1. Godot 4 Requires layout_mode
- When setting anchors manually, **MUST** set `layout_mode = 1`
- Without it, anchors are ignored and node defaults to (0,0) position

### 2. Z-Index Has Hard Limit of 4096
- Child z_index + parent z_index must stay under 4096
- Exceeding limit causes wrapping/failure
- Use smaller values: 50, 100, 200 instead of 1000, 3000, 4000

### 3. Z-Index is Additive
- Always calculate: parent z + child z = effective z
- Plan hierarchy to avoid conflicts
- Keep parent layers spread apart (50, 100) to leave room for children

### 4. Testing Z-Index Hierarchy
```
Tools(55) < Quest(100) < Actions(200) < Buttons(400)

Desired behavior:
- Quest covers tools ✓ (100 > 55)
- Quest under actions ✓ (100 < 200)
- Buttons above all ✓ (400 > 200)
```

---

## Summary

**Problems Fixed**:
1. ✅ ESC menu positioning - added missing `layout_mode = 1`
2. ✅ Z-index exceeding limit - recalculated all values to stay under 4096
3. ✅ Quest Board boundaries - already correct (6%-72%)
4. ✅ CVN buttons invisible - fixed z_index calculation
5. ✅ Keyboard hint invisible - fixed z_index calculation

**All UI elements should now be**:
- Properly positioned
- Visible with correct layering
- Under the 4096 z_index limit
- Ready for visual testing

**Next Step**: Visual testing to confirm everything renders correctly!
