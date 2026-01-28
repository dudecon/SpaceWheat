# Multi-Select System (Plot Checkboxes)

## Summary

The plot selection system now supports **multi-select checkboxes** for batch operations:

```
Press J/K/L/; → Select plot + toggle checkmark ☑
Press Shift+3Q → Act on ALL checked plots (batch EXPLORE)
Press Shift+4E → Full quantum reset + cycle to next biome
```

This enables strategic batch operations across multiple plots, even spanning different biomes!

---

## What Changed

### Before (Single Selection)
```gdscript
Press J → Selects plot 0 (highlights it)
Press 3Q → Explores plot 0
Press Shift+3Q → Explores ALL 4 plots in current biome (JKL;)
```
Fixed batch operation on entire homerow.

### After (Multi-Select with Checkboxes)
```gdscript
Press J → Selects plot 0 AND toggles checkmark ☑
Press J again → Unchecks plot 0 ☐
Press K → Selects plot 1 AND toggles checkmark ☑
Press 3Q → Explores currently selected plot (single)
Press Shift+3Q → Explores ALL checked plots (batch operation)
```
Dynamic batch operation on user-selected plots.

---

## How It Works

### Visual Indicators

Each plot tile shows two visual states:

1. **Selection (cyan border)**: Currently focused plot (cursor)
2. **Checkbox (☑ in top-right)**: In multi-select group

**Example:**
```
Plot J: Cyan border + ☑ → Selected AND checked
Plot K: No border + ☑  → Checked but not selected
Plot L: Cyan border + ☐ → Selected but not checked
Plot ;: No border + ☐  → Neither
```

### Toggle Behavior

Press the same key to toggle:
```
Press J → Check ☑
Press J → Uncheck ☐
Press J → Check ☑
```

Checkmarks **persist** even when you:
- Switch biomes (T/Y/U/I/O/P)
- Select different plots
- Perform actions

This allows building up a multi-select group across multiple biomes!

---

## Use Cases

### 1. Batch Explore Across Biomes

**Scenario:** You want to explore 2 plots in BioticFlux and 3 plots in StellarForges.

**Steps:**
1. Press U (select BioticFlux)
2. Press J (check plot 0)
3. Press K (check plot 1)
4. Press I (switch to StellarForges)
5. Press J (check plot 0)
6. Press K (check plot 1)
7. Press L (check plot 2)
8. Press Shift+3Q (batch EXPLORE all 5 checked plots)

**Result:** All 5 plots explored in one batch operation!

### 2. Selective Measurement

**Scenario:** You explored 4 plots but only want to measure 2 of them (cherry-pick high-probability outcomes).

**Steps:**
1. Manually uncheck the 2 plots you don't want to measure
2. Press Shift+3E (batch MEASURE on remaining 2 checked plots)

### 3. Cleanup After Harvest

**Scenario:** You harvested plots in multiple biomes and want to clear checkmarks.

**Steps:**
- **Option A (Full Reset):** Press Shift+4E to reset everything + cycle to next biome
- **Option B (Manual):** Press J/K/L/; to toggle individual checkmarks

---

## Keyboard Controls

### Selection Keys (JKL;)
- **J** → Select plot 0 + toggle checkbox
- **K** → Select plot 1 + toggle checkbox
- **L** → Select plot 2 + toggle checkbox
- **;** → Select plot 3 + toggle checkbox

### Action Keys (QER with modifiers)
- **Q/E/R** → Act on currently selected plot (single)
- **Shift+Q/E/R** → Act on ALL checked plots (batch)

**Special Shift Modifiers:**
- **Shift+4E** (Tool 4 only) → **Quantum Reset + Cycle Biome**: Full reset + move to next biome

**Example:**
```
3Q → EXPLORE current plot
Shift+3Q → EXPLORE all checked plots

3E → MEASURE current plot
Shift+3E → MEASURE all checked plots

3R → POP current plot
Shift+3R → POP all checked plots

Shift+4E → QUANTUM RESET + cycle to next biome (full reset)
```

**Auto-Clear Behavior:**
- **Shift+3R (Batch Harvest)**: Checkmarks automatically clear after harvest completes
  - Reason: Harvested terminals are recycled/destroyed, so keeping checkmarks would be confusing
  - You'll need to re-check plots for next batch operation

---

## Technical Implementation

### Multi-Select State

**File:** `UI/Core/QuantumInstrumentInput.gd`

```gdscript
# State tracking
var checked_plots: Array[Vector2i] = []  # Global multi-select set

# Signal emitted when checkbox toggled
signal plot_checked(grid_pos: Vector2i, is_checked: bool)

# Toggle function
func toggle_check(grid_pos: Vector2i) -> void:
    if grid_pos in checked_plots:
        checked_plots.erase(grid_pos)  # Uncheck
    else:
        checked_plots.append(grid_pos)  # Check
    plot_checked.emit(grid_pos, grid_pos in checked_plots)
```

### Visual Checkbox

**File:** `UI/PlotTile.gd`

```gdscript
# UI element (already existed!)
var checkbox_label: Label  # Shows ☐ or ☑

# Update function
func set_checkbox_selected(selected: bool) -> void:
    is_checkbox_selected = selected
    checkbox_label.text = "☑" if selected else "☐"
    # Bright cyan when checked, dimmed when unchecked
```

### Signal Wiring

**File:** `Core/Boot/BootManager.gd`

```gdscript
# Connect QuantumInstrumentInput signal to PlotGridDisplay handler
input_handler.plot_checked.connect(plot_grid_display.set_plot_checked)
```

### Batch Operation

**File:** `UI/Core/QuantumInstrumentInput.gd`

```gdscript
func _perform_shift_key_action(action_key: String) -> void:
    """Apply action to all checked plots (not entire homerow).

    Special case: Shift+4E = Clear checks + cycle biome
    """
    var current_group = ToolConfig.get_current_group()

    # Special case: Shift+4E (Tool 4, E key) = Clear checks + cycle biome
    if current_group == 4 and action_key == "E":
        _clear_checks_and_cycle_biome()
        return

    var positions = checked_plots.duplicate()
    if positions.is_empty():
        _verbose.debug("input", "⚠️", "No plots checked")
        return

    # Execute action on each checked plot
    for pos in positions:
        _set_selection_for_grid_pos(pos)
        _run_action(action_name, symbol, log_label)

    # Note: harvest_all action handles clearing checkmarks internally
```

**Auto-Clear Implementation:**
```gdscript
func _action_harvest_all() -> Dictionary:
    """Execute SHIFT+R/harvest_all: harvest density matrix, clear selections, unexplore plots."""
    var biome = _get_current_biome()
    var result = ProbeActions.action_harvest_all(farm.plot_pool, farm.economy, biome)

    if result.get("success", false):
        # Clear all checkmarks after successful harvest
        clear_all_checks()
        _verbose.info("input", "🧹", "Cleared terminals and selections after harvest")

    return result
```

**Key Changes:**
- Uses `checked_plots` instead of `_get_homerow_positions()`
- Special handling for Shift+4E (clear + cycle)

### Reset Function

**File:** `UI/Core/QuantumInstrumentInput.gd`

```gdscript
func _clear_checks_and_cycle_biome() -> void:
    """Shift+4E: Full quantum reset + cycle biome."""
    # Clear all checkmarks
    clear_all_checks()

    # Deselect all plots visually
    plot_grid_display.set_selected_plot(Vector2i(-1, -1))

    # Reset selection state
    current_selection = {"plot_idx": -1, "biome": "", "subspace_idx": -1}
    last_selected_plot_position = Vector2i(-1, -1)

    # Reset quantum simulation
    if farm and farm.has_method("reset_quantum_state"):
        farm.reset_quantum_state()

    # Cycle to next biome
    _action_cycle_biome()
```

---

## Grid Position Format

Checkmarks are stored as **Vector2i(x, y)**:
- **x**: Plot index (0-3 for J/K/L/;)
- **y**: Biome row (0-5 for T/Y/U/I/O/P)

**Example:**
```gdscript
Vector2i(0, 0) → Plot J in BioticFlux (T)
Vector2i(1, 2) → Plot K in FungalNetworks (O)
Vector2i(3, 4) → Plot ; in StarterForest (Y)
```

This allows checkmarks to persist across biome switches!

---

## Logging

### Check/Uncheck Actions
```
[DEBUG][input] ☑ Checked plot at Vector2i(0, 0) (total: 1)
[DEBUG][input] ☑ Checked plot at Vector2i(1, 0) (total: 2)
[DEBUG][input] ☐ Unchecked plot at Vector2i(0, 0)
```

### Batch Operations
```
[INFO][input] ⇧Q Batch EXPLORE on 3 checked plots
```

### Empty Batch
```
[DEBUG][input] ⚠️ No plots checked - Shift+action requires checked plots
```

---

## Reset Operations

### Shift+4E: Quantum Reset + Cycle Biome (Tool 4 Only)

**Full system reset** that clears all player state and moves to next biome:

**What it does:**
1. ✅ Clears all checkmarks (☑ → ☐)
2. ✅ Deselects all plots (removes cyan borders)
3. ✅ Resets internal selection state
4. ✅ Calls `farm.reset_quantum_state()` if available (resets quantum simulation)
5. ✅ Cycles to next biome (T→Y→U→I→O→P→T...)

**Use case:** Start fresh without reloading the game. Useful when you want to clear everything, reset the quantum state, and move to the next biome in one action.

**Example:**
```
Tool 4 selected (Meta)
You have 5 plots checked across 3 biomes
You're deep into a quantum experiment
Press Shift+4E → Everything resets + switched to next biome
Ready to start fresh in new biome!
```

**Why Tool 4 only?**
- Tool 4 (Meta) is about system-level operations (vocabulary, biome management)
- Shift+4E is grouped with 4E ("cycle biome") - the Shift version adds reset behavior
- Prevents accidental resets when using other tool groups

---

## Future Enhancements

### Possible Extensions

1. **Visual Connection Lines**
   - Draw lines between checked plots to show batch operation scope
   - Glow effect on checked plots when Shift is held

3. **Checkbox Toggle Key**
   - Separate key (like Space) to toggle checkbox without selecting
   - Allows "marking" plots without moving cursor

4. **Smart Batch Operations**
   - Skip plots that can't perform the action (already measured, etc.)
   - Warning if some plots fail validation

5. **Batch Operation Preview**
   - Show preview of what will happen before executing Shift+action
   - "Shift+3Q will EXPLORE 3 plots: J@BioticFlux, K@BioticFlux, J@StellarForges"

6. **Persistent Checkbox Sets**
   - Save/load checkbox state in game save file
   - Name checkbox groups ("Harvest Group A", "Measurement Set 1")

---

## Strategic Depth

### What This Adds to Gameplay

1. **Precision Batch Operations**
   - Choose exactly which plots to act on (not forced to entire homerow)
   - Mix plots from different biomes in one batch

2. **Multi-Biome Coordination**
   - Build up a batch operation across multiple biomes
   - Strategic planning of which plots to group together

3. **Workflow Efficiency**
   - Check plots during exploration phase
   - Execute batch harvest at end of turn
   - Reduces repetitive key presses

4. **Visual Planning**
   - Checkmarks show your intended next action
   - See at a glance which plots are queued for batch operation

### Example Strategies

**Early Game (Learning):**
- Check all plots before batch EXPLORE
- Learn that checkmarks persist across biome switches
- Discover Shift+action acts on checked plots only

**Mid Game (Optimization):**
- Selectively check high-value plots for batch MEASURE
- Leave low-probability plots unchecked to save actions
- Use checkmarks as a "to-do list" for harvest

**Late Game (Mastery):**
- Strategic batch operations across entangled plot networks
- Coordinate multi-biome harvests with checkmark groups
- Minimize action count through efficient batch planning

---

## Testing the System

### In-Game Test Sequence

1. **Boot game** and wait for farm to initialize
2. **Select BioticFlux** (press T)
3. **Check plot J** (press J) → See ☑ in top-right of plot J tile
4. **Check plot K** (press K) → See ☑ on both J and K
5. **Uncheck plot J** (press J again) → See ☐ on plot J
6. **Switch to StellarForges** (press I)
7. **Check plot K** (press K) → See ☑ on plot K in StellarForges
8. **Switch back to BioticFlux** (press T)
9. **Verify:** Plot K still has ☑ from step 4
10. **Batch EXPLORE** (press Shift+3Q)
11. **Check console:**
    ```
    [INFO][input] ⇧Q Batch EXPLORE on 2 checked plots
    [INFO][ui] 🌾 Explored plot at Vector2i(1, 0)
    [INFO][ui] 🌾 Explored plot at Vector2i(1, 3)
    ```

### Expected Behavior

- ✅ Pressing J/K/L/; toggles checkmark (☑ ↔ ☐)
- ✅ Checkmarks persist when switching biomes
- ✅ Shift+action acts on ALL checked plots (not entire homerow)
- ✅ Regular action acts on currently selected plot only
- ✅ Warning if Shift+action pressed with no checked plots

---

## Relation to Other Systems

### Neighbor Bonus Multiplier
```
Credits = probability × purity × neighbor_count
```
- Multi-select allows batch harvest of high-neighbor plots
- Check interior plots (4 neighbors) for maximum credit extraction
- Strategic grouping by neighbor count

### Purity Multiplier
```
Credits = probability × PURITY × neighbor_count
```
- Check plots with high purity (Tr(ρ²) > 0.8) for batch harvest
- Visual purity indicator (Ψ%) helps identify high-value plots
- Batch operations on coherent plot groups

### Entanglement
- Check entangled plots to measure as a group (coordinated collapse)
- Batch MEASURE on entangled pair → consistent measurement outcomes
- Strategic: Check one endpoint, measure both via entanglement

---

## Performance

### Memory Overhead
- **checked_plots array**: ~24 bytes per checked plot (Vector2i + overhead)
- **Maximum**: 24 plots × 24 bytes = 576 bytes (negligible)

### Signal Emission
- **plot_checked**: Emitted once per toggle (~1-2 per second max)
- **PlotTile.set_checkbox_selected()**: O(1) update (just text + color change)
- **Negligible overhead**: Signal emission is fast, checkbox update is trivial

### Batch Operations
- **Shift+action**: Loops through checked_plots array (typically 2-8 plots)
- **Same cost as before**: Previously looped through homerow (4 plots)
- **Actually more efficient** when checking fewer than 4 plots!

---

**Last Updated:** 2026-01-26
**Status:** ✅ Implemented and Tested
**Commit:** [current]

**Key Files Modified:**
1. `UI/Core/QuantumInstrumentInput.gd` - Multi-select state + signal
2. `UI/PlotGridDisplay.gd` - Checkbox visual handler
3. `Core/Boot/BootManager.gd` - Signal wiring
4. `UI/PlotTile.gd` - Checkbox visual (no changes - already existed!)

**Signal Flow:**
```
User presses J/K/L/;
    ↓
QuantumInstrumentInput._select_plot()
    ↓
toggle_check(grid_pos)
    ↓
plot_checked.emit(grid_pos, is_checked)
    ↓
PlotGridDisplay.set_plot_checked(pos, is_checked)
    ↓
PlotTile.set_checkbox_selected(is_checked)
    ↓
Checkbox label updates: ☑ or ☐
```

**Batch Operation Flow:**
```
User presses Shift+3Q
    ↓
_perform_shift_key_action("Q")
    ↓
Get checked_plots array (e.g., [Vec2i(0,0), Vec2i(1,3)])
    ↓
For each position:
    - Set selection to that position
    - Execute action (EXPLORE)
    - Refresh tile visuals
    ↓
Restore original selection
```
