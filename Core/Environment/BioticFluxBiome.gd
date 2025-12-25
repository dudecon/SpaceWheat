class_name BioticFluxBiome
extends "res://Core/Environment/BiomeBase.gd"

## BioticFlux Biome - Environmental quantum ecosystem with sun/moon cycling
## Manages all quantum objects: celestial (sun/moon), native (biome-specific), farm (plantable)
## Manages Icons: wheat_icon (🌾↔🏰 agrarian/imperium)
## Manages temperature, decoherence, and all quantum couplings

# Celestial objects (immutable, drive the system)
var sun_qubit: DualEmojiQubit = null  # (☀️, 🌙) - immutable celestial anchor
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
var wheat_energy_influence: float = 0.034  # cos²(165°/2) - weak (wheat grows minimally alone) - 2x for better growth
var mushroom_energy_influence: float = 0.983  # cos²(15°/2) - strong (mushrooms grow well)

# Plot type system: Biome owns ALL qubits regardless of type
enum PlotType { CELESTIAL, NATIVE, FARM }
var plots_by_type: Dictionary = {  # PlotType -> Array[Vector2i]
	PlotType.CELESTIAL: [],
	PlotType.NATIVE: [],
	PlotType.FARM: []
}
var plot_types: Dictionary = {}  # Vector2i -> PlotType (to look up type of position)

# Static mode flag (for testing without quantum evolution)
var is_static: bool = false  # If true, disable all quantum evolution

# Temperature control (Kelvin)
var base_temperature: float = 300.0  # 300K baseline
var temperature_grid: Dictionary = {}  # Vector2i(x,y) -> local_temperature

# Decoherence base rates (modified by temperature)
var T1_base_rate: float = 0.001  # Amplitude damping
var T2_base_rate: float = 0.002  # Phase damping

# Visualization - Celestial object colors and positions
var sun_color: Color = Color.YELLOW  # Updated each frame based on sun.theta
var sun_display_theta: float = 0.0  # Sun theta for UI (0=☀️ yellow, π=🌑 purple)


func _ready():
	"""Initialize biome with sun/moon qubit and icon states"""
	super._ready()

	# HAUNTED UI FIX: Guard against double-initialization
	if sun_qubit != null:
		print("⚠️  BioticFluxBiome._ready() called multiple times, skipping re-initialization")
		return

	# Initialize sun/moon qubit as DYNAMIC celestial oscillator
	# Sun/moon oscillates around equator with tilted axis (avoids pole singularities)
	# Path: θ(t) = π/2 + A*sin(ωt), φ(t) = B*sin(ωt) where ω = 2π/period
	sun_qubit = BiomeUtilities.create_qubit("☀️", "🌑", PI / 2.0)  # Start at equator
	sun_qubit.phi = 0.0
	sun_qubit.radius = 1.0  # Brightness (will modulate with oscillation)

	# Register sun/moon as normal FARM plot (not CELESTIAL - let it move!)
	plots_by_type[PlotType.FARM].append(Vector2i(-1, -1))
	plot_types[Vector2i(-1, -1)] = PlotType.FARM
	quantum_states[Vector2i(-1, -1)] = sun_qubit

	# Set up emoji relationships: sun broadcasts its presence
	sun_qubit.entanglement_graph["☀️→"] = ["🌾"]  # Sun influences wheat
	sun_qubit.entanglement_graph["🌑→"] = ["🍄"]  # Moon influences mushroom

	# Initialize wheat and mushroom icons with stable points and spring constants
	# Fallback: Create icon objects directly if script loading fails

	# WHEAT ICON - Create fallback directly with internal qubit for coupling
	var wheat_internal = DualEmojiQubit.new()
	wheat_internal.north_emoji = "🌾"
	wheat_internal.south_emoji = "🏰"
	wheat_internal.theta = PI / 4.0  # Start at stable point
	wheat_internal.phi = 0.0
	wheat_internal.radius = 1.0
	wheat_internal.energy = 1.0

	wheat_icon = {
		"hamiltonian_terms": {"sigma_x": 0.0, "sigma_y": 0.0, "sigma_z": 0.0},  # Removed sigma_z
		"stable_theta": PI / 2.0,     # Current target: SUN position (moves with sun)
		"stable_phi": 0.0,            # Current target: SUN's φ
		"spring_constant": 0.5,       # Attraction to sun/moon (for crops)
		"icon_spring_constant": 2.5,  # Attraction to preferred rest point (balanced)
		"preferred_theta": PI / 4.0,  # Wheat Icon's preferred rest: 45° (morning)
		"preferred_phi": 3.0 * PI / 2.0,  # Wheat Icon's preferred rest: fall quadrant (φ ≈ 270°)
		"internal_qubit": wheat_internal,
		"target_qubit_pos": Vector2i(-1, -1)
	}
	# Keep wheat_energy_influence at tuned 0.017 for 3-day 30%→90% growth (don't override)

	# MUSHROOM ICON - Create fallback directly
	mushroom_icon = {
		"hamiltonian_terms": {"sigma_x": 0.0, "sigma_y": 0.0, "sigma_z": 0.0},  # Removed sigma_z
		"stable_theta": PI / 2.0,     # Current target: MOON position
		"stable_phi": PI,             # Current target: MOON's φ
		"spring_constant": 0.5,       # Attraction to sun/moon (for crops)
		"icon_spring_constant": 2.5,  # Attraction to preferred rest point (balanced)
		"preferred_theta": PI,        # Mushroom Icon's preferred rest: π (midnight, south pole)
		"preferred_phi": 0.0,         # Mushroom Icon's preferred rest: φ = 0
		"target_qubit_pos": Vector2i(-1, -1)
	}
	mushroom_energy_influence = 0.5  # Increase to balance day damage with night growth

	# TODO: Initialize biotic flux icon when script parsing issues are resolved
	# For now, sun damage to fungi is applied directly in _apply_energy_transfer()

	print("🌍 BioticFlux Biome initialized - Temperature: %.0fK, Period: %.1fs" % [base_temperature, sun_moon_period])
	print("  ☀️ Sun/Moon oscillating around equator with tilted axis (dynamic celestial)")
	print("  🌾 Wheat energy influence: %.3f (cos²(165°/2))" % wheat_energy_influence)
	print("  🍄 Mushroom energy influence: %.3f (cos²(163°/2))" % mushroom_energy_influence)
	print("  DEBUG: wheat_icon=%s, mushroom_icon=%s" % [wheat_icon != null, mushroom_icon != null])

	# Configure visual properties for QuantumForceGraph
	visual_color = Color(0.4, 0.6, 0.8, 0.3)  # Blue
	visual_label = "🌿 Biotic Flux"
	visual_center_offset = Vector2(0, 0.5)    # BOTTOM-CENTER (moved down from center)
	visual_oval_width = 400.0   # Spread UIOP plots out
	visual_oval_height = 247.0  # Golden ratio: 400/1.618


func get_biome_type() -> String:
	"""Return biome type identifier"""
	return "BioticFlux"


func _update_sun_visualization() -> void:
	"""Update sun color based on quantum state - yellow (day) to deep blue/purple (night)"""
	if not sun_qubit:
		return

	sun_display_theta = sun_qubit.theta

	# Color transition: θ=0 (yellow ☀️) → θ=π (deep purple/blue 🌙)
	# Using HSV interpolation for smooth color shift
	var day_night_progress = sun_display_theta / PI  # 0.0 (day) to 1.0 (night)

	# Yellow (day): HSV(60°, 1.0, 1.0)
	# Deep purple (night): HSV(270°, 0.8, 0.3)
	var day_hue = 60.0 / 360.0  # Yellow
	var night_hue = 270.0 / 360.0  # Deep purple

	var hue = lerp(day_hue, night_hue, day_night_progress)
	var saturation = lerp(1.0, 0.8, day_night_progress)
	var brightness = lerp(1.0, 0.3, day_night_progress)

	sun_color = Color.from_hsv(hue, saturation, brightness, 1.0)


func _update_quantum_substrate(dt: float) -> void:
	"""Override parent: Update biome each frame with quantum evolution"""
	# Skip all evolution if in static mode (for testing)
	if is_static:
		return

	# Standard biome evolution enabled by default
	_sync_sun_qubit(dt)
	_evolve_sun_moon_cycle(dt)
	_update_temperature_from_cycle()
	_update_energy_taps(dt)
	_evolve_quantum_substrate(dt)
	_update_sun_visualization()  # Update visualization colors based on sun state


func _sync_sun_qubit(dt: float):
	"""Advance sun qubit through day-night cycle using sinusoidal progression

	Sun's theta cycles smoothly: starts at 0 (noon, ☀️), peaks intensity at 0 and π,
	minimum intensity at π/2 and 3π/2 (twilight transitions).

	Uses sine wave: theta(t) = π + π*sin(2π*t/period)
	This gives: theta=0 (noon) → π/2 (afternoon) → 2π (midnight) → 3π/2 (early morning) → 0 (noon)
	With intensity peaking at 0 and π (noon and midnight).
	"""
	if not sun_qubit:
		return

	time_tracker.update(dt)

	# Smooth sinusoidal cycling using sine wave
	# This creates: noon (theta≈0) → midnight (theta≈π) → noon
	var cycle_time = fmod(time_tracker.time_elapsed, sun_moon_period)
	var phase = (cycle_time / sun_moon_period) * TAU  # 0→2π over period

	# Use sine to create smooth, natural-looking progression
	# For day-night cycle: θ should go 0→π→0 in one period
	# sin(phase/2) ranges -1→0→1 as phase goes 0→π→2π
	sun_qubit.theta = PI * sin(phase / 2.0)  # Results in 0→π smoothly, avoiding 2π wraparound

	# Keep sun locked to north pole (phi doesn't matter for σ_z coupling, but keep constant)
	sun_qubit.phi = 0.0

	# Radius varies with intensity for visual aura effect (pulsing)
	# Peaks at noon (theta=0) and midnight (theta=π)
	var intensity = (1.0 + cos(2.0 * sun_qubit.theta)) / 2.0
	sun_qubit.radius = 0.8 + 0.2 * intensity  # Ranges 0.8→1.0, always pure but pulsing visually
	sun_qubit.energy = intensity  # Energy also reflects intensity (for force graph effects)


func _evolve_sun_moon_cycle(dt: float):
	"""Deprecated - sun_qubit.theta is now synced directly in _sync_sun_qubit"""
	# No longer using sun_moon_phase - using time_tracker.time_elapsed and sun_qubit.theta instead
	pass


func _update_temperature_from_cycle():
	"""Temperature varies with sun/moon cycle - intensity peaks at BOTH noon and midnight

	Physics model:
	- Peak intensity at θ=0 (noon, ☀️ sun at maximum)
	- Peak intensity at θ=π (midnight, 🌙 moon at maximum)
	- Minimum intensity at θ=π/2 and 3π/2 (twilight transitions)

	Formula: intensity = (1 + cos(2*θ)) / 2
	This is a Rabi-like oscillation giving double peaks per cycle.
	"""
	if not sun_qubit:
		return

	# Rabi oscillation: peaks at both 0 and π (noon and midnight)
	var intensity = (1.0 + cos(2.0 * sun_qubit.theta)) / 2.0

	# Temperature ranges from 300K (twilight) to 400K (noon/midnight)
	var heat_factor = intensity * 100.0
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
	"""Returns true if in sun phase (theta between 0 and pi)"""
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


func get_sun_visualization() -> Dictionary:
	"""Get sun/moon celestial visualization data

	Returns:
		{
			"color": Color,  # Yellow (day) to deep purple (night)
			"theta": float,  # Sun qubit theta (0=day, π=night)
			"emoji": String  # ☀️ (day) or 🌙 (night)
		}
	"""
	var emoji = sun_qubit.north_emoji if sun_display_theta < PI/2.0 else sun_qubit.south_emoji
	return {
		"color": sun_color,
		"theta": sun_display_theta,
		"emoji": emoji,
		"time_remaining": get_sun_moon_time_remaining()
	}


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
## NOTE: create_quantum_state, get_qubit, measure_qubit, clear_qubit are inherited from BiomeBase

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


func _apply_celestial_oscillation(dt: float) -> void:
	"""Drive sun/moon qubit around tilted great circle (ecliptic path)

	Path: Sun traces a great circle tilted ~23° from equator (like Earth's ecliptic)
	- φ(t) rotates continuously: 0 → 2π over one sun_moon_period
	- θ(φ) = π/2 + tilt·sin(φ) stays on the tilted great circle
	- tilt ≈ 23.5° (Earth's axial tilt) = 0.41 radians

	This gives a precessing path that's natural and dynamic:
	- Full 360° rotation around the Bloch sphere
	- Crosses the celestial equator at φ=0 and φ=π (ascending/descending nodes)
	- Reaches maximum northern latitude at φ=π/2, southern at φ=3π/2
	- No pole singularities since we never reach θ=0 or θ=π

	This is deterministic - not quantum evolution, but classical driving force
	"""
	if not sun_qubit:
		return

	# Time-based continuous rotation around ecliptic great circle
	var cycle_time = fmod(time_tracker.time_elapsed, sun_moon_period)
	var phi = (cycle_time / sun_moon_period) * TAU  # 0 → 2π full rotation

	# Ecliptic tilt (23.5° - Earth's axial tilt relative to orbital plane)
	var ecliptic_tilt = 23.5 * PI / 180.0  # ~0.41 radians

	# Position on tilted great circle
	# θ(φ) = π/2 + tilt·sin(φ) keeps sun on the tilted ecliptic path
	sun_qubit.phi = phi
	sun_qubit.theta = PI / 2.0 + ecliptic_tilt * sin(phi)

	# Brightness modulates based on position on ecliptic
	# Maximum at equator crossings (φ=0, φ=π), minimum at extremes (φ=π/2, φ=3π/2)
	# This models seasonal intensity: brightest at equinoxes, dimmer at solstices
	var phase_brightness = pow(cos(phi / 2.0), 2)  # 0→1→0 over half cycle, repeats
	sun_qubit.radius = 0.7 + 0.3 * phase_brightness  # Ranges 0.7 to 1.0


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


func _bloch_vector(theta: float, phi: float) -> Vector3:
	"""Convert Bloch sphere angles (θ, φ) to 3D vector

	Point on Bloch sphere: v = (sin(θ)cos(φ), sin(θ)sin(φ), cos(θ))
	"""
	return Vector3(
		sin(theta) * cos(phi),
		sin(theta) * sin(phi),
		cos(theta)
	)


func _bloch_angle_between(v1: Vector3, v2: Vector3) -> float:
	"""Calculate angle between two Bloch vectors

	cos(angle) = v1 · v2 / (|v1| |v2|)
	Returns angle in [0, π]
	"""
	var dot_product = v1.dot(v2)
	# Clamp to avoid numerical errors
	dot_product = clamp(dot_product, -1.0, 1.0)
	return acos(dot_product)


func _apply_bloch_torque(qubit: DualEmojiQubit, target_v: Vector3, spring_constant: float, dt: float) -> void:
	"""Apply torque to qubit to rotate toward target Bloch vector

	Uses cross product: τ = k × (v_target × v)
	Rotating FROM v TOWARD v_target requires torque in direction of target × v
	This naturally affects both θ and φ
	"""
	var v = _bloch_vector(qubit.theta, qubit.phi)
	var torque_vec = target_v.cross(v)  # v_target × v (direction to rotate around)

	# Scale by spring constant (negate to produce attraction toward target)
	torque_vec *= -spring_constant

	# Apply torque as infinitesimal rotation
	# dθ/dt ≈ |τ × e_z| component
	# dφ/dt ≈ |τ| / sin(θ) component

	# Rotation around torque axis by angle |τ| * dt
	var torque_mag = torque_vec.length()
	if torque_mag > 0.001:  # Only apply if significant torque
		var torque_axis = torque_vec.normalized()
		var rotation_angle = torque_mag * dt

		# Apply infinitesimal rotation to Bloch vector
		var v_new = v.rotated(torque_axis, rotation_angle)

		# Extract new angles from rotated vector
		# θ = acos(z)
		# φ = atan2(y, x)
		qubit.theta = acos(clamp(v_new.z, -1.0, 1.0))
		qubit.phi = atan2(v_new.y, v_new.x)


func _apply_spring_attraction(dt: float) -> void:
	"""Apply spring attraction in full Bloch sphere space

	Crops have preferred rest locations that track celestial bodies:
	- Wheat preferred rest = SUN's current position (θ_sun, φ_sun)
	- Mushroom preferred rest = MOON's current position (opposite sun)
	Uses cross product τ = v × v_target for proper 3D rotation
	Affects both θ and φ naturally
	"""
	for position in quantum_states.keys():
		var qubit = quantum_states[position]
		if not qubit:
			continue

		# Skip sun/moon itself (it's being driven separately)
		if position == Vector2i(-1, -1):
			continue

		# Detect crop type (wheat or mushroom)
		var is_wheat = qubit.north_emoji == "🌾" or qubit.south_emoji == "🌾" or qubit.north_emoji == "💧" or qubit.south_emoji == "💧"
		var is_mushroom = qubit.north_emoji == "🍄" or qubit.south_emoji == "🍄" or qubit.north_emoji == "🍂" or qubit.south_emoji == "🍂"
		var is_hybrid = is_wheat and is_mushroom

		if is_hybrid:
			# HYBRID: Apply TWO separate torques from celestial targets AND preferred rests
			# Wheat follows sun + weak pull toward icon rest location
			if wheat_icon and sun_qubit:
				# PRIMARY: Strong spring toward sun's current position
				var sun_target = _bloch_vector(sun_qubit.theta, sun_qubit.phi)
				var wheat_spring = wheat_icon["spring_constant"] if wheat_icon is Dictionary else wheat_icon.spring_constant
				_apply_bloch_torque(qubit, sun_target, wheat_spring * 0.5, dt)  # 0.5 weight for hybrid

				# SECONDARY: Weak spring toward icon's preferred rest location
				var pref_target = _bloch_vector(wheat_icon["preferred_theta"], wheat_icon["preferred_phi"])
				_apply_bloch_torque(qubit, pref_target, wheat_icon["icon_spring_constant"] * 0.5, dt)

				# Update stable position for visualization/debugging
				wheat_icon["stable_theta"] = wheat_icon["preferred_theta"]
				wheat_icon["stable_phi"] = wheat_icon["preferred_phi"]

			if mushroom_icon and sun_qubit:
				# Moon is opposite to sun (θ → π - θ, φ → φ + π)
				var moon_theta = PI - sun_qubit.theta
				var moon_phi = sun_qubit.phi + PI

				# PRIMARY: Strong spring toward moon's current position
				var moon_target = _bloch_vector(moon_theta, moon_phi)
				var mushroom_spring = mushroom_icon["spring_constant"] if mushroom_icon is Dictionary else mushroom_icon.spring_constant
				_apply_bloch_torque(qubit, moon_target, mushroom_spring * 0.5, dt)  # 0.5 weight for hybrid

				# SECONDARY: Weak spring toward icon's preferred rest location
				var pref_target = _bloch_vector(mushroom_icon["preferred_theta"], mushroom_icon["preferred_phi"])
				_apply_bloch_torque(qubit, pref_target, mushroom_icon["icon_spring_constant"] * 0.5, dt)

				# Update stable position for visualization/debugging
				mushroom_icon["stable_theta"] = mushroom_icon["preferred_theta"]
				mushroom_icon["stable_phi"] = mushroom_icon["preferred_phi"]
		else:
			# SPECIALIST: Apply TWO separate springs toward sun/moon AND preferred rests
			if is_wheat and wheat_icon and sun_qubit:
				# PRIMARY: Strong spring toward sun's current position
				var sun_target = _bloch_vector(sun_qubit.theta, sun_qubit.phi)
				var spring = wheat_icon["spring_constant"] if wheat_icon is Dictionary else wheat_icon.spring_constant
				_apply_bloch_torque(qubit, sun_target, spring, dt)

				# SECONDARY: Weak spring toward icon's preferred rest location
				var pref_target = _bloch_vector(wheat_icon["preferred_theta"], wheat_icon["preferred_phi"])
				_apply_bloch_torque(qubit, pref_target, wheat_icon["icon_spring_constant"], dt)

				# Update stable position for visualization/debugging
				wheat_icon["stable_theta"] = wheat_icon["preferred_theta"]
				wheat_icon["stable_phi"] = wheat_icon["preferred_phi"]
			elif is_mushroom and mushroom_icon and sun_qubit:
				# Moon is opposite to sun (θ → π - θ, φ → φ + π)
				var moon_theta = PI - sun_qubit.theta
				var moon_phi = sun_qubit.phi + PI

				# PRIMARY: Strong spring toward moon's current position
				var moon_target = _bloch_vector(moon_theta, moon_phi)
				var spring = mushroom_icon["spring_constant"] if mushroom_icon is Dictionary else mushroom_icon.spring_constant
				_apply_bloch_torque(qubit, moon_target, spring, dt)

				# SECONDARY: Weak spring toward icon's preferred rest location
				var pref_target = _bloch_vector(mushroom_icon["preferred_theta"], mushroom_icon["preferred_phi"])
				_apply_bloch_torque(qubit, pref_target, mushroom_icon["icon_spring_constant"], dt)

				# Update stable position for visualization/debugging
				mushroom_icon["stable_theta"] = mushroom_icon["preferred_theta"]
				mushroom_icon["stable_phi"] = mushroom_icon["preferred_phi"]


func _apply_icon_rest_attraction(dt: float) -> void:
	"""Apply weak spring attraction pulling Icons toward their preferred rest locations

	Icons have preferred "home" positions:
	- Wheat Icon: (θ=π/4, φ=3π/2) - Morning in fall season
	- Mushroom Icon: (θ=π, φ=0) - Perfect midnight

	These are much weaker than crop attraction (0.1 vs 0.5) so icons mostly follow
	the sun/moon but slowly drift back toward their preferred resting points.
	"""
	if not wheat_icon or not wheat_icon.get("internal_qubit"):
		return
	if not mushroom_icon or not mushroom_icon.get("internal_qubit"):
		return

	# WHEAT ICON: Spring toward (π/4, fall quadrant)
	var wheat_rest_theta = wheat_icon["preferred_theta"]
	var wheat_rest_phi = wheat_icon["preferred_phi"]
	var wheat_rest_vector = _bloch_vector(wheat_rest_theta, wheat_rest_phi)
	var wheat_spring = wheat_icon["icon_spring_constant"]
	_apply_bloch_torque(wheat_icon["internal_qubit"], wheat_rest_vector, wheat_spring, dt)

	# MUSHROOM ICON: Spring toward (π, 0) - midnight
	var mushroom_rest_theta = mushroom_icon["preferred_theta"]
	var mushroom_rest_phi = mushroom_icon["preferred_phi"]
	var mushroom_rest_vector = _bloch_vector(mushroom_rest_theta, mushroom_rest_phi)
	var mushroom_spring = mushroom_icon["icon_spring_constant"]
	_apply_bloch_torque(mushroom_icon["internal_qubit"], mushroom_rest_vector, mushroom_spring, dt)


func _get_icon_influence_for_crop(position: Vector2i) -> float:
	"""Get energy influence for crop at position based on crop type"""
	# Try grid system first if available
	if grid:
		var plot = grid.get_plot(position)
		if plot and plot.plot_type == 2:  # PlotType.MUSHROOM = 2
			return mushroom_energy_influence
		return wheat_energy_influence

	# Fallback: check quantum_states for emoji (no grid)
	if position in quantum_states:
		var qubit = quantum_states[position]
		if qubit and (qubit.north_emoji == "🍄" or qubit.south_emoji == "🍄" or qubit.north_emoji == "🍂" or qubit.south_emoji == "🍂"):
			return mushroom_energy_influence

	return wheat_energy_influence  # Default to wheat


func _is_mushroom_plot(position: Vector2i) -> bool:
	"""Check if a plot contains a mushroom crop (by emoji or plot_type)"""
	# First try grid system if available
	if grid:
		var plot = grid.get_plot(position)
		if plot:
			# Check by plot_type first
			if plot.plot_type == 2:  # PlotType.MUSHROOM = 2
				return true
			# Fallback: check the emoji of the quantum state
			if plot.quantum_state and plot.quantum_state.north_emoji == "🍄":
				return true

	# Fallback for direct quantum_states (no grid)
	if position in quantum_states:
		var qubit = quantum_states[position]
		if qubit and (qubit.north_emoji == "🍄" or qubit.south_emoji == "🍄" or qubit.north_emoji == "🍂" or qubit.south_emoji == "🍂"):
			return true

	return false


func _apply_energy_transfer(dt: float) -> void:
	"""Layer 2: Non-Hamiltonian energy growth (radius changes only)

	DYNAMIC CELESTIAL ENERGY: Sun/moon radius modulates available energy
	- Sun brightness (radius) drives energy availability
	- Alignment shows how well crop couples to celestial body
	- Formula: energy_rate = base_rate × amplitude × sun_radius × alignment × influence

	Affects radius/energy, NOT θ/φ
	"""
	for position in quantum_states.keys():
		var qubit = quantum_states[position]
		if not qubit:
			continue

		# Skip sun/moon itself
		if position == Vector2i(-1, -1):
			continue

		# Detect hybrid crops (both wheat AND mushroom emojis)
		var is_hybrid = (qubit.north_emoji == "🌾" and qubit.south_emoji == "🍄") or \
		                (qubit.north_emoji == "🍄" and qubit.south_emoji == "🌾")
		var is_mushroom = _is_mushroom_plot(position)

		# Alignment: 3D Bloch sphere angle between crop and celestial bodies
		# This emerges naturally from spring forces pulling toward sun/moon
		var qubit_vector = _bloch_vector(qubit.theta, qubit.phi)
		var sun_vector = _bloch_vector(sun_qubit.theta, sun_qubit.phi)
		var bloch_angle = _bloch_angle_between(qubit_vector, sun_vector)
		var sun_alignment = pow(cos(bloch_angle / 2.0), 2)

		# Moon position (opposite of sun on Bloch sphere)
		var moon_theta = PI - sun_qubit.theta
		var moon_phi = sun_qubit.phi + PI
		var moon_vector = _bloch_vector(moon_theta, moon_phi)
		var moon_bloch_angle = _bloch_angle_between(qubit_vector, moon_vector)
		var moon_alignment = pow(cos(moon_bloch_angle / 2.0), 2)

		# Brightness sources: sun and moon have equal but opposite brightness cycles
		var sun_brightness = sun_qubit.radius  # Sun bright during day (θ near 0)
		var moon_brightness = 1.0 - sun_brightness  # Moon bright at night (θ near π)

		# Calculate total energy rate from applicable icons
		var energy_rate = 0.0
		var mushroom_exposure = 0.0  # Probability of mushroom being "active" (for damage weighting)

		if is_hybrid:
			# HYBRID: Probability-weighted effects based on Bloch sphere position
			# P(wheat) = cos²(θ/2) - probability of being in wheat state
			# P(mushroom) = sin²(θ/2) - probability of being in mushroom state
			var wheat_prob = pow(cos(qubit.theta / 2.0), 2)
			var mushroom_prob = pow(sin(qubit.theta / 2.0), 2)

			# Wheat component: absorbs energy from DAY (aligned with sun)
			var wheat_amplitude = wheat_prob
			var wheat_rate = base_energy_rate * wheat_amplitude * sun_brightness * sun_alignment * wheat_energy_influence

			# Mushroom component: absorbs energy from NIGHT (aligned with moon)
			var mushroom_amplitude = mushroom_prob
			var mushroom_rate = base_energy_rate * mushroom_amplitude * moon_brightness * moon_alignment * mushroom_energy_influence

			# Total: smoothly transitions between wheat and mushroom effects
			# At θ=0: 100% wheat (day), 0% mushroom (wheat shields mushroom from sun damage)
			# At θ=π/2: 50% wheat, 50% mushroom (balanced day/night)
			# At θ=π: 0% wheat, 100% mushroom (night - mushroom absorbs moonlight)
			energy_rate = wheat_rate + mushroom_rate

			# Mushroom exposure for sun damage weighting
			mushroom_exposure = mushroom_prob
		else:
			# SPECIALIST: Apply only appropriate icon
			var icon_influence = _get_icon_influence_for_crop(position)

			# Amplitude: relative to crop's native phase
			var amplitude_self: float
			if is_mushroom:
				# Mushroom: absorbs energy from NIGHT (aligned with moon)
				# Native phase is θ=π (midnight), amplitude peaks when aligned with moon
				amplitude_self = pow(cos((qubit.theta - PI) / 2.0), 2)
				energy_rate = base_energy_rate * amplitude_self * moon_brightness * moon_alignment * icon_influence
				mushroom_exposure = 1.0  # Specialist mushroom is fully exposed to sun damage (still takes damage during day)
			else:
				# Wheat: absorbs energy from DAY (aligned with sun)
				# Native phase is θ=0 (noon), amplitude peaks when aligned with sun
				amplitude_self = pow(cos(qubit.theta / 2.0), 2)
				energy_rate = base_energy_rate * amplitude_self * sun_brightness * sun_alignment * icon_influence
				mushroom_exposure = 0.0  # Wheat doesn't take sun damage

		# Apply exponential growth
		qubit.grow_energy(energy_rate, dt)

		# Apply sun damage (to mushrooms and hybrid crops)
		if is_mushroom or is_hybrid:
			# Damage based on sun brightness AND alignment with sun
			# Only strong damage when sun is bright AND aligned with crop
			# At noon with sun-aligned mushroom: max damage (~0.20/sec)
			# At noon with sun-opposite mushroom: negligible damage
			var sun_brightness_damage = pow(sun_qubit.radius, 2)  # Damage scales with brightness squared
			var sun_damage_modulation = sun_alignment  # Damage strongest when aligned with sun
			# Significantly increased damage coefficient to make mushrooms wilt more during day
			var damage_rate = 0.20 * sun_brightness_damage * sun_damage_modulation * mushroom_exposure
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

	CELESTIAL PLOTS ARE IMMUTABLE ANCHORS:
	- Sun/Moon qubits (CelestialPlot) do NOT evolve
	- They are skipped in all evolution layers (Hamiltonian, spring, energy transfer, dissipation)
	- They remain fixed to drive all other qubits via coupling terms
	- Immune to forces in force-directed graph visualization
	"""
	# CELESTIAL LAYER: Oscillate sun/moon around equator with tilted axis
	# This MUST run first so crops see the updated celestial position
	_apply_celestial_oscillation(dt)

	# Layer 1: Apply Hamiltonian evolution from all icons (pure rotations)
	_apply_hamiltonian_evolution(dt)

	# Layer 1b: Apply spring attraction to icon stable points (Hooke's law for rotation)
	_apply_spring_attraction(dt)

	# Layer 1c: Icon rest attraction (now blended into spring_attraction, so skip)

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
	var planting_qubit = BiomeUtilities.create_qubit("🌾", "👥", PI / 2.0)  # π/2 = balanced
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


func mark_bell_gate(positions: Array) -> void:
	"""
	Override: Mark Bell gate and apply BioticFlux entanglement energy boost

	In BioticFlux biome, entangled qubits receive a 10% energy boost per
	involved emoji, representing the cooperative energy generation from
	entanglement relationships.

	Example:
	- 2-qubit gate: each qubit gets +10% boost (1.10x multiplier)
	- 3-qubit gate: each qubit gets +10% boost (1.10x multiplier)

	Args:
		positions: Array of Vector2i positions to entangle
	"""
	# Call parent to record the Bell gate
	super.mark_bell_gate(positions)

	# Apply energy boost: 10% per emoji in the entanglement
	var boost_multiplier = 1.10
	var total_boost = 0.0

	for pos in positions:
		# Get plot at this position
		if not grid or not grid.has_method("get_plot"):
			continue

		var plot = grid.get_plot(pos)
		if plot == null:
			continue

		# Get qubit from plot
		var qubit = plot.quantum_state
		if qubit == null:
			continue

		# Apply energy boost
		var old_energy = qubit.radius
		qubit.radius *= boost_multiplier

		total_boost += (qubit.radius - old_energy)
		print("  ⚡ BioticFlux boost: %s energy %.3f → %.3f (+%.3f)" % [
			pos,
			old_energy,
			qubit.radius,
			qubit.radius - old_energy
		])

	if total_boost > 0.001:
		print("  ⚡ Total BioticFlux entanglement boost: +%.3f energy (%.1f%%)" % [
			total_boost,
			(boost_multiplier - 1.0) * 100
		])


func _reset_custom() -> void:
	"""Override parent: Reset biome to initial state"""
	# Reset celestial
	if sun_qubit:
		sun_qubit.theta = 0.0
		sun_qubit.radius = 1.0

	# Reset icons
	if wheat_icon and wheat_icon is Dictionary:
		wheat_icon["stable_theta"] = PI / 4.0
	if mushroom_icon and mushroom_icon is Dictionary:
		mushroom_icon["stable_theta"] = PI

	# Clear all other quantum states but keep sun_qubit
	var sun_pos = Vector2i(-1, -1)
	var temp_sun = quantum_states.get(sun_pos)
	quantum_states.clear()
	if temp_sun:
		quantum_states[sun_pos] = temp_sun

	temperature_grid.clear()
	base_temperature = 300.0

	print("🌍 BioticFlux Biome reset to initial state")


func _notification(what: int):
	"""Debug: Print biome info periodically"""
	if what == NOTIFICATION_PROCESS:
		if Engine.get_process_frames() % 300 == 0:  # Every 5 seconds at 60fps
			var info = get_debug_info()
			print("🌍 BioticFlux | Temp: %.0fK | ☀️%.1f° | 🌾%.1f° | Energy: %.1f | Qubits: %d" % [
				info["temperature"],
				info["sun_theta_degrees"],
				info["icon_theta_degrees"],
				info["energy_strength"],
				quantum_states.size()
			])
