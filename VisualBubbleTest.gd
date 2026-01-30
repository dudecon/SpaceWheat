extends Node2D

## Visual Bubble Test - Uses TestBootManager for self-contained boot sequence
##
## Decoupled from main game's BootManager refactoring.
## Loads biomes from biomes_merged.json via TestBootManager.

const TestBootManager = preload("res://Tests/TestBootManager.gd")
const QuantumForceGraph = preload("res://Core/Visualization/QuantumForceGraph.gd")
const SimStatsOverlay = preload("res://UI/Overlays/SimStatsOverlay.gd")
const TestInspectorOverlay = preload("res://Tests/TestInspectorOverlay.gd")

var boot_manager: TestBootManager = null
var biomes: Dictionary = {}
var batcher = null
var force_graph: QuantumForceGraph = null
var stats_overlay = null
var inspector_overlay = null
var frame = 0
var test_phase = "init"
var screen_center: Vector2 = Vector2.ZERO
var window_ready: bool = false

# Controls
var evolution_enabled = true
var simulation_time_scale: float = 1.0  # Start at 1x speed (real-time quantum dynamics)

# Stress testing
var spam_active = false
var spam_interval = 0.2
var spam_timer = 0.0
var spam_slot_index = 0

# Biome visibility (TYUIOP toggles)
var biome_visibility: Dictionary = {}  # biome_name → bool
var slot_to_actual_biome: Dictionary = {}  # slot_name → actual_biome_name (for random loading)
const BIOME_KEYS = {
	KEY_T: "CyberDebtMegacity",
	KEY_Y: "StellarForges",
	KEY_U: "VolcanicWorlds",
	KEY_I: "BioticFlux",
	KEY_O: "FungalNetworks",
	KEY_P: "TidalPools"
}

# Biome pool for random selection
var available_biome_pool: Array[String] = [
	"CyberDebtMegacity", "StellarForges", "VolcanicWorlds",
	"BioticFlux", "FungalNetworks", "TidalPools",
	"Village", "StarterForest", "BureaucraticAbyss",
	"GildedRot", "HorizonFracture"
]

# Position tracking
var position_tracker: Array = []
var tracking_node = null


func _ready():
	print("\n" + "=".repeat(70))
	print("VISUAL BUBBLE TEST - TestBootManager")
	print("=".repeat(70))

	# Create boot manager
	boot_manager = TestBootManager.new()
	boot_manager.boot_progress.connect(_on_boot_progress)

	# List available biomes
	print("\nAvailable biomes: %s" % ", ".join(boot_manager.get_available_biomes()))

	# Wait for window to be fully initialized
	test_phase = "waiting_for_window"
	print("\n[PHASE 0] Waiting for window initialization...")
	frame = 0


func _on_boot_progress(stage: String, message: String):
	print("[%s] %s" % [stage, message])


func _check_window_ready():
	"""Wait for window to be fully initialized before proceeding"""
	frame += 1

	var viewport = get_viewport()
	if not viewport:
		return

	var window_size = Vector2.ZERO
	if DisplayServer.get_name() != "headless":
		window_size = DisplayServer.window_get_size()
	else:
		window_size = viewport.get_visible_rect().size

	if window_size.x <= 0 or window_size.y <= 0:
		if frame % 60 == 0:
			print("  Waiting for window... (size=%s)" % window_size)
		return

	# Window is ready!
	window_ready = true
	screen_center = window_size / 2.0

	print("  Window ready: %s" % window_size)
	print("  Screen center: %s" % screen_center)

	# Position camera
	var camera = get_node("Camera2D")
	if camera:
		camera.position = screen_center
		print("  Camera positioned at: %s" % camera.position)

	# Start boot sequence
	test_phase = "booting"
	frame = 0
	_start_boot()


func _start_boot():
	"""Start the boot sequence using TestBootManager"""
	print("\n[BOOT] Starting TestBootManager boot sequence...")

	# Load 6 biomes (exclude Village, StarterForest) - mapped to TYUIOP
	var result = await boot_manager.boot_biomes(self, [
		"CyberDebtMegacity",    # T
		"StellarForges",        # Y
		"VolcanicWorlds",       # U
		"BioticFlux",           # I
		"FungalNetworks",       # O
		"TidalPools"            # P
	])

	if not result.get("success", false):
		print("\nBOOT FAILED: %s" % result.get("error", "unknown"))
		test_phase = "failed"
		return

	biomes = result.get("biomes", {})
	batcher = result.get("batcher")

	# Initialize biome visibility (all start visible)
	for biome_name in biomes:
		biome_visibility[biome_name] = true

	# Position biomes farther apart in 2x3 grid
	var positions = {
		"CyberDebtMegacity": Vector2(-0.9, -0.6),   # Top-left (T)
		"StellarForges": Vector2(0, -0.6),          # Top-center (Y)
		"VolcanicWorlds": Vector2(0.9, -0.6),       # Top-right (U)
		"BioticFlux": Vector2(-0.9, 0.6),           # Bottom-left (I)
		"FungalNetworks": Vector2(0, 0.6),          # Bottom-center (O)
		"TidalPools": Vector2(0.9, 0.6)             # Bottom-right (P)
	}
	for biome_name in positions:
		if biomes.has(biome_name):
			biomes[biome_name].visual_center_offset = positions[biome_name]
			print("  Positioned %s at offset %s" % [biome_name, positions[biome_name]])

	# Create visualization
	await _create_visualization()


func _create_visualization():
	"""Create QuantumForceGraph with booted biomes"""
	print("\n[VIZ] Creating QuantumForceGraph...")

	force_graph = boot_manager.create_force_graph(self, biomes, batcher)

	# Center the graph at screen center
	print("  Centering at: %s" % screen_center)
	force_graph.layout_calculator.graph_center = screen_center
	force_graph.center_position = screen_center

	# Recalculate biome ovals to be centered
	var default_center = Vector2(960, 540)
	for biome_name in force_graph.layout_calculator.biome_ovals:
		var biome_oval = force_graph.layout_calculator.biome_ovals[biome_name]
		var old_center = biome_oval.get("center", Vector2.ZERO)
		var offset = screen_center - default_center
		biome_oval["center"] = old_center + offset

	# Recalculate node positions
	for node in force_graph.quantum_nodes:
		var new_pos = force_graph.layout_calculator.get_parametric_position(
			node.biome_name, node.parametric_t, node.parametric_ring
		)
		node.position = new_pos
		node.classical_anchor = new_pos

	# Create stats overlay
	stats_overlay = SimStatsOverlay.new()
	stats_overlay.name = "SimStatsOverlay"
	stats_overlay.set_meta("test_controller", self)
	add_child(stats_overlay)

	# Create inspector overlay (density matrix display)
	inspector_overlay = TestInspectorOverlay.new()
	inspector_overlay.name = "InspectorOverlay"
	inspector_overlay.visible = false  # Start hidden
	inspector_overlay.position = Vector2(20, 20)  # Top-left corner
	add_child(inspector_overlay)
	inspector_overlay.set_biomes(biomes)
	print("  Inspector overlay created (press N to toggle)")

	await get_tree().process_frame

	# Report
	var bubble_count = force_graph.quantum_nodes.size()
	print("  Bubbles created: %d" % bubble_count)

	if bubble_count > 0:
		var node = force_graph.quantum_nodes[0]
		print("  Sample: %s:r%d (north='%s', south='%s')" % [
			node.biome_name, node.register_id, node.emoji_north, node.emoji_south
		])
	else:
		print("  WARNING: No bubbles created!")

	test_phase = "running"
	frame = 0

	print("\n[RUNNING] Test active!")
	print("  Evolution: %s" % ("ENABLED" if evolution_enabled else "DISABLED"))
	print("  Simulation speed: %.3fx%s (floor: 1/256x)" % [simulation_time_scale, _get_speed_fraction(simulation_time_scale)])
	print("  Inspector: %s" % ("ON" if inspector_overlay.visible else "OFF"))
	if DisplayServer.get_name() != "headless":
		print("\n  Controls:")
		print("    SPACE = Toggle evolution")
		print("    - / = = Slow down / Speed up (floor: 1/256x)")
		print("    N = Toggle density inspector")
		print("    F = Cycle inspector view (heatmap ↔ bars)")
		print("    TYUIOP = Inspector ON: Select biome | Inspector OFF: Load random biome in slot")
		print("      T/Y/U/I/O/P = 6 slots (toggle on loads random from pool)")
		print("    S = STRESS TEST: Rapid biome toggle spam (tests BiomeBuilder robustness)")
		print("    ESC = Exit")
	print("")


func _process(delta):
	queue_redraw()

	match test_phase:
		"waiting_for_window":
			_check_window_ready()
		"running":
			_run_test(delta)


func _run_test(delta):
	"""Run the test - evolve and update"""
	frame += 1

	# Stress test: spam toggle biomes
	if spam_active:
		spam_timer += delta
		if spam_timer >= spam_interval:
			spam_timer = 0.0
			# Cycle through slots, toggling off and on
			var slots = [KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P]
			_toggle_biome_visibility(slots[spam_slot_index % slots.size()])
			spam_slot_index += 1

	# Evolution with time scaling
	if evolution_enabled and batcher:
		var scaled_delta = delta * simulation_time_scale
		batcher.physics_process(scaled_delta)

	# Track position of first bubble
	if tracking_node == null and force_graph and force_graph.quantum_nodes.size() > 0:
		tracking_node = force_graph.quantum_nodes[0]
	if tracking_node:
		position_tracker.append(tracking_node.position)
		if position_tracker.size() > 600:
			position_tracker.pop_front()

	# Set initial velocities at frame 3
	if frame == 3 and force_graph:
		print("\n[Frame 3] Setting initial velocities...")
		for node in force_graph.quantum_nodes:
			var angle = randf() * TAU
			var speed = 100.0 + randf() * 100.0
			node.velocity = Vector2(cos(angle), sin(angle)) * speed
		print("  Set velocities for %d nodes" % force_graph.quantum_nodes.size())

	# Sample node state at frame 5
	if frame == 5 and force_graph and force_graph.quantum_nodes.size() > 0:
		var node = force_graph.quantum_nodes[0]
		print("\n[Frame 5] Bubble state:")
		print("  %s:r%d - scale=%.2f, alpha=%.2f, radius=%.1f" % [
			node.biome_name, node.register_id, node.visual_scale, node.visual_alpha, node.radius
		])
		print("  Position: %s, Velocity: %.1f px/s" % [node.position, node.velocity.length()])
		print("  Emoji opacities: north=%.2f, south=%.2f" % [
			node.emoji_north_opacity, node.emoji_south_opacity
		])

	# Headless: exit after 200 frames
	if DisplayServer.get_name() == "headless" and frame >= 200:
		print("\n[HEADLESS] Completed 200 frames, exiting...")
		get_tree().quit()
		return

	# Stats every 60 frames
	if frame % 60 == 0 and frame >= 5:
		var total_bubbles = force_graph.quantum_nodes.size() if force_graph else 0
		var fps = Engine.get_frames_per_second()

		print("\n[Frame %d] %.1f FPS" % [frame, fps])
		print("  Simulation: %s at %.3fx speed" % [
			"ENABLED" if evolution_enabled else "DISABLED",
			simulation_time_scale
		])
		print("  Bubbles: %d across %d biomes" % [total_bubbles, biomes.size()])

		if tracking_node and position_tracker.size() >= 60:
			var total_distance = 0.0
			for i in range(1, position_tracker.size()):
				total_distance += position_tracker[i].distance_to(position_tracker[i-1])
			print("  Movement (last 60f): %.1fpx traveled, velocity=%.1fpx/s" % [
				total_distance, tracking_node.velocity.length()
			])


func _select_biome_in_inspector(keycode: int):
	"""Select biome in inspector using TYUIOP keys."""
	if not BIOME_KEYS.has(keycode):
		return

	# Map TYUIOP to indices 0-5
	var key_to_index = {
		KEY_T: 0,
		KEY_Y: 1,
		KEY_U: 2,
		KEY_I: 3,
		KEY_O: 4,
		KEY_P: 5
	}

	if inspector_overlay:
		inspector_overlay.select_biome(key_to_index[keycode])


func _toggle_biome_visibility(keycode: int):
	"""Toggle biome evolution using TYUIOP keys (when inspector hidden).

	When toggled OFF: Remove from evolution and rendering
	When toggled ON: Pick random biome and load it in this slot
	"""
	if not BIOME_KEYS.has(keycode):
		return

	var slot_biome_name = BIOME_KEYS[keycode]

	# Toggle evolution state
	var was_active = biome_visibility.get(slot_biome_name, true)
	biome_visibility[slot_biome_name] = !was_active
	var is_active = biome_visibility[slot_biome_name]

	if is_active and not was_active:
		# Toggling ON: Pick random biome from pool
		var random_biome = available_biome_pool[randi() % available_biome_pool.size()]
		print("\n[REBUILD] Slot %s → Random biome: %s" % [
			slot_biome_name.substr(0, 1), random_biome
		])

		# Rebuild biome using BiomeBuilder
		var rebuild_result = await boot_manager.boot_biomes(self, [random_biome])
		if rebuild_result.get("success", false):
			var rebuilt_biomes = rebuild_result.get("biomes", {})
			if rebuilt_biomes.has(random_biome):
				var new_biome = rebuilt_biomes[random_biome]

				# Remove old biome from slot if exists
				if biomes.has(slot_biome_name):
					var old_biome = biomes[slot_biome_name]
					if batcher:
						var idx = batcher.biomes.find(old_biome)
						if idx >= 0:
							batcher.biomes.remove_at(idx)
					biomes.erase(slot_biome_name)

				# Assign new biome to slot
				biomes[slot_biome_name] = new_biome

				# Track which actual biome is in this slot (for incremental node removal)
				slot_to_actual_biome[slot_biome_name] = random_biome

				# Position biome at slot location
				var positions = {
					"CyberDebtMegacity": Vector2(-0.9, -0.6),   # T
					"StellarForges": Vector2(0, -0.6),          # Y
					"VolcanicWorlds": Vector2(0.9, -0.6),       # U
					"BioticFlux": Vector2(-0.9, 0.6),           # I
					"FungalNetworks": Vector2(0, 0.6),          # O
					"TidalPools": Vector2(0.9, 0.6)             # P
				}
				if positions.has(slot_biome_name):
					new_biome.visual_center_offset = positions[slot_biome_name]

				# Register with batcher
				if batcher:
					batcher.register_biome(new_biome)

				# Add nodes for this biome only (incremental, not full rebuild)
				if force_graph:
					force_graph.add_nodes_for_biome(random_biome, new_biome)

				# Update inspector
				if inspector_overlay:
					inspector_overlay.set_biomes(biomes)

				print("  Slot %s ← %s (%d qubits)" % [
					slot_biome_name.substr(0, 1),
					random_biome,
					new_biome.quantum_computer.register_map.num_qubits
				])
		else:
			print("  REBUILD FAILED: %s" % random_biome)
	else:
		# Toggling OFF: Remove from batcher and remove nodes
		var biome = biomes.get(slot_biome_name)
		if biome and batcher:
			# Remove from batcher's biomes array
			var idx = batcher.biomes.find(biome)
			if idx >= 0:
				batcher.biomes.remove_at(idx)

		# Remove nodes for this biome from force graph (incremental)
		# Use actual biome name, not slot name
		var actual_biome_name = slot_to_actual_biome.get(slot_biome_name, slot_biome_name)
		if force_graph:
			force_graph.remove_nodes_for_biome(actual_biome_name)

		# Clean up tracking
		slot_to_actual_biome.erase(slot_biome_name)

		print("Slot %s: Evolution DISABLED" % slot_biome_name.substr(0, 1))


func _get_speed_fraction(speed: float) -> String:
	var lookup = {
		0.03125: " (1/32)", 0.0625: " (1/16)", 0.125: " (1/8)",
		0.25: " (1/4)", 0.5: " (1/2)", 1.0: " (1x)",
		2.0: " (2x)", 4.0: " (4x)", 8.0: " (8x)", 16.0: " (16x)"
	}
	for key in lookup.keys():
		if abs(speed - key) < 1e-4:
			return lookup[key]
	return ""


func _draw():
	"""Draw debug center crosshair"""
	if window_ready and screen_center != Vector2.ZERO:
		var size = 20.0
		draw_line(screen_center + Vector2(-size, 0), screen_center + Vector2(size, 0), Color.RED, 2.0)
		draw_line(screen_center + Vector2(0, -size), screen_center + Vector2(0, size), Color.RED, 2.0)
		draw_circle(screen_center, 5.0, Color(1, 0, 0, 0.3))


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				print("\nExiting test...")
				get_tree().quit()

			KEY_SPACE:
				evolution_enabled = !evolution_enabled
				print("Evolution: %s" % ("ON" if evolution_enabled else "OFF"))

			KEY_MINUS:
				simulation_time_scale = max(simulation_time_scale * 0.5, 1.0/256.0)  # Floor: 1/256x
				print("Simulation SLOWER: %.3fx%s" % [simulation_time_scale, _get_speed_fraction(simulation_time_scale)])

			KEY_EQUAL:
				simulation_time_scale = min(simulation_time_scale * 2.0, 16.0)
				print("Simulation FASTER: %.3fx%s" % [simulation_time_scale, _get_speed_fraction(simulation_time_scale)])

			KEY_N:
				if inspector_overlay:
					inspector_overlay.visible = !inspector_overlay.visible
					print("Inspector: %s" % ("ON" if inspector_overlay.visible else "OFF"))

			KEY_F:
				if inspector_overlay:
					inspector_overlay.toggle_view_mode()

			KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P:
				# If inspector is visible, use TYUIOP to select biome
				# If inspector is hidden, use TYUIOP to toggle visibility
				if inspector_overlay and inspector_overlay.visible:
					_select_biome_in_inspector(event.keycode)
				else:
					_toggle_biome_visibility(event.keycode)

			KEY_S:
				# Stress test: toggle spam mode
				spam_active = !spam_active
				if spam_active:
					spam_slot_index = 0
					spam_timer = 0.0
					print("\n[STRESS] Biome toggle SPAM started (%.1fs interval)" % spam_interval)
				else:
					print("\n[STRESS] Biome toggle SPAM stopped")
