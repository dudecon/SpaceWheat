class_name DualEmojiQubit
extends Resource

const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

## DualEmojiQubit - Stateless Projection Lens (Model B - Physics Correct)
##
## Model B: This is a read-only view into a QuantumComponent's subspace.
## All quantum state lives in the parent biome's QuantumComputer.
## This class only provides measurement basis labels and view properties.
##
## Key properties:
## - No stored quantum state - all computed from parent quantum computer
## - No "energy" - energy is Hamiltonian observable only
## - "radius" is Bloch vector length (1 = pure, <1 = mixed)
## - "purity" is Tr(ρ²) of the 2×2 reduced density matrix

## ========================================
## Projection Basis (measurement labels)
## ========================================

@export var north_emoji: String = ""
@export var south_emoji: String = ""

## ========================================
## State References (Model B)
## ========================================

var register_id: int = -1  # Logical qubit ID in quantum computer
var parent_biome: Node = null  # BiomeBase that owns quantum state

# Legacy: QuantumBath reference (deprecated, for backward compat)
var bath: RefCounted = null  # QuantumBath reference (if using old bath mode)
var plot_position: Vector2i = Vector2i.ZERO

## ========================================
## Computed Properties (Model B - from quantum computer)
## ========================================

## Helper: Get probability marginal from quantum computer (Model B)
func _get_marginal_from_computer() -> Dictionary:
	"""Query marginal density matrix from parent biome's quantum computer."""
	if not parent_biome or register_id < 0:
		return {}

	var comp = parent_biome.quantum_computer.get_component_containing(register_id)
	if not comp:
		return {}

	var marginal = parent_biome.quantum_computer.get_marginal_density_matrix(comp, register_id)
	if not marginal:
		return {}

	# Extract probabilities
	var p0 = marginal.get_element(0, 0).re
	var p1 = marginal.get_element(1, 1).re
	var coh = marginal.get_element(0, 1)

	return {
		"p_north": p0,
		"p_south": p1,
		"coherence": coh,
		"p_subspace": p0 + p1
	}

## Theta: polar angle on Bloch sphere [0, π] (computed from marginal)
var theta: float:
	get:
		var marginal = _get_marginal_from_computer()
		if marginal.is_empty():
			# Fallback to legacy bath if available
			if bath:
				var proj = bath.project_onto_axis(north_emoji, south_emoji)
				return proj.get("theta", PI / 2.0)
			return PI / 2.0

		var p0 = marginal.get("p_north", 0.5)
		var p_total = marginal.get("p_subspace", 1.0)
		if p_total < 1e-10:
			return PI / 2.0

		# θ = 2 arccos(√(p0/p_total))
		return 2.0 * acos(sqrt(max(0.0, p0 / p_total)))

## Phi: azimuthal angle on Bloch sphere [0, 2π) (relative phase)
var phi: float:
	get:
		var marginal = _get_marginal_from_computer()
		if marginal.is_empty():
			# Fallback to legacy bath
			if bath:
				var proj = bath.project_onto_axis(north_emoji, south_emoji)
				return proj.get("phi", 0.0)
			return 0.0

		var coh = marginal.get("coherence", Complex.zero())
		if coh.abs() < 1e-10:
			return 0.0

		# φ = arg(ρ_01)
		return coh.get_angle()

## Radius: Bloch vector length [0, 1] (from coherence)
var radius: float:
	get:
		var marginal = _get_marginal_from_computer()
		if marginal.is_empty():
			if bath:
				var proj = bath.project_onto_axis(north_emoji, south_emoji)
				return proj.get("radius", 0.0)
			return 0.0

		var p0 = marginal.get("p_north", 0.0)
		var p1 = marginal.get("p_south", 0.0)
		var coh = marginal.get("coherence", Complex.zero())

		if p0 + p1 < 1e-10:
			return 0.0

		# radius = |ρ_01| / sqrt(p0 * p1) = coherence visibility
		var denom = sqrt(max(1e-10, p0 * p1))
		return coh.abs() / denom

## Purity: Tr(ρ²) of the 2×2 reduced density matrix
var purity: float:
	get:
		var marginal = _get_marginal_from_computer()
		if marginal.is_empty():
			if bath:
				var proj = bath.project_onto_axis(north_emoji, south_emoji)
				return proj.get("purity", 0.5)
			return 0.5

		# Compute Tr(ρ²) from marginal
		# This should come directly from parent_biome.quantum_computer.get_marginal_purity()
		# For now, approximate from probabilities
		var p0 = marginal.get("p_north", 0.0)
		var p1 = marginal.get("p_south", 0.0)
		var coh_sq = marginal.get("coherence", Complex.zero()).abs_sq()

		return p0*p0 + p1*p1 + 2.0*coh_sq

## Probability in subspace: P(north) + P(south)
var subspace_probability: float:
	get:
		var marginal = _get_marginal_from_computer()
		if marginal.is_empty():
			if bath:
				var proj = bath.project_onto_axis(north_emoji, south_emoji)
				return proj.get("p_subspace", 0.0)
			return 0.0

		return marginal.get("p_subspace", 0.0)

## ========================================
## SubspaceProbe Interface (Manifest Section 2)
## ========================================

## Mass: Subspace population p_sub = ρ_nn + ρ_ss
## Manifest terminology for "how much stuff is in the window"
var mass: float:
	get:
		return subspace_probability

## Order: Coherence visibility |ρ_ns| / p_sub
## Manifest terminology for "how quantum-ordered it is"
var order: float:
	get:
		if subspace_probability < 1e-10:
			return 0.0
		var marginal = _get_marginal_from_computer()
		if marginal.is_empty():
			# Fallback to legacy bath
			if bath:
				var coherence = bath.get_coherence(north_emoji, south_emoji)
				return coherence.abs() / subspace_probability
			return 0.0
		var coh = marginal.get("coherence", Complex.zero())
		return coh.abs() / subspace_probability

## Get reduced 2×2 density matrix ρ_sub
## Returns the block [[ρ_nn, ρ_ns], [ρ_sn, ρ_ss]] from parent biome's quantum computer
func get_rho_subspace() -> ComplexMatrix:
	# Model B: Query from parent_biome's quantum computer
	if parent_biome and register_id >= 0:
		var comp = parent_biome.quantum_computer.get_component_containing(register_id)
		if comp:
			var rho_sub = parent_biome.quantum_computer.get_marginal_density_matrix(comp, register_id)
			if rho_sub:
				return rho_sub

	# Fallback: legacy bath (backward compat)
	if bath and bath._density_matrix:
		var n_idx = bath._density_matrix.emoji_to_index.get(north_emoji, -1)
		var s_idx = bath._density_matrix.emoji_to_index.get(south_emoji, -1)

		if n_idx >= 0 and s_idx >= 0:
			var full_rho = bath._density_matrix.get_matrix()
			var rho_sub = ComplexMatrix.new(2)

			# Extract 2×2 block
			rho_sub.set_element(0, 0, full_rho.get_element(n_idx, n_idx))  # ρ_nn
			rho_sub.set_element(0, 1, full_rho.get_element(n_idx, s_idx))  # ρ_ns
			rho_sub.set_element(1, 0, full_rho.get_element(s_idx, n_idx))  # ρ_sn
			rho_sub.set_element(1, 1, full_rho.get_element(s_idx, s_idx))  # ρ_ss

			return rho_sub

	# Ultimate fallback: maximally mixed 2×2 state
	var fallback = ComplexMatrix.new(2)
	fallback.set_element(0, 0, Complex.new(0.5, 0.0))
	fallback.set_element(1, 1, Complex.new(0.5, 0.0))
	return fallback

## Get normalized viewport state: ρ_sub / p_sub (visual only)
## Manifest: "Normalized viewport state for visualization"
func get_rho_subspace_norm() -> ComplexMatrix:
	var rho_sub = get_rho_subspace()
	var p_sub = mass

	if p_sub < 1e-10:
		# No population - return maximally mixed
		var maximally_mixed = ComplexMatrix.new(2)
		maximally_mixed.set_element(0, 0, Complex.new(0.5, 0.0))
		maximally_mixed.set_element(1, 1, Complex.new(0.5, 0.0))
		return maximally_mixed

	# Normalize: ρ_norm = ρ_sub / Tr(ρ_sub)
	var rho_norm = ComplexMatrix.new(2)
	for i in range(2):
		for j in range(2):
			var element = rho_sub.get_element(i, j)
			rho_norm.set_element(i, j, element.div_scalar(p_sub))

	return rho_norm

## ========================================
## Entanglement Tracking (preserved from legacy)
## ========================================

var entangled_pair: Resource = null
var is_qubit_a: bool = true
var entangled_cluster: Resource = null
var cluster_qubit_index: int = -1

## Berry phase accumulation (visualization aid)
var berry_phase: float = 0.0
var berry_phase_rate: float = 1.0

## Entanglement graph (topological relationships)
var entanglement_graph: Dictionary = {}

## ========================================
## Constructor
## ========================================

func _init(north: String = "", south: String = "", _unused_theta: float = PI/2, bath_ref: RefCounted = null):
	north_emoji = north
	south_emoji = south
	bath = bath_ref
	berry_phase = 0.0

## ========================================
## Projection Methods
## ========================================

## Get full projection data from bath
func get_projection() -> Dictionary:
	if not bath:
		return {
			"theta": PI / 2.0,
			"phi": 0.0,
			"radius": 0.0,
			"purity": 0.5,
			"valid": false
		}
	return bath.project_onto_axis(north_emoji, south_emoji)

## Get Bloch vector
func get_bloch_vector() -> Vector3:
	var x = sin(theta) * cos(phi)
	var y = sin(theta) * sin(phi)
	var z = cos(theta)
	return Vector3(x, y, z) * radius

## Get semantic state description
func get_semantic_state() -> String:
	if theta < PI / 4.0:
		return north_emoji
	elif theta > 3.0 * PI / 4.0:
		return south_emoji
	else:
		return north_emoji + "↔" + south_emoji

## ========================================
## Probability Methods
## ========================================

## Get north amplitude magnitude (for backwards compatibility)
func get_north_amplitude() -> float:
	return cos(theta / 2.0)

## Get south amplitude magnitude
func get_south_amplitude() -> float:
	return sin(theta / 2.0)

## Get north probability: P(north) = cos²(θ/2)
func get_north_probability() -> float:
	return pow(cos(theta / 2.0), 2)

## Get south probability: P(south) = sin²(θ/2)
func get_south_probability() -> float:
	return pow(sin(theta / 2.0), 2)

## Get coherence (same as radius for this projection)
func get_coherence() -> float:
	return radius

## ========================================
## Measurement
## ========================================

## Measure qubit in {north, south} basis
## Collapses the quantum state and returns the outcome (MEASURE operation)
func measure() -> String:
	# Model B: Measure via parent_biome's quantum computer
	if parent_biome and register_id >= 0:
		var comp = parent_biome.quantum_computer.get_component_containing(register_id)
		if comp:
			var outcome = parent_biome.quantum_computer.measure_register(comp, register_id)
			return outcome

	# Fallback: legacy bath measurement (backward compat)
	if bath:
		var outcome = bath.measure_axis(north_emoji, south_emoji, 1.0)  # Full collapse
		return outcome

	push_warning("DualEmojiQubit.measure(): No quantum computer or bath reference")
	return ""


## Inspect qubit WITHOUT collapsing state (INSPECT operation - Phase 2)
func inspect() -> Dictionary:
	"""Non-destructive inspection of measurement probabilities.

	Returns probabilities without affecting quantum state.
	Model B: Phase 2 - INSPECT operation.

	Returns:
		Dictionary with:
		- "north": Probability in north basis
		- "south": Probability in south basis
		- "total": Total probability in subspace
	"""
	# Model B: Inspect via parent_biome's quantum computer
	if parent_biome and register_id >= 0:
		var comp = parent_biome.quantum_computer.get_component_containing(register_id)
		if comp:
			return parent_biome.quantum_computer.inspect_register_distribution(comp, register_id)

	# Fallback: legacy bath inspection (backward compat)
	if bath:
		return bath.inspect_axis(north_emoji, south_emoji)

	push_warning("DualEmojiQubit.inspect(): No quantum computer or bath reference")
	return {"north": 0.0, "south": 0.0, "total": 0.0}


## Batch measure entire entangled component (Phase 3 - Spooky Action at Distance)
func batch_measure() -> Dictionary:
	"""Measure entire entangled component when one qubit is measured.

	Manifest Section 4.2: Batch measurement - one measurement collapses entire component.
	Implements "spooky action at a distance": all qubits in component are measured.

	Returns:
		Dictionary mapping qubit positions to outcomes (legacy format)
		For single qubit: returns self outcome in {"0": outcome} format
	"""
	# Model B: Batch measure via parent_biome's quantum computer
	if parent_biome and register_id >= 0:
		var comp = parent_biome.quantum_computer.get_component_containing(register_id)
		if comp:
			var all_outcomes = parent_biome.quantum_computer.batch_measure_component(comp)
			# Return just this qubit's outcome in legacy format
			var my_outcome = all_outcomes.get(register_id, "")
			return {"0": my_outcome}

	# Fallback: single qubit measurement via bath
	if bath:
		var outcome = bath.measure_axis(north_emoji, south_emoji, 1.0)
		return {"0": outcome}

	push_warning("DualEmojiQubit.batch_measure(): No quantum computer or bath reference")
	return {}

## ========================================
## Berry Phase (Visualization Aid)
## ========================================

func accumulate_berry_phase(evolution_amount: float, dt: float = 1.0) -> void:
	berry_phase += evolution_amount * berry_phase_rate * dt
	berry_phase = clamp(berry_phase, 0.0, 10.0)

func get_berry_phase() -> float:
	return berry_phase

func get_berry_phase_normalized() -> float:
	return berry_phase / 10.0

## ========================================
## Entanglement Graph (Topological Relationships)
## ========================================

func add_graph_edge(relationship_emoji: String, target_emoji: String) -> void:
	if not entanglement_graph.has(relationship_emoji):
		entanglement_graph[relationship_emoji] = []
	if not entanglement_graph[relationship_emoji].has(target_emoji):
		entanglement_graph[relationship_emoji].append(target_emoji)

func get_graph_targets(relationship_emoji: String) -> Array:
	return entanglement_graph.get(relationship_emoji, [])

func has_graph_edge(relationship_emoji: String, target_emoji: String) -> bool:
	return entanglement_graph.get(relationship_emoji, []).has(target_emoji)

func get_all_relationships() -> Array:
	return entanglement_graph.keys()

## ========================================
## Entanglement Status Helpers
## ========================================

func is_in_pair() -> bool:
	return entangled_pair != null

func is_in_cluster() -> bool:
	return entangled_cluster != null

## ========================================
## Environmental Modulation (Legacy Helpers)
## ========================================

func water_probability() -> float:
	return get_north_probability()

func sun_probability() -> float:
	return get_south_probability()

## ========================================
## Debug
## ========================================

func get_debug_string() -> String:
	var state = get_semantic_state()
	var graph_info = ""
	if entanglement_graph.size() > 0:
		graph_info = " | Graph: %d relationships" % entanglement_graph.size()
	return "%s | θ=%.2f φ=%.2f r=%.2f | P=%.2f%s" % [
		state, theta, phi, radius, purity, graph_info
	]

func _to_string() -> String:
	return "DualEmojiQubit(%s↔%s, θ=%.2f, r=%.2f)" % [north_emoji, south_emoji, theta, radius]

## ========================================
## DEPRECATED METHODS REMOVED
## ========================================
## All quantum operations now handled by QuantumBath using proper:
## - Unitary gates: bath.apply_unitary_1q(), bath.apply_unitary_2q()
## - Evolution: bath.evolve() with Hamiltonian + Lindblad
## - State manipulation: bath methods only
##
## DualEmojiQubit is now a pure projection lens (read-only)
