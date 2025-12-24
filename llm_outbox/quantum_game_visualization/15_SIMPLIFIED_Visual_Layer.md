# Quantum Force Graph - Simplified Visual Layer

**Core Principle**: Base visualization is minimal and intuitive. Full complexity only appears on selection.

---

## Part 1: Base Glyph (Always Visible)

### Minimal Encoding

Each node shows only 3 data channels:

```
        ╭─────────╮
        │ 🌾 0.8  │  ← North emoji, opacity = cos²(θ/2)
        │ ╭─────╮ │
        │ │  ◎  │ │  ← Phase ring (hue = φ, animated)
        │ ╰─────╯ │
        │ 💧 0.2  │  ← South emoji, opacity = sin²(θ/2)
        ╰─────────╯
```

**What players naturally learn:**
- Emoji fading in/out = state changing
- Ring colors cycling = quantum phase evolving
- Both emojis visible = superposition (cool!)
- One emoji solid = measured (classical)

### Implementation: Minimal QuantumGlyph

```gdscript
class_name QuantumGlyph
extends RefCounted

## Renders quantum state as dual emoji + phase ring (minimal)

var qubit: DualEmojiQubit = null
var position: Vector2 = Vector2.ZERO
var is_measured: bool = false

# Animation state
var time_accumulated: float = 0.0

# Visual constants
const BASE_RADIUS: float = 25.0
const EMOJI_OFFSET: float = 20.0
const RING_THICKNESS: float = 3.0


func update_from_qubit(dt: float) -> void:
    """Sync visual state from quantum data"""
    if not qubit:
        return
    time_accumulated += dt


func draw(canvas: CanvasItem, emoji_font: Font) -> void:
    """Render minimal glyph"""

    var theta = qubit.theta
    var phi = qubit.phi
    var north_opacity = pow(cos(theta / 2.0), 2.0)
    var south_opacity = pow(sin(theta / 2.0), 2.0)

    # Measured state: snap to 0 or 1
    if is_measured:
        north_opacity = 1.0 if north_opacity > 0.5 else 0.0
        south_opacity = 1.0 - north_opacity

    # === PHASE RING (hue cycles with phi) ===
    var phase_hue = fmod((phi + PI) / TAU, 1.0)
    var ring_color = Color.from_hsv(phase_hue, 0.7, 0.85, 0.8)

    # Animate hue for unmeasured qubits
    if not is_measured:
        ring_color = Color.from_hsv(
            fmod(phase_hue + time_accumulated * 0.05, 1.0),
            0.7, 0.85, 0.8
        )

    canvas.draw_arc(position, BASE_RADIUS, 0, TAU, 32, ring_color, RING_THICKNESS)

    # === NORTH EMOJI ===
    if north_opacity > 0.05:
        var north_color = Color(1, 1, 1, north_opacity)
        canvas.draw_string(emoji_font,
            position + Vector2(0, -EMOJI_OFFSET),
            qubit.north_emoji,
            HORIZONTAL_ALIGNMENT_CENTER, -1, 20, north_color)

    # === SOUTH EMOJI ===
    if south_opacity > 0.05:
        var south_color = Color(1, 1, 1, south_opacity)
        canvas.draw_string(emoji_font,
            position + Vector2(0, EMOJI_OFFSET),
            qubit.south_emoji,
            HORIZONTAL_ALIGNMENT_CENTER, -1, 20, south_color)
```

---

## Part 2: Semantic Edges (Visible When Needed)

Simple lines showing relationships (coupling):

```
    NODE A                          NODE B
      ●━━━━━━━━━━━━━━━━━━━━━━━━━━━●
      │                             │
      Edge color = relationship     │
      Edge width = coupling strength
      Subtle glow if active interaction
```

No relationship emojis yet. Just colors:
- Red = predation
- Green = feeding
- Blue = production
- Purple = transformation

Particles flow along edges when interaction is strong (√(Nᵢ Nⱼ) > threshold).

---

## Part 3: Selection Detail Panel

**ONLY when selected**, show comprehensive information:

```
┌─────────────────────────────────────┐
│ 🌾 WHEAT (3, 5)                     │
├─────────────────────────────────────┤
│ STATE METRICS:                      │
│  θ = 1.23 rad (polar angle)         │
│  φ = 0.45 rad (azimuthal angle)     │
│  r = 0.87 (coherence/radius)        │
│  Measured: No (superposition)       │
│  Energy: 0.45 J                     │
├─────────────────────────────────────┤
│ SUPERPOSITION:                      │
│  🌾 (north)  ████████░░  78%        │
│  💧 (south)  ██░░░░░░░░  22%        │
├─────────────────────────────────────┤
│ CONNECTIONS:                        │
│  → 🐰 (herbivore) [0.15 strength]   │
│  ← 🌍 (soil) [0.08 strength]        │
│  ↔ 🍄 (fungi) [entangled]           │
├─────────────────────────────────────┤
│ ENVIRONMENT:                        │
│  Temperature: 312K                  │
│  BioticFlux: +15% growth mod        │
│  Coherence loss: 2%/s               │
├─────────────────────────────────────┤
│ [Bloch Sphere Display - TODO]       │
└─────────────────────────────────────┘
```

**Implementation: DetailPanel Class**

```gdscript
class_name DetailPanel
extends RefCounted

## Shows full quantum state info when glyph selected

var selected_glyph: QuantumGlyph = null
var panel_position: Vector2 = Vector2.ZERO
var panel_size: Vector2 = Vector2(350, 400)


func draw(canvas: CanvasItem, glyph: QuantumGlyph, font: Font) -> void:
    """Render detail panel for selected glyph"""

    if not glyph or not glyph.qubit:
        return

    # Panel background
    var bg_color = Color(0.1, 0.1, 0.15, 0.95)
    canvas.draw_rect(Rect2(panel_position, panel_size), bg_color)

    # Panel border
    var border_color = Color(0.8, 0.8, 0.9, 0.8)
    canvas.draw_rect(Rect2(panel_position, panel_size), Color.TRANSPARENT,
        false, 2.0, border_color)

    # Title
    var title = "%s (%s)" % [glyph.qubit.north_emoji, glyph.qubit.south_emoji]
    canvas.draw_string(font, panel_position + Vector2(15, 20), title,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

    var y = 50
    var line_height = 20

    # === STATE METRICS ===
    var metrics_text = [
        "θ = %.2f rad" % glyph.qubit.theta,
        "φ = %.2f rad" % glyph.qubit.phi,
        "r = %.2f (coherence)" % glyph.qubit.get_coherence(),
        "Measured: %s" % ("Yes" if glyph.is_measured else "No"),
        "Energy: %.2f J" % glyph.qubit.energy,
    ]

    for text in metrics_text:
        canvas.draw_string(font, panel_position + Vector2(15, y), text,
            HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.8))
        y += line_height

    y += 10

    # === SUPERPOSITION ===
    var north_prob = pow(cos(glyph.qubit.theta / 2.0), 2.0)
    var south_prob = 1.0 - north_prob

    canvas.draw_string(font, panel_position + Vector2(15, y), "SUPERPOSITION:",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 1.0, 0.8))
    y += line_height

    # North bar
    canvas.draw_string(font, panel_position + Vector2(25, y),
        "%s %.0f%%" % [glyph.qubit.north_emoji, north_prob * 100],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
    _draw_probability_bar(canvas, panel_position + Vector2(70, y - 5),
        200, north_prob, Color(0.3, 0.8, 0.3))
    y += line_height

    # South bar
    canvas.draw_string(font, panel_position + Vector2(25, y),
        "%s %.0f%%" % [glyph.qubit.south_emoji, south_prob * 100],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
    _draw_probability_bar(canvas, panel_position + Vector2(70, y - 5),
        200, south_prob, Color(0.3, 0.6, 0.9))
    y += line_height * 2

    # === CONNECTIONS (if available) ===
    if glyph.qubit and glyph.qubit.entanglement_graph.size() > 0:
        canvas.draw_string(font, panel_position + Vector2(15, y), "CONNECTIONS:",
            HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 1.0, 0.8))
        y += line_height

        for relationship in glyph.qubit.entanglement_graph.keys():
            var targets = glyph.qubit.entanglement_graph[relationship]
            var strength = glyph.qubit.get_coupling_strength(relationship)

            var conn_text = "%s → %s [%.2f]" % [relationship, targets[0], strength]
            canvas.draw_string(font, panel_position + Vector2(25, y), conn_text,
                HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.9, 0.7))
            y += line_height - 2


func _draw_probability_bar(canvas: CanvasItem, pos: Vector2,
        width: float, fill: float, color: Color) -> void:
    """Draw probability bar"""
    # Background
    canvas.draw_rect(Rect2(pos, Vector2(width, 10)),
        Color(0.2, 0.2, 0.2, 0.5))
    # Fill
    canvas.draw_rect(Rect2(pos, Vector2(width * fill, 10)), color)
```

---

## Part 4: Game Mechanics - Measurement (Separate)

**Measurement is NOT selection.** Measurement happens when:
- Player harvests a crop
- Player builds on a farm plot
- Some game action explicitly "measures" the quantum state
- Wavefunction collapses to definite outcome

When measured, the glyph:
- Snaps to single emoji (100% opacity on outcome)
- Phase ring freezes (no more animation)
- Shows measured state in detail panel

```gdscript
func apply_measurement(outcome: String) -> void:
    """Apply measurement result to glyph"""
    is_measured = true

    # Collapse to outcome
    if outcome == "north":
        qubit.theta = 0.0  # Snap to north pole
    else:
        qubit.theta = PI   # Snap to south pole

    # Could emit particle effect here
    # particles.spawn_measurement_flash(position, outcome_color)
```

---

## Part 5: Simplified Integration

```gdscript
class_name QuantumVisualizationController
extends Control

## Main controller - simplified for base version

var glyphs: Array[QuantumGlyph] = []
var edges: Array[SemanticEdge] = []
var detail_panel: DetailPanel = null
var selected_glyph: QuantumGlyph = null

var emoji_font: Font = null


func _ready() -> void:
    emoji_font = load("res://Assets/Fonts/NotoColorEmoji.ttf")
    detail_panel = DetailPanel.new()
    mouse_filter = Control.MOUSE_FILTER_STOP


func connect_to_biome(biome_ref) -> void:
    """Connect to biome and build glyphs from quantum states"""
    glyphs.clear()
    edges.clear()

    if not biome:
        return

    # Create glyph for each quantum state
    for position in biome.quantum_states.keys():
        var qubit = biome.quantum_states[position]
        if not qubit:
            continue

        var glyph = QuantumGlyph.new()
        glyph.qubit = qubit
        glyph.position = _grid_to_screen(position)

        # Check if measured
        if biome.grid:
            var plot = biome.grid.get_plot(position)
            if plot:
                glyph.is_measured = plot.has_been_measured

        glyphs.append(glyph)

    # Create edges from coupling graph
    _rebuild_edges()


func _rebuild_edges() -> void:
    """Build edges from entanglement/coupling relationships"""
    edges.clear()

    for i in range(glyphs.size()):
        for j in range(i + 1, glyphs.size()):
            var glyph_a = glyphs[i]
            var glyph_b = glyphs[j]

            if not glyph_a.qubit or not glyph_b.qubit:
                continue

            # Check if entangled or coupled
            var coupling = _get_coupling_strength(glyph_a.qubit, glyph_b.qubit)
            if coupling > 0.05:  # Only show significant couplings
                var edge = SemanticEdge.new()
                edge.from_node = glyph_a
                edge.to_node = glyph_b
                edge.coupling_strength = coupling
                edges.append(edge)


func _process(delta: float) -> void:
    # Update glyphs
    for glyph in glyphs:
        glyph.update_from_qubit(delta)

    # Update edges
    for edge in edges:
        if edge.from_node and edge.to_node:
            edge.update(delta, edge.from_node.qubit, edge.to_node.qubit)

    queue_redraw()


func _draw() -> void:
    # Draw edges first (background)
    for edge in edges:
        edge.draw(self, emoji_font)

    # Draw glyphs
    for glyph in glyphs:
        glyph.draw(self, emoji_font)

    # Selection highlight
    if selected_glyph:
        draw_arc(selected_glyph.position, 35, 0, TAU, 32,
            Color(1.0, 0.8, 0.2, 0.8), 2.0)

    # Detail panel (only if selected)
    if selected_glyph:
        detail_panel.draw(self, selected_glyph, emoji_font)


func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            var clicked = _get_glyph_at(event.position)
            selected_glyph = clicked
            queue_redraw()


func _get_glyph_at(pos: Vector2) -> QuantumGlyph:
    for glyph in glyphs:
        if pos.distance_to(glyph.position) < 30:
            return glyph
    return null


func _grid_to_screen(grid_pos: Vector2i) -> Vector2:
    var center = get_viewport_rect().size / 2.0
    var spacing = 100.0
    return center + Vector2(grid_pos.x * spacing, grid_pos.y * spacing)


func _get_coupling_strength(qubit_a: DualEmojiQubit, qubit_b: DualEmojiQubit) -> float:
    """Calculate coupling strength between two qubits"""
    # TODO: Get from Hamiltonian or biome
    return 0.0
```

---

## TODO Items (Future Enhancements)

- [ ] Bloch sphere visualization in detail panel
- [ ] Berry phase bar in detail panel
- [ ] Particle effects (energy flow, decoherence dust, growth sparks)
- [ ] Field background (temperature gradient, Icon zones, coherence grid)
- [ ] Semantic relationship emojis on edges
- [ ] Connection strength visualization
- [ ] Measurement animation/flash effect
- [ ] Topological campaign overlays (strange attractors, braid patterns)

---

## Design Philosophy

**Start minimal. Learn through play.**

Players don't need to understand θ, φ, radius to enjoy watching emojis fade in and out. They don't need to know about coherence to notice when the ring stops animating.

As they play, patterns emerge naturally:
- "When the plant emoji is bright, I get more water"
- "When both emojis are visible, something weird happens"
- "When I harvest, the emoji stops changing"

Only when they click for details do they see the full quantum picture. That's when the Bloch sphere, probability bars, and connection list become meaningful.

**Complexity emerges from clarity, not the reverse.**
