class_name BathQuantumVisualizationController
extends Node2D

## Bath-First Quantum Visualization Controller
## Visualizes quantum BATHS (not individual qubits)
## Each bubble represents one BASIS STATE (emoji) in a biome's bath
## Bubble size scales with probability using power law for better differentiation
##
## Usage:
##   var viz = BathQuantumVisualizationController.new()
##   add_child(viz)
##   viz.add_biome("BioticFlux", biotic_flux_biome)
##   viz.add_biome("Forest", forest_biome)
##   viz.initialize()

const QuantumForceGraph = preload("res://Core/Visualization/QuantumForceGraph.gd")
const QuantumNode = preload("res://Core/Visualization/QuantumNode.gd")
const FarmPlot = preload("res://Core/GameMechanics/FarmPlot.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

# Logging - access autoload safely
@onready var _verbose = get_node("/root/VerboseConfig")

# Graph engine
var graph: Node2D = null

# Biomes to visualize (name → biome reference)
var biomes: Dictionary = {}

# Farm reference (for plot-to-biome lookups)
var farm_ref = null

# Plot selection tracking (synced with PlotGridDisplay)
var plot_grid_display_ref = null
var selected_plot_positions: Dictionary = {}  # Vector2i -> true (which plots are selected)

# Basis state bubbles (biome_name → Array[QuantumNode])
# V2.2 Architecture: This is REDUNDANT with graph.quantum_nodes
# Kept for backward compatibility but should be phased out
# Primary lookup should use graph.quantum_nodes_by_grid_pos
var basis_bubbles: Dictionary = {}

# Requested emojis per biome (biome_name → Array[String])
# Only emojis that plots have requested will have bubbles
# DEPRECATED: Legacy basis state bubbles - v2 uses terminal-driven bubbles
var requested_emojis: Dictionary = {}

# Emoji to bubble mapping for quick lookup (biome_name → {emoji → QuantumNode})
# DEPRECATED: Not used in v2 architecture - use graph.quantum_nodes_by_grid_pos
var emoji_to_bubble: Dictionary = {}

# Visual tuning (power law scaling for better differentiation at low probabilities)
var base_bubble_size: float = 8.0   # Small minimum so tiny probabilities are visible
var size_scale: float = 60.0        # Scale factor for probability → radius
var size_exponent: float = 0.3      # Power law: prob^0.3 gives differentiation at low end

# Force parameters
var skating_rink_strength: float = 150.0

# Cached layout info
var stored_center: Vector2
var stored_radius: float


func _ready() -> void:
	"""Set up basic properties - call initialize() after adding biomes"""
	# Position at origin (Node2D doesn't use anchors)
	position = Vector2.ZERO
	set_process(true)


func add_biome(biome_name: String, biome_ref) -> void:
	"""Register a biome for visualization

	Args:
		biome_name: Identifier for the biome (e.g., "BioticFlux", "Forest")
		biome_ref: BiomeBase instance with bath mode enabled
	"""
	if not biome_ref:
		push_warning("BathQuantumViz: null biome reference for %s" % biome_name)
		return

	# All biomes must have visualization payload (Model C)
	if not biome_ref.viz_cache or not biome_ref.viz_cache.has_metadata():
		push_warning("BathQuantumViz: biome %s has no viz payload" % biome_name)
		return

	biomes[biome_name] = biome_ref
	if _verbose:
		var qubits = biome_ref.viz_cache.get_num_qubits() if ("viz_cache" in biome_ref) else 0
		_verbose.debug("viz", "🛁", "BathQuantumViz: Added biome '%s' with %d qubits (Model C)" % [biome_name, qubits])


func initialize() -> void:
	"""Initialize visualization after all biomes are added

	Call this after add_biome() for all biomes. Creates graph, computes layout,
	spawns basis state bubbles.
	"""
	if biomes.is_empty():
		push_warning("BathQuantumViz: No biomes registered - visualization disabled")
		return

	if _verbose:
		_verbose.debug("viz", "🛁", "BathQuantumViz: Initializing with %d biomes..." % biomes.size())

	# Create graph engine
	graph = QuantumForceGraph.new()
	add_child(graph)
	await get_tree().process_frame

	# Register biomes with graph BEFORE layout calculation
	for biome_name in biomes:
		graph.biomes[biome_name] = biomes[biome_name]

	# CRITICAL: Let update_layout() compute center/radius from actual viewport
	# This will handle small viewports correctly (e.g., 64×64 in headless mode)
	graph.lock_dimensions = false
	graph.update_layout(true)  # Force layout calculation before first _draw()

	# Cache the computed values for reference
	stored_center = graph.center_position
	stored_radius = graph.graph_radius

	# Initialize tracking structures (but don't create bubbles yet - wait for requests)
	for biome_name in biomes:
		requested_emojis[biome_name] = []
		emoji_to_bubble[biome_name] = {}
		basis_bubbles[biome_name] = []

	# CRITICAL: Connect to ActiveBiomeManager for biome switching
	# This ensures bubbles filter when user switches biomes via tab bar or keyboard
	_connect_to_biome_manager()

	graph.set_process(true)
	_sync_bound_terminals()

	if _verbose:
		_verbose.debug("viz", "✅", "BathQuantumViz: Ready (plot-driven mode - bubbles will spawn on demand)")
		_verbose.debug("viz", "📍", "Position: %s" % position)
		_verbose.debug("viz", "📊", "QuantumForceGraph exists: %s" % (graph != null))
		if graph:
			_verbose.debug("viz", "📊", "QuantumForceGraph center: %s, radius: %.1f" % [graph.center_position, graph.graph_radius])


func _connect_to_biome_manager() -> void:
	"""Connect to ActiveBiomeManager for single-biome view filtering.

	When user switches biomes via tab bar or keyboard (7/8/9/0),
	this ensures the quantum bubbles filter to show only the active biome.
	"""
	var biome_mgr = get_node_or_null("/root/ActiveBiomeManager")
	if biome_mgr and biome_mgr.has_signal("active_biome_changed"):
		if not biome_mgr.active_biome_changed.is_connected(_on_active_biome_changed):
			biome_mgr.active_biome_changed.connect(_on_active_biome_changed)
			if _verbose:
				_verbose.debug("viz", "📡", "BathQuantumViz connected to ActiveBiomeManager")

			# Apply initial biome filter
			var initial_biome = biome_mgr.get_active_biome()
			if graph and initial_biome != "":
				graph.set_active_biome(initial_biome)
				if _verbose:
					_verbose.debug("viz", "🔄", "Initial biome filter applied: %s" % initial_biome)
	else:
		push_warning("BathQuantumViz: ActiveBiomeManager not found - bubbles won't filter on biome switch")


func _on_active_biome_changed(new_biome: String, _old_biome: String) -> void:
	"""Handle biome change - filter bubbles to show only active biome."""
	if graph:
		graph.set_active_biome(new_biome)
		if _verbose:
			_verbose.debug("viz", "🔄", "BathQuantumViz: Biome changed to %s - bubbles filtered" % new_biome)


func _connect_to_plot_grid_display() -> void:
	"""Connect to PlotGridDisplay for selection-based bubble rendering.

	ARCHITECTURE: Bubbles only render for plots that are BOTH:
	1. Selected (checkmark in PlotGridDisplay)
	2. Explored (terminal bound to register)

	This ties visualization directly to UI selection state.
	"""
	# Find PlotGridDisplay in scene tree
	# It's typically under PlayerShell -> QuantumInstrument -> PlotGridDisplay
	if not farm_ref:
		if _verbose:
			_verbose.debug("viz", "⚠️", "Cannot connect to PlotGridDisplay - no farm_ref")
		return

	# Try to find PlotGridDisplay via common paths
	var shell = get_tree().get_first_node_in_group("player_shell")
	if shell:
		plot_grid_display_ref = shell.get_node_or_null("QuantumInstrument/PlotGridDisplay")

	if not plot_grid_display_ref:
		# Fallback: search entire tree
		plot_grid_display_ref = get_tree().get_first_node_in_group("plot_grid_display")

	if plot_grid_display_ref:
		# Connect to selection signals
		if plot_grid_display_ref.has_signal("plot_selection_changed"):
			plot_grid_display_ref.plot_selection_changed.connect(_on_plot_selection_changed)
			if _verbose:
				_verbose.info("viz", "📡", "Connected to PlotGridDisplay.plot_selection_changed")

		# Sync initial selection state
		if plot_grid_display_ref.has_method("get_selected_plots"):
			var selected = plot_grid_display_ref.get_selected_plots()
			for pos in selected:
				selected_plot_positions[pos] = true
			if _verbose:
				_verbose.info("viz", "✅", "Synced initial plot selection: %d plots selected (positions: %s)" % [selected.size(), selected])

		# Also sync selected_plots dictionary directly for debugging
		if "selected_plots" in plot_grid_display_ref:
			if _verbose:
				_verbose.info("viz", "🔍", "PlotGridDisplay.selected_plots has %d entries: %s" % [
					plot_grid_display_ref.selected_plots.size(),
					plot_grid_display_ref.selected_plots.keys()
				])
	else:
		if _verbose:
			_verbose.warn("viz", "⚠️", "PlotGridDisplay not found - selection-based filtering disabled")


func _on_plot_selection_changed(position: Vector2i, is_selected: bool) -> void:
	"""Handle plot selection change - show/hide bubble based on selection state.

	Args:
		position: Grid position of the plot
		is_selected: True if plot was selected, False if deselected
	"""
	print("\n☑️  PLOT SELECTION CHANGED")
	print("  Position: %s" % position)
	print("  Selected: %s" % is_selected)

	# Update selection tracking
	if is_selected:
		selected_plot_positions[position] = true
	else:
		selected_plot_positions.erase(position)

	print("  Total selected: %d" % selected_plot_positions.size())

	# Show/hide bubble based on selection state
	if graph and graph.quantum_nodes_by_grid_pos.has(position):
		var bubble = graph.quantum_nodes_by_grid_pos[position]
		if bubble:
			# Set bubble visibility based on selection
			bubble.visible = is_selected
			print("  ✅ Updated bubble visibility: %s" % is_selected)
			graph.queue_redraw()
		else:
			print("  ⚠️  Bubble exists in lookup but is null")
	else:
		print("  🔍 No bubble at this position yet (will show when created)")


func connect_to_farm(farm) -> void:
	"""Connect to farm signals to auto-request bubbles when terminals are bound

	Args:
		farm: Farm instance with terminal lifecycle signals
	"""
	if _verbose:
		_verbose.debug("viz", "🔌", "BathQuantumViz.connect_to_farm() called")

	if not farm:
		push_warning("BathQuantumViz: null farm reference")
		return

	# Store farm reference for plot-to-biome lookups
	farm_ref = farm

	# CRITICAL: Pass plot_pool to graph for v2 terminal measurement state lookup
	if graph and "plot_pool" in farm and farm.plot_pool:
		graph.plot_pool = farm.plot_pool
		if _verbose:
			_verbose.debug("viz", "📡", "Passed plot_pool to QuantumForceGraph for measured state detection")

	# Pass batched lookahead engine to graph for buffered rendering
	if graph and "biome_evolution_batcher" in farm and farm.biome_evolution_batcher:
		graph.biome_evolution_batcher = farm.biome_evolution_batcher
		if _verbose:
			_verbose.debug("viz", "📡", "Passed biome_evolution_batcher to QuantumForceGraph for lookahead rendering")

	# Connect to terminal lifecycle signals (EXPLORE/MEASURE/POP)
	if farm.has_signal("terminal_bound"):
		farm.terminal_bound.connect(_on_terminal_bound)
		print("\n🔗 SIGNAL CONNECTION SUCCESS")
		print("  Connected BathQuantumViz._on_terminal_bound to farm.terminal_bound")
		print("  Farm: %s" % farm)
		print("  Signal exists: %s\n" % farm.has_signal("terminal_bound"))
	else:
		print("\n❌ SIGNAL CONNECTION FAILED")
		print("  Farm has no terminal_bound signal!")
		print("  Farm: %s\n" % farm)
		push_warning("BathQuantumViz: farm has no terminal_bound signal")

	if farm.has_signal("terminal_measured"):
		farm.terminal_measured.connect(_on_terminal_measured)
		if _verbose:
			_verbose.debug("viz", "📡", "Connected to farm.terminal_measured for bubble state update")
	else:
		push_warning("BathQuantumViz: farm has no terminal_measured signal")

	if farm.has_signal("terminal_released"):
		farm.terminal_released.connect(_on_terminal_released)
		if _verbose:
			_verbose.debug("viz", "📡", "Connected to farm.terminal_released for bubble despawn")
	else:
		push_warning("BathQuantumViz: farm has no terminal_released signal")

	if farm.has_signal("biome_loaded"):
		farm.biome_loaded.connect(_on_biome_loaded)
		if _verbose:
			_verbose.debug("viz", "📡", "Connected to farm.biome_loaded for dynamic biomes")

	# CRITICAL: Connect to PlotGridDisplay for selection-based bubble filtering
	_connect_to_plot_grid_display()

	# If visualization is already initialized, sync any bound terminals now.
	if graph:
		_sync_bound_terminals()


func _on_biome_loaded(biome_name: String, biome_ref) -> void:
	"""Handle dynamically loaded biome - register for visualization."""
	add_biome(biome_name, biome_ref)
	if graph:
		graph.biomes[biome_name] = biome_ref
		graph.update_layout(true)
		graph.queue_redraw()
	if _verbose:
		_verbose.debug("viz", "🧭", "Dynamic biome registered for viz: %s" % biome_name)


func _sync_bound_terminals() -> void:
	"""Ensure bubbles exist for any terminals already bound before viz init."""
	if not graph or not farm_ref or not farm_ref.plot_pool:
		return

	if not farm_ref.grid:
		return

	if not farm_ref.plot_pool.has_method("get_all_terminals"):
		return

	for terminal in farm_ref.plot_pool.get_all_terminals():
		if not terminal or not terminal.is_bound:
			continue
		if graph.quantum_nodes_by_grid_pos.has(terminal.grid_position):
			continue

		var position = terminal.grid_position
		var biome_name = farm_ref.grid.plot_biome_assignments.get(position, "")
		if biome_name.is_empty():
			continue

		var plot = farm_ref.grid.get_plot(position)
		_create_bubble_for_terminal(
			biome_name,
			position,
			terminal.north_emoji if terminal.north_emoji else "?",
			terminal.south_emoji if terminal.south_emoji else "?",
			plot,
			terminal
		)

func _on_terminal_bound(position: Vector2i, terminal_id: String, emoji_pair: Dictionary) -> void:
	"""Handle terminal bound event - spawn bubble when EXPLORE binds a terminal

	V2.2 Architecture: Gets terminal reference and passes it to bubble for
	single source of truth queries.

	Args:
		position: Grid position where terminal is bound
		terminal_id: Unique terminal identifier
		emoji_pair: {north: String, south: String} - the emoji basis states
	"""
	var north_emoji = emoji_pair.get("north", "?")
	var south_emoji = emoji_pair.get("south", "?")

	print("\n" + "=".repeat(70))
	print("🔔 TERMINAL_BOUND SIGNAL RECEIVED")
	print("  Position: %s" % position)
	print("  Terminal ID: %s" % terminal_id)
	print("  Emojis: %s/%s" % [north_emoji, south_emoji])
	print("  farm_ref: %s" % ("EXISTS" if farm_ref else "NULL"))
	print("  graph: %s" % ("EXISTS" if graph else "NULL"))
	print("=".repeat(70) + "\n")

	# Get plot's biome assignment from stored farm reference
	if not farm_ref or not farm_ref.grid:
		print("❌ EARLY EXIT: No farm reference or grid found")
		print("  farm_ref: %s" % farm_ref)
		print("  farm_ref.grid: %s" % (farm_ref.grid if farm_ref else "N/A"))
		return

	var biome_name = farm_ref.grid.plot_biome_assignments.get(position, "")
	print("📍 Biome lookup for position %s:" % position)
	print("  plot_biome_assignments.get(): '%s'" % biome_name)
	print("  Total assignments: %d" % farm_ref.grid.plot_biome_assignments.size())

	if biome_name.is_empty():
		print("  ⚠️  Empty biome name, trying fallback...")
		# FALLBACK: Try to get biome from terminal's bound_biome_name
		# This handles cases where plot_biome_assignments isn't populated yet
		var terminal_temp = farm_ref.plot_pool.get_terminal(terminal_id) if farm_ref.plot_pool else null
		if terminal_temp and not terminal_temp.bound_biome_name.is_empty():
			biome_name = terminal_temp.bound_biome_name
			print("  ✅ Using terminal's biome: %s" % biome_name)
		else:
			print("❌ EARLY EXIT: No biome assignment found")
			print("  terminal_temp: %s" % terminal_temp)
			print("  bound_biome_name: %s" % (terminal_temp.bound_biome_name if terminal_temp else "N/A"))
			return
	else:
		print("  ✅ Found biome: %s" % biome_name)

	if _verbose:
		_verbose.debug("viz", "📍", "Plot at %s assigned to biome: %s" % [position, biome_name])

	# Get the actual plot (needed for entanglement visualization)
	var plot = farm_ref.grid.get_plot(position)

	# V2.2: Get terminal reference from plot_pool (single source of truth)
	# Try multiple lookup methods to ensure we find it
	var terminal = null
	if farm_ref.plot_pool:
		# First try by grid position
		terminal = farm_ref.plot_pool.get_terminal_at_grid_pos(position)
		# If not found, try by terminal_id
		if not terminal:
			terminal = farm_ref.plot_pool.get_terminal(terminal_id)
			if terminal and _verbose:
				_verbose.debug("viz", "🔗", "Found terminal by ID (grid_pos lookup failed)")

	if terminal:
		if _verbose:
			_verbose.debug("viz", "✅", "Terminal reference acquired: %s (is_bound=%s)" % [terminal.terminal_id, terminal.is_bound])
	else:
		if _verbose:
			_verbose.debug("viz", "⚠️", "Could not find terminal %s in plot_pool" % terminal_id)

	# Create bubble with terminal reference (enables state queries)
	# Bubble visibility will be set based on plot selection state
	print("🎨 Calling _create_bubble_for_terminal...")
	print("  biome_name: %s" % biome_name)
	print("  position: %s" % position)
	print("  emojis: %s/%s" % [north_emoji, south_emoji])
	print("  plot: %s" % ("EXISTS" if plot else "NULL"))
	print("  terminal: %s" % ("EXISTS" if terminal else "NULL"))

	_create_bubble_for_terminal(biome_name, position, north_emoji, south_emoji, plot, terminal)

	if graph:
		print("✅ Calling graph.queue_redraw()")
		graph.queue_redraw()
	else:
		print("❌ No graph to redraw!")

	print("=".repeat(70) + "\n")


func _on_terminal_measured(position: Vector2i, terminal_id: String, outcome: String, probability: float) -> void:
	"""Handle terminal measured event - trigger visual update

	V2.2 Architecture: Visualization is READ-ONLY. We do NOT mutate game state.
	The terminal's is_measured flag is the single source of truth.
	Rendering queries terminal.is_measured to determine visual appearance.

	Args:
		position: Grid position of the measured terminal
		terminal_id: Unique terminal identifier
		outcome: The measured emoji outcome
		probability: The recorded probability (for credits on POP)
	"""
	if _verbose:
		_verbose.debug("viz", "📏", "Terminal %s measured at %s → %s (p=%.2f)" % [terminal_id, position, outcome, probability])

	if not graph:
		return

	# Find bubble by grid position
	var bubble = graph.quantum_nodes_by_grid_pos.get(position)
	if bubble:
		# V2.2: Ensure bubble has terminal reference (may have been missed during creation)
		if not bubble.terminal and farm_ref and farm_ref.plot_pool:
			bubble.terminal = farm_ref.plot_pool.get_terminal_at_grid_pos(position)
			if bubble.terminal and _verbose:
				_verbose.debug("viz", "🔗", "Late-bound terminal to bubble at %s" % position)

		# Freeze position for measurement visualization
		if bubble.terminal:
			bubble.frozen_anchor = bubble.position
			bubble.terminal.frozen_position = bubble.position

		# Trigger redraw to update visual appearance
		graph.queue_redraw()
		if _verbose:
			_verbose.debug("viz", "✨", "Bubble at %s visual update triggered (terminal=%s)" % [position, "found" if bubble.terminal else "missing"])
	else:
		if _verbose:
			_verbose.debug("viz", "⚠️", "No bubble found at %s" % position)


func _on_terminal_released(position: Vector2i, terminal_id: String, credits_earned: int) -> void:
	"""Handle terminal released event - despawn bubble when POP releases a terminal

	Args:
		position: Grid position of the released terminal
		terminal_id: Unique terminal identifier
		credits_earned: Credits gained from the harvest
	"""
	if _verbose:
		_verbose.debug("viz", "💰", "Terminal %s released at %s (+%d credits)" % [terminal_id, position, credits_earned])

	if not graph:
		if _verbose:
			_verbose.debug("viz", "⚠️", "No graph found")
		return

	# Find bubble by grid position
	var bubble = graph.quantum_nodes_by_grid_pos.get(position)
	if not bubble:
		if _verbose:
			_verbose.debug("viz", "⚠️", "No bubble found at position %s" % position)
		return

	# CRITICAL: Only remove TERMINAL bubbles, not pure quantum register bubbles
	# Pure quantum bubbles (has_farm_tether=false) should persist after terminal release
	if not bubble.has_farm_tether:
		if _verbose:
			_verbose.debug("viz", "🔄", "Skipping removal of pure quantum bubble at %s" % position)
		return

	# Get biome name for cleanup
	var biome_name = bubble.biome_name

	# Remove terminal bubble from graph tracking
	graph.quantum_nodes_by_grid_pos.erase(position)
	graph.quantum_nodes.erase(bubble)

	# Remove from biome bubble tracking
	if basis_bubbles.has(biome_name):
		basis_bubbles[biome_name].erase(bubble)
		if _verbose:
			_verbose.debug("viz", "🗑️", "Removed terminal bubble from %s (remaining: %d)" % [biome_name, basis_bubbles[biome_name].size()])

	# Trigger redraw to hide bubble
	graph.queue_redraw()
	if _verbose:
		_verbose.debug("viz", "✅", "Terminal bubble despawned at %s" % position)


func request_plot_bubble(biome_name: String, grid_pos: Vector2i, plot) -> void:
	"""Request bubble for a specific plot - PLOT-DRIVEN INTERFACE

	Creates ONE bubble for the plot that shows both emojis in superposition.
	This is how the full game creates bubbles.

	Args:
		biome_name: Which biome this plot belongs to
		grid_pos: Grid position of the plot
		plot: The plot instance (FarmPlot or subclass)
	"""
	if not biomes.has(biome_name):
		push_warning("BathQuantumViz: Unknown biome '%s'" % biome_name)
		return

	var biome = biomes.get(biome_name)
	# Model C: require visualization payload
	if not biome or not biome.viz_cache or not biome.viz_cache.has_metadata():
		return

	# Get emojis from plot (Model C: uses terminal system now)
	# v2 Architecture: Terminals store emojis, not plots. Check both paths:
	var north_emoji = ""
	var south_emoji = ""

	# Try new terminal path first (v2)
	if plot.has_method("get_terminal") and plot.get_terminal():
		var terminal = plot.get_terminal()
		north_emoji = terminal.north_emoji if terminal.north_emoji else ""
		south_emoji = terminal.south_emoji if terminal.south_emoji else ""
	# Fall back to old plot path (v1 compatibility)
	elif plot.is_planted and plot.parent_biome and plot.bath_subplot_id >= 0:
		north_emoji = plot.north_emoji
		south_emoji = plot.south_emoji
	else:
		# Neither path works - skip this bubble
		if _verbose:
			_verbose.debug("viz", "⚠️", "Plot at %s has no terminal or valid plot data" % grid_pos)
		return

	if north_emoji.is_empty():
		if _verbose:
			_verbose.debug("viz", "⚠️", "No emoji data for plot at %s" % grid_pos)
		return

	if _verbose:
		_verbose.debug("viz", "🌱", "Requesting plot bubble at %s: %s/%s" % [grid_pos, north_emoji, south_emoji])

	# Remove any existing bubble at this grid position (from previous harvest cycle)
	if graph.quantum_nodes_by_grid_pos.has(grid_pos):
		var old_bubble = graph.quantum_nodes_by_grid_pos[grid_pos]
		if old_bubble:
			# Remove from graph's node array
			var idx = graph.quantum_nodes.find(old_bubble)
			if idx >= 0:
				graph.quantum_nodes.remove_at(idx)
				if _verbose:
					_verbose.debug("viz", "🗑️", "Removed old bubble at grid %s" % grid_pos)

			# Remove from basis_bubbles array
			if basis_bubbles.has(biome_name):
				var basis_idx = basis_bubbles[biome_name].find(old_bubble)
				if basis_idx >= 0:
					basis_bubbles[biome_name].remove_at(basis_idx)

	# Create ONE bubble for this plot (it will show both emojis via update_from_quantum_state)
	var bubble = _create_plot_bubble(biome_name, grid_pos, plot)

	if bubble:
		basis_bubbles[biome_name].append(bubble)
		graph.quantum_nodes.append(bubble)  # Add to graph for rendering!
		graph.quantum_nodes_by_grid_pos[grid_pos] = bubble  # Index by grid pos
		if _verbose:
			_verbose.debug("viz", "🔵", "Created plot bubble (%s/%s) at grid %s" % [north_emoji, south_emoji, grid_pos])

		# Trigger graph redraw to show new bubble
		graph.queue_redraw()


func request_emoji_bubble(biome_name: String, emoji: String) -> void:
	"""Request a bubble for a specific emoji in a biome (LEGACY - basis state bubbles)

	This creates "floating" bubbles not associated with any plot.
	Use request_plot_bubble() for plot-driven bubbles instead.

	Args:
		biome_name: Which biome bath to project from
		emoji: The emoji to create a bubble for
	"""
	if not biomes.has(biome_name):
		push_warning("BathQuantumViz: Unknown biome '%s'" % biome_name)
		return

	var biome = biomes[biome_name]
	if not biome or not biome.viz_cache or not biome.viz_cache.has_metadata():
		return

	# Skip if already requested
	if requested_emojis[biome_name].has(emoji):
		return

	# Mark as requested
	requested_emojis[biome_name].append(emoji)

	# Create the bubble (with dummy grid position for basis state bubbles)
	var bubble = _create_single_bubble(biome_name, emoji, Vector2i(0, 0))
	if bubble:
		basis_bubbles[biome_name].append(bubble)
		emoji_to_bubble[biome_name][emoji] = bubble
		if _verbose:
			_verbose.debug("viz", "🔵", "Created bubble for %s in %s (total: %d)" % [emoji, biome_name, basis_bubbles[biome_name].size()])


func _create_plot_bubble(biome_name: String, grid_pos: Vector2i, plot) -> QuantumNode:
	"""Create a bubble associated with a specific plot

	This is the plot-driven version - the bubble knows which plot it belongs to.
	The bubble's emojis will be set by update_from_quantum_state() from the plot's qubit.

	Args:
		biome_name: Which biome bath to project from
		grid_pos: Grid position of the plot this bubble represents
		plot: The actual plot instance (for quantum_state reference)

	Returns: The created QuantumNode, or null if creation failed
	"""
	var biome = biomes.get(biome_name)
	# Model C: require visualization payload
	if not biome or not biome.viz_cache or not biome.viz_cache.has_metadata():
		return null

	# Determine initial position (scatter around oval perimeter)
	var initial_pos = stored_center
	var oval = graph.layout_calculator.get_biome_oval(biome_name)
	if not oval.is_empty():
		var center = oval.get("center", stored_center)
		var semi_a = oval.get("semi_a", 100.0)
		var semi_b = oval.get("semi_b", 60.0)

		# Random angle for initial scatter
		var angle = randf() * TAU
		initial_pos = center + Vector2(
			semi_a * cos(angle) * 0.7,
			semi_b * sin(angle) * 0.7
		)

	# Create QuantumNode bubble (with REAL grid position from plot!)
	var bubble = QuantumNode.new(plot, initial_pos, grid_pos, stored_center)
	bubble.biome_name = biome_name

	# NOTE: Constructor calls update_from_quantum_state() which sets color from coherence
	# Do NOT overwrite color here - let quantum state determine it

	return bubble


func _create_bubble_for_terminal(biome_name: String, grid_pos: Vector2i, north_emoji: String, south_emoji: String, plot = null, terminal = null) -> void:
	"""Create a bubble for a terminal (v2.2 architecture)

	V2.2: Now accepts terminal reference for single source of truth.
	Bubble queries terminal for is_measured, emoji_pair, etc.

	Args:
		biome_name: Which biome this terminal belongs to
		grid_pos: Grid position for tethering
		north_emoji: North pole emoji
		south_emoji: South pole emoji
		plot: Optional FarmPlot reference (enables entanglement visualization)
		terminal: Terminal instance (v2.2 - single source of truth)
	"""
	print("🏗️  _create_bubble_for_terminal ENTRY")
	print("  biome_name: %s" % biome_name)
	print("  grid_pos: %s" % grid_pos)

	if not biomes.has(biome_name):
		print("❌ EARLY EXIT: Unknown biome '%s'" % biome_name)
		print("  Available biomes: %s" % biomes.keys())
		return

	var biome = biomes.get(biome_name)
	if not biome or not biome.viz_cache or not biome.viz_cache.has_metadata():
		print("❌ EARLY EXIT: Biome %s has no viz payload" % biome_name)
		print("  biome: %s" % biome)
		print("  viz_cache: %s" % (biome.viz_cache if biome else "N/A"))
		return

	if not graph or not graph.layout_calculator:
		print("❌ EARLY EXIT: graph or layout_calculator not initialized")
		print("  graph: %s" % graph)
		print("  layout_calculator: %s" % (graph.layout_calculator if graph else "N/A"))
		return

	print("  ✅ Passed all early exit checks")

	# Determine initial position (scatter around biome oval)
	var initial_pos = stored_center
	var oval = graph.layout_calculator.get_biome_oval(biome_name)
	if not oval.is_empty():
		var center = oval.get("center", stored_center)
		var semi_a = oval.get("semi_a", 100.0)
		var semi_b = oval.get("semi_b", 60.0)
		var angle = randf() * TAU
		initial_pos = center + Vector2(
			semi_a * cos(angle) * 0.7,
			semi_b * sin(angle) * 0.7
		)

	# Remove old bubble at this position if exists
	if graph.quantum_nodes_by_grid_pos.has(grid_pos):
		var old_bubble = graph.quantum_nodes_by_grid_pos[grid_pos]
		if old_bubble:
			var idx = graph.quantum_nodes.find(old_bubble)
			if idx >= 0:
				graph.quantum_nodes.remove_at(idx)
			# Also remove from node_by_plot_id if it had a plot
			if old_bubble.plot_id and graph.node_by_plot_id.has(old_bubble.plot_id):
				graph.node_by_plot_id.erase(old_bubble.plot_id)
			if basis_bubbles.has(biome_name):
				var bidx = basis_bubbles[biome_name].find(old_bubble)
				if bidx >= 0:
					basis_bubbles[biome_name].remove_at(bidx)

	# Create bubble with plot reference (enables entanglement line drawing)
	var bubble = QuantumNode.new(plot, initial_pos, grid_pos, stored_center)
	bubble.biome_name = biome_name
	bubble.emoji_north = north_emoji
	bubble.emoji_south = south_emoji
	# NOTE: Constructor calls update_from_quantum_state() which sets color from coherence
	# Do NOT hardcode color - let quantum state determine it
	bubble.has_farm_tether = true  # Show tether to grid position
	bubble.is_terminal_bubble = true  # V2 architecture marker

	# V2.2: Store terminal reference (single source of truth for state queries)
	bubble.terminal = terminal

	# Add to tracking
	if not basis_bubbles.has(biome_name):
		basis_bubbles[biome_name] = []

	print("  📊 Adding bubble to tracking structures...")
	basis_bubbles[biome_name].append(bubble)
	graph.quantum_nodes.append(bubble)
	graph.quantum_nodes_by_grid_pos[grid_pos] = bubble
	print("    ✅ Added to basis_bubbles[%s] (now %d bubbles)" % [biome_name, basis_bubbles[biome_name].size()])
	print("    ✅ Added to graph.quantum_nodes (now %d total)" % graph.quantum_nodes.size())
	print("    ✅ Added to graph.quantum_nodes_by_grid_pos[%s]" % grid_pos)

	# Register by plot_id for entanglement lookup (only if plot provided)
	if plot and bubble.plot_id:
		graph.node_by_plot_id[bubble.plot_id] = bubble
		print("    ✅ Registered by plot_id: %s" % bubble.plot_id)

	# Start spawn animation so visual_scale/alpha go from 0→1
	# CRITICAL: Must use graph.time_accumulator, NOT real time, because
	# update_animation() is called with time_accumulator and computes
	# elapsed = current_time - spawn_time. Mismatched time bases cause
	# visual_scale to stay at 0 forever (bubbles invisible).
	bubble.start_spawn_animation(graph.time_accumulator)

	# Set initial visibility based on plot selection state
	# ARCHITECTURE: Bubbles only visible for SELECTED plots
	# FALLBACK: If PlotGridDisplay not fully synced yet, default to visible
	var is_selected = selected_plot_positions.has(grid_pos)

	# Only apply selection-based visibility if:
	# 1. PlotGridDisplay was found AND
	# 2. Selection has been synced (selected_plot_positions is not empty OR plot was explicitly selected)
	if plot_grid_display_ref and selected_plot_positions.size() > 0:
		bubble.visible = is_selected
	else:
		# FALLBACK: Show all bubbles if selection system not ready yet
		print("  ⚠️  PlotGridDisplay not ready (size=%d), defaulting to visible" % selected_plot_positions.size())
		bubble.visible = true

	print("✅ BUBBLE CREATED SUCCESSFULLY!")
	print("  Position: %s" % bubble.position)
	print("  Visible: %s" % bubble.visible)
	print("  Is selected: %s" % is_selected)
	print("  Visual scale: %s" % bubble.visual_scale)
	print("  Visual alpha: %s" % bubble.visual_alpha)
	print("  Radius: %s" % bubble.radius)
	print("  Biome: %s" % bubble.biome_name)

	graph.queue_redraw()


func _create_single_bubble(biome_name: String, emoji: String, grid_pos: Vector2i = Vector2i.ZERO) -> QuantumNode:
	"""Create a single bubble for one emoji

	Returns: The created QuantumNode, or null if creation failed
	"""
	var biome = biomes.get(biome_name)
	# Model C: require visualization payload
	if not biome or not biome.viz_cache or not biome.viz_cache.has_metadata():
		return null

	# Create dummy qubit for interface compatibility (QuantumNode expects one)
	# This qubit doesn't evolve - we just update its phi from bath
	var dummy_qubit = DualEmojiQubit.new(emoji, "💀", PI/2)

	# Create dummy FarmPlot to hold qubit (QuantumNode expects plot.quantum_state)
	var dummy_plot = FarmPlot.new()
	dummy_plot.quantum_state = dummy_qubit

	# Determine initial position (scatter around oval perimeter)
	var initial_pos = stored_center
	var oval = graph.layout_calculator.get_biome_oval(biome_name)
	if not oval.is_empty():
		var center = oval.get("center", stored_center)
		var semi_a = oval.get("semi_a", 100.0)
		var semi_b = oval.get("semi_b", 60.0)

		# Random angle for initial scatter
		var angle = randf() * TAU
		initial_pos = center + Vector2(
			semi_a * cos(angle) * 0.7,
			semi_b * sin(angle) * 0.7
		)

	# Create QuantumNode bubble (requires: plot, anchor_pos, grid_pos, center_pos)
	# Use passed grid_pos (defaults to (0,0) for basis state bubbles)
	var bubble = QuantumNode.new(dummy_plot, initial_pos, grid_pos, stored_center)
	bubble.emoji_north = emoji
	bubble.emoji_south = "💀"
	bubble.biome_name = biome_name

	# Set initial visual properties (Model C: fixed size, color from emoji)
	bubble.radius = 40.0
	bubble.color = _get_emoji_color(emoji)

	# Store in graph arrays (don't add_child - QuantumNode extends RefCounted, not Node)
	graph.quantum_nodes.append(bubble)
	graph.node_by_plot_id[dummy_plot.plot_id] = bubble

	return bubble


func _create_basis_bubbles(biome_name: String) -> void:
	"""DEPRECATED - use request_emoji_bubble() instead

	This method is kept for backward compatibility but does nothing in plot-driven mode.
	"""
	pass


func _process(delta: float) -> void:
	var t0 = Time.get_ticks_usec()
	"""Update bubble visuals from bath state and apply forces"""
	if not graph:
		return

	_update_bubble_visuals_from_bath()
	var t1 = Time.get_ticks_usec()
	_apply_skating_rink_forces(delta)
	var t2 = Time.get_ticks_usec()

	if Engine.get_process_frames() % 60 == 0:
		_verbose.trace("viz", "⏱️", "BQVC Process Trace: Total %d us (Visuals: %d, Forces: %d)" % [t2 - t0, t1 - t0, t2 - t1])


func _update_bubble_visuals_from_bath() -> void:
	"""Update bubble visuals from quantum state

	Model C: Bubble visuals are updated by QuantumForceGraph from density matrix,
	not from this function. This is kept as a no-op for compatibility.
	"""
	# Model C uses QuantumForceGraph for all visualization updates
	pass


func _apply_skating_rink_forces(delta: float) -> void:
	"""Apply forces to position bubbles on biome ovals

	RADIAL ENCODING: ring_distance ← purity Tr(ρ²)
	- Pure states (purity=1.0) → center of oval (ring=0.3)
	- Mixed states (purity=1/N) → edge of oval (ring=0.85)

	ANGULAR ENCODING: phi ← grid position hash (spread bubbles evenly)
	"""
	if not graph or not graph.layout_calculator:
		return

	for biome_name in basis_bubbles:
		var bubbles = basis_bubbles[biome_name]
		if bubbles.is_empty():
			continue

		var oval = graph.layout_calculator.get_biome_oval(biome_name)
		if oval.is_empty():
			continue

		var center = oval.get("center", Vector2.ZERO)
		var semi_a = oval.get("semi_a", 100.0)
		var semi_b = oval.get("semi_b", 60.0)

		# Get biome's purity for radial positioning
		var biome = biomes.get(biome_name)
		var biome_purity = 0.5  # Default mid-purity
		if biome and ("viz_cache" in biome):
			var purity = biome.viz_cache.get_purity()
			if purity >= 0.0:
				biome_purity = purity

		# RADIAL POSITION: ring_distance ← purity (constant for all bubbles in this biome)
		# Pure (1.0) → 0.3 (center), Mixed (0.125 for 8-dim) → 0.85 (edge)
		# Interpolate: ring = 0.85 - (purity - min_purity) * 0.55 / (1 - min_purity)
		var min_purity = 0.125  # 1/8 for 3-qubit system
		var purity_normalized = clampf((biome_purity - min_purity) / (1.0 - min_purity), 0.0, 1.0)
		var ring_distance = 0.85 - purity_normalized * 0.55  # 0.85 (mixed) to 0.30 (pure)

		for bubble in bubbles:
			# Skip bubbles without plot OR farm_tether (neither v1 nor v2 style)
			if not bubble.plot and not bubble.has_farm_tether:
				continue

			# MEASURED BUBBLES: Freeze in place - no skating rink forces
			if bubble.is_terminal_measured():
				bubble.velocity = Vector2.ZERO
				continue

			# ANGULAR POSITION: spread bubbles around oval
			var phi = 0.0
			if bubble.has_farm_tether and not bubble.plot:
				# Terminal bubbles: spread around oval based on grid position hash
				phi = (bubble.grid_position.x * 1.618 + bubble.grid_position.y * 2.718) * TAU
			elif bubble.plot:
				# Plot bubbles: use grid position for spread
				phi = (bubble.grid_position.x * 2.236 + bubble.grid_position.y * 1.414) * TAU

			var target_pos = center + Vector2(
				semi_a * cos(phi) * ring_distance,
				semi_b * sin(phi) * ring_distance
			)

			# Apply force toward target
			var to_target = target_pos - bubble.position
			var distance = to_target.length()

			if distance > 1.0:
				var force_dir = to_target.normalized()
				var force_magnitude = skating_rink_strength * min(distance / 50.0, 2.0)
				bubble.velocity += force_dir * force_magnitude * delta


func _get_emoji_color(emoji: String) -> Color:
	"""Get base color for emoji"""
	match emoji:
		"☀", "☀️":
			return Color(1.0, 0.9, 0.3, 0.8)
		"🌙", "🌑":
			return Color(0.7, 0.7, 0.9, 0.8)
		"🌾":
			return Color(0.9, 0.8, 0.4, 0.8)
		"🍄":
			return Color(0.9, 0.3, 0.3, 0.8)
		"💀", "👥":
			return Color(0.8, 0.8, 0.8, 0.8)
		"🍂":
			return Color(0.7, 0.5, 0.3, 0.8)
		"🐺":
			return Color(0.6, 0.6, 0.6, 0.8)
		"🐇":
			return Color(0.9, 0.9, 0.9, 0.8)
		"🦌":
			return Color(0.7, 0.5, 0.4, 0.8)
		"🌿":
			return Color(0.3, 0.7, 0.3, 0.8)
		"🌲", "🌳":
			return Color(0.2, 0.6, 0.2, 0.8)
		"💧":
			return Color(0.3, 0.5, 0.9, 0.8)
		"⛰":
			return Color(0.5, 0.5, 0.5, 0.8)
		_:
			return Color(0.7, 0.7, 0.7, 0.8)
