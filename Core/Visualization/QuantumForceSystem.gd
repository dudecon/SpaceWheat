class_name QuantumForceSystem
extends RefCounted

## Quantum Force System - Physics-Grounded Bubble Dynamics
##
## Forces are derived from quantum observables:
##
## 1. HAMILTONIAN ATTRACTION: H coupling strength → base attraction
##    Emojis connected by Hamiltonian off-diagonals attract
##
## 2. MI BOOST: Mutual information amplifies attraction
##    Correlated (entangled) pairs attract more strongly
##
## 3. REPULSION: Inverse-square prevents overlap
##
## 4. QUANTUM MOMENTUM: dP/dt drives velocity
##    When populations oscillate, bubbles physically respond
##
## Color encodes phase (φ) - no angular force needed.


# === FORCE CONSTANTS ===
const H_SPRING = 8.0           # Hamiltonian coupling → attraction strength
const MI_MULTIPLIER = 2.0      # MI boosts H-spring (MI up to 2 bits → up to 4x boost)
const REPULSION = 2500.0       # Inverse-square overlap prevention
const MIN_DISTANCE = 20.0      # Minimum separation for repulsion calc
const MOMENTUM_GAIN = 80.0     # dP/dt → velocity kick (ties to quantum dynamics)
const DRAG = 0.92              # Linear velocity damping per frame
const BASE_SEPARATION = 100.0  # Natural separation when no forces


# === CACHED DATA ===
var _coupling_cache: Dictionary = {}   # (node_a_id, node_b_id) → coupling_strength
var _mi_cache: Dictionary = {}         # (node_a_id, node_b_id) → mutual_info
var _prev_population: Dictionary = {}  # node_id → previous north_opacity (for dP/dt)
var _cache_timer: float = 0.0
const CACHE_INTERVAL = 0.1             # Refresh caches at 10Hz


func update(delta: float, nodes: Array, ctx: Dictionary) -> void:
	"""Update forces and positions for all quantum nodes."""
	var biomes = ctx.get("biomes", {})
	var layout_calculator = ctx.get("layout_calculator")

	# Refresh caches periodically
	_cache_timer += delta
	if _cache_timer >= CACHE_INTERVAL:
		_cache_timer = 0.0
		_refresh_caches(nodes, biomes)

	# Build active node list
	var active_nodes: Array = []
	for node in nodes:
		if _is_active(node):
			active_nodes.append(node)

	# Calculate and apply forces
	for node in active_nodes:
		# Skip frozen nodes
		if node.is_lifeless or _is_measured(node):
			node.velocity = Vector2.ZERO
			continue

		var total_force = Vector2.ZERO

		# 1. Hamiltonian + MI attraction to coupled nodes
		total_force += _calc_coupling_forces(node, active_nodes, biomes)

		# 2. Repulsion from all nodes
		total_force += _calc_repulsion(node, active_nodes)

		# 3. Quantum momentum from population change
		total_force += _calc_momentum(node)

		# Apply force (F = ma, mass = probability)
		var mass = clampf(node.emoji_north_opacity + node.emoji_south_opacity, 0.1, 1.0)
		node.velocity += (total_force / mass) * delta

		# Apply drag
		node.velocity *= DRAG

	# Update positions
	for node in active_nodes:
		if not node.is_lifeless and not _is_measured(node):
			node.position += node.velocity * delta


func _calc_coupling_forces(node, active_nodes: Array, biomes: Dictionary) -> Vector2:
	"""Calculate attraction from Hamiltonian couplings, boosted by MI."""
	var force = Vector2.ZERO
	var node_id = node.get_instance_id()

	for other in active_nodes:
		if other == node:
			continue
		if other.biome_name != node.biome_name:
			continue  # Only couple within same biome

		var other_id = other.get_instance_id()
		var key = _cache_key(node_id, other_id)

		# Get cached coupling strength (from Hamiltonian)
		var h_coupling = _coupling_cache.get(key, 0.0)
		if h_coupling < 0.001:
			continue  # No Hamiltonian connection

		# Get MI boost
		var mi = _mi_cache.get(key, 0.0)
		var mi_boost = 1.0 + MI_MULTIPLIER * mi  # MI=0 → 1x, MI=2 → 5x

		# Direction and distance
		var delta_pos = other.position - node.position
		var distance = delta_pos.length()
		if distance < 1.0:
			continue

		var direction = delta_pos.normalized()

		# Spring force toward coupled partner
		# Target distance decreases with coupling strength
		var target_dist = BASE_SEPARATION / (1.0 + h_coupling * 2.0)
		var displacement = distance - target_dist

		# Attractive spring: F = k * displacement * coupling * mi_boost
		force += direction * displacement * H_SPRING * h_coupling * mi_boost

	return force


func _calc_repulsion(node, active_nodes: Array) -> Vector2:
	"""Inverse-square repulsion to prevent overlap."""
	var force = Vector2.ZERO

	for other in active_nodes:
		if other == node:
			continue

		var delta_pos = node.position - other.position
		var distance = max(delta_pos.length(), MIN_DISTANCE)

		# F = k / r²
		var magnitude = REPULSION / (distance * distance)
		force += delta_pos.normalized() * magnitude

	return force


func _calc_momentum(node) -> Vector2:
	"""Calculate momentum kick from population change rate (dP/dt).

	When quantum state oscillates, the bubble should physically respond.
	This ties the force graph animation to the quantum dynamics timescale.
	"""
	var node_id = node.get_instance_id()
	var current_pop = node.emoji_north_opacity
	var prev_pop = _prev_population.get(node_id, current_pop)

	# Store for next frame
	_prev_population[node_id] = current_pop

	# dP/dt
	var dP = current_pop - prev_pop
	if abs(dP) < 0.001:
		return Vector2.ZERO

	# Kick in radial direction from biome center
	# Positive dP (gaining north population) → outward kick
	# Negative dP (losing north population) → inward kick
	var direction = node.velocity.normalized() if node.velocity.length() > 1.0 else Vector2.RIGHT.rotated(randf() * TAU)

	return direction * dP * MOMENTUM_GAIN


func _refresh_caches(nodes: Array, biomes: Dictionary) -> void:
	"""Refresh coupling and MI caches from viz_cache."""
	_coupling_cache.clear()
	_mi_cache.clear()

	# Group nodes by biome
	var by_biome: Dictionary = {}
	for node in nodes:
		if not _is_active(node):
			continue
		var bn = node.biome_name
		if bn.is_empty():
			continue
		if not by_biome.has(bn):
			by_biome[bn] = []
		by_biome[bn].append(node)

	# Cache couplings and MI for each biome
	for biome_name in by_biome:
		var biome = biomes.get(biome_name)
		if not biome or not biome.viz_cache:
			continue

		var biome_nodes = by_biome[biome_name]

		for i in range(biome_nodes.size()):
			var node_a = biome_nodes[i]
			var emoji_a = node_a.emoji_north
			var qubit_a = biome.viz_cache.get_qubit(emoji_a)

			# Get Hamiltonian couplings for this emoji
			var h_couplings = biome.viz_cache.get_hamiltonian_couplings(emoji_a)

			for j in range(i + 1, biome_nodes.size()):
				var node_b = biome_nodes[j]
				var emoji_b = node_b.emoji_north
				var qubit_b = biome.viz_cache.get_qubit(emoji_b)

				var key = _cache_key(node_a.get_instance_id(), node_b.get_instance_id())

				# Hamiltonian coupling (check both directions)
				var h_ab = abs(h_couplings.get(emoji_b, 0.0))
				var h_ba_dict = biome.viz_cache.get_hamiltonian_couplings(emoji_b)
				var h_ba = abs(h_ba_dict.get(emoji_a, 0.0))
				var h_strength = max(h_ab, h_ba)

				_coupling_cache[key] = h_strength
				_coupling_cache[_cache_key(node_b.get_instance_id(), node_a.get_instance_id())] = h_strength

				# Mutual information
				if qubit_a >= 0 and qubit_b >= 0:
					var mi = biome.viz_cache.get_mutual_information(qubit_a, qubit_b)
					_mi_cache[key] = mi
					_mi_cache[_cache_key(node_b.get_instance_id(), node_a.get_instance_id())] = mi


func _cache_key(id_a: int, id_b: int) -> String:
	return "%d_%d" % [id_a, id_b]


func _is_active(node) -> bool:
	"""Node is active if it has biome assignment and emoji data."""
	if not node:
		return false
	return node.biome_name != "" and not node.emoji_north.is_empty()


func _is_measured(node) -> bool:
	"""Check if node has been measured (frozen)."""
	if not node:
		return false
	# Terminal-based measurement
	if node.terminal and node.terminal.is_measured:
		return true
	# Plot-based measurement (legacy)
	if node.plot and node.plot.has_been_measured:
		return true
	return false


# === PUBLIC API FOR EDGE RENDERER ===

func get_quantum_coupling_strength(node_a, node_b) -> float:
	"""Get effective coupling strength between two nodes (for edge rendering).

	Returns combined metric: Hamiltonian coupling × MI boost
	This matches the force calculation in _calc_coupling_forces().
	"""
	if not node_a or not node_b:
		return 0.0

	# Different biomes don't couple
	if node_a.biome_name != node_b.biome_name:
		return 0.0

	var node_a_id = node_a.get_instance_id()
	var node_b_id = node_b.get_instance_id()
	var key = _cache_key(node_a_id, node_b_id)

	# Get Hamiltonian coupling from cache
	var h_coupling = _coupling_cache.get(key, 0.0)
	if h_coupling < 0.001:
		return 0.0

	# Get MI boost from cache
	var mi = _mi_cache.get(key, 0.0)
	var mi_boost = 1.0 + MI_MULTIPLIER * mi  # MI=0 → 1x, MI=2 → 5x

	# Return combined strength (raw value, not spring force)
	return h_coupling * mi_boost
