extends Node2D

## Visual Bubble Test - Uses TestBootManager for self-contained boot sequence
##
## Decoupled from main game's BootManager refactoring.
## Loads biomes from biomes_merged.json via TestBootManager.

const TestBootManager = preload("res://Tests/TestBootManager.gd")
const QuantumForceGraph = preload("res://Core/Visualization/QuantumForceGraph.gd")
const SimStatsOverlay = preload("res://UI/Overlays/SimStatsOverlay.gd")
const TestInspectorOverlay = preload("res://Tests/TestInspectorOverlay.gd")
const FrameBudgetProfiler = preload("res://Tests/FrameBudgetProfiler.gd")
const RenderingProfiler = preload("res://Tests/RenderingProfiler.gd")
const ComputeBenchmark = preload("res://Tests/ComputeBenchmark.gd")

var boot_manager: TestBootManager = null
var biomes: Dictionary = {}
var batcher = null
var lookahead_engine = null  # Native C++ evolution engine (shared across all biomes)
var emoji_atlas = null  # Pre-built emoji atlas for GPU-accelerated rendering
var bubble_atlas = null  # Pre-built bubble atlas for GPU-accelerated bubble rendering
var force_graph: QuantumForceGraph = null
var stats_overlay = null
var inspector_overlay = null
var frame = 0
var test_phase = "init"
var screen_center: Vector2 = Vector2.ZERO
var window_ready: bool = false

# Benchmark
var benchmark: ComputeBenchmark = null
var benchmark_results: Dictionary = {}
var run_benchmark: bool = false  # Disabled during profiling (too slow)

# Profiling
var profiling_enabled: bool = true  # Enable force calculation profiling
var profiling_started: bool = false

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
	lookahead_engine = result.get("lookahead_engine")  # Store for dynamic biome loading
	emoji_atlas = result.get("emoji_atlas_batcher")
	bubble_atlas = result.get("bubble_atlas_batcher")

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

	force_graph = boot_manager.create_force_graph(self, biomes, batcher, emoji_atlas, bubble_atlas)

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
	inspector_overlay.batcher = batcher  # For PFPS display
	print("  Inspector overlay created (press N to toggle)")

	# Create frame budget profiler
	var profiler = FrameBudgetProfiler.new()
	profiler.name = "FrameBudgetProfiler"
	profiler.set_meta("test_controller", self)
	add_child(profiler)
	print("  Frame budget profiler created (reports every 180 frames)")

	# Create rendering profiler
	var render_profiler = RenderingProfiler.new()
	render_profiler.name = "RenderingProfiler"
	render_profiler.set_meta("test_controller", self)
	add_child(render_profiler)
	print("  Rendering profiler created (reports every 60 frames)")

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

	# Run benchmark if enabled (skip in headless mode)
	if run_benchmark and DisplayServer.get_name() != "headless":
		print("\n[BENCHMARK] Running compute backend benchmark...")
		test_phase = "benchmarking"
		_run_benchmark()
		await benchmark.benchmark_complete
		print("[BENCHMARK] Complete!")
	else:
		print("\n[BENCHMARK] Skipped (headless or disabled)")

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
		"benchmarking":
			pass  # Benchmark runs async
		"running":
			_run_visual_update(delta)


func _run_benchmark():
	"""Run compute backend benchmark."""
	benchmark = ComputeBenchmark.new()

	# Connect progress signal for live updates
	benchmark.benchmark_progress.connect(_on_benchmark_progress)

	# Run benchmark (uses first biome for test data)
	var first_biome = biomes.values()[0] if biomes.size() > 0 else null
	benchmark_results = benchmark.run_benchmark(first_biome)

	# Store results for later reference
	if force_graph and force_graph.force_system:
		# TODO: Could update force_system's backend based on results
		pass


func _on_benchmark_progress(backend: String, iteration: int, total: int):
	"""Handle benchmark progress updates."""
	if iteration == 1:
		print("  %s: iteration %d/%d..." % [backend.to_upper(), iteration, total])


func _physics_process(delta):
	"""Physics loop - runs at fixed rate, handles quantum evolution"""
	if test_phase == "running":
		_run_physics_update(delta)


func _run_physics_update(delta):
	"""Physics loop - quantum evolution only"""
	# Evolution with time scaling
	if evolution_enabled and batcher:
		var scaled_delta = delta * simulation_time_scale
		batcher.physics_process(scaled_delta)


func _run_visual_update(delta):
	"""Visual loop - rendering and UI updates"""
	frame += 1

	# Track visual frames for batching verification
	if batcher and batcher.has_method("track_visual_frame"):
		batcher.track_visual_frame()

	# Stress test: spam toggle biomes
	if spam_active:
		spam_timer += delta
		if spam_timer >= spam_interval:
			spam_timer = 0.0
			# Cycle through slots, toggling off and on
			var slots = [KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P]
			_toggle_biome_visibility(slots[spam_slot_index % slots.size()])
			spam_slot_index += 1

	# Track position of first bubble
	if tracking_node == null and force_graph and force_graph.quantum_nodes.size() > 0:
		tracking_node = force_graph.quantum_nodes[0]
	if tracking_node:
		position_tracker.append(tracking_node.position)
		if position_tracker.size() > 600:
			position_tracker.pop_front()

	# Enable profiling at frame 1 of running phase
	if frame == 1 and profiling_enabled and not profiling_started and force_graph and force_graph.force_system:
		profiling_started = true
		force_graph.force_system.enable_profiling()

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

	# Detailed per-frame batching log (frames 10-100) to verify batching
	if frame >= 10 and frame <= 100 and batcher:
		var diag = batcher.get_batching_diagnostics() if batcher.has_method("get_batching_diagnostics") else {}
		var metrics = batcher.get_performance_metrics() if batcher.has_method("get_performance_metrics") else {}
		var cursor = diag.get("buffer_cursor", -1)
		var buffer_size = diag.get("buffer_size", 0)
		var depth = buffer_size - cursor if buffer_size > 0 else 0
		var pending = metrics.get("batches_pending", 0)
		var in_flight = metrics.get("batches_in_flight", 0)
		var batch_ms = metrics.get("last_batch_time_ms", 0.0)
		print("[F%d] buf=%d/%d pend=%d fly=%d t=%.2f batch=%.1fms" % [
			frame, depth, buffer_size, pending, in_flight,
			diag.get("interpolation_t", 0.0), batch_ms
		])

	# Headless: exit after 500 frames
	if DisplayServer.get_name() == "headless" and frame >= 500:
		print("\n[HEADLESS] Completed 500 frames, exiting...")
		get_tree().quit()
		return

	# Stats every 60 frames
	if frame % 60 == 0 and frame >= 5:
		var total_bubbles = force_graph.quantum_nodes.size() if force_graph else 0
		var vfps = Engine.get_frames_per_second()
		var metrics = batcher.get_performance_metrics() if batcher and batcher.has_method("get_performance_metrics") else {}

		var depth = metrics.get("buffer_depth", 0)
		var coverage_ms = metrics.get("buffer_coverage_ms", 0.0)
		var pending = metrics.get("batches_pending", 0)
		var batch_ms = metrics.get("avg_batch_time_ms", 0.0)
		var refills = metrics.get("refill_count", 0)

		print("\n[F%d] %.0f FPS | buf=%d (%.0fms) | pend=%d | batch=%.1fms | refills=%d | %d bubbles" % [
			frame, vfps, depth, coverage_ms, pending, batch_ms, refills, total_bubbles
		])

	# Detailed C++ task profiling every ~10 physics frames (100 visual frames)
	if frame % 100 == 0 and frame >= 100 and batcher:
		_print_cpp_profiling_report()


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

	IMPORTANT: Uses lightweight build_single_biome() to avoid creating
	new engine/batcher instances. Reuses existing infrastructure.
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

		# Remove old biome from slot if exists
		if biomes.has(slot_biome_name):
			var old_biome = biomes[slot_biome_name]
			var actual_old_name = slot_to_actual_biome.get(slot_biome_name, slot_biome_name)

			# Use lightweight unregister
			boot_manager.unregister_biome(old_biome, batcher)

			# Remove nodes from force graph
			if force_graph:
				force_graph.remove_nodes_for_biome(actual_old_name)

			biomes.erase(slot_biome_name)

		# Build single biome using LIGHTWEIGHT method (reuses existing engine/batcher)
		var build_result = boot_manager.build_single_biome(
			random_biome,
			self,
			batcher,
			lookahead_engine
		)

		if build_result.get("success", false):
			var new_biome = build_result.get("biome")

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

			# Register biome with layout calculator BEFORE creating nodes
			if force_graph and force_graph.layout_calculator:
				# Ensure layout calculator knows about this biome type
				force_graph.layout_calculator.get_biome_oval(random_biome)

			# Add nodes for this biome only (incremental, not full rebuild)
			if force_graph:
				force_graph.add_nodes_for_biome(random_biome, new_biome)

			# Update inspector
			if inspector_overlay:
				inspector_overlay.set_biomes(biomes)

			print("  Slot %s ← %s (%d qubits, engine_id=%d)" % [
				slot_biome_name.substr(0, 1),
				random_biome,
				new_biome.quantum_computer.register_map.num_qubits,
				build_result.get("biome_id", -1)
			])
		else:
			print("  REBUILD FAILED: %s (%s)" % [random_biome, build_result.get("error", "unknown")])
			biome_visibility[slot_biome_name] = false  # Revert toggle state
	else:
		# Toggling OFF: Remove from batcher and remove nodes
		var biome = biomes.get(slot_biome_name)
		var actual_biome_name = slot_to_actual_biome.get(slot_biome_name, slot_biome_name)

		if biome:
			# Use lightweight unregister (cleans up batcher buffers properly)
			boot_manager.unregister_biome(biome, batcher)

		# Remove nodes for this biome from force graph (incremental)
		if force_graph:
			force_graph.remove_nodes_for_biome(actual_biome_name)

		# Clean up tracking
		slot_to_actual_biome.erase(slot_biome_name)
		biomes.erase(slot_biome_name)

		print("Slot %s: Evolution DISABLED (%s)" % [slot_biome_name.substr(0, 1), actual_biome_name])


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


func _print_cpp_profiling_report():
	"""Print detailed frame budget breakdown and batching status."""
	if not batcher or not batcher.has_method("get_performance_metrics"):
		return

	var metrics = batcher.get_performance_metrics()
	var vfps = Engine.get_frames_per_second()
	var frame_time_ms = 1000.0 / vfps if vfps > 0 else 16.67

	print("\n" + "─".repeat(70))
	print("📊 FRAME BUDGET BREAKDOWN - Frame %d" % frame)
	print("─".repeat(70))

	# Visual FPS and frame time
	var physics_fps = metrics.get("physics_fps", 10.0)
	var avg_frame_ms = metrics.get("avg_frame_time_ms", 16.67)

	print("\n🎯 TARGET: 16.67ms (60 FPS)  |  ACTUAL: %.2fms (%.1f FPS)" % [frame_time_ms, vfps])

	# Frame budget breakdown
	var batch_time = metrics.get("avg_batch_time_ms", 0.0)
	var last_batch_time = metrics.get("last_batch_time_ms", 0.0)
	var batches_pending = metrics.get("batches_pending", 0)

	# Estimate how often batches run (when queue is not empty)
	# Approximate elapsed time: frame count / assumed 60 FPS
	var elapsed_seconds = max(1.0, frame / 60.0)
	var batches_per_second = metrics.get("refill_count", 0) / elapsed_seconds
	var batches_per_visual_frame = batches_per_second / max(1.0, vfps)

	print("\n⏱️  WHERE TIME GOES (per visual frame):")
	print("  ┌─────────────────────────────────────────────────────────┐")
	if batches_pending > 0:
		print("  │ ⚠️  BATCH BLOCKING: ~%.2fms  (SYNCHRONOUS!)           │" % last_batch_time)
	else:
		print("  │ C++ Evolution:     ~%.2fms  (avg, amortized)           │" % [batch_time * batches_per_visual_frame])

	# Estimate rendering time (varies by scene complexity)
	var estimated_render_ms = frame_time_ms * 0.5  # Rough estimate: 50% of frame time
	print("  │ Rendering:         ~%.2fms  (estimated)                │" % estimated_render_ms)
	print("  │ Force calc (GPU):  ~1-2ms   (parallel, estimated)     │")

	# GDScript overhead (remainder after accounting for known components)
	var accounted_time = (batch_time * batches_per_visual_frame) + estimated_render_ms + 2.0
	var overhead_ms = max(0.0, frame_time_ms - accounted_time)
	print("  │ GDScript overhead: ~%.2fms  (remainder)                │" % overhead_ms)
	print("  └─────────────────────────────────────────────────────────┘")
	print("  Note: With async batches, visual frames should no longer block!")

	# Batching status (Adaptive Fibonacci mode)
	var batch_size = metrics.get("batch_size", 5)
	var batches_per_refill = metrics.get("batches_per_refill", 1)
	var buffer_state = metrics.get("buffer_state", "UNKNOWN")
	var fib_index = metrics.get("fib_index", 4)
	var pending = metrics.get("batches_pending", 0)
	var in_flight = metrics.get("batches_in_flight", 0)

	print("\n📦 BATCHING (Adaptive Fibonacci):")
	if batches_per_refill == 1:
		# Adaptive mode: 1 batch of variable size
		print("  Mode:     %s (fib_index=%d)" % [buffer_state, fib_index])
		print("  Batch:    %d steps/refill (Fib[%d])" % [batch_size, fib_index])
	else:
		# Legacy mode: multiple fixed-size batches
		print("  Config:   %d steps/batch × %d batches = %d steps/refill" % [
			batch_size, batches_per_refill, batch_size * batches_per_refill
		])
	print("  Queue:    %d pending, %d in-flight" % [pending, in_flight])
	print("  Timing:   %.2fms last | %.2fms avg" % [
		metrics.get("last_batch_time_ms", 0.0),
		batch_time
	])

	# Buffer state
	var depth = metrics.get("buffer_depth", 0)
	var coverage_ms = metrics.get("buffer_coverage_ms", 0.0)
	var threshold_ms = metrics.get("refill_threshold_ms", 2000.0)
	var coast_target = metrics.get("coast_target", 10)

	var bar_width = 30
	var max_coverage_ms = 2400.0  # 24 steps × 100ms = 2.4s max buffer
	var fill = int(clampf(coverage_ms / max_coverage_ms, 0.0, 1.0) * bar_width)
	var threshold_pos = int(clampf(threshold_ms / max_coverage_ms, 0.0, 1.0) * bar_width)
	var bar = ""
	for i in range(bar_width):
		if i == threshold_pos:
			bar += "|"
		elif i < fill:
			bar += "█"
		else:
			bar += "░"

	print("\n🔋 BUFFER: %d steps (%.0fms)" % [depth, coverage_ms])
	print("  [%s] %.0fms threshold" % [bar, threshold_ms])

	if coverage_ms < threshold_ms:
		print("  ⚠️  LOW - refill triggered")
	elif coverage_ms < threshold_ms * 1.5:
		print("  🟡 OK - will refill soon")
	else:
		print("  ✅ HEALTHY")

	# Per-biome breakdown (parallel processing visibility)
	if batcher.has_method("get_all_biome_diagnostics"):
		var biome_diag = batcher.get_all_biome_diagnostics()
		if biome_diag.size() > 1:  # Only show if multiple biomes
			print("\n🌍 PER-BIOME STATUS (Parallel Evolution):")
			for biome_name in biome_diag.keys():
				var diag = biome_diag[biome_name]
				var status_icons = []
				if diag.get("paused", false):
					status_icons.append("💤")
				if diag.get("in_flight", false):
					status_icons.append("⚡")
				if diag.get("pending", false):
					status_icons.append("📦")

				var status_str = " ".join(status_icons) if status_icons.size() > 0 else "🟢"
				var name_display = biome_name.substr(0, 18).rpad(18, " ")
				print("  %s: buf=%d %s" % [
					name_display,
					diag.get("depth", 0),
					status_str
				])

	# Stats
	print("\n📈 STATS: %d refills | PFPS: %.1f Hz" % [
		metrics.get("refill_count", 0),
		physics_fps
	])
	print("─".repeat(70))
