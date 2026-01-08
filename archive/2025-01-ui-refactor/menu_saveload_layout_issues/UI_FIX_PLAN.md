# SpaceWheat UI Fix Plan - Three Critical Issues

## Executive Summary

After analyzing your code, I've identified the **root causes** for all three issues. They are NOT Godot 4.5 bugs - they're architectural patterns that don't work as expected.

---

## Issue #1: SaveLoadMenu ESC Key Not Working

### Root Cause
**The `_input()` function is NOT what you should use for menu input in Godot 4.**

The problem: `_input()` is called on ALL nodes that haven't had input handled yet. The order depends on node tree position, NOT z_index. When you call `set_process_input(false)`, it disables `_process_input()` but **`_input()` continues to be called**.

Your attempted fix used `set_process_input(false)` but your menus use `_input()`, not `_process_input()`.

### The Solution
Use `_unhandled_input()` OR use Godot's built-in input handling with `set_process_unhandled_input()`.

**Better approach:** Use `_gui_input()` for menu controls since they're GUI elements, or use `_unhandled_key_input()` for keyboard shortcuts.

### Fix Code for EscapeMenu.gd

```gdscript
# Change line ~145 from:
func _input(event):

# To:
func _unhandled_key_input(event):
    """Handle keyboard navigation in menu - only if not handled by children"""
    if not visible:
        return
    
    # ... rest of input handling stays the same
```

### Fix Code for SaveLoadMenu.gd

```gdscript
# Change line ~232 from:
func _input(event):

# To:
func _unhandled_key_input(event):
    """Handle keyboard navigation - ONLY if not already handled"""
    if not visible:
        return
    
    # For ESC specifically, mark as handled FIRST before doing anything
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            get_viewport().set_input_as_handled()  # Mark handled IMMEDIATELY
            _on_cancel_pressed()
            return
    
    # ... rest of input handling
```

### Alternative Fix (More Robust)
Instead of relying on input order, make SaveLoadMenu explicitly control its parent:

```gdscript
# In SaveLoadMenu._on_cancel_pressed():
func _on_cancel_pressed():
    print("❌ Save/Load cancelled")
    # FIRST: Hide this menu
    hide_menu()
    # THEN: Emit signal (which triggers _on_save_load_menu_closed in OverlayManager)
    menu_closed.emit()
    # DON'T let escape menu see this ESC - we already handled it
```

And in OverlayManager, `_on_save_load_menu_closed()` should show the escape menu:

```gdscript
func _on_save_load_menu_closed() -> void:
    """Handle save/load menu closed - return to escape menu"""
    print("📋 Returning from save/load menu to escape menu")
    # Re-show escape menu (it was still visible but under SaveLoadMenu)
    if escape_menu and escape_menu.visible:
        # Menu is still there, just refresh
        pass
    elif escape_menu:
        escape_menu.show_menu()
```

---

## Issue #2: Pause Menu Not Centered

### Root Cause
**CenterContainer only centers children that have a defined size.** Your menu_panel uses `custom_minimum_size` which sets minimum, not actual size. The CenterContainer doesn't know how big to make the panel.

Also, in Godot 4, when you set `layout_mode = 1` (anchors) on a Control created in code, you MUST also set the offsets correctly or the anchors don't take effect properly.

### The Real Problem
When you create a CenterContainer in `_init()`, it doesn't have a valid size yet. The viewport isn't available, so the CenterContainer is 0x0 pixels and can't center anything.

### The Solution
Don't use anchors for the CenterContainer. Use `SIZE_EXPAND_FILL` and let the layout system handle it:

```gdscript
func _init():
    # ... anchor setup for THIS node (EscapeMenu) stays the same ...
    
    # Semi-transparent dark background - CORRECT
    background = ColorRect.new()
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    
    # CenterContainer - DON'T use anchors, use size flags
    var center = CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)  # Use preset instead of manual anchors
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(center)
    
    # Menu panel stays the same
    var menu_panel = PanelContainer.new()
    menu_panel.custom_minimum_size = Vector2(400, 600)
    center.add_child(menu_panel)
```

### Key Insight
`Control.PRESET_FULL_RECT` is the proper way to make a Control fill its parent in Godot 4. It sets:
- anchors to 0,0,1,1
- offsets to 0,0,0,0
- Handles layout_mode correctly

### Alternative: Use _ready() for Layout

```gdscript
func _init():
    name = "EscapeMenu"
    # Don't set anchors here - wait for _ready
    
    # Create children but don't position yet
    background = ColorRect.new()
    background.color = Color(0.0, 0.0, 0.0, 0.7)
    add_child(background)
    
    # ... create other children ...
    visible = false

func _ready():
    # NOW we have valid viewport size
    set_anchors_preset(Control.PRESET_FULL_RECT)
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    
    var center = get_node("CenterContainer")  # If named during _init
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
```

---

## Issue #3: Tool Bar Buttons Not Stretching

### Root Cause
**HBoxContainer children with `SIZE_EXPAND_FILL` will stretch, BUT the HBoxContainer itself needs to have a defined width to expand INTO.**

Your hierarchy:
```
MainContainer (VBoxContainer) 
  └─ ToolSelectionRow (HBoxContainer with size_flags_horizontal=3)
       └─ Buttons (size_flags_horizontal=SIZE_EXPAND_FILL)
```

The problem: `ToolSelectionRow` has `size_flags_horizontal=3` (EXPAND_FILL), but its PARENT (`MainContainer`) is a **VBoxContainer**. VBoxContainer gives its children **full width automatically** - it ignores horizontal size_flags.

So your buttons ARE expanding... to fill the ToolSelectionRow's width. But ToolSelectionRow is only as wide as its content (the buttons' minimum sizes).

### The Real Problem
Look at FarmUI.tscn:
```
[node name="ToolSelectionRow" type="HBoxContainer" parent="MainContainer"]
layout_mode = 2
size_flags_horizontal = 3
custom_minimum_size = Vector2(0, 60)
```

`layout_mode = 2` means "anchors mode" but with no anchors set, and `custom_minimum_size.x = 0` means no guaranteed width.

### The Solution
The HBoxContainer needs to FILL the parent width. In a VBoxContainer, this should happen automatically, BUT you need to ensure the VBoxContainer itself fills its parent.

**Fix in FarmUI.tscn:**

```ini
[node name="MainContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15  # PRESET_FULL_RECT
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 0
offset_top = 0
offset_right = 0
offset_bottom = 0

[node name="ToolSelectionRow" type="HBoxContainer" parent="MainContainer"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 0
custom_minimum_size = Vector2(0, 60)
```

### Alternative Fix - In Code (ToolSelectionRow.gd)

The issue is that HBoxContainer children are distributed based on separation and minimum sizes. To make them FILL:

```gdscript
func _ready():
    # Container setup
    add_theme_constant_override("separation", 12)
    
    # CRITICAL: Set size flags for THIS container to fill parent
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    
    # Create buttons...
    for tool_num in range(1, 7):
        var button = Button.new()
        # ...
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.size_flags_stretch_ratio = 1.0  # Equal distribution
        # ...
```

### Most Likely Fix
The real issue is probably that `FarmUIContainer` in PlayerShell isn't properly sized. Check if FarmUI actually fills its container:

```gdscript
# In FarmUI._ready() - ADD THIS:
func _ready():
    # Ensure this Control fills its parent
    set_anchors_preset(Control.PRESET_FULL_RECT)
    
    # ... rest of _ready
```

---

## Summary of All Fixes

### Quick Reference

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| ESC in SaveLoadMenu | `_input()` doesn't respect `set_process_input()` | Use `_unhandled_key_input()` instead |
| Menu not centered | Anchors set in `_init()` before viewport exists | Use `set_anchors_preset(PRESET_FULL_RECT)` |
| Buttons not stretching | Parent containers not filling viewport width | Add `set_anchors_preset(PRESET_FULL_RECT)` to FarmUI and ensure containers fill |

### Files to Modify

1. **EscapeMenu.gd**
   - Change `_input()` to `_unhandled_key_input()`
   - Use `set_anchors_preset()` instead of manual anchor assignment

2. **SaveLoadMenu.gd**
   - Change `_input()` to `_unhandled_key_input()`
   - Handle ESC immediately with `set_input_as_handled()` before processing

3. **FarmUI.gd**
   - Add `set_anchors_preset(Control.PRESET_FULL_RECT)` in `_ready()`

4. **FarmUI.tscn**
   - Verify MainContainer has `anchors_preset = 15` or correct anchor values

5. **ToolSelectionRow.gd** / **ActionPreviewRow.gd**
   - Add `size_flags_stretch_ratio = 1.0` to buttons for equal distribution

---

## Debugging Tips

### Check if Controls are Actually Sized

Add this debug code temporarily:

```gdscript
func _ready():
    # After all setup...
    await get_tree().process_frame
    print("DEBUG: %s size = %s" % [name, size])
    for child in get_children():
        if child is Control:
            print("  Child %s size = %s" % [child.name, child.size])
```

### Check Input Handler Order

```gdscript
func _unhandled_key_input(event):
    print("INPUT: %s received key %s (handled=%s)" % [name, event.keycode, event.is_pressed()])
```

### Verify Anchors Applied

```gdscript
func _ready():
    await get_tree().process_frame
    print("Anchors: L=%s T=%s R=%s B=%s" % [anchor_left, anchor_top, anchor_right, anchor_bottom])
    print("Offsets: L=%s T=%s R=%s B=%s" % [offset_left, offset_top, offset_right, offset_bottom])
    print("Size: %s" % size)
```

---

## Want Me to Generate the Fixed Files?

I can create complete, corrected versions of:
1. EscapeMenu.gd
2. SaveLoadMenu.gd  
3. FarmUI.gd
4. ToolSelectionRow.gd
5. ActionPreviewRow.gd

Just say the word and I'll generate them with all fixes applied.
