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

const OverlayManager = preload("res://UI/Managers/OverlayManager.gd")
const QuestManager = preload("res://Core/Quests/QuestManager.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const LoggerConfigPanel = preload("res://UI/Panels/LoggerConfigPanel.gd")

var current_farm_ui = null  # FarmUI instance (from scene)
var overlay_manager: OverlayManager = null
var quest_manager: QuestManager = null
var farm: Node = null
var farm_ui_container: Control = null
var action_bar_manager = null  # ActionBarManager - manages bottom toolbars
var action_preview_row: Control = null  # Cached reference from ActionBarManager
var logger_config_panel: LoggerConfigPanel = null  # Logger configuration UI

## Modal Management
var modal_stack: Array[Control] = []


func _input(event: InputEvent) -> void:
	"""Layer 1: High-priority input routing (modals + shell actions)"""
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	VerboseConfig.debug("input", "⌨️", "PlayerShell._input() KEY: %s, modal_stack: %d" % [event.keycode, modal_stack.size()])

	# LAYER 1: Modal input (highest priority)
	if not modal_stack.is_empty():
		var active_modal = modal_stack[-1]
		VerboseConfig.debug("input", "→", "Routing to modal: %s" % active_modal.name)
		if active_modal.has_method("handle_input"):
			var consumed = active_modal.handle_input(event)
			VerboseConfig.debug("input", "→", "Modal consumed: %s" % consumed)
			if consumed:
				get_viewport().set_input_as_handled()
				return

	# LAYER 2: Shell actions
	if _handle_shell_action(event):
		get_viewport().set_input_as_handled()
		return

	# LAYER 3: Fall through to Farm._unhandled_input()


func _handle_shell_action(event: InputEvent) -> bool:
	"""Handle shell-level actions (overlay toggles, menu)"""
	match event.keycode:
		KEY_C:
			_toggle_quest_board()
			return true
		KEY_K:
			_toggle_keyboard_help()
			return true
		KEY_L:
			_toggle_logger_config()
			return true
		KEY_ESCAPE:
			_toggle_escape_menu()
			return true
	return false


func _toggle_quest_board() -> void:
	"""Toggle quest board - pass biome via parameter"""
	VerboseConfig.debug("ui", "🎯", "_toggle_quest_board() called")
	if not overlay_manager:
		VerboseConfig.warn("ui", "❌", "overlay_manager is null!")
		return
	if not overlay_manager.quest_board:
		VerboseConfig.warn("ui", "❌", "quest_board is null!")
		return
	var quest_board = overlay_manager.quest_board
	if quest_board.visible:
		VerboseConfig.info("ui", "→", "Closing quest board")
		quest_board.close_board()
		_pop_modal(quest_board)
	else:
		VerboseConfig.info("ui", "→", "Opening quest board")
		var biome = null
		if farm and "biotic_flux_biome" in farm:
			biome = farm.biotic_flux_biome
		VerboseConfig.debug("ui", "→", "farm: %s" % farm)
		VerboseConfig.debug("ui", "→", "biome: %s" % biome)
		if biome:
			quest_board.set_biome(biome)
			quest_board.open_board()
			_push_modal(quest_board)
			VerboseConfig.info("ui", "✅", "Quest board opened")
		else:
			VerboseConfig.warn("ui", "❌", "No biome available!")


func _toggle_keyboard_help() -> void:
	"""Toggle keyboard help overlay"""
	if not overlay_manager:
		return
	overlay_manager.toggle_keyboard_help()


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


func _push_modal(modal: Control) -> void:
	"""Add modal to stack"""
	if modal not in modal_stack:
		modal_stack.append(modal)
		VerboseConfig.debug("input", "📚", "Modal stack: %s" % str(modal_stack.map(func(m): return m.name)))


func _pop_modal(modal: Control) -> void:
	"""Remove modal from stack"""
	var idx = modal_stack.find(modal)
	if idx >= 0:
		modal_stack.remove_at(idx)
		VerboseConfig.debug("input", "📚", "Modal stack: %s" % str(modal_stack.map(func(m): return m.name)))


func _ready() -> void:
	"""Initialize player shell UI - children defined in scene"""
	VerboseConfig.info("boot", "🎪", "PlayerShell initializing...")

	# Add to group so overlay buttons can find us
	add_to_group("player_shell")

	# CRITICAL: Ensure PlayerShell fills its parent (FarmView)
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Process input even when game is paused (for ESC menu, etc.)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Get reference to containers from scene
	farm_ui_container = get_node("FarmUIContainer")
	var overlay_layer = get_node("OverlayLayer")
	var action_bar_layer = get_node("ActionBarLayer")

	# CRITICAL: FarmUIContainer must pass input through to PlotGridDisplay/QuantumForceGraph
	farm_ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	VerboseConfig.info("ui", "✅", "FarmUIContainer mouse_filter set to IGNORE for plot/bubble input")

	# CRITICAL: ActionBarLayer needs explicit size for ActionBarManager to work
	# It has full anchors (0,0,1,1) which will maintain this size, but during _ready()
	# the anchors haven't taken effect yet. Set size to viewport size (what anchors will do).
	# The layout engine processes anchors AFTER _ready(), so this initial size is necessary.
	var viewport_size = get_viewport_rect().size
	action_bar_layer.size = viewport_size
	VerboseConfig.info("ui", "✅", "ActionBarLayer sized for action bar creation: %.0f × %.0f" % [viewport_size.x, viewport_size.y])

	# Create and initialize UILayoutManager
	const UILayoutManager = preload("res://UI/Managers/UILayoutManager.gd")
	var layout_manager = UILayoutManager.new()
	add_child(layout_manager)

	# Create quest manager (before overlays, since overlays need it)
	quest_manager = QuestManager.new()
	add_child(quest_manager)
	VerboseConfig.info("ui", "✅", "Quest manager created")

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

	VerboseConfig.info("ui", "✅", "Action bars created")
	# ═══════════════════════════════════════════════════════════════

	# Create overlay manager and add to overlay layer
	overlay_manager = OverlayManager.new()
	overlay_layer.add_child(overlay_manager)

	# Setup overlay manager with proper dependencies
	overlay_manager.setup(layout_manager, null, null, null, quest_manager)

	# Initialize overlays (C/V/N/K/ESC menus)
	overlay_manager.create_overlays(overlay_layer)

	# Create logger config panel (debug tool, press L to toggle)
	logger_config_panel = LoggerConfigPanel.new()
	overlay_layer.add_child(logger_config_panel)
	logger_config_panel.closed.connect(func():
		_pop_modal(logger_config_panel)
	)
	VerboseConfig.info("ui", "✅", "Logger config panel created (press L to toggle)")

	# Connect overlay signals
	_connect_overlay_signals()

	VerboseConfig.info("ui", "✅", "Overlay manager created")
	VerboseConfig.info("boot", "✅", "PlayerShell ready")


func _connect_overlay_signals() -> void:
	"""Connect signals from overlays to manage modal stack"""
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
		VerboseConfig.info("ui", "✅", "Quest board signals connected")

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
		VerboseConfig.info("ui", "✅", "Escape menu signals connected")

	if overlay_manager.save_load_menu:
		overlay_manager.save_load_menu.menu_closed.connect(func():
			_pop_modal(overlay_manager.save_load_menu)
		)
		VerboseConfig.info("ui", "✅", "Save/Load menu signals connected")


func load_farm(farm_ref: Node) -> void:
	"""Load a farm into FarmUIContainer (swappable)"""
	VerboseConfig.info("ui", "📂", "Loading farm into PlayerShell...")

	# Clean up old farm UI if it exists
	if current_farm_ui:
		current_farm_ui.queue_free()
		current_farm_ui = null

	# Store farm reference
	farm = farm_ref

	# Connect quest manager to farm economy
	if quest_manager and farm.economy:
		quest_manager.connect_to_economy(farm.economy)
		VerboseConfig.info("ui", "✅", "Quest manager connected to economy")

		# Offer initial quest
		_offer_initial_quest()

	# Load FarmUI as scene and add to container
	var farm_ui_scene = load("res://UI/FarmUI.tscn")
	if farm_ui_scene:
		current_farm_ui = farm_ui_scene.instantiate()
		farm_ui_container.add_child(current_farm_ui)

		# Setup farm AFTER layout engine calculates sizes (proper Godot 4 pattern)
		# call_deferred here is the CORRECT TOOL for "run after engine initialization"
		current_farm_ui.call_deferred("setup_farm", farm_ref)
		VerboseConfig.info("ui", "✅", "FarmUI loaded (setup deferred until after layout calculation)")
	else:
		VerboseConfig.warn("ui", "❌", "FarmUI.tscn not found - cannot load farm UI")
		return

	VerboseConfig.info("ui", "✅", "Farm loaded into PlayerShell")


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
		VerboseConfig.info("ui", "✔", "FarmUI mounted in container")

	# Connect to farm_setup_complete signal to wire input_handler (created later in setup_farm())
	if farm_ui.has_signal("farm_setup_complete"):
		farm_ui.farm_setup_complete.connect(_connect_to_farm_input_handler)
		VerboseConfig.info("ui", "⏳", "Will connect to input_handler when farm setup completes...")
	else:
		push_error("FarmUI missing farm_setup_complete signal!")

func _connect_to_farm_input_handler() -> void:
	"""Connect to FarmInputHandler after it's created (triggered by farm_setup_complete signal)"""
	var farm_ui = current_farm_ui
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
				VerboseConfig.info("ui", "✔", "ActionPreviewRow → FarmInputHandler (direct connection)")

				# Inject input_handler reference for action validation
				action_row.input_handler = farm_ui.input_handler
				VerboseConfig.info("ui", "✔", "ActionPreviewRow validation dependencies injected")

		VerboseConfig.info("ui", "✔", "Input handler connected to action bars")

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
				VerboseConfig.info("ui", "✔", "Action buttons will update on selection changes")

			# Connect to resource changes to update action button availability (for planting)
			if farm_ui.farm and farm_ui.farm.economy and farm_ui.farm.economy.has_signal("resource_changed"):
				farm_ui.farm.economy.resource_changed.connect(func(_emoji, _amount):
					var action_row = action_bar_manager.get_action_row()
					if action_row and action_row.has_method("update_action_availability"):
						action_row.update_action_availability()
				)
				VerboseConfig.info("ui", "✔", "Action buttons will update on resource changes")


## OVERLAY SYSTEM INITIALIZATION

func _initialize_overlay_system() -> void:
	"""Initialize OverlayManager with minimal dependencies"""
	if not overlay_manager:
		return

	# Create a minimal UILayoutManager for compatibility
	# (OverlayManager requires it even if we don't use all features)
	const UILayoutManager = preload("res://UI/Managers/UILayoutManager.gd")
	var layout_mgr = UILayoutManager.new()

	# Get system dependencies from Farm if available
	# (These will be null but OverlayManager handles it gracefully)
	var vocab_sys = null
	var faction_mgr = null
	var conspiracy_net = null

	# Initialize OverlayManager with dependencies
	overlay_manager.setup(layout_mgr, vocab_sys, faction_mgr, conspiracy_net)

	# Create the overlay UI panels
	overlay_manager.create_overlays(self)

	VerboseConfig.info("ui", "🎭", "Overlay system initialized")


## QUEST SYSTEM HELPERS

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


## QUEST SYSTEM HELPERS

func _offer_initial_quest() -> void:
	"""Offer first quest to player when farm loads"""
	if not quest_manager or not farm:
		return

	# Get random faction from database
	var faction = FactionDatabase.get_random_faction()
	if faction.is_empty():
		VerboseConfig.warn("ui", "⚠️", "No factions available for quests")
		return

	# Get resources from current biome
	var resources = []
	if farm.biotic_flux_biome:
		resources = farm.biotic_flux_biome.get_harvestable_emojis()

	if resources.is_empty():
		resources = ["🌾", "👥"]  # Fallback

	# Generate and offer quest
	var quest = quest_manager.offer_quest(faction, "BioticFlux", resources)
	if not quest.is_empty():
		# Auto-accept first quest for tutorial
		quest_manager.accept_quest(quest)
		VerboseConfig.info("ui", "📜", "Initial quest offered: %s - %s" % [quest.get("faction", ""), quest.get("body", "")])
