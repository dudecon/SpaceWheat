class_name QuantumInstrumentInput
extends Node

## QuantumInstrumentInput - Musical instrument spindle for quantum navigation
##
## A unified interface where plot selection, biome navigation, and quantum
## operations fuse into a single system. Creates a fractal address to game
## state through hierarchical navigation.
##
## Key Layout:
##   1 2 3 [4]    = Tool groups (time scale ratchet)
##
##   U I O P      = Biome selection (4 biomes)
##   J K L ;      = Homerow plot selection (4 plots in current biome - PRIMARY INTERFACE)
##   M , . /      = Reserved for future subspace navigation
##
##   Q = DOWN action (dig into, bind, construct)
##   E = NEUTRAL action (observe, balance, transfer)
##   R = UP action (extract, harvest, remove)
##   F = Mode cycling within tool group
##
##   - = Decrease matrix granularity (finer substeps, more accurate)
##   = = Increase matrix granularity (coarser substeps, faster)

# Preloads
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const GateActionHandler = preload("res://UI/Handlers/GateActionHandler.gd")
const LindbladHandler = preload("res://UI/Handlers/LindbladHandler.gd")
const ProbeHandler = preload("res://UI/Handlers/ProbeHandler.gd")
const ActionValidator = preload("res://UI/Core/ActionValidator.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const GranularityController = preload("res://Core/Utils/GranularityController.gd")
const GateSelectionSubmenu = preload("res://UI/Core/Submenus/GateSelectionSubmenu.gd")

# Access autoloads safely
@onready var _verbose = get_node("/root/VerboseConfig")
@onready var _observation_frame = get_node("/root/ObservationFrame")
@onready var _chain_tracker = get_node("/root/ActionChainTracker")
@onready var _active_biome_mgr = get_node("/root/ActiveBiomeManager")

# Row mappings: key -> slot index (T,Y,U,I,O,P)
const BIOME_ROW = {"T": 0, "Y": 1, "U": 2, "I": 3, "O": 4, "P": 5}  # Biome selection (6 slots)
const HOMEROW = {"J": 0, "K": 1, "L": 2, ";": 3, "'": 4, "H": 5, "G": 6}        # Plot selection (dynamic)
const SUBSPACE_ROW = {"M": 0, ",": 1, ".": 2, "/": 3}   # Reserved for future subspace navigation

# Input action mappings for the rows (order must match BIOME_ROW: T,Y,U,I,O,P)
const BIOME_ACTIONS = ["biome_0", "biome_1", "biome_2", "biome_3", "biome_4", "biome_5"]
const HOMEROW_ACTIONS = ["plot_0", "plot_1", "plot_2", "plot_3", "plot_4", "plot_5", "plot_6"]
const SUBSPACE_ACTIONS = ["subspace_0", "subspace_1", "subspace_2", "subspace_3"]

# Core state
var farm  # Farm instance
var plot_grid_display  # PlotGridDisplay reference for visual selection
var current_selection: Dictionary = {"plot_idx": -1, "biome": "", "subspace_idx": -1}
var last_selected_plot_position: Vector2i = Vector2i(-1, -1)  # Most recently selected plot for neighbor bonus

# Multi-select state (NEW - for batch operations with Shift modifier)
var checked_plots: Array[Vector2i] = []  # Set of checked grid positions (persists across biome switches)

# Submenu state
var _current_submenu: Dictionary = {}  # Current submenu data
var _in_submenu: bool = false  # Are we in a submenu?
var _submenu_page: int = 0  # Current page for paginated submenus

# Signals
signal action_performed(action: String, result: Dictionary)
signal selection_changed(plot_idx: int, biome: String)
signal biome_switched(old_biome: String, new_biome: String)
signal tool_group_changed(group: int)
signal mode_cycled(group: int, mode_index: int, mode_label: String)
signal submenu_changed(submenu_name: String, submenu_actions: Dictionary)
signal plot_checked(grid_pos: Vector2i, is_checked: bool)  # Multi-select checkbox toggled


func _ready() -> void:
	add_to_group("quantum_instrument_input")
	set_process_unhandled_key_input(true)

	# Ensure extra plot action exists for 5th column (apostrophe)
	if not InputMap.has_action("plot_4"):
		InputMap.add_action("plot_4")
		var ev = InputEventKey.new()
		ev.keycode = KEY_APOSTROPHE
		InputMap.action_add_event("plot_4", ev)

	if not InputMap.has_action("plot_5"):
		InputMap.add_action("plot_5")
		var ev_h = InputEventKey.new()
		ev_h.keycode = KEY_H
		InputMap.action_add_event("plot_5", ev_h)

	if not InputMap.has_action("plot_6"):
		InputMap.add_action("plot_6")
		var ev_g = InputEventKey.new()
		ev_g.keycode = KEY_G
		InputMap.action_add_event("plot_6", ev_g)

	_verbose.info("input", "~", "QuantumInstrumentInput initialized (Homerow + Biome Selection)")


## ============================================================================
## INJECTION
## ============================================================================

func inject_farm(farm_ref) -> void:
	"""Inject farm reference for action execution."""
	farm = farm_ref
	_verbose.info("input", "~", "Farm injected into QuantumInstrumentInput")


func inject_plot_grid_display(pgd_ref) -> void:
	"""Inject PlotGridDisplay reference for visual selection updates."""
	plot_grid_display = pgd_ref
	_verbose.info("input", "~", "PlotGridDisplay injected into QuantumInstrumentInput")


## ============================================================================
## INPUT HANDLING
## ============================================================================

func _unhandled_key_input(event: InputEvent) -> void:
	"""Handle keyboard input for the quantum instrument."""
	if not event is InputEventKey or not event.pressed:
		return
	if event.echo:
		return

	var key = _keycode_to_string(event.keycode)

	# Tool group selection: 1, 2, 3, 4
	if key in ["1", "2", "3", "4"]:
		_select_tool_group(int(key))
		get_viewport().set_input_as_handled()
		return

	# Biome selection: UIOP
	if key in BIOME_ROW:
		_select_biome(BIOME_ROW[key], key)
		get_viewport().set_input_as_handled()
		return

	# Plot selection: JKL; (homerow - primary interface)
	if key in HOMEROW:
		_select_plot(HOMEROW[key], key)
		get_viewport().set_input_as_handled()
		return

	# Subspace selection: M,./ (reserved for future)
	if key in SUBSPACE_ROW:
		_select_subspace(SUBSPACE_ROW[key], key)
		get_viewport().set_input_as_handled()
		return

	# Speed controls: - (decrease), = (increase)
	if key == "-":
		_decrease_simulation_speed()
		get_viewport().set_input_as_handled()
		return
	if key == "=":
		_increase_simulation_speed()
		get_viewport().set_input_as_handled()
		return

	# Action keys
	match key:
		"Q", "E", "R":
			if _in_submenu:
				_handle_submenu_action(key)
			else:
				if event.is_shift_pressed():
					_perform_shift_key_action(key)
				else:
					_perform_action(key)
			get_viewport().set_input_as_handled()
		"F":
			if _in_submenu:
				_cycle_submenu_page()
			else:
				_cycle_mode()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	"""Handle input actions for biome and plot selection."""
	# Check BIOME row actions (UIOP)
	for i in range(BIOME_ACTIONS.size()):
		if event.is_action_pressed(BIOME_ACTIONS[i]):
			var key_label = BIOME_ACTIONS[i]
			if _active_biome_mgr:
				var slot_key = _active_biome_mgr.get_slot_key(i)
				if slot_key != "":
					key_label = slot_key
			_select_biome(i, key_label)
			get_viewport().set_input_as_handled()
			return

	# Check HOMEROW actions (JKL;)
	for i in range(HOMEROW_ACTIONS.size()):
		if event.is_action_pressed(HOMEROW_ACTIONS[i]):
			_select_plot(i, HOMEROW_ACTIONS[i])
			get_viewport().set_input_as_handled()
			return

	# Check SUBSPACE row actions (M,./) - reserved for future
	for i in range(SUBSPACE_ACTIONS.size()):
		if event.is_action_pressed(SUBSPACE_ACTIONS[i]):
			_select_subspace(i, SUBSPACE_ACTIONS[i])
			get_viewport().set_input_as_handled()
			return


## ============================================================================
## TOOL GROUP MANAGEMENT
## ============================================================================

func _select_tool_group(group_num: int) -> void:
	"""Select a tool group (1-4)."""
	ToolConfig.select_group(group_num)
	tool_group_changed.emit(group_num)

	var group_name = ToolConfig.get_group_name(group_num)
	var mode_label = ToolConfig.get_group_mode_label(group_num)
	var display = group_name
	if mode_label != "":
		display = "%s [%s]" % [group_name, mode_label]
	_verbose.info("input", "~", "Tool: %s" % display)


func _cycle_mode() -> void:
	"""Cycle F-mode for current tool group."""
	var current_group = ToolConfig.get_current_group()
	if not ToolConfig.has_f_cycling(current_group):
		_verbose.debug("input", "~", "No F-cycling for group %d" % current_group)
		return

	var new_index = ToolConfig.cycle_group_mode(current_group)
	var mode_label = ToolConfig.get_group_mode_label(current_group)
	var mode_emoji = ToolConfig.get_group_mode_emoji(current_group)

	mode_cycled.emit(current_group, new_index, mode_label)
	_verbose.info("input", "~", "Mode: %s (%s)" % [mode_label, mode_emoji])


## ============================================================================
## SUBMENU HANDLING
## ============================================================================

func _open_submenu_for_action(action_info: Dictionary) -> void:
	"""Open a submenu for an action.

	Args:
		action_info: Action info dictionary from ToolConfig containing "submenu" field
	"""
	var submenu_name = action_info.get("submenu", "")
	if submenu_name.is_empty():
		_verbose.warn("input", "📋", "Action has submenu field but name is empty")
		return

	# For vocab_injection, generate dynamic submenu
	if submenu_name == "vocab_injection":
		_current_submenu = _generate_vocab_injection_submenu()
		_in_submenu = true
		_submenu_page = 0
		_verbose.info("input", "📋", "Opened vocab injection submenu")
		var submenu_actions = _current_submenu.get("actions", {})
		submenu_changed.emit(submenu_name, submenu_actions)

		# Debug: Print submenu contents
		if not _current_submenu.is_empty():
			var actions = _current_submenu.get("actions", {})
			_verbose.info("input", "📋", "Submenu has %d actions (Q/E/R)" % actions.size())
			for key in ["Q", "E", "R"]:
				if actions.has(key):
					var action = actions[key]
					var label = action.get("label", "")
					var affinity = action.get("affinity", 0.0)
					_verbose.info("input", "📋", "  %s: %s (affinity: %.2f)" % [key, label, affinity])
		else:
			_verbose.warn("input", "📋", "Submenu is empty!")

	# For gate_selection, generate dynamic submenu with selection context
	elif submenu_name == "gate_selection":
		_current_submenu = _generate_gate_selection_submenu()
		_in_submenu = true
		_submenu_page = 0
		var selection_count = checked_plots.size()
		_verbose.info("input", "⚛️", "Opened gate selection submenu (%d qubits selected)" % selection_count)
		var submenu_actions = _current_submenu.get("actions", {})
		submenu_changed.emit(submenu_name, submenu_actions)

		# Debug: Print gate options
		if not _current_submenu.is_empty():
			var actions = _current_submenu.get("actions", {})
			for key in ["Q", "E", "R"]:
				if actions.has(key):
					var action = actions[key]
					var label = action.get("label", "")
					var gate_type = action.get("gate_type", "")
					_verbose.debug("input", "⚛️", "  %s: %s (%s)" % [key, label, gate_type])


func _generate_vocab_injection_submenu() -> Dictionary:
	"""Generate the vocab injection submenu dynamically."""
	var VocabInjectionSubmenu = preload("res://UI/Core/Submenus/VocabInjectionSubmenu.gd")
	if not farm:
		_verbose.warn("input", "📋", "Farm not available")
		return {}

	var biome = _get_current_biome()
	if not biome:
		_verbose.warn("input", "📋", "No current biome")
		return {}

	return VocabInjectionSubmenu.generate_submenu(biome, farm, _submenu_page)


func _generate_gate_selection_submenu() -> Dictionary:
	"""Generate the gate selection submenu dynamically based on checked_plots."""
	if not farm:
		_verbose.warn("input", "⚛️", "Farm not available")
		return {}

	var biome = _get_current_biome()
	if not biome:
		_verbose.warn("input", "⚛️", "No current biome")
		return {}

	# Pass checked_plots as selection (preserves order)
	var selection: Array = []
	for pos in checked_plots:
		selection.append(pos)

	return GateSelectionSubmenu.generate_submenu(biome, farm, selection, _submenu_page)


func _cycle_submenu_page() -> void:
	"""Cycle to next page in paginated submenu (F key)."""
	if _current_submenu.is_empty():
		return

	var max_pages = _current_submenu.get("max_pages", 1)
	if max_pages <= 1:
		_verbose.debug("input", "📋", "Only 1 page in submenu")
		return

	_submenu_page = (_submenu_page + 1) % max_pages
	var submenu_name = _current_submenu.get("name", "")

	# Regenerate based on submenu type
	if submenu_name == "vocab_injection":
		_current_submenu = _generate_vocab_injection_submenu()
	elif submenu_name == "gate_selection":
		_current_submenu = _generate_gate_selection_submenu()
	else:
		_verbose.warn("input", "📋", "Unknown submenu type for pagination: %s" % submenu_name)
		return

	var current_page = _current_submenu.get("page", 0)
	var total_pages = _current_submenu.get("max_pages", 1)

	_verbose.info("input", "📋", "Submenu page %d/%d" % [current_page + 1, total_pages])
	submenu_changed.emit(submenu_name, _current_submenu.get("actions", {}))


func _handle_submenu_action(action_key: String) -> void:
	"""Handle Q/E/R actions while in a submenu.

	Args:
		action_key: "Q", "E", or "R"
	"""
	if _current_submenu.is_empty():
		_verbose.warn("input", "📋", "No submenu active")
		return

	var actions = _current_submenu.get("actions", {})
	var action_data = actions.get(action_key, {})

	if action_data.is_empty():
		_verbose.info("input", "📋", "You pressed %s - no option in that slot" % action_key)
		_verbose.info("input", "📋", "Available options: Q=%s E=%s R=%s" % [
			"✓" if actions.has("Q") else "✗",
			"✓" if actions.has("E") else "✗",
			"✓" if actions.has("R") else "✗"
		])
		return  # Stay in submenu

	# Check if option is disabled
	if not action_data.get("enabled", true):
		_verbose.info("input", "📋", "Option disabled: %s" % action_data.get("label", ""))
		return  # Stay in submenu

	var action = action_data.get("action", "")

	# Handle vocab_injection submenu actions
	if action == "inject_vocabulary":
		var vocab_pair = action_data.get("vocab_pair", {})
		var label = action_data.get("label", "")
		if not vocab_pair.is_empty():
			_verbose.info("input", "📋", "You selected: %s - injecting..." % label)
			_execute_inject_vocabulary(vocab_pair)

	# Handle gate_selection submenu actions
	elif action == "build_gate":
		var gate_type = action_data.get("gate_type", "bell")
		var label = action_data.get("label", gate_type)
		var qubits_required = action_data.get("qubits_required", 2)
		_verbose.info("input", "⚛️", "Building %s gate (requires %d qubits)" % [label, qubits_required])
		_execute_build_gate(gate_type)

	# Exit submenu
	_in_submenu = false
	_current_submenu = {}
	submenu_changed.emit("", {})


func _execute_inject_vocabulary(vocab_pair: Dictionary) -> void:
	"""Execute vocabulary injection with user-selected pair.

	Args:
		vocab_pair: {north: String, south: String}
	"""
	var cost: Dictionary = {}
	var biome = _get_current_biome()
	if not biome:
		_verbose.warn("input", "+", "No biome for vocab injection")
		return
	if not biome.viz_cache or not biome.viz_cache.has_metadata():
		_verbose.warn("input", "+", "Biome visualization data not ready")
		return
	var qubit_count = biome.get_total_register_count() if biome.has_method("get_total_register_count") else 0
	if qubit_count >= EconomyConstants.MAX_BIOME_QUBITS:
		_verbose.warn("input", "+", "Biome at max capacity (%d qubits)" % EconomyConstants.MAX_BIOME_QUBITS)
		return

	# Check if pair is already in biome
	if _biome_has_emoji(biome, vocab_pair.get("north", "")):
		_verbose.warn("input", "+", "%s already in biome" % vocab_pair.get("north", ""))
		return
	if _biome_has_emoji(biome, vocab_pair.get("south", "")):
		_verbose.warn("input", "+", "%s already in biome" % vocab_pair.get("south", ""))
		return

	# 5. Check and deduct cost BEFORE expanding
	var context = {"south_emoji": vocab_pair.get("south", "")}
	cost = EconomyConstants.get_action_cost("inject_vocabulary", context)
	if not farm or not farm.economy or not EconomyConstants.try_action("inject_vocabulary", farm.economy, context):
		_verbose.warn("input", "+", "Insufficient funds for vocab injection (need %s)" % [cost])
		return

	# 6. Perform expansion
	var result = biome.expand_quantum_system(vocab_pair.get("north", ""), vocab_pair.get("south", ""))

	if result.get("success", false):
		# Update game state vocabulary
		if farm and farm.has_method("discover_pair"):
			farm.discover_pair(vocab_pair.get("north", ""), vocab_pair.get("south", ""))

		_verbose.info("input", "+", "Injected vocab %s/%s into %s" % [vocab_pair.get("north", ""), vocab_pair.get("south", ""), biome.name])
		action_performed.emit("inject_vocabulary", {
			"success": true,
			"north_emoji": vocab_pair.get("north", ""),
			"south_emoji": vocab_pair.get("south", ""),
			"cost": cost,
			"biome": biome.name
		})
	else:
		_verbose.warn("input", "+", "Vocab injection failed: %s" % result.get("error", "unknown"))
		action_performed.emit("inject_vocabulary", result)


func _execute_build_gate(gate_type: String) -> void:
	"""Execute gate building with the specified gate type.

	Args:
		gate_type: Type of gate to build (bell, cnot, cz, swap, ghz, cluster)
	"""
	# Use checked_plots as selection (order preserved)
	var positions: Array[Vector2i] = []
	for pos in checked_plots:
		positions.append(pos)

	if positions.size() < 2:
		_verbose.warn("input", "⚛️", "Need 2+ qubits selected for %s gate" % gate_type)
		action_performed.emit("build_gate", {"success": false, "error": "need_more_qubits"})
		return

	var result: Dictionary = {}

	match gate_type:
		"bell":
			# Bell pair (|00⟩+|11⟩)/√2 - uses first 2 positions
			result = GateActionHandler.create_bell_pair(farm, positions.slice(0, 2))

		"cnot":
			# CNOT gate - first position is control, second is target
			result = GateActionHandler.apply_cnot(farm, positions.slice(0, 2))

		"cz":
			# Controlled-Z - phase flip if both qubits are |1⟩
			result = GateActionHandler.apply_cz(farm, positions.slice(0, 2))

		"swap":
			# SWAP gate - exchange qubit states
			result = GateActionHandler.apply_swap(farm, positions.slice(0, 2))

		"ghz":
			# GHZ state - (|000...⟩+|111...⟩)/√2 for all selected qubits
			result = GateActionHandler.create_ghz_state(farm, positions)

		"cluster":
			# Linear cluster state
			result = GateActionHandler.cluster(farm, positions)

		_:
			_verbose.warn("input", "⚛️", "Unknown gate type: %s" % gate_type)
			result = {"success": false, "error": "unknown_gate_type", "gate_type": gate_type}

	if result.get("success", false):
		_verbose.info("input", "⚛️", "Built %s gate on %d qubits" % [gate_type, positions.size()])
		# Clear selections after successful gate build
		clear_all_checks()
	else:
		_verbose.warn("input", "⚛️", "Failed to build %s: %s" % [gate_type, result.get("error", "unknown")])

	action_performed.emit("build_gate", result)


## ============================================================================
## BIOME SELECTION (UIOP Row)
## ============================================================================

func _select_biome(biome_idx: int, key: String) -> void:
	"""Select a biome from the TYUIOP row.

	Args:
		biome_idx: Which biome (0-5) was selected (T=0, Y=1, U=2, I=3, O=4, P=5)
		key: The key that was pressed (for logging)
	"""
	if not _active_biome_mgr:
		_verbose.warn("input", "~", "ActiveBiomeManager not available")
		return

	var new_biome = _active_biome_mgr.get_biome_for_slot(biome_idx)
	if new_biome == "":
		_verbose.info("input", "•", "Biome slot %s unassigned" % key)
		return

	var old_biome = _active_biome_mgr.get_active_biome()

	# Switch active biome
	_active_biome_mgr.set_active_biome(new_biome)

	# Update current selection to reflect new biome
	current_selection.biome = new_biome

	# Record in chain tracker
	if _chain_tracker:
		_chain_tracker.record_observation(key, -1, new_biome, 0)

	# Emit signal
	biome_switched.emit(old_biome, new_biome)
	_verbose.info("input", "~", "Biome: %s → %s" % [old_biome, new_biome])


## ============================================================================
## PLOT SELECTION (JKL; Homerow)
## ============================================================================

func _select_plot(plot_idx: int, key: String) -> void:
	"""Select a plot in the current biome.

	Args:
		plot_idx: Which plot index was selected (0..N-1)
		key: The key that was pressed (for chain tracking)
	"""
	if not _active_biome_mgr:
		_verbose.warn("input", "~", "ActiveBiomeManager not available")
		return

	# Guard against out-of-range plot indices
	if farm and farm.grid_config and plot_idx >= farm.grid_config.grid_width:
		_verbose.debug("input", "•", "Plot %d outside grid width %d" % [plot_idx, farm.grid_config.grid_width])
		return
	var register_count = _get_active_biome_register_count()
	if register_count > 0 and plot_idx >= register_count:
		_verbose.debug("input", "•", "Plot %d exceeds registers (%d)" % [plot_idx, register_count])
		return

	# Get current active biome
	var biome_name = _active_biome_mgr.get_active_biome()

	# Record the observation in the chain tracker
	if _chain_tracker:
		_chain_tracker.record_observation(key, plot_idx, biome_name, 0)

	# Update current selection
	current_selection = {
		"plot_idx": plot_idx,
		"biome": biome_name,
		"subspace_idx": -1
	}

	# Get grid position for visual updates and multi-select
	var grid_pos = _get_grid_position()

	_verbose.debug("input", "📍", "SELECTION DEBUG: plot_idx=%d, biome=%s → grid_pos=%s" % [plot_idx, biome_name, grid_pos])

	# CRITICAL: Update PlotGridDisplay visual selection
	if plot_grid_display and farm and grid_pos.x >= 0:
		plot_grid_display.set_selected_plot(grid_pos)
		last_selected_plot_position = grid_pos  # Track for neighbor bonus
		_verbose.debug("input", "~", "Visual selection: %s" % grid_pos)

	# Emit selection changed signal
	selection_changed.emit(plot_idx, biome_name)
	_verbose.debug("input", "~", "Plot %d in %s" % [plot_idx, biome_name])

	# NEW: Toggle checkmark on selection (multi-select support)
	if grid_pos.x >= 0:
		toggle_check(grid_pos)


## ============================================================================
## MULTI-SELECT SYSTEM (Checkboxes)
## ============================================================================

func toggle_check(grid_pos: Vector2i) -> void:
	"""Toggle checkmark for multi-select at given grid position.

	Args:
		grid_pos: Grid position to toggle (Vector2i(plot_idx, biome_row))
	"""
	if grid_pos.x < 0 or grid_pos.y < 0:
		return  # Invalid position

	var was_checked = grid_pos in checked_plots

	if was_checked:
		# Uncheck: remove from list
		checked_plots.erase(grid_pos)
		_verbose.debug("input", "☐", "Unchecked plot at %s" % grid_pos)
	else:
		# Check: add to list
		checked_plots.append(grid_pos)
		_verbose.debug("input", "☑", "Checked plot at %s (total: %d)" % [grid_pos, checked_plots.size()])

	# Emit signal so PlotGridDisplay can update visual checkbox
	plot_checked.emit(grid_pos, not was_checked)


func clear_all_checks() -> void:
	"""Clear all checkmarks (useful for batch operation completion)."""
	for pos in checked_plots.duplicate():  # Duplicate to avoid modification during iteration
		plot_checked.emit(pos, false)
	checked_plots.clear()
	_verbose.debug("input", "☐", "Cleared all checkmarks")


func _clear_checks_and_cycle_biome() -> void:
	"""Shift+4E: Full quantum reset + cycle to next biome (fresh start).

	Performs:
	- Clear all checkmarks
	- Deselect all plots
	- Reset selection state
	- Reset quantum simulation (if available)
	- Cycle to next biome
	"""
	_verbose.info("input", "⇧4E", "QUANTUM RESET + CYCLE - Clearing selections and cycling biome")

	# Clear all checkmarks
	clear_all_checks()

	# Deselect all plots visually
	if plot_grid_display:
		plot_grid_display.set_selected_plot(Vector2i(-1, -1))  # Invalid position = clear selection

	# Reset current selection state
	current_selection = {"plot_idx": -1, "biome": "", "subspace_idx": -1}
	last_selected_plot_position = Vector2i(-1, -1)

	# Reset quantum simulation (if farm has reset method)
	if farm and farm.has_method("reset_quantum_state"):
		farm.reset_quantum_state()
		_verbose.info("input", "⚛️", "Quantum state reset")
	else:
		_verbose.debug("input", "~", "No quantum reset method available (farm.reset_quantum_state)")

	# Cycle to next biome
	var result = _action_cycle_biome()
	if result.success:
		_verbose.info("input", "✓", "Reset complete + cycled to %s" % result.get("new_biome", "next biome"))
	else:
		_verbose.warn("input", "⚠️", "Failed to cycle biome: %s" % result.get("message", "unknown"))


## ============================================================================
## SUBSPACE SELECTION (M,./ Row - Reserved)
## ============================================================================

func _select_subspace(subspace_idx: int, key: String) -> void:
	"""Select a subspace within the current biome (reserved for future).

	Args:
		subspace_idx: Which subspace (0-3) was selected
		key: The key that was pressed (for logging)
	"""
	_verbose.debug("input", "~", "Subspace selection reserved for future (idx: %d)" % subspace_idx)

	# Update current selection to track subspace
	current_selection.subspace_idx = subspace_idx

	# TODO: Implement subspace navigation when needed


## ============================================================================
## ACTION EXECUTION
## ============================================================================

func _perform_action(action_key: String) -> void:
	"""Execute the action mapped to Q/E/R for current tool group.

	Args:
		action_key: "Q" (DOWN), "E" (NEUTRAL), or "R" (UP)
	"""
	var current_group = ToolConfig.get_current_group()
	var action_info = ToolConfig.get_action(current_group, action_key)

	if action_info.is_empty():
		_verbose.debug("input", "~", "No action for %s in group %d" % [action_key, current_group])
		return

	var emoji = action_info.get("emoji", "")
	_verbose.info("input", emoji, "%s" % action_info.get("label", ""))

	# Check if this action opens a submenu
	if action_info.has("submenu"):
		_verbose.debug("input", "📋", "Opening submenu: %s" % action_info["submenu"])
		_open_submenu_for_action(action_info)
		return

	var action_name = action_info.get("action", "")
	if action_name == "":
		return

	if not ActionValidator.can_execute_action_name(
		action_name, farm, _get_selected_positions(), _get_grid_position()
	):
		_verbose.info("input", "•", "%s blocked" % action_info.get("label", action_name))
		return

	_run_action(action_name, emoji if emoji != "" else action_name, action_info.get("label", action_name))


func _perform_shift_key_action(action_key: String) -> void:
	"""Apply the Q/E/R action across all checked plots (multi-select batch operation).

	For gate actions (Tool 1: Unitary), uses batch injection with single buffer invalidation.
	Selection order is preserved - gates are applied in the order plots were checked.
	"""
	var current_group = ToolConfig.get_current_group()
	var action_info = ToolConfig.get_action(current_group, action_key)
	if action_info.is_empty():
		return

	# Use shift_action if defined, otherwise use normal action
	var action_name = action_info.get("shift_action", action_info.get("action", ""))
	if action_name == "":
		return

	var symbol = "⇧%s" % action_key
	var log_label = action_info.get("shift_label", action_info.get("label", action_name))

	# Use checked plots instead of entire homerow (ORDER PRESERVED from selection)
	var positions = checked_plots.duplicate()
	if positions.is_empty():
		_verbose.debug("input", "⚠️", "No plots checked - Shift+action requires checked plots")
		return

	var original_selection = current_selection.duplicate()

	# Special case: Global shift actions (execute once, not per plot)
	if action_name == "harvest_all" or action_name == "clear_all":
		_verbose.info("input", symbol, "Executing global %s once (costs 1 🍼)" % log_label)
		_run_action(action_name, symbol, log_label)
		_restore_selection(original_selection)
		return

	# BATCH GATE PATH: For Tool 1 (Unitary) gate actions, use batch injection
	# This applies all gates in selection order with SINGLE buffer invalidation
	if _is_gate_action(action_name):
		_perform_batch_gate_action(action_name, positions, symbol, log_label)
		_restore_selection(original_selection)
		return

	# NON-GATE PATH: Loop through positions (old behavior)
	_verbose.info("input", symbol, "Batch %s on %d checked plots" % [log_label, positions.size()])

	for pos in positions:
		_set_selection_for_grid_pos(pos)
		if not ActionValidator.can_execute_action_name(
			action_name, farm, _get_selected_positions(), _get_grid_position()
		):
			_verbose.info("input", "•", "%s blocked" % log_label)
			continue
		if action_name == "pop":
			_run_cleanup_action(action_name, symbol, log_label)
		else:
			_run_action(action_name, symbol, log_label)
		_refresh_plot_tiles([pos])
	_restore_selection(original_selection)


func _is_gate_action(action_name: String) -> bool:
	"""Check if action is a unitary gate operation (eligible for batch injection)."""
	return action_name in ["hadamard", "rotate_up", "rotate_down"]


func _perform_batch_gate_action(action_name: String, positions: Array, symbol: String, log_label: String) -> void:
	"""Apply gate action to multiple qubits using batch injection.

	Gates are applied in selection order (first checked = first gate applied).
	Buffer invalidation happens ONCE at the end, not per-gate.

	Args:
		action_name: Gate action (hadamard, rotate_up, rotate_down)
		positions: Array[Vector2i] of grid positions in selection order
		symbol: Log symbol
		log_label: Human-readable label
	"""
	const GateInjectorClass = preload("res://Core/QuantumSubstrate/GateInjector.gd")

	# Determine gate name from action
	var gate_name = _get_gate_name_for_action(action_name)
	if gate_name == "":
		_verbose.warn("input", "⚠️", "Unknown gate action: %s" % action_name)
		return

	# Collect gate operations in selection order
	var gate_ops: Array = []
	var order_log: Array = []

	for pos in positions:
		var biome = _get_biome_for_position(pos)
		if not biome or not biome.quantum_computer:
			continue

		var qubit = _get_qubit_for_position(pos, biome)
		if qubit < 0:
			continue

		gate_ops.append({
			"biome": biome,
			"qubit": qubit,
			"gate_name": gate_name
		})
		order_log.append("q%d" % qubit)

	if gate_ops.is_empty():
		_verbose.warn("input", "⚠️", "No valid qubits for batch gate")
		return

	_verbose.info("input", symbol, "Batch %s on %d qubits (order: %s)" % [
		log_label, gate_ops.size(), " → ".join(order_log)
	])

	# BATCH INJECTION: All gates applied, single buffer invalidation
	var result = GateInjectorClass.inject_gate_batch(gate_ops, farm)

	if result.success:
		_verbose.info("input", "✓", "Applied %d gates, order preserved: %s" % [
			result.applied_count, result.order
		])
	else:
		_verbose.warn("input", "✗", "Batch gate failed: %s" % result.get("error", "unknown"))

	action_performed.emit(action_name, result)
	_refresh_plot_tiles(positions)


func _get_gate_name_for_action(action_name: String) -> String:
	"""Map action name to gate library name."""
	match action_name:
		"hadamard":
			return "H"
		"rotate_up", "rotate_down":
			# Get axis from Tool 1 mode (X, Y, or Z)
			var axis = ToolConfig.get_group_mode_name(1)
			if axis == "":
				axis = "X"
			return "R" + axis.to_lower()  # Rx, Ry, or Rz
		_:
			return ""


func _get_biome_for_position(pos: Vector2i):
	"""Get biome for a grid position."""
	if not farm or not farm.grid:
		return null
	var biome_name = farm.get_biome_for_row(pos.y) if farm.has_method("get_biome_for_row") else ""
	if biome_name == "":
		return null
	return farm.grid.biomes.get(biome_name)


func _get_qubit_for_position(pos: Vector2i, biome) -> int:
	"""Get qubit index for a grid position via terminal binding."""
	if not farm or not farm.plot_pool:
		return -1

	var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
	if terminal and terminal.is_bound:
		return terminal.bound_register_id

	# Fallback: try viz_cache lookup
	var plot = farm.grid.get_plot(pos) if farm.grid else null
	if plot and plot.is_planted and biome and biome.viz_cache:
		return biome.viz_cache.get_qubit(plot.north_emoji)

	return -1


func _run_action(action_name: String, log_symbol: String, action_label: String) -> void:
	"""Execute an action and emit logging + signal."""
	var result = _execute_action(action_name)
	_log_action_result(action_name, log_symbol, action_label, result)


func _run_cleanup_action(action_name: String, log_symbol: String, action_label: String) -> void:
	"""Execute a cleanup version of an action (e.g., pop cleanup)."""
	var result = _execute_cleanup_action(action_name)
	_log_action_result(action_name, log_symbol, action_label, result)


func _execute_cleanup_action(action_name: String) -> Dictionary:
	"""Execute cleanup variants for actions that require special handling.

	NOTE: Currently just calls _execute_action() for all actions.
	Previously had special handling for pop cleanup, but unified into standard _action_pop().
	"""
	return _execute_action(action_name)


func _log_action_result(action_name: String, log_symbol: String, action_label: String, result: Dictionary) -> void:
	var symbol = log_symbol if log_symbol != "" else action_name
	var label = action_label if action_label != "" else action_name
	if result.get("success", false):
		_verbose.info("input", symbol, "%s succeeded: %s" % [label, result])
	else:
		var message = result.get("message", "unknown")
		if result.get("blocked", false):
			_verbose.info("input", "•", "%s blocked: %s" % [label, message])
		else:
			_verbose.warn("input", "✗", "%s failed: %s" % [label, message])
	action_performed.emit(action_name, result)


func _execute_action(action_name: String) -> Dictionary:
	"""Execute a specific action by name.

	Routes to appropriate handler based on action name.
	"""
	if not farm:
		return {"success": false, "error": "no_farm", "message": "Farm not initialized"}

	match action_name:
		# =====================================================================
		# GROUP 1: UNITARY - Quantum gates
		# =====================================================================
		"rotate_up":
			return _action_rotate(1)
		"rotate_down":
			return _action_rotate(-1)
		"hadamard":
			return _action_hadamard()

		# =====================================================================
		# GROUP 2: LINDBLADIAN - Energy exchange
		# =====================================================================
		"drain":
			return _action_drain()
		"transfer":
			return _action_transfer()
		"pump":
			return _action_pump()

		# =====================================================================
		# GROUP 3: MEASURE - Probe mode
		# =====================================================================
		"explore":
			return _action_explore()
		"measure":
			return _action_measure()
		"reap":
			return _action_reap()
		"pop":
			return _action_pop()
		"harvest_all":
			return _action_harvest_all()
		"clear_all":
			return _action_clear_all()

		# GROUP 3: MEASURE - Gate mode
		"build_gate":
			return _action_build_gate()
		"inspect":
			return _action_inspect()
		"remove_gates":
			return _action_remove_gates()

		# =====================================================================
		# GROUP 4: META - Vocabulary/Biome
		# =====================================================================
		"inject_vocabulary":
			return _action_inject_vocabulary()
		"explore_biome":
			return _action_explore_biome()
		"cycle_biome", "toggle_view":
			return _action_cycle_biome()
		"remove_vocabulary":
			return _action_remove_vocabulary()

		_:
			_verbose.warn("input", "?", "Unknown action: %s" % action_name)
			return {"success": false, "error": "unknown_action", "message": "Unknown action: %s" % action_name}


## ============================================================================
## GROUP 1: UNITARY ACTIONS
## ============================================================================

func _action_rotate(direction: int) -> Dictionary:
	"""Apply rotation to selected plot."""
	_verbose.debug("input", "R", "Rotate: selection=%s dir=%d" % [current_selection, direction])

	if current_selection.plot_idx < 0:
		return {"success": false, "error": "no_selection", "message": "No plot selected"}

	var axis = ToolConfig.get_group_mode_name(1)
	if axis == "":
		axis = "X"

	var positions = _get_selected_positions()
	var gate_name = "R" + axis.to_lower()  # Rx, Ry, or Rz
	_verbose.debug("input", "R", "Rotate: axis=%s positions=%s" % [axis, positions])

	# Use GateActionHandler for rotation
	var result: Dictionary
	match axis:
		"X":
			result = GateActionHandler.apply_rx_gate(farm, positions)
		"Y":
			result = GateActionHandler.apply_ry_gate(farm, positions)
		"Z":
			result = GateActionHandler.apply_rz_gate(farm, positions)
		_:
			result = {"success": true, "axis": axis, "direction": direction}

	_verbose.debug("input", "R", "Rotate result: %s" % result)
	return result


func _action_hadamard() -> Dictionary:
	"""Apply Hadamard gate to selected plot."""
	_verbose.debug("input", "H", "Hadamard: selection=%s" % current_selection)

	if current_selection.plot_idx < 0:
		return {"success": false, "error": "no_selection", "message": "No plot selected"}

	var positions = _get_selected_positions()
	_verbose.debug("input", "H", "Hadamard: positions=%s" % [positions])

	var result = GateActionHandler.apply_hadamard(farm, positions)
	_verbose.debug("input", "H", "Hadamard result: %s" % result)

	return result


## ============================================================================
## GROUP 2: LINDBLADIAN ACTIONS
## ============================================================================

func _action_drain() -> Dictionary:
	"""Drain: Dissipate excess energy to classical resources."""
	if current_selection.plot_idx < 0:
		return {"success": false, "error": "no_selection", "message": "No plot selected"}

	var positions = _get_selected_positions()
	var result = LindbladHandler.enable_persistent_decay(farm, positions)

	if result.get("success", false):
		_refresh_plot_tiles(positions)

	return result


func _action_transfer() -> Dictionary:
	"""Transfer: Move population between qubits."""
	if current_selection.plot_idx < 0:
		return {"success": false, "error": "no_selection", "message": "No plot selected"}

	var positions = _get_selected_positions()
	return LindbladHandler.lindblad_transfer(farm, positions)


func _action_pump() -> Dictionary:
	"""Pump: Drive energy into quantum state."""
	if current_selection.plot_idx < 0:
		return {"success": false, "error": "no_selection", "message": "No plot selected"}

	var positions = _get_selected_positions()
	var result = LindbladHandler.enable_persistent_drive(farm, positions)
	_refresh_plot_tiles(positions)
	return result


func _refresh_plot_tiles(positions: Array[Vector2i]) -> void:
	"""Refresh plot tiles after stateful actions."""
	if not plot_grid_display:
		return
	for pos in positions:
		if plot_grid_display.has_method("update_tile_from_farm"):
			plot_grid_display.update_tile_from_farm(pos)


## ============================================================================
## GROUP 3: MEASURE ACTIONS - Probe Mode
## ============================================================================

func _action_explore() -> Dictionary:
	"""Execute EXPLORE action - bind terminal to register."""
	if not farm or not farm.plot_pool:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	if current_selection.plot_idx < 0:
		return {"success": false, "error": "no_selection", "message": "No plot selected"}

	var biome = _get_current_biome()
	if not biome:
		return {"success": false, "error": "no_biome", "message": "No biome at selection"}
	if not biome.viz_cache or not biome.viz_cache.has_metadata():
		return {"success": false, "error": "no_viz_cache", "message": "Biome visualization data not ready"}

	if not farm.economy:
		return {"success": false, "error": "no_economy", "message": "Economy system not initialized"}

	var grid_pos = _get_grid_position()
	_verbose.debug("input", "?", "Explore at %s in %s" % [grid_pos, biome.name if biome else "null"])

	var result = ProbeActions.action_explore(farm.plot_pool, biome, farm.economy)

	if result.get("success", false):
		_verbose.debug("input", "?", "Terminal %s bound to grid %s" % [result.terminal.terminal_id, grid_pos])
	# Central signal emission (handles grid_position assignment internally)
	farm.emit_action_signal("explore", result, grid_pos)

	return result


func _action_measure() -> Dictionary:
	"""Execute MEASURE action - collapse terminal state."""
	if not farm or not farm.plot_pool:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	var grid_pos = _get_grid_position()
	_verbose.debug("input", "🔍", "MEASURE DEBUG: grid_pos=%s, current_selection=%s" % [grid_pos, current_selection])

	var terminal = farm.plot_pool.get_terminal_at_grid_pos(grid_pos)

	if not terminal:
		_verbose.warn("input", "❌", "MEASURE DEBUG: No terminal found at %s" % grid_pos)
		return {"success": false, "error": "no_terminal", "message": "No terminal at selection", "blocked": true}

	_verbose.debug("input", "🔍", "MEASURE DEBUG: Terminal found - is_bound=%s, is_measured=%s, terminal_id=%s" % [terminal.is_bound, terminal.is_measured, terminal.terminal_id])

	if not terminal.can_measure():
		_verbose.warn("input", "❌", "MEASURE DEBUG: can_measure()=false (is_bound=%s, is_measured=%s)" % [terminal.is_bound, terminal.is_measured])
		return {"success": false, "error": "cannot_measure", "message": "Terminal not ready to measure", "blocked": true}

	# Resolve biome from terminal's biome name
	var biome_name = terminal.bound_biome_name
	if biome_name == "":
		return {"success": false, "error": "no_biome", "message": "Terminal not bound to biome", "blocked": true}

	var biome = farm.grid.biomes.get(biome_name, null) if farm and farm.grid else null
	if not biome:
		return {"success": false, "error": "no_biome", "message": "Biome '%s' not found" % biome_name, "blocked": true}

	var result = ProbeActions.action_measure(terminal, biome)

	# Central signal emission
	farm.emit_action_signal("measure", result, grid_pos)

	return result


func _action_reap() -> Dictionary:
	"""Execute REAP action - harvest credits and unbind terminal."""
	if not farm or not farm.plot_pool or not farm.economy:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	var grid_pos = _get_grid_position()
	var terminal = _resolve_terminal_for_harvest(grid_pos)

	if not terminal:
		return {"success": false, "error": "no_terminal", "message": "No terminal at selection"}

	var result = ProbeActions.action_reap(terminal, farm.plot_pool, farm.economy, farm)

	# Central signal emission
	farm.emit_action_signal("reap", result, grid_pos)

	return result


func _action_pop() -> Dictionary:
	"""Execute POP action - harvest credits and unbind terminal."""
	if not farm or not farm.plot_pool or not farm.economy:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	var grid_pos = _get_grid_position()
	var terminal = _resolve_terminal_for_harvest(grid_pos)

	if not terminal:
		return {"success": false, "error": "no_terminal", "message": "No terminal at selection"}

	var result = ProbeActions.action_pop(terminal, farm.plot_pool, farm.economy, farm)

	# Central signal emission
	farm.emit_action_signal("pop", result, grid_pos)

	return result


func _action_harvest_all() -> Dictionary:
	"""Execute SHIFT+R/harvest_all: harvest density matrix, clear selections, unexplore plots."""
	if not farm or not farm.plot_pool or not farm.economy:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	var biome = _get_current_biome()
	var result = ProbeActions.action_harvest_all(farm.plot_pool, farm.economy, biome)

	# Central signal emission (handles all terminal_released signals internally)
	farm.emit_action_signal("harvest_all", result)

	if result.get("success", false):
		# Clear all checkmarks after successful harvest
		clear_all_checks()
		var harvest_results = result.get("harvest_results", [])
		_verbose.info("input", "🧹", "Cleared %d terminals and selections after density matrix harvest" % harvest_results.size())

	return result


func _action_clear_all() -> Dictionary:
	"""Execute SHIFT+R/clear_all: unbind all terminals without harvesting."""
	if not farm or not farm.plot_pool:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	var result = ProbeActions.action_clear_all(farm.plot_pool)

	# Central signal emission (handles all terminal_released signals internally)
	farm.emit_action_signal("clear_all", result)

	return result


## ============================================================================
## GROUP 3: MEASURE ACTIONS - Gate Mode
## ============================================================================

func _action_build_gate() -> Dictionary:
	"""Build gate (bell/cluster/cnot based on selection count)."""
	if current_selection.plot_idx < 0:
		return {"success": false, "error": "no_selection", "message": "No plot selected"}

	var positions = _get_selected_positions()

	# Auto-select gate type based on number of positions
	if positions.size() == 2:
		# Bell pair for exactly 2 positions
		return GateActionHandler.create_bell_pair(farm, positions)
	elif positions.size() > 2:
		# Cluster for 3+ positions
		return GateActionHandler.cluster(farm, positions)
	else:
		# Single position - apply CNOT with next available
		return {"success": false, "error": "need_more_plots", "message": "Select 2+ plots for gate"}


func _action_inspect() -> Dictionary:
	"""Inspect entanglement at selection."""
	if current_selection.plot_idx < 0:
		return {"success": false, "error": "no_selection", "message": "No plot selected"}

	var positions = _get_selected_positions()
	return GateActionHandler.inspect_entanglement(farm, positions)


func _action_remove_gates() -> Dictionary:
	"""Remove gate infrastructure."""
	if current_selection.plot_idx < 0:
		return {"success": false, "error": "no_selection", "message": "No plot selected"}

	var positions = _get_selected_positions()
	return GateActionHandler.disentangle(farm, positions)


## ============================================================================
## GROUP 4: META ACTIONS
## ============================================================================

func _action_inject_vocabulary() -> Dictionary:
	"""Inject vocabulary into biome (save-like operation)."""
	if current_selection.plot_idx < 0:
		return {"success": false, "error": "no_selection", "message": "No plot selected"}

	var biome = _get_current_biome()
	if not biome:
		return {"success": false, "error": "no_biome", "message": "No biome at selection"}
	
	var qubit_count = biome.get_total_register_count() if biome.has_method("get_total_register_count") else 0
	if qubit_count >= EconomyConstants.MAX_BIOME_QUBITS:
		return {
			"success": false,
			"error": "qubit_cap_reached",
			"message": "Biome is at max capacity (%d qubits)" % EconomyConstants.MAX_BIOME_QUBITS
		}

	var candidate_pairs = _collect_injectable_pairs(farm, biome)
	var pair = _pick_injectable_pair(candidate_pairs, biome)
	if pair.is_empty():
		return {"success": false, "error": "no_available_pair", "message": "No injectable vocab pair for this biome"}

	# CRITICAL: Check and spend cost BEFORE heavy expansion
	var context = {"south_emoji": pair.get("south", "")}
	if not farm or not farm.economy or not EconomyConstants.try_action("inject_vocabulary", farm.economy, context):
		var cost = EconomyConstants.get_action_cost("inject_vocabulary", context)
		return {
			"success": false,
			"error": "insufficient_funds",
			"message": "Insufficient resources for vocab injection (%s)" % [cost]
		}

	# Heavy operation starts here
	var result = biome.expand_quantum_system(pair.get("north", ""), pair.get("south", ""))
	if result.get("success", false):
		if farm and farm.has_method("discover_pair"):
			farm.discover_pair(pair.get("north", ""), pair.get("south", ""))
		
		_verbose.debug("input", "+", "Injected vocab %s/%s into %s" % [
			pair.get("north", ""), pair.get("south", ""), current_selection.biome
		])
		return result

	return {
		"success": false,
		"error": result.get("error", "expansion_failed"),
		"message": result.get("message", "Failed to expand quantum system")
	}


func _action_cycle_biome() -> Dictionary:
	"""Cycle to next biome (replaces old '=' key behavior)."""
	if not _active_biome_mgr:
		return {"success": false, "error": "no_biome_manager", "message": "ActiveBiomeManager not available"}

	var old_biome = _active_biome_mgr.get_active_biome()
	_active_biome_mgr.cycle_next()
	var new_biome = _active_biome_mgr.get_active_biome()

	_verbose.info("input", "=", "Biome: %s -> %s" % [old_biome, new_biome])

	return {
		"success": true,
		"old_biome": old_biome,
		"new_biome": new_biome
	}


func _action_explore_biome() -> Dictionary:
	"""Explore and unlock a random new biome (4E action)."""
	if not farm:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}
	if not farm.has_method("explore_biome"):
		return {"success": false, "error": "no_method", "message": "Farm cannot explore biomes"}
	var result = farm.explore_biome()
	if result.get("success", false):
		_select_tool_group(3)
	return result


func _action_remove_vocabulary() -> Dictionary:
	"""Remove vocabulary from biome - shrink quantum system."""
	if current_selection.plot_idx < 0:
		return {"success": false, "error": "no_selection", "message": "No plot selected"}

	var biome = _get_current_biome()
	if not biome or not biome.quantum_computer:
		return {"success": false, "error": "no_biome", "message": "No biome at selection"}

	var qc = biome.quantum_computer
	var rm = qc.register_map

	# Need at least 2 qubits to remove one (can't go below 1)
	if rm.num_qubits < 2:
		return {"success": false, "error": "minimum_reached", "message": "Cannot remove last vocab pair"}

	var target_qubit = rm.num_qubits - 1
	var pair_to_remove = {}
	var grid_pos = _get_grid_position()
	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name
	var terminal = farm.plot_pool.get_terminal_at_grid_pos(grid_pos) if farm and farm.plot_pool else null
	if terminal and terminal.is_bound and terminal.bound_biome_name == biome_name:
		target_qubit = terminal.bound_register_id
		pair_to_remove = _get_pair_for_qubit(rm, target_qubit)
	else:
		pair_to_remove = _get_pair_for_qubit(rm, target_qubit)

	var cost = EconomyConstants.get_action_cost("remove_vocabulary")
	if cost.size() > 0:
		if not farm.economy or not EconomyConstants.try_action("remove_vocabulary", farm.economy):
			return {
				"success": false,
				"error": "insufficient_resources",
				"message": "Need %d %s to remove vocabulary." % [cost.values()[0], cost.keys()[0]]
			}

	if pair_to_remove.is_empty():
		return {"success": false, "error": "no_pair_found", "message": "Could not find vocab pair to remove"}

	_unbind_terminals_for_register(biome, target_qubit)

	# Perform the shrink operation
	var result = _shrink_quantum_system(biome, target_qubit, pair_to_remove)

	if result.get("success", false):
		_reindex_bound_terminals(biome, target_qubit)
		_verbose.info("input", "-", "Removed vocab %s/%s from %s" % [
			pair_to_remove.get("north", "?"),
			pair_to_remove.get("south", "?"),
			current_selection.biome
		])

	return result


func _get_pair_for_qubit(register_map, qubit_index: int) -> Dictionary:
	"""Get the north/south emoji pair for a given qubit index."""
	var north = ""
	var south = ""

	# Search coordinates for emojis at this qubit index
	for emoji in register_map.coordinates.keys():
		var coord = register_map.coordinates[emoji]
		if coord.qubit == qubit_index:
			if coord.pole == 0:
				north = emoji
			else:
				south = emoji

	if north != "" and south != "":
		return {"north": north, "south": south}
	return {}


func _shrink_quantum_system(biome, qubit_to_remove: int, pair: Dictionary) -> Dictionary:
	"""Shrink the quantum system by removing a qubit axis.

	This is the inverse of expand_quantum_system():
	1. Remove emoji entries from register_map
	2. Shrink density matrix
	3. Rebuild operators
	"""
	var qc = biome.quantum_computer
	var rm = qc.register_map

	var north = pair.get("north", "")
	var south = pair.get("south", "")
	var old_dim = rm.dim()
	var old_num_qubits = rm.num_qubits

	# 1. Remove from register_map coordinates
	rm.coordinates.erase(north)
	rm.coordinates.erase(south)

	# 2. Shrink density matrix by tracing out the removed qubit
	if qc.density_matrix:
		qc.density_matrix = _trace_out_qubit(qc.density_matrix, qubit_to_remove, old_num_qubits)

	# 2b. Reindex register_map and entanglement graph
	_reindex_register_map_after_removal(rm, qubit_to_remove, old_num_qubits)
	_reindex_entanglement_graph(qc, qubit_to_remove)

	# 3. Rebuild operators with remaining emojis
	_rebuild_operators_after_shrink(biome)

	var new_dim = rm.dim()

	_verbose.debug("input", "-", "Shrunk %s: %d -> %d qubits (%dD -> %dD)" % [
		biome.get_biome_type(), old_num_qubits, rm.num_qubits, old_dim, new_dim])

	return {
		"success": true,
		"removed_north": north,
		"removed_south": south,
		"old_dim": old_dim,
		"new_dim": new_dim,
		"old_qubits": old_num_qubits,
		"new_qubits": rm.num_qubits
	}


func _reindex_register_map_after_removal(register_map, removed_qubit: int, old_num_qubits: int) -> void:
	var updated_axes: Dictionary = {}

	for emoji in register_map.coordinates.keys():
		var coord = register_map.coordinates[emoji]
		var qubit_index = coord.get("qubit", -1)
		if qubit_index > removed_qubit:
			coord["qubit"] = qubit_index - 1
			register_map.coordinates[emoji] = coord
			qubit_index -= 1

		if not updated_axes.has(qubit_index):
			updated_axes[qubit_index] = {"north": "", "south": ""}

		if coord.get("pole", 0) == 0:
			updated_axes[qubit_index]["north"] = emoji
		else:
			updated_axes[qubit_index]["south"] = emoji

	register_map.axes = updated_axes
	register_map.num_qubits = max(old_num_qubits - 1, 0)


func _reindex_entanglement_graph(quantum_computer, removed_qubit: int) -> void:
	if not quantum_computer or not quantum_computer.entanglement_graph:
		return

	var updated_graph: Dictionary = {}
	for reg_id in quantum_computer.entanglement_graph.keys():
		if reg_id == removed_qubit:
			continue
		var new_reg = reg_id - 1 if reg_id > removed_qubit else reg_id
		var neighbors: Array = []
		for neighbor in quantum_computer.entanglement_graph[reg_id]:
			if neighbor == removed_qubit:
				continue
			var new_neighbor = neighbor - 1 if neighbor > removed_qubit else neighbor
			if not neighbors.has(new_neighbor):
				neighbors.append(new_neighbor)
		updated_graph[new_reg] = neighbors

	quantum_computer.entanglement_graph = updated_graph


func _unbind_terminals_for_register(biome, register_id: int) -> void:
	if not farm or not farm.plot_pool:
		return
	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name
	for terminal in farm.plot_pool.get_all_terminals():
		if terminal.is_bound and terminal.bound_biome_name == biome_name and terminal.bound_register_id == register_id:
			farm.plot_pool.unbind_terminal(terminal)


func _reindex_bound_terminals(biome, removed_qubit: int) -> void:
	if not farm or not farm.plot_pool:
		return
	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name
	for terminal in farm.plot_pool.get_all_terminals():
		if not terminal.is_bound or terminal.bound_biome_name != biome_name:
			continue
		if terminal.bound_register_id > removed_qubit:
			terminal.bound_register_id -= 1



func _trace_out_qubit(density_matrix, qubit_index: int, num_qubits: int):
	"""Trace out a qubit from the density matrix (partial trace).

	For a system of n qubits where we remove qubit k:
	- Old dimension: 2^n
	- New dimension: 2^(n-1)

	The partial trace sums over the traced-out qubit's degrees of freedom.
	"""
	var old_dim = density_matrix.n
	var new_num_qubits = num_qubits - 1
	var new_dim = 1 << new_num_qubits  # 2^(n-1)

	if new_dim < 1:
		return density_matrix  # Can't shrink below 1

	# Create new density matrix
	var ComplexMatrixClass = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	var ComplexClass = load("res://Core/QuantumSubstrate/Complex.gd")
	var new_dm = ComplexMatrixClass.new(new_dim)

	# Perform partial trace
	# For each element (i,j) in new matrix, sum over the traced qubit
	for i in range(new_dim):
		for j in range(new_dim):
			var sum_re = 0.0
			var sum_im = 0.0

			# Insert 0 and 1 at the qubit_index position
			for traced_val in [0, 1]:
				var old_i = _insert_bit(i, qubit_index, traced_val, new_num_qubits)
				var old_j = _insert_bit(j, qubit_index, traced_val, new_num_qubits)

				if old_i < old_dim and old_j < old_dim:
					var elem = density_matrix.get_element(old_i, old_j)
					if elem:
						sum_re += elem.re
						sum_im += elem.im

			new_dm.set_element(i, j, ComplexClass.new(sum_re, sum_im))

	return new_dm


func _insert_bit(index: int, bit_position: int, bit_value: int, num_bits: int) -> int:
	"""Insert a bit at a specific position in an index.

	Example: insert_bit(0b11, 1, 0, 2) -> 0b101 (insert 0 at position 1)
	"""
	# Bits above the insertion point
	var high_mask = (-1) << bit_position
	var high_bits = (index & high_mask) << 1

	# Bits below the insertion point
	var low_mask = (1 << bit_position) - 1
	var low_bits = index & low_mask

	# Combine with the inserted bit
	return high_bits | (bit_value << bit_position) | low_bits


func _rebuild_operators_after_shrink(biome) -> void:
	"""Rebuild Hamiltonian and Lindblad operators after shrinking."""
	var qc = biome.quantum_computer
	var _icon_reg = get_node_or_null("/root/IconRegistry")

	if not _icon_reg:
		push_warning("_rebuild_operators_after_shrink: IconRegistry not available")
		return

	# Gather remaining icons
	var all_icons = {}
	for emoji in qc.register_map.coordinates.keys():
		var icon = _icon_reg.get_icon(emoji)
		if icon:
			all_icons[emoji] = icon

	# Rebuild operators
	var HamBuilder = load("res://Core/QuantumSubstrate/HamiltonianBuilder.gd")
	var LindBuilder = load("res://Core/QuantumSubstrate/LindbladBuilder.gd")
	var verbose_ref = get_node_or_null("/root/VerboseConfig")

	qc.hamiltonian = HamBuilder.build(all_icons, qc.register_map, verbose_ref)
	var lindblad_result = LindBuilder.build(all_icons, qc.register_map, verbose_ref)
	qc.lindblad_operators = lindblad_result.get("operators", [])
	qc.gated_lindblad_configs = lindblad_result.get("gated_configs", [])

	# Re-extract driven configs
	var driven_configs = HamBuilder.get_driven_icons(all_icons, qc.register_map)
	qc.set_driven_icons(driven_configs)


## ============================================================================
## HELPER FUNCTIONS
## ============================================================================

func _get_current_biome():
	"""Get the biome for the current selection."""
	if not farm or not farm.grid:
		return null

	var biome_name = current_selection.get("biome", "")
	if biome_name == "":
		biome_name = _active_biome_mgr.get_active_biome() if _active_biome_mgr else "BioticFlux"

	return farm.grid.biomes.get(biome_name)


func _get_grid_position() -> Vector2i:
	"""Convert current selection to grid position."""
	var plot_idx = current_selection.get("plot_idx", 0)
	var biome_name = current_selection.get("biome", "")

	# Map biome name to row (y coordinate)
	var biome_row = farm.get_biome_row(biome_name) if farm and farm.has_method("get_biome_row") else 0

	return Vector2i(plot_idx, biome_row)


func _get_active_biome_register_count() -> int:
	"""Get register (qubit) count for the currently active biome."""
	if not farm or not farm.grid or not _active_biome_mgr:
		return 0
	var biome_name = _active_biome_mgr.get_active_biome()
	if biome_name == "":
		return 0
	if not farm.grid.biomes.has(biome_name):
		return 0
	var biome = farm.grid.biomes[biome_name]
	if biome and biome.quantum_computer and biome.quantum_computer.register_map:
		return biome.quantum_computer.register_map.num_qubits
	return 0


func _get_selected_positions() -> Array[Vector2i]:
	"""Get array of selected positions (currently just single selection)."""
	var positions: Array[Vector2i] = []
	if current_selection.plot_idx >= 0:
		positions.append(_get_grid_position())
	return positions

func _resolve_terminal_for_harvest(grid_pos: Vector2i) -> RefCounted:
	"""Locate the terminal that should be harvested for a given selection."""
	if not farm or not farm.plot_pool:
		return null

	var terminal = farm.plot_pool.get_terminal_at_grid_pos(grid_pos)
	if terminal:
		return terminal

	# Fallback: try the last selected plot (useful when selection resets after MEASURE)
	if last_selected_plot_position != Vector2i(-1, -1) and last_selected_plot_position != grid_pos:
		var fallback = farm.plot_pool.get_terminal_at_grid_pos(last_selected_plot_position)
		if fallback and fallback.is_measured:
			return fallback

	# Final fallback: search measured terminals exactly at the requested grid
	if farm.plot_pool.has_method("get_measured_terminals"):
		for candidate in farm.plot_pool.get_measured_terminals():
			if candidate.grid_position == grid_pos:
				return candidate

	return null


func _get_homerow_positions() -> Array[Vector2i]:
	"""Return the four plot positions for the current biome (JKL; row)."""
	var positions: Array[Vector2i] = []
	var row = _get_current_biome_row()
	for idx in range(4):
		positions.append(Vector2i(idx, row))
	return positions


func _get_current_biome_row() -> int:
	if not farm:
		return 0
	var biome_name = current_selection.get("biome", "")
	if biome_name == "":
		biome_name = _active_biome_mgr.get_active_biome() if _active_biome_mgr else "BioticFlux"
	if biome_name == "":
		biome_name = "BioticFlux"
	if farm.has_method("get_biome_row"):
		return farm.get_biome_row(biome_name)
	return 0


func _set_selection_for_grid_pos(grid_pos: Vector2i) -> void:
	"""Update current_selection to match the specified grid position."""
	if not farm:
		return
	var biome_name = farm.get_biome_for_row(grid_pos.y) if farm.has_method("get_biome_for_row") else ""
	current_selection = {
		"plot_idx": grid_pos.x,
		"biome": biome_name,
		"subspace_idx": -1
	}


func _restore_selection(previous_selection: Dictionary) -> void:
	"""Restore the selection state and refresh visual highlight."""
	if previous_selection and previous_selection.has("plot_idx"):
		current_selection = previous_selection.duplicate()
	else:
		current_selection = {"plot_idx": -1, "biome": "", "subspace_idx": -1}

	if plot_grid_display and farm and current_selection.plot_idx >= 0:
		var grid_pos = _get_grid_position()
		if grid_pos.x >= 0:
			plot_grid_display.set_selected_plot(grid_pos)


func _pick_injectable_pair(pairs: Array, biome) -> Dictionary:
	for i in range(pairs.size() - 1, -1, -1):
		var pair = pairs[i]
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north == "" or south == "":
			continue
		if _biome_has_emoji(biome, north):
			continue
		if _biome_has_emoji(biome, south):
			continue
		return {"north": north, "south": south}
	return {}


func _collect_injectable_pairs(farm_ref, biome = null) -> Array:
	var pairs: Array = []
	if farm_ref and farm_ref.has_method("get_known_pairs"):
		pairs.append_array(farm_ref.get_known_pairs())
	if farm_ref and "vocabulary_evolution" in farm_ref and farm_ref.vocabulary_evolution:
		var vocab = farm_ref.vocabulary_evolution
		if vocab and vocab.has_method("get_discovered_vocabulary"):
			var discovered = vocab.get_discovered_vocabulary()
			if discovered is Array:
				pairs.append_array(discovered)

	var filtered: Array = []
	var seen: Dictionary = {}
	for pair in pairs:
		if not (pair is Dictionary):
			continue
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north == "" or south == "" or north == south:
			continue
		if biome and (_biome_has_emoji(biome, north) or _biome_has_emoji(biome, south)):
			continue
		var key = "%s|%s" % [north, south]
		if seen.has(key):
			continue
		seen[key] = true
		filtered.append({"north": north, "south": south})
	return filtered


func _biome_has_emoji(biome, emoji: String) -> bool:
	if not biome or emoji == "":
		return false
	if biome.viz_cache and biome.viz_cache.has_metadata():
		return biome.viz_cache.get_qubit(emoji) >= 0
	return false


func _keycode_to_string(keycode: int) -> String:
	"""Convert keycode to string representation."""
	match keycode:
		KEY_0: return "0"
		KEY_1: return "1"
		KEY_2: return "2"
		KEY_3: return "3"
		KEY_4: return "4"
		KEY_Q: return "Q"
		KEY_E: return "E"
		KEY_R: return "R"
		KEY_F: return "F"
		KEY_T: return "T"
		KEY_Y: return "Y"
		KEY_U: return "U"
		KEY_I: return "I"
		KEY_O: return "O"
		KEY_P: return "P"
		KEY_H: return "H"
		KEY_G: return "G"
		KEY_J: return "J"
		KEY_K: return "K"
		KEY_L: return "L"
		KEY_SEMICOLON: return ";"
		KEY_APOSTROPHE: return "'"
		KEY_M: return "M"
		KEY_COMMA: return ","
		KEY_PERIOD: return "."
		KEY_SLASH: return "/"
		KEY_MINUS: return "-"
		KEY_EQUAL: return "="
		_: return ""




## ============================================================================
## PUBLIC API
## ============================================================================

func get_current_selection() -> Dictionary:
	"""Get current plot selection."""
	return current_selection.duplicate()


func can_execute_action(action_key: String) -> bool:
	"""Check if action can succeed with current selection (for UI highlighting)."""
	if current_selection.get("plot_idx", -1) < 0:
		return false
	if not farm:
		return false

	var selected_positions = _get_selected_positions()
	var current_pos = _get_grid_position()
	return ActionValidator.can_execute_action(
		action_key,
		ToolConfig.get_current_group(),
		"",
		{},
		farm,
		selected_positions,
		current_pos
	)


func get_current_tool_group() -> int:
	"""Get current tool group number."""
	return ToolConfig.get_current_group()


func get_current_tool_info() -> Dictionary:
	"""Get info about current tool group."""
	var group = ToolConfig.get_current_group()
	return {
		"group": group,
		"name": ToolConfig.get_group_name(group),
		"emoji": ToolConfig.get_group_emoji(group),
		"time_scale": ToolConfig.get_group_time_scale(group),
		"mode": ToolConfig.get_group_mode_name(group),
		"mode_label": ToolConfig.get_group_mode_label(group),
		"mode_emoji": ToolConfig.get_group_mode_emoji(group)
	}


func get_actions_for_current_group() -> Dictionary:
	"""Get Q/E/R actions for current tool group."""
	return ToolConfig.get_all_actions(ToolConfig.get_current_group())


## ============================================================================
## SIMULATION SPEED CONTROLS
## ============================================================================

func _decrease_simulation_speed() -> void:
	"""Decrease quantum evolution granularity - finer substeps (- key)."""
	if not farm or not farm.grid:
		_verbose.warn("input", "⚠️", "Cannot adjust granularity - no farm/grid")
		return

	# Use shared granularity controller
	var biomes = farm.grid.biomes.values()
	var result = GranularityController.decrease_granularity(biomes)

	# Update GameState so it's saved
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state:
		if not ("max_evolution_dt" in gsm.current_state):
			gsm.current_state.set("max_evolution_dt", result.new_dt)
		else:
			gsm.current_state.max_evolution_dt = result.new_dt

	_verbose.info("input", "🔬", "Matrix granularity: %.4fs → %.4fs (finer, %d biomes)" % [
		result.current_dt, result.new_dt, result.biome_count
	])


func _increase_simulation_speed() -> void:
	"""Increase quantum evolution granularity - coarser substeps (= key)."""
	if not farm or not farm.grid:
		_verbose.warn("input", "⚠️", "Cannot adjust granularity - no farm/grid")
		return

	# Use shared granularity controller
	var biomes = farm.grid.biomes.values()
	var result = GranularityController.increase_granularity(biomes)

	# Update GameState so it's saved
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state:
		if not ("max_evolution_dt" in gsm.current_state):
			gsm.current_state.set("max_evolution_dt", result.new_dt)
		else:
			gsm.current_state.max_evolution_dt = result.new_dt

	_verbose.info("input", "🔭", "Matrix granularity: %.4fs → %.4fs (coarser, %d biomes)" % [
		result.current_dt, result.new_dt, result.biome_count
	])
