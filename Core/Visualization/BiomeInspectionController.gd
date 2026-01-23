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
	if biome and biome.has_method("get_purity"):
		return biome.get_purity()
	if biome and "quantum_computer" in biome and biome.quantum_computer:
		if biome.quantum_computer.has_method("get_purity"):
			return biome.quantum_computer.get_purity()
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

	# Get energy distribution from quantum_computer
	var qc = biome.quantum_computer if biome.quantum_computer else null
	if not qc:
		# No quantum computer - show equal distribution as placeholder
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

	# Calculate total energy for normalization
	var total_energy = 0.0
	var emoji_energies = {}

	# Sum energy across all basis states containing each emoji
	for emoji in biome.producible_emojis:
		var emoji_energy = _get_emoji_basis_energy(biome, emoji)
		emoji_energies[emoji] = emoji_energy
		total_energy += emoji_energy

	# Normalize to percentages
	for emoji in biome.producible_emojis:
		var energy = emoji_energies.get(emoji, 0.0)
		var percentage = (energy / total_energy * 100.0) if total_energy > 0.0 else 0.0

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
	if not biome.quantum_computer:
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


static func _get_emoji_basis_energy(biome: BiomeBase, emoji: String) -> float:
	"""Get energy associated with a specific emoji basis state

	Sums energy from all projections where this emoji appears
	"""
	var energy = 0.0

	if not "active_projections" in biome:
		return energy

	for pos in biome.active_projections.keys():
		var projection = biome.active_projections[pos]

		if projection:
			var north = projection.get("north_emoji", "")
			var south = projection.get("south_emoji", "")

			# If this emoji is in the projection, add its energy
			if emoji == north or emoji == south:
				if projection.has_method("get_quantum_energy"):
					energy += projection.get_quantum_energy()

	return energy


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
	if not biome.quantum_computer:
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
		}
	"""
	if not biome:
		return _empty_quantum_detail()

	var qc = biome.quantum_computer if "quantum_computer" in biome else null
	if not qc:
		return _empty_quantum_detail()

	return {
		"num_qubits": qc.register_map.num_qubits,
		"dimension": qc.register_map.dim(),
		"purity": qc.get_purity() if qc.has_method("get_purity") else 0.5,
		"entropy": _estimate_entropy(qc),
		"qubit_axes": _get_qubit_axes(qc),
		"hamiltonian": _get_hamiltonian_info(qc),
		"lindblad": _get_lindblad_info(qc),
		"entanglement": _get_entanglement_info(qc),
	}


static func _get_qubit_axes(qc) -> Array:
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

	if not qc or not qc.register_map:
		return axes

	var rm = qc.register_map

	for qubit_idx in range(rm.num_qubits):
		var axis_info = rm.axis(qubit_idx)
		if axis_info.is_empty():
			continue

		var north = axis_info.get("north", "?")
		var south = axis_info.get("south", "?")

		# Get marginal probabilities
		var p_north = qc.get_marginal(qubit_idx, 0) if qc.has_method("get_marginal") else 0.5
		var p_south = qc.get_marginal(qubit_idx, 1) if qc.has_method("get_marginal") else 0.5

		# Get coherence magnitude (off-diagonal element)
		# Model C: Use get_coherence() directly on quantum computer
		var coherence_mag = 0.0
		if qc.has_method("get_coherence"):
			var coh = qc.get_coherence(north, south)
			if coh:
				coherence_mag = sqrt(coh.re * coh.re + coh.im * coh.im)

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


static func _get_hamiltonian_info(qc) -> Dictionary:
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

	if not qc:
		return info

	# Get couplings from coupling_registry
	if "coupling_registry" in qc and qc.coupling_registry:
		for key in qc.coupling_registry.keys():
			var coupling = qc.coupling_registry[key]
			info["couplings"].append({
				"a": coupling.get("a", -1),
				"b": coupling.get("b", -1),
				"J": coupling.get("J", 0.0),
			})

	# Get all couplings via method if available
	if qc.has_method("get_all_couplings"):
		var couplings = qc.get_all_couplings()
		if couplings.size() > 0 and info["couplings"].is_empty():
			info["couplings"] = couplings

	# Extract self-energies from Hamiltonian diagonal
	# (These are typically set by IconRegistry based on emoji physics)
	if qc.hamiltonian and qc.register_map:
		var rm = qc.register_map
		for emoji in rm.coordinates.keys():
			var q = rm.qubit(emoji)
			var p = rm.pole(emoji)
			if q >= 0:
				# Self-energy is embedded in diagonal elements
				# For now, mark as present (actual extraction would need full matrix analysis)
				info["self_energies"][emoji] = 0.0  # Placeholder

	return info


static func _get_lindblad_info(qc) -> Array:
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

	if not qc:
		return channels

	# Check for gated Lindblad configs (these have structured data)
	if "gated_lindblad_configs" in qc and qc.gated_lindblad_configs:
		for config in qc.gated_lindblad_configs:
			channels.append({
				"type": "gated",
				"description": config.get("description", "Conditional dissipation"),
				"rate": config.get("rate", 0.0),
				"gate": config.get("gate", ""),
			})

	# Count raw Lindblad operators
	if "lindblad_operators" in qc and qc.lindblad_operators:
		var num_ops = qc.lindblad_operators.size()
		if num_ops > 0 and channels.is_empty():
			channels.append({
				"type": "raw",
				"description": "%d Lindblad operators" % num_ops,
				"rate": 0.0,
				"gate": "",
			})

	return channels


static func _get_entanglement_info(qc) -> Dictionary:
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

	if not qc:
		return info

	# Check components
	if "components" in qc and qc.components:
		info["num_components"] = qc.components.size()
		for comp_id in qc.components.keys():
			var comp = qc.components[comp_id]
			if comp and "register_ids" in comp:
				info["component_sizes"].append(comp.register_ids.size())

		info["is_fully_entangled"] = (info["num_components"] == 1)

	return info


static func _estimate_entropy(qc) -> float:
	"""Estimate von Neumann entropy from purity

	For a maximally mixed state: S = log(d)
	For a pure state: S = 0
	Using approximation: S ≈ -log(Tr(ρ²)) for rough estimate
	"""
	if not qc or not qc.has_method("get_purity"):
		return 0.0

	var purity = qc.get_purity()
	if purity <= 0.0 or purity > 1.0:
		return 0.0

	# Rough entropy estimate: S ≈ -log₂(purity)
	# Normalized to [0, 1] where 1 = maximally mixed
	var dim = qc.register_map.dim() if qc.register_map else 2
	var max_entropy = log(dim) / log(2)  # log₂(d)

	if purity >= 1.0:
		return 0.0

	var entropy_estimate = -log(purity) / log(2)
	return clamp(entropy_estimate / max_entropy, 0.0, 1.0)


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
	}
