# Bubble Rendering Fix - Debug Session

## Changes Made

### 1. Removed Biome-Based Visibility Override ✅
**File**: `Core/Visualization/QuantumNodeManager.gd`

Disabled `filter_nodes_for_biome()` which was overriding selection-based visibility when switching biomes.

**Before:**
```gdscript
for node in nodes:
    if active_biome == "":
        node.visible = true
    else:
        node.visible = (node.biome_name == active_biome)
```

**After:**
```gdscript
# DISABLED: Don't override selection-based visibility
pass
```

This fixes the "bubbles appear when switching biomes" issue.

### 2. Enhanced Debug Output ✅
**File**: `Core/Visualization/BathQuantumVisualizationController.gd`

Added comprehensive logging to diagnose bubble creation and visibility:

- **Connection**: Shows if PlotGridDisplay found and connected
- **Initial sync**: Lists selected plot positions at startup
- **Selection changes**: Logs each plot selection/deselection event
- **Bubble creation**: Shows visibility state and selection count
- **Visibility changes**: Logs when bubbles are shown/hidden

### 3. Added Visibility Fallback ✅

If PlotGridDisplay isn't found (test scenes, timing issues):
- Bubbles default to `visible = true` (backward compatibility)
- Warning logged but no errors

## Testing Instructions

### Run the game and watch console output:

```bash
godot 2>&1 | grep -E "\[viz\]|\[ui\].*☑️|\[farm\].*🌱"
```

### Expected Debug Flow

**1. Initialization:**
```
[viz] 📡 Connected to PlotGridDisplay.plot_selection_changed
[viz] ✅ Synced initial plot selection: 0 plots selected (positions: [])
[viz] 🔍 PlotGridDisplay.selected_plots has 0 entries: []
```

**2. Select a plot (click checkbox or press J/K/L/;):**
```
[ui]  ☑️ Plot (0,0) selected (total selected: 1)
[viz] ☑️ Plot (0,0) selected (total selected: 1)
[viz] 🔍 Plot (0,0) selected but no bubble exists yet
```

**3. Explore the selected plot (press E):**
```
[farm] 🌱 EXPLORE emit: grid_pos=(0,0), terminal=T_00, biome=StarterForest
[viz] 🔔 Terminal T_00 bound at (0,0) (🌲/🍂)
[viz] 🔄 Using terminal's biome: StarterForest for position (0,0)
[viz] 🔵 Created terminal bubble (🌲/🍂) at grid (0,0) [visible=true, selected=true, total_selected=1]
```
👉 **BUBBLE SHOULD APPEAR HERE** ✅

**4. Deselect the plot:**
```
[ui]  ☑️ Plot (0,0) deselected (total selected: 0)
[viz] ☑️ Plot (0,0) deselected (total selected: 0)
[viz] 👁️ Bubble at (0,0) visibility changed: false
```
👉 **BUBBLE SHOULD DISAPPEAR** ✅

**5. Reselect the plot:**
```
[ui]  ☑️ Plot (0,0) selected (total selected: 1)
[viz] ☑️ Plot (0,0) selected (total selected: 1)
[viz] 👁️ Bubble at (0,0) visibility changed: true
```
👉 **BUBBLE SHOULD REAPPEAR** ✅

## Diagnostic Checklist

If bubbles still don't appear, check the console for:

### Issue 1: PlotGridDisplay Not Found
```
[viz] ⚠️ PlotGridDisplay not found - selection-based filtering disabled
```
**Solution**: PlotGridDisplay should be in scene tree under PlayerShell. Check initialization order.

### Issue 2: Selection Not Synced
```
[viz] ✅ Synced initial plot selection: 0 plots selected
```
Then you explore, and see:
```
[viz] 🔵 Created terminal bubble ... [visible=false, selected=false, total_selected=0]
```
**Problem**: Plot wasn't selected before exploring.
**Solution**: Select plot FIRST, then explore.

### Issue 3: Bubble Created But Not Visible
```
[viz] 🔵 Created terminal bubble ... [visible=false, selected=false, total_selected=0]
```
**Problem**: `selected_plot_positions` is empty or doesn't have this grid_pos.
**Check**:
- Is the grid_pos correct?
- Is PlotGridDisplay.selected_plots tracking the right positions?
- Does grid_pos match between selection and exploration?

### Issue 4: Visibility Changed But Bubble Not Rendering
```
[viz] 👁️ Bubble at (0,0) visibility changed: true
```
But bubble doesn't appear.
**Problem**: Renderer might not be checking `node.visible`.
**Check**: Confirm QuantumBubbleRenderer line 49-50 checks visibility:
```gdscript
if not node.visible:
    continue
```

## Quick Test Sequence

1. Launch game
2. Select plot at (0,0) - press `J`
3. Explore - press `E`
4. **BUBBLE SHOULD APPEAR**
5. Deselect - press `J` again
6. **BUBBLE SHOULD DISAPPEAR**
7. Reselect - press `J`
8. **BUBBLE SHOULD REAPPEAR**

## Next Steps Based on Output

**If you see this pattern:**
```
[viz] ⚠️ PlotGridDisplay not found
```
→ PlotGridDisplay initialization issue. Check scene tree structure.

**If you see this:**
```
[viz] 🔵 Created terminal bubble ... [visible=false, selected=false]
```
→ Selection isn't being tracked. Plot needs to be selected first.

**If you see this:**
```
[viz] 🔵 Created terminal bubble ... [visible=true, selected=true]
```
But no bubble appears → Rendering issue. Check graph.queue_redraw() is being called.

---

**Status**: Ready for testing
**Next**: Run game and paste console output here for analysis
