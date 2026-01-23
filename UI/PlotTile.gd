class_name PlotTile
extends Control

## PlotTile - Visual representation of a single farm plot
## Part of the emoji lattice grid
## Phase 4: Decoupled from WheatPlot - uses PlotUIData (display snapshots)

signal clicked(grid_position: Vector2i)
signal long_pressed(grid_position: Vector2i)

# Plot data (set by FarmView) - Phase 4: Use PlotUIData instead of WheatPlot
var grid_position: Vector2i = Vector2i.ZERO
var plot_ui_data = null  # FarmUIState.PlotUIData

# Visual state
var is_selected: bool = false
var is_hovered: bool = false
var is_selected_by_keyboard: bool = false  # Phase 3: Track keyboard vs mouse selection
var is_checkbox_selected: bool = false  # NEW: Multi-select checkbox state

# Long press detection
var press_timer: float = 0.0
var is_pressing: bool = false
const LONG_PRESS_TIME = 0.5

# UI elements (will be created in _ready)
var background: ColorRect
var emoji_label_north: Label  # North pole emoji (quantum superposition)
var emoji_label_south: Label  # South pole emoji (quantum superposition)
var growth_bar: ProgressBar
var selection_border: ColorRect
var territory_border: ColorRect  # Shows Icon control
var number_label: Label
var checkbox_label: Label  # NEW: Multi-select checkbox (☐/☑)
var purity_label: Label  # Purity indicator Tr(ρ²) - color-coded quality metric
var center_state_indicator: Control  # Small indicator showing quantum state at plot center
var entanglement_indicator: Control  # Visual ring showing entanglement status
var entanglement_counter: Label  # Shows number of entangled connections

# Colors (backgrounds at 60% transparency = 0.4 alpha, text stays opaque)
const COLOR_EMPTY = Color(0.15, 0.15, 0.15, 0.4)
const COLOR_SELECTED = Color(0.3, 0.6, 0.8, 0.5)  # Slightly more visible when selected
const COLOR_HOVER = Color(0.25, 0.25, 0.25, 0.4)
const COLOR_NATURAL = Color(0.2, 0.8, 0.2, 0.4)  # Green (🌾)
const COLOR_LABOR = Color(0.2, 0.4, 0.8, 0.4)    # Blue (👥)
const COLOR_MATURE = Color(0.9, 0.7, 0.2, 0.4)   # Golden

# Icon territory colors
const COLOR_BIOTIC = Color(0.3, 1.0, 0.3, 0.6)     # Green glow
const COLOR_CHAOS = Color(1.0, 0.3, 0.3, 0.6)      # Red chaos
const COLOR_IMPERIUM = Color(0.8, 0.6, 1.0, 0.6)   # Purple/gold
const COLOR_NEUTRAL = Color(0.3, 0.3, 0.3, 0.3)    # Dim gray

# PCB styling colors
const COLOR_PCB_BASE = Color(0.1, 0.12, 0.15)      # Dark PCB base
const COLOR_PCB_COPPER = Color(0.8, 0.5, 0.1)      # Copper traces
const COLOR_PCB_SOLDER = Color(0.6, 0.6, 0.6)      # Solder pads
const COLOR_PCB_EDGE_LIGHT = Color(0.25, 0.25, 0.25)  # Edge highlight
const COLOR_PCB_EDGE_DARK = Color(0.08, 0.08, 0.08)   # Edge shadow

# Entanglement visualization colors
const COLOR_ENTANGLEMENT_RING = Color(0.0, 1.0, 1.0, 0.8)  # Bright cyan
const COLOR_ENTANGLEMENT_GLOW = Color(0.0, 1.0, 1.0, 0.3)  # Faint cyan glow

# Reference to territory manager (set by FarmView)
var territory_manager = null

# Reference to biome for temperature/energy effects (set by FarmView)
var biome = null


func _ready():
	# Setup visual components FIRST (before setting size, which triggers resize notification)
	_create_ui_elements()

	# Don't set grid position number - let set_label_text() provide keyboard labels only
	# This prevents duplicate label overlap (number_label was showing 0-5 behind TYUIOP)
	number_label.text = ""

	# Now set size properties (this triggers NOTIFICATION_RESIZED, which calls _layout_elements)
	custom_minimum_size = Vector2(80, 80)
	size = Vector2(80, 80)  # Explicit size for input detection
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through to quantum bubbles below

	# Explicitly layout elements since NOTIFICATION_RESIZED may not fire in all cases
	_layout_elements()

	# Update visuals
	set_process(true)


func set_label_text(label: String) -> void:
	"""Set custom label text on the tile (e.g., keyboard shortcut letter)"""
	if number_label:
		number_label.text = label



func _create_ui_elements():
	# Safety check: if elements already exist, DON'T recreate them
	if background != null:
		print("⚠️  WARNING: PlotTile._create_ui_elements() called but background already exists!")
		print("   This suggests elements are being created multiple times!")
		return

	# Background
	background = ColorRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = COLOR_EMPTY  # Set initial color so tiles are visible immediately
	add_child(background)

	# Territory border (shows Icon control)
	territory_border = ColorRect.new()
	territory_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	territory_border.color = COLOR_NEUTRAL
	territory_border.z_index = 1  # Above background
	add_child(territory_border)

	# Selection border
	selection_border = ColorRect.new()
	selection_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_border.color = COLOR_SELECTED
	selection_border.visible = false
	selection_border.z_index = 2  # Above territory border
	add_child(selection_border)

	# Emoji display - DUAL LABEL SYSTEM for quantum superposition
	# North pole emoji (e.g., 🌾 for wheat)
	emoji_label_north = Label.new()
	emoji_label_north.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label_north.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji_label_north.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label_north.add_theme_font_size_override("font_size", 36)
	emoji_label_north.z_index = 3  # Above selection border
	emoji_label_north.set_anchors_preset(Control.PRESET_FULL_RECT)  # Fill parent
	add_child(emoji_label_north)

	# South pole emoji (e.g., 👥 for wheat, 🍂 for mushroom)
	emoji_label_south = Label.new()
	emoji_label_south.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label_south.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji_label_south.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label_south.add_theme_font_size_override("font_size", 36)
	emoji_label_south.z_index = 3  # Same layer as north (overlaid)
	emoji_label_south.set_anchors_preset(Control.PRESET_FULL_RECT)  # Fill parent
	add_child(emoji_label_south)

	# Growth bar
	growth_bar = ProgressBar.new()
	growth_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	growth_bar.show_percentage = false
	growth_bar.visible = false
	add_child(growth_bar)

	# Number label (shows plot index for navigation - Phase 3: Larger for keyboard visibility)
	number_label = Label.new()
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_label.add_theme_font_size_override("font_size", 32)  # Phase 3: Increased from 12
	number_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0, 0.9))  # Phase 3: Bright yellow
	number_label.z_index = 5  # Above all other elements for visibility
	add_child(number_label)

	# Checkbox label (shows multi-select checkbox - NEW)
	checkbox_label = Label.new()
	checkbox_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	checkbox_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	checkbox_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checkbox_label.add_theme_font_size_override("font_size", 32)  # Larger for visibility
	checkbox_label.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0, 1.0))  # Bright cyan
	checkbox_label.text = "☐"  # Empty checkbox by default
	checkbox_label.z_index = 5  # Above all other elements for visibility
	add_child(checkbox_label)

	# Purity indicator (shows Tr(ρ²) in bottom-left corner)
	purity_label = Label.new()
	purity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	purity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	purity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purity_label.add_theme_font_size_override("font_size", 12)
	purity_label.text = ""  # Hidden by default
	purity_label.z_index = 4  # Above most elements
	purity_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(purity_label)

	# Center state indicator (shows quantum state + biome effects at plot center)
	# Use a ColorRect as the visual indicator - small circle-like square in center
	center_state_indicator = ColorRect.new()
	center_state_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_state_indicator.z_index = 4  # Above emojis
	center_state_indicator.color = Color(0.9, 0.9, 0.9, 0.0)  # Initially invisible
	center_state_indicator.custom_minimum_size = Vector2(4, 4)
	add_child(center_state_indicator)

	# Entanglement indicator (glowing ring when plot is entangled)
	entanglement_indicator = Control.new()
	entanglement_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entanglement_indicator.z_index = 2  # Above territory border but below emojis
	entanglement_indicator.custom_minimum_size = size
	entanglement_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(entanglement_indicator)

	# Entanglement counter (shows number of entangled plots in top-right corner)
	entanglement_counter = Label.new()
	entanglement_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	entanglement_counter.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	entanglement_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entanglement_counter.add_theme_font_size_override("font_size", 14)
	entanglement_counter.add_theme_color_override("font_color", COLOR_ENTANGLEMENT_RING)
	entanglement_counter.text = ""
	entanglement_counter.z_index = 4  # Above entanglement indicator
	add_child(entanglement_counter)


func _process(delta):
	# Track long press timer
	if is_pressing:
		press_timer += delta
		if press_timer >= LONG_PRESS_TIME:
			# Long press detected
			print("🖱️ PlotTile LONG PRESS detected at %s" % grid_position)
			long_pressed.emit(grid_position)
			is_pressing = false
			press_timer = 0.0

	_update_visuals()
	queue_redraw()  # Continuously redraw PCB styling and dynamic effects


## REMOVED: _gui_input() was dead code - PlotTile has mouse_filter=IGNORE
## Input is now handled by PlotGridDisplay._input() for plots
## and QuantumForceGraph._unhandled_input() for bubbles


func _update_visuals():
	if plot_ui_data == null:
		_show_empty_state()
		return

	if not plot_ui_data.get("is_planted", false):
		_show_empty_state()
	else:
		# Quantum-only mechanics: plants are instant full size
		# Always show mature state when planted
		_show_mature_state()

	# Update territory border based on Icon control
	_update_territory_border()

	# Update entanglement visualization
	_update_entanglement_display()

	# Update purity indicator
	_update_purity_display()

	# Update selection border
	selection_border.visible = is_selected


func _update_territory_border():
	"""Update territory border color based on Icon control"""
	if not territory_manager:
		territory_border.color = COLOR_NEUTRAL
		return

	var controller = territory_manager.get_plot_controller(grid_position)

	match controller:
		"biotic":
			territory_border.color = COLOR_BIOTIC
		"chaos":
			territory_border.color = COLOR_CHAOS
		"imperium":
			territory_border.color = COLOR_IMPERIUM
		_:
			territory_border.color = COLOR_NEUTRAL


func _show_empty_state():
	emoji_label_north.text = ""
	emoji_label_south.text = ""
	emoji_label_north.modulate.a = 0.0
	emoji_label_south.modulate.a = 0.0
	growth_bar.visible = false
	background.color = COLOR_EMPTY if not is_selected else COLOR_SELECTED

	# Hide center indicator for empty plots
	center_state_indicator.queue_redraw()


func _show_growing_state():
	# Phase 4: PlotUIData doesn't track growth progress
	# Just use _show_mature_state() instead
	_show_mature_state()


func _show_mature_state():
	growth_bar.visible = false

	# Phase 4: Use PlotUIData - no plot_type enum, use string instead
	match plot_ui_data.get("plot_type", ""):
		"tomato":
			emoji_label_north.text = "🍅"
			emoji_label_south.text = ""
			emoji_label_north.modulate.a = 1.0
			emoji_label_south.modulate.a = 0.0
		"mushroom":
			emoji_label_north.text = "🍄"
			emoji_label_south.text = ""
			emoji_label_north.modulate.a = 1.0
			emoji_label_south.modulate.a = 0.0
		"mill":
			emoji_label_north.text = "🏭"
			emoji_label_south.text = ""
			emoji_label_north.modulate.a = 1.0
			emoji_label_south.modulate.a = 0.0
		"market":
			emoji_label_north.text = "💰"
			emoji_label_south.text = ""
			emoji_label_north.modulate.a = 1.0
			emoji_label_south.modulate.a = 0.0
		"fire", "water", "flour":
			# Kitchen ingredients: QUANTUM SUPERPOSITION - dual label with probability-weighted opacity
			if not plot_ui_data.get("has_been_measured", false):
				# Show both emojis with probability-weighted opacity
				emoji_label_north.text = plot_ui_data.get("north_emoji", "")
				emoji_label_south.text = plot_ui_data.get("south_emoji", "")
				emoji_label_north.modulate.a = plot_ui_data.get("north_probability", 0.5)
				emoji_label_south.modulate.a = plot_ui_data.get("south_probability", 0.5)
			else:
				# Measured - show single dominant emoji
				if plot_ui_data.get("north_probability", 0.5) > plot_ui_data.get("south_probability", 0.5):
					emoji_label_north.text = plot_ui_data.get("north_emoji", "")
					emoji_label_south.text = ""
				else:
					emoji_label_north.text = plot_ui_data.get("south_emoji", "")
					emoji_label_south.text = ""
				emoji_label_north.modulate.a = 1.0
				emoji_label_south.modulate.a = 0.0
		_:
			# Wheat: QUANTUM SUPERPOSITION - dual label with probability-weighted opacity
			if not plot_ui_data.get("has_been_measured", false):
				# Show both emojis with probability-weighted opacity
				emoji_label_north.text = plot_ui_data.get("north_emoji", "")
				emoji_label_south.text = plot_ui_data.get("south_emoji", "")
				emoji_label_north.modulate.a = plot_ui_data.get("north_probability", 0.5)
				emoji_label_south.modulate.a = plot_ui_data.get("south_probability", 0.5)
			else:
				# Measured - show single dominant emoji
				# (choose dominant based on which has higher probability)
				if plot_ui_data.get("north_probability", 0.5) > plot_ui_data.get("south_probability", 0.5):
					emoji_label_north.text = plot_ui_data.get("north_emoji", "")
					emoji_label_south.text = ""
				else:
					emoji_label_north.text = plot_ui_data.get("south_emoji", "")
					emoji_label_south.text = ""
				emoji_label_north.modulate.a = 1.0
				emoji_label_south.modulate.a = 0.0

	# Golden glow for mature crops
	var glow_pulse = (sin(Time.get_ticks_msec() * 0.003) + 1.0) / 2.0
	var base_golden = COLOR_MATURE
	background.color = base_golden.lightened(glow_pulse * 0.2)

	# Update center state indicator (shows quantum state + biome effects)
	_update_center_indicator()


func update_tomato_visuals(conspiracy_network):
	"""Update visual state based on conspiracy node data (PROPOSAL B)

	Phase 4: This method is unused in decoupled architecture
	Keeping for backward compatibility but it's not called
	"""
	pass  # Not used with PlotUIData


func _get_temperature_color(normalized_theta: float) -> Color:
	"""Map theta to temperature color (blue → white → red)"""
	if normalized_theta < 0.5:
		# Blue to white (cold to neutral)
		var t = normalized_theta * 2.0
		return Color(0.3, 0.4, 0.8).lerp(Color(0.9, 0.9, 0.9), t)
	else:
		# White to red (neutral to hot)
		var t = (normalized_theta - 0.5) * 2.0
		return Color(0.9, 0.9, 0.9).lerp(Color(0.9, 0.3, 0.2), t)


func set_selected(selected: bool, by_keyboard: bool = false):
	"""Set selection state with optional keyboard indicator

	Args:
		selected: Whether the plot is selected
		by_keyboard: Whether selection was made by keyboard (shows cyan) vs mouse (shows blue)
	"""
	is_selected = selected
	is_selected_by_keyboard = by_keyboard

	if is_selected:
		selection_border.visible = true
		# Phase 3: Different color for keyboard vs mouse selection
		if by_keyboard:
			selection_border.color = Color(0.0, 1.0, 1.0)  # Cyan for keyboard
		else:
			selection_border.color = Color(0.3, 0.6, 0.8)  # Blue for mouse
	else:
		selection_border.visible = false


func set_checkbox_selected(selected: bool) -> void:
	"""Update the multi-select checkbox visual state

	Args:
		selected: Whether the plot is in the multi-select group
	"""
	is_checkbox_selected = selected
	if checkbox_label:
		checkbox_label.text = "☑" if selected else "☐"
		# Change color intensity when selected
		if selected:
			checkbox_label.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0, 1.0))  # Bright cyan
		else:
			checkbox_label.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0, 0.6))  # Dimmed cyan (still visible)


func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_layout_elements()


func _layout_elements():
	# Safety check: UI elements must exist
	if not background or not territory_border or not selection_border or not emoji_label_north or not emoji_label_south or not growth_bar or not number_label or not checkbox_label or not center_state_indicator:
		return

	var rect = get_rect()

	# Background fills entire tile
	background.position = Vector2.ZERO
	background.size = rect.size

	# Territory border (colored glow overlay showing Icon control)
	territory_border.position = Vector2.ZERO
	territory_border.size = rect.size

	# Selection border (inset slightly, shows when selected)
	var border_width = 3
	selection_border.position = Vector2(border_width, border_width)
	selection_border.size = rect.size - Vector2(border_width * 2, border_width * 2)

	# Emoji labels centered and overlaid (for quantum superposition)
	# NOTE: emoji labels have PRESET_FULL_RECT anchors, so they automatically
	# fill the parent. Setting position/size would conflict with anchors.
	# The anchors handle sizing - no manual position/size needed.

	# Growth bar at bottom
	var bar_height = 8
	growth_bar.position = Vector2(4, rect.size.y - bar_height - 4)
	growth_bar.size = Vector2(rect.size.x - 8, bar_height)

	# Number label in top-left corner
	number_label.position = Vector2(4, 2)
	number_label.size = Vector2(30, 20)

	# Checkbox label in top-right corner (NEW - multi-select)
	checkbox_label.position = Vector2(rect.size.x - 35, 0)
	checkbox_label.size = Vector2(35, 32)

	# Center state indicator (will be sized and positioned in _update_center_indicator)
	center_state_indicator.position = Vector2.ZERO
	center_state_indicator.size = rect.size

	queue_redraw()


func _draw():
	"""Draw PCB-style borders, solder pads, traces, and entanglement indicators"""
	var rect = get_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	# Draw PCB-style beveled edge (metallic look)
	_draw_pcb_edges(rect)

	# Draw solder pads at corners
	_draw_solder_pads(rect)

	# Draw subtle circuit traces
	_draw_circuit_traces(rect)

	# Draw entanglement ring if plot is entangled
	if plot_ui_data and plot_ui_data.get("is_planted", false):
		var entangled_count = 0
		if plot_ui_data.has("entangled_plots"):
			entangled_count = plot_ui_data.get("entangled_plots", []).size()
		if entangled_count > 0:
			_draw_entanglement_ring_inline(rect, entangled_count)


func _draw_pcb_edges(rect: Rect2):
	"""Draw beveled metallic edges like a PCB component"""
	var edge_width = 2

	# Top edge highlight
	draw_line(Vector2(0, 0), Vector2(rect.size.x, 0), COLOR_PCB_EDGE_LIGHT, edge_width)
	draw_line(Vector2(0, 1), Vector2(rect.size.x, 1), COLOR_PCB_EDGE_LIGHT.darkened(0.3), edge_width)

	# Left edge highlight
	draw_line(Vector2(0, 0), Vector2(0, rect.size.y), COLOR_PCB_EDGE_LIGHT, edge_width)
	draw_line(Vector2(1, 0), Vector2(1, rect.size.y), COLOR_PCB_EDGE_LIGHT.darkened(0.3), edge_width)

	# Bottom edge shadow
	draw_line(Vector2(0, rect.size.y - 1), Vector2(rect.size.x, rect.size.y - 1), COLOR_PCB_EDGE_DARK, edge_width)
	draw_line(Vector2(0, rect.size.y - 2), Vector2(rect.size.x, rect.size.y - 2), COLOR_PCB_EDGE_DARK.lightened(0.2), edge_width)

	# Right edge shadow
	draw_line(Vector2(rect.size.x - 1, 0), Vector2(rect.size.x - 1, rect.size.y), COLOR_PCB_EDGE_DARK, edge_width)
	draw_line(Vector2(rect.size.x - 2, 0), Vector2(rect.size.x - 2, rect.size.y), COLOR_PCB_EDGE_DARK.lightened(0.2), edge_width)


func _draw_solder_pads(rect: Rect2):
	"""Draw circular solder pads at corners"""
	var pad_radius = 2.5
	var pad_offset = 4

	# Corner pads
	var corners = [
		Vector2(pad_offset, pad_offset),                           # Top-left
		Vector2(rect.size.x - pad_offset, pad_offset),            # Top-right
		Vector2(pad_offset, rect.size.y - pad_offset),            # Bottom-left
		Vector2(rect.size.x - pad_offset, rect.size.y - pad_offset) # Bottom-right
	]

	for pad_pos in corners:
		# Outer solder pad (silver)
		draw_circle(pad_pos, pad_radius, COLOR_PCB_SOLDER)
		# Inner copper ring
		draw_circle(pad_pos, pad_radius * 0.6, COLOR_PCB_COPPER)


func _draw_circuit_traces(rect: Rect2):
	"""Draw subtle circuit trace patterns"""
	var trace_color = COLOR_PCB_COPPER.darkened(0.4)
	trace_color.a = 0.3  # Semi-transparent

	# Horizontal trace line near top
	draw_line(Vector2(8, 6), Vector2(rect.size.x - 8, 6), trace_color, 1.0)

	# Vertical trace lines (like vias connecting layers)
	draw_line(Vector2(rect.size.x / 2.0, 6), Vector2(rect.size.x / 2.0, rect.size.y - 6), trace_color, 1.0)

	# Horizontal trace near bottom
	draw_line(Vector2(8, rect.size.y - 6), Vector2(rect.size.x - 8, rect.size.y - 6), trace_color, 1.0)


## Center State Visualization

func _update_center_indicator():
	"""Update center indicator showing quantum state + biome effects

	Small glow in center of plot reflects:
	- Size: coherence level (radius/coherence) - larger when more coherent
	- Opacity: biome energy - brighter during high-energy times
	"""
	if not plot_ui_data or not plot_ui_data.get("is_planted", false):
		var c = center_state_indicator.color
		c.a = 0.0
		center_state_indicator.color = c
		return

	# Phase 4: Use PlotUIData - coherence maps to radius concept
	# Get biome energy if available (affects glow intensity)
	var biome_energy = 0.5  # Default middle value
	if biome and biome.has_method("get_energy_strength"):
		biome_energy = biome.get_energy_strength()

	# Calculate size and opacity based on coherence (PlotUIData equivalent of radius)
	# Size ranges from 2 to 12 pixels based on coherence (0 to 1)
	var glow_size = 2.0 + (plot_ui_data.get("coherence", 0.0) * 10.0)

	# Center the indicator in the middle of the plot
	var plot_center = size / 2.0
	center_state_indicator.position = plot_center - Vector2(glow_size / 2.0, glow_size / 2.0)
	center_state_indicator.custom_minimum_size = Vector2(glow_size, glow_size)
	center_state_indicator.size = Vector2(glow_size, glow_size)

	# Color: white, with opacity based on biome energy
	var indicator_color = Color(0.9, 0.9, 0.9)
	indicator_color.a = biome_energy * 0.8  # Max 80% opacity when energy is high
	center_state_indicator.color = indicator_color


func _update_entanglement_display():
	"""Update entanglement visual indicators (ring + counter)"""
	if plot_ui_data == null or not plot_ui_data.get("is_planted", false):
		# No entanglement indicators for empty plots
		entanglement_indicator.queue_redraw()
		entanglement_counter.text = ""
		return

	# Count entangled connections (from plot_ui_data if available)
	var entangled_count = 0
	if plot_ui_data.has("entangled_plots"):
		entangled_count = plot_ui_data.get("entangled_plots", []).size()

	# Update counter label
	if entangled_count > 0:
		entanglement_counter.text = "🔗%d" % entangled_count
	else:
		entanglement_counter.text = ""

	# Trigger redraw of entanglement indicator ring
	entanglement_indicator.queue_redraw()


func _update_purity_display():
	"""Update purity indicator showing Tr(ρ²) quality metric"""
	if plot_ui_data == null or not plot_ui_data.get("is_planted", false):
		# Hide purity for empty plots
		purity_label.text = ""
		return

	# Get purity from plot_ui_data if available
	var purity = 1.0  # Default to pure state
	if plot_ui_data.has("purity"):
		purity = plot_ui_data.get("purity", 1.0)
	elif plot_ui_data.has("quantum_state") and plot_ui_data.get("quantum_state"):
		# Try to get purity from quantum state's bath
		var quantum_state = plot_ui_data.get("quantum_state")
		if quantum_state and quantum_state.has("bath") and quantum_state.get("bath"):
			purity = quantum_state.get("bath").get_purity()

	# Format purity as percentage
	var purity_percent = int(purity * 100)

	# Color-code based on purity level:
	# - High purity (>80%) → Green (excellent yield)
	# - Medium purity (50-80%) → Yellow (decent yield)
	# - Low purity (<50%) → Red (poor yield)
	var purity_color: Color
	if purity > 0.8:
		purity_color = Color(0.0, 1.0, 0.0)  # Green
	elif purity > 0.5:
		purity_color = Color(1.0, 1.0, 0.0)  # Yellow
	else:
		purity_color = Color(1.0, 0.0, 0.0)  # Red

	# Set label text and color
	purity_label.text = "Ψ%d%%" % purity_percent  # Ψ symbol for quantum purity
	purity_label.add_theme_color_override("font_color", purity_color)


func _draw_entanglement_ring_inline(rect: Rect2, entangled_count: int):
	"""Draw the entanglement glow ring inside the plot tile"""
	if entangled_count == 0:
		return

	var center = rect.get_center()
	var ring_radius = min(rect.size.x, rect.size.y) / 2.0 - 2

	# Draw outer glow (faint)
	draw_circle(center, ring_radius + 2, COLOR_ENTANGLEMENT_GLOW)

	# Draw bright ring (pulsing effect based on entanglement count)
	var pulse = (sin(Time.get_ticks_msec() * 0.005) + 1.0) / 2.0
	var bright_color = COLOR_ENTANGLEMENT_RING.lerp(COLOR_ENTANGLEMENT_GLOW, 0.3 + pulse * 0.2)
	draw_arc(center, ring_radius, 0, TAU, 16, bright_color, 2.0)


## Public API

func set_plot_data(plot_data, pos: Vector2i, index: int = -1):
	"""Set the plot UI data for this tile (Phase 4: PlotUIData instead of WheatPlot)"""
	plot_ui_data = plot_data
	grid_position = pos

	# Set number label if index provided (check if label exists first)
	if index >= 0 and number_label:
		number_label.text = str(index)

	# Update visuals to reflect new plot data
	_update_visuals()


func get_debug_info() -> String:
	if plot_ui_data == null or not plot_ui_data.get("is_planted", false):
		return "Empty"
	return "Planted: %s" % plot_ui_data.get("plot_type", "unknown")
