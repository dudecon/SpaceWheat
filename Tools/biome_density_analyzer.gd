extends Node

## Biome Density Analyzer - Extract icon densities and purity from running game
##
## Add this to the scene tree during runtime and call analyze_all_biomes()

signal analysis_complete(results: Dictionary)

var results: Dictionary = {}

func analyze_all_biomes() -> void:
	"""Analyze all loaded biomes in the current game."""
	print("=== Biome Density Analysis ===")
	print("")

	var farm = get_node_or_null("/root/Farm")
	if not farm:
		print("ERROR: No Farm node found")
		return

	if not farm.grid or not farm.grid.biomes:
		print("ERROR: No biomes loaded")
		return

	print("Found " + str(farm.grid.biomes.size()) + " loaded biomes")
	print("")

	# Access batcher to get viz data
	var batcher = farm.biome_evolution_batcher
	if not batcher:
		print("ERROR: No BiomeEvolutionBatcher found")
		return

	# Analyze each biome
	for biome_name in farm.grid.biomes.keys():
		var biome = farm.grid.biomes[biome_name]
		if not biome:
			continue

		print("--- Analyzing: %s ---" % biome_name)
		var result = _analyze_biome(biome_name, biome, batcher)
		results[biome_name] = result
		print("")

	# Print summary
	_print_summary()

	analysis_complete.emit(results)


func _analyze_biome(biome_name: String, biome, batcher) -> Dictionary:
	"""Extract density and purity data from a biome using C++ eigenstate solver."""

	if not biome.quantum_computer:
		print("  ERROR: No quantum computer")
		return {"error": "no_qc"}

	var qc = biome.quantum_computer
	print("  Dimension: %d, Qubits: %d" % [qc.register_map.dim(), qc.register_map.num_qubits])

	# Get packed density matrix
	var rho_packed = qc.density_matrix._to_packed()

	# Use C++ native engine for eigenstate analysis
	var purity = 0.0
	var eigenstate = PackedFloat64Array()
	var eigenvalues = PackedFloat64Array()
	var dominant_eigenvalue = 0.0

	if qc.native_engine and qc.native_engine.has_method("compute_eigenstates"):
		# Use NEW C++ eigenstate solver
		var eigen_result = qc.native_engine.compute_eigenstates(rho_packed)

		if eigen_result.has("error"):
			print("  WARNING: Eigenstate computation failed: %s" % eigen_result["error"])
		else:
			eigenstate = eigen_result.get("dominant_eigenvector", PackedFloat64Array())
			eigenvalues = eigen_result.get("eigenvalues", PackedFloat64Array())
			dominant_eigenvalue = eigen_result.get("dominant_eigenvalue", 0.0)
			print("  Dominant eigenvalue: %.6f" % dominant_eigenvalue)

			# Print top 3 eigenvalues
			if eigenvalues.size() >= 3:
				print("  Top eigenvalues: %.4f, %.4f, %.4f" % [eigenvalues[0], eigenvalues[1], eigenvalues[2]])

		# Get purity
		purity = qc.native_engine.compute_purity_from_packed(rho_packed) if qc.native_engine.has_method("compute_purity_from_packed") else 0.0
	else:
		print("  WARNING: Native engine not available, using fallback")
		eigenstate = _extract_dominant_eigenstate_fallback(rho_packed, qc.register_map.dim())

	print("  Current purity: %.4f" % purity)

	# Extract current densities from density matrix
	var densities = _extract_densities_from_qc(qc)
	var total_density = 0.0
	for emoji in densities:
		total_density += densities[emoji]

	print("  Total icons tracked: %d" % densities.size())
	print("  Top 5 densities:")
	var sorted_emojis = densities.keys()
	sorted_emojis.sort_custom(func(a, b): return densities[a] > densities[b])
	for i in range(min(5, sorted_emojis.size())):
		var emoji = sorted_emojis[i]
		print("    %s: %.4f" % [emoji, densities[emoji]])

	# Check if batcher has icon_map data
	var icon_map_total = 0.0
	var icon_map_steps = 0
	if batcher.icon_map_payloads.has(biome_name):
		var icon_map = batcher.icon_map_payloads[biome_name]
		icon_map_total = icon_map.get("total", 0.0)
		icon_map_steps = icon_map.get("steps", 0)
		if icon_map_steps > 0:
			print("  Icon map accumulated over %d steps, total=%.2f" % [icon_map_steps, icon_map_total])

	return {
		"success": true,
		"purity": purity,
		"density_map": densities,
		"total_density": total_density,
		"num_icons": densities.size(),
		"eigenstate": eigenstate,
		"eigenvalues": eigenvalues,
		"dominant_eigenvalue": dominant_eigenvalue,
		"dim": qc.register_map.dim(),
		"icon_map_total": icon_map_total,
		"icon_map_steps": icon_map_steps
	}


func _extract_densities_from_qc(qc) -> Dictionary:
	"""Extract emoji densities from quantum computer's current state."""
	var densities: Dictionary = {}
	var rho_packed = qc.density_matrix._to_packed()
	var dim = qc.register_map.dim()

	for i in range(dim):
		var density = rho_packed[i * 2 * dim + i * 2]  # Real part of diagonal

		# Map computational basis state to emoji(s)
		var state_emojis = qc.register_map.get_emojis_for_state(i)
		for emoji in state_emojis:
			if not densities.has(emoji):
				densities[emoji] = 0.0
			densities[emoji] += density

	return densities


func _extract_dominant_eigenstate_fallback(rho_packed: PackedFloat64Array, dim: int) -> PackedFloat64Array:
	"""Fallback: Extract diagonal (populations) as eigenstate approximation."""
	var eigenstate = PackedFloat64Array()
	eigenstate.resize(dim * 2)  # Complex: [re0, im0, re1, im1, ...]

	# Extract diagonal (populations) as approximation
	for i in range(dim):
		eigenstate[i * 2] = rho_packed[i * 2 * dim + i * 2]  # Real part of diagonal
		eigenstate[i * 2 + 1] = 0.0  # Imaginary part

	# Normalize
	var norm_sq = 0.0
	for i in range(dim):
		var re = eigenstate[i * 2]
		var im = eigenstate[i * 2 + 1]
		norm_sq += re * re + im * im
	var norm = sqrt(norm_sq)

	if norm > 0:
		for i in range(dim * 2):
			eigenstate[i] /= norm

	return eigenstate


func _compute_cos2_similarity(state_a: PackedFloat64Array, state_b: PackedFloat64Array) -> float:
	"""Compute cos²(θ) similarity between two complex state vectors.
	States packed as [re0, im0, re1, im1, ...]
	"""
	if state_a.size() != state_b.size() or state_a.is_empty():
		return 0.0

	var dim = state_a.size() / 2

	# Compute complex inner product ⟨a|b⟩ = Σ conj(a_i) * b_i
	var inner_re = 0.0
	var inner_im = 0.0
	for i in range(dim):
		var a_re = state_a[i * 2]
		var a_im = state_a[i * 2 + 1]
		var b_re = state_b[i * 2]
		var b_im = state_b[i * 2 + 1]
		# conj(a) * b = (a_re - i*a_im) * (b_re + i*b_im)
		inner_re += a_re * b_re + a_im * b_im
		inner_im += a_re * b_im - a_im * b_re

	# |⟨a|b⟩|²
	return inner_re * inner_re + inner_im * inner_im


func _print_summary():
	"""Print summary table of all biomes."""
	print("")
	print("=== SUMMARY ===")
	print("")
	print("%-20s | %8s | %8s | %8s" % ["Biome", "Purity", "Icons", "Total"])
	var sep = ""
	for i in range(60):
		sep += "-"
	print(sep)

	var successful_biomes: Array = []
	for biome_name in results.keys():
		var result = results[biome_name]
		if result.get("error"):
			print("%-20s | ERROR: %s" % [biome_name, result["error"]])
			continue

		print("%-20s | %8.4f | %8d | %8.2f" % [
			biome_name,
			result.get("purity", 0.0),
			result.get("num_icons", 0),
			result.get("total_density", 0.0)
		])

		if result.has("eigenstate"):
			successful_biomes.append(biome_name)

	# Print eigenstate similarity matrix (cos² between all biome pairs)
	if successful_biomes.size() > 1:
		print("")
		print("=== EIGENSTATE SIMILARITY (cos²) ===")
		print("")
		print("Comparing eigenstates (1.0 = identical, 0.0 = orthogonal)")
		print("")

		# Try to use C++ similarity computation if available
		var use_native = false
		var native_engine = null

		# Get native engine from first biome
		var farm = get_node_or_null("/root/Farm")
		if farm and farm.grid and farm.grid.biomes:
			for biome_name in farm.grid.biomes.keys():
				var biome = farm.grid.biomes[biome_name]
				if biome and biome.quantum_computer and biome.quantum_computer.native_engine:
					native_engine = biome.quantum_computer.native_engine
					if native_engine.has_method("compute_cos2_similarity"):
						use_native = true
					break

		if use_native:
			print("(Using C++ eigenstate solver)")
		else:
			print("(Using GDScript fallback)")
		print("")

		# Header
		var header = "%-20s" % ""
		for name in successful_biomes:
			header += " | %6s" % name.substr(0, 6)
		print(header)

		var header_sep = ""
		for i in range(20 + successful_biomes.size() * 9):
			header_sep += "-"
		print(header_sep)

		# Matrix
		for i in range(successful_biomes.size()):
			var row_name = successful_biomes[i]
			var state_i = results[row_name]["eigenstate"]
			var row = "%-20s" % row_name

			for j in range(successful_biomes.size()):
				var col_name = successful_biomes[j]
				var state_j = results[col_name]["eigenstate"]

				var similarity = 0.0
				if use_native and native_engine:
					similarity = native_engine.compute_cos2_similarity(state_i, state_j)
				else:
					similarity = _compute_cos2_similarity(state_i, state_j)
				row += " | %6.3f" % similarity

			print(row)

	print("")
	print("=== Analysis Complete ===")
