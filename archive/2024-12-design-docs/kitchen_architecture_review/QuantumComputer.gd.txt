class_name QuantumComputer
extends Resource

## Central quantum state manager for one biome
##
## Model B: The QuantumComputer is the ONLY owner of quantum state for the biome.
## All plots reference it via RegisterIds. The computer is internally factorized
## into independent connected components (entangled sets).

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")

@export var biome_name: String = ""
@export var components: Dictionary = {}  # component_id → QuantumComponent
@export var register_to_component: Dictionary = {}  # register_id → component_id
@export var entanglement_graph: Dictionary = {}  # register_id → Array[register_id] (adjacency)

## Phase 4: Energy tap flux tracking
## Accumulated energy flux per tapped emoji (accumulated this frame from Lindblad drain operators)
var sink_flux_per_emoji: Dictionary = {}  # emoji → float (accumulated flux)

var _next_component_id: int = 0

func _init(name: String = ""):
	biome_name = name

func add_component(comp: QuantumComponent) -> void:
	"""Register a new component in this quantum computer."""
	components[comp.component_id] = comp

	# Map all registers in component
	for reg_id in comp.register_ids:
		register_to_component[reg_id] = comp.component_id

		# Initialize entanglement graph
		if not reg_id in entanglement_graph:
			entanglement_graph[reg_id] = []

func allocate_register(north_emoji: String = "🌾", south_emoji: String = "🌽") -> int:
	"""
	Allocate a new single-qubit register (for a newly planted plot).

	Creates 1-qubit component initialized to |0⟩.
	Returns: register_id (unique per biome)
	"""
	# Generate unique register ID (could also use plot coordinates)
	var reg_id = _next_component_id * 10 + register_to_component.size()

	# Create 1-qubit component with |0⟩ state
	var comp = QuantumComponent.new(_next_component_id)
	comp.register_ids.append(reg_id)  # Model B: append instead of assign
	comp.state_vector = [Complex.one(), Complex.zero()]  # |0⟩
	comp.is_pure = true

	add_component(comp)
	_next_component_id += 1

	return reg_id

func get_component_containing(reg_id: int) -> QuantumComponent:
	"""Get the component that owns a register."""
	var comp_id = register_to_component.get(reg_id, -1)
	if comp_id < 0:
		return null
	return components.get(comp_id, null)

func merge_components(comp_a: QuantumComponent, comp_b: QuantumComponent) -> QuantumComponent:
	"""
	Merge two components into tensor product (used on entanglement).
	Updates registry, returns merged component.
	"""
	if comp_a.component_id == comp_b.component_id:
		return comp_a  # Already in same component

	var merged = comp_a.merge_with(comp_b)

	# Remove old components from registry
	components.erase(comp_a.component_id)
	components.erase(comp_b.component_id)

	# Register merged component
	add_component(merged)

	# Update entanglement graph: add edges between all registers in different original components
	for reg_a in comp_a.register_ids:
		for reg_b in comp_b.register_ids:
			if reg_a not in entanglement_graph[reg_b]:
				entanglement_graph[reg_b].append(reg_a)
			if reg_b not in entanglement_graph[reg_a]:
				entanglement_graph[reg_a].append(reg_b)

	return merged

## ============================================================================
## UNITARY GATE OPERATIONS (Tool 5 Backend)
## ============================================================================

func apply_unitary_1q(comp: QuantumComponent, reg_id: int, U: ComplexMatrix) -> bool:
	"""
	Apply 1-qubit unitary gate to one register in a component.

	Operation: ρ' = U ⊗ I (where I acts on other qubits)
	Full: ρ' = (U ⊗ I_other) ρ (U† ⊗ I_other)
	"""
	var reg_index = comp.register_ids.find(reg_id)
	if reg_index < 0:
		push_error("Register %d not in component %d" % [reg_id, comp.component_id])
		return false

	var rho = comp.ensure_density_matrix()
	var dim = comp.hilbert_dimension()

	# Embed U into full component space: I ⊗ ... ⊗ U ⊗ ... ⊗ I
	var embedded_U = _embed_1q_unitary(U, reg_index, comp.register_count())

	# Apply: ρ' = U ρ U†
	var rho_new = embedded_U.mul(rho).mul(embedded_U.conjugate_transpose())

	# Renormalize trace
	rho_new.renormalize_trace()

	comp.density_matrix = rho_new
	comp.is_pure = false

	# Validate invariants (if enabled)
	if not comp.validate_invariants():
		push_error("1Q gate violated invariants on component %d!" % comp.component_id)
		return false

	return true

func apply_unitary_2q(comp: QuantumComponent, reg_a: int, reg_b: int, U: ComplexMatrix) -> bool:
	"""
	Apply 2-qubit unitary gate to two registers in same component.

	Operation: ρ' = (I ⊗ ... ⊗ U ⊗ ... ⊗ I) ρ (I ⊗ ... ⊗ U† ⊗ ... ⊗ I)
	where U acts on (reg_a, reg_b) as tensor product space.
	"""
	var idx_a = comp.register_ids.find(reg_a)
	var idx_b = comp.register_ids.find(reg_b)

	if idx_a < 0 or idx_b < 0:
		push_error("Registers not in component: %d, %d" % [reg_a, reg_b])
		return false

	# Ensure they're in right order (control, target)
	if idx_a > idx_b:
		var temp = idx_a
		idx_a = idx_b
		idx_b = temp

	var rho = comp.ensure_density_matrix()

	# Embed 2Q gate into full component space
	var embedded_U = _embed_2q_unitary(U, idx_a, idx_b, comp.register_count())

	# Apply: ρ' = U ρ U†
	var rho_new = embedded_U.mul(rho).mul(embedded_U.conjugate_transpose())

	# Renormalize trace
	rho_new.renormalize_trace()

	comp.density_matrix = rho_new
	comp.is_pure = false

	# Validate invariants
	if not comp.validate_invariants():
		push_error("2Q gate violated invariants on component %d!" % comp.component_id)
		return false

	return true

func _embed_1q_unitary(U: ComplexMatrix, target_index: int, num_qubits: int) -> ComplexMatrix:
	"""
	Embed 1Q gate U at target_index into full Hilbert space.

	Result: I ⊗ ... ⊗ U ⊗ ... ⊗ I (where U is at target_index)

	Sparse optimization: only non-zero blocks computed.
	"""
	if target_index == 0:
		# U ⊗ I^(n-1)
		var I = ComplexMatrix.identity(1 << (num_qubits - 1))
		return U.tensor_product(I)
	elif target_index == num_qubits - 1:
		# I^(n-1) ⊗ U
		var I = ComplexMatrix.identity(1 << (num_qubits - 1))
		return I.tensor_product(U)
	else:
		# I ⊗ ... ⊗ U ⊗ I ⊗ ... ⊗ I (middle)
		# Recursively build left and right
		var left_I = ComplexMatrix.identity(1 << target_index)
		var right_I = ComplexMatrix.identity(1 << (num_qubits - target_index - 1))

		# (I_left ⊗ U) ⊗ I_right
		var left_part = left_I.tensor_product(U)
		return left_part.tensor_product(right_I)

func _embed_2q_unitary(U: ComplexMatrix, idx_a: int, idx_b: int, num_qubits: int) -> ComplexMatrix:
	"""
	Embed 2Q gate U at indices (idx_a, idx_b) into full Hilbert space.

	Result: I ⊗ ... ⊗ U_{ab} ⊗ ... ⊗ I
	where U_{ab} acts on qubits at idx_a and idx_b.

	Implementation: Builds full 4-dimensional operator by iterating over all basis states,
	applying U only to the (idx_a, idx_b) subspace and passing through other qubits.

	Complexity: O(16 × 4^num_qubits) for full matrix, sparse-optimizable for structured gates.
	"""
	if idx_a > idx_b:
		var temp = idx_a
		idx_a = idx_b
		idx_b = temp

	var total_dim = 1 << num_qubits
	var result = ComplexMatrix.new(total_dim)

	# Build operator by iterating over all 2Q basis states and embedding
	# For basis state |i_a, i_b⟩ at (idx_a, idx_b) with other indices fixed:
	# The operator applies U to (i_a, i_b) and passes through other qubits

	# Iterate over all basis states
	for out_basis in range(total_dim):
		# Decompose output basis state into qubit indices
		var out_qubits = _decompose_basis(out_basis, num_qubits)

		for in_basis in range(total_dim):
			# Decompose input basis state
			var in_qubits = _decompose_basis(in_basis, num_qubits)

			# Check if non-target qubits match (pass-through condition)
			var pass_through = true
			for q in range(num_qubits):
				if q != idx_a and q != idx_b:
					if out_qubits[q] != in_qubits[q]:
						pass_through = false
						break

			if not pass_through:
				continue  # Skip: non-target qubits don't match

			# Extract 2-qubit indices for U
			var in_2q_idx = (in_qubits[idx_a] << 1) | in_qubits[idx_b]
			var out_2q_idx = (out_qubits[idx_a] << 1) | out_qubits[idx_b]

			# Get U[out_2q, in_2q]
			var u_element = U.get_element(out_2q_idx, in_2q_idx)

			# Set result[out_basis, in_basis] = U[out_2q, in_2q]
			result.set_element(out_basis, in_basis, u_element)

	return result


func _decompose_basis(basis: int, num_qubits: int) -> Array[int]:
	"""Decompose a basis state index into individual qubit indices.

	For num_qubits=3, basis=5 (binary 101):
	Returns [1, 0, 1] (qubit 0=1, qubit 1=0, qubit 2=1)
	"""
	var qubits: Array[int] = []
	for i in range(num_qubits):
		qubits.append((basis >> i) & 1)
	return qubits

## ============================================================================
## MEASUREMENT (Tool 2 Backend)
## ============================================================================

func measure_register(comp: QuantumComponent, reg_id: int) -> String:
	"""
	Projective measurement of one register in a component.

	Samples outcome from Born probabilities, collapses state by projection.
	Returns: "north" or "south" (outcome)

	Physics: Measures in the computational basis {|0⟩, |1⟩}.
	For plot with (north_emoji, south_emoji) basis, maps naturally.
	"""
	var marginal = comp.get_marginal_2x2(reg_id)
	var p0 = marginal.get_element(0, 0).re
	var p1 = marginal.get_element(1, 1).re
	var p_total = p0 + p1

	if p_total < 1e-14:
		push_error("Measurement probabilities sum to zero!")
		return "north"  # Default

	# Sample outcome
	var rand = randf()
	var outcome_idx = 0 if (rand < p0 / p_total) else 1
	var outcome = "south" if outcome_idx == 1 else "north"

	# Project state onto outcome
	_project_component_state(comp, reg_id, outcome_idx)

	return outcome

func inspect_register_distribution(comp: QuantumComponent, reg_id: int) -> Dictionary:
	"""
	Non-destructive peek at measurement probabilities.

	Returns marginal probabilities WITHOUT collapsing state.
	This is simulator introspection, not physical measurement.

	Returns: {north: float, south: float}
	"""
	var marginal = comp.get_marginal_2x2(reg_id)
	var p0 = marginal.get_element(0, 0).re
	var p1 = marginal.get_element(1, 1).re

	return {
		"north": p0,
		"south": p1
	}

func _project_component_state(comp: QuantumComponent, reg_id: int, outcome_idx: int) -> void:
	"""
	Apply projector to component state after measurement.

	outcome_idx: 0 = |0⟩ (north), 1 = |1⟩ (south)

	Math: ρ' = P ρ P† / Tr(P ρ P†) where P = |outcome⟩⟨outcome|
	"""
	var reg_index = comp.register_ids.find(reg_id)
	if reg_index < 0:
		return

	# Create projector |outcome⟩⟨outcome|
	var projector = ComplexMatrix.new(2)
	projector.set_element(outcome_idx, outcome_idx, Complex.one())

	# Embed into full component space
	var embedded_proj = _embed_1q_unitary(projector, reg_index, comp.register_count())

	# Apply projection: ρ' = P ρ P†
	var rho = comp.ensure_density_matrix()
	var rho_proj = embedded_proj.mul(rho).mul(embedded_proj.conjugate_transpose())

	# Renormalize
	rho_proj.renormalize_trace()

	comp.density_matrix = rho_proj
	comp.is_pure = false

## ============================================================================
## ENTANGLEMENT (Tool 1 Backend)
## ============================================================================

func entangle_plots(reg_a: int, reg_b: int) -> bool:
	"""
	Entangle two registers (from same biome) using Bell circuit.

	Circuit: H on reg_a, then CNOT(reg_a, reg_b)
	Result: Bell Φ+ = (|00⟩ + |11⟩) / √2

	Merges components if in different connected sets.
	"""
	var comp_a = get_component_containing(reg_a)
	var comp_b = get_component_containing(reg_b)

	if not comp_a or not comp_b:
		push_error("Invalid registers for entanglement: %d, %d" % [reg_a, reg_b])
		return false

	# Merge components if different
	if comp_a.component_id != comp_b.component_id:
		var merged = merge_components(comp_a, comp_b)
		if not merged:
			return false
		comp_a = merged

	# Apply Bell circuit
	var H = QuantumGateLibrary.get_gate("H")["matrix"]
	if not apply_unitary_1q(comp_a, reg_a, H):
		return false

	var CNOT = QuantumGateLibrary.get_gate("CNOT")["matrix"]
	if not apply_unitary_2q(comp_a, reg_a, reg_b, CNOT):
		return false

	return true

func get_entangled_component(reg_id: int) -> Array[int]:
	"""Get all registers entangled with this one (in same component)."""
	var comp = get_component_containing(reg_id)
	if not comp:
		return []
	return comp.register_ids


func batch_measure_component(comp: QuantumComponent) -> Dictionary:
	"""Measure all registers in an entangled component (Manifest Section 4.2: Batch Measurement)

	Implements "spooky action at a distance": Measuring one qubit collapses entire component.
	Returns all measurement outcomes for registers in this component.

	Args:
		comp: QuantumComponent to measure

	Returns:
		Dictionary: {register_id → outcome_string}
		Example: {0: "north", 1: "south", 2: "north"}
	"""
	var outcomes: Dictionary = {}

	# For each register in component, project to measured outcome
	for reg_id in comp.register_ids:
		var marginal = comp.get_marginal_2x2(reg_id)
		var p0 = marginal.get_element(0, 0).re
		var p1 = marginal.get_element(1, 1).re
		var p_total = p0 + p1

		if p_total < 1e-14:
			outcomes[reg_id] = "?"
			continue

		# Sample outcome from Born probabilities
		var outcome_idx = 0 if (randf() < p0 / p_total) else 1
		var outcome = "south" if outcome_idx == 1 else "north"

		# Project this qubit
		_project_component_state(comp, reg_id, outcome_idx)

		outcomes[reg_id] = outcome

	# Renormalize trace for entire component (once, after all projections)
	if comp.density_matrix:
		comp.density_matrix.renormalize_trace()
		comp.is_pure = false

	return outcomes

## ============================================================================
## UTILITY METHODS
## ============================================================================

func get_marginal_density_matrix(comp: QuantumComponent, reg_id: int) -> ComplexMatrix:
	"""Get 2×2 marginal density matrix for one register."""
	return comp.get_marginal_2x2(reg_id)

func get_marginal_probability_subspace(comp: QuantumComponent, reg_id: int, basis_labels: Array[String]) -> float:
	"""
	Get total probability in subspace spanned by two basis states.

	Used for plots with (north_emoji, south_emoji) basis.
	Returns: P(north) + P(south)
	"""
	var marginal = comp.get_marginal_2x2(reg_id)
	var p0 = marginal.get_element(0, 0).re
	var p1 = marginal.get_element(1, 1).re
	return p0 + p1

func get_marginal_purity(comp: QuantumComponent, reg_id: int) -> float:
	"""Get purity of marginal state for one register."""
	return comp.get_purity(reg_id)

func get_marginal_coherence(comp: QuantumComponent, reg_id: int) -> float:
	"""Get coherence (off-diagonal element) for one register."""
	return comp.get_coherence(reg_id)

## ============================================================================
## PHASE 4: ENERGY TAP SINK FLUX TRACKING
## ============================================================================

func get_sink_flux(emoji: String) -> float:
	"""
	Get accumulated energy flux that drained to sink state from an emoji this frame.

	Manifest Section 4.1: Lindblad drain operators L_e = |sink⟩⟨e| transfer
	population from emoji to sink state. This tracks how much was drained.

	Called during each frame to collect energy from energy tap plots.
	"""
	return sink_flux_per_emoji.get(emoji, 0.0)

func get_all_sink_fluxes() -> Dictionary:
	"""
	Get dictionary of all accumulated fluxes per emoji this frame.

	Returns: {emoji: float} of all drained energies
	"""
	return sink_flux_per_emoji.duplicate()

func reset_sink_flux() -> void:
	"""Reset accumulated sink flux for next frame."""
	sink_flux_per_emoji.clear()

func debug_dump() -> String:
	"""Generate human-readable dump of quantum computer state."""
	var s = "=== QuantumComputer %s ===\n" % biome_name
	s += "Components: %d\n" % components.size()
	s += "Registers: %d\n" % register_to_component.size()

	for comp_id in components.keys():
		var comp = components[comp_id]
		s += "  Component %d: %s\n" % [comp_id, comp]

	s += "Entanglement Graph:\n"
	for reg_id in entanglement_graph.keys():
		if entanglement_graph[reg_id].size() > 0:
			s += "  Register %d ↔ %s\n" % [reg_id, entanglement_graph[reg_id]]

	return s
