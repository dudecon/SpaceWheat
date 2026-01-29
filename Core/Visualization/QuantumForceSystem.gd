class_name QuantumForceSystem
extends RefCounted

## Quantum Force System - Physics-Grounded Position Calculation
##
## Replaces arbitrary parametric/tether positions with physics-meaningful forces:
##
## 1. PURITY RADIAL FORCE: Tr(ρ²) determines distance from biome center
##    - Pure states (Tr(ρ²)=1) → center of biome
##    - Mixed states (Tr(ρ²)→0.5) → edge of biome
##
## 2. PHASE ANGULAR FORCE: arg(ρ_01) determines angular position
##    - Same-phase qubits cluster at similar angles
##    - Enables visual identification of coherent groups
##
## 3. CORRELATION FORCE: I(A:B) mutual information determines separation
##    - High mutual info (entangled) → cluster together
##    - Low mutual info (independent) → spread apart
##
## 4. REPULSION FORCE: Prevents overlap for visual clarity


# Physics-grounded force constants
const CORRELATION_SPRING = 0.12  # Strength of mutual information coupling
const PURITY_RADIAL_SPRING = 0.08  # Strength of purity-based radial force
const PHASE_ANGULAR_SPRING = 0.04  # Strength of phase-based angular alignment
const REPULSION_STRENGTH = 1500.0  # Prevents overlap
const MIN_DISTANCE = 15.0  # Minimum distance between nodes
const DAMPING = 0.85  # Velocity damping per frame

# Correlation-based distance scaling
const BASE_DISTANCE = 120.0  # Base separation between uncorrelated bubbles
const CORRELATION_SCALING = 3.0  # How much MI affects clustering
const MAX_BIOME_RADIUS = 250.0  # Maximum radius for mixed states

# Cached mutual information (expensive to compute)
var _mi_cache: Dictionary = {}  # (qubit_a, qubit_b) -> float
var _mi_cache_frame: int = -1  # Frame when cache was last computed
var _mi_throttle_hz: float = 5.0  # How often to recompute MI (Hz)
var _time_since_mi_update: float = 0.0


func update(delta: float, nodes: Array, ctx: Dictionary) -> void:
	"""Update forces and positions for all quantum nodes.

	Args:
	    delta: Time step
	    nodes: Array of QuantumNode instances
	    ctx: Context dictionary with {biomes, layout_calculator, time_accumulator, active_biome, etc.}
	"""
	var biomes = ctx.get("biomes", {})
	var layout_calculator = ctx.get("layout_calculator")
	var plot_pool = ctx.get("plot_pool")
	var active_biome_name = ctx.get("filter_biome", ctx.get("active_biome", ""))  # "" means process all biomes

	# Throttle expensive MI computation (now just reads C++ cache, but still throttle)
	_time_since_mi_update += delta
	if _time_since_mi_update >= 1.0 / _mi_throttle_hz:
		_update_mutual_information_cache(nodes, biomes)
		_time_since_mi_update = 0.0

	# Build list of active (planted/visible) nodes for O(n²) calculations
	# OPTIMIZATION: Only include nodes from active biome if specified
	var active_nodes: Array = []
	for node in nodes:
		if _is_active_node(node):
			# Skip nodes from non-active biomes if filtering is enabled
			if active_biome_name != "" and node.biome_name != active_biome_name:
				continue
			active_nodes.append(node)


	# Calculate and apply forces
	for node in nodes:
		# OPTIMIZATION: Skip force calculations for non-active biomes entirely
		if active_biome_name != "" and node.biome_name != active_biome_name:
			continue

		var total_force = Vector2.ZERO

		# Check plot's quantum behavior (FLOATING=0, HOVERING=1, FIXED=2)
		var quantum_behavior = _get_quantum_behavior(node)

		# FIXED PLOTS: Don't move at all (celestial bodies)
		if quantum_behavior == 2:
			continue

		# HOVERING PLOTS: Fixed relative to anchor (biome measurement plots)
		if quantum_behavior == 1:
			node.position = node.classical_anchor
			continue

		# Skip unplanted nodes
		if not _is_active_node(node):
			continue

		# LIFELESS NODES: No quantum data - freeze at anchor
		if node.is_lifeless:
			node.position = node.classical_anchor
			node.velocity = Vector2.ZERO
			continue

		# Check if measured (v1 plot-based or v2 terminal-based)
		var is_measured = _is_node_measured(node, plot_pool)

		# MEASURED NODES: Freeze at frozen_anchor
		if is_measured:
			if node.frozen_anchor != Vector2.ZERO:
				node.position = node.frozen_anchor
			else:
				node.position = node.classical_anchor
			node.velocity = Vector2.ZERO
			continue

		# === PHYSICS-GROUNDED FORCES FOR UNMEASURED FLOATING NODES ===
		var biome_center = _get_biome_center(node, layout_calculator)

		# 1. Purity radial force: pure→center, mixed→edge
		total_force += _calculate_purity_radial_force(node, biome_center, biomes)

		# 2. Phase angular force: same-phase qubits cluster angularly
		total_force += _calculate_phase_angular_force(node, biome_center, biomes)

		# 3. Correlation forces: entangled bubbles attract
		total_force += _calculate_correlation_forces(node, active_nodes, biomes)

		# 4. Repulsion forces: prevent overlap
		total_force += _calculate_repulsion_forces(node, active_nodes)

		# Apply forces
		node.apply_force(total_force, delta)
		node.apply_damping(DAMPING)

	# Update positions from velocities
	_update_positions(delta, nodes)


func _calculate_purity_radial_force(node, biome_center: Vector2, biomes: Dictionary) -> Vector2:
	"""Calculate radial force based on quantum purity.

	Pure states (Tr(ρ²)=1) are pulled toward biome center.
	Mixed states (Tr(ρ²)→0.5) drift toward biome edge.

	Physics: Purity indicates how "quantum" the state is.
	Pure states have maximum quantum information.
	"""
	if biome_center == Vector2.ZERO:
		return Vector2.ZERO

	# Get purity from node (already cached from visual update)
	var purity = node.energy if node else 0.5
	purity = clampf(purity, 0.5, 1.0)  # Normalize to valid range

	# Target radius: pure → 0 (center), mixed → MAX_BIOME_RADIUS (edge)
	# Linear mapping: r = (1 - purity) / 0.5 * MAX_RADIUS
	var normalized_purity = (purity - 0.5) / 0.5  # 0 = maximally mixed, 1 = pure
	var target_radius = (1.0 - normalized_purity) * MAX_BIOME_RADIUS * 0.8

	# Current position relative to center
	var to_center = biome_center - node.position
	var current_radius = to_center.length()

	if current_radius < 1.0:
		return Vector2.ZERO

	var direction = to_center.normalized()
	var displacement = target_radius - current_radius

	# Spring force toward target radius (negative displacement = pull in)
	return direction * (-displacement) * PURITY_RADIAL_SPRING


func _calculate_phase_angular_force(node, biome_center: Vector2, biomes: Dictionary) -> Vector2:
	"""Calculate angular force based on coherence phase.

	Qubits with similar phase cluster at similar angles around biome center.

	Physics: The coherence phase arg(ρ_01) encodes the quantum phase relationship.
	Qubits in similar superposition states cluster together.
	"""
	if biome_center == Vector2.ZERO:
		return Vector2.ZERO

	# Get target angle from hue (which encodes phase)
	var target_angle = node.color.h * TAU  # Hue → angle

	# Current angle relative to biome center
	var to_node = node.position - biome_center
	var current_radius = to_node.length()
	if current_radius < 10.0:
		return Vector2.ZERO  # Too close to center for angular force

	var current_angle = atan2(to_node.y, to_node.x)

	# Angular error (with wrapping)
	var angular_error = _wrap_angle(target_angle - current_angle)

	# Tangent direction (perpendicular to radius)
	var tangent = Vector2(-to_node.y, to_node.x).normalized()

	# Get coherence magnitude (stronger coherence = stronger angular force)
	var coherence_magnitude = node.coherence if node else 0.0

	return tangent * angular_error * PHASE_ANGULAR_SPRING * coherence_magnitude


func _calculate_correlation_forces(node, active_nodes: Array, biomes: Dictionary) -> Vector2:
	"""Calculate forces based on mutual information with other nodes.

	High mutual information (entangled) → attractive force
	Low mutual information (independent) → no force

	Physics: Mutual information I(A:B) = S(A) + S(B) - S(AB) quantifies
	total correlations. Entangled states have I(A:B) up to 2 bits.
	"""
	var total_force = Vector2.ZERO

	for other_node in active_nodes:
		if other_node == node:
			continue

		# Get mutual information between these nodes
		var mi = _get_mutual_information(node, other_node, biomes)
		if mi < 0.01:
			continue  # Uncorrelated - no attraction

		# Target distance decreases with mutual information
		# MI = 0 → BASE_DISTANCE, MI = 2 → BASE_DISTANCE / (1 + 2*SCALING)
		var target_distance = BASE_DISTANCE / (1.0 + CORRELATION_SCALING * mi)

		# Current distance
		var delta_pos = other_node.position - node.position
		var current_distance = delta_pos.length()
		if current_distance < 1.0:
			continue

		var direction = delta_pos.normalized()
		var displacement = current_distance - target_distance

		# Spring force: positive displacement = push apart, negative = pull together
		total_force += direction * displacement * CORRELATION_SPRING * mi

	return total_force


func _calculate_repulsion_forces(node, active_nodes: Array) -> Vector2:
	"""Calculate repulsion forces to prevent bubble overlap.

	Standard inverse-square repulsion for visual clarity.
	"""
	var repulsion = Vector2.ZERO

	for other_node in active_nodes:
		if other_node == node:
			continue

		var delta_pos = node.position - other_node.position
		var distance = delta_pos.length()

		if distance < MIN_DISTANCE:
			distance = MIN_DISTANCE

		var force_magnitude = REPULSION_STRENGTH / (distance * distance)
		repulsion += delta_pos.normalized() * force_magnitude

	return repulsion


func _update_positions(delta: float, nodes: Array) -> void:
	"""Update node positions from velocities."""
	for node in nodes:
		var quantum_behavior = _get_quantum_behavior(node)
		if quantum_behavior == 1 or quantum_behavior == 2:
			continue  # HOVERING and FIXED don't move

		node.update_position(delta)


func _update_mutual_information_cache(nodes: Array, biomes: Dictionary) -> void:
	"""Update mutual information cache from native C++ computation.

	MI is now computed in C++ during evolution (evolve_with_mi) at physics rate.
	This function just reads the cached values - no expensive GDScript calculations.
	"""
	_mi_cache.clear()

	# Group nodes by biome (MI is only defined within same quantum computer)
	var nodes_by_biome: Dictionary = {}
	for node in nodes:
		if not _is_active_node(node):
			continue
		var biome_name = node.biome_name if node else ""
		if biome_name.is_empty():
			continue
		if not nodes_by_biome.has(biome_name):
			nodes_by_biome[biome_name] = []
		nodes_by_biome[biome_name].append(node)

	# Read cached MI for all pairs within each biome (computed in C++ during evolution)
	for biome_name in nodes_by_biome:
		var biome = biomes.get(biome_name)
		if not biome or not biome.quantum_computer:
			continue

		var biome_nodes = nodes_by_biome[biome_name]
		var qc = biome.quantum_computer

		for i in range(biome_nodes.size()):
			for j in range(i + 1, biome_nodes.size()):
				var node_a = biome_nodes[i]
				var node_b = biome_nodes[j]

				# Get qubit indices
				var qubit_a = _get_qubit_index(node_a, qc)
				var qubit_b = _get_qubit_index(node_b, qc)

				if qubit_a < 0 or qubit_b < 0:
					continue

				# Use CACHED MI from native C++ (computed during evolution)
				# Falls back to GDScript if cache is empty
				var mi = 0.0
				if qc.has_method("get_cached_mutual_information"):
					mi = qc.get_cached_mutual_information(qubit_a, qubit_b)
				elif qc.has_method("get_mutual_information"):
					mi = qc.get_mutual_information(qubit_a, qubit_b)

				# Cache bidirectionally
				var key_ab = "%s_%s" % [node_a.get_instance_id(), node_b.get_instance_id()]
				var key_ba = "%s_%s" % [node_b.get_instance_id(), node_a.get_instance_id()]
				_mi_cache[key_ab] = mi
				_mi_cache[key_ba] = mi


func _get_mutual_information(node_a, node_b, biomes: Dictionary) -> float:
	"""Get cached mutual information between two nodes."""
	var key = "%s_%s" % [node_a.get_instance_id(), node_b.get_instance_id()]
	return _mi_cache.get(key, 0.0)


func _get_qubit_index(node, qc) -> int:
	"""Get qubit index for a node in the quantum computer."""
	if not node or not qc:
		return -1

	# Try to get from plot's register
	if node.plot and "register_id" in node.plot:
		return node.plot.register_id

	# Try from emoji
	if node.emoji_north and qc.register_map and qc.register_map.has(node.emoji_north):
		return qc.register_map.qubit(node.emoji_north)

	return -1


func _get_biome_center(node, layout_calculator) -> Vector2:
	"""Get biome center for a node's biome."""
	if not node or not layout_calculator:
		return Vector2.ZERO

	var biome_name = node.biome_name if node else ""
	if biome_name.is_empty():
		return Vector2.ZERO

	var oval = layout_calculator.get_biome_oval(biome_name)
	return oval.get("center", Vector2.ZERO)


func _get_quantum_behavior(node) -> int:
	"""Get quantum behavior flag.

	Priority:
	1. Node's direct quantum_behavior property (if set)
	2. Plot's quantum_behavior (legacy compatibility)
	3. Default: FLOATING (0) - forces active

	Values:
	- 0 = FLOATING: Forces active, normal physics
	- 1 = HOVERING: Fixed to anchor (biome measurement plots)
	- 2 = FIXED: Completely static (celestial bodies)
	"""
	if not node:
		return 0

	# Check node's direct property first (first-class quantum viz)
	if "quantum_behavior" in node:
		return node.quantum_behavior

	# Fallback to plot property (legacy)
	if node.plot and "quantum_behavior" in node.plot:
		return node.plot.quantum_behavior

	# Default: FLOATING (forces active)
	return 0


func _is_active_node(node) -> bool:
	"""Check if node is active (should receive forces).

	Active means the node has quantum data to visualize.
	Priority (first match wins):
	1. Direct quantum register (biome_name set) - PREFERRED
	2. Terminal bubble (has terminal binding)
	3. Plot bubble (has planted plot)
	"""
	if not node:
		return false

	# First-class quantum visualization: has biome_name and emojis
	if node.biome_name != "" and not node.emoji_north.is_empty():
		return true

	# v2 terminal bubbles
	if node.has_farm_tether and not node.emoji_north.is_empty():
		return true

	# v1 plot bubbles
	if node.plot and node.plot.is_planted:
		return true

	return false


func _is_node_measured(node, plot_pool) -> bool:
	"""Check if node has been measured."""
	if not node:
		return false

	# v1: plot-based
	if node.plot and node.plot.has_been_measured:
		return true

	# v2: terminal-based
	if plot_pool and node.grid_position != Vector2i(-1, -1):
		var terminal = plot_pool.get_terminal_at_grid_pos(node.grid_position) if plot_pool.has_method("get_terminal_at_grid_pos") else null
		if terminal and terminal.is_measured:
			return true

	return false


func _wrap_angle(angle: float) -> float:
	"""Wrap angle to [-PI, PI]."""
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle


# ============================================================================
# LEGACY COMPATIBILITY
# ============================================================================
# These methods maintain API compatibility with the old force system

func get_quantum_coupling_strength(node_a, node_b) -> float:
	"""Legacy compatibility: Get coupling from mutual information."""
	return _mi_cache.get("%s_%s" % [node_a.get_instance_id(), node_b.get_instance_id()], 0.0)
