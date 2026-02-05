extends Node
class_name PerformanceStressTest

## Performance Stress Test - Integrated into FarmView
## Runs after game boot: measures FPS empty → creates 4 biomes → explores all plots → measures FPS full

const WARMUP_FRAMES = 6
const MEASURE_FRAMES = 30

# Preload concrete biome classes for dynamic creation (excluding broken StarterForest)
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const VillageBiome = preload("res://Core/Environment/VillageBiome.gd")
const StellarForgesBiome = preload("res://Core/Environment/StellarForgesBiome.gd")
const VolcanicWorldsBiome = preload("res://Core/Environment/VolcanicWorldsBiome.gd")

var phase = "warmup"
var frame = 0
var empty_times = []
var full_times = []

var farm = null
var quantum_viz = null
var test_biomes = []  # 4 dynamically created biomes

signal stress_test_complete(results: Dictionary)

func _ready():
	print("\n" + "=".repeat(80))
	print("PERFORMANCE STRESS TEST - Integrated with Game")
	print("=".repeat(80))

	# Enable perf_hud logging for stress test
	VerboseConfig.set_category_enabled("perf_hud", true)
	VerboseConfig.set_category_level("perf_hud", VerboseConfig.LogLevel.DEBUG)

	# Wait for FarmView to fully initialize (quantum_viz is created after farm)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_find_game_refs()

	# After farm is ready, create 4 test biomes
	if quantum_viz:
		await get_tree().process_frame
		_create_test_biomes()
	else:
		print("ERROR: Cannot run stress test - quantum visualization not available")
		get_tree().quit()

func _find_game_refs():
	"""Find farm and quantum_viz from FarmView parent"""
	var farm_view = get_parent()
	if farm_view and "farm" in farm_view and "quantum_viz" in farm_view:
		farm = farm_view.farm
		# quantum_viz is now QuantumForceGraph directly (no controller middleman)
		quantum_viz = farm_view.quantum_viz
		if quantum_viz:
			print("✅ Found farm and quantum visualization (QuantumForceGraph)")
		else:
			print("⚠️ Found farm but quantum_viz is missing")
		return

	print("ERROR: Could not find farm and visualization from FarmView")

func _process(delta):
	frame += 1

	match phase:
		"warmup":
			if frame % 30 == 0:
				print("[WARMUP] %d/%d frames..." % [frame, WARMUP_FRAMES])
			if frame >= WARMUP_FRAMES:
				phase = "measure_empty"
				frame = 0
				empty_times.clear()
				print("\n[PHASE 1] Measuring EMPTY grid (%d frames)..." % MEASURE_FRAMES)

		"measure_empty":
			empty_times.append(Engine.get_frames_per_second())
			if frame >= MEASURE_FRAMES:
				var empty_fps = _avg(empty_times)
				var empty_ms = _avg(empty_times.map(func(fps): return 1000.0 / fps))
				print("  ✓ Empty Grid: %.1f FPS (%.2fms per frame)" % [empty_fps, empty_ms])

				phase = "explore"
				frame = 0
				print("\n[PHASE 2] Running EXPLORE on 24 plots...")
				_run_explore_all()
				print("  ✓ Explored plots, waiting for quantum state to settle...")

		"explore":
			if frame > 15:  # Let quantum system settle
				phase = "measure_full"
				frame = 0
				full_times.clear()
				print("[PHASE 3] Measuring FULL grid (%d frames)..." % MEASURE_FRAMES)

		"measure_full":
			full_times.append(Engine.get_frames_per_second())
			if frame >= MEASURE_FRAMES:
				_finish_test()

func _create_test_biomes():
	"""Create 4 random biomes and register them with farm's grid and visualization"""
	if not farm or not farm.grid:
		print("  ERROR: Cannot access farm grid")
		return

	print("\n[SETUP] Creating 4 test biomes...")
	print("  DEBUG: quantum_viz = %s" % quantum_viz)
	print("  DEBUG: quantum_viz type = %s" % (quantum_viz.get_class() if quantum_viz else "null"))

	# Create 4 biome instances (using Village, BioticFlux, StellarForges, VolcanicWorlds)
	var biome_classes = [VillageBiome, BioticFluxBiome, StellarForgesBiome, VolcanicWorldsBiome]

	for i in range(min(4, biome_classes.size())):
		var biome_class = biome_classes[i]
		var biome = biome_class.new()
		biome.name = "TestBiome_%d" % i
		farm.add_child(biome)  # This automatically calls _ready()

		# Wait one frame for _ready() to complete
		# NOTE: _ready() calls _initialize_bath() which builds operators via BiomeBuilder
		await get_tree().process_frame

		# Don't rebuild operators - biome already has them from _initialize_bath()
		# Calling build_operators_cached() again would overwrite the good faction-based operators

		# Enable quantum evolution for this biome
		if biome.has_method("set_process"):
			biome.set_process(true)
		biome.quantum_evolution_enabled = true

		# Register with farm's grid
		if farm.grid and farm.grid.has_method("register_biome"):
			farm.grid.register_biome(biome.get_biome_type(), biome)

		# Also inject grid reference into biome
		if farm.grid:
			biome.grid = farm.grid

		# Register with quantum visualization (creates bubbles from registers)
		if quantum_viz and quantum_viz.has_method("register_biome"):
			quantum_viz.register_biome(biome.get_biome_type(), biome)

		# CRITICAL: Register with BiomeEvolutionBatcher for quantum evolution
		if farm.biome_evolution_batcher and farm.biome_evolution_batcher.has_method("register_biome"):
			farm.biome_evolution_batcher.register_biome(biome)
			print("  DEBUG: Registered biome with evolution batcher")

		test_biomes.append(biome)

		# Debug: Check viz_cache status
		var has_viz = biome.viz_cache and biome.viz_cache.has_metadata()
		var num_qubits = biome.viz_cache.get_num_qubits() if has_viz else 0
		print("  ✓ Created biome %d: %s (%d qubits, viz_cache: %s)" % [i, biome.get_biome_type(), num_qubits, "OK" if has_viz else "MISSING"])

	print("  ✓ Biome setup complete (%d total qubits across 4 biomes)" % _count_total_registers())

	# Wait for biomes to evolve and populate viz_cache with quantum state
	print("  ⏳ Waiting for quantum evolution to populate viz_cache...")
	for i in range(5):  # Wait ~5 frames for initial evolution
		await get_tree().process_frame
	print("  ✓ Evolution wait complete")

	# WORKAROUND: Stage 1 batcher doesn't populate viz_cache, so manually populate from quantum state
	print("  ⏳ Manually populating viz_cache from quantum computers...")
	for biome in test_biomes:
		_populate_viz_cache_from_qc(biome)
	print("  ✓ viz_cache populated for all test biomes")

	# DIAGNOSTIC: Check visual information packet contents
	print("\n" + "=".repeat(80))
	print("DIAGNOSTIC: Visual Information Packet Contents")
	print("=".repeat(80))
	_diagnose_viz_packets()
	print("=".repeat(80) + "\n")

	# Force one final rebuild to ensure all bubbles are visible
	print("  DEBUG: About to rebuild visualization nodes...")
	print("  DEBUG: quantum_viz exists = %s" % (quantum_viz != null))
	print("  DEBUG: has rebuild_nodes = %s" % (quantum_viz.has_method("rebuild_nodes") if quantum_viz else false))

	if quantum_viz and quantum_viz.has_method("rebuild_nodes"):
		print("  DEBUG: Calling rebuild_nodes()...")
		quantum_viz.rebuild_nodes()
		print("  ✓ Visualization updated with all quantum bubbles")

		# DEBUG: Force a manual check of nodes
		if quantum_viz.has_method("get_stats"):
			var stats = quantum_viz.get_stats()
			print("  DEBUG: Active nodes: %d, Total nodes: %d" % [stats.get("active_nodes", 0), stats.get("total_nodes", 0)])
	else:
		print("  ERROR: Cannot rebuild visualization (quantum_viz missing or no rebuild_nodes method)")


func _count_total_registers() -> int:
	"""Count total available quantum registers across all test biomes"""
	var total = 0
	for biome in test_biomes:
		if biome and biome.quantum_computer and biome.quantum_computer.register_map:
			total += biome.quantum_computer.register_map.num_qubits
	return total


func _populate_viz_cache_from_qc(biome):
	"""Populate viz_cache from quantum computer using standard export interface."""
	if not biome or not biome.quantum_computer or not biome.viz_cache:
		return

	var qc = biome.quantum_computer

	# Use QC's standard export (single source of truth)
	var bloch_packet = qc.export_bloch_packet()
	biome.viz_cache.update_from_bloch_packet(bloch_packet, qc.register_map.num_qubits)
	biome.viz_cache.update_purity(qc.get_purity())


func _diagnose_viz_packets():
	"""Diagnostic: Check visual information packets from quantum computer to viz_cache."""
	for biome in test_biomes:
		var biome_name = biome.get_biome_type()
		print("\n[%s]" % biome_name)

		# Check 1: Register map metadata
		if not biome.viz_cache.has_metadata():
			print("  ❌ viz_cache has NO METADATA (register map not loaded)")
			continue

		var num_qubits = biome.viz_cache.get_num_qubits()
		print("  ✓ Metadata: %d qubits registered" % num_qubits)

		# Check 2: Axes (emoji pairs per qubit)
		var sample_qubit = 0
		var axis = biome.viz_cache.get_axis(sample_qubit)
		if axis.is_empty():
			print("  ❌ Axis for qubit 0: EMPTY (no emoji mapping)")
		else:
			print("  ✓ Axis for qubit 0: %s ↔ %s" % [axis.get("north", "?"), axis.get("south", "?")])

		# Check 3: Bloch vector data (the core quantum state)
		var bloch = biome.viz_cache.get_bloch(sample_qubit)
		if bloch.is_empty():
			print("  ❌ Bloch vector for qubit 0: EMPTY (NO QUANTUM DATA)")
			print("     → This is the ROOT PROBLEM - viz_cache._bloch_cache is unpopulated")
			print("     → BiomeEvolutionBatcher.update_from_bloch_packet() not being called?")
		else:
			print("  ✓ Bloch vector for qubit 0:")
			print("     p0=%.4f, p1=%.4f (probabilities)" % [bloch.get("p0", 0), bloch.get("p1", 0)])
			print("     x=%.4f, y=%.4f, z=%.4f (Bloch coords)" % [bloch.get("x", 0), bloch.get("y", 0), bloch.get("z", 0)])
			print("     r=%.4f, theta=%.4f, phi=%.4f (spherical)" % [bloch.get("r", 0), bloch.get("theta", 0), bloch.get("phi", 0)])

		# Check 4: Snapshot (what QuantumNode actually reads)
		var snapshot = biome.viz_cache.get_snapshot(sample_qubit)
		if snapshot.is_empty():
			print("  ❌ Snapshot for qubit 0: EMPTY (get_snapshot() returns {})")
			print("     → QuantumNode will see NO DATA and mark bubble as LIFELESS")
		else:
			print("  ✓ Snapshot for qubit 0:")
			print("     p0=%.4f, p1=%.4f" % [snapshot.get("p0", 0), snapshot.get("p1", 0)])
			print("     r_xy=%.4f (radial amplitude)" % snapshot.get("r_xy", 0))
			print("     phi=%.4f (phase angle)" % snapshot.get("phi", 0))
			print("     purity=%.4f" % snapshot.get("purity", -1))

		# Check 5: Purity (global system state)
		var purity = biome.viz_cache.get_purity()
		if purity < 0:
			print("  ⚠️  System purity: NOT SET (%.1f)" % purity)
		else:
			print("  ✓ System purity: %.4f" % purity)


func _run_explore_all():
	"""Run EXPLORE action on all plots, cycling through 4 test biomes"""
	if not farm or not farm.terminal_pool:
		print("  ERROR: Cannot access plot pool")
		return

	if test_biomes.is_empty():
		print("  ERROR: No test biomes available")
		return

	var ProbeActions = load("res://Core/Actions/ProbeActions.gd")
	var economy = farm.economy if farm.economy else null

	var success_count = 0
	var error_types = {}

	for i in range(24):
		# Cycle through the 4 test biomes
		var biome = test_biomes[i % test_biomes.size()]
		var result = ProbeActions.action_explore(farm.terminal_pool, biome, economy)
		if result.success:
			success_count += 1
		else:
			var error = result.get("error", "unknown")
			error_types[error] = error_types.get(error, 0) + 1

	print("  Results: %d/24 successful" % success_count)
	if not error_types.is_empty():
		print("  Errors:")
		for error_type in error_types:
			print("    - %s: %d" % [error_type, error_types[error_type]])

func _finish_test():
	"""Analyze results and print report"""
	var empty_fps = _avg(empty_times)
	var full_fps = _avg(full_times)
	var empty_ms = _avg(empty_times.map(func(fps): return 1000.0 / fps if fps > 0 else 0))
	var full_ms = _avg(full_times.map(func(fps): return 1000.0 / fps if fps > 0 else 0))

	var fps_delta = full_fps - empty_fps
	var ms_delta = full_ms - empty_ms
	var pct_delta = (fps_delta / empty_fps * 100.0) if empty_fps > 0 else 0

	print("\n" + "=".repeat(80))
	print("STRESS TEST RESULTS")
	print("=".repeat(80))

	print("\n📊 Empty Grid Baseline (0 bubbles):")
	print("   FPS: %.1f" % empty_fps)
	print("   Frame Time: %.2fms" % empty_ms)

	print("\n📊 Full Grid (24 explored plots with bubbles):")
	print("   FPS: %.1f" % full_fps)
	print("   Frame Time: %.2fms" % full_ms)

	print("\n📊 Performance Impact:")
	print("   FPS Delta: %+.1f (%+.1f%%)" % [fps_delta, pct_delta])
	print("   Frame Time Delta: %+.2fms" % ms_delta)

	var verdict = "✓ EXCELLENT"
	if abs(pct_delta) > 15:
		verdict = "🔴 POOR"
	elif abs(pct_delta) > 5:
		verdict = "⚠️ MODERATE"

	print("\n" + "=".repeat(80))
	print("VERDICT: %s" % verdict)
	print("Impact: %.1f%% FPS decrease" % abs(pct_delta))
	print("=".repeat(80) + "\n")

	# Emit signal with results
	var results = {
		"empty_fps": empty_fps,
		"full_fps": full_fps,
		"empty_ms": empty_ms,
		"full_ms": full_ms,
		"fps_delta": fps_delta,
		"pct_delta": pct_delta,
		"verdict": verdict
	}
	stress_test_complete.emit(results)

	# Quit for automated testing
	get_tree().quit()

func _avg(arr: Array) -> float:
	if arr.is_empty():
		return 0
	var sum = 0.0
	for v in arr:
		sum += v
	return sum / float(arr.size())
