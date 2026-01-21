extends Node

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = get_node("/root/VerboseConfig")

## GameStateManager - Singleton for save/load operations
## Handles 3 save slots, scenarios, and state capture/restore

const GameState = preload("res://Core/GameState/GameState.gd")
const VocabularyEvolution = preload("res://Core/QuantumSubstrate/VocabularyEvolution.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const QuantumRigorConfig = preload("res://Core/GameState/QuantumRigorConfig.gd")

# Signals
signal emoji_discovered(emoji: String)
signal pair_discovered(north: String, south: String)
signal factions_unlocked(factions: Array)

# Save configuration
const SAVE_DIR = "user://saves/"
const NUM_SAVE_SLOTS = 3
const SCENARIO_DIR = "res://Scenarios/"

# Current state
var current_state: GameState = null
var current_scenario_id: String = "default"
var last_saved_slot: int = -1  # Track most recent save for "Reload Last Save"

# Reference to active game (set by FarmView)
var active_farm_view = null  # DEPRECATED: Use active_farm instead

# Direct reference to Farm simulation (Phase 1: Simulation-only saves)
var active_farm = null

# PERSISTENT VOCABULARY EVOLUTION - Travels with player across farms/biomes
var vocabulary_evolution: VocabularyEvolution = null


func _ready():
	# Ensure save directory exists
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
	_verbose.info("save", "💾", "GameStateManager ready - Save dir: " + SAVE_DIR)

	# Initialize quantum rigor configuration (singleton)
	if not QuantumRigorConfig.instance:
		var config = QuantumRigorConfig.new()
		_verbose.info("quantum", "⚛️", "QuantumRigorConfig initialized: %s" % config.mode_description())

	# Initialize persistent vocabulary evolution system
	if not vocabulary_evolution:
		vocabulary_evolution = VocabularyEvolution.new()
		vocabulary_evolution._ready()
		add_child(vocabulary_evolution)
		_verbose.info("quest", "📚", "Persistent VocabularyEvolution initialized")


## Player Vocabulary Discovery

func discover_emoji(emoji: String) -> void:
	"""Player encounters a new emoji - updates vocabulary and checks for unlocked factions

	This is called when:
	- Player harvests a new resource type
	- Player completes a quest with a new emoji reward
	- Player unlocks a new tool/icon
	"""
	if not current_state:
		return

	# Already known?
	if emoji in current_state.known_emojis:
		return

	# Add to vocabulary
	current_state.known_emojis.append(emoji)
	emit_signal("emoji_discovered", emoji)

	_verbose.info("quest", "📖", "Discovered emoji: %s (vocabulary: %d emojis)" % [emoji, current_state.known_emojis.size()])

	# Check if this unlocks new factions
	var newly_accessible = _check_newly_accessible_factions(emoji)
	if newly_accessible.size() > 0:
		emit_signal("factions_unlocked", newly_accessible)
		_verbose.info("quest", "🔓", "Unlocked %d new faction(s)!" % newly_accessible.size())
		for faction in newly_accessible:
			var sig = faction.get("sig", [])
			_verbose.info("quest", "-", "%s %s" % ["".join(sig.slice(0, 3)), faction.get("name", "?")])


func discover_pair(north: String, south: String) -> void:
	"""Player learns a vocabulary pair (plantable qubit axis)

	This is called when:
	- Quest completion grants paired vocabulary
	- Starting the game with initial pairs

	Args:
		north: The North pole emoji (from faction)
		south: The South pole emoji (rolled from physics)
	"""
	if not current_state:
		return

	# Check if pair already known
	for pair in current_state.known_pairs:
		if pair.get("north") == north and pair.get("south") == south:
			return  # Already known

	# Add pair
	current_state.known_pairs.append({"north": north, "south": south})

	# Also add individual emojis to known_emojis
	discover_emoji(north)
	discover_emoji(south)

	emit_signal("pair_discovered", north, south)
	_verbose.info("quest", "📖", "Discovered pair: %s/%s (vocabulary: %d pairs)" % [north, south, current_state.known_pairs.size()])


func _check_newly_accessible_factions(new_emoji: String) -> Array:
	"""Find factions that just became accessible due to vocabulary overlap

	A faction is "newly accessible" if:
	- It had NO vocabulary overlap before (inaccessible)
	- It has vocabulary overlap now (accessible)
	"""
	if not current_state:
		return []

	var newly_accessible = []
	var old_vocab = current_state.known_emojis.filter(func(e): return e != new_emoji)

	for faction in FactionDatabase.ALL_FACTIONS:
		var faction_vocab = FactionDatabase.get_faction_vocabulary(faction)

		# Check if faction was inaccessible before
		var old_overlap = FactionDatabase.get_vocabulary_overlap(faction_vocab.all, old_vocab)
		var new_overlap = FactionDatabase.get_vocabulary_overlap(faction_vocab.all, current_state.known_emojis)

		if old_overlap.is_empty() and not new_overlap.is_empty():
			newly_accessible.append(faction)

	return newly_accessible


func get_accessible_factions() -> Array:
	"""Get all factions that have vocabulary overlap with player (can receive quests)"""
	if not current_state:
		return []

	var accessible = []

	for faction in FactionDatabase.ALL_FACTIONS:
		var faction_vocab = FactionDatabase.get_faction_vocabulary(faction)
		var overlap = FactionDatabase.get_vocabulary_overlap(faction_vocab.all, current_state.known_emojis)

		if not overlap.is_empty():
			accessible.append(faction)

	return accessible


## New Game / Scenarios

func new_game(scenario_id: String = "default") -> GameState:
	"""Start new game by loading a scenario template"""
	_verbose.info("quest", "🎮", "Starting new game with scenario: " + scenario_id)
	current_scenario_id = scenario_id

	# Try to load scenario file, fall back to default state
	var scenario_path = SCENARIO_DIR + scenario_id + ".tres"
	if ResourceLoader.exists(scenario_path):
		current_state = ResourceLoader.load(scenario_path).duplicate()
		_verbose.info("quest", "✓", "Loaded scenario from: " + scenario_path)
	else:
		_verbose.info("quest", "⚠", "Scenario not found, using default state")
		current_state = GameState.new()
		current_state.scenario_id = scenario_id

	current_state.save_timestamp = Time.get_unix_time_from_system()
	current_state.game_time = 0.0
	return current_state


## Save Operations

func save_game(slot: int) -> bool:
	"""Save current game state to slot (0-2)"""
	if slot < 0 or slot >= NUM_SAVE_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return false
	
	if not active_farm:
		push_error("No active game to save!")
		return false
	
	# Capture current state from live game
	var state = capture_state_from_game()
	
	# Save to disk
	var path = get_save_path(slot)
	var result = ResourceSaver.save(state, path)

	if result == OK:
		last_saved_slot = slot
		_verbose.info("save", "💾", "Game saved to slot " + str(slot + 1) + ": " + path)
		return true
	else:
		push_error("Failed to save game to slot " + str(slot))
		return false


func get_save_path(slot: int) -> String:
	"""Get file path for save slot"""
	return SAVE_DIR + "save_slot_" + str(slot) + ".tres"


func save_exists(slot: int) -> bool:
	"""Check if save file exists in slot"""
	return FileAccess.file_exists(get_save_path(slot))


func get_save_info(slot: int) -> Dictionary:
	"""Get save file info for display in load menu"""
	if not save_exists(slot):
		return {"exists": false, "slot": slot}
	
	var state = load_game_state(slot)
	if not state:
		return {"exists": false, "slot": slot}
	
	return {
		"exists": true,
		"slot": slot,
		"display_name": state.get_save_display_name(),
		"scenario": state.scenario_id,
		"credits": state.credits,
		"goal_index": state.current_goal_index,
		"playtime": state.game_time
	}


## Load Operations

func load_game_state(slot: int) -> GameState:
	"""Load game state from slot (returns state, doesn't apply it)"""
	if slot < 0 or slot >= NUM_SAVE_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return null

	var path = get_save_path(slot)
	if not FileAccess.file_exists(path):
		_verbose.info("save", "⚠", "No save file in slot " + str(slot + 1))
		return null

	var state = ResourceLoader.load(path)
	if state:
		_verbose.info("save", "📂", "Loaded save from slot " + str(slot + 1))
		return state
	else:
		push_error("Failed to load save from slot " + str(slot))
		return null


func load_and_apply(slot: int) -> bool:
	"""Load game state from slot and apply it to active game"""
	var state = load_game_state(slot)
	if not state:
		return false

	if not active_farm:
		push_error("No active game to apply state to!")
		return false

	apply_state_to_game(state)
	current_state = state
	current_scenario_id = state.scenario_id
	# NOTE: Don't update last_saved_slot here - only update on actual save
	# This ensures "Reload Last Save" reloads the last SAVED file, not last LOADED file
	return true


func reload_last_save() -> bool:
	"""Reload the most recently saved game by scanning all slots for latest timestamp"""
	var latest_slot = -1
	var latest_timestamp = 0.0

	# Scan all save slots to find the most recent
	for slot in range(NUM_SAVE_SLOTS):
		if not save_exists(slot):
			continue

		var state = load_game_state(slot)
		if state and state.save_timestamp > latest_timestamp:
			latest_timestamp = state.save_timestamp
			latest_slot = slot

	# No saves found
	if latest_slot < 0:
		_verbose.info("save", "⚠", "No saves found to reload")
		return false

	_verbose.info("save", "🔄", "Reloading most recent save from slot " + str(latest_slot + 1) + " (saved at " + str(latest_timestamp) + ")")
	return load_and_apply(latest_slot)


## State Capture/Restore

func capture_state_from_game() -> GameState:
	"""Capture current game state from active Farm (from FarmView)

	Refactored for Farm/Biome/Qubit architecture:
	- Economy: All resource inventories
	- Plots: Configuration, planted/measured/entanglement state
	- Goals: Progress
	- Icons: Activation levels
	- Time: Biome elapsed time + sun/moon phase
	- Quantum State: Complete biome_state tree (sun qubit, icon qubits, emoji qubits)
	"""
	var state = GameState.new()

	# Phase 1: Use direct farm reference (simulation-only saves)
	var farm = active_farm
	if not farm:
		push_error("Farm not found - cannot capture state (is GameStateManager.active_farm set?)")
		return state

	# Meta
	state.scenario_id = current_scenario_id
	state.save_timestamp = Time.get_unix_time_from_system()
	state.game_time = current_state.game_time if current_state else 0.0

	# Grid Dimensions (from Farm.grid)
	state.grid_width = farm.grid.grid_width
	state.grid_height = farm.grid.grid_height

	# Economy (from Farm.economy) - using emoji-based API
	var economy = farm.economy
	state.wheat_inventory = economy.get_resource("🌾")
	state.labor_inventory = economy.get_resource("👥")
	state.flour_inventory = economy.get_resource("🍞")
	state.flower_inventory = economy.get_resource("🌻")
	state.mushroom_inventory = economy.get_resource("🍄")
	state.detritus_inventory = economy.get_resource("🍂")
	state.imperium_resource = economy.get_resource("👑")
	state.credits = economy.get_resource("💰")
	state.tributes_paid = economy.total_tributes_paid if "total_tributes_paid" in economy else 0
	state.tributes_failed = economy.total_tributes_failed if "total_tributes_failed" in economy else 0

	# Plots (from Farm.grid)
	state.plots.clear()
	var grid = farm.grid
	for y in range(state.grid_height):
		for x in range(state.grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)

			# Capture plot configuration and measurement state
			# NOTE: Quantum state details (theta, phi, radius, energy, berry_phase) are NOT saved
			#       They regenerate when plots are planted from the biome environment
			var plot_data = {
				"position": pos,
				"type": plot.plot_type,
				"is_planted": plot.is_planted,
				"has_been_measured": plot.has_been_measured,
				"theta_frozen": plot.theta_frozen,
				"entangled_with": plot.entangled_plots.keys()
			}
			# Phase 5.2: Serialize persistent gate infrastructure (Tool #2 gates)
			# These gates survive harvest/replant cycles
			if "persistent_gates" in plot:
				var serialized_gates = []
				for gate in plot.persistent_gates:
					var serialized_gate = {
						"type": gate.get("type", ""),
						"active": gate.get("active", true)
					}
					# Serialize linked_plots (Array[Vector2i] → Array[Dictionary])
					var linked_plots_serialized = []
					for linked_pos in gate.get("linked_plots", []):
						linked_plots_serialized.append({"x": linked_pos.x, "y": linked_pos.y})
					serialized_gate["linked_plots"] = linked_plots_serialized
					serialized_gates.append(serialized_gate)
				plot_data["persistent_gates"] = serialized_gates
			else:
				plot_data["persistent_gates"] = []

			state.plots.append(plot_data)

	# Goals
	var goals = farm.goals
	state.current_goal_index = goals.current_goal_index
	state.completed_goals.clear()
	for i in range(goals.goals_completed.size()):
		if goals.goals_completed[i]:
			state.completed_goals.append(goals.goals[i]["id"])

	# Icons (DEPRECATED: Icons now managed by IconRegistry autoload)
	# Set to 0.0 - icon state no longer persisted per-farm
	state.biotic_activation = 0.0
	state.chaos_activation = 0.0
	state.imperium_activation = 0.0

	# Phase 2: Multi-Biome Capture
	# Capture quantum states from all registered biomes
	state.biome_states = _capture_all_biome_states(farm)

	# Capture plot→biome assignments
	state.plot_biome_assignments = {}
	if farm.grid and "plot_biome_assignments" in farm.grid:
		for pos_key in farm.grid.plot_biome_assignments.keys():
			state.plot_biome_assignments[pos_key] = farm.grid.plot_biome_assignments[pos_key]

	# LEGACY: Also populate old single-biome fields for backward compatibility
	# Use BioticFlux as the "primary" biome for old saves
	if state.biome_states.has("BioticFlux"):
		var bf = state.biome_states["BioticFlux"]
		state.time_elapsed = bf.get("time_elapsed", 0.0)
		if bf.has("sun_qubit"):
			state.sun_theta = bf["sun_qubit"].get("theta", 0.0)
			state.sun_phi = bf["sun_qubit"].get("phi", 0.0)
		state.biome_state = bf  # Copy full state for backward compat

	# Vocabulary Evolution State (PERSISTED - player's discovered vocabulary travels with them)
	if vocabulary_evolution:
		state.vocabulary_state = vocabulary_evolution.serialize()
		_verbose.debug("save", "📚", "Captured vocabulary: %d discovered, %d evolving" % [
			state.vocabulary_state.get("discovered_vocabulary", []).size(),
			state.vocabulary_state.get("evolving_qubits", []).size()
		])

	# Conspiracy Network NOT saved (dynamic, regenerated each session)

	_verbose.info("save", "📸", "Captured game state: grid=" + str(state.grid_width) + "x" + str(state.grid_height) +
		  ", plots=" + str(state.plots.size()) + ", credits=" + str(state.credits))
	return state


## Phase 2: Multi-Biome Capture Helpers

func _capture_all_biome_states(farm: Node) -> Dictionary:
	"""Capture quantum state from all registered biomes (DYNAMIC)

	Phase 7: Supports arbitrary biomes by discovering them from grid.biomes registry.
	Each biome's class type is saved so it can be recreated on load.
	"""
	var all_states = {}

	# Dynamically discover all registered biomes from grid
	if not farm.grid or not "biomes" in farm.grid:
		push_warning("Farm grid has no biomes registry - cannot capture biome states")
		return all_states

	# Capture each registered biome
	for biome_name in farm.grid.biomes.keys():
		var biome = farm.grid.biomes[biome_name]
		if biome:
			var state = _capture_single_biome_state(biome, biome_name)

			# Add biome class type for recreation on load
			state["biome_class"] = biome.get_script().resource_path

			all_states[biome_name] = state
			_verbose.debug("save", "💾", "Captured %s biome (%s)" % [biome_name, state["biome_class"]])

	return all_states


func _capture_single_biome_state(biome: Node, biome_name: String) -> Dictionary:
	"""Capture quantum state from one biome"""
	var state_dict = {
		"time_elapsed": 0.0,
		"quantum_states": []
	}

	# Capture time
	if "time_elapsed" in biome:
		state_dict["time_elapsed"] = biome.time_elapsed
	elif "time_tracker" in biome and biome.time_tracker:
		state_dict["time_elapsed"] = biome.time_tracker.time_elapsed

	# Capture sun/moon qubit (BioticFlux specific)
	if biome_name == "BioticFlux" and "sun_qubit" in biome and biome.sun_qubit:
		state_dict["sun_qubit"] = {
			"theta": biome.sun_qubit.theta,
			"phi": biome.sun_qubit.phi,
			"radius": biome.sun_qubit.radius
			# energy removed - now derived from theta (excitation = sin²(θ/2))
		}

	# Capture icon states (if they have internal_qubit)
	if "wheat_icon" in biome and biome.wheat_icon:
		if biome.wheat_icon is Dictionary and biome.wheat_icon.has("internal_qubit"):
			var iq = biome.wheat_icon["internal_qubit"]
			state_dict["wheat_icon"] = {
				"theta": iq.theta, "phi": iq.phi, "radius": iq.radius
				# energy removed - derived from theta
			}
		elif biome.wheat_icon.has("internal_qubit"):
			var iq = biome.wheat_icon.internal_qubit
			state_dict["wheat_icon"] = {
				"theta": iq.theta, "phi": iq.phi, "radius": iq.radius
				# energy removed - derived from theta
			}

	if "mushroom_icon" in biome and biome.mushroom_icon:
		if biome.mushroom_icon is Dictionary and biome.mushroom_icon.has("internal_qubit"):
			var iq = biome.mushroom_icon["internal_qubit"]
			state_dict["mushroom_icon"] = {
				"theta": iq.theta, "phi": iq.phi, "radius": iq.radius
				# energy removed - derived from theta
			}
		elif biome.mushroom_icon.has("internal_qubit"):
			var iq = biome.mushroom_icon.internal_qubit
			state_dict["mushroom_icon"] = {
				"theta": iq.theta, "phi": iq.phi, "radius": iq.radius
				# energy removed - derived from theta
			}

	# PHASE 6: Don't save individual qubit states for bath-mode biomes
	# Qubits are live projections - theta/phi/radius computed from bath
	# We only save bath state + projection metadata (active_projections)
	# For backwards compat with non-bath biomes, still save quantum_states
	if "quantum_states" in biome and not ("bath" in biome and biome.bath):
		# Legacy mode: save qubit states for biomes without bath
		for pos in biome.quantum_states.keys():
			var qubit = biome.quantum_states[pos]
			if qubit:
				var qubit_data = {
					"position": pos,
					"theta": qubit.theta,
					"phi": qubit.phi,
					"radius": qubit.radius
				}
				if "north_emoji" in qubit:
					qubit_data["north_emoji"] = qubit.north_emoji
				if "south_emoji" in qubit:
					qubit_data["south_emoji"] = qubit.south_emoji
				state_dict["quantum_states"].append(qubit_data)

	# Phase 5.1: Capture gate infrastructure (Bell gates, CNOT gates, cluster gates)
	state_dict["bell_gates"] = []
	if "bell_gates" in biome:
		for gate in biome.bell_gates:
			# Each gate is an array of Vector2i positions
			# Convert to serializable format (Array[Vector2i] → Array[Dictionary])
			var gate_positions = []
			for pos in gate:
				gate_positions.append({"x": pos.x, "y": pos.y})
			state_dict["bell_gates"].append(gate_positions)

	# Phase 3: Capture bath state (all biomes now use bath mode)
	# Serialize bath state if biome has a bath
	if "bath" in biome and biome.bath:
		# Serialize QuantumBath amplitudes
		state_dict["bath_state"] = _serialize_bath_state(biome.bath)

		# Serialize active projections
		state_dict["active_projections"] = []
		if "active_projections" in biome:
			for pos in biome.active_projections.keys():
				var proj_data = biome.active_projections[pos]
				state_dict["active_projections"].append({
					"position": pos,
					"north": proj_data.north,
					"south": proj_data.south
				})

	return state_dict


## Phase 2: Multi-Biome Restore Helpers

func _restore_all_biome_states(farm: Node, biome_states: Dictionary) -> void:
	"""Restore quantum states to all biomes (DYNAMIC)

	Phase 7: Handles arbitrary biomes by discovering them from grid.biomes registry.
	Biomes must already be registered in the grid (Farm._ready() handles this).
	"""
	if not farm.grid or not "biomes" in farm.grid:
		push_warning("Farm grid has no biomes registry - cannot restore biome states")
		return

	for biome_name in biome_states.keys():
		var biome_state = biome_states[biome_name]

		# Get biome from grid registry
		var biome = farm.grid.biomes.get(biome_name, null)

		if not biome:
			push_warning("Biome %s not found in grid registry - skipping restore" % biome_name)
			continue

		# Restore state
		_restore_single_biome_state(biome, biome_state, biome_name)
		_verbose.debug("save", "📂", "Restored %s biome" % biome_name)


func _restore_single_biome_state(biome: Node, state: Dictionary, biome_name: String) -> void:
	"""Restore quantum state to one biome"""

	# Restore time
	if state.has("time_elapsed"):
		if "time_elapsed" in biome:
			biome.time_elapsed = state.time_elapsed
		elif "time_tracker" in biome and biome.time_tracker:
			biome.time_tracker.time_elapsed = state.time_elapsed

	# Restore sun/moon qubit (BioticFlux specific)
	if biome_name == "BioticFlux" and state.has("sun_qubit") and "sun_qubit" in biome and biome.sun_qubit:
		var sq = state.sun_qubit
		biome.sun_qubit.theta = sq.get("theta", 0.0)
		biome.sun_qubit.phi = sq.get("phi", 0.0)
		biome.sun_qubit.radius = sq.get("radius", 1.0)
		# energy removed - derived from theta automatically

	# Restore wheat icon (if has internal_qubit)
	if state.has("wheat_icon") and "wheat_icon" in biome and biome.wheat_icon:
		var wi = state.wheat_icon
		if biome.wheat_icon is Dictionary and biome.wheat_icon.has("internal_qubit"):
			var iq = biome.wheat_icon["internal_qubit"]
			iq.theta = wi.get("theta", PI/4.0)
			iq.phi = wi.get("phi", 0.0)
			iq.radius = wi.get("radius", 1.0)
			# energy removed - derived from theta
		elif biome.wheat_icon.has("internal_qubit"):
			var iq = biome.wheat_icon.internal_qubit
			iq.theta = wi.get("theta", PI/4.0)
			iq.phi = wi.get("phi", 0.0)
			iq.radius = wi.get("radius", 1.0)
			# energy removed - derived from theta

	# Restore mushroom icon (if has internal_qubit)
	if state.has("mushroom_icon") and "mushroom_icon" in biome and biome.mushroom_icon:
		var mi = state.mushroom_icon
		if biome.mushroom_icon is Dictionary and biome.mushroom_icon.has("internal_qubit"):
			var iq = biome.mushroom_icon["internal_qubit"]
			iq.theta = mi.get("theta", PI)
			iq.phi = mi.get("phi", 0.0)
			iq.radius = mi.get("radius", 1.0)
			# energy removed - derived from theta
		elif biome.mushroom_icon.has("internal_qubit"):
			var iq = biome.mushroom_icon.internal_qubit
			iq.theta = mi.get("theta", PI)
			iq.phi = mi.get("phi", 0.0)
			iq.radius = mi.get("radius", 1.0)
			# energy removed - derived from theta

	# Restore quantum states (emoji qubits)
	if state.has("quantum_states") and "quantum_states" in biome:
		for qubit_data in state.quantum_states:
			var pos = qubit_data["position"]
			if biome.quantum_states.has(pos):
				var qubit = biome.quantum_states[pos]
				qubit.theta = qubit_data.get("theta", PI/2.0)
				qubit.phi = qubit_data.get("phi", 0.0)
				qubit.radius = qubit_data.get("radius", 0.3)
				# energy removed - derived from theta (excitation = sin²(θ/2))

	# Phase 5.1: Restore gate infrastructure (Bell gates, CNOT gates, cluster gates)
	if state.has("bell_gates") and "bell_gates" in biome:
		biome.bell_gates.clear()
		for gate_data in state.bell_gates:
			# Convert serialized format back to Vector2i array
			var gate_positions = []
			for pos_dict in gate_data:
				gate_positions.append(Vector2i(pos_dict.x, pos_dict.y))
			biome.bell_gates.append(gate_positions)

	# Phase 3: Restore bath state (all biomes now use bath mode)
	# Wait for bath initialization (async process)
	if not "bath" in biome or not biome.bath:
		await biome.get_tree().process_frame

	# Restore bath state if saved
	if state.has("bath_state") and "bath" in biome and biome.bath:
		_deserialize_bath_state(biome.bath, state.bath_state)

		# Recreate projections
		if state.has("active_projections") and biome.has_method("create_projection"):
			biome.active_projections.clear()
			for proj in state.active_projections:
				biome.create_projection(proj.position, proj.north, proj.south)


## Phase 6: Plot-Projection Reconnection

func _reconnect_plots_to_projections(farm: Node, state: GameState) -> void:
	"""Reconnect plots to their biome projections after load

	After biomes recreate projections via create_projection(), plots need
	to have their quantum_state references updated to point to those projections.
	"""
	if not farm.grid:
		return

	var reconnected_count = 0

	for plot_data in state.plots:
		var pos = plot_data["position"]

		# Get plot
		var plot = farm.grid.get_plot(pos)
		if not plot:
			continue

		# Skip if plot not planted (check actual plot, not save data)
		if not plot.is_planted:
			continue

		# Get biome for this plot
		var biome_name = ""
		if farm.grid.plot_biome_assignments.has(pos):
			biome_name = farm.grid.plot_biome_assignments[pos]
		else:
			continue

		# Get biome reference from grid registry (DYNAMIC)
		var biome = farm.grid.biomes.get(biome_name, null)

		if not biome:
			push_warning("Biome %s not found for plot reconnection" % biome_name)
			continue

		# Look up projection in biome's active_projections
		if not "active_projections" in biome:
			continue

		if not pos in biome.active_projections:
			continue

		var projection = biome.active_projections[pos]
		if not projection.has("qubit"):
			continue

		# Model C: Reconnect plot to projection via bath_subplot_id
		# (backwards compatible with old register_id saves)
		if projection.has("bath_subplot_id"):
			plot.bath_subplot_id = projection.bath_subplot_id
			reconnected_count += 1
		elif projection.has("register_id"):
			# Backwards compatibility with Model B saves
			plot.bath_subplot_id = projection.register_id
			reconnected_count += 1

	if reconnected_count > 0:
		_verbose.debug("farm", "🔗", "Reconnected %d plots to biome projections" % reconnected_count)


## Phase 3: Bath-First Serialization Helpers

func _serialize_bath_state(bath: RefCounted) -> Dictionary:
	"""Convert QuantumBath to serializable dict (Phase 3)"""
	var serialized_amps = {}

	# Serialize Complex amplitudes to {real, imag} dictionaries
	for emoji in bath.emoji_list:
		var amp = bath.get_amplitude(emoji)
		serialized_amps[emoji] = {
			"real": amp.re,
			"imag": amp.im
		}

	return {
		"emojis": bath.emoji_list.duplicate(),
		"amplitudes": serialized_amps,
		"bath_time": bath.bath_time
	}


func _deserialize_bath_state(bath: RefCounted, state: Dictionary) -> void:
	"""Restore QuantumBath from serialized dict (Phase 3)"""
	const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

	# Restore amplitudes array
	for i in range(state.emojis.size()):
		var emoji = state.emojis[i]
		if state.amplitudes.has(emoji):
			var amp_data = state.amplitudes[emoji]
			var amp = Complex.new(amp_data.real, amp_data.imag)
			bath.amplitudes[i] = amp

	bath.bath_time = state.bath_time


func apply_state_to_game(state: GameState):
	"""Apply loaded state to active Farm (through FarmView)

	Refactored for Farm/Biome/Qubit architecture:
	- Loads economy, plot configuration, goals, time from GameState
	- Restores complete biome quantum state tree (all qubits)
	- UI layer (icons, visuals) updated through FarmView
	"""
	# Phase 1: Use direct farm reference (simulation-only saves)
	var farm = active_farm

	if not farm:
		push_error("Farm not found - cannot apply state (is GameStateManager.active_farm set?)")
		return

	# Phase 4: Validation
	# Version check
	if state.save_version != 1:
		push_error("Save file version mismatch: expected 1, got %d" % state.save_version)
		push_error("This save may be incompatible with current game version")
		# Continue anyway - attempt to load what we can

	# Grid size validation
	if farm.grid:
		if state.grid_width != farm.grid.grid_width or state.grid_height != farm.grid.grid_height:
			push_warning("Grid size mismatch: save has %dx%d, farm has %dx%d" % [
				state.grid_width, state.grid_height,
				farm.grid.grid_width, farm.grid.grid_height
			])
			push_warning("Out-of-bounds plots will be skipped")

	_verbose.info("save", "🔄", "Applying game state to farm (" + str(state.grid_width) + "x" + str(state.grid_height) + ")...")

	# Apply Economy (from Farm.economy) - using emoji-based API
	var economy = farm.economy
	economy.emoji_credits["🌾"] = state.wheat_inventory
	economy.emoji_credits["👥"] = state.labor_inventory
	economy.emoji_credits["🍞"] = state.flour_inventory
	economy.emoji_credits["🌻"] = state.flower_inventory
	economy.emoji_credits["🍄"] = state.mushroom_inventory
	economy.emoji_credits["🍂"] = state.detritus_inventory
	economy.emoji_credits["👑"] = state.imperium_resource
	economy.emoji_credits["💰"] = state.credits
	if "total_tributes_paid" in economy:
		economy.total_tributes_paid = state.tributes_paid
	if "total_tributes_failed" in economy:
		economy.total_tributes_failed = state.tributes_failed

	# Emit signals for UI updates
	for emoji in economy.emoji_credits.keys():
		economy._emit_resource_change(emoji)

	# Apply Plot Configuration (from Farm.grid)
	var grid = farm.grid
	for plot_data in state.plots:
		var pos = plot_data["position"]

		# Phase 4: Bounds checking - skip out-of-bounds plots
		if pos.x < 0 or pos.x >= grid.grid_width or pos.y < 0 or pos.y >= grid.grid_height:
			push_warning("Skipping out-of-bounds plot at %s (grid is %dx%d)" % [
				pos, grid.grid_width, grid.grid_height
			])
			continue

		var plot = grid.get_plot(pos)

		if plot:
			plot.plot_type = plot_data["type"]
			plot.is_planted = plot_data["is_planted"]

			# Measurement state (collapses quantum superposition)
			plot.has_been_measured = plot_data.get("has_been_measured", false)
			plot.theta_frozen = plot_data.get("theta_frozen", false)

			# Restore entanglement relationships
			plot.entangled_plots.clear()
			for entangled_pos in plot_data.get("entangled_with", []):
				var other_plot = grid.get_plot(entangled_pos)
				if other_plot:
					plot.entangled_plots[other_plot.plot_id] = 1.0

			# IMPORTANT: Quantum state details (theta, phi, radius, energy, berry_phase)
			# are NOT restored - they regenerate from the biome when the plot is replanted.
			# This keeps the save format simple and maintains deterministic behavior through
			# the infrastructure model (entanglement gates persist, qubits regenerate).

	# Apply Goals
	var goals = farm.goals
	goals.current_goal_index = state.current_goal_index
	goals.goals_completed.clear()
	for goal in goals.goals:
		var is_completed = state.completed_goals.has(goal["id"])
		goals.goals_completed.append(is_completed)
		goal["completed"] = is_completed

	# Phase 2: Multi-Biome Restore
	# Restore plot→biome assignments FIRST (before restoring states)
	if state.plot_biome_assignments and farm.grid:
		if "plot_biome_assignments" in farm.grid:
			farm.grid.plot_biome_assignments = state.plot_biome_assignments.duplicate()

	# Restore quantum states to all biomes
	if state.biome_states:
		_restore_all_biome_states(farm, state.biome_states)
	elif state.biome_state:
		# LEGACY: Old saves only have single biome_state - restore to BioticFlux
		if farm.biotic_flux_biome:
			_restore_single_biome_state(farm.biotic_flux_biome, state.biome_state, "BioticFlux")

	# Phase 6: Reconnect plots to their biome projections
	# After biomes recreate projections, plots need to know about them
	_reconnect_plots_to_projections(farm, state)

	# Apply Icon Activation (Phase 1: Now from Farm simulation layer)
	if farm.biotic_icon and farm.biotic_icon.has_method("set_activation"):
		farm.biotic_icon.set_activation(state.biotic_activation)
	if farm.chaos_icon and farm.chaos_icon.has_method("set_activation"):
		farm.chaos_icon.set_activation(state.chaos_activation)
	if farm.imperium_icon and farm.imperium_icon.has_method("set_activation"):
		farm.imperium_icon.set_activation(state.imperium_activation)

	# Restore Vocabulary Evolution State (PERSISTED - player's discovered vocabulary)
	if vocabulary_evolution and state.vocabulary_state:
		vocabulary_evolution.deserialize(state.vocabulary_state)
		_verbose.debug("save", "📚", "Restored vocabulary evolution from save")

	# Conspiracy Network NOT loaded (dynamic, regenerate each session)

	# Phase 5: Visualizer Rebuild Strategy
	# ARCHITECTURE: GameStateManager (simulation layer) doesn't access UI visualizers directly
	#
	# Automatic rebuild via signals:
	# - ResourcePanel: ✅ Already rebuilds via economy.resource_changed (emitted above)
	# - PlotGridDisplay: ✅ Has rebuild_from_grid() method (UI layer calls it after load)
	# - QuantumForceGraph: ✅ Has rebuild_from_biomes() method (UI layer calls it after load)
	#
	# The UI layer (FarmView/FarmUI) is responsible for calling rebuild methods after
	# GameStateManager.apply_state_to_game() completes. This maintains clean separation:
	# - Simulation layer (this file) restores game state
	# - UI layer responds by rebuilding visualizations
	#
	# NOTE: Economy signals are automatically emitted when we set wheat_inventory etc above,
	# so ResourcePanel updates happen automatically. Other visualizers need explicit rebuild.

	_verbose.info("save", "✓", "State applied to farm successfully - quantum states will regenerate from biome")


## Scenario Completion Tracking

func mark_scenario_completed(scenario_id: String):
	"""Mark scenario as completed (unlocks next scenarios)"""
	var completed = _load_completed_scenarios()
	if scenario_id not in completed:
		completed.append(scenario_id)
		_save_completed_scenarios(completed)
		_verbose.info("quest", "🏆", "Scenario completed: " + scenario_id)

func is_scenario_completed(scenario_id: String) -> bool:
	"""Check if player has completed this scenario"""
	var completed = _load_completed_scenarios()
	return scenario_id in completed

func get_completed_scenarios() -> Array[String]:
	"""Get list of all completed scenarios"""
	return _load_completed_scenarios() as Array[String]

func clear_completed_scenarios():
	"""Clear all completed scenarios (for testing/reset)"""
	_save_completed_scenarios([])
	_verbose.info("quest", "🔄", "Cleared all completed scenarios")

func _load_completed_scenarios() -> Array:
	"""Load completed scenarios from save file"""
	var completed_file = SAVE_DIR + "completed_scenarios.json"
	if not FileAccess.file_exists(completed_file):
		return []

	var file = FileAccess.open(completed_file, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.parse_string(json_string)
		if json and json is Array:
			return json
	return []

func _save_completed_scenarios(completed: Array):
	"""Save completed scenarios to save file"""
	var completed_file = SAVE_DIR + "completed_scenarios.json"
	var file = FileAccess.open(completed_file, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(completed)
		file.store_string(json_string)

## Restart

func restart_current_scenario():
	"""Restart by reloading current scenario (not scene reload!)"""
	_verbose.info("quest", "🔄", "Restarting scenario: " + current_scenario_id)
	var state = new_game(current_scenario_id)
	apply_state_to_game(state)


## Persistent Vocabulary Access

func get_vocabulary_evolution() -> VocabularyEvolution:
	"""Get the persistent vocabulary evolution system

	The vocabulary persists across farm/biome changes and travels with the player.
	This ensures discovered vocabulary remains available even when switching contexts.
	"""
	if not vocabulary_evolution:
		# Safety fallback - should not happen if _ready() was called
		vocabulary_evolution = VocabularyEvolution.new()
		vocabulary_evolution._ready()
		add_child(vocabulary_evolution)

	return vocabulary_evolution
