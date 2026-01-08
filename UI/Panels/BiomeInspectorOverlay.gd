class_name BiomeInspectorOverlay
extends CanvasLayer

## Biome Inspector Overlay
## Main controller for biome inspection system
## Manages display of BiomeOvalPanels over game view

signal overlay_closed

const BiomeOvalPanel = preload("res://UI/Panels/BiomeOvalPanel.gd")

# Mode
enum DisplayMode {
	HIDDEN,
	SINGLE_BIOME,  # Show one biome
	ALL_BIOMES     # Show all biomes (scrollable)
}

var current_mode: DisplayMode = DisplayMode.HIDDEN

# UI References
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
	layer = 100  # Above game, below escape menu
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
	"""Build overlay UI structure"""

	# Dimmer (tappable background)
	dimmer = ColorRect.new()
	dimmer.color = dimmer_color
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP  # Catch taps
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	# Connect tap to close
	dimmer.gui_input.connect(_on_dimmer_input)

	# Center container (for single biome mode)
	center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	# Scroll container (for all biomes mode)
	scroll_container = ScrollContainer.new()
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll_container)

	# VBox for multiple biomes
	biome_list = VBoxContainer.new()
	biome_list.add_theme_constant_override("separation", 24)
	biome_list.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll_container.add_child(biome_list)


func _show_overlay() -> void:
	"""Show overlay and configure for current mode"""
	visible = true

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
