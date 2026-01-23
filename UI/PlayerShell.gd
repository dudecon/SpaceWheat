## PlayerShell - Player-level UI layer
## Handles:
## - Overlay/menu system (ESC menu, V vocabulary, C contracts, etc)
## - Player inventory/resource panel
## - Keyboard help, settings
## - Farm loading/switching (when implemented)
##
## This layer STAYS when farm changes

class_name PlayerShell
extends Control

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = get_node("/root/VerboseConfig")

const OverlayManager = preload("res://UI/Managers/OverlayManager.gd")
const OverlayStackManager = preload("res://UI/Managers/OverlayStackManager.gd")
const QuestManager = preload("res://Core/Quests/QuestManager.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const LoggerConfigPanel = preload("res://UI/Panels/LoggerConfigPanel.gd")
# QuantumHUDPanel REMOVED - content merged into InspectorOverlay (N key)
const QuantumModeStatusIndicator = preload("res://UI/Panels/QuantumModeStatusIndicator.gd")
const BiomeTabBarClass = preload("res://UI/BiomeTabBar.gd")

## Key-to-overlay mapping (DRY - single source of truth for toggle keys)
const KEY_TO_OVERLAY = {
	KEY_C: "quests",
	KEY_V: "semantic_map",
	KEY_B: "biome_detail",
	KEY_N: "inspector",
	KEY_K: "controls",
}

var current_farm_ui = null  # FarmUI instance (from scene)
var overlay_manager: OverlayManager = null
var quest_manager: QuestManager = null
var farm: Node = null
var farm_ui_container: Control = null
var action_bar_manager = null  # ActionBarManager - manages bottom toolbars
var action_preview_row: Control = null  # Cached reference from ActionBarManager
var logger_config_panel: LoggerConfigPanel = null  # Logger configuration UI
# quantum_hud_panel REMOVED - content merged into InspectorOverlay (N key)
var quantum_mode_indicator: QuantumModeStatusIndicator = null  # Current quantum mode display
var biome_tab_bar: BiomeTabBarClass = null  # Top bar for biome selection

## Unified Overlay Stack Management (replaces modal_stack)
var overlay_stack: OverlayStackManager = null


func _input(event: InputEvent) -> void:
	"""Layer 1: High-priority input routing (overlays + shell actions)"""
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	var stack_size = overlay_stack.size() if overlay_stack else 0
	_verbose.debug("input", "⌨️", "PlayerShell._input() KEY: %s, overlay_stack: %d" % [event.keycode, stack_size])

	# LAYER 1: Overlay input (highest priority) - uses unified OverlayStackManager
	if overlay_stack and not overlay_stack.is_empty():
		var top_overlay = overlay_stack.get_top()
		_verbose.debug("input", "→", "Routing to overlay: %s" % top_overlay.name)
		var consumed = overlay_stack.route_input(event)
		_verbose.debug("input", "→", "Overlay consumed: %s" % consumed)
		if consumed:
			get_viewport().set_input_as_handled()
			return

	# LAYER 2: Shell actions
	if _handle_shell_action(event):
		get_viewport().set_input_as_handled()
		return

	# LAYER 3: Fall through to Farm._unhandled_input()


func _handle_shell_action(event: InputEvent) -> bool:
	"""Handle shell-level actions (overlay toggles, menu)

	Toggle keys (C/V/B/N/K): Open overlay if closed, close if same key pressed again.
	ESC: Closes any open overlay, or opens escape menu if nothing is open.
	L: Logger config (only when no overlay active).
	TAB: Build/Play mode toggle (only when no overlay active).
	"""
	# ESC has special handling - closes overlay OR opens escape menu
	if event.keycode == KEY_ESCAPE:
		if overlay_stack and not overlay_stack.is_empty():
			overlay_stack.handle_escape()
			return true
		else:
			_toggle_escape_menu()
			return true

	# Toggle keys (C/V/B/N/K) - work whether overlay is open or not
	# This enables same-key-to-close: press B to open biome, press B again to close
	if KEY_TO_OVERLAY.has(event.keycode):
		_toggle_v2_overlay(KEY_TO_OVERLAY[event.keycode])
		return true

	# Other keys only work when no overlay is active
	if overlay_stack and not overlay_stack.is_empty():
		return false

	# Remaining shell keys (L, TAB)
	match event.keycode:
		KEY_L:
			_toggle_logger_config()
			return true
		KEY_TAB:
			# TAB must be handled here (in _input) because Godot's focus system
			# intercepts TAB before _unhandled_input() runs
			_toggle_build_play_mode()
			return true

	return false


func _toggle_v2_overlay(overlay_name: String) -> void:
	"""Toggle a v2 overlay by name"""
	if overlay_manager:
		overlay_manager.toggle_v2_overlay(overlay_name)


func _toggle_quest_board() -> void:
	"""Toggle quest board - pass biome via parameter"""
	_verbose.debug("ui", "🎯", "_toggle_quest_board() called")
	if not overlay_manager:
		_verbose.warn("ui", "❌", "overlay_manager is null!")
		return
	if not overlay_manager.quest_board:
		_verbose.warn("ui", "❌", "quest_board is null!")
		return
	var quest_board = overlay_manager.quest_board
	if quest_board.visible:
		_verbose.info("ui", "→", "Closing quest board")
		quest_board.close_board()
		_pop_modal(quest_board)
	else:
		_verbose.info("ui", "→", "Opening quest board")
		var biome = null
		if farm and "biotic_flux_biome" in farm:
			biome = farm.biotic_flux_biome
		_verbose.debug("ui", "→", "farm: %s" % farm)
		_verbose.debug("ui", "→", "biome: %s" % biome)
		if biome:
			quest_board.set_biome(biome)
			quest_board.open_board()
			_push_modal(quest_board)
			_verbose.info("ui", "✅", "Quest board opened")
		else:
			_verbose.warn("ui", "❌", "No biome available!")


# _toggle_keyboard_help() REMOVED - K key now uses v2 overlay: _toggle_v2_overlay("controls")


func _toggle_logger_config() -> void:
	"""Toggle logger configuration panel"""
	if not logger_config_panel:
		return
	if logger_config_panel.visible:
		logger_config_panel.hide_panel()
		_pop_modal(logger_config_panel)
	else:
		logger_config_panel.show_panel()
		_push_modal(logger_config_panel)


func _toggle_escape_menu() -> void:
	"""Toggle escape menu"""
	if not overlay_manager or not overlay_manager.escape_menu:
		return
	var menu = overlay_manager.escape_menu
	if menu.visible:
		menu.hide()
		_pop_modal(menu)
	else:
		menu.show()
		_push_modal(menu)


func _toggle_build_play_mode() -> void:
	"""Toggle between BUILD and PLAY modes (TAB key)

	This is handled here (in _input) because Godot's focus navigation
	intercepts TAB before _unhandled_input() runs.
	"""
	const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

	var new_mode = ToolConfig.toggle_mode()
	_verbose.info("input", "🔧" if new_mode == "build" else "🎮",
		"Switched to %s MODE (Tab to toggle)" % new_mode.to_upper())

	# Update ToolSelectionRow UI
	if action_bar_manager:
		var tool_row = action_bar_manager.get_tool_row()
		if tool_row and tool_row.has_method("refresh_for_mode"):
			tool_row.refresh_for_mode(new_mode)

	# Notify FarmInputHandler (if available)
	# Find FarmInputHandler in FarmUIContainer
	if farm_ui_container:
		var farm_view = farm_ui_container.get_node_or_null("FarmUI")
		if farm_view:
			for child in farm_view.get_children():
				if child.has_method("on_mode_changed"):
					child.on_mode_changed(new_mode)
					break


func _push_modal(modal: Control) -> void:
	"""Add modal/overlay to stack"""
	if overlay_stack and not overlay_stack.has_overlay(modal):
		overlay_stack.push(modal)
		_verbose.debug("input", "📚", "Overlay stack: %s" % overlay_stack.get_stack_info())


func _pop_modal(modal: Control) -> void:
	"""Remove modal/overlay from stack"""
	if overlay_stack:
		overlay_stack.pop_overlay(modal)
		_verbose.debug("input", "📚", "Overlay stack: %s" % overlay_stack.get_stack_info())


func _ready() -> void:
	"""Initialize player shell UI - children defined in scene"""
	_verbose.info("boot", "🎪", "PlayerShell initializing...")

	# Add to group so overlay buttons can find us
	add_to_group("player_shell")

	# CRITICAL: Ensure PlayerShell fills its parent (FarmView)
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Process input even when game is paused (for ESC menu, etc.)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create unified overlay stack manager (before any overlays)
	overlay_stack = OverlayStackManager.new()
	add_child(overlay_stack)
	_verbose.info("ui", "✅", "OverlayStackManager created")

	# Get reference to containers from scene
	farm_ui_container = get_node("FarmUIContainer")
	var overlay_layer = get_node("OverlayLayer")
	var action_bar_layer = get_node("ActionBarLayer")

	# CRITICAL: FarmUIContainer must pass input through to PlotGridDisplay/QuantumForceGraph
	farm_ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_verbose.info("ui", "✅", "FarmUIContainer mouse_filter set to IGNORE for plot/bubble input")

	# CRITICAL: ActionBarLayer needs explicit size for ActionBarManager to work
	# It has full anchors (0,0,1,1) which will maintain this size, but during _ready()
	# the anchors haven't taken effect yet. Set size to viewport size (what anchors will do).
	# Use set_deferred to avoid warning about opposite anchors.
	var viewport_size = get_viewport_rect().size
	action_bar_layer.set_deferred("size", viewport_size)
	_verbose.info("ui", "✅", "ActionBarLayer sized for action bar creation: %.0f × %.0f" % [viewport_size.x, viewport_size.y])

	# Create and initialize UILayoutManager
	const UILayoutManager = preload("res://UI/Managers/UILayoutManager.gd")
	var layout_manager = UILayoutManager.new()
	add_child(layout_manager)

	# Create quest manager (before overlays, since overlays need it)
	quest_manager = QuestManager.new()
	add_child(quest_manager)
	_verbose.info("ui", "✅", "Quest manager created")

	# ═══════════════════════════════════════════════════════════════
	# CREATE ACTION BARS DIRECTLY IN ActionBarLayer
	# ═══════════════════════════════════════════════════════════════
	const ActionBarManager = preload("res://UI/Managers/ActionBarManager.gd")
	action_bar_manager = ActionBarManager.new()
	action_bar_manager.create_action_bars(action_bar_layer)

	# Store reference for quest board updates
	action_preview_row = action_bar_manager.get_action_row()

	# Connect tool selection signal
	var tool_row = action_bar_manager.get_tool_row()
	if tool_row and tool_row.has_signal("tool_selected"):
		tool_row.tool_selected.connect(_on_tool_selected_from_bar)

	# Connect action button signal - will be connected to FarmInputHandler later
	# (after farm setup completes and input_handler is available)

	_verbose.info("ui", "✅", "Action bars created")
	# ═══════════════════════════════════════════════════════════════

	# Create overlay manager and add to overlay layer
	overlay_manager = OverlayManager.new()
	overlay_layer.add_child(overlay_manager)

	# Setup overlay manager with proper dependencies
	overlay_manager.setup(layout_manager, null, null, null, quest_manager)

	# Connect overlay stack and overlay manager bidirectionally
	if overlay_stack:
		overlay_stack.set_overlay_manager(overlay_manager)
		overlay_manager.set_overlay_stack(overlay_stack)

	# Initialize overlays (C/V/N/K/ESC menus)
	overlay_manager.create_overlays(overlay_layer)

	# Create logger config panel (debug tool, press L to toggle)
	logger_config_panel = LoggerConfigPanel.new()
	overlay_layer.add_child(logger_config_panel)
	logger_config_panel.closed.connect(func():
		_pop_modal(logger_config_panel)
	)
	_verbose.info("ui", "✅", "Logger config panel created (press L to toggle)")

	# QuantumHUDPanel REMOVED - content merged into InspectorOverlay (N key)

	# Create quantum mode status indicator (top-right corner)
	quantum_mode_indicator = QuantumModeStatusIndicator.new()
	quantum_mode_indicator.name = "QuantumModeIndicator"
	overlay_layer.add_child(quantum_mode_indicator)
	# Position in top-right, below the ResourcePanel
	quantum_mode_indicator.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quantum_mode_indicator.position = Vector2(-200, 54)  # Below 50px resource panel
	_verbose.info("ui", "✅", "Quantum mode indicator created")

	# Create biome tab bar (top-center for biome selection)
	biome_tab_bar = BiomeTabBarClass.new()
	biome_tab_bar.name = "BiomeTabBar"
	overlay_layer.add_child(biome_tab_bar)
	# Position at top-center, below the ResourcePanel (50px min height + 4px gap)
	biome_tab_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	biome_tab_bar.offset_top = 54  # Below 50px resource panel + 4px gap
	biome_tab_bar.offset_bottom = 94  # 40px height
	biome_tab_bar.offset_left = 200  # Leave room for any left-side UI
	biome_tab_bar.offset_right = -200  # Leave room for quantum mode indicator
	_verbose.info("ui", "✅", "Biome tab bar created")

	# Connect overlay signals
	_connect_overlay_signals()

	_verbose.info("ui", "✅", "Overlay manager created")
	_verbose.info("boot", "✅", "PlayerShell ready")


func _connect_overlay_signals() -> void:
	"""Connect signals from overlays to manage unified overlay stack.

	Note: _push_modal() and _pop_modal() delegate to OverlayStackManager.
	These signal handlers keep overlays synchronized with the stack.
	"""
	if overlay_manager.quest_board:
		overlay_manager.quest_board.board_closed.connect(func():
			_pop_modal(overlay_manager.quest_board)
			_restore_action_toolbar()
		)
		overlay_manager.quest_board.board_opened.connect(func():
			_update_action_toolbar_for_quest()
		)
		overlay_manager.quest_board.selection_changed.connect(func(slot_state: int, is_locked: bool):
			_update_action_toolbar_for_quest(slot_state, is_locked)
		)
		_verbose.info("ui", "✅", "Quest board signals connected")

	if overlay_manager.escape_menu:
		overlay_manager.escape_menu.resume_pressed.connect(func():
			_pop_modal(overlay_manager.escape_menu)
		)
		overlay_manager.escape_menu.save_pressed.connect(func():
			_push_modal(overlay_manager.save_load_menu)
		)
		overlay_manager.escape_menu.load_pressed.connect(func():
			_push_modal(overlay_manager.save_load_menu)
		)
		overlay_manager.escape_menu.quantum_settings_pressed.connect(func():
			_pop_modal(overlay_manager.escape_menu)
			if overlay_manager.quantum_config_ui:
				overlay_manager.toggle_quantum_config()
		)
		_verbose.info("ui", "✅", "Escape menu signals connected")

	if overlay_manager.save_load_menu:
		overlay_manager.save_load_menu.menu_closed.connect(func():
			_pop_modal(overlay_manager.save_load_menu)
		)
		_verbose.info("ui", "✅", "Save/Load menu signals connected")


func get_farm_ui():
	"""Get the currently loaded FarmUI instance"""
	return current_farm_ui


func load_farm_ui(farm_ui: Control) -> void:
	"""Load an already-instantiated FarmUI into the farm container.

	Called by BootManager.boot() in Stage 3C to add the FarmUI.
	Action bars are already created in _ready(), so no reparenting needed.
	"""
	# Store reference
	current_farm_ui = farm_ui

	# Add to container
	if farm_ui_container:
		farm_ui_container.add_child(farm_ui)
		_verbose.info("ui", "✔", "FarmUI mounted in container")

	# Note: farm_setup_complete fires before input_handler is created, so the actual
	# connection is done by BootManager calling connect_to_farm_input_handler() later.
	# We still connect here as a fallback in case input_handler is somehow ready early.
	if farm_ui.has_signal("farm_setup_complete"):
		farm_ui.farm_setup_complete.connect(connect_to_farm_input_handler)
		_verbose.info("ui", "⏳", "Will connect to input_handler when farm setup completes...")
	else:
		push_error("FarmUI missing farm_setup_complete signal!")

func connect_to_farm_input_handler() -> void:
	"""Connect to FarmInputHandler after it's created.

	Called by BootManager after input_handler is created and injected into farm_ui.
	Note: farm_setup_complete fires too early (before input_handler exists).
	"""
	var farm_ui = current_farm_ui
	if not farm_ui or not farm_ui.input_handler:
		push_warning("connect_to_farm_input_handler called but input_handler not ready!")
		return

	# Already connected? Skip
	if farm_ui.input_handler.tool_changed.get_connections().size() > 0:
		return

	# Connect quest_manager to economy (CRITICAL for quest completion!)
	if quest_manager and farm_ui.farm and farm_ui.farm.economy:
		quest_manager.connect_to_economy(farm_ui.farm.economy)
		_verbose.info("ui", "✅", "QuestManager connected to economy")

	if farm_ui and farm_ui.input_handler:
		# Connect input handler tool changes to action bar
		if farm_ui.input_handler.has_signal("tool_changed"):
			farm_ui.input_handler.tool_changed.connect(func(tool_num: int, _info: Dictionary):
				if action_bar_manager:
					action_bar_manager.select_tool(tool_num)
			)

		if farm_ui.input_handler.has_signal("submenu_changed"):
			farm_ui.input_handler.submenu_changed.connect(func(name: String, info: Dictionary):
				if action_bar_manager:
					action_bar_manager.update_for_submenu(name, info)
			)

		# CRITICAL: Connect ActionPreviewRow directly to FarmInputHandler
		# This makes touch and keyboard share the same code path
		if action_bar_manager:
			var action_row = action_bar_manager.get_action_row()
			if action_row and action_row.has_signal("action_pressed"):
				action_row.action_pressed.connect(farm_ui.input_handler._execute_tool_action)
				_verbose.info("ui", "✔", "ActionPreviewRow → FarmInputHandler (direct connection)")

				# Inject input_handler reference for action validation
				action_row.input_handler = farm_ui.input_handler
				_verbose.info("ui", "✔", "ActionPreviewRow validation dependencies injected")

		_verbose.info("ui", "✔", "Input handler connected to action bars")

		# Inject farm and plot_grid references into ActionPreviewRow for action availability
		if action_bar_manager and farm_ui.farm and farm_ui.plot_grid_display:
			action_bar_manager.inject_references(farm_ui.farm, farm_ui.plot_grid_display)

			# Connect to selection changes to update action button availability
			if farm_ui.plot_grid_display.has_signal("selection_count_changed"):
				farm_ui.plot_grid_display.selection_count_changed.connect(func(_count: int):
					var action_row = action_bar_manager.get_action_row()
					if action_row and action_row.has_method("update_action_availability"):
						action_row.update_action_availability()
				)
				_verbose.info("ui", "✔", "Action buttons will update on selection changes")

			# Connect to resource changes to update action button availability (for planting)
			if farm_ui.farm and farm_ui.farm.economy and farm_ui.farm.economy.has_signal("resource_changed"):
				farm_ui.farm.economy.resource_changed.connect(func(_emoji, _amount):
					var action_row = action_bar_manager.get_action_row()
					if action_row and action_row.has_method("update_action_availability"):
						action_row.update_action_availability()
				)
				_verbose.info("ui", "✔", "Action buttons will update on resource changes")

			# Connect to action_performed to refresh availability after EXPLORE/MEASURE/POP (Issue #2 fix)
			if farm_ui.input_handler and farm_ui.input_handler.has_signal("action_performed"):
				farm_ui.input_handler.action_performed.connect(func(_action, _success, _message):
					var action_row = action_bar_manager.get_action_row()
					if action_row and action_row.has_method("update_action_availability"):
						action_row.update_action_availability()
				)
				_verbose.info("ui", "✔", "Action buttons will update after action performed")

		# QuantumHUDPanel connection REMOVED - use InspectorOverlay (N key) instead

## ACTION TOOLBAR UPDATES (for quest board context)

func _update_action_toolbar_for_quest(slot_state: int = 1, is_locked: bool = false) -> void:
	"""Update action toolbar to show quest-specific actions"""
	if action_bar_manager:
		action_bar_manager.update_for_quest_board(slot_state, is_locked)


func _restore_action_toolbar() -> void:
	"""Restore action toolbar to normal tool mode"""
	if action_bar_manager:
		action_bar_manager.restore_normal_mode()


func _on_tool_selected_from_bar(tool_num: int) -> void:
	"""Handle tool selection from action bar"""
	# Update action bar display
	if action_bar_manager:
		action_bar_manager.select_tool(tool_num)

	# Forward to FarmUI if available
	if current_farm_ui and current_farm_ui.has_method("_on_tool_selected"):
		current_farm_ui._on_tool_selected(tool_num)


