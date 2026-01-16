class_name InspectorOverlay
extends "res://UI/Overlays/V2OverlayBase.gd"

## InspectorOverlay - Density matrix visualization with register selection
##
## Primary analysis overlay for v2 architecture. Displays:
##   - Density matrix heatmap (|ρ_ij| magnitudes)
##   - Probability bars for each register
##   - Per-register details (amplitude, phase, entropy)
##
## Controls:
##   Q = Select/confirm register
##   E = Show register details
##   R = Compare with another register
##   F = Cycle view mode (heatmap → bars → heatmap)
##   WASD = Navigate registers
##   ESC = Close overlay

# View modes
enum ViewMode { HEATMAP, PROBABILITY_BARS }
const VIEW_MODE_NAMES = ["Density Matrix", "Probability Bars"]

var current_view_mode: int = ViewMode.HEATMAP

# Data sources
var biome = null  # BiomeBase reference
var quantum_computer = null  # QuantumComputer reference
var register_data: Array = []  # Cached register info

# UI components
var title_label: Label
var view_mode_label: Label
var heatmap_container: Control
var bars_container: Control
var details_panel: Control
var register_grid: GridContainer

# Visual constants
const PANEL_WIDTH: int = 600
const PANEL_HEIGHT: int = 450
const HEATMAP_SIZE: int = 280
const CELL_SIZE: int = 24
const BAR_HEIGHT: int = 20
const BAR_MAX_WIDTH: int = 200

# Auto-refresh settings (matches BiomeInspectorOverlay pattern)
var update_interval: float = 0.5  # Update every 0.5s when visible
var update_timer: float = 0.0


func _init():
	overlay_name = "inspector"
	overlay_icon = "📊"
	action_labels = {
		"Q": "Select",
		"E": "Details",
		"R": "Compare",
		"F": "View Mode"
	}


func _ready() -> void:
	super._ready()
	_build_ui()


func _build_ui() -> void:
	"""Build the inspector overlay UI."""
	# Main panel styling
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.14, 0.95)
	panel_style.border_color = Color(0.3, 0.5, 0.7, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", panel_style)

	# Main layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# Title bar
	var title_bar = _create_title_bar()
	vbox.add_child(title_bar)

	# Content area (heatmap or bars)
	var content_container = Control.new()
	content_container.custom_minimum_size = Vector2(0, 300)
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_container)

	# Heatmap view
	heatmap_container = _create_heatmap_view()
	heatmap_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_container.add_child(heatmap_container)

	# Probability bars view
	bars_container = _create_bars_view()
	bars_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	bars_container.visible = false
	content_container.add_child(bars_container)

	# Details panel (bottom)
	details_panel = _create_details_panel()
	vbox.add_child(details_panel)


func _create_title_bar() -> Control:
	"""Create title bar with overlay name and view mode."""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	# Title
	title_label = Label.new()
	title_label.text = "📊 Inspector"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	hbox.add_child(title_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# View mode indicator
	view_mode_label = Label.new()
	view_mode_label.text = "[F] %s" % VIEW_MODE_NAMES[current_view_mode]
	view_mode_label.add_theme_font_size_override("font_size", 14)
	view_mode_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	hbox.add_child(view_mode_label)

	return hbox


func _create_heatmap_view() -> Control:
	"""Create density matrix heatmap visualization."""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	# Heatmap label
	var label = Label.new()
	label.text = "Density Matrix ρ (magnitude)"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	container.add_child(label)

	# Heatmap grid
	register_grid = GridContainer.new()
	register_grid.columns = 1  # Will be set dynamically
	container.add_child(register_grid)

	return container


func _create_bars_view() -> Control:
	"""Create probability bar chart visualization."""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	var label = Label.new()
	label.text = "Register Probabilities (diagonal of ρ)"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	container.add_child(label)

	return container


func _create_details_panel() -> Control:
	"""Create details panel for selected register."""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.9)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Selected Register Details"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	vbox.add_child(title)

	var info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.text = "Use WASD to select a register, E for details"
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vbox.add_child(info_label)

	return panel


# ============================================================================
# LIFECYCLE
# ============================================================================

func activate() -> void:
	"""Called when overlay opens - refresh data."""
	super.activate()

	# Auto-find biome if not set
	if not biome:
		_auto_find_biome()

	_refresh_data()
	_update_view()
	update_timer = 0.0  # Reset timer on open


func deactivate() -> void:
	"""Called when overlay closes."""
	super.deactivate()
	update_timer = 0.0


func _process(delta: float) -> void:
	"""Periodic refresh while overlay is visible.

	Updates density matrix display every 0.5s to show:
	- Quantum evolution changes
	- Measurement collapse effects
	- Gate application results
	"""
	if not visible:
		return

	update_timer += delta
	if update_timer >= update_interval:
		_refresh_data()
		_update_view()
		update_timer = 0.0


func _auto_find_biome() -> void:
	"""Auto-detect the current biome from farm/selected plot."""
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and "active_farm" in gsm and gsm.active_farm:
		var farm = gsm.active_farm
		if farm.has_method("get") and "grid" in farm and farm.grid:
			# Get the first biome as default
			var biomes = farm.grid.get_biomes() if farm.grid.has_method("get_biomes") else []
			if biomes.size() > 0:
				set_biome(biomes[0])
				return

	# Fallback: search scene tree for Farm
	var farm = _find_node_recursive(get_tree().root, "Farm")
	if farm and "grid" in farm and farm.grid:
		var biomes = farm.grid.get_biomes() if farm.grid.has_method("get_biomes") else []
		if biomes.size() > 0:
			set_biome(biomes[0])


func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node_recursive(child, target_name)
		if found:
			return found
	return null


func set_biome(b) -> void:
	"""Set the biome to inspect."""
	biome = b
	if biome and "quantum_computer" in biome:
		quantum_computer = biome.quantum_computer
	elif biome and biome.has_method("get_quantum_computer"):
		quantum_computer = biome.get_quantum_computer()
	_refresh_data()


func _refresh_data() -> void:
	"""Refresh register data from quantum computer."""
	register_data.clear()

	if not quantum_computer:
		return

	var rho = quantum_computer.get_density_matrix()
	if not rho:
		return

	var dim = rho.n  # ComplexMatrix uses .n for dimension
	var register_map = quantum_computer.register_map if quantum_computer.has("register_map") else null

	for i in range(dim):
		var diag = rho.get_element(i, i)
		var prob = diag.re if diag else 0.0

		var reg_info = {
			"index": i,
			"probability": prob,
			"emoji": "?",
			"coherence": 0.0
		}

		# Try to get emoji from register map
		if register_map and register_map.has_method("get_register"):
			var reg = register_map.get_register(i)
			if reg:
				reg_info["emoji"] = reg.get("north_emoji", reg.get("north", "?"))

		# Calculate coherence (sum of off-diagonal magnitudes)
		var coh = 0.0
		for j in range(dim):
			if j != i:
				var off_diag = rho.get_element(i, j)
				if off_diag:
					coh += sqrt(off_diag.re * off_diag.re + off_diag.im * off_diag.im)
		reg_info["coherence"] = coh

		register_data.append(reg_info)

	# Set up selectable items and grid
	set_selectable_items(register_data, mini(dim, 8))


# ============================================================================
# VIEW UPDATES
# ============================================================================

func _update_view() -> void:
	"""Update the visualization based on current view mode."""
	view_mode_label.text = "[F] %s" % VIEW_MODE_NAMES[current_view_mode]

	heatmap_container.visible = (current_view_mode == ViewMode.HEATMAP)
	bars_container.visible = (current_view_mode == ViewMode.PROBABILITY_BARS)

	if current_view_mode == ViewMode.HEATMAP:
		_update_heatmap()
	else:
		_update_bars()

	_update_details()


func _update_heatmap() -> void:
	"""Update the density matrix heatmap."""
	# Clear existing cells
	for child in register_grid.get_children():
		child.queue_free()

	if register_data.is_empty():
		return

	var dim = register_data.size()
	register_grid.columns = dim

	# Create heatmap cells
	for i in range(dim):
		for j in range(dim):
			var cell = _create_heatmap_cell(i, j)
			register_grid.add_child(cell)


func _create_heatmap_cell(row: int, col: int) -> Control:
	"""Create a single heatmap cell."""
	var cell = Panel.new()
	cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)

	# Get magnitude from density matrix
	var magnitude = 0.0
	if quantum_computer:
		var rho = quantum_computer.get_density_matrix()
		if rho:
			var elem = rho.get_element(row, col)
			if elem:
				magnitude = sqrt(elem.re * elem.re + elem.im * elem.im)

	# Color based on magnitude (blue to red gradient)
	var style = StyleBoxFlat.new()
	if row == col:
		# Diagonal - probability (green gradient)
		style.bg_color = Color(0.1, 0.3 + 0.7 * magnitude, 0.2, 1.0)
	else:
		# Off-diagonal - coherence (blue-purple gradient)
		style.bg_color = Color(0.2 + 0.6 * magnitude, 0.1, 0.4 + 0.5 * magnitude, 1.0)

	# Highlight selected
	if row == selected_index or col == selected_index:
		style.border_color = Color(1.0, 0.9, 0.3, 1.0)
		style.set_border_width_all(2)

	cell.add_theme_stylebox_override("panel", style)
	return cell


func _update_bars() -> void:
	"""Update the probability bar chart."""
	# Clear existing bars
	for child in bars_container.get_children():
		if child is not Label:
			child.queue_free()

	for i in range(register_data.size()):
		var reg = register_data[i]
		var bar_row = _create_bar_row(i, reg)
		bars_container.add_child(bar_row)


func _create_bar_row(index: int, reg: Dictionary) -> Control:
	"""Create a probability bar row."""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Emoji label
	var emoji_label = Label.new()
	emoji_label.text = reg.get("emoji", "?")
	emoji_label.custom_minimum_size = Vector2(30, 0)
	emoji_label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(emoji_label)

	# Index label
	var index_label = Label.new()
	index_label.text = "[%d]" % index
	index_label.custom_minimum_size = Vector2(30, 0)
	index_label.add_theme_font_size_override("font_size", 12)
	index_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	hbox.add_child(index_label)

	# Bar
	var bar = Panel.new()
	var prob = reg.get("probability", 0.0)
	bar.custom_minimum_size = Vector2(BAR_MAX_WIDTH * prob, BAR_HEIGHT)

	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.3, 0.6, 0.9, 0.8)
	if index == selected_index:
		bar_style.bg_color = Color(0.9, 0.7, 0.2, 0.9)
	bar_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("panel", bar_style)
	hbox.add_child(bar)

	# Probability text
	var prob_label = Label.new()
	prob_label.text = "%.1f%%" % (prob * 100)
	prob_label.add_theme_font_size_override("font_size", 12)
	prob_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	hbox.add_child(prob_label)

	return hbox


func _update_details() -> void:
	"""Update the details panel for selected register."""
	var info_label = details_panel.find_child("InfoLabel", true, false)
	if not info_label:
		return

	if selected_index < 0 or selected_index >= register_data.size():
		info_label.text = "Use WASD to select a register, E for details"
		return

	var reg = register_data[selected_index]
	info_label.text = "Register %d: %s | P=%.2f%% | Coherence=%.3f" % [
		selected_index,
		reg.get("emoji", "?"),
		reg.get("probability", 0.0) * 100,
		reg.get("coherence", 0.0)
	]


func _update_selection_visual() -> void:
	"""Update visual highlight of selected register."""
	_update_view()


# ============================================================================
# ACTION HANDLERS
# ============================================================================

func on_q_pressed() -> void:
	"""Q = Confirm selection / Toggle selection."""
	if selected_index >= 0 and selected_index < register_data.size():
		var reg = register_data[selected_index]
		action_performed.emit("select_register", {"index": selected_index, "data": reg})


func on_e_pressed() -> void:
	"""E = Show detailed register information."""
	if selected_index >= 0 and selected_index < register_data.size():
		var reg = register_data[selected_index]
		_show_register_details(reg)
		action_performed.emit("show_details", {"index": selected_index, "data": reg})


func on_r_pressed() -> void:
	"""R = Compare with another register (future feature)."""
	action_performed.emit("compare_states", {"selected": selected_index})


func on_f_pressed() -> void:
	"""F = Cycle view mode."""
	current_view_mode = (current_view_mode + 1) % VIEW_MODE_NAMES.size()
	_update_view()
	action_performed.emit("cycle_view_mode", {"mode": VIEW_MODE_NAMES[current_view_mode]})


func _show_register_details(reg: Dictionary) -> void:
	"""Show detailed information popup for a register."""
	var info_label = details_panel.find_child("InfoLabel", true, false)
	if info_label:
		var details = "Register %d: %s\n" % [reg.get("index", -1), reg.get("emoji", "?")]
		details += "Probability: %.4f (%.2f%%)\n" % [reg.get("probability", 0.0), reg.get("probability", 0.0) * 100]
		details += "Coherence: %.4f\n" % reg.get("coherence", 0.0)
		info_label.text = details
