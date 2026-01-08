class_name FactionBrowser
extends Control

## Faction Browser - Shows All Accessible Factions
## Opened from QuestBoard with C key
## Filtered by player vocabulary

signal faction_selected(faction_quest: Dictionary)
signal browser_closed

# References
var layout_manager: Node
var quest_manager: Node
var target_slot_index: int = 0
var current_biome: Node = null

# UI elements
var background: ColorRect
var browser_panel: PanelContainer
var title_label: Label
var scroll_container: ScrollContainer
var faction_list: VBoxContainer
var selected_faction_index: int = 0
var faction_items: Array = []  # Array of FactionItem instances


func _init():
	name = "FactionBrowser"

	# Fill entire screen - proper modal design
	set_anchors_preset(Control.PRESET_FULL_RECT)
	layout_mode = 1
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_create_ui()
	visible = false


func set_layout_manager(manager: Node) -> void:
	layout_manager = manager


func set_quest_manager(manager: Node) -> void:
	quest_manager = manager


func _unhandled_key_input(event: InputEvent) -> void:
	"""Handle input using unhandled input pattern"""
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_ESCAPE, KEY_C:
			close_browser()
			get_viewport().set_input_as_handled()

		# Navigate (UIOP)
		KEY_U:
			move_selection(-1)
			get_viewport().set_input_as_handled()
		KEY_I:
			move_selection(-3)  # Page up
			get_viewport().set_input_as_handled()
		KEY_O:
			move_selection(3)   # Page down
			get_viewport().set_input_as_handled()
		KEY_P:
			move_selection(1)
			get_viewport().set_input_as_handled()

		# Arrow keys for navigation
		KEY_UP:
			move_selection(-1)  # Up one
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			move_selection(1)   # Down one
			get_viewport().set_input_as_handled()
		KEY_PAGEUP:
			move_selection(-3)  # Page up
			get_viewport().set_input_as_handled()
		KEY_PAGEDOWN:
			move_selection(3)   # Page down
			get_viewport().set_input_as_handled()

		# Select (Q or Enter)
		KEY_Q, KEY_ENTER, KEY_KP_ENTER:
			select_current_faction()
			get_viewport().set_input_as_handled()


func handle_input(event: InputEvent) -> bool:
	"""Modal input handler - called by QuestBoard when on modal stack

	Returns true if input was consumed, false otherwise.
	"""
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return false

	match event.keycode:
		KEY_ESCAPE, KEY_C:
			close_browser()
			return true

		# Navigate (UIOP)
		KEY_U:
			move_selection(-1)
			return true
		KEY_I:
			move_selection(-3)  # Page up
			return true
		KEY_O:
			move_selection(3)   # Page down
			return true
		KEY_P:
			move_selection(1)
			return true

		# Arrow keys for navigation
		KEY_UP:
			move_selection(-1)  # Up one
			return true
		KEY_DOWN:
			move_selection(1)   # Down one
			return true
		KEY_PAGEUP:
			move_selection(-3)  # Page up
			return true
		KEY_PAGEDOWN:
			move_selection(3)   # Page down
			return true

		# Select (Q or Enter)
		KEY_Q, KEY_ENTER, KEY_KP_ENTER:
			select_current_faction()
			return true

	return false  # Input not consumed


func _create_ui() -> void:
	"""Create the faction browser UI - RESPONSIVE DESIGN matching QuestBoard"""
	var scale = layout_manager.scale_factor if layout_manager else 1.0

	# Fixed font sizes for 960×540 base resolution
	var title_size = 24
	var normal_size = 14

	# Background - fill screen (darker than quest board for drill-down effect)
	background = ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.85)  # Slightly darker
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.layout_mode = 1
	add_child(background)

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.layout_mode = 1
	add_child(center)

	# Browser panel - Fixed size for 960×540 base resolution (~70% width, 75% height)
	browser_panel = PanelContainer.new()
	browser_panel.custom_minimum_size = Vector2(670, 400)
	center.add_child(browser_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", int(10 * scale))
	browser_panel.add_child(main_vbox)

	# Header
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	title_label = Label.new()
	title_label.text = "⚛️ FACTION BROWSER"
	title_label.add_theme_font_size_override("font_size", title_size)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_label)

	var close_button = Button.new()
	close_button.text = "← Back [C/ESC]"
	close_button.pressed.connect(close_browser)
	header_hbox.add_child(close_button)

	# Controls hint
	var controls = Label.new()
	controls.text = "[↑↓ or UIOP] Navigate  [ENTER or Q] Select  [ESC/C] Back"
	controls.add_theme_font_size_override("font_size", normal_size)
	controls.modulate = Color(0.8, 0.8, 0.8)
	main_vbox.add_child(controls)

	# Scroll container - Fixed height for 960×540 base resolution
	scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(0, 320)  # ~60% of 540
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll_container)

	# Faction list
	faction_list = VBoxContainer.new()
	faction_list.add_theme_constant_override("separation", int(6 * scale))
	scroll_container.add_child(faction_list)


func show_for_slot(slot_index: int, biome: Node) -> void:
	"""Show browser for selecting faction for given slot"""
	target_slot_index = slot_index
	current_biome = biome

	visible = true
	_refresh_faction_list()


func close_browser() -> void:
	"""Close the browser"""
	visible = false
	browser_closed.emit()


func _refresh_faction_list() -> void:
	"""Refresh faction list from quest manager"""
	# Clear existing
	for item in faction_items:
		item.queue_free()
	faction_items.clear()

	if not quest_manager or not current_biome:
		return

	# Get all accessible quests sorted by alignment
	var all_quests = quest_manager.offer_all_faction_quests(current_biome)

	if all_quests.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No accessible factions!\nLearn more emojis by completing quests."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		faction_list.add_child(empty_label)
		return

	# Update title
	title_label.text = "⚛️ FACTION BROWSER → Will fill slot [%s]" % ["UIOP"[target_slot_index]]

	# Create faction items
	for i in range(all_quests.size()):
		var quest = all_quests[i]
		var item = FactionItem.new()
		item.set_layout_manager(layout_manager)
		item.set_quest_data(quest, i)
		item.faction_clicked.connect(_on_faction_clicked.bind(i))
		faction_list.add_child(item)
		faction_items.append(item)

	# Select first faction
	selected_faction_index = 0
	_update_selection()


func move_selection(delta: int) -> void:
	"""Move selection by delta"""
	if faction_items.is_empty():
		return

	selected_faction_index = clampi(selected_faction_index + delta, 0, faction_items.size() - 1)
	_update_selection()

	# Scroll to selected
	if scroll_container and selected_faction_index < faction_items.size():
		var item = faction_items[selected_faction_index]
		scroll_container.ensure_control_visible(item)


func _update_selection() -> void:
	"""Update visual selection state"""
	for i in range(faction_items.size()):
		faction_items[i].set_selected(i == selected_faction_index)


func select_current_faction() -> void:
	"""Select the currently highlighted faction"""
	if selected_faction_index >= 0 and selected_faction_index < faction_items.size():
		var item = faction_items[selected_faction_index]
		faction_selected.emit(item.quest_data)
		close_browser()


func _on_faction_clicked(index: int) -> void:
	"""Handle faction item clicked"""
	selected_faction_index = index
	_update_selection()
	select_current_faction()


# =============================================================================
# FACTION ITEM COMPONENT
# =============================================================================

class FactionItem extends PanelContainer:
	"""Individual faction display in browser"""

	signal faction_clicked

	var layout_manager: Node
	var quest_data: Dictionary
	var item_index: int = 0
	var is_selected: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				faction_clicked.emit()
				accept_event()

	func set_layout_manager(manager: Node) -> void:
		layout_manager = manager

	func set_quest_data(quest: Dictionary, index: int) -> void:
		quest_data = quest
		item_index = index
		_create_ui()

	func set_selected(selected: bool) -> void:
		is_selected = selected
		_refresh_selection()

	func _create_ui() -> void:
		var scale = layout_manager.scale_factor if layout_manager else 1.0

		# Fixed font sizes for 960×540 base resolution
		var faction_size = 15
		var normal_size = 13
		var small_size = 11

		# Fixed item height
		custom_minimum_size = Vector2(0, 65)

		# Background color based on alignment
		var alignment = quest_data.get("_alignment", 0.5)
		_set_bg_color(_get_alignment_color(alignment))

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", int(3 * scale))
		add_child(vbox)

		# Faction header
		var header_hbox = HBoxContainer.new()
		vbox.add_child(header_hbox)

		var faction_label = Label.new()
		var ring = quest_data.get("ring", "")
		var ring_display = " [%s]" % ring.capitalize() if ring else ""
		faction_label.text = "%s %s%s" % [
			quest_data.get("faction_emoji", ""),
			quest_data.get("faction", "Unknown"),
			ring_display
		]
		faction_label.add_theme_font_size_override("font_size", faction_size)
		faction_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_hbox.add_child(faction_label)

		# Alignment
		var alignment_label = Label.new()
		alignment_label.text = "%d%%" % int(alignment * 100)
		alignment_label.add_theme_font_size_override("font_size", small_size)
		alignment_label.modulate = _get_alignment_text_color(alignment)
		header_hbox.add_child(alignment_label)

		# Motto
		var motto = quest_data.get("motto", "")
		if motto and motto != "":
			var motto_label = Label.new()
			motto_label.text = '"%s"' % motto
			motto_label.add_theme_font_size_override("font_size", small_size)
			motto_label.modulate = Color(0.9, 0.9, 0.7)
			motto_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(motto_label)

		# Quest details
		var details_label = Label.new()
		details_label.text = "Quest: %s" % quest_data.get("body", "")
		details_label.add_theme_font_size_override("font_size", normal_size)
		details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(details_label)

		# Vocabulary info
		var vocab_label = Label.new()
		var faction_vocab = quest_data.get("faction_vocabulary", [])
		var available_vocab = quest_data.get("available_emojis", [])
		var overlap_pct = quest_data.get("vocabulary_overlap_pct", 0.0)

		if overlap_pct >= 1.0:
			vocab_label.text = "📖 Vocab: %s (all known ✓)" % " ".join(faction_vocab.slice(0, 5))
		else:
			var unknown_count = faction_vocab.size() - available_vocab.size()
			vocab_label.text = "📖 Vocab: %s (%d/%d known)" % [
				" ".join(faction_vocab.slice(0, 5)),
				available_vocab.size(),
				faction_vocab.size()
			]

		vocab_label.add_theme_font_size_override("font_size", small_size)
		vocab_label.modulate = Color(0.7, 0.9, 1.0)
		vbox.add_child(vocab_label)

	func _refresh_selection() -> void:
		"""Update selection visual - THICKER gold border when selected"""
		var current_style = get_theme_stylebox("panel")
		if current_style and current_style is StyleBoxFlat:
			if is_selected:
				# SELECTED: Extra thick gold border (matching QuestBoard)
				current_style.border_width_left = 6
				current_style.border_width_right = 6
				current_style.border_width_top = 6
				current_style.border_width_bottom = 6
				current_style.border_color = Color(1.0, 0.9, 0.0)  # Bright gold
			else:
				# NORMAL: Standard thick border
				current_style.border_width_left = 4
				current_style.border_width_right = 4
				current_style.border_width_top = 4
				current_style.border_width_bottom = 4
				current_style.border_color = Color(0.7, 0.7, 0.7, 0.8)

	func _set_bg_color(color: Color) -> void:
		# FLASH GAME STYLE - Chunky borders matching QuestBoard and ESC menu
		var style = StyleBoxFlat.new()
		style.bg_color = color
		style.border_color = Color(0.7, 0.7, 0.7, 0.8)  # Brighter border
		style.border_width_left = 4  # THICKER borders!
		style.border_width_right = 4
		style.border_width_top = 4
		style.border_width_bottom = 4
		style.corner_radius_top_left = 12  # Rounder corners
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.content_margin_left = 16  # MORE PADDING!
		style.content_margin_right = 16
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		add_theme_stylebox_override("panel", style)

	func _get_alignment_color(alignment: float) -> Color:
		if alignment > 0.7:
			return Color(0.2, 0.4, 0.2, 0.8)
		elif alignment > 0.5:
			return Color(0.3, 0.3, 0.2, 0.8)
		elif alignment > 0.3:
			return Color(0.4, 0.3, 0.2, 0.8)
		else:
			return Color(0.4, 0.2, 0.2, 0.8)

	func _get_alignment_text_color(alignment: float) -> Color:
		if alignment > 0.7:
			return Color(0.5, 1.0, 0.5)
		elif alignment > 0.5:
			return Color(1.0, 1.0, 0.7)
		elif alignment > 0.3:
			return Color(1.0, 0.7, 0.5)
		else:
			return Color(1.0, 0.5, 0.5)
