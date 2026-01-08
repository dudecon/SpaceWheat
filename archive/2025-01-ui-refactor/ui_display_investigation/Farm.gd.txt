class_name Farm
extends Node

## Farm - Pure simulation manager for quantum wheat farming
## Owns all game systems and handles all game logic
## Emits signals when state changes (no UI dependencies)

# System preloads
# Grid configuration (Phase 2)
const GridConfig = preload("res://Core/GameState/GridConfig.gd")
const PlotConfig = preload("res://Core/GameState/PlotConfig.gd")
const KeyboardLayoutConfig = preload("res://Core/GameState/KeyboardLayoutConfig.gd")

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const GoalsSystem = preload("res://Core/GameMechanics/GoalsSystem.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const MarketBiome = preload("res://Core/Environment/MarketBiome.gd")
const ForestBiome = preload("res://Core/Environment/ForestEcosystem_Biome.gd")
const QuantumKitchen_Biome = preload("res://Core/Environment/QuantumKitchen_Biome.gd")
const TestBiome = preload("res://Core/Environment/TestBiome.gd")
const FarmUIState = preload("res://Core/GameState/FarmUIState.gd")
const VocabularyEvolution = preload("res://Core/QuantumSubstrate/VocabularyEvolution.gd")

# Icon Hamiltonians (simulation objects that affect quantum evolution)
const BioticFluxIcon = preload("res://Core/Icons/BioticFluxIcon.gd")
const ChaosIcon = preload("res://Core/Icons/ChaosIcon.gd")
const ImperiumIcon = preload("res://Core/Icons/ImperiumIcon.gd")

# Core simulation systems
var grid: FarmGrid
var economy: FarmEconomy
var goals: GoalsSystem
var biotic_flux_biome: BioticFluxBiome
var market_biome: MarketBiome
var forest_biome: ForestBiome
var kitchen_biome: QuantumKitchen_Biome
var vocabulary_evolution: VocabularyEvolution  # Vocabulary evolution system
var ui_state: FarmUIState  # UI State abstraction layer
var grid_config: GridConfig = null  # Single source of truth for grid layout

# Icon Hamiltonians (simulation objects)
var biotic_icon = null
var chaos_icon = null
var imperium_icon = null

# Configuration

# Biome availability (may fail to load if icon dependencies are missing)
var biome_enabled: bool = false

# Build configuration - all plantable/buildable types
# Costs are in emoji-credits (1 quantum unit = 10 credits)
const BUILD_CONFIGS = {
	"wheat": {
		"cost": {"🌾": 1},  # 1 wheat credit - agricultural economy
		"type": "plant",
		"plant_type": "wheat",
		"north_emoji": "🌾",  # Wheat (growth/harvest)
		"south_emoji": "👥"   # Labor (work/cultivation)
	},
	"tomato": {
		"cost": {"🌾": 1},  # 1 wheat credit to plant
		"type": "plant",
		"plant_type": "tomato",
		"north_emoji": "🍅",  # Tomato (life/creation/conspiracy)
		"south_emoji": "🌌"   # Cosmic Chaos (void/entropy) - COUNTER-AXIAL
	},
	"mushroom": {
		"cost": {"🍄": 10, "🍂": 10},  # 1 mushroom + 1 detritus (50/50 split) - fungal cycle
		"type": "plant",
		"plant_type": "mushroom",
		"north_emoji": "🍄",  # Mushroom (fruiting body)
		"south_emoji": "🍂"   # Detritus (decomposition)
	},
	"mill": {
		"cost": {"🌾": 30},  # 3 wheat = 30 wheat-credits
		"type": "build"
	},
	"market": {
		"cost": {"🌾": 30},  # 3 wheat = 30 wheat-credits
		"type": "build"
	},
	"kitchen": {
		"cost": {"🌾": 30, "💨": 10},  # 3 wheat + 1 flour
		"type": "build"
	},
	"energy_tap": {
		"cost": {"🌾": 20},  # 2 wheat = 20 wheat-credits
		"type": "build"
	},
	"forest_harvest": {
		"cost": {},  # Free - gather natural detritus from forest
		"type": "gather",
		"yields": {"🍂": 5},  # Collect 5 detritus (leaf litter, deadwood)
		"biome_required": "Forest"  # Only works in Forest biome
	}
}

# Signals - emitted when game state changes (no UI callbacks needed)
signal state_changed(state_data: Dictionary)
signal action_result(action: String, success: bool, message: String)
signal action_rejected(action: String, position: Vector2i, reason: String)  # For visual/audio feedback
signal plot_planted(position: Vector2i, plant_type: String)
signal plot_harvested(position: Vector2i, yield_data: Dictionary)
signal plot_measured(position: Vector2i, outcome: String)
signal plots_entangled(pos1: Vector2i, pos2: Vector2i, bell_state: String)
signal economy_changed(state: Dictionary)


func _ready():
	# Ensure IconRegistry exists (for test mode where autoloads don't exist)
	_ensure_iconregistry()

	# Create grid configuration (single source of truth for grid layout)
	grid_config = _create_grid_config()
	var validation = grid_config.validate()
	if not validation.success:
		push_error("GridConfig validation failed:")
		for error in validation.errors:
			push_error("  - %s" % error)
		return


	# Create core systems
	economy = FarmEconomy.new()
	add_child(economy)

	# Create environmental simulations (three biomes for multi-biome support)
	biome_enabled = false

	# Instantiate BioticFlux Biome
	biotic_flux_biome = BioticFluxBiome.new()
	biotic_flux_biome.name = "BioticFlux"
	add_child(biotic_flux_biome)

	# Instantiate Market Biome
	market_biome = MarketBiome.new()
	market_biome.name = "Market"
	add_child(market_biome)

	# Instantiate Forest Ecosystem Biome
	forest_biome = ForestBiome.new()
	forest_biome.name = "Forest"
	add_child(forest_biome)

	# Instantiate Kitchen Biome
	kitchen_biome = QuantumKitchen_Biome.new()
	kitchen_biome.name = "Kitchen"
	add_child(kitchen_biome)

	# All four biomes successfully instantiated
	biome_enabled = true

	# Create Icons (simulation objects that affect quantum evolution)
	# These are owned by Farm (simulation) not UI
	biotic_icon = BioticFluxIcon.new()
	add_child(biotic_icon)

	chaos_icon = ChaosIcon.new()
	add_child(chaos_icon)

	imperium_icon = ImperiumIcon.new()
	add_child(imperium_icon)

	# Create grid AFTER biome (or fallback)
	grid = FarmGrid.new()
	grid.grid_width = grid_config.grid_width
	grid.grid_height = grid_config.grid_height

	# Connect economy to grid for mill/market/kitchen flour & bread processing
	grid.farm_economy = economy

	# Wire all four biomes to the grid
	if biome_enabled:
		grid.register_biome("BioticFlux", biotic_flux_biome)
		biotic_flux_biome.grid = grid

		grid.register_biome("Market", market_biome)
		market_biome.grid = grid

		grid.register_biome("Forest", forest_biome)
		forest_biome.grid = grid

		grid.register_biome("Kitchen", kitchen_biome)
		kitchen_biome.grid = grid

	add_child(grid)

	# Register all four biomes as metadata for UI systems (QuantumForceGraph visualization)
	set_meta("grid", grid)
	if biome_enabled:
		set_meta("biotic_flux_biome", biotic_flux_biome)
		set_meta("market_biome", market_biome)
		set_meta("forest_biome", forest_biome)
		set_meta("kitchen_biome", kitchen_biome)

	# Configure plot-to-biome assignments
	if biome_enabled and grid and grid.has_method("assign_plot_to_biome"):
		# Market biome: T,Y
		grid.assign_plot_to_biome(Vector2i(0, 0), "Market")
		grid.assign_plot_to_biome(Vector2i(1, 0), "Market")

		# BioticFlux biome: U,I,O,P
		grid.assign_plot_to_biome(Vector2i(2, 0), "BioticFlux")
		grid.assign_plot_to_biome(Vector2i(3, 0), "BioticFlux")
		grid.assign_plot_to_biome(Vector2i(4, 0), "BioticFlux")
		grid.assign_plot_to_biome(Vector2i(5, 0), "BioticFlux")

		# Forest biome: 0,9,8,7
		grid.assign_plot_to_biome(Vector2i(0, 1), "Forest")
		grid.assign_plot_to_biome(Vector2i(1, 1), "Forest")
		grid.assign_plot_to_biome(Vector2i(2, 1), "Forest")
		grid.assign_plot_to_biome(Vector2i(3, 1), "Forest")

		# Kitchen biome: , .
		grid.assign_plot_to_biome(Vector2i(4, 1), "Kitchen")
		grid.assign_plot_to_biome(Vector2i(5, 1), "Kitchen")

		# Create TestBiomes for any unassigned plots
		# DISABLED: TestBiome has IconRegistry dependency issues in headless mode
		# All plots are already assigned to main biomes anyway
		#print("🧪 Checking for unassigned plots...")
		#var test_biome_count = 0
		#for y in range(grid.grid_height):
		#	for x in range(grid.grid_width):
		#		var pos = Vector2i(x, y)
		#		if not grid.plot_biome_assignments.has(pos):
		#			# Create isolated TestBiome for this plot
		#			var test_biome = TestBiome.new(test_biome_count, pos)
		#			test_biome.name = "TestBiome_%d" % test_biome_count
		#			add_child(test_biome)
		#
		#			# Assign plot to this test biome
		#			grid.assign_plot_to_biome(pos, test_biome.name)
		#
		#			# Register with grid's biomes dict
		#			grid.biomes[test_biome.name] = test_biome
		#
		#			test_biome_count += 1
		#			print("  🧪 Created TestBiome #%d for plot %s" % [test_biome_count - 1, pos])
		#
		#if test_biome_count > 0:
		#	print("  ✅ Created %d TestBiomes for unassigned plots" % test_biome_count)

	# Get persistent vocabulary evolution from GameStateManager
	# The vocabulary persists across farms/biomes and travels with the player
	# Safe access for headless mode where get_tree() may return null
	var tree = get_tree()
	var game_state_mgr = null
	if tree and tree.root and tree.root.get_child_count() > 0:
		game_state_mgr = tree.root.get_child(0)
	if game_state_mgr and game_state_mgr.has_method("get_vocabulary_evolution"):
		vocabulary_evolution = game_state_mgr.get_vocabulary_evolution()
	else:
		# Fallback: create local vocabulary if GameStateManager not available
		# This happens in test/standalone scenarios
		var VocabularyEvolution = preload("res://Core/QuantumSubstrate/VocabularyEvolution.gd")
		vocabulary_evolution = VocabularyEvolution.new()
		add_child(vocabulary_evolution)

	# Inject vocabulary reference into grid for tap validation
	if grid:
		grid.vocabulary_evolution = vocabulary_evolution

	goals = GoalsSystem.new()
	add_child(goals)

	# Create UI State abstraction layer (Phase 2 integration)
	ui_state = FarmUIState.new()

	# Connect economy signals to both state_changed AND ui_state (de-slopped)
	var economy_signals = ["wheat_changed", "credits_changed", "flour_changed", "flower_changed", "labor_changed"]
	for sig_name in economy_signals:
		if economy.has_signal(sig_name):
			economy.connect(sig_name, _on_economy_changed)
			economy.connect(sig_name, _on_economy_changed_ui)

	# Connect Farm's own measurement signal to trigger UIState update
	plot_measured.connect(_on_plot_measured_ui)

	# Connect goal signals
	goals.goal_completed.connect(_on_goal_completed)

	# Populate UIState with initial farm state
	ui_state.refresh_all(self)


## Called by BootManager in Stage 3A to finalize setup before simulation starts
func finalize_setup() -> void:
	"""Finalize farm setup after all basic initialization.

	Called by BootManager.boot() after biomes are verified to be initialized.
	This allows for any post-setup operations needed before gameplay starts.
	"""
	# Verify all biomes have their baths initialized
	if biome_enabled:
		assert(biotic_flux_biome.bath != null, "BioticFlux biome has null bath!")
		assert(market_biome.bath != null, "Market biome has null bath!")
		assert(forest_biome.bath != null, "Forest biome has null bath!")
		assert(kitchen_biome.bath != null, "Kitchen biome has null bath!")

	print("  ✓ Farm setup finalized")


## Called by BootManager in Stage 3D to enable simulation processing
func enable_simulation() -> void:
	"""Enable the farm simulation to start processing quantum evolution.

	Called by BootManager.boot() after UI is initialized.
	This enables _process() to evolve quantum states in biomes.
	"""
	set_process(true)

	# Enable biome processing
	if biome_enabled:
		if biotic_flux_biome:
			biotic_flux_biome.set_process(true)
		if market_biome:
			market_biome.set_process(true)
		if forest_biome:
			forest_biome.set_process(true)
		if kitchen_biome:
			kitchen_biome.set_process(true)
		print("  ✓ All biome processing enabled")

	print("  ✓ Farm simulation process enabled")


func _process(delta: float):
	"""Handle passive effects like mushroom composting and grid processing"""
	# Process grid (mills, markets, kitchens, etc.)
	if grid:
		grid._process(delta)

	# Handle passive composting
	_process_mushroom_composting(delta)


func _process_mushroom_composting(delta: float):
	"""Passive composting: converts detritus → mushrooms based on planted mushroom count

	Composting rate scales with number of planted mushrooms
	Ratio: 2 detritus → 1 mushroom
	"""
	if not economy or not grid:
		return

	# Count planted mushrooms to determine composting power
	var mushroom_count = 0
	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var plot = grid.get_plot(Vector2i(x, y))
			if plot and plot.is_planted and plot.plot_type == FarmPlot.PlotType.MUSHROOM:
				mushroom_count += 1

	if mushroom_count == 0:
		return  # No composting without mushrooms

	# Only compost if we have detritus
	var detritus_amount = economy.get_resource("🍂")
	if detritus_amount <= 0:
		return

	# Composting parameters
	const COMPOSTING_RATE = 1.0  # 1 detritus per second per mushroom
	const COMPOSTING_RATIO = 0.5  # 2 detritus → 1 mushroom

	# Calculate composting power (scales with mushroom count)
	var activation = min(1.0, float(mushroom_count) / 4.0)  # Full power at 4 mushrooms
	var detritus_per_frame = COMPOSTING_RATE * activation * delta

	# Accumulate fractional detritus
	if not has_meta("composting_accumulator"):
		set_meta("composting_accumulator", 0.0)

	var accumulator = get_meta("composting_accumulator") + detritus_per_frame

	# Only convert when we've accumulated at least 2 detritus (makes 1 mushroom)
	if accumulator < 2.0:
		set_meta("composting_accumulator", accumulator)
		return

	# Convert accumulated detritus → mushrooms at 2:1 ratio
	var detritus_to_convert = int(accumulator)
	var mushrooms_produced = int(detritus_to_convert * COMPOSTING_RATIO)

	if mushrooms_produced > 0:
		var detritus_consumed = mushrooms_produced * 2  # 2 detritus per mushroom

		# Perform the conversion
		if economy.remove_resource("🍂", detritus_consumed, "composting"):
			economy.add_resource("🍄", mushrooms_produced, "composting")
			# Reset accumulator, keeping remainder
			set_meta("composting_accumulator", accumulator - detritus_consumed)

			if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_ECONOMY") == "1":
				print("🍄 Composting: %d 🍂 → %d 🍄 (%.1f%% activation, %d mushrooms planted)" % [detritus_consumed, mushrooms_produced, activation * 100, mushroom_count])
		else:
			# Conversion failed, keep accumulator for next frame
			set_meta("composting_accumulator", accumulator)


## GRID CONFIGURATION (Phase 2)

func _create_grid_config() -> GridConfig:
	"""Create grid configuration - single source of truth for layout"""
	var config = GridConfig.new()
	config.grid_width = 6
	config.grid_height = 2

	# Create keyboard layout configuration
	var keyboard = KeyboardLayoutConfig.new()

	# Row 0: TYUIOP → left-to-right grid positions (0,0) through (5,0)
	var row0_keys = ["t", "y", "u", "i", "o", "p"]
	for i in range(6):
		var pos = Vector2i(i, 0)
		keyboard.action_to_position["select_plot_" + row0_keys[i]] = pos
		keyboard.position_to_label[pos] = row0_keys[i].to_upper()

	# Row 1: 7890-= → left-to-right grid positions (0,1) through (5,1)
	var row1_keys = ["7", "8", "9", "0"]
	for i in range(4):
		var pos = Vector2i(i, 1)
		keyboard.action_to_position["select_plot_" + row1_keys[i]] = pos
		keyboard.position_to_label[pos] = row1_keys[i]

	# Kitchen keys: , and .
	var kitchen_keys = [",", "."]
	for i in range(2):
		var pos = Vector2i(4 + i, 1)
		keyboard.action_to_position["select_plot_" + kitchen_keys[i]] = pos
		keyboard.position_to_label[pos] = kitchen_keys[i]

	# NOTE: Removed confusing parametric position overrides
	# Keyboard now matches grid in simple left-to-right order:
	#   Row 0: T=0, Y=1, U=2, I=3, O=4, P=5
	#   Row 1: 7=0, 8=1, 9=2, 0=3, -=4, ==5

	config.keyboard_layout = keyboard

	# =========================================================================
	# PLOT CONFIGURATIONS - Simple logical positions
	# Biomes handle their own visual arrangement
	# =========================================================================

	# Market (TY) - positions (0,0), (1,0)
	for i in range(2):
		var plot = PlotConfig.new()
		plot.position = Vector2i(i, 0)
		plot.is_active = true
		plot.keyboard_label = row0_keys[i].to_upper()  # T, Y
		plot.input_action = "select_plot_" + row0_keys[i]
		plot.biome_name = "Market"
		config.plots.append(plot)

	# BioticFlux (UIOP) - positions (2,0), (3,0), (4,0), (5,0)
	for i in range(4):
		var plot = PlotConfig.new()
		plot.position = Vector2i(2 + i, 0)
		plot.is_active = true
		plot.keyboard_label = row0_keys[2 + i].to_upper()  # U, I, O, P
		plot.input_action = "select_plot_" + row0_keys[2 + i]
		plot.biome_name = "BioticFlux"
		config.plots.append(plot)

	# Forest (7890) - positions (0,1), (1,1), (2,1), (3,1)
	for i in range(4):
		var plot = PlotConfig.new()
		plot.position = Vector2i(i, 1)
		plot.is_active = true
		plot.keyboard_label = row1_keys[i]  # 7, 8, 9, 0
		plot.input_action = "select_plot_" + row1_keys[i]
		plot.biome_name = "Forest"
		config.plots.append(plot)

	# Kitchen (positions 4,1 and 5,1) - using keys ',' and '.'
	# Reusing kitchen_keys declared above
	for i in range(2):
		var plot = PlotConfig.new()
		plot.position = Vector2i(4 + i, 1)
		plot.is_active = true  # Changed from false
		plot.keyboard_label = kitchen_keys[i]
		plot.input_action = "select_plot_" + kitchen_keys[i]
		plot.biome_name = "Kitchen"
		config.plots.append(plot)

	# Set up biome assignments
	config.biome_assignments[Vector2i(0, 0)] = "Market"
	config.biome_assignments[Vector2i(1, 0)] = "Market"
	config.biome_assignments[Vector2i(2, 0)] = "BioticFlux"
	config.biome_assignments[Vector2i(3, 0)] = "BioticFlux"
	config.biome_assignments[Vector2i(4, 0)] = "BioticFlux"
	config.biome_assignments[Vector2i(5, 0)] = "BioticFlux"
	config.biome_assignments[Vector2i(0, 1)] = "Forest"
	config.biome_assignments[Vector2i(1, 1)] = "Forest"
	config.biome_assignments[Vector2i(2, 1)] = "Forest"
	config.biome_assignments[Vector2i(3, 1)] = "Forest"
	config.biome_assignments[Vector2i(4, 1)] = "Kitchen"
	config.biome_assignments[Vector2i(5, 1)] = "Kitchen"

	return config


## Public API - Game Operations

func build(pos: Vector2i, build_type: String) -> bool:
	"""Build/plant at position - unified method for all types

	Returns: true if successful, false if failed
	Emits: action_result signal with success/failure message
	"""
	# Validate build type
	if not BUILD_CONFIGS.has(build_type):
		action_result.emit("build", false, "Unknown build type: %s" % build_type)
		return false

	var config = BUILD_CONFIGS[build_type]
	var cost = config["cost"]

	# 1. PRE-VALIDATION: Check if we can build here (skip for gather actions)
	var plot = grid.get_plot(pos)
	if config["type"] != "gather":
		if not plot or plot.is_planted:
			var reason = "Plot already occupied!"
			action_result.emit("build_%s" % build_type, false, reason)
			action_rejected.emit("build_%s" % build_type, pos, reason)
			return false

	# 1b. BIOME VALIDATION: Check if gather action is in correct biome
	if config.has("biome_required"):
		# Get biome name from plot_biome_assignments (in grid)
		var biome_name = ""
		if grid and grid.plot_biome_assignments.has(pos):
			biome_name = grid.plot_biome_assignments[pos]
		if biome_name != config["biome_required"]:
			var reason = "Must be in %s biome!" % config["biome_required"]
			action_result.emit("build_%s" % build_type, false, reason)
			action_rejected.emit("build_%s" % build_type, pos, reason)
			return false

	# 2. ECONOMY CHECK: Can we afford it?
	if not _can_afford_cost(cost):
		var missing = _get_missing_resources(cost)
		var reason = "Cannot afford! Missing: %s" % missing
		action_result.emit("build_%s" % build_type, false, reason)
		action_rejected.emit("build_%s" % build_type, pos, reason)
		return false

	# 3. DEDUCT COST
	_spend_resources(cost, build_type)

	# 4. EXECUTE BUILD
	var success = false
	match config["type"]:
		"plant":
			# Bath-first mode: Don't pre-create qubit, let grid.plant() handle it
			# This ensures BasePlot.plant() uses the new API path which calls
			# biome.create_projection() and properly registers in active_projections
			success = grid.plant(pos, config["plant_type"])
		"build":
			# Route to specific building
			match build_type:
				"mill":
					success = grid.place_mill(pos)
				"market":
					success = grid.place_market(pos)
				"kitchen":
					success = grid.place_kitchen(pos)
				"energy_tap":
					# Energy tap requires target emoji - not supported in simple build() API
					# Use grid.plant_energy_tap(pos, target_emoji) directly instead
					print("⚠️  energy_tap requires target emoji - use grid.plant_energy_tap() instead")
					success = false
		"gather":
			# Gather resources directly from environment
			if config.has("yields"):
				for emoji in config["yields"]:
					var amount = config["yields"][emoji]
					economy.add_resource(emoji, amount * 10, "gather_%s" % build_type)  # Convert to credits
				success = true

	if success:
		print("🌱 Farm: Emitting plot_planted signal for %s at %s" % [build_type, pos])
		plot_planted.emit(pos, build_type)
		_emit_state_changed()
		action_result.emit("build_%s" % build_type, true, "%s placed successfully!" % build_type.capitalize())
		return true
	else:
		# Refund if operation failed, and clean up quantum state if created
		if config["type"] == "plant":
			var plot_biome = _get_plot_biome(pos)
			if plot_biome and plot_biome.has_method("clear_qubit"):
				plot_biome.clear_qubit(pos)
		_refund_resources(cost)
		action_result.emit("build_%s" % build_type, false, "Failed to place %s" % build_type)
		return false


func do_action(action: String, params: Dictionary) -> Dictionary:
	"""Universal action dispatcher - routes to appropriate method

	Supported actions:
	- plant: {position, plant_type} → plants at position
	- entangle: {position_a, position_b} → entangles two plots
	- measure: {position} → measures plot
	- harvest: {position} → harvests plot

	Returns: Dictionary with {success: bool, message: String, ...action-specific data}
	"""
	match action:
		"plant":
			var pos = params.get("position", Vector2i.ZERO)
			var plant_type = params.get("plant_type", "wheat")
			var success = build(pos, plant_type)
			return {
				"success": success,
				"position": pos,
				"plant_type": plant_type,
				"message": "Plant action " + ("succeeded" if success else "failed")
			}

		"entangle":
			var pos_a = params.get("position_a", Vector2i.ZERO)
			var pos_b = params.get("position_b", Vector2i.ZERO)
			var bell_state = params.get("bell_state", "phi_plus")
			var success = entangle_plots(pos_a, pos_b, bell_state)
			return {
				"success": success,
				"position_a": pos_a,
				"position_b": pos_b,
				"bell_state": bell_state,
				"message": "Entangle action " + ("succeeded" if success else "failed")
			}

		"measure":
			var pos = params.get("position", Vector2i.ZERO)
			var outcome = measure_plot(pos)
			return {
				"success": outcome != "",
				"position": pos,
				"outcome": outcome,
				"message": "Measured: " + outcome if outcome else "Measurement failed"
			}

		"harvest":
			var pos = params.get("position", Vector2i.ZERO)
			var result = harvest_plot(pos)
			result["message"] = "Harvest " + ("succeeded" if result.get("success", false) else "failed")
			return result


		_:
			return {
				"success": false,
				"message": "Unknown action: %s" % action
			}


func measure_plot(pos: Vector2i) -> String:
	"""Measure (collapse) quantum state of plot at position

	Returns: outcome emoji (e.g., "🌾", "👥", "🍄", "🍂")
	Emits: plot_measured signal
	"""
	if not grid:
		return ""

	var outcome = grid.measure_plot(pos)

	# No biome mode: use random outcome for testing (no quantum evolution happened)
	if not outcome and not biome_enabled:
		outcome = "🌾" if randf() > 0.5 else "👥"

	plot_measured.emit(pos, outcome)
	_emit_state_changed()
	action_result.emit("measure", true, "Measured: %s collapsed!" % outcome)
	return outcome


func harvest_plot(pos: Vector2i) -> Dictionary:
	"""Harvest measured plot - collect yield

	Returns: Dictionary with {success: bool, outcome: String, yield: int}
	Emits: plot_harvested signal with yield data
	"""
	if not grid or not economy:
		return {"success": false}

	var plot = grid.get_plot(pos)
	if not plot or not plot.is_planted:
		action_result.emit("harvest", false, "Plot not ready to harvest")
		return {"success": false}

	# Note: has_been_measured check removed - BasePlot.harvest() handles auto-measure
	var harvest_data = grid.harvest_wheat(pos)

	if harvest_data.get("success", false):
		# Route resources based on outcome
		_process_harvest_outcome(harvest_data)
		plot_harvested.emit(pos, harvest_data)
		_emit_state_changed()

		var emoji = harvest_data.get("outcome", "?")
		action_result.emit("harvest", true, "Harvested %d %s!" % [harvest_data.get("yield", 0), emoji])
	else:
		action_result.emit("harvest", false, "Harvest failed")

	return harvest_data


func measure_all() -> int:
	"""Measure all planted but unmeasured plots

	Returns: number of plots measured
	"""
	var measured_count = 0

	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)

			if plot and plot.is_planted and not plot.has_been_measured:
				measure_plot(pos)
				measured_count += 1

	action_result.emit("measure_all", true, "Measured %d plots" % measured_count)
	return measured_count


func harvest_all() -> int:
	"""Harvest all measured plots

	Returns: number of plots harvested
	"""
	var harvested_count = 0

	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)

			if plot and plot.is_planted and plot.has_been_measured:
				var result = harvest_plot(pos)
				if result.get("success", false):
					harvested_count += 1

	action_result.emit("harvest_all", true, "Harvested %d plots" % harvested_count)
	return harvested_count


func entangle_plots(pos1: Vector2i, pos2: Vector2i, bell_state: String = "phi_plus") -> bool:
	"""Create entanglement between two plots with specified Bell state

	Args:
		pos1: Grid position of first plot
		pos2: Grid position of second plot
		bell_state: "phi_plus" (same correlation), "psi_plus" (opposite correlation)

	Returns:
		bool: True if successful, False if failed

	Emits: plots_entangled signal on success
	"""
	if not grid:
		action_result.emit("entangle", false, "Farm grid not initialized")
		return false

	# Verify both plots exist and are planted
	var plot1 = grid.get_plot(pos1)
	var plot2 = grid.get_plot(pos2)

	if not plot1 or not plot1.is_planted:
		action_result.emit("entangle", false, "First plot must be planted!")
		return false

	if not plot2 or not plot2.is_planted:
		action_result.emit("entangle", false, "Second plot must be planted!")
		return false

	# Create the entanglement in the grid
	var result = grid.create_entanglement(pos1, pos2, bell_state)

	if result:
		# Emit entanglement signal
		plots_entangled.emit(pos1, pos2, bell_state)
		_emit_state_changed()

		# Track entanglement for achievements (Bug #9 fix)
		if goals:
			goals.record_entanglement()

		var state_name = "same correlation (Φ+)" if bell_state == "phi_plus" else "opposite correlation (Ψ+)"
		action_result.emit("entangle", true, "🔗 Entangled %s ↔ %s (%s)" % [pos1, pos2, state_name])
		return true
	else:
		action_result.emit("entangle", false, "Failed to create entanglement")
		return false


## Batch Operation Methods (Multi-Select Support)
## De-slopped: Common loop+result pattern extracted to _batch_operation()

func _batch_operation(positions: Array[Vector2i], operation_name: String, operation: Callable) -> Dictionary:
	"""Execute an operation on multiple positions with unified result structure.

	Args:
		positions: Array of grid positions to operate on
		operation_name: Name for message (e.g., "Planted", "Measured")
		operation: Callable that takes position and returns bool (success)

	Returns: Dictionary with {success: bool, count: int, message: String}
	"""
	var result = {"success": false, "count": 0, "message": ""}

	if positions.is_empty():
		result["message"] = "No positions specified"
		return result

	var success_count = 0
	for pos in positions:
		if operation.call(pos):
			success_count += 1

	result["success"] = success_count > 0
	result["count"] = success_count
	result["message"] = "%s %d/%d plots" % [operation_name, success_count, positions.size()]
	return result


func batch_plant(positions: Array[Vector2i], plant_type: String) -> Dictionary:
	"""Plant multiple plots with the given plant type."""
	return _batch_operation(positions, "Planted", func(pos): return build(pos, plant_type))


func batch_measure(positions: Array[Vector2i]) -> Dictionary:
	"""Measure quantum state of multiple plots."""
	return _batch_operation(positions, "Measured", func(pos): return measure_plot(pos) != "")


func batch_harvest(positions: Array[Vector2i]) -> Dictionary:
	"""Harvest multiple plots (measure then harvest each).

	Returns: Dictionary with {success, count, message, total_yield}
	"""
	var total_yield = 0

	# Custom operation that measures first, then harvests
	var harvest_op = func(pos: Vector2i) -> bool:
		var plot = grid.get_plot(pos)
		if plot and plot.is_planted and not plot.has_been_measured:
			measure_plot(pos)
		var harvest_result = harvest_plot(pos)
		if harvest_result.get("success", false):
			total_yield += harvest_result.get("yield", 0)
			return true
		return false

	var result = _batch_operation(positions, "Harvested", harvest_op)
	result["total_yield"] = total_yield
	return result


func batch_build(positions: Array[Vector2i], build_type: String) -> Dictionary:
	"""Build structures (mill, market, kitchen) on multiple plots."""
	return _batch_operation(positions, "Built", func(pos): return build(pos, build_type))


func get_plot(position: Vector2i):
	"""Get plot at given grid position (returns FarmPlot or subclass)"""
	if grid:
		return grid.get_plot(position)
	return null


func get_state() -> Dictionary:
	"""Get complete game state snapshot for serialization"""
	if not grid or not economy or not goals:
		return {}

	var state = {
		"economy": {
			"wheat": economy.get_resource("🌾"),
			"flour": economy.get_resource("💨"),
			"flower": economy.get_resource("🌻"),
			"labor": economy.get_resource("👥"),
			"mushroom": economy.get_resource("🍄"),
			"detritus": economy.get_resource("🍂"),
			"credits": economy.get_resource("💰"),
		},
		"plots": []
	}

	# Collect all plot states
	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)
			if plot:
				state["plots"].append({
					"position": pos,
					"is_planted": plot.is_planted,
					"emoji": plot.get_semantic_emoji() if plot.is_planted else ""
				})

	return state


func apply_state(state: Dictionary) -> void:
	"""Apply complete game state from snapshot"""
	if not grid or not economy:
		return

	# Apply economy state
	if state.has("economy"):
		var eco = state["economy"]
		economy.wheat_inventory = eco.get("wheat", 100)
		economy.flour_inventory = eco.get("flour", 0)
		economy.flower_inventory = eco.get("flower", 0)
		economy.labor_inventory = eco.get("labor", 0)

		# Emit signals so UI updates
		economy.wheat_changed.emit(economy.wheat_inventory)
		economy.flour_changed.emit(economy.flour_inventory)
		economy.flower_changed.emit(economy.flower_inventory)
		economy.labor_changed.emit(economy.labor_inventory)

	# Apply plot states
	if state.has("plots"):
		for plot_state in state["plots"]:
			var pos = plot_state.get("position")
			var plot = grid.get_plot(pos)
			if plot and plot_state.get("is_planted", false):
				# Recreate wheat at this position
				plot.plant()

	_emit_state_changed()


## GameState Integration - Clean Architecture Methods

func apply_game_state(state: Resource) -> void:
	"""Load a GameState into the simulation (clean architecture pattern)

	Args:
		state: GameState resource with all persistent game data

	Sets up the entire simulation from saved state:
	- Economy: wheat inventory (primary currency)
	- Plots: planted state, measurement state, quantum properties
	- Environment: sun/moon phase
	"""
	if not state:
		push_error("Cannot apply null game state")
		return

	if not (grid and economy and biome_enabled):
		push_error("Farm systems not initialized")
		return

	# Apply economy
	economy.wheat_inventory = state.get("wheat_inventory") if state.has("wheat_inventory") else 100
	economy.flour_inventory = state.get("flour_inventory") if state.has("flour_inventory") else 0

	# Emit economy change signals so UI updates
	economy.wheat_changed.emit(economy.wheat_inventory)
	economy.flour_changed.emit(economy.flour_inventory)

	# Apply plots
	var plots_array = state.get("plots") if state.has("plots") else []
	for plot_data in plots_array:
		var pos = plot_data.get("position") if plot_data.has("position") else Vector2i.ZERO
		var plot = grid.get_plot(pos)

		if plot:
			plot.is_planted = plot_data.get("is_planted") if plot_data.has("is_planted") else false
			plot.has_been_measured = plot_data.get("has_been_measured") if plot_data.has("has_been_measured") else false
			plot.theta_frozen = plot_data.get("theta_frozen") if plot_data.has("theta_frozen") else false

			# Regenerate quantum state if planted
			if plot.is_planted:
				var plot_biome = grid.get_biome_for_plot(pos)
				if plot_biome and not plot_biome.quantum_states.has(pos):
					var qubit = plot_biome.create_quantum_state(pos, "🌾", "🌱", PI/2)

	# Apply environment (sun & icons) - BioticFlux specific
	if biotic_flux_biome and biotic_flux_biome.sun_qubit:
		biotic_flux_biome.sun_qubit.theta = state.get("sun_theta") if state.has("sun_theta") else 0.0
		biotic_flux_biome.sun_qubit.phi = state.get("sun_phi") if state.has("sun_phi") else 0.0
	if biotic_flux_biome and biotic_flux_biome.wheat_icon:
		biotic_flux_biome.wheat_icon.theta = state.get("wheat_icon_theta") if state.has("wheat_icon_theta") else PI/12

	_emit_state_changed()


func capture_game_state(state: Resource) -> Resource:
	"""Save current simulation state to a GameState (clean architecture pattern)

	Args:
		state: GameState resource to update with current simulation state

	Captures:
	- Economy: current wheat inventory (primary currency)
	- Plots: current planted/measured/entangled states for all plots
	- Environment: current sun/moon phase

	Returns: The updated GameState resource
	"""
	if not state:
		push_error("Cannot capture to null game state")
		return state

	if not (grid and economy and biome_enabled):
		push_error("Farm systems not initialized")
		return state

	# Capture economy
	state["wheat_inventory"] = economy.wheat_inventory
	state["flour_inventory"] = economy.flour_inventory

	# Capture plots
	var plots_array = []
	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)

			if plot:
				plots_array.append({
					"position": pos,
					"type": 0,
					"is_planted": plot.is_planted,
					"has_been_measured": plot.has_been_measured,
					"theta_frozen": plot.theta_frozen,
					"entangled_with": []
				})

	state["plots"] = plots_array

	# Capture environment (sun & icons) - BioticFlux specific
	if biotic_flux_biome and biotic_flux_biome.sun_qubit:
		state["sun_theta"] = biotic_flux_biome.sun_qubit.theta
		state["sun_phi"] = biotic_flux_biome.sun_qubit.phi
	if biotic_flux_biome and biotic_flux_biome.wheat_icon:
		state["wheat_icon_theta"] = biotic_flux_biome.wheat_icon.theta

	return state


## Private Helpers - Biome Access

func _get_plot_biome(pos: Vector2i):
	"""Get biome for plot position. Returns null if biomes disabled or not found."""
	if biome_enabled and grid:
		return grid.get_biome_for_plot(pos)
	return null


func _ensure_iconregistry() -> void:
	"""Ensure IconRegistry exists (for test mode where autoloads don't exist)

	In normal gameplay: IconRegistry is autoload at /root/IconRegistry
	In test mode (extends SceneTree): Autoloads don't exist, create fallback
	"""
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if icon_registry:
		# Already exists (normal game mode)
		return

	# Test mode: Create IconRegistry
	var IconRegistryScript = load("res://Core/QuantumSubstrate/IconRegistry.gd")
	if not IconRegistryScript:
		push_error("Failed to load IconRegistry.gd!")
		return

	icon_registry = IconRegistryScript.new()
	icon_registry.name = "IconRegistry"
	# Use get_tree() if available (normal mode), otherwise use SceneTree's root
	var tree_root = get_tree().root if has_method("get_tree") else get_node("/root")
	tree_root.add_child(icon_registry)
	icon_registry._ready()  # Trigger initialization
	print("✓ Test mode: IconRegistry initialized with %d icons" % icon_registry.icons.size())


## Private Helpers - Resource & Economy Management
## Now uses FarmEconomy's unified emoji-credits API

func _can_afford_cost(cost: Dictionary) -> bool:
	"""Check if player can afford emoji-credits cost."""
	return economy.can_afford_cost(cost)


func _get_missing_resources(cost: Dictionary) -> String:
	"""Get human-readable list of missing resources."""
	var missing = []
	for emoji in cost.keys():
		var need = cost[emoji]
		var have = economy.get_resource(emoji)
		if have < need:
			var shortfall = (need - have) / FarmEconomy.QUANTUM_TO_CREDITS
			missing.append("%d more %s" % [shortfall, emoji])
	return ", ".join(missing)


func _spend_resources(cost: Dictionary, action: String) -> void:
	"""Deduct emoji-credits from economy."""
	economy.spend_cost(cost, action)


func _refund_resources(cost: Dictionary) -> void:
	"""Return emoji-credits to player (failed operation)."""
	for emoji in cost.keys():
		economy.add_resource(emoji, cost[emoji], "refund")


func _process_harvest_outcome(harvest_data: Dictionary) -> void:
	"""Route harvested resources to economy - generic emoji routing"""
	var outcome_emoji = harvest_data.get("outcome", "")
	var quantum_energy = harvest_data.get("energy", 0.0)

	# Fallback: if energy not provided, use yield * 0.1 (inverse of QUANTUM_TO_CREDITS)
	if quantum_energy == 0.0:
		var yield_amount = harvest_data.get("yield", 1)
		quantum_energy = float(yield_amount) / float(FarmEconomy.QUANTUM_TO_CREDITS)

	if outcome_emoji.is_empty():
		return

	# Generic routing: any emoji → its credits
	var credits_earned = economy.receive_harvest(outcome_emoji, quantum_energy, "harvest")

	# Goal tracking for wheat (track credits earned, not units)
	if outcome_emoji == "🌾":
		goals.record_harvest(credits_earned)


func _emit_state_changed() -> void:
	"""Emit state_changed signal with current game state"""
	state_changed.emit(get_state())


func _on_economy_changed(_value) -> void:
	"""Handle economy signal"""
	_emit_state_changed()


func _on_goal_completed(_goal) -> void:
	"""Handle goal completion"""
	_emit_state_changed()


## UI State Integration (Phase 2)

func _on_economy_changed_ui(_value = null) -> void:
	"""Handle economy changes - update UIState"""
	if ui_state:
		ui_state.update_economy(economy)


func _on_plot_measured_ui(position: Vector2i, outcome: String) -> void:
	"""Handle measurement - update UIState with measured outcome"""
	if ui_state and grid:
		var plot = grid.get_plot(position)
		if plot:
			ui_state.update_plot(position, plot)


func _on_plot_changed_ui(position: Vector2i, _data = null) -> void:
	"""Handle plot changes - update UIState"""
	if ui_state and grid:
		var plot = grid.get_plot(position)
		if plot:
			ui_state.update_plot(position, plot)
