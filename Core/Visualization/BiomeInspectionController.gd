class_name BiomeInspectionController
extends Node

## Biome Inspection Controller
## Provides structured data for BiomeInspectorOverlay UI
## Extracts quantum state information from biomes for display

const BiomeBase = preload("res://Core/Environment/BiomeBase.gd")

## Get comprehensive biome data for display
static func get_biome_data(biome: BiomeBase, farm_grid) -> Dictionary:
	"""Extract all displayable data from a biome

	Returns:
		{
			"name": String,
			"emoji": String,  # Representative emoji
			"temperature": float,
			"total_energy": float,
			"active_plots": int,
			"emoji_states": Array[Dictionary],  # Detailed per-emoji data
			"energy_flow_rate": float,
			"entanglement_count": int,
			"bath_mode": String,
			"purity": float,  # 0-1 quantum purity (Tr(ρ²))
			"harvest_prediction": Dictionary  # Expected harvest outcomes
		}
	"""
	if not biome:
		return _empty_biome_data()

	var emoji_states = get_emoji_energy_distribution(biome)

	var data = {
		"name": _get_biome_name(biome),
		"emoji": _get_biome_representative_emoji(biome),
		"temperature": biome.temperature if "temperature" in biome else 300.0,
		"total_energy": _calculate_total_quantum_energy(biome),
		"active_plots": _count_active_projections(biome),
		"emoji_states": emoji_states,
		"energy_flow_rate": _calculate_energy_flow_rate(biome),
		"entanglement_count": _count_entanglements(biome),
		"quantum_mode": _get_quantum_mode(biome),
		"purity": _get_biome_purity(biome),
		"harvest_prediction": _get_harvest_prediction(emoji_states)
	}

	return data


## Get biome quantum purity (Tr(ρ²))
static func _get_biome_purity(biome: BiomeBase) -> float:
	var viz = _get_viz_cache(biome)
	if viz:
		var purity = viz.get_purity()
		if purity >= 0.0:
			return purity
	return 0.5


## Get harvest prediction (most likely outcomes)
static func _get_harvest_prediction(emoji_states: Array) -> Dictionary:
	"""Predict what player will likely get from harvest based on emoji probabilities"""
	if emoji_states.is_empty():
		return {"top_emoji": "?", "top_percent": 0, "second_emoji": "?", "second_percent": 0}

	# emoji_states is already sorted by percentage (highest first)
	var top = emoji_states[0] if emoji_states.size() > 0 else {}
	var second = emoji_states[1] if emoji_states.size() > 1 else {}

	return {
		"top_emoji": top.get("emoji", "?"),
		"top_percent": int(top.get("percentage", 0)),
		"second_emoji": second.get("emoji", "?"),
		"second_percent": int(second.get("percentage", 0))
	}


## Get per-emoji energy distribution
static func get_emoji_energy_distribution(biome: BiomeBase) -> Array[Dictionary]:
	"""Calculate energy distribution across emoji basis states

	Returns array of:
		{
			"emoji": String,
			"percentage": float,  # 0-100
			"energy_dots": int,   # 1-5 visual indicator
			"trend": String       # "stable" | "growing" | "decaying"
		}
	"""
	var emoji_data: Array[Dictionary] = []

	if not biome or not biome.producible_emojis:
		return emoji_data

	# Compute probabilities from cached C++ Bloch packet
	var total_prob = 0.0
	var emoji_probs = {}
	for emoji in biome.producible_emojis:
		var p = _get_emoji_probability(biome, emoji)
		emoji_probs[emoji] = p
		if p >= 0.0:
			total_prob += p

	# If cache not ready, show equal distribution as placeholder
	if total_prob <= 0.0:
		var count = biome.producible_emojis.size()
		var percentage = 100.0 / count if count > 0 else 0.0
		for emoji in biome.producible_emojis:
			emoji_data.append({
				"emoji": emoji,
				"percentage": percentage,
				"energy_dots": _percentage_to_dots(percentage),
				"trend": "stable"
			})
		return emoji_data

	# Normalize to percentages
	for emoji in biome.producible_emojis:
		var prob = maxf(emoji_probs.get(emoji, 0.0), 0.0)
		var percentage = (prob / total_prob * 100.0) if total_prob > 0.0 else 0.0

		emoji_data.append({
			"emoji": emoji,
			"percentage": percentage,
			"energy_dots": _percentage_to_dots(percentage),
			"trend": "stable"  # TODO: Calculate derivative for trend
		})

	# Sort by percentage (highest first)
	emoji_data.sort_custom(func(a, b): return a.percentage > b.percentage)

	return emoji_data


## Get active projections for a biome
static func get_active_projections(biome: BiomeBase, farm_grid) -> Array[Dictionary]:
	"""Get list of plots projected into this biome's bath

	Returns array of:
		{
			"position": Vector2i,
			"north_emoji": String,
			"south_emoji": String,
			"energy": float,
			"measured": bool
		}
	"""
	var projections: Array[Dictionary] = []

	if not biome or not farm_grid:
		return projections

	var biome_name = _get_biome_name(biome)

	# Iterate through all plots
	for pos in farm_grid.plot_biome_assignments.keys():
		var assigned_biome = farm_grid.plot_biome_assignments.get(pos, "")

		if assigned_biome == biome_name:
			var plot = farm_grid.get_plot(pos)

			if plot and plot.is_planted:
				var proj_data = {
					"position": pos,
					"north_emoji": "",
					"south_emoji": "",
					"energy": 0.0,
					"measured": plot.has_been_measured
				}

				# Get quantum state info
				if plot.quantum_state:
					proj_data["north_emoji"] = plot.quantum_state.north_emoji
					proj_data["south_emoji"] = plot.quantum_state.south_emoji
					proj_data["energy"] = plot.quantum_state.get_quantum_energy()

				projections.append(proj_data)

	return projections


## Calculate Lindblad transfer rates
static func get_lindblad_transfers(biome: BiomeBase) -> Array[Dictionary]:
	"""Extract Lindblad transfer rates for display

	Returns array of:
		{
			"from_emoji": String,
			"to_emoji": String,
			"rate": float
		}
	"""
	var transfers: Array[Dictionary] = []
	# Transfer rate tracking not implemented for quantum_computer
	return transfers


# ============================================================================
# PRIVATE HELPER FUNCTIONS
# ============================================================================

static func _get_biome_name(biome: BiomeBase) -> String:
	"""Extract biome name from script path or class name"""
	var script_path = biome.get_script().resource_path

	# Extract name from path: "res://Core/Environment/BioticFluxBiome.gd" → "BioticFlux"
	var filename = script_path.get_file().get_basename()

	# Remove "Biome" suffix if present
	if filename.ends_with("Biome"):
		filename = filename.substr(0, filename.length() - 5)

	return filename


static func _get_biome_representative_emoji(biome: BiomeBase) -> String:
	"""Get first emoji as representative icon"""
	if biome.producible_emojis and biome.producible_emojis.size() > 0:
		return biome.producible_emojis[0]
	return "🌍"


static func _calculate_total_quantum_energy(biome: BiomeBase) -> float:
	"""Sum total energy in quantum computer state"""
	if not biome:
		return 0.0

	# Sum energy from all active projections
	var total = 0.0
	if "active_projections" in biome:
		for pos in biome.active_projections.keys():
			var projection = biome.active_projections[pos]
			if projection and projection.has_method("get_quantum_energy"):
				total += projection.get_quantum_energy()

	return total


static func _count_active_projections(biome: BiomeBase) -> int:
	"""Count number of plots projected into this bath"""
	if "active_projections" in biome:
		return biome.active_projections.size()
	return 0


static func _get_emoji_probability(biome: BiomeBase, emoji: String) -> float:
	"""Get cached probability for a specific emoji pole, or -1 if unavailable."""
	var viz = _get_viz_cache(biome)
	if not viz:
		return -1.0
	var qubit_idx = viz.get_qubit(emoji)
	var pole = viz.get_pole(emoji)
	if qubit_idx < 0 or pole < 0:
		return -1.0

	var snap = viz.get_snapshot(qubit_idx)
	if snap.is_empty():
		return -1.0

	var p = snap.get("p0", 0.5) if pole == 0 else snap.get("p1", 0.5)
	return clampf(p, 0.0, 1.0)


static func _percentage_to_dots(percentage: float) -> int:
	"""Convert energy percentage to visual dot count (1-5)"""
	if percentage >= 50.0:
		return 5  # ●●●●●
	elif percentage >= 25.0:
		return 4  # ●●●●
	elif percentage >= 10.0:
		return 3  # ●●●
	elif percentage >= 5.0:
		return 2  # ●●
	else:
		return 1  # ●


static func _calculate_energy_flow_rate(biome: BiomeBase) -> float:
	"""Calculate dE/dt (energy derivative)

	Returns rate of energy change in bath (⚡/s)
	"""
	# TODO: Track energy history and calculate derivative
	# For now, return 0 (would need to store previous energy values)
	return 0.0


static func _count_entanglements(biome: BiomeBase) -> int:
	"""Count number of entangled pairs in this biome"""
	if "bell_gates" in biome:
		return biome.bell_gates.size()
	return 0


static func _get_quantum_mode(biome: BiomeBase) -> String:
	"""Determine quantum evolution mode"""
	var viz = _get_viz_cache(biome)
	if not viz or not viz.has_metadata():
		return "None"
	return "QuantumComputer"


static func _empty_biome_data() -> Dictionary:
	"""Return empty data structure"""
	return {
		"name": "Unknown",
		"emoji": "❓",
		"temperature": 0.0,
		"total_energy": 0.0,
		"active_plots": 0,
		"emoji_states": [],
		"energy_flow_rate": 0.0,
		"entanglement_count": 0,
		"quantum_mode": "None"
	}


# ============================================================================
# QUANTUM DETAIL EXTRACTION (Phase 3 - Deep Quantum Display)
# ============================================================================

static func get_quantum_detail(biome: BiomeBase) -> Dictionary:
	"""Extract comprehensive quantum computer data for display

	Returns:
		{
			"num_qubits": int,
			"dimension": int,  # 2^num_qubits
			"purity": float,  # Tr(ρ²)
			"entropy": float,  # von Neumann entropy estimate
			"qubit_axes": Array,  # Per-qubit Bloch projections
			"hamiltonian": Dictionary,  # Self-energies + couplings
			"lindblad": Array,  # Dissipation channels
			"entanglement": Dictionary,  # Component structure
			"populations": Dictionary,  # {emoji: probability} for all icons
		}
	"""
	if not biome:
		return _empty_quantum_detail()

	var viz = _get_viz_cache(biome)
	var purity = _get_biome_purity(biome)
	var num_qubits = viz.get_num_qubits() if viz else 0
	var dim = (1 << num_qubits) if num_qubits > 0 else 0

	return {
		"num_qubits": num_qubits,
		"dimension": dim,
		"purity": purity,
		"entropy": _estimate_entropy(purity, dim),
		"qubit_axes": _get_qubit_axes(biome),
		"hamiltonian": _get_hamiltonian_info(biome),
		"lindblad": _get_lindblad_info(biome),
		"entanglement": _get_entanglement_info(biome),
		"populations": _get_icon_populations(biome),
	}


static func _get_icon_populations(biome: BiomeBase) -> Dictionary:
	"""Get probability amplitudes for all registered icons.

	This is the actual quantum state probability - the likelihood of
	harvesting each icon when the state is measured.

	Returns:
		Dictionary: {emoji: probability} for all registered emojis
	"""
	var pops: Dictionary = {}
	var viz = _get_viz_cache(biome)
	if not viz:
		return pops
	for emoji in viz.get_emojis():
		var p = _get_emoji_probability(biome, emoji)
		if p >= 0.0:
			pops[emoji] = p
	return pops


static func _get_qubit_axes(biome: BiomeBase) -> Array:
	"""Get Bloch projection for each qubit axis

	Returns array of:
		{
			"qubit": int,
			"north": String,  # North pole emoji
			"south": String,  # South pole emoji
			"p_north": float,  # P(north) probability
			"p_south": float,  # P(south) probability
			"coherence_mag": float,  # |ρ₀₁| off-diagonal magnitude
			"balance": float,  # -1 (full south) to +1 (full north)
		}
	"""
	var axes = []

	var viz = _get_viz_cache(biome)
	if not viz:
		return axes

	for qubit_idx in range(viz.get_num_qubits()):
		var axis_info = viz.get_axis(qubit_idx)
		if axis_info.is_empty():
			continue

		var north = axis_info.get("north", "?")
		var south = axis_info.get("south", "?")

		var p_north = 0.5
		var p_south = 0.5
		var coherence_mag = 0.0
		var bloch = viz.get_bloch(qubit_idx)
		if not bloch.is_empty():
			p_north = bloch.get("p0", 0.5)
			p_south = bloch.get("p1", 0.5)
			var x = bloch.get("x", 0.0)
			var y = bloch.get("y", 0.0)
			# |rho_01| = 0.5 * sqrt(x^2 + y^2)
			coherence_mag = 0.5 * sqrt(x * x + y * y)

		# Calculate balance (-1 to +1, where +1 is full north)
		var total = p_north + p_south
		var balance = (p_north - p_south) / total if total > 0 else 0.0

		axes.append({
			"qubit": qubit_idx,
			"north": north,
			"south": south,
			"p_north": p_north,
			"p_south": p_south,
			"coherence_mag": coherence_mag,
			"balance": balance,
		})

	return axes


static func _get_hamiltonian_info(biome: BiomeBase) -> Dictionary:
	"""Extract Hamiltonian structure (self-energies and couplings)

	Returns:
		{
			"self_energies": Dictionary,  # emoji → ε value
			"couplings": Array,  # [{a: qubit, b: qubit, J: float}, ...]
		}
	"""
	var info = {
		"self_energies": {},
		"couplings": [],
	}

	# Get couplings from cached payload (emoji → emoji)
	var viz = _get_viz_cache(biome)
	if viz:
		var seen_pairs: Dictionary = {}
		for emoji in viz.get_emojis():
			var couplings = viz.get_hamiltonian_couplings(emoji)
			var qa = viz.get_qubit(emoji)
			if qa < 0:
				continue
			for target in couplings:
				var qb = viz.get_qubit(target)
				if qb < 0:
					continue
				var pair = [emoji, target]
				pair.sort()
				var key = "%s_%s" % [pair[0], pair[1]]
				if seen_pairs.has(key):
					continue
				seen_pairs[key] = true
				info["couplings"].append({
					"a": qa,
					"b": qb,
					"J": couplings[target],
				})

	# Extract self-energies from Hamiltonian diagonal
	# (These are typically set by IconRegistry based on emoji physics)
	if viz:
		for emoji in viz.get_emojis():
			# Self-energy is embedded in diagonal elements
			# For now, mark as present (actual extraction would need full matrix analysis)
			info["self_energies"][emoji] = 0.0  # Placeholder

	return info


static func _get_lindblad_info(biome: BiomeBase) -> Array:
	"""Extract Lindblad dissipation channel information

	Returns array of:
		{
			"type": String,  # "incoming" | "outgoing" | "gated"
			"description": String,  # Human-readable description
			"rate": float,  # γ coefficient
			"gate": String,  # Gate emoji (for gated operators)
		}
	"""
	var channels = []
	var viz = _get_viz_cache(biome)
	if not viz:
		return channels
	for emoji in viz.get_emojis():
		var outgoing = viz.get_lindblad_outgoing(emoji)
		for target in outgoing:
			channels.append({
				"type": "outgoing",
				"description": "%s → %s" % [emoji, target],
				"rate": outgoing[target],
				"gate": "",
			})

	return channels


static func _get_entanglement_info(biome: BiomeBase) -> Dictionary:
	"""Extract entanglement structure

	Returns:
		{
			"num_components": int,  # Number of disconnected components
			"component_sizes": Array[int],  # Size of each component
			"is_fully_entangled": bool,  # All qubits in one component?
		}
	"""
	var info = {
		"num_components": 1,
		"component_sizes": [],
		"is_fully_entangled": true,
	}
	var viz = _get_viz_cache(biome)
	if not viz:
		return info
	var n = viz.get_num_qubits()
	if n <= 0:
		return info

	# Build adjacency based on MI threshold
	var threshold = 0.05
	var adjacency: Array = []
	adjacency.resize(n)
	for i in range(n):
		adjacency[i] = []
	for i in range(n):
		for j in range(i + 1, n):
			var mi = viz.get_mutual_information(i, j)
			if mi > threshold:
				adjacency[i].append(j)
				adjacency[j].append(i)

	# Connected components
	var visited: Array = []
	visited.resize(n)
	visited.fill(false)
	var component_sizes: Array = []
	for i in range(n):
		if visited[i]:
			continue
		var queue: Array = [i]
		visited[i] = true
		var size = 0
		while not queue.is_empty():
			var cur = queue.pop_back()
			size += 1
			for neighbor in adjacency[cur]:
				if not visited[neighbor]:
					visited[neighbor] = true
					queue.append(neighbor)
		component_sizes.append(size)

	info["num_components"] = component_sizes.size()
	info["component_sizes"] = component_sizes
	info["is_fully_entangled"] = (info["num_components"] == 1)

	return info


static func _estimate_entropy(purity: float, dim: int) -> float:
	"""Estimate von Neumann entropy from purity

	For a maximally mixed state: S = log(d)
	For a pure state: S = 0
	Using approximation: S ≈ -log(Tr(ρ²)) for rough estimate
	"""
	if purity <= 0.0 or purity > 1.0:
		return 0.0
	# Rough entropy estimate: S ≈ -log₂(purity)
	# Normalized to [0, 1] where 1 = maximally mixed
	if dim <= 1:
		return 0.0
	var max_entropy = log(dim) / log(2)  # log₂(d)

	if purity >= 1.0:
		return 0.0

	var entropy_estimate = -log(purity) / log(2)
	return clamp(entropy_estimate / max_entropy, 0.0, 1.0)


static func _get_viz_cache(biome: BiomeBase):
	if biome and "viz_cache" in biome:
		return biome.viz_cache
	return null


static func _empty_quantum_detail() -> Dictionary:
	"""Return empty quantum detail structure"""
	return {
		"num_qubits": 0,
		"dimension": 0,
		"purity": 0.5,
		"entropy": 0.0,
		"qubit_axes": [],
		"hamiltonian": {"self_energies": {}, "couplings": []},
		"lindblad": [],
		"entanglement": {"num_components": 0, "component_sizes": [], "is_fully_entangled": false},
		"populations": {},
	}
