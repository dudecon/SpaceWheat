class_name BioticFluxIcon
extends IconHamiltonian

## Biotic Flux Icon - Quantum Order and Coherence Enhancement
## Extends LindbladIcon with growth-promoting, coherence-preserving effects
##
## The Yang to Cosmic Chaos's Yin:
## - Lowers temperature (slows decoherence)
## - Actively restores coherence (anti-entropy)
## - Accelerates growth
## - Strengthens entanglement bonds
##
## Physics: Represents quantum error correction environment
## - Optical pumping (σ_+ operator)
## - Active stabilization
## - Cooling (lower T → slower T₁/T₂)

func _ready():
	# Icon identity
	icon_name = "Biotic Flux"
	icon_emoji = "🌾"

	# Temperature modulation: COOLING effect
	base_temperature = 20.0
	temperature_scaling = -1.0  # Negative = cooling!

	# HAMILTONIAN TERMS (Pure unitary evolution - Pauli operators)
	# Biotic Flux: Strong transverse field (tunneling between states)
	# Creates and maintains superposition
	hamiltonian_terms = {
		"sigma_x": 0.3,   # Strong transverse field (tunneling/tunneling)
		"sigma_y": 0.1,   # Weak rotation
		"sigma_z": 0.05,  # Very weak Z-bias
	}



## Temperature Modulation (Cooling)

func get_effective_temperature() -> float:
	"""Calculate effective temperature from Icon activation

	Biotic Flux LOWERS temperature (quantum cooling).

	Returns:
		Temperature (Kelvin or relative units)
		- 0% activation: 20K (baseline)
		- 100% activation: ~1K (near absolute zero!)
	"""
	var cooling_amount = active_strength * 60.0
	return max(1.0, base_temperature - cooling_amount)  # Clamp to min 1K


func get_T1_modifier() -> float:
	"""Get T₁ time modifier based on Icon effects

	Cooling INCREASES T₁ time (slower energy relaxation).

	Returns:
		Multiplier for T₁ (1.0 = no effect, > 1.0 = slower damping)
	"""
	var temp = get_effective_temperature()
	# Lower temperature → longer T₁
	return 100.0 / (temp + 1.0)  # Inverse relationship


func get_T2_modifier() -> float:
	"""Get T₂ time modifier based on Icon effects

	Cooling INCREASES T₂ time (slower dephasing).

	Returns:
		Multiplier for T₂ (1.0 = no effect, > 1.0 = slower dephasing)
	"""
	var temp = get_effective_temperature()
	# Lower temperature → longer T₂
	return 100.0 / (temp + 1.0)


## Coherence Enhancement (Direct)

func apply_to_qubit(qubit, dt: float) -> void:
	"""Apply Icon's quantum effects to a single qubit

	Biotic Flux actively RESTORES coherence (moves toward superposition).

	Args:
		qubit: DualEmojiQubit to affect
		dt: Time step (seconds)
	"""
	if active_strength <= 0.0:
		return

	# Skip if qubit is part of entangled pair (handled at pair level)
	if qubit.entangled_pair != null:
		return

	# Set environment temperature (cooling)
	var temp = get_effective_temperature()
	qubit.environment_temperature = temp

	# Direct coherence restoration (move toward superposition)
	_apply_coherence_restoration(qubit, dt)


func _apply_coherence_restoration(qubit, dt: float) -> void:
	"""Directly restore coherence by moving qubit toward equator

	This represents active error correction / dynamical decoupling.

	The equator (θ = π/2) is maximum superposition = maximum coherence.
	"""
	var restoration_rate = 0.05 * active_strength  # 5% per second at full activation
	var target_theta = PI / 2.0  # Equator

	# Gently pull toward superposition
	qubit.theta = lerp(qubit.theta, target_theta, restoration_rate * dt)


## Growth Acceleration

func get_growth_modifier() -> float:
	"""Get growth rate multiplier for wheat cultivation

	Biotic Flux accelerates growth, but Carrion Throne (Imperium) REDUCES it.
	Creates strategic tension: more wheat → more Biotic Flux → counters Imperium pressure.

	Returns:
		Growth speed multiplier (1.0x to 2.0x base, reduced by Imperium)
	"""
	var base_growth = 1.0 + (active_strength * 1.0)  # Up to 2x at full Biotic Flux

	# Imperium Icon creates decoherence pressure that REDUCES growth
	if imperium_icon and imperium_icon.active_strength > 0.0:
		# Imperium reduces growth: 100% - (20% × Imperium strength)
		# At 0.2 Imperium (baseline): 4% reduction
		# At 1.0 Imperium (max): 20% reduction
		var imperium_reduction = 1.0 - (imperium_icon.active_strength * 0.2)
		base_growth *= imperium_reduction

	return base_growth


## Entanglement Enhancement

func get_entanglement_strength_modifier() -> float:
	"""Get entanglement strength multiplier

	Biotic Flux strengthens quantum bonds (harder to break).

	Returns:
		Entanglement strength multiplier (1.0x to 1.5x)
	"""
	return 1.0 + (active_strength * 0.5)


## Environmental Effects (Biotic-specific, can be extended by subclasses)

var environmental_effects: Dictionary = {
	# Effect type -> strength/params
	"sun_damage": 0.8,  # Damage rate at peak sun - dampens fungi when sun is strong
}

func apply_environmental_effect(target_qubit, sun_qubit, dt: float) -> void:
	"""Apply any environmental effects from this icon to a qubit

	Character-agnostic design: Icon defines what effects to apply,
	not which crops to apply them to.

	Args:
		target_qubit: DualEmojiQubit to apply effects to
		sun_qubit: DualEmojiQubit representing celestial cycle
		dt: Time step (seconds)
	"""
	if not target_qubit or not sun_qubit:
		return

	# Sun damage effect: peaks during sun (noon), zero during night
	# Applied continuously via cos² coupling to sun phase
	if environmental_effects.has("sun_damage"):
		var damage_strength = environmental_effects["sun_damage"]
		var sun_phase_strength = pow(cos(sun_qubit.theta / 2.0), 2)
		var damage_rate = damage_strength * sun_phase_strength

		# Apply as negative energy transfer (exponential decay)
		target_qubit.grow_energy(-damage_rate, dt)


## Icon Interactions

var imperium_icon = null  # Reference to competing Imperium Icon for growth modifier

func set_competing_icon(icon) -> void:
	"""Set reference to competing Imperium Icon"""
	imperium_icon = icon


## Activation Logic

func calculate_activation_from_wheat(wheat_count: int, total_plots: int) -> float:
	"""Calculate activation based on wheat cultivation

	Biotic Flux emerges naturally as player cultivates wheat.

	Args:
		wheat_count: Number of planted wheat plots
		total_plots: Total plot capacity

	Returns:
		Activation strength (0.0 to 1.0)
	"""
	if total_plots <= 0:
		active_strength = 0.0
		return 0.0

	# Base activation from wheat coverage
	var base_activation = float(wheat_count) / float(total_plots)

	# TODO: Bonus for high entanglement network density
	# This would reward building complex topologies
	var entanglement_bonus = 0.0

	# Total activation
	active_strength = clamp(base_activation + entanglement_bonus, 0.0, 1.0)

	return active_strength


## Visual Effects

func get_visual_effect() -> Dictionary:
	"""Return visual effect parameters for rendering

	Biotic Flux: Bright green, flowing, coherent (opposite of Cosmic Chaos).
	"""
	return {
		"type": "biotic_field",
		"color": Color(0.3, 0.8, 0.3, 0.6),  # Bright green with transparency
		"particle_type": "flowing",          # Organized flow patterns
		"flow_pattern": "coherent",          # Smooth, ordered movement
		"sound": "growth_hum",               # Organic resonance
		"glow_radius": int(active_strength * 15),
		"coherence_overlay": active_strength * 0.4,  # Green tint on screen
		"particle_density": int(active_strength * 50),
		"intensity": active_strength
	}


## Icon Effects Summary

func get_physics_description() -> String:
	"""Return human-readable description of Icon's physical effects

	For educational tooltips and codex entries.
	"""
	var desc = "[%s %s]\n" % [icon_emoji, icon_name]

	desc += "Temperature: %.1f K (%.0f%% cooling)\n" % [
		get_effective_temperature(),
		(1.0 - get_effective_temperature() / base_temperature) * 100
	]

	desc += "Coherence Restoration: +%.1f%%/s\n" % (active_strength * 5.0)
	desc += "Growth Rate: %.1fx\n" % get_growth_modifier()
	desc += "Entanglement Strength: %.1fx\n" % get_entanglement_strength_modifier()
	desc += "\nPhysics: Quantum error correction environment (pure Hamiltonian)"

	return desc


## Debug

func get_debug_string() -> String:
	var base = super.get_debug_string()
	var temp = get_effective_temperature()
	var growth = get_growth_modifier()
	return base + " | T=%.1fK | Growth: %.2fx" % [temp, growth]
