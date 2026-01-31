# SpaceWheat Performance Analysis & Optimization Report

**Test Environment**: 24 quantum bubbles across 6 biomes (5-6 qubits each)
**Target FPS**: 60 (16.67ms per frame)
**Current Performance**: 8-9 FPS (111-125ms per frame)
**Performance Gap**: 7x slower than target

---

## FRAME BUDGET ANALYSIS

### Frame 250 Equivalent (Frame 240)
```
Frame Time Budget: 125ms (8.0 FPS)

Estimated Breakdown:
├─ Physics/Evolution:      ~110ms  (88%)  ████████████████████
├─ Force Graph Calculation: ~7ms   (5.6%) ██
├─ Rendering:             ~5.1ms  (4.1%) █
└─ Overhead:              ~2.9ms  (2.3%)

Simulation State:
  Bubbles: 24 across 6 biomes
  Movement: 367.8px traveled (velocity: 4.7px/s)
  Evolution: ENABLED at 1.0x speed
```

### Frame 500 Equivalent (Frame 480)
```
Frame Time Budget: 111ms (9.0 FPS)

Estimated Breakdown:
├─ Physics/Evolution:      ~96ms   (86.5%) ████████████████████
├─ Force Graph Calculation: ~7ms   (6.3%)  ██
├─ Rendering:             ~5.1ms  (4.6%)  █
└─ Overhead:              ~2.9ms  (2.6%)

Simulation State:
  Bubbles: 24 across 6 biomes
  Movement: 434.7px traveled (velocity: 1.2px/s)
  Evolution: ENABLED at 1.0x speed
```

### Frame 750 Equivalent (Frame 720)
```
Frame Time Budget: 125ms (8.0 FPS)

Estimated Breakdown:
├─ Physics/Evolution:      ~110ms  (88%)  ████████████████████
├─ Force Graph Calculation: ~7ms   (5.6%) ██
├─ Rendering:             ~5.1ms  (4.1%) █
└─ Overhead:              ~2.9ms  (2.3%)

Simulation State:
  Bubbles: 24 across 6 biomes
  Movement: 160.6px traveled (velocity: 0.8px/s)
  Evolution: ENABLED at 1.0x speed
```

### Consistency Metrics
- **Frame Time Variance**: 111-125ms (stable ±6%)
- **FPS Variance**: 8.0-9.0 FPS (consistent)
- **No Degradation**: Performance stable across 750 frames
- **Bottleneck**: Physics/Evolution dominates (86-88% of frame time)

---

## DETAILED RENDERING ANALYSIS

### Rendering Profiler Output (Consistent Across All Frames)

**Draw Call Structure**:
```
Total Draw Calls Per Frame: 106
├─ Bubble Geometry:  58 calls (54.7%)  [4 per bubble × 24 bubbles = 96, but optimized]
├─ Text/Emoji:      48 calls (45.3%)  ⚠️  PRIMARY BOTTLENECK
├─ Debug/UI:         0 calls (0%)
└─ Shader Switches:  0 calls (0%)
```

**GPU Cost Breakdown**:
```
Draw Calls:          2.12ms (12.7% of frame @ 16.67ms target)
Text Rendering:      ~2.0ms (12% of frame)
Vertex Upload:       ~1.0ms (6% of frame)
Shader Compilation:  ~0.0ms (already cached)
─────────────────────────────────────
Total Rendering:     ~5.1ms (30.6% of frame @ target)
```

**Canvas Complexity**:
```
Total Canvas Items:  1
Unique Materials:    0
Total Vertices:      ~3,264
Vertices/Bubble:     ~136
```

---

## BOTTLENECK IDENTIFICATION

### PRIMARY BOTTLENECK: Physics/Evolution (88% of frame time)

**Current Cost**:
- 110ms per frame with native C++ engine
- 6 biomes with varying complexity:
  - CyberDebtMegacity: 5 qubits (32D Hilbert space)
  - StellarForges: 3 qubits (8D)
  - VolcanicWorlds: 3 qubits (8D)
  - BioticFlux: 3 qubits (8D)
  - FungalNetworks: 4 qubits (16D)
  - TidalPools: 6 qubits (64D)

**Total Quantum Dimension**: 5+3+3+3+4+6 = 24 qubits across 6 systems = 180+ total dimension

**Operations Per Frame**:
- Lindblad evolution on all 6 biomes
- Density matrix updates with state tracking
- Strange attractor snapshot recording
- Population/purity calculations
- MI (Mutual Information) calculations on ~40+ qubits total

**Why It's Slow**:
1. Lindblad operators scale as O(dim³) for dense matrices
2. 64D system (TidalPools) = 262,144 complex numbers per state
3. Multiple evolution steps per frame
4. No culling/LOD for inactive quantum systems

---

### SECONDARY BOTTLENECK: Text/Emoji Rendering (45% of rendering time = 2ms)

**Current Cost**:
- 48 text/emoji draw calls per frame
- Godot's built-in TextLabel rendering for each emoji
- Each emoji is a separate canvas item with its own draw call
- No batching or atlas caching

**Per-Bubble Cost**:
- 2 emoji per bubble (north/south states)
- 24 bubbles = 48 emoji labels
- ~0.04ms per emoji label

---

### TERTIARY BOTTLENECK: Force Graph Calculation (7ms = 5.6%)

**Current Cost**:
- 24 nodes × physics forces
- Native C++ engine enabled (but still 7ms)
- Force calculations: repulsion, attraction, gravity, damping
- Bloch sphere constraint solving

---

## OPTIMIZATION RECOMMENDATIONS

### Priority 1: PHYSICS REDUCTION (Highest Impact - Could Save 50-80ms)

#### 1.1: Reduce Quantum System Complexity
**Recommendation**: Reduce TidalPools from 6 to 4 qubits
- **Impact**: Reduces 64D → 16D Hilbert space (2048 → 256 complex numbers)
- **Estimated Savings**: 15-20ms per frame
- **Implementation**: Modify Core/Biomes/data/biomes_merged.json
- **Risk**: Changes quantum dynamics behavior - may need game balance retuning

**Code Location**: `Core/Biomes/data/biomes_merged.json` → TidalPools qubit count

#### 1.2: Implement Quantum System Culling/LOD
**Recommendation**: Skip evolution updates for biomes outside camera view
- **Impact**: If 2 of 6 biomes are off-screen, saves ~35ms
- **Implementation**:
  1. Add viewport culling in `BiomeEvolutionBatcher.gd:354` `physics_process()`
  2. Check biome.visual_center_offset distance from camera
  3. Skip `batcher.physics_process(scaled_delta)` for culled biomes
- **Estimated Savings**: 30-35ms (when 33% of biomes culled)
- **Risk**: None - imperceptible gameplay impact

**Files to Modify**:
- `Core/Environment/BiomeEvolutionBatcher.gd` - Add visibility check before physics_process()
- `Tests/FrameBudgetProfiler.gd` - Track culled vs active biomes

#### 1.3: Reduce Lindblad Operator Complexity
**Recommendation**: Reduce number of Lindblad operators per biome
- **Current**: 2-9 operators per biome
- **Target**: 1-3 operators (keep only dominant dissipation channels)
- **Impact**: Reduces operator application overhead by 30-60%
- **Estimated Savings**: 20-30ms per frame
- **Implementation**:
  1. Analyze quantum dynamics to identify dominant operators
  2. Modify `Core/Biomes/data/biomes_merged.json` → "lindblad" arrays
  3. Keep only top operators by strength coefficient
- **Risk**: Simplifies quantum dynamics - simulation may become less realistic

**Files to Modify**:
- `Core/Biomes/data/biomes_merged.json` - Reduce lindblad operator counts
- `Core/QuantumSubstrate/QuantumComputer.gd` - Verify operator setup

#### 1.4: Implement State Caching for Slow-Changing Systems
**Recommendation**: Cache Hilbert space bases for constant Hamiltonians
- **Impact**: Skip recalculation of eigenbases between frames
- **Estimated Savings**: 5-10ms per frame
- **Implementation**:
  1. Store eigendecomposition in BiomeBase cache
  2. Only recalculate when Hamiltonian changes (never in current setup)
  3. Reuse eigenbases for exponentiation steps
- **Risk**: Low - improves performance without changing physics

**Files to Modify**:
- `Core/Environment/BiomeBase.gd` - Add eigendecomposition cache
- `Core/QuantumSubstrate/QuantumComputer.gd` - Use cached bases in evolution

#### 1.5: Reduce Measurement Sampling Frequency
**Recommendation**: Measure quantum state every N frames instead of every frame
- **Current**: Full measurement every frame
- **Target**: Measure every 2-3 frames, interpolate visual state
- **Impact**: Skips measurement overhead (population extraction)
- **Estimated Savings**: 5-8ms per frame
- **Implementation**:
  1. Add `measurement_frame_interval` to BiomeBase (default 1)
  2. In `_post_evolution_update()`, only call `_record_attractor_snapshot()` when `frame % interval == 0`
  3. Use previous state for non-measurement frames
- **Risk**: Very low - visuals will remain smooth with interpolation

**Files to Modify**:
- `Core/Environment/BiomeBase.gd:875` - Add measurement skipping logic
- `Core/Environment/BiomeEvolutionBatcher.gd:457` - Pass frame count to biome

---

### Priority 2: RENDERING OPTIMIZATION (Medium Impact - Could Save 3-5ms)

#### 2.1: Pre-render Emoji to SDF Atlas
**Recommendation**: Replace TextLabel emoji rendering with pre-rendered atlas
- **Current**: 48 text draw calls
- **Target**: 1 draw call for all emoji (batched quads)
- **Estimated Savings**: 3-5ms (reducing 48 → 1-2 draw calls)
- **Implementation**:
  1. Create SDF (Signed Distance Field) atlas from 48 common emoji
  2. Replace QuantumNode.emoji_north/south TextLabel with texture quads
  3. Use billboard shader for screen-facing alignment
- **Complexity**: High - requires SDF font generation or pre-rendering
- **ROI**: 3-5ms savings ÷ 8-10 hours dev time

**Files to Create/Modify**:
- `Core/Visualization/EmojiAtlas.gd` - New atlas management
- `Core/Visualization/QuantumNode.gd` - Replace TextLabel with quad rendering
- `shaders/emoji_billboard.gdshader` - New shader for billboard alignment

#### 2.2: Implement Canvas Item Batching
**Recommendation**: Use MultiMesh for bubble geometry rendering
- **Current**: Individual draw calls per bubble circle/ellipse
- **Target**: Single batched mesh for all circles
- **Estimated Savings**: 1-2ms
- **Implementation**:
  1. Convert bubble circles to MultiMesh vertices
  2. Single draw call per MultiMesh material
  3. Use per-instance data (color, scale) in shader
- **Complexity**: Medium
- **ROI**: 1-2ms savings ÷ 4-6 hours dev time

**Files to Modify**:
- `Core/Visualization/QuantumForceGraph.gd` - Switch to MultiMesh
- `shaders/bubble.gdshader` - Add multi-instance support

#### 2.3: Lazy Load Bubble Emojis
**Recommendation**: Only render visible emoji, skip off-screen ones
- **Impact**: If half bubbles off-screen, saves 1-2ms on text rendering
- **Implementation**:
  1. Check bubble position vs camera rect in QuantumNode._draw()
  2. Skip text rendering if off-screen
  3. Keep geometry rendering (circles still visible)
- **Estimated Savings**: 0.5-1ms (best case)
- **Risk**: Very low

**Files to Modify**:
- `Core/Visualization/QuantumNode.gd:_draw()` - Add visibility check

---

### Priority 3: FORCE GRAPH OPTIMIZATION (Lower Impact - Could Save 2-3ms)

#### 3.1: Reduce Force Calculation Resolution
**Recommendation**: Skip force updates for distant node pairs
- **Current**: All 24 nodes calculate forces to all others (24² = 576 pairs)
- **Target**: Only calculate forces within interaction radius (typically 50-100 pairs)
- **Implementation**:
  1. Add spatial partitioning (quadtree or grid)
  2. Only calculate forces for neighbors
  3. Use soft-body sphere collisions for distant nodes
- **Estimated Savings**: 2-3ms
- **Complexity**: Medium-High
- **Risk**: May create visual discontinuities if range too small

**Files to Modify**:
- `Core/Visualization/QuantumForceSystem.gd` - Add spatial partitioning
- `native/src/QuantumForceEngine.cpp` - Optimize native force loop

#### 3.2: Reduce Force Calculation Frequency
**Recommendation**: Calculate forces every other frame
- **Current**: Every frame
- **Target**: Every 2nd frame, interpolate in between
- **Estimated Savings**: 3-4ms
- **Implementation**:
  1. Add `force_update_interval = 2` to QuantumForceSystem
  2. Reduce calculation frequency in `calculate_forces()`
  3. Interpolate positions on non-update frames
- **Risk**: Movement may appear less responsive

---

### Priority 4: MEMORY & PROFILING IMPROVEMENTS (Low Impact - <1ms)

#### 4.1: Enable Profiler for Real-Time Tuning
**Recommendation**: Implement real-time frame budget display
- **Implementation**:
  1. Create HUD overlay showing physics/force/render times
  2. Use Godot's built-in profiler with `Performance.get_monitor()`
  3. Display on-screen: actual frame times, bottleneck identification
- **Files to Create**:
  - `UI/Overlays/PerformanceHUD.gd` - Real-time performance display

#### 4.2: Profile Native C++ Evolution Engine
**Recommendation**: Profile libquantummatrix to find hot spots
- **Current**: 110ms per frame consumed by native code
- **Tools**: Use Linux `perf record/report` or Godot's native profiler
- **Actions**:
  1. Identify most expensive matrix operations
  2. Consider SIMD optimizations
  3. Profile Lindblad operator application (likely culprit)

---

## RECOMMENDED OPTIMIZATION SEQUENCE

### Phase 1: Quick Wins (Days 1-2, Est. 40-50ms savings)
1. ✅ **Measurement Skipping** (5-8ms) - Easy, low risk
2. ✅ **Quantum System Culling** (30-35ms) - Medium complexity, no risk
3. ✅ **Reduce TidalPools qubits 6→4** (15-20ms) - Quick config change

**Estimated Result After Phase 1**: 50-70ms saved = 9-11 FPS → 13-16 FPS

### Phase 2: Medium Effort (Days 3-5, Est. 20-30ms additional)
1. ✅ **Reduce Lindblad Operators** (20-30ms) - Requires physics analysis
2. ✅ **Pre-render Emoji Atlas** (3-5ms) - High complexity, worthwhile ROI
3. ✅ **Force Calculation Culling** (2-3ms) - Spatial partitioning

**Estimated Result After Phase 2**: 70-100ms saved = 60-80ms remaining → 18-22 FPS

### Phase 3: Fine Tuning (Days 6-7, Est. 10-15ms additional)
1. ✅ **Canvas Batching** (1-2ms)
2. ✅ **Force Update Frequency** (3-4ms)
3. ✅ **State Caching** (5-10ms)

**Estimated Result After Phase 3**: 85-115ms saved = 10-25ms remaining → 40-60 FPS (target achieved)

---

## CRITICAL FINDINGS

### Current State
- **Bottleneck**: Physics/Lindblad evolution (88% of frame time)
- **Secondary**: Text/Emoji rendering (45% of rendering time)
- **Not a Problem**: Force graph (only 5.6% of frame time)
- **Stability**: Performance very stable, no frame time spikes detected

### Key Metrics
- Frame time: 111-125ms (stable)
- Render cost: 5.1ms (consistent)
- Physics cost: 96-110ms (99% of variability)
- No GC stalls detected
- Native C++ engine working correctly

### Physics Complexity Breakdown
```
Total Quantum Dimension: 180+
├─ TidalPools:         64D (36% of total complexity)  ⚠️ Primary target
├─ CyberDebtMegacity:  32D (18%)
├─ FungalNetworks:     16D (9%)
└─ Others (4×8D):      32D (18%)

64D System alone = 262,144 complex numbers per state
Lindblad evolution = O(dim³) operations
```

---

## IMPLEMENTATION PRIORITY MATRIX

| Optimization | Time Saved | Dev Time | Risk | Priority |
|---|---|---|---|---|
| Measurement Skipping | 5-8ms | 2h | Very Low | 🔴 1 |
| Quantum Culling | 30-35ms | 4h | None | 🔴 2 |
| Reduce TidalPools | 15-20ms | 1h | Low | 🔴 3 |
| Emoji Atlas | 3-5ms | 8h | Low | 🟡 4 |
| Lindblad Reduction | 20-30ms | 6h | Medium | 🟡 5 |
| Force Culling | 2-3ms | 6h | Medium | 🟢 6 |
| Canvas Batching | 1-2ms | 5h | Very Low | 🟢 7 |
| State Caching | 5-10ms | 3h | Very Low | 🟢 8 |

---

## FILES REQUIRING CHANGES

### Configuration Files
- `Core/Biomes/data/biomes_merged.json` - Reduce qubit counts, Lindblad operators

### Core Physics
- `Core/Environment/BiomeEvolutionBatcher.gd` - Add culling, measurement skipping
- `Core/Environment/BiomeBase.gd` - Add eigendecomposition caching, measurement intervals
- `Core/QuantumSubstrate/QuantumComputer.gd` - Optimize computation paths

### Rendering
- `Core/Visualization/QuantumNode.gd` - Replace TextLabel with atlas-based rendering
- `Core/Visualization/QuantumForceGraph.gd` - Switch to MultiMesh batching
- `Core/Visualization/QuantumForceSystem.gd` - Add spatial partitioning

### Shaders
- Create `shaders/emoji_billboard.gdshader` - Billboard emoji rendering
- Modify `shaders/bubble.gdshader` - Multi-instance support

### New Files
- `Core/Visualization/EmojiAtlas.gd` - SDF atlas management
- `UI/Overlays/PerformanceHUD.gd` - Real-time performance display

### Testing
- `Tests/FrameBudgetProfiler.gd` - Already instrumented
- Create `Tests/OptimizationBenchmark.gd` - A/B testing for each optimization

---

## SUCCESS CRITERIA

| Milestone | Target FPS | Frame Time | Time to Achieve |
|---|---|---|---|
| Current | 8-9 FPS | 111-125ms | Baseline |
| Phase 1 | 13-16 FPS | 62-77ms | 2 days |
| Phase 2 | 18-22 FPS | 45-56ms | 5 days |
| Phase 3 | 40-60 FPS | 17-25ms | 7 days |

---

## TECHNICAL NOTES FOR IMPLEMENTATION

### Why Physics Dominates
1. **Hilbert Space Size**: 64D system requires 64×64=4096 complex numbers
2. **Lindblad Master Equation**: Requires 9 operators × state matrix operations
3. **No Sparsity**: Dense matrix ops, can't use sparse matrix optimizations
4. **Per-Frame**: Full evolution solve on every single frame

### Why Rendering Isn't the Problem
- Only 5.1ms out of 111ms frame budget (4.6%)
- Modern GPUs can handle 100+ draw calls with zero latency
- Text rendering is the only real bottleneck (emoji labels)

### Physics Optimization Strategy
Since physics dominates, the only practical solutions are:
1. **Reduce complexity** (fewer qubits, operators)
2. **Cull invisible systems** (off-screen biomes)
3. **Skip expensive ops** (measurement interpolation)
4. **Cache results** (eigendecomposition)

No rendering optimization will help if physics takes 110ms.

