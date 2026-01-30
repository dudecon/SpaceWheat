extends SceneTree

## Analyze Biome Densities - Run C++ sims and aggregate icon densities + purity
##
## Usage: godot --headless --script analyze_biome_densities.gd

var results: Dictionary = {}  # biome_name -> {density_map, purity, total_density}

func _initialize():
	print("=== Biome Density Analysis ===")
	print("")

	# Get biome list from JSON
	var biome_data = _load_biome_json()
	if biome_data.is_empty():
		print("ERROR: No biomes found in biomes_merged.json")
		quit(1)
		return

	print("Found " + str(biome_data.size()) + " biomes in biomes_merged.json")
	print("")

	# Process each biome
	for biome_json in biome_data:
		var biome_name = biome_json.get("name", "")
		if biome_name.is_empty():
			continue

		print("--- Processing: %s ---" % biome_name)
		var result = _analyze_biome(biome_name, biome_json)
		results[biome_name] = result
		print("")

	# Print summary
	_print_summary()

	quit(0)


func _load_biome_json() -> Array:
	"""Load biomes_merged.json"""
	var path = "res://Core/Biomes/data/biomes_merged.json"
	if not FileAccess.file_exists(path):
		return []

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return []

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(text)
	if error != OK:
		print("ERROR parsing JSON: %s" % json.get_error_message())
		return []

	return json.data if json.data is Array else []


func _analyze_biome(biome_name: String, biome_json: Dictionary) -> Dictionary:
	"""Run simulation on a single biome and extract density + purity."""

	# Load biome script
	var biome = _load_biome_instance(biome_name)
	if not biome:
		print("  ERROR: Failed to load biome")
		return {"error": "load_failed"}

	# Check quantum computer
	if not biome.quantum_computer:
		print("  ERROR: No quantum computer")
		return {"error": "no_qc"}

	var qc = biome.quantum_computer
	print("  Dimension: %d, Qubits: %d" % [qc.register_map.dim(), qc.register_map.num_qubits])

	# Check if native engine available
	if not ClassDB.class_exists("QuantumEvolutionEngine"):
		print("  ERROR: QuantumEvolutionEngine not available (C++ not built?)")
		return {"error": "no_native"}

	# Get native engine from quantum computer
	var engine = qc.native_engine
	if not engine or not engine.is_finalized():
		print("  WARNING: Native engine not finalized, trying to finalize...")
		if engine:
			engine.finalize()
		else:
			print("  ERROR: No native engine")
			return {"error": "no_engine"}

	# Run evolution for several steps to accumulate density
	var dt = 0.1
	var max_dt = 0.02
	var num_steps = 50  # 5 seconds of simulation
	var num_qubits = qc.register_map.num_qubits

	print("  Running %d evolution steps (%.1fs total)..." % [num_steps, num_steps * dt])

	# Accumulate icon densities
	var icon_map: Dictionary = {}  # emoji -> cumulative probability
	var total_density: float = 0.0
	var final_purity: float = 0.0
	var rho_packed = qc.density_matrix._to_packed()

	for step in range(num_steps):
		# Evolve one step with MI computation
		var result = engine.evolve_with_mi(rho_packed, dt, max_dt, num_qubits)

		if not result or not result.has("rho"):
			print("  ERROR at step %d: Evolution failed" % step)
			break

		rho_packed = result["rho"]
		var purity = result.get("purity", 0.0)
		final_purity = purity

		# Extract densities from density matrix
		var densities = _extract_densities(rho_packed, qc.register_map)

		# Accumulate
		for emoji in densities:
			if not icon_map.has(emoji):
				icon_map[emoji] = 0.0
			icon_map[emoji] += densities[emoji]
			total_density += densities[emoji]

		if step % 10 == 0:
			print("    Step %d: purity=%.4f" % [step, purity])

	# Normalize icon map
	var normalized_map: Dictionary = {}
	if total_density > 0:
		for emoji in icon_map:
			normalized_map[emoji] = icon_map[emoji] / num_steps

	print("  Final purity: %.4f" % final_purity)
	print("  Total icons tracked: %d" % normalized_map.size())
	print("  Top 5 densities:")
	var sorted_emojis = normalized_map.keys()
	sorted_emojis.sort_custom(func(a, b): return normalized_map[a] > normalized_map[b])
	for i in range(min(5, sorted_emojis.size())):
		var emoji = sorted_emojis[i]
		print("    %s: %.4f" % [emoji, normalized_map[emoji]])

	# Extract eigenstate (dominant eigenvector of final density matrix)
	var eigenstate = _extract_dominant_eigenstate(rho_packed, qc.register_map.dim())

	return {
		"success": true,
		"purity": final_purity,
		"density_map": normalized_map,
		"total_density": total_density,
		"num_icons": normalized_map.size(),
		"num_steps": num_steps,
		"eigenstate": eigenstate,  # Dominant eigenvector for cos² comparison
		"dim": qc.register_map.dim()
	}


func _load_biome_instance(biome_name: String):
	"""Load and instantiate a biome by name."""
	var script_map = {
		"StarterForest": "res://Core/Environment/StarterForestBiome.gd",
		"Village": "res://Core/Environment/VillageBiome.gd",
		"BioticFlux": "res://Core/Environment/BioticFluxBiome.gd",
		"StellarForges": "res://Core/Environment/StellarForgesBiome.gd",
		"FungalNetworks": "res://Core/Environment/FungalNetworksBiome.gd",
		"VolcanicWorlds": "res://Core/Environment/VolcanicWorldsBiome.gd",
		# New biomes don't have scripts yet - skip them
		# "CyberDebtMegacity": "res://Core/Environment/CyberDebtMegacityBiome.gd",
		# "EchoingChasm": "res://Core/Environment/EchoingChasmBiome.gd",
		# "HorizonFracture": "res://Core/Environment/HorizonFractureBiome.gd",
	}

	var script_path = script_map.get(biome_name, "")
	if script_path.is_empty():
		print("  SKIP: No script path mapped for %s" % biome_name)
		return null

	if not ResourceLoader.exists(script_path):
		print("  SKIP: Script not found: %s" % script_path)
		return null

	var script = load(script_path)
	if not script:
		return null

	var biome = script.new()
	return biome


func _extract_densities(rho_packed: PackedFloat64Array, register_map) -> Dictionary:
	"""Extract emoji densities from packed density matrix."""
	var densities: Dictionary = {}

	# Get diagonal elements (populations)
	var dim = register_map.dim()

	for i in range(dim):
		var density = rho_packed[i * 2 * dim + i * 2]  # Real part of diagonal

		# Map computational basis state to emoji(s)
		var state_emojis = register_map.get_emojis_for_state(i)
		for emoji in state_emojis:
			if not densities.has(emoji):
				densities[emoji] = 0.0
			densities[emoji] += density

	return densities


func _extract_dominant_eigenstate(rho_packed: PackedFloat64Array, dim: int) -> PackedFloat64Array:
	"""Extract dominant eigenstate (eigenvector with largest eigenvalue).

	Note: This is a placeholder - proper eigenvalue decomposition should be done in C++.
	For now, just return the diagonal (populations) as a rough approximation.
	"""
	var eigenstate = PackedFloat64Array()
	eigenstate.resize(dim)

	# Extract diagonal (populations) as approximation
	for i in range(dim):
		eigenstate[i] = rho_packed[i * 2 * dim + i * 2]  # Real part of diagonal

	# Normalize
	var norm = 0.0
	for val in eigenstate:
		norm += val * val
	norm = sqrt(norm)

	if norm > 0:
		for i in range(dim):
			eigenstate[i] /= norm

	return eigenstate


func _compute_cos2_similarity(state_a: PackedFloat64Array, state_b: PackedFloat64Array) -> float:
	"""Compute cos²(θ) similarity between two states.

	cos²(θ) = |<a|b>|² measures quantum state overlap.
	Returns 1.0 for identical states, 0.0 for orthogonal states.
	"""
	if state_a.size() != state_b.size() or state_a.is_empty():
		return 0.0

	# Compute inner product <a|b>
	var inner_product = 0.0
	for i in range(state_a.size()):
		inner_product += state_a[i] * state_b[i]

	# Return |<a|b>|²
	return inner_product * inner_product


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
		print("Comparing dominant eigenstates across biomes (1.0 = identical, 0.0 = orthogonal)")
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
				var similarity = _compute_cos2_similarity(state_i, state_j)
				row += " | %6.3f" % similarity

			print(row)

	print("")
	print("=== Analysis Complete ===")
