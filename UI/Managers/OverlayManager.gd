class_name OverlayManager
extends Node

## Centralizes management of all overlays (Contracts, Vocabulary, Network, Escape Menu, Save/Load)
## Handles overlay visibility, positioning, and menu actions

# Preload dependencies
const ContractPanel = preload("res://UI/ContractPanel.gd")
const NetworkInfoPanel = preload("res://UI/NetworkInfoPanel.gd")
const ConspiracyNetworkOverlay = preload("res://UI/ConspiracyNetworkOverlay.gd")
const SaveLoadMenu = preload("res://UI/Panels/SaveLoadMenu.gd")
const EscapeMenu = preload("res://UI/Panels/EscapeMenu.gd")
const SaveDataAdapter = preload("res://UI/SaveDataAdapter.gd")

# Overlay instances
var contract_panel: ContractPanel
var vocabulary_overlay: Control
var network_overlay: ConspiracyNetworkOverlay
var network_info_panel: NetworkInfoPanel
var escape_menu: EscapeMenu
var save_load_menu
var keyboard_hint_button: Control  # Keyboard help display

# Dependencies
var layout_manager
var faction_manager
var vocabulary_evolution
var conspiracy_network

# Track overlay visibility state
var overlay_states: Dictionary = {
	"contracts": false,
	"vocabulary": false,
	"network": false,
	"escape_menu": false,
	"save_load": false
}

# Signals for menu actions
signal overlay_toggled(name: String, visible: bool)
signal save_requested(slot: int)
signal load_requested(slot: int)
signal restart_requested()
signal quit_requested()
signal menu_resumed()
signal debug_scenario_requested(name: String)

# HAUNTED UI FIX: Prevent duplicate overlay creation
var _overlays_created: bool = false


func setup(layout_mgr, vocab_sys, faction_mgr, conspiracy_net) -> void:
	"""Initialize OverlayManager with required dependencies"""
	layout_manager = layout_mgr
	vocabulary_evolution = vocab_sys
	faction_manager = faction_mgr
	conspiracy_network = conspiracy_net
	print("📋 OverlayManager initialized")


func create_overlays(parent: Control) -> void:
	"""Create all overlay panels and add them to parent"""
	# HAUNTED UI FIX: Guard against duplicate overlay creation
	if _overlays_created:
		print("⚠️  OverlayManager.create_overlays() called multiple times, skipping duplicate creation")
		return
	_overlays_created = true

	if not layout_manager:
		push_error("OverlayManager: layout_manager not set before create_overlays()")
		return

	# Create Contract Panel
	contract_panel = ContractPanel.new()
	contract_panel.set_faction_manager(faction_manager)
	contract_panel.visible = false
	contract_panel.z_index = 1001
	parent.add_child(contract_panel)
	print("📜 Contract panel created (press C to toggle)")

	# Create Vocabulary Overlay
	vocabulary_overlay = _create_vocabulary_overlay()
	parent.add_child(vocabulary_overlay)
	print("📖 Vocabulary overlay created (press V to toggle)")

	# Network overlay - DISABLED (being redesigned)
	# Will be implemented differently in future update
	# if conspiracy_network:
	# 	network_overlay = ConspiracyNetworkOverlay.new()
	# 	network_overlay.visible = false
	# 	network_overlay.z_index = 1000
	# 	parent.add_child(network_overlay)
	# 	print("📊 Quantum space network overlay created (press N to toggle)")
	#
	# 	network_info_panel = NetworkInfoPanel.new()
	# 	network_info_panel.visible = false
	# 	network_info_panel.z_index = 1001
	# 	parent.add_child(network_info_panel)
	# 	print("📊 Network info panel created")

	# Create Escape Menu
	escape_menu = EscapeMenu.new()
	escape_menu.z_index = 100
	escape_menu.hide_menu()
	parent.add_child(escape_menu)

	# Connect escape menu signals
	escape_menu.resume_pressed.connect(_on_menu_resume)
	escape_menu.restart_pressed.connect(_on_restart_pressed)
	escape_menu.quit_pressed.connect(func(): quit_requested.emit())
	escape_menu.save_pressed.connect(_on_save_pressed)
	escape_menu.load_pressed.connect(_on_load_pressed)
	escape_menu.reload_last_save_pressed.connect(_on_reload_last_save_pressed)
	# Note: EscapeMenu doesn't have debug_environment_selected - removed this connection
	print("🎮 Escape menu created (ESC to toggle)")

	# Create Keyboard Hint Button (K key help)
	const KeyboardHintButton = preload("res://UI/Panels/KeyboardHintButton.gd")
	keyboard_hint_button = KeyboardHintButton.new()
	if layout_manager:
		keyboard_hint_button.set_layout_manager(layout_manager)
	parent.add_child(keyboard_hint_button)
	print("⌨️  Keyboard hint button created (K to toggle)")

	# Create Save/Load Menu
	print("💾 Creating Save/Load menu...")
	save_load_menu = SaveLoadMenu.new()
	print("💾 Save/Load menu instantiated, setting properties...")
	save_load_menu.z_index = 101
	save_load_menu.hide_menu()
	print("💾 Adding Save/Load menu to parent...")
	parent.add_child(save_load_menu)
	print("💾 Save/Load menu created")

	# Connect save/load menu signals
	print("💾 Connecting save/load menu signals...")
	save_load_menu.slot_selected.connect(_on_save_load_slot_selected)
	save_load_menu.debug_environment_selected.connect(_on_debug_environment_selected)
	save_load_menu.menu_closed.connect(_on_save_load_menu_closed)
	print("💾 Save/Load menu signals connected")

	# Update positions after layout is ready
	await get_tree().process_frame
	update_positions()


func toggle_overlay(name: String) -> void:
	"""Toggle visibility of an overlay by name"""
	match name:
		"contracts":
			toggle_contract_panel()
		"vocabulary":
			toggle_vocabulary_overlay()
		"network":
			toggle_network_overlay()
		"escape_menu":
			toggle_escape_menu()
		_:
			push_warning("OverlayManager: Unknown overlay '%s'" % name)


func show_overlay(name: String) -> void:
	"""Show a specific overlay"""
	print("🔓 show_overlay('%s') called" % name)
	match name:
		"contracts":
			if contract_panel:
				print("  → Setting contract_panel.visible = true")
				contract_panel.visible = true
				contract_panel.refresh_display()
				overlay_states["contracts"] = true
				overlay_toggled.emit("contracts", true)
				print("  ✅ contract_panel shown")
			else:
				print("  ❌ contract_panel is null!")
		"vocabulary":
			if vocabulary_overlay:
				print("  → Setting vocabulary_overlay.visible = true")
				vocabulary_overlay.visible = true
				overlay_states["vocabulary"] = true
				overlay_toggled.emit("vocabulary", true)
				print("  ✅ vocabulary_overlay shown")
			else:
				print("  ❌ vocabulary_overlay is null!")
		"network":
			if network_overlay:
				print("  → Setting network_overlay.visible = true")
				network_overlay.visible = true
				if network_info_panel:
					network_info_panel.visible = true
				overlay_states["network"] = true
				overlay_toggled.emit("network", true)
				print("  ✅ network_overlay shown")
			else:
				print("  ❌ network_overlay is null (disabled)")
		"escape_menu":
			if escape_menu:
				print("  → Calling escape_menu.show_menu()")
				escape_menu.show_menu()
				overlay_states["escape_menu"] = true
				overlay_toggled.emit("escape_menu", true)
				print("  ✅ escape_menu shown")
			else:
				print("  ❌ escape_menu is null!")
		_:
			push_warning("OverlayManager: Unknown overlay '%s'" % name)


func hide_overlay(name: String) -> void:
	"""Hide a specific overlay"""
	print("🔐 hide_overlay('%s') called" % name)
	match name:
		"contracts":
			if contract_panel:
				print("  → Setting contract_panel.visible = false")
				contract_panel.visible = false
				overlay_states["contracts"] = false
				overlay_toggled.emit("contracts", false)
				print("  ✅ contract_panel hidden")
			else:
				print("  ❌ contract_panel is null!")
		"vocabulary":
			if vocabulary_overlay:
				print("  → Setting vocabulary_overlay.visible = false")
				vocabulary_overlay.visible = false
				overlay_states["vocabulary"] = false
				overlay_toggled.emit("vocabulary", false)
				print("  ✅ vocabulary_overlay hidden")
			else:
				print("  ❌ vocabulary_overlay is null!")
		"network":
			if network_overlay:
				print("  → Hiding network panels")
				network_overlay.visible = false
				if network_info_panel:
					network_info_panel.visible = false
				overlay_states["network"] = false
				overlay_toggled.emit("network", false)
				print("  ✅ network_overlay hidden")
			else:
				print("  ❌ network_overlay is null (disabled)")
		"escape_menu":
			if escape_menu:
				print("  → Calling escape_menu.hide_menu()")
				escape_menu.hide_menu()
				overlay_states["escape_menu"] = false
				overlay_toggled.emit("escape_menu", false)
				print("  ✅ escape_menu hidden")
			else:
				print("  ❌ escape_menu is null!")
		_:
			push_warning("OverlayManager: Unknown overlay '%s'" % name)


func hide_all_overlays() -> void:
	"""Hide all overlays (useful when entering/exiting menus)"""
	for overlay_name in overlay_states.keys():
		hide_overlay(overlay_name)


func update_positions() -> void:
	"""Update positions of all overlays based on layout_manager"""
	if not layout_manager:
		return

	# Contract panel - top-left corner with scaled margin
	if contract_panel:
		contract_panel.position = layout_manager.anchor_to_corner("top_left", Vector2(10, 10))

	# Network info panel - below top bar with scaled margin
	if network_info_panel:
		var scaled_margin = 15 * layout_manager.scale_factor
		var panel_y = layout_manager.top_bar_height + scaled_margin
		network_info_panel.position = Vector2(10 * layout_manager.scale_factor, panel_y)

	# Conspiracy network overlay - centered on play area
	if network_overlay:
		network_overlay.center = layout_manager.get_play_area_center()
		network_overlay.bounds_radius = layout_manager.play_area_rect.size.length() * 0.35

	# Vocabulary overlay - position set during creation, can be overridden here if needed
	# (currently left at creation position for UX consistency)


func show_escape_menu() -> void:
	"""Show the escape menu"""
	show_overlay("escape_menu")


func hide_escape_menu() -> void:
	"""Hide the escape menu"""
	hide_overlay("escape_menu")


func is_menu_open() -> bool:
	"""Check if any menu/overlay is currently visible"""
	return overlay_states.values().any(func(visible): return visible)


# ============================================================================
# PRIVATE METHODS
# ============================================================================

func toggle_contract_panel() -> void:
	"""Toggle contract panel visibility"""
	print("🔄 toggle_contract_panel() called")
	if contract_panel:
		print("  contract_panel exists, visible = %s" % contract_panel.visible)
		if contract_panel.visible:
			print("    → Panel is visible, calling hide_overlay()")
			hide_overlay("contracts")
		else:
			print("    → Panel is hidden, calling show_overlay()")
			show_overlay("contracts")
	else:
		print("  ❌ contract_panel is null!")


func toggle_vocabulary_overlay() -> void:
	"""Toggle vocabulary overlay visibility"""
	print("🔄 toggle_vocabulary_overlay() called")
	if vocabulary_overlay:
		print("  vocabulary_overlay exists, visible = %s" % vocabulary_overlay.visible)
		if vocabulary_overlay.visible:
			print("    → Overlay is visible, calling hide_overlay()")
			hide_overlay("vocabulary")
		else:
			print("    → Overlay is hidden, calling show_overlay()")
			show_overlay("vocabulary")
	else:
		print("  ❌ vocabulary_overlay is null!")


func toggle_network_overlay() -> void:
	"""Toggle network overlay and info panel visibility"""
	print("🔄 toggle_network_overlay() called")
	if network_overlay:
		print("  network_overlay exists, visible = %s" % network_overlay.visible)
		if network_overlay.visible:
			print("    → Overlay is visible, calling hide_overlay()")
			hide_overlay("network")
		else:
			print("    → Overlay is hidden, calling show_overlay()")
			show_overlay("network")
	else:
		print("  ❌ network_overlay is null (disabled)")


func toggle_escape_menu() -> void:
	"""Toggle escape menu visibility"""
	print("🔄 toggle_escape_menu() called")
	if escape_menu:
		print("  escape_menu exists, is_visible() = %s" % escape_menu.is_visible())
		if escape_menu.is_visible():
			print("    → Menu is visible, calling hide_overlay()")
			hide_overlay("escape_menu")
		else:
			print("    → Menu is hidden, calling show_overlay()")
			show_overlay("escape_menu")
	else:
		print("  ❌ escape_menu is null!")


func toggle_keyboard_help() -> void:
	"""Toggle keyboard help panel visibility (K key)"""
	if keyboard_hint_button:
		if keyboard_hint_button.has_method("toggle_hints"):
			keyboard_hint_button.toggle_hints()
			print("⌨️  Keyboard help toggled via K key")
		else:
			print("⚠️  keyboard_hint_button missing toggle_hints() method")
	else:
		print("⚠️  Keyboard help not initialized")


func _create_vocabulary_overlay() -> Control:
	"""Create vocabulary display overlay - shows emoji lexicon"""
	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
	var font_size = layout_manager.get_scaled_font_size(18) if layout_manager else 18
	var title_font_size = layout_manager.get_scaled_font_size(24) if layout_manager else 24

	# Main panel container
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400 * scale_factor, 300 * scale_factor)
	panel.position = Vector2(100 * scale_factor, 100 * scale_factor)
	panel.z_index = 1000
	panel.visible = false

	# VBox for content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(10 * scale_factor))
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "📖 Vocabulary"
	title.add_theme_font_size_override("font_size", title_font_size)
	vbox.add_child(title)

	# Content label with emoji vocabulary
	var content = Label.new()
	content.text = """🌾 Wheat - Staple crop
👥 Labor - Farm workers
🍅 Tomato - Special crop
🍄 Mushroom - Fungal crop
💰 Credits - Currency
⏱️ Tribute - Regular payment
🌍 Biome - Environment
⚡ Energy - System power
🏭 Mill - Processing building
💨 Detritus - Waste product"""
	content.add_theme_font_size_override("font_size", font_size)
	content.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.clip_text = true
	vbox.add_child(content)

	# Separator
	var separator = Control.new()
	separator.custom_minimum_size.y = int(5 * scale_factor)
	vbox.add_child(separator)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close [V]"
	close_btn.add_theme_font_size_override("font_size", font_size)
	close_btn.pressed.connect(func():
		panel.visible = false
	)
	vbox.add_child(close_btn)

	return panel


# ============================================================================
# MENU SIGNAL HANDLERS
# ============================================================================

func _on_menu_resume() -> void:
	"""Resume game from escape menu"""
	hide_overlay("escape_menu")
	menu_resumed.emit()


func _on_restart_pressed() -> void:
	"""Restart the game by reloading the current scene"""
	print("🔄 Restarting game...")
	get_tree().reload_current_scene()
	emit_signal("restart_requested")


func _on_save_pressed() -> void:
	"""Show save menu when Save is pressed from escape menu"""
	print("📋 OverlayManager._on_save_pressed() called")
	print("   save_load_menu exists: %s" % (save_load_menu != null))
	if save_load_menu:
		print("   Calling show_menu(SAVE)...")
		save_load_menu.show_menu(SaveLoadMenu.Mode.SAVE)
		print("   save_load_menu.visible = %s" % save_load_menu.visible)
		print("💾 Save menu opened")
	else:
		print("⚠️  Save/Load menu not available")


func _on_load_pressed() -> void:
	"""Show load menu when Load is pressed from escape menu"""
	print("📋 OverlayManager._on_load_pressed() called")
	print("   save_load_menu exists: %s" % (save_load_menu != null))
	if save_load_menu:
		print("   Calling show_menu(LOAD)...")
		save_load_menu.show_menu(SaveLoadMenu.Mode.LOAD)
		print("   save_load_menu.visible = %s" % save_load_menu.visible)
		print("📂 Load menu opened")
	else:
		print("⚠️  Save/Load menu not available")


func _on_reload_last_save_pressed() -> void:
	"""Reload the last saved game"""
	if GameStateManager and GameStateManager.last_saved_slot >= 0:
		if GameStateManager.load_and_apply(GameStateManager.last_saved_slot):
			print("✅ Game reloaded from last save")
			emit_signal("load_completed")
		else:
			print("❌ Failed to reload last save")
	else:
		print("⚠️  No previous save to reload")


func _on_save_load_slot_selected(slot: int, mode: String) -> void:
	"""Handle save/load slot selection from the SaveLoadMenu"""
	if mode == "save":
		# Save to the selected slot
		if GameStateManager.save_game(slot):
			print("✅ Game saved to slot %d" % (slot + 1))
			save_requested.emit(slot)
			save_load_menu.hide_menu()
		else:
			print("❌ Failed to save to slot %d" % (slot + 1))
	elif mode == "load":
		# Load from the selected slot and display
		print("📂 Loading save from slot %d..." % (slot + 1))
		var game_state = GameStateManager.load_game_state(slot)
		if not game_state:
			print("❌ Failed to load game state from slot %d" % (slot + 1))
			return

		# Convert to display data using adapter
		var display_data = SaveDataAdapter.from_game_state(game_state)
		if not display_data:
			print("❌ Failed to convert save data for display")
			return

		# Reconstruct biome and grid from saved state
		var biome = SaveDataAdapter.create_biome_from_state(display_data.biome_data)
		var grid = SaveDataAdapter.create_grid_from_state(
			display_data.grid_data,
			display_data.grid_width,
			display_data.grid_height,
			biome
		)

		# Update visualizer if available
		if layout_manager and layout_manager.quantum_graph:
			var center = layout_manager.layout_manager.play_area_rect.get_center()
			var radius = layout_manager.layout_manager.play_area_rect.size.length() * 0.3
			layout_manager.quantum_graph.initialize(grid, center, radius)
			layout_manager.quantum_graph.set_biome(biome)
			layout_manager.quantum_graph.create_sun_qubit_node()
			print("✅ Visualizer updated with save data")

		# Emit signal
		load_requested.emit(slot)
		save_load_menu.hide_menu()
		print("✅ Save loaded from slot %d (display mode)" % (slot + 1))


func _on_debug_environment_selected(env_name: String) -> void:
	"""Handle debug environment/scenario selection"""
	print("🎮 Loading debug environment: %s" % env_name)

	# Emit signal for debug scenario (other systems can listen for this)
	debug_scenario_requested.emit(env_name)

	# Hide the save/load menu and escape menu
	save_load_menu.hide_menu()
	hide_overlay("escape_menu")


func _on_save_load_menu_closed() -> void:
	"""Handle save/load menu closed"""
	# Menu is being hidden by SaveLoadMenu
	# Resume escape menu if it's still open
	if escape_menu and escape_menu.visible:
		escape_menu.show_menu()
	else:
		# Close the escape menu too if user cancelled from save/load menu
		hide_overlay("escape_menu")
