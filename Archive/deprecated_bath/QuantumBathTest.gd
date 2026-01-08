extends Node

## Phase 0 Test Scene
## Tests Complex number arithmetic and Icon resource creation

func _ready():
	print("\n" + "=".repeat(60))
	print("QUANTUM BATH PHASE 0 TESTS")
	print("=".repeat(60) + "\n")

	# Phase 0 Tests
	test_complex_arithmetic()
	test_icon_creation()
	test_icon_time_dependent()

	print("\n" + "-".repeat(60))
	print("✅ PHASE 0 COMPLETE")
	print("-".repeat(60))

	# Phase 1 Tests
	print("\nPHASE 1: QUANTUM BATH CORE")
	print("-".repeat(60) + "\n")

	test_bath_normalization()
	test_hamiltonian_oscillation()
	test_lindblad_transfer()

	print("\n" + "-".repeat(60))
	print("✅ PHASE 1 COMPLETE")
	print("-".repeat(60))

	# Phase 2 Tests
	print("\nPHASE 2: ICON SYSTEM")
	print("-".repeat(60) + "\n")

	test_icon_registry()
	test_icon_composition()

	print("\n" + "-".repeat(60))
	print("✅ PHASE 2 COMPLETE")
	print("-".repeat(60))

	# Phase 3 Tests
	print("\nPHASE 3: BIOME INTEGRATION")
	print("-".repeat(60) + "\n")

	test_bath_biome_integration()
	test_projection_backaction()

	print("\n" + "=".repeat(60))
	print("✅ ALL TESTS PASSED (PHASES 0-3)")
	print("=".repeat(60) + "\n")

	# Auto-quit for headless testing
	if OS.has_feature("standalone"):
		get_tree().quit()

func test_complex_arithmetic():
	print("🧪 Testing Complex Arithmetic...")

	# Test basic construction
	var z1 = Complex.new(3.0, 4.0)
	assert(abs(z1.re - 3.0) < 1e-6, "Complex real part incorrect")
	assert(abs(z1.im - 4.0) < 1e-6, "Complex imaginary part incorrect")

	# Test magnitude
	var mag = z1.abs()
	assert(abs(mag - 5.0) < 1e-6, "Complex magnitude incorrect: expected 5.0, got %f" % mag)

	# Test abs_sq
	var abs_sq = z1.abs_sq()
	assert(abs(abs_sq - 25.0) < 1e-6, "Complex abs_sq incorrect: expected 25.0, got %f" % abs_sq)

	# Test arg
	var arg = z1.arg()
	var expected_arg = atan2(4.0, 3.0)
	assert(abs(arg - expected_arg) < 1e-6, "Complex arg incorrect")

	# Test conjugate
	var z1_conj = z1.conjugate()
	assert(abs(z1_conj.re - 3.0) < 1e-6, "Conjugate real part incorrect")
	assert(abs(z1_conj.im - (-4.0)) < 1e-6, "Conjugate imaginary part incorrect")

	# Test addition
	var z2 = Complex.new(1.0, 2.0)
	var z_sum = z1.add(z2)
	assert(abs(z_sum.re - 4.0) < 1e-6, "Addition real part incorrect")
	assert(abs(z_sum.im - 6.0) < 1e-6, "Addition imaginary part incorrect")

	# Test subtraction
	var z_diff = z1.sub(z2)
	assert(abs(z_diff.re - 2.0) < 1e-6, "Subtraction real part incorrect")
	assert(abs(z_diff.im - 2.0) < 1e-6, "Subtraction imaginary part incorrect")

	# Test multiplication (3+4i)(1+2i) = 3+6i+4i+8i² = 3+10i-8 = -5+10i
	var z_prod = z1.mul(z2)
	assert(abs(z_prod.re - (-5.0)) < 1e-6, "Multiplication real part incorrect: expected -5.0, got %f" % z_prod.re)
	assert(abs(z_prod.im - 10.0) < 1e-6, "Multiplication imaginary part incorrect: expected 10.0, got %f" % z_prod.im)

	# Test division (3+4i)/(1+2i) = (3+4i)(1-2i)/5 = (3-6i+4i-8i²)/5 = (3-2i+8)/5 = (11-2i)/5
	var z_quot = z1.div(z2)
	assert(abs(z_quot.re - 2.2) < 1e-6, "Division real part incorrect: expected 2.2, got %f" % z_quot.re)
	assert(abs(z_quot.im - (-0.4)) < 1e-6, "Division imaginary part incorrect: expected -0.4, got %f" % z_quot.im)

	# Test polar conversion
	var z_polar = Complex.from_polar(5.0, PI / 4.0)
	var expected_re = 5.0 * cos(PI / 4.0)
	var expected_im = 5.0 * sin(PI / 4.0)
	assert(abs(z_polar.re - expected_re) < 1e-6, "Polar conversion real part incorrect")
	assert(abs(z_polar.im - expected_im) < 1e-6, "Polar conversion imaginary part incorrect")

	# Test utility functions
	var z_zero = Complex.zero()
	assert(z_zero.re == 0.0 and z_zero.im == 0.0, "Zero incorrect")

	var z_one = Complex.one()
	assert(z_one.re == 1.0 and z_one.im == 0.0, "One incorrect")

	var z_i = Complex.i()
	assert(z_i.re == 0.0 and z_i.im == 1.0, "i incorrect")

	# Test scale
	var z_scaled = z1.scale(2.0)
	assert(abs(z_scaled.re - 6.0) < 1e-6, "Scale real part incorrect")
	assert(abs(z_scaled.im - 8.0) < 1e-6, "Scale imaginary part incorrect")

	print("  ✅ Complex arithmetic tests passed")

func test_icon_creation():
	print("🧪 Testing Icon Creation...")

	# Create a basic icon
	var wheat_icon = Icon.new()
	wheat_icon.emoji = "🌾"
	wheat_icon.display_name = "Wheat"
	wheat_icon.description = "The golden grain"
	wheat_icon.self_energy = 0.1
	wheat_icon.hamiltonian_couplings = {"☀": 0.5, "🌙": 0.2}
	wheat_icon.lindblad_incoming = {"☀": 0.1}
	wheat_icon.decay_rate = 0.02
	wheat_icon.decay_target = "🍂"
	wheat_icon.trophic_level = 1
	var wheat_tags: Array[String] = ["flora", "cultivated"]
	wheat_icon.tags = wheat_tags

	assert(wheat_icon.emoji == "🌾", "Icon emoji incorrect")
	assert(wheat_icon.display_name == "Wheat", "Icon display_name incorrect")
	assert(abs(wheat_icon.self_energy - 0.1) < 1e-6, "Icon self_energy incorrect")
	assert(wheat_icon.hamiltonian_couplings.has("☀"), "Icon missing hamiltonian coupling")
	assert(abs(wheat_icon.hamiltonian_couplings["☀"] - 0.5) < 1e-6, "Icon coupling strength incorrect")
	assert(wheat_icon.lindblad_incoming.has("☀"), "Icon missing lindblad term")
	assert(abs(wheat_icon.decay_rate - 0.02) < 1e-6, "Icon decay_rate incorrect")
	assert(wheat_icon.trophic_level == 1, "Icon trophic_level incorrect")
	assert("flora" in wheat_icon.tags, "Icon tags incorrect")

	print("  ✅ Icon creation tests passed")

func test_icon_time_dependent():
	print("🧪 Testing Icon Time-Dependent Self-Energy...")

	# Create icon with cosine driver
	var sun_icon = Icon.new()
	sun_icon.emoji = "☀"
	sun_icon.display_name = "Sol"
	sun_icon.self_energy = 1.0
	sun_icon.self_energy_driver = "cosine"
	sun_icon.driver_frequency = 0.1
	sun_icon.driver_phase = 0.0
	sun_icon.driver_amplitude = 1.0

	# Test at t=0 (cosine should be 1.0)
	var energy_0 = sun_icon.get_self_energy(0.0)
	assert(abs(energy_0 - 1.0) < 1e-6, "Cosine driver at t=0 incorrect: expected 1.0, got %f" % energy_0)

	# Test at t = π/(2ω) = π/(2 * 0.1 * 2π) = 2.5 (cosine should be 0.0)
	var t_quarter = PI / (2.0 * sun_icon.driver_frequency * TAU)
	var energy_quarter = sun_icon.get_self_energy(t_quarter)
	assert(abs(energy_quarter) < 1e-5, "Cosine driver at quarter period incorrect: expected ~0.0, got %f" % energy_quarter)

	# Test sine driver
	var moon_icon = Icon.new()
	moon_icon.emoji = "🌙"
	moon_icon.self_energy = 0.8
	moon_icon.self_energy_driver = "sine"
	moon_icon.driver_frequency = 0.1
	moon_icon.driver_phase = 0.0
	moon_icon.driver_amplitude = 1.0

	# Test at t=0 (sine should be 0.0)
	var moon_energy_0 = moon_icon.get_self_energy(0.0)
	assert(abs(moon_energy_0) < 1e-6, "Sine driver at t=0 incorrect: expected 0.0, got %f" % moon_energy_0)

	# Test pulse driver
	var pulse_icon = Icon.new()
	pulse_icon.emoji = "⚡"
	pulse_icon.self_energy = 2.0
	pulse_icon.self_energy_driver = "pulse"
	pulse_icon.driver_frequency = 1.0
	pulse_icon.driver_amplitude = 1.0

	# First half of cycle should be full amplitude
	var pulse_energy_0 = pulse_icon.get_self_energy(0.1)
	assert(abs(pulse_energy_0 - 2.0) < 1e-6, "Pulse driver (on) incorrect: expected 2.0, got %f" % pulse_energy_0)

	# Second half of cycle should be zero
	var pulse_energy_half = pulse_icon.get_self_energy(0.6)
	assert(abs(pulse_energy_half) < 1e-6, "Pulse driver (off) incorrect: expected 0.0, got %f" % pulse_energy_half)

	print("  ✅ Time-dependent self-energy tests passed")

## ========================================
## Phase 1 Tests: QuantumBath Core Evolution
## ========================================

func test_bath_normalization():
	print("🧪 Testing Bath Normalization (Conservation)...")

	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["A", "B", "C"])
	bath.initialize_uniform()

	# Create a simple Icon with coupling
	var icon_a = Icon.new()
	icon_a.emoji = "A"
	icon_a.hamiltonian_couplings = {"B": 0.3, "C": 0.2}
	icon_a.self_energy = 0.1

	var icon_b = Icon.new()
	icon_b.emoji = "B"
	icon_b.hamiltonian_couplings = {"A": 0.3}
	icon_b.self_energy = 0.05

	var icons: Array[Icon] = [icon_a, icon_b]
	bath.active_icons = icons
	bath.build_hamiltonian_from_icons(icons)

	# Evolve for 1000 steps
	for i in range(1000):
		bath.evolve(0.016)

	var final_prob = bath.get_total_probability()
	assert(abs(final_prob - 1.0) < 0.001, "Normalization failed: total probability = %f" % final_prob)

	print("  ✅ Bath normalization conserved (prob = %.6f)" % final_prob)

func test_hamiltonian_oscillation():
	print("🧪 Testing Hamiltonian Oscillation...")

	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["A", "B"])

	# Start in pure |A⟩ state
	bath.amplitudes[0] = Complex.new(1.0, 0.0)
	bath.amplitudes[1] = Complex.zero()

	# Create Icon with coupling between A and B
	var icon_a = Icon.new()
	icon_a.emoji = "A"
	icon_a.hamiltonian_couplings = {"B": 0.5}

	var icons: Array[Icon] = [icon_a]
	bath.active_icons = icons
	bath.build_hamiltonian_from_icons(icons)

	# Record probability of A over time
	var prob_a_history = []
	for i in range(200):
		prob_a_history.append(bath.get_probability("A"))
		bath.evolve(0.05)

	# Check that oscillation occurred
	var prob_a_start = prob_a_history[0]
	var prob_a_mid = prob_a_history[prob_a_history.size() / 2]
	var prob_a_end = prob_a_history[prob_a_history.size() - 1]

	# Should start near 1.0, dip in middle, return toward 1.0
	assert(prob_a_start > 0.95, "Oscillation: Initial state incorrect")
	assert(prob_a_mid < 0.8, "Oscillation: Didn't transfer to B (mid prob_a = %f)" % prob_a_mid)

	print("  ✅ Hamiltonian oscillation verified (A: %.2f → %.2f → %.2f)" % [prob_a_start, prob_a_mid, prob_a_end])

func test_lindblad_transfer():
	print("🧪 Testing Lindblad Transfer...")

	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["source", "target"])

	# Start with all amplitude in source
	bath.amplitudes[0] = Complex.new(1.0, 0.0)
	bath.amplitudes[1] = Complex.zero()

	# Create Icon with Lindblad transfer from source to target
	var icon_source = Icon.new()
	icon_source.emoji = "source"
	icon_source.lindblad_outgoing = {"target": 0.1}

	var icons: Array[Icon] = [icon_source]
	bath.active_icons = icons
	bath.build_lindblad_from_icons(icons)

	# Evolve
	for i in range(100):
		bath.evolve(0.016)

	var prob_target = bath.get_probability("target")
	var prob_source = bath.get_probability("source")

	# Significant transfer should have occurred
	assert(prob_target > 0.2, "Lindblad transfer: Target didn't gain amplitude (prob = %f)" % prob_target)
	assert(prob_source < 0.8, "Lindblad transfer: Source didn't lose amplitude (prob = %f)" % prob_source)
	assert(abs((prob_source + prob_target) - 1.0) < 0.01, "Lindblad transfer: Normalization broken")

	print("  ✅ Lindblad transfer verified (source: %.2f → target: %.2f)" % [prob_source, prob_target])

## ========================================
## Phase 2 Tests: Icon System
## ========================================

func test_icon_registry():
	print("🧪 Testing IconRegistry...")

	# IconRegistry should be autoloaded
	assert(IconRegistry != null, "IconRegistry not found (autoload failed)")

	# Should have 20 core Icons
	var icon_count = IconRegistry.icons.size()
	assert(icon_count == 20, "IconRegistry: Expected 20 icons, got %d" % icon_count)

	# Test specific Icons exist
	var expected_icons = ["☀", "🌙", "🌾", "🍄", "🌿", "🌱", "🐺", "🐇", "🦌", "🦅",
	                      "💧", "⛰", "🍂", "💀", "👥", "🌳", "🐭", "🐦", "🐜", "🏪"]

	for emoji in expected_icons:
		assert(IconRegistry.has_icon(emoji), "IconRegistry: Missing icon %s" % emoji)

	# Test sun Icon properties
	var sun = IconRegistry.get_icon("☀")
	assert(sun != null, "Sun icon not found")
	assert(sun.display_name == "Sol", "Sun display_name incorrect")
	assert(sun.self_energy_driver == "cosine", "Sun driver incorrect")
	assert(sun.is_driver, "Sun should be marked as driver")
	assert(sun.hamiltonian_couplings.has("🌙"), "Sun should couple to moon")

	# Test wolf Icon properties
	var wolf = IconRegistry.get_icon("🐺")
	assert(wolf != null, "Wolf icon not found")
	assert(wolf.trophic_level == 3, "Wolf trophic level incorrect")
	assert(wolf.lindblad_incoming.has("🐇"), "Wolf should receive from rabbit")

	# Test tag system
	var celestial_icons = IconRegistry.get_icons_by_tag("celestial")
	assert(celestial_icons.size() == 2, "Should have 2 celestial icons, got %d" % celestial_icons.size())

	var fauna_icons = IconRegistry.get_icons_by_tag("fauna")
	assert(fauna_icons.size() >= 6, "Should have at least 6 fauna icons, got %d" % fauna_icons.size())

	print("  ✅ IconRegistry verified (%d icons, all present)" % icon_count)

func test_icon_composition():
	print("🧪 Testing Icon Composition...")

	# Create a simple ecosystem bath
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["☀", "🌿", "🐇", "🍂"])
	bath.initialize_uniform()

	# Get Icons from registry
	var icons: Array[Icon] = []
	icons.append(IconRegistry.get_icon("☀"))
	icons.append(IconRegistry.get_icon("🌿"))
	icons.append(IconRegistry.get_icon("🐇"))
	icons.append(IconRegistry.get_icon("🍂"))

	bath.active_icons = icons
	bath.build_hamiltonian_from_icons(icons)
	bath.build_lindblad_from_icons(icons)

	# Hamiltonian should have been built
	assert(not bath.hamiltonian_sparse.is_empty(), "Hamiltonian not built")

	# Lindblad terms should exist (vegetation and rabbit have incoming terms)
	assert(not bath.lindblad_terms.is_empty(), "Lindblad terms not built")

	# Evolve the ecosystem
	for i in range(100):
		bath.evolve(0.016)

	# Probability should still be conserved
	var final_prob = bath.get_total_probability()
	assert(abs(final_prob - 1.0) < 0.01, "Composition: Normalization broken after evolution")

	# Sun amplitude should be influenced by its time-dependent driver
	# (Hard to test precisely without knowing exact evolution, but it should exist)
	var sun_prob = bath.get_probability("☀")
	assert(sun_prob > 0.0, "Sun probability should be non-zero")

	print("  ✅ Icon composition verified (ecosystem evolved, normalized)")
	print("       Final distribution: ☀=%.2f 🌿=%.2f 🐇=%.2f 🍂=%.2f" % [
		bath.get_probability("☀"),
		bath.get_probability("🌿"),
		bath.get_probability("🐇"),
		bath.get_probability("🍂")
	])

## ========================================
## Phase 3 Tests: BiomeBase Integration
## ========================================

func test_bath_biome_integration():
	print("🧪 Testing BiomeBase Bath Integration...")

	# Create a test biome with bath mode
	var test_biome = BiomeBase.new()
	test_biome.use_bath_mode = true

	# Manually initialize bath for testing
	test_biome.bath = QuantumBath.new()
	test_biome.bath.initialize_with_emojis(["🌾", "💀", "🍄"])
	test_biome.bath.initialize_uniform()

	var icons: Array[Icon] = []
	icons.append(IconRegistry.get_icon("🌾"))
	icons.append(IconRegistry.get_icon("💀"))
	icons.append(IconRegistry.get_icon("🍄"))

	test_biome.bath.active_icons = icons
	test_biome.bath.build_hamiltonian_from_icons(icons)
	test_biome.bath.build_lindblad_from_icons(icons)

	# Test: Create a projection
	var pos = Vector2i(0, 0)
	var qubit = test_biome.create_projection(pos, "🌾", "💀")

	assert(qubit != null, "Projection should create a qubit")
	assert(test_biome.active_projections.has(pos), "Projection should be tracked")
	assert(test_biome.quantum_states.has(pos), "Backward compatibility: should be in quantum_states")

	# Test: Projection reflects bath state
	var proj = test_biome.bath.project_onto_axis("🌾", "💀")
	assert(abs(qubit.theta - proj.theta) < 0.01, "Qubit theta should match bath projection")

	# Test: Bath evolution updates projections
	test_biome.bath.evolve(0.1)
	test_biome.update_projections()

	var proj_after = test_biome.bath.project_onto_axis("🌾", "💀")
	# Theta may have changed due to evolution
	assert(abs(qubit.theta - proj_after.theta) < 0.01, "Qubit should update with bath")

	# Test: Remove projection
	test_biome.remove_projection(pos)
	assert(not test_biome.active_projections.has(pos), "Projection should be removed")

	print("  ✅ BiomeBase bath integration verified")

func test_projection_backaction():
	print("🧪 Testing Projection Measurement Backaction...")

	# Create test biome with bath
	var test_biome = BiomeBase.new()
	test_biome.use_bath_mode = true

	test_biome.bath = QuantumBath.new()
	test_biome.bath.initialize_with_emojis(["A", "B"])

	# Start with pure |A⟩ state
	test_biome.bath.amplitudes[0] = Complex.new(1.0, 0.0)
	test_biome.bath.amplitudes[1] = Complex.zero()

	# Create a projection
	var pos1 = Vector2i(0, 0)
	var qubit1 = test_biome.create_projection(pos1, "A", "B")

	# Create a second overlapping projection (same axis)
	var pos2 = Vector2i(1, 0)
	var qubit2 = test_biome.create_projection(pos2, "A", "B")

	# Both should show |A⟩ (theta ≈ 0)
	assert(qubit1.theta < 0.5, "First projection should be near |A⟩")
	assert(qubit2.theta < 0.5, "Second projection should be near |A⟩")

	# Measure the first projection
	var outcome = test_biome.measure_projection(pos1)
	assert(outcome == "A" or outcome == "B", "Measurement should return an outcome")

	# If outcome is B, the bath has collapsed toward B
	# Both projections should now reflect this
	# (We can't predict which outcome, but both qubits should match)
	assert(abs(qubit1.theta - qubit2.theta) < 0.1, "Both projections should see same bath state after measurement")

	# Probability should still be conserved
	var total_prob = test_biome.bath.get_total_probability()
	assert(abs(total_prob - 1.0) < 0.01, "Bath normalization should be preserved")

	print("  ✅ Projection backaction verified (measurement affects all projections)")
