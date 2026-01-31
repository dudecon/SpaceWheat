extends Control

const PANEL_BG_COLOR: Color = Color(0.08, 0.10, 0.18, 0.88)
const PANEL_BORDER_COLOR: Color = Color(0.4, 0.55, 0.9, 0.7)
const PANEL_PADDING: int = 10

var sim_label: Label
var fps_label: Label
var farm_ref = null
var batcher_ref = null  # For PFPS

func _ready() -> void:
	_ensure_ui()
	set_process(true)

func _process(delta: float) -> void:
	if sim_label == null or fps_label == null:
		_ensure_ui()
		if sim_label == null or fps_label == null:
			return

	# Check if we're in test mode or game mode
	if has_meta("test_controller"):
		var test = get_meta("test_controller")
		var speed = test.simulation_time_scale if "simulation_time_scale" in test else 1.0
		var fraction = _get_speed_fraction(speed)
		var suffix = (" %s" % fraction) if fraction != "" else ""
		sim_label.text = "Sim speed: %.3fx%s" % [speed, suffix]
	else:
		var speed = _get_simulation_speed()
		var fraction = _get_speed_fraction(speed)
		var suffix = (" %s" % fraction) if fraction != "" else ""
		sim_label.text = "Sim time scale: %.3fx%s" % [speed, suffix]

	# Get VFPS (visual) and PFPS (physics)
	var vfps = Engine.get_frames_per_second()
	var pfps = _get_physics_fps()

	fps_label.text = "FPS: %d | VFPS: %d | PFPS: %.1f" % [vfps, vfps, pfps]

func _get_granularity(test_biomes: Array) -> float:
	"""Get max_evolution_dt from test biomes."""
	if test_biomes.is_empty():
		return 0.02
	var first_biome = test_biomes[0]
	if "max_evolution_dt" in first_biome:
		return first_biome.max_evolution_dt
	return 0.02

func _get_simulation_speed() -> float:
	var farm = _locate_farm()
	if farm and farm.grid:
		for biome in farm.grid.biomes.values():
			if not biome:
				continue
			if "quantum_time_scale" in biome:
				return biome.quantum_time_scale
			if biome.has_method("get_quantum_time_scale"):
				return biome.get_quantum_time_scale()
	if farm and "quantum_time_scale" in farm:
		return farm.quantum_time_scale
	return 1.0

func _get_speed_fraction(speed: float) -> String:
	var lookup = {
		0.03125: "1/32",
		0.0625: "1/16",
		0.125: "1/8",
		0.25: "1/4",
		0.5: "1/2",
		1.0: "1",
		2.0: "2",
		4.0: "4",
		8.0: "8",
		16.0: "16"
	}
	for key in lookup.keys():
		if abs(speed - key) < 1e-4:
			return lookup[key]
	return ""

func _get_physics_fps() -> float:
	"""Get PFPS from batcher or test controller."""
	# Check test mode first
	if has_meta("test_controller"):
		var test = get_meta("test_controller")
		if "batcher" in test and test.batcher:
			if "physics_frames_per_second" in test.batcher:
				return test.batcher.physics_frames_per_second

	# Check batcher reference
	if batcher_ref and "physics_frames_per_second" in batcher_ref:
		return batcher_ref.physics_frames_per_second

	# Try to find farm's batcher
	var farm = _locate_farm()
	if farm and "biome_evolution_batcher" in farm:
		var batcher = farm.biome_evolution_batcher
		if batcher and "physics_frames_per_second" in batcher:
			batcher_ref = batcher
			return batcher.physics_frames_per_second

	return 0.0

func _locate_farm():
	if farm_ref and farm_ref.is_inside_tree():
		return farm_ref
	var root = get_tree().root if get_tree() else null
	if root:
		var candidate = root.get_node_or_null("/root/FarmView/Farm")
		if not candidate:
			candidate = root.get_node_or_null("/root/Farm")
		if not candidate:
			var gsm = root.get_node_or_null("/root/GameStateManager")
			if gsm and "active_farm" in gsm and gsm.active_farm:
				candidate = gsm.active_farm
		if candidate:
			farm_ref = candidate
			return farm_ref
	return null

func _ensure_ui() -> void:
	if sim_label != null and fps_label != null:
		return

	anchors_preset = Control.PRESET_TOP_LEFT
	offset_left = 16
	offset_top = 16
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(280, 62)

	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.custom_minimum_size = Vector2(280, 62)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG_COLOR
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_color = PANEL_BORDER_COLOR
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", PANEL_PADDING)
	margin.add_theme_constant_override("margin_top", PANEL_PADDING)
	margin.add_theme_constant_override("margin_right", PANEL_PADDING)
	margin.add_theme_constant_override("margin_bottom", PANEL_PADDING)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)

	sim_label = _create_label("Sim time scale: --", Color(0.95, 0.95, 0.95))
	fps_label = _create_label("FPS: --", Color(0.8, 0.9, 1.0))

	vbox.add_child(sim_label)
	vbox.add_child(fps_label)
	margin.add_child(vbox)
	panel.add_child(margin)
	add_child(panel)

func _create_label(text_value: String, color: Color) -> Label:
	var label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", color)
	label.text = text_value
	return label
