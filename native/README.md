# SpaceWheat Native GDExtension

**Clean, minimal build system - NO BLOAT**

## Structure

```
native/
├── src/                    Your 7 C++ files (3415 lines)
├── include/
│   ├── Eigen/              Linear algebra (header-only)
│   ├── unsupported/        Eigen matrix functions
│   └── godot_cpp/          GDExtension headers only
├── lib/
│   └── libgodot-cpp...a    Pre-compiled godot-cpp (81MB)
├── bin/
│   ├── linux/              Linux binaries (.so)
│   ├── windows/            Windows binaries (.dll)
│   ├── macos/              macOS frameworks
│   └── web/                WASM binaries
└── Makefile                Simple build (no scons)
```

## Build

```bash
make clean && make -j$(nproc)
```

**Build time:** ~30 seconds

## What's Compiled

| File | Lines | Purpose |
|------|-------|---------|
| `quantum_evolution_engine.cpp` | 1257 | Core Lindblad solver |
| `multi_biome_lookahead_engine.cpp` | 869 | Batched multi-biome evolution |
| `parametric_selector_native.cpp` | 475 | Music Layer 4/5 (100× speedup) |
| `quantum_matrix_native.cpp` | 293 | General matrix ops |
| `force_graph_engine.cpp` | 273 | Bubble physics |
| `liquid_neural_net.cpp` | 180 | Phase modulation |
| `register_types.cpp` | 68 | GDExtension registration |

**Total:** 7 files, 3415 lines

## Classes Exposed to GDScript

- `QuantumMatrixNative` - Matrix operations (Eigen accelerated)
- `QuantumEvolutionEngine` - Lindblad evolution (10-20× speedup)
- `MultiBiomeLookaheadEngine` - Batched evolution (4ms amortized)
- `ForceGraphEngine` - Bubble physics (3-5× speedup)
- `ParametricSelectorNative` - Music selection (100× speedup)

## Dependencies

**External (header-only):**
- Eigen 3 - Linear algebra
- godot-cpp headers - GDExtension API

**Pre-compiled:**
- libgodot-cpp.linux.template_release.x86_64.a (81MB, built once)

**No runtime dependencies** - statically linked

## History

**2025-02-02:** Migrated from bloated scons build
- Removed 971 godot-cpp class compilations
- Build time: 20+ min → 30 sec
- No more zombie rendering/UI/physics code

**Previous implementation:** Archived at `~/ws/SpaceWheat/native_OLD_BLOATED_*`
