# Native GDExtension Build

**Location:** `~/ws/SpaceWheat/native/`

## Quick Build

```bash
cd ~/ws/SpaceWheat/native
make clean && make -j$(nproc)
```

**Time:** ~30 seconds

## What's Here

- **7 source files** (3415 lines of actual code)
- **Simple Makefile** (no scons bloat)
- **Pre-compiled godot-cpp** (no 971-file recompilation)
- **Clean structure** (src, include, lib, bin)

## What's NOT Here

- ❌ No scons build system
- ❌ No 971 godot-cpp class compilations
- ❌ No rendering/UI/physics code (you don't use it)
- ❌ No 20+ minute builds

## Performance

| Class | Speedup | Use Case |
|-------|---------|----------|
| `QuantumEvolutionEngine` | 10-20× | Biome evolution |
| `MultiBiomeLookaheadEngine` | 4ms amortized | Batch processing |
| `ParametricSelectorNative` | 100× | Music Layer 4/5 |
| `ForceGraphEngine` | 3-5× | Bubble physics |

## Migration History

**2025-02-02:** Aggressively migrated from bloated build
- Old implementation: `~/ws/SpaceWheat/native_OLD_BLOATED_*`
- Result: Clean, fast, maintainable

