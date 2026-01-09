class_name LoggerConfigPanel
extends Control

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = get_node("/root/VerboseConfig")

## Logger Configuration Panel
## Runtime UI for configuring log categories and levels
## Toggle with 'L' key

signal closed()

var background: ColorRect
var menu_panel: PanelContainer
var scroll_container: ScrollContainer
var categories_vbox: VBoxContainer

# Category controls
var category_checkboxes: Dictionary = {}  # category_name -> CheckBox
var category_option_buttons: Dictionary = {}  # category_name -> OptionButton

# Console/file toggles
var console_checkbox: CheckBox
var file_checkbox: CheckBox
var timestamps_checkbox: CheckBox

# Category emojis for display
const CATEGORY_EMOJIS = {
	"ui": "📋",
	"input": "⌨️",
	"quantum": "🔬",
	"farm": "🌾",
	"economy": "💰",
	"biome": "🌍",
	"save": "💾",
	"quest": "📋",
	"boot": "🚀",
	"test": "🧪",
	"perf": "⏱️",
	"network": "🕸️",
}


func _init():
	name = "LoggerConfigPanel"

	# Fill entire screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	layout_mode = 1
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()  # Hidden by default


func _ready():
	"""Build UI after _verbose is available"""
	# Background - semi-transparent black
	background = ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.8)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.layout_mode = 1
	add_child(background)

	# Menu panel - centered, fixed size
	menu_panel = PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(600, 700)
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_top = 0.5
	menu_panel.anchor_bottom = 0.5
	menu_panel.offset_left = -300
	menu_panel.offset_right = 300
	menu_panel.offset_top = -350
	menu_panel.offset_bottom = 350
	menu_panel.layout_mode = 1
	add_child(menu_panel)

	# Main VBox
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	menu_panel.add_child(main_vbox)

	# Title
	var title = Label.new()
	title.text = "📝 Logger Configuration"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	# Output options section
	_create_output_options(main_vbox)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(spacer1)

	# Categories label
	var cat_label = Label.new()
	cat_label.text = "Categories (Enable | Level)"
	cat_label.add_theme_font_size_override("font_size", 18)
	cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(cat_label)

	# Scroll container for categories
	scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(0, 400)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll_container)

	categories_vbox = VBoxContainer.new()
	categories_vbox.add_theme_constant_override("separation", 8)
	scroll_container.add_child(categories_vbox)

	# Create category controls
	_create_category_controls()

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(spacer2)

	# Buttons
	_create_buttons(main_vbox)


func _create_output_options(parent: VBoxContainer):
	"""Create output toggles (console, file, timestamps)"""
	var output_hbox = HBoxContainer.new()
	output_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	output_hbox.add_theme_constant_override("separation", 20)
	parent.add_child(output_hbox)

	# Console output
	console_checkbox = CheckBox.new()
	console_checkbox.text = "Console Output"
	console_checkbox.button_pressed = _verbose.enable_console_output
	console_checkbox.toggled.connect(_on_console_toggled)
	output_hbox.add_child(console_checkbox)

	# File logging
	file_checkbox = CheckBox.new()
	file_checkbox.text = "File Logging"
	file_checkbox.button_pressed = _verbose.enable_file_logging
	file_checkbox.toggled.connect(_on_file_toggled)
	output_hbox.add_child(file_checkbox)

	# Timestamps
	timestamps_checkbox = CheckBox.new()
	timestamps_checkbox.text = "Timestamps"
	timestamps_checkbox.button_pressed = _verbose.show_timestamps
	timestamps_checkbox.toggled.connect(_on_timestamps_toggled)
	output_hbox.add_child(timestamps_checkbox)


func _create_category_controls():
	"""Create checkbox + dropdown for each category"""
	var categories = _verbose.get_all_categories()
	categories.sort()  # Alphabetical order

	for category in categories:
		var row_hbox = HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 10)
		categories_vbox.add_child(row_hbox)

		# Checkbox (enable/disable)
		var checkbox = CheckBox.new()
		checkbox.button_pressed = _verbose.category_enabled.get(category, true)
		checkbox.toggled.connect(func(enabled): _on_category_enabled_changed(category, enabled))
		row_hbox.add_child(checkbox)
		category_checkboxes[category] = checkbox

		# Category label with emoji
		var emoji = CATEGORY_EMOJIS.get(category, "📌")
		var label = Label.new()
		label.text = "%s %s" % [emoji, category.capitalize()]
		label.custom_minimum_size = Vector2(180, 0)
		row_hbox.add_child(label)

		# Log level dropdown
		var option_btn = OptionButton.new()
		option_btn.custom_minimum_size = Vector2(100, 0)

		# Add log level options
		for i in range(_verbose.LogLevel.size()):
			option_btn.add_item(_verbose.LEVEL_NAMES[i])

		# Set current level
		var current_level = _verbose.get_category_level(category)
		option_btn.selected = current_level
		option_btn.item_selected.connect(func(idx): _on_category_level_changed(category, idx))
		row_hbox.add_child(option_btn)
		category_option_buttons[category] = option_btn


func _create_buttons(parent: VBoxContainer):
	"""Create action buttons at bottom"""
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 15)
	parent.add_child(button_hbox)

	# Reset to defaults button
	var reset_btn = Button.new()
	reset_btn.text = "Reset to Defaults"
	reset_btn.custom_minimum_size = Vector2(150, 40)
	reset_btn.pressed.connect(_on_reset_pressed)
	button_hbox.add_child(reset_btn)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close [L / ESC]"
	close_btn.custom_minimum_size = Vector2(150, 40)
	close_btn.pressed.connect(_on_close_pressed)
	button_hbox.add_child(close_btn)


# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_console_toggled(enabled: bool):
	_verbose.enable_console_output = enabled
	print("🔧 Logger: Console output %s" % ("ENABLED" if enabled else "DISABLED"))


func _on_file_toggled(enabled: bool):
	_verbose.enable_file_logging = enabled
	if enabled and not _verbose._log_file:
		_verbose._init_file_logging()
	print("🔧 Logger: File logging %s" % ("ENABLED" if enabled else "DISABLED"))


func _on_timestamps_toggled(enabled: bool):
	_verbose.show_timestamps = enabled
	print("🔧 Logger: Timestamps %s" % ("ENABLED" if enabled else "DISABLED"))


func _on_category_enabled_changed(category: String, enabled: bool):
	_verbose.set_category_enabled(category, enabled)


func _on_category_level_changed(category: String, level_idx: int):
	_verbose.set_category_level(category, level_idx)  # level_idx already matches LogLevel enum values


func _on_reset_pressed():
	"""Reset all categories to default levels"""
	# Reset to defaults
	_verbose.category_levels = {
		"ui": _verbose.LogLevel.INFO,
		"input": _verbose.LogLevel.WARN,
		"quantum": _verbose.LogLevel.INFO,
		"farm": _verbose.LogLevel.INFO,
		"economy": _verbose.LogLevel.INFO,
		"biome": _verbose.LogLevel.WARN,
		"save": _verbose.LogLevel.INFO,
		"quest": _verbose.LogLevel.INFO,
		"boot": _verbose.LogLevel.INFO,
		"test": _verbose.LogLevel.TRACE,
		"perf": _verbose.LogLevel.WARN,
		"network": _verbose.LogLevel.DEBUG,
	}

	# Enable all categories
	for category in _verbose.category_enabled.keys():
		_verbose.category_enabled[category] = true

	# Refresh UI
	_refresh_ui()

	print("🔧 Logger: Reset to default configuration")


func _on_close_pressed():
	hide()
	closed.emit()


func _refresh_ui():
	"""Update UI controls to match current VerboseConfig state"""
	# Update checkboxes and dropdowns
	for category in category_checkboxes.keys():
		var checkbox = category_checkboxes[category]
		checkbox.button_pressed = _verbose.category_enabled.get(category, true)

		var option_btn = category_option_buttons[category]
		option_btn.selected = _verbose.get_category_level(category)

	# Update output toggles
	console_checkbox.button_pressed = _verbose.enable_console_output
	file_checkbox.button_pressed = _verbose.enable_file_logging
	timestamps_checkbox.button_pressed = _verbose.show_timestamps


# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event: InputEvent):
	if not visible:
		return

	# Close on ESC or L key
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_L:
			_on_close_pressed()
			get_viewport().set_input_as_handled()


# ============================================================================
# PUBLIC API
# ============================================================================

func show_panel():
	"""Show the logger config panel"""
	_refresh_ui()
	show()


func hide_panel():
	"""Hide the logger config panel"""
	hide()
	closed.emit()
