class_name QuantumNodeManager
extends RefCounted

const QuantumNode = preload("res://Core/Visualization/QuantumNode.gd")

## Quantum Node Manager
##
## Manages quantum node lifecycle:
## - Creating nodes from biomes/plots
## - Updating node visuals from quantum state
## - Filtering nodes for active biome
## - Animation updates


func create_quantum_nodes(ctx: Dictionary) -> Array:
	"""Create quantum nodes from biomes and farm grid.

	Args:
	    ctx: Context dictionary with {biomes, farm_grid, plot_pool, layout_calculator}

	Returns:
	    Array of created QuantumNode instances
	"""
	var biomes = ctx.get("biomes", {})
	var farm_grid = ctx.get("farm_grid")
	var plot_pool = ctx.get("plot_pool")
	var layout_calculator = ctx.get("layout_calculator")

	var nodes: Array = []
	var node_by_plot_id: Dictionary = {}
	var quantum_nodes_by_grid_pos: Dictionary = {}
	var all_plot_positions: Dictionary = {}

	# Create nodes from farm grid plots
	if farm_grid:
		for grid_pos in farm_grid.plots:
			var plot = farm_grid.plots[grid_pos]
			if not plot:
				continue

			var node = _create_node_for_plot(plot, grid_pos, layout_calculator, biomes)
			if node:
				nodes.append(node)
				node_by_plot_id[node.plot_id] = node
				quantum_nodes_by_grid_pos[grid_pos] = node
				all_plot_positions[grid_pos] = node.classical_anchor

	# Create nodes from plot pool terminals (v2 system)
	if plot_pool and plot_pool.has_method("get_all_terminals"):
		for terminal in plot_pool.get_all_terminals():
			if not terminal.is_bound:
				continue

			var existing = quantum_nodes_by_grid_pos.get(terminal.grid_position)
			if existing:
				# Update existing node with terminal reference
				existing.terminal = terminal
				existing.has_farm_tether = true
				existing.emoji_north = terminal.north_emoji if terminal.north_emoji else existing.emoji_north
				existing.emoji_south = terminal.south_emoji if terminal.south_emoji else existing.emoji_south
				continue

			var node = _create_node_for_terminal(terminal, layout_calculator, biomes)
			if node:
				nodes.append(node)
				quantum_nodes_by_grid_pos[terminal.grid_position] = node

	return nodes


func _create_node_for_plot(plot, grid_pos: Vector2i, layout_calculator, biomes: Dictionary):
	"""Create a QuantumNode for a farm plot."""
	# Calculate initial anchor position
	var anchor_pos = Vector2.ZERO
	var center_pos = Vector2.ZERO
	var biome_name = ""
	if plot.parent_biome:
		biome_name = plot.parent_biome.biome_name if "biome_name" in plot.parent_biome else ""

	if layout_calculator:
		center_pos = layout_calculator.graph_center
		var positions = layout_calculator.distribute_nodes_in_biome(biome_name, 4)
		if positions.size() > 0:
			var idx = clampi(grid_pos.x, 0, positions.size() - 1)
			var params = positions[idx]
			anchor_pos = layout_calculator.get_parametric_position(
				biome_name,
				params.get("t", 0.5),
				params.get("ring", 0.5)
			)

	# Create node with required constructor arguments
	var node = QuantumNode.new(plot, anchor_pos, grid_pos, center_pos)

	node.plot_id = plot.plot_id if "plot_id" in plot else str(grid_pos)
	node.has_farm_tether = true

	# Set biome resolver for terminal-based biome lookup
	node.biome_resolver = func(name: String): return biomes.get(name, null)

	node.biome_name = biome_name
	if layout_calculator and biome_name != "":
		var positions = layout_calculator.distribute_nodes_in_biome(biome_name, 4)
		if positions.size() > 0:
			var idx = clampi(grid_pos.x, 0, positions.size() - 1)
			var params = positions[idx]
			node.parametric_t = params.get("t", 0.5)
			node.parametric_ring = params.get("ring", 0.5)

	# Initialize emojis
	if plot.is_planted:
		var emojis = plot.get_plot_emojis() if plot.has_method("get_plot_emojis") else {}
		node.emoji_north = emojis.get("north", "")
		node.emoji_south = emojis.get("south", "")

	return node


func _create_node_for_terminal(terminal, layout_calculator, biomes: Dictionary):
	"""Create a QuantumNode for a plot pool terminal."""
	# Calculate initial anchor position
	var anchor_pos = Vector2.ZERO
	var center_pos = Vector2.ZERO
	var biome_name = terminal.bound_biome_name if terminal.bound_biome_name != "" else ""

	if layout_calculator:
		center_pos = layout_calculator.graph_center
		var positions = layout_calculator.distribute_nodes_in_biome(biome_name, 4)
		if positions.size() > 0:
			var idx = clampi(terminal.grid_position.x, 0, positions.size() - 1)
			var params = positions[idx]
			anchor_pos = layout_calculator.get_parametric_position(
				biome_name,
				params.get("t", 0.5),
				params.get("ring", 0.5)
			)

	# Create node with required constructor arguments (null plot for terminal bubbles)
	var node = QuantumNode.new(null, anchor_pos, terminal.grid_position, center_pos)

	node.terminal = terminal
	node.has_farm_tether = true
	node.is_terminal_bubble = true

	# Set biome resolver for terminal-based biome lookup
	node.biome_resolver = func(name: String): return biomes.get(name, null)

	# Get biome name from terminal binding (now a string, not object)
	if biome_name != "":
		node.biome_name = biome_name
		if layout_calculator:
			var positions = layout_calculator.distribute_nodes_in_biome(biome_name, 4)
			if positions.size() > 0:
				var idx = clampi(terminal.grid_position.x, 0, positions.size() - 1)
				var params = positions[idx]
				node.parametric_t = params.get("t", 0.5)
				node.parametric_ring = params.get("ring", 0.5)

	# Set emojis from terminal
	node.emoji_north = terminal.north_emoji if terminal.north_emoji else ""
	node.emoji_south = terminal.south_emoji if terminal.south_emoji else ""

	return node


func _get_plot_index(grid_pos: Vector2i) -> int:
	"""Convert grid position to plot index for hex layout."""
	# Standard 2x3 grid mapping
	return grid_pos.y * 3 + grid_pos.x


func create_sun_qubit_node(biotic_flux_biome, layout_calculator) -> QuantumNode:
	"""Create the sun/moon qubit node."""
	if not biotic_flux_biome or not biotic_flux_biome.sun_qubit:
		return null

	# Calculate position
	var anchor_pos = Vector2.ZERO
	var center_pos = Vector2.ZERO

	if layout_calculator:
		center_pos = layout_calculator.graph_center
		anchor_pos = center_pos + Vector2(0, -layout_calculator.graph_radius * 0.7)

	# Create node with required constructor arguments (null plot, special grid pos for celestial)
	var node = QuantumNode.new(null, anchor_pos, Vector2i(-1, -1), center_pos)

	node.plot_id = "celestial_sun"
	node.biome_name = "BioticFlux"
	node.has_farm_tether = false

	var sun = biotic_flux_biome.sun_qubit
	node.emoji_north = sun.north_emoji
	node.emoji_south = sun.south_emoji

	node.radius = 35.0
	node.visual_scale = 1.0
	node.visual_alpha = 1.0

	return node


func update_node_visuals(nodes: Array, ctx: Dictionary) -> void:
	"""Update visual properties of all nodes from their quantum states.

	Optimized: Batches expensive purity queries per biome.

	Args:
	    nodes: Array of QuantumNode instances
	    ctx: Context dictionary with {biomes, time_accumulator}
	"""
	var biomes = ctx.get("biomes", {})
	var time_accumulator = ctx.get("time_accumulator", 0.0)
	var batcher = ctx.get("biome_evolution_batcher", null)
	var lookahead_offset = int(ctx.get("lookahead_offset", 1))

	# Cache purity per quantum source
	var purity_cache: Dictionary = {}
	var buffered_state_cache: Dictionary = {}
	var buffered_purity_cache: Dictionary = {}
	var buffered_register_cache: Dictionary = {}
	var use_lookahead = batcher != null and batcher.lookahead_enabled

	for node in nodes:
		# Trigger spawn animation for new nodes
		if not node.is_spawning and node.visual_scale == 0.0:
			if node.has_farm_tether and not node.emoji_north.is_empty():
				node.start_spawn_animation(time_accumulator)
			elif node.plot and node.plot.is_planted and node.plot.parent_biome and node.plot.bath_subplot_id >= 0:
				node.start_spawn_animation(time_accumulator)

		# Update from quantum state (unless terminal bubble with own data)
		if not node.is_terminal_bubble:
			_update_node_visual_batched(
				node,
				purity_cache,
				biomes,
				batcher,
				lookahead_offset,
				buffered_state_cache,
				buffered_purity_cache,
				buffered_register_cache,
				use_lookahead
			)
		else:
			_update_terminal_visuals_from_buffer(
				node,
				biomes,
				batcher,
				lookahead_offset,
				buffered_state_cache,
				buffered_purity_cache,
				buffered_register_cache,
				use_lookahead
			)


func _update_node_visual_batched(
	node,
	purity_cache: Dictionary,
	biomes: Dictionary,
	batcher,
	lookahead_offset: int,
	buffered_state_cache: Dictionary,
	buffered_purity_cache: Dictionary,
	buffered_register_cache: Dictionary,
	use_lookahead: bool
) -> void:
	"""Update single node's visuals with batched purity lookup."""
	# Terminal bubbles with no plot
	if node.has_farm_tether and not node.plot:
		if node.terminal and node.terminal.bound_biome_name != "":
			# Resolve biome from name using the biomes dictionary
			var biome = biomes.get(node.terminal.bound_biome_name, null)
			if biome and biome.quantum_computer and not node.is_terminal_measured():
				if use_lookahead and node.terminal and node.terminal.bound_register_id >= 0:
					if _apply_buffered_metrics(
						node,
						biome,
						node.terminal.bound_register_id,
						batcher,
						lookahead_offset,
						buffered_state_cache,
						buffered_purity_cache,
						buffered_register_cache
					):
						return
				var north_prob = biome.get_emoji_probability(node.emoji_north) if biome.has_method("get_emoji_probability") else 0.5
				var south_prob = biome.get_emoji_probability(node.emoji_south) if biome.has_method("get_emoji_probability") else 0.5
				var mass = north_prob + south_prob
				if mass > 0.001:
					node.emoji_north_opacity = north_prob / mass
					node.emoji_south_opacity = south_prob / mass
		return

	# Guard: unplanted plot → invisible
	if not node.plot or not node.plot.is_planted:
		node.energy = 0.0
		node.coherence = 1.0
		node.radius = node.MIN_RADIUS
		node.color = Color(0.5, 0.5, 0.5, 0.0)
		node.emoji_north_opacity = 0.0
		node.emoji_south_opacity = 0.0
		node.visual_scale = 0.0
		node.visual_alpha = 0.0
		return

	var biome = node.plot.parent_biome
	if not biome:
		_set_node_fallback(node)
		return

	var qc = biome.quantum_computer
	if not qc:
		_set_node_fallback(node)
		return

	if use_lookahead and "register_id" in node.plot and node.plot.register_id >= 0:
		if _apply_buffered_metrics(
			node,
			biome,
			node.plot.register_id,
			batcher,
			lookahead_offset,
			buffered_state_cache,
			buffered_purity_cache,
			buffered_register_cache
		):
			return

	# Query quantum data
	var emojis = node.plot.get_plot_emojis() if node.plot.has_method("get_plot_emojis") else {}
	node.emoji_north = emojis.get("north", "")
	node.emoji_south = emojis.get("south", "")

	# 1. Emoji opacity ← Probabilities
	var north_prob = qc.get_population(node.emoji_north) if qc.has_method("get_population") else 0.5
	var south_prob = qc.get_population(node.emoji_south) if qc.has_method("get_population") else 0.5
	var mass = north_prob + south_prob

	if mass > 0.001:
		node.emoji_north_opacity = north_prob / mass
		node.emoji_south_opacity = south_prob / mass
	else:
		node.emoji_north_opacity = 0.1
		node.emoji_south_opacity = 0.1

	# 2. Color hue ← Coherence phase
	var coh_magnitude = 0.0
	var coh_phase = 0.0

	if node.emoji_north != "" and node.emoji_south != "":
		var coherence = biome.get_emoji_coherence(node.emoji_north, node.emoji_south) if biome.has_method("get_emoji_coherence") else null
		if coherence:
			coh_magnitude = coherence.abs()
			coh_phase = atan2(coherence.im, coherence.re)
	var hue = (coh_phase + PI) / TAU
	var saturation = clampf(coh_magnitude * 2.0, 0.0, 1.0)
	node.color = Color.from_hsv(hue, saturation * 0.8, 0.9, 0.8)

	# 3. Glow (energy) ← Purity (cached)
	var source_id = qc.get_instance_id()
	if not purity_cache.has(source_id):
		purity_cache[source_id] = qc.get_purity() if qc.has_method("get_purity") else 0.5
	node.energy = purity_cache[source_id]

	# 4. Pulse rate ← Coherence magnitude
	node.coherence = coh_magnitude

	# 5. Radius ← Mass
	node.radius = lerpf(node.MIN_RADIUS, node.MAX_RADIUS, clampf(mass * 2.0, 0.0, 1.0))

	# 6. Berry phase
	node.berry_phase += node.energy * 0.01


func _update_terminal_visuals_from_buffer(
	node,
	biomes: Dictionary,
	batcher,
	lookahead_offset: int,
	buffered_state_cache: Dictionary,
	buffered_purity_cache: Dictionary,
	buffered_register_cache: Dictionary,
	use_lookahead: bool
) -> void:
	"""Update terminal bubbles from lookahead buffer when available."""
	if not node.terminal:
		return

	if node.terminal.north_emoji != "":
		node.emoji_north = node.terminal.north_emoji
	if node.terminal.south_emoji != "":
		node.emoji_south = node.terminal.south_emoji

	if node.terminal.is_measured:
		node.coherence = 0.0
		node.energy = 0.6
		node.color = Color(0.75, 0.75, 0.75, 0.9)
		if node.terminal.measured_outcome == node.terminal.north_emoji:
			node.emoji_north_opacity = 1.0
			node.emoji_south_opacity = 0.0
		else:
			node.emoji_north_opacity = 0.0
			node.emoji_south_opacity = 1.0
		return

	var biome = biomes.get(node.terminal.bound_biome_name, null)
	if not biome or not biome.quantum_computer:
		return

	if node.terminal.bound_register_id < 0:
		return

	if _apply_buffered_metrics(
		node,
		biome,
		node.terminal.bound_register_id,
		batcher,
		lookahead_offset,
		buffered_state_cache,
		buffered_purity_cache,
		buffered_register_cache
	):
		return

	# Fallback: basic opacities if viz cache unavailable
	var north_prob = biome.get_emoji_probability(node.emoji_north) if biome.has_method("get_emoji_probability") else 0.5
	var south_prob = biome.get_emoji_probability(node.emoji_south) if biome.has_method("get_emoji_probability") else 0.5
	var mass = north_prob + south_prob
	if mass > 0.001:
		node.emoji_north_opacity = north_prob / mass
		node.emoji_south_opacity = south_prob / mass
	node.color = Color(0.7, 0.8, 0.9, 0.8)
	node.energy = 0.5
	node.coherence = 0.0
	node.radius = lerpf(node.MIN_RADIUS, node.MAX_RADIUS, clampf(mass * 2.0, 0.0, 1.0))


func _apply_buffered_metrics(
	node,
	biome,
	register_id: int,
	batcher,
	lookahead_offset: int,
	buffered_state_cache: Dictionary,
	buffered_purity_cache: Dictionary,
	buffered_register_cache: Dictionary
) -> bool:
	"""Apply lookahead buffer metrics to a node. Returns true if applied.

	Delegates to QuantumComputer for all observable calculations.
	The QC's viz_metrics_cache is populated by BiomeEvolutionBatcher during buffer advance.
	"""
	var qc = biome.quantum_computer
	if not qc:
		return false

	# Ensure QC has cached visualization metrics (populated by batcher)
	var metrics = qc.get_viz_qubit_metrics(register_id)
	if metrics.is_empty():
		if batcher and batcher.has_method("get_buffered_state_offset"):
			var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name
			if biome_name != "":
				var packed = batcher.get_buffered_state_offset(biome_name, lookahead_offset)
				if not packed.is_empty():
					qc.compute_viz_metrics_from_packed(packed)
		if metrics.is_empty():
			qc.compute_viz_metrics_from_live()
		metrics = qc.get_viz_qubit_metrics(register_id)
		if metrics.is_empty():
			return false

	# Apply emoji opacities from QC
	var opacities = qc.compute_emoji_opacities(register_id)
	node.emoji_north_opacity = opacities.get("north_opacity", 0.5)
	node.emoji_south_opacity = opacities.get("south_opacity", 0.5)

	# Apply color from QC (hue from phase, saturation from coherence magnitude)
	node.color = qc.compute_bubble_color(register_id)

	# Apply purity (energy/glow)
	node.energy = qc.get_viz_purity()

	# Apply coherence magnitude
	node.coherence = metrics.get("coh_mag", 0.0)

	# Apply radius from mass
	node.radius = qc.compute_bubble_radius(register_id, node.MIN_RADIUS, node.MAX_RADIUS)

	# Accumulate berry phase
	node.berry_phase += node.energy * 0.01

	return true


func _set_node_fallback(node) -> void:
	"""Set fallback visualization when quantum state is unavailable."""
	node.energy = 1.0
	node.coherence = 0.5
	node.radius = node.MAX_RADIUS
	node.color = Color(0.7, 0.8, 0.9, 0.8)
	if node.plot and node.plot.has_method("get_plot_emojis"):
		var emojis = node.plot.get_plot_emojis()
		node.emoji_north = emojis.get("north", "")
		node.emoji_south = emojis.get("south", "")
	node.emoji_north_opacity = 0.5
	node.emoji_south_opacity = 0.5


func update_animations(nodes: Array, time_accumulator: float, delta: float) -> void:
	"""Update spawn animations for all nodes."""
	for node in nodes:
		node.update_animation(time_accumulator, delta)


func filter_nodes_for_biome(nodes: Array, active_biome: String) -> void:
	"""Update node visibility based on active biome.

	Args:
	    nodes: Array of QuantumNode instances
	    active_biome: Name of active biome, or "" for all biomes
	"""
	for node in nodes:
		if active_biome == "":
			node.visible = true
		else:
			node.visible = (node.biome_name == active_biome)


func is_node_in_active_biome(node, active_biome: String) -> bool:
	"""Check if a node belongs to the active biome."""
	if active_biome == "":
		return true
	return node.biome_name == active_biome


func rebuild_from_biomes(biomes: Dictionary, ctx: Dictionary) -> Array:
	"""Rebuild all quantum nodes from biomes.

	Called when biome configuration changes.

	Args:
	    biomes: Dictionary of biome_name → BiomeBase
	    ctx: Context dictionary

	Returns:
	    New array of QuantumNode instances
	"""
	ctx["biomes"] = biomes
	return create_quantum_nodes(ctx)
