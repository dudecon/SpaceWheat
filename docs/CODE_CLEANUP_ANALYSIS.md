# SpaceWheat Code Cleanup Analysis

## 🎯 Executive Summary
Found significant cleanup opportunities across 5 categories:
1. **Deprecated Systems** (can delete)
2. **Duplicate Implementations** (consolidate)
3. **Experimental Biomes** (archive or delete)
4. **Test Infrastructure** (relocate)
5. **Version Conflicts** (resolve)

---

## 1. 🗑️ DEPRECATED SYSTEMS - Safe to Delete

### InputController (Replaced by Modal Stack)
**Status:** DEPRECATED - Replaced by PlayerShell modal stack architecture
**Files:**
- `UI/Controllers/InputController.gd` (374 lines)

**Evidence:**
- FarmView.gd line 109: Comment says "Input is now handled by PlayerShell._input() → modal stack"
- Only references in archive files and old comments
- Current system uses PlayerShell modal stack (cleaner architecture)

**Action:** DELETE file + Controllers/ directory (if empty)

---

### PlotBase Hierarchy (Replaced by BasePlot)
**Status:** DEPRECATED - Old plot system (Model B)
**Files:**
- `Core/GameMechanics/PlotBase.gd` (70 lines)
- `Core/GameMechanics/ImperialPlot.gd` (extends PlotBase)
- `Core/GameMechanics/ImperialPlotNoon.gd` (extends ImperialPlot)
- `Core/GameMechanics/ImperialPlotMidnight.gd` (extends ImperialPlot)
- `Core/GameMechanics/CelestialPlot.gd` (extends PlotBase)

**Evidence:**
- PlotBase comment: "MODEL B: quantum_state is owned by parent biome" (OLD)
- BasePlot comment: "Model C - Analog Bath" (CURRENT)
- ImperialPlot only used in old tests
- Current system uses BasePlot → FarmPlot exclusively
- FarmGrid.gd line 116, 629: `FarmPlot.new()` (not PlotBase)

**Action:** DELETE all PlotBase hierarchy files (5 files total)

---

### Test/Debug Scripts in Core/
**Status:** Development artifacts left in production code
**Files:**
- `Core/GameController_KitchenTest.gd` - Kitchen testing script
- `Core/GameState/DebugEnvironment.gd` - Debug environment setup
- `tests/TestQERSignal.gd` - QER signal testing
- `tests/test_qer_signal_direct.gd` - Direct QER test
- `UI/LayoutDebugTester.gd` - UI layout debugging

**Evidence:**
- "Test" and "Debug" in filenames
- Only referenced in test files
- LayoutDebugTester only in UITestOnly.tscn (test scene)

**Action:** MOVE to Tests/ directory

---

## 2. 🔀 DUPLICATE IMPLEMENTATIONS - Resolve Conflicts

### FactionDatabase vs FactionDatabaseV2
**Status:** INCONSISTENT - Mixed usage across codebase
**Files:**
- `Core/Quests/FactionDatabase.gd` (32K, 748 lines)
- `Core/Quests/FactionDatabaseV2.gd` (50K, 1200+ lines)

**Current Usage:**
- **V2 users:** QuestManager.gd (MAIN SYSTEM)
- **V1 users:**
  - QuestRewards.gd
  - QuestTheming.gd
  - GameStateManager.gd
  - PlayerShell.gd
  - OverlayManager.gd
  - All test files

**Impact:** V2 has more content but most code uses V1

**Action:**
- **OPTION A (Recommended):** Migrate all V1 references to V2, delete V1
- **OPTION B:** Keep V1 as stable, migrate V2 content to V1, delete V2
- **OPTION C (Quick):** Rename V2 → FactionDatabaseV3, keep both for now

---

## 3. 🧪 EXPERIMENTAL BIOMES - Not Used in Production

### Unused Biome Types
**Status:** Experimental/test biomes not loaded by Farm.gd
**Files:**
- `Core/Environment/MinimalTestBiome.gd` (1.1K)
- `Core/Environment/TestBiome.gd` (1.5K)
- `Core/Environment/DualBiome.gd` (1.7K)
- `Core/Environment/TripleBiome.gd` (2.3K)
- `Core/Environment/MergedEcosystem_Biome.gd` (2.6K)
- `Core/Environment/NeutralBiome.gd` (1.9K)
- `Core/Environment/NullBiome.gd` (1.5K)
- `Core/Environment/EconomicBiome.gd` (12.5K)
- `Core/Environment/GranaryGuilds_MarketProjection_Biome.gd` (6.8K)

**Evidence:**
- Farm.gd ONLY creates 4 biomes:
  - BioticFluxBiome ✓
  - MarketBiome ✓
  - ForestEcosystem_Biome ✓
  - QuantumKitchen_Biome ✓
- Rest are only used in Tests/
- Commented out TestBiome creation in Farm.gd lines 294-314

**Action:**
- **OPTION A:** DELETE unused biomes entirely
- **OPTION B:** MOVE to Tests/Biomes/ for reference
- **OPTION C:** ARCHIVE to archive/2024-12-experimental-biomes/

**Total Size:** ~30KB of unused code

---

## 4. 📂 MISPLACED FILES

### Test Files in Wrong Locations
**Files in wrong directories:**
- `tests/` (lowercase) should be `Tests/` (capitalized)
  - `tests/TestQERSignal.gd`
  - `tests/test_qer_signal_direct.gd`

**Action:** MOVE to Tests/ directory (standardize)

---

## 5. 📊 CLEANUP IMPACT SUMMARY

### High-Confidence Deletions
| Category | Files | Lines | Status |
|----------|-------|-------|--------|
| InputController | 1 | ~374 | DEPRECATED |
| PlotBase hierarchy | 5 | ~500 | REPLACED |
| Test/Debug scripts | 5 | ~300 | MISPLACED |
| **TOTAL** | **11** | **~1174** | **Safe to remove** |

### Medium-Confidence (Needs Decision)
| Category | Files | Lines | Decision Needed |
|----------|-------|-------|----------------|
| FactionDatabase conflict | 2 | ~2000 | V1 vs V2? |
| Experimental biomes | 9 | ~800 | Delete/Archive/Keep? |
| **TOTAL** | **11** | **~2800** | **User choice** |

---

## 🎬 PROPOSED CLEANUP PHASES

### Phase 1: Safe Deletions (High Confidence)
1. Delete deprecated InputController system
2. Delete obsolete PlotBase hierarchy (5 files)
3. Move test/debug scripts to Tests/
4. Consolidate tests/ → Tests/

**Impact:** Remove ~1200 lines of dead code, no functionality loss

### Phase 2: Resolve Conflicts (Medium Confidence)
1. Resolve FactionDatabase V1/V2 conflict
2. Handle experimental biomes (delete/archive/keep)

**Impact:** Remove ~2800 lines, requires decision

### Phase 3: Documentation
1. Update any documentation referencing deleted systems
2. Add migration notes if needed

---

## ❓ QUESTIONS FOR USER

1. **FactionDatabase:** Migrate everything to V2 and delete V1? Or keep V1 as stable?
2. **Experimental Biomes:** Delete entirely, archive, or move to Tests/?
3. **Should I proceed with Phase 1 (safe deletions) automatically?**
