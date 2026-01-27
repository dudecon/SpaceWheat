# Purity Multiplier System - Quantum Coherence Rewards

## Summary

Credits from harvesting (POP action) are now multiplied by the quantum system's **purity**:

```
Credits = measured_probability × purity × 10
```

This creates a direct economic incentive to maintain quantum coherence!

---

## What is Purity?

**Purity** measures how "pure" (coherent) vs "mixed" (decoherent) a quantum state is:

```
Purity = Tr(ρ²)
```

Where ρ is the density matrix.

### Purity Scale

| Purity Value | State Type | Description |
|--------------|------------|-------------|
| **1.0** | Pure state | Maximum coherence (e.g., \|0⟩, Bell state) |
| **0.5 - 0.9** | Partially mixed | Some decoherence, still fairly coherent |
| **0.2 - 0.5** | Mixed | Significant decoherence |
| **1/d** | Maximally mixed | Complete decoherence (d = dimension) |

For a 5-qubit system (32-dimensional):
- Pure state: purity = 1.0
- Maximally mixed: purity = 1/32 = 0.03125

---

## Gameplay Impact

### Before (Probability Only)
```
Measure 🌾 with P(🌾) = 0.8
→ Credits = 0.8 × 10 = 8.0
```

### After (Probability × Purity)
```
Scenario A: High Coherence
Measure 🌾 with P(🌾) = 0.8, purity = 0.9
→ Credits = 0.8 × 0.9 × 10 = 7.2

Scenario B: Low Coherence
Measure 🌾 with P(🌾) = 0.8, purity = 0.3
→ Credits = 0.8 × 0.3 × 10 = 2.4
```

**Same measurement probability, 3x difference in payout!**

---

## Strategic Depth

### What Reduces Purity?
1. **Lindblad dissipation** - environmental decoherence over time
2. **Entanglement with environment** - coupling to external degrees of freedom
3. **Partial measurements** - collapsing part of the system
4. **Mixed initial states** - starting from thermal or random states

### What Increases Purity?
1. **Projective measurements** - collapse to pure states
2. **Unitary evolution** - Hamiltonian dynamics preserve purity
3. **State preparation** - resetting to ground state
4. **Coherent pumping** - external drive that maintains coherence

### Player Strategies

**Early Game (Low Skill):**
- Purity naturally low due to Lindblad dissipation
- Small payouts teach importance of coherence
- Incentive to learn quantum control

**Mid Game (Learning):**
- Players discover that waiting for state purification pays off
- Strategic timing: measure when probability × purity peaks
- Balance between "harvest now" vs "wait for coherence"

**Late Game (Advanced):**
- Use Berry phase dynamics to stabilize coherence
- Entanglement engineering to create robust pure states
- Optimize measurement sequences to maximize purity bonus

---

## Implementation Details

### Core Calculation (ProbeActions.gd:402-410)

```gdscript
# 3. Get purity bonus multiplier from biome's quantum computer
var purity = 1.0  # Default if no quantum computer
if biome and biome.quantum_computer:
    purity = biome.quantum_computer.get_purity()

# 4. Convert probability to credits with purity multiplier
# Credits = probability × purity × 10
# This rewards maintaining quantum coherence!
var credits = recorded_prob * purity * EconomyConstants.QUANTUM_TO_CREDITS
```

### Purity Calculation (QuantumComputer.gd:1301-1312)

```gdscript
func get_purity() -> float:
    """Get purity Tr(ρ²) of the quantum state.

    Returns:
        1.0 for pure states, < 1.0 for mixed states
        Minimum is 1/dim for maximally mixed state
    """
    if density_matrix == null:
        return 0.0

    var rho_squared = density_matrix.mul(density_matrix)
    return rho_squared.trace().re
```

Uses native C++ acceleration via Eigen backend (100x faster than GDScript).

---

## UI Display

### Console Output (FarmView.gd:211)

When popping a terminal:
```
[INFO][ui] 🎉 Popped: 🌾 → 7.2 credits (purity: 0.90)
```

Shows both credits earned AND purity multiplier.

### BiomeOvalPanel (Already Integrated!)

The biome inspector already has a purity bar that displays Tr(ρ²):
- **Green (high)**: Purity near 1.0 - coherent system
- **Yellow (medium)**: Purity ~0.5 - partially mixed
- **Red (low)**: Purity near 0 - decoherent system

Access via:
- Press **B** to open biome inspector
- Press **F** to toggle between single biome and all biomes view
- Purity bar updates in real-time (0.5s refresh)

---

## Physics Interpretation

### Why This Makes Sense

In real quantum computing:
1. **Coherence is valuable** - decoherence destroys quantum advantage
2. **Purity is measurable** - Tr(ρ²) is an experimentally accessible quantity
3. **Resource cost** - maintaining purity requires energy/control

In SpaceWheat:
1. **Purity = Quality** - better quantum states = better harvests
2. **Lindblad = Entropy** - environmental coupling degrades resources
3. **Player skill** - learning to maintain coherence increases efficiency

### Thermodynamic Interpretation

The purity bonus can be seen as:
```
Credits ∝ Probability × Purity
        ∝ ⟨Observable⟩ × (1 - Entropy/Max_Entropy)
        ∝ Extracted_Work
```

Higher purity → lower entropy → more extractable work → more credits!

---

## Example Scenarios

### Scenario 1: Immediate Harvest (Low Purity)

```
T=0: Initialize |0⟩ (purity=1.0)
T=1: Lindblad dissipation → purity=0.7
T=2: More dissipation → purity=0.4
T=3: MEASURE → P(🌾)=0.6, purity=0.4
     Credits = 0.6 × 0.4 × 10 = 2.4 credits
```

**Harvested quickly but low purity killed the payout.**

### Scenario 2: Patient Harvest (Purification Strategy)

```
T=0: Initialize |0⟩ (purity=1.0)
T=1: Hamiltonian evolution → purity=1.0 (unitary preserves purity)
T=2: Population builds: P(🌾)=0.8, purity=1.0
T=3: MEASURE → P(🌾)=0.8, purity=1.0
     Credits = 0.8 × 1.0 × 10 = 8.0 credits
```

**Waited for population AND maintained coherence → 3.3x more credits!**

### Scenario 3: Entanglement Engineering

```
T=0: Create Bell state |Φ+⟩ (purity=1.0)
T=1: Hamiltonian couples Bell pair → coherent evolution
T=2: Measurement on subsystem A → P(🌾)=0.7, purity=0.85
     Credits = 0.7 × 0.85 × 10 = 5.95 credits
```

**Used entanglement to maintain high purity despite partial measurement.**

---

## Advanced Mechanics

### Purity Dynamics Under Evolution

For closed system (Hamiltonian only):
```
d(purity)/dt = 0  (conserved under unitary evolution)
```

For open system (Lindblad master equation):
```
d(purity)/dt = -γ × (purity - purity_equilibrium)
```

Where γ is the decoherence rate and purity_equilibrium depends on temperature.

### Optimal Measurement Time

To maximize credits, solve:
```
max_t [ P(resource, t) × Purity(t) ]
```

This creates a trade-off:
- Early measurement: low probability, high purity
- Late measurement: high probability, low purity
- Optimal: somewhere in between!

---

## Future Enhancements

### Possible Extensions

1. **Purity Visualization**
   - Color-code quantum bubbles by purity (blue = pure, red = mixed)
   - Show purity decay animation over time

2. **Purity Threshold Bonuses**
   - Purity > 0.9: 2x multiplier (coherence bonus)
   - Purity > 0.95: 3x multiplier (ultra-coherent bonus)
   - Purity = 1.0: 5x multiplier (perfect purity bonus)

3. **Purity-Based Achievements**
   - "Quantum Purist" - harvest with purity > 0.99
   - "Coherence Master" - maintain purity > 0.8 for 100 harvests
   - "Entropy Slayer" - increase purity by 0.5 in one cycle

4. **Purity Leaderboards**
   - Track highest purity harvest
   - Average purity per player
   - Total credits earned from purity bonuses

---

## Testing the System

### In-Game Test

1. **Boot the game** and press **B** to open biome inspector
2. **Check purity bar** - should show current Tr(ρ²) value
3. **Press 3Q (EXPLORE)** to bind a terminal
4. **Wait and watch purity** - should decrease over time (Lindblad dissipation)
5. **Press 3Q again (MEASURE)** to collapse state
6. **Press 3Q again (POP)** to harvest
7. **Check console output** - should show `Popped: 🌾 → X.X credits (purity: 0.XX)`

### Expected Console Output

```
[INFO][ui] 🎉 Popped: 🌾 → 7.2 credits (purity: 0.90)
```

If purity is working, you'll see different credit amounts for the same emoji depending on system coherence!

---

**Last Updated:** 2026-01-26
**Status:** ✅ Implemented and Tested
**Commit:** 848aa8e
