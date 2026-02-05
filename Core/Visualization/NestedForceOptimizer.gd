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

# Force constants - calibrated for screen-space pixels
# Integration: vel += force * dt, pos += vel * dt → need forces ~100-300 for ~30 px/sec movement
const REPULSION_STRENGTH = 6000.0   # Inverse-linear: force = R/dist (not R/dist²)
const CORRELATION_SPRING = 30.0     # MI-based attraction: force = displacement * spring * mi
const MI_LOW_BOOST = 0.05           # Minimum MI floor for loose clustering
const MIN_DISTANCE = 20.0
const DAMPING = 0.92

# Meta-level constants
const META_REPULSION = 8000.0
const META_CENTERING = 5.0            # Pull biomes toward graph center
const META_DAMPING = 0.90
const BIOME_RADIUS = 150.0

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
			# Initialize with scattered position (not zero - prevents all bubbles stacking)
			var scatter_angle = bubbles.size() * 2.4  # Golden angle spread
			var scatter_radius = 30.0 + randf() * 40.0
			var initial_pos = Vector2(cos(scatter_angle), sin(scatter_angle)) * scatter_radius
			local_positions[node.get_instance_id()] = initial_pos
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

	# Verbose logging moved to VerboseConfig
	var verbose = _get_verbose()
	if verbose:
		verbose.debug("viz", "🌐", "NestedForceOptimizer: Initialized %d biomes" % biome_array.size())


func _generate_hex_layout(count: int) -> Array:
	"""Generate hexagonal positions for biome centers."""
	var positions = []
	var center = Vector2(400, 300)  # Will be overridden by actual graph center
	var radius = 200.0

	for i in range(count):
		var angle = (float(i) / count) * TAU - PI / 2
		positions.append(center + Vector2(cos(angle), sin(angle)) * radius)

	return positions


func register_bubble(node, biome_name: String, graph_center: Vector2 = Vector2.ZERO) -> void:
	"""Register a bubble with its biome's inner graph.

	Args:
		node: QuantumNode to register
		biome_name: Name of the biome this bubble belongs to
		graph_center: Fallback center if biome doesn't have a position yet
	"""
	if not biome_graphs.has(biome_name):
		biome_graphs[biome_name] = BiomeInnerGraph.new(biome_name)
		# Use graph_center as fallback instead of (0,0) to avoid corner clustering
		meta_positions[biome_name] = graph_center if graph_center != Vector2.ZERO else Vector2(400, 300)
		meta_velocities[biome_name] = Vector2.ZERO

	var inner = biome_graphs[biome_name]
	inner.add_bubble(node)

	# Update inner graph center from meta_positions
	inner.center = meta_positions.get(biome_name, graph_center)

	# Initialize local position from bubble's current world position
	# (relative to biome center, so forces work correctly)
	if node and "position" in node:
		var center = inner.center if inner.center != Vector2.ZERO else graph_center
		if center != Vector2.ZERO and node.position != Vector2.ZERO:
			var local_pos = node.position - center
			inner.local_positions[node.get_instance_id()] = local_pos


func unregister_bubble(node, biome_name: String) -> void:
	"""Remove a bubble from its biome's inner graph."""
	if biome_graphs.has(biome_name):
		biome_graphs[biome_name].remove_bubble(node)


var _frame_count: int = 0
var _prev_sample_pos: Vector2 = Vector2.ZERO

func update(delta: float, mi_cache: Dictionary, graph_center: Vector2) -> void:
	"""Update both levels of the force graph.

	Args:
		delta: Time step
		mi_cache: {biome_name -> PackedFloat64Array} mutual information per biome
		graph_center: Center of the overall graph area
	"""
	_frame_count += 1

	# Phase 1: Evolve meta-quantum system (updates 6×6 density matrix)
	if meta_quantum:
		meta_quantum.evolve(delta)

	# Phase 2: Update inner graph aggregates (for legacy compatibility)
	for biome_name in biome_graphs:
		biome_graphs[biome_name].update_aggregates()

	# Phase 3: Meta-level forces (biome centers from meta-quantum)
	_update_meta_level(delta, graph_center)

	# Phase 4: Inner-level forces (bubbles within each biome)
	# Attraction is siloed by biome (MI correlation), repulsion is same-biome only here
	for biome_name in biome_graphs:
		var inner = biome_graphs[biome_name]
		var mi = mi_cache.get(biome_name, PackedFloat64Array())
		_update_inner_graph(delta, inner, mi)

	# Phase 5: Cross-biome repulsion (all bubbles repel all other bubbles)
	_apply_cross_biome_repulsion(delta)


func _update_meta_level(delta: float, graph_center: Vector2) -> void:
	"""Update biome center positions.

	Forces:
	1. Centering: Pull all biome centers gently toward graph center
	2. Repulsion: Biome centers repel each other (inverse-linear)
	"""
	var biome_names_list = biome_graphs.keys()

	for biome_name in biome_names_list:
		var force = Vector2.ZERO
		var pos = meta_positions[biome_name]

		# 1. Centering force (spring toward graph center)
		var to_center = graph_center - pos
		force += to_center * META_CENTERING

		# 2. Repulsion between biome centers (inverse-linear)
		for other_name in biome_names_list:
			if other_name == biome_name:
				continue

			var other_pos = meta_positions[other_name]
			var delta_pos = pos - other_pos
			var dist = delta_pos.length()

			if dist < 1.0:
				dist = 1.0

			if dist < BIOME_RADIUS * 4:
				# Inverse-linear repulsion between biome centers
				var direction = delta_pos / dist
				force += direction * META_REPULSION / dist

		# Apply force (Euler integration)
		meta_velocities[biome_name] += force * delta
		meta_velocities[biome_name] *= META_DAMPING

		# Safety: clamp meta velocity
		var meta_speed = meta_velocities[biome_name].length()
		if meta_speed > 300.0:
			meta_velocities[biome_name] = meta_velocities[biome_name] * (300.0 / meta_speed)

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
		# Quadratic spring — force grows with square of overshoot
		var dist_from_center = local_pos.length()
		if dist_from_center > BIOME_RADIUS * 0.7:
			var overshoot = dist_from_center - BIOME_RADIUS * 0.7
			var containment_strength = 20.0 + overshoot * 2.0
			force += -local_pos.normalized() * overshoot * containment_strength

		# Apply forces (Euler integration)
		var vel = inner.local_velocities.get(node_id, Vector2.ZERO)
		vel += force * delta
		vel *= DAMPING

		# Safety: clamp velocity to prevent NaN explosion
		var speed = vel.length()
		if speed > 500.0:
			vel = vel * (500.0 / speed)

		local_pos += vel * delta

		inner.local_velocities[node_id] = vel
		inner.local_positions[node_id] = local_pos

		# Update bubble's world position
		bubble.position = center + local_pos

		# DIAG: Trace first bubble per biome for first 10 frames + every 120
		if i == 0 and (_frame_count <= 10 or _frame_count % 120 == 0):
			var pos_change = vel * delta
			print("[FORCE_DIAG] frame=%d biome=%s | local_pos=(%.1f,%.1f) dist=%.1f | force=%.1f vel=%.2f pos_change=%.3f | center=%s world=%s delta=%.4f" % [
				_frame_count, inner.biome_name,
				local_pos.x, local_pos.y, dist_from_center,
				force.length(), speed, pos_change.length(),
				center, bubble.position, delta])


func _apply_cross_biome_repulsion(delta: float) -> void:
	"""Apply repulsion between ALL bubbles across different biomes.

	Attraction is siloed by biome (only same-biome MI correlation attracts).
	Repulsion is global (every bubble pushes every other bubble away).
	Uses inverse-linear falloff, same as inner repulsion.
	"""
	# Collect all bubbles with their biome name for cross-biome check
	var all_bubbles: Array = []
	for biome_name in biome_graphs:
		var inner = biome_graphs[biome_name]
		for bubble in inner.bubbles:
			if bubble:
				all_bubbles.append({"bubble": bubble, "biome": biome_name})

	var n = all_bubbles.size()
	if n < 2:
		return

	# Apply pairwise repulsion between bubbles from DIFFERENT biomes
	for i in range(n):
		var a = all_bubbles[i]
		var bubble_a = a["bubble"]

		for j in range(i + 1, n):
			var b = all_bubbles[j]

			# Skip same-biome pairs (already handled by inner graph)
			if a["biome"] == b["biome"]:
				continue

			var bubble_b = b["bubble"]
			var delta_pos = bubble_a.position - bubble_b.position
			var dist = delta_pos.length()

			if dist < 1.0:
				dist = 1.0

			if dist > BIOME_RADIUS * 4:
				continue  # Too far to matter

			# Inverse-linear repulsion (consistent with inner graph)
			var direction = delta_pos / dist
			var magnitude = REPULSION_STRENGTH / dist

			# Apply as velocity impulse (not position — avoids bypassing integration)
			var impulse = direction * minf(magnitude, 2000.0) * delta

			# Update local velocities so the inner graph stays consistent
			var inner_a = biome_graphs[a["biome"]]
			var inner_b = biome_graphs[b["biome"]]
			var id_a = bubble_a.get_instance_id()
			var id_b = bubble_b.get_instance_id()
			inner_a.local_velocities[id_a] = inner_a.local_velocities.get(id_a, Vector2.ZERO) + impulse
			inner_b.local_velocities[id_b] = inner_b.local_velocities.get(id_b, Vector2.ZERO) - impulse


# REMOVED: Purity radial force - purity should come from C++ bloch packet, not node.energy


func _correlation_force(pos: Vector2, other_pos: Vector2, mi: float) -> Vector2:
	"""MI-based spring: high MI → attract to close distance, low MI → loose."""
	var mi_eff = max(mi, MI_LOW_BOOST)

	var delta_pos = other_pos - pos
	var dist = delta_pos.length()
	if dist < 1.0:
		return Vector2.ZERO

	# Target distance shrinks with MI (high MI = close together)
	var target_dist = 80.0 / (1.0 + 5.0 * mi_eff)
	var displacement = dist - target_dist

	return delta_pos.normalized() * displacement * CORRELATION_SPRING * mi_eff


func _repulsion_force(pos: Vector2, other_pos: Vector2) -> Vector2:
	"""Inverse-linear repulsion (appropriate for 2D pixel-space visualization).

	Inverse-square (1/r²) gives <1.0 force at typical pixel distances (30-100px),
	producing ~0.15 px/sec movement with Euler integration. Inverse-linear (1/r)
	gives forces in the 60-200 range, producing ~30 px/sec visible movement.
	"""
	var delta_pos = pos - other_pos
	var dist = delta_pos.length()

	if dist < MIN_DISTANCE:
		dist = MIN_DISTANCE

	# Inverse-linear: force ∝ 1/r (not 1/r²)
	return delta_pos.normalized() * REPULSION_STRENGTH / dist


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


func _get_verbose():
	"""Get VerboseConfig autoload."""
	var tree = Engine.get_main_loop()
	if tree and tree.has_method("get_root"):
		var root = tree.get_root()
		if root:
			return root.get_node_or_null("/root/VerboseConfig")
	return null


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
