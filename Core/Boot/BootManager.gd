extends Node

## BootManager - Manages the boot sequence - ensures proper initialization order
## Available globally as autoload singleton
## Core boot happens before UI; UI can be attached later.

# Access autoloads safely
@onready var _verbose = get_node("/root/VerboseConfig")

signal core_systems_ready
signal visualization_ready
signal ui_ready
signal game_ready

var _core_booted: bool = false
var _ui_booted: bool = false
var _booted: bool = false  # Full boot (core + UI)
var is_ready: bool = false  # Public flag for checking boot completion
var _current_stage: String = ""

## Autoload singleton - ready to use as global
func _ready() -> void:
	_verbose.info("boot", "🔧", "BootManager autoload ready")

## Main boot sequence entry point - call after farm and shell are created
func boot_core(load_slot: int = -1, scenario_id: String = "default", headless: bool = false) -> Node:
	"""Boot core systems and ensure Farm exists (no UI)."""
	if _core_booted:
		return get_node_or_null("/root/GameStateManager").active_farm if get_node_or_null("/root/GameStateManager") else null

	_verbose.info("boot", "🚀", "======================================================================")
	_verbose.info("boot", "🚀", "BOOT CORE STARTING")
	_verbose.info("boot", "🚀", "======================================================================")

	var gsm = get_node_or_null("/root/GameStateManager")
	if not gsm:
		push_warning("BootManager: GameStateManager not found")
		return null

	var farm = await gsm.start_session(load_slot, scenario_id)
	if not farm:
		push_warning("BootManager: Farm not available after start_session")
		return null

	# Stage 3A: Core Systems
	_stage_core_systems(farm)

	# Stage 3D: Start Simulation (core runs even without UI)
	_stage_start_simulation(farm)

	_core_booted = true

	# Headless or no UI expected → finalize boot here
	if headless:
		_booted = true
		is_ready = true
		_verbose.info("boot", "✅", "BOOT CORE COMPLETE (headless) - GAME READY")
		game_ready.emit()

	return farm


func boot_ui(farm: Node, shell: Node, quantum_viz: Node) -> void:
	"""Boot visualization + UI after core is ready."""
	if _ui_booted:
		return
	if not farm:
		push_warning("BootManager: boot_ui called with null farm")
		return

	_verbose.info("boot", "🚀", "======================================================================")
	_verbose.info("boot", "🚀", "BOOT UI STARTING")
	_verbose.info("boot", "🚀", "======================================================================")

	# Stage 3B: Visualization
	_stage_visualization(farm, quantum_viz)

	# Stage 3C: UI (async - must await to ensure QuantumInstrumentInput is created)
	await _stage_ui(farm, shell, quantum_viz)

	_ui_booted = true

	if _core_booted:
		# Stage 3E: Music (cherry on top - after all UI is ready)
		_stage_music(farm)

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

	# Prime lookahead buffers so viz_cache is populated before visualization starts.
	if ("biome_evolution_batcher" in farm) and farm.biome_evolution_batcher:
		if farm.biome_evolution_batcher.has_method("prime_lookahead_buffers"):
			farm.biome_evolution_batcher.prime_lookahead_buffers()
			_verbose.info("boot", "✓", "Lookahead buffers primed")

	# NOTE: Music moved to Stage 3E (_stage_music) - runs after all UI is ready

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

	# Register biomes with visualization (payload should already be primed)
	if farm.biome_enabled:
		if farm.biotic_flux_biome:
			quantum_viz.add_biome("BioticFlux", farm.biotic_flux_biome)
		if farm.stellar_forges_biome:
			quantum_viz.add_biome("StellarForges", farm.stellar_forges_biome)
		if farm.fungal_networks_biome:
			quantum_viz.add_biome("FungalNetworks", farm.fungal_networks_biome)
		if farm.volcanic_worlds_biome:
			quantum_viz.add_biome("VolcanicWorlds", farm.volcanic_worlds_biome)
		if farm.starter_forest_biome:
			quantum_viz.add_biome("StarterForest", farm.starter_forest_biome)
		if farm.village_biome:
			quantum_viz.add_biome("Village", farm.village_biome)

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

	# Collect biomes for setup
	var biomes = {}
	if farm.biome_enabled:
		if farm.biotic_flux_biome:
			biomes["BioticFlux"] = farm.biotic_flux_biome
		if farm.stellar_forges_biome:
			biomes["StellarForges"] = farm.stellar_forges_biome
		if farm.fungal_networks_biome:
			biomes["FungalNetworks"] = farm.fungal_networks_biome
		if farm.volcanic_worlds_biome:
			biomes["VolcanicWorlds"] = farm.volcanic_worlds_biome
		if farm.starter_forest_biome:
			biomes["StarterForest"] = farm.starter_forest_biome
		if farm.village_biome:
			biomes["Village"] = farm.village_biome

	# CRITICAL: Call setup() to create quantum nodes from biome registers
	# This was missing - without it, quantum_nodes array stays empty and bubbles don't render
	if biomes.size() > 0:
		_verbose.info("boot", "💭", "Creating quantum nodes from biome registers...")
		var farm_grid = farm.grid if "grid" in farm else null
		var plot_pool = farm.plot_pool if "plot_pool" in farm else null
		quantum_viz.graph.setup(biomes, farm_grid, plot_pool)
		_verbose.info("boot", "✓", "Created %d quantum bubbles" % quantum_viz.graph.quantum_nodes.size())

	if biomes.size() > 0:
		_verbose.info("boot", "🎨", "Building emoji atlas...")
		var all_emojis = _collect_all_emojis(biomes)
		_verbose.info("boot", "🎨", "  Found %d unique emojis" % all_emojis.size())

		var EmojiAtlasBatcherClass = load("res://Core/Visualization/EmojiAtlasBatcher.gd")
		var atlas_batcher = EmojiAtlasBatcherClass.new()
		# CRITICAL: Call build_atlas_async() synchronously (no await)
		# It now uses RenderingServer.force_draw() to render immediately, not awaits
		# This ensures atlas is COMPLETELY BUILT before first frame renders
		atlas_batcher.build_atlas_async(all_emojis, quantum_viz.graph)
		_verbose.info("boot", "✓", "Emoji atlas ready (%d emojis)" % atlas_batcher._emoji_uvs.size())

		# Pass atlas to the quantum viz context for use by bubble renderer
		if quantum_viz.graph.has_method("set_emoji_atlas_batcher"):
			quantum_viz.graph.set_emoji_atlas_batcher(atlas_batcher)

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


## Stage 3E: Start music (cherry on top - after all UI is ready)
func _stage_music(farm: Node) -> void:
	_current_stage = "MUSIC"
	_verbose.info("boot", "📍", "Stage 3E: Music")

	var music = get_node_or_null("/root/MusicManager")
	if not music:
		_verbose.warn("boot", "⚠️", "MusicManager not found - skipping music")
		return

	# Check if we have biomes loaded
	var has_biomes = farm and farm.grid and farm.grid.biomes and not farm.grid.biomes.is_empty()

	if has_biomes:
		# In iconmap mode, let the dynamic system handle music selection
		# Just start accumulating - music will play once enough samples are gathered
		if music.iconmap_mode_enabled:
			_verbose.info("boot", "🎵", "IconMap mode active - dynamic music selection will begin shortly")
			# Play fallback until iconmap system has enough data
			music.crossfade_to(music.FALLBACK_TRACK)
		else:
			var biome_mgr = get_node_or_null("/root/ActiveBiomeManager")
			var active_biome = ""
			if biome_mgr and biome_mgr.has_method("get_active_biome"):
				active_biome = biome_mgr.get_active_biome()

			if active_biome != "":
				music.play_biome_track(active_biome)
				_verbose.info("boot", "🎵", "Playing biome track for: %s" % active_biome)
			else:
				music.crossfade_to(music.FALLBACK_TRACK)
				_verbose.info("boot", "🎵", "Playing fallback track")
	else:
		# No biomes - stop any music
		music.stop()
		_verbose.info("boot", "🔇", "No biomes loaded - music stopped")


## ============================================================================
## UNIFIED BIOME LOADING - Used by both boot and lazy-load paths
## ============================================================================

func load_biome(biome_name: String, farm: Node) -> Dictionary:
	"""Unified biome loading - single source of truth for boot and runtime.

	Called by:
	- Farm._ready() during boot (for all unlocked biomes)
	- Farm.explore_biome() at runtime (for new biomes)

	Ensures consistent order:
	1. Load script & instantiate
	2. Register with grid
	3. Assign plots from GridConfig
	4. Rebuild quantum operators (if IconRegistry ready)
	5. Register with batcher
	6. Emit signals

	Args:
		biome_name: String like "BioticFlux", "Village", etc
		farm: Farm instance (has grid, batcher, grid_config)

	Returns:
		{
			success: bool,
			biome_name: String,
			biome_ref: Object (if success),
			already_loaded: bool (if already loaded),
			message: String (if error)
		}
	"""
	# ====== PRE-CONDITION CHECKS ======
	if not farm:
		return {
			"success": false,
			"error": "farm_null",
			"message": "Farm not provided"
		}

	if not farm.grid:
		return {
			"success": false,
			"error": "grid_null",
			"message": "Farm.grid not initialized"
		}

	if not farm.grid_config:
		return {
			"success": false,
			"error": "grid_config_null",
			"message": "Farm.grid_config not initialized"
		}

	# ====== CHECK IF ALREADY LOADED ======
	if farm.grid.biomes.has(biome_name):
		var existing_biome = farm.grid.biomes[biome_name]
		if existing_biome:
			_verbose.debug("boot", "ℹ️", "Biome '%s' already loaded (idempotent)" % biome_name)
			return {
				"success": true,
				"biome_name": biome_name,
				"biome_ref": existing_biome,
				"already_loaded": true
			}

	# ====== STEP 1: LOAD SCRIPT & INSTANTIATE ======
	var biome = farm._safe_load_biome(_get_biome_script_path(biome_name), biome_name)
	if not biome:
		_verbose.error("boot", "❌", "Failed to load biome: %s" % biome_name)
		return {
			"success": false,
			"error": "load_failed",
			"message": "Could not load biome script for '%s'" % biome_name
		}

	# ====== STEP 2: REGISTER WITH GRID ======
	farm.grid.register_biome(biome_name, biome)
	biome.grid = farm.grid
	_verbose.debug("boot", "✓", "Registered '%s' with grid" % biome_name)

	# ====== STEP 2.5: UPDATE GRID CONFIG ======
	if farm.has_method("refresh_grid_for_biomes"):
		farm.refresh_grid_for_biomes()
		_verbose.debug("boot", "📐", "Grid refreshed for loaded biomes")

	# ====== STEP 3: ASSIGN PLOTS FROM GridConfig ======
	farm._assign_plots_for_biome(biome_name)
	_verbose.debug("boot", "✓", "Assigned plots for '%s'" % biome_name)

	# ====== STEP 4: STORE METADATA ======
	farm.set_meta(biome_name.to_lower() + "_biome", biome)

	# ====== STEP 5: REBUILD OPERATORS ======
	# CRITICAL: Must happen BEFORE batcher registration
	# IconRegistry should be ready by this point (checked in Stage 3A)
	var icon_registry = get_node_or_null("/root/IconRegistry")
	if icon_registry and biome.has_method("rebuild_quantum_operators"):
		biome.rebuild_quantum_operators()
		_verbose.debug("boot", "✓", "Rebuilt operators for '%s'" % biome_name)
	elif not icon_registry:
		_verbose.warn("boot", "⚠️", "IconRegistry not available for '%s'" % biome_name)

	# Verify quantum computer initialized
	if not biome.quantum_computer:
		_verbose.warn("boot", "⚠️", "Biome '%s' has no quantum_computer after operator rebuild" % biome_name)

	# ====== STEP 6: REGISTER WITH BATCHER ======
	if farm.biome_evolution_batcher and farm.biome_evolution_batcher.has_method("register_biome"):
		farm.biome_evolution_batcher.register_biome(biome)
		_verbose.debug("boot", "✓", "Registered '%s' with batcher" % biome_name)
	else:
		_verbose.warn("boot", "⚠️", "Batcher not available for '%s'" % biome_name)

	# ====== STEP 7: EMIT SIGNALS ======
	if farm.has_signal("biome_loaded"):
		farm.biome_loaded.emit(biome_name, biome)

	_verbose.info("boot", "✓", "Biome loaded: %s" % biome_name)
	return {
		"success": true,
		"biome_name": biome_name,
		"biome_ref": biome,
		"already_loaded": false
	}


## Helper: Get script path for a biome name
func _get_biome_script_path(biome_name: String) -> String:
	match biome_name:
		"StarterForest":
			return "res://Core/Environment/StarterForestBiome.gd"
		"Village":
			return "res://Core/Environment/VillageBiome.gd"
		"BioticFlux":
			return "res://Core/Environment/BioticFluxBiome.gd"
		"StellarForges":
			return "res://Core/Environment/StellarForgesBiome.gd"
		"FungalNetworks":
			return "res://Core/Environment/FungalNetworksBiome.gd"
		"VolcanicWorlds":
			return "res://Core/Environment/VolcanicWorldsBiome.gd"
		_:
			# Fallback: data-driven biomes from registry
			var registry = load("res://Core/Biomes/BiomeRegistry.gd").new()
			if registry.get_by_name(biome_name):
				return "res://Core/Environment/DataDrivenBiome.gd"
			return ""


## Helper: Collect all unique emojis from all biomes for atlas building
func _collect_all_emojis(biomes: Dictionary) -> Array:
	"""Extract all unique emojis from biome quantum computers.

	Returns an array of unique emoji strings for atlas building.
	"""
	var unique_emojis: Dictionary = {}
	print("[BootManager] Collecting emojis from %d biomes" % biomes.size())

	for biome_name in biomes:
		var biome = biomes[biome_name]
		print("[BootManager]   Biome '%s': has_quantum_computer=%s" % [biome_name, biome != null and "quantum_computer" in biome])
		if not biome or not biome.quantum_computer:
			print("[BootManager]     Skipping '%s' - no quantum_computer" % biome_name)
			continue

		var qc = biome.quantum_computer
		var register_map = qc.register_map
		print("[BootManager]     '%s' qc has register_map=%s" % [biome_name, register_map != null])
		if not register_map:
			print("[BootManager]     Skipping '%s' - no register_map" % biome_name)
			continue

		# Get all emojis from register map coordinates
		if "coordinates" in register_map:
			print("[BootManager]     '%s' has coordinates: %d items" % [biome_name, register_map.coordinates.size()])
			for emoji in register_map.coordinates.keys():
				unique_emojis[emoji] = true
		else:
			print("[BootManager]     '%s' NO COORDINATES property!" % biome_name)

		# Also get from axes (north/south poles)
		if "axes" in register_map:
			print("[BootManager]     '%s' has axes: %d items" % [biome_name, register_map.axes.size()])
			for axis_id in register_map.axes:
				var axis = register_map.axes[axis_id]
				if axis.has("north"):
					unique_emojis[axis.north] = true
				if axis.has("south"):
					unique_emojis[axis.south] = true

	print("[BootManager] Collected %d unique emojis total" % unique_emojis.size())
	return unique_emojis.keys()
