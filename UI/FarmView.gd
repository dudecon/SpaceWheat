## FarmView - UI entry point
## Farm is owned/created by GameStateManager; FarmView only attaches UI.

extends Control

const BathQuantumViz = preload("res://Core/Visualization/BathQuantumVisualizationController.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const BiomeBackgroundClass = preload("res://Core/Visualization/BiomeBackground.gd")
const PerformanceHUDClass = preload("res://UI/Overlays/PerformanceHUD.gd")
# BootManager is an autoload singleton - no need to preload

var shell = null  # PlayerShell (from scene)
var farm: Node = null
var quantum_viz: BathQuantumViz = null
var biome_background: Control = null  # BiomeBackground for full-screen biome art
var performance_hud: Control = null  # Performance profiling overlay

# Helpers to access autoloads safely (avoids compile-time errors in tests)
@onready var _verbose = get_node("/root/VerboseConfig")
@onready var _boot_mgr = get_node("/root/BootManager")


func _ready():
	"""Initialize: boot core systems, then attach UI"""
	_verbose.info("ui", "🌾", "FarmView starting...")

	# DEBUG: Check if FarmView is properly sized
	_verbose.debug("ui", "📏", "FarmView size: %.0f × %.0f" % [size.x, size.y])
	_verbose.debug("ui", "", "FarmView anchors: L%.1f T%.1f R%.1f B%.1f" % [anchor_left, anchor_top, anchor_right, anchor_bottom])
	_verbose.debug("ui", "", "Viewport: %.0f × %.0f" % [get_viewport_rect().size.x, get_viewport_rect().size.y])

	# Detect headless mode early
	var is_headless = DisplayServer.get_name() == "headless"

	# ═══════════════════════════════════════════════════════════════════════
	# BOOT CORE (GameStateManager owns Farm)
	# ═══════════════════════════════════════════════════════════════════════
	farm = await _boot_mgr.boot_core(-1, "default", is_headless)
	if not farm:
		_verbose.warn("ui", "❌", "Farm not available after core boot")
		return

	# Reparent FarmView under Farm (UI lives under simulation)
	if get_parent() != farm:
		var parent = get_parent()
		if parent:
			parent.remove_child(self)
		farm.add_child(self)
		if get_tree().current_scene == self:
			get_tree().current_scene = farm

	# ═══════════════════════════════════════════════════════════════════════
	# SKIP ALL UI SETUP IN HEADLESS MODE (prevents GPU initialization)
	# ═══════════════════════════════════════════════════════════════════════
	if is_headless:
		_verbose.info("ui", "🎯", "Headless mode detected - skipping UI/visualization")
		return

	# ═══════════════════════════════════════════════════════════════════════
	# BIOME BACKGROUND - Full-screen biome art (behind everything)
	# ═══════════════════════════════════════════════════════════════════════
	_verbose.debug("ui", "🖼️", "Creating biome background layer...")
	var bg_layer = CanvasLayer.new()
	bg_layer.layer = -1  # Behind layer 0 (all other UI)
	bg_layer.name = "BiomeBackgroundLayer"
	add_child(bg_layer)

	biome_background = BiomeBackgroundClass.new()
	biome_background.name = "BiomeBackground"
	bg_layer.add_child(biome_background)
	_verbose.info("ui", "✅", "Biome background created (CanvasLayer -1)")

	# Load PlayerShell scene
	_verbose.debug("ui", "🎪", "Loading player shell scene...")
	var shell_scene = load("res://UI/PlayerShell.tscn")
	if shell_scene:
		shell = shell_scene.instantiate()
		add_child(shell)
		_verbose.info("ui", "✅", "Player shell loaded and added to tree")
	else:
		_verbose.warn("ui", "❌", "PlayerShell.tscn not found!")
		return

	# Create quantum visualization
	_verbose.debug("ui", "🛁", "Creating bath-first quantum visualization...")
	quantum_viz = BathQuantumViz.new()

	# Add directly to scene tree - no CanvasLayer needed
	# Set z_index low so it renders behind UI and overlays
	add_child(quantum_viz)
	quantum_viz.z_index = -100  # Behind everything (plots are -10, overlays are 1000+)

	# Create performance HUD overlay
	_verbose.debug("ui", "🔬", "Creating performance profiling HUD...")
	performance_hud = PerformanceHUDClass.new()
	add_child(performance_hud)
	performance_hud.z_index = 2000  # Above all UI
	_verbose.info("ui", "✅", "Performance HUD created")

	# ═══════════════════════════════════════════════════════════════════════
	# PRE-BOOT: Signal connections needed before game starts
	# ═══════════════════════════════════════════════════════════════════════

	# CRITICAL: Connect visualization signals BEFORE boot emits game_ready
	# Otherwise EXPLORE will emit plot_planted before viz is connected to listen
	if quantum_viz:
		# ALWAYS connect - connect_to_farm handles missing biomes gracefully
		quantum_viz.connect_to_farm(farm)
	else:
		push_error("FarmView: quantum_viz is NULL - cannot connect to farm!")

	# ═══════════════════════════════════════════════════════════════════════
	# BOOT UI - Visualization + UI setup after core is ready
	# ═══════════════════════════════════════════════════════════════════════
	_verbose.info("farm", "🚀", "Starting UI Boot Sequence...")
	await _boot_mgr.boot_ui(farm, shell, quantum_viz)
	_verbose.info("farm", "✅", "UI Boot Sequence complete")

	# ═══════════════════════════════════════════════════════════════════════
	# POST-BOOT: Additional signal connections and final setup
	# ═══════════════════════════════════════════════════════════════════════

	# Reconnect to PlotGridDisplay now that it's created during boot_ui
	if quantum_viz and quantum_viz.has_method("_connect_to_plot_grid_display"):
		quantum_viz._connect_to_plot_grid_display()
		_verbose.info("ui", "✅", "PlotGridDisplay reconnected to visualization")

	# Connect touch gesture signals from QuantumForceGraph
	if quantum_viz and quantum_viz.graph:
		var swipe_result = quantum_viz.graph.node_swiped_to.connect(_on_quantum_nodes_swiped)
		if swipe_result != OK:
			_verbose.warn("ui", "⚠️", "Failed to connect node_swiped_to signal")
		else:
			_verbose.info("ui", "✅", "Touch: Swipe-to-entangle connected")

		var click_result = quantum_viz.graph.node_clicked.connect(_on_quantum_node_clicked)
		if click_result != OK:
			_verbose.warn("ui", "⚠️", "Failed to connect node_clicked signal")
		else:
			_verbose.info("ui", "✅", "Touch: Tap-to-measure connected")

	# Input is handled by PlayerShell._input() → modal stack → QuantumInstrumentInput
	# No need for InputController anymore!
	_verbose.info("ui", "✅", "Input routing handled by PlayerShell modal stack")

	_verbose.info("ui", "✅", "FarmView ready - game started!")


func _on_quit_requested() -> void:
	"""Handle quit request"""
	_verbose.info("ui", "🛑", "Quit requested - exiting game")
	get_tree().quit()


func _on_restart_requested() -> void:
	"""Handle restart request"""
	_verbose.info("ui", "🔄", "Restart requested - reloading scene")
	# Reset music completely before reloading
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").reset()
	get_tree().reload_current_scene()


func _on_overlay_state_changed(overlay_name: String, visible: bool) -> void:
	"""Handle overlay state changes (if needed for future features)"""
	# Input is now handled by PlayerShell modal stack - no sync needed
	pass


func _on_quantum_node_clicked(grid_pos: Vector2i, button_index: int) -> void:
	"""Handle tap gesture on quantum bubble - TAP TO MEASURE/POP (v2 Terminal system)

	Triggered when user taps a quantum bubble (short press <50px distance).
	Uses Terminal-based architecture (EXPLORE → MEASURE → POP):
	- Bound but not measured → MEASURE (collapse quantum state)
	- Measured → POP (harvest and return terminal to pool)
	"""
	_verbose.debug("ui", "🎯", "BUBBLE TAP HANDLER CALLED! Grid pos: %s, button: %d" % [grid_pos, button_index])

	if not farm or not farm.plot_pool:
		_verbose.warn("ui", "⚠️", "No farm or plot_pool available")
		return

	# v2: Look up terminal by grid position
	var terminal = farm.plot_pool.get_terminal_at_grid_pos(grid_pos)
	if not terminal:
		_verbose.warn("ui", "⚠️", "No terminal bound at %s" % grid_pos)
		return

	# Get biome for this position (needed for MEASURE)
	var biome = farm.grid.get_biome_for_plot(grid_pos) if farm.grid else null

	# Bubble tap action: measure or pop (Ensemble Model)
	if not terminal.is_measured:
		# MEASURE: Sample from ensemble, drain ρ, record claim
		_verbose.debug("ui", "→", "MEASURING terminal at %s" % grid_pos)
		var result = ProbeActions.action_measure(terminal, biome, farm.economy)
		if result.success:
			var prob = result.recorded_probability
			var drained = result.was_drained
			_verbose.info("ui", "📊", "Measured: %s (%.1f%% recorded, drained=%s)" % [
				result.outcome, prob * 100, drained
			])
			# Emit with recorded probability for visualization
			farm.plot_measured.emit(grid_pos, result.outcome)
		else:
			_verbose.warn("ui", "⚠️", "Measure failed: %s" % result.get("message", "unknown"))
	else:
		# POP: Convert recorded probability to credits with purity and neighbor bonuses
		_verbose.debug("ui", "→", "POPPING terminal at %s" % grid_pos)
		var result = ProbeActions.action_pop(terminal, farm.plot_pool, farm.economy, farm)
		if result.success:
			var credits = result.credits
			var purity = result.get("purity", 1.0)
			var neighbors = result.get("neighbor_count", 4)
			_verbose.info("ui", "🎉", "Popped: %s → %.1f credits (purity: %.2f, neighbors: %d)" % [result.resource, credits, purity, neighbors])
			farm.plot_harvested.emit(grid_pos, {
				"emoji": result.resource,
				"credits": credits,
				"purity": purity,
				"neighbors": neighbors
			})
		else:
			_verbose.warn("ui", "⚠️", "Pop failed: %s" % result.get("message", "unknown"))


func _on_quantum_nodes_swiped(from_grid_pos: Vector2i, to_grid_pos: Vector2i) -> void:
	"""Handle swipe gesture between quantum bubbles - SWIPE TO ENTANGLE

	Triggered when user drags from one bubble to another (≥50px, ≤1.0s).
	Creates quantum entanglement between the two plots.
	"""
	_verbose.debug("ui", "✨", "BUBBLE SWIPE HANDLER CALLED! %s → %s" % [from_grid_pos, to_grid_pos])

	if not farm or not farm.grid:
		_verbose.warn("ui", "⚠️", "No farm available")
		return

	# Create entanglement using default Bell state (phi_plus)
	# TODO: Add Bell state selection dialog for advanced control
	var bell_state = "phi_plus"
	var success = farm.grid.create_entanglement(from_grid_pos, to_grid_pos, bell_state)

	if success:
		_verbose.info("ui", "✅", "Entanglement created: %s ↔ %s (Φ+)" % [from_grid_pos, to_grid_pos])
	else:
		_verbose.warn("ui", "❌", "Failed to create entanglement")


func get_farm() -> Node:
	"""Get the current farm (for external access)"""
	return farm


func get_shell() -> Node:
	"""Get the shell (for external access)"""
	return shell
