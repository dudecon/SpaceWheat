# 🔍 Test Round 1: Tool 1 (PROBE) Findings

**Date:** 2026-01-16
**Test:** test_round_1_probe_actions.gd
**Results:** 6/11 tests passed

---

## Key Discovery: Register Binding & Resource Depletion

### The Problem
- Each biome has a **LIMITED number of quantum registers** (3-5 qubits)
- `EXPLORE` allocates a register and **binds it to a Terminal**
- **Registers remain bound until the Terminal is POPped**
- Once all registers are bound, `EXPLORE` fails with no available registers

### Evidence
- BioticFlux biome initialization shows: 3 qubits → 3 available registers
- Test 1: EXPLORE allocates register 2 ✅
- Test 2: EXPLORE allocates registers 0, 1 ✅ (3rd EXPLORE fails - all bound)
- Tests 3-6: Fail because no unbound registers remaining

### Example Flow
```
State: 3 qubits = 3 registers

EXPLORE (TEST 1):
  - Allocates register 2, binds to Terminal T_00
  - State: [free, free, BOUND]

EXPLORE (TEST 2):
  - Allocates register 0, binds to Terminal T_01
  - Allocates register 1, binds to Terminal T_02
  - State: [BOUND, BOUND, BOUND]

EXPLORE (TEST 2, 3rd):
  - ALL REGISTERS BOUND → FAILS with "no_registers"
```

### Critical Insight
**The game requires COMPLETE TERMINAL LIFECYCLE for register reuse:**
```
EXPLORE → MEASURE → POP (releases register)
```

Only the POP action releases the register back to the pool via:
```gdscript
# ProbeActions.action_pop() line 350-351
if biome.has_method("mark_register_unbound"):
    biome.mark_register_unbound(register_id)
```

---

## Issues Found

### ISSUE-1: Limited Parallel Terminals
**Severity:** HIGH
**Category:** Resource Constraint

Each biome has only 3-5 registers, severely limiting parallel EXPLORE actions.

**Example:**
- BioticFlux: 3 registers → max 3 simultaneous bound terminals
- Forest: 5 registers → max 5 simultaneous bound terminals

This means players can't explore freely - they must complete EXPLORE→MEASURE→POP before exploring again.

**Workaround:** Use multiple biomes (BioticFlux=3, Market=3, Forest=5, Kitchen=3)

---

### ISSUE-2: Test Resource Exhaustion
**Severity:** MEDIUM
**Category:** Test Design

Sequential tests that don't release terminals cause later tests to fail.

**Evidence:**
- Test 1: Uses register 2 (not released)
- Test 2: Uses registers 0, 1 (not released)
- Tests 3-6: Fail because no unbound registers exist

**Solution:** Each test should either:
1. Use a different biome, OR
2. Complete full EXPLORE→MEASURE→POP sequence to release registers

---

## Test Results Summary

| Test | Pass | Notes |
|------|------|-------|
| TEST 1: EXPLORE Basic | ✅ 5/5 | Successful exploration and allocation |
| TEST 2: EXPLORE Multiple | ✅ 3/4 | Allocated 2 registers, 3rd failed (expected) |
| TEST 3: MEASURE Drain | ❌ 0/4 | EXPLORE failed (no free registers) |
| TEST 4: POP Conversion | ❌ 0/4 | EXPLORE failed (no free registers) |
| TEST 5: Sequence | ❌ 0/1 | EXPLORE failed (no free registers) |
| TEST 6: Cross-Biome | ❌ 0/1 | EXPLORE failed (no free registers) |

**Total: 6/11 passed (55%)**

---

## Recommendations

### For Next Test Round
Rewrite tests to either:
1. Complete full lifecycle per test (EXPLORE→MEASURE→POP), OR
2. Use separate biomes for each test, OR
3. Refactor into isolated test scenarios that reset registers

### For Game Design
Consider:
- Whether 3-5 terminals per biome is intentional game balance
- UI/UX implications (players must complete lifecycle before exploring again)
- Vocabulary injection system (allows new registers? See Tool 2-3)

---

## Test File Location
`/home/tehcr33d/ws/SpaceWheat/Tests/test_round_1_probe_actions.gd`
