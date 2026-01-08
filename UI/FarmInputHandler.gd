class_name FarmInputHandler
extends Node

## INPUT CONTRACT (Layer 2 - Tool/Action System)
## ═══════════════════════════════════════════════════════════════
## PHASE: _input() - Runs after InputController
## HANDLES: InputEventKey via input actions
## ACTIONS: tool_1-6, action_q/e/r, select_plot_*, move_*, toggle_help
## CONSUMES: Always for handled actions (via get_viewport().set_input_as_handled())
## EMITS: tool_changed, submenu_changed, action_performed
## REQUIRES: GridConfig injection for plot selection
## ═══════════════════════════════════════════════════════════════
##
## Keyboard-driven Farm UI - Minecraft-style tool/action system:
## Numbers 1-6 = Tool modes (Plant, Quantum, Economy, etc)
## Q/E/R = Context-sensitive actions (depends on active tool)
## WASD = Movement/cursor control
## TYUIOP = Quick-access location selectors

# Preloads
const GridConfig = preload("res://Core/GameState/GridConfig.gd")
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const QuantumAlgorithms = preload("res://Core/QuantumSubstrate/QuantumAlgorithms.gd")

# Tool actions from shared config (single source of truth)
const TOOL_ACTIONS = ToolConfig.TOOL_ACTIONS

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = get_node("/root/VerboseConfig")

var farm  # Will be injected with Farm instance (Farm.gd)
var plot_grid_display: Node = null  # Will be injected with PlotGridDisplay instance
var current_selection: Vector2i = Vector2i.ZERO
var current_tool: int = 1  # Active tool (1-6)
var current_submenu: String = ""  # Active submenu name (empty = no submenu)
var _cached_submenu: Dictionary = {}  # Cached dynamic submenu during session
var grid_config: GridConfig = null  # Grid configuration (Phase 7)
var input_enable_frame_count: int = 0  # Counter to enable input after N frames

# Config (deprecated - now read from GridConfig)
var grid_width: int = 6
var grid_height: int = 2

# Debug: Set to true to enable verbose logging (keystroke-by-keystroke, location info, etc)
const VERBOSE = false

# ═══════════════════════════════════════════════════════════════
# MODEL B COMPATIBILITY LAYER
# ═══════════════════════════════════════════════════════════════
# These helper functions provide safe fallbacks for Model A code
# that tries to access quantum_state on plots (which don't exist in Model B)

func _get_plot_north_emoji(plot: BiomePlot) -> String:
	"""Get north emoji safely (handles Model B where quantum_state doesn't exist)"""
	if plot and plot.is_planted and plot.north_emoji:
		return plot.north_emoji
	# Fallback: return placeholder
	return "?"

func _get_plot_south_emoji(plot: BiomePlot) -> String:
	"""Get south emoji safely"""
	if plot and plot.is_planted and plot.south_emoji:
		return plot.south_emoji
	return "?"

func _action_disabled_message(action_name: String) -> String:
	"""Return standard message for disabled actions"""
	return "⚠️  %s not functional in Model B (requires quantum_computer refactor)" % action_name

# ═══════════════════════════════════════════════════════════════
# Phase 3: Quantum Gate Helper Functions (Model B)
# ═══════════════════════════════════════════════════════════════

func _apply_single_qubit_gate(position: Vector2i, gate_name: String) -> bool:
	"""Apply a single-qubit gate via quantum_computer (Model B)

	Args:
		position: Grid position of plot
		gate_name: Gate name ("X", "Z", "H", "Y", "S", "T")

	Returns:
		true if gate applied successfully
	"""
	if not farm or not farm.grid:
		return false

	var plot = farm.grid.get_plot(position)
	if not plot or not plot.is_planted:
		return false

	var biome = farm.grid.get_biome_for_plot(position)
	var register_id = farm.grid.get_register_for_plot(position)

	if not biome or not biome.quantum_computer or register_id < 0:
		return false

	# Get gate matrix from library
	var gate_lib = QuantumGateLibrary.new()
	if not gate_lib.GATES.has(gate_name):
		push_error("Unknown gate: %s" % gate_name)
		return false

	var gate_matrix = gate_lib.GATES[gate_name]["matrix"]
	if not gate_matrix:
		return false

	# Get component for this register
	var comp = biome.quantum_computer.get_component_containing(register_id)
	if not comp:
		return false

	# Apply the gate
	return biome.quantum_computer.apply_unitary_1q(comp, register_id, gate_matrix)

func _apply_two_qubit_gate(position_a: Vector2i, position_b: Vector2i, gate_name: String) -> bool:
	"""Apply a two-qubit gate via quantum_computer (Model B)

	Args:
		position_a: Grid position of first plot
		position_b: Grid position of second plot
		gate_name: Gate name ("CNOT", "CZ", "SWAP")

	Returns:
		true if gate applied successfully
	"""
	if not farm or not farm.grid:
		return false

	var plot_a = farm.grid.get_plot(position_a)
	var plot_b = farm.grid.get_plot(position_b)

	if not plot_a or not plot_b or not plot_a.is_planted or not plot_b.is_planted:
		return false

	var biome_a = farm.grid.get_biome_for_plot(position_a)
	var biome_b = farm.grid.get_biome_for_plot(position_b)
	var reg_a = farm.grid.get_register_for_plot(position_a)
	var reg_b = farm.grid.get_register_for_plot(position_b)

	# Plots must be in same biome for 2Q gates
	if biome_a != biome_b or not biome_a or not biome_a.quantum_computer:
		return false

	if reg_a < 0 or reg_b < 0:
		return false

	# Get gate matrix from library
	var gate_lib = QuantumGateLibrary.new()
	if not gate_lib.GATES.has(gate_name):
		push_error("Unknown gate: %s" % gate_name)
		return false

	var gate_matrix = gate_lib.GATES[gate_name]["matrix"]
	if not gate_matrix:
		return false

	# Get component containing both registers
	var comp_a = biome_a.quantum_computer.get_component_containing(reg_a)
	var comp_b = biome_a.quantum_computer.get_component_containing(reg_b)

	if not comp_a or comp_a != comp_b:
		# Registers not in same component - must entangle first
		return false

	# Apply the gate
	return biome_a.quantum_computer.apply_unitary_2q(comp_a, reg_a, reg_b, gate_matrix)

# ═══════════════════════════════════════════════════════════════

# Signals
signal action_performed(action: String, success: bool, message: String)
signal selection_changed(new_pos: Vector2i)
signal plot_selected(pos: Vector2i)  # Signal emitted when plot location is selected
signal tool_changed(tool_num: int, tool_info: Dictionary)
signal submenu_changed(submenu_name: String, submenu_info: Dictionary)  # Emitted when entering/exiting submenu
signal help_requested

func _ready():
	_verbose.info("input", "⌨️", "FarmInputHandler initialized (Tool Mode System)")
	if VERBOSE:
		_verbose.debug("input", "📍", "Starting position: %s" % current_selection)
		_verbose.debug("input", "🛠️", "Current tool: %s" % TOOL_ACTIONS[current_tool]["name"])
	# Input is ready immediately - PlotGridDisplay is initialized before this
	# No deferred calls needed
	set_process_input(true)
	_verbose.info("input", "✅", "Input processing enabled (no deferred delays)")
	_print_help()


func _enable_input_processing() -> void:
	"""Enable input processing after UI is initialized - prevents race conditions"""
	# Simple approach: wait 1 frame to ensure all initialization is done
	# (Reduced from 10 - modern Godot initialization is fast, UI is ready by frame 1)
	set_process(true)  # Enable _process() to count frames
	input_enable_frame_count = 1


func _process(_delta: float) -> void:
	"""Count down frames until input processing can be safely enabled"""
	if not get_tree().root.is_input_handled():
		input_enable_frame_count -= 1
		if input_enable_frame_count <= 0:
			set_process(false)  # Stop processing frames
			set_process_input(true)  # Enable input
			_verbose.info("input", "✅", "Input processing enabled (UI ready)")
			# Verify tiles exist
			if plot_grid_display and plot_grid_display.tiles:
				_verbose.debug("input", "📊", "PlotGridDisplay has %d tiles ready" % plot_grid_display.tiles.size())


func inject_grid_config(config: GridConfig) -> void:
	"""Inject GridConfig for dynamic grid-aware input handling (Phase 7)"""
	if not config:
		push_error("FarmInputHandler: Attempted to inject null GridConfig!")
		return

	grid_config = config
	# Update dimensions from config
	grid_width = config.grid_width
	grid_height = config.grid_height
	_verbose.info("input", "💉", "GridConfig injected into FarmInputHandler (%dx%d grid)" % [grid_width, grid_height])


func _unhandled_input(event: InputEvent):
	"""Handle gameplay input via InputMap actions (Layer 3 - Low Priority)

	Only processes input that PlayerShell didn't consume (modals, shell actions).
	Supports keyboard (WASD, QERT, numbers, etc) and gamepad (D-Pad, buttons, sticks)
	via Godot's InputMap system.
	"""
	if VERBOSE and event is InputEventKey and event.pressed:
		_verbose.debug("input", "🔑", "FarmInputHandler._input() received KEY: %s" % event.keycode)

	# Tool selection (1-6) - Phase 7: Use InputMap actions
	for i in range(1, 7):
		if event.is_action_pressed("tool_" + str(i)):
			if VERBOSE:
				_verbose.debug("input", "🛠️", "Tool key pressed: %d" % i)
			_select_tool(i)
			get_viewport().set_input_as_handled()
			return

	# Location quick-select (dynamic from GridConfig, or default mapping) - MULTI-SELECT: Toggle plots with checkboxes
	if grid_config:
		for action in grid_config.keyboard_layout.get_all_actions():
			if event.is_action_pressed(action):
				if VERBOSE:
					_verbose.debug("input", "📍", "GridConfig action detected: %s" % action)
				var pos = grid_config.keyboard_layout.get_position_for_action(action)
				if pos != Vector2i(-1, -1) and grid_config.is_position_valid(pos):
					_toggle_plot_selection(pos)
					get_viewport().set_input_as_handled()
					return
	else:
		_verbose.warn("input", "⚠️", "grid_config is NULL at input time - falling back to hardcoded actions")
		# Fallback: default 6x2 keyboard layout
		# Row 0: TYUIOP left-to-right
		# Row 1: 7890 left-to-right
		var default_keys = {
			"select_plot_t": Vector2i(0, 0),
			"select_plot_y": Vector2i(1, 0),
			"select_plot_u": Vector2i(2, 0),
			"select_plot_i": Vector2i(3, 0),
			"select_plot_o": Vector2i(4, 0),
			"select_plot_p": Vector2i(5, 0),
			"select_plot_7": Vector2i(0, 1),
			"select_plot_8": Vector2i(1, 1),
			"select_plot_9": Vector2i(2, 1),
			"select_plot_0": Vector2i(3, 1),
		}
		for action in default_keys.keys():
			if event.is_action_pressed(action):
				if VERBOSE:
					_verbose.debug("input", "📍", "Fallback action detected: %s → %s" % [action, default_keys[action]])
				_toggle_plot_selection(default_keys[action])
				get_viewport().set_input_as_handled()
				return

	# Selection management: [ = clear all, ] = restore previous
	# Check for raw keyboard events since InputMap actions don't exist for these keys
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_BRACKETLEFT:  # [ key
			_clear_all_selection()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_BRACKETRIGHT:  # ] key
			_restore_previous_selection()
			get_viewport().set_input_as_handled()
			return

	# Movement (WASD or D-Pad or Left Stick) - Phase 7: Use InputMap actions
	if event.is_action_pressed("move_up"):
		_move_selection(Vector2i.UP)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("move_down"):
		_move_selection(Vector2i.DOWN)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("move_left"):
		_move_selection(Vector2i.LEFT)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("move_right"):
		_move_selection(Vector2i.RIGHT)
		get_viewport().set_input_as_handled()
		return

	# Action keys (Q/E/R or gamepad buttons A/B/X) - Phase 7: Use InputMap actions
	# Debug: Check if actions are detected
	if VERBOSE and event is InputEventKey and event.pressed:
		var key = event.keycode
		if key == KEY_Q or key == KEY_E or key == KEY_R:
			_verbose.debug("input", "🐛", "DEBUG: Pressed key: %s" % event.keycode)
			_verbose.debug("input", "🐛", "is_action_pressed('action_q'): %s" % event.is_action_pressed("action_q"))
			_verbose.debug("input", "🐛", "is_action_pressed('action_e'): %s" % event.is_action_pressed("action_e"))
			_verbose.debug("input", "🐛", "is_action_pressed('action_r'): %s" % event.is_action_pressed("action_r"))

	# NOTE: Q/E/R actions are now primarily routed through InputController
	# Only process if input hasn't already been handled (by menu system)
	if not get_tree().root.is_input_handled():
		if event.is_action_pressed("action_q"):
			if VERBOSE:
				_verbose.debug("input", "⚡", "action_q detected")
			_execute_tool_action("Q")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("action_e"):
			if VERBOSE:
				_verbose.debug("input", "⚡", "action_e detected")
			_execute_tool_action("E")
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("action_r"):
			if VERBOSE:
				_verbose.debug("input", "⚡", "action_r detected")
			_execute_tool_action("R")
			get_viewport().set_input_as_handled()
			return

	# Debug/Help - Phase 7: Use InputMap action
	if event.is_action_pressed("toggle_help"):
		_print_help()
		get_viewport().set_input_as_handled()
		return

	# NOTE: K key for keyboard help is now handled by InputController
	# Removed backward compatibility handlers to avoid conflicts with menu system


## Tool System

func _select_tool(tool_num: int):
	"""Select active tool (1-6)"""
	if not TOOL_ACTIONS.has(tool_num):
		_verbose.warn("input", "⚠️", "Tool %d not available" % tool_num)
		return

	# Exit any active submenu when switching tools
	if current_submenu != "":
		_exit_submenu()

	current_tool = tool_num
	var tool_info = TOOL_ACTIONS[tool_num]
	_verbose.info("input", "🛠️", "Tool switched to: %s" % tool_info["name"])
	if VERBOSE:
		_verbose.debug("input", "🛠️", "Q = %s" % tool_info["Q"]["label"])
		_verbose.debug("input", "🛠️", "E = %s" % tool_info["E"]["label"])
		_verbose.debug("input", "🛠️", "R = %s" % tool_info["R"]["label"])

	tool_changed.emit(tool_num, tool_info)


## Submenu System

func _enter_submenu(submenu_name: String):
	"""Enter a submenu - QER keys now map to submenu actions"""
	var submenu = ToolConfig.get_submenu(submenu_name)
	if submenu.is_empty():
		push_error("Submenu '%s' not found" % submenu_name)
		return

	# Check if submenu is dynamic - generate runtime actions
	if submenu.get("dynamic", false):
		# For dynamic menus, determine which plot position to use for generation
		var menu_position = current_selection

		# If checkboxes are active, use first checked plot instead of current_selection
		# This allows users to checkbox a plot and get the correct biome menu
		var checked_plots: Array[Vector2i] = []
		if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
			checked_plots = plot_grid_display.get_selected_plots()

		if not checked_plots.is_empty():
			menu_position = checked_plots[0]

		submenu = ToolConfig.get_dynamic_submenu(submenu_name, farm, menu_position)

	current_submenu = submenu_name

	# Cache the generated submenu for this session
	_cached_submenu = submenu

	submenu_changed.emit(submenu_name, submenu)


func _exit_submenu():
	"""Exit current submenu and return to tool mode"""
	if current_submenu == "":
		return

	current_submenu = ""
	_cached_submenu = {}  # Clear cache
	submenu_changed.emit("", {})

	# Re-emit tool info to update UI
	tool_changed.emit(current_tool, TOOL_ACTIONS[current_tool])


func _refresh_dynamic_submenu():
	"""Refresh dynamic submenu when selection changes

	If currently in a dynamic submenu (like plant), regenerate it based on
	the new selected plot's biome. This ensures biome-specific menus update
	when switching between plots.
	"""
	if current_submenu == "":
		return  # Not in a submenu

	# Check if current submenu is dynamic
	var base_submenu = ToolConfig.get_submenu(current_submenu)
	if not base_submenu.get("dynamic", false):
		return  # Not a dynamic submenu

	# Determine which plot position to use for menu generation
	var menu_position = current_selection

	# If checkboxes are active, use first checked plot instead of current_selection
	var checked_plots: Array[Vector2i] = []
	if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
		checked_plots = plot_grid_display.get_selected_plots()

	if not checked_plots.is_empty():
		menu_position = checked_plots[0]

	# Regenerate dynamic submenu for new selection
	var regenerated = ToolConfig.get_dynamic_submenu(current_submenu, farm, menu_position)
	_cached_submenu = regenerated

	# Re-emit submenu_changed to update UI
	submenu_changed.emit(current_submenu, regenerated)


func _execute_submenu_action(action_key: String):
	"""Execute action from current submenu"""
	# Use cached submenu (supports dynamic generation)
	var submenu = _cached_submenu if not _cached_submenu.is_empty() else ToolConfig.get_submenu(current_submenu)

	if submenu.is_empty():
		_verbose.warn("input", "⚠️", "Current submenu '%s' not found" % current_submenu)
		_exit_submenu()
		return

	# Check if entire submenu is disabled (e.g., no vocabulary discovered)
	if submenu.get("_disabled", false):
		_verbose.warn("input", "⚠️", "Submenu disabled - grow crops to discover vocabulary")
		action_performed.emit("disabled", false, "⚠️  Discover vocabulary by growing crops")
		return

	if not submenu.has(action_key):
		_verbose.warn("input", "⚠️", "Action %s not available in submenu %s" % [action_key, current_submenu])
		return

	var action_info = submenu[action_key]
	var action = action_info["action"]
	var label = action_info["label"]

	# Check if action is empty (locked button)
	if action == "":
		_verbose.warn("input", "⚠️", "Action locked - discover more vocabulary")
		action_performed.emit("locked", false, "⚠️  Unlock by discovering vocabulary")
		return

	# Get currently selected plots
	var selected_plots: Array[Vector2i] = []
	if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
		selected_plots = plot_grid_display.get_selected_plots()

	if selected_plots.is_empty():
		if _is_valid_position(current_selection):
			selected_plots = [current_selection]
		else:
			_verbose.warn("input", "⚠️", "No plots selected!")
			action_performed.emit(action, false, "⚠️  No plots selected")
			return

	_verbose.info("input", "📂", "Submenu %s | Key %s | Action: %s | Plots: %d" % [current_submenu, action_key, label, selected_plots.size()])

	# Execute submenu-specific actions
	match action:
		# Plant submenu
		"plant_wheat":
			_action_batch_plant("wheat", selected_plots)
		"plant_mushroom":
			_action_batch_plant("mushroom", selected_plots)
		"plant_tomato":
			_action_batch_plant("tomato", selected_plots)

		# Kitchen ingredients (dynamic submenu)
		"plant_fire":
			_action_batch_plant("fire", selected_plots)
		"plant_water":
			_action_batch_plant("water", selected_plots)
		"plant_flour":
			_action_batch_plant("flour", selected_plots)

		# Forest organisms (dynamic submenu)
		"plant_vegetation":
			_action_batch_plant("vegetation", selected_plots)
		"plant_rabbit":
			_action_batch_plant("rabbit", selected_plots)
		"plant_wolf":
			_action_batch_plant("wolf", selected_plots)

		# Market commodities (dynamic submenu)
		"plant_bread":
			_action_batch_plant("bread", selected_plots)

		# Industry submenu
		"place_mill":
			_action_batch_build("mill", selected_plots)
		"place_market":
			_action_batch_build("market", selected_plots)
		"place_kitchen":
			_action_place_kitchen(selected_plots)

		# Single-qubit gate submenu
		"apply_pauli_x":
			_action_apply_pauli_x(selected_plots)
		"apply_hadamard":
			_action_apply_hadamard(selected_plots)
		"apply_pauli_z":
			_action_apply_pauli_z(selected_plots)

		# Two-qubit gate submenu
		"apply_cnot":
			_action_apply_cnot(selected_plots)
		"apply_cz":
			_action_apply_cz(selected_plots)
		"apply_swap":
			_action_apply_swap(selected_plots)

		# Tool 6: Biome Management
		"clear_biome_assignment":
			_action_clear_biome_assignment(selected_plots)

		"inspect_plot":
			_action_inspect_plot(selected_plots)

		"pump_to_wheat":
			_action_pump_to_wheat(selected_plots)

		"reset_to_pure":
			_action_reset_to_pure(selected_plots)

		"reset_to_mixed":
			_action_reset_to_mixed(selected_plots)

		_:
			# Handle dynamic actions
			if action.begins_with("tap_"):
				# Dynamic energy tap
				var emoji = _extract_emoji_from_action(action)
				if emoji != "":
					_action_place_energy_tap_for(selected_plots, emoji)
				else:
					_verbose.warn("input", "⚠️", "Unknown tap action: %s" % action)
			elif action.begins_with("assign_to_"):
				# Dynamic biome assignment
				var biome_name = action.replace("assign_to_", "")
				if farm.grid.biomes.has(biome_name):
					_action_assign_plots_to_biome(selected_plots, biome_name)
				else:
					_verbose.warn("input", "⚠️", "Biome '%s' not found in registry!" % biome_name)
			else:
				_verbose.warn("input", "⚠️", "Unknown submenu action: %s" % action)

	# Auto-exit submenu after executing action
	_exit_submenu()


func get_current_actions() -> Dictionary:
	"""Get current QER actions (from submenu or tool)

	Used by UI to display correct action labels.
	"""
	if current_submenu != "":
		var submenu = ToolConfig.get_submenu(current_submenu)
		return {
			"Q": submenu.get("Q", {}),
			"E": submenu.get("E", {}),
			"R": submenu.get("R", {}),
			"is_submenu": true,
			"submenu_name": current_submenu,
		}
	else:
		var tool = TOOL_ACTIONS.get(current_tool, {})
		return {
			"Q": tool.get("Q", {}),
			"E": tool.get("E", {}),
			"R": tool.get("R", {}),
			"is_submenu": false,
			"tool_name": tool.get("name", ""),
		}


func execute_action(action_key: String) -> void:
	"""PUBLIC: Execute the action mapped to Q/E/R for current tool

	NOTE: This is now primarily used by test files. In production, ActionPreviewRow
	connects directly to _execute_tool_action() for the unified signal path.
	"""
	_execute_tool_action(action_key)


func _execute_tool_action(action_key: String):
	"""Execute the action mapped to Q/E/R for current tool or submenu

	Supports submenu navigation and multi-select.
	Called by BOTH keyboard (_unhandled_input) and touch (ActionPreviewRow signal).
	"""
	if not farm:
		push_error("Farm not set on FarmInputHandler!")
		return

	# Check if we're in a submenu first
	if current_submenu != "":
		_execute_submenu_action(action_key)
		return

	if not TOOL_ACTIONS.has(current_tool):
		_verbose.warn("input", "⚠️", "Current tool not found")
		return

	var tool = TOOL_ACTIONS[current_tool]
	if not tool.has(action_key):
		_verbose.warn("input", "⚠️", "Action %s not available for tool %d (%s)" % [action_key, current_tool, tool.get("name", "unknown")])
		return

	var action_info = tool[action_key]
	var action = action_info["action"]
	var label = action_info["label"]

	# Check if this action opens a submenu
	if action_info.has("submenu"):
		var submenu_name = action_info["submenu"]
		_enter_submenu(submenu_name)
		return

	# Get currently selected plots
	var selected_plots: Array[Vector2i] = []
	if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
		selected_plots = plot_grid_display.get_selected_plots()

	# FALLBACK: If no plots selected in UI, use current selection (for auto-play/testing)
	if selected_plots.is_empty():
		if _is_valid_position(current_selection):
			selected_plots = [current_selection]
			if VERBOSE:
				_verbose.debug("input", "📍", "No multi-select; using current selection: %s" % current_selection)
		else:
			_verbose.warn("input", "⚠️", "No plots selected! Use T/Y/U/I/O/P to toggle selections.")
			action_performed.emit(action, false, "⚠️  No plots selected")
			return

	_verbose.info("input", "⚡", "Tool %d (%s) | Key %s | Action: %s | Plots: %d selected" % [current_tool, tool.get("name", "?"), action_key, label, selected_plots.size()])

	# Execute the action based on type (now with multi-select support)
	match action:
		# Tool 1: GROWER - Core farming
		"plant_batch":
			_action_plant_batch(selected_plots)
		"entangle_batch":
			_action_entangle_batch(selected_plots)
		"measure_and_harvest":
			_action_batch_measure_and_harvest(selected_plots)

		# Tool 2: QUANTUM - Persistent gate infrastructure
		"cluster":
			_action_cluster(selected_plots)
		"measure_trigger":
			_action_measure_trigger(selected_plots)
		"remove_gates":
			_action_remove_gates(selected_plots)

		# Tool 3: INDUSTRY - Economy & automation
		"place_mill":
			_action_batch_build("mill", selected_plots)
		"place_market":
			_action_batch_build("market", selected_plots)
		"place_kitchen":
			_action_place_kitchen(selected_plots)

		# Tool 4: ENERGY - Energy management
		"inject_energy":
			_action_inject_energy(selected_plots)
		"drain_energy":
			_action_drain_energy(selected_plots)
		"place_energy_tap":
			_action_place_energy_tap(selected_plots)

		# Tool 5: GATES - Instantaneous single-qubit gates
		"apply_pauli_x":
			_action_apply_pauli_x(selected_plots)
		"apply_hadamard":
			_action_apply_hadamard(selected_plots)
		"apply_pauli_z":
			_action_apply_pauli_z(selected_plots)

		# Tool 5: Measure (R action)
		"measure_batch":
			_action_batch_measure(selected_plots)

		_:
			_verbose.warn("input", "⚠️", "Unknown action: %s" % action)


## Selection Management

func _set_selection(pos: Vector2i):
	"""Set selection to specific position (YUIOP quick-select)"""
	if _is_valid_position(pos):
		current_selection = pos
		selection_changed.emit(current_selection)
		plot_selected.emit(current_selection)  # Also emit plot_selected for UI updates

		# If in a dynamic submenu, regenerate it for the new selection
		_refresh_dynamic_submenu()

		if VERBOSE:
			_verbose.debug("input", "📍", "Selected: %s (Location %d)" % [current_selection, current_selection.x + 1])
	else:
		if VERBOSE:
			_verbose.debug("input", "⚠️", "Invalid position: %s" % pos)


func _move_selection(direction: Vector2i):
	"""Move selection in given direction (WASD)"""
	var new_pos = current_selection + direction
	if _is_valid_position(new_pos):
		current_selection = new_pos
		selection_changed.emit(current_selection)

		# If in a dynamic submenu, regenerate it for the new selection
		_refresh_dynamic_submenu()

		if VERBOSE:
			_verbose.debug("input", "📍", "Moved to: %s" % current_selection)
	else:
		if VERBOSE:
			_verbose.debug("input", "⚠️", "Cannot move to: %s (out of bounds)" % new_pos)


func _is_valid_position(pos: Vector2i) -> bool:
	"""Check if position is within grid bounds"""
	if grid_config:
		return grid_config.is_position_valid(pos)
	# Fallback for backward compatibility
	return pos.x >= 0 and pos.x < grid_width and \
	       pos.y >= 0 and pos.y < grid_height


## Multi-Select Management (NEW)

func _toggle_plot_selection(pos: Vector2i):
	"""Toggle a plot's selection state (for T/Y/U/I/O/P keys)"""
	if not plot_grid_display:
		_verbose.error("input", "❌", "ERROR: PlotGridDisplay not wired to FarmInputHandler!")
		_verbose.error("input", "❌", "Refactor incomplete or wiring failed")
		return

	if not _is_valid_position(pos):
		_verbose.warn("input", "⚠️", "Invalid position: %s" % pos)
		return

	_verbose.debug("input", "⌨️", "Toggle plot %s" % pos)
	plot_grid_display.toggle_plot_selection(pos)


func _clear_all_selection():
	"""Clear all selected plots ([ key)"""
	if not plot_grid_display:
		_verbose.error("input", "❌", "ERROR: PlotGridDisplay not wired to FarmInputHandler!")
		return

	plot_grid_display.clear_all_selection()


func _restore_previous_selection():
	"""Restore previous selection state (] key)"""
	if not plot_grid_display:
		_verbose.error("input", "❌", "ERROR: PlotGridDisplay not wired to FarmInputHandler!")
		return

	plot_grid_display.restore_previous_selection()


## Action Implementations - Batch Operations (NEW)

func _action_batch_plant(plant_type: String, positions: Array[Vector2i]):
	"""Plant multiple plots with the given plant type"""
	if not farm:
		action_performed.emit("plant_%s" % plant_type, false, "⚠️  Farm not loaded yet")
		_verbose.error("farm", "❌", "PLANT FAILED: Farm not loaded")
		return

	# Map plant types to their emojis for display
	var emoji_map = {
		"wheat": "🌾",
		"mushroom": "🍄",
		"tomato": "🍅",
		"fire": "🔥",
		"water": "💧",
		"flour": "💨",
		"vegetation": "🌿",
		"rabbit": "🐇",
		"wolf": "🐺",
		"bread": "🍞"
	}
	var emoji = emoji_map.get(plant_type, "❓")
	_verbose.info("farm", "🌱", "Batch planting %s %s at %d plots: %s" % [emoji, plant_type, positions.size(), positions])

	# Check if farm has batch method, otherwise execute individually
	if farm.has_method("batch_plant"):
		var result = farm.batch_plant(positions, plant_type)
		var success = result.get("success", false)
		var count = result.get("count", 0)
		var message = result.get("message", "")
		action_performed.emit("plant_%s" % plant_type, success,
			"%s Planted %d %s plots | %s" % ["✅" if success else "❌", count, plant_type, message])
	else:
		# Fallback: execute individually
		var success_count = 0
		for pos in positions:
			if farm.build(pos, plant_type):
				success_count += 1
		var success = success_count > 0
		action_performed.emit("plant_%s" % plant_type, success,
			"%s Planted %d/%d %s plots" % ["✅" if success else "❌", success_count, positions.size(), plant_type])


func _action_batch_measure(positions: Array[Vector2i]):
	"""Measure quantum state of multiple plots via quantum_computer (Model B)

	Collapses the quantum state of selected plots and reports outcomes.
	Uses the refactored measure_plot() which is fully Model B compatible.
	"""
	if not farm or not farm.grid:
		action_performed.emit("measure", false, "⚠️  Farm not loaded yet")
		return

	if positions.is_empty():
		action_performed.emit("measure", false, "⚠️  No plots selected")
		return

	_verbose.info("farm", "📊", "Measuring %d plots..." % positions.size())

	var success_count = 0
	var outcomes = {}
	for pos in positions:
		var outcome_emoji = farm.grid.measure_plot(pos)
		if outcome_emoji and outcome_emoji != "":
			success_count += 1
			outcomes[outcome_emoji] = outcomes.get(outcome_emoji, 0) + 1
			_verbose.debug("farm", "📍", "%s → %s" % [pos, outcome_emoji])

	var summary = ""
	for emoji in outcomes.keys():
		summary += "%s×%d " % [emoji, outcomes[emoji]]

	action_performed.emit("measure", success_count > 0,
		"%s Measured %d/%d plots | %s" % ["✅" if success_count > 0 else "❌", success_count, positions.size(), summary])


func _action_batch_harvest(positions: Array[Vector2i]):
	"""Harvest multiple plots (measure then harvest each)"""
	if not farm:
		action_performed.emit("harvest", false, "⚠️  Farm not loaded yet")
		return

	_verbose.info("farm", "✂️", "Batch harvesting %d plots: %s" % [positions.size(), positions])

	# Check if farm has batch method
	if farm.has_method("batch_harvest"):
		var result = farm.batch_harvest(positions)
		var success = result.get("success", false)
		var count = result.get("count", 0)
		var total_yield = result.get("total_yield", 0)
		action_performed.emit("harvest", success,
			"%s Harvested %d/%d plots | Yield: %d" % ["✅" if success else "❌", count, positions.size(), total_yield])
	else:
		# Fallback: execute individually
		var success_count = 0
		var total_yield = 0
		for pos in positions:
			# Measure first, then harvest
			farm.measure_plot(pos)
			var result = farm.harvest_plot(pos)
			if result.get("success", false):
				success_count += 1
				total_yield += result.get("yield", 0)
		var success = success_count > 0
		action_performed.emit("harvest", success,
			"%s Harvested %d/%d plots | Yield: %d" % ["✅" if success else "❌", success_count, positions.size(), total_yield])


func _action_batch_build(build_type: String, positions: Array[Vector2i]):
	"""Build structures (mill, market) on multiple plots"""
	if not farm:
		action_performed.emit("build_%s" % build_type, false, "⚠️  Farm not loaded yet")
		_verbose.error("farm", "❌", "BUILD FAILED: Farm not loaded")
		return

	_verbose.info("farm", "🏗️", "Batch building %s at %d plots: %s" % [build_type, positions.size(), positions])

	# Check if farm has batch method
	if farm.has_method("batch_build"):
		var result = farm.batch_build(positions, build_type)
		var success = result.get("success", false)
		var count = result.get("count", 0)
		action_performed.emit("build_%s" % build_type, success,
			"%s Built %d %s structures" % ["✅" if success else "❌", count, build_type])
	else:
		# Fallback: execute individually
		var success_count = 0
		for pos in positions:
			if farm.build(pos, build_type):
				success_count += 1
		var success = success_count > 0
		action_performed.emit("build_%s" % build_type, success,
			"%s Built %d/%d %s structures" % ["✅" if success else "❌", success_count, positions.size(), build_type])


func _action_place_kitchen(positions: Array[Vector2i]):
	"""Place kitchen using triplet entanglement (requires exactly 3 plots)"""
	if not farm or not farm.grid:
		action_performed.emit("place_kitchen", false, "⚠️  Farm not loaded yet")
		return

	_verbose.info("farm", "🍳", "Placing kitchen with %d selected plots..." % positions.size())

	# Kitchen requires exactly 3 plots for triplet entanglement
	if positions.size() != 3:
		action_performed.emit("place_kitchen", false, "⚠️  Kitchen requires exactly 3 plots selected (got %d)" % positions.size())
		_verbose.warn("farm", "❌", "Kitchen needs exactly 3 plots for triplet entanglement")
		return

	# Create triplet entanglement (determines Bell state by spatial pattern)
	var pos_a = positions[0]
	var pos_b = positions[1]
	var pos_c = positions[2]

	var success = farm.grid.create_triplet_entanglement(pos_a, pos_b, pos_c)

	if success:
		_verbose.info("farm", "🍳", "Kitchen triplet created: %s ↔ %s ↔ %s" % [pos_a, pos_b, pos_c])
		action_performed.emit("place_kitchen", true, "✅ Kitchen created with triplet entanglement")
	else:
		_verbose.error("farm", "❌", "Failed to create kitchen triplet")
		action_performed.emit("place_kitchen", false, "❌ Failed to create kitchen (plots may need to be planted first)")


func _action_batch_boost_energy(positions: Array[Vector2i]):
	"""Boost quantum energy in selected plots (DEPRECATED - Model A only)

	This method implemented fake quantum physics (direct amplitude inflation).
	Model B uses proper quantum evolution via Hamiltonian coupling.
	Use harvest operations for resource extraction instead.
	"""
	action_performed.emit("boost_energy", false,
		"⚠️  DEPRECATED: Energy boost removed in Model B (use harvest instead)")


func _action_batch_measure_and_harvest(positions: Array[Vector2i]):
	"""Measure quantum state then harvest multiple plots (Model B)

	Combines measurement and harvest into single action:
	1. Measure each plot (collapse state)
	2. Harvest each plot (calculate yield based on outcome)
	Both operations use refactored quantum_computer APIs.
	"""
	if not farm or not farm.grid:
		action_performed.emit("harvest", false, "⚠️  Farm not loaded yet")
		return

	if positions.is_empty():
		action_performed.emit("harvest", false, "⚠️  No plots selected")
		return

	_verbose.info("farm", "📊", "Measure-Harvest %d plots..." % positions.size())

	var success_count = 0
	var total_yield = 0
	var measure_outcomes = {}
	var position_outcomes = {}  # Track outcome per position for bread detection

	for pos in positions:
		# Measure first (collapse state) - returns emoji string
		var outcome_emoji = farm.grid.measure_plot(pos)
		if outcome_emoji and outcome_emoji != "":
			measure_outcomes[outcome_emoji] = measure_outcomes.get(outcome_emoji, 0) + 1
			position_outcomes[pos] = outcome_emoji  # Track for bread detection

		# Then harvest (get yield based on outcome)
		# Note: harvest_with_topology() now automatically awards resources to economy
		var harvest_result = farm.grid.harvest_with_topology(pos)
		if harvest_result.has("success") and harvest_result["success"]:
			success_count += 1
			var yield_amount = harvest_result.get("yield", 0)
			total_yield += int(yield_amount)

			var state_emoji = harvest_result.get("state", "")
			_verbose.debug("farm", "✂️", "%s → %s × %.1f yield" % [pos, state_emoji, yield_amount])

	# BREAD DETECTION: Check if all 3 Kitchen plots measured to |000⟩ state
	# Physics: |000⟩ = 🔥💧💨 (hot, wet, flour) = Bread Ready
	# From QuantumKitchen_Biome.gd: "🍞 is NOT a basis state. It's the outcome when measurement finds |000⟩."
	var bread_created = _check_kitchen_bread_state(positions, position_outcomes)
	if bread_created:
		_verbose.info("farm", "🍞", "BREAD CREATED from quantum baking! (|000⟩ state measured)")
		# Award bread to economy
		var bread_amount = 50  # 50 credits = 5 bread units
		farm.economy.add_resource("🍞", bread_amount, "kitchen_quantum_baking")
		total_yield += bread_amount

	var summary = ""
	for emoji in measure_outcomes.keys():
		summary += "%s×%d " % [emoji, measure_outcomes[emoji]]

	var result_message = "%s Harvested %d/%d plots | Outcomes: %s| Total Yield: %d" % ["✅" if success_count > 0 else "❌", success_count, positions.size(), summary, total_yield]
	if bread_created:
		result_message += " | 🍞 BREAD CREATED!"

	action_performed.emit("harvest", success_count > 0, result_message)


func _check_kitchen_bread_state(positions: Array[Vector2i], outcomes: Dictionary) -> bool:
	"""Check if Kitchen plots measured to |000⟩ state (bread ready)

	Quantum Physics:
	  - Kitchen is 3-qubit system: Temperature × Moisture × Substance
	  - Basis states: |ijk⟩ where i,j,k ∈ {0,1}
	  - |000⟩ = 🔥💧💨 (hot, wet, flour) = Bread Ready
	  - Each qubit: |0⟩ = north state, |1⟩ = south state
	  - Bread is NOT a quantum state - it's the reward when measurement finds |000⟩

	Args:
	  positions: Array of plot positions that were measured
	  outcomes: Dictionary mapping position → measurement outcome emoji

	Returns:
	  true if all 3 Kitchen plots measured to their north/|0⟩ states
	"""
	# Must have exactly 3 plots (full GHZ state)
	if positions.size() != 3:
		return false

	# Check if all plots are in Kitchen biome
	var all_kitchen = true
	for pos in positions:
		var biome_name = farm.grid.plot_biome_assignments.get(pos, "")
		if biome_name != "Kitchen":
			all_kitchen = false
			break

	if not all_kitchen:
		return false

	# Check if all 3 plots measured to their north/|0⟩ states
	# |000⟩ means: qubit1=|0⟩, qubit2=|0⟩, qubit3=|0⟩
	# Each |0⟩ corresponds to plot.north_emoji
	var all_north = true
	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot:
			return false

		var outcome = outcomes.get(pos, "")
		var north_state = plot.north_emoji

		# Check if this plot measured to its north/|0⟩ state
		if outcome != north_state:
			all_north = false
			_verbose.debug("quantum", "📊", "Plot %s: measured %s, need %s for |0⟩" % [pos, outcome, north_state])
			break

	if all_north:
		_verbose.info("quantum", "🎯", "QUANTUM DETECTION: All 3 plots in |0⟩ state → |000⟩ = 🔥💧💨 = BREAD!")
		return true

	return false


func _action_entangle():
	"""Start entanglement at current selection (requires second selection)"""
	_verbose.info("quantum", "🔗", "Entangle mode: Select second location or press R again")
	action_performed.emit("entangle_start", true, "Select target plot to entangle with")


func _action_process_flour():
	"""Process wheat into flour (1 wheat → 1 flour)"""
	if not farm or not farm.economy:
		action_performed.emit("process_flour", false, "⚠️  Farm not loaded yet")
		return

	var success = farm.economy.process_wheat_to_flour(1)
	if success:
		action_performed.emit("process_flour", true, "💨 Processed 1 wheat → 1 flour")
	else:
		action_performed.emit("process_flour", false, "⚠️  Not enough wheat to process")


## NEW Tool 1 (GROWER) Actions

func _action_plant_batch(positions: Array[Vector2i]):
	"""Batch plant crops - context-aware based on biome

	- Kitchen plots → plant fire/water/flour
	- BioticFlux plots → plant wheat
	- Forest plots → plant mushroom
	- Other → plant wheat (default)
	"""
	if not farm:
		action_performed.emit("plant_batch", false, "⚠️  Farm not loaded yet")
		return

	if positions.is_empty():
		action_performed.emit("plant_batch", false, "⚠️  No plots selected")
		return

	# Detect biome from first selected plot
	var first_pos = positions[0]
	var biome_name = farm.grid.plot_biome_assignments.get(first_pos, "")

	var plant_type = "wheat"  # Default

	match biome_name:
		"Kitchen":
			# Kitchen: cycle through fire, water, flour based on plot position
			# Plot (3,1) = fire, Plot (4,1) = water, Plot (5,1) = flour
			if first_pos.x == 3:
				plant_type = "fire"
			elif first_pos.x == 4:
				plant_type = "water"
			elif first_pos.x == 5:
				plant_type = "flour"
			else:
				plant_type = "fire"  # Fallback

		"BioticFlux":
			plant_type = "wheat"

		"Forest":
			plant_type = "mushroom"

		"Market":
			# Can't plant on market plots
			action_performed.emit("plant_batch", false, "⚠️  Cannot plant on Market plots")
			return

		_:
			plant_type = "wheat"  # Default fallback

	_verbose.info("farm", "🌱", "Context-aware plant: %s biome → planting %s" % [biome_name, plant_type])
	_action_batch_plant(plant_type, positions)


func _action_entangle_batch(positions: Array[Vector2i]):
	"""Batch entangle selected plots (Model B - Gate Infrastructure)

	Creates Bell pairs between all consecutive plots via quantum_computer.entangle_plots().
	Uses BiomeBase.batch_entangle() for coordinated multi-qubit entanglement.
	"""
	if not farm or not farm.grid:
		action_performed.emit("entangle_batch", false, "⚠️  Farm not loaded yet")
		return

	if positions.size() < 2:
		action_performed.emit("entangle_batch", false, "⚠️  Need at least 2 plots to entangle")
		return

	_verbose.info("quantum", "🔗", "Batch entangling %d plots..." % positions.size())

	# Get biome from first plot
	var biome = farm.grid.get_biome_for_plot(positions[0])
	if not biome:
		action_performed.emit("entangle_batch", false, "⚠️  Could not access biome")
		return

	# Create batch entanglement
	var success = biome.batch_entangle(positions)
	var pair_count = positions.size() - 1

	action_performed.emit("entangle_batch", success,
		"%s Created %d Bell pairs from %d plots" % ["✅" if success else "❌", pair_count, positions.size()])


## NEW Tool 2 (QUANTUM) Actions - PERSISTENT INFRASTRUCTURE

func _action_cluster(positions: Array[Vector2i]):
	"""Build entanglement gate infrastructure (Model B - Gate Infrastructure)

	Creates multi-qubit cluster state topology via quantum_computer entanglement.
	Linear chain: plot[0]↔plot[1]↔plot[2]↔...
	Uses BiomeBase.create_cluster_state() for coordinated entanglement.
	"""
	if not farm or not farm.grid:
		action_performed.emit("cluster", false, "⚠️  Farm not loaded yet")
		return

	if positions.size() < 2:
		action_performed.emit("cluster", false, "⚠️  Need at least 2 plots for cluster")
		return

	_verbose.info("quantum", "🌐", "Creating cluster state with %d plots..." % positions.size())

	# Get biome from first plot
	var biome = farm.grid.get_biome_for_plot(positions[0])
	if not biome:
		action_performed.emit("cluster", false, "⚠️  Could not access biome")
		return

	# Create cluster state
	var success = biome.create_cluster_state(positions)
	var entanglement_count = positions.size() - 1

	action_performed.emit("cluster", success,
		"%s Built cluster with %d entanglements (%d plots)" % ["✅" if success else "❌", entanglement_count, positions.size()])


func _action_measure_trigger(positions: Array[Vector2i]):
	"""Build measure trigger (Model B - Gate Infrastructure)

	Creates conditional measurement infrastructure for controlled collapse.
	First plot in selection is trigger, remaining are targets.
	Uses BiomeBase.set_measurement_trigger() for setup.
	"""
	if not farm or not farm.grid:
		action_performed.emit("measure_trigger", false, "⚠️  Farm not loaded yet")
		return

	if positions.size() < 2:
		action_performed.emit("measure_trigger", false, "⚠️  Need trigger + at least 1 target plot")
		return

	_verbose.info("quantum", "🎯", "Setting up measure trigger with %d plots..." % positions.size())

	# Get biome from first plot
	var biome = farm.grid.get_biome_for_plot(positions[0])
	if not biome:
		action_performed.emit("measure_trigger", false, "⚠️  Could not access biome")
		return

	# First plot is trigger, rest are targets
	var trigger_pos = positions[0]
	var target_positions = positions.slice(1, positions.size())

	# Set measurement trigger
	var success = biome.set_measurement_trigger(trigger_pos, target_positions)

	action_performed.emit("measure_trigger", success,
		"%s Set trigger at %s with %d targets" % ["✅" if success else "❌", trigger_pos, target_positions.size()])


func _action_remove_gates(positions: Array[Vector2i]):
	"""Remove gate infrastructure (Model B - Gate Infrastructure)

	Removes entanglement between pairs of plots via quantum_computer metadata.
	Processes selection as pairs: (0,1), (2,3), (4,5), etc.
	Uses BiomeBase.remove_entanglement() for decouplng.
	"""
	if not farm or not farm.grid:
		action_performed.emit("remove_gates", false, "⚠️  Farm not loaded yet")
		return

	if positions.size() < 2:
		action_performed.emit("remove_gates", false, "⚠️  Need at least 2 plots to decouple")
		return

	_verbose.info("quantum", "🔓", "Removing entanglement for %d plots..." % positions.size())

	# Get biome from first plot
	var biome = farm.grid.get_biome_for_plot(positions[0])
	if not biome:
		action_performed.emit("remove_gates", false, "⚠️  Could not access biome")
		return

	var success_count = 0
	var removed_pairs = []

	# Process pairs
	for i in range(0, positions.size() - 1, 2):
		var pos_a = positions[i]
		var pos_b = positions[i + 1]

		if biome.remove_entanglement(pos_a, pos_b):
			success_count += 1
			removed_pairs.append("%s↔%s" % [pos_a, pos_b])
			_verbose.debug("quantum", "🔓", "Decoupled %s ↔ %s" % [pos_a, pos_b])

	action_performed.emit("remove_gates", success_count > 0,
		"%s Removed %d entanglements | %s" % ["✅" if success_count > 0 else "❌", success_count, ", ".join(removed_pairs) if removed_pairs else "no changes"])


## Tool 4 (BIOME EVOLUTION CONTROLLER) - Research-Grade Actions

func _action_boost_coupling(positions: Array[Vector2i]):
	"""Boost Hamiltonian coupling (Model B - Biome Evolution)

	Increases Hamiltonian coupling strength between emoji states via Icon modification.
	Uses BiomeBase.boost_coupling() to modify Icon parameters and rebuild Hamiltonian.
	"""
	if not farm or not farm.grid:
		action_performed.emit("boost_coupling", false, "⚠️  Farm not loaded yet")
		return

	if positions.is_empty():
		action_performed.emit("boost_coupling", false, "⚠️  No plots selected")
		return

	_verbose.info("quantum", "⚡", "Boosting coupling for %d plots..." % positions.size())

	var success_count = 0
	var boosted_pairs = []

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			continue

		# Get the emoji at this plot
		var emoji = plot.north_emoji if plot.north_emoji else "🌾"

		# Boost coupling to a default target (e.g., south emoji or neighbor)
		var target = plot.south_emoji if plot.south_emoji else "🍂"

		# Get the biome and call boost_coupling
		var biome = farm.grid.get_biome_for_plot(pos)
		if biome and biome.boost_coupling(emoji, target, 1.5):
			success_count += 1
			boosted_pairs.append("%s→%s" % [emoji, target])
			_verbose.debug("quantum", "⚡", "Boosted %s coupling at %s" % [emoji, pos])

	action_performed.emit("boost_coupling", success_count > 0,
		"%s Boosted coupling on %d/%d plots | %s" % ["✅" if success_count > 0 else "❌", success_count, positions.size(), ", ".join(boosted_pairs) if boosted_pairs else "no changes"])


func _action_tune_decoherence(positions: Array[Vector2i]):
	"""Tune Lindblad decoherence rates (Model B - Biome Evolution)

	Scales Lindblad decay rates for individual emojis via Icon modification.
	Uses BiomeBase.tune_decoherence() to modify Icon parameters and rebuild Lindblad.
	"""
	if not farm or not farm.grid:
		action_performed.emit("tune_decoherence", false, "⚠️  Farm not loaded yet")
		return

	if positions.is_empty():
		action_performed.emit("tune_decoherence", false, "⚠️  No plots selected")
		return

	_verbose.info("quantum", "🔧", "Tuning decoherence for %d plots..." % positions.size())

	var success_count = 0
	var tuned_emojis = {}

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			continue

		# Get the emoji at this plot
		var emoji = plot.north_emoji if plot.north_emoji else "🌾"

		# Get the biome and call tune_decoherence
		var biome = farm.grid.get_biome_for_plot(pos)
		if biome and biome.tune_decoherence(emoji, 1.5):
			success_count += 1
			tuned_emojis[emoji] = tuned_emojis.get(emoji, 0) + 1
			_verbose.debug("quantum", "🔧", "Tuned decoherence for %s at %s" % [emoji, pos])

	var summary = ""
	for emoji in tuned_emojis.keys():
		summary += "%s×%d " % [emoji, tuned_emojis[emoji]]

	action_performed.emit("tune_decoherence", success_count > 0,
		"%s Tuned decoherence on %d/%d plots | %s" % ["✅" if success_count > 0 else "❌", success_count, positions.size(), summary])


func _action_add_driver(positions: Array[Vector2i]):
	"""Add time-dependent driving field (Model B - Biome Evolution)

	Creates oscillating Hamiltonian term for emojis (e.g., day/night cycles).
	Uses BiomeBase.add_time_dependent_driver() with cosine modulation.
	"""
	if not farm or not farm.grid:
		action_performed.emit("add_driver", false, "⚠️  Farm not loaded yet")
		return

	if positions.is_empty():
		action_performed.emit("add_driver", false, "⚠️  No plots selected")
		return

	_verbose.info("quantum", "🌊", "Adding time-dependent drivers for %d plots..." % positions.size())

	var success_count = 0
	var driver_emojis = {}

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			continue

		# Get the emoji at this plot
		var emoji = plot.north_emoji if plot.north_emoji else "🌾"

		# Get the biome and add driver (cosine modulation, 1 Hz frequency)
		var biome = farm.grid.get_biome_for_plot(pos)
		if biome and biome.add_time_dependent_driver(emoji, "cosine", 1.0, 1.0):
			success_count += 1
			driver_emojis[emoji] = driver_emojis.get(emoji, 0) + 1
			_verbose.debug("quantum", "🌊", "Added cosine driver to %s at %s" % [emoji, pos])

	var summary = ""
	for emoji in driver_emojis.keys():
		summary += "%s×%d " % [emoji, driver_emojis[emoji]]

	action_performed.emit("add_driver", success_count > 0,
		"%s Added drivers to %d/%d plots | %s" % ["✅" if success_count > 0 else "❌", success_count, positions.size(), summary])


## DEPRECATED: Old fake physics methods (Model A artifacts)

func _action_inject_energy(positions: Array[Vector2i]):
	"""Inject energy into plots (DEPRECATED - Model A only)

	This method implemented fake quantum physics and is removed from Model B.
	Use harvest operations for resource management instead.
	"""
	action_performed.emit("inject_energy", false,
		"⚠️  DEPRECATED: Energy injection removed in Model B (use harvest instead)")


func _action_drain_energy(positions: Array[Vector2i]):
	"""Drain energy from plots (DEPRECATED - Model A only)

	This method implemented fake quantum physics and is removed from Model B.
	Use harvest operations for resource management instead.
	"""
	action_performed.emit("drain_energy", false,
		"⚠️  DEPRECATED: Energy draining removed in Model B (use harvest instead)")


func _action_place_energy_tap(positions: Array[Vector2i]):
	"""Place energy drain taps (Model B - Energy Tap Infrastructure)

	Creates Lindblad drain operators for selected plots.
	Drains population to sink state ⬇️ via L_drain = √κ |sink⟩⟨e|.
	Uses BiomeBase.place_energy_tap() with drain_rate = 0.05/sec.
	"""
	if not farm or not farm.grid:
		action_performed.emit("place_energy_tap", false, "⚠️  Farm not loaded yet")
		return

	if positions.is_empty():
		action_performed.emit("place_energy_tap", false, "⚠️  No plots selected")
		return

	_verbose.info("quantum", "💧", "Placing energy taps on %d plots..." % positions.size())

	var success_count = 0
	var tapped_emojis = {}

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			continue

		# Get the emoji at this plot
		var emoji = plot.north_emoji if plot.north_emoji else "🌾"

		# Get the biome and place energy tap
		var biome = farm.grid.get_biome_for_plot(pos)
		if biome and biome.place_energy_tap(emoji, 0.05):
			success_count += 1
			tapped_emojis[emoji] = tapped_emojis.get(emoji, 0) + 1
			_verbose.debug("quantum", "💧", "Tap placed on %s at %s" % [emoji, pos])

	var summary = ""
	for emoji in tapped_emojis.keys():
		summary += "%s×%d " % [emoji, tapped_emojis[emoji]]

	action_performed.emit("place_energy_tap", success_count > 0,
		"%s Tapped %d/%d plots | %s" % ["✅" if success_count > 0 else "❌", success_count, positions.size(), summary])


## NEW Tool 5 (GATES) Actions - INSTANTANEOUS SINGLE-QUBIT

func _action_apply_pauli_x(positions: Array[Vector2i]):
	"""Apply Pauli-X gate (bit flip) to selected plots - INSTANTANEOUS.

	Flips the qubit state: |0⟩ → |1⟩, |1⟩ → |0⟩
	Model B: Uses quantum_computer.apply_unitary_1q() with X gate matrix.
	"""
	if positions.is_empty():
		action_performed.emit("apply_pauli_x", false, "⚠️  No plots selected")
		return

	var success_count = 0
	for pos in positions:
		if _apply_single_qubit_gate(pos, "X"):
			success_count += 1
			_verbose.debug("quantum", "↔️", "Applied Pauli-X at %s" % pos)

	action_performed.emit("apply_pauli_x", success_count > 0,
		"✅ Applied Pauli-X to %d qubits" % success_count if success_count > 0 else "❌ No gates applied")


func _action_apply_hadamard(positions: Array[Vector2i]):
	"""Apply Hadamard gate (superposition) to selected plots - INSTANTANEOUS.

	Creates equal superposition from basis states:
	|0⟩ → (|0⟩ + |1⟩)/√2, |1⟩ → (|0⟩ - |1⟩)/√2
	Model B: Uses quantum_computer.apply_unitary_1q() with H gate matrix.
	"""
	if positions.is_empty():
		action_performed.emit("apply_hadamard", false, "⚠️  No plots selected")
		return

	var success_count = 0
	for pos in positions:
		if _apply_single_qubit_gate(pos, "H"):
			success_count += 1
			_verbose.debug("quantum", "🌀", "Applied Hadamard at %s" % pos)

	action_performed.emit("apply_hadamard", success_count > 0,
		"✅ Applied Hadamard to %d qubits" % success_count if success_count > 0 else "❌ No gates applied")


func _action_apply_pauli_z(positions: Array[Vector2i]):
	"""Apply Pauli-Z gate (phase flip) to selected plots - INSTANTANEOUS.

	Applies a phase flip: |0⟩ → |0⟩, |1⟩ → -|1⟩
	Proper unitary: ρ' = ZρZ† where Z = [[1,0],[0,-1]]
	Model B: Uses quantum_computer.apply_unitary_1q() with Z gate matrix.
	"""
	if positions.is_empty():
		action_performed.emit("apply_pauli_z", false, "⚠️  No plots selected")
		return

	var success_count = 0
	for pos in positions:
		if _apply_single_qubit_gate(pos, "Z"):
			success_count += 1
			_verbose.debug("quantum", "⚡", "Applied Pauli-Z at %s" % pos)

	action_performed.emit("apply_pauli_z", success_count > 0,
		"✅ Applied Pauli-Z to %d qubits" % success_count if success_count > 0 else "❌ No gates applied")


## NEW Tool 4 (ENERGY) - Energy Tap with specific emoji target

func _action_place_energy_tap_for(positions: Array[Vector2i], target_emoji: String):
	"""Place energy tap targeting specific emoji (Model B, v2)

	Kitchen v2: Energy taps create Lindblad drains on the biome quantum computer.
	Taps do NOT require plots to be planted - they operate biome-level.

	Creates Lindblad drain operators for the specified emoji.
	Drains population to sink state via L_drain = √κ |sink⟩⟨target⟩.
	"""
	if not farm or not farm.grid:
		action_performed.emit("place_energy_tap", false, "⚠️  Farm not loaded yet")
		return

	if positions.is_empty():
		action_performed.emit("place_energy_tap", false, "⚠️  No plots selected")
		return

	_verbose.info("quantum", "💧", "Placing energy taps targeting %s on %d plots..." % [target_emoji, positions.size()])

	var success_count = 0

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot:
			continue

		# Kitchen v2: Get the biome and place energy tap for target emoji
		# Taps operate biome-level, NOT plot-level
		# No is_planted check needed - taps work on empty plots too
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome:
			continue

		# Check if emoji has a register in this biome
		# (For BioticFlux: wheat, flour. For Kitchen: fire, water, flour)
		if biome.has_method("can_tap_emoji") and not biome.can_tap_emoji(target_emoji):
			_verbose.warn("quantum", "⚠️", "Cannot tap %s in %s" % [target_emoji, biome.get_biome_type()])
			continue

		if biome.place_energy_tap(target_emoji, 0.05):
			success_count += 1
			_verbose.debug("quantum", "💧", "Tap on %s placed at %s" % [target_emoji, pos])

	action_performed.emit("place_energy_tap", success_count > 0,
		"%s Placed %d energy taps targeting %s" % ["✅" if success_count > 0 else "❌", success_count, target_emoji])


## NEW Tool 5 (GATES) - Two-Qubit Gates

func _action_apply_cnot(positions: Array[Vector2i]):
	"""Apply CNOT gate via quantum_computer (Model B)

	Applies CNOT gates to sequential position pairs:
	- Pair (0,1): control=0, target=1
	- Pair (2,3): control=2, target=3
	- Odd remaining position ignored
	"""
	if positions.is_empty():
		action_performed.emit("apply_cnot", false, "⚠️  No plots selected")
		return

	var success_count = 0
	for i in range(0, positions.size() - 1, 2):
		var control_pos = positions[i]
		var target_pos = positions[i + 1]
		if _apply_two_qubit_gate(control_pos, target_pos, "CNOT"):
			success_count += 1

	action_performed.emit("apply_cnot", success_count > 0,
		"✅ Applied CNOT to %d qubit pairs" % success_count if success_count > 0 else "❌ No gates applied")


func _action_apply_cz(positions: Array[Vector2i]):
	"""Apply CZ gate via quantum_computer (Model B)

	Applies CZ gates to sequential position pairs:
	- Pair (0,1): first qubit, second qubit
	- Pair (2,3): first qubit, second qubit
	- Odd remaining position ignored
	"""
	if positions.is_empty():
		action_performed.emit("apply_cz", false, "⚠️  No plots selected")
		return

	var success_count = 0
	for i in range(0, positions.size() - 1, 2):
		var pos_a = positions[i]
		var pos_b = positions[i + 1]
		if _apply_two_qubit_gate(pos_a, pos_b, "CZ"):
			success_count += 1

	action_performed.emit("apply_cz", success_count > 0,
		"✅ Applied CZ to %d qubit pairs" % success_count if success_count > 0 else "❌ No gates applied")


func _action_apply_swap(positions: Array[Vector2i]):
	"""Apply SWAP gate via quantum_computer (Model B)

	Applies SWAP gates to sequential position pairs:
	- Pair (0,1): swap qubits
	- Pair (2,3): swap qubits
	- Odd remaining position ignored
	"""
	if positions.is_empty():
		action_performed.emit("apply_swap", false, "⚠️  No plots selected")
		return

	var success_count = 0
	for i in range(0, positions.size() - 1, 2):
		var pos_a = positions[i]
		var pos_b = positions[i + 1]
		if _apply_two_qubit_gate(pos_a, pos_b, "SWAP"):
			success_count += 1

	action_performed.emit("apply_swap", success_count > 0,
		"✅ Applied SWAP to %d qubit pairs" % success_count if success_count > 0 else "❌ No gates applied")


func _extract_emoji_from_action(action: String) -> String:
	"""Extract target emoji from dynamic tap action

	Looks up emoji from cached submenu based on action name.
	This allows dynamic emoji targets beyond hardcoded wheat/mushroom/tomato.

	Args:
		action: Action string like "tap_wheat" or "tap_emoji_12345"

	Returns:
		Emoji string, or empty if not found
	"""
	# Search cached submenu for matching action
	for key in ["Q", "E", "R"]:
		if _cached_submenu.has(key):
			var action_info = _cached_submenu[key]
			if action_info.get("action", "") == action:
				return action_info.get("emoji", "")

	# Fallback: Parse from hardcoded action names
	match action:
		"tap_wheat": return "🌾"
		"tap_mushroom": return "🍄"
		"tap_tomato": return "🍅"
		"tap_fire": return "🔥"
		"tap_water": return "💧"
		"tap_flour": return "💨"
		_: return ""


## Help System

func _print_help():
	"""Print keyboard help to console"""
	var line = ""
	for i in range(60):
		line += "="

	_verbose.info("input", "⌨️", "\n" + line)
	_verbose.info("input", "⌨️", "FARM KEYBOARD CONTROLS (Tool Mode System)")
	_verbose.info("input", "⌨️", line)

	_verbose.info("input", "🛠️", "\nTOOL SELECTION (Numbers 1-4):")
	for tool_num in range(1, 5):
		if TOOL_ACTIONS.has(tool_num):
			var tool = TOOL_ACTIONS[tool_num]
			_verbose.info("input", "🛠️", "  %d = %s" % [tool_num, tool["name"]])

	_verbose.info("input", "⚡", "\nACTIONS (Q/E/R - Context-sensitive):")
	var tool = TOOL_ACTIONS[current_tool]
	_verbose.info("input", "⚡", "  Current Tool: %s" % tool["name"])
	_verbose.info("input", "⚡", "  Q = %s" % tool["Q"]["label"])
	_verbose.info("input", "⚡", "  E = %s" % tool["E"]["label"])
	_verbose.info("input", "⚡", "  R = %s" % tool["R"]["label"])

	_verbose.info("input", "📍", "\nMULTI-SELECT PLOTS (NEW):")
	_verbose.info("input", "📍", "  T/Y/U/I/O/P = Toggle checkbox on plots 1-6")
	_verbose.info("input", "📍", "  [ = Deselect all plots")
	_verbose.info("input", "📍", "  ] = Restore previous selection state")
	_verbose.info("input", "📍", "  Q/E/R = Apply current tool action to ALL selected plots")

	_verbose.info("input", "🎮", "\nMOVEMENT (Legacy - for focus/cursor):")
	_verbose.info("input", "🎮", "  WASD = Move cursor (up/left/down/right)")

	_verbose.info("input", "📋", "\nDEBUG:")
	_verbose.info("input", "📋", "  ? = Show this help")
	_verbose.info("input", "📋", "  I = Toggle info panel")

	_verbose.info("input", "⌨️", line + "\n")


## Helper Methods

func _get_biome_for_position(pos: Vector2i):
	"""Get the biome that contains this position"""
	if not farm or not farm.grid:
		return null
	return farm.grid.get_biome_for_plot(pos)


## Tool 6: Biome Management Actions

func _action_assign_plots_to_biome(plots: Array[Vector2i], biome_name: String):
	"""Reassign selected plots to target biome

	NOTE: This CHANGES the biome assignment but does NOT:
	- Destroy existing quantum states (they persist)
	- Clear entanglement links (they persist)
	- Harvest crops (use Tool 1 R for that)

	The plot keeps its quantum state but future operations use new biome's bath.
	"""
	if plots.is_empty():
		_verbose.warn("farm", "⚠️", "No plots selected for biome assignment")
		action_performed.emit("assign_plots_to_biome", false, "No plots")
		return

	# Verify biome exists
	if not farm.grid.biomes.has(biome_name):
		_verbose.error("farm", "❌", "Biome '%s' not registered!" % biome_name)
		action_performed.emit("assign_plots_to_biome", false, "Biome not found")
		return

	_verbose.info("farm", "🌍", "Reassigning %d plot(s) to %s biome..." % [plots.size(), biome_name])

	var success_count = 0
	for pos in plots:
		# Get current biome (for logging)
		var old_biome = farm.grid.plot_biome_assignments.get(pos, "None")

		# Reassign to new biome
		farm.grid.assign_plot_to_biome(pos, biome_name)

		_verbose.debug("farm", "🌍", "Plot %s: %s → %s" % [pos, old_biome, biome_name])
		success_count += 1

	_verbose.info("farm", "✅", "Reassigned %d plot(s) to %s" % [success_count, biome_name])
	action_performed.emit("assign_plots_to_biome", true,
		"%d plots → %s" % [success_count, biome_name])


func _action_clear_biome_assignment(plots: Array[Vector2i]):
	"""Remove biome assignment from selected plots

	Returns plots to unassigned state. Future operations will fail
	unless plot is reassigned to a biome first.
	"""
	if plots.is_empty():
		_verbose.warn("farm", "⚠️", "No plots selected to clear")
		action_performed.emit("clear_biome_assignment", false, "No plots")
		return

	_verbose.info("farm", "🌍", "Clearing biome assignment for %d plot(s)..." % plots.size())

	var success_count = 0
	for pos in plots:
		var old_biome = farm.grid.plot_biome_assignments.get(pos, "None")

		# Remove from assignments dict
		farm.grid.plot_biome_assignments.erase(pos)

		_verbose.debug("farm", "🌍", "Plot %s: %s → (unassigned)" % [pos, old_biome])
		success_count += 1

	_verbose.info("farm", "✅", "Cleared %d plot(s)" % success_count)
	action_performed.emit("clear_biome_assignment", true,
		"Cleared %d plots" % success_count)


func _action_inspect_plot(plots: Array[Vector2i]):
	"""Show detailed metadata for selected plot(s)

	Displays:
	- Current biome assignment
	- Quantum state (if planted)
	- Entanglement links
	- Bath projection info

	Also opens the biome inspector overlay for the first selected plot
	"""
	if plots.is_empty():
		_verbose.warn("farm", "⚠️", "No plots selected to inspect")
		action_performed.emit("inspect_plot", false, "No plots")
		return

	_verbose.info("farm", "🔍", "PLOT INSPECTION")
	_verbose.info("farm", "🔍", "──────────────────────────────────────────────────────────────────────")

	var inspected_count = 0
	var first_biome_name = ""

	for pos in plots:
		_verbose.info("farm", "📍", "\nPlot %s:" % pos)

		# Biome assignment
		var biome_name = farm.grid.plot_biome_assignments.get(pos, "(unassigned)")
		_verbose.info("farm", "🌍", "   Biome: %s" % biome_name)

		if inspected_count == 0:
			first_biome_name = biome_name

		# Get plot instance
		var plot = farm.grid.get_plot(pos)
		if not plot:
			_verbose.error("farm", "❌", "   Plot not found in grid!")
			continue

		# Plant status
		if plot.is_planted:
			# Get planted crop emojis
			var emojis = plot.get_plot_emojis()
			var planted_emoji = "%s↔%s" % [emojis.get("north", "?"), emojis.get("south", "?")]
			_verbose.info("farm", "🌱", "   Planted: %s" % planted_emoji)
			_verbose.debug("farm", "🌱", "      Has been measured: %s" % ("YES" if plot.has_been_measured else "NO"))

			# Quantum state info (Model C)
			if plot.parent_biome and plot.bath_subplot_id >= 0:
				var north = plot.north_emoji
				var south = plot.south_emoji
				# Get purity from bath
				var biome = plot.parent_biome
				var purity = 0.5
				if biome.bath:
					purity = biome.bath.get_purity()
				_verbose.debug("quantum", "⚛️", "      State: %s ↔ %s | Purity: %.3f" % [north, south, purity])
		else:
			_verbose.info("farm", "🌱", "   Planted: NO")

		# Entanglement links
		if biome_name != "(unassigned)":
			var biome = farm.grid.biomes.get(biome_name)
			if biome and biome.bell_gates:
				var is_entangled = false
				for gate in biome.bell_gates:
					if pos in gate:
						is_entangled = true
						_verbose.debug("quantum", "🔗", "   Entangled with: %s" % gate)
						break

				if not is_entangled:
					_verbose.debug("quantum", "🔗", "   Entangled: NO")

		# Bath projection (if plot is in a biome)
		if biome_name != "(unassigned)":
			var biome = farm.grid.biomes.get(biome_name)
			if biome and biome.active_projections.has(pos):
				var projection = biome.active_projections[pos]
				_verbose.debug("quantum", "🛁", "   Bath Projection: Active")
				if projection.has("north") and projection.has("south"):
					_verbose.debug("quantum", "🛁", "      North: %s | South: %s" % [projection.north, projection.south])

		inspected_count += 1

	_verbose.info("farm", "🔍", "\n──────────────────────────────────────────────────────────────────────")
	_verbose.info("farm", "✅", "Inspected %d plot(s)" % inspected_count)

	# Open biome inspector overlay for first plot's biome
	if first_biome_name != "" and first_biome_name != "(unassigned)":
		# Get biome inspector overlay from OverlayManager
		var overlay_manager = _get_overlay_manager()
		if overlay_manager and overlay_manager.biome_inspector:
			overlay_manager.biome_inspector.inspect_plot_biome(plots[0], farm)
			_verbose.info("farm", "🌍", "Opened biome inspector for plot %s's biome: %s" % [plots[0], first_biome_name])

	action_performed.emit("inspect_plot", true,
		"Inspected %d plots" % inspected_count)


func _get_overlay_manager():
	"""Navigate scene tree to find OverlayManager

	Hierarchy: FarmInputHandler → FarmUI → FarmView → PlayerShell → OverlayManager
	"""
	# Navigate up the tree to find PlayerShell
	var current = self
	while current:
		if current.has_method("get_class"):
			var node_class = current.get_class()
			# Check if it's PlayerShell (or has overlay_manager property)
			if current.has_node("OverlayManager") or current.get("overlay_manager"):
				return current.get("overlay_manager")

		# Try by node name
		if current.name == "PlayerShell" or current.name.contains("Shell"):
			if current.has_node("OverlayManager"):
				return current.get_node("OverlayManager")
			elif current.get("overlay_manager"):
				return current.get("overlay_manager")

		current = current.get_parent()

	push_warning("_get_overlay_manager: Could not find OverlayManager in scene tree")
	return null

## ═══════════════════════════════════════════════════════════════════════════
## Phase 4 UI: Pump & Reset Operations (Gozinta Channels)
## ═══════════════════════════════════════════════════════════════════════════

func _action_pump_to_wheat(plots: Array[Vector2i]):
	"""Pump population to wheat (Model B - Lindblad Operations)

	Transfers population from environment to wheat via Lindblad pump operator.
	L_pump = √Γ |wheat⟩⟨environment|
	Uses BiomeBase.pump_to_emoji() to add pump channel.
	"""
	if not farm or not farm.grid:
		action_performed.emit("pump_to_wheat", false, "⚠️  Farm not loaded yet")
		return

	if plots.is_empty():
		action_performed.emit("pump_to_wheat", false, "⚠️  No plots selected")
		return

	_verbose.info("quantum", "⛩️", "Pumping to wheat for %d plots..." % plots.size())

	var success_count = 0
	var pumped = {}

	for pos in plots:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			continue

		# Source is environment (🍂), target is wheat (🌾)
		var biome = farm.grid.get_biome_for_plot(pos)
		if biome and biome.pump_to_emoji("🍂", "🌾", 0.05):
			success_count += 1
			pumped["🍂→🌾"] = pumped.get("🍂→🌾", 0) + 1
			_verbose.debug("quantum", "⛩️", "Pump established at %s" % pos)

	var summary = ""
	for pair in pumped.keys():
		summary += "%s×%d " % [pair, pumped[pair]]

	action_performed.emit("pump_to_wheat", success_count > 0,
		"%s Pumped wheat on %d/%d plots | %s" % ["✅" if success_count > 0 else "❌", success_count, plots.size(), summary])


func _action_reset_to_pure(plots: Array[Vector2i]):
	"""Reset to pure state (Model B - Lindblad Operations)

	Resets quantum state to pure |0⟩⟨0| via Lindblad reset channel.
	ρ ← (1-α)ρ + α|0⟩⟨0|
	Uses BiomeBase.reset_to_pure_state() to add reset channel.
	"""
	if not farm or not farm.grid:
		action_performed.emit("reset_to_pure", false, "⚠️  Farm not loaded yet")
		return

	if plots.is_empty():
		action_performed.emit("reset_to_pure", false, "⚠️  No plots selected")
		return

	_verbose.info("quantum", "🔄", "Resetting to pure state for %d plots..." % plots.size())

	var success_count = 0
	var reset_emojis = {}

	for pos in plots:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			continue

		var emoji = plot.north_emoji if plot.north_emoji else "🌾"
		var biome = farm.grid.get_biome_for_plot(pos)
		if biome and biome.reset_to_pure_state(emoji, 0.1):
			success_count += 1
			reset_emojis[emoji] = reset_emojis.get(emoji, 0) + 1
			_verbose.debug("quantum", "🔄", "Pure reset for %s at %s" % [emoji, pos])

	var summary = ""
	for emoji in reset_emojis.keys():
		summary += "%s×%d " % [emoji, reset_emojis[emoji]]

	action_performed.emit("reset_to_pure", success_count > 0,
		"%s Reset to pure on %d/%d plots | %s" % ["✅" if success_count > 0 else "❌", success_count, plots.size(), summary])


func _action_reset_to_mixed(plots: Array[Vector2i]):
	"""Reset to mixed state (Model B - Lindblad Operations)

	Resets quantum state to maximally mixed I/N via Lindblad channel.
	ρ ← (1-α)ρ + α(I/N)
	Uses BiomeBase.reset_to_mixed_state() to add reset channel.
	"""
	if not farm or not farm.grid:
		action_performed.emit("reset_to_mixed", false, "⚠️  Farm not loaded yet")
		return

	if plots.is_empty():
		action_performed.emit("reset_to_mixed", false, "⚠️  No plots selected")
		return

	_verbose.info("quantum", "🔀", "Resetting to mixed state for %d plots..." % plots.size())

	var success_count = 0
	var reset_emojis = {}

	for pos in plots:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			continue

		var emoji = plot.north_emoji if plot.north_emoji else "🌾"
		var biome = farm.grid.get_biome_for_plot(pos)
		if biome and biome.reset_to_mixed_state(emoji, 0.1):
			success_count += 1
			reset_emojis[emoji] = reset_emojis.get(emoji, 0) + 1
			_verbose.debug("quantum", "🔀", "Mixed reset for %s at %s" % [emoji, pos])

	var summary = ""
	for emoji in reset_emojis.keys():
		summary += "%s×%d " % [emoji, reset_emojis[emoji]]

	action_performed.emit("reset_to_mixed", success_count > 0,
		"%s Reset to mixed on %d/%d plots | %s" % ["✅" if success_count > 0 else "❌", success_count, plots.size(), summary])


# ============================================================================
# ACTION VALIDATION - Check if actions can succeed without executing
# ============================================================================

func can_execute_action(action_key: String) -> bool:
	"""Check if action for given key can succeed with current selection

	Called by ActionPreviewRow to determine button highlighting.
	Uses any-valid strategy: returns true if at least 1 plot can succeed.

	Args:
		action_key: "Q", "E", or "R"

	Returns:
		bool: true if action would succeed on at least one selected plot
	"""
	if current_submenu != "":
		return _can_execute_submenu_action(action_key)
	else:
		return _can_execute_tool_action(action_key)


func _can_execute_tool_action(action_key: String) -> bool:
	"""Check if tool action can succeed (not in submenu)"""
	var selected_plots = plot_grid_display.get_selected_plots() if plot_grid_display else []

	if selected_plots.is_empty():
		return false

	var tool = ToolConfig.TOOL_ACTIONS.get(current_tool, {})
	var action = tool.get(action_key, {}).get("action", "")

	# Route to specific validation based on action type
	match action:
		"plant_batch":
			return _can_plant_any(selected_plots)
		"entangle_batch":
			return _can_entangle(selected_plots)
		"measure_and_harvest":
			return _can_harvest_any(selected_plots)
		_:
			return false


func _can_execute_submenu_action(action_key: String) -> bool:
	"""Check if submenu action can succeed"""
	var selected_plots = plot_grid_display.get_selected_plots() if plot_grid_display else []

	if selected_plots.is_empty():
		return false

	var submenu = _cached_submenu if not _cached_submenu.is_empty() else ToolConfig.get_submenu(current_submenu)

	# Check if entire submenu disabled
	if submenu.get("_disabled", false):
		return false

	var action_info = submenu.get(action_key, {})
	var action = action_info.get("action", "")

	# Empty action = locked slot
	if action == "":
		return false

	# Route to specific validation
	match action:
		"plant_wheat":
			return _can_plant_type("wheat", selected_plots)
		"plant_mushroom":
			return _can_plant_type("mushroom", selected_plots)
		"plant_tomato":
			return _can_plant_type("tomato", selected_plots)
		"plant_fire":
			return _can_plant_type("fire", selected_plots)
		"plant_water":
			return _can_plant_type("water", selected_plots)
		"plant_flour":
			return _can_plant_type("flour", selected_plots)
		"plant_ice":
			return _can_plant_type("ice", selected_plots)
		"plant_desert":
			return _can_plant_type("desert", selected_plots)
		_:
			return false


func _can_plant_any(plots: Array[Vector2i]) -> bool:
	"""Check if we can open plant submenu (at least one plot empty)"""
	if not farm or plots.is_empty():
		return false

	# Check at least ONE plot is empty
	for pos in plots:
		var plot = farm.grid.get_plot(pos)
		if plot and not plot.is_planted:
			return true

	return false


func _can_plant_type(plant_type: String, plots: Array[Vector2i]) -> bool:
	"""Check if we can plant this specific type on any selected plot"""
	if not farm or plots.is_empty():
		return false

	var config = Farm.BUILD_CONFIGS.get(plant_type, {})
	if config.is_empty():
		return false

	# Check resources (same check for all plots)
	if not farm.economy.can_afford_cost(config.get("cost", {})):
		return false

	# Check at least ONE plot is valid (any-valid strategy)
	for pos in plots:
		var plot = farm.grid.get_plot(pos)
		if not plot:
			continue

		# Must be empty
		if plot.is_planted:
			continue

		# Check biome requirement if specified
		if config.has("biome_required"):
			var biome_name = farm.grid.plot_biome_assignments.get(pos, "")
			if biome_name != config["biome_required"]:
				continue

		# Found at least one valid plot!
		return true

	return false


func _can_harvest_any(plots: Array[Vector2i]) -> bool:
	"""Check if any plot can be harvested"""
	if not farm or plots.is_empty():
		return false

	for pos in plots:
		var plot = farm.grid.get_plot(pos)
		if plot and plot.is_planted:
			return true

	return false


func _can_entangle(plots: Array[Vector2i]) -> bool:
	"""Check if we can entangle selected plots"""
	if not farm or plots.size() < 2:
		return false

	# ALL plots must be planted
	for pos in plots:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			return false

	return true

