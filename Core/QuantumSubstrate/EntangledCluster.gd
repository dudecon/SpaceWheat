class_name EntangledCluster
extends Resource

## N-Qubit Entangled State
## Represents genuinely multi-partite entangled quantum states
##
## Physics: Sequential 2-qubit gates create N-qubit entanglement
## - Start with 2 qubits → Bell pair (|00⟩ + |11⟩)/√2
## - Add 3rd qubit via CNOT → GHZ₃ (|000⟩ + |111⟩)/√2
## - Continue → arbitrary N-qubit states
##
## This is exactly how real quantum computers (Google, IBM) build multi-qubit states!
##
## Supported States:
## - GHZ (Greenberger-Horne-Zeilinger): Maximally entangled, fragile
## - W states: Robust shared excitation
## - Cluster states: Graph states for measurement-based quantum computing
## - Custom: Arbitrary N-qubit states

## Qubits in this cluster
var qubits: Array = []  # Array of DualEmojiQubit references
var qubit_ids: Array[String] = []  # Corresponding plot IDs

## Density Matrix: 2^N × 2^N
## Each element is Vector2(real, imaginary)
## Basis ordering: |000⟩, |001⟩, |010⟩, |011⟩, |100⟩, ...
var density_matrix: Array = []

## Decoherence parameters (shared across cluster)
var coherence_time_T1: float = 100.0  # Amplitude damping
var coherence_time_T2: float = 50.0   # Dephasing

## Cluster type (for display and physics)
enum ClusterType {
	GHZ,      # All-or-nothing perfect correlation
	W_STATE,  # Robust shared single excitation
	CLUSTER,  # Graph state (MBQC)
	CUSTOM    # General N-qubit state
}

var cluster_type: ClusterType = ClusterType.CUSTOM

## Creation timestamp
var creation_time: float = 0.0


func _init():
	creation_time = Time.get_ticks_msec() / 1000.0


## Qubit Management

func add_qubit(qubit, plot_id: String):
	"""Add qubit to cluster (product state extension)

	New qubit starts in separable state |ψ⟩⊗|0⟩.
	Use entangle_new_qubit_cnot() to create entanglement!

	Args:
		qubit: DualEmojiQubit to add
		plot_id: Plot identifier
	"""
	qubits.append(qubit)
	qubit_ids.append(plot_id)

	# Resize density matrix: N → N+1 qubits
	_expand_density_matrix_product()

	if VerboseConfig.is_verbose("quantum"):
		print("➕ Added qubit %s to cluster (size: %d)" % [plot_id, qubits.size()])


func _expand_density_matrix_product():
	"""Expand density matrix for new qubit in |0⟩ state

	ρ_new = ρ_old ⊗ |0⟩⟨0|

	Dimension: 2^N × 2^N → 2^(N+1) × 2^(N+1)
	"""
	var N_old = qubits.size() - 1
	var N_new = qubits.size()

	if N_old == 0:
		# First qubit: Initialize to |0⟩⟨0|
		density_matrix = [
			[Vector2(1.0, 0.0), Vector2(0.0, 0.0)],
			[Vector2(0.0, 0.0), Vector2(0.0, 0.0)]
		]
		return

	var old_dim = int(pow(2, N_old))
	var new_dim = int(pow(2, N_new))

	var new_density = []
	for i in range(new_dim):
		var row = []
		for j in range(new_dim):
			row.append(Vector2(0.0, 0.0))
		new_density.append(row)

	# ρ ⊗ |0⟩⟨0| means new qubit is in north pole (|0⟩)
	# Only blocks where new qubit is 0 are populated
	for i in range(old_dim):
		for j in range(old_dim):
			# Map old indices to new indices (new qubit in state |0⟩)
			var i_new = i * 2  # Append 0 bit
			var j_new = j * 2
			new_density[i_new][j_new] = density_matrix[i][j]

	density_matrix = new_density


## State Initialization

func create_ghz_state():
	"""Create GHZ state: (|00...0⟩ + |11...1⟩)/√2

	All qubits perfectly correlated.
	Measuring one qubit instantly determines all others!

	Properties:
	- Maximally entangled
	- Fragile: Losing ANY qubit → separable state
	- Used in quantum teleportation, superdense coding
	"""
	var N = qubits.size()
	if N < 2:
		push_error("Need at least 2 qubits for GHZ state")
		return

	_clear_density_matrix()

	var dim = int(pow(2, N))
	var amplitude = 0.5  # |c|² = 1/2 for each term

	# |00...0⟩⟨00...0| (basis state 0)
	density_matrix[0][0] = Vector2(amplitude, 0.0)

	# |00...0⟩⟨11...1| (coherence)
	density_matrix[0][dim - 1] = Vector2(amplitude, 0.0)

	# |11...1⟩⟨00...0| (coherence conjugate)
	density_matrix[dim - 1][0] = Vector2(amplitude, 0.0)

	# |11...1⟩⟨11...1| (basis state 2^N-1)
	density_matrix[dim - 1][dim - 1] = Vector2(amplitude, 0.0)

	cluster_type = ClusterType.GHZ

	if VerboseConfig.is_verbose("quantum"):
		print("🌟 Created %d-qubit GHZ state: (|0...0⟩ + |1...1⟩)/√2" % N)


func create_w_state():
	"""Create W state: (|100...0⟩ + |010...0⟩ + ... + |00...01⟩)/√N

	One excitation shared across all qubits.

	Properties:
	- Genuinely multi-partite entangled
	- Robust: Losing one qubit → remaining qubits still entangled!
	- Different entanglement structure than GHZ
	"""
	var N = qubits.size()
	if N < 2:
		push_error("Need at least 2 qubits for W state")
		return

	_clear_density_matrix()

	var amplitude = 1.0 / N  # |c|² = 1/N for each term

	# For each basis state with exactly one '1'
	for k in range(N):
		var basis_index = int(pow(2, k))  # 2^k has '1' in position k

		# Diagonal term: |basis⟩⟨basis|
		density_matrix[basis_index][basis_index] = Vector2(amplitude, 0.0)

		# Off-diagonal coherences with other single-excitation states
		for m in range(k + 1, N):
			var other_basis = int(pow(2, m))
			density_matrix[basis_index][other_basis] = Vector2(amplitude, 0.0)
			density_matrix[other_basis][basis_index] = Vector2(amplitude, 0.0)

	cluster_type = ClusterType.W_STATE

	if VerboseConfig.is_verbose("quantum"):
		print("💫 Created %d-qubit W state (robust shared excitation)" % N)


func create_cluster_state_1d():
	"""Create 1D cluster state for measurement-based quantum computing

	Construction:
	1. Initialize all qubits in |+⟩ state
	2. Apply controlled-Z between adjacent qubits

	Result: Graph state where edges represent CZ gates.
	Foundation of one-way quantum computer!
	"""
	var N = qubits.size()
	if N < 2:
		return

	# Start with all qubits in |+⟩ state
	_initialize_all_plus()

	# Apply controlled-Z between neighbors
	for i in range(N - 1):
		_apply_controlled_z(i, i + 1)

	cluster_type = ClusterType.CLUSTER

	if VerboseConfig.is_verbose("quantum"):
		print("🌐 Created %d-qubit 1D cluster state (MBQC ready)" % N)


func _initialize_all_plus():
	"""Initialize to |+⟩^⊗N state

	|+⟩ = (|0⟩+|1⟩)/√2, so |+⟩^⊗N is equal superposition of all basis states.
	"""
	_clear_density_matrix()

	var N = qubits.size()
	var dim = int(pow(2, N))
	var amplitude = 1.0 / dim

	# Equal superposition: all matrix elements equal
	for i in range(dim):
		for j in range(dim):
			density_matrix[i][j] = Vector2(amplitude, 0.0)


## Sequential Entangling Operations

func entangle_new_qubit_cnot(new_qubit, new_plot_id: String, control_index: int = 0):
	"""Add new qubit and entangle via CNOT gate

	Applies CNOT with existing qubit as control, new qubit as target.
	This extends GHZ states: |00⟩+|11⟩ → |000⟩+|111⟩

	Physics: CNOT|ψ⟩⊗|0⟩ creates entanglement between new qubit and cluster.

	Args:
		new_qubit: DualEmojiQubit to add
		new_plot_id: Plot ID
		control_index: Which existing qubit is control (default: first)
	"""
	if qubits.is_empty():
		add_qubit(new_qubit, new_plot_id)
		return

	if control_index >= qubits.size():
		push_error("Control index %d out of range (max: %d)" % [control_index, qubits.size() - 1])
		return

	# Store old state before adding qubit
	var old_density = _copy_density_matrix()
	var old_N = qubits.size()

	# Add qubit in |0⟩ state (product state)
	add_qubit(new_qubit, new_plot_id)

	# Apply CNOT to create entanglement
	_apply_cnot_expansion(old_density, old_N, control_index)

	if VerboseConfig.is_verbose("quantum"):
		print("🔗 Applied CNOT: control=%d, target=%d" % [control_index, old_N])


func _apply_cnot_expansion(old_density: Array, old_N: int, control_bit: int):
	"""Expand N-qubit state to (N+1)-qubit state via CNOT

	CNOT transformation on computational basis:
	- |x⟩|0⟩ → |x⟩|x[control]⟩

	If old state was |00⟩+|11⟩, result is |000⟩+|111⟩ (GHZ₃).

	Args:
		old_density: Density matrix before adding qubit
		old_N: Number of qubits before adding
		control_bit: Which bit is control (0-indexed)
	"""
	var old_dim = int(pow(2, old_N))
	var new_dim = int(pow(2, old_N + 1))

	# Create temporary matrix for result
	var new_density = []
	for i in range(new_dim):
		var row = []
		for j in range(new_dim):
			row.append(Vector2(0.0, 0.0))
		new_density.append(row)

	# For each basis state |x⟩ in old space
	for x in range(old_dim):
		# Extract control bit value
		var control_value = (x >> control_bit) & 1

		# New basis state: |x⟩|c⟩ where c = control bit
		# (CNOT copies control bit to target)
		var new_x = (x << 1) | control_value

		for y in range(old_dim):
			var control_y = (y >> control_bit) & 1
			var new_y = (y << 1) | control_y

			# Copy density matrix element
			new_density[new_x][new_y] = old_density[x][y]

	density_matrix = new_density


func _apply_controlled_z(control: int, target: int):
	"""Apply controlled-Z gate between two qubits in cluster

	CZ|ab⟩ = (-1)^(a·b)|ab⟩ (phase flip if both qubits are |1⟩)

	Used to create cluster states from |+⟩^⊗N.

	Args:
		control: First qubit index
		target: Second qubit index
	"""
	var N = qubits.size()
	var dim = int(pow(2, N))

	# Create temporary matrix
	var new_density = _copy_density_matrix()

	for i in range(dim):
		for j in range(dim):
			# Extract bit values
			var control_i = (i >> control) & 1
			var target_i = (i >> target) & 1
			var control_j = (j >> control) & 1
			var target_j = (j >> target) & 1

			# Phase factor: (-1)^(c·t) for bra and ket
			var phase_i = -1 if (control_i and target_i) else 1
			var phase_j = -1 if (control_j and target_j) else 1
			var total_phase = phase_i * phase_j

			# Apply phase
			var element = density_matrix[i][j]
			new_density[i][j] = Vector2(
				element.x * total_phase,
				element.y * total_phase
			)

	density_matrix = new_density


## Measurement

func measure_qubit(qubit_index: int) -> int:
	"""Measure one qubit in computational basis

	Collapses cluster state according to measurement outcome.

	For GHZ: Measuring one qubit instantly determines all others!
	For W: Measuring removes one qubit, others remain entangled.

	Args:
		qubit_index: Which qubit to measure (0-indexed)

	Returns:
		0 or 1 (measurement outcome)
	"""
	var N = qubits.size()

	if qubit_index < 0 or qubit_index >= N:
		push_error("Qubit index %d out of range" % qubit_index)
		return 0

	# Calculate probabilities
	var prob_0 = _probability_qubit_zero(qubit_index)
	var prob_1 = 1.0 - prob_0

	# Random measurement outcome
	var outcome = 0 if randf() < prob_0 else 1

	# Collapse state
	_collapse_to_outcome(qubit_index, outcome)

	if VerboseConfig.is_verbose("quantum"):
		print("📊 Measured qubit %d: %d (p₀=%.2f, p₁=%.2f)" %
		      [qubit_index, outcome, prob_0, prob_1])

	return outcome


func _probability_qubit_zero(qubit_index: int) -> float:
	"""Calculate probability of measuring |0⟩ on given qubit

	P(0) = Tr(Π₀ ρ) where Π₀ projects onto |0⟩ for this qubit.

	Computed by summing diagonal elements where qubit_index bit is 0.
	"""
	var N = qubits.size()
	var dim = int(pow(2, N))
	var prob = 0.0

	# Sum diagonal elements where qubit_index is 0
	for i in range(dim):
		var bit_value = (i >> qubit_index) & 1
		if bit_value == 0:
			prob += density_matrix[i][i].x  # Real part of diagonal

	return clamp(prob, 0.0, 1.0)


func _collapse_to_outcome(qubit_index: int, outcome: int):
	"""Collapse density matrix to measurement outcome

	Post-measurement state: Π ρ Π / Tr(Π ρ)

	where Π projects onto basis states consistent with outcome.
	"""
	var N = qubits.size()
	var dim = int(pow(2, N))

	# Zero out basis states inconsistent with outcome
	for i in range(dim):
		var bit_value = (i >> qubit_index) & 1
		if bit_value != outcome:
			# Zero this row and column
			for j in range(dim):
				density_matrix[i][j] = Vector2(0.0, 0.0)
				density_matrix[j][i] = Vector2(0.0, 0.0)

	# Renormalize (Tr(ρ) = 1)
	_normalize_density_matrix()


## Helper Methods

func _copy_density_matrix() -> Array:
	"""Deep copy of density matrix"""
	var copy = []
	for row in density_matrix:
		var row_copy = []
		for element in row:
			row_copy.append(Vector2(element.x, element.y))
		copy.append(row_copy)
	return copy


func _clear_density_matrix():
	"""Clear density matrix to all zeros"""
	for i in range(density_matrix.size()):
		for j in range(density_matrix[i].size()):
			density_matrix[i][j] = Vector2(0.0, 0.0)


func _normalize_density_matrix():
	"""Normalize density matrix: Tr(ρ) = 1"""
	var trace = 0.0
	for i in range(density_matrix.size()):
		trace += density_matrix[i][i].x

	if trace > 0.0:
		for i in range(density_matrix.size()):
			for j in range(density_matrix[i].size()):
				density_matrix[i][j] /= trace


## Properties and Queries

func get_qubit_count() -> int:
	"""Number of qubits in cluster"""
	return qubits.size()


func get_state_dimension() -> int:
	"""Hilbert space dimension: 2^N"""
	return int(pow(2, qubits.size()))


func is_ghz_type() -> bool:
	return cluster_type == ClusterType.GHZ


func is_w_type() -> bool:
	return cluster_type == ClusterType.W_STATE


func is_cluster_type() -> bool:
	return cluster_type == ClusterType.CLUSTER


func get_all_plot_ids() -> Array[String]:
	"""Get all plot IDs in cluster"""
	return qubit_ids


func contains_qubit(qubit) -> bool:
	"""Check if qubit is in this cluster"""
	return qubit in qubits


func contains_plot_id(plot_id: String) -> bool:
	"""Check if plot ID is in this cluster"""
	return plot_id in qubit_ids


func get_purity() -> float:
	"""Calculate purity: Tr(ρ²)

	Purity = 1 for pure states, < 1 for mixed states.
	"""
	var dim = density_matrix.size()
	var trace_rho_squared = 0.0

	# Compute ρ²
	for i in range(dim):
		for j in range(dim):
			var sum_real = 0.0
			var sum_imag = 0.0

			for k in range(dim):
				var a = density_matrix[i][k]
				var b = density_matrix[k][j]
				# Complex multiplication: (a.x + i·a.y)(b.x + i·b.y)
				sum_real += a.x * b.x - a.y * b.y
				sum_imag += a.x * b.y + a.y * b.x

			# Add diagonal of ρ²
			if i == j:
				trace_rho_squared += sum_real

	return clamp(trace_rho_squared, 0.0, 1.0)


func get_entanglement_entropy() -> float:
	"""Estimate entanglement entropy (simplified)

	For pure states: S = 0
	For maximally mixed: S = log₂(2^N) = N

	Returns approximate von Neumann entropy.
	"""
	var purity = get_purity()

	if purity > 0.99:
		return 0.0  # Pure state

	# Approximate: S ≈ -log₂(purity)
	return -log(purity) / log(2.0)


## Debug and Display

func get_state_string() -> String:
	"""Human-readable state description"""
	var type_names = {
		ClusterType.GHZ: "GHZ",
		ClusterType.W_STATE: "W",
		ClusterType.CLUSTER: "Cluster",
		ClusterType.CUSTOM: "Custom"
	}

	var type_name = type_names.get(cluster_type, "Unknown")
	return "%d-qubit %s state" % [qubits.size(), type_name]


func get_debug_string() -> String:
	"""Compact debug representation"""
	return "EntangledCluster[N=%d, type=%s, dim=%d×%d, purity=%.2f]" % [
		get_qubit_count(),
		get_state_string(),
		get_state_dimension(),
		get_state_dimension(),
		get_purity()
	]


func print_density_matrix():
	"""Print density matrix (only for small N!)"""
	var N = qubits.size()
	if N > 3:
		print("⚠️ Density matrix too large to print (2^%d = %d dimensions)" %
		      [N, int(pow(2, N))])
		print("   Use get_purity() or get_entanglement_entropy() instead.")
		return

	print("\nDensity Matrix (%d×%d):" % [density_matrix.size(), density_matrix.size()])
	for i in range(density_matrix.size()):
		var row_str = ""
		for j in range(density_matrix[i].size()):
			var elem = density_matrix[i][j]
			if abs(elem.y) < 0.001:  # Negligible imaginary part
				row_str += "%6.3f  " % elem.x
			else:
				row_str += "%6.3f%+.3fi  " % [elem.x, elem.y]
		print("  " + row_str)

	print("Purity: %.3f" % get_purity())
	print("Entropy: %.3f bits\n" % get_entanglement_entropy())


func print_state_info():
	"""Print comprehensive state information"""
	print("\n" + "=".repeat(60))
	print("  %s" % get_state_string().to_upper())
	print("=".repeat(60))
	print("Qubits: %d" % get_qubit_count())
	print("Dimension: %d (2^%d)" % [get_state_dimension(), get_qubit_count()])
	print("Type: %s" % get_state_string())
	print("Purity: %.3f" % get_purity())
	print("Entropy: %.3f bits" % get_entanglement_entropy())
	print("\nPlot IDs:")
	for i in range(qubit_ids.size()):
		print("  [%d] %s" % [i, qubit_ids[i]])
	print("=".repeat(60) + "\n")
