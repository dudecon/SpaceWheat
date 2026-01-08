# 🍞 Full Kitchen Test - Keyboard Input & Display

## Overview

This test demonstrates the **complete gameplay loop** using actual keyboard input simulation and displays it in a game window so you can watch it execute in real-time.

### What Gets Tested

The test performs the following sequence:

1. **🌱 Plant Phase** (3 crops, ~2 seconds)
   - Uses Tool 1 (Grower), Q key to plant
   - Plants 3 wheat crops in a line at positions (0,0), (1,0), (2,0)

2. **🌿 Growth Phase** (3 biome days, ~65 seconds)
   - Biotic flux energy system evolves crops
   - Energy grows from 0.3 → 0.78+ per crop
   - Spring attraction pulls theta toward stable point

3. **✂️ Harvest Phase** (~2 seconds)
   - Uses Tool 1 (Grower), R key to harvest
   - Measures and collects quantum qubits
   - Each crop yields ~3 resources

4. **👨‍🍳 Kitchen Phase** (~2 seconds)
   - Builds kitchen building (Tool 3, R)
   - Bell state detected from 3-qubit GHZ pattern
   - Produces bread via triplet measurement
   - Bread energy: 1.87 (80% of input total)

5. **💰 Market Phase** (~1 second)
   - Trades 10 flour for 800 credits (80 credits/flour)
   - Classical market economy in action

6. **✅ Complete** (~90 seconds total)

---

## How to Run

### Option 1: Godot Editor

1. Open the project in Godot Editor
2. Navigate to: **scenes/TestFullKitchenKeyboardDisplay.tscn**
3. Click **Play Scene** (or press F6)
4. Watch the keyboard inputs execute automatically!
5. The test will complete in ~90 seconds and the window will close

### Option 2: Command Line (with display)

```bash
# Run with Godot (NOT --headless!)
godot scenes/TestFullKitchenKeyboardDisplay.tscn
```

Then press the Play button in the Godot editor, or:

```bash
# Direct execution (requires Godot in PATH)
godot --main-scene scenes/TestFullKitchenKeyboardDisplay.tscn
```

### Option 3: Headless Output (text-only)

If you want to see just the text output without display:

```bash
godot --headless -s test_full_kitchen_complete_loop.gd
```

---

## What You'll See

The game window will show:

1. **Black background** (farm render area)
2. **Console output** (tee'd to terminal) showing:
   - Each step being executed
   - Progress bar for long steps (growth phase)
   - Quantum state updates
   - Resource changes

Example output:
```
════════════════════════════════════════════════════════════════════════════════════════════════════
🍞 FULL KITCHEN KEYBOARD AUTO-SEQUENCER
Complete gameplay loop with keyboard input simulation
════════════════════════════════════════════════════════════════════════════════════════════════════

⏱️  Step 0: Initialize Farm (2.0 seconds)
   ✓ Farm initialized

📌 Step 1: Select Plot (T) (instant)
   ✓ Plot (0,0) selected

📌 Step 2: Select Tool 1 (1) (instant)
   ✓ Tool 1 (Grower) selected

📌 Step 3: Plant Crop 1 (Q) (instant)
   ✓ Planted crop 1

...

⏳ Step 8: Grow Crops (60s)
   [████████████████████████████░░] 93% (55.5/60.0 s)

...

✅ FULL KITCHEN TEST COMPLETE!
```

---

## Technical Details

### Files Involved

- **UI/FarmView.gd** - Main UI orchestration
- **UI/FarmUIController.gd** - Input handler coordination
- **UI/FullKitchenAutoSequence.gd** - Keyboard auto-sequencer
- **scenes/TestFullKitchenKeyboardDisplay.tscn** - Test scene
- **Core/Farm.gd** - Farm game system
- **Core/Environment/Biome.gd** - Quantum evolution
- **Core/Environment/QuantumKitchen_Biome.gd** - Kitchen measurement system

### Keyboard Sequence

The auto-sequencer simulates these keyboard inputs:

```
T → Select plot (0,0)
1 → Select Tool 1 (Grower)
Q → Plant crop
Y → Select plot (1,0)
Q → Plant crop
U → Select plot (2,0)
Q → Plant crop

[Wait 65 seconds for growth]

T → Select plot (0,0)
R → Harvest crop
Y → Select plot (1,0)
R → Harvest crop
U → Select plot (2,0)
R → Harvest crop

[Kitchen arrangement]

3 → Select Tool 3 (Industry)
R → Build kitchen
[Bread production via measurement]

3 → Select Tool 3
Q → Build market (if needed)
[Trade flour]
```

---

## Verifying Correctness

The test is **successful** if you see:

1. ✅ Crops planted at (0,0), (1,0), (2,0)
2. ✅ Energy grows from 0.3 → 0.78+ during growth phase
3. ✅ All 3 crops harvested successfully
4. ✅ Kitchen Bell state detected as "GHZ (Horizontal)"
5. ✅ Bread produced with energy 1.87
6. ✅ Flour traded for credits at market

If any step fails, check:

- Are keyboard events being parsed? (Check console for `_press_key` calls)
- Does the farm have the biome? (Should say "Biome enabled" in output)
- Are qubits being collected? (Should list energy for each qubit)

---

## Troubleshooting

### Window doesn't appear
- Make sure you're NOT using `--headless` flag
- Run from editor with Play button (F6)

### Keyboard inputs not being received
- Check that FarmInputHandler is properly wired
- Verify InputMap has entries for Q, E, R, numbers, TYUIOP

### Biome not evolving
- Should see "Biome initialized" message
- Should see spring attraction working (theta changing)
- Check that `biome._ready()` was called

### Kitchen Bell state not detected
- Plots must be in a valid pattern (horizontal line = GHZ)
- Positions must be exactly (0,0), (1,0), (2,0)

---

## Next Steps

Once this test passes, you can:

1. **Extend the test** - Add more crops, different Bell state patterns
2. **Test market** - Verify trading in different supply conditions
3. **Test kitchen variations** - Try W-state, Cluster state patterns
4. **Test with guilds** - Bread consumption and market pressure
5. **Full game loop** - Multiple cycles of farming → kitchen → market → repeat

---

## Reference: System Integration

```
🎮 Game Loop Integration:

[Farm System]
  ├─ Plant (Tool 1, Q)
  ├─ Entangle (Tool 1, E)
  └─ Measure & Harvest (Tool 1, R)
         ↓
[Biome Evolution]
  ├─ Spring attraction (θ changes)
  ├─ Energy transfer (E grows)
  └─ Decoherence (dissipation)
         ↓
[Kitchen System]
  ├─ Bell state detection (spatial pattern)
  ├─ Triplet measurement (3 qubits → 1 bread)
  └─ Entanglement storage
         ↓
[Market System]
  ├─ Classical trading
  ├─ Flour → Credits
  └─ Supply/demand dynamics
         ↓
[Economy]
  ├─ Resource tracking (wheat, labor, flour, credits)
  └─ Player inventory
```

---

## Author Notes

This test validates that **all systems work together** using actual gameplay inputs (keyboard) and real-time display. Previous "tests" that claimed success but had the biome frozen showed the importance of this kind of integration testing.

**Key validation points:**
- Spring attraction ACTUALLY changes theta ✓
- Energy ACTUALLY grows (not frozen) ✓
- Kitchen ACTUALLY produces bread ✓
- All via keyboard input ✓
- Visible in game window ✓

---

Good luck! 🍞✨
