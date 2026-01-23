class_name QuantumEffectsRenderer
extends RefCounted

## Quantum Effects Renderer
##
## Draws visual effects with mathematical basis:
##
## KEEP (Mathematical/Game Physics):
## - Strange attractor: Chaotic dynamics in 4D phase space
## - Icon auras: Field influence gradients
## - Icon influence forces: Attractor basins
## - Entanglement particles: Flowing along Bell pair lines
## - Life cycle effects: Spawns, deaths, coherence strikes
##
## REMOVED (No Math Basis):
## - Icon particles: Random spawn with no physics meaning


func draw(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw visual effects.

	Args:
	    graph: The QuantumForceGraph node
	    ctx: Context dictionary
	"""
	_draw_strange_attractor(graph, ctx)
	_draw_energy_transfer_forces(graph, ctx)
	_draw_particles(graph, ctx)
	_draw_life_cycle_effects(graph, ctx)

	# NOTE: Icon auras disabled - causes visual artifacts
	# _draw_icon_auras(graph, ctx)


func update_particles(delta: float, ctx: Dictionary) -> void:
	"""Update particle systems."""
	_update_entanglement_particles(delta, ctx)
	# NOTE: Icon particles REMOVED - no mathematical basis


func _draw_strange_attractor(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw the agricultural-political strange attractor.

	Visualizes the 4D political season cycle as a 2D trajectory.
	Real dynamical systems math: chaotic attractors in phase space.
	"""
	var imperium_icon = ctx.get("imperium_icon")
	var center_position = ctx.get("center_position", Vector2.ZERO)

	if not imperium_icon:
		return

	if not imperium_icon.has_method("get_attractor_history"):
		return

	var history = imperium_icon.get_attractor_history()
	if history.is_empty():
		return

	var attractor_color = Color(0.7, 0.6, 0.2, 0.4)
	var attractor_offset = center_position + Vector2(200, 200)

	# Draw trajectory trail
	for i in range(1, history.size()):
		var prev_snapshot = history[i - 1]
		var curr_snapshot = history[i]

		var prev_2d = imperium_icon.project_4d_to_2d(prev_snapshot)
		var curr_2d = imperium_icon.project_4d_to_2d(curr_snapshot)

		var prev_pos = attractor_offset + prev_2d
		var curr_pos = attractor_offset + curr_2d

		var fade = float(i) / float(history.size())
		var line_color = attractor_color
		line_color.a = fade * 0.5

		graph.draw_line(prev_pos, curr_pos, line_color, 2.0, true)

	# Current position
	if history.size() > 0:
		var current = history[history.size() - 1]
		var current_2d = imperium_icon.project_4d_to_2d(current)
		var current_pos = attractor_offset + current_2d

		graph.draw_circle(current_pos, 5.0, Color(1.0, 0.8, 0.3, 0.8))
		graph.draw_circle(current_pos, 3.0, Color(1.0, 0.9, 0.5, 1.0))

	# Label
	var label_pos = attractor_offset + Vector2(-80, -90)
	var label_color = Color(0.8, 0.7, 0.3, 0.7)
	var font = ThemeDB.fallback_font
	var season = imperium_icon.get_political_season() if imperium_icon.has_method("get_political_season") else ""
	graph.draw_string(font, label_pos, "Political Season", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)
	if season != "":
		graph.draw_string(font, label_pos + Vector2(0, 16), season, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_color.lightened(0.2))


func _draw_energy_transfer_forces(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw energy transfer forces from sun (Lindbladian evolution).

	Game physics: Hamiltonian potential wells create attractor basins.
	"""
	var sun_qubit_node = ctx.get("sun_qubit_node")
	var biotic_flux_biome = ctx.get("biotic_flux_biome")
	var quantum_nodes = ctx.get("quantum_nodes", [])

	if not sun_qubit_node or not biotic_flux_biome:
		return

	var sun_color_vis = biotic_flux_biome.get_sun_visualization()
	var sun_theta = sun_color_vis["theta"]

	var energy_strength = abs(cos(sun_theta))
	if energy_strength < 0.1:
		return

	for node in quantum_nodes:
		if not node.plot or not node.plot.is_planted or not node.plot.quantum_state:
			continue

		if node.plot_id == "celestial_sun" or node.plot_id == "celestial_moon":
			continue

		var qubit = node.plot.quantum_state
		if not qubit:
			continue

		var alignment = cos((qubit.theta - sun_theta) / 2.0)
		var plot_alignment = cos(qubit.theta / 2.0)
		var energy_transfer_rate = plot_alignment * plot_alignment * alignment * alignment * energy_strength

		if energy_transfer_rate < 0.05:
			continue

		var arrow_thickness = clamp(energy_transfer_rate * 3.0, 0.5, 2.5)
		var arrow_color = sun_color_vis["color"]
		arrow_color.a = clamp(energy_transfer_rate * 0.8, 0.2, 0.7)

		var from = sun_qubit_node.position
		var to = node.position
		graph.draw_line(from, to, arrow_color, arrow_thickness, true)

		# Arrow head
		var direction = (to - from).normalized()
		var arrow_size = arrow_thickness * 3.0
		var arrow_left = to - direction * arrow_size + direction.rotated(PI/2) * arrow_size * 0.5
		var arrow_right = to - direction * arrow_size - direction.rotated(PI/2) * arrow_size * 0.5

		var arrow_head_color = arrow_color
		arrow_head_color.a = arrow_color.a * 0.8
		graph.draw_colored_polygon([to, arrow_left, arrow_right], arrow_head_color)

	# Icon influence forces
	_draw_icon_influence_forces(graph, ctx)


func _draw_icon_influence_forces(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw spring attraction forces toward icon stable points.

	Game physics: Shows how icons pull qubits toward their stable states.
	"""
	var biotic_flux_biome = ctx.get("biotic_flux_biome")
	var quantum_nodes = ctx.get("quantum_nodes", [])

	if not biotic_flux_biome:
		return

	var wheat_stable = PI / 4.0
	var mushroom_stable = PI

	for node in quantum_nodes:
		if not node.plot or not node.plot.is_planted or not node.plot.quantum_state:
			continue

		if node.plot_id == "celestial_sun" or node.plot_id == "celestial_moon":
			continue

		var qubit = node.plot.quantum_state
		if not qubit:
			continue

		var wheat_deviation = abs(qubit.theta - wheat_stable)
		var mushroom_deviation = abs(qubit.theta - mushroom_stable)

		if wheat_deviation > PI:
			wheat_deviation = TAU - wheat_deviation
		if mushroom_deviation > PI:
			mushroom_deviation = TAU - mushroom_deviation

		# Wheat icon force
		if biotic_flux_biome.wheat_icon and wheat_deviation > 0.1:
			var spring_strength = (1.0 - wheat_deviation / PI) * 0.6
			if spring_strength > 0.1:
				var wheat_color = Color(1.0, 0.9, 0.3, spring_strength * 0.5)
				var force_magnitude = spring_strength * 15.0
				var force_direction = sign(wheat_stable - qubit.theta)
				if abs(wheat_stable - qubit.theta) > PI:
					force_direction = -force_direction

				var indicator_center = node.position
				var indicator_direction = Vector2(cos(qubit.theta), sin(qubit.theta))
				var indicator_end = indicator_center + indicator_direction * force_magnitude * force_direction
				graph.draw_line(indicator_center, indicator_end, wheat_color, 1.0, true)

		# Mushroom icon force
		if biotic_flux_biome.mushroom_icon and mushroom_deviation > 0.1:
			var spring_strength = (1.0 - mushroom_deviation / PI) * 0.6
			if spring_strength > 0.1:
				var mushroom_color = Color(0.8, 0.4, 0.9, spring_strength * 0.5)
				var force_magnitude = spring_strength * 15.0
				var force_direction = sign(mushroom_stable - qubit.theta)
				if abs(mushroom_stable - qubit.theta) > PI:
					force_direction = -force_direction

				var indicator_center = node.position
				var indicator_direction = Vector2(cos(qubit.theta), sin(qubit.theta))
				var indicator_end = indicator_center + indicator_direction * force_magnitude * force_direction * 1.5
				graph.draw_line(indicator_center, indicator_end, mushroom_color, 1.0, true)


func _draw_particles(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw entanglement particles flowing along Bell pair lines."""
	var entanglement_particles = ctx.get("entanglement_particles", [])

	for particle in entanglement_particles:
		var life_ratio = particle.life / particle.get("max_life", 1.0)
		var alpha = clamp(life_ratio, 0.0, 1.0)

		# Outer glow
		var glow_color = particle.color
		glow_color.a = alpha * 0.4
		graph.draw_circle(particle.position, particle.size * 2.0, glow_color)

		# Core
		var core_color = Color.WHITE
		core_color.a = alpha * 0.9
		graph.draw_circle(particle.position, particle.size, core_color)


func _draw_life_cycle_effects(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw life cycle effects: spawns, deaths, coherence strikes."""
	var life_cycle_effects = ctx.get("life_cycle_effects", {})
	var font = ThemeDB.fallback_font

	# Spawn effects
	for effect in life_cycle_effects.get("spawns", []):
		var pos = effect.get("position", Vector2.ZERO)
		var t = effect.get("time", 0.0)
		var color = effect.get("color", Color.GREEN)

		var duration = 1.0
		var progress = clamp(t / duration, 0.0, 1.0)
		var alpha = 1.0 - progress

		var ring_radius = 10.0 + progress * 50.0
		var ring_color = color
		ring_color.a = alpha * 0.6
		graph.draw_arc(pos, ring_radius, 0, TAU, 32, ring_color, 3.0, true)

		var glow_color = color.lightened(0.3)
		glow_color.a = alpha * 0.4
		graph.draw_circle(pos, ring_radius * 0.5, glow_color)

		for i in range(4):
			var angle = (t * 3.0 + i * TAU / 4.0)
			var sparkle_pos = pos + Vector2(cos(angle), sin(angle)) * ring_radius * 0.7
			var sparkle_color = Color.WHITE
			sparkle_color.a = alpha * 0.8
			graph.draw_circle(sparkle_pos, 3.0 * (1.0 - progress), sparkle_color)

	# Death effects
	for effect in life_cycle_effects.get("deaths", []):
		var pos = effect.get("position", Vector2.ZERO)
		var t = effect.get("time", 0.0)
		var icon = effect.get("icon", "💀")

		var duration = 1.0
		var progress = clamp(t / duration, 0.0, 1.0)
		var alpha = 1.0 - progress

		var ghost_pos = pos + Vector2(0, -progress * 30.0)
		var emoji_alpha = alpha * 0.8
		graph.draw_string(font, ghost_pos, icon, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(1, 1, 1, emoji_alpha))

		for i in range(6):
			var angle = i * TAU / 6.0 + t * 2.0
			var dist = progress * 40.0
			var particle_pos = pos + Vector2(cos(angle), sin(angle) - progress) * dist
			var particle_color = Color(0.5, 0.5, 0.5, alpha * 0.5)
			graph.draw_circle(particle_pos, 2.0 * (1.0 - progress), particle_color)

	# Coherence strike effects
	for effect in life_cycle_effects.get("strikes", []):
		var from_pos = effect.get("from", Vector2.ZERO)
		var to_pos = effect.get("to", Vector2.ZERO)
		var t = effect.get("time", 0.0)

		var duration = 0.5
		var progress = clamp(t / duration, 0.0, 1.0)
		var alpha = 1.0 - progress

		var flash_color = Color(1.0, 0.95, 0.5, alpha)
		var direction = (to_pos - from_pos).normalized()
		var distance = from_pos.distance_to(to_pos)
		var perp = direction.rotated(PI / 2.0)

		var segments = 5
		var prev_point = from_pos
		for i in range(segments):
			var t_seg = float(i + 1) / float(segments)
			var base_point = from_pos.lerp(to_pos, t_seg)
			var offset = 0.0 if i == segments - 1 else (randf() - 0.5) * 20.0
			var point = base_point + perp * offset

			var glow = flash_color
			glow.a = alpha * 0.3
			graph.draw_line(prev_point, point, glow, 8.0, true)
			graph.draw_line(prev_point, point, flash_color, 3.0, true)

			prev_point = point

		var impact_size = 20.0 * (1.0 - progress)
		var impact_color = flash_color
		impact_color.a = alpha * 0.6
		graph.draw_circle(to_pos, impact_size, impact_color)


func _update_entanglement_particles(delta: float, ctx: Dictionary) -> void:
	"""Update entanglement particles."""
	var entanglement_particles = ctx.get("entanglement_particles", [])
	var quantum_nodes = ctx.get("quantum_nodes", [])
	var node_by_plot_id = ctx.get("node_by_plot_id", {})
	var particle_life = ctx.get("particle_life", 1.5)
	var particle_speed = ctx.get("particle_speed", 80.0)
	var particle_size = ctx.get("particle_size", 3.0)

	# Update existing particles
	for i in range(entanglement_particles.size() - 1, -1, -1):
		var particle = entanglement_particles[i]
		particle.life -= delta
		particle.position += particle.velocity * delta

		if particle.life <= 0.0:
			entanglement_particles.remove_at(i)

	# Spawn new particles
	var spawn_rate = 3.0

	for node in quantum_nodes:
		if not node.plot:
			continue

		for partner_id in node.plot.entangled_plots.keys():
			var partner_node = node_by_plot_id.get(partner_id)
			if not partner_node or node.plot_id > partner_id:
				continue

			if randf() < spawn_rate * delta:
				var start_pos = node.position
				var end_pos = partner_node.position
				var progress = randf()
				var pos = start_pos.lerp(end_pos, progress)
				var direction = (end_pos - start_pos).normalized()

				var particle = {
					"position": pos,
					"velocity": direction * particle_speed,
					"life": particle_life,
					"max_life": particle_life,
					"color": Color(0.3, 0.95, 1.0),
					"size": particle_size
				}

				entanglement_particles.append(particle)
