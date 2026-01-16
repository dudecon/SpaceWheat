extends SceneTree

## Frame Time Benchmark - Measures per-component computation time
## Run with: godot --headless --script res://Tests/benchmark_frame_time.gd

const WARMUP_FRAMES := 5
const BENCHMARK_FRAMES := 20

var farm = null
var boot_manager = null
var scene_loaded = false
var benchmark_done = false
var frame_count = 0

# Timing accumulators (in microseconds)
var biome_times := []
var farm_times := []
var grid_times := []
var force_graph_times := []
var total_frame_times := []

func _init():
	print("\n══════════════════════════════════════════════════════════════════")
	print("  FRAME TIME BENCHMARK")
	print("══════════════════════════════════════════════════════════════════\n")

func _process(_delta):
	frame_count += 1

	# Load scene at frame 3
	if frame_count == 3 and not scene_loaded:
		print("Loading main scene...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			var instance = scene.instantiate()
			root.add_child(instance)
			scene_loaded = true

			boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)
				print("✓ Waiting for BootManager.game_ready...\n")

func _on_game_ready():
	if benchmark_done:
		return
	benchmark_done = true

	_find_farm()
	if not farm:
		print("❌ Farm not found!")
		quit(1)
		return

	print("✓ Farm found. Starting benchmark...\n")

	# Run warmup frames
	print("Warming up (%d frames)..." % WARMUP_FRAMES)
	for i in range(WARMUP_FRAMES):
		_run_single_frame(0.016, false)

	# Run benchmark frames
	print("Benchmarking (%d frames)...\n" % BENCHMARK_FRAMES)
	for i in range(BENCHMARK_FRAMES):
		_run_single_frame(0.016, true)

	_print_results()
	quit(0)

func _find_farm():
	var farm_view = root.get_node_or_null("FarmView")
	if farm_view:
		farm = farm_view.farm if "farm" in farm_view else null
		if not farm:
			for child in farm_view.get_children():
				if child.name == "Farm":
					farm = child
					break

func _run_single_frame(dt: float, record: bool):
	var frame_start = Time.get_ticks_usec()

	# 1. Biome evolution (all 4 biomes)
	var biome_start = Time.get_ticks_usec()
	for biome in [farm.biotic_flux_biome, farm.forest_biome, farm.market_biome, farm.kitchen_biome]:
		if biome:
			biome.advance_simulation(dt)
	var biome_time = Time.get_ticks_usec() - biome_start

	# 2. Farm process (grid + composting)
	var farm_start = Time.get_ticks_usec()
	if farm.grid:
		farm.grid._process(dt)
	farm._process_mushroom_composting(dt)
	var farm_time = Time.get_ticks_usec() - farm_start

	# 3. Grid processing standalone
	var grid_start = Time.get_ticks_usec()
	if farm.grid:
		# Grid was already processed above, but this measures overhead
		pass
	var grid_time = Time.get_ticks_usec() - grid_start

	var frame_time = Time.get_ticks_usec() - frame_start

	if record:
		biome_times.append(biome_time)
		farm_times.append(farm_time)
		grid_times.append(grid_time)
		total_frame_times.append(frame_time)

func _print_results():
	print("══════════════════════════════════════════════════════════════════")
	print("  RESULTS (microseconds per frame)")
	print("══════════════════════════════════════════════════════════════════\n")

	# Calculate stats
	var biome_avg = _avg(biome_times)
	var biome_max = _max(biome_times)
	var farm_avg = _avg(farm_times)
	var total_avg = _avg(total_frame_times)
	var total_max = _max(total_frame_times)

	print("Component         | Avg (us) | Max (us) | ms/frame")
	print("------------------|----------|----------|----------")
	print("Biome Evolution   | %8.0f | %8.0f | %.1f ms" % [biome_avg, biome_max, biome_avg / 1000.0])
	print("Farm Process      | %8.0f | %8.0f | %.1f ms" % [farm_avg, _max(farm_times), farm_avg / 1000.0])
	print("------------------|----------|----------|----------")
	print("TOTAL FRAME       | %8.0f | %8.0f | %.1f ms" % [total_avg, total_max, total_avg / 1000.0])
	print("")

	# FPS estimate
	var target_frame_ms = 16.67  # 60 FPS
	var actual_frame_ms = total_avg / 1000.0
	var estimated_fps = 1000.0 / actual_frame_ms if actual_frame_ms > 0 else 999

	print("Target: 60 FPS = 16.67 ms/frame")
	print("Actual: %.1f FPS = %.2f ms/frame" % [estimated_fps, actual_frame_ms])
	print("")

	if actual_frame_ms > target_frame_ms:
		print("⚠️  OVER BUDGET by %.1f ms (%.0f%%)" % [
			actual_frame_ms - target_frame_ms,
			(actual_frame_ms / target_frame_ms - 1) * 100
		])
	else:
		print("✅ Under budget by %.1f ms" % [target_frame_ms - actual_frame_ms])

	# Breakdown by biome (run individual biome benchmarks)
	print("\n")
	print("══════════════════════════════════════════════════════════════════")
	print("  BIOME BREAKDOWN")
	print("══════════════════════════════════════════════════════════════════\n")

	_benchmark_individual_biomes()

func _benchmark_individual_biomes():
	var biomes = {
		"BioticFlux": farm.biotic_flux_biome,
		"Forest": farm.forest_biome,
		"Market": farm.market_biome,
		"Kitchen": farm.kitchen_biome
	}

	print("Biome             | Avg (us) | Max (us) | ms/frame | Matrix Size")
	print("------------------|----------|----------|----------|------------")

	for name in biomes:
		var biome = biomes[name]
		if not biome:
			print("%s            | N/A      | N/A      | N/A      | N/A" % name)
			continue

		# Get matrix size
		var matrix_size = "?"
		if biome.quantum_computer and biome.quantum_computer.density_matrix:
			matrix_size = str(biome.quantum_computer.density_matrix.n)

		# Run 10 iterations
		var times = []
		for i in range(10):
			var start = Time.get_ticks_usec()
			biome.advance_simulation(0.016)
			times.append(Time.get_ticks_usec() - start)

		var avg = _avg(times)
		var max_t = _max(times)
		print("%-17s | %8.0f | %8.0f | %8.1f | %s" % [name, avg, max_t, avg / 1000.0, matrix_size])

	print("")

func _avg(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var sum = 0.0
	for v in arr:
		sum += v
	return sum / arr.size()

func _max(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var m = arr[0]
	for v in arr:
		if v > m:
			m = v
	return m
