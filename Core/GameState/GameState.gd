class_name GameState
extends Resource

## Game State - Complete snapshot of game state for save/load
## Refactored for Farm/Biome/Qubit architecture
## All game state must be serializable (no Node references!)
##
## PERSISTED:
##  - Economy: All resource inventories, tribute counts
##  - Plots: Position, type, planted state, measurement state, entanglement
##  - Goals: Progress and completion
##  - Icons: Activation levels
##  - Time: Biome elapsed time + sun/moon phase
##  - Quantum state: Complete biome_state tree (sun qubit, icons, emoji qubits)
##
## NOT PERSISTED (regenerated each load):
##  - Conspiracy network (dynamic)
##  - UI/visual state

## Meta
@export var scenario_id: String = "default"
@export var save_timestamp: int = 0  # Unix timestamp
@export var game_time: float = 0.0  # Total playtime

## Grid Dimensions (for variable-sized farms)
@export var grid_width: int = 6
@export var grid_height: int = 1

## Quantum Energy Economy - All resources are emoji-quantum currencies
## Starting with minimal amounts forces strategic gameplay
@export var wheat_inventory: int = 2          # 🌾 Quantum energy (primary harvest)
@export var labor_inventory: int = 1          # 👥 Quantum energy (labor/people)
@export var flour_inventory: int = 0          # 🍞 Quantum energy (processed grain)
@export var flower_inventory: int = 0         # 🌻 Quantum energy (rare yields)
@export var mushroom_inventory: int = 1       # 🍄 Quantum energy (nocturnal)
@export var detritus_inventory: int = 1       # 🍂 Quantum energy (compost)
@export var imperium_resource: int = 0        # 👑 Quantum energy (imperial influence)
@export var credits: int = 1                  # 💰 Quantum energy (exchange medium)
@export var tributes_paid: int = 0
@export var tributes_failed: int = 0

## Plots - Array of serialized plot states (from FarmGrid)
@export var plots: Array[Dictionary] = []
# Each plot dictionary contains:
#   position: Vector2i - Grid coordinates (x, y)
#   type: int - PlotType enum (WHEAT=0, TOMATO=1, MUSHROOM=2, MILL=3, MARKET=4)
#   is_planted: bool - Currently has an active crop
#   has_been_measured: bool - Quantum state has been collapsed
#   theta_frozen: bool - Measurement locked the theta value (stops Hamiltonian drift)
#   entangled_with: Array[Vector2i] - Positions of entangled plots (bidirectional)
#
# NOTE: Quantum state details (theta, phi, radius, energy, berry_phase) are NOT persisted.
#       They regenerate when plots are planted from the biome environment.
#       This avoids serialization complexity while maintaining deterministic behavior.

## Goals
@export var current_goal_index: int = 0
@export var completed_goals: Array[String] = []

## Icons
@export var biotic_activation: float = 0.0
@export var chaos_activation: float = 0.0
@export var imperium_activation: float = 0.0

## Contracts
@export var active_contracts: Array[Dictionary] = []
# Each contract: {title, description, reward, requirements, faction}

## Time/Cycles - Celestial & Icon States (NEW QUANTUM ARCHITECTURE)
@export var time_elapsed: float = 0.0  # Biome absolute time (for sun cycle)
@export var sun_theta: float = 0.0  # Sun/moon qubit theta (0 to TAU)
@export var sun_phi: float = 0.0    # Sun/moon qubit phi (not really used for sun, but for completeness)
@export var wheat_icon_theta: float = PI/12  # Wheat icon theta (starts at 15° agrarian)
@export var mushroom_icon_theta: float = 11*PI/12  # Mushroom icon theta (starts at 165° lunar)

## Biome Quantum State Tree (mirrors Biome.gd architecture)
## Preserves complete quantum evolution state including all emoji qubits
@export var biome_state: Dictionary = {}
# Structure:
# {
#   "time_elapsed": float,
#   "sun_qubit": {theta, phi, radius, energy},
#   "wheat_icon": {theta, phi, radius, energy} - if has internal_qubit,
#   "mushroom_icon": {theta, phi, radius, energy} - if has internal_qubit,
#   "quantum_states": [
#     {position: Vector2i, theta, phi, radius, energy},
#     ...
#   ]
# }

## Vocabulary Evolution State (NEW - PERSISTED)
## Complete state snapshot from VocabularyEvolution.serialize()
@export var vocabulary_state: Dictionary = {}
# Structure:
# {
#   "discovered_vocabulary": [...],
#   "evolving_qubits": [...],
#   "parameters": {mutation_pressure, max_qubits, cannibalism_threshold, maturity_threshold},
#   "statistics": {total_spawned, total_cannibalized, time_elapsed}
# }


func _init():
	# Initialize with default values
	scenario_id = "default"
	save_timestamp = Time.get_unix_time_from_system()
	game_time = 0.0
	credits = 20
	wheat_inventory = 0
	flour_inventory = 0

	# Initialize empty plot grid (default 6x1, customizable per farm)
	plots.clear()
	for y in range(grid_height):
		for x in range(grid_width):
			plots.append({
				"position": Vector2i(x, y),
				"type": 0,  # PlotType.WHEAT
				"is_planted": false,
				"has_been_measured": false,
				"theta_frozen": false,
				"entangled_with": []
			})

	# Initialize typed arrays properly (Godot 4 requirement)
	completed_goals.clear()
	active_contracts.clear()


## Convenience method to create state for a specific grid size
static func create_for_grid(width: int, height: int):
	var resource = Resource.new()
	resource.set_script(load("res://Core/GameState/GameState.gd"))
	var state = resource as GameState
	state.grid_width = width
	state.grid_height = height

	# Reinitialize plots for the given grid size
	state.plots.clear()
	for y in range(height):
		for x in range(width):
			state.plots.append({
				"position": Vector2i(x, y),
				"type": 0,
				"is_planted": false,
				"has_been_measured": false,
				"theta_frozen": false,
				"entangled_with": []
			})

	return state


func get_save_display_name() -> String:
	"""Get human-readable save name"""
	var time = Time.get_datetime_dict_from_unix_time(save_timestamp)
	return "%02d/%02d/%04d %02d:%02d" % [
		time.month, time.day, time.year,
		time.hour, time.minute
	]
