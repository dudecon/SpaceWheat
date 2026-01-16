class_name OverlayStackManager
extends Node

## Unified Overlay Stack Manager
##
## Consolidates modal_stack (PlayerShell) and active_v2_overlay (OverlayManager)
## into a single overlay management system.
##
## Features:
## - Single stack for all overlays (info, modal, system)
## - Automatic z-index management based on tier
## - Unified input routing to top overlay
## - Tier-based priority (higher tier closes lower tier overlays)
##
## Tiers:
##   Z_TIER_HUD (1000)    - ActionBar, ToolSelection (not managed by stack)
##   Z_TIER_INFO (2000)   - Inspector, Controls, Vocabulary
##   Z_TIER_MODAL (3000)  - QuestBoard, BiomeInspector
##   Z_TIER_SYSTEM (4000) - EscapeMenu, SaveLoadMenu

signal overlay_pushed(overlay: Control)
signal overlay_popped(overlay: Control)
signal stack_changed()

# Z-Index tier constants
const Z_TIER_GAME = 0
const Z_TIER_HUD = 1000
const Z_TIER_INFO = 2000
const Z_TIER_MODAL = 3000
const Z_TIER_SYSTEM = 4000

# The overlay stack - topmost overlay receives input
var overlay_stack: Array[Control] = []

# Reference to OverlayManager for ActionPreviewRow updates
var overlay_manager: Node = null


# =============================================================================
# STACK OPERATIONS
# =============================================================================

func push(overlay: Control) -> void:
	"""Push an overlay onto the stack.

	- Higher tier overlays close lower tier overlays first
	- Assigns z-index based on tier + stack position
	- Calls activate() if overlay implements it
	"""
	if overlay in overlay_stack:
		# Already on stack - bring to top
		overlay_stack.erase(overlay)

	var tier = get_overlay_tier(overlay)

	# Close lower-tier overlays (higher tier takes precedence)
	while not overlay_stack.is_empty():
		var top = overlay_stack[-1]
		var top_tier = get_overlay_tier(top)
		if top_tier >= tier:
			break  # Keep overlays at same or higher tier
		pop()  # Close lower tier overlay

	# Add to stack
	overlay_stack.append(overlay)

	# Set z-index: tier + stack position for proper ordering
	overlay.z_index = tier + overlay_stack.size()

	# Activate overlay
	if overlay.has_method("activate"):
		overlay.activate()

	# Always ensure visible after activation (activate() may not set it)
	overlay.visible = true

	overlay_pushed.emit(overlay)
	stack_changed.emit()

	_update_action_preview()


func pop() -> Control:
	"""Pop the top overlay from the stack.

	- Calls deactivate() if overlay implements it
	- Returns the popped overlay, or null if stack was empty
	"""
	if overlay_stack.is_empty():
		return null

	var overlay = overlay_stack.pop_back()

	# Deactivate overlay
	if overlay.has_method("deactivate"):
		overlay.deactivate()
	else:
		overlay.visible = false

	overlay_popped.emit(overlay)
	stack_changed.emit()

	_update_action_preview()

	return overlay


func pop_overlay(overlay: Control) -> bool:
	"""Pop a specific overlay from the stack (if present).

	Returns true if overlay was found and removed.
	"""
	var idx = overlay_stack.find(overlay)
	if idx < 0:
		return false

	# If it's on top, use normal pop
	if idx == overlay_stack.size() - 1:
		pop()
		return true

	# Remove from middle of stack
	overlay_stack.remove_at(idx)

	if overlay.has_method("deactivate"):
		overlay.deactivate()
	else:
		overlay.visible = false

	overlay_popped.emit(overlay)
	stack_changed.emit()

	_update_action_preview()

	return true


func close_all() -> void:
	"""Close all overlays on the stack."""
	while not overlay_stack.is_empty():
		pop()


func get_top() -> Control:
	"""Get the topmost overlay, or null if stack is empty."""
	return overlay_stack[-1] if not overlay_stack.is_empty() else null


func is_empty() -> bool:
	"""Check if overlay stack is empty."""
	return overlay_stack.is_empty()


func has_overlay(overlay: Control) -> bool:
	"""Check if a specific overlay is on the stack."""
	return overlay in overlay_stack


func size() -> int:
	"""Get number of overlays on stack."""
	return overlay_stack.size()


# =============================================================================
# INPUT ROUTING
# =============================================================================

func route_input(event: InputEvent) -> bool:
	"""Route input to the top overlay.

	Returns true if input was consumed by an overlay.
	"""
	var top = get_top()
	if top and top.has_method("handle_input"):
		return top.handle_input(event)
	return false


func handle_escape() -> bool:
	"""Handle ESC key - closes top overlay.

	Returns true if an overlay was closed.
	"""
	if not overlay_stack.is_empty():
		pop()
		return true
	return false


# =============================================================================
# TIER MANAGEMENT
# =============================================================================

func get_overlay_tier(overlay: Control) -> int:
	"""Get the z-index tier for an overlay.

	Overlays can implement get_overlay_tier() or have overlay_tier property.
	Falls back to name-based detection.
	"""
	# Method takes priority
	if overlay.has_method("get_overlay_tier"):
		return overlay.get_overlay_tier()

	# Property check
	if "overlay_tier" in overlay:
		return overlay.overlay_tier

	# Fallback: detect from name
	var overlay_name = overlay.name if overlay.name else ""

	if "Escape" in overlay_name or "SaveLoad" in overlay_name:
		return Z_TIER_SYSTEM
	if "Quest" in overlay_name or "Biome" in overlay_name:
		return Z_TIER_MODAL

	return Z_TIER_INFO


func is_system_overlay_active() -> bool:
	"""Check if any SYSTEM tier overlay is active (EscapeMenu, SaveLoad)."""
	for overlay in overlay_stack:
		if get_overlay_tier(overlay) >= Z_TIER_SYSTEM:
			return true
	return false


func is_modal_overlay_active() -> bool:
	"""Check if any MODAL tier or higher overlay is active."""
	for overlay in overlay_stack:
		if get_overlay_tier(overlay) >= Z_TIER_MODAL:
			return true
	return false


# =============================================================================
# ACTION PREVIEW INTEGRATION
# =============================================================================

func set_overlay_manager(manager: Node) -> void:
	"""Set reference to OverlayManager for ActionPreviewRow updates."""
	overlay_manager = manager


func _update_action_preview() -> void:
	"""Update ActionPreviewRow when stack changes."""
	if not overlay_manager:
		return

	# Get action labels from top overlay
	var top = get_top()
	if top and top.has_method("get_action_labels"):
		var labels = top.get_action_labels()
		if overlay_manager.has_method("update_action_preview_for_overlay"):
			overlay_manager.update_action_preview_for_overlay(labels)
	else:
		# No overlay active - restore default actions
		if overlay_manager.has_method("restore_action_preview"):
			overlay_manager.restore_action_preview()


func get_active_action_labels() -> Dictionary:
	"""Get action labels from the top overlay for ActionPreviewRow."""
	var top = get_top()
	if top and top.has_method("get_action_labels"):
		return top.get_action_labels()
	return {}


# =============================================================================
# TOGGLE HELPERS
# =============================================================================

func toggle(overlay: Control) -> void:
	"""Toggle an overlay - push if not on stack, pop if on stack."""
	if has_overlay(overlay):
		pop_overlay(overlay)
	else:
		push(overlay)


# =============================================================================
# DEBUG
# =============================================================================

func get_stack_info() -> String:
	"""Get debug info about current stack state."""
	if overlay_stack.is_empty():
		return "Stack: [empty]"

	var info = "Stack (%d): " % overlay_stack.size()
	var names = []
	for overlay in overlay_stack:
		var name = overlay.name if overlay.name else "?"
		var tier = get_overlay_tier(overlay)
		names.append("%s(T%d)" % [name, tier / 1000])

	return info + " → ".join(names)
