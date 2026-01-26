extends Node

## BootManager - Manages the boot sequence - ensures proper initialization order
## Available globally as autoload singleton
## Call BootManager.boot() once to transition from Phase 2 to Phase 3

# Access autoloads safely
@onready var _verbose = get_node("/root/VerboseConfig")

signal core_systems_ready
signal visualization_ready
signal ui_ready
signal game_ready

var _booted: bool = false
var is_ready: bool = false  # Public flag for checking boot completion
var _current_stage: String = ""

## Autoload singleton - ready to use as global
func _ready() -> void:
	_verbose.info("boot", "🔧", "BootManager autoload ready")

## Main boot sequence entry point - call after farm and shell are created
func boot(farm: Node, shell: Node, quantum_viz: Node) -> void:
	if _booted:
		push_warning("Boot already completed!")
		return

	_verbose.info("boot", "🚀", "======================================================================")
	_verbose.info("boot", "🚀", "BOOT SEQUENCE STARTING")
	_verbose.info("boot", "🚀", "======================================================================")

	# Stage 3A: Core Systems
	_stage_core_systems(farm)

	# Stage 3B: Visualization
	_stage_visualization(farm, quantum_viz)

	# Stage 3C: UI (async - must await to ensure FarmInputHandler is created)
	await _stage_ui(farm, shell, quantum_viz)

	# Stage 3D: Start Simulation
	_stage_start_simulation(farm)

	_booted = true
	is_ready = true  # Set flag before emitting signal

	_verbose.info("boot", "✅", "======================================================================")
	_verbose.info("boot", "✅", "BOOT SEQUENCE COMPLETE - GAME READY")
	_verbose.info("boot", "✅", "======================================================================")

	game_ready.emit()

## Stage 3A: Initialize core systems
func _stage_core_systems(farm: Node) -> void:
	_current_stage = "CORE_SYSTEMS"
	_verbose.info("boot", "📍", "Stage 3A: Core Systems")

	# Verify all required components exist
	assert(farm != null, "Farm is null!")
	assert(farm.grid != null, "Farm.grid is null!")
	assert(farm.grid.biomes != null, "Farm.grid.biomes is null!")

	# Verify IconRegistry is available and fully loaded
	var icon_registry = get_node_or_null("/root/IconRegistry")
	assert(icon_registry != null, "IconRegistry not found! Autoloads not initialized.")

	# Wait for IconRegistry to finish loading if needed
	if icon_registry.icons.size() == 0:
		push_warning("IconRegistry not fully loaded yet, waiting...")
		await get_tree().process_frame

	_verbose.info("boot", "✓", "IconRegistry ready (%d icons)" % icon_registry.icons.size())

	# CRITICAL: Rebuild biome quantum operators now that IconRegistry is guaranteed ready
	# Biomes may have initialized before IconRegistry loaded all icons
	_verbose.info("boot", "🔧", "Rebuilding biome quantum operators...")
	if farm.has_method("rebuild_all_biome_operators"):
		farm.rebuild_all_biome_operators()
	else:
		# Fallback: rebuild each biome directly
		for biome_name in farm.grid.biomes.keys():
			var biome = farm.grid.biomes[biome_name]
			if biome.has_method("rebuild_quantum_operators"):
				biome.rebuild_quantum_operators()
	_verbose.info("boot", "✓", "All biome operators rebuilt")

	# Verify all biomes initialized correctly
	for biome_name in farm.grid.biomes.keys():
		var biome = farm.grid.biomes[biome_name]
		assert(biome != null, "Biome '%s' is null!" % biome_name)
		assert(biome.quantum_computer != null, "Biome '%s' has no quantum_computer!" % biome_name)
		_verbose.info("boot", "✓", "Biome '%s' verified" % biome_name)

	# Any additional farm finalization
	if farm.has_method("finalize_setup"):
		farm.finalize_setup()

	# CRITICAL: Set active_farm in GameStateManager for save/load to work
	var game_state_mgr = get_node_or_null("/root/GameStateManager")
	if game_state_mgr:
		game_state_mgr.active_farm = farm
		_verbose.info("boot", "✓", "GameStateManager.active_farm set")
	else:
		push_warning("GameStateManager not found - save/load will not work!")

	_verbose.info("boot", "✓", "Core systems ready")
	core_systems_ready.emit()

## Stage 3B: Initialize visualization
func _stage_visualization(farm: Node, quantum_viz: Node) -> void:
	_current_stage = "VISUALIZATION"
	_verbose.info("boot", "📍", "Stage 3B: Visualization")

	assert(quantum_viz != null, "QuantumViz is null!")

	# Initialize the visualization engine
	quantum_viz.initialize()

	# Verify layout calculator was created
	assert(quantum_viz.graph != null, "QuantumForceGraph not created!")
	assert(quantum_viz.graph.layout_calculator != null, "BiomeLayoutCalculator not created!")

	_verbose.info("boot", "✓", "QuantumForceGraph created")
	_verbose.info("boot", "✓", "BiomeLayoutCalculator ready")
	_verbose.info("boot", "✓", "Layout positions computed")

	visualization_ready.emit()

## Stage 3C: Initialize UI
func _stage_ui(farm: Node, shell: Node, quantum_viz: Node) -> void:
	_current_stage = "UI"
	_verbose.info("boot", "📍", "Stage 3C: UI Initialization")

	# Load and instantiate FarmUI scene
	var farm_ui_scene = load("res://UI/FarmUI.tscn")
	assert(farm_ui_scene != null, "FarmUI.tscn not found!")

	var farm_ui = farm_ui_scene.instantiate() as Control
	assert(farm_ui != null, "FarmUI failed to instantiate!")

	# Add to shell FIRST so _ready() runs and sets up scene structure
	shell.load_farm_ui(farm_ui)
	_verbose.info("boot", "✓", "FarmUI mounted in shell")

	# Set farm reference in PlayerShell (needed for quest board)
	shell.farm = farm
	_verbose.info("boot", "✓", "Farm reference set in PlayerShell")

	# Wait one frame for _ready() to complete
	await shell.get_tree().process_frame

	# NOW inject dependencies (_ready() has set up child nodes)
	farm_ui.setup_farm(farm)

	# Inject layout calculator (created in Stage 3B)
	var plot_grid_display = farm_ui.get_node("PlotGridDisplay")
	if plot_grid_display:
		if plot_grid_display.has_method("inject_layout_calculator"):
			plot_grid_display.inject_layout_calculator(quantum_viz.graph.layout_calculator)
			_verbose.info("boot", "✓", "Layout calculator injected")

	# Create and inject FarmInputHandler
	# FarmInputHandler extends Node, so we create a generic Node and attach the script
	var input_handler = Node.new()
	var FarmInputHandlerScript = load("res://UI/FarmInputHandler.gd")
	input_handler.set_script(FarmInputHandlerScript)
	input_handler.name = "FarmInputHandler"
	shell.add_child(input_handler)

	input_handler.farm = farm
	input_handler.plot_grid_display = farm_ui.plot_grid_display
	farm_ui.input_handler = input_handler

	# CRITICAL: Inject grid_config (was missing - caused "grid_config is NULL" warnings)
	if farm.grid_config:
		input_handler.inject_grid_config(farm.grid_config)
		_verbose.info("boot", "✓", "GridConfig injected into FarmInputHandler")

	# CRITICAL: Connect input_handler signals to action bar AFTER input_handler exists
	# (farm_setup_complete fires too early, before input_handler is created)
	if shell.has_method("connect_to_farm_input_handler"):
		shell.connect_to_farm_input_handler()
		_verbose.info("boot", "✓", "Input handler connected to action bars")

	# Note: input_handler is a child of shell, accessible via shell.get_node("FarmInputHandler")
	_verbose.info("boot", "✓", "FarmInputHandler created")

	ui_ready.emit()

## Stage 3D: Start simulation
func _stage_start_simulation(farm: Node) -> void:
	_current_stage = "START_SIMULATION"
	_verbose.info("boot", "📍", "Stage 3D: Start Simulation")

	# Enable farm processing
	farm.set_process(true)
	if farm.has_method("enable_simulation"):
		farm.enable_simulation()
	_verbose.info("boot", "✓", "Farm simulation enabled")

	# Enable input processing
	# (done separately to avoid input during boot)
	_verbose.info("boot", "✓", "Input system enabled")
	_verbose.info("boot", "✓", "Ready to accept player input")
