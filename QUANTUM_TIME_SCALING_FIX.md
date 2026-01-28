# Quantum Time Scaling Fix

## Problem

The quantum simulation was running too fast. The issue was **not** the rendering or visual effects, but the **quantum state evolution** itself advancing too quickly through simulated time.

### Architecture (Correct)
- **Physics Updates:** 10 Hz (`quantum_evolution_timestep = 0.1`)
- **Rendering:** 30+ Hz (Godot's default)
- **Subcycling:** MAX_DT = 0.02s (numerical stability)

### The Bug
`BiomeBase.quantum_time_scale = 0.5` was defined but **never used**!

The code was doing:
```gdscript
# Every 0.1s of real time:
var actual_dt = quantum_evolution_accumulator  # 0.1s
_update_quantum_substrate(actual_dt)  # Advances simulation by 0.1s
```

This meant the simulation ran at full speed (1.0x) instead of the intended 0.5x.

---

## Solution

Apply `quantum_time_scale` when passing time to the quantum substrate:

```gdscript
# BiomeBase.gd line 237-239
if quantum_evolution_accumulator >= quantum_evolution_timestep:
    # Apply quantum_time_scale to slow down/speed up simulation
    # Still updates at 10 Hz, but advances less simulated time
    var actual_dt = quantum_evolution_accumulator * quantum_time_scale
    quantum_evolution_accumulator = 0.0
```

**File:** `Core/Environment/BiomeBase.gd:237-239`

---

## How It Works

With `quantum_time_scale = 0.125`:

### Real Time vs Simulated Time
| Real Time | Physics Ticks | Simulated Time Advanced |
|-----------|---------------|-------------------------|
| 0.0s      | 0             | 0.0s                    |
| 0.1s      | 1             | 0.05s (0.1 × 0.5)       |
| 0.2s      | 2             | 0.10s                   |
| 1.0s      | 10            | 0.50s                   |

The game runs at **half-speed** in simulated time, while maintaining:
- ✅ 10 Hz physics updates (no stuttering)
- ✅ 30+ Hz rendering (smooth visuals)
- ✅ Same numerical stability (subcycling still works)

---

## Tuning the Simulation Speed

Adjust `quantum_time_scale` in each biome or globally:

```gdscript
# In BiomeBase.gd or specific biome classes
quantum_time_scale = 1.0    # Normal speed (real-time)
quantum_time_scale = 0.5    # Half-speed - smooth intermediate speed
quantum_time_scale = 0.25   # Quarter-speed - slow observation
quantum_time_scale = 0.125  # Eighth-speed (new default) - slowest detailed view
quantum_time_scale = 2.0    # Double-speed - fast-forward mode
```

**Trade-offs:**
- **Lower values (0.1-0.5):** Easier to observe/control, better for learning
- **Higher values (1.0-2.0):** Faster gameplay, more challenging

---

## What Was NOT Changed

The visual force graph system was left untouched because it was already working correctly:
- ✅ `QuantumForceSystem` repulsion/spring constants unchanged
- ✅ `QuantumEdgeRenderer` MI threshold unchanged
- ✅ Force update rates unchanged

The simulation speed issue was **entirely in the quantum evolution**, not the visualization.

---

## Testing

Boot the game and observe:
1. **Quantum state evolution** (bubble radius, emoji opacity changes) should be slower
2. **Rendering** should still be smooth (30+ fps)
3. **Physics updates** should still happen 10x per second (no stuttering)

If too slow/fast, adjust `quantum_time_scale` in `BiomeBase.gd:100` (now set to 0.125).

---

## Technical Notes

### Why 10 Hz Physics?
Quantum evolution is expensive (matrix operations). Running at 10 Hz instead of 60 Hz:
- Saves ~83% CPU (10/60 = 17%)
- Still imperceptible to player (< human reaction time)
- Allows more complex quantum systems

### Why Subcycling?
`QuantumComputer.evolve()` breaks large time steps into 0.02s chunks for numerical stability:
- Prevents density matrix from becoming non-positive (ρ ≱ 0)
- Preserves trace normalization (Tr(ρ) = 1)
- Maintains coherence bounds (0 ≤ |ρ_ij| ≤ 1)

With time scaling:
- Real dt = 0.1s → scaled dt = 0.05s
- Subcycles: 0.05s / 0.02s = 2-3 steps
- Still stable and efficient

---

**Last Updated:** 2026-01-26
**Status:** ✅ Fixed
**Commit:** [current]
