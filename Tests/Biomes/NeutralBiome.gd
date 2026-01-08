class_name NeutralBiome
extends BiomeBase

## NeutralBiome - Static environment for game loop testing
## Extends BiomeBase but disables all quantum evolution
## Plants stay at their planted state indefinitely with no changes
## Perfect for testing planting, harvesting, measurement mechanics without quantum complexity

# Sun/moon qubit (static - stays at constant position)
var sun_qubit = null


func _process(dt: float) -> void:
	"""Override: Do nothing - this is a static environment"""
	time_tracker.update(dt)  # Still track time, but no quantum evolution
	# Biome infrastructure is intact (icons, temperature, etc.)
	# But NO quantum evolution happens:
	# - No sun/moon qubit cycling
	# - No Hamiltonian evolution
	# - No energy transfer between plots
	# - No decoherence or coherence changes
	#
	# Plants maintain their initial quantum state indefinitely


func _update_quantum_substrate(dt: float) -> void:
	"""Override parent: Do nothing - no quantum evolution"""
	# Keep sun at constant theta = PI/4 (45°) - balanced between sun and moon
	if sun_qubit:
		sun_qubit.theta = PI / 4.0


func get_biome_type() -> String:
	"""Return biome type identifier"""
	return "Neutral"


## Legacy interface stubs for compatibility

func _sync_sun_qubit(dt: float) -> void:
	"""Override: Sun stays at fixed 45° (balanced superposition)"""
	if not sun_qubit:
		return
	sun_qubit.theta = PI / 4.0


func _update_hamiltonian(dt: float) -> void:
	"""Override: Do nothing - no quantum evolution"""
	pass


func _update_energy_transfer(dt: float) -> void:
	"""Override: Do nothing - plants don't grow or change"""
	pass


func _update_energy_taps(dt: float) -> void:
	"""Override: Do nothing - no energy taps"""
	pass


func _update_decoherence(dt: float) -> void:
	"""Override: Do nothing - no coherence loss"""
	pass


func _update_entanglement_dynamics(dt: float) -> void:
	"""Override: Do nothing - no entanglement evolution"""
	pass
