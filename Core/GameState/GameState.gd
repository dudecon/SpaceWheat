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
@export var quantum_time_scale: float = 0.125  # Simulation speed multiplier (0.001-16.0)
@export var save_version: int = 1  # Phase 4: Save format version (increment when format changes)

## Grid Dimensions (for variable-sized farms)
@export var grid_width: int = 6
@export var grid_height: int = 1

## Quantum Energy Economy - All resources are emoji-quantum currencies
## Starting with minimal amounts forces strategic gameplay
##
## LEGACY fields (kept for backward compatibility with old saves):
@export var wheat_inventory: int = 2          # 🌾 Quantum energy (primary harvest)
@export var labor_inventory: int = 1          # 👥 Quantum energy (labor/people)
@export var flour_inventory: int = 0          # 💨 Quantum energy (processed grain)
@export var flower_inventory: int = 0         # 🌻 Quantum energy (rare yields)
@export var mushroom_inventory: int = 1       # 🍄 Quantum energy (nocturnal)
@export var detritus_inventory: int = 1       # 🍂 Quantum energy (compost)
@export var imperium_resource: int = 0        # 👑 Quantum energy (imperial influence)
@export var credits: int = 1                  # 💰 Quantum energy (exchange medium)
@export var tributes_paid: int = 0
@export var tributes_failed: int = 0

## NEW: Complete emoji credits dictionary (saves ALL resources)
## Format: {"emoji": credits_amount, ...}
## This replaces the individual inventory fields above for full persistence
@export var all_emoji_credits: Dictionary = {}

## Known Pairs - persisted copy of player vocabulary (canonical in Farm)
## Each pair is {north: String, south: String}
## These are the actual plantable qubit axes the player has learned
## Starter pair: 🌾/👥 (wheat/people - the farming foundation)
@export var known_pairs: Array = [
	{"north": "🌾", "south": "👥"}
]

## DERIVED: known_emojis is computed from known_pairs (for backward compatibility)
## Use get_known_emojis() to access the derived list
## This field is still exported for save file compatibility with old saves
@export var known_emojis: Array = []

## Player Vocabulary Quantum Computer data (for biome affinity calculations)
## Serialized data from PlayerVocabulary autoload
@export var player_vocab_data: Dictionary = {}

## Unlocked Biomes - Start with StarterForest and Village, unlock more through exploration
@export var unlocked_biomes: Array[String] = ["StarterForest", "Village"]

## Pool of unexplored biomes (assigned to UIOP slots dynamically)
## These are available but not yet assigned to keyboard slots
@export var unexplored_biome_pool: Array[String] = ["BioticFlux", "StellarForges", "FungalNetworks", "VolcanicWorlds"]


## Get known emojis (derived from known_pairs)
## This is the canonical way to get the player's vocabulary
func get_known_emojis() -> Array:
	var emojis = []
	for pair in known_pairs:
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north and north not in emojis:
			emojis.append(north)
		if south and south not in emojis:
			emojis.append(south)
	return emojis


## Get the pair containing a given emoji (returns null if not found)
func get_pair_for_emoji(emoji: String) -> Variant:
	for pair in known_pairs:
		if pair.get("north", "") == emoji or pair.get("south", "") == emoji:
			return pair
	return null

## Quest Board - Multi-Page Memory System
@export var quest_pages: Dictionary = {}
# Structure: {
#   0: [slot0_dict, slot1_dict, slot2_dict, slot3_dict],
#   1: [slot0_dict, slot1_dict, slot2_dict, slot3_dict],
#   ...
# }
# Each slot_dict: {quest_id, offered_quest, faction, is_locked, state}

@export var quest_board_current_page: int = 0

## DEPRECATED: Old single-page storage (kept for migration)
@export var quest_slots: Array = [null, null, null, null]
# Each slot dictionary contains:
#   quest_id: int - ID of active quest (if active)
#   offered_quest: Dictionary - Quest data (if offered but not accepted)
#   is_locked: bool - Locked slot won't auto-refresh
#   state: int - SlotState enum (EMPTY=0, OFFERED=1, ACTIVE=2, READY=3, LOCKED=4)

## Plots - Array of serialized plot states (from FarmGrid)
@export var plots: Array[Dictionary] = []
# Each plot dictionary contains:
#   position: Vector2i - Grid coordinates (x, y)
#   type: int - PlotType enum (WHEAT=0, TOMATO=1, MUSHROOM=2, MILL=3, MARKET=4)
#   is_planted: bool - Currently has an active crop
#   has_been_measured: bool - Quantum state has been collapsed
#   theta_frozen: bool - Measurement locked the theta value (stops Hamiltonian drift)
#   entangled_with: Array[Vector2i] - Positions of entangled plots (bidirectional)
#   persistent_gates: Array[Dictionary] - Persistent gate infrastructure (survives harvest)
#       Each gate: {type: String, active: bool, linked_plots: Array[Vector2i]}
#       Types: "bell_phi_plus", "cluster", "measure_trigger"
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

## LEGACY - Single Biome (DEPRECATED in Phase 2)
## Kept for backward compatibility with old saves
@export var time_elapsed: float = 0.0  # DEPRECATED: Use biome_states["BioticFlux"]["time_elapsed"]
@export var sun_theta: float = 0.0  # DEPRECATED: Use biome_states["BioticFlux"]["sun_qubit"]["theta"]
@export var sun_phi: float = 0.0    # DEPRECATED: Use biome_states["BioticFlux"]["sun_qubit"]["phi"]
@export var wheat_icon_theta: float = PI/12  # DEPRECATED
@export var mushroom_icon_theta: float = 11*PI/12  # DEPRECATED
@export var biome_state: Dictionary = {}  # DEPRECATED: Use biome_states

## Phase 2: Multi-Biome Architecture
## Each biome has its own quantum state, independent evolution
@export var biome_states: Dictionary = {}
# Structure: biome_name → biome_state_dict
# {
#   "BioticFlux": {
#     "time_elapsed": float,
#     "sun_qubit": {theta, phi, radius, energy},
#     "wheat_icon": {theta, phi, radius, energy},
#     "mushroom_icon": {theta, phi, radius, energy},
#     "quantum_states": [{position, theta, phi, radius, energy, north_emoji, south_emoji}, ...],
#
#     # Phase 5.1: Gate infrastructure (entanglement gates persist across saves)
#     "bell_gates": [[Vector2i, ...], ...],  # Array of position arrays (pairs, triplets, clusters)
#     # Example: [[Vector2i(0,0), Vector2i(1,0)], [Vector2i(2,0), Vector2i(3,0), Vector2i(4,0)]]
#     # First is a pair gate, second is a triplet gate
#
#     # Phase 3: Bath-first mode support
#     "use_bath_mode": bool,  # True if biome uses QuantumBath
#     "bath_state": {  # Only if use_bath_mode=true
#       "emojis": [String, ...],  # Emoji basis
#       "amplitudes": {"emoji": {real: float, imag: float}, ...},
#       "bath_time": float
#     },
#     "active_projections": [  # Only if use_bath_mode=true
#       {"position": Vector2i, "north": String, "south": String},
#       ...
#     ]
#   },
#   "Market": {...},
#   "Forest": {...},
#   "Kitchen": {...}
# }

## Phase 2: Plot-to-Biome Assignments
## Maps each plot position to its assigned biome
@export var plot_biome_assignments: Dictionary = {}
# Structure: String(Vector2i) → biome_name
# Example: "(0, 0)" → "Market", "(2, 0)" → "BioticFlux"

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
				"entangled_with": [],
				"persistent_gates": [],
				"lindblad_pump_active": false,
				"lindblad_drain_active": false,
				"lindblad_pump_rate": 0.5,
				"lindblad_drain_rate": 0.5
			})

	# Initialize typed arrays properly (Godot 4 requirement)
	completed_goals.clear()
	active_contracts.clear()

	# Player vocabulary is initialized in the @export default above
	# 🌾 (Wheat) and 👥 (People) are the starter emojis
	# These match faction signatures and seed initial faction conversations


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
				"entangled_with": [],
				"persistent_gates": [],
				"lindblad_pump_active": false,
				"lindblad_drain_active": false,
				"lindblad_pump_rate": 0.5,
				"lindblad_drain_rate": 0.5
			})

	return state


func get_save_display_name() -> String:
	"""Get human-readable save name"""
	var time = Time.get_datetime_dict_from_unix_time(save_timestamp)
	return "%02d/%02d/%04d %02d:%02d" % [
		time.month, time.day, time.year,
		time.hour, time.minute
	]
