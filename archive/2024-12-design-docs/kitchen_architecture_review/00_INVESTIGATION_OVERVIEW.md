# 🍳 Kitchen Gameplay Loop - Architecture Review Package

**Status**: ⚠️ COMPREHENSIVE INVESTIGATION COMPLETE
**Date**: 2026-01-05
**Purpose**: Full kitchen gameplay loop review for architecture alignment
**Audience**: Architecture team (design decisions needed before implementation)

---

## What Is The Kitchen?

The kitchen is meant to be **the tutorial system and quantum mechanics smoke test** for Space Wheat.

### Intent (From Your Brief)
```
"The full kitchen's intent is a gameplay loop that acts as a tutorial
and introduction to many of the games systems as well as 'smoke testing'
the quantum mechanics to make sure they are real and not a toybox."
```

### Current Scope (What We Built)
A complete quantum 3-qubit Bell state construction that:
1. Takes quantum inputs (fire 🔥, water 💧, flour 💨)
2. Creates entangled state: |ψ⟩ = α|🔥💧💨⟩ + β|🍞⟩
3. Measures in bread basis
4. Outputs bread 🍞 at 80% efficiency

---

## The Problem

When you tried to test the kitchen loop with keyboard controls, you ran into **three interconnected systems issues**:

1. **Mill Physics Ambiguity**: Mill measures wheat but doesn't consume it
   - Wheat stays "flailing" (evolving quantum state)
   - No clear harvest semantics

2. **Energy Tap Architecture Mismatch**: Can't place fire/water taps from keyboard
   - Taps operate on biome quantum state (layer abstraction)
   - Handler UI requires plot selection (different layer)
   - Fire emoji doesn't exist in BioticFlux biome

3. **Cross-Biome Resource Access**: Kitchen needs fire from Kitchen biome but wheat in BioticFlux
   - No clear ownership model for quantum emojis
   - No mechanism for kitchen to access foreign biome states

These aren't bugs - they're **architectural design gaps** that need closure before implementation.

---

## This Package Contains

### 1. **00_INVESTIGATION_OVERVIEW.md** (this file)
   - High-level summary of investigation
   - Links to detailed documents
   - Decision framework

### 2. **01_GAMEPLAY_LOOP_SPECIFICATION.md**
   - Full kitchen gameplay loop breakdown
   - Step-by-step player workflow
   - What the player learns at each step
   - Quantum mechanics that should be "real"

### 3. **02_SYSTEMS_ANALYSIS.md**
   - Wheat + Mill system deep dive
   - Energy tap system architecture
   - Kitchen quantum mechanics
   - How each piece relates to others

### 4. **03_QUANTUM_MECHANICS_REQUIREMENTS.md**
   - What must be "real" quantum (not toybox)
   - What can be classical approximations
   - Rigor requirements for smoke testing
   - Bell state measurement verification

### 5. **04_UI_FLOW_DOCUMENTATION.md**
   - Keyboard controls needed
   - Visual feedback expectations
   - Modal states and transitions
   - Player confusion points

### 6. **05_DESIGN_DECISION_FRAMEWORK.md**
   - Three critical decisions to make
   - Decision A: Mill physics model
   - Decision B: Energy tap architecture
   - Decision C: Cross-biome access
   - For each: options, trade-offs, implications

### 7. **06_SIMULATION_EVIDENCE.md**
   - Automated test results showing current behavior
   - Wheat collapse (non-)behavior
   - Energy tap placement failure traces
   - Data showing what works vs. broken

### 8. **07_OPEN_SOLUTION_SPACE.md**
   - Don't try to fix incrementally
   - Here's what the solution space actually is
   - Multiple coherent architectural approaches
   - Choose one, implement fully

---

## Quick Navigation

### For Someone in a Hurry
1. Read: **00_INVESTIGATION_OVERVIEW.md** (this file)
2. Skim: **01_GAMEPLAY_LOOP_SPECIFICATION.md**
3. Review: **05_DESIGN_DECISION_FRAMEWORK.md**
4. Make decisions: "What should we do about mill physics?"

### For Implementation
1. Start: **05_DESIGN_DECISION_FRAMEWORK.md** (decide architecture)
2. Reference: **02_SYSTEMS_ANALYSIS.md** (understand current code)
3. Build to: **04_UI_FLOW_DOCUMENTATION.md** (UI requirements)
4. Test with: **06_SIMULATION_EVIDENCE.md** (test procedures)

### For Quantum Mechanics Review
1. Focus: **03_QUANTUM_MECHANICS_REQUIREMENTS.md**
2. Verify: **06_SIMULATION_EVIDENCE.md** (current physics)
3. Decide: **05_DESIGN_DECISION_FRAMEWORK.md** (rigor level)

---

## Current State Snapshot

### What's Working ✅
```
🌾 Wheat planting          → Works (biome quantum registers)
🏭 Mill measurement       → Works (produces flour)
💨 Flour accumulation     → Works (160 credits in 5 seconds)
🍞 Kitchen Bell state     → Works (3-qubit entanglement)
🍞 Kitchen measurement    → Works (collapses to bread)
🍞 Bread production       → Works (280 credits from inputs)
⌨️  Keyboard controls      → Partially working (wheat/kitchen ok, taps blocked)
```

### What's Broken ❌
```
🌾 Wheat collapse after mill     → NOT collapsing (still planted)
⚡ Energy tap placement via UI   → Can't find target emojis in biome
🔥 Fire emoji in biome           → Not injected into BioticFlux/Forest/Market
🏭 Mill emoji display           → No display emoji for mill plots
```

### What's Ambiguous ⚠️
```
🏭 Mill: Destructive or non-destructive measurement?
⚡ Taps: Plot-level or biome-level architecture?
🔥 Fire: How does kitchen access foreign biome's quantum states?
```

---

## Key Findings

### Finding 1: Mill is Non-Destructive Measurement
```
Code Location: Core/GameMechanics/QuantumMill.gd:100-110

Result:
  plot.has_been_measured = true  ✓
  plot.measured_outcome = "👥"   ✓
  plot.is_planted = true         ✗ (still planted!)

Problem: Wheat quantum state NOT consumed
         Can be measured again next frame
         = infinite flour from single wheat
```

**Implication**: Either:
- A) Mill should consume wheat (destructive measurement)
- B) Mill should lock outcome (non-destructive tracking)
- C) This is intentional (wheat is renewable?)

### Finding 2: Energy Taps Have Layer Mismatch
```
UI Layer: "Select plots" (requires plot.is_planted)
Physics Layer: "Create Lindblad drain" (operates on biome bath)

Result:
  FarmInputHandler.gd:1388 blocks empty plots
  BiomeBase.gd:716 can't find target emoji

Problem: Trying to place 🔥 tap in BioticFlux
         But 🔥 only exists in Kitchen biome
         Need emoji injection system
```

**Implication**: Either:
- A) Taps are plot-level structures (different architecture)
- B) Taps auto-inject emojis into biomes
- C) Taps placed only in correct biome
- D) All emojis injected into all biomes

### Finding 3: Cross-Biome Resource Query
```
Kitchen requirements:
  🔥 Fire   - lives in Kitchen biome
  💧 Water  - lives in Forest biome
  💨 Flour  - lives in Market biome (or produced by mill in BioticFlux)

Current architecture:
  Kitchen is placed on BioticFlux plots
  Kitchen biome exists but isn't connected to plot biomes

Problem: No mechanism for kitchen to access fire/water from other biomes
```

**Implication**: Either:
- A) Kitchen accessible from Kitchen biome only
- B) Kitchen is cross-biome aware (queries multiple baths)
- C) Fire/water are injected into all biomes
- D) Kitchen uses different mechanics (not quantum)

---

## How to Use This Package

### Phase 1: Review (2 hours)
1. Read all "00-07" documents
2. Identify assumptions and gaps
3. List any additional questions

### Phase 2: Decide (1 hour)
1. Review **05_DESIGN_DECISION_FRAMEWORK.md**
2. Make three critical decisions
3. Document rationale

### Phase 3: Plan (1 hour)
1. Map decisions to code changes
2. Identify new issues from decisions
3. Create implementation sequence

### Phase 4: Implement (time TBD)
1. Build according to decisions
2. Test against smoke tests
3. Verify quantum rigor

---

## Critical Questions for Architecture Team

### Q1: Mill Semantics
**What should wheat do after the mill measures it?**

```
Scenario: Mill measures wheat at t=1, t=2, t=3
Current:  🌾 produced 3× at each timestep
Intended: ???
```

- Should measurement be consumptive (wheat disappears)?
- Should measurement lock outcome (can't remeasure)?
- Should this be configurable per biome?

### Q2: Energy Tap Model
**Where do energy taps live in the architecture?**

```
Current broken model tries: Plot-level UI + Biome-level physics
Need to choose: Plot-level? Biome-level? Auto-injected?
```

### Q3: Resource Ownership
**Who owns the quantum emojis (fire, water, flour)?**

```
Kitchen needs:
  🔥 Fire from Kitchen biome
  💧 Water from Forest biome
  💨 Flour from mill/market

How does kitchen access these across biome boundaries?
```

---

## How to Read the Documents

Each document is **standalone** but they build on each other:

```
00_OVERVIEW (you are here)
    ↓
01_GAMEPLAY_LOOP (what we're trying to do)
    ↓
02_SYSTEMS_ANALYSIS (how things currently work)
    ↓
03_QUANTUM_MECHANICS (what needs to be "real")
    ↓
04_UI_REQUIREMENTS (what player needs to see/do)
    ↓
05_DESIGN_FRAMEWORK (what decisions to make)
    ↓
06_SIMULATION_EVIDENCE (proof of current state)
    ↓
07_SOLUTION_SPACE (where we can go from here)
```

---

## Key Principle: Don't Restrict Design

**Important**: This investigation is meant to **open** the design space, not close it.

Instead of saying "here's how to fix it", we say:
- "Here's what needs to work"
- "Here are the design choices"
- "Here's what each choice implies"
- "Here's the coherent approaches"

You pick which approach makes sense for your game.

---

## Next Steps

1. **Print** or bookmark `/home/tehcr33d/llm_outbox/kitchen_architecture_review/` folder
2. **Start with** `01_GAMEPLAY_LOOP_SPECIFICATION.md`
3. **When ready** to decide: Review `05_DESIGN_DECISION_FRAMEWORK.md`
4. **Once decided**: Return to Claude with decisions, we implement

---

## Contacts

**Investigation**: `/tmp/test_physics_issues.gd` (automated test showing all issues)

**Evidence**:
- `/home/tehcr33d/llm_outbox/kitchen_architecture_review/06_SIMULATION_EVIDENCE.md`

**Code References**:
- `Core/GameMechanics/QuantumMill.gd` - Mill measurement
- `Core/Environment/QuantumKitchen_Biome.gd` - Kitchen Bell states
- `UI/FarmInputHandler.gd` - Energy tap UI
- `Core/GameMechanics/FarmGrid.gd` - Grid orchestration

---

## Document Summary Table

| Doc | Title | Key Content | Read Time |
|-----|-------|-----------|-----------|
| 00 | Overview | This document | 10 min |
| 01 | Gameplay | Step-by-step loop + learning goals | 15 min |
| 02 | Systems | How wheat/mill/taps/kitchen work | 20 min |
| 03 | Quantum | Rigor requirements + smoke tests | 15 min |
| 04 | UI | Keyboard controls + feedback | 10 min |
| 05 | Decisions | Three key choices + trade-offs | 25 min |
| 06 | Evidence | Test results + simulation data | 15 min |
| 07 | Solutions | Coherent architectural approaches | 20 min |

**Total Review Time**: ~2 hours

---

## Status

✅ Investigation: Complete
⏳ Decisions: Pending
⏳ Implementation: Blocked on decisions
⏳ Testing: Automated tests ready, awaiting architecture alignment

**Ready to proceed once you've reviewed and made architectural decisions.**
