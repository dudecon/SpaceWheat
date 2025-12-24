class_name ChaosIcon
extends IconHamiltonian

## Chaos Icon - Transformation, Unpredictability, Decoherence, Emergence
## Amplifies conspiracy activations and creates chaotic behavior
##
## Quantum Layer: Adds stochastic noise and phase randomization to qubits
## Classical Layer: Modulates conspiracy network evolution

# Override temperature modulation (heating - increases decoherence)
# Note: base_temperature and temperature_scaling are inherited from IconHamiltonian

func _init():
	icon_name = "Chaos Vortex"
	icon_emoji = "🍅"

	# HAMILTONIAN TERMS (Pure unitary evolution - Pauli operators)
	# Chaos: Stochastic/random Hamiltonian (different each frame)
	# Creates unpredictability and emergence
	hamiltonian_terms = {
		"sigma_x": randf_range(-0.2, 0.2),   # Random transverse field
		"sigma_y": randf_range(-0.2, 0.2),   # Random rotation
		"sigma_z": randf_range(-0.1, 0.1),   # Random Z bias
	}

	spatial_extent = 400.0


func _initialize_couplings():
	# Strongly enhance chaos-related nodes
	node_couplings["meta"] = 1.0          # Maximum coupling to self-reference
	node_couplings["identity"] = 0.9      # Enhances fruit/vegetable duality
	node_couplings["underground"] = 0.8   # Amplifies hive-mind
	node_couplings["observer"] = 0.7      # Strengthens observer effects
	node_couplings["sauce"] = 0.6         # Transformation processes
	node_couplings["ripening"] = 0.5      # Temporal chaos
	node_couplings["market"] = 0.4        # Economic unpredictability

	# Suppress order
	node_couplings["seed"] = -0.4         # Disrupts orderly growth
	node_couplings["solar"] = -0.3        # Reduces stable energy

	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_BIOME") == "1":
			print("🍅 Chaos Icon initialized with %d node couplings" % node_couplings.size())


## Temperature Modulation

func get_effective_temperature() -> float:
	"""Chaos increases temperature (more decoherence, more chaos)

	Returns:
		Temperature that increases with Chaos activation
	"""
	return base_temperature + (temperature_scaling * active_strength * 80.0)


## Quantum Layer: Apply stochastic noise to qubit states

func apply_to_qubit(qubit, dt: float) -> void:
	"""Apply chaotic quantum noise to a single qubit

	Chaos Icon adds stochastic fluctuations to quantum states:
	- Random phase kicks (drunken walk in Bloch sphere)
	- Theta randomization (energy fluctuations)
	- Increased decoherence via temperature

	Args:
		qubit: DualEmojiQubit to affect
		dt: Time step (seconds)
	"""
	if active_strength <= 0.0:
		return

	# Skip if qubit is part of entangled pair (handled at pair level)
	if qubit.entangled_pair != null:
		return

	# Apply quantum noise (stochastic Hamiltonian modulation)
	_apply_quantum_noise(qubit, dt)


func _apply_quantum_noise(qubit, dt: float) -> void:
	"""Add stochastic noise to qubit parameters

	Implements random walk in Bloch sphere:
	- Phase (phi): Random kicks → dephasing
	- Theta: Random fluctuations → energy uncertainty
	"""
	var noise_strength = 0.3 * active_strength  # 30% noise at full activation

	# Random phase kicks (Wiener process)
	var phase_noise = randfn(0.0, 1.0) * noise_strength * sqrt(dt)
	qubit.phi += phase_noise
	qubit.phi = fmod(qubit.phi + PI, TAU) - PI  # Wrap to [-π, π]

	# Random theta fluctuations (energy uncertainty)
	var theta_noise = randfn(0.0, 1.0) * noise_strength * 0.5 * sqrt(dt)
	qubit.theta = clamp(qubit.theta + theta_noise, 0.0, PI)

	# Increase temperature (more decoherence)
	qubit.environment_temperature += active_strength * 50.0 * dt


func get_growth_modifier() -> float:
	"""Get growth rate multiplier for wheat cultivation

	Chaos creates unpredictability - sometimes faster, sometimes slower.

	Returns:
		Growth speed multiplier (0.8x to 1.4x, average ~1.1x)
	"""
	if active_strength <= 0.0:
		return 1.0

	# Random growth boost/penalty
	var random_factor = randf_range(-0.2, 0.4) * active_strength
	return clamp(1.0 + random_factor, 0.8, 1.4)


## Calculate activation based on active conspiracy count
func calculate_activation_from_conspiracies(active_count: int, max_conspiracies: int = 12) -> void:
	var strength = float(active_count) / float(max_conspiracies)
	set_activation(strength)
