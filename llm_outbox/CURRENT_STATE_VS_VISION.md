# Current State vs Vision: Quantum Visualization System

## Vision (from QuantumForceGraph_Visual_Layer_Design.md)

Players should experience a "quantum aquarium" - a living window into the ecosystem with layers of visual meaning:

```
Layer 5: UI Overlay         (Selection, tooltips, metrics)
Layer 4: Particle Effects   (Flow particles, decoherence dust)
Layer 3: Edges (Semantic)   (Relationship emojis, coupling)
Layer 2: Nodes (Glyphs)     (Compound quantum state display)
Layer 1: Field Background   (Temperature gradients, Icon auras)
Layer 0: Grid Reference     (Subtle classical anchor points)
```

---

## Where We Are Now ❌

### What's Working
✅ Basic glyph creation from biome occupation_numbers
✅ Dual emoji rendering (north/south)
✅ Emoji opacity based on Born rule (cos²/sin²)
✅ Phase ring color cycling (hue from φ)
✅ Biome quantum evolution (Hamiltonian)
✅ Visualization reads evolved state each frame

### What's Missing (Critical Gaps)

#### Glyph Rendering (Layer 2)
❌ **NO GLOW LAYER** - No energy-based glow behind glyphs
❌ **NO CORE GRADIENT** - No vertical gradient circle showing superposition
❌ **NO BERRY PHASE BAR** - No accumulated evolution visualization
❌ **NO PULSE ANIMATION** - No decoherence warning pulse
❌ **PHASE RING BROKEN** - Using line segments instead of proper circle
   - Should be: `canvas.draw_arc()` with coherence-weighted thickness
   - Currently: 32 manual lines (crude approximation)
❌ **NO EMOJI POSITIONING** - Emojis not offset from center properly
❌ **NO COHERENCE FLICKER** - Decohering glyphs should flicker opacity

#### Edge System (Layer 3)
❌ **ZERO EDGE VISUALIZATION** - No relationship connections drawn
❌ **NO SEMANTIC EDGES** - No 🍴/🌱/💧/🔄/⚡/👶/🃏 emoji relationships
❌ **NO FLOW PARTICLES** - No particle flow along edges
❌ **NO COUPLING STRENGTH** - Edges don't show gᵢⱼ coupling
❌ **NO DIRECTIONAL ARROWS** - Asymmetric relationships not indicated

#### Particle Effects (Layer 4)
❌ **NO DECOHERENCE DUST** - Low coherence qubits should show particle decay
❌ **NO FLOW PARTICLES** - Edges should have flowing particles
❌ **NO MEASUREMENT FLASH** - No visual feedback on measurement

#### Field Background (Layer 1)
❌ **NO TEMPERATURE GRADIENT** - No visual temperature field
❌ **NO ICON AURAS** - No environmental modulation visualization
❌ **NO BIOME-LEVEL EFFECTS** - No background context

#### UI Overlay (Layer 5)
❌ **DETAIL PANEL INCOMPLETE** - Only appears on selection
❌ **NO TOOLTIP SYSTEM** - No hover information
❌ **NO GRID REFERENCE** - No subtle anchor points

---

## Why This Matters

The current implementation is a **visualization skeleton** that:
- Shows glyphs exist and change color
- Proves simulation/visualization separation works
- But provides NO intuitive feel for quantum mechanics

The vision requires players to understand:
- **Superposition**: Core gradient shows both possibilities
- **Coherence**: Ring thickness shows stability
- **Evolution**: Berry phase bar accumulates as qubit evolves
- **Relationships**: Edges show how nodes influence each other
- **Energy**: Glow shows active participation
- **Decoherence**: Pulse and flicker warn of instability

---

## Implementation Todo List

### Phase 1: Fix Glyph Rendering (CRITICAL)
- [ ] Implement glow layer (circle behind glyph, opacity = energy)
- [ ] Draw core gradient circle (vertical gradient based on θ)
- [ ] Add berry phase accumulation bar below glyph
- [ ] Implement coherence-based pulse animation
- [ ] Replace phase ring line-segments with proper arc (if available) or improve line quality
- [ ] Add emoji flicker animation for low-coherence states
- [ ] Properly offset emoji positions from center
- [ ] Add glow fade effect for measurement collapse

### Phase 2: Add Edge System
- [ ] Extract entanglement_graph from qubits
- [ ] Create SemanticEdge class
- [ ] Render edges with relationship-emoji colors
- [ ] Implement edge width based on coupling strength
- [ ] Add directional arrows for asymmetric relationships
- [ ] Implement edge animation (active/dormant/resonant states)
- [ ] Add glow on active edges

### Phase 3: Particle Effects
- [ ] Spawn flow particles along edges
- [ ] Implement particle animation (progress along edge)
- [ ] Add decoherence dust (particles drifting from low-coherence glyphs)
- [ ] Add measurement flash effect
- [ ] Implement particle color matching edge relationship

### Phase 4: Field Background
- [ ] Create temperature gradient visualization
- [ ] Add biome-level environmental effects
- [ ] Implement aura system for environmental qubits
- [ ] Add subtle grid reference layer

### Phase 5: Polish & Optimization
- [ ] Optimize draw calls (batch edges, particles)
- [ ] Add visual feedback for user interactions
- [ ] Implement smooth transitions
- [ ] Test performance with many glyphs/edges

---

## Technical Blockers

1. **Godot 4.5 API Issues**
   - `canvas.draw_arc()` doesn't exist - need workaround
   - May need to use `CanvasItem.draw_polygon()` or shaders for circles/arcs
   - `draw_circle()` exists but no arc support

2. **Emoji Rendering**
   - Font rendering for emoji is spotty
   - May need to use texture-based emoji or SVG
   - Positioning needs fine-tuning

3. **Performance**
   - Many glyphs + edges + particles = draw call explosion
   - Need batching strategy
   - Consider shader-based rendering for complex shapes

4. **Data Structure Gaps**
   - `DualEmojiQubit.entanglement_graph` needs to be populated from biome
   - `DualEmojiQubit.get_coherence()` may not exist
   - `DualEmojiQubit.get_berry_phase_normalized()` may not exist
   - Need to add missing helper methods to DualEmojiQubit

---

## Current Code Health

### QuantumGlyph.gd
- Implements ~30% of design spec
- Only draws emoji + phase ring lines
- Missing: glow, core gradient, berry bar, pulse
- ~70 lines of code, should be ~250+ for full spec

### QuantumVisualizationController.gd
- Correctly reads biome state each frame ✅
- Missing: edge system, particle system
- Need to add SemanticEdge creation and rendering
- ~140 lines, should be ~400+ for full system

### DualEmojiQubit.gd
- Has basic structure
- Missing helper methods for visualization:
  - `get_coherence()` - used by design
  - `get_berry_phase_normalized()` - used by design
  - May need to populate `entanglement_graph`

---

## Recommended Next Steps

1. **Start with core glyph improvements** (highest visual impact):
   - Glow layer (easy, looks great)
   - Core gradient circle (medium, very informative)
   - Berry phase bar (easy, adds history)
   - Coherence pulse (medium, warning system)

2. **Then add edge system**:
   - Extract entanglement relationships
   - Render edges with semantic colors
   - Add flow particles (lots of visual interest)

3. **Finally polish with particles and effects**

This approach gives continuous visual improvements and keeps the system modular.

---

## Summary

| Aspect | Current | Target | Gap |
|--------|---------|--------|-----|
| Glyph Layers | 2 (emoji + ring) | 6 (glow, core, ring, berry, pulse, emoji) | Major |
| Visual Variables | 4 (θ, φ, emoji) | 8 (+ coherence, energy, berry, interaction) | Major |
| Edges | 0 | Full system with 7 relationship types | Critical |
| Particles | 0 | Flow + decoherence effects | Critical |
| Background | 0 | Temperature field + auras | Important |
| Total Visual Richness | ~20% | 100% | 4-5x more work |

The visualization skeleton is solid. Now we need to flesh it out into a living, breathing quantum aquarium.
