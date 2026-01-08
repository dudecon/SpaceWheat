# Q2: Model B Architecture - Physics-First Design

**Question**: The docs reference "Model B (bath-first)" vs an older "Model A (qubit-first)". Can you clarify the architecture?

**Answer**: Model B is a **proper density matrix formalism** where the biome owns all quantum state. Plots are just handles into it.

---

## Model A vs Model B

### Model A (Old): Qubit-First
```
Each plot had its own quantum state:
┌─────────────┐
│ Plot (0,0)  │
│ quantum_state: DualEmojiQubit  │─→ Isolated state evolution
└─────────────┘

┌─────────────┐
│ Plot (1,0)  │
│ quantum_state: DualEmojiQubit  │─→ Entanglement manually tracked
└─────────────┘

Problems:
- No central quantum state
- Manual entanglement handling
- Measurement inconsistent
- Cross-biome impossible
```

### Model B (Current): Bath-First
```
Biome owns ONE quantum computer:
┌──────────────────────────────────────────┐
│ BiomeBase (owns quantum state)            │
│                                           │
│  quantum_computer: QuantumComputer       │
│  ┌──────────────────────────────────┐   │
│  │ QuantumComponent 0 (2 qubits)    │   │
│  │  - register_id: 0 (plot at 0,0)  │   │
│  │  - register_id: 1 (plot at 1,0)  │   │
│  │  - state_vector: [...]           │   │
│  │  - is_entangled: true (CNOT)     │   │
│  └──────────────────────────────────┘   │
│                                           │
│  QuantumComponent 1 (1 qubit)            │
│  │  - register_id: 2 (plot at 0,1)  │   │
│  │  - state_vector: [...]           │   │
│  │  - is_entangled: false           │   │
│  └──────────────────────────────────┘   │
└──────────────────────────────────────────┘

Plots just hold metadata:
┌──────────┐
│ Plot     │
│ register_id: 0  │─→ Points into component 0
│ parent_biome    │─→ BiomeBase reference
└──────────┘
```

---

## The QuantumComputer: Single Source of Truth

**File**: `Core/QuantumSubstrate/QuantumComputer.gd`

**Architecture**:
```gdscript
class_name QuantumComputer extends Resource

var biome_name: String = ""
var components: Dictionary = {}              # component_id → QuantumComponent
var register_to_component: Dictionary = {}   # register_id → component_id
var entanglement_graph: Dictionary = {}      # register_id → Array[register_id]
```

**Three Key Structures**:

1. **Components** (Separately Evolving Systems)
```gdscript
var components: Dictionary = {
    0: QuantumComponent {
        register_ids: [0, 1],      # Two qubits (plots at 0,0 and 1,0)
        state_vector: [c0, c1, c2, c3],  # 4D (2⊗2)
        is_pure: true
        hilbert_dimension: 4
    },
    1: QuantumComponent {
        register_ids: [2],         # One qubit (plot at 0,1)
        state_vector: [c0, c1],    # 2D
        is_pure: true
        hilbert_dimension: 2
    }
}
```

Key insight: **Only entangled qubits share a component.**
- Unentangled: separate components (efficient storage)
- Entangled: merged components (tensor product)

2. **Register Mapping** (Which qubit is which)
```gdscript
var register_to_component: Dictionary = {
    0: 0,  # Register 0 (wheat at plot 0,0) in component 0
    1: 0,  # Register 1 (mushroom at plot 1,0) in component 0 (ENTANGLED!)
    2: 1   # Register 2 (wheat at plot 0,1) in component 1
}
```

3. **Entanglement Graph** (Who's connected)
```gdscript
var entanglement_graph: Dictionary = {
    0: [1],    # Register 0 entangled with 1
    1: [0],    # Register 1 entangled with 0
    2: []      # Register 2 isolated
}
```

---

## The QuantumBath: Legacy Compatibility Layer

**File**: `Core/QuantumSubstrate/QuantumBath.gd`

**Purpose**: Backwards compatibility while Model B is being rolled out

**Current Status**:
```gdscript
var _density_matrix  # DensityMatrix (NEW: actual quantum state)
var _hamiltonian     # Hamiltonian operator
var _lindblad        # LindbladSuperoperator
var _evolver         # QuantumEvolver

# Legacy properties (computed on-demand from density matrix)
var amplitudes: Array[Complex]:
    get:
        # Compute from density matrix diagonal
        var result: Array[Complex] = []
        for i in range(_density_matrix.dimension()):
            var prob = _density_matrix.get_probability_by_index(i)
            result.append(Complex.new(sqrt(max(0.0, prob)), 0.0))
        return result
```

**Why Both?**
- QuantumComputer: Model B (proper architecture)
- QuantumBath: Model A compatibility (being deprecated)
- Each biome has both
- Code can use either (but shouldn't)

**TODO**: Remove QuantumBath after full migration to QuantumComputer

---

## Density Matrix Storage

### What's Actually Stored

**In QuantumComputer**:
```
Each QuantumComponent owns a state vector or density matrix:

For 1 qubit (register 0):
  |ψ⟩ = α|0⟩ + β|1⟩
  Stored as: [α, β] (Complex numbers)

For 2 qubits (registers 0,1):
  |ψ⟩ = c00|00⟩ + c01|01⟩ + c10|10⟩ + c11|11⟩
  Stored as: [c00, c01, c10, c11] (4-element vector)

For 3 qubits (kitchen):
  |ψ⟩ = (8 complex amplitudes)
  Stored as: 8-element vector
```

**In QuantumBath**:
```
Legacy: Full density matrix ρ
Stored as: 2D array of Complex numbers
ρ = |ψ⟩⟨ψ| (if pure state)
ρ = mixed state (if decoherent)

Access: _density_matrix.get_element(i, j)
```

### Model B Advantage: Factorization

```
Single biome with 3 entangled qubits + 5 isolated:

Model A (full density matrix):
  8 qubits total = 256×256 complex matrix
  56,536 complex numbers = 452 KB

Model B (factorized):
  Component 1: 3 qubits = 8×8 matrix = 128 complex
  Component 2-6: 1 qubit each = 2×2 = 8 complex each
  Total: 128 + 5×8 = 168 complex numbers = 1.3 KB

  Speedup: 346× fewer calculations!
```

---

## Active Icons and Evolution

### What is bath.active_icons?

```gdscript
var active_icons: Array[Icon] = []
```

**Answer**: The set of **Hamiltonian terms** that affect this biome.

**Example (BioticFlux)**:
```gdscript
active_icons = [
    Icon("🌾", "wheat"),     # Hamiltonian: drives toward wheat state
    Icon("☀️", "sunlight"),  # Lindblad: couples wheat to sunlight
    Icon("🌙", "moonlight"), # Lindblad: couples mushroom to moonlight
    Icon("🍄", "mushroom"),  # Hamiltonian: mushroom dynamics
    Icon("🍂", "detritus"),  # Lindblad: decay term
    Icon("❌", "decay")      # Lindblad: entropy production
]
```

**NOT** "emojis that CAN exist in this biome". Rather: "physics terms affecting evolution".

### How Evolution Works

```gdscript
func advance_simulation(dt: float):
    # Rebuild Hamiltonian from current Icons
    _hamiltonian = _build_hamiltonian(active_icons)

    # Rebuild Lindblad operators
    _lindblad = _build_lindblad(active_icons)

    # Apply Lindblad master equation:
    # dρ/dt = -i[H, ρ] + Σ_k (L_k ρ L_k† - 0.5{L_k†L_k, ρ})
    _evolver.apply_step(dt)
```

---

## How Kitchen Accesses Fire/Water

### Current Problem

Kitchen needs fire from Kitchen biome, water from Forest:

```
Kitchen biome:
  quantum_computer owns:
    ├─ 🔥 (fire qubit)
    └─ 🍞 (bread output)

Forest biome:
  quantum_computer owns:
    ├─ 💧 (water qubit)
    ├─ 🌿 (vegetation)
    └─ predators

BioticFlux biome:
  quantum_computer owns:
    ├─ 🌾 (wheat)
    ├─ 🍄 (mushroom)
    └─ 💨 (flour from mill)
```

**Kitchen is placed on BioticFlux plots but needs:**
- 🔥 from Kitchen.quantum_computer
- 💧 from Forest.quantum_computer
- 💨 from BioticFlux.quantum_computer

**NO MECHANISM exists for this!**

### Possible Solutions

**Option 1: Direct Reference**
```gdscript
func bake_bread():
    var fire_state = farm.kitchen_biome.quantum_computer.query(🔥)
    var water_state = farm.forest_biome.quantum_computer.query(💧)
    var flour_state = farm.biotic_flux_biome.quantum_computer.query(💨)
    # Create bell state from three separate biome states
```
Problem: Cross-biome entanglement? Not physically justified.

**Option 2: Resource Movement**
```
Energy taps PHYSICALLY move resources:
  Kitchen bath (fire) → Sink → Economy
  Forest bath (water) → Sink → Economy
  Mill (flour) → Sink → Economy

Kitchen reads from Economy, not from baths.
```
Problem: Adds unnecessary complexity.

**Option 3: Kitchen-Only Biome**
```
Kitchen is a biome itself with fire/water/flour.
Place kitchen ONLY in Kitchen biome.
Kitchen has its own quantum computer (simpler).
```
Advantage: Clean separation.

---

## Summary: Model B Architecture

| Aspect | Model A | Model B |
|--------|---------|---------|
| State owner | Each plot | Biome (QuantumComputer) |
| Entanglement | Manual tracking | Automatic (component merge) |
| Storage | Per-plot overhead | Factorized components |
| Measurement | Inconsistent | Via quantum_computer |
| Scalability | Poor (256×256 matrices) | Excellent (factorized) |
| Physics correctness | Partial | Full (density matrix formalism) |
| Implementation status | Deprecated | Current |

---

## For Kitchen Physics

Model B means:
- ✅ Each biome has proper density matrix evolution
- ✅ Purity-based measurement correct
- ✅ Lindblad drains for energy taps valid
- ❌ Cross-biome access undefined
- ❓ Kitchen as 3-qubit Bell state uses what density matrix?

The kitchen is "hybrid":
- Creates Bell state (3-qubit superposition)
- Uses qubits from different biome baths
- Measures in bread basis

**Physics question**: Is a Bell state across three biome baths even well-defined?

That's an **architectural decision**, not a physics error.
