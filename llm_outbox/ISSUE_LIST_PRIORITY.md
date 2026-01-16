# 🎯 Issue Priority List - Actionable Fixes

## 🔴 P1: CRITICAL - Fix Immediately

### Issue #1: POP Action Bug - Credits Added to Wrong Resource
**File:** `Core/Actions/ProbeActions.gd`
**Lines:** 344-349
**Fix Time:** 15 min
**Severity:** CRITICAL - Breaks economy progression

**Problem:**
```gdscript
# BROKEN CODE (line 349):
economy.add_resource(resource, int(credits))  # Adds to measured emoji, not 💰!
```

**Fix:**
```gdscript
# CORRECT:
if economy:
    economy.add_resource("💰", int(credits), "pop_%s" % resource)
```

**Test Evidence:**
```
Before: 💰=10, 🌾=10
After:  💰=10 (❌ expected 20), 🌾=20 (should stay 10)
```

**Impact:** Players never gain credits from POP actions.

---

### Issue #2: can_inject_vocabulary Incomplete - Doesn't Check Resources
**File:** `Core/Environment/BiomeBase.gd`
**Lines:** 315-338
**Fix Time:** 10 min
**Severity:** CRITICAL - Returns misleading contract

**Problem:**
```gdscript
# INCOMPLETE (line 338):
return {"can_inject": true, "reason": "", "cost": cost}  # Missing resource check!
```

Method returns true even with 0 credits, contradicting calling code expectations.

**Fix:**
Add resource validation before returning true:
```gdscript
var cost = EconomyConstants.get_vocab_injection_cost(emoji)
var cost_credits = cost.get("💰", 0)

# NEW: Check resource availability
if grid and grid.farm_economy:
    var current_credits = grid.farm_economy.get_resource("💰")
    if current_credits < cost_credits:
        return {
            "can_inject": false,
            "reason": "Need %d 💰-credits but only have %d" % [cost_credits, current_credits],
            "cost": cost
        }

return {"can_inject": true, "reason": "", "cost": cost}
```

**Test Evidence:**
```
can_inject(emoji) with 0 credits → returns true (❌ should be false)
inject_vocabulary(emoji) with 0 credits → returns false ✓ (works correctly)
```

**Impact:** UI thinks operation is possible when it fails.

---

## 🟡 P2: MEDIUM - Investigate & Document

### Issue #3: Terminal Pool Capacity Unclear
**File:** `Core/GameMechanics/PlotPool.gd`
**Severity:** MEDIUM - Blocks multi-terminal testing

**Problem:** Cannot simultaneously bind terminals in multiple biomes
- Creates in biome A ✓
- Creates in biome B ✗ (capacity issue?)

**Investigation Needed:**
- Check PlotPool.get_unbound_count()
- Review allocation per-biome vs global
- Is this intentional (1 terminal/biome) or bug?

**Impact:** Cross-biome tests blocked, complex scenarios untestable.

---

## ℹ️ P3: INFORMATIONAL - Design Notes

### Design: BUILD Mode Required for All Planting
**File:** `Core/GameMechanics/FarmGrid.gd`
**Lines:** 736-737
**Status:** INTENTIONAL - Not a bug

Planting always requires BUILD mode, even if emoji axis already exists in biome. This is by design (quantum expansion system requirement).

**Implication:** Document in user help that planting = setup phase only.

---

## 📋 Feature Gaps (Not Bugs)

These systems are not yet implemented - assign to feature work:

- **Entanglement Tool (Tool 2):** CLUSTER, TRIGGER, DISENTANGLE
- **Industry Tools (Tool 3):** MILL, MARKET, KITCHEN
- **Unitary Gates (Tool 4):** PAULI-X, HADAMARD, PAULI-Z
- **Cross-Biome Validation:** Blocking operations between biomes

---

## 🧪 Test Evidence Location

See detailed findings in:
```
/llm_outbox/COMPREHENSIVE_QA_FINDINGS.md
```

Test scripts created:
- `Tests/round2_resource_and_cross_biome.gd` - Resource validation tests
- `Tests/round3_economy_system.gd` - Economy system deep dive

---

## Quick Reference: Metrics

| Category | Count | Status |
|----------|-------|--------|
| Critical Bugs | 2 | Found & Documented |
| Medium Issues | 1 | Found & Documented |
| Design Notes | 1 | Documented |
| Unimplemented Features | 4+ | Listed |
| Working Systems | 6+ | Confirmed ✅ |

---

## Estimated Fix Effort

- **P1 Fixes:** 25 min (2 bugs)
- **P2 Investigation:** 30 min
- **P3 Documentation:** 15 min
- **Total:** ~1 hour for critical items

---

## Next Steps

1. **Fix P1 issues** (15 min each)
2. **Test POP fix** with Round 3 script
3. **Test can_inject fix** with Round 2 script
4. **Investigate P2** as needed
5. **Plan feature implementation** for Tool 2/3/4
