extends SceneTree

## Music Eigenstate Analyzer - Compute biome similarity matrix for music selection
## Usage: godot --headless --script Tools/music_eigenstate_analyzer.gd

var biomes: Array = []
var all_emojis: Array = []  # Unified emoji index
var emoji_to_idx: Dictionary = {}  # emoji -> index in vector
var biome_vectors: Dictionary = {}  # biome_name -> PackedFloat64Array
var music_to_biome: Dictionary = {}  # track_key -> biome_name

func _initialize():
	print("=== Music Eigenstate Analyzer ===")
	print("")

	# Load biomes
	biomes = _load_biomes()
	if biomes.is_empty():
		print("ERROR: Failed to load biomes")
		quit(1)
		return

	print("Loaded %d biomes" % biomes.size())

	# Build unified emoji index
	_build_emoji_index()
	print("Unified emoji space: %d dimensions" % all_emojis.size())
	print("")

	# Create biome vectors
	_create_biome_vectors()

	# Map music to biomes (from MusicManager)
	_setup_music_mapping()

	# Compute and display similarity matrix
	_compute_similarity_matrix()

	# Show music track assignments
	_show_music_assignments()

	print("")
	print("=== Analysis Complete ===")
	quit(0)


func _load_biomes() -> Array:
	var path = "res://Core/Biomes/data/biomes_merged.json"
	if not FileAccess.file_exists(path):
		return []

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return []

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(text) != OK:
		return []

	return json.data if json.data is Array else []


func _build_emoji_index():
	"""Build unified emoji space from all biomes."""
	var emoji_set: Dictionary = {}

	for biome in biomes:
		var emojis = biome.get("emojis", [])
		for emoji in emojis:
			emoji_set[emoji] = true

		# Also include emojis from icon_components (they have weights!)
		var components = biome.get("icon_components", {})
		for emoji in components.keys():
			emoji_set[emoji] = true

	# Sort for consistent ordering
	all_emojis = emoji_set.keys()
	all_emojis.sort()

	# Build reverse mapping
	for i in range(all_emojis.size()):
		emoji_to_idx[all_emojis[i]] = i


func _create_biome_vectors():
	"""Create normalized vectors for each biome in emoji space."""
	print("=== BIOME VECTORS ===")
	print("")

	for biome in biomes:
		var name = biome.get("name", "Unknown")
		var emojis = biome.get("emojis", [])
		var components = biome.get("icon_components", {})

		# Create vector
		var vec = PackedFloat64Array()
		vec.resize(all_emojis.size())
		for i in range(vec.size()):
			vec[i] = 0.0

		# Method 1: Equal weight for all emojis in list
		for emoji in emojis:
			if emoji_to_idx.has(emoji):
				vec[emoji_to_idx[emoji]] = 1.0

		# Method 2: Use self_energy from icon_components as weight (if available)
		for emoji in components.keys():
			if emoji_to_idx.has(emoji):
				var comp = components[emoji]
				var weight = 1.0
				if comp is Dictionary and comp.has("self_energy"):
					weight = abs(float(comp["self_energy"])) + 0.1  # Add small base
				vec[emoji_to_idx[emoji]] = weight

		# Normalize
		var norm = 0.0
		for v in vec:
			norm += v * v
		norm = sqrt(norm)
		if norm > 0:
			for i in range(vec.size()):
				vec[i] /= norm

		biome_vectors[name] = vec

		# Print top emojis for this biome
		var emoji_weights: Array = []
		for i in range(vec.size()):
			if vec[i] > 0.01:
				emoji_weights.append({"emoji": all_emojis[i], "weight": vec[i]})
		emoji_weights.sort_custom(func(a, b): return a["weight"] > b["weight"])

		var top_str = ""
		for j in range(min(6, emoji_weights.size())):
			top_str += "%s:%.2f " % [emoji_weights[j]["emoji"], emoji_weights[j]["weight"]]

		print("%-20s | %s" % [name, top_str])

	print("")


func _setup_music_mapping():
	"""Map music track keys to their associated biomes."""
	# From MusicManager BIOME_TRACKS (keep in sync!)
	music_to_biome = {
		"quantum_harvest": "BioticFlux",
		"black_horizon": "StellarForges",
		"fungal_lattice": "FungalNetworks",
		"entropic_bread": "VolcanicWorlds",
		"peripheral_arbor": "StarterForest",
		"heisenberg_township": "Village",
		"cyberdebt_megacity": "CyberDebtMegacity",
		"echoing_chasm": "EchoingChasm",
		"horizon_fracture": "HorizonFracture",
		"bureaucratic_abyss": "BureaucraticAbyss",
		"tidal_pools": "TidalPools",
		"yeast_prophet": "GildedRot",  # Dark/decadent vibe
		# Menu/fallback tracks (no biome)
		"end_credits": "",
		"afterbirth_arbor": "",
	}


func _compute_similarity_matrix():
	"""Compute cos² similarity between all biome pairs."""
	print("=== BIOME SIMILARITY MATRIX (cos²) ===")
	print("")
	print("Values: 1.0 = identical, 0.0 = orthogonal (no emoji overlap)")
	print("")

	var names = biome_vectors.keys()
	names.sort()

	# Header row
	var header = "%-16s" % ""
	for name in names:
		header += " | %6s" % name.substr(0, 6)
	print(header)

	var sep = ""
	for i in range(16 + names.size() * 9):
		sep += "-"
	print(sep)

	# Matrix rows
	for i in range(names.size()):
		var row_name = names[i]
		var vec_i = biome_vectors[row_name]
		var row = "%-16s" % row_name

		for j in range(names.size()):
			var col_name = names[j]
			var vec_j = biome_vectors[col_name]
			var sim = _compute_cos2(vec_i, vec_j)
			row += " | %6.3f" % sim

		print(row)

	print("")

	# Find highest off-diagonal similarities
	print("=== HIGHEST CROSS-BIOME SIMILARITIES ===")
	print("")

	var pairs: Array = []
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			var sim = _compute_cos2(biome_vectors[names[i]], biome_vectors[names[j]])
			pairs.append({"a": names[i], "b": names[j], "sim": sim})

	pairs.sort_custom(func(a, b): return a["sim"] > b["sim"])

	print("%-20s | %-20s | %8s | Shared Emojis" % ["Biome A", "Biome B", "cos²"])
	sep = ""
	for k in range(70):
		sep += "-"
	print(sep)

	for k in range(min(10, pairs.size())):
		var pair = pairs[k]
		var shared = _get_shared_emojis(pair["a"], pair["b"])
		print("%-20s | %-20s | %8.3f | %s" % [pair["a"], pair["b"], pair["sim"], shared])

	print("")


func _compute_cos2(vec_a: PackedFloat64Array, vec_b: PackedFloat64Array) -> float:
	"""Compute cos²(θ) = (a·b)² for normalized vectors."""
	if vec_a.size() != vec_b.size():
		return 0.0

	var dot = 0.0
	for i in range(vec_a.size()):
		dot += vec_a[i] * vec_b[i]

	return dot * dot


func _get_shared_emojis(biome_a: String, biome_b: String) -> String:
	"""Get emojis that appear in both biomes."""
	var vec_a = biome_vectors[biome_a]
	var vec_b = biome_vectors[biome_b]

	var shared: Array = []
	for i in range(vec_a.size()):
		if vec_a[i] > 0.01 and vec_b[i] > 0.01:
			shared.append(all_emojis[i])

	return " ".join(shared) if shared.size() > 0 else "(none)"


func _show_music_assignments():
	"""Show which music tracks map to which biome vectors."""
	print("=== MUSIC TRACK → BIOME MAPPING ===")
	print("")

	var mapped = 0
	var unmapped = 0

	for track in music_to_biome.keys():
		var biome = music_to_biome[track]
		if biome != "" and biome_vectors.has(biome):
			mapped += 1
			var vec = biome_vectors[biome]
			var dim = 0
			for v in vec:
				if v > 0.01:
					dim += 1
			print("  %-20s → %-20s (%d emojis)" % [track, biome, dim])
		else:
			unmapped += 1
			print("  %-20s → (unmapped)" % track)

	print("")
	print("Mapped tracks: %d" % mapped)
	print("Unmapped tracks: %d (need manual vectors or new biomes)" % unmapped)
	print("")

	# Simulate music selection for each biome
	print("=== SIMULATED MUSIC SELECTION ===")
	print("")
	print("If player is in biome X, which track has highest similarity?")
	print("")

	var biome_names = biome_vectors.keys()
	biome_names.sort()

	for target_biome in biome_names:
		var target_vec = biome_vectors[target_biome]

		# Find best matching track
		var best_track = ""
		var best_sim = -1.0

		for track in music_to_biome.keys():
			var track_biome = music_to_biome[track]
			if track_biome == "" or not biome_vectors.has(track_biome):
				continue

			var track_vec = biome_vectors[track_biome]
			var sim = _compute_cos2(target_vec, track_vec)

			if sim > best_sim:
				best_sim = sim
				best_track = track

		# Also show runner-up
		var second_track = ""
		var second_sim = -1.0
		for track in music_to_biome.keys():
			if track == best_track:
				continue
			var track_biome = music_to_biome[track]
			if track_biome == "" or not biome_vectors.has(track_biome):
				continue

			var track_vec = biome_vectors[track_biome]
			var sim = _compute_cos2(target_vec, track_vec)

			if sim > second_sim:
				second_sim = sim
				second_track = track

		print("%-20s → %s (%.3f)  |  runner-up: %s (%.3f)" % [
			target_biome, best_track, best_sim, second_track, second_sim
		])
