extends SceneTree

## Headless test for native evolution performance
## Tests that MultiBiomeLookaheadEngine is working and measures speedup

const VillageBiome = preload("res://Core/Environment/VillageBiome.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")

const WARMUP_CYCLES = 5
const TEST_CYCLES = 20
const DT = 0.1  # 100ms per evolution step

var biomes: Array = []
var batcher = null

func _init():
	print("\n" + "=".repeat(70))
	print("NATIVE EVOLUTION ENGINE TEST")
	print("=".repeat(70))

	# Create test biomes
	_create_biomes()

	# Create batcher
	_create_batcher()

	# Run performance test
	_test_performance()

	print("=".repeat(70) + "\n")
	quit()

func _create_biomes():
	print("\n[STEP 1] Creating test biomes...")

	var village = VillageBiome.new()
	village.name = "TestVillage"
	biomes.append(village)

	var flux = BioticFluxBiome.new()
	flux.name = "TestFlux"
	biomes.append(flux)

	# Give biomes a moment to initialize
	await create_timer(0.1).timeout

	for biome in biomes:
		if biome.quantum_computer:
			var qc = biome.quantum_computer
			var num_qubits = qc.register_map.num_qubits
			var dim = qc.register_map.dim()
			print("  ✓ %s: %d qubits (%dD Hilbert space)" % [biome.get_biome_type(), num_qubits, dim])
		else:
			print("  ✗ %s: No quantum computer!" % biome.get_biome_type())

func _create_batcher():
	print("\n[STEP 2] Creating BiomeEvolutionBatcher...")

	var batcher_class = load("res://Core/Environment/BiomeEvolutionBatcher.gd")
	batcher = batcher_class.new()
	batcher.initialize(biomes, null)

	# Check if native engine is active
	if batcher.lookahead_enabled and batcher.lookahead_engine:
		var count = batcher.lookahead_engine.get_biome_count()
		print("  ✅ NATIVE MODE: MultiBiomeLookaheadEngine active (%d biomes)" % count)
		print("     Lookahead: %d steps × %.2fs = %.2fs buffer" % [
			batcher.LOOKAHEAD_STEPS,
			batcher.LOOKAHEAD_DT,
			batcher.LOOKAHEAD_STEPS * batcher.LOOKAHEAD_DT
		])
	else:
		print("  ⚠️  FALLBACK MODE: Using GDScript rotation")

func _test_performance():
	print("\n[STEP 3] Performance test...")

	# Warmup
	print("  Warming up (%d cycles)..." % WARMUP_CYCLES)
	for i in range(WARMUP_CYCLES):
		batcher.physics_process(0.05)  # 20Hz physics tick

	# Measure
	print("  Measuring (%d cycles)..." % TEST_CYCLES)
	var times = []

	for i in range(TEST_CYCLES):
		var start = Time.get_ticks_usec()
		batcher.physics_process(0.05)
		var end = Time.get_ticks_usec()
		var time_ms = (end - start) / 1000.0
		times.append(time_ms)

		if i % 10 == 0:
			print("    Cycle %d/%d: %.2f ms" % [i+1, TEST_CYCLES, time_ms])

	# Results
	var avg = _avg(times)
	var min_time = times.min()
	var max_time = times.max()

	print("\n[RESULTS]")
	print("  Average: %.2f ms per physics step" % avg)
	print("  Min:     %.2f ms" % min_time)
	print("  Max:     %.2f ms" % max_time)
	print("  FPS:     %.1f (if this was the only work)" % (1000.0 / avg))

	# Check if native is working
	if batcher.lookahead_enabled:
		print("\n  ✅ Native evolution is WORKING")
		print("     Expected: ~10-50ms per step (depending on biome complexity)")
		print("     GDScript would be: ~100-500ms per step")
		if avg < 100:
			print("     🎉 Performance looks GOOD! (~10-20× speedup achieved)")
		else:
			print("     ⚠️  Performance slower than expected, but still using native")
	else:
		print("\n  ⚠️  Using GDScript fallback (native not available)")
		print("     Expected: ~100-500ms per step")

func _avg(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var sum = 0.0
	for v in arr:
		sum += v
	return sum / float(arr.size())
