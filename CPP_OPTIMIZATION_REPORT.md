# C++ Native Engine Optimization Report
## SpaceWheat Quantum Evolution Pipeline → Vis Cache

**Scope**: Optimize the C++ physics/evolution pipeline that feeds the viz_cache
**Complement**: Another bot handles viz_cache → Godot rendering

---

## ARCHITECTURE OVERVIEW

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          HOT PATH (110ms/frame)                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  GDScript (BiomeEvolutionBatcher.gd)                                    │
│      │                                                                  │
│      ▼ evolve_all_lookahead(biome_rhos, 5 steps, 0.1s, 0.02s)          │
│      │                                                                  │
│  ════════════════════ C++/GDScript Bridge ════════════════════         │
│      │                                                                  │
│      ▼                                                                  │
│  C++ (MultiBiomeLookaheadEngine)                                        │
│      │                                                                  │
│      ├─► for each biome (6 biomes):                                    │
│      │       │                                                          │
│      │       ▼ _evolve_biome_steps(biome_id, rho, 5, 0.1, 0.02)        │
│      │           │                                                      │
│      │           ├─► for each step (5 steps):                          │
│      │           │       │                                              │
│      │           │       ├─► engine->evolve()        ████ 60-70%       │
│      │           │       ├─► compute_bloch_metrics() ██   15-20%       │
│      │           │       ├─► compute_purity()        █    5%           │
│      │           │       └─► compute_all_MI()        ███  15-20%       │
│      │           │                                                      │
│      │           └─► _build_icon_map()                                 │
│      │                                                                  │
│      ▼                                                                  │
│  Result Dictionary { results, bloch_steps, purity_steps, mi_steps }    │
│      │                                                                  │
│  ════════════════════ C++/GDScript Bridge ════════════════════         │
│      │                                                                  │
│      ▼                                                                  │
│  GDScript → biome.viz_cache.update_*()                                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## HOT PATH ANALYSIS

### Call Stack Per Frame

```
evolve_all_lookahead()
├── biome 0 (CyberDebtMegacity, 5 qubits = 32D)
│   └── _evolve_biome_steps() × 5 steps
│       ├── evolve() × 5 substeps @ 0.02s each
│       │   └── evolve_step() - Lindblad master equation
│       │       ├── Hρ - ρH (32×32 dense × dense)
│       │       └── LρL† - ½{L†L,ρ} × 9 operators (sparse × dense × sparse)
│       ├── compute_bloch_metrics_from_packed()
│       │   └── partial_trace_single() × 5 qubits
│       ├── compute_purity_from_packed()
│       │   └── Tr(ρ²) = Σ|ρᵢⱼ|² (O(dim²))
│       └── compute_all_mutual_information()
│           └── mutual_information() × 10 pairs (5 choose 2)
│               ├── partial_trace_single() × 2
│               ├── partial_trace_complement()
│               └── von_neumann_entropy() × 3 (eigendecomp)
│
├── biome 1 (StellarForges, 3 qubits = 8D) ... similar
├── biome 2 (VolcanicWorlds, 3 qubits = 8D) ... similar
├── biome 3 (BioticFlux, 3 qubits = 8D) ... similar
├── biome 4 (FungalNetworks, 4 qubits = 16D) ... similar
└── biome 5 (TidalPools, 6 qubits = 64D) ← MOST EXPENSIVE
    └── _evolve_biome_steps() × 5 steps
        ├── evolve() × 5 substeps
        │   └── evolve_step() - 64×64 dense matrices, 7 Lindblad operators
        ├── compute_bloch_metrics_from_packed()
        │   └── partial_trace_single() × 6 qubits
        └── compute_all_mutual_information()
            └── mutual_information() × 15 pairs (6 choose 2)
                └── von_neumann_entropy() × 45 eigendecompositions!
```

---

## PROFILED COST BREAKDOWN (estimated from frame budget)

### Per-Frame Totals (6 biomes × 5 steps = 30 evolution calls)

| Component | Cost | % of 110ms | Hot Spot |
|-----------|------|------------|----------|
| `evolve()` | ~65ms | 59% | Lindblad operator application |
| `compute_all_MI()` | ~25ms | 23% | Eigendecomposition in von_neumann_entropy |
| `compute_bloch_metrics()` | ~12ms | 11% | partial_trace_single × num_qubits |
| `compute_purity()` | ~3ms | 3% | Simple O(dim²) loop |
| `pack/unpack` | ~3ms | 3% | PackedFloat64Array ↔ Eigen::MatrixXcd |
| `_build_icon_map()` | ~2ms | 2% | Dictionary operations |

### Per-Biome Cost (5 steps each)

| Biome | Dim | Qubits | Lindblads | MI Pairs | Est. Cost |
|-------|-----|--------|-----------|----------|-----------|
| TidalPools | 64 | 6 | 7 | 15 | **~35ms** ← 32% of total |
| CyberDebtMegacity | 32 | 5 | 9 | 10 | ~25ms |
| FungalNetworks | 16 | 4 | 5 | 6 | ~15ms |
| StellarForges | 8 | 3 | 2 | 3 | ~10ms |
| VolcanicWorlds | 8 | 3 | 5 | 3 | ~12ms |
| BioticFlux | 8 | 3 | 6 | 3 | ~13ms |

---

## OPTIMIZATION RECOMMENDATIONS

### Priority 1: MUTUAL INFORMATION COMPUTATION (Save ~20ms)

**Current Implementation** (`quantum_evolution_engine.cpp:419-433`):
```cpp
double QuantumEvolutionEngine::mutual_information(
    const Eigen::MatrixXcd& rho, int qubit_a, int qubit_b, int num_qubits) const {
    // I(A:B) = S(A) + S(B) - S(AB)
    Eigen::MatrixXcd rho_a = partial_trace_single(rho, qubit_a, num_qubits);
    Eigen::MatrixXcd rho_b = partial_trace_single(rho, qubit_b, num_qubits);
    Eigen::MatrixXcd rho_ab = partial_trace_complement(rho, qubit_a, qubit_b, num_qubits);

    double S_a = von_neumann_entropy(rho_a);   // 2×2 eigendecomp
    double S_b = von_neumann_entropy(rho_b);   // 2×2 eigendecomp
    double S_ab = von_neumann_entropy(rho_ab); // 4×4 eigendecomp

    return std::max(S_a + S_b - S_ab, 0.0);
}
```

**Problem**: For 6 qubits (TidalPools), this runs 15× per step × 5 steps = **75 calls**
Each call does 3 eigendecompositions = **225 eigendecomps per biome per refill**

**Optimization 1.1: Cache Single-Qubit Entropies**
```cpp
// In compute_all_mutual_information(), compute all S(i) once
std::vector<double> single_entropies(num_qubits);
std::vector<Eigen::MatrixXcd> single_rhos(num_qubits);

for (int i = 0; i < num_qubits; i++) {
    single_rhos[i] = partial_trace_single(rho, i, num_qubits);
    single_entropies[i] = von_neumann_entropy(single_rhos[i]);
}

// Then for each pair, only compute S(AB)
for (int i = 0; i < num_qubits; i++) {
    for (int j = i + 1; j < num_qubits; j++) {
        Eigen::MatrixXcd rho_ab = partial_trace_complement(rho, i, j, num_qubits);
        double S_ab = von_neumann_entropy(rho_ab);
        double mi = single_entropies[i] + single_entropies[j] - S_ab;
        ptr[idx++] = std::max(mi, 0.0);
    }
}
```

**Impact**: Reduces eigendecomps from 3×n(n-1)/2 to n + n(n-1)/2 = n(n+1)/2
For 6 qubits: 45 → 21 eigendecomps (**53% reduction**)

**File**: `native/src/quantum_evolution_engine.cpp:435-461`

---

**Optimization 1.2: Skip MI Computation When Not Needed**

The MI values drive edge rendering in the force graph. If edges aren't visible or the game is paused, skip MI entirely.

```cpp
// Add parameter to evolve_all_lookahead
Dictionary evolve_all_lookahead(const Array& biome_rhos, int steps,
                                float dt, float max_dt, bool compute_mi = true);

// In _evolve_biome_steps:
if (compute_mi) {
    out.mi_steps.push_back(engine->compute_all_mutual_information(evolved_rho, num_qubits));
} else {
    out.mi_steps.push_back(PackedFloat64Array());  // Empty placeholder
}
```

**Impact**: Save ~25ms when MI not needed (e.g., zoomed out, edges hidden)

**Files**:
- `native/src/multi_biome_lookahead_engine.h:113` - Add parameter
- `native/src/multi_biome_lookahead_engine.cpp:284` - Conditional MI

---

**Optimization 1.3: Approximate MI with Classical Correlations**

For gameplay purposes, exact quantum MI may be overkill. Use classical correlation:

```cpp
double classical_correlation(const Eigen::MatrixXcd& rho, int qubit_a, int qubit_b, int num_qubits) const {
    // Compute p(00), p(01), p(10), p(11) from diagonal
    // Much faster than full MI (no eigendecomp)
    double p00 = 0.0, p01 = 0.0, p10 = 0.0, p11 = 0.0;

    for (int state = 0; state < (1 << num_qubits); state++) {
        double prob = rho(state, state).real();
        int bit_a = (state >> qubit_a) & 1;
        int bit_b = (state >> qubit_b) & 1;
        if (bit_a == 0 && bit_b == 0) p00 += prob;
        else if (bit_a == 0 && bit_b == 1) p01 += prob;
        else if (bit_a == 1 && bit_b == 0) p10 += prob;
        else p11 += prob;
    }

    // Classical mutual info: I = H(A) + H(B) - H(A,B)
    // Using joint probabilities (no eigendecomp needed)
    auto H = [](double p) { return (p > 1e-10) ? -p * std::log2(p) : 0.0; };
    double H_a = H(p00 + p01) + H(p10 + p11);
    double H_b = H(p00 + p10) + H(p01 + p11);
    double H_ab = H(p00) + H(p01) + H(p10) + H(p11);

    return std::max(H_a + H_b - H_ab, 0.0);
}
```

**Impact**: Eliminates all eigendecompositions for MI (~20ms saved)
**Trade-off**: Loses quantum correlation (entanglement) information

**File**: `native/src/quantum_evolution_engine.cpp` - Add new method

---

### Priority 2: EVOLUTION STEP OPTIMIZATION (Save ~15-20ms)

**Current Implementation** (`quantum_evolution_engine.cpp:229-273`):
```cpp
PackedFloat64Array QuantumEvolutionEngine::evolve(const PackedFloat64Array& rho_data, float dt, float max_dt) {
    // Subcycling for numerical stability
    int num_steps = static_cast<int>(std::ceil(dt / max_dt));  // 5 substeps
    float sub_dt = dt / num_steps;

    Eigen::MatrixXcd rho = unpack_dense(rho_data);  // O(dim²) copy

    for (int step = 0; step < num_steps; step++) {
        Eigen::MatrixXcd drho = Eigen::MatrixXcd::Zero(m_dim, m_dim);

        // Hamiltonian: -i[H,ρ]
        if (m_has_hamiltonian) {
            Eigen::MatrixXcd commutator = m_hamiltonian * rho - rho * m_hamiltonian;
            drho += std::complex<double>(0.0, -1.0) * commutator;
        }

        // Lindblad: Σ(LρL† - ½{L†L,ρ})
        for (size_t k = 0; k < m_lindblads.size(); k++) {
            Eigen::MatrixXcd L_rho_Ldag = (L * rho) * L_dag;  // 2 sparse×dense
            Eigen::MatrixXcd anticomm = LdagL * rho + rho * LdagL;  // 2 sparse×dense
            drho += L_rho_Ldag - 0.5 * anticomm;
        }

        rho += static_cast<double>(sub_dt) * drho;  // Euler step
        cap_trace_and_clamp_diag(rho);
    }

    return pack_dense(rho);  // O(dim²) copy
}
```

**Optimization 2.1: Reduce Substeps for Small Systems**

Small systems (dim ≤ 16) are numerically stable with fewer substeps:

```cpp
PackedFloat64Array QuantumEvolutionEngine::evolve(const PackedFloat64Array& rho_data, float dt, float max_dt) {
    // Adaptive substep count based on system size
    float effective_max_dt = max_dt;
    if (m_dim <= 8) {
        effective_max_dt = max_dt * 2.0;  // 8D systems: half substeps
    } else if (m_dim <= 16) {
        effective_max_dt = max_dt * 1.5;  // 16D systems: 33% fewer substeps
    }

    int num_steps = static_cast<int>(std::ceil(dt / effective_max_dt));
    // ...
}
```

**Impact**: 3 biomes at 8D go from 5→2-3 substeps = ~8ms saved

**File**: `native/src/quantum_evolution_engine.cpp:229-240`

---

**Optimization 2.2: Pre-allocate drho Matrix**

Current code allocates `drho` fresh each substep. Pre-allocate and reuse:

```cpp
// In header, add member:
Eigen::MatrixXcd m_drho_buffer;  // Reusable scratch space

// In finalize():
m_drho_buffer = Eigen::MatrixXcd::Zero(m_dim, m_dim);

// In evolve():
for (int step = 0; step < num_steps; step++) {
    m_drho_buffer.setZero();  // Much faster than allocating
    // ... use m_drho_buffer instead of local drho
}
```

**Impact**: Eliminates ~30 matrix allocations per frame = ~2ms saved

**Files**:
- `native/src/quantum_evolution_engine.h:108` - Add member
- `native/src/quantum_evolution_engine.cpp:166,248` - Initialize and use

---

**Optimization 2.3: Fused Lindblad Application**

Currently computes intermediate matrices. Fuse into single pass:

```cpp
// Current: 4 matrix operations per Lindblad
// L_rho_Ldag = (L * rho) * L_dag
// LdagL_rho = LdagL * rho
// rho_LdagL = rho * LdagL
// drho += L_rho_Ldag - 0.5 * (LdagL_rho + rho_LdagL)

// Optimized: 2 matrix operations + fused accumulation
Eigen::MatrixXcd L_rho = L * rho;  // Sparse × Dense
// Direct accumulation into drho, avoiding temporaries
for (int i = 0; i < m_dim; i++) {
    for (int j = 0; j < m_dim; j++) {
        std::complex<double> L_rho_Ldag_ij = 0.0;
        for (int k = 0; k < m_dim; k++) {
            L_rho_Ldag_ij += L_rho(i, k) * std::conj(L.coeff(j, k));
        }
        drho(i, j) += L_rho_Ldag_ij;
    }
}
// Similar fusion for anticommutator term
```

**Impact**: Reduces temporary matrix allocations, ~3-5ms saved

**File**: `native/src/quantum_evolution_engine.cpp:256-264`

---

**Optimization 2.4: Use RK4 Instead of Euler (Fewer Substeps Needed)**

Euler requires many substeps for stability. 4th-order Runge-Kutta needs fewer:

```cpp
PackedFloat64Array QuantumEvolutionEngine::evolve_rk4(const PackedFloat64Array& rho_data, float dt) {
    Eigen::MatrixXcd rho = unpack_dense(rho_data);

    auto compute_drho = [this](const Eigen::MatrixXcd& r) -> Eigen::MatrixXcd {
        Eigen::MatrixXcd dr = Eigen::MatrixXcd::Zero(m_dim, m_dim);
        if (m_has_hamiltonian) {
            dr += std::complex<double>(0.0, -1.0) * (m_hamiltonian * r - r * m_hamiltonian);
        }
        for (size_t k = 0; k < m_lindblads.size(); k++) {
            dr += (m_lindblads[k] * r) * m_lindblad_dags[k]
                - 0.5 * (m_LdagLs[k] * r + r * m_LdagLs[k]);
        }
        return dr;
    };

    Eigen::MatrixXcd k1 = compute_drho(rho);
    Eigen::MatrixXcd k2 = compute_drho(rho + 0.5 * dt * k1);
    Eigen::MatrixXcd k3 = compute_drho(rho + 0.5 * dt * k2);
    Eigen::MatrixXcd k4 = compute_drho(rho + dt * k3);

    rho += (dt / 6.0) * (k1 + 2.0*k2 + 2.0*k3 + k4);
    cap_trace_and_clamp_diag(rho);

    return pack_dense(rho);
}
```

**Impact**: Single RK4 step vs 5 Euler substeps = 4× fewer Lindblad applications = ~15ms saved
**Trade-off**: 4× more temporary matrices per step (higher memory)

**File**: `native/src/quantum_evolution_engine.cpp` - Add new method

---

### Priority 3: BLOCH METRICS OPTIMIZATION (Save ~5-8ms)

**Current Implementation** (`quantum_evolution_engine.cpp:521-567`):
Each call to `compute_bloch_metrics` runs `partial_trace_single` for every qubit.

**Optimization 3.1: Vectorized Bloch Computation**

Compute all qubit Bloch vectors in one pass through the density matrix:

```cpp
PackedFloat64Array QuantumEvolutionEngine::compute_bloch_metrics_vectorized(
    const Eigen::MatrixXcd& rho, int num_qubits) const {

    PackedFloat64Array out;
    out.resize(num_qubits * 8);
    double* ptr = out.ptrw();

    // Pre-allocate arrays for all qubits
    std::vector<double> p0s(num_qubits, 0.0);
    std::vector<double> p1s(num_qubits, 0.0);
    std::vector<std::complex<double>> rho01s(num_qubits, 0.0);

    // Single pass through diagonal and off-diagonal
    int dim = 1 << num_qubits;
    for (int state = 0; state < dim; state++) {
        double prob = rho(state, state).real();
        for (int q = 0; q < num_qubits; q++) {
            if ((state >> q) & 1) {
                p1s[q] += prob;
            } else {
                p0s[q] += prob;
            }
        }
    }

    // Off-diagonal (coherence) requires smarter iteration
    // For each qubit q, sum rho(i,j) where i and j differ only in bit q
    for (int q = 0; q < num_qubits; q++) {
        std::complex<double> coherence(0.0, 0.0);
        for (int base = 0; base < dim; base++) {
            if ((base >> q) & 1) continue;  // Only process |0⟩ states
            int flipped = base | (1 << q);
            coherence += rho(base, flipped);  // Sum over traced-out indices
        }
        rho01s[q] = coherence;
    }

    // Compute Bloch vectors
    for (int q = 0; q < num_qubits; q++) {
        double p0 = p0s[q];
        double p1 = p1s[q];
        double x = 2.0 * rho01s[q].real();
        double y = -2.0 * rho01s[q].imag();
        double z = p0 - p1;
        double r = std::sqrt(x*x + y*y + z*z);
        double theta = (r > 1e-12) ? std::acos(std::clamp(z/r, -1.0, 1.0)) : 0.0;
        double phi = std::atan2(y, x);

        int base = q * 8;
        ptr[base+0] = p0; ptr[base+1] = p1;
        ptr[base+2] = x;  ptr[base+3] = y;  ptr[base+4] = z;
        ptr[base+5] = r;  ptr[base+6] = theta; ptr[base+7] = phi;
    }

    return out;
}
```

**Impact**: O(dim × num_qubits) instead of O(dim × num_qubits²) = ~5ms saved

**File**: `native/src/quantum_evolution_engine.cpp:521-567`

---

### Priority 4: PACK/UNPACK OPTIMIZATION (Save ~2-3ms)

**Current Implementation**: Full copy between PackedFloat64Array and Eigen::MatrixXcd

**Optimization 4.1: Zero-Copy Read via Pointer Aliasing**

```cpp
// Instead of copying, use Eigen::Map for read-only access
const double* ptr = rho_data.ptr();
Eigen::Map<const Eigen::Matrix<double, Eigen::Dynamic, Eigen::Dynamic, Eigen::RowMajor>>
    rho_real(ptr, m_dim, m_dim * 2);  // Interleaved re,im

// Or create complex view (requires aligned data)
// This is safe because PackedFloat64Array is contiguous
```

**Impact**: Eliminates copy on unpack = ~1ms saved per call

**File**: `native/src/quantum_evolution_engine.cpp:275-286`

---

### Priority 5: TidalPools DIMENSION REDUCTION (Save ~20ms)

**Observation**: TidalPools (6 qubits, 64D) consumes 32% of total compute time.

**Recommendation**: Reduce to 4 qubits (16D)
- 64D → 16D = 16× smaller matrices
- Lindblad operations: O(dim³) → 64× faster
- Estimated savings: ~25-30ms

**File**: `Core/Biomes/data/biomes_merged.json` → TidalPools configuration
**Risk**: Gameplay balance changes, fewer quantum states to explore

---

## IMPLEMENTATION SEQUENCE

### Phase 1: Quick Wins (1-2 days, ~25ms savings)
1. ✅ **Cache single-qubit entropies in MI computation** (1.1) - 10ms
2. ✅ **Add `compute_mi` flag to skip MI when not needed** (1.2) - 15ms
3. ✅ **Pre-allocate drho buffer** (2.2) - 2ms

### Phase 2: Medium Effort (2-3 days, ~20ms additional)
1. ✅ **Adaptive substep count** (2.1) - 8ms
2. ✅ **Vectorized Bloch computation** (3.1) - 5ms
3. ✅ **Classical correlation fallback for MI** (1.3) - 7ms (optional)

### Phase 3: Algorithmic Changes (3-4 days, ~15-20ms additional)
1. ✅ **RK4 integrator** (2.4) - 15ms
2. ✅ **Fused Lindblad application** (2.3) - 5ms
3. ✅ **Zero-copy unpack** (4.1) - 2ms

### Phase 4: Game Design Changes (if needed)
1. ✅ **Reduce TidalPools to 4 qubits** (5) - 25ms

---

## FILES TO MODIFY

### Native C++ (highest impact)
```
native/src/quantum_evolution_engine.h
  - Add m_drho_buffer member
  - Add compute_mi parameter to signatures
  - Add classical_correlation method

native/src/quantum_evolution_engine.cpp
  - Implement all optimization changes
  - Line 229-273: evolve() substep optimization
  - Line 435-461: MI caching optimization
  - Line 521-567: Vectorized Bloch computation

native/src/multi_biome_lookahead_engine.h
  - Add compute_mi flag to evolve_all_lookahead

native/src/multi_biome_lookahead_engine.cpp
  - Line 273-293: Conditional MI computation
```

### GDScript (interface changes only)
```
Core/Environment/BiomeEvolutionBatcher.gd
  - Line 583: Pass compute_mi flag based on zoom/visibility
```

### Configuration
```
Core/Biomes/data/biomes_merged.json
  - TidalPools qubit reduction (if approved)
```

---

## EXPECTED RESULTS

| Optimization Phase | Cumulative Savings | New Frame Time | FPS |
|-------------------|-------------------|----------------|-----|
| Baseline | 0ms | 110ms | 9 |
| Phase 1 | 25ms | 85ms | 12 |
| Phase 2 | 45ms | 65ms | 15 |
| Phase 3 | 65ms | 45ms | 22 |
| Phase 4 (+TidalPools) | 90ms | 20ms | **50** |

---

## TESTING STRATEGY

### Benchmark Script
Create `Tests/NativeEngineBenchmark.gd`:
```gdscript
func benchmark_evolution():
    var engine = MultiBiomeLookaheadEngine.new()
    # Register all biomes
    var start = Time.get_ticks_usec()
    for i in 100:
        engine.evolve_all_lookahead(biome_rhos, 5, 0.1, 0.02)
    var elapsed = (Time.get_ticks_usec() - start) / 1000.0
    print("100 iterations: %.2fms (%.2fms per call)" % [elapsed, elapsed/100])
```

### A/B Testing
1. Profile baseline with current code
2. Apply each optimization individually
3. Measure improvement
4. Commit if ≥5ms improvement per change

---

## CRITICAL CODE LOCATIONS

| File | Line | Function | Purpose |
|------|------|----------|---------|
| quantum_evolution_engine.cpp | 229-273 | evolve() | Main evolution loop |
| quantum_evolution_engine.cpp | 256-264 | (in evolve) | Lindblad dissipation |
| quantum_evolution_engine.cpp | 419-433 | mutual_information() | MI for one pair |
| quantum_evolution_engine.cpp | 435-461 | compute_all_MI() | MI for all pairs |
| quantum_evolution_engine.cpp | 398-417 | von_neumann_entropy() | Eigendecomposition |
| quantum_evolution_engine.cpp | 521-567 | compute_bloch_metrics() | Bloch vectors |
| multi_biome_lookahead_engine.cpp | 255-293 | _evolve_biome_steps() | Hot loop |

