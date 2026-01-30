# BiomeBuilder Testing - Investigation Summary

**Date:** 2026-01-29  
**Status:** Test suite created, ready for execution

---

## Investigation Findings

### 1. **Existing Test Infrastructure** ✅

Found robust testing framework:
- **`test_biome_construction.gd`** - Tests `BootManager.load_biome()` (11 test cases)
  - Validates biome loading, registration, plot assignment
  - Checks quantum operator rebuild
  - Validates density matrix (trace=1.0, no negative diagonals)
  - Tests idempotency and multi-biome loading
  
- **`test_quantum_integration.gd`** - Tests quest system (not relevant here)

- **C++ Extension:** `quantum_matrix.gdextension` 
  - Native library: `libquantummatrix.linux.*.so`
  - Entry point: `quantum_matrix_library_init`
  - Used for ComplexMatrix operations

### 2. **Gaps Identified** ❌

Current tests do NOT verify:
- BiomeBuilder itself (uses BootManager as wrapper)
- Hamiltonian vs Lindblad separation
- Icon purity (H-only, no L terms)
- Live rebuild capability
- C++ native operator performance
- Visualization packet completeness

---

## Test Suite Created

### **File: `Tests/test_biome_builder.gd`** ✅

**10 comprehensive unit tests:**

#### Build Correctness (5 tests)
1. `test_build_success` - Basic build returns success
2. `test_hamiltonian_size` - H matrix has correct dimension (2^n)
3. `test_lindblad_from_biome_spec` - L operators built from BiomeLindblad
4. `test_icons_are_hamiltonian_only` - Icons have NO Lindblad terms
5. `test_density_matrix_valid` - ρ is normalized (Tr(ρ) = 1.0)

#### Live Rebuild (3 tests)
6. `test_rebuild_icons_for_standings` - Rebuild function works
7. `test_rebuild_changes_hamiltonian` - Faction weight changes H
8. `test_rebuild_preserves_lindblad` - Biome spec unchanged → L unchanged

#### Error Handling (2 tests)
9. `test_error_invalid_emoji_pairs` - Empty emojis fail gracefully
10. `test_error_empty_lindblad_spec` - Null Lindblad still builds (H-only)

**Execution:**
```bash
godot --headless -s Tests/test_biome_builder.gd
```

---

## Proposed Testing Path Forward

### Phase 1: **Run BiomeBuilder Unit Tests** (NEXT STEP)
```bash
cd /home/tehcr33d/ws/SpaceWheat
godot --headless -s Tests/test_biome_builder.gd
```

**Expected outcome:**
- ✅ 10/10 tests pass
- Confirms H/L separation works
- Validates live rebuild capability

**If tests fail:** Debug BiomeBuilder implementation

---

### Phase 2: **Test C++ Acceleration** (AFTER PHASE 1 PASSES)

Create `Tests/test_biome_builder_native.gd`:

**Tests:**
1. Native matrix multiplication (H * |ψ⟩)
2. Trace calculation (Tr(ρ))
3. Evolution performance (100 timesteps)
4. Speed comparison (native vs GDScript)

**Verification points:**
- [ ] No crashes with native library
- [ ] No NaN or Inf values in results
- [ ] Evolution maintains valid density matrix
- [ ] Performance: < 5ms per evolution step

---

### Phase 3: **Test Visualization Packets** (AFTER PHASE 2 PASSES)

Create `Tests/test_biome_visualization_packet.gd`:

**Tests:**
1. `get_visual_config()` returns complete packet
2. `get_status()` returns quantum state data
3. Observable queries work (`get_emoji_probability`, `get_purity`)
4. Force graph can render (has positions, colors, labels)

**Verification points:**
- [ ] All visualization fields present
- [ ] Values are valid (no nulls or NaNs)
- [ ] Queries run fast (< 1ms per call)

---

### Phase 4: **Integration Test** (FINAL VALIDATION)

Extend `tests/test_biome_construction.gd`:

**Add 2 new tests:**
1. `test_biome_builder_boot_path` - BootManager uses BiomeBuilder
2. `test_biome_builder_live_rebuild` - Runtime rebuild works

**Verification:**
- [ ] Existing 11 tests still pass (no regressions)
- [ ] New 2 tests pass (BiomeBuilder integration)
- [ ] Boot console shows "(H=factions, L=biome)"

---

## Critical Test Criteria

### ✅ **Must Pass:**
1. **Build correctness** - All BiomeBuilder unit tests pass (10/10)
2. **C++ acceleration** - Native library works without crashes
3. **Visualization** - Complete data packets available
4. **Integration** - Boot and live-rebuild both work

### ⚠️ **Performance Benchmarks:**
- H matrix build: < 100ms (cached), < 8s (uncached)
- L operator build: < 50ms
- Evolution step: < 5ms (native)
- Viz query: < 1ms per observable

### ❌ **Blockers:**
- Any test failures indicate architecture problems
- Crashes with native library → C++ binding issues
- Missing viz fields → incomplete biome setup

---

## Next Immediate Action

**Run the unit tests:**
```bash
cd \\wsl.localhost\Ubuntu-22.04\home\tehcr33d\ws\SpaceWheat
godot --headless -s Tests/test_biome_builder.gd
```

This will validate:
- BiomeBuilder builds correctly
- H/L separation works
- Icons are Hamiltonian-only
- Live rebuild capability exists
- Error handling is robust

**Expected output:**
```
🔬 BIOMEBUILDER UNIT TEST SUITE
================================================================================

🧪 Test: build_biome_quantum_system returns success
  ✅ build_biome_quantum_system returns success

🧪 Test: Hamiltonian has correct dimension
  ✅ Hamiltonian has correct dimension (8x8 for 3 qubits)

...

================================================================================
TEST SUMMARY:
  ✅ Passed: 10
  ❌ Failed: 0
================================================================================
```

---

## Files Created

1. **`docs/BIOME_BUILDER_TEST_PLAN.md`** - Full testing strategy
2. **`Tests/test_biome_builder.gd`** - 10 unit tests (ready to run)
3. **`docs/BIOME_BUILDER_TEST_SUMMARY.md`** - This summary document

---

## Status: Ready for Testing ✅

The new BiomeBuilder architecture has comprehensive test coverage.  
Once the game boots successfully, run the test suite to validate the implementation.
