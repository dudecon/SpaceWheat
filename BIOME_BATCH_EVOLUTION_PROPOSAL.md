# Biome Batch Evolution System - Proposal

## Problem Statement

### Current Architecture Issues

**Per-Biome Evolution** (every 0.1s at 10Hz):
```gdscript
# BiomeBase._process() → advance_simulation() → _update_quantum_substrate()
for each biome:
    quantum_computer.evolve(dt)  # ← GDScript → C++ handoff
        # C++ side:
        - Unpack density matrix (64-1024 complex numbers)
        - Evolve (fast!)
        - Pack result back
        # ← C++ → GDScript return
```

**Performance Bottleneck:**
- **6 separate C++/GDScript handoffs** per 10Hz tick
- **Data transfer overhead**: ~3ms per transfer
  - Packing: GDScript → PackedFloat64Array
  - Bridge crossing: GDScript FFI → C++ native
  - Unpacking: C++ → Eigen matrix
  - (Reverse for return)
- **Total handoff cost**: 6 biomes × 3ms = **18ms wasted** every 0.1s
- **Amortized per frame** (at 15 FPS): ~3-5ms average

### Proposed Solution Architecture

**Batched Multi-Biome Evolution** - Process 2 biomes per frame, rotating

```
Frame 1: Evolve BioticFlux + StellarForges  (8×8 + 8×8)
Frame 2: Evolve FungalNetworks + VolcanicWorlds (16×16 + 8×8)
Frame 3: Evolve StarterForest + Village (32×32 + 32×32)
[Repeat every 3 frames at 10Hz effective rate]
```

**Key Benefits:**
1. ✅ **Reduced handoffs**: 6 → 2 per evolution cycle (67% reduction)
2. ✅ **Amortized load**: Spread 20-30ms burst across 3 frames → 7-10ms/frame
3. ✅ **Sparse packing**: Transfer only non-zero elements (50-80% savings for sparse matrices)
4. ✅ **Better cache utilization**: Process related biomes together

---

## Implementation Design

### Phase 1: Create BiomeEvolutionBatcher (GDScript)

**File**: `Core/Environment/BiomeEvolutionBatcher.gd`

```gdscript
class_name BiomeEvolutionBatcher
extends RefCounted

## BiomeEvolutionBatcher - Rotational batch evolution for all biomes
##
## Processes 2 biomes per frame in rotating batches to:
## 1. Reduce C++/GDScript handoff overhead
## 2. Amortize quantum evolution across multiple frames
## 3. Batch data transfer for sparse matrices

# Batching configuration
const BIOMES_PER_BATCH = 2  # Process 2 biomes per frame
const EVOLUTION_INTERVAL = 0.1  # 10Hz evolution rate

# Batch rotation state
var batch_groups: Array[Array] = []  # [[biome0, biome1], [biome2, biome3], ...]
var current_batch_index: int = 0
var evolution_accumulator: float = 0.0

# Native batch evolution engine
var native_batch_engine = null  # MultiBiomeEvolutionEngine (C++)

func initialize(biomes: Array):
    """Initialize batcher with all farm biomes.

    Args:
        biomes: Array of BiomeBase instances (6 biomes)
    """
    # Filter out null biomes
    var valid_biomes = biomes.filter(func(b): return b != null and b.quantum_computer != null)

    # Group into batches of 2
    batch_groups.clear()
    for i in range(0, valid_biomes.size(), BIOMES_PER_BATCH):
        var batch = []
        for j in range(BIOMES_PER_BATCH):
            if i + j < valid_biomes.size():
                batch.append(valid_biomes[i + j])
        if not batch.is_empty():
            batch_groups.append(batch)

    print("BiomeEvolutionBatcher: Created %d batches from %d biomes" % [
        batch_groups.size(), valid_biomes.size()
    ])

    # Setup native batch engine
    _setup_native_batch_engine()

func process(delta: float):
    """Called every frame from Farm._process().

    Rotates through batch groups, processing one batch per evolution interval.
    """
    evolution_accumulator += delta

    if evolution_accumulator >= EVOLUTION_INTERVAL:
        var actual_dt = evolution_accumulator
        evolution_accumulator = 0.0

        # Evolve current batch
        if not batch_groups.is_empty():
            _evolve_batch(batch_groups[current_batch_index], actual_dt)

            # Rotate to next batch
            current_batch_index = (current_batch_index + 1) % batch_groups.size()

func _evolve_batch(biomes: Array, dt: float):
    """Evolve a batch of biomes together.

    Two modes:
    1. Native batch mode: Single C++ call for all biomes
    2. Fallback mode: Sequential evolution with reduced handoff
    """
    if native_batch_engine != null:
        _evolve_batch_native(biomes, dt)
    else:
        _evolve_batch_fallback(biomes, dt)

func _evolve_batch_native(biomes: Array, dt: float):
    """Native batch evolution (single C++ call).

    Packs all density matrices → C++ evolves all → unpack results.
    Expected: ~1-2ms per batch vs ~6ms for 2 separate calls.
    """
    # Prepare batch data
    var batch_data = []
    for biome in biomes:
        var qc = biome.quantum_computer
        if qc and qc.density_matrix:
            batch_data.append({
                "biome": biome,
                "qc": qc,
                "rho": qc.density_matrix._to_packed_sparse(),  # Use sparse packing
                "dim": qc.register_map.dim(),
                "engine_id": qc.native_evolution_engine.get_instance_id()
            })

    if batch_data.is_empty():
        return

    # Single C++ call for entire batch
    var results = native_batch_engine.evolve_batch(batch_data, dt)

    # Unpack results
    for i in range(results.size()):
        var data = batch_data[i]
        var result_rho = results[i]
        data.qc.density_matrix._from_packed_sparse(result_rho, data.dim)
        data.qc._renormalize()

func _evolve_batch_fallback(biomes: Array, dt: float):
    """Fallback: Sequential evolution without batching.

    Still reduces per-frame load by rotating batches.
    """
    for biome in biomes:
        if biome.quantum_computer:
            biome.quantum_computer.evolve(dt)

func _setup_native_batch_engine():
    """Setup native multi-biome batch evolution engine."""
    if not ClassDB.class_exists("MultiBiomeEvolutionEngine"):
        print("BiomeEvolutionBatcher: Native batch engine not available (fallback mode)")
        return

    native_batch_engine = ClassDB.instantiate("MultiBiomeEvolutionEngine")
    if native_batch_engine:
        print("BiomeEvolutionBatcher: Native batch engine initialized")
    else:
        push_warning("BiomeEvolutionBatcher: Failed to instantiate native engine")
```

---

### Phase 2: Add Sparse Packing to ComplexMatrix

**File**: `Core/QuantumSubstrate/ComplexMatrix.gd`

```gdscript
func _to_packed_sparse() -> PackedFloat64Array:
    """Pack as sparse triplets: [row, col, re, im, ...]

    Only includes non-zero elements (|z| > 1e-15).
    For sparse matrices, this reduces transfer size by 50-80%.
    """
    var triplets = PackedFloat64Array()
    var threshold = 1e-15

    for i in range(n):
        for j in range(n):
            var c = get_element(i, j)
            if abs(c.re) > threshold or abs(c.im) > threshold:
                triplets.append(float(i))
                triplets.append(float(j))
                triplets.append(c.re)
                triplets.append(c.im)

    # Prepend dimension for unpacking
    var result = PackedFloat64Array([float(n)])
    result.append_array(triplets)
    return result

func _from_packed_sparse(data: PackedFloat64Array, dim: int):
    """Unpack from sparse triplets."""
    if n != dim:
        resize(dim)

    # Clear matrix
    for i in range(n):
        for j in range(n):
            set_element(i, j, Complex.new(0, 0))

    # Read triplets
    var idx = 1  # Skip dimension header
    while idx + 3 < data.size():
        var row = int(data[idx])
        var col = int(data[idx + 1])
        var re = data[idx + 2]
        var im = data[idx + 3]
        set_element(row, col, Complex.new(re, im))
        idx += 4
```

---

### Phase 3: Create Native MultiBiomeEvolutionEngine (C++)

**File**: `native/src/multi_biome_evolution_engine.h`

```cpp
#ifndef MULTI_BIOME_EVOLUTION_ENGINE_H
#define MULTI_BIOME_EVOLUTION_ENGINE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/array.hpp>
#include <Eigen/Dense>
#include <Eigen/Sparse>
#include <vector>

namespace godot {

/**
 * MultiBiomeEvolutionEngine - Batch evolution for multiple biomes
 *
 * Reduces GDScript ↔ C++ handoff overhead by:
 * 1. Accepting multiple density matrices in ONE call
 * 2. Evolving them all in C++ (parallel where possible)
 * 3. Returning all results in ONE call
 *
 * Expected speedup: 2-3× for batches of 2-3 biomes
 * (6ms → 2ms for typical batch)
 */
class MultiBiomeEvolutionEngine : public RefCounted {
    GDCLASS(MultiBiomeEvolutionEngine, RefCounted)

public:
    MultiBiomeEvolutionEngine();
    ~MultiBiomeEvolutionEngine();

    // Batch evolution interface
    // batch_data: Array of {rho: PackedFloat64Array, engine_id: int, dim: int}
    // Returns: Array of PackedFloat64Array (evolved density matrices)
    Array evolve_batch(const Array& batch_data, float dt, float max_dt = 0.02f);

protected:
    static void _bind_methods();

private:
    // Helper: Unpack sparse density matrix
    Eigen::MatrixXcd unpack_sparse(const PackedFloat64Array& data, int dim) const;

    // Helper: Pack sparse density matrix
    PackedFloat64Array pack_sparse(const Eigen::MatrixXcd& mat) const;

    // Cache for QuantumEvolutionEngine lookups
    std::unordered_map<uint64_t, QuantumEvolutionEngine*> m_engine_cache;
};

}  // namespace godot

#endif  // MULTI_BIOME_EVOLUTION_ENGINE_H
```

**File**: `native/src/multi_biome_evolution_engine.cpp`

```cpp
#include "multi_biome_evolution_engine.h"
#include "quantum_evolution_engine.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/object.hpp>

using namespace godot;

void MultiBiomeEvolutionEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("evolve_batch", "batch_data", "dt", "max_dt"),
                         &MultiBiomeEvolutionEngine::evolve_batch);
}

MultiBiomeEvolutionEngine::MultiBiomeEvolutionEngine() {}
MultiBiomeEvolutionEngine::~MultiBiomeEvolutionEngine() {}

Array MultiBiomeEvolutionEngine::evolve_batch(const Array& batch_data,
                                                float dt, float max_dt) {
    Array results;
    results.resize(batch_data.size());

    for (int i = 0; i < batch_data.size(); i++) {
        Dictionary entry = batch_data[i];

        // Extract data
        PackedFloat64Array rho_sparse = entry["rho"];
        int dim = entry["dim"];
        uint64_t engine_id = entry["engine_id"];

        // Look up the QuantumEvolutionEngine for this biome
        QuantumEvolutionEngine* engine = nullptr;
        if (m_engine_cache.find(engine_id) != m_engine_cache.end()) {
            engine = m_engine_cache[engine_id];
        } else {
            // Fetch from ObjectDB (expensive, cache it)
            Object* obj = ObjectDB::get_instance(engine_id);
            engine = Object::cast_to<QuantumEvolutionEngine>(obj);
            if (engine) {
                m_engine_cache[engine_id] = engine;
            }
        }

        if (!engine || !engine->is_finalized()) {
            // Return unchanged
            results[i] = rho_sparse;
            continue;
        }

        // Unpack sparse matrix to dense Eigen
        Eigen::MatrixXcd rho = unpack_sparse(rho_sparse, dim);

        // Evolve using the biome's pre-configured engine
        // This reuses all the H, L, L†, L†L precomputed data
        PackedFloat64Array rho_dense = pack_dense(rho);
        PackedFloat64Array evolved = engine->evolve(rho_dense, dt, max_dt);

        // Convert back to sparse for return
        Eigen::MatrixXcd rho_evolved = unpack_dense(evolved, dim);
        results[i] = pack_sparse(rho_evolved);
    }

    return results;
}

Eigen::MatrixXcd MultiBiomeEvolutionEngine::unpack_sparse(
    const PackedFloat64Array& data, int dim) const {

    Eigen::MatrixXcd mat = Eigen::MatrixXcd::Zero(dim, dim);

    // Skip dimension header at index 0
    const double* ptr = data.ptr();
    int idx = 1;

    while (idx + 3 < data.size()) {
        int row = static_cast<int>(ptr[idx]);
        int col = static_cast<int>(ptr[idx + 1]);
        double re = ptr[idx + 2];
        double im = ptr[idx + 3];

        mat(row, col) = std::complex<double>(re, im);
        idx += 4;
    }

    return mat;
}

PackedFloat64Array MultiBiomeEvolutionEngine::pack_sparse(
    const Eigen::MatrixXcd& mat) const {

    PackedFloat64Array triplets;
    int dim = mat.rows();
    double threshold = 1e-15;

    // Add dimension header
    triplets.append(static_cast<double>(dim));

    // Add non-zero elements
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            std::complex<double> val = mat(i, j);
            if (std::abs(val.real()) > threshold ||
                std::abs(val.imag()) > threshold) {
                triplets.append(static_cast<double>(i));
                triplets.append(static_cast<double>(j));
                triplets.append(val.real());
                triplets.append(val.imag());
            }
        }
    }

    return triplets;
}
```

---

### Phase 4: Integrate into Farm

**File**: `Core/Farm.gd` modifications

```gdscript
# Add biome batcher
var biome_evolution_batcher: BiomeEvolutionBatcher = null

func _ready():
    # ... existing initialization ...

    # Initialize biome evolution batcher
    biome_evolution_batcher = BiomeEvolutionBatcher.new()
    biome_evolution_batcher.initialize([
        biotic_flux_biome,
        stellar_forges_biome,
        fungal_networks_biome,
        volcanic_worlds_biome,
        starter_forest_biome,
        village_biome
    ])

func _process(delta: float):
    # Replace individual biome processing with batched processing
    if biome_evolution_batcher:
        biome_evolution_batcher.process(delta)

    # ... rest of _process ...
```

**File**: `Core/Environment/BiomeBase.gd` modifications

```gdscript
func _process(dt: float) -> void:
    # DISABLE individual evolution when batcher is active
    # The batcher will call quantum_computer.evolve() directly

    # Only update time tracker (for UI and drift)
    time_tracker.update(dt)

    # Don't call advance_simulation() - batcher handles it
```

---

## Performance Analysis

### Current Performance (6 individual evolutions every 0.1s)

| Component | Time (ms) | Notes |
|-----------|-----------|-------|
| **Per-biome handoff** | 3ms × 6 | Pack, bridge, unpack × 2 |
| **Total handoff** | 18ms | Every 0.1s (10Hz) |
| **Actual evolution** | 20-30ms | Fast (C++ with Eigen) |
| **Total per tick** | 38-48ms | Every 0.1s |
| **Amortized/frame** | 6-8ms | At 15 FPS |

### Proposed Performance (2-biome batches, rotating)

| Component | Time (ms) | Notes |
|-----------|-----------|-------|
| **Batch handoff** | 2ms × 1 | Single transfer for 2 biomes |
| **Sparse packing** | -50% | Only non-zero elements |
| **Net handoff** | 1ms | Per batch |
| **Actual evolution** | 7-10ms | 2 biomes together |
| **Total per batch** | 8-11ms | Every frame (rotates) |
| **Amortized/frame** | 8-11ms | At 15 FPS |

### Expected Improvements

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Handoff overhead** | 18ms/tick | 3ms/cycle | **-83%** |
| **Peak frame cost** | 38-48ms | 8-11ms | **-77%** |
| **Frame smoothness** | Spiky (0,0,0,38,0,0) | Smooth (8,8,8) | **Much better** |
| **Amortized cost** | 6-8ms/frame | 8-11ms/frame | ~+2ms (acceptable) |

**Key wins:**
- ✅ **Eliminate 15ms of handoff waste** per evolution cycle
- ✅ **Smooth frame times** - no more 30-40ms spikes
- ✅ **Better cache utilization** - process similar biomes together
- ✅ **50-80% transfer reduction** with sparse packing

---

## Migration Strategy

### Stage 1: GDScript-Only Batch Rotation (Quick Win)

**Effort**: 2-4 hours
**Gain**: Smooth frame times, eliminate spikes

```gdscript
# Just rotate which biomes evolve each frame
# No C++ changes needed
var biome_rotation_index = 0
func _process(delta):
    # Evolve 2 biomes this frame
    biomes[biome_rotation_index].quantum_computer.evolve(dt)
    biomes[biome_rotation_index + 1].quantum_computer.evolve(dt)
    biome_rotation_index = (biome_rotation_index + 2) % 6
```

**Result**: Smooth 8-11ms/frame instead of spiky 0-38ms

### Stage 2: Add Sparse Packing (Medium Win)

**Effort**: 4-6 hours
**Gain**: 50-80% transfer reduction

- Implement `_to_packed_sparse()` / `_from_packed_sparse()`
- Modify existing QuantumEvolutionEngine to accept sparse
- Test thoroughly

**Result**: Reduce handoff from 3ms → 1ms per biome

### Stage 3: Native Batch Engine (Big Win)

**Effort**: 8-12 hours (C++ development + testing)
**Gain**: Single handoff for entire batch

- Implement MultiBiomeEvolutionEngine
- Add to register_types.cpp
- Integrate with BiomeEvolutionBatcher
- Profile and optimize

**Result**: Reduce 6ms handoff → 1ms for entire batch

---

## Alternative: Simpler "2-per-frame" Approach

If full batching is too complex, start with this minimal change:

**File**: `Core/Farm.gd`

```gdscript
var biome_list: Array = []
var biome_index: int = 0

func _ready():
    biome_list = [
        biotic_flux_biome, stellar_forges_biome,
        fungal_networks_biome, volcanic_worlds_biome,
        starter_forest_biome, village_biome
    ].filter(func(b): return b != null)

func _process(delta: float):
    # Process 2 biomes per frame (rotating)
    if biome_list.size() >= 2:
        var b1 = biome_list[biome_index]
        var b2 = biome_list[(biome_index + 1) % biome_list.size()]

        if b1: b1.advance_simulation(delta)
        if b2: b2.advance_simulation(delta)

        biome_index = (biome_index + 2) % biome_list.size()

    # ... rest of processing ...
```

**Effort**: 30 minutes
**Gain**: Smooth frame times immediately

---

## Testing Plan

### Performance Benchmarks

1. **Run baseline** (current system):
   ```bash
   godot --headless --script res://Tests/PerformanceBenchmark.gd
   ```

2. **Implement Stage 1** (rotation only)
3. **Run benchmark again** - expect smoother frame times
4. **Implement Stage 2** (sparse packing)
5. **Run benchmark** - expect lower process time
6. **Implement Stage 3** (native batching)
7. **Final benchmark** - expect major handoff reduction

### Correctness Tests

```gdscript
# Verify quantum state stays consistent
- Compare final probabilities: batched vs sequential
- Check purity preservation: Tr(ρ²) stays constant
- Verify Hermiticity: ρ = ρ†
- Test with entanglement
```

---

## Recommendation

**Start with Stage 1** (GDScript rotation) for immediate smooth frames:
- ✅ Quick to implement (< 1 hour)
- ✅ No C++ changes needed
- ✅ Immediate visual improvement
- ✅ Sets up architecture for later optimization

**Then add Stage 2** (sparse packing) for transfer reduction:
- ✅ Moderate effort (4-6 hours)
- ✅ Works with existing C++ code
- ✅ 50-80% bandwidth savings

**Finally Stage 3** (native batch engine) if needed:
- Consider only if profiling shows handoff is still a bottleneck
- Requires C++ expertise
- Most complex to test

**Expected final performance**: ~5-7ms/frame for all quantum evolution (vs current 6-8ms, but smoother)
