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
const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")
const Farm = preload("res://Core/Farm.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

# Tool actions from shared config (single source of truth)
const TOOL_ACTIONS = ToolConfig.TOOL_ACTIONS

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = get_node("/root/VerboseConfig")

var farm  # Will be injected with Farm instance (Farm.gd)
var plot_grid_display: Node = null  # Will be injected with PlotGridDisplay instance
var current_selection: Vector2i = Vector2i.ZERO
var current_tool: int = 1  # Active tool (1-4, v2 architecture)
var current_submenu: String = ""  # Active submenu name (empty = no submenu)
var _cached_submenu: Dictionary = {}  # Cached dynamic submenu during session
var grid_config: GridConfig = null  # Grid configuration (Phase 7)
var input_enable_frame_count: int = 0  # Counter to enable input after N frames

# v2 Architecture State
var evolution_paused: bool = false  # Spacebar toggle for quantum evolution

# Config (deprecated - now read from GridConfig)
var grid_width: int = 6
var grid_height: int = 2

# Debug: Set to true to enable verbose logging (keystroke-by-keystroke, location info, etc)
const VERBOSE = true  # Enabled for debugging keyboard issues

# ═══════════════════════════════════════════════════════════════
# Plot Emoji Accessors (Model C)
# ═══════════════════════════════════════════════════════════════

func _get_plot_north_emoji(plot) -> String:
	"""Get north emoji for a plot (returns '?' if not planted)"""
	if plot and plot.is_planted and plot.north_emoji:
		return plot.north_emoji
	return "?"

func _get_plot_south_emoji(plot) -> String:
	"""Get south emoji for a plot (returns '?' if not planted)"""
	if plot and plot.is_planted and plot.south_emoji:
		return plot.south_emoji
	return "?"

# ═══════════════════════════════════════════════════════════════
# Quantum Gate Helper Functions (Model C)
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

# v2 Architecture Signals
signal mode_changed(new_mode: String)  # "play" or "build"
signal pause_toggled(is_paused: bool)  # Evolution pause state
signal tool_mode_cycled(tool_num: int, new_mode_index: int, mode_label: String)  # F-cycling

func _ready():
	_verbose.info("input", "⌨️", "FarmInputHandler initialized (Tool Mode System)")
	if VERBOSE:
		_verbose.debug("input", "📍", "Starting position: %s" % current_selection)
		_verbose.debug("input", "🛠️", "Current tool: %s" % TOOL_ACTIONS[current_tool]["name"])
	# Input is ready immediately - PlotGridDisplay is initialized before this
	# No deferred calls needed
	# CRITICAL: Enable _unhandled_input() processing (not _input()!)
	set_process_unhandled_input(true)
	_verbose.info("input", "✅", "Unhandled input processing enabled (no deferred delays)")
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
			set_process_unhandled_input(true)  # Enable _unhandled_input() callback
			_verbose.info("input", "✅", "Unhandled input processing enabled (UI ready)")
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

	# ═══════════════════════════════════════════════════════════════
	# v2 GLOBAL CONTROLS (always processed first)
	# ═══════════════════════════════════════════════════════════════

	# Spacebar: Toggle evolution pause
	if event.is_action_pressed("pause"):
		_toggle_evolution_pause()
		get_viewport().set_input_as_handled()
		return

	# H: HARVEST - Global collapse, end level
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		_action_harvest_global()
		get_viewport().set_input_as_handled()
		return

	# Tab: Toggle BUILD/PLAY mode
	if event.is_action_pressed("toggle_mode"):
		_toggle_build_play_mode()
		get_viewport().set_input_as_handled()
		return

	# F: Cycle tool mode (for tools with F-cycling like GATES, ENTANGLE)
	# Note: If overlay is active, PlayerShell routes F to overlay first.
	# This only runs if no overlay consumed the input.
	if event.is_action_pressed("action_f"):
		_cycle_current_tool_mode()
		get_viewport().set_input_as_handled()
		return

	# NOTE: v2 overlay input routing moved to PlayerShell.OverlayStackManager
	# PlayerShell._input() routes to overlays BEFORE reaching FarmInputHandler

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
		elif event.keycode == KEY_BACKSPACE:  # Backspace - Remove Gates (only with Tool 5)
			if current_tool == 5 and current_submenu == "":  # Only if Tool 5 is active and not in submenu
				var selected_plots: Array[Vector2i] = []
				if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
					selected_plots = plot_grid_display.get_selected_plots()
				if selected_plots.is_empty() and _is_valid_position(current_selection):
					selected_plots = [current_selection]
				if not selected_plots.is_empty():
					_action_remove_gates(selected_plots)
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

	# Action keys (Q/E/R or gamepad buttons A/B/X)
	# Use both InputMap actions (for gamepad) AND raw keycodes (for keyboard reliability)
	if event is InputEventKey and event.pressed:
		var key = event.keycode
		var action_key: String = ""

		# Map keycode to action
		match key:
			KEY_Q:
				action_key = "Q"
			KEY_E:
				action_key = "E"
			KEY_R:
				action_key = "R"

		if action_key != "":
			if VERBOSE:
				_verbose.debug("input", "⚡", "QER keycode detected: %s → %s" % [key, action_key])
			_execute_tool_action(action_key)
			get_viewport().set_input_as_handled()
			return

	# Also check InputMap actions for gamepad support
	if event.is_action_pressed("action_q"):
		if VERBOSE:
			_verbose.debug("input", "⚡", "action_q (InputMap) detected")
		_execute_tool_action("Q")
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("action_e"):
		if VERBOSE:
			_verbose.debug("input", "⚡", "action_e (InputMap) detected")
		_execute_tool_action("E")
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("action_r"):
		if VERBOSE:
			_verbose.debug("input", "⚡", "action_r (InputMap) detected")
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
	"""Select active tool (1-4, v2 architecture)"""
	if not TOOL_ACTIONS.has(tool_num):
		_verbose.warn("input", "⚠️", "Tool %d not available" % tool_num)
		return

	# Exit any active submenu when switching tools
	if current_submenu != "":
		_exit_submenu()

	current_tool = tool_num
	var tool_info = TOOL_ACTIONS[tool_num]
	_verbose.info("input", "🛠️", "Tool switched to: %s" % tool_info["name"])
	# v2 structure: actions are nested under "actions" key
	if VERBOSE:
		var actions = tool_info.get("actions", {})
		_verbose.debug("input", "🛠️", "Q = %s" % actions.get("Q", {}).get("label", "?"))
		_verbose.debug("input", "🛠️", "E = %s" % actions.get("E", {}).get("label", "?"))
		_verbose.debug("input", "🛠️", "R = %s" % actions.get("R", {}).get("label", "?"))

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

		# Phase gate submenu (NEW)
		"apply_pauli_y":
			_action_apply_pauli_y(selected_plots)
		"apply_s_gate":
			_action_apply_s_gate(selected_plots)
		"apply_t_gate":
			_action_apply_t_gate(selected_plots)
		"apply_sdg_gate":
			_action_apply_sdg_gate(selected_plots)

		# Rotation gate submenu (BUILD Tool 4 Mode 2)
		"apply_rx_gate":
			_action_apply_rx_gate(selected_plots)
		"apply_ry_gate":
			_action_apply_ry_gate(selected_plots)
		"apply_rz_gate":
			_action_apply_rz_gate(selected_plots)

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

		# Lindblad control actions
		"lindblad_drive":
			_action_lindblad_drive(selected_plots)

		"lindblad_decay":
			_action_lindblad_decay(selected_plots)

		"lindblad_transfer":
			_action_lindblad_transfer(selected_plots)

		# Non-destructive state inspection
		"peek_state":
			_action_peek_state(selected_plots)

		# Tool 2 (Icon) - BUILD mode
		"icon_swap":
			_action_icon_swap(selected_plots)

		"icon_clear":
			_action_icon_clear(selected_plots)

		# Tool 4 (System) - BUILD mode
		"system_reset":
			_action_system_reset(selected_plots)

		"system_snapshot":
			_action_system_snapshot(selected_plots)

		"system_debug":
			_action_system_debug(selected_plots)

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

	# Use ToolConfig API to get action (handles F-cycling and nested structure)
	var action_info = ToolConfig.get_action(current_tool, action_key)
	if action_info.is_empty():
		_verbose.warn("input", "⚠️", "Action %s not available for tool %d" % [action_key, current_tool])
		return

	var action = action_info.get("action", "")
	var label = action_info.get("label", "")

	if action == "":
		_verbose.warn("input", "⚠️", "Action %s has no action defined for tool %d" % [action_key, current_tool])
		return

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

	var tool_name = ToolConfig.get_tool_name(current_tool)
	_verbose.info("input", "⚡", "Tool %d (%s) | Key %s | Action: %s | Plots: %d selected" % [current_tool, tool_name, action_key, label, selected_plots.size()])

	# Execute the action based on type (now with multi-select support)
	match action:
		# Tool 1: PROBE - v2 EXPLORE/MEASURE/POP (Quantum Tomography Paradigm)
		"explore":
			_action_explore()
		"measure":
			_action_measure(selected_plots)
		"pop":
			_action_pop(selected_plots)

		# Legacy actions (deprecated but kept for backwards compatibility)
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

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE ACTIONS (Tab to switch)
		# ═══════════════════════════════════════════════════════════════

		# BUILD Tool 1: BIOME - Assign/Clear biome, Inspect
		"clear_biome_assignment":
			_action_clear_biome_assignment(selected_plots)
		"inspect_plot":
			_action_inspect_plot(selected_plots)

		# BUILD Tool 2: ICON - Swap/Clear icons
		"icon_swap":
			_action_icon_swap(selected_plots)
		"icon_clear":
			_action_icon_clear(selected_plots)

		# BUILD Tool 3: LINDBLAD - Dissipation control
		"lindblad_drive":
			_action_lindblad_drive(selected_plots)
		"lindblad_decay":
			_action_lindblad_decay(selected_plots)
		"lindblad_transfer":
			_action_lindblad_transfer(selected_plots)

		# BUILD Tool 4: QUANTUM (system mode) - System control
		"system_reset":
			_action_system_reset(selected_plots)
		"system_snapshot":
			_action_system_snapshot(selected_plots)
		"system_debug":
			_action_system_debug(selected_plots)

		# BUILD Tool 4: QUANTUM (phase mode) - Phase gates
		"apply_s_gate":
			_action_apply_s_gate(selected_plots)
		"apply_t_gate":
			_action_apply_t_gate(selected_plots)
		"apply_sdg_gate":
			_action_apply_sdg_gate(selected_plots)

		# BUILD Tool 4: QUANTUM (rotation mode) - Rotation gates
		"apply_rx_gate":
			_action_apply_rx_gate(selected_plots)
		"apply_ry_gate":
			_action_apply_ry_gate(selected_plots)
		"apply_rz_gate":
			_action_apply_rz_gate(selected_plots)

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
	"""Plant multiple plots with the given plant type (PARAMETRIC - Phase 3)

	Queries biome capabilities for validation and cost checking.
	Groups plots by biome to handle different capabilities.
	"""
	if not farm:
		action_performed.emit("plant_%s" % plant_type, false, "⚠️  Farm not loaded yet")
		_verbose.error("farm", "❌", "PLANT FAILED: Farm not loaded")
		return

	if not farm.grid:
		action_performed.emit("plant_%s" % plant_type, false, "⚠️  Farm grid not ready")
		_verbose.error("farm", "❌", "PLANT FAILED: Farm grid not ready")
		return

	# Group plots by biome (different biomes may have different capabilities)
	var plots_by_biome = {}
	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome:
			_verbose.warn("farm", "⚠️", "Plot %s has no biome - skipping" % pos)
			continue

		var biome_type = biome.get_biome_type()
		if not plots_by_biome.has(biome_type):
			plots_by_biome[biome_type] = {
				"biome": biome,
				"positions": []
			}
		plots_by_biome[biome_type].positions.append(pos)

	# Plant in each biome group
	var total_success = 0
	var total_failed = 0
	var first_capability = null  # For display emoji

	for biome_type in plots_by_biome.keys():
		var biome_data = plots_by_biome[biome_type]
		var biome = biome_data.biome
		var biome_positions = biome_data.positions

		# Find capability for this plant_type in this biome (PARAMETRIC!)
		var capability = null
		for cap in biome.get_plantable_capabilities():
			if cap.plant_type == plant_type:
				capability = cap
				break

		# Track first capability for display
		if not first_capability and capability:
			first_capability = capability

		# Validate biome supports this plant type
		if not capability:
			_verbose.warn("farm", "❌", "%s biome doesn't support %s - skipping %d plots" % [
				biome_type, plant_type, biome_positions.size()])
			total_failed += biome_positions.size()
			continue

		# Plant each plot in this biome group
		for pos in biome_positions:
			# PARAMETRIC (Phase 6): farm.build() queries biome capabilities
			if farm.build(pos, plant_type):
				total_success += 1
			else:
				total_failed += 1

	# Report results
	var emoji = first_capability.emoji_pair.north if first_capability else "❓"
	var display_name = first_capability.display_name if first_capability else plant_type

	if total_success > 0:
		_verbose.info("farm", "🌱", "Planted %d × %s %s" % [total_success, emoji, display_name])
		action_performed.emit("plant_%s" % plant_type, true,
			"✅ Planted %d %s plots" % [total_success, display_name])
	else:
		_verbose.error("farm", "❌", "Failed to plant any %s (tried %d plots)" % [display_name, positions.size()])
		action_performed.emit("plant_%s" % plant_type, false,
			"❌ Failed to plant %s (%d plots)" % [display_name, total_failed])


func _action_batch_measure(positions: Array[Vector2i]):
	"""Measure quantum state of multiple plots via quantum_computer (Model B)

	Collapses the quantum state of selected plots and reports outcomes.
	Uses the refactored measure_plot() which is fully Model B compatible.

	Enhanced: When measuring an entangled plot, shows outcomes for ALL
	registers in the entangled component (batch component measurement).
	"""
	if not farm or not farm.grid:
		action_performed.emit("measure", false, "Farm not loaded yet")
		return

	if positions.is_empty():
		action_performed.emit("measure", false, "No plots selected")
		return

	_verbose.info("farm", "📊", "Measuring %d plots (with component expansion)..." % positions.size())

	var success_count = 0
	var outcomes = {}
	var measured_components: Array[int] = []  # Track which components we've measured

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			continue

		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			# Fallback to regular measure
			var outcome_emoji = farm.grid.measure_plot(pos)
			if outcome_emoji and outcome_emoji != "":
				success_count += 1
				outcomes[outcome_emoji] = outcomes.get(outcome_emoji, 0) + 1
			continue

		var emoji = plot.north_emoji if plot.north_emoji else "🌾"
		var qc = biome.quantum_computer

		# Get register for this emoji
		if not qc.register_map.coordinates.has(emoji):
			continue

		var reg_id = qc.register_map.coordinates[emoji]
		var comp = qc.get_component_containing(reg_id)

		if not comp:
			# No component - measure normally
			var outcome_emoji = farm.grid.measure_plot(pos)
			if outcome_emoji and outcome_emoji != "":
				success_count += 1
				outcomes[outcome_emoji] = outcomes.get(outcome_emoji, 0) + 1
			continue

		# Check if we've already measured this component
		if comp.component_id in measured_components:
			continue

		measured_components.append(comp.component_id)

		# Measure ALL registers in the component (batch component measurement)
		_verbose.info("farm", "🔗", "Measuring entangled component %d with %d registers" % [comp.component_id, comp.register_ids.size()])

		for comp_reg_id in comp.register_ids:
			# Find the emoji for this register
			var reg_emoji = _get_emoji_for_register(qc, comp_reg_id)
			if reg_emoji == "":
				continue

			# Measure this register in the component
			var outcome = qc.measure_register(comp, comp_reg_id)
			if outcome != "":
				success_count += 1
				outcomes[outcome] = outcomes.get(outcome, 0) + 1
				_verbose.debug("farm", "📍", "Component %d: %s → %s" % [comp.component_id, reg_emoji, outcome])

	var summary = ""
	for emoji in outcomes.keys():
		summary += "%s×%d " % [emoji, outcomes[emoji]]

	var component_note = " (%d components)" % measured_components.size() if measured_components.size() > 0 else ""
	action_performed.emit("measure", success_count > 0,
		"%s Measured %d outcomes%s | %s" % ["✅" if success_count > 0 else "❌", success_count, component_note, summary])


func _get_emoji_for_register(qc, reg_id: int) -> String:
	"""Reverse lookup: find emoji for a register ID."""
	for emoji in qc.register_map.coordinates:
		if qc.register_map.coordinates[emoji] == reg_id:
			return emoji
	return ""


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


## V2 Tool 1 (PROBE) Actions - Quantum Tomography Paradigm

func _action_explore():
	"""EXPLORE: Probe the quantum soup to discover registers.

	Uses probability-weighted selection from the density matrix.
	Binds terminals to registers for ALL selected plots.
	Creates a bubble at each selected plot position.
	"""
	if not farm or not farm.plot_pool:
		action_performed.emit("explore", false, "⚠️  Farm not ready")
		return

	# Get selected plots (checkbox system) or fall back to current_selection
	var selected_plots: Array[Vector2i] = []
	if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
		selected_plots = plot_grid_display.get_selected_plots()
	if selected_plots.is_empty():
		selected_plots.append(current_selection)

	var success_count = 0
	var last_emoji = ""

	# EXPLORE for each selected plot
	for plot_pos in selected_plots:
		var biome = farm.grid.get_biome_for_plot(plot_pos)
		if not biome:
			continue

		# Execute EXPLORE via ProbeActions
		var result = ProbeActions.action_explore(farm.plot_pool, biome)

		if result.success:
			var terminal = result.terminal
			var emoji = result.emoji_pair.get("north", "?")
			last_emoji = emoji

			# Link terminal to grid position for bubble tap lookup
			terminal.grid_position = plot_pos

			# Emit signal for visualization (bubble spawn) at THIS plot position
			farm.plot_planted.emit(plot_pos, emoji)

			_verbose.info("action", "🔍", "EXPLORE: Bound terminal %s to register %d (%s) at %s" % [
				terminal.terminal_id, result.register_id, emoji, plot_pos
			])
			success_count += 1

	if success_count > 0:
		action_performed.emit("explore", true, "🔍 Discovered %d registers" % success_count)
	else:
		action_performed.emit("explore", false, "⚠️  No terminals available or all registers bound")


func _action_measure(positions: Array[Vector2i]):
	"""MEASURE: Collapse an explored register via Born rule.

	Finds the first bound-but-not-measured terminal in the selected biome
	and performs quantum measurement.
	"""
	if not farm or not farm.plot_pool:
		action_performed.emit("measure", false, "⚠️  Farm not ready")
		return

	# Get biome from SELECTED plots (not cursor) - fixes Issue #1
	var target_pos = positions[0] if not positions.is_empty() else current_selection
	var biome = farm.grid.get_biome_for_plot(target_pos)
	if not biome:
		action_performed.emit("measure", false, "⚠️  No biome at selected plot")
		return

	# Find first active terminal (bound but not measured) in this biome
	var terminal = _find_active_terminal_in_biome(biome)
	if not terminal:
		action_performed.emit("measure", false, "⚠️  No terminals to measure. EXPLORE first.")
		return

	# Execute MEASURE via ProbeActions
	var result = ProbeActions.action_measure(terminal, biome)

	if result.success:
		var outcome = result.outcome
		var prob = result.recorded_probability  # Fixed: was 'probability', should be 'recorded_probability'

		# Emit signal for visualization (bubble freeze/collapse) - use target_pos
		farm.plot_measured.emit(target_pos, outcome)

		action_performed.emit("measure", true, "👁️ Measured: %s (p=%.0f%%)" % [outcome, prob * 100])
		_verbose.info("action", "👁️", "MEASURE: Terminal %s collapsed to %s" % [
			terminal.terminal_id, outcome
		])
	else:
		var msg = result.get("message", "Measure failed")
		action_performed.emit("measure", false, "⚠️  %s" % msg)


func _action_pop(positions: Array[Vector2i]):
	"""POP: Harvest a measured terminal and free it for reuse.

	Finds the first measured terminal in the selected biome,
	adds the resource to economy, and unbinds the terminal.
	"""
	if not farm or not farm.plot_pool:
		action_performed.emit("pop", false, "⚠️  Farm not ready")
		return

	# Get biome from SELECTED plots (not cursor) - fixes Issue #1
	var target_pos = positions[0] if not positions.is_empty() else current_selection
	var biome = farm.grid.get_biome_for_plot(target_pos)
	if not biome:
		action_performed.emit("pop", false, "⚠️  No biome at selected plot")
		return

	# Find first measured terminal in this biome
	var terminal = _find_measured_terminal_in_biome(biome)
	if not terminal:
		action_performed.emit("pop", false, "⚠️  No measured terminals. MEASURE first.")
		return

	# Execute POP via ProbeActions
	var result = ProbeActions.action_pop(terminal, farm.plot_pool, farm.economy)

	if result.success:
		var resource = result.resource

		# Emit signal for visualization (bubble pop, particle effect) - use target_pos
		farm.plot_harvested.emit(target_pos, {"emoji": resource, "amount": 1})

		action_performed.emit("pop", true, "✂️ Harvested: %s" % resource)
		_verbose.info("action", "✂️", "POP: Harvested %s from terminal %s" % [
			resource, result.terminal_id
		])
	else:
		var msg = result.get("message", "Pop failed")
		action_performed.emit("pop", false, "⚠️  %s" % msg)


func _action_harvest_global():
	"""HARVEST: Global collapse of biome, end level.

	Ensemble Model: True projective measurement that collapses the
	entire quantum system and converts all probability to credits.
	This is the "end of turn" action.
	"""
	if not farm or not farm.plot_pool:
		action_performed.emit("harvest_global", false, "⚠️  Farm not ready")
		return

	# Get biome for current selection
	var biome = farm.grid.get_biome_for_plot(current_selection) if farm.grid else null
	if not biome:
		action_performed.emit("harvest_global", false, "⚠️  No biome at current selection")
		return

	# Execute HARVEST via ProbeActions
	var result = ProbeActions.action_harvest_global(biome, farm.plot_pool, farm.economy)

	if result.success:
		var total = result.total_credits
		var count = result.harvested.size()

		action_performed.emit("harvest_global", true, "🌾 HARVESTED: %.0f credits from %d registers!" % [total, count])
		_verbose.info("action", "🌾", "GLOBAL HARVEST: %.1f credits from %d registers" % [total, count])

		# Signal level complete
		if farm.has_signal("level_complete"):
			farm.level_complete.emit(result)
	else:
		var msg = result.get("message", "Harvest failed")
		action_performed.emit("harvest_global", false, "⚠️  %s" % msg)


func _find_active_terminal_in_biome(biome) -> RefCounted:
	"""Find the first bound-but-not-measured terminal in a biome.
	Uses object identity for reliable matching (Issue #5 fix).
	"""
	if not farm or not farm.plot_pool or not biome:
		return null

	for terminal in farm.plot_pool.get_active_terminals():
		if terminal.bound_biome == biome:  # Object identity comparison
			return terminal

	return null


func _find_measured_terminal_in_biome(biome) -> RefCounted:
	"""Find the first measured terminal in a biome.
	Uses object identity for reliable matching (Issue #5 fix).
	"""
	if not farm or not farm.plot_pool or not biome:
		return null

	for terminal in farm.plot_pool.get_measured_terminals():
		if terminal.bound_biome == biome:  # Object identity comparison
			return terminal

	return null


## Legacy Tool 1 (GROWER) Actions - Deprecated

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
	"""Build entanglement between terminals at selected positions.

	Creates multi-qubit cluster state topology via quantum_computer entanglement.
	Linear chain: plot[0]↔plot[1]↔plot[2]↔...
	Uses Terminal system to find bound registers, then entangles them.
	"""
	if not farm or not farm.grid or not farm.plot_pool:
		action_performed.emit("cluster", false, "⚠️  Farm not loaded yet")
		return

	if positions.size() < 2:
		action_performed.emit("cluster", false, "⚠️  Need at least 2 plots for cluster")
		return

	_verbose.info("quantum", "🌐", "Creating cluster state with %d plots..." % positions.size())

	# Get biome from first plot
	var biome = farm.grid.get_biome_for_plot(positions[0])
	if not biome or not biome.quantum_computer:
		action_performed.emit("cluster", false, "⚠️  Could not access biome quantum computer")
		return

	# Collect terminals at these positions
	var terminals: Array = []
	for pos in positions:
		var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
		if terminal and terminal.is_bound and not terminal.is_measured:
			terminals.append(terminal)
		else:
			_verbose.warn("quantum", "⚠️", "No active terminal at %s" % pos)

	if terminals.size() < 2:
		action_performed.emit("cluster", false, "⚠️  Need at least 2 active terminals. EXPLORE first.")
		return

	# Create entanglements between adjacent terminals
	var success_count = 0
	for i in range(terminals.size() - 1):
		var reg_a = terminals[i].bound_register_id
		var reg_b = terminals[i + 1].bound_register_id

		if biome.quantum_computer.entangle_plots(reg_a, reg_b):
			success_count += 1
			_verbose.info("quantum", "🔗", "Entangled register %d ↔ %d" % [reg_a, reg_b])

	var success = success_count > 0
	action_performed.emit("cluster", success,
		"%s Built cluster with %d entanglements (%d terminals)" % [
			"✅" if success else "❌", success_count, terminals.size()
		])


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


func _action_apply_pauli_y(positions: Array[Vector2i]):
	"""Apply Pauli-Y gate to selected plots - INSTANTANEOUS.

	Combines X and Z rotations: |0⟩ → i|1⟩, |1⟩ → -i|0⟩
	Proper unitary: ρ' = YρY† where Y = [[0,-i],[i,0]]
	Model B: Uses quantum_computer.apply_unitary_1q() with Y gate matrix.
	"""
	if positions.is_empty():
		action_performed.emit("apply_pauli_y", false, "⚠️  No plots selected")
		return

	var success_count = 0
	for pos in positions:
		if _apply_single_qubit_gate(pos, "Y"):
			success_count += 1
			_verbose.debug("quantum", "🔄", "Applied Pauli-Y at %s" % pos)

	action_performed.emit("apply_pauli_y", success_count > 0,
		"✅ Applied Pauli-Y to %d qubits" % success_count if success_count > 0 else "❌ No gates applied")


func _action_apply_s_gate(positions: Array[Vector2i]):
	"""Apply S gate (π/2 phase) to selected plots - INSTANTANEOUS.

	Applies phase shift: |0⟩ → |0⟩, |1⟩ → i|1⟩
	S = [[1, 0], [0, i]] (square root of Z gate, S² = Z)
	Model B: Uses quantum_computer.apply_unitary_1q() with S gate matrix.
	"""
	if positions.is_empty():
		action_performed.emit("apply_s_gate", false, "⚠️  No plots selected")
		return

	var success_count = 0
	for pos in positions:
		if _apply_single_qubit_gate(pos, "S"):
			success_count += 1
			_verbose.debug("quantum", "🌊", "Applied S-gate at %s" % pos)

	action_performed.emit("apply_s_gate", success_count > 0,
		"✅ Applied S-gate to %d qubits" % success_count if success_count > 0 else "❌ No gates applied")


func _action_apply_t_gate(positions: Array[Vector2i]):
	"""Apply T gate (π/4 phase) to selected plots - INSTANTANEOUS.

	Applies phase shift: |0⟩ → |0⟩, |1⟩ → e^(iπ/4)|1⟩
	T = [[1, 0], [0, e^(iπ/4)]] (square root of S gate, enables universal computation)
	Model B: Uses quantum_computer.apply_unitary_1q() with T gate matrix.
	"""
	if positions.is_empty():
		action_performed.emit("apply_t_gate", false, "⚠️  No plots selected")
		return

	var success_count = 0
	for pos in positions:
		if _apply_single_qubit_gate(pos, "T"):
			success_count += 1
			_verbose.debug("quantum", "✨", "Applied T-gate at %s" % pos)

	action_performed.emit("apply_t_gate", success_count > 0,
		"✅ Applied T-gate to %d qubits" % success_count if success_count > 0 else "❌ No gates applied")


func _action_apply_sdg_gate(positions: Array[Vector2i]):
	"""Apply S-dagger gate (-π/2 phase) to selected plots - INSTANTANEOUS.

	S† = [[1, 0], [0, -i]] (inverse of S gate)
	Applies phase shift: |0⟩ → |0⟩, |1⟩ → -i|1⟩
	"""
	if positions.is_empty():
		action_performed.emit("apply_sdg_gate", false, "⚠️  No plots selected")
		return

	var success_count = 0
	for pos in positions:
		if _apply_single_qubit_gate(pos, "Sdg"):
			success_count += 1
			_verbose.debug("quantum", "🌑", "Applied S†-gate at %s" % pos)

	action_performed.emit("apply_sdg_gate", success_count > 0,
		"✅ Applied S†-gate to %d qubits" % success_count if success_count > 0 else "❌ No gates applied")


func _action_apply_rx_gate(positions: Array[Vector2i]):
	"""Apply Rx rotation gate to selected plots.

	Rx(θ) = [[cos(θ/2), -i·sin(θ/2)], [-i·sin(θ/2), cos(θ/2)]]
	Default θ = π/4 for now (configurable later via parameter)
	"""
	if positions.is_empty():
		action_performed.emit("apply_rx_gate", false, "⚠️  No plots selected")
		return

	var success_count = 0
	for pos in positions:
		if _apply_single_qubit_gate(pos, "Rx"):
			success_count += 1
			_verbose.debug("quantum", "↔️", "Applied Rx-gate at %s" % pos)

	action_performed.emit("apply_rx_gate", success_count > 0,
		"✅ Applied Rx-gate to %d qubits" % success_count if success_count > 0 else "❌ No gates applied")


func _action_apply_ry_gate(positions: Array[Vector2i]):
	"""Apply Ry rotation gate to selected plots.

	Ry(θ) = [[cos(θ/2), -sin(θ/2)], [sin(θ/2), cos(θ/2)]]
	Default θ = π/4 for now (configurable later via parameter)
	"""
	if positions.is_empty():
		action_performed.emit("apply_ry_gate", false, "⚠️  No plots selected")
		return

	var success_count = 0
	for pos in positions:
		if _apply_single_qubit_gate(pos, "Ry"):
			success_count += 1
			_verbose.debug("quantum", "↕️", "Applied Ry-gate at %s" % pos)

	action_performed.emit("apply_ry_gate", success_count > 0,
		"✅ Applied Ry-gate to %d qubits" % success_count if success_count > 0 else "❌ No gates applied")


func _action_apply_rz_gate(positions: Array[Vector2i]):
	"""Apply Rz rotation gate to selected plots.

	Rz(θ) = [[e^(-iθ/2), 0], [0, e^(iθ/2)]]
	Default θ = π/4 for now (configurable later via parameter)
	"""
	if positions.is_empty():
		action_performed.emit("apply_rz_gate", false, "⚠️  No plots selected")
		return

	var success_count = 0
	for pos in positions:
		if _apply_single_qubit_gate(pos, "Rz"):
			success_count += 1
			_verbose.debug("quantum", "🔄", "Applied Rz-gate at %s" % pos)

	action_performed.emit("apply_rz_gate", success_count > 0,
		"✅ Applied Rz-gate to %d qubits" % success_count if success_count > 0 else "❌ No gates applied")


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
	if TOOL_ACTIONS.has(current_tool):
		var tool = TOOL_ACTIONS[current_tool]
		_verbose.info("input", "⚡", "  Current Tool: %s" % tool.get("name", "Unknown"))

		# Get actions for current tool (handle both simple and mode-based tools)
		var tool_actions = null
		if tool.has("actions"):
			tool_actions = tool["actions"]

		if tool_actions and tool_actions.has("Q"):
			_verbose.info("input", "⚡", "  Q = %s" % tool_actions["Q"].get("label", "Action"))
			_verbose.info("input", "⚡", "  E = %s" % tool_actions["E"].get("label", "Action"))
			_verbose.info("input", "⚡", "  R = %s" % tool_actions["R"].get("label", "Action"))
	else:
		_verbose.info("input", "⚡", "  (No tool currently selected)")

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


## ═══════════════════════════════════════════════════════════════════════════
## Lindblad Control Operations (Direct Quantum Computer Access)
## ═══════════════════════════════════════════════════════════════════════════

func _action_lindblad_drive(plots: Array[Vector2i]):
	"""Apply Lindblad drive to increase population on selected plots.

	Drive operation pumps population into the target state.
	Uses QuantumComputer.apply_drive(target_emoji, rate, dt).
	"""
	if not farm or not farm.grid:
		action_performed.emit("lindblad_drive", false, "Farm not loaded")
		return

	if plots.is_empty():
		action_performed.emit("lindblad_drive", false, "No plots selected")
		return

	_verbose.info("quantum", "📈", "Applying Lindblad drive to %d plots..." % plots.size())

	var success_count = 0
	var driven_emojis = {}
	var drive_rate = 0.1
	var dt = 0.1

	for pos in plots:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			continue

		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue

		var emoji = plot.north_emoji if plot.north_emoji else "🌾"
		biome.quantum_computer.apply_drive(emoji, drive_rate, dt)
		success_count += 1
		driven_emojis[emoji] = driven_emojis.get(emoji, 0) + 1
		_verbose.debug("quantum", "📈", "Drive applied to %s at %s" % [emoji, pos])

	var summary = ""
	for emoji in driven_emojis.keys():
		summary += "%s×%d " % [emoji, driven_emojis[emoji]]

	action_performed.emit("lindblad_drive", success_count > 0,
		"%s Drive on %d/%d plots | %s" % ["✅" if success_count > 0 else "❌", success_count, plots.size(), summary])


func _action_lindblad_decay(plots: Array[Vector2i]):
	"""Apply Lindblad decay to decrease population on selected plots.

	Decay operation removes population from the target state.
	Uses QuantumComputer.apply_decay(qubit_index, rate, dt).
	"""
	if not farm or not farm.grid:
		action_performed.emit("lindblad_decay", false, "Farm not loaded")
		return

	if plots.is_empty():
		action_performed.emit("lindblad_decay", false, "No plots selected")
		return

	_verbose.info("quantum", "📉", "Applying Lindblad decay to %d plots..." % plots.size())

	var success_count = 0
	var decayed_emojis = {}
	var decay_rate = 0.1
	var dt = 0.1

	for pos in plots:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			continue

		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue

		var emoji = plot.north_emoji if plot.north_emoji else "🌾"
		# Get qubit index for this emoji
		if biome.quantum_computer.register_map.coordinates.has(emoji):
			var qubit_idx = biome.quantum_computer.register_map.coordinates[emoji]
			biome.quantum_computer.apply_decay(qubit_idx, decay_rate, dt)
			success_count += 1
			decayed_emojis[emoji] = decayed_emojis.get(emoji, 0) + 1
			_verbose.debug("quantum", "📉", "Decay applied to %s at %s" % [emoji, pos])

	var summary = ""
	for emoji in decayed_emojis.keys():
		summary += "%s×%d " % [emoji, decayed_emojis[emoji]]

	action_performed.emit("lindblad_decay", success_count > 0,
		"%s Decay on %d/%d plots | %s" % ["✅" if success_count > 0 else "❌", success_count, plots.size(), summary])


func _action_lindblad_transfer(plots: Array[Vector2i]):
	"""Transfer population between two selected plots.

	Requires exactly 2 plots selected. Transfers population from first to second.
	Uses QuantumComputer.transfer_population(from_emoji, to_emoji, rate, dt).
	"""
	if not farm or not farm.grid:
		action_performed.emit("lindblad_transfer", false, "Farm not loaded")
		return

	if plots.size() != 2:
		action_performed.emit("lindblad_transfer", false, "Select exactly 2 plots")
		return

	var pos_from = plots[0]
	var pos_to = plots[1]

	var plot_from = farm.grid.get_plot(pos_from)
	var plot_to = farm.grid.get_plot(pos_to)

	if not plot_from or not plot_from.is_planted or not plot_to or not plot_to.is_planted:
		action_performed.emit("lindblad_transfer", false, "Both plots must be planted")
		return

	var biome = farm.grid.get_biome_for_plot(pos_from)
	if not biome or not biome.quantum_computer:
		action_performed.emit("lindblad_transfer", false, "No quantum computer")
		return

	var emoji_from = plot_from.north_emoji if plot_from.north_emoji else "🌾"
	var emoji_to = plot_to.north_emoji if plot_to.north_emoji else "🌾"

	_verbose.info("quantum", "↔️", "Transferring population %s → %s" % [emoji_from, emoji_to])

	var transfer_rate = 0.1
	var dt = 0.1
	biome.quantum_computer.transfer_population(emoji_from, emoji_to, transfer_rate, dt)

	action_performed.emit("lindblad_transfer", true,
		"✅ Transfer: %s → %s" % [emoji_from, emoji_to])


func _action_peek_state(plots: Array[Vector2i]):
	"""Non-destructive peek at quantum state probabilities.

	Shows measurement probabilities WITHOUT collapsing the state.
	This is simulator introspection - players can see exact probabilities.
	Uses QuantumComputer.inspect_register_distribution().
	"""
	if not farm or not farm.grid:
		action_performed.emit("peek_state", false, "Farm not loaded")
		return

	if plots.is_empty():
		action_performed.emit("peek_state", false, "No plots selected")
		return

	_verbose.info("quantum", "🔍", "Peeking at state for %d plots (no collapse)..." % plots.size())

	var peek_results: Array[String] = []

	for pos in plots:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			continue

		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue

		var emoji = plot.north_emoji if plot.north_emoji else "🌾"

		# Get component and register for this emoji
		if biome.quantum_computer.register_map.coordinates.has(emoji):
			var reg_id = biome.quantum_computer.register_map.coordinates[emoji]
			var comp = biome.quantum_computer._get_component_for_register(reg_id)
			if comp:
				var dist = biome.quantum_computer.inspect_register_distribution(comp, reg_id)
				var north_pct = dist.get("north", 0.5) * 100.0
				var south_pct = dist.get("south", 0.5) * 100.0
				peek_results.append("%s: ↑%.0f%% ↓%.0f%%" % [emoji, north_pct, south_pct])
				_verbose.debug("quantum", "🔍", "Peek %s: north=%.2f south=%.2f" % [emoji, dist.north, dist.south])

	if peek_results.is_empty():
		action_performed.emit("peek_state", false, "No quantum states found")
		return

	var summary = " | ".join(peek_results)
	action_performed.emit("peek_state", true,
		"🔍 Peek: %s" % summary)


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

	# Use ToolConfig API to properly resolve action name
	var action = ToolConfig.get_action_name(current_tool, action_key)

	# Route to specific validation based on action type
	match action:
		# ═══════════════════════════════════════════════════════════════
		# v2 PROBE Tool (Tool 1) - Core gameplay loop
		# ═══════════════════════════════════════════════════════════════
		"explore":
			return _can_execute_explore()
		"measure":
			return _can_execute_measure(selected_plots)  # Pass selected plots for Issue #4 fix
		"pop":
			return _can_execute_pop(selected_plots)  # Pass selected plots for Issue #4 fix

		# ═══════════════════════════════════════════════════════════════
		# v2 ENTANGLE Tool (Tool 2)
		# ═══════════════════════════════════════════════════════════════
		"cluster", "measure_trigger", "remove_gates":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# v2 INDUSTRY Tool (Tool 3)
		# ═══════════════════════════════════════════════════════════════
		"place_mill", "place_market", "place_kitchen":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# v2 UNITARY Tool (Tool 4)
		# ═══════════════════════════════════════════════════════════════
		"apply_pauli_x", "apply_hadamard", "apply_pauli_z":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 1 (BIOME)
		# ═══════════════════════════════════════════════════════════════
		"submenu_biome_assign":
			return true  # Opens submenu
		"clear_biome_assignment", "inspect_plot":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 2 (ICON)
		# ═══════════════════════════════════════════════════════════════
		"submenu_icon_assign":
			return true  # Opens submenu
		"icon_swap", "icon_clear":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 3 (LINDBLAD)
		# ═══════════════════════════════════════════════════════════════
		"lindblad_drive", "lindblad_decay", "lindblad_transfer":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 4 (QUANTUM) with F-cycling
		# System mode (F=0)
		# ═══════════════════════════════════════════════════════════════
		"system_reset", "system_snapshot", "system_debug":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 4 (QUANTUM) with F-cycling
		# Phase mode (F=1)
		# ═══════════════════════════════════════════════════════════════
		"apply_s_gate", "apply_t_gate", "apply_sdg_gate":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 4 (QUANTUM) with F-cycling
		# Rotation mode (F=2)
		# ═══════════════════════════════════════════════════════════════
		"apply_rx_gate", "apply_ry_gate", "apply_rz_gate":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# Legacy v1 actions (backward compatibility)
		# ═══════════════════════════════════════════════════════════════
		"plant_batch":
			return _can_plant_any(selected_plots)
		"entangle_batch":
			return _can_entangle(selected_plots)
		"measure_and_harvest":
			return _can_harvest_any(selected_plots)
		_:
			return false


func _can_execute_explore() -> bool:
	"""Check if EXPLORE action is available (v2 PROBE Tool 1)

	EXPLORE binds an unbound terminal to a register in the current biome.
	Available when: unbound terminals exist AND biome has unbound registers.
	"""
	if not farm or not farm.plot_pool:
		return false

	# Need unbound terminals
	if farm.plot_pool.get_unbound_count() == 0:
		return false

	# Get biome from current selection
	var biome = _get_current_biome()
	if not biome:
		return false

	# Must have unbound registers
	var probabilities = biome.get_register_probabilities()
	return not probabilities.is_empty()


func _can_execute_measure(selected_plots: Array[Vector2i] = []) -> bool:
	"""Check if MEASURE action is available (v2 PROBE Tool 1)

	MEASURE collapses an active terminal (bound but not measured).
	Available when: active terminal exists in selected biome.
	Uses selected_plots[0] to match execution behavior (Issue #4 fix).
	"""
	if not farm or not farm.plot_pool:
		return false

	# Use selected plots if available, otherwise fall back to current_selection
	var target_pos = selected_plots[0] if not selected_plots.is_empty() else current_selection
	var biome = farm.grid.get_biome_for_plot(target_pos) if farm.grid else null
	if not biome:
		return false

	# Must have active terminal (bound but not measured) in this biome
	for terminal in farm.plot_pool.get_active_terminals():
		if terminal.bound_biome == biome:  # Object identity instead of string comparison (Issue #5)
			return true
	return false


func _can_execute_pop(selected_plots: Array[Vector2i] = []) -> bool:
	"""Check if POP action is available (v2 PROBE Tool 1)

	POP harvests a measured terminal and unbinds it.
	Available when: measured terminal exists in selected biome.
	Uses selected_plots[0] to match execution behavior (Issue #4 fix).
	"""
	if not farm or not farm.plot_pool:
		return false

	# Use selected plots if available, otherwise fall back to current_selection
	var target_pos = selected_plots[0] if not selected_plots.is_empty() else current_selection
	var biome = farm.grid.get_biome_for_plot(target_pos) if farm.grid else null
	if not biome:
		return false

	# Must have measured terminal in this biome
	for terminal in farm.plot_pool.get_measured_terminals():
		if terminal.bound_biome == biome:  # Object identity instead of string comparison (Issue #5)
			return true
	return false


func _get_current_biome():
	"""Get biome for current selection (helper for availability checks)"""
	if not farm or not farm.grid:
		return null
	return farm.grid.get_biome_for_plot(current_selection)


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
	"""Check if we can plant this specific type on any selected plot

	PARAMETRIC (Phase 6): Queries biome capabilities instead of BUILD_CONFIGS.
	Follows same pattern as Farm.build() for cost determination.
	"""
	if not farm or plots.is_empty():
		return false

	# PARAMETRIC: Determine cost based on type
	var cost = {}
	var biome_required = ""

	# Check infrastructure buildings
	if Farm.INFRASTRUCTURE_COSTS.has(plant_type):
		cost = Farm.INFRASTRUCTURE_COSTS[plant_type]

	# Check gather actions
	elif Farm.GATHER_ACTIONS.has(plant_type):
		var gather_config = Farm.GATHER_ACTIONS[plant_type]
		cost = gather_config.get("cost", {})
		biome_required = gather_config.get("biome_required", "")

	# Otherwise, query biome capabilities for plant cost
	else:
		# Check first plot's biome for capability
		var first_pos = plots[0]
		var plot_biome = farm.grid.get_biome_for_plot(first_pos)
		if not plot_biome:
			return false

		# Find capability for this plant type
		var capability = null
		for cap in plot_biome.get_plantable_capabilities():
			if cap.plant_type == plant_type:
				capability = cap
				break

		if not capability:
			return false

		cost = capability.cost
		biome_required = plot_biome.name if capability.requires_biome else ""

	# Check if we can afford it
	if not farm.economy.can_afford_cost(cost):
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
		if biome_required != "":
			var plot_biome_name = farm.grid.plot_biome_assignments.get(pos, "")
			if plot_biome_name != biome_required:
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


# ═══════════════════════════════════════════════════════════════════════════
# v2 ARCHITECTURE: GLOBAL CONTROLS
# ═══════════════════════════════════════════════════════════════════════════

func _toggle_evolution_pause() -> void:
	"""Toggle quantum evolution pause state (Spacebar)

	When paused:
	- Quantum evolution stops (density matrix doesn't evolve)
	- Actions (EXPLORE, MEASURE, POP, gates) still work
	- Visual indicator shows paused state
	"""
	evolution_paused = not evolution_paused

	# Notify biomes to pause/resume evolution
	if farm and farm.grid and farm.grid.biomes:
		for biome_name in farm.grid.biomes:
			var biome = farm.grid.biomes[biome_name]
			if biome and biome.has_method("set_evolution_paused"):
				biome.set_evolution_paused(evolution_paused)

	var status = "PAUSED" if evolution_paused else "RUNNING"
	_verbose.info("input", "⏸️" if evolution_paused else "▶️",
		"Evolution %s (Spacebar to toggle)" % status)

	pause_toggled.emit(evolution_paused)
	action_performed.emit("toggle_pause", true, "Evolution %s" % status.to_lower())


func _toggle_build_play_mode() -> void:
	"""Toggle between BUILD and PLAY modes (Tab)

	PLAY mode (default):
	- Tool 1: PROBE (Explore/Measure/Pop)
	- Tool 2: GATES (with F-cycling)
	- Tool 3: ENTANGLE (with F-cycling)
	- Tool 4: INJECT

	BUILD mode:
	- Tool 1: BIOME (assign plots to biomes)
	- Tool 2: ICON (configure icons)
	- Tool 3: LINDBLAD (dissipation control)
	- Tool 4: SYSTEM (global config)
	"""
	var new_mode = ToolConfig.toggle_mode()

	# Reset to tool 1 when switching modes
	current_tool = 1
	current_submenu = ""
	_cached_submenu = {}

	# BUILD MODE PAUSE: Pause quantum evolution when entering BUILD mode
	# This allows safe modification of biome structure (adding qubits, etc.)
	var is_build_mode = (new_mode == "build")
	_set_all_biomes_paused(is_build_mode)

	_verbose.info("input", "🔧" if new_mode == "build" else "🎮",
		"Switched to %s MODE (Tab to toggle)" % new_mode.to_upper())

	mode_changed.emit(new_mode)

	# Emit tool_changed with new tool info
	var tool_info = ToolConfig.get_tool(current_tool)
	tool_changed.emit(current_tool, tool_info)

	action_performed.emit("toggle_mode", true, "%s mode" % new_mode.capitalize())


func _cycle_current_tool_mode() -> void:
	"""Cycle F-mode for current tool (F key)

	Only works for tools with F-cycling enabled:
	- Tool 2 (GATES): Basic → Phase → 2-Qubit
	- Tool 3 (ENTANGLE): Bell → Cluster → Manipulate
	"""
	if not ToolConfig.has_f_cycling(current_tool):
		_verbose.debug("input", "🔄", "Tool %d doesn't support F-cycling" % current_tool)
		action_performed.emit("cycle_mode", false, "This tool doesn't have modes")
		return

	var new_index = ToolConfig.cycle_tool_mode(current_tool)
	if new_index < 0:
		return

	var mode_label = ToolConfig.get_tool_mode_label(current_tool)
	var tool_name = ToolConfig.get_tool_name(current_tool)

	_verbose.info("input", "🔄",
		"%s mode: %s (F to cycle)" % [tool_name, mode_label])

	tool_mode_cycled.emit(current_tool, new_index, mode_label)

	# Update action preview by re-emitting tool_changed
	var tool_info = ToolConfig.get_tool(current_tool)
	tool_changed.emit(current_tool, tool_info)

	action_performed.emit("cycle_mode", true, "%s: %s" % [tool_name, mode_label])


func is_evolution_paused() -> bool:
	"""Get current pause state"""
	return evolution_paused


func get_current_game_mode() -> String:
	"""Get current game mode (play or build)"""
	return ToolConfig.get_mode()


func _set_all_biomes_paused(paused: bool) -> void:
	"""Pause or resume quantum evolution on all biomes.

	Called when switching between PLAY and BUILD modes.
	BUILD mode pauses evolution to allow safe biome modification.
	"""
	if not farm or not farm.grid or not farm.grid.biomes:
		return

	for biome_name in farm.grid.biomes:
		var biome = farm.grid.biomes[biome_name]
		if biome and biome.has_method("set_evolution_paused"):
			biome.set_evolution_paused(paused)


# ═══════════════════════════════════════════════════════════════════════════════
# BUILD MODE: Tool 2 (Icon) - Icon Management Actions
# ═══════════════════════════════════════════════════════════════════════════════

func _action_icon_swap(plots: Array[Vector2i]):
	"""Swap north/south emojis on selected plot(s).

	Exchanges the north_emoji and south_emoji for each selected plot.
	This changes which outcome is considered "success" vs "failure".
	"""
	if not farm or not farm.grid:
		action_performed.emit("icon_swap", false, "Farm not loaded")
		return

	if plots.is_empty():
		action_performed.emit("icon_swap", false, "No plots selected")
		return

	var swap_count := 0

	for pos in plots:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			continue

		# Swap north and south emojis
		var temp = plot.north_emoji
		plot.north_emoji = plot.south_emoji
		plot.south_emoji = temp
		swap_count += 1

		_verbose.debug("icon", "🔃", "Swapped %s ↔ %s at %s" % [plot.south_emoji, plot.north_emoji, pos])

	if swap_count > 0:
		action_performed.emit("icon_swap", true, "🔃 Swapped icons on %d plots" % swap_count)
	else:
		action_performed.emit("icon_swap", false, "No planted plots to swap")


func _action_icon_clear(plots: Array[Vector2i]):
	"""Clear icon assignment from selected plot(s).

	Resets plots to their default biome icons (unassigned state).
	"""
	if not farm or not farm.grid:
		action_performed.emit("icon_clear", false, "Farm not loaded")
		return

	if plots.is_empty():
		action_performed.emit("icon_clear", false, "No plots selected")
		return

	var clear_count := 0

	for pos in plots:
		var plot = farm.grid.get_plot(pos)
		if not plot:
			continue

		# Get default icons from biome
		var biome = farm.grid.get_biome_for_plot(pos)
		if biome and biome.producible_emojis.size() >= 2:
			plot.north_emoji = biome.producible_emojis[0]
			plot.south_emoji = biome.producible_emojis[1]
		else:
			plot.north_emoji = ""
			plot.south_emoji = ""

		clear_count += 1
		_verbose.debug("icon", "⬜", "Cleared icons at %s" % pos)

	action_performed.emit("icon_clear", true, "⬜ Cleared icons on %d plots" % clear_count)


# ═══════════════════════════════════════════════════════════════════════════════
# BUILD MODE: Tool 4 (System) - System Control Actions
# ═══════════════════════════════════════════════════════════════════════════════

func _action_system_reset(plots: Array[Vector2i]):
	"""Reset quantum bath to initial/thermal state.

	Reinitializes the density matrix for the biome containing selected plots.
	This is a "hard reset" - all quantum coherence is lost.
	"""
	if not farm or not farm.grid:
		action_performed.emit("system_reset", false, "Farm not loaded")
		return

	# Get the biome for the first selected plot (or current selection)
	var target_pos = plots[0] if not plots.is_empty() else current_selection
	var biome = farm.grid.get_biome_for_plot(target_pos)

	if not biome or not biome.quantum_computer:
		action_performed.emit("system_reset", false, "No quantum computer at selection")
		return

	var biome_name = biome.get_biome_type()

	# Reset to initial basis state |0...0⟩
	biome.quantum_computer.initialize_basis(0)

	_verbose.info("system", "🔄", "Reset %s quantum bath to |0⟩" % biome_name)
	action_performed.emit("system_reset", true, "🔄 Reset %s to ground state" % biome_name)


func _action_system_snapshot(plots: Array[Vector2i]):
	"""Save current quantum state snapshot.

	Captures the current density matrix state for later comparison or rollback.
	Snapshots are stored in GameStateManager.
	"""
	if not farm or not farm.grid:
		action_performed.emit("system_snapshot", false, "Farm not loaded")
		return

	# Get the biome for the first selected plot
	var target_pos = plots[0] if not plots.is_empty() else current_selection
	var biome = farm.grid.get_biome_for_plot(target_pos)

	if not biome or not biome.quantum_computer:
		action_performed.emit("system_snapshot", false, "No quantum computer at selection")
		return

	var biome_name = biome.get_biome_type()

	# Get density matrix and create snapshot
	var rho = biome.quantum_computer.get_density_matrix()
	if not rho:
		action_performed.emit("system_snapshot", false, "No density matrix to snapshot")
		return

	# Store snapshot in GameStateManager (if available)
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm:
		if not gsm.has("quantum_snapshots"):
			gsm.quantum_snapshots = []

		var snapshot = {
			"biome": biome_name,
			"timestamp": Time.get_unix_time_from_system(),
			"dimension": rho.n,
			"trace": rho.trace().re if rho.has_method("trace") else 1.0
		}
		gsm.quantum_snapshots.append(snapshot)

		_verbose.info("system", "📸", "Snapshot saved for %s (dim=%d)" % [biome_name, rho.n])
		action_performed.emit("system_snapshot", true, "📸 Snapshot saved for %s" % biome_name)
	else:
		# Fallback: just log it
		_verbose.info("system", "📸", "Snapshot (no GSM): %s dim=%d" % [biome_name, rho.n])
		action_performed.emit("system_snapshot", true, "📸 Snapshot logged for %s" % biome_name)


func _action_system_debug(plots: Array[Vector2i]):
	"""Toggle debug visualization mode.

	Enables/disables verbose quantum state logging and debug overlays.
	"""
	# Toggle verbose debug mode
	var new_state := false

	if _verbose:
		# Toggle between info and debug levels
		var current_level = _verbose.get_level() if _verbose.has_method("get_level") else 1
		if current_level >= 2:  # Already debug
			_verbose.set_level(1)  # Back to info
			new_state = false
		else:
			_verbose.set_level(2)  # Enable debug
			new_state = true

		_verbose.info("system", "🐛", "Debug mode: %s" % ("ON" if new_state else "OFF"))

	# Also toggle any debug overlays
	var overlay_manager = _get_overlay_manager()
	if overlay_manager and overlay_manager.has_method("toggle_debug_mode"):
		overlay_manager.toggle_debug_mode()

	action_performed.emit("system_debug", true,
		"🐛 Debug mode: %s" % ("ON" if new_state else "OFF"))

