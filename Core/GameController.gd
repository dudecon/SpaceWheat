class_name GameController
extends Node

## Central controller for all game actions
## Coordinates between farm grid, economy, goals, and UI

const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")

# References to game systems (set by FarmView)
# Note: Using untyped vars to avoid circular dependencies
var farm_grid
var economy
var goals
var conspiracy_network
var faction_manager
var visual_effects
var quantum_graph
var vocabulary_evolution

# UI callbacks (set by FarmView)
var on_ui_update: Callable
var on_goal_update: Callable
var on_icon_update: Callable
var on_contract_check: Callable
var get_tile_callback: Callable

# Signals for UI feedback
signal action_feedback(message: String, success: bool)
signal visual_effect_requested(effect_type: String, position: Vector2, data: Dictionary)

# Import economy helper for currency operations
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")


func _ready():
	print("🎮 GameController initialized")


## Public API - Game Actions

func measure_plot(pos: Vector2i) -> String:
	"""Measure plot (collapse quantum state)"""
	var result = farm_grid.measure_plot(pos)

	# Emit visual effect request
	if result != "" and get_tile_callback.is_valid():
		var tile = get_tile_callback.call(pos)
		if tile:
			var effect_pos = tile.global_position + tile.size / 2
			visual_effect_requested.emit("measure", effect_pos, {"color": Color(0.7, 0.3, 1.0)})

	if result != "":
		action_feedback.emit("⚛️ Measured: %s collapsed!" % result, true)
		print("👁️ Measured at %s -> %s" % [pos, result])
	else:
		action_feedback.emit("⚛️ Measurement failed", false)

	_trigger_updates()
	return result


func harvest_plot(pos: Vector2i) -> Dictionary:
	"""Harvest single plot - uses generic emoji-credits routing"""
	var harvest_data = farm_grid.harvest_wheat(pos)

	if harvest_data["success"]:
		# Get harvest outcome (emoji) and energy/yield
		var outcome_emoji = harvest_data.get("outcome", "")
		var quantum_energy = harvest_data.get("energy", 0.0)

		# Fallback: if energy not provided, derive from yield
		if quantum_energy == 0.0:
			var yield_amount = harvest_data.get("yield", 1)
			quantum_energy = float(yield_amount) / float(EconomyConstants.QUANTUM_TO_CREDITS)

		if not outcome_emoji.is_empty():
			# Generic routing: any emoji → its credits
			var credits_earned = economy.receive_harvest(outcome_emoji, quantum_energy, "harvest")
			var units = credits_earned / EconomyConstants.QUANTUM_TO_CREDITS

			# Goal tracking for wheat
			if outcome_emoji == "🌾":
				goals.record_harvest(units)

			action_feedback.emit("✂️ Harvested %d %s!" % [units, outcome_emoji], true)
			print("✂️ Harvested at %s: %d %s" % [pos, units, outcome_emoji])

		# Check contracts
		if on_contract_check.is_valid():
			on_contract_check.call()

		# Emit visual effect request
		if get_tile_callback.is_valid():
			var tile = get_tile_callback.call(pos)
			if tile:
				var effect_pos = tile.global_position + tile.size / 2
				visual_effect_requested.emit("harvest", effect_pos, {"color": Color(1.0, 0.9, 0.3)})

		_trigger_updates()
		if on_goal_update.is_valid():
			on_goal_update.call()
		if on_icon_update.is_valid():
			on_icon_update.call()

	return harvest_data


func harvest_all() -> Dictionary:
	"""Harvest all measured mature plots"""
	var total_harvested = 0
	var harvest_count = 0

	if farm_grid.terminal_pool:
		for terminal in farm_grid.terminal_pool.get_measured_terminals():
			if terminal.grid_position == Vector2i(-1, -1):
				continue
			var pos = terminal.grid_position
			var harvest_data = farm_grid.harvest_wheat(pos)
			if harvest_data.get("success", false):
				harvest_count += 1
				total_harvested += harvest_data.get("yield", 0)

				# Record each harvest
				economy.record_harvest(harvest_data.get("yield", 0))
				goals.record_harvest(harvest_data.get("yield", 0))

				# Emit visual effect request
				if get_tile_callback.is_valid():
					var tile = get_tile_callback.call(pos)
					if tile:
						var effect_pos = tile.global_position + tile.size / 2
						visual_effect_requested.emit("harvest", effect_pos, {"color": Color(1.0, 0.9, 0.3)})

	if harvest_count > 0:
		# Check contracts
		if on_contract_check.is_valid():
			on_contract_check.call()

		action_feedback.emit("✂️ Harvested %d plots → %d wheat!" % [harvest_count, total_harvested], true)
		print("✂️ Field harvest: %d plots → %d total wheat" % [harvest_count, total_harvested])

		_trigger_updates()
		if on_goal_update.is_valid():
			on_goal_update.call()
		if on_icon_update.is_valid():
			on_icon_update.call()
	else:
		action_feedback.emit("⚠️ No measured plots to harvest!", false)

	return {"harvest_count": harvest_count, "total_harvested": total_harvested}


func entangle_plots(pos1: Vector2i, pos2: Vector2i, bell_state: String = "phi_plus") -> bool:
	"""Create entanglement between two plots with specified Bell state

	Args:
		pos1: Grid position of first plot
		pos2: Grid position of second plot
		bell_state: "phi_plus" (same correlation), "psi_plus" (opposite), etc.
	"""
	var result = farm_grid.create_entanglement(pos1, pos2, bell_state)

	if result:
		var state_name = "same correlation" if bell_state == "phi_plus" else "opposite correlation"
		if quantum_graph:
			quantum_graph.print_snapshot("Entangled %s ↔ %s (%s)" % [pos1, pos2, state_name])
		action_feedback.emit("🔗 Entangled %s ↔ %s (%s)" % [pos1, pos2, state_name], true)
		_trigger_updates()
	else:
		action_feedback.emit("⚠️ Cannot entangle - both plots must be planted!", false)

	return result


## Helper Functions

func _trigger_updates():
	"""Trigger all UI update callbacks"""
	if on_ui_update.is_valid():
		on_ui_update.call()


func check_plot_harvestable(grid_size: int) -> bool:
	"""Check if any plot is ready to harvest (must be planted and measured)"""
	for y in range(grid_size):
		for x in range(grid_size):
			var pos = Vector2i(x, y)
			var plot = farm_grid.get_plot(pos)
			if plot and plot.is_planted and plot.has_been_measured:
				return true
	return false
