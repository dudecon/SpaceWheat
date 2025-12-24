class_name ResourcePanel
extends HBoxContainer

## ResourcePanel - Displays game resources dynamically
## Top bar showing wheat currency, dynamic resources (sorted by amount)
## Phase 3: Simplified for keyboard-first UI (removed redundant quick-action buttons)
## Supports arbitrary resources via emoji keys - no hardcoding needed!

# Layout manager reference (for dynamic scaling)
var layout_manager: Node  # Will be UILayoutManager instance

# Special labels (always shown)
var wheat_label: Label
var credits_label: Label  # 💵 Classical economy currency
var flour_label: Label  # 💨 Intermediate product for production chain
var sun_moon_label: Label
var biome_label: Label  # 🌍 Temperature/Biome info
var tribute_timer_label: Label

var resources_hbox: HBoxContainer  # Container for all dynamic resources


func _ready():
	_create_ui()


func set_layout_manager(manager: Node):
	"""Set the layout manager reference for dynamic scaling"""
	layout_manager = manager


func connect_to_economy(economy: Node) -> void:
	"""Connect to economy signals for real-time resource updates

	This is the ONLY way ResourcePanel gets data - directly from the simulation engine.
	Graphics layer (ResourcePanel) does NOT store state, only displays it.
	"""
	if not economy:
		print("⚠️  ResourcePanel: economy is null, cannot connect signals")
		return

	# Connect to all economy signals for live updates
	if economy.has_signal("wheat_changed"):
		economy.wheat_changed.connect(_on_wheat_changed)
		print("✅ ResourcePanel connected to economy.wheat_changed")

	if economy.has_signal("credits_changed"):
		economy.credits_changed.connect(_on_credits_changed)
		print("✅ ResourcePanel connected to economy.credits_changed")

	if economy.has_signal("flour_changed"):
		economy.flour_changed.connect(_on_flour_changed)
		print("✅ ResourcePanel connected to economy.flour_changed")

	# Initialize with current values
	wheat_label.text = str(economy.wheat_inventory)
	credits_label.text = str(economy.credits)
	flour_label.text = str(economy.flour_inventory)


## Signal handlers - update display when economy changes
func _on_wheat_changed(new_amount: int) -> void:
	"""Handle wheat_changed signal from economy"""
	wheat_label.text = str(new_amount)


func _on_credits_changed(new_amount: int) -> void:
	"""Handle credits_changed signal from economy"""
	credits_label.text = str(new_amount)


func _on_flour_changed(new_amount: int) -> void:
	"""Handle flour_changed signal from economy"""
	flour_label.text = str(new_amount)


func _create_ui():
	# Get scale factor from layout manager (or default to 1.0 if not set)
	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
	var icon_font_size = layout_manager.get_scaled_font_size(24) if layout_manager else 24
	var label_font_size = layout_manager.get_scaled_font_size(20) if layout_manager else 20
	var small_font_size = layout_manager.get_scaled_font_size(18) if layout_manager else 18
	var button_font_size = layout_manager.get_scaled_font_size(16) if layout_manager else 16

	var main_spacing = int(20 * scale_factor)
	var resource_spacing = int(15 * scale_factor)
	var button_spacing = int(10 * scale_factor)

	add_theme_constant_override("separation", main_spacing)

	# LEFT: Wheat currency + dynamic resources
	resources_hbox = HBoxContainer.new()
	resources_hbox.add_theme_constant_override("separation", resource_spacing)

	# Wheat (primary currency - always shown, special handling)
	var wheat_container = HBoxContainer.new()
	var wheat_icon = Label.new()
	wheat_icon.text = "🌾"
	wheat_icon.add_theme_font_size_override("font_size", icon_font_size)
	wheat_container.add_child(wheat_icon)
	wheat_label = Label.new()
	wheat_label.text = "0"  # Start at 0, will be updated via signals
	wheat_label.add_theme_font_size_override("font_size", label_font_size)
	wheat_container.add_child(wheat_label)
	resources_hbox.add_child(wheat_container)

	# Credits (classical economy - always shown after wheat)
	var credits_container = HBoxContainer.new()
	var credits_icon = Label.new()
	credits_icon.text = "💵"
	credits_icon.add_theme_font_size_override("font_size", icon_font_size)
	credits_container.add_child(credits_icon)
	credits_label = Label.new()
	credits_label.text = "0"  # Start at 0, will be updated via signals
	credits_label.add_theme_font_size_override("font_size", label_font_size)
	credits_container.add_child(credits_label)
	resources_hbox.add_child(credits_container)

	# Flour (intermediate product - always shown after credits)
	var flour_container = HBoxContainer.new()
	var flour_icon = Label.new()
	flour_icon.text = "💨"
	flour_icon.add_theme_font_size_override("font_size", icon_font_size)
	flour_container.add_child(flour_icon)
	flour_label = Label.new()
	flour_label.text = "0"  # Start at 0, will be updated via signals
	flour_label.add_theme_font_size_override("font_size", label_font_size)
	flour_container.add_child(flour_label)
	resources_hbox.add_child(flour_container)

	# Note: Sun/Moon and Biome info moved to BiomeInfoDisplay in farm area
	# These labels are kept for backward compatibility but not displayed

	add_child(resources_hbox)




func update_sun_moon(is_sun: bool, time_remaining: float):
	"""Update sun/moon cycle display"""
	if is_sun:
		sun_moon_label.text = "☀️ Sun"
		sun_moon_label.modulate = Color(1.0, 0.9, 0.5)  # Golden
	else:
		sun_moon_label.text = "🌙 Moon"
		sun_moon_label.modulate = Color(0.7, 0.7, 1.0)  # Bluish

	# Add timer if space available
	if sun_moon_label.text.length() < 20:
		sun_moon_label.text += " (%.0fs)" % time_remaining


func update_biome_info(temperature: float, energy_strength: float = -1.0):
	"""Update biome display (temperature and energy level)

	Args:
		temperature: Current biome temperature (Kelvin)
		energy_strength: Energy level 0.0-1.0 (optional, for color coding)
	"""
	biome_label.text = "🌍 %.0fK" % temperature

	# Color code based on temperature
	if temperature < 250.0:
		biome_label.modulate = Color(0.5, 0.8, 1.0)  # Cool blue
	elif temperature < 300.0:
		biome_label.modulate = Color(0.8, 1.0, 0.8)  # Cool green
	elif temperature < 350.0:
		biome_label.modulate = Color(1.0, 1.0, 0.7)  # Warm yellow
	else:
		biome_label.modulate = Color(1.0, 0.8, 0.5)  # Hot orange


func update_tribute_timer(seconds: float, warn_level: int = 0):
	"""Update tribute timer display

	warn_level:
	  0 = normal (yellow)
	  1 = warning (orange)
	  2 = critical (red)
	"""
	tribute_timer_label.text = "%.0fs" % seconds

	match warn_level:
		0:  # Normal
			tribute_timer_label.modulate = Color(1.0, 1.0, 0.7)
		1:  # Warning
			tribute_timer_label.modulate = Color(1.0, 0.7, 0.3)
		2:  # Critical
			tribute_timer_label.modulate = Color(1.0, 0.3, 0.3)
