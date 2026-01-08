class_name InputController
extends Node

## INPUT CONTRACT (Layer 0 - Global Menu Control)
## ═══════════════════════════════════════════════════════════════
## PHASE: _input() - First priority, runs before other handlers
## HANDLES: InputEventKey only (keyboard)
## KEYS: ESC, K, V, N, C, Q(menu), R(menu), TAB, G, SPACE, ARROWS
## CONSUMES: Always for handled keys (via get_viewport().set_input_as_handled())
## BLOCKS: ALL downstream input when menu_visible=true
## EMITS: menu_toggled, vocabulary_requested, keyboard_help_requested, etc.
## ═══════════════════════════════════════════════════════════════
##
## This is the top-level input handler for global actions like:
## - Opening/closing menus (ESC)
## - Overlay toggles (K=keyboard help, V=vocabulary, N=network, C=quests)
## - Quit/restart (Q/R when menu visible)
##
## When menu_visible=true, this handler BLOCKS all game input.
## Decouples input handling from UI and game logic.

# Action signals
signal plant_requested()
signal plant_tomato_requested()
signal plant_mushroom_requested()
signal measure_requested()
signal measure_all_requested()  # Measure all unmeasured plots
signal entangle_requested()
signal harvest_requested()
signal place_mill_requested()
signal place_market_requested()
signal sell_wheat_requested()
signal vocabulary_requested()
signal network_toggled()
signal contracts_toggled()
signal biome_inspector_toggled()  # B: Toggle biome inspector overlay
signal goal_cycle_requested()  # Cycle through goals/contracts

# Navigation signals
signal plot_selection_next()  # Arrow right/down
signal plot_selection_previous()  # Arrow left/up

# Mode signals
signal entangle_mode_exited()
signal quit_requested()
signal apply_tool_requested()  # Spacebar: Apply selected tool to selected plot
signal menu_toggled()  # ESC: Toggle menu
signal restart_requested()  # R: Restart game
signal keyboard_help_requested()  # K: Toggle keyboard shortcuts help
signal quantum_config_requested()  # Shift+Q: Toggle quantum rigor config settings

# Mode state
var is_entangle_mode: bool = false
var menu_visible: bool = false
var quest_board_visible: bool = false  # Quest board blocks game input when open


func _ready():
	# This controller will handle input events
	set_process_input(true)

	# Process even when game is paused (so ESC can close menu)
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_entangle_mode(enabled: bool):
	"""Update entangle mode state"""
	is_entangle_mode = enabled


func _on_overlay_toggled(overlay_name: String, is_visible: bool):
	"""Called when overlays open/close - block game input for modal overlays"""
	if overlay_name == "quest_board":
		quest_board_visible = is_visible
		print("  → Quest board visibility: %s (game input %s)" % [is_visible, "BLOCKED" if is_visible else "ENABLED"])


## Input Handling

func _input(event):
	"""Handle keyboard shortcuts"""
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	print("⌨️ KEY PRESSED: %s" % event.keycode)

	# Handle menu-related keys first (ESC, Q, R)
	match event.keycode:
		# Escape: Exit entangle mode OR toggle menu (open/close)
		KEY_ESCAPE:
			if is_entangle_mode:
				print("  → ESC: Exiting entangle mode")
				entangle_mode_exited.emit()
				get_viewport().set_input_as_handled()
			elif menu_visible:
				print("  → ESC: Resuming game (closing menu)")
				menu_visible = false
				menu_toggled.emit()
				get_viewport().set_input_as_handled()
			else:
				print("  → ESC: Opening menu")
				menu_visible = true
				menu_toggled.emit()
				get_viewport().set_input_as_handled()

		# Q: Quit game (when menu is visible)
		KEY_Q:
			if menu_visible:
				print("  → Q: Quitting game")
				quit_requested.emit()
				get_viewport().set_input_as_handled()

		# R: Restart game (when menu is visible)
		KEY_R:
			if menu_visible:
				print("  → R: Restarting game")
				restart_requested.emit()
				menu_visible = false
				get_viewport().set_input_as_handled()
				return

	# BLOCK ALL GAME INPUT when menu or quest board is visible
	# Modals should handle their own navigation (arrow keys, Enter, UIOP)
	if menu_visible:
		print("  → Menu is visible - blocking game input")
		return
	if quest_board_visible:
		print("  → Quest board is visible - blocking game input")
		return

	# Game input (only processed when menu is NOT visible)
	match event.keycode:
		# DISABLED: These keys are now used by FarmInputHandler for plot selection (T/Y/U/I/O/P)
		# # Tool selection hotkeys (always enabled in mode-based system)
		# KEY_P:
		#	print("  → P key pressed - selecting wheat tool")
		#	plant_requested.emit()
		#	get_viewport().set_input_as_handled()
		# # KEY_T:  # DISABLED - tomatoes removed from default mode
		# #	print("  → T key pressed - selecting tomato tool")
		# #	plant_tomato_requested.emit()
		# #	get_viewport().set_input_as_handled()
		# KEY_U:
		#	print("  → U key pressed - selecting mushroom tool")
		#	plant_mushroom_requested.emit()
		#	get_viewport().set_input_as_handled()
		# KEY_I:
		#	print("  → I key pressed - selecting mill tool")
		#	place_mill_requested.emit()
		#	get_viewport().set_input_as_handled()
		# DISABLED: These keys conflict with FarmInputHandler's tool/action system (1-6, Q/E/R, WASD)
		# KEY_K:
		#	print("  → K key pressed - selecting market tool")
		#	place_market_requested.emit()
		#	get_viewport().set_input_as_handled()
		# KEY_M:
		#	print("  → M key pressed - selecting measure tool")
		#	measure_requested.emit()
		#	get_viewport().set_input_as_handled()
		# KEY_E:
		#	print("  → E key pressed - selecting entangle tool")
		#	entangle_requested.emit()
		#	get_viewport().set_input_as_handled()

		# Action hotkeys (immediate execution - always available, game logic handles validity)
		# DISABLED: These conflict with FarmInputHandler
		# KEY_A:
		#	print("  → A key pressed - measure all action")
		#	measure_all_requested.emit()
		#	get_viewport().set_input_as_handled()
		# KEY_H:
		#	print("  → H key pressed - harvest action")
		#	harvest_requested.emit()
		#	get_viewport().set_input_as_handled()
		# KEY_S:
		#	print("  → S key pressed - sell wheat action")
		#	sell_wheat_requested.emit()
		#	get_viewport().set_input_as_handled()

		# K: Keyboard shortcuts help
		KEY_K:
			print("  → K key pressed - toggling keyboard help")
			keyboard_help_requested.emit()
			get_viewport().set_input_as_handled()

		KEY_V:
			print("  → V key pressed - vocabulary action")
			vocabulary_requested.emit()
			get_viewport().set_input_as_handled()

		# Spacebar: Apply selected tool to selected plot
		KEY_SPACE:
			apply_tool_requested.emit()
			get_viewport().set_input_as_handled()

		# Toggle overlays (always available)
		KEY_N:
			network_toggled.emit()
			get_viewport().set_input_as_handled()
		KEY_C:
			contracts_toggled.emit()
			get_viewport().set_input_as_handled()
		KEY_B:
			print("  → B key pressed - biome inspector action")
			biome_inspector_toggled.emit()
			get_viewport().set_input_as_handled()

		KEY_Q:
			# Shift+Q: Open quantum rigor config settings
			if event.shift_pressed:
				print("  → Shift+Q pressed - quantum rigor config")
				quantum_config_requested.emit()
				get_viewport().set_input_as_handled()

		# Goal cycling
		KEY_TAB, KEY_G:
			print("  → TAB/G key pressed - cycling goals")
			goal_cycle_requested.emit()
			get_viewport().set_input_as_handled()

		# Arrow key navigation
		KEY_DOWN, KEY_RIGHT:
			plot_selection_next.emit()
			get_viewport().set_input_as_handled()
		KEY_UP, KEY_LEFT:
			plot_selection_previous.emit()
			get_viewport().set_input_as_handled()
