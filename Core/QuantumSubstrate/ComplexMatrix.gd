class_name ComplexMatrix
extends RefCounted

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

# Self-reference helper for internal constructors (avoid circular reference issues)
static var _class_ref = null

#region Native Backend (GDExtension Acceleration)

## Native backend detection - checked once, cached
static var _native_available: bool = false
static var _native_checked: bool = false

static func _check_native() -> void:
	if _native_checked:
		return
	_native_checked = true

	if ClassDB.class_exists("QuantumMatrixNative"):
		_native_available = true
		print("ComplexMatrix: Native acceleration enabled (Eigen)")
	else:
		_native_available = false
		print("ComplexMatrix: Using pure GDScript")

static func is_native_available() -> bool:
	_check_native()
	return _native_available

## Instance-level native backend
var _native_backend = null

func _get_native():
	if _native_backend == null and _native_available and n > 0:
		_native_backend = ClassDB.instantiate("QuantumMatrixNative")
	return _native_backend

## Marshal GDScript data to PackedFloat64Array for native (DENSE)
func _to_packed() -> PackedFloat64Array:
	var packed = PackedFloat64Array()
	packed.resize(n * n * 2)
	for i in range(n * n):
		packed[i * 2] = _data[i].re
		packed[i * 2 + 1] = _data[i].im
	return packed

## Unmarshal PackedFloat64Array back to GDScript (DENSE)
func _from_packed(packed: PackedFloat64Array, dim: int) -> void:
	n = dim
	_data = []
	for i in range(n * n):
		_data.append(Complex.new(packed[i * 2], packed[i * 2 + 1]))

#region Sparse Matrix Transfer (CSR Format)

## Sparsity threshold - elements below this magnitude are considered zero
const SPARSITY_THRESHOLD: float = 1e-12

## Calculate sparsity ratio (0.0 = all zero, 1.0 = all non-zero)
func get_sparsity_ratio() -> float:
	var nonzero_count = 0
	var total = n * n
	for i in range(total):
		if _data[i].abs() > SPARSITY_THRESHOLD:
			nonzero_count += 1
	return float(nonzero_count) / float(total) if total > 0 else 0.0

## Count non-zero elements
func count_nonzeros() -> int:
	var count = 0
	for i in range(n * n):
		if _data[i].abs() > SPARSITY_THRESHOLD:
			count += 1
	return count

## Marshal to CSR (Compressed Sparse Row) format for efficient transfer
## Returns Dictionary with: row_ptr, col_idx, values_real, values_imag, dim, nnz
func _to_packed_csr() -> Dictionary:
	var row_ptr = PackedInt32Array()
	var col_idx = PackedInt32Array()
	var values_real = PackedFloat64Array()
	var values_imag = PackedFloat64Array()

	row_ptr.resize(n + 1)
	var current_nnz = 0

	for i in range(n):
		row_ptr[i] = current_nnz
		for j in range(n):
			var elem = get_element(i, j)
			if elem.abs() > SPARSITY_THRESHOLD:
				col_idx.append(j)
				values_real.append(elem.re)
				values_imag.append(elem.im)
				current_nnz += 1

	row_ptr[n] = current_nnz

	return {
		"format": "csr",
		"dim": n,
		"nnz": current_nnz,
		"row_ptr": row_ptr,
		"col_idx": col_idx,
		"values_real": values_real,
		"values_imag": values_imag
	}

## Unmarshal from CSR format
func _from_packed_csr(csr_data: Dictionary) -> void:
	n = csr_data.dim
	_data = []
	for i in range(n * n):
		_data.append(Complex.zero())

	var row_ptr = csr_data.row_ptr
	var col_idx = csr_data.col_idx
	var values_real = csr_data.values_real
	var values_imag = csr_data.values_imag

	for i in range(n):
		var row_start = row_ptr[i]
		var row_end = row_ptr[i + 1]
		for k in range(row_start, row_end):
			var j = col_idx[k]
			set_element(i, j, Complex.new(values_real[k], values_imag[k]))

## Smart marshal: choose dense or sparse based on sparsity ratio
## Uses sparse if less than 40% non-zero (60% sparse or more)
func _to_packed_auto() -> Dictionary:
	var sparsity_ratio = get_sparsity_ratio()
	var use_sparse = sparsity_ratio < 0.4  # Use sparse if <40% non-zero

	if use_sparse:
		var csr = _to_packed_csr()
		# Calculate transfer savings for logging
		var dense_bytes = n * n * 2 * 8
		var sparse_bytes = (n + 1) * 4 + csr.nnz * 4 + csr.nnz * 2 * 8
		# Only use sparse if it actually saves bytes
		if sparse_bytes < dense_bytes:
			return csr

	# Fall back to dense
	return {
		"format": "dense",
		"dim": n,
		"data": _to_packed()
	}

## Smart unmarshal: detect format and use appropriate method
func _from_packed_auto(packed_data) -> void:
	if packed_data is Dictionary:
		if packed_data.format == "csr":
			_from_packed_csr(packed_data)
		else:
			_from_packed(packed_data.data, packed_data.dim)
	else:
		# Legacy: PackedFloat64Array, assume square matrix
		var dim = int(sqrt(packed_data.size() / 2))
		_from_packed(packed_data, dim)

#endregion

## Sync current matrix to native backend
func _sync_to_native() -> void:
	var native = _get_native()
	if native and n > 0:
		native.from_packed(_to_packed(), n)

## Create result matrix from packed native output
func _result_from_packed(packed: PackedFloat64Array, dim: int):
	var result = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(dim)
	result._from_packed(packed, dim)
	return result

#endregion

## N×N Complex Matrix for quantum mechanics
## Supports density matrices, Hamiltonians, and unitary operators
##
## Key operations:
## - Arithmetic: add, sub, mul, scale
## - Linear algebra: inverse, determinant, trace
## - Quantum: dagger (Hermitian conjugate), commutator, expm (matrix exponential)

var n: int = 0  # Dimension
var _data: Array = []  # Flat array: element (i,j) at index i*n + j

func _init(dimension: int = 0):
	_check_native()
	n = dimension
	_data = []
	for i in range(n * n):
		_data.append(Complex.zero())

## Create zero matrix of given dimension
static func zeros(dimension: int):
	return load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(dimension)

## Create identity matrix
static func identity(dimension: int):
	var m = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(dimension)
	for i in range(dimension):
		m.set_element(i, i, Complex.one())
	return m

## Create from 2D array of Complex numbers
static func from_array(arr: Array):
	var dim = arr.size()
	var m = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(dim)
	for i in range(dim):
		for j in range(dim):
			if j < arr[i].size():
				m.set_element(i, j, arr[i][j])
	return m

## Create diagonal matrix from array of Complex numbers
static func diagonal(diag: Array):
	var dim = diag.size()
	var m = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(dim)
	for i in range(dim):
		m.set_element(i, i, diag[i])
	return m

## Deep copy
func duplicate():
	var m = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(n)
	for i in range(n * n):
		m._data[i] = Complex.new(_data[i].re, _data[i].im)
	return m

#region Element Access

func get_element(i: int, j: int):
	if i < 0 or i >= n or j < 0 or j >= n:
		push_error("ComplexMatrix index out of bounds: (%d, %d) for %dx%d matrix" % [i, j, n, n])
		return Complex.zero()
	return _data[i * n + j]

func set_element(i: int, j: int, value):
	if i < 0 or i >= n or j < 0 or j >= n:
		push_error("ComplexMatrix index out of bounds: (%d, %d) for %dx%d matrix" % [i, j, n, n])
		return
	_data[i * n + j] = value

#endregion

#region Matrix Arithmetic

func add(other):
	if other.n != n:
		push_error("Matrix dimension mismatch in add: %d vs %d" % [n, other.n])
		return load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(n)
	var result = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(n)
	for i in range(n * n):
		result._data[i] = _data[i].add(other._data[i])
	return result

func sub(other):
	if other.n != n:
		push_error("Matrix dimension mismatch in sub: %d vs %d" % [n, other.n])
		return load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(n)
	var result = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(n)
	for i in range(n * n):
		result._data[i] = _data[i].sub(other._data[i])
	return result

func mul(other):
	if other.n != n:
		push_error("Matrix dimension mismatch in mul: %d vs %d" % [n, other.n])
		return load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(n)

	# Use native acceleration if available
	var native = _get_native()
	if native:
		_sync_to_native()
		var result_packed = native.mul(other._to_packed(), n)
		return _result_from_packed(result_packed, n)

	# Fallback: pure GDScript O(n³)
	var result = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(n)
	for i in range(n):
		for j in range(n):
			var sum = Complex.zero()
			for k in range(n):
				sum = sum.add(get_element(i, k).mul(other.get_element(k, j)))
			result.set_element(i, j, sum)
	return result

func scale(s):
	var result = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(n)
	for i in range(n * n):
		result._data[i] = _data[i].mul(s)
	return result

func scale_real(s: float):
	var result = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(n)
	for i in range(n * n):
		result._data[i] = Complex.new(_data[i].re * s, _data[i].im * s)
	return result

#endregion

#region Linear Algebra Operations

func dagger():
	var result = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(n)
	for i in range(n):
		for j in range(n):
			result.set_element(j, i, get_element(i, j).conjugate())
	return result

func trace():
	var sum = Complex.zero()
	for i in range(n):
		sum = sum.add(get_element(i, i))
	return sum


func compute_energy_split() -> Dictionary:
	"""Split total energy into Real (diagonal) + Imaginary (off-diagonal)

	For density matrices:
	- Real energy = observable populations (diagonal elements)
	- Imaginary energy = quantum coherence (off-diagonal elements)

	The imaginary energy represents "potential" that can be extracted
	via the Sparks mechanic (coherence → observable conversion).

	Returns:
		{
			"real": float,           # Sum of diagonal probabilities
			"imaginary": float,      # Sum of |off-diagonal| coherences
			"total": float,          # real + imaginary
			"coherence_ratio": float # imaginary / total (0.0 to 1.0)
		}
	"""
	var real_energy = 0.0
	var imaginary_energy = 0.0

	# Real: sum of diagonal (populations)
	for i in range(n):
		real_energy += get_element(i, i).re

	# Imaginary: sum of |off-diagonal| (coherences)
	# Only count upper triangle and multiply by 2 (matrix is Hermitian)
	for i in range(n):
		for j in range(i + 1, n):
			var coherence = get_element(i, j)
			imaginary_energy += coherence.abs() * 2.0  # *2 for symmetry

	var total = real_energy + imaginary_energy
	var ratio = imaginary_energy / total if total > 0.0 else 0.0

	return {
		"real": real_energy,
		"imaginary": imaginary_energy,
		"total": total,
		"coherence_ratio": ratio
	}


func commutator(other):
	return mul(other).sub(other.mul(self))

func anticommutator(other):
	return mul(other).add(other.mul(self))

static func outer_product(ket: Array, bra: Array):
	var dim = ket.size()
	if bra.size() != dim:
		push_error("Outer product dimension mismatch")
		return load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(dim)
	var m = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(dim)
	for i in range(dim):
		for j in range(dim):
			m.set_element(i, j, ket[i].mul(bra[j].conjugate()))
	return m

#endregion

#region Matrix Exponential (Padé Approximation)

func expm():
	# Use native acceleration if available (Eigen's optimized Padé approximation)
	var native = _get_native()
	if native:
		_sync_to_native()
		var result_packed = native.expm()
		return _result_from_packed(result_packed, n)

	# Fallback: pure GDScript Padé [6/6] approximation with scaling and squaring
	# exp(A) = exp(A/2^k)^(2^k) where k chosen so ||A/2^k|| < 1

	# Find scaling factor
	var norm = _one_norm()
	var k = max(0, int(ceil(log(norm) / log(2.0))))
	var scaled = scale_real(1.0 / pow(2.0, k))

	# Padé [6/6] approximation
	var pade = _pade_6_6(scaled)

	# Square k times: (exp(A/2^k))^(2^k)
	for i in range(k):
		pade = pade.mul(pade)

	return pade

func _pade_6_6(A):
	# Padé [6/6] coefficients
	var c = [1.0, 0.5, 0.117857142857143, 0.019841269841270, 0.002480158730159, 0.000198412698412698, 0.000008267195767196]

	var I = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").identity(n)
	var A2 = A.mul(A)
	var A4 = A2.mul(A2)
	var A6 = A2.mul(A4)

	# Numerator: U = A(c1*I + c3*A^2 + c5*A^4)
	var U = I.scale_real(c[1]).add(A2.scale_real(c[3])).add(A4.scale_real(c[5]))
	U = A.mul(U)

	# Denominator: V = c0*I + c2*A^2 + c4*A^4 + c6*A^6
	var V = I.scale_real(c[0]).add(A2.scale_real(c[2])).add(A4.scale_real(c[4])).add(A6.scale_real(c[6]))

	# exp(A) ≈ (V - U)^(-1) (V + U)
	var numerator = V.add(U)
	var denominator = V.sub(U)

	return denominator.inverse().mul(numerator)

func _one_norm() -> float:
	# ||A||_1 = max column sum
	var max_sum = 0.0
	for j in range(n):
		var col_sum = 0.0
		for i in range(n):
			col_sum += get_element(i, j).abs()
		max_sum = max(max_sum, col_sum)
	return max_sum

#endregion

#region Matrix Inverse (Gauss-Jordan)

func inverse():
	if n == 0:
		return load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(0)

	# Use native acceleration if available (Eigen's LU decomposition)
	var native = _get_native()
	if native:
		_sync_to_native()
		var result_packed = native.inverse()
		return _result_from_packed(result_packed, n)

	# Fallback: pure GDScript Gauss-Jordan elimination
	# Create augmented matrix [A | I]
	var aug = []
	for i in range(n):
		var row = []
		for j in range(n):
			row.append(get_element(i, j))
		for j in range(n):
			row.append(Complex.one() if i == j else Complex.zero())
		aug.append(row)

	# Gauss-Jordan elimination
	for pivot in range(n):
		# Find pivot
		var max_row = pivot
		var max_val = aug[pivot][pivot].abs()
		for i in range(pivot + 1, n):
			if aug[i][pivot].abs() > max_val:
				max_val = aug[i][pivot].abs()
				max_row = i

		if max_val < 1e-14:
			push_error("Matrix is singular, cannot invert")
			return load("res://Core/QuantumSubstrate/ComplexMatrix.gd").identity(n)

		# Swap rows
		if max_row != pivot:
			var temp = aug[pivot]
			aug[pivot] = aug[max_row]
			aug[max_row] = temp

		# Scale pivot row
		var pivot_val = aug[pivot][pivot]
		for j in range(2 * n):
			aug[pivot][j] = aug[pivot][j].div(pivot_val)

		# Eliminate column
		for i in range(n):
			if i != pivot:
				var factor = aug[i][pivot]
				for j in range(2 * n):
					aug[i][j] = aug[i][j].sub(factor.mul(aug[pivot][j]))

	# Extract inverse from right half
	var inv = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(n)
	for i in range(n):
		for j in range(n):
			inv.set_element(i, j, aug[i][j + n])

	return inv

#endregion

#region Eigenvalue Decomposition (Jacobi for Hermitian)

func eigensystem() -> Dictionary:
	# Returns { "eigenvalues": Array[float], "eigenvectors": ComplexMatrix }

	if not is_hermitian():
		push_warning("eigensystem() called on non-Hermitian matrix - results may be unreliable")

	# Use native acceleration if available (Eigen's SelfAdjointEigenSolver)
	var native = _get_native()
	if native:
		_sync_to_native()
		var result = native.eigensystem()
		return {
			"eigenvalues": result["eigenvalues"],
			"eigenvectors": _result_from_packed(result["eigenvectors"], n)
		}

	# Fallback: pure GDScript Jacobi iteration for Hermitian matrices
	# Initialize: V = I, A = self
	var V = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").identity(n)
	var A = duplicate()

	var max_iterations = 50 * n * n
	var tolerance = 1e-12

	for iteration in range(max_iterations):
		# Find largest off-diagonal element
		var max_val = 0.0
		var p = 0
		var q = 1
		for i in range(n):
			for j in range(i + 1, n):
				var val = A.get_element(i, j).abs()
				if val > max_val:
					max_val = val
					p = i
					q = j

		# Converged?
		if max_val < tolerance:
			break

		# Compute Givens rotation
		var app = A.get_element(p, p).re
		var aqq = A.get_element(q, q).re
		var apq = A.get_element(p, q)

		var theta = 0.5 * atan2(2.0 * apq.abs(), aqq - app)
		var c = cos(theta)
		var s = sin(theta)

		# Apply rotation to A and V
		_apply_jacobi_rotation(A, V, p, q, c, s)

	# Extract eigenvalues (diagonal of A)
	var eigenvalues = []
	for i in range(n):
		eigenvalues.append(A.get_element(i, i).re)

	return {
		"eigenvalues": eigenvalues,
		"eigenvectors": V  # Columns are eigenvectors
	}

func _apply_jacobi_rotation(A, V, p: int, q: int, c: float, s: float) -> void:
	# Apply Givens rotation to A and accumulate in V
	for i in range(n):
		if i != p and i != q:
			var aip = A.get_element(i, p)
			var aiq = A.get_element(i, q)
			A.set_element(i, p, Complex.new(c * aip.re - s * aiq.re, c * aip.im - s * aiq.im))
			A.set_element(i, q, Complex.new(s * aip.re + c * aiq.re, s * aip.im + c * aiq.im))
			A.set_element(p, i, A.get_element(i, p).conjugate())
			A.set_element(q, i, A.get_element(i, q).conjugate())

	# Update eigenvectors
	for i in range(n):
		var vip = V.get_element(i, p)
		var viq = V.get_element(i, q)
		V.set_element(i, p, Complex.new(c * vip.re - s * viq.re, c * vip.im - s * viq.im))
		V.set_element(i, q, Complex.new(s * vip.re + c * viq.re, s * vip.im + c * viq.im))

	# Update diagonal
	var app = A.get_element(p, p).re
	var aqq = A.get_element(q, q).re
	var apq = A.get_element(p, q)

	A.set_element(p, p, Complex.new(c*c*app - 2*c*s*apq.re + s*s*aqq, 0.0))
	A.set_element(q, q, Complex.new(s*s*app + 2*c*s*apq.re + c*c*aqq, 0.0))
	A.set_element(p, q, Complex.zero())
	A.set_element(q, p, Complex.zero())

#endregion

#region Validation

func is_hermitian(tolerance: float = 1e-10) -> bool:
	for i in range(n):
		for j in range(i, n):
			var aij = get_element(i, j)
			var aji = get_element(j, i)
			if not aij.sub(aji.conjugate()).abs() < tolerance:
				return false
	return true

func is_positive_semidefinite(tolerance: float = 1e-10) -> bool:
	var eig = eigensystem()
	for eigenvalue in eig.eigenvalues:
		if eigenvalue < -tolerance:
			return false
	return true

func has_unit_trace(tolerance: float = 1e-10) -> bool:
	return abs(trace().re - 1.0) < tolerance

#endregion

#region Tensor Products & State Conversion

func tensor_product(other: ComplexMatrix) -> ComplexMatrix:
	"""
	Compute Kronecker product: self ⊗ other (sparse-optimized)
	Result dimension: (n × m) × (n × m) where self is n×n, other is m×m

	Sparse optimization: skip zero blocks, compute only non-zero products.
	Time: O(nnz₁ × nnz₂) where nnz = number of non-zero elements
	"""
	var m = other.n
	var result_dim = n * m
	var result = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(result_dim)

	# Sparse computation: iterate only through non-zero elements of self
	var self_sparsity = _get_sparsity_pattern()
	var other_sparsity = other._get_sparsity_pattern()

	for i_pair in self_sparsity:
		var i = i_pair[0]
		var j = i_pair[1]
		var self_ij = get_element(i, j)

		# Skip if essentially zero
		if self_ij.abs() < 1e-14:
			continue

		# Multiply by all non-zero elements of other
		for k_pair in other_sparsity:
			var k = k_pair[0]
			var l = k_pair[1]
			var other_kl = other.get_element(k, l)

			# Skip if essentially zero
			if other_kl.abs() < 1e-14:
				continue

			# (A ⊗ B)[i*m+k, j*m+l] = A[i,j] * B[k,l]
			var res_i = i * m + k
			var res_j = j * m + l
			result.set_element(res_i, res_j, self_ij.mul(other_kl))

	return result

func _get_sparsity_pattern() -> Array:
	"""
	Get list of (i, j) indices where element is non-zero.
	Caches result for repeated calls.

	Sparse optimization: O(n²) initial scan, then O(nnz) for returns.
	"""
	var pattern = []

	for i in range(n):
		for j in range(n):
			if get_element(i, j).abs() > 1e-14:
				pattern.append([i, j])

	return pattern

static func from_statevector(statevector: Array) -> ComplexMatrix:
	"""
	Convert state vector |ψ⟩ to density matrix ρ = |ψ⟩⟨ψ| (sparse-optimized)

	Input: statevector as Array[Complex]
	Output: density matrix ρ where ρ_ij = ψ_i * conj(ψ_j)

	Sparse optimization: only compute ρ_ij where both ψ_i and ψ_j are non-zero.
	Time: O(nnz²) where nnz = number of non-zero components in |ψ⟩
	Space: O(nnz²) instead of O(n²)

	Typical case: superposition of 2-4 basis states → nnz ≈ 4, time ≈ O(16) vs O(2^(2n))
	"""
	var dim = statevector.size()
	var rho = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(dim)

	# Find non-zero indices in statevector
	var nonzero_indices = []
	for i in range(dim):
		if statevector[i].abs() > 1e-14:
			nonzero_indices.append(i)

	# Only compute ρ_ij for non-zero pairs
	for i in nonzero_indices:
		for j in nonzero_indices:
			var psi_i = statevector[i]
			var psi_j = statevector[j]
			# ρ_ij = ψ_i * conj(ψ_j)
			var rho_ij = psi_i.mul(psi_j.conjugate())
			rho.set_element(i, j, rho_ij)

	return rho

func conjugate_transpose() -> ComplexMatrix:
	"""Alias for dagger() for physics naming convention."""
	return dagger()

func renormalize_trace() -> void:
	"""
	Renormalize matrix so Tr(M) = 1 (in-place).
	Used after measurement/projection to restore unit trace.

	Sparse optimization: only scan non-zero trace elements.
	"""
	var tr = trace()
	var tr_val = tr.abs()

	if tr_val < 1e-14:
		push_warning("Cannot renormalize: trace is essentially zero")
		return

	# Scale all elements by 1/trace
	var scale_factor = Complex.new(1.0 / tr_val, 0.0)

	for i in range(n * n):
		_data[i] = _data[i].mul(scale_factor)

#endregion

#region Debug

func _to_string() -> String:
	var s = "ComplexMatrix(%dx%d):\n" % [n, n]
	for i in range(min(n, 4)):
		s += "  ["
		for j in range(min(n, 4)):
			var elem = get_element(i, j)
			s += "%.3f%+.3fi" % [elem.re, elem.im]
			if j < min(n, 4) - 1:
				s += ", "
		if n > 4:
			s += " ..."
		s += "]\n"
	if n > 4:
		s += "  ...\n"
	return s

#endregion
