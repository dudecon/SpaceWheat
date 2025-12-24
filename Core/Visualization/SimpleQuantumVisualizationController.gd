class_name SimpleQuantumVisualizationController
extends Control

## Generic force-directed quantum visualization for any biome
## Implements physics-grounded force mechanics from the design document
## Works with any biome that has quantum_states dictionary

const QuantumGlyph = preload("res://Core/Visualization/QuantumGlyph.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

# Quantum node data (position -> node_data)
var nodes: Dictionary = {}  # Vector2i grid_pos -> {glyph, position, velocity, anchor}
var sun_node = null  # Special celestial node {glyph, position, velocity, anchor}
var biome = null
var emoji_font: Font = null

# Force parameters (physics-grounded)
const TETHER_SPRING = 0.05  # Hooke's law constant (pulls toward anchor)
const REPULSION_STRENGTH = 50000.0  # Inverse-square repulsion (prevents overlap)
const ENERGY_ATTRACTION = 100000.0  # Energy coupling attracts similar nodes
const DAMPING_COEFFICIENT = 0.3  # Exponential decay coefficient (per second)
const MIN_DISTANCE = 5.0  # Minimum node separation

# Visual parameters
const TETHER_COLOR = Color(0.8, 0.8, 0.8, 0.6)
const TETHER_WIDTH = 2.5
# Energy arrow color is parametric - determined by biome's sun visualization
# Day color: bright yellow, Night color: deep blue/purple

# Particles for energy transfer visualization
var energy_particles: Array = []
const MAX_PARTICLES = 200
const PARTICLE_LIFE = 2.0

# Animation state
var time_accumulator: float = 0.0
var frame_count: int = 0


func _ready() -> void:
	# Load emoji font with fallback
	var font_path = "res://Assets/Fonts/NotoColorEmoji.ttf"
	if ResourceLoader.exists(font_path):
		emoji_font = load(font_path)
	else:
		emoji_font = ThemeDB.fallback_font

	if not emoji_font:
		emoji_font = ThemeDB.fallback_font

	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	print("⚛️ QuantumForceGraph initialized (physics-grounded force-directed visualization)")


func connect_biome(biome_ref, plot_pos_dict: Dictionary = {}) -> void:
	"""Connect to any biome and create force-directed nodes for all qubits"""
	nodes.clear()
	biome = biome_ref

	if not biome_ref or not ("quantum_states" in biome_ref):
		print("⚠️ QuantumForceGraph: No biome or quantum_states found")
		return

	# Create nodes for all qubits
	var positions = _get_scatter_positions(plot_pos_dict.size() if not plot_pos_dict.is_empty() else biome_ref.quantum_states.size())
	var idx = 0

	for grid_pos in biome_ref.quantum_states.keys():
		# Skip sun node, handled separately
		if grid_pos == Vector2i(-1, -1):
			continue

		var qubit = biome_ref.quantum_states[grid_pos]
		if not qubit:
			continue

		var glyph = QuantumGlyph.new()
		glyph.qubit = qubit

		# Use provided position or scatter position
		var pos: Vector2
		if plot_pos_dict.has(grid_pos):
			pos = plot_pos_dict[grid_pos]
		elif idx < positions.size():
			pos = positions[idx]
		else:
			pos = get_viewport_rect().size / 2.0

		nodes[grid_pos] = {
			"glyph": glyph,
			"qubit": qubit,
			"position": pos,
			"velocity": Vector2.ZERO,
			"anchor": pos,  # Classical anchor position
			"grid_pos": grid_pos
		}

		idx += 1

	# Create sun/moon celestial node if it exists
	_create_sun_node(plot_pos_dict)

	print("⚛️ QuantumForceGraph: %d nodes + %s" % [nodes.size(), "sun" if sun_node else "no sun"])


func _create_sun_node(plot_pos_dict: Dictionary) -> void:
	"""Create celestial node for sun/moon if biome has sun_qubit"""
	if not biome or not ("sun_qubit" in biome) or not biome.sun_qubit:
		return

	var glyph = QuantumGlyph.new()
	glyph.qubit = biome.sun_qubit

	# Position sun at top-center or from provided positions
	var pos: Vector2
	if plot_pos_dict.has(Vector2i(-1, -1)):
		pos = plot_pos_dict[Vector2i(-1, -1)]
	else:
		var viewport_size = get_viewport_rect().size
		pos = Vector2(viewport_size.x / 2.0, 100.0)

	# Use whatever emojis the biome defined for the sun (parametric - biome-driven)

	sun_node = {
		"glyph": glyph,
		"qubit": biome.sun_qubit,
		"position": pos,
		"velocity": Vector2.ZERO,
		"anchor": pos,
		"grid_pos": Vector2i(-1, -1),
		"is_celestial": true
	}

	print("   ☀️ Celestial sun node created at position: %s" % pos)


func _get_scatter_positions(count: int) -> Array:
	"""Get random scattered positions across the viewport"""
	var positions = []
	var viewport_size = get_viewport_rect().size
	var margin = 100.0
	var valid_width = viewport_size.x - (margin * 2)
	var valid_height = viewport_size.y - (margin * 2)

	for i in range(count):
		var x = margin + randf() * valid_width
		var y = margin + randf() * valid_height
		positions.append(Vector2(x, y))

	return positions


func _process(delta: float) -> void:
	"""Main simulation loop"""
	if not biome or nodes.is_empty():
		return

	time_accumulator += delta
	frame_count += 1

	# Physics simulation
	_update_forces(delta)
	_update_positions(delta)

	# Visualization particles
	_update_particles(delta)

	queue_redraw()


func _update_forces(delta: float) -> void:
	"""Calculate forces on all nodes (Hamiltonian + dissipation)"""
	for grid_pos in nodes.keys():
		var node = nodes[grid_pos]
		var total_force = Vector2.ZERO

		# 1. TETHER: Spring force pulling toward classical anchor (Hooke's law)
		var displacement = node.anchor - node.position
		var tether_force = displacement * TETHER_SPRING
		total_force += tether_force

		# 2. REPULSION + ATTRACTION: Based on energy coupling
		if sun_node and sun_node.qubit:
			var sun_theta = biome.sun_qubit.theta
			var this_energy_rate = pow(cos(node.qubit.theta / 2.0), 2) * pow(cos((node.qubit.theta - sun_theta) / 2.0), 2)

			for other_pos in nodes.keys():
				if other_pos == grid_pos:
					continue
				var other_node = nodes[other_pos]
				var delta_pos = node.position - other_node.position
				var distance = delta_pos.length()

				if distance < MIN_DISTANCE:
					distance = MIN_DISTANCE

				# Calculate energy coupling between this node and other node
				var other_energy_rate = pow(cos(other_node.qubit.theta / 2.0), 2) * pow(cos((other_node.qubit.theta - sun_theta) / 2.0), 2)
				var energy_coupling = this_energy_rate * other_energy_rate

				# REPULSION: Inverse-square repulsion prevents overlap
				var repulsion_mag = REPULSION_STRENGTH / (distance * distance)
				total_force += delta_pos.normalized() * repulsion_mag

				# ATTRACTION: Energy sharing pulls similar nodes together
				if energy_coupling > 0.01:  # Only attract if both are actively receiving energy
					var attraction_mag = ENERGY_ATTRACTION * energy_coupling / (distance * distance)
					total_force -= delta_pos.normalized() * attraction_mag  # Negative = attract

		# 3. REPULSION FROM SUN: Celestial bodies repel
		if sun_node:
			var sun_delta = node.position - sun_node.position
			var sun_dist = sun_delta.length()
			if sun_dist > MIN_DISTANCE:
				var sun_repulsion = REPULSION_STRENGTH * 0.5 / (sun_dist * sun_dist)
				total_force += sun_delta.normalized() * sun_repulsion

		# Apply force to velocity
		node.velocity += total_force * delta

		# Apply exponential damping (velocity decay per second)
		var damping_factor = exp(-DAMPING_COEFFICIENT * delta)
		node.velocity *= damping_factor


func _update_positions(delta: float) -> void:
	"""Update node positions from velocities"""
	for grid_pos in nodes.keys():
		var node = nodes[grid_pos]
		node.position += node.velocity * delta


func _update_particles(delta: float) -> void:
	"""Update energy transfer particles"""
	# Update existing particles
	for i in range(energy_particles.size() - 1, -1, -1):
		var p = energy_particles[i]
		p.life -= delta
		p.position += p.velocity * delta

		if p.life <= 0:
			energy_particles.remove_at(i)

	# Spawn new energy particles (Lindblad evolution visualization)
	_spawn_energy_particles()


func _spawn_energy_particles() -> void:
	"""Spawn particles showing energy transfer (Lindblad coupling)

	Particle color matches the sun's current phase (day = yellow, night = deep blue/purple)
	"""
	if not sun_node or not biome or not ("sun_qubit" in biome):
		return

	if energy_particles.size() >= MAX_PARTICLES:
		return

	# Get parametric sun color for particles
	var sun_color: Color = Color(1.0, 0.8, 0.2)  # Default bright yellow (day)
	if "get_sun_visualization" in biome:
		var sun_vis = biome.get_sun_visualization()
		if sun_vis and "color" in sun_vis:
			sun_color = sun_vis.color

	# Particle spawn probability based on energy transfer rate
	var sun_theta = biome.sun_qubit.theta

	for grid_pos in nodes.keys():
		var node = nodes[grid_pos]
		if not node.qubit:
			continue

		# Energy transfer rate: cos²(θ/2) × cos²((θ-θ_sun)/2)
		var amplitude = pow(cos(node.qubit.theta / 2.0), 2)
		var alignment = pow(cos((node.qubit.theta - sun_theta) / 2.0), 2)
		var transfer_rate = amplitude * alignment

		# Spawn particle with probability proportional to transfer rate
		if transfer_rate > 0.05 and randf() < transfer_rate * 0.05:
			var direction = (node.position - sun_node.position).normalized()
			var particle_color = sun_color  # Parametric color matching sun phase
			particle_color.a = 0.8
			energy_particles.append({
				"position": sun_node.position,
				"velocity": direction * 150.0,
				"life": PARTICLE_LIFE,
				"color": particle_color,
				"size": 4.0
			})


func _draw() -> void:
	"""Render the force-directed graph"""
	if nodes.is_empty():
		return

	frame_count += 1

	# Background (subtle)
	var bg_color = Color(0.08, 0.08, 0.12, 0.08)
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), bg_color)

	# Layer 1: Tether lines (classical positions)
	_draw_tether_lines()

	# Layer 2: Energy transfer arrows (Lindblad visualization)
	_draw_energy_arrows()

	# Layer 3: Energy particles
	_draw_energy_particles()

	# Layer 4: Quantum nodes (glyphs)
	_draw_quantum_nodes()

	# Layer 5: Sun node (always on top)
	_draw_sun_node()


func _draw_tether_lines() -> void:
	"""Draw dashed lines from classical anchors to quantum positions"""
	for grid_pos in nodes.keys():
		var node = nodes[grid_pos]
		var start = node.anchor
		var end = node.position
		var distance = start.distance_to(end)

		if distance < 2.0:
			continue

		# Dashed line
		var direction = (end - start).normalized()
		var dash_len = 8.0
		var gap_len = 6.0
		var current_dist = 0.0

		while current_dist < distance:
			var dash_start = start + direction * current_dist
			var dash_end = start + direction * min(current_dist + dash_len, distance)

			# Fade toward quantum node
			var fade = 1.0 - (current_dist / distance) * 0.5
			var color = TETHER_COLOR
			color.a *= fade

			draw_line(dash_start, dash_end, color, TETHER_WIDTH, true)
			current_dist += dash_len + gap_len


func _draw_energy_arrows() -> void:
	"""Draw arrows showing energy transfer from sun to qubits

	Arrow color is parametric: day = bright yellow, night = deep blue/purple
	"""
	if not sun_node or not biome or not ("sun_qubit" in biome):
		return

	var sun_theta = biome.sun_qubit.theta
	var arrows_drawn = 0

	# Get day/night color from biome (parametric - biome defines the energy color)
	var sun_color: Color = Color(1.0, 0.8, 0.2)  # Default bright yellow (day)
	if "get_sun_visualization" in biome:
		var sun_vis = biome.get_sun_visualization()
		if sun_vis and "color" in sun_vis:
			sun_color = sun_vis.color

	for grid_pos in nodes.keys():
		var node = nodes[grid_pos]
		if not node.qubit:
			continue

		# Energy transfer rate
		var amplitude = pow(cos(node.qubit.theta / 2.0), 2)
		var alignment = pow(cos((node.qubit.theta - sun_theta) / 2.0), 2)
		var transfer_rate = amplitude * alignment

		if transfer_rate < 0.05:
			continue

		# Draw arrow from sun to node
		var from = sun_node.position
		var to = node.position
		var thickness = clamp(transfer_rate * 3.0, 0.5, 2.5)
		var arrow_color = sun_color  # Parametric color from biome
		arrow_color.a = clamp(transfer_rate * 0.6, 0.2, 0.7)

		# Main line
		draw_line(from, to, arrow_color, thickness, true)

		# Arrowhead
		var direction = (to - from).normalized()
		var arrow_size = thickness * 3.0
		var left = to - direction * arrow_size + direction.rotated(PI/2) * arrow_size * 0.5
		var right = to - direction * arrow_size - direction.rotated(PI/2) * arrow_size * 0.5

		var head_color = arrow_color
		head_color.a *= 0.8
		draw_colored_polygon([to, left, right], head_color)

		arrows_drawn += 1


func _draw_energy_particles() -> void:
	"""Draw particles flowing along energy transfer arrows

	Particles maintain their spawned color throughout their lifetime
	"""
	for p in energy_particles:
		var ratio = p.life / PARTICLE_LIFE
		var alpha = clamp(ratio, 0.0, 1.0)

		# Glow (uses particle's stored color)
		var glow = p.color
		glow.a = alpha * 0.4
		draw_circle(p.position, p.size * 2.0, glow)

		# Core (bright center in particle's color)
		var core = p.color.lightened(0.5)
		core.a = alpha * 0.9
		draw_circle(p.position, p.size, core)


func _draw_quantum_nodes() -> void:
	"""Draw all quantum nodes as glyphs"""
	for grid_pos in nodes.keys():
		var node = nodes[grid_pos]
		if not node.glyph or not node.qubit:
			continue

		# Update glyph from qubit data
		node.glyph.update_from_qubit(0.016)

		# CRITICAL: Update glyph position from node position (for force-directed movement)
		node.glyph.position = node.position

		# Draw at current position
		_draw_glyph(node)


func _draw_glyph(node: Dictionary) -> void:
	"""Draw a quantum glyph with energy/coherence encoding"""
	var qubit = node.qubit
	var pos = node.position

	# Size encodes coherence/radius
	var base_size = 25.0
	var size_range = 30.0
	var visual_radius = base_size + qubit.radius * size_range

	# Color from phase with brightness encoding
	var brightness = 0.3 + qubit.radius * 0.7
	var hue = fmod(qubit.phi / TAU, 1.0)
	var color = Color.from_hsv(hue, 0.8, brightness)

	# Outer glow
	var glow = color
	glow.a = 0.3
	draw_circle(pos, visual_radius * 1.6, glow)

	# Mid glow
	glow.a = 0.5
	draw_circle(pos, visual_radius * 1.3, glow)

	# Dark background (emoji contrast)
	var dark_bg = Color(0.1, 0.1, 0.15, 0.85)
	draw_circle(pos, visual_radius * 1.08, dark_bg)

	# Main bubble
	var main = color.lightened(0.15)
	main.a = 0.75
	draw_circle(pos, visual_radius, main)

	# Glossy highlight
	var bright = color.lightened(0.6)
	bright.a = 0.8
	draw_circle(pos - Vector2(visual_radius * 0.25, visual_radius * 0.25), visual_radius * 0.5, bright)

	# Alignment ring - Shows theta distance from sun (green = aligned, red = misaligned)
	if biome and biome.sun_qubit:
		var sun_theta = biome.sun_qubit.theta
		var theta_distance = abs(qubit.theta - sun_theta)
		# Normalize to 0-π range (furthest is π away)
		var normalized_distance = min(theta_distance, TAU - theta_distance) / PI

		# Color gradient: green (aligned) → red (misaligned)
		var alignment_ring = Color.GREEN.lerp(Color.RED, normalized_distance)
		alignment_ring.a = 0.5 * (1.0 - normalized_distance)  # Fade when aligned
		draw_arc(pos, visual_radius * 0.85, 0, TAU, 32, alignment_ring, 3.0, true)

	# Outline
	var outline = Color.WHITE
	outline.a = 0.95
	draw_arc(pos, visual_radius * 1.02, 0, TAU, 64, outline, 2.5, true)

	# Phi direction indicator - Shows azimuthal orientation as small arrow
	var arrow_distance = visual_radius * 1.4
	var arrow_angle = qubit.phi
	var arrow_start = pos + Vector2(cos(arrow_angle), sin(arrow_angle)) * arrow_distance
	var arrow_end = arrow_start + Vector2(cos(arrow_angle), sin(arrow_angle)) * 8.0
	var arrow_color = Color.CYAN
	arrow_color.a = 0.7
	draw_line(arrow_start, arrow_end, arrow_color, 2.5, true)

	# Arrow head
	var head_angle1 = arrow_angle + 2.5
	var head_angle2 = arrow_angle - 2.5
	draw_line(arrow_end, arrow_end - Vector2(cos(head_angle1), sin(head_angle1)) * 4.0, arrow_color, 2.0, true)
	draw_line(arrow_end, arrow_end - Vector2(cos(head_angle2), sin(head_angle2)) * 4.0, arrow_color, 2.0, true)

	# Emojis with superposition opacity
	var font = emoji_font
	var font_size = int(visual_radius * 1.0)
	var text_pos = pos - Vector2(font_size * 0.4, -font_size * 0.25)

	var north_opacity = pow(cos(qubit.theta / 2.0), 2)
	var south_opacity = pow(sin(qubit.theta / 2.0), 2)

	# South emoji
	if south_opacity > 0.01:
		_draw_emoji_shadowed(font, text_pos, qubit.south_emoji, font_size, south_opacity)

	# North emoji (on top)
	if north_opacity > 0.01:
		_draw_emoji_shadowed(font, text_pos, qubit.north_emoji, font_size, north_opacity)

	# Optional: Small theta/phi labels (uncomment to see exact values)
	# var label_font = emoji_font
	# var theta_degrees = int(qubit.theta * 180.0 / PI)
	# var phi_degrees = int(qubit.phi * 180.0 / PI)
	# var label_pos = pos + Vector2(visual_radius + 15, -visual_radius)
	# var label_color = Color.WHITE
	# label_color.a = 0.6
	# draw_string(label_font, label_pos, "θ:%d° φ:%d°" % [theta_degrees, phi_degrees], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_color)


func _draw_emoji_shadowed(font, pos: Vector2, emoji: String, size: int, opacity: float) -> void:
	"""Draw emoji with dark shadow for contrast"""
	var shadow = Color(0, 0, 0, 0.8 * opacity)
	for dx in [-2, -1, 0, 1, 2]:
		for dy in [-2, -1, 0, 1, 2]:
			if dx != 0 or dy != 0:
				draw_string(font, pos + Vector2(dx, dy), emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, size, shadow)

	var main = Color.WHITE
	main.a = opacity
	draw_string(font, pos, emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, size, main)


func _draw_sun_node() -> void:
	"""Draw celestial sun/moon node with day/night cycle

	Day: bright golden yellow with rays
	Night: deep blue/purple midnight energy
	"""
	if not sun_node or not sun_node.qubit:
		return

	var qubit = sun_node.qubit
	var pos = sun_node.position

	# Larger than regular nodes
	var base_size = 40.0
	var visual_radius = base_size

	# Day/night intensity (controls glow and color)
	var sun_intensity = abs(cos(qubit.theta))  # 1.0 = noon, 0.0 = midnight
	var moon_intensity = abs(sin(qubit.theta))  # 1.0 = midnight, 0.0 = noon

	# Parametric colors: day = yellow, night = deep blue/purple
	var day_color = Color(1.0, 0.8, 0.2)      # Bright golden yellow
	var night_color = Color(0.3, 0.2, 0.5)    # Deep blue/purple midnight

	# Interpolate color based on sun/moon phase
	var sun_opacity = pow(cos(qubit.theta / 2.0), 2)
	var moon_opacity = pow(sin(qubit.theta / 2.0), 2)
	var current_color = day_color.lerp(night_color, moon_opacity)

	# Energy-based aura (pulsing with day/night)
	var energy = sun_intensity + moon_intensity * 0.5  # Midnight still has some glow
	var aura_radius = visual_radius * (1.5 + energy * 0.5)
	var aura = current_color
	aura.a = energy * 0.3
	draw_circle(pos, aura_radius, aura)

	# Sun/moon rays (animate based on phase)
	if energy > 0.2:
		var ray_color = current_color
		ray_color.a = energy * 0.6
		for i in range(8):
			var angle = (TAU / 8.0) * i
			var ray_start = pos + Vector2(cos(angle), sin(angle)) * visual_radius
			var ray_end = pos + Vector2(cos(angle), sin(angle)) * (visual_radius + 20.0 * energy)
			draw_line(ray_start, ray_end, ray_color, 1.5, true)

	# Glow layers (day = golden, night = deep purple)
	var glow = current_color
	glow.a = 0.3
	draw_circle(pos, visual_radius * 2.2, glow)

	glow.a = 0.5
	draw_circle(pos, visual_radius * 1.8, glow)

	# Dark background
	var dark_bg = Color(0.1, 0.1, 0.15, 0.85)
	draw_circle(pos, visual_radius * 1.12, dark_bg)

	# Main bubble (color-interpolated)
	var main = current_color.lightened(0.15)
	main.a = 0.75
	draw_circle(pos, visual_radius, main)

	# Glossy center (brighter during day)
	var bright = current_color.lightened(0.6)
	bright.a = 0.8 * energy
	draw_circle(pos - Vector2(visual_radius * 0.25, visual_radius * 0.25), visual_radius * 0.4, bright)

	# Outline (matches current color)
	var outline = current_color.lightened(0.3)
	outline.a = 0.95
	draw_arc(pos, visual_radius * 1.02, 0, TAU, 64, outline, 3.0, true)

	# Sun/moon emojis (read from qubit - Biome is source of truth)
	var font = emoji_font
	var font_size = int(visual_radius * 1.3)
	var text_pos = pos - Vector2(font_size * 0.4, -font_size * 0.25)

	if moon_opacity > 0.01:
		_draw_emoji_shadowed(font, text_pos, qubit.south_emoji, font_size, moon_opacity)

	if sun_opacity > 0.01:
		_draw_emoji_shadowed(font, text_pos, qubit.north_emoji, font_size, sun_opacity)

	# Celestial label
	var label_color = current_color
	label_color.a = 0.7
	var label_pos = pos + Vector2(0, visual_radius + 20)
	draw_string(font, label_pos, "Celestial", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, label_color)
