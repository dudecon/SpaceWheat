# Additional Architecture Information - Round 2

**Date:** 2026-01-05
**Update:** Added data model, boot sequence, input flow, and visualization details

---

## What's New (10 Additional Files)

### Data Model Files:
- **Farm.gd.txt** (39KB) - Root game state container
- **FarmGrid.gd.txt** (63KB) - Plot storage and biome registration system
- **BioticFluxBiome.gd.txt** (15KB) - Concrete biome implementation example
- **BiomeBase.gd.txt** (72KB) - Biome base class with quantum interface
- **BasePlot.gd.txt** (13KB) - Plot data structure

### Boot & Input:
- **BootManager.gd.txt** (5.3KB) - Multi-stage boot sequence
- **FarmInputHandler.gd.txt** (64KB) - Key-to-action mapping

### Visualization:
- **PlotTile.gd.txt** (25KB) - Individual plot visual component

### Scene Structure:
- **FarmView.tscn.txt** (303 bytes) - Root scene definition

### Documentation:
- **ARCHITECTURE_DEEP_DIVE.md** (20KB) - Answers all architecture questions

---

## Export Summary

**Total Files:** 29
**Total Size:** 616KB
**Documentation:** 6 markdown files
**Code Files:** 23 .gd and .tscn files (renamed to .txt)

---

## Start Here for Architecture Review

### Priority 1 - Understanding the System
1. **ARCHITECTURE_DEEP_DIVE.md** - Complete answers to all questions
   - Data model relationships
   - Boot sequence breakdown
   - Input flow diagram
   - Visualization architecture
   - The "2-day registration problem" explanation

### Priority 2 - The UI Problem
2. **UI_DISPLAY_SUMMARY.md** - Visual hierarchy and broken components
3. **VISUAL_ISSUE_DIAGRAM.md** - Visual comparison of expected vs actual
4. **README.md** - Original investigation overview

### Priority 3 - Specific Components
5. **PlayerShell.gd.txt** - The broken reparenting code (lines 333-396)
6. **BootManager.gd.txt** - When reparenting happens (Stage 3C)
7. **OverlayManager.gd.txt** - Working positioning examples

---

## Questions Answered in ARCHITECTURE_DEEP_DIVE.md

### 1. The Data Model

**Q: What does Farm.gd actually contain?**
- Root game state container
- Owns: FarmGrid, FarmEconomy, BioticFluxBiome, QuantumBath
- Relationships documented with code examples

**Q: What's the relationship to Grid/Biomes?**
- Grid stores 6 plots + biome_registrations dictionary
- Biome operates on QuantumBath, tracks registered_plots indices
- Grid acts as REGISTRAR between plots and biomes

**Q: How are plots stored in Grid?**
- Array[BasePlot] of size 6
- Indexed 0-5 (matches TYUIOP keyboard)
- biome_registrations: Dictionary mapping biomes → plot indices

**Q: What's the quantum state interface?**
- BiomeBase owns QuantumBath (density matrix)
- Methods: register_plot(), get_plot_state(), evolve()
- Quantum flow: Bath → Biome → Grid → Plot → UI

---

### 2. The Boot Sequence

**Q: What exactly does boot() do?**

Complete 4-stage breakdown:
1. **Stage 1:** Autoloads ready
2. **Stage 2:** Create Farm (data model)
3. **Stage 3:** Instantiate + Setup + Mount FarmUI
   - **Stage 3C** = PlayerShell.load_farm_ui() ← **UI BREAKS HERE**
4. **Stage 4:** Register plots to biomes

Timing diagram shows exactly when _move_action_bar_to_top_layer() fires.

---

### 3. The Input Flow

**Q: How does input get from keys to actions?**

2-layer hierarchy documented:
1. **Layer 1:** PlayerShell._input()
   - Modal stack (highest priority)
   - Shell actions (C/K/ESC)
   - Falls through if not consumed

2. **Layer 2:** Farm._unhandled_input() → FarmInputHandler
   - Tool selection (1-6)
   - Plot targeting (TYUIOP)
   - Action keys (QER)

**Q: How does the modal stack actually work?**

Complete implementation shown:
- Array[Control] modal_stack
- _push_modal() / _pop_modal()
- handle_input() contract
- Example flow for opening/closing quest board

---

### 4. The Quantum Visualization

**Q: How does PlotGridDisplay know which plots belong to which biome?**

**The 2-Day Registration Problem** explained in detail:
- Why auto-detection failed (4 attempted solutions)
- Current working solution: explicit registration
- Grid.biome_registrations as single source of truth

**Q: What's the "registration" problem you mentioned?**

Complete breakdown:
- Original approach (auto-detect biome ownership) - FAILED
- Attempted solutions 1-3 - All had timing issues
- Solution 4 (explicit registration in boot) - WORKS

Visualization flow documented:
```
QuantumBath → Biome → Grid registrations → PlotGridDisplay → Viz Controller → Screen
```

---

### 5. Scene Structure

**Q: What's the actual root scene?**

**FarmView.tscn** - documented with hierarchy:
- FarmView (root Control)
  - Creates PlayerShell.tscn dynamically
  - Creates viz_layer (CanvasLayer)
  - Creates Farm (data)

Scene instantiation order timeline shows exactly when each _ready() fires and when UI breaks.

---

## Key Insights from Deep Dive

### The Core UI Problem (Confirmed)

**Root Cause:** Dynamic reparenting in boot Stage 3C

**Evidence:**
1. Working components (overlays) created in final parent, never moved
2. Broken components (action bars) created in .tscn, reparented at runtime
3. Timing: Reparenting happens during PlayerShell.load_farm_ui()
4. Even with `await process_frame`, parent not fully sized yet

**The Fix (Hypothesis):**
- Create action bars directly in ActionBarLayer
- Skip reparenting entirely
- OR: Fix the timing/sizing cascade

### The Registration Problem (Solved)

**What took 2 days:**
- Figuring out who owns "which plots belong to which biome"
- Tried 4 different approaches
- Finally: explicit registration in boot sequence
- Grid.biome_registrations = single source of truth

**Lessons:**
- Timing-dependent initialization is fragile
- Explicit is better than implicit
- Single source of truth prevents race conditions

### The Input Flow (Clean)

**Actually well-designed:**
- Modal stack works correctly
- Priority system clear
- Fall-through pattern good
- No issues here

---

## Files by Category

### Critical for UI Fix:
1. PlayerShell.gd.txt - Broken reparenting
2. BootManager.gd.txt - When it happens
3. FarmView.gd.txt - Scene creation order
4. FarmUI.tscn.txt - Original location of action bars

### Working Examples:
5. OverlayManager.gd.txt - How overlays position correctly
6. QuestBoard.gd.txt - Center positioning that works
7. EscapeMenu.gd.txt - Fullscreen overlay that works

### Data Model Context:
8. Farm.gd.txt - Root state container
9. FarmGrid.gd.txt - Plot storage + registrations
10. BiomeBase.gd.txt - Quantum interface
11. BioticFluxBiome.gd.txt - Concrete example
12. BasePlot.gd.txt - Plot structure

### Input & Visualization:
13. FarmInputHandler.gd.txt - Input routing
14. PlotGridDisplay.gd.txt - Visualization manager
15. PlotTile.gd.txt - Individual plot visual
16. BathQuantumVisualizationController.gd.txt - Biome rendering

---

## Recommended Investigation Path

### For Understanding the System:
1. Read **ARCHITECTURE_DEEP_DIVE.md** (all questions answered)
2. Read **Farm.gd.txt** (10 min - see data model)
3. Read **BootManager.gd.txt** (5 min - see boot sequence)

### For Fixing the UI:
4. Read **UI_DISPLAY_SUMMARY.md** (the problem)
5. Read **VISUAL_ISSUE_DIAGRAM.md** (visual comparison)
6. Read **PlayerShell.gd.txt** lines 333-396 (broken code)
7. Compare with **OverlayManager.gd.txt** lines 770-832 (working code)

### For Complete Context:
8. Skim **FarmInputHandler.gd.txt** (input flow)
9. Skim **PlotGridDisplay.gd.txt** (visualization)
10. Reference other files as needed

---

## Quick Reference

### The Broken Code:
**File:** PlayerShell.gd.txt
**Lines:** 333-396
**Function:** _move_action_bar_to_top_layer()
**Problem:** Reparents action bars from FarmUI to ActionBarLayer, positioning fails

### The Working Code:
**File:** OverlayManager.gd.txt
**Lines:** 770-832
**Function:** _create_touch_button_bar()
**Success:** Creates buttons directly in final parent, positions correctly

### The Root Cause:
**When:** Boot Stage 3C (PlayerShell.load_farm_ui)
**What:** Dynamic reparenting before parent is fully sized
**Why:** Timing cascade - FarmView → PlayerShell → ActionBarLayer sizing

---

## Export Stats

| Category | Files | Size |
|----------|-------|------|
| Documentation | 6 | 77KB |
| UI Scripts | 12 | 215KB |
| Data Model | 5 | 202KB |
| Visualization | 3 | 81KB |
| Input/Boot | 2 | 69KB |
| Scene Files | 1 | 303B |
| **TOTAL** | **29** | **616KB** |

---

## Status

✅ **All requested architecture information provided**

The bot now has:
- Complete data model relationships
- Exact boot sequence timing
- Full input flow diagram
- Visualization architecture explained
- Scene structure documented
- The broken code identified
- Working examples provided

**Ready for architecture review and recommendations.**
