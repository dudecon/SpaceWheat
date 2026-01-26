class_name FactionQuestOffersPanel
extends PanelContainer

const UIStyleFactory = preload("res://UI/Core/UIStyleFactory.gd")

## Faction Quest Offers Panel
## Shows emergent quest offers from all 32 factions based on current biome state
## Displays alignment scores and biome observables to teach players

signal quest_offer_accepted(quest: Dictionary)
signal panel_closed

# Layout manager reference
var layout_manager: Node

# Quest manager reference
var quest_manager: Node = null

# Current biome reference
var current_biome: Node = null

# UI elements
var title_label: Label
var biome_state_label: Label
var offers_scroll: ScrollContainer
var offers_vbox: VBoxContainer
var close_button: Button
var refresh_button: Button

# Quest offer items
var offer_items: Array = []

# Constants
const MAX_VISIBLE_OFFERS: int = 10


func set_layout_manager(manager: Node):
	"""Set the layout manager reference"""
	layout_manager = manager


func _ready():
	_create_ui()
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event):
	"""Handle mouse input"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Consume clicks (prevent clicking through)
			accept_event()


func _create_ui():
	"""Create the quest offers UI"""
	var scale = layout_manager.scale_factor if layout_manager else 1.0
	var title_size = layout_manager.get_scaled_font_size(20) if layout_manager else 20
	var biome_size = layout_manager.get_scaled_font_size(12) if layout_manager else 12

	custom_minimum_size = Vector2(700 * scale, 800 * scale)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", int(10 * scale))
	add_child(main_vbox)

	# Header HBox (title + buttons)
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", int(10 * scale))
	main_vbox.add_child(header_hbox)

	# Title
	title_label = Label.new()
	title_label.text = "⚛️ QUEST ORACLE - Faction Offers"
	title_label.add_theme_font_size_override("font_size", title_size)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_label)

	# Refresh button
	refresh_button = Button.new()
	refresh_button.text = "🔄 Refresh"
	refresh_button.pressed.connect(_on_refresh_clicked)
	header_hbox.add_child(refresh_button)

	# Close button
	close_button = Button.new()
	close_button.text = "✖ Close"
	close_button.pressed.connect(_on_close_clicked)
	header_hbox.add_child(close_button)

	# Biome state display
	biome_state_label = Label.new()
	biome_state_label.text = "Biome State: Loading..."
	biome_state_label.add_theme_font_size_override("font_size", biome_size)
	biome_state_label.modulate = Color(0.7, 0.9, 1.0)  # Light blue
	biome_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(biome_state_label)

	# Scroll container for offers
	offers_scroll = ScrollContainer.new()
	offers_scroll.custom_minimum_size = Vector2(0, 650 * scale)
	offers_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	offers_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(offers_scroll)

	# VBox for offer items
	offers_vbox = VBoxContainer.new()
	offers_vbox.add_theme_constant_override("separation", int(8 * scale))
	offers_scroll.add_child(offers_vbox)


# =============================================================================
# PUBLIC API
# =============================================================================

func connect_to_quest_manager(manager: Node) -> void:
	"""Set quest manager reference"""
	quest_manager = manager


func show_offers(biome: Node) -> void:
	"""Show quest offers for the current biome"""
	current_biome = biome

	if not quest_manager:
		push_error("FactionQuestOffersPanel: quest_manager not set")
		return

	# Update biome state display
	_update_biome_state_display()

	# Get quest offers from all factions
	var offers = quest_manager.offer_all_faction_quests(biome)

	# Sort by alignment (highest first)
	offers.sort_custom(func(a, b): return a.get("_alignment", 0) > b.get("_alignment", 0))

	# Clear existing offers
	_clear_offers()

	# Create offer items
	var count = 0
	for quest in offers:
		if count >= MAX_VISIBLE_OFFERS:
			break
		_create_offer_item(quest)
		count += 1

	# Show panel
	visible = true


# =============================================================================
# INTERNAL
# =============================================================================

func _update_biome_state_display():
	"""Update the biome state label with observables"""
	if not quest_manager or not current_biome:
		biome_state_label.text = "Biome State: Unknown"
		return

	var obs = quest_manager.get_biome_observables(current_biome)

	biome_state_label.text = "Current Biome State:\n"
	biome_state_label.text += "  Purity: %.1f%% (%.2f) " % [obs.purity * 100, obs.purity]
	biome_state_label.text += " | Entropy: %.1f%% (%.2f)\n" % [obs.entropy * 100, obs.entropy]
	biome_state_label.text += "  Coherence: %.1f%% (%.2f) " % [obs.coherence * 100, obs.coherence]
	biome_state_label.text += " | Scale: %.1f%%" % [obs.scale * 100]
	biome_state_label.text += "\n  Your farming shaped these quest offers!"


func _create_offer_item(quest: Dictionary):
	"""Create a single quest offer item"""
	var item = QuestOfferItem.new()
	item.set_layout_manager(layout_manager)
	item.set_quest_data(quest)
	item.quest_accepted.connect(_on_offer_accepted.bind(quest))

	offers_vbox.add_child(item)
	offer_items.append(item)


func _clear_offers():
	"""Clear all offer items"""
	for item in offer_items:
		item.queue_free()
	offer_items.clear()


func _on_offer_accepted(quest: Dictionary):
	"""Handle quest acceptance"""
	if not quest_manager:
		return

	# Accept the quest in quest manager
	var success = quest_manager.accept_quest(quest)

	if success:
		quest_offer_accepted.emit(quest)
		# Close panel after accepting
		_on_close_clicked()
	else:
		push_warning("Failed to accept quest: %s" % quest.get("faction", "Unknown"))


func _on_refresh_clicked():
	"""Refresh quest offers"""
	if current_biome:
		show_offers(current_biome)


func _on_close_clicked():
	"""Close the panel"""
	visible = false
	panel_closed.emit()


# =============================================================================
# QUEST OFFER ITEM COMPONENT
# =============================================================================

class QuestOfferItem extends PanelContainer:
	"""Individual quest offer display with alignment score"""

	signal quest_accepted

	var layout_manager: Node
	var quest_data: Dictionary

	func set_layout_manager(manager: Node):
		layout_manager = manager

	func set_quest_data(quest: Dictionary):
		quest_data = quest
		_create_ui()

	func _create_ui():
		var scale = layout_manager.scale_factor if layout_manager else 1.0
		var faction_size = layout_manager.get_scaled_font_size(14) if layout_manager else 14
		var body_size = layout_manager.get_scaled_font_size(13) if layout_manager else 13
		var detail_size = layout_manager.get_scaled_font_size(11) if layout_manager else 11

		custom_minimum_size = Vector2(0, 120 * scale)

		# Background color based on alignment
		var alignment = quest_data.get("_alignment", 0.5)
		var bg_color = _get_alignment_color(alignment)
		add_theme_stylebox_override("panel", _create_colored_panel(bg_color))

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", int(5 * scale))
		add_child(vbox)

		# Faction header with banner + name + alignment
		var header_hbox = HBoxContainer.new()
		header_hbox.add_theme_constant_override("separation", int(8 * scale))
		vbox.add_child(header_hbox)

		# Faction banner (left side)
		var banner_path = quest_data.get("banner_path", "")
		if not banner_path.is_empty() and ResourceLoader.exists(banner_path):
			var banner_rect = TextureRect.new()
			banner_rect.texture = load(banner_path)
			banner_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			banner_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			banner_rect.custom_minimum_size = Vector2(40 * scale, 40 * scale)
			banner_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			header_hbox.add_child(banner_rect)

		# Faction label (name + ring)
		var faction_label = Label.new()
		var domain = quest_data.get("domain", "")
		var ring = quest_data.get("ring", "")
		var ring_display = ""
		if ring:
			ring_display = " [%s]" % ring.capitalize()

		# Show emoji ONLY if no banner is displayed
		var faction_emoji_prefix = ""
		if banner_path.is_empty():
			faction_emoji_prefix = quest_data.get("faction_emoji", "") + " "

		faction_label.text = "%s%s%s" % [
			faction_emoji_prefix,
			quest_data.get("faction", "Unknown"),
			ring_display
		]
		faction_label.add_theme_font_size_override("font_size", faction_size)
		faction_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		faction_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header_hbox.add_child(faction_label)

		# Alignment score (right side)
		var alignment_label = Label.new()
		alignment_label.text = "Alignment: %d%%" % int(alignment * 100)
		alignment_label.add_theme_font_size_override("font_size", detail_size)
		alignment_label.modulate = _get_alignment_text_color(alignment)
		alignment_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header_hbox.add_child(alignment_label)

		# Motto (if available)
		var motto = quest_data.get("motto")
		if motto and motto != "":
			var motto_label = Label.new()
			motto_label.text = '"%s"' % motto
			motto_label.add_theme_font_size_override("font_size", detail_size)
			motto_label.modulate = Color(0.9, 0.9, 0.7)  # Soft gold
			motto_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(motto_label)

		# Quest details
		var body_label = Label.new()
		body_label.text = quest_data.get("body", "Quest details missing")
		body_label.add_theme_font_size_override("font_size", body_size)
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(body_label)

		# Bottom row: requirements + button
		var bottom_hbox = HBoxContainer.new()
		bottom_hbox.add_theme_constant_override("separation", int(15 * scale))
		vbox.add_child(bottom_hbox)

		# Resource requirement
		var resource_label = Label.new()
		resource_label.text = "%s × %d" % [
			quest_data.get("resource", "?"),
			quest_data.get("quantity", 0)
		]
		resource_label.add_theme_font_size_override("font_size", detail_size)
		bottom_hbox.add_child(resource_label)

		# Time limit
		var time_label = Label.new()
		var time_limit = quest_data.get("time_limit", -1)
		if time_limit > 0:
			time_label.text = "⏰ %ds" % int(time_limit)
		else:
			time_label.text = "🕰️ No limit"
		time_label.add_theme_font_size_override("font_size", detail_size)
		bottom_hbox.add_child(time_label)

		# Reward multiplier
		var reward_label = Label.new()
		reward_label.text = "Reward: %.2fx" % quest_data.get("reward_multiplier", 2.0)
		reward_label.add_theme_font_size_override("font_size", detail_size)
		reward_label.modulate = Color(1.0, 0.9, 0.3)  # Gold
		bottom_hbox.add_child(reward_label)

		# Vocabulary preview
		var vocab_label = Label.new()
		var faction_vocab = quest_data.get("faction_vocabulary", [])
		var available_vocab = quest_data.get("available_emojis", [])
		var player_vocab = GameStateManager.current_state.get_known_emojis() if GameStateManager.current_state else []

		# Find unknown emojis in faction's signature
		var unknown_vocab = []
		for emoji in faction_vocab:
			if emoji not in player_vocab:
				unknown_vocab.append(emoji)

		if unknown_vocab.size() > 0:
			var preview = unknown_vocab.slice(0, 3)  # Show first 3
			vocab_label.text = "📖 Learn: %s" % " or ".join(preview)
			if unknown_vocab.size() > 3:
				vocab_label.text += " (+%d)" % (unknown_vocab.size() - 3)
		else:
			vocab_label.text = "📖 (No new vocab)"

		vocab_label.add_theme_font_size_override("font_size", detail_size)
		vocab_label.modulate = Color(0.7, 0.9, 1.0)  # Light blue
		bottom_hbox.add_child(vocab_label)

		# Spacer
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom_hbox.add_child(spacer)

		# Accept button
		var accept_button = Button.new()
		accept_button.text = "✅ Accept"
		accept_button.add_theme_font_size_override("font_size", detail_size)
		accept_button.pressed.connect(_on_accept_pressed)
		bottom_hbox.add_child(accept_button)

	func _on_accept_pressed():
		quest_accepted.emit()

	func _get_alignment_color(alignment: float) -> Color:
		"""Get background color based on alignment score"""
		return UIStyleFactory.get_alignment_color(alignment)

	func _get_alignment_text_color(alignment: float) -> Color:
		"""Get text color for alignment score"""
		return UIStyleFactory.get_alignment_text_color(alignment)

	func _create_colored_panel(color: Color) -> StyleBoxFlat:
		"""Create a colored panel background"""
		return UIStyleFactory.create_slot_style(color, Color(0.5, 0.5, 0.5, 0.5), 2, 8, 10, 8)
