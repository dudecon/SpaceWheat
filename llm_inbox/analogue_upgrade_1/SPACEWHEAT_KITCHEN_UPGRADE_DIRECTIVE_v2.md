# 🍞 SpaceWheat Kitchen Pipeline: Upgrade Directive v2

**Version**: 2.0 (Corrected Quantum Mechanics)
**Date**: 2026-01-05
**Status**: READY FOR IMPLEMENTATION
**Scope**: Complete kitchen gameplay loop via proper 8D quantum dynamics

---

## Critical Corrections from v1

| v1 (Wrong) | v2 (Correct) |
|------------|--------------|
| Emojis as dimensions | Emojis as basis labels on qubit axes |
| "Population of 🔥 = 0.7" | Marginal probability via partial trace |
| "Pump population" | Lindblad drive operators (preserve Tr(ρ)=1) |
| Bread as separate Icon/dimension | Bread = measurement outcome P(\|000⟩) |
| Gaussian on emoji populations | Detuning in Hamiltonian |
| 6+ emojis = 64+ dimensions | 3 qubits = 8 dimensions exactly |

---

## Executive Summary

The Kitchen is a **3-qubit quantum system** with an **8-dimensional Hilbert space**. Each qubit represents an **axis** (not an emoji), and the player's goal is to drive the system from the ground state |111⟩ to the bread-ready state |000⟩.

### The Three Axes

| Qubit | Axis | \|0⟩ (North) | \|1⟩ (South) | Physical Meaning |
|-------|------|--------------|--------------|------------------|
| 0 | Temperature | 🔥 Hot | ❄️ Cold | Heat level in oven |
| 1 | Moisture | 💧 Wet | 🏜️ Dry | Water content in dough |
| 2 | Substance | 💨 Flour | 🌾 Grain | Processing level |

### The 8 Basis States

```
Index  Binary   State      Emojis      Meaning
─────────────────────────────────────────────────
  0    |000⟩   🔥💧💨    Hot,Wet,Flour    "Bread Ready" ← TARGET
  1    |001⟩   🔥💧🌾    Hot,Wet,Grain    
  2    |010⟩   🔥🏜️💨    Hot,Dry,Flour    
  3    |011⟩   🔥🏜️🌾    Hot,Dry,Grain    
  4    |100⟩   ❄️💧💨    Cold,Wet,Flour   
  5    |101⟩   ❄️💧🌾    Cold,Wet,Grain   
  6    |110⟩   ❄️🏜️💨    Cold,Dry,Flour   
  7    |111⟩   ❄️🏜️🌾    Cold,Dry,Grain   "Ground State" ← START
```

### Where Is Bread?

**Bread is NOT a dimension.** Bread is the measurement outcome when the system is found in |000⟩:

```
P(🍞) = P(|000⟩) = ρ[0,0] = ⟨000|ρ|000⟩

Measurement → collapse:
  - If collapse to |000⟩ → Player gets 🍞
  - If collapse to other → Player gets 💀 (failed bake)
```

---

## Part 1: The "Two Wheats" Problem

### Problem Statement

🌾 appears in TWO places:
- BioticFlux: Register with 🌾/👥 (wheat/labor axis)
- Kitchen: Register with 💨/🌾 (flour/grain axis)

### Solution: Biome Isolation + Classical Bridge

Each biome owns its own `QuantumComputer`. The same emoji can appear in multiple biomes without collision because they're in **separate Hilbert spaces**.

```
BioticFlux.quantum_computer:
  ρ_biotic ∈ ℂ^(2^n × 2^n)  where n = planted plots
  🌾 here means "wheat crop ready to harvest"

Kitchen.quantum_computer:
  ρ_kitchen ∈ ℂ^(8×8)  (always 3 qubits)
  🌾 here means "unprocessed grain in the dough"
```

**The Bridge**: Classical economy

```
1. Player harvests wheat in BioticFlux
   → Quantum state collapses
   → Classical "wheat credits" added to economy
   
2. Player "adds wheat" to Kitchen
   → Economy credits consumed
   → Lindblad drive activated on Kitchen's substance axis
   → Population flows |1⟩ → |0⟩ on qubit 2 (grain → flour)
```

### Guardrail: Global Resource ID

```gdscript
# In FarmEconomy or ResourceRegistry
const RESOURCE_IDS = {
    "🌾": "wheat",      # Same ID regardless of which biome
    "💨": "flour",
    "🔥": "fire",
    "💧": "water",
    "🍞": "bread"
}

# When harvesting BioticFlux wheat:
economy.add_resource(RESOURCE_IDS["🌾"], amount)

# When spending wheat in Kitchen:
economy.remove_resource(RESOURCE_IDS["🌾"], amount)
# This activates the Lindblad drive on Kitchen qubit 2
```

---

## Part 2: Quantum Namespace Guardrails

### Guardrail A: Unique Register IDs

In `QuantumComputer.gd`, every register must be unique within a biome:

```gdscript
func allocate_register(north_emoji: String, south_emoji: String) -> int:
    # Generate unique ID
    var reg_id = _next_register_id
    _next_register_id += 1
    
    # Validate uniqueness
    assert(not register_to_component.has(reg_id), 
           "Register ID collision: %d" % reg_id)
    
    # ... rest of allocation
    return reg_id
```

### Guardrail B: Basis Validation

North and south poles must be different:

```gdscript
func allocate_register(north_emoji: String, south_emoji: String) -> int:
    # CRITICAL: Basis states must be orthogonal
    assert(north_emoji != south_emoji,
           "Invalid qubit basis: north=%s south=%s (must differ!)" % 
           [north_emoji, south_emoji])
    
    # Validate both emojis exist in registry
    assert(IconRegistry.has_icon(north_emoji),
           "North emoji %s not in IconRegistry!" % north_emoji)
    assert(IconRegistry.has_icon(south_emoji),
           "South emoji %s not in IconRegistry!" % south_emoji)
    
    # ... rest of allocation
```

### Guardrail C: Icon Registry as Source of Truth

Every emoji used as a basis label MUST have a corresponding Icon:

```gdscript
# In BiomeBase.allocate_register_for_plot()
func allocate_register_for_plot(position: Vector2i, north: String, south: String) -> int:
    # Physics error if icons missing
    if not IconRegistry.has_icon(north):
        push_error("PHYSICS ERROR: Icon '%s' not registered!" % north)
        return -1
    if not IconRegistry.has_icon(south):
        push_error("PHYSICS ERROR: Icon '%s' not registered!" % south)
        return -1
    
    return quantum_computer.allocate_register(north, south)
```

---

## Part 3: Partial Trace (Actual Quantum Math)

### The Problem

To answer "how hot is the kitchen?" we need the **marginal probability** of qubit 0 being in |0⟩. This requires summing over all basis states where qubit 0 = 0.

### Implementation

Add to `Core/QuantumSubstrate/QuantumComponent.gd` or `QuantumBath.gd`:

```gdscript
func get_marginal_probability(qubit_index: int, target_state: int = 0) -> float:
    """Compute P(qubit_i = target_state) via partial trace.
    
    For a 3-qubit system (dim=8):
      P(qubit 0 = 0) = ρ[0,0] + ρ[1,1] + ρ[2,2] + ρ[3,3]
      P(qubit 1 = 0) = ρ[0,0] + ρ[1,1] + ρ[4,4] + ρ[5,5]
      P(qubit 2 = 0) = ρ[0,0] + ρ[2,2] + ρ[4,4] + ρ[6,6]
    
    Args:
        qubit_index: Which qubit (0, 1, or 2 for Kitchen)
        target_state: 0 for north/|0⟩, 1 for south/|1⟩
    
    Returns:
        Probability in [0, 1]
    """
    var rho = ensure_density_matrix()
    var dim = rho.rows  # 8 for 3-qubit
    var num_qubits = int(log(dim) / log(2))  # 3
    
    var prob = 0.0
    
    for basis_idx in range(dim):
        # Extract bit at qubit_index position
        # For qubit 0 (leftmost), shift by (num_qubits - 1 - 0) = 2
        # For qubit 2 (rightmost), shift by (num_qubits - 1 - 2) = 0
        var shift = num_qubits - 1 - qubit_index
        var bit = (basis_idx >> shift) & 1
        
        if bit == target_state:
            # Add diagonal element ρ[i,i]
            prob += rho.get_element(basis_idx, basis_idx).real
    
    return clamp(prob, 0.0, 1.0)


func get_basis_probability(basis_index: int) -> float:
    """Get probability of specific basis state.
    
    For Kitchen:
      get_basis_probability(0) = P(|000⟩) = P(🍞 ready)
      get_basis_probability(7) = P(|111⟩) = P(ground state)
    """
    var rho = ensure_density_matrix()
    return clamp(rho.get_element(basis_index, basis_index).real, 0.0, 1.0)
```

### Kitchen-Specific Helpers

```gdscript
# In QuantumKitchen_Biome.gd

func get_temperature_hot() -> float:
    """P(qubit 0 = |0⟩) = probability oven is hot (🔥)"""
    return kitchen_component.get_marginal_probability(0, 0)

func get_temperature_cold() -> float:
    """P(qubit 0 = |1⟩) = probability oven is cold (❄️)"""
    return kitchen_component.get_marginal_probability(0, 1)

func get_moisture_wet() -> float:
    """P(qubit 1 = |0⟩) = probability dough is wet (💧)"""
    return kitchen_component.get_marginal_probability(1, 0)

func get_moisture_dry() -> float:
    """P(qubit 1 = |1⟩) = probability dough is dry (🏜️)"""
    return kitchen_component.get_marginal_probability(1, 1)

func get_substance_flour() -> float:
    """P(qubit 2 = |0⟩) = probability substance is flour (💨)"""
    return kitchen_component.get_marginal_probability(2, 0)

func get_substance_grain() -> float:
    """P(qubit 2 = |1⟩) = probability substance is grain (🌾)"""
    return kitchen_component.get_marginal_probability(2, 1)

func get_bread_probability() -> float:
    """P(|000⟩) = probability of successful bread measurement"""
    return kitchen_component.get_basis_probability(0)

func get_ground_probability() -> float:
    """P(|111⟩) = probability still in ground state"""
    return kitchen_component.get_basis_probability(7)
```

---

## Part 4: Lindblad Drives (Not "Pumps")

### The Problem

You cannot "set population = 0.7" — that violates Tr(ρ) = 1.

### The Solution: Lindblad Jump Operators

When the player "adds fire" to the Kitchen, they activate a **drive operator** that transfers amplitude:

```
L_drive = √γ |target⟩⟨source|

For "add fire" (push cold → hot on qubit 0):
  L = √γ |0⟩⟨1| ⊗ I ⊗ I

This acts on the 8×8 density matrix as:
  dρ/dt = γ (L ρ L† - ½{L†L, ρ})
```

### Implementation

Add to `QuantumComponent.gd`:

```gdscript
func apply_lindblad_drive(qubit_index: int, target_state: int, rate: float, dt: float) -> void:
    """Apply Lindblad drive to push population on one axis.
    
    Transfers amplitude from |1-target⟩ to |target⟩ on specified qubit.
    Preserves Tr(ρ) = 1.
    
    Args:
        qubit_index: Which qubit to drive (0, 1, or 2)
        target_state: 0 to push toward |0⟩, 1 to push toward |1⟩
        rate: Drive strength γ (probability/second)
        dt: Time step
    
    Physics:
        L = √γ |target⟩⟨source| ⊗ I_other
        dρ = dt * (L ρ L† - ½{L†L, ρ})
    """
    var rho = ensure_density_matrix()
    var dim = rho.rows
    var num_qubits = int(log(dim) / log(2))
    
    var source_state = 1 - target_state
    var gamma = rate * dt  # Effective rate for this timestep
    var sqrt_gamma = sqrt(gamma)
    
    # Build the jump operator L embedded in full Hilbert space
    var L = _build_embedded_jump_operator(qubit_index, target_state, source_state, 
                                           sqrt_gamma, num_qubits)
    var L_dag = L.conjugate_transpose()
    var L_dag_L = L_dag.mul(L)
    
    # Lindblad evolution: ρ' = ρ + (L ρ L† - ½{L†L, ρ})
    var term1 = L.mul(rho).mul(L_dag)                           # L ρ L†
    var anticomm = L_dag_L.mul(rho).add(rho.mul(L_dag_L))       # {L†L, ρ}
    var term2 = anticomm.scale(Complex.new(0.5, 0.0))           # ½{L†L, ρ}
    
    density_matrix = rho.add(term1).sub(term2)
    
    # Renormalize for numerical stability
    _renormalize_trace()


func _build_embedded_jump_operator(qubit_idx: int, target: int, source: int, 
                                    amplitude: float, num_qubits: int) -> ComplexMatrix:
    """Build L = amplitude * |target⟩⟨source| ⊗ I_other
    
    For 3 qubits, this creates an 8×8 matrix where the jump
    operator acts on qubit_idx and identity acts on others.
    """
    var dim = 1 << num_qubits  # 2^num_qubits
    var L = ComplexMatrix.zeros(dim, dim)
    
    var shift = num_qubits - 1 - qubit_idx
    
    for i in range(dim):
        # Check if qubit at qubit_idx is in source state
        var bit_i = (i >> shift) & 1
        if bit_i == source:
            # Compute target index (flip the bit at qubit_idx)
            var j = i ^ (1 << shift)
            L.set_element(j, i, Complex.new(amplitude, 0.0))
    
    return L


func _renormalize_trace() -> void:
    """Ensure Tr(ρ) = 1 after numerical operations."""
    var trace = Complex.zero()
    for i in range(density_matrix.rows):
        trace = trace.add(density_matrix.get_element(i, i))
    
    if trace.real > 1e-10:
        var scale = Complex.new(1.0 / trace.real, 0.0)
        density_matrix = density_matrix.scale(scale)
```

### Player Action → Lindblad Drive

```gdscript
# In QuantumKitchen_Biome.gd

func add_fire(amount: float) -> void:
    """Player adds fire → activates temperature drive toward hot.
    
    Amount controls drive duration/strength.
    """
    var rate = 0.5  # Base drive rate (probability/second)
    var duration = amount * 2.0  # Seconds of driving
    
    # Queue the drive (will be applied over multiple frames)
    active_drives.append({
        "qubit": 0,           # Temperature axis
        "target": 0,          # Push toward |0⟩ (hot)
        "rate": rate,
        "remaining": duration
    })
    
    print("🔥 Fire drive activated: %.1f seconds" % duration)


func add_water(amount: float) -> void:
    """Player adds water → activates moisture drive toward wet."""
    active_drives.append({
        "qubit": 1,           # Moisture axis
        "target": 0,          # Push toward |0⟩ (wet)
        "rate": 0.5,
        "remaining": amount * 2.0
    })
    print("💧 Water drive activated")


func add_flour(amount: float) -> void:
    """Player adds flour → activates substance drive toward flour."""
    active_drives.append({
        "qubit": 2,           # Substance axis
        "target": 0,          # Push toward |0⟩ (flour)
        "rate": 0.5,
        "remaining": amount * 2.0
    })
    print("💨 Flour drive activated")


func _process_drives(dt: float) -> void:
    """Apply active Lindblad drives each frame."""
    var completed = []
    
    for drive in active_drives:
        if drive["remaining"] <= 0:
            completed.append(drive)
            continue
        
        # Apply drive for this timestep
        kitchen_component.apply_lindblad_drive(
            drive["qubit"],
            drive["target"],
            drive["rate"],
            dt
        )
        
        drive["remaining"] -= dt
    
    # Remove completed drives
    for drive in completed:
        active_drives.erase(drive)
```

---

## Part 5: Detuning Hamiltonian (The "Sweet Spot")

### The Physics

The Kitchen Hamiltonian drives coherent rotation from |111⟩ (ground) to |000⟩ (bread-ready). But this rotation is **suppressed by detuning** when conditions are wrong.

```
H = Δ/2 (|000⟩⟨000| - |111⟩⟨111|) + Ω (|000⟩⟨111| + |111⟩⟨000|)

Where:
  Ω = coupling strength (constant)
  Δ = detuning (depends on current populations)

Effective rotation rate:
  Ω_eff = Ω / √(1 + (Δ/Ω)²)

At resonance (Δ=0): Ω_eff = Ω (maximum rotation)
Off resonance (|Δ| >> Ω): Ω_eff ≈ 0 (rotation suppressed)
```

### Computing Detuning from Marginals

The "sweet spot" is when all three axes are near their ideal |0⟩ probabilities:

```gdscript
func compute_detuning() -> float:
    """Compute detuning Δ based on how far from ideal conditions.
    
    Ideal: P(🔥)≈0.7, P(💧)≈0.5, P(💨)≈0.6
    
    Detuning increases as populations deviate from ideal.
    """
    var p_fire = get_temperature_hot()
    var p_water = get_moisture_wet()
    var p_flour = get_substance_flour()
    
    # Ideal target populations (the "sweet spot")
    var ideal_fire = 0.7
    var ideal_water = 0.5
    var ideal_flour = 0.6
    
    # Detuning = weighted sum of squared deviations
    var delta = 0.0
    delta += pow(p_fire - ideal_fire, 2) * 2.0
    delta += pow(p_water - ideal_water, 2) * 2.0
    delta += pow(p_flour - ideal_flour, 2) * 2.0
    
    # Scale to reasonable Hamiltonian units
    delta = sqrt(delta) * 5.0
    
    return delta
```

### Building the Hamiltonian

```gdscript
func build_kitchen_hamiltonian() -> ComplexMatrix:
    """Build the Kitchen Hamiltonian with detuning.
    
    H = Δ/2 (|000⟩⟨000| - |111⟩⟨111|) + Ω (|000⟩⟨111| + h.c.)
    
    Returns: 8×8 Hermitian matrix
    """
    var H = ComplexMatrix.zeros(8, 8)
    
    # Base coupling strength
    var omega = 0.15
    
    # Compute current detuning
    var delta = compute_detuning()
    
    # Diagonal terms: energy of |000⟩ and |111⟩
    H.set_element(0, 0, Complex.new(delta / 2.0, 0.0))   # |000⟩ raised
    H.set_element(7, 7, Complex.new(-delta / 2.0, 0.0)) # |111⟩ lowered
    
    # Off-diagonal coupling: |000⟩ ↔ |111⟩
    H.set_element(0, 7, Complex.new(omega, 0.0))  # |000⟩⟨111|
    H.set_element(7, 0, Complex.new(omega, 0.0))  # |111⟩⟨000|
    
    return H


func get_effective_baking_rate() -> float:
    """Compute effective rotation rate Ω_eff for UI display.
    
    Shows player how "in tune" the kitchen is.
    """
    var omega = 0.15
    var delta = compute_detuning()
    
    # Ω_eff = Ω / √(1 + (Δ/Ω)²)
    var omega_eff = omega / sqrt(1.0 + pow(delta / omega, 2))
    
    return omega_eff
```

### Hamiltonian Evolution

```gdscript
func evolve_kitchen(dt: float) -> void:
    """Evolve Kitchen quantum state under Hamiltonian + Lindblad.
    
    Called each frame from _process().
    """
    # 1. Apply any active Lindblad drives (player actions)
    _process_drives(dt)
    
    # 2. Build current Hamiltonian (detuning depends on state)
    var H = build_kitchen_hamiltonian()
    
    # 3. Unitary evolution: ρ' = exp(-iHt) ρ exp(iHt)
    kitchen_component.apply_hamiltonian_evolution(H, dt)
    
    # 4. Natural dissipation (everything slowly decays toward |111⟩)
    _apply_natural_decay(dt)
    
    # 5. Debug output
    if OS.get_environment("DEBUG_KITCHEN") == "1":
        print("Kitchen: P(🍞)=%.3f, Δ=%.3f, Ω_eff=%.3f" % [
            get_bread_probability(),
            compute_detuning(),
            get_effective_baking_rate()
        ])
```

---

## Part 6: Kitchen Initialization

### Setting Up the 3-Qubit System

```gdscript
# In QuantumKitchen_Biome.gd

var kitchen_component: QuantumComponent = null
var active_drives: Array = []

func _initialize_bath() -> void:
    """Initialize Kitchen as exactly 3 qubits (8D Hilbert space).
    
    Registers:
      0: Temperature (🔥/❄️)
      1: Moisture (💧/🏜️)
      2: Substance (💨/🌾)
    
    Initial state: |111⟩ (cold, dry, grain)
    """
    # Create quantum computer for this biome
    quantum_computer = QuantumComputer.new("Kitchen")
    
    # Allocate exactly 3 registers
    var temp_reg = quantum_computer.allocate_register("🔥", "❄️")
    var moist_reg = quantum_computer.allocate_register("💧", "🏜️")
    var subst_reg = quantum_computer.allocate_register("💨", "🌾")
    
    print("🍳 Kitchen registers allocated: temp=%d, moist=%d, subst=%d" % 
          [temp_reg, moist_reg, subst_reg])
    
    # Merge all three into single component (creates 8D space)
    var comp_0 = quantum_computer.get_component_containing(temp_reg)
    var comp_1 = quantum_computer.get_component_containing(moist_reg)
    var comp_2 = quantum_computer.get_component_containing(subst_reg)
    
    var comp_01 = quantum_computer.merge_components(comp_0, comp_1)
    kitchen_component = quantum_computer.merge_components(comp_01, comp_2)
    
    # Verify dimension
    assert(kitchen_component.hilbert_dimension() == 8,
           "Kitchen must be 8D! Got %d" % kitchen_component.hilbert_dimension())
    
    # Initialize to |111⟩ (ground state: cold, dry, grain)
    kitchen_component.initialize_to_basis_state(7)
    
    print("🍳 Kitchen initialized: 8D quantum state, starting in |111⟩ (❄️🏜️🌾)")


func reset_to_ground_state() -> void:
    """Reset Kitchen to |111⟩ after measurement."""
    kitchen_component.initialize_to_basis_state(7)
    active_drives.clear()
    print("🍳 Kitchen reset to ground state |111⟩")
```

### Component Helper Methods

Add to `QuantumComponent.gd`:

```gdscript
func initialize_to_basis_state(basis_index: int) -> void:
    """Initialize to pure basis state |i⟩.
    
    Creates density matrix ρ = |i⟩⟨i|
    """
    var dim = hilbert_dimension()
    assert(basis_index >= 0 and basis_index < dim,
           "Invalid basis index %d for dimension %d" % [basis_index, dim])
    
    # Pure state: ρ = |i⟩⟨i|
    density_matrix = ComplexMatrix.zeros(dim, dim)
    density_matrix.set_element(basis_index, basis_index, Complex.one())
    
    is_pure = true


func apply_hamiltonian_evolution(H: ComplexMatrix, dt: float) -> void:
    """Apply unitary evolution: ρ' = U ρ U† where U = exp(-iHt).
    
    Uses first-order approximation for small dt:
      U ≈ I - iHdt
      ρ' ≈ ρ - i[H, ρ]dt
    """
    var rho = ensure_density_matrix()
    
    # Commutator [H, ρ] = Hρ - ρH
    var H_rho = H.mul(rho)
    var rho_H = rho.mul(H)
    var commutator = H_rho.sub(rho_H)
    
    # ρ' = ρ - i[H,ρ]dt
    var i_dt = Complex.new(0.0, -dt)
    var delta_rho = commutator.scale(i_dt)
    
    density_matrix = rho.add(delta_rho)
    
    # Renormalize and ensure Hermiticity
    _enforce_density_matrix_properties()


func _enforce_density_matrix_properties() -> void:
    """Ensure ρ is Hermitian, positive semi-definite, trace 1."""
    # Hermiticity: ρ = (ρ + ρ†)/2
    var rho_dag = density_matrix.conjugate_transpose()
    density_matrix = density_matrix.add(rho_dag).scale(Complex.new(0.5, 0.0))
    
    # Normalize trace
    _renormalize_trace()
    
    # Note: Full positive semi-definiteness check is expensive
    # For gameplay, trace normalization is usually sufficient
```

---

## Part 7: Measurement (Harvest)

### Projective Measurement

```gdscript
# In QuantumKitchen_Biome.gd

func harvest() -> Dictionary:
    """Perform projective measurement on Kitchen state.
    
    Measurement in computational basis:
      - Collapses to one of 8 basis states
      - P(|i⟩) = ρ[i,i]
    
    Returns:
      {
        success: bool,
        outcome: String ("🍞" or "💀"),
        basis_state: int (0-7),
        bread_amount: int
      }
    """
    var rho = kitchen_component.ensure_density_matrix()
    
    # Sample from probability distribution
    var roll = randf()
    var cumulative = 0.0
    var outcome_state = 7  # Default to ground if numerical issues
    
    for i in range(8):
        cumulative += rho.get_element(i, i).real
        if roll < cumulative:
            outcome_state = i
            break
    
    # Collapse to measured state
    kitchen_component.initialize_to_basis_state(outcome_state)
    
    # Determine outcome
    var result = {
        "success": true,
        "basis_state": outcome_state,
        "outcome": "",
        "bread_amount": 0
    }
    
    if outcome_state == 0:
        # |000⟩ = 🔥💧💨 = Perfect bread!
        result["outcome"] = "🍞"
        result["bread_amount"] = 100  # Full bread
        print("🍞 BREAD! Measured |000⟩ (Hot, Wet, Flour)")
    elif outcome_state in [1, 2, 4]:
        # One bit wrong - partial success
        result["outcome"] = "🍞"
        result["bread_amount"] = 50  # Half bread
        print("🍞 Partial bread: measured |%s⟩" % _basis_to_string(outcome_state))
    else:
        # Two or more bits wrong - failure
        result["outcome"] = "💀"
        result["bread_amount"] = 0
        print("💀 Failed bake: measured |%s⟩" % _basis_to_string(outcome_state))
    
    # Reset for next bake
    reset_to_ground_state()
    
    return result


func _basis_to_string(index: int) -> String:
    """Convert basis index to binary string for debugging."""
    var s = ""
    for i in range(3):
        s += "0" if ((index >> (2-i)) & 1) == 0 else "1"
    return s
```

---

## Part 8: Natural Decay

### Everything Drifts Back to Ground

```gdscript
func _apply_natural_decay(dt: float) -> void:
    """Apply natural dissipation toward ground state |111⟩.
    
    Without player input, the kitchen cools, dries, and grain dominates.
    This creates time pressure - player must maintain conditions.
    """
    var decay_rate = 0.05  # Per second
    
    # Three decay channels: each axis decays toward |1⟩
    for qubit in range(3):
        kitchen_component.apply_lindblad_drive(qubit, 1, decay_rate, dt)
```

---

## Part 9: Mill as Icon Injector (Simplified)

The Mill no longer measures. It injects the Flour Icon into BioticFlux, enabling wheat↔flour dynamics.

```gdscript
# In QuantumMill.gd

class_name QuantumMill
extends Node2D

## Mill - Icon Injection Portal
## Injects 💨 (Flour) dynamics into parent biome
## Creates Hamiltonian coupling: 🌾 ↔ 💨

var grid_position: Vector2i = Vector2i.ZERO
var parent_biome = null
var is_active: bool = false


func activate(biome) -> bool:
    """Activate mill by injecting Flour dynamics into biome."""
    parent_biome = biome
    
    if not parent_biome:
        push_error("Mill has no parent biome!")
        return false
    
    # Get Flour Icon (defines Hamiltonian coupling to wheat)
    var flour_icon = IconRegistry.get_icon("💨")
    if not flour_icon:
        push_error("Flour Icon not registered!")
        return false
    
    # Inject into biome - adds flour register and dynamics
    # The flour Icon's hamiltonian_couplings define wheat↔flour rotation
    if parent_biome.has_method("inject_icon"):
        var success = parent_biome.inject_icon(flour_icon)
        if success:
            is_active = true
            print("🏭 Mill active: Flour dynamics enabled")
            return true
    
    return false


func _process(_delta: float):
    # Mill is passive - physics happens in biome bath
    pass
```

---

## Part 10: Energy Tap Fix

Taps create Lindblad drains. They don't need planted plots.

```gdscript
# In FarmInputHandler.gd

func _action_place_energy_tap_for(positions: Array[Vector2i], target_emoji: String):
    """Place energy tap - creates Lindblad drain on biome."""
    
    if positions.is_empty():
        action_performed.emit("place_energy_tap", false, "No plots selected")
        return
    
    var success_count = 0
    
    for pos in positions:
        var biome = farm.grid.get_biome_for_plot(pos)
        if not biome:
            continue
        
        # Check if emoji has a register in this biome
        # (For BioticFlux: wheat, flour. For Kitchen: fire, water, flour)
        if biome.has_method("can_tap_emoji") and not biome.can_tap_emoji(target_emoji):
            print("  ⚠️ Cannot tap %s in %s" % [target_emoji, biome.get_biome_type()])
            continue
        
        # Create Lindblad drain
        if biome.place_energy_tap(target_emoji, 0.05):
            # Mark plot as tap for visual
            var plot = farm.grid.get_plot(pos)
            if plot:
                plot.plot_type = FarmPlot.PlotType.ENERGY_TAP
                plot.tap_target_emoji = target_emoji
            
            success_count += 1
            print("  💧 Tap on %s at %s" % [target_emoji, pos])
    
    action_performed.emit("place_energy_tap", success_count > 0,
        "Placed %d taps on %s" % [success_count, target_emoji])
```

---

## Part 11: Complete Player Flow

```
KITCHEN GAMEPLAY LOOP (Correct Physics):

1. PLANT WHEAT (BioticFlux)
   - Allocates 🌾/👥 register in BioticFlux.quantum_computer
   - Wheat evolves under biome Hamiltonian

2. PLACE MILL (BioticFlux)  
   - Injects 💨 Icon → allocates 💨/🌾 register
   - Hamiltonian coupling enables wheat ↔ flour rotation
   - Population oscillates between states

3. PLACE TAP ON FLOUR (BioticFlux)
   - Creates Lindblad drain L = √κ |sink⟩⟨💨|
   - Flour population drains to classical economy

4. HARVEST WHEAT (BioticFlux)
   - Projective measurement on wheat register
   - Collapse → classical wheat credits to economy

5. ADD FIRE TO KITCHEN
   - Player spends economy fire credits
   - Activates Lindblad drive on Kitchen qubit 0
   - Population flows: |1⟩ → |0⟩ on temperature axis
   - P(🔥) increases

6. ADD WATER TO KITCHEN
   - Same mechanism on qubit 1 (moisture axis)
   - P(💧) increases

7. ADD FLOUR TO KITCHEN
   - Same mechanism on qubit 2 (substance axis)  
   - P(💨) increases

8. WATCH DETUNING DECREASE
   - As P(🔥)→0.7, P(💧)→0.5, P(💨)→0.6
   - Detuning Δ → 0
   - Effective baking rate Ω_eff → maximum
   - Hamiltonian rotates |111⟩ → |000⟩
   - P(🍞) = P(|000⟩) increases

9. NATURAL DECAY FIGHTS BACK
   - Each axis decays toward |1⟩
   - Player must maintain conditions
   - Time pressure creates gameplay

10. HARVEST KITCHEN (When Ready)
    - Player judges: "Is P(🍞) high enough?"
    - Projective measurement collapses state
    - If |000⟩: Get bread! 🍞
    - If other: Failure 💀
    - Kitchen resets to |111⟩

11. ITERATE & DISCOVER
    - Player experiments with timing
    - Discovers ideal population ratios
    - Optimizes bread yield
```

---

## Part 12: Validation Tests

```gdscript
func test_kitchen_8d_initialization():
    """Verify Kitchen is exactly 8D."""
    var kitchen = farm.grid.biomes.get("Kitchen")
    
    assert(kitchen.kitchen_component.hilbert_dimension() == 8,
           "Kitchen must be 8D!")
    
    assert(kitchen.get_ground_probability() > 0.99,
           "Should start in |111⟩!")
    
    print("✅ Kitchen 8D initialization test passed")


func test_partial_trace():
    """Verify marginal probabilities sum correctly."""
    var kitchen = farm.grid.biomes.get("Kitchen")
    
    # In |111⟩ state: all marginals should be 0 for |0⟩
    assert(kitchen.get_temperature_hot() < 0.01, "P(🔥) should be ~0")
    assert(kitchen.get_moisture_wet() < 0.01, "P(💧) should be ~0")
    assert(kitchen.get_substance_flour() < 0.01, "P(💨) should be ~0")
    
    # P(|0⟩) + P(|1⟩) = 1 for each qubit
    assert(abs(kitchen.get_temperature_hot() + kitchen.get_temperature_cold() - 1.0) < 0.01,
           "Marginals must sum to 1!")
    
    print("✅ Partial trace test passed")


func test_lindblad_drive_preserves_trace():
    """Verify drives don't break Tr(ρ)=1."""
    var kitchen = farm.grid.biomes.get("Kitchen")
    
    # Apply fire drive
    kitchen.add_fire(1.0)
    
    # Evolve several steps
    for i in range(100):
        kitchen.evolve_kitchen(0.016)
    
    # Check trace
    var trace = kitchen.kitchen_component.get_trace()
    assert(abs(trace - 1.0) < 0.01, "Trace must remain 1! Got %f" % trace)
    
    print("✅ Lindblad trace preservation test passed")


func test_detuning_affects_rotation():
    """Verify detuning suppresses rotation when conditions wrong."""
    var kitchen = farm.grid.biomes.get("Kitchen")
    
    # Reset to ground
    kitchen.reset_to_ground_state()
    
    # Evolve without any drives (conditions are wrong)
    for i in range(100):
        kitchen.evolve_kitchen(0.1)
    
    # P(🍞) should stay low (high detuning suppresses rotation)
    assert(kitchen.get_bread_probability() < 0.1,
           "Bread shouldn't form without proper conditions!")
    
    # Now add correct drives
    kitchen.add_fire(0.7)
    kitchen.add_water(0.5)
    kitchen.add_flour(0.6)
    
    # Evolve with drives
    for i in range(200):
        kitchen.evolve_kitchen(0.1)
    
    # P(🍞) should be higher now
    assert(kitchen.get_bread_probability() > 0.3,
           "Bread should form with proper conditions!")
    
    print("✅ Detuning test passed")
```

---

## Summary: What's Different in v2

| Aspect | v1 (Wrong) | v2 (Correct) |
|--------|------------|--------------|
| Hilbert space | 6+ emojis = undefined | 3 qubits = 8D exactly |
| Basis states | Emoji populations | \|000⟩ through \|111⟩ |
| Bread | Separate dimension | P(\|000⟩) measurement outcome |
| "Add fire" | Pump population | Lindblad drive L=√γ\|0⟩⟨1\| |
| Sweet spot | Gaussian on populations | Detuning in Hamiltonian |
| Two wheats | Undefined collision | Biome isolation + economy bridge |
| Mill | Measurement loop | Icon injection (passive) |
| Trace | Could violate | Preserved by construction |

---

## Files to Modify

- [ ] `Core/QuantumSubstrate/QuantumComponent.gd` - Add partial trace, Lindblad drives, basis initialization
- [ ] `Core/QuantumSubstrate/QuantumComputer.gd` - Add basis validation, merge components
- [ ] `Core/Environment/QuantumKitchen_Biome.gd` - Complete rewrite with 8D system
- [ ] `Core/GameMechanics/QuantumMill.gd` - Simplify to Icon injection
- [ ] `UI/FarmInputHandler.gd` - Fix energy tap is_planted check
- [ ] `Core/Icons/CoreIcons.gd` - Ensure all basis emojis registered

---

**This is real quantum mechanics. The math works. Ready for implementation.**
