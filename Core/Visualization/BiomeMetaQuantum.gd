class_name BiomeMetaQuantum
extends RefCounted

## Biome Meta-Quantum System
##
## Treats the 6 biomes as a 6-level quantum system with:
## - 6×6 meta-density-matrix ρ̃ (biome correlations)
## - 6×6 meta-Hamiltonian H̃ (derived from inner biome states)
## - Lindblad evolution for meta-level dynamics
##
## Physical interpretation:
## - ρ̃[i,i] = "activity weight" of biome i (how quantum-active it is)
## - ρ̃[i,j] = "coherence" between biomes (economic/narrative entanglement)
## - H̃[i,i] = expected energy ⟨E⟩ of biome i = Tr(H_i ρ_i)
## - H̃[i,j] = coupling strength (trade flow, semantic overlap)
##
## The meta-state drives force graph positioning:
## - High ρ̃[i,i] → biome is prominent (moves toward center)
## - High |ρ̃[i,j]| → biomes attract (meta-entanglement)
## - Meta-MI I(i:j) → clustering strength

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")

# Meta-system dimension
const META_DIM = 6

# Evolution parameters
const META_EVOLUTION_RATE = 0.5  # Slower than inner evolution
const META_DEPHASING_RATE = 0.1  # Decoherence rate for off-diagonals
const META_THERMALIZATION_RATE = 0.02  # Drift toward uniform

# Biome references
var biomes: Array = []  # Array of BiomeBase
var biome_names: Array[String] = []

# Meta quantum state
var meta_rho: ComplexMatrix = null  # 6×6 density matrix
var meta_hamiltonian: ComplexMatrix = null  # 6×6 Hamiltonian

# Cached values for force calculations
var meta_populations: Array[float] = []  # ρ̃[i,i] diagonal
var meta_coherences: Array = []  # ρ̃[i,j] off-diagonal magnitudes
var meta_mutual_info: Array = []  # I(i:j) for all pairs

# Statistics
var total_evolution_steps: int = 0


func initialize(biome_array: Array) -> void:
	"""Initialize meta-quantum system with biome references."""
	biomes = biome_array.filter(func(b): return b != null)
	biome_names.clear()

	for biome in biomes:
		var name = biome.get_biome_type() if biome.has_method("get_biome_type") else "Unknown"
		biome_names.append(name)

	# Initialize meta density matrix to uniform mixed state
	# ρ̃ = I/6 (equal weight on all biomes)
	meta_rho = ComplexMatrix.zeros(META_DIM)
	for i in range(META_DIM):
		meta_rho.set_element(i, i, Complex.new(1.0 / META_DIM, 0.0))

	# Initialize Hamiltonian (will be computed from biome states)
	meta_hamiltonian = ComplexMatrix.zeros(META_DIM)

	# Initialize cache arrays
	meta_populations.resize(META_DIM)
	meta_populations.fill(1.0 / META_DIM)

	print("BiomeMetaQuantum: Initialized %d-level meta-system" % biomes.size())


func evolve(dt: float) -> void:
	"""Evolve the meta-quantum state.

	1. Rebuild meta-Hamiltonian from current biome states
	2. Apply Lindblad evolution to meta-density-matrix
	3. Cache populations/coherences for force calculations
	"""
	if meta_rho == null or biomes.is_empty():
		return

	# Step 1: Rebuild meta-Hamiltonian from biome states
	_rebuild_meta_hamiltonian()

	# Step 2: Lindblad evolution
	_evolve_meta_lindblad(dt * META_EVOLUTION_RATE)

	# Step 3: Cache values for force graph
	_cache_meta_observables()

	total_evolution_steps += 1


func _rebuild_meta_hamiltonian() -> void:
	"""Compute meta-Hamiltonian from inner biome quantum states.

	H̃[i,i] = Tr(H_i ρ_i) = expected energy of biome i
	H̃[i,j] = coupling from trade/semantic overlap
	"""
	# Clear
	for i in range(META_DIM):
		for j in range(META_DIM):
			meta_hamiltonian.set_element(i, j, Complex.zero())

	# Diagonal: expected energy per biome
	for i in range(mini(biomes.size(), META_DIM)):
		var biome = biomes[i]
		if not biome or not biome.quantum_computer:
			continue

		var expected_energy = _compute_expected_energy(biome)
		meta_hamiltonian.set_element(i, i, Complex.new(expected_energy, 0.0))

	# Off-diagonal: biome coupling
	for i in range(mini(biomes.size(), META_DIM)):
		for j in range(i + 1, mini(biomes.size(), META_DIM)):
			var coupling = _compute_biome_coupling(biomes[i], biomes[j])
			meta_hamiltonian.set_element(i, j, Complex.new(coupling, 0.0))
			meta_hamiltonian.set_element(j, i, Complex.new(coupling, 0.0))


func _compute_expected_energy(biome) -> float:
	"""Compute ⟨E⟩ = Tr(H ρ) for a biome."""
	var qc = biome.quantum_computer
	if not qc or not qc.hamiltonian or not qc.density_matrix:
		return 0.0

	var H = qc.hamiltonian
	var rho = qc.density_matrix
	var dim = H.n

	# Tr(H ρ) = Σ_ij H_ij ρ_ji
	var trace_sum = 0.0
	for i in range(dim):
		for j in range(dim):
			var h_ij = H.get_element(i, j)
			var rho_ji = rho.get_element(j, i)
			# Real part of H_ij × ρ_ji
			trace_sum += h_ij.re * rho_ji.re - h_ij.im * rho_ji.im

	return trace_sum


func _compute_biome_coupling(biome_a, biome_b) -> float:
	"""Compute coupling between two biomes.

	Based on:
	1. Vocabulary overlap (shared emojis)
	2. Purity similarity (similar quantum character)
	3. Trade connections (if economy system exists)
	"""
	var coupling = 0.0

	# 1. Vocabulary overlap
	if biome_a.has_method("get_icon_library") and biome_b.has_method("get_icon_library"):
		var icons_a = biome_a.get_icon_library()
		var icons_b = biome_b.get_icon_library()

		if icons_a and icons_b:
			var emojis_a = icons_a.get_all_emojis() if icons_a.has_method("get_all_emojis") else []
			var emojis_b = icons_b.get_all_emojis() if icons_b.has_method("get_all_emojis") else []

			var overlap = 0
			for emoji in emojis_a:
				if emoji in emojis_b:
					overlap += 1

			coupling += overlap * 0.1

	# 2. Purity similarity
	var qc_a = biome_a.quantum_computer
	var qc_b = biome_b.quantum_computer

	if qc_a and qc_b:
		var purity_a = qc_a.get_purity() if qc_a.has_method("get_purity") else 0.5
		var purity_b = qc_b.get_purity() if qc_b.has_method("get_purity") else 0.5

		# Similar purity → stronger coupling
		var purity_similarity = 1.0 - abs(purity_a - purity_b)
		coupling += purity_similarity * 0.2

	# 3. Could add trade connections here
	# coupling += economy.get_trade_flow(biome_a, biome_b) * 0.5

	return coupling


func _evolve_meta_lindblad(dt: float) -> void:
	"""Lindblad evolution of meta-density-matrix.

	dρ̃/dt = -i[H̃, ρ̃] + Σ_k γ_k (L_k ρ̃ L_k† - ½{L_k†L_k, ρ̃})

	Lindblad channels:
	1. Dephasing: Destroys off-diagonal coherence (decoherence)
	2. Thermalization: Drives toward uniform distribution
	"""
	var drho = ComplexMatrix.zeros(META_DIM)

	# Term 1: Hamiltonian evolution -i[H̃, ρ̃]
	var commutator = _commutator(meta_hamiltonian, meta_rho)
	var neg_i = Complex.new(0.0, -1.0)
	drho = drho.add(commutator.scale(neg_i))

	# Term 2: Dephasing (decay off-diagonals)
	# L_k = |k⟩⟨k| projectors cause pure dephasing
	for i in range(META_DIM):
		for j in range(META_DIM):
			if i != j:
				var rho_ij = meta_rho.get_element(i, j)
				# Dephasing: ρ_ij → ρ_ij × e^(-γt) ≈ ρ_ij × (1 - γdt)
				var decay = Complex.new(-META_DEPHASING_RATE * rho_ij.re,
				                        -META_DEPHASING_RATE * rho_ij.im)
				drho.set_element(i, j, drho.get_element(i, j).add(decay))

	# Term 3: Thermalization (drift toward uniform)
	# Drives ρ_ii toward 1/N
	var target_pop = 1.0 / META_DIM
	for i in range(META_DIM):
		var current_pop = meta_rho.get_element(i, i).re
		var drift = (target_pop - current_pop) * META_THERMALIZATION_RATE
		var current_drho = drho.get_element(i, i)
		drho.set_element(i, i, Complex.new(current_drho.re + drift, current_drho.im))

	# Euler integration
	meta_rho = meta_rho.add(drho.scale_real(dt))

	# Renormalize
	_renormalize_meta_rho()


func _commutator(A: ComplexMatrix, B: ComplexMatrix) -> ComplexMatrix:
	"""Compute [A, B] = AB - BA."""
	var AB = A.mul(B)
	var BA = B.mul(A)
	return AB.sub(BA)


func _renormalize_meta_rho() -> void:
	"""Ensure Tr(ρ̃) = 1 and ρ̃ is valid density matrix."""
	# Compute trace
	var trace = 0.0
	for i in range(META_DIM):
		trace += meta_rho.get_element(i, i).re

	if trace < 1e-10:
		# Reinitialize to uniform
		for i in range(META_DIM):
			for j in range(META_DIM):
				if i == j:
					meta_rho.set_element(i, j, Complex.new(1.0 / META_DIM, 0.0))
				else:
					meta_rho.set_element(i, j, Complex.zero())
		return

	# Normalize
	if abs(trace - 1.0) > 1e-10:
		var scale = 1.0 / trace
		for i in range(META_DIM):
			for j in range(META_DIM):
				var val = meta_rho.get_element(i, j)
				meta_rho.set_element(i, j, Complex.new(val.re * scale, val.im * scale))


func _cache_meta_observables() -> void:
	"""Cache populations, coherences, and MI for force calculations."""
	# Populations (diagonal)
	for i in range(META_DIM):
		meta_populations[i] = meta_rho.get_element(i, i).re

	# Coherences (off-diagonal magnitudes)
	meta_coherences.clear()
	for i in range(META_DIM):
		for j in range(i + 1, META_DIM):
			var c = meta_rho.get_element(i, j)
			meta_coherences.append({
				"i": i,
				"j": j,
				"magnitude": sqrt(c.re * c.re + c.im * c.im),
				"phase": atan2(c.im, c.re)
			})

	# Mutual information between all biome pairs
	meta_mutual_info.clear()
	for i in range(META_DIM):
		for j in range(i + 1, META_DIM):
			var mi = _compute_meta_mutual_info(i, j)
			meta_mutual_info.append({
				"i": i,
				"j": j,
				"mi": mi
			})


func _compute_meta_mutual_info(i: int, j: int) -> float:
	"""Compute mutual information I(i:j) at meta level.

	For a 2-level subsystem extracted from the 6-level meta-state:
	I(i:j) = S(ρ_i) + S(ρ_j) - S(ρ_ij)

	Where ρ_ij is the 2×2 reduced density matrix for biomes i,j.
	"""
	# Extract 2×2 block for biomes i and j
	var rho_ii = meta_rho.get_element(i, i).re
	var rho_jj = meta_rho.get_element(j, j).re
	var rho_ij = meta_rho.get_element(i, j)

	# Normalize to get 2×2 reduced state
	var total = rho_ii + rho_jj
	if total < 1e-10:
		return 0.0

	var p_i = rho_ii / total
	var p_j = rho_jj / total
	var coh_mag = sqrt(rho_ij.re * rho_ij.re + rho_ij.im * rho_ij.im) / total

	# Eigenvalues of 2×2 density matrix
	# λ± = (1 ± √(1 - 4(p_i×p_j - |c|²))) / 2
	var det = p_i * p_j - coh_mag * coh_mag
	var discriminant = maxf(1.0 - 4.0 * det, 0.0)
	var sqrt_disc = sqrt(discriminant)

	var lambda_plus = (1.0 + sqrt_disc) / 2.0
	var lambda_minus = (1.0 - sqrt_disc) / 2.0

	# Joint entropy S(ρ_ij)
	var S_joint = 0.0
	if lambda_plus > 1e-15:
		S_joint -= lambda_plus * log(lambda_plus) / log(2.0)
	if lambda_minus > 1e-15:
		S_joint -= lambda_minus * log(lambda_minus) / log(2.0)

	# Marginal entropies S(ρ_i), S(ρ_j)
	# For single-site marginals in this embedding, they're just binary entropy
	var S_i = _binary_entropy(p_i)
	var S_j = _binary_entropy(p_j)

	# I(i:j) = S_i + S_j - S_joint
	return maxf(S_i + S_j - S_joint, 0.0)


func _binary_entropy(p: float) -> float:
	"""Binary entropy H(p) = -p log p - (1-p) log(1-p)."""
	if p < 1e-15 or p > 1.0 - 1e-15:
		return 0.0
	var q = 1.0 - p
	return -(p * log(p) + q * log(q)) / log(2.0)


# ============================================================================
# PUBLIC API FOR FORCE GRAPH
# ============================================================================

func get_biome_weight(biome_index: int) -> float:
	"""Get meta-population ρ̃[i,i] for biome i.

	Higher weight → biome is more "active" → moves toward center.
	"""
	if biome_index < 0 or biome_index >= meta_populations.size():
		return 1.0 / META_DIM
	return meta_populations[biome_index]


func get_biome_coherence(biome_i: int, biome_j: int) -> float:
	"""Get meta-coherence |ρ̃[i,j]| between biomes.

	Higher coherence → biomes are "entangled" at meta level → attract.
	"""
	for coh in meta_coherences:
		if (coh.i == biome_i and coh.j == biome_j) or \
		   (coh.i == biome_j and coh.j == biome_i):
			return coh.magnitude
	return 0.0


func get_biome_mutual_info(biome_i: int, biome_j: int) -> float:
	"""Get meta-level mutual information I(i:j).

	Higher MI → biomes are correlated → cluster together.
	"""
	for mi_entry in meta_mutual_info:
		if (mi_entry.i == biome_i and mi_entry.j == biome_j) or \
		   (mi_entry.i == biome_j and mi_entry.j == biome_i):
			return mi_entry.mi
	return 0.0


func get_all_meta_mi() -> Array:
	"""Get all pairwise mutual information values.

	Returns: Array of {i, j, mi} dictionaries.
	"""
	return meta_mutual_info.duplicate()


func inject_player_action(biome_index: int, action_strength: float = 0.3) -> void:
	"""Inject player action as measurement-like collapse.

	When player interacts with biome i:
	1. Increase ρ̃[i,i] (focus on that biome)
	2. Partially dephase coherences with other biomes

	This makes the active biome more prominent in the force graph.
	"""
	if biome_index < 0 or biome_index >= META_DIM:
		return

	# Boost diagonal (like partial measurement toward |i⟩)
	var current_pop = meta_rho.get_element(biome_index, biome_index).re
	var boost = action_strength * (1.0 - current_pop)

	# Redistribute from other biomes
	var reduction_per_other = boost / (META_DIM - 1)

	for i in range(META_DIM):
		var pop = meta_rho.get_element(i, i).re
		if i == biome_index:
			meta_rho.set_element(i, i, Complex.new(pop + boost, 0.0))
		else:
			meta_rho.set_element(i, i, Complex.new(maxf(pop - reduction_per_other, 0.01), 0.0))

	# Partial dephasing of coherences involving this biome
	for i in range(META_DIM):
		if i == biome_index:
			continue
		var coh = meta_rho.get_element(biome_index, i)
		var decayed = Complex.new(coh.re * 0.7, coh.im * 0.7)
		meta_rho.set_element(biome_index, i, decayed)
		meta_rho.set_element(i, biome_index, decayed.conjugate())

	_renormalize_meta_rho()
	_cache_meta_observables()


func create_biome_entanglement(biome_i: int, biome_j: int, strength: float = 0.2) -> void:
	"""Create meta-level entanglement between two biomes.

	Could be triggered by:
	- Building a trade route between biomes
	- Quest that connects biomes narratively
	- Player action that links biomes

	Increases off-diagonal coherence ρ̃[i,j].
	"""
	if biome_i < 0 or biome_i >= META_DIM or biome_j < 0 or biome_j >= META_DIM:
		return
	if biome_i == biome_j:
		return

	var current = meta_rho.get_element(biome_i, biome_j)

	# Max coherence limited by populations: |ρ_ij| ≤ √(ρ_ii × ρ_jj)
	var pop_i = meta_rho.get_element(biome_i, biome_i).re
	var pop_j = meta_rho.get_element(biome_j, biome_j).re
	var max_coh = sqrt(pop_i * pop_j)

	var current_mag = sqrt(current.re * current.re + current.im * current.im)
	var new_mag = minf(current_mag + strength * max_coh, max_coh * 0.9)

	# Preserve phase, increase magnitude
	var phase = atan2(current.im, current.re) if current_mag > 1e-10 else 0.0
	var new_coh = Complex.new(new_mag * cos(phase), new_mag * sin(phase))

	meta_rho.set_element(biome_i, biome_j, new_coh)
	meta_rho.set_element(biome_j, biome_i, new_coh.conjugate())

	_renormalize_meta_rho()
	_cache_meta_observables()


func get_debug_string() -> String:
	"""Debug output of meta-quantum state."""
	var s = "=== BiomeMetaQuantum ===\n"
	s += "Populations:\n"
	for i in range(mini(biomes.size(), META_DIM)):
		s += "  %s: %.3f\n" % [biome_names[i] if i < biome_names.size() else "?", meta_populations[i]]

	s += "Top coherences:\n"
	var sorted_coh = meta_coherences.duplicate()
	sorted_coh.sort_custom(func(a, b): return a.magnitude > b.magnitude)
	for k in range(mini(3, sorted_coh.size())):
		var c = sorted_coh[k]
		var name_i = biome_names[c.i] if c.i < biome_names.size() else "?"
		var name_j = biome_names[c.j] if c.j < biome_names.size() else "?"
		s += "  %s↔%s: %.3f\n" % [name_i, name_j, c.magnitude]

	s += "Top MI:\n"
	var sorted_mi = meta_mutual_info.duplicate()
	sorted_mi.sort_custom(func(a, b): return a.mi > b.mi)
	for k in range(mini(3, sorted_mi.size())):
		var m = sorted_mi[k]
		var name_i = biome_names[m.i] if m.i < biome_names.size() else "?"
		var name_j = biome_names[m.j] if m.j < biome_names.size() else "?"
		s += "  I(%s:%s) = %.3f bits\n" % [name_i, name_j, m.mi]

	return s
