# UI Architecture Review Request

**Status:** 🔴 CRITICAL - UI system has fundamental architecture issues
**Date:** 2026-01-04

---

## What's In This Folder

1. **UI_ARCHITECTURE.md** - Complete UI hierarchy, z-ordering, and architectural questions
2. **CURRENT_WARNINGS.md** - Specific warnings, code snippets, and what we've tried
3. **README.md** (this file) - Summary and action items

---

## TL;DR - The Problem

**Our UI has conflicting sizing systems that fight each other:**

1. ⚠️ Godot warns about anchor/size conflicts (hundreds of warnings)
2. ❌ Dynamic toolbar repositioning fails (appears in wrong location)
3. 🔥 Multiple sizing mechanisms conflict:
   - Godot anchors/offsets
   - Container size flags
   - Custom minimum size
   - Scene file properties vs runtime code

**Result:** Fragile UI that breaks when we change things, warnings everywhere, toolbars in wrong positions.

---

## Immediate Issues Needing Fix

### 1. ActionPreviewRow (QER buttons) Position
- **Expected:** Bottom center, 80px from bottom
- **Actual:** Upper left corner
- **Why:** Node reparented at runtime, retains old layout properties
- **File:** `UI/PlayerShell.gd:349-381`

### 2. Anchor/Size Warnings (Hundreds of Them)
- **Warning:** "Nodes with non-equal opposite anchors will have their size overridden"
- **Source:** `UI/PlotTile.gd:439` (happens for every plot element)
- **Why:** Setting `size` on nodes with anchors (0,0) to (1,1)
- **Impact:** Console spam, undefined behavior, sizing breaks

### 3. Layout System Confusion
- **Problem:** 3 different sizing systems active simultaneously
- **Impact:** Code fights itself, unpredictable results
- **Need:** Pick ONE system and stick to it

---

## Questions for Architecture Review

### Priority 1: Sizing Strategy
**Q:** Should we use anchors OR custom_minimum_size, never both?
**Q:** When are containers appropriate vs manual positioning?
**Q:** What's the Godot-approved pattern for responsive UI?

### Priority 2: Dynamic Reparenting
**Q:** Is moving nodes at runtime a Godot anti-pattern?
**Q:** Should we create UI programmatically instead of .tscn files?
**Q:** How to properly clear layout properties when reparenting?

### Priority 3: Z-Ordering
**Q:** Is our CanvasLayer + z_index mixing sustainable?
**Q:** Too many magic z_index numbers (50, 100, 1000, 1500, 5000, 8000, 9999)?
**Q:** Better architectural pattern for depth management?

---

## Recommended Reading Order

1. Start with **UI_ARCHITECTURE.md** for full context
2. Review **CURRENT_WARNINGS.md** for specific code issues
3. Check the actual code files listed in each document
4. Provide architectural guidance

---

## What We Need

**Architectural guidance on:**

✅ **Correct UI hierarchy design** - What should the structure be?
✅ **One consistent sizing approach** - Stop mixing incompatible systems
✅ **Dynamic UI patterns** - Best way to reposition nodes at runtime
✅ **Z-ordering strategy** - Sustainable depth management
✅ **Initialization timing** - When to size nodes, role of deferred calls

**Desired outcome:**
- No console warnings
- Toolbars appear where we tell them to
- Sustainable, maintainable UI architecture
- Clear rules: "use X for Y, never mix with Z"

---

## Current Status

**What works:**
- ✅ Modal input routing (PlayerShell modal stack)
- ✅ Visual z-ordering (mostly correct depth)
- ✅ Overlay system (quest board, menus)

**What's broken:**
- ❌ Toolbar positioning (wrong location)
- ❌ Anchor/size conflicts (hundreds of warnings)
- ❌ Fragile (breaks when we change things)

**What's unclear:**
- ❓ Is our hierarchy too deep? (5+ levels)
- ❓ Should we refactor from scratch?
- ❓ Are we fighting Godot's layout system?

---

## Files for Review

**Critical files:**
```
UI/PlayerShell.gd       # Dynamic reparenting (broken)
UI/PlotTile.gd         # Anchor/size warnings (source)
UI/FarmUI.tscn         # Scene structure
UI/FarmView.gd         # Root orchestration
```

**Supporting files:**
```
UI/PlotGridDisplay.gd
UI/Managers/OverlayManager.gd
Core/Boot/BootManager.gd
```

---

## Next Steps

1. **Review architecture docs** in this folder
2. **Identify anti-patterns** we're using
3. **Provide refactoring guidance** with clear examples
4. **Prioritize fixes** - what to tackle first?

---

**Thank you for reviewing! We need expert Godot UI architecture guidance to fix this properly.**
