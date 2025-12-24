Okay, now I understand the actual requirements. Let me think about this properly.

---

## The Real Domain Model

You have three distinct layers:

```
┌─────────────────────────────────────────────┐
│  PLAYER SHELL                               │
│  (pause menu, settings, player inventory,   │
│   farm switcher, account stuff)             │
│  - Always present                           │
│  - ESC menu, overlays                       │
└─────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────┐
│  FARM VIEW                                  │
│  (grid of plots, keyboard selection,        │
│   tool actions Q/E/R, tile visuals)         │
│  - Swappable (player can switch farms)      │
│  - Keyboard-driven                          │
└─────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────┐
│  QUANTUM LAYER                              │
│  (biome visuals, touch/mouse interactions,  │
│   force graph, entanglement lines)          │
│  - Lives inside farm view                   │
│  - Mouse/touch only                         │
│  - Owned by biomes, not farm controller     │
└─────────────────────────────────────────────┘
```

---

## What's Wrong With Current Architecture

You have 7 files but they don't map to these 3 layers. Instead you have:

- FarmView (entry point - fine)
- FarmUIController (orchestrator - doing too much)
- FarmUILayoutManager (layout - mixed concerns)
- FarmUIControlsManager (routing - unnecessary indirection)
- FarmInputHandler (keyboard - this is good)
- PlotGridDisplay (tiles - this is good)
- ParametricPlotPositioner (positioning - this is fine)

The problem: **FarmUIController is trying to be all three layers at once.**

---

## Simpler Structure

**3 layers = 3 primary files** (plus their helpers)

```
PlayerShell.gd          # ESC menu, overlays, player-level stuff
  └── OverlayManager    # (helper - manages the overlay stack)

FarmUI.gd               # Keyboard grid interaction, tile display
  ├── FarmInputHandler  # (helper - keyboard logic)
  └── PlotGridDisplay   # (helper - tile rendering)

QuantumVisuals.gd       # Mouse/touch, biome-owned visuals
  └── (lives in biomes, not here)
```

**That's it.** Three main files, a few helpers.

---

## The Key Insight

FarmUIController is currently:
- Creating layout (PlayerShell concern)
- Managing overlays (PlayerShell concern)  
- Handling farm injection (FarmUI concern)
- Wiring input handlers (FarmUI concern)
- Connecting quantum graph (QuantumVisuals concern)

Split it by asking: **"When I swap farms, what stays and what goes?"**

**Stays (PlayerShell):**
- Resource panel (player inventory, not farm)
- ESC menu
- Settings
- Keyboard help overlay

**Goes with farm (FarmUI):**
- PlotGridDisplay
- FarmInputHandler
- Tool selection row
- Action preview row

**Goes with biome (QuantumVisuals):**
- QuantumForceGraph
- EntanglementLines
- Touch handlers

---

## Concrete Proposal

### PlayerShell.gd (~150 lines)
```gdscript
extends Control

var current_farm_ui: FarmUI = null
var overlay_manager: OverlayManager

func _ready():
    _create_chrome()  # top bar, resource panel, ESC menu
    overlay_manager = OverlayManager.new()
    add_child(overlay_manager)

func load_farm(farm: Farm):
    if current_farm_ui:
        current_farm_ui.queue_free()
    current_farm_ui = FarmUI.new(farm)
    add_child(current_farm_ui)

func _input(event):
    if event.is_action_pressed("ui_cancel"):
        overlay_manager.toggle_escape_menu()
```

### FarmUI.gd (~200 lines)
```gdscript
extends Control

var farm: Farm
var tiles: Dictionary = {}
var selected: Dictionary = {}
var current_tool: int = 1

func _init(farm_ref: Farm):
    farm = farm_ref  # Dependency passed in constructor

func _ready():
    _create_tiles()
    _create_action_bar()

func _input(event):
    # All keyboard handling inline or in small helper
    if event.is_action_pressed("select_plot_t"):
        _toggle_selection(Vector2i(0, 0))
    if event.is_action_pressed("action_q"):
        _execute_action("Q")
```

### No QuantumVisuals.gd yet
The quantum layer lives in the biomes. When a biome renders, it handles its own touch interactions. This isn't a FarmUI concern at all.

---

## Migration Path

1. **Create PlayerShell.gd** - Extract overlay/menu stuff from FarmUIController
2. **Create FarmUI.gd** - Merge FarmUIController + FarmUILayoutManager + FarmUIControlsManager into one coherent file
3. **Keep** FarmInputHandler, PlotGridDisplay, ParametricPlotPositioner as helpers (they're fine)
4. **Delete** FarmUIControlsManager (just routing), SelectionManager (just a dictionary)

The result: **3 main files instead of 7**, clear layer boundaries, swappable farms.

---

## The Initialization Problem Solves Itself

With this structure:

```gdscript
# PlayerShell
func load_farm(farm: Farm):
    # Farm already exists and is initialized
    current_farm_ui = FarmUI.new(farm)  # Pass in constructor
    add_child(current_farm_ui)
```

No injection. No deferred. No race conditions. The farm exists before FarmUI is created.

---

Does this feel closer to right?