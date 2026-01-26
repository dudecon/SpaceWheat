class_name QuestBoard
extends Control

const UIStyleFactory = preload("res://UI/Core/UIStyleFactory.gd")
const UIOrnamentation = preload("res://UI/Core/UIOrnamentation.gd")

## Modal Quest Board with 4 Slots (UIOP)
## Controls hijacked when open (like ESC menu)
## Press C to drill into faction browser

const VocabularyPairing = preload("res://Core/Quests/VocabularyPairing.gd")

signal quest_accepted(quest: Dictionary)
signal quest_completed(quest_id: int, rewards: Dictionary)
signal quest_abandoned(quest_id: int)
signal board_closed
signal board_opened
signal selection_changed(slot_state: int, is_locked: bool)  # For updating action toolbar
signal action_performed(action: String, data: Dictionary)  # v2 overlay compatibility

# v2 Overlay Interface
var overlay_name: String = "quests"
var overlay_icon: String = "📜"
var overlay_tier: int = 3000  # Z_TIER_MODAL
var action_labels: Dictionary = {
	"Q": "Accept/Complete",
	"E": "Reroll/Abandon",
	"R": "Lock/Unlock",
	"F": "Next Page"
}

# References
var layout_manager: Node
var quest_manager: Node
var current_biome: Node

# UI elements
var background: ColorRect
var menu_panel: PanelContainer
var title_label: Label
var slot_container: GridContainer  # Changed to GridContainer for 2×2 quadrant layout
var accessible_factions_label: Label

# Quest slots (4 slots: U, I, O, P)
var quest_slots: Array = []  # Array of QuestSlot instances
var selected_slot_index: int = 0

# Quest pool for F-cycling
var all_available_quests: Array = []  # All quests from accessible factions
var quest_page_offset: int = 0  # Current page offset (0, 4, 8, ...)

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
	z_index = 0  # OverlayLayer(100) + 0 = 100, above tools(55), below actions(200)

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

	# Connect to quest manager signals (check if not already connected)
	if quest_manager:
		if not quest_manager.quest_completed.is_connected(_on_quest_completed):
			quest_manager.quest_completed.connect(_on_quest_completed)
		if not quest_manager.active_quests_changed.is_connected(_refresh_slots):
			quest_manager.active_quests_changed.connect(_refresh_slots)
		if quest_manager.has_signal("quest_ready_to_claim"):
			if not quest_manager.quest_ready_to_claim.is_connected(_on_quest_ready_to_claim):
				quest_manager.quest_ready_to_claim.connect(_on_quest_ready_to_claim)


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
		# Arrow keys for navigation (2×2 grid layout)
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


func _create_ui() -> void:
	"""Create the quest board UI - 2×2 QUADRANT LAYOUT with auto-scaling.

	Uses UILayoutManager constants for consistent layout proportions.
	"""
	const UILayoutManager = preload("res://UI/Managers/UILayoutManager.gd")

	var scale = layout_manager.scale_factor if layout_manager else 1.0

	# Use UILayoutManager constants for consistent proportions
	var top_bar_percent = UILayoutManager.TOP_BAR_HEIGHT_PERCENT  # 0.06 (6%)
	var play_area_percent = UILayoutManager.PLAY_AREA_PERCENT     # 0.665 (66.5%)
	var bottom_percent = top_bar_percent + play_area_percent      # ~0.725 (72.5%)

	# Balanced font sizes - readable but compact
	var title_size = 24
	var large_size = 16
	var normal_size = 14

	# Background dimmer - starts BELOW resource bar so player can see resources
	background = ColorRect.new()
	background.color = UIStyleFactory.COLOR_MODAL_DIMMER
	background.anchor_left = 0.0
	background.anchor_right = 1.0
	background.anchor_top = top_bar_percent  # Start at 6% (below resource bar)
	background.anchor_bottom = 1.0
	background.layout_mode = 1
	add_child(background)

	# Center container for panel - positioned in play zone (below resource bar)
	var center = CenterContainer.new()
	center.anchor_left = 0.0
	center.anchor_right = 1.0
	center.anchor_top = top_bar_percent  # Start right at 6% (below resource bar)
	center.anchor_bottom = bottom_percent  # End at ~72.5% (above tool selection)
	center.offset_left = 0
	center.offset_right = 0
	center.offset_top = 0  # No extra margin - start right below resources
	center.offset_bottom = 0
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.layout_mode = 1
	add_child(center)

	# Quest board panel - compact, fits in play zone
	menu_panel = PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(880, 340)
	var panel_style = UIStyleFactory.create_panel_style(
		UIStyleFactory.COLOR_PANEL_BG,
		Color(0.5, 0.4, 0.6, 0.8)  # Purple border for quests
	)
	menu_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(menu_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", int(8 * scale))
	menu_panel.add_child(main_vbox)

	# Corner ornamentation disabled - layout issues with PanelContainer
	# UIOrnamentation.apply_corners_to_panel(
	# 	menu_panel,
	# 	UIOrnamentation.CORNER_SIZE_MEDIUM,
	# 	UIOrnamentation.TINT_GOLD
	# )

	# Header - compact
	title_label = UIStyleFactory.create_title_label("⚛️ QUEST ORACLE ⚛️", title_size)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title_label)

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
	mouse_filter = Control.MOUSE_FILTER_STOP  # Capture input when open
	_refresh_biome_state()
	_refresh_slots()
	_update_accessible_count()

	# Emit board opened signal and initial selection
	board_opened.emit()
	_emit_selection_update()


func close_board() -> void:
	"""Close the quest board"""
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Release input to prevent blocking
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
	if gsm and gsm.current_state and gsm.current_state.has("quest_slots"):
		return gsm.current_state.quest_slots
	return []


func _refresh_slots() -> void:
	"""Refresh all quest slots - displays current page from all_available_quests pool

	IMPORTANT: Locked and Active slots are PINNED - they don't change when F cycles pages.
	Only EMPTY and OFFERED (not locked) slots get updated from the quest pool.
	"""
	if not quest_manager or not current_biome:
		return

	# Build the full quest pool from all accessible factions
	all_available_quests = quest_manager.offer_all_faction_quests(current_biome)

	# Identify pinned slots and their factions (locked OR active)
	var pinned_factions: Array = []
	var unpinned_slot_indices: Array = []

	for i in range(4):
		var slot = quest_slots[i]
		var is_pinned = slot.is_locked or slot.state == SlotState.ACTIVE or slot.state == SlotState.READY

		if is_pinned and slot.quest_data.has("faction"):
			pinned_factions.append(slot.quest_data.get("faction", ""))
		elif not is_pinned:
			unpinned_slot_indices.append(i)

	# Filter quest pool to exclude factions already in pinned slots
	var available_for_cycling: Array = []
	for quest in all_available_quests:
		var faction = quest.get("faction", "")
		if faction not in pinned_factions:
			available_for_cycling.append(quest)

	# Reset page offset if it exceeds filtered quests
	if quest_page_offset >= available_for_cycling.size():
		quest_page_offset = 0

	# Fill only UNPINNED slots from current page of available quests
	var quest_index = quest_page_offset
	for slot_index in unpinned_slot_indices:
		var slot = quest_slots[slot_index]

		if quest_index < available_for_cycling.size():
			var quest = available_for_cycling[quest_index]
			slot.set_quest_offered(quest, false)
			quest_index += 1
		else:
			slot.set_empty()

	_update_slot_selection()
	_update_page_display()


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


func _update_page_display() -> void:
	"""Update the page indicator in accessible_factions_label"""
	# Count pinned slots
	var pinned_count = 0
	var pinned_factions: Array = []
	for slot in quest_slots:
		var is_pinned = slot.is_locked or slot.state == SlotState.ACTIVE or slot.state == SlotState.READY
		if is_pinned:
			pinned_count += 1
			if slot.quest_data.has("faction"):
				pinned_factions.append(slot.quest_data.get("faction", ""))

	# Count available quests (excluding pinned factions)
	var available_count = 0
	for quest in all_available_quests:
		var faction = quest.get("faction", "")
		if faction not in pinned_factions:
			available_count += 1

	var unpinned_slots = 4 - pinned_count
	var total_pages = int(ceil(float(available_count) / float(max(1, unpinned_slots)))) if available_count > 0 else 1
	var current_page = (quest_page_offset / max(1, unpinned_slots)) + 1

	# Show pinned count if any slots are pinned
	var pinned_text = " | 📌 %d pinned" % pinned_count if pinned_count > 0 else ""

	accessible_factions_label.text = "📚 Page %d/%d  |  %d quests%s  |  [F] Next" % [
		current_page, total_pages, all_available_quests.size(), pinned_text
	]


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
	"""Q action: Accept (OFFERED), Deliver (ACTIVE DELIVERY), or Claim (READY)"""
	var slot = quest_slots[selected_slot_index]
	var quest_type = slot.quest_data.get("type", 0)  # 0 = DELIVERY
	print("🎯 action_q_on_selected: slot=%d, state=%d, quest_type=%d, quest_id=%d" % [
		selected_slot_index, slot.state, quest_type, slot.quest_data.get("id", -1)])

	match slot.state:
		SlotState.OFFERED:
			print("  → Accepting quest")
			_accept_quest(slot)
		SlotState.READY:
			# Claim rewards (works for both DELIVERY and non-DELIVERY)
			if quest_type == 0:
				print("  → Delivering READY quest")
				_deliver_quest(slot)  # DELIVERY: deduct resources, grant rewards
			else:
				print("  → Claiming READY quest")
				_claim_quest(slot)  # Non-DELIVERY: just grant rewards
		SlotState.ACTIVE:
			if quest_type == 0:  # DELIVERY
				# Check if player has resources to deliver
				var can_deliver = _check_can_complete(slot)
				print("  → ACTIVE DELIVERY, can_deliver=%s" % str(can_deliver))
				if can_deliver:
					_deliver_quest(slot)
				else:
					print("  ⚠️ Not enough resources to deliver")
			else:  # Non-DELIVERY (SHAPE_ACHIEVE etc.)
				print("  ℹ️ This quest tracks automatically - watch the biome state!")


func action_e_on_selected() -> void:
	"""E action: Reroll (OFFERED), Abandon (ACTIVE), or Reject (READY non-DELIVERY)"""
	var slot = quest_slots[selected_slot_index]
	var quest_type = slot.quest_data.get("type", 0)  # 0 = DELIVERY

	match slot.state:
		SlotState.OFFERED:
			if not slot.is_locked:
				_reroll_quest(slot)
		SlotState.ACTIVE:
			_abandon_quest(slot)
		SlotState.READY:
			if quest_type != 0:  # Non-DELIVERY: can reject
				_reject_quest(slot)
			else:  # DELIVERY: can still abandon
				_abandon_quest(slot)


func action_r_on_selected() -> void:
	"""R action: Lock/Unlock toggle"""
	var slot = quest_slots[selected_slot_index]
	slot.toggle_lock()
	_save_slot_state()


func _accept_quest(slot: QuestSlot) -> void:
	"""Accept an offered quest"""
	if not quest_manager:
		print("❌ _accept_quest: quest_manager is null!")
		return

	# CRITICAL: Save quest data and set slot to ACTIVE *before* calling accept_quest
	# because accept_quest emits active_quests_changed which triggers _refresh_slots,
	# and we need the slot to be pinned (ACTIVE) so it doesn't get overwritten!
	var quest_data_copy = slot.quest_data.duplicate(true)
	print("📝 _accept_quest: Duplicated quest ID=%d, faction=%s" % [
		quest_data_copy.get("id", -1), quest_data_copy.get("faction", "?")])
	slot.set_quest_active(quest_data_copy)

	var success = quest_manager.accept_quest(quest_data_copy)
	if success:
		quest_accepted.emit(quest_data_copy)
		_save_slot_state()
		# CRITICAL: Update action labels after state change!
		_emit_selection_update()
		print("✅ Accepted quest: %s (ID: %d)" % [quest_data_copy.get("faction", "Unknown"), quest_data_copy.get("id", -1)])
	else:
		print("❌ _accept_quest: accept_quest returned false")
		# Revert slot state if accept failed
		slot.set_quest_offered(quest_data_copy, slot.is_locked)


func _deliver_quest(slot: QuestSlot) -> void:
	"""Deliver a DELIVERY quest - deducts resources and grants rewards"""
	if not quest_manager:
		print("❌ _deliver_quest: quest_manager is null!")
		return

	var quest_id = slot.quest_data.get("id", -1)
	print("📦 _deliver_quest: quest_id=%d, faction=%s" % [quest_id, slot.quest_data.get("faction", "?")])
	if quest_id < 0:
		print("❌ _deliver_quest: invalid quest_id!")
		return

	var success = quest_manager.complete_quest(quest_id)
	if success:
		print("✅ Delivered quest: %s" % slot.quest_data.get("faction", "Unknown"))
		_emit_selection_update()
		# Slot will be auto-filled on next refresh
	else:
		print("❌ _deliver_quest: complete_quest returned false")


func _claim_quest(slot: QuestSlot) -> void:
	"""Claim rewards for a READY non-DELIVERY quest"""
	if not quest_manager:
		print("❌ _claim_quest: quest_manager is null!")
		return

	var quest_id = slot.quest_data.get("id", -1)
	print("🎁 _claim_quest: quest_id=%d, faction=%s" % [quest_id, slot.quest_data.get("faction", "?")])
	if quest_id < 0:
		print("❌ _claim_quest: invalid quest_id!")
		return

	var success = quest_manager.claim_quest(quest_id)
	if success:
		print("✅ Claimed quest rewards: %s" % slot.quest_data.get("faction", "Unknown"))
		_emit_selection_update()
		# Slot will be auto-filled on next refresh
	else:
		print("❌ _claim_quest: claim_quest returned false")


func _reject_quest(slot: QuestSlot) -> void:
	"""Reject a READY non-DELIVERY quest without claiming rewards"""
	if not quest_manager:
		return

	var quest_id = slot.quest_data.get("id", -1)
	if quest_id < 0:
		return

	quest_manager.reject_quest(quest_id)
	quest_abandoned.emit(quest_id)
	_auto_fill_slot(slot.slot_index)
	_save_slot_state()
	print("🚫 Rejected quest: %s" % slot.quest_data.get("faction", "Unknown"))


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


func _on_quest_ready_to_claim(quest_id: int) -> void:
	"""Handle quest ready to claim signal from manager (non-DELIVERY quest conditions met)"""
	# Find slot with this quest and update to READY state
	for i in range(4):
		var slot = quest_slots[i]
		if slot.quest_data.get("id", -1) == quest_id:
			slot.state = SlotState.READY
			slot._refresh_ui()
			print("✨ Quest ready to claim: %s" % slot.quest_data.get("faction", "Unknown"))
			# Update action labels if this slot is selected
			if i == selected_slot_index:
				_emit_selection_update()
			break


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
# V2 OVERLAY INTERFACE
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
	"""v2 overlay action: F key cycles to next page of quests.

	Advances by the number of UNPINNED slots, so locked/active quests stay put.
	"""
	if all_available_quests.is_empty():
		return

	# Count unpinned slots to determine page size
	var unpinned_count = 0
	for slot in quest_slots:
		var is_pinned = slot.is_locked or slot.state == SlotState.ACTIVE or slot.state == SlotState.READY
		if not is_pinned:
			unpinned_count += 1

	# No unpinned slots means nothing to cycle
	if unpinned_count == 0:
		return

	# Advance by number of unpinned slots (dynamic page size)
	quest_page_offset += unpinned_count

	# Wrap around handled in _refresh_slots()

	# Refresh slots with new page
	_refresh_slots()

	# Keep current selection (don't reset to 0)
	action_performed.emit("quest_next_page", {"page_offset": quest_page_offset})


func get_action_labels() -> Dictionary:
	"""v2 overlay interface: Get context-sensitive QER+F labels.

	Labels change based on selected slot state.
	"""
	if selected_slot_index < 0 or selected_slot_index >= quest_slots.size():
		return action_labels

	var slot = quest_slots[selected_slot_index]
	var labels = action_labels.duplicate()

	# Context-sensitive Q and E labels based on quest type and state
	var quest_type = slot.quest_data.get("type", 0)  # 0 = DELIVERY, 1+ = SHAPE_ACHIEVE etc.

	match slot.state:
		SlotState.EMPTY:
			labels["Q"] = "—"
			labels["E"] = "—"
		SlotState.OFFERED:
			labels["Q"] = "Accept"
			labels["E"] = "Reroll" if not slot.is_locked else "—"
		SlotState.ACTIVE:
			if quest_type == 0:  # DELIVERY - player delivers resources
				labels["Q"] = "Deliver"
			else:  # SHAPE_ACHIEVE etc. - auto-tracks biome state
				labels["Q"] = "Tracking"
			labels["E"] = "Abandon"
		SlotState.READY:
			if quest_type == 0:  # DELIVERY ready to turn in
				labels["Q"] = "Deliver"
				labels["E"] = "Abandon"
			else:  # SHAPE_ACHIEVE conditions met - claim rewards
				labels["Q"] = "Claim"
				labels["E"] = "Reject"

	# R label based on lock state
	labels["R"] = "Unlock" if slot.is_locked else "Lock"

	return labels


func get_overlay_info() -> Dictionary:
	"""v2 overlay interface: Get overlay metadata for registration."""
	return {
		"name": overlay_name,
		"icon": overlay_icon,
		"action_labels": get_action_labels(),
		"tier": overlay_tier
	}


func get_overlay_tier() -> int:
	"""Get z-index tier for OverlayStackManager."""
	return overlay_tier


# =============================================================================
# QUEST SLOT COMPONENT
# =============================================================================

class QuestSlot extends PanelContainer:
	"""Individual quest slot display - Two column layout

	Layout:
	┌────────────────────────────────────┐
	│ [U] 🔒  Faction Name        😊 ♾️ │
	├────────────────┬───────────────────┤
	│   Deliver      │        🌾         │
	│    🌾 × 5      │       ━━━         │
	│                │        🍄         │
	└────────────────┴───────────────────┘
	"""

	signal slot_selected(slot_index: int)

	var layout_manager: Node
	var slot_letter: String = "U"
	var slot_index: int = 0
	var state: int = SlotState.EMPTY
	var quest_data: Dictionary = {}
	var is_locked: bool = false
	var is_selected: bool = false

	# UI elements - Header row
	var slot_label: Label        # [U] 🔒
	var faction_label: Label     # Faction name
	var status_label: Label      # 😊 ♾️

	# UI elements - Left column (requirement)
	var action_type_label: Label   # "Deliver" or "Reach" etc.
	var requirement_label: Label   # "🌾 × 5" or "purity ≥ 70%"

	# UI elements - Right column (reward)
	var north_label: Label       # North emoji (BIG)
	var separator_label: Label   # ━━━
	var south_label: Label       # South emoji (BIG)

	# UI elements - Bottom bar (faction info)
	var signature_label: Label      # Faction signature emojis
	var alignment_bar_label: Label  # 😊 ████████░░

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
		separator_label.text = "━━━"
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
		"""Update all UI elements based on state"""
		# Header: slot key + lock
		var lock_icon = "🔒" if is_locked else ""
		slot_label.text = "[%s]%s" % [slot_letter, lock_icon]

		match state:
			SlotState.EMPTY:
				_refresh_empty_ui()
			SlotState.OFFERED:
				_refresh_offered_ui()
			SlotState.ACTIVE:
				_refresh_active_ui()
			SlotState.READY:
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
		faction_label.text = "⚡ %s" % quest_data.get("faction", "Unknown")
		status_label.text = "🔥"

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
		faction_label.text = "✅ %s" % quest_data.get("faction", "Unknown")
		status_label.text = "✨"

		# Left: Requirement (completed)
		var quest_type = quest_data.get("type", 0)
		_set_requirement_display(quest_type)
		action_type_label.text = "✓ " + action_type_label.text

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
				requirement_label.text = "%s × %d" % [resource, quantity]
			1:  # SHAPE_ACHIEVE
				action_type_label.text = "Reach"
				var obs = quest_data.get("observable", "purity")
				var target = quest_data.get("target", 0.7)
				var comp = quest_data.get("comparison", ">")
				var comp_str = "≥" if comp == ">" else "≤"
				requirement_label.text = "%s %s %d%%" % [obs, comp_str, int(target * 100)]
			2:  # SHAPE_MAINTAIN
				action_type_label.text = "Hold"
				var obs = quest_data.get("observable", "purity")
				var target = quest_data.get("target", 0.7)
				var duration = quest_data.get("duration", 30)
				var comp = quest_data.get("comparison", ">")
				var comp_str = "≥" if comp == ">" else "≤"
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
				requirement_label.text = "≥ %d%%" % int(target * 100)
			_:
				action_type_label.text = "Quest"
				requirement_label.text = quest_data.get("body", "???")

	func _set_reward_display() -> void:
		"""Set right column with vocab pair"""
		var north = quest_data.get("reward_vocab_north", "")
		var south = quest_data.get("reward_vocab_south", "")

		if north == "":
			north_label.text = "✓"
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

		# Alignment bar: 😊 ████████░░
		var mood = _alignment_to_mood_icon(alignment)
		var bar = _make_alignment_bar(alignment, 8)

		# Combine: signature + spacing + mood bar
		signature_label.text = "%s  %s%s" % [sig_text, mood, bar]
		alignment_bar_label.text = ""  # Not used anymore, all in signature_label

	func _make_alignment_bar(value: float, length: int) -> String:
		"""Create visual alignment bar: ████████░░"""
		var filled = int(value * length)
		var bar = ""
		for i in range(length):
			if i < filled:
				bar += "█"
			else:
				bar += "░"
		return bar

	func _alignment_to_mood_icon(alignment: float) -> String:
		"""Convert alignment to single mood emoji"""
		if alignment > 0.8:
			return "😊"
		elif alignment > 0.6:
			return "🙂"
		elif alignment > 0.4:
			return "😐"
		elif alignment > 0.2:
			return "😕"
		else:
			return "😠"

	func _set_bg_color(color: Color) -> void:
		"""Set background with clean style"""
		var style = UIStyleFactory.create_slot_style(color)
		add_theme_stylebox_override("panel", style)

	func _get_alignment_color(alignment: float) -> Color:
		return UIStyleFactory.get_alignment_color(alignment)
