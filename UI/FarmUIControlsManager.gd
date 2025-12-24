class_name FarmUIControlsManager
extends Node

## FarmUIControlsManager
## Separated concerns: Handles ALL input, signals, and event routing
## Leaves FarmUIController clean for visual layout only
##
## ARCHITECTURE:
## - FarmInputHandler (keyboard: 1-6, Q/E/R, WASD)
## - InputController (overlay toggles: ESC, C, V, N, K)
## - Uses ControlsInterface to abstract simulation machinery
## - Allows swapping simulations by providing different ControlsInterface implementations

# Preload input handlers and interface
const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")
const InputController = preload("res://UI/Controllers/InputController.gd")
const ControlsInterface = preload("res://UI/ControlsInterface.gd")

# Preload GridConfig (Phase 7)
const GridConfig = preload("res://Core/GameState/GridConfig.gd")

# Input handlers
var input_handler: FarmInputHandler = null
var input_controller: InputController = null

# Reference to UI controller (for event emission)
var ui_controller: Node = null

# Reference to simulation machinery via abstract interface (typed as Node for flexibility/duck typing)
var controls: Node = null

# Fallback: reference to Farm for backward compatibility / adapter creation
var farm: Node = null

# Grid configuration (Phase 7)
var grid_config: GridConfig = null

# For lazy-init pattern (connect signals when simulation is injected)
var signals_connected: bool = false


func _ready() -> void:
	"""Initialize input handlers (Farm may be injected later)"""
	print("⌨️  FarmUIControlsManager initializing...")

	# Create input handlers
	_create_input_handlers()

	# Connect overlay/menu input signals (separate from farm simulation signals)
	_connect_overlay_input_signals()


func inject_ui_controller(controller: Node) -> void:
	"""Set the UI controller reference (for signal routing)"""
	ui_controller = controller
	print("📡 Controls manager connected to UI controller")


func inject_controls(controls_interface: Node) -> void:
	"""Inject any simulation machinery that implements ControlsInterface contract"""
	controls = controls_interface

	# REFACTOR: Disabled signal cascade to eliminate haunted behavior
	# Visualization systems now read from Farm directly instead of listening to signals
	#if not signals_connected:
	#	_connect_controls_signals()
	#	signals_connected = true


func inject_farm(farm_ref: Node) -> void:
	"""Set the Farm reference and optionally wrap it with ControlsInterface"""
	farm = farm_ref

	# Inject farm into input handler so keyboard actions can access it
	if input_handler:
		input_handler.farm = farm
		if farm:
			input_handler.grid_width = farm.grid_width
			input_handler.grid_height = farm.grid_height
		print("💉 Farm injected into FarmInputHandler")

	# If farm implements ControlsInterface, use it directly
	if farm is ControlsInterface:
		inject_controls(farm as ControlsInterface)
	else:
		# Otherwise, create an adapter (simulation team can provide one)
		print("⚠️  Farm does not implement ControlsInterface - backward compatibility mode")
		print("🔗 Signal cascade DISABLED - using direct state reading instead")


func inject_grid_config(config: GridConfig) -> void:
	"""Inject GridConfig into FarmInputHandler (Phase 7)"""
	if not config:
		push_error("FarmUIControlsManager: Attempted to inject null GridConfig!")
		return

	grid_config = config
	print("💉 GridConfig injected into FarmUIControlsManager")

	# Pass to FarmInputHandler
	if input_handler and input_handler.has_method("inject_grid_config"):
		input_handler.inject_grid_config(config)
		print("   📡 GridConfig → FarmInputHandler")


func _create_input_handlers() -> void:
	"""Create input handling systems"""
	# Input Controller MUST be added FIRST so it gets priority for input processing
	# This ensures menu/overlay keys (ESC, Q, R when menu visible) are handled
	# BEFORE FarmInputHandler can intercept them (overlay toggles: ESC, C, V, N, K)
	input_controller = InputController.new()
	add_child(input_controller)
	print("🎮 InputController created")

	# Farm Input Handler (keyboard-driven farm actions: 1-6, Q/E/R, WASD)
	# Added second so it only processes when no menu is open
	input_handler = FarmInputHandler.new()
	add_child(input_handler)
	if farm:
		input_handler.farm = farm
		input_handler.grid_width = farm.grid_width
		input_handler.grid_height = farm.grid_height
	print("⌨️  FarmInputHandler created")


func _connect_overlay_input_signals() -> void:
	"""Connect InputController overlay/menu signals ONLY (not farm simulation signals)

	CRITICAL SEPARATION:
	- This connects OVERLAY toggles (ESC, V, C, N, K, Q, R) → OverlayManager
	- Does NOT connect farm simulation signals (plot_planted, wheat_changed, etc.)
	- Farm simulation signals remain DISABLED to prevent haunted visualization
	"""
	if not input_controller:
		print("⚠️  InputController not available for overlay signal connection")
		return

	print("🔗 Connecting overlay/menu input signals...")

	# ESC, V, C, N, K, Q, R signal connections
	if input_controller.has_signal("menu_toggled"):
		input_controller.menu_toggled.connect(_on_menu_toggled)
		print("   ✓ menu_toggled → _on_menu_toggled")
	if input_controller.has_signal("vocabulary_requested"):
		input_controller.vocabulary_requested.connect(_on_vocabulary_requested)
		print("   ✓ vocabulary_requested → _on_vocabulary_requested")
	if input_controller.has_signal("contracts_toggled"):
		input_controller.contracts_toggled.connect(_on_contracts_toggled)
		print("   ✓ contracts_toggled → _on_contracts_toggled")
	if input_controller.has_signal("network_toggled"):
		input_controller.network_toggled.connect(_on_network_toggled)
		print("   ✓ network_toggled → _on_network_toggled")
	if input_controller.has_signal("keyboard_help_requested"):
		input_controller.keyboard_help_requested.connect(_on_keyboard_help_requested)
		print("   ✓ keyboard_help_requested → _on_keyboard_help_requested")
	if input_controller.has_signal("quit_requested"):
		input_controller.quit_requested.connect(_on_quit_requested)
		print("   ✓ quit_requested → _on_quit_requested")
	if input_controller.has_signal("restart_requested"):
		input_controller.restart_requested.connect(_on_restart_requested)
		print("   ✓ restart_requested → _on_restart_requested")

	print("✅ Overlay/menu input signals connected (7 signals)")


func get_input_handler() -> Node:
	"""Get the input handler (for external access)"""
	return input_handler


func set_plot_grid_display(plot_grid_display: Node) -> void:
	"""Set PlotGridDisplay reference on FarmInputHandler (for wiring phase)"""
	if input_handler:
		input_handler.plot_grid_display = plot_grid_display
		print("   💉 PlotGridDisplay wired to FarmInputHandler")


## ============================================================================
## OVERLAY/MENU INPUT HANDLERS
## These handle UI navigation ONLY - separate from farm simulation signals
## ============================================================================

func _on_menu_toggled() -> void:
	"""Handle ESC key - toggle escape menu"""
	if ui_controller and ui_controller.overlay_manager:
		ui_controller.overlay_manager.toggle_escape_menu()


func _on_vocabulary_requested() -> void:
	"""Handle V key - toggle vocabulary overlay"""
	if ui_controller and ui_controller.overlay_manager:
		ui_controller.overlay_manager.toggle_vocabulary_overlay()


func _on_contracts_toggled() -> void:
	"""Handle C key - toggle contracts overlay"""
	if ui_controller and ui_controller.overlay_manager:
		ui_controller.overlay_manager.toggle_overlay("contracts")


func _on_network_toggled() -> void:
	"""Handle N key - toggle network overlay"""
	if ui_controller and ui_controller.overlay_manager:
		ui_controller.overlay_manager.toggle_network_overlay()


func _on_keyboard_help_requested() -> void:
	"""Handle K key - toggle keyboard help overlay"""
	if ui_controller and ui_controller.layout_manager and ui_controller.layout_manager.keyboard_hint_button:
		ui_controller.layout_manager.keyboard_hint_button.toggle_hints()


func _on_quit_requested() -> void:
	"""Handle Q key - quit game (when menu is visible)"""
	if ui_controller and ui_controller.overlay_manager and ui_controller.overlay_manager.escape_menu:
		ui_controller.overlay_manager.escape_menu._on_quit_pressed()


func _on_restart_requested() -> void:
	"""Handle R key - restart game (when menu is visible)"""
	if ui_controller and ui_controller.overlay_manager:
		ui_controller.overlay_manager._on_restart_pressed()

