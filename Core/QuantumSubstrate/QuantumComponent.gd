class_name QuantumComponent
extends Resource

## Legacy Model B component container (deprecated).
## Kept as a minimal compatibility shim for QuantumComputer's component APIs.

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")

@export var component_id: int = -1
@export var register_ids: Array[int] = []
@export var state_vector: Array = []
@export var density_matrix: ComplexMatrix = null
@export var is_pure: bool = true


func _init(comp_id: int = -1) -> void:
	component_id = comp_id


func register_count() -> int:
	return register_ids.size()


func hilbert_dimension() -> int:
	return 1 << register_count()


func ensure_density_matrix() -> ComplexMatrix:
	if density_matrix:
		return density_matrix

	if state_vector.is_empty():
		_initialize_default_state()

	density_matrix = _density_from_state_vector(state_vector)
	return density_matrix


func merge_with(other: QuantumComponent) -> QuantumComponent:
	var merged = QuantumComponent.new(component_id)
	merged.register_ids = register_ids.duplicate()
	merged.register_ids.append_array(other.register_ids)

	var can_use_state = is_pure and other.is_pure \
		and not state_vector.is_empty() and not other.state_vector.is_empty()
	if can_use_state:
		merged.state_vector = _tensor_product_vector(state_vector, other.state_vector)
		merged.is_pure = true
		merged.density_matrix = _density_from_state_vector(merged.state_vector)
	else:
		var rho_a = ensure_density_matrix()
		var rho_b = other.ensure_density_matrix()
		if rho_a and rho_b:
			merged.density_matrix = rho_a.tensor_product(rho_b)
		merged.is_pure = false

	return merged


func get_marginal_2x2(reg_id: int) -> ComplexMatrix:
	var result = ComplexMatrix.new(2)
	var reg_index = register_ids.find(reg_id)
	if reg_index < 0:
		return result

	var rho = ensure_density_matrix()
	if not rho:
		return result

	var num_qubits = register_count()
	if num_qubits <= 0:
		num_qubits = _infer_qubit_count(rho.n)
	if num_qubits <= 0:
		return result

	var shift = num_qubits - 1 - reg_index
	var target_bit = 1 << shift
	var mask_other = ((1 << num_qubits) - 1) ^ target_bit

	for i in range(rho.n):
		var i_other = i & mask_other
		var i_bit = (i >> shift) & 1
		for j in range(rho.n):
			if (j & mask_other) != i_other:
				continue
			var j_bit = (j >> shift) & 1
			var accum = result.get_element(i_bit, j_bit)
			result.set_element(i_bit, j_bit, accum.add(rho.get_element(i, j)))

	return result


func get_purity(reg_id: int) -> float:
	var marginal = get_marginal_2x2(reg_id)
	var rho_sq = marginal.mul(marginal)
	return clamp(rho_sq.trace().re, 0.0, 1.0)


func get_coherence(reg_id: int) -> float:
	var marginal = get_marginal_2x2(reg_id)
	return marginal.get_element(0, 1).abs()


func validate_invariants() -> bool:
	if not density_matrix:
		return true
	return density_matrix.is_hermitian() \
		and density_matrix.is_positive_semidefinite() \
		and density_matrix.has_unit_trace()


func _initialize_default_state() -> void:
	var dim = hilbert_dimension()
	if dim <= 0:
		dim = 1
	state_vector = []
	state_vector.resize(dim)
	for i in range(dim):
		state_vector[i] = Complex.zero()
	state_vector[0] = Complex.one()


func _density_from_state_vector(vec: Array) -> ComplexMatrix:
	var dim = vec.size()
	var rho = ComplexMatrix.new(dim)
	for i in range(dim):
		for j in range(dim):
			rho.set_element(i, j, vec[i].mul(vec[j].conjugate()))
	return rho


func _tensor_product_vector(vec_a: Array, vec_b: Array) -> Array:
	var result: Array = []
	for a in vec_a:
		for b in vec_b:
			result.append(a.mul(b))
	return result


func _infer_qubit_count(dim: int) -> int:
	if dim <= 0:
		return 0
	var count = 0
	var size = dim
	while size > 1:
		size >>= 1
		count += 1
	return count


func _to_string() -> String:
	return "QuantumComponent(id=%d, registers=%d, pure=%s)" % [
		component_id, register_ids.size(), str(is_pure)
	]
