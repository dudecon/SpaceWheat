# Quantum Force Graph Visual Layer
## A Design Document for Rendering the Invisible

*"The goal is not to show everything. The goal is to make quantum mechanics feel alive."*

---

## Vision Statement

Players should look at the visualization and feel:
1. **Wonder** — "This is beautiful and I don't fully understand why"
2. **Intuition** — "I can sense when something is healthy or sick"
3. **Agency** — "My actions ripple through this living system"
4. **Discovery** — "There's always more to learn by watching closely"

The visualization is not a dashboard. It's a **quantum aquarium** — a living window into an ecosystem where the rules are strange but learnable.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    RENDERING LAYERS                              │
├─────────────────────────────────────────────────────────────────┤
│  Layer 5: UI Overlay        │ Selection, tooltips, metrics      │
│  Layer 4: Particle Effects  │ Flow particles, decoherence dust  │
│  Layer 3: Edges (Semantic)  │ Relationship emojis, coupling     │
│  Layer 2: Nodes (Glyphs)    │ Compound quantum state display    │
│  Layer 1: Field Background  │ Temperature gradients, Icon auras │
│  Layer 0: Grid Reference    │ Subtle classical anchor points    │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │
┌─────────────────────────────┴───────────────────────────────────┐
│                    DATA SOURCES                                  │
├─────────────────────────────────────────────────────────────────┤
│  Biome.quantum_states{}     │ Position → DualEmojiQubit         │
│  Biome.sun_qubit            │ Celestial driver (θ cycles)       │
│  Biome.temperature_grid{}   │ Position → Kelvin                 │
│  DualEmojiQubit.entanglement_graph{} │ Relationship topology    │
│  Icon.active_strength       │ Environmental modulation          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Part 1: The Quantum Glyph System

### 1.1 Philosophy

Every node is a **compound glyph** — not a simple circle, but a mini-visualization encoding multiple quantum variables simultaneously. Players learn to read glyphs like they learn to read faces: intuitively, without conscious analysis.

### 1.2 Glyph Anatomy

```
                    ╭─────────────╮
                    │   🌾 NORTH  │  ← North emoji (opacity = cos²(θ/2))
                    │             │
        Phase Ring →│ ╭─────────╮ │← Outer ring color = φ (hue)
                    │ │         │ │   Ring thickness = coherence (radius)
                    │ │  CORE   │ │← Core gradient: θ-weighted blend
                    │ │         │ │   between north and south colors
                    │ ╰─────────╯ │
                    │             │
                    │   💧 SOUTH  │  ← South emoji (opacity = sin²(θ/2))
                    ╰─────────────╯
                          │
                    ══════════════  ← Berry phase bar (accumulated evolution)
                    ░░░░░░████████     Fills left-to-right as qubit evolves
```

### 1.3 Glyph Data Encoding

| Visual Element | Quantum Variable | Range | Interpretation |
|----------------|------------------|-------|----------------|
| **North emoji opacity** | cos²(θ/2) | 0.0–1.0 | Probability of north pole outcome |
| **South emoji opacity** | sin²(θ/2) | 0.0–1.0 | Probability of south pole outcome |
| **Core gradient** | θ | 0–π | Vertical gradient from north→south color |
| **Phase ring hue** | φ | 0–2π | HSV hue (0=red, 0.33=green, 0.67=blue) |
| **Phase ring thickness** | radius (coherence) | 0.0–1.0 | Thicker = more coherent |
| **Berry phase bar** | berry_phase | 0.0–∞ | Evolution history (experience points) |
| **Glow intensity** | energy | 0.0–1.0 | Brighter = more energy |
| **Pulse rate** | 1.0 - coherence | 0.2–2.0 Hz | Faster = more decoherence threat |

### 1.4 Glyph States

**Unmeasured (Superposition)**
```
        ╭───────────╮
        │   🌾 0.7  │  ← 70% opacity
        │ ╭───────╮ │
        │ │▓▓▓▒▒▒│ │  ← Gradient shows superposition
        │ ╰───────╯ │
        │   💧 0.3  │  ← 30% opacity
        ╰───────────╯
        ═══════░░░░░   ← Berry phase accumulating
```
- Both emojis visible with probability-weighted opacity
- Core shows gradient between states
- Phase ring animates (hue cycling with φ evolution)
- Subtle pulse indicating quantum uncertainty

**Measured (Collapsed)**
```
        ╭───────────╮
        │   🌾 1.0  │  ← 100% opacity (collapsed to north)
        │ ╭───────╮ │
        │ │███████│ │  ← Solid color (no gradient)
        │ ╰───────╯ │
        │   💧 0.0  │  ← 0% opacity (hidden)
        ╰───────────╯
        ═══════════    ← Berry phase frozen
```
- Single emoji at full opacity
- Solid core color (no superposition gradient)
- Phase ring frozen (no animation)
- No pulse (classical definite state)

**Low Coherence (Decohering)**
```
        ╭ ─ ─ ─ ─ ─ ╮
        │   🌾 ???  │  ← Flickering opacity
        │ ╭ ─ ─ ─ ╮ │
        │ │ ░ ░ ░ │ │  ← Faded, noisy core
        │ ╰ ─ ─ ─ ╯ │  ← Thin, broken ring
        │   💧 ???  │
        ╰ ─ ─ ─ ─ ─ ╯
            ░░░░░      ← Berry phase static/degrading
```
- Emojis flicker (opacity noise)
- Core faded and noisy
- Phase ring thin and dashed
- Fast pulse (decoherence warning)
- Particle effects: "decoherence dust" drifting away

### 1.5 Implementation: QuantumGlyph Class

```gdscript
class_name QuantumGlyph
extends RefCounted

## Renders a single quantum state as a compound visual glyph

# Data source
var qubit: DualEmojiQubit = null
var position: Vector2 = Vector2.ZERO
var is_measured: bool = false

# Visual state (updated each frame)
var north_opacity: float = 0.5
var south_opacity: float = 0.5
var core_gradient_top: Color = Color.WHITE
var core_gradient_bottom: Color = Color.WHITE
var phase_hue: float = 0.0
var ring_thickness: float = 4.0
var berry_bar_fill: float = 0.0
var glow_intensity: float = 0.0
var pulse_phase: float = 0.0

# Animation
var pulse_rate: float = 1.0  # Hz
var time_accumulated: float = 0.0

# Size constants
const BASE_RADIUS: float = 30.0
const EMOJI_OFFSET: float = 25.0
const RING_MAX_THICKNESS: float = 8.0
const BERRY_BAR_WIDTH: float = 50.0
const BERRY_BAR_HEIGHT: float = 6.0


func update_from_qubit(dt: float) -> void:
    """Sync visual state from quantum data"""
    if not qubit:
        return
    
    time_accumulated += dt
    
    # === EMOJI OPACITY (Born rule probabilities) ===
    var theta = qubit.theta
    north_opacity = pow(cos(theta / 2.0), 2.0)
    south_opacity = pow(sin(theta / 2.0), 2.0)
    
    # Measured qubits: snap to 0 or 1
    if is_measured:
        if north_opacity > 0.5:
            north_opacity = 1.0
            south_opacity = 0.0
        else:
            north_opacity = 0.0
            south_opacity = 1.0
    
    # === PHASE HUE (azimuthal angle) ===
    phase_hue = fmod((qubit.phi + PI) / TAU, 1.0)
    
    # === RING THICKNESS (coherence) ===
    var coherence = qubit.get_coherence()
    ring_thickness = coherence * RING_MAX_THICKNESS
    
    # === BERRY PHASE BAR ===
    berry_bar_fill = qubit.get_berry_phase_normalized()
    
    # === GLOW INTENSITY (energy) ===
    glow_intensity = qubit.energy
    
    # === PULSE RATE (decoherence threat) ===
    pulse_rate = 0.2 + (1.0 - coherence) * 1.8  # 0.2 Hz (stable) to 2.0 Hz (chaotic)
    pulse_phase = sin(time_accumulated * pulse_rate * TAU) * 0.5 + 0.5
    
    # === CORE GRADIENT COLORS ===
    # North color: Warm (yellow-green for wheat, etc.)
    # South color: Cool (blue-purple for night/decay, etc.)
    core_gradient_top = _get_emoji_color(qubit.north_emoji)
    core_gradient_bottom = _get_emoji_color(qubit.south_emoji)


func draw(canvas: CanvasItem, font: Font) -> void:
    """Render the glyph to canvas"""
    
    # === LAYER 1: GLOW (behind everything) ===
    if glow_intensity > 0.1:
        var glow_color = Color(1.0, 0.9, 0.5, glow_intensity * 0.3)
        var glow_radius = BASE_RADIUS * (1.5 + glow_intensity * 0.5)
        canvas.draw_circle(position, glow_radius, glow_color)
    
    # === LAYER 2: PHASE RING ===
    var ring_color = Color.from_hsv(phase_hue, 0.8, 0.9, 0.9)
    if not is_measured:
        # Animate ring hue for unmeasured qubits
        ring_color = Color.from_hsv(
            fmod(phase_hue + time_accumulated * 0.1, 1.0),
            0.8, 0.9, 0.9
        )
    var ring_radius = BASE_RADIUS + ring_thickness / 2.0
    canvas.draw_arc(position, ring_radius, 0, TAU, 64, ring_color, ring_thickness)
    
    # === LAYER 3: CORE (gradient circle) ===
    _draw_gradient_circle(canvas, position, BASE_RADIUS,
        core_gradient_top, core_gradient_bottom, north_opacity, south_opacity)
    
    # === LAYER 4: EMOJIS ===
    var north_pos = position + Vector2(0, -EMOJI_OFFSET)
    var south_pos = position + Vector2(0, EMOJI_OFFSET)
    
    # North emoji
    if north_opacity > 0.05:
        var north_color = Color(1, 1, 1, north_opacity)
        canvas.draw_string(font, north_pos, qubit.north_emoji,
            HORIZONTAL_ALIGNMENT_CENTER, -1, 24, north_color)
    
    # South emoji
    if south_opacity > 0.05:
        var south_color = Color(1, 1, 1, south_opacity)
        canvas.draw_string(font, south_pos, qubit.south_emoji,
            HORIZONTAL_ALIGNMENT_CENTER, -1, 24, south_color)
    
    # === LAYER 5: BERRY PHASE BAR ===
    var bar_pos = position + Vector2(-BERRY_BAR_WIDTH / 2.0, BASE_RADIUS + 15)
    _draw_berry_bar(canvas, bar_pos)
    
    # === LAYER 6: PULSE OVERLAY (decoherence warning) ===
    if pulse_rate > 0.5 and not is_measured:
        var pulse_alpha = pulse_phase * 0.2 * (pulse_rate / 2.0)
        var pulse_color = Color(1.0, 0.3, 0.3, pulse_alpha)
        canvas.draw_circle(position, BASE_RADIUS * 1.1, pulse_color)


func _draw_gradient_circle(canvas: CanvasItem, pos: Vector2, radius: float,
        top_color: Color, bottom_color: Color, top_weight: float, bottom_weight: float) -> void:
    """Draw a circle with vertical gradient based on superposition weights"""
    # Simplified: draw as blend of two colors
    # Full implementation would use shader or multiple arc segments
    var blend = bottom_weight / (top_weight + bottom_weight + 0.001)
    var blended_color = top_color.lerp(bottom_color, blend)
    canvas.draw_circle(pos, radius, blended_color)


func _draw_berry_bar(canvas: CanvasItem, pos: Vector2) -> void:
    """Draw berry phase accumulation bar"""
    # Background
    canvas.draw_rect(Rect2(pos, Vector2(BERRY_BAR_WIDTH, BERRY_BAR_HEIGHT)),
        Color(0.2, 0.2, 0.2, 0.5))
    
    # Fill
    var fill_width = BERRY_BAR_WIDTH * berry_bar_fill
    var fill_color = Color(0.3, 0.8, 0.3, 0.8)  # Green for accumulated experience
    canvas.draw_rect(Rect2(pos, Vector2(fill_width, BERRY_BAR_HEIGHT)), fill_color)


func _get_emoji_color(emoji: String) -> Color:
    """Map emoji to representative color for gradient"""
    match emoji:
        "🌾", "🌿", "🌱": return Color(0.6, 0.8, 0.3)  # Green-gold (plants)
        "☀️": return Color(1.0, 0.9, 0.3)  # Bright yellow
        "🌙": return Color(0.3, 0.3, 0.6)  # Deep blue-purple
        "🍄": return Color(0.6, 0.4, 0.7)  # Purple (fungi)
        "💧": return Color(0.3, 0.6, 0.9)  # Blue (water)
        "🐰", "🐺", "🦅": return Color(0.8, 0.6, 0.4)  # Warm brown (animals)
        "👥": return Color(0.9, 0.7, 0.5)  # Skin tone (labor)
        "🏰": return Color(0.5, 0.5, 0.5)  # Gray (imperium)
        _: return Color(0.7, 0.7, 0.7)  # Default gray
```

---

## Part 2: The Semantic Edge System

### 2.1 Philosophy

Edges are not just lines. They are **semantic channels** — visible representations of how quantum states influence each other. The relationship emoji language from `DualEmojiQubit.entanglement_graph` becomes visible.

### 2.2 Edge Types (from entanglement_graph)

| Relationship Emoji | Meaning | Visual Style |
|-------------------|---------|--------------|
| 🍴 | Predation (A hunts B) | Red, sharp arrows, pulse on interaction |
| 🃏 | Escape (A flees B) | Dashed, fast animation away from predator |
| 🌱 | Consumption (A feeds on B) | Green, flowing toward consumer |
| 💧 | Production (A produces B) | Blue, droplet particles flowing |
| 🔄 | Transformation (A→B Markov) | Purple, bidirectional shimmer |
| ⚡ | Coherence strike (θ alignment) | Yellow-white, bright flash on alignment |
| 👶 | Reproduction (A spawns B) | Pink, expanding rings |

### 2.3 Edge Visual Encoding

```
     NODE A                              NODE B
       ●━━━━━━━━━━━🍴━━━━━━━━━━━━━━━━━━━━▶●
           │                               │
    Edge color = relationship type         │
    Edge width = coupling strength gᵢⱼ     │
    Particle flow = current interaction √(Nᵢ×Nⱼ)
    Arrow direction = asymmetric relationship
    Pulse = active energy transfer
    Relationship emoji = semantic label (centered on edge)
```

### 2.4 Edge Animation States

**Dormant** (weak coupling, no active transfer)
```
    ●─ ─ ─ ─ ─🍴─ ─ ─ ─ ─●
    Thin, dashed, low opacity
    No particles
```

**Active** (strong coupling, energy flowing)
```
    ●━━━━●━━●━🍴━●━━●━━━━●
    Thick, solid, bright
    Particles flow from source to sink
```

**Resonant** (θ alignment creating coherence)
```
    ●═══════⚡═══════●
    Pulsing bright white
    Expanding rings at connection points
```

### 2.5 Implementation: SemanticEdge Class

```gdscript
class_name SemanticEdge
extends RefCounted

## Renders relationship between two quantum nodes with semantic meaning

# Connection
var from_node: QuantumGlyph = null
var to_node: QuantumGlyph = null
var relationship_emoji: String = ""
var coupling_strength: float = 0.0

# Animation state
var current_interaction: float = 0.0  # √(Nᵢ × Nⱼ)
var particles: Array[Dictionary] = []  # {position: Vector2, progress: float}
var pulse_phase: float = 0.0
var time_accumulated: float = 0.0

# Visual constants
const BASE_WIDTH: float = 2.0
const MAX_WIDTH: float = 12.0
const PARTICLE_SPEED: float = 100.0  # pixels per second
const MAX_PARTICLES: int = 10


func update(dt: float, from_qubit: DualEmojiQubit, to_qubit: DualEmojiQubit) -> void:
    """Update edge state from quantum data"""
    time_accumulated += dt
    
    # Calculate current interaction strength
    if from_qubit and to_qubit:
        var from_pop = from_qubit.energy
        var to_pop = to_qubit.energy
        current_interaction = sqrt(from_pop * to_pop)
    
    # Spawn particles based on interaction strength
    if current_interaction > 0.1 and particles.size() < MAX_PARTICLES:
        if randf() < current_interaction * dt * 5.0:
            particles.append({
                "progress": 0.0,
                "speed": PARTICLE_SPEED * (0.8 + randf() * 0.4)
            })
    
    # Update existing particles
    var new_particles: Array[Dictionary] = []
    for p in particles:
        p.progress += p.speed * dt / _get_edge_length()
        if p.progress < 1.0:
            new_particles.append(p)
    particles = new_particles
    
    # Pulse animation
    pulse_phase = sin(time_accumulated * 3.0) * 0.5 + 0.5


func draw(canvas: CanvasItem, font: Font) -> void:
    """Render the edge"""
    if not from_node or not to_node:
        return
    
    var from_pos = from_node.position
    var to_pos = to_node.position
    var midpoint = (from_pos + to_pos) / 2.0
    var direction = (to_pos - from_pos).normalized()
    
    # === EDGE LINE ===
    var edge_width = BASE_WIDTH + coupling_strength * (MAX_WIDTH - BASE_WIDTH)
    var edge_color = _get_relationship_color()
    
    # Modulate alpha by interaction strength
    edge_color.a = 0.3 + current_interaction * 0.7
    
    # Draw main line
    canvas.draw_line(from_pos, to_pos, edge_color, edge_width)
    
    # Draw glow for active edges
    if current_interaction > 0.3:
        var glow_color = edge_color
        glow_color.a = current_interaction * 0.2
        canvas.draw_line(from_pos, to_pos, glow_color, edge_width * 2.5)
    
    # === RELATIONSHIP EMOJI (at midpoint) ===
    var emoji_bg_color = Color(0, 0, 0, 0.7)
    canvas.draw_circle(midpoint, 12, emoji_bg_color)
    canvas.draw_string(font, midpoint + Vector2(-8, 6), relationship_emoji,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
    
    # === DIRECTIONAL ARROW (for asymmetric relationships) ===
    if _is_directional():
        _draw_arrow(canvas, to_pos - direction * 35, direction, edge_color)
    
    # === FLOW PARTICLES ===
    for p in particles:
        var particle_pos = from_pos.lerp(to_pos, p.progress)
        var particle_color = edge_color
        particle_color.a = 1.0 - abs(p.progress - 0.5) * 2.0  # Fade at ends
        canvas.draw_circle(particle_pos, 3.0, particle_color)


func _get_relationship_color() -> Color:
    """Get color based on relationship type"""
    match relationship_emoji:
        "🍴": return Color(0.9, 0.3, 0.2)   # Red (predation)
        "🃏": return Color(0.9, 0.6, 0.2)   # Orange (escape)
        "🌱": return Color(0.3, 0.8, 0.3)   # Green (consumption/feeding)
        "💧": return Color(0.3, 0.6, 0.9)   # Blue (production)
        "🔄": return Color(0.7, 0.4, 0.9)   # Purple (transformation)
        "⚡": return Color(1.0, 0.95, 0.5)  # Yellow (coherence)
        "👶": return Color(0.95, 0.6, 0.8)  # Pink (reproduction)
        _: return Color(0.7, 0.7, 0.7)      # Gray (unknown)


func _is_directional() -> bool:
    """Check if relationship is asymmetric (needs arrow)"""
    return relationship_emoji in ["🍴", "🌱", "💧", "👶"]


func _draw_arrow(canvas: CanvasItem, tip: Vector2, direction: Vector2, color: Color) -> void:
    """Draw arrowhead at tip pointing in direction"""
    var arrow_size = 8.0
    var perpendicular = Vector2(-direction.y, direction.x)
    var base_left = tip - direction * arrow_size + perpendicular * arrow_size * 0.5
    var base_right = tip - direction * arrow_size - perpendicular * arrow_size * 0.5
    canvas.draw_polygon([tip, base_left, base_right], [color])


func _get_edge_length() -> float:
    """Get pixel length of edge"""
    if from_node and to_node:
        return from_node.position.distance_to(to_node.position)
    return 100.0
```

---

## Part 3: The Field Background Layer

### 3.1 Philosophy

The background is not empty space. It's a **quantum field** that shows environmental conditions: temperature gradients, Icon influence zones, and coherence fields.

### 3.2 Field Types

**Temperature Field**
```
    HOT (400K)           COOL (300K)
    ░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░
    ░░░░▓▓▓▓▓▓████████▓▓▓▓░░░░░
    ░░░▓▓▓▓████████████▓▓▓▓░░░
    ░░▓▓▓██████████████████▓▓░░
    
    Visual: Red-orange gradient for hot, blue for cool
    Updates: Follows sun_qubit.theta cycle
```

**Icon Influence Zones**
```
    BIOTIC FLUX (green)     IMPERIUM (gray)
         ╭──────╮               ╭──────╮
        ╱        ╲             ╱        ╲
       │  🌾🌾🌾  │           │  🏰🏰🏰  │
        ╲        ╱             ╲        ╱
         ╰──────╯               ╰──────╯
    
    Visual: Soft radial gradient from Icon center
    Color: Matches Icon's visual_color
    Radius: Proportional to active_strength
```

**Coherence Field**
```
    HIGH COHERENCE          LOW COHERENCE
    ════════════════        ░ ░ ░ ░ ░ ░ ░
    ════════════════        ░   ░   ░   ░
    ════════════════        ░ ░   ░ ░   ░
    
    Visual: Grid lines that become noisy/broken with low coherence
    Updates: Average coherence of all qubits in region
```

### 3.3 Implementation: FieldBackground Class

```gdscript
class_name FieldBackground
extends RefCounted

## Renders environmental field effects behind nodes

# Data sources
var biome = null  # Reference to Biome
var glyphs: Array[QuantumGlyph] = []

# Visual state
var temperature_field: Image = null
var coherence_average: float = 1.0
var icon_zones: Array[Dictionary] = []  # {center, radius, color}

# Constants
const FIELD_RESOLUTION: int = 32  # Low-res for performance
const TEMPERATURE_MIN: float = 280.0
const TEMPERATURE_MAX: float = 420.0


func update(dt: float) -> void:
    """Update field state from biome data"""
    if not biome:
        return
    
    # Update temperature field from sun cycle
    _update_temperature_field()
    
    # Update average coherence from all glyphs
    _update_coherence_average()
    
    # Update Icon influence zones
    _update_icon_zones()


func draw(canvas: CanvasItem, viewport_size: Vector2) -> void:
    """Render field effects"""
    
    # === TEMPERATURE GRADIENT (subtle background wash) ===
    _draw_temperature_gradient(canvas, viewport_size)
    
    # === ICON INFLUENCE ZONES (soft radial gradients) ===
    for zone in icon_zones:
        _draw_icon_zone(canvas, zone)
    
    # === COHERENCE GRID (subtle reference lines) ===
    _draw_coherence_grid(canvas, viewport_size)


func _update_temperature_field() -> void:
    """Build temperature field from biome"""
    if not biome or not biome.sun_qubit:
        return
    
    # Temperature follows sun cycle
    # θ=0 (noon) → hot, θ=π (midnight) → cooler but still warm
    var sun_theta = biome.sun_qubit.theta
    var intensity = (1.0 + cos(2.0 * sun_theta)) / 2.0
    # This creates peaks at both noon AND midnight (Rabi oscillation)


func _update_coherence_average() -> void:
    """Calculate average coherence across all glyphs"""
    if glyphs.is_empty():
        coherence_average = 1.0
        return
    
    var total = 0.0
    for glyph in glyphs:
        if glyph.qubit:
            total += glyph.qubit.get_coherence()
    coherence_average = total / glyphs.size()


func _update_icon_zones() -> void:
    """Build Icon influence zone data"""
    icon_zones.clear()
    
    if not biome:
        return
    
    # Biotic Flux zone (green, growth-promoting)
    if biome.biotic_flux_icon and biome.biotic_flux_icon.active_strength > 0.1:
        icon_zones.append({
            "center": biome.visual_center_offset,
            "radius": biome.biotic_flux_icon.active_strength * 200.0,
            "color": Color(0.3, 0.8, 0.3, 0.15)
        })
    
    # Imperium zone (gray, order/extraction)
    if biome.imperium_icon and biome.imperium_icon.active_strength > 0.1:
        icon_zones.append({
            "center": Vector2(200, 0),  # Offset from center
            "radius": biome.imperium_icon.active_strength * 150.0,
            "color": Color(0.5, 0.5, 0.5, 0.2)
        })


func _draw_temperature_gradient(canvas: CanvasItem, viewport_size: Vector2) -> void:
    """Draw subtle temperature wash"""
    if not biome or not biome.sun_qubit:
        return
    
    var sun_theta = biome.sun_qubit.theta
    var day_night = sun_theta / PI  # 0 = noon, 1 = midnight
    
    # Day: warm yellow-orange tint
    # Night: cool blue-purple tint
    var day_color = Color(1.0, 0.95, 0.8, 0.05)
    var night_color = Color(0.7, 0.7, 0.9, 0.08)
    var bg_color = day_color.lerp(night_color, day_night)
    
    canvas.draw_rect(Rect2(Vector2.ZERO, viewport_size), bg_color)


func _draw_icon_zone(canvas: CanvasItem, zone: Dictionary) -> void:
    """Draw soft radial gradient for Icon influence"""
    var center = zone.center + canvas.get_viewport_rect().size / 2.0
    var radius = zone.radius
    var color = zone.color
    
    # Draw multiple concentric circles with decreasing alpha
    for i in range(5):
        var ring_radius = radius * (1.0 - i * 0.2)
        var ring_alpha = color.a * (1.0 - i * 0.2)
        var ring_color = Color(color.r, color.g, color.b, ring_alpha)
        canvas.draw_circle(center, ring_radius, ring_color)


func _draw_coherence_grid(canvas: CanvasItem, viewport_size: Vector2) -> void:
    """Draw subtle reference grid that degrades with low coherence"""
    var grid_spacing = 80.0
    var grid_color = Color(0.5, 0.5, 0.5, 0.1 * coherence_average)
    
    # Horizontal lines
    var y = grid_spacing
    while y < viewport_size.y:
        var y_offset = 0.0
        if coherence_average < 0.7:
            # Add noise to grid lines when coherence is low
            y_offset = (randf() - 0.5) * 10.0 * (1.0 - coherence_average)
        canvas.draw_line(
            Vector2(0, y + y_offset),
            Vector2(viewport_size.x, y + y_offset),
            grid_color, 1.0)
        y += grid_spacing
    
    # Vertical lines
    var x = grid_spacing
    while x < viewport_size.x:
        var x_offset = 0.0
        if coherence_average < 0.7:
            x_offset = (randf() - 0.5) * 10.0 * (1.0 - coherence_average)
        canvas.draw_line(
            Vector2(x + x_offset, 0),
            Vector2(x + x_offset, viewport_size.y),
            grid_color, 1.0)
        x += grid_spacing
```

---

## Part 4: The Particle Effect System

### 4.1 Philosophy

Particles show **flow** — energy transfer, decoherence, growth, and decay. They make the invisible visible.

### 4.2 Particle Types

| Particle Type | Trigger | Visual | Meaning |
|--------------|---------|--------|---------|
| **Energy Flow** | Energy transfer between nodes | Bright dots following edges | Resources moving |
| **Decoherence Dust** | Coherence decreasing | Gray motes drifting away | Quantum state degrading |
| **Growth Sparks** | Energy increasing | Green sparkles rising | Life flourishing |
| **Measurement Flash** | Qubit measured | Expanding ring + burst | Wavefunction collapse |
| **Entanglement Link** | Bell state created | Twin particles mirroring | Quantum correlation |

### 4.3 Implementation: ParticleEffectManager

```gdscript
class_name ParticleEffectManager
extends RefCounted

## Manages all particle effects for the quantum visualization

var particles: Array[Dictionary] = []
const MAX_PARTICLES: int = 500


func spawn_energy_flow(from: Vector2, to: Vector2, intensity: float) -> void:
    """Spawn particles flowing along an edge"""
    var count = int(intensity * 5)
    for i in range(count):
        particles.append({
            "type": "energy_flow",
            "position": from,
            "target": to,
            "progress": randf() * 0.3,  # Stagger start
            "speed": 80.0 + randf() * 40.0,
            "color": Color(1.0, 0.9, 0.3, 0.8),
            "size": 2.0 + randf() * 2.0
        })


func spawn_decoherence_dust(center: Vector2, amount: float) -> void:
    """Spawn gray motes drifting away from decohering node"""
    var count = int(amount * 10)
    for i in range(count):
        var angle = randf() * TAU
        var speed = 20.0 + randf() * 30.0
        particles.append({
            "type": "decoherence",
            "position": center,
            "velocity": Vector2(cos(angle), sin(angle)) * speed,
            "lifetime": 2.0,
            "age": 0.0,
            "color": Color(0.5, 0.5, 0.5, 0.6),
            "size": 1.5 + randf() * 1.5
        })


func spawn_growth_sparks(center: Vector2, intensity: float) -> void:
    """Spawn green sparkles rising from growing node"""
    var count = int(intensity * 8)
    for i in range(count):
        var x_offset = (randf() - 0.5) * 30.0
        particles.append({
            "type": "growth",
            "position": center + Vector2(x_offset, 0),
            "velocity": Vector2(0, -40.0 - randf() * 20.0),
            "lifetime": 1.5,
            "age": 0.0,
            "color": Color(0.4, 0.9, 0.3, 0.9),
            "size": 2.0 + randf() * 2.0
        })


func spawn_measurement_flash(center: Vector2, outcome_color: Color) -> void:
    """Spawn expanding ring and burst for wavefunction collapse"""
    # Central burst
    for i in range(20):
        var angle = randf() * TAU
        var speed = 60.0 + randf() * 40.0
        particles.append({
            "type": "burst",
            "position": center,
            "velocity": Vector2(cos(angle), sin(angle)) * speed,
            "lifetime": 0.5,
            "age": 0.0,
            "color": outcome_color,
            "size": 3.0
        })
    
    # Expanding ring
    particles.append({
        "type": "ring",
        "position": center,
        "radius": 10.0,
        "max_radius": 80.0,
        "lifetime": 0.8,
        "age": 0.0,
        "color": outcome_color
    })


func spawn_entanglement_link(pos_a: Vector2, pos_b: Vector2) -> void:
    """Spawn mirrored twin particles showing entanglement"""
    for i in range(5):
        var offset = Vector2((randf() - 0.5) * 20, (randf() - 0.5) * 20)
        particles.append({
            "type": "entangle_twin",
            "position_a": pos_a + offset,
            "position_b": pos_b - offset,  # Mirrored!
            "lifetime": 2.0,
            "age": 0.0,
            "color": Color(0.9, 0.5, 0.9, 0.8),
            "size": 3.0
        })


func update(dt: float) -> void:
    """Update all particles"""
    var surviving: Array[Dictionary] = []
    
    for p in particles:
        match p.type:
            "energy_flow":
                p.progress += p.speed * dt / p.position.distance_to(p.target)
                if p.progress < 1.0:
                    p.position = p.position.lerp(p.target, p.progress)
                    surviving.append(p)
            
            "decoherence", "growth", "burst":
                p.age += dt
                p.position += p.velocity * dt
                p.velocity *= 0.98  # Drag
                if p.age < p.lifetime:
                    surviving.append(p)
            
            "ring":
                p.age += dt
                p.radius = lerp(10.0, p.max_radius, p.age / p.lifetime)
                if p.age < p.lifetime:
                    surviving.append(p)
            
            "entangle_twin":
                p.age += dt
                # Twins orbit their centers
                var orbit = Vector2(cos(p.age * 5), sin(p.age * 5)) * 10.0
                # Positions are mirrored (entangled!)
                if p.age < p.lifetime:
                    surviving.append(p)
    
    particles = surviving
    
    # Enforce max particles
    if particles.size() > MAX_PARTICLES:
        particles = particles.slice(particles.size() - MAX_PARTICLES)


func draw(canvas: CanvasItem) -> void:
    """Render all particles"""
    for p in particles:
        var alpha = 1.0
        if p.has("age") and p.has("lifetime"):
            alpha = 1.0 - (p.age / p.lifetime)
        
        var color = p.color
        color.a *= alpha
        
        match p.type:
            "energy_flow", "decoherence", "growth", "burst":
                canvas.draw_circle(p.position, p.size, color)
            
            "ring":
                canvas.draw_arc(p.position, p.radius, 0, TAU, 32, color, 2.0)
            
            "entangle_twin":
                # Draw both twins
                canvas.draw_circle(p.position_a, p.size, color)
                canvas.draw_circle(p.position_b, p.size, color)
                # Draw connecting line (ghostly)
                var line_color = color
                line_color.a *= 0.3
                canvas.draw_line(p.position_a, p.position_b, line_color, 1.0)
```

---

## Part 5: The Detail Panel (Selection UI)

### 5.1 Philosophy

When a player selects a node, they deserve to see **everything**. The detail panel is the "quantum microscope" — full Bloch sphere geometry, all connections, complete history.

### 5.2 Panel Layout

```
┌─────────────────────────────────────┐
│ 🌾 WHEAT PLOT (3, 5)                │
├─────────────────────────────────────┤
│  ┌─────────────┐                    │
│  │   BLOCH     │  θ = 1.23 rad      │
│  │   SPHERE    │  φ = 0.45 rad      │
│  │     ●→      │  r = 0.87          │
│  │             │                    │
│  └─────────────┘  Berry: 3.7        │
├─────────────────────────────────────┤
│ SUPERPOSITION                       │
│   🌾 wheat    ████████░░  78%       │
│   👥 labor    ██░░░░░░░░  22%       │
├─────────────────────────────────────┤
│ CONNECTIONS                         │
│   🍴→ 🐰 rabbit (0.15)              │
│   🌱← 🌿 grass (0.08)               │
│   ⚡↔ 🌾 wheat-2 (entangled)        │
├─────────────────────────────────────┤
│ ENVIRONMENT                         │
│   🌡️ Temperature: 312K              │
│   🌾 BioticFlux: +15% growth        │
│   ☀️ Sun phase: 0.7π (afternoon)    │
├─────────────────────────────────────┤
│ HISTORY                             │
│   ░░▓▓▓████▓▓▓░░░░░░░░░░  (energy) │
│   Created: 45s ago                  │
│   Measured: never                   │
└─────────────────────────────────────┘
```

### 5.3 Mini Bloch Sphere Visualization

```gdscript
func draw_mini_bloch_sphere(canvas: CanvasItem, center: Vector2, 
        radius: float, theta: float, phi: float, r: float) -> void:
    """Draw a small 2D projection of the Bloch sphere"""
    
    # Draw sphere outline
    canvas.draw_arc(center, radius, 0, TAU, 64, Color(0.5, 0.5, 0.5, 0.5), 1.0)
    
    # Draw equator (dashed)
    canvas.draw_arc(center, radius * 0.7, 0, TAU, 32, Color(0.4, 0.4, 0.4, 0.3), 1.0)
    
    # Draw prime meridian
    canvas.draw_line(
        center + Vector2(0, -radius),
        center + Vector2(0, radius),
        Color(0.4, 0.4, 0.4, 0.3), 1.0)
    
    # Calculate Bloch vector endpoint (2D projection)
    # x = r * sin(θ) * cos(φ)
    # y = r * sin(θ) * sin(φ)  (not shown in 2D)
    # z = r * cos(θ)
    var bloch_x = r * sin(theta) * cos(phi) * radius
    var bloch_z = r * cos(theta) * radius
    var bloch_point = center + Vector2(bloch_x, -bloch_z)  # Flip z for screen coords
    
    # Draw Bloch vector
    canvas.draw_line(center, bloch_point, Color(0.9, 0.7, 0.2), 2.0)
    
    # Draw Bloch point
    canvas.draw_circle(bloch_point, 5.0, Color(1.0, 0.8, 0.2))
    
    # Draw poles
    canvas.draw_circle(center + Vector2(0, -radius), 3.0, Color(0.3, 0.8, 0.3))  # North (|0⟩)
    canvas.draw_circle(center + Vector2(0, radius), 3.0, Color(0.8, 0.3, 0.3))   # South (|1⟩)
```

---

## Part 6: Integration Architecture

### 6.1 Main Visualization Controller

```gdscript
class_name QuantumVisualizationController
extends Control

## Main controller that orchestrates all visualization layers

# Components
var field_background: FieldBackground = null
var glyphs: Array[QuantumGlyph] = []
var edges: Array[SemanticEdge] = []
var particles: ParticleEffectManager = null
var detail_panel: DetailPanel = null

# Data source
var biome = null  # Biome reference

# Selection state
var selected_glyph: QuantumGlyph = null
var hovered_glyph: QuantumGlyph = null

# Font for emoji rendering
var emoji_font: Font = null


func _ready() -> void:
    # Initialize components
    field_background = FieldBackground.new()
    particles = ParticleEffectManager.new()
    detail_panel = DetailPanel.new()
    
    # Load emoji font
    emoji_font = load("res://Assets/Fonts/NotoColorEmoji.ttf")
    
    # Enable input
    mouse_filter = Control.MOUSE_FILTER_STOP


func connect_to_biome(biome_ref) -> void:
    """Connect visualization to biome data source"""
    biome = biome_ref
    field_background.biome = biome
    
    # Create glyphs for all quantum states
    _rebuild_glyphs()
    
    # Create edges from entanglement graphs
    _rebuild_edges()


func _rebuild_glyphs() -> void:
    """Rebuild glyph array from biome.quantum_states"""
    glyphs.clear()
    
    if not biome:
        return
    
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
    
    field_background.glyphs = glyphs


func _rebuild_edges() -> void:
    """Rebuild edge array from qubit entanglement_graphs"""
    edges.clear()
    
    # Build edges from entanglement_graph relationships
    for glyph in glyphs:
        if not glyph.qubit:
            continue
        
        for relationship in glyph.qubit.get_all_relationships():
            var targets = glyph.qubit.get_graph_targets(relationship)
            for target_emoji in targets:
                # Find glyph with matching emoji
                var target_glyph = _find_glyph_by_emoji(target_emoji)
                if target_glyph:
                    var edge = SemanticEdge.new()
                    edge.from_node = glyph
                    edge.to_node = target_glyph
                    edge.relationship_emoji = relationship
                    edge.coupling_strength = 0.5  # Could be computed from Hamiltonian
                    edges.append(edge)


func _process(delta: float) -> void:
    # Update all components
    field_background.update(delta)
    
    for glyph in glyphs:
        glyph.update_from_qubit(delta)
    
    for edge in edges:
        edge.update(delta, edge.from_node.qubit, edge.to_node.qubit)
    
    particles.update(delta)
    
    # Trigger particle effects based on state changes
    _check_for_particle_triggers(delta)
    
    # Redraw
    queue_redraw()


func _draw() -> void:
    var viewport_size = get_viewport_rect().size
    
    # Layer 0: Field background
    field_background.draw(self, viewport_size)
    
    # Layer 1: Edges (behind nodes)
    for edge in edges:
        edge.draw(self, emoji_font)
    
    # Layer 2: Glyphs
    for glyph in glyphs:
        glyph.draw(self, emoji_font)
    
    # Layer 3: Particles
    particles.draw(self)
    
    # Layer 4: Selection highlight
    if selected_glyph:
        draw_arc(selected_glyph.position, 45, 0, TAU, 64,
            Color(1.0, 0.8, 0.2, 0.8), 3.0)
    
    # Layer 5: Detail panel (if selected)
    if selected_glyph:
        detail_panel.draw(self, selected_glyph, emoji_font)


func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            var clicked_glyph = _get_glyph_at(event.position)
            if clicked_glyph:
                selected_glyph = clicked_glyph
                # Spawn selection particle effect
                particles.spawn_measurement_flash(
                    clicked_glyph.position,
                    clicked_glyph.core_gradient_top)
            else:
                selected_glyph = null
            queue_redraw()
    
    elif event is InputEventMouseMotion:
        hovered_glyph = _get_glyph_at(event.position)


func _get_glyph_at(pos: Vector2) -> QuantumGlyph:
    """Find glyph at screen position"""
    for glyph in glyphs:
        if pos.distance_to(glyph.position) < QuantumGlyph.BASE_RADIUS:
            return glyph
    return null


func _find_glyph_by_emoji(emoji: String) -> QuantumGlyph:
    """Find glyph whose qubit has matching emoji"""
    for glyph in glyphs:
        if glyph.qubit:
            if glyph.qubit.north_emoji == emoji or glyph.qubit.south_emoji == emoji:
                return glyph
    return null


func _grid_to_screen(grid_pos: Vector2i) -> Vector2:
    """Convert grid position to screen coordinates"""
    var center = get_viewport_rect().size / 2.0
    var spacing = 100.0
    return center + Vector2(grid_pos.x * spacing, grid_pos.y * spacing)


func _check_for_particle_triggers(delta: float) -> void:
    """Spawn particles based on state changes"""
    for glyph in glyphs:
        if not glyph.qubit:
            continue
        
        # Growth sparks when energy is increasing
        if glyph.qubit.energy > glyph.glow_intensity + 0.01:
            particles.spawn_growth_sparks(glyph.position, 0.3)
        
        # Decoherence dust when coherence drops
        if glyph.qubit.get_coherence() < 0.5:
            particles.spawn_decoherence_dust(glyph.position, 
                (1.0 - glyph.qubit.get_coherence()) * delta)
```

---

## Part 7: Future Extensions (Topological Campaign Support)

### 7.1 Strange Attractor Overlay

For Tier 0 "Strange Attractors" mechanic:

```gdscript
func draw_strange_attractor_overlay(canvas: CanvasItem, 
        attractor_phase: float, node_positions: Array[Vector2]) -> void:
    """Draw phase portrait showing attractor dynamics"""
    # Draw the attractor's phase space trajectory
    var trajectory_points: Array[Vector2] = []
    for i in range(100):
        var t = i * 0.1
        # Rössler attractor equations (or your chosen system)
        var x = sin(attractor_phase + t) * 50.0
        var y = cos(attractor_phase * 1.3 + t) * 30.0
        trajectory_points.append(Vector2(x, y) + canvas.get_viewport_rect().size / 2.0)
    
    # Draw trajectory
    for i in range(trajectory_points.size() - 1):
        var alpha = float(i) / trajectory_points.size()
        canvas.draw_line(trajectory_points[i], trajectory_points[i + 1],
            Color(0.5, 0.8, 1.0, alpha * 0.5), 1.0)
    
    # Show which nodes are "on" the attractor
    for node_pos in node_positions:
        # Calculate distance to attractor
        var closest_dist = INF
        for traj_pos in trajectory_points:
            closest_dist = min(closest_dist, node_pos.distance_to(traj_pos))
        
        if closest_dist < 30.0:
            # Node is riding the attractor!
            canvas.draw_arc(node_pos, 35, 0, TAU, 32,
                Color(0.5, 0.8, 1.0, 0.6), 2.0)
```

### 7.2 Berry Phase Path Visualization

For accumulated geometric phase:

```gdscript
func draw_berry_phase_path(canvas: CanvasItem, glyph: QuantumGlyph) -> void:
    """Draw the path this qubit has traced on the Bloch sphere"""
    if not glyph.qubit:
        return
    
    # Store history in qubit (would need to add this)
    var history = glyph.qubit.theta_phi_history  # Array of [theta, phi] pairs
    
    if history.size() < 2:
        return
    
    # Project history onto 2D and draw as ribbon
    var ribbon_points: Array[Vector2] = []
    for point in history:
        var theta = point[0]
        var phi = point[1]
        var x = sin(theta) * cos(phi) * 30.0
        var z = cos(theta) * 30.0
        ribbon_points.append(glyph.position + Vector2(x, -z))
    
    # Draw path with gradient showing time
    for i in range(ribbon_points.size() - 1):
        var alpha = float(i) / ribbon_points.size()
        canvas.draw_line(ribbon_points[i], ribbon_points[i + 1],
            Color(0.9, 0.6, 0.9, alpha), 2.0)
```

### 7.3 Braid Pattern Overlay

For Non-Abelian Anyonic Highways:

```gdscript
func draw_braid_pattern(canvas: CanvasItem, 
        strands: Array[Array], crossings: Array[Dictionary]) -> void:
    """Draw braid pattern showing topological routing"""
    # strands: Array of position arrays (each strand's path)
    # crossings: {position, over_strand, under_strand}
    
    for i in range(strands.size()):
        var strand = strands[i]
        var color = Color.from_hsv(float(i) / strands.size(), 0.8, 0.9)
        
        for j in range(strand.size() - 1):
            # Check if this segment has a crossing
            var is_under = false
            for crossing in crossings:
                if crossing.under_strand == i:
                    # This strand goes under - draw with gap
                    is_under = true
            
            if is_under:
                # Draw dashed (under)
                _draw_dashed_line(canvas, strand[j], strand[j + 1], color)
            else:
                # Draw solid (over)
                canvas.draw_line(strand[j], strand[j + 1], color, 3.0)
```

---

## Part 8: Performance Considerations

### 8.1 Rendering Budget

```
Target: 60 FPS (16.6ms per frame)

Budget allocation:
- Field background:     1ms
- Glyphs (20 nodes):    3ms
- Edges (30 edges):     2ms
- Particles (100):      2ms
- Detail panel:         1ms
- UI overlay:           1ms
- Headroom:             6ms

Total: ~10ms (plenty of margin)
```

### 8.2 Optimization Strategies

1. **Culling**: Don't draw off-screen elements
2. **LOD**: Simplify distant glyphs (emoji only, no ring)
3. **Batching**: Group draw calls by type
4. **Caching**: Pre-render static elements to textures
5. **Particle limits**: Hard cap at 500 particles

### 8.3 Scaling Considerations

| Node Count | Strategy |
|------------|----------|
| 1-20 | Full detail, all effects |
| 20-50 | Reduce particle count, simplify edges |
| 50-100 | LOD for distant nodes, batch rendering |
| 100+ | Consider switching to GPU particle system |

---

## Part 9: Implementation Roadmap

### Phase 1: Core Glyphs (Week 1)
- [ ] Implement `QuantumGlyph` class
- [ ] Dual-emoji with θ-weighted opacity
- [ ] Phase ring with φ hue
- [ ] Berry phase bar
- [ ] Basic glow effect

### Phase 2: Semantic Edges (Week 1-2)
- [ ] Implement `SemanticEdge` class
- [ ] Relationship emoji labels
- [ ] Particle flow along edges
- [ ] Directional arrows

### Phase 3: Field Background (Week 2)
- [ ] Temperature gradient
- [ ] Icon influence zones
- [ ] Coherence grid

### Phase 4: Particles (Week 2-3)
- [ ] Energy flow particles
- [ ] Decoherence dust
- [ ] Growth sparks
- [ ] Measurement flash

### Phase 5: Detail Panel (Week 3)
- [ ] Mini Bloch sphere
- [ ] Connection list
- [ ] Environment display
- [ ] History sparkline

### Phase 6: Integration (Week 3-4)
- [ ] Connect to Biome data
- [ ] Input handling (selection)
- [ ] Polish and performance

### Phase 7: Future Mechanics (Ongoing)
- [ ] Strange attractor overlay
- [ ] Berry phase path visualization
- [ ] Braid pattern support

---

## Appendix A: Visual Reference Palette

```
ECOSYSTEM COLORS:
  Plants:     #99CC33 (green-gold)
  Animals:    #CC9966 (warm brown)
  Fungi:      #9966AA (purple)
  Water:      #4D99E6 (blue)
  Sun:        #FFEE55 (bright yellow)
  Moon:       #4D4D99 (deep blue-purple)
  
RELATIONSHIP COLORS:
  Predation:  #E64D33 (red)
  Escape:     #E69933 (orange)
  Feeding:    #4DB34D (green)
  Production: #4D99E6 (blue)
  Transform:  #B366E6 (purple)
  Coherence:  #FFFF88 (yellow-white)
  Reproduce:  #F299CC (pink)

UI COLORS:
  Background: #1A1A2E (dark blue-black)
  Panel:      #16213E (navy)
  Text:       #E6E6E6 (off-white)
  Accent:     #E6B333 (gold)
  Warning:    #E64D4D (red)
  Success:    #4DE64D (green)
```

---

## Appendix B: Emoji Reference

```
CELESTIAL:
  ☀️ - Sun (north pole of sun_qubit)
  🌙 - Moon (south pole of sun_qubit)

CROPS:
  🌾 - Wheat (growth, harvest)
  🍄 - Mushroom (decay, night)
  🌿 - Grass/plants (base ecosystem)

RESOURCES:
  💧 - Water (produced by plants)
  👥 - Labor (player investment)

ICONS:
  🌾 - Biotic Flux (growth, coherence)
  🏰 - Imperium (order, extraction)

RELATIONSHIPS:
  🍴 - Predation (A hunts B)
  🃏 - Escape (A flees B)
  🌱 - Consumption (A feeds on B)
  💧 - Production (A produces B)
  🔄 - Transformation (A→B)
  ⚡ - Coherence strike
  👶 - Reproduction

ANIMALS (for ecosystem expansion):
  🐰 - Rabbit (herbivore)
  🐺 - Wolf (predator)
  🦅 - Eagle (apex predator)
```

---

## Closing Notes

This visualization system is designed to grow with your game. The core glyph and edge systems handle the immediate needs (showing quantum state), while the layered architecture allows adding topological campaign mechanics without rewriting everything.

The key insight: **every visual element encodes real quantum data**. This isn't decoration — it's a measurement apparatus. Players who learn to read glyphs are learning to read quantum states. Players who watch particle flows are seeing Hamiltonian dynamics.

That's the magic: education through play, physics through beauty.

🌾⚛️ *May your coherence remain high and your berry phase accumulate.* ⚛️🌾
