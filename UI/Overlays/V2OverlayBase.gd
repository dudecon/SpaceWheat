class_name V2OverlayBase
extends Control

## V2OverlayBase - Base class for v2 overlays with QER remapping and WASD navigation
##
## All v2 overlays extend this class to get:
##   - Unified QER+F key handling with action remapping
##   - WASD navigation between selectable items
##   - Automatic integration with OverlayManager
##   - ActionPreviewRow label updates
##
## Subclasses must override:
##   - on_q_pressed(), on_e_pressed(), on_r_pressed(), on_f_pressed()
##   - get_action_labels() for ActionPreviewRow display
##
## Lifecycle:
##   1. OverlayManager.open_v2_overlay() → activate()
##   2. Input routed to handle_input()
##   3. OverlayManager.close_v2_overlay() → deactivate()

signal overlay_opened()
signal overlay_closed()
signal action_performed(action: String, data: Dictionary)
signal selection_changed(new_index: int)

# ============================================================================
# CONFIGURATION (Override in subclass)
# ============================================================================

## Unique identifier for this overlay (e.g., "inspector", "quests")
var overlay_name: String = "base"

## Emoji icon for sidebar button
var overlay_icon: String = "📋"

## Action labels for QER+F keys (used by ActionPreviewRow)
## Format: {"Q": "Action Label", "E": "Action Label", "R": "Action Label", "F": "Mode Label"}
var action_labels: Dictionary = {
	"Q": "Select",
	"E": "Details",
	"R": "Action",
	"F": "Cycle"
}

## Z-index tier for OverlayStackManager
## Default: Z_TIER_INFO (2000) - subclasses can override
## Options: Z_TIER_INFO (2000), Z_TIER_MODAL (3000), Z_TIER_SYSTEM (4000)
var overlay_tier: int = 2000  # Z_TIER_INFO

# ============================================================================
# NAVIGATION STATE
# ============================================================================

## Currently selected item index (-1 if nothing selected)
var selected_index: int = -1

## List of selectable items (populated by subclass)
## Each item should be a Dictionary with at least {id, position} for WASD nav
var selectable_items: Array = []

## Grid dimensions for WASD navigation (set by subclass)
var grid_columns: int = 1
var grid_rows: int = 1

## Whether overlay is currently active
var is_active: bool = false

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Start hidden - OverlayManager will show when needed
	visible = false

	# Set up default styling
	_setup_default_style()


func activate() -> void:
	"""Called when overlay is opened. Override for custom activation."""
	is_active = true
	visible = true
	selected_index = 0 if not selectable_items.is_empty() else -1
	_update_selection_visual()
	overlay_opened.emit()


func deactivate() -> void:
	"""Called when overlay is closed. Override for custom deactivation."""
	is_active = false
	visible = false
	overlay_closed.emit()


func _setup_default_style() -> void:
	"""Set up default panel styling. Override for custom appearance."""
	# Default: semi-transparent dark background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.border_color = Color(0.3, 0.4, 0.5, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)


# ============================================================================
# INPUT HANDLING
# ============================================================================

func handle_input(event: InputEvent) -> bool:
	"""Handle input when overlay is active. Returns true if consumed.

	Routes QER+F to action methods, WASD to navigation.
	Override for custom input handling.
	"""
	if not is_active:
		return false

	if not event is InputEventKey or not event.pressed:
		return false

	# QER+F action keys
	if event.is_action_pressed("action_q"):
		on_q_pressed()
		return true

	if event.is_action_pressed("action_e"):
		on_e_pressed()
		return true

	if event.is_action_pressed("action_r"):
		on_r_pressed()
		return true

	if event.is_action_pressed("action_f"):
		on_f_pressed()
		return true

	# WASD navigation
	if event.is_action_pressed("move_up"):
		navigate(Vector2i.UP)
		return true

	if event.is_action_pressed("move_down"):
		navigate(Vector2i.DOWN)
		return true

	if event.is_action_pressed("move_left"):
		navigate(Vector2i.LEFT)
		return true

	if event.is_action_pressed("move_right"):
		navigate(Vector2i.RIGHT)
		return true

	# ESC is handled by PlayerShell._handle_shell_action() via overlay_stack.handle_escape()
	# Do NOT consume ESC here - let it fall through so the stack can properly pop this overlay
	# If we consumed ESC here, the overlay would be hidden but remain on the stack
	if event.keycode == KEY_ESCAPE:
		return false  # Let OverlayStackManager.handle_escape() pop us from stack

	return false


# ============================================================================
# ACTION METHODS (Override in subclass)
# ============================================================================

func on_q_pressed() -> void:
	"""Handle Q key press. Override for overlay-specific action."""
	action_performed.emit("q_action", {"selected": selected_index})


func on_e_pressed() -> void:
	"""Handle E key press. Override for overlay-specific action."""
	action_performed.emit("e_action", {"selected": selected_index})


func on_r_pressed() -> void:
	"""Handle R key press. Override for overlay-specific action."""
	action_performed.emit("r_action", {"selected": selected_index})


func on_f_pressed() -> void:
	"""Handle F key press (mode cycling). Override for overlay-specific action."""
	action_performed.emit("f_action", {"selected": selected_index})


# ============================================================================
# NAVIGATION
# ============================================================================

func navigate(direction: Vector2i) -> void:
	"""Navigate selection in WASD direction.

	Uses grid_columns/grid_rows to convert 2D direction to 1D index change.
	"""
	if selectable_items.is_empty():
		return

	var old_index = selected_index
	var new_index = selected_index

	match direction:
		Vector2i.UP:
			new_index = selected_index - grid_columns
		Vector2i.DOWN:
			new_index = selected_index + grid_columns
		Vector2i.LEFT:
			new_index = selected_index - 1
		Vector2i.RIGHT:
			new_index = selected_index + 1

	# Clamp to valid range
	new_index = clampi(new_index, 0, selectable_items.size() - 1)

	if new_index != old_index:
		selected_index = new_index
		_update_selection_visual()
		selection_changed.emit(selected_index)


func select_index(index: int) -> void:
	"""Directly select an item by index."""
	if index >= 0 and index < selectable_items.size():
		selected_index = index
		_update_selection_visual()
		selection_changed.emit(selected_index)


func get_selected_item() -> Variant:
	"""Get currently selected item, or null if nothing selected."""
	if selected_index >= 0 and selected_index < selectable_items.size():
		return selectable_items[selected_index]
	return null


func _update_selection_visual() -> void:
	"""Update visual indication of selection. Override for custom visuals."""
	# Subclasses should implement visual feedback for selection
	pass


# ============================================================================
# ACTION PREVIEW INTEGRATION
# ============================================================================

func get_action_labels() -> Dictionary:
	"""Get current QER+F labels for ActionPreviewRow display.

	Returns: {"Q": "Label", "E": "Label", "R": "Label", "F": "Label"}
	"""
	return action_labels


func set_action_label(key: String, label: String) -> void:
	"""Update a single action label."""
	if key in ["Q", "E", "R", "F"]:
		action_labels[key] = label


# ============================================================================
# SELECTABLE ITEMS MANAGEMENT
# ============================================================================

func set_selectable_items(items: Array, columns: int = 1) -> void:
	"""Set the list of selectable items and grid layout.

	Args:
		items: Array of selectable item data
		columns: Number of columns for WASD grid navigation
	"""
	selectable_items = items
	grid_columns = columns
	grid_rows = ceili(float(items.size()) / columns) if columns > 0 else 1

	# Reset selection to first item
	selected_index = 0 if not items.is_empty() else -1
	_update_selection_visual()


func clear_selectable_items() -> void:
	"""Clear all selectable items."""
	selectable_items = []
	selected_index = -1
	grid_columns = 1
	grid_rows = 1


# ============================================================================
# UTILITY
# ============================================================================

func get_overlay_info() -> Dictionary:
	"""Get overlay metadata for registration."""
	return {
		"name": overlay_name,
		"icon": overlay_icon,
		"action_labels": action_labels,
		"tier": overlay_tier
	}


func get_overlay_tier() -> int:
	"""Get z-index tier for OverlayStackManager."""
	return overlay_tier


func _to_string() -> String:
	return "V2Overlay[%s] (active=%s, selected=%d/%d)" % [
		overlay_name, is_active, selected_index, selectable_items.size()
	]
