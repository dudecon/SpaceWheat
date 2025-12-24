extends Node

## Test: Load wheat in BioticFluxBiome and visualize energy transfer
## Shows real-time quantum evolution with sun/moon cycling and energy growth

const SimpleQuantumVisualizationController = preload("res://Core/Visualization/SimpleQuantumVisualizationController.gd")
const QuantumGlyph = preload("res://Core/Visualization/QuantumGlyph.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var biome = null
var visualization: SimpleQuantumVisualizationController = null
var frame_count: int = 0
var wheat_positions: Array = []  # Track wheat positions
var mushroom_positions: Array = []  # Track mushroom positions


func _ready() -> void:
	var sep = "=================================================================================="
	print("\n" + sep)
	print("BIOTIC FLUX WHEAT TEST - Energy Transfer Simulation")
	print("Watch wheat grow as sun provides energy and icon provides alignment")
	print(sep + "\n")

	# Create container
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	# Create BioticFluxBiome
	print("🌍 Creating BioticFluxBiome...")
	biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame
	print("   ✓ BioticFluxBiome initialized")
	print("   ✓ Sun/Moon qubit created (immutable)")
	print("   ✓ Wheat icon initialized (θ_stable = π/4)")
	print("   ✓ Base temperature: %.0fK" % biome.base_temperature)
	print("   ✓ Base energy rate: %.3f" % biome.base_energy_rate)

	# Add wheat and mushrooms with varied theta angles
	print("\n🌾 Planting wheat with varied theta angles...")
	_plant_varied_wheat(3, 3)  # 3x3 grid of wheat at different angles
	print("   ✓ Planted %d wheat qubits" % wheat_positions.size())

	print("\n🍄 Planting mushrooms with varied theta angles...")
	_plant_varied_mushrooms()  # Mushrooms scattered at θ ≈ π
	print("   ✓ Planted %d mushroom qubits" % mushroom_positions.size())

	# Create force-directed quantum visualization
	print("\n📊 Creating force-directed quantum visualization...")
	visualization = SimpleQuantumVisualizationController.new()
	visualization.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(visualization)

	# Get random scatter positions and connect biome
	print("\n☀️ Initializing force-directed graph with scattered nodes...")
	var plot_positions = _get_plot_positions()
	visualization.connect_biome(biome, plot_positions)
	print("   ✓ Force-directed graph initialized with physics")
	print("   ✓ Nodes: %d (wheat + mushrooms with forces + sun celestial)" % visualization.nodes.size())

	print("\n⚡ ENERGY TRANSFER DYNAMICS")
	print("   Energy formula: rate = base × cos²(θ/2) × cos²((θ-θ_sun)/2) × icon_influence")
	print("   Wheat amplitude: cos²(θ/2) - grows at θ=0 (🌾 state)")
	print("   Alignment: cos²((θ-θ_sun)/2) - synchronized with sun's phase")
	print("   Wheat influence: %.3f (weak without icon/mushroom)" % biome.wheat_energy_influence)
	print("\n   Watch for:")
	print("   ✓ Emoji glyph opacity changing as energy changes")
	print("   ✓ Ring thickness increasing as energy accumulates")
	print("   ✓ Glow intensity growing")
	print("   ✓ Berry bar filling (evolution history)\n")


func _plant_varied_wheat(width: int, height: int) -> void:
	"""Plant wheat qubits at different theta angles"""
	var center_x = -width / 2
	var center_y = -height / 2

	for x in range(width):
		for y in range(height):
			var pos = Vector2i(center_x + x, center_y + y)

			# Create wheat qubit (🌾 = north, 💧 = south)
			var wheat = DualEmojiQubit.new()
			wheat.north_emoji = "🌾"
			wheat.south_emoji = "💧"

			# Vary theta from -π/4 to π/4 (wheat-leaning states)
			# Use position to determine angle for visual effect
			var angle_variation = (x - center_x) * PI / (width * 2.0)  # -π/4 to π/4
			wheat.theta = angle_variation

			wheat.phi = randf() * TAU
			wheat.radius = 0.3  # Initial energy
			wheat.energy = 0.3

			# Register with biome
			biome.quantum_states[pos] = wheat
			biome.plots_by_type[biome.PlotType.FARM].append(pos)
			biome.plot_types[pos] = biome.PlotType.FARM

			wheat_positions.append(pos)


func _plant_varied_mushrooms() -> void:
	"""Plant mushroom qubits scattered at different theta angles (near π)"""
	var positions = [
		Vector2i(-2, -2),
		Vector2i(0, -2),
		Vector2i(2, -2),
		Vector2i(-1, 2),
		Vector2i(1, 2),
	]

	for pos in positions:
		# Create mushroom qubit (🍂 = north/day, 🍄 = south/night)
		var mushroom = DualEmojiQubit.new()
		mushroom.north_emoji = "🍂"  # Detritus/decay during day
		mushroom.south_emoji = "🍄"  # Mushroom active at night

		# Start at dusk theta (π/2 = evening/transition) with variation
		# This lets them evolve toward night (π) as energy flows
		var dusk_angle = PI / 2.0
		var angle_offset = randf_range(-PI/8, PI/8)  # Smaller variation around dusk
		mushroom.theta = dusk_angle + angle_offset

		# Random azimuthal angle
		mushroom.phi = randf() * TAU
		mushroom.radius = 0.3  # Initial energy
		mushroom.energy = 0.3

		# Register with biome
		biome.quantum_states[pos] = mushroom
		biome.plots_by_type[biome.PlotType.FARM].append(pos)
		biome.plot_types[pos] = biome.PlotType.FARM

		mushroom_positions.append(pos)


func _get_plot_positions() -> Dictionary:
	"""Get screen positions for all qubits scattered randomly on screen"""
	var positions = {}

	# Get actual window size or use fallback
	# Use a reasonable default for headless mode (typically 64×64)
	var viewport_size = Vector2(1920, 1080)
	if get_window():
		var actual = get_window().get_size()
		# Only use if it's a reasonable size (not headless 64×64)
		if actual.x > 200 and actual.y > 200:
			viewport_size = actual

	# Margin from edges (pixels)
	var margin = 100.0
	var valid_width = viewport_size.x - (margin * 2)
	var valid_height = viewport_size.y - (margin * 2)

	print("   Screen resolution: %.0f × %.0f" % [viewport_size.x, viewport_size.y])

	# Scatter sun/moon at top-center (it's at Vector2i(-1, -1) in quantum_states)
	positions[Vector2i(-1, -1)] = Vector2(viewport_size.x / 2.0, margin + 50)

	# Scatter wheat randomly
	for pos in wheat_positions:
		var random_x = margin + randf() * valid_width
		var random_y = margin + randf() * valid_height
		positions[pos] = Vector2(random_x, random_y)

	# Scatter mushrooms randomly
	for pos in mushroom_positions:
		var random_x = margin + randf() * valid_width
		var random_y = margin + randf() * valid_height
		positions[pos] = Vector2(random_x, random_y)

	return positions


func _process(delta: float) -> void:
	frame_count += 1

	# Print detailed energy data every 60 frames (1 second at 60 FPS)
	if frame_count % 60 == 0:
		_print_energy_state()


func _print_energy_state() -> void:
	"""Print current energy state of wheat qubits"""
	if not biome or wheat_positions.is_empty():
		return

	var elapsed = frame_count / 60.0
	var sample_pos = wheat_positions[0]  # Sample first wheat plot
	var sample_qubit = biome.quantum_states.get(sample_pos)

	if not sample_qubit:
		return

	# Calculate energy components
	var amplitude = pow(cos(sample_qubit.theta / 2.0), 2)
	var alignment = pow(cos((sample_qubit.theta - biome.sun_qubit.theta) / 2.0), 2)
	var sun_phase = "☀️" if biome.is_currently_sun() else "🌙"

	print("⏱️  [%.1fs] %s" % [elapsed, sun_phase])
	print("   🌾 Wheat [sample]:")
	print("      θ = %.3f rad (%.0f°) | φ = %.3f rad" % [
		sample_qubit.theta,
		sample_qubit.theta * 180 / PI,
		sample_qubit.phi
	])
	print("      Energy: %.3f | Radius: %.3f" % [sample_qubit.energy, sample_qubit.radius])
	print("      Amplitude (cos²(θ/2)): %.3f" % amplitude)
	print("      Alignment (cos²((θ-θ_sun)/2)): %.3f" % alignment)

	# Sun/Moon state
	print("   ☀️ Sun/Moon:")
	print("      θ = %.3f rad (%.0f°)" % [biome.sun_qubit.theta, biome.sun_qubit.theta * 180 / PI])
	print("      Intensity (day-phase): %.3f" % pow(cos(biome.sun_qubit.theta / 2.0), 2))

	# Temperature
	print("   🌡️  Temperature: %.0fK (base: %.0fK)" % [
		biome.temperature_grid.get(sample_pos, biome.base_temperature),
		biome.base_temperature
	])

	# Statistics across all crops
	var total_energy = 0.0
	var max_energy = 0.0
	var wheat_avg_theta = 0.0
	var mushroom_count = 0
	var mushroom_avg_theta = 0.0

	for pos in wheat_positions:
		var q = biome.quantum_states.get(pos)
		if q:
			total_energy += q.energy
			max_energy = max(max_energy, q.energy)
			wheat_avg_theta += q.theta

	wheat_avg_theta /= wheat_positions.size()

	for pos in mushroom_positions:
		var q = biome.quantum_states.get(pos)
		if q:
			total_energy += q.energy
			max_energy = max(max_energy, q.energy)
			mushroom_avg_theta += q.theta
			mushroom_count += 1

	if mushroom_count > 0:
		mushroom_avg_theta /= mushroom_count

	print("   📈 Aggregate Stats:")
	print("      Total energy (wheat+mushroom): %.3f | Max: %.3f" % [total_energy, max_energy])
	print("      Wheat avg θ: %.3f rad | Mushroom avg θ: %.3f rad" % [wheat_avg_theta, mushroom_avg_theta])
	print()


func _exit_tree() -> void:
	var sep = "=================================================================================="
	print("\n" + sep)
	print("Biotic Flux Wheat Test Complete")
	print("Wheat energy should grow with sun alignment and icon influence")
	print(sep + "\n")
