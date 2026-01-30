class_name QuantumRegionRenderer
extends RefCounted

## Quantum Region Renderer
##
## Draws background regions and environmental visualizations:
## - Biome ovals (multi-biome view)
## - Temperature heatmap (decoherence zones)
## - Orbit trails (evolution history paths)


func draw(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw background regions.

	Args:
	    graph: The QuantumForceGraph node
	    ctx: Context dictionary
	"""
	_draw_biome_regions(graph, ctx)
	_draw_temperature_heatmap(graph, ctx)
	_draw_orbit_trails(graph, ctx)


func _draw_biome_regions(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw biome regions - OVALS REMOVED (replaced by BiomeBackground images).

	Now only calls biome's custom rendering callback if present.
	"""
	var biomes = ctx.get("biomes", {})
	var layout_calculator = ctx.get("layout_calculator")
	var active_biome = ctx.get("active_biome", "")
	var center_position = ctx.get("center_position", Vector2.ZERO)

	if not layout_calculator:
		return

	for biome_name in biomes:
		# Skip non-active biomes in single-biome view
		if active_biome != "" and biome_name != active_biome:
			continue

		var biome_obj = biomes[biome_name]

		var oval = layout_calculator.get_biome_oval(biome_name)
		if oval.is_empty():
			continue

		var biome_center = oval.get("center", center_position)
		var semi_a = oval.get("semi_a", 100.0)
		var semi_b = oval.get("semi_b", 60.0)

		# OVALS REMOVED - BiomeBackground now provides full-screen biome art
		# The colored ovals were old zone markers, replaced by pretty backgrounds

		# Call biome's custom rendering callback (if any)
		var biome_radius = (semi_a + semi_b) / 2.0
		if biome_obj and biome_obj.has_method("render_biome_content"):
			biome_obj.render_biome_content(graph, biome_center, biome_radius)


## _draw_filled_oval and _draw_oval_outline REMOVED
## Ovals replaced by BiomeBackground full-screen images


func _draw_temperature_heatmap(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw temperature/decoherence heatmap as background gradient.

	Hot zones (high decoherence) appear red/orange.
	Cold zones (low decoherence) appear blue/cyan.
	"""
	var biomes = ctx.get("biomes", {})
	var layout_calculator = ctx.get("layout_calculator")
	var active_biome = ctx.get("active_biome", "")

	if not layout_calculator:
		return

	for biome_name in biomes:
		if active_biome != "" and biome_name != active_biome:
			continue

		var biome = biomes[biome_name]
		if not biome:
			continue

		var oval = layout_calculator.get_biome_oval(biome_name)
		if oval.is_empty():
			continue

		var center = oval.get("center", Vector2.ZERO)
		var semi_a = oval.get("semi_a", 100.0)
		var semi_b = oval.get("semi_b", 60.0)

		# Get average decoherence from sink fluxes
		var total_flux = 0.0
		var flux_count = 0
		var fluxes = biome.viz_cache.get_sink_fluxes() if biome.viz_cache else {}
		for emoji in fluxes:
			total_flux += fluxes[emoji]
			flux_count += 1

		var avg_flux = total_flux / max(flux_count, 1)

		# Map flux to color
		var heat_intensity = clampf(avg_flux * 50.0, 0.0, 1.0)
		var heat_color: Color
		if heat_intensity < 0.5:
			heat_color = Color(0.2 + heat_intensity * 0.4, 0.2, 0.6 - heat_intensity * 0.2, 0.15)
		else:
			var t = (heat_intensity - 0.5) * 2.0
			heat_color = Color(0.4 + t * 0.5, 0.2 - t * 0.15, 0.4 - t * 0.3, 0.15)

		# Draw radial gradient
		var segments = 32
		for ring in range(3):
			var ring_t = float(ring) / 3.0
			var ring_radius = (semi_a + semi_b) / 2.0 * (0.4 + ring_t * 0.5)

			var ring_color = heat_color
			ring_color.a = heat_color.a * (0.5 + ring_t * 0.5)

			if ring > 0:
				graph.draw_arc(center, ring_radius, 0, TAU, segments, ring_color, 3.0, true)


func _draw_orbit_trails(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw fading trails showing bubble evolution history."""
	var quantum_nodes = ctx.get("quantum_nodes", [])

	for node in quantum_nodes:
		if not node.visible:
			continue

		if node.position_history.size() < 2:
			continue

		if node.visual_scale <= 0.0:
			continue

		var trail_color = node.color
		var history_size = node.position_history.size()

		for i in range(history_size - 1):
			var t = float(i) / float(history_size)
			var alpha = t * 0.4 * node.visual_alpha

			var line_color = trail_color
			line_color.a = alpha

			var width = 1.0 + t * 2.0

			graph.draw_line(node.position_history[i], node.position_history[i + 1], line_color, width, true)

		# Connect to current position
		if history_size > 0:
			var line_color = trail_color
			line_color.a = 0.4 * node.visual_alpha
			graph.draw_line(node.position_history[history_size - 1], node.position, line_color, 3.0, true)
