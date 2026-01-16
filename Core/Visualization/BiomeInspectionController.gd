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
		"total_energy": _calculate_total_bath_energy(biome),
		"active_plots": _count_active_projections(biome),
		"emoji_states": emoji_states,
		"energy_flow_rate": _calculate_energy_flow_rate(biome),
		"entanglement_count": _count_entanglements(biome),
		"bath_mode": _get_bath_mode(biome),
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

	# Get bath energy distribution
	var bath = biome.bath if "bath" in biome else null
	if not bath:
		# No bath - show equal distribution as placeholder
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

	if not biome or not "bath" in biome or not biome.bath:
		return transfers

	var bath = biome.bath

	# Get Lindblad operators from bath
	if "lindblad_ops" in bath:
		# Extract transfer information from Lindblad operators
		# This depends on bath implementation details
		pass

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


static func _calculate_total_bath_energy(biome: BiomeBase) -> float:
	"""Sum total energy in bath quantum state"""
	var bath = biome.bath if "bath" in biome else null
	if not bath:
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


static func _get_bath_mode(biome: BiomeBase) -> String:
	"""Determine bath evolution mode"""
	var bath = biome.bath if "bath" in biome else null
	if not bath:
		return "None"

	# Check for Hamiltonian and Lindblad
	var has_hamiltonian = "hamiltonian" in bath and bath.hamiltonian != null
	var has_lindblad = "lindblad_ops" in bath and bath.lindblad_ops.size() > 0

	if has_hamiltonian and has_lindblad:
		return "Hybrid"
	elif has_hamiltonian:
		return "Hamiltonian"
	elif has_lindblad:
		return "Lindblad"
	else:
		return "Unknown"


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
		"bath_mode": "None"
	}
