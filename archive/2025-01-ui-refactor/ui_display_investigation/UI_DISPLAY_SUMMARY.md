# UI Display Investigation - Complete Visual Hierarchy

**Date:** 2026-01-05
**Status:** 🔴 CRITICAL - UI positioning completely broken

---

## TL;DR - Current Issues

**What the user sees:**
1. ❌ Action bars (QER buttons) - **Half off screen top-left** instead of bottom center
2. ❌ Tool selection (1-6 tools) - **Half off screen top-left** instead of bottom center
3. ❌ Keyboard hints button - **MISSING/NOT VISIBLE** (should be upper right)
4. ✅ Overlays (C/V/B/ESC) - **Working** (quest board, vocabulary, escape menu)

**What we tried:**
- Clearing container properties when reparenting nodes ✅
- Using `set_deferred()` for positioning ❌ (still wrong)
- Using `await get_tree().process_frame` ❌ (still wrong)
- Multiple timing strategies - **ALL FAILED**

**Root cause hypothesis:**
- Dynamic reparenting fundamentally broken
- Timing/sizing issues in ActionBarLayer
- Anchors not being respected
- Possible scene structure problem

---

## Complete UI Hierarchy (Visual Tree)

```
FarmView (Root Control - fills viewport)
│
└── PlayerShell (Control - PRESET_FULL_RECT anchors)
    ├── FarmUIContainer (Control, z_index: 0)
    │   └── FarmUI (Control)
    │       ├── PlotGridDisplay (Control, z_index: -10)
    │       │   └── PlotTiles (GridContainer)
    │       │       └── PlotTile × 6 (Control)
    │       │           ├── Background (ColorRect)
    │       │           ├── Territory border (ColorRect)
    │       │           ├── Selection border (ColorRect)
    │       │           ├── Emoji labels × 2 (Label, PRESET_FULL_RECT)
    │       │           ├── Growth bar (ColorRect)
    │       │           ├── Number label (Label)
    │       │           ├── Checkbox label (Label)
    │       │           └── Center indicator (ColorRect)
    │       │
    │       ├── MainContainer (VBoxContainer, z_index: 100)
    │       │   ├── ResourcePanel (HBoxContainer)
    │       │   ├── PlayAreaSpacer (Control - takes up space)
    │       │   ├── [ActionPreviewRow - MOVED AT RUNTIME] ⚠️
    │       │   └── [ToolSelectionRow - MOVED AT RUNTIME] ⚠️
    │       │
    │       └── QuantumModeStatusIndicator (PanelContainer, top-right)
    │
    ├── OverlayLayer (Control, z_index: 1000)
    │   ├── QuestBoard (Control, z_index: 1003) ✅ WORKS
    │   ├── VocabularyOverlay (Control) ✅ WORKS
    │   ├── BiomeInspectorOverlay (Control) ✅ WORKS
    │   ├── EscapeMenu (Control, z_index: 3500) ✅ WORKS
    │   ├── SaveLoadMenu (Control, z_index: 4000) ✅ WORKS
    │   ├── KeyboardHintButton (Button, z_index: 1000) ❌ NOT VISIBLE
    │   │   └── Hints Panel (PanelContainer, hidden initially)
    │   └── TouchButtonBar (VBoxContainer, z_index: 1500)
    │       ├── Quest Button [C] ✅ WORKS
    │       ├── Vocabulary Button [V] ✅ WORKS
    │       └── Biome Button [B] ✅ WORKS
    │
    └── ActionBarLayer (Control, z_index: 3000) ⚠️ BROKEN
        ├── ActionPreviewRow (HBoxContainer) ❌ WRONG POSITION
        │   ├── Action Q Button
        │   ├── Action E Button
        │   └── Action R Button
        └── ToolSelectionRow (HBoxContainer) ❌ WRONG POSITION
            ├── Tool 1 Button
            ├── Tool 2 Button
            ├── Tool 3 Button
            ├── Tool 4 Button
            ├── Tool 5 Button
            └── Tool 6 Button

viz_layer (CanvasLayer, layer: 0)
└── BathQuantumVisualizationController (Node2D, z_index: 50)
    └── QuantumForceGraph (Node2D)
        └── Biome bubbles (drawn procedurally)
```

---

## Z-Index Layering (Intended)

| Component | Z-Index | Status | Notes |
|-----------|---------|--------|-------|
| PlotGridDisplay | -10 | ✅ | Background plots |
| Biome visualization | 50 | ✅ | Above plots, below UI |
| FarmUI MainContainer | 100 | ✅ | Primary farm UI |
| OverlayLayer | 1000 | ✅ | Quest board, menus |
| QuestBoard | 1003 | ✅ | In overlays |
| KeyboardHintButton | 1000 | ❌ | **NOT VISIBLE** |
| TouchButtonBar | 1500 | ✅ | Left-side buttons work |
| **ActionBarLayer** | **3000** | **❌** | **BROKEN - toolbars wrong position** |
| EscapeMenu | 3500 | ✅ | Above action bars |
| SaveLoadMenu | 4000 | ✅ | Highest menu |

**Valid z_index range:** -4096 to +4096 (Godot limit)

---

## Screen Positioning (What Should Happen)

### Upper Right:
- ✅ **ResourcePanel** - Shows resources (wheat, mushrooms, etc.)
- ❌ **KeyboardHintButton** - Should show "[K] Keyboard" button
  - **PROBLEM:** Not visible at all
  - Position: PRESET_TOP_RIGHT, offset_left: -160, offset_top: 10

### Left Center:
- ✅ **TouchButtonBar** - Shows [C], [V], [B] buttons vertically
  - Position: anchor_left/right: 0.0, anchor_top/bottom: 0.5, offset calculations
  - **STATUS:** Working correctly

### Bottom Center:
- ❌ **ActionPreviewRow** (QER buttons) - Should be 80px from bottom
  - **ACTUAL:** Half off screen in top-left
  - **INTENDED:** PRESET_BOTTOM_WIDE, offset_top: -80, offset_bottom: 0
  - **SIZE:** custom_minimum_size: Vector2(0, 80)

- ❌ **ToolSelectionRow** (1-6 tools) - Should be 140px from bottom
  - **ACTUAL:** Half off screen in top-left
  - **INTENDED:** PRESET_BOTTOM_WIDE, offset_top: -140, offset_bottom: -80
  - **SIZE:** custom_minimum_size: Vector2(0, 60)

### Center (Fullscreen Overlays):
- ✅ **QuestBoard** - Press [C] to open
  - PRESET_CENTER with specific sizing
- ✅ **EscapeMenu** - Press [ESC] to open
- ✅ **SaveLoadMenu** - From ESC menu
- ✅ **VocabularyOverlay** - Press [V] to open

---

## Dynamic Reparenting Issue (Core Problem)

### The Process (PlayerShell._move_action_bar_to_top_layer)

**Step 1: Creation (in FarmUI.tscn)**
```
MainContainer (VBoxContainer)
├── ResourcePanel
├── PlayAreaSpacer
├── ActionPreviewRow (layout_mode=2, size_flags from VBoxContainer)
└── ToolSelectionRow (layout_mode=2, size_flags from VBoxContainer)
```

**Step 2: Runtime Reparenting (PlayerShell.gd:333-396)**
```gdscript
# Remove from VBoxContainer
main_container.remove_child(action_bar)

# Add to ActionBarLayer (plain Control)
action_bar_layer.add_child(action_bar)

# Clear container properties
action_bar.layout_mode = 1  # Switch to anchors mode
action_bar.size_flags_horizontal = Control.SIZE_FILL
action_bar.size_flags_vertical = Control.SIZE_FILL

# Call deferred positioning
_position_action_bars_deferred.call_deferred()
```

**Step 3: Deferred Positioning (PlayerShell.gd:378-396)**
```gdscript
func _position_action_bars_deferred() -> void:
    # Wait for layout pass
    await get_tree().process_frame

    # Set anchors and offsets
    action_preview_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    action_preview_row.offset_top = -80
    action_preview_row.offset_bottom = 0
    action_preview_row.custom_minimum_size = Vector2(0, 80)
```

**RESULT: ❌ FAILED - Bars appear half off screen in top-left**

### Why It's Failing (Hypotheses)

1. **ActionBarLayer not sized yet**
   - Despite `await get_tree().process_frame`, ActionBarLayer may not have final size
   - Parent sizing cascade: FarmView → PlayerShell → ActionBarLayer
   - If PlayerShell isn't sized, ActionBarLayer can't be sized

2. **Anchors not being respected**
   - `layout_mode = 1` might not be enough
   - Scene properties persisting despite clearing
   - Transform/position cache not being cleared

3. **Timing too early**
   - One frame may not be enough
   - Need to wait for multiple frames?
   - Or wait for specific ready signal?

4. **Scene structure issue**
   - ActionBarLayer in .tscn might have wrong properties
   - Node order in scene tree affecting layout

5. **Container properties not fully cleared**
   - Something else besides layout_mode and size_flags?
   - grow_horizontal/grow_vertical?
   - Position/size cached?

---

## Attempted Fixes (All Failed)

### Attempt 1: set_deferred() for all properties
```gdscript
action_bar.set_deferred("anchor_left", 0.0)
action_bar.set_deferred("anchor_right", 1.0)
# etc...
```
**Result:** ❌ Still wrong position

### Attempt 2: Immediate clearing + deferred positioning
```gdscript
action_bar.layout_mode = 1  # Immediate
action_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)  # Immediate
```
**Result:** ❌ Still wrong position

### Attempt 3: await get_tree().process_frame
```gdscript
func _position_action_bars_deferred():
    await get_tree().process_frame
    # Then set anchors
```
**Result:** ❌ Still wrong position (current state)

---

## KeyboardHintButton Mystery

**Code says it's created:**
```
⌨️  KeyboardHintButton initialized (upper right)
⌨️  Keyboard hint button created (K to toggle)
```

**But user reports:** NOT VISIBLE

**Possible causes:**
1. Z-index conflict (button has z_index: 1000, same as OverlayLayer parent)
2. Position calculation wrong (offset_left: -160 * scale_factor)
3. Scale factor incorrect (causing it to be off-screen)
4. Parent clipping/masking hiding it
5. Color/visibility issue (button exists but not rendered)

**Code location:** UI/Panels/KeyboardHintButton.gd:19-38
- Uses PRESET_TOP_RIGHT
- Should be 160px from right, 10px from top
- Added to OverlayLayer which has z_index: 1000

---

## Biome Visualization (Working)

**Structure:**
- CanvasLayer (layer: 0) - separate from UI
- BathQuantumVisualizationController (Node2D, z_index: 50)
- QuantumForceGraph draws biome bubbles

**Status:** ✅ WORKING - Renders correctly below UI

---

## Scene Structure Issues

### PlayerShell.tscn
```tscn
[node name="PlayerShell" type="Control"]
layout_mode = 1
anchors_left = 0.0
anchors_top = 0.0
anchors_right = 1.0
anchors_bottom = 1.0
# ... fills parent

[node name="FarmUIContainer" type="Control" parent="."]
# ... also fills parent

[node name="OverlayLayer" type="Control" parent="."]
z_index = 1000
# ... fills parent

[node name="ActionBarLayer" type="Control" parent="."]
layout_mode = 1
anchors_left = 0.0
anchors_right = 1.0
anchors_top = 0.0
anchors_bottom = 1.0
z_index = 3000
mouse_filter = 2  # IGNORE - lets clicks pass through
```

**ActionBarLayer properties:**
- Layout mode: 1 (anchors)
- Anchors: Full rect (0,0) to (1,1)
- Mouse filter: IGNORE
- **Question:** Does mouse_filter affect layout?

### FarmUI.tscn
```tscn
[node name="MainContainer" type="VBoxContainer" parent="."]
# Container with ActionPreviewRow and ToolSelectionRow as children

[node name="ActionPreviewRow" type="HBoxContainer" parent="MainContainer"]
layout_mode = 2  # Container child
size_flags_horizontal = 3  # EXPAND_FILL
custom_minimum_size = Vector2(0, 80)

[node name="ToolSelectionRow" type="HBoxContainer" parent="MainContainer"]
layout_mode = 2  # Container child
size_flags_horizontal = 3  # EXPAND_FILL
custom_minimum_size = Vector2(0, 60)
```

**These nodes get reparented at runtime** - properties persist

---

## Bootstrap Sequence

1. **FarmView._ready()**
   - Creates PlayerShell from scene
   - Creates viz_layer (CanvasLayer)
   - Creates quantum visualization

2. **PlayerShell._ready()**
   - Sets PRESET_FULL_RECT anchors
   - Creates OverlayManager
   - Creates overlays (quest, vocab, ESC, save/load, keyboard hints)

3. **BootManager.boot() - Stage 3**
   - 3A: Instantiate FarmUI.tscn
   - 3B: Setup FarmUI with farm reference
   - 3C: PlayerShell.load_farm_ui(farm_ui)
     - **Triggers:** call_deferred("_move_action_bar_to_top_layer")

4. **FarmUI._ready()**
   - Gets references to child nodes
   - ActionPreviewRow/ToolSelectionRow still in MainContainer

5. **_move_action_bar_to_top_layer() (deferred)**
   - Reparents bars to ActionBarLayer
   - Calls _position_action_bars_deferred.call_deferred()

6. **_position_action_bars_deferred() (deferred + await)**
   - Awaits get_tree().process_frame
   - Sets anchors and offsets
   - **FAILS** - bars end up in wrong position

---

## Input Handling (Working)

**Modal Stack (PlayerShell):**
```
User presses key → PlayerShell._input()
├─ If modal active → Route to modal.handle_input()
├─ Else if shell action (C/K/ESC) → Handle in PlayerShell
└─ Else → Fall through to Farm._unhandled_input()
```

**Status:** ✅ WORKING
- C key opens quest board
- V key opens vocabulary
- ESC opens escape menu
- K key should toggle keyboard hints (but button not visible)

---

## Files Exported

### Core UI Scripts:
- `PlayerShell.gd.txt` - Root UI orchestration
- `FarmView.gd.txt` - Viewport setup
- `FarmUI.gd.txt` - Farm interface
- `PlotGridDisplay.gd.txt` - Plot tile grid

### Action Bars (BROKEN):
- `ActionPreviewRow.gd.txt` - QER buttons
- `ToolSelectionRow.gd.txt` - 1-6 tool buttons

### Overlays (WORKING):
- `OverlayManager.gd.txt` - Manages all overlays
- `QuestBoard.gd.txt` - Quest interface
- `EscapeMenu.gd.txt` - Pause menu
- `SaveLoadMenu.gd.txt` - Save/load interface
- `KeyboardHintButton.gd.txt` - Keyboard help (NOT VISIBLE)

### Scene Structures:
- `PlayerShell.tscn.txt` - Layer structure
- `FarmUI.tscn.txt` - Farm UI layout

### Visualization:
- `BathQuantumVisualizationController.gd.txt` - Biome renderer

---

## Critical Questions

1. **Why does dynamic reparenting fail?**
   - Is this a fundamental Godot limitation?
   - Should we create nodes in ActionBarLayer from the start?
   - Is there a "reset layout" function we're missing?

2. **Why is await process_frame not enough?**
   - How many frames do we need to wait?
   - Is there a better signal to await?
   - Should we use a different approach entirely?

3. **Why is KeyboardHintButton not visible?**
   - Z-index issue?
   - Position calculation wrong?
   - Parent clipping?

4. **What's the correct Godot 4.5 pattern?**
   - For dynamic UI repositioning
   - For z-layering
   - For responsive anchoring

---

## Recommended Investigation Steps

1. **Test creating ActionPreviewRow directly in ActionBarLayer**
   - Skip reparenting entirely
   - See if positioning works when node starts in correct parent

2. **Add debug prints for sizes**
   - Print ActionBarLayer.size when positioning
   - Print action_bar.size and position after setting
   - Compare to expected values

3. **Try multiple frame waits**
   - await get_tree().process_frame
   - await get_tree().process_frame  # Second time
   - See if extra frames help

4. **Check for hidden properties**
   - Print all properties of reparented node
   - Look for anything that persists from old parent

5. **Test fixed positioning instead of anchors**
   - Use explicit position/size instead of anchors
   - See if problem is anchor-specific

---

## Status: NEEDS EXPERT GUIDANCE

The UI architecture is fundamentally broken. Multiple fix attempts have failed. We need:

1. ✅ **Why dynamic reparenting fails in Godot 4.5**
2. ✅ **Correct pattern for bottom-anchored toolbars**
3. ✅ **How to properly clear layout properties**
4. ✅ **Why KeyboardHintButton isn't visible**
5. ✅ **Should we redesign the entire approach?**

---

**Thank you for investigating! The codebase is exported and ready for analysis.**
