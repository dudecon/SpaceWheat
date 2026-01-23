class_name QuantumInfraRenderer
extends RefCounted

## Quantum Infrastructure Renderer
##
## Draws persistent gate infrastructure at PLOT positions:
## - Bell gates: Gold/amber two-node connection
## - Cluster gates: Multi-node web with central hub
## - Bell gate ghosts: Historical entanglement traces


func draw(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw gate infrastructure.

	Args:
	    graph: The QuantumForceGraph node
	    ctx: Context dictionary
	"""
	_draw_persistent_gate_infrastructure(graph, ctx)
	_draw_bell_gate_ghosts(graph, ctx)


func _draw_persistent_gate_infrastructure(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw persistent gate infrastructure at PLOT positions."""
	var farm_grid = ctx.get("farm_grid")
	var all_plot_positions = ctx.get("all_plot_positions", {})
	var quantum_nodes_by_grid_pos = ctx.get("quantum_nodes_by_grid_pos", {})
	var graph_radius = ctx.get("graph_radius", 300.0)
	var time_accumulator = ctx.get("time_accumulator", 0.0)

	if not farm_grid:
		return

	var drawn_gates = {}

	# Parametric sizing
	var base_width = graph_radius * 0.008
	var max_width = graph_radius * 0.02
	var corner_radius = graph_radius * 0.025

	for grid_pos in farm_grid.plots:
		var plot = farm_grid.plots[grid_pos]
		if not plot:
			continue

		var active_gates = plot.get_active_gates() if plot.has_method("get_active_gates") else []

		for gate in active_gates:
			var gate_type = gate.get("type", "")
			var linked_plots: Array = gate.get("linked_plots", [])

			if linked_plots.is_empty():
				continue

			var sorted_positions = linked_plots.duplicate()
			sorted_positions.sort()
			var gate_key = "%s_%s" % [gate_type, str(sorted_positions)]

			if drawn_gates.has(gate_key):
				continue
			drawn_gates[gate_key] = true

			var plot_positions: Array[Vector2] = []
			for pos in linked_plots:
				if all_plot_positions.has(pos):
					plot_positions.append(all_plot_positions[pos])
				elif quantum_nodes_by_grid_pos.has(pos):
					plot_positions.append(quantum_nodes_by_grid_pos[pos].classical_anchor)

			if plot_positions.size() < 2:
				continue

			match gate_type:
				"bell":
					_draw_bell_gate_infrastructure(graph, plot_positions, base_width, max_width, corner_radius, time_accumulator)
				"cluster":
					_draw_cluster_gate_infrastructure(graph, plot_positions, base_width, max_width, corner_radius, time_accumulator)
				_:
					_draw_bell_gate_infrastructure(graph, plot_positions, base_width, max_width, corner_radius, time_accumulator)


func _draw_bell_gate_infrastructure(graph: Node2D, positions: Array[Vector2], base_width: float, max_width: float, corner_radius: float, time: float) -> void:
	"""Draw Bell gate infrastructure (2-node connection)."""
	if positions.size() < 2:
		return

	var p1 = positions[0]
	var p2 = positions[1]

	var pulse = (sin(time * 0.8) + 1.0) / 2.0
	var pulse_factor = 0.7 + pulse * 0.3

	var infra_color = Color(1.0, 0.75, 0.2)
	var infra_glow = Color(1.0, 0.85, 0.4)

	var line_width = base_width + max_width * 0.5
	var pulsed_width = line_width * pulse_factor

	# Glow layer
	var glow_color = infra_glow
	glow_color.a = 0.3 * pulse_factor
	graph.draw_line(p1, p2, glow_color, pulsed_width * 2.5, true)

	# Core line
	var core_color = infra_color
	core_color.a = 0.85 * pulse_factor
	graph.draw_line(p1, p2, core_color, pulsed_width, true)

	# Corner connectors
	_draw_gate_corner_connector(graph, p1, corner_radius, infra_color, pulse_factor)
	_draw_gate_corner_connector(graph, p2, corner_radius, infra_color, pulse_factor)


func _draw_cluster_gate_infrastructure(graph: Node2D, positions: Array[Vector2], base_width: float, max_width: float, corner_radius: float, time: float) -> void:
	"""Draw Cluster gate infrastructure (N-node web)."""
	if positions.size() < 2:
		return

	# Calculate center hub
	var hub = Vector2.ZERO
	for pos in positions:
		hub += pos
	hub /= positions.size()

	var pulse = (sin(time * 0.8) + 1.0) / 2.0
	var pulse_factor = 0.7 + pulse * 0.3

	var cluster_color = Color(0.7, 0.4, 1.0)
	var cluster_glow = Color(0.85, 0.6, 1.0)

	var line_width = base_width + max_width * 0.3
	var pulsed_width = line_width * pulse_factor

	# Draw spokes
	for pos in positions:
		var glow_color = cluster_glow
		glow_color.a = 0.25 * pulse_factor
		graph.draw_line(hub, pos, glow_color, pulsed_width * 2.0, true)

		var core_color = cluster_color
		core_color.a = 0.8 * pulse_factor
		graph.draw_line(hub, pos, core_color, pulsed_width, true)

		_draw_gate_corner_connector(graph, pos, corner_radius, cluster_color, pulse_factor)

	# Central hub
	var hub_size = corner_radius * 1.5 * pulse_factor
	var hub_glow = cluster_glow
	hub_glow.a = 0.4 * pulse_factor
	graph.draw_circle(hub, hub_size * 1.5, hub_glow)

	var hub_core = cluster_color
	hub_core.a = 0.9 * pulse_factor
	graph.draw_circle(hub, hub_size, hub_core)

	var bright = Color.WHITE
	bright.a = 0.6 * pulse_factor
	graph.draw_circle(hub, hub_size * 0.4, bright)


func _draw_gate_corner_connector(graph: Node2D, pos: Vector2, radius: float, color: Color, pulse_factor: float) -> void:
	"""Draw corner connector at a plot position."""
	var size = radius * pulse_factor

	var glow = color
	glow.a = 0.3 * pulse_factor
	graph.draw_circle(pos, size * 1.8, glow)

	var core = color
	core.a = 0.9 * pulse_factor
	graph.draw_circle(pos, size, core)

	var highlight = Color.WHITE
	highlight.a = 0.5 * pulse_factor
	graph.draw_circle(pos, size * 0.5, highlight)


func _draw_bell_gate_ghosts(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw fading ghost lines for historical Bell gate entanglements."""
	var biomes = ctx.get("biomes", {})
	var active_biome = ctx.get("active_biome", "")
	var all_plot_positions = ctx.get("all_plot_positions", {})
	var quantum_nodes_by_grid_pos = ctx.get("quantum_nodes_by_grid_pos", {})

	for biome_name in biomes:
		if active_biome != "" and biome_name != active_biome:
			continue

		var biome = biomes[biome_name]
		if not biome or not "bell_gates" in biome:
			continue

		var bell_gates = biome.bell_gates if "bell_gates" in biome else []
		if bell_gates.is_empty():
			continue

		var ghost_color = Color(1.0, 0.8, 0.3, 0.15)

		for gate in bell_gates:
			if gate.size() < 2:
				continue

			var positions: Array[Vector2] = []
			for pos in gate:
				if all_plot_positions.has(pos):
					positions.append(all_plot_positions[pos])
				elif quantum_nodes_by_grid_pos.has(pos):
					positions.append(quantum_nodes_by_grid_pos[pos].position)

			if positions.size() < 2:
				continue

			# Draw ghost line (dashed)
			var start = positions[0]
			var end = positions[1]
			var direction = (end - start).normalized()
			var distance = start.distance_to(end)

			var dash_length = 12.0
			var gap_length = 8.0
			var current = 0.0

			while current < distance:
				var dash_start = start + direction * current
				var dash_end = start + direction * min(current + dash_length, distance)
				graph.draw_line(dash_start, dash_end, ghost_color, 1.5, true)
				current += dash_length + gap_length
