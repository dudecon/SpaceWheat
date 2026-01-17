# Complete QER (EXPLORE/MEASURE/POP) Architecture Analysis

**Date:** 2026-01-16
**Status:** Comprehensive Audit Complete
**Scope:** All overlapping information systems, signal pathways, and desynchronization risks

---

## EXECUTIVE SUMMARY

The QER system is a **catastrophic example of architectural decay**. There are **EIGHT** independent overlapping information systems tracking the same state:

1. **Three binding trackers** (Terminal.is_bound, PlotPool.binding_table, BiomeBase._bound_registers)
2. **Four emoji sources** (Terminal.{north/south}_emoji, FarmPlot.{north/south}_emoji, QuantumNode.emoji_{north/south}, BiomeBase.register_map)
3. **Three measurement state stores** (Terminal.is_measured, FarmPlot.has_been_measured, QuantumNode rendering)
4. **Five bubble lookup dictionaries** (quantum_nodes[], node_by_plot_id, quantum_nodes_by_grid_pos, basis_bubbles, emoji_to_bubble)
5. **Dual position coordinate systems** (grid_position: Vector2i, QuantumNode.position: Vector2 with physics)
6. **Two incompatible emoji architectures** (v1 plot-based, v2 terminal-based)

**No single source of truth exists.** Each system independently tracks state, creating exponential desynchronization pathways.

---

## PART 1: ACTUAL USER EXPERIENCE (WHY IT APPEARS BROKEN)

### Scenario: User selects 3 plots, presses Q, E, R

#### STEP 1: USER PRESSES Q (EXPLORE) WITH 3 SELECTED PLOTS

**Expected behavior:** 3 bubbles appear, one per plot, showing emoji pairs

**Actual behavior:** 3 dots appear (no emojis visible)

**Why:** Terminal bubbles were marked with `is_terminal_bubble = true` to prevent opacity reset, but **TWO different code paths still attempted to update them:**

1. **Code path A** (QuantumForceGraph._initialize() line 749):
   ```gdscript
   if not node.is_terminal_bubble:
       _update_node_visual_batched(node, purity_cache)  ← SKIPPED (good)
   ```

2. **Code path B** (QuantumForceGraph._draw_quantum_bubbles() line 2611):
   ```gdscript
   if node.plot and not node.is_terminal_bubble:
       node.update_from_quantum_state()  ← SKIPPED (good)
   ```

Both paths were fixed in commit 14925b8. However, the **core issue remains: Terminal bubbles inherit from QuantumNode which has plot references, causing semantic confusion.**

#### STEP 2: USER PRESSES E (MEASURE) WITH 3 TERMINALS BOUND

**Expected behavior (user assumption):** All 3 terminals collapse; 3 cyan glows appear

**Actual behavior:** Only 1 terminal measures; only 1 cyan glow appears

**Why this is by design, not a bug:**

```gdscript
// FarmInputHandler._action_measure() line 1445
func _action_measure(positions: Array[Vector2i]):
    var target_pos = positions[0]  ← USES ONLY FIRST POSITION
    var biome = farm.grid.get_biome_for_plot(target_pos)
    var terminal = _find_active_terminal_in_biome(biome)  ← RETURNS FIRST MATCH ONLY
    # Measures only this one terminal, then returns
```

**Design intent:** Single-action measurement (one E press = one terminal measured)

**Result:** Terminals 2 and 3 remain bound but unmeasured; **no signal fires for them; no visualization update**

#### STEP 3: USER PRESSES R (POP)

**Expected behavior:** Measured terminal is harvested; bubble disappears

**Actual behavior:** One bubble disappears (the measured one); two unmeasured bubbles remain

**Why:** Working as designed. POP also operates on single-terminal basis.

---

## PART 2: INFORMATION FLOW DIAGRAMS

### THE THREE INDEPENDENT BINDING TRACKERS

```
EXPLORE (Binding Creation):
════════════════════════════

ProbeActions.action_explore(biome, plot_pool)
    │
    ├─ 1️⃣ TERMINAL-LEVEL:
    │   plot_pool.bind_terminal(terminal, register, biome, emoji)
    │   └─ terminal.bind_to_register(register_id, biome, emoji_north, emoji_south)
    │      └─ Terminal.is_bound = true  ← SOURCE 1
    │      └─ Terminal.bound_register_id = register_id
    │      └─ Terminal.north_emoji = emoji_north
    │      └─ Terminal.south_emoji = emoji_south
    │
    ├─ 2️⃣ PLOTPOOL-LEVEL:
    │   plot_pool.bind_terminal() continues:
    │   └─ PlotPool.binding_table[terminal_id] = {register_id, biome_name}  ← SOURCE 2
    │   └─ PlotPool.reverse_binding["biome:register_id"] = terminal_id
    │
    └─ 3️⃣ BIOME-LEVEL:
        biome.mark_register_bound(register_id, terminal_id)
        └─ BiomeBase._bound_registers[register_id] = terminal_id  ← SOURCE 3

SYNCHRONIZATION POINT: THREE SEPARATE DICTIONARIES
═════════════════════════════════════════════════════

Risk 1: If PlotPool.binding_table succeeds but BiomeBase._bound_registers fails:
        - PlotPool thinks terminal IS bound
        - Biome thinks register is FREE
        - UNIQUE BINDING CONSTRAINT VIOLATED

Risk 2: Terminal.is_bound is updated FIRST, but other trackers updated AFTER
        - Querying "is terminal bound" returns true immediately
        - But PlotPool lookup might fail (eventual consistency issue)
```

### THE FOUR EMOJI SOURCES

```
V1 ARCHITECTURE (Plot-based):
══════════════════════════════

BasePlot.plant(emoji_pair)
    └─ FarmPlot.north_emoji = emoji_pair["north"]
    └─ FarmPlot.south_emoji = emoji_pair["south"]


V2 ARCHITECTURE (Terminal-based):
══════════════════════════════════

ProbeActions.action_explore()
    └─ emoji_pair = biome.get_register_emoji_pair(selected_register)  [SOURCE 1]
    └─ terminal.bind_to_register(..., emoji_north, emoji_south)
       └─ Terminal.north_emoji = emoji_north  [SOURCE 2]
       └─ Terminal.south_emoji = emoji_south


VISUALIZATION LAYER (tries to read both):
═══════════════════════════════════════════

BathQuantumVisualizationController.request_plot_bubble():
    └─ if plot.has_method("get_terminal") and plot.get_terminal():
           north_emoji = terminal.north_emoji  [SOURCE 2]  ← Does FarmPlot have get_terminal()?
       else:
           north_emoji = plot.north_emoji  [SOURCE 1]  ← Fallback to v1

QuantumNode.update_from_quantum_state():
    └─ if plot:
           var emojis = plot.get_plot_emojis()  [Could return either source!]


BIOME REGISTER MAP (independent):
════════════════════════════════

BiomeBase.register_map:
    └─ emoji_pair → qubit_index  [SOURCE 4: RegisterMap object]
    └─ Used by get_register_emoji_pair()
    └─ Updated when allocate_register() is called


DESYNCHRONIZATION SCENARIO:
═══════════════════════════

1. Terminal binds: Terminal.north_emoji = "☀"
2. Plot has: FarmPlot.north_emoji = "🌾"
3. Biome register has: RegisterMap["☀"] = qubit_5

If visualization reads plot instead of terminal:
    - Shows "🌾" but density matrix is tracking "☀"
    - Wrong emoji displayed for wrong quantum state!
    - User sees "🌾" but MEASURE returns "☀"
```

### THE MEASUREMENT STATE TRILEMMA

```
MEASURE (Measurement Recording):
═════════════════════════════════

ProbeActions.action_measure(terminal, biome)
    │
    ├─ 1️⃣ TERMINAL-LEVEL:
    │   terminal.mark_measured(outcome, recorded_probability)
    │   └─ Terminal.is_measured = true  ← SOURCE 1 (immediate)
    │   └─ Terminal.measured_outcome = outcome
    │   └─ Terminal.measured_probability = recorded_probability
    │
    ├─ Emit signals:
    │   terminal.measured.emit(outcome)  ← Local signal
    │   terminal.state_changed.emit(self)
    │   farm.terminal_measured.emit(pos, terminal_id, outcome, prob)  ← Global signal
    │
    └─ No direct update to FarmPlot!


VISUALIZATION LAYER (2 steps):
════════════════════════════════

Step A: FarmInputHandler._action_measure() line 1475:
    └─ farm.terminal_measured.emit(...)

Step B: BathQuantumVisualizationController._on_terminal_measured() line 215:
    └─ bubble.plot.has_been_measured = true  ← SOURCE 2 (happens AFTER signal)
    └─ This is where FarmPlot.has_been_measured gets synchronized!


RENDERING:
══════════

QuantumForceGraph._draw_quantum_bubble() line 2225:
    └─ if node.plot != null and node.plot.has_been_measured:
           └─ is_measured = true  ← SOURCE 3 (rendering-time decision)
    └─ Applies cyan glow effect


DESYNCHRONIZATION RISKS:
═════════════════════════

Risk 1: Signal doesn't fire
    - Terminal.is_measured = true ✓
    - FarmPlot.has_been_measured = false ✗
    - Rendering: if plot == null, cyan glow won't appear

Risk 2: Plot lookup fails
    - bubble.plot = null
    - FarmPlot.has_been_measured stays false
    - No cyan glow rendered

Risk 3: Multiple measurement sources
    - Two separate systems declare "measured" state
    - Physics layer (line 1091-1095) checks Terminal.is_measured
    - Rendering layer (line 2225) checks FarmPlot.has_been_measured
    - Could freeze in physics but glow in rendering (or vice versa)
```

### THE FIVE BUBBLE TRACKING DICTIONARIES

```
MASTER ARRAY:
═════════════
QuantumForceGraph.quantum_nodes: Array[QuantumNode]
    └─ SOURCE OF TRUTH for all bubbles
    └─ Used for physics, rendering, updates


LOOKUP INDEX 1: BY GRID POSITION
══════════════════════════════════
QuantumForceGraph.quantum_nodes_by_grid_pos: Dictionary
    └─ grid_position (Vector2i) → QuantumNode
    └─ Used by:
       - Terminal._action_pop() to find bubble at position
       - QuantumForceGraph physics layer (line 1091) to check if measured
       - BathQuantumVisualizationController to remove bubbles


LOOKUP INDEX 2: BY PLOT ID
════════════════════════════
QuantumForceGraph.node_by_plot_id: Dictionary
    └─ plot_id (String) → QuantumNode
    └─ Used for:
       - Entanglement visualization (finding related bubbles)
       - Reverse plot → node lookup


LOOKUP INDEX 3: BY BIOME & BIOME ARRAY
═════════════════════════════════════════
BathQuantumVisualizationController.basis_bubbles: Dictionary
    └─ biome_name (String) → Array[QuantumNode]
    └─ Used by visualization controller for per-biome updates


LOOKUP INDEX 4: BY EMOJI
═════════════════════════
BathQuantumVisualizationController.emoji_to_bubble: Dictionary
    └─ emoji (String) → QuantumNode
    └─ Created during initialize() and NEVER UPDATED
    └─ QuantumNode.emoji_north changes but emoji_to_bubble[old_emoji] still points to node!


DESYNCHRONIZATION SCENARIO:
═════════════════════════════

1. Terminal bound: grid_pos=(2,3), emoji_north="☀"
2. quantum_nodes_by_grid_pos[(2,3)] = bubble ✓
3. basis_bubbles["BioticFlux"].append(bubble) ✓
4. node_by_plot_id[plot_id] = bubble ✓ (maybe)
5. emoji_to_bubble["☀"] = bubble ✓

6. MEASURE causes MEASURE causes update_from_quantum_state()
7. QuantumNode.emoji_north changes to "🌙"
8. emoji_to_bubble["☀"] STILL points to bubble
9. emoji_to_bubble["🌙"] is undefined
10. Lookup by emoji breaks: emoji_to_bubble[new_emoji] == null

When POP fires terminal_released signal:
11. _on_terminal_released() tries to erase by grid_pos ✓
12. basis_bubbles[biome_name].erase(bubble) ✓
13. But if erase fails silently → basis_bubbles still has bubble
14. quantum_nodes still has bubble
15. If physics update iterates quantum_nodes → dead reference!
```

### THE GRID vs PHYSICS POSITION DIVERGENCE

```
EXPLORATION (EXPLORE action):
═════════════════════════════

FarmInputHandler._action_explore():
    └─ terminal.grid_position = plot_pos  [e.g., (2,3)]

BathQuantumVisualizationController._create_bubble_for_terminal():
    └─ bubble = QuantumNode.new(..., grid_pos, ...)
    └─ bubble.grid_position = grid_pos  [e.g., (2,3)]
    └─ bubble.position = initial_pos  [random scatter around biome oval]
    └─ bubble.classical_anchor = stored_center [screen center position]
    └─ INITIAL STATE: grid_position == integer position, position == float screen position


PHYSICS SIMULATION (every frame):
═════════════════════════════════

QuantumForceGraph._update_nodes_physics():
    └─ for node in quantum_nodes:
           node.position += forces * delta
           └─ DRIFTS: node.position += repulsion, tether, semantic coupling
           └─ node.grid_position UNCHANGED

Result: node.position can drift to (543.2, 812.7) while grid_position stays (2,3)


MEASURED STATE (MEASURE action):
════════════════════════════════

QuantumForceGraph._update_nodes_physics() line 1098-1100:
    └─ if is_measured:
           node.position = node.classical_anchor
           node.velocity = Vector2.ZERO
    └─ FREEZES position at classical_anchor (screen position)
    └─ classical_anchor may NOT equal initial_pos (could have drifted!)
    └─ node.grid_position still (2,3)


INDEXING ISSUE:
═══════════════

QuantumForceGraph.quantum_nodes_by_grid_pos[(2,3)] = bubble

But bubble.position is NOT (2,3) anymore!
    - Classical grid: (2,3)
    - Physics position: (543.2, 812.7) or (classical_anchor_x, classical_anchor_y)
    - These are in DIFFERENT COORDINATE SYSTEMS!

When terminal is popped:
    grid_pos = (2,3)
    quantum_nodes_by_grid_pos.erase((2,3))  ← Works ✓
    bubble.position still at drift location  ← Orphaned!


CRITICAL BUG SCENARIO:
══════════════════════

If bubble.position is at screen (543, 812) but we look up by grid_pos (2,3):
    - Grid lookup finds bubble ✓
    - Physics lookup by position fails ✗
    - Bubble might be rendered at wrong location or doubly updated
```

---

## PART 3: ROOT CAUSES OF THE MESS

### Cause 1: Two Incompatible Architectural Paradigms

**V1 (Plot-centric):**
- FarmPlot owns quantum state (emoji pair, is_planted flag)
- Visualization reads from plot
- State mutation: plot.plant(), plot.measure(), plot.harvest()

**V2 (Terminal-centric):**
- Terminal owns lifecycle (is_bound, is_measured, grid_position)
- Biome owns quantum registers
- Visualization reads from terminal binding info

**Current state:** Both systems coexist. Code has to handle both paths:

```gdscript
if plot.has_method("get_terminal") and plot.get_terminal():
    // V2: Use terminal
    terminal = plot.get_terminal()
    emoji = terminal.north_emoji
else:
    // V1: Use plot
    emoji = plot.north_emoji
```

**Problem:** FarmPlot never actually implements `get_terminal()`. The fallback ALWAYS triggers, meaning V1 path is always used for emoji lookup, **but V2 is used for binding logic.**

### Cause 2: Signal Layer Synchronizes State

Plot measurement state (`FarmPlot.has_been_measured`) should be authoritative in V1, but is actually set by the **visualization layer via signal handling**:

```gdscript
// BathQuantumVisualizationController._on_terminal_measured()
bubble.plot.has_been_measured = true  ← Visualization mutates game state!
```

This violates MVC pattern: **View layer should not mutate Model state.**

### Cause 3: Three Independent Binding Dictionaries

Instead of one source of truth, there are three:

| System | Dict | Updated By | Checked By |
|--------|------|-----------|-----------|
| Terminal | is_bound property | bind_to_register() | can_pop(), can_measure() |
| PlotPool | binding_table | bind_terminal() | reverse lookups |
| BiomeBase | _bound_registers | mark_register_bound() | get_bound_registers() |

None of them is officially "the authority." Each is independently maintained.

### Cause 4: External Orchestration Without Atomicity

```gdscript
// ProbeActions.action_pop()
var result = ProbeActions.action_pop(terminal, farm.plot_pool, farm.economy)
    └─ biome.mark_register_unbound(register_id)  [Step 1]
    └─ plot_pool.unbind_terminal(terminal)  [Step 2]
```

Both steps are called externally from ProbeActions. If Step 1 fails but Step 2 succeeds:
- BiomeBase._bound_registers still has register marked as bound
- PlotPool.binding_table has it marked as unbound
- **DESYNCHRONIZED**

No rollback mechanism. No transaction support.

### Cause 5: Dual Coordinate Systems

Visualization uses two coordinates simultaneously:
- **Grid coordinates** (discrete): (2,3) — the logical position in FarmGrid
- **Physics coordinates** (continuous): (543.2, 812.7) — the rendered position with forces

These are treated as equivalent but diverge due to force-directed layout.

---

## PART 4: WHY THE USER SEES "BROKEN" BEHAVIOR

### Issue 1: Three dots instead of emojis
**Root cause:** Terminal bubbles inherit emoji data from Terminal, but QuantumNode tries to read from unplanted FarmPlot, resetting opacities to 0.

**Fixed in commit 14925b8** by adding `is_terminal_bubble` flag, but only a band-aid.

### Issue 2: Only 1 terminal measures when E is pressed
**Root cause:** By design. `_action_measure()` finds `_find_active_terminal_in_biome()` which returns first match only.

**User expectation:** All selected terminals measure.

**Design reality:** Single-action measurement model (E = measure one).

### Issue 3: Remaining dots don't disappear
**Root cause:** POP only removes measured terminals. Unmeasured terminals are unaffected.

**This is correct behavior** given the design, but user expected all to be consumable in one sequence.

---

## PART 5: ALL SIGNAL PATHWAYS

### EXPLORE Signal Chain
```
PlotPool.bind_terminal()
    ├─ Terminal.bind_to_register()
    │  ├─ Terminal.bound.emit()
    │  └─ Terminal.state_changed.emit()
    │
    └─ PlotPool.terminal_bound.emit(terminal, register_id)
       └─ BathQuantumVisualizationController._on_terminal_bound()
          └─ _create_bubble_for_terminal()
             └─ graph.quantum_nodes.append(bubble)
```

### MEASURE Signal Chain
```
ProbeActions.action_measure()
    └─ Terminal.mark_measured()
       ├─ Terminal.measured.emit()
       └─ Terminal.state_changed.emit()

FarmInputHandler._action_measure()
    └─ farm.terminal_measured.emit(pos, id, outcome, prob)
       └─ BathQuantumVisualizationController._on_terminal_measured()
          └─ bubble.plot.has_been_measured = true  ← STATE MUTATION IN VIEW
```

### POP Signal Chain
```
ProbeActions.action_pop()
    └─ PlotPool.unbind_terminal()
       └─ PlotPool.terminal_unbound.emit(terminal)
          └─ BathQuantumVisualizationController._on_terminal_released()
             ├─ graph.quantum_nodes_by_grid_pos.erase(position)
             ├─ graph.quantum_nodes.erase(bubble)
             └─ basis_bubbles[biome_name].erase(bubble)
```

---

## PART 6: COMPLETE DESYNCHRONIZATION CATALOG

### Possible Divergence Points (8 Critical Issues)

1. **Binding table mismatch**
   - Terminal.is_bound ≠ PlotPool.binding_table[terminal_id] exists
   - Terminal.is_bound ≠ BiomeBase._bound_registers[register_id] exists

2. **Emoji source mismatch**
   - Terminal.north_emoji ≠ FarmPlot.north_emoji
   - FarmPlot emoji ≠ Biome.register_map emoji
   - QuantumNode.emoji_north ≠ all three sources

3. **Measurement state mismatch**
   - Terminal.is_measured ≠ FarmPlot.has_been_measured
   - Physics layer sees Terminal.is_measured but rendering layer sees FarmPlot.has_been_measured

4. **Position coordinate mismatch**
   - Terminal.grid_position = (2,3) but QuantumNode.position = (543.2, 812.7)
   - Lookup by grid fails if using physics position

5. **Bubble tracking divergence**
   - quantum_nodes has bubble but quantum_nodes_by_grid_pos doesn't
   - emoji_to_bubble points to old emoji name
   - basis_bubbles has orphaned reference

6. **Terminal-to-plot binding**
   - Terminal knows grid_position but no reverse lookup from plot
   - Signal handler has to find plot by grid position (inefficient)

7. **Register ownership conflict**
   - PlotPool says register is unbound
   - Biome says register is still bound
   - Unique constraint violated

8. **External orchestration failure**
   - mark_register_unbound() succeeds but unbind_terminal() fails
   - Partial state update leaves system inconsistent

---

## CONCLUSION

The QER system represents **architectural collapse through accumulation of workarounds**:

- **Original design (V1):** Plot-centric, straightforward
- **Refactored design (V2):** Terminal-centric, more powerful
- **Current reality:** Both coexist without clean boundaries
- **Result:** Eight independent information systems tracking same state with no central authority

The system works *most of the time* because ProbeActions happens to call things in the right order, and signal handlers happen to fire. But it is **fragile, non-deterministic, and impossible to reason about.**

**Every single issue in this document is a latent bug waiting to happen.**
