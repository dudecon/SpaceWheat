# Performance Action Plan

## 🎯 Goal

**Achieve BETTER performance than pre-physics-split baseline**
- Pre-split: 28 FPS (headless, batched evolution)
- Target: **>= 30 FPS** (with rendering, physics split)

## 🔴 Current Issues

### 1. Matrix Transfer is NOT Sparse-Optimized

**Problem**: Transferring DENSE 32×32 matrices (16 KB each)
- Current: `PackedFloat64Array` with ALL elements (even zeros)
- Expected sparsity: 60-98% (most elements are near-zero)
- Waste: **10-15 KB per large matrix** unnecessarily transferred

**Impact**:
- StarterForest + Village batch: **32 KB per physics tick**
- At 10Hz: **320 KB/second** bandwidth waste
- Adds **~5ms per large biome evolution**

**Fix**:
- Implement CSR (Compressed Sparse Row) format
- Auto-detect sparsity and choose format
- Expected savings: **50-90% bandwidth** = **~5-10ms per tick**

### 2. Bubbles May Not Be Visible

**Problem**: quantum_viz is hidden or bubbles not created
- Bubble system is plot-driven (needs terminal_bound signals)
- May not be properly wired up
- User reported "didn't see any bubbles"

**Fix**:
- Verify bubble creation on terminal binding
- Check signal connections
- Ensure bubbles are actually rendered

### 3. Frame Spikeyness is Extreme

**Problem**: CV = 43.8% (very spiky)
- Some frames: 41ms (smooth)
- Some frames: 423ms (10× slower!)
- **Target: CV < 20%** (acceptable)

**Causes**:
- Large matrix transfers during physics ticks
- 5-qubit biomes (32×32 matrices) cause spikes
- GC pauses during evolution

**Fixes**:
- Sparse matrix transfer (primary)
- Budget-based evolution scheduling
- Pre-compute/cache heavy operators

### 4. Baseline Performance Regression

**Problem**: Performance is WORSE than before physics split
- Pre-split (headless, batched): 28 FPS
- Post-split (headless, physics): 24.8 FPS
- **Post-split (visual, rendering): 7.3 FPS** 🔴

**This is unacceptable** - we should be the same or better!

**Analysis**:
- WSL2 + software rendering: 3-5× slower than native
- But even accounting for that, something is wrong
- Rendering overhead too high OR physics separation not working properly

**Fixes**:
- Investigate rendering pipeline
- Check if physics is actually non-blocking
- Profile to find the real bottleneck

---

## 📋 Action Items (Priority Order)

### PRIORITY 1: Matrix Sparsity Analysis (30 min)

**Task**: Measure actual sparsity of runtime matrices

**Test**: `Tests/MatrixSparsityAnalysis.gd`

**Expected outcome**:
- Density matrices: 60-80% sparse
- Hamiltonians: 95-98% sparse
- Lindblad operators: 95-99% sparse

**Decision**: IF >30% sparse → Implement sparse transfer (Priority 2)

---

### PRIORITY 2: Sparse Matrix Transfer (4-6 hours)

**ONLY IF** Priority 1 confirms >30% sparsity

**Implementation**:

1. **Add CSR methods to C++** (2 hours)
   ```cpp
   // In quantum_matrix_native.cpp
   Dictionary pack_matrix_csr(const Eigen::MatrixXcd& mat, int dim) {
       // Count non-zeros
       int nnz = 0;
       for (int i = 0; i < dim; i++)
           for (int j = 0; j < dim; j++)
               if (abs(mat(i,j)) > 1e-12) nnz++;

       // Allocate CSR arrays
       PackedInt32Array row_ptr, col_idx;
       PackedFloat64Array values_real, values_imag;

       // ... fill CSR format ...

       return {
           "format": "csr",
           "dim": dim,
           "nnz": nnz,
           "row_ptr": row_ptr,
           "col_idx": col_idx,
           "values_real": values_real,
           "values_imag": values_imag
       };
   }
   ```

2. **Add auto-detection in GDScript** (1 hour)
   ```gdscript
   # In ComplexMatrix wrapper
   func to_packed_auto():
       var sparsity = estimate_sparsity()
       if sparsity > 0.3:
           return native.to_packed_csr()
       else:
           return native.to_packed()
   ```

3. **Update QuantumComputer to use sparse** (1 hour)
   - Modify evolve() to use auto format
   - Test with all biomes

4. **Benchmark improvement** (1 hour)
   - Run PerformanceBenchmark again
   - Verify 5-10ms savings per tick

**Expected gain**: **+20-30% FPS** from bandwidth reduction

---

### PRIORITY 3: Fix Bubble Visibility (1-2 hours)

**Task**: Ensure bubbles are actually visible and rendering

**Steps**:

1. **Verify signal connections** (15 min)
   - Check terminal_bound signal is emitted
   - Check quantum_viz receives it
   - Check bubbles are created

2. **Test bubble creation** (15 min)
   - Plant plots manually
   - Check quantum_nodes array
   - Print bubble count

3. **Force bubble visibility** (30 min)
   - Ensure quantum_viz.visible = true
   - Queue redraw after visibility change
   - Check z-index / layer ordering

4. **Run visual test** (30 min)
   - Use `BubbleTestFixed.gd`
   - Verify bubbles appear on screen
   - Measure performance impact

**Expected outcome**: Bubbles visible, performance measured accurately

---

### PRIORITY 4: Reduce Frame Spikeyness (2-3 hours)

**Goal**: Reduce CV from 43.8% → < 20%

**Strategies**:

1. **Smart batching** (1 hour)
   - Don't batch two 5-qubit biomes together
   - Pair large+small biomes instead
   ```gdscript
   func _should_batch(biome_a, biome_b) -> bool:
       var total_qubits = biome_a.num_qubits + biome_b.num_qubits
       return total_qubits <= 8  # Max 256 elements combined
   ```

2. **Budget-based evolution** (1 hour)
   - Set frame time budget (12ms @ 60 FPS target)
   - Only evolve if budget allows
   - Defer expensive evolutions to next tick
   ```gdscript
   const FRAME_BUDGET_MS = 12.0

   func _physics_process(delta):
       var start = Time.get_ticks_usec()
       var budget = FRAME_BUDGET_MS

       while budget > 2.0 and has_work():
           do_one_evolution()
           var elapsed = (Time.get_ticks_usec() - start) / 1000.0
           budget = FRAME_BUDGET_MS - elapsed
   ```

3. **Operator caching** (30 min)
   - Cache evolution operators for common dt values
   - Reduces matrix exponential computations

**Expected gain**: CV from 43.8% → 18-22% (acceptable)

---

### PRIORITY 5: Profile Rendering Pipeline (1-2 hours)

**Task**: Find why visual rendering is so slow (7.3 FPS)

**Tools**:
- Godot profiler (run with --profiler flag)
- Custom timing markers
- Draw call counter

**Check**:
1. How many draw calls per frame?
2. Is GPU actually being used?
3. What's the bottleneck: CPU or GPU?
4. Is double-buffering working?

**Hypothesis**: WSL2 software rendering is the culprit
- If true: Performance will be fine on real hardware
- If false: Need to optimize rendering code

---

## 📊 Expected Results

### After Priority 1 (Sparsity Analysis)

**Know**: Actual matrix sparsity (decision point)

### After Priority 2 (Sparse Transfer)

**Metrics**:
- Headless FPS: 24.8 → **30-35 FPS** (+20-40%)
- Visual FPS: 7.3 → **9-10 FPS** (+20-35%)
- Frame spikeyness: CV 43.8% → **35-38%** (improved but still needs work)

**Conclusion**: Bandwidth-limited performance improved

### After Priority 3 (Bubble Fix)

**Metrics**:
- Bubbles visible: YES
- Bubble rendering cost: Measured accurately
- FPS with bubbles: Known (can make tradeoff decision)

### After Priority 4 (Spikeyness Reduction)

**Metrics**:
- Headless FPS: 30-35 → **32-38 FPS** (marginal)
- Visual FPS: 9-10 → **10-12 FPS** (marginal)
- Frame spikeyness: CV 35-38% → **18-22%** ✅ (major improvement)

**Conclusion**: Frame times consistent, gameplay feels smooth

### After Priority 5 (Rendering Profile)

**Metrics**:
- Understand bottleneck: CPU vs GPU
- Verify WSL2 is the limitation
- Confirm real hardware will be fine

---

## 🎮 Production Projections

### After All Optimizations

**WSL2 (software rendering)**:
- FPS: 10-12 FPS
- Spikeyness: CV ~20% (good)
- **Still slow but consistent**

**Native Hardware (GPU rendering)**:
- FPS: **50-70 FPS** (5-6× WSL2 performance)
- Spikeyness: CV ~15% (excellent)
- **Smooth gameplay**

**Calculation**:
- WSL2 → Native: 3-4× faster (GPU acceleration)
- Debug → Release: 1.5× faster (optimizations)
- Sparse matrices: 1.2× faster (bandwidth savings)
- **Total: 10 FPS × 5.4 = 54 FPS** (reasonable target)

---

## ✅ Success Criteria

### Minimum Acceptable

- [ ] Headless FPS: >= 28 FPS (match pre-split baseline)
- [ ] Frame spikeyness: CV < 25% (good consistency)
- [ ] Bubbles: Visible and measurable
- [ ] Sparse matrices: Implemented if >30% sparse

### Target (Stretch Goals)

- [ ] Headless FPS: >= 35 FPS (better than baseline)
- [ ] Frame spikeyness: CV < 20% (excellent consistency)
- [ ] Production estimate: >= 50 FPS (playable)

---

## 🔧 Testing Protocol

### After Each Priority

1. Run `PerformanceBenchmark.gd` (full 300-frame test)
2. Run `QuickSmoothnessTest.gd` (frame distribution)
3. Compare to previous results
4. Document gains in PERFORMANCE_OPTIMIZATION_SUMMARY.md

### Regression Testing

- Always compare to baseline (28 FPS pre-split)
- Never ship if performance is worse than baseline
- Rollback changes that hurt performance

---

## 📝 Next Session Goals

**Immediate (this session)**:
1. ✅ Complete matrix sparsity analysis
2. ✅ Fix bubble visibility test
3. ✅ Run fixed performance test

**Next session**:
1. Implement sparse matrix transfer (if justified)
2. Measure performance improvement
3. Tackle frame spikeyness

**Long-term**:
1. Profile on native hardware
2. Verify 50+ FPS in production
3. Ship with performance modes (bubbles optional)

---

## 🚀 Action: START WITH PRIORITY 1

**Run**: `godot --headless --script res://Tests/MatrixSparsityAnalysis.gd`

**Goal**: Get actual sparsity numbers to make informed decisions

**Next**: Based on results, implement sparse transfer or move to other priorities
