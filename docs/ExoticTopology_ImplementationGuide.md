# SpaceWheat Exotic Topology - Implementation Guide

*Bridging rigorous quantum mechanics with playable factory optimization*

## Document Conventions

Throughout this document, we use the following labels:

- **[PHYSICS]** - Real physics that the game simulates with mathematical rigor
- **[GAMEPLAY]** - Game mechanics inspired by physics but adapted for playability
- **[SPECULATIVE]** - Ideas for future exploration, not finalized designs
- **[IMPLEMENTED]** - Already exists in the codebase
- **[PROPOSED]** - Concrete implementation path identified

---

## Part 1: The Quantum Substrate Foundation

### What We Have Built [IMPLEMENTED]

The SpaceWheat quantum simulation is built on real physics:

| Component | Physics Basis | Code Location |
|-----------|---------------|---------------|
| Density Matrix | **[PHYSICS]** Mixed quantum states, ρ with Tr(ρ)=1 | `QuantumComputer.density_matrix` |
| Lindblad Evolution | **[PHYSICS]** Open quantum systems: dρ/dt = -i[H,ρ] + Σ(LρL† - ½{L†L,ρ}) | `QuantumComputer.evolve()` |
| Hamiltonian Couplings | **[PHYSICS]** Hermitian operator generating unitary evolution | `Icon.hamiltonian_couplings` |
| Decoherence | **[PHYSICS]** Loss of quantum coherence via environment coupling | `Icon.decoherence_coupling` |
| Bell States | **[PHYSICS]** Maximally entangled 2-qubit states: (|00⟩+|11⟩)/√2 | `QuantumComputer.entangle_plots()` |
| Eigenstate Analysis | **[PHYSICS]** Hamiltonian eigenvectors as stable configurations | `ProphecyEngine.compute_prophecy()` |

### How Icons Create Physics [IMPLEMENTED]

**[PHYSICS]** The icon/faction system generates genuine quantum operators:

```
Icon Properties → Quantum Operators
─────────────────────────────────────
self_energy         → H[i,i] diagonal elements
hamiltonian_couplings → H[i,j] off-diagonal (can be complex)
lindblad_outgoing   → Jump operators L = √γ|j⟩⟨i|
lindblad_incoming   → Reverse jump operators
gated_lindblad      → State-dependent rates: γ_eff = γ₀ × P(gate)^power
```

**[GAMEPLAY]** Factions contribute weighted parameters to icons, creating emergent physics from narrative design. Players don't see operators—they see emoji relationships.

---

## Part 2: Tier Progression with Implementation Paths

### Tier 0: Instant Satisfaction
*"Set and forget" - minimal player management required*

---

#### Strange Attractors [PARTIALLY IMPLEMENTED]

**[PHYSICS]** Real dynamical systems theory:
- Nonlinear maps (logistic map, Rössler, Lorenz)
- Sensitive dependence on initial conditions
- Attracting sets in phase space with fractal structure
- Lyapunov exponents quantify chaos

**[IMPLEMENTED]** `StrangeAttractorAnalyzer.gd` tracks phase space trajectories of quantum state evolution. The density matrix diagonal (populations) traces paths through probability simplex.

**[PROPOSED]** Visualization and gameplay hook:

```gdscript
# Attractor detection in existing StrangeAttractorAnalyzer
func detect_attractor_type() -> String:
    var trajectory = get_recent_trajectory(100)  # Last 100 snapshots
    var lyapunov = estimate_lyapunov_exponent(trajectory)

    if lyapunov < -0.1:
        return "fixed_point"      # Stable equilibrium
    elif lyapunov < 0.1:
        return "limit_cycle"      # Periodic orbit
    else:
        return "strange_attractor"  # Chaotic
```

**[GAMEPLAY]**
- Fixed point: Predictable, low variance harvests
- Limit cycle: Rhythmic harvests, timing bonuses
- Strange attractor: High variance, occasional jackpots

**[SPECULATIVE]** Faction affinities to explore:
- Chaos-aligned factions (Cult of Drowned Star?) might thrive in strange attractor regimes
- Order-aligned factions (Archivists?) might prefer fixed points
- This needs playtesting to determine if it creates interesting choices

---

#### Berry Phase Accumulation [PHYSICS EXISTS, UI NEEDED]

**[PHYSICS]** Geometric phase is real and measurable:
- When a quantum state is transported around a closed loop in parameter space, it acquires a phase beyond the dynamical phase
- Berry phase γ = i∮⟨ψ|∇ψ⟩·dR (line integral of Berry connection)
- For density matrices: γ = Im(∫Tr(ρ dρ)) over a cycle
- This phase is geometric—it depends only on the path shape, not speed

**[IMPLEMENTED]** The Hamiltonian evolution `-i[H,ρ]` in `QuantumComputer.evolve()` naturally accumulates geometric phase. The phase information exists in the off-diagonal elements.

**[PROPOSED]** Extract and display accumulated phase:

```gdscript
# Add to BiomeBase or QuantumComputer
var berry_phase_accumulator: float = 0.0
var cycle_detector: CycleDetector = null  # Tracks return to initial state

func _track_berry_phase(dt: float) -> void:
    if not cycle_detector:
        return

    # [PHYSICS] Phase increment from density matrix evolution
    # This is a simplification - full Berry phase requires parallel transport
    var populations = _get_population_vector()
    var phase_contribution = cycle_detector.accumulate(populations, dt)
    berry_phase_accumulator += phase_contribution

    if cycle_detector.cycle_completed():
        var efficiency_bonus = 1.0 + abs(sin(berry_phase_accumulator)) * 0.2
        emit_signal("berry_cycle_complete", efficiency_bonus)
        berry_phase_accumulator = 0.0
```

**[GAMEPLAY]**
- Completing full cycles grants efficiency bonuses
- Interrupted cycles lose accumulated phase (no partial credit)
- Visual: Circular progress indicator showing phase accumulation

**[SPECULATIVE]** Faction exploration ideas:
- Factions with complex-valued Hamiltonian couplings (imaginary components) might accumulate Berry phase faster
- Could Loom Priests' "fate threads" be visualized as Berry phase windings?
- Needs mathematical verification that this creates meaningful gameplay differentiation

---

#### Monopole Resource Nodes [PROPOSED]

**[PHYSICS]** Magnetic monopoles:
- Hypothetical particles with isolated magnetic charge
- Never observed in nature, but can be created as "synthetic" gauge defects in condensed matter
- In quantum systems, monopoles appear as topological defects in gauge fields
- Dirac quantization: electric × magnetic charge = integer × ℏ/2

**[GAMEPLAY]** Simplified for playability:
- "Monopole" nodes provide unidirectional resource flow
- Unlike normal sources (which oscillate), monopoles emit steadily
- Implemented as icons with no `lindblad_incoming`—they only give, never receive

**[PROPOSED]** Implementation:

```gdscript
# In Icon or as special node type
var is_monopole: bool = false

# Monopole icons have:
# - lindblad_outgoing: normal rates
# - lindblad_incoming: empty (blocked)
# - hamiltonian_couplings: one-way (anti-Hermitian contribution)
```

**[SPECULATIVE]**
- Which factions might create monopole effects? Needs world-building consideration
- Could monopoles be rare drops from certain quest completions?
- Balance concern: Monopoles might be too powerful if not limited

---

#### Topological Insulator Pipes [PROPOSED]

**[PHYSICS]** Topological insulators are real:
- Materials that are insulators in bulk but conduct on edges/surfaces
- Edge conduction is topologically protected—robust against disorder
- SSH model (Su-Schrieffer-Heeger): 1D chain with alternating coupling strengths
- Bulk-boundary correspondence: bulk topology determines edge state existence

**[PHYSICS]** The SSH Hamiltonian:
```
H = Σᵢ (v c†ᵢ,ₐcᵢ,ᵦ + w c†ᵢ,ᵦcᵢ₊₁,ₐ + h.c.)

When |v| < |w|: topological phase with edge states
When |v| > |w|: trivial phase, no edge states
```

**[GAMEPLAY]** Translation for SpaceWheat:
- "Pipes" are chains of plots with alternating coupling strengths
- Information/resources flow along edges, protected from bulk corruption
- Semantic drift (🌀) affects bulk but not edges

**[PROPOSED]** Implementation path:

```gdscript
class_name TopologicalPipe
extends Resource

var segments: Array[Vector2i] = []  # Plot positions forming the pipe
var coupling_pattern: Array[float] = []  # Alternating v, w, v, w...

func is_topological() -> bool:
    # [PHYSICS] Check if in topological phase
    # Simplified: alternating strong-weak pattern
    var v_avg = 0.0
    var w_avg = 0.0
    for i in range(coupling_pattern.size()):
        if i % 2 == 0:
            v_avg += coupling_pattern[i]
        else:
            w_avg += coupling_pattern[i]
    v_avg /= coupling_pattern.size() / 2
    w_avg /= coupling_pattern.size() / 2
    return abs(v_avg) < abs(w_avg)

func get_edge_protection() -> float:
    # [GAMEPLAY] How much the edges resist decoherence
    if is_topological():
        return 0.9  # 90% decoherence reduction at edges
    return 0.0
```

**[SPECULATIVE]**
- Could faction territories naturally form topological/trivial phases based on their coupling preferences?
- Visual: Edge plots glow differently when pipe is in topological phase
- Needs playtesting to see if players intuitively grasp "alternating pattern = protection"

---

### Tier 0.5: Quantum Observation Tools [PROPOSED]
*"See before you manipulate"*

Before players can effectively use topology, they need to observe quantum state. This tier introduces visualization tools.

---

#### Purity Meters [IMPLEMENTED PHYSICS, UI NEEDED]

**[PHYSICS]** Purity Tr(ρ²) is a real quantum observable:
- Pure states: Tr(ρ²) = 1 (system in definite quantum state)
- Maximally mixed: Tr(ρ²) = 1/dim (complete uncertainty)
- Purity decreases under decoherence

**[IMPLEMENTED]** `QuantumComputer.get_purity()` computes Tr(ρ²)

**[PROPOSED]** UI visualization:

```gdscript
# In biome visualization or overlay
func draw_purity_indicator(biome: BiomeBase) -> void:
    var purity = biome.quantum_computer.get_purity()
    var min_purity = 1.0 / biome.quantum_computer.register_map.dim()

    # Normalize to 0-1 scale
    var normalized = (purity - min_purity) / (1.0 - min_purity)

    # Visual: Crystal clarity (pure) vs fog (mixed)
    var clarity = lerp(0.2, 1.0, normalized)
    # Draw biome with clarity-based transparency/sharpness
```

**[GAMEPLAY]**
- High purity: Predictable outcomes, harvests match expectations
- Low purity: Chaotic outcomes, high variance in yields
- Players learn to manage purity through faction/icon choices

---

#### Coherence Thermometers [IMPLEMENTED PHYSICS, UI NEEDED]

**[PHYSICS]** Coherence (off-diagonal density matrix elements) is physically meaningful:
- Represents quantum superposition between basis states
- |ρᵢⱼ|² bounded by ρᵢᵢ × ρⱼⱼ (Cauchy-Schwarz)
- Coherence enables interference effects
- Decays under dephasing (T2 processes)

**[IMPLEMENTED]** Density matrix stores full coherence information. `decoherence_coupling` affects decay rates.

**[PROPOSED]** Aggregate coherence measure:

```gdscript
func get_total_coherence() -> float:
    # [PHYSICS] Sum of off-diagonal magnitudes, normalized
    var dm = quantum_computer.density_matrix
    var dim = quantum_computer.register_map.dim()
    var total = 0.0
    var max_possible = 0.0

    for i in range(dim):
        for j in range(dim):
            if i != j:
                var c = dm.get_element(i, j)
                total += sqrt(c.re * c.re + c.im * c.im)
                # Max coherence when ρᵢᵢ = ρⱼⱼ = 1/dim
                max_possible += 1.0 / dim

    return total / max_possible if max_possible > 0 else 0.0
```

**[GAMEPLAY]**
- "Quantum temperature": High coherence = cold (quantum effects dominate), low = hot (classical)
- Visual: Color temperature of biome shifts with coherence

---

#### Eigenstate Compass [IMPLEMENTED]

**[PHYSICS]** Eigenstates of Hamiltonian are stationary states:
- H|ψₙ⟩ = Eₙ|ψₙ⟩
- System evolves toward dominant eigenstate under dissipation
- Eigenstate populations reveal system's "preferred" configuration

**[IMPLEMENTED]** `ProphecyEngine.compute_prophecy()` finds dominant eigenstates and returns them as "fate emojis."

**[PROPOSED]** Visual compass:

```gdscript
func draw_eigenstate_compass(biome: BiomeBase) -> void:
    var prophecy = ProphecyEngine.compute_prophecy(biome)
    var fate_emojis = prophecy.get("fate_emojis", [])

    # Draw compass pointing toward dominant eigenstate
    # Arrow strength = eigenstate stability (1 - entropy)
    var stability = prophecy.get("stability", 0.0)

    # Show top 3 fate emojis as compass directions
    for i in range(min(3, fate_emojis.size())):
        var emoji_data = fate_emojis[i]
        var angle = i * TAU / 3  # Spread around compass
        var weight = emoji_data.get("weight", 0.0)
        draw_compass_arm(angle, weight, emoji_data.get("emoji", "?"))
```

**[GAMEPLAY]**
- Compass shows where system "wants" to go
- Align with eigenstate: bonuses for working with the flow
- Fight eigenstate: harder but different rewards (rare drops?)

---

#### Entanglement Map [IMPLEMENTED PHYSICS, UI NEEDED]

**[PHYSICS]** Entanglement is real quantum correlation:
- Entangled systems have correlations stronger than any classical system
- Bell states: measuring one qubit instantly determines the other
- Quantified by entanglement entropy, concurrence, negativity

**[IMPLEMENTED]** `QuantumComputer.entanglement_graph` tracks which registers are entangled. `entangle_plots()` creates Bell states.

**[PROPOSED]** Visual network:

```gdscript
func draw_entanglement_web(biome: BiomeBase) -> void:
    var graph = biome.quantum_computer.entanglement_graph

    for reg_id in graph.keys():
        var partners = graph[reg_id]
        for partner_id in partners:
            # Draw glowing line between entangled plots
            var pos_a = get_plot_position(reg_id)
            var pos_b = get_plot_position(partner_id)

            # Line intensity = entanglement strength (coherence between them)
            var strength = get_entanglement_strength(reg_id, partner_id)
            draw_quantum_link(pos_a, pos_b, strength)
```

**[GAMEPLAY]**
- Visual web shows quantum connections
- Entangled plots harvest together (good or bad depending on timing)
- Breaking entanglement (measurement) severs the link

---

### Tier 1: Simple Optimization
*"Easy to use, clear benefits"*

---

#### Bell State Entanglement [IMPLEMENTED]

**[PHYSICS]** Bell states are maximally entangled 2-qubit states:
```
|Φ+⟩ = (|00⟩ + |11⟩) / √2
|Φ-⟩ = (|00⟩ - |11⟩) / √2
|Ψ+⟩ = (|01⟩ + |10⟩) / √2
|Ψ-⟩ = (|01⟩ - |10⟩) / √2
```
- Measuring one qubit instantly determines the other (spooky action)
- Bell inequality violations prove quantum nature
- Used in quantum teleportation, superdense coding

**[IMPLEMENTED]**
- `QuantumComputer.entangle_plots()` applies H then CNOT to create |Φ+⟩
- `bell_activated_features` in factions enable conditional mechanics
- Entanglement graph tracks connections

**[GAMEPLAY]**
- Entangled plots synchronize harvests
- Bell-activated features only trigger during entanglement
- Measurement of one affects both (correlated collapse)

**[SPECULATIVE]** Faction exploration:
- Could Knot-Shriners' "oaths" be implemented as Bell state creation with latent Lindblad channels?
- Do Liminal Taper's "bridges" work through entanglement?
- Needs design review to ensure faction identity remains distinct

---

#### Classical Knot Invariants [PROPOSED]

**[PHYSICS]** Knot theory is rigorous mathematics:
- Knots classified by invariants (crossing number, Jones polynomial, etc.)
- Reidemeister moves: local transformations that preserve knot type
- Linking number: how many times two curves wind around each other
- Borromean rings: three linked rings where no two are linked

**[GAMEPLAY]** Production chains as knots:
- Resource flows form "strands" through the factory
- Tangled strands create knot topology
- Knot invariant determines protection against disruption

**[PROPOSED]** Simple crossing-number implementation:

```gdscript
class_name ProductionKnot
extends Resource

var strands: Array[ProductionStrand] = []  # Resource flow paths

func get_crossing_number() -> int:
    # [PHYSICS] Count crossings in 2D projection
    var crossings = 0
    for i in range(strands.size()):
        for j in range(i + 1, strands.size()):
            crossings += count_intersections(strands[i], strands[j])
    return crossings

func get_protection_level() -> float:
    # [GAMEPLAY] More crossings = harder to untangle = more protected
    var crossings = get_crossing_number()
    return 1.0 - (1.0 / (1.0 + crossings * 0.5))
```

**[SPECULATIVE]**
- Visual: Production flows rendered as colored strands, crossings highlighted
- Could this connect to Loom Priests' thread imagery?
- Need to determine if crossing-based protection creates interesting player decisions

---

#### Quantum Chaos Amplifiers [PROPOSED]

**[PHYSICS]** Quantum chaos is real:
- Kicked rotor, quantum billiards, random matrix theory
- Sensitive dependence on initial conditions (butterfly effect)
- Ehrenfest time: how long quantum tracks classical chaos
- Level spacing statistics distinguish chaos from regularity

**[GAMEPLAY]** Controlled chaos for amplification:
- Small parameter changes create exponentially different outcomes
- Risk/reward: Chaos amplifies both gains and losses
- Players tune chaos parameters to balance risk

**[PROPOSED]** Chaos amplifier mechanic:

```gdscript
class_name ChaosAmplifier
extends Resource

var kick_strength: float = 0.1  # Player-adjustable
var base_yield: float = 1.0

func compute_amplified_yield(seed_value: float) -> float:
    # [PHYSICS] Logistic map: xₙ₊₁ = r × xₙ × (1 - xₙ)
    # Chaotic for r > 3.57
    var r = 3.0 + kick_strength * 1.0  # Range 3.0 to 4.0
    var x = seed_value

    # Iterate map
    for i in range(10):
        x = r * x * (1.0 - x)

    # [GAMEPLAY] Final value determines yield multiplier
    return base_yield * (0.5 + x * 1.5)  # Range 0.5x to 2.0x
```

**[SPECULATIVE]**
- Could chaos-aligned factions have higher default kick_strength?
- Visual: Bifurcation diagram showing player's position in parameter space
- Warning: Pure chaos might feel random rather than skillful—needs tuning

---

### Tier 2: Network Management
*"Requires understanding system interactions"*

---

#### Majorana Bridges [PROPOSED]

**[PHYSICS]** Majorana fermions and edge states are real:
- Majorana fermion: particle that is its own antiparticle (γ = γ†)
- Kitaev chain: 1D model where Majorana modes appear at wire ends
- Edge modes are topologically protected—immune to local perturbations
- Information stored nonlocally between two edge Majoranas

**[PHYSICS]** The Kitaev chain Hamiltonian:
```
H = -μ Σᵢ c†ᵢcᵢ - t Σᵢ (c†ᵢcᵢ₊₁ + h.c.) + Δ Σᵢ (cᵢcᵢ₊₁ + h.c.)

In topological phase (|μ| < 2t, Δ ≠ 0):
- Bulk is gapped (no low-energy excitations)
- Two Majorana zero modes γₗ, γᵣ at wire ends
- Together encode one fermion: f = (γₗ + iγᵣ)/2
```

**[GAMEPLAY]** Inter-biome communication without matrix explosion:

```
┌─────────────────┐                    ┌─────────────────┐
│    Biome A      │                    │     Biome B     │
│  8×8 density    │                    │   8×8 density   │
│    matrix       │                    │     matrix      │
│                 │                    │                 │
│   [edge plot]───┼──── Majorana ─────┼───[edge plot]   │
│                 │     Bridge        │                 │
│                 │    (2×2 only!)    │                 │
└─────────────────┘                    └─────────────────┘
```

**[PROPOSED]** Implementation:

```gdscript
class_name MajoranaBridge
extends Resource

## [PHYSICS] Bridge connects edge modes of two biomes
## Information stored nonlocally—neither biome "has" it alone

var biome_a: BiomeBase
var biome_b: BiomeBase
var edge_emoji_a: String  # Which emoji is A's edge
var edge_emoji_b: String  # Which emoji is B's edge

# [PHYSICS] The bridge state is just 2×2
# |00⟩: both edges in north state
# |01⟩: A-north, B-south
# |10⟩: A-south, B-north
# |11⟩: both edges in south state
var bridge_density_matrix: ComplexMatrix  # 2×2

# [PHYSICS] Bridge is protected from bulk decoherence
var topological_protection: float = 0.95  # 95% decoherence reduction

func evolve_bridge(dt: float) -> void:
    # [PHYSICS] Bridge has its own simple evolution
    # Couples to edge populations of each biome
    var p_a = biome_a.quantum_computer.get_population(edge_emoji_a)
    var p_b = biome_b.quantum_computer.get_population(edge_emoji_b)

    # Update bridge state based on edge populations
    _update_bridge_from_edges(p_a, p_b, dt)

    # Apply protected decoherence (much slower than bulk)
    _apply_protected_decoherence(dt)

func get_correlation() -> float:
    # [PHYSICS] Correlation between edge modes
    # C = ⟨σz⊗σz⟩ = P(00) + P(11) - P(01) - P(10)
    var p00 = bridge_density_matrix.get_element(0, 0).re
    var p01 = bridge_density_matrix.get_element(1, 1).re
    var p10 = bridge_density_matrix.get_element(2, 2).re
    var p11 = bridge_density_matrix.get_element(3, 3).re
    return p00 + p11 - p01 - p10

func send_signal(from_biome: BiomeBase, message: float) -> void:
    # [GAMEPLAY] Encode message in edge state, retrieve at other end
    # Protected from bulk 🌀 drift in either biome
    pass
```

**[GAMEPLAY]**
- Building bridges is expensive (requires specific edge infrastructure)
- Once built, biomes share correlations without full matrix merging
- Bridges resist semantic drift—chaos in bulk doesn't corrupt the channel
- Can "send" quantum information between biomes

**[SPECULATIVE]**
- Could Reality Midwives specialize in bridge construction?
- Do Void Shepherds use bridges to communicate across realms?
- Quest type: `ESTABLISH_MAJORANA_BRIDGE` with high rewards
- Needs careful balance—bridges shouldn't trivialize inter-biome logistics

---

#### Non-Abelian Anyonic Highways [PROPOSED]

**[PHYSICS]** Anyons are real (in 2D systems):
- In 3D: particles are bosons or fermions (exchange phase ±1)
- In 2D: particles can be anyons (exchange phase eⁱᶿ for any θ)
- Non-abelian anyons: exchange depends on ORDER of operations
- Fibonacci anyons: braiding implements universal quantum computation

**[PHYSICS]** Fibonacci anyon braiding:
```
Two anyons have fusion space: |0⟩, |1⟩ (vacuum or single anyon)
Braiding matrices:
σ₁ = [e⁴ⁱᵖ/⁵   0    ]    σ₂ = [φ⁻¹e⁻⁴ⁱᵖ/⁵   φ⁻¹/²e⁻²ⁱᵖ/⁵]
     [0    e⁻³ⁱᵖ/⁵]         [φ⁻¹/²e²ⁱᵖ/⁵     -φ⁻¹     ]

where φ = (1+√5)/2 (golden ratio)
```

**[GAMEPLAY]** Simplified braiding for routing:
- Resources as "anyons" that can be braided
- Different braid sequences produce different products
- Order matters! (A then B) ≠ (B then A)

**[PROPOSED]** Implementation:

```gdscript
class_name AnyonicHighway
extends Resource

## [PHYSICS] Tracks braid group element as sequence of generators
## σᵢ = clockwise exchange of anyons i and i+1
## σᵢ⁻¹ = counterclockwise exchange

var braid_sequence: Array[int] = []  # Positive = σᵢ, negative = σᵢ⁻¹
var num_strands: int = 3

func add_braid(generator: int) -> void:
    # [PHYSICS] Append to braid word
    braid_sequence.append(generator)

func compute_output_state() -> ComplexMatrix:
    # [PHYSICS] Apply braiding matrices in sequence
    var state = ComplexMatrix.identity(2)  # Start with identity

    for gen in braid_sequence:
        var braid_matrix = _get_fibonacci_braid_matrix(gen)
        state = braid_matrix.mul(state)

    return state

func _get_fibonacci_braid_matrix(generator: int) -> ComplexMatrix:
    # [PHYSICS] Real Fibonacci anyon braiding matrix
    var phi = (1.0 + sqrt(5.0)) / 2.0
    # ... construct matrix based on generator index and sign
    pass
```

**[GAMEPLAY]**
- Visual: Drag strands to create braid patterns
- Library of preset braid patterns for common operations
- Advanced: Design custom braids for specialized products

**[SPECULATIVE]**
- Could Loom Priests' weaving be non-abelian braiding?
- Pattern Weavers (if such a faction exists) as braid specialists?
- This is complex—might need to be Tier 3 or have extensive UI scaffolding

---

#### Fiber Bundle Conditional Operations [PROPOSED]

**[PHYSICS]** Fiber bundles are real mathematical structures:
- Base space B (parameter space)
- Fiber F attached at each point of B
- Total space E = union of all fibers
- Connection: rule for parallel transport between fibers
- Gauge theory is fiber bundle theory (electromagnetism, Standard Model)

**[PHYSICS]** Connection and curvature:
```
Connection 1-form A: tells how to transport between nearby fibers
Curvature 2-form F = dA + A∧A: measures failure of transport to be path-independent
Gauge transformation: different choices of local fiber coordinates
```

**[GAMEPLAY]** Conditional operations based on state:
- "Local chart" = rules that apply in specific region of parameter space
- Different charts for different (θ, φ) regions
- Transition functions handle boundaries between charts

**[PROPOSED]** Simplified implementation:

```gdscript
class_name FiberBundleRouter
extends Resource

## [GAMEPLAY] Routes operations based on quantum state coordinates
## [PHYSICS] Inspired by fiber bundle structure, simplified for playability

# Charts cover different regions of Bloch sphere
var charts: Dictionary = {}  # region_id → OperationTable

func add_chart(theta_range: Vector2, phi_range: Vector2, operations: Dictionary) -> void:
    var region_id = _compute_region_id(theta_range, phi_range)
    charts[region_id] = operations

func get_operation(theta: float, phi: float, operation_name: String) -> Callable:
    # Find which chart covers this point
    var region_id = _find_containing_region(theta, phi)
    if region_id in charts:
        return charts[region_id].get(operation_name, _default_operation)
    return _default_operation

func route_resource(resource: Resource, theta: float, phi: float) -> Resource:
    # [GAMEPLAY] Different processing based on state
    var operation = get_operation(theta, phi, "process")
    return operation.call(resource)
```

**[GAMEPLAY]**
- Preset "chart library" with common conditional patterns
- Advanced players can design custom charts
- Visual: Bloch sphere with colored regions showing active charts

---

### Tier 3: Advanced Physics Concepts
*"Requires understanding non-trivial quantum mechanics"*

---

#### Majorana Edge States (Boundary Production) [PROPOSED]

**[PHYSICS]** Edge states in topological systems:
- Bulk-boundary correspondence: nontrivial bulk topology implies edge states
- Edge states are robust—can't be removed without phase transition
- Majorana edge states in Kitaev wire carry zero energy
- Information processing at boundaries, not bulk

**[GAMEPLAY]** Production concentrated at boundaries:
- Build "Kitaev wire" infrastructure along biome edges
- Edge plots have dramatically reduced decoherence
- Bulk plots feed edges; edges produce high-quality output

**[PROPOSED]** Integration with existing infrastructure:

```gdscript
# Add to BiomeBase or create KitaevInfrastructure class

func is_edge_plot(position: Vector2i) -> bool:
    # [GAMEPLAY] Plots on biome boundary
    return position.x == 0 or position.x == grid_width - 1 or \
           position.y == 0 or position.y == grid_height - 1

func get_effective_decoherence(position: Vector2i, base_decoherence: float) -> float:
    if is_edge_plot(position) and has_kitaev_infrastructure():
        # [PHYSICS] Topological protection reduces decoherence
        return base_decoherence * 0.1  # 90% reduction
    return base_decoherence
```

---

#### Homotopy Production Paths [PROPOSED]

**[PHYSICS]** Homotopy is rigorous topology:
- Two paths are homotopic if one can be continuously deformed into the other
- Fundamental group π₁: equivalence classes of loops
- Higher homotopy groups πₙ: equivalence classes of n-spheres
- Path-connected space: any two points joined by path

**[GAMEPLAY]** Multiple equivalent production routes:
- Factory has multiple paths from input to output
- Paths in same homotopy class produce equivalent results
- Different classes produce different products

**[PROPOSED]** Path equivalence checker:

```gdscript
class_name HomotopyPathFinder
extends Resource

var production_space: Graph  # Nodes = states, edges = operations

func find_all_paths(start: String, end: String) -> Array[ProductionPath]:
    # Standard pathfinding
    pass

func classify_by_homotopy(paths: Array[ProductionPath]) -> Dictionary:
    # [PHYSICS] Group paths by homotopy class
    # [GAMEPLAY] Simplified: paths through same "obstacles" are equivalent
    var classes: Dictionary = {}

    for path in paths:
        var signature = _compute_winding_signature(path)
        if signature not in classes:
            classes[signature] = []
        classes[signature].append(path)

    return classes

func _compute_winding_signature(path: ProductionPath) -> String:
    # [GAMEPLAY] Which obstacles does path wind around?
    # [PHYSICS] This is a simplified winding number calculation
    var windings = []
    for obstacle in obstacles:
        var winding = _compute_winding_around(path, obstacle)
        windings.append("%s:%d" % [obstacle.id, winding])
    return ",".join(windings)
```

---

#### Quantum Spin Liquid Processing [PROPOSED]

**[PHYSICS]** Quantum spin liquids are real (and exotic):
- Frustrated magnets that don't order even at zero temperature
- Kitaev honeycomb model: exactly solvable spin liquid
- Emergent gauge fields and fractionalized excitations
- Long-range entanglement without local order

**[PHYSICS]** Frustration:
```
Triangle with antiferromagnetic coupling:
Each spin wants to anti-align with neighbors.
Can't satisfy all three constraints simultaneously.
System remains "liquid"—fluctuating, never frozen.
```

**[GAMEPLAY]** Competing constraints:
- Multiple resource demands that can't all be satisfied
- System finds "frustrated equilibrium"
- Fluctuations between competing states create interesting dynamics

**[PROPOSED]** Frustration mechanics:

```gdscript
class_name FrustrationNetwork
extends Resource

var nodes: Array[ResourceNode] = []
var constraints: Array[Constraint] = []  # Each wants specific allocations

func compute_frustration() -> float:
    # [PHYSICS] How much do constraints conflict?
    var total_conflict = 0.0
    for i in range(constraints.size()):
        for j in range(i + 1, constraints.size()):
            total_conflict += constraints[i].conflict_with(constraints[j])
    return total_conflict

func find_equilibrium() -> Dictionary:
    # [GAMEPLAY] Find allocation that minimizes total dissatisfaction
    # [PHYSICS] Like finding ground state of frustrated system
    pass
```

---

### Tier 4: Systems Engineering
*"Managing complexity through mathematics"*

---

#### Quantum Error Correction [PROPOSED]

**[PHYSICS]** QEC is real and essential for quantum computing:
- Quantum information is fragile (decoherence, gate errors)
- Can't clone quantum states (no-cloning theorem)
- But CAN encode in subspace protected against certain errors
- Surface codes, stabilizer codes, topological codes

**[PHYSICS]** Stabilizer formalism:
```
Stabilizer group S ⊂ Pauli group
Code space = states |ψ⟩ where s|ψ⟩ = |ψ⟩ for all s ∈ S
Errors detected by measuring stabilizers (syndrome)
Correction applied based on syndrome
```

**[GAMEPLAY]** Factory immune system:
- Encode important production states in error-correcting codes
- Toggle stabilizer measurements to detect corruption
- Apply corrections to maintain production quality

**[PROPOSED]** Simple repetition code as introduction:

```gdscript
class_name QuantumErrorCorrector
extends Resource

## [PHYSICS] Implements simple repetition code
## Real QEC uses more sophisticated codes (surface, color, etc.)

var code_distance: int = 3  # Can correct (d-1)/2 errors
var physical_qubits: int = 3
var logical_qubits: int = 1

func encode(logical_state: ComplexMatrix) -> ComplexMatrix:
    # [PHYSICS] |0⟩_L → |000⟩, |1⟩_L → |111⟩
    pass

func measure_syndrome() -> Array[int]:
    # [PHYSICS] Measure stabilizers Z₁Z₂, Z₂Z₃
    # Returns syndrome bits indicating which errors occurred
    pass

func apply_correction(syndrome: Array[int]) -> void:
    # [PHYSICS] Flip qubits based on syndrome
    # Majority vote decoding for repetition code
    pass
```

---

#### Hamiltonian Production Flows [PHYSICS EXISTS, GAMEPLAY PROPOSED]

**[PHYSICS]** Hamiltonian mechanics is fundamental:
- Symplectic geometry: phase space with special structure
- Hamilton's equations: dq/dt = ∂H/∂p, dp/dt = -∂H/∂q
- Conserved quantities (energy, momentum) from symmetries
- Integrable systems: as many conserved quantities as degrees of freedom

**[IMPLEMENTED]** The Lindblad evolution already uses Hamiltonian:
```gdscript
# In QuantumComputer.evolve()
# Hamiltonian term: -i[H, ρ]
var commutator = hamiltonian.commutator(density_matrix)
var neg_i = Complex.new(0.0, -1.0)
drho = drho.add(commutator.scale(neg_i))
```

**[GAMEPLAY]** Energy-conserving production:
- Identify conserved quantities in production system
- Design flows that preserve these quantities
- Avoid wasteful processes that break conservation

**[PROPOSED]** Conservation tracker:

```gdscript
func track_conserved_quantities() -> Dictionary:
    # [PHYSICS] Trace over commuting observables
    var H = quantum_computer.hamiltonian
    var rho = quantum_computer.density_matrix

    var conserved = {}
    conserved["energy"] = H.mul(rho).trace().re  # ⟨H⟩ = Tr(Hρ)

    # [GAMEPLAY] Track production-relevant quantities
    for observable_name in tracked_observables:
        var O = get_observable(observable_name)
        conserved[observable_name] = O.mul(rho).trace().re

    return conserved
```

---

### Tier 5: Meta-System Design
*"Designing systems that design systems"*

---

#### Many-Worlds Navigation [PROPOSED]

**[PHYSICS]** Everettian quantum mechanics (speculative interpretation):
- Wavefunction never collapses—universe branches
- All outcomes happen in different branches
- Observers experience single branch (no memory of others)
- Controversial among physicists—treat as Monte Carlo branching for game

**[GAMEPLAY]** Parallel timeline management:
- Fork game state at decision points
- Explore multiple branches simultaneously
- Collapse to best outcome (with cost)

**[PROPOSED]** Implementation as Monte Carlo:

```gdscript
class_name BranchingSimulator
extends Resource

## [GAMEPLAY] NOT claiming literal many-worlds interpretation
## Using branching as Monte Carlo optimization tool

var branches: Array[GameState] = []
var max_branches: int = 8

func fork_at_decision(base_state: GameState, options: Array) -> void:
    for option in options:
        var branch = base_state.duplicate()
        branch.apply_decision(option)
        branches.append(branch)

    # Prune to max branches (keep most promising)
    if branches.size() > max_branches:
        branches.sort_custom(_compare_branch_value)
        branches = branches.slice(0, max_branches)

func collapse_to_best() -> GameState:
    # [GAMEPLAY] Choose best branch, discard others
    branches.sort_custom(_compare_branch_value)
    var best = branches[0]
    branches.clear()
    return best
```

---

#### K-Theory Asset Management [PROPOSED]

**[PHYSICS]** K-theory is real algebraic topology:
- Classifies vector bundles over topological spaces
- K⁰(X) = equivalence classes of vector bundles on X
- Stable equivalence: E ~ F if E ⊕ trivial = F ⊕ trivial
- K-theory of point = integers (dimension of vector space)

**[GAMEPLAY]** Grouping equivalent production assets:
- Many machines may be "equivalent" in production capability
- K-theory-inspired classification groups them
- Manage groups rather than individuals

**[PROPOSED]** Asset classifier:

```gdscript
class_name KTheoryAssetManager
extends Resource

## [GAMEPLAY] Groups assets by "stable equivalence"
## Inspired by K-theory but simplified for playability

var equivalence_classes: Dictionary = {}  # class_id → Array[Asset]

func classify_asset(asset: Asset) -> String:
    # [GAMEPLAY] Compute equivalence class
    # Assets with same "production signature" are equivalent
    var signature = _compute_production_signature(asset)
    return signature

func _compute_production_signature(asset: Asset) -> String:
    # What inputs → what outputs at what rates?
    # Ignore superficial differences (color, position, etc.)
    var inputs = asset.get_input_types().sorted()
    var outputs = asset.get_output_types().sorted()
    var rate_class = _quantize_rate(asset.get_throughput())
    return "%s→%s@%s" % [inputs, outputs, rate_class]
```

---

### Tier 6: Reality Engineering
*"Transcendent complexity requiring deep mathematical intuition"*

---

#### Semantic Manifold Navigation [PROPOSED]

**[PHYSICS]** Word embeddings have geometric structure:
- Word2vec, GloVe, transformer embeddings map words to vectors
- Semantic relationships ≈ vector arithmetic (king - man + woman ≈ queen)
- Embedding space has metric (cosine similarity, Euclidean distance)
- Can treat as Riemannian manifold with semantic metric tensor

**[GAMEPLAY]** Optimize meaning itself:
- Wheat varieties have positions in semantic space
- Imperial preferences define target region
- Navigate production toward preferred semantic coordinates

**[PROPOSED]** Semantic distance mechanics:

```gdscript
class_name SemanticManifold
extends Resource

## [GAMEPLAY] Products have positions in meaning-space
## Closer to Imperial preferences = more valuable

var embedding_dim: int = 64
var product_embeddings: Dictionary = {}  # product_id → Vector (PackedFloat64Array)
var imperial_preference: PackedFloat64Array  # Target in semantic space

func set_product_embedding(product_id: String, embedding: PackedFloat64Array) -> void:
    product_embeddings[product_id] = embedding

func get_semantic_value(product_id: String) -> float:
    if product_id not in product_embeddings:
        return 0.0

    var product_vec = product_embeddings[product_id]

    # [PHYSICS] Cosine similarity in embedding space
    var dot = 0.0
    var norm_p = 0.0
    var norm_i = 0.0

    for i in range(embedding_dim):
        dot += product_vec[i] * imperial_preference[i]
        norm_p += product_vec[i] * product_vec[i]
        norm_i += imperial_preference[i] * imperial_preference[i]

    var similarity = dot / (sqrt(norm_p) * sqrt(norm_i))

    # [GAMEPLAY] Similarity → value multiplier
    return 1.0 + similarity * 2.0  # Range: -1.0 to 3.0

func navigate_toward_preference(product_id: String, step_size: float) -> void:
    # [GAMEPLAY] Shift product embedding toward Imperial preference
    # [PHYSICS] Gradient descent on semantic manifold
    pass
```

---

#### TQFT Factories [PROPOSED]

**[PHYSICS]** Topological Quantum Field Theory is real mathematics:
- Assigns vector spaces to manifolds, linear maps to cobordisms
- Independent of metric—only topology matters
- Atiyah-Segal axioms formalize the structure
- Examples: Chern-Simons theory, Dijkgraaf-Witten theory

**[PHYSICS]** TQFT axioms (simplified):
```
- (d-1)-manifold M → vector space Z(M)
- d-manifold W with boundary M → vector Z(W) ∈ Z(M)
- Gluing: Z(W₁ ∪ W₂) = Z(W₁) ⊗ Z(W₂) (with appropriate boundaries)
- Dimension independence: same rules work in any dimension
```

**[GAMEPLAY]** Dimension-independent production:
- Design factories that work regardless of space layout
- Rules depend only on topology (connections), not geometry (distances)
- Ultimate abstraction: production as pure structure

**[PROPOSED]** TQFT factory template:

```gdscript
class_name TQFTFactory
extends Resource

## [GAMEPLAY] Factory design independent of physical layout
## [PHYSICS] Inspired by TQFT axioms

# Boundary types (what goes in/out)
var input_boundary: Array[String] = []   # Resource types accepted
var output_boundary: Array[String] = []  # Resource types produced

# Cobordism (transformation rules)
var transformation_rules: Dictionary = {}  # input_config → output_config

func process(inputs: Dictionary) -> Dictionary:
    # [GAMEPLAY] Apply transformation regardless of physical arrangement
    var config_key = _encode_config(inputs)
    if config_key in transformation_rules:
        return transformation_rules[config_key]
    return {}
```

---

## Part 3: Emergent Mechanics from Faction Combinations

**[SPECULATIVE]** The following are exploratory ideas for how faction interactions might create emergent topology. These need design review and playtesting.

---

### Drift Stabilization Loops

**Concept:**
- Chaos-generating factions (high 🌀 production)
- Stability-generating factions (high ✨ production)
- When both present, system oscillates between chaos and order

**Possible Emergent Behavior:**
- Oscillation itself traces path in phase space
- Path accumulates Berry phase
- Tuning faction balance → tuning oscillation frequency → tuning phase accumulation

**Questions to Explore:**
- Which specific factions should have this interaction?
- How do players discover this emergent mechanic?
- Is this fun or just complex?

---

### Entanglement Cascades

**Concept:**
- Some factions have `bell_activated_features`
- Activated features might create NEW couplings
- New couplings might enable MORE entanglement

**Possible Emergent Behavior:**
- Initial entanglement triggers cascade
- Self-propagating entanglement network
- Could create large-scale quantum correlations

**Questions to Explore:**
- How to prevent runaway cascades?
- Should cascades be reversible?
- What's the gameplay value?

---

### Decoherence Gradients

**Concept:**
- Factions with positive `decoherence_coupling` on one side
- Factions with negative `decoherence_coupling` on other side
- Creates directional "decoherence flow"

**Possible Emergent Behavior:**
- Information flows from coherent (cold) to decoherent (hot) regions
- Like heat flow, but for quantum coherence
- Could implement one-way channels without explicit infrastructure

**Physics Basis:**
- Second law of thermodynamics: entropy increases
- Decoherence is entropy production
- Flow from low to high entropy is natural

**Questions to Explore:**
- Is this the right metaphor for players?
- How visible should the gradient be?
- Does this create interesting strategic choices?

---

## Part 4: Mathematical Prerequisites by Tier

| Tier | Mechanic | Prerequisites | Player Can Learn In-Game? |
|------|----------|---------------|---------------------------|
| 0 | Strange Attractors | Iteration, patterns | Yes - visual |
| 0 | Berry Phase | Cycles, accumulation | Yes - cycle counter |
| 0.5 | Purity | Probability, mixing | Yes - meter |
| 0.5 | Coherence | Superposition concept | Yes - thermometer |
| 1 | Bell States | Correlation, pairs | Yes - entanglement web |
| 1 | Knot Invariants | Crossings, linking | Yes - visual strands |
| 2 | Majorana Bridges | Edges vs bulk | Partially - needs tutorial |
| 2 | Anyonic Braiding | Order of operations | Partially - practice |
| 3 | Edge States | Boundary protection | Needs tutorial |
| 3 | Homotopy | Path equivalence | Needs visualization |
| 4 | QEC | Redundancy, errors | Needs tutorial |
| 4 | Hamiltonian Flows | Conservation | Partially - tracking UI |
| 5 | Many-Worlds | Branching, selection | Yes - timeline UI |
| 5 | K-Theory | Equivalence classes | Partially - grouping UI |
| 6 | Semantic Manifolds | Vector spaces, distance | Needs introduction |
| 6 | TQFT | Abstract structure | Requires significant prep |

---

## Part 5: Failure Modes (Learning Through Consequences)

| Mechanic | Failure Mode | Physics Lesson | Player Experience |
|----------|--------------|----------------|-------------------|
| Berry Phase | Incomplete cycle | Phase requires closed loop | "My bonus vanished when I stopped early!" |
| Bell States | Measure one partner | Entanglement destroyed by measurement | "Why did both fields collapse?!" |
| Majorana Bridge | Bulk corruption spreads | Topological protection has limits | "Even the bridge failed eventually..." |
| Anyonic Braiding | Wrong braid order | Non-abelian means order matters | "AB ≠ BA, lesson learned" |
| QEC | Too many errors | Error thresholds exist | "Overwhelmed the correction" |
| Semantic Manifolds | Wrong metric | Geometry of meaning has structure | "Close in distance, far in meaning" |

---

## Part 6: Implementation Priorities

### Phase 1: Observation Tools (Foundation)
1. Purity meter UI
2. Coherence thermometer UI
3. Eigenstate compass UI
4. Entanglement web visualization

### Phase 2: Tier 0-1 Mechanics
1. Berry phase accumulation + cycle detection
2. Strange attractor classification
3. Basic knot invariant computation
4. Chaos amplifier parameter tuning

### Phase 3: Inter-Biome Infrastructure
1. Majorana bridge implementation
2. Edge state mechanics in biomes
3. Cross-biome correlation tracking

### Phase 4: Advanced Mechanics
1. Anyonic braiding with visual UI
2. Fiber bundle conditional routing
3. Quantum error correction (simple codes)

### Phase 5: Meta-Systems
1. Many-worlds branching (as Monte Carlo)
2. K-theory asset classification
3. Semantic manifold navigation

---

## Appendix A: Code Mapping

| Document Concept | Existing Code | Status |
|------------------|---------------|--------|
| Density matrix | `QuantumComputer.density_matrix` | ✅ |
| Lindblad evolution | `QuantumComputer.evolve()` | ✅ |
| Hamiltonian | `QuantumComputer.hamiltonian` | ✅ |
| Purity | `QuantumComputer.get_purity()` | ✅ |
| Bell states | `QuantumComputer.entangle_plots()` | ✅ |
| Eigenstate analysis | `ProphecyEngine.compute_prophecy()` | ✅ |
| Semantic drift | `SemanticDrift.apply_drift()` | ✅ |
| Decoherence coupling | `Icon.decoherence_coupling` metadata | ✅ |
| Bell-activated features | `Faction.bell_activated_features` | ✅ |
| Attractor tracking | `StrangeAttractorAnalyzer` | ✅ |
| Berry phase extraction | — | 🔲 Proposed |
| Majorana bridges | — | 🔲 Proposed |
| Knot invariants | — | 🔲 Proposed |
| Anyonic braiding | — | 🔲 Proposed |
| QEC codes | — | 🔲 Proposed |
| Semantic manifolds | — | 🔲 Proposed |

---

## Appendix B: Glossary

**[PHYSICS]** terms with rigorous definitions:

- **Berry Phase**: Geometric phase acquired by quantum state transported around closed loop in parameter space
- **Coherence**: Off-diagonal elements of density matrix; quantum superposition between basis states
- **Decoherence**: Loss of coherence due to environment interaction; transition from quantum to classical
- **Density Matrix**: ρ, positive semi-definite Hermitian matrix with Tr(ρ)=1; describes mixed quantum states
- **Eigenstate**: State |ψ⟩ satisfying H|ψ⟩ = E|ψ⟩ for Hamiltonian H; stationary under time evolution
- **Entanglement**: Quantum correlations between subsystems that cannot be explained classically
- **Hamiltonian**: Hermitian operator generating time evolution; H determines energy eigenvalues
- **Lindblad**: Master equation for open quantum systems; includes both unitary and dissipative evolution
- **Majorana Fermion**: Particle that is its own antiparticle; γ = γ†
- **Purity**: Tr(ρ²); equals 1 for pure states, < 1 for mixed states
- **Topological Protection**: Robustness of quantum properties due to topology rather than energetics

**[GAMEPLAY]** terms specific to SpaceWheat:

- **Biome**: Game region with its own QuantumComputer and faction mix
- **Faction**: Group contributing weighted parameters to icon physics
- **Icon**: Emoji-represented quantum state node with physics properties
- **Plot**: Grid position where player interacts with quantum state
- **Semantic Drift**: 🌀-driven random perturbation of icon couplings

---

*Document Version: 1.0*
*Last Updated: After quantum substrate implementation*
*Status: Living document—will evolve with implementation*
