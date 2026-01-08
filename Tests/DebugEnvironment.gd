class_name DebugEnvironment
extends Node

## Debug Environment - Utilities for setting up test/debug game states
## Designed for dev team to quickly create reproducible test scenarios
##
## Usage:
##   var env = DebugEnvironment.minimal_farm()
##   var farm = Farm.new()
##   farm.apply_game_state(env)
##
##   var env = DebugEnvironment.wealthy_farm()
##   var env = DebugEnvironment.fully_entangled_farm()
##   var env = DebugEnvironment.custom_state(credits=1000, wheat=100)

const GameState = preload("res://Core/GameState/GameState.gd")

## Minimal farm - fresh start, no resources
static func minimal_farm() -> GameState:
	var state = GameState.new()
	state.scenario_id = "debug_minimal"
	state.credits = 20
	state.wheat_inventory = 0
	state.flour_inventory = 0
	state.flower_inventory = 0
	state.labor_inventory = 0
	return state


## Wealthy farm - plenty of resources for testing
static func wealthy_farm() -> GameState:
	var state = GameState.new()
	state.scenario_id = "debug_wealthy"
	state.credits = 5000
	state.wheat_inventory = 500
	state.flour_inventory = 200
	state.flower_inventory = 150
	state.labor_inventory = 100
	return state


## Planted farm - 6x1 grid all planted
static func fully_planted_farm() -> GameState:
	var state = wealthy_farm()
	state.scenario_id = "debug_fully_planted"

	for i in range(6):
		state.plots[i]["is_planted"] = true
		state.plots[i]["type"] = 0  # WHEAT

	return state


## Measured farm - quantum mechanics tested
static func fully_measured_farm() -> GameState:
	var state = fully_planted_farm()
	state.scenario_id = "debug_fully_measured"

	for i in range(6):
		state.plots[i]["has_been_measured"] = true
		state.plots[i]["theta_frozen"] = false

	return state


## Entangled farm - test quantum entanglement visuals
static func fully_entangled_farm() -> GameState:
	var state = wealthy_farm()
	state.scenario_id = "debug_fully_entangled"

	# Create chain of entanglements: (0) <-> (1) <-> (2) <-> (3) <-> (4) <-> (5)
	for i in range(5):
		var pos1 = state.plots[i]["position"]
		var pos2 = state.plots[i+1]["position"]

		state.plots[i]["entangled_with"] = [pos2]
		state.plots[i+1]["entangled_with"] = [pos1]
		state.plots[i]["is_planted"] = true
		state.plots[i+1]["is_planted"] = true

	return state


## Mixed quantum state - various quantum conditions
static func mixed_quantum_farm() -> GameState:
	var state = wealthy_farm()
	state.scenario_id = "debug_mixed_quantum"

	# Create different quantum states in different regions of 6x1 grid
	# Left: measured and frozen (plots 0-1)
	for i in range(2):
		state.plots[i]["is_planted"] = true
		state.plots[i]["has_been_measured"] = true
		state.plots[i]["theta_frozen"] = true

	# Middle: entangled but unmeasured (plots 2-3)
	for i in range(2, 4):
		if i < 3:
			state.plots[i]["entangled_with"] = [state.plots[i+1]["position"]]
		state.plots[i]["is_planted"] = true
		state.plots[i]["has_been_measured"] = false

	# Right: empty/unmeasured (plots 4-5)
	for i in range(4, 6):
		state.plots[i]["is_planted"] = false
		state.plots[i]["has_been_measured"] = false

	return state


## Icon powers active - test visualization of icon activation
static func icons_active_farm() -> GameState:
	var state = wealthy_farm()
	state.scenario_id = "debug_icons_active"

	state.biotic_activation = 0.75
	state.chaos_activation = 0.5
	state.imperium_activation = 0.25

	return state


## Mid-game farm - some progress made
static func mid_game_farm() -> GameState:
	var state = GameState.new()
	state.scenario_id = "debug_mid_game"

	# Resources
	state.credits = 200
	state.wheat_inventory = 75
	state.flour_inventory = 30
	state.flower_inventory = 20
	state.labor_inventory = 15

	# Some plots planted and measured
	for i in range(6):
		state.plots[i]["is_planted"] = true
		if i < 4:
			state.plots[i]["has_been_measured"] = true
			state.plots[i]["theta_frozen"] = false

	# Tributes
	state.tributes_paid = 2
	state.tributes_failed = 1

	# One completed goal
	state.current_goal_index = 2
	state.completed_goals.clear()
	state.completed_goals.append("harvest_wheat_1")

	return state


## Save to slot - persist a state to disk
static func save_to_slot(state: GameState, slot: int) -> bool:
	var path = "user://saves/save_slot_" + str(slot) + ".tres"
	var result = ResourceSaver.save(state, path)
	if result == OK:
		print("💾 Debug state saved to slot " + str(slot + 1) + ": " + state.scenario_id)
		return true
	else:
		push_error("Failed to save debug state")
		return false


## Load from slot
static func load_from_slot(slot: int) -> GameState:
	var path = "user://saves/save_slot_" + str(slot) + ".tres"
	if not FileAccess.file_exists(path):
		push_error("No save file in slot " + str(slot + 1))
		return null
	return ResourceLoader.load(path)


## Create custom state with shorthand parameters
## Usage: DebugEnvironment.custom_state(credits=1000, wheat=500, planted=10)
static func custom_state(
	credits: int = 20,
	wheat: int = 0,
	flour: int = 0,
	flowers: int = 0,
	labor: int = 0,
	planted: int = 0,
	measured: int = 0,
	entangled_pairs: int = 0,
	icon_activation: Dictionary = {}
) -> GameState:
	var state = GameState.new()
	state.scenario_id = "debug_custom"

	# Economy
	state.credits = credits
	state.wheat_inventory = wheat
	state.flour_inventory = flour
	state.flower_inventory = flowers
	state.labor_inventory = labor

	# Plant specified number of plots (max 6 for 6x1 grid)
	for i in range(mini(planted, 6)):
		state.plots[i]["is_planted"] = true

	# Measure specified number (max 6)
	for i in range(mini(measured, 6)):
		state.plots[i]["has_been_measured"] = true

	# Create entangled pairs (max 3 pairs for 6 plots)
	for pair_idx in range(mini(entangled_pairs, 3)):
		var idx1 = pair_idx * 2
		var idx2 = pair_idx * 2 + 1
		if idx2 < 6:
			var pos1 = state.plots[idx1]["position"]
			var pos2 = state.plots[idx2]["position"]
			state.plots[idx1]["entangled_with"] = [pos2]
			state.plots[idx2]["entangled_with"] = [pos1]

	# Icon activation
	if icon_activation.has("biotic"):
		state.biotic_activation = float(icon_activation["biotic"])
	if icon_activation.has("chaos"):
		state.chaos_activation = float(icon_activation["chaos"])
	if icon_activation.has("imperium"):
		state.imperium_activation = float(icon_activation["imperium"])

	return state


## Print state summary - useful for debugging
static func print_state(state: GameState) -> void:
	print("\n" + "=".repeat(60))
	print("📊 DEBUG STATE: " + state.scenario_id)
	print("=".repeat(60))
	print("Credits: " + str(state.credits))
	print("Wheat: " + str(state.wheat_inventory) + " | Flour: " + str(state.flour_inventory) + " | Flowers: " + str(state.flower_inventory))
	print("Labor: " + str(state.labor_inventory))

	var planted_count = 0
	var measured_count = 0
	var entangled_count = 0

	for plot in state.plots:
		if plot["is_planted"]:
			planted_count += 1
		if plot["has_been_measured"]:
			measured_count += 1
		if plot["entangled_with"].size() > 0:
			entangled_count += 1

	print("Planted: " + str(planted_count) + "/6 | Measured: " + str(measured_count) + "/6 | Entangled: " + str(entangled_count) + "/6")
	print("Tributes: " + str(state.tributes_paid) + " paid, " + str(state.tributes_failed) + " failed")
	print("Icon activation: Biotic=" + str("%.2f" % state.biotic_activation) + " Chaos=" + str("%.2f" % state.chaos_activation) + " Imperium=" + str("%.2f" % state.imperium_activation))
	print("=".repeat(60) + "\n")


## Export state as JSON for debugging (prints to console)
static func export_as_json(state: GameState) -> Dictionary:
	return {
		"scenario": state.scenario_id,
		"timestamp": state.save_timestamp,
		"game_time": state.game_time,
		"economy": {
			"credits": state.credits,
			"wheat": state.wheat_inventory,
			"flour": state.flour_inventory,
			"flowers": state.flower_inventory,
			"labor": state.labor_inventory,
			"tributes_paid": state.tributes_paid,
			"tributes_failed": state.tributes_failed
		},
		"plots": state.plots,
		"goals": {
			"current_index": state.current_goal_index,
			"completed": state.completed_goals
		},
		"icons": {
			"biotic": state.biotic_activation,
			"chaos": state.chaos_activation,
			"imperium": state.imperium_activation
		}
	}
