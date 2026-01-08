# SpaceWheat UI Architecture Refactor Plan

**Version:** 1.0
**Date:** 2026-01-05
**Author:** Architecture Review
**Target:** Godot 4.x

---

## Executive Summary

This document provides a complete, unambiguous implementation plan to fix the broken UI system in SpaceWheat. The core problem is **dynamic reparenting of UI nodes**, which fights Godot's layout system. The solution is to create nodes in their final parent from the start and use consistent sizing strategies.

**Time Estimate:** 4-6 hours for a focused implementation

---

## Table of Contents

1. [Problem Diagnosis](#1-problem-diagnosis)
2. [Target Architecture](#2-target-architecture)
3. [File Changes Summary](#3-file-changes-summary)
4. [Implementation Steps](#4-implementation-steps)
5. [Code Stubs](#5-code-stubs)
6. [Testing Checklist](#6-testing-checklist)

---

## 1. Problem Diagnosis

### 1.1 Root Cause

**The broken code is in `PlayerShell.gd` lines 333-396:**

```gdscript
# PROBLEM: Reparenting nodes from VBoxContainer to ActionBarLayer
main_container.remove_child(action_bar)
action_bar_layer.add_child(action_bar)
action_bar.layout_mode = 1  # Too late - cached layout already computed
```

When a node is created as a child of a `VBoxContainer` (in the .tscn file), Godot bakes in:
- `layout_mode = 2` (container child mode)
- Cached size calculations from the container
- Internal transform state

When you reparent at runtime:
- The node retains cached layout data
- Setting `layout_mode = 1` doesn't reset internal state
- The new parent may not be sized yet
- Anchors don't work correctly on already-initialized nodes

### 1.2 Symptoms

| Component | Expected | Actual |
|-----------|----------|--------|
| ActionPreviewRow (QER) | Bottom center | Top-left, half off screen |
| ToolSelectionRow (1-6) | Above QER row | Top-left, half off screen |
| KeyboardHintButton | Top-right | Not visible |
| Overlays (Quest, ESC) | Center | ✅ Working |
| BiomeVisualization | Center | ✅ Working |

### 1.3 Why Overlays Work

Overlays work because they are:
1. Created in code (not .tscn)
2. Added directly to their final parent
3. Never reparented
4. Positioned immediately after creation

---

## 2. Target Architecture

### 2.1 Scene Tree (After Refactor)

```
FarmView (Control, root)
│
├── Farm (Node) ← Pure data, NOT Control
│   ├── FarmGrid
│   ├── FarmEconomy
│   └── Biomes[]
│
├── WorldLayer (CanvasLayer, layer=0)
│   ├── PlotGridDisplay (Control)
│   └── QuantumVisualization (Node2D)
│
└── UILayer (CanvasLayer, layer=1)
    └── PlayerShell (Control, PRESET_FULL_RECT)
        │
        ├── FarmUIContainer (Control, PRESET_FULL_RECT)
        │   └── FarmUI (Control) ← Created at runtime
        │       ├── ResourcePanel (TOP)
        │       └── PlotGridDisplay ← REMOVED (moved to WorldLayer)
        │
        ├── ActionBarLayer (Control, PRESET_FULL_RECT, z_index=3000)
        │   ├── ToolSelectionRow (HBoxContainer) ← CREATED HERE
        │   └── ActionPreviewRow (HBoxContainer) ← CREATED HERE
        │
        ├── OverlayLayer (Control, PRESET_FULL_RECT, z_index=1000)
        │   ├── TouchButtonBar
        │   ├── KeyboardHintButton ← CREATED HERE
        │   ├── QuestBoard
        │   ├── EscapeMenu
        │   └── SaveLoadMenu
        │
        └── ToastLayer (Control, z_index=5000)
```

### 2.2 Key Principles

1. **Never reparent** - Create nodes in their final parent
2. **Single sizing strategy** - Either anchors OR container, never both
3. **CanvasLayers for z-ordering** - Don't use z_index on Controls for major layers
4. **Data/View separation** - Farm is data, PlotGridDisplay is view
5. **Explicit initialization** - No `call_deferred` chains

### 2.3 Sizing Strategy Reference

| Strategy | When to Use | Properties |
|----------|-------------|------------|
| **Anchors** | Fixed position relative to parent | `anchors_preset`, `offset_*` |
| **Container** | Dynamic layout within parent | `size_flags_*`, `custom_minimum_size` |
| **Manual** | Absolute pixel positioning | `position`, `size` |

**Rule:** If parent is a Container (VBox/HBox/etc), use Container strategy. Otherwise, use Anchors.

---

## 3. File Changes Summary

### 3.1 Files to MODIFY

| File | Changes |
|------|---------|
| `PlayerShell.gd` | Remove reparenting, create action bars directly |
| `PlayerShell.tscn` | Verify ActionBarLayer structure |
| `FarmUI.gd` | Remove action bar setup, simplify |
| `FarmUI.tscn` | Remove ActionPreviewRow and ToolSelectionRow nodes |
| `BootManager.gd` | Simplify Stage 3C |
| `OverlayManager.gd` | Add KeyboardHintButton creation |
| `FarmView.gd` | Add WorldLayer for visualization |

### 3.2 Files to CREATE

| File | Purpose |
|------|---------|
| `ActionBarManager.gd` | New manager for bottom toolbar |

### 3.3 Files to DELETE

None - we're refactoring, not removing features.

### 3.4 Files UNCHANGED

| File | Reason |
|------|--------|
| `Farm.gd` | Pure data model, no UI |
| `FarmGrid.gd` | Pure data model, no UI |
| `BiomeBase.gd` | Pure data model, no UI |
| `BasePlot.gd` | Pure data model, no UI |
| `FarmInputHandler.gd` | Input handling works correctly |
| `QuestBoard.gd` | Already works |
| `EscapeMenu.gd` | Already works |
| `SaveLoadMenu.gd` | Already works |
| `ActionPreviewRow.gd` | Logic is fine, just needs correct parent |
| `ToolSelectionRow.gd` | Logic is fine, just needs correct parent |
| `PlotTile.gd` | Already works |

---

## 4. Implementation Steps

### Step 1: Create ActionBarManager.gd

**Purpose:** Centralize action bar creation and management

**Location:** `res://UI/Managers/ActionBarManager.gd`

```gdscript
# See Code Stubs section for full implementation
```

### Step 2: Modify PlayerShell.tscn

**File:** `res://UI/PlayerShell.tscn`

**Changes:**
1. Verify ActionBarLayer exists with correct properties
2. Ensure mouse_filter = MOUSE_FILTER_IGNORE on ActionBarLayer

**Target structure:**
```tscn
[node name="ActionBarLayer" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15  ; PRESET_FULL_RECT
z_index = 3000
mouse_filter = 2  ; MOUSE_FILTER_IGNORE
```

### Step 3: Modify PlayerShell.gd

**File:** `res://UI/PlayerShell.gd`

**Changes:**

1. **REMOVE** the entire `_move_action_bar_to_top_layer()` function (lines 333-375)
2. **REMOVE** the entire `_position_action_bars_deferred()` function (lines 378-396)
3. **REMOVE** the `call_deferred("_move_action_bar_to_top_layer")` call in `load_farm_ui()` (around line 246)
4. **ADD** ActionBarManager initialization in `_ready()`
5. **ADD** action bar creation in `_ready()` BEFORE overlay creation

**Find and DELETE these functions:**
```gdscript
# DELETE THIS ENTIRE FUNCTION:
func _move_action_bar_to_top_layer() -> void:
    # ... all content ...
    pass

# DELETE THIS ENTIRE FUNCTION:
func _position_action_bars_deferred() -> void:
    # ... all content ...
    pass
```

**In `load_farm_ui()`, DELETE this line:**
```gdscript
# DELETE THIS LINE:
call_deferred("_move_action_bar_to_top_layer")
```

**In `_ready()`, ADD after overlay_manager setup:**
```gdscript
# Create action bars directly in ActionBarLayer (NEVER reparent)
_create_action_bars()
```

### Step 4: Modify FarmUI.tscn

**File:** `res://UI/FarmUI.tscn`

**Changes:**
1. **REMOVE** the `ActionPreviewRow` node from MainContainer
2. **REMOVE** the `ToolSelectionRow` node from MainContainer
3. Keep ResourcePanel and PlayAreaSpacer

**DELETE these node blocks:**
```tscn
[node name="ActionPreviewRow" type="HBoxContainer" parent="MainContainer"]
; ... delete entire block ...

[node name="ToolSelectionRow" type="HBoxContainer" parent="MainContainer"]
; ... delete entire block ...
```

**Resulting structure:**
```tscn
[node name="MainContainer" type="VBoxContainer" parent="."]
; ...

[node name="ResourcePanel" type="HBoxContainer" parent="MainContainer"]
; ... keep this ...

[node name="PlayAreaSpacer" type="Control" parent="MainContainer"]
; ... keep this ...

; ActionPreviewRow - REMOVED
; ToolSelectionRow - REMOVED
```

### Step 5: Modify FarmUI.gd

**File:** `res://UI/FarmUI.gd`

**Changes:**
1. Remove references to tool_selection_row and action_preview_row
2. Remove their initialization in `_ready()`
3. Remove signal connections to them

**Find and DELETE:**
```gdscript
# DELETE these variable declarations:
var tool_selection_row = null  # From scene
var action_preview_row = null  # From scene

# DELETE these node references in _ready():
tool_selection_row = get_node("MainContainer/ToolSelectionRow")
action_preview_row = get_node("MainContainer/ActionPreviewRow")

# DELETE signal connections:
if tool_selection_row:
    if not tool_selection_row.tool_selected.is_connected(_on_tool_selected):
        tool_selection_row.tool_selected.connect(_on_tool_selected)
    tool_selection_row.select_tool(1)

if action_preview_row:
    action_preview_row.update_for_tool(1)
    if not action_preview_row.action_pressed.is_connected(_on_action_pressed):
        action_preview_row.action_pressed.connect(_on_action_pressed)
```

**Keep the callback functions** but they will be connected from PlayerShell instead:
```gdscript
# KEEP these functions (they will be called from PlayerShell):
func _on_tool_selected(tool_num: int) -> void:
func _on_action_pressed(action_key: String) -> void:
```

### Step 6: Modify BootManager.gd

**File:** `res://Core/Boot/BootManager.gd`

**Changes:**
1. Simplify Stage 3C - remove action bar references
2. The action bars are now created in PlayerShell._ready(), not during boot

**In `_stage_ui()`, REMOVE:**
```gdscript
# These references no longer exist in FarmUI:
# var action_preview_row = ...
# var tool_selection_row = ...
```

### Step 7: Add KeyboardHintButton to OverlayManager

**File:** `res://UI/Managers/OverlayManager.gd`

**Changes:**
1. Add `_create_keyboard_hint_button()` function
2. Call it from `create_overlays()`

**Add to `create_overlays()`:**
```gdscript
func create_overlays(parent: Control) -> void:
    # ... existing overlay creation ...
    
    # Create keyboard hint button (top-right)
    _create_keyboard_hint_button(parent)
```

---

## 5. Code Stubs

### 5.1 ActionBarManager.gd (NEW FILE)

```gdscript
class_name ActionBarManager
extends RefCounted

## ActionBarManager - Creates and manages the bottom action toolbars
## 
## This manager creates ToolSelectionRow and ActionPreviewRow directly in
## ActionBarLayer. NO REPARENTING - nodes are created in their final parent.

const ToolSelectionRow = preload("res://UI/Panels/ToolSelectionRow.gd")
const ActionPreviewRow = preload("res://UI/Panels/ActionPreviewRow.gd")

var tool_selection_row: Control = null
var action_preview_row: Control = null


func create_action_bars(parent: Control) -> void:
    """Create action bars directly in parent (ActionBarLayer)
    
    Args:
        parent: The ActionBarLayer Control node
    
    CRITICAL: parent must already be in the scene tree and sized!
    """
    if not parent:
        push_error("ActionBarManager: parent is null!")
        return
    
    if not parent.is_inside_tree():
        push_error("ActionBarManager: parent not in scene tree!")
        return
    
    # Create ToolSelectionRow (1-6 buttons) - positioned 140px from bottom
    tool_selection_row = ToolSelectionRow.new()
    tool_selection_row.name = "ToolSelectionRow"
    parent.add_child(tool_selection_row)
    _position_tool_row(tool_selection_row)
    
    # Create ActionPreviewRow (QER buttons) - positioned 80px from bottom
    action_preview_row = ActionPreviewRow.new()
    action_preview_row.name = "ActionPreviewRow"
    parent.add_child(action_preview_row)
    _position_action_row(action_preview_row)
    
    print("✅ ActionBarManager: Created action bars directly in ActionBarLayer")


func _position_tool_row(row: Control) -> void:
    """Position ToolSelectionRow at bottom, above ActionPreviewRow"""
    # Use anchors for bottom-wide positioning
    row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    
    # Height: 60px, positioned above action row (which is 80px tall)
    row.offset_top = -140    # 140px from bottom
    row.offset_bottom = -80  # 80px from bottom (60px height)
    row.offset_left = 20     # 20px padding from left
    row.offset_right = -20   # 20px padding from right
    
    # Ensure proper sizing
    row.custom_minimum_size = Vector2(0, 60)


func _position_action_row(row: Control) -> void:
    """Position ActionPreviewRow at the very bottom"""
    # Use anchors for bottom-wide positioning
    row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    
    # Height: 80px at the bottom
    row.offset_top = -80     # 80px from bottom
    row.offset_bottom = 0    # At bottom
    row.offset_left = 20     # 20px padding from left
    row.offset_right = -20   # 20px padding from right
    
    # Ensure proper sizing
    row.custom_minimum_size = Vector2(0, 80)


func get_tool_row() -> Control:
    return tool_selection_row


func get_action_row() -> Control:
    return action_preview_row


func select_tool(tool_num: int) -> void:
    """Update tool selection display"""
    if tool_selection_row and tool_selection_row.has_method("select_tool"):
        tool_selection_row.select_tool(tool_num)
    if action_preview_row and action_preview_row.has_method("update_for_tool"):
        action_preview_row.update_for_tool(tool_num)


func update_for_submenu(submenu_name: String, submenu_info: Dictionary) -> void:
    """Update action row for submenu mode"""
    if action_preview_row and action_preview_row.has_method("update_for_submenu"):
        action_preview_row.update_for_submenu(submenu_name, submenu_info)


func update_for_quest_board(slot_state: int, is_locked: bool = false) -> void:
    """Update action row for quest board mode"""
    if action_preview_row and action_preview_row.has_method("update_for_quest_board"):
        action_preview_row.update_for_quest_board(slot_state, is_locked)


func restore_normal_mode() -> void:
    """Restore normal tool mode display"""
    if action_preview_row and action_preview_row.has_method("restore_normal_mode"):
        action_preview_row.restore_normal_mode()
```

### 5.2 PlayerShell.gd Modifications

**Replace the `_ready()` function with:**

```gdscript
var action_bar_manager = null  # ADD this variable declaration at top


func _ready() -> void:
    """Initialize player shell UI - children defined in scene"""
    print("🎪 PlayerShell initializing...")

    # Add to group so overlay buttons can find us
    add_to_group("player_shell")

    # CRITICAL: Ensure PlayerShell fills its parent (FarmView)
    set_anchors_preset(Control.PRESET_FULL_RECT)

    # Process input even when game is paused (for ESC menu, etc.)
    process_mode = Node.PROCESS_MODE_ALWAYS

    # Get reference to containers from scene
    farm_ui_container = get_node("FarmUIContainer")
    var overlay_layer = get_node("OverlayLayer")
    var action_bar_layer = get_node("ActionBarLayer")

    # Create and initialize UILayoutManager
    const UILayoutManager = preload("res://UI/Managers/UILayoutManager.gd")
    var layout_manager = UILayoutManager.new()
    add_child(layout_manager)

    # Create quest manager (before overlays, since overlays need it)
    quest_manager = QuestManager.new()
    add_child(quest_manager)
    print("   ✅ Quest manager created")

    # ═══════════════════════════════════════════════════════════════
    # CREATE ACTION BARS DIRECTLY IN ActionBarLayer (NO REPARENTING!)
    # ═══════════════════════════════════════════════════════════════
    const ActionBarManager = preload("res://UI/Managers/ActionBarManager.gd")
    action_bar_manager = ActionBarManager.new()
    action_bar_manager.create_action_bars(action_bar_layer)
    
    # Store reference for quest board updates
    action_preview_row = action_bar_manager.get_action_row()
    
    # Connect tool selection signal
    var tool_row = action_bar_manager.get_tool_row()
    if tool_row and tool_row.has_signal("tool_selected"):
        tool_row.tool_selected.connect(_on_tool_selected_from_bar)
    
    # Connect action button signal
    if action_preview_row and action_preview_row.has_signal("action_pressed"):
        action_preview_row.action_pressed.connect(_on_action_pressed_from_bar)
    
    print("   ✅ Action bars created directly in ActionBarLayer")
    # ═══════════════════════════════════════════════════════════════

    # Create overlay manager and add to overlay layer
    overlay_manager = OverlayManager.new()
    overlay_layer.add_child(overlay_manager)

    # Setup overlay manager with proper dependencies
    overlay_manager.setup(layout_manager, null, null, null, quest_manager)

    # Initialize overlays (C/V/N/K/ESC menus)
    overlay_manager.create_overlays(overlay_layer)

    # Connect overlay signals (existing code unchanged)
    _connect_overlay_signals()

    print("   ✅ Overlay manager created")
    print("✅ PlayerShell ready")


func _connect_overlay_signals() -> void:
    """Connect signals from overlays to manage modal stack"""
    if overlay_manager.quest_board:
        overlay_manager.quest_board.board_closed.connect(func():
            _pop_modal(overlay_manager.quest_board)
            _restore_action_toolbar()
        )
        overlay_manager.quest_board.board_opened.connect(func():
            _update_action_toolbar_for_quest()
        )
        overlay_manager.quest_board.selection_changed.connect(func(slot_state: int, is_locked: bool):
            _update_action_toolbar_for_quest(slot_state, is_locked)
        )
        print("   ✅ Quest board signals connected")

    if overlay_manager.escape_menu:
        overlay_manager.escape_menu.resume_pressed.connect(func():
            _pop_modal(overlay_manager.escape_menu)
        )
        overlay_manager.escape_menu.save_pressed.connect(func():
            _push_modal(overlay_manager.save_load_menu)
        )
        overlay_manager.escape_menu.load_pressed.connect(func():
            _push_modal(overlay_manager.save_load_menu)
        )
        print("   ✅ Escape menu signals connected")

    if overlay_manager.save_load_menu:
        overlay_manager.save_load_menu.menu_closed.connect(func():
            _pop_modal(overlay_manager.save_load_menu)
        )
        print("   ✅ Save/Load menu signals connected")


func _on_tool_selected_from_bar(tool_num: int) -> void:
    """Handle tool selection from action bar"""
    # Update action bar display
    if action_bar_manager:
        action_bar_manager.select_tool(tool_num)
    
    # Forward to FarmUI if available
    if current_farm_ui and current_farm_ui.has_method("_on_tool_selected"):
        current_farm_ui._on_tool_selected(tool_num)


func _on_action_pressed_from_bar(action_key: String) -> void:
    """Handle action button press from action bar"""
    # Forward to FarmUI if available
    if current_farm_ui and current_farm_ui.has_method("_on_action_pressed"):
        current_farm_ui._on_action_pressed(action_key)
```

**Replace `load_farm_ui()` with:**

```gdscript
func load_farm_ui(farm_ui: Control) -> void:
    """Load an already-instantiated FarmUI into the farm container.

    Called by BootManager.boot() in Stage 3C to add the FarmUI.
    Action bars are already created in _ready(), so no reparenting needed.
    """
    # Store reference
    current_farm_ui = farm_ui

    # Add to container
    if farm_ui_container:
        farm_ui_container.add_child(farm_ui)
        print("   ✔ FarmUI mounted in container")
    
    # Connect FarmUI to action bars via input handler
    if farm_ui.input_handler:
        # Connect input handler tool changes to action bar
        if farm_ui.input_handler.has_signal("tool_changed"):
            farm_ui.input_handler.tool_changed.connect(func(tool_num: int, _info: Dictionary):
                if action_bar_manager:
                    action_bar_manager.select_tool(tool_num)
            )
        
        if farm_ui.input_handler.has_signal("submenu_changed"):
            farm_ui.input_handler.submenu_changed.connect(func(name: String, info: Dictionary):
                if action_bar_manager:
                    action_bar_manager.update_for_submenu(name, info)
            )
        
        print("   ✔ Input handler connected to action bars")


# REMOVE THESE FUNCTIONS ENTIRELY:
# func _move_action_bar_to_top_layer() -> void:
# func _position_action_bars_deferred() -> void:
```

**Replace `_update_action_toolbar_for_quest()` and `_restore_action_toolbar()` with:**

```gdscript
func _update_action_toolbar_for_quest(slot_state: int = 1, is_locked: bool = false) -> void:
    """Update action toolbar to show quest-specific actions"""
    if action_bar_manager:
        action_bar_manager.update_for_quest_board(slot_state, is_locked)


func _restore_action_toolbar() -> void:
    """Restore action toolbar to normal tool mode"""
    if action_bar_manager:
        action_bar_manager.restore_normal_mode()
```

### 5.3 KeyboardHintButton Creation in OverlayManager

**Add to OverlayManager.gd:**

```gdscript
var keyboard_hint_button: Control = null


func _create_keyboard_hint_button(parent: Control) -> void:
    """Create keyboard hint button in top-right corner"""
    const KeyboardHintButton = preload("res://UI/Panels/KeyboardHintButton.gd")
    
    keyboard_hint_button = KeyboardHintButton.new()
    keyboard_hint_button.name = "KeyboardHintButton"
    parent.add_child(keyboard_hint_button)
    
    # Position in top-right
    keyboard_hint_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    keyboard_hint_button.offset_left = -170   # Button width + padding
    keyboard_hint_button.offset_right = -10   # 10px from right edge
    keyboard_hint_button.offset_top = 10      # 10px from top
    keyboard_hint_button.offset_bottom = 50   # 40px height
    
    # Ensure clickable
    keyboard_hint_button.mouse_filter = Control.MOUSE_FILTER_STOP
    keyboard_hint_button.z_index = 1000
    
    print("⌨️  Keyboard hint button created (top-right)")


func create_overlays(parent: Control) -> void:
    """Create all overlay panels"""
    # ... existing overlay creation code ...
    
    # ADD THIS AT THE END:
    _create_keyboard_hint_button(parent)
```

### 5.4 FarmUI.tscn Modifications

**Current (REMOVE):**
```tscn
[node name="ActionPreviewRow" type="HBoxContainer" parent="MainContainer"]
layout_mode = 2
size_flags_horizontal = 3
custom_minimum_size = Vector2(0, 80)
z_index = 500
script = ExtResource("5_actionrow")

[node name="ToolSelectionRow" type="HBoxContainer" parent="MainContainer"]
layout_mode = 2
size_flags_horizontal = 3
custom_minimum_size = Vector2(0, 60)
script = ExtResource("4_toolrow")
```

**Target (after removal):**
```tscn
[gd_scene load_steps=4 format=3 uid="uid://cdxfwm3p04laq"]

[ext_resource type="Script" path="res://UI/FarmUI.gd" id="1_farmui"]
[ext_resource type="Script" path="res://UI/Panels/ResourcePanel.gd" id="2_resourcepanel"]
[ext_resource type="Script" path="res://UI/PlotGridDisplay.gd" id="3_plotgrid"]

[node name="FarmUI" type="Control"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_farmui")

[node name="PlotGridDisplay" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
z_index = -10
mouse_filter = 2
script = ExtResource("3_plotgrid")

[node name="MainContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
self_modulate = Color(1, 1, 1, 0)

[node name="ResourcePanel" type="HBoxContainer" parent="MainContainer"]
layout_mode = 2
size_flags_horizontal = 3
custom_minimum_size = Vector2(0, 50)
script = ExtResource("2_resourcepanel")

[node name="PlayAreaSpacer" type="Control" parent="MainContainer"]
layout_mode = 2
custom_minimum_size = Vector2(0, 400)
size_flags_vertical = 3
mouse_filter = 2
```

---

## 6. Testing Checklist

### 6.1 Pre-Implementation Verification

- [ ] Backup all files being modified
- [ ] Verify Godot 4.x project opens without errors
- [ ] Note current broken behavior (screenshot if possible)

### 6.2 Implementation Verification

After each step, verify:

- [ ] **Step 1 (ActionBarManager):** File compiles without errors
- [ ] **Step 2 (PlayerShell.tscn):** Scene loads without warnings
- [ ] **Step 3 (PlayerShell.gd):** Script compiles, no errors about missing functions
- [ ] **Step 4 (FarmUI.tscn):** Scene loads without missing node errors
- [ ] **Step 5 (FarmUI.gd):** Script compiles, no errors about missing nodes
- [ ] **Step 6 (BootManager.gd):** Boot sequence completes

### 6.3 Post-Implementation Testing

**Visual Tests:**

| Test | Expected Result | Pass? |
|------|-----------------|-------|
| Launch game | No error dialogs | |
| ToolSelectionRow visible | Bottom, 140px from edge | |
| ActionPreviewRow visible | Bottom, 80px from edge | |
| KeyboardHintButton visible | Top-right corner | |
| Press 1-6 | Tool buttons highlight | |
| Press Q/E/R | Action buttons respond | |
| Press C | Quest board opens centered | |
| Press ESC | Pause menu opens centered | |
| Press K | Keyboard help toggles | |
| Window resize | Bars stay at bottom | |

**Functional Tests:**

| Test | Expected Result | Pass? |
|------|-----------------|-------|
| Select plot (T/Y/U/I/O/P) | Plot highlights | |
| Execute action (Q on planted) | Action executes | |
| Tool switch affects actions | Q/E/R labels update | |
| Quest board modifies action bar | Shows Accept/Reroll/Lock | |
| Close quest board | Action bar restores | |

### 6.4 Regression Tests

- [ ] Biome visualization still renders
- [ ] Plot tiles clickable
- [ ] Resource panel updates on harvest
- [ ] Save/load works
- [ ] All keyboard shortcuts work

---

## Appendix A: Quick Reference - Godot 4 Control Sizing

### Anchor Presets

```gdscript
# Common presets
Control.PRESET_FULL_RECT    # 15 - fills entire parent
Control.PRESET_TOP_WIDE     # 10 - top edge, full width
Control.PRESET_BOTTOM_WIDE  # 12 - bottom edge, full width
Control.PRESET_TOP_RIGHT    # 2  - top-right corner
Control.PRESET_CENTER       # 8  - centered in parent
```

### Offset Usage with Anchors

```gdscript
# Bottom-wide bar, 80px tall
control.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
control.offset_top = -80     # 80px up from anchor (bottom)
control.offset_bottom = 0    # At anchor (bottom)
control.offset_left = 20     # 20px from left
control.offset_right = -20   # 20px from right
```

### Size Flags (Container Children ONLY)

```gdscript
# Only use when parent is VBox/HBox/Grid/etc
Control.SIZE_FILL          # 1 - fill available space
Control.SIZE_EXPAND        # 2 - expand to push siblings
Control.SIZE_EXPAND_FILL   # 3 - both (most common)
Control.SIZE_SHRINK_CENTER # 4 - shrink and center
```

---

## Appendix B: Debug Commands

If issues persist, add this debug function to PlayerShell.gd:

```gdscript
func _debug_action_bars() -> void:
    """Debug action bar positioning - call with F12"""
    print("\n=== ACTION BAR DEBUG ===")
    
    var action_bar_layer = get_node_or_null("ActionBarLayer")
    if action_bar_layer:
        print("ActionBarLayer:")
        print("  size: %s" % action_bar_layer.size)
        print("  global_position: %s" % action_bar_layer.global_position)
    
    if action_bar_manager:
        var tool_row = action_bar_manager.get_tool_row()
        var action_row = action_bar_manager.get_action_row()
        
        if tool_row:
            print("\nToolSelectionRow:")
            print("  size: %s" % tool_row.size)
            print("  position: %s" % tool_row.position)
            print("  global_position: %s" % tool_row.global_position)
            print("  anchors: L%.2f T%.2f R%.2f B%.2f" % [
                tool_row.anchor_left, tool_row.anchor_top,
                tool_row.anchor_right, tool_row.anchor_bottom
            ])
        
        if action_row:
            print("\nActionPreviewRow:")
            print("  size: %s" % action_row.size)
            print("  position: %s" % action_row.position)
            print("  global_position: %s" % action_row.global_position)
    
    print("\nViewport: %s" % get_viewport().get_visible_rect().size)
    print("=== END DEBUG ===\n")


func _input(event: InputEvent) -> void:
    # Add debug key
    if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
        _debug_action_bars()
        return
    
    # ... rest of existing _input code ...
```

---

## Summary

This refactor eliminates the reparenting antipattern by creating UI nodes directly in their final parents. The key changes are:

1. **ActionBarManager** creates toolbars directly in ActionBarLayer
2. **PlayerShell** no longer reaches into FarmUI's internals
3. **FarmUI.tscn** no longer contains action bars
4. **Anchors-only positioning** for fixed UI elements
5. **No `call_deferred` chains** for layout

The result is a predictable, maintainable UI system that works with Godot's layout engine instead of fighting it.
