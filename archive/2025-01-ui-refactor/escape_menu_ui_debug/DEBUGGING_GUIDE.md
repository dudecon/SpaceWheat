# Escape Menu UI - Debugging Guide

## Immediate Actions to Take

### 1. Check Boot Status
```
Run: godot
Expected: Game boots and main scene loads
Actual: [NEED TO VERIFY - Currently hangs]

If hangs, look for these in console:
✓ "💾 Creating Save/Load menu..." - Passes SaveLoadMenu instantiation?
✓ "💾 Save/Load menu instantiated" - Passes z_index assignment?
✓ "💾 Adding Save/Load menu to parent..." - Passes add_child()?
✓ "💾 Save/Load menu signals connected" - Passes signal connections?
```

### 2. If Game Boots, Test Save Button
```
Steps:
1. Press ESC to open menu (should see "🎮 ESC: Toggling escape menu")
2. Click "Save Game [S]" button
3. Check console for:
   - "💾 Save pressed" (from EscapeMenu._on_save_pressed)
   - "📋 OverlayManager._on_save_pressed() called" (from OverlayManager)
   - "save_load_menu exists: true"
   - "Calling show_menu(SAVE)..."
   - "save_load_menu.visible = true"
   - "💾 Save menu opened"

If you see "💾 Save pressed" but NOT the OverlayManager messages:
→ Signal connection is broken
→ Check: escape_menu.save_pressed.connect(_on_save_pressed)
```

### 3. Test Keyboard Input
```
Steps:
1. Press ESC to open menu
2. Press S key (should trigger same as button)

If S key doesn't work:
→ Check: EscapeMenu._input() method
→ Check: Is EscapeMenu visible?
→ Check: Is input being processed?
```

## Console Output to Collect

Run the game and provide the ENTIRE console output from startup until:
- Game fully boots, OR
- Game hangs with error message

Key things I'm looking for:
```
🎮 FarmUIController initializing...
📡 Controls manager connected to UI controller
...
💾 Creating Save/Load menu...
💾 Save/Load menu instantiated, setting properties...
💾 Adding Save/Load menu to parent...
💾 Save/Load menu created
💾 Connecting save/load menu signals...
💾 Save/Load menu signals connected
```

## Possible Issues & Quick Fixes

### Issue A: Game Hangs During Boot
**Likely Cause:** SaveLoadMenu._init() doing something blocking

**Quick Fix:**
1. Comment out SaveLoadMenu instantiation (lines 106-120 in OverlayManager.gd)
2. Try booting again
3. If boots successfully → SaveLoadMenu is the problem
4. If still hangs → Problem is elsewhere

### Issue B: Save/Load Menu Won't Open
**Possible Cause 1:** Signal not being emitted
- Check: Does "💾 Save pressed" appear in console?
- If NO: Button handler not being called
- If YES: Signal should be emitted

**Possible Cause 2:** Signal connection broken
- Check: Does "📋 OverlayManager._on_save_pressed() called" appear?
- If NO: Signal connection failed
- Check if method name is valid

**Possible Cause 3:** SaveLoadMenu exists but won't show
- Check: "save_load_menu exists: true"?
- Check: "save_load_menu.visible = true"?
- If both true but menu not visible: visibility issue in SaveLoadMenu

### Issue C: Keyboard Input Not Working
**Check In Order:**
1. Is EscapeMenu visible when pressing S?
2. Does EscapeMenu._input() get called?
3. Are KEY_S/KEY_L/KEY_D cases reached in the match statement?

## Code Review Checklist

Reviewers should check:

- [ ] SaveLoadMenu preload correct: `const SaveLoadMenu = preload("res://UI/Panels/SaveLoadMenu.gd")`
- [ ] Signal names match: `escape_menu.save_pressed.connect(_on_save_pressed)`
- [ ] Method signatures match: Both take no parameters
- [ ] Method names spelled correctly in signal connections
- [ ] OverlayManager methods exist and have correct names
- [ ] SaveLoadMenu.show_menu() method exists and takes Mode parameter
- [ ] SaveLoadMenu.Mode.SAVE and SaveLoadMenu.Mode.LOAD are valid
- [ ] No circular signal connections
- [ ] No deadlocks in initialization order
- [ ] z_index values make sense (SaveLoadMenu=101, EscapeMenu=100)
- [ ] parent.add_child() is correct (vs add_child() alone)

## Modified Signal Connections

### In OverlayManager (lines 100-102)
```gdscript
escape_menu.save_pressed.connect(_on_save_pressed)
escape_menu.load_pressed.connect(_on_load_pressed)
escape_menu.reload_last_save_pressed.connect(_on_reload_last_save_pressed)
```

Check:
- Do these methods exist in OverlayManager?
- Are they spelled correctly?
- Do they take the right parameters?

### In OverlayManager (lines 113-115)
```gdscript
save_load_menu.slot_selected.connect(_on_save_load_slot_selected)
save_load_menu.debug_environment_selected.connect(_on_debug_environment_selected)
save_load_menu.menu_closed.connect(_on_save_load_menu_closed)
```

Check:
- Do SaveLoadMenu signals have these exact names?
- Do the handler methods exist and take the right parameters?

## Specific Method Signatures to Verify

```gdscript
# EscapeMenu signals (should exist)
signal save_pressed()        # Line 9 (added quit_pressed)
signal load_pressed()        # Should exist
signal reload_last_save_pressed()  # Should exist

# EscapeMenu methods (should exist and emit signals)
func _on_save_pressed():     # Should emit save_pressed
    print("💾 Save pressed")
    save_pressed.emit()

func _on_load_pressed():     # Should emit load_pressed
    print("📂 Load pressed")
    load_pressed.emit()

func _on_reload_last_save_pressed():  # Should emit reload_last_save_pressed
    print("🔄 Reload last save pressed")
    reload_last_save_pressed.emit()

# OverlayManager methods (should exist)
func _on_save_pressed() -> void:     # Should receive escape_menu.save_pressed
func _on_load_pressed() -> void:     # Should receive escape_menu.load_pressed
func _on_reload_last_save_pressed() -> void:  # Should receive signal

# SaveLoadMenu signals (should exist)
signal slot_selected(slot: int, mode: String)
signal debug_environment_selected(env_name: String)
signal menu_closed()
```

## Export Contents

- `OverlayManager.gd` - Main issue likely here
- `EscapeMenu.gd` - Button and keyboard handlers
- `SaveLoadMenu.gd` - Save/load UI panel
- `FarmUIControlsManager.gd` - Signal routing
- `InputController.gd` - Input handling
- `FarmInputHandler.gd` - Farm tool input
- `FarmUIController.gd` - UI orchestrator
- `FarmUILayoutManager.gd` - Layout setup
- `README.md` - Overview
- `DEBUGGING_GUIDE.md` - This file

## Contact Points for Review

Focus areas for external review:
1. SaveLoadMenu instantiation and initialization
2. Signal connection syntax and validity
3. Method reference and naming
4. Input event flow and consumption
5. Z-index and visibility stacking
6. Parent-child relationships in UI tree
