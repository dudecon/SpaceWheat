class_name QuantumEdgeRenderer
extends RefCounted

## Quantum Edge Renderer
##
## Draws relationships between quantum nodes:
##
## PHYSICS-GROUNDED EDGES:
## - Mutual Information Web (NEW): I(A:B) correlations between all pairs
## - Entanglement Lines: Explicit Bell pair connections
## - Coherence Web: Off-diagonal ρ[i,j] correlations
## - Hamiltonian Coupling Web: Unitary interactions
## - Lindblad Flow Arrows: Dissipative energy flow
## - Entanglement Clusters: Multi-body entangled groups
##
## REDESIGNED:
## - Food Web as Linked Orbits (was arrows, now knot topology)
##
## REMOVED (no physics meaning):
## - Tether Lines (replaced by MI-based position forces)


func draw(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw all quantum edge visualizations.

	Args:
	    graph: The QuantumForceGraph node
	    ctx: Context dictionary
	"""
	# Order matters: back to front

	# 1. Mutual information web (faint background correlation structure)
	_draw_mutual_information_web(graph, ctx)

	# 2. Coherence web (quantum correlations)
	_draw_coherence_web(graph, ctx)

	# 3. Hamiltonian coupling web (unitary interactions)
	_draw_hamiltonian_coupling_web(graph, ctx)

	# 4. Lindblad flow arrows (dissipative flow)
	_draw_lindblad_flow_arrows(graph, ctx)

	# 5. Explicit entanglement lines (Bell pairs)
	_draw_entanglement_lines(graph, ctx)

	# 6. Food web as linked orbits
	_draw_food_web_as_knot(graph, ctx)

	# 7. Entanglement clusters (multi-body groups)
	_draw_entanglement_clusters(graph, ctx)


# ============================================================================
# NEW: MUTUAL INFORMATION WEB
# ============================================================================

func _draw_mutual_information_web(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw lines between ALL bubble pairs showing mutual information.

	This is the key physics-grounded correlation visualization:
	- Opacity/color scales with I(A:B) mutual information
	- Shows full correlation structure at a glance
	- Entangled pairs appear connected, independent pairs fade

	Physics: I(A:B) = S(A) + S(B) - S(AB) quantifies total correlations.
	"""
	var quantum_nodes = ctx.get("quantum_nodes", [])
	var biomes = ctx.get("biomes", {})
	var force_system = ctx.get("force_system")
	var active_biome = ctx.get("active_biome", "")

	# Get visible nodes
	var visible_nodes: Array = []
	for node in quantum_nodes:
		if node.visible and _is_active_node(node):
			visible_nodes.append(node)

	if visible_nodes.size() < 2:
		return

	# Group by biome (MI only defined within same quantum computer)
	var nodes_by_biome: Dictionary = {}
	for node in visible_nodes:
		var biome_name = node.biome_name if node else ""
		if biome_name.is_empty():
			continue
		if active_biome != "" and biome_name != active_biome:
			continue
		if not nodes_by_biome.has(biome_name):
			nodes_by_biome[biome_name] = []
		nodes_by_biome[biome_name].append(node)

	# Draw MI lines within each biome
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

				# Get mutual information
				var mi = 0.0
				if force_system:
					mi = force_system.get_quantum_coupling_strength(node_a, node_b)
				else:
					# Fallback: compute directly
					var qubit_a = _get_qubit_index(node_a, qc)
					var qubit_b = _get_qubit_index(node_b, qc)
					if qubit_a >= 0 and qubit_b >= 0 and qc.has_method("get_mutual_information"):
						mi = qc.get_mutual_information(qubit_a, qubit_b)

				if mi < 0.01:
					continue  # Skip uncorrelated pairs

				# Alpha scales with MI (max MI = 2 for single qubits)
				var alpha = clampf(mi / 2.0, 0.05, 0.6)

				# Color: orange-gold for correlations
				var color = Color(0.9, 0.6, 0.2, alpha)

				# Line width scales with MI
				var width = 1.0 + mi * 1.5

				graph.draw_line(node_a.position, node_b.position, color, width, true)


# ============================================================================
# EXPLICIT ENTANGLEMENT LINES
# ============================================================================

func _draw_entanglement_lines(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw entanglement connections between quantum nodes.

	WIDTH ENCODING: Edge width proportional to entanglement strength
	PULSING ANIMATION: Pulse rate proportional to interaction strength
	"""
	var quantum_nodes = ctx.get("quantum_nodes", [])
	var node_by_plot_id = ctx.get("node_by_plot_id", {})
	var time_accumulator = ctx.get("time_accumulator", 0.0)

	var drawn_pairs = {}

	for node in quantum_nodes:
		if not node.visible or not node.plot:
			continue

		for partner_id in node.plot.entangled_plots.keys():
			var partner_node = node_by_plot_id.get(partner_id)
			if not partner_node:
				continue

			# Avoid duplicates
			var ids = [node.plot_id, partner_id]
			ids.sort()
			var pair_key = "%s_%s" % [ids[0], ids[1]]
			if drawn_pairs.has(pair_key):
				continue
			drawn_pairs[pair_key] = true

			# Get entanglement strength
			var entanglement_strength = node.plot.entangled_plots.get(partner_id, 0.5)
			var base_line_width = 1.0 + entanglement_strength * 5.0

			# Pulsing animation
			var interaction_strength = _get_interaction_strength(node, partner_node)
			var phase = time_accumulator * 2.0 * (1.0 + interaction_strength)
			var pulse = (sin(phase) + 1.0) / 2.0
			var pulse_factor = 0.5 + pulse * 0.5

			var alpha = (0.5 + entanglement_strength * 0.5) * pulse_factor
			var pulsed_width = base_line_width * pulse_factor

			# Vibrant cyan
			var base_color = Color(0.2, 0.9, 1.0)

			# Outer glow
			var glow_outer = base_color
			glow_outer.a = alpha * 0.25
			graph.draw_line(node.position, partner_node.position, glow_outer, pulsed_width * 3.5, true)

			# Mid glow
			var glow_mid = base_color
			glow_mid.a = alpha * 0.5
			graph.draw_line(node.position, partner_node.position, glow_mid, pulsed_width * 2.0, true)

			# Core line
			var core_color = Color(0.6, 1.0, 1.0)
			core_color.a = alpha * 0.95
			graph.draw_line(node.position, partner_node.position, core_color, pulsed_width, true)

			# Midpoint indicator
			var mid_point = (node.position + partner_node.position) / 2
			var indicator_size = (8.0 + interaction_strength * 4.0) * pulse_factor

			var glow_color = base_color
			glow_color.a = alpha * 0.4
			graph.draw_circle(mid_point, indicator_size * 1.8, glow_color)

			var core_indicator = Color(0.8, 1.0, 1.0)
			core_indicator.a = alpha * 0.95
			graph.draw_circle(mid_point, indicator_size * 0.8, core_indicator)


# ============================================================================
# REDESIGNED: FOOD WEB AS LINKED ORBITS (Knot Topology)
# ============================================================================

func _draw_food_web_as_knot(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw predation/escape relationships as linked orbit topology.

	Knot theory: Linking number encodes relationship strength.
	Food relationships visualized as orbit curves that link/unlink.

	This replaces the simple arrow visualization with topologically meaningful curves.
	"""
	var quantum_nodes = ctx.get("quantum_nodes", [])
	var time_accumulator = ctx.get("time_accumulator", 0.0)

	# Find forest nodes
	var forest_nodes: Array = []
	for node in quantum_nodes:
		if node.biome_name == "FungalNetworks":
			forest_nodes.append(node)

	if forest_nodes.is_empty():
		return

	for predator_node in forest_nodes:
		if not predator_node.plot or not "quantum_state" in predator_node.plot or not predator_node.plot.quantum_state:
			continue

		var pred_qubit = predator_node.plot.quantum_state
		if not pred_qubit.has_method("get_graph_targets"):
			continue

		# Get predation targets
		var prey_targets = pred_qubit.get_graph_targets("🍴")

		for prey_node in forest_nodes:
			if prey_node == predator_node:
				continue
			if not prey_node.plot or not "quantum_state" in prey_node.plot or not prey_node.plot.quantum_state:
				continue

			var prey_emoji = prey_node.emoji_north

			if prey_emoji in prey_targets:
				_draw_linked_orbits(graph, predator_node, prey_node, 0.7, time_accumulator, Color(1.0, 0.4, 0.2, 0.5))

		# Get escape targets
		var escape_targets = pred_qubit.get_graph_targets("🏃")

		for threat_node in forest_nodes:
			if threat_node == predator_node:
				continue
			if not threat_node.plot or not threat_node.plot.quantum_state:
				continue

			var threat_emoji = threat_node.emoji_north

			if threat_emoji in escape_targets:
				_draw_linked_orbits(graph, predator_node, threat_node, 0.4, time_accumulator, Color(0.3, 0.7, 1.0, 0.4))


func _draw_linked_orbits(graph: Node2D, node_a, node_b, coupling: float, time: float, color: Color) -> void:
	"""Draw two linked orbit curves representing the relationship.

	The linking number (how many times curves wind around each other)
	encodes the relationship strength.
	"""
	var center = (node_a.position + node_b.position) / 2
	var distance = node_a.position.distance_to(node_b.position)
	var direction = (node_b.position - node_a.position).normalized()
	var perp = Vector2(-direction.y, direction.x)

	if distance < 40.0:
		return

	# Orbit parameters
	var orbit_radius = distance * 0.25
	var num_segments = 24
	var link_count = int(coupling * 3) + 1  # 1-4 links based on coupling

	# Draw intertwined orbits
	for orbit in range(2):
		var orbit_center = center + direction * (orbit * 2 - 1) * orbit_radius * 0.3
		var phase_offset = orbit * PI + time * 0.5

		var prev_point = Vector2.ZERO
		for i in range(num_segments + 1):
			var t = float(i) / float(num_segments) * TAU * link_count
			var x = cos(t + phase_offset) * orbit_radius
			var y = sin(t + phase_offset) * orbit_radius * 0.5
			var point = orbit_center + direction * x + perp * y

			if i > 0:
				var segment_color = color
				segment_color.a = color.a * (0.5 + 0.5 * sin(t * 2 + time * 3))
				graph.draw_line(prev_point, point, segment_color, 1.5, true)

			prev_point = point


# ============================================================================
# COHERENCE WEB
# ============================================================================

func _draw_coherence_web(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw thin lines showing all quantum correlations (off-diagonal ρ[i,j])."""
	var quantum_nodes = ctx.get("quantum_nodes", [])
	var biomes = ctx.get("biomes", {})
	var active_biome = ctx.get("active_biome", "")

	for biome_name in biomes:
		if active_biome != "" and biome_name != active_biome:
			continue
		var biome = biomes[biome_name]
		if not biome or not biome.quantum_computer:
			continue

		var qc = biome.quantum_computer
		if not qc.density_matrix or not qc.register_map:
			continue

		# Get emoji positions
		var emoji_positions: Dictionary = {}
		for node in quantum_nodes:
			if node.biome_name == biome_name and node.emoji_north != "":
				emoji_positions[node.emoji_north] = node.position

		var emojis = qc.register_map.coordinates.keys()

		for i in range(emojis.size()):
			for j in range(i + 1, emojis.size()):
				var emoji_a = emojis[i]
				var emoji_b = emojis[j]

				var pos_a = emoji_positions.get(emoji_a, Vector2.ZERO)
				var pos_b = emoji_positions.get(emoji_b, Vector2.ZERO)

				if pos_a == Vector2.ZERO or pos_b == Vector2.ZERO:
					continue

				var coherence = biome.get_emoji_coherence(emoji_a, emoji_b)
				if not coherence:
					continue

				var coherence_mag = coherence.abs()
				if coherence_mag < 0.01:
					continue

				var alpha = clampf(coherence_mag * 2.0, 0.05, 0.8)
				var color = Color(0.8, 0.8, 1.0, alpha)
				graph.draw_line(pos_a, pos_b, color, 1.0, true)


# ============================================================================
# HAMILTONIAN COUPLING WEB
# ============================================================================

func _draw_hamiltonian_coupling_web(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw green dashed lines showing Hamiltonian (unitary) couplings."""
	var quantum_nodes = ctx.get("quantum_nodes", [])
	var biomes = ctx.get("biomes", {})
	var active_biome = ctx.get("active_biome", "")

	var icon_registry = graph.get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		return

	var drawn_pairs: Dictionary = {}

	for biome_name in biomes:
		if active_biome != "" and biome_name != active_biome:
			continue
		var biome = biomes[biome_name]
		if not biome or not biome.quantum_computer:
			continue

		var emoji_positions: Dictionary = {}
		for node in quantum_nodes:
			if node.biome_name == biome_name and node.emoji_north != "":
				emoji_positions[node.emoji_north] = node.position

		var qc = biome.quantum_computer
		if not qc.register_map:
			continue

		for emoji in qc.register_map.coordinates.keys():
			var icon = icon_registry.get_icon(emoji)
			if not icon:
				continue

			var source_pos = emoji_positions.get(emoji, Vector2.ZERO)
			if source_pos == Vector2.ZERO:
				continue

			for target_emoji in icon.hamiltonian_couplings:
				var strength = icon.hamiltonian_couplings[target_emoji]
				if abs(strength) < 0.001:
					continue

				var target_pos = emoji_positions.get(target_emoji, Vector2.ZERO)
				if target_pos == Vector2.ZERO:
					continue

				var pair_key = [emoji, target_emoji]
				pair_key.sort()
				var key_str = "%s_%s" % [pair_key[0], pair_key[1]]
				if drawn_pairs.has(key_str):
					continue
				drawn_pairs[key_str] = true

				var color = Color(0.3, 0.9, 0.4, 0.4)
				var line_width = clampf(abs(strength) * 2.0 + 1.0, 1.0, 3.0)

				_draw_dashed_line(graph, source_pos, target_pos, color, line_width, 10.0, 6.0)


# ============================================================================
# LINDBLAD FLOW ARROWS
# ============================================================================

func _draw_lindblad_flow_arrows(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw curved arrows showing Lindblad energy transfer network."""
	var quantum_nodes = ctx.get("quantum_nodes", [])
	var biomes = ctx.get("biomes", {})
	var active_biome = ctx.get("active_biome", "")
	var time_accumulator = ctx.get("time_accumulator", 0.0)
	var layout_calculator = ctx.get("layout_calculator")

	var icon_registry = graph.get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		return

	for biome_name in biomes:
		if active_biome != "" and biome_name != active_biome:
			continue
		var biome = biomes[biome_name]
		if not biome or not biome.quantum_computer:
			continue

		var oval = layout_calculator.get_biome_oval(biome_name) if layout_calculator else {}
		if oval.is_empty():
			continue

		var biome_center = oval.get("center", Vector2.ZERO)

		var emoji_positions: Dictionary = {}
		for node in quantum_nodes:
			if node.biome_name == biome_name and node.emoji_north != "":
				emoji_positions[node.emoji_north] = node.position

		var qc = biome.quantum_computer
		if not qc.register_map:
			continue

		for emoji in qc.register_map.coordinates.keys():
			var icon = icon_registry.get_icon(emoji)
			if not icon:
				continue

			var source_pos = emoji_positions.get(emoji, biome_center)

			for target_emoji in icon.lindblad_outgoing:
				var rate = icon.lindblad_outgoing[target_emoji]
				if rate < 0.001:
					continue

				var target_pos = emoji_positions.get(target_emoji, Vector2.ZERO)
				if target_pos == Vector2.ZERO:
					continue

				_draw_flow_arrow(graph, source_pos, target_pos, rate, Color(1.0, 0.5, 0.2, 0.5), time_accumulator)


func _draw_flow_arrow(graph: Node2D, from_pos: Vector2, to_pos: Vector2, rate: float, color: Color, time: float) -> void:
	"""Draw a curved flow arrow."""
	var direction = (to_pos - from_pos).normalized()
	var distance = from_pos.distance_to(to_pos)

	if distance < 30.0:
		return

	var perp = direction.rotated(PI / 2.0)
	var curve_offset = perp * distance * 0.2
	var control = from_pos.lerp(to_pos, 0.5) + curve_offset

	var arrow_width = clampf(rate * 3.0 + 1.0, 1.0, 4.0)
	var flow_phase = fmod(time * 2.0, 1.0)

	var segments = 12
	var prev_point = from_pos
	for i in range(1, segments + 1):
		var t = float(i) / float(segments)
		var p = (1 - t) * (1 - t) * from_pos + 2 * (1 - t) * t * control + t * t * to_pos

		var segment_alpha = color.a
		var flow_t = fmod(flow_phase + float(i) / float(segments), 1.0)
		if flow_t > 0.7:
			segment_alpha *= 1.5

		var seg_color = color
		seg_color.a = segment_alpha
		graph.draw_line(prev_point, p, seg_color, arrow_width, true)
		prev_point = p

	# Arrowhead
	var arrow_size = 8.0
	var arrow_tip = to_pos - direction * 15.0
	var arrow_left = arrow_tip - direction * arrow_size + perp * arrow_size * 0.5
	var arrow_right = arrow_tip - direction * arrow_size - perp * arrow_size * 0.5

	var arrow_color = color
	arrow_color.a = color.a * 1.2
	graph.draw_colored_polygon([arrow_tip, arrow_left, arrow_right], arrow_color)


# ============================================================================
# ENTANGLEMENT CLUSTERS
# ============================================================================

func _draw_entanglement_clusters(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw convex hull glow around multi-body entangled groups."""
	var quantum_nodes = ctx.get("quantum_nodes", [])
	var node_by_plot_id = ctx.get("node_by_plot_id", {})

	if quantum_nodes.is_empty():
		return

	# Build adjacency map
	var adjacency: Dictionary = {}
	for node in quantum_nodes:
		if not node.plot:
			continue
		adjacency[node.plot_id] = node.plot.entangled_plots.keys()

	# Find connected components
	var visited: Dictionary = {}
	var clusters: Array = []

	for node in quantum_nodes:
		if not node.plot or visited.has(node.plot_id):
			continue

		var cluster: Array = []
		var queue: Array = [node.plot_id]

		while not queue.is_empty():
			var current = queue.pop_front()
			if visited.has(current):
				continue
			visited[current] = true
			cluster.append(current)

			for neighbor in adjacency.get(current, []):
				if not visited.has(neighbor):
					queue.append(neighbor)

		if cluster.size() > 1:
			clusters.append(cluster)

	# Draw each cluster
	for cluster in clusters:
		if cluster.size() < 2:
			continue

		var positions: Array[Vector2] = []
		for plot_id in cluster:
			var node = node_by_plot_id.get(plot_id)
			if node:
				positions.append(node.position)

		if positions.size() < 2:
			continue

		var centroid = Vector2.ZERO
		for pos in positions:
			centroid += pos
		centroid /= positions.size()

		var max_dist = 0.0
		for pos in positions:
			max_dist = max(max_dist, centroid.distance_to(pos))

		var cluster_color = Color(0.2, 0.9, 1.0, 0.1)

		for ring in range(3):
			var ring_radius = max_dist * (0.8 + float(ring) * 0.3)
			var ring_color = cluster_color
			ring_color.a = cluster_color.a * (1.0 - float(ring) * 0.3)
			graph.draw_arc(centroid, ring_radius, 0, TAU, 32, ring_color, 2.0, true)


# ============================================================================
# HELPERS
# ============================================================================

func _draw_dashed_line(graph: Node2D, from: Vector2, to: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	"""Draw a dashed line."""
	var direction = (to - from).normalized()
	var distance = from.distance_to(to)
	var current = 0.0

	while current < distance:
		var dash_start = from + direction * current
		var dash_end = from + direction * min(current + dash, distance)
		graph.draw_line(dash_start, dash_end, color, width, true)
		current += dash + gap


func _get_interaction_strength(node_a, node_b) -> float:
	"""Get interaction strength from node purity values.

	Model C: Uses node.energy which already contains purity Tr(ρ²).
	"""
	# Model C: node.energy is already set to purity by QuantumNodeManager
	var purity_a = node_a.energy if node_a and node_a.energy > 0 else 0.5
	var purity_b = node_b.energy if node_b and node_b.energy > 0 else 0.5
	return sqrt(purity_a * purity_b)


func _is_active_node(node) -> bool:
	"""Check if node should be included in edge calculations."""
	if not node:
		return false
	if node.has_farm_tether and not node.emoji_north.is_empty():
		return true
	if node.plot and node.plot.is_planted:
		return true
	return false


func _get_qubit_index(node, qc) -> int:
	"""Get qubit index for a node."""
	if not node or not qc:
		return -1

	if node.plot and "register_id" in node.plot:
		return node.plot.register_id

	if node.emoji_north and qc.register_map and qc.register_map.has(node.emoji_north):
		return qc.register_map.qubit(node.emoji_north)

	return -1
