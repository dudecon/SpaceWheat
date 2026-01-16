class_name BiomeInspectorOverlay
extends Control

## Biome Inspector Overlay
## Main controller for biome inspection system
## Manages display of BiomeOvalPanels over game view
##
## v2 Overlay Integration:
##   Q = Select icon for details
##   E = Show icon parameters
##   R = Show registers
##   F = Cycle display mode (single → all → single)
##   WASD = Navigate biomes/icons
##
## Architecture:
##   Extends Control for unified overlay stack management.
##   Uses internal CanvasLayer (render_layer) for rendering above game.

signal overlay_closed
signal action_performed(action: String, data: Dictionary)  # v2 overlay compatibility

const BiomeOvalPanel = preload("res://UI/Panels/BiomeOvalPanel.gd")

# v2 Overlay Interface
var overlay_name: String = "biome_detail"
var overlay_icon: String = "🔬"
var overlay_tier: int = 3000  # Z_TIER_MODAL - renders above INFO overlays
var action_labels: Dictionary = {
	"Q": "Select Icon",
	"E": "Parameters",
	"R": "Registers",
	"F": "Cycle Mode"
}

# v2 Navigation State
var selected_biome_index: int = 0
var selected_icon_index: int = 0
var is_active: bool = false

# Mode
enum DisplayMode {
	HIDDEN,
	SINGLE_BIOME,  # Show one biome
	ALL_BIOMES     # Show all biomes (scrollable)
}

var current_mode: DisplayMode = DisplayMode.HIDDEN

# UI References
var render_layer: CanvasLayer  # Child CanvasLayer for rendering above game
var dimmer: ColorRect  # Dims background
var center_container: CenterContainer  # For single biome mode
var scroll_container: ScrollContainer  # For all biomes mode
var biome_list: VBoxContainer  # Container for multiple panels

# Data references
var farm: Node = null
var current_biome_panel: BiomeOvalPanel = null
var all_biome_panels: Array[BiomeOvalPanel] = []

# Settings
var dimmer_color: Color = Color(0, 0, 0, 0.5)
var update_interval: float = 0.5  # Update overlay every 0.5s
var update_timer: float = 0.0

func _ready():
	# Set up as full-rect Control (z_index managed by OverlayStackManager)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let render_layer handle input
	_build_ui()
	hide_overlay()


## Show single biome inspector
func show_biome(biome: Node, farm_node: Node) -> void:
	"""Display inspector for a specific biome"""
	if not biome or not farm_node:
		print("⚠️  BiomeInspectorOverlay: Invalid biome or farm")
		return

	farm = farm_node
	current_mode = DisplayMode.SINGLE_BIOME

	# Clear existing
	_clear_panels()

	# Create panel for this biome
	current_biome_panel = BiomeOvalPanel.new()
	current_biome_panel.initialize(biome, farm.grid)
	current_biome_panel.close_requested.connect(_on_close_requested)
	current_biome_panel.emoji_tapped.connect(_on_emoji_tapped)

	center_container.add_child(current_biome_panel)

	# Show overlay
	_show_overlay()

	print("🔍 BiomeInspectorOverlay: Showing %s" % biome)


## Show all biomes
func show_all_biomes(farm_node: Node) -> void:
	"""Display inspectors for all registered biomes"""
	if not farm_node:
		print("⚠️  BiomeInspectorOverlay: Invalid farm")
		return

	farm = farm_node
	current_mode = DisplayMode.ALL_BIOMES

	# Clear existing
	_clear_panels()

	# Get all biomes from farm grid
	if not farm.grid or not farm.grid.biomes:
		print("⚠️  BiomeInspectorOverlay: No biomes registered")
		return

	# Create panel for each biome
	for biome_name in farm.grid.biomes.keys():
		var biome = farm.grid.biomes[biome_name]

		var panel = BiomeOvalPanel.new()
		panel.initialize(biome, farm.grid)
		panel.close_requested.connect(_on_close_requested)
		panel.emoji_tapped.connect(_on_emoji_tapped)

		biome_list.add_child(panel)
		all_biome_panels.append(panel)

	# Show overlay
	_show_overlay()

	print("🔍 BiomeInspectorOverlay: Showing all %d biomes" % all_biome_panels.size())


## Hide overlay
func hide_overlay() -> void:
	"""Hide inspector overlay"""
	current_mode = DisplayMode.HIDDEN
	_clear_panels()
	visible = false
	if render_layer:
		render_layer.visible = false
	overlay_closed.emit()


## Toggle overlay (for button)
func toggle_all_biomes(farm_node: Node) -> void:
	"""Toggle between hidden and all biomes mode"""
	if current_mode == DisplayMode.HIDDEN:
		show_all_biomes(farm_node)
	else:
		hide_overlay()


# ============================================================================
# UI SETUP
# ============================================================================

func _build_ui() -> void:
	"""Build overlay UI structure

	Creates a CanvasLayer child for rendering above game view.
	All visual elements are added to the render_layer.
	"""
	# Create CanvasLayer for rendering above game (layer 100 = above game, below system menus)
	render_layer = CanvasLayer.new()
	render_layer.layer = 100
	add_child(render_layer)

	# Dimmer (tappable background) - added to render_layer
	dimmer = ColorRect.new()
	dimmer.color = dimmer_color
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP  # Catch taps
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	render_layer.add_child(dimmer)

	# Connect tap to close
	dimmer.gui_input.connect(_on_dimmer_input)

	# Center container (for single biome mode)
	center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	render_layer.add_child(center_container)

	# Scroll container (for all biomes mode)
	scroll_container = ScrollContainer.new()
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	render_layer.add_child(scroll_container)

	# VBox for multiple biomes
	biome_list = VBoxContainer.new()
	biome_list.add_theme_constant_override("separation", 24)
	biome_list.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll_container.add_child(biome_list)


func _show_overlay() -> void:
	"""Show overlay and configure for current mode"""
	visible = true
	render_layer.visible = true

	# Show/hide containers based on mode
	center_container.visible = (current_mode == DisplayMode.SINGLE_BIOME)
	scroll_container.visible = (current_mode == DisplayMode.ALL_BIOMES)

	# Reset update timer
	update_timer = 0.0


func _clear_panels() -> void:
	"""Remove all biome panels"""
	# Clear single biome
	if current_biome_panel:
		current_biome_panel.queue_free()
		current_biome_panel = null

	# Clear all biomes
	for panel in all_biome_panels:
		panel.queue_free()
	all_biome_panels.clear()

	# Clear list children
	for child in biome_list.get_children():
		child.queue_free()

	# Clear center children
	for child in center_container.get_children():
		child.queue_free()


# ============================================================================
# UPDATE LOOP
# ============================================================================

func _process(delta: float) -> void:
	"""Update overlay data periodically"""
	if current_mode == DisplayMode.HIDDEN:
		return

	update_timer += delta
	if update_timer >= update_interval:
		_refresh_all_panels()
		update_timer = 0.0


func _refresh_all_panels() -> void:
	"""Refresh data in all visible panels"""
	if current_mode == DisplayMode.SINGLE_BIOME and current_biome_panel:
		current_biome_panel.refresh_data()

	elif current_mode == DisplayMode.ALL_BIOMES:
		for panel in all_biome_panels:
			panel.refresh_data()


# ============================================================================
# INPUT HANDLING
# ============================================================================

func _on_dimmer_input(event: InputEvent) -> void:
	"""Handle tap on dimmed background (close overlay)"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("🔍 BiomeInspectorOverlay: Background tapped, closing")
			hide_overlay()

	elif event is InputEventScreenTouch:
		# TODO: Add gesture discrimination (tap vs accidental touch, swipe vs tap)
		# Current implementation closes on any touch - needs refinement
		# See: /home/tehcr33d/ws/SpaceWheat/llm_outbox/TOUCH_CODE_AUDIT.md
		if event.pressed:
			print("🔍 BiomeInspectorOverlay: Background tapped (touch), closing")
			hide_overlay()


func _on_close_requested() -> void:
	"""Handle close button from BiomeOvalPanel"""
	hide_overlay()


func _on_emoji_tapped(emoji: String) -> void:
	"""Handle emoji tap - show icon details (Tier 3)"""
	print("🔍 BiomeInspectorOverlay: Emoji tapped: %s (Tier 3 not yet implemented)" % emoji)
	# TODO: Phase 3 - Open IconDetailPanel


# ============================================================================
# V2 OVERLAY INTERFACE
# ============================================================================

func handle_input(event: InputEvent) -> bool:
	"""Modal input handler for v2 overlay system.

	Returns true if input was consumed, false otherwise.
	"""
	if not visible or current_mode == DisplayMode.HIDDEN:
		return false

	if not event is InputEventKey or not event.pressed or event.echo:
		return false

	match event.keycode:
		KEY_ESCAPE:
			# Don't consume ESC - let PlayerShell._handle_shell_action() call
			# overlay_stack.handle_escape() which properly pops us from the stack.
			# If we consume ESC here, we get hidden but stay on the stack!
			return false
		# WASD/Arrow navigation
		KEY_W, KEY_UP:
			_navigate_up()
			return true
		KEY_S, KEY_DOWN:
			_navigate_down()
			return true
		KEY_A, KEY_LEFT:
			_navigate_left()
			return true
		KEY_D, KEY_RIGHT:
			_navigate_right()
			return true
		# QER+F actions
		KEY_Q:
			on_q_pressed()
			return true
		KEY_E:
			on_e_pressed()
			return true
		KEY_R:
			on_r_pressed()
			return true
		KEY_F:
			on_f_pressed()
			return true

	return false


func activate() -> void:
	"""v2 overlay lifecycle: Called when overlay opens."""
	is_active = true

	# Show render layer (ensures visibility even without content)
	if render_layer:
		render_layer.visible = true

	# Default to showing all biomes if farm is set
	if farm:
		show_all_biomes(farm)


func deactivate() -> void:
	"""v2 overlay lifecycle: Called when overlay closes."""
	is_active = false
	hide_overlay()


func on_q_pressed() -> void:
	"""Q = Select current icon for details."""
	var biome = _get_selected_biome()
	if biome and biome.icon_registry:
		var icons = biome.icon_registry.get_all_icons()
		if selected_icon_index >= 0 and selected_icon_index < icons.size():
			var icon = icons[selected_icon_index]
			action_performed.emit("select_icon", {"icon": icon, "biome": biome.biome_name})
			print("🔬 Selected icon: %s" % icon.get("emoji", "?"))


func on_e_pressed() -> void:
	"""E = Show icon parameters (hamiltonians, lindblads)."""
	var biome = _get_selected_biome()
	if biome:
		action_performed.emit("show_parameters", {"biome": biome.biome_name})
		print("🔬 Parameters for: %s" % biome.biome_name)


func on_r_pressed() -> void:
	"""R = Show register mappings."""
	var biome = _get_selected_biome()
	if biome and biome.quantum_computer:
		action_performed.emit("show_registers", {"biome": biome.biome_name})
		print("🔬 Registers for: %s" % biome.biome_name)


func on_f_pressed() -> void:
	"""F = Cycle display mode (single biome ↔ all biomes)."""
	if current_mode == DisplayMode.SINGLE_BIOME:
		if farm:
			show_all_biomes(farm)
	elif current_mode == DisplayMode.ALL_BIOMES:
		# Switch to first biome single view
		var biome = _get_selected_biome()
		if biome and farm:
			show_biome(biome, farm)
	action_performed.emit("cycle_mode", {"mode": current_mode})


func get_action_labels() -> Dictionary:
	"""v2 overlay interface: Get current QER+F labels."""
	return action_labels


func get_overlay_tier() -> int:
	"""Get z-index tier for OverlayStackManager."""
	return overlay_tier


func get_overlay_info() -> Dictionary:
	"""v2 overlay interface: Get overlay metadata for registration."""
	return {
		"name": overlay_name,
		"icon": overlay_icon,
		"action_labels": get_action_labels(),
		"tier": overlay_tier
	}


func _navigate_up() -> void:
	"""Navigate up in icon/biome list."""
	if current_mode == DisplayMode.ALL_BIOMES:
		selected_biome_index = maxi(0, selected_biome_index - 1)
		_update_selection_highlight()
	elif current_mode == DisplayMode.SINGLE_BIOME:
		selected_icon_index = maxi(0, selected_icon_index - 1)
		_update_selection_highlight()


func _navigate_down() -> void:
	"""Navigate down in icon/biome list."""
	if current_mode == DisplayMode.ALL_BIOMES:
		selected_biome_index = mini(all_biome_panels.size() - 1, selected_biome_index + 1)
		_update_selection_highlight()
	elif current_mode == DisplayMode.SINGLE_BIOME:
		var biome = _get_selected_biome()
		if biome and biome.icon_registry:
			var max_idx = biome.icon_registry.get_all_icons().size() - 1
			selected_icon_index = mini(max_idx, selected_icon_index + 1)
		_update_selection_highlight()


func _navigate_left() -> void:
	"""Navigate left (previous biome in all mode)."""
	if current_mode == DisplayMode.ALL_BIOMES:
		selected_biome_index = maxi(0, selected_biome_index - 1)
		_update_selection_highlight()


func _navigate_right() -> void:
	"""Navigate right (next biome in all mode)."""
	if current_mode == DisplayMode.ALL_BIOMES:
		selected_biome_index = mini(all_biome_panels.size() - 1, selected_biome_index + 1)
		_update_selection_highlight()


func _get_selected_biome():
	"""Get currently selected biome based on mode."""
	if current_mode == DisplayMode.SINGLE_BIOME and current_biome_panel:
		return current_biome_panel.biome
	elif current_mode == DisplayMode.ALL_BIOMES:
		if selected_biome_index >= 0 and selected_biome_index < all_biome_panels.size():
			return all_biome_panels[selected_biome_index].biome
	return null


func _update_selection_highlight() -> void:
	"""Update visual selection indicators."""
	# Highlight selected biome panel
	for i in range(all_biome_panels.size()):
		var panel = all_biome_panels[i]
		if panel.has_method("set_selected"):
			panel.set_selected(i == selected_biome_index)

	# TODO: Highlight selected icon within panel


# ============================================================================
# PUBLIC API
# ============================================================================

## Inspect biome for a specific plot (Tool 6 integration)
func inspect_plot_biome(plot_pos: Vector2i, farm_node: Node) -> void:
	"""Show inspector for the biome assigned to a plot

	Used by Tool 6 R (Inspect) action
	"""
	if not farm_node or not farm_node.grid:
		return

	var biome_name = farm_node.grid.plot_biome_assignments.get(plot_pos, "")
	if biome_name.is_empty():
		print("⚠️  Plot %s has no biome assignment" % plot_pos)
		return

	var biome = farm_node.grid.biomes.get(biome_name)
	if not biome:
		print("⚠️  Biome '%s' not found" % biome_name)
		return

	# Show this biome with plot highlighted
	show_biome(biome, farm_node)

	# TODO: Highlight the specific plot in projection list


## Check if overlay is visible
func is_overlay_visible() -> bool:
	"""Check if any overlay mode is active"""
	return current_mode != DisplayMode.HIDDEN
