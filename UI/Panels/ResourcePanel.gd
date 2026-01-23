class_name ResourcePanel
extends HBoxContainer

## ResourcePanel - Displays game resources dynamically with sci-fi styling
## Uses universal resource_changed signal from FarmEconomy
## Shows all emoji resources with their quantum unit values
## Supports arbitrary resources via emoji keys - no hardcoding needed!

const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")

# Layout manager reference (for dynamic scaling)
var layout_manager: Node  # Will be UILayoutManager instance

# Dynamic resource displays: emoji -> {container, label, units, update_order}
var resource_displays: Dictionary = {}

# Container for all resource displays
var resources_hbox: HBoxContainer

# Economy reference for initialization
var economy_ref: Node = null

# Update counter for tie-breaking (most recently updated wins ties)
var update_counter: int = 0


func _ready():
	_create_ui()
	# Connect to resized signal to redraw background when size changes
	resized.connect(queue_redraw)


func _draw():
	"""Draw sci-fi styled background directly on the HBoxContainer."""
	# Dark blue-gray background (semi-transparent for sci-fi look)
	var bg_color = Color(0.1, 0.15, 0.22, 0.9)  # Slightly lighter, more visible
	draw_rect(Rect2(Vector2.ZERO, size), bg_color)

	# Cyan border on bottom for HUD effect
	var border_color = Color(0.3, 0.8, 0.9, 0.6)
	draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), border_color, 2.0)


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

	# Connect to universal resource_changed signal (check if not already connected)
	if economy.has_signal("resource_changed"):
		if not economy.resource_changed.is_connected(_on_resource_changed):
			economy.resource_changed.connect(_on_resource_changed)
			print("✅ ResourcePanel connected to economy.resource_changed (HUD style)")

	# Initialize displays with current values (only show non-zero resources)
	if economy.has_method("get_resource") and "emoji_credits" in economy:
		for emoji in economy.emoji_credits.keys():
			var credits = economy.get_resource(emoji)
			if credits > 0:  # Only show resources with value > 0
				_ensure_display_exists(emoji)
				_update_display(emoji, credits)

		# Sort displays by priority then amount
		_sort_displays()


func _on_resource_changed(emoji: String, credits_amount: int) -> void:
	"""Handle universal resource_changed signal from economy"""
	# Only create display if amount > 0 (hide zero-value resources)
	if credits_amount > 0:
		_ensure_display_exists(emoji)

	# Display credits directly - this matches what's stored in the economy
	# The 10x conversion happens at pop time (quantum → classical)
	_update_display(emoji, credits_amount)

	# Bubble sort this resource to its correct position
	_bubble_sort_resource(emoji)


func _ensure_display_exists(emoji: String) -> void:
	"""Ensure a display exists for this emoji resource"""
	if resource_displays.has(emoji):
		return

	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
	var icon_font_size = layout_manager.get_scaled_font_size(24) if layout_manager else 24
	var label_font_size = layout_manager.get_scaled_font_size(20) if layout_manager else 20

	# Create container for this resource
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var icon = Label.new()
	icon.text = emoji
	icon.add_theme_font_size_override("font_size", icon_font_size)
	container.add_child(icon)

	var value_label = Label.new()
	value_label.text = "0"
	value_label.add_theme_font_size_override("font_size", label_font_size)
	value_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))  # Slight blue tint
	container.add_child(value_label)

	resources_hbox.add_child(container)
	update_counter += 1
	resource_displays[emoji] = {
		"container": container,
		"label": value_label,
		"units": 0,
		"update_order": update_counter
	}


func _update_display(emoji: String, units: int) -> void:
	"""Update the display for an emoji resource"""
	if not resource_displays.has(emoji):
		return

	resource_displays[emoji]["label"].text = str(units)
	resource_displays[emoji]["units"] = units
	update_counter += 1
	resource_displays[emoji]["update_order"] = update_counter

	# Hide resources with 0 credits, show resources with > 0
	var container = resource_displays[emoji]["container"]
	container.visible = (units > 0)


func _sort_displays() -> void:
	"""Sort resource displays by units (descending), ties broken by update_order (most recent first)"""
	if not resources_hbox:
		return

	# Get all emojis and their sort keys
	var sort_data = []
	for emoji in resource_displays.keys():
		var data = resource_displays[emoji]
		sort_data.append({
			"emoji": emoji,
			"units": data["units"],
			"update_order": data["update_order"],
			"container": data["container"]
		})

	# Sort by units (descending), then by update_order (descending for most recent)
	sort_data.sort_custom(func(a, b):
		if a["units"] != b["units"]:
			return a["units"] > b["units"]  # Higher units first
		return a["update_order"] > b["update_order"]  # More recent first for ties
	)

	# Reorder children
	for i in range(sort_data.size()):
		var container = sort_data[i]["container"]
		resources_hbox.move_child(container, i)


func _bubble_sort_resource(emoji: String) -> void:
	"""Bubble sort a single resource to its correct position.

	This is more efficient than full sort - only moves the changed item.
	Sort order: highest units first, ties broken by most recently updated.
	"""
	if not resources_hbox or not resource_displays.has(emoji):
		return

	var container = resource_displays[emoji]["container"]
	var my_units = resource_displays[emoji]["units"]
	var my_order = resource_displays[emoji]["update_order"]
	var current_idx = container.get_index()

	# Bubble up: swap with left neighbor while we should be before them
	while current_idx > 0:
		var left_container = resources_hbox.get_child(current_idx - 1)
		var left_emoji = _find_emoji_for_container(left_container)
		if left_emoji == "":
			break

		var left_data = resource_displays[left_emoji]
		var left_units = left_data["units"]
		var left_order = left_data["update_order"]

		# Should we be before the left neighbor?
		var should_swap = false
		if my_units > left_units:
			should_swap = true
		elif my_units == left_units and my_order > left_order:
			should_swap = true  # Same units, but we're more recent

		if should_swap:
			resources_hbox.move_child(container, current_idx - 1)
			current_idx -= 1
		else:
			break

	# Bubble down: swap with right neighbor while they should be before us
	current_idx = container.get_index()
	var total_children = resources_hbox.get_child_count()

	while current_idx < total_children - 1:
		var right_container = resources_hbox.get_child(current_idx + 1)
		var right_emoji = _find_emoji_for_container(right_container)
		if right_emoji == "":
			break

		var right_data = resource_displays[right_emoji]
		var right_units = right_data["units"]
		var right_order = right_data["update_order"]

		# Should the right neighbor be before us?
		var should_swap = false
		if right_units > my_units:
			should_swap = true
		elif right_units == my_units and right_order > my_order:
			should_swap = true  # Same units, but they're more recent

		if should_swap:
			resources_hbox.move_child(container, current_idx + 1)
			current_idx += 1
		else:
			break


func _find_emoji_for_container(container: Node) -> String:
	"""Find the emoji key for a given container node"""
	for emoji in resource_displays.keys():
		if resource_displays[emoji]["container"] == container:
			return emoji
	return ""


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

	print("🖼️  ResourcePanel initialized with HUD style background")

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
