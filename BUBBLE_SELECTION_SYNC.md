# Bubble Selection Synchronization - Implementation Complete

## Overview

Bubble rendering is now synchronized with the Quantum Instrument's plot selection UI (checkmarks).

**Architecture**: Bubbles only render for plots that are BOTH:
1. **Selected** (checkmark visible in PlotGridDisplay)
2. **Explored** (terminal bound to quantum register)

## Changes Made

### 1. PlotGridDisplay - Selection Signal Emission

**File**: `UI/PlotGridDisplay.gd`

- Added new signal: `plot_selection_changed(position: Vector2i, is_selected: bool)`
- Signal emitted whenever plot selection state changes:
  - Individual toggle (JKL; keys or tile click)
  - Select all (`]` key)
  - Clear all (`[` key)
  - Drag selection
- Added to "plot_grid_display" group for discovery

**Lines modified:**
- Line 61: Added signal declaration
- Line 1003: Emit on individual toggle
- Line 1009-1016: Emit on clear all
- Line 1027-1050: Emit on select all
- Line 1262-1268: Emit on drag selection
- Line 72: Added to group

### 2. BathQuantumVisualizationController - Selection Tracking

**File**: `Core/Visualization/BathQuantumVisualizationController.gd`

- Added plot selection state tracking
- Connects to PlotGridDisplay on initialization
- Shows/hides bubbles based on selection state
- New bubbles inherit visibility from selection state

**New members:**
```gdscript
var plot_grid_display_ref = null
var selected_plot_positions: Dictionary = {}  # Vector2i -> true
```

**New functions:**
- `_connect_to_plot_grid_display()` - Finds PlotGridDisplay and connects signals
- `_on_plot_selection_changed(position, is_selected)` - Shows/hides bubble when selection changes

**Modified functions:**
- `_create_bubble_for_terminal()` - Sets initial visibility based on selection state

## How It Works

### Flow Diagram

```
User Action                    Signal Chain                     Bubble State
───────────                   ──────────────                   ─────────────

Click plot checkbox    →   plot_selection_changed(pos, true)  →  Bubble visible
                                                                   (if explored)

Uncheck plot          →   plot_selection_changed(pos, false)  →  Bubble hidden

Explore (E key)       →   terminal_bound(pos, ...)            →  Bubble created
                                                                   (visible only if selected)

Select All (])        →   plot_selection_changed × N          →  All explored bubbles visible

Clear All ([)         →   plot_selection_changed × N          →  All bubbles hidden
```

### Selection States

| Plot Selected | Terminal Bound | Bubble Visible |
|---------------|----------------|----------------|
| ❌ No         | ❌ No          | ❌ No          |
| ✅ Yes        | ❌ No          | ❌ No          |
| ❌ No         | ✅ Yes         | ❌ No          |
| ✅ Yes        | ✅ Yes         | ✅ **YES**     |

## Usage Instructions

### For Players

1. **Select plots** using:
   - Keyboard: `JKL;` keys (row 0-3)
   - Mouse: Click plot tiles
   - Touch: Tap plot tiles
   - Shortcuts: `]` = select all, `[` = clear all

2. **Explore selected plots**: Press `E` key
   - Bubbles will appear ONLY for selected plots
   - Multiple explorations work correctly

3. **Manage visibility**:
   - Uncheck a plot → its bubble disappears
   - Check a plot → its bubble reappears (if explored)

### For Developers

**Debug output** (with VerboseConfig):
```
[viz] 📡 Connected to PlotGridDisplay.plot_selection_changed
[viz] ✅ Synced initial plot selection: 2 plots selected
[ui]  ☑️ Plot (0,0) selected (total selected: 1)
[viz] ☑️ Plot (0,0) selected
[farm] 🌱 EXPLORE emit: grid_pos=(0,0), terminal=T_00, biome=StarterForest
[viz] 🔔 Terminal T_00 bound at (0,0) (🌲/🍂)
[viz] 🔵 Created terminal bubble (🌲/🍂) at grid (0,0) [visible=true]
[viz] 👁️ Bubble at (0,0) visibility: true
```

**Testing checklist:**
- [ ] Select plot, then explore → bubble appears
- [ ] Explore, then select → bubble appears when selected
- [ ] Deselect explored plot → bubble disappears
- [ ] Reselect → bubble reappears
- [ ] Select all → all explored bubbles visible
- [ ] Clear all → all bubbles hidden

## Fallback Behavior

If PlotGridDisplay is not found (e.g., in test scenes):
- Warning logged: `⚠️ PlotGridDisplay not found - selection-based filtering disabled`
- Bubbles default to visible (original behavior)
- No errors or crashes

## Integration Points

**Connects to:**
- `PlotGridDisplay.plot_selection_changed` signal
- Found via scene tree search:
  1. Try: `PlayerShell → QuantumInstrument → PlotGridDisplay`
  2. Fallback: Search "plot_grid_display" group

**Called from:**
- `BathQuantumViz.connect_to_farm()` during visualization initialization

## Known Limitations

1. **Selection persistence**: Selection state resets on biome switch (by design)
2. **Multi-biome**: Selection is per-biome (active biome only)
3. **Initialization timing**: PlotGridDisplay must be initialized before BathQuantumViz

## Future Enhancements

- [ ] Save/load selection state
- [ ] Selection presets ("favorites")
- [ ] Keyboard shortcut to toggle all visible bubbles
- [ ] Selection state in game save files

---

**Status**: ✅ Complete and ready for testing
**Date**: 2025-02-02
**Related Files**:
- `UI/PlotGridDisplay.gd`
- `Core/Visualization/BathQuantumVisualizationController.gd`
