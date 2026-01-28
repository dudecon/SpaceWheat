# How to Capture Performance Logs

## What Was Added

Added detailed performance logging to `QuantumForceGraph._draw()` to show where rendering time is spent. The code already had timing instrumentation in:

1. ✅ **Farm._process()** - Grid and composting timing
2. ✅ **BiomeEvolutionBatcher** - Quantum evolution timing
3. ✅ **QuantumForceGraph._draw()** - NOW has layer-by-layer breakdown

All logs print **every 60 frames** (~1 second at 60 FPS).

---

## How to Run and Capture Logs

### Option 1: Visual Mode (Recommended)

```bash
cd /home/tehcr33d/ws/SpaceWheat
godot scenes/FarmView.tscn 2>&1 | tee performance_logs.txt
```

Then:
1. Let the game run for ~10 seconds (empty grid)
2. Plant all 24 plots manually (use explore action)
3. Let it run for another ~10 seconds (full grid)
4. Close Godot (Ctrl+C or ESC → Quit)

### Option 2: With Test Script

Run the interactive stress test (it already plants plots automatically):

```bash
godot Tests/stress_test_harvest_perf.tscn 2>&1 | tee stress_test_perf.txt
```

Wait for Phases 1-2 to complete, then close.

---

## What to Look For in Logs

### 1. Quantum Evolution (Physics - 20Hz)

```
BiomeEvolutionBatcher: Evolved 2 biomes in 1.23ms
```

- Shows how long quantum evolution takes
- Should be **< 5ms** for good performance
- "skipped X" means biomes with no terminals (optimization working)

### 2. Farm Process (Visual - 60 FPS)

```
Farm Process Trace: Total 1234 us (Grid: 890, Compost: 344)
```

- Shows _process() breakdown in **microseconds**
- Grid: FarmGrid plot processing
- Compost: Mushroom visual effects
- Should be **< 10,000 us (10ms)** for 60 FPS

### 3. Quantum Graph Rendering (Visual - 60 FPS)

```
QuantumForceGraph Draw: 8.45ms total (Ctx=0.12 Region=0.34 Infra=0.23 Edge=1.45 Effects=0.89 Bubble=5.12 Sun=0.30 Debug=0.00) [24 nodes]
```

**Layer breakdown**:
- **Ctx**: Context building (negligible)
- **Region**: Background regions (< 1ms)
- **Infra**: Gate infrastructure (< 1ms)
- **Edge**: Entanglement/coherence edges (1-2ms)
- **Effects**: Particles/attractors (1-2ms)
- **Bubble**: **MOST EXPENSIVE** - quantum bubbles (5-10ms for 24 nodes)
- **Sun**: Sun qubit (< 1ms)
- **Debug**: Debug overlay (0ms if disabled)

---

## Performance Targets

**60 FPS = 16.67ms frame budget**

### Empty Grid (0 planted)
- Physics: ~0.1ms (evolution skipped)
- Process: ~5-10ms (UI + minimal rendering)
- **Expected**: 60+ FPS

### Full Grid (24 planted)
- Physics: ~2-5ms (quantum evolution)
- Process: ~10-15ms (rendering + UI)
- **Expected**: 50-60 FPS

If performance is worse than this, look for:
- **Bubble rendering > 10ms** → Optimization needed (batching helps here)
- **Farm Process > 10ms** → Grid plot processing issue
- **BiomeEvolution > 5ms** → Quantum evolution bottleneck

---

## Example Analysis

### Good Performance (50+ FPS)

```
BiomeEvolutionBatcher: Evolved 2 biomes in 2.34ms
Farm Process Trace: Total 8234 us (Grid: 5123, Compost: 3111)
QuantumForceGraph Draw: 9.12ms total (...Bubble=6.34...) [24 nodes]
```

- Physics: 2.34ms ✓
- Process: 8.23ms + 9.12ms = 17.35ms ✓
- **Total**: ~19.7ms = **50 FPS** ✓

### Poor Performance (< 30 FPS)

```
BiomeEvolutionBatcher: Evolved 4 biomes in 15.67ms  ← TOO SLOW
Farm Process Trace: Total 45234 us (Grid: 42123, Compost: 3111)  ← TOO SLOW
QuantumForceGraph Draw: 38.45ms total (...Bubble=32.11...) [24 nodes]  ← TOO SLOW
```

- Physics: 15.67ms ⚠️
- Process: 45.23ms + 38.45ms = 83.68ms ⚠️
- **Total**: ~99ms = **10 FPS** 🔴

**Bottleneck**: Everything is slow! Need to investigate each system.

---

## Quick Test Script

Create `test_perf.sh`:

```bash
#!/bin/bash
echo "Running 30-second performance capture..."
timeout 30 godot scenes/FarmView.tscn 2>&1 | tee /tmp/perf_capture.txt &
GODOT_PID=$!

echo "Godot started (PID: $GODOT_PID)"
echo "Manually plant plots in the game, then wait..."
sleep 28

echo "Stopping Godot..."
kill $GODOT_PID 2>/dev/null

echo ""
echo "=== PERFORMANCE SUMMARY ==="
echo ""
echo "Quantum Evolution (BiomeEvolutionBatcher):"
grep "BiomeEvolutionBatcher" /tmp/perf_capture.txt | tail -5
echo ""
echo "Farm Process (Grid + Compost):"
grep "Farm Process Trace" /tmp/perf_capture.txt | tail -5
echo ""
echo "Rendering (QuantumForceGraph):"
grep "QuantumForceGraph Draw" /tmp/perf_capture.txt | tail -5
```

Run with:
```bash
chmod +x test_perf.sh
./test_perf.sh
```

---

## Next Steps

1. **Run the game** (either manually or with test script)
2. **Capture logs** showing the performance breakdown
3. **Identify bottleneck**:
   - If Bubble rendering > 10ms → Batching optimization would help
   - If BiomeEvolution > 5ms → Quantum algorithm needs optimization
   - If Farm Process > 10ms → Grid plot processing issue

4. **Share logs** with the performance summary to determine next optimization

---

## Files Modified

- `Core/Visualization/QuantumForceGraph.gd` - Added layer-by-layer timing logs

## Files Already Instrumented

- `Core/Farm.gd:623-624` - Farm process timing
- `Core/Environment/BiomeEvolutionBatcher.gd:111-116` - Quantum evolution timing
