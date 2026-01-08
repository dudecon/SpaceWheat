class_name Hamiltonian
extends RefCounted

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")

## Hamiltonian: The energy operator for unitary evolution
##
## Physics:
## - Generates unitary time evolution: U(t) = exp(-iHt)
## - Hermitian by construction: H = H†
## - Diagonal elements: self-energies (natural frequencies)
## - Off-diagonal elements: couplings between states
##
## For density matrix evolution:
## - ρ(t) = U(t) ρ(0) U†(t)
## - Equivalent to: dρ/dt = -i[H, ρ] (Liouville-von Neumann equation)
##
## Time-dependent driving:
## - Icons can specify driver functions (cosine, sine, pulse)
## - Hamiltonian is rebuilt each frame with current time

var _matrix: ComplexMatrix
var _dimension: int = 0
var emoji_list: Array[String] = []
var emoji_to_index: Dictionary = {}
var _icons: Array = []  # Reference to Icon objects for time-dependent terms
var _static_matrix: ComplexMatrix  # Cached static part
var _has_drivers: bool = false  # Whether any time-dependent terms exist
var _sparse_matrix: Dictionary = {}  # Sparse representation {i: {j: Complex}} for optimization

#region Construction

## Initialize empty Hamiltonian
func _init():
	_matrix = ComplexMatrix.new(0)

## Build Hamiltonian from Icons and emoji list
func build_from_icons(icons: Array, emojis: Array) -> void:
	# Store references
	_icons = icons
	emoji_list = []
	emoji_to_index = {}

	for i in range(emojis.size()):
		var emoji = emojis[i]
		emoji_list.append(emoji)
		emoji_to_index[emoji] = i

	_dimension = emojis.size()
	_matrix = ComplexMatrix.new(_dimension)
	_static_matrix = ComplexMatrix.new(_dimension)

	# Check for time-dependent drivers
	_has_drivers = false
	for icon in icons:
		if icon.self_energy_driver != "":
			_has_drivers = true
			break

	# Build matrix from Icons
	_build_matrix(0.0)

	# Cache static part (for efficiency when no drivers)
	if not _has_drivers:
		_static_matrix = _matrix.duplicate()

## Build/rebuild matrix at given time (for time-dependent Hamiltonians)
func _build_matrix(time: float) -> void:
	# Reset to zeros
	for i in range(_dimension * _dimension):
		_matrix._data[i] = Complex.zero()

	# Reset sparse matrix
	_sparse_matrix = {}

	# Build from each Icon
	for icon in _icons:
		var i = emoji_to_index.get(icon.emoji, -1)
		if i < 0:
			continue

		# Diagonal: self-energy (possibly time-dependent)
		var self_e = icon.get_self_energy(time)
		var current_diag = _matrix.get_element(i, i)
		var new_diag = current_diag.add(Complex.new(self_e, 0.0))
		_matrix.set_element(i, i, new_diag)

		# Store in sparse format if non-zero
		if new_diag.abs() > 1e-15:
			if not _sparse_matrix.has(i):
				_sparse_matrix[i] = {}
			_sparse_matrix[i][i] = new_diag

		# Off-diagonal: Hamiltonian couplings
		for target_emoji in icon.hamiltonian_couplings:
			var j = emoji_to_index.get(target_emoji, -1)
			if j >= 0:
				var coupling = icon.hamiltonian_couplings[target_emoji]
				# Symmetrize: H[i,j] = H[j,i]* (for Hermiticity)
				# Assuming real couplings, just add to both
				var half_coupling = coupling / 2.0
				var current_ij = _matrix.get_element(i, j)
				var current_ji = _matrix.get_element(j, i)
				var new_ij = current_ij.add(Complex.new(half_coupling, 0.0))
				var new_ji = current_ji.add(Complex.new(half_coupling, 0.0))
				_matrix.set_element(i, j, new_ij)
				_matrix.set_element(j, i, new_ji)

				# Store in sparse format if non-zero
				if new_ij.abs() > 1e-15:
					if not _sparse_matrix.has(i):
						_sparse_matrix[i] = {}
					_sparse_matrix[i][j] = new_ij
				if new_ji.abs() > 1e-15:
					if not _sparse_matrix.has(j):
						_sparse_matrix[j] = {}
					_sparse_matrix[j][i] = new_ji

	# Ensure Hermiticity
	_enforce_hermitian()

## Ensure Hamiltonian is Hermitian: H = (H + H†)/2
func _enforce_hermitian() -> void:
	_matrix = _matrix.add(_matrix.dagger()).scale_real(0.5)

## Update time-dependent terms
func update(time: float) -> void:
	if _has_drivers:
		_build_matrix(time)

#endregion

#region Evolution Operators

## Get unitary evolution operator: U(dt) = exp(-iH·dt)
## Uses matrix exponential for exact evolution
func get_evolution_operator(dt: float) -> ComplexMatrix:
	# U = exp(-iH·dt)
	# First compute -iH·dt
	var scaled = _matrix.scale(Complex.new(0.0, -dt))
	return scaled.expm()

## Get Cayley form evolution operator: U = (I - iHdt/2)⁻¹(I + iHdt/2)
## Exactly unitary, cheaper than full expm, accurate for small dt
func get_cayley_operator(dt: float) -> ComplexMatrix:
	var ident = ComplexMatrix.identity(_dimension)
	var half_dt = dt / 2.0

	# iH·dt/2
	var ihdt = _matrix.scale(Complex.new(0.0, half_dt))

	# (I - iHdt/2)
	var denom = ident.sub(ihdt)

	# (I + iHdt/2)
	var numer = ident.add(ihdt)

	# U = denom⁻¹ × numer
	return denom.inverse().mul(numer)

## Get sparse commutator: [H, ρ] = Hρ - ρH
## Optimized for sparse H - only processes non-zero Hamiltonian elements
## Returns ComplexMatrix (result is generally dense even if H is sparse)
func get_sparse_commutator(rho: ComplexMatrix) -> ComplexMatrix:
	var result = ComplexMatrix.new(_dimension)

	# Compute [H,ρ] = Hρ - ρH using sparse H
	# Only iterate over non-zero elements of H
	# Use direct array access for performance (skip bounds checking)

	var rho_data = rho._data
	var result_data = result._data
	var dim = _dimension

	for i in _sparse_matrix.keys():
		for j in _sparse_matrix[i].keys():
			var H_ij = _sparse_matrix[i][j]

			# Contribution to (Hρ)
			for k in range(dim):
				var rho_jk = rho_data[j * dim + k]
				var contrib1 = H_ij.mul(rho_jk)
				var idx = i * dim + k
				result_data[idx] = result_data[idx].add(contrib1)

			# Contribution to -(ρH)
			for k in range(dim):
				var rho_ki = rho_data[k * dim + i]
				var contrib2 = rho_ki.mul(H_ij)
				var idx = k * dim + j
				result_data[idx] = result_data[idx].sub(contrib2)

	return result

#endregion

#region Observables

## Get expected energy: ⟨E⟩ = Tr(ρH)
func get_expected_energy(rho) -> float:
	return rho.get_expected_value(_matrix).re

## Get energy uncertainty: ΔE = √(⟨H²⟩ - ⟨H⟩²)
func get_energy_uncertainty(rho) -> float:
	var H_sq = _matrix.mul(_matrix)
	var E_sq = rho.get_expected_value(H_sq).re
	var E = get_expected_energy(rho)
	var variance = E_sq - E * E
	return sqrt(max(0.0, variance))

## Get matrix element
func get_element(i: int, j: int) -> Complex:
	return _matrix.get_element(i, j)

## Get full matrix
func get_matrix() -> ComplexMatrix:
	return _matrix

## Get dimension
func dimension() -> int:
	return _dimension

#endregion

#region Validation

## Verify Hamiltonian is Hermitian
func is_hermitian(tolerance: float = 1e-10) -> bool:
	return _matrix.is_hermitian(tolerance)

## Get eigenspectrum (for verification)
func get_spectrum() -> Array:
	var eig = _matrix.eigensystem()
	return eig.eigenvalues

#endregion

#region Debug

func _to_string() -> String:
	return "Hamiltonian(%d states, time-dep=%s)" % [_dimension, str(_has_drivers)]

func debug_print() -> void:
	print("=== Hamiltonian ===")
	print("Dimension: %d" % _dimension)
	print("Time-dependent: %s" % str(_has_drivers))
	print("Emojis: %s" % [", ".join(emoji_list)])
	print("Eigenvalues: %s" % [get_spectrum()])
	print("\nMatrix:")
	print(_matrix)

#endregion
