class_name EntanglementLines
extends Node2D

## EntanglementLines - Draws quantum connection lines between entangled plots
## Visualizes the spooky action at a distance ✨

# References (set by FarmView)
var farm_grid: Node = null
var plot_tiles: Array = []

# Visual configuration
const LINE_WIDTH = 3.0
const LINE_COLOR_START = Color(0.4, 0.6, 1.0, 0.8)  # Blue
const LINE_COLOR_END = Color(0.8, 0.4, 1.0, 0.8)    # Purple
const PARTICLE_COLOR = Color(1.0, 1.0, 1.0, 0.9)

# Line nodes (one per entanglement)
var line_nodes: Dictionary = {}  # Key: "pos_a:pos_b", Value: Line2D

# Animation state
var time_offset: float = 0.0


func _ready():
	z_index = -1  # Draw behind tiles but above background


func _process(delta):
	time_offset += delta
	_update_lines()


func setup(grid: Node, tiles: Array):
	"""Initialize with references to farm grid and plot tiles"""
	farm_grid = grid
	plot_tiles = tiles
	_rebuild_all_lines()


func _rebuild_all_lines():
	"""Rebuild all line visuals from scratch"""
	# Clear existing lines
	for line in line_nodes.values():
		line.queue_free()
	line_nodes.clear()

	if farm_grid == null or plot_tiles.is_empty():
		return

	# Create lines for all entanglements
	for y in range(farm_grid.grid_height):
		for x in range(farm_grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm_grid.get_plot(pos)

			if plot == null or not plot.is_planted:
				continue

			# Create lines for this plot's entanglements
			for other_plot_id in plot.entangled_plots.keys():
				var strength = plot.entangled_plots[other_plot_id]
				var other_pos = _find_plot_position(other_plot_id)
				if other_pos == Vector2i(-1, -1):
					continue

				# Only create line once (avoid duplicates)
				var key = _get_line_key(pos, other_pos)
				if not line_nodes.has(key):
					_create_line(pos, other_pos, strength)


func _update_lines():
	"""Update existing lines (remove dead ones, add new ones)"""
	if farm_grid == null:
		return

	var active_connections = {}

	# Collect all active entanglements
	for y in range(farm_grid.grid_height):
		for x in range(farm_grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm_grid.get_plot(pos)

			if plot == null or not plot.is_planted:
				continue

			for other_plot_id in plot.entangled_plots.keys():
				var strength = plot.entangled_plots[other_plot_id]
				var other_pos = _find_plot_position(other_plot_id)
				if other_pos == Vector2i(-1, -1):
					continue

				var key = _get_line_key(pos, other_pos)
				active_connections[key] = {
					"pos_a": pos,
					"pos_b": other_pos,
					"strength": strength
				}

	# Remove dead lines
	var keys_to_remove = []
	for key in line_nodes.keys():
		if not active_connections.has(key):
			line_nodes[key].queue_free()
			keys_to_remove.append(key)

	for key in keys_to_remove:
		line_nodes.erase(key)

	# Add new lines
	for key in active_connections.keys():
		if not line_nodes.has(key):
			var conn = active_connections[key]
			_create_line(conn["pos_a"], conn["pos_b"], conn["strength"])

	# Animate existing lines
	_animate_lines()


func _create_line(pos_a: Vector2i, pos_b: Vector2i, strength: float):
	"""Create a new Line2D for an entanglement"""
	var line = Line2D.new()

	# Get tile centers
	var tile_a = _get_tile(pos_a)
	var tile_b = _get_tile(pos_b)

	if tile_a == null or tile_b == null:
		return

	var center_a = tile_a.global_position + tile_a.size / 2
	var center_b = tile_b.global_position + tile_b.size / 2

	# Setup line visual
	line.add_point(to_local(center_a))
	line.add_point(to_local(center_b))
	line.width = LINE_WIDTH

	# Color gradient based on strength
	var gradient = Gradient.new()
	gradient.add_point(0.0, LINE_COLOR_START.lerp(LINE_COLOR_END, strength * 0.5))
	gradient.add_point(1.0, LINE_COLOR_END.lerp(LINE_COLOR_START, strength * 0.5))
	line.gradient = gradient

	# Slight transparency based on strength
	line.modulate.a = 0.6 + strength * 0.4

	# Store and add to scene
	var key = _get_line_key(pos_a, pos_b)
	line_nodes[key] = line
	add_child(line)


func _animate_lines():
	"""Add shimmer effect to lines"""
	for line in line_nodes.values():
		if line == null:
			continue

		# Pulsing alpha
		var pulse = (sin(time_offset * 2.0) + 1.0) / 2.0  # 0 to 1
		var base_alpha = 0.6
		line.modulate.a = base_alpha + pulse * 0.3

		# Gradient animation
		if line.gradient:
			var shift = (sin(time_offset * 3.0) + 1.0) / 2.0
			var color_a = LINE_COLOR_START.lerp(LINE_COLOR_END, shift)
			var color_b = LINE_COLOR_END.lerp(LINE_COLOR_START, shift)
			line.gradient.set_color(0, color_a)
			line.gradient.set_color(1, color_b)


func force_refresh():
	"""Force rebuild all lines (call when entanglements change)"""
	_rebuild_all_lines()


## Helpers

func _get_line_key(pos_a: Vector2i, pos_b: Vector2i) -> String:
	"""Generate unique key for line (order-independent)"""
	var min_pos = pos_a if (pos_a.x < pos_b.x or (pos_a.x == pos_b.x and pos_a.y < pos_b.y)) else pos_b
	var max_pos = pos_b if min_pos == pos_a else pos_a
	return "%d,%d:%d,%d" % [min_pos.x, min_pos.y, max_pos.x, max_pos.y]


func _find_plot_position(plot_id: String) -> Vector2i:
	"""Find grid position of a plot by its ID"""
	if farm_grid == null:
		return Vector2i(-1, -1)

	for y in range(farm_grid.grid_height):
		for x in range(farm_grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm_grid.get_plot(pos)
			if plot and plot.plot_id == plot_id:
				return pos

	return Vector2i(-1, -1)


func _get_tile(pos: Vector2i) -> Control:
	"""Get PlotTile at grid position"""
	if plot_tiles.is_empty():
		return null

	var grid_width = farm_grid.grid_width if farm_grid else 5
	var index = pos.y * grid_width + pos.x

	if index < 0 or index >= plot_tiles.size():
		return null

	return plot_tiles[index]
