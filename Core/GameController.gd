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

# Build configuration - use Farm.BUILD_CONFIGS as source of truth for costs
# This table only adds UI-specific metadata (colors, messages)
const BUILD_UI_CONFIGS = {
	"mill": {
		"farm_method": "place_mill",
		"visual_color": Color(0.8, 0.6, 0.4),
		"success_message": "🏭 Mill placed!",
		"failure_message": "Plot must be empty!",
		"updates_quantum_graph": false
	},
	"market": {
		"farm_method": "place_market",
		"visual_color": Color(1.0, 0.85, 0.2),
		"success_message": "💰 Market placed!",
		"failure_message": "Plot must be empty!",
		"updates_quantum_graph": false
	},
	"kitchen": {
		"farm_method": "place_kitchen",
		"visual_color": Color(0.9, 0.5, 0.3),
		"success_message": "🍳 Kitchen placed!",
		"failure_message": "Plot must be empty!",
		"updates_quantum_graph": false
	},
	# NOTE: energy_tap removed (2026-01) - energy tap system deprecated
}

# Import cost configs from Farm (canonical source)
const Farm = preload("res://Core/Farm.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")


func _ready():
	print("🎮 GameController initialized")


## Public API - Game Actions

func build(pos: Vector2i, build_type: String) -> bool:
	"""Unified build method - handles all types

	Args:
		pos: Grid position to build at
		build_type: Type identifier ("mill", "market", "kitchen", etc.)

	Returns:
		bool: True if successful, False if failed
	"""
	# 1. Validate build type exists in both configs
	if not Farm.BUILD_CONFIGS.has(build_type):
		push_error("Unknown build type: %s" % build_type)
		return false

	if not BUILD_UI_CONFIGS.has(build_type):
		push_error("Missing UI config for: %s" % build_type)
		return false

	var cost_config = Farm.BUILD_CONFIGS[build_type]
	var ui_config = BUILD_UI_CONFIGS[build_type]

	# 2. PRE-VALIDATION: Check if building is possible BEFORE spending money
	var plot = farm_grid.get_plot(pos)
	if plot == null or plot.is_planted:
		action_feedback.emit(ui_config["failure_message"], false)
		return false

	# 3. ECONOMY CHECK: Use unified emoji-credits API
	var costs = cost_config["cost"]  # e.g. {"🌾": 10} or {"👥": 10}

	if not economy.can_afford_cost(costs):
		var missing = _format_missing_resources(costs)
		action_feedback.emit("Not enough resources! Need: %s" % missing, false)
		return false

	# Spend emoji-credits
	economy.spend_cost(costs, build_type)

	# 4. FARM OPERATION: Call appropriate farm_grid method
	var success = false
	var farm_method = ui_config["farm_method"]
	match farm_method:
		"place_mill":
			success = farm_grid.place_mill(pos)
		"place_market":
			success = farm_grid.place_market(pos)
		"place_kitchen":
			success = farm_grid.place_kitchen(pos) if farm_grid.has_method("place_kitchen") else false
		# NOTE: place_energy_tap case removed (2026-01) - energy tap system deprecated

	# 5. Handle failure - refund emoji-credits
	if not success:
		for emoji in costs.keys():
			economy.add_resource(emoji, costs[emoji], "refund")
		action_feedback.emit(ui_config["failure_message"], false)
		return false

	# 6. POST-PROCESSING: Visual effects and feedback
	if get_tile_callback.is_valid():
		var tile = get_tile_callback.call(pos)
		if tile:
			var effect_pos = tile.global_position + tile.size / 2
			visual_effect_requested.emit("plant", effect_pos, {"color": ui_config["visual_color"]})

	# 7. Quantum graph update (only for wheat)
	if ui_config["updates_quantum_graph"] and quantum_graph:
		quantum_graph.print_snapshot("%s at %s" % [build_type.capitalize(), pos])

	# 8. Trigger UI updates
	_trigger_updates()

	# 9. Success feedback
	action_feedback.emit(ui_config["success_message"], true)

	return true


func _format_missing_resources(costs: Dictionary) -> String:
	"""Format missing resources for error message"""
	var missing = []
	for emoji in costs.keys():
		var need = costs[emoji]
		var have = economy.get_resource(emoji)
		if have < need:
			var shortfall = (need - have) / EconomyConstants.QUANTUM_TO_CREDITS
			missing.append("%d %s" % [shortfall, emoji])
	return ", ".join(missing)


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

	if farm_grid.plot_pool:
		for terminal in farm_grid.plot_pool.get_measured_terminals():
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
