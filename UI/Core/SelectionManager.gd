class_name SelectionManager
extends RefCounted

## SelectionManager - Unified selection state management
##
## Manages cursor position and multi-select checkbox state.
## Provides a clean API for QuantumInstrumentInput to query selected plots.

# Current cursor position (single-select fallback)
var current_selection: Vector2i = Vector2i.ZERO

# Reference to PlotGridDisplay for multi-select
var plot_grid_display: Node = null

# Grid configuration for bounds checking
var grid_config = null

# Grid dimensions (fallback if grid_config is null)
var grid_width: int = 0
var grid_height: int = 0

# Signals
signal selection_changed(new_pos: Vector2i)


## ============================================================================
## INITIALIZATION
## ============================================================================

func inject_plot_grid_display(display: Node) -> void:
	"""Inject PlotGridDisplay reference for multi-select support."""
	plot_grid_display = display


func inject_grid_config(config) -> void:
	"""Inject GridConfig for bounds checking."""
	grid_config = config
	if config:
		grid_width = config.grid_width
		grid_height = config.grid_height


## ============================================================================
## SELECTION QUERIES
## ============================================================================

func get_selected_plots() -> Array[Vector2i]:
	"""Get checkbox-selected plots, fallback to cursor position.

	Returns:
		Array[Vector2i]: Selected plot positions
	"""
	var selected: Array[Vector2i] = []

	if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
		selected = plot_grid_display.get_selected_plots()

	# Fallback to cursor if no multi-select
	if selected.is_empty() and is_valid_position(current_selection):
		selected = [current_selection]

	return selected


func get_cursor_position() -> Vector2i:
	"""Get current cursor position."""
	return current_selection


func has_multi_selection() -> bool:
	"""Check if multiple plots are selected via checkboxes."""
	if not plot_grid_display or not plot_grid_display.has_method("get_selected_plots"):
		return false
	var selected = plot_grid_display.get_selected_plots()
	return selected.size() > 1


func get_selection_count() -> int:
	"""Get number of selected plots."""
	return get_selected_plots().size()


## ============================================================================
## SELECTION MODIFICATION
## ============================================================================

func toggle_plot_selection(pos: Vector2i) -> void:
	"""Toggle a plot's checkbox selection state."""
	if not plot_grid_display:
		push_error("SelectionManager: PlotGridDisplay not wired!")
		return

	if not is_valid_position(pos):
		return

	plot_grid_display.toggle_plot_selection(pos)


func clear_all_selection() -> void:
	"""Clear all checkbox selections."""
	if not plot_grid_display:
		push_error("SelectionManager: PlotGridDisplay not wired!")
		return

	plot_grid_display.clear_all_selection()


func select_all_plots() -> void:
	"""Select all plots in the active biome."""
	if not plot_grid_display:
		push_error("SelectionManager: PlotGridDisplay not wired!")
		return

	plot_grid_display.select_all_plots()


func move_selection(direction: Vector2i) -> bool:
	"""Move cursor in given direction.

	Args:
		direction: Movement vector (e.g., Vector2i.UP, Vector2i.LEFT)

	Returns:
		bool: True if move was successful
	"""
	var new_pos = current_selection + direction
	if is_valid_position(new_pos):
		current_selection = new_pos
		selection_changed.emit(current_selection)
		return true
	return false


func set_selection(pos: Vector2i) -> bool:
	"""Set cursor to specific position.

	Args:
		pos: Target position

	Returns:
		bool: True if position was valid and set
	"""
	if is_valid_position(pos):
		current_selection = pos
		selection_changed.emit(current_selection)
		return true
	return false


func reset_to_origin() -> void:
	"""Reset cursor to origin (0,0)."""
	current_selection = Vector2i.ZERO
	selection_changed.emit(current_selection)


func reset_to_biome_start(farm, biome_index: int = 0) -> void:
	"""Reset cursor to first plot of specified biome.

	Args:
		farm: Farm instance
		biome_index: Plot index within biome (default 0)
	"""
	if farm and farm.has_method("get_plot_position_for_active_biome"):
		current_selection = farm.get_plot_position_for_active_biome(biome_index)
		selection_changed.emit(current_selection)


## ============================================================================
## VALIDATION
## ============================================================================

func is_valid_position(pos: Vector2i) -> bool:
	"""Check if position is within grid bounds."""
	if grid_config:
		return grid_config.is_position_valid(pos)
	# Fallback for backward compatibility
	return pos.x >= 0 and pos.x < grid_width and \
		   pos.y >= 0 and pos.y < grid_height


## ============================================================================
## BIOME INTEGRATION
## ============================================================================

func on_biome_changed(farm) -> void:
	"""Handle biome change - reset cursor and clear selections."""
	reset_to_biome_start(farm, 0)
	clear_all_selection()
