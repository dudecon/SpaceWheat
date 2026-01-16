class_name ResourcePanel
extends HBoxContainer

## ResourcePanel - Displays game resources dynamically
## Uses universal resource_changed signal from FarmEconomy
## Shows all emoji resources with their quantum unit values
## Supports arbitrary resources via emoji keys - no hardcoding needed!

const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")

# Layout manager reference (for dynamic scaling)
var layout_manager: Node  # Will be UILayoutManager instance

# Dynamic resource displays: emoji -> {container, label}
var resource_displays: Dictionary = {}

# Container for all resource displays
var resources_hbox: HBoxContainer

# Economy reference for initialization
var economy_ref: Node = null

# Priority order for resources (displayed first, in this order)
const PRIORITY_EMOJIS = ["🌾", "👥", "💨", "🍄", "🍂", "💰", "👑", "🌻"]


func _ready():
	_create_ui()


func set_layout_manager(manager: Node):
	"""Set the layout manager reference for dynamic scaling"""
	layout_manager = manager


func connect_to_economy(economy: Node) -> void:
	"""Connect to economy's universal resource_changed signal

	This is the ONLY way ResourcePanel gets data - directly from the simulation engine.
	Graphics layer (ResourcePanel) does NOT store state, only displays it.
	"""
	if not economy:
		print("⚠️  ResourcePanel: economy is null, cannot connect signals")
		return

	economy_ref = economy

	# Connect to universal resource_changed signal
	if economy.has_signal("resource_changed"):
		economy.resource_changed.connect(_on_resource_changed)
		print("✅ ResourcePanel connected to economy.resource_changed (universal)")

	# Initialize displays with current values
	if economy.has_method("get_resource") and "emoji_credits" in economy:
		for emoji in economy.emoji_credits.keys():
			var units = economy.get_resource_units(emoji)
			_ensure_display_exists(emoji)
			_update_display(emoji, units)

		# Sort displays by priority then amount
		_sort_displays()


func _on_resource_changed(emoji: String, credits_amount: int) -> void:
	"""Handle universal resource_changed signal from economy"""
	_ensure_display_exists(emoji)

	# Convert credits to quantum units for display
	var units = credits_amount / EconomyConstants.QUANTUM_TO_CREDITS
	_update_display(emoji, units)


func _ensure_display_exists(emoji: String) -> void:
	"""Ensure a display exists for this emoji resource"""
	if resource_displays.has(emoji):
		return

	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
	var icon_font_size = layout_manager.get_scaled_font_size(24) if layout_manager else 24
	var label_font_size = layout_manager.get_scaled_font_size(20) if layout_manager else 20

	# Create container for this resource
	var container = HBoxContainer.new()

	var icon = Label.new()
	icon.text = emoji
	icon.add_theme_font_size_override("font_size", icon_font_size)
	container.add_child(icon)

	var value_label = Label.new()
	value_label.text = "0"
	value_label.add_theme_font_size_override("font_size", label_font_size)
	container.add_child(value_label)

	resources_hbox.add_child(container)
	resource_displays[emoji] = {"container": container, "label": value_label}


func _update_display(emoji: String, units: int) -> void:
	"""Update the display for an emoji resource"""
	if not resource_displays.has(emoji):
		return

	resource_displays[emoji]["label"].text = str(units)


func _sort_displays() -> void:
	"""Sort resource displays: priority emojis first, then by amount"""
	if not resources_hbox:
		return

	# Get all emojis and their sort keys
	var sort_data = []
	for emoji in resource_displays.keys():
		var priority = PRIORITY_EMOJIS.find(emoji)
		if priority == -1:
			priority = 100  # Non-priority items go last

		var units = 0
		if economy_ref and economy_ref.has_method("get_resource_units"):
			units = economy_ref.get_resource_units(emoji)

		sort_data.append({
			"emoji": emoji,
			"priority": priority,
			"units": units,
			"container": resource_displays[emoji]["container"]
		})

	# Sort by priority, then by units (descending)
	sort_data.sort_custom(func(a, b):
		if a["priority"] != b["priority"]:
			return a["priority"] < b["priority"]
		return a["units"] > b["units"]
	)

	# Reorder children
	for i in range(sort_data.size()):
		var container = sort_data[i]["container"]
		resources_hbox.move_child(container, i)


func _create_ui():
	# Get scale factor from layout manager (or default to 1.0 if not set)
	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
	var resource_spacing = int(15 * scale_factor)
	var main_spacing = int(20 * scale_factor)

	add_theme_constant_override("separation", main_spacing)

	# Create container for all resource displays
	resources_hbox = HBoxContainer.new()
	resources_hbox.add_theme_constant_override("separation", resource_spacing)
	add_child(resources_hbox)

	# Note: Individual resource displays are created dynamically
	# when connect_to_economy() is called or when resources change


# Legacy compatibility methods (for code that still uses them)

func update_sun_moon(is_sun: bool, time_remaining: float):
	"""Legacy - sun/moon display moved to BiomeInfoDisplay"""
	pass


func update_biome_info(temperature: float, energy_strength: float = -1.0):
	"""Legacy - biome info display moved to BiomeInfoDisplay"""
	pass


func update_tribute_timer(seconds: float, warn_level: int = 0):
	"""Legacy - tribute timer moved to dedicated UI"""
	pass
