class_name NullBiome
extends BiomeBase

## NullBiome - Test Biome Where Nothing Happens
##
## Used for UI testing and experiments where quantum evolution
## would interfere with UI development.
##
## Features:
## - No quantum evolution
## - No energy transfer
## - No decoherence
## - No temperature changes
## - No entanglement
## - Completely inert
##
## Extends BiomeBase but overrides _update_quantum_substrate() to do nothing.
## This is a minimal stub that satisfies the Biome interface without actually doing anything.

# Stub icons (required interface for compatibility)
var sun_qubit = null
var wheat_icon = null
var mushroom_icon = null


func _ready():
	super._ready()
	print("🪦 NullBiome initialized - No quantum evolution will occur")
	set_process(true)


func _update_quantum_substrate(dt: float) -> void:
	"""Override parent - do absolutely nothing each frame"""
	# No quantum evolution for UI testing
	pass


func get_biome_type() -> String:
	"""Return biome type identifier"""
	return "Null"


## Legacy interface stubs for compatibility with older code

func _evolve_quantum_substrate(dt: float) -> void:
	"""Stub: Don't evolve anything"""
	pass


func _update_energy_taps(dt: float) -> void:
	"""Stub: Don't transfer any energy"""
	pass


func _sync_sun_qubit(dt: float) -> void:
	"""Stub: Don't sync sun"""
	pass


func get_T1_rate(position: Vector2i) -> float:
	"""Stub: Return zero decoherence"""
	return 0.0


func get_T2_rate(position: Vector2i) -> float:
	"""Stub: Return zero dephasing"""
	return 0.0
