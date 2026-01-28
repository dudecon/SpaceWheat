# Matrix Transfer Analysis: Dense vs Sparse

## 🔍 Current Implementation

### Transfer Format: DENSE PackedFloat64Array

**File**: `native/src/quantum_matrix_native.cpp`

**Format**:
```cpp
// Pack matrix: dim × dim × 2 float64 values (real + imaginary)
PackedFloat64Array pack_matrix(const Eigen::MatrixXcd& mat, int dim) {
    PackedFloat64Array packed;
    packed.resize(dim * dim * 2);  // EVERY element transferred
    double* ptr = packed.ptrw();

    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            ptr[idx] = mat(i, j).real();      // Transfer even if zero
            ptr[idx + 1] = mat(i, j).imag();  // Transfer even if zero
        }
    }
    return packed;
}
```

**Transfer Cost per Matrix:**

| Dimension | Elements | Transfer Size | Per Biome Tick |
|-----------|----------|---------------|----------------|
| 8×8 (3 qubits) | 64 | **1,024 bytes** | 1 KB |
| 16×16 (4 qubits) | 256 | **4,096 bytes** | 4 KB |
| 32×32 (5 qubits) | 1024 | **16,384 bytes** | **16 KB** |

**Total per Evolution Tick (2 biomes batched):**
- BioticFlux (8×8): 1 KB
- StellarForges (8×8): 1 KB
- **FungalNetworks (16×16): 4 KB**
- VolcanicWorlds (8×8): 1 KB
- **StarterForest (32×32): 16 KB**
- **Village (32×32): 16 KB**

**Worst case batch**: StarterForest + Village = **32 KB per tick**

At 10Hz evolution rate: **320 KB/second** just for density matrices!

---

## 📊 Expected Sparsity

### Quantum Density Matrices

**Pure states**: ρ = |ψ⟩⟨ψ| → **Rank 1** → Very sparse
- Only O(dim) non-zero elements
- Example: 32×32 pure state has ~32 significant elements (rest near-zero)
- **Sparsity: ~90-95%** for pure states

**Mixed states**: ρ = Σ p_i |ψ_i⟩⟨ψ_i|
- Depends on mixedness
- Highly mixed: ~10-20% sparse
- Moderately mixed: ~50-70% sparse
- **Expected game states: 60-80% sparse** (biome attractors have structure)

### Hamiltonians

**Quantum Hamiltonians** are typically **very sparse**:
- Local interactions only (nearest neighbor coupling)
- Few-body terms only (1-qubit, 2-qubit interactions)
- Example: Heisenberg model on 5 qubits
  - Only ~20 non-zero matrix elements out of 1024
  - **Sparsity: ~98%**

**Our Hamiltonians**:
- Built from Pauli operators (σ_x, σ_y, σ_z)
- Sum of 1-qubit and 2-qubit terms
- **Expected sparsity: 95-98%**

### Lindblad Operators

**Jump operators** L_k are typically sparse:
- Usually single-qubit or two-qubit operators
- Example: Decay operator σ^- on qubit 0 in 32×32 space
  - Only 32 non-zero elements (one per row/column)
  - **Sparsity: ~97%**

**Our Lindblad operators**:
- Emoji-specific decay/pump
- Usually affect 1-2 qubits at a time
- **Expected sparsity: 95-99%**

---

## 💾 Sparse Matrix Format Proposal

### Format: Coordinate List (COO)

```gdscript
# Sparse matrix representation
{
    "dim": int,                      # Matrix dimension
    "nnz": int,                      # Number of non-zeros
    "rows": PackedInt32Array,        # Row indices
    "cols": PackedInt32Array,        # Column indices
    "values_real": PackedFloat64Array,  # Real parts
    "values_imag": PackedFloat64Array   # Imaginary parts
}
```

**Transfer cost**:
- Indices: `nnz × 2 × 4 bytes` (int32 row/col pairs)
- Values: `nnz × 2 × 8 bytes` (float64 real/imag pairs)
- **Total: `nnz × 24 bytes + 8 bytes overhead`**

### Bandwidth Savings

**Pure density matrix (32×32, 95% sparse)**:
- Dense: 16,384 bytes
- Sparse: ~1,536 non-zeros × 24 = 36,864 bytes... **WAIT, this is worse!**

**Problem**: Coordinate format has 24 bytes overhead per element!

---

## 🚀 Better Sparse Format: Compressed Sparse Row (CSR)

### Format: CSR (Better for Dense Rows)

```cpp
struct SparseMatrix {
    int dim;
    int nnz;
    int* row_ptr;        // Size: (dim+1) × 4 bytes
    int* col_indices;    // Size: nnz × 4 bytes
    double* values_real; // Size: nnz × 8 bytes
    double* values_imag; // Size: nnz × 8 bytes
};
```

**Transfer cost**:
- Row pointers: `(dim+1) × 4 bytes`
- Column indices: `nnz × 4 bytes`
- Values: `nnz × 16 bytes` (complex)
- **Total: `(dim+1) × 4 + nnz × 20 bytes`**

**32×32 matrix with 5% density** (51 non-zeros):
- Dense: 16,384 bytes
- CSR: 132 + 204 + 816 = **1,152 bytes**
- **Savings: 93%**

**32×32 matrix with 20% density** (205 non-zeros):
- Dense: 16,384 bytes
- CSR: 132 + 820 + 3,280 = **4,232 bytes**
- **Savings: 74%**

---

## 🎯 Recommendation

### When to Use Sparse

**IF matrices are >30% sparse:**
- ✅ IMPLEMENT CSR transfer format
- Expected bandwidth reduction: **50-90%**
- Reduces GDScript ↔ C++ handoff overhead

**Implementation**:
1. Add CSR pack/unpack methods to QuantumMatrixNative
2. Add sparsity detection in GDScript wrapper
3. Auto-select format based on sparsity

```gdscript
# In ComplexMatrix wrapper
func to_packed_auto():
    var sparsity = _calculate_sparsity()
    if sparsity > 0.3:  # >30% sparse
        return _to_packed_csr()
    else:
        return _to_packed_dense()
```

### IF matrices are <30% sparse:

- ⚠️ Dense format is fine
- Sparse overhead not worth complexity

---

## 📉 Expected Performance Impact

### Current Bottleneck

**Per evolution tick** (StarterForest + Village batch):
- Density matrix transfer: 32 KB (2 × 16 KB)
- Hamiltonian cache: 0 bytes (computed once)
- Lindblad operators: ~48 KB (6 operators × 8 KB each)
- **Total: ~80 KB per tick**

At 10Hz: **800 KB/second bandwidth**

### With Sparse Transfer (80% sparsity)

- Density matrix: 6.4 KB (80% savings)
- Lindblad operators: 9.6 KB (80% savings)
- **Total: ~16 KB per tick**

At 10Hz: **160 KB/second bandwidth**

**Savings: 640 KB/second (80% reduction)**

### Frame Time Impact

**Estimated handoff time reduction**:
- Dense transfer: ~3ms per biome (memcpy + unpacking)
- Sparse transfer: ~0.6ms per biome (smaller memcpy)
- **Savings: ~2.4ms per biome**

For 2-biome batch: **~5ms saved per physics tick**

At 20Hz physics: **~100ms saved per second** = 10% CPU time!

---

## 🔬 Next Steps

1. **Measure actual sparsity** of runtime matrices
   - Run `MatrixSparsityAnalysis.gd` test
   - Sample 100 evolution ticks
   - Calculate average sparsity

2. **IF >30% sparse**:
   - Implement CSR format in C++
   - Add auto-detection in GDScript
   - Benchmark performance improvement

3. **IF <30% sparse**:
   - Dense format is optimal
   - Focus optimization elsewhere

---

## 🧪 Sparsity Measurement

**Test**: `Tests/MatrixSparsityAnalysis.gd`

**What it measures**:
- Density matrix sparsity per biome
- Hamiltonian sparsity
- Lindblad operator sparsity
- Transfer cost savings estimate

**Expected results**:
- Pure quantum states: 90-95% sparse
- Attractors (game states): 60-80% sparse
- Hamiltonians: 95-98% sparse
- Lindblad operators: 95-99% sparse

**If results confirm >30% sparsity**:
- **PRIORITY**: Implement sparse transfer
- **Expected gain**: 5-10ms per physics tick
- **Impact**: Reduces frame spikeyness significantly

---

## 🎮 Impact on Gameplay

### Current Performance Issues

1. **Frame spikeyness (CV = 43.8%)**
   - Cause: Large matrix transfers during physics ticks
   - Biomes with 32×32 matrices (StarterForest, Village) spike frames

2. **Low baseline FPS (7.3 FPS)**
   - Cause: Multiple factors (WSL2, rendering, quantum computation)
   - Sparse transfer helps but won't fix everything

### Expected Improvement with Sparse

**Frame time variance reduction**:
- Current: Large biomes add 5-10ms spike
- With sparse: Large biomes add 1-2ms spike
- **CV reduction: 43.8% → ~25% (still needs more work)**

**Baseline FPS improvement**:
- Current: 7.3 FPS (140ms/frame)
- With sparse: ~8.5 FPS (120ms/frame)
- **+16% FPS** (modest but measurable)

**Production projection** (with GPU):
- Current estimate: 35-70 FPS
- With sparse: **42-85 FPS**
- **+20% FPS** in production

---

## Summary

✅ **Dense transfer is wasteful** - Matrices are likely 60-98% sparse

✅ **Sparse format can save 50-90% bandwidth** - Significant gain

✅ **CSR is the right format** - Better than COO for our use case

⚠️ **Need to measure first** - Run sparsity analysis test

🚀 **High priority optimization** - Could save 5-10ms per tick

**Next action**: Complete sparsity measurement, then implement if justified
