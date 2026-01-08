class_name HamiltonianBuilder
extends RefCounted

## Build Hamiltonian from Icons, filtered by RegisterMap
##
## Icons define GLOBAL physics: {emoji: {target_emoji: Complex}}
## RegisterMap defines LOCAL coordinates: {emoji: {qubit, pole}}
## Only couplings where BOTH emojis have coordinates are included.
##
## This allows the same Icon definitions to be reused across biomes
## with different register configurations.

const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const RegisterMap = preload("res://Core/QuantumSubstrate/RegisterMap.gd")


static func build(icons: Dictionary, register_map: RegisterMap) -> ComplexMatrix:
	"""Build Hamiltonian matrix from Icons dictionary.

	Args:
	    icons: Dictionary[emoji] → Icon (containing hamiltonian_couplings)
	    register_map: This biome's RegisterMap

	Returns:
	    Hermitian matrix H of dimension 2^(num_qubits)
	"""
	var dim = register_map.dim()
	var num_qubits = register_map.num_qubits
	var H = ComplexMatrix.zeros(dim)

	print("🔨 Building Hamiltonian: %d qubits (%dD)..." % [num_qubits, dim])

	for source_emoji in icons:
		var icon = icons[source_emoji]

		# Skip if source not in this biome
		if not register_map.has(source_emoji):
			continue

		var source_q = register_map.qubit(source_emoji)
		var source_p = register_map.pole(source_emoji)

		# --- Self-energy: diagonal term ---
		# Icon.self_energy is a float, convert to Complex for matrix operations
		if icon.self_energy != null and abs(icon.self_energy) > 1e-10:
			var energy_complex = Complex.new(icon.self_energy, 0.0)
			_add_self_energy(H, source_q, source_p, energy_complex, num_qubits)
			print("  ✓ %s self-energy: %.3f" % [source_emoji, icon.self_energy])

		# --- Couplings: emoji → float (coupling strength) ---
		if icon.hamiltonian_couplings:
			for target_emoji in icon.hamiltonian_couplings:
				# Filter: skip if target not in this biome
				if not register_map.has(target_emoji):
					print("  ⚠️ %s→%s skipped (no coordinate)" % [source_emoji, target_emoji])
					continue

				var target_q = register_map.qubit(target_emoji)
				var target_p = register_map.pole(target_emoji)
				var strength = icon.hamiltonian_couplings[target_emoji]
				# Convert float to Complex for matrix operations
				var coupling = Complex.new(strength, 0.0) if strength is float else strength

				_add_coupling(H, source_q, source_p, target_q, target_p, coupling, num_qubits)

				print("  ✓ %s→%s coupling: %.3f" % [source_emoji, target_emoji, strength])

	# Ensure Hermiticity: H = (H + H†)/2
	H = _hermitianize(H)

	print("🔨 Hamiltonian built: %dx%d" % [dim, dim])
	return H


static func _add_self_energy(H: ComplexMatrix, qubit: int, pole: int,
							  energy: Complex, num_qubits: int) -> void:
	"""Add diagonal term for states where qubit is in pole state.

	For each basis state |i⟩ where qubit = pole, add energy to H[i,i].
	"""
	var dim = 1 << num_qubits
	var shift = num_qubits - 1 - qubit

	for i in range(dim):
		# Check if qubit at position 'qubit' has bit value 'pole'
		if ((i >> shift) & 1) == pole:
			var current = H.get_element(i, i)
			H.set_element(i, i, current.add(energy))


static func _add_coupling(H: ComplexMatrix,
						   q_a: int, p_a: int,
						   q_b: int, p_b: int,
						   coupling: Complex, num_qubits: int) -> void:
	"""Add off-diagonal coupling between two qubit-pole pairs.

	Cases:
	    - Same qubit, different poles: σ_x rotation (|0⟩↔|1⟩)
	    - Different qubits: Conditional transition (correlated flip)
	"""
	var dim = 1 << num_qubits

	if q_a == q_b:
		# Same qubit: σ_x rotation (|0⟩↔|1⟩)
		if p_a == p_b:
			# Self-coupling should be handled by self_energy
			return

		var shift = num_qubits - 1 - q_a
		for i in range(dim):
			# Check if qubit is in pole p_a
			if ((i >> shift) & 1) == p_a:
				var j = i ^ (1 << shift)  # Flip bit
				var current = H.get_element(i, j)
				H.set_element(i, j, current.add(coupling))
	else:
		# Different qubits: conditional transition
		# Flip both qubits if both match source poles
		var shift_a = num_qubits - 1 - q_a
		var shift_b = num_qubits - 1 - q_b

		for i in range(dim):
			var bit_a = (i >> shift_a) & 1
			var bit_b = (i >> shift_b) & 1

			# Both qubits must match source poles
			if bit_a == p_a and bit_b == p_b:
				var j = i ^ (1 << shift_a) ^ (1 << shift_b)
				var current = H.get_element(i, j)
				H.set_element(i, j, current.add(coupling))


static func _hermitianize(H: ComplexMatrix) -> ComplexMatrix:
	"""Return (H + H†)/2 to ensure Hermiticity.

	This corrects any numerical errors from asymmetric coupling additions.
	"""
	var H_dag = H.conjugate_transpose()
	return H.add(H_dag).scale_real(0.5)
