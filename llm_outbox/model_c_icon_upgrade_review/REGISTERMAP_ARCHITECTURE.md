# RegisterMap Architecture - Emoji to Qubit Coordinate System

**Date:** 2026-01-07
**File:** `Core/QuantumSubstrate/RegisterMap.gd`

---

## Purpose

RegisterMap is the **critical translation layer** that bridges:
- **IconRegistry** (global physics): HOW emojis interact
- **QuantumComputer** (local hardware): WHERE emojis live in Hilbert space

**Core idea:** The same emoji can live on different qubits in different biomes.

---

## Architecture

### Data Structure

```gdscript
class RegisterMap:
    # Primary lookup: emoji → coordinate
    var coordinates: Dictionary = {}
    # {
    #   "🔥": {"qubit": 0, "pole": NORTH},
    #   "❄️": {"qubit": 0, "pole": SOUTH},
    #   "💧": {"qubit": 1, "pole": NORTH},
    #   ...
    # }

    # Reverse lookup: qubit → {north, south} emojis
    var axes: Dictionary = {}
    # {
    #   0: {"north": "🔥", "south": "❄️"},
    #   1: {"north": "💧", "south": "🏜️"},
    #   ...
    # }

    var num_qubits: int = 0  # Total qubits registered
```

### Constants

```gdscript
const NORTH = 0  # |0⟩ state (north pole of Bloch sphere)
const SOUTH = 1  # |1⟩ state (south pole of Bloch sphere)
```

---

## Key Concepts

### 1. Qubit Axis

Each qubit is a **binary axis** with two poles:
```
Qubit 0 (Temperature):
  North pole (|0⟩) = 🔥 (Hot)
  South pole (|1⟩) = ❄️ (Cold)
```

**Physical interpretation:**
- Qubit can be in |0⟩ (100% hot), |1⟩ (100% cold), or superposition
- Measurement collapses to one pole
- Hamiltonian creates oscillations (hot ↔ cold coherence)
- Lindblad creates decay (hot → cold irreversible transfer)

### 2. Multi-Qubit Basis States

For n qubits, there are **2^n basis states**:

**Example: 3-Qubit Kitchen**
```
|000⟩ = |🔥💧💨⟩ = Hot, Wet, Flour
|001⟩ = |🔥💧🌾⟩ = Hot, Wet, Grain
|010⟩ = |🔥🏜️💨⟩ = Hot, Dry, Flour
|011⟩ = |🔥🏜️🌾⟩ = Hot, Dry, Grain
|100⟩ = |❄️💧💨⟩ = Cold, Wet, Flour
|101⟩ = |❄️💧🌾⟩ = Cold, Wet, Grain
|110⟩ = |❄️🏜️💨⟩ = Cold, Dry, Flour
|111⟩ = |❄️🏜️🌾⟩ = Cold, Dry, Grain
```

**Interpretation:**
- Each basis state is a **product state** of all qubits
- State vector: |ψ⟩ = Σ c_i |i⟩ where i ∈ {0..7}
- Density matrix: ρ = |ψ⟩⟨ψ| (8×8 for 3 qubits)

### 3. Coordinate Mapping

**Forward lookup (emoji → coordinate):**
```gdscript
register_map.qubit("🔥")  # → 0
register_map.pole("🔥")   # → NORTH (0)
```

**Reverse lookup (qubit → emojis):**
```gdscript
register_map.axis(0)  # → {"north": "🔥", "south": "❄️"}
```

**Basis state conversion:**
```gdscript
# Basis index → emoji array
register_map.basis_to_emojis(0)  # → ["🔥", "💧", "💨"]
register_map.basis_to_emojis(7)  # → ["❄️", "🏜️", "🌾"]

# Emoji array → basis index
register_map.emojis_to_basis(["🔥", "💧", "💨"])  # → 0
register_map.emojis_to_basis(["❄️", "🏜️", "🌾"])  # → 7
```

---

## API Reference

### Registration

```gdscript
func register_axis(qubit_index: int, north_emoji: String, south_emoji: String) -> void
```

**Purpose:** Register a qubit axis with its pole labels.

**Constraints:**
- `north_emoji != south_emoji` (orthogonal basis states)
- No collisions (emoji can't be registered twice)
- Qubit indices typically sequential (0, 1, 2, ...)

**Example:**
```gdscript
var rm = RegisterMap.new()
rm.register_axis(0, "🔥", "❄️")  # Temperature
rm.register_axis(1, "💧", "🏜️")  # Moisture
rm.register_axis(2, "💨", "🌾")  # Substance
# Now have 3 qubits → 8D Hilbert space
```

**Output:**
```
📊 Qubit 0: |0⟩=🔥 |1⟩=❄️
📊 Qubit 1: |0⟩=💧 |1⟩=🏜️
📊 Qubit 2: |0⟩=💨 |1⟩=🌾
```

### Queries

```gdscript
func has(emoji: String) -> bool
func qubit(emoji: String) -> int        # -1 if not found
func pole(emoji: String) -> int         # 0=NORTH, 1=SOUTH, -1 if not found
func axis(qubit_index: int) -> Dictionary  # {"north": emoji, "south": emoji}
func dim() -> int                       # Hilbert space dimension (2^num_qubits)
```

**Example:**
```gdscript
if rm.has("🔥"):
    var q = rm.qubit("🔥")  # 0
    var p = rm.pole("🔥")   # 0 (NORTH)
    print("🔥 lives on qubit %d, pole %d" % [q, p])
```

### Basis Conversions

```gdscript
func basis_to_emojis(index: int) -> Array[String]
func emojis_to_basis(emojis: Array[String]) -> int
```

**Example:**
```gdscript
var emojis = rm.basis_to_emojis(5)  # [❄️, 💧, 🌾] (binary 101)
var index = rm.emojis_to_basis(emojis)  # 5
```

**Binary encoding:**
```
Index   Binary   Emojis
  0     000      [🔥, 💧, 💨]
  1     001      [🔥, 💧, 🌾]
  2     010      [🔥, 🏜️, 💨]
  3     011      [🔥, 🏜️, 🌾]
  4     100      [❄️, 💧, 💨]
  5     101      [❄️, 💧, 🌾]
  6     110      [❄️, 🏜️, 💨]
  7     111      [❄️, 🏜️, 🌾]
```

**Bit layout:** MSB = qubit 0, LSB = qubit n-1
- Bit 0 → qubit 0 (leftmost emoji)
- Bit 1 → qubit 1 (middle emoji)
- Bit 2 → qubit 2 (rightmost emoji)

---

## How It's Used

### 1. QuantumComputer Initialization

```gdscript
var qc = QuantumComputer.new("Kitchen")
qc.allocate_axis(0, "🔥", "❄️")  # Internally calls register_map.register_axis()
qc.allocate_axis(1, "💧", "🏜️")
qc.allocate_axis(2, "💨", "🌾")
# Creates 3-qubit system (8D Hilbert space)
```

### 2. HamiltonianBuilder

```gdscript
static func build(icons: Dictionary, register_map: RegisterMap) -> ComplexMatrix:
    # For each Icon coupling
    for source_emoji in icons:
        if not register_map.has(source_emoji):
            continue  # Filter: skip if not in this biome

        var source_q = register_map.qubit(source_emoji)
        var source_p = register_map.pole(source_emoji)

        for target_emoji in icon.hamiltonian_couplings:
            if not register_map.has(target_emoji):
                continue  # Filter: skip if not in this biome

            var target_q = register_map.qubit(target_emoji)
            var target_p = register_map.pole(target_emoji)

            # Add coupling H[i,j] based on (q,p) coordinates
            _add_coupling(H, source_q, source_p, target_q, target_p, coupling, num_qubits)
```

**Key insight:** Same Icons can be reused across biomes because RegisterMap filters which couplings apply.

### 3. LindbladBuilder

```gdscript
static func build(icons: Dictionary, register_map: RegisterMap) -> Array[ComplexMatrix]:
    # Similar filtering logic
    for source_emoji in icons:
        if not register_map.has(source_emoji):
            continue

        # Build L_k = √γ |target⟩⟨source| using coordinates
        var L = _build_jump(source_q, source_p, target_q, target_p, amplitude, num_qubits)
        operators.append(L)
```

### 4. State Queries

```gdscript
# Get population of single emoji
var p_fire = qc.get_population("🔥")
# → Internally: qubit=0, pole=NORTH → marginal trace over other qubits

# Get population of basis state
var p_bread = qc.get_population(["🔥", "💧", "💨"])
# → Internally: emojis_to_basis([🔥,💧,💨]) = 0 → ρ[0,0]
```

---

## Example: Kitchen Biome Setup

```gdscript
# Core/Environment/QuantumKitchen_Biome.gd (hypothetical Model C version)

func _initialize_quantum_computer() -> void:
    quantum_computer = QuantumComputer.new("Kitchen")

    # Register 3 axes
    quantum_computer.allocate_axis(0, "🔥", "❄️")  # Temperature
    quantum_computer.allocate_axis(1, "💧", "🏜️")  # Moisture
    quantum_computer.allocate_axis(2, "💨", "🌾")  # Substance

    # Initialize to ground state |111⟩ = |❄️🏜️🌾⟩
    quantum_computer.initialize_basis(7)  # Binary 111 = 7

    # Get Icons from IconRegistry
    var icon_registry = get_node("/root/IconRegistry")
    var icons = {}
    for emoji in ["🔥", "❄️", "💧", "🏜️", "💨", "🌾"]:
        icons[emoji] = icon_registry.get_icon(emoji)

    # Build operators (automatically filtered by RegisterMap)
    var H = HamiltonianBuilder.build(icons, quantum_computer.register_map)
    var L_ops = LindbladBuilder.build(icons, quantum_computer.register_map)

    # Store operators in QuantumComputer
    quantum_computer.hamiltonian = H
    quantum_computer.lindblad_operators = L_ops

    print("✅ Kitchen: 3 qubits, 8 basis states, %d Lindblad terms" % L_ops.size())
```

---

## Design Patterns

### Pattern 1: Icon Filtering

**Problem:** IconRegistry has 31+ Icons, but Kitchen only uses 6 emojis.

**Solution:** RegisterMap filters during operator build.

```gdscript
# IconRegistry has "☀" with coupling to "🌾"
# Kitchen RegisterMap doesn't have "☀"
# → HamiltonianBuilder skips this coupling for Kitchen
# → BioticFlux RegisterMap DOES have "☀" → includes the coupling
```

**Result:** Each biome gets a minimal Hilbert space with only relevant interactions.

### Pattern 2: Reusable Physics

**Problem:** Don't want to redefine Icon physics for each biome.

**Solution:** Icons define global physics, RegisterMap localizes them.

```gdscript
# Icon definition (global)
wheat.hamiltonian_couplings = {"☀": 0.5, "💧": 0.4}

# BioticFlux RegisterMap (has ☀, 💧, 🌾)
# → Wheat couples to Sun and Water

# Kitchen RegisterMap (has 💧, 🌾 but NOT ☀)
# → Wheat only couples to Water in Kitchen
```

**Result:** Same Icon definitions work across different biome contexts.

### Pattern 3: Coordinate Independence

**Problem:** Want visualization code to work regardless of qubit layout.

**Solution:** Query by emoji, not by qubit index.

```gdscript
# Bad (coordinate-dependent)
var p0 = qc.get_marginal(0, 0)  # What does qubit 0 mean?

# Good (coordinate-independent)
var p_fire = qc.get_population("🔥")  # Clear semantic meaning
```

---

## Limitations

### 1. Binary Axes Only

RegisterMap assumes **qubits** (2-level systems).

**Can't represent:**
- 3-level systems (qutrits)
- Continuous variables (position, momentum)
- Non-binary labels

**Workaround:** Use multiple qubits to encode higher-dimensional spaces.

### 2. Fixed Qubit Count

Once axes are registered, Hilbert space dimension is fixed.

**Can't dynamically:**
- Add new qubits at runtime
- Resize density matrix
- Change emoji assignments

**Workaround:** Pre-allocate all needed qubits, leave some unused.

### 3. All Qubits Independent

RegisterMap doesn't enforce constraints like "qubit 0 and 1 are entangled" or "qubit 2 is always measured."

**Result:** Hilbert space grows exponentially (2^n) even if some subspaces are never accessed.

**Workaround:** Use component factorization (Model B) to track which qubits are actually entangled.

---

## Comparison to Legacy System

### Legacy QuantumBath

**Basis states:** Direct emoji labels
```gdscript
bath.initialize_with_emojis(["🔥💧💨", "🔥💧🌾", ..., "❄️🏜️🌾"])
# 8 labels, 8×8 density matrix
```

**Pros:**
- Simple (no coordinate translation)
- Can use arbitrary multi-character labels
- Direct mapping from Icons to matrix indices

**Cons:**
- Doesn't scale (Kitchen is fine, but 31 Icons → 31×31 matrix)
- Can't reuse Icons across biomes (all emojis hard-coded)
- No qubit structure (can't use quantum gates properly)

### Model C RegisterMap

**Basis states:** Qubit product states
```gdscript
register_map.register_axis(0, "🔥", "❄️")
register_map.register_axis(1, "💧", "🏜️")
register_map.register_axis(2, "💨", "🌾")
# 3 qubits → 8 basis states (2^3)
```

**Pros:**
- Scalable (each biome has minimal Hilbert space)
- Icon reuse (filtering at build time)
- Qubit structure (enables gates, factorization)
- Clear separation of physics (Icons) and coordinates (RegisterMap)

**Cons:**
- Extra translation layer (emoji ↔ qubit/pole)
- Requires explicit axis registration
- Binary axes only (no qutrits)

---

## Future Enhancements

### 1. Sparse RegisterMaps

**Problem:** Some basis states may never be used.

**Example:** Kitchen has 8 basis states but |010⟩ (hot, dry, flour) may be unreachable.

**Solution:** Allow RegisterMap to specify "active subspace" and use sparse matrices.

### 2. Dynamic Axes

**Problem:** Can't add qubits at runtime.

**Solution:** Support `allocate_axis()` after initialization with automatic density matrix resize.

**Challenge:** What happens to existing quantum state?

### 3. Higher-Dimensional Poles

**Problem:** Binary qubits limit expressiveness.

**Solution:** Generalize to d-level systems (qudits).

**Example:**
```gdscript
register_map.register_axis(0, ["🔥", "🌡️", "❄️"])  # 3-level temperature
```

### 4. Composite Emojis

**Problem:** Kitchen uses multi-character emojis like "🔥💧💨" which don't fit RegisterMap cleanly.

**Solution:** Allow RegisterMap to map composite emojis to basis indices directly.

```gdscript
register_map.register_composite("🔥💧💨", 0)  # Basis state 0
register_map.register_composite("❄️🏜️🌾", 7)  # Basis state 7
```

---

## Code Location

**File:** `Core/QuantumSubstrate/RegisterMap.gd` (157 lines)

**Dependencies:**
- None (pure data structure)

**Used by:**
- `QuantumComputer.gd` (stores as `register_map` member)
- `HamiltonianBuilder.gd` (for coordinate filtering)
- `LindbladBuilder.gd` (for coordinate filtering)

---

## Commentary

**Strengths:**
- Clean separation of physics (Icons) and coordinates (qubits)
- Enables Icon reuse across biomes
- Proper qubit structure for quantum mechanics
- Simple, well-documented API

**Weaknesses:**
- Doesn't handle multi-character emojis elegantly (Kitchen issue)
- No support for qutrits or higher-dimensional systems
- Can't dynamically add qubits

**Recommendation:**
RegisterMap is well-designed for single-emoji qubits. For full Model C transition, either:

**Option A:** Stick with binary qubits
- Pros: Clean, mathematically correct
- Cons: Kitchen "🔥💧💨" labels don't fit

**Option B:** Add composite emoji support
- Pros: Preserves Kitchen's multi-emoji labels
- Cons: Breaks clean qubit abstraction

**Suggested path:** Use Option A (pure qubits) and treat Kitchen's 8 basis states as abstract |0⟩ through |7⟩ with RegisterMap providing semantic labels for visualization only.
