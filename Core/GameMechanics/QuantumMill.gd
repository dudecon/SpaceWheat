class_name QuantumMill
extends Node2D

## QuantumMill v2: Icon Injection Portal
##
## The Mill is a PASSIVE structure that injects flour dynamics into the parent biome.
## It does NOT measure. Instead, it enables the Flour Icon's Hamiltonian coupling:
##
##   Wheat ↔ Flour rotation (populations oscillate between states)
##
## Architecture:
##   - Injects 💨 (Flour) Icon into parent biome
##   - Flour Icon defines hamiltonian_couplings to 🌾 (wheat)
##   - Biome's bath automatically builds rotation dynamics
##   - Mill itself is passive (no _process needed)

## Configuration
var grid_position: Vector2i = Vector2i.ZERO
var parent_biome = null
var is_active: bool = false

## Statistics
var flour_injection_time: float = 0.0


func _ready():
	print("🏭 QuantumMill initialized at %s" % grid_position)


## ========================================
## Activation
## ========================================

func activate(biome) -> bool:
	"""
	Activate mill by injecting Flour dynamics into biome.

	Args:
	    biome: Parent BiomeBase that owns the quantum computer

	Returns:
	    true if activation successful, false otherwise
	"""
	parent_biome = biome

	if not parent_biome:
		push_error("Mill: has no parent biome!")
		return false

	# Get Flour Icon from registry
	var flour_icon = IconRegistry.get_icon("💨")
	if not flour_icon:
		push_error("Mill: Flour Icon not registered in IconRegistry!")
		return false

	# Inject Flour Icon into biome
	# The flour Icon's hamiltonian_couplings define wheat ↔ flour rotation
	if parent_biome.has_method("inject_icon"):
		var success = parent_biome.inject_icon(flour_icon)
		if success:
			is_active = true
			flour_injection_time = Time.get_ticks_msec() / 1000.0
			print("🏭 Mill active: Flour dynamics enabled at %s" % grid_position)
			print("   Flour ↔ Wheat coupling strength: %.3f" % flour_icon.hamiltonian_couplings.get("🌾", 0.0))
			return true
	else:
		push_error("Mill: Parent biome has no inject_icon method!")

	return false


## ========================================
## Status
## ========================================

func get_debug_info() -> Dictionary:
	"""Return mill state for debugging"""
	return {
		"position": grid_position,
		"is_active": is_active,
		"parent_biome": parent_biome.get_biome_type() if parent_biome else "none",
		"injection_time": flour_injection_time,
	}


func is_working() -> bool:
	"""Check if mill is actively injecting flour dynamics"""
	return is_active
