class_name FarmUIController
extends Control

## FarmUIController - Boundary Plane between User UI and Simulation Machinery
##
## Architecture:
## - FarmUILayoutManager: Handles all visual layout (containers, sizing, styling)
## - FarmUIControlsManager: Handles all input and signal routing
## - FarmUIController: Orchestrates both, provides public API, injects dependencies
##
## This controller is the ONLY thing that touches both the UI systems and Farm simulation.
## It acts as a clean boundary/facade between user interaction and simulation machinery.
##
## WIRING PATTERN (Phase 2+):
## All components declare their farm dependencies via a standardized wire_to_farm(farm) method.
## FarmUIController calls _wire_components_to_farm() which loops through all components
## and calls wire_to_farm() on each one. This ensures:
## - No hidden dependencies (all wiring is explicit)
## - Consistent initialization order (all components wired before farm is "live")
## - Self-documenting contracts (component declares what it needs)
## - Easy debugging (one place to see all component initialization)

# Preload the two subsystems
const FarmUILayoutManager = preload("res://UI/FarmUILayoutManager.gd")
const FarmUIControlsManager = preload("res://UI/FarmUIControlsManager.gd")

# Preload GridConfig (Phase 7)
const GridConfig = preload("res://Core/GameState/GridConfig.gd")

# Dependencies (injected from parent)
var farm: Node = null
var ui_state = null  # FarmUIState - abstraction layer (Phase 3, RefCounted not Node)
var faction_manager: Node = null
var vocabulary_evolution: Node = null
var conspiracy_network: Node = null
var grid_config: GridConfig = null  # Grid configuration (Phase 7)

# Subsystems
var layout_manager: FarmUILayoutManager = null
var controls_manager: FarmUIControlsManager = null

# Convenience access to major components (delegates to layout manager)
var overlay_manager: Node = null
var quantum_graph: Node = null
var play_area: Control = null
var plots_row: Control = null
var actions_row: Control = null

# Debug: detect multiple _ready() calls
var ready_call_count: int = 0


## INITIALIZATION

func _ready() -> void:
	"""Initialize the UI boundary layer"""
	ready_call_count += 1
	if ready_call_count > 1:
		print("⚠️  FarmUIController._ready() called %d times!" % ready_call_count)
		return

	print("🎮 FarmUIController initializing...")

	# Fill parent (FarmView)
	size = get_parent().size
	position = Vector2.ZERO

	# Create layout manager and add to tree
	layout_manager = FarmUILayoutManager.new()
	layout_manager.size = size  # Fill FarmUIController
	layout_manager.position = Vector2.ZERO
	add_child(layout_manager)

	# Inject dependencies into layout manager (needed by overlay systems)
	layout_manager.inject_dependencies(faction_manager, vocabulary_evolution, conspiracy_network)

	# Create the controls subsystem (handles input and signals)
	controls_manager = FarmUIControlsManager.new()
	add_child(controls_manager)

	# Inject UI controller reference into controls manager
	controls_manager.inject_ui_controller(self)

	# Cache convenient references to major components
	overlay_manager = layout_manager.overlay_manager
	quantum_graph = layout_manager.quantum_graph
	play_area = layout_manager.play_area
	plots_row = layout_manager.plots_row
	actions_row = layout_manager.actions_row

	# CRITICAL: Get InputController from controls_manager and inject into SaveLoadMenu
	# This allows SaveLoadMenu to disable InputController while menu is open
	# so all input goes to SaveLoadMenu instead of being consumed by InputController
	var input_controller = controls_manager.input_controller
	if input_controller and overlay_manager and overlay_manager.save_load_menu:
		overlay_manager.save_load_menu.inject_input_controller(input_controller)
		print("🔗 InputController wired to SaveLoadMenu")
	else:
		print("⚠️  Could not wire InputController to SaveLoadMenu (missing refs)")
		print("   input_controller: %s" % input_controller)
		print("   overlay_manager: %s" % overlay_manager)
		print("   save_load_menu: %s" % (overlay_manager.save_load_menu if overlay_manager else "N/A"))

	# Inject farm into layout manager (for plot grid display)
	if farm:
		layout_manager.inject_farm(farm, self)

	# REFACTOR: Wire multi-select components after all are initialized
	_wire_multi_select_components()

	print("✅ FarmUIController ready (boundary established)")


## DEPENDENCY INJECTION

func inject_controls(controls_interface: Node) -> void:
	"""Inject simulation machinery implementing ControlsInterface contract"""
	if controls_manager:
		controls_manager.inject_controls(controls_interface)
		print("✅ Simulation controls injected into controls manager")


func inject_farm(farm_ref: Node, faction_mgr: Node = null, vocab_sys: Node = null, conspiracy_net: Node = null) -> void:
	"""Inject farm and related systems, wire all UI components

	Initialization flow:
	1. Store farm reference and related systems
	2. Inject farm into layout_manager (for PlotGridDisplay direct signals)
	3. Inject UIState if available
	4. Connect controls_manager signals
	5. Wire all components via _wire_components_to_farm()
	   - QuantumForceGraph.wire_to_farm() initializes quantum bubble visualization
	   - PlotGridDisplay.wire_to_farm() connects to farm signals

	After this returns, all systems are ready and farm is "live".
	"""
	farm = farm_ref
	faction_manager = faction_mgr
	vocabulary_evolution = vocab_sys
	conspiracy_network = conspiracy_net
	print("💉 Farm injected into FarmUIController")

	# Phase 7: Extract and inject GridConfig from farm
	if farm_ref and farm_ref.has_meta("grid_config") or (farm_ref and "grid_config" in farm_ref):
		var farm_grid_config = farm_ref.grid_config if "grid_config" in farm_ref else farm_ref.get_meta("grid_config")
		if farm_grid_config:
			grid_config = farm_grid_config
			_inject_grid_config_to_components()
			print("   📡 GridConfig extracted and injected into components")

	# PHASE 4: Inject farm into layout_manager (for PlotGridDisplay direct signal connections)
	if layout_manager and farm_ref:
		layout_manager.inject_farm(farm_ref, self)
		print("   📡 Farm injected into PlotGridDisplay via layout_manager")

	# Phase 6: Inject UIState from farm if available
	if farm_ref and "ui_state" in farm_ref:
		if farm_ref.ui_state:
			inject_ui_state(farm_ref.ui_state)
			print("   📡 UIState auto-injected from farm")

	# If controls_manager exists (was already created in _ready), connect signals now
	if controls_manager:
		controls_manager.inject_farm(farm_ref)
		print("📡 Controls manager signals connected")

	# Phase 6: Inject UIState into layout_manager (for PlotGridDisplay)
	if layout_manager and farm_ref and "ui_state" in farm_ref and farm_ref.ui_state:
		if layout_manager.plot_grid_display:
			layout_manager.plot_grid_display.inject_ui_state(farm_ref.ui_state)
			print("   📡 UIState injected into PlotGridDisplay")

	# Wire all components to farm (standardized initialization contract)
	_wire_components_to_farm(farm_ref)


func inject_farm_late(farm_ref: Node) -> void:
	"""Inject farm data after UI is already initialized (via MemoryManager)"""
	if not farm_ref:
		push_error("FarmUIController: Attempted to inject null farm!")
		return

	farm = farm_ref
	print("💉 Farm injected (post-_ready) - Reinitializing systems...")

	# Inject farm into controls manager for signal connections
	if controls_manager:
		controls_manager.inject_farm(farm_ref)

	# Inject farm into layout manager's visualization systems
	if layout_manager and layout_manager.quantum_graph and farm.has_meta("grid"):
		var play_rect = layout_manager.layout_manager.play_area_rect
		var center = play_rect.get_center() - play_rect.position
		var radius = play_rect.size.length() * 0.3

		# PHASE 8: Get parametric plot positions from PlotGridDisplay
		# Plots are the foundation - QuantumForceGraph tethers to them
		var plot_positions: Dictionary = {}
		if layout_manager.plot_grid_display and layout_manager.plot_grid_display.has_method("get_classical_plot_positions"):
			plot_positions = layout_manager.plot_grid_display.get_classical_plot_positions()
			print("⚛️ FarmUIController: Passing %d plot positions to QuantumForceGraph" % plot_positions.size())

		layout_manager.quantum_graph.initialize(farm.grid if farm.has_method("get_grid") else null, center, radius, plot_positions)

		if farm.has_meta("biome"):
			layout_manager.quantum_graph.set_biome(farm.get_meta("biome"))
			layout_manager.quantum_graph.create_sun_qubit_node()

	print("✅ Farm systems reinitialized")


func _inject_grid_config_to_components() -> void:
	"""Inject GridConfig to all components that need it (Phase 7)"""
	if not grid_config:
		print("⚠️  GridConfig not available for injection")
		return

	# Inject to layout manager
	if layout_manager and layout_manager.has_method("inject_grid_config"):
		layout_manager.inject_grid_config(grid_config)
		print("💉 GridConfig → FarmUILayoutManager")

	# Inject to controls manager
	if controls_manager and controls_manager.has_method("inject_grid_config"):
		controls_manager.inject_grid_config(grid_config)
		print("💉 GridConfig → FarmUIControlsManager")


func _wire_components_to_farm(farm_ref: Node) -> void:
	"""Wire all components using standardized wire_to_farm() interface

	This is the central place where all components are initialized with farm data.
	Each component declares its dependencies via the wire_to_farm(farm) method.
	"""
	if not farm_ref:
		return

	# Wire QuantumForceGraph (quantum bubble visualization)
	if layout_manager and layout_manager.quantum_graph and layout_manager.quantum_graph.has_method("wire_to_farm"):
		layout_manager.quantum_graph.wire_to_farm(farm_ref)

	# Wire PlotGridDisplay (classical plot tiles)
	if layout_manager and layout_manager.plot_grid_display and layout_manager.plot_grid_display.has_method("wire_to_farm"):
		layout_manager.plot_grid_display.wire_to_farm(farm_ref)

	print("✅ All components wired to farm")


func _wire_multi_select_components() -> void:
	"""Wire PlotGridDisplay to FarmInputHandler for multi-select support

	This is called after all components are created to avoid deferred/shimmed injection.
	Ensures clean dependency wiring without haunting issues.
	"""
	if not controls_manager or not layout_manager:
		print("⚠️  Cannot wire multi-select: controls_manager or layout_manager missing")
		return

	# Get references to both components
	var input_handler = controls_manager.get_input_handler()
	var plot_grid_display = layout_manager.plot_grid_display

	# Validate both exist
	if not input_handler:
		print("⚠️  Cannot wire multi-select: FarmInputHandler not found")
		return

	if not plot_grid_display:
		print("⚠️  Cannot wire multi-select: PlotGridDisplay not found")
		return

	# Wire them together
	controls_manager.set_plot_grid_display(plot_grid_display)

	# Validate the wiring worked
	if input_handler.plot_grid_display == plot_grid_display:
		print("✅ Multi-select components wired successfully")
		print("   • FarmInputHandler → PlotGridDisplay")
		print("   • PlotGridDisplay → SelectionManager → PlotTiles")
	else:
		print("❌ FAILED: Multi-select wiring did not work!")

	# Wire selection changes to button highlighting
	if plot_grid_display.has_signal("selection_count_changed") and layout_manager.action_preview_row:
		plot_grid_display.selection_count_changed.connect(_on_selection_count_changed)
		print("   • PlotGridDisplay → ActionPreviewRow (button highlighting)")
		# Initial state: update buttons based on current selection
		var current_count = plot_grid_display.get_selected_plot_count()
		_on_selection_count_changed(current_count)


func inject_ui_state(ui_state_ref) -> void:
	"""Inject FarmUIState - the abstraction layer (Phase 3)"""
	if not ui_state_ref:
		push_error("FarmUIController: Attempted to inject null UIState!")
		return

	ui_state = ui_state_ref
	print("💉 UIState injected into FarmUIController")

	# Connect to UIState signals for reactive updates
	if ui_state.has_signal("economy_updated"):
		ui_state.economy_updated.connect(_on_economy_updated)
		print("   📡 Connected to economy_updated signal")
	if ui_state.has_signal("credits_changed"):
		ui_state.credits_changed.connect(_on_credits_changed)
		print("   📡 Connected to credits_changed signal")
	if ui_state.has_signal("flour_changed"):
		ui_state.flour_changed.connect(_on_flour_changed)
		print("   📡 Connected to flour_changed signal")

	if ui_state.has_signal("plot_updated"):
		ui_state.plot_updated.connect(_on_plot_updated)
		print("   📡 Connected to plot_updated signal")


## PUBLIC API - Simple facades for UI operations

func get_layout_manager() -> FarmUILayoutManager:
	"""Get the layout manager (for visual operations)"""
	return layout_manager


func get_controls_manager() -> FarmUIControlsManager:
	"""Get the controls manager (for input operations)"""
	return controls_manager


func mark_dirty() -> void:
	"""Mark UI as needing refresh"""
	pass  # Can implement update queuing here if needed


## CALLBACKS FROM CONTROLS MANAGER - These route to UI updates

func on_tool_changed(tool_num: int, tool_info: Dictionary) -> void:
	"""Tool selection changed"""
	print("  FarmUIController.on_tool_changed() called with tool_num=%d" % tool_num)
	if layout_manager:
		print("    layout_manager exists")
		if layout_manager.action_preview_row:
			print("    Updating ActionPreviewRow...")
			layout_manager.action_preview_row.update_for_tool(tool_num)
		if layout_manager.tool_selection_row:
			print("    Updating ToolSelectionRow...")
			layout_manager.tool_selection_row.select_tool(tool_num)
			print("    ✓ ToolSelectionRow.select_tool() called")
		else:
			print("    ✗ tool_selection_row is null!")
	else:
		print("    ✗ layout_manager is null!")


func on_plot_selected(pos: Vector2i) -> void:
	"""Plot was selected via keyboard"""
	# Highlight selected plot visually
	if layout_manager and layout_manager.plot_grid_display:
		layout_manager.plot_grid_display.set_selected_plot(pos)
		print("🎯 Plot selected in UI: %s" % pos)


func on_action_performed(action: String, success: bool, message: String) -> void:
	"""Action was performed (Q/E/R executed) - show feedback to user"""
	print("💬 Action feedback: %s" % message)
	# TODO: Show action feedback in UI (toast, status bar, etc.)
	if layout_manager and layout_manager.has_method("show_action_feedback"):
		layout_manager.show_action_feedback(action, success, message)


func on_plot_planted(pos: Vector2i) -> void:
	"""Plot was planted"""
	# Update plot visual
	if layout_manager and layout_manager.plot_grid_display:
		layout_manager.plot_grid_display.update_tile_from_farm(pos)
		print("🌱 Plot planted visual updated: %s" % pos)


func on_plot_harvested(pos: Vector2i, yield_amount: int) -> void:
	"""Plot was harvested"""
	pass


func on_qubit_measured(pos: Vector2i, outcome: String) -> void:
	"""Qubit measurement happened"""
	pass


func on_plots_entangled(pos1: Vector2i, pos2: Vector2i) -> void:
	"""Plots were entangled"""
	pass


func on_tool_applied(tool: String, pos: Vector2i, result: bool) -> void:
	"""Tool was applied to farm"""
	pass


func on_plot_state_changed(pos: Vector2i) -> void:
	"""Plot state changed"""
	pass


func toggle_keyboard_help() -> void:
	"""Toggle keyboard help display"""
	pass


func toggle_debug() -> void:
	"""Toggle debug mode"""
	pass


func update_wheat(new_amount: int) -> void:
	"""Update wheat currency display"""
	if layout_manager and layout_manager.resource_panel:
		var resources = _gather_resources()
		var wheat = new_amount
		var credits = 0
		var flour = 0
		# Prefer UIState value if available (Phase 3)
		if ui_state and "wheat" in ui_state:
			wheat = ui_state.wheat
		if ui_state and "credits" in ui_state:
			credits = ui_state.credits
		if ui_state and "flour" in ui_state:
			flour = ui_state.flour
		layout_manager.resource_panel.update_resources(wheat, credits, flour, resources)


func update_inventory(resource: String, amount: int) -> void:
	"""Update inventory display"""
	if layout_manager and layout_manager.resource_panel:
		# Prefer UIState values if available (Phase 3)
		var wheat = 100
		var credits = 0
		var flour = 0
		if ui_state and "wheat" in ui_state:
			wheat = ui_state.wheat
		elif farm and farm.economy:
			wheat = farm.economy.wheat_inventory

		if ui_state and "credits" in ui_state:
			credits = ui_state.credits
		if ui_state and "flour" in ui_state:
			flour = ui_state.flour

		var resources = _gather_resources()
		layout_manager.resource_panel.update_resources(wheat, credits, flour, resources)


func _gather_resources() -> Dictionary:
	"""Gather current resource values from UIState (abstraction layer)

	Falls back to farm.economy if UIState not available (backward compatibility)
	"""
	# Prefer UIState (Phase 3 decoupling)
	if ui_state and ui_state.has_method("get"):
		return ui_state.resources

	# Fallback to farm economy (for backward compatibility)
	if farm and farm.economy:
		return {
			"👥": farm.economy.labor_inventory,
			"💨": farm.economy.flour_inventory,
			"🌻": farm.economy.flower_inventory,
			"🍄": farm.economy.mushroom_inventory,
			"🍂": farm.economy.detritus_inventory,
			"🏰": farm.economy.imperium_resource
		}

	return {}


func show_message(text: String) -> void:
	"""Show informational message in UI"""
	if layout_manager and layout_manager.info_panel:
		layout_manager.info_panel.show_message(text)


func show_error(text: String) -> void:
	"""Show error message in UI"""
	if layout_manager and layout_manager.info_panel:
		layout_manager.info_panel.show_error(text)


func get_current_selected_plot() -> Vector2i:
	"""Get current keyboard-selected plot position"""
	if controls_manager and controls_manager.has_method("get_input_handler"):
		var input_handler = controls_manager.get_input_handler()
		if input_handler and input_handler.has_property("current_selection"):
			return input_handler.current_selection
	return Vector2i(-1, -1)


## UI STATE SIGNAL HANDLERS (Phase 3 - Reactive Updates)

func _on_economy_updated(wheat: int, resources: Dictionary) -> void:
	"""Handle economy changes from UIState - update ResourcePanel reactively"""
	if layout_manager and layout_manager.resource_panel and ui_state:
		var credits = ui_state.credits if "credits" in ui_state else 0
		var flour = ui_state.flour if "flour" in ui_state else 0
		layout_manager.resource_panel.update_resources(wheat, credits, flour, resources)
		print("💰 ResourcePanel updated via UIState signal")


func _on_credits_changed(new_amount: int) -> void:
	"""Handle credits changed signal"""
	if layout_manager and layout_manager.resource_panel:
		layout_manager.resource_panel.update_credits(new_amount)


func _on_flour_changed(new_amount: int) -> void:
	"""Handle flour changed signal"""
	if layout_manager and layout_manager.resource_panel:
		layout_manager.resource_panel.update_flour(new_amount)


func _on_plot_updated(position: Vector2i, plot_data) -> void:
	"""Handle plot changes from UIState - update plot tile visually"""
	if layout_manager and layout_manager.plot_grid_display:
		# Plot grid display will respond to UIState signals directly
		# This handler can be used for other plot-related UI updates
		print("🌱 Plot updated at %s via UIState signal" % position)


func _on_selection_count_changed(count: int) -> void:
	"""Handle selection count changes - update action button highlights"""
	if not layout_manager or not layout_manager.action_preview_row:
		return

	var has_selection = count > 0
	layout_manager.action_preview_row.update_button_highlights(has_selection)

	if has_selection:
		print("🎯 Action buttons highlighted (plots selected: %d)" % count)
	else:
		print("🎯 Action buttons disabled (no plots selected)")
