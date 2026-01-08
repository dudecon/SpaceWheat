class_name QuestBoard
extends Control

## Modal Quest Board with 4 Slots (UIOP)
## Controls hijacked when open (like ESC menu)
## Press C to drill into faction browser

signal quest_accepted(quest: Dictionary)
signal quest_completed(quest_id: int, rewards: Dictionary)
signal quest_abandoned(quest_id: int)
signal board_closed
signal board_opened
signal selection_changed(slot_state: int, is_locked: bool)  # For updating action toolbar

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
var slot_container: GridContainer  # Changed to GridContainer for 2×2 quadrant layout
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


func handle_input(event: InputEvent) -> bool:
	"""Modal input handler - called by PlayerShell when on modal stack

	Returns true if input was consumed, false otherwise.
	"""
	if not visible:
		return false

	if not event is InputEventKey or not event.pressed or event.echo:
		return false

	# If browser is open, it handles input first
	if is_browser_open and faction_browser and faction_browser.visible:
		if faction_browser.has_method("handle_input"):
			return faction_browser.handle_input(event)
		return false

	# Handle quest board actions using keycodes
	print("  🎯 QuestBoard.handle_input() KEY: %s" % event.keycode)
	match event.keycode:
		KEY_ESCAPE:
			close_board()
			return true
		# UIOP keys for direct selection
		KEY_U:
			select_slot(0)
			return true
		KEY_I:
			select_slot(1)
			return true
		KEY_O:
			select_slot(2)
			return true
		KEY_P:
			select_slot(3)
			return true
		# Arrow keys for navigation (2×2 grid layout)
		KEY_UP:
			_navigate_up()
			return true
		KEY_DOWN:
			_navigate_down()
			return true
		KEY_LEFT:
			_navigate_left()
			return true
		KEY_RIGHT:
			_navigate_right()
			return true
		# Action keys
		KEY_Q:
			action_q_on_selected()
			return true
		KEY_E:
			action_e_on_selected()
			return true
		KEY_R:
			action_r_on_selected()
			return true
		KEY_C:
			open_faction_browser()
			return true

	return false  # Input not consumed


func _handle_browser_input(event: InputEvent) -> void:
	"""Handle faction browser controls"""
	if faction_browser and faction_browser.has_method("handle_input"):
		faction_browser.handle_input(event)


func _create_ui() -> void:
	"""Create the quest board UI - 2×2 QUADRANT LAYOUT with auto-scaling"""
	var scale = layout_manager.scale_factor if layout_manager else 1.0

	# Get viewport size for responsive scaling (defensive - fallback if not in tree yet)
	var viewport_size = Vector2(1920, 1080)  # Default fallback
	if is_inside_tree() and get_viewport():
		viewport_size = get_viewport().get_visible_rect().size

	# Scale fonts based on viewport height (more conservative)
	var title_size = int(viewport_size.y * 0.04)  # 4% of screen height
	var large_size = int(viewport_size.y * 0.022)  # 2.2% of screen height
	var normal_size = int(viewport_size.y * 0.018)  # 1.8% of screen height

	# Background - fill screen to block interaction
	background = ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.8)  # Darker for better contrast
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

	# Quest board panel - RESPONSIVE sizing (85% of viewport)
	menu_panel = PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(viewport_size.x * 0.85, viewport_size.y * 0.85)
	center.add_child(menu_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", int(12 * scale))
	menu_panel.add_child(main_vbox)

	# Header - BIG and BOLD
	title_label = Label.new()
	title_label.text = "⚛️ QUEST ORACLE ⚛️"
	title_label.add_theme_font_size_override("font_size", title_size)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title_label)

	# Simplified controls - JUST SELECTION + BROWSE (QER shown in toolbar!)
	controls_label = Label.new()
	controls_label.text = "🎯 [Arrows or UIOP] Select  |  [QER] Actions  |  📚 [C] Browse  |  ✖️ [ESC] Close"
	controls_label.add_theme_font_size_override("font_size", normal_size)
	controls_label.modulate = Color(1.0, 0.9, 0.5)  # Gold/yellow for visibility
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(controls_label)

	# Biome state - SIMPLIFIED, BIG, VISUAL
	biome_state_label = Label.new()
	biome_state_label.text = "🌾 Biome State: Loading..."
	biome_state_label.add_theme_font_size_override("font_size", large_size)
	biome_state_label.modulate = Color(0.5, 1.0, 1.0)  # Cyan - high contrast
	biome_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	biome_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(biome_state_label)

	# Quest slots container - 2×2 GRID LAYOUT!
	slot_container = GridContainer.new()
	slot_container.columns = 2  # TWO COLUMNS = QUADRANT LAYOUT!
	slot_container.add_theme_constant_override("h_separation", int(12 * scale))
	slot_container.add_theme_constant_override("v_separation", int(12 * scale))
	main_vbox.add_child(slot_container)

	# Create 4 quest slots in quadrant pattern:
	# [U] [I]
	# [O] [P]
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
	accessible_factions_label.modulate = Color(0.9, 0.9, 0.5)
	accessible_factions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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

	# Emit board opened signal and initial selection
	board_opened.emit()
	_emit_selection_update()


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
	"""Update biome state display - FLASH GAME STYLE (big, visual, simple)"""
	if not quest_manager or not current_biome:
		return

	var obs = quest_manager.get_biome_observables(current_biome)

	# SIMPLIFIED: Show only the most important stat (purity = order vs chaos)
	# Visual bar representation using block characters
	var purity_pct = int(obs.purity * 100)
	var purity_bar = _make_bar(obs.purity, 10)

	biome_state_label.text = "🌾 Farm State: %s %d%% Order" % [purity_bar, purity_pct]


func _make_bar(value: float, length: int) -> String:
	"""Create a visual bar using block characters"""
	var filled = int(value * length)
	var bar = ""
	for i in range(length):
		if i < filled:
			bar += "█"
		else:
			bar += "░"
	return bar


# =============================================================================
# SAFE GAMESTATE ACCESS (avoids compile warnings)
# =============================================================================

func _get_game_state_manager():
	"""Safely get GameStateManager autoload (avoids static analyzer warnings)"""
	if Engine.is_editor_hint():
		return null
	return get_node_or_null("/root/GameStateManager")


func _get_saved_quest_slots() -> Array:
	"""Safely load quest slots from GameStateManager"""
	var gsm = _get_game_state_manager()
	if gsm and gsm.current_state and gsm.current_state.has("quest_slots"):
		return gsm.current_state.quest_slots
	return []


func _refresh_slots() -> void:
	"""Refresh all quest slots from quest manager and game state"""
	if not quest_manager:
		return

	# Load slot data from GameStateManager (safe access)
	var slot_data = _get_saved_quest_slots()

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

	# Emit selection changed for action toolbar update
	_emit_selection_update()


func _navigate_up() -> void:
	"""Navigate up in 2×2 grid: O→U, P→I"""
	match selected_slot_index:
		2:  # O → U
			select_slot(0)
		3:  # P → I
			select_slot(1)


func _navigate_down() -> void:
	"""Navigate down in 2×2 grid: U→O, I→P"""
	match selected_slot_index:
		0:  # U → O
			select_slot(2)
		1:  # I → P
			select_slot(3)


func _navigate_left() -> void:
	"""Navigate left in 2×2 grid: I→U, P→O"""
	match selected_slot_index:
		1:  # I → U
			select_slot(0)
		3:  # P → O
			select_slot(2)


func _navigate_right() -> void:
	"""Navigate right in 2×2 grid: U→I, O→P"""
	match selected_slot_index:
		0:  # U → I
			select_slot(1)
		2:  # O → P
			select_slot(3)


func _emit_selection_update() -> void:
	"""Emit selection_changed signal with current slot state"""
	if selected_slot_index < 0 or selected_slot_index >= quest_slots.size():
		return

	var slot = quest_slots[selected_slot_index]
	selection_changed.emit(slot.state, slot.is_locked)


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
	"""Save slot state to GameStateManager (safe access)"""
	var gsm = _get_game_state_manager()
	if not gsm or not gsm.current_state:
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

	gsm.current_state.quest_slots = slot_data


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
	# NO action_label - actions shown in QER toolbar at bottom!

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
		"""QUADRANT SLOT - Compact for 2×2 layout"""
		var scale = layout_manager.scale_factor if layout_manager else 1.0

		# Get viewport size for responsive font scaling (defensive)
		var viewport_size = Vector2(1920, 1080)  # Default fallback
		if is_inside_tree() and get_viewport():
			viewport_size = get_viewport().get_visible_rect().size

		# Responsive font sizes (% of viewport height)
		var header_size = int(viewport_size.y * 0.028)  # 2.8% of screen height
		var faction_size = int(viewport_size.y * 0.024)  # 2.4% of screen height
		var normal_size = int(viewport_size.y * 0.018)  # 1.8% of screen height
		var small_size = int(viewport_size.y * 0.015)  # 1.5% of screen height

		# Slot expands to fill grid cell
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(200 * scale, 150 * scale)  # Minimum size

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", int(6 * scale))
		add_child(vbox)

		# Header: [U] 🔒
		header_label = Label.new()
		header_label.add_theme_font_size_override("font_size", header_size)
		vbox.add_child(header_label)

		# Faction emoji and name
		faction_label = Label.new()
		faction_label.add_theme_font_size_override("font_size", faction_size)
		vbox.add_child(faction_label)

		# Quest details
		details_label = Label.new()
		details_label.add_theme_font_size_override("font_size", normal_size)
		details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(details_label)

		# Status (alignment, time, rewards)
		status_label = Label.new()
		status_label.add_theme_font_size_override("font_size", small_size)
		vbox.add_child(status_label)

		# NO action_label - actions shown in QER toolbar!

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
		"""QUADRANT UI - Compact, no action hints (shown in QER toolbar)"""
		# Update header - BOLD KEY + LOCK
		var lock_icon = "🔒" if is_locked else ""
		header_label.text = "[%s] %s" % [slot_letter, lock_icon]

		# Update based on state
		match state:
			SlotState.EMPTY:
				faction_label.text = "⭕ EMPTY"
				details_label.text = ""
				status_label.text = ""
				_set_bg_color(Color(0.15, 0.15, 0.15, 0.9))

			SlotState.OFFERED:
				# FACTION - emoji + name
				faction_label.text = "%s %s" % [
					quest_data.get("faction_emoji", "❓"),
					quest_data.get("faction", "Unknown")
				]

				# QUEST - Just the body
				details_label.text = quest_data.get("body", "")

				# STATUS - Visual bars for alignment + rewards
				var alignment = quest_data.get("_alignment", 0.5)
				var align_bar = _make_bar(alignment, 8)  # Shorter bar for compact layout
				var reward_mult = quest_data.get("reward_multiplier", 2.0)

				var time_limit = quest_data.get("time_limit", -1)
				var time_str = "⏰%ds" % int(time_limit) if time_limit > 0 else "♾️"

				status_label.text = "%s %d%%  |  🎁×%.1f  |  %s" % [
					align_bar,
					int(alignment * 100),
					reward_mult,
					time_str
				]

				_set_bg_color(_get_alignment_color(alignment))

			SlotState.ACTIVE:
				faction_label.text = "%s %s ⚡" % [
					quest_data.get("faction_emoji", "❓"),
					quest_data.get("faction", "Unknown")
				]
				details_label.text = quest_data.get("body", "")

				var time_limit = quest_data.get("time_limit", -1)
				var time_str = "⏰ ???" if time_limit > 0 else "♾️"
				status_label.text = "🔥 ACTIVE  |  %s" % time_str
				_set_bg_color(Color(0.2, 0.3, 0.5, 0.9))

			SlotState.READY:
				faction_label.text = "%s %s ✅" % [
					quest_data.get("faction_emoji", "❓"),
					quest_data.get("faction", "Unknown")
				]
				details_label.text = quest_data.get("body", "")
				status_label.text = "✨ READY! ✨"
				status_label.modulate = Color(0.3, 1.0, 0.3)
				_set_bg_color(Color(0.2, 0.6, 0.2, 0.95))

		# Highlight if selected - THICKER BORDER
		if is_selected:
			var current_style = get_theme_stylebox("panel")
			if current_style:
				current_style.border_width_left = 6  # Thick gold border
				current_style.border_width_right = 6
				current_style.border_width_top = 6
				current_style.border_width_bottom = 6
				current_style.border_color = Color(1.0, 0.9, 0.0)  # Bright gold


	func _make_bar(value: float, length: int) -> String:
		"""Create a visual bar using block characters"""
		var filled = int(value * length)
		var bar = ""
		for i in range(length):
			if i < filled:
				bar += "█"
			else:
				bar += "░"
		return bar

	func _set_bg_color(color: Color) -> void:
		"""FLASH GAME STYLE - Chunky borders, more padding"""
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
		style.content_margin_left = 20  # MORE PADDING!
		style.content_margin_right = 20
		style.content_margin_top = 16
		style.content_margin_bottom = 16
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
