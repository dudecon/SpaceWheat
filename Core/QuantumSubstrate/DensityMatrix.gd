class_name DensityMatrix
extends RefCounted

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")

## Density Matrix: The quantum state representation
##
## The density matrix ρ is the fundamental object in quantum mechanics:
## - Pure states: ρ = |ψ⟩⟨ψ| (rank 1, Tr(ρ²) = 1)
## - Mixed states: ρ = Σᵢ pᵢ|ψᵢ⟩⟨ψᵢ| (Tr(ρ²) < 1)
##
## Properties:
## - Hermitian: ρ = ρ†
## - Positive semidefinite: all eigenvalues ≥ 0
## - Unit trace: Tr(ρ) = 1
##
## Observables are computed, never stored:
## - Probability: P(i) = ρᵢᵢ (diagonal element)
## - Coherence: ρᵢⱼ (off-diagonal element)
## - Purity: Tr(ρ²)
## - Entropy: S = -Tr(ρ log ρ)
## - Expected value: ⟨O⟩ = Tr(ρO)

var _matrix
var emoji_list: Array[String] = []
var emoji_to_index: Dictionary = {}

#region Constructors

func _init():
	_matrix = ComplexMatrix.new(0)

## Initialize with a list of emojis (basis states)
func initialize_with_emojis(emojis: Array) -> void:
	emoji_list = []
	emoji_to_index = {}
	for i in range(emojis.size()):
		var emoji = emojis[i]
		emoji_list.append(emoji)
		emoji_to_index[emoji] = i

	var n = emojis.size()
	_matrix = ComplexMatrix.new(n)

	# Start in maximally mixed state
	var prob = 1.0 / n
	for i in range(n):
		_matrix.set_element(i, i, Complex.new(prob, 0.0))

## Create pure state from amplitudes: ρ = |ψ⟩⟨ψ|
func set_pure_state(amplitudes: Array) -> void:
	if amplitudes.size() != dimension():
		push_error("Amplitude array size mismatch: %d vs %d" % [amplitudes.size(), dimension()])
		return

	# ρ = |ψ⟩⟨ψ| = outer product
	for i in range(dimension()):
		for j in range(dimension()):
			_matrix.set_element(i, j, amplitudes[i].mul(amplitudes[j].conjugate()))

	_ensure_normalized()

## Create maximally mixed state: ρ = I/N
func set_maximally_mixed() -> void:
	var n = dimension()
	if n == 0:
		return
	var prob = 1.0 / n
	for i in range(n):
		for j in range(n):
			if i == j:
				_matrix.set_element(i, j, Complex.new(prob, 0.0))
			else:
				_matrix.set_element(i, j, Complex.zero())

## Create classical mixture from probabilities (diagonal density matrix)
func set_classical_mixture(probabilities: Array) -> void:
	if probabilities.size() != dimension():
		push_error("Probability array size mismatch")
		return

	for i in range(dimension()):
		for j in range(dimension()):
			if i == j:
				_matrix.set_element(i, j, Complex.new(probabilities[i], 0.0))
			else:
				_matrix.set_element(i, j, Complex.zero())

	_ensure_normalized()

## Deep copy
func duplicate_density():
	var copy = load("res://Core/QuantumSubstrate/DensityMatrix.gd").new()
	copy.emoji_list = emoji_list.duplicate()
	copy.emoji_to_index = emoji_to_index.duplicate()
	copy._matrix = _matrix.duplicate()
	return copy

#endregion

#region Matrix Access

## Get dimension (number of basis states)
func dimension() -> int:
	return _matrix.n

## Direct access to underlying matrix (for evolution operations)
func get_matrix():
	return _matrix

## Set matrix directly (used by evolution operators)
func set_matrix(m) -> void:
	if m.n != dimension():
		push_error("Matrix dimension mismatch")
		return
	_matrix = m

#endregion

#region Observables (All Computed)

## Get probability of basis state i: P(i) = ρᵢᵢ
func get_probability_by_index(i: int) -> float:
	if i < 0 or i >= dimension():
		return 0.0
	return _matrix.get_element(i, i).re  # Real part (should be real for valid ρ)

## Get probability of emoji state: P(emoji) = ρᵢᵢ where i = index of emoji
func get_probability(emoji: String) -> float:
	var idx = emoji_to_index.get(emoji, -1)
	if idx < 0:
		return 0.0
	return get_probability_by_index(idx)

## Get coherence between states i and j: ρᵢⱼ
func get_coherence_by_index(i: int, j: int):
	if i < 0 or i >= dimension() or j < 0 or j >= dimension():
		return Complex.zero()
	return _matrix.get_element(i, j)

## Get coherence between emoji states
func get_coherence(emoji_a: String, emoji_b: String):
	var i = emoji_to_index.get(emoji_a, -1)
	var j = emoji_to_index.get(emoji_b, -1)
	if i < 0 or j < 0:
		return Complex.zero()
	return get_coherence_by_index(i, j)

## Purity: Tr(ρ²) - 1 for pure, 1/N for maximally mixed
func get_purity() -> float:
	var rho_squared = _matrix.mul(_matrix)
	return rho_squared.trace().re

## Von Neumann entropy: S = -Tr(ρ log ρ) = -Σᵢ λᵢ log λᵢ
func get_entropy() -> float:
	var eig = _matrix.eigensystem()
	var entropy = 0.0
	for eigenvalue in eig.eigenvalues:
		if eigenvalue > 1e-14:
			entropy -= eigenvalue * log(eigenvalue)
	return entropy

## Expected value of observable: ⟨O⟩ = Tr(ρO)
func get_expected_value(observable):
	if observable.n != dimension():
		push_error("Observable dimension mismatch")
		return Complex.zero()
	return _matrix.mul(observable).trace()

## Trace (should always be 1)
func get_trace() -> float:
	return _matrix.trace().re

#endregion

#region Projection onto 2D Subspace (Bloch Sphere Visualization)

## Project density matrix onto a 2D subspace defined by north and south emojis
## Returns dictionary with Bloch sphere coordinates:
##   theta: polar angle [0, π] - 0 is north pole, π is south pole
##   phi: azimuthal angle [0, 2π]
##   radius: |r⃗| - 1 for pure states in subspace, <1 for mixed
##   purity: Tr(ρ_reduced²) - purity of the 2x2 reduced state
func project_onto_subspace(north: String, south: String) -> Dictionary:
	var n_idx = emoji_to_index.get(north, -1)
	var s_idx = emoji_to_index.get(south, -1)

	if n_idx < 0 or s_idx < 0:
		push_warning("Projection emojis not found: %s, %s" % [north, south])
		return {"theta": PI/2, "phi": 0.0, "radius": 0.0, "purity": 0.5, "p_north": 0.0, "p_south": 0.0, "p_subspace": 0.0}

	# Extract 2x2 reduced density matrix
	var p_n = get_probability_by_index(n_idx)
	var p_s = get_probability_by_index(s_idx)
	var coherence = get_coherence_by_index(n_idx, s_idx)

	# Total probability in subspace
	var p_total = p_n + p_s
	if p_total < 1e-14:
		return {"theta": PI/2, "phi": 0.0, "radius": 0.0, "purity": 0.5, "p_north": p_n, "p_south": p_s, "p_subspace": p_total}

	# Normalize to subspace
	var rho_nn = p_n / p_total
	var rho_ss = p_s / p_total
	var rho_ns = Complex.new(coherence.re / p_total, coherence.im / p_total)

	# Bloch vector components:
	# For 2x2 density matrix: ρ = (I + r⃗·σ⃗)/2
	# r_x = 2 Re(ρ₀₁) = 2 Re(rho_ns)
	# r_y = 2 Im(ρ₀₁) = 2 Im(rho_ns)
	# r_z = ρ₀₀ - ρ₁₁ = rho_nn - rho_ss
	var r_x = 2.0 * rho_ns.re
	var r_y = 2.0 * rho_ns.im
	var r_z = rho_nn - rho_ss

	# Bloch sphere radius: |r⃗|
	var radius = sqrt(r_x*r_x + r_y*r_y + r_z*r_z)

	# Convert to spherical coordinates
	# theta: angle from +z axis (north pole)
	# phi: azimuthal angle in x-y plane
	var theta: float
	var phi: float

	if radius < 1e-14:
		# Maximally mixed - at center of sphere
		theta = PI / 2.0
		phi = 0.0
	else:
		# Normalize Bloch vector
		var r_z_norm = r_z / radius
		theta = acos(clamp(r_z_norm, -1.0, 1.0))
		phi = atan2(r_y, r_x)
		if phi < 0:
			phi += 2.0 * PI

	# 2x2 purity
	var purity_2x2 = rho_nn * rho_nn + rho_ss * rho_ss + 2.0 * rho_ns.abs_sq()

	# Scale radius by total probability in subspace (how much state is in this subspace)
	var scaled_radius = radius * sqrt(p_total)

	return {
		"theta": theta,
		"phi": phi,
		"radius": scaled_radius,
		"purity": purity_2x2,
		"p_north": p_n,
		"p_south": p_s,
		"p_subspace": p_total
	}

#endregion

#region State Manipulation

## Apply unitary evolution: ρ' = UρU†
func apply_unitary(U) -> void:
	var new_rho = U.mul(_matrix).mul(U.dagger())
	_matrix = new_rho
	_enforce_hermitian()

## Apply Lindblad superoperator term: L ρ L† - ½{L†L, ρ}
func apply_lindblad_term(L, rate: float, dt: float) -> void:
	var L_dag = L.dagger()
	var L_dag_L = L_dag.mul(L)

	# γ(LρL† - ½{L†L, ρ})
	var term1 = L.mul(_matrix).mul(L_dag)
	var term2 = L_dag_L.mul(_matrix)
	var term3 = _matrix.mul(L_dag_L)

	var drho = term1.sub(term2.scale_real(0.5)).sub(term3.scale_real(0.5))
	_matrix = _matrix.add(drho.scale_real(rate * dt))

	_enforce_trace_one()
	_enforce_hermitian()

## Normalize to unit trace
func _ensure_normalized() -> void:
	var tr = _matrix.trace().re
	if abs(tr) > 1e-14 and abs(tr - 1.0) > 1e-10:
		_matrix = _matrix.scale_real(1.0 / tr)

## Enforce trace = 1 (with numerical robustness)
func _enforce_trace_one() -> void:
	var tr = _matrix.trace().re
	if abs(tr) > 1e-14:
		_matrix = _matrix.scale_real(1.0 / tr)

## Enforce Hermiticity: ρ = (ρ + ρ†)/2
func _enforce_hermitian() -> void:
	var hermitian = _matrix.add(_matrix.dagger()).scale_real(0.5)
	_matrix = hermitian

#endregion

#region Validation

## Check if density matrix is valid
func is_valid(tolerance: float = 1e-8) -> Dictionary:
	var result = {
		"valid": true,
		"hermitian": _matrix.is_hermitian(tolerance),
		"positive_semidefinite": _matrix.is_positive_semidefinite(tolerance),
		"unit_trace": _matrix.has_unit_trace(tolerance),
		"trace": _matrix.trace().re,
		"purity": get_purity()
	}

	result.valid = result.hermitian and result.positive_semidefinite and result.unit_trace
	return result

#endregion

#region Debug

func _to_string() -> String:
	return "DensityMatrix(%d states, purity=%.4f, trace=%.4f)" % [
		dimension(), get_purity(), get_trace()
	]

## Detailed debug output
func debug_print() -> void:
	print("=== Density Matrix ===")
	print("Dimension: %d" % dimension())
	print("Emojis: %s" % [", ".join(emoji_list)])
	print("Trace: %.6f" % get_trace())
	print("Purity: %.6f" % get_purity())
	print("Entropy: %.6f" % get_entropy())
	print("\nProbabilities:")
	for i in range(dimension()):
		print("  %s: %.4f" % [emoji_list[i], get_probability_by_index(i)])
	print("\nMatrix:")
	print(_matrix)

#endregion
