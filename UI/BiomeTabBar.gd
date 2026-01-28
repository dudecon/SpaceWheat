class_name BiomeTabBar
extends HBoxContainer

## BiomeTabBar - Top bar showing biome tabs for switching between biomes
##
## Displays tabs for all biomes with the active one highlighted.
## Click a tab to switch biomes. Shows keyboard shortcuts (UIOP).
## Connects to ActiveBiomeManager for state synchronization.

# Access autoload safely
@onready var _verbose = get_node("/root/VerboseConfig")

# Biome order and keyboard shortcuts (TYUIOP)
const BIOME_ORDER: Array[String] = ["StarterForest", "Village", "BioticFlux", "StellarForges", "FungalNetworks", "VolcanicWorlds"]
const BIOME_SHORTCUTS: Dictionary = {
	"StarterForest": "T",
	"Village": "Y",
	"BioticFlux": "U",
	"StellarForges": "I",
	"FungalNetworks": "O",
	"VolcanicWorlds": "P",
}

# Biome display names (more user-friendly)
const BIOME_LABELS: Dictionary = {
	"StarterForest": "Starter Forest",
	"Village": "Village",
	"BioticFlux": "Quantum Fields",
	"StellarForges": "Stellar Forges",
	"FungalNetworks": "Fungal Networks",
	"VolcanicWorlds": "Volcanic Worlds",
}

# Tab buttons
var tab_buttons: Dictionary = {}  # biome_name -> Button
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

	# Create tab buttons for each biome
	for biome_name in BIOME_ORDER:
		var button = _create_tab_button(biome_name)
		add_child(button)
		tab_buttons[biome_name] = button

	# Connect to ActiveBiomeManager (with guard to prevent duplicate connections)
	active_biome_manager = get_node_or_null("/root/ActiveBiomeManager")
	if active_biome_manager:
		if not active_biome_manager.active_biome_changed.is_connected(_on_active_biome_changed):
			active_biome_manager.active_biome_changed.connect(_on_active_biome_changed)
			_verbose.info("ui", "📡", "BiomeTabBar connected to ActiveBiomeManager")
		# Defer setting initial state (wait for ActiveBiomeManager to sync with ObservationFrame)
		call_deferred("_set_initial_tab_state")
	else:
		_verbose.warn("ui", "⚠️", "BiomeTabBar: ActiveBiomeManager not found")
		# Default to StarterForest (matches ObservationFrame initial state)
		_update_tab_states("StarterForest")


func _create_tab_button(biome_name: String) -> Button:
	"""Create a tab button for a biome"""
	var button = Button.new()
	button.name = biome_name + "Tab"

	# Set button text with label and shortcut
	var label = BIOME_LABELS.get(biome_name, biome_name)
	var shortcut = BIOME_SHORTCUTS.get(biome_name, "")
	button.text = "%s [%s]" % [label, shortcut]

	# Style
	button.flat = true
	button.custom_minimum_size = Vector2(140, 32)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Connect click handler
	button.pressed.connect(_on_tab_pressed.bind(biome_name))
	button.mouse_entered.connect(_on_tab_hover.bind(biome_name, true))
	button.mouse_exited.connect(_on_tab_hover.bind(biome_name, false))

	return button


func _on_tab_pressed(biome_name: String) -> void:
	"""Handle tab click - switch to biome"""
	if active_biome_manager:
		# Calculate direction for transition animation
		var current_idx = BIOME_ORDER.find(active_biome_manager.get_active_biome())
		var target_idx = BIOME_ORDER.find(biome_name)
		var direction = 1 if target_idx > current_idx else -1 if target_idx < current_idx else 0

		active_biome_manager.set_active_biome(biome_name, direction)
		_verbose.debug("ui", "🖱️", "BiomeTabBar: Clicked %s (direction=%d)" % [biome_name, direction])


func _on_tab_hover(biome_name: String, is_hovering: bool) -> void:
	"""Handle tab hover for visual feedback"""
	var button = tab_buttons.get(biome_name)
	if not button:
		return

	# Don't change color of active tab
	if active_biome_manager and biome_name == active_biome_manager.get_active_biome():
		return

	if is_hovering:
		button.add_theme_color_override("font_color", HOVER_COLOR)
	else:
		button.add_theme_color_override("font_color", INACTIVE_COLOR)


func _set_initial_tab_state() -> void:
	"""Deferred call to set initial tab state after ActiveBiomeManager syncs with ObservationFrame"""
	if active_biome_manager:
		_update_tab_states(active_biome_manager.get_active_biome())


func _on_active_biome_changed(new_biome: String, _old_biome: String) -> void:
	"""Handle biome change - update tab visuals"""
	_update_tab_states(new_biome)


func _update_tab_states(active_biome: String) -> void:
	"""Update all tab buttons to reflect active state"""
	for biome_name in tab_buttons:
		var button = tab_buttons[biome_name]
		var is_active = (biome_name == active_biome)

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


func get_current_biome() -> String:
	"""Get the currently active biome"""
	if active_biome_manager:
		return active_biome_manager.get_active_biome()
	return "BioticFlux"
