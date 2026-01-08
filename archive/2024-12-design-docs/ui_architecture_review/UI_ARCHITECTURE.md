# SpaceWheat UI Architecture - Current State & Issues

**Date:** 2026-01-04
**Status:** NEEDS ARCHITECTURAL REVIEW
**Critical Issues:** Anchor/size conflicts, z-ordering complexity, layout fighting

---

## Current UI Hierarchy

```
SceneTree (Root)
└── FarmView (Control)
    ├── PlayerShell (Control) - Scene: PlayerShell.tscn
    │   ├── FarmUIContainer (Control, z_index: 0)
    │   │   └── FarmUI (Control) - Scene: FarmUI.tscn
    │   │       ├── PlotGridDisplay (Control, z_index: -10)
    │   │       │   └── PlotTiles (GridContainer)
    │   │       │       └── PlotTile × N (Control)
    │   │       │           └── [Emoji labels, borders, indicators]
    │   │       └── MainContainer (VBoxContainer, z_index: 100)
    │   │           ├── ResourcePanel (HBoxContainer)
    │   │           ├── PlayAreaSpacer (Control)
    │   │           ├── ActionPreviewRow (HBoxContainer) ⚠️ MOVED DYNAMICALLY
    │   │           └── ToolSelectionRow (HBoxContainer) ⚠️ MOVED DYNAMICALLY
    │   │
    │   ├── OverlayLayer (Control, z_index: 1000)
    │   │   ├── QuestBoard (Control, z_index: 1003)
    │   │   ├── EscapeMenu (Control, z_index: 8000)
    │   │   ├── SaveLoadMenu (Control, z_index: 9999)
    │   │   ├── VocabularyOverlay (Control)
    │   │   ├── KeyboardHintButton (Button, z_index: 1000)
    │   │   └── TouchButtonBar (VBoxContainer, z_index: 1500)
    │   │
    │   └── ActionBarLayer (Control, z_index: 5000) ⚠️ DYNAMIC
    │       ├── ActionPreviewRow ⬅️ Moved here at runtime
    │       └── ToolSelectionRow  ⬅️ Moved here at runtime
    │
    └── viz_layer (CanvasLayer, layer: 0)
        └── BathQuantumVisualizationController (Node2D, z_index: 50)
            └── QuantumForceGraph (Node2D)
                └── [Biome visualization bubbles]
```

---

## Z-Index Layering Strategy

**Goal:** Plots < Biomes < Farm UI < Overlays < Action Bar < ESC Menu < Save/Load

| Layer | Component | Z-Index | Notes |
|-------|-----------|---------|-------|
| **CanvasLayer 0** | Default UI layer | - | All Control nodes |
| Plot tiles | PlotGridDisplay | -10 | Background |
| Biomes | QuantumViz (Node2D) | 50 | Above plots, below UI |
| Farm UI | MainContainer | 100 | Above biomes |
| Overlays | OverlayLayer container | 1000 | Above farm |
| Quest system | QuestBoard | 1003 | In overlays |
| Keyboard hints | KeyboardHintButton | 1000 | Clickable UI |
| Touch buttons | TouchButtonBar | 1500 | Side buttons |
| **Action toolbars** | **ActionBarLayer** | **5000** | **Above overlays!** |
| ESC menu | EscapeMenu | 8000 | Above toolbars |
| Save/Load | SaveLoadMenu | 9999 | HIGHEST |

---

## CRITICAL ISSUES

### 🔥 Issue 1: Anchor/Size Conflicts

**Warning Message:**
```
WARNING: Nodes with non-equal opposite anchors will have their size overridden after _ready().
If you want to set size, change the anchors or consider using set_deferred().
     at: _set_size (scene/gui/control.cpp:1476)
     GDScript backtrace:
         [0] _layout_elements (res://UI/PlotTile.gd:439)
         [1] _ready (res://UI/PlotTile.gd:86)
         [2] _create_tiles (res://UI/PlotGridDisplay.gd:319)
         [3] inject_layout_calculator (res://UI/PlotGridDisplay.gd:152)
         [4] _stage_ui (res://Core/Boot/BootManager.gd:131)
```

**What's Happening:**
- Nodes set both anchors (left≠right or top≠bottom) AND explicit size
- Godot layout engine overrides the size during `_ready()`
- Causes positioning to fail

**Where:**
- PlotTile._layout_elements() (line 439)
- Anywhere we set `custom_minimum_size` with non-equal anchors

**Current Attempted Fix:**
- Using `set_deferred()` for anchor/size properties
- Moving nodes dynamically at runtime (ActionPreviewRow, ToolSelectionRow)
- BUT: Still getting warnings, positioning still breaks

---

### 🔥 Issue 2: Dynamic Node Movement Breaking Layout

**Problem:**
- ActionPreviewRow and ToolSelectionRow created in FarmUI.tscn
- Moved to ActionBarLayer at runtime in PlayerShell._move_action_bar_to_top_layer()
- Their original layout properties (from VBoxContainer parent) conflict with new positioning
- Result: Appear in wrong location (upper left instead of bottom center)

**Code Location:** `PlayerShell.gd:331-405`

**Current Approach:**
```gdscript
# Remove from original parent (MainContainer VBoxContainer)
main_container.remove_child(action_bar)

# Add to new parent (ActionBarLayer Control)
action_bar_layer.add_child(action_bar)

# Try to reposition with set_deferred
action_bar.set_deferred("anchor_left", 0.0)
action_bar.set_deferred("anchor_right", 1.0)
action_bar.set_deferred("anchor_top", 1.0)
action_bar.set_deferred("anchor_bottom", 1.0)
action_bar.set_deferred("offset_top", -80)
# ... etc
```

**Why It Fails:**
- Node retains size_flags from VBoxContainer parent
- Layout properties from scene file persist
- Anchor preset methods don't work after reparenting
- Deferred calls may be too late in the frame

---

### 🔥 Issue 3: Multiple Sizing Systems Fighting

**We have THREE different sizing systems active simultaneously:**

1. **Godot Anchors/Offsets** (engine-level)
   - set_anchors_preset()
   - anchor_left/right/top/bottom
   - offset_left/right/top/bottom

2. **Container Size Flags** (layout containers)
   - size_flags_horizontal (EXPAND, FILL, SHRINK)
   - size_flags_vertical
   - size_flags_stretch_ratio

3. **Custom Minimum Size** (manual override)
   - custom_minimum_size property
   - Conflicts with anchors when anchors are non-equal

**Problem:** These systems don't cooperate - they FIGHT each other.

---

### 🔥 Issue 4: Scene vs Code Positioning Conflict

**Pattern:**
1. Node created in .tscn file with certain layout properties
2. Code tries to reposition at runtime
3. Original scene properties persist and conflict

**Example:**
- ActionPreviewRow in FarmUI.tscn has `layout_mode = 2` (container child)
- When moved to ActionBarLayer, still has those properties
- New parent expects different layout_mode
- Positioning breaks

---

## Boot Sequence & Initialization Order

```
1. FarmView._ready()
   ├─ Loads PlayerShell.tscn → instantiates
   ├─ Creates Farm
   └─ Creates QuantumViz on CanvasLayer

2. PlayerShell._ready()
   ├─ Sets anchors to PRESET_FULL_RECT
   ├─ Creates OverlayManager
   └─ Creates overlays (quest board, menus, etc)

3. BootManager.boot() - Multi-stage boot
   ├─ Stage 3A: Instantiate FarmUI.tscn
   ├─ Stage 3B: Setup FarmUI with farm reference
   └─ Stage 3C: PlayerShell.load_farm_ui(farm_ui)
       └─ Triggers _move_action_bar_to_top_layer() ⚠️

4. FarmUI._ready()
   ├─ Gets references to scene children
   ├─ ActionPreviewRow still in MainContainer (hasn't moved yet)
   └─ ToolSelectionRow still in MainContainer

5. _move_action_bar_to_top_layer() (deferred)
   ├─ Removes nodes from MainContainer
   ├─ Adds to ActionBarLayer
   └─ Tries to reposition (FAILS due to conflicts)
```

**Timing Issue:** Node properties set in _ready() conflict with deferred repositioning.

---

## Sizing Delegation Pattern (Intended Design)

**The Intent:**
```
FarmView size (fills viewport)
    ↓ delegates to
PlayerShell (PRESET_FULL_RECT)
    ↓ delegates to
FarmUIContainer (anchors fill)
    ↓ delegates to
FarmUI (anchors fill)
    ↓ delegates to
MainContainer (anchors fill)
```

**Why It's Breaking:**
- Each level tries to set size explicitly
- Each level uses different sizing mechanism
- Deferred sizing happens at different times
- Size conflicts cascade down the hierarchy

---

## Key Code Locations

### Files Doing UI Positioning:

1. **UI/FarmView.gd**
   - Creates PlayerShell
   - Creates CanvasLayer for biomes
   - Lines 56-67: Biome visualization z_index

2. **UI/PlayerShell.gd**
   - Main UI orchestration
   - Lines 127-147: _ready() - anchor setup
   - Lines 331-405: _move_action_bar_to_top_layer() - DYNAMIC REPARENTING

3. **UI/FarmUI.gd**
   - Lines 37-83: _ready() - tries to size itself
   - Lines 61-75: Explicit size setting that conflicts with anchors

4. **UI/FarmUI.tscn**
   - Scene file with baked-in layout properties
   - Lines 17-70: Node structure with layout_mode, z_index

5. **UI/PlotTile.gd**
   - Lines 86-100: _ready() calls _layout_elements()
   - Lines 439-500: _layout_elements() - WHERE WARNING ORIGINATES

6. **UI/PlotGridDisplay.gd**
   - Lines 319-350: _create_tiles() - sets sizes with anchors

7. **UI/Panels/KeyboardHintButton.gd**
   - Lines 19-38: _ready() - anchor positioning
   - Lines 73-81: Hints panel positioning

8. **UI/Managers/OverlayManager.gd**
   - Lines 770-832: _create_touch_button_bar() - complex anchoring

---

## Attempted Solutions (What We've Tried)

### ✅ What Worked:
1. Z-index layering for visual ordering
2. Modal stack for input routing
3. CanvasLayer for biome depth

### ❌ What Failed:
1. set_deferred() for positioning (too late in frame?)
2. Dynamic node reparenting (retains old layout properties)
3. Mixing anchors with custom_minimum_size
4. Trying to reposition nodes created in .tscn files

---

## Questions for Architecture Review

### 1. **Should we stop reparenting nodes at runtime?**
   - Current: Create in .tscn, move in code
   - Alternative: Create all UI programmatically in correct parent from start?

### 2. **Should we pick ONE sizing system and stick to it?**
   - Option A: Pure anchors/offsets (no containers, no custom sizes)
   - Option B: Pure containers (no manual positioning)
   - Option C: Hybrid but with clear rules when to use which

### 3. **Is the CanvasLayer + Control z_index mixing problematic?**
   - Biomes on CanvasLayer 0 with z_index
   - UI on CanvasLayer 0 (default) with z_index
   - Does this cause conflicts?

### 4. **Should ActionBarLayer exist?**
   - Current: Separate Control layer for toolbars
   - Alternative: Keep in FarmUI but with higher z_index?
   - Alternative: Use CanvasLayer instead of Control?

### 5. **Is the delegation cascade too complex?**
   - 5+ levels of size delegation
   - Each level trying to size itself
   - Should we simplify the hierarchy?

### 6. **When should we use set_deferred() vs direct property setting?**
   - Current: Using it everywhere to avoid warnings
   - Does it actually help or just mask the problem?

---

## Recommendations Needed

We need architectural guidance on:

1. **UI Hierarchy Design**
   - What should the structure be?
   - How many layers is too many?
   - Where should dynamic elements live?

2. **Sizing Strategy**
   - One consistent approach for all nodes
   - Clear rules: "use anchors for X, containers for Y"
   - How to handle responsive scaling?

3. **Dynamic UI Changes**
   - Best practice for moving nodes at runtime
   - How to clear old layout properties
   - When to use reparenting vs creating new nodes

4. **Z-Ordering**
   - Is our current system sustainable?
   - Too many magic z_index numbers?
   - Better way to manage depth?

5. **Initialization Order**
   - When to size nodes relative to _ready()
   - Role of deferred calls
   - How to avoid timing conflicts

---

## Desired End State

**What we want:**
- ✅ Plots at back
- ✅ Biomes above plots
- ✅ Farm UI above biomes
- ✅ Toolbars (action + tool selection) at bottom center, above everything
- ✅ Overlays above toolbars
- ✅ Menus above overlays
- ✅ No console warnings
- ✅ UI responds correctly to window resizing
- ✅ Nodes appear where we tell them to appear

**Current reality:**
- ❌ Toolbars in wrong position
- ❌ Warnings about anchor/size conflicts
- ❌ Layout fighting between systems
- ❌ Fragile - breaks when we change things

---

## Files to Review

**Critical files for architectural review:**

```
UI/
├── FarmView.gd           # Root UI orchestration
├── PlayerShell.gd        # Layer management, dynamic reparenting
├── PlayerShell.tscn      # Layer structure definition
├── FarmUI.gd            # Farm UI setup
├── FarmUI.tscn          # Farm UI scene structure
├── PlotGridDisplay.gd   # Plot grid layout
├── PlotTile.gd          # Individual plot (warning source)
├── Managers/
│   └── OverlayManager.gd  # Overlay positioning
└── Panels/
    ├── KeyboardHintButton.gd  # Upper right positioning
    └── ActionPreviewRow.gd    # Bottom toolbar

Core/Boot/
└── BootManager.gd       # Boot sequence timing
```

**Please review and advise on:**
- Is this hierarchy sustainable?
- Where are we violating Godot best practices?
- What should we refactor first?
- Is there a simpler design pattern we should use?

---

**END OF ARCHITECTURE DOCUMENT**
