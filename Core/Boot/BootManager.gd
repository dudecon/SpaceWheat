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

	# Stage 3C: UI (async - must await to ensure QuantumInstrumentInput is created)
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

	# Verify required components (hard failures - these are critical)
	assert(farm != null, "Farm is null!")
	assert(farm.grid != null, "Farm.grid is null!")

	# Check biomes gracefully - allow boot to continue without them
	var has_biomes = farm.grid.biomes != null and not farm.grid.biomes.is_empty()
	if not has_biomes:
		_verbose.warn("boot", "⚠️", "No biomes loaded - boot will continue with limited functionality")

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
	if has_biomes:
		_verbose.info("boot", "🔧", "Rebuilding biome quantum operators...")
		if farm.has_method("rebuild_all_biome_operators"):
			farm.rebuild_all_biome_operators()
		else:
			# Fallback: rebuild each biome directly
			for biome_name in farm.grid.biomes.keys():
				var biome = farm.grid.biomes[biome_name]
				if biome and biome.has_method("rebuild_quantum_operators"):
					biome.rebuild_quantum_operators()
		_verbose.info("boot", "✓", "All biome operators rebuilt")

		# Verify all biomes initialized correctly
		for biome_name in farm.grid.biomes.keys():
			var biome = farm.grid.biomes[biome_name]
			if not biome:
				_verbose.warn("boot", "⚠️", "Biome '%s' is null - skipping" % biome_name)
				continue
			if not biome.quantum_computer:
				_verbose.warn("boot", "⚠️", "Biome '%s' has no quantum_computer" % biome_name)
				continue
			_verbose.info("boot", "✓", "Biome '%s' verified" % biome_name)
	else:
		_verbose.info("boot", "⏭️", "Skipping biome operations (no biomes)")

	# Any additional farm finalization
	if farm.has_method("finalize_setup"):
		farm.finalize_setup()

	# Start music after biomes are loaded (no biomes => no music).
	var music = get_node_or_null("/root/MusicManager")
	if music:
		if has_biomes:
			var biome_mgr = get_node_or_null("/root/ActiveBiomeManager")
			var active_biome = biome_mgr.get_active_biome() if biome_mgr and biome_mgr.has_method("get_active_biome") else ""
			if active_biome != "":
				music.play_biome_track(active_biome)
			else:
				music.stop()
		else:
			music.stop()

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

	if not quantum_viz:
		_verbose.warn("boot", "⚠️", "QuantumViz is null - skipping visualization")
		visualization_ready.emit()
		return

	# Initialize the visualization engine (may fail gracefully if no biomes)
	quantum_viz.initialize()

	# Check if graph was created (won't be if no biomes)
	if not quantum_viz.graph:
		_verbose.warn("boot", "⚠️", "QuantumForceGraph not created (no biomes?) - visualization disabled")
		visualization_ready.emit()
		return

	if not quantum_viz.graph.layout_calculator:
		_verbose.warn("boot", "⚠️", "BiomeLayoutCalculator not created - visualization disabled")
		visualization_ready.emit()
		return

	_verbose.info("boot", "✓", "QuantumForceGraph created")
	_verbose.info("boot", "✓", "BiomeLayoutCalculator ready")
	_verbose.info("boot", "✓", "Layout positions computed")

	visualization_ready.emit()

## Stage 3C: Initialize UI
func _stage_ui(farm: Node, shell: Node, quantum_viz: Node) -> void:
	_current_stage = "UI"
	_verbose.info("boot", "📍", "Stage 3C: UI Initialization")

	# Verify shell is a PlayerShell with expected methods
	if not shell.has_method("load_farm_ui"):
		push_error("BootManager: shell is not a PlayerShell! Type: %s, Script: %s" % [
			shell.get_class(),
			shell.get_script().resource_path if shell.get_script() else "no script"
		])
		return

	# Load and instantiate FarmUI scene
	var farm_ui_scene = load("res://UI/FarmUI.tscn")
	assert(farm_ui_scene != null, "FarmUI.tscn not found!")

	var farm_ui = farm_ui_scene.instantiate() as Control
	assert(farm_ui != null, "FarmUI failed to instantiate!")

	# INJECT DEPENDENCIES BEFORE ADD_CHILD
	# This allows PlotGridDisplay._ready() to have all dependencies available,
	# creating tiles synchronously during tree entry (cleaner boot sequence).
	var plot_grid_display = farm_ui.get_node("PlotGridDisplay")
	if plot_grid_display:
		# Inject in order: farm → grid_config → layout_calculator → biomes
		# Tiles are created when biomes is injected (last dependency)
		plot_grid_display.inject_farm(farm)
		plot_grid_display.inject_grid_config(farm.grid_config)

		# Layout calculator may not exist if no biomes were loaded
		if quantum_viz and quantum_viz.graph and quantum_viz.graph.layout_calculator:
			if plot_grid_display.has_method("inject_layout_calculator"):
				plot_grid_display.inject_layout_calculator(quantum_viz.graph.layout_calculator)
		else:
			_verbose.warn("boot", "⚠️", "No layout_calculator available - tiles will use fallback positioning")

		if farm.grid and farm.grid.biomes and not farm.grid.biomes.is_empty():
			plot_grid_display.inject_biomes(farm.grid.biomes)
			_verbose.info("boot", "✓", "PlotGridDisplay dependencies pre-injected")
		else:
			_verbose.warn("boot", "⚠️", "No biomes to inject - PlotGridDisplay will have no tiles")

		# Wire plot positions to QuantumForceGraph for tethering
		if quantum_viz and quantum_viz.graph and plot_grid_display.has_signal("plot_positions_changed"):
			if not plot_grid_display.plot_positions_changed.is_connected(quantum_viz.graph.update_plot_positions):
				plot_grid_display.plot_positions_changed.connect(quantum_viz.graph.update_plot_positions)
				_verbose.info("boot", "📡", "PlotGridDisplay connected to QuantumForceGraph anchors")

	# NOW add to tree - _ready() runs with all dependencies available
	shell.load_farm_ui(farm_ui)
	_verbose.info("boot", "✓", "FarmUI mounted in shell")

	# Set farm reference in PlayerShell (needed for quest board)
	shell.farm = farm
	_verbose.info("boot", "✓", "Farm reference set in PlayerShell")

	# Setup remaining FarmUI parts (ResourcePanel wiring, signal connections)
	# PlotGridDisplay injection is idempotent - guards prevent double tile creation
	farm_ui.setup_farm(farm)

	# Create and inject QuantumInstrumentInput (single input system)
	# Uses the new musical instrument spindle interface for tool groups + fractal navigation
	var input_handler = Node.new()
	var QuantumInstrumentScript = load("res://UI/Core/QuantumInstrumentInput.gd")
	input_handler.set_script(QuantumInstrumentScript)
	input_handler.name = "QuantumInstrumentInput"
	shell.add_child(input_handler)

	# Inject dependencies
	input_handler.inject_farm(farm)
	if plot_grid_display:
		input_handler.inject_plot_grid_display(plot_grid_display)

		# Connect multi-select checkbox signal to PlotGridDisplay
		input_handler.plot_checked.connect(plot_grid_display.set_plot_checked)
		_verbose.info("boot", "✓", "Multi-select checkbox signals connected")
	farm_ui.input_handler = input_handler

	# CRITICAL: Connect input_handler signals to action bar AFTER input_handler exists
	# (farm_setup_complete fires too early, before input_handler is created)
	if shell.has_method("connect_to_quantum_input"):
		shell.connect_to_quantum_input()
		_verbose.info("boot", "✓", "QuantumInstrumentInput connected to action bars")

	_verbose.info("boot", "✓", "QuantumInstrumentInput created (Musical Spindle)")

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
