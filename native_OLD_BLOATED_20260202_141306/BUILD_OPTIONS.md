# Build Options for SpaceWheat Native GDExtension

## What Changed

**Removed dead code (720 lines):**
- `quantum_solver_cpu.cpp` (296 lines) - Compiled but unreachable
- `batched_bubble_renderer.cpp` (424 lines) - Never used, atlas always works

**Now compiling (7 files, 3415 lines):**
1. `quantum_evolution_engine.cpp` (1257) - Core Lindblad solver
2. `multi_biome_lookahead_engine.cpp` (869) - Batched multi-biome evolution
3. `parametric_selector_native.cpp` (475) - Music Layer 4/5 selection (100× speedup)
4. `quantum_matrix_native.cpp` (293) - General matrix ops for GDScript fallback
5. `force_graph_engine.cpp` (273) - Bubble physics layout
6. `liquid_neural_net.cpp` (180) - Phase modulation
7. `register_types.cpp` (68) - GDExtension registration

---

## Option 1: Build Locally (Slow but Simple)

**Time:** ~10-15 minutes on slow machine
**Requires:** Nothing extra

```bash
cd ~/ws/SpaceWheat/native
./build_slow.sh
```

The script will:
- Build with `-j1` (single-threaded, gentle on resources)
- Save log to `build.log`
- Show compiled library size when done

---

## Option 2: Build on Google Colab (Fast)

**Time:** ~2-3 minutes on Google's servers
**Requires:** Google account

### Step 1: Prepare source tarball
```bash
cd ~/ws/SpaceWheat/native
./prepare_colab.sh
```

This creates `native_source.tar.gz` (~15-20MB).

### Step 2: Upload to Google Colab
1. Go to https://colab.research.google.com/
2. Upload `colab_build.ipynb`
3. In Colab, upload `native_source.tar.gz` (Files panel → Upload)

### Step 3: Build
Run all cells in the notebook (Runtime → Run all)

### Step 4: Download
Right-click `native/bin/libquantummatrix.linux.template_debug.x86_64.so` → Download

### Step 5: Install locally
```bash
mv ~/Downloads/libquantummatrix.linux.template_debug.x86_64.so \
   ~/ws/SpaceWheat/native/bin/
```

---

## Verify the Build

```bash
cd ~/ws/SpaceWheat
./godot --headless --script Tests/TestParametricSelector.gd
```

Expected output:
```
[ParametricSelector] All 6 tests passed!
Native ParametricSelectorNative: 100× faster than GDScript
```

---

## What You Get

**5 Native Classes (exposed to GDScript):**
| Class | Purpose | Speedup |
|-------|---------|---------|
| `QuantumEvolutionEngine` | Lindblad solver | 10-20× |
| `MultiBiomeLookaheadEngine` | Batched multi-biome evolution | 4ms amortized |
| `ParametricSelectorNative` | Music Layer 4/5 selection | 100× |
| `ForceGraphEngine` | Bubble physics layout | 3-5× |
| `QuantumMatrixNative` | General matrix ops (fallback) | 5-10× |

**Libraries Used:**
- Eigen 3 (header-only, linear algebra)
- godot-cpp (GDExtension bindings)
- std::complex, std::vector, std::random

**Total compiled size:** ~2.4MB

---

## Troubleshooting

### Build fails with "Eigen not found"
```bash
cd ~/ws/SpaceWheat/native
ls include/Eigen/  # Should show Core, Dense, Sparse, etc.
```

### Build succeeds but classes not available in Godot
Check `.gdextension` file:
```bash
cat ~/ws/SpaceWheat/native/libquantummatrix.gdextension
```

Should reference `bin/libquantummatrix.linux.template_debug.x86_64.so`

### Godot says "Cannot load GDExtension"
```bash
ldd ~/ws/SpaceWheat/native/bin/libquantummatrix.linux.template_debug.x86_64.so
```

Check for missing dependencies.
