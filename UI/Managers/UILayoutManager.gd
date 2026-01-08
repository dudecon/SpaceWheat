class_name UILayoutManager
extends Node

## UILayoutManager - Parametric layout system for responsive UI scaling
## Central source of truth for all position, size, and scaling calculations
## Handles viewport resizing, breakpoints, and touch vs mouse adaptation

# Preload GridConfig (Phase 5)
const GridConfig = preload("res://Core/GameState/GridConfig.gd")

# Base resolution for design (all proportions calculated from this)
const BASE_RESOLUTION = Vector2(960, 540)  # Static viewport base resolution

# Layout proportions (percentages of viewport)
const TOP_BAR_HEIGHT_PERCENT = 0.06       # 6% of viewport height
const PLAY_AREA_PERCENT = 0.665           # 66.5% of viewport height (quantum graph center)
var plots_row_height_percent: float = 0.15  # Dynamic: 15% base (recalculated from GridConfig grid height)
const ACTIONS_ROW_HEIGHT_PERCENT = 0.125  # 12.5% action buttons row

# Margins and spacing (as percentages)
const PLAY_AREA_MARGIN_PERCENT = 0.05   # 5% margin inside play area
const PANEL_SPACING_PERCENT = 0.01      # 1% spacing between panels

# Current viewport dimensions (updated on resize)
var viewport_size: Vector2
var scale_factor: float = 1.0
var is_touch_device: bool = false
var grid_config: GridConfig = null  # Grid configuration (Phase 5)

# Calculated layout dimensions (updated when viewport resizes)
var top_bar_height: float
var play_area_rect: Rect2  # x, y, width, height (quantum graph area)
var play_area_inner_rect: Rect2  # After applying margins
var plots_row_rect: Rect2  # PCB-style component placement row
var actions_row_rect: Rect2  # Action buttons row

# Breakpoint-based scaling
enum ScaleBreakpoint { MOBILE, HD, FHD, QHD, UHD_4K }
var current_breakpoint: ScaleBreakpoint

# Signals
signal layout_changed(new_layout: Dictionary)
signal input_mode_changed(is_touch: bool)


func _ready():
	# Detect input mode
	_detect_input_mode()

	# Connect to viewport resize signal
	get_viewport().size_changed.connect(_on_viewport_resize)

	# Initial layout calculation
	_on_viewport_resize()


func _detect_input_mode():
	"""Detect if device supports touch input"""
	is_touch_device = OS.has_feature("touchscreen")

	# Additional detection for HTML5 export
	if OS.get_name() == "HTML5":
		# For web, check user agent
		is_touch_device = is_touch_device or _detect_mobile_browser()

	print("UILayoutManager: Input mode detected - %s" % ("TOUCH" if is_touch_device else "MOUSE"))
	input_mode_changed.emit(is_touch_device)


func _detect_mobile_browser() -> bool:
	"""Check if running in mobile browser (HTML5 export)"""
	if OS.get_name() != "HTML5":
		return false

	# Note: JavaScript.eval requires careful handling
	# For now, rely on OS.has_touchscreen_ui_hint()
	return false


func inject_grid_config(config: GridConfig) -> void:
	"""Inject GridConfig for dynamic layout sizing (Phase 5)"""
	if not config:
		push_error("UILayoutManager: Attempted to inject null GridConfig!")
		return

	grid_config = config
	_recalculate_layout_percentages()
	print("💉 GridConfig injected into UILayoutManager")


func _recalculate_layout_percentages() -> void:
	"""Recalculate layout percentages based on grid height (Phase 5)"""
	if not grid_config:
		return

	# Base: 15% per row, with 10% spacing multiplier
	var base_per_row = 0.15
	var spacing_multiplier = 1.1
	plots_row_height_percent = base_per_row * grid_config.grid_height * spacing_multiplier

	# Cap at 35% max (don't let plots dominate screen)
	plots_row_height_percent = min(plots_row_height_percent, 0.35)

	print("📐 Plots row height recalculated: %.1f%% (grid: %d rows)" %
		[plots_row_height_percent * 100, grid_config.grid_height])


func _on_viewport_resize():
	"""Called when viewport size changes"""
	viewport_size = get_viewport().get_visible_rect().size  # Logical viewport (960×540 with canvas_items)
	_calculate_scale_factor()
	_calculate_layout_dimensions()
	_emit_layout_change()


func _calculate_scale_factor():
	"""Calculate scale factor and determine breakpoint"""
	var width_scale = viewport_size.x / BASE_RESOLUTION.x
	var height_scale = viewport_size.y / BASE_RESOLUTION.y
	var raw_scale = min(width_scale, height_scale)

	# Snap to breakpoints for consistent experience
	if raw_scale >= 1.8:
		scale_factor = 2.0
		current_breakpoint = ScaleBreakpoint.UHD_4K
	elif raw_scale >= 1.25:
		scale_factor = 1.5
		current_breakpoint = ScaleBreakpoint.QHD
	elif raw_scale >= 0.9:
		scale_factor = 1.0
		current_breakpoint = ScaleBreakpoint.FHD
	elif raw_scale >= 0.6:
		scale_factor = 0.75
		current_breakpoint = ScaleBreakpoint.HD
	else:
		scale_factor = 0.6
		current_breakpoint = ScaleBreakpoint.MOBILE

	# On touch devices, never scale down below 1.0 for readability
	if is_touch_device and scale_factor < 1.0:
		scale_factor = 1.0

	print("UILayoutManager: Viewport=%s, Scale=%.2f×, Breakpoint=%s" % [
		viewport_size, scale_factor, ScaleBreakpoint.keys()[current_breakpoint]
	])


func _calculate_layout_dimensions():
	"""Calculate all layout dimensions based on current viewport and scale factor"""
	# Recalculate if grid config changed
	if grid_config:
		_recalculate_layout_percentages()

	# Top bar (anchored to top, full width)
	top_bar_height = viewport_size.y * TOP_BAR_HEIGHT_PERCENT

	# Play area (center section between top and bottom rows)
	var play_area_y = top_bar_height
	var play_area_height = viewport_size.y * PLAY_AREA_PERCENT
	play_area_rect = Rect2(0, play_area_y, viewport_size.x, play_area_height)

	# Play area inner rect (after applying margins)
	var margin = play_area_rect.size.length() * PLAY_AREA_MARGIN_PERCENT
	play_area_inner_rect = Rect2(
		play_area_rect.position + Vector2(margin, margin),
		play_area_rect.size - Vector2(margin * 2, margin * 2)
	)

	# Plots row (PCB-style component placement) - below play area - DYNAMIC HEIGHT
	var plots_row_height = viewport_size.y * plots_row_height_percent
	var plots_row_y = play_area_y + play_area_height
	plots_row_rect = Rect2(0, plots_row_y, viewport_size.x, plots_row_height)

	# Actions row - below plots row
	var actions_row_height = viewport_size.y * ACTIONS_ROW_HEIGHT_PERCENT
	var actions_row_y = plots_row_y + plots_row_height
	actions_row_rect = Rect2(0, actions_row_y, viewport_size.x, actions_row_height)

	# DEBUG: Verify layout fits within viewport
	print("📐 Layout breakdown (parametric):")
	print("  Top bar: %.1fpx (0%% to %d%%)" % [top_bar_height, int(TOP_BAR_HEIGHT_PERCENT * 100)])
	print("  Play area: %.1fpx (%d%% to %d%%)" % [play_area_height, int(TOP_BAR_HEIGHT_PERCENT * 100), int((TOP_BAR_HEIGHT_PERCENT + PLAY_AREA_PERCENT) * 100)])
	print("  Plots row: %.1fpx (%d%% to %d%%)" % [plots_row_height, int((TOP_BAR_HEIGHT_PERCENT + PLAY_AREA_PERCENT) * 100), int((TOP_BAR_HEIGHT_PERCENT + PLAY_AREA_PERCENT + plots_row_height_percent) * 100)])
	print("  Actions row: %.1fpx (%d%% to 100%%)" % [actions_row_height, int((TOP_BAR_HEIGHT_PERCENT + PLAY_AREA_PERCENT + plots_row_height_percent) * 100)])
	print("  Total: %.1fpx (should equal viewport height: %.1fpx)" % [top_bar_height + play_area_height + plots_row_height + actions_row_height, viewport_size.y])


func _emit_layout_change():
	"""Emit layout change signal with complete layout data"""
	layout_changed.emit({
		"viewport_size": viewport_size,
		"scale_factor": scale_factor,
		"top_bar_height": top_bar_height,
		"play_area": play_area_rect,
		"play_area_inner": play_area_inner_rect,
		"plots_row": plots_row_rect,
		"actions_row": actions_row_rect,
		"breakpoint": current_breakpoint
	})


## Public API: Position Calculation Functions

func get_scaled_size(base_size: Vector2) -> Vector2:
	"""Scale a size vector by current scale factor"""
	return base_size * scale_factor


func get_scaled_font_size(base_size: int) -> int:
	"""Scale font size with cap at 1.5× to maintain readability

	Args:
		base_size: Base font size in pixels (at 1920×1080)

	Returns:
		Scaled font size, capped at 1.5× to prevent text overflow
	"""
	var font_scale = min(scale_factor, 1.5)
	return int(base_size * font_scale)


func get_perimeter_position(index: int, total: int) -> Vector2:
	"""Calculate position for plot tiles around play area perimeter

	Distributes items evenly around the inner rectangular boundary of play area.
	Starts at top-left corner and goes: top → right → bottom → left

	Args:
		index: Which item this is (0 to total-1)
		total: Total number of items to distribute

	Returns:
		Position for this item in play area coordinates
	"""
	var inner_rect = play_area_inner_rect
	var perimeter_length = (inner_rect.size.x + inner_rect.size.y) * 2
	var segment_length = perimeter_length / total
	var distance = index * segment_length

	# Distribute around rectangle perimeter (top, right, bottom, left)
	if distance < inner_rect.size.x:
		# Top edge (left to right)
		return Vector2(inner_rect.position.x + distance, inner_rect.position.y)
	elif distance < inner_rect.size.x + inner_rect.size.y:
		# Right edge (top to bottom)
		var offset = distance - inner_rect.size.x
		return Vector2(inner_rect.position.x + inner_rect.size.x, inner_rect.position.y + offset)
	elif distance < inner_rect.size.x * 2 + inner_rect.size.y:
		# Bottom edge (right to left)
		var offset = distance - (inner_rect.size.x + inner_rect.size.y)
		return Vector2(inner_rect.position.x + inner_rect.size.x - offset, inner_rect.position.y + inner_rect.size.y)
	else:
		# Left edge (bottom to top)
		var offset = distance - (inner_rect.size.x * 2 + inner_rect.size.y)
		return Vector2(inner_rect.position.x, inner_rect.position.y + inner_rect.size.y - offset)


func get_play_area_center() -> Vector2:
	"""Get center point of play area (for quantum graph positioning)"""
	return play_area_rect.position + play_area_rect.size / 2


func anchor_to_corner(corner: String, offset: Vector2) -> Vector2:
	"""Position element relative to screen corner with scaled offset

	Args:
		corner: One of "top_left", "top_right", "bottom_left", "bottom_right"
		offset: Offset from corner (will be scaled by scale_factor)

	Returns:
		Absolute screen position for the element
	"""
	var scaled_offset = offset * scale_factor
	match corner:
		"top_left":
			return scaled_offset
		"top_right":
			return Vector2(viewport_size.x - scaled_offset.x, scaled_offset.y)
		"bottom_left":
			return Vector2(scaled_offset.x, viewport_size.y - scaled_offset.y)
		"bottom_right":
			return viewport_size - scaled_offset
		_:
			push_error("UILayoutManager: Invalid corner '%s'" % corner)
			return Vector2.ZERO


func anchor_to_edge(edge: String, offset_from_edge: float, position_along_edge: float) -> Vector2:
	"""Position element along screen edge

	Args:
		edge: One of "top", "right", "bottom", "left"
		offset_from_edge: Distance from edge (will be scaled)
		position_along_edge: 0.0-1.0 position along the edge (0=start, 1=end)

	Returns:
		Absolute screen position for the element
	"""
	var scaled_offset = offset_from_edge * scale_factor
	match edge:
		"top":
			return Vector2(viewport_size.x * position_along_edge, scaled_offset)
		"right":
			return Vector2(viewport_size.x - scaled_offset, viewport_size.y * position_along_edge)
		"bottom":
			return Vector2(viewport_size.x * position_along_edge, viewport_size.y - scaled_offset)
		"left":
			return Vector2(scaled_offset, viewport_size.y * position_along_edge)
		_:
			push_error("UILayoutManager: Invalid edge '%s'" % edge)
			return Vector2.ZERO


func get_debug_info() -> Dictionary:
	"""Return debug information about current layout state"""
	return {
		"viewport_size": viewport_size,
		"scale_factor": scale_factor,
		"breakpoint": ScaleBreakpoint.keys()[current_breakpoint],
		"is_touch": is_touch_device,
		"top_bar_height": top_bar_height,
		"play_area_size": play_area_rect.size,
		"play_area_inner_size": play_area_inner_rect.size,
		"plots_row_size": plots_row_rect.size,
		"actions_row_size": actions_row_rect.size,
	}
