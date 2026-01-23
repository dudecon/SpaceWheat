class_name SemanticMapOverlay
extends "res://UI/Overlays/V2OverlayBase.gd"

## SemanticMapOverlay - Octant visualization and vocabulary explorer
##
## Displays the 8 semantic octants with:
##   - Current region highlight
##   - Vocabulary (discovered emojis) per octant
##   - Strange attractor visualization
##
## Controls:
##   Q = Navigate octants
##   E = Zoom into selected octant
##   R = Show attractors
##   F = Cycle projection mode (2D/3D view)
##   WASD = Navigate within octant emojis
##   ESC = Close overlay

const V2OverlayBaseClass = preload("res://UI/Overlays/V2OverlayBase.gd")

# Semantic octant regions (from SemanticOctant.gd)
const REGIONS = [
	{"name": "Phoenix", "icon": "🔥", "desc": "Abundance & transformation", "color": Color(1.0, 0.6, 0.2)},
	{"name": "Sage", "icon": "🧙", "desc": "Wisdom & patience", "color": Color(0.6, 0.4, 0.8)},
	{"name": "Warrior", "icon": "⚔️", "desc": "Conflict & struggle", "color": Color(0.9, 0.2, 0.2)},
	{"name": "Merchant", "icon": "💰", "desc": "Trade & accumulation", "color": Color(1.0, 0.85, 0.3)},
	{"name": "Ascetic", "icon": "🧘", "desc": "Minimalism & conservation", "color": Color(0.5, 0.5, 0.5)},
	{"name": "Gardener", "icon": "🌻", "desc": "Cultivation & harmony", "color": Color(0.3, 0.8, 0.3)},
	{"name": "Innovator", "icon": "💡", "desc": "Experimentation & chaos", "color": Color(0.3, 0.7, 1.0)},
	{"name": "Guardian", "icon": "🛡️", "desc": "Defense & protection", "color": Color(0.4, 0.4, 0.6)}
]

# View modes
enum ViewMode { VOCAB_LIST, OCTANT_GRID, VOCABULARY, ATTRACTOR_MAP }
const VIEW_MODE_NAMES = ["My Vocabulary", "Octant Grid", "Octant Detail", "Attractor Map"]

var current_view_mode: int = ViewMode.VOCAB_LIST  # Default to simple list
var selected_octant: int = 0
var vocabulary_data: Dictionary = {}  # Loaded from game state

# UI elements
var title_label: Label
var view_mode_label: Label
var vocab_list_container: Control  # Simple vocabulary list (default view)
var vocab_list_grid: GridContainer  # Grid for vocab list items
var octant_grid: GridContainer
var vocab_container: Control
var attractor_container: Control
var octant_panels: Array = []  # References to octant panel nodes
var emoji_grid: GridContainer

# Layout
const PANEL_WIDTH: int = 650
const PANEL_HEIGHT: int = 500
const OCTANT_SIZE: int = 140


func _init():
	overlay_name = "semantic_map"
	overlay_icon = "🧭"
	action_labels = {
		"Q": "Prev Octant",
		"E": "Next Octant",
		"R": "Attractors",
		"F": "View Mode"
	}


func _ready() -> void:
	super._ready()
	_build_ui()


func _build_ui() -> void:
	"""Build the semantic map overlay UI."""
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	# Create background panel (Control doesn't render panel stylebox, so use PanelContainer)
	var background_panel = PanelContainer.new()
	background_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.14, 0.95)
	panel_style.border_color = Color(0.4, 0.3, 0.6, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(16)
	background_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(background_panel)

	# Main layout inside the background panel
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	background_panel.add_child(vbox)

	# Title bar
	var title_bar = _create_title_bar()
	vbox.add_child(title_bar)

	# Content area
	var content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	# Simple vocabulary list (default view - shows all discovered vocab)
	vocab_list_container = _create_vocab_list_view()
	vocab_list_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(vocab_list_container)

	# Octant grid view (initially hidden)
	octant_grid = _create_octant_grid()
	octant_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	octant_grid.visible = false
	content.add_child(octant_grid)

	# Vocabulary per-octant view (initially hidden)
	vocab_container = _create_vocabulary_view()
	vocab_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	vocab_container.visible = false
	content.add_child(vocab_container)

	# Attractor view (initially hidden)
	attractor_container = _create_attractor_view()
	attractor_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	attractor_container.visible = false
	content.add_child(attractor_container)


func _create_title_bar() -> Control:
	"""Create title bar with overlay name and view mode."""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	# Title
	title_label = Label.new()
	title_label.text = "🧭 Semantic Map"
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


func _create_octant_grid() -> GridContainer:
	"""Create 2x4 grid of octant panels."""
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)

	octant_panels.clear()
	for i in range(8):
		var panel = _create_octant_panel(i)
		grid.add_child(panel)
		octant_panels.append(panel)

	return grid


func _create_octant_panel(index: int) -> Control:
	"""Create a single octant panel."""
	var region = REGIONS[index]

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(OCTANT_SIZE, OCTANT_SIZE)

	var style = StyleBoxFlat.new()
	style.bg_color = region.color.darkened(0.7)
	style.border_color = region.color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Icon and name
	var header = Label.new()
	header.text = "%s %s" % [region.icon, region.name]
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", region.color)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Description
	var desc = Label.new()
	desc.text = region.desc
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Emoji count placeholder
	var count_label = Label.new()
	count_label.name = "CountLabel"
	count_label.text = "0 emojis"
	count_label.add_theme_font_size_override("font_size", 11)
	count_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(count_label)

	return panel


func _create_vocab_list_view() -> Control:
	"""Create simple vocabulary list view (default view).

	Shows all discovered vocabulary in a flat list format.
	This is what the player has learned and can use for quests.
	"""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 10)

	# Header
	var header = Label.new()
	header.name = "VocabListHeader"
	header.text = "📚 Known Pairs"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	container.add_child(header)

	# Subtitle
	var subtitle = Label.new()
	subtitle.name = "VocabListSubtitle"
	subtitle.text = "Emoji pairs you can plant - complete quests to learn more!"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	container.add_child(subtitle)

	# Scroll container for vocabulary list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	container.add_child(scroll)

	# Grid for vocabulary items (pairs need more horizontal space)
	vocab_list_grid = GridContainer.new()
	vocab_list_grid.columns = 2  # 2 columns of emoji pairs
	vocab_list_grid.add_theme_constant_override("h_separation", 24)
	vocab_list_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(vocab_list_grid)

	# Mode hint
	var hint = Label.new()
	hint.text = "[F] Cycle views: List → Octant Grid → Detail → Attractors"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	container.add_child(hint)

	return container


func _create_vocabulary_view() -> Control:
	"""Create vocabulary grid for selected octant."""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 10)

	# Octant header
	var header = Label.new()
	header.name = "OctantHeader"
	header.text = "📖 Vocabulary - Phoenix"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	container.add_child(header)

	# Scroll container
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	container.add_child(scroll)

	# Emoji grid
	emoji_grid = GridContainer.new()
	emoji_grid.columns = 10
	emoji_grid.add_theme_constant_override("h_separation", 12)
	emoji_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(emoji_grid)

	# Back hint
	var hint = Label.new()
	hint.text = "[F] Back to Octant Grid"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	container.add_child(hint)

	return container


func _create_attractor_view() -> Control:
	"""Create strange attractor visualization."""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 10)

	# Header
	var header = Label.new()
	header.text = "🌀 Strange Attractors"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	container.add_child(header)

	# Placeholder for attractor visualization
	var placeholder = Label.new()
	placeholder.text = "Attractor visualization coming soon...\n\nAttractors represent stable states in the semantic space."
	placeholder.add_theme_font_size_override("font_size", 14)
	placeholder.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(placeholder)

	return container


# ============================================================================
# LIFECYCLE
# ============================================================================

func activate() -> void:
	"""Called when overlay opens - refresh data."""
	super.activate()
	_load_vocabulary_data()
	_update_octant_counts()
	_update_selection_visual()
	_update_view()  # Show correct view mode


func _load_vocabulary_data() -> void:
	"""Load vocabulary from game state."""
	vocabulary_data = {}

	var gsm = get_node_or_null("/root/GameStateManager")
	if not gsm:
		return

	# Get vocabulary evolution system
	var vocab_evolution = gsm.get_vocabulary_evolution()
	if not vocab_evolution:
		return

	# Get discovered vocabulary (array of {north, south, stability, ...} dicts)
	var discovered = vocab_evolution.get_discovered_vocabulary()

	# Map emojis to octants based on simple heuristic
	# Vocabulary items have "north" and "south" emojis
	for vocab_item in discovered:
		var north_emoji = vocab_item.get("north", "")
		var south_emoji = vocab_item.get("south", "")
		var stability = vocab_item.get("stability", 0.5)

		if north_emoji and south_emoji:
			# Create combined emoji pair as key
			var key = "%s↔%s" % [north_emoji, south_emoji]

			# Determine octant using simple heuristic
			# We'll use stability and emoji properties to assign octants
			var octant = _assign_emoji_to_octant(north_emoji, south_emoji, stability)

			# Store in vocabulary data
			if not vocabulary_data.has(octant):
				vocabulary_data[octant] = []

			vocabulary_data[octant].append({
				"pair": key,
				"north": north_emoji,
				"south": south_emoji,
				"stability": stability
			})


func _update_octant_counts() -> void:
	"""Update emoji counts in each octant panel."""
	for i in range(octant_panels.size()):
		var panel = octant_panels[i]
		var count_label = panel.find_child("CountLabel", true, false)
		if count_label:
			var count = _get_octant_emoji_count(i)
			count_label.text = "%d emojis" % count


func _populate_vocab_list() -> void:
	"""Populate the vocabulary list with player's known pairs.

	Shows known_pairs (plantable qubit axes) as the primary display.
	Pairs are the core vocabulary unit - emojis are learned as pairs.
	"""
	# Clear existing items
	for child in vocab_list_grid.get_children():
		child.queue_free()

	var gsm = get_node_or_null("/root/GameStateManager")
	if not gsm or not gsm.current_state:
		_add_vocab_placeholder("Game not loaded")
		return

	# Get player's known pairs (the core vocabulary unit - source of truth)
	var known_pairs = gsm.current_state.known_pairs
	var known_emojis = gsm.current_state.get_known_emojis()  # Derived from known_pairs
	var accessible_factions = gsm.get_accessible_factions() if gsm.has_method("get_accessible_factions") else []

	# Update subtitle with count
	var subtitle = vocab_list_container.find_child("VocabListSubtitle", true, false)
	if subtitle:
		subtitle.text = "%d pairs known | %d factions accessible" % [known_pairs.size(), accessible_factions.size()]

	if known_pairs.is_empty():
		_add_vocab_placeholder("No vocabulary yet!\n\nComplete quests to learn new emoji pairs.")
		return

	# Add each known pair with nice styling
	for pair in known_pairs:
		var north = pair.get("north", "?")
		var south = pair.get("south", "?")

		# Create a horizontal container for the pair
		var pair_container = HBoxContainer.new()
		pair_container.add_theme_constant_override("separation", 8)
		pair_container.custom_minimum_size = Vector2(180, 60)

		# North emoji
		var north_label = Label.new()
		north_label.text = north
		north_label.add_theme_font_size_override("font_size", 32)
		north_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		north_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		north_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9))
		pair_container.add_child(north_label)

		# Divider
		var divider = Label.new()
		divider.text = "/"
		divider.add_theme_font_size_override("font_size", 24)
		divider.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		divider.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		divider.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pair_container.add_child(divider)

		# South emoji
		var south_label = Label.new()
		south_label.text = south
		south_label.add_theme_font_size_override("font_size", 32)
		south_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		south_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		south_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9))
		pair_container.add_child(south_label)

		vocab_list_grid.add_child(pair_container)

	# Add separator and faction info
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(vocab_list_grid.size.x, 20)
	vocab_list_grid.add_child(spacer)

	# Show a few accessible factions as preview
	if accessible_factions.size() > 0:
		var factions_label = Label.new()
		factions_label.text = "Accessible Factions:"
		factions_label.add_theme_font_size_override("font_size", 14)
		factions_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		vocab_list_grid.add_child(factions_label)

		var count = 0
		for faction in accessible_factions:
			if count >= 6:
				var more_label = Label.new()
				more_label.text = "... +%d more" % (accessible_factions.size() - count)
				more_label.add_theme_font_size_override("font_size", 12)
				more_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
				vocab_list_grid.add_child(more_label)
				break

			var faction_name = faction.get("name", "Unknown") if faction is Dictionary else str(faction)
			var faction_emoji = faction.get("sig", ["?"])[0] if faction is Dictionary and faction.has("sig") else "?"

			var faction_label = Label.new()
			faction_label.text = "%s %s" % [faction_emoji, faction_name]
			faction_label.add_theme_font_size_override("font_size", 12)
			faction_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
			vocab_list_grid.add_child(faction_label)
			count += 1


func _add_vocab_placeholder(message: String) -> void:
	"""Add a placeholder message to the vocab list grid."""
	var placeholder = Label.new()
	placeholder.text = message
	placeholder.add_theme_font_size_override("font_size", 14)
	placeholder.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vocab_list_grid.add_child(placeholder)


func _get_octant_emoji_count(octant_index: int) -> int:
	"""Get number of discovered emojis in an octant."""
	if vocabulary_data.has(octant_index):
		var octant_items = vocabulary_data[octant_index]
		if octant_items is Array:
			return octant_items.size()
	return 0


func _assign_emoji_to_octant(north_emoji: String, south_emoji: String, stability: float) -> int:
	"""Assign an emoji pair to an octant based on heuristic.

	Uses stability and emoji properties to determine octant assignment (0-7).
	Simple heuristic: uses string hash to distribute emojis.
	"""
	# Simple hash-based distribution for now
	# In a full implementation, could use emoji semantic meaning or learned associations
	var hash_value = hash(north_emoji + south_emoji)
	var octant = abs(hash_value) % 8

	# Adjust based on stability for more semantic meaning
	if stability > 0.7:
		octant = (octant + 1) % 8  # Shift toward positive regions
	elif stability < 0.3:
		octant = (octant + 4) % 8  # Shift toward negative regions

	return octant


func _update_view() -> void:
	"""Update visibility based on current view mode."""
	view_mode_label.text = "[F] %s" % VIEW_MODE_NAMES[current_view_mode]

	vocab_list_container.visible = (current_view_mode == ViewMode.VOCAB_LIST)
	octant_grid.visible = (current_view_mode == ViewMode.OCTANT_GRID)
	vocab_container.visible = (current_view_mode == ViewMode.VOCABULARY)
	attractor_container.visible = (current_view_mode == ViewMode.ATTRACTOR_MAP)

	# Populate vocab list when entering that mode
	if current_view_mode == ViewMode.VOCAB_LIST:
		_populate_vocab_list()


func _update_selection_visual() -> void:
	"""Update visual highlight of selected octant."""
	for i in range(octant_panels.size()):
		var panel = octant_panels[i]
		var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			var region = REGIONS[i]
			if i == selected_octant:
				style.border_color = Color(1.0, 1.0, 0.5)
				style.border_width_left = 4
				style.border_width_right = 4
				style.border_width_top = 4
				style.border_width_bottom = 4
			else:
				style.border_color = region.color
				style.border_width_left = 2
				style.border_width_right = 2
				style.border_width_top = 2
				style.border_width_bottom = 2


# ============================================================================
# ACTION HANDLERS
# ============================================================================

func on_q_pressed() -> void:
	"""Q = Previous octant."""
	selected_octant = (selected_octant - 1) % 8
	if selected_octant < 0:
		selected_octant = 7
	_update_selection_visual()
	action_performed.emit("prev_octant", {"octant": selected_octant, "name": REGIONS[selected_octant].name})


func on_e_pressed() -> void:
	"""E = Next octant / Zoom in."""
	if current_view_mode == ViewMode.OCTANT_GRID:
		selected_octant = (selected_octant + 1) % 8
		_update_selection_visual()
		action_performed.emit("next_octant", {"octant": selected_octant, "name": REGIONS[selected_octant].name})
	else:
		# Zoom into selected octant vocabulary
		current_view_mode = ViewMode.VOCABULARY
		_update_view()
		_populate_vocabulary_grid()


func on_r_pressed() -> void:
	"""R = Show attractors."""
	current_view_mode = ViewMode.ATTRACTOR_MAP
	_update_view()
	action_performed.emit("show_attractors", {})


func on_f_pressed() -> void:
	"""F = Cycle view mode."""
	current_view_mode = (current_view_mode + 1) % VIEW_MODE_NAMES.size()
	_update_view()
	if current_view_mode == ViewMode.VOCABULARY:
		_populate_vocabulary_grid()
	action_performed.emit("cycle_view", {"mode": VIEW_MODE_NAMES[current_view_mode]})


func _populate_vocabulary_grid() -> void:
	"""Populate emoji grid with vocabulary for selected octant."""
	# Clear existing
	for child in emoji_grid.get_children():
		child.queue_free()

	# Update header
	var header = vocab_container.find_child("OctantHeader", true, false)
	if header:
		var region = REGIONS[selected_octant]
		var count = _get_octant_emoji_count(selected_octant)
		header.text = "%s %s - %d vocabulary items" % [region.icon, region.name, count]

	# Add vocabulary pairs for selected octant
	if vocabulary_data.has(selected_octant):
		var octant_vocab = vocabulary_data[selected_octant]
		if octant_vocab is Array:
			for vocab_item in octant_vocab:
				# Create a pair display
				var hbox = HBoxContainer.new()
				hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

				# North emoji
				var north_label = Label.new()
				north_label.text = vocab_item.get("north", "?")
				north_label.add_theme_font_size_override("font_size", 20)
				hbox.add_child(north_label)

				# Arrow
				var arrow_label = Label.new()
				arrow_label.text = "↔"
				arrow_label.add_theme_font_size_override("font_size", 16)
				hbox.add_child(arrow_label)

				# South emoji
				var south_label = Label.new()
				south_label.text = vocab_item.get("south", "?")
				south_label.add_theme_font_size_override("font_size", 20)
				hbox.add_child(south_label)

				# Stability indicator
				var stability = vocab_item.get("stability", 0.5)
				var stability_label = Label.new()
				var star_count = int(stability * 5)
				var stars = ""
				for i in range(star_count):
					stars += "★"
				stability_label.text = stars if stars else "☆"
				stability_label.add_theme_color_override("font_color", Color.YELLOW)
				hbox.add_child(stability_label)

				emoji_grid.add_child(hbox)
	else:
		# Show placeholder if no vocabulary in this octant
		var placeholder = Label.new()
		placeholder.text = "No vocabulary discovered\nin this octant yet"
		placeholder.add_theme_font_size_override("font_size", 16)
		placeholder.add_theme_color_override("font_color", Color.GRAY)
		emoji_grid.add_child(placeholder)


func get_action_labels() -> Dictionary:
	"""v2 overlay interface: Get context-sensitive labels."""
	var labels = action_labels.duplicate()

	if current_view_mode == ViewMode.OCTANT_GRID:
		labels["E"] = "Next Octant"
	else:
		labels["E"] = "Zoom In"

	return labels
