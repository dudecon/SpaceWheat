# 🔧 Tooling System Issues Identified

**Date:** 2026-01-16
**Focus:** Action button highlighting and keystroke dispatch
**Status:** Investigation complete - Multiple critical bugs found

---

## ISSUE 1: MEASURE and POP Ignore Selected Plots Parameter

**Severity:** 🔴 CRITICAL
**Category:** Action Dispatch Bug
**Impact:** MEASURE and POP actions only work from `current_selection`, not from checkbox-selected plots

### Evidence

**File:** `UI/FarmInputHandler.gd` lines 1445-1523

**_action_measure() signature:**
```gdscript
func _action_measure(positions: Array[Vector2i]):  # positions parameter received!
    var biome = farm.grid.get_biome_for_plot(current_selection)  # IGNORES positions!
    var terminal = _find_active_terminal_in_biome(biome)  # Searches in CURRENT biome only
```

**_action_pop() signature:**
```gdscript
func _action_pop(positions: Array[Vector2i]):  # positions parameter received!
    var biome = farm.grid.get_biome_for_plot(current_selection)  # IGNORES positions!
    var terminal = _find_measured_terminal_in_biome(biome)  # Searches in CURRENT biome only
```

### Root Cause

Both methods accept `positions: Array[Vector2i]` from the checkbox selection system, but:
1. **Never use the `positions` parameter**
2. **Always use `current_selection`** instead (which may be different from selected plots)
3. **Only search within one biome** (the biome at `current_selection`)

### Player Experience Impact

**Scenario:**
1. Player selects plot at (2,0) via checkbox (part of BioticFlux)
2. Player moves cursor to plot at (5,0) (part of Forest) - this becomes `current_selection`
3. Player presses E (MEASURE)
4. Expected: Measure the explored terminal in BioticFlux
5. Actual: Tries to measure in Forest (wrong biome), finds no terminals, fails with "No terminals to measure"

### Why It Fails Silently

The availability check (_can_execute_measure) correctly identifies that terminals exist:
```gdscript
for terminal in farm.plot_pool.get_active_terminals():
    if terminal.bound_biome and terminal.bound_biome.get_biome_type() == biome.get_biome_type():
        return true  # ✓ Returns TRUE - button highlighted
```

But action execution uses a DIFFERENT biome (current_selection), so fails:
```gdscript
# Check availability - uses biome from selected plots (correct)
var biome = _get_current_biome()  # From first checkbox-selected plot
# ... [action_performed.emit shows "MEASURE available"]

# Execute action - uses biome from cursor position (wrong!)
var biome = farm.grid.get_biome_for_plot(current_selection)  # From cursor
```

---

## ISSUE 2: EXPLORE Availability Not Properly Updated After Exploration

**Severity:** 🟠 MAJOR
**Category:** Action State Management
**Impact:** EXPLORE stays highlighted even when all registers are bound, giving false indication action will succeed

### Evidence

**File:** `UI/FarmInputHandler.gd` lines 3035-3055

**_can_execute_explore() logic:**
```gdscript
# Must have unbound registers
var probabilities = biome.get_register_probabilities()
return not probabilities.is_empty()
```

This checks if the current biome has ANY unbound registers.

**Problem:** It doesn't account for:
1. **Already-explored plots** in the same biome
2. **Terminal pool exhaustion** - if all terminals are bound in current biome, EXPLORE will still show as available but fail when executed

### What Happens

1. User EXPLOREs plot 1 (BioticFlux) - biome has 3 registers, 2 remain unbound
2. EXPLORE button stays bright green (because biome still has unbound registers)
3. User EXPLOREs plot 2 (BioticFlux) - biome has 3 registers, 1 remains unbound
4. EXPLORE button still bright green
5. User EXPLOREs plot 3 (BioticFlux) - biome has 3 registers, 0 remain unbound
6. **EXPLORE button STILL bright green** (this is the bug!)
7. User presses Q, EXPLORE fails: "no_registers"

### Root Cause

The availability check only looks at **register capacity**, not:
- Whether the plot was already explored
- Whether terminals exist to bind to registers
- Terminal pool state

---

## ISSUE 3: Checkbox Selection Not Properly Passed to MEASURE/POP

**Severity:** 🔴 CRITICAL
**Category:** Multi-Select Architecture Mismatch
**Impact:** Users can't MEASURE or POP from checkbox-selected plots; only works from cursor position

### Architecture Mismatch

**How actions are dispatched (line 795-797):**
```gdscript
var selected_plots: Array[Vector2i] = []
if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
    selected_plots = plot_grid_display.get_selected_plots()  # Get checkboxes

if selected_plots.is_empty():
    selected_plots = [current_selection]  # Fallback to cursor

match action:
    "measure":
        _action_measure(selected_plots)  # Pass checkbox selection
```

**How MEASURE receives it (line 1456):**
```gdscript
func _action_measure(positions: Array[Vector2i]):
    var biome = farm.grid.get_biome_for_plot(current_selection)  # IGNORES positions parameter
```

The parameter is passed but never used!

### Why This Breaks Measurement Flow

1. **EXPLORE is called without position parameter** (line 793) - so it ignores checkboxes too
   - But EXPLORE doesn't need positions (it explores from current_selection's biome)

2. **MEASURE receives positions but ignores them** (line 1456)
   - Should search in biome(s) of selected plots
   - Instead searches in biome of cursor position

3. **POP receives positions but ignores them** (line 1497)
   - Should pop from selected plots
   - Instead pops from cursor position

---

## ISSUE 4: Action Availability Uses Different Biome Than Execution

**Severity:** 🔴 CRITICAL
**Category:** State Inconsistency
**Impact:** Button is highlighted but action fails, creating broken UI feedback

### The Mismatch

**When checking if MEASURE is available (line 3072-3075):**
```gdscript
func _can_execute_measure() -> bool:
    var biome = _get_current_biome()  # Gets biome from current_selection
    for terminal in farm.plot_pool.get_active_terminals():
        if terminal.bound_biome and terminal.bound_biome.get_biome_type() == biome.get_biome_type():
            return true  # Button gets highlighted ✓
```

**When executing MEASURE (line 1456):**
```gdscript
func _action_measure(positions: Array[Vector2i]):
    var biome = farm.grid.get_biome_for_plot(current_selection)  # Same source
    var terminal = _find_active_terminal_in_biome(biome)  # But terminal is bound to DIFFERENT biome!
```

### When This Breaks

**Scenario:**
1. Current cursor position: Forest (biome with no active terminals)
2. Checkbox-selected plot: BioticFlux (biome with 1 active terminal)
3. Availability check: "Is there an active terminal in Forest?" NO → Button dims ❌
4. But terminal EXISTS in BioticFlux!

---

## ISSUE 5: Terminal Lookup Uses Biome String Comparison

**Severity:** 🟠 MAJOR
**Category:** Object Identity Bug
**Impact:** Terminals bound to one biome instance may not be found in another instance

### Evidence

**File:** `UI/FarmInputHandler.gd` lines 1582-1584

```gdscript
func _find_measured_terminal_in_biome(biome) -> RefCounted:
    for terminal in farm.plot_pool.get_measured_terminals():
        if terminal.bound_biome and terminal.bound_biome.get_biome_type() == biome.get_biome_type():
            return terminal  # Compares STRING names, not object references!
```

### Why This Is Fragile

- If two biome instances exist with same name but different objects → match still succeeds
- If biome instance is garbage collected and recreated → string name is same but object is different
- No verification that terminal's quantum_computer is same as action's biome's quantum_computer

---

## Summary Table of Issues

| Issue | Severity | Impact | File:Line |
|-------|----------|--------|-----------|
| 1. MEASURE/POP ignore positions parameter | 🔴 CRITICAL | Actions don't work with checkbox selection | 1445, 1486 |
| 2. EXPLORE stays highlighted after all registers bound | 🟠 MAJOR | False indication action will succeed | 3035 |
| 3. Multi-select checkbox selection not propagated | 🔴 CRITICAL | Can't measure/pop from selected plots | 795-797, 1456, 1497 |
| 4. Action availability checks different biome than execution | 🔴 CRITICAL | Button highlighted but action fails | 3072, 1456 |
| 5. Terminal lookup uses string comparison not object identity | 🟠 MAJOR | May fail to find terminals in rare cases | 1582 |

---

## Architecture Issues

### Root Problem: Two Different Selection Systems

1. **Checkbox system:** `plot_grid_display.get_selected_plots()` - used for UI highlighting
2. **Cursor system:** `current_selection` - used for action execution

These are **inconsistently used**:
- EXPLORE ignores checkboxes (OK - explores current biome)
- MEASURE receives checkboxes but ignores them (BUG - searches wrong biome)
- POP receives checkboxes but ignores them (BUG - searches wrong biome)

### Design Confusion

Actions seem split into two paradigms:

**Paradigm A: Single-selection (cursor-based)**
- EXPLORE uses current_selection
- MEASURE uses current_selection
- POP uses current_selection

**Paradigm B: Multi-selection (checkbox-based)**
- receive `positions: Array[Vector2i]` parameter
- but ignore it completely

The checkbox system was added for multi-select support (T/Y/U/I/O/P keys), but MEASURE and POP never adapted to use it.

---

## Recommendations for Investigation

1. **Trace actual keystroke:** When user presses E, does `_action_measure()` get called?
2. **Check plot_grid_display:** Is `get_selected_plots()` returning correct data?
3. **Verify terminal binding:** When EXPLORE binds terminal, does `terminal.bound_biome` reference the right biome object?
4. **Check availability logic refresh:** When is `update_action_availability()` called? Does it update after EXPLORE?

---

**Investigation Status:** Complete - Ready for fixing
**Test Files Created:**
- `Tests/test_register_lifecycle_debug.gd` - Verified core register lifecycle works ✓
- `Tests/test_gameplay_register_reuse.gd` - Verified 3-cycle reuse works ✓
- `Tests/test_multiplot_explore_debug.gd` - Verified multi-plot EXPLORE works ✓
- `Tests/test_biome_reference_identity.gd` - Verified biome references are consistent ✓
- `Tests/test_visualization_signal_flow.gd` - Verified signal connections work ✓
- `Tests/test_visualization_fix.gd` - Created to verify visualization

**Conclusion:** Core quantum and register systems are working correctly. The issue is purely in the action/tooling layer - specifically how MEASURE and POP dispatch actions and check availability.
