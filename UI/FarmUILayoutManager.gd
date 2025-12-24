class_name FarmUILayoutManager
extends Control

## FarmUILayoutManager - Responsible for all visual layout and container hierarchy
## Handles:
## - UI container structure (VBox, HBox hierarchy)
## - Sizing and positioning of elements
## - Visual styling and debug borders
## - Component creation (panels, buttons, displays)
## - Visualization systems (quantum graph, entanglement lines)
##
## Clean separation: This manager handles ONLY visual layout
## Input handling is in FarmUIControlsManager
## Simulation logic stays in Farm.gd

# Preload UI components
const UILayoutManager = preload("res://UI/Managers/UILayoutManager.gd")
const OverlayManager = preload("res://UI/Managers/OverlayManager.gd")

# Preload GridConfig (Phase 7)
const GridConfig = preload("res://Core/GameState/GridConfig.gd")
const PlotGridDisplay = preload("res://UI/PlotGridDisplay.gd")
const ResourcePanel = preload("res://UI/Panels/ResourcePanel.gd")
const BiomeInfoDisplay = preload("res://UI/Panels/BiomeInfoDisplay.gd")
const GoalPanel = preload("res://UI/Panels/GoalPanel.gd")
const InfoPanel = preload("res://UI/Panels/InfoPanel.gd")
const ToolSelectionRow = preload("res://UI/Panels/ToolSelectionRow.gd")
const ActionPreviewRow = preload("res://UI/Panels/ActionPreviewRow.gd")
const KeyboardHintButton = preload("res://UI/Panels/KeyboardHintButton.gd")
const QuantumForceGraph = preload("res://Core/Visualization/QuantumForceGraph.gd")
const EntanglementLines = preload("res://UI/EntanglementLines.gd")

## Managers
var layout_manager: UILayoutManager
var overlay_manager: OverlayManager

## Dependencies for OverlayManager
var faction_manager: Node = null
var vocabulary_evolution: Node = null
var conspiracy_network: Node = null
var grid_config: GridConfig = null  # Grid configuration (Phase 7)

## UI Components
var plot_grid_display: PlotGridDisplay
var resource_panel: ResourcePanel
var biome_info_display: BiomeInfoDisplay
var goal_panel: GoalPanel
var info_panel: InfoPanel
var tool_selection_row: ToolSelectionRow
var action_preview_row: ActionPreviewRow
var keyboard_hint_button: KeyboardHintButton

## Visualization Systems
var quantum_graph: QuantumForceGraph
var entanglement_lines: EntanglementLines

## UI Containers
var top_bar: HBoxContainer
var plots_row: Control
var play_area: Control
var actions_row: Control
var bottom_bar: Control


## INITIALIZATION

# HAUNTED UI FIX: Prevent double-initialization
var _is_initialized: bool = false

func _ready() -> void:
	"""Initialize visual layout structure"""
	# HAUNTED UI FIX: Guard against double-initialization
	if _is_initialized:
		print("⚠️  FarmUILayoutManager._ready() called multiple times, skipping re-initialization")
		return
	_is_initialized = true

	print("🎨 FarmUILayoutManager initializing... size=%s" % size)

	# Create layout manager (must be first - needed by other components)
	_create_layout_manager()

	# Create UI structure (synchronous - no await)
	_create_ui_structure()

	# Create all UI components and visual systems
	_create_managers()
	_create_ui_components()
	_create_visualization_systems()

	# Wait for layout system to process container sizing
	await get_tree().process_frame

	# DISABLE DEBUG LAYOUT TEMPORARILY to test for visual artifacts from debug borders
	# _enable_debug_layout() # TODO: Re-enable after fixing button overlap issue
	print("🐛 DEBUG LAYOUT DISABLED - checking for button duplication")

	print("✅ FarmUILayoutManager ready!")


func inject_dependencies(faction_mgr: Node = null, vocab_sys: Node = null, conspiracy_net: Node = null) -> void:
	"""Inject dependencies needed by overlay systems"""
	faction_manager = faction_mgr
	vocabulary_evolution = vocab_sys
	conspiracy_network = conspiracy_net
	print("💉 Dependencies injected into FarmUILayoutManager")


func inject_farm(farm: Node, ui_controller: Node) -> void:
	"""Inject farm and ui_controller into plot grid display"""
	if plot_grid_display:
		plot_grid_display.inject_farm(farm)
		plot_grid_display.inject_ui_controller(ui_controller)
		print("💉 Farm injected into PlotGridDisplay")


func inject_grid_config(config: GridConfig) -> void:
	"""Inject GridConfig into PlotGridDisplay (Phase 7)"""
	if not config:
		push_error("FarmUILayoutManager: Attempted to inject null GridConfig!")
		return

	grid_config = config
	print("💉 GridConfig injected into FarmUILayoutManager")

	# Pass to PlotGridDisplay
	if plot_grid_display and plot_grid_display.has_method("inject_grid_config"):
		plot_grid_display.inject_grid_config(config)
		print("   📡 GridConfig → PlotGridDisplay")

	# Pass to layout manager for dynamic sizing
	if layout_manager and layout_manager.has_method("inject_grid_config"):
		layout_manager.inject_grid_config(config)
		print("   📡 GridConfig → UILayoutManager")


func _create_layout_manager() -> void:
	"""Create parametric layout manager for responsive scaling"""
	layout_manager = UILayoutManager.new()
	add_child(layout_manager)
	print("📐 Layout Manager created")


func _create_ui_structure() -> void:
	"""Create basic UI container structure"""
	# Create main vertical container
	var main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	# Since parent is a plain Control, we must size the container explicitly
	main_container.size = size  # Fill parent
	main_container.position = Vector2.ZERO
	# Also set size_flags for children that expand
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_theme_constant_override("separation", 0)
	add_child(main_container)

	# ========== TOP BAR (Resources, Goals, etc.) ==========
	top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_theme_constant_override("separation", 10)
	main_container.add_child(top_bar)

	# ========== MAIN AREA (Play Area + Plots + Actions) ==========
	var main_area = VBoxContainer.new()
	main_area.name = "MainArea"
	main_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_area.add_theme_constant_override("separation", 0)
	main_container.add_child(main_area)

	# Play area (quantum visualization) - expands to fill remaining space
	play_area = Control.new()
	play_area.name = "PlayArea"
	play_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_area.size_flags_vertical = Control.SIZE_EXPAND_FILL  # ONLY this one expands to fill
	main_area.add_child(play_area)

	# Plots row (classical plot tiles) - fixed height, no expansion
	plots_row = Control.new()
	plots_row.name = "PlotsRow"
	plots_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plots_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # Don't expand, use minimum_size
	plots_row.custom_minimum_size = Vector2(0, 100)  # Fixed height for plot tiles
	main_area.add_child(plots_row)

	# Actions row (keyboard UI) - fixed height, no expansion
	actions_row = Control.new()
	actions_row.name = "ActionsRow"
	actions_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # Don't expand, use minimum_size
	actions_row.custom_minimum_size = Vector2(0, 90)  # Fixed height for action labels
	main_area.add_child(actions_row)

	# ========== BOTTOM BAR (Tool Selection) ==========
	bottom_bar = HBoxContainer.new()
	bottom_bar.name = "BottomBar"
	bottom_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_bar.add_theme_constant_override("separation", 10)
	main_container.add_child(bottom_bar)

	print("✅ UI Structure created")


func _create_managers() -> void:
	"""Create all manager systems (OverlayManager, etc.)"""
	overlay_manager = OverlayManager.new()
	add_child(overlay_manager)
	# CRITICAL: setup() must be called before create_overlays()
	overlay_manager.setup(layout_manager, vocabulary_evolution, faction_manager, conspiracy_network)
	overlay_manager.create_overlays(self)
	print("📋 OverlayManager created")


func _create_ui_components() -> void:
	"""Create all UI component panels with proper positioning"""

	# ========== TOP BAR COMPONENTS ==========
	resource_panel = ResourcePanel.new()
	resource_panel.set_layout_manager(layout_manager)
	resource_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(resource_panel)

	var spacer1 = Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer1)

	goal_panel = GoalPanel.new()
	goal_panel.set_layout_manager(layout_manager)
	goal_panel.custom_minimum_size = Vector2(300, 0)
	top_bar.add_child(goal_panel)

	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer2)

	keyboard_hint_button = KeyboardHintButton.new()
	keyboard_hint_button.set_layout_manager(layout_manager)
	keyboard_hint_button.custom_minimum_size = Vector2(150, 0)
	top_bar.add_child(keyboard_hint_button)

	# ========== PLAY AREA COMPONENTS ==========
	biome_info_display = BiomeInfoDisplay.new()
	biome_info_display.set_layout_manager(layout_manager)
	biome_info_display.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	play_area.add_child(biome_info_display)

	# ========== INFO PANEL ==========
	info_panel = InfoPanel.new()
	info_panel.set_layout_manager(layout_manager)
	add_child(info_panel)

	# ========== PLOTS ROW COMPONENTS ==========
	plot_grid_display = PlotGridDisplay.new()
	plot_grid_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plot_grid_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plots_row.add_child(plot_grid_display)
	# Hide PlotGridDisplay - using QuantumForceGraph visualization instead
	plot_grid_display.hide()

	# ========== ACTIONS ROW COMPONENTS ==========
	action_preview_row = ActionPreviewRow.new()
	action_preview_row.set_layout_manager(layout_manager)
	action_preview_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_preview_row.z_index = 10  # Ensure Q/E/R menu appears on top
	actions_row.add_child(action_preview_row)

	# ========== BOTTOM BAR COMPONENTS ==========
	tool_selection_row = ToolSelectionRow.new()
	tool_selection_row.set_layout_manager(layout_manager)
	tool_selection_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_selection_row.z_index = 5  # Lower z_index than ActionPreviewRow
	bottom_bar.add_child(tool_selection_row)

	print("🎨 UI components created and positioned")


func _create_visualization_systems() -> void:
	"""Create all visualization systems (quantum graph, entanglement lines, effects)"""
	quantum_graph = QuantumForceGraph.new()
	play_area.add_child(quantum_graph)

	entanglement_lines = EntanglementLines.new()
	play_area.add_child(entanglement_lines)

	print("✨ Visualization systems created and anchored")


## DEBUG UTILITIES

func _add_debug_border(node: Node, color: Color = Color.YELLOW, label: String = "") -> void:
	"""Add a colorful debug border to any Control node"""
	if not node is Control:
		return

	var control = node as Control

	# Create a StyleBox with border for visibility
	var stylebox = StyleBoxFlat.new()
	var semi_transparent_color = color
	semi_transparent_color.a = 0.15
	stylebox.bg_color = semi_transparent_color
	stylebox.border_color = color
	stylebox.border_width_left = 2
	stylebox.border_width_top = 2
	stylebox.border_width_right = 2
	stylebox.border_width_bottom = 2

	control.add_theme_stylebox_override("panel", stylebox)

	# Add a label for identification
	if label != "":
		var debug_label = Label.new()
		debug_label.text = label
		debug_label.add_theme_font_size_override("font_size", 10)
		debug_label.modulate = color
		debug_label.z_index = 100
		control.add_child(debug_label)


func _enable_debug_layout() -> void:
	"""Enable visual debug for all UI containers"""
	print("🐛 DEBUG MODE: Adding visual borders to all UI elements")

	# Find main_container for diagnostics
	var main_container = find_child("MainContainer", true, false)

	# Print actual dimensions for debugging
	print("\n📐 ACTUAL RENDERED SIZES:")
	print("   FarmUILayoutManager: pos=%s size=%s" % [position, size])
	if main_container and main_container is Control:
		var mc = main_container as Control
		print("   MainContainer: pos=%s size=%s (this should be %s)" % [mc.position, mc.size, size])
	if top_bar:
		print("   TopBar: pos=%s size=%s (expected %.1fpx height)" % [top_bar.position, top_bar.size, layout_manager.top_bar_height])
	if plots_row:
		print("   PlotsRow: pos=%s size=%s (expected %.1fpx height)" % [plots_row.position, plots_row.size, layout_manager.plots_row_rect.size.y])
	if play_area:
		print("   PlayArea: pos=%s size=%s (should expand)" % [play_area.position, play_area.size])
	if actions_row:
		print("   ActionsRow: pos=%s size=%s (expected %.1fpx height)" % [actions_row.position, actions_row.size, layout_manager.actions_row_rect.size.y])
	if bottom_bar:
		print("   BottomBar: pos=%s size=%s (expected %.1fpx height)" % [bottom_bar.position, bottom_bar.size, layout_manager.top_bar_height])
	print()

	# Containers
	_add_debug_border(top_bar, Color.RED, "TOP_BAR")
	_add_debug_border(plots_row, Color.GREEN, "PLOTS_ROW")
	_add_debug_border(play_area, Color.BLUE, "PLAY_AREA")
	_add_debug_border(actions_row, Color.YELLOW, "ACTIONS_ROW")
	_add_debug_border(bottom_bar, Color.MAGENTA, "BOTTOM_BAR")

	# Components
	if resource_panel:
		_add_debug_border(resource_panel, Color.ORANGE, "RESOURCE")
	if goal_panel:
		_add_debug_border(goal_panel, Color.CYAN, "GOALS")
	if biome_info_display:
		_add_debug_border(biome_info_display, Color(0.5, 1.0, 0.5), "BIOME")
	if tool_selection_row:
		_add_debug_border(tool_selection_row, Color(0.5, 0.7, 1.0), "TOOLS")
	if action_preview_row:
		_add_debug_border(action_preview_row, Color(1.0, 0.5, 1.0), "ACTIONS")
	if info_panel:
		_add_debug_border(info_panel, Color.WHITE, "INFO")

	# Visualization
	if quantum_graph:
		_add_debug_border(quantum_graph, Color(1.0, 0.84, 0.0), "QUANTUM")
	if entanglement_lines:
		_add_debug_border(entanglement_lines, Color(0.5, 1.0, 0.0), "ENTANGLE")


## PUBLIC API - Query methods for other systems

func get_plot_row() -> Control:
	"""Get the plots row container"""
	return plots_row

func get_play_area() -> Control:
	"""Get the play area container"""
	return play_area

func get_action_row() -> Control:
	"""Get the actions row container"""
	return actions_row

func get_bottom_bar() -> Control:
	"""Get the bottom bar container"""
	return bottom_bar

func get_quantum_graph() -> QuantumForceGraph:
	"""Get quantum visualization system"""
	return quantum_graph

func get_entanglement_lines() -> EntanglementLines:
	"""Get entanglement visualization system"""
	return entanglement_lines
