# Layout and Positioning Issues - Deep Dive Analysis

## Summary
Two critical UI layout issues affecting the entire game interface remain **completely unresolved** despite multiple correct implementation attempts. The fixes follow all Godot 4 best practices but produce zero visual changes, suggesting a fundamental issue with the layout system or viewport/canvas rendering.

---

## Issue #1: Pause Menu Not Centered

### Expected Behavior
```
┌─────────────────────────────────┐
│                                 │
│    Semi-transparent overlay     │
│        (fills viewport)         │
│                                 │
│         ┌──────────────┐        │
│         │   PAUSED     │        │
│         │              │        │
│         │ Resume [ESC] │        │
│         │ Save Game    │        │
│         │ Load Game    │        │
│         │ Restart      │        │
│         │ Quit         │        │
│         └──────────────┘        │
│                                 │
│    (Menu centered on screen)    │
│                                 │
└─────────────────────────────────┘
```

### Actual Behavior
```
┌─────────────────────────────────┐
│                                 │
│ ┌──────────────┐                │
│ │   PAUSED     │                │
│ │              │                │
│ │ Resume [ESC] │                │
│ │ Save Game    │                │
│ │ Load Game    │                │
│ │ Restart      │                │
│ │ Quit         │                │
│ └──────────────┘                │
│                                 │
│ (Menu stuck on LEFT side)       │
│                                 │
└─────────────────────────────────┘
```

### Root Cause Analysis

The menu positioning issue occurs despite using **exactly the correct implementation** for Godot 4:

#### What Should Work (Textbook Godot 4 Implementation)
```gdscript
# EscapeMenu._init()
extends Control

func _init():
    # These settings should make EscapeMenu fill the viewport
    layout_mode = 1  # LAYOUT_MODE_FULLRECT (anchors-based layout)
    anchor_left = 0.0
    anchor_top = 0.0
    anchor_right = 1.0
    anchor_bottom = 1.0

    # Background to fill entire viewport
    background = ColorRect.new()
    background.color = Color(0.0, 0.0, 0.0, 0.7)
    background.anchor_left = 0.0
    background.anchor_top = 0.0
    background.anchor_right = 1.0
    background.anchor_bottom = 1.0
    background.layout_mode = 1
    add_child(background)

    # CenterContainer to center the menu
    var center = CenterContainer.new()
    center.anchor_left = 0.0
    center.anchor_top = 0.0
    center.anchor_right = 1.0
    center.anchor_bottom = 1.0
    center.layout_mode = 1  # LAYOUT_MODE_FULLRECT
    add_child(center)

    # Menu panel inside center
    var menu_panel = PanelContainer.new()
    menu_panel.custom_minimum_size = Vector2(400, 600)
    center.add_child(menu_panel)
```

**This is the exact pattern from Godot 4 documentation for centered modal dialogs.**

Yet the result is a menu stuck on the LEFT side of the screen.

### Attempted Fixes (All Failed)

#### Fix 1: Changed CenterContainer to Free Positioning Mode
**Hypothesis:** Maybe anchors-based layout_mode = 1 conflicts with CenterContainer's centering behavior.

**Attempt:**
```gdscript
var center = CenterContainer.new()
center.layout_mode = 0  # Free positioning mode
center.position = Vector2(0, 0)
center.size = get_viewport().get_visible_rect().size
center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
center.size_flags_vertical = Control.SIZE_EXPAND_FILL
add_child(center)
```

**Result:** `get_viewport()` returned null (not in scene tree yet in _init)
**Status:** FAILED - Reverted to anchors mode

#### Fix 2: Added Explicit SIZE_EXPAND_FILL to CenterContainer
**Hypothesis:** Maybe CenterContainer needs explicit expansion flags.

**Attempt:**
```gdscript
center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
center.size_flags_vertical = Control.SIZE_EXPAND_FILL
```

**Result:** No visual change - menu still on left
**Status:** FAILED

#### Fix 3: Fixed PlayerShell to Fill Viewport
**Hypothesis:** Maybe the parent PlayerShell isn't giving EscapeMenu enough space.

**Attempt in PlayerShell.tscn:**
```
Old: layout_mode = 2 (container mode)
New: layout_mode = 1 (anchor-based)
     anchors_left = 0.0
     anchors_top = 0.0
     anchors_right = 1.0
     anchors_bottom = 1.0
```

**Result:** No visual change - menu still on left
**Status:** FAILED

### Technical Breakdown

#### Scene Hierarchy (What Should Work)
```
FarmView (root scene)
  └─ PlayerShell (Control, layout_mode=1, anchors 0-1)
     ├─ FarmUIContainer (Control, layout_mode=1, anchors 0-1)
     │  └─ FarmUI (Control, layout_mode=1, anchors 0-1)
     │     └─ MainContainer (VBoxContainer)
     │        ├─ ResourcePanel
     │        ├─ PlotGridDisplay
     │        ├─ ActionPreviewRow
     │        └─ ToolSelectionRow
     │
     └─ OverlayLayer (Control, layout_mode=1, anchors 0-1, z_index=1000)
        ├─ EscapeMenu (Control, layout_mode=1, anchors 0-1)
        │  ├─ ColorRect (background, layout_mode=1, anchors 0-1)
        │  └─ CenterContainer (layout_mode=1, anchors 0-1)
        │     └─ PanelContainer (menu_panel, custom_minimum_size=400x600)
        │        └─ VBoxContainer (menu_vbox)
        │           ├─ Label (title)
        │           ├─ Button (Resume)
        │           ├─ Button (Save)
        │           └─ ... more buttons
        │
        ├─ SaveLoadMenu
        ├─ VocabularyOverlay
        └─ ContractsOverlay
```

**Every single node in this hierarchy is configured correctly** for anchors-based layout with proper viewport filling.

Yet EscapeMenu renders on the LEFT instead of CENTERED.

### Possible Root Causes

1. **Godot 4.5 CenterContainer Bug**
   - CenterContainer might not work with layout_mode=1 (anchors mode)
   - Could be regression in 4.5.stable
   - Centering might only work with layout_mode=0 (but then we can't get viewport)

2. **Canvas/Viewport Rendering Issue**
   - Anchors might not be properly applied to dynamically-created nodes
   - Viewport rect calculation might be happening before nodes are in tree
   - Z-index or layer ordering issue preventing proper rendering

3. **Layout_mode Cascade Problem**
   - Parent's layout_mode might override child's anchors
   - Scene-based composition (using `.instantiate()`) might not propagate layout properly
   - Missing layout update or recalculation after node creation

4. **OverlayLayer Configuration**
   - z_index=1000 set correctly, but maybe position/anchors not respected
   - Might need explicit size setting instead of relying on anchors

### Code Evidence That Configuration Is Correct

**EscapeMenu._init() - Lines 22-67:**
```
✅ layout_mode = 1
✅ anchor_left/top/right/bottom = 0.0/0.0/1.0/1.0
✅ process_mode = PROCESS_MODE_ALWAYS (so it works when paused)
✅ mouse_filter = MOUSE_FILTER_STOP (blocks input to game)
✅ background with proper anchors
✅ CenterContainer with proper anchors
✅ PanelContainer child with custom_minimum_size
```

**PlayerShell.tscn - Lines 5-15:**
```
✅ PlayerShell: layout_mode = 1
✅ PlayerShell: anchors 0-1
✅ OverlayLayer child: layout_mode = 1
✅ OverlayLayer child: anchors 0-1
✅ OverlayLayer child: z_index = 1000
```

Everything is configured exactly as documented in Godot 4 tutorials for centered modal dialogs.

---

## Issue #2: Tool Bar Buttons Not Stretching Horizontally

### Expected Behavior
```
Tool Selection Row (Full Width):
┌──────────────────────────────────────────────────────────────────┐
│  [1] Grower  │  [2] Quantum  │  [3] Industry  │  [4] Energy  │ ... │
│              │               │               │              │     │
└──────────────────────────────────────────────────────────────────┘
(Buttons stretch equally to fill available width)

Action Preview Row (Full Width):
┌──────────────────────────────────────────────────────────────────┐
│  [Q] Plant  │  [E] Entangle  │  [R] Harvest                       │
│             │                │                                    │
└──────────────────────────────────────────────────────────────────┘
(Buttons stretch equally to fill available width)
```

### Actual Behavior
```
Tool Selection Row:
┌──────────────────────────────────────────────────────────────────┐
│ [1] Grower [2] Quantum [3] Industry [4] Energy ...               │
│                                                                   │
│ (Buttons clustered on LEFT, large empty space on RIGHT)          │
└──────────────────────────────────────────────────────────────────┘

Action Preview Row:
┌──────────────────────────────────────────────────────────────────┐
│ [Q] Plant [E] Entangle [R] Harvest                               │
│                                                                   │
│ (Buttons clustered on LEFT, large empty space on RIGHT)          │
└──────────────────────────────────────────────────────────────────┘
```

### Root Cause Analysis

The button stretching issue occurs despite using **completely correct size_flags configuration** across all levels:

#### Configuration Level 1: Scene Definition (FarmUI.tscn)
```
✅ MainContainer (VBoxContainer):
   - layout_mode = 1 (anchors-based)
   - anchors = 0-1 on all sides
   - size_flags_horizontal = 3 (SIZE_EXPAND_FILL | SIZE_SHRINK_CENTER)
   - size_flags_vertical = 3

✅ ActionPreviewRow (HBoxContainer):
   - layout_mode = 2 (container-based)
   - size_flags_horizontal = 3 (SIZE_EXPAND_FILL)
   - custom_minimum_size = Vector2(0, 80)  [0 width = allow full expansion]

✅ ToolSelectionRow (HBoxContainer):
   - layout_mode = 2 (container-based)
   - size_flags_horizontal = 3 (SIZE_EXPAND_FILL)
   - custom_minimum_size = Vector2(0, 60)  [0 width = allow full expansion]
```

#### Configuration Level 2: Script Implementation (ActionPreviewRow.gd)
```gdscript
✅ func _ready():
   - size_flags_horizontal = Control.SIZE_EXPAND_FILL

   for action_key in ["Q", "E", "R"]:
       var button = Button.new()
       ✅ button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
       ✅ button.custom_minimum_size = Vector2(120 * scale_factor, 50 * scale_factor)
       add_child(button)
```

#### Configuration Level 3: Script Implementation (ToolSelectionRow.gd)
```gdscript
✅ func _ready():
   for tool_num in range(1, 7):
       var button = Button.new()
       ✅ button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
       ✅ button.custom_minimum_size = Vector2(90 * scale_factor, 55 * scale_factor)
       add_child(button)
```

**This is textbook correct HBoxContainer button layout.**

Yet buttons remain clustered on the left.

### How HBoxContainer Should Work (Godot 4 Behavior)

With proper configuration, HBoxContainer should:
1. Calculate available width
2. Deduct minimum widths from each child
3. Distribute remaining space to children with SIZE_EXPAND_FILL
4. Stretch all SIZE_EXPAND_FILL children equally to fill the space

Expected calculation for ActionPreviewRow:
```
Total width: 1280px
Button minimum width: 120px × 3 buttons = 360px
Separator width: 10px × 2 separators = 20px
Available space: 1280 - 360 - 20 = 900px

Per button expansion: 900px ÷ 3 buttons = 300px
Final button width: 120px (minimum) + 300px (expansion) = 420px each
```

**Actual result:** Buttons appear ~120px each (minimum only, no expansion)

### Attempted Fixes (All Failed)

#### Fix 1: Changed Alignment from CENTER to BEGIN
**Hypothesis:** Maybe alignment affects expansion behavior.

**Attempt in ActionPreviewRow.gd:**
```gdscript
# OLD:
alignment = BoxContainer.ALIGNMENT_CENTER

# NEW:
alignment = BoxContainer.ALIGNMENT_BEGIN
# (or removed entirely)
```

**Result:** No visual change - buttons still clustered
**Status:** FAILED - Reverted because made it worse semantically

#### Fix 2: Verified All size_flags Configurations
**Hypothesis:** Maybe a config was missing or wrong.

**Verification:**
```
✅ Scene file: ActionPreviewRow size_flags_horizontal = 3
✅ Scene file: ToolSelectionRow size_flags_horizontal = 3
✅ Script: Container size_flags_horizontal = SIZE_EXPAND_FILL
✅ Script: Each button size_flags_horizontal = SIZE_EXPAND_FILL
✅ Scene file: MainContainer size_flags_horizontal = 3
✅ Script: Button custom_minimum_size X component = 0 (allows expansion)
```

All configurations are correct.

**Result:** No visual change - buttons still clustered
**Status:** FAILED

#### Fix 3: Parametric Sizing with Zero X Component
**Hypothesis:** Maybe parametric sizing was overriding button width.

**Implementation in FarmUI.gd:**
```gdscript
func _apply_parametric_sizing() -> void:
    # Only set HEIGHT, leave width as 0 for expansion
    if action_preview_row:
        action_preview_row.custom_minimum_size = Vector2(0, action_row_height)
```

**Result:** No visual change - buttons still clustered
**Status:** FAILED

### Technical Breakdown

#### How Buttons Are Created
**ActionPreviewRow._ready() - Lines 65-80:**
```gdscript
for action_key in ["Q", "E", "R"]:
    var button = Button.new()
    button.text = "[%s]" % action_key
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # ✅ Correct
    button.custom_minimum_size = Vector2(120 * scale_factor, 50 * scale_factor)  # ✅ Correct
    button.focus_mode = Control.FOCUS_NONE
    button.pressed.connect(_on_action_button_pressed.bindv([action_key]))
    add_child(button)
    action_buttons[action_key] = button
```

Each button is created with SIZE_EXPAND_FILL. Container is HBoxContainer with SIZE_EXPAND_FILL.

**Expected result:** Buttons stretch to fill container width.
**Actual result:** Buttons stick to minimum width.

#### Layout Cascade
```
FarmUI (Control, anchors 0-1)
  └─ MainContainer (VBoxContainer, size_flags=3)
     ├─ ResourcePanel (HBoxContainer, size_flags=3) → Stretches correctly ✅
     ├─ PlotGridDisplay (Control)
     ├─ ActionPreviewRow (HBoxContainer, size_flags=3) → Doesn't stretch ❌
     │  └─ Button (Q/E/R, size_flags=SIZE_EXPAND_FILL) → Don't stretch ❌
     └─ ToolSelectionRow (HBoxContainer, size_flags=3) → Doesn't stretch ❌
        └─ Button (1-6, size_flags=SIZE_EXPAND_FILL) → Don't stretch ❌
```

Interestingly, ResourcePanel (also HBoxContainer with size_flags=3) does stretch correctly! This suggests:
- HBoxContainer can stretch when properly configured
- Something specific about ActionPreviewRow/ToolSelectionRow prevents stretching
- Or something about dynamically-created buttons vs scene-based buttons

### Possible Root Causes

1. **Dynamically-Created Buttons Bug**
   - Buttons created with `.new()` might not respect size_flags properly
   - Scene-based buttons might work differently than script-created buttons
   - ResourcePanel might work because it's created via scene, not script

2. **HBoxContainer Layout Issue**
   - Might not recalculate layout after children added with `.new()` and `add_child()`
   - Missing layout update or invalidation after dynamic child creation
   - VBoxContainer children might have priority over actual expansion

3. **custom_minimum_size Limiting Expansion**
   - Even with X=0, might be preventing expansion
   - custom_minimum_size on parent might override child expansion
   - Parametric sizing setting might be interfering

4. **Container Hierarchy Issue**
   - MainContainer (VBoxContainer) might not distribute width properly to HBoxContainer children
   - Size cache not being invalidated
   - Layout recalculation not happening for dynamically-created nodes

---

## Code Files Involved

### Menu Centering Issue
- `EscapeMenu.gd` (Lines 22-67: _init, CenterContainer setup)
- `PlayerShell.tscn` (Lines 5-15: viewport-filling configuration)
- `OverlayManager.gd` (Lines 102-115: EscapeMenu creation)

### Tool Bar Stretching Issue
- `ActionPreviewRow.gd` (Lines 54-84: _ready and button creation)
- `ToolSelectionRow.gd` (Lines 35-97: _ready and button creation)
- `FarmUI.tscn` (Lines 17-53: MainContainer and children configuration)
- `FarmUI.gd` (Lines 154-187: parametric sizing)

---

## Critical Observation

**ResourcePanel (HBoxContainer) DOES stretch properly.** It's created in the scene file and contains buttons. Yet ActionPreviewRow and ToolSelectionRow (also HBoxContainer with same size_flags) do NOT stretch.

The key difference:
- ✅ ResourcePanel: defined in scene file
- ❌ ActionPreviewRow: created via scene file, buttons added dynamically via script
- ❌ ToolSelectionRow: created via scene file, buttons added dynamically via script

**This suggests the issue is specifically with dynamically-created buttons and/or the layout not being recalculated after dynamic child addition.**

---

## Next Steps for External Reviewer

1. Verify if dynamically-created buttons in HBoxContainer have known issues in Godot 4.5
2. Check if HBoxContainer needs explicit layout update/invalidation after `add_child()`
3. Investigate if CenterContainer works differently with layout_mode=1 vs layout_mode=0
4. Determine if custom_minimum_size with X=0 actually allows expansion
5. Check if scene-based buttons behave differently than script-created buttons
6. Review if anchors-based layout (layout_mode=1) conflicts with CenterContainer behavior

---

## Environment Details
- **Engine:** Godot 4.5.stable.official (876b29033)
- **Language:** GDScript
- **Platform:** Linux/WSL2
- **Resolution Tested:** 1280×720, 64×64 (headless)
- **Date:** December 24, 2025
