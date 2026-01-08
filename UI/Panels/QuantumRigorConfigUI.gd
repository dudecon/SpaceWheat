extends PanelContainer

## QuantumRigorConfigUI - Settings panel for quantum rigor modes
##
## Allows player to:
## - View current readout mode (HARDWARE vs INSPECTOR)
## - View current backaction mode (KID_LIGHT vs LAB_TRUE)
## - View selective measure model (POSTSELECT_COSTED vs CLICK_NOCLICK)
## - Toggle modes (if design allows)
##
## Can be opened from main menu or pause menu

const QuantumRigorConfig = preload("res://Core/GameState/QuantumRigorConfig.gd")

var config: QuantumRigorConfig = null
var scroll_container: ScrollContainer = null
var content_vbox: VBoxContainer = null


func _ready() -> void:
	"""Initialize settings panel"""
	config = QuantumRigorConfig.instance
	if not config:
		print("⚠️  QuantumRigorConfigUI: No QuantumRigorConfig instance found")
		return

	_setup_theme()
	_setup_layout()
	_update_display()

	print("✅ QuantumRigorConfigUI initialized")


func _setup_theme() -> void:
	"""Configure visual styling"""
	# Panel background
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	# Godot 4.5: set borders individually
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.2, 0.8, 1.0, 0.5)
	# Godot 4.5: set margins individually
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	add_theme_stylebox_override("panel", panel_style)

	# Custom minimum size
	custom_minimum_size = Vector2(600, 500)


func _setup_layout() -> void:
	"""Build UI layout"""
	# Main container
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)

	# Title
	var title = Label.new()
	title.text = "🔬 Quantum Rigor Configuration"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	main_vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Manifest Section 1.1: Choose your quantum mechanics learning path"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	main_vbox.add_child(subtitle)

	main_vbox.add_child(HSeparator.new())

	# Scrollable content
	scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(550, 350)
	main_vbox.add_child(scroll_container)

	content_vbox = VBoxContainer.new()
	scroll_container.add_child(content_vbox)

	# Add sections
	_add_readout_mode_section()
	_add_backaction_mode_section()
	_add_selective_measure_section()
	_add_invariant_checks_section()

	# Info box
	main_vbox.add_child(HSeparator.new())
	var info_label = Label.new()
	info_label.text = "💡 Modes affect gameplay difficulty and measurement behavior. Experiment to find your preferred style!"
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))
	main_vbox.add_child(info_label)

	# Close button
	var close_button = Button.new()
	close_button.text = "Close (ESC)"
	close_button.pressed.connect(_on_close_pressed)
	main_vbox.add_child(close_button)


func _add_readout_mode_section() -> void:
	"""Add readout mode selection section"""
	var section = _create_section("📡 Readout Mode", "How measurement results are presented:")

	var hardware_btn_container = _create_mode_button(
		"HARDWARE",
		"🎲 Shot-based sampling (realistic quantum hardware behavior)",
		config.readout_mode == QuantumRigorConfig.ReadoutMode.HARDWARE
	)
	hardware_btn_container.get_child(0).pressed.connect(func(): _set_readout_mode(QuantumRigorConfig.ReadoutMode.HARDWARE))
	section.add_child(hardware_btn_container)

	var inspector_btn_container = _create_mode_button(
		"INSPECTOR",
		"🔍 Exact probability distribution (simulator privilege mode)",
		config.readout_mode == QuantumRigorConfig.ReadoutMode.INSPECTOR
	)
	inspector_btn_container.get_child(0).pressed.connect(func(): _set_readout_mode(QuantumRigorConfig.ReadoutMode.INSPECTOR))
	section.add_child(inspector_btn_container)

	content_vbox.add_child(section)


func _add_backaction_mode_section() -> void:
	"""Add backaction mode selection section"""
	var section = _create_section("⚛️ Backaction Mode", "How measurement affects quantum state:")

	var kid_light_btn_container = _create_mode_button(
		"KID_LIGHT",
		"😌 Gentle partial collapse (preserves some quantum coherence)",
		config.backaction_mode == QuantumRigorConfig.BackactionMode.KID_LIGHT
	)
	kid_light_btn_container.get_child(0).pressed.connect(func(): _set_backaction_mode(QuantumRigorConfig.BackactionMode.KID_LIGHT))
	section.add_child(kid_light_btn_container)

	var lab_true_btn_container = _create_mode_button(
		"LAB_TRUE",
		"🔬 Rigorous projective collapse (full Born rule, no coherence)",
		config.backaction_mode == QuantumRigorConfig.BackactionMode.LAB_TRUE
	)
	lab_true_btn_container.get_child(0).pressed.connect(func(): _set_backaction_mode(QuantumRigorConfig.BackactionMode.LAB_TRUE))
	section.add_child(lab_true_btn_container)

	content_vbox.add_child(section)


func _add_selective_measure_section() -> void:
	"""Add selective measurement model selection section"""
	var section = _create_section("💰 Selective Measurement Model", "Cost of measuring specific subspaces:")

	var costed_btn_container = _create_mode_button(
		"POSTSELECT_COSTED",
		"💸 Postselection cost: harvest yield divided by measurement cost",
		config.selective_measure_model == QuantumRigorConfig.SelectiveMeasureModel.POSTSELECT_COSTED
	)
	costed_btn_container.get_child(0).pressed.connect(func(): _set_measure_model(QuantumRigorConfig.SelectiveMeasureModel.POSTSELECT_COSTED))
	section.add_child(costed_btn_container)

	var click_btn_container = _create_mode_button(
		"CLICK_NOCLICK",
		"🎯 Click/no-click instrument (future: repeated measurement)",
		config.selective_measure_model == QuantumRigorConfig.SelectiveMeasureModel.CLICK_NOCLICK
	)
	click_btn_container.get_child(0).pressed.connect(func(): _set_measure_model(QuantumRigorConfig.SelectiveMeasureModel.CLICK_NOCLICK))
	section.add_child(click_btn_container)

	content_vbox.add_child(section)


func _add_invariant_checks_section() -> void:
	"""Add debug mode for physics invariant checks"""
	var section = _create_section("🐛 Debug Mode", "Expensive per-frame validation (performance impact):")

	var check_box = CheckButton.new()
	check_box.text = "Enable Invariant Checks (Hermitian, Tr(ρ)=1, PSD)"
	check_box.button_pressed = config.enable_invariant_checks
	check_box.toggled.connect(func(enabled): _set_invariant_checks(enabled))
	section.add_child(check_box)

	var info = Label.new()
	info.text = "Validates quantum state integrity every frame (slow!). Only for testing."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	section.add_child(info)

	content_vbox.add_child(section)


func _create_section(title: String, description: String) -> VBoxContainer:
	"""Create a mode section with title and description"""
	var section = VBoxContainer.new()

	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	section.add_child(title_label)

	var desc_label = Label.new()
	desc_label.text = description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	desc_label.add_theme_font_size_override("font_size", 11)
	section.add_child(desc_label)

	section.add_child(VSeparator.new())

	return section


func _create_mode_button(name: String, description: String, selected: bool) -> HBoxContainer:
	"""Create a selectable mode button (returns container with button as first child)"""
	var container = HBoxContainer.new()
	container.custom_minimum_size = Vector2(500, 60)

	var button = Button.new()
	button.text = "%s %s" % ["✓" if selected else " ", name]
	button.custom_minimum_size = Vector2(120, 60)
	button.modulate = Color(0.2, 0.8, 1.0) if selected else Color.WHITE
	container.add_child(button)

	var desc = Label.new()
	desc.text = description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 10)
	container.add_child(desc)

	return container


func _set_readout_mode(mode: QuantumRigorConfig.ReadoutMode) -> void:
	"""Change readout mode"""
	config.readout_mode = mode
	print("🎲 Readout mode changed: %s" % ("HARDWARE" if mode == QuantumRigorConfig.ReadoutMode.HARDWARE else "INSPECTOR"))
	_update_display()


func _set_backaction_mode(mode: QuantumRigorConfig.BackactionMode) -> void:
	"""Change backaction mode"""
	config.backaction_mode = mode
	print("⚛️ Backaction mode changed: %s" % ("LAB_TRUE" if mode == QuantumRigorConfig.BackactionMode.LAB_TRUE else "KID_LIGHT"))
	_update_display()


func _set_measure_model(model: QuantumRigorConfig.SelectiveMeasureModel) -> void:
	"""Change selective measurement model"""
	config.selective_measure_model = model
	print("💰 Measurement model changed: %s" % ("POSTSELECT_COSTED" if model == QuantumRigorConfig.SelectiveMeasureModel.POSTSELECT_COSTED else "CLICK_NOCLICK"))
	_update_display()


func _set_invariant_checks(enabled: bool) -> void:
	"""Enable/disable invariant checks"""
	config.enable_invariant_checks = enabled
	print("🐛 Invariant checks: %s" % ("ENABLED" if enabled else "DISABLED"))
	_update_display()


func _update_display() -> void:
	"""Refresh UI to reflect current config"""
	# Could add animation or visual feedback here
	pass


func _on_close_pressed() -> void:
	"""Close settings panel"""
	queue_free()
