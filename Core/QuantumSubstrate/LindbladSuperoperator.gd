class_name LindbladSuperoperator
extends RefCounted

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const DensityMatrix = preload("res://Core/QuantumSubstrate/DensityMatrix.gd")

## LindbladSuperoperator: Dissipative quantum evolution
##
## The Lindblad master equation describes open quantum system dynamics:
##
##   dρ/dt = -i[H,ρ] + Σₖ γₖ D[Lₖ](ρ)
##
## where D[L](ρ) = LρL† - ½{L†L, ρ} is the dissipator
##
## This class handles the dissipative part: Σₖ γₖ D[Lₖ](ρ)
##
## Physical interpretation:
## - Each Lindblad operator Lₖ represents a "jump" or "decay" channel
## - γₖ is the rate of that channel
## - For population transfer i→j: L = |j⟩⟨i| (creates j, destroys i)
## - Decoherence: L = |i⟩⟨i| causes pure dephasing
##
## Trace preservation:
## - The Lindblad form guarantees Tr(ρ) is preserved
## - Each D[L](ρ) has Tr(D[L](ρ)) = 0

## Storage for Lindblad terms
## Each term is { "L": ComplexMatrix, "rate": float, "source": String, "target": String }
var _terms: Array = []
var _dimension: int = 0
var emoji_list: Array[String] = []
var emoji_to_index: Dictionary = {}

#region Construction

func _init():
	pass

## Build Lindblad operators from Icons and emoji list
func build_from_icons(icons: Array, emojis: Array) -> void:
	_terms = []
	emoji_list = []
	emoji_to_index = {}

	for i in range(emojis.size()):
		var emoji = emojis[i]
		emoji_list.append(emoji)
		emoji_to_index[emoji] = i

	_dimension = emojis.size()

	# Build terms from each Icon
	for icon in icons:
		var source_idx = emoji_to_index.get(icon.emoji, -1)
		if source_idx < 0:
			continue

		# Lindblad outgoing: source loses population to target
		# L = |target⟩⟨source|
		for target_emoji in icon.lindblad_outgoing:
			var target_idx = emoji_to_index.get(target_emoji, -1)
			if target_idx >= 0:
				var rate = icon.lindblad_outgoing[target_emoji]
				var L = _create_jump_operator(target_idx, source_idx)
				_terms.append({
					"L": L,
					"rate": rate,
					"source": icon.emoji,
					"target": target_emoji,
					"type": "transfer"
				})

		# Decay: source loses to decay_target
		if icon.decay_rate > 0 and icon.decay_target:
			var decay_idx = emoji_to_index.get(icon.decay_target, -1)
			if decay_idx >= 0:
				var L = _create_jump_operator(decay_idx, source_idx)
				_terms.append({
					"L": L,
					"rate": icon.decay_rate,
					"source": icon.emoji,
					"target": icon.decay_target,
					"type": "decay"
				})

	# Energy Tap Drains: emoji drains to sink state (Manifest Section 4.1)
	# L_e = |sink⟩⟨e| with rate κ
	var sink_idx = emoji_to_index.get("⬇️", -1)
	if sink_idx >= 0:
		for icon in icons:
			var emoji_idx = emoji_to_index.get(icon.emoji, -1)
			if emoji_idx >= 0 and icon.is_drain_target and icon.drain_to_sink_rate > 0.0:
				if emoji_idx != sink_idx:  # Don't drain sink to itself
					var L = _create_jump_operator(sink_idx, emoji_idx)
					_terms.append({
						"L": L,
						"rate": icon.drain_to_sink_rate,
						"source": icon.emoji,
						"target": "⬇️",
						"type": "drain"
					})

	# Process lindblad_incoming (convert to outgoing from source perspective)
	# This is syntactic sugar: if A has incoming from B, treat as B→A
	for icon in icons:
		var target_idx = emoji_to_index.get(icon.emoji, -1)
		if target_idx < 0:
			continue

		for source_emoji in icon.lindblad_incoming:
			var source_idx = emoji_to_index.get(source_emoji, -1)
			if source_idx >= 0:
				var rate = icon.lindblad_incoming[source_emoji]

				# Check if this term already exists (from source's outgoing)
				var exists = false
				for term in _terms:
					if term.source == source_emoji and term.target == icon.emoji:
						exists = true
						break

				if not exists:
					var L = _create_jump_operator(target_idx, source_idx)
					_terms.append({
						"L": L,
						"rate": rate,
						"source": source_emoji,
						"target": icon.emoji,
						"type": "incoming"
					})

## Create jump operator |j⟩⟨i| that transfers from i to j
func _create_jump_operator(j: int, i: int) -> ComplexMatrix:
	var L = ComplexMatrix.new(_dimension)
	L.set_element(j, i, Complex.one())
	return L

## Add a custom Lindblad term
func add_term(L: ComplexMatrix, rate: float, description: String = "") -> void:
	_terms.append({
		"L": L,
		"rate": rate,
		"source": "",
		"target": "",
		"type": "custom",
		"description": description
	})

## Add a dephasing term on state i (pure decoherence without population change)
func add_dephasing(i: int, rate: float) -> void:
	var L = ComplexMatrix.new(_dimension)
	L.set_element(i, i, Complex.one())
	_terms.append({
		"L": L,
		"rate": rate,
		"source": emoji_list[i] if i < emoji_list.size() else "",
		"target": emoji_list[i] if i < emoji_list.size() else "",
		"type": "dephasing"
	})

#endregion

#region Evolution

## Apply all Lindblad terms to density matrix for timestep dt
## Returns new density matrix (does not modify in place)
func apply(rho, dt: float):
	var result = rho.duplicate_density()

	for term in _terms:
		_apply_single_term(result, term.L, term.rate, dt)

	return result

## Apply all Lindblad terms using sparse jump operator optimization
## Much faster for jump operators L = |j⟩⟨i| (which are extremely sparse)
## Returns new density matrix (does not modify in place)
func apply_sparse(rho, dt: float):
	var result = rho.duplicate_density()

	for term in _terms:
		# Extract source and target indices from the term
		var source_idx = emoji_to_index.get(term.source, -1)
		var target_idx = emoji_to_index.get(term.target, -1)

		if source_idx >= 0 and target_idx >= 0:
			_apply_jump_operator_sparse(result, source_idx, target_idx, term.rate, dt)
		else:
			# Fallback to dense for custom terms
			_apply_single_term(result, term.L, term.rate, dt)

	return result

## Apply single Lindblad term: γ D[L](ρ) = γ (LρL† - ½{L†L, ρ})
func _apply_single_term(rho, L: ComplexMatrix, rate: float, dt: float) -> void:
	var rho_mat = rho.get_matrix()
	var L_dag = L.dagger()
	var L_dag_L = L_dag.mul(L)

	# LρL†
	var term1 = L.mul(rho_mat).mul(L_dag)

	# ½ L†L ρ
	var term2 = L_dag_L.mul(rho_mat).scale_real(0.5)

	# ½ ρ L†L
	var term3 = rho_mat.mul(L_dag_L).scale_real(0.5)

	# D[L](ρ) = term1 - term2 - term3
	var dissipator = term1.sub(term2).sub(term3)

	# Apply: ρ += γ dt D[L](ρ)
	var new_rho = rho_mat.add(dissipator.scale_real(rate * dt))
	rho.set_matrix(new_rho)

## Apply jump operator L = |j⟩⟨i| using sparse optimization
## For jump operators, the Lindblad dissipator can be computed without matrix multiplication
##
## D[L](ρ) = LρL† - ½{L†L, ρ}
## where L = |j⟩⟨i| has only ONE non-zero element at (j,i)
##
## This gives:
## - LρL† transfers population: ρⱼⱼ += ρᵢᵢ, dampens coherences
## - L†L = |i⟩⟨i| (projection onto source state)
## - {L†L, ρ} dampens terms involving state i
func _apply_jump_operator_sparse(rho, source_idx: int, target_idx: int, rate: float, dt: float) -> void:
	var rho_mat = rho.get_matrix()
	var gamma_dt = rate * dt

	# Use direct array access for performance (skip bounds checking)
	var rho_data = rho_mat._data
	var dim = _dimension

	# Get source population (will be transferred to target)
	var source_diag_idx = source_idx * dim + source_idx
	var rho_ii = rho_data[source_diag_idx]

	# Apply dissipator: D[L](ρ) = LρL† - ½{L†L, ρ}

	# 1. LρL† term: Transfers population from source to target
	#    and creates coherence damping
	var target_diag_idx = target_idx * dim + target_idx
	var rho_jj = rho_data[target_diag_idx]
	rho_data[target_diag_idx] = rho_jj.add(rho_ii.scale(gamma_dt))

	# If source != target, also affect the source diagonal
	if source_idx != target_idx:
		for k in range(dim):
			# Cross-term: affects ρₛₖ and ρₖₛ (coherences involving source)
			if k != source_idx and k != target_idx:
				var rho_sk = rho_data[source_idx * dim + k]
				var rho_ks = rho_data[k * dim + source_idx]
				var rho_tk = rho_data[target_idx * dim + k]
				var rho_kt = rho_data[k * dim + target_idx]

				# LρL† creates new coherences target-k from source-k
				rho_data[target_idx * dim + k] = rho_tk.add(rho_sk.scale(gamma_dt))
				rho_data[k * dim + target_idx] = rho_kt.add(rho_ks.scale(gamma_dt))

	# 2. -½{L†L, ρ} term: Dampens source state
	#    L†L = |i⟩⟨i|, so {L†L, ρ} = 2|i⟩⟨i|ρ|i⟩⟨i| for diagonal part
	#    and dampens off-diagonal elements involving source

	# Dampen source diagonal
	var damping_factor = Complex.new(1.0 - gamma_dt, 0.0)
	rho_data[source_diag_idx] = rho_ii.mul(damping_factor)

	# Dampen coherences involving source
	var half_damping = Complex.new(1.0 - gamma_dt * 0.5, 0.0)
	for k in range(dim):
		if k != source_idx:
			var rho_sk = rho_data[source_idx * dim + k]
			var rho_ks = rho_data[k * dim + source_idx]

			rho_data[source_idx * dim + k] = rho_sk.mul(half_damping)
			rho_data[k * dim + source_idx] = rho_ks.mul(half_damping)

	rho.set_matrix(rho_mat)

## Get total transfer rate out of a state
func get_outgoing_rate(emoji: String) -> float:
	var total = 0.0
	for term in _terms:
		if term.source == emoji:
			total += term.rate
	return total

## Get total transfer rate into a state
func get_incoming_rate(emoji: String) -> float:
	var total = 0.0
	for term in _terms:
		if term.target == emoji:
			total += term.rate
	return total

#endregion

#region Query

## Get all terms
func get_terms() -> Array:
	return _terms

## Get terms by type
func get_terms_by_type(type: String) -> Array:
	var result: Array = []
	for term in _terms:
		if term.type == type:
			result.append(term)
	return result

## Get dimension
func dimension() -> int:
	return _dimension

#endregion

#region Validation

## Verify trace preservation (should be automatic for Lindblad form)
## Returns true if applying superoperator preserves trace
func verify_trace_preservation(test_dt: float = 0.01) -> bool:
	# Create test density matrix (maximally mixed)
	var test_rho = DensityMatrix.new()
	test_rho.initialize_with_emojis(emoji_list)
	test_rho.set_maximally_mixed()

	var initial_trace = test_rho.get_trace()
	var evolved = apply(test_rho, test_dt)
	var final_trace = evolved.get_trace()

	return abs(initial_trace - final_trace) < 1e-10

## Verify complete positivity (eigenvalues of evolved ρ should be ≥ 0)
func verify_positivity(test_dt: float = 0.01) -> bool:
	# Create test density matrix (pure state)
	var test_rho = DensityMatrix.new()
	test_rho.initialize_with_emojis(emoji_list)
	var amps: Array = []
	for i in range(_dimension):
		amps.append(Complex.new(1.0 / sqrt(_dimension), 0.0))
	test_rho.set_pure_state(amps)

	var evolved = apply(test_rho, test_dt)
	var validation = evolved.is_valid()

	return validation.positive_semidefinite

#endregion

#region Debug

func _to_string() -> String:
	return "LindbladSuperoperator(%d states, %d terms)" % [_dimension, _terms.size()]

func debug_print() -> void:
	print("=== Lindblad Superoperator ===")
	print("Dimension: %d" % _dimension)
	print("Number of terms: %d" % _terms.size())
	print("\nTransfer terms:")
	for term in _terms:
		if term.source and term.target:
			print("  %s → %s: γ = %.5f/sec (type: %s)" % [
				term.source, term.target, term.rate, term.type
			])
		elif term.has("description"):
			print("  Custom: %s, γ = %.5f/sec" % [term.description, term.rate])

#endregion
