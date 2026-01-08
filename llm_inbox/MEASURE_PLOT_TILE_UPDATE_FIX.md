# Measurement → Plot Tile Update Fix

## Issue Reported

> "please check that measuring a bubble also update the emoji displayed on the plot. there should be some plot effects to that match the emoji effect."

## Root Cause Analysis

### The Problem

When a player taps a quantum bubble to measure it, the bubble visualization updates correctly, but the **plot tile at the bottom does NOT update** to show the measured emoji.

### Why It Happened

**PlotGridDisplay** was missing a signal connection:

```gdscript
// UI/PlotGridDisplay.gd:348-362 (BEFORE FIX)
# Connected to:
farm.plot_planted.connect(_on_farm_plot_planted)   ✅
farm.plot_harvested.connect(_on_farm_plot_harvested) ✅

# NOT connected to:
farm.plot_measured  ❌ MISSING!
```

This meant the measurement event never triggered a visual update of the plot tile.

### Expected Flow (What Should Happen)

```
1. Player taps bubble
   ↓
2. FarmView._on_quantum_node_clicked(grid_pos)
   ↓
3. farm.measure_plot(grid_pos)
   ↓
4. farm.plot_measured.emit(grid_pos, outcome) 📡
   ↓
5. PlotGridDisplay._on_farm_plot_measured(grid_pos, outcome)
   ↓
6. update_tile_from_farm(grid_pos)
   ↓
7. tile.set_plot_data(ui_data) [includes has_been_measured=true]
   ↓
8. PlotTile._update_visuals()
   ↓
9. Shows SINGLE emoji at full opacity ✅
```

### Actual Flow (What Was Happening Before Fix)

```
1. Player taps bubble
   ↓
2. FarmView._on_quantum_node_clicked(grid_pos)
   ↓
3. farm.measure_plot(grid_pos)
   ↓
4. farm.plot_measured.emit(grid_pos, outcome) 📡
   ↓
5. [NO CONNECTION - signal ignored!] ❌
   ↓
6. Plot tile NEVER UPDATES
   ↓
7. Tile still shows SUPERPOSITION (both emojis ghosted)
```

## The Fix

### File 1: UI/PlotGridDisplay.gd

**Added missing signal connection:**

```gdscript
// Line 355-358
if farm.has_signal("plot_measured"):
	if not farm.plot_measured.is_connected(_on_farm_plot_measured):
		farm.plot_measured.connect(_on_farm_plot_measured)
		print("   📡 Connected to farm.plot_measured")
```

**Added signal handler:**

```gdscript
// Line 555-558
func _on_farm_plot_measured(pos: Vector2i, outcome: String) -> void:
	"""Handle plot measured event from farm - update tile to show collapsed emoji"""
	print("👁️  Farm.plot_measured received at PlotGridDisplay: %s → %s" % [pos, outcome])
	update_tile_from_farm(pos)
```

## How It Works

### Visual States

**Before Measurement (Superposition):**
```
PlotUIData {
  has_been_measured: false
  north_emoji: "🌾"
  south_emoji: "👥"
  north_probability: 0.7
  south_probability: 0.3
}

Tile Display:
  🌾 (70% opacity)
  👥 (30% opacity)
  ← Both visible (ghosted)
```

**After Measurement (Collapsed):**
```
PlotUIData {
  has_been_measured: true
  north_emoji: "🌾"
  south_emoji: "👥"
  north_probability: 1.0  (or 0.0)
  south_probability: 0.0  (or 1.0)
}

Tile Display:
  🌾 (100% opacity)
  (south emoji hidden)
  ← Single solid emoji
```

### The Logic in PlotTile.gd

```gdscript
// UI/PlotTile.gd:325-341
func _show_mature_state():
	# ...
	if not plot_ui_data.has_been_measured:
		# SUPERPOSITION: Show both emojis with probability-weighted opacity
		emoji_label_north.text = plot_ui_data.north_emoji
		emoji_label_south.text = plot_ui_data.south_emoji
		emoji_label_north.modulate.a = plot_ui_data.north_probability
		emoji_label_south.modulate.a = plot_ui_data.south_probability
	else:
		# MEASURED: Show single dominant emoji at full opacity
		if plot_ui_data.north_probability > plot_ui_data.south_probability:
			emoji_label_north.text = plot_ui_data.north_emoji
			emoji_label_south.text = ""
		else:
			emoji_label_north.text = plot_ui_data.south_emoji
			emoji_label_south.text = ""
		emoji_label_north.modulate.a = 1.0
		emoji_label_south.modulate.a = 0.0
```

This logic was **already correct** - it just wasn't being triggered because the signal connection was missing!

## Verification

### Boot Log Shows Connection

```
   📡 Connected to farm.plot_planted
   📡 Connected to farm.plot_measured   ← NEW!
   📡 Connected to farm.plot_harvested
```

### Expected Console Output After Measurement

When player taps a bubble to measure:

```
🎯🎯🎯 BUBBLE TAP HANDLER CALLED! Grid pos: (0, 0), button: 0
   → Plot planted - MEASURING quantum state
👁️ Measured at (0, 0) -> 🌾
👁️  Farm.plot_measured received at PlotGridDisplay: (0, 0) → 🌾
   ✓ update_tile_from_farm((0, 0)): found plot, transforming data...
  🌾 PlotGridDisplay updating tile for plot (0, 0)
```

## Visual Effects

### Plot Tile Changes

1. **Before Measurement:**
   - Shows 2 ghosted emojis (e.g., 🌾 at 70%, 👥 at 30%)
   - Background has golden pulsing glow (mature state)
   - Border color depends on territory ownership

2. **After Measurement:**
   - Shows 1 solid emoji (e.g., 🌾 at 100%)
   - Background still has golden glow (still mature)
   - Border unchanged (territory ownership same)

### Additional Effects (Already Implemented)

The PlotTile also has these visual indicators that update correctly:

- **Purity indicator** (Tr(ρ²)) - color-coded quality metric
- **Entanglement ring** - shows if plot is entangled
- **Entanglement counter** - shows number of connections
- **Territory border** - shows Icon control (biotic/chaos/imperium)
- **Center state indicator** - quantum state visualization

All of these update via the same `update_tile_from_farm()` call, so they work correctly after measurement.

## Files Modified

1. **UI/PlotGridDisplay.gd**
   - Line 355-358: Added `plot_measured` signal connection
   - Line 555-558: Added `_on_farm_plot_measured()` handler

## Testing Checklist

### Manual Test: Measure Bubble → Plot Tile Updates

1. ✅ Start game
2. ✅ Plant wheat (tap empty bubble OR use keyboard P + Space)
3. ✅ Verify plot tile shows 2 ghosted emojis (superposition)
4. ✅ Tap the bubble to measure
5. ✅ Verify plot tile updates to show 1 solid emoji
6. ✅ Check console shows: `👁️  Farm.plot_measured received at PlotGridDisplay`

### Visual Regression Test

1. ✅ Plant wheat on plot (0, 0)
2. ✅ Before measurement:
   - Screenshot plot tile
   - Should see 🌾 (dim) + 👥 (dimmer)
3. ✅ Measure by tapping bubble
4. ✅ After measurement:
   - Screenshot plot tile
   - Should see 🌾 (solid) only
5. ✅ Compare screenshots - emoji should be brighter/more solid

## Architecture Notes

This fix maintains the **Phase 4 architecture** where PlotGridDisplay subscribes directly to Farm signals and updates in real-time, bypassing the FarmUIState layer for immediate visual feedback.

The signal flow is:
```
Farm (game logic)
  ↓ plot_measured signal
PlotGridDisplay (grid visualization)
  ↓ update_tile_from_farm()
PlotTile (individual tile display)
```

This is consistent with how `plot_planted` and `plot_harvested` already work.

## Impact

This fix ensures that **touch-based measurement** (tapping bubbles) has the same visual feedback as keyboard-based measurement. The plot tile will now correctly transition from showing quantum superposition to showing the collapsed/measured state.

**No changes needed to:**
- QuantumForceGraph (bubble visualization already updates correctly)
- Farm.gd (already emits signal)
- FarmGrid.gd (measurement logic unchanged)
- PlotTile.gd (visual display logic already correct)

Only needed to **connect the missing wire** between Farm and PlotGridDisplay.
