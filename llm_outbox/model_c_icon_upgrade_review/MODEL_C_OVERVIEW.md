# Model C (Analog) Overview - SpaceWheat Quantum Architecture

**Date:** 2026-01-07
**Purpose:** Technical overview of the Model C analog quantum computation system

---

## What is Model C?

Model C is SpaceWheat's **analog quantum computer architecture** - a continuous-time quantum evolution system that uses **density matrices** and **Lindblad master equations** to simulate realistic quantum dynamics with decoherence.

**Key Features:**
- **Density matrix representation** (not just pure states)
- **Continuous Lindblad evolution** (not discrete gates)
- **RegisterMap coordinate system** (emoji → qubit/pole mapping)
- **Hamiltonian + Lindblad operators** built from Icons
- **Per-biome quantum computers** (independent systems)

---

## Architecture Hierarchy

```
IconRegistry (Global Physics)
    ↓ defines interactions
RegisterMap (Local Coordinates)
    ↓ maps emojis → qubits
QuantumComputer (Analog Hardware)
    ↓ executes evolution
QuantumBath (Legacy Interface)
    ↓ wraps for compatibility
BiomeBase (Game Logic)
    ↓ drives simulation
QuantumNode (Visualization)
```

---

## Core Concept: Emoji as Quantum Basis States

### Traditional Quantum Computing
```
|0⟩ = qubit in "zero" state
|1⟩ = qubit in "one" state
```

### Model C (SpaceWheat)
```
|🔥⟩ = qubit in "hot" state (north pole)
|❄️⟩ = qubit in "cold" state (south pole)
```

**Why this matters:**
- Players think in **emojis** (🔥, 💧, 🌾), not bits
- Icons define **physics** (how emojis interact)
- RegisterMap defines **coordinates** (where emojis live in Hilbert space)
- Same Icons work across different biomes with different RegisterMaps

---

## The Three Layers

### Layer 1: Icon Physics (Global)

**IconRegistry** stores **global physics rules**:
```gdscript
Icon: 🌾 (Wheat)
  - self_energy: 0.1 (inherent energy)
  - hamiltonian_couplings: {"☀": 0.5, "💧": 0.4}
    → Wheat couples to Sun and Water (coherent oscillations)
  - lindblad_incoming: {"☀": 0.0267, "💧": 0.0167}
    → Wheat grows FROM Sun and Water (irreversible transfer)
  - decay_rate: 0.02
  - decay_target: "🍂"
    → Wheat decays TO Organic Matter
```

**Physics interpretation:**
- **Hamiltonian couplings** = reversible energy exchange (oscillations)
- **Lindblad incoming** = irreversible population transfer INTO this state
- **Lindblad outgoing** = irreversible population transfer OUT OF this state
- **Decay** = spontaneous relaxation to lower energy state

### Layer 2: RegisterMap Coordinates (Local)

**RegisterMap** translates emojis to qubit coordinates **per biome**:

**Example: 3-Qubit Kitchen**
```
Qubit 0 (Temperature): |🔥⟩ = |0⟩, |❄️⟩ = |1⟩
Qubit 1 (Moisture):    |💧⟩ = |0⟩, |🏜️⟩ = |1⟩
Qubit 2 (Substance):   |💨⟩ = |0⟩, |🌾⟩ = |1⟩
```

**Basis states (8 total):**
```
|000⟩ = |🔥💧💨⟩ = Hot, Wet, Flour = Bread Ready
|001⟩ = |🔥💧🌾⟩ = Hot, Wet, Grain
|010⟩ = |🔥🏜️💨⟩ = Hot, Dry, Flour
...
|111⟩ = |❄️🏜️🌾⟩ = Cold, Dry, Grain = Ground State
```

**Why separate layers?**
- **Icon**: "Wheat grows from Sun" (universal truth)
- **RegisterMap**: "Wheat lives on qubit 2 in this biome" (local fact)
- **Different biomes** can use same Icons but different coordinates
- **Icons are reusable** across Forest (22 qubits) vs Kitchen (3 qubits)

### Layer 3: QuantumComputer Evolution (Analog Hardware)

**QuantumComputer** executes continuous evolution:

```gdscript
# Initialize
var qc = QuantumComputer.new("Kitchen")
qc.allocate_axis(0, "🔥", "❄️")  # Temperature axis
qc.allocate_axis(1, "💧", "🏜️")  # Moisture axis
qc.allocate_axis(2, "💨", "🌾")  # Substance axis
qc.initialize_basis(7)  # Start in |111⟩ = |❄️🏜️🌾⟩

# Apply drives (player actions)
qc.apply_drive("🔥", rate=0.5, dt=0.1)  # Push toward hot

# Query state
var p_bread = qc.get_population("🔥💧💨")  # P(bread ready state)
```

**Evolution equation (Lindblad master):**
```
dρ/dt = -i[H, ρ] + Σ_k γ_k (L_k ρ L_k† - ½{L_k†L_k, ρ})
         ↑            ↑
      Hamiltonian   Lindblad (decoherence + transfer)
```

Where:
- **ρ** = density matrix (2^n × 2^n for n qubits)
- **H** = Hamiltonian (built from Icon.hamiltonian_couplings)
- **L_k** = Lindblad operators (built from Icon.lindblad_incoming/outgoing)
- **γ_k** = rates (from Icons)

---

## Model C vs Legacy Bath System

| Aspect | Legacy QuantumBath | Model C QuantumComputer |
|--------|-------------------|-------------------------|
| **State** | Density matrix (emojis as basis) | Density matrix (qubits as basis) |
| **Coordinates** | Direct emoji indexing | RegisterMap (emoji → qubit/pole) |
| **Operators** | Built from Icon dicts | Built by Hamiltonian/LindbladBuilder |
| **Evolution** | Lindblad master equation | Same (Lindblad master equation) |
| **Icon filtering** | All Icons included | Only Icons with coordinates included |
| **Scalability** | Limited (all emojis → large H) | Better (only biome emojis → small H) |
| **Status** | **Currently used** | **Future (Model C)** |

**Why transition to Model C?**
1. **Scalability:** RegisterMap allows biomes to have independent Hilbert spaces
2. **Modularity:** Same Icons work across different biome configurations
3. **Clarity:** Explicit qubit structure makes quantum mechanics clearer
4. **Tools:** Enables proper quantum gates (H, CNOT, etc.) for Tool 5
5. **Performance:** Smaller Hilbert spaces = faster evolution

**Current status:** Kitchen uses Legacy Bath (with multi-emoji basis states). Model C infrastructure exists but isn't actively used yet.

---

## Analog Computation Principles

### What "Analog" Means

**Digital quantum computing:**
- Apply discrete gates: H, CNOT, etc.
- Exact unitary operations
- Circuit model

**Analog quantum computing (Model C):**
- **Continuous evolution** under Hamiltonian H(t)
- **Always-on interactions** (Icon couplings)
- **Realistic decoherence** (Lindblad operators)
- **Player-controlled drives** (time-dependent terms)

**SpaceWheat is an analog quantum simulator.**

### Evolution Mechanisms

**1. Hamiltonian Evolution (Coherent)**
```gdscript
Icon.hamiltonian_couplings = {"target": strength}
→ Off-diagonal term in H
→ Creates coherent oscillations between states
→ Reversible (energy conserved)
```

Example: Sun ↔ Moon coupling (day/night oscillation)

**2. Lindblad Transfer (Incoherent)**
```gdscript
Icon.lindblad_incoming = {"source": rate}
→ Jump operator L = √rate |this⟩⟨source|
→ Irreversible population transfer
→ Increases entropy
```

Example: Wheat grows from Sun (☀ → 🌾 transfer)

**3. Decay (Thermalization)**
```gdscript
Icon.decay_rate = rate
Icon.decay_target = "target_emoji"
→ Spontaneous relaxation to lower energy
→ Universal dissipation mechanism
```

Example: All Kitchen states decay toward |111⟩ (ground state)

**4. Drives (Player Control)**
```gdscript
qc.apply_drive("target_emoji", rate, dt)
→ Lindblad operator pushing toward target
→ Controlled by player actions (spending resources)
```

Example: Adding fire in Kitchen drives ❄️ → 🔥

---

## Time Scales

**Fast (< 1 second):**
- Drive applications (player actions)
- State queries (visualization at 60 Hz)
- Decay processes

**Medium (1-60 seconds):**
- Hamiltonian oscillations (Sun/Moon cycle = 20s)
- Lindblad transfers (Wheat growth = 37.5s)
- Player-observable dynamics

**Slow (> 60 seconds):**
- Ecosystem equilibration
- Long-term resource accumulation
- Economic cycles

---

## Key Design Decisions

### 1. Emoji-First Design
**Decision:** Players interact with emojis, not qubits
**Rationale:** Intuitive, visual, culturally meaningful
**Trade-off:** Extra translation layer (RegisterMap) needed

### 2. Icon-Based Physics
**Decision:** Icons define global physics rules
**Rationale:** Reusable across biomes, designer-friendly
**Trade-off:** Runtime filtering required (not all Icons apply to all biomes)

### 3. Density Matrix Representation
**Decision:** Use ρ (mixed states) not |ψ⟩ (pure states)
**Rationale:** Realistic decoherence, entanglement with environment
**Trade-off:** Larger memory (n² vs n for pure states)

### 4. Continuous Evolution
**Decision:** Lindblad master equation (analog)
**Rationale:** Matches real physics, smooth dynamics
**Trade-off:** Requires numerical integration (RK4), can't use exact gate math

### 5. Per-Biome Quantum Computers
**Decision:** Each biome has independent Hilbert space
**Rationale:** Scalability, modularity, performance
**Trade-off:** Cross-biome entanglement requires special handling

---

## Current Implementation Status

### ✅ Implemented (Working)
- QuantumComputer class (Core/QuantumSubstrate/)
- RegisterMap (emoji → qubit coordinate mapping)
- HamiltonianBuilder (Icons → H matrix)
- LindbladBuilder (Icons → L_k operators)
- Lindblad evolution (apply_drive, apply_decay)
- State queries (get_population, get_marginal)

### ⚠️ Partially Implemented
- Kitchen uses Legacy Bath (not Model C QuantumComputer)
- Other biomes (BioticFlux, Market, Forest) use Legacy Bath
- Model C infrastructure exists but isn't actively used

### ❌ Not Yet Implemented
- Cross-biome entanglement (Icon-mediated interactions)
- Quantum gates for Model C (H, CNOT exist for Legacy)
- Full transition from Legacy Bath to QuantumComputer
- RegisterMap-aware visualization

---

## Next Steps for Full Model C Transition

1. **Convert Kitchen to use QuantumComputer** (instead of Legacy Bath)
   - Replace multi-emoji basis states with RegisterMap axes
   - Use HamiltonianBuilder/LindbladBuilder
   - Test that bread production still works

2. **Convert BioticFlux to use QuantumComputer**
   - 6 emojis → need at least 3 qubits (2³ = 8 > 6)
   - Or use sparse representation (some basis states unused)

3. **Update visualization** to query QuantumComputer
   - Modify QuantumNode to use RegisterMap
   - Query via get_population() instead of bath.get_probability()

4. **Add cross-biome interactions**
   - Icon-mediated coupling between biomes
   - Example: Biotic Flux Icon affects Kitchen evolution rates

5. **Deprecate Legacy Bath**
   - Remove QuantumBath class
   - Clean up old code paths

---

## Technical Benefits of Model C

### Clarity
- Explicit qubit structure makes quantum mechanics transparent
- RegisterMap clearly separates physics (Icons) from coordinates (qubits)

### Modularity
- Same Icons work across different biome configurations
- Easy to add new biomes without redefining physics

### Scalability
- Each biome has small Hilbert space (2³ for Kitchen, not 2³¹ for all Icons)
- Icon filtering happens at operator build time (not evolution time)

### Correctness
- Explicit Hamiltonian/Lindblad operators (not ad-hoc transfer rules)
- Hermiticity enforced (H = H†)
- Trace preservation guaranteed (Lindblad form)

### Tools
- Enables proper quantum gates (Model B had gate infrastructure)
- Easier to implement Tool 5 (unitary operations)
- Clear path to advanced features (error correction, annealing)

---

## Terminology Clarification

**Model A:** Original system (deprecated)
**Model B:** Factorized components (partially implemented)
**Model C:** Analog + RegisterMap (current target)

**Note:** The code comments sometimes say "Model B" where they mean "Model C". The key distinction is:
- **Model B** = Component-based quantum computer (Tool 1-5 backend)
- **Model C** = Analog continuous evolution with RegisterMap

Model C builds on Model B infrastructure but adds analog evolution.

---

## Files to Review

**Core Architecture:**
- `Core/QuantumSubstrate/QuantumComputer.gd` - Main quantum computer class
- `Core/QuantumSubstrate/RegisterMap.gd` - Emoji → qubit/pole mapping
- `Core/QuantumSubstrate/HamiltonianBuilder.gd` - Icon → H matrix
- `Core/QuantumSubstrate/LindbladBuilder.gd` - Icon → L_k operators

**Legacy System:**
- `Core/QuantumSubstrate/QuantumBath.gd` - Old system (still in use)
- `Core/Environment/BiomeBase.gd` - Biome evolution loop

**Icon Definitions:**
- `Core/Icons/CoreIcons.gd` - All Icon physics definitions
- `Core/QuantumSubstrate/IconRegistry.gd` - Icon storage/lookup

**Example Usage:**
- `Core/Environment/QuantumKitchen_Biome.gd` - Kitchen (uses Legacy Bath)
- `Core/Environment/BioticFluxBiome.gd` - BioticFlux (uses Legacy Bath)

---

## Commentary

**Strengths:**
- Well-architected separation of concerns (physics vs coordinates)
- Icons are designer-friendly and reusable
- Proper quantum mechanics (Lindblad master equation)
- Analog evolution matches real quantum systems

**Challenges:**
- Transition from Legacy to Model C is incomplete
- Multi-emoji basis states (Kitchen) don't fit RegisterMap cleanly
- Cross-biome interactions need design work
- Performance concerns for large Hilbert spaces

**Recommendation:**
Start with Kitchen as proof-of-concept for full Model C transition. It's the simplest biome (3 qubits, clear structure) and already has well-defined physics.
