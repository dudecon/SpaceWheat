class_name ControlsOverlay
extends "res://UI/Core/OverlayBase.gd"

## ControlsOverlay - Full keyboard reference with section navigation
##
## Controls:
##   Q/E = Navigate sections
##   R = Search/filter (future)
##   F = Toggle compact/full mode
##   WASD = Navigate within section
##   ESC = Close overlay

# Sections
enum Section {
	TOOL_SELECTION,
	ACTIONS,
	NAVIGATION,
	OVERLAYS,
	QUANTUM_UI,
	ADVANCED
}

const SECTION_NAMES = [
	"Tool Selection",
	"Actions (QER)",
	"Biome & Plot Nav",
	"Overlays & Menus",
	"Quantum UI",
	"Advanced Actions"
]

const SECTION_ICONS = ["Tools", "Actions", "Nav", "Overlays", "Quantum", "Advanced"]

var current_section: int = Section.TOOL_SELECTION
var compact_mode: bool = false

# UI elements
var section_tabs: HBoxContainer
var sections_container: VBoxContainer
var section_panels: Array = []

# Layout
const COMPACT_HEIGHT: int = 300


func _init():
	overlay_name = "controls"
	overlay_icon = ""
	overlay_tier = 2000  # Z_TIER_INFO
	panel_title = "Keyboard Controls"
	panel_size = Vector2(650, 500)
	panel_border_color = Color(0.5, 0.5, 0.3, 0.8)  # Gold/tan border
	navigation_mode = NavigationMode.NONE  # We handle our own Q/E navigation
	action_labels = {
		"Q": "Prev Section",
		"E": "Next Section",
		"R": "Search",
		"F": "Compact/Full"
	}


func _build_content(container: Control) -> void:
	"""Build the controls overlay content."""
	# Section tabs
	section_tabs = _create_section_tabs()
	container.add_child(section_tabs)

	# Sections container
	sections_container = VBoxContainer.new()
	sections_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(sections_container)

	# Create section panels
	_create_section_panels()
	_update_section_display()


func _create_section_tabs() -> HBoxContainer:
	"""Create section tab bar."""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	for i in range(SECTION_NAMES.size()):
		var tab = Button.new()
		tab.text = SECTION_ICONS[i]
		tab.add_theme_font_size_override("font_size", 11)
		tab.toggle_mode = true
		tab.button_pressed = (i == current_section)
		tab.pressed.connect(func(): _select_section(i))
		hbox.add_child(tab)

	return hbox


func _create_section_panels() -> void:
	"""Create content for each section."""
	section_panels.clear()
	section_panels.append(_create_tool_section())
	section_panels.append(_create_actions_section())
	section_panels.append(_create_navigation_section())
	section_panels.append(_create_overlays_section())
	section_panels.append(_create_quantum_section())
	section_panels.append(_create_advanced_section())


func _create_tool_section() -> Control:
	"""Create tool selection help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	var mode_header = Label.new()
	mode_header.text = "Tab = Toggle PLAY/BUILD Mode"
	mode_header.add_theme_font_size_override("font_size", 14)
	mode_header.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	content.add_child(mode_header)

	var play_label = Label.new()
	play_label.text = "\nPLAY MODE (default):"
	play_label.add_theme_font_size_override("font_size", 13)
	play_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	content.add_child(play_label)

	var play_entries = [
		["1", "Probe", "Explore/Measure/Pop (core loop)"],
		["2", "Gates", "X/H/Ry + F-cycle to Z/S/T"],
		["3", "Entangle", "CNOT/SWAP/CZ + F-cycle to Bell/Disentangle"],
		["4", "Industry", "Deprecated (buildings removed)"]
	]

	for entry in play_entries:
		content.add_child(_create_help_row(entry[0], entry[1], entry[2]))

	var build_label = Label.new()
	build_label.text = "\nBUILD MODE (Tab to switch):"
	build_label.add_theme_font_size_override("font_size", 13)
	build_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	content.add_child(build_label)

	var build_entries = [
		["1", "Biome", "Assign plots to biomes"],
		["2", "Icon", "Configure emoji icons"],
		["3", "Lindblad", "Drive/Decay/Transfer dissipation"],
		["4", "Quantum", "Reset/Snapshot/Debug + F-cycle to phase gates"]
	]

	for entry in build_entries:
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
		["F", "Cycle Mode", "Switch tool sub-modes"],
		["Tab", "PLAY/BUILD", "Toggle between modes"],
		["Space", "Pause", "Pause/resume evolution"],
		["H", "Harvest All", "Global harvest"]
	]

	for entry in entries:
		content.add_child(_create_help_row(entry[0], entry[1], entry[2]))

	return content


func _create_navigation_section() -> Control:
	"""Create biome and plot navigation help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	var biome_header = Label.new()
	biome_header.text = "Biome Selection (TYUIOP):"
	biome_header.add_theme_font_size_override("font_size", 14)
	biome_header.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	content.add_child(biome_header)

	var biome_entries = [
		["T", "StarterForest", "Switch to Starter Forest"],
		["Y", "Village", "Switch to Village"],
		["U", "BioticFlux", "Switch to Quantum Fields"],
		["I", "StellarForges", "Switch to Stellar Forges"],
		["O", "FungalNetworks", "Switch to Fungal Networks"],
		["P", "VolcanicWorlds", "Switch to Volcanic Worlds"]
	]

	for entry in biome_entries:
		content.add_child(_create_help_row(entry[0], entry[1], entry[2]))

	var plot_header = Label.new()
	plot_header.text = "\nPlot Selection (JKL; Homerow):"
	plot_header.add_theme_font_size_override("font_size", 14)
	plot_header.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	content.add_child(plot_header)

	var plot_entries = [
		["J", "Plot 1", "Select first plot in current biome"],
		["K", "Plot 2", "Select second plot in current biome"],
		["L", "Plot 3", "Select third plot in current biome"],
		[";", "Plot 4", "Select fourth plot in current biome"]
	]

	for entry in plot_entries:
		content.add_child(_create_help_row(entry[0], entry[1], entry[2]))

	var subspace_header = Label.new()
	subspace_header.text = "\nSubspace Navigation (Reserved):"
	subspace_header.add_theme_font_size_override("font_size", 14)
	subspace_header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	content.add_child(subspace_header)

	var subspace_note = Label.new()
	subspace_note.text = "  M , . / = Reserved for future subspace navigation"
	subspace_note.add_theme_font_size_override("font_size", 12)
	subspace_note.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	content.add_child(subspace_note)

	return content


func _create_overlays_section() -> Control:
	"""Create overlays help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	var entries = [
		["C", "Quest Board", "View and manage quests"],
		["V", "Vocabulary", "Semantic vocabulary"],
		["B", "Biome Inspector", "Detailed biome info"],
		["Z", "Keyboard Help", "This overlay"],
		["X", "Logger Config", "Debug logging"],
		["ESC", "Pause Menu", "Save, Load, Quit"]
	]

	for entry in entries:
		content.add_child(_create_help_row(entry[0], entry[1], entry[2]))

	var pause_label = Label.new()
	pause_label.text = "\nIn Pause Menu: S=Save, L=Load, X=Settings, D=Reload, R=Restart, Q=Quit"
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
	left_items.text = "  - Energy Meter\n  - Uncertainty Meter\n  - Semantic Context\n  - Attractor Personality"
	left_items.add_theme_font_size_override("font_size", 13)
	left_items.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	content.add_child(left_items)

	var right_label = Label.new()
	right_label.text = "\nTop Right - Quantum Mode Indicator:"
	right_label.add_theme_font_size_override("font_size", 14)
	right_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	content.add_child(right_label)

	var right_items = Label.new()
	right_items.text = "  Shows: HARDWARE/INSPECTOR mode\n  Configure: ESC -> X (Quantum Settings)"
	right_items.add_theme_font_size_override("font_size", 13)
	right_items.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	content.add_child(right_items)

	return content


func _create_advanced_section() -> Control:
	"""Create advanced tool actions help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)

	var play_header = Label.new()
	play_header.text = "PLAY MODE - F-Cycling Details:"
	play_header.add_theme_font_size_override("font_size", 14)
	play_header.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	content.add_child(play_header)

	var t2_label = Label.new()
	t2_label.text = "\nTool 2 (Gates) - F-cycles:"
	t2_label.add_theme_font_size_override("font_size", 13)
	t2_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	content.add_child(t2_label)

	content.add_child(_create_help_row("Convert", "X/H/Ry", "Bit flip, Superposition, Tune"))
	content.add_child(_create_help_row("Phase", "Z/S/T", "Phase flip, pi/2, pi/4"))

	var t3_label = Label.new()
	t3_label.text = "\nTool 3 (Entangle) - F-cycles:"
	t3_label.add_theme_font_size_override("font_size", 13)
	t3_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	content.add_child(t3_label)

	content.add_child(_create_help_row("Link", "CNOT/SWAP/CZ", "Two-qubit gates"))
	content.add_child(_create_help_row("Manage", "Bell/Disentangle", "Entanglement control"))

	var t4_label = Label.new()
	t4_label.text = "\nTool 4 (Industry) - F-cycles:"
	t4_label.add_theme_font_size_override("font_size", 13)
	t4_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	content.add_child(t4_label)

	content.add_child(_create_help_row("Build", "Deprecated", "Mill/Market/Kitchen removed"))
	content.add_child(_create_help_row("Harvest", "Disabled", "Industry structures no longer exist"))

	return content


func _create_help_row(key: String, action: String, description: String) -> Control:
	"""Create a help row: [KEY] Action - Description."""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var key_label = Label.new()
	key_label.text = "[%s]" % key
	key_label.custom_minimum_size = Vector2(70, 0)
	key_label.add_theme_font_size_override("font_size", 13)
	key_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	hbox.add_child(key_label)

	var action_label = Label.new()
	action_label.text = action
	action_label.custom_minimum_size = Vector2(120, 0)
	action_label.add_theme_font_size_override("font_size", 13)
	action_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	hbox.add_child(action_label)

	var desc_label = Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(desc_label)

	return hbox


func _update_section_display() -> void:
	"""Update which section is visible."""
	for i in range(section_panels.size()):
		var panel = section_panels[i]
		if panel.get_parent() != sections_container:
			sections_container.add_child(panel)
		panel.visible = (i == current_section)

	for i in range(section_tabs.get_child_count()):
		var tab = section_tabs.get_child(i)
		if tab is Button:
			tab.button_pressed = (i == current_section)


func _select_section(index: int) -> void:
	"""Select a section by index."""
	if index >= 0 and index < SECTION_NAMES.size():
		current_section = index
		_update_section_display()
		action_performed.emit("section_changed", {"section": SECTION_NAMES[index]})


# ============================================================================
# ACTION HANDLERS
# ============================================================================

func _on_action_q() -> void:
	"""Q = Previous section."""
	current_section = posmod(current_section - 1, SECTION_NAMES.size())
	_update_section_display()
	action_performed.emit("prev_section", {"section": SECTION_NAMES[current_section]})


func _on_action_e() -> void:
	"""E = Next section."""
	current_section = (current_section + 1) % SECTION_NAMES.size()
	_update_section_display()
	action_performed.emit("next_section", {"section": SECTION_NAMES[current_section]})


func _on_action_r() -> void:
	"""R = Search/filter (future feature)."""
	action_performed.emit("search", {})


func _on_action_f() -> void:
	"""F = Toggle compact/full mode."""
	compact_mode = not compact_mode
	_update_section_display()
	action_performed.emit("toggle_compact", {"compact": compact_mode})
