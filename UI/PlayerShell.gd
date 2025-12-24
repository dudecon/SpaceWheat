## PlayerShell - Player-level UI layer
## Handles:
## - Overlay/menu system (ESC menu, V vocabulary, C contracts, etc)
## - Player inventory/resource panel
## - Keyboard help, settings
## - Farm loading/switching (when implemented)
##
## This layer STAYS when farm changes

class_name PlayerShell
extends Control

const FarmUI = preload("res://UI/FarmUI.gd")
const OverlayManager = preload("res://UI/Managers/OverlayManager.gd")

var current_farm_ui: FarmUI = null
var overlay_manager: OverlayManager = null
var farm: Node = null


func _ready() -> void:
	"""Initialize player shell UI"""
	print("🎪 PlayerShell initializing...")

	# Fill screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport().get_visible_rect().size

	# Create overlay manager (ESC menu, overlays, etc)
	overlay_manager = OverlayManager.new()
	add_child(overlay_manager)

	# Initialize overlays with minimal dependencies (will be upgraded later if needed)
	_initialize_overlay_system()

	print("   ✅ Overlay manager created")

	# Farm will be loaded by parent (typically GameController or main scene)
	print("✅ PlayerShell ready")


func load_farm(farm_ref: Node) -> void:
	"""Load a farm (swappable - creates fresh FarmUI)"""
	print("📂 Loading farm...")

	# Clean up old farm UI if it exists
	if current_farm_ui:
		current_farm_ui.queue_free()
		current_farm_ui = null

	# Store farm reference
	farm = farm_ref

	# Create fresh FarmUI for this farm
	current_farm_ui = FarmUI.new()
	current_farm_ui._init(farm_ref)
	add_child(current_farm_ui)

	print("   ✅ FarmUI created and added")


func _input(event: InputEvent) -> void:
	"""Handle overlay/menu shortcuts (ESC, V, C, N, K, Q, R)"""
	if not event is InputEventKey or not event.pressed:
		return

	match event.keycode:
		KEY_ESCAPE:
			_toggle_escape_menu()
		KEY_V:
			_toggle_vocabulary()
		KEY_C:
			_toggle_contracts()
		KEY_N:
			_toggle_network()
		KEY_K:
			_toggle_keyboard_help()


func _toggle_escape_menu() -> void:
	"""Toggle ESC menu"""
	if overlay_manager:
		overlay_manager.toggle_escape_menu()


func _toggle_vocabulary() -> void:
	"""Toggle vocabulary overlay"""
	if overlay_manager:
		overlay_manager.toggle_vocabulary_overlay()


func _toggle_contracts() -> void:
	"""Toggle contracts overlay"""
	if overlay_manager:
		overlay_manager.toggle_overlay("contracts")


func _toggle_network() -> void:
	"""Toggle network overlay"""
	if overlay_manager:
		overlay_manager.toggle_network_overlay()


func _toggle_keyboard_help() -> void:
	"""Toggle keyboard help overlay"""
	if overlay_manager:
		overlay_manager.toggle_keyboard_help()


## OVERLAY SYSTEM INITIALIZATION

func _initialize_overlay_system() -> void:
	"""Initialize OverlayManager with minimal dependencies"""
	if not overlay_manager:
		return

	# Create a minimal UILayoutManager for compatibility
	# (OverlayManager requires it even if we don't use all features)
	const UILayoutManager = preload("res://UI/Managers/UILayoutManager.gd")
	var layout_mgr = UILayoutManager.new()

	# Get system dependencies from Farm if available
	# (These will be null but OverlayManager handles it gracefully)
	var vocab_sys = null
	var faction_mgr = null
	var conspiracy_net = null

	# Initialize OverlayManager with dependencies
	overlay_manager.setup(layout_mgr, vocab_sys, faction_mgr, conspiracy_net)

	# Create the overlay UI panels
	overlay_manager.create_overlays(self)

	print("🎭 Overlay system initialized")
