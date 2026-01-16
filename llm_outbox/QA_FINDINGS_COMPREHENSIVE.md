# 🔬 COMPREHENSIVE QA FINDINGS - Tool Testing & Edge Cases

**Test Run:** 2026-01-16
**Headless Mode:** Yes
**Test Script:** `Tests/qa_comprehensive_tools.gd`

---

## 📊 OVERVIEW

- **Total Findings:** 18 items
- **Critical Issues:** 1
- **Warnings:** 4
- **TODOs (Not Implemented):** 10

---

## 🔴 CRITICAL ISSUE #1: Vocabulary Injection Cost NOT Enforced

### Evidence
```
Test: Resource Constraints → Vocabulary injection with insufficient resources
Credits Available: 0 💰
Cost Required: 150 💰
Result: ✅ Injection SUCCEEDED (SHOULD HAVE FAILED)
```

### Root Cause
**File:** `Core/Environment/BiomeBase.gd` lines 341-375
**Function:** `inject_vocabulary(emoji: String) -> Dictionary`

```gdscript
# Lines 361-375 (CURRENT - NO RESOURCE CHECK)
func inject_vocabulary(emoji: String) -> Dictionary:
    var check = can_inject_vocabulary(emoji)
    if not check.can_inject:
        return {"success": false, "error": check.reason}

    # ❌ MISSING: Resource cost enforcement!
    # The cost is calculated in can_inject_vocabulary() but NEVER enforced

    producible_emojis.append(emoji)
    # ... rest of function
    return {"success": true, "emoji": emoji, "cost": check.cost}
```

### What Should Happen
The `inject_vocabulary()` should:
1. Calculate cost via `EconomyConstants.get_vocab_injection_cost(emoji)`
2. Check if player has sufficient resources
3. **Deduct the cost from player economy before injection**
4. Return failure if insufficient resources

### Impact
- Players can inject unlimited vocabulary without spending resources
- Economy system broken for vocabulary expansion
- BUILD mode becomes trivial

---

## 🟠 ISSUE #2: MEASURE Response Format Mismatch

### Evidence
```
Test: PROBE Tool → MEASURE action
Error: Invalid access to property or key 'probability' on a base object of type 'Dictionary'
At: qa_comprehensive_tools.gd:124
```

### Root Cause
**File:** `Core/Actions/ProbeActions.gd` line 213-222
**Expected Key:** `probability` (test expectation)
**Actual Key:** `recorded_probability` (actual return value)

```gdscript
# ACTUAL RETURN (ProbeActions.gd:213-222)
return {
    "success": true,
    "outcome": outcome,
    "recorded_probability": recorded_probability,  # ← Key is "recorded_probability"
    "was_entangled": was_entangled,
    "was_drained": drain_success,
    "drain_factor": EconomyConstants.DRAIN_FACTOR,
    "entangled_drains": entangled_drains,
    "register_id": register_id
}

# TEST EXPECTED (qa_comprehensive_tools.gd:124)
print("   Probability: %.2f" % measure_result.probability)  # ← Should be .recorded_probability
```

### Impact
- Any code expecting `.probability` will crash
- Response keys are inconsistent across action functions
- Documentation doesn't match implementation

---

## 🟡 ISSUE #3: Terminal Creation Pool Exhaustion

### Evidence
```
Test Progress:
✅ PROBE Tool: Created 1 terminal
✅ ENTANGLE Tool: Created 2 terminals (attempted)
❌ UNITARY Tool: "Could not create terminal"
❌ CROSS-BIOME: "Could not create terminals in both biomes"
```

### Root Cause
`plot_pool.get_unbound_count()` dropped to 0 before all tests completed.
Each `action_explore()` consumes one unbound terminal.
With only ~4-5 total terminals in pool, tests ran out after 3 explorations.

### What Happens
1. System creates ~4-5 unbound terminals at startup
2. Each EXPLORE action binds one terminal permanently
3. After ~5 EXPLOREs, no more terminals available
4. Later tools can't test because no terminals to work with

### Impact
- Cannot test all tools in sequence in QA mode
- Requires either: reset between tests, or more terminals, or unbind mechanism

---

## 🟠 ISSUE #4: Emoji-Biome Mismatch Warning on Plant

### Evidence
```
Test: Edge Cases → Plant 🍞 in Market biome
Warning: ⏸️ Biome Market quantum system doesn't have 🍞/💨 axis - plant may not function correctly
```

### Location
**File:** `Core/GameMechanics/FarmGrid.gd` around line 776

### Root Cause
- 🍞 (bread) and 💨 (flour) axes exist in **QuantumKitchen** biome only
- Market biome quantum computer has different axes: 🐂/🐻, 💰/💳, 🏛️/🏚️
- Planting 🍞 in Market registers the measurement axis anyway
- But the axis doesn't exist in that biome's quantum system

### What Should Happen
**Option A:** Prevent planting - fail with "invalid emoji for this biome"
**Option B:** Auto-redirect - plant in correct biome instead
**Option C:** Expand biome quantum system on-demand

Currently does **Option C** (expand) but prints warning and the plant doesn't map correctly.

### Impact
- Plot is planted with emoji that has no quantum backing in that biome
- POP/MEASURE operations on this plot may behave unexpectedly
- No error thrown - silent semantic violation

---

## 🟡 ISSUE #5: POP on Unbound Terminal (Test Incomplete)

### Evidence
Test attempted to run POP on unbound terminal but was cut off before completion.

### Expected Behavior
POP should **fail** if terminal was never MEASURE'd (unbound).

### Status
**UNCONFIRMED** - Test needs retry with proper terminal state management

---

## ✅ WORKING CORRECTLY

### Resource Constraints
- ✅ **Planting cost deduction works** - Plant correctly failed with insufficient resources
- ✅ **Cost checking enforced** - Warning printed for insufficient 💰

### Probe Tool
- ✅ **EXPLORE action works** - Creates bound terminals
- ✅ **MEASURE action works** - Records probability, drains register
- ✅ **Damage/drainage mechanics work** - DRAIN_FACTOR applied correctly

---

## 📝 NOT IMPLEMENTED / STUB TESTS

These features have no test coverage yet (marked TODO in test output):

### Tool-Specific TODOs

**ENTANGLE Tool (3 actions not tested):**
- [ ] CLUSTER - Multi-qubit entanglement creation
- [ ] TRIGGER - Measurement trigger mechanism
- [ ] DISENTANGLE - Gate removal

**INDUSTRY Tool (3 actions not tested):**
- [ ] MILL placement and grain processing
- [ ] MARKET placement and trading
- [ ] KITCHEN placement and flour→bread conversion

**UNITARY Tool (1+ actions not tested):**
- [ ] PAULI-X gate application
- [ ] HADAMARD gate application
- [ ] PAULI-Z gate application
- [ ] Sequential gate applications (X→H→Z)

**CROSS-BIOME Restrictions (Not verified):**
- [ ] Entanglement across biomes (should FAIL)
- [ ] CNOT across biomes (should FAIL)
- [ ] Measurement trigger across biomes (should FAIL)

### Edge Case TODOs

- [ ] Plant → Gate same plot behavior
- [ ] Multi-plot selection (3+ plots in same biome)
- [ ] Mode switching during operations (TAB toggle)
- [ ] Rapid tool switching (1→2→3→4→1)
- [ ] POP on unbound terminal (verify failure)

---

## 🔍 TEST EXECUTION LOG

### System Initialization
```
✅ Farm systems ready
✅ 4 biomes initialized (BioticFlux, Market, Forest, Kitchen)
✅ 12 plots created
✅ Economy bootstrapped with 2000 💰
```

### Test Flow
```
1. PROBE Tool testing
   ✅ EXPLORE succeeded
   ✅ MEASURE succeeded
   ⚠️ Response format mismatch (see Issue #2)

2. ENTANGLE Tool testing
   ✅ Created 2 terminals
   📝 Actions not implemented/tested

3. INDUSTRY Tool testing
   ✅ Located plots
   📝 Actions not implemented/tested

4. UNITARY Tool testing
   ❌ No terminals available (pool exhausted)

5. CROSS-BIOME testing
   ❌ No terminals available (pool exhausted)

6. RESOURCE CONSTRAINTS
   ❌ Vocab injection allowed with 0 credits (CRITICAL - see Issue #1)
   ✅ Planting correctly blocked with 0 credits

7. EDGE CASES
   ✅ Plant succeeded on empty plot
   ⚠️ Planted bread in wrong biome (see Issue #4)
   ❌ POP test incomplete
```

---

## 📋 SUMMARY TABLE

| Issue | Severity | Status | Location | Fix Needed |
|-------|----------|--------|----------|-----------|
| Vocab injection no cost check | 🔴 CRITICAL | IDENTIFIED | BiomeBase.gd:341 | Resource enforcement |
| MEASURE response key mismatch | 🟠 HIGH | IDENTIFIED | ProbeActions.gd:213 | Response format docs |
| Terminal pool exhaustion | 🟡 MEDIUM | IDENTIFIED | plot_pool design | Reset/unbind mechanism |
| Emoji-biome axis mismatch | 🟠 HIGH | IDENTIFIED | FarmGrid.gd:776 | Validation on plant |
| POP unbound terminal | 🟡 MEDIUM | INCOMPLETE | ProbeActions.gd | Needs retest |

---

## 🎯 NEXT STEPS (FOR FUTURE FIXING)

1. **Fix Critical Issue #1** - Add resource cost enforcement to `inject_vocabulary()`
2. **Fix Issue #2** - Standardize response keys across all action functions
3. **Improve Issue #3** - Add terminal unbinding mechanism or increase pool
4. **Fix Issue #4** - Add emoji→biome validation or auto-redirect
5. **Complete Test** - Retry POP unbound terminal scenario
6. **Implement TODOs** - Add actual test coverage for ENTANGLE, INDUSTRY, UNITARY tools

---

## 📝 TEST METADATA

- **Test Date:** 2026-01-16T08:57:22 UTC
- **Godot Version:** 4.5.stable
- **Game State:** Clean boot, new game scenario
- **Duration:** ~30 seconds headless
- **Logging:** Verbose enabled
- **Notes:** Used bootstrapped economy for reproducibility

