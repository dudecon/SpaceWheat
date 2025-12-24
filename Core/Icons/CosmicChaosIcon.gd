class_name CosmicChaosIcon
extends LindbladIcon

## Cosmic Chaos Icon - Entropy, Void, Decoherence (REAL PHYSICS)
## Represents environmental dephasing bath and thermal noise
##
## Physics: Dephasing channel + weak amplitude damping
## Always active (min 20%) - entropy never stops

func _init():
	icon_name = "Cosmic Chaos"
	icon_emoji = "🌌"

	# Temperature: Chaos increases effective temperature
	base_temperature = 20.0
	temperature_scaling = 3.0  # Strong temperature modulation

	# Evolution bias for conspiracy nodes (legacy tomato growth) - DEPRECATED
	# This was used in old tomato growth system, no longer active
	#evolution_bias = Vector3(
	#	0.0,    # No theta drift (doesn't favor 🌾 or 👥)
	#	0.8,    # High phi noise (random phase kicks)
	#	0.05    # Moderate damping (energy dissipation)
	#)

	# Affects entire farm (entropy is everywhere)
	spatial_extent = 1000.0


func _initialize_couplings():
	# Chaos couples strongly to META nodes (self-reference, paradox, meaning)
	node_couplings["meta"] = 1.0
	node_couplings["identity"] = 0.9
	node_couplings["meaning"] = 0.8

	# Also enhances underground/hidden/mysterious
	node_couplings["underground"] = 0.7

	# Suppresses order and stability nodes
	node_couplings["seed"] = -0.5
	node_couplings["solar"] = -0.4
	node_couplings["water"] = -0.4
	node_couplings["ripening"] = -0.3

	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_BIOME") == "1":
			print("🌌 Cosmic Chaos Icon initialized with %d node couplings" % node_couplings.size())


func _initialize_jump_operators():
	"""Chaos = Dephasing bath + weak damping

	Physics interpretation:
	- Dephasing (σ_z): Random phase noise from environment
	- Damping (σ_-): Energy loss to thermal bath

	These are REAL decoherence channels in quantum optics!
	"""
	# Strong dephasing (phase randomization)
	jump_operators.append({
		"operator_type": "dephasing",
		"base_rate": 0.15  # High dephasing rate
	})

	# Weak amplitude damping (energy loss)
	jump_operators.append({
		"operator_type": "damping",
		"base_rate": 0.05  # Moderate damping
	})

	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_BIOME") == "1":
			print("🌌 Cosmic Chaos: Initialized %d Lindblad operators" % jump_operators.size())


## Calculate activation based on void items or emptiness
func calculate_activation_from_void(void_count: int, total_items: int) -> void:
	"""Activation increases with emptiness or void items

	Args:
		void_count: Number of 'void' items explicitly placed
		total_items: Total items on farm (wheat + tomatoes + etc)
	"""
	# Base activation from void items (if we had them)
	var void_strength = 0.0
	if total_items > 0:
		void_strength = float(void_count) / max(1.0, total_items * 0.1)

	# Also activates when farm is EMPTY (nothingness)
	var emptiness_strength = 1.0 - (float(total_items) / 100.0)

	# Chaos is ALWAYS at least weakly active (entropy never stops)
	# Minimum 20%, up to 100%
	var total_strength = clamp(max(void_strength, emptiness_strength), 0.2, 1.0)

	set_activation(total_strength)


## Legacy decoherence modifier (deprecated, use Lindblad framework instead)
func get_decoherence_modifier() -> float:
	"""Return decoherence rate multiplier based on activation

	DEPRECATED: Use get_T1_modifier() and get_T2_modifier() instead.

	Returns:
		1.0 to 3.0 multiplier for decoherence rate
	"""
	# Map to effective temperature modulation
	return 1.0 / get_T1_modifier()


## Visual effect parameters (for UI bot to use)
func get_visual_effect() -> Dictionary:
	"""Return visual effect parameters for rendering

	UI bot can use these to create appropriate effects
	"""
	return {
		"type": "chaos_void",
		"color": Color(0.1, 0.0, 0.2, 0.8),  # Dark purple/black
		"particle_type": "static",  # Visual noise/static
		"flow_pattern": "dissolving",  # Things fade/break apart
		"sound": "void_whisper",  # Eerie ambient sound
		"tendril_count": int(active_strength * 20),  # More tendrils when stronger
		"screen_desaturation": active_strength * 0.3  # Desaturate screen
	}


## Apply quantum effects to all plots (called by game manager)
func apply_quantum_effects_to_plots(plots: Array, delta: float) -> void:
	"""Apply Chaos Icon's quantum effects to all wheat plots

	Uses Lindblad framework for physically accurate decoherence.

	Args:
		plots: Array of WheatPlot (with .quantum_state)
		delta: Time step (seconds)
	"""
	if active_strength <= 0.0:
		return

	for plot in plots:
		if plot.quantum_state:
			apply_to_qubit(plot.quantum_state, delta)
