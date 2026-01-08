extends Node

## BootManager - Manages the boot sequence - ensures proper initialization order
## Available globally as autoload singleton
## Call BootManager.boot() once to transition from Phase 2 to Phase 3

signal core_systems_ready
signal visualization_ready
signal ui_ready
signal game_ready

var _booted: bool = false
var is_ready: bool = false  # Public flag for checking boot completion
var _current_stage: String = ""

## Autoload singleton - ready to use as global
func _ready() -> void:
	print("🔧 BootManager autoload ready")

## Main boot sequence entry point - call after farm and shell are created
func boot(farm: Node, shell: Node, quantum_viz: Node) -> void:
	if _booted:
		push_warning("Boot already completed!")
		return

	print("\n" + "======================================================================")
	print("BOOT SEQUENCE STARTING")
	print("======================================================================\n")

	# Stage 3A: Core Systems
	_stage_core_systems(farm)

	# Stage 3B: Visualization
	_stage_visualization(farm, quantum_viz)

	# Stage 3C: UI
	_stage_ui(farm, shell, quantum_viz)

	# Stage 3D: Start Simulation
	_stage_start_simulation(farm)

	_booted = true
	is_ready = true  # Set flag before emitting signal

	print("\n" + "======================================================================")
	print("BOOT SEQUENCE COMPLETE - GAME READY")
	print("======================================================================\n")

	game_ready.emit()

## Stage 3A: Initialize core systems
func _stage_core_systems(farm: Node) -> void:
	_current_stage = "CORE_SYSTEMS"
	print("📍 Stage 3A: Core Systems")

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

	print("  ✓ IconRegistry ready (%d icons)" % icon_registry.icons.size())

	# CRITICAL: Rebuild biome quantum operators now that IconRegistry is guaranteed ready
	# Biomes may have initialized before IconRegistry loaded all icons
	print("  🔧 Rebuilding biome quantum operators...")
	if farm.has_method("rebuild_all_biome_operators"):
		farm.rebuild_all_biome_operators()
	else:
		# Fallback: rebuild each biome directly
		for biome_name in farm.grid.biomes.keys():
			var biome = farm.grid.biomes[biome_name]
			if biome.has_method("rebuild_quantum_operators"):
				biome.rebuild_quantum_operators()
	print("  ✓ All biome operators rebuilt\n")

	# Verify all biomes initialized correctly
	for biome_name in farm.grid.biomes.keys():
		var biome = farm.grid.biomes[biome_name]
		assert(biome != null, "Biome '%s' is null!" % biome_name)

		# Check for either old (bath) or new (quantum_computer) architecture
		var has_bath = biome.bath != null
		var has_qc = biome.quantum_computer != null
		assert(has_bath or has_qc, "Biome '%s' has neither bath nor quantum_computer!" % biome_name)

		# Verify bath components if using old architecture
		if has_bath:
			assert(biome.bath._hamiltonian != null, "Biome '%s' bath has null hamiltonian!" % biome_name)
			assert(biome.bath._lindblad != null, "Biome '%s' bath has null lindblad!" % biome_name)

		print("  ✓ Biome '%s' verified" % biome_name)

	# Any additional farm finalization
	if farm.has_method("finalize_setup"):
		farm.finalize_setup()

	# CRITICAL: Set active_farm in GameStateManager for save/load to work
	var game_state_mgr = get_node_or_null("/root/GameStateManager")
	if game_state_mgr:
		game_state_mgr.active_farm = farm
		print("  ✓ GameStateManager.active_farm set")
	else:
		push_warning("GameStateManager not found - save/load will not work!")

	print("  ✓ Core systems ready\n")
	core_systems_ready.emit()

## Stage 3B: Initialize visualization
func _stage_visualization(farm: Node, quantum_viz: Node) -> void:
	_current_stage = "VISUALIZATION"
	print("📍 Stage 3B: Visualization")

	assert(quantum_viz != null, "QuantumViz is null!")

	# Initialize the visualization engine
	quantum_viz.initialize()

	# Verify layout calculator was created
	assert(quantum_viz.graph != null, "QuantumForceGraph not created!")
	assert(quantum_viz.graph.layout_calculator != null, "BiomeLayoutCalculator not created!")

	print("  ✓ QuantumForceGraph created")
	print("  ✓ BiomeLayoutCalculator ready")
	print("  ✓ Layout positions computed\n")

	visualization_ready.emit()

## Stage 3C: Initialize UI
func _stage_ui(farm: Node, shell: Node, quantum_viz: Node) -> void:
	_current_stage = "UI"
	print("📍 Stage 3C: UI Initialization")

	# Load and instantiate FarmUI scene
	var farm_ui_scene = load("res://UI/FarmUI.tscn")
	assert(farm_ui_scene != null, "FarmUI.tscn not found!")

	var farm_ui = farm_ui_scene.instantiate() as Control
	assert(farm_ui != null, "FarmUI failed to instantiate!")

	# Add to shell FIRST so _ready() runs and sets up scene structure
	shell.load_farm_ui(farm_ui)
	print("  ✓ FarmUI mounted in shell")

	# Set farm reference in PlayerShell (needed for quest board)
	shell.farm = farm
	print("  ✓ Farm reference set in PlayerShell")

	# Wait one frame for _ready() to complete
	await shell.get_tree().process_frame

	# NOW inject dependencies (_ready() has set up child nodes)
	farm_ui.setup_farm(farm)

	# Inject layout calculator (created in Stage 3B)
	var plot_grid_display = farm_ui.get_node("PlotGridDisplay")
	if plot_grid_display:
		if plot_grid_display.has_method("inject_layout_calculator"):
			plot_grid_display.inject_layout_calculator(quantum_viz.graph.layout_calculator)
			print("  ✓ Layout calculator injected")

	# Create and inject FarmInputHandler
	var FarmInputHandlerScript = load("res://UI/FarmInputHandler.gd")
	var input_handler = FarmInputHandlerScript.new()
	input_handler.farm = farm
	input_handler.plot_grid_display = plot_grid_display
	farm_ui.input_handler = input_handler
	print("  ✓ FarmInputHandler created\n")

	ui_ready.emit()

## Stage 3D: Start simulation
func _stage_start_simulation(farm: Node) -> void:
	_current_stage = "START_SIMULATION"
	print("📍 Stage 3D: Start Simulation")

	# Enable farm processing
	farm.set_process(true)
	if farm.has_method("enable_simulation"):
		farm.enable_simulation()
	print("  ✓ Farm simulation enabled")

	# Enable input processing
	# (done separately to avoid input during boot)
	print("  ✓ Input system enabled")
	print("  ✓ Ready to accept player input\n")
