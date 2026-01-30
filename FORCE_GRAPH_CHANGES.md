# Force Graph Physics Changes

## a) POSITIONING FIX
**Problem:** Bubbles appearing in upper left corner
**Solution:** Match graph center to camera position (960, 540)

```gdscript
// Manually repositioned all biome ovals to center at camera position
force_graph.layout_calculator.graph_center = camera_pos
force_graph.center_position = camera_pos
```

## b) MOVEMENT TRACKING
**Added:** Position tracking over 600 frames with pixel-level reporting

Every 60 frames, shows:
- Total distance traveled
- Net displacement
- Current position
- Velocity magnitude

## c) PROBABILITY-BASED MASS (QUANTUM INERTIA!)
**Old system:** `mass = radius` (5-40px range)
**New system:** `mass = emoji_north_opacity + emoji_south_opacity` (0.1-1.0 range)

### Physics Implications:
- **High probability states** (mass ~1.0) → heavy, resist forces
- **Low probability states** (mass ~0.1) → light, easily moved
- **Mass changes every frame** as quantum state evolves!
- Creates **quantum-mechanical inertia** - probability affects dynamics

### Force Scaling (increased 10-40× for probability mass):
```
PURITY_RADIAL_SPRING: 0.05 → 2.0    (40× stronger)
PHASE_ANGULAR_SPRING: 0.08 → 1.5    (19× stronger)
CORRELATION_SPRING:   0.35 → 3.0    (9× stronger)
MI_SPRING:            0.60 → 5.0    (8× stronger)
REPULSION_STRENGTH:   1500 → 8000   (5× stronger)
```

### Other Changes:
- **Damping:** 0.95 → 0.97 (3% energy loss, more sustained motion)
- **Min target radius:** 0px → 50px (prevents center collapse)
- **Initial velocity:** 50px/s → 100-200px/s (more visible movement)

## Expected Behavior:
1. **Bubbles centered at (960, 540)** matching camera
2. **Fast swirling motion** with visible pixel displacement
3. **Dynamic clustering** based on MI (stronger as evolution progresses)
4. **Variable acceleration** - low-probability bubbles zip around, high-probability bubbles drift slowly
5. **Orange-gold correlation edges** connecting entangled qubits

## Force Summary:
```
For each bubble every frame:
  1. Purity Radial: Pulls to radius ~50-200px based on purity
  2. Phase Angular: Rotates around center based on coherence phase
  3. MI Correlation: Attracts to correlated qubits (target dist ∝ 1/MI)
  4. Repulsion: Pushes away from nearby bubbles (inverse-square)

  Total Force → Acceleration = Force / Probability
  → Update Velocity (with 3% damping)
  → Update Position
```
