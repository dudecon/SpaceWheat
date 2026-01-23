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
var dimension_label: Label

# Qubit axes section
var qubit_axes_container: VBoxContainer

# Hamiltonian section
var hamiltonian_label: Label

# Lindblad section
var lindblad_label: Label

# Data
var biome: Node = null
var farm_grid: Node = null
var biome_data: Dictionary = {}
var quantum_detail: Dictionary = {}

# Visual settings
var panel_width: int = 500
var panel_height: int = 600
var bg_color: Color = Color(0.08, 0.08, 0.12, 0.98)
var border_color: Color = Color(0.3, 0.5, 0.7, 1.0)
var corner_radius: int = 20

# Font sizes - LARGER for readability
var title_size: int = 28
var section_header_size: int = 16
var normal_size: int = 18
var small_size: int = 14

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
	"""Construct UI hierarchy"""
	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	# Add margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	main_vbox.add_child(margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(content_vbox)

	# Title bar
	title_bar = _create_title_bar()
	content_vbox.add_child(title_bar)

	# === QUANTUM STATE SECTION ===
	content_vbox.add_child(_create_section_header("QUANTUM STATE"))

	var state_container = VBoxContainer.new()
	state_container.add_theme_constant_override("separation", 6)
	content_vbox.add_child(state_container)

	# Dimension info
	dimension_label = Label.new()
	dimension_label.add_theme_font_size_override("font_size", normal_size)
	state_container.add_child(dimension_label)

	# Purity bar
	purity_bar = _create_stat_bar("Purity", 0.5, Color(0.3, 0.7, 1.0))
	state_container.add_child(purity_bar)

	# Entropy bar
	entropy_bar = _create_stat_bar("Entropy", 0.0, Color(1.0, 0.5, 0.3))
	state_container.add_child(entropy_bar)

	# === QUBIT AXES SECTION ===
	content_vbox.add_child(_create_section_header("QUBIT AXES (Bloch Projection)"))

	qubit_axes_container = VBoxContainer.new()
	qubit_axes_container.add_theme_constant_override("separation", 8)
	content_vbox.add_child(qubit_axes_container)

	# === HAMILTONIAN SECTION ===
	content_vbox.add_child(_create_section_header("HAMILTONIAN"))

	hamiltonian_label = Label.new()
	hamiltonian_label.add_theme_font_size_override("font_size", small_size)
	hamiltonian_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_vbox.add_child(hamiltonian_label)

	# === LINDBLAD SECTION ===
	content_vbox.add_child(_create_section_header("LINDBLAD DISSIPATION"))

	lindblad_label = Label.new()
	lindblad_label.add_theme_font_size_override("font_size", small_size)
	lindblad_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	"""Create a labeled progress bar for stats"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Label
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 80
	label.add_theme_font_size_override("font_size", normal_size)
	hbox.add_child(label)

	# Bar background
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.2, 0.2)
	bar_bg.custom_minimum_size = Vector2(200, 20)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	pct_label.custom_minimum_size.x = 50
	pct_label.add_theme_font_size_override("font_size", normal_size)
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


func _update_qubit_axes() -> void:
	"""Update qubit axes Bloch projection display"""
	if not qubit_axes_container:
		return

	# Clear existing children IMMEDIATELY (not queue_free)
	# queue_free causes layout issues because old nodes aren't removed until end of frame
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

	# Create axis display for each qubit
	for axis_data in axes:
		var axis_row = _create_qubit_axis_row(axis_data)
		qubit_axes_container.add_child(axis_row)


func _create_qubit_axis_row(axis_data: Dictionary) -> VBoxContainer:
	"""Create a visual row for one qubit axis

	Shows: [qubit_idx] north_emoji ←━━━●━━━→ south_emoji  P(N)=73%
	"""
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var qubit_idx = axis_data.get("qubit", 0)
	var north = axis_data.get("north", "?")
	var south = axis_data.get("south", "?")
	var p_north = axis_data.get("p_north", 0.5)
	var p_south = axis_data.get("p_south", 0.5)
	var coherence = axis_data.get("coherence_mag", 0.0)
	var balance = axis_data.get("balance", 0.0)  # -1 to +1

	# Main row with axis bar
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	# Qubit index
	var idx_label = Label.new()
	idx_label.text = "[%d]" % qubit_idx
	idx_label.custom_minimum_size.x = 30
	idx_label.add_theme_font_size_override("font_size", normal_size)
	idx_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hbox.add_child(idx_label)

	# North emoji
	var north_label = Label.new()
	north_label.text = north
	north_label.add_theme_font_size_override("font_size", 22)
	hbox.add_child(north_label)

	# Balance bar (shows position between north and south)
	var bar_container = Control.new()
	bar_container.custom_minimum_size = Vector2(180, 24)
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(bar_container)

	# Bar background
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.15, 0.15, 0.2)
	bar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_container.add_child(bar_bg)

	# Position marker (circle indicating balance)
	var marker_x = (balance + 1.0) / 2.0  # Convert -1..1 to 0..1
	var marker = ColorRect.new()
	marker.color = Color(1.0, 0.9, 0.3)  # Gold
	marker.custom_minimum_size = Vector2(8, 16)
	marker.position = Vector2(marker_x * 172 + 4, 4)  # Offset for centering
	bar_container.add_child(marker)

	# South emoji
	var south_label = Label.new()
	south_label.text = south
	south_label.add_theme_font_size_override("font_size", 22)
	hbox.add_child(south_label)

	# Stats row below
	var stats_row = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 16)
	vbox.add_child(stats_row)

	var spacer = Control.new()
	spacer.custom_minimum_size.x = 30
	stats_row.add_child(spacer)

	var stats_label = Label.new()
	stats_label.text = "P(%s)=%d%%  P(%s)=%d%%  |ρ₀₁|=%.2f" % [
		north, int(p_north * 100),
		south, int(p_south * 100),
		coherence
	]
	stats_label.add_theme_font_size_override("font_size", small_size)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	stats_row.add_child(stats_label)

	return vbox


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
