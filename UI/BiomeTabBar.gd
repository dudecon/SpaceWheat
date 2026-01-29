class_name BiomeTabBar
extends HBoxContainer

## BiomeTabBar - Top bar showing biome tabs for switching between biomes
##
## Displays tabs for all biomes with the active one highlighted.
## Click a tab to switch biomes. Shows keyboard shortcuts (UIOP).
## Connects to ActiveBiomeManager for state synchronization.

# Access autoload safely
@onready var _verbose = get_node("/root/VerboseConfig")

# Fixed key slots (TYUIOP). Biomes are assigned as they are unlocked.
const SLOT_KEYS: Array[String] = ["T", "Y", "U", "I", "O", "P"]

# Biome display names (more user-friendly)
const BIOME_LABELS: Dictionary = {
	"StarterForest": "Starter Forest",
	"Village": "Village",
	"BioticFlux": "Quantum Fields",
	"StellarForges": "Stellar Forges",
	"FungalNetworks": "Fungal Networks",
	"VolcanicWorlds": "Volcanic Worlds",
}

# Tab buttons (slot indexed)
var slot_buttons: Array = []  # index -> Button
var active_biome_manager: Node = null

# Colors
const ACTIVE_COLOR = Color(0.3, 0.7, 1.0, 1.0)  # Bright blue for active
const INACTIVE_COLOR = Color(0.5, 0.5, 0.5, 0.8)  # Gray for inactive
const HOVER_COLOR = Color(0.4, 0.6, 0.9, 1.0)  # Lighter blue on hover


func _ready() -> void:
	# Configure container
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)

	# Set size hints for proper layout
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(0, 40)

	# Create tab buttons for each slot (T/Y/U/I/O/P)
	for slot_idx in range(SLOT_KEYS.size()):
		var button = _create_tab_button(slot_idx)
		add_child(button)
		slot_buttons.append(button)

	# Connect to ActiveBiomeManager (with guard to prevent duplicate connections)
	active_biome_manager = get_node_or_null("/root/ActiveBiomeManager")
	if active_biome_manager:
		if not active_biome_manager.active_biome_changed.is_connected(_on_active_biome_changed):
			active_biome_manager.active_biome_changed.connect(_on_active_biome_changed)
			_verbose.info("ui", "📡", "BiomeTabBar connected to ActiveBiomeManager")
		if active_biome_manager.has_signal("biome_order_changed"):
			if not active_biome_manager.biome_order_changed.is_connected(_on_biome_order_changed):
				active_biome_manager.biome_order_changed.connect(_on_biome_order_changed)
		# Defer setting initial state (wait for ActiveBiomeManager to sync with ObservationFrame)
		call_deferred("_set_initial_tab_state")
	else:
		_verbose.warn("ui", "⚠️", "BiomeTabBar: ActiveBiomeManager not found")
		# Default to StarterForest (matches ObservationFrame initial state)
		_refresh_slot_labels()
		_update_tab_states("StarterForest")


func _create_tab_button(slot_idx: int) -> Button:
	"""Create a tab button for a slot (T/Y/U/I/O/P)."""
	var button = Button.new()
	button.name = "BiomeSlot_%d" % slot_idx
	button.set_meta("slot_idx", slot_idx)

	# Style
	button.flat = true
	button.custom_minimum_size = Vector2(140, 32)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Connect click handler
	button.pressed.connect(_on_slot_pressed.bind(slot_idx))
	button.mouse_entered.connect(_on_slot_hover.bind(slot_idx, true))
	button.mouse_exited.connect(_on_slot_hover.bind(slot_idx, false))

	return button


func _on_slot_pressed(slot_idx: int) -> void:
	"""Handle tab click - switch to biome for a slot."""
	if active_biome_manager:
		var biome_name = active_biome_manager.get_biome_for_slot(slot_idx)
		if biome_name == "":
			return
		# Calculate direction for transition animation
		var current_idx = active_biome_manager.get_biome_index(active_biome_manager.get_active_biome())
		var target_idx = active_biome_manager.get_biome_index(biome_name)
		var direction = 1 if target_idx > current_idx else -1 if target_idx < current_idx else 0

		active_biome_manager.set_active_biome(biome_name, direction)
		_verbose.debug("ui", "🖱️", "BiomeTabBar: Clicked %s (direction=%d)" % [biome_name, direction])


func _on_slot_hover(slot_idx: int, is_hovering: bool) -> void:
	"""Handle tab hover for visual feedback"""
	if slot_idx < 0 or slot_idx >= slot_buttons.size():
		return
	var button = slot_buttons[slot_idx]
	if not button:
		return

	# Don't change color of active tab
	var biome_name = active_biome_manager.get_biome_for_slot(slot_idx) if active_biome_manager else ""
	if active_biome_manager and biome_name != "" and biome_name == active_biome_manager.get_active_biome():
		return

	if is_hovering:
		button.add_theme_color_override("font_color", HOVER_COLOR)
	else:
		button.add_theme_color_override("font_color", INACTIVE_COLOR)


func _set_initial_tab_state() -> void:
	"""Deferred call to set initial tab state after ActiveBiomeManager syncs with ObservationFrame"""
	if active_biome_manager:
		_refresh_slot_labels()
		_update_tab_states(active_biome_manager.get_active_biome())


func _on_active_biome_changed(new_biome: String, _old_biome: String) -> void:
	"""Handle biome change - update tab visuals"""
	_update_tab_states(new_biome)


func _on_biome_order_changed(_new_order: Array) -> void:
	"""Handle biome order changes - refresh slot labels."""
	_refresh_slot_labels()
	if active_biome_manager:
		_update_tab_states(active_biome_manager.get_active_biome())


func _update_tab_states(active_biome: String) -> void:
	"""Update all tab buttons to reflect active state"""
	for slot_idx in range(slot_buttons.size()):
		var button = slot_buttons[slot_idx]
		if not button:
			continue
		var biome_name = active_biome_manager.get_biome_for_slot(slot_idx) if active_biome_manager else ""
		var is_active = (biome_name != "" and biome_name == active_biome)

		if is_active:
			button.add_theme_color_override("font_color", ACTIVE_COLOR)
			button.add_theme_font_size_override("font_size", 16)
			# Add underline effect using stylebox
			var style = StyleBoxFlat.new()
			style.bg_color = Color(ACTIVE_COLOR, 0.2)
			style.border_color = ACTIVE_COLOR
			style.set_border_width_all(0)
			style.border_width_bottom = 2
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", style)
			button.add_theme_stylebox_override("pressed", style)
		else:
			button.add_theme_color_override("font_color", INACTIVE_COLOR)
			button.add_theme_font_size_override("font_size", 14)
			# Clear underline
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")
			button.remove_theme_stylebox_override("pressed")

		# Disable unassigned slots
		button.disabled = (biome_name == "")


func _refresh_slot_labels() -> void:
	"""Update button labels to reflect assigned/unassigned biomes."""
	for slot_idx in range(slot_buttons.size()):
		var button = slot_buttons[slot_idx]
		if not button:
			continue
		var slot_key = SLOT_KEYS[slot_idx] if slot_idx < SLOT_KEYS.size() else ""
		var biome_name = active_biome_manager.get_biome_for_slot(slot_idx) if active_biome_manager else ""
		if biome_name == "":
			button.text = "Unassigned [%s]" % slot_key
			button.add_theme_color_override("font_color", INACTIVE_COLOR)
		else:
			var label = BIOME_LABELS.get(biome_name, biome_name)
			button.text = "%s [%s]" % [label, slot_key]


func get_current_biome() -> String:
	"""Get the currently active biome"""
	if active_biome_manager:
		return active_biome_manager.get_active_biome()
	return "BioticFlux"
