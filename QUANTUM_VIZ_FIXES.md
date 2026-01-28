# Quantum Visualization Fixes

## Issues Fixed

### 1. Simulation Too Fast ⚡→🐌

**Problem:**
- `REPULSION_STRENGTH = 1500.0` was causing explosive motion
- At 15px distance → force = 1500 / 225 = **6.67 px/frame** (way too high!)

**Fix:**
- Reduced `REPULSION_STRENGTH` from 1500.0 → **30.0** (50x reduction)
- Added `TIME_SCALE = 1.0` constant for easy tuning
- Applied time scaling to force updates and position updates

**File:** `Core/Visualization/QuantumForceSystem.gd`
**Lines:** 27, 30, 122-126

---

### 2. No Visible Connections 🔗

**Problem:**
- Mutual Information (MI) cache updated too slowly (5 Hz)
- MI threshold too high (0.01) - skipped weak correlations
- Made connections flicker and disappear

**Fix:**
- Increased MI update rate from 5 Hz → **30 Hz** (6x faster)
- Lowered MI threshold from 0.01 → **0.001** (10x more sensitive)
- Lowered min alpha from 0.05 → 0.02 to see weak connections

**Files:**
- `Core/Visualization/QuantumForceSystem.gd` line 39
- `Core/Visualization/QuantumEdgeRenderer.gd` lines 119-123

---

### 3. Bubbles Not Animated 🎈

**Root Cause (Not Fixed Yet):**

Based on code analysis, bubbles may be frozen due to:
1. **Lifeless nodes** - plots with no quantum data freeze at anchor
2. **Measured nodes** - nodes that have been measured freeze at frozen_anchor
3. **HOVERING/FIXED plots** - plots with quantum_behavior = 1 or 2 don't move

**To Diagnose:**
Run the diagnostic script to check which nodes are frozen and why.

**Likely Fix (if needed):**
If all nodes are "lifeless", check that:
- Biomes have quantum_computer initialized
- Plots are planted (is_planted = true)
- Quantum states are being evolved (not all zero)

---

## Testing the Fixes

### Before Testing
Boot the game and observe:
- How fast do bubbles move when close together?
- Do you see any connection lines between bubbles?
- Are bubbles moving at all or completely frozen?

### After Changes
The simulation should now:
1. ✅ Move at reasonable speed (not explosive)
2. ✅ Show orange-gold MI web connections between correlated qubits
3. ✅ Show cyan entanglement lines for explicit Bell pairs
4. ❓ Bubbles should move/wiggle (unless intentionally frozen)

### Tuning Parameters

If simulation is still too fast/slow, adjust **TIME_SCALE**:
```gdscript
# In Core/Visualization/QuantumForceSystem.gd line 30
const TIME_SCALE = 0.5  # Half speed
const TIME_SCALE = 2.0  # Double speed
```

If too many/few connections visible, adjust **MI threshold**:
```gdscript
# In Core/Visualization/QuantumEdgeRenderer.gd line 119
if mi < 0.0001:  # More connections (very sensitive)
if mi < 0.01:    # Fewer connections (only strong correlations)
```

---

## Force Constants Reference

Current values after fixes:
```gdscript
CORRELATION_SPRING = 0.12      # MI-based attraction
PURITY_RADIAL_SPRING = 0.08    # Pure → center force
PHASE_ANGULAR_SPRING = 0.04    # Phase alignment
REPULSION_STRENGTH = 30.0      # Overlap prevention (was 1500.0!)
DAMPING = 0.85                 # Velocity decay
TIME_SCALE = 1.0               # Global time multiplier
```

---

## Diagnostic Commands

To check visualization state at runtime:
```gdscript
# Check force system
var graph = get_node("/root/Main/PlayerShell/QuantumViz").graph
print("MI cache size: ", graph.force_system._mi_cache.size())
print("Active nodes: ", graph.quantum_nodes.filter(func(n): return n.visible).size())

# Check node velocities
for node in graph.quantum_nodes:
	if node.velocity.length() > 0.1:
		print("Node moving: %s, vel: %.2f" % [node.emoji_north, node.velocity.length()])

# Check if lifeless
for node in graph.quantum_nodes:
	if node.is_lifeless:
		print("Lifeless node: %s" % node.emoji_north)
```

---

## Next Steps if Issues Persist

### If bubbles still not moving:
1. Run diagnostic script to check:
   - How many nodes are "lifeless"?
   - How many have quantum_behavior = 1 or 2?
   - Are any nodes marked as measured?
2. Check that quantum states are evolving (not frozen)
3. Verify biomes have quantum_computer initialized

### If connections still not visible:
1. Check MI cache size (should be > 0)
2. Lower MI threshold further (try 0.0001)
3. Verify nodes are in same biome (MI only within biome)
4. Check that quantum states are correlated (not all |0⟩)

### If simulation still too fast:
1. Reduce TIME_SCALE to 0.5 or 0.25
2. Further reduce REPULSION_STRENGTH to 15.0 or 10.0
3. Increase DAMPING to 0.9 or 0.95

---

**Last Updated:** 2026-01-26
**Status:** ⚠️ Partial Fix (speed + connections) - animation TBD
