# Model C Machinery Guide - Source Code Reference

**Date:** 2026-01-07
**Purpose:** Technical reference for all source files included in this review package

---

## Overview

This document catalogs all `.gd.txt` files (renamed from `.gd` to avoid collisions) included in this review package. Each file is a critical component of SpaceWheat's Model C analog quantum architecture.

**File naming:** Original `.gd` files renamed to `.gd.txt` for safe transport and review.

---

## Core Quantum Substrate (Model C)

### QuantumComputer.gd.txt (869 lines)
**Path:** `Core/QuantumSubstrate/QuantumComputer.gd`
**Status:** ✅ Implemented, ❌ Not actively used

**Purpose:** Main Model C analog quantum computer implementation.

**Key Features:**
- Density matrix representation (2^n × 2^n for n qubits)
- RegisterMap-based coordinate system
- Lindblad master equation evolution
- Player-controlled drives
- State queries and measurements
- Unitary gate support

**Public API:**
```gdscript
# Initialization
func allocate_axis(qubit_index: int, north_emoji: String, south_emoji: String)
func initialize_basis(index: int)
func initialize_thermal(beta: float)

# Evolution
func apply_drive(target_emoji: String, rate: float, dt: float)
func apply_decay(dt: float)
func evolve(dt: float)

# State queries
func get_population(arg) -> float  # Single emoji or array
func get_marginal(qubit_index: int, pole: int) -> float
func get_basis_probability(index: int) -> float
func get_purity() -> float

# Measurements
func measure_register(qubit_index: int) -> int
func inspect_register_distribution(qubit_index: int) -> Dictionary
```

**Dependencies:**
- `RegisterMap` (emoji → qubit coordinates)
- `ComplexMatrix` (density matrix operations)
- `Complex` (complex numbers)

**Used by:** Future biomes (not yet integrated)

---

### RegisterMap.gd.txt (157 lines)
**Path:** `Core/QuantumSubstrate/RegisterMap.gd`
**Status:** ✅ Implemented, ❌ Not actively used

**Purpose:** Emoji → qubit/pole coordinate translation layer.

**Key Concept:** Separates physics (Icons) from coordinates (qubits).

**Data Structure:**
```gdscript
# Forward: emoji → {qubit, pole}
coordinates = {
  "🔥": {"qubit": 0, "pole": NORTH},
  "❄️": {"qubit": 0, "pole": SOUTH},
  ...
}

# Reverse: qubit → {north, south}
axes = {
  0: {"north": "🔥", "south": "❄️"},
  ...
}
```

**Public API:**
```gdscript
func register_axis(qubit_index: int, north_emoji: String, south_emoji: String)
func has(emoji: String) -> bool
func qubit(emoji: String) -> int
func pole(emoji: String) -> int
func axis(qubit_index: int) -> Dictionary
func dim() -> int  # 2^num_qubits
func basis_to_emojis(index: int) -> Array[String]
func emojis_to_basis(emojis: Array[String]) -> int
```

**Design Pattern:** Enables Icon reuse across different biome configurations.

---

### HamiltonianBuilder.gd.txt (136 lines)
**Path:** `Core/QuantumSubstrate/HamiltonianBuilder.gd`
**Status:** ✅ Implemented, ❌ Not actively used

**Purpose:** Constructs Hamiltonian matrix H from Icons, filtered by RegisterMap.

**Key Method:**
```gdscript
static func build(icons: Dictionary, register_map: RegisterMap) -> ComplexMatrix
```

**Algorithm:**
1. For each Icon in `icons`:
   - Check if Icon's emoji is in `register_map`
   - If yes, get qubit/pole coordinates
   - For each `hamiltonian_coupling`:
     - Check if target emoji is in `register_map`
     - Add coupling H[i,j] based on coordinates
     - Ensure Hermiticity: H[j,i] = H[i,j]*

**Result:** Hermitian matrix H (energy operator).

**Physics:** H drives coherent oscillations via -i[H,ρ] term in Lindblad equation.

**Icon filtering:** Automatically excludes Icons whose emojis aren't in RegisterMap.

---

### LindbladBuilder.gd.txt (101 lines)
**Path:** `Core/QuantumSubstrate/LindbladBuilder.gd`
**Status:** ✅ Implemented, ❌ Not actively used

**Purpose:** Constructs Lindblad operators L_k from Icons, filtered by RegisterMap.

**Key Method:**
```gdscript
static func build(icons: Dictionary, register_map: RegisterMap) -> Array[ComplexMatrix]
```

**Algorithm:**
1. For each Icon in `icons`:
   - Process `lindblad_incoming` (population transfer INTO this emoji)
   - Process `lindblad_outgoing` (population transfer OUT OF this emoji)
   - Build jump operator: L_k = √γ |target⟩⟨source|

**Result:** Array of Lindblad operators L_k.

**Physics:** L_k drives irreversible population transfer via Lindblad superoperator.

**Icon filtering:** Same as HamiltonianBuilder.

---

### Complex.gd.txt (~100 lines estimated)
**Path:** `Core/QuantumSubstrate/Complex.gd`
**Status:** ✅ Fully functional

**Purpose:** Complex number implementation (a + bi).

**Operations:**
- Addition, subtraction, multiplication, division
- Conjugate, magnitude, magnitude_squared, phase
- Exponential (Euler's formula)
- String formatting

**Used by:** All quantum machinery.

---

### ComplexMatrix.gd.txt (~400 lines estimated)
**Path:** `Core/QuantumSubstrate/ComplexMatrix.gd`
**Status:** ✅ Fully functional

**Purpose:** Dense complex matrix operations.

**Operations:**
- Matrix multiplication, addition
- Hermitian conjugate (dagger)
- Commutator [A,B], anticommutator {A,B}
- Trace, partial trace
- Tensor product
- Exponentiation (matrix exponential)
- Apply to density matrix (sandwich: A ρ A†)

**Performance:** Dense matrices, O(n³) for multiplication.

**Used by:** QuantumComputer, HamiltonianBuilder, LindbladBuilder.

---

## Icon System

### Icon.gd.txt (~150 lines estimated)
**Path:** `Core/QuantumSubstrate/Icon.gd`
**Status:** ✅ Fully functional

**Purpose:** Resource class defining emoji physics.

**Properties:**
```gdscript
@export var emoji: String  # Unicode emoji
@export var icon_name: String  # Human-readable name
@export var self_energy: float = 0.0  # Diagonal H term
@export var hamiltonian_couplings: Dictionary = {}  # {emoji: strength}
@export var lindblad_incoming: Dictionary = {}  # {source_emoji: rate}
@export var lindblad_outgoing: Dictionary = {}  # {target_emoji: rate}
@export var decay_rate: float = 0.0  # Spontaneous decay rate
@export var decay_target: String = ""  # Target emoji
@export var is_eternal: bool = false  # Never decays
@export var is_driver: bool = false  # Time-dependent self-energy
@export var driver_frequency_seconds: float = 0.0
@export var driver_amplitude: float = 0.0
@export var tags: Array[String] = []
@export var trophic_level: int = 0  # Ecosystem tier
```

**Usage:** Define once in CoreIcons, use across all biomes.

---

### CoreIcons.gd.txt (661 lines)
**Path:** `Core/Icons/CoreIcons.gd`
**Status:** ✅ Functional, ⚠️ Contains bugs

**Purpose:** Defines all 32 Icons with physics parameters.

**Categories:**
1. **Celestial** (2): ☀ Sun, 🌙 Moon
2. **Flora** (5): 🌾 Wheat, 🍄 Mushroom, 🌲 Conifer, 🌳 Broadleaf, 🌿 Herb
3. **Fauna** (7): 🦌 Deer, 🐿️ Squirrel, 🐦 Bird, 🦅 Eagle, 🐺 Wolf, 🐻 Bear, 🐛 Bug
4. **Elements** (4): 💧 Water, 🏜️ Soil, 🌬️ Wind, 🔥 Fire
5. **Abstract** (4): 💀 Death, 🍂 Organic Matter, 📈 Bull Market, 📉 Bear Market
6. **Reserved** (2): 🌍 Global State, 💰 Currency
7. **Market** (2): 🧑‍🌾 Farmer, 🥖 Bread
8. **Kitchen** (6): 🔥 Fire, ❄️ Cold, 💧 Moisture, 🏜️ Dryness, 💨 Flour, 🌾 Grain

**Known Bugs:**
- Line 302: `water.is_eternal = true` should be `soil.is_eternal = true`
- Water defined twice (Elements section + Kitchen section, different emojis)

**Rate Tuning:** All Lindblad rates 10x faster for gameplay visibility.

---

### IconRegistry.gd.txt (157 lines)
**Path:** `Core/QuantumSubstrate/IconRegistry.gd`
**Status:** ✅ Functional, ⚠️ Initialization timing issue (fixed)

**Purpose:** Global autoload storing all Icons.

**Lifecycle:**
1. `_ready()`: Load CoreIcons
2. Biomes query Icons via `get_icon(emoji)`

**Timing Bug (Fixed):** Biomes initialized before IconRegistry loaded → 0 operators. Fixed by BootManager Stage 3A rebuild.

**Public API:**
```gdscript
func register_icon(icon: Icon)
func get_icon(emoji: String) -> Icon
func has_icon(emoji: String) -> bool
func get_all_icons() -> Array[Icon]
```

---

## Legacy System (Currently Used)

### QuantumBath.gd.txt (~600 lines estimated)
**Path:** `Core/QuantumSubstrate/QuantumBath.gd`
**Status:** ✅ Fully functional, currently used by ALL biomes

**Purpose:** Legacy quantum evolution system (pre-Model C).

**Differences from Model C:**
- Direct emoji basis states (no RegisterMap)
- Emojis can be multi-character strings (e.g. "🔥💧💨")
- Icons applied directly (no HamiltonianBuilder/LindbladBuilder)
- Less modular (all Icons included, no filtering)

**Why still used:** Transition to Model C incomplete.

**Evolution:**
```gdscript
func evolve(delta: float)  # Main evolution loop
func build_hamiltonian_from_icons(icons: Array[Icon])
func build_lindblad_from_icons(icons: Array[Icon])
```

**State queries:**
```gdscript
func get_probability(emoji: String) -> float
func get_complex_amplitude(emoji: String) -> Complex
```

**Used by:** BioticFluxBiome, MarketBiome, ForestBiome, QuantumKitchen_Biome.

---

## Biome Implementations

### BiomeBase.gd.txt (~1200 lines estimated)
**Path:** `Core/Environment/BiomeBase.gd`
**Status:** ✅ Functional

**Purpose:** Abstract base class for all biomes.

**Key Responsibilities:**
- Quantum bath lifecycle (initialization, evolution)
- Plot management (active plots, harvesting)
- Energy accounting
- Operator rebuild infrastructure
- Idle optimization (disabled temporarily)

**Evolution Loop:**
```gdscript
func _process(delta: float):
    if bath:
        bath.evolve(delta * evolution_speed)
```

**Rebuild API:**
```gdscript
func rebuild_quantum_operators()  # Public, called by BootManager
func _rebuild_bath_operators()  # Override in child classes
```

**Child Classes:** BioticFluxBiome, MarketBiome, ForestBiome, QuantumKitchen_Biome.

---

### BioticFluxBiome.gd.txt (~250 lines)
**Path:** `Core/Environment/BioticFluxBiome.gd`
**Status:** ✅ Functional

**Purpose:** Sun/Moon ecosystem (6 emojis, celestial oscillations).

**Emojis:** ☀ Sun, 🌙 Moon, 🌾 Wheat, 🍄 Mushroom, 💀 Death, 🍂 Organic Matter

**Evolution Speed:** 4x baseline

**Key Dynamics:**
- Sun ↔ Moon oscillation (20s period)
- Wheat grows from Sun (☀ → 🌾, 37.5s)
- Mushroom grows from Moon (🌙 → 🍄, 2.5s)
- Organic matter decay

**Icon Tuning:**
```gdscript
wheat_icon.lindblad_incoming["☀"] = 0.017  # Slow growth
mushroom_icon.lindblad_incoming["🌙"] = 0.40  # Fast growth
```

**Model C Requirement:** 3 qubits minimum (2³ = 8 > 6 emojis).

---

### QuantumKitchen_Biome.gd.txt (~300 lines estimated)
**Path:** `Core/Environment/QuantumKitchen_Biome.gd`
**Status:** ✅ Functional (Legacy Bath)

**Purpose:** 3-qubit cooking system (temperature, moisture, substance).

**Basis States:** 8 states using 3-emoji strings:
```
|000⟩ = "🔥💧💨" = Hot, Wet, Flour = Bread Ready
|001⟩ = "🔥💧🌾" = Hot, Wet, Grain
...
|111⟩ = "❄️🏜️🌾" = Cold, Dry, Grain = Ground State
```

**Evolution:** Continuous Lindblad evolution toward bread state.

**Harvest:** Measure bread state, produce bread resource.

**Model C Challenge:** Multi-emoji basis states don't fit RegisterMap's pure qubit model.

**Recommendation:** Convert to 3 qubits with RegisterMap:
```gdscript
register_map.register_axis(0, "🔥", "❄️")  # Temperature
register_map.register_axis(1, "💧", "🏜️")  # Moisture
register_map.register_axis(2, "💨", "🌾")  # Substance
```

---

## Visualization System

### QuantumNode.gd.txt (~400 lines estimated)
**Path:** `Core/Visualization/QuantumNode.gd`
**Status:** ✅ Functional

**Purpose:** Single quantum bubble (one per plot).

**Visual Channels (6+):**
1. **Opacity** ← Probability P(emoji)
2. **Hue** ← Quantum phase arg(ψ)
3. **Saturation** ← Coherence |ψ|
4. **Glow intensity** ← Purity Tr(ρ²)
5. **Pulse rate** ← Decoherence rate
6. **Radius** ← Mass/Energy

**State Queries:**
```gdscript
func _process(delta):
    if bath:
        var prob = bath.get_probability(current_emoji)
        opacity = prob
        # ... update other visual properties
```

**Update Rate:** 60 Hz (every frame).

**Performance:** ~0.3ms per emoji query (text rendering bottleneck).

---

### QuantumForceGraph.gd.txt (~600 lines estimated)
**Path:** `Core/Visualization/QuantumForceGraph.gd`
**Status:** ✅ Functional

**Purpose:** Manages all quantum bubbles in scene.

**Responsibilities:**
- Spawn QuantumNode instances
- Position bubbles in grid layout
- Handle physics (collision avoidance)
- Update all bubbles each frame

**Performance:** 8-12ms per frame with 12 bubbles (720 queries/second).

**Bottleneck:** Text rendering (emoji labels).

---

### BathQuantumVisualizationController.gd.txt (~200 lines estimated)
**Path:** `Core/Visualization/BathQuantumVisualizationController.gd`
**Status:** ✅ Functional

**Purpose:** Lifecycle manager for visualization system.

**Responsibilities:**
- Initialize QuantumForceGraph
- Connect to biome bath
- Handle cleanup on biome change

---

## Supporting Files

### MarketBiome.gd.txt (if exists)
**Path:** `Core/Environment/MarketBiome.gd`
**Status:** Likely exists but not in core review

**Purpose:** Economic trading ecosystem (8 emojis, bull/bear cycles).

**Expected Dynamics:**
- Bull ↔ Bear oscillation (30s period)
- Farmer produces wheat
- Bread trading

---

## File Dependency Graph

```
Icon.gd (Resource)
  ↓ defines
CoreIcons.gd (32 Icon definitions)
  ↓ registered in
IconRegistry.gd (Global autoload)
  ↓ provides Icons to
BiomeBase.gd (Abstract)
  ↓ extended by
BioticFluxBiome.gd, QuantumKitchen_Biome.gd, etc.
  ↓ create
QuantumBath.gd (Legacy) OR QuantumComputer.gd (Model C)
  ↓ uses (Model C only)
RegisterMap.gd, HamiltonianBuilder.gd, LindbladBuilder.gd
  ↓ depends on
ComplexMatrix.gd, Complex.gd
  ↓ queried by
QuantumNode.gd
  ↓ managed by
QuantumForceGraph.gd
  ↓ initialized by
BathQuantumVisualizationController.gd
```

---

## Implementation Status Summary

| Component | Status | Lines | Usage |
|-----------|--------|-------|-------|
| QuantumComputer | ✅ Complete | 869 | ❌ Unused |
| RegisterMap | ✅ Complete | 157 | ❌ Unused |
| HamiltonianBuilder | ✅ Complete | 136 | ❌ Unused |
| LindbladBuilder | ✅ Complete | 101 | ❌ Unused |
| QuantumBath | ✅ Complete | ~600 | ✅ All biomes |
| Icon | ✅ Complete | ~150 | ✅ All biomes |
| CoreIcons | ⚠️ Has bugs | 661 | ✅ All biomes |
| IconRegistry | ✅ Fixed | 157 | ✅ All biomes |
| BiomeBase | ✅ Complete | ~1200 | ✅ All biomes |
| BioticFluxBiome | ✅ Complete | ~250 | ✅ Active |
| QuantumKitchen | ✅ Complete | ~300 | ✅ Active |
| QuantumNode | ✅ Complete | ~400 | ✅ Active |
| QuantumForceGraph | ✅ Complete | ~600 | ✅ Active |
| Complex | ✅ Complete | ~100 | ✅ All quantum |
| ComplexMatrix | ✅ Complete | ~400 | ✅ All quantum |

---

## Critical Insights

### 1. Model C Infrastructure Exists But Unused
**Finding:** QuantumComputer, RegisterMap, Hamiltonian/LindbladBuilder all implemented but no biome uses them.

**Reason:** Transition incomplete. All biomes still use Legacy QuantumBath.

**Action:** Follow RECOMMENDATIONS.md roadmap for transition.

---

### 2. Icon System Works Well
**Finding:** Icon-based physics is elegant, reusable, designer-friendly.

**Issues:**
- Water double-definition bug
- Eternal flag on wrong Icon
- Some rates may need tuning

**Action:** Fix bugs in CoreIcons.gd, review rates in ALL_ICONS_INVENTORY.md.

---

### 3. Visualization is Expensive
**Finding:** 8-12ms per frame for 12 bubbles (720 queries/second).

**Bottleneck:** Text rendering (emoji labels).

**Optimization:** Cache emoji textures, reduce query rate, batch state queries.

---

### 4. Kitchen Multi-Emoji Problem
**Finding:** Kitchen uses 3-character emoji strings like "🔥💧💨" which don't fit RegisterMap.

**Options:**
- **A:** Convert to pure qubits, use basis indices for internal representation
- **B:** Extend RegisterMap to support composite emojis

**Recommendation:** Option A (pure qubits) - cleaner, more quantum-mechanical.

---

### 5. Initialization Timing Fixed
**Finding:** IconRegistry timing bug caused 0 operators.

**Solution:** BootManager Stage 3A rebuild ensures deterministic ordering.

**Status:** ✅ Fixed.

---

## Next Steps

1. **Review ALL_ICONS_INVENTORY.md** - Check all 32 Icons for physics correctness
2. **Fix CoreIcons bugs** - Water double-def, eternal flag
3. **Convert Kitchen to Model C** - Proof-of-concept for RegisterMap
4. **Test quantum evolution** - Verify bread production still works
5. **Repeat for other biomes** - BioticFlux, Market, Forest
6. **Update visualization** - Query QuantumComputer instead of QuantumBath
7. **Deprecate Legacy Bath** - Remove QuantumBath.gd

---

## File Manifest

**Documentation (6 files):**
- INDEX.md
- MODEL_C_OVERVIEW.md
- REGISTERMAP_ARCHITECTURE.md
- ALL_ICONS_INVENTORY.md
- VISUALIZATION_SYSTEM.md
- RECOMMENDATIONS.md
- MACHINERY_GUIDE.md (this file)

**Source Code (17 files):**
- QuantumComputer.gd.txt
- RegisterMap.gd.txt
- HamiltonianBuilder.gd.txt
- LindbladBuilder.gd.txt
- QuantumBath.gd.txt
- Icon.gd.txt
- CoreIcons.gd.txt
- IconRegistry.gd.txt
- Complex.gd.txt
- ComplexMatrix.gd.txt
- BiomeBase.gd.txt
- BioticFluxBiome.gd.txt
- QuantumKitchen_Biome.gd.txt
- QuantumNode.gd.txt
- QuantumForceGraph.gd.txt
- BathQuantumVisualizationController.gd.txt
- MarketBiome.gd.txt (if exists)

**Total:** 23+ files in this review package.

---

This machinery guide provides technical context for all source code included in the review package. Read alongside MODEL_C_OVERVIEW.md and RECOMMENDATIONS.md for complete understanding.
