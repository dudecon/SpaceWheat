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

const OverlayManager = preload("res://UI/Managers/OverlayManager.gd")
const QuestManager = preload("res://Core/Quests/QuestManager.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabase.gd")

var current_farm_ui = null  # FarmUI instance (from scene)
var overlay_manager: OverlayManager = null
var quest_manager: QuestManager = null
var farm: Node = null
var farm_ui_container: Control = null


func _ready() -> void:
	"""Initialize player shell UI - children defined in scene"""
	print("🎪 PlayerShell initializing...")

	# CRITICAL: Ensure PlayerShell fills its parent (FarmView)
	# This is the top of the delegation cascade - everything below depends on this sizing
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Explicitly match parent size (in case anchors don't work due to layout_mode mismatch)
	if get_parent():
		size = get_parent().size

	# Get reference to containers from scene
	farm_ui_container = get_node("FarmUIContainer")

	# Also size FarmUIContainer to fill this PlayerShell
	if farm_ui_container:
		farm_ui_container.size = size
	var overlay_layer = get_node("OverlayLayer")

	# Create and initialize UILayoutManager (needs to be in scene tree for _ready())
	const UILayoutManager = preload("res://UI/Managers/UILayoutManager.gd")
	var layout_manager = UILayoutManager.new()
	add_child(layout_manager)
	# _ready() will be called automatically by the engine

	# Create quest manager (before overlays, since overlays need it)
	quest_manager = QuestManager.new()
	add_child(quest_manager)
	print("   ✅ Quest manager created")

	# Create overlay manager and add to overlay layer
	overlay_manager = OverlayManager.new()
	overlay_layer.add_child(overlay_manager)

	# Setup overlay manager with proper dependencies (pass quest_manager)
	overlay_manager.setup(layout_manager, null, null, null, quest_manager)

	# Initialize overlays (C/V/N/K/ESC menus)
	overlay_manager.create_overlays(overlay_layer)

	print("   ✅ Overlay manager created")
	print("✅ PlayerShell ready")


func load_farm(farm_ref: Node) -> void:
	"""Load a farm into FarmUIContainer (swappable)"""
	print("📂 Loading farm into PlayerShell...")

	# Clean up old farm UI if it exists
	if current_farm_ui:
		current_farm_ui.queue_free()
		current_farm_ui = null

	# Store farm reference
	farm = farm_ref

	# Connect quest manager to farm economy
	if quest_manager and farm.economy:
		quest_manager.connect_to_economy(farm.economy)
		print("   ✅ Quest manager connected to economy")

		# Offer initial quest
		_offer_initial_quest()

	# Load FarmUI as scene and add to container
	var farm_ui_scene = load("res://UI/FarmUI.tscn")
	if farm_ui_scene:
		current_farm_ui = farm_ui_scene.instantiate()
		farm_ui_container.add_child(current_farm_ui)

		# Setup farm AFTER layout engine calculates sizes (proper Godot 4 pattern)
		# call_deferred here is the CORRECT TOOL for "run after engine initialization"
		current_farm_ui.call_deferred("setup_farm", farm_ref)
		print("   ✅ FarmUI loaded (setup deferred until after layout calculation)")
	else:
		print("❌ FarmUI.tscn not found - cannot load farm UI")
		return

	print("✅ Farm loaded into PlayerShell")


func get_farm_ui():
	"""Get the currently loaded FarmUI instance"""
	return current_farm_ui


func load_farm_ui(farm_ui: Control) -> void:
	"""Load an already-instantiated FarmUI into the farm container.

	Called by BootManager.boot() in Stage 3C to add the FarmUI that has
	already been instantiated and setup with all dependencies.

	This is separate from load_farm() which handles the entire loading sequence.
	"""
	# Store reference
	current_farm_ui = farm_ui

	# Add to container
	if farm_ui_container:
		farm_ui_container.add_child(farm_ui)
		print("   ✓ FarmUI mounted in container")


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


## QUEST SYSTEM HELPERS

func _offer_initial_quest() -> void:
	"""Offer first quest to player when farm loads"""
	if not quest_manager or not farm:
		return

	# Get random faction from database
	var faction = FactionDatabase.get_random_faction()
	if faction.is_empty():
		print("⚠️  No factions available for quests")
		return

	# Get resources from current biome
	var resources = []
	if farm.biotic_flux_biome:
		resources = farm.biotic_flux_biome.get_harvestable_emojis()

	if resources.is_empty():
		resources = ["🌾", "👥"]  # Fallback

	# Generate and offer quest
	var quest = quest_manager.offer_quest(faction, "BioticFlux", resources)
	if not quest.is_empty():
		# Auto-accept first quest for tutorial
		quest_manager.accept_quest(quest)
		print("   📜 Initial quest offered: %s - %s" % [quest.get("faction", ""), quest.get("body", "")])
