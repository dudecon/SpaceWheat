class_name MenuPanelBase
extends Control

## MenuPanelBase - Base class for modal menu panels (EscapeMenu, SaveLoadMenu, etc.)
##
## Provides:
##   - Modal dimmer background
##   - Centered panel with standard styling
##   - Keyboard navigation (UP/DOWN)
##   - Button array management with selection highlight
##   - Optional corner ornamentation
##   - OverlayStackManager integration
##
## Subclasses should:
##   1. Call _setup_menu_panel() in _init()
##   2. Add buttons via add_menu_button()
##   3. Override _on_button_activated(index) for button actions
##   4. Override handle_input() for custom key handling

const UIStyleFactory = preload("res://UI/Core/UIStyleFactory.gd")
const UIOrnamentation = preload("res://UI/Core/UIOrnamentation.gd")

# =============================================================================
# SIGNALS
# =============================================================================

signal menu_opened()
signal menu_closed()
signal button_selected(index: int)
signal button_activated(index: int)

# =============================================================================
# OVERLAY INTERFACE
# =============================================================================

var overlay_name: String = "menu"
var overlay_tier: int = 4000  # Z_TIER_SYSTEM - highest priority

# =============================================================================
# CONFIGURATION (Set before calling _setup_menu_panel)
# =============================================================================

var menu_title: String = "Menu"
var menu_panel_size: Vector2 = Vector2(360, 380)
var menu_border_color: Color = UIStyleFactory.COLOR_PANEL_BORDER
var menu_title_size: int = 28
var use_ornamentation: bool = false  # Disabled - layout issues with PanelContainer
var ornamentation_style: int = UIOrnamentation.Style.CORNERS_ONLY
var ornamentation_tint: Color = UIOrnamentation.TINT_DEFAULT

# =============================================================================
# UI REFERENCES
# =============================================================================

var background: ColorRect
var menu_panel: PanelContainer
var menu_vbox: VBoxContainer
var title_label: Label
var ornaments: Dictionary = {}

# =============================================================================
# BUTTON MANAGEMENT
# =============================================================================

var menu_buttons: Array[Button] = []
var selected_button_index: int = 0

# =============================================================================
# SETUP
# =============================================================================

func _setup_menu_panel() -> void:
	"""Initialize the menu panel UI. Call this in subclass _init() after setting config."""
	# Fill entire screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	layout_mode = 1
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Background dimmer
	background = UIStyleFactory.create_modal_dimmer()
	add_child(background)

	# Centered panel
	menu_panel = UIStyleFactory.create_centered_panel(
		menu_panel_size,
		UIStyleFactory.COLOR_PANEL_BG,
		menu_border_color
	)
	add_child(menu_panel)

	# Main vbox container
	menu_vbox = UIStyleFactory.create_vbox(UIStyleFactory.VBOX_SPACING_NORMAL)
	menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_panel.add_child(menu_vbox)

	# Title
	title_label = UIStyleFactory.create_title_label(menu_title, menu_title_size)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_vbox.add_child(title_label)

	# Apply ornamentation
	if use_ornamentation:
		_apply_ornamentation()

	# Start hidden
	visible = false


func _apply_ornamentation() -> void:
	"""Apply corner ornaments to the menu panel."""
	ornaments = UIOrnamentation.apply_ornamentation(
		menu_panel,
		ornamentation_style,
		UIOrnamentation.CORNER_SIZE_MEDIUM,
		ornamentation_tint
	)


# =============================================================================
# BUTTON MANAGEMENT
# =============================================================================

func add_menu_button(text: String, color: Color, callback: Callable = Callable()) -> Button:
	"""Add a button to the menu.

	Args:
		text: Button text
		color: Button background color
		callback: Optional callback for button press

	Returns the created Button.
	"""
	var btn = UIStyleFactory.create_styled_button(text, color)
	menu_vbox.add_child(btn)
	menu_buttons.append(btn)

	var btn_index = menu_buttons.size() - 1
	btn.pressed.connect(_on_button_pressed.bind(btn_index))

	if callback.is_valid():
		btn.pressed.connect(callback)

	return btn


func add_custom_control(control: Control) -> void:
	"""Add a custom control (slider, separator, etc.) to the menu.

	Custom controls are not part of keyboard navigation.
	"""
	menu_vbox.add_child(control)


func clear_buttons() -> void:
	"""Remove all buttons from the menu."""
	for btn in menu_buttons:
		btn.queue_free()
	menu_buttons.clear()
	selected_button_index = 0


func _on_button_pressed(index: int) -> void:
	"""Internal handler for button presses."""
	button_activated.emit(index)
	_on_button_activated(index)


func _on_button_activated(index: int) -> void:
	"""Override in subclass to handle button activation."""
	pass


# =============================================================================
# KEYBOARD NAVIGATION
# =============================================================================

func _navigate_menu(direction: int) -> void:
	"""Navigate menu selection up (-1) or down (+1)."""
	if menu_buttons.is_empty():
		return

	var old_index = selected_button_index
	selected_button_index = (selected_button_index + direction) % menu_buttons.size()
	if selected_button_index < 0:
		selected_button_index = menu_buttons.size() - 1

	if selected_button_index != old_index:
		_update_button_highlights()
		button_selected.emit(selected_button_index)


func _activate_selected_button() -> void:
	"""Activate the currently selected button."""
	if selected_button_index >= 0 and selected_button_index < menu_buttons.size():
		menu_buttons[selected_button_index].emit_signal("pressed")


func _update_button_highlights() -> void:
	"""Update visual highlight for selected button."""
	for i in range(menu_buttons.size()):
		UIStyleFactory.apply_selection_modulate(menu_buttons[i], i == selected_button_index)


func select_button(index: int) -> void:
	"""Programmatically select a button by index."""
	if index >= 0 and index < menu_buttons.size():
		selected_button_index = index
		_update_button_highlights()
		button_selected.emit(index)


# =============================================================================
# INPUT HANDLING
# =============================================================================

func handle_input(event: InputEvent) -> bool:
	"""Modal input handler - called by OverlayStackManager.

	Override in subclass for custom key handling.
	Returns true if input was consumed.
	"""
	if not visible:
		return false

	if not event is InputEventKey or not event.pressed or event.echo:
		return false

	match event.keycode:
		KEY_ESCAPE:
			close_menu()
			return true
		KEY_UP:
			_navigate_menu(-1)
			return true
		KEY_DOWN:
			_navigate_menu(1)
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_activate_selected_button()
			return true

	return false


# =============================================================================
# SHOW/HIDE
# =============================================================================

func show_menu() -> void:
	"""Show the menu."""
	visible = true
	selected_button_index = 0
	_update_button_highlights()

	if is_inside_tree():
		get_tree().paused = true

	menu_opened.emit()


func close_menu() -> void:
	"""Close the menu."""
	visible = false

	if is_inside_tree():
		get_tree().paused = false

	menu_closed.emit()


# =============================================================================
# OVERLAY STACK INTERFACE
# =============================================================================

func get_overlay_tier() -> int:
	"""Get z-index tier for OverlayStackManager."""
	return overlay_tier


func activate() -> void:
	"""Overlay lifecycle: Called when pushed onto stack."""
	show_menu()


func deactivate() -> void:
	"""Overlay lifecycle: Called when popped from stack."""
	close_menu()


# =============================================================================
# UTILITY
# =============================================================================

func set_title(text: String) -> void:
	"""Update the menu title."""
	menu_title = text
	if title_label:
		title_label.text = text


func get_selected_button() -> Button:
	"""Get the currently selected button."""
	if selected_button_index >= 0 and selected_button_index < menu_buttons.size():
		return menu_buttons[selected_button_index]
	return null
