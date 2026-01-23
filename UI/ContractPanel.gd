class_name ContractPanel
extends PanelContainer

## Contract Panel - Displays faction contracts and reputation
## Toggle with 'C' key

signal contract_accepted(contract)

# References
var faction_manager = null

# UI Elements
var main_vbox: VBoxContainer
var header_label: Label
var available_section: VBoxContainer
var active_section: VBoxContainer
var reputation_section: VBoxContainer

# Styling
const PANEL_WIDTH = 400
const CONTRACT_CARD_HEIGHT = 80
const REPUTATION_ITEM_HEIGHT = 30


func _ready():
	# Panel setup
	custom_minimum_size = Vector2(PANEL_WIDTH, 600)

	# Create main layout
	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	# Header
	header_label = Label.new()
	header_label.text = "📜 FACTION CONTRACTS [C]"
	header_label.add_theme_font_size_override("font_size", 20)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(header_label)

	# Available Contracts Section
	var available_header = Label.new()
	available_header.text = "Available Contracts"
	available_header.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(available_header)

	available_section = VBoxContainer.new()
	available_section.add_theme_constant_override("separation", 5)
	main_vbox.add_child(available_section)

	# Active Contracts Section
	var active_header = Label.new()
	active_header.text = "Active Contracts"
	active_header.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(active_header)

	active_section = VBoxContainer.new()
	active_section.add_theme_constant_override("separation", 5)
	main_vbox.add_child(active_section)

	# Reputation Section
	var reputation_header = Label.new()
	reputation_header.text = "Faction Reputation"
	reputation_header.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(reputation_header)

	reputation_section = VBoxContainer.new()
	reputation_section.add_theme_constant_override("separation", 3)
	main_vbox.add_child(reputation_section)

	# Initial refresh
	refresh_display()


func set_faction_manager(manager):
	"""Set the faction manager reference"""
	faction_manager = manager
	if faction_manager:
		# Connect signals (check if not already connected)
		if not faction_manager.contract_offered.is_connected(_on_contract_offered):
			faction_manager.contract_offered.connect(_on_contract_offered)
		if not faction_manager.contract_completed.is_connected(_on_contract_completed):
			faction_manager.contract_completed.connect(_on_contract_completed)
		if not faction_manager.reputation_changed.is_connected(_on_reputation_changed):
			faction_manager.reputation_changed.connect(_on_reputation_changed)
		if not faction_manager.faction_relationship_changed.is_connected(_on_relationship_changed):
			faction_manager.faction_relationship_changed.connect(_on_relationship_changed)
	refresh_display()


func refresh_display():
	"""Refresh all contract and reputation displays"""
	if not faction_manager:
		return

	_refresh_available_contracts()
	_refresh_active_contracts()
	_refresh_reputation()


func _refresh_available_contracts():
	"""Update available contracts list"""
	if not available_section:
		return  # Not ready yet

	# Clear existing
	for child in available_section.get_children():
		child.queue_free()

	if not faction_manager:
		var no_contracts = Label.new()
		no_contracts.text = "No faction manager"
		available_section.add_child(no_contracts)
		return

	var available = faction_manager.get_available_contracts()

	if available.is_empty():
		var no_contracts = Label.new()
		no_contracts.text = "No contracts available"
		no_contracts.modulate = Color(0.7, 0.7, 0.7)
		available_section.add_child(no_contracts)
		return

	# Create contract cards
	for contract in available:
		var card = _create_available_contract_card(contract)
		available_section.add_child(card)


func _refresh_active_contracts():
	"""Update active contracts list"""
	if not active_section:
		return  # Not ready yet

	# Clear existing
	for child in active_section.get_children():
		child.queue_free()

	if not faction_manager:
		return

	var active = faction_manager.get_active_contracts()

	if active.is_empty():
		var no_contracts = Label.new()
		no_contracts.text = "No active contracts"
		no_contracts.modulate = Color(0.7, 0.7, 0.7)
		active_section.add_child(no_contracts)
		return

	# Create contract cards
	for contract in active:
		var card = _create_active_contract_card(contract)
		active_section.add_child(card)


func _refresh_reputation():
	"""Update faction reputation display"""
	if not reputation_section:
		return  # Not ready yet

	# Clear existing
	for child in reputation_section.get_children():
		child.queue_free()

	if not faction_manager:
		return

	var factions = faction_manager.get_all_factions()

	for faction in factions:
		var rep_item = _create_reputation_item(faction)
		reputation_section.add_child(rep_item)


func _create_available_contract_card(contract) -> PanelContainer:
	"""Create a card for an available contract"""
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, CONTRACT_CARD_HEIGHT)

	var vbox = VBoxContainer.new()
	card.add_child(vbox)

	# Title and faction
	var faction = faction_manager.get_faction(contract.faction_id)
	var title_label = Label.new()
	title_label.text = "%s %s" % [faction.faction_emoji if faction else "📜", contract.contract_title]
	title_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = contract.contract_description
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(desc_label)

	# Rewards
	var reward_label = Label.new()
	reward_label.text = "💰 %d credits, ⭐ +%d rep" % [contract.reward_credits, contract.reward_reputation]
	reward_label.add_theme_font_size_override("font_size", 11)
	reward_label.modulate = Color(0.3, 1.0, 0.3)
	vbox.add_child(reward_label)

	# Accept button
	var accept_btn = Button.new()
	accept_btn.text = "✅ Accept"
	accept_btn.pressed.connect(func(): _on_accept_contract_pressed(contract))
	vbox.add_child(accept_btn)

	return card


func _create_active_contract_card(contract) -> PanelContainer:
	"""Create a card for an active contract"""
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, CONTRACT_CARD_HEIGHT)

	var vbox = VBoxContainer.new()
	card.add_child(vbox)

	# Title and faction
	var faction = faction_manager.get_faction(contract.faction_id)
	var title_label = Label.new()
	title_label.text = "%s %s" % [faction.faction_emoji if faction else "📜", contract.contract_title]
	title_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title_label)

	# Progress indicator
	var progress_label = Label.new()
	progress_label.text = _get_contract_progress_text(contract)
	progress_label.add_theme_font_size_override("font_size", 11)
	progress_label.modulate = Color(1.0, 1.0, 0.3)
	vbox.add_child(progress_label)

	# Time remaining (if timed)
	if contract.time_limit > 0:
		var time_label = Label.new()
		var time_remaining = int(contract.time_remaining)
		time_label.text = "⏱️ Time: %d:%02d" % [time_remaining / 60, time_remaining % 60]
		time_label.add_theme_font_size_override("font_size", 11)
		time_label.modulate = Color(1.0, 0.5, 0.5) if time_remaining < 60 else Color(0.8, 0.8, 0.8)
		vbox.add_child(time_label)

	# Turn In button (only if contract is completable)
	var can_turn_in = contract.get("can_turn_in") if contract.get("can_turn_in") != null else false
	if can_turn_in:
		var turn_in_btn = Button.new()
		turn_in_btn.text = "✅ Turn In [ENTER]"
		turn_in_btn.modulate = Color(0.5, 1.0, 0.5)  # Green highlight
		turn_in_btn.pressed.connect(func(): _on_turn_in_contract_pressed(contract))
		vbox.add_child(turn_in_btn)

	return card


func _create_reputation_item(faction) -> HBoxContainer:
	"""Create a reputation display item"""
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, REPUTATION_ITEM_HEIGHT)

	# Faction emoji and name
	var name_label = Label.new()
	name_label.text = "%s %s" % [faction.faction_emoji, faction.faction_name]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(name_label)

	# Reputation value
	var rep = faction_manager.get_reputation(faction.faction_id)
	var status = faction_manager.get_relationship_status(faction.faction_id)

	var rep_label = Label.new()
	rep_label.text = "%+d (%s)" % [rep, status]
	rep_label.add_theme_font_size_override("font_size", 12)

	# Color by relationship
	match status:
		"allied":
			rep_label.modulate = Color(0.3, 1.0, 0.3)  # Green
		"friendly":
			rep_label.modulate = Color(0.5, 1.0, 0.5)  # Light green
		"neutral":
			rep_label.modulate = Color(0.8, 0.8, 0.8)  # Gray
		"hostile":
			rep_label.modulate = Color(1.0, 0.3, 0.3)  # Red

	hbox.add_child(rep_label)

	return hbox


func _get_contract_progress_text(contract) -> String:
	"""Get human-readable progress text for a contract"""
	match contract.contract_type:
		"harvest_quota":
			var required = contract.requirements.get("wheat_amount", 0)
			return "📊 Progress: Harvest %d wheat" % required
		"conspiracy_research":
			var conspiracy = contract.requirements.get("conspiracy_name", "unknown")
			return "📊 Progress: Discover '%s'" % conspiracy
		"topological_defense":
			var min_jones = contract.requirements.get("min_jones_polynomial", 0.0)
			return "📊 Progress: Build topology with Jones ≥ %.1f" % min_jones
		"purity_delivery":
			var required = contract.requirements.get("wheat_amount", 0)
			var max_chaos = contract.requirements.get("max_chaos_influence", 0.5)
			return "📊 Progress: %d pure wheat (chaos < %.1f%%)" % [required, max_chaos * 100]
		"chaos_containment":
			var max_conspiracies = contract.requirements.get("max_active_conspiracies", 3)
			var min_protection = contract.requirements.get("min_topological_protection", 5)
			return "📊 Progress: ≤%d conspiracies, protection ≥%d" % [max_conspiracies, min_protection]
		_:
			return "📊 Progress: In progress..."


func _on_accept_contract_pressed(contract):
	"""Handle accept button press"""
	if faction_manager.accept_contract(contract):
		contract_accepted.emit(contract)
		refresh_display()
	else:
		print("⚠️ Failed to accept contract")


func _on_turn_in_contract_pressed(contract):
	"""Handle turn in button press (manual contract completion)"""
	# Get player state to verify completion
	var farm_view = get_parent().get_parent()  # Hacky but works to get FarmView
	if not farm_view or not farm_view.has_method("get_player_state_for_contract_evaluation"):
		print("⚠️ Cannot get player state")
		return

	var player_state = faction_manager.get_player_state_for_contract_evaluation(farm_view)

	# Complete contract through faction manager
	if faction_manager.check_contract_completion(contract, player_state):
		print("✅ Contract turned in successfully")
		refresh_display()
	else:
		print("⚠️ Contract not ready to turn in")


func _on_contract_offered(contract):
	"""Handle new contract offered signal"""
	refresh_display()


func _on_contract_completed(contract, _rewards):
	"""Handle contract completion signal"""
	refresh_display()


func _on_reputation_changed(_faction_id, _new_reputation, _change):
	"""Handle reputation change signal"""
	_refresh_reputation()


func _on_relationship_changed(_faction_id, _relationship):
	"""Handle relationship status change signal"""
	_refresh_reputation()
