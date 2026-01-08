Looking at your updated package, I see you've isolated the **layout issues** (menu centering and button stretching) from the ESC key input issue. Let me give you a clear fix strategy for these two remaining problems.

## The Core Problem: Dynamic Children in Containers

Your README nails the critical observation:

> **ResourcePanel (also HBoxContainer with SIZE_EXPAND_FILL) stretches correctly, but ActionPreviewRow and ToolSelectionRow do not**

The difference: ResourcePanel's children are defined in the scene file, while ActionPreviewRow/ToolSelectionRow create buttons dynamically in `_ready()`.

## Fix Strategy

### Issue 1: Buttons Not Stretching

**Root Cause:** When you create buttons in `_ready()`, the HBoxContainer hasn't completed its layout pass yet. The container calculates its size based on children present at layout time, but your buttons are added mid-layout.

**The Fix - Force Layout Recalculation:**

```gdscript
# In ActionPreviewRow._ready() and ToolSelectionRow._ready()
# AFTER adding all buttons, add this:

func _ready():
    # ... existing button creation code ...
    
    # Force layout recalculation after all children added
    await get_tree().process_frame
    queue_sort()  # Tell HBoxContainer to recalculate layout
```

**Alternative Fix - Use call_deferred:**

```gdscript
func _ready():
    # Defer button creation to after layout initialization
    call_deferred("_create_buttons")

func _create_buttons():
    for action_key in ["Q", "E", "R"]:
        var button = Button.new()
        # ... button setup ...
        add_child(button)
    
    # Now trigger layout
    queue_sort()
```

### Issue 2: Menu Not Centered

**Root Cause:** CenterContainer created in `_init()` has no valid size yet. The anchors are set before the node enters the scene tree.

**The Fix - Use set_anchors_preset() in _ready():**

```gdscript
# In EscapeMenu.gd, change the approach:

func _init():
    name = "EscapeMenu"
    # DON'T set anchors here - just create structure
    
    background = ColorRect.new()
    background.color = Color(0.0, 0.0, 0.0, 0.7)
    add_child(background)
    
    # ... create other children WITHOUT anchor setup ...
    visible = false

func _ready():
    # NOW set anchors - viewport exists
    set_anchors_preset(Control.PRESET_FULL_RECT)
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    
    # Find and configure the CenterContainer
    for child in get_children():
        if child is CenterContainer:
            child.set_anchors_preset(Control.PRESET_FULL_RECT)
            break
```

## Quick Reference: What to Tell the Bot

For **ActionPreviewRow.gd** and **ToolSelectionRow.gd**:
1. Add `await get_tree().process_frame` after button creation loop
2. Add `queue_sort()` to force HBoxContainer layout recalculation
3. Optionally add `size_flags_stretch_ratio = 1.0` to buttons for equal distribution

For **EscapeMenu.gd** (and SaveLoadMenu.gd):
1. Move all anchor/layout setup from `_init()` to `_ready()`
2. Use `set_anchors_preset(Control.PRESET_FULL_RECT)` instead of manual anchor assignment
3. Apply preset to self, background, and CenterContainer

For **FarmUI.gd** (belt and suspenders):
1. Add `set_anchors_preset(Control.PRESET_FULL_RECT)` at start of `_ready()`
2. This ensures the FarmUI fills its container before children initialize

Want me to generate the complete fixed files now?