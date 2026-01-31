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
##
## NATIVE ACCELERATION: If ForceGraphEngine is available, use C++ path (3-5× faster)

# === NATIVE ENGINE ===
var _native_engine = null
var _native_enabled: bool = false

func _init():
	# Try to use native force graph engine
	if ClassDB.class_exists("ForceGraphEngine"):
		_native_engine = ClassDB.instantiate("ForceGraphEngine")
		if _native_engine:
			# Configure with same constants as GDScript
			_native_engine.set_repulsion_strength(REPULSION)
			_native_engine.set_damping(DRAG)
			_native_engine.set_base_distance(BASE_SEPARATION)
			_native_engine.set_min_distance(MIN_DISTANCE)
			_native_enabled = true
			print("QuantumForceSystem: Native C++ engine ENABLED (3-5x faster)")
		else:
			print("QuantumForceSystem: Native engine instantiation failed - using GDScript")
	else:
		print("QuantumForceSystem: ForceGraphEngine not available - using GDScript fallback")


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

# Debug output (set to true to see diagnostics every 2 seconds)
var _debug_enabled: bool = true
var _debug_timer: float = 0.0
const DEBUG_INTERVAL = 2.0


func update(delta: float, nodes: Array, ctx: Dictionary) -> void:
	"""Update forces and positions for all quantum nodes."""
	var biomes = ctx.get("biomes", {})
	var layout_calculator = ctx.get("layout_calculator")

	# Refresh caches periodically
	_cache_timer += delta
	if _cache_timer >= CACHE_INTERVAL:
		_cache_timer = 0.0
		_refresh_caches(nodes, biomes)

	# Debug output
	if _debug_enabled:
		_debug_timer += delta
		if _debug_timer >= DEBUG_INTERVAL:
			_debug_timer = 0.0
			_print_debug_info(nodes, biomes)

	# Build active node list
	var active_nodes: Array = []
	for node in nodes:
		if _is_active(node):
			active_nodes.append(node)

	# DUAL-PATH: Native C++ (fast) vs GDScript (fallback)
	if _native_enabled and _native_engine:
		_update_native(delta, active_nodes, biomes, layout_calculator)
	else:
		_update_gdscript(delta, active_nodes, biomes)


func _update_native(delta: float, nodes: Array, biomes: Dictionary, layout_calculator) -> void:
	"""Fast path: Use native C++ ForceGraphEngine."""
	if nodes.is_empty():
		return

	# Pack positions and velocities
	var positions = PackedVector2Array()
	var velocities = PackedVector2Array()
	var frozen_mask = PackedByteArray()

	for node in nodes:
		positions.append(node.position)
		velocities.append(node.velocity)
		frozen_mask.append(1 if (node.is_lifeless or _is_measured(node)) else 0)

	# Get quantum data from first node's biome
	var bloch_packet = PackedFloat64Array()
	var mi_values = PackedFloat64Array()
	var biome_center = Vector2.ZERO

	# Group nodes by biome and process each biome
	var biome_nodes: Dictionary = {}
	for node in nodes:
		if not biome_nodes.has(node.biome_name):
			biome_nodes[node.biome_name] = []
		biome_nodes[node.biome_name].append(node)

	# For now, use simple approach: process all nodes together with combined data
	# Get biome center from layout calculator if available
	if layout_calculator and biome_nodes.size() > 0:
		var first_biome = biome_nodes.keys()[0]
		if layout_calculator.has_method("get_biome_oval"):
			var oval = layout_calculator.get_biome_oval(first_biome)
			biome_center = oval.get("center", Vector2(960, 540))

	# Get MI values from first active biome's viz_cache
	for biome_name in biome_nodes:
		if biomes.has(biome_name):
			var biome = biomes[biome_name]
			if biome and biome.viz_cache:
				mi_values = biome.viz_cache._mi_values
				# Get bloch data
				var num_qubits = biome.viz_cache.get_num_qubits()
				for q in range(num_qubits):
					var bloch = biome.viz_cache.get_bloch(q)
					if not bloch.is_empty():
						bloch_packet.append(bloch.get("p0", 0.5))
						bloch_packet.append(bloch.get("p1", 0.5))
						bloch_packet.append(bloch.get("x", 0.0))
						bloch_packet.append(bloch.get("y", 0.0))
						bloch_packet.append(bloch.get("z", 0.0))
						bloch_packet.append(bloch.get("r", 0.0))
						bloch_packet.append(bloch.get("theta", 0.0))
						bloch_packet.append(bloch.get("phi", 0.0))
				break  # Use first biome's data for now

	# Call native engine
	var result = _native_engine.update_positions(
		positions,
		velocities,
		bloch_packet,
		mi_values,
		biome_center,
		delta,
		frozen_mask
	)

	# Unpack results back to nodes
	var new_positions = result.get("positions", PackedVector2Array())
	var new_velocities = result.get("velocities", PackedVector2Array())

	for i in range(nodes.size()):
		if i < new_positions.size():
			nodes[i].position = new_positions[i]
		if i < new_velocities.size():
			nodes[i].velocity = new_velocities[i]


func _update_gdscript(delta: float, active_nodes: Array, biomes: Dictionary) -> void:
	"""Fallback path: GDScript force calculations."""
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

	if _debug_enabled and biomes.size() > 0:
		_test_log("[ForceSystem._refresh_caches] Starting cache refresh for %d biomes" % biomes.size())

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

			if _debug_enabled and i == 0:
				_test_log("  [DEBUG] emoji_a='%s' h_couplings type=%s, size=%d" % [emoji_a, typeof(h_couplings), h_couplings.size() if h_couplings is Dictionary else 0])

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


func _print_debug_info(nodes: Array, biomes: Dictionary) -> void:
	"""Print diagnostic info about force graph state."""

	_test_log("\n=== QUANTUM FORCE SYSTEM DEBUG ===")

	# Count node states
	var active_count = 0
	var frozen_count = 0
	var lifeless_count = 0
	var max_vel = 0.0
	var total_vel = Vector2.ZERO
	var max_pop_change = 0.0

	for node in nodes:
		if node.is_lifeless:
			lifeless_count += 1
			continue

		if _is_measured(node):
			frozen_count += 1
			continue

		if not _is_active(node):
			continue

		active_count += 1
		max_vel = max(max_vel, node.velocity.length())
		total_vel += node.velocity

		# Check population change
		var node_id = node.get_instance_id()
		var current_pop = node.emoji_north_opacity
		var prev_pop = _prev_population.get(node_id, current_pop)
		var dP = abs(current_pop - prev_pop)
		max_pop_change = max(max_pop_change, dP)

	_test_log("Nodes: %d total (%d active, %d frozen, %d lifeless)" % [
		nodes.size(), active_count, frozen_count, lifeless_count
	])

	_test_log("Velocities: max=%.2f px/s, avg=%.2f px/s" % [
		max_vel,
		total_vel.length() / max(active_count, 1)
	])

	_test_log("Population change: max dP=%.6f" % max_pop_change)

	# Sample actual populations from a few nodes
	if nodes.size() > 0:
		var sample_pops = []
		var sample_radii = []
		var sample_hues = []
		var sample_phi = []
		var sample_r_xy = []
		for i in range(min(3, nodes.size())):
			if i < nodes.size() and _is_active(nodes[i]):
				var n = nodes[i]
				sample_pops.append("%.2f" % n.emoji_north_opacity)
				sample_radii.append("%.1f" % n.radius)
				sample_hues.append("%.2f" % n.color.h)
				# Also get raw phi and r_xy from viz_cache
				var biome = biomes.get(n.biome_name)
				if biome and biome.viz_cache:
					var qubit_idx = biome.viz_cache.get_qubit(n.emoji_north)
					var snap = biome.viz_cache.get_snapshot(qubit_idx)
					sample_phi.append("%.3f" % snap.get("phi", 0.0))
					sample_r_xy.append("%.3f" % snap.get("r_xy", 0.0))
				else:
					sample_phi.append("N/A")
					sample_r_xy.append("N/A")
		if sample_pops.size() > 0:
			_test_log("Sample pops: %s | radii: %s | hues: %s | phi: %s | r_xy: %s" % [
				str(sample_pops), str(sample_radii), str(sample_hues), str(sample_phi), str(sample_r_xy)
			])

	_test_log("Caches: H-coupling=%d entries, MI=%d entries" % [
		_coupling_cache.size(),
		_mi_cache.size()
	])

	# Sample some couplings
	if _coupling_cache.size() > 0:
		var sample_h = []
		var sample_mi = []
		var count = 0
		for key in _coupling_cache:
			if count >= 3:
				break
			sample_h.append(_coupling_cache[key])
			sample_mi.append(_mi_cache.get(key, 0.0))
			count += 1

		_test_log("Sample H-couplings: %s" % str(sample_h))
		_test_log("Sample MI values: %s" % str(sample_mi))
	else:
		_test_log("⚠️ NO COUPLING DATA - biomes may not be evolving!")

	# Check biomes and quantum states
	_test_log("Biomes: %d" % biomes.size())
	for biome_name in biomes:
		var biome = biomes[biome_name]
		if biome and "quantum_computer" in biome:
			var qc = biome.quantum_computer
			if qc and qc.density_matrix:
				var pop_00 = qc.density_matrix.get_element(0, 0).re
				var pop_11 = 0.0
				if qc.density_matrix.n > 1:
					var last_idx = qc.density_matrix.n - 1
					pop_11 = qc.density_matrix.get_element(last_idx, last_idx).re

				# Check coherence (off-diagonal)
				var coherence = 0.0
				if qc.density_matrix.n > 1:
					var rho_01 = qc.density_matrix.get_element(0, 1)
					coherence = sqrt(rho_01.re * rho_01.re + rho_01.im * rho_01.im)

				_test_log("  %s: ρ₀₀=%.4f, ρ₁₁=%.4f, |ρ₀₁|=%.4f" % [
					biome_name, pop_00, pop_11, coherence
				])

	_test_log("=================================")


func _test_log(message: String) -> void:
	"""Log test/debug message with [TEST] prefix via VerboseConfig."""
	var tree = Engine.get_main_loop()
	if not tree:
		return
	var verbose = tree.root.get_node_or_null("/root/VerboseConfig")
	if verbose:
		verbose.trace("test", "📊", message)
