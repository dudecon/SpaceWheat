class_name ParametricPlotPositioner

## ParametricPlotPositioner - Calculate parametric positions for plots around biomes
##
## Replaces GridContainer layout with biome-based oval ring positioning.
## Plots are positioned parametrically using get_plot_positions_in_oval() from each biome.
##
## Architecture: Plots are FOUNDATION (fixed positions), QuantumForceGraph tethers to them

const GridConfig = preload("res://Core/GameState/GridConfig.gd")

var grid_config: GridConfig = null
var biomes: Dictionary = {}  # biome_name -> BiomeBase
var viewport_size: Vector2 = Vector2.ZERO
var graph_center: Vector2 = Vector2.ZERO
var graph_radius: float = 1.0


func _init(config: GridConfig, biomes_dict: Dictionary, viewport: Vector2, center: Vector2, radius: float) -> void:
	"""Initialize parametric positioner with grid and biome configuration

	Args:
		config: GridConfig with plot definitions and biome assignments
		biomes_dict: Dictionary of biome_name -> BiomeBase objects
		viewport: Current viewport size for calculations
		center: Center point for graph layout
		radius: Radius of graph for scaling
	"""
	grid_config = config
	biomes = biomes_dict
	viewport_size = viewport
	graph_center = center
	graph_radius = radius


func get_classical_plot_positions() -> Dictionary:
	"""Calculate and return parametric plot positions as classical_plot_positions

	Returns: Dictionary mapping Vector2i (grid position) → Vector2 (screen position)
	"""
	var classical_positions: Dictionary = {}

	if not grid_config:
		print("⚠️  ParametricPlotPositioner: GridConfig not set!")
		return classical_positions

	# Group plots by biome (same logic as QuantumForceGraph)
	var plots_by_biome: Dictionary = {}
	var total_plots = 0

	for plot_config in grid_config.get_all_active_plots():
		var biome_name = grid_config.get_biome_for_plot(plot_config.position)
		if biome_name == "":
			biome_name = "default"

		if not plots_by_biome.has(biome_name):
			plots_by_biome[biome_name] = []

		plots_by_biome[biome_name].append(plot_config.position)
		total_plots += 1

	print("📐 ParametricPlotPositioner: Grouping %d plots into %d biomes" % [total_plots, plots_by_biome.keys().size()])
	for biome_name in plots_by_biome.keys():
		print("     - %s: %d plots" % [biome_name, plots_by_biome[biome_name].size()])

	# Calculate viewport scaling for oval sizing
	var viewport_scale = graph_radius / 500.0  # Scale based on graph size

	# Calculate parametric positions for each biome's plots
	for biome_name in plots_by_biome:
		if not biomes.has(biome_name):
			print("⚠️  ParametricPlotPositioner: Biome '%s' not found!" % biome_name)
			continue

		var biome_obj = biomes[biome_name]
		var biome_config = biome_obj.get_visual_config()
		var biome_center = graph_center + biome_config.center_offset * graph_radius

		# Get parametric ring positions from biome
		var all_plots = plots_by_biome[biome_name]
		var plot_positions = biome_obj.get_plot_positions_in_oval(
			all_plots.size(),
			biome_center,
			viewport_scale
		)

		print("🔵 Biome '%s': %d plots → positions" % [biome_name, all_plots.size()])

		# Assign positions to plots (in grid order for consistency)
		var plot_idx = 0
		for grid_pos in all_plots:
			if plot_idx < plot_positions.size():
				var screen_pos = plot_positions[plot_idx]

				# Offset anchor position UPWARD (negative Y) so tiles float above like anchors
				var home_pos = screen_pos + Vector2(0, -60)
				classical_positions[grid_pos] = home_pos
				plot_idx += 1

	print("✅ ParametricPlotPositioner: Calculated positions for %d plots" % classical_positions.size())

	# DEBUG: Show first few positions
	if classical_positions.size() > 0:
		var first_three = classical_positions.keys().slice(0, 3)
		for grid_pos in first_three:
			var pos = classical_positions[grid_pos]
			print("   Grid %s → Screen (%.1f, %.1f)" % [grid_pos, pos.x, pos.y])
		if classical_positions.size() > 3:
			print("   ... and %d more" % (classical_positions.size() - 3))

	return classical_positions


func get_plot_position(grid_pos: Vector2i) -> Vector2:
	"""Get parametric position for a specific plot

	Returns: Screen position, or zero if plot not found
	"""
	var positions = get_classical_plot_positions()
	return positions.get(grid_pos, Vector2.ZERO)
