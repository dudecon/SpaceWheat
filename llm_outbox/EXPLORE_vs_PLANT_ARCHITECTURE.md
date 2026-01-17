# EXPLORE vs PLANT - Clean Separation Architecture

**Date:** 2026-01-17
**Status:** Proposed Solution
**Goal:** Untangle two fundamentally different actions at tool, signal, and visual layers

---

## Conceptual Foundation

### EXPLORE (Quantum Discovery)
```
┌─────────────────────────────────────────────────────────────────┐
│  EXPLORE = "Look into the quantum soup"                         │
│                                                                 │
│  • Binds a TERMINAL to an existing REGISTER in the biome        │
│  • Does NOT create anything new in the quantum system           │
│  • Terminal becomes a "window" into the register's state        │
│  • Emoji pair comes FROM the register (already exists)          │
│  • No resource cost - you're just observing                     │
│  • Reversible via POP (terminal returns to pool)                │
└─────────────────────────────────────────────────────────────────┘
```

### PLANT (Biome Expansion)
```
┌─────────────────────────────────────────────────────────────────┐
│  PLANT = "Expand the quantum system"                            │
│                                                                 │
│  • Creates NEW quantum axes/registers in the biome              │
│  • Adds physical structure (mill, market, kitchen, crop)        │
│  • Emoji pair is DEFINED by the plant (you choose it)           │
│  • Costs resources (wheat, flour, etc.)                         │
│  • Permanent - structure persists until demolished              │
│  • Expands the Hilbert space (more qubits = more states)        │
└─────────────────────────────────────────────────────────────────┘
```

### Key Distinction
```
EXPLORE: Terminal → binds to → existing Register → reads emoji pair
PLANT:   Resources → creates → new Register → defines emoji pair
```

---

## Layer 1: Tool Definitions

### EXPLORE (Tool 1 - PROBE, PLAY mode)

**Location:** `Core/GameState/ToolConfig.gd`

```gdscript
# Tool 1: PROBE - Quantum observation tools
{
    "name": "PROBE",
    "color": Color(0.4, 0.8, 1.0),  # Cyan - observation
    "actions": [
        {
            "action": "explore",
            "label": "Explore",
            "emoji": "🔍",
            "key": "Q",
            "description": "Bind terminal to quantum register"
        },
        {
            "action": "measure",
            "label": "Measure",
            "emoji": "📏",
            "key": "E",
            "description": "Collapse state via Born rule"
        },
        {
            "action": "pop",
            "label": "Pop",
            "emoji": "💰",
            "key": "R",
            "description": "Harvest credits, release terminal"
        }
    ]
}
```

### PLANT (BUILD mode tools)

**Location:** `Core/GameState/ToolConfig.gd`

```gdscript
# Build Tool: STRUCTURE - Infrastructure creation
{
    "name": "STRUCTURE",
    "color": Color(0.9, 0.6, 0.2),  # Orange - construction
    "actions": [
        {
            "action": "plant_crop",
            "label": "Plant",
            "emoji": "🌱",
            "key": "Q",
            "description": "Plant crop (adds quantum axis)"
        },
        {
            "action": "build_mill",
            "label": "Mill",
            "emoji": "🏭",
            "key": "E",
            "description": "Build flour mill (30🌾)"
        },
        {
            "action": "build_market",
            "label": "Market",
            "emoji": "🏪",
            "key": "R",
            "description": "Build trading post (30🌾)"
        },
        {
            "action": "build_kitchen",
            "label": "Kitchen",
            "emoji": "🍳",
            "key": "T",
            "description": "Build kitchen (30🌾 + 10💨)"
        }
    ]
}
```

---

## Layer 2: Signal Definitions

### New Signal Architecture

**Location:** `Core/Farm.gd`

```gdscript
# ═══════════════════════════════════════════════════════════════════
# TERMINAL LIFECYCLE SIGNALS (EXPLORE/MEASURE/POP)
# ═══════════════════════════════════════════════════════════════════

## Emitted when EXPLORE binds a terminal to a quantum register
## This is the trigger for bubble visualization
signal terminal_bound(grid_position: Vector2i, terminal_id: String, emoji_pair: Dictionary)

## Emitted when MEASURE collapses the terminal's quantum state
## Updates bubble to show measurement outcome
signal terminal_measured(grid_position: Vector2i, terminal_id: String, outcome: String, probability: float)

## Emitted when POP releases the terminal back to pool
## Removes bubble from visualization
signal terminal_released(grid_position: Vector2i, terminal_id: String, credits_earned: int)

# ═══════════════════════════════════════════════════════════════════
# STRUCTURE LIFECYCLE SIGNALS (BUILD/DEMOLISH)
# ═══════════════════════════════════════════════════════════════════

## Emitted when PLANT creates a new structure
## Updates grid visualization, expands biome if needed
signal structure_built(grid_position: Vector2i, structure_type: String, emoji_pair: Dictionary)

## Emitted when structure is demolished
signal structure_demolished(grid_position: Vector2i, structure_type: String)

## Emitted when biome quantum system expands (new axis added)
signal biome_expanded(biome_name: String, qubit_index: int, emoji_pair: Dictionary)

# ═══════════════════════════════════════════════════════════════════
# DEPRECATED SIGNALS (remove after migration)
# ═══════════════════════════════════════════════════════════════════

## @deprecated Use terminal_bound or structure_built instead
signal plot_planted(position: Vector2i, plant_type: String)

## @deprecated Use terminal_measured instead
signal plot_measured(position: Vector2i, outcome: String)

## @deprecated Use terminal_released instead
signal plot_harvested(position: Vector2i, yield_data: Dictionary)
```

### Signal Flow Diagrams

#### EXPLORE Flow
```
User presses Q (Explore)
        │
        ▼
FarmInputHandler._action_explore()
        │
        ▼
ProbeActions.action_explore(plot_pool, biome)
        │
        ├── Gets unbound terminal from pool
        ├── Gets available registers from biome
        ├── Binds terminal to weighted-random register
        │
        ▼
FarmInputHandler emits:
farm.terminal_bound.emit(grid_pos, terminal.id, {
    "north": terminal.emoji_north,
    "south": terminal.emoji_south
})
        │
        ▼
BathQuantumVisualizationController receives terminal_bound
        │
        ▼
Creates bubble at grid_pos showing emoji_pair
```

#### MEASURE Flow
```
User presses E (Measure)
        │
        ▼
FarmInputHandler._action_measure()
        │
        ▼
ProbeActions.action_measure(terminal, biome)
        │
        ├── Born rule sampling
        ├── Records probability claim
        ├── Drains ρ by drain factor
        │
        ▼
FarmInputHandler emits:
farm.terminal_measured.emit(grid_pos, terminal.id, outcome, probability)
        │
        ▼
BathQuantumVisualizationController receives terminal_measured
        │
        ▼
Updates bubble: shows outcome emoji, measured glow effect
```

#### POP Flow
```
User presses R (Pop)
        │
        ▼
FarmInputHandler._action_pop()
        │
        ▼
ProbeActions.action_pop(terminal, plot_pool, economy)
        │
        ├── Converts probability to credits
        ├── Releases register in biome
        ├── Returns terminal to pool
        │
        ▼
FarmInputHandler emits:
farm.terminal_released.emit(grid_pos, terminal.id, credits_earned)
        │
        ▼
BathQuantumVisualizationController receives terminal_released
        │
        ▼
Removes bubble (fade out animation)
```

#### PLANT Flow (BUILD mode)
```
User in BUILD mode selects plot and structure
        │
        ▼
FarmInputHandler._action_build(structure_type)
        │
        ▼
Farm.build(position, structure_type)
        │
        ├── Checks resource cost
        ├── Deducts resources
        │
        ▼
FarmGrid.place_*(position)
        │
        ├── Creates structure node
        ├── If new emoji pair needed:
        │   └── biome.expand_quantum_system(north, south)
        │       └── emit farm.biome_expanded(biome_name, qubit_idx, emoji_pair)
        │
        ▼
FarmGrid emits:
farm.structure_built.emit(grid_pos, structure_type, emoji_pair)
        │
        ▼
PlotGridDisplay receives structure_built
        │
        ▼
Updates plot tile to show structure icon
```

---

## Layer 3: Visual Implementation

### Bubble Visualization (Terminal-based)

**Location:** `Core/Visualization/BathQuantumVisualizationController.gd`

```gdscript
## Terminal-based bubble visualization
## Bubbles represent bound terminals, NOT planted crops

func _ready():
    # Connect to terminal lifecycle signals (NOT plot_planted!)
    if farm.has_signal("terminal_bound"):
        farm.terminal_bound.connect(_on_terminal_bound)
    if farm.has_signal("terminal_measured"):
        farm.terminal_measured.connect(_on_terminal_measured)
    if farm.has_signal("terminal_released"):
        farm.terminal_released.connect(_on_terminal_released)


func _on_terminal_bound(grid_pos: Vector2i, terminal_id: String, emoji_pair: Dictionary):
    """Create bubble when terminal binds to register"""
    print("🔍 Terminal %s bound at %s with %s/%s" % [
        terminal_id, grid_pos, emoji_pair.north, emoji_pair.south
    ])

    # Create bubble node
    var bubble = _create_bubble_for_terminal(grid_pos, terminal_id, emoji_pair)

    # Start spawn animation
    bubble.start_spawn_animation(Time.get_ticks_msec() / 1000.0)

    # Track by terminal ID (not grid position - multiple terminals can exist)
    _bubbles_by_terminal[terminal_id] = bubble


func _on_terminal_measured(grid_pos: Vector2i, terminal_id: String, outcome: String, probability: float):
    """Update bubble when terminal is measured"""
    print("📏 Terminal %s measured: %s (p=%.3f)" % [terminal_id, outcome, probability])

    var bubble = _bubbles_by_terminal.get(terminal_id)
    if bubble:
        bubble.set_measured_state(outcome, probability)
        # Apply pulsing cyan glow to indicate "ready to harvest"


func _on_terminal_released(grid_pos: Vector2i, terminal_id: String, credits_earned: int):
    """Remove bubble when terminal is released"""
    print("💰 Terminal %s released: +%d credits" % [terminal_id, credits_earned])

    var bubble = _bubbles_by_terminal.get(terminal_id)
    if bubble:
        # Play harvest animation
        bubble.play_harvest_animation(credits_earned)
        # After animation, remove bubble
        await bubble.animation_finished
        bubble.queue_free()
        _bubbles_by_terminal.erase(terminal_id)
```

### Structure Visualization (Plot-based)

**Location:** `UI/PlotGridDisplay.gd`

```gdscript
## Structure visualization for built items
## Shows icons on plots for mills, markets, kitchens, crops

func _ready():
    # Connect to structure lifecycle signals
    if farm.has_signal("structure_built"):
        farm.structure_built.connect(_on_structure_built)
    if farm.has_signal("structure_demolished"):
        farm.structure_demolished.connect(_on_structure_demolished)


func _on_structure_built(grid_pos: Vector2i, structure_type: String, emoji_pair: Dictionary):
    """Update plot tile when structure is built"""
    print("🏗️ Structure built at %s: %s (%s/%s)" % [
        grid_pos, structure_type, emoji_pair.north, emoji_pair.south
    ])

    var plot_tile = _get_plot_tile(grid_pos)
    if plot_tile:
        plot_tile.set_structure(structure_type, emoji_pair)
        plot_tile.play_build_animation()


func _on_structure_demolished(grid_pos: Vector2i, structure_type: String):
    """Clear plot tile when structure is demolished"""
    var plot_tile = _get_plot_tile(grid_pos)
    if plot_tile:
        plot_tile.clear_structure()
        plot_tile.play_demolish_animation()
```

---

## Implementation Checklist

### Phase 1: Signal Infrastructure
```
[ ] Add terminal_bound signal to Core/Farm.gd
[ ] Add terminal_measured signal to Core/Farm.gd
[ ] Add terminal_released signal to Core/Farm.gd
[ ] Add structure_built signal to Core/Farm.gd
[ ] Add structure_demolished signal to Core/Farm.gd
[ ] Add biome_expanded signal to Core/Farm.gd
[ ] Mark plot_planted as @deprecated
```

### Phase 2: Action Handlers
```
[ ] Update FarmInputHandler._action_explore():
    - Remove: farm.plot_planted.emit(...)
    - Add: farm.terminal_bound.emit(grid_pos, terminal.id, emoji_pair)

[ ] Update FarmInputHandler._action_measure():
    - Add: farm.terminal_measured.emit(grid_pos, terminal.id, outcome, prob)

[ ] Update FarmInputHandler._action_pop():
    - Add: farm.terminal_released.emit(grid_pos, terminal.id, credits)

[ ] Update FarmGrid.place_mill/market/kitchen():
    - Add: farm.structure_built.emit(position, type, emoji_pair)
```

### Phase 3: Visualization
```
[ ] Update BathQuantumVisualizationController:
    - Disconnect from plot_planted
    - Connect to terminal_bound, terminal_measured, terminal_released
    - Rename internal tracking: _bubbles_by_plot → _bubbles_by_terminal

[ ] Update PlotGridDisplay:
    - Connect to structure_built, structure_demolished
    - Add structure visualization methods
```

### Phase 4: Cleanup
```
[ ] Remove legacy plant_batch action dispatch
[ ] Remove _action_plant_batch method (or mark deprecated)
[ ] Remove _action_batch_plant method (or mark deprecated)
[ ] Update comments throughout codebase
[ ] Remove deprecated signal usage
```

---

## Data Structures

### Terminal (after EXPLORE)
```gdscript
Terminal {
    terminal_id: String        # Unique ID (e.g., "T_00")
    grid_position: Vector2i    # Where on the grid
    register_id: int           # Which register in quantum computer
    emoji_north: String        # |0⟩ basis label (from register)
    emoji_south: String        # |1⟩ basis label (from register)
    is_bound: bool             # true after EXPLORE
    is_measured: bool          # true after MEASURE
    recorded_probability: float # Claim for POP (after MEASURE)
}
```

### Structure (after PLANT)
```gdscript
Structure {
    grid_position: Vector2i    # Where on the grid
    structure_type: String     # "mill", "market", "kitchen", "crop"
    emoji_north: String        # |0⟩ basis label (defined by structure)
    emoji_south: String        # |1⟩ basis label (defined by structure)
    qubit_index: int           # Index in biome's quantum computer
}
```

---

## Visual Separation

### Bubbles (Terminal Visualization)
```
┌─────────────────────────────────────────────────────────────┐
│  BUBBLES = Floating quantum state windows                   │
│                                                             │
│  • Appear when terminal_bound signal fires                  │
│  • Float above plot grid (force-directed movement)          │
│  • Show emoji pair with probability-weighted opacity        │
│  • Glow cyan when measured (ready to harvest)               │
│  • Disappear when terminal_released signal fires            │
│  • Temporary - exist only while terminal is bound           │
└─────────────────────────────────────────────────────────────┘
```

### Plot Tiles (Structure Visualization)
```
┌─────────────────────────────────────────────────────────────┐
│  PLOT TILES = Fixed grid infrastructure                     │
│                                                             │
│  • Update when structure_built signal fires                 │
│  • Fixed position on plot grid (no movement)                │
│  • Show structure icon (🏭 mill, 🏪 market, 🍳 kitchen)     │
│  • Permanent - persist until demolished                     │
│  • Show connection lines to adjacent structures             │
└─────────────────────────────────────────────────────────────┘
```

---

## Summary

| Aspect | EXPLORE | PLANT |
|--------|---------|-------|
| **Tool** | PROBE (Tool 1, PLAY mode) | STRUCTURE (BUILD mode) |
| **Action** | explore | plant_crop, build_* |
| **Signal** | terminal_bound | structure_built |
| **Visual** | Bubble (floating) | Plot tile (fixed) |
| **Creates** | Nothing new | New quantum axis |
| **Cost** | Free | Resources |
| **Duration** | Temporary (until POP) | Permanent |
| **Tracks by** | terminal_id | grid_position |

This architecture cleanly separates:
1. **What the player does** (observe vs build)
2. **What the system does** (bind vs create)
3. **What the UI shows** (bubbles vs tiles)
4. **What signals fire** (terminal_* vs structure_*)
