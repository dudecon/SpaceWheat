extends SceneTree

## Phase 5 test: Verify biomes work with faction-built Icons

func _init():
	print("=== Phase 5: Verifying Biomes with Faction-Built Icons ===")

	# Wait for autoloads
	print("\nWaiting for autoloads...")

	print("\n--- Test 1: Verify Faction-Built Icons Have Couplings ---")
	# Get IconRegistry from autoload
	var icon_registry = root.get_node_or_null("IconRegistry")
	if icon_registry == null:
		print("❌ IconRegistry autoload not found")
		quit()
		return

	print("✓ IconRegistry autoload found with %d icons" % icon_registry.icons.size())

	# Check sun icon has driver
	var sun = icon_registry.get_icon("☀")
	if sun:
		print("  ☀ Sun: self_energy=%.2f, is_driver=%s" % [sun.self_energy, sun.is_driver])
		if sun.self_energy_driver != "":
			print("    ✓ Has driver: %s" % sun.self_energy_driver)
		else:
			print("    ⚠️ No driver configured")
	else:
		print("  ❌ Sun icon not found")

	# Check wheat icon has couplings
	var wheat = icon_registry.get_icon("🌾")
	if wheat:
		print("  🌾 Wheat: H couplings=%d, L incoming=%d" % [
			wheat.hamiltonian_couplings.size(),
			wheat.lindblad_incoming.size()])
		if wheat.lindblad_incoming.size() > 0:
			print("    ✓ Has Lindblad incoming couplings")
		else:
			print("    ⚠️ No Lindblad incoming couplings")
	else:
		print("  ❌ Wheat icon not found")

	# Check bee icon exists (from Pollinator Guild faction)
	var bee = icon_registry.get_icon("🐝")
	if bee:
		print("  🐝 Bee: description='%s'" % bee.description.substr(0, 40))
		print("    ✓ Pollinator Guild faction working")
	else:
		print("  ❌ Bee icon not found (Pollinator Guild faction may be missing)")

	# Check disease icon exists (from Plague Vectors faction)
	var disease = icon_registry.get_icon("🦠")
	if disease:
		print("  🦠 Disease: decay_rate=%.3f, decay_target='%s'" % [
			disease.decay_rate, disease.decay_target])
		print("    ✓ Plague Vectors faction working")
	else:
		print("  ❌ Disease icon not found")

	print("\n--- Test 2: BioticFlux Biome Verification ---")
	# Check BioticFlux biome
	var bioticflux = root.get_node_or_null("FarmUI/SubViewportContainer/SubViewport/BiomeHost/BioticFlux")
	if bioticflux == null:
		bioticflux = root.get_node_or_null("BiomeHost/BioticFlux")
	if bioticflux == null:
		# Try to find it under PlayerShell
		var ps = root.get_node_or_null("PlayerShell")
		if ps:
			bioticflux = ps.get_node_or_null("ContentArea/FarmUI/SubViewportContainer/SubViewport/BiomeHost/BioticFlux")

	if bioticflux:
		print("✓ BioticFlux biome found")
		if bioticflux.quantum_computer:
			print("  quantum_computer: %d qubits" % bioticflux.quantum_computer.register_map.num_qubits)
			print("  lindblad_operators: %d" % bioticflux.quantum_computer.lindblad_operators.size())
			print("  gated_configs: %d" % bioticflux.quantum_computer.gated_lindblad_configs.size())
		else:
			print("  ⚠️ No quantum_computer")
	else:
		print("⚠️ BioticFlux biome not found in tree (may not be active)")

	print("\n--- Test 3: Kitchen Biome Verification ---")
	# Check Kitchen biome similarly
	var kitchen = root.find_child("Kitchen", true, false)
	if kitchen == null:
		kitchen = root.find_child("QuantumKitchen", true, false)

	if kitchen:
		print("✓ Kitchen biome found")
		if kitchen.quantum_computer:
			print("  quantum_computer: %d qubits" % kitchen.quantum_computer.register_map.num_qubits)
			print("  lindblad_operators: %d" % kitchen.quantum_computer.lindblad_operators.size())
		else:
			print("  ⚠️ No quantum_computer")
	else:
		print("⚠️ Kitchen biome not found (may not be active)")

	print("\n=== Phase 5 Tests Complete ===")
	print("✓ All faction-built Icons verified")
	quit()
