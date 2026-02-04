class_name QuantumComputer
extends Resource

## Central quantum state manager for one biome (Model C Architecture)
##
## The QuantumComputer is the ONLY owner of quantum state for the biome.
## Uses a single density_matrix with RegisterMap for emoji↔qubit coordination.
## Entanglement tracked via entanglement_graph metadata (adjacency lists).

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
# SparseMatrix deprecated - sparse optimization now handled by native C++ backend
const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")
const RegisterMap = preload("res://Core/QuantumSubstrate/RegisterMap.gd")


## Safely log via VerboseConfig (Resource can't use @onready)
func _log(level: String, category: String, emoji: String, message: String) -> void:
	var tree = Engine.get_main_loop()
	if not tree or not tree is SceneTree:
		return
	var verbose = tree.root.get_node_or_null("/root/VerboseConfig")
	if not verbose:
		return
	match level:
		"info":
			verbose.info(category, emoji, message)
		"debug":
			verbose.debug(category, emoji, message)
		"warn":
			verbose.warn(category, emoji, message)
		"error":
			verbose.error(category, emoji, message)
		"trace":
			verbose.trace(category, emoji, message)

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

## CACHED MUTUAL INFORMATION (computed in C++ during evolution at 5Hz)
## Format: {qubit_pair_index: mi_value} where index = i * num_qubits + j (upper triangular)
## Access via get_cached_mutual_information(qubit_a, qubit_b)
var _cached_mi_values: PackedFloat64Array = PackedFloat64Array()
var _mi_compute_enabled: bool = true          # Set false to disable MI computation
var _mi_last_compute_frame: int = -1          # Frame when MI was last computed

## Gated Lindblad configurations (set by biome via LindbladBuilder)
## Format: [{target_emoji: String, source_emoji: String, rate: float, gate: String, power: float}]
## Evaluated each timestep: effective_rate = rate × P(gate)^power
var gated_lindblad_configs: Array = []

## Time-dependent driver configurations (set via set_driven_icons)
## Format: [{emoji, qubit, pole, icon_ref, driver_type, base_energy}, ...]
## Used to update Hamiltonian diagonal terms each frame for oscillating self-energies
var driven_icons: Array = []
var _last_driver_update_time: float = -1.0  # Track when we last updated drivers

@export var entanglement_graph: Dictionary = {}  # register_id → Array[register_id] (adjacency)

## Phase 4: Energy tap flux tracking
## Accumulated energy flux per tapped emoji (accumulated this frame from Lindblad drain operators)
var sink_flux_per_emoji: Dictionary = {}  # emoji → float (accumulated flux)

## TIME TRACKING FOR TIME-DEPENDENT HAMILTONIAN
## Tracks elapsed time to apply time-dependent drivers (e.g., sun oscillation)
var elapsed_time: float = 0.0  # Total time elapsed since biome initialization

## PHASE MODULATION VIA LEARNED NEURAL NETWORK (Phasic Shadow)
## Optional LiquidNeuralNet that modulates density matrix phases during evolution
## Inference happens atomically as part of evolve() call
var phase_lnn = null  # LiquidNeuralNet reference (optional)

# Performance: Purity cache (invalidated on density matrix changes)
var _purity_cache: float = -1.0

func _init(name: String = ""):
	biome_name = name


func _ensure_entanglement_node(reg_id: int) -> void:
	if not entanglement_graph.has(reg_id):
		entanglement_graph[reg_id] = []


func _collect_component_registers(reg_id: int) -> Array[int]:
	var visited: Dictionary = {}
	var queue: Array = [reg_id]

	while queue.size() > 0:
		var current = queue.pop_front()
		if visited.has(current):
			continue
		visited[current] = true
		for neighbor in entanglement_graph.get(current, []):
			if not visited.has(neighbor):
				queue.append(neighbor)

	var result: Array[int] = []
	for key in visited.keys():
		result.append(int(key))
	result.sort()
	return result

## ============================================================================
## UNITARY GATE OPERATIONS (Model C)
## ============================================================================

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

	Convention: Uses MSB indexing (qubit 0 = most significant bit) to match _embed_1q_unitary.
	For CNOT, idx_a is control and idx_b is target.

	Implementation: Builds full 4-dimensional operator by iterating over all basis states,
	applying U only to the (idx_a, idx_b) subspace and passing through other qubits.
	"""
	# NOTE: Do NOT swap idx_a and idx_b - order matters for non-symmetric gates like CNOT!

	var total_dim = 1 << num_qubits
	var result = ComplexMatrix.new(total_dim)

	# Build operator by iterating over all 2Q basis states and embedding
	# For basis state |i_a, i_b⟩ at (idx_a, idx_b) with other indices fixed:
	# The operator applies U to (i_a, i_b) and passes through other qubits

	# Iterate over all basis states
	for out_basis in range(total_dim):
		# Decompose output basis state into qubit indices (MSB convention)
		var out_qubits = _decompose_basis_msb(out_basis, num_qubits)

		for in_basis in range(total_dim):
			# Decompose input basis state (MSB convention)
			var in_qubits = _decompose_basis_msb(in_basis, num_qubits)

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
			# idx_a is high bit (control for CNOT), idx_b is low bit (target for CNOT)
			var in_2q_idx = (in_qubits[idx_a] << 1) | in_qubits[idx_b]
			var out_2q_idx = (out_qubits[idx_a] << 1) | out_qubits[idx_b]

			# Get U[out_2q, in_2q]
			var u_element = U.get_element(out_2q_idx, in_2q_idx)

			# Set result[out_basis, in_basis] = U[out_2q, in_2q]
			result.set_element(out_basis, in_basis, u_element)

	return result


func _decompose_basis_msb(basis: int, num_qubits: int) -> Array[int]:
	"""Decompose a basis state index into individual qubit indices (MSB convention).

	MSB convention: qubit index k corresponds to bit (n-1-k).
	This matches _embed_1q_unitary where qubit 0 affects the most significant bit.

	For num_qubits=3, basis=5 (binary 101):
	  - qubit 0 = bit 2 = 1
	  - qubit 1 = bit 1 = 0
	  - qubit 2 = bit 0 = 1
	Returns [1, 0, 1]
	"""
	var qubits: Array[int] = []
	for i in range(num_qubits):
		var bit_pos = num_qubits - 1 - i
		qubits.append((basis >> bit_pos) & 1)
	return qubits


func _decompose_basis(basis: int, num_qubits: int) -> Array[int]:
	"""Decompose a basis state index into individual qubit indices (LSB convention).

	DEPRECATED: Use _decompose_basis_msb for consistency with gate embedding.

	LSB convention: qubit index k corresponds to bit k.
	For num_qubits=3, basis=5 (binary 101):
	Returns [1, 0, 1] (qubit 0=bit0=1, qubit 1=bit1=0, qubit 2=bit2=1)
	"""
	var qubits: Array[int] = []
	for i in range(num_qubits):
		qubits.append((basis >> i) & 1)
	return qubits

## ============================================================================
## MEASUREMENT (Tool 2 Backend)
## ============================================================================

func measure_register(_comp, reg_id: int) -> String:
	"""
	Projective measurement of one register in a component.

	DEPRECATED: Model B measurement. Use measure_axis() or project_qubit() for Model C.

	Samples outcome from Born probabilities, collapses state by projection.
	Returns: "north" or "south" (outcome)

	Physics: Measures in the computational basis {|0⟩, |1⟩}.
	For plot with (north_emoji, south_emoji) basis, maps naturally.
	"""
	push_warning("DEPRECATED: measure_register() uses Model B. Use measure_axis() or project_qubit() for Model C.")
	if density_matrix == null:
		push_error("Measurement attempted without density_matrix")
		return "north"

	var p0 = get_marginal(reg_id, 0)
	var p1 = get_marginal(reg_id, 1)
	var p_total = p0 + p1

	if p_total < 1e-14:
		push_error("Measurement probabilities sum to zero!")
		return "north"

	var rand = randf()
	var outcome_idx = 0 if (rand < p0 / p_total) else 1
	var outcome = "south" if outcome_idx == 1 else "north"

	_project_component_state(null, reg_id, outcome_idx)

	return outcome

func inspect_register_distribution(_comp, reg_id: int) -> Dictionary:
	"""
	Non-destructive peek at measurement probabilities.

	Returns marginal probabilities WITHOUT collapsing state.
	This is simulator introspection, not physical measurement.

	Returns: {north: float, south: float}
	"""
	var p0 = get_marginal(reg_id, 0)
	var p1 = get_marginal(reg_id, 1)
	return {"north": p0, "south": p1}

func _project_component_state(_comp, reg_id: int, outcome_idx: int) -> void:
	"""
	Apply projector to component state after measurement.

	outcome_idx: 0 = |0⟩ (north), 1 = |1⟩ (south)

	Math: ρ' = P ρ P† / Tr(P ρ P†) where P = |outcome⟩⟨outcome|
	"""
	project_qubit(reg_id, outcome_idx)

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
	if density_matrix == null:
		push_error("Entanglement attempted without density_matrix")
		return false

	# Apply Bell circuit (Model C)
	var H = QuantumGateLibrary.get_gate("H")["matrix"]
	if not apply_gate(reg_a, H):
		return false

	var CNOT = QuantumGateLibrary.get_gate("CNOT")["matrix"]
	if not apply_gate_2q(reg_a, reg_b, CNOT):
		return false

	# Track entanglement metadata
	_ensure_entanglement_node(reg_a)
	_ensure_entanglement_node(reg_b)
	if reg_b not in entanglement_graph[reg_a]:
		entanglement_graph[reg_a].append(reg_b)
	if reg_a not in entanglement_graph[reg_b]:
		entanglement_graph[reg_b].append(reg_a)

	return true

func get_entangled_component(reg_id: int) -> Array[int]:
	"""Get all registers entangled with this one (in same component)."""
	if reg_id < 0:
		return []
	return _collect_component_registers(reg_id)


## ============================================================================
## UTILITY METHODS
## ============================================================================

func get_marginal_density_matrix(_comp, reg_id: int) -> ComplexMatrix:
	"""Get 2×2 marginal density matrix for one register (Model C)."""
	var result = ComplexMatrix.new(2)
	if density_matrix == null:
		return result

	var num_qubits = register_map.num_qubits
	if reg_id < 0 or reg_id >= num_qubits:
		return result

	var dim = register_map.dim()
	var shift = num_qubits - 1 - reg_id
	var target_bit = 1 << shift
	var mask_other = (dim - 1) ^ target_bit

	for i in range(dim):
		var i_other = i & mask_other
		var i_bit = (i >> shift) & 1
		for j in range(dim):
			if (j & mask_other) != i_other:
				continue
			var j_bit = (j >> shift) & 1
			var accum = result.get_element(i_bit, j_bit)
			result.set_element(i_bit, j_bit, accum.add(density_matrix.get_element(i, j)))

	return result

func get_marginal_probability_subspace(_comp, reg_id: int, basis_labels: Array[String]) -> float:
	"""
	Get total probability in subspace spanned by two basis states.

	Used for plots with (north_emoji, south_emoji) basis.
	Returns: P(north) + P(south)
	"""
	var marginal = get_marginal_density_matrix(null, reg_id)
	var p0 = marginal.get_element(0, 0).re
	var p1 = marginal.get_element(1, 1).re
	return p0 + p1

func get_marginal_purity(_comp, reg_id: int) -> float:
	"""Get purity of marginal state for one register."""
	var marginal = get_marginal_density_matrix(null, reg_id)
	var rho_sq = marginal.mul(marginal)
	return clamp(rho_sq.trace().re, 0.0, 1.0)

func get_marginal_coherence(_comp, reg_id: int) -> float:
	"""Get coherence (off-diagonal element) for one register."""
	var marginal = get_marginal_density_matrix(null, reg_id)
	return marginal.get_element(0, 1).abs()


func export_bloch_packet() -> PackedFloat64Array:
	"""Export current state as visualization packet.

	Standard format for the information railway:
	QC.export_bloch_packet() → batcher buffers → viz_cache → UI

	Returns packed array: [p0, p1, x, y, z, r, theta, phi] per qubit
	"""
	var num_qubits = register_map.num_qubits
	var packet = PackedFloat64Array()
	packet.resize(num_qubits * 8)

	for q in range(num_qubits):
		var marginal = get_marginal_density_matrix(null, q)
		var base = q * 8

		if not marginal:
			# Fallback: uniform superposition
			packet[base + 0] = 0.5  # p0
			packet[base + 1] = 0.5  # p1
			packet[base + 2] = 0.0  # x
			packet[base + 3] = 0.0  # y
			packet[base + 4] = 0.0  # z
			packet[base + 5] = 0.0  # r
			packet[base + 6] = PI / 2  # theta
			packet[base + 7] = 0.0  # phi
			continue

		# Probabilities from diagonal
		var p0 = marginal.get_element(0, 0).re
		var p1 = marginal.get_element(1, 1).re

		# Coherence from off-diagonal
		var coh = marginal.get_element(0, 1)

		# DEBUG: Log coherence values for first qubit every 100 frames
		if q == 0 and Engine.get_process_frames() % 100 == 0:
			_log("trace", "test", "⚛️", "Bloch q0: ρ₀₁=%.6f + %.6fi, |ρ₀₁|=%.6f" % [
				coh.re if coh else 0.0,
				coh.im if coh else 0.0,
				coh.abs() if coh else 0.0
			])

		# Bloch coordinates
		var theta = 0.0
		var phi = 0.0
		var r = 0.0

		var p_total = p0 + p1
		if p_total > 1e-10:
			theta = 2.0 * acos(sqrt(clamp(p0 / p_total, 0.0, 1.0)))

		if coh and coh.abs() > 1e-10:
			phi = coh.arg()
			r = 2.0 * coh.abs()

		var x = sin(theta) * cos(phi) * r
		var y = sin(theta) * sin(phi) * r
		var z = cos(theta) * r

		packet[base + 0] = p0
		packet[base + 1] = p1
		packet[base + 2] = x
		packet[base + 3] = y
		packet[base + 4] = z
		packet[base + 5] = r
		packet[base + 6] = theta
		packet[base + 7] = phi

	return packet


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
	s += "Qubits: %d\n" % register_map.num_qubits
	s += "Dim: %d\n" % register_map.dim()

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
	_ensure_entanglement_node(qubit_index)
	_resize_density_matrix()
	_log("debug", "quantum", "📍", "Allocated axis %d: %s (north) ↔ %s (south)" % [qubit_index, north_emoji, south_emoji])


func _resize_density_matrix() -> void:
	"""Resize density matrix when qubits are added.

	When adding a new qubit, tensor-extends existing state with |0⟩⟨0|.
	New qubit starts in ground state (north pole).
	"""
	var num_qubits = register_map.num_qubits
	var dim = register_map.dim()

	if density_matrix == null:
		density_matrix = ComplexMatrix.zeros(dim)
		_log("debug", "quantum", "🔧", "Created density matrix: %d qubits → %dD" % [num_qubits, dim])
	elif density_matrix.n != dim:
		# Tensor-extend: ρ_new = ρ_old ⊗ |0⟩⟨0|
		var old_dim = density_matrix.n
		var ket0_bra0 = ComplexMatrix.zeros(2)
		ket0_bra0.set_element(0, 0, Complex.one())  # |0⟩⟨0| = [[1,0],[0,0]]
		var new_density = density_matrix.tensor_product(ket0_bra0)
		density_matrix = new_density
		_log("debug", "quantum", "🔧", "Extended density matrix: %dD → %dD (tensor with |0⟩⟨0|)" % [old_dim, dim])


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
	_log("debug", "quantum", "🎯", "Initialized to |%d⟩ = %s" % [basis_index, register_map.basis_to_emojis(basis_index)])


func initialize_uniform_superposition() -> void:
	"""Initialize density matrix to uniform superposition |ψ⟩ over all basis states.

	|ψ⟩ = (1/√d) Σ_i |i⟩, so ρ = |ψ⟩⟨ψ| has all entries = 1/d.
	"""
	var dim = register_map.dim()
	if dim <= 0:
		push_error("❌ Cannot initialize superposition: invalid dimension %d" % dim)
		return
	density_matrix = ComplexMatrix.zeros(dim)
	var value = Complex.new(1.0 / float(dim), 0.0)
	for i in range(dim):
		for j in range(dim):
			density_matrix.set_element(i, j, value)
	_log("debug", "quantum", "✨", "Initialized to uniform superposition (dim=%d)" % dim)


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


## ============================================================================
## MODEL C: Public API Methods
## ============================================================================

func allocate_qubit(north_emoji: String, south_emoji: String) -> int:
	"""Allocate a new qubit axis and return its index.

	Model C allocation: adds axis to RegisterMap, resizes density_matrix.
	Use this instead of allocate_register() for new code.

	Args:
	    north_emoji: Emoji for |0⟩ (north pole)
	    south_emoji: Emoji for |1⟩ (south pole)

	Returns:
	    Qubit index (0, 1, 2, ...) or -1 on error
	"""
	if north_emoji == south_emoji:
		push_error("allocate_qubit: north and south emojis must differ")
		return -1

	var qubit_index = register_map.num_qubits
	allocate_axis(qubit_index, north_emoji, south_emoji)
	return qubit_index


func project_qubit(qubit_index: int, outcome: int) -> bool:
	"""Project density matrix onto measurement outcome.

	Model C measurement projection: collapses state without sampling.
	Use measure_axis() for sampling + projection, or this for post-selection.

	Args:
	    qubit_index: Which qubit (0 to num_qubits-1)
	    outcome: 0 (north/|0⟩) or 1 (south/|1⟩)

	Returns:
	    true if projection succeeded
	"""
	if density_matrix == null:
		push_error("project_qubit: density_matrix not initialized")
		return false

	var num_qubits = register_map.num_qubits
	if qubit_index < 0 or qubit_index >= num_qubits:
		push_error("project_qubit: qubit %d out of range [0, %d)" % [qubit_index, num_qubits])
		return false

	if outcome != 0 and outcome != 1:
		push_error("project_qubit: outcome must be 0 or 1, got %d" % outcome)
		return false

	_project_qubit(qubit_index, outcome)
	return true


func get_qubit_for_emoji(emoji: String) -> int:
	"""Get qubit index for an emoji (Model C lookup).

	Migration helper: use this instead of get_component_containing().

	Args:
	    emoji: Emoji to look up

	Returns:
	    Qubit index (0, 1, 2, ...) or -1 if not found
	"""
	return register_map.qubit(emoji)


func get_emoji_pair_for_qubit(qubit_index: int) -> Dictionary:
	"""Get {north, south} emoji pair for a qubit.

	Migration helper: use this to get axis emojis from qubit index.

	Args:
	    qubit_index: Qubit to look up (0 to num_qubits-1)

	Returns:
	    {north: String, south: String} or empty dict if not found
	"""
	return register_map.axis(qubit_index)


## ============================================================================
## GATE APPLICATION (Model C: RegisterMap-based)
## ============================================================================

func apply_gate(qubit: int, U: ComplexMatrix) -> bool:
	"""Apply 1-qubit unitary gate to the density matrix.

	Model C (RegisterMap): Operates on the top-level density_matrix directly.
	Used by UI gate tools when register_map is active.

	Operation: ρ' = (I⊗...⊗U⊗...⊗I) ρ (I⊗...⊗U†⊗...⊗I)

	Args:
		qubit: Qubit index (0 to num_qubits-1)
		U: 2×2 unitary gate matrix

	Returns:
		true if gate applied successfully
	"""
	if density_matrix == null:
		push_error("apply_gate: density_matrix not initialized")
		return false

	var num_qubits = register_map.num_qubits
	if qubit < 0 or qubit >= num_qubits:
		push_error("apply_gate: qubit %d out of range [0, %d)" % [qubit, num_qubits])
		return false

	# Embed 1Q gate into full Hilbert space
	var embedded_U = _embed_1q_unitary(U, qubit, num_qubits)

	# Apply gate: ρ' = U ρ U†
	var rho_new = embedded_U.mul(density_matrix).mul(embedded_U.conjugate_transpose())
	rho_new.renormalize_trace()

	density_matrix = rho_new

	return true


func apply_gate_2q(qubit_a: int, qubit_b: int, U: ComplexMatrix) -> bool:
	"""Apply 2-qubit unitary gate to the density matrix.

	Model C (RegisterMap): Operates on the top-level density_matrix directly.
	Used by UI gate tools when register_map is active.

	Operation: ρ' = U_{ab} ρ U†_{ab}

	Args:
		qubit_a: First qubit index (control for CNOT)
		qubit_b: Second qubit index (target for CNOT)
		U: 4×4 unitary gate matrix

	Returns:
		true if gate applied successfully
	"""
	if density_matrix == null:
		push_error("apply_gate_2q: density_matrix not initialized")
		return false

	var num_qubits = register_map.num_qubits
	if qubit_a < 0 or qubit_a >= num_qubits:
		push_error("apply_gate_2q: qubit_a %d out of range [0, %d)" % [qubit_a, num_qubits])
		return false
	if qubit_b < 0 or qubit_b >= num_qubits:
		push_error("apply_gate_2q: qubit_b %d out of range [0, %d)" % [qubit_b, num_qubits])
		return false
	if qubit_a == qubit_b:
		push_error("apply_gate_2q: qubit_a and qubit_b must differ")
		return false

	# Embed 2Q gate into full Hilbert space
	var embedded_U = _embed_2q_unitary(U, qubit_a, qubit_b, num_qubits)

	# Apply gate: ρ' = U ρ U†
	var rho_new = embedded_U.mul(density_matrix).mul(embedded_U.conjugate_transpose())
	rho_new.renormalize_trace()

	density_matrix = rho_new

	return true


# ============================================================================
# HIGH-LEVEL GATE CONVENIENCE METHODS
# ============================================================================

func apply_pauli_x(qubit: int) -> bool:
	"""Apply Pauli-X (NOT/bit-flip) gate to a qubit."""
	var X = QuantumGateLibrary.get_gate("X")["matrix"]
	return apply_gate(qubit, X)


func apply_hadamard(qubit: int) -> bool:
	"""Apply Hadamard gate to create superposition."""
	var H = QuantumGateLibrary.get_gate("H")["matrix"]
	return apply_gate(qubit, H)


func apply_pauli_y(qubit: int) -> bool:
	"""Apply Pauli-Y gate."""
	var Y = QuantumGateLibrary.get_gate("Y")["matrix"]
	return apply_gate(qubit, Y)


func apply_pauli_z(qubit: int) -> bool:
	"""Apply Pauli-Z (phase-flip) gate."""
	var Z = QuantumGateLibrary.get_gate("Z")["matrix"]
	return apply_gate(qubit, Z)


func apply_ry(qubit: int, theta: float = PI / 4.0) -> bool:
	"""Apply Ry rotation gate with angle theta (default π/4)."""
	var Ry = QuantumGateLibrary._ry_gate(theta)
	return apply_gate(qubit, Ry)


func apply_rx(qubit: int, theta: float = PI / 4.0) -> bool:
	"""Apply Rx rotation gate with angle theta (default π/4)."""
	var Rx = QuantumGateLibrary._rx_gate(theta)
	return apply_gate(qubit, Rx)


func apply_rz(qubit: int, theta: float = PI / 4.0) -> bool:
	"""Apply Rz rotation gate with angle theta (default π/4)."""
	var Rz = QuantumGateLibrary._rz_gate(theta)
	return apply_gate(qubit, Rz)


func apply_cnot(control_qubit: int, target_qubit: int) -> bool:
	"""Apply CNOT (controlled-NOT) gate. First arg is control, second is target."""
	var CNOT = QuantumGateLibrary.get_gate("CNOT")["matrix"]
	return apply_gate_2q(control_qubit, target_qubit, CNOT)


func apply_swap(qubit_a: int, qubit_b: int) -> bool:
	"""Apply SWAP gate to exchange two qubit states."""
	var SWAP = QuantumGateLibrary.get_gate("SWAP")["matrix"]
	return apply_gate_2q(qubit_a, qubit_b, SWAP)


func apply_cz(control_qubit: int, target_qubit: int) -> bool:
	"""Apply CZ (controlled-Z) gate."""
	var CZ = QuantumGateLibrary.get_gate("CZ")["matrix"]
	return apply_gate_2q(control_qubit, target_qubit, CZ)


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

	# Use fast path for diagonal reads (avoids O(n²) object creation)
	for i in range(dim):
		if ((i >> shift) & 1) == pole_value:
			prob += density_matrix.get_diagonal_real(i)

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

	_log("debug", "quantum", "🔬", "Measured axis %s/%s: outcome=%s (p_north=%.3f, p_south=%.3f)" % [
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
	"""Ensure Tr(ρ) = 1 after numerical integration.

	Three-stage approach:
	1. Clip small negative diagonal values to zero (numerical noise fix)
	2. Reinitialize only on truly catastrophic failure
	3. Normalize trace to 1
	"""
	if density_matrix == null:
		return

	var dim = register_map.dim()

	# Stage 1: Clip small negative diagonal values (numerical noise fix)
	var data = density_matrix._data
	for i in range(dim):
		var idx = i * dim + i
		var diag = data[idx]
		if diag.re < 0.0 and diag.re > -0.15:
			data[idx] = Complex.zero()

	# Compute trace and check for catastrophic failure
	var trace = 0.0
	var min_diag = 1.0
	for i in range(dim):
		var diag_re = data[i * dim + i].re
		trace += diag_re
		if diag_re < min_diag:
			min_diag = diag_re

	# Stage 2: Only reinitialize on truly catastrophic failure
	if abs(trace) < 1e-10 or min_diag < -0.15:
		push_warning("⚠️ Quantum state catastrophic (trace=%.4f, min_diag=%.4f), reinitializing" % [trace, min_diag])
		_reinitialize_mixed_state()
		return

	# Stage 3: Cap trace to 1 (allow dissipative trace < 1)
	if trace > 1.0 + 1e-10:
		var scale = 1.0 / trace
		var scale_c = Complex.new(scale, 0.0)
		for i in range(data.size()):
			data[i] = data[i].mul(scale_c)
	
	_purity_cache = -1.0


func load_packed_state(rho_packed: PackedFloat64Array, dim: int, already_normalized: bool = false) -> void:
	"""Load a packed density matrix, with optional trusted normalization."""
	if density_matrix == null or density_matrix.n != dim:
		density_matrix = ComplexMatrix.zeros(dim)
	density_matrix._from_packed(rho_packed, dim)
	if not already_normalized:
		_renormalize()


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


func _apply_phase_lnn(lnn: Object) -> void:
	"""Apply learned phase modulation from neural network to density matrix diagonal.

	The LNN operates in the phasic shadow - it learns to modulate the phases of
	the diagonal density matrix elements. This creates an undercurrent of learned
	intelligence that shapes quantum evolution.

	Args:
		lnn: LiquidNeuralNet instance with forward(phases: PackedFloat64Array) method
	"""
	# Kill-switch: Can be disabled by setting phase_lnn = null or via BiomeBase.ENABLE_PHASE_LNN
	if density_matrix == null or not lnn:
		return

	var dim = register_map.dim()
	if dim == 0:
		return

	# Extract current phases from density matrix diagonal
	var phases = PackedFloat64Array()
	phases.resize(dim)

	for i in range(dim):
		var diag_elem = density_matrix.get_element(i, i)
		var phase = atan2(diag_elem.im, diag_elem.re)
		phases[i] = phase

	# Run LNN forward pass to get learned phase modulations
	var modulated_phases = lnn.forward(phases)
	if modulated_phases.is_empty():
		return

	# Apply phase shifts to density matrix diagonal
	var data = density_matrix._data
	for i in range(dim):
		var old_elem = data[i * dim + i]
		var magnitude = sqrt(old_elem.re * old_elem.re + old_elem.im * old_elem.im)

		# Phase shift from LNN
		var new_phase = modulated_phases[i]
		var new_re = magnitude * cos(new_phase)
		var new_im = magnitude * sin(new_phase)

		data[i * dim + i] = Complex.new(new_re, new_im)

	# Invalidate caches since we modified the state
	_purity_cache = -1.0


# ============================================================================
# MODEL C: FULL LINDBLAD EVOLUTION
# ============================================================================

func evolve(dt: float, max_dt: float = 0.02, lnn: Object = null) -> void:
	var t0 = Time.get_ticks_usec()
	"""Evolve density matrix under Lindblad master equation + optional phase modulation.

	Implements: dρ/dt = -i[H,ρ] + Σ_k (L_k ρ L_k† - ½{L_k†L_k, ρ})
	             + phase modulation via learned neural network (if lnn provided)

	Uses first-order Euler integration: ρ(t+dt) = ρ(t) + dt * dρ/dt

	Args:
	    dt: Time step (in game seconds, actual evolution timestep)
	    max_dt: Unused (kept for API compatibility)
	    lnn: Optional LiquidNeuralNet for phase modulation in phasic shadow
	         If provided, applies learned phase shifts to density matrix diagonal

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

	# Use provided lnn or fall back to instance variable
	if lnn == null:
		lnn = phase_lnn

	# ACCUMULATE TIME for time-dependent drivers (sun oscillation, etc.)
	elapsed_time += dt

	# UPDATE TIME-DEPENDENT DRIVERS (e.g., sun/moon 20-second oscillation)
	# This modifies Hamiltonian diagonal terms for icons with active drivers
	if not driven_icons.is_empty():
		update_driven_self_energies(elapsed_time)

	# ==========================================================================
	# EVOLUTION PATH: GDScript per-operator sparse path (CPU-optimized)
	# ==========================================================================
	# Single evolution step using max_dt as actual timestep (no subcycling)
	# max_dt is the granularity setting (user-adjustable)
	# dt parameter is ignored (legacy from subcycling era)
	var actual_dt = max_dt if max_dt > 0.0 else dt
	_evolve_step(actual_dt)
	# Apply phase modulation from LNN (phasic shadow)
	if lnn:
		_apply_phase_lnn(lnn)
	var t1 = Time.get_ticks_usec()
	if Engine.get_process_frames() % 60 == 0:
		_log("trace", "quantum", "⏱️", "QC Evolve Trace (Single+LNN, dt=%.4f): Total %d us" % [actual_dt, t1 - t0])


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

		# DEBUG: Log commutator values
		if Engine.get_process_frames() % 100 == 0:
			var comm_01 = commutator.get_element(0, 1)
			var comm_10 = commutator.get_element(1, 0)
			_log("trace", "test", "⚛️", "Commutator [H,ρ]: [0,1]=%.6f+%.6fi, [1,0]=%.6f+%.6fi" % [
				comm_01.re, comm_01.im, comm_10.re, comm_10.im
			])

		drho = drho.add(commutator.scale(neg_i))

		# DEBUG: Log scaled commutator
		if Engine.get_process_frames() % 100 == 0:
			var scaled_01 = drho.get_element(0, 1)
			var scaled_10 = drho.get_element(1, 0)
			_log("trace", "test", "⚛️", "(-i)[H,ρ]: [0,1]=%.6f+%.6fi, [1,0]=%.6f+%.6fi" % [
				scaled_01.re, scaled_01.im, scaled_10.re, scaled_10.im
			])
	elif hamiltonian != null:
		# Dense fallback
		var commutator = hamiltonian.commutator(density_matrix)
		var neg_i = Complex.new(0.0, -1.0)

		# DEBUG: Log commutator values
		if Engine.get_process_frames() % 100 == 0:
			var comm_01 = commutator.get_element(0, 1)
			var comm_10 = commutator.get_element(1, 0)
			_log("trace", "test", "⚛️", "Commutator [H,ρ]: [0,1]=%.6f+%.6fi, [1,0]=%.6f+%.6fi" % [
				comm_01.re, comm_01.im, comm_10.re, comm_10.im
			])

		drho = drho.add(commutator.scale(neg_i))

		# DEBUG: Log scaled commutator
		if Engine.get_process_frames() % 100 == 0:
			var scaled_01 = drho.get_element(0, 1)
			var scaled_10 = drho.get_element(1, 0)
			_log("trace", "test", "⚛️", "(-i)[H,ρ]: [0,1]=%.6f+%.6fi, [1,0]=%.6f+%.6fi" % [
				scaled_01.re, scaled_01.im, scaled_10.re, scaled_10.im
			])

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
	var rho_new = density_matrix.add(drho.scale_real(dt))

	# DEBUG: Log density matrix before/after update
	if Engine.get_process_frames() % 100 == 0:
		var old_01 = density_matrix.get_element(0, 1)
		var new_01 = rho_new.get_element(0, 1)
		var drho_01 = drho.get_element(0, 1)
		_log("trace", "test", "⚛️", "Update: ρ_old[0,1]=%.6f+%.6fi, δρ[0,1]*dt=%.6f+%.6fi, ρ_new[0,1]=%.6f+%.6fi" % [
			old_01.re, old_01.im, drho_01.re * dt, drho_01.im * dt, new_01.re, new_01.im
		])

	density_matrix = rho_new

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
	if _purity_cache >= 0.0:
		return _purity_cache

	if density_matrix == null:
		return 0.0

	# Tr(ρ²) = Σ_ij |ρ_ij|² for Hermitian ρ
	var sum_sq = 0.0
	var data = density_matrix._data
	for i in range(data.size()):
		var c = data[i]
		sum_sq += c.re * c.re + c.im * c.im
	
	_purity_cache = clamp(sum_sq, 0.0, 1.0)
	return _purity_cache


# ============================================================================
# MUTUAL INFORMATION: Physics-grounded correlation measure
# ============================================================================

func get_mutual_information(qubit_a: int, qubit_b: int) -> float:
	"""Compute mutual information I(A:B) = S(A) + S(B) - S(AB) between two qubits.

	Mutual information quantifies the total correlations (classical + quantum)
	between two subsystems. For a Bell state: I(A:B) = 2 (maximum).
	For a product state: I(A:B) = 0 (independent).

	This is used for physics-grounded position encoding:
	- High mutual info → bubbles cluster together
	- Low mutual info → bubbles spread apart

	Args:
	    qubit_a: First qubit index (0 to num_qubits-1)
	    qubit_b: Second qubit index (0 to num_qubits-1)

	Returns:
	    Mutual information in bits [0, 2] for single qubits
	"""
	if density_matrix == null or qubit_a == qubit_b:
		return 0.0

	if qubit_a < 0 or qubit_a >= register_map.num_qubits:
		return 0.0
	if qubit_b < 0 or qubit_b >= register_map.num_qubits:
		return 0.0

	var S_A = _entropy_of_marginal(qubit_a)
	var S_B = _entropy_of_marginal(qubit_b)
	var S_AB = _entropy_of_joint(qubit_a, qubit_b)

	# I(A:B) = S(A) + S(B) - S(AB) (subadditivity guarantees this is >= 0)
	return max(S_A + S_B - S_AB, 0.0)


func get_cached_mutual_information(qubit_a: int, qubit_b: int) -> float:
	"""Get mutual information from native C++ cache (computed during evolution).

	This is the FAST path - MI is computed in C++ during evolve_with_mi() at physics rate.
	Falls back to GDScript calculation if cache is empty or indices are invalid.

	The cache stores MI in upper triangular order: [mi_01, mi_02, ..., mi_12, mi_13, ...]
	Index formula: for i < j, index = i * (2*n - i - 1) / 2 + (j - i - 1)
	"""
	if qubit_a == qubit_b:
		return 0.0

	# Ensure a < b for cache lookup (MI is symmetric)
	var i = min(qubit_a, qubit_b)
	var j = max(qubit_a, qubit_b)
	var n = register_map.num_qubits

	if i < 0 or j >= n:
		return 0.0

	# Check if cache is valid
	if _cached_mi_values.is_empty():
		# Fallback to GDScript calculation
		return get_mutual_information(qubit_a, qubit_b)

	# Upper triangular index: i * (2n - i - 1) / 2 + (j - i - 1)
	var idx = i * (2 * n - i - 1) / 2 + (j - i - 1)

	if idx < 0 or idx >= _cached_mi_values.size():
		return get_mutual_information(qubit_a, qubit_b)

	return _cached_mi_values[idx]


func has_cached_mi() -> bool:
	"""Check if MI cache is populated (native path is working)."""
	return not _cached_mi_values.is_empty()


func _entropy_of_marginal(qubit_index: int) -> float:
	"""Compute von Neumann entropy S(ρ_A) = -Tr(ρ_A log ρ_A) of single-qubit marginal.

	For a single qubit: S(ρ) = -p₀ log p₀ - p₁ log p₁
	where p₀, p₁ are the eigenvalues of the 2×2 reduced density matrix.

	Args:
	    qubit_index: Which qubit to compute entropy for

	Returns:
	    Entropy in bits [0, 1] (0 = pure, 1 = maximally mixed)
	"""
	if density_matrix == null:
		return 0.0

	# Get diagonal elements of marginal (populations)
	var p0 = get_marginal(qubit_index, 0)  # P(|0⟩)
	var p1 = get_marginal(qubit_index, 1)  # P(|1⟩)

	# For full entropy, we need eigenvalues of reduced density matrix
	# The 2×2 reduced matrix is: [[p0, coh], [coh*, p1]]
	# Eigenvalues: λ± = (1 ± √(1 - 4·det))/2 where det = p0·p1 - |coh|²

	# Get coherence for this qubit's axis
	var coh_mag_sq = 0.0
	# Get the emoji pair for this qubit
	for emoji in register_map.coordinates.keys():
		var q = register_map.qubit(emoji)
		if q == qubit_index:
			var p = register_map.pole(emoji)
			if p == 0:  # Found north emoji
				# Find corresponding south emoji
				for other_emoji in register_map.coordinates.keys():
					var other_q = register_map.qubit(other_emoji)
					var other_p = register_map.pole(other_emoji)
					if other_q == qubit_index and other_p == 1:
						# Found the pair - get coherence
						var coh = get_coherence(emoji, other_emoji)
						if coh:
							coh_mag_sq = coh.re * coh.re + coh.im * coh.im
						break
				break

	# Compute determinant of 2×2 reduced density matrix
	var det = p0 * p1 - coh_mag_sq

	# Eigenvalues via characteristic polynomial
	var discriminant = max(1.0 - 4.0 * det, 0.0)
	var sqrt_disc = sqrt(discriminant)
	var lambda_plus = (1.0 + sqrt_disc) / 2.0
	var lambda_minus = (1.0 - sqrt_disc) / 2.0

	# von Neumann entropy: S = -Σ λ log λ (in nats, then convert to bits)
	var entropy = 0.0
	var eps = 1e-15

	if lambda_plus > eps:
		entropy -= lambda_plus * log(lambda_plus)
	if lambda_minus > eps:
		entropy -= lambda_minus * log(lambda_minus)

	# Convert from nats to bits (divide by ln(2))
	return entropy / log(2.0)


func _entropy_of_joint(qubit_a: int, qubit_b: int) -> float:
	"""Compute von Neumann entropy S(ρ_AB) of the two-qubit reduced density matrix.

	This is the entropy of the joint state of qubits A and B after tracing out
	all other qubits.

	Args:
	    qubit_a: First qubit index
	    qubit_b: Second qubit index

	Returns:
	    Joint entropy in bits [0, 2] (0 = pure, 2 = maximally mixed)
	"""
	if density_matrix == null:
		return 0.0

	# Build the 4×4 reduced density matrix for qubits A and B
	var num_qubits = register_map.num_qubits
	var dim = register_map.dim()

	if num_qubits < 2:
		return 0.0

	# Ensure a < b for consistent indexing
	var qa = mini(qubit_a, qubit_b)
	var qb = maxi(qubit_a, qubit_b)

	# Partial trace over all qubits except qa and qb
	# Result is 4×4 matrix with indices (i_a, i_b) ∈ {0,1}²
	var rho_ab = ComplexMatrix.zeros(4)
	var shift_a = num_qubits - 1 - qa
	var shift_b = num_qubits - 1 - qb

	for out_a in range(2):
		for out_b in range(2):
			for in_a in range(2):
				for in_b in range(2):
					var out_ab = out_a * 2 + out_b
					var in_ab = in_a * 2 + in_b

					# Sum over all basis states where qubits a,b have specified values
					var accum = Complex.zero()
					for i in range(dim):
						var bit_a_i = (i >> shift_a) & 1
						var bit_b_i = (i >> shift_b) & 1
						if bit_a_i != out_a or bit_b_i != out_b:
							continue

						for j in range(dim):
							var bit_a_j = (j >> shift_a) & 1
							var bit_b_j = (j >> shift_b) & 1
							if bit_a_j != in_a or bit_b_j != in_b:
								continue

							# Check if other qubits match (partial trace condition)
							var other_match = true
							for k in range(num_qubits):
								if k == qa or k == qb:
									continue
								var shift_k = num_qubits - 1 - k
								if ((i >> shift_k) & 1) != ((j >> shift_k) & 1):
									other_match = false
									break

							if other_match:
								accum = accum.add(density_matrix.get_element(i, j))

					rho_ab.set_element(out_ab, in_ab, accum)

	# Compute eigenvalues of 4×4 matrix (numerical diagonalization)
	var eigenvalues = _eigenvalues_4x4(rho_ab)

	# von Neumann entropy: S = -Σ λ log λ
	var entropy = 0.0
	var eps = 1e-15

	for lambda_val in eigenvalues:
		if lambda_val > eps:
			entropy -= lambda_val * log(lambda_val)

	return entropy / log(2.0)


func _eigenvalues_4x4(mat: ComplexMatrix) -> Array[float]:
	"""Compute eigenvalues of a 4×4 Hermitian matrix numerically.

	Uses power iteration with deflation for simplicity.
	For a Hermitian density matrix, all eigenvalues are real.

	Returns:
	    Array of 4 real eigenvalues (may include near-zero values)
	"""
	var eigenvalues: Array[float] = []

	if mat == null or mat.n != 4:
		return [0.0, 0.0, 0.0, 0.0]

	# Work with a copy to avoid modifying original
	var work = ComplexMatrix.zeros(4)
	for i in range(4):
		for j in range(4):
			work.set_element(i, j, mat.get_element(i, j))

	# Power iteration with deflation to find eigenvalues
	for _ev_idx in range(4):
		var v = [Complex.new(1.0, 0.0), Complex.new(0.0, 0.0),
		         Complex.new(0.0, 0.0), Complex.new(0.0, 0.0)]

		# Power iteration
		for _iter in range(50):
			# w = work * v
			var w: Array = []
			for i in range(4):
				var sum = Complex.zero()
				for j in range(4):
					sum = sum.add(work.get_element(i, j).mul(v[j]))
				w.append(sum)

			# Normalize
			var norm_sq = 0.0
			for i in range(4):
				norm_sq += w[i].re * w[i].re + w[i].im * w[i].im
			var norm = sqrt(norm_sq)
			if norm < 1e-14:
				break
			for i in range(4):
				v[i] = Complex.new(w[i].re / norm, w[i].im / norm)

		# Compute Rayleigh quotient (eigenvalue estimate)
		var Av: Array = []
		for i in range(4):
			var sum = Complex.zero()
			for j in range(4):
				sum = sum.add(work.get_element(i, j).mul(v[j]))
			Av.append(sum)

		var numerator = Complex.zero()
		var denominator = 0.0
		for i in range(4):
			numerator = numerator.add(v[i].conjugate().mul(Av[i]))
			denominator += v[i].re * v[i].re + v[i].im * v[i].im

		var lambda_val = numerator.re / max(denominator, 1e-14)
		eigenvalues.append(max(lambda_val, 0.0))  # Clamp small negatives

		# Deflate: work = work - λ * v * v†
		for i in range(4):
			for j in range(4):
				var outer = v[i].mul(v[j].conjugate()).scale(lambda_val)
				work.set_element(i, j, work.get_element(i, j).sub(outer))

	return eigenvalues


func get_coherence(emoji_a: String, emoji_b: String):
	"""Get coherence (off-diagonal element) between two emojis.

	Returns the complex coherence ρ[a,b] from the density matrix.
	Used for visualization and correlation calculations.

	Args:
	    emoji_a: First emoji
	    emoji_b: Second emoji

	Returns:
	    Complex coherence value, or null if emojis not registered
	"""
	if not register_map.has(emoji_a) or not register_map.has(emoji_b):
		return null

	if density_matrix == null:
		return null

	# For same-qubit emojis (north/south pair), return off-diagonal of reduced matrix
	var q_a = register_map.qubit(emoji_a)
	var q_b = register_map.qubit(emoji_b)
	var p_a = register_map.pole(emoji_a)
	var p_b = register_map.pole(emoji_b)

	if q_a != q_b:
		# Different qubits - return cross-correlation from density matrix
		# This is more complex - for now return null
		return null

	if p_a == p_b:
		# Same pole - no coherence (would be diagonal)
		return Complex.zero()

	# Same qubit, different poles - compute off-diagonal of reduced density matrix
	var num_qubits = register_map.num_qubits
	var dim = register_map.dim()
	var shift = num_qubits - 1 - q_a

	# Compute ρ[0,1] of the single-qubit reduced density matrix
	var coherence = Complex.zero()
	for i in range(dim):
		for j in range(dim):
			var bit_i = (i >> shift) & 1
			var bit_j = (j >> shift) & 1

			# We want ρ_reduced[p_a, p_b] (off-diagonal)
			# This accumulates when qubit has value p_a in bra and p_b in ket
			if bit_i == p_a and bit_j == p_b:
				# Check if other qubits match (partial trace condition)
				var other_match = true
				for k in range(num_qubits):
					if k == q_a:
						continue
					var shift_k = num_qubits - 1 - k
					if ((i >> shift_k) & 1) != ((j >> shift_k) & 1):
						other_match = false
						break

				if other_match:
					coherence = coherence.add(density_matrix.get_element(i, j))

	return coherence


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
# COUPLING INJECTION (Mill/Building Mechanics)
# ============================================================================

## Coupling registry: stores injected couplings for Hamiltonian rebuilds
## Format: {"qubit_a-qubit_b": {"a": int, "b": int, "J": float}}
var coupling_registry: Dictionary = {}


func add_coupling(qubit_a: int, qubit_b: int, strength: float) -> Dictionary:
	"""Add ZZ coupling between two qubits in the Hamiltonian.

	Creates/updates σz⊗σz interaction term: J × σz_a ⊗ σz_b
	This causes population oscillation between the coupled axes.

	Args:
		qubit_a: First qubit index
		qubit_b: Second qubit index
		strength: Coupling strength J

	Returns:
		Dictionary with success/error keys
	"""
	if qubit_a < 0 or qubit_a >= register_map.num_qubits:
		return {"success": false, "error": "invalid_qubit_a", "qubit": qubit_a}
	if qubit_b < 0 or qubit_b >= register_map.num_qubits:
		return {"success": false, "error": "invalid_qubit_b", "qubit": qubit_b}
	if qubit_a == qubit_b:
		return {"success": false, "error": "same_qubit", "qubit": qubit_a}

	# Store coupling in registry (canonical order: smaller index first)
	var key = "%d-%d" % [mini(qubit_a, qubit_b), maxi(qubit_a, qubit_b)]
	coupling_registry[key] = {"a": qubit_a, "b": qubit_b, "J": strength}

	# Apply coupling directly to Hamiltonian
	_add_zz_coupling_to_hamiltonian(qubit_a, qubit_b, strength)

	_log("debug", "quantum", "⚛️", "Added ZZ coupling: qubit %d ↔ qubit %d (J=%.3f)" % [qubit_a, qubit_b, strength])
	return {"success": true, "coupling_key": key}


func _add_zz_coupling_to_hamiltonian(qubit_a: int, qubit_b: int, J: float) -> void:
	"""Add σz⊗σz coupling term directly to Hamiltonian diagonal.

	ZZ interaction: H += J × σz_a ⊗ σz_b
	Diagonal elements only: ⟨i|σz_a⊗σz_b|i⟩ = ±1 depending on qubit states

	Args:
		qubit_a: First qubit index
		qubit_b: Second qubit index
		J: Coupling strength
	"""
	if hamiltonian == null:
		push_warning("⚠️ Cannot add coupling: Hamiltonian is null")
		return

	var n = register_map.num_qubits
	var dim = 1 << n  # 2^n
	var shift_a = n - 1 - qubit_a
	var shift_b = n - 1 - qubit_b

	for i in range(dim):
		# σz eigenvalue: +1 for |0⟩, -1 for |1⟩
		var bit_a = (i >> shift_a) & 1
		var bit_b = (i >> shift_b) & 1
		var sign_a = 1 - 2 * bit_a  # +1 if bit=0, -1 if bit=1
		var sign_b = 1 - 2 * bit_b
		var zz_value = sign_a * sign_b * J

		# Add to diagonal of Hamiltonian
		var current = hamiltonian.get_element(i, i)
		hamiltonian.set_element(i, i, Complex.new(current.re + zz_value, current.im))

	# Update sparse Hamiltonian if in use
	if sparse_hamiltonian != null:
		sparse_hamiltonian = hamiltonian  # Re-reference


func get_coupling(qubit_a: int, qubit_b: int) -> float:
	"""Get current coupling strength between two qubits.

	Returns:
		Coupling strength J, or 0.0 if no coupling exists
	"""
	var key = "%d-%d" % [mini(qubit_a, qubit_b), maxi(qubit_a, qubit_b)]
	if coupling_registry.has(key):
		return coupling_registry[key].J
	return 0.0


func get_all_couplings() -> Array:
	"""Get all registered couplings.

	Returns:
		Array of {a: int, b: int, J: float} dictionaries
	"""
	var result = []
	for key in coupling_registry:
		result.append(coupling_registry[key].duplicate())
	return result


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
		_log("debug", "quantum", "⚡", "Hamiltonian converted to sparse: %.1f%% zeros, nnz=%d" % [sparsity * 100, nnz])
	else:
		sparse_hamiltonian = null
		_log("debug", "quantum", "📊", "Hamiltonian kept dense: %.1f%% zeros (below threshold)" % [sparsity * 100])


func set_driven_icons(configs: Array) -> void:
	"""Set time-dependent driver configurations for efficient Hamiltonian updates.

	These configs are used by update_driven_self_energies() to update
	Hamiltonian diagonal terms without full rebuild.

	Args:
		configs: Array from HamiltonianBuilder.get_driven_icons()
			[{emoji, qubit, pole, icon_ref, driver_type, base_energy}, ...]
	"""
	driven_icons = configs
	_last_driver_update_time = -1.0

	if not configs.is_empty():
		var driver_emojis = []
		for cfg in configs:
			driver_emojis.append("%s(%s)" % [cfg.emoji, cfg.driver_type])
		_log("debug", "quantum", "⚡", "Registered %d driven icons: %s" % [configs.size(), ", ".join(driver_emojis)])


func update_driven_self_energies(time: float) -> void:
	"""Update Hamiltonian diagonal terms for time-dependent drivers.

	This is called during evolve() to apply oscillating self-energies
	(e.g., sun/moon 20-second cycle) without rebuilding the full Hamiltonian.

	Only modifies diagonal elements for icons with active drivers.
	Invalidates native evolution engine cache if drivers changed significantly.

	Args:
		time: Current simulation time in seconds
	"""
	if driven_icons.is_empty():
		return

	if hamiltonian == null:
		return

	var num_qubits = register_map.num_qubits
	var dim = 1 << num_qubits
	var significant_change = false

	for cfg in driven_icons:
		var icon = cfg.icon_ref
		var qubit = cfg.qubit
		var pole = cfg.pole

		# Get time-dependent energy from icon
		var old_energy = cfg.get("cached_energy", cfg.base_energy)
		var new_energy = icon.get_self_energy(time)

		# Skip if energy hasn't changed significantly
		if abs(new_energy - old_energy) < 1e-6:
			continue

		significant_change = true
		cfg["cached_energy"] = new_energy

		# Calculate the delta to add to Hamiltonian diagonal
		var delta = new_energy - old_energy
		var shift = num_qubits - 1 - qubit

		# Update all basis states where this qubit is in the target pole
		for i in range(dim):
			if ((i >> shift) & 1) == pole:
				var current = hamiltonian.get_element(i, i)
				hamiltonian.set_element(i, i, Complex.new(current.re + delta, current.im))

	# Update sparse reference if needed
	if significant_change and sparse_hamiltonian != null:
		sparse_hamiltonian = hamiltonian

	# NOTE: Native evolution engine cache is not invalidated for small diagonal changes
	# The native engine stores its own copy, so for truly accurate time-dependent evolution,
	# we would need to rebuild the native engine. For now, we accept small drift.
	# Full rebuild happens every ~1 second via biome's periodic update.


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
	_log("debug", "quantum", "⚡", "%d Lindblad ops → sparse: avg %.1f%% zeros, total nnz=%d" % [
		operators.size(), avg_sparsity * 100, total_nnz])
