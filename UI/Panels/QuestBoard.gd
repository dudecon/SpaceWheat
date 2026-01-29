class_name QuestBoard
extends "res://UI/Core/OverlayBase.gd"

## Modal Quest Board with 4 Slots (UIOP)
## Controls hijacked when open (like ESC menu)
## Press C to drill into faction browser
##
## Extends OverlayBase for unified overlay infrastructure.
## Uses custom 2x2 grid layout instead of scroll container.

const VocabularyPairing = preload("res://Core/Quests/VocabularyPairing.gd")

# Logging
@onready var _verbose = get_node("/root/VerboseConfig")

signal quest_accepted(quest: Dictionary)
signal quest_completed(quest_id: int, rewards: Dictionary)
signal quest_abandoned(quest_id: int)
signal board_closed
signal board_opened
signal slot_selection_changed(slot_state: int, is_locked: bool)  # For updating action toolbar

# References
var quest_manager: Node
var current_biome: Node

# UI elements (quest-specific)
var slot_container: GridContainer  # 2x2 quadrant layout
var accessible_factions_label: Label

# Quest slots (4 slots: U, I, O, P)
var quest_slots: Array = []  # Array of QuestSlot instances
var selected_slot_index: int = 0

# Quest pool for F-cycling
var all_available_quests: Array = []  # All quests from accessible factions
var quest_pages_memory: Dictionary = {}  # Runtime cache: page_num → [4 slots]
var current_page: int = 0  # Current page (0, 1, 2...) not offset!
const QUESTS_PER_PAGE: int = 4  # Fixed: all slots cycle together

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
	panel_title = "QUEST ORACLE"
	panel_title_size = 24
	panel_border_color = Color(0.5, 0.4, 0.6, 0.8)  # Purple border
	panel_size = Vector2(880, 340)
	use_scroll_container = false  # We use custom grid layout
	overlay_name = "quests"
	overlay_icon = ""
	overlay_tier = 3000
	action_labels = {
		"Q": "Accept/Complete",
		"E": "Lock/Abandon",
		"R": "Reroll",
		"F": "Next Page"
	}


func _build_content(container: Control) -> void:
	"""Build quest board content - 2x2 grid layout."""
	var scale = layout_manager.scale_factor if layout_manager else 1.0

	# Quest slots container - 2x2 GRID LAYOUT!
	slot_container = GridContainer.new()
	slot_container.columns = 2  # TWO COLUMNS = QUADRANT LAYOUT!
	slot_container.add_theme_constant_override("h_separation", int(12 * scale))
	slot_container.add_theme_constant_override("v_separation", int(12 * scale))
	container.add_child(slot_container)

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
	accessible_factions_label.text = "Accessible Factions: 0/68"
	accessible_factions_label.add_theme_font_size_override("font_size", 14)
	accessible_factions_label.modulate = Color(0.9, 0.9, 0.5)
	accessible_factions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(accessible_factions_label)

	# Select first slot by default
	select_slot(0)


func set_quest_manager(manager: Node) -> void:
	quest_manager = manager

	# Connect to quest manager signals (check if not already connected)
	if quest_manager:
		if not quest_manager.quest_completed.is_connected(_on_quest_completed):
			quest_manager.quest_completed.connect(_on_quest_completed)
		if not quest_manager.active_quests_changed.is_connected(_refresh_slots):
			quest_manager.active_quests_changed.connect(_refresh_slots)
		if quest_manager.has_signal("quest_ready_to_claim"):
			if not quest_manager.quest_ready_to_claim.is_connected(_on_quest_ready_to_claim):
				quest_manager.quest_ready_to_claim.connect(_on_quest_ready_to_claim)
		# Auto-reroll quests invalidated by newly learned vocabulary
		if quest_manager.has_signal("vocabulary_learned"):
			if not quest_manager.vocabulary_learned.is_connected(_on_vocabulary_learned):
				quest_manager.vocabulary_learned.connect(_on_vocabulary_learned)


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
		# Arrow keys for navigation (2x2 grid layout)
		KEY_UP, KEY_W:
			_navigate_up()
			return true
		KEY_DOWN, KEY_S:
			_navigate_down()
			return true
		KEY_LEFT, KEY_A:
			_navigate_left()
			return true
		KEY_RIGHT, KEY_D:
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
		KEY_F:
			on_f_pressed()
			return true

	return false  # Input not consumed


func _handle_browser_input(event: InputEvent) -> void:
	"""Handle faction browser controls"""
	if faction_browser and faction_browser.has_method("handle_input"):
		faction_browser.handle_input(event)


func open_board() -> void:
	"""Open the quest board"""
	if not quest_manager or not current_biome:
		push_error("QuestBoard: quest_manager or current_biome not set")
		return

	# Restore from GameState
	var gsm = _get_game_state_manager()
	if gsm and gsm.current_state:
		# Migrate old quest_slots format to new quest_pages format (only if has actual quests)
		if "quest_slots" in gsm.current_state and gsm.current_state.quest_slots.size() == 4:
			if not ("quest_pages" in gsm.current_state) or gsm.current_state.quest_pages.is_empty():
				# Check if old slots have any actual quests (not all null)
				var has_quests = false
				for slot_data in gsm.current_state.quest_slots:
					if slot_data != null:
						has_quests = true
						break

				# Only migrate if there were actual quests saved
				if has_quests:
					gsm.current_state.quest_pages = {0: gsm.current_state.quest_slots.duplicate(true)}
					gsm.current_state.quest_board_current_page = 0

		# Restore page memory
		if "quest_pages" in gsm.current_state and not gsm.current_state.quest_pages.is_empty():
			quest_pages_memory = gsm.current_state.quest_pages.duplicate(true)

		# Restore current page
		if "quest_board_current_page" in gsm.current_state:
			current_page = gsm.current_state.quest_board_current_page
		else:
			current_page = 0

	visible = true
	is_active = true
	_refresh_biome_state()
	_refresh_slots()
	_update_accessible_count()

	# Emit board opened signal and initial selection
	board_opened.emit()
	overlay_opened.emit()
	_emit_selection_update()


func close_board() -> void:
	"""Close the quest board"""
	# Save current page before closing
	_save_current_page()

	visible = false
	is_active = false
	is_browser_open = false
	if faction_browser:
		faction_browser.visible = false
	board_closed.emit()
	overlay_closed.emit()


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
	"""Biome state is now visible via resource bar - no separate display needed"""
	pass


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
	if gsm and gsm.current_state and "quest_slots" in gsm.current_state:
		return gsm.current_state.quest_slots
	return []


func _save_current_page() -> void:
	"""Capture current slot configuration to page memory."""
	var page_slots = []
	for slot in quest_slots:
		if slot.state == SlotState.EMPTY:
			page_slots.append(null)
		else:
			page_slots.append({
				"quest_id": slot.quest_data.get("id", -1),
				"offered_quest": slot.quest_data.duplicate(true),
				"faction": slot.quest_data.get("faction", ""),
				"is_locked": slot.is_locked,
				"state": slot.state
			})

	# Save to runtime cache
	quest_pages_memory[current_page] = page_slots

	# Persist to GameState
	var gsm = _get_game_state_manager()
	if gsm and gsm.current_state:
		gsm.current_state.quest_pages = quest_pages_memory.duplicate(true)
		gsm.current_state.quest_board_current_page = current_page


func _load_page(page_num: int) -> bool:
	"""Load a page from memory and display it. Returns true if found."""
	# Check runtime cache first
	if quest_pages_memory.has(page_num):
		var page_slots = quest_pages_memory[page_num]
		_display_page_slots(page_slots)
		current_page = page_num
		return true

	# Check GameState (for session restore)
	var gsm = _get_game_state_manager()
	if gsm and gsm.current_state and "quest_pages" in gsm.current_state:
		if gsm.current_state.quest_pages.has(page_num):
			var page_slots = gsm.current_state.quest_pages[page_num]
			quest_pages_memory[page_num] = page_slots  # Cache it
			_display_page_slots(page_slots)
			current_page = page_num
			return true

	# Page not in memory
	return false


func _display_page_slots(page_slots: Array) -> void:
	"""Set quest slots to match saved page configuration."""
	for i in range(min(4, page_slots.size())):
		var slot = quest_slots[i]
		var slot_data = page_slots[i]

		if slot_data == null:
			slot.set_empty()
		else:
			var quest_state = slot_data.get("state", SlotState.OFFERED)
			var quest_data = slot_data.get("offered_quest", {})
			var is_locked = slot_data.get("is_locked", false)

			match quest_state:
				SlotState.OFFERED:
					slot.set_quest_offered(quest_data, is_locked)
				SlotState.ACTIVE:
					slot.set_quest_active(quest_data)
				SlotState.READY:
					slot.state = SlotState.READY
					slot.quest_data = quest_data
					slot._refresh_ui()
				_:
					slot.set_empty()


func _generate_and_display_page(page_num: int) -> void:
	"""Generate a new page of quests from pool.

	Loads 4 quests from pool starting at (page_num * 4).
	- Checks if each quest is in active_quests (show as ACTIVE)
	- Lock state only prevents reroll, doesn't affect page loading
	"""
	var start_index = page_num * QUESTS_PER_PAGE
	var end_index = min(start_index + QUESTS_PER_PAGE, all_available_quests.size())

	for i in range(4):
		var slot = quest_slots[i]
		var pool_index = start_index + i

		# Load quest from pool for this slot position
		if pool_index < end_index:
			var quest = all_available_quests[pool_index]
			var quest_id = quest.get("id", -1)

			# Check if this quest is already active
			if quest_manager and quest_manager.active_quests.has(quest_id):
				# Quest is already accepted - show as ACTIVE
				slot.set_quest_active(quest)
			else:
				# Quest is offered - preserve lock state if it was already locked
				var was_locked = (slot.quest_data.get("id", -1) == quest_id and slot.is_locked)
				slot.set_quest_offered(quest, was_locked)
		else:
			slot.set_empty()

	current_page = page_num
	# Save this newly generated page
	_save_current_page()


func _calculate_total_pages() -> int:
	"""Calculate total pages from quest pool."""
	if all_available_quests.is_empty():
		return 1
	return int(ceil(float(all_available_quests.size()) / QUESTS_PER_PAGE))


func _regenerate_all_pages() -> void:
	"""Clear page memory and regenerate from updated quest pool.

	Called when quest pool changes (accept, complete, etc).
	Clears all cached pages and regenerates current page from pool.
	"""
	print("\n🟢 DEBUG: _regenerate_all_pages() CALLED")
	var pool_ids = all_available_quests.map(func(q): return q.get("id", -1)) if all_available_quests else []
	print("   Current pool IDs: %s" % pool_ids)

	# Clear runtime page memory (force regeneration)
	quest_pages_memory.clear()

	# Clear GameState page memory
	var gsm = _get_game_state_manager()
	if gsm and gsm.current_state:
		gsm.current_state.quest_pages = {}

	# Regenerate current page from pool
	_generate_and_display_page(current_page)
	print("🟢 DEBUG: _regenerate_all_pages() END\n")


func _refresh_slots() -> void:
	"""Refresh quest slots - load current page or generate.

	NEW BEHAVIOR:
	- No pinning logic (all slots cycle together)
	- Load page from memory if available
	- Generate new page if not in memory
	"""
	print("\n🟠 DEBUG: _refresh_slots() CALLED")
	var old_pool_size = all_available_quests.size() if all_available_quests else 0
	var old_ids = all_available_quests.map(func(q): return q.get("id", -1)) if all_available_quests else []
	print("   Current pool size: %d, IDs: %s" % [old_pool_size, old_ids])
	print("   Calling offer_all_faction_quests...")

	if not quest_manager or not current_biome:
		return

	# Build quest pool
	all_available_quests = quest_manager.offer_all_faction_quests(current_biome)
	var new_ids = all_available_quests.map(func(q): return q.get("id", -1))
	print("   NEW pool size: %d, IDs: %s" % [all_available_quests.size(), new_ids])

	# Try to load current page
	if _load_page(current_page):
		# Loaded from memory
		pass
	else:
		# First time viewing, generate
		_generate_and_display_page(current_page)

	_update_slot_selection()
	_update_page_display()


func _update_accessible_count() -> void:
	"""Update accessible factions count"""
	if not quest_manager or not current_biome:
		return

	var all_quests = quest_manager.offer_all_faction_quests(current_biome)
	accessible_factions_label.text = "%d/68 factions accessible (learn more emojis!)" % all_quests.size()


func _update_page_display() -> void:
	"""Update page indicator label."""
	var total_pages = _calculate_total_pages()
	var total_quests = all_available_quests.size()
	var visited_pages = quest_pages_memory.size()

	accessible_factions_label.text = "Page %d/%d  |  %d quests  |  %d visited  |  [F] Next" % [
		current_page + 1,  # 1-indexed for display
		total_pages,
		total_quests,
		visited_pages
	]


func get_selected_quest() -> Dictionary:
	"""Return a snapshot of the currently selected quest, if any."""
	if selected_slot_index < 0 or selected_slot_index >= quest_slots.size():
		return {}

	var slot = quest_slots[selected_slot_index]
	if slot.quest_data.is_empty():
		return {}

	var snapshot = slot.quest_data.duplicate(true)
	snapshot["slot_index"] = selected_slot_index
	snapshot["slot_state"] = slot.state
	snapshot["slot_locked"] = slot.is_locked
	return snapshot


func select_slot(index: int) -> void:
	"""Select a quest slot"""
	if index < 0 or index >= quest_slots.size():
		return

	selected_slot_index = index
	_update_slot_selection()

	# Emit selection changed for action toolbar update
	_emit_selection_update()


func _navigate_up() -> void:
	"""Navigate up in 2x2 grid: O->U, P->I"""
	match selected_slot_index:
		2:  # O -> U
			select_slot(0)
		3:  # P -> I
			select_slot(1)


func _navigate_down() -> void:
	"""Navigate down in 2x2 grid: U->O, I->P"""
	match selected_slot_index:
		0:  # U -> O
			select_slot(2)
		1:  # I -> P
			select_slot(3)


func _navigate_left() -> void:
	"""Navigate left in 2x2 grid: I->U, P->O"""
	match selected_slot_index:
		1:  # I -> U
			select_slot(0)
		3:  # P -> O
			select_slot(2)


func _navigate_right() -> void:
	"""Navigate right in 2x2 grid: U->I, O->P"""
	match selected_slot_index:
		0:  # U -> I
			select_slot(1)
		2:  # O -> P
			select_slot(3)


func _emit_selection_update() -> void:
	"""Emit selection_changed signal with current slot state"""
	if selected_slot_index < 0 or selected_slot_index >= quest_slots.size():
		return

	var slot = quest_slots[selected_slot_index]
	slot_selection_changed.emit(slot.state, slot.is_locked)


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
	"""Q action: Accept, Deliver, or Claim"""
	var info = get_action_info("Q")
	if info.is_empty() or info.get("disabled", false):
		return
		
	var slot = quest_slots[selected_slot_index]
	match info.action:
		"quest_accept": _accept_quest(slot)
		"quest_claim": _claim_quest(slot)
		"quest_deliver": _deliver_quest(slot)


func action_e_on_selected() -> void:
	"""E action dispatch from manifest"""
	var info = get_action_info("E")
	if info.is_empty() or info.get("disabled", false):
		return

	var slot = quest_slots[selected_slot_index]
	match info.action:
		"quest_lock":
			var was_locked = slot.is_locked
			if not was_locked:
				if quest_manager and quest_manager.economy:
					if not EconomyConstants.try_action("quest_lock", quest_manager.economy):
						_verbose.warn("quest", "🌲", "Cannot lock: Need 1 🌲 tree.")
						return
			
			slot.toggle_lock()
			_save_current_page()
			_emit_selection_update()
		"quest_abandon":
			_abandon_quest(slot)
		"quest_reject":
			_reject_quest(slot)


func action_r_on_selected() -> void:
	"""R action dispatch from manifest"""
	var info = get_action_info("R")
	if info.is_empty() or info.get("disabled", false):
		return

	var slot = quest_slots[selected_slot_index]
	match info.action:
		"quest_generate", "quest_reroll":
			_reroll_quest(slot)
			_save_current_page()
			_emit_selection_update()


func _accept_quest(slot) -> void:
	"""Accept an offered quest"""
	if not quest_manager:
		return

	var quest_data_copy = slot.quest_data.duplicate(true)
	var quest_id = quest_data_copy.get("id", -1)

	# Check if already active
	if quest_manager.active_quests.has(quest_id):
		# Quest is already accepted, just ensure visual state is correct
		slot.set_quest_active(quest_data_copy)
		return

	# CRITICAL: Disconnect _refresh_slots temporarily to prevent rerolling other slots
	# when accept_quest emits active_quests_changed
	var was_connected = false
	if quest_manager.active_quests_changed.is_connected(_refresh_slots):
		quest_manager.active_quests_changed.disconnect(_refresh_slots)
		was_connected = true

	# Save quest data and set slot to ACTIVE
	slot.set_quest_active(quest_data_copy)

	var success = quest_manager.accept_quest(quest_data_copy)

	# Reconnect signal
	if was_connected:
		quest_manager.active_quests_changed.connect(_refresh_slots)

	if success:
		quest_accepted.emit(quest_data_copy)

		# Bubble sort - move accepted quest to top of pool
		var quest_index = -1

		# Find quest in pool
		for i in range(all_available_quests.size()):
			if all_available_quests[i].get("id") == quest_id:
				quest_index = i
				break

		# Move to front of pool
		if quest_index >= 0:
			var quest_to_move = all_available_quests[quest_index]
			all_available_quests.remove_at(quest_index)
			all_available_quests.insert(0, quest_to_move)

			# Regenerate all pages with new ordering
			_regenerate_all_pages()

		_emit_selection_update()
	else:
		# Revert slot state if accept failed
		slot.set_quest_offered(quest_data_copy, slot.is_locked)


func _deliver_quest(slot) -> void:
	"""Deliver a DELIVERY quest - deducts resources and grants rewards"""
	print("\n🔵 DEBUG: _deliver_quest() START")
	var before_pool_ids = all_available_quests.map(func(q): return q.get("id", -1)) if all_available_quests else []
	var before_active = quest_manager.active_quests.keys() if quest_manager.active_quests else []
	print("   BEFORE: Pool=%s, Active=%s" % [before_pool_ids, before_active])

	if not quest_manager:
		return

	var quest_id = slot.quest_data.get("id", -1)
	if quest_id < 0:
		return

	print("   Completing quest_id=%d" % quest_id)

	# Disconnect _refresh_slots to prevent pool rebuild that would change quest IDs
	var was_connected = false
	if quest_manager.active_quests_changed.is_connected(_refresh_slots):
		print("   Disconnecting _refresh_slots signal")
		quest_manager.active_quests_changed.disconnect(_refresh_slots)
		was_connected = true

	var success = quest_manager.complete_quest(quest_id)
	print("   complete_quest() returned: %s" % success)

	# Reconnect signal
	if was_connected:
		print("   Reconnecting _refresh_slots signal")
		quest_manager.active_quests_changed.connect(_refresh_slots)

	if success:
		var after_complete_pool = all_available_quests.map(func(q): return q.get("id", -1)) if all_available_quests else []
		print("   AFTER complete: Pool=%s" % after_complete_pool)

		# Remove completed quest from pool (preserve active quest IDs)
		for i in range(all_available_quests.size()):
			if all_available_quests[i].get("id") == quest_id:
				all_available_quests.remove_at(i)
				break

		var after_remove_pool = all_available_quests.map(func(q): return q.get("id", -1)) if all_available_quests else []
		print("   AFTER remove: Pool=%s" % after_remove_pool)

		# Regenerate pages from existing pool
		_regenerate_all_pages()
		_emit_selection_update()

	var after_pool_ids = all_available_quests.map(func(q): return q.get("id", -1)) if all_available_quests else []
	var after_active = quest_manager.active_quests.keys() if quest_manager.active_quests else []
	print("   FINAL: Pool=%s, Active=%s" % [after_pool_ids, after_active])
	print("🔵 DEBUG: _deliver_quest() END\n")


func _claim_quest(slot) -> void:
	"""Claim rewards for a READY non-DELIVERY quest"""
	if not quest_manager:
		return

	var quest_id = slot.quest_data.get("id", -1)
	if quest_id < 0:
		return

	# Disconnect _refresh_slots to prevent pool rebuild that would change quest IDs
	var was_connected = false
	if quest_manager.active_quests_changed.is_connected(_refresh_slots):
		quest_manager.active_quests_changed.disconnect(_refresh_slots)
		was_connected = true

	var success = quest_manager.claim_quest(quest_id)

	# Reconnect signal
	if was_connected:
		quest_manager.active_quests_changed.connect(_refresh_slots)

	if success:
		# Remove completed quest from pool (preserve active quest IDs)
		for i in range(all_available_quests.size()):
			if all_available_quests[i].get("id") == quest_id:
				all_available_quests.remove_at(i)
				break

		# Regenerate pages from existing pool
		_regenerate_all_pages()
		_emit_selection_update()


func _reject_quest(slot) -> void:
	"""Reject a READY non-DELIVERY quest without claiming rewards"""
	if not quest_manager:
		return

	var quest_id = slot.quest_data.get("id", -1)
	if quest_id < 0:
		return

	# Disconnect _refresh_slots to prevent pool rebuild that would change quest IDs
	var was_connected = false
	if quest_manager.active_quests_changed.is_connected(_refresh_slots):
		quest_manager.active_quests_changed.disconnect(_refresh_slots)
		was_connected = true

	quest_manager.reject_quest(quest_id)
	quest_abandoned.emit(quest_id)

	# Reconnect signal
	if was_connected:
		quest_manager.active_quests_changed.connect(_refresh_slots)

	# Remove from pool and regenerate pages (preserves active quest IDs)
	for i in range(all_available_quests.size()):
		if all_available_quests[i].get("id") == quest_id:
			all_available_quests.remove_at(i)
			break

	_regenerate_all_pages()


func _abandon_quest(slot) -> void:
	"""Abandon an active quest"""
	if not quest_manager:
		return

	var quest_id = slot.quest_data.get("id", -1)
	if quest_id < 0:
		return

	# Disconnect _refresh_slots to prevent pool rebuild that would change quest IDs
	var was_connected = false
	if quest_manager.active_quests_changed.is_connected(_refresh_slots):
		quest_manager.active_quests_changed.disconnect(_refresh_slots)
		was_connected = true

	quest_manager.fail_quest(quest_id, "player_abandoned")
	quest_abandoned.emit(quest_id)

	# Reconnect signal
	if was_connected:
		quest_manager.active_quests_changed.connect(_refresh_slots)

	# Remove from pool and regenerate pages (preserves active quest IDs)
	for i in range(all_available_quests.size()):
		if all_available_quests[i].get("id") == quest_id:
			all_available_quests.remove_at(i)
			break

	_regenerate_all_pages()


func _reroll_quest(slot) -> void:
	"""Reroll quest in slot (get random different faction) - Costs 1 rabbit 🐇"""
	if not quest_manager or not current_biome or not quest_manager.economy:
		return

	# Deduct 1 rabbit
	if not EconomyConstants.try_action("quest_reroll", quest_manager.economy):
		_verbose.warn("quest", "🐇", "Cannot reroll: Need 1 🐇 rabbit.")
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
		return

	# Pick random
	var new_quest = available[randi() % available.size()]
	slot.set_quest_offered(new_quest, slot.is_locked)


func _check_can_complete(slot) -> bool:
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
	_save_current_page()
	close_faction_browser()


func _on_quest_completed(quest_id: int, rewards: Dictionary) -> void:
	"""Handle quest completed signal from manager"""
	# Remove from pool and regenerate pages (preserves active quest IDs)
	for i in range(all_available_quests.size()):
		if all_available_quests[i].get("id") == quest_id:
			all_available_quests.remove_at(i)
			break

	_regenerate_all_pages()
	quest_completed.emit(quest_id, rewards)


func _on_quest_ready_to_claim(quest_id: int) -> void:
	"""Handle quest ready to claim signal from manager (non-DELIVERY quest conditions met)"""
	# Find slot with this quest and update to READY state
	for i in range(4):
		var slot = quest_slots[i]
		if slot.quest_data.get("id", -1) == quest_id:
			slot.state = SlotState.READY
			slot._refresh_ui()
			# Update action labels if this slot is selected
			if i == selected_slot_index:
				_emit_selection_update()
			break


func _on_vocabulary_learned(emoji: String, faction: String) -> void:
	"""Handle vocabulary invalidation across all quest states.

	When a quest's north pole vocabulary is learned:
	- OFFERED unlocked → Auto-reroll with fresh quest
	- ACTIVE → Downgrade to LOCKED (preserve, let player see it's invalid)
	- LOCKED → Stay LOCKED (already protected, show it's invalid)

	This gives the player visibility and manual control.

	CRITICAL: Do NOT rebuild quest pool here! That would destroy quest IDs and break
	active_quests matching. Only check the current slots against existing pool.
	"""
	print("\n🟣 DEBUG: _on_vocabulary_learned() CALLED - emoji=%s, faction=%s" % [emoji, faction])
	var before_pool_ids = all_available_quests.map(func(q): return q.get("id", -1)) if all_available_quests else []
	print("   Before: Pool IDs=%s" % before_pool_ids)

	var tree = Engine.get_main_loop()
	var verbose = tree.root.get_node_or_null("/root/VerboseConfig") if tree and tree is SceneTree else null

	if verbose:
		verbose.debug("quest", "📚", "Vocabulary learned: %s (%s)" % [emoji, faction])

	if not quest_manager or not current_biome:
		if verbose:
			verbose.debug("quest", "⚠️", "Cannot check for vocab invalidation: quest_manager or current_biome not set")
		return

	var reroll_count = 0
	var downgrade_count = 0

	# Check ALL slots for vocabulary invalidation
	for i in range(4):
		var slot = quest_slots[i]

		# Skip empty slots
		if slot.state == SlotState.EMPTY:
			continue

		# Check if this quest is invalidated
		if not _is_quest_invalidated(slot.quest_data):
			continue

		var quest_id = slot.quest_data.get("id", -1)

		match slot.state:
			SlotState.OFFERED:
				if not slot.is_locked:
					# OFFERED unlocked → Auto-reroll
					if verbose:
						verbose.debug("quest", "🔄", "Auto-rerolling quest %d (offers already-known vocab)" % quest_id)
					_reroll_quest(slot)
					reroll_count += 1
				# else: OFFERED locked - let it stay (user protecting it)

			SlotState.ACTIVE:
				# ACTIVE → Downgrade to LOCKED (preserve for player to handle)
				if verbose:
					verbose.warn("quest", "⚠️", "Downgrading quest %d from ACTIVE to LOCKED (vocab invalidated)" % quest_id)
				slot.set_quest_offered(slot.quest_data, true)  # Convert to locked offer
				slot.state = SlotState.OFFERED
				slot.is_locked = true
				slot._refresh_ui()
				downgrade_count += 1

			SlotState.LOCKED:
				# LOCKED → Stay locked (but now clearly marked as invalid)
				if verbose:
					verbose.debug("quest", "🔒", "Quest %d invalidated but stays LOCKED (user protected)" % quest_id)
				# Refresh to show it's invalid (visual indicator via locked state)
				slot._refresh_ui()

	if reroll_count > 0 or downgrade_count > 0:
		if verbose:
			verbose.info("quest", "✅", "Vocabulary invalidation: %d auto-rerolled, %d downgraded to locked" % [reroll_count, downgrade_count])
		# Save page after changes
		_save_current_page()
	elif verbose:
		verbose.debug("quest", "ℹ️", "No quests invalidated by vocabulary learning")

	var after_pool_ids = all_available_quests.map(func(q): return q.get("id", -1)) if all_available_quests else []
	print("   After: Pool IDs=%s (rerolled=%d, downgraded=%d)" % [after_pool_ids, reroll_count, downgrade_count])
	print("🟣 DEBUG: _on_vocabulary_learned() END\n")


func _is_quest_invalidated(quest_data: Dictionary) -> bool:
	"""Check if a quest's vocabulary rewards are now known.

	Only the NORTH pole needs to be new. SOUTH pole can be known.
	"""
	if not quest_manager:
		return false

	# Get player's known vocabulary
	var known_emojis = []
	var gsm = get_tree().root.get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state:
		known_emojis = gsm.current_state.get_known_emojis()

	if known_emojis.is_empty():
		return false

	# Check vocabulary rewards stored in quest data
	# Only NORTH pole needs to be new - SOUTH can be known
	var north = quest_data.get("reward_vocab_north", "")

	if north != "" and north in known_emojis:
		var tree = Engine.get_main_loop()
		var verbose = tree.root.get_node_or_null("/root/VerboseConfig") if tree and tree is SceneTree else null
		if verbose:
			verbose.debug("quest", "📚", "Quest invalidated: %s already known (north pole)" % north)
		return true

	return false


# =============================================================================
# V2 OVERLAY INTERFACE OVERRIDES
# =============================================================================

func activate() -> void:
	"""v2 overlay lifecycle: Called when overlay opens."""
	open_board()


func deactivate() -> void:
	"""v2 overlay lifecycle: Called when overlay closes."""
	close_board()


func on_q_pressed() -> void:
	"""v2 overlay action: Q key handler."""
	action_q_on_selected()
	action_performed.emit("quest_action_q", {"slot": selected_slot_index})


func on_e_pressed() -> void:
	"""v2 overlay action: E key handler."""
	action_e_on_selected()
	action_performed.emit("quest_action_e", {"slot": selected_slot_index})


func on_r_pressed() -> void:
	"""v2 overlay action: R key handler."""
	action_r_on_selected()
	action_performed.emit("quest_action_r", {"slot": selected_slot_index})


func on_f_pressed() -> void:
	"""F key cycles to next page (all 4 slots).

	NEW BEHAVIOR:
	- Saves current page
	- Advances to next page
	- Loads from memory OR generates new page
	- Wraps to page 0 at end
	"""
	# Save current page before leaving
	_save_current_page()

	# Calculate total pages
	var total_pages = _calculate_total_pages()

	# Advance to next page (wrap around)
	current_page = (current_page + 1) % max(1, total_pages)

	# Try to load from memory
	if not _load_page(current_page):
		# Generate new page
		_generate_and_display_page(current_page)

	# Update UI
	_update_slot_selection()
	_update_page_display()

	# Emit signal
	action_performed.emit("quest_next_page", {"page": current_page})


func get_action_info(key: String) -> Dictionary:
	"""Return metadata for a given key based on quest state"""
	if selected_slot_index < 0 or selected_slot_index >= quest_slots.size():
		return {}

	var slot = quest_slots[selected_slot_index]
	var quest_type = slot.quest_data.get("type", 0)

	match key:
		"Q":
			match slot.state:
				SlotState.OFFERED:
					return {"action": "quest_accept", "label": "Accept", "emoji": "✅"}
				SlotState.ACTIVE:
					if quest_type == 0:
						return {"action": "quest_deliver", "label": "Deliver", "emoji": "📦"}
					return {"action": "quest_tracking", "label": "Tracking", "emoji": "📡", "disabled": true}
				SlotState.READY:
					if quest_type == 0:
						return {"action": "quest_deliver", "label": "Deliver", "emoji": "📦"}
					return {"action": "quest_claim", "label": "Claim", "emoji": "🎁"}
		"E":
			match slot.state:
				SlotState.OFFERED:
					return {"action": "quest_lock", "label": "Unlock" if slot.is_locked else "Lock", "emoji": "🔓" if slot.is_locked else "🔒"}
				SlotState.ACTIVE, SlotState.READY:
					if quest_type != 0 and slot.state == SlotState.READY:
						return {"action": "quest_reject", "label": "Reject", "emoji": "❌"}
					return {"action": "quest_abandon", "label": "Abandon", "emoji": "🗑️"}
		"R":
			match slot.state:
				SlotState.EMPTY:
					return {"action": "quest_generate", "label": "Generate", "emoji": "✨"}
				SlotState.OFFERED:
					if slot.is_locked:
						return {"action": "quest_reroll", "label": "Reroll", "emoji": "🔄", "disabled": true}
					return {"action": "quest_reroll", "label": "Reroll", "emoji": "🔄"}
		"F":
			return {"action": "quest_next_page", "label": "Next Page", "emoji": "📖"}
			
	return {}


func get_action_labels() -> Dictionary:
	"""v2 overlay interface: Get current labels from action info."""
	var labels = {}
	for key in ["Q", "E", "R", "F"]:
		var info = get_action_info(key)
		labels[key] = info.get("label", "-")
	return labels


# =============================================================================
# QUEST SLOT COMPONENT
# =============================================================================

class QuestSlot extends PanelContainer:
	"""Individual quest slot display - Two column layout

	Layout:
	|---------------------------------------|
	| [U] Lock  Faction Name        Mood    |
	|---------------+------------------------|
	|   Deliver     |        North           |
	|    Emoji x 5  |       --------         |
	|               |        South           |
	|---------------+------------------------|
	| Signature             Alignment        |
	|---------------------------------------|
	"""

	signal slot_selected(slot_index: int)

	var layout_manager: Node
	var slot_letter: String = "U"
	var slot_index: int = 0
	var state: int = QuestBoard.SlotState.EMPTY
	var quest_data: Dictionary = {}
	var is_locked: bool = false
	var is_selected: bool = false

	# UI elements - Header row
	var slot_label: Label        # [U] Lock
	var faction_label: Label     # Faction name
	var status_label: Label      # Mood

	# UI elements - Left column (requirement)
	var action_type_label: Label   # "Deliver" or "Reach" etc.
	var requirement_label: Label   # "Emoji x 5" or "purity >= 70%"

	# UI elements - Right column (reward)
	var north_label: Label       # North emoji (BIG)
	var separator_label: Label   # --------
	var south_label: Label       # South emoji (BIG)

	# UI elements - Bottom bar (faction info)
	var signature_label: Label      # Faction signature emojis
	var alignment_bar_label: Label  # Mood + bar

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
		"""Two-column layout: requirement on left, reward on right"""
		var scale = layout_manager.scale_factor if layout_manager else 1.0

		# Font sizes
		var header_size = 13
		var action_size = 12
		var requirement_size = 16
		var emoji_size = 28  # BIG emojis for reward

		# Slot expands to fill grid cell
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(200 * scale, 95 * scale)

		var main_vbox = VBoxContainer.new()
		main_vbox.add_theme_constant_override("separation", int(2 * scale))
		add_child(main_vbox)

		# === HEADER ROW ===
		var header_hbox = HBoxContainer.new()
		header_hbox.add_theme_constant_override("separation", int(4 * scale))
		main_vbox.add_child(header_hbox)

		# Slot key + lock
		slot_label = Label.new()
		slot_label.add_theme_font_size_override("font_size", header_size)
		header_hbox.add_child(slot_label)

		# Faction name (expands)
		faction_label = Label.new()
		faction_label.add_theme_font_size_override("font_size", header_size)
		faction_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		faction_label.clip_text = true
		header_hbox.add_child(faction_label)

		# Status (mood + time)
		status_label = Label.new()
		status_label.add_theme_font_size_override("font_size", header_size)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header_hbox.add_child(status_label)

		# === CONTENT ROW (two columns) ===
		var content_hbox = HBoxContainer.new()
		content_hbox.add_theme_constant_override("separation", int(8 * scale))
		content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		main_vbox.add_child(content_hbox)

		# --- LEFT COLUMN: Requirement ---
		var left_vbox = VBoxContainer.new()
		left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		content_hbox.add_child(left_vbox)

		# Action type
		action_type_label = Label.new()
		action_type_label.add_theme_font_size_override("font_size", action_size)
		action_type_label.modulate = Color(0.7, 0.7, 0.7)
		action_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left_vbox.add_child(action_type_label)

		# Requirement (bigger, centered)
		requirement_label = Label.new()
		requirement_label.add_theme_font_size_override("font_size", requirement_size)
		requirement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left_vbox.add_child(requirement_label)

		# --- VERTICAL SEPARATOR ---
		var vsep = VSeparator.new()
		vsep.modulate = Color(0.5, 0.5, 0.5, 0.5)
		content_hbox.add_child(vsep)

		# --- RIGHT COLUMN: Reward (N/S pair) ---
		var right_vbox = VBoxContainer.new()
		right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		right_vbox.add_theme_constant_override("separation", 0)
		content_hbox.add_child(right_vbox)

		# North emoji (BIG)
		north_label = Label.new()
		north_label.add_theme_font_size_override("font_size", emoji_size)
		north_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right_vbox.add_child(north_label)

		# Separator line
		separator_label = Label.new()
		separator_label.add_theme_font_size_override("font_size", 10)
		separator_label.text = "--------"
		separator_label.modulate = Color(0.6, 0.6, 0.6)
		separator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right_vbox.add_child(separator_label)

		# South emoji (BIG)
		south_label = Label.new()
		south_label.add_theme_font_size_override("font_size", emoji_size)
		south_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right_vbox.add_child(south_label)

		# === BOTTOM BAR (faction signature + alignment) ===
		var bottom_hbox = HBoxContainer.new()
		bottom_hbox.add_theme_constant_override("separation", int(4 * scale))
		main_vbox.add_child(bottom_hbox)

		# Faction signature emojis (left)
		signature_label = Label.new()
		signature_label.add_theme_font_size_override("font_size", 11)
		signature_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		signature_label.modulate = Color(0.7, 0.7, 0.7)
		bottom_hbox.add_child(signature_label)

		# Alignment bar (right)
		alignment_bar_label = Label.new()
		alignment_bar_label.add_theme_font_size_override("font_size", 11)
		alignment_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bottom_hbox.add_child(alignment_bar_label)

		_refresh_ui()

	func set_empty() -> void:
		state = QuestBoard.SlotState.EMPTY
		quest_data = {}
		is_locked = false
		_refresh_ui()

	func set_quest_offered(quest: Dictionary, locked: bool) -> void:
		state = QuestBoard.SlotState.OFFERED
		quest_data = quest
		is_locked = locked
		_refresh_ui()

	func set_quest_active(quest: Dictionary) -> void:
		state = QuestBoard.SlotState.ACTIVE
		quest_data = quest
		_refresh_ui()

	func toggle_lock() -> void:
		is_locked = !is_locked
		_refresh_ui()

	func set_selected(selected: bool) -> void:
		is_selected = selected
		_refresh_ui()

	func _refresh_ui() -> void:
		"""Update all UI elements based on state"""
		# Header: slot key + lock
		var lock_icon = "Lock" if is_locked else ""
		slot_label.text = "[%s]%s" % [slot_letter, lock_icon]

		match state:
			QuestBoard.SlotState.EMPTY:
				_refresh_empty_ui()
			QuestBoard.SlotState.OFFERED:
				_refresh_offered_ui()
			QuestBoard.SlotState.ACTIVE:
				_refresh_active_ui()
			QuestBoard.SlotState.READY:
				_refresh_ready_ui()

		# Selection highlight
		if is_selected:
			var current_style = get_theme_stylebox("panel")
			if current_style:
				current_style.border_width_left = 5
				current_style.border_width_right = 5
				current_style.border_width_top = 5
				current_style.border_width_bottom = 5
				current_style.border_color = Color(1.0, 0.9, 0.0)

	func _refresh_empty_ui() -> void:
		"""Empty slot display"""
		faction_label.text = "Empty"
		status_label.text = ""

		action_type_label.text = "Press [F]"
		requirement_label.text = "for quests"

		north_label.text = "?"
		separator_label.visible = false
		south_label.text = ""

		# Bottom bar - empty
		signature_label.text = ""
		alignment_bar_label.text = ""

		_set_bg_color(Color(0.15, 0.15, 0.15, 0.9))

	func _refresh_offered_ui() -> void:
		"""Offered quest display"""
		# Header - just faction name, no mood (moved to bottom bar)
		faction_label.text = quest_data.get("faction", "Unknown")
		status_label.text = ""  # Mood moved to bottom bar

		# Left: Requirement
		var quest_type = quest_data.get("type", 0)
		_set_requirement_display(quest_type)

		# Right: Vocab pair reward
		_set_reward_display()

		# Bottom bar: signature + alignment
		var alignment = quest_data.get("_alignment", 0.5)
		_set_bottom_bar(alignment)

		_set_bg_color(_get_alignment_color(alignment))

	func _refresh_active_ui() -> void:
		"""Active quest display"""
		# Header with active indicator
		faction_label.text = "* %s" % quest_data.get("faction", "Unknown")
		status_label.text = "Active"

		# Left: Requirement
		var quest_type = quest_data.get("type", 0)
		_set_requirement_display(quest_type)

		# Right: Vocab pair reward
		_set_reward_display()

		# Bottom bar: signature + alignment
		var alignment = quest_data.get("_alignment", 0.5)
		_set_bottom_bar(alignment)

		_set_bg_color(Color(0.2, 0.3, 0.5, 0.9))

	func _refresh_ready_ui() -> void:
		"""Ready to claim display"""
		# Header with ready indicator
		faction_label.text = "Done %s" % quest_data.get("faction", "Unknown")
		status_label.text = "Ready"

		# Left: Requirement (completed)
		var quest_type = quest_data.get("type", 0)
		_set_requirement_display(quest_type)
		action_type_label.text = "Done " + action_type_label.text

		# Right: Vocab pair reward (highlighted)
		_set_reward_display()
		north_label.modulate = Color(0.5, 1.0, 0.5)
		south_label.modulate = Color(0.5, 1.0, 0.5)

		# Bottom bar: signature + alignment (bright for ready state)
		var alignment = quest_data.get("_alignment", 0.5)
		_set_bottom_bar(alignment)
		alignment_bar_label.modulate = Color(0.5, 1.0, 0.5)

		_set_bg_color(Color(0.2, 0.5, 0.2, 0.95))

	func _set_requirement_display(quest_type: int) -> void:
		"""Set left column based on quest type"""
		match quest_type:
			0:  # DELIVERY
				action_type_label.text = "Deliver"
				var resource = quest_data.get("resource", "?")
				var quantity = quest_data.get("quantity", 1)
				requirement_label.text = "%s x %d" % [resource, quantity]
			1:  # SHAPE_ACHIEVE
				action_type_label.text = "Reach"
				var obs = quest_data.get("observable", "purity")
				var target = quest_data.get("target", 0.7)
				var comp = quest_data.get("comparison", ">")
				var comp_str = ">=" if comp == ">" else "<="
				requirement_label.text = "%s %s %d%%" % [obs, comp_str, int(target * 100)]
			2:  # SHAPE_MAINTAIN
				action_type_label.text = "Hold"
				var obs = quest_data.get("observable", "purity")
				var target = quest_data.get("target", 0.7)
				var duration = quest_data.get("duration", 30)
				var comp = quest_data.get("comparison", ">")
				var comp_str = ">=" if comp == ">" else "<="
				requirement_label.text = "%s %s %d%% %ds" % [obs, comp_str, int(target * 100), int(duration)]
			3:  # EVOLUTION
				var direction = quest_data.get("direction", "increase")
				action_type_label.text = direction.capitalize()
				var obs = quest_data.get("observable", "purity")
				var delta = quest_data.get("delta", 0.2)
				requirement_label.text = "%s %d%%" % [obs, int(delta * 100)]
			4:  # ENTANGLEMENT
				action_type_label.text = "Entangle"
				var target = quest_data.get("target_coherence", 0.6)
				requirement_label.text = ">= %d%%" % int(target * 100)
			_:
				action_type_label.text = "Quest"
				requirement_label.text = quest_data.get("body", "???")

	func _set_reward_display() -> void:
		"""Set right column with vocab pair"""
		var north = quest_data.get("reward_vocab_north", "")
		var south = quest_data.get("reward_vocab_south", "")

		if north == "":
			north_label.text = "OK"
			separator_label.visible = false
			south_label.text = "known"
			north_label.modulate = Color(0.6, 0.6, 0.6)
			south_label.modulate = Color(0.6, 0.6, 0.6)
		elif south == "":
			north_label.text = north
			separator_label.visible = false
			south_label.text = "(solo)"
			north_label.modulate = Color(1.0, 1.0, 1.0)
			south_label.modulate = Color(0.6, 0.6, 0.6)
		else:
			north_label.text = north
			separator_label.visible = true
			south_label.text = south
			north_label.modulate = Color(1.0, 1.0, 1.0)
			south_label.modulate = Color(1.0, 1.0, 1.0)

	func _set_bottom_bar(alignment: float) -> void:
		"""Set bottom bar with faction signature and alignment bar (both left-aligned)"""
		# Faction signature emojis + alignment bar together
		var sig = quest_data.get("faction_signature", quest_data.get("sig", []))
		var sig_text = "".join(sig.slice(0, 5)) if sig.size() > 0 else ""

		# Alignment bar: Mood + bar
		var mood = _alignment_to_mood_icon(alignment)
		var bar = _make_alignment_bar(alignment, 8)

		# Combine: signature + spacing + mood bar
		signature_label.text = "%s  %s%s" % [sig_text, mood, bar]
		alignment_bar_label.text = ""  # Not used anymore, all in signature_label

	func _make_alignment_bar(value: float, length: int) -> String:
		"""Create visual alignment bar"""
		var filled = int(value * length)
		var bar = ""
		for i in range(length):
			if i < filled:
				bar += "#"
			else:
				bar += "-"
		return bar

	func _alignment_to_mood_icon(alignment: float) -> String:
		"""Convert alignment to single mood emoji"""
		if alignment > 0.8:
			return ":)"
		elif alignment > 0.6:
			return ":)"
		elif alignment > 0.4:
			return ":|"
		elif alignment > 0.2:
			return ":("
		else:
			return ">:("

	func _set_bg_color(color: Color) -> void:
		"""Set background with clean style"""
		var style = UIStyleFactory.create_slot_style(color)
		add_theme_stylebox_override("panel", style)

	func _get_alignment_color(alignment: float) -> Color:
		return UIStyleFactory.get_alignment_color(alignment)
