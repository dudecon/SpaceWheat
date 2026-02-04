# Bubble Rendering Debug Trace

## Aggressive Debug Output Added

I've added `print()` statements (not _verbose.debug) at every step of the bubble creation pipeline. These will ALWAYS show up in the console.

## What to Look For

Run the game, select a plot, and press `E` to explore. You should see this exact sequence:

### 1. Signal Emission from Farm
```
🚨🚨🚨 FARM EMITTING terminal_bound SIGNAL 🚨🚨🚨
  grid_pos: (0, 0)
  terminal_id: T_00
  emoji_pair: {north:🌲, south:🍂}
✅ Signal emitted!
```

### 2. Signal Reception in BathQuantumViz
```
======================================================================
🔔 TERMINAL_BOUND SIGNAL RECEIVED
  Position: (0, 0)
  Terminal ID: T_00
  Emojis: 🌲/🍂
  farm_ref: EXISTS
  graph: EXISTS
======================================================================
```

### 3. Biome Lookup
```
📍 Biome lookup for position (0, 0):
  plot_biome_assignments.get(): 'StarterForest'
  Total assignments: 12
  ✅ Found biome: StarterForest
```

OR if fallback needed:
```
📍 Biome lookup for position (0, 0):
  plot_biome_assignments.get(): ''
  Total assignments: 0
  ⚠️  Empty biome name, trying fallback...
  ✅ Using terminal's biome: StarterForest
```

### 4. Create Bubble Call
```
🎨 Calling _create_bubble_for_terminal...
  biome_name: StarterForest
  position: (0, 0)
  emojis: 🌲/🍂
  plot: EXISTS
  terminal: EXISTS
```

### 5. Bubble Creation
```
🏗️  _create_bubble_for_terminal ENTRY
  biome_name: StarterForest
  grid_pos: (0, 0)
  ✅ Passed all early exit checks
```

### 6. Bubble Tracking
```
  📊 Adding bubble to tracking structures...
    ✅ Added to basis_bubbles[StarterForest] (now 1 bubbles)
    ✅ Added to graph.quantum_nodes (now 1 total)
    ✅ Added to graph.quantum_nodes_by_grid_pos[(0, 0)]
```

### 7. Bubble Properties
```
✅ BUBBLE CREATED SUCCESSFULLY!
  Position: (480, 270)
  Visible: true
  Is selected: true
  Visual scale: 0.0
  Visual alpha: 0.0
  Radius: 40.0
  Biome: StarterForest
```

### 8. Graph Redraw
```
✅ Calling graph.queue_redraw()
======================================================================
```

## Diagnosis Based on Output

### If you see NOTHING:
**Problem**: `terminal_bound` signal is not being emitted at all
**Check**:
- Is `E` key actually triggering explore?
- Is `emit_action_signal` being called?
- Add `print("E KEY PRESSED")` in input handler

### If you see step 1 but NOT step 2:
**Problem**: Signal connection failed
**Look for**:
```
🔗 SIGNAL CONNECTION SUCCESS
  Connected BathQuantumViz._on_terminal_bound to farm.terminal_bound
```
If missing → BathQuantumViz.connect_to_farm() was never called or failed

### If you see step 2 but stops at "No farm reference":
**Problem**: `farm_ref` is null
**Fix**: BathQuantumViz.connect_to_farm() needs to be called with valid farm

### If you see "❌ EARLY EXIT: No biome assignment found":
**Problem**: Neither plot_biome_assignments nor terminal.bound_biome_name has the biome
**Check**:
- `plot_biome_assignments` dictionary contents
- Does terminal have `bound_biome_name` set?

### If you see "❌ EARLY EXIT: Unknown biome":
**Problem**: Biome not registered with BathQuantumViz
**Check**: Was biome added via `add_biome()`?

### If you see "✅ BUBBLE CREATED" with visible=false:
**Problem**: Plot not selected before exploring
**Fix**: Select plot first, THEN explore

### If you see everything but bubble doesn't render:
**Problem**: Rendering issue, not creation issue
**Check**:
- Is `visual_scale` and `visual_alpha` increasing over time?
- Is graph._draw() being called?
- Is QuantumBubbleRenderer checking `node.visible`?

## Quick Test

```bash
# Run and capture all debug output
godot 2>&1 | tee debug.log

# Then search for key markers:
grep "🚨🚨🚨 FARM" debug.log
grep "🔔 TERMINAL_BOUND" debug.log
grep "✅ BUBBLE CREATED" debug.log
```

If ANY of these are missing, we know exactly where the pipeline breaks!
