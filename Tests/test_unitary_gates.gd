#!/usr/bin/env -S godot --headless -s
extends SceneTree

## UNITARY GATES TEST - Tool 4
## Tests single-qubit gates (X, H, Z) on planted plots

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")

var farm = null
var grid = null
var economy = null
var plot_pool = null
var biome_list = []

var frame_count = 0
var scene_loaded = false
var tests_done = false

var findings = {
	"gate_definitions": [],
	"gate_application": [],
	"gate_physics": [],
	"issues": []
}

func _init():
	print("\n" + "═".repeat(80))
	print("🔬 UNITARY GATES TEST - Single-Qubit Gates (Tool 4)")
	print("═".repeat(80))

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		print("\n⏳ Frame 5: Loading main scene...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			var instance = scene.instantiate()
			root.add_child(instance)
			scene_loaded = true

			var boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)
		else:
			print("   ❌ Failed to load scene")
			quit(1)

func _on_game_ready():
	if tests_done:
		return
	tests_done = true

	print("\n✅ Game ready! Starting unitary gates testing...\n")

	var fv = root.get_node_or_null("FarmView")
	if not fv or not fv.farm:
		print("❌ Farm not found")
		print_findings()
		quit()
		return

	farm = fv.farm
	grid = farm.grid
	economy = farm.economy
	plot_pool = farm.plot_pool
	biome_list = grid.biomes.values()

	# Bootstrap resources
	economy.add_resource("💰", 2000, "test_bootstrap")

	print("Systems initialized:")
	print("   Farm: ✅")
	print("   Grid: ✅ (%d plots)" % grid.plots.size())
	print("   Biomes: ✅ (%d)" % biome_list.size())

	# Run tests
	_test_gate_definitions()
	_test_gate_application()
	_test_gate_physics()

	print_findings()
	quit()

# ═══════════════════════════════════════════════════════════════
# TEST 1: GATE DEFINITIONS
# ═══════════════════════════════════════════════════════════════

func _test_gate_definitions():
	print("\n" + "─".repeat(80))
	print("TEST 1: Gate Definitions (QuantumGateLibrary)")
	print("─".repeat(80))

	var gate_lib = QuantumGateLibrary.new()

	# Check available gates
	var all_gates = gate_lib.list_gates()
	print("\n   Available gates: %s" % str(all_gates))
	_finding("gate_definitions", "✅ QuantumGateLibrary has %d gates" % all_gates.size())

	# Check 1-qubit gates
	var q1_gates = gate_lib.list_1q_gates()
	print("   1-qubit gates: %s" % str(q1_gates))
	_finding("gate_definitions", "✅ 1-qubit gates: %d gates" % q1_gates.size())

	# Check specific gates we'll test
	var test_gates = ["X", "H", "Z"]
	for gate in test_gates:
		if gate_lib.GATES.has(gate):
			var gate_data = gate_lib.GATES[gate]
			print("   %s gate: arity=%d" % [gate, gate_data.get("arity", "?")])
			_finding("gate_definitions", "✅ Gate %s defined" % gate)
		else:
			_finding("gate_definitions", "❌ Gate %s NOT found" % gate)

# ═══════════════════════════════════════════════════════════════
# TEST 2: GATE APPLICATION ON PLANTED PLOTS
# ═══════════════════════════════════════════════════════════════

func _test_gate_application():
	print("\n" + "─".repeat(80))
	print("TEST 2: Gate Application (Plant → Gate → Measure)")
	print("─".repeat(80))

	if biome_list.is_empty():
		_finding("gate_application", "⚠️ NO BIOMES")
		return

	var biome = biome_list[0]
	print("\n   Testing on biome: %s" % biome.get_biome_type())

	# Enable BUILD mode for planting
	biome.set_evolution_paused(true)
	print("   Enabled BUILD mode for planting")

	# Step 1: Plant a plot (must use emotion already in biome)
	print("\n   STEP 1: Plant existing emoji (already in quantum system)")
	var plant_pos = Vector2i(2, 0)
	var plant = grid.plant(plant_pos, "wheat")  # Wheat already in BioticFlux
	if plant:
		_finding("gate_application", "✅ Plot planted at %s" % plant_pos)
	else:
		_finding("gate_application", "❌ Failed to plant plot")
		return

	# Step 2: Apply Pauli-X gate
	print("\n   STEP 2: Apply Pauli-X gate")
	var plot = grid.get_plot(plant_pos)
	if not plot:
		_finding("gate_application", "❌ Plot not found after planting")
		return

	var gate_lib = QuantumGateLibrary.new()
	if not plot.is_planted:
		_finding("gate_application", "❌ Plot not marked as planted")
		return

	# Get quantum computer and apply gate directly
	var biome_for_plot = grid.get_biome_for_plot(plant_pos)
	if not biome_for_plot or not biome_for_plot.quantum_computer:
		_finding("gate_application", "❌ Biome quantum computer not found")
		return

	var register_id = grid.get_register_for_plot(plant_pos)
	if register_id < 0:
		_finding("gate_application", "❌ Invalid register ID")
		return

	var comp = biome_for_plot.quantum_computer.get_component_containing(register_id)
	if not comp:
		_finding("gate_application", "❌ Component not found")
		return

	# Get gate matrix
	var gate_matrix = gate_lib.GATES["X"]["matrix"]
	var result = biome_for_plot.quantum_computer.apply_unitary_1q(comp, register_id, gate_matrix)

	if result:
		_finding("gate_application", "✅ Pauli-X gate applied successfully")
		print("     Result: true (gate applied)")
	else:
		_finding("gate_application", "❌ Pauli-X gate application failed")
		print("     Result: false")

	# Step 3: Apply Hadamard gate
	print("\n   STEP 3: Apply Hadamard gate")
	var plant_pos_h = Vector2i(3, 0)
	var plant_h = grid.plant(plant_pos_h, "bread")
	if plant_h:
		_finding("gate_application", "✅ Second plot planted at %s" % plant_pos_h)

		var plot_h = grid.get_plot(plant_pos_h)
		var biome_h = grid.get_biome_for_plot(plant_pos_h)
		var reg_h = grid.get_register_for_plot(plant_pos_h)
		var comp_h = biome_h.quantum_computer.get_component_containing(reg_h)

		var gate_h = gate_lib.GATES["H"]["matrix"]
		var result_h = biome_h.quantum_computer.apply_unitary_1q(comp_h, reg_h, gate_h)

		if result_h:
			_finding("gate_application", "✅ Hadamard gate applied successfully")
		else:
			_finding("gate_application", "❌ Hadamard gate application failed")
	else:
		_finding("gate_application", "⚠️ Could not plant second plot for Hadamard test")

# ═══════════════════════════════════════════════════════════════
# TEST 3: GATE PHYSICS (Measurement after gates)
# ═══════════════════════════════════════════════════════════════

func _test_gate_physics():
	print("\n" + "─".repeat(80))
	print("TEST 3: Gate Physics (Verify state changes)")
	print("─".repeat(80))

	if biome_list.is_empty():
		_finding("gate_physics", "⚠️ NO BIOMES")
		return

	var biome = biome_list[0]

	# Enable BUILD mode for planting
	biome.set_evolution_paused(true)

	# Plant a plot to test
	print("\n   TEST 3A: X gate flips state")
	var test_pos = Vector2i(4, 0)
	var plant = grid.plant(test_pos, "wheat")

	if not plant:
		_finding("gate_physics", "⚠️ Could not plant test plot")
		return

	var plot = grid.get_plot(test_pos)
	var plot_biome = grid.get_biome_for_plot(test_pos)
	var reg_id = grid.get_register_for_plot(test_pos)
	var comp = plot_biome.quantum_computer.get_component_containing(reg_id)

	# Get initial state
	var initial_probs = plot_biome.quantum_computer.inspect_register_distribution(comp, reg_id)
	print("   Initial state probabilities: %s" % initial_probs)

	# Apply X gate (should flip)
	var gate_lib = QuantumGateLibrary.new()
	var x_gate = gate_lib.GATES["X"]["matrix"]
	var x_result = plot_biome.quantum_computer.apply_unitary_1q(comp, reg_id, x_gate)

	if x_result:
		_finding("gate_physics", "✅ X gate applied (state flip expected)")

		# Get state after X
		var after_x = plot_biome.quantum_computer.inspect_register_distribution(comp, reg_id)
		print("   After X gate: %s" % after_x)
	else:
		_finding("gate_physics", "❌ X gate application failed")

	# Test 3B: H gate creates superposition
	print("\n   TEST 3B: H gate creates superposition")
	var test_pos_h = Vector2i(5, 0)
	var plant_h = grid.plant(test_pos_h, "bread")

	if plant_h:
		var plot_h = grid.get_plot(test_pos_h)
		var biome_h = grid.get_biome_for_plot(test_pos_h)
		var reg_h = grid.get_register_for_plot(test_pos_h)
		var comp_h = biome_h.quantum_computer.get_component_containing(reg_h)

		var h_gate = gate_lib.GATES["H"]["matrix"]
		var h_result = biome_h.quantum_computer.apply_unitary_1q(comp_h, reg_h, h_gate)

		if h_result:
			_finding("gate_physics", "✅ Hadamard gate applied (superposition expected)")

			var after_h = biome_h.quantum_computer.inspect_register_distribution(comp_h, reg_h)
			print("   After H gate: %s" % after_h)

			# Check if probabilities are roughly equal
			if after_h.size() == 2:
				var p0 = after_h[0]
				var p1 = after_h[1]
				if abs(p0 - p1) < 0.1:  # Allow some numerical error
					_finding("gate_physics", "✅ Hadamard created balanced superposition (~0.5 each)")
				else:
					_finding("gate_physics", "⚠️ Probabilities not balanced (%.2f vs %.2f)" % [p0, p1])
		else:
			_finding("gate_physics", "❌ Hadamard application failed")
	else:
		_finding("gate_physics", "⚠️ Could not plant for Hadamard test")

# ═══════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

func _finding(category: String, message: String):
	findings[category].append(message)
	print("   " + message)

func print_findings():
	print("\n" + "═".repeat(80))
	print("📋 UNITARY GATES TEST SUMMARY")
	print("═".repeat(80))

	var total_findings = 0
	var total_issues = 0

	for category in findings.keys():
		var items = findings[category]
		if items.is_empty():
			continue

		print("\n🔹 %s (%d)" % [category.to_upper(), items.size()])
		for item in items:
			print("   " + item)
			if "❌" in item or "FAILED" in item:
				total_issues += 1
			total_findings += 1

	print("\n" + "═".repeat(80))
	print("📊 TOTALS: %d findings, %d issues" % [total_findings, total_issues])
	print("═".repeat(80) + "\n")
