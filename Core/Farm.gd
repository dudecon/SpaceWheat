class_name Farm
extends Node

# Access autoloads safely (avoids compile-time errors)
@onready var _icon_registry = get_node("/root/IconRegistry")
@onready var _verbose = get_node("/root/VerboseConfig")

## Farm - Pure simulation manager for quantum wheat farming
## Owns all game systems and handles all game logic
## Emits signals when state changes (no UI dependencies)

# System preloads
# Grid configuration (Phase 2)
const GridConfig = preload("res://Core/GameState/GridConfig.gd")
const PlotConfig = preload("res://Core/GameState/PlotConfig.gd")
const KeyboardLayoutConfig = preload("res://Core/GameState/KeyboardLayoutConfig.gd")

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmPlot = preload("res://Core/GameMechanics/FarmPlot.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const TerminalPoolClass = preload("res://Core/GameMechanics/TerminalPool.gd")
const BiomeEvolutionBatcherClass = preload("res://Core/Environment/BiomeEvolutionBatcher.gd")
# GRACEFUL BIOME LOADING: Use load() instead of preload() so script errors
# in individual biomes don't break the entire Farm. Failed biomes are skipped.
var _BiomeScripts: Dictionary = {}  # Populated at runtime in _init_biomes()
const FarmUIState = preload("res://Core/GameState/FarmUIState.gd")
const VocabularyEvolution = preload("res://Core/QuantumSubstrate/VocabularyEvolution.gd")

# Icon system moved to faction-based IconRegistry (no preload needed)

# Core simulation systems
var grid: FarmGrid
var economy  # FarmEconomy type
# Biome instances (may be null if script failed to load)
var biotic_flux_biome = null
var stellar_forges_biome = null
var fungal_networks_biome = null
var volcanic_worlds_biome = null
var starter_forest_biome = null
var village_biome = null
var _loaded_biome_count: int = 0  # Track how many biomes loaded successfully
var vocabulary_evolution: VocabularyEvolution  # Vocabulary evolution system
var known_pairs: Array = []  # Player vocabulary pairs (canonical, farm-owned)
var ui_state: FarmUIState  # UI State abstraction layer
var grid_config: GridConfig = null  # Single source of truth for grid layout
var terminal_pool: TerminalPoolClass = null  # v2 Architecture: Terminal pool for EXPLORE/MEASURE/POP
var biome_evolution_batcher: BiomeEvolutionBatcherClass = null  # Batched quantum evolution

# Icon system now managed by faction-based IconRegistry (deprecated variables removed)

# PERFORMANCE: Cached mushroom count (avoid O(n) iteration every frame)
var _cached_mushroom_count: int = 0
var _mushroom_count_dirty: bool = true  # Set true when plots change

func invalidate_mushroom_cache() -> void:
	"""Call when plots are planted/harvested to recalculate mushroom count on next frame"""
	_mushroom_count_dirty = true


func _safe_load_biome(script_path: String, biome_name: String):
	"""Gracefully load and instantiate a biome. Returns null if loading fails.

	This allows the game to continue with partial biome availability
	when individual biome scripts have compile errors.
	"""
	var script = load(script_path)
	if script == null:
		push_warning("Farm: Failed to load biome script '%s' - biome '%s' disabled" % [script_path, biome_name])
		return null

	var biome = script.new()
	if biome == null:
		push_warning("Farm: Failed to instantiate biome '%s' - disabled" % biome_name)
		return null

	biome.name = biome_name
	add_child(biome)
	_loaded_biome_count += 1
	print("Farm: Loaded biome '%s'" % biome_name)
	return biome




func _finalize_biome_evolution_batcher() -> void:
	"""Finalize batched biome evolution setup after all biomes are loaded.

	The batcher was created before biome loading and biomes were registered
	during BootManager.load_biome(). Now we just disable individual biome
	_process() to prevent double evolution.
	"""
	if not biome_evolution_batcher:
		push_warning("Farm: Batcher not initialized - cannot finalize")
		return

	# Disable individual biome _process() to prevent double evolution
	# BiomeEvolutionBatcher handles both quantum evolution AND time_tracker updates
	var all_biomes = [
		biotic_flux_biome,
		stellar_forges_biome,
		fungal_networks_biome,
		volcanic_worlds_biome,
		starter_forest_biome,
		village_biome
	]

	var disabled_count = 0
	for biome in all_biomes:
		if biome:
			biome.set_meta("batched_evolution", true)
			biome.set_process(false)  # Completely disable - batcher handles everything
			disabled_count += 1

	print("Farm: Biome evolution batcher finalized (%d biomes, 2/frame rotation)" % disabled_count)


# Configuration

# Biome availability (may fail to load if icon dependencies are missing)
var biome_enabled: bool = false

# Dynamic grid sizing
const DEFAULT_PLOTS_PER_BIOME = 4
const MAX_PLOTS_PER_BIOME = 7  # J K L ; ' H G

# Dynamic row mappings (built from explored biome order)
var biome_row_map: Dictionary = {}  # biome_name -> row index
var row_biome_map: Dictionary = {}  # row index -> biome_name

# Special gather actions (not plantable, not buildings)
const GATHER_ACTIONS = {
	"forest_harvest": {
		"cost": {},  # Free - gather natural detritus from forest
		"yields": {"🍂": 5},  # Collect 5 detritus (leaf litter, deadwood)
		"biome_required": "Forest"  # Only works in Forest biome
	}
}

# Signals - emitted when game state changes (no UI callbacks needed)
signal state_changed(state_data: Dictionary)
signal action_result(action: String, success: bool, message: String)
signal action_rejected(action: String, position: Vector2i, reason: String)  # For visual/audio feedback
signal grid_resized(new_config)  # Emitted when grid dimensions change

# ═══════════════════════════════════════════════════════════════════════════════
# TERMINAL LIFECYCLE SIGNALS (EXPLORE/MEASURE/POP actions)
# These trigger bubble visualization in QuantumForceGraph
# ═══════════════════════════════════════════════════════════════════════════════

## Emitted when EXPLORE binds a terminal to a quantum register
signal terminal_bound(grid_position: Vector2i, terminal_id: String, emoji_pair: Dictionary)

## Emitted when MEASURE collapses the terminal's quantum state
signal terminal_measured(grid_position: Vector2i, terminal_id: String, outcome: String, probability: float)

## Emitted when POP releases the terminal back to pool
signal terminal_released(grid_position: Vector2i, terminal_id: String, credits_earned: int)

## Emitted when a biome is loaded dynamically (for visualization updates)
signal biome_loaded(biome_name: String, biome_ref)

## Emitted BEFORE a biome is removed (for cascading cleanup)
signal biome_removed(biome_name: String)

# ═══════════════════════════════════════════════════════════════════════════════
# STRUCTURE LIFECYCLE SIGNALS (BUILD mode actions)
# These trigger plot tile updates in PlotGridDisplay
# ═══════════════════════════════════════════════════════════════════════════════

## Emitted when biome quantum system expands (new axis added)
signal biome_expanded(biome_name: String, qubit_index: int, emoji_pair: Dictionary)

# ═══════════════════════════════════════════════════════════════════════════════
# LEGACY SIGNALS (kept for internal use and backwards compatibility)
# For visualization, use terminal_* signals instead
# ═══════════════════════════════════════════════════════════════════════════════

## @deprecated - Use terminal_measured for visualization
signal plot_measured(position: Vector2i, outcome: String)

## @deprecated - Use terminal_released for visualization
signal plot_harvested(position: Vector2i, yield_data: Dictionary)

# ═══════════════════════════════════════════════════════════════════════════════
# OTHER SIGNALS
# ═══════════════════════════════════════════════════════════════════════════════

signal plots_entangled(pos1: Vector2i, pos2: Vector2i, bell_state: String)
signal economy_changed(state: Dictionary)


# ═══════════════════════════════════════════════════════════════════════════════
# CENTRAL SIGNAL EMISSION (DRY Architecture)
# All action→signal mapping in ONE place. UI handlers call this instead of
# emitting signals directly. This ensures headless and headed modes behave
# identically, and tests can trigger visualization by calling this method.
# ═══════════════════════════════════════════════════════════════════════════════

func emit_action_signal(action: String, result: Dictionary, grid_pos: Vector2i = Vector2i(-1, -1)) -> void:
	"""Central hub for action→signal emission.

	Simulation layer (ProbeActions) returns result dictionaries.
	This method translates those results into appropriate Farm signals.
	Visualization layer observes these signals to update display.

	Args:
		action: Action name ("explore", "measure", "pop", "reap", "harvest_all", "build")
		result: Dictionary returned by ProbeActions (must have "success" key)
		grid_pos: Grid position for the action (used by most signals)
	"""
	if not result.get("success", false):
		return  # Only emit signals on successful actions

	match action:
		"explore":
			var terminal = result.get("terminal")
			if terminal:
				# Set grid_position on terminal if not already set
				if "grid_position" in terminal and grid_pos != Vector2i(-1, -1):
					terminal.grid_position = grid_pos
				terminal_bound.emit(grid_pos, terminal.terminal_id, result.get("emoji_pair", {}))

		"measure":
			var terminal = result.get("terminal")
			var terminal_id = terminal.terminal_id if terminal else result.get("terminal_id", "")
			terminal_measured.emit(grid_pos, terminal_id,
				result.get("outcome", ""), result.get("probability", 0.0))

		"pop", "reap":
			terminal_released.emit(grid_pos, result.get("terminal_id", ""),
				int(result.get("credits", 0)))

		"harvest_all", "clear_all":
			# Handle array of harvest/clear results
			var harvest_results = result.get("harvest_results", result.get("terminals", []))
			for harvest in harvest_results:
				var h_pos = harvest.get("grid_position", Vector2i(-1, -1))
				var tid = harvest.get("terminal_id", "")
				if h_pos == Vector2i(-1, -1) and harvest is Object and "grid_position" in harvest:
					h_pos = harvest.grid_position
				if tid == "" and harvest is Object and "terminal_id" in harvest:
					tid = harvest.terminal_id
				if h_pos != Vector2i(-1, -1) and tid != "":
					terminal_released.emit(h_pos, tid, int(harvest.get("total_credits", 0)))


func _ready():
	# Ensure IconRegistry exists (for test mode where autoloads don't exist)
	_ensure_iconregistry()

	# Create core systems
	economy = FarmEconomy.new()
	add_child(economy)

	# Start with empty grid (0x0) and expand as biomes load
	grid_config = _create_empty_grid_config()
	grid = FarmGrid.new(grid_config.grid_width, grid_config.grid_height)
	add_child(grid)

	# v2 Architecture: Create terminal pool for EXPLORE/MEASURE/POP actions
	var total_plots = grid_config.grid_width * grid_config.grid_height
	terminal_pool = TerminalPoolClass.new(total_plots)
	if grid:
		grid.set_terminal_pool(terminal_pool)

	# Create biome evolution batcher BEFORE loading biomes
	# This allows BootManager.load_biome() to register each biome as it loads
	biome_evolution_batcher = BiomeEvolutionBatcherClass.new()
	biome_evolution_batcher.initialize([], terminal_pool)  # Initialize with empty array, biomes register individually

	# Create environmental simulations (six biomes for multi-biome support)
	# UNIFIED LOADING: All biomes go through BootManager.load_biome() for consistency
	# This ensures: script load → grid register → batcher register → operator rebuild
	biome_enabled = false
	_loaded_biome_count = 0

	# Load only unlocked biomes (initially just StarterForest and Village)
	# Other biomes are loaded dynamically when explored via 4E action
	var observation_frame = get_node_or_null("/root/ObservationFrame")
	var unlocked_biomes = ["StarterForest", "Village"]  # Default
	if observation_frame and observation_frame.has_method("get_explored_biomes"):
		unlocked_biomes = observation_frame.get_explored_biomes()
	elif observation_frame and observation_frame.has_method("get_unlocked_biomes"):
		unlocked_biomes = observation_frame.get_unlocked_biomes()

	# Load unlocked biomes through unified BootManager.load_biome()
	var boot_manager = get_node_or_null("/root/BootManager")
	var biome_name_to_var = {
		"StarterForest": "starter_forest_biome",
		"Village": "village_biome",
		"BioticFlux": "biotic_flux_biome",
		"StellarForges": "stellar_forges_biome",
		"FungalNetworks": "fungal_networks_biome",
		"VolcanicWorlds": "volcanic_worlds_biome"
	}

	for biome_name in unlocked_biomes:
		if boot_manager and boot_manager.has_method("load_biome"):
			var result = boot_manager.load_biome(biome_name, self)
			if result.get("success", false):
				# Store biome reference in the correct variable
				if biome_name_to_var.has(biome_name):
					var var_name = biome_name_to_var[biome_name]
					set(var_name, result.get("biome_ref"))
					_loaded_biome_count += 1
			else:
				_verbose.warn("boot", "⚠️", "Failed to load biome '%s': %s" % [biome_name, result.get("message", "unknown error")])

	# Enable biome features if at least one biome loaded
	if _loaded_biome_count > 0:
		biome_enabled = true
		print("Farm: %d biomes loaded successfully (via unified BootManager.load_biome)" % _loaded_biome_count)
	else:
		biome_enabled = false
		_verbose.warn("boot", "⚠️", "No biomes loaded - operating in simple mode (fallback 4×1 grid)")

	# NOTE: Operator rebuild now handled by BootManager in Stage 3A
	# This ensures deterministic ordering: IconRegistry ready → rebuild operators → verify biomes

	# Icon system now managed by faction-based IconRegistry

	# Grid already created (empty) - resize after biomes load
	refresh_grid_for_biomes()

	# Validate grid configuration now that biomes are loaded
	if grid_config.grid_width > 0 and grid_config.grid_height > 0:
		var validation = grid_config.validate()
		if not validation.success:
			push_error("GridConfig validation failed:")
			for error in validation.errors:
				push_error("  - %s" % error)
			return

	# Persist grid dimensions into GameState (source of truth for saves)
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state:
		gsm.current_state.grid_width = grid_config.grid_width
		gsm.current_state.grid_height = grid_config.grid_height

	# PERFORMANCE: Connect grid signals to invalidate mushroom cache
	grid.plot_planted.connect(func(_pos): invalidate_mushroom_cache())
	grid.plot_harvested.connect(func(_pos, _data): invalidate_mushroom_cache())

	# Connect economy to grid for mill/market/kitchen flour & bread processing
	grid.farm_economy = economy

	# Note: StellarForges doesn't have direct economy connection (no trading)

	# NOTE: Biomes are already wired to grid by BootManager.load_biome()
	# (No additional registration needed here - unified path handles it)

	# Register loaded biomes as metadata for UI systems (QuantumForceGraph visualization)
	set_meta("grid", grid)
	if biotic_flux_biome:
		set_meta("biotic_flux_biome", biotic_flux_biome)
	if stellar_forges_biome:
		set_meta("stellar_forges_biome", stellar_forges_biome)
	if starter_forest_biome:
		set_meta("starter_forest_biome", starter_forest_biome)
	if village_biome:
		set_meta("village_biome", village_biome)
	if fungal_networks_biome:
		set_meta("fungal_networks_biome", fungal_networks_biome)
	if volcanic_worlds_biome:
		set_meta("volcanic_worlds_biome", volcanic_worlds_biome)

	# Configure plot-to-biome assignments from GridConfig (4 biomes, 1 row each)
	# Each biome has its own row: Row 0=BioticFlux, 1=StellarForges, 2=FungalNetworks, 3=VolcanicWorlds
	if biome_enabled and grid and grid.has_method("assign_plot_to_biome"):
		for pos in grid_config.biome_assignments:
			var biome_name = grid_config.biome_assignments[pos]
			grid.assign_plot_to_biome(pos, biome_name)

	# Get persistent vocabulary evolution from GameStateManager
	# The vocabulary persists across farms/biomes and travels with the player
	# Safe access for headless mode where get_tree() may return null
	var game_state_mgr = get_node_or_null("/root/GameStateManager")
	if game_state_mgr and game_state_mgr.has_method("get_vocabulary_evolution"):
		vocabulary_evolution = game_state_mgr.get_vocabulary_evolution()
	else:
		# Fallback: create local vocabulary if GameStateManager not available
		# This happens in test/standalone scenarios
		var VocabularyEvolution = preload("res://Core/QuantumSubstrate/VocabularyEvolution.gd")
		vocabulary_evolution = VocabularyEvolution.new()
		add_child(vocabulary_evolution)

	# Initialize farm-owned vocabulary (canonical player vocab)
	_ensure_vocabulary_initialized()

	# Inject vocabulary reference into grid for tap validation
	if grid:
		grid.vocabulary_evolution = vocabulary_evolution

	# Finalize biome evolution batcher setup
	# (Batcher was created before biome loading, biomes registered during load)
	# Now disable individual biome _process() to prevent double evolution
	_finalize_biome_evolution_batcher()
	if _verbose:
		_verbose.info("boot", "🧭", "Farm _ready checkpoint: after batcher finalization")

	# Create UI State abstraction layer (Phase 2 integration)
	ui_state = FarmUIState.new()
	if _verbose:
		_verbose.info("boot", "🧭", "Farm _ready checkpoint: UIState created")

	# Connect economy signals to both state_changed AND ui_state (de-slopped)
	var economy_signals = ["wheat_changed", "credits_changed", "flour_changed", "flower_changed", "labor_changed"]
	for sig_name in economy_signals:
		if economy.has_signal(sig_name):
			economy.connect(sig_name, _on_economy_changed)
			economy.connect(sig_name, _on_economy_changed_ui)

	# Connect Farm's own measurement signal to trigger UIState update
	plot_measured.connect(_on_plot_measured_ui)


	# Populate UIState with initial farm state
	ui_state.refresh_all(self)
	if _verbose:
		_verbose.info("boot", "🧭", "Farm _ready checkpoint: UIState refreshed")


## ============================================================================
## VOCABULARY (FARM-OWNED)
## ============================================================================

func _ensure_vocabulary_initialized() -> void:
	"""Ensure farm has a valid starting vocabulary."""
	if known_pairs.is_empty():
		set_known_pairs([{"north": "🌾", "south": "👥"}], true, false)
	else:
		_sync_player_vocabulary(false)


func get_known_pairs() -> Array:
	"""Return player-known vocab pairs (canonical)."""
	return known_pairs.duplicate(true)


func get_known_emojis() -> Array:
	"""Return unique emojis from known vocab pairs."""
	var emojis: Array = []
	for pair in known_pairs:
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north != "" and north not in emojis:
			emojis.append(north)
		if south != "" and south not in emojis:
			emojis.append(south)
	return emojis


func set_known_pairs(pairs: Array, sync_player_vocab: bool = true, reset_player_vocab: bool = false) -> void:
	"""Replace known vocab pairs with sanitized list."""
	var filtered: Array = []
	var seen: Dictionary = {}
	for pair in pairs:
		if not (pair is Dictionary):
			continue
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north == "" or south == "" or north == south:
			continue
		var key = "%s|%s" % [north, south]
		if seen.has(key):
			continue
		seen[key] = true
		filtered.append({"north": north, "south": south})

	if filtered.is_empty():
		filtered = [{"north": "🌾", "south": "👥"}]

	known_pairs = filtered
	if sync_player_vocab:
		_sync_player_vocabulary(reset_player_vocab)
	_sync_gsm_vocab_state()


func discover_pair(north: String, south: String) -> bool:
	"""Learn a new vocab pair (farm-owned source of truth)."""
	if north == "" or south == "" or north == south:
		return false

	# Check if exact pair already exists
	for pair in known_pairs:
		if pair.get("north", "") == north and pair.get("south", "") == south:
			return false  # Already known

	# Check if either emoji already exists in a different pair
	for pair in known_pairs:
		var existing_north = pair.get("north", "")
		var existing_south = pair.get("south", "")
		if north == existing_north or north == existing_south or south == existing_north or south == existing_south:
			# One of the emojis is already registered - can't add overlapping pair
			return false

	known_pairs.append({"north": north, "south": south})
	_sync_player_vocabulary(false)
	_sync_gsm_vocab_state()
	return true


func get_pair_for_emoji(emoji: String) -> Variant:
	"""Return the vocab pair containing an emoji (or null)."""
	for pair in known_pairs:
		if pair.get("north", "") == emoji or pair.get("south", "") == emoji:
			return pair
	return null


func _sync_player_vocabulary(reset_first: bool) -> void:
	"""Keep PlayerVocabulary QC in sync with farm-owned vocabulary."""
	var player_vocab = get_node_or_null("/root/PlayerVocabulary")
	if not player_vocab:
		return
	if reset_first and player_vocab.has_method("reset"):
		player_vocab.reset()
	for pair in known_pairs:
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north != "" and south != "":
			if player_vocab.has_method("learn_vocab_pair"):
				player_vocab.learn_vocab_pair(north, south)


func _sync_gsm_vocab_state() -> void:
	"""Keep GameStateManager.current_state mirrored for legacy readers."""
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and "current_state" in gsm and gsm.current_state:
		gsm.current_state.known_pairs = get_known_pairs()
		if gsm.current_state.has_method("get_known_emojis"):
			gsm.current_state.known_emojis = get_known_emojis()


## Rebuild quantum operators after biomes have initialized
func rebuild_all_biome_operators() -> void:
	"""Rebuild quantum operators for all biomes

	Called by BootManager in Stage 3A after IconRegistry is confirmed ready.
	This ensures all biomes have complete Hamiltonian and Lindblad operators
	even if they initialized before IconRegistry loaded all icons.
	"""
	if not biome_enabled:
		return

	_verbose.info("boot", "🔧", "Rebuilding operators for loaded biomes...")
	if biotic_flux_biome:
		biotic_flux_biome.rebuild_quantum_operators()
	if stellar_forges_biome:
		stellar_forges_biome.rebuild_quantum_operators()
	if fungal_networks_biome:
		fungal_networks_biome.rebuild_quantum_operators()
	if volcanic_worlds_biome:
		volcanic_worlds_biome.rebuild_quantum_operators()
	if starter_forest_biome:
		starter_forest_biome.rebuild_quantum_operators()
	if village_biome:
		village_biome.rebuild_quantum_operators()
	_verbose.info("boot", "✓", "Loaded biome operators rebuilt")


## Called by BootManager in Stage 3A to finalize setup before simulation starts
func finalize_setup() -> void:
	"""Finalize farm setup after all basic initialization.

	Called by BootManager.boot() after biomes are loaded and verified.
	Quantum verification already happened in BootManager.load_biome().
	"""
	_verbose.info("boot", "✓", "Farm setup finalized (%d biomes active)" % _loaded_biome_count)


## Called by BootManager in Stage 3D to enable simulation processing
func enable_simulation() -> void:
	"""Enable the farm simulation to start processing quantum evolution.

	Called by BootManager.boot() after UI is initialized.
	This enables _process() to evolve quantum states in biomes.
	"""
	set_process(true)
	set_physics_process(true)

	# Enable biome processing (only for non-batched biomes)
	# Batched biomes stay disabled - BiomeEvolutionBatcher handles their updates
	if biome_enabled:
		var all_biomes = [biotic_flux_biome, stellar_forges_biome, fungal_networks_biome,
						  volcanic_worlds_biome, starter_forest_biome, village_biome]
		for biome in all_biomes:
			if biome and not biome.get_meta("batched_evolution", false):
				biome.set_process(true)
		if _verbose:
			_verbose.info("boot", "✓", "All biome processing enabled (batched biomes use BiomeEvolutionBatcher)")

	if _verbose:
		_verbose.info("boot", "✓", "Farm simulation process enabled")


func _process(delta: float):
	# Visual updates only - runs at 60+ FPS independent of quantum simulation
	var t0 = Time.get_ticks_usec()
	# Process grid UI updates (mills, markets, kitchens, etc.)
	if grid:
		grid._process(delta)
	var t1 = Time.get_ticks_usec()

	# Handle passive composting (visual effects)
	_process_mushroom_composting(delta)
	var t2 = Time.get_ticks_usec()

	if Engine.get_process_frames() % 60 == 0:
		# Use 'trace' category (WARN by default, only shown if explicitly enabled at DEBUG level)
		if _verbose:
			_verbose.debug("trace", "🚜", "Farm Process Trace: Total %d us (Grid: %d, Compost: %d)" % [t2 - t0, t1 - t0, t2 - t1])


func _physics_process(delta: float) -> void:
	"""Physics simulation - runs at fixed 20Hz"""
	# BATCHED QUANTUM EVOLUTION (moved here for visual/physics separation)
	# Runs at fixed 20Hz, independent of visual framerate (60+ FPS)
	if biome_evolution_batcher:
		biome_evolution_batcher.physics_process(delta)

	# Lindblad pump/drain effects
	_process_lindblad_effects(delta)


func _process_lindblad_effects(delta: float) -> void:
	"""Apply persistent Lindblad pump/drain effects from Tool 2."""
	if not grid:
		return

	var plots = grid.plots if "plots" in grid else {}
	if plots.is_empty():
		return
	var known_emojis: Array = get_known_emojis()
	var has_vocab_gate = not known_emojis.is_empty()

	for pos in plots.keys():
		var plot = plots[pos]
		if not plot:
			continue
		if not plot.lindblad_pump_active and not plot.lindblad_drain_active:
			continue

		var biome = grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue

		var pair = _get_lindblad_pair_for_plot(plot, pos)
		if pair.is_empty():
			continue

		if plot.lindblad_pump_active:
			var target = pair.get("north", "")
			if target != "":
				biome.quantum_computer.apply_drive(target, plot.lindblad_pump_rate, delta)

		if plot.lindblad_drain_active:
			var north = pair.get("north", "")
			var south = pair.get("south", "")
			var axis_emoji = north if north != "" else south
			if axis_emoji != "" and biome.quantum_computer.register_map.has(axis_emoji):
				var before_pop = 0.0
				if north != "" and biome.quantum_computer.register_map.has(north):
					before_pop = biome.quantum_computer.get_population(north)
				else:
					before_pop = biome.quantum_computer.get_population(axis_emoji)

				var qubit_idx = biome.quantum_computer.register_map.qubit(axis_emoji)
				biome.quantum_computer.apply_decay(qubit_idx, plot.lindblad_drain_rate, delta)

				var drained_probability = before_pop * plot.lindblad_drain_rate * delta
				_accumulate_lindblad_harvest(
					plot,
					axis_emoji,
					drained_probability,
					known_emojis,
					has_vocab_gate
				)


func _accumulate_lindblad_harvest(plot, emoji: String, drained_probability: float,
		known_emojis: Array, has_vocab_gate: bool) -> void:
	if not economy or emoji == "":
		return
	if has_vocab_gate and emoji not in known_emojis:
		return

	var credits = max(0.0, drained_probability) * EconomyConstants.QUANTUM_TO_CREDITS
	if credits <= 0.0:
		return

	plot.lindblad_drain_accumulator += credits
	if _verbose:
		_verbose.info("lindblad", "⏱", "accumulator %s=%.6f" % [emoji, plot.lindblad_drain_accumulator])
	else:
		print("⏱ Lindblad accumulator %s=%.6f" % [emoji, plot.lindblad_drain_accumulator])
	var whole_credits = int(plot.lindblad_drain_accumulator)
	if whole_credits <= 0:
		return

	plot.lindblad_drain_accumulator -= whole_credits
	economy.add_resource(emoji, whole_credits, "lindblad_drain")


func _get_lindblad_pair_for_plot(plot, pos: Vector2i) -> Dictionary:
	"""Resolve emoji pair for a plot using terminal binding when available."""
	if terminal_pool:
		var terminal = terminal_pool.get_terminal_at_grid_pos(pos)
		if terminal and terminal.is_bound:
			return terminal.get_emoji_pair()

	if plot and plot.is_planted:
		return plot.get_plot_emojis()

	return {}


func _process_mushroom_composting(delta: float):
	"""Passive composting: converts detritus → mushrooms based on planted mushroom count

	Composting rate scales with number of planted mushrooms
	Ratio: 2 detritus → 1 mushroom
	"""
	if not economy or not grid:
		return

	# PERFORMANCE: Use cached mushroom count instead of iterating every frame
	if _mushroom_count_dirty:
		_cached_mushroom_count = 0
		for y in range(grid.grid_height):
			for x in range(grid.grid_width):
				var plot = grid.get_plot(Vector2i(x, y))
				if plot and plot.is_planted and plot.plot_type == FarmPlot.PlotType.MUSHROOM:
					_cached_mushroom_count += 1
		_mushroom_count_dirty = false

	if _cached_mushroom_count == 0:
		return  # No composting without mushrooms

	# Only compost if we have detritus
	var detritus_amount = economy.get_resource("🍂")
	if detritus_amount <= 0:
		return

	# Composting parameters
	const COMPOSTING_RATE = 1.0  # 1 detritus per second per mushroom
	const COMPOSTING_RATIO = 0.5  # 2 detritus → 1 mushroom

	# Calculate composting power (scales with mushroom count)
	var activation = min(1.0, float(_cached_mushroom_count) / 4.0)  # Full power at 4 mushrooms
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

			_verbose.debug("economy", "🍄", "Composting: %d 🍂 → %d 🍄 (%.1f%% activation, %d mushrooms planted)" % [detritus_consumed, mushrooms_produced, activation * 100, _cached_mushroom_count])
		else:
			# Conversion failed, keep accumulator for next frame
			set_meta("composting_accumulator", accumulator)


## GRID CONFIGURATION (Phase 2 → Single-Biome View → Quantum Instrument)
##
## NEW ARCHITECTURE: Each biome has N independent plots (dynamic).
## Only one biome visible at a time.
## Homerow keys select plots within the current biome.
##
## Grid dimensions are derived from:
##   width  = max plot count across loadable biomes (min 5)
##   height = number of explored biomes loaded into the farm

const HOMEROW_KEYS: Array[String] = ["J", "K", "L", ";", "'", "H", "G"]

func _create_grid_config() -> GridConfig:
	"""Create grid configuration - single source of truth for layout

	Quantum Instrument Layout: dynamic grid
	  width  = max plot count across loadable biomes (min 5)
	  height = explored biomes count

	Keyboard layout:
	  Homerow keys map to columns 0..N-1 (N=grid_width)
	"""
	var config = GridConfig.new()
	var explored_biomes = _get_loaded_biomes_in_order()
	if explored_biomes.is_empty():
		return _create_empty_grid_config()
	var grid_width = _get_max_biome_plot_count(explored_biomes)
	var grid_height = explored_biomes.size()
	config.grid_width = grid_width
	config.grid_height = grid_height

	# Build dynamic row maps based on explored biome order
	_rebuild_biome_row_maps(explored_biomes)

	# Create keyboard layout configuration
	var keyboard = KeyboardLayoutConfig.new()

	# Homerow → positions 0..N-1 (within active biome, y determined at runtime)
	var neutral_keys = []
	for i in range(grid_width):
		var key_label = HOMEROW_KEYS[i] if i < HOMEROW_KEYS.size() else str(i + 1)
		neutral_keys.append(key_label)
		var pos = Vector2i(i, 0)  # Default to y=0, remapped at runtime
		keyboard.action_to_position["plot_neutral_" + str(i)] = pos
		keyboard.position_to_label[pos] = key_label.to_upper()
		# Also add labels for other biome rows (same x position, different y)
		for biome_row in range(1, grid_height):
			keyboard.position_to_label[Vector2i(i, biome_row)] = key_label.to_upper()

	config.keyboard_layout = keyboard

	# =========================================================================
	# PLOT CONFIGURATIONS - N plots per biome, dynamic total
	# Each biome has independent quantum state and plots
	# =========================================================================

	for biome_name in explored_biomes:
		var biome_row = biome_row_map[biome_name]
		for i in range(grid_width):
			var plot = PlotConfig.new()
			plot.position = Vector2i(i, biome_row)
			plot.is_active = true
			plot.keyboard_label = neutral_keys[i].to_upper()
			plot.input_action = "plot_neutral_" + str(i)
			plot.biome_name = biome_name
			config.plots.append(plot)

			# Set up biome assignment
			config.biome_assignments[Vector2i(i, biome_row)] = biome_name

	return config


func _create_empty_grid_config() -> GridConfig:
	"""Create a fallback grid config (4x1) when no biomes load.

	This ensures a fully functioning farm even with zero working biomes.
	The farm operates in "simple mode" without quantum evolution, but plots
	remain usable for basic operations and economy continues to function.

	Returns: GridConfig with 4×1 grid (4 usable plots, no biome assignments)
	"""
	var config = GridConfig.new()

	# Fallback: 4×1 grid (minimum viable farm)
	# Provides 4 plots for basic farming even if all biomes fail
	config.grid_width = 4
	config.grid_height = 1

	# Create keyboard layout with homerow mapping
	var keyboard = KeyboardLayoutConfig.new()
	var neutral_keys = ["J", "K", "L", ";"]
	for i in range(4):
		var pos = Vector2i(i, 0)
		keyboard.action_to_position["plot_neutral_" + str(i)] = pos
		keyboard.position_to_label[pos] = neutral_keys[i].to_upper()
	config.keyboard_layout = keyboard

	# Create plot configs for each grid position (unassigned to any biome)
	var plots: Array[PlotConfig] = []
	for x in range(4):
		var plot = PlotConfig.new()
		plot.position = Vector2i(x, 0)
		plot.is_active = true
		plot.keyboard_label = neutral_keys[x].to_upper()
		plot.input_action = "plot_neutral_" + str(x)
		plot.biome_name = ""  # No biome assignment (simple mode)
		plots.append(plot)

	config.plots = plots
	config.biome_assignments.clear()  # No biome assignments in simple mode

	_verbose.info("boot", "⚠️", "Fallback grid created: %dx%d (%d plots, zero biomes, simple mode)" % [
		config.grid_width, config.grid_height, config.grid_width * config.grid_height
	])

	return config


func _get_explored_biomes() -> Array[String]:
	"""Get explored biomes (preferred terminology)."""
	var observation_frame = get_node_or_null("/root/ObservationFrame")
	if observation_frame and observation_frame.has_method("get_explored_biomes"):
		return observation_frame.get_explored_biomes()
	if observation_frame and observation_frame.has_method("get_unlocked_biomes"):
		return observation_frame.get_unlocked_biomes()
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state and "unlocked_biomes" in gsm.current_state:
		return gsm.current_state.unlocked_biomes
	return ["StarterForest", "Village"]


func _get_loaded_biomes_in_order() -> Array[String]:
	"""Return explored biomes filtered to those currently loaded (in order)."""
	var explored = _get_explored_biomes()
	var loaded: Array[String] = []
	for biome_name in explored:
		if _is_biome_loaded(biome_name):
			loaded.append(biome_name)
	return loaded


func _is_biome_loaded(biome_name: String) -> bool:
	"""Check if a biome instance is loaded on this Farm."""
	if grid and grid.biomes and grid.biomes.has(biome_name):
		return grid.biomes[biome_name] != null
	match biome_name:
		"StarterForest":
			return starter_forest_biome != null
		"Village":
			return village_biome != null
		"BioticFlux":
			return biotic_flux_biome != null
		"StellarForges":
			return stellar_forges_biome != null
		"FungalNetworks":
			return fungal_networks_biome != null
		"VolcanicWorlds":
			return volcanic_worlds_biome != null
		_:
			return false


func _get_loadable_biomes() -> Array[String]:
	"""Get loadable biomes (icon build succeeded)."""
	var observation_frame = get_node_or_null("/root/ObservationFrame")
	if observation_frame and observation_frame.has_method("get_loadable_biomes"):
		return observation_frame.get_loadable_biomes()
	# Fallback to explored list if loadable list not available
	return _get_explored_biomes()


func _get_max_biome_plot_count(biome_names: Array[String]) -> int:
	"""Compute max plot count across biome layouts (fallback to DEFAULT_PLOTS_PER_BIOME)."""
	var max_count = 0
	for name in biome_names:
		var biome = _get_loaded_biome_ref(name)
		if biome and biome.quantum_computer and biome.quantum_computer.register_map:
			var count = biome.quantum_computer.register_map.num_qubits
			if count > max_count:
				max_count = count
			continue
		# Fallback: use biome registry plot_layout if biome not loaded yet
		var biome_registry = load("res://Core/Biomes/BiomeRegistry.gd").new()
		var biome_data = biome_registry.get_by_name(name)
		if biome_data and "plot_layout" in biome_data:
			var count2 = biome_data.plot_layout.size()
			if count2 > max_count:
				max_count = count2
	if max_count <= 0:
		max_count = DEFAULT_PLOTS_PER_BIOME
	return min(max_count, MAX_PLOTS_PER_BIOME)


func _get_loaded_biome_ref(biome_name: String):
	if grid and grid.biomes and grid.biomes.has(biome_name):
		return grid.biomes[biome_name]
	match biome_name:
		"StarterForest":
			return starter_forest_biome
		"Village":
			return village_biome
		"BioticFlux":
			return biotic_flux_biome
		"StellarForges":
			return stellar_forges_biome
		"FungalNetworks":
			return fungal_networks_biome
		"VolcanicWorlds":
			return volcanic_worlds_biome
		_:
			return null


func _rebuild_biome_row_maps(biome_list: Array[String]) -> void:
	"""Rebuild row mappings based on explored biome order."""
	biome_row_map.clear()
	row_biome_map.clear()
	for i in range(biome_list.size()):
		var biome_name = biome_list[i]
		biome_row_map[biome_name] = i
		row_biome_map[i] = biome_name


func refresh_grid_for_biomes() -> bool:
	"""Rebuild grid_config and resize grid/terminal_pool if dimensions changed.

	Always produces a valid grid configuration:
	- If biomes loaded: grid sized to match biome layout
	- If no biomes loaded: fallback 4×1 grid for simple mode farming
	"""
	var new_config = _create_grid_config()
	if not new_config:
		return false

	# NOTE: Grid can be valid even with width/height = 0 from _create_grid_config()
	# In that case, we fall back to minimum viable grid
	if new_config.grid_width == 0 or new_config.grid_height == 0:
		new_config = _create_empty_grid_config()  # Fallback: 4×1 grid

	var resized = false
	if not grid_config or new_config.grid_width != grid_config.grid_width or new_config.grid_height != grid_config.grid_height:
		resized = true

	grid_config = new_config

	if resized and grid:
		if grid.has_method("resize_grid"):
			grid.resize_grid(grid_config.grid_width, grid_config.grid_height)
		else:
			grid.grid_width = grid_config.grid_width
			grid.grid_height = grid_config.grid_height

		# Ensure plots exist for new positions
		for plot_cfg in grid_config.get_all_active_plots():
			grid.get_plot(plot_cfg.position)

		# Resize terminal pool to match new grid size
		if terminal_pool:
			terminal_pool.resize(grid_config.grid_width * grid_config.grid_height)

	# Re-assign plot-to-biome mappings (safe even if unchanged)
	if grid and grid.has_method("assign_plot_to_biome"):
		for pos in grid_config.biome_assignments:
			grid.assign_plot_to_biome(pos, grid_config.biome_assignments[pos])

	# Persist dimensions into GameState if available
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state:
		gsm.current_state.grid_width = grid_config.grid_width
		gsm.current_state.grid_height = grid_config.grid_height

	if resized:
		grid_resized.emit(grid_config)

	return resized


func get_biome_row(biome_name: String) -> int:
	"""Get the row (y-coordinate) for a biome"""
	return biome_row_map.get(biome_name, 0)


func get_biome_for_row(row: int) -> String:
	"""Get the biome name for a row (y-coordinate)"""
	return row_biome_map.get(row, "")


func get_biomes() -> Array:
	"""Get all loaded biomes for testing/diagnostics.

	Returns array of biome instances in order:
	[BioticFlux, StellarForges, FungalNetworks, VolcanicWorlds, StarterForest, Village]
	Null entries if biome failed to load.
	"""
	return [
		biotic_flux_biome,
		stellar_forges_biome,
		fungal_networks_biome,
		volcanic_worlds_biome,
		starter_forest_biome,
		village_biome
	]


func get_plot_position_for_active_biome(plot_index: int) -> Vector2i:
	"""Convert plot index (0-3) to full position using active biome

	Used by input handling to map plot keys to the correct biome's plots.
	Now uses ObservationFrame as the source of truth for active biome.
	"""
	# Clamp plot_index to valid range (0..grid_width-1)
	var max_index = grid_config.grid_width - 1 if grid_config else 3
	plot_index = clampi(plot_index, 0, max_index)

	# Try ObservationFrame first, fall back to ActiveBiomeManager
	var observation_frame = get_node_or_null("/root/ObservationFrame")
	var active_biome = "BioticFlux"
	if observation_frame:
		active_biome = observation_frame.get_neutral_biome()
	else:
		var biome_mgr = get_node_or_null("/root/ActiveBiomeManager")
		if biome_mgr:
			active_biome = biome_mgr.get_active_biome()

	var biome_row = get_biome_row(active_biome)
	return Vector2i(plot_index, biome_row)


## Public API - Game Operations

func can_explore_biome() -> Dictionary:
	"""Check if a new biome can be explored (slots + availability)."""
	var observation_frame = get_node_or_null("/root/ObservationFrame")
	if not observation_frame:
		return {"ok": false, "message": "ObservationFrame not available"}

	var biome_mgr = get_node_or_null("/root/ActiveBiomeManager")
	if not biome_mgr:
		return {"ok": false, "message": "ActiveBiomeManager not available"}
	if biome_mgr.has_method("has_open_biome_slot") and not biome_mgr.has_open_biome_slot():
		return {"ok": false, "message": "Biome slots full"}

	var unexplored = observation_frame.get_unexplored_biomes()
	if unexplored.is_empty():
		return {"ok": false, "message": "All biomes already explored!"}

	var cost_gate = EconomyConstants.preflight_action("explore_biome", economy)
	if not cost_gate.get("ok", true):
		return {"ok": false, "message": "Insufficient resources"}

	return {"ok": true, "unexplored": unexplored}

func explore_biome() -> Dictionary:
	"""Explore and unlock a random new biome (4E action)

	Returns:
		Dictionary with:
			- success: bool
			- biome_name: String (if successful)
			- message: String (error or success message)
	"""
	print("🗺️ explore_biome() called!")

	var gate = can_explore_biome()
	if not gate.get("ok", false):
		var msg = gate.get("message", "Biome exploration blocked")
		print("❌ %s" % msg)
		return {"success": false, "blocked": true, "message": msg}

	var observation_frame = get_node_or_null("/root/ObservationFrame")
	if not observation_frame:
		print("❌ ObservationFrame not found")
		return {"success": false, "message": "ObservationFrame not available"}

	# Get unexplored biomes
	var unexplored = gate.get("unexplored", observation_frame.get_unexplored_biomes())
	print("🗺️ Unexplored biomes: %s" % str(unexplored))

	if unexplored.is_empty():
		print("❌ All biomes already explored")
		return {"success": false, "message": "All biomes already explored!"}

	# Pick a random unexplored biome
	var random_index = randi() % unexplored.size()
	var new_biome = unexplored[random_index]
	print("🗺️ Selected random biome: %s" % new_biome)

	# Unlock it
	var unlocked = observation_frame.unlock_biome(new_biome)
	if not unlocked:
		print("❌ Failed to unlock biome")
		return {"success": false, "message": "Failed to unlock biome"}
	print("✅ Biome unlocked successfully")

	# Expand grid to accommodate newly explored biome
	refresh_grid_for_biomes()

	# Load the new biome
	print("🗺️ Loading biome dynamically...")
	var biome_loaded = _load_biome_dynamically(new_biome)
	if not biome_loaded:
		print("❌ Biome failed to load")
		return {"success": false, "biome_name": new_biome, "message": "Biome unlocked but failed to load"}
	print("✅ Biome loaded successfully")

	# Sync with ActiveBiomeManager
	var biome_manager = get_node_or_null("/root/ActiveBiomeManager")
	if biome_manager:
		biome_manager.set_biome_order(observation_frame.get_unlocked_biomes())
		print("✅ Synced with ActiveBiomeManager")

	# Switch to the new biome
	if biome_manager:
		var direction = 1  # Slide right (new biome appears)
		biome_manager.set_active_biome(new_biome, direction)
		print("✅ Switched to new biome: %s" % new_biome)

	if economy and not EconomyConstants.commit_action("explore_biome", economy):
		return {"success": false, "biome_name": new_biome, "message": "Explore biome failed: unable to spend cost."}

	print("🗺️ Exploration complete: %s" % new_biome)
	return {"success": true, "biome_name": new_biome, "message": "Discovered %s!" % new_biome}


func _load_biome_dynamically(biome_name: String) -> bool:
	"""Load a biome at runtime via unified BootManager.load_biome().

	This delegates to BootManager to ensure consistent loading sequence:
	1. Load & instantiate
	2. Register with grid
	3. Assign plots
	4. Rebuild operators (CRITICAL: before batcher registration)
	5. Register with batcher
	6. Emit signals

	Idempotent: if already loaded, returns true without re-initializing.
	"""
	var boot_manager = get_node_or_null("/root/BootManager")
	if not boot_manager:
		push_error("BootManager not found")
		return false

	# Ensure grid is sized for the newly explored biome
	refresh_grid_for_biomes()

	var result = boot_manager.load_biome(biome_name, self)
	if not result.get("success", false):
		var error = result.get("message", "Unknown error")
		push_error("Failed to load biome '%s': %s" % [biome_name, error])
		return false

	# Print success message
	var already = result.get("already_loaded", false)
	if not already:
		print("🗺️ Dynamically loaded and registered biome: %s" % biome_name)


	return true


func _assign_plots_for_biome(biome_name: String) -> void:
	"""Assign grid plots to a newly loaded biome based on GridConfig."""
	if not grid or not grid_config:
		return
	if not grid.has_method("assign_plot_to_biome"):
		return
	for pos in grid_config.biome_assignments:
		if grid_config.biome_assignments[pos] == biome_name:
			grid.assign_plot_to_biome(pos, biome_name)


func do_action(action: String, params: Dictionary) -> Dictionary:
	"""Universal action dispatcher - routes to appropriate method

	Supported actions:
	- entangle: {position_a, position_b} → entangles two plots
	- measure: {position} → measures plot
	- harvest: {position} → harvests plot

	Returns: Dictionary with {success: bool, message: String, ...action-specific data}
	"""
	match action:
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

	if outcome != "":
		plot_measured.emit(pos, outcome)
		_emit_state_changed()
		action_result.emit("measure", true, "Measured: %s collapsed!" % outcome)
	else:
		action_result.emit("measure", false, "Measurement failed")
	return outcome


func harvest_plot(pos: Vector2i) -> Dictionary:
	"""Harvest measured plot - collect yield

	Returns: Dictionary with {success: bool, outcome: String, yield: int}
	Emits: plot_harvested signal with yield data
	"""
	if not grid or not economy:
		return {"success": false}

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
	if terminal_pool:
		for terminal in terminal_pool.get_active_terminals():
			if terminal.grid_position != Vector2i(-1, -1):
				if measure_plot(terminal.grid_position) != "":
					measured_count += 1

	action_result.emit("measure_all", true, "Measured %d plots" % measured_count)
	return measured_count


func harvest_all() -> int:
	"""Harvest all measured plots

	Returns: number of plots harvested
	"""
	var harvested_count = 0
	if terminal_pool:
		for terminal in terminal_pool.get_measured_terminals():
			if terminal.grid_position != Vector2i(-1, -1):
				var result = harvest_plot(terminal.grid_position)
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
		if plot and plot.is_active() and not plot.get_is_measured():
			measure_plot(pos)
		var harvest_result = harvest_plot(pos)
		if harvest_result.get("success", false):
			total_yield += harvest_result.get("yield", 0)
			return true
		return false

	var result = _batch_operation(positions, "Harvested", harvest_op)
	result["total_yield"] = total_yield
	return result


func get_plot(position: Vector2i):
	"""Get plot at given grid position (returns FarmPlot or subclass)"""
	if grid:
		return grid.get_plot(position)
	return null


func get_state() -> Dictionary:
	"""Get complete game state snapshot for serialization"""
	if not grid or not economy:
		return {}

	var state = {
		"economy": economy.get_all_resources(),
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
	var IconRegistryScript = load("res://Core/QuantumSubstrate/_icon_registry.gd")
	if not IconRegistryScript:
		push_error("Failed to load _icon_registry.gd!")
		return

	icon_registry = IconRegistryScript.new()
	icon_registry.name = "IconRegistry"
	# Use get_tree() if available (normal mode), otherwise skip autoload simulation
	var tree = get_tree()
	if tree and tree.root:
		tree.root.add_child(icon_registry)
		icon_registry._ready()  # Trigger initialization
		if _verbose:
			_verbose.info("test", "✓", "Test mode: IconRegistry initialized with %d icons" % icon_registry.icons.size())
	else:
		# Headless mode without scene tree - just initialize locally
		icon_registry._ready()
		if _verbose:
			_verbose.info("test", "✓", "Headless mode: IconRegistry initialized with %d icons" % icon_registry.icons.size())


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
			var shortfall = (need - have) / EconomyConstants.QUANTUM_TO_CREDITS
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
		quantum_energy = float(yield_amount) / float(EconomyConstants.QUANTUM_TO_CREDITS)

	if outcome_emoji.is_empty():
		return

	# Generic routing: any emoji → its credits
	var credits_earned = economy.receive_harvest(outcome_emoji, quantum_energy, "harvest")


func _emit_state_changed() -> void:
	"""Emit state_changed signal with current game state"""
	state_changed.emit(get_state())


func _on_economy_changed(_value) -> void:
	"""Handle economy signal"""
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
