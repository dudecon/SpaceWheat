class_name IconDetailPanel
extends PanelContainer

## Icon Detail Panel - Touch-Friendly
## Shows comprehensive Icon information with summary at top
## Optimized for touch interaction (no hover, large buttons)

signal panel_closed

var current_icon  # Icon type
var layout_manager: Node

# UI elements
var title_label: Label
var summary_section: VBoxContainer
var detail_scroll: ScrollContainer
var detail_vbox: VBoxContainer
var close_button: Button


func set_layout_manager(manager: Node) -> void:
	"""Set layout manager for scaling"""
	layout_manager = manager


func _ready() -> void:
	"""Initialize UI"""
	_create_ui()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _gui_input(event: InputEvent) -> void:
	"""Handle mouse input"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Consume clicks (prevent clicking through)
			accept_event()


func _create_ui() -> void:
	"""Create the detail panel UI"""
	var scale = layout_manager.scale_factor if layout_manager else 1.0

	# Size and position (centered)
	custom_minimum_size = Vector2(600 * scale, 800 * scale)
	z_index = 2000  # Above all other panels

	# Position in center of screen
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -300 * scale
	offset_right = 300 * scale
	offset_top = -400 * scale
	offset_bottom = 400 * scale

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", int(10 * scale))
	add_child(main_vbox)

	# Header with title and close
	var header = HBoxContainer.new()
	main_vbox.add_child(header)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	close_button = Button.new()
	close_button.text = "✖"
	close_button.custom_minimum_size = Vector2(60 * scale, 60 * scale)  # Large for touch!
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	# Summary section (always visible)
	summary_section = VBoxContainer.new()
	summary_section.add_theme_constant_override("separation", int(5 * scale))
	main_vbox.add_child(summary_section)

	# Separator
	var separator = HSeparator.new()
	main_vbox.add_child(separator)

	# Scrollable detail section
	detail_scroll = ScrollContainer.new()
	detail_scroll.custom_minimum_size.y = 600 * scale
	detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(detail_scroll)

	detail_vbox = VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", int(15 * scale))
	detail_scroll.add_child(detail_vbox)


func show_icon(icon) -> void:  # icon: Icon type
	"""Show detail panel for a specific Icon"""
	current_icon = icon
	_populate_content()
	visible = true


func _populate_content() -> void:
	"""Populate panel with Icon data"""
	if not current_icon:
		return

	title_label.text = "📖 Icon: %s %s" % [current_icon.emoji, current_icon.display_name]

	# Clear previous content
	for child in summary_section.get_children():
		child.queue_free()
	for child in detail_vbox.get_children():
		child.queue_free()

	# Populate summary (top, always visible)
	_add_summary_section()

	# Populate details (scrollable)
	_add_hamiltonian_section()
	_add_lindblad_section()
	_add_energy_coupling_section()
	_add_metadata_section()


func _add_summary_section() -> void:
	"""Quick info - visible without scrolling"""
	var scale = layout_manager.scale_factor if layout_manager else 1.0

	# Description
	var desc = Label.new()
	desc.text = '"%s"' % current_icon.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 14)
	summary_section.add_child(desc)

	# Key interactions (Lindblad incoming - what it grows from)
	var grows_from = []
	for emoji in current_icon.lindblad_incoming.keys():
		grows_from.append(emoji)

	if grows_from.size() > 0:
		var grows_label = Label.new()
		var preview = grows_from.slice(0, min(3, grows_from.size()))
		grows_label.text = "Grows from: " + " ".join(preview)
		if grows_from.size() > 3:
			grows_label.text += " (+%d more)" % (grows_from.size() - 3)
		summary_section.add_child(grows_label)

	# Trophic level
	var trophic_names = ["Abiotic", "Producer", "Consumer", "Predator"]
	var trophic = Label.new()
	var level = current_icon.trophic_level
	var level_name = trophic_names[level] if level < 4 else "Unknown"
	trophic.text = "Trophic Level: %d (%s)" % [level, level_name]
	summary_section.add_child(trophic)


func _add_hamiltonian_section() -> void:
	"""Coherent evolution details"""
	var header = Label.new()
	header.text = "HAMILTONIAN (Coherent Evolution) ⚛️"
	header.add_theme_font_size_override("font_size", 18)
	detail_vbox.add_child(header)

	var self_e = Label.new()
	self_e.text = "Self-Energy: %.3f" % current_icon.self_energy
	detail_vbox.add_child(self_e)

	if not current_icon.hamiltonian_couplings.is_empty():
		var coup_header = Label.new()
		coup_header.text = "Couplings:"
		detail_vbox.add_child(coup_header)

		for target in current_icon.hamiltonian_couplings:
			var strength = current_icon.hamiltonian_couplings[target]
			var coup_line = Label.new()
			coup_line.text = "  %s → %.3f (quantum coherence)" % [target, strength]
			detail_vbox.add_child(coup_line)
	else:
		var no_coup = Label.new()
		no_coup.text = "No Hamiltonian couplings"
		no_coup.modulate = Color(0.7, 0.7, 0.7)
		detail_vbox.add_child(no_coup)

	# Driver parameters (if applicable)
	if current_icon.is_driver:
		var driver_header = Label.new()
		driver_header.text = "Driver Parameters:"
		driver_header.modulate = Color(1.0, 0.8, 0.3)  # Gold
		detail_vbox.add_child(driver_header)

		var freq = Label.new()
		freq.text = "  Frequency: %.3f rad/s" % current_icon.driver_frequency
		detail_vbox.add_child(freq)

		var phase = Label.new()
		phase.text = "  Phase: %.3f rad" % current_icon.driver_phase
		detail_vbox.add_child(phase)

		var amp = Label.new()
		amp.text = "  Amplitude: %.3f" % current_icon.driver_amplitude
		detail_vbox.add_child(amp)


func _add_lindblad_section() -> void:
	"""Dissipative evolution details"""
	var header = Label.new()
	header.text = "LINDBLAD (Dissipative Evolution) 🌊"
	header.add_theme_font_size_override("font_size", 18)
	detail_vbox.add_child(header)

	# Incoming transfers (gains amplitude)
	if not current_icon.lindblad_incoming.is_empty():
		var inc_header = Label.new()
		inc_header.text = "Gains amplitude from:"
		detail_vbox.add_child(inc_header)

		for source in current_icon.lindblad_incoming:
			var rate = current_icon.lindblad_incoming[source]
			var inc_line = Label.new()
			inc_line.text = "  %s → %.5f/s (slow growth)" % [source, rate]
			detail_vbox.add_child(inc_line)
	else:
		var no_inc = Label.new()
		no_inc.text = "No incoming Lindblad transfers"
		no_inc.modulate = Color(0.7, 0.7, 0.7)
		detail_vbox.add_child(no_inc)

	# Outgoing transfers
	if not current_icon.lindblad_outgoing.is_empty():
		var out_header = Label.new()
		out_header.text = "Transfers amplitude to:"
		detail_vbox.add_child(out_header)

		for target in current_icon.lindblad_outgoing:
			var rate = current_icon.lindblad_outgoing[target]
			var out_line = Label.new()
			out_line.text = "  %s → %.5f/s" % [target, rate]
			detail_vbox.add_child(out_line)

	# Decay
	if current_icon.decay_rate > 0:
		var decay_label = Label.new()
		decay_label.text = "Decay: %.3f/s → %s" % [current_icon.decay_rate, current_icon.decay_target]
		decay_label.modulate = Color(1.0, 0.6, 0.6)  # Light red
		detail_vbox.add_child(decay_label)


func _add_energy_coupling_section() -> void:
	"""Energy couplings (bath response)"""
	var header = Label.new()
	header.text = "ENERGY COUPLINGS (Bath Response) 📊"
	header.add_theme_font_size_override("font_size", 18)
	detail_vbox.add_child(header)

	if not current_icon.energy_couplings.is_empty():
		var info = Label.new()
		info.text = "Growth/damage from bath state:"
		detail_vbox.add_child(info)

		for observable in current_icon.energy_couplings:
			var coupling = current_icon.energy_couplings[observable]
			var coup_line = Label.new()
			var sign = "+" if coupling > 0 else ""
			var effect = "growth" if coupling > 0 else "damage"
			coup_line.text = "  When %s present → %s%.2f (%s)" % [observable, sign, coupling, effect]
			coup_line.modulate = Color(0.5, 1.0, 0.5) if coupling > 0 else Color(1.0, 0.5, 0.5)
			detail_vbox.add_child(coup_line)
	else:
		var no_energy = Label.new()
		no_energy.text = "No energy couplings"
		no_energy.modulate = Color(0.7, 0.7, 0.7)
		detail_vbox.add_child(no_energy)


func _add_metadata_section() -> void:
	"""Metadata and special flags"""
	var header = Label.new()
	header.text = "SPECIAL FLAGS"
	header.add_theme_font_size_override("font_size", 18)
	detail_vbox.add_child(header)

	# Tags
	if not current_icon.tags.is_empty():
		var tags_label = Label.new()
		tags_label.text = "Tags: " + ", ".join(current_icon.tags)
		detail_vbox.add_child(tags_label)

	# Flags
	var flags_hbox = HBoxContainer.new()
	detail_vbox.add_child(flags_hbox)

	var driver_flag = Label.new()
	driver_flag.text = "☑ Driver" if current_icon.is_driver else "☐ Driver"
	flags_hbox.add_child(driver_flag)

	var adaptive_flag = Label.new()
	adaptive_flag.text = "☑ Adaptive" if current_icon.is_adaptive else "☐ Adaptive"
	flags_hbox.add_child(adaptive_flag)

	var eternal_flag = Label.new()
	eternal_flag.text = "☑ Eternal" if current_icon.is_eternal else "☐ Eternal"
	flags_hbox.add_child(eternal_flag)

	# Drain target
	if current_icon.is_drain_target:
		var drain_label = Label.new()
		drain_label.text = "☑ Drain Target (tap rate: %.3f/s)" % current_icon.drain_to_sink_rate
		drain_label.modulate = Color(0.7, 0.9, 1.0)  # Light blue
		detail_vbox.add_child(drain_label)


func _on_close_pressed() -> void:
	"""Handle close button press"""
	visible = false
	panel_closed.emit()
