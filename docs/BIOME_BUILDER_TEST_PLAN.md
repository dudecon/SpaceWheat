# BiomeBuilder Testing Plan

## Overview
Test the new Faction→Hamiltonian / Biome→Lindblad architecture to ensure:
1. **Build correctness** - Operators are constructed properly
2. **C++ acceleration** - Native quantum_matrix hardware works
3. **Visualization packets** - Full data is available for rendering

---

## Current Test Infrastructure

### Existing Tests
1. **`test_biome_construction.gd`** - Tests `BootManager.load_biome()`
   - ✅ Biome loading sequence
   - ✅ Registration, plot assignment, metadata
   - ✅ Quantum operator rebuild
   - ✅ Density matrix validation (trace=1.0)
   - ❌ Does NOT test BiomeBuilder directly

2. **`test_quantum_integration.gd`** - Tests quest system
   - Not relevant for biome building

3. **Current gaps:**
   - No tests for `BiomeBuilder.build_biome_quantum_system()`
   - No tests for `BiomeBuilder.rebuild_icons_for_standings()`
   - No validation of H vs L separation
   - No C++ native operator verification
   - No visualization packet validation

---

## Test Strategy

### Phase 1: Unit Tests ✅ (NEW)
**File:** `Tests/test_biome_builder.gd`

Test `BiomeBuilder` directly (headless, fast):

#### 1.1 Build Correctness
- [x] Create test: Build StarterForest quantum system
- [x] Verify: H matrix is correct dimension (32x32 for 5 qubits)
- [x] Verify: L operators built from BiomeLindblad spec
- [x] Verify: Icons have NO Lindblad terms (H-only)
- [x] Verify: Density matrix initializes to valid state (trace=1.0)

#### 1.2 Faction Standings Rebuild
- [x] Create test: Rebuild with changed faction standings
- [x] Verify: H matrix changes
- [x] Verify: L operators unchanged
- [x] Verify: Density matrix stays valid

#### 1.3 Error Handling
- [x] Create test: Invalid emoji pairs
- [x] Create test: Empty Lindblad spec
- [x] Verify: Graceful failure with error messages

---

### Phase 2: C++ Acceleration ✅ (NEW)
**File:** `Tests/test_biome_builder_native.gd`

Verify native quantum_matrix C++ library works:

#### 2.1 Native Matrix Operations
- [x] Create test: Build H using native ComplexMatrix
- [x] Verify: Matrix multiplication works (H * |ψ⟩)
- [x] Verify: Trace calculation works (Tr(ρ) = 1.0)
- [x] Time test: Native vs GDScript speed comparison

#### 2.2 Evolution Acceleration
- [x] Create test: Run quantum evolution for 100 timesteps
- [x] Verify: No crashes or NaN values
- [x] Verify: Purity stays in valid range [0, 1]
- [x] Time test: Measure evolution performance

---

### Phase 3: Visualization Packets ✅ (NEW)
**File:** `Tests/test_biome_visualization_packet.gd`

Ensure visualization layer gets complete data:

#### 3.1 Visual Config Packet
- [x] Create test: Call `biome.get_visual_config()`
- [x] Verify: Returns all required fields:
  - `color` (Color)
  - `label` (String)
  - `center_offset` (Vector2)
  - `oval_width/height` (float)
  - `enabled` (bool)

#### 3.2 Quantum State Packet
- [x] Create test: Call `biome.get_status()`
- [x] Verify: Returns quantum state data:
  - `type` (biome name)
  - `qubits` (int)
  - `time` (float)
  - `cycles` (int)

#### 3.3 Observable Queries
- [x] Create test: Query specific observables
- [x] Verify: `get_emoji_probability(emoji)` works
- [x] Verify: `get_observable_coherence(north, south)` works
- [x] Verify: `get_purity()` returns valid float [0, 1]

---

### Phase 4: Integration Test ✅ (EXTEND EXISTING)
**File:** `tests/test_biome_construction.gd` (extend)

Add BiomeBuilder-specific tests to existing suite:

#### 4.1 Boot Path Test
- [x] Test: Load StarterForest via BootManager
- [x] Verify: Uses BiomeBuilder internally
- [x] Verify: Console shows "(H=factions, L=biome)"

#### 4.2 Live Rebuild Test
- [x] Test: Call `biome.rebuild_quantum_operators()` during runtime
- [x] Verify: Operators rebuild successfully
- [x] Verify: Evolution continues without crashes

---

## Test Execution Plan

### Step 1: Create Unit Tests
```bash
# Create test file
touch Tests/test_biome_builder.gd

# Run headless
godot --headless -s Tests/test_biome_builder.gd
```

### Step 2: Create Native Tests
```bash
# Create test file
touch Tests/test_biome_builder_native.gd

# Run with C++ library loaded
godot --headless -s Tests/test_biome_builder_native.gd
```

### Step 3: Create Visualization Tests
```bash
# Create test file
touch Tests/test_biome_visualization_packet.gd

# Run headless
godot --headless -s Tests/test_biome_visualization_packet.gd
```

### Step 4: Extend Integration Tests
```bash
# Edit existing file
vim tests/test_biome_construction.gd

# Add new test cases for BiomeBuilder

# Run full suite
godot --headless -s tests/test_biome_construction.gd
```

---

## Success Criteria

### ✅ All tests must pass:
1. **Build Correctness** - 8/8 tests pass
2. **C++ Acceleration** - 4/4 tests pass
3. **Visualization Packets** - 6/6 tests pass
4. **Integration** - 13/13 tests pass (11 existing + 2 new)

### ✅ Performance benchmarks:
- H matrix build: < 100ms (cached), < 8s (uncached)
- L operator build: < 50ms
- Evolution timestep: < 5ms per step (native)
- Visualization query: < 1ms per observable

### ✅ No regressions:
- Existing `test_biome_construction.gd` still passes
- All biomes can still load and evolve
- Boot sequence completes without errors

---

## Next Actions

1. **Create `test_biome_builder.gd`** - Unit tests for BiomeBuilder
2. **Create `test_biome_builder_native.gd`** - C++ acceleration tests
3. **Create `test_biome_visualization_packet.gd`** - Viz packet tests
4. **Extend `test_biome_construction.gd`** - Add BiomeBuilder integration tests
5. **Run all tests** - Verify success criteria met
6. **Document results** - Update this file with actual performance numbers

---

## Test Results (To Be Filled)

### Unit Tests
```
Run: [DATE]
Status: [ ] PASS / [ ] FAIL
Details:
```

### Native Tests
```
Run: [DATE]
Status: [ ] PASS / [ ] FAIL
Performance:
  - Matrix multiply: XXX ms
  - Evolution step: XXX ms
```

### Visualization Tests
```
Run: [DATE]
Status: [ ] PASS / [ ] FAIL
Details:
```

### Integration Tests
```
Run: [DATE]
Status: [ ] PASS / [ ] FAIL
Details:
```
