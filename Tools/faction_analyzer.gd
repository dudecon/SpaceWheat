extends SceneTree

## Faction Analyzer - Analyze factions_merged.json
## Usage: godot --headless --script Tools/faction_analyzer.gd

var factions: Array = []
var emoji_usage: Dictionary = {}  # emoji -> {factions: [], total_hamiltonian: float, total_lindblad: float}
var faction_signatures: Dictionary = {}  # name -> PackedFloat64Array (for similarity)

func _initialize():
	print("=== Faction Analysis ===")
	print("")

	# Load factions
	factions = _load_factions()
	if factions.is_empty():
		print("ERROR: Failed to load factions")
		quit(1)
		return

	print("Loaded %d factions" % factions.size())
	print("")

	# Analysis phases
	_analyze_emoji_distribution()
	_analyze_hamiltonian_strengths()
	_analyze_lindblad_flows()
	_analyze_faction_rings()
	_compute_faction_similarities()

	print("")
	print("=== Analysis Complete ===")
	quit(0)


func _load_factions() -> Array:
	var path = "res://Core/Factions/data/factions_merged.json"
	if not FileAccess.file_exists(path):
		print("ERROR: %s not found" % path)
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


func _analyze_emoji_distribution():
	print("=== EMOJI DISTRIBUTION ===")
	print("")

	# Count emoji appearances across factions
	for faction in factions:
		var name = faction.get("name", "Unknown")
		var signature = faction.get("signature", [])
		var hamiltonian = faction.get("hamiltonian", {})
		var self_energies = faction.get("self_energies", {})

		# Count signature emojis
		for emoji in signature:
			if not emoji_usage.has(emoji):
				emoji_usage[emoji] = {"factions": [], "signature_count": 0, "hamiltonian_total": 0.0, "self_energy_total": 0.0}
			emoji_usage[emoji]["factions"].append(name)
			emoji_usage[emoji]["signature_count"] += 1

		# Sum Hamiltonian couplings
		for source in hamiltonian.keys():
			if not emoji_usage.has(source):
				emoji_usage[source] = {"factions": [], "signature_count": 0, "hamiltonian_total": 0.0, "self_energy_total": 0.0}
			var targets = hamiltonian[source]
			for target in targets.keys():
				var val = targets[target]
				var coupling = 0.0
				if val is float or val is int:
					coupling = abs(float(val))
				elif val is Array and val.size() > 0:
					coupling = abs(float(val[0]))
				emoji_usage[source]["hamiltonian_total"] += coupling

		# Sum self-energies
		for emoji in self_energies.keys():
			if not emoji_usage.has(emoji):
				emoji_usage[emoji] = {"factions": [], "signature_count": 0, "hamiltonian_total": 0.0, "self_energy_total": 0.0}
			emoji_usage[emoji]["self_energy_total"] += abs(float(self_energies[emoji]))

	# Sort by signature count
	var sorted_emojis = emoji_usage.keys()
	sorted_emojis.sort_custom(func(a, b): return emoji_usage[a]["signature_count"] > emoji_usage[b]["signature_count"])

	print("Top 20 Most Used Emojis (by faction signature):")
	print("%-4s | %6s | %10s | %10s | Factions" % ["Emoji", "Count", "H_total", "E_self"])
	var sep = ""
	for i in range(70):
		sep += "-"
	print(sep)

	for i in range(min(20, sorted_emojis.size())):
		var emoji = sorted_emojis[i]
		var data = emoji_usage[emoji]
		var faction_list = data["factions"].slice(0, 3)
		var more = "..." if data["factions"].size() > 3 else ""
		print("%-4s | %6d | %10.3f | %10.3f | %s%s" % [
			emoji,
			data["signature_count"],
			data["hamiltonian_total"],
			data["self_energy_total"],
			", ".join(faction_list),
			more
		])

	print("")
	print("Total unique emojis: %d" % emoji_usage.size())
	print("")


func _analyze_hamiltonian_strengths():
	print("=== HAMILTONIAN COUPLING ANALYSIS ===")
	print("")

	var coupling_pairs: Array = []  # [{source, target, strength, faction}]

	for faction in factions:
		var name = faction.get("name", "Unknown")
		var hamiltonian = faction.get("hamiltonian", {})

		for source in hamiltonian.keys():
			var targets = hamiltonian[source]
			for target in targets.keys():
				var val = targets[target]
				var strength = 0.0
				if val is float or val is int:
					strength = float(val)
				elif val is Array and val.size() > 0:
					strength = float(val[0])

				coupling_pairs.append({
					"source": source,
					"target": target,
					"strength": strength,
					"faction": name
				})

	# Sort by absolute strength
	coupling_pairs.sort_custom(func(a, b): return abs(a["strength"]) > abs(b["strength"]))

	print("Strongest 15 Hamiltonian Couplings:")
	print("%-4s → %-4s | %8s | Faction" % ["Src", "Tgt", "Strength"])
	var sep = ""
	for i in range(50):
		sep += "-"
	print(sep)

	for i in range(min(15, coupling_pairs.size())):
		var pair = coupling_pairs[i]
		print("%-4s → %-4s | %8.3f | %s" % [pair["source"], pair["target"], pair["strength"], pair["faction"]])

	print("")
	print("Total couplings: %d" % coupling_pairs.size())
	print("")


func _analyze_lindblad_flows():
	print("=== LINDBLAD DISSIPATION ANALYSIS ===")
	print("")

	var lindblad_flows: Array = []  # [{source, target, rate, type, faction}]

	for faction in factions:
		var name = faction.get("name", "Unknown")

		# Outgoing flows
		var outgoing = faction.get("lindblad_outgoing", {})
		for source in outgoing.keys():
			var targets = outgoing[source]
			for target in targets.keys():
				lindblad_flows.append({
					"source": source,
					"target": target,
					"rate": float(targets[target]),
					"type": "outgoing",
					"faction": name
				})

		# Incoming flows
		var incoming = faction.get("lindblad_incoming", {})
		for target in incoming.keys():
			var sources = incoming[target]
			for source in sources.keys():
				lindblad_flows.append({
					"source": source,
					"target": target,
					"rate": float(sources[source]),
					"type": "incoming",
					"faction": name
				})

		# Gated Lindblad
		var gated = faction.get("gated_lindblad", {})
		for target in gated.keys():
			var entries = gated[target]
			if entries is Array:
				for entry in entries:
					lindblad_flows.append({
						"source": entry.get("source", "?"),
						"target": target,
						"rate": float(entry.get("rate", 0)),
						"type": "gated(" + str(entry.get("gate", "?")) + ")",
						"faction": name
					})

	# Sort by rate
	lindblad_flows.sort_custom(func(a, b): return a["rate"] > b["rate"])

	print("Strongest 15 Lindblad Flows:")
	print("%-4s → %-4s | %8s | %-15s | Faction" % ["Src", "Tgt", "Rate", "Type"])
	var sep = ""
	for i in range(65):
		sep += "-"
	print(sep)

	for i in range(min(15, lindblad_flows.size())):
		var flow = lindblad_flows[i]
		print("%-4s → %-4s | %8.4f | %-15s | %s" % [flow["source"], flow["target"], flow["rate"], flow["type"], flow["faction"]])

	print("")
	print("Total Lindblad flows: %d" % lindblad_flows.size())
	print("")


func _analyze_faction_rings():
	print("=== FACTION RINGS ===")
	print("")

	var rings: Dictionary = {}  # ring -> [faction names]

	for faction in factions:
		var name = faction.get("name", "Unknown")
		var ring = faction.get("ring", "unknown")

		if not rings.has(ring):
			rings[ring] = []
		rings[ring].append(name)

	for ring in rings.keys():
		print("%s ring (%d factions):" % [ring.capitalize(), rings[ring].size()])
		for faction_name in rings[ring]:
			print("  - %s" % faction_name)
		print("")


func _compute_faction_similarities():
	print("=== FACTION SIGNATURE SIMILARITY ===")
	print("")
	print("(Jaccard similarity based on emoji overlap)")
	print("")

	# Build signature sets
	var faction_sets: Dictionary = {}  # name -> Set of emojis
	for faction in factions:
		var name = faction.get("name", "Unknown")
		var signature = faction.get("signature", [])
		var hamiltonian = faction.get("hamiltonian", {})

		# Include all emojis faction touches
		var emoji_set: Dictionary = {}
		for emoji in signature:
			emoji_set[emoji] = true
		for emoji in hamiltonian.keys():
			emoji_set[emoji] = true

		faction_sets[name] = emoji_set

	# Find most similar pairs
	var similarities: Array = []
	var names = faction_sets.keys()

	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			var name_a = names[i]
			var name_b = names[j]
			var set_a = faction_sets[name_a]
			var set_b = faction_sets[name_b]

			# Jaccard similarity = |A ∩ B| / |A ∪ B|
			var intersection = 0
			var union_size = set_a.size()
			for emoji in set_b.keys():
				if set_a.has(emoji):
					intersection += 1
				else:
					union_size += 1

			var jaccard = float(intersection) / float(union_size) if union_size > 0 else 0.0

			if jaccard > 0:
				similarities.append({
					"faction_a": name_a,
					"faction_b": name_b,
					"jaccard": jaccard,
					"overlap": intersection
				})

	# Sort by similarity
	similarities.sort_custom(func(a, b): return a["jaccard"] > b["jaccard"])

	print("Top 15 Most Similar Faction Pairs:")
	print("%-25s | %-25s | %8s | %6s" % ["Faction A", "Faction B", "Jaccard", "Overlap"])
	var sep = ""
	for i in range(75):
		sep += "-"
	print(sep)

	for i in range(min(15, similarities.size())):
		var sim = similarities[i]
		print("%-25s | %-25s | %8.3f | %6d" % [
			sim["faction_a"].substr(0, 25),
			sim["faction_b"].substr(0, 25),
			sim["jaccard"],
			sim["overlap"]
		])

	print("")

	# Summary stats
	var total_factions = names.size()
	var isolated = 0
	for name in names:
		var has_overlap = false
		for sim in similarities:
			if (sim["faction_a"] == name or sim["faction_b"] == name) and sim["jaccard"] > 0:
				has_overlap = true
				break
		if not has_overlap:
			isolated += 1

	print("Total factions: %d" % total_factions)
	print("Factions with no emoji overlap: %d" % isolated)
