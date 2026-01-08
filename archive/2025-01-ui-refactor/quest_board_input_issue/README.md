# Quest Board Input Issue - Complete Analysis

**Status:** Quest board opens but doesn't capture UIOP/ESC input 🔴

---

## Documents in This Folder

1. **PROBLEM_ANALYSIS.md** - Root cause analysis
   - What's broken and why
   - Inverted architecture issues
   - Input priority problems
   - All attempted fixes

2. **INPUT_FLOW_TRACE.md** - Debugging guide
   - Step-by-step input flow trace
   - Where to add debug prints
   - What console output to look for
   - Signal chain verification

3. **REFACTOR_PLAN.md** - Solution options
   - Quick hack (30 min)
   - Partial refactor (2 hours)
   - Full refactor (4-6 hours)
   - Step-by-step migration guide

---

## Quick Summary

### The Problem
Quest board **opens visually** but is **"transparent" to input**:
- ✅ C opens quest board
- ✅ C closes quest board
- ❌ UIOP keys still control game instead of quest slots
- ❌ ESC still affects game instead of closing board

### Root Causes

**Cause 1: Inverted Architecture**
```
FarmView (entry point)
└── PlayerShell (UI layer NESTED INSIDE)
    └── OverlayManager
        └── QuestBoard
```
**Should be:** PlayerShell at root, Farm as child

**Cause 2: Input Priority**
```
InputController._input() ← Runs FIRST (highest priority)
    ↓
Game processes input
    ↓
QuestBoard._unhandled_key_input() ← Never reached (lowest priority)
```

**Cause 3: Blocking Not Working**
Added `quest_board_visible` flag to block input, but it's either:
- Not being set by signal
- Or set too late
- Or checked in wrong place

---

## Three Solution Options

### Option 1: Quick Hack ⚡ (30 minutes)
**Change QuestBoard to use `_input()` instead of `_unhandled_key_input()`**

**Pros:**
- Works immediately
- Minimal code changes

**Cons:**
- Against Godot best practices
- Doesn't fix architecture
- Technical debt

**Code change:**
```gdscript
# UI/Panels/QuestBoard.gd
func _input(event: InputEvent) -> void:  # Was: _unhandled_key_input
	if not visible: return
	# ... rest stays the same
```

---

### Option 2: Partial Refactor 🔧 (2 hours)
**Remove farm reference, fix input blocking properly**

**Changes:**
1. Remove `overlay_manager.farm = farm`
2. Pass biome via method parameters:
   ```gdscript
   overlay_manager.toggle_quest_board(farm.biotic_flux_biome)
   ```
3. Fix signal timing or use direct method call
4. Keep scene hierarchy as-is

**Pros:**
- Decouples OverlayManager from Farm
- Fixes blocking issue properly
- Doesn't break existing structure

**Cons:**
- Doesn't fix inverted hierarchy
- Still has architectural issues

---

### Option 3: Full Refactor 🏗️ (4-6 hours)
**Fix the entire architecture**

**Changes:**
1. Make PlayerShell the main scene entry point
2. Farm becomes child of PlayerShell
3. Remove FarmView layer
4. OverlayManager gets data via methods
5. Fix input priority naturally

**Pros:**
- Correct Godot architecture
- Clean separation of concerns
- Future-proof
- Follows best practices

**Cons:**
- Takes longer
- More testing needed
- Higher risk of breaking things

---

## My Recommendation

**Do Option 1 (quick hack) NOW to unblock development**
- Gets quest board working in 30 minutes
- Can continue building features

**Then do Option 3 (full refactor) LATER when you have time**
- Schedule 4-6 hours for clean architecture
- Do it when you're not in feature-development mode
- Makes future development easier

**Why not Option 2?**
- Takes almost as long as Option 3
- Doesn't fix the core problem
- Still leaves architectural debt

---

## Next Steps

### Immediate (You Choose):
1. **Quick hack:** Change `_unhandled_key_input` to `_input` in QuestBoard.gd
2. **Debug first:** Add debug prints per INPUT_FLOW_TRACE.md to find exact break point
3. **Full refactor:** Follow REFACTOR_PLAN.md step-by-step

### Questions for You:
1. Do you want the quick hack to unblock, or proper refactor?
2. Is FarmView serving a purpose we need to preserve?
3. How much time do you have for this fix?
4. Should we debug first to understand exactly where it breaks?

---

## Files to Review

**Current implementation:**
- UI/Controllers/InputController.gd (input router)
- UI/Panels/QuestBoard.gd (modal, not capturing input)
- UI/FarmView.gd (entry point, signal wiring)
- UI/Managers/OverlayManager.gd (overlay management)

**Test cases:**
- llm_outbox/quest_board_testing_guide.md (manual test checklist)

**Documentation:**
- llm_outbox/modal_quest_board_implementation.md (original implementation)
- llm_outbox/quest_board_modal_ui_fixes.md (UI pattern fixes)

---

## Contact Points

**If you need help:**
- See INPUT_FLOW_TRACE.md for debugging steps
- See REFACTOR_PLAN.md for implementation guide
- Check console output when pressing C and UIOP

**Want me to:**
- [ ] Do the quick hack (30 min)
- [ ] Add debug prints and investigate (30 min)
- [ ] Do the full refactor (4-6 hours)
- [ ] Something else?
