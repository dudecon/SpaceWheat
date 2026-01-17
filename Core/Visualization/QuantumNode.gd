class_name QuantumNode
extends RefCounted

## Quantum Node - Force-Directed Graph Representation
## Represents a single quantum state in the central force-directed visualization

# Import dependencies
const FarmPlot = preload("res://Core/GameMechanics/FarmPlot.gd")

# Physics state
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var classical_anchor: Vector2 = Vector2.ZERO  # Position of classical plot (tether target)

# Quantum state reference
var plot: FarmPlot = null  # Reference to the actual quantum plot
var plot_id: String = ""
var grid_position: Vector2i = Vector2i.ZERO

# Visual properties (derived from quantum state)
var energy: float = 0.0
var coherence: float = 1.0
var color: Color = Color.WHITE
var radius: float = 20.0
var berry_phase: float = 0.0  # Accumulated quantum evolution (experience points)

# DUAL EMOJI SYSTEM for quantum superposition visualization
var emoji_north: String = "🌾"  # North pole emoji (e.g., 🌾 for wheat)
var emoji_south: String = "👥"  # South pole emoji (e.g., 👥 for wheat)
var emoji_north_opacity: float = 1.0  # Probability-weighted opacity
var emoji_south_opacity: float = 0.0  # Probability-weighted opacity

# Parametric biome coordinates (for auto-scaling layout)
# Position is computed by BiomeLayoutCalculator from these coords
var biome_name: String = ""        # Which biome this node belongs to
var parametric_t: float = 0.5      # Angular parameter [0, 1] around biome oval
var parametric_ring: float = 0.5   # Radial parameter [0, 1] (0=center, 1=edge)

# Farm plot tethering
# When true, this bubble is attached to a farm plot and should show tether lines
# When false, this is a free-floating biome bubble (no tether)
var has_farm_tether: bool = false

# Terminal bubble flag (v2 architecture)
# When true, this bubble represents a bound terminal (EXPLORE action)
# Emojis come from terminal binding, not plot data
# Should NOT call update_from_quantum_state() which would zero out opacities
var is_terminal_bubble: bool = false

# V2 Architecture: Direct reference to the bound terminal (source of truth)
# When set, emoji and measurement state are queried from here
var terminal = null  # Terminal instance

# V2 Architecture: Frozen anchor position (set on MEASURE, used for snapping)
var frozen_anchor: Vector2 = Vector2.ZERO

# Lifeless mode - no quantum data available, should not wiggle
var is_lifeless: bool = false

# Legacy compatibility (deprecated - use biome_name + parametric coords)
var venn_zone: int = -1      # Zone enum value (-1 = not set)

# Animation properties
var visual_scale: float = 0.0  # Animated scale (0 to 1)
var visual_alpha: float = 0.0  # Animated alpha (0 to 1)
var spawn_time: float = 0.0    # Time when node was created
var is_spawning: bool = false  # Currently animating in

# Orbit trail history (for visualizing evolution path)
var position_history: Array[Vector2] = []  # Last N positions
const MAX_TRAIL_LENGTH: int = 30  # Number of positions to remember
var trail_update_timer: float = 0.0
const TRAIL_UPDATE_INTERVAL: float = 0.05  # Update every 50ms

# Constants
const MIN_RADIUS = 10.0
const MAX_RADIUS = 40.0
const SPAWN_DURATION = 0.5  # Fade-in duration in seconds


func _init(wheat_plot: FarmPlot, anchor_pos: Vector2, grid_pos: Vector2i, center_pos: Vector2 = Vector2.ZERO):
	plot = wheat_plot
	classical_anchor = anchor_pos
	grid_position = grid_pos

	# Start at the tether location (where the classical plot is)
	position = anchor_pos

	# Initialize visual scale and alpha to 0.0 (spawn animation will fade in)
	# This prevents the "flash at full size" bug when bubbles are created
	visual_scale = 0.0
	visual_alpha = 0.0

	if plot:
		plot_id = plot.plot_id
		update_from_quantum_state()

	# Start empty - no emoji displayed until plot is planted
	emoji_north_opacity = 0.0
	emoji_south_opacity = 0.0


func start_spawn_animation(current_time: float):
	"""Start the spawn animation for this node"""
	is_spawning = true
	spawn_time = current_time
	visual_scale = 0.0
	visual_alpha = 0.0


func update_animation(current_time: float, delta: float):
	"""Update spawn animation"""
	if not is_spawning:
		visual_scale = 1.0
		visual_alpha = 1.0
		return

	var elapsed = current_time - spawn_time
	var progress = clamp(elapsed / SPAWN_DURATION, 0.0, 1.0)

	# Ease-out cubic for smooth deceleration
	var eased = 1.0 - pow(1.0 - progress, 3.0)

	visual_scale = eased
	visual_alpha = eased

	if progress >= 1.0:
		is_spawning = false
		visual_scale = 1.0
		visual_alpha = 1.0


func update_from_quantum_state():
	"""Update visual properties from quantum state (Model C: queries parent_biome.bath)

	Visual mapping (no duplicates):
	- Emoji opacity ← Normalized probabilities (θ-like, measurement outcome)
	- Color hue ← Coherence phase arg(ρ_{n,s}) (φ-like, quantum phase)
	- Color saturation ← Coherence magnitude (quantum vs classical)
	- Glow (energy) ← Purity Tr(ρ²) (pure=bright, mixed=dim)
	- Pulse rate (coherence) ← |ρ_{n,s}| coherence magnitude (decoherence threat)
	- Radius ← Mass P(n)+P(s) (probability in measurement subspace)
	"""
	var is_transitioning_planted = (radius == MAX_RADIUS)

	# === DETERMINE BIOME SOURCE ===
	# Terminal bubbles use terminal.bound_biome, plot bubbles use plot.parent_biome
	var biome = null
	if terminal and terminal.is_bound:
		# V2 Terminal architecture: get biome from terminal
		biome = terminal.bound_biome
	elif plot and plot.is_planted:
		# V1 Plot architecture: get biome from plot
		biome = plot.parent_biome

	# Guard: no biome or no quantum_computer → LIFELESS fallback (no wiggle)
	if not biome or not biome.quantum_computer:
		is_lifeless = true  # Mark as frozen - no physics
		energy = 0.0       # No glow - lifeless
		coherence = 0.0    # No pulse - static
		radius = MIN_RADIUS  # Small - minimal presence
		color = Color(0.4, 0.4, 0.5, 0.5)  # Dim gray - disconnected

		# Try to get emojis from either source
		var emojis_dict = {}
		if terminal and terminal.is_bound:
			emojis_dict = {"north": terminal.north_emoji, "south": terminal.south_emoji}
		elif plot:
			emojis_dict = plot.get_plot_emojis()

		emoji_north = emojis_dict.get("north", emoji_north)
		emoji_south = emojis_dict.get("south", emoji_south)
		emoji_north_opacity = 0.3  # Dim
		emoji_south_opacity = 0.3
		return

	# Has real quantum data - not lifeless
	is_lifeless = false

	# === CHECK IF MEASURED: If so, freeze at measurement outcome ===
	var is_measured_now = is_terminal_measured()
	if is_measured_now:
		# Measurement outcome is frozen - don't query evolving quantum state
		# Just show the measured outcome with static properties
		energy = 0.5  # Static glow at neutral
		coherence = 0.0  # No pulse (stable/static)
		color = Color(0.6, 0.6, 0.6, 0.8)  # Neutral gray - measured state

		# Show measured outcome as 100% on one emoji, 0% on other
		if terminal and terminal.is_measured and terminal.measured_outcome:
			emoji_north = terminal.north_emoji
			emoji_south = terminal.south_emoji
			if terminal.measured_outcome == emoji_north:
				emoji_north_opacity = 1.0
				emoji_south_opacity = 0.0
			else:
				emoji_north_opacity = 0.0
				emoji_south_opacity = 1.0
		else:
			# Fallback for plot-based measurement
			emoji_north_opacity = 0.5
			emoji_south_opacity = 0.5

		# Freeze radius at current size
		# (don't query evolving probabilities)
		return

	# === QUERY BIOME FOR REAL QUANTUM DATA (UNMEASURED ONLY) ===
	# Get emojis from either terminal or plot
	var emojis = {}
	if terminal and terminal.is_bound:
		emojis = {"north": terminal.north_emoji, "south": terminal.south_emoji}
	elif plot:
		emojis = plot.get_plot_emojis()

	emoji_north = emojis.get("north", emoji_north)
	emoji_south = emojis.get("south", emoji_south)

	# 1. EMOJI OPACITY ← Normalized probabilities (θ-like)
	var north_prob = biome.get_emoji_probability(emoji_north)
	var south_prob = biome.get_emoji_probability(emoji_south)
	var mass = north_prob + south_prob  # Total probability in our subspace

	if mass > 0.001:
		emoji_north_opacity = north_prob / mass
		emoji_south_opacity = south_prob / mass
	else:
		# No probability in our subspace - show dim
		emoji_north_opacity = 0.1
		emoji_south_opacity = 0.1

	# 2. COLOR HUE ← Coherence phase arg(ρ_{n,s}) (φ-like)
	var coh = biome.get_emoji_coherence(emoji_north, emoji_south)
	var coh_magnitude = 0.0
	var coh_phase = 0.0
	if coh:
		coh_magnitude = coh.abs()
		coh_phase = coh.arg()  # Returns angle in radians [-π, π]
		# DEBUG: Log if we're getting real coherence
		if is_transitioning_planted and coh_magnitude > 0.01:
			print("⚛️  COHERENCE FOUND: |coh|=%.4f arg=%.2f° for %s/%s" % [coh_magnitude, rad_to_deg(coh_phase), emoji_north, emoji_south])
	else:
		# DEBUG: Log when coherence is null (possible problem)
		if is_transitioning_planted:
			print("⚠️  COHERENCE NULL for %s/%s at %s" % [emoji_north, emoji_south, grid_position])

	# Map phase to hue [0, 1] for HSV color
	var hue = (coh_phase + PI) / TAU  # Normalize to [0, 1]
	var saturation = coh_magnitude  # More coherent = more saturated color
	color = Color.from_hsv(hue, saturation * 0.8, 0.9, 0.8)

	# 3. GLOW (energy) ← Purity Tr(ρ²)
	# Pure state = 1.0 (bright glow), maximally mixed = 1/N (dim)
	energy = biome.get_purity()

	# 4. PULSE RATE (coherence) ← |ρ_{n,s}| coherence magnitude
	# High coherence = stable/slow pulse, low = jittery/fast
	coherence = coh_magnitude

	# 5. RADIUS ← Mass in subspace (bigger = more probability)
	radius = lerpf(MIN_RADIUS, MAX_RADIUS, clampf(mass * 2.0, 0.0, 1.0))

	# 6. Berry phase accumulation (tracks total evolution)
	berry_phase += energy * 0.01

	if is_transitioning_planted:
		print("⚛️  Node %s: θ=(%.2f/%.2f) φ=%.1f° purity=%.3f |coh|=%.3f mass=%.3f" % [
			grid_position, emoji_north_opacity, emoji_south_opacity,
			rad_to_deg(coh_phase), energy, coh_magnitude, mass])


func get_entangled_partner_ids() -> Array:
	"""Get list of plot IDs this node is entangled with (Model B: via parent biome)"""
	# Model B: entanglement managed by biome's quantum_computer
	# For now, return empty array - will be implemented via biome queries
	if not plot or not plot.parent_biome:
		return []

	# TODO: Query biome's quantum_computer for entangled registers
	# var partner_ids = []
	# for reg_id in plot.parent_biome.quantum_computer.get_entangled_registers(plot.register_id):
	#     partner_ids.append(...)
	# return partner_ids

	return []  # Empty for now - Model B visualization TODO


func apply_force(force: Vector2, delta: float):
	"""Apply a force to this node"""
	velocity += force * delta


func apply_damping(damping_factor: float):
	"""Apply velocity damping"""
	velocity *= damping_factor


func update_position(delta: float):
	"""Update position from velocity"""
	position += velocity * delta

	# Update orbit trail history
	trail_update_timer += delta
	if trail_update_timer >= TRAIL_UPDATE_INTERVAL:
		trail_update_timer = 0.0
		position_history.append(position)
		if position_history.size() > MAX_TRAIL_LENGTH:
			position_history.remove_at(0)


func get_glow_alpha() -> float:
	"""Get glow halo alpha based on PURITY (energy) only.

	Glow = Purity Tr(ρ²): Pure states glow brightly, mixed states are dim.
	Range: 0.3 (mixed) to 0.8 (pure)

	NOTE: Berry phase has been moved to pulse rate animation.
	"""
	return energy * 0.5 + 0.3  # 0.3 to 0.8 range based on purity


func get_berry_phase_glow() -> float:
	"""DEPRECATED: Berry phase now affects pulse rate, not glow.
	Kept for backward compatibility.
	"""
	return 0.0  # No longer contributes to glow


func get_pulse_rate() -> float:
	"""Get pulse/oscillation speed based on COHERENCE + BERRY PHASE.

	Components:
	- Coherence: Low coherence = fast pulse (decoherence threat)
	- Berry phase: More evolution history = faster pulse (experience)

	Fast pulse = unstable state OR highly evolved
	Slow pulse = stable coherent state AND fresh qubit

	Range: 0.3 to 3.0 Hz
	"""
	# Base rate from decoherence threat (inverted coherence)
	var decoherence_threat = 1.0 - coherence  # 0 = stable, 1 = chaotic
	var base_rate = 0.3 + (decoherence_threat * 1.5)  # 0.3 to 1.8 Hz

	# Berry phase adds experience-based pulse acceleration
	# Clamp to prevent runaway pulse rates
	var berry_boost = clampf(berry_phase * 0.1, 0.0, 1.2)  # 0 to 1.2 Hz bonus

	return base_rate + berry_boost  # 0.3 to 3.0 Hz


# ============================================================================
# V2 Architecture: Terminal-delegating computed properties
# ============================================================================

func get_emoji_north() -> String:
	"""Get north emoji - delegates to terminal when available (v2 single source of truth)"""
	if terminal and terminal.is_bound:
		return terminal.north_emoji
	return emoji_north


func get_emoji_south() -> String:
	"""Get south emoji - delegates to terminal when available (v2 single source of truth)"""
	if terminal and terminal.is_bound:
		return terminal.south_emoji
	return emoji_south


func get_emoji_opacities(biome = null) -> Dictionary:
	"""Get emoji opacities computed from biome's density matrix at render time.

	V2 Architecture: Opacities are computed fresh each frame from biome state.
	This eliminates the need to cache/duplicate probability state.

	Args:
		biome: BiomeBase to query for probabilities (optional)

	Returns:
		Dictionary with "north" and "south" opacity values (0.0-1.0)
	"""
	# If no terminal or not bound, use cached values
	if not terminal or not terminal.is_bound:
		return {"north": emoji_north_opacity, "south": emoji_south_opacity}

	# If measured, show only the measured outcome
	if terminal.is_measured:
		if terminal.measured_outcome == terminal.north_emoji:
			return {"north": 1.0, "south": 0.0}
		else:
			return {"north": 0.0, "south": 1.0}

	# If no biome provided, try to get from terminal
	if not biome:
		biome = terminal.bound_biome

	if not biome:
		return {"north": emoji_north_opacity, "south": emoji_south_opacity}

	# Query biome for current probability of this register
	var north_prob = 0.5
	if biome.has_method("get_register_probability"):
		north_prob = biome.get_register_probability(terminal.bound_register_id)

	var south_prob = 1.0 - north_prob
	var mass = north_prob + south_prob

	if mass > 0.001:
		return {"north": north_prob / mass, "south": south_prob / mass}
	return {"north": 0.1, "south": 0.1}


func is_terminal_measured() -> bool:
	"""Check if this node's terminal is measured (v2 single source of truth)"""
	if terminal:
		return terminal.is_measured
	# Fallback to plot-based check for v1 compatibility
	if plot:
		return plot.is_measured() if plot.has_method("is_measured") else plot.has_been_measured
	return false
