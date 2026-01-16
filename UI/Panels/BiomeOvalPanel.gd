class_name BiomeOvalPanel
extends PanelContainer

## Biome Oval Panel
## Displays comprehensive biome information in oval overlay
## Contains emoji grid, stats, and projection details

signal close_requested
signal emoji_tapped(emoji: String)

const EmojiGridDisplay = preload("res://UI/Panels/EmojiGridDisplay.gd")
const BiomeInspectionController = preload("res://Core/Visualization/BiomeInspectionController.gd")

# UI References
var title_bar: HBoxContainer
var biome_name_label: Label
var stats_label: Label
var emoji_grid: EmojiGridDisplay
var projection_list: VBoxContainer
var close_button: Button

# Data
var biome: Node = null
var farm_grid: Node = null
var biome_data: Dictionary = {}

# Visual settings
var panel_width: int = 400
var panel_height: int = 500
var bg_color: Color = Color(0.1, 0.1, 0.1, 0.95)
var border_color: Color = Color(0.3, 0.6, 0.8, 1.0)
var corner_radius: int = 30

func _ready():
	_setup_panel_style()
	_build_ui()
	custom_minimum_size = Vector2(panel_width, panel_height)


## Initialize with biome and grid
func initialize(biome_node: Node, grid_node: Node) -> void:
	"""Set biome to inspect and refresh display"""
	biome = biome_node
	farm_grid = grid_node
	refresh_data()


## Refresh all data from biome
func refresh_data() -> void:
	"""Query biome and update all UI elements"""
	if not biome or not farm_grid:
		print("⚠️  BiomeOvalPanel: Cannot refresh - biome or grid is null")
		return

	# Get data from controller
	biome_data = BiomeInspectionController.get_biome_data(biome, farm_grid)

	# Update UI
	_update_title_bar()
	_update_emoji_grid()
	_update_stats()
	_update_projection_list()


# ============================================================================
# UI SETUP
# ============================================================================

func _setup_panel_style() -> void:
	"""Configure panel appearance (oval/rounded rectangle)"""
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	# Rounded corners (oval effect)
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius

	add_theme_stylebox_override("panel", style)


func _build_ui() -> void:
	"""Construct UI hierarchy"""

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	add_child(main_vbox)

	# Title bar
	title_bar = _create_title_bar()
	main_vbox.add_child(title_bar)

	# Stats summary
	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	main_vbox.add_child(stats_label)

	# Section: Emoji Bath
	var emoji_section_label = Label.new()
	emoji_section_label.text = "EMOJI BATH"
	emoji_section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_section_label.add_theme_font_size_override("font_size", 12)
	emoji_section_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	main_vbox.add_child(emoji_section_label)

	# Emoji grid
	emoji_grid = EmojiGridDisplay.new()
	emoji_grid.emoji_tapped.connect(_on_emoji_tapped)
	main_vbox.add_child(emoji_grid)

	# Separator
	var separator = HSeparator.new()
	main_vbox.add_child(separator)

	# Section: Active Projections
	var proj_section_label = Label.new()
	proj_section_label.text = "ACTIVE PROJECTIONS"
	proj_section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	proj_section_label.add_theme_font_size_override("font_size", 12)
	proj_section_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	main_vbox.add_child(proj_section_label)

	# Projection list
	projection_list = VBoxContainer.new()
	projection_list.add_theme_constant_override("separation", 4)
	main_vbox.add_child(projection_list)


func _create_title_bar() -> HBoxContainer:
	"""Create top bar with biome name + close button"""
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Biome emoji + name
	biome_name_label = Label.new()
	biome_name_label.text = "🌍 Biome"
	biome_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	biome_name_label.add_theme_font_size_override("font_size", 24)
	biome_name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	biome_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(biome_name_label)

	# Close button
	close_button = Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(40, 40)
	close_button.add_theme_font_size_override("font_size", 32)
	close_button.pressed.connect(_on_close_button_pressed)
	hbox.add_child(close_button)

	return hbox


# ============================================================================
# DATA UPDATE
# ============================================================================

func _update_title_bar() -> void:
	"""Update biome name and emoji"""
	if not biome_name_label:
		return
	var emoji = biome_data.get("emoji", "🌍")
	var bname = biome_data.get("name", "Unknown")
	biome_name_label.text = "%s %s" % [emoji, bname]


func _update_stats() -> void:
	"""Update stats summary line with purity and harvest prediction"""
	if not stats_label:
		return

	var purity = biome_data.get("purity", 0.5)
	var plots = biome_data.get("active_plots", 0)
	var prediction = biome_data.get("harvest_prediction", {})

	# Build compact stats line: Purity % | Harvest prediction | Active plots
	var purity_str = "%.0f%% pure" % (purity * 100)
	var harvest_str = ""

	if prediction.has("top_emoji") and prediction.top_percent > 0:
		harvest_str = "%s %d%%" % [prediction.top_emoji, prediction.top_percent]
		if prediction.has("second_emoji") and prediction.second_percent > 10:
			harvest_str += " / %s %d%%" % [prediction.second_emoji, prediction.second_percent]

	if harvest_str != "":
		stats_label.text = "%s  │  %s  │  %d plots" % [purity_str, harvest_str, plots]
	else:
		stats_label.text = "%s  │  %d plots" % [purity_str, plots]


func _update_emoji_grid() -> void:
	"""Update emoji grid display"""
	if not emoji_grid:
		return
	var raw_states = biome_data.get("emoji_states", [])
	# Convert to typed array for EmojiGridDisplay
	var emoji_states: Array[Dictionary] = []
	for state in raw_states:
		if state is Dictionary:
			emoji_states.append(state)
	emoji_grid.set_emoji_data(emoji_states)


func _update_projection_list() -> void:
	"""Update list of active projections"""
	if not projection_list:
		return

	# Clear existing
	for child in projection_list.get_children():
		child.queue_free()

	# Get projection data
	var projections = BiomeInspectionController.get_active_projections(biome, farm_grid)

	if projections.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No plots planted"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		projection_list.add_child(empty_label)
		return

	# Add projection entries
	for proj_data in projections:
		var entry = _create_projection_entry(proj_data)
		projection_list.add_child(entry)


func _create_projection_entry(proj_data: Dictionary) -> HBoxContainer:
	"""Create single projection entry

	Format: • (x,y): 🌾↔👥 | 0.42⚡
	"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Indicator dot
	var dot_label = Label.new()
	dot_label.text = "•"
	dot_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	hbox.add_child(dot_label)

	# Position
	var pos = proj_data.get("position", Vector2i(0, 0))
	var pos_label = Label.new()
	pos_label.text = "(%d,%d):" % [pos.x, pos.y]
	pos_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(pos_label)

	# North ↔ South emojis
	var north = proj_data.get("north_emoji", "")
	var south = proj_data.get("south_emoji", "")
	var emoji_label = Label.new()
	emoji_label.text = "%s ↔ %s" % [north, south]
	emoji_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(emoji_label)

	# Energy
	var energy = proj_data.get("energy", 0.0)
	var energy_label = Label.new()
	energy_label.text = "│ %.2f⚡" % energy
	energy_label.add_theme_font_size_override("font_size", 14)
	energy_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	hbox.add_child(energy_label)

	return hbox


# ============================================================================
# SIGNALS
# ============================================================================

func _on_close_button_pressed() -> void:
	"""Handle close button tap"""
	print("🔍 BiomeOvalPanel: Close requested")
	close_requested.emit()


func _on_emoji_tapped(emoji: String) -> void:
	"""Forward emoji tap signal"""
	emoji_tapped.emit(emoji)
