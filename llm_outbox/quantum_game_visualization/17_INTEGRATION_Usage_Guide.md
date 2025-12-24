# Simplified Quantum Glyph - Integration Usage Guide

**Quick Reference**: How to use the new simplified visualization in your game

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│          QuantumVisualizationController                  │
│  (Manages glyphs, selection, detail panel)              │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Glyphs Array[QuantumGlyph]                      │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐          │  │
│  │  │ Glyph 1 │  │ Glyph 2 │  │ Glyph 3 │  ...     │  │
│  │  │  🌾💧  │  │  🐰🌾  │  │  🐺🦅  │          │  │
│  │  │ + ring  │  │ + ring  │  │ + ring  │          │  │
│  │  └─────────┘  └─────────┘  └─────────┘          │  │
│  │                                                  │  │
│  │  Selected Glyph: Glyph 2 (highlighted)          │  │
│  │  ┌────────────────────────────────────────────┐ │  │
│  │  │          DetailPanel                       │ │  │
│  │  │  🐰 🌾                                      │ │  │
│  │  │  θ = 1.23 rad  φ = 0.45 rad               │ │  │
│  │  │  r = 0.87 (coherence)                     │ │  │
│  │  │  SUPERPOSITION: 🐰 78%  🌾 22%            │ │  │
│  │  │  CONNECTIONS: → (others)                  │ │  │
│  │  └────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## Basic Usage Example

### 1. Create and Initialize

```gdscript
# In your scene or game controller
var viz_controller: QuantumVisualizationController

func _ready() -> void:
    # Create visualization controller
    viz_controller = QuantumVisualizationController.new()
    add_child(viz_controller)

    # Connect to a biome (forest, field, ecosystem, etc.)
    var biome = get_biome_reference()
    viz_controller.connect_to_biome(biome)

    print("Visualization initialized with quantum states from biome")
```

### 2. The Controller Handles Everything

```gdscript
# The controller automatically:
# - Updates glyphs from biome quantum states each frame
# - Renders all glyphs with minimal visual encoding
# - Handles click selection for detail panel
# - Manages measurement mechanics (separate from UI interaction)

# No manual update loop needed - controller handles it via _process()
```

### 3. Trigger Measurement (Game Mechanic)

```gdscript
# When player harvests, builds, or takes explicit game action
func harvest_crop(grid_position: Vector2i) -> void:
    # Some game logic here...

    # Collapse quantum state (separate from inspection)
    var outcome = "north" if randf() > 0.5 else "south"
    viz_controller.apply_measurement(grid_position, outcome)

    # The glyph now shows:
    # - Single emoji at 100% opacity
    # - Frozen phase ring (no animation)
    # - Detail panel shows "Measured: Yes"
```

### 4. Manual Selection (UI, Not Game Logic)

```gdscript
# User clicks on glyph in visualization
# The controller automatically:
# 1. Detects click via _input()
# 2. Finds glyph at position
# 3. Sets selected_glyph
# 4. Triggers queue_redraw() to show detail panel
# 5. NO state change occurs (measurement is separate)

# If you need to deselect programmatically:
viz_controller.deselect()
```

---

## Integration with Biomes

### What the Controller Expects

**Biome Requirements**:
```gdscript
# Your biome must have:
class_name MyBiome
extends Node

# 1. Dictionary of quantum states keyed by grid position
var quantum_states: Dictionary = {}  # Vector2i -> DualEmojiQubit

# 2. Optional: Grid reference for checking measured status
var grid: FarmGrid = null

# Usage:
func _ready() -> void:
    # Populate quantum_states with DualEmojiQubit objects
    quantum_states[Vector2i(0, 0)] = DualEmojiQubit.new()
    quantum_states[Vector2i(1, 0)] = DualEmojiQubit.new()
    # ... etc
```

### Example: Forest Biome Integration

```gdscript
# In ForestEcosystem_Biome.gd or similar
func _ready() -> void:
    # Your existing setup...
    _initialize_quantum_field()

    # Create visualization
    var viz = QuantumVisualizationController.new()
    add_child(viz)
    viz.connect_to_biome(self)

func _initialize_quantum_field() -> void:
    # Your existing initialization...
    for x in range(-5, 5):
        for y in range(-5, 5):
            var pos = Vector2i(x, y)
            var qubit = DualEmojiQubit.new()
            qubit.north_emoji = "🌾"  # Plant
            qubit.south_emoji = "💧"  # Water
            qubit.theta = randf_range(0, PI)
            qubit.phi = randf_range(0, TAU)
            quantum_states[pos] = qubit
```

---

## Visual Encoding Reference

### Base Glyph (Always Visible)

```
North emoji opacity = cos²(θ/2)
South emoji opacity = sin²(θ/2)
Phase ring hue = φ (cycles continuously for unmeasured states)
Phase ring animation = disabled when is_measured = true
```

**What Players See**:
- Both emojis fading in/out = superposition (quantum!)
- Ring colors rotating = phase evolution
- One emoji solid = measured/classical state
- Frozen ring = measured (no more evolution)

### Detail Panel (Appears on Click)

**Sections**:
1. **State Metrics**: θ, φ, coherence, measurement status, energy
2. **Superposition**: Visual probability bars for each outcome
3. **Connections**: List of entangled/coupled qubits
4. (TODO) **Environment**: Temperature, BioticFlux, decoherence rate
5. (TODO) **Bloch Sphere**: 3D state visualization

---

## Measurement Mechanic (Separate from Selection)

### The Key Distinction

```gdscript
# ❌ WRONG: Don't collapse on selection
func _on_glyph_clicked(glyph: QuantumGlyph) -> void:
    # This just shows details - no state change!
    selected_glyph = glyph
    # ❌ DON'T DO: glyph.apply_measurement("north")
    # That's not what selection means!

# ✅ RIGHT: Collapse on explicit game action
func harvest_crop(grid_pos: Vector2i) -> void:
    # Player takes action that physically affects the system
    var outcome = perform_harvest_logic(grid_pos)

    # NOW collapse the quantum state
    viz_controller.apply_measurement(grid_pos, outcome)

    # The glyph shows the measured result
```

### Game Actions That Trigger Measurement

- **Harvest**: Crop measurement yields water/soil/energy
- **Build**: Construction measurement collapses field state
- **Breed**: Creature measurement selects phenotype
- **Observe**: Explicit "take measurement" action in quantum labs

---

## Customization Points

### Modify Visual Encoding

Edit `QuantumGlyph.gd` to change appearance:

```gdscript
# Adjust ring thickness
const RING_THICKNESS: float = 3.0  # Change to 5.0 for thicker ring

# Adjust emoji size
const EMOJI_OFFSET: float = 20.0  # Change to 25.0 to space further apart

# Adjust animation speed
ring_color = Color.from_hsv(
    fmod(phase_hue + time_accumulated * 0.05, 1.0),  # 0.05 = speed
    0.7, 0.85, 0.8
)
```

### Add New Detail Panel Sections

Edit `DetailPanel.gd` to show more information:

```gdscript
# Add environment section
canvas.draw_string(font, panel_position + Vector2(15, y), "ENVIRONMENT:",
    HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 1.0, 0.8))
y += line_height

var env_text = "Temperature: %dK" % glyph.qubit.temperature
canvas.draw_string(font, panel_position + Vector2(25, y), env_text,
    HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8))
y += line_height
```

### Add Particle Effects

Extend `apply_measurement()` in QuantumGlyph:

```gdscript
func apply_measurement(outcome: String) -> void:
    is_measured = true

    if outcome == "north":
        qubit.theta = 0.0
    else:
        qubit.theta = PI

    # Add visual feedback
    if has_node("/root/ParticleEffects"):
        var particles = get_node("/root/ParticleEffects")
        particles.spawn_measurement_flash(position, outcome)
```

---

## Performance Notes

### Scalability

```
Number of Glyphs | FPS Impact | Click Detection | Notes
─────────────────┼────────────┼─────────────────┼──────────────────
1-10             | <1% impact | O(n) trivial    | No optimization needed
10-50            | 1-2% impact | Still fine      | Normal gameplay
50-100           | 3-5% impact | Start batching? | Consider spatial hash
100+             | >5% impact  | Use quadtree    | Optimize click detection
```

**Current Implementation**: O(n) click detection, optimized for ~10-20 glyphs typical in biome view.

**If needed**: Replace simple loop with spatial hash:
```gdscript
# TODO for future: Add spatial partitioning
# var glyph_grid: Dictionary = {}  # Spatial hash of glyphs
```

---

## Testing Checklist

- [ ] Glyphs render without errors (emoji + ring visible)
- [ ] Phase ring animates (hue rotation continuous)
- [ ] Emoji opacity changes with theta (superposition visible)
- [ ] Click selection works (glyph highlights, detail panel appears)
- [ ] Detail panel displays correct metrics
- [ ] Measurement collapses state (emoji freezes, ring animation stops)
- [ ] Multiple glyphs update independently
- [ ] Integration with actual biome data works

---

## Common Issues & Solutions

### Issue: Detail panel doesn't appear on click
**Solution**: Ensure `mouse_filter = MOUSE_FILTER_STOP` on the controller

### Issue: Glyphs don't update from biome
**Solution**: Verify biome has `quantum_states` dictionary with `Vector2i` keys

### Issue: Phase ring doesn't animate
**Solution**: Check that `is_measured` is false and `_process()` is being called

### Issue: Emoji look too small
**Solution**: Adjust `EMOJI_OFFSET` in QuantumGlyph.gd (increase value = spread further)

### Issue: Performance degrades with many glyphs
**Solution**: Implement spatial hashing for click detection or reduce glyph count

---

## Next Steps

1. **Test**: Run `QuantumGlyphTest.gd` to verify implementation
2. **Integrate**: Connect to actual biome data (Forest, Market, etc.)
3. **Polish**: Add particle effects, field backgrounds
4. **Enhance**: Implement Bloch sphere, semantic edges, topological overlays
5. **Measure**: Profile performance with real biome data

---

**Status**: Ready for integration! 🌾⚛️✨
