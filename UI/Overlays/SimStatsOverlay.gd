extends Control

const PANEL_PADDING: int = 8

var sim_label: Label
var fps_label: Label
var farm_ref = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	set_margin(Margin.RIGHT, 12)
	set_margin(Margin.TOP, 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect_min_size = Vector2(180, 48)

	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_FLAGS_FILL
	panel.size_flags_vertical = Control.SIZE_FLAGS_FILL
	panel.rect_min_size = Vector2(180, 48)
	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.margin_right = -PANEL_PADDING
	vbox.margin_bottom = -PANEL_PADDING
	vbox.margin_left = PANEL_PADDING
	vbox.margin_top = PANEL_PADDING

	sim_label = Label.new()
	sim_label.add_color_override("font_color", Color(0.95, 0.95, 0.95))
	sim_label.align = Label.ALIGN_LEFT

	fps_label = Label.new()
	fps_label.add_color_override("font_color", Color(0.8, 0.9, 1.0))
	fps_label.align = Label.ALIGN_LEFT

	vbox.add_child(sim_label)
	vbox.add_child(fps_label)
	panel.add_child(vbox)
	add_child(panel)

	set_process(true)

func _process(delta: float) -> void:
	var speed = _get_simulation_speed()
	sim_label.text = "Sim time scale: %.3fx" % speed
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

func _get_simulation_speed() -> float:
	var farm = _locate_farm()
	if farm and farm.grid:
		var biome_dict = farm.grid.biomes
		for biome in biome_dict.values():
			if not biome:
				continue
			if "quantum_time_scale" in biome:
				return biome.quantum_time_scale
			if biome.has_method("get_quantum_time_scale"):
				return biome.get_quantum_time_scale()
	# Fallback to farm-level property
	if farm and "quantum_time_scale" in farm:
		return farm.quantum_time_scale
	return 1.0

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
