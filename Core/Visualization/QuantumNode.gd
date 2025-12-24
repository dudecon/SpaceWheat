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

# Animation properties
var visual_scale: float = 0.0  # Animated scale (0 to 1)
var visual_alpha: float = 0.0  # Animated alpha (0 to 1)
var spawn_time: float = 0.0    # Time when node was created
var is_spawning: bool = false  # Currently animating in

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

	# Initialize visual scale and alpha to 1.0 (visible immediately)
	visual_scale = 1.0
	visual_alpha = 1.0

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
	"""Update visual properties from quantum state"""
	if not plot or not plot.quantum_state:
		# Default values for empty/unplanted plot
		energy = 0.0
		coherence = 1.0
		radius = MIN_RADIUS
		color = Color(0.5, 0.5, 0.5, 0.3)  # Gray, semi-transparent

		# Show plot emojis even if unplanted - just with zero opacity
		var emojis = plot.get_plot_emojis() if plot else {"north": "?", "south": "?"}
		emoji_north = emojis["north"]
		emoji_south = emojis["south"]
		emoji_north_opacity = 0.0  # Invisible until planted
		emoji_south_opacity = 0.0
		return

	var quantum_state = plot.quantum_state

	# Energy: Instant full size for planted plots (quantum-only mechanics)
	# No classical growth - plants appear at full size immediately
	energy = 1.0

	# Coherence from quantum state
	coherence = quantum_state.get_coherence()

	# Berry phase: Accumulated quantum evolution (experience points)
	# Raw unbounded value - glow intensifies as evolution accumulates
	# Acts as visual "measurement apparatus" showing full quantum activity
	berry_phase = quantum_state.get_berry_phase()

	# Radius: Constant full size for planted plots (no growth scaling)
	radius = MAX_RADIUS

	# Color from Bloch sphere angles
	# MEASURED plots: freeze color (wavefunction collapsed, state is classical)
	# UNMEASURED plots: color evolves with quantum phase
	if plot.has_been_measured:
		# Measured: Use fixed color based on collapsed state (theta frozen)
		# Bright, saturated color to show classical definite state
		var hue = fmod((quantum_state.phi + PI) / TAU, 1.0)
		var saturation = 1.0  # Full saturation - definite classical state
		var brightness = 0.9  # Bright - measured and known
		var alpha = 0.95
		color = Color.from_hsv(hue, saturation, brightness, alpha)
	else:
		# Unmeasured: Color evolves with quantum phase (superposition)
		var hue = fmod((quantum_state.phi + PI) / TAU, 1.0)
		var saturation = clamp(sin(quantum_state.theta), 0.6, 1.0)  # Varies with superposition
		var brightness = 0.85
		var alpha = 0.95 if plot.is_planted else 0.3
		color = Color.from_hsv(hue, saturation, brightness, alpha)

	# Add subtle variation based on plot type
	if plot.plot_type == FarmPlot.PlotType.TOMATO:
		# Tomatoes lean toward red/orange
		color = color.lerp(Color(1.0, 0.3, 0.2), 0.2)
	elif plot.plot_type == FarmPlot.PlotType.MUSHROOM:
		# Mushrooms lean toward purple/blue (moon colors)
		color = color.lerp(Color(0.6, 0.4, 0.9), 0.25)
	else:
		# Wheat leans toward golden/green
		color = color.lerp(Color(0.8, 0.9, 0.3), 0.15)

	# DUAL EMOJI SYSTEM: Show quantum superposition with theta-weighted opacity
	# Opacity determined by polar angle (theta) on Bloch sphere:
	# theta = 0 → 100% north emoji, theta = π → 100% south emoji
	if plot.has_been_measured:
		# Measured: Show single collapsed emoji
		var dominant_emoji = plot.get_dominant_emoji()
		emoji_north = dominant_emoji
		emoji_south = ""
		emoji_north_opacity = 1.0
		emoji_south_opacity = 0.0
	else:
		# Unmeasured: Show both emojis with theta-weighted opacity (Bloch sphere polar angle)
		var emojis = plot.get_plot_emojis()
		emoji_north = emojis["north"]
		emoji_south = emojis["south"]

		# Theta-weighted opacity using Born rule: P = sin²(θ/2) for north, cos²(θ/2) for south
		var theta = quantum_state.theta
		emoji_north_opacity = pow(sin(theta / 2.0), 2.0)  # Peaks at north pole (θ=0)
		emoji_south_opacity = pow(cos(theta / 2.0), 2.0)  # Peaks at south pole (θ=π)


func get_entangled_partner_ids() -> Array:
	"""Get list of plot IDs this node is entangled with"""
	if not plot or not plot.quantum_state:
		return []

	var partner_ids = []
	for partner_qubit in plot.quantum_state.entangled_partners:
		# Find the plot that owns this qubit
		# We'll need to search through all plots to find the match
		# This will be handled by the QuantumForceGraph
		pass

	return partner_ids


func apply_force(force: Vector2, delta: float):
	"""Apply a force to this node"""
	velocity += force * delta


func apply_damping(damping_factor: float):
	"""Apply velocity damping"""
	velocity *= damping_factor


func update_position(delta: float):
	"""Update position from velocity"""
	position += velocity * delta


func get_glow_alpha() -> float:
	"""Get glow halo alpha based on ENERGY + BERRY PHASE

	Glow components:
	- Energy: Current quantum energy level (0.0-0.4)
	- Berry phase: Accumulated evolution (unbounded - grows indefinitely)

	The glow intensifies with quantum evolution history, acting as a
	visual "measurement apparatus" showing full quantum activity.
	Highly evolved bubbles will have intense glows.

	Strong glow = high energy + extensive quantum evolution
	Faint glow = low energy, fresh qubit
	"""
	var energy_glow = energy * 0.4  # 0.0 to 0.4 range
	var berry_glow = berry_phase * 0.2  # Unbounded, grows with evolution
	return energy_glow + berry_glow  # Energy baseline + accumulated evolution


func get_berry_phase_glow() -> float:
	"""Get glow contribution from berry phase (experience/evolution indicator)

	Raw unbounded value that grows indefinitely with quantum evolution.
	This represents the full "measurement apparatus" aesthetic - showing
	every bit of quantum activity with intense visual feedback.

	The more evolved a quantum state is, the brighter it glows.
	Range: Unlimited (0.0 at fresh qubit, increases with evolution)
	"""
	return berry_phase * 0.2


func get_pulse_rate() -> float:
	"""Get pulse/oscillation speed based on COHERENCE

	Fast pulse = high decoherence threat (low coherence)
	Slow pulse = stable coherent state (high coherence)

	Inverted relationship: pulse_rate = 1.0 - coherence
	Range: 0.2 to 2.0 (fast when incoherent, slow when coherent)
	"""
	var decoherence_threat = 1.0 - coherence  # Invert: high coherence = low pulse
	return 0.2 + (decoherence_threat * 1.8)  # Range 0.2 (stable) to 2.0 (chaotic)
