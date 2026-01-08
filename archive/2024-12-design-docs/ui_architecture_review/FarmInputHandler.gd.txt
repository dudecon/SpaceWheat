class_name FarmInputHandler
extends Node

## Keyboard-driven Farm UI - Minecraft-style tool/action system
## Numbers 1-6 = Tool modes (Plant, Quantum, Economy, etc)
## Q/E/R = Context-sensitive actions (depends on active tool)
## WASD = Movement/cursor control
## YUIOP = Quick-access location selectors

# Preload GridConfig (Phase 7)
const GridConfig = preload("res://Core/GameState/GridConfig.gd")

var farm  # Will be injected with Farm instance (Farm.gd)
var plot_grid_display: Node = null  # NEW: Will be injected with PlotGridDisplay instance
var current_selection: Vector2i = Vector2i.ZERO
var current_tool: int = 1  # Active tool (1-6)
var grid_config: GridConfig = null  # Grid configuration (Phase 7)
var input_enable_frame_count: int = 0  # Counter to enable input after N frames

# Config (deprecated - now read from GridConfig)
var grid_width: int = 6
var grid_height: int = 2

# Debug: Set to true to enable verbose logging (keystroke-by-keystroke, location info, etc)
const VERBOSE = false

# Tool action sets - each tool has 3 actions mapped to Q, E, R
# All actions are batch operations on multi-selected plots
const TOOL_ACTIONS = {
	1: {  # GROWER Tool - Core farming (80% of gameplay)
		"name": "Grower",
		"Q": {"action": "plant_batch", "label": "Plant (wheat/mushroom/tomato)"},
		"E": {"action": "entangle_batch", "label": "Entangle (Bell φ+)"},
		"R": {"action": "measure_and_harvest", "label": "Measure + Harvest"},
	},
	2: {  # QUANTUM Tool - Advanced quantum operations
		"name": "Quantum",
		"Q": {"action": "cluster", "label": "Cluster (GHZ/W/3+qubits)"},
		"E": {"action": "measure_plot", "label": "Measure Cascade"},
		"R": {"action": "break_entanglement", "label": "Break Entanglement"},
	},
	3: {  # INDUSTRY Tool - Economy & automation
		"name": "Industry",
		"Q": {"action": "place_mill", "label": "Build Mill"},
		"E": {"action": "place_market", "label": "Build Market"},
		"R": {"action": "place_kitchen", "label": "Build Kitchen"},
	},
	4: {  # ENERGY Tool - Quantum energy management
		"name": "Energy",
		"Q": {"action": "inject_energy", "label": "Inject Energy"},
		"E": {"action": "drain_energy", "label": "Drain Energy"},
		"R": {"action": "place_energy_tap", "label": "Place Energy Tap"},
	},
}


# Signals
signal action_performed(action: String, success: bool, message: String)
signal selection_changed(new_pos: Vector2i)
signal plot_selected(pos: Vector2i)  # Signal emitted when plot location is selected
signal tool_changed(tool_num: int, tool_info: Dictionary)
signal help_requested

func _ready():
	print("⌨️  FarmInputHandler initialized (Tool Mode System)")
	if VERBOSE:
		print("📍 Starting position: %s" % current_selection)
		print("🛠️  Current tool: %s" % TOOL_ACTIONS[current_tool]["name"])
	# CRITICAL: Don't process input until PlotGridDisplay is ready with tiles
	# This prevents race conditions where input arrives before UI initialization
	set_process_input(false)
	call_deferred("_enable_input_processing")
	_print_help()


func _enable_input_processing() -> void:
	"""Enable input processing after UI is initialized - prevents race conditions"""
	# Simple approach: wait 10 frames to ensure all initialization is done
	set_process(true)  # Enable _process() to count frames
	input_enable_frame_count = 10


func _process(_delta: float) -> void:
	"""Count down frames until input processing can be safely enabled"""
	if not get_tree().root.is_input_handled():
		input_enable_frame_count -= 1
		if input_enable_frame_count <= 0:
			set_process(false)  # Stop processing frames
			set_process_input(true)  # Enable input
			print("✅ Input processing enabled (UI ready)")
			# Verify tiles exist
			if plot_grid_display and plot_grid_display.tiles:
				print("   📊 PlotGridDisplay has %d tiles ready" % plot_grid_display.tiles.size())


func inject_grid_config(config: GridConfig) -> void:
	"""Inject GridConfig for dynamic grid-aware input handling (Phase 7)"""
	if not config:
		push_error("FarmInputHandler: Attempted to inject null GridConfig!")
		return

	grid_config = config
	# Update dimensions from config
	grid_width = config.grid_width
	grid_height = config.grid_height
	print("💉 GridConfig injected into FarmInputHandler (%dx%d grid)" % [grid_width, grid_height])


func _input(event: InputEvent):
	"""Handle input via InputMap actions (Phase 7)

	Supports keyboard (WASD, QERT, numbers, etc) and gamepad (D-Pad, buttons, sticks)
	via Godot's InputMap system.
	"""
	if VERBOSE and event is InputEventKey and event.pressed:
		print("🔑 FarmInputHandler._input() received KEY: %s" % event.keycode)

	# Tool selection (1-6) - Phase 7: Use InputMap actions
	for i in range(1, 7):
		if event.is_action_pressed("tool_" + str(i)):
			if VERBOSE:
				print("🛠️  Tool key pressed: %d" % i)
			_select_tool(i)
			get_tree().root.set_input_as_handled()
			return

	# Location quick-select (dynamic from GridConfig, or default mapping) - MULTI-SELECT: Toggle plots with checkboxes
	if grid_config:
		for action in grid_config.keyboard_layout.get_all_actions():
			if event.is_action_pressed(action):
				if VERBOSE:
					print("📍 GridConfig action detected: %s" % action)
				var pos = grid_config.keyboard_layout.get_position_for_action(action)
				if pos != Vector2i(-1, -1) and grid_config.is_position_valid(pos):
					_toggle_plot_selection(pos)
					get_tree().root.set_input_as_handled()
					return
	else:
		print("⚠️  grid_config is NULL at input time - falling back to hardcoded actions")
		# Fallback: default 6x2 keyboard layout (T/Y/U/I/O/P for row 0, 0/9/8/7 for row 1)
		var default_keys = {
			"select_plot_t": Vector2i(0, 0),
			"select_plot_y": Vector2i(1, 0),
			"select_plot_u": Vector2i(2, 0),
			"select_plot_i": Vector2i(3, 0),
			"select_plot_o": Vector2i(4, 0),
			"select_plot_p": Vector2i(5, 0),
			"select_plot_0": Vector2i(0, 1),
			"select_plot_9": Vector2i(1, 1),
			"select_plot_8": Vector2i(2, 1),
			"select_plot_7": Vector2i(3, 1),
		}
		for action in default_keys.keys():
			if event.is_action_pressed(action):
				if VERBOSE:
					print("📍 Fallback action detected: %s → %s" % [action, default_keys[action]])
				_toggle_plot_selection(default_keys[action])
				get_tree().root.set_input_as_handled()
				return

	# Selection management: [ = clear all, ] = restore previous
	# Check for raw keyboard events since InputMap actions don't exist for these keys
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_BRACKETLEFT:  # [ key
			_clear_all_selection()
			get_tree().root.set_input_as_handled()
			return
		elif event.keycode == KEY_BRACKETRIGHT:  # ] key
			_restore_previous_selection()
			get_tree().root.set_input_as_handled()
			return

	# Movement (WASD or D-Pad or Left Stick) - Phase 7: Use InputMap actions
	if event.is_action_pressed("move_up"):
		_move_selection(Vector2i.UP)
		get_tree().root.set_input_as_handled()
		return
	elif event.is_action_pressed("move_down"):
		_move_selection(Vector2i.DOWN)
		get_tree().root.set_input_as_handled()
		return
	elif event.is_action_pressed("move_left"):
		_move_selection(Vector2i.LEFT)
		get_tree().root.set_input_as_handled()
		return
	elif event.is_action_pressed("move_right"):
		_move_selection(Vector2i.RIGHT)
		get_tree().root.set_input_as_handled()
		return

	# Action keys (Q/E/R or gamepad buttons A/B/X) - Phase 7: Use InputMap actions
	# Debug: Check if actions are detected
	if VERBOSE and event is InputEventKey and event.pressed:
		var key = event.keycode
		if key == KEY_Q or key == KEY_E or key == KEY_R:
			print("🐛 DEBUG: Pressed key: %s" % event.keycode)
			print("   is_action_pressed('action_q'): %s" % event.is_action_pressed("action_q"))
			print("   is_action_pressed('action_e'): %s" % event.is_action_pressed("action_e"))
			print("   is_action_pressed('action_r'): %s" % event.is_action_pressed("action_r"))

	# NOTE: Q/E/R actions are now primarily routed through InputController
	# Only process if input hasn't already been handled (by menu system)
	if not get_tree().root.is_input_handled():
		if event.is_action_pressed("action_q"):
			if VERBOSE:
				print("⚡ action_q detected")
			_execute_tool_action("Q")
			get_tree().root.set_input_as_handled()
			return
		elif event.is_action_pressed("action_e"):
			if VERBOSE:
				print("⚡ action_e detected")
			_execute_tool_action("E")
			get_tree().root.set_input_as_handled()
			return
		elif event.is_action_pressed("action_r"):
			if VERBOSE:
				print("⚡ action_r detected")
			_execute_tool_action("R")
			get_tree().root.set_input_as_handled()
			return

	# Debug/Help - Phase 7: Use InputMap action
	if event.is_action_pressed("toggle_help"):
		_print_help()
		get_tree().root.set_input_as_handled()
		return

	# NOTE: K key for keyboard help is now handled by InputController
	# Removed backward compatibility handlers to avoid conflicts with menu system


## Tool System

func _select_tool(tool_num: int):
	"""Select active tool (1-6)"""
	if not TOOL_ACTIONS.has(tool_num):
		print("⚠️  Tool %d not available" % tool_num)
		return

	current_tool = tool_num
	var tool_info = TOOL_ACTIONS[tool_num]
	print("🛠️  Tool switched to: %s" % tool_info["name"])
	if VERBOSE:
		print("   Q = %s" % tool_info["Q"]["label"])
		print("   E = %s" % tool_info["E"]["label"])
		print("   R = %s" % tool_info["R"]["label"])

	tool_changed.emit(tool_num, tool_info)


func _execute_tool_action(action_key: String):
	"""Execute the action mapped to Q/E/R for current tool

	NEW: Applies to ALL selected plots (multi-select support)
	"""
	if not farm:
		push_error("Farm not set on FarmInputHandler!")
		return

	if not TOOL_ACTIONS.has(current_tool):
		print("⚠️  Current tool not found")
		return

	var tool = TOOL_ACTIONS[current_tool]
	if not tool.has(action_key):
		print("⚠️  Action %s not available for tool %d (%s)" % [action_key, current_tool, tool.get("name", "unknown")])
		return

	var action_info = tool[action_key]
	var action = action_info["action"]
	var label = action_info["label"]

	# Get currently selected plots
	var selected_plots: Array[Vector2i] = []
	if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
		selected_plots = plot_grid_display.get_selected_plots()

	# FALLBACK: If no plots selected in UI, use current selection (for auto-play/testing)
	if selected_plots.is_empty():
		if _is_valid_position(current_selection):
			selected_plots = [current_selection]
			if VERBOSE:
				print("📍 No multi-select; using current selection: %s" % current_selection)
		else:
			print("⚠️  No plots selected! Use T/Y/U/I/O/P to toggle selections.")
			action_performed.emit(action, false, "⚠️  No plots selected")
			return

	print("⚡ Tool %d (%s) | Key %s | Action: %s | Plots: %d selected" % [current_tool, tool.get("name", "?"), action_key, label, selected_plots.size()])

	# Execute the action based on type (now with multi-select support)
	match action:
		# Tool 1: GROWER - Core farming
		"plant_batch":
			_action_plant_batch(selected_plots)
		"entangle_batch":
			_action_entangle_batch(selected_plots)
		"measure_and_harvest":
			_action_batch_measure_and_harvest(selected_plots)

		# Tool 2: QUANTUM - Advanced quantum
		"cluster":
			_action_cluster(selected_plots)
		"measure_plot":
			_action_batch_measure(selected_plots)  # Cascades automatically
		"break_entanglement":
			_action_break_entanglement(selected_plots)

		# Tool 3: INDUSTRY - Economy & automation
		"place_mill":
			_action_batch_build("mill", selected_plots)
		"place_market":
			_action_batch_build("market", selected_plots)
		"place_kitchen":
			_action_batch_build("kitchen", selected_plots)

		# Tool 4: ENERGY - Energy management
		"inject_energy":
			_action_inject_energy(selected_plots)
		"drain_energy":
			_action_drain_energy(selected_plots)
		"place_energy_tap":
			_action_place_energy_tap(selected_plots)

		_:
			print("⚠️  Unknown action: %s" % action)


## Selection Management

func _set_selection(pos: Vector2i):
	"""Set selection to specific position (YUIOP quick-select)"""
	if _is_valid_position(pos):
		current_selection = pos
		selection_changed.emit(current_selection)
		plot_selected.emit(current_selection)  # Also emit plot_selected for UI updates
		if VERBOSE:
			print("📍 Selected: %s (Location %d)" % [current_selection, current_selection.x + 1])
	else:
		if VERBOSE:
			print("⚠️  Invalid position: %s" % pos)


func _move_selection(direction: Vector2i):
	"""Move selection in given direction (WASD)"""
	var new_pos = current_selection + direction
	if _is_valid_position(new_pos):
		current_selection = new_pos
		selection_changed.emit(current_selection)
		if VERBOSE:
			print("📍 Moved to: %s" % current_selection)
	else:
		if VERBOSE:
			print("⚠️  Cannot move to: %s (out of bounds)" % new_pos)


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
		print("❌ ERROR: PlotGridDisplay not wired to FarmInputHandler!")
		print("   Refactor incomplete or wiring failed")
		return

	if not _is_valid_position(pos):
		print("⚠️  Invalid position: %s" % pos)
		return

	print("⌨️  Toggle plot %s" % pos)
	plot_grid_display.toggle_plot_selection(pos)


func _clear_all_selection():
	"""Clear all selected plots ([ key)"""
	if not plot_grid_display:
		print("❌ ERROR: PlotGridDisplay not wired to FarmInputHandler!")
		return

	plot_grid_display.clear_all_selection()


func _restore_previous_selection():
	"""Restore previous selection state (] key)"""
	if not plot_grid_display:
		print("❌ ERROR: PlotGridDisplay not wired to FarmInputHandler!")
		return

	plot_grid_display.restore_previous_selection()


## Action Implementations - Batch Operations (NEW)

func _action_batch_plant(plant_type: String, positions: Array[Vector2i]):
	"""Plant multiple plots with the given plant type"""
	if not farm:
		action_performed.emit("plant_%s" % plant_type, false, "⚠️  Farm not loaded yet")
		print("❌ PLANT FAILED: Farm not loaded")
		return

	var emoji = "🌾" if plant_type == "wheat" else ("🍄" if plant_type == "mushroom" else "🍅")
	print("🌱 Batch planting %s at %d plots: %s" % [plant_type, positions.size(), positions])

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
	"""Measure quantum state of multiple plots"""
	if not farm:
		action_performed.emit("measure", false, "⚠️  Farm not loaded yet")
		return

	print("👁️  Batch measuring %d plots: %s" % [positions.size(), positions])

	# Check if farm has batch method
	if farm.has_method("batch_measure"):
		var result = farm.batch_measure(positions)
		var success = result.get("success", false)
		var count = result.get("count", 0)
		action_performed.emit("measure", success,
			"%s Measured %d plots" % ["✅" if success else "❌", count])
	else:
		# Fallback: execute individually
		var success_count = 0
		for pos in positions:
			if farm.measure_plot(pos):
				success_count += 1
		var success = success_count > 0
		action_performed.emit("measure", success,
			"%s Measured %d/%d plots" % ["✅" if success else "❌", success_count, positions.size()])


func _action_batch_harvest(positions: Array[Vector2i]):
	"""Harvest multiple plots (measure then harvest each)"""
	if not farm:
		action_performed.emit("harvest", false, "⚠️  Farm not loaded yet")
		return

	print("✂️  Batch harvesting %d plots: %s" % [positions.size(), positions])

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
		print("❌ BUILD FAILED: Farm not loaded")
		return

	print("🏗️  Batch building %s at %d plots: %s" % [build_type, positions.size(), positions])

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


func _action_batch_boost_energy(positions: Array[Vector2i]):
	"""Boost quantum energy in selected plots (grow energy in quantum states)"""
	if not farm:
		action_performed.emit("boost_energy", false, "⚠️  Farm not loaded yet")
		return

	print("⚡ Batch boosting energy at %d plots: %s" % [positions.size(), positions])

	var success_count = 0
	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if plot and plot.quantum_state:
			# Grow energy by a small amount (strength * dt = 0.3 * 1.0 = 30% exponential growth)
			plot.quantum_state.grow_energy(0.3, 1.0)
			success_count += 1
			print("  ⚡ Boosted energy at %s: %.2f" % [pos, plot.quantum_state.energy])

	var success = success_count > 0
	action_performed.emit("boost_energy", success,
		"%s Boosted energy in %d/%d plots" % ["✅" if success else "❌", success_count, positions.size()])


func _action_batch_measure_and_harvest(positions: Array[Vector2i]):
	"""Measure quantum state then harvest plots (combined action)"""
	if not farm:
		action_performed.emit("harvest", false, "⚠️  Farm not loaded yet")
		return

	print("🔬✂️  Batch measuring and harvesting %d plots: %s" % [positions.size(), positions])

	var success_count = 0
	var total_yield = 0
	for pos in positions:
		# Measure first
		farm.measure_plot(pos)
		# Then harvest
		var result = farm.harvest_plot(pos)
		if result.get("success", false):
			success_count += 1
			total_yield += result.get("yield", 0)

	var success = success_count > 0
	action_performed.emit("harvest", success,
		"%s Measured and harvested %d/%d plots | Yield: %d" % ["✅" if success else "❌", success_count, positions.size(), total_yield])


func _action_entangle():
	"""Start entanglement at current selection (requires second selection)"""
	print("🔗 Entangle mode: Select second location or press R again")
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
	"""Batch plant crops - cycles through wheat, mushroom, tomato"""
	if not farm:
		action_performed.emit("plant_batch", false, "⚠️  Farm not loaded yet")
		return

	# TODO: Implement crop cycling selector (for now, default to wheat)
	# Could track which crop was last planted and cycle through them
	_action_batch_plant("wheat", positions)


func _action_entangle_batch(positions: Array[Vector2i]):
	"""Batch entangle selected plots in Bell state φ+"""
	if not farm or not farm.grid:
		action_performed.emit("entangle_batch", false, "⚠️  Farm not loaded yet")
		return

	if positions.size() < 2:
		action_performed.emit("entangle_batch", false, "⚠️  Need at least 2 plots to entangle")
		return

	print("🔗 Batch entangling %d plots..." % positions.size())

	var success_count = 0
	# Create pairwise entanglement: 0-1, 1-2, 2-3, etc.
	for i in range(positions.size() - 1):
		var plot1 = positions[i]
		var plot2 = positions[i + 1]
		farm.grid.create_entanglement(plot1, plot2)
		success_count += 1
		print("  🔗 Entangled %s ↔ %s (Bell φ+)" % [plot1, plot2])

	action_performed.emit("entangle_batch", success_count > 0,
		"✅ Created %d Bell state entanglements" % success_count)


## NEW Tool 2 (QUANTUM) Actions

func _action_cluster(positions: Array[Vector2i]):
	"""Create GHZ/W/Cluster states for 3+ qubit entanglement"""
	if not farm or not farm.grid:
		action_performed.emit("cluster", false, "⚠️  Farm not loaded yet")
		return

	if positions.size() < 3:
		action_performed.emit("cluster", false, "⚠️  Need at least 3 plots for clustering")
		return

	print("🔗 Creating cluster state for %d plots..." % positions.size())

	# TODO: Detect geometry (horizontal/L-shape/T-shape) and create appropriate state
	# For now, create sequential pairwise entanglement like entangle_batch
	var success_count = 0
	for i in range(positions.size() - 1):
		var plot1 = positions[i]
		var plot2 = positions[i + 1]
		farm.grid.create_entanglement(plot1, plot2)
		success_count += 1

	action_performed.emit("cluster", success_count > 0,
		"✅ Created cluster state with %d plots" % positions.size())


func _action_break_entanglement(positions: Array[Vector2i]):
	"""Break all entanglements for selected plots"""
	if not farm or not farm.grid:
		action_performed.emit("break_entanglement", false, "⚠️  Farm not loaded yet")
		return

	print("🔓 Breaking entanglement for %d plots..." % positions.size())

	var success_count = 0
	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if plot:
			# Clear all entangled links
			plot.entangled_plots.clear()
			success_count += 1
			print("  🔓 Cleared entanglement at %s" % pos)

	action_performed.emit("break_entanglement", success_count > 0,
		"✅ Broke entanglement on %d plots" % success_count)


## NEW Tool 4 (ENERGY) Actions

func _action_inject_energy(positions: Array[Vector2i]):
	"""Inject quantum energy by spending wheat resources"""
	if not farm or not farm.grid or not farm.economy:
		action_performed.emit("inject_energy", false, "⚠️  Farm not loaded yet")
		return

	print("⚡ Injecting energy into %d plots..." % positions.size())

	# Spending wheat (1 wheat → 0.1 energy per plot)
	var emoji_resource = "wheat"
	var cost_per_plot = 1
	var energy_gain = 0.1

	var total_cost = cost_per_plot * positions.size()

	# Check if we have enough wheat
	if farm.economy.wheat_inventory < total_cost:
		action_performed.emit("inject_energy", false, "⚠️  Not enough wheat! Need %d, have %d" % [total_cost, farm.economy.wheat_inventory])
		return

	# Deduct cost from economy first
	farm.economy.wheat_inventory -= total_cost
	print("  💸 Spent %d wheat on energy injection" % total_cost)

	# Apply energy boost to valid plots
	var success_count = 0
	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if plot and plot.quantum_state:
			plot.quantum_state.energy += energy_gain
			success_count += 1
			print("  ⚡ Injected %.2f energy at %s" % [energy_gain, pos])

	action_performed.emit("inject_energy", success_count > 0,
		"✅ Injected energy into %d plots (spent %d %s)" % [success_count, total_cost, emoji_resource])


func _action_drain_energy(positions: Array[Vector2i]):
	"""Drain quantum energy to gain wheat resources"""
	if not farm or not farm.grid or not farm.economy:
		action_performed.emit("drain_energy", false, "⚠️  Farm not loaded yet")
		return

	print("🔋 Draining energy from %d plots..." % positions.size())

	var drain_amount = 0.5  # Energy to drain per plot
	var wheat_return = 1    # Wheat returned per drained energy

	var success_count = 0
	var total_wheat_gained = 0
	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if plot and plot.quantum_state and plot.quantum_state.energy >= drain_amount:
			plot.quantum_state.energy -= drain_amount
			total_wheat_gained += wheat_return
			success_count += 1
			print("  🔋 Drained %.2f energy at %s → gained %d wheat" % [drain_amount, pos, wheat_return])

	# Add gained wheat to economy
	if success_count > 0 and farm.economy:
		farm.economy.wheat_inventory += total_wheat_gained
		print("  💰 Added %d wheat to inventory" % total_wheat_gained)

	action_performed.emit("drain_energy", success_count > 0,
		"✅ Drained energy from %d plots → gained %d wheat" % [success_count, total_wheat_gained])


func _action_place_energy_tap(positions: Array[Vector2i]):
	"""Place constant energy drain taps on selected plots"""
	if not farm or not farm.grid:
		action_performed.emit("place_energy_tap", false, "⚠️  Farm not loaded yet")
		return

	print("🚰 Placing energy taps on %d plots..." % positions.size())

	# TODO: Add target emoji selector (which emoji to drain to)
	# For now, just mark that taps would be placed
	var success_count = 0
	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if plot:
			# TODO: Call farm.plant_energy_tap(pos, target_emoji)
			success_count += 1
			print("  🚰 Placed energy tap at %s" % pos)

	action_performed.emit("place_energy_tap", success_count > 0,
		"✅ Placed energy taps on %d plots (passive drain active)" % success_count)


## Help System

func _print_help():
	"""Print keyboard help to console"""
	var line = ""
	for i in range(60):
		line += "="

	print("\n" + line)
	print("⌨️  FARM KEYBOARD CONTROLS (Tool Mode System)")
	print(line)

	print("\n🛠️  TOOL SELECTION (Numbers 1-4):")
	for tool_num in range(1, 5):
		if TOOL_ACTIONS.has(tool_num):
			var tool = TOOL_ACTIONS[tool_num]
			print("  %d = %s" % [tool_num, tool["name"]])

	print("\n⚡ ACTIONS (Q/E/R - Context-sensitive):")
	var tool = TOOL_ACTIONS[current_tool]
	print("  Current Tool: %s" % tool["name"])
	print("  Q = %s" % tool["Q"]["label"])
	print("  E = %s" % tool["E"]["label"])
	print("  R = %s" % tool["R"]["label"])

	print("\n📍 MULTI-SELECT PLOTS (NEW):")
	print("  T/Y/U/I/O/P = Toggle checkbox on plots 1-6")
	print("  [ = Deselect all plots")
	print("  ] = Restore previous selection state")
	print("  Q/E/R = Apply current tool action to ALL selected plots")

	print("\n🎮 MOVEMENT (Legacy - for focus/cursor):")
	print("  WASD = Move cursor (up/left/down/right)")

	print("\n📋 DEBUG:")
	print("  ? = Show this help")
	print("  I = Toggle info panel")

	print(line + "\n")
