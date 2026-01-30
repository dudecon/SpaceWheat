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


static func build(icons: Dictionary, register_map: RegisterMap, verbose = null, time: float = 0.0) -> ComplexMatrix:
	"""Build Hamiltonian matrix from Icons dictionary.

	Args:
	    icons: Dictionary[emoji] → Icon (containing hamiltonian_couplings)
	    register_map: This biome's RegisterMap
	    verbose: Optional VerboseConfig for logging (default: print to console)
	    time: Current simulation time for time-dependent drivers (default: 0.0)

	Returns:
	    Hermitian matrix H of dimension 2^(num_qubits)
	"""
	var dim = register_map.dim()
	var num_qubits = register_map.num_qubits
	var H = ComplexMatrix.zeros(dim)

	# Statistics tracking
	var stats = {
		"self_energies_added": 0,
		"couplings_added": 0,
		"couplings_skipped": 0
	}

	if verbose:
		verbose.info("quantum", "🔨", "Building Hamiltonian: %d qubits (%dD)" % [num_qubits, dim])
	else:
		print("🔨 Building Hamiltonian: %d qubits (%dD)..." % [num_qubits, dim])

	for source_emoji in icons:
		var icon = icons[source_emoji]

		# Skip if source not in this biome
		if not register_map.has(source_emoji):
			continue

		var source_q = register_map.qubit(source_emoji)
		var source_p = register_map.pole(source_emoji)

		# --- Self-energy: diagonal term ---
		# Use time-dependent get_self_energy(time) to support driver oscillations
		var energy = icon.get_self_energy(time)
		if abs(energy) > 1e-10:
			var energy_complex = Complex.new(energy, 0.0)
			_add_self_energy(H, source_q, source_p, energy_complex, num_qubits)
			stats.self_energies_added += 1
			if verbose:
				verbose.debug("quantum-build", "✓", "%s self-energy: %.3f" % [source_emoji, energy])
			else:
				print("  ✓ %s self-energy: %.3f" % [source_emoji, energy])

		# --- Couplings: emoji → float (coupling strength) ---
		if icon.hamiltonian_couplings:
			for target_emoji in icon.hamiltonian_couplings:
				# Filter: skip if target not in this biome
				if not register_map.has(target_emoji):
					stats.couplings_skipped += 1
					if verbose:
						verbose.debug("quantum-build", "⚠️", "%s→%s skipped (no coordinate)" % [source_emoji, target_emoji])
					continue

				var target_q = register_map.qubit(target_emoji)
				var target_p = register_map.pole(target_emoji)
				var strength = icon.hamiltonian_couplings[target_emoji]

				# Convert to Complex for matrix operations
				# strength can be: float (real), Vector2 (complex: x=real, y=imag), or Complex
				var coupling: Complex
				if strength is float:
					coupling = Complex.new(strength, 0.0)
				elif strength is Vector2:
					coupling = Complex.new(strength.x, strength.y)
				elif strength is Complex:
					coupling = strength
				else:
					push_warning("HamiltonianBuilder: unexpected coupling type: %s" % typeof(strength))
					continue

				_add_coupling(H, source_q, source_p, target_q, target_p, coupling, num_qubits)
				stats.couplings_added += 1

				var strength_label = _format_strength_label(strength)
				if verbose:
					verbose.debug("quantum-build", "✓", "%s→%s coupling: %s" % [source_emoji, target_emoji, strength_label])
				else:
					print("  ✓ %s→%s coupling: %s" % [source_emoji, target_emoji, strength_label])

	# Ensure Hermiticity: H = (H + H†)/2
	H = _hermitianize(H)

	# Print summary
	if verbose:
		verbose.info("quantum", "✅",
			"Hamiltonian built: %dx%d | Added: %d self-energies + %d couplings | Skipped: %d couplings" % [
				dim, dim,
				stats.self_energies_added,
				stats.couplings_added,
				stats.couplings_skipped
			])
	else:
		print("🔨 Hamiltonian built: %dx%d (added: %d self-energies + %d couplings, skipped: %d)" % [
			dim, dim,
			stats.self_energies_added,
			stats.couplings_added,
			stats.couplings_skipped
		])

	return H


static func _format_strength_label(strength) -> String:
	"""Format coupling strength for logs (supports float, Vector2, Complex)."""
	if strength is float or strength is int:
		return "%.3f" % float(strength)
	if strength is Vector2:
		var re = float(strength.x)
		var im = float(strength.y)
		return "%.3f%+.3fi" % [re, im]
	if strength is Complex:
		return "%.3f%+.3fi" % [strength.re, strength.im]
	return str(strength)


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


static func get_driven_icons(icons: Dictionary, register_map: RegisterMap) -> Array:
	"""Extract icons with time-dependent drivers for efficient updates.

	Returns an array of dictionaries with the info needed to update
	Hamiltonian diagonal terms without full rebuild:
	[{emoji, qubit, pole, icon_ref, driver_type, base_energy}, ...]

	This enables efficient time-dependent evolution by updating only
	the driven diagonal terms instead of rebuilding the full Hamiltonian.
	"""
	var driven = []

	for source_emoji in icons:
		var icon = icons[source_emoji]

		# Skip if source not in this biome
		if not register_map.has(source_emoji):
			continue

		# Check if this icon has a time-dependent driver
		if icon.self_energy_driver == "" or icon.self_energy_driver == null:
			continue

		# This icon has a driver - store its config
		driven.append({
			"emoji": source_emoji,
			"qubit": register_map.qubit(source_emoji),
			"pole": register_map.pole(source_emoji),
			"icon_ref": icon,  # Reference to Icon for get_self_energy(time)
			"driver_type": icon.self_energy_driver,
			"base_energy": icon.self_energy
		})

	return driven
