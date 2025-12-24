class_name ImperiumIcon
extends IconHamiltonian

## Imperium Icon - Quotas, Authority, Extraction, Control
## Represents the Carrion Throne's influence on the conspiracy network
##
## Quantum Layer: Enforces ordered collapse, biases measurements toward classical states
## Classical Layer: Modulates conspiracy network and faction influence

# Temperature modulation (neutral - no thermal effects)

func _init():
	icon_name = "Carrion Throne"
	icon_emoji = "🏰"

	# HAMILTONIAN TERMS (Pure unitary evolution - Pauli operators)
	# Imperium: Strong longitudinal field (pins to specific state)
	# Suppresses superposition, enforces classical order
	hamiltonian_terms = {
		"sigma_x": 0.0,   # No transverse field
		"sigma_y": 0.0,   # No rotation
		"sigma_z": 0.5,   # Strong Z-field (energy gap, pinning effect)
	}

	spatial_extent = 500.0  # Wide-reaching imperial authority


func _initialize_couplings():
	# Strongly coupled to economic and control nodes
	node_couplings["market"] = 0.9        # Strongly affects market dynamics
	node_couplings["ripening"] = 0.7      # Controls timing/deadlines
	node_couplings["sauce"] = 0.6         # Industrial transformation
	node_couplings["observer"] = 0.5      # Surveillance
	node_couplings["genetic"] = 0.4       # Genetic control

	# Suppresses freedom and meaning
	node_couplings["meaning"] = -0.3      # Suppresses semantic freedom
	node_couplings["identity"] = -0.5     # Reduces autonomy

	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_BIOME") == "1":
			print("🏰 Imperium Icon initialized with %d node couplings" % node_couplings.size())


## Temperature Modulation

func get_effective_temperature() -> float:
	"""Imperium has neutral temperature (no thermal effects)

	Unlike Biotic (cooling) or Chaos (heating), Imperium operates
	through measurement and control, not thermal manipulation.
	"""
	return base_temperature + (temperature_scaling * active_strength * 80.0)


## Quantum Layer: No direct qubit modification
## (Qubit freezing is now handled by ImperialPlot mechanics, not Icon level)


func get_growth_modifier() -> float:
	"""Get growth rate multiplier for wheat cultivation

	Imperium bureaucracy slows growth due to regulations and extraction.

	Returns:
		Growth speed multiplier (0.7x to 1.0x)
	"""
	return 1.0 - (active_strength * 0.3)  # Up to -30% growth at full activation


## Calculate activation based on quota urgency
func calculate_activation_from_quota(urgency: float) -> void:
	# urgency should be 0.0 (no pressure) to 1.0 (deadline imminent)
	set_activation(clamp(urgency, 0.0, 1.0))


## Calculate activation based on time remaining
func calculate_activation_from_deadline(time_remaining: float, total_time: float) -> void:
	var urgency = 1.0 - clamp(time_remaining / total_time, 0.0, 1.0)
	set_activation(urgency)


## Calculate activation based on tribute success rate
func calculate_activation_from_tribute(tributes_paid: int, tributes_failed: int) -> void:
	"""Calculate Imperium activation based on tribute compliance

	Failed tributes increase Imperium pressure (more aggressive extraction).
	Successful tributes reduce pressure (appeasement).

	Args:
		tributes_paid: Number of successful tributes
		tributes_failed: Number of failed tributes
	"""
	var total_tributes = tributes_paid + tributes_failed
	if total_tributes == 0:
		set_activation(0.2)  # Baseline Imperial presence
		return

	# More failures → higher activation (Imperium becomes more aggressive)
	var failure_rate = float(tributes_failed) / float(total_tributes)
	var base_activation = 0.2 + (failure_rate * 0.6)  # 20% baseline, up to 80%

	set_activation(clamp(base_activation, 0.0, 1.0))
