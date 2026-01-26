class_name BiomeOvalPanel
extends PanelContainer

## Biome Oval Panel - UPGRADED
## Displays comprehensive quantum computer information for a biome
## Shows qubit axes, Hamiltonian couplings, Lindblad dissipation

signal close_requested
signal emoji_tapped(emoji: String)

const BiomeInspectionController = preload("res://Core/Visualization/BiomeInspectionController.gd")

# UI References
var title_bar: HBoxContainer
var biome_name_label: Label
var close_button: Button
var main_vbox: VBoxContainer

# Quantum state section
var purity_bar: HBoxContainer
var entropy_bar: HBoxContainer
var coherence_bar: HBoxContainer
var dimension_label: Label
var dynamics_label: Label

# Icon populations section (harvest probabilities)
var populations_container: HBoxContainer

# Qubit axes section
var qubit_axes_container: GridContainer

# Hamiltonian section
var hamiltonian_label: Label

# Lindblad section
var lindblad_label: Label

# Data
var biome: Node = null
var farm_grid: Node = null
var biome_data: Dictionary = {}
var quantum_detail: Dictionary = {}

# Visual settings - sized to fit play area (6%-72% of viewport)
var panel_width: int = 900
var panel_height: int = 340
var bg_color: Color = Color(0.08, 0.08, 0.12, 0.98)
var border_color: Color = Color(0.3, 0.5, 0.7, 1.0)
var corner_radius: int = 12

# Font sizes - compact but readable
var title_size: int = 22
var section_header_size: int = 13
var normal_size: int = 14
var small_size: int = 12

func _ready():
	_setup_panel_style()
	_build_ui()
	custom_minimum_size = Vector2(panel_width, panel_height)


## Initialize with biome and grid
func initialize(biome_node: Node, grid_node: Node) -> void:
	"""Set biome to inspect and refresh display"""
	biome = biome_node
	farm_grid = grid_node

	# Only refresh if we're in the tree (meaning _ready() has run)
	if is_inside_tree():
		refresh_data()
	else:
		# If not in tree yet, defer until we are
		call_deferred("refresh_data")


## Refresh all data from biome
func refresh_data() -> void:
	"""Query biome and update all UI elements"""
	if not biome or not farm_grid:
		return

	# Get basic data
	biome_data = BiomeInspectionController.get_biome_data(biome, farm_grid)

	# Get detailed quantum data
	quantum_detail = BiomeInspectionController.get_quantum_detail(biome)

	# Update UI
	_update_title_bar()
	_update_quantum_state()
	_update_populations()
	_update_qubit_axes()
	_update_hamiltonian()
	_update_lindblad()


# ============================================================================
# UI SETUP
# ============================================================================

func _setup_panel_style() -> void:
	"""Configure panel appearance"""
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	add_theme_stylebox_override("panel", style)


func _build_ui() -> void:
	"""Construct UI hierarchy - HORIZONTAL LAYOUT to fit play area"""
	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# Add margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	main_vbox.add_child(margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(content_vbox)

	# === ROW 1: Title bar with inline stats ===
	title_bar = _create_title_bar()
	content_vbox.add_child(title_bar)

	# === ROW 2: Horizontal layout - State + Populations ===
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 24)
	content_vbox.add_child(row2)

	# Left: Quantum state (compact vertical)
	var state_vbox = VBoxContainer.new()
	state_vbox.add_theme_constant_override("separation", 4)
	state_vbox.custom_minimum_size.x = 220
	row2.add_child(state_vbox)

	state_vbox.add_child(_create_section_header("QUANTUM STATE"))

	dimension_label = Label.new()
	dimension_label.add_theme_font_size_override("font_size", small_size)
	state_vbox.add_child(dimension_label)

	purity_bar = _create_stat_bar("Purity", 0.5, Color(0.3, 0.7, 1.0))
	state_vbox.add_child(purity_bar)

	entropy_bar = _create_stat_bar("Entropy", 0.0, Color(1.0, 0.5, 0.3))
	state_vbox.add_child(entropy_bar)

	coherence_bar = _create_stat_bar("Coherence", 0.0, Color(0.7, 0.3, 1.0))
	state_vbox.add_child(coherence_bar)

	# Dynamics stability label
	dynamics_label = Label.new()
	dynamics_label.text = "⚡ Stable"
	dynamics_label.add_theme_font_size_override("font_size", small_size)
	dynamics_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	state_vbox.add_child(dynamics_label)

	# Right: Populations (harvest probabilities)
	var pop_vbox = VBoxContainer.new()
	pop_vbox.add_theme_constant_override("separation", 4)
	pop_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(pop_vbox)

	pop_vbox.add_child(_create_section_header("HARVEST PROBABILITIES"))

	populations_container = HBoxContainer.new()
	populations_container.add_theme_constant_override("separation", 12)
	pop_vbox.add_child(populations_container)

	# === ROW 3: Qubit axes (2-column grid) ===
	content_vbox.add_child(_create_section_header("QUBIT AXES"))

	qubit_axes_container = GridContainer.new()
	qubit_axes_container.columns = 2
	qubit_axes_container.add_theme_constant_override("h_separation", 24)
	qubit_axes_container.add_theme_constant_override("v_separation", 4)
	content_vbox.add_child(qubit_axes_container)

	# === Hidden sections (accessed via E key for details) ===
	hamiltonian_label = Label.new()
	hamiltonian_label.visible = false
	content_vbox.add_child(hamiltonian_label)

	lindblad_label = Label.new()
	lindblad_label.visible = false
	content_vbox.add_child(lindblad_label)


func _create_title_bar() -> HBoxContainer:
	"""Create top bar with biome name + close button"""
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Biome emoji + name
	biome_name_label = Label.new()
	biome_name_label.text = "🌍 Biome"
	biome_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	biome_name_label.add_theme_font_size_override("font_size", title_size)
	biome_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(biome_name_label)

	# Close button
	close_button = Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(40, 40)
	close_button.add_theme_font_size_override("font_size", 32)
	close_button.pressed.connect(_on_close_button_pressed)
	hbox.add_child(close_button)

	return hbox


func _create_section_header(text: String) -> Label:
	"""Create a section header label"""
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", section_header_size)
	label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	return label


func _create_stat_bar(label_text: String, value: float, color: Color) -> HBoxContainer:
	"""Create a compact labeled progress bar for stats"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	# Label
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 55
	label.add_theme_font_size_override("font_size", small_size)
	hbox.add_child(label)

	# Bar background
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.2, 0.2)
	bar_bg.custom_minimum_size = Vector2(100, 14)
	hbox.add_child(bar_bg)

	# Bar fill (added as child of background)
	var bar_fill = ColorRect.new()
	bar_fill.color = color
	bar_fill.name = "Fill"
	bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar_fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar_bg.add_child(bar_fill)

	# Percentage label
	var pct_label = Label.new()
	pct_label.name = "Percent"
	pct_label.text = "50%"
	pct_label.custom_minimum_size.x = 35
	pct_label.add_theme_font_size_override("font_size", small_size)
	hbox.add_child(pct_label)

	return hbox


func _update_stat_bar(bar: HBoxContainer, value: float) -> void:
	"""Update a stat bar's fill and percentage"""
	if not bar:
		return

	# Find the bar background (second child)
	if bar.get_child_count() < 3:
		return

	var bar_bg = bar.get_child(1)
	var pct_label = bar.get_child(2)

	# Update fill width
	var fill = bar_bg.get_node_or_null("Fill")
	if fill:
		fill.custom_minimum_size.x = bar_bg.size.x * clamp(value, 0.0, 1.0)

	# Update percentage text
	if pct_label and pct_label is Label:
		pct_label.text = "%d%%" % int(value * 100)


# ============================================================================
# DATA UPDATE
# ============================================================================

func _update_title_bar() -> void:
	"""Update biome name and emoji"""
	if not biome_name_label:
		return
	var emoji = biome_data.get("emoji", "🌍")
	var bname = biome_data.get("name", "Unknown")
	biome_name_label.text = "%s %s" % [emoji, bname]


func _update_quantum_state() -> void:
	"""Update quantum state overview section"""
	var num_qubits = quantum_detail.get("num_qubits", 0)
	var dim = quantum_detail.get("dimension", 0)
	var purity = quantum_detail.get("purity", 0.5)
	var entropy = quantum_detail.get("entropy", 0.0)

	# Dimension info
	if dimension_label:
		dimension_label.text = "Dimension: %d  (%d qubits)" % [dim, num_qubits]

	# Update bars
	_update_stat_bar(purity_bar, purity)
	_update_stat_bar(entropy_bar, entropy)

	# Get coherence and dynamics from biome's dynamics_tracker
	var coherence = 0.0
	var dynamics = 0.5
	var stability_label = "⚡ Moderate"

	if biome and "dynamics_tracker" in biome and biome.dynamics_tracker:
		coherence = biome.dynamics_tracker.get_average_coherence()
		dynamics = biome.dynamics_tracker.get_dynamics()
		stability_label = "⚡ " + biome.dynamics_tracker.get_stability_label()

	_update_stat_bar(coherence_bar, coherence)

	# Update dynamics label with color coding
	if dynamics_label:
		dynamics_label.text = stability_label
		if dynamics < 0.2:
			dynamics_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))  # Green - stable
		elif dynamics < 0.5:
			dynamics_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))  # Yellow - moderate
		elif dynamics < 0.8:
			dynamics_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))  # Orange - active
		else:
			dynamics_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))  # Red - volatile


func _update_populations() -> void:
	"""Update icon population display (harvest probabilities).

	Shows the probability amplitude for each registered icon.
	This is what determines harvest outcomes when the quantum state is measured.
	"""
	if not populations_container:
		return

	# Clear existing children
	for child in populations_container.get_children():
		populations_container.remove_child(child)
		child.queue_free()

	var populations = quantum_detail.get("populations", {})

	if populations.is_empty():
		var empty = Label.new()
		empty.text = "No icons registered"
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		populations_container.add_child(empty)
		return

	# Sort by probability (highest first)
	var sorted_items = []
	for emoji in populations.keys():
		sorted_items.append({"emoji": emoji, "prob": populations[emoji]})
	sorted_items.sort_custom(func(a, b): return a.prob > b.prob)

	# Create compact display for each icon (emoji + percentage on same line)
	for item in sorted_items:
		var emoji = item.emoji
		var prob = item.prob

		var item_hbox = HBoxContainer.new()
		item_hbox.add_theme_constant_override("separation", 2)
		populations_container.add_child(item_hbox)

		# Emoji
		var emoji_label = Label.new()
		emoji_label.text = emoji
		emoji_label.add_theme_font_size_override("font_size", 22)
		item_hbox.add_child(emoji_label)

		# Percentage
		var pct_label = Label.new()
		pct_label.text = "%d%%" % int(prob * 100)
		pct_label.add_theme_font_size_override("font_size", small_size)
		# Color based on probability
		if prob > 0.5:
			pct_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		elif prob > 0.25:
			pct_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
		else:
			pct_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
		item_hbox.add_child(pct_label)


func _update_qubit_axes() -> void:
	"""Update qubit axes Bloch projection display (2-column grid)"""
	if not qubit_axes_container:
		return

	# Clear existing children IMMEDIATELY (not queue_free)
	var children = qubit_axes_container.get_children()
	for child in children:
		qubit_axes_container.remove_child(child)
		child.queue_free()

	var axes = quantum_detail.get("qubit_axes", [])

	if axes.is_empty():
		var empty = Label.new()
		empty.text = "No qubits registered"
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		qubit_axes_container.add_child(empty)
		return

	# Create compact axis display for each qubit (fits in 2-column grid)
	for axis_data in axes:
		var axis_row = _create_qubit_axis_row(axis_data)
		qubit_axes_container.add_child(axis_row)


func _create_qubit_axis_row(axis_data: Dictionary) -> HBoxContainer:
	"""Create a compact visual row for one qubit axis (fits in grid cell).

	Shows: [0] 🌾 ●━━━━━● 👥 58/42%
	"""
	var qubit_idx = axis_data.get("qubit", 0)
	var north = axis_data.get("north", "?")
	var south = axis_data.get("south", "?")
	var p_north = axis_data.get("p_north", 0.5)
	var p_south = axis_data.get("p_south", 0.5)
	var balance = axis_data.get("balance", 0.0)  # -1 to +1

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	hbox.custom_minimum_size.x = 380

	# Qubit index
	var idx_label = Label.new()
	idx_label.text = "[%d]" % qubit_idx
	idx_label.custom_minimum_size.x = 24
	idx_label.add_theme_font_size_override("font_size", small_size)
	idx_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hbox.add_child(idx_label)

	# North emoji
	var north_label = Label.new()
	north_label.text = north
	north_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(north_label)

	# Balance bar (compact)
	var bar_container = Control.new()
	bar_container.custom_minimum_size = Vector2(120, 16)
	hbox.add_child(bar_container)

	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.15, 0.15, 0.2)
	bar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_container.add_child(bar_bg)

	# Position marker
	var marker_x = (balance + 1.0) / 2.0
	var marker = ColorRect.new()
	marker.color = Color(1.0, 0.9, 0.3)
	marker.custom_minimum_size = Vector2(6, 12)
	marker.position = Vector2(marker_x * 108 + 6, 2)
	bar_container.add_child(marker)

	# South emoji
	var south_label = Label.new()
	south_label.text = south
	south_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(south_label)

	# Compact probability display
	var prob_label = Label.new()
	prob_label.text = "%d/%d%%" % [int(p_north * 100), int(p_south * 100)]
	prob_label.add_theme_font_size_override("font_size", small_size)
	prob_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	prob_label.custom_minimum_size.x = 55
	hbox.add_child(prob_label)

	return hbox


func _update_hamiltonian() -> void:
	"""Update Hamiltonian couplings display"""
	if not hamiltonian_label:
		return

	var ham_info = quantum_detail.get("hamiltonian", {})
	var couplings = ham_info.get("couplings", [])

	if couplings.is_empty():
		hamiltonian_label.text = "No couplings registered"
		hamiltonian_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		return

	# Format couplings
	var coupling_strs = []
	for c in couplings:
		var a = c.get("a", -1)
		var b = c.get("b", -1)
		var J = c.get("J", 0.0)
		if a >= 0 and b >= 0:
			coupling_strs.append("q%d↔q%d: J=%.3f" % [a, b, J])

	if coupling_strs.is_empty():
		hamiltonian_label.text = "No active couplings"
	else:
		hamiltonian_label.text = "  ".join(coupling_strs)

	hamiltonian_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))


func _update_lindblad() -> void:
	"""Update Lindblad dissipation display"""
	if not lindblad_label:
		return

	var channels = quantum_detail.get("lindblad", [])

	if channels.is_empty():
		lindblad_label.text = "No dissipation channels"
		lindblad_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		return

	# Format channels
	var channel_strs = []
	for ch in channels:
		var desc = ch.get("description", "Unknown")
		var rate = ch.get("rate", 0.0)
		var ch_type = ch.get("type", "raw")

		if ch_type == "gated":
			var gate = ch.get("gate", "")
			channel_strs.append("%s (γ=%.3f, gate=%s)" % [desc, rate, gate])
		elif rate > 0:
			channel_strs.append("%s (γ=%.3f)" % [desc, rate])
		else:
			channel_strs.append(desc)

	lindblad_label.text = "\n".join(channel_strs)
	lindblad_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))


# ============================================================================
# SIGNALS
# ============================================================================

func _on_close_button_pressed() -> void:
	"""Handle close button tap"""
	close_requested.emit()


func set_selected(selected: bool) -> void:
	"""Set selection highlight state"""
	if selected:
		border_color = Color(1.0, 0.9, 0.0)  # Gold highlight
	else:
		border_color = Color(0.3, 0.5, 0.7)  # Default blue
	_setup_panel_style()
