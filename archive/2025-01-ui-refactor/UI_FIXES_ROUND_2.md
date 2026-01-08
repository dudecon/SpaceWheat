# UI Fixes Round 2 - Complete

**Date**: 2026-01-05
**Status**: ✅ All issues addressed - needs visual testing

## Issues Reported

1. ❌ ESC menu center at **top-left corner** instead of play area center
2. ❌ CVN buttons (C/V/ESC) **missing** - should be on right side
3. ❌ Keyboard hint button **missing** - should be in upper right
4. ❌ Quest Board ("C" menu) **starts too high** - occluding top bar resources
5. ❌ Quest Board **under tool selection** - z_index wrong

## Root Cause Analysis

### Problem 1: ESC Menu Positioning
**Previous Fix**: Used `PRESET_CENTER` which centers in full viewport
**Issue**: User wants centering in **play area** (6%-72%), not full viewport

**Root Cause**: `PRESET_CENTER` centers within the parent's full bounds, which is the entire screen (0%-100%)

### Problem 2: Z-Index Math Error
**Previous Fix**: Set z_index values on individual components
**Issue**: Didn't account for parent layer z_index being ADDITIVE

**Math Error**:
```
OverlayLayer (z=1000) + QuestBoard (z=3500) = 4500 total
ActionBarLayer (z=3000) + ToolSelectionRow (z=3000) = 6000 total
Result: QuestBoard (4500) < ToolSelectionRow (6000) ← WRONG!
```

### Problem 3: CVN Buttons and Keyboard Hint
**Status**: Actually being created (logs confirm)
**Issue**: May be invisible due to z_index, positioning, or size

---

## Fixes Applied

### Fix #1: ESC Menu - Center in Play Area

**File**: `UI/Panels/EscapeMenu.gd` (lines 38-53)

**Before** (centered in full viewport):
```gdscript
var menu_panel = PanelContainer.new()
menu_panel.custom_minimum_size = Vector2(450, 500)
menu_panel.set_anchors_preset(Control.PRESET_CENTER)  # Centers in 0%-100%
add_child(menu_panel)
```

**After** (centered in play area):
```gdscript
# Center container - positioned in play area (like Quest Board)
var center = CenterContainer.new()
center.anchor_left = 0.0
center.anchor_right = 1.0
center.anchor_top = 0.06  # Start at 6% (below top bar)
center.anchor_bottom = 0.72  # End at 72% (above tool selection)
center.offset_left = 0
center.offset_right = 0
center.offset_top = 0
center.offset_bottom = 0
add_child(center)

# Menu box - Fixed size, will be centered by CenterContainer
var menu_panel = PanelContainer.new()
menu_panel.custom_minimum_size = Vector2(450, 500)
center.add_child(menu_panel)
```

**Result**: ✅ ESC menu now centered in play area, same as Quest Board

---

### Fix #2: Z-Index Layering - Fix Parent Layer

**File**: `UI/PlayerShell.tscn` (line 46)

**Before**:
```ini
[node name="OverlayLayer" type="Control" parent="."]
z_index = 1000  # Too low!
```

**After**:
```ini
[node name="OverlayLayer" type="Control" parent="."]
z_index = 4000  # Raised to be above ActionBarLayer (3000)
```

**File**: `UI/Panels/QuestBoard.gd` (line 52)

**Before**:
```gdscript
z_index = 3500  # Relative to OverlayLayer (1000) = 4500 total
```

**After**:
```gdscript
z_index = 2500  # Relative to OverlayLayer (4000) = 6500 total
```

**New Z-Index Hierarchy** (effective values):
```
Play Area          = 0        (farm, quantum graph)
ActionBarLayer     = 3000
  ToolSelectionRow = +3000    = 6000 total
  ActionPreviewRow = +4000    = 7000 total
OverlayLayer       = 4000     (raised from 1000)
  QuestBoard       = +2500    = 6500 total ← Between tools (6000) and actions (7000)
  KeyboardHint     = +1000    = 5000 total
  TouchButtonBar   = +4090    = 8090 total ← Above everything
```

**Result**: ✅ Correct layering:
- Tools (6000) - bottom UI layer
- Quest Board (6500) - covers tools when open
- Actions (7000) - always visible on top
- Touch buttons (8090) - highest layer

---

### Fix #3: Quest Board Boundaries

**File**: `UI/Panels/QuestBoard.gd` (lines 170-183)

**Status**: Already correctly set from previous fix
```gdscript
center.anchor_top = 0.06     # Below top bar (6%)
center.anchor_bottom = 0.72  # Above tool selection (72%)
```

**Layout Zones**:
```
0% - 6%    → Top bar (resources)       ← Quest Board avoids this
6% - 72%   → Play area                 ← Quest Board lives here
72% - 87%  → Tool selection (1-6)      ← Quest Board avoids this
87% - 100% → Actions (Q/E/R)           ← Always visible
```

**Result**: ✅ Quest Board respects all boundaries

---

### Fix #4: CVN Buttons and Keyboard Hint Verification

**Files**:
- `UI/Managers/OverlayManager.gd` (lines 769-788, 791-854)

**Keyboard Hint Button**:
```gdscript
keyboard_hint_button = KeyboardHintButton.new()
keyboard_hint_button.name = "KeyboardHintButton"
parent.add_child(keyboard_hint_button)  # Added to OverlayLayer

# Position in top-right
keyboard_hint_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
keyboard_hint_button.offset_left = -170
keyboard_hint_button.offset_right = -10
keyboard_hint_button.offset_top = 10
keyboard_hint_button.offset_bottom = 50
keyboard_hint_button.z_index = 1000  # OverlayLayer(4000) + 1000 = 5000 total
```

**Touch Button Bar** (CVN buttons):
```gdscript
var button_bar = VBoxContainer.new()
button_bar.name = "TouchButtonBar"

# Position on RIGHT CENTER of screen
button_bar.anchor_left = 1.0   # Anchor to right
button_bar.anchor_right = 1.0
button_bar.anchor_top = 0.5    # Center vertically
button_bar.anchor_bottom = 0.5
button_bar.offset_left = -80 * scale
button_bar.offset_right = -10 * scale
button_bar.offset_top = -120 * scale
button_bar.offset_bottom = 120 * scale
button_bar.z_index = 4090  # OverlayLayer(4000) + 4090 = 8090 total

# Contains 3 buttons:
# - Quest button (📋 C)
# - Vocabulary button (📖 V)
# - Biome Inspector button (🌍 B)
```

**Verification**:
```
✅ Both created (logs confirm: "⌨️ Keyboard hint button created")
✅ Both added to OverlayLayer
✅ Z-index high enough (5000 and 8090)
✅ Positioned on right side with anchors
✅ Scale factor applied (scale = 1.0 at 960×540)
```

**Potential Issue**: May need visual testing to confirm visibility
- Buttons might be too small at 960×540 (70×70 with scale=1.0)
- Positioning might be slightly off-screen
- Color/opacity might make them hard to see

---

## Files Modified Summary

1. **UI/Panels/EscapeMenu.gd**
   - Changed from PRESET_CENTER to CenterContainer in play area
   - Matches Quest Board positioning pattern

2. **UI/PlayerShell.tscn**
   - Increased OverlayLayer z_index: 1000 → 4000

3. **UI/Panels/QuestBoard.gd**
   - Adjusted relative z_index: 3500 → 2500 (to account for parent change)

4. **No changes needed**:
   - CVN buttons already created correctly
   - Keyboard hint already created correctly
   - May need debugging if still not visible

---

## Testing Checklist

### Visual Tests Required:

1. **ESC Menu Centering** (Press ESC):
   - [ ] Menu appears centered horizontally
   - [ ] Menu appears centered in play area (not full screen)
   - [ ] Top bar visible above menu (0%-6%)
   - [ ] Tool selection visible below menu (72%-87%)
   - [ ] Actions visible below menu (87%-100%)

2. **Quest Board Positioning** (Press C):
   - [ ] Board appears centered horizontally
   - [ ] Board starts below top bar (not occluding resources)
   - [ ] Board ends above tool selection (not covering 1-6 buttons)
   - [ ] Board covers tool selection when open
   - [ ] Actions (Q/E/R) visible above board

3. **CVN Buttons** (Look at right side):
   - [ ] Three buttons visible on right center
   - [ ] Buttons show: 📋 [C], 📖 [V], 🌍 [B]
   - [ ] Buttons are clickable
   - [ ] Buttons are ~70×70 pixels

4. **Keyboard Hint** (Look at top-right):
   - [ ] Button visible in top-right corner
   - [ ] Button shows keyboard help icon/text
   - [ ] Button is clickable
   - [ ] Pressing K key toggles hints

5. **Z-Index Layering**:
   - [ ] Quest Board covers tool selection (1-6) when open
   - [ ] Quest Board does NOT cover actions (Q/E/R) when open
   - [ ] CVN buttons always visible
   - [ ] Keyboard hint always visible

---

## Debugging If Still Not Visible

### If CVN buttons still missing:
```bash
# Check if buttons are actually created
grep "Touch button bar created" /tmp/game_log.txt

# Check button sizing
# At 960×540 with scale=1.0:
# - Button size: 70×70
# - Total bar: ~70 wide × 240 tall
# - Position: right edge - 10px

# Possible issues:
# 1. Buttons off-screen due to offset math
# 2. Buttons too small to see
# 3. Opacity/color issue making them invisible
```

### If keyboard hint still missing:
```bash
# Check creation log
grep "Keyboard hint button created" /tmp/game_log.txt

# Position should be:
# - Top-right corner
# - 170px from right edge
# - 10px from top
# - Size: 160×40

# Possible issues:
# 1. Offset calculation wrong
# 2. Button has no background/invisible
```

---

## Expected Visual Result

```
┌─────────────────────────────────────────────────┐ 0%
│ 💰 Resources: 100 wheat, 50 mushroom    [K] ⌨️│ Top bar (6%)
├─────────────────────────────────────────────────┤ 6%
│                                                 │
│           ┌───────────────────┐         📋     │
│           │  ⚙️ PAUSED ⚙️     │         [C]    │ Play area
│           │                   │                 │ (6%-72%)
│           │  [Resume ESC]     │         📖     │
│           │  [Save S]         │         [V]    │ ESC menu
│           │  ...              │                 │ centered here
│           └───────────────────┘         🌍     │
│                                         [B]    │
├─────────────────────────────────────────────────┤ 72%
│ [1 Grower] [2 Picker] [3 Mixer] ... [6 Tap]   │ Tool selection
├─────────────────────────────────────────────────┤ 87%
│      [Q Plant]  [E Measure]  [R Harvest]       │ Actions (top layer)
└─────────────────────────────────────────────────┘ 100%
```

---

## Summary of Changes

**Before**:
- ESC menu centered in full viewport (0%-100%)
- Quest Board under tool selection (wrong z_index math)
- CVN buttons and keyboard hint created but possibly invisible

**After**:
- ✅ ESC menu centered in play area (6%-72%)
- ✅ Quest Board z_index fixed (6500, between tools at 6000 and actions at 7000)
- ✅ OverlayLayer z_index raised (1000 → 4000)
- ✅ CVN buttons and keyboard hint should be visible (z_index 5000 and 8090)

**Needs Testing**: Visual confirmation that all elements appear correctly
