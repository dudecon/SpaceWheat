extends SceneTree

## Integration Tests for QuantumKitchen_Biome
##
## Tests kitchen biome initialization, evolution, and BiomeBase integration

const QuantumKitchen_Biome = preload("res://Core/Environment/QuantumKitchen_Biome.gd")


func _init():
	print("\n=== Kitchen Biome Integration Tests ===\n")

	var passed = 0
	var failed = 0

	# Test 1: Kitchen initialization
	print("Test 1: Kitchen biome initialization")
	var kitchen = QuantumKitchen_Biome.new()
	kitchen._ready()

	if kitchen.quantum_computer != null:
		print("  ✓ quantum_computer created")
	else:
		print("  ✗ quantum_computer is null")
		failed += 1
		quit()
		return

	if kitchen.quantum_computer.register_map.num_qubits == 3:
		print("  ✓ 3 qubits registered")
		passed += 1
	else:
		print("  ✗ Expected 3 qubits, got %d" % kitchen.quantum_computer.register_map.num_qubits)
		failed += 1

	# Test 2: Initial state verification
	print("\nTest 2: Initial state is |111⟩")
	var p_ground = kitchen.get_ground_probability()
	var p_bread = kitchen.get_bread_probability()

	if abs(p_ground - 1.0) < 0.01:
		print("  ✓ P(|111⟩) = %.3f (ground state)" % p_ground)
		passed += 1
	else:
		print("  ✗ P(|111⟩) = %.3f, expected ~1.0" % p_ground)
		failed += 1

	if abs(p_bread - 0.0) < 0.01:
		print("  ✓ P(|000⟩) = %.3f (no bread yet)" % p_bread)
		passed += 1
	else:
		print("  ✗ P(|000⟩) = %.3f, expected ~0.0" % p_bread)
		failed += 1

	# Test 3: RegisterMap emoji queries
	print("\nTest 3: RegisterMap emoji queries")
	var all_emojis_present = (
		kitchen.quantum_computer.has("🔥") and
		kitchen.quantum_computer.has("❄️") and
		kitchen.quantum_computer.has("💧") and
		kitchen.quantum_computer.has("🏜️") and
		kitchen.quantum_computer.has("💨") and
		kitchen.quantum_computer.has("🌾")
	)

	if all_emojis_present:
		print("  ✓ All 6 emojis registered")
		passed += 1
	else:
		print("  ✗ Some emojis missing")
		failed += 1

	# Test 4: Population queries
	print("\nTest 4: Population queries (ground state)")
	var p_cold = kitchen.get_temperature_cold()
	var p_dry = kitchen.get_moisture_dry()
	var p_grain = kitchen.get_substance_grain()

	if abs(p_cold - 1.0) < 0.01 and abs(p_dry - 1.0) < 0.01 and abs(p_grain - 1.0) < 0.01:
		print("  ✓ Ground state: P(❄️)=%.2f, P(🏜️)=%.2f, P(🌾)=%.2f" % [p_cold, p_dry, p_grain])
		passed += 1
	else:
		print("  ✗ Ground state populations incorrect")
		failed += 1

	# Test 5: Add fire drive
	print("\nTest 5: Add fire resource")
	kitchen.add_fire(1.0)  # 1.0 units → 2 seconds drive

	if kitchen.active_drives.size() == 1:
		print("  ✓ Fire drive activated")
		passed += 1
	else:
		print("  ✗ Expected 1 active drive, got %d" % kitchen.active_drives.size())
		failed += 1

	# Test 6: Evolution with fire drive
	print("\nTest 6: Evolution with fire drive (0.5s)")
	for i in range(5):
		kitchen._update_quantum_substrate(0.1)  # 5 × 0.1s = 0.5s

	var p_hot = kitchen.get_temperature_hot()
	if p_hot > 0.1:  # Should have some hot probability
		print("  ✓ P(🔥) = %.3f (increased from 0)" % p_hot)
		passed += 1
	else:
		print("  ✗ P(🔥) = %.3f, expected > 0.1" % p_hot)
		failed += 1

	# Test 7: Add multiple resources
	print("\nTest 7: Add water and flour drives")
	kitchen.add_water(1.0)
	kitchen.add_flour(1.0)

	if kitchen.active_drives.size() == 3:  # Fire (partial) + water + flour
		print("  ✓ Three drives active")
		passed += 1
	else:
		print("  ✗ Expected 3 active drives, got %d" % kitchen.active_drives.size())
		failed += 1

	# Test 8: Evolve toward bread state
	print("\nTest 8: Evolve toward bread state (5s)")
	for i in range(50):
		kitchen._update_quantum_substrate(0.1)  # 50 × 0.1s = 5s

	var p_bread_after = kitchen.get_bread_probability()
	print("  → P(🔥)=%.3f, P(💧)=%.3f, P(💨)=%.3f" % [
		kitchen.get_temperature_hot(),
		kitchen.get_moisture_wet(),
		kitchen.get_substance_flour()
	])
	print("  → P(🍞)=%.3f, detuning=%.3f, Ω_eff=%.3f" % [
		p_bread_after,
		kitchen._compute_detuning(),
		kitchen.get_effective_baking_rate()
	])

	if p_bread_after > 0.01:  # Should have some bread probability
		print("  ✓ P(🍞) increased to %.3f" % p_bread_after)
		passed += 1
	else:
		print("  ✗ P(🍞) still near zero: %.3f" % p_bread_after)
		failed += 1

	# Test 9: Harvest measurement
	print("\nTest 9: Harvest (projective measurement)")
	var result = kitchen.harvest()

	if result["success"]:
		print("  ✓ Harvest succeeded")
		print("    → Outcome: %s" % result["outcome"])
		print("    → Collapsed to: |%d⟩" % result["basis_state"])
		print("    → Yield: %d" % result["yield"])
		passed += 1
	else:
		print("  ✗ Harvest failed")
		failed += 1

	# Test 10: Reset after harvest
	print("\nTest 10: Reset to ground state after harvest")
	var p_ground_after = kitchen.get_ground_probability()

	if abs(p_ground_after - 1.0) < 0.01:
		print("  ✓ Reset to |111⟩, P(ground)=%.3f" % p_ground_after)
		passed += 1
	else:
		print("  ✗ Not reset properly, P(ground)=%.3f" % p_ground_after)
		failed += 1

	# Test 11: Natural decay
	print("\nTest 11: Natural decay (no drives)")
	kitchen.add_fire(0.5)  # Brief drive
	for i in range(5):
		kitchen._update_quantum_substrate(0.1)

	var p_hot_before_decay = kitchen.get_temperature_hot()

	# Let decay happen (no drives active)
	for i in range(50):
		kitchen._update_quantum_substrate(0.1)

	var p_hot_after_decay = kitchen.get_temperature_hot()

	if p_hot_after_decay < p_hot_before_decay:
		print("  ✓ Temperature decayed: %.3f → %.3f" % [p_hot_before_decay, p_hot_after_decay])
		passed += 1
	else:
		print("  ✗ No decay observed")
		failed += 1

	# Test 12: Trace preservation
	print("\nTest 12: Trace preservation")
	var trace = kitchen.quantum_computer.get_trace()

	if abs(trace - 1.0) < 0.01:
		print("  ✓ Tr(ρ) = %.6f (preserved)" % trace)
		passed += 1
	else:
		print("  ⚠ Tr(ρ) = %.6f (should be 1.0)" % trace)
		failed += 1

	# Test 13: Kitchen status dictionary
	print("\nTest 13: Kitchen status dictionary")
	var status = kitchen.get_kitchen_status()

	if (status.has("bread_probability") and
		status.has("temperature_hot") and
		status.has("detuning") and
		status.has("baking_rate")):
		print("  ✓ Status dict contains all keys")
		passed += 1
	else:
		print("  ✗ Status dict missing keys")
		failed += 1

	# Test 14: BiomeBase integration
	print("\nTest 14: BiomeBase integration")
	if kitchen.get_biome_type() == "QuantumKitchen":
		print("  ✓ get_biome_type() = QuantumKitchen")
		passed += 1
	else:
		print("  ✗ Wrong biome type: %s" % kitchen.get_biome_type())
		failed += 1

	# Test 15: Emoji pairing
	print("\nTest 15: Emoji pairing")
	var paired_fire = kitchen.get_paired_emoji("🔥")
	var paired_water = kitchen.get_paired_emoji("💧")

	if paired_fire == "❄️" and paired_water == "🏜️":
		print("  ✓ Emoji pairs: 🔥↔❄️, 💧↔🏜️")
		passed += 1
	else:
		print("  ✗ Emoji pairing incorrect")
		failed += 1

	# Summary
	print("\n" + "=".repeat(60))
	print("Summary: %d passed, %d failed" % [passed, failed])
	if failed == 0:
		print("✅ All kitchen integration tests passed!")
	else:
		print("❌ Some tests failed")
	print("=".repeat(60) + "\n")

	quit()
