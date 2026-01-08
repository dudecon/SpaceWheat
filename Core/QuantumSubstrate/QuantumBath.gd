class_name QuantumBath
extends RefCounted

## QuantumBath: The quantum state of a biome

## Import QuantumRigorConfig for mode system
const QuantumRigorConfig = preload("res://Core/GameState/QuantumRigorConfig.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const DensityMatrix = preload("res://Core/QuantumSubstrate/DensityMatrix.gd")
##
## REFACTORED: Now uses proper density matrix formalism internally.
## The bath is REALITY. Plots merely PROJECT from it.
##
## Key changes from legacy version:
## - Internal state is DensityMatrix (not amplitude array)
## - Evolution via Hamiltonian + Lindblad superoperator (proper master equation)
## - "amplitudes" property maintained for backwards compatibility
## - All observables computed from density matrix

## ========================================
## Signals
## ========================================

signal bath_evolved()
signal bath_measured(north: String, south: String, outcome: String)

## ========================================
## Core Quantum State (NEW: Density Matrix)
## ========================================

## The source of truth: density matrix ρ
var _density_matrix  # DensityMatrix (no type hint - class_name removed)

## Operators
var _hamiltonian  # Hamiltonian (no type hint - class_name removed)
var _lindblad  # LindbladSuperoperator (no type hint - class_name removed)
var _evolver  # QuantumEvolver (no type hint - class_name removed)

## ========================================
## Backwards Compatibility Layer
## ========================================

## Legacy: amplitude array (computed from density matrix for pure states)
## WARNING: For mixed states, this returns sqrt of diagonal elements
var amplitudes: Array[Complex]:
	get:
		if not _density_matrix:
			return []
		var result: Array[Complex] = []
		for i in range(_density_matrix.dimension()):
			var prob = _density_matrix.get_probability_by_index(i)
			result.append(Complex.new(sqrt(max(0.0, prob)), 0.0))
		return result
	set(value):
		# Convert amplitudes to pure state density matrix
		if _density_matrix and value.size() == _density_matrix.dimension():
			_density_matrix.set_pure_state(value)

## Legacy: emoji_list (now in density matrix)
var emoji_list: Array[String]:
	get:
		if not _density_matrix:
			return []
		return _density_matrix.emoji_list
	set(value):
		push_warning("QuantumBath: emoji_list is read-only. Use initialize_with_emojis()")

## Legacy: emoji_to_index
var emoji_to_index: Dictionary:
	get:
		if not _density_matrix:
			return {}
		return _density_matrix.emoji_to_index
	set(value):
		push_warning("QuantumBath: emoji_to_index is read-only. Use initialize_with_emojis()")

## ========================================
## Legacy Operator Storage (for compatibility)
## ========================================

## Hamiltonian: sparse representation {i: {j: Complex}}
var hamiltonian_sparse: Dictionary = {}

## Lindblad terms: [{source_idx, target_idx, rate}]
var lindblad_terms: Array[Dictionary] = []

## ========================================
## Time Tracking
## ========================================

var bath_time: float = 0.0

## ========================================
## Cached Icons
## ========================================

var active_icons: Array[Icon] = []
var operators_dirty: bool = true

## ========================================
## Sink State Infrastructure (Gozouta 1: Energy Taps)
## Manifest Section 4.1
## ========================================

## Global sink state emoji (drain target for energy taps)
var sink_emoji: String = "⬇️"

## Flux accumulation per emoji this tick
## Maps emoji → probability drained into sink
var sink_flux_per_emoji: Dictionary = {}

## ========================================
## Initialization
## ========================================

func _init():
	_density_matrix = load("res://Core/QuantumSubstrate/DensityMatrix.gd").new()
	_hamiltonian = load("res://Core/QuantumSubstrate/Hamiltonian.gd").new()
	_lindblad = load("res://Core/QuantumSubstrate/LindbladSuperoperator.gd").new()
	_evolver = load("res://Core/QuantumSubstrate/QuantumEvolver.gd").new()

## Initialize with a list of emojis
func initialize_with_emojis(emojis: Array) -> void:
	_density_matrix = load("res://Core/QuantumSubstrate/DensityMatrix.gd").new()
	_density_matrix.initialize_with_emojis(emojis)

	# Start in maximally mixed state
	_density_matrix.set_maximally_mixed()

	operators_dirty = true

## Initialize with uniform superposition (pure state)
func initialize_uniform() -> void:
	if _density_matrix.dimension() == 0:
		push_error("QuantumBath: Cannot initialize_uniform with no emojis. Call initialize_with_emojis first.")
		return

	var n = _density_matrix.dimension()
	var amp = 1.0 / sqrt(float(n))
	var amps: Array = []
	for i in range(n):
		amps.append(Complex.new(amp, 0.0))
	_density_matrix.set_pure_state(amps)

## Initialize with weighted probabilities (classical mixture)
func initialize_weighted(weights: Dictionary) -> void:
	if _density_matrix.dimension() == 0:
		push_error("QuantumBath: Cannot initialize_weighted with no emojis. Call initialize_with_emojis first.")
		return

	var probs: Array = []
	var total = 0.0
	for emoji in _density_matrix.emoji_list:
		var w = weights.get(emoji, 0.0)
		probs.append(w)
		total += w

	if total < 1e-10:
		initialize_uniform()
		return

	# Normalize
	for i in range(probs.size()):
		probs[i] = probs[i] / total

	_density_matrix.set_classical_mixture(probs)

## Initialize with sink state included (for energy tap support)
## Manifest Section 4.1: Sink state infrastructure
func initialize_with_sink(emojis: Array, include_sink: bool = true) -> void:
	var emoji_list = emojis.duplicate()

	# Add sink emoji if not already present
	if include_sink and not emoji_list.has(sink_emoji):
		emoji_list.append(sink_emoji)

	# Initialize with expanded list
	initialize_with_emojis(emoji_list)

	# Sink starts with zero population (no flux yet)
	# Population will accumulate via Lindblad drain operators

## Get flux drained from emoji into sink this tick
## Returns accumulated probability transferred to sink
func get_sink_flux(emoji: String) -> float:
	return sink_flux_per_emoji.get(emoji, 0.0)

## Reset sink flux counters (call after harvest or at tick boundary)
func reset_sink_flux() -> void:
	sink_flux_per_emoji.clear()

## Dynamically inject emoji into running bath
## MANIFEST COMPLIANT: Uses block-embedding to preserve existing probabilities
## (Manifest Section 3.5: "expanding N must not redistribute existing probability")
func inject_emoji(emoji: String, icon: Icon, initial_amplitude: Complex = Complex.zero()) -> bool:
	if _density_matrix.emoji_to_index.has(emoji):
		return true

	# BLOCK-EMBEDDING: Preserve existing density matrix structure
	var old_dim = _density_matrix.dimension()
	var old_matrix = _density_matrix.get_matrix()

	# Expand Hilbert space: N → N+1
	var old_emojis = _density_matrix.emoji_list.duplicate()
	old_emojis.append(emoji)

	# Create new (N+1)×(N+1) density matrix with block structure:
	# ρ_new = [[ρ_old,    0   ],
	#          [  0   , p_new ]]
	# where p_new = |initial_amplitude|²
	var new_dim = old_dim + 1

	# Initialize with new emoji list
	_density_matrix.initialize_with_emojis(old_emojis)
	var new_matrix = ComplexMatrix.new(new_dim)

	# Copy old block (NO RENORMALIZATION!)
	for i in range(old_dim):
		for j in range(old_dim):
			new_matrix.set_element(i, j, old_matrix.get_element(i, j))

	# Set new emoji diagonal element
	var p_new = initial_amplitude.abs_sq()
	new_matrix.set_element(old_dim, old_dim, Complex.new(p_new, 0.0))

	# Off-diagonals between old and new subspaces remain zero (block structure)

	# Apply new matrix
	_density_matrix.set_matrix(new_matrix)

	# PHYSICS CHECK: Trace should now be Tr(ρ_old) + p_new
	# If p_new > 0 and Tr(ρ_old) = 1, then Tr(ρ_new) > 1 (violation!)
	# Player must use pump operators to add population without violating trace
	var current_trace = _density_matrix.get_trace()
	if current_trace > 1.0 + 1e-6:
		push_warning("⚠️  Emoji injection: Tr(ρ) = %.6f > 1.0! New emoji has p=%.6f. Use pump operators to add population instead of non-zero initial_amplitude!" % [current_trace, p_new])

	# Add Icon
	active_icons.append(icon)

	# Rebuild operators with new emoji
	build_hamiltonian_from_icons(active_icons)
	build_lindblad_from_icons(active_icons)

	operators_dirty = false

	print("💉 Injected emoji '%s' via block-embedding: %d→%d dimensions, Tr(ρ)=%.6f" % [
		emoji, old_dim, new_dim, current_trace])

	return true

## ========================================
## Query Methods
## ========================================

## Get amplitude for an emoji (backwards compatible)
func get_amplitude(emoji: String) -> Complex:
	var idx = _density_matrix.emoji_to_index.get(emoji, -1)
	if idx < 0:
		return Complex.zero()
	var prob = _density_matrix.get_probability_by_index(idx)
	return Complex.new(sqrt(max(0.0, prob)), 0.0)

## Get probability for an emoji
func get_probability(emoji: String) -> float:
	return _density_matrix.get_probability(emoji)

## Get total probability (should be 1.0)
func get_total_probability() -> float:
	return _density_matrix.get_trace()

## Normalize the bath state
func normalize() -> void:
	_density_matrix._enforce_trace_one()

## ========================================
## NEW: Density Matrix Observables
## ========================================

## Get purity: Tr(ρ²) - 1 for pure states, 1/N for maximally mixed
func get_purity() -> float:
	return _density_matrix.get_purity()

## Get von Neumann entropy: S = -Tr(ρ log ρ)
func get_entropy() -> float:
	return _density_matrix.get_entropy()

## Get coherence between two emojis
func get_coherence(emoji_a: String, emoji_b: String) -> Complex:
	return _density_matrix.get_coherence(emoji_a, emoji_b)

## Get expected energy from Hamiltonian
func get_expected_energy() -> float:
	return _hamiltonian.get_expected_energy(_density_matrix)

## ========================================
## Population/Energy Methods
## ========================================

## Get population for emoji (same as probability)
func get_population(emoji: String) -> float:
	return get_probability(emoji)

## DEPRECATED: Boost amplitude (violates unitarity - use BiomeBase evolution control instead)
## MANIFEST VIOLATION (Section 1.4): Ad-hoc diagonal tweaks break complete positivity
func boost_amplitude(emoji: String, amount: float) -> void:
	# HARD ERROR in LAB_TRUE mode (quantum rigor enforcement)
	if QuantumRigorConfig.instance and QuantumRigorConfig.instance.is_lab_true_mode():
		push_error("❌ boost_amplitude() FORBIDDEN in LAB_TRUE mode! Violates CPTP (Manifest Section 1.4). Use BiomeBase.boost_hamiltonian_coupling() for unitary control.")
		return

	# KID_LIGHT mode: Allow with deprecation warning (backward compat)
	push_warning("⚠️  QuantumBath.boost_amplitude() DEPRECATED - violates unitarity! Use BiomeBase.boost_hamiltonian_coupling() instead")

	var idx = _density_matrix.emoji_to_index.get(emoji, -1)
	if idx < 0:
		push_warning("QuantumBath: Cannot boost unknown emoji: %s" % emoji)
		return

	if amount <= 0.0:
		return

	var current_prob = _density_matrix.get_probability_by_index(idx)
	var target_prob = current_prob + amount

	# WARNING: This directly modifies ρᵢᵢ which violates unitarity
	# Use BiomeBase.boost_hamiltonian_coupling() for physically correct control
	var mat = _density_matrix.get_matrix()
	mat.set_element(idx, idx, Complex.new(target_prob, 0.0))
	_density_matrix.set_matrix(mat)
	_density_matrix._enforce_trace_one()

## DEPRECATED: Drain amplitude (violates unitarity - use BiomeBase evolution control instead)
## MANIFEST VIOLATION (Section 1.4): Ad-hoc diagonal tweaks break complete positivity
func drain_amplitude(emoji: String, amount: float) -> float:
	# HARD ERROR in LAB_TRUE mode (quantum rigor enforcement)
	if QuantumRigorConfig.instance and QuantumRigorConfig.instance.is_lab_true_mode():
		push_error("❌ drain_amplitude() FORBIDDEN in LAB_TRUE mode! Violates CPTP (Manifest Section 1.4). Use BiomeBase.tune_lindblad_rate() for proper dissipation.")
		return 0.0

	# KID_LIGHT mode: Allow with deprecation warning (backward compat)
	push_warning("⚠️  QuantumBath.drain_amplitude() DEPRECATED - violates unitarity! Use BiomeBase.tune_lindblad_rate() instead")

	var idx = _density_matrix.emoji_to_index.get(emoji, -1)
	if idx < 0:
		return 0.0

	var current_prob = get_probability(emoji)
	var max_drain = current_prob * 0.9
	var actual_drain = min(amount, max_drain)

	if actual_drain < 0.001:
		return 0.0

	var new_prob = max(0.0, current_prob - actual_drain)

	# WARNING: This directly modifies ρᵢᵢ which violates unitarity
	# Use BiomeBase.tune_lindblad_rate() for physically correct dissipation
	var mat = _density_matrix.get_matrix()
	mat.set_element(idx, idx, Complex.new(new_prob, 0.0))
	_density_matrix.set_matrix(mat)
	_density_matrix._enforce_trace_one()

	return actual_drain

## Transfer amplitude between emojis
func transfer_amplitude(from_emoji: String, to_emoji: String, rate: float) -> float:
	var from_idx = _density_matrix.emoji_to_index.get(from_emoji, -1)
	var to_idx = _density_matrix.emoji_to_index.get(to_emoji, -1)

	if from_idx < 0 or to_idx < 0:
		return 0.0

	var from_prob = get_probability(from_emoji)
	var transfer_amount = min(rate, from_prob * 0.5)

	if transfer_amount < 0.001:
		return 0.0

	var mat = _density_matrix.get_matrix()
	var to_prob = get_probability(to_emoji)

	mat.set_element(from_idx, from_idx, Complex.new(from_prob - transfer_amount, 0.0))
	mat.set_element(to_idx, to_idx, Complex.new(to_prob + transfer_amount, 0.0))
	_density_matrix.set_matrix(mat)
	_density_matrix._enforce_trace_one()

	return transfer_amount

## ========================================
## Operator Building
## ========================================

## Build Hamiltonian from Icons
func build_hamiltonian_from_icons(icons: Array) -> void:
	hamiltonian_sparse.clear()

	# Build using new Hamiltonian class
	_hamiltonian.build_from_icons(icons, _density_matrix.emoji_list)

	# Also populate legacy hamiltonian_sparse for compatibility
	for i in range(_hamiltonian.dimension()):
		for j in range(_hamiltonian.dimension()):
			var elem = _hamiltonian.get_element(i, j)
			if elem.abs() > 1e-10:
				if not hamiltonian_sparse.has(i):
					hamiltonian_sparse[i] = {}
				hamiltonian_sparse[i][j] = elem

	operators_dirty = false

## Build Lindblad terms from Icons
func build_lindblad_from_icons(icons: Array) -> void:
	lindblad_terms.clear()

	# Build using new Lindblad class
	_lindblad.build_from_icons(icons, _density_matrix.emoji_list)

	# Also populate legacy lindblad_terms for compatibility
	for term in _lindblad.get_terms():
		var source_idx = _density_matrix.emoji_to_index.get(term.source, -1)
		var target_idx = _density_matrix.emoji_to_index.get(term.target, -1)
		if source_idx >= 0 and target_idx >= 0:
			lindblad_terms.append({
				"source": source_idx,
				"target": target_idx,
				"rate": term.rate
			})

	# Initialize evolver
	_evolver.initialize(_hamiltonian, _lindblad)

## ========================================
## Evolution Methods (NEW: Proper Master Equation)
## ========================================

## Update time-dependent Hamiltonian terms
func update_time_dependent() -> void:
	if active_icons.is_empty():
		return

	_hamiltonian.update(bath_time)

## Full evolution step using proper Lindblad master equation
func evolve(dt: float) -> void:
	if _density_matrix.dimension() == 0:
		return

	bath_time += dt

	# Update time-dependent Hamiltonian
	update_time_dependent()

	# Track energy tap flux (Manifest Section 4.1)
	# Calculate flux BEFORE evolution based on current state
	reset_sink_flux()
	for term in _lindblad.get_terms():
		if term.type == "drain" and term.source:
			var p_source = get_probability(term.source)
			var flux = term.rate * dt * p_source
			if not sink_flux_per_emoji.has(term.source):
				sink_flux_per_emoji[term.source] = 0.0
			sink_flux_per_emoji[term.source] += flux

	# Set evolver time
	_evolver.set_time(bath_time)

	# Evolve using proper quantum mechanics
	_evolver.evolve_in_place(_density_matrix, dt)

	bath_evolved.emit()

## Legacy: evolve_hamiltonian (now uses proper unitary evolution)
func evolve_hamiltonian(dt: float) -> void:
	if _density_matrix.dimension() == 0:
		return

	var U = _hamiltonian.get_cayley_operator(dt)
	_density_matrix.apply_unitary(U)

## Legacy: evolve_lindblad (now uses proper Lindblad superoperator)
func evolve_lindblad(dt: float) -> void:
	if _density_matrix.dimension() == 0:
		return

	var evolved = _lindblad.apply(_density_matrix, dt)
	_density_matrix.set_matrix(evolved.get_matrix())

## ========================================
## Projection Methods
## ========================================

## Project onto a two-emoji axis
func project_onto_axis(north: String, south: String) -> Dictionary:
	var projection = _density_matrix.project_onto_subspace(north, south)

	# Convert to legacy format
	return {
		"radius": projection["radius"],
		"theta": projection["theta"],
		"phi": projection["phi"],
		"valid": projection["p_subspace"] > 1e-10,
		"purity": projection["purity"],
		"p_north": projection["p_north"],
		"p_south": projection["p_south"]
	}

## ========================================
## Measurement Methods
## ========================================

## Partial collapse toward an emoji
func partial_collapse(emoji: String, strength: float) -> void:
	var idx = _density_matrix.emoji_to_index.get(emoji, -1)
	if idx < 0:
		return

	var mat = _density_matrix.get_matrix()
	var dim = _density_matrix.dimension()

	# Full projective collapse for LAB_TRUE mode (strength ≈ 1.0)
	if strength >= 0.99:
		# Born rule projective measurement: ρ → |e⟩⟨e|
		# Set all elements to zero, then set measured state to 1.0
		for i in range(dim):
			for j in range(dim):
				mat.set_element(i, j, Complex.zero())

		# Set outcome to pure state: ρ[idx,idx] = 1.0
		mat.set_element(idx, idx, Complex.one())

	else:
		# Partial collapse for KID_LIGHT mode (strength < 1.0)
		# Boost measured outcome and dampen coherences
		var current = mat.get_element(idx, idx).re
		mat.set_element(idx, idx, Complex.new(current * (1.0 + strength), 0.0))

		# Dampen off-diagonals (decoherence from measurement)
		for i in range(dim):
			for j in range(dim):
				if i != j:
					var off_diag = mat.get_element(i, j)
					mat.set_element(i, j, off_diag.scale(1.0 - strength * 0.5))

		_density_matrix.set_matrix(mat)
		_density_matrix._enforce_trace_one()
		_density_matrix._enforce_hermitian()
		return

	# For projective collapse, no renormalization needed (already Tr=1)
	_density_matrix.set_matrix(mat)

## Measure along an axis (Born rule + full projective collapse)
## Model B: Phase 2 - Implements true projective measurement (no soft collapse)
func measure_axis(north: String, south: String, collapse_strength: float = -1.0) -> String:
	"""Projective measurement in {north, south} basis with state collapse.

	Manifest Section 4.3: MEASURE operation (destructive, collapses state)

	Args:
		north: North pole emoji (maps to |0⟩)
		south: South pole emoji (maps to |1⟩)
		collapse_strength: Collapse strength (1.0=full projective, or -1=use config)

	Returns:
		Outcome emoji (north or south)
	"""
	var p_n = get_probability(north)
	var p_s = get_probability(south)
	var total = p_n + p_s

	if total < 1e-10:
		return ""

	# Use configured collapse strength if not explicitly provided
	var strength = collapse_strength
	if strength < 0:
		strength = get_collapse_strength()  # 1.0 for LAB_TRUE, 0.5 for KID_LIGHT

	var outcome: String
	if randf() < p_n / total:
		outcome = north
		partial_collapse(north, strength)
	else:
		outcome = south
		partial_collapse(south, strength)

	bath_measured.emit(north, south, outcome)
	return outcome


## Inspect measurement probabilities WITHOUT collapsing state
## Model B: Phase 2 - INSPECT operation (non-destructive)
func inspect_axis(north: String, south: String) -> Dictionary:
	"""Non-destructive inspection of measurement probabilities in {north, south} basis.

	Manifest Section 4.3: INSPECT operation (read-only, no collapse)
	Used by visualization and analysis without affecting quantum state.

	Args:
		north: North pole emoji
		south: South pole emoji

	Returns:
		Dictionary with:
			- "north": P(north)
			- "south": P(south)
			- "total": P(north) + P(south) in subspace
	"""
	var p_n = get_probability(north)
	var p_s = get_probability(south)

	return {
		"north": p_n,
		"south": p_s,
		"total": p_n + p_s
	}

## Full collapse to a single emoji
func collapse_to_emoji(emoji: String) -> void:
	var idx = _density_matrix.emoji_to_index.get(emoji, -1)
	if idx < 0:
		push_warning("QuantumBath: Cannot collapse to unknown emoji: %s" % emoji)
		return

	# Create pure state |emoji⟩⟨emoji|
	var amps: Array = []
	for i in range(_density_matrix.dimension()):
		if i == idx:
			amps.append(Complex.one())
		else:
			amps.append(Complex.zero())
	_density_matrix.set_pure_state(amps)

## Collapse in 2D subspace
func collapse_in_subspace(emoji_a: String, emoji_b: String, outcome: String) -> void:
	var idx_a = _density_matrix.emoji_to_index.get(emoji_a, -1)
	var idx_b = _density_matrix.emoji_to_index.get(emoji_b, -1)

	if idx_a < 0 or idx_b < 0:
		push_warning("QuantumBath: Invalid subspace {%s, %s}" % [emoji_a, emoji_b])
		return

	if outcome != emoji_a and outcome != emoji_b:
		push_warning("QuantumBath: Outcome %s not in subspace" % outcome)
		return

	# Zero out the non-measured emoji
	var mat = _density_matrix.get_matrix()
	var zero_idx = idx_b if outcome == emoji_a else idx_a

	mat.set_element(zero_idx, zero_idx, Complex.zero())
	# Also zero off-diagonals involving this index
	for i in range(_density_matrix.dimension()):
		mat.set_element(zero_idx, i, Complex.zero())
		mat.set_element(i, zero_idx, Complex.zero())

	_density_matrix.set_matrix(mat)
	_density_matrix._enforce_trace_one()
	_density_matrix._enforce_hermitian()

## Get collapse strength from quantum rigor configuration
func get_collapse_strength() -> float:
	"""Manifest Section 4.3: Get collapse strength based on backaction mode

	Returns:
		1.0 for LAB_TRUE (full projective collapse)
		0.5 for KID_LIGHT (gentle partial collapse)
	"""
	var config = QuantumRigorConfig.instance
	if config:
		if config.backaction_mode == QuantumRigorConfig.BackactionMode.LAB_TRUE:
			return 1.0  # Full projective collapse (Born rule)
		else:
			return 0.5  # Gentle partial collapse (preserves coherence)
	return 0.5  # Default to gentle if no config

## Selective measurement with postselection cost (Manifest Section 4.3)
func measure_axis_costed(north: String, south: String, max_cost: float = 10.0) -> Dictionary:
	"""Manifest Section 4.3: Selective measurement using postselection cost model

	For selective measurement in a restricted subspace:
	- Cost = 1/p_subspace (expected number of attempts for click)
	- Outcome is random in {north, south} weighted by subspace probabilities
	- Measurement applies collapse with configured strength

	Args:
		north: North pole emoji
		south: South pole emoji
		max_cost: Maximum cost to report (clamp)

	Returns:
		Dictionary with:
			"outcome": Measured emoji (north or south) or ""
			"cost": Cost of measurement in [1, max_cost]
			"p_subspace": Probability of subspace P(north) + P(south)
	"""
	var p_n = get_probability(north)
	var p_s = get_probability(south)
	var p_sub = p_n + p_s

	# No population in subspace
	if p_sub < 1e-10:
		return {
			"outcome": "",
			"cost": max_cost,
			"p_subspace": 0.0
		}

	# Cost = 1/p_sub (expected attempts for click)
	var cost = clamp(1.0 / p_sub, 1.0, max_cost)

	# Conditional measurement: sample from conditional distribution
	var outcome: String
	if randf() < p_n / p_sub:
		outcome = north
		partial_collapse(north, get_collapse_strength())
	else:
		outcome = south
		partial_collapse(south, get_collapse_strength())

	bath_measured.emit(north, south, outcome)

	return {
		"outcome": outcome,
		"cost": cost,
		"p_subspace": p_sub
	}


func measure_marginal_axis(north: String, south: String, collapse_strength: float = -1.0) -> String:
	"""Marginal projective measurement - measures qubit by summing states containing emoji.

	Use this when measuring a single qubit in a multi-qubit composite state.
	For example, measuring temperature (🔥 vs ❄️) in Kitchen's 3-qubit state.

	The method:
	1. Finds all basis states containing 'north' emoji → P(north) = sum of their probabilities
	2. Finds all basis states containing 'south' emoji → P(south) = sum of their probabilities
	3. Randomly chooses north or south weighted by marginal probabilities
	4. Collapses all states in the chosen subspace

	Args:
		north: North pole emoji (e.g., "🔥")
		south: South pole emoji (e.g., "❄️")
		collapse_strength: Collapse strength (1.0=full projective, or -1=use config)

	Returns:
		Outcome emoji (north or south), or "" if no probability in either
	"""
	# Find all basis states containing north emoji
	var north_states = []
	var p_north_total = 0.0
	for emoji in emoji_list:
		if north in emoji:
			north_states.append(emoji)
			p_north_total += get_probability(emoji)

	# Find all basis states containing south emoji
	var south_states = []
	var p_south_total = 0.0
	for emoji in emoji_list:
		if south in emoji:
			south_states.append(emoji)
			p_south_total += get_probability(emoji)

	var total = p_north_total + p_south_total

	if total < 1e-10:
		return ""  # No probability in either subspace

	# Use configured collapse strength if not explicitly provided
	var strength = collapse_strength
	if strength < 0:
		strength = get_collapse_strength()

	# Randomly choose outcome weighted by marginal probabilities
	var outcome: String
	var chosen_states: Array
	if randf() < p_north_total / total:
		outcome = north
		chosen_states = north_states
	else:
		outcome = south
		chosen_states = south_states

	# Collapse all states in the chosen subspace proportionally
	for state in chosen_states:
		partial_collapse(state, strength)

	# Renormalize after collapse
	_density_matrix._enforce_trace_one()

	bath_measured.emit(north, south, outcome)

	return outcome


## ========================================
## Quantum Gate Operations (NEW: Research-Grade)
## ========================================

## Apply single-qubit gate to 2D subspace of density matrix
## north, south: define the qubit basis (|0⟩ = north, |1⟩ = south)
## U: 2×2 unitary matrix
func apply_unitary_1q(north: String, south: String, U) -> void:
	var n_idx = _density_matrix.emoji_to_index.get(north, -1)
	var s_idx = _density_matrix.emoji_to_index.get(south, -1)

	if n_idx < 0 or s_idx < 0:
		push_error("QuantumBath: Cannot apply gate to unknown emojis: %s, %s" % [north, south])
		return

	# Build full-space unitary (identity elsewhere)
	var dim = _density_matrix.dimension()
	var ComplexMatrix = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	var U_full = ComplexMatrix.identity(dim)

	# Insert 2×2 gate into full matrix
	U_full.set_element(n_idx, n_idx, U.get_element(0, 0))
	U_full.set_element(n_idx, s_idx, U.get_element(0, 1))
	U_full.set_element(s_idx, n_idx, U.get_element(1, 0))
	U_full.set_element(s_idx, s_idx, U.get_element(1, 1))

	# Apply: ρ' = UρU†
	_density_matrix.apply_unitary(U_full)

## Apply two-qubit gate to 4D subspace
## Basis order: |n1,n2⟩, |n1,s2⟩, |s1,n2⟩, |s1,s2⟩
## U: 4×4 unitary matrix
func apply_unitary_2q(n1: String, s1: String, n2: String, s2: String, U) -> void:
	var n1_idx = _density_matrix.emoji_to_index.get(n1, -1)
	var s1_idx = _density_matrix.emoji_to_index.get(s1, -1)
	var n2_idx = _density_matrix.emoji_to_index.get(n2, -1)
	var s2_idx = _density_matrix.emoji_to_index.get(s2, -1)

	if n1_idx < 0 or s1_idx < 0 or n2_idx < 0 or s2_idx < 0:
		push_error("QuantumBath: Cannot apply 2Q gate to unknown emojis")
		return

	# Map 4D subspace indices: |00⟩, |01⟩, |10⟩, |11⟩
	var subspace_indices = [
		[n1_idx, n2_idx],  # |00⟩ = |n1,n2⟩
		[n1_idx, s2_idx],  # |01⟩ = |n1,s2⟩
		[s1_idx, n2_idx],  # |10⟩ = |s1,n2⟩
		[s1_idx, s2_idx]   # |11⟩ = |s1,s2⟩
	]

	# Get density matrix
	var rho = _density_matrix.get_matrix()
	var dim = _density_matrix.dimension()

	# Extract 4×4 reduced density matrix
	var Complex = load("res://Core/QuantumSubstrate/Complex.gd")
	var ComplexMatrix = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	var rho_sub = ComplexMatrix.new(4)

	for i in range(4):
		for j in range(4):
			var idx_i = subspace_indices[i]
			var idx_j = subspace_indices[j]
			# For 2-qubit, we need tensor product index
			# But in general bath, each emoji is independent
			# We use the first emoji index as proxy (simplified for now)
			var val = rho.get_element(idx_i[0], idx_j[0])
			rho_sub.set_element(i, j, val)

	# Apply gate: ρ_sub' = U ρ_sub U†
	var rho_sub_new = U.mul(rho_sub).mul(U.dagger())

	# Insert back into full density matrix
	for i in range(4):
		for j in range(4):
			var idx_i = subspace_indices[i]
			var idx_j = subspace_indices[j]
			var val = rho_sub_new.get_element(i, j)
			rho.set_element(idx_i[0], idx_j[0], val)

	_density_matrix.set_matrix(rho)
	_density_matrix._enforce_hermitian()
	_density_matrix._enforce_trace_one()

## Standard gate library
func get_standard_gate(name: String):
	match name:
		"X": return _pauli_x()
		"Y": return _pauli_y()
		"Z": return _pauli_z()
		"H": return _hadamard()
		"CNOT": return _cnot()
		"CZ": return _cz()
		"SWAP": return _swap()
		_:
			push_error("Unknown gate: %s" % name)
			return null

## Pauli-X gate: X = [[0, 1], [1, 0]] (bit flip)
func _pauli_x():
	var Complex = load("res://Core/QuantumSubstrate/Complex.gd")
	var ComplexMatrix = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	var X = ComplexMatrix.new(2)
	X.set_element(0, 0, Complex.zero())
	X.set_element(0, 1, Complex.one())
	X.set_element(1, 0, Complex.one())
	X.set_element(1, 1, Complex.zero())
	return X

## Pauli-Y gate: Y = [[0, -i], [i, 0]]
func _pauli_y():
	var Complex = load("res://Core/QuantumSubstrate/Complex.gd")
	var ComplexMatrix = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	var Y = ComplexMatrix.new(2)
	Y.set_element(0, 0, Complex.zero())
	Y.set_element(0, 1, Complex.new(0.0, -1.0))
	Y.set_element(1, 0, Complex.i())
	Y.set_element(1, 1, Complex.zero())
	return Y

## Pauli-Z gate: Z = [[1, 0], [0, -1]] (phase flip)
func _pauli_z():
	var Complex = load("res://Core/QuantumSubstrate/Complex.gd")
	var ComplexMatrix = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	var Z = ComplexMatrix.new(2)
	Z.set_element(0, 0, Complex.one())
	Z.set_element(0, 1, Complex.zero())
	Z.set_element(1, 0, Complex.zero())
	Z.set_element(1, 1, Complex.new(-1.0, 0.0))
	return Z

## Hadamard gate: H = (1/√2)[[1, 1], [1, -1]]
func _hadamard():
	var Complex = load("res://Core/QuantumSubstrate/Complex.gd")
	var ComplexMatrix = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	var c = 1.0 / sqrt(2.0)
	var H = ComplexMatrix.new(2)
	H.set_element(0, 0, Complex.new(c, 0.0))
	H.set_element(0, 1, Complex.new(c, 0.0))
	H.set_element(1, 0, Complex.new(c, 0.0))
	H.set_element(1, 1, Complex.new(-c, 0.0))
	return H

## CNOT gate: 4×4 controlled-NOT
## Basis: |00⟩, |01⟩, |10⟩, |11⟩
## CNOT|10⟩ = |11⟩, CNOT|11⟩ = |10⟩
func _cnot():
	var Complex = load("res://Core/QuantumSubstrate/Complex.gd")
	var ComplexMatrix = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	var CNOT = ComplexMatrix.new(4)
	# Identity on first two basis states
	CNOT.set_element(0, 0, Complex.one())  # |00⟩ → |00⟩
	CNOT.set_element(1, 1, Complex.one())  # |01⟩ → |01⟩
	# Swap last two basis states
	CNOT.set_element(2, 3, Complex.one())  # |10⟩ → |11⟩
	CNOT.set_element(3, 2, Complex.one())  # |11⟩ → |10⟩
	return CNOT

## CZ gate: 4×4 controlled-Z
## CZ = diag(1, 1, 1, -1)
func _cz():
	var Complex = load("res://Core/QuantumSubstrate/Complex.gd")
	var ComplexMatrix = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	var CZ = ComplexMatrix.new(4)
	CZ.set_element(0, 0, Complex.one())
	CZ.set_element(1, 1, Complex.one())
	CZ.set_element(2, 2, Complex.one())
	CZ.set_element(3, 3, Complex.new(-1.0, 0.0))
	return CZ

## SWAP gate: 4×4 swap two qubits
## SWAP|01⟩ = |10⟩, SWAP|10⟩ = |01⟩
func _swap():
	var Complex = load("res://Core/QuantumSubstrate/Complex.gd")
	var ComplexMatrix = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	var SWAP = ComplexMatrix.new(4)
	SWAP.set_element(0, 0, Complex.one())  # |00⟩ → |00⟩
	SWAP.set_element(1, 2, Complex.one())  # |01⟩ → |10⟩
	SWAP.set_element(2, 1, Complex.one())  # |10⟩ → |01⟩
	SWAP.set_element(3, 3, Complex.one())  # |11⟩ → |11⟩
	return SWAP

## ========================================
## Debug/Utility Methods
## ========================================

## Get full probability distribution
func get_probability_distribution() -> Dictionary:
	var dist = {}
	for emoji in _density_matrix.emoji_list:
		dist[emoji] = get_probability(emoji)
	return dist

## Debug: Print current state
func debug_print() -> void:
	print("\n=== QuantumBath State (Density Matrix) ===")
	print("Time: %.2f s" % bath_time)
	print("Dimension: %d" % _density_matrix.dimension())
	print("Trace: %.6f" % get_total_probability())
	print("Purity: %.6f (1.0 = pure, 1/N = maximally mixed)" % get_purity())
	print("Entropy: %.6f" % get_entropy())
	print("\nProbability Distribution:")
	var dist = get_probability_distribution()
	for emoji in _density_matrix.emoji_list:
		var prob = dist[emoji]
		if prob > 0.001:
			print("  %s: %.4f" % [emoji, prob])
	print("==========================================\n")

## Validate density matrix properties
func validate() -> Dictionary:
	return _density_matrix.is_valid()

## Get direct access to density matrix (for advanced use)
func get_density_matrix():
	return _density_matrix
