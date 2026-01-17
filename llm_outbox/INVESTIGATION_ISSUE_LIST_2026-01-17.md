# Investigation Issue List
**Date:** 2026-01-17
**From:** Comprehensive Testing Rounds 1-3
**Priority:** Listed by severity

---

## 🔴 CRITICAL ISSUES (Crash / Game-Breaking)

### CRITICAL #1: ProbeActions.action_measure() - Null Terminal Crash
- **File:** `Core/Actions/ProbeActions.gd:150`
- **Function:** `action_measure(terminal, biome)`
- **Issue:** No null check before calling `terminal.can_measure()`
- **Current Code:**
  ```gdscript
  if not terminal.can_measure():  # ← CRASHES if terminal is null
  ```
- **Impact:**
  - Any call to `action_measure(null, biome)` crashes with: "Nonexistent function 'can_measure' in base 'Nil'"
  - Could happen if UI layer passes null in edge cases
  - No graceful error handling
- **Test Evidence:**
  ```
  Code: ProbeActions.action_measure(null, biome)
  Result: SCRIPT ERROR - Invalid call. Nonexistent function 'can_measure' in base 'Nil'
  ```
- **Fix:** Add null check before any terminal access:
  ```gdscript
  if not terminal:
      return {success: false, message: "No terminal to measure"}
  if not terminal.can_measure():
      # existing code...
  ```

---

### CRITICAL #2: ProbeActions.action_pop() - Null Terminal Crash
- **File:** `Core/Actions/ProbeActions.gd` (around line 284+)
- **Function:** `action_pop(terminal, plot_pool, economy)`
- **Issue:** No null check before terminal state access
- **Impact:** Same as CRITICAL #1 but for POP action
- **Likely Location:** First line accessing terminal property without validation
- **Fix:** Add null check at function start:
  ```gdscript
  if not terminal:
      return {success: false, message: "No terminal to harvest"}
  ```

---

## ⚠️ HIGH PRIORITY (Robustness Issues)

### HIGH #1: Missing Terminal State Validation in action_measure()
- **File:** `Core/Actions/ProbeActions.gd:150-167`
- **Issue:** `can_measure()` method doesn't exist or is incomplete
- **Current Code:** Calls `terminal.can_measure()` which might not be a real method
- **Impact:**
  - Unclear what validation is actually happening
  - Method might not properly check all required conditions
- **Requirements:**
  - Terminal must be bound (is_bound == true)
  - Terminal must not be measured (is_measured == false)
  - Terminal must have valid bound_register_id
- **Status:** Need to verify if `can_measure()` is properly implemented in Terminal.gd

---

### HIGH #2: Missing Terminal State Validation in action_pop()
- **File:** `Core/Actions/ProbeActions.gd` (around line 284+)
- **Issue:** No validation that terminal is in measured state
- **Requirements:**
  - Terminal must be bound (is_bound == true)
  - Terminal MUST be measured (is_measured == true)
  - Terminal must have valid bound_register_id
  - Terminal must have recorded_probability set
- **Missing Checks:**
  - If `terminal.is_measured == false`, should fail immediately
  - If `terminal.recorded_probability` not set, should fail

---

### HIGH #3: Terminal State Transitions Not Fully Validated
- **File:** `Core/GameMechanics/Terminal.gd`
- **Issue:** No state machine preventing invalid transitions
- **Current State:** Terminal has properties `is_bound` and `is_measured` but no validation of valid state combinations
- **Possible Invalid States:**
  - `is_measured=true` but `is_bound=false` (should be impossible)
  - `is_measured=true` but `bound_register_id=null` (should be impossible)
  - Multiple simultaneous attempts to bind same terminal
- **Recommendation:** Implement proper state machine or validation in Terminal class

---

## ⚠️ MEDIUM PRIORITY (Feature/UI Issues)

### MEDIUM #1: UI Button Availability Flicker After Action
- **File:** `UI/FarmInputHandler.gd` (recently fixed)
- **Issue:** After EXPLORE/MEASURE, action buttons might show incorrect state briefly
- **Status:** Partially addressed with `action_performed` signal connection
- **Remaining Issue:** May need to throttle refresh if actions fire rapidly
- **Test:** Run multiple fast actions in succession

---

### MEDIUM #2: Availability Check Timing with Multi-Select
- **File:** `UI/FarmInputHandler.gd` (lines 3060-3103)
- **Issue:** After fixes, availability checks might not refresh immediately with checkbox selections
- **Current Status:** Fixed to use selected_plots parameter
- **Remaining Test:** Verify checkbox selection → button state → action execution flow works end-to-end
- **Test Case:**
  1. Select plots with T/Y/U/I/O/P
  2. Check button highlighting
  3. Execute action
  4. Verify correct biome was targeted

---

## ℹ️ LOW PRIORITY (Enhancements / Clarifications)

### LOW #1: Improve Error Messages
- **File:** `Core/Actions/ProbeActions.gd` (all action functions)
- **Issue:** Some error messages unclear or missing context
- **Examples:**
  - "No unbound registers available in this biome" - good
  - "Not bound" - could be "Use EXPLORE to bind a terminal first"
  - Missing: "Terminal pool exhausted across all plots"

---

### LOW #2: Add Logging for Action Sequences
- **File:** `Core/Actions/ProbeActions.gd`
- **Issue:** No debug logging of action sequence state transitions
- **Would Help With:**
  - Diagnosing action failures
  - Understanding why buttons are disabled
  - Tracking register allocation
- **Recommendation:** Add verbose logging calls at key points

---

### LOW #3: Document Terminal State Machine
- **File:** `Core/GameMechanics/Terminal.gd`
- **Issue:** State transitions not documented
- **Valid States:**
  - Unbound: `is_bound=false, is_measured=false`
  - Bound: `is_bound=true, is_measured=false` (EXPLORE)
  - Measured: `is_bound=true, is_measured=true` (MEASURE)
  - Released: `is_bound=false, is_measured=false` (POP)
- **Missing:** Official state diagram and transition rules

---

## Testing Evidence

### Round 1: Basic Cycle ✅
```
✅ EXPLORE → Terminal T_00 bound to Register 1
✅ MEASURE → Terminal marked measured, outcome: 💰 (p=1.0)
✅ POP → Register 1 released, terminal unbound
✅ 4 complete cycles executed successfully
```

### Round 2: Advanced Scenarios ⚠️
```
⚠️ Terminal exhaustion: Only 3 out of 12 could be bound to Market biome (CORRECT - Market has 3 registers)
🔴 MEASURE(null) → CRASH - Missing null check
❌ POP without MEASURE → Not executed due to earlier crash
```

### Round 3: Cross-Biome ❌
```
❌ Test infrastructure issue (FarmGrid.width not available)
⚠️ Indicates need for better cross-biome testing setup
```

---

## Fixed Issues (From Previous Sessions)

✅ **Issue #1 (Fixed):** MEASURE/POP now use positions parameter instead of current_selection
- **Files Modified:** `UI/FarmInputHandler.gd:1456, 1498, 1476, 1517`
- **Status:** VERIFIED working in tests

✅ **Issue #2 (Fixed):** Availability checks now use selected_plots and object identity
- **Files Modified:** `UI/FarmInputHandler.gd:3060-3103`
- **Status:** VERIFIED working in tests

✅ **Issue #3 (Fixed):** Action button availability refreshes after action performed
- **File Modified:** `UI/PlayerShell.gd:503-510`
- **Status:** VERIFIED working in tests

---

## Summary Table

| ID | Category | Severity | Component | Status |
|:---|:---------|:---------|:----------|:-------|
| C1 | Crash | 🔴 CRITICAL | ProbeActions | ❌ UNFIXED |
| C2 | Crash | 🔴 CRITICAL | ProbeActions | ❌ UNFIXED |
| H1 | Validation | ⚠️ HIGH | ProbeActions | ❓ UNCLEAR |
| H2 | Validation | ⚠️ HIGH | ProbeActions | ❌ UNFIXED |
| H3 | State Machine | ⚠️ HIGH | Terminal | ❌ UNFIXED |
| M1 | UI Timing | ⚠️ MEDIUM | FarmInputHandler | ⚠️ PARTIAL |
| M2 | UI Timing | ⚠️ MEDIUM | FarmInputHandler | ⚠️ PARTIAL |
| L1 | UX | ℹ️ LOW | ProbeActions | 📋 ENHANCEMENT |
| L2 | Debug | ℹ️ LOW | ProbeActions | 📋 ENHANCEMENT |
| L3 | Docs | ℹ️ LOW | Terminal | 📋 ENHANCEMENT |

---

## Recommended Fix Order

1. **C1 - action_measure null check** (5 min)
2. **C2 - action_pop null check** (5 min)
3. **H2 - Terminal state validation in pop** (15 min)
4. **H3 - State machine for Terminal** (30 min)
5. **M1-M2 - UI refresh timing** (20 min - depends on testing)
6. **H1 - Investigate can_measure() implementation** (10 min)
7. **L1-L3 - Enhancements** (As time permits)

---

## Test Coverage Needed

### Before Deployment:
- [ ] Test null terminal handling in all ProbeActions methods
- [ ] Test invalid state transitions in Terminal class
- [ ] Test multi-plot action execution with checkbox selection
- [ ] Test action button state after rapid-fire actions
- [ ] Test cross-biome register isolation

### Tools Not Yet Tested:
- [ ] Tool 2: QUANTUM (CLUSTER, MEASURE_TRIGGER, REMOVE_GATES)
- [ ] Tool 3: INDUSTRY (PLACE_MILL, PLACE_MARKET, PLACE_KITCHEN)
- [ ] Tool 4: GATES (APPLY_PAULI_X, APPLY_HADAMARD, APPLY_PAULI_Z)

---

## Notes

- **Core Logic Status:** ✅ Register lifecycle, terminal binding, and probability calculations working correctly
- **UI Integration Status:** ⚠️ Action dispatch and button highlighting mostly fixed, but null-check crashes need immediate attention
- **Testing Infrastructure:** Some API knowledge gaps (FarmGrid dimensions) but overall testing methodology sound
- **Code Quality:** Most code is well-structured; issues are mostly missing validation rather than logic errors

