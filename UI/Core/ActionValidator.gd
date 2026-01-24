class_name ActionValidator
extends RefCounted

## ActionValidator - Pure validation functions for action availability
##
## Extracts all _can_execute_* logic from FarmInputHandler.
## All methods are static with no side effects.
##
## Used by:
## - ActionPreviewRow for button highlighting
## - FarmInputHandler for pre-execution validation

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const Farm = preload("res://Core/Farm.gd")


## ============================================================================
## MAIN ENTRY POINT
## ============================================================================

static func can_execute_action(
	action_key: String,
	current_tool: int,
	current_submenu: String,
	cached_submenu: Dictionary,
	farm,
	selected_plots: Array[Vector2i],
	current_selection: Vector2i
) -> bool:
	"""Check if action for given key can succeed with current selection.

	Uses any-valid strategy: returns true if at least 1 plot can succeed.

	Args:
		action_key: "Q", "E", or "R"
		current_tool: Active tool number (1-4)
		current_submenu: Active submenu name (empty = no submenu)
		cached_submenu: Cached submenu data for dynamic menus
		farm: Farm instance
		selected_plots: Currently selected plot positions
		current_selection: Cursor position

	Returns:
		bool: true if action would succeed on at least one selected plot
	"""
	if current_submenu != "":
		return _can_execute_submenu_action(
			action_key, current_submenu, cached_submenu, farm, selected_plots
		)
	else:
		return _can_execute_tool_action(
			action_key, current_tool, farm, selected_plots, current_selection
		)


## ============================================================================
## TOOL ACTION VALIDATION
## ============================================================================

static func _can_execute_tool_action(
	action_key: String,
	current_tool: int,
	farm,
	selected_plots: Array[Vector2i],
	current_selection: Vector2i
) -> bool:
	"""Check if tool action can succeed (not in submenu)."""
	if selected_plots.is_empty():
		return false

	# Use ToolConfig API to properly resolve action name
	var action = ToolConfig.get_action_name(current_tool, action_key)

	# Route to specific validation based on action type
	match action:
		# ═══════════════════════════════════════════════════════════════
		# v2 PROBE Tool (Tool 1) - Core gameplay loop
		# ═══════════════════════════════════════════════════════════════
		"explore":
			return _can_execute_explore(farm, current_selection)
		"measure":
			return _can_execute_measure(farm, selected_plots)
		"pop":
			return _can_execute_pop(farm, selected_plots)

		# ═══════════════════════════════════════════════════════════════
		# v2 GATES Tool (Tool 2) - 1-qubit gates
		# ═══════════════════════════════════════════════════════════════
		"apply_pauli_x", "apply_hadamard", "apply_pauli_z", "apply_ry", \
		"apply_pauli_y", "apply_s_gate", "apply_t_gate", "apply_sdg_gate", \
		"apply_rx_gate", "apply_ry_gate", "apply_rz_gate":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# v2 ENTANGLE Tool (Tool 3) - 2-qubit gates
		# ═══════════════════════════════════════════════════════════════
		"apply_cnot", "apply_swap", "apply_cz":
			return selected_plots.size() >= 2  # Need 2 plots for 2-qubit gates
		"create_bell_pair":
			return selected_plots.size() >= 2  # Need 2 plots for Bell pair
		"disentangle", "inspect_entanglement":
			return true  # Available if any plots selected

		# Entanglement cluster operations
		"cluster", "measure_trigger", "remove_gates":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# v2 INDUSTRY Tool (Tool 4)
		# ═══════════════════════════════════════════════════════════════
		"place_mill", "place_market":
			return true  # Available if plots selected
		"place_kitchen":
			return selected_plots.size() == 3  # Kitchen needs exactly 3 plots
		"harvest_flour", "market_sell":
			return true  # Available if plots selected
		"bake_bread":
			return selected_plots.size() == 3  # Baking needs exactly 3 plots

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 1 (BIOME)
		# ═══════════════════════════════════════════════════════════════
		"submenu_biome_assign":
			return true  # Opens submenu
		"clear_biome_assignment", "inspect_plot":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 2 (ICON)
		# ═══════════════════════════════════════════════════════════════
		"submenu_icon_assign":
			return true  # Opens submenu
		"icon_swap", "icon_clear":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 3 (LINDBLAD)
		# ═══════════════════════════════════════════════════════════════
		"lindblad_drive", "lindblad_decay":
			return true  # Available if plots selected
		"lindblad_transfer":
			return selected_plots.size() == 2  # Transfer needs exactly 2 plots

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 4 (QUANTUM) System/Phase/Rotation modes
		# ═══════════════════════════════════════════════════════════════
		"system_reset", "system_snapshot", "system_debug":
			return true  # Available if plots selected

		_:
			# Catch-all for any submenu-opening actions
			if action.begins_with("submenu_"):
				return true
			return false


## ============================================================================
## PROBE ACTION VALIDATION
## ============================================================================

static func _can_execute_explore(farm, current_selection: Vector2i) -> bool:
	"""Check if EXPLORE action is available (v2 PROBE Tool 1).

	EXPLORE binds an unbound terminal to a register in the current biome.
	Available when: unbound terminals exist AND biome has unbound registers.
	"""
	if not farm or not farm.plot_pool:
		return false

	# Need unbound terminals
	if farm.plot_pool.get_unbound_count() == 0:
		return false

	# Get biome from current selection
	if not farm.grid:
		return false

	var biome = farm.grid.get_biome_for_plot(current_selection)
	if not biome:
		return false

	# Must have unbound registers
	var probabilities = biome.get_register_probabilities()
	return not probabilities.is_empty()


static func _can_execute_measure(farm, selected_plots: Array[Vector2i]) -> bool:
	"""Check if MEASURE action is available (v2 PROBE Tool 1).

	MEASURE collapses an active terminal (bound but not measured).
	Available when: active terminal exists at any selected position.
	"""
	if not farm or not farm.plot_pool:
		return false

	if selected_plots.is_empty():
		return false

	# Check any selected plot has an active terminal
	for pos in selected_plots:
		var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
		if terminal and terminal.can_measure():
			return true

	return false


static func _can_execute_pop(farm, selected_plots: Array[Vector2i]) -> bool:
	"""Check if POP action is available (v2 PROBE Tool 1).

	POP harvests a measured terminal and unbinds it.
	Available when: measured terminal exists at any selected position.
	"""
	if not farm or not farm.plot_pool:
		return false

	if selected_plots.is_empty():
		return false

	# Check any selected plot has a measured terminal
	for pos in selected_plots:
		var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
		if terminal and terminal.can_pop():
			return true

	return false


## ============================================================================
## SUBMENU ACTION VALIDATION
## ============================================================================

static func _can_execute_submenu_action(
	action_key: String,
	current_submenu: String,
	cached_submenu: Dictionary,
	farm,
	selected_plots: Array[Vector2i]
) -> bool:
	"""Check if submenu action can succeed."""
	if selected_plots.is_empty():
		return false

	var submenu = cached_submenu if not cached_submenu.is_empty() else ToolConfig.get_submenu(current_submenu)

	# Check if entire submenu disabled
	if submenu.get("_disabled", false):
		return false

	var action_info = submenu.get(action_key, {})
	var action = action_info.get("action", "")

	# Empty action = locked slot
	if action == "":
		return false

	# Route to specific validation
	match action:
		"plant_wheat":
			return _can_plant_type(farm, "wheat", selected_plots)
		"plant_mushroom":
			return _can_plant_type(farm, "mushroom", selected_plots)
		"plant_tomato":
			return _can_plant_type(farm, "tomato", selected_plots)
		"plant_fire":
			return _can_plant_type(farm, "fire", selected_plots)
		"plant_water":
			return _can_plant_type(farm, "water", selected_plots)
		"plant_flour":
			return _can_plant_type(farm, "flour", selected_plots)
		"plant_ice":
			return _can_plant_type(farm, "ice", selected_plots)
		"plant_desert":
			return _can_plant_type(farm, "desert", selected_plots)
		"plant_vegetation":
			return _can_plant_type(farm, "vegetation", selected_plots)
		"plant_rabbit":
			return _can_plant_type(farm, "rabbit", selected_plots)
		"plant_wolf":
			return _can_plant_type(farm, "wolf", selected_plots)
		"plant_bread":
			return _can_plant_type(farm, "bread", selected_plots)
		_:
			# Mill power/conversion and biome assignment always available
			if action.begins_with("mill_") or action.begins_with("assign_to_"):
				return true
			# Icon actions
			if action.begins_with("icon_"):
				return true
			return false


## ============================================================================
## PLANT TYPE VALIDATION
## ============================================================================

static func _can_plant_type(farm, plant_type: String, plots: Array[Vector2i]) -> bool:
	"""Check if we can plant this specific type on any selected plot.

	PARAMETRIC: Queries biome capabilities instead of BUILD_CONFIGS.
	"""
	if not farm or plots.is_empty():
		return false

	# Determine cost based on type
	var cost = {}
	var biome_required = ""

	# Check infrastructure buildings
	if Farm.INFRASTRUCTURE_COSTS.has(plant_type):
		cost = Farm.INFRASTRUCTURE_COSTS[plant_type]

	# Check gather actions
	elif Farm.GATHER_ACTIONS.has(plant_type):
		var gather_config = Farm.GATHER_ACTIONS[plant_type]
		cost = gather_config.get("cost", {})
		biome_required = gather_config.get("biome_required", "")

	# Otherwise, query biome capabilities for plant cost
	else:
		if not farm.grid:
			return false

		var first_pos = plots[0]
		var plot_biome = farm.grid.get_biome_for_plot(first_pos)
		if not plot_biome:
			return false

		# Find capability for this plant type
		var capability = null
		for cap in plot_biome.get_plantable_capabilities():
			if cap.plant_type == plant_type:
				capability = cap
				break

		if not capability:
			return false

		cost = capability.cost
		biome_required = plot_biome.name if capability.requires_biome else ""

	# Check if we can afford it
	if farm.economy and not farm.economy.can_afford_cost(cost):
		return false

	# Check at least ONE plot is valid (any-valid strategy)
	for pos in plots:
		if not farm.grid:
			continue

		var plot = farm.grid.get_plot(pos)
		if not plot:
			continue

		# Must be empty
		if plot.is_planted:
			continue

		# Check biome requirement if specified
		if biome_required != "":
			var plot_biome_name = farm.grid.plot_biome_assignments.get(pos, "")
			if plot_biome_name != biome_required:
				continue

		# Found at least one valid plot!
		return true

	return false


## ============================================================================
## UTILITY VALIDATION HELPERS
## ============================================================================

static func has_active_terminal_at(farm, pos: Vector2i) -> bool:
	"""Check if there's an active (bound but not measured) terminal at position."""
	if not farm or not farm.plot_pool:
		return false
	var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
	return terminal != null and terminal.can_measure()


static func has_measured_terminal_at(farm, pos: Vector2i) -> bool:
	"""Check if there's a measured terminal at position."""
	if not farm or not farm.plot_pool:
		return false
	var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
	return terminal != null and terminal.can_pop()


static func has_planted_plot_at(farm, pos: Vector2i) -> bool:
	"""Check if there's a planted plot at position."""
	if not farm or not farm.grid:
		return false
	var plot = farm.grid.get_plot(pos)
	return plot != null and plot.is_planted


static func has_empty_plot_at(farm, pos: Vector2i) -> bool:
	"""Check if there's an empty (unplanted) plot at position."""
	if not farm or not farm.grid:
		return false
	var plot = farm.grid.get_plot(pos)
	return plot != null and not plot.is_planted
