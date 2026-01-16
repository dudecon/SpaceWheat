class_name ControlsOverlay
extends "res://UI/Overlays/V2OverlayBase.gd"

## ControlsOverlay - Full keyboard reference with section navigation
##
## Expands on KeyboardHintButton with full v2 overlay features:
##   - Section navigation via WASD/QE
##   - Compact/full toggle via F
##   - Search/filter via R
##
## Controls:
##   Q/E = Navigate sections
##   R = Search/filter (future)
##   F = Toggle compact/full mode
##   WASD = Navigate within section
##   ESC = Close overlay

const V2OverlayBaseClass = preload("res://UI/Overlays/V2OverlayBase.gd")

# Sections
enum Section {
	TOOL_SELECTION,
	ACTIONS,
	LOCATION,
	OVERLAYS,
	QUANTUM_UI,
	ADVANCED
}

const SECTION_NAMES = [
	"Tool Selection",
	"Actions (QER)",
	"Location",
	"Overlays & Menus",
	"Quantum UI",
	"Advanced Actions"
]

const SECTION_ICONS = ["🛠️", "⚡", "📍", "📋", "🔬", "⚡"]

var current_section: int = Section.TOOL_SELECTION
var compact_mode: bool = false

# UI elements
var title_label: Label
var section_tabs: HBoxContainer
var content_container: Control
var section_panels: Array = []  # Array of PanelContainer

# Layout
const PANEL_WIDTH: int = 650
const PANEL_HEIGHT: int = 500
const COMPACT_HEIGHT: int = 300


func _init():
	overlay_name = "controls"
	overlay_icon = "⌨️"
	action_labels = {
		"Q": "Prev Section",
		"E": "Next Section",
		"R": "Search",
		"F": "Compact/Full"
	}


func _ready() -> void:
	super._ready()
	_build_ui()


func _build_ui() -> void:
	"""Build the controls overlay UI."""
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
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.text = "⌨️ Keyboard Controls"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vbox.add_child(title_label)

	# Section tabs
	section_tabs = _create_section_tabs()
	vbox.add_child(section_tabs)

	# Content area with scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)

	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_container)

	# Create section panels
	_create_section_panels()
	_update_section_display()


func _create_section_tabs() -> HBoxContainer:
	"""Create section tab bar."""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	for i in range(SECTION_NAMES.size()):
		var tab = Button.new()
		tab.text = "%s %s" % [SECTION_ICONS[i], SECTION_NAMES[i]]
		tab.add_theme_font_size_override("font_size", 12)
		tab.toggle_mode = true
		tab.button_pressed = (i == current_section)
		tab.pressed.connect(func(): _select_section(i))
		hbox.add_child(tab)

	return hbox


func _create_section_panels() -> void:
	"""Create content for each section."""
	section_panels.clear()

	# Tool Selection
	section_panels.append(_create_tool_section())
	# Actions
	section_panels.append(_create_actions_section())
	# Location
	section_panels.append(_create_location_section())
	# Overlays
	section_panels.append(_create_overlays_section())
	# Quantum UI
	section_panels.append(_create_quantum_section())
	# Advanced
	section_panels.append(_create_advanced_section())


func _create_tool_section() -> Control:
	"""Create tool selection help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	var entries = [
		["1", "🌱 Grower", "Plant, Entangle, Measure+Harvest"],
		["2", "⚛️ Quantum", "Cluster, Peek, Measure"],
		["3", "🏭 Industry", "Build Market/Kitchen"],
		["4", "⚡ Biome Control", "Energy Tap, Lindblad, Pump/Reset"],
		["5", "🔄 Gates", "1-Qubit Gates, 2-Qubit Gates, Remove"],
		["6", "🌍 Biome", "Assign Biome, Clear, Inspect"]
	]

	for entry in entries:
		content.add_child(_create_help_row(entry[0], entry[1], entry[2]))

	return content


func _create_actions_section() -> Control:
	"""Create QER actions help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	var desc = Label.new()
	desc.text = "Q, E, R = Context-sensitive actions that change based on selected tool"
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(desc)

	var entries = [
		["Q", "First Action", "Primary action for current tool"],
		["E", "Second Action", "Secondary action for current tool"],
		["R", "Third Action", "Tertiary action for current tool"],
		["F", "Tool Mode", "Cycle tool sub-modes (some tools)"]
	]

	for entry in entries:
		content.add_child(_create_help_row(entry[0], entry[1], entry[2]))

	return content


func _create_location_section() -> Control:
	"""Create location navigation help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	var entries = [
		["WASD", "Move Cursor", "Navigate plot selection"],
		["Y", "Location 1", "Quick-select first location"],
		["U", "Location 2", "Quick-select second location"],
		["I", "Location 3", "Quick-select third location"],
		["O", "Location 4", "Quick-select fourth location"],
		["P", "Location 5", "Quick-select fifth location"]
	]

	for entry in entries:
		content.add_child(_create_help_row(entry[0], entry[1], entry[2]))

	return content


func _create_overlays_section() -> Control:
	"""Create overlays help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	var entries = [
		["C", "Quest Board", "View and manage faction quests"],
		["V", "Vocabulary", "Semantic vocabulary/meaning-space"],
		["B", "Biome Inspector", "Detailed biome inspection"],
		["K", "Keyboard Help", "Toggle quick keyboard reference"],
		["L", "Logger Config", "Debug logging settings"],
		["ESC", "Pause Menu", "Save, Load, Settings, Quit"]
	]

	for entry in entries:
		content.add_child(_create_help_row(entry[0], entry[1], entry[2]))

	var pause_label = Label.new()
	pause_label.text = "\nIn Pause Menu: S=Save, L=Load, X=Quantum Settings, D=Reload, R=Restart, Q=Quit"
	pause_label.add_theme_font_size_override("font_size", 12)
	pause_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	pause_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(pause_label)

	return content


func _create_quantum_section() -> Control:
	"""Create quantum UI help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	var left_label = Label.new()
	left_label.text = "Left Side Panel (Collapsible):"
	left_label.add_theme_font_size_override("font_size", 14)
	left_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	content.add_child(left_label)

	var left_items = Label.new()
	left_items.text = "  • Energy Meter (real vs imaginary)\n  • Uncertainty Meter (precision/flexibility)\n  • Semantic Context (octant/region)\n  • Attractor Personality"
	left_items.add_theme_font_size_override("font_size", 13)
	left_items.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	content.add_child(left_items)

	var right_label = Label.new()
	right_label.text = "\nTop Right - Quantum Mode Indicator:"
	right_label.add_theme_font_size_override("font_size", 14)
	right_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	content.add_child(right_label)

	var right_items = Label.new()
	right_items.text = "  Shows: HARDWARE/INSPECTOR mode\n  Configure: ESC → X (Quantum Settings)"
	right_items.add_theme_font_size_override("font_size", 13)
	right_items.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	content.add_child(right_items)

	return content


func _create_advanced_section() -> Control:
	"""Create advanced tool actions help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)

	# Tool 2
	var t2_label = Label.new()
	t2_label.text = "Tool 2 (Quantum):"
	t2_label.add_theme_font_size_override("font_size", 14)
	t2_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	content.add_child(t2_label)

	content.add_child(_create_help_row("E", "Peek State", "Shows probabilities without collapse"))
	content.add_child(_create_help_row("R", "Batch Measure", "Measures entire entangled component"))

	# Tool 4
	var t4_label = Label.new()
	t4_label.text = "\nTool 4 (Biome Control):"
	t4_label.add_theme_font_size_override("font_size", 14)
	t4_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	content.add_child(t4_label)

	content.add_child(_create_help_row("E→Q/E/R", "Lindblad Ops", "Drive, Decay, Transfer"))
	content.add_child(_create_help_row("R→Q/E/R", "Pump/Reset", "Pump wheat, Reset pure, Reset mixed"))

	# Tool 5
	var t5_label = Label.new()
	t5_label.text = "\nTool 5 (Gates):"
	t5_label.add_theme_font_size_override("font_size", 14)
	t5_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	content.add_child(t5_label)

	content.add_child(_create_help_row("Q→Q/E/R", "1-Qubit Basic", "Pauli-X, Hadamard, Pauli-Z"))
	content.add_child(_create_help_row("E→Q/E/R", "Phase Gates", "Pauli-Y, S-gate, T-gate"))
	content.add_child(_create_help_row("R→Q/E/R", "2-Qubit Gates", "CNOT, CZ, SWAP"))

	# Tool 6
	var t6_label = Label.new()
	t6_label.text = "\nTool 6 (Biome):"
	t6_label.add_theme_font_size_override("font_size", 14)
	t6_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	content.add_child(t6_label)

	content.add_child(_create_help_row("R", "Inspect Plot", "Opens detailed biome inspector"))

	return content


func _create_help_row(key: String, action: String, description: String) -> Control:
	"""Create a help row: [KEY] Action - Description."""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Key label
	var key_label = Label.new()
	key_label.text = "[%s]" % key
	key_label.custom_minimum_size = Vector2(80, 0)
	key_label.add_theme_font_size_override("font_size", 13)
	key_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	hbox.add_child(key_label)

	# Action label
	var action_label = Label.new()
	action_label.text = action
	action_label.custom_minimum_size = Vector2(140, 0)
	action_label.add_theme_font_size_override("font_size", 13)
	action_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	hbox.add_child(action_label)

	# Description label
	var desc_label = Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(desc_label)

	return hbox


func _update_section_display() -> void:
	"""Update which section is visible."""
	# Show/hide panels based on current section (don't delete them!)
	# First, ensure all panels are added to content_container if not already
	for i in range(section_panels.size()):
		var panel = section_panels[i]
		if panel.get_parent() != content_container:
			content_container.add_child(panel)
		panel.visible = (i == current_section)

	# Update tab states
	for i in range(section_tabs.get_child_count()):
		var tab = section_tabs.get_child(i)
		if tab is Button:
			tab.button_pressed = (i == current_section)

	# Update compact mode
	if compact_mode:
		custom_minimum_size.y = COMPACT_HEIGHT
	else:
		custom_minimum_size.y = PANEL_HEIGHT


func _select_section(index: int) -> void:
	"""Select a section by index."""
	if index >= 0 and index < SECTION_NAMES.size():
		current_section = index
		_update_section_display()
		action_performed.emit("section_changed", {"section": SECTION_NAMES[index]})


# ============================================================================
# ACTION HANDLERS
# ============================================================================

func on_q_pressed() -> void:
	"""Q = Previous section."""
	current_section = (current_section - 1) % SECTION_NAMES.size()
	if current_section < 0:
		current_section = SECTION_NAMES.size() - 1
	_update_section_display()
	action_performed.emit("prev_section", {"section": SECTION_NAMES[current_section]})


func on_e_pressed() -> void:
	"""E = Next section."""
	current_section = (current_section + 1) % SECTION_NAMES.size()
	_update_section_display()
	action_performed.emit("next_section", {"section": SECTION_NAMES[current_section]})


func on_r_pressed() -> void:
	"""R = Search/filter (future feature)."""
	action_performed.emit("search", {})
	# TODO: Implement search popup


func on_f_pressed() -> void:
	"""F = Toggle compact/full mode."""
	compact_mode = not compact_mode
	_update_section_display()
	action_performed.emit("toggle_compact", {"compact": compact_mode})


func get_action_labels() -> Dictionary:
	"""v2 overlay interface: Get current QER+F labels."""
	return action_labels
