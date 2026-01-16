# SpaceWheat Input & Overlay Architecture Analysis

**Date:** 2026-01-15
**Purpose:** Deep dive on menu, overlay, and input handling systems compared to Godot 4 best practices

---

## Current Architecture Map

### Input Event Flow

```
KEY PRESS EVENT
       ↓
┌──────────────────────────────────────────────────────────────────┐
│ LAYER 1: PlayerShell._input()  [HIGH PRIORITY]                   │
│                                                                   │
│  1. Is overlay stack not empty?                                  │
│     YES → overlay_stack.route_input(event)                       │
│           → top_overlay.handle_input(event)                      │
│           → If returns true: set_input_as_handled() + RETURN     │
│                                                                   │
│  2. Try shell actions (_handle_shell_action)                     │
│     ESC → _toggle_escape_menu()                                  │
│     C/V/B/N/K → _toggle_v2_overlay(name)                         │
│     L → _toggle_logger_config()                                  │
│     If matched: set_input_as_handled() + RETURN                  │
│                                                                   │
│  3. Not consumed → falls through                                 │
└──────────────────────────────────────────────────────────────────┘
       ↓
┌──────────────────────────────────────────────────────────────────┐
│ LAYER 3: FarmInputHandler._unhandled_input()  [NORMAL PRIORITY]  │
│                                                                   │
│  Global: Space (pause), H (harvest), Tab (mode), F (cycle)       │
│  Tools: 1-6 → _select_tool(i)                                    │
│  Plots: T/Y/U/I/O/P → _toggle_plot_selection(pos)                │
│  Actions: Q/E/R → _execute_tool_action(key)                      │
│  Movement: W/A/S/D → _move_selection(direction)                  │
│  Selection: [ (clear), ] (restore), Backspace (remove gates)     │
└──────────────────────────────────────────────────────────────────┘
```

### Overlay Stack System

```
Z-Index Tiers (Higher = More Priority):
┌────────────────────────────────────────┐
│ Z_TIER_SYSTEM = 4000                   │ ← EscapeMenu, SaveLoadMenu
├────────────────────────────────────────┤
│ Z_TIER_MODAL = 3000                    │ ← QuestBoard, BiomeInspector
├────────────────────────────────────────┤
│ Z_TIER_INFO = 2000                     │ ← Inspector, Vocabulary, Controls
├────────────────────────────────────────┤
│ Z_TIER_HUD = 1000                      │ ← ActionBar (not on stack)
└────────────────────────────────────────┘

Push behavior: Higher tier overlays auto-close lower tier overlays
```

### Component Responsibilities

| Component | Responsibility |
|-----------|----------------|
| **PlayerShell** | Top-level input routing, overlay coordination, shell actions |
| **OverlayStackManager** | Stack management, tier-based priority, input routing to top overlay |
| **OverlayManager** | Overlay creation, registration, toggle logic |
| **V2OverlayBase** | Base class for v2 overlays, QER+F actions, WASD navigation |
| **EscapeMenu** | Pause menu, implements overlay interface |
| **FarmInputHandler** | Farm gameplay input, tool/plot/action system |

---

## Godot 4 Best Practices

### Input Handling Hierarchy

According to [Godot Input Examples](https://docs.godotengine.org/en/latest/tutorials/inputs/input_examples.html) and [GDQuest Input Cheatsheet](https://school.gdquest.com/cheatsheets/input):

```
Godot's Input Propagation Order:
1. _input()           - Called first, for high-priority input
2. _gui_input()       - Control-specific input (within bounding box)
3. _unhandled_input() - Called after GUI, for gameplay input
4. _input_event()     - For 3D/2D physics objects
```

**Best Practice**: Use `_unhandled_input()` for gameplay so GUI can intercept events first.

### `_input()` vs `_unhandled_input()`

| Method | Best For | Behavior |
|--------|----------|----------|
| `_input()` | UI, global shortcuts, menus | Called for ALL nodes, ignores GUI consumption |
| `_unhandled_input()` | Gameplay input | Only called if GUI didn't consume the event |

From [Godot Forum Discussion](https://forum.godotengine.org/t/why-do-tutorials-use-unhandled-input-event-instead-of-input-event/88084):
> "For gameplay inputs, favor `_unhandled_input()` because it allows the GUI to intercept events."

### Consuming Input

```gdscript
# CORRECT: Consume input to stop propagation
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        toggle_pause_menu()
        get_viewport().set_input_as_handled()  # CRITICAL!
```

### Mouse Filter for Modals

From [Godot Control Documentation](https://docs.godotengine.org/en/stable/classes/class_control.html):

| Mouse Filter | Behavior |
|--------------|----------|
| `MOUSE_FILTER_STOP` | Consume the event, don't pass to parent |
| `MOUSE_FILTER_PASS` | Consume but also pass to parent (for scroll containers) |
| `MOUSE_FILTER_IGNORE` | Don't consume, let it pass through |

**Modal Dialog Pattern**: Use `MOUSE_FILTER_STOP` on the modal background to block clicks from reaching content behind it.

### Modal Systems (Community Best Practices)

From [Godot-Modal-World](https://github.com/dragunoff/Godot-Modal-World):
- Modal windows should be **blocking** and appear on top of everything
- Use `process_mode` for paused game handling
- Nested modals are supported but **not recommended** (anti-pattern)

From [Godot Issue #19450](https://github.com/godotengine/godot/issues/19450):
- True modal dialogs should prevent all `_input()` from other nodes
- The `exclusive` property on Popup was intended for this but has limitations

---

## Analysis: SpaceWheat vs Best Practices

### ✅ What SpaceWheat Does Well

1. **Layered Input Architecture**
   - PlayerShell uses `_input()` for overlay/menu routing (high priority)
   - FarmInputHandler uses `_unhandled_input()` for gameplay (after GUI)
   - This matches Godot's recommended pattern

2. **Unified Stack Manager**
   - Single source of truth for active overlays
   - Tier-based priority system
   - Clean `push()`/`pop()` interface

3. **Input Consumption**
   - Uses `set_input_as_handled()` when consuming input
   - Returns `bool` from `handle_input()` to indicate consumption

4. **V2 Overlay Base Class**
   - Consistent interface for all overlays
   - QER+F action pattern
   - WASD grid navigation

### ⚠️ Potential Issues Identified

#### Issue 1: ESC Key Double-Dispatch Bug

**Problem**: When pressing ESC to close a v2 overlay, the overlay doesn't consume ESC. It returns `false`, causing `_handle_shell_action()` to also process it and toggle the EscapeMenu.

```gdscript
# V2OverlayBase.handle_input()
match event.keycode:
    KEY_ESCAPE:
        return false  # ← BUG: Let OverlayManager handle, but...

# PlayerShell._handle_shell_action() ALSO runs after overlay doesn't consume
match event.keycode:
    KEY_ESCAPE:
        _toggle_escape_menu()  # ← Opens EscapeMenu!
        return true
```

**Fix**: V2 overlays should consume ESC and close themselves:
```gdscript
# V2OverlayBase.handle_input()
match event.keycode:
    KEY_ESCAPE:
        deactivate()
        return true  # CONSUME the event
```

Or: OverlayStackManager should handle ESC specially.

#### Issue 2: Overlay Toggle Logic

**Problem**: Shell actions (C/V/B/N/K) can toggle overlays even when another overlay is active. This can create confusing state.

```gdscript
# PlayerShell._input() current flow:
1. Route to top overlay → consumed? return
2. Try shell actions (C/V/B/N/K) → can toggle NEW overlay!
```

**Best Practice**: When an overlay is active, only ESC should close it (or overlay-specific keys). Shell toggle keys should either:
- Be blocked while overlay is active, OR
- Close current overlay first

#### Issue 3: EscapeMenu Doesn't Use Stack Properly

**Problem**: Looking at the test output, EscapeMenu's `show_menu()` was called after opening Controls overlay. The EscapeMenu may be getting pushed to stack incorrectly.

From `_toggle_escape_menu()`:
```gdscript
func _toggle_escape_menu():
    if escape_menu.visible:
        _pop_modal(escape_menu)
    else:
        _push_modal(escape_menu)  # ← This pushes to stack
        escape_menu.show_menu()   # ← This pauses game
```

But `show_menu()` does:
```gdscript
func show_menu():
    visible = true
    get_tree().paused = true  # ← PAUSES GAME!
```

**Issue**: If `process_mode` isn't set correctly on other nodes, pausing the game might cause issues.

#### Issue 4: No `_gui_input()` for Control-Specific Input

**Observation**: SpaceWheat overlays don't use `_gui_input()` for their internal button/selection handling. They rely entirely on the parent routing system.

**Best Practice**: Control-specific input (like clicking items in a list) should use `_gui_input()` or proper Control signals, not just top-down key routing.

#### Issue 5: Mouse Filter Not Set on Modal Backgrounds

**Check Needed**: Do modal overlays (EscapeMenu, QuestBoard) have `mouse_filter = MOUSE_FILTER_STOP` on their background ColorRect? Without this, clicks might pass through to game elements behind.

From EscapeMenu._init():
```gdscript
mouse_filter = Control.MOUSE_FILTER_STOP  # ✅ Good - root control blocks
```

But this only blocks clicks ON the menu panel, not the semi-transparent background covering the whole screen.

---

## Specific Bug: Why EscapeMenu Intercepted Input

From the test output:
```
[INFO][UI] 📖 Opened v2 overlay: controls
📋 Menu opened - Game PAUSED        ← EscapeMenu.show_menu() was called!
...
📋 EscapeMenu.handle_input() KEY: 81
🚪 Quit pressed from menu
```

**Root Cause Analysis**:

1. Controls overlay (K) opened via `_toggle_v2_overlay("controls")`
2. Something triggered `EscapeMenu.show_menu()` (the "📋 Menu opened - Game PAUSED" line)
3. EscapeMenu is now on the stack AND visible
4. When Q is pressed, it goes to EscapeMenu.handle_input() first (tier 4000 > tier 2000)
5. EscapeMenu interprets Q as "Quit"

**Possible Causes**:
- Race condition in overlay stack push
- EscapeMenu's `activate()` being called incorrectly
- Signal misconfiguration causing double-push

---

## Recommendations

### Immediate Fixes

1. **V2OverlayBase should consume ESC**:
```gdscript
func handle_input(event: InputEvent) -> bool:
    # ... existing code ...

    if event.keycode == KEY_ESCAPE:
        # Close this overlay, consume the event
        overlay_closed.emit()
        return true  # CONSUME!

    return false
```

2. **Block shell toggles when overlay is active**:
```gdscript
func _handle_shell_action(event: InputEvent) -> bool:
    # If ANY overlay is active (except checking for ESC), don't process toggles
    if overlay_stack and not overlay_stack.is_empty():
        if event.keycode == KEY_ESCAPE:
            # ESC is special - close top overlay
            overlay_stack.pop()
            return true
        # Block other shell keys while overlay is active
        return false

    # Normal toggle handling when no overlay active
    match event.keycode:
        KEY_C: _toggle_v2_overlay("quests"); return true
        # ...
```

3. **Add debug logging to overlay push/pop**:
```gdscript
func push(overlay: Control) -> void:
    print("📥 OverlayStack.push(%s) tier=%d" % [overlay.name, get_overlay_tier(overlay)])
    print("   Stack before: %s" % [overlay_stack.map(func(o): return o.name)])
    # ... existing push logic ...
    print("   Stack after: %s" % [overlay_stack.map(func(o): return o.name)])
```

### Architectural Improvements

1. **Centralize ESC Handling**:
   - ESC should ALWAYS go through OverlayStackManager
   - OverlayStackManager pops top overlay
   - If stack is empty, THEN open EscapeMenu

2. **Use Godot's Built-in Modal System** (optional):
   - Consider using `Popup` or `Window` nodes with `exclusive = true`
   - These handle modal blocking automatically

3. **Separate "System Menus" from "Info Overlays"**:
   - System menus (ESC, Save/Load) should pause game
   - Info overlays (V, B, N, K) should NOT pause game
   - Different input handling for each category

4. **Add Input Action Map**:
   - Instead of checking `KEY_Q`, `KEY_E`, etc.
   - Use Input Actions: `ui_action_q`, `ui_action_e`
   - More flexible, supports remapping

---

## Visual Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PlayerShell._input()                          │
│                        [LAYER 1 - High Priority]                     │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │              OverlayStackManager                                 │ │
│  │  ┌──────────┬──────────┬──────────┬──────────┐                 │ │
│  │  │ EscapeMenu│ QuestBoard│ Inspector │ Controls │                 │ │
│  │  │ TIER 4000 │ TIER 3000 │ TIER 2000 │ TIER 2000│                 │ │
│  │  │           │           │           │          │                 │ │
│  │  │ handle_   │ handle_   │ handle_   │ handle_  │                 │ │
│  │  │ input()   │ input()   │ input()   │ input()  │                 │ │
│  │  └──────────┴──────────┴──────────┴──────────┘                 │ │
│  │                      ↑                                          │ │
│  │        overlay_stack.route_input(event)                         │ │
│  │        → Calls top overlay's handle_input()                     │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  If not consumed by overlay:                                        │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │              _handle_shell_action()                              │ │
│  │  ESC → _toggle_escape_menu()                                    │ │
│  │  C/V/B/N/K → _toggle_v2_overlay()                               │ │
│  │  L → _toggle_logger_config()                                    │ │
│  └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                               ↓
                    (If not consumed, falls through)
                               ↓
┌─────────────────────────────────────────────────────────────────────┐
│                 FarmInputHandler._unhandled_input()                  │
│                 [LAYER 3 - Normal Priority]                          │
│                                                                      │
│  Global: Space, H, Tab, F                                           │
│  Tools: 1-6                                                          │
│  Plots: T/Y/U/I/O/P                                                  │
│  Actions: Q/E/R                                                      │
│  Movement: W/A/S/D                                                   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Summary

| Aspect | Current State | Best Practice | Status |
|--------|---------------|---------------|--------|
| Input layer separation | `_input()` + `_unhandled_input()` | ✅ Correct | Good |
| Input consumption | Uses `set_input_as_handled()` | ✅ Correct | Good |
| Modal stack management | Custom OverlayStackManager | ✅ Good pattern | Good |
| ESC key handling | Double-dispatch bug | Should consume in overlay | **BUG** |
| Shell toggles during overlay | Allows opening new overlays | Should block or close first | **Issue** |
| Mouse filter on modals | Set on panel, not background | Should cover full screen | Check |
| Game pausing | EscapeMenu pauses, others don't | Mixed approach is fine | OK |

---

## Sources

- [Godot Input Examples Documentation](https://docs.godotengine.org/en/latest/tutorials/inputs/input_examples.html)
- [GDQuest Input Cheatsheet](https://school.gdquest.com/cheatsheets/input)
- [Godot Control Documentation](https://docs.godotengine.org/en/stable/classes/class_control.html)
- [Godot Modal Dialog Issue #19450](https://github.com/godotengine/godot/issues/19450)
- [Godot-Modal-World Plugin](https://github.com/dragunoff/Godot-Modal-World)
- [Input Propagation Tutorial](https://godottutorials.com/courses/godot-basics-series/godot-basics-tutorial-17/)
- [_input vs _unhandled_input Discussion](https://forum.godotengine.org/t/why-do-tutorials-use-unhandled-input-event-instead-of-input-event/88084)
