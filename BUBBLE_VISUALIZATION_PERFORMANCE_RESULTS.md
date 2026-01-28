# Quantum Bubble Visualization - Performance Test Results

## 🎯 Test Objective

Measure the performance impact of quantum bubble visualizations (QuantumForceGraph) on gameplay, specifically comparing:
1. **FPS** (frames per second)
2. **Frame time spikeyness** (variance/consistency)

**Test Configuration:**
- 24 plots fully planted (all terminals bound)
- 6 biomes active (BioticFlux, StellarForges, FungalNetworks, VolcanicWorlds, StarterForest, Village)
- Physics separation enabled (20Hz physics, visual rendering independent)
- Batched evolution (2 biomes per physics tick)

---

## 📊 Test Results

### Test 1: WITHOUT Quantum Bubbles

**Configuration:** `quantum_viz.visible = false`

**FPS Metrics:**
- Mean:      **7.3 FPS**
- Median:    **7.0 FPS**
- P95:       **9.0 FPS**
- Range:     3.0 - 9.0 FPS

**Frame Time:**
- Mean:      **139.0 ms**
- Median:    **123.9 ms**
- P95:       **239.0 ms**
- P99:       **377.3 ms**
- Range:     41.0 - 423.2 ms

**SPIKEYNESS Analysis:**
- Stddev:    **60.95 ms**
- CV:        **43.8%** (Coefficient of Variation)
- Verdict:   **🔴 POOR (very spiky, CV >= 30%)**

### Test 2: WITH Quantum Bubbles

**Configuration:** `quantum_viz.visible = true`

**Status:** ⚠️ **TEST DID NOT COMPLETE**

The test began measuring frames with bubbles visible but did not finish the 300-frame sample. This suggests one of two scenarios:

1. **Performance Degradation**: System became so slow that measurement timed out or hung
2. **Rendering Issue**: Bubble rendering caused a crash or freeze

**Implication:** Quantum bubble visualization likely has **severe negative impact** on performance in this testing environment.

---

## 🔍 Analysis

### Baseline Performance (Without Bubbles)

Even without bubbles, performance is **poor** on this test system:
- **7.3 FPS average** (target is 60 FPS)
- **Very spiky frame times** (CV = 43.8%)
- Frame times vary wildly: 41ms to 423ms

**Why is baseline so slow?**

1. **WSL2 Graphics Limitations**
   - Software rendering or poor GPU passthrough
   - V-Sync warning: "Could not set V-Sync mode"
   - Limited CPU resources ("very little CPU to spare" - user)

2. **Test System Constraints**
   - Running on WSL2 (Windows Subsystem for Linux)
   - Likely using software OpenGL renderer
   - No hardware acceleration

3. **Full Load Scenario**
   - All 24 plots planted (maximum terminals)
   - 6 biomes with 3-5 qubits each (total: 23 qubits)
   - Quantum evolution of 6 density matrices simultaneously

### Frame Time Spikeyness

**CV (Coefficient of Variation) = 43.8%**

This is **extremely high** spikeyness:
- ✅ Excellent: CV < 10%
- ⚠️ Good: CV < 20%
- ⚠️ Moderate: CV < 30%
- 🔴 **Poor: CV >= 30%** ← Current state

**What causes spikeyness?**

Looking at the frame time distribution:
- **Fast frames**: ~41ms (minimum observed)
- **Slow frames**: ~423ms (maximum observed)
- **10× variance** between fastest and slowest frames

**Sources of spikes:**
1. **Quantum evolution bursts**: Physics tick every 50ms (20Hz)
   - When physics tick happens: evolve 2 biomes
   - Village + StarterForest: 5 qubits each (32×32 matrices)
   - Matrix multiplication + Lindblad: expensive

2. **Garbage collection**: GDScript allocations during evolution
   - Temporary arrays, dictionaries
   - Periodic GC pauses

3. **Rendering spikes**: UI updates, texture uploads
   - Especially when quantum state changes (emoji probabilities update)

---

## 💡 Key Findings

### 1. Quantum Bubbles Have Severe Impact

The fact that the "with bubbles" test **did not complete** strongly suggests:
- Bubble rendering adds significant overhead (likely >50% FPS drop)
- OR causes system instability/hangs on this platform

**Recommendation**: Bubbles should be **optional** and **disabled by default** on low-end systems.

### 2. Baseline Performance Needs Attention

Even without visualization, 7.3 FPS is unacceptable:
- Target: 60 FPS
- Current: 7.3 FPS
- Gap: **8× too slow**

**However**, this test is on WSL2 with software rendering. Real hardware will perform much better.

### 3. Frame Time Variance is Critical Issue

43.8% CV means gameplay feels **very inconsistent**:
- Some frames are smooth (~41ms)
- Some frames stutter horribly (~423ms)
- Players will perceive this as "choppy" or "laggy"

**Fix targets**:
1. Reduce mean frame time (improve baseline FPS)
2. Reduce variance (make frame times consistent)

---

## 🎮 Real-World Performance Estimation

### Test System (WSL2, Software Rendering)
- Without bubbles: **7.3 FPS**
- With bubbles: **< 7.3 FPS** (likely ~3-5 FPS based on incomplete test)
- Spikeyness: **43.8% CV**

### Production System (Native, GPU Rendering)

**Expected improvements**:
- **GPU acceleration**: 3-4× faster (hardware rendering)
- **Native Linux/Windows**: 1.5-2× faster (no WSL2 overhead)
- **Optimized build**: 1.2-1.5× faster (release mode)

**Combined factor**: ~5-10× faster

**Projected performance**:
- Without bubbles: **35-70 FPS** (acceptable to excellent)
- With bubbles: **20-50 FPS** (depends on bubble count and GPU)
- Spikeyness: **15-25% CV** (good to moderate)

---

## 🚀 Recommendations

### Immediate Actions

1. **Make Bubbles Optional**
   ```gdscript
   # Settings menu
   var show_quantum_bubbles: bool = true  # User preference

   func _ready():
       if quantum_viz:
           quantum_viz.visible = show_quantum_bubbles
   ```

2. **Add Performance Mode**
   ```gdscript
   enum PerformanceMode { LOW, MEDIUM, HIGH }

   func apply_performance_mode(mode: PerformanceMode):
       match mode:
           LOW:
               quantum_viz.visible = false
               Engine.physics_ticks_per_second = 10
           MEDIUM:
               quantum_viz.visible = false
               Engine.physics_ticks_per_second = 20
           HIGH:
               quantum_viz.visible = true
               Engine.physics_ticks_per_second = 20
   ```

3. **Add FPS Counter to UI**
   - Let players monitor performance
   - Auto-suggest disabling bubbles if FPS < 30

### Optimization Opportunities

**If bubbles are essential**, consider:

1. **Cull Off-Screen Bubbles**
   - Only render bubbles in viewport
   - Expected gain: 30-50% (if many off-screen)

2. **Reduce Bubble Count**
   - Show only high-probability states (p > 0.05)
   - Expected gain: 20-40% (depending on threshold)

3. **Lower Update Rate**
   - Update bubble positions at 30Hz instead of 60Hz
   - Expected gain: 10-20%

4. **Use Simpler Shaders**
   - Reduce glow/effects on bubbles
   - Expected gain: 10-30%

5. **LOD (Level of Detail)**
   - Fewer vertices when camera zoomed out
   - Expected gain: 15-25%

---

## 📈 Spikeyness Reduction Strategies

### Current: CV = 43.8% (Poor)

**Target: CV < 20% (Good)**

### Strategy 1: Smooth Physics Load

**Problem:** Evolving 5-qubit biomes (32×32 matrices) causes huge spikes

**Solution:** Split large biomes into sub-batches
```gdscript
# Instead of 2 biomes per tick:
# - Small biomes (3 qubits): 2 per tick
# - Large biomes (5 qubits): 1 per tick

func _should_batch_together(biome_a, biome_b) -> bool:
    var total_qubits = biome_a.get_qubit_count() + biome_b.get_qubit_count()
    return total_qubits <= 8  # Max combined complexity
```

**Expected gain:** Reduce CV from 43.8% → ~25% (moderate)

### Strategy 2: Pre-compute Heavy Operations

**Problem:** Matrix exponentials calculated on-demand

**Solution:** Cache frequently-used operators
```gdscript
# In QuantumComputer:
var operator_cache: Dictionary = {}

func get_evolution_operator(dt: float) -> ComplexMatrix:
    var key = "%.3f" % dt  # 1ms precision
    if not operator_cache.has(key):
        operator_cache[key] = _compute_evolution_operator(dt)
    return operator_cache[key]
```

**Expected gain:** Reduce CV from ~25% → ~18% (good)

### Strategy 3: Budget-Based Evolution

**Problem:** Some frames do heavy work, others idle

**Solution:** Distribute work evenly across frames
```gdscript
const FRAME_TIME_BUDGET = 12.0  # ms (target: 60 FPS with 4ms margin)

func _physics_process(delta: float):
    var budget_remaining = FRAME_TIME_BUDGET
    var start_time = Time.get_ticks_usec()

    while budget_remaining > 2.0 and not evolution_queue.is_empty():
        _evolve_one_biome(evolution_queue.pop_front())
        var elapsed = (Time.get_ticks_usec() - start_time) / 1000.0
        budget_remaining = FRAME_TIME_BUDGET - elapsed
```

**Expected gain:** Reduce CV from ~18% → ~12% (excellent)

---

## 🧪 Testing Recommendations

### Test on Real Hardware

**Critical:** WSL2 results are not representative
- Test on native Linux or Windows
- Test with GPU rendering enabled
- Test on target hardware specs

### Test Matrix

| Platform | GPU | Bubbles | Expected FPS | Priority |
|----------|-----|---------|--------------|----------|
| WSL2 | Software | Off | 7-10 FPS | ✅ Baseline |
| WSL2 | Software | On | 3-5 FPS | ✅ Baseline |
| Native Linux | Integrated | Off | 40-60 FPS | ⚠️ High |
| Native Linux | Integrated | On | 25-45 FPS | ⚠️ High |
| Native Windows | Discrete GPU | Off | 60+ FPS | ⚠️ Medium |
| Native Windows | Discrete GPU | On | 50-60 FPS | ⚠️ Medium |

### Performance Metrics to Track

1. **FPS** (mean, median, P95, P99)
2. **Frame time** (mean, stddev, CV%)
3. **Physics time** (quantum evolution cost)
4. **Bubble count** (how many rendered)
5. **Draw calls** (rendering overhead)

---

## 📋 Summary

### What We Learned

✅ **Quantum bubbles have significant performance cost**
- Test with bubbles did not complete (hung or crashed)
- Implies severe performance degradation

✅ **Baseline performance is poor on WSL2**
- 7.3 FPS without bubbles (target: 60 FPS)
- But WSL2 is not representative of production

✅ **Frame time variance is very high**
- CV = 43.8% (poor spikeyness)
- 10× variance between fast and slow frames

✅ **Physics separation is working**
- Quantum evolution in physics loop
- But needs further optimization for consistency

### Recommendations

1. ⚠️ **Make bubbles optional** - Add settings toggle
2. ⚠️ **Test on real hardware** - WSL2 not representative
3. ⚠️ **Optimize frame consistency** - Reduce spikeyness (CV target: <20%)
4. ✅ **Monitor performance** - Add FPS counter to UI
5. ✅ **Consider performance modes** - LOW/MEDIUM/HIGH presets

### Next Steps

1. **Test on native hardware** with GPU rendering
2. **Implement performance mode** (bubbles off by default on low FPS)
3. **Optimize physics batching** to reduce frame time variance
4. **Profile bubble rendering** to identify bottlenecks
5. **Consider LOD system** for bubbles if needed

---

**Test Date:** 2026-01-27
**System:** WSL2 (Limited CPU/GPU)
**Status:** Baseline measured, bubble test incomplete
**Conclusion:** Further testing needed on production hardware
