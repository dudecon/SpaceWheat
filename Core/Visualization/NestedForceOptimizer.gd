class_name NestedForceOptimizer
extends RefCounted

## Nested Force Graph Optimizer
##
## Two-level hierarchical force calculation:
## 1. Meta-level: 6 biome centers (driven by BiomeMetaQuantum)
## 2. Inner-level: 4 bubbles per biome (6 × 4×4 = 96 pairs)
## Total: 132 pairs vs flat 576 pairs (4.4× reduction)
##
## The meta-level uses a 6×6 density matrix where:
## - ρ̃[i,i] = biome "weight" (activity level)
## - ρ̃[i,j] = biome "coherence" (meta-entanglement)
## - I(i:j) = mutual information (clustering strength)

const BiomeMetaQuantum = preload("res://Core/Visualization/BiomeMetaQuantum.gd")

# Force constants (same physics, just partitioned)
const CORRELATION_SPRING = 0.02    # Reduced from 0.12 to prevent over-clustering
const MI_LOW_BOOST = 0.05          # Minimum MI floor to keep bubbles loosely clustered
const REPULSION_STRENGTH = 600.0   # Prevents overlap (2x boost for stronger separation)
const MIN_DISTANCE = 15.0
const DAMPING = 0.85

# Meta-level constants
const META_REPULSION = 16000.0
const META_WEIGHT_ATTRACTION = 200.0  # Pull high-weight biomes to center
const META_COHERENCE_SPRING = 150.0   # Coherent biomes attract
const META_MI_SPRING = 100.0          # High MI biomes cluster
const META_DAMPING = 0.92
const BIOME_RADIUS = 120.0  # Max radius for bubbles within biome

# Meta-quantum system
var meta_quantum: BiomeMetaQuantum = null

# Biome data structures
var biome_graphs: Dictionary = {}  # biome_name -> BiomeInnerGraph
var biome_indices: Dictionary = {}  # biome_name -> int (index in meta system)
var meta_positions: Dictionary = {}  # biome_name -> Vector2 (center)
var meta_velocities: Dictionary = {}  # biome_name -> Vector2


class BiomeInnerGraph:
	var biome_name: String
	var center: Vector2
	var bubbles: Array = []  # QuantumNode references
	var local_positions: Dictionary = {}  # node_id -> Vector2
	var local_velocities: Dictionary = {}  # node_id -> Vector2

	# Cached aggregate properties (for meta-level)
	var mean_purity: float = 0.5
	var total_coherence: float = 0.0
	var dominant_pole: int = 0  # 0=north, 1=south

	func _init(name: String):
		biome_name = name

	func add_bubble(node) -> void:
		if node not in bubbles:
			bubbles.append(node)
			local_positions[node.get_instance_id()] = Vector2.ZERO
			local_velocities[node.get_instance_id()] = Vector2.ZERO

	func remove_bubble(node) -> void:
		bubbles.erase(node)
		local_positions.erase(node.get_instance_id())
		local_velocities.erase(node.get_instance_id())

	func update_aggregates() -> void:
		"""Compute aggregate properties for meta-level forces."""
		if bubbles.is_empty():
			mean_purity = 0.5
			total_coherence = 0.0
			return

		var purity_sum = 0.0
		var coherence_sum = 0.0
		var north_count = 0

		for bubble in bubbles:
			purity_sum += bubble.energy if bubble else 0.5
			coherence_sum += bubble.coherence if bubble else 0.0
			if bubble and bubble.color.h < 0.5:
				north_count += 1

		mean_purity = purity_sum / bubbles.size()
		total_coherence = coherence_sum
		dominant_pole = 0 if north_count > bubbles.size() / 2 else 1


func initialize(biome_array: Array) -> void:
	"""Set up inner graphs for each biome and meta-quantum system."""
	biome_graphs.clear()
	biome_indices.clear()
	meta_positions.clear()
	meta_velocities.clear()

	# Meta-quantum system disabled for now (native Eigen matrix dimension bug)
	# TODO: Fix BiomeMetaQuantum to work with native ComplexMatrix backend
	meta_quantum = null

	# Initialize with default hexagonal layout
	var hex_positions = _generate_hex_layout(biome_array.size())

	for i in range(biome_array.size()):
		var biome = biome_array[i]
		if not biome:
			continue

		var name = biome.get_biome_type() if biome.has_method("get_biome_type") else "Biome%d" % i
		biome_graphs[name] = BiomeInnerGraph.new(name)
		biome_indices[name] = i
		meta_positions[name] = hex_positions[i] if i < hex_positions.size() else Vector2.ZERO
		meta_velocities[name] = Vector2.ZERO

	print("NestedForceOptimizer: Initialized %d biomes with meta-quantum system" % biome_array.size())


func _generate_hex_layout(count: int) -> Array:
	"""Generate hexagonal positions for biome centers."""
	var positions = []
	var center = Vector2(400, 300)  # Will be overridden by actual graph center
	var radius = 200.0

	for i in range(count):
		var angle = (float(i) / count) * TAU - PI / 2
		positions.append(center + Vector2(cos(angle), sin(angle)) * radius)

	return positions


func register_bubble(node, biome_name: String) -> void:
	"""Register a bubble with its biome's inner graph."""
	if not biome_graphs.has(biome_name):
		biome_graphs[biome_name] = BiomeInnerGraph.new(biome_name)
		meta_positions[biome_name] = Vector2.ZERO
		meta_velocities[biome_name] = Vector2.ZERO

	biome_graphs[biome_name].add_bubble(node)


func unregister_bubble(node, biome_name: String) -> void:
	"""Remove a bubble from its biome's inner graph."""
	if biome_graphs.has(biome_name):
		biome_graphs[biome_name].remove_bubble(node)


func update(delta: float, mi_cache: Dictionary, graph_center: Vector2) -> void:
	"""Update both levels of the force graph.

	Args:
		delta: Time step
		mi_cache: {biome_name -> PackedFloat64Array} mutual information per biome
		graph_center: Center of the overall graph area
	"""
	# Phase 1: Evolve meta-quantum system (updates 6×6 density matrix)
	if meta_quantum:
		meta_quantum.evolve(delta)

	# Phase 2: Update inner graph aggregates (for legacy compatibility)
	for biome_name in biome_graphs:
		biome_graphs[biome_name].update_aggregates()

	# Phase 3: Meta-level forces (biome centers from meta-quantum)
	_update_meta_level(delta, graph_center)

	# Phase 4: Inner-level forces (bubbles within each biome)
	for biome_name in biome_graphs:
		var inner = biome_graphs[biome_name]
		var mi = mi_cache.get(biome_name, PackedFloat64Array())
		_update_inner_graph(delta, inner, mi)


func _update_meta_level(delta: float, graph_center: Vector2) -> void:
	"""Update biome center positions using meta-quantum forces.

	Forces derived from 6×6 meta-density-matrix:
	1. Weight attraction: High ρ̃[i,i] → pull to center
	2. Coherence spring: High |ρ̃[i,j]| → biomes attract
	3. MI clustering: High I(i:j) → biomes cluster
	4. Repulsion: Prevent overlap
	"""
	var biome_names_list = biome_graphs.keys()

	for biome_name in biome_names_list:
		var force = Vector2.ZERO
		var pos = meta_positions[biome_name]
		var idx_i = biome_indices.get(biome_name, -1)

		# 1. Weight-based attraction to center
		# Higher meta-population → stronger pull toward graph center
		if meta_quantum and idx_i >= 0:
			var weight = meta_quantum.get_biome_weight(idx_i)
			var to_center = graph_center - pos
			force += to_center * weight * META_WEIGHT_ATTRACTION * 0.01

		# 2 & 3. Coherence and MI-based forces with other biomes
		for other_name in biome_names_list:
			if other_name == biome_name:
				continue

			var other_pos = meta_positions[other_name]
			var delta_pos = other_pos - pos
			var dist = delta_pos.length()

			if dist < 1.0:
				continue

			var direction = delta_pos.normalized()
			var idx_j = biome_indices.get(other_name, -1)

			# Repulsion (always)
			if dist < BIOME_RADIUS * 3:
				var repulsion = META_REPULSION / max(dist * dist, 100.0)
				force -= direction * repulsion

			# Coherence attraction (from meta-quantum)
			if meta_quantum and idx_i >= 0 and idx_j >= 0:
				var coherence = meta_quantum.get_biome_coherence(idx_i, idx_j)
				if coherence > 0.01:
					# Attract proportional to coherence
					var ideal_dist = BIOME_RADIUS * 2.5 * (1.0 - coherence)
					var displacement = dist - ideal_dist
					force += direction * displacement * coherence * META_COHERENCE_SPRING * 0.01

				# MI clustering (from meta-quantum)
				var mi = meta_quantum.get_biome_mutual_info(idx_i, idx_j)
				if mi > 0.01:
					# High MI → cluster together
					var ideal_dist_mi = BIOME_RADIUS * 2.0 / (1.0 + mi)
					var displacement_mi = dist - ideal_dist_mi
					force += direction * displacement_mi * mi * META_MI_SPRING * 0.01

		# Fallback: gentle centering if no meta-quantum
		if not meta_quantum:
			var to_center = graph_center - pos
			force += to_center * 0.01

		# Apply force
		meta_velocities[biome_name] += force * delta
		meta_velocities[biome_name] *= META_DAMPING
		meta_positions[biome_name] += meta_velocities[biome_name] * delta

		# Update inner graph center
		biome_graphs[biome_name].center = meta_positions[biome_name]


func _update_inner_graph(delta: float, inner: BiomeInnerGraph, mi: PackedFloat64Array) -> void:
	"""Update bubble positions within a single biome (4×4 force pairs max)."""
	var num_bubbles = inner.bubbles.size()
	if num_bubbles == 0:
		return

	var center = inner.center

	for i in range(num_bubbles):
		var bubble = inner.bubbles[i]
		if not bubble:
			continue

		var node_id = bubble.get_instance_id()
		var local_pos = inner.local_positions.get(node_id, Vector2.ZERO)
		var force = Vector2.ZERO

		# 1. Correlation forces (MI-based, within this biome only)
		for j in range(num_bubbles):
			if i == j:
				continue
			var other = inner.bubbles[j]
			if not other:
				continue

			var other_id = other.get_instance_id()
			var other_pos = inner.local_positions.get(other_id, Vector2.ZERO)

			# Get MI for this pair (upper triangular index)
			var mi_val = _get_mi_value(i, j, num_bubbles, mi)
			force += _correlation_force(local_pos, other_pos, mi_val)

		# 2. Repulsion (prevent overlap)
		for j in range(num_bubbles):
			if i == j:
				continue
			var other = inner.bubbles[j]
			if not other:
				continue
			var other_id = other.get_instance_id()
			var other_pos = inner.local_positions.get(other_id, Vector2.ZERO)
			force += _repulsion_force(local_pos, other_pos)

		# 4. Containment (keep within biome radius)
		var dist_from_center = local_pos.length()
		if dist_from_center > BIOME_RADIUS:
			force += -local_pos.normalized() * (dist_from_center - BIOME_RADIUS) * 0.5

		# Apply forces
		var vel = inner.local_velocities.get(node_id, Vector2.ZERO)
		vel += force * delta
		vel *= DAMPING
		local_pos += vel * delta

		inner.local_velocities[node_id] = vel
		inner.local_positions[node_id] = local_pos

		# Update bubble's world position
		bubble.position = center + local_pos


# REMOVED: Purity radial force - purity should come from C++ bloch packet, not node.energy


func _correlation_force(pos: Vector2, other_pos: Vector2, mi: float) -> Vector2:
	"""High MI → attract, low MI → loose clustering."""
	# Boost low MI to keep bubbles loosely clustered (prevents explosion)
	var mi_boosted = max(mi, MI_LOW_BOOST)

	var delta_pos = other_pos - pos
	var dist = delta_pos.length()
	if dist < 1.0:
		return Vector2.ZERO

	var target_dist = 80.0 / (1.0 + 3.0 * mi_boosted)
	var displacement = dist - target_dist

	return delta_pos.normalized() * displacement * CORRELATION_SPRING * mi_boosted


func _repulsion_force(pos: Vector2, other_pos: Vector2) -> Vector2:
	"""Prevent bubble overlap."""
	var delta_pos = pos - other_pos
	var dist = delta_pos.length()

	if dist < MIN_DISTANCE:
		dist = MIN_DISTANCE

	return delta_pos.normalized() * REPULSION_STRENGTH / (dist * dist)


func _get_mi_value(i: int, j: int, num_qubits: int, mi: PackedFloat64Array) -> float:
	"""Get MI value from packed array (upper triangular order)."""
	if mi.is_empty():
		return 0.0

	# Ensure i < j for lookup
	var a = mini(i, j)
	var b = maxi(i, j)

	# Upper triangular index: a * (2n - a - 1) / 2 + (b - a - 1)
	var idx = a * (2 * num_qubits - a - 1) / 2 + (b - a - 1)

	if idx < 0 or idx >= mi.size():
		return 0.0

	return mi[idx]


func get_biome_center(biome_name: String) -> Vector2:
	"""Get current center position for a biome."""
	return meta_positions.get(biome_name, Vector2.ZERO)


func get_bubble_world_position(node, biome_name: String) -> Vector2:
	"""Get world position for a bubble."""
	if not biome_graphs.has(biome_name):
		return Vector2.ZERO

	var inner = biome_graphs[biome_name]
	var local_pos = inner.local_positions.get(node.get_instance_id(), Vector2.ZERO)
	return inner.center + local_pos


# ============================================================================
# META-QUANTUM INTEGRATION
# ============================================================================

func on_player_action(biome_name: String, strength: float = 0.3) -> void:
	"""Notify meta-quantum of player action in a biome.

	Increases that biome's weight in the meta-density-matrix,
	making it more prominent in the force graph.
	"""
	if not meta_quantum:
		return

	var idx = biome_indices.get(biome_name, -1)
	if idx >= 0:
		meta_quantum.inject_player_action(idx, strength)


func on_biome_connection(biome_a: String, biome_b: String, strength: float = 0.2) -> void:
	"""Create meta-entanglement between biomes.

	Called when player builds trade route, completes quest linking biomes, etc.
	Makes the biomes cluster together in the force graph.
	"""
	if not meta_quantum:
		return

	var idx_a = biome_indices.get(biome_a, -1)
	var idx_b = biome_indices.get(biome_b, -1)

	if idx_a >= 0 and idx_b >= 0:
		meta_quantum.create_biome_entanglement(idx_a, idx_b, strength)


func get_meta_quantum_debug() -> String:
	"""Get debug output of meta-quantum state."""
	if meta_quantum:
		return meta_quantum.get_debug_string()
	return "Meta-quantum not initialized"


func get_all_meta_mi() -> Array:
	"""Get all pairwise meta-level mutual information.

	Returns: Array of {biome_i: String, biome_j: String, mi: float}
	"""
	if not meta_quantum:
		return []

	var result = []
	var biome_names_list = biome_graphs.keys()

	for entry in meta_quantum.get_all_meta_mi():
		var name_i = biome_names_list[entry.i] if entry.i < biome_names_list.size() else "?"
		var name_j = biome_names_list[entry.j] if entry.j < biome_names_list.size() else "?"
		result.append({
			"biome_i": name_i,
			"biome_j": name_j,
			"mi": entry.mi
		})

	return result
