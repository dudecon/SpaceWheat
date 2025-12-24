class_name Biome
extends Node

## Biome - Environmental quantum ecosystem
## Manages all quantum objects: celestial (sun/moon), native (biome-specific), farm (plantable)
## Manages Icons: wheat_icon (🌾↔🏰 agrarian/imperium)
## Manages temperature, decoherence, and all quantum couplings

# Import dependencies
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

# Celestial objects (immutable, drive the system)
var sun_qubit: DualEmojiQubit = null  # (☀️, 🌙) - immutable celestial anchor
var time_elapsed: float = 0.0  # Absolute time for cycling
var sun_moon_period: float = 20.0  # seconds for full day-night cycle

# Icon Hamiltonians (environmental modifiers with quantum state and coupling terms)
var wheat_icon = null  # WheatIcon - defines Hamiltonian terms and influence
var mushroom_icon = null  # MushroomIcon - defines Hamiltonian terms and influence
var biotic_flux_icon = null  # Reference to Biotic Flux Icon (environmental error correction)
var imperium_icon = null  # Reference to Imperium Icon (order/extraction)

# Energy transfer parameters (non-Hamiltonian, affects radius/energy only)
# Tuned for 3-day growth: 0.3→0.9 in 60 seconds (3 full sun-moon cycles)
# With alignment formula: rate_avg = base * amplitude * alignment_avg * icon_influence
# Alignment averages to 0.5 over a full day-night cycle
var base_energy_rate: float = 2.45
var wheat_energy_influence: float = 0.017  # cos²(165°/2) - weak (wheat grows minimally alone)
var mushroom_energy_influence: float = 0.025  # Balanced with wheat, not dominant

# Plot type system: Biome owns ALL qubits regardless of type
enum PlotType { CELESTIAL, NATIVE, FARM }
var plots_by_type: Dictionary = {  # PlotType -> Array[Vector2i]
	PlotType.CELESTIAL: [],
	PlotType.NATIVE: [],
	PlotType.FARM: []
}
var plot_types: Dictionary = {}  # Vector2i -> PlotType (to look up type of position)

# Conspiracy network removed (DISABLED)

# Grid reference (injected by Farm) - used for phase constraints
var grid = null  # FarmGrid reference

# Static mode flag (for testing without quantum evolution)
var is_static: bool = false  # If true, disable all quantum evolution

# Temperature control (Kelvin)
var base_temperature: float = 300.0  # 300K baseline
var temperature_grid: Dictionary = {}  # Vector2i(x,y) -> local_temperature

# Decoherence base rates (modified by temperature)
var T1_base_rate: float = 0.001  # Amplitude damping
var T2_base_rate: float = 0.002  # Phase damping

# Quantum substrate - manages DualEmojiQubit instances
var quantum_states: Dictionary = {}  # Vector2i(position) -> DualEmojiQubit
var signals: Dictionary = {}  # Emitted when quantum states change

signal qubit_created(position: Vector2i, qubit: Resource)
signal qubit_measured(position: Vector2i, outcome: String)
signal qubit_evolved(position: Vector2i)


func _ready():
	set_process(true)

	# Initialize celestial sun/moon qubit (immutable, eternal)
	sun_qubit = DualEmojiQubit.new("☀️", "🌙", 0.0)  # Start at north (☀️ = full day)
	sun_qubit.radius = 1.0  # Always pure, never decoheres
	plots_by_type[PlotType.CELESTIAL].append(Vector2i(-1, -1))  # Special position
	plot_types[Vector2i(-1, -1)] = PlotType.CELESTIAL
	quantum_states[Vector2i(-1, -1)] = sun_qubit

	# Initialize wheat and mushroom icons with stable points and spring constants
	# Fallback: Create icon objects directly if script loading fails

	# WHEAT ICON - Create fallback directly to avoid script loading issues
	wheat_icon = {
		"hamiltonian_terms": {"sigma_x": 0.0, "sigma_y": 0.0, "sigma_z": 0.1},
		"stable_theta": PI / 4.0,
		"spring_constant": 0.5
	}
	wheat_energy_influence = 0.017

	# MUSHROOM ICON - Create fallback directly
	mushroom_icon = {
		"hamiltonian_terms": {"sigma_x": 0.0, "sigma_y": 0.0, "sigma_z": 0.023},
		"stable_theta": PI,
		"spring_constant": 0.5
	}
	mushroom_energy_influence = 0.04

	# TODO: Initialize biotic flux icon when script parsing issues are resolved
	# For now, sun damage to fungi is applied directly in _apply_energy_transfer()

	print("🌍 Biome initialized - Temperature: %.0fK, Period: %.1fs" % [base_temperature, sun_moon_period])
	print("  ☀️ Sun/Moon qubit initialized (immutable celestial)")
	print("  🌾 Wheat icon initialized (spring: %.1f, stable: π/4)" % wheat_icon.spring_constant)
	print("  🍄 Mushroom icon initialized (spring: %.1f, stable: π)" % mushroom_icon.spring_constant)


func _process(dt: float):
	"""Update biome each frame"""
	# Skip all evolution if in static mode (for testing)
	if is_static:
		return

	# Standard biome evolution enabled by default
	_sync_sun_qubit(dt)
	_evolve_sun_moon_cycle(dt)
	_update_temperature_from_cycle()
	_update_energy_taps(dt)
	_evolve_quantum_substrate(dt)


func _sync_sun_qubit(dt: float):
	"""Advance sun qubit through day-night cycle

	Sun's theta cycles from 0→2π over sun_moon_period seconds.
	Phi and radius stay constant (sun never decoheres).
	"""
	if not sun_qubit:
		return

	time_elapsed += dt

	# Cycle theta through full period
	var cycle_progress = fmod(time_elapsed, sun_moon_period) / sun_moon_period
	sun_qubit.theta = cycle_progress * TAU

	# Keep sun locked to north pole (phi doesn't matter for σ_z coupling, but keep constant)
	sun_qubit.phi = 0.0
	sun_qubit.radius = 1.0  # Always pure


func _evolve_sun_moon_cycle(dt: float):
	"""Deprecated - sun_qubit.theta is now synced directly in _sync_sun_qubit"""
	# No longer using sun_moon_phase - using time_elapsed and sun_qubit.theta instead
	pass


func _update_temperature_from_cycle():
	"""Temperature varies with sun cycle

	Physics model:
	- Peak temperature during sun phase (θ near 0 or π, but cos(θ) peaks at θ=0)
	- Minimum temperature during transition phases
	- Temperature = base + 50 * (1 - cos(sun.theta))
	"""
	if not sun_qubit:
		return

	var heat_factor = (1.0 - cos(sun_qubit.theta)) * 50.0
	base_temperature = 300.0 + heat_factor


## Decoherence Rate Queries

func get_T1_rate(position: Vector2i) -> float:
	"""Get amplitude damping rate (T1) at position

	T1 increases with temperature (hotter → faster energy loss)
	"""
	var temp = temperature_grid.get(position, base_temperature)
	return T1_base_rate * (temp / 300.0)


func get_T2_rate(position: Vector2i) -> float:
	"""Get phase damping rate (T2) at position

	T2 increases with temperature (hotter → faster dephasing)
	"""
	var temp = temperature_grid.get(position, base_temperature)
	return T2_base_rate * (temp / 300.0)


## Quantum Couplings (NEW)

func _apply_quantum_couplings(dt: float) -> void:
	"""Apply emoji-agnostic quantum couplings between qubits

	Order of operations:
	1. Sun → Wheat Icon: Sun drives icon toward wheat alignment
	2. Wheat qubits → Wheat Icon: Plants couple back to icon (feedback)
	3. Icon influences plant growth via energy modulation
	"""
	if not sun_qubit or not wheat_icon:
		return

	# 1. Sun drives wheat_icon toward sun's phase
	_couple_sun_to_wheat_icon(dt)

	# 2. Farm wheat qubits couple back to wheat_icon (collective feedback)
	_couple_wheat_qubits_to_wheat_icon(dt)


func _couple_sun_to_wheat_icon(dt: float) -> void:
	"""Sun couples to wheat_icon via σ_z interaction

	H = J × σ_z_sun × σ_z_wheat_icon
	Effect: Icon's theta drifts toward sun's theta
	"""
	if not sun_qubit or not wheat_icon:
		return

	# Skip coupling if icon doesn't have internal_qubit (fallback dict)
	if wheat_icon is Dictionary:
		if not wheat_icon.has("internal_qubit"):
			return
	elif not wheat_icon.internal_qubit:
		return

	# Coupling strength (sun always influences icon equally)
	var J = 0.3  # Base coupling constant

	# Apply σ_z coupling: drags icon theta toward sun theta
	var theta_error = sun_qubit.theta - wheat_icon.internal_qubit.theta
	# Use shortest path on circle
	if abs(theta_error) > PI:
		theta_error = theta_error - sign(theta_error) * TAU

	wheat_icon.internal_qubit.theta += theta_error * J * dt


func _couple_wheat_qubits_to_wheat_icon(dt: float) -> void:
	"""Farm wheat qubits couple back to icon (collective feedback)

	All wheat (🌾) qubits provide feedback, pulling icon toward agricultural alignment.
	This represents the system's tendency toward growth when full of crops.
	"""
	if not wheat_icon:
		return

	var wheat_count = 0
	var wheat_alignment = 0.0

	# Count wheat qubits in farm plots and measure their alignment
	for position in plots_by_type[PlotType.FARM]:
		var qubit = quantum_states.get(position)
		if not qubit or qubit.north_emoji != "🌾":
			continue

		wheat_count += 1
		# Measure how "wheat-like" this qubit is (north bias)
		var north_prob = pow(cos(qubit.theta / 2.0), 2)
		wheat_alignment += north_prob

	if wheat_count == 0:
		return

	# Average alignment of all wheat
	wheat_alignment /= wheat_count

	# Icon tends toward 🌾 (north) when surrounded by wheat
	var coupling_strength = 0.1 * wheat_alignment
	var target_theta = 0.0  # Try to stay agricultural (🌾)
	if wheat_icon.internal_qubit:
		wheat_icon.internal_qubit.theta += (target_theta - wheat_icon.internal_qubit.theta) * coupling_strength * dt


## Energy Growth (Quantum-Classical Divide)

## Dissipation Application (Lindblad Terms)

func apply_dissipation(qubit: DualEmojiQubit, position: Vector2i, dt: float):
	"""Apply Lindblad dissipation (energy loss + dephasing)

	Separate from Hamiltonian evolution!
	Called AFTER Hamiltonian in evolution loop.
	"""
	if not qubit:
		return

	var T1_rate = get_T1_rate(position)
	var T2_rate = get_T2_rate(position)

	# Amplitude damping (T1: energy loss to environment)
	qubit.apply_amplitude_damping(T1_rate * dt)

	# Phase damping (T2: pure dephasing)
	qubit.apply_phase_damping(T2_rate * dt)


## Sun/Moon Queries

func is_currently_sun() -> bool:
	"""Returns true if in sun phase (theta ∈ [0, π))"""
	if not sun_qubit:
		return false
	return sun_qubit.theta < PI


func get_sun_moon_time_remaining() -> float:
	"""Get seconds until next phase transition"""
	if not sun_qubit:
		return 0.0

	var phase_in_half_cycle = fmod(sun_qubit.theta, PI)
	var fraction_through = phase_in_half_cycle / PI
	var time_in_half_cycle = sun_moon_period / 2.0
	return (1.0 - fraction_through) * time_in_half_cycle


## Energy Level Query

func get_energy_strength() -> float:
	"""Get current biome energy level (0.0 to 1.0)

	Used for visualization and feedback systems
	Peaks at noon (sun.theta=0) and midnight (sun.theta=π)
	Valleys at dawn/dusk (sun.theta=π/2, 3π/2)
	Returns magnitude of cos(sun.theta)
	"""
	if not sun_qubit:
		return 0.0
	return abs(cos(sun_qubit.theta))


## Temperature Queries

func get_temperature(position: Vector2i) -> float:
	"""Get temperature at specific position"""
	return temperature_grid.get(position, base_temperature)


func set_local_temperature_override(position: Vector2i, temperature: float):
	"""Allow infrastructure to set local temperature override (future use)"""
	temperature_grid[position] = clamp(temperature, 1.0, 1000.0)


func clear_temperature_override(position: Vector2i):
	"""Remove local temperature override"""
	if position in temperature_grid:
		temperature_grid.erase(position)


## Debug Info

func get_debug_info() -> Dictionary:
	"""Return biome state for debugging"""
	var sun_theta = 0.0
	var icon_theta = 0.0
	if sun_qubit:
		sun_theta = sun_qubit.theta
	if wheat_icon and wheat_icon is Dictionary and wheat_icon.has("internal_qubit"):
		icon_theta = wheat_icon.internal_qubit.theta

	return {
		"temperature": base_temperature,
		"sun_theta": sun_theta,
		"sun_theta_degrees": sun_theta * 180.0 / PI,
		"icon_theta": icon_theta,
		"icon_theta_degrees": icon_theta * 180.0 / PI,
		"is_sun": is_currently_sun(),
		"energy_strength": get_energy_strength(),
		"time_remaining": get_sun_moon_time_remaining(),
		"T1_rate": T1_base_rate * (base_temperature / 300.0),
		"T2_rate": T2_base_rate * (base_temperature / 300.0),
	}


## Quantum Substrate Management (Emoji Math)

func create_quantum_state(position: Vector2i, north_emoji: String, south_emoji: String, initial_theta: float = PI/2) -> Resource:
	"""Create a new DualEmojiQubit at position in equal superposition

	Returns: DualEmojiQubit in |+⟩ state (theta = π/2)
	Emits: qubit_created signal
	"""
	var qubit = DualEmojiQubit.new(north_emoji, south_emoji, initial_theta)
	quantum_states[position] = qubit
	qubit_created.emit(position, qubit)
	return qubit


func get_qubit(position: Vector2i) -> Resource:
	"""Get DualEmojiQubit at position, or null if none exists"""
	return quantum_states.get(position)


func measure_qubit(position: Vector2i) -> String:
	"""Measure (collapse) qubit at position

	Returns: Emoji outcome (north_emoji or south_emoji)
	Emits: qubit_measured signal
	"""
	var qubit = quantum_states.get(position)
	if not qubit:
		return ""

	var outcome = qubit.measure()
	qubit_measured.emit(position, outcome)
	return outcome


func clear_qubit(position: Vector2i) -> void:
	"""Remove quantum state at position (after harvest)"""
	if position in quantum_states:
		quantum_states.erase(position)


func get_semantic_state(position: Vector2i) -> String:
	"""Get current semantic state of qubit (emoji or superposition)"""
	var qubit = quantum_states.get(position)
	if not qubit:
		return ""
	return qubit.get_semantic_state()


func get_probability_north(position: Vector2i) -> float:
	"""Get probability of measuring north_emoji"""
	var qubit = quantum_states.get(position)
	if not qubit:
		return 0.0
	return qubit.get_north_probability()


func get_probability_south(position: Vector2i) -> float:
	"""Get probability of measuring south_emoji"""
	var qubit = quantum_states.get(position)
	if not qubit:
		return 0.0
	return qubit.get_south_probability()


func _compose_total_hamiltonian() -> Dictionary:
	"""Layer 1: Compose total Hamiltonian from all icon Hamiltonians

	H_total = Σ(strength_i × H_i)
	Weighted sum of all icon Hamiltonian terms
	"""
	var H_total = {"sigma_x": 0.0, "sigma_y": 0.0, "sigma_z": 0.0}

	# Wheat icon contribution (active strength = 1.0 always for crop icons)
	if wheat_icon:
		var wheat_terms = wheat_icon["hamiltonian_terms"] if wheat_icon is Dictionary else wheat_icon.hamiltonian_terms
		H_total.sigma_x += 1.0 * wheat_terms.get("sigma_x", 0.0)
		H_total.sigma_y += 1.0 * wheat_terms.get("sigma_y", 0.0)
		H_total.sigma_z += 1.0 * wheat_terms.get("sigma_z", 0.0)

	# Mushroom icon contribution
	if mushroom_icon:
		var mushroom_terms = mushroom_icon["hamiltonian_terms"] if mushroom_icon is Dictionary else mushroom_icon.hamiltonian_terms
		H_total.sigma_x += 1.0 * mushroom_terms.get("sigma_x", 0.0)
		H_total.sigma_y += 1.0 * mushroom_terms.get("sigma_y", 0.0)
		H_total.sigma_z += 1.0 * mushroom_terms.get("sigma_z", 0.0)

	# Add other environmental icons (BioticFlux, Imperium, etc.)
	if biotic_flux_icon:
		var strength = biotic_flux_icon.active_strength
		H_total.sigma_x += strength * biotic_flux_icon.hamiltonian_terms.get("sigma_x", 0.0)
		H_total.sigma_y += strength * biotic_flux_icon.hamiltonian_terms.get("sigma_y", 0.0)
		H_total.sigma_z += strength * biotic_flux_icon.hamiltonian_terms.get("sigma_z", 0.0)

	if imperium_icon:
		var strength = imperium_icon.active_strength
		H_total.sigma_x += strength * imperium_icon.hamiltonian_terms.get("sigma_x", 0.0)
		H_total.sigma_y += strength * imperium_icon.hamiltonian_terms.get("sigma_y", 0.0)
		H_total.sigma_z += strength * imperium_icon.hamiltonian_terms.get("sigma_z", 0.0)

	return H_total


func _apply_hamiltonian_evolution(dt: float) -> void:
	"""Layer 1: Apply composed Hamiltonian evolution (pure rotations)

	Applies H_total to all qubits via Bloch vector rotations
	Only affects θ/φ, NOT radius/energy
	"""
	var H_total = _compose_total_hamiltonian()

	# Apply to all qubits
	for position in quantum_states.keys():
		var qubit = quantum_states[position]
		if not qubit:
			continue

		# Skip celestial (sun/moon don't evolve)
		if position in plot_types and plot_types[position] == PlotType.CELESTIAL:
			continue

		# Apply unitary Hamiltonian rotation
		qubit.apply_hamiltonian_rotation(H_total, dt)


func _apply_spring_attraction(dt: float) -> void:
	"""Apply Hooke's law rotational attraction to icon stable points

	Each crop is attracted toward its icon's stable theta on the Bloch sphere
	Hybrid crops are attracted to BOTH stable points (flexible equilibrium)
	Torque τ ∝ sin(θ - θ_stable), implemented as dθ/dt = -k × sin(angle_diff)/2
	"""
	for position in quantum_states.keys():
		var qubit = quantum_states[position]
		if not qubit:
			continue

		# Skip celestial (immutable)
		if position in plot_types and plot_types[position] == PlotType.CELESTIAL:
			continue

		# Detect hybrid crops
		var is_hybrid = (qubit.north_emoji == "🌾" and qubit.south_emoji == "🍄") or \
		                (qubit.north_emoji == "🍄" and qubit.south_emoji == "🌾")

		# Calculate total spring torque (can come from both icons for hybrids)
		var total_spring_torque = 0.0

		if is_hybrid:
			# HYBRID: Attracted to BOTH stable points
			# Wheat: θ = π/4
			if wheat_icon:
				var wheat_spring = wheat_icon["spring_constant"] if wheat_icon is Dictionary else wheat_icon.spring_constant
				if wheat_spring > 0.0:
					var wheat_stable = wheat_icon["stable_theta"] if wheat_icon is Dictionary else wheat_icon.stable_theta
					var wheat_diff = qubit.theta - wheat_stable
					while wheat_diff > PI:
						wheat_diff -= TAU
					while wheat_diff < -PI:
						wheat_diff += TAU
					var wheat_torque = -wheat_spring * sin(wheat_diff / 2.0)
					total_spring_torque += wheat_torque

			# Mushroom: θ = π
			if mushroom_icon:
				var mushroom_spring = mushroom_icon["spring_constant"] if mushroom_icon is Dictionary else mushroom_icon.spring_constant
				if mushroom_spring > 0.0:
					var mushroom_stable = mushroom_icon["stable_theta"] if mushroom_icon is Dictionary else mushroom_icon.stable_theta
					var mushroom_diff = qubit.theta - mushroom_stable
					while mushroom_diff > PI:
						mushroom_diff -= TAU
					while mushroom_diff < -PI:
						mushroom_diff += TAU
					var mushroom_torque = -mushroom_spring * sin(mushroom_diff / 2.0)
					total_spring_torque += mushroom_torque
		else:
			# SPECIALIST: Attracted to single stable point
			var icon = null
			if qubit.north_emoji == "🍄":
				icon = mushroom_icon
			else:
				icon = wheat_icon

			if position == Vector2i(0, 0):  # DEBUG
				var icon_name = "wheat" if icon == wheat_icon else ("mushroom" if icon == mushroom_icon else "NULL")
				print("[SPRING CALC] pos=%s north=%s icon=%s (wheat_icon=%s mushroom_icon=%s)" % [position, qubit.north_emoji, icon_name, wheat_icon == null, mushroom_icon == null])

			if icon:
				var spring = icon["spring_constant"] if icon is Dictionary else icon.spring_constant
				if position == Vector2i(0, 0):  # DEBUG
					print("[SPRING CHECK] icon is_dict=%s spring=%.4f (check: >0?%s)" % [icon is Dictionary, spring, spring > 0.0])
				if spring > 0.0:
					var stable = icon["stable_theta"] if icon is Dictionary else icon.stable_theta
					var angle_diff = qubit.theta - stable
					# Wrap to [-π, π]
					while angle_diff > PI:
						angle_diff -= TAU
					while angle_diff < -PI:
						angle_diff += TAU

					total_spring_torque = -spring * sin(angle_diff / 2.0)
					if position == Vector2i(0, 0):  # DEBUG
						print("[SPRING CALC] stable=%.4f angle_diff=%.4f spring=%.4f -> torque=%.6f" % [stable, angle_diff, spring, total_spring_torque])

		# Apply rotation to theta
		var old_theta = qubit.theta
		qubit.theta += total_spring_torque * dt
		if position == Vector2i(0, 0):  # DEBUG: only for first plot
			print("[SPRING] pos=%s θ_before=%.4f torque=%.6f *dt=%.6f θ_after=%.4f" % [
				position, old_theta, total_spring_torque, total_spring_torque * dt, qubit.theta
			])


func _get_icon_influence_for_crop(position: Vector2i) -> float:
	"""Get energy influence for crop at position based on crop type"""
	if not grid:
		return wheat_energy_influence  # Default to wheat

	var plot = grid.get_plot(position)
	if plot and plot.plot_type == 2:  # PlotType.MUSHROOM = 2
		return mushroom_energy_influence
	else:
		return wheat_energy_influence


func _is_mushroom_plot(position: Vector2i) -> bool:
	"""Check if a plot contains a mushroom crop (by emoji or plot_type)"""
	if not grid:
		return false

	var plot = grid.get_plot(position)
	if not plot:
		return false

	# Check by plot_type first
	if plot.plot_type == 2:  # PlotType.MUSHROOM = 2
		return true

	# Fallback: check the emoji of the quantum state
	if plot.quantum_state and plot.quantum_state.north_emoji == "🍄":
		return true

	return false


func _apply_energy_transfer(dt: float) -> void:
	"""Layer 2: Non-Hamiltonian energy growth (radius changes only)

	Energy transfer: continuous cos² formula (no categorical phase gates)
	energy_rate = base_rate × cos²(θ_qubit/2) × cos²((θ_qubit - θ_sun)/2) × cos²(θ_icon/2)

	Affects radius/energy, NOT θ/φ
	"""
	for position in quantum_states.keys():
		var qubit = quantum_states[position]
		if not qubit:
			continue

		# Skip celestial (sun/moon don't transfer energy)
		if position in plot_types and plot_types[position] == PlotType.CELESTIAL:
			continue

		# Sanity check: ensure sun_qubit exists
		if not sun_qubit:
			continue

		# Detect hybrid crops (both wheat AND mushroom emojis)
		var is_hybrid = (qubit.north_emoji == "🌾" and qubit.south_emoji == "🍄") or \
		                (qubit.north_emoji == "🍄" and qubit.south_emoji == "🌾")
		var is_mushroom = _is_mushroom_plot(position)

		# Alignment: phase matching with sun
		var alignment = pow(cos((qubit.theta - sun_qubit.theta) / 2.0), 2)

		# Calculate total energy rate from applicable icons
		var energy_rate = 0.0
		var mushroom_exposure = 0.0  # Probability of mushroom being "active" (for damage weighting)

		if is_hybrid:
			# HYBRID: Probability-weighted effects based on Bloch sphere position
			# P(wheat) = cos²(θ/2) - probability of being in wheat state
			# P(mushroom) = sin²(θ/2) - probability of being in mushroom state
			var wheat_prob = pow(cos(qubit.theta / 2.0), 2)
			var mushroom_prob = pow(sin(qubit.theta / 2.0), 2)

			# Wheat component: energy scales with probability of wheat state
			var wheat_amplitude = wheat_prob
			var wheat_rate = base_energy_rate * wheat_amplitude * alignment * wheat_energy_influence

			# Mushroom component: energy scales with probability of mushroom state
			var mushroom_amplitude = mushroom_prob
			var mushroom_rate = base_energy_rate * mushroom_amplitude * alignment * mushroom_energy_influence

			# Total: smoothly transitions between wheat and mushroom effects
			# At θ=0: 100% wheat, 0% mushroom (wheat shields mushroom from damage)
			# At θ=π/2: 50% wheat, 50% mushroom (balanced)
			# At θ=π: 0% wheat, 100% mushroom (mushroom exposed but sun weak at night)
			energy_rate = wheat_rate + mushroom_rate

			# Mushroom exposure for sun damage weighting
			mushroom_exposure = mushroom_prob
		else:
			# SPECIALIST: Apply only appropriate icon
			var icon_influence = _get_icon_influence_for_crop(position)

			# Amplitude: relative to crop's native phase
			var amplitude_self: float
			if is_mushroom:
				# Mushroom: native phase is θ=π
				amplitude_self = pow(cos((qubit.theta - PI) / 2.0), 2)
				mushroom_exposure = 1.0  # Specialist mushroom is fully exposed to sun damage
			else:
				# Wheat: native phase is θ=0
				amplitude_self = pow(cos(qubit.theta / 2.0), 2)
				mushroom_exposure = 0.0  # Wheat doesn't take sun damage

			energy_rate = base_energy_rate * amplitude_self * alignment * icon_influence

		# Apply exponential growth
		qubit.grow_energy(energy_rate, dt)

		# Apply sun damage (to mushrooms and hybrid crops)
		if is_mushroom or is_hybrid:
			# Damage based on sun strength (cos² of sun's day-phase)
			var sun_strength = pow(cos(sun_qubit.theta / 2.0), 2)
			# Max damage when sun strong: 0.01/sec (weighted by mushroom exposure probability)
			# For hybrids: damage only applies when mushroom component is exposed
			# For specialists: always exposed
			var damage_rate = 0.01 * sun_strength * mushroom_exposure
			qubit.grow_energy(-damage_rate, dt)  # Negative energy = damage

		# Sync radius with energy
		qubit.radius = qubit.energy


func _update_energy_taps(dt: float) -> void:
	"""Layer 2b: Energy tap update - drain energy from target emojis using cos² coupling

	Applied AFTER standard energy transfer to avoid circular dependencies.
	Each energy tap continuously drains energy from a configured target emoji.
	"""
	if not grid:
		return

	# Iterate through all plots in grid
	for plot in grid.plots:
		# DISABLED: WheatPlot.PlotType.ENERGY_TAP no longer exists in current architecture
		# Energy taps are not part of the current farming system
		#if not plot or plot.plot_type != WheatPlot.PlotType.ENERGY_TAP:
		#	continue
		if not plot:
			continue
		# Skip energy taps (not implemented in current design)
		continue

		# Skip if no target configured
		if not plot.tap_target_emoji or plot.tap_target_emoji == "":
			continue

		var target_emoji = plot.tap_target_emoji
		var tap_theta = plot.tap_theta
		var tap_base_rate = plot.tap_base_rate

		# Find all qubits with matching target emoji and drain them
		for position in quantum_states.keys():
			var target_qubit = quantum_states[position]
			if not target_qubit:
				continue

			# Skip celestial objects
			if position in plot_types and plot_types[position] == PlotType.CELESTIAL:
				continue

			# Check if this qubit produces/represents the target emoji
			# (Match either north or south emoji)
			if target_qubit.north_emoji != target_emoji and target_qubit.south_emoji != target_emoji:
				continue

			# Calculate cos² coupling (phase alignment between target and tap point)
			var alignment = pow(cos((target_qubit.theta - tap_theta) / 2.0), 2)

			# Amplitude (how target-like the qubit is at its current state)
			var amplitude = pow(cos(target_qubit.theta / 2.0), 2)

			# Total transfer rate (from target TO tap point)
			var transfer_rate = tap_base_rate * amplitude * alignment

			# Apply energy transfer (drain from target, accumulate in tap)
			if target_qubit.energy > 0.01:  # Don't drain below threshold
				# Max 10% drain per tick to avoid overshooting
				var drained = min(transfer_rate * dt, target_qubit.energy * 0.1)
				target_qubit.grow_energy(-drained, dt)  # Negative = drain
				target_qubit.radius = target_qubit.energy  # Sync radius

				# Accumulate in tap plot
				plot.tap_accumulated_resource += drained


func _evolve_quantum_substrate(dt: float) -> void:
	"""Apply quantum evolution to all qubits each frame

	THREE-LAYER ARCHITECTURE:
	1. Icons (Hamiltonian): Pure rotations - θ/φ only
	2. Biome (Lindblad): Energy transfer + dissipation - radius/energy only
	3. Gates (Discrete): Player actions - entanglement, measurement
	"""
	# Layer 1: Apply Hamiltonian evolution from all icons (pure rotations)
	_apply_hamiltonian_evolution(dt)

	# Layer 1b: Apply spring attraction to icon stable points (Hooke's law for rotation)
	_apply_spring_attraction(dt)

	# Layer 2: Apply Biome non-Hamiltonian effects (open system dynamics)
	_apply_energy_transfer(dt)

	# Layer 2b: Apply energy taps (drain energy from targets using cos² coupling)
	_update_energy_taps(dt)

	# Layer 3 + : Apply temperature, dissipation, coherence, constraints (per-qubit)
	for position in quantum_states.keys():
		var qubit = quantum_states[position]
		if not qubit:
			continue

		# Skip celestial objects (they don't evolve further)
		if position in plot_types and plot_types[position] == PlotType.CELESTIAL:
			continue

		# Temperature modulation (if Biotic Flux is active)
		if biotic_flux_icon:
			temperature_grid[position] = biotic_flux_icon.get_effective_temperature()
		else:
			temperature_grid[position] = base_temperature

		# Dissipation (T1 + T2 decoherence) with effective temperature
		apply_dissipation(qubit, position, dt)

		# Icon coherence restoration (pulls qubits toward superposition via BioticFlux)
		if biotic_flux_icon:
			biotic_flux_icon._apply_coherence_restoration(qubit, dt)

		# Apply icon-specific environmental effects (generic - any icon can define effects)
		_apply_icon_environmental_effects(qubit, position, dt)

		# Apply phase constraint (e.g., Imperium freezes Bloch sphere)
		_apply_phase_constraint(qubit, position)

		qubit_evolved.emit(position)


func _apply_icon_environmental_effects(qubit: DualEmojiQubit, position: Vector2i, dt: float) -> void:
	"""Apply any environmental effects defined by active icons

	Icons can define arbitrary effects via apply_environmental_effect().
	This is character-agnostic - icons describe effects, not crop types.
	"""
	# Let each icon apply its environmental effects if it has any
	if biotic_flux_icon:
		biotic_flux_icon.apply_environmental_effect(qubit, sun_qubit, dt)


func _apply_phase_constraint(qubit: DualEmojiQubit, position: Vector2i) -> void:
	"""Apply phase constraint from plot (if any)

	E.g., Imperium fields freeze theta/phi, allowing only radius to change
	"""
	if not grid:
		return

	var plot = grid.get_plot(position)
	if not plot or not plot.phase_constraint:
		return

	# Apply the constraint (e.g., locks theta/phi if Imperium)
	plot.phase_constraint.apply_constraint(qubit)


func inject_planting(position: Vector2i, wheat_amount: float, labor_amount: float, plot_type: int) -> Resource:
	"""
	Inject wheat directly into farming biome (new universal planting system)

	FARMING BIOME GAMEPLAY:
	- Player plants: 0.22🌾 + 0.08👥
	- Farming converts to quantum superposition (wheat/labor split)
	- Growth through Bloch sphere evolution
	- Harvest = measure qubit, get wheat or labor based on probability

	Returns: Qubit representing the planting
	"""
	if not wheat_icon:
		return null

	# Create a hybrid qubit (🌾, 👥) representing the planting
	# Start at balanced superposition (50/50 wheat/labor)
	var planting_qubit = DualEmojiQubit.new("🌾", "👥", PI / 2.0)  # π/2 = balanced

	# Set position and phase
	planting_qubit.phi = 0.0
	planting_qubit.radius = 1.0

	# Initial energy based on resources
	planting_qubit.energy = (wheat_amount * 100.0) + (labor_amount * 50.0)

	print("🌾 Farming injection: %.2f🌾 + %.2f👥 → quantum superposition (%.1f energy)" %
		[wheat_amount, labor_amount, planting_qubit.energy])

	return planting_qubit


func harvest_quantum_planting(planting_qubit: Resource) -> Dictionary:
	"""
	Harvest quantum planting from farming biome
	Measure the qubit to collapse superposition

	Returns: {
		"success": bool,
		"wheat": float,
		"labor": float,
		"energy": float
	}
	"""
	if not planting_qubit or not planting_qubit is DualEmojiQubit:
		return {"success": false, "wheat": 0.0, "labor": 0.0, "energy": 0.0}

	var qubit = planting_qubit as DualEmojiQubit

	# Measurement: collapse based on theta position
	# sin²(θ/2) = probability of 👥 (labor)
	# cos²(θ/2) = probability of 🌾 (wheat)
	var theta = qubit.theta
	var labor_prob = sin(theta / 2.0) * sin(theta / 2.0)
	var wheat_prob = cos(theta / 2.0) * cos(theta / 2.0)

	# Energy distributed based on probability
	var labor_yield = qubit.energy * labor_prob / 100.0  # Convert energy back to resource
	var wheat_yield = qubit.energy * wheat_prob / 100.0

	print("🌾 Farming harvest: %.2f🌾 + %.2f👥 (θ=%.2f)" % [wheat_yield, labor_yield, theta])

	return {
		"success": true,
		"wheat": wheat_yield,
		"labor": labor_yield,
		"energy": qubit.energy
	}


func _notification(what: int):
	"""Debug: Print biome info periodically"""
	if what == NOTIFICATION_PROCESS:
		if Engine.get_process_frames() % 300 == 0:  # Every 5 seconds at 60fps
			var info = get_debug_info()
			print("🌍 Biome | Temp: %.0fK | ☀️%.1f° | 🌾%.1f° | Energy: %.1f | Qubits: %d" % [
				info["temperature"],
				info["sun_theta_degrees"],
				info["icon_theta_degrees"],
				info["energy_strength"],
				quantum_states.size()
			])
