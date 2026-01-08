# 🍳 Kitchen Architecture Review Package

**Complete investigation into the kitchen gameplay loop, systems, and design decisions needed**

---

## What's In This Package

### 📋 Documents (Read in Order)

1. **00_INVESTIGATION_OVERVIEW.md** ← START HERE
   - What this package is and why
   - High-level findings
   - How to navigate

2. **01_GAMEPLAY_LOOP_SPECIFICATION.md**
   - What the kitchen teaches
   - 7 steps of gameplay
   - Learning arc
   - Smoke test verification

3. **02_SYSTEMS_ANALYSIS.md**
   - How wheat/mill work (code-level)
   - How energy taps work
   - How kitchen works
   - Cross-system interactions
   - Current issues mapped to code

4. **05_DESIGN_DECISION_FRAMEWORK.md** ← MOST IMPORTANT
   - Three critical decisions you must make
   - Decision A: Mill measurement semantics
   - Decision B: Energy tap architecture
   - Decision C: Cross-biome resource access
   - Trade-offs for each option
   - Recommendations

5. **06_SIMULATION_EVIDENCE.md**
   - Automated test results
   - What works, what's broken
   - Code excerpts showing issues
   - Quantitative data

### 🔍 Supplementary Documents (In Preparation)

- **03_QUANTUM_MECHANICS_REQUIREMENTS.md** - What's "real" quantum vs. toy
- **04_UI_FLOW_DOCUMENTATION.md** - Keyboard controls and UX
- **07_OPEN_SOLUTION_SPACE.md** - Coherent architectural approaches

---

## Quick Navigation

### For Decision Makers
1. Read: **00_INVESTIGATION_OVERVIEW.md** (10 min)
2. Skim: **01_GAMEPLAY_LOOP_SPECIFICATION.md** (15 min)
3. Review: **05_DESIGN_DECISION_FRAMEWORK.md** (30 min)
4. Make choices on A, B, C

### For Implementers
1. Start: **05_DESIGN_DECISION_FRAMEWORK.md** (understand choices)
2. Reference: **02_SYSTEMS_ANALYSIS.md** (code structure)
3. Build to: **06_SIMULATION_EVIDENCE.md** (test procedures)

### For Quantum Mechanics Review
1. Focus: **03_QUANTUM_MECHANICS_REQUIREMENTS.md**
2. Verify: **06_SIMULATION_EVIDENCE.md** (current state)
3. Decide: **05_DESIGN_DECISION_FRAMEWORK.md** (rigor level)

---

## Current State Summary

### ✅ What Works
- Wheat planting and quantum registers
- Mill measurement and flour production
- Wheat harvest measurement
- Kitchen Bell state creation
- Kitchen measurement and bread production
- Keyboard controls (partial)

### ❌ What's Broken
- Wheat not consumed after mill measurement (can measure infinitely)
- Energy tap placement fails (fire emoji missing from BioticFlux)
- Can't complete full keyboard pipeline

### ⚠️ What's Ambiguous
- Mill physics (destructive? non-destructive? renewable?)
- Energy tap architecture (plot-level? biome-level?)
- Cross-biome resource access (kitchen isolation? global bath?)

---

## The Three Critical Decisions

### Decision A: Mill Measurement
```
What should happen to wheat after mill measures it?

Options:
  A1: Destructive (mill consumes wheat)
  A2: Non-destructive + outcome locking
  A3: Renewable (intentional - can measure infinitely)

Recommended: A2 (best learning potential)
Your choice: ?
```

### Decision B: Energy Tap Architecture
```
How do energy taps fit in the game?

Options:
  B1: Plot-level structures (like buildings)
  B2: Biome-level quantum operations
  B3: Auto-injected emoji reservoir

Recommended: B2 (matches Model B, proper quantum)
Your choice: ?
```

### Decision C: Cross-Biome Resource Access
```
How does kitchen access fire/water from other biomes?

Options:
  C1: Kitchen biome only (isolated)
  C2: Kitchen cross-biome aware (queries multiple baths)
  C3: Unified global quantum computer

Recommended: C2 (good balance of learning + coherence)
Your choice: ?
```

---

## How to Use This Package

### Phase 1: Review (2-3 hours)
- [ ] Read 00_INVESTIGATION_OVERVIEW.md
- [ ] Read 01_GAMEPLAY_LOOP_SPECIFICATION.md
- [ ] Read 02_SYSTEMS_ANALYSIS.md
- [ ] Review 05_DESIGN_DECISION_FRAMEWORK.md
- [ ] Skim 06_SIMULATION_EVIDENCE.md

### Phase 2: Decide (30-60 min)
- [ ] Choose: Option A1, A2, or A3?
- [ ] Choose: Option B1, B2, or B3?
- [ ] Choose: Option C1, C2, or C3?
- [ ] Document rationale for choices

### Phase 3: Plan Implementation (1-2 hours)
- [ ] Map decisions to code changes
- [ ] Identify new sub-issues
- [ ] Create implementation sequence
- [ ] Estimate effort

### Phase 4: Implement (TBD)
- [ ] Build according to decisions
- [ ] Test against smoke tests
- [ ] Verify quantum rigor

---

## Key Findings

### Finding 1: Mill Doesn't Consume Wheat
```
Current: Mill measures wheat every frame
Result: Wheat produces flour 5× in 5 seconds

Expected:
  Option A1: Wheat consumed on first measure
  Option A2: Wheat locked after measurement
  Option A3: This is intentional (acknowledged)
```

**Code Location**: `Core/GameMechanics/QuantumMill.gd:100-110`

### Finding 2: Energy Taps Have Layer Mismatch
```
UI Layer: "Select plots" (requires is_planted)
Physics Layer: "Create Lindblad drain" (operates on bath)

Result: Fire emoji doesn't exist in BioticFlux bath
        Tap placement silently fails
        User sees "nothing happened"
```

**Code Location**:
- `UI/FarmInputHandler.gd:1388`
- `Core/Environment/BiomeBase.gd:716`

### Finding 3: Cross-Biome Resource Query Not Defined
```
Kitchen needs:
  🔥 from Kitchen bath
  💧 from Forest bath
  💨 from Mill/Market

Current: No mechanism to query across biome boundaries
```

---

## Test Evidence

### How to Run Automated Tests

```bash
cd /home/tehcr33d/ws/SpaceWheat

# Full physics investigation
timeout 20 godot --headless -s /tmp/test_physics_issues.gd

# Kitchen-only (works separately)
timeout 15 godot --headless -s /tmp/test_keyboard_kitchen_pipeline.gd
```

### Test Output Highlights

```
Wheat measurement test:
  BEFORE: is_planted=true, purity=1.0
  AFTER:  is_planted=TRUE (SHOULD BE FALSE), purity=1.0
  Conclusion: Wheat not consumed ✗

Energy tap test:
  Error: "Target icon 🔥 not found in biome BioticFlux"
  Conclusion: Emoji missing, tap placement fails ✗

Kitchen test (separate):
  Input: fire+water+flour
  Output: bread ✓
  Conclusion: Kitchen works when given inputs ✓
```

---

## Principle: Don't Restrict Design

This investigation is meant to:
- **Open** the design space, not close it
- **Clarify** the options, not prescribe them
- **Enable** informed decisions, not dictate them

We're not saying "here's how to fix it."
We're saying "here's what needs to work, and here are the coherent approaches."

You pick which approach makes sense for your game.

---

## Next Steps

1. **Review** this package (2-3 hours)
2. **Make decisions** on A, B, C
3. **Return** with your choices
4. **We implement** according to your decisions
5. **Test** full kitchen pipeline end-to-end

---

## File Locations

```
/home/tehcr33d/llm_outbox/kitchen_architecture_review/
├── README.md (this file)
├── 00_INVESTIGATION_OVERVIEW.md
├── 01_GAMEPLAY_LOOP_SPECIFICATION.md
├── 02_SYSTEMS_ANALYSIS.md
├── 05_DESIGN_DECISION_FRAMEWORK.md
├── 06_SIMULATION_EVIDENCE.md
└── (supplementary docs in prep)

Test files:
├── /tmp/test_physics_issues.gd
└── /tmp/test_keyboard_kitchen_pipeline.gd
```

---

## Questions?

Each document is self-contained but builds on the others. Start with `00_INVESTIGATION_OVERVIEW.md` and follow the links.

---

**Status**: Ready for architecture review and decision-making
**Last Updated**: 2026-01-05
**Investigation Duration**: Complete
**Implementation Status**: Blocked awaiting decisions
