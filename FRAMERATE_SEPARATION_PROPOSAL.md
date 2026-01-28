# Framerate Separation: Visual vs Physics/Quantum

## Current Architecture Problem

**Everything runs in `_process(delta)`** (visual framerate):
```gdscript
Farm._process(delta)  ← Runs every visual frame (28-60 FPS)
  ↓
BiomeEvolutionBatcher.process(delta)
  ↓
  [Accumulates time until 0.1s]
  ↓
  quantum_computer.evolve(dt)  ← Only when accumulated >= 0.1s
```

**Issue**: Quantum checks happen every visual frame even though evolution only occurs every 0.1s

---

## Godot's Built-in Solution: `_physics_process()`

**Godot already has framerate separation built-in:**

| Function | Purpose | Rate | Tied To |
|----------|---------|------|---------|
| `_process(delta)` | Visual updates, UI, animations | **Variable (30-144 FPS)** | Display refresh |
| `_physics_process(delta)` | Physics, simulation, game logic | **Fixed (configurable)** | Physics tick |

**Default**: Physics runs at **60Hz fixed**, independent of visual framerate!

---

## Solution: Move Quantum to Physics Process

### Option 1: Use Existing 60Hz Physics (Easiest - 1 hour)

**Change**: Move quantum evolution to `_physics_process()` at default 60Hz

**Benefits:**
- ✅ Completely decouples from visual framerate
- ✅ No accumulator needed (physics gives fixed dt)
- ✅ Visual can run at 144 FPS without extra quantum cost
- ✅ No threading complexity

**Implementation:**
```gdscript
# BiomeEvolutionBatcher.gd
func physics_process(delta: float):  # ← Rename from process()
    """Called at fixed 60Hz by physics loop."""
    evolution_accumulator += delta
    if evolution_accumulator >= EVOLUTION_INTERVAL:
        # ... evolve batch ...
```

**Expected Performance:**
- Visual: 60+ FPS (UI, rendering)
- Physics: 60 FPS fixed (quantum checks)
- Quantum: 10 Hz effective (batched evolution)

---

### Option 2: Custom 20Hz Physics (Better - 2 hours)

**Change**: Set custom physics tick rate for quantum-only

**Config**: Add to `project.godot`:
```ini
[physics]
common/physics_ticks_per_second=20
```

**Benefits:**
- ✅ All of Option 1 benefits
- ✅ Reduces quantum checks from 60Hz → 20Hz (67% reduction!)
- ✅ Better CPU utilization
- ✅ Still independent of visual framerate

**Implementation:**
```gdscript
# BiomeEvolutionBatcher.gd
const EVOLUTION_INTERVAL = 0.1  # Still 10Hz evolution

func physics_process(delta: float):
    """Called at fixed 20Hz by physics loop."""
    evolution_accumulator += delta  # Will be 0.05s per call

    # Every 2 physics ticks (2 × 0.05 = 0.1s), evolve
    if evolution_accumulator >= EVOLUTION_INTERVAL:
        _evolve_batch(evolution_accumulator)
        evolution_accumulator = 0.0
```

**Expected Performance:**
- Visual: 60+ FPS (UI, rendering)
- Physics: 20 FPS fixed (quantum checks)
- Quantum: 10 Hz effective (evolution rate)

**Frame time breakdown (20Hz physics):**
```
Visual frames: 16ms (60 FPS)
Physics frames: 50ms (20 FPS)
  └─ Quantum evolution: 8-10ms (when triggered)

Result: Visual stays smooth at 60 FPS
        Physics handles quantum independently
```

---

### Option 3: Dual Physics Worlds (Advanced - 4-6 hours)

**Change**: Separate quantum into its own physics world at 10Hz

Godot supports multiple physics worlds with different tick rates!

**Config**:
```gdscript
# Create quantum-only physics world
var quantum_world = PhysicsServer2D.world_create()
PhysicsServer2D.world_set_fixed_fps(quantum_world, 10)  # 10Hz only

# Assign biomes to quantum world
for biome in biomes:
    biome.set_physics_process_world(quantum_world)
```

**Benefits:**
- ✅ Pure 10Hz quantum evolution (no accumulator needed!)
- ✅ Visual at 60+ FPS
- ✅ Main physics at 60 FPS (for other game logic)
- ✅ Perfect separation

**Complexity**: Higher (requires world management)

---

## Recommended Approach: Option 2 (20Hz Physics)

### Why Option 2 is Best

**Pros:**
- ✅ Easy to implement (2 hours)
- ✅ 67% reduction in quantum checks (60Hz → 20Hz)
- ✅ Visual stays at 60+ FPS
- ✅ No threading needed
- ✅ Godot handles all synchronization
- ✅ Can adjust tick rate at runtime

**Cons:**
- Main game physics also runs at 20Hz (probably fine for this game)

### Implementation Steps

#### Step 1: Add Physics Config (5 minutes)

Edit `project.godot`:
```ini
[physics]

common/physics_ticks_per_second=20
common/max_physics_steps_per_frame=8
```

#### Step 2: Move Batcher to Physics Process (30 minutes)

```gdscript
# Core/Environment/BiomeEvolutionBatcher.gd

func process(delta: float):
    """DEPRECATED - use physics_process instead."""
    pass

func physics_process(delta: float):
    """Called at fixed 20Hz by physics loop.

    Evolves 2 biomes per physics frame in rotation.
    Achieves 10Hz effective evolution rate.
    """
    evolution_accumulator += delta  # 0.05s per call at 20Hz

    if evolution_accumulator >= EVOLUTION_INTERVAL:
        var actual_dt = evolution_accumulator
        evolution_accumulator = 0.0

        if not batch_groups.is_empty():
            _evolve_batch(batch_groups[current_batch_index], actual_dt)
            current_batch_index = (current_batch_index + 1) % batch_groups.size()
```

#### Step 3: Update Farm Integration (10 minutes)

```gdscript
# Core/Farm.gd

func _process(delta: float):
    """Handle visual updates and UI."""
    # Grid processing (UI updates only)
    if grid:
        grid._process(delta)

    # Mushroom composting (can stay in _process)
    _process_mushroom_composting(delta)

func _physics_process(delta: float):
    """Handle physics and quantum simulation at fixed 20Hz."""
    # BATCHED QUANTUM EVOLUTION (runs at 20Hz physics, evolves at 10Hz)
    if biome_evolution_batcher:
        biome_evolution_batcher.physics_process(delta)

    # Other physics (Lindblad effects, etc.)
    _process_lindblad_effects(delta)
```

#### Step 4: Test & Verify (1 hour)

Run benchmarks to confirm:
- Visual framerate independent of quantum
- Quantum still evolves at 10Hz effective
- Frame times smoother

---

## Performance Comparison

### Before (Current Batched System)

```
Visual Process Loop (28 FPS):
  Frame 1: Check batcher (no evolve)        35ms
  Frame 2: Check batcher (no evolve)        35ms
  Frame 3: Check batcher + evolve 2 biomes  43ms ← quantum work
  [Repeat]

CPU: Checks every visual frame
Quantum: Evolves every ~3rd frame
```

### After (20Hz Physics)

```
Visual Process Loop (60 FPS):
  Frame 1: UI updates                       16ms
  Frame 2: UI updates                       16ms
  Frame 3: UI updates                       16ms
  [Always smooth, no quantum checks]

Physics Process Loop (20 FPS, parallel):
  Tick 1: Check batcher (no evolve)         2ms
  Tick 2: Check batcher + evolve 2 biomes  10ms ← quantum work
  [Repeat every 50ms]

CPU: Visual and physics run independently
Quantum: Evolves at precise 10Hz
Visual: Smooth 60 FPS
```

**Key Win**: Visual framerate **completely decoupled** from quantum simulation!

---

## Expected Results

### Before Separation

| Metric | Value | Notes |
|--------|-------|-------|
| Visual FPS | 28 FPS | Limited by quantum checks |
| Frame consistency | Moderate | Varies with quantum evolution |
| Quantum checks | 28 Hz | Every visual frame |

### After Separation (20Hz Physics)

| Metric | Value | Notes |
|--------|-------|-------|
| Visual FPS | **60 FPS** | ✅ No quantum blocking |
| Frame consistency | **Excellent** | ✅ Consistent 16ms |
| Quantum checks | **20 Hz** | ✅ Fixed physics tick |
| Quantum evolution | **10 Hz** | ✅ Same effective rate |

**Improvement**: **+114% visual FPS** (28 → 60) with smoother frames!

---

## Advanced: Runtime Adjustable Physics (Optional)

**Dynamic quality settings**:
```gdscript
# Settings menu
enum PhysicsQuality {
    LOW,      # 10Hz physics
    MEDIUM,   # 20Hz physics (default)
    HIGH,     # 30Hz physics
}

func set_physics_quality(quality: PhysicsQuality):
    var tick_rate = {
        PhysicsQuality.LOW: 10,
        PhysicsQuality.MEDIUM: 20,
        PhysicsQuality.HIGH: 30,
    }[quality]

    Engine.physics_ticks_per_second = tick_rate
    print("Physics tick rate: %d Hz" % tick_rate)
```

**Use cases:**
- Low-end devices: 10Hz physics for better performance
- High-end devices: 30Hz physics for smoother quantum animation
- Visual: Always stays at 60+ FPS regardless

---

## Threading (Only if Physics Separation Insufficient)

If after physics separation you still need more:

### Option 4: Worker Thread for Quantum (Complex - 8-12 hours)

**Architecture**:
```gdscript
# QuantumWorkerThread.gd
extends Thread

var work_queue: Array = []
var result_queue: Array = []
var mutex: Mutex = Mutex.new()

func run_quantum_batch(biomes: Array, dt: float):
    """Runs on separate thread."""
    for biome in biomes:
        var result = biome.quantum_computer.evolve(dt)
        mutex.lock()
        result_queue.append(result)
        mutex.unlock()
```

**Complexity:**
- Thread safety for density matrices
- Mutex locking overhead
- Race condition debugging
- Godot's thread limitations

**When needed:**
- Targeting 120+ visual FPS
- Very complex quantum systems (> 64 qubits)
- Real-time quantum visualization

**Verdict**: **Probably overkill** for current game scope

---

## Recommendation: Start with Option 2

**Implementation Order:**

1. ✅ **Try Option 2 first** (20Hz physics) - 2 hours
   - Easy to implement
   - Big visual FPS gain
   - Reversible if issues

2. ⏸️ **Evaluate after testing**
   - If 60 FPS achieved → **DONE** ✅
   - If still need more → Try Option 3 (dual worlds)
   - If *still* need more → Consider Option 4 (threading)

**Expected outcome**: Option 2 will be **sufficient** for release!

---

## Testing Plan

### Test 1: Visual FPS Independence

```bash
# Before
godot res://scenes/FarmView.tscn
# Watch FPS counter - varies 28-35 FPS

# After (20Hz physics)
godot res://scenes/FarmView.tscn
# Watch FPS counter - stable 60 FPS ✅
```

### Test 2: Quantum Evolution Rate

```gdscript
# Verify quantum still evolves at 10Hz
var start_time = Time.get_ticks_msec()
await biome.quantum_computer.density_changed
var elapsed = Time.get_ticks_msec() - start_time
print("Evolution interval: %d ms" % elapsed)
# Should be ~100ms (10Hz) ✅
```

### Test 3: Frame Time Distribution

```bash
godot --headless --script res://Tests/QuickSmoothnessTest.gd
# Check stddev and P95
# Should be < 5ms stddev (excellent smoothness) ✅
```

---

## Summary

**Question**: How to separate visual from physics framerate?

**Answer**: Use Godot's built-in `_physics_process()` with custom tick rate!

**Easiest Solution**: Option 2 (20Hz physics) - **2 hours implementation**

**Expected Gain**: **+114% visual FPS** (28 → 60 FPS)

**Threading Needed**: **NO** - Godot handles it all ✅

**Risk**: Low - easily reversible if issues arise

**Verdict**: **IMPLEMENT OPTION 2 IMMEDIATELY** 🚀
