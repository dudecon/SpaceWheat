# Architecture Deep Dive - Data Model, Boot, Input, Visualization

**Date:** 2026-01-05
**Purpose:** Answer specific architecture questions about data flow and relationships

---

## 1. The Data Model

### Farm.gd - What Does It Contain?

**File:** `Farm.gd.txt`

**Core Responsibility:** Root game state container

**Key Components:**
```gdscript
class_name Farm
extends Node

# Core Systems
var grid: FarmGrid = null              # Plot grid (6 plots)
var economy: FarmEconomy = null        # Resources and transactions
var biotic_flux_biome: BiomeBase = null  # Primary quantum biome
var vocabulary_system = null           # Icon/word system
var conspiracy_network = null          # Faction network

# Quantum Systems
var hamiltonian = null                 # Quantum evolution operator
var quantum_bath = null                # Shared quantum bath for all biomes
```

**Farm → Grid Relationship:**
- Farm OWNS FarmGrid as a child node
- Grid manages 6 BasePlot instances
- Each plot can be "registered" to a biome

**Farm → Biome Relationship:**
- Farm has direct reference to biotic_flux_biome
- Biome DOES NOT know about Farm directly
- Biome operates on quantum bath, grid registers plots with biome

### FarmGrid.gd - How Are Plots Stored?

**File:** `FarmGrid.gd.txt`

**Core Structure:**
```gdscript
class_name FarmGrid
extends Node

var plots: Array[BasePlot] = []  # Fixed size: 6 plots
var plot_count: int = 6

# Registration system
var biome_registrations: Dictionary = {}
# Key: biome reference
# Value: Array of plot indices registered to that biome
```

**Plot Storage:**
- Array of 6 BasePlot instances
- Indexed 0-5 (matches TYUIOP keyboard layout)
- Each plot is a child Node of FarmGrid

**Plot → Biome Registration:**
```gdscript
func register_plot_to_biome(plot_index: int, biome: BiomeBase) -> void:
    """Register a plot to a biome for quantum state tracking"""
    if not biome_registrations.has(biome):
        biome_registrations[biome] = []

    if plot_index not in biome_registrations[biome]:
        biome_registrations[biome].append(plot_index)

    # Tell the biome about this plot
    biome.register_plot(plot_index)
```

**Key Insight:**
- Grid acts as REGISTRAR between plots and biomes
- Multiple plots can register to same biome
- Biome doesn't own plots, just tracks which indices are "theirs"

### BiomeBase.gd - Quantum State Interface

**File:** `BiomeBase.gd.txt` (base class)
**Example:** `BioticFluxBiome.gd.txt` (concrete implementation)

**Core Interface:**
```gdscript
class_name BiomeBase
extends Node

var bath: QuantumBath = null           # Shared quantum state
var registered_plots: Array[int] = []  # Plot indices registered to this biome

# Quantum operations
func register_plot(plot_idx: int) -> void
func get_plot_state(plot_idx: int) -> Dictionary
func evolve(delta: float) -> void      # Quantum time evolution
func apply_hamiltonian() -> void       # H|ψ⟩
```

**BioticFluxBiome Example:**
```gdscript
extends BiomeBase
class_name BioticFluxBiome

# Specific to BioticFlux mechanics
var wheat_growth_rate: float = 1.0
var mushroom_midnight_bonus: float = 2.0

func _physics_process(delta: float) -> void:
    # Evolve quantum state
    if bath:
        bath.evolve_lindbladian(delta)

    # Update registered plots based on quantum state
    for plot_idx in registered_plots:
        var quantum_state = bath.get_state_for_plot(plot_idx)
        # ... apply to grid.plots[plot_idx]
```

**Quantum State Flow:**
```
QuantumBath (shared density matrix)
    ↓ evolves via Lindbladian
BiomeBase.bath
    ↓ queries state for specific plot indices
registered_plots[i]
    ↓ grid provides plot reference
BasePlot instance
    ↓ updates visual state
PlotTile UI
```

---

## 2. The Boot Sequence

### BootManager.boot() - Exact Flow

**File:** `BootManager.gd.txt`

**Complete Boot Stages:**

```gdscript
func boot() -> void:
    """Multi-stage boot sequence"""

    # ═══════════════════════════════════════════════════════════
    # STAGE 1: Core Systems (Autoloads already loaded)
    # ═══════════════════════════════════════════════════════════
    # - IconRegistry (autoload)
    # - GameStateManager (autoload)
    # - QuantumRigorConfig (autoload)

    # ═══════════════════════════════════════════════════════════
    # STAGE 2: Create Farm (Data Model)
    # ═══════════════════════════════════════════════════════════
    var farm = Farm.new()
    farm.name = "Farm"
    farm_view.add_child(farm)  # Add to scene tree

    # Farm internally creates:
    # - FarmGrid (6 plots)
    # - FarmEconomy
    # - BioticFluxBiome
    # - QuantumBath (shared quantum state)

    # ═══════════════════════════════════════════════════════════
    # STAGE 3A: Instantiate FarmUI (UI Layer)
    # ═══════════════════════════════════════════════════════════
    var farm_ui_scene = load("res://UI/FarmUI.tscn")
    var farm_ui = farm_ui_scene.instantiate()
    # NOT added to tree yet!

    # ═══════════════════════════════════════════════════════════
    # STAGE 3B: Setup FarmUI with Dependencies
    # ═══════════════════════════════════════════════════════════
    farm_ui.inject_dependencies(
        farm.grid,                    # Plot data source
        farm.biotic_flux_biome,       # Biome for visualization
        farm.economy                  # Resource display
    )

    # ═══════════════════════════════════════════════════════════
    # STAGE 3C: Mount FarmUI in PlayerShell
    # ═══════════════════════════════════════════════════════════
    player_shell.load_farm_ui(farm_ui)
    # This triggers _move_action_bar_to_top_layer() ← BROKEN HERE!

    # ═══════════════════════════════════════════════════════════
    # STAGE 4: Register Plots to Biome (THE 2-DAY PROBLEM!)
    # ═══════════════════════════════════════════════════════════
    for i in range(farm.grid.plot_count):
        farm.grid.register_plot_to_biome(i, farm.biotic_flux_biome)

    # This was the registration problem:
    # - PlotGridDisplay needs to know which plots belong to which biome
    # - For visualization (oval boundaries, quantum state colors)
    # - Originally tried to auto-detect, but timing issues
    # - Now explicit registration during boot

    print("✅ Boot complete")
```

**Key Timing Issues:**

1. **FarmUI must be instantiated BEFORE being added to tree**
   - Allows dependency injection before _ready() fires

2. **PlotGridDisplay needs layout calculator BEFORE creating tiles**
   - Injected in Stage 3B via `inject_layout_calculator()`

3. **Action bar reparenting happens in Stage 3C**
   - PlayerShell.load_farm_ui() calls deferred _move_action_bar_to_top_layer()
   - THIS IS WHERE UI BREAKS - reparenting happens too early/late

4. **Plot registration AFTER UI is mounted**
   - So PlotGridDisplay can update visuals when plots register

---

## 3. The Input Flow

### FarmInputHandler.gd - Key to Action Flow

**File:** `FarmInputHandler.gd.txt`

**Input Routing Hierarchy:**

```
User presses key
    ↓
PlayerShell._input(event)  ← LAYER 1: Highest priority
    ↓
    ├─ Modal stack active? → Route to modal.handle_input()
    │   └─ QuestBoard, EscapeMenu, SaveLoadMenu
    │
    ├─ Shell action? (C/K/ESC) → Handle in PlayerShell
    │   └─ Open overlays, toggle keyboard hints
    │
    └─ Fall through to Farm._unhandled_input(event)
        ↓
    Farm._unhandled_input(event)  ← LAYER 2: Farm-level
        ↓
        └─ FarmInputHandler.handle_input(event)
            ↓
            ├─ Tool selection? (1-6 keys)
            │   └─ Switch active tool
            │
            ├─ Plot action? (TYUIOP keys)
            │   └─ Apply current tool to plot
            │
            └─ Action key? (QER keys)
                └─ Execute tool-specific action
```

**FarmInputHandler Core Methods:**

```gdscript
class_name FarmInputHandler
extends Node

var farm: Farm = null
var current_tool: String = "grower"  # Active tool

func handle_input(event: InputEvent) -> bool:
    """Process farm-level input"""

    # Tool selection (1-6)
    if event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]:
        _select_tool(event.keycode - KEY_1)
        return true

    # Plot targeting (TYUIOP)
    if event.keycode in [KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P]:
        var plot_idx = _key_to_plot_index(event.keycode)
        _apply_tool_to_plot(plot_idx, current_tool)
        return true

    # Action keys (QER) - tool-specific
    if event.keycode == KEY_Q:
        _execute_q_action(current_tool)
        return true

    return false  # Not consumed
```

**Tool → Action Mapping:**
```
Tool: "grower"
  Q → Plant (initialize quantum state)
  E → Harvest (measure/collapse quantum state)
  R → Sell (convert to resources)

Tool: "entangler"
  Q → Start multi-select
  E → Entangle selected plots (create quantum correlation)
  R → Break entanglement

Tool: "tap"
  Q → Extract energy from biome
  E → Inject energy to biome
  R → Drain (destructive extraction)
```

### Modal Stack Implementation

**PlayerShell.gd lines 24-132:**

```gdscript
var modal_stack: Array[Control] = []

func _input(event: InputEvent) -> void:
    """Layer 1: High-priority input routing"""

    # Modal input (highest priority)
    if not modal_stack.is_empty():
        var active_modal = modal_stack[-1]  # Top of stack
        if active_modal.has_method("handle_input"):
            var consumed = active_modal.handle_input(event)
            if consumed:
                get_viewport().set_input_as_handled()
                return  # Don't pass to lower layers

    # Shell actions (C/K/ESC)
    if _handle_shell_action(event):
        get_viewport().set_input_as_handled()
        return

    # Fall through to Farm._unhandled_input()

func _push_modal(modal: Control) -> void:
    """Add modal to stack"""
    modal_stack.append(modal)

func _pop_modal(modal: Control) -> void:
    """Remove modal from stack"""
    var idx = modal_stack.find(modal)
    if idx >= 0:
        modal_stack.remove_at(idx)
```

**Example Flow - Opening Quest Board:**

1. User presses **C**
2. PlayerShell._input() catches it
3. Calls `_toggle_quest_board()`
4. QuestBoard.open_board() sets visible = true
5. `_push_modal(quest_board)` adds to stack
6. **Next input:** QuestBoard.handle_input() gets first chance
7. User presses **ESC** in quest board
8. QuestBoard.handle_input() consumes ESC, closes board
9. `_pop_modal(quest_board)` removes from stack
10. **Next input:** Falls through to Farm

---

## 4. The Quantum Visualization

### How PlotGridDisplay Knows Which Plots Belong to Which Biome

**The 2-Day Registration Problem:**

**Original Approach (FAILED):**
```gdscript
# PlotGridDisplay tried to auto-detect biome ownership
func _update_biome_visuals():
    for i in range(6):
        # ❌ PROBLEM: No way to know which biome owns plot i!
        var biome = _guess_biome_from_plot_state(plots[i])
        # This caused:
        # - Timing issues (biome not ready)
        # - Wrong biome assignments
        # - Ovals drawn around wrong plots
```

**Current Approach (WORKS):**
```gdscript
# FarmGrid explicitly tracks registrations
var biome_registrations: Dictionary = {
    biotic_flux_biome_ref: [0, 1, 2, 3, 4, 5]  # All 6 plots
}

# PlotGridDisplay queries grid for biome ownership
func _update_biome_visuals():
    for biome in grid.biome_registrations.keys():
        var plot_indices = grid.biome_registrations[biome]
        _draw_biome_oval(biome, plot_indices)
```

**Why It Took 2 Days:**

1. **Attempted Solution 1:** PlotTile stores biome reference
   - Problem: Who sets it? When?
   - Timing issues with initialization

2. **Attempted Solution 2:** Biome auto-registers on _ready()
   - Problem: Order-dependent, breaks on save/load
   - Biome ready before grid ready? Vice versa?

3. **Attempted Solution 3:** Farm broadcasts plot assignments
   - Problem: Signal timing, listeners not ready
   - Who listens? Grid? PlotGridDisplay? Both?

4. **WORKING Solution 4:** Explicit registration in BootManager
   - Grid is single source of truth
   - Registration happens in controlled boot sequence
   - PlotGridDisplay queries grid when needed
   - No timing ambiguity

### Visualization Architecture

**From Quantum State to Pixels:**

```
1. QuantumBath (Core/QuantumSubstrate/QuantumBath.gd)
   - Stores density matrix ρ
   - Evolves via Lindbladian: dρ/dt = -i[H,ρ] + L[ρ]

   ↓ queries state

2. BiomeBase (Core/Environment/BiomeBase.gd)
   - Owns QuantumBath instance
   - Registered plot indices: [0, 2, 4]
   - Methods: get_plot_state(idx), evolve(delta)

   ↓ farm.grid.biome_registrations

3. FarmGrid (Core/GameMechanics/FarmGrid.gd)
   - biome_registrations: { biome → [indices] }
   - Single source of truth for "which plots belong to which biome"

   ↓ injected into PlotGridDisplay

4. PlotGridDisplay (UI/PlotGridDisplay.gd)
   - Queries grid.biome_registrations
   - For each biome: get registered plot indices
   - Calculate oval boundary enclosing those plots
   - Pass to BathQuantumVisualizationController

   ↓ draws ovals

5. BathQuantumVisualizationController (Core/Visualization/...)
   - Receives: biome reference + plot positions
   - Draws: Colored oval, quantum state visualization
   - Node2D with z_index: 50 (above plots, below UI)

   ↓ renders to screen

6. PlotTile (UI/PlotTile.gd)
   - Individual plot visual
   - Receives quantum state updates from biome
   - Shows: emoji (basis state), growth bar, colors
```

**Key Data Flow:**

```gdscript
# In BioticFluxBiome._physics_process(delta):
bath.evolve_lindbladian(delta)  # Quantum evolution

for plot_idx in registered_plots:
    var state = bath.get_state_for_basis(plot_idx)
    # state = { "emoji": "🌾", "probability": 0.8, "phase": 1.2 }

    var plot = farm.grid.plots[plot_idx]
    plot.update_quantum_state(state)
```

```gdscript
# In PlotGridDisplay._process(delta):
# Query grid for biome registrations
for biome in grid.biome_registrations.keys():
    var plot_indices = grid.biome_registrations[biome]

    # Calculate oval boundary
    var plot_positions = []
    for idx in plot_indices:
        plot_positions.append(_get_plot_center(idx))

    var oval_rect = _calculate_enclosing_oval(plot_positions)

    # Tell visualization controller
    viz_controller.update_biome_oval(biome, oval_rect)
```

---

## 5. Scene Structure

### Root Scene: FarmView.tscn

**File:** `FarmView.tscn.txt`

**Scene Hierarchy:**
```tscn
[node name="FarmView" type="Control"]
# Root control, fills viewport
anchors_preset = 15  # PRESET_FULL_RECT
script = "res://UI/FarmView.gd"

# FarmView.gd creates children dynamically in _ready():
# - PlayerShell (from PlayerShell.tscn)
# - viz_layer (CanvasLayer for biome visualization)
# - Farm (data model, not visual)
```

**What FarmView Does:**

```gdscript
# FarmView.gd _ready():

1. Create PlayerShell
   var player_shell_scene = load("res://UI/PlayerShell.tscn")
   var player_shell = player_shell_scene.instantiate()
   add_child(player_shell)

2. Create Visualization Layer
   var viz_layer = CanvasLayer.new()
   viz_layer.layer = 0  # Same layer as UI
   add_child(viz_layer)

   var quantum_viz = BathQuantumVisualizationController.new()
   quantum_viz.z_index = 50  # Above plots, below UI
   viz_layer.add_child(quantum_viz)

3. Create Farm (data)
   var farm = Farm.new()
   add_child(farm)

4. Trigger Boot
   BootManager.boot(self, farm, player_shell)
```

**Why This Structure:**

- **FarmView** = Root, owns everything
- **PlayerShell** = Player-persistent UI (stays when swapping farms)
- **viz_layer** = Separate CanvasLayer for biome visualization depth control
- **Farm** = Data model (not visual)

**Scene Instantiation Order:**
```
1. Engine loads FarmView.tscn
2. FarmView._ready() fires
3. FarmView creates:
   - PlayerShell.tscn (instantiated)
     - PlayerShell._ready() fires
       - Creates OverlayLayer children
       - Creates ActionBarLayer (empty)
   - viz_layer (new CanvasLayer)
   - Farm (new Node)
4. BootManager.boot() fires
   - Instantiates FarmUI.tscn
   - Injects dependencies
   - PlayerShell.load_farm_ui() fires
     - _move_action_bar_to_top_layer() fires ← UI BREAKS HERE
```

---

## Summary of Critical Paths

### Data Model
- **Farm** contains Grid, Economy, Biome, QuantumBath
- **Grid** stores 6 plots + biome_registrations dictionary
- **Biome** operates on QuantumBath, tracks registered_plots
- **Plot** is data + visual, updated by biome quantum state

### Boot Sequence
1. Autoloads (IconRegistry, GameStateManager)
2. Create Farm (data model)
3. Instantiate FarmUI (UI layer)
4. Inject dependencies
5. Mount FarmUI in PlayerShell ← **BREAKS HERE**
6. Register plots to biomes

### Input Flow
1. PlayerShell._input() - modal stack & shell actions
2. Farm._unhandled_input() - passes to FarmInputHandler
3. FarmInputHandler - tool selection, plot actions, QER keys

### Visualization
1. QuantumBath evolves
2. Biome queries bath for registered plots
3. Grid tracks biome_registrations (which plots → which biome)
4. PlotGridDisplay queries grid, calculates ovals
5. BathQuantumVisualizationController draws
6. PlotTile updates individual plot visuals

### Scene Structure
- FarmView.tscn (root) creates everything dynamically
- PlayerShell.tscn defines layer structure
- FarmUI.tscn defines farm interface (where action bars start)
- Action bars reparented from FarmUI to PlayerShell.ActionBarLayer ← **BREAKS**

---

## Files Added to Investigation

**Data Model:**
- `Farm.gd.txt` - Root game state
- `FarmGrid.gd.txt` - Plot storage and biome registration
- `BioticFluxBiome.gd.txt` - Concrete biome implementation
- `BiomeBase.gd.txt` - Biome base class
- `BasePlot.gd.txt` - Plot data structure

**Boot Sequence:**
- `BootManager.gd.txt` - Multi-stage boot process

**Input Flow:**
- `FarmInputHandler.gd.txt` - Key to action mapping

**Visualization:**
- `PlotTile.gd.txt` - Individual plot visual
- `BathQuantumVisualizationController.gd.txt` - Biome oval renderer

**Scene Structure:**
- `FarmView.tscn.txt` - Root scene

**Total new files:** 10
**Total investigation files:** 29

---

**All requested information now available for architecture review.**
