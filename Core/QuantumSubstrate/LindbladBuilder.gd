class_name LindbladBuilder
extends RefCounted

## Build Lindblad operators from Icons, filtered by RegisterMap
##
## Lindblad operators: L_k = amplitude * |target⟩⟨source|
## where amplitude = √rate (Complex number)
##
## Icons define couplings: {target_emoji: Complex}
## RegisterMap filters: only include if both emojis have coordinates

const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const RegisterMap = preload("res://Core/QuantumSubstrate/RegisterMap.gd")


static func build(icons: Dictionary, register_map: RegisterMap) -> Dictionary:
	"""Build Lindblad operators and gated configs from Icons dictionary.

	Args:
	    icons: Dictionary[emoji] → Icon (containing lindblad couplings)
	    register_map: This biome's RegisterMap

	Returns:
	    Dictionary with:
	        "operators": Array of L_k matrices (each is dim×dim ComplexMatrix)
	        "gated_configs": Array of gated Lindblad configurations
	            Format: [{target_emoji, source_emoji, rate, gate, power}]
	"""
	var operators: Array = []
	var gated_configs: Array = []
	var dim = register_map.dim()
	var num_qubits = register_map.num_qubits

	print("🔨 Building Lindblad operators: %d qubits (%dD)..." % [num_qubits, dim])

	for source_emoji in icons:
		var icon = icons[source_emoji]

		# Skip if source not in this biome
		if not register_map.has(source_emoji):
			continue

		var source_q = register_map.qubit(source_emoji)
		var source_p = register_map.pole(source_emoji)

		# --- Outgoing Lindblad: source loses amplitude to target ---
		# lindblad_outgoing: {target_emoji: rate (float)}
		if icon.lindblad_outgoing:
			for target_emoji in icon.lindblad_outgoing:
				# Filter: skip if target not in this biome
				if not register_map.has(target_emoji):
					print("  ⚠️ L %s→%s skipped (no coordinate)" % [source_emoji, target_emoji])
					continue

				var target_q = register_map.qubit(target_emoji)
				var target_p = register_map.pole(target_emoji)
				var rate = icon.lindblad_outgoing[target_emoji]
				# Convert rate to amplitude: √γ
				var amplitude = Complex.new(sqrt(abs(rate)), 0.0)

				# Operator L = √γ |target⟩⟨source| (population flows from source to target)
				var L = _build_jump(source_q, source_p, target_q, target_p,
									amplitude, num_qubits)
				operators.append(L)

				print("  ✓ L %s→%s (γ=%.3f)" % [source_emoji, target_emoji, rate])

		# --- Incoming Lindblad: target gains amplitude from source ---
		# lindblad_incoming: {source_emoji: rate (float)}
		if icon.lindblad_incoming:
			for from_emoji in icon.lindblad_incoming:
				# Filter: skip if source not in this biome
				if not register_map.has(from_emoji):
					print("  ⚠️ L %s→%s skipped (no coordinate)" % [from_emoji, source_emoji])
					continue

				var from_q = register_map.qubit(from_emoji)
				var from_p = register_map.pole(from_emoji)
				var rate = icon.lindblad_incoming[from_emoji]
				# Convert rate to amplitude: √γ
				var amplitude = Complex.new(sqrt(abs(rate)), 0.0)

				# Operator L = √γ |source⟩⟨from| (population flows INTO source)
				var L = _build_jump(from_q, from_p, source_q, source_p,
									amplitude, num_qubits)
				operators.append(L)

				print("  ✓ L %s→%s (γ=%.3f)" % [from_emoji, source_emoji, rate])

		# --- Gated Lindblad: extract configs for runtime evaluation ---
		# Format from IconBuilder: [{source, rate, gate, power, faction}]
		if icon.has_meta("gated_lindblad"):
			var gated_list = icon.get_meta("gated_lindblad")
			for g in gated_list:
				var source_e: String = g.get("source", "")
				var gate_e: String = g.get("gate", "")
				var rate: float = g.get("rate", 0.0)
				var power: float = g.get("power", 1.0)

				# Filter: skip if source or gate not in this biome
				if not register_map.has(source_e):
					print("  ⚠️ Gated L %s→%s skipped (source %s not in biome)" % [source_e, source_emoji, source_e])
					continue
				if not register_map.has(gate_e):
					print("  ⚠️ Gated L %s→%s skipped (gate %s not in biome)" % [source_e, source_emoji, gate_e])
					continue

				# Store config for runtime evaluation
				gated_configs.append({
					"target_emoji": source_emoji,  # Icon emoji is the target
					"source_emoji": source_e,
					"rate": rate,
					"gate": gate_e,
					"power": power,
				})
				print("  ✓ Gated L %s→%s (γ=%.3f × P(%s)^%.1f)" % [
					source_e, source_emoji, rate, gate_e, power])

	print("🔨 Built %d Lindblad operators + %d gated configs" % [operators.size(), gated_configs.size()])
	return {"operators": operators, "gated_configs": gated_configs}


static func _build_jump(from_q: int, from_p: int, to_q: int, to_p: int,
						amplitude: Complex, num_qubits: int) -> ComplexMatrix:
	"""Build jump operator L = amplitude * |to⟩⟨from|.

	Cases:
	    - Same qubit: flip pole (|0⟩→|1⟩ or |1⟩→|0⟩)
	    - Different qubits: correlated transfer (flip both)
	"""
	var dim = 1 << num_qubits
	var L = ComplexMatrix.zeros(dim)

	if from_q == to_q:
		# Same qubit: flip pole
		var shift = num_qubits - 1 - from_q

		for i in range(dim):
			# Check if qubit is in 'from' pole
			if ((i >> shift) & 1) == from_p:
				var j = i ^ (1 << shift)  # Flip bit
				L.set_element(j, i, amplitude)
	else:
		# Different qubits: correlated transfer
		# If from_q is in from_p AND to_q is NOT in to_p, flip both
		var shift_from = num_qubits - 1 - from_q
		var shift_to = num_qubits - 1 - to_q

		for i in range(dim):
			var bit_from = (i >> shift_from) & 1
			var bit_to = (i >> shift_to) & 1

			# Source qubit must be in from_p
			# Target qubit must NOT already be in to_p (room to transfer)
			if bit_from == from_p and bit_to != to_p:
				var j = i ^ (1 << shift_from) ^ (1 << shift_to)
				L.set_element(j, i, amplitude)

	return L
