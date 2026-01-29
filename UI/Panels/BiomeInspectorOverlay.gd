class_name BiomeInspectorOverlay
extends "res://UI/Core/OverlayBase.gd"

## Biome Inspector Overlay
## Main controller for biome inspection system
## Manages display of BiomeOvalPanels in standard modal menu format
##
## v2 Overlay Integration:
##   Q = Select icon for details
##   E = Show icon parameters
##   R = Show registers
##   F = Cycle display mode (single -> all -> single)
##   WASD = Navigate biomes/icons
##
## Architecture:
##   Extends OverlayBase for unified overlay infrastructure.
##   Dynamic panels created on demand within scrollable content area.

const BiomeOvalPanel = preload("res://UI/Panels/BiomeOvalPanel.gd")

# Biome display order (consistent across app)
const BIOME_ORDER: Array[String] = ["StarterForest", "Village", "BioticFlux", "StellarForges", "FungalNetworks", "VolcanicWorlds"]

# v2 Navigation State
var selected_biome_index: int = 0
var selected_icon_index: int = 0

# Mode
enum DisplayMode {
	HIDDEN,
	SINGLE_BIOME,  # Show one biome
	ALL_BIOMES     # Show all biomes (scrollable)
}

var current_mode: DisplayMode = DisplayMode.HIDDEN

# UI References (biome-specific)
var biome_list: VBoxContainer

# Data references
var farm: Node = null
var current_biome_panel: BiomeOvalPanel = null
var all_biome_panels: Array[BiomeOvalPanel] = []

# Settings
var update_interval: float = 0.5
var update_timer: float = 0.0


func _init():
	# Configure OverlayBase
	overlay_name = "biome_detail"
	overlay_icon = ""
	overlay_tier = 3000  # Z_TIER_MODAL
	panel_title = "BIOME INSPECTOR"
	panel_title_size = 24
	panel_size = Vector2(700, 500)
	panel_border_color = Color(0.4, 0.7, 0.8, 0.8)  # Cyan border
	navigation_mode = NavigationMode.CALLBACK  # Custom navigation
	action_labels = {
		"Q": "Select Icon",
		"E": "Parameters",
		"R": "Registers",
		"F": "Show All"
	}


func _ready() -> void:
	super._ready()

	# Connect to biome changes so we update when user switches with ,/.
	var active_biome_manager = get_node_or_null("/root/ActiveBiomeManager")
	if active_biome_manager:
		active_biome_manager.active_biome_changed.connect(_on_active_biome_changed)


func _build_content(container: Control) -> void:
	"""Build biome-specific content inside scrollable area."""
	# VBox for biome panels list
	biome_list = VBoxContainer.new()
	biome_list.add_theme_constant_override("separation", 12)
	biome_list.alignment = BoxContainer.ALIGNMENT_BEGIN
	biome_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(biome_list)


func _get_biome_by_name(biome_name: String) -> Node:
	"""Get biome node by name from farm grid."""
	if not farm or not farm.grid or not farm.grid.biomes:
		return null
	return farm.grid.biomes.get(biome_name)


func _select_biome_by_index(index: int) -> void:
	"""Select biome panel by index and update highlight."""
	if index < 0 or index >= all_biome_panels.size():
		return
	selected_biome_index = index
	_update_selection_highlight()


## Populate single biome content (internal helper, doesn't call activate)
func _populate_single_biome(biome: Node) -> void:
	"""Set up content for a single biome without activating."""
	if not biome or not biome_list:
		return

	_clear_panels()
	current_mode = DisplayMode.SINGLE_BIOME

	# Create panel and add to scrollable area
	current_biome_panel = BiomeOvalPanel.new()
	current_biome_panel.close_requested.connect(_on_close_requested)
	current_biome_panel.emoji_tapped.connect(_on_emoji_tapped)
	biome_list.add_child(current_biome_panel)
	current_biome_panel.initialize(biome, farm.grid)
	_update_title_for_mode()


## Show single biome inspector
func show_biome(biome: Node, farm_node: Node) -> void:
	"""Display inspector for a specific biome."""
	if not biome or not farm_node:
		return

	farm = farm_node
	_populate_single_biome(biome)

	# Show panel and enable interaction
	activate()


## Populate all biomes content (internal helper, doesn't call activate)
func _populate_all_biomes() -> void:
	"""Set up content for all biomes without activating."""
	if not farm or not farm.grid or not farm.grid.biomes or not biome_list:
		return

	_clear_panels()
	current_mode = DisplayMode.ALL_BIOMES

	# Create panels in consistent order
	for biome_name in BIOME_ORDER:
		if not farm.grid.biomes.has(biome_name):
			continue
		var biome = farm.grid.biomes[biome_name]

		var panel = BiomeOvalPanel.new()
		panel.close_requested.connect(_on_close_requested)
		panel.emoji_tapped.connect(_on_emoji_tapped)
		biome_list.add_child(panel)
		panel.initialize(biome, farm.grid)
		all_biome_panels.append(panel)

	# Reset selection to first biome
	selected_biome_index = 0
	_update_selection_highlight()
	_update_title_for_mode()


## Show all biomes
func show_all_biomes(farm_node: Node) -> void:
	"""Display inspectors for all registered biomes in scrollable list."""
	if not farm_node or not farm_node.grid or not farm_node.grid.biomes:
		return

	farm = farm_node
	_populate_all_biomes()

	# Show panel and enable interaction
	activate()


## Hide overlay
func hide_overlay() -> void:
	"""Hide inspector overlay and clean up panels."""
	_clear_panels()
	current_mode = DisplayMode.HIDDEN
	deactivate()


## Toggle overlay (for button)
func toggle_all_biomes(farm_node: Node) -> void:
	"""Toggle between hidden and all biomes mode."""
	if current_mode == DisplayMode.HIDDEN:
		show_all_biomes(farm_node)
	else:
		hide_overlay()


# ============================================================================
# PANEL MANAGEMENT
# ============================================================================

func _clear_panels() -> void:
	"""Remove all biome panels immediately."""
	current_biome_panel = null
	all_biome_panels.clear()

	# Clear biome_list children
	if biome_list:
		for child in biome_list.get_children():
			biome_list.remove_child(child)
			child.free()


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

func _update_title_for_mode() -> void:
	"""Update title label based on current display mode."""
	match current_mode:
		DisplayMode.SINGLE_BIOME:
			set_title("BIOME INSPECTOR (Single View)")
		DisplayMode.ALL_BIOMES:
			set_title("BIOME INSPECTOR (All Biomes)")
		DisplayMode.HIDDEN:
			set_title("BIOME INSPECTOR")


func _on_close_requested() -> void:
	"""Handle close button from BiomeOvalPanel"""
	hide_overlay()


func _on_emoji_tapped(emoji: String) -> void:
	"""Handle emoji tap - show icon details (Tier 3)"""
	print("BiomeInspectorOverlay: Emoji tapped: %s (Tier 3 not yet implemented)" % emoji)
	# TODO: Phase 3 - Open IconDetailPanel


func _on_active_biome_changed(new_biome: String, _old_biome: String) -> void:
	"""Handle biome switch via ,/. keys while overlay is open."""
	if current_mode != DisplayMode.SINGLE_BIOME:
		return  # Only update in single biome mode

	if not farm or not farm.grid or not farm.grid.biomes:
		return

	var biome = farm.grid.biomes.get(new_biome)
	if not biome:
		return

	# Update selected_biome_index to match new biome
	selected_biome_index = BIOME_ORDER.find(new_biome)
	if selected_biome_index < 0:
		selected_biome_index = 0

	# Refresh display with new biome (use internal helper since already active)
	_populate_single_biome(biome)


# ============================================================================
# OVERRIDES FOR CUSTOM INPUT HANDLING
# ============================================================================

func _on_unhandled_key(keycode: int, _event: InputEvent) -> bool:
	"""Handle keys not caught by OverlayBase standard routing."""
	match keycode:
		KEY_COMMA, KEY_PERIOD:
			# Don't consume biome cycling keys - let QuantumInstrumentInput handle them
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

	return false


# ============================================================================
# V2 OVERLAY INTERFACE OVERRIDES
# ============================================================================

func _on_activated() -> void:
	"""Called when overlay opens.

	Note: Only populates content if not already showing something.
	When show_biome() or show_all_biomes() calls activate(), content
	is already set up, so we skip re-population to avoid recursion.
	"""
	# If already showing content, don't re-populate (avoid recursion)
	if current_mode != DisplayMode.HIDDEN:
		return

	if farm:
		# Show only the currently active biome (not all 4)
		var active_biome_manager = get_node_or_null("/root/ActiveBiomeManager")
		if active_biome_manager:
			var active_biome_name = active_biome_manager.get_active_biome()
			var biome = _get_biome_by_name(active_biome_name)
			if biome:
				_populate_single_biome(biome)
				return
		# Fallback: show first biome if no active biome manager
		if farm.grid and farm.grid.biomes:
			for biome_name in BIOME_ORDER:
				if farm.grid.biomes.has(biome_name):
					_populate_single_biome(farm.grid.biomes[biome_name])
					return


func _on_deactivated() -> void:
	"""Called when overlay closes - just cleanup, don't call deactivate() again."""
	_clear_panels()
	current_mode = DisplayMode.HIDDEN


func _on_action_q() -> void:
	"""Q = Select current icon for details."""
	var biome = _get_selected_biome()
	if biome and biome.icon_registry:
		var icons = biome.icon_registry.get_all_icons()
		if selected_icon_index >= 0 and selected_icon_index < icons.size():
			var icon = icons[selected_icon_index]
			action_performed.emit("select_icon", {"icon": icon, "biome": biome.biome_name})
			print("Selected icon: %s" % icon.get("emoji", "?"))


func _on_action_e() -> void:
	"""E = Show icon parameters (hamiltonians, lindblads)."""
	var biome = _get_selected_biome()
	if biome:
		action_performed.emit("show_parameters", {"biome": biome.biome_name})
		print("Parameters for: %s" % biome.biome_name)


func _on_action_r() -> void:
	"""R = Show register mappings."""
	var biome = _get_selected_biome()
	if biome and biome.quantum_computer:
		action_performed.emit("show_registers", {"biome": biome.biome_name})
		print("Registers for: %s" % biome.biome_name)


func _on_action_f() -> void:
	"""F = Cycle display mode (single biome <-> all biomes)."""
	# Use internal helpers since overlay is already active (avoid re-activation)
	if current_mode == DisplayMode.SINGLE_BIOME:
		if farm:
			_populate_all_biomes()
	elif current_mode == DisplayMode.ALL_BIOMES:
		# Switch to first biome single view
		var biome = _get_selected_biome()
		if biome and farm:
			_populate_single_biome(biome)
	action_performed.emit("cycle_mode", {"mode": current_mode})


func get_action_labels() -> Dictionary:
	"""Get current QER+F labels."""
	var labels = action_labels.duplicate()
	# Context-sensitive F label
	if current_mode == DisplayMode.SINGLE_BIOME:
		labels["F"] = "Show All"
	elif current_mode == DisplayMode.ALL_BIOMES:
		labels["F"] = "Single View"
	return labels


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
	"""Show inspector for the biome assigned to a plot"""
	if not farm_node or not farm_node.grid:
		return

	var biome_name = farm_node.grid.plot_biome_assignments.get(plot_pos, "")
	if biome_name.is_empty():
		print("Plot %s has no biome assignment" % plot_pos)
		return

	var biome = farm_node.grid.biomes.get(biome_name)
	if not biome:
		print("Biome '%s' not found" % biome_name)
		return

	# Show this biome with plot highlighted
	show_biome(biome, farm_node)


## Check if overlay is visible
func is_overlay_visible() -> bool:
	"""Check if any overlay mode is active"""
	return current_mode != DisplayMode.HIDDEN
