class_name QuantumComponent
extends Resource

## One connected component of entangled registers in a biome's quantum computer
##
## Model B: The biome's quantum computer is internally factorized into independent
## components. Each component manages its own quantum state (possibly as a product
## of smaller subspaces). This avoids 2^N explosion for large farms.

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")

@export var component_id: int = -1
@export var register_ids: Array[int] = []  # Logical qubit IDs in this component

## Quantum state representation (choose one per component)
@export var state_vector: Array = []  # Array[Complex] for pure states
var density_matrix: ComplexMatrix = null  # For mixed states
@export var is_pure: bool = true  # true → use state_vector, false → use density_matrix

## Scheduled operations queue
@export var pending_operations: Array = []  # [{op_type, gate_matrix, target_indices, turn}]

func _init(comp_id: int = -1):
	component_id = comp_id

func register_count() -> int:
	"""Number of logical qubits in this component."""
	return register_ids.size()

func hilbert_dimension() -> int:
	"""Dimension of Hilbert space: 2^(register_count)."""
	return 1 << register_count()

func _to_string() -> String:
	var dim_str = ""
	if is_pure:
		dim_str = "pure, |ψ⟩ dim=%d" % state_vector.size()
	else:
		dim_str = "mixed, ρ %dx%d" % [density_matrix.n, density_matrix.n]
	return "QuantumComponent(id=%d, regs=%s, %s)" % [component_id, register_ids, dim_str]

## Ensure component has a density matrix representation (convert if needed)
func ensure_density_matrix() -> ComplexMatrix:
	"""Get or create density matrix. Converts from statevector if needed."""
	if not is_pure or density_matrix == null:
		if state_vector:
			# Convert |ψ⟩ to ρ = |ψ⟩⟨ψ|
			density_matrix = ComplexMatrix.from_statevector(state_vector)
		else:
			# Create maximally mixed state I/N
			density_matrix = ComplexMatrix.identity(hilbert_dimension())
			density_matrix = density_matrix.scale_real(1.0 / hilbert_dimension())
		is_pure = false
	return density_matrix

## Merge this component with another (tensor product)
func merge_with(other: QuantumComponent) -> QuantumComponent:
	"""
	Merge two components into tensor product.
	Returns new component with merged state and register list.
	"""
	var merged = QuantumComponent.new(component_id)
	merged.register_ids = register_ids + other.register_ids

	# Tensor product of states: ρ_merged = ρ_self ⊗ ρ_other
	var my_rho = ensure_density_matrix()
	var other_rho = other.ensure_density_matrix()

	# Use sparse-optimized tensor product
	merged.density_matrix = my_rho.tensor_product(other_rho)
	merged.is_pure = false

	return merged

## Get marginal density matrix for a single register (2×2)
func get_marginal_2x2(register_id: int) -> ComplexMatrix:
	"""
	Extract 2×2 reduced density matrix for one register's measurement basis.

	If register is index i in component, traces out all others.
	Used for accessing qubit properties without full state knowledge.
	"""
	var reg_index = register_ids.find(register_id)
	if reg_index < 0:
		push_error("Register %d not in component %d" % [register_id, component_id])
		return ComplexMatrix.identity(2)

	var rho = ensure_density_matrix()
	var dim = hilbert_dimension()

	# Partial trace: trace out all qubits except register at position reg_index
	# Result is 2×2 matrix of probabilities/coherences for that qubit's measurement basis

	var rho_marginal = ComplexMatrix.new(2)

	# Special case: single-qubit component (no tracing needed)
	if register_ids.size() == 1:
		# For single-qubit, the marginal IS the full 2×2 density matrix
		return rho

	# For multi-qubit components, compute partial trace
	# For each element of the 2×2 result
	for alpha in range(2):  # Result basis state (north/south for target)
		for beta in range(2):
			# Sum over all basis states of other qubits: Tr_other[ρ]_{α,β}
			var sum = Complex.zero()

			# Generate all basis states for "other" qubits
			var other_dim = dim >> 1  # Dimension for other qubits
			for other_state in range(other_dim):
				# Construct full state indices where target qubit = alpha/beta
				var state_a = _insert_bit_at_position(other_state, alpha, reg_index, register_ids.size())
				var state_b = _insert_bit_at_position(other_state, beta, reg_index, register_ids.size())

				# Add ρ[state_a][state_b] to sum
				sum = sum.add(rho.get_element(state_a, state_b))

			rho_marginal.set_element(alpha, beta, sum)

	return rho_marginal

## Helper: Insert a single bit at a specific position in a multi-qubit state index
func _insert_bit_at_position(other_state: int, target_bit: int, position: int, total_qubits: int) -> int:
	"""
	Insert a single bit (0 or 1) at a specific qubit position in a multi-qubit state index.

	Example: other_state=5 (binary 101), target_bit=1, position=1, total_qubits=3
	Result: 111 (7) - the bit 1 is inserted at position 1
	"""
	var lower_mask = (1 << position) - 1  # Bits below position
	var lower_bits = other_state & lower_mask

	var upper_bits = (other_state >> position) << (position + 1)  # Shift remaining bits up by 1

	return upper_bits | (target_bit << position) | lower_bits

## Recursive helper for partial trace (internal) - DEPRECATED, use direct computation above
func _partial_trace_recursive(
	rho: ComplexMatrix,
	regs: Array[int],
	target_index: int,
	alpha: int,
	beta: int,
	other_index: int,
	result: Complex
) -> Complex:
	"""
	DEPRECATED: Use direct computation in get_marginal_2x2 instead.
	This was a stub implementation that didn't work correctly.
	"""
	push_warning("_partial_trace_recursive is deprecated, using direct computation")
	return Complex.zero()

## Get probability of measuring basis state (0 or 1)
func get_probability_outcome(register_id: int, outcome: int) -> float:
	"""
	Get Born probability: P(outcome | register_id) = ρ[outcome, outcome] (marginal).
	outcome: 0 = "north" (|0⟩), 1 = "south" (|1⟩)
	"""
	var marginal = get_marginal_2x2(register_id)
	return marginal.get_element(outcome, outcome).re

## Get coherence between two basis states
func get_coherence(register_id: int) -> float:
	"""
	Get off-diagonal element |ρ₀₁| (coherence between basis states).
	Indicates entanglement with measurement basis.
	"""
	var marginal = get_marginal_2x2(register_id)
	return marginal.get_element(0, 1).abs()

## Get purity of marginal state: Tr(ρ_marginal²)
func get_purity(register_id: int) -> float:
	"""
	Compute purity of single-qubit marginal: P = Tr(ρ²).
	P=1 → pure, P=1/2 → maximally mixed (for 2×2).
	"""
	var marginal = get_marginal_2x2(register_id)
	var marginal_sq = marginal.mul(marginal)
	var tr = marginal_sq.trace()
	return tr.re

## Validate quantum invariants (debug mode)
func validate_invariants(tolerance: float = 1e-10) -> bool:
	"""
	Check Hermiticity, Trace=1, PSD of density matrix.
	Called after any operation if debug mode enabled.
	"""
	var rho = ensure_density_matrix()

	# Check Hermitian: ρ = ρ†
	if not rho.is_hermitian(tolerance):
		push_warning("Component %d: ρ not Hermitian!" % component_id)
		return false

	# Check Trace: Tr(ρ) = 1
	var tr = rho.trace()
	if abs(tr.re - 1.0) > tolerance:
		push_warning("Component %d: Tr(ρ) = %.6f, not 1!" % [component_id, tr.re])
		return false

	# Check PSD: ρ ≥ 0 (all eigenvalues ≥ 0)
	if not rho.is_positive_semidefinite(tolerance):
		push_warning("Component %d: ρ not PSD!" % component_id)
		return false

	return true
