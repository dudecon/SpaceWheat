# Performance Profiling Analysis

## Summary

Analyzed the codebase performance instrumentation and captured logs to determine where compute time is spent between `_process()` (rendering/UI) and `_physics_process()` (quantum simulation).

---

## Existing Performance Instrumentation

The codebase already has performance logging built-in:

### 1. Farm._process() Timing (Core/Farm.gd:611-624)

```gdscript
func _process(delta: float):
	var t0 = Time.get_ticks_usec()
	# Grid UI updates
	if grid:
		grid._process(delta)
	var t1 = Time.get_ticks_usec()

	# Passive composting
	_process_mushroom_composting(delta)
	var t2 = Time.get_ticks_usec()

	if Engine.get_process_frames() % 60 == 0:
		print("Farm Process Trace: Total %d us (Grid: %d, Compost: %d)" % [t2 - t0, t1 - t0, t2 - t1])
```

**What it measures**: Visual frame processing time breakdown
- Grid UI updates (mills, markets, kitchens)
- Mushroom composting visual effects
- **Prints every 60 frames (~1 second at 60 FPS)**

### 2. BiomeEvolutionBatcher Timing (Core/Environment/BiomeEvolutionBatcher.gd:78-116)

```gdscript
func _evolve_batch(dt: float):
	var batch_start = Time.get_ticks_usec()
	# ... evolve biomes ...
	var batch_end = Time.get_ticks_usec()
	last_batch_time_ms = (batch_end - batch_start) / 1000.0

	if total_evolutions % 60 == 0:
		print("BiomeEvolutionBatcher: Evolved %d biomes in %.2fms" % [evolved_count, last_batch_time_ms])
```

**What it measures**: Quantum evolution batch time
- Runs at 10Hz (every 0.1s)
- Evolves 2 biomes per batch
- Skips biomes with no bound terminals
- **Prints every 60 evolution ticks (~6 seconds)**

### 3. QuantumForceGraph._draw() Timing (Core/Visualization/QuantumForceGraph.gd:193-219)

```gdscript
func _draw():
	var t_start = Time.get_ticks_usec()
	var ctx = _build_context()

	# Draw layers:
	region_renderer.draw(self, ctx)       # Background
	infra_renderer.draw(self, ctx)        # Gates
	edge_renderer.draw(self, ctx)         # Edges
	effects_renderer.draw(self, ctx)      # Particles
	bubble_renderer.draw(self, ctx)       # Bubbles
	bubble_renderer.draw_sun_qubit(self, ctx)  # Sun
```

**What it measures**: Rendering layer breakdown
- **NOTE**: Timer started but NOT printing results
- **ACTION NEEDED**: Add timing log at end of _draw()

---

## Captured Performance Logs

### Empty Grid (No Planted Plots)

```
BiomeEvolutionBatcher: Evolved 0 biomes in 0.07ms (skipped 2)
BiomeEvolutionBatcher: Evolved 0 biomes in 0.05ms (skipped 2)
BiomeEvolutionBatcher: Evolved 0 biomes in 0.21ms (skipped 2)
```

**Findings**:
- Quantum evolution time: **0.05-0.21ms** (negligible - all biomes skipped)
- Optimization working: "Out of sight, out of mind" skips unpopulated biomes
- Empty grid has minimal physics overhead

**Missing Data**: Farm Process Trace logs not captured (condition not met or print disabled)

---

## Architectural Separation (Physics vs Visual)

### Physics Loop (_physics_process @ 20Hz)

**Location**: `Core/Farm.gd:627-635`

```gdscript
func _physics_process(delta: float) -> void:
	# Quantum evolution (batched)
	if biome_evolution_batcher:
		biome_evolution_batcher.physics_process(delta)

	# Lindblad pump/drain effects
	_process_lindblad_effects(delta)
```

**What runs here**:
1. **BiomeEvolutionBatcher** - Rotational quantum evolution
   - Evolves 2 biomes per tick at 10Hz effective rate
   - Configuration: `BIOMES_PER_FRAME = 2`, `EVOLUTION_INTERVAL = 0.1`
   - Skips biomes with no bound terminals

2. **Lindblad effects** - Pump/drain from Tool 2

**Optimization Applied**: Quantum evolution separated from visual framerate (see `FRAMERATE_SEPARATION_PROPOSAL.md`)

### Visual Loop (_process @ 60+ FPS)

**Location**: `Core/Farm.gd:611-625`

```gdscript
func _process(delta: float):
	# Grid UI updates
	if grid:
		grid._process(delta)

	# Mushroom composting effects
	_process_mushroom_composting(delta)
```

**What runs here**:
1. **FarmGrid._process()** (`Core/GameMechanics/FarmGrid.gd:188-208`)
   - Plot growth (for all planted plots)
   - Icon network calculations
   - Mills/markets throttled to 10Hz

2. **Mushroom composting** - Visual particle effects

3. **QuantumForceGraph._draw()** (called by engine on queue_redraw())
   - Background regions
   - Gate infrastructure
   - Edge relationships
   - Particles/attractors
   - Quantum bubbles (24 nodes × 12 layers = 288 draw calls)
   - Sun qubit

---

## Performance Hypothesis (Based on Code Analysis)

### Expected Breakdown - Empty Grid

- **_physics_process**: ~0.05ms (quantum evolution skipped)
- **_process**: ~5-10ms (UI + minimal rendering)
- **Target**: 60 FPS (16.67ms budget)
- **Status**: Should achieve 60 FPS easily

### Expected Breakdown - Full Grid (24 Planted)

Based on `PERFORMANCE_BREAKDOWN.md` findings:

**_physics_process** (~2-5ms):
- Quantum evolution: 2-4 biomes evolving per batch
  - Forest (32D): ~1-2ms per evolution
  - Other biomes (8D): ~0.5-1ms per evolution
- Lindblad effects: ~0.5ms

**_process** (~10-15ms):
- FarmGrid plot growth: ~2-3ms (24 plots)
- QuantumForceGraph rendering: ~8-12ms
  - Bubble renderer: ~5-8ms (24 bubbles × 12 layers)
  - Edge renderer: ~2-3ms
  - Effects renderer: ~1-2ms

**Total frame time**: ~12-20ms
- **Expected FPS**: 50-83 FPS (within 60 FPS target)
- **Bottleneck**: _process() (rendering) at 60-75% of frame time

---

## Evidence from Previous Stress Test

From `/tmp/stress_full_3phase.log` (session context):

**Phase 1 (Empty Grid)**:
- FPS: ~36 FPS
- Frame time: ~46ms

**Phase 2 (Full Grid)**:
- FPS: ~6 FPS
- Frame time: ~166ms

**Phase 3 (Action Spam)**:
- FPS: ~1-2 FPS (severe degradation)

**Analysis**:
- Empty grid performance (36 FPS) is lower than expected - suggests baseline overhead
- Full grid degradation (-83% FPS) is severe
- Something else is consuming time beyond quantum evolution + rendering

---

## Debugging Next Steps

### 1. Add Missing Performance Logs

**File**: `Core/Visualization/QuantumForceGraph.gd`

Add at end of `_draw()` function (after line 219):

```gdscript
	var t_end = Time.get_ticks_usec()
	if frame_count % 60 == 0:
		print("QuantumForceGraph Draw: %.2fms (%.0f bubbles)" % [
			(t_end - t_start) / 1000.0,
			quantum_nodes.size()
		])
```

### 2. Add Layer-by-Layer Timing

Replace `_draw()` with:

```gdscript
func _draw():
	var t_start = Time.get_ticks_usec()
	var ctx = _build_context()
	var t_ctx = Time.get_ticks_usec()

	region_renderer.draw(self, ctx)
	var t_region = Time.get_ticks_usec()

	infra_renderer.draw(self, ctx)
	var t_infra = Time.get_ticks_usec()

	edge_renderer.draw(self, ctx)
	var t_edge = Time.get_ticks_usec()

	effects_renderer.draw(self, ctx)
	var t_effects = Time.get_ticks_usec()

	bubble_renderer.draw(self, ctx)
	var t_bubble = Time.get_ticks_usec()

	bubble_renderer.draw_sun_qubit(self, ctx)
	var t_sun = Time.get_ticks_usec()

	if frame_count % 60 == 0:
		print("Draw Breakdown: Ctx=%.2f Region=%.2f Infra=%.2f Edge=%.2f Effects=%.2f Bubble=%.2f Sun=%.2f (Total=%.2fms)" % [
			(t_ctx - t_start) / 1000.0,
			(t_region - t_ctx) / 1000.0,
			(t_infra - t_region) / 1000.0,
			(t_edge - t_infra) / 1000.0,
			(t_effects - t_edge) / 1000.0,
			(t_bubble - t_effects) / 1000.0,
			(t_sun - t_bubble) / 1000.0,
			(t_sun - t_start) / 1000.0
		])
```

### 3. Enable VerboseConfig Performance Logging

**File**: `Core/Config/VerboseConfig.gd`

Change line 52:
```gdscript
"perf": LogLevel.WARN,  # Only show slow frames
```

To:
```gdscript
"perf": LogLevel.TRACE,  # Show all performance logs
```

### 4. Check for Hidden Frame Spikes

Add Godot performance monitors:

```gdscript
# In Farm._process() or test script
if Engine.get_process_frames() % 60 == 0:
	print("Perf Monitor: Nodes=%d Orphans=%d DrawCalls=%d Canvas2D=%d" % [
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_2D_DRAW_CALLS_IN_FRAME)
	])
```

---

## Conclusion - Current State

### Known Facts

1. **Quantum evolution is optimized**:
   - Batched at 10Hz (not every frame)
   - Separated to _physics_process
   - Skips unpopulated biomes
   - Timing instrumentation shows ~0.05-0.21ms when empty

2. **Rendering has instrumentation but incomplete**:
   - Farm._process() logs exist
   - QuantumForceGraph._draw() has timer but no print
   - **Need to enable full timing to identify bottleneck**

3. **Something else is consuming time**:
   - Empty grid: 36 FPS (should be 60+)
   - Full grid: 6 FPS (should be 50+)
   - Suggests issue beyond quantum + rendering

### Recommendation

**User's hypothesis is correct** - quantum evolution is already optimized in _physics_process.

**Real bottleneck is likely in _process()**:
- FarmGrid plot processing
- QuantumForceGraph rendering layers
- UI updates
- Hidden subsystems not yet profiled

**Next action**: Add the missing performance logs above and run a 30-second test with:
1. 10 seconds empty grid
2. Plant all plots
3. 20 seconds full grid measurement

This will show exactly where the time is going.

---

## Files with Performance Instrumentation

- ✅ `Core/Farm.gd:623-624` - Farm._process() timing (ACTIVE)
- ✅ `Core/Environment/BiomeEvolutionBatcher.gd:111-116` - Quantum evolution timing (ACTIVE)
- ❌ `Core/Visualization/QuantumForceGraph.gd:194` - Rendering timing (MISSING LOG)
- ❌ `Core/GameMechanics/FarmGrid.gd` - Grid processing (NO INSTRUMENTATION)
- ❌ Bubble renderers - Individual layer timing (NO INSTRUMENTATION)
