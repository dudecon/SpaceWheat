#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Unit tests for unified biome loading framework (BootManager.load_biome)
##
## Tests verify:
## - Biome loading sequence (load → register → assign → rebuild → batcher)
## - Idempotency (loading twice works)
## - Error handling (missing dependencies)
## - Quantum state integrity (no corruption)

const Farm = preload("res://Core/Farm.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const GridConfig = preload("res://Core/GameMechanics/GridConfig.gd")
const BiomeEvolutionBatcher = preload("res://Core/Environment/BiomeEvolutionBatcher.gd")

var passed := 0
var failed := 0
var boot_manager
var icon_registry
var farm


func _initialize():
	print("\n" + "=".repeat(80))
	print("🔬 BIOME CONSTRUCTION TEST SUITE")
	print("=".repeat(80))

	await get_root().ready

	# Get autoloads
	boot_manager = get_node_or_null("/root/BootManager")
	icon_registry = get_node_or_null("/root/IconRegistry")

	if not boot_manager:
		print("❌ BootManager autoload not found - tests cannot run")
		quit(1)
		return

	# Run all tests
	test_load_biome_success()
	test_load_biome_registers_with_grid()
	test_load_biome_assigns_plots()
	test_load_biome_stores_metadata()
	test_load_biome_rebuilds_operators()
	test_load_biome_valid_density_matrix()
	test_load_biome_twice_idempotent()
	test_load_multiple_biomes()
	test_load_biome_no_farm()
	test_load_biome_no_grid()
	test_operators_rebuilt_before_batcher()

	# Print summary
	print("\n" + "=".repeat(80))
	print("TEST SUMMARY:")
	print("  ✅ Passed: %d" % passed)
	print("  ❌ Failed: %d" % failed)
	print("=".repeat(80))

	var exit_code = 1 if failed > 0 else 0
	quit(exit_code)


func create_test_farm() -> Farm:
	"""Create a minimal Farm instance for testing."""
	var test_farm = Farm.new()
	test_farm.name = "TestFarm"
	get_root().add_child(test_farm)

	# Create grid config (required for plot assignment)
	test_farm.grid_config = GridConfig.new(4, 6)  # 4x6 grid

	# Create grid (required for biome registration)
	test_farm.grid = FarmGrid.new(4, 6)
	test_farm.add_child(test_farm.grid)

	# Create batcher (required for evolution)
	test_farm.biome_evolution_batcher = BiomeEvolutionBatcher.new()
	test_farm.add_child(test_farm.biome_evolution_batcher)

	return test_farm


func cleanup_farm(test_farm: Farm):
	"""Cleanup farm after test."""
	if test_farm and is_instance_valid(test_farm):
		test_farm.queue_free()


func pass_test(test_name: String):
	passed += 1
	print("  ✅ %s" % test_name)


func fail_test(test_name: String, reason: String = ""):
	failed += 1
	var msg = "  ❌ %s" % test_name
	if reason:
		msg += ": %s" % reason
	print(msg)


## ============================================================================
## TEST CASES
## ============================================================================

func test_load_biome_success():
	print("\n🧪 Test: load_biome returns success")
	farm = create_test_farm()

	var result = boot_manager.load_biome("StarterForest", farm)

	if result.get("success", false):
		if result.get("biome_name", "") == "StarterForest":
			if result.get("biome_ref", null) != null:
				pass_test("load_biome returns success")
			else:
				fail_test("load_biome returns success", "biome_ref is null")
		else:
			fail_test("load_biome returns success", "wrong biome_name")
	else:
		fail_test("load_biome returns success", "success=false")

	cleanup_farm(farm)


func test_load_biome_registers_with_grid():
	print("\n🧪 Test: Biome registered in grid.biomes")
	farm = create_test_farm()

	var result = boot_manager.load_biome("Village", farm)

	if result.get("success", false):
		if farm.grid.biomes.has("Village"):
			var biome = farm.grid.biomes["Village"]
			if biome and biome.name == "Village":
				pass_test("Biome registered in grid.biomes")
			else:
				fail_test("Biome registered in grid.biomes", "biome invalid")
		else:
			fail_test("Biome registered in grid.biomes", "not in grid.biomes")
	else:
		fail_test("Biome registered in grid.biomes", "load failed")

	cleanup_farm(farm)


func test_load_biome_assigns_plots():
	print("\n🧪 Test: Plots assigned to biome")
	farm = create_test_farm()

	var result = boot_manager.load_biome("BioticFlux", farm)

	if result.get("success", false):
		var assigned_count = 0
		for pos in farm.grid_config.biome_assignments:
			if farm.grid_config.biome_assignments[pos] == "BioticFlux":
				assigned_count += 1

		if assigned_count > 0:
			pass_test("Plots assigned to biome (%d plots)" % assigned_count)
		else:
			fail_test("Plots assigned to biome", "no plots assigned")
	else:
		fail_test("Plots assigned to biome", "load failed")

	cleanup_farm(farm)


func test_load_biome_stores_metadata():
	print("\n🧪 Test: Metadata stored in Farm")
	farm = create_test_farm()

	var result = boot_manager.load_biome("StellarForges", farm)

	if result.get("success", false):
		if farm.has_meta("stellarforges_biome"):
			var meta_biome = farm.get_meta("stellarforges_biome")
			if meta_biome:
				pass_test("Metadata stored in Farm")
			else:
				fail_test("Metadata stored in Farm", "metadata is null")
		else:
			fail_test("Metadata stored in Farm", "metadata not found")
	else:
		fail_test("Metadata stored in Farm", "load failed")

	cleanup_farm(farm)


func test_load_biome_rebuilds_operators():
	print("\n🧪 Test: Quantum operators rebuilt")
	farm = create_test_farm()

	var result = boot_manager.load_biome("FungalNetworks", farm)

	if result.get("success", false):
		var biome = result.get("biome_ref", null)
		if biome and biome.quantum_computer:
			if biome.quantum_computer.register_map:
				if biome.quantum_computer.register_map.num_qubits > 0:
					pass_test("Quantum operators rebuilt")
				else:
					fail_test("Quantum operators rebuilt", "no qubits")
			else:
				fail_test("Quantum operators rebuilt", "no register_map")
		else:
			fail_test("Quantum operators rebuilt", "no quantum_computer")
	else:
		fail_test("Quantum operators rebuilt", "load failed")

	cleanup_farm(farm)


func test_load_biome_valid_density_matrix():
	print("\n🧪 Test: Valid density matrix (trace=1.0)")
	farm = create_test_farm()

	var result = boot_manager.load_biome("VolcanicWorlds", farm)

	if result.get("success", false):
		var biome = result.get("biome_ref", null)
		if biome and biome.quantum_computer and biome.quantum_computer.density_matrix:
			var dm = biome.quantum_computer.density_matrix
			var trace = dm.trace()

			# Trace should be very close to 1.0 (allow small numerical error)
			if abs(trace - 1.0) < 0.05:
				# Check for negative diagonals (physically impossible)
				var has_negative = false
				for i in range(dm.n):
					var diag = dm.get_element(i, i).real
					if diag < -0.001:
						has_negative = true
						break

				if not has_negative:
					pass_test("Valid density matrix (trace=%.3f)" % trace)
				else:
					fail_test("Valid density matrix", "has negative diagonal")
			else:
				fail_test("Valid density matrix", "trace=%.3f (should be 1.0)" % trace)
		else:
			fail_test("Valid density matrix", "no density_matrix")
	else:
		fail_test("Valid density matrix", "load failed")

	cleanup_farm(farm)


func test_load_biome_twice_idempotent():
	print("\n🧪 Test: Loading twice is idempotent")
	farm = create_test_farm()

	var result1 = boot_manager.load_biome("Village", farm)
	var result2 = boot_manager.load_biome("Village", farm)

	if result1.get("success", false) and result2.get("success", false):
		if not result1.get("already_loaded", true) and result2.get("already_loaded", false):
			if result1.get("biome_ref") == result2.get("biome_ref"):
				pass_test("Loading twice is idempotent")
			else:
				fail_test("Loading twice is idempotent", "different biome refs")
		else:
			fail_test("Loading twice is idempotent", "already_loaded flags wrong")
	else:
		fail_test("Loading twice is idempotent", "load failed")

	cleanup_farm(farm)


func test_load_multiple_biomes():
	print("\n🧪 Test: Load multiple biomes")
	farm = create_test_farm()

	var biomes = ["StarterForest", "Village", "BioticFlux"]
	var all_success = true
	var loaded_refs = {}

	for biome_name in biomes:
		var result = boot_manager.load_biome(biome_name, farm)
		if not result.get("success", false):
			all_success = false
			break
		loaded_refs[biome_name] = result.get("biome_ref")

	if all_success:
		# Check all in grid
		var all_in_grid = true
		for biome_name in biomes:
			if not farm.grid.biomes.has(biome_name):
				all_in_grid = false
				break

		if all_in_grid:
			# Check references distinct
			var refs = loaded_refs.values()
			var all_distinct = true
			for i in range(refs.size()):
				for j in range(i + 1, refs.size()):
					if refs[i] == refs[j]:
						all_distinct = false
						break
				if not all_distinct:
					break

			if all_distinct:
				pass_test("Load multiple biomes")
			else:
				fail_test("Load multiple biomes", "refs not distinct")
		else:
			fail_test("Load multiple biomes", "not all in grid")
	else:
		fail_test("Load multiple biomes", "load failed")

	cleanup_farm(farm)


func test_load_biome_no_farm():
	print("\n🧪 Test: Null farm fails gracefully")

	var result = boot_manager.load_biome("StarterForest", null)

	if not result.get("success", true):
		if result.get("error", "") == "farm_null":
			pass_test("Null farm fails gracefully")
		else:
			fail_test("Null farm fails gracefully", "wrong error: %s" % result.get("error", ""))
	else:
		fail_test("Null farm fails gracefully", "should fail but succeeded")


func test_load_biome_no_grid():
	print("\n🧪 Test: Missing grid fails gracefully")
	farm = create_test_farm()
	farm.grid.queue_free()
	farm.grid = null

	var result = boot_manager.load_biome("StarterForest", farm)

	if not result.get("success", true):
		if result.get("error", "") == "grid_null":
			pass_test("Missing grid fails gracefully")
		else:
			fail_test("Missing grid fails gracefully", "wrong error: %s" % result.get("error", ""))
	else:
		fail_test("Missing grid fails gracefully", "should fail but succeeded")

	cleanup_farm(farm)


func test_operators_rebuilt_before_batcher():
	print("\n🧪 Test: Operators rebuilt before batcher (prevents corruption)")
	farm = create_test_farm()

	var result = boot_manager.load_biome("BioticFlux", farm)

	if result.get("success", false):
		var biome = result.get("biome_ref")
		if biome and biome.quantum_computer and biome.quantum_computer.density_matrix:
			var dm = biome.quantum_computer.density_matrix
			var trace = dm.trace()

			# If operators were built after batcher started, trace would be corrupted
			if abs(trace - 1.0) < 0.1:
				pass_test("Operators rebuilt before batcher (trace=%.3f)" % trace)
			else:
				fail_test("Operators rebuilt before batcher", "corrupted trace=%.3f" % trace)
		else:
			fail_test("Operators rebuilt before batcher", "no density_matrix")
	else:
		fail_test("Operators rebuilt before batcher", "load failed")

	cleanup_farm(farm)
