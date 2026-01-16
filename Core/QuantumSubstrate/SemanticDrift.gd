class_name SemanticDrift
extends RefCounted

## SemanticDrift: 🌀 causes nearby icons to shift their couplings
##
## The spiral emoji (🌀) represents semantic instability - when present
## in sufficient quantity, it causes nearby icons' physics to drift randomly.
## This creates chaos and unpredictability, making the game harder to control.
##
## Mechanics:
## - When P(🌀) > threshold, icons within DRIFT_RADIUS hops are affected
## - Affected icons have their hamiltonian_couplings and self_energy perturbed
## - Perturbation strength scales with 🌀 population
## - ✨ (sparkle) acts as a stabilizer, counteracting drift
##
## Balance:
## - Outer ring factions tend to use 🌀 (chaos)
## - Reality Midwives use ✨ to stabilize (order)
## - Players must manage drift vs stability tradeoff

const DRIFT_EMOJI = "🌀"
const STABILIZER_EMOJI = "✨"
const DRIFT_RADIUS = 3          # Icons within this many "hops" are affected
const DRIFT_RATE = 0.002        # Per tick, per unit 🌀 population
const DRIFT_THRESHOLD = 0.01   # Minimum 🌀 population to trigger drift
const STABILIZER_FACTOR = 0.7  # How much ✨ counteracts 🌀


## Apply semantic drift to icons based on current bath state
## Call this in the evolution loop (BiomeBase._physics_process or QuantumEvolver)
static func apply_drift(bath, icon_registry, dt: float) -> void:
	"""Apply semantic drift based on 🌀 population

	Args:
		bath: The quantum bath with density matrix
		icon_registry: IconRegistry or dictionary of icons
		dt: Time delta
	"""
	if bath == null or icon_registry == null:
		return

	# Get 🌀 and ✨ populations
	var spiral_pop = _get_probability(bath, DRIFT_EMOJI)
	var sparkle_pop = _get_probability(bath, STABILIZER_EMOJI)

	# Stabilizer counteracts drift
	var net_drift = spiral_pop - (sparkle_pop * STABILIZER_FACTOR)

	if net_drift < DRIFT_THRESHOLD:
		return  # No drift below threshold

	var drift_strength = net_drift * DRIFT_RATE * dt

	# Get spiral icon to find nearby emojis
	var spiral_icon = _get_icon(icon_registry, DRIFT_EMOJI)
	if spiral_icon == null:
		return

	# Find icons within drift radius
	var affected_emojis = _get_nearby_emojis(spiral_icon, icon_registry, DRIFT_RADIUS)

	# Apply drift to each affected icon
	for emoji in affected_emojis:
		var icon = _get_icon(icon_registry, emoji)
		if icon != null:
			_apply_drift_to_icon(icon, drift_strength)


## Apply random perturbations to an icon's physics
static func _apply_drift_to_icon(icon, strength: float) -> void:
	"""Perturb icon's hamiltonian_couplings and self_energy

	Args:
		icon: Icon to modify
		strength: Perturbation magnitude
	"""
	# Perturb hamiltonian couplings
	for target in icon.hamiltonian_couplings.keys():
		var current = icon.hamiltonian_couplings[target]
		var perturbation = randf_range(-strength, strength)

		if current is Vector2:
			# Complex coupling - perturb both components
			icon.hamiltonian_couplings[target] = Vector2(
				current.x + perturbation,
				current.y + randf_range(-strength * 0.5, strength * 0.5)
			)
		else:
			icon.hamiltonian_couplings[target] = current + perturbation

	# Perturb self-energy (smaller effect)
	icon.self_energy += randf_range(-strength * 0.5, strength * 0.5)

	# Perturb lindblad rates (very small effect)
	for target in icon.lindblad_outgoing.keys():
		var current = icon.lindblad_outgoing[target]
		var perturbation = randf_range(-strength * 0.2, strength * 0.2)
		icon.lindblad_outgoing[target] = maxf(0.001, current + perturbation)


## Find emojis within a given radius of the source icon
static func _get_nearby_emojis(source_icon, icon_registry, radius: int) -> Array:
	"""BFS to find emojis within radius hops of source

	Args:
		source_icon: Starting icon
		icon_registry: IconRegistry or dictionary
		radius: Maximum hop distance

	Returns:
		Array of emoji strings within radius
	"""
	var source_emoji = source_icon.emoji
	var visited = {source_emoji: 0}
	var queue = [source_emoji]

	while queue.size() > 0:
		var current = queue.pop_front()
		var current_dist = visited[current]

		if current_dist >= radius:
			continue

		var icon = _get_icon(icon_registry, current)
		if icon == null:
			continue

		# Get all coupled emojis (neighbors in the coupling graph)
		var neighbors = _get_coupled_emojis(icon)

		for neighbor in neighbors:
			if not visited.has(neighbor):
				visited[neighbor] = current_dist + 1
				queue.append(neighbor)

	# Remove source emoji from results
	visited.erase(DRIFT_EMOJI)
	return visited.keys()


## Get all emojis coupled to an icon
static func _get_coupled_emojis(icon) -> Array:
	"""Get emojis this icon is coupled to

	Args:
		icon: Icon to check

	Returns:
		Array of emoji strings
	"""
	var coupled = []

	# Hamiltonian couplings
	for target in icon.hamiltonian_couplings.keys():
		if target not in coupled:
			coupled.append(target)

	# Lindblad outgoing
	for target in icon.lindblad_outgoing.keys():
		if target not in coupled:
			coupled.append(target)

	# Lindblad incoming
	for source in icon.lindblad_incoming.keys():
		if source not in coupled:
			coupled.append(source)

	# Energy couplings
	for observable in icon.energy_couplings.keys():
		if observable not in coupled:
			coupled.append(observable)

	return coupled


## Helper: Get probability from bath/quantum_computer
static func _get_probability(bath, emoji: String) -> float:
	"""Safely get probability of emoji from bath or QuantumComputer

	Supports multiple interfaces:
	- QuantumComputer: get_population(emoji)
	- Bath: get_probability(emoji)
	- DensityMatrix access: _density_matrix.get_probability_by_index()
	"""
	if bath == null:
		return 0.0

	# Try QuantumComputer method (Model C architecture)
	if bath.has_method("get_population"):
		return bath.get_population(emoji)

	# Try legacy bath method
	if bath.has_method("get_probability"):
		return bath.get_probability(emoji)

	# Try density matrix
	if bath.get("_density_matrix"):
		var dm = bath._density_matrix
		var idx = dm.emoji_to_index.get(emoji, -1)
		if idx >= 0:
			return dm.get_probability_by_index(idx)

	return 0.0


## Helper: Get icon from registry
static func _get_icon(icon_registry, emoji: String):
	"""Safely get icon from registry (handles both IconRegistry and Dictionary)"""
	if icon_registry == null:
		return null

	# IconRegistry singleton
	if icon_registry.has_method("get_icon"):
		return icon_registry.get_icon(emoji)

	# Dictionary
	if icon_registry is Dictionary:
		return icon_registry.get(emoji, null)

	return null


## Calculate current drift intensity (for UI display)
static func get_drift_intensity(bath) -> float:
	"""Get current drift intensity (0-1 scale)

	Args:
		bath: Quantum bath

	Returns:
		Drift intensity for display (0 = stable, 1 = maximum chaos)
	"""
	if bath == null:
		return 0.0

	var spiral_pop = _get_probability(bath, DRIFT_EMOJI)
	var sparkle_pop = _get_probability(bath, STABILIZER_EMOJI)

	var net_drift = spiral_pop - (sparkle_pop * STABILIZER_FACTOR)

	# Normalize to 0-1 scale (assuming max useful drift is ~0.3)
	return clamp(net_drift / 0.3, 0.0, 1.0)


## Check if drift is currently active
static func is_drift_active(bath) -> bool:
	"""Check if drift is currently affecting the system

	Args:
		bath: Quantum bath

	Returns:
		True if drift is active
	"""
	if bath == null:
		return false

	var spiral_pop = _get_probability(bath, DRIFT_EMOJI)
	var sparkle_pop = _get_probability(bath, STABILIZER_EMOJI)

	var net_drift = spiral_pop - (sparkle_pop * STABILIZER_FACTOR)

	return net_drift >= DRIFT_THRESHOLD


## Get drift status text for UI
static func get_drift_status(bath) -> String:
	"""Get human-readable drift status

	Args:
		bath: Quantum bath

	Returns:
		Status string
	"""
	if not is_drift_active(bath):
		return "Stable"

	var intensity = get_drift_intensity(bath)

	if intensity < 0.2:
		return "Minor fluctuations"
	elif intensity < 0.5:
		return "Semantic drift"
	elif intensity < 0.8:
		return "Reality wavering"
	else:
		return "CHAOS STORM"
