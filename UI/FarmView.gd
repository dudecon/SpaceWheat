## FarmView - Simplified entry point
## Creates the farm and loads it into PlayerShell
##
## This used to be 50+ lines of orchestration.
## Now it's just: create farm, load into shell.

extends Control

const Farm = preload("res://Core/Farm.gd")
const BathQuantumViz = preload("res://Core/Visualization/BathQuantumVisualizationController.gd")
# BootManager is an autoload singleton - no need to preload

var shell = null  # PlayerShell (from scene)
var farm: Node = null
var quantum_viz: BathQuantumViz = null

# Helpers to access autoloads safely (avoids compile-time errors in tests)
@onready var _verbose = get_node("/root/VerboseConfig")
@onready var _boot_mgr = get_node("/root/BootManager")
@onready var _game_state = get_node("/root/GameStateManager")


func _ready() -> void:
	"""Initialize: create farm and shell, wire them together"""
	_verbose.info("ui", "🌾", "FarmView starting...")

	# DEBUG: Check if FarmView is properly sized
	_verbose.debug("ui", "📏", "FarmView size: %.0f × %.0f" % [size.x, size.y])
	_verbose.debug("ui", "", "FarmView anchors: L%.1f T%.1f R%.1f B%.1f" % [anchor_left, anchor_top, anchor_right, anchor_bottom])
	_verbose.debug("ui", "", "Viewport: %.0f × %.0f" % [get_viewport_rect().size.x, get_viewport_rect().size.y])

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

	# Create farm (synchronous)
	_verbose.info("farm", "📝", "Creating farm...")
	farm = Farm.new()
	add_child(farm)
	_verbose.info("farm", "✅", "Farm created and added to tree")

	# Register farm with GameStateManager for save/load (if available)
	if _game_state:
		_game_state.active_farm = farm
		_verbose.info("farm", "✅", "Farm registered with GameStateManager")
	else:
		_verbose.warn("farm", "⚠️", "GameStateManager not available (test mode)")

	# Wait for farm._ready() to complete
	await get_tree().process_frame
	await get_tree().process_frame

	# Create quantum visualization
	_verbose.debug("ui", "🛁", "Creating bath-first quantum visualization...")
	quantum_viz = BathQuantumViz.new()

	# Add to same CanvasLayer as UI (layer 0) so we can control z_index
	var viz_layer = CanvasLayer.new()
	viz_layer.layer = 0  # Same layer as UI - use z_index for ordering
	add_child(viz_layer)
	viz_layer.add_child(quantum_viz)

	# Set z_index to be above plots (-10) but below farm UI (100)
	quantum_viz.z_index = 50  # Between plots and UI

	# Add biomes to visualization (if available)
	if farm.biome_enabled:
		if farm.biotic_flux_biome:
			quantum_viz.add_biome("BioticFlux", farm.biotic_flux_biome)
		if farm.forest_biome:
			quantum_viz.add_biome("Forest", farm.forest_biome)
		if farm.market_biome:
			quantum_viz.add_biome("Market", farm.market_biome)
		if farm.kitchen_biome:
			quantum_viz.add_biome("Kitchen", farm.kitchen_biome)

	# ═══════════════════════════════════════════════════════════════════════
	# CLEAN BOOT SEQUENCE - Explicit multi-phase initialization
	# ═══════════════════════════════════════════════════════════════════════
	_verbose.info("farm", "🚀", "Starting Clean Boot Sequence...")
	await _boot_mgr.boot(farm, shell, quantum_viz)
	_verbose.info("farm", "✅", "Clean Boot Sequence complete")

	# ═══════════════════════════════════════════════════════════════════════
	# POST-BOOT: Signal connections and final setup
	# ═══════════════════════════════════════════════════════════════════════

	# Connect visualization signals to farm (plot-driven bubble spawning)
	if farm.biome_enabled and quantum_viz:
		quantum_viz.connect_to_farm(farm)

		# Connect touch gesture signals from QuantumForceGraph
		if quantum_viz.graph:
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

	# Input is now handled by PlayerShell._input() → modal stack → FarmInputHandler._unhandled_input()
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
	get_tree().reload_current_scene()


func _on_overlay_state_changed(overlay_name: String, visible: bool) -> void:
	"""Handle overlay state changes (if needed for future features)"""
	# Input is now handled by PlayerShell modal stack - no sync needed
	pass


func _on_quantum_node_clicked(grid_pos: Vector2i, button_index: int) -> void:
	"""Handle tap gesture on quantum bubble - TAP TO MEASURE/HARVEST

	Triggered when user taps a quantum bubble (short press <50px distance).
	Performs contextual action based on plot state:
	- Empty plot → Plant (if tool supports it)
	- Planted/unmeasured → MEASURE (collapse quantum state)
	- Measured → HARVEST
	"""
	_verbose.debug("ui", "🎯", "BUBBLE TAP HANDLER CALLED! Grid pos: %s, button: %d" % [grid_pos, button_index])

	if not farm or not farm.grid:
		_verbose.warn("ui", "⚠️", "No farm available")
		return

	var plot = farm.grid.get_plot(grid_pos)
	if not plot:
		_verbose.warn("ui", "⚠️", "No plot at %s" % grid_pos)
		return

	# Contextual action based on plot state
	if not plot.is_planted:
		_verbose.debug("ui", "→", "Plot empty - planting wheat")
		farm.plant_wheat(grid_pos)
	elif not plot.has_been_measured:
		_verbose.debug("ui", "→", "Plot planted - MEASURING quantum state")
		farm.measure_plot(grid_pos)
	else:
		_verbose.debug("ui", "→", "Plot measured - HARVESTING")
		farm.harvest_plot(grid_pos)


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
