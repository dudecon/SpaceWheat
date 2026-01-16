class_name SparkConverter
extends RefCounted

## Spark Converter: Extract Energy from Quantum Potential
##
## The Sparks mechanic allows players to convert "imaginary" quantum energy
## (off-diagonal coherence) into "real" observable energy (diagonal population).
##
## Physics Analogy:
## - Off-diagonal elements represent quantum superposition/coherence
## - Diagonal elements represent classical probabilities
## - Extraction = partial decoherence + population boost
##
## Gameplay Effect:
## - Trade quantum potential (flexibility) for immediate observable gain
## - Higher coherence → more extractable energy
## - Extraction causes decoherence (reduces future flexibility)
##
## Formula:
## - Extract fraction f of imaginary energy I
## - Boost target population by f × I × efficiency
## - Decay all off-diagonal by exp(-f × decay_rate)

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")

## Extraction efficiency (how much imaginary converts to real)
const EXTRACTION_EFFICIENCY: float = 0.8

## Decoherence rate multiplier (how much coherence is lost per extraction)
const DECOHERENCE_RATE: float = 2.0

## Minimum coherence required for extraction
const MIN_COHERENCE_THRESHOLD: float = 0.01


## ========================================
## Public API
## ========================================

static func extract_spark(quantum_computer, target_emoji: String, extraction_fraction: float = 0.1) -> Dictionary:
	"""Extract quantum potential as real observable

	Converts imaginary (coherence) energy into real (population) energy.
	This is a trade: gain immediate observable at cost of quantum flexibility.

	Args:
		quantum_computer: QuantumComputer to extract from
		target_emoji: Which observable to boost
		extraction_fraction: How much imaginary to convert (0.0-1.0)

	Returns:
		{
			"success": bool,
			"extracted_amount": float,      # How much energy was extracted
			"new_population": float,        # Target's new population
			"coherence_lost": float,        # How much coherence was decayed
			"message": String               # Status message
		}
	"""
	if not quantum_computer or not quantum_computer.density_matrix:
		return {
			"success": false,
			"message": "No quantum state available"
		}

	# Validate target emoji exists
	if not quantum_computer.register_map.has(target_emoji):
		return {
			"success": false,
			"message": "Target emoji '%s' not registered in this biome" % target_emoji
		}

	# Get current energy split
	var energy = quantum_computer.density_matrix.compute_energy_split()

	# Check minimum coherence
	if energy.imaginary < MIN_COHERENCE_THRESHOLD:
		return {
			"success": false,
			"extracted_amount": 0.0,
			"coherence_lost": 0.0,
			"message": "Insufficient quantum potential to extract (coherence = %.3f)" % energy.imaginary
		}

	# Clamp extraction fraction
	extraction_fraction = clamp(extraction_fraction, 0.0, 1.0)

	# Calculate extraction amount
	var extract_amount = energy.imaginary * extraction_fraction * EXTRACTION_EFFICIENCY

	# Apply extraction
	var result = _apply_extraction(quantum_computer, target_emoji, extract_amount, extraction_fraction)

	return {
		"success": true,
		"extracted_amount": extract_amount,
		"new_population": result.new_population,
		"coherence_lost": result.coherence_lost,
		"message": "⚡ Extracted %.3f quantum potential → %s" % [extract_amount, target_emoji]
	}


static func get_energy_status(quantum_computer) -> Dictionary:
	"""Get current energy split without modifying state

	Args:
		quantum_computer: QuantumComputer to inspect

	Returns:
		{
			"real": float,
			"imaginary": float,
			"total": float,
			"coherence_ratio": float,
			"extractable": float,      # How much could be extracted
			"regime": String           # "high_coherence", "balanced", "mostly_classical"
		}
	"""
	if not quantum_computer or not quantum_computer.density_matrix:
		return {
			"real": 0.0,
			"imaginary": 0.0,
			"total": 0.0,
			"coherence_ratio": 0.0,
			"extractable": 0.0,
			"regime": "no_state"
		}

	var energy = quantum_computer.density_matrix.compute_energy_split()

	# Determine regime
	var regime = "balanced"
	if energy.coherence_ratio > 0.4:
		regime = "high_coherence"
	elif energy.coherence_ratio < 0.1:
		regime = "mostly_classical"

	return {
		"real": energy.real,
		"imaginary": energy.imaginary,
		"total": energy.total,
		"coherence_ratio": energy.coherence_ratio,
		"extractable": energy.imaginary * EXTRACTION_EFFICIENCY,
		"regime": regime
	}


static func get_regime_description(regime: String) -> String:
	"""Get human-readable description of energy regime"""
	match regime:
		"high_coherence":
			return "⚡ High quantum potential - lots of extractable energy"
		"balanced":
			return "⚖️ Balanced - moderate extraction possible"
		"mostly_classical":
			return "📊 Mostly classical - limited extraction available"
		"no_state":
			return "❌ No quantum state"
		_:
			return "Unknown regime"


static func get_regime_color(regime: String) -> Color:
	"""Get color for regime visualization"""
	match regime:
		"high_coherence":
			return Color.CYAN
		"balanced":
			return Color.MEDIUM_PURPLE
		"mostly_classical":
			return Color.ORANGE
		"no_state":
			return Color.GRAY
		_:
			return Color.WHITE


## ========================================
## Internal Implementation
## ========================================

static func _apply_extraction(quantum_computer, target_emoji: String, amount: float, fraction: float) -> Dictionary:
	"""Apply extraction: dephase + inject population"""

	var density_matrix = quantum_computer.density_matrix
	var dim = density_matrix.n

	# Step 1: Get target qubit info
	var target_qubit = quantum_computer.register_map.qubit(target_emoji)
	var target_pole = quantum_computer.register_map.pole(target_emoji)

	# Step 2: Apply dephasing (reduce off-diagonal coherences)
	var dephasing_strength = fraction * DECOHERENCE_RATE
	var decay_factor = exp(-dephasing_strength)

	var coherence_lost = 0.0
	for i in range(dim):
		for j in range(i + 1, dim):
			var old_coherence = density_matrix.get_element(i, j)
			var new_coherence = Complex.new(
				old_coherence.re * decay_factor,
				old_coherence.im * decay_factor
			)

			# Track coherence loss
			coherence_lost += (old_coherence.abs() - new_coherence.abs()) * 2.0

			# Update both symmetric elements
			density_matrix.set_element(i, j, new_coherence)
			density_matrix.set_element(j, i, new_coherence.conjugate())

	# Step 3: Inject population into target
	# Find basis states where target_qubit = target_pole
	var num_qubits = quantum_computer.register_map.num_qubits
	var shift = num_qubits - 1 - target_qubit

	var injection_per_state = amount / _count_matching_states(dim, shift, target_pole)

	for i in range(dim):
		if ((i >> shift) & 1) == target_pole:
			var current_pop = density_matrix.get_element(i, i).re
			var new_pop = current_pop + injection_per_state
			density_matrix.set_element(i, i, Complex.new(new_pop, 0.0))

	# Step 4: Renormalize to maintain Tr(ρ) = 1
	_renormalize_density_matrix(density_matrix)

	# Get new population for target
	var new_population = quantum_computer.get_population(target_emoji)

	return {
		"new_population": new_population,
		"coherence_lost": coherence_lost
	}


static func _count_matching_states(dim: int, shift: int, target_pole: int) -> int:
	"""Count basis states where qubit at shift position equals target_pole"""
	var count = 0
	for i in range(dim):
		if ((i >> shift) & 1) == target_pole:
			count += 1
	return max(1, count)  # Avoid divide by zero


static func _renormalize_density_matrix(density_matrix) -> void:
	"""Ensure Tr(ρ) = 1 after modification"""
	var trace = 0.0
	var dim = density_matrix.n

	for i in range(dim):
		trace += density_matrix.get_element(i, i).re

	if abs(trace) < 1e-10:
		# Trace collapsed - recover by reinitializing to maximally mixed state
		push_warning("⚠️ SparkConverter: Trace collapsed, reinitializing to mixed state")
		var diag_val = 1.0 / float(dim)
		for i in range(dim):
			for j in range(dim):
				if i == j:
					density_matrix.set_element(i, j, Complex.new(diag_val, 0.0))
				else:
					density_matrix.set_element(i, j, Complex.zero())
		return

	if abs(trace - 1.0) > 1e-6:
		# Normalize
		var scale_factor = 1.0 / trace
		for i in range(dim):
			for j in range(dim):
				var old_val = density_matrix.get_element(i, j)
				density_matrix.set_element(i, j, Complex.new(
					old_val.re * scale_factor,
					old_val.im * scale_factor
				))
