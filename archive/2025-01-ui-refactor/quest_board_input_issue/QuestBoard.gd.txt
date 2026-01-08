class_name QuestBoard
extends Control

## Modal Quest Board with 4 Slots (UIOP)
## Controls hijacked when open (like ESC menu)
## Press C to drill into faction browser

signal quest_accepted(quest: Dictionary)
signal quest_completed(quest_id: int, rewards: Dictionary)
signal quest_abandoned(quest_id: int)
signal board_closed

# References
var layout_manager: Node
var quest_manager: Node
var current_biome: Node

# UI elements
var background: ColorRect
var menu_panel: PanelContainer
var title_label: Label
var biome_state_label: Label
var controls_label: Label
var slot_container: VBoxContainer
var accessible_factions_label: Label

# Quest slots (4 slots: U, I, O, P)
var quest_slots: Array = []  # Array of QuestSlot instances
var selected_slot_index: int = 0

# Faction browser
var faction_browser: Node = null
var is_browser_open: bool = false

# Slot letters
const SLOT_KEYS = ["U", "I", "O", "P"]

# Quest slot states
enum SlotState {
	EMPTY,
	OFFERED,
	ACTIVE,
	READY,    # Can be completed
	LOCKED    # Locked offer (won't auto-refresh)
}


func _init():
	name = "QuestBoard"

	# Fill entire screen - proper modal design like ESC menu
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

	# Connect to quest manager signals
	if quest_manager:
		quest_manager.quest_completed.connect(_on_quest_completed)
		quest_manager.active_quests_changed.connect(_refresh_slots)


func set_biome(biome: Node) -> void:
	current_biome = biome


func _unhandled_key_input(event: InputEvent) -> void:
	"""Modal input handling - hijacks controls when open

	Using _unhandled_key_input() ensures proper input order:
	1. FactionBrowser (child) gets first chance
	2. Then QuestBoard handles unhandled input
	"""
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return

	# If browser is open, it handles input first
	if is_browser_open and faction_browser and faction_browser.visible:
		return

	_handle_board_input(event)




func _handle_board_input(event: InputEvent) -> void:
	"""Handle quest board controls"""
	match event.keycode:
		KEY_ESCAPE:
			close_board()
			get_viewport().set_input_as_handled()

		# Slot selection (UIOP)
		KEY_U:
			select_slot(0)
			get_viewport().set_input_as_handled()
		KEY_I:
			select_slot(1)
			get_viewport().set_input_as_handled()
		KEY_O:
			select_slot(2)
			get_viewport().set_input_as_handled()
		KEY_P:
			select_slot(3)
			get_viewport().set_input_as_handled()

		# Actions on selected slot (QER)
		KEY_Q:
			action_q_on_selected()  # Accept or Complete
			get_viewport().set_input_as_handled()
		KEY_E:
			action_e_on_selected()  # Reroll or Abandon
			get_viewport().set_input_as_handled()
		KEY_R:
			action_r_on_selected()  # Lock toggle
			get_viewport().set_input_as_handled()

		# Open faction browser
		KEY_C:
			open_faction_browser()
			get_viewport().set_input_as_handled()


func _handle_browser_input(event: InputEvent) -> void:
	"""Handle faction browser controls"""
	if faction_browser and faction_browser.has_method("handle_input"):
		faction_browser.handle_input(event)


func _create_ui() -> void:
	"""Create the quest board UI - proper modal design like ESC menu"""
	var scale = layout_manager.scale_factor if layout_manager else 1.0
	var title_size = layout_manager.get_scaled_font_size(20) if layout_manager else 20
	var normal_size = layout_manager.get_scaled_font_size(12) if layout_manager else 12

	# Background - fill screen to block interaction
	background = ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.7)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.layout_mode = 1
	add_child(background)

	# Center container for panel
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.layout_mode = 1
	add_child(center)

	# Quest board panel
	menu_panel = PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(800 * scale, 700 * scale)
	center.add_child(menu_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", int(10 * scale))
	menu_panel.add_child(main_vbox)

	# Header
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	title_label = Label.new()
	title_label.text = "⚛️ QUEST BOARD"
	title_label.add_theme_font_size_override("font_size", title_size)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_label)

	var close_button = Button.new()
	close_button.text = "✖ Close [ESC]"
	close_button.pressed.connect(close_board)
	header_hbox.add_child(close_button)

	# Controls hint
	controls_label = Label.new()
	controls_label.text = "[UIOP]Select  [Q]Accept/Complete  [E]Reroll/Abandon  [R]Lock  [C]Browse Factions"
	controls_label.add_theme_font_size_override("font_size", normal_size)
	controls_label.modulate = Color(0.8, 0.8, 0.8)
	main_vbox.add_child(controls_label)

	# Biome state display
	biome_state_label = Label.new()
	biome_state_label.text = "Biome State: Loading..."
	biome_state_label.add_theme_font_size_override("font_size", normal_size)
	biome_state_label.modulate = Color(0.7, 0.9, 1.0)
	biome_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(biome_state_label)

	# Quest slots container
	slot_container = VBoxContainer.new()
	slot_container.add_theme_constant_override("separation", int(8 * scale))
	main_vbox.add_child(slot_container)

	# Create 4 quest slots
	for i in range(4):
		var slot = QuestSlot.new()
		slot.set_layout_manager(layout_manager)
		slot.slot_letter = SLOT_KEYS[i]
		slot.slot_index = i
		slot.slot_selected.connect(_on_slot_selected)
		slot_container.add_child(slot)
		quest_slots.append(slot)

	# Accessible factions label
	accessible_factions_label = Label.new()
	accessible_factions_label.text = "📚 Accessible Factions: 0/68"
	accessible_factions_label.add_theme_font_size_override("font_size", normal_size)
	accessible_factions_label.modulate = Color(0.9, 0.9, 0.7)
	main_vbox.add_child(accessible_factions_label)

	# Select first slot by default
	select_slot(0)


func open_board() -> void:
	"""Open the quest board"""
	if not quest_manager or not current_biome:
		push_error("QuestBoard: quest_manager or current_biome not set")
		return

	visible = true
	_refresh_biome_state()
	_refresh_slots()
	_update_accessible_count()


func close_board() -> void:
	"""Close the quest board"""
	visible = false
	is_browser_open = false
	if faction_browser:
		faction_browser.visible = false
	board_closed.emit()


func open_faction_browser() -> void:
	"""Open faction browser for selected slot"""
	if not faction_browser:
		_create_faction_browser()

	is_browser_open = true
	faction_browser.show_for_slot(selected_slot_index, current_biome)


func close_faction_browser() -> void:
	"""Close faction browser"""
	is_browser_open = false
	if faction_browser:
		faction_browser.visible = false


func _create_faction_browser() -> void:
	"""Create the faction browser panel"""
	const FactionBrowser = preload("res://UI/Panels/FactionBrowser.gd")
	faction_browser = FactionBrowser.new()
	faction_browser.set_layout_manager(layout_manager)
	faction_browser.set_quest_manager(quest_manager)
	faction_browser.faction_selected.connect(_on_faction_selected)
	faction_browser.browser_closed.connect(close_faction_browser)
	add_child(faction_browser)


func _refresh_biome_state() -> void:
	"""Update biome state display"""
	if not quest_manager or not current_biome:
		return

	var obs = quest_manager.get_biome_observables(current_biome)
	biome_state_label.text = "🌾 Biome: Purity %.0f%% | Entropy %.0f%% | Coherence %.0f%% | Scale %.0f%%" % [
		obs.purity * 100,
		obs.entropy * 100,
		obs.coherence * 100,
		obs.scale * 100
	]


func _refresh_slots() -> void:
	"""Refresh all quest slots from quest manager and game state"""
	if not quest_manager:
		return

	# Load slot data from GameStateManager
	var slot_data = GameStateManager.current_state.quest_slots if GameStateManager.current_state else []

	for i in range(4):
		var slot = quest_slots[i]

		# Load saved slot data if available
		if i < slot_data.size() and slot_data[i] != null:
			var data = slot_data[i]

			# Check if quest is still active in quest manager
			var quest_id = data.get("quest_id", -1)
			var active_quest = quest_manager.get_quest_by_id(quest_id) if quest_id >= 0 else {}

			if not active_quest.is_empty():
				# Quest still active
				slot.set_quest_active(active_quest)
			elif data.get("is_locked", false) and data.has("offered_quest"):
				# Locked offer
				slot.set_quest_offered(data.offered_quest, true)
			else:
				# Slot expired or completed - auto-fill new
				_auto_fill_slot(i)
		else:
			# Empty slot - auto-fill
			_auto_fill_slot(i)

	_update_slot_selection()


func _auto_fill_slot(slot_index: int) -> void:
	"""Auto-fill slot with best-aligned accessible quest"""
	if not quest_manager or not current_biome:
		return

	var slot = quest_slots[slot_index]

	# Don't auto-fill locked slots
	if slot.is_locked:
		return

	# Get all accessible quests
	var all_quests = quest_manager.offer_all_faction_quests(current_biome)

	if all_quests.is_empty():
		slot.set_empty()
		return

	# Filter out quests from factions already in other slots
	var used_factions = []
	for i in range(4):
		if i == slot_index:
			continue
		var other_slot = quest_slots[i]
		if other_slot.quest_data.has("faction"):
			used_factions.append(other_slot.quest_data.faction)

	# Find best quest not already used
	for quest in all_quests:
		if quest.get("faction", "") not in used_factions:
			slot.set_quest_offered(quest, false)
			_save_slot_state()
			return

	# All factions used - just take first available
	if all_quests.size() > 0:
		slot.set_quest_offered(all_quests[0], false)
		_save_slot_state()


func _update_accessible_count() -> void:
	"""Update accessible factions count"""
	if not quest_manager or not current_biome:
		return

	var all_quests = quest_manager.offer_all_faction_quests(current_biome)
	accessible_factions_label.text = "📚 %d/68 factions accessible (learn more emojis!)" % all_quests.size()


func select_slot(index: int) -> void:
	"""Select a quest slot"""
	if index < 0 or index >= quest_slots.size():
		return

	selected_slot_index = index
	_update_slot_selection()


func _update_slot_selection() -> void:
	"""Update visual selection state of slots"""
	for i in range(quest_slots.size()):
		quest_slots[i].set_selected(i == selected_slot_index)


func _on_slot_selected(slot_index: int) -> void:
	"""Handle slot clicked/selected"""
	select_slot(slot_index)


# =============================================================================
# ACTIONS
# =============================================================================

func action_q_on_selected() -> void:
	"""Q action: Accept (OFFERED) or Complete (READY)"""
	var slot = quest_slots[selected_slot_index]

	match slot.state:
		SlotState.OFFERED:
			_accept_quest(slot)
		SlotState.READY:
			_complete_quest(slot)
		SlotState.ACTIVE:
			# Check if ready to complete
			if _check_can_complete(slot):
				slot.state = SlotState.READY
				slot._refresh_ui()
				_complete_quest(slot)


func action_e_on_selected() -> void:
	"""E action: Reroll (OFFERED) or Abandon (ACTIVE)"""
	var slot = quest_slots[selected_slot_index]

	match slot.state:
		SlotState.OFFERED:
			if not slot.is_locked:
				_reroll_quest(slot)
		SlotState.ACTIVE:
			_abandon_quest(slot)


func action_r_on_selected() -> void:
	"""R action: Lock/Unlock toggle"""
	var slot = quest_slots[selected_slot_index]
	slot.toggle_lock()
	_save_slot_state()


func _accept_quest(slot: QuestSlot) -> void:
	"""Accept an offered quest"""
	if not quest_manager:
		return

	var success = quest_manager.accept_quest(slot.quest_data)
	if success:
		slot.set_quest_active(slot.quest_data)
		quest_accepted.emit(slot.quest_data)
		_save_slot_state()
		print("✅ Accepted quest: %s" % slot.quest_data.get("faction", "Unknown"))


func _complete_quest(slot: QuestSlot) -> void:
	"""Complete an active quest"""
	if not quest_manager:
		return

	var quest_id = slot.quest_data.get("id", -1)
	if quest_id < 0:
		return

	var success = quest_manager.complete_quest(quest_id)
	if success:
		print("🎉 Completed quest: %s" % slot.quest_data.get("faction", "Unknown"))
		# Slot will be auto-filled on next refresh


func _abandon_quest(slot: QuestSlot) -> void:
	"""Abandon an active quest"""
	if not quest_manager:
		return

	var quest_id = slot.quest_data.get("id", -1)
	if quest_id < 0:
		return

	quest_manager.fail_quest(quest_id, "player_abandoned")
	quest_abandoned.emit(quest_id)
	_auto_fill_slot(slot.slot_index)
	_save_slot_state()
	print("❌ Abandoned quest: %s" % slot.quest_data.get("faction", "Unknown"))


func _reroll_quest(slot: QuestSlot) -> void:
	"""Reroll quest in slot (get random different faction)"""
	if not quest_manager or not current_biome:
		return

	var all_quests = quest_manager.offer_all_faction_quests(current_biome)

	# Filter out current faction and other slots
	var current_faction = slot.quest_data.get("faction", "")
	var used_factions = [current_faction]

	for i in range(4):
		if i == slot.slot_index:
			continue
		var other_slot = quest_slots[i]
		if other_slot.quest_data.has("faction"):
			used_factions.append(other_slot.quest_data.faction)

	# Find quests from different factions
	var available = []
	for quest in all_quests:
		if quest.get("faction", "") not in used_factions:
			available.append(quest)

	if available.is_empty():
		print("⚠️ No other factions available to reroll")
		return

	# Pick random
	var new_quest = available[randi() % available.size()]
	slot.set_quest_offered(new_quest, slot.is_locked)
	_save_slot_state()
	print("🔄 Rerolled to: %s" % new_quest.get("faction", "Unknown"))


func _check_can_complete(slot: QuestSlot) -> bool:
	"""Check if quest can be completed"""
	if not quest_manager:
		return false

	var quest_id = slot.quest_data.get("id", -1)
	if quest_id < 0:
		return false

	return quest_manager.check_quest_completion(quest_id)


func _on_faction_selected(faction_quest: Dictionary) -> void:
	"""Handle faction selected from browser"""
	var slot = quest_slots[selected_slot_index]
	slot.set_quest_offered(faction_quest, slot.is_locked)
	_save_slot_state()
	close_faction_browser()


func _on_quest_completed(quest_id: int, rewards: Dictionary) -> void:
	"""Handle quest completed signal from manager"""
	# Find slot with this quest and auto-fill
	for i in range(4):
		var slot = quest_slots[i]
		if slot.quest_data.get("id", -1) == quest_id:
			_auto_fill_slot(i)
			break

	quest_completed.emit(quest_id, rewards)


func _save_slot_state() -> void:
	"""Save slot state to GameStateManager"""
	if not GameStateManager.current_state:
		return

	var slot_data = []
	for slot in quest_slots:
		if slot.state == SlotState.EMPTY:
			slot_data.append(null)
		else:
			slot_data.append({
				"quest_id": slot.quest_data.get("id", -1),
				"offered_quest": slot.quest_data if slot.state == SlotState.OFFERED else null,
				"is_locked": slot.is_locked,
				"state": slot.state
			})

	GameStateManager.current_state.quest_slots = slot_data


# =============================================================================
# QUEST SLOT COMPONENT
# =============================================================================

class QuestSlot extends PanelContainer:
	"""Individual quest slot display"""

	signal slot_selected(slot_index: int)

	var layout_manager: Node
	var slot_letter: String = "U"
	var slot_index: int = 0
	var state: int = SlotState.EMPTY
	var quest_data: Dictionary = {}
	var is_locked: bool = false
	var is_selected: bool = false

	# UI elements
	var header_label: Label
	var faction_label: Label
	var details_label: Label
	var status_label: Label
	var action_label: Label

	func _ready() -> void:
		_create_ui()
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				slot_selected.emit(slot_index)
				accept_event()

	func set_layout_manager(manager: Node) -> void:
		layout_manager = manager

	func _create_ui() -> void:
		var scale = layout_manager.scale_factor if layout_manager else 1.0
		var header_size = layout_manager.get_scaled_font_size(14) if layout_manager else 14
		var normal_size = layout_manager.get_scaled_font_size(12) if layout_manager else 12
		var small_size = layout_manager.get_scaled_font_size(10) if layout_manager else 10

		custom_minimum_size = Vector2(0, 120 * scale)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", int(3 * scale))
		add_child(vbox)

		# Header: [U] Faction Name
		header_label = Label.new()
		header_label.add_theme_font_size_override("font_size", header_size)
		vbox.add_child(header_label)

		# Faction emoji and name
		faction_label = Label.new()
		faction_label.add_theme_font_size_override("font_size", normal_size)
		vbox.add_child(faction_label)

		# Quest details
		details_label = Label.new()
		details_label.add_theme_font_size_override("font_size", normal_size)
		details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(details_label)

		# Status
		status_label = Label.new()
		status_label.add_theme_font_size_override("font_size", small_size)
		vbox.add_child(status_label)

		# Actions
		action_label = Label.new()
		action_label.add_theme_font_size_override("font_size", small_size)
		action_label.modulate = Color(0.8, 0.8, 0.8)
		vbox.add_child(action_label)

		_refresh_ui()

	func set_empty() -> void:
		state = SlotState.EMPTY
		quest_data = {}
		is_locked = false
		_refresh_ui()

	func set_quest_offered(quest: Dictionary, locked: bool) -> void:
		state = SlotState.OFFERED
		quest_data = quest
		is_locked = locked
		_refresh_ui()

	func set_quest_active(quest: Dictionary) -> void:
		state = SlotState.ACTIVE
		quest_data = quest
		_refresh_ui()

	func toggle_lock() -> void:
		is_locked = !is_locked
		_refresh_ui()

	func set_selected(selected: bool) -> void:
		is_selected = selected
		_refresh_ui()

	func _refresh_ui() -> void:
		# Update header
		var lock_icon = "🔒 " if is_locked else ""
		header_label.text = "[%s] %sSlot %s" % [slot_letter, lock_icon, slot_letter]

		# Update based on state
		match state:
			SlotState.EMPTY:
				faction_label.text = "(Empty)"
				details_label.text = "Press [E] to generate quest"
				status_label.text = "Status: EMPTY"
				action_label.text = ""
				_set_bg_color(Color(0.15, 0.15, 0.15, 0.8))

			SlotState.OFFERED:
				var ring = quest_data.get("ring", "")
				var ring_display = " [%s]" % ring.capitalize() if ring else ""
				faction_label.text = "%s %s%s" % [
					quest_data.get("faction_emoji", ""),
					quest_data.get("faction", "Unknown"),
					ring_display
				]
				details_label.text = '"%s"\n%s' % [
					quest_data.get("motto", ""),
					quest_data.get("body", "")
				]
				var alignment = quest_data.get("_alignment", 0.5)
				var time_limit = quest_data.get("time_limit", -1)
				var time_str = "⏰%ds" % int(time_limit) if time_limit > 0 else "🕰️No limit"
				status_label.text = "Alignment: %d%% | %s | 🎁%.1fx" % [
					int(alignment * 100),
					time_str,
					quest_data.get("reward_multiplier", 2.0)
				]
				action_label.text = "[Q]Accept  [E]Reroll  [R]%s" % ("Unlock" if is_locked else "Lock")
				_set_bg_color(_get_alignment_color(alignment))

			SlotState.ACTIVE:
				faction_label.text = "%s %s (ACTIVE)" % [
					quest_data.get("faction_emoji", ""),
					quest_data.get("faction", "Unknown")
				]
				details_label.text = quest_data.get("body", "")
				var time_limit = quest_data.get("time_limit", -1)
				var time_str = "⏰Time left: ???" if time_limit > 0 else "🕰️No limit"
				status_label.text = "Status: ACTIVE | %s" % time_str
				action_label.text = "[Q]Complete  [E]Abandon"
				_set_bg_color(Color(0.2, 0.3, 0.4, 0.8))

			SlotState.READY:
				faction_label.text = "%s %s ✅ READY" % [
					quest_data.get("faction_emoji", ""),
					quest_data.get("faction", "Unknown")
				]
				details_label.text = quest_data.get("body", "")
				status_label.text = "Status: READY TO COMPLETE!"
				status_label.modulate = Color(0.5, 1.0, 0.5)
				action_label.text = "[Q]Complete!"
				_set_bg_color(Color(0.2, 0.5, 0.2, 0.9))

		# Highlight if selected
		if is_selected:
			var current_style = get_theme_stylebox("panel")
			if current_style:
				current_style.border_width_left = 4
				current_style.border_width_right = 4
				current_style.border_width_top = 4
				current_style.border_width_bottom = 4
				current_style.border_color = Color(1.0, 0.9, 0.3)  # Gold

	func _set_bg_color(color: Color) -> void:
		var style = StyleBoxFlat.new()
		style.bg_color = color
		style.border_color = Color(0.5, 0.5, 0.5, 0.5)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		add_theme_stylebox_override("panel", style)

	func _get_alignment_color(alignment: float) -> Color:
		if alignment > 0.7:
			return Color(0.2, 0.4, 0.2, 0.8)  # Green
		elif alignment > 0.5:
			return Color(0.3, 0.3, 0.2, 0.8)  # Neutral
		elif alignment > 0.3:
			return Color(0.4, 0.3, 0.2, 0.8)  # Orange
		else:
			return Color(0.4, 0.2, 0.2, 0.8)  # Red
