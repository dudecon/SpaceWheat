# 🐛 Issue List - January 16, 2026

**Generated From:** Comprehensive investigation of Tools 1-4 and economic system
**Test Status:** 3 test suites run, 22/22 core tests passed
**Date:** 2026-01-16

---

## CRITICAL ISSUES (🔴 Blocking)

**NONE** - No critical bugs found!

---

## MAJOR ISSUES (🟠 High Priority)

### MAJOR-1: Limited Quantum Register Capacity Per Biome

**Status:** 🔴 ISSUE CONFIRMED
**Priority:** HIGH
**Category:** Resource Constraint
**Affects:** All biomes, Player progression

**Description:**
Each biome has only 3-5 quantum registers. Once all registers are BOUND (by EXPLORE action), no more EXPLORE is possible until a terminal completes MEASURE→POP and releases the register.

**Example Problem:**
```
BioticFlux has 3 registers [0, 1, 2]
Player EXPLORE 3 times → All registers bound
Player wants to EXPLORE again → ❌ FAILS with "no_registers"
Player must POP a terminal first to free a register
```

**Impact:**
- Limits parallel exploration (max 3-5 simultaneous active probes)
- Forces mandatory lifecycle completion (can't freely explore)
- Players hit "no_registers" error as expected gameplay

**Questions:**
- Is this **intentional balance mechanism**?
- Should players expect this constraint?
- Can vocabulary injection add new registers?

**Evidence:**
- File: Tests/test_round_1_probe_lifecycle.gd (TEST 2)
- Results: After 3 EXPLOREs in 3-qubit biome, 4th fails as expected

**Workaround:**
- Use multiple biomes (12 registers total across 4 biomes)
- Complete EXPLORE→MEASURE→POP before exploring again
- Cross-biome workflow distributes load

---

### MAJOR-2: Tool 2 (ENTANGLE) and Tool 3 (INDUSTRY) Functional Testing Incomplete

**Status:** ⚠️ INVESTIGATION DEFERRED
**Priority:** HIGH
**Category:** Missing Verification
**Affects:** These tools' reliability unknown

**Description:**
Tools 2 and 3 are configured and available, but **actual functional behavior has not been tested**. Previous session fixed wiring, but end-to-end testing blocked by:
- Game startup takes 45+ seconds
- Complex setup requirements (multiple bound terminals)
- Test infrastructure overhead

**What We Know:**
- ✅ Tool 2 config exists (cluster, measure_trigger, remove_gates)
- ✅ Tool 3 config exists (place_mill, place_market, place_kitchen)
- ✅ FarmInputHandler action routing verified present
- ❌ Actual game behavior untested

**What We Don't Know:**
- Do cluster actions work correctly?
- Does measure_trigger properly create infrastructure?
- Does remove_gates successfully disentangle?
- Do industry buildings get placed?
- Do buildings function after placement?

**Evidence:**
- File: Tests/test_round_2345_tools_quick.gd (never completed)
- Reason: Game startup timeout at 60 seconds

**Next Steps:**
1. Optimize test infrastructure (< 5 second startup)
2. Create dedicated Tools 2 & 3 test suite
3. Verify both tools work end-to-end

---

### MAJOR-3: Game Startup Performance Blocks Testing

**Status:** ⚠️ INFRASTRUCTURE ISSUE
**Priority:** MEDIUM
**Category:** Development Efficiency
**Affects:** Test iteration speed, debugging

**Description:**
Full game initialization takes 30-45 seconds, making rapid testing/iteration impossible.

**Breakdown:**
- Godot startup: ~5s
- Scene loading: ~5s
- Boot manager: ~10s
- Quantum operator generation: ~10-15s (Forest has 5 qubits)
- UI initialization: ~5-10s

**Impact:**
- Each test run = 45+ second wait
- Impossible to do rapid debug-test cycles
- Limits scope of what can be tested

**Recommendation:**
- Create **minimal test bootloader** (1 biome, headless)
- Skip quantum operator regeneration (cache)
- Bypass UI initialization
- Target: < 5 second startup

---

## MINOR ISSUES (🟡 Lower Priority)

### MINOR-1: Test Output Bug (Not a Game Bug)

**File:** Tests/test_unitary_gates.gd:281
**Severity:** LOW
**Issue:** Probability calculations show 133% instead of correct percentages

This is a **test harness bug**, not a game bug. Division by wrong denominator.

---

### MINOR-2: Outcome Distribution Bias Worth Investigating

**Observation:** In 10 EXPLORE→MEASURE cycles:
- ☀ appeared 40% (expected ~33%)
- 🍂 appeared 40% (expected ~33%)
- 🌾 appeared 20% (expected ~33%)

**Hypothesis:** Weighted register selection (squared probability weighting) might bias outcomes.

**Severity:** LOW (possible design choice, not necessarily a bug)

---

### MINOR-3: No Error Case Testing

**Coverage Gap:** These error conditions NOT tested:
- MEASURE on unbound terminal
- POP without MEASURE
- Gate application to non-existent register
- Cross-biome entanglement rejection

**Status:** Testing blocked by infrastructure limitations

---

## VERIFIED WORKING (✅ GREEN)

These systems passed all tests:

### Tool 1: PROBE (🔍)
- ✅ EXPLORE action (terminal/register allocation)
- ✅ MEASURE action (probability drain, outcome sampling)
- ✅ POP action (credit conversion P×10)
- ✅ Terminal reuse (proper lifecycle)
- ✅ Register reuse (released after POP)
- ✅ Cross-biome independence
- ✅ Probabilistic outcomes

**Test Status:** 11/11 PASSED ✅

### Tool 4: UNITARY (⚡)
- ✅ All 13 gates available
- ✅ Pauli-X gate (state flip)
- ✅ Hadamard gate (superposition)
- ✅ Other rotation gates
- ✅ Physics transformations correct

**Test Status:** 11/11 PASSED ✅

### Economy System (💰)
- ✅ add_resource() works
- ✅ spend_resource() works
- ✅ Custom resources functional
- ✅ Credit tracking accurate

**Test Status:** All ops functional ✅

---

## ACTION ITEMS

### Immediate (Next Session)
- [ ] Clarify register capacity design intent
- [ ] Answer: Is 3-5 limit a feature or limitation?

### Short-term (1-2 weeks)
- [ ] Optimize test infrastructure (< 5s startup)
- [ ] Create Tools 2 & 3 functional tests
- [ ] Test error conditions & edge cases

### Longer-term (Future)
- [ ] Stress test with many simultaneous terminals
- [ ] Test vocabulary injection side-effects
- [ ] Test qubit expansion mechanisms
- [ ] Multi-biome interaction scenarios

---

## Summary Stats

| Category | Count | Status |
|----------|-------|--------|
| Critical Issues | 0 | ✅ None |
| Major Issues | 3 | 🔴 Needs decision |
| Minor Issues | 3 | 🟡 Noted |
| Verified Working Systems | 3 | ✅ All green |
| Tests Passed | 22 | ✅ 100% pass rate |
| Tests Deferred | 2+ | ⏳ Infrastructure |

---

**For detailed findings, see:** COMPREHENSIVE_TEST_RESULTS_2026-01-16.md
