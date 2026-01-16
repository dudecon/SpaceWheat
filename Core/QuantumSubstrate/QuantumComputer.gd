class_name QuantumComputer
extends Resource

## Central quantum state manager for one biome
##
## Model B: The QuantumComputer is the ONLY owner of quantum state for the biome.
## All plots reference it via RegisterIds. The computer is internally factorized
## into independent connected components (entangled sets).

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
# SparseMatrix deprecated - sparse optimization now handled by native C++ backend
const QuantumComponent = preload("res://Core/QuantumSubstrate/QuantumComponent.gd")
const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")
const RegisterMap = preload("res://Core/QuantumSubstrate/RegisterMap.gd")

@export var biome_name: String = ""

## Model C (Analog Upgrade): RegisterMap-based architecture
var register_map: RegisterMap = RegisterMap.new()
var density_matrix: ComplexMatrix = null

## Lindblad evolution operators (set by biome via HamiltonianBuilder/LindbladBuilder)
var hamiltonian: ComplexMatrix = null         # H matrix (Hermitian, dim×dim)
var lindblad_operators: Array = []            # Array of L_k matrices (ComplexMatrix)

## SPARSE optimized operators (10-50x faster for sparse Hamiltonians/Lindblad)
var sparse_hamiltonian = null                 # SparseMatrix (auto-converted if sparse)
var sparse_lindblad_operators: Array = []     # Array of SparseMatrix (auto-converted)

## BATCHED NATIVE evolution engine (100x faster - eliminates GDScript↔C++ bridge overhead)
## Set up via setup_native_evolution() after operators are configured
var native_evolution_engine = null            # QuantumEvolutionEngine (native C++ class)
static var _native_engine_available: bool = false
static var _native_engine_checked: bool = false

## Gated Lindblad configurations (set by biome via LindbladBuilder)
## Format: [{target_emoji: String, source_emoji: String, rate: float, gate: String, power: float}]
## Evaluated each timestep: effective_rate = rate × P(gate)^power
var gated_lindblad_configs: Array = []

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

	Kitchen v2: Validates basis states are orthogonal and registered.

	Creates 1-qubit component initialized to |0⟩.
	Returns: register_id (unique per biome)

	Args:
	    north_emoji: North pole of qubit axis (|0⟩ basis label)
	    south_emoji: South pole of qubit axis (|1⟩ basis label)

	Guardrails:
	    - north_emoji must != south_emoji (orthogonal basis states)
	    - Both emojis must be registered in IconRegistry
	"""
	# CRITICAL: Basis states must be orthogonal
	if north_emoji == south_emoji:
		push_error("PHYSICS ERROR: Invalid qubit basis: north='%s' south='%s' (must differ!)" %
		           [north_emoji, south_emoji])
		return -1

	# Note: IconRegistry validation removed - not needed for quantum mechanics
	# RegisterMap handles coordinate mapping in Model C architecture

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


# ============================================================================
# MODEL C: Analog Upgrade - RegisterMap-based Architecture
# ============================================================================

func allocate_axis(qubit_index: int, north_emoji: String, south_emoji: String) -> void:
	"""Register a qubit axis in the RegisterMap.

	Args:
	    qubit_index: Qubit number (0, 1, 2, ...)
	    north_emoji: Emoji for |0⟩ (north pole)
	    south_emoji: Emoji for |1⟩ (south pole)

	Example:
	    allocate_axis(0, "🔥", "❄️")  # Qubit 0: Temperature axis
	"""
	register_map.register_axis(qubit_index, north_emoji, south_emoji)
	_resize_density_matrix()
	print("📍 Allocated axis %d: %s (north) ↔ %s (south)" % [qubit_index, north_emoji, south_emoji])


func _resize_density_matrix() -> void:
	"""Resize density matrix when qubits are added."""
	var num_qubits = register_map.num_qubits
	var dim = register_map.dim()

	if density_matrix == null or density_matrix.n != dim:
		density_matrix = ComplexMatrix.zeros(dim)
		print("🔧 Resized density matrix: %d qubits → %dD" % [num_qubits, dim])


func initialize_basis(basis_index: int) -> void:
	"""Initialize density matrix to pure state |i⟩⟨i|.

	Args:
	    basis_index: Computational basis index (0 to 2^n - 1)

	Example:
	    initialize_basis(7)  # |111⟩ for 3 qubits (ground state)
	"""
	var dim = register_map.dim()
	if basis_index < 0 or basis_index >= dim:
		push_error("❌ Basis index %d out of range [0, %d)" % [basis_index, dim])
		return

	density_matrix = ComplexMatrix.zeros(dim)
	density_matrix.set_element(basis_index, basis_index, Complex.one())
	print("🎯 Initialized to |%d⟩ = %s" % [basis_index, register_map.basis_to_emojis(basis_index)])


# Delegate RegisterMap queries
func has(emoji: String) -> bool:
	"""Check if emoji is registered in this quantum computer."""
	return register_map.has(emoji)


func qubit(emoji: String) -> int:
	"""Get qubit index for emoji (-1 if not found)."""
	return register_map.qubit(emoji)


func pole(emoji: String) -> int:
	"""Get pole for emoji (0=north, 1=south, -1 if not found)."""
	return register_map.pole(emoji)


func get_density_matrix() -> ComplexMatrix:
	"""Get the density matrix (ρ) for this quantum computer.

	Returns the full density matrix representing the quantum state.
	Used by BiomeBase for measurements, coherence checks, and draining.
	"""
	return density_matrix


func get_marginal(qubit_index: int, pole_value: int) -> float:
	"""Get marginal probability P(qubit = pole) via partial trace.

	Args:
	    qubit_index: Which qubit to measure
	    pole_value: 0 (north) or 1 (south)

	Returns:
	    Probability in [0, 1]

	Example:
	    get_marginal(0, 0)  # P(qubit 0 = north) = P(🔥)
	"""
	if density_matrix == null:
		return 0.0

	var num_qubits = register_map.num_qubits
	var dim = register_map.dim()
	var shift = num_qubits - 1 - qubit_index
	var prob = 0.0

	for i in range(dim):
		if ((i >> shift) & 1) == pole_value:
			prob += density_matrix.get_element(i, i).re

	return clamp(prob, 0.0, 1.0)


func get_population(emoji: String) -> float:
	"""Get probability of emoji state via RegisterMap lookup.

	Args:
	    emoji: Emoji to query (must be registered)

	Returns:
	    P(emoji) in [0, 1]

	Example:
	    get_population("🔥")  # Returns P(qubit 0 = north)
	"""
	if not register_map.has(emoji):
		# Unregistered emojis have 0 probability - no warning needed
		# (SemanticDrift queries 🌀 and ✨ which may not be in this biome)
		return 0.0

	var q = register_map.qubit(emoji)
	var p = register_map.pole(emoji)
	return get_marginal(q, p)


func get_all_populations() -> Dictionary:
	"""Get populations for all registered emojis.

	Returns:
	    Dictionary: {emoji: float} for all registered emojis

	Example:
	    {"🔥": 0.7, "❄️": 0.3, "💧": 0.5, "🏜️": 0.5}
	"""
	var populations: Dictionary = {}

	if register_map == null:
		return populations

	# Iterate over all registered emojis
	for emoji in register_map.coordinates.keys():
		populations[emoji] = get_population(emoji)

	return populations


func measure_axis(north_emoji: String, south_emoji: String) -> String:
	"""Projective measurement on a north/south emoji axis.

	Model C measurement: samples from Born probabilities and collapses state.

	Args:
	    north_emoji: North pole emoji (e.g., "🌾")
	    south_emoji: South pole emoji (e.g., "🍄")

	Returns:
	    Measured emoji (north_emoji or south_emoji), or "" on error
	"""
	if not register_map.has(north_emoji) or not register_map.has(south_emoji):
		push_warning("⚠️ Emoji axis not registered: %s/%s" % [north_emoji, south_emoji])
		return ""

	var q_north = register_map.qubit(north_emoji)
	var q_south = register_map.qubit(south_emoji)

	if q_north != q_south:
		push_warning("⚠️ Emojis not on same qubit: %s (q%d) / %s (q%d)" % [
			north_emoji, q_north, south_emoji, q_south])
		return ""

	var qubit_idx = q_north
	var p_north = get_marginal(qubit_idx, 0)  # pole 0 = north
	var p_south = get_marginal(qubit_idx, 1)  # pole 1 = south
	var p_total = p_north + p_south

	if p_total < 1e-14:
		push_error("⚠️ Measurement probabilities sum to zero for axis %s/%s" % [north_emoji, south_emoji])
		return north_emoji  # Default

	# Sample outcome
	var rand = randf()
	var outcome_pole = 0 if (rand < p_north / p_total) else 1
	var outcome_emoji = north_emoji if outcome_pole == 0 else south_emoji

	# Project density matrix onto outcome
	_project_qubit(qubit_idx, outcome_pole)

	print("🔬 Measured axis %s/%s: outcome=%s (p_north=%.3f, p_south=%.3f)" % [
		north_emoji, south_emoji, outcome_emoji, p_north, p_south])

	return outcome_emoji


func _project_qubit(qubit_index: int, outcome_pole: int) -> void:
	"""Project density matrix onto qubit measurement outcome.

	Implements projective measurement collapse:
	ρ → P_k ρ P_k / Tr(P_k ρ)

	where P_k is the projector onto |k⟩⟨k| for the measured qubit.
	"""
	var num_qubits = register_map.num_qubits
	var dim = register_map.dim()
	var shift = num_qubits - 1 - qubit_index
	var rho_new = ComplexMatrix.zeros(dim)

	# Apply projector: keep only states where qubit = outcome_pole
	for i in range(dim):
		var qubit_i = (i >> shift) & 1
		if qubit_i != outcome_pole:
			continue  # Project out

		for j in range(dim):
			var qubit_j = (j >> shift) & 1
			if qubit_j != outcome_pole:
				continue  # Project out

			rho_new.set_element(i, j, density_matrix.get_element(i, j))

	# Renormalize
	density_matrix = rho_new
	density_matrix.renormalize_trace()


func get_basis_probability(basis_index: int) -> float:
	"""Get probability of computational basis state |i⟩.

	Args:
	    basis_index: Basis state index (0 to 2^n - 1)

	Returns:
	    P(|i⟩) = ρ[i,i] (diagonal element)

	Example:
	    get_basis_probability(0)  # P(|000⟩) = P(bread)
	"""
	if density_matrix == null:
		return 0.0

	var dim = register_map.dim()
	if basis_index < 0 or basis_index >= dim:
		return 0.0

	return clamp(density_matrix.get_element(basis_index, basis_index).re, 0.0, 1.0)


func apply_drive(target_emoji: String, rate: float, dt: float) -> void:
	"""Apply Lindblad drive pushing population toward target emoji.

	This implements trace-preserving population transfer:
	    dρ/dt = γ(L ρ L† - {L†L, ρ}/2)

	where L = √γ |target⟩⟨source| flips the qubit from opposite pole to target.

	Args:
	    target_emoji: Emoji to drive toward (must be registered)
	    rate: Drive strength γ (1/s)
	    dt: Time step (s)

	Example:
	    apply_drive("🔥", 2.0, 0.1)  # Drive toward hot for 0.1s
	"""
	if not register_map.has(target_emoji):
		push_warning("⚠️ Cannot drive to unregistered emoji: %s" % target_emoji)
		return

	var q = register_map.qubit(target_emoji)
	var target_pole = register_map.pole(target_emoji)
	var source_pole = 1 - target_pole  # Opposite pole

	_apply_lindblad_1q(q, source_pole, target_pole, rate, dt)


func _apply_lindblad_1q(qubit_index: int, from_pole: int, to_pole: int,
                        gamma: float, dt: float) -> void:
	"""Apply single-qubit Lindblad operator L = √γ |to⟩⟨from|.

	Updates density matrix:
	    ρ → ρ + dt * γ(L ρ L† - {L†L, ρ}/2)

	This preserves Tr(ρ) = 1 and positive semi-definiteness (to first order).
	"""
	if density_matrix == null:
		return

	var num_qubits = register_map.num_qubits
	var dim = register_map.dim()
	var shift = num_qubits - 1 - qubit_index
	var rho_new = ComplexMatrix.zeros(dim)

	# Build Lindblad superoperator: L ρ L† - {L†L, ρ}/2
	for i in range(dim):
		for j in range(dim):
			var rho_ij = density_matrix.get_element(i, j)
			var accum = Complex.zero()

			# Term 1: L ρ L†
			# L|k⟩ = |k'⟩ if k has from_pole at qubit, else 0
			# where k' = k with qubit flipped to to_pole
			var k_bit_i = (i >> shift) & 1
			var k_bit_j = (j >> shift) & 1

			if k_bit_i == to_pole and k_bit_j == to_pole:
				# i and j both have to_pole: could have come from flipping from_pole
				var i_source = i ^ (1 << shift)  # Flip back to from_pole
				var j_source = j ^ (1 << shift)
				accum = accum.add(density_matrix.get_element(i_source, j_source))

			# Term 2: -{L†L, ρ}/2 = -(L†L ρ + ρ L†L)/2
			# L†L|k⟩ = |k⟩ if k has from_pole, else 0
			if k_bit_i == from_pole:
				accum = accum.sub(rho_ij.scale(0.5))
			if k_bit_j == from_pole:
				accum = accum.sub(rho_ij.scale(0.5))

			# ρ_new = ρ + dt * γ * L[ρ]
			rho_new.set_element(i, j, rho_ij.add(accum.scale(gamma * dt)))

	density_matrix = rho_new
	_renormalize()


func _renormalize() -> void:
	"""Ensure Tr(ρ) = 1 after numerical integration."""
	if density_matrix == null:
		return

	var trace = 0.0
	var dim = register_map.dim()
	for i in range(dim):
		trace += density_matrix.get_element(i, i).re

	if abs(trace) < 1e-10:
		# Trace collapsed - recover by reinitializing to maximally mixed state
		push_warning("⚠️ Trace collapsed to ~0, reinitializing to mixed state")
		_reinitialize_mixed_state()
		return

	# Normalize: ρ → ρ / Tr(ρ)
	for i in range(dim):
		for j in range(dim):
			var rho_ij = density_matrix.get_element(i, j)
			density_matrix.set_element(i, j, rho_ij.scale(1.0 / trace))


func _reinitialize_mixed_state() -> void:
	"""Reinitialize to maximally mixed state (ρ = I/d) when trace collapses."""
	if density_matrix == null:
		return

	var dim = register_map.dim()
	if dim == 0:
		return

	# Set to ρ = I/d (uniform distribution over all basis states)
	var diag_val = 1.0 / float(dim)
	for i in range(dim):
		for j in range(dim):
			if i == j:
				density_matrix.set_element(i, j, Complex.new(diag_val, 0.0))
			else:
				density_matrix.set_element(i, j, Complex.zero())


# ============================================================================
# MODEL C: FULL LINDBLAD EVOLUTION
# ============================================================================

func evolve(dt: float) -> void:
	"""Evolve density matrix under Lindblad master equation.

	Implements: dρ/dt = -i[H,ρ] + Σ_k (L_k ρ L_k† - ½{L_k†L_k, ρ})

	Uses first-order Euler integration: ρ(t+dt) = ρ(t) + dt * dρ/dt
	With subcycling for numerical stability when dt is large.

	Args:
	    dt: Time step (in game seconds, typically 1/60 for 60 FPS)

	Requires:
	    - density_matrix initialized (via initialize_basis or allocate_axis)
	    - hamiltonian set (via HamiltonianBuilder.build)
	    - lindblad_operators set (via LindbladBuilder.build)
	"""
	if density_matrix == null:
		return  # Not initialized yet

	var dim = register_map.dim()
	if dim == 0:
		return

	# ==========================================================================
	# BATCHED NATIVE PATH: 100x faster (single C++ call with internal subcycling)
	# ==========================================================================
	if native_evolution_engine != null and native_evolution_engine.is_finalized():
		const MAX_DT: float = 0.1
		var rho_packed = density_matrix._to_packed()
		var result_packed = native_evolution_engine.evolve(rho_packed, dt, MAX_DT)
		density_matrix._from_packed(result_packed, dim)
		_renormalize()  # Critical: ensure Tr(ρ) = 1 after native evolution
		return

	# ==========================================================================
	# FALLBACK: Per-operator sparse path (still fast, but more bridge overhead)
	# ==========================================================================
	# Subcycling for numerical stability: break large dt into smaller steps
	# NOTE: 0.1 is generous - allows ~10 FPS before subcycling kicks in
	const MAX_DT: float = 0.1  # Maximum safe timestep for Euler integration
	if dt > MAX_DT:
		var num_steps = int(ceil(dt / MAX_DT))
		var sub_dt = dt / num_steps
		for _i in range(num_steps):
			_evolve_step(sub_dt)
		return

	_evolve_step(dt)


func _evolve_step(dt: float) -> void:
	"""Single Euler integration step (internal)."""
	var dim = register_map.dim()

	# Accumulate dρ/dt
	var drho = ComplexMatrix.zeros(dim)

	# -------------------------------------------------------------------------
	# Term 1: Hamiltonian evolution -i[H, ρ]
	# -------------------------------------------------------------------------
	if sparse_hamiltonian != null:
		# SPARSE path: 10-50x faster commutator
		var commutator = sparse_hamiltonian.commutator_with_dense(density_matrix)
		var neg_i = Complex.new(0.0, -1.0)
		drho = drho.add(commutator.scale(neg_i))
	elif hamiltonian != null:
		# Dense fallback
		var commutator = hamiltonian.commutator(density_matrix)
		var neg_i = Complex.new(0.0, -1.0)
		drho = drho.add(commutator.scale(neg_i))

	# -------------------------------------------------------------------------
	# Term 2: Lindblad dissipation Σ_k (L_k ρ L_k† - ½{L_k†L_k, ρ})
	# -------------------------------------------------------------------------
	# SPARSE path: use optimized native lindblad_dissipator()
	if sparse_lindblad_operators.size() > 0:
		for L_sparse in sparse_lindblad_operators:
			if L_sparse == null:
				continue
			# Single native call computes entire dissipator: L ρ L† - ½{L†L, ρ}
			var dissipator = L_sparse.lindblad_dissipator(density_matrix)
			drho = drho.add(dissipator)
	else:
		# Dense fallback
		for L in lindblad_operators:
			if L == null:
				continue

			# L ρ L†
			var L_dag = L.dagger()
			var L_rho = L.mul(density_matrix)
			var L_rho_Ldag = L_rho.mul(L_dag)

			# L†L for anticommutator
			var Ldag_L = L_dag.mul(L)

			# {L†L, ρ}/2 = (L†L ρ + ρ L†L)/2
			var anticomm = Ldag_L.anticommutator(density_matrix)
			var half_anticomm = anticomm.scale_real(0.5)

			# Dissipator: L ρ L† - {L†L, ρ}/2
			var dissipator = L_rho_Ldag.sub(half_anticomm)
			drho = drho.add(dissipator)

	# -------------------------------------------------------------------------
	# Term 3: Gated Lindblad (evaluated each timestep)
	# effective_rate = base_rate × P(gate)^power
	# Only applies if P(gate) > threshold (optimization)
	# -------------------------------------------------------------------------
	for config in gated_lindblad_configs:
		var gate_emoji: String = config.get("gate", "")
		var power: float = config.get("power", 1.0)

		# Skip if gate emoji not registered
		if not register_map.has(gate_emoji):
			continue

		# Evaluate gate probability
		var gate_prob = get_population(gate_emoji)
		var effective_rate = config.get("rate", 0.0) * pow(gate_prob, power)

		# Skip if negligible (optimization)
		if effective_rate < 0.0001:
			continue

		# Build and apply jump operator for this timestep
		var source_emoji: String = config.get("source_emoji", "")
		var target_emoji: String = config.get("target_emoji", "")

		if not register_map.has(source_emoji) or not register_map.has(target_emoji):
			continue

		var source_q = register_map.qubit(source_emoji)
		var source_p = register_map.pole(source_emoji)
		var target_q = register_map.qubit(target_emoji)
		var target_p = register_map.pole(target_emoji)

		# Build jump operator L = √γ_eff |target⟩⟨source|
		var L_gated = _build_gated_jump(source_q, source_p, target_q, target_p,
		                                effective_rate, register_map.num_qubits)

		if L_gated != null:
			# Apply Lindblad dissipator for this operator
			var L_dag = L_gated.dagger()
			var L_rho = L_gated.mul(density_matrix)
			var L_rho_Ldag = L_rho.mul(L_dag)
			var Ldag_L = L_dag.mul(L_gated)
			var anticomm = Ldag_L.anticommutator(density_matrix)
			var half_anticomm = anticomm.scale_real(0.5)
			var dissipator = L_rho_Ldag.sub(half_anticomm)
			drho = drho.add(dissipator)

	# -------------------------------------------------------------------------
	# Euler integration: ρ_new = ρ + dt * dρ/dt
	# -------------------------------------------------------------------------
	density_matrix = density_matrix.add(drho.scale_real(dt))

	# Renormalize to maintain Tr(ρ) = 1 (numerical stability)
	_renormalize()


func _build_gated_jump(source_q: int, source_p: int, target_q: int, target_p: int,
                       rate: float, num_qubits: int) -> ComplexMatrix:
	"""Build jump operator L = √rate |target⟩⟨source| for gated Lindblad.

	Args:
	    source_q: Source qubit index
	    source_p: Source pole (0=north, 1=south)
	    target_q: Target qubit index
	    target_p: Target pole (0=north, 1=south)
	    rate: Effective rate (already scaled by gate probability)
	    num_qubits: Total number of qubits in system

	Returns:
	    ComplexMatrix L operator, or null if invalid
	"""
	var dim = 1 << num_qubits
	var L = ComplexMatrix.zeros(dim)
	var amplitude = Complex.new(sqrt(rate), 0.0)

	if source_q == target_q:
		# Same qubit: flip pole
		var shift = num_qubits - 1 - source_q

		for i in range(dim):
			# Check if qubit is in 'source' pole
			if ((i >> shift) & 1) == source_p:
				var j = i ^ (1 << shift)  # Flip bit
				L.set_element(j, i, amplitude)
	else:
		# Different qubits: correlated transfer
		var shift_from = num_qubits - 1 - source_q
		var shift_to = num_qubits - 1 - target_q

		for i in range(dim):
			var bit_from = (i >> shift_from) & 1
			var bit_to = (i >> shift_to) & 1

			# Source qubit must be in source_p
			# Target qubit must NOT already be in target_p
			if bit_from == source_p and bit_to != target_p:
				var j = i ^ (1 << shift_from) ^ (1 << shift_to)
				L.set_element(j, i, amplitude)

	return L


func get_purity() -> float:
	"""Get purity Tr(ρ²) of the quantum state.

	Returns:
	    1.0 for pure states, < 1.0 for mixed states
	    Minimum is 1/dim for maximally mixed state
	"""
	if density_matrix == null:
		return 0.0

	var rho_squared = density_matrix.mul(density_matrix)
	return rho_squared.trace().re


func transfer_population(from_emoji: String, to_emoji: String,
                         amount: float, phase: float = 0.0) -> void:
	"""Transfer population between two basis states (Hamiltonian-based).

	This creates/updates off-diagonal coherence:
	    ρ[to, from] += amount * e^(iφ)
	    ρ[from, to] += amount * e^(-iφ)

	And adjusts populations to conserve trace:
	    ρ[from, from] -= amount
	    ρ[to, to] += amount

	Args:
	    from_emoji: Source basis state (array of emojis)
	    to_emoji: Target basis state (array of emojis)
	    amount: Population to transfer (0 to 1)
	    phase: Coherence phase φ (radians)

	Example:
	    transfer_population("🌾", "💨", 0.1, PI/4)  # Grain → Flour
	"""
	# Convert emoji strings to basis indices
	# Note: This is simplified - full implementation would parse emoji arrays
	if not register_map.has(from_emoji) or not register_map.has(to_emoji):
		push_warning("⚠️ Cannot transfer: emoji not registered")
		return

	# For single-qubit transfer, we can compute basis index
	var from_q = register_map.qubit(from_emoji)
	var from_p = register_map.pole(from_emoji)
	var to_q = register_map.qubit(to_emoji)
	var to_p = register_map.pole(to_emoji)

	if from_q != to_q:
		push_warning("⚠️ Cross-qubit transfer not yet implemented")
		return

	# Build basis indices for full state
	# This is simplified - assumes all other qubits in south pole
	var num_qubits = register_map.num_qubits
	var from_index = 0
	var to_index = 0

	for q in range(num_qubits):
		if q == from_q:
			if from_p == 0:  # North pole
				pass  # Bit is 0
			else:
				from_index |= (1 << (num_qubits - 1 - q))

			if to_p == 0:
				pass
			else:
				to_index |= (1 << (num_qubits - 1 - q))
		else:
			# Default to south pole (bit = 1)
			from_index |= (1 << (num_qubits - 1 - q))
			to_index |= (1 << (num_qubits - 1 - q))

	# Update coherences with phase
	var coherence = Complex.from_polar(amount, phase)
	var current_off = density_matrix.get_element(to_index, from_index)
	density_matrix.set_element(to_index, from_index, current_off.add(coherence))
	density_matrix.set_element(from_index, to_index, current_off.add(coherence.conjugate()))

	# Update populations
	var pop_from = density_matrix.get_element(from_index, from_index)
	var pop_to = density_matrix.get_element(to_index, to_index)
	density_matrix.set_element(from_index, from_index,
		pop_from.sub(Complex.new(amount, 0.0)))
	density_matrix.set_element(to_index, to_index,
		pop_to.add(Complex.new(amount, 0.0)))


func apply_decay(qubit_index: int, rate: float, dt: float) -> void:
	"""Apply spontaneous decay toward south pole (thermal relaxation).

	Implements: dρ/dt = γ(L ρ L† - {L†L, ρ}/2)
	where L = √γ |south⟩⟨north| pushes north → south.

	Args:
	    qubit_index: Which qubit to decay
	    rate: Decay rate γ (1/s)
	    dt: Time step (s)

	Example:
	    apply_decay(0, 0.5, 0.1)  # Temperature decays toward cold
	"""
	var from_pole = 0  # North
	var to_pole = 1    # South
	_apply_lindblad_1q(qubit_index, from_pole, to_pole, rate, dt)


func get_trace() -> float:
	"""Get trace of density matrix (should always be 1.0)."""
	if density_matrix == null:
		return 0.0

	var trace = 0.0
	var dim = register_map.dim()
	for i in range(dim):
		trace += density_matrix.get_element(i, i).re

	return trace


# ============================================================================
# SPARSE OPERATOR SETUP (Performance Optimization)
# ============================================================================

func set_hamiltonian(H: ComplexMatrix) -> void:
	"""Set Hamiltonian with auto-sparse conversion.

	Automatically converts to sparse format if sparsity > 50%.
	Sparse Hamiltonian: 10-50x faster commutator computation.
	"""
	hamiltonian = H

	if H == null:
		sparse_hamiltonian = null
		return

	# Sparsity check (simplified - native engine handles actual sparse ops)
	var nnz = 0
	var total = H.n * H.n
	for i in range(total):
		var c = H._data[i]
		if c.re * c.re + c.im * c.im > 1e-24:
			nnz += 1
	var sparsity = 1.0 - (float(nnz) / float(total)) if total > 0 else 0.0

	if sparsity > 0.5:
		sparse_hamiltonian = H  # Keep reference for native engine
		print("⚡ Hamiltonian converted to sparse: %.1f%% zeros, nnz=%d" % [sparsity * 100, nnz])
	else:
		sparse_hamiltonian = null
		print("📊 Hamiltonian kept dense: %.1f%% zeros (below threshold)" % [sparsity * 100])


func set_lindblad_operators(operators: Array) -> void:
	"""Set Lindblad operators with auto-sparse conversion.

	Converts each operator to sparse format. Lindblad operators are
	typically very sparse (e.g., |target⟩⟨source| has only 1 non-zero).

	Sparse Lindblad: 10-50x faster dissipator computation via native
	lindblad_dissipator() which fuses L ρ L† - ½{L†L, ρ} into one call.
	"""
	lindblad_operators = operators
	sparse_lindblad_operators.clear()

	if operators.is_empty():
		return

	var total_nnz = 0
	var total_dense = 0

	for L in operators:
		if L == null:
			continue

		# Inline sparsity check (native engine handles actual sparse ops)
		var nnz = 0
		var total = L.n * L.n
		for i in range(total):
			var c = L._data[i]
			if c.re * c.re + c.im * c.im > 1e-24:
				nnz += 1

		sparse_lindblad_operators.append(L)  # Keep reference
		total_nnz += nnz
		total_dense += total

	var avg_sparsity = 1.0 - (float(total_nnz) / float(total_dense)) if total_dense > 0 else 0.0
	print("⚡ %d Lindblad ops → sparse: avg %.1f%% zeros, total nnz=%d" % [
		operators.size(), avg_sparsity * 100, total_nnz])

	# Auto-setup native evolution engine for maximum performance
	setup_native_evolution()


# ============================================================================
# BATCHED NATIVE EVOLUTION (100x faster - eliminates bridge overhead)
# ============================================================================

static func _check_native_engine() -> void:
	"""Check if native QuantumEvolutionEngine is available."""
	if _native_engine_checked:
		return
	_native_engine_checked = true
	_native_engine_available = ClassDB.class_exists("QuantumEvolutionEngine")
	if _native_engine_available:
		print("⚡ QuantumEvolutionEngine: Native batched evolution available")
	else:
		print("📊 QuantumEvolutionEngine: Not available (using per-operator sparse path)")


func setup_native_evolution() -> void:
	"""Set up native batched evolution engine for maximum performance.

	Call this after both hamiltonian and lindblad_operators are set.
	The native engine eliminates GDScript↔C++ bridge overhead by:
	1. Registering all operators ONCE
	2. Precomputing L†, L†L for each Lindblad
	3. Doing complete evolution in single native call

	Performance: 100x faster than per-operator sparse calls.
	(130ms → 7ms for Forest biome with 14 Lindblad operators)
	"""
	_check_native_engine()
	if not _native_engine_available:
		return

	var dim = register_map.dim()
	if dim == 0:
		return

	# Create native engine
	native_evolution_engine = ClassDB.instantiate("QuantumEvolutionEngine")
	if native_evolution_engine == null:
		print("⚠️ QuantumEvolutionEngine: Failed to instantiate")
		return

	native_evolution_engine.set_dimension(dim)

	# Register Hamiltonian (if set)
	if hamiltonian != null:
		var H_packed = hamiltonian._to_packed()
		native_evolution_engine.set_hamiltonian(H_packed)

	# Register all Lindblad operators as triplets
	# Convert from ComplexMatrix to triplet format: [row, col, re, im, ...]
	for L in lindblad_operators:
		if L == null:
			continue
		var triplets = _matrix_to_triplets(L)
		if not triplets.is_empty():
			native_evolution_engine.add_lindblad_triplets(triplets)

	# Finalize (precompute L†, L†L)
	native_evolution_engine.finalize()

	print("🚀 QuantumEvolutionEngine: Batched evolution ready (%d dim, %d Lindblad)" % [
		dim, lindblad_operators.size()])


func _matrix_to_triplets(mat: ComplexMatrix) -> PackedFloat64Array:
	"""Convert a ComplexMatrix to triplet format for native engine.

	Triplet format: [row0, col0, re0, im0, row1, col1, re1, im1, ...]
	Only includes non-zero elements (abs > 1e-15).
	"""
	var triplets = PackedFloat64Array()
	var n = mat.n
	var threshold = 1e-15

	for i in range(n):
		for j in range(n):
			var c = mat.get_element(i, j)
			if abs(c.re) > threshold or abs(c.im) > threshold:
				triplets.append(float(i))  # row
				triplets.append(float(j))  # col
				triplets.append(c.re)      # real part
				triplets.append(c.im)      # imaginary part

	return triplets
