# Model C (Analog) Review - Documentation Index

**Date:** 2026-01-07
**Purpose:** Technical review materials for transitioning SpaceWheat to Model C analog quantum architecture

---

## Overview

This folder contains comprehensive documentation of SpaceWheat's Model C (analog quantum computer) architecture, gathered for review and planning of biome/icon updates.

**Status:** Model C infrastructure exists but is not actively used. Current system uses Legacy QuantumBath. This review prepares for full transition.

---

## Documents in This Folder

### 1. **MODEL_C_OVERVIEW.md** (Core Architecture)
**What it covers:**
- What is Model C and why it exists
- Three-layer architecture (Icons → RegisterMap → QuantumComputer)
- How analog quantum computation works
- Evolution mechanisms (Hamiltonian, Lindblad, decay, drives)
- Comparison to Legacy Bath system
- Current implementation status
- Next steps for full transition

**Read this first** to understand the big picture.

### 2. **REGISTERMAP_ARCHITECTURE.md** (Coordinate System)
**What it covers:**
- Emoji → qubit/pole coordinate mapping
- Multi-qubit basis states
- API reference and usage patterns
- Design patterns (Icon filtering, reusable physics)
- Limitations and future enhancements
- Comparison to Legacy system

**Read this second** to understand how emojis map to quantum states.

### 3. **ALL_ICONS_INVENTORY.md** (Physics Definitions)
**What it covers:**
- Complete list of all 32 Icons across 8 categories
- For each Icon: emoji, name, energy, couplings, rates, decay, tags
- 10x rate speedup for gameplay visibility
- Identified bugs (water double-definition, eternal flag error)

**Read this third** to see all current Icon physics.

### 4. **VISUALIZATION_SYSTEM.md** (Display Layer)
**What it covers:**
- How quantum bubbles are rendered
- 6+ visual channels (opacity, hue, saturation, glow, pulse, radius)
- State query architecture (60 Hz update rate)
- Performance analysis (8-12ms per frame with 12 bubbles)
- Optimization opportunities

**Read this fourth** to understand how quantum state becomes pixels.

### 5. **RECOMMENDATIONS.md** (Next Steps)
**What it covers:**
- Prioritized action items for Model C transition
- Icon review and adjustment suggestions
- Biome-specific recommendations
- Technical improvements
- Design decisions to make

**Read this last** for actionable next steps.

---

## Quick Reference

### Key Concepts

**Icon:** Global physics rule defining how an emoji interacts with others
- Hamiltonian couplings (reversible energy exchange)
- Lindblad rates (irreversible transfer)
- Decay (spontaneous relaxation)

**RegisterMap:** Local coordinate system mapping emojis to qubits
- Qubit = binary axis (north pole |0⟩, south pole |1⟩)
- Example: Qubit 0 = 🔥 (north) / ❄️ (south)

**QuantumComputer:** Analog hardware executing continuous evolution
- Density matrix ρ (2^n × 2^n for n qubits)
- Lindblad master equation: dρ/dt = -i[H,ρ] + Lindblad terms
- Supports drives (player actions), decay, state queries

**Biome:** Game region with independent quantum system
- BioticFlux: 6 emojis (sun/moon, wheat/mushroom, death/decay)
- Market: 8 emojis (economic trading dynamics)
- Forest: 22 emojis (food web ecosystem)
- Kitchen: 8 emojis (3 qubits - temperature, moisture, substance)

### Current Status

✅ **Working:**
- Legacy QuantumBath (all biomes use this)
- Icon system (31+ Icons defined)
- Visualization (bubbles query bath state)
- Evolution (Lindblad master equation)

⚠️ **Partially Done:**
- Model C infrastructure (exists but unused)
- RegisterMap (implemented but not integrated)
- Hamiltonian/LindbladBuilder (implemented but unused)

❌ **Not Done:**
- Biomes using QuantumComputer (instead of Legacy Bath)
- RegisterMap-aware visualization
- Cross-biome Icon-mediated interactions

---

## Technical Stack

### Core Classes

**Quantum Substrate:**
- `QuantumComputer` - Analog quantum computer (Model C)
- `QuantumBath` - Legacy system (currently used)
- `RegisterMap` - Emoji → qubit coordinate mapper
- `HamiltonianBuilder` - Icons → H matrix
- `LindbladBuilder` - Icons → L_k operators
- `ComplexMatrix` - Dense complex matrices
- `Complex` - Complex number type

**Icons:**
- `Icon` - Physics definition resource
- `IconRegistry` - Global Icon storage
- `CoreIcons` - Built-in Icon definitions

**Biomes:**
- `BiomeBase` - Abstract biome with evolution loop
- `BioticFluxBiome` - Sun/moon ecosystem
- `MarketBiome` - Economic trading
- `ForestBiome` - Food web (Markov-derived)
- `QuantumKitchen_Biome` - Cooking/production

**Visualization:**
- `QuantumNode` - Quantum bubble (one per plot)
- `QuantumForceGraph` - Bubble renderer
- `BathQuantumVisualizationController` - Lifecycle manager

---

## Key Files

**Model C Implementation:**
- `/Core/QuantumSubstrate/QuantumComputer.gd` (869 lines)
- `/Core/QuantumSubstrate/RegisterMap.gd` (157 lines)
- `/Core/QuantumSubstrate/HamiltonianBuilder.gd` (136 lines)
- `/Core/QuantumSubstrate/LindbladBuilder.gd` (101 lines)

**Legacy System:**
- `/Core/QuantumSubstrate/QuantumBath.gd` (still in use)

**Icons:**
- `/Core/Icons/CoreIcons.gd` (661 lines, 32 Icons)
- `/Core/QuantumSubstrate/IconRegistry.gd` (157 lines)

**Biomes:**
- `/Core/Environment/BiomeBase.gd` (evolution loop)
- `/Core/Environment/BioticFluxBiome.gd` (uses Legacy Bath)
- `/Core/Environment/QuantumKitchen_Biome.gd` (uses Legacy Bath)

**Visualization:**
- `/Core/Visualization/QuantumNode.gd` (state → visuals)
- `/Core/Visualization/QuantumForceGraph.gd` (renderer)

---

## Statistics

### Icon Inventory
- **32 total Icons** across 8 categories
- **6 driver Icons** (time-dependent self-energy)
- **4 eternal Icons** (never decay)
- **All Lindblad rates 10x faster** for gameplay visibility
- **3 different driver frequencies:** 20s (celestial), 30s (market), 15s (kitchen)

### Biome Sizes
- **BioticFlux:** 6 emojis (needs 3 qubits for Model C)
- **Market:** 8 emojis (needs 3 qubits)
- **Forest:** 22 emojis (needs 5 qubits for Model C)
- **Kitchen:** 8 basis states (currently multi-emoji labels)

### Visualization Performance
- **60 Hz update rate** (every frame)
- **8-12ms per frame** with 12 bubbles
- **720 bath queries/second** (12 bubbles × 60 Hz)
- **0.3ms per emoji** (text rendering bottleneck)

---

## Questions to Answer

Before proceeding with Model C transition, decide:

### 1. RegisterMap Strategy
- **Q:** How to handle Kitchen's multi-emoji basis states (e.g. "🔥💧💨")?
- **Option A:** Use pure qubits, treat 8 states as |0⟩-|7⟩
- **Option B:** Extend RegisterMap to support composite emojis

### 2. Icon Filtering
- **Q:** Should all biomes share same Icons, or custom per biome?
- **Current:** All biomes use CoreIcons, filtered by RegisterMap
- **Alternative:** Each biome creates own Icons with custom physics

### 3. Cross-Biome Interactions
- **Q:** How should Icon simulation objects (BioticFluxIcon, etc.) affect biomes?
- **Current:** Icon objects wander scene, proximity affects rates (unclear)
- **Model C:** Need clear coupling mechanism between biome QuantumComputers

### 4. Visualization Updates
- **Q:** Should QuantumNode query QuantumComputer or QuantumBath?
- **Current:** Queries QuantumBath (Legacy)
- **Model C:** Need to query QuantumComputer via RegisterMap

### 5. Performance Targets
- **Q:** What's acceptable biome size for real-time evolution?
- **3 qubits:** 8×8 matrix = 64 complex numbers (trivial)
- **5 qubits:** 32×32 matrix = 1024 complex numbers (fine)
- **10 qubits:** 1024×1024 matrix = 1M complex numbers (too slow)

### 6. Transition Strategy
- **Q:** Big bang or incremental transition to Model C?
- **Option A:** Convert all biomes at once (risky but clean)
- **Option B:** Convert Kitchen first as proof-of-concept (safer)

---

## Recommended Reading Order

1. **MODEL_C_OVERVIEW.md** - Understand the architecture
2. **REGISTERMAP_ARCHITECTURE.md** - Learn the coordinate system
3. **ALL_ICONS_INVENTORY.md** - Review all physics definitions
4. **VISUALIZATION_SYSTEM.md** - See how it's displayed
5. **RECOMMENDATIONS.md** - Plan next steps

---

## External Resources

**In this repository:**
- `/home/tehcr33d/llm_outbox/BIOME_VISUAL_EFFECTS_GUIDE.md` - What you should see in each biome
- `/home/tehcr33d/llm_outbox/QUANTUM_EVOLUTION_FIX_COMPLETE.md` - Recent fix for evolution freeze
- `/home/tehcr33d/llm_outbox/BOOTMANAGER_FIX_APPLIED.md` - Initialization timing fix

**Code locations:**
- `/home/tehcr33d/ws/SpaceWheat/Core/QuantumSubstrate/` - Quantum simulation
- `/home/tehcr33d/ws/SpaceWheat/Core/Icons/` - Icon definitions
- `/home/tehcr33d/ws/SpaceWheat/Core/Environment/` - Biomes
- `/home/tehcr33d/ws/SpaceWheat/Core/Visualization/` - Display layer

---

## Contact Points

**Architecture questions:**
- QuantumComputer class (Model C analog system)
- RegisterMap class (coordinate mapping)

**Physics questions:**
- Icon resource (physics definitions)
- CoreIcons (built-in Icon definitions)

**Integration questions:**
- BiomeBase (evolution loop)
- Specific biome classes (BioticFluxBiome, QuantumKitchen_Biome, etc.)

**Visualization questions:**
- QuantumNode (bubble state queries)
- QuantumForceGraph (rendering)

---

## Next Steps

See **RECOMMENDATIONS.md** for detailed action items, but at high level:

1. **Review** all Icons in ALL_ICONS_INVENTORY.md
2. **Adjust** Icon parameters if needed (rates, couplings, decay)
3. **Decide** on RegisterMap strategy (pure qubits vs composite emojis)
4. **Convert** Kitchen to Model C as proof-of-concept
5. **Test** that quantum evolution still works
6. **Convert** other biomes (BioticFlux, Market, Forest)
7. **Update** visualization to use RegisterMap
8. **Deprecate** Legacy QuantumBath

---

## Glossary

**Analog quantum computing:** Continuous-time evolution (not discrete gates)
**Basis state:** Computational basis |i⟩ (e.g. |000⟩ = hot, wet, flour)
**Coherence:** Off-diagonal elements of density matrix (quantum phase)
**Density matrix:** ρ = statistical mixture of quantum states
**Hamiltonian:** H = energy operator (drives coherent oscillations)
**Icon:** Resource defining emoji physics (couplings, rates, decay)
**Lindblad operator:** L_k = jump operator causing irreversible transfer
**North pole:** |0⟩ state of qubit (e.g. 🔥 = hot)
**Pole:** One of two basis states of a qubit
**Purity:** Tr(ρ²) = measure of entanglement (1 = pure, <1 = mixed)
**Qubit:** 2-level quantum system with north and south poles
**RegisterMap:** Coordinate system mapping emojis to qubits
**South pole:** |1⟩ state of qubit (e.g. ❄️ = cold)

---

## Changelog

**2026-01-07:** Initial documentation gathered
- Created comprehensive review package
- Documented Model C architecture
- Inventoried all Icons
- Analyzed visualization system
- Prepared recommendations

---

This documentation was generated for technical review and planning. All information current as of 2026-01-07.
