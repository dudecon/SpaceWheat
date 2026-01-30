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
	"""Create quantum nodes from quantum registers (first-class architecture).

	Args:
	    ctx: Context dictionary with {biomes, farm_grid, plot_pool, layout_calculator}

	Returns:
	    Array of created QuantumNode instances

	NEW ARCHITECTURE:
	  1. Create bubbles FROM quantum registers (primary source)
	  2. Optionally overlay terminal/plot data (secondary game mechanics)
	  3. Plots are UI-only, don't drive bubble creation
	"""
	var biomes = ctx.get("biomes", {})
	var farm_grid = ctx.get("farm_grid")
	var plot_pool = ctx.get("plot_pool")
	var layout_calculator = ctx.get("layout_calculator")

	var nodes: Array = []
	var nodes_by_register: Dictionary = {}  # Key: "biome_name:register_id"

	# PRIMARY: Create nodes from quantum registers (one bubble per register)
	var total_registers = 0
	for biome_name in biomes:
		var biome = biomes[biome_name]
		if not biome or not biome.viz_cache or not biome.viz_cache.has_metadata():
			print("  [QuantumNodeManager] Skipping biome %s (no viz_cache)" % biome_name)
			continue

		var num_registers = biome.viz_cache.get_num_qubits()
		total_registers += num_registers
		for register_id in range(num_registers):
			var node = _create_node_for_register(biome_name, register_id, biomes, layout_calculator)
			if node:
				nodes.append(node)
				var key = "%s:%d" % [biome_name, register_id]
				nodes_by_register[key] = node

	print("  [QuantumNodeManager] Created %d bubbles from %d quantum registers" % [nodes.size(), total_registers])

	# SECONDARY: Overlay terminal data on existing nodes (optional game mechanics)
	if plot_pool and plot_pool.has_method("get_all_terminals"):
		for terminal in plot_pool.get_all_terminals():
			if not terminal.is_bound:
				continue

			var key = "%s:%d" % [terminal.bound_biome_name, terminal.bound_register_id]
			var node = nodes_by_register.get(key)
			if node:
				# Attach terminal to existing bubble (game mechanic overlay)
				node.terminal = terminal
				node.grid_position = terminal.grid_position
				node.has_farm_tether = true
				# Emojis come from terminal binding for gameplay
				node.emoji_north = terminal.north_emoji if terminal.north_emoji else node.emoji_north
				node.emoji_south = terminal.south_emoji if terminal.south_emoji else node.emoji_south

	return nodes


func _create_node_for_register(biome_name: String, register_id: int, biomes: Dictionary, layout_calculator):
	"""Create a QuantumNode directly from a quantum register (first-class architecture).

	Args:
	    biome_name: Name of the biome containing the register
	    register_id: Index of the register/qubit in the quantum computer
	    biomes: Dictionary of all biomes for resolver
	    layout_calculator: For positioning bubbles

	Returns:
	    QuantumNode representing this quantum register
	"""
	var biome = biomes.get(biome_name)
	if not biome or not biome.viz_cache or not biome.viz_cache.has_metadata():
		return null

	if register_id < 0 or register_id >= biome.viz_cache.get_num_qubits():
		return null

	# Calculate position from biome layout
	var anchor_pos = Vector2.ZERO
	var center_pos = Vector2.ZERO
	var parametric_t = 0.5
	var parametric_ring = 0.5

	if layout_calculator:
		center_pos = layout_calculator.graph_center
		# Distribute registers evenly around biome oval
		var num_registers = biome.viz_cache.get_num_qubits()
		parametric_t = float(register_id) / float(num_registers) if num_registers > 0 else 0.5
		parametric_ring = 0.7  # Place on outer ring by default

		anchor_pos = layout_calculator.get_parametric_position(
			biome_name,
			parametric_t,
			parametric_ring
		)

	# Create node (no plot, no terminal initially - pure quantum)
	var node = QuantumNode.new(null, anchor_pos, Vector2i(-1, -1), center_pos)

	# PRIMARY quantum reference (this is what makes it first-class)
	node.biome_name = biome_name
	node.register_id = register_id
	node.plot_id = "%s_r%d" % [biome_name, register_id]  # Unique ID based on register

	# Biome resolver for quantum state queries
	node.biome_resolver = func(name: String): return biomes.get(name, null)

	# Parametric coordinates for layout
	node.parametric_t = parametric_t
	node.parametric_ring = parametric_ring

	# Get emojis from quantum register via biome
	var axis = biome.viz_cache.get_axis(register_id) if biome.viz_cache else {}
	node.emoji_north = axis.get("north", "")
	node.emoji_south = axis.get("south", "")

	# DEBUG: Check if emojis are set
	if register_id == 0:  # Only print for first register per biome
		print("    [DEBUG] Node for %s:r%d - north='%s', south='%s', biome_name='%s'" % [
			biome_name, register_id, node.emoji_north, node.emoji_south, node.biome_name
		])

	# Not a terminal bubble (pure quantum visualization)
	node.is_terminal_bubble = false
	node.has_farm_tether = false

	# Ensure node is visible and has physics enabled
	node.visible = true
	node.quantum_behavior = 0  # 0 = FLOATING (physics enabled)

	return node


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
	var use_lookahead = batcher != null and batcher.lookahead_enabled
	var lookahead_offset = ctx.get("lookahead_offset", 0)

	for node in nodes:
		# Trigger spawn animation for new nodes
		if not node.is_spawning and node.visual_scale == 0.0:
			# Pure quantum nodes (no plot, no terminal)
			if not node.has_farm_tether and node.biome_name != "" and not node.emoji_north.is_empty():
				node.start_spawn_animation(time_accumulator)
			# Terminal nodes with farm tether
			elif node.has_farm_tether and not node.emoji_north.is_empty():
				node.start_spawn_animation(time_accumulator)
			# Plot-based nodes
			elif node.plot and node.plot.is_planted and node.plot.parent_biome and node.plot.bath_subplot_id >= 0:
				node.start_spawn_animation(time_accumulator)

		# Update from quantum state (unless terminal bubble with own data)
		if not node.is_terminal_bubble:
			_update_node_visual_batched(
				node,
				biomes,
				use_lookahead,
				lookahead_offset,
				batcher
			)
		else:
			_update_terminal_visuals_from_buffer(
				node,
				biomes,
				use_lookahead,
				lookahead_offset,
				batcher
			)


func _update_node_visual_batched(
	node,
	biomes: Dictionary,
	use_lookahead: bool,
	lookahead_offset: int,
	batcher = null
) -> void:
	"""Update single node's visuals with batched purity lookup."""
	# PURE QUANTUM VISUALIZATION (no plot, no terminal - first-class quantum)
	if not node.has_farm_tether and not node.plot and node.biome_name != "":
		var biome = biomes.get(node.biome_name, null)
		if biome and biome.viz_cache and node.register_id >= 0:
			# Update from quantum state directly
			node.update_from_quantum_state()
			# Ensure node is visible
			if node.visual_scale == 0.0:
				node.visual_scale = 1.0
				node.visual_alpha = 1.0
			return
		else:
			_set_node_fallback(node)
			return

	# Terminal bubbles with no plot
	if node.has_farm_tether and not node.plot:
		if node.terminal and node.terminal.bound_biome_name != "":
			if node.terminal.north_emoji != "":
				node.emoji_north = node.terminal.north_emoji
			if node.terminal.south_emoji != "":
				node.emoji_south = node.terminal.south_emoji
			# Resolve biome from name using the biomes dictionary
			var biome = biomes.get(node.terminal.bound_biome_name, null)
			if biome and biome.viz_cache and not node.is_terminal_measured():
				if use_lookahead and node.terminal and node.terminal.bound_register_id >= 0:
					if _apply_buffered_metrics(
						node,
						biome,
						node.terminal.bound_register_id,
						use_lookahead,
						lookahead_offset,
						batcher
					):
						return
			_set_node_fallback(node)
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

	if not biome.viz_cache:
		_set_node_fallback(node)
		return

	var emojis = node.plot.get_plot_emojis() if node.plot.has_method("get_plot_emojis") else {}
	node.emoji_north = emojis.get("north", node.emoji_north)
	node.emoji_south = emojis.get("south", node.emoji_south)

	if use_lookahead and "register_id" in node.plot and node.plot.register_id >= 0:
		if _apply_buffered_metrics(
			node,
			biome,
			node.plot.register_id,
			use_lookahead,
			lookahead_offset,
			batcher
		):
			return
	_set_node_fallback(node)
	return


func _update_terminal_visuals_from_buffer(
	node,
	biomes: Dictionary,
	use_lookahead: bool,
	lookahead_offset: int,
	batcher = null
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
	if not biome or not biome.viz_cache:
		_set_node_fallback(node)
		return

	if node.terminal.bound_register_id < 0:
		return

	if _apply_buffered_metrics(
		node,
		biome,
		node.terminal.bound_register_id,
		use_lookahead,
		lookahead_offset,
		batcher
	):
		return

	_set_node_fallback(node)


func _apply_buffered_metrics(
	node,
	biome,
	register_id: int,
	use_lookahead: bool,
	lookahead_offset: int,
	batcher = null
) -> bool:
	"""Apply lookahead buffer metrics to a node. Returns true if applied.

	Delegates to biome viz_cache populated by lookahead packets.
	"""
	if not biome or not biome.viz_cache:
		return false

	var snap: Dictionary = {}
	if use_lookahead and batcher and batcher.has_method("get_viz_snapshot"):
		var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name
		snap = batcher.get_viz_snapshot(biome_name, register_id, lookahead_offset)
	else:
		snap = biome.viz_cache.get_snapshot(register_id)
	if snap.is_empty():
		return false

	var p0 = snap.get("p0", 0.5)
	var p1 = snap.get("p1", 0.5)
	var r_xy = snap.get("r_xy", 0.0)
	var phi = snap.get("phi", 0.0)
	var purity = snap.get("purity", -1.0)

	node.emoji_north_opacity = p0
	node.emoji_south_opacity = p1

	var hue = (phi + PI) / TAU
	node.color = Color.from_hsv(hue, r_xy * 0.8, 0.9, 0.8)

	node.energy = purity if purity >= 0.0 else 0.5
	node.coherence = r_xy * 0.5

	var mass = p0 + p1
	# Radius represents probability mass (p0+p1), not purity
	# Purity is encoded spatially via force system (pure → center, mixed → edge)
	node.radius = lerpf(node.MIN_RADIUS, node.MAX_RADIUS * 0.7, clampf(mass * 2.0, 0.0, 1.0))

	# Berry phase accumulation DISABLED - should come from C++ geometric phase
	# Real berry phase = ∮ ⟨ψ|i∇|ψ⟩·dλ computed during evolution path in C++
	# node.berry_phase += node.energy * 0.01  # This was fake - not geometric phase!

	return true


func _set_node_fallback(node) -> void:
	"""Set fallback visualization when quantum state is unavailable."""
	node.energy = 0.0
	node.coherence = 0.0
	node.radius = node.MIN_RADIUS
	node.color = Color(0.4, 0.4, 0.5, 0.4)
	if node.plot and node.plot.has_method("get_plot_emojis"):
		var emojis = node.plot.get_plot_emojis()
		node.emoji_north = emojis.get("north", "")
		node.emoji_south = emojis.get("south", "")
	node.emoji_north_opacity = 0.0
	node.emoji_south_opacity = 0.0


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
