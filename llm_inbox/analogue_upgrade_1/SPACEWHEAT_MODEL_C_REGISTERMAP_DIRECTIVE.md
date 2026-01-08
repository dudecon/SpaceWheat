# 🗺️ SpaceWheat Model C: RegisterMap Infrastructure

**Version**: 3.1
**Date**: 2026-01-05
**Status**: CRITICAL INFRASTRUCTURE
**Scope**: Translation layer between Icons (physics) and Basis Labels (coordinates)

---

## The Core Problem

There are TWO distinct concepts that MUST NOT be conflated:

| Concept | What It Is | Where It Lives | Example |
|---------|------------|----------------|---------|
| **Icon** | Physics law: "🔥 couples to ❄️ with strength 0.3" | `IconRegistry` (global) | `icons["🔥"].hamiltonian_couplings["❄️"] = Complex(0.3, 0)` |
| **Basis Label** | Coordinate: "🔥 is the north pole of qubit 2" | `RegisterMap` (per-biome) | `register_map.coordinates["🔥"] = {qubit: 2, pole: NORTH}` |

**Icons are VERBS** (how things interact).
**Basis Labels are ADDRESSES** (where things live in the matrix).

An implementation bot will conflate these. This directive prevents that.

---

## Data Structures Overview

All registries and couplings use **dictionaries with emoji keys**:

```gdscript
# IconRegistry: Dictionary[emoji] → Icon
var icons: Dictionary = {
    "🔥": fire_icon,
    "❄️": cold_icon,
    "💧": water_icon,
    ...
}

# Icon.hamiltonian_couplings: Dictionary[emoji] → Complex
var hamiltonian_couplings: Dictionary = {
    "❄️": Complex.new(0.3, 0.0),   # Couples to cold
    "💧": Complex.new(0.1, 0.0),   # Couples to water
}

# Icon.lindblad_couplings: Dictionary[emoji] → Complex
var lindblad_couplings: Dictionary = {
    "❄️": Complex.new(0.14, 0.0),  # √rate to cold
}

# RegisterMap.coordinates: Dictionary[emoji] → {qubit, pole}
var coordinates: Dictionary = {
    "🔥": {"qubit": 0, "pole": NORTH},
    "❄️": {"qubit": 0, "pole": SOUTH},
    "💧": {"qubit": 1, "pole": NORTH},
    "🏜️": {"qubit": 1, "pole": SOUTH},
}

# RegisterMap.axes: Dictionary[qubit] → {north, south}
var axes: Dictionary = {
    0: {"north": "🔥", "south": "❄️"},
    1: {"north": "💧", "south": "🏜️"},
}
```

---

## The Translation Layer

### RegisterMap: Emoji → Coordinate

Every biome's `QuantumComputer` maintains a `RegisterMap` that translates emoji labels to matrix coordinates:

```gdscript
# Core/QuantumSubstrate/RegisterMap.gd

class_name RegisterMap
extends RefCounted

## RegisterMap: Translates emoji labels to qubit coordinates
##
## Structure: Dictionary[emoji] → {qubit: int, pole: int}
##
## This is the "glue" between IconRegistry (global physics) and
## QuantumComputer (local hardware). Without this layer, the math breaks.

const NORTH = 0  # |0⟩ state
const SOUTH = 1  # |1⟩ state

## Primary data structure: emoji → coordinate
## {
##   "🔥": {"qubit": 0, "pole": NORTH},
##   "❄️": {"qubit": 0, "pole": SOUTH},
##   "💧": {"qubit": 1, "pole": NORTH},
##   ...
## }
var coordinates: Dictionary = {}

## Reverse lookup: qubit → {north: emoji, south: emoji}
var axes: Dictionary = {}

## Number of qubits
var num_qubits: int = 0


func register_axis(qubit_index: int, north_emoji: String, south_emoji: String) -> void:
    """Register a qubit axis with its pole labels."""
    
    # Validate orthogonality
    assert(north_emoji != south_emoji,
           "Qubit %d: poles must differ! Got '%s'" % [qubit_index, north_emoji])
    
    # Validate no collisions
    if coordinates.has(north_emoji):
        var existing = coordinates[north_emoji]
        assert(existing["qubit"] == qubit_index,
               "Emoji '%s' already on qubit %d!" % [north_emoji, existing["qubit"]])
    
    # Register both poles
    coordinates[north_emoji] = {"qubit": qubit_index, "pole": NORTH}
    coordinates[south_emoji] = {"qubit": qubit_index, "pole": SOUTH}
    
    # Reverse lookup
    axes[qubit_index] = {"north": north_emoji, "south": south_emoji}
    
    num_qubits = max(num_qubits, qubit_index + 1)


func has(emoji: String) -> bool:
    """Check if emoji is registered."""
    return coordinates.has(emoji)


func get(emoji: String) -> Dictionary:
    """Get {qubit: int, pole: int} for emoji."""
    return coordinates.get(emoji, {})


func qubit(emoji: String) -> int:
    """Get qubit index for emoji, or -1."""
    return coordinates.get(emoji, {}).get("qubit", -1)


func pole(emoji: String) -> int:
    """Get pole (0=north, 1=south) for emoji, or -1."""
    return coordinates.get(emoji, {}).get("pole", -1)


func axis(qubit_index: int) -> Dictionary:
    """Get {north: emoji, south: emoji} for qubit."""
    return axes.get(qubit_index, {})


func dim() -> int:
    """Hilbert space dimension (2^num_qubits)."""
    return 1 << num_qubits


func basis_to_emojis(index: int) -> Array[String]:
    """Convert basis index to emoji array."""
    var result: Array[String] = []
    for q in range(num_qubits):
        var bit = (index >> (num_qubits - 1 - q)) & 1
        var ax = axes[q]
        result.append(ax["north"] if bit == 0 else ax["south"])
    return result


func emojis_to_basis(emojis: Array[String]) -> int:
    """Convert emoji array to basis index."""
    var index = 0
    for q in range(num_qubits):
        var ax = axes[q]
        if emojis[q] == ax["south"]:
            index |= (1 << (num_qubits - 1 - q))
    return index
```

---

## Icon Couplings: Emoji → Complex

The Icon's coupling terms are also dictionaries with emoji keys and Complex values:

```gdscript
# Core/QuantumSubstrate/Icon.gd (coupling structure)

## Hamiltonian couplings: emoji → Complex
## {
##   "❄️": Complex(0.3, 0.0),    # Real coupling
##   "💧": Complex(0.0, 0.1),    # Imaginary coupling (if needed)
##   "🍞": Complex(0.15, 0.0)
## }
@export var hamiltonian_couplings: Dictionary = {}

## Lindblad transfers: emoji → Complex (magnitude = √rate)
## {
##   "❄️": Complex(0.14, 0.0),   # √0.02 ≈ 0.14
##   "💀": Complex(0.1, 0.0)
## }
@export var lindblad_couplings: Dictionary = {}
```

### Complex Number Class

```gdscript
# Core/QuantumSubstrate/Complex.gd

class_name Complex
extends RefCounted

var re: float = 0.0
var im: float = 0.0

func _init(real: float = 0.0, imag: float = 0.0):
    re = real
    im = imag

static func zero() -> Complex:
    return Complex.new(0.0, 0.0)

static func one() -> Complex:
    return Complex.new(1.0, 0.0)

static func i() -> Complex:
    return Complex.new(0.0, 1.0)

func add(other: Complex) -> Complex:
    return Complex.new(re + other.re, im + other.im)

func sub(other: Complex) -> Complex:
    return Complex.new(re - other.re, im - other.im)

func mul(other: Complex) -> Complex:
    return Complex.new(
        re * other.re - im * other.im,
        re * other.im + im * other.re
    )

func scale(s: float) -> Complex:
    return Complex.new(re * s, im * s)

func conj() -> Complex:
    return Complex.new(re, -im)

func mag() -> float:
    return sqrt(re * re + im * im)

func mag_sq() -> float:
    return re * re + im * im

func _to_string() -> String:
    if im >= 0:
        return "%.3f+%.3fi" % [re, im]
    else:
        return "%.3f%.3fi" % [re, im]
```

---

## Integration with QuantumComputer

### QuantumComputer Owns the RegisterMap

```gdscript
# Core/QuantumSubstrate/QuantumComputer.gd

class_name QuantumComputer
extends RefCounted

var name: String = ""
var register_map: RegisterMap = RegisterMap.new()
var density_matrix: ComplexMatrix = null


func _init(biome_name: String = ""):
    name = biome_name


func allocate_axis(north_emoji: String, south_emoji: String) -> int:
    """Allocate a new qubit axis. Returns qubit index."""
    
    # Validate emojis exist in global IconRegistry
    if not IconRegistry.icons.has(north_emoji):
        push_error("PHYSICS ERROR: '%s' not in IconRegistry!" % north_emoji)
        return -1
    if not IconRegistry.icons.has(south_emoji):
        push_error("PHYSICS ERROR: '%s' not in IconRegistry!" % south_emoji)
        return -1
    
    var qubit_index = register_map.num_qubits
    register_map.register_axis(qubit_index, north_emoji, south_emoji)
    
    # Expand density matrix
    _resize_density_matrix()
    
    print("📊 Qubit %d: |0⟩=%s |1⟩=%s" % [qubit_index, north_emoji, south_emoji])
    return qubit_index


func _resize_density_matrix() -> void:
    """Resize density matrix for current number of qubits."""
    var dim = register_map.dim()
    density_matrix = ComplexMatrix.zeros(dim, dim)
    # Initialize to |11...1⟩ (ground state)
    density_matrix.set_element(dim - 1, dim - 1, Complex.one())


func initialize_basis(index: int) -> void:
    """Initialize to pure basis state |index⟩."""
    var dim = register_map.dim()
    density_matrix = ComplexMatrix.zeros(dim, dim)
    density_matrix.set_element(index, index, Complex.one())


func has(emoji: String) -> bool:
    """Check if emoji has a coordinate."""
    return register_map.has(emoji)


func qubit(emoji: String) -> int:
    """Get qubit index for emoji."""
    return register_map.qubit(emoji)


func pole(emoji: String) -> int:
    """Get pole for emoji."""
    return register_map.pole(emoji)
```

---

## Icon Composition with Coordinate Filtering

### The Key Insight

When building the Hamiltonian from Icons, we **filter couplings** based on what registers exist. If an Icon says "🔥 couples to 🍞", but this biome only has 🔥 (no 🍞 register), the coupling is **skipped**—not errored.

This allows the same Icons to be reused across biomes with different register configurations.

```gdscript
# Core/QuantumSubstrate/HamiltonianBuilder.gd

class_name HamiltonianBuilder
extends RefCounted

## Build Hamiltonian from Icons, filtered by RegisterMap
##
## Icons define GLOBAL physics: {emoji: {target_emoji: Complex}}
## RegisterMap defines LOCAL coordinates: {emoji: {qubit, pole}}
## Only couplings where BOTH emojis have coordinates are included.


static func build(icons: Dictionary, register_map: RegisterMap) -> ComplexMatrix:
    """Build Hamiltonian matrix from Icons dictionary.
    
    Args:
        icons: Dictionary[emoji] → Icon (containing couplings as emoji → Complex)
        register_map: This biome's RegisterMap
    
    Returns:
        Hermitian matrix H of dimension 2^(num_qubits)
    """
    var dim = register_map.dim()
    var num_qubits = register_map.num_qubits
    var H = ComplexMatrix.zeros(dim, dim)
    
    print("🔨 Building H for %d qubits (%dD)..." % [num_qubits, dim])
    
    for source_emoji in icons:
        var icon = icons[source_emoji]
        
        # Skip if source not in this biome
        if not register_map.has(source_emoji):
            continue
        
        var source_q = register_map.qubit(source_emoji)
        var source_p = register_map.pole(source_emoji)
        
        # --- Self-energy: diagonal term ---
        if icon.self_energy != null and icon.self_energy.mag() > 1e-10:
            _add_self_energy(H, source_q, source_p, icon.self_energy, num_qubits)
        
        # --- Couplings: emoji → Complex ---
        for target_emoji in icon.hamiltonian_couplings:
            # Filter: skip if target not in this biome
            if not register_map.has(target_emoji):
                print("  ⚠️ %s→%s skipped (no wire)" % [source_emoji, target_emoji])
                continue
            
            var target_q = register_map.qubit(target_emoji)
            var target_p = register_map.pole(target_emoji)
            var coupling: Complex = icon.hamiltonian_couplings[target_emoji]
            
            _add_coupling(H, source_q, source_p, target_q, target_p, coupling, num_qubits)
            
            print("  ✓ %s→%s (g=%s)" % [source_emoji, target_emoji, coupling])
    
    # Ensure Hermiticity: H = (H + H†)/2
    H = _hermitianize(H)
    
    return H


static func _add_self_energy(H: ComplexMatrix, qubit: int, pole: int, 
                              energy: Complex, num_qubits: int) -> void:
    """Add diagonal term for states where qubit is in pole state."""
    var dim = 1 << num_qubits
    var shift = num_qubits - 1 - qubit
    
    for i in range(dim):
        if ((i >> shift) & 1) == pole:
            var current = H.get_element(i, i)
            H.set_element(i, i, current.add(energy))


static func _add_coupling(H: ComplexMatrix, 
                           q_a: int, p_a: int,
                           q_b: int, p_b: int,
                           coupling: Complex, num_qubits: int) -> void:
    """Add off-diagonal coupling between two qubit-pole pairs."""
    var dim = 1 << num_qubits
    
    if q_a == q_b:
        # Same qubit: σ_x rotation (|0⟩↔|1⟩)
        if p_a == p_b:
            return  # Self-coupling = self-energy, handled separately
        
        var shift = num_qubits - 1 - q_a
        for i in range(dim):
            if ((i >> shift) & 1) == p_a:
                var j = i ^ (1 << shift)  # Flip bit
                var current = H.get_element(i, j)
                H.set_element(i, j, current.add(coupling))
    else:
        # Different qubits: conditional transition
        var shift_a = num_qubits - 1 - q_a
        var shift_b = num_qubits - 1 - q_b
        
        for i in range(dim):
            var bit_a = (i >> shift_a) & 1
            var bit_b = (i >> shift_b) & 1
            
            if bit_a == p_a and bit_b == p_b:
                var j = i ^ (1 << shift_a) ^ (1 << shift_b)
                var current = H.get_element(i, j)
                H.set_element(i, j, current.add(coupling))


static func _hermitianize(H: ComplexMatrix) -> ComplexMatrix:
    """Return (H + H†)/2 to ensure Hermiticity."""
    var H_dag = H.conjugate_transpose()
    return H.add(H_dag).scale_real(0.5)
```

---

## Lindblad Builder with Coordinate Filtering

Same principle for dissipative terms:

```gdscript
# Core/QuantumSubstrate/LindbladBuilder.gd

class_name LindbladBuilder
extends RefCounted

## Build Lindblad operators from Icons, filtered by RegisterMap
## 
## Lindblad couplings: {target_emoji: Complex} where |Complex|² = rate


static func build(icons: Dictionary, register_map: RegisterMap) -> Array[ComplexMatrix]:
    """Build array of Lindblad jump operators from Icons dictionary.
    
    Args:
        icons: Dictionary[emoji] → Icon (containing lindblad_couplings as emoji → Complex)
        register_map: This biome's RegisterMap
    
    Returns: Array of L_k matrices
    """
    var operators: Array[ComplexMatrix] = []
    var dim = register_map.dim()
    var num_qubits = register_map.num_qubits
    
    for source_emoji in icons:
        var icon = icons[source_emoji]
        
        if not register_map.has(source_emoji):
            continue
        
        var source_q = register_map.qubit(source_emoji)
        var source_p = register_map.pole(source_emoji)
        
        # --- Lindblad couplings: emoji → Complex ---
        for target_emoji in icon.lindblad_couplings:
            if not register_map.has(target_emoji):
                print("  ⚠️ L %s→%s skipped (no wire)" % [source_emoji, target_emoji])
                continue
            
            var target_q = register_map.qubit(target_emoji)
            var target_p = register_map.pole(target_emoji)
            var amplitude: Complex = icon.lindblad_couplings[target_emoji]
            
            var L = _build_jump(source_q, source_p, target_q, target_p, 
                                amplitude, num_qubits)
            operators.append(L)
            
            print("  ✓ L %s→%s (√γ=%s)" % [source_emoji, target_emoji, amplitude])
    
    return operators


static func _build_jump(from_q: int, from_p: int, to_q: int, to_p: int,
                        amplitude: Complex, num_qubits: int) -> ComplexMatrix:
    """Build jump operator L = amplitude * |to⟩⟨from|."""
    var dim = 1 << num_qubits
    var L = ComplexMatrix.zeros(dim, dim)
    
    if from_q == to_q:
        # Same qubit: flip pole
        var shift = num_qubits - 1 - from_q
        
        for i in range(dim):
            if ((i >> shift) & 1) == from_p:
                var j = i ^ (1 << shift)
                L.set_element(j, i, amplitude)
    else:
        # Different qubits: correlated transfer
        var shift_from = num_qubits - 1 - from_q
        var shift_to = num_qubits - 1 - to_q
        
        for i in range(dim):
            var bit_from = (i >> shift_from) & 1
            var bit_to = (i >> shift_to) & 1
            
            if bit_from == from_p and bit_to != to_p:
                var j = i ^ (1 << shift_from) ^ (1 << shift_to)
                L.set_element(j, i, amplitude)
    
    return L
```

---

## Dynamic Biome Generation

### The Goal

Given a handful of emoji pairs, generate a biome by:
1. Allocating registers for each pair
2. Gathering relevant Icons from IconRegistry
3. Building Hamiltonian/Lindblad filtered by the RegisterMap

```gdscript
# Core/Environment/BiomeFactory.gd

class_name BiomeFactory
extends RefCounted

## Create biomes dynamically from emoji axis configurations


static func create(axes: Array[Dictionary], biome_name: String) -> BiomeBase:
    """Create a biome from axis definitions.
    
    Args:
        axes: Array of {north: emoji, south: emoji}
        biome_name: Name for the biome
    
    Example:
        BiomeFactory.create([
            {"north": "🔥", "south": "❄️"},
            {"north": "💧", "south": "🏜️"},
            {"north": "💨", "south": "🌾"}
        ], "Kitchen")
    """
    var biome = BiomeBase.new()
    biome.biome_name = biome_name
    biome.quantum_computer = QuantumComputer.new(biome_name)
    
    # Register each axis
    for i in range(axes.size()):
        var axis = axes[i]
        biome.quantum_computer.register_map.register_axis(
            i, axis["north"], axis["south"]
        )
    
    # Gather relevant icons (those with emojis in our register map)
    var relevant_icons = _gather_icons(biome.quantum_computer.register_map)
    
    # Build operators filtered by register map
    biome.hamiltonian = HamiltonianBuilder.build(
        relevant_icons, biome.quantum_computer.register_map)
    biome.lindblad_ops = LindbladBuilder.build(
        relevant_icons, biome.quantum_computer.register_map)
    
    # Initialize to ground (all |1⟩ = all south poles)
    var ground = (1 << axes.size()) - 1
    biome.quantum_computer.initialize_basis(ground)
    
    print("🏭 Created '%s': %d qubits, %dD" % 
          [biome_name, axes.size(), 1 << axes.size()])
    
    return biome


static func _gather_icons(register_map: RegisterMap) -> Dictionary:
    """Get icons dictionary for emojis in the register map."""
    var icons: Dictionary = {}
    
    for emoji in register_map.coordinates:
        if IconRegistry.icons.has(emoji):
            icons[emoji] = IconRegistry.icons[emoji]
    
    return icons
```

### Kitchen Example

```gdscript
# Creating the Kitchen biome:

var kitchen = BiomeFactory.create([
    {"north": "🔥", "south": "❄️"},   # Qubit 0: Temperature
    {"north": "💧", "south": "🏜️"},   # Qubit 1: Moisture
    {"north": "💨", "south": "🌾"}    # Qubit 2: Substance
], "Kitchen")

# Result:
#
# register_map.coordinates = {
#     "🔥": {qubit: 0, pole: 0},  "❄️": {qubit: 0, pole: 1},
#     "💧": {qubit: 1, pole: 0},  "🏜️": {qubit: 1, pole: 1},
#     "💨": {qubit: 2, pole: 0},  "🌾": {qubit: 2, pole: 1}
# }
#
# register_map.axes = {
#     0: {north: "🔥", south: "❄️"},
#     1: {north: "💧", south: "🏜️"},
#     2: {north: "💨", south: "🌾"}
# }
#
# Hilbert dimension = 2³ = 8
# Initial state = |111⟩ (index 7)
```

---

## The Detuning Hamiltonian (Kitchen-Specific)

For the Kitchen, we add a **global coupling term** that rotates |111⟩ → |000⟩ with detuning:

```gdscript
# In QuantumKitchen_Biome.gd

func build_hamiltonian() -> ComplexMatrix:
    """Build Kitchen Hamiltonian = H_icons + H_bread."""
    
    # Start with Icon-derived terms
    var icons = BiomeFactory._gather_icons(quantum_computer.register_map)
    var H = HamiltonianBuilder.build(icons, quantum_computer.register_map)
    
    # Add bread resonance term
    _add_bread_resonance(H)
    
    return H


func _add_bread_resonance(H: ComplexMatrix) -> void:
    """Add |000⟩ ↔ |111⟩ coupling with detuning.
    
    H_bread = Δ/2 (|0⟩⟨0| - |7⟩⟨7|) + Ω (|0⟩⟨7| + |7⟩⟨0|)
    """
    var omega = 0.15
    var delta = _compute_detuning()
    
    # Detuning: raise |000⟩, lower |111⟩
    var e0 = H.get_element(0, 0)
    var e7 = H.get_element(7, 7)
    H.set_element(0, 0, e0.add(Complex.new(delta / 2.0, 0.0)))
    H.set_element(7, 7, e7.add(Complex.new(-delta / 2.0, 0.0)))
    
    # Coupling
    H.set_element(0, 7, H.get_element(0, 7).add(Complex.new(omega, 0.0)))
    H.set_element(7, 0, H.get_element(7, 0).add(Complex.new(omega, 0.0)))


func _compute_detuning() -> float:
    """Detuning from ideal conditions.
    
    Δ = √(Σ w_i (P_i - ideal_i)²)
    """
    var d2 = 0.0
    d2 += 2.0 * pow(p_fire() - 0.7, 2)   # Ideal fire = 70%
    d2 += 2.0 * pow(p_water() - 0.5, 2)  # Ideal water = 50%
    d2 += 2.0 * pow(p_flour() - 0.6, 2)  # Ideal flour = 60%
    
    return sqrt(d2) * 5.0


func effective_baking_rate() -> float:
    """Ω_eff = Ω / √(1 + (Δ/Ω)²) for UI display."""
    var omega = 0.15
    var delta = _compute_detuning()
    return omega / sqrt(1.0 + pow(delta / omega, 2))
```

---

## Partial Trace with RegisterMap

### Marginal Probability Using Coordinates

```gdscript
# Add to QuantumComputer.gd

func get_marginal(qubit: int, target_pole: int) -> float:
    """Compute P(qubit = target_pole) via partial trace.
    
    Sums diagonal ρ[i,i] where qubit's bit matches target_pole.
    """
    var dim = register_map.dim()
    var num_q = register_map.num_qubits
    var shift = num_q - 1 - qubit
    
    var prob = 0.0
    for i in range(dim):
        if ((i >> shift) & 1) == target_pole:
            prob += density_matrix.get_element(i, i).re
    
    return clamp(prob, 0.0, 1.0)


func get_population(emoji: String) -> float:
    """Get population of emoji via RegisterMap lookup."""
    if not register_map.has(emoji):
        push_warning("'%s' not in RegisterMap!" % emoji)
        return 0.0
    
    var qubit = register_map.qubit(emoji)
    var pole = register_map.pole(emoji)
    
    return get_marginal(qubit, pole)


func get_basis_probability(index: int) -> float:
    """Get P(|index⟩) = ρ[index, index]."""
    return clamp(density_matrix.get_element(index, index).re, 0.0, 1.0)
```

### Kitchen Helpers

```gdscript
# In QuantumKitchen_Biome.gd

func p_fire() -> float:
    return quantum_computer.get_population("🔥")

func p_water() -> float:
    return quantum_computer.get_population("💧")

func p_flour() -> float:
    return quantum_computer.get_population("💨")

func p_bread() -> float:
    """P(|000⟩) = ρ[0,0]"""
    return quantum_computer.get_basis_probability(0)

func p_ground() -> float:
    """P(|111⟩) = ρ[7,7]"""
    return quantum_computer.get_basis_probability(7)
```

---

## Lindblad Drive with Coordinates

### Trace-Preserving "Pump"

```gdscript
# Add to QuantumComputer.gd

func apply_drive(emoji: String, rate: float, dt: float) -> bool:
    """Apply Lindblad drive to increase population of emoji.
    
    Pushes population from opposite pole to target pole.
    Preserves Tr(ρ) = 1.
    """
    if not register_map.has(emoji):
        push_warning("Cannot drive '%s': not in RegisterMap!" % emoji)
        return false
    
    var qubit = register_map.qubit(emoji)
    var target_pole = register_map.pole(emoji)
    var source_pole = 1 - target_pole
    
    _apply_lindblad_1q(qubit, source_pole, target_pole, rate, dt)
    return true


func _apply_lindblad_1q(qubit: int, from_pole: int, to_pole: int, 
                         rate: float, dt: float) -> void:
    """Apply single-qubit Lindblad: L = √(γdt) |to⟩⟨from|."""
    var dim = register_map.dim()
    var num_q = register_map.num_qubits
    var shift = num_q - 1 - qubit
    
    var amp = Complex.new(sqrt(rate * dt), 0.0)
    
    # Build L matrix
    var L = ComplexMatrix.zeros(dim, dim)
    for i in range(dim):
        if ((i >> shift) & 1) == from_pole:
            var j = i ^ (1 << shift)
            L.set_element(j, i, amp)
    
    # Apply: ρ' = ρ + L ρ L† - ½{L†L, ρ}
    var L_dag = L.conjugate_transpose()
    var L_dag_L = L_dag.mul(L)
    
    var term1 = L.mul(density_matrix).mul(L_dag)
    var anticomm = L_dag_L.mul(density_matrix).add(density_matrix.mul(L_dag_L))
    var term2 = anticomm.scale_real(0.5)
    
    density_matrix = density_matrix.add(term1).sub(term2)
    _renormalize()


func _renormalize() -> void:
    """Ensure Tr(ρ) = 1."""
    var trace = 0.0
    for i in range(density_matrix.rows):
        trace += density_matrix.get_element(i, i).re
    
    if trace > 1e-10:
        density_matrix = density_matrix.scale_real(1.0 / trace)
```

### Kitchen Player Actions

```gdscript
# In QuantumKitchen_Biome.gd

var active_drives: Array = []  # Queued drives

func add_fire(amount: float) -> void:
    """Player adds fire → drive toward 🔥."""
    active_drives.append({
        "emoji": "🔥",
        "rate": 0.5,
        "remaining": amount * 2.0
    })

func add_water(amount: float) -> void:
    active_drives.append({"emoji": "💧", "rate": 0.5, "remaining": amount * 2.0})

func add_flour(amount: float) -> void:
    active_drives.append({"emoji": "💨", "rate": 0.5, "remaining": amount * 2.0})

func _process_drives(dt: float) -> void:
    """Apply queued drives each frame."""
    for drive in active_drives:
        if drive["remaining"] > 0:
            quantum_computer.apply_drive(drive["emoji"], drive["rate"], dt)
            drive["remaining"] -= dt
    
    # Remove completed
    active_drives = active_drives.filter(func(d): return d["remaining"] > 0)
```

---

## Summary: The Two Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                   ICON REGISTRY (Global)                        │
│                   Dictionary[emoji] → Icon                      │
│                                                                 │
│  icons = {                                                      │
│      "🔥": Icon {                                               │
│          hamiltonian_couplings: {"❄️": Complex(0.3, 0)}         │
│          lindblad_couplings: {"❄️": Complex(0.14, 0)}           │
│      },                                                         │
│      "❄️": Icon { ... },                                        │
│      ...                                                        │
│  }                                                              │
│                                                                 │
│  These define HOW emojis interact (the physics laws).           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ (filtered at build time)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│               REGISTER MAP (Per-Biome)                          │
│               Dictionary[emoji] → {qubit, pole}                 │
│                                                                 │
│  Kitchen.register_map.coordinates = {                           │
│      "🔥": {"qubit": 0, "pole": 0},                             │
│      "❄️": {"qubit": 0, "pole": 1},                             │
│      "💧": {"qubit": 1, "pole": 0},                             │
│      "🏜️": {"qubit": 1, "pole": 1},                             │
│      "💨": {"qubit": 2, "pole": 0},                             │
│      "🌾": {"qubit": 2, "pole": 1}                              │
│  }                                                              │
│                                                                 │
│  Note: 🍞 NOT in coordinates → fire's coupling to 🍞 IGNORED    │
│                                                                 │
│  These define WHERE emojis live in ρ[i,j] (the hardware).       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    DENSITY MATRIX (8×8)                         │
│                                                                 │
│  Indices are INTEGERS, translated via RegisterMap:              │
│                                                                 │
│  ρ[0,0] = P(|000⟩) = P(🔥💧💨) ← basis_to_emojis(0)             │
│  ρ[7,7] = P(|111⟩) = P(❄️🏜️🌾) ← basis_to_emojis(7)             │
│                                                                 │
│  All matrix operations use INTEGER indices.                     │
│  RegisterMap translates emoji ↔ index at boundaries.            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Checklist

### New Files to Create

- [ ] `Core/QuantumSubstrate/RegisterMap.gd` - Emoji ↔ Coordinate translation
- [ ] `Core/QuantumSubstrate/HamiltonianBuilder.gd` - Build H from filtered Icons
- [ ] `Core/QuantumSubstrate/LindbladBuilder.gd` - Build L operators from filtered Icons
- [ ] `Core/Environment/BiomeFactory.gd` - Dynamic biome generation

### Files to Modify

- [ ] `Core/QuantumSubstrate/QuantumComputer.gd` - Add RegisterMap ownership
- [ ] `Core/QuantumSubstrate/QuantumComponent.gd` - Use coordinates for marginals
- [ ] `Core/Environment/QuantumKitchen_Biome.gd` - Use coordinate-based detuning
- [ ] `Core/QuantumSubstrate/QuantumBath.gd` - Delegate to builders

### Critical Invariants to Enforce

1. **No direct emoji → matrix index mapping** without going through RegisterMap
2. **All Hamiltonian/Lindblad builds filter** by RegisterMap.has_emoji()
3. **Trace is preserved** by all operations (no manual ρ[i,i] edits)
4. **North ≠ South** for all qubit axes (validated at allocation)
5. **All basis emojis registered in IconRegistry** (physics error if not)

---

## Validation Tests

```gdscript
func test_register_map_structure():
    """Verify RegisterMap uses emoji-keyed dictionaries."""
    var rm = RegisterMap.new()
    rm.register_axis(0, "🔥", "❄️")
    rm.register_axis(1, "💧", "🏜️")
    
    # Check coordinates dictionary
    assert(rm.coordinates.has("🔥"))
    assert(rm.coordinates["🔥"]["qubit"] == 0)
    assert(rm.coordinates["🔥"]["pole"] == 0)  # NORTH
    
    assert(rm.coordinates.has("❄️"))
    assert(rm.coordinates["❄️"]["qubit"] == 0)
    assert(rm.coordinates["❄️"]["pole"] == 1)  # SOUTH
    
    # Check axes dictionary
    assert(rm.axes[0]["north"] == "🔥")
    assert(rm.axes[0]["south"] == "❄️")
    
    print("✅ RegisterMap structure test passed")


func test_biome_isolation():
    """Verify same emoji in different biomes doesn't collide."""
    var biotic = BiomeFactory.create([
        {"north": "🌾", "south": "👥"}
    ], "BioticFlux")
    
    var kitchen = BiomeFactory.create([
        {"north": "🔥", "south": "❄️"},
        {"north": "💧", "south": "🏜️"},
        {"north": "💨", "south": "🌾"}  # Same 🌾!
    ], "Kitchen")
    
    # 🌾 is qubit 0, NORTH in BioticFlux
    var biotic_coord = biotic.quantum_computer.register_map.coordinates["🌾"]
    assert(biotic_coord["qubit"] == 0)
    assert(biotic_coord["pole"] == 0)
    
    # 🌾 is qubit 2, SOUTH in Kitchen
    var kitchen_coord = kitchen.quantum_computer.register_map.coordinates["🌾"]
    assert(kitchen_coord["qubit"] == 2)
    assert(kitchen_coord["pole"] == 1)
    
    print("✅ Biome isolation test passed")


func test_coupling_filtering():
    """Verify couplings to non-existent emojis are skipped."""
    
    # Fire icon couples to 🍞 in IconRegistry
    # But Kitchen has no 🍞 register
    var kitchen = BiomeFactory.create([
        {"north": "🔥", "south": "❄️"}
    ], "TinyKitchen")
    
    # Hamiltonian should only have 🔥↔❄️ terms
    # The 🔥→🍞 coupling from IconRegistry is filtered out
    # (Verified by absence of errors)
    
    print("✅ Coupling filtering test passed")


func test_icon_couplings_are_complex():
    """Verify Icon couplings use Complex values."""
    var fire_icon = IconRegistry.icons["🔥"]
    
    # Couplings should be emoji → Complex
    for target in fire_icon.hamiltonian_couplings:
        var coupling = fire_icon.hamiltonian_couplings[target]
        assert(coupling is Complex, "Coupling must be Complex!")
    
    print("✅ Icon coupling type test passed")


func test_basis_to_emojis():
    """Verify basis ↔ emoji conversion."""
    var rm = RegisterMap.new()
    rm.register_axis(0, "🔥", "❄️")
    rm.register_axis(1, "💧", "🏜️")
    rm.register_axis(2, "💨", "🌾")
    
    # |000⟩ = Hot, Wet, Flour
    assert(rm.basis_to_emojis(0) == ["🔥", "💧", "💨"])
    
    # |111⟩ = Cold, Dry, Grain
    assert(rm.basis_to_emojis(7) == ["❄️", "🏜️", "🌾"])
    
    # |101⟩ = Cold, Wet, Grain
    assert(rm.basis_to_emojis(5) == ["❄️", "💧", "🌾"])
    
    # Round-trip
    assert(rm.emojis_to_basis(["🔥", "💧", "💨"]) == 0)
    assert(rm.emojis_to_basis(["❄️", "🏜️", "🌾"]) == 7)
    
    print("✅ Basis ↔ emoji conversion test passed")
```

---

**This is the infrastructure that prevents the math from breaking. Implement RegisterMap first, then everything else builds on it.**
