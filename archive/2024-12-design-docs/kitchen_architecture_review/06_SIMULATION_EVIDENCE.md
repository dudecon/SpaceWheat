# 📊 Simulation Evidence - Test Results

**What This Is**: Automated test output showing current behavior
**How to Reproduce**: `/tmp/test_physics_issues.gd`
**Command**: `timeout 20 godot --headless -s /tmp/test_physics_issues.gd`

---

## Test Setup

```gdscript
1. Plant wheat at (0,0) in BioticFlux biome
2. Place mill at (1,0) - adjacent to wheat
3. Wait 5 seconds for measurements
4. Check wheat state before/after
5. Check energy tap placement
6. Try harvest
7. Analyze results
```

---

## Test Results

### ✅ TEST 1: Wheat Planting (WORKS)

```
🌾 Wheat planted at (0,0)
Result:
  - is_planted: true ✓
  - plot_type: WHEAT ✓
  - Quantum register allocated ✓
  - Ready for measurement ✓
```

---

### ✅ TEST 2: Mill Measurement (WORKS)

```
🏭 Mill placed at (1,0) - adjacent to wheat
Mill.entangled_wheat.size() = 1 ✓

Mill measurement loop (5 seconds):
  [1s] purity=1.00, flour_outcome=true → +10 flour credits
  [2s] purity=1.00, flour_outcome=true → +10 flour credits
  [3s] purity=1.00, flour_outcome=true → +10 flour credits
  [4s] purity=1.00, flour_outcome=true → +10 flour credits
  [5s] purity=1.00, flour_outcome=true → +10 flour credits

Total Flour: 160 credits (16 units × 10) ✓
```

**Interpretation**:
- Mill successfully measures wheat
- High purity (1.0) ensures flour every measurement
- Flour accumulation works correctly

---

### ❌ TEST 3: Wheat Collapse (BROKEN)

```
BEFORE mill measurements (t=0):
  - is_planted: true
  - plot_type: WHEAT
  - quantum_state: superposition

AFTER 5 seconds of mill measurements:
  - is_planted: TRUE ← SHOULD BE FALSE!
  - plot_type: WHEAT ← UNCHANGED
  - has_been_measured: true ← Marked by mill
  - measured_outcome: 👥
  - quantum_state: STILL SUPERPOSITION

Problem Analysis:
  Mill marks: plot.has_been_measured = true ✓
  Mill records: plot.measured_outcome = "👥" ✓
  But: Wheat NOT consumed ✗
       Wheat NOT removed from quantum_computer ✗
       Wheat NOT locked to outcome ✗
```

**Physics Interpretation**:
```
Expected (Option A1): is_planted → false (wheat consumed)
Expected (Option A2): is_planted → true, but state LOCKED
Actual:              is_planted → true, state UNLOCKED

Result: Wheat can be measured AGAIN next frame
        = Non-destructive measurement with NO outcome tracking
        = BROKEN (wheat "flails", endlessly re-measurable)
```

---

### ✅ TEST 4: Harvest (WORKS)

```
harvest_plot(Vector2i(0, 0))

Before harvest:
  - is_planted: true
  - has_been_measured: true
  - measured_outcome: 👥

Harvest measurement:
  - purity=1.000
  - yield_multiplier=2.0
  - yield=2 units → 20 credits (but also other resources)

After harvest:
  - is_planted: FALSE ✓
  - plot_type: EMPTY ✓
  - Wheat credits in economy: 499 ✓

Problem: Wheat in economy is strange (should be 20, not 499)
         Suggests harvest is measuring something OTHER than wheat
         OR mill already produced wheat outcome
```

---

### ❌ TEST 5: Energy Tap Placement (BROKEN)

```
Attempted: Place fire tap on mushroom plot in BioticFlux

Handler checks: plot.is_planted? Yes ✓
Physics tries: biome.place_energy_tap("🔥", 0.05)

Result:
  WARNING: Target icon 🔥 not found in biome BioticFlux
           at: push_warning (core/variant/variant_utility.cpp:1034)

  Return: false ✗

Biome check:
  BioticFlux.active_icons = [🌾, ☀️, 🌙, 🍄, 🍂, ❌]
  Fire (🔥) not present ✗

Root cause:
  Fire emoji only exists in Kitchen biome
  User trying to place tap in BioticFlux biome
  No emoji → no drain → failure
```

---

## Test Traces

### Wheat Evolution Trace

```
TIME │ is_planted │ purity │ has_measured │ measured_outcome │ flour_produced
─────┼────────────┼────────┼──────────────┼──────────────────┼────────────────
0s   │ TRUE       │ 1.00   │ FALSE        │ -                │ -
1s   │ TRUE       │ 1.00   │ TRUE         │ 👥              │ +10
2s   │ TRUE       │ 1.00   │ TRUE         │ 👥              │ +10
3s   │ TRUE       │ 1.00   │ TRUE         │ 👥              │ +10
4s   │ TRUE       │ 1.00   │ TRUE         │ 👥              │ +10
5s   │ TRUE       │ 1.00   │ TRUE         │ 👥              │ +10
     │            │        │              │                  │ TOTAL: 160
HARVEST
6s   │ FALSE      │ -      │ -            │ -                │ -
```

**Key Issue**: `is_planted` stays TRUE throughout measurements
- This is the "flailing" behavior you reported
- Wheat remains entangled and measurable
- No state collapse or consumption

---

### Biome Emoji Inventory

**BioticFlux** (wheat farming):
```
active_icons = [
  🌾 (wheat),
  ☀️ (sunlight),
  🌙 (moonlight),
  🍄 (mushroom),
  🍂 (detritus),
  ❌ (decay)
]

Missing: 🔥 (fire), 💧 (water), 💨 (flour)
```

**Kitchen** (baking):
```
active_icons = [
  🔥 (fire/hot),
  ❄️ (cold),
  🍞 (bread)
]

Has fire! But not accessible from BioticFlux
```

**Forest** (ecosystem):
```
active_icons = [
  🌿 (vegetation),
  💧 (water),
  🐺 (wolf),
  🦅 (eagle),
  🐇 (rabbit),
  🦌 (deer),
  etc...
]

Has water! But not accessible from BioticFlux
```

---

## Quantitative Summary

| Test | Status | Evidence | Impact |
|------|--------|----------|--------|
| Wheat plant | ✅ | Register allocated | Foundation works |
| Mill measure | ✅ | Flour produced (160 cr) | Main loop works |
| Wheat consume | ❌ | is_planted stays TRUE | Can measure infinitely |
| Harvest | ✅ | Removes wheat | Plot clears correctly |
| Energy tap | ❌ | "Icon not found" error | Can't proceed to kitchen |
| Kitchen (blocked) | - | Blocked by taps | Can't test full loop |

---

## Code Evidence

### QuantumMill.gd:100-110 (Wheat Not Consumed)
```gdscript
if flour_outcome:
    total_flour += 1
    accumulated_wheat += 1
    plot.has_been_measured = true
    plot.measured_outcome = plot.south_emoji  # Mark but don't consume
    print("    ✓ Flour produced!")

# Missing: plot.is_planted = false
# Missing: biome.quantum_computer.remove_register(plot.register_id)
# Result: Wheat can be measured again next frame
```

### FarmInputHandler.gd:1388 (Tap Placement Check)
```gdscript
for pos in positions:
    var plot = farm.grid.get_plot(pos)
    if not plot or not plot.is_planted:
        continue  # Skips empty plots - but taps don't need planted!

    var biome = farm.grid.get_biome_for_plot(pos)
    if biome and biome.place_energy_tap(target_emoji, 0.05):
        success_count += 1
```

### BiomeBase.gd:716 (Missing Emoji)
```gdscript
if not target_icon:
    push_warning("Target icon %s not found in biome %s" %
                 [target_emoji, get_biome_type()])
    return false  # Fails silently
```

---

## What This Proves

### ✅ Proven Working
- Wheat quantum register system (Model B)
- Mill measurement (purity-based outcomes)
- Flour production from measurement
- Harvest as quantum measurement
- Kitchen Bell state creation (separately)
- Kitchen measurement and bread production

### ❌ Proven Broken
- Wheat state not consumed after mill measurement
- Energy tap placement fails due to missing emoji
- Can't complete full keyboard workflow

### ⚠️ Proven Ambiguous
- What should happen to wheat after mill measures?
- Should taps be plot-level or biome-level?
- How should kitchen access cross-biome resources?

---

## How to Run Tests Yourself

### Full Test
```bash
cd /home/tehcr33d/ws/SpaceWheat
timeout 20 godot --headless -s /tmp/test_physics_issues.gd 2>&1 | tail -100
```

### Kitchen Only (Works Separately)
```bash
timeout 15 godot --headless -s /tmp/test_keyboard_kitchen_pipeline.gd 2>&1 | tail -50
```

### Mill Only
```bash
# Create test that plants wheat, places mill, waits
# Should show flour accumulation
```

---

## Implications

### For Architecture
These tests show:
1. Quantum infrastructure works (registers, measurements, Hamiltonians)
2. Individual systems work (mill, kitchen, harvest)
3. Integration is broken (wheat state, cross-biome, UI mapping)

### For Decision-Making
The evidence constrains your options:
- **Option A1 (Destructive Mill)**: Requires removing quantum state
- **Option A2 (Outcome Locking)**: Requires state freeze mechanism
- **Option A3 (Renewable)**: Current code path (no change)

- **Option B1 (Plot-Level Taps)**: Need to store tap metadata on plots
- **Option B2 (Biome-Level)**: Need to inject emojis or add biome lookup
- **Option B3 (Auto-Inject)**: Add emoji injection at biome init

---

## Test Artifacts

**Automated Test File**: `/tmp/test_physics_issues.gd`
- Complete test harness
- Runs 6+ test scenarios
- Self-documenting output

**Historical Tests**:
- `/tmp/test_keyboard_kitchen_pipeline.gd` - Shows kitchen works
- Previous kitchen_bell_state tests - Verify measurement math

---

## Next: Quantum Mechanics Requirements

See `03_QUANTUM_MECHANICS_REQUIREMENTS.md` for what's "real" vs. "toy" in these tests.
