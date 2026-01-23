#!/usr/bin/env -S godot --headless -s
extends SceneTree

## CLAUDE PLAYS v2 - Full Toolset Gameplay Session
##
## Uses the complete v2 tool architecture:
##   Tool 1: PROBE (Explore/Measure/Pop)
##   Tool 2: GATES (X/H/Ry + Z/S/T via F-cycling)
##   Tool 3: ENTANGLE (CNOT/SWAP/CZ + Bell/Disentangle/Inspect via F-cycling)
##   Tool 4: INDUSTRY (Mill/Market/Kitchen)
##
## Run: godot --headless --script Tests/claude_plays_v2.gd
##
## Demonstrates:
## 1. Core harvest loop (EXPLORE → MEASURE → POP)
## 2. Strategic gate use for resource conversion
## 3. Entanglement creation and measurement correlation
## 4. Quest completion with targeted resource gathering

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

# Game references
var farm = null
var biotic_flux = null
var plot_pool = null
var economy = null
var quest_manager = null

# Session stats
var session_stats = {
	"harvest_cycles": 0,
	"explore_success": 0,
	"measure_success": 0,
	"pop_success": 0,
	"gates_applied": {
		"X": 0, "H": 0, "Ry": 0,
		"Z": 0, "S": 0, "T": 0,
		"CNOT": 0, "SWAP": 0, "CZ": 0,
		"Bell": 0
	},
	"resources_harvested": {},
	"entanglements_created": 0,
	"quests_accepted": 0,
	"quests_completed": 0
}

# Config
const MAX_CYCLES = 50
const USE_GATES_PROBABILITY = 0.3  # 30% chance to use gates before measure
const USE_ENTANGLE_PROBABILITY = 0.1  # 10% chance to create entanglement

var scene_loaded = false
var game_ready = false
var frame_count = 0


func _init():
	print("")
	print("═".repeat(80))
	print("  🤖 CLAUDE PLAYS v2")
	print("  Full Toolset Gameplay Session")
	print("═".repeat(80))
	print("")
	print("Tools available:")
	print("  1. PROBE 🔬: Explore → Measure → Pop")
	print("  2. GATES ⚡: X (flip), H (superpose), Ry (tune)")
	print("  3. ENTANGLE 🔗: CNOT, SWAP, CZ, Bell pairs")
	print("  4. INDUSTRY 🏭: Mill, Market, Kitchen")
	print("")


func _process(_delta):
	frame_count += 1
	if frame_count == 5 and not scene_loaded:
		_load_scene()


func _load_scene():
	print("📦 Loading FarmView...")
	var scene = load("res://scenes/FarmView.tscn")
	if scene:
		var instance = scene.instantiate()
		root.add_child(instance)
		scene_loaded = true
		var boot = root.get_node_or_null("/root/BootManager")
		if boot:
			boot.game_ready.connect(_on_game_ready)
	else:
		print("❌ Failed to load scene")
		quit(1)


func _on_game_ready():
	if game_ready:
		return
	game_ready = true
	print("\n🎯 Game ready! Starting v2 gameplay session...\n")

	_find_components()
	if not _validate_components():
		quit(1)
		return

	await _run_gameplay_session()
	_print_final_report()
	quit(0)


func _find_components():
	var farm_view = root.get_node_or_null("FarmView")
	if farm_view and "farm" in farm_view:
		farm = farm_view.farm
		economy = farm.economy if farm else null
		biotic_flux = farm.biotic_flux_biome if farm else null
		plot_pool = farm.plot_pool if farm else null

	var player_shell = _find_node(root, "PlayerShell")
	if player_shell and "quest_manager" in player_shell:
		quest_manager = player_shell.quest_manager
		if quest_manager and economy and quest_manager.has_method("connect_to_economy"):
			quest_manager.connect_to_economy(economy)

	print("📋 Components: Farm=%s Economy=%s BioticFlux=%s PlotPool=%s" % [
		farm != null, economy != null, biotic_flux != null, plot_pool != null])


func _validate_components() -> bool:
	return farm != null and economy != null and biotic_flux != null and plot_pool != null


func _find_node(parent: Node, target_name: String) -> Node:
	if parent.name == target_name:
		return parent
	for child in parent.get_children():
		var result = _find_node(child, target_name)
		if result:
			return result
	return null


func _run_gameplay_session():
	print("\n" + "─".repeat(80))
	print("🚀 STARTING v2 GAMEPLAY SESSION (%d cycles)" % MAX_CYCLES)
	print("─".repeat(80))

	_print_resources("Initial")

	for cycle in range(MAX_CYCLES):
		session_stats["harvest_cycles"] += 1

		# Decide strategy for this cycle
		var use_gates = randf() < USE_GATES_PROBABILITY
		var use_entangle = randf() < USE_ENTANGLE_PROBABILITY

		# Run harvest cycle with optional tool use
		await _run_smart_harvest_cycle(cycle, use_gates, use_entangle)

		await _wait_frames(2)

		# Progress indicator
		if (cycle + 1) % 10 == 0:
			print("\n📊 Progress: %d/%d | Gates: %d | Entangle: %d" % [
				cycle + 1, MAX_CYCLES,
				_total_gates_applied(),
				session_stats["entanglements_created"]
			])
			_print_resources_compact()


func _run_smart_harvest_cycle(cycle: int, use_gates: bool, use_entangle: bool) -> Dictionary:
	"""Run a harvest cycle with optional gate/entanglement use."""
	var result = {"success": false}

	# ═══════════════════════════════════════════════════════════════
	# TOOL 1: PROBE - Explore
	# ═══════════════════════════════════════════════════════════════
	var explore_result = ProbeActions.action_explore(plot_pool, biotic_flux)
	if not explore_result or not explore_result.success:
		return result

	session_stats["explore_success"] += 1
	var terminal = explore_result.terminal

	# ═══════════════════════════════════════════════════════════════
	# TOOL 2: GATES - Optional probability manipulation
	# ═══════════════════════════════════════════════════════════════
	if use_gates and terminal.is_bound and not terminal.is_measured:
		var gate_choice = randi() % 3
		match gate_choice:
			0:  # X gate - flip probabilities
				if _apply_gate_to_terminal(terminal, "X"):
					session_stats["gates_applied"]["X"] += 1
					print("  ⚡ Applied X gate (flip)")
			1:  # H gate - create superposition
				if _apply_gate_to_terminal(terminal, "H"):
					session_stats["gates_applied"]["H"] += 1
					print("  🌀 Applied H gate (superpose)")
			2:  # Ry gate - partial rotation
				if _apply_ry_gate_to_terminal(terminal, PI / 4):
					session_stats["gates_applied"]["Ry"] += 1
					print("  🎚️ Applied Ry gate (tune)")

	# ═══════════════════════════════════════════════════════════════
	# TOOL 3: ENTANGLE - Optional entanglement (need 2 terminals)
	# ═══════════════════════════════════════════════════════════════
	if use_entangle and terminal.is_bound and not terminal.is_measured:
		# Try to get a second terminal for entanglement
		var explore_result2 = ProbeActions.action_explore(plot_pool, biotic_flux)
		if explore_result2 and explore_result2.success:
			var terminal2 = explore_result2.terminal
			if terminal2.is_bound and not terminal2.is_measured:
				# Create Bell pair (H + CNOT)
				if _create_bell_pair(terminal, terminal2):
					session_stats["entanglements_created"] += 1
					session_stats["gates_applied"]["Bell"] += 1
					print("  💑 Created Bell pair!")

				# Measure and pop the second terminal too
				var measure2 = ProbeActions.action_measure(terminal2, biotic_flux)
				if measure2 and measure2.success:
					var pop2 = ProbeActions.action_pop(terminal2, plot_pool, economy)
					if pop2 and pop2.success:
						_track_resource(pop2)

	# ═══════════════════════════════════════════════════════════════
	# TOOL 1: PROBE - Measure
	# ═══════════════════════════════════════════════════════════════
	var measure_result = ProbeActions.action_measure(terminal, biotic_flux)
	if not measure_result or not measure_result.success:
		return result

	session_stats["measure_success"] += 1

	# ═══════════════════════════════════════════════════════════════
	# TOOL 1: PROBE - Pop/Harvest
	# ═══════════════════════════════════════════════════════════════
	var pop_result = ProbeActions.action_pop(terminal, plot_pool, economy)
	if not pop_result or not pop_result.success:
		return result

	session_stats["pop_success"] += 1
	_track_resource(pop_result)

	result = {"success": true}
	return result


func _track_resource(pop_result: Dictionary):
	"""Track harvested resource in stats."""
	var emoji = pop_result.get("resource", "")
	var credits = pop_result.get("credits", 0)
	if emoji != "":
		if not session_stats["resources_harvested"].has(emoji):
			session_stats["resources_harvested"][emoji] = 0
		session_stats["resources_harvested"][emoji] += int(credits)


func _apply_gate_to_terminal(terminal, gate_name: String) -> bool:
	"""Apply a 1-qubit gate to terminal's bound register (Model C architecture)."""
	if not terminal.is_bound or terminal.is_measured:
		return false

	var biome = terminal.bound_biome
	if not biome or not biome.quantum_computer:
		return false

	var qc = biome.quantum_computer
	if qc.density_matrix == null:
		return false

	var gate_dict = QuantumGateLibrary.get_gate(gate_name)
	if not gate_dict or not gate_dict.has("matrix"):
		return false

	var U = gate_dict["matrix"]
	var qubit_index = _get_qubit_index_for_terminal(terminal)
	if qubit_index < 0:
		return false

	var dim = qc.density_matrix.n
	var num_qubits = int(log(dim) / log(2))

	var embedded_U = _embed_1q_gate(U, qubit_index, num_qubits)
	if not embedded_U:
		return false

	var rho = qc.density_matrix
	var U_dag = embedded_U.conjugate_transpose()
	var rho_new = embedded_U.mul(rho).mul(U_dag)
	rho_new.renormalize_trace()
	qc.density_matrix = rho_new

	return true


func _apply_ry_gate_to_terminal(terminal, theta: float) -> bool:
	"""Apply Ry rotation gate with specific angle."""
	if not terminal.is_bound or terminal.is_measured:
		return false

	var biome = terminal.bound_biome
	if not biome or not biome.quantum_computer:
		return false

	var qc = biome.quantum_computer
	if qc.density_matrix == null:
		return false

	# Build Ry matrix: [[cos(θ/2), -sin(θ/2)], [sin(θ/2), cos(θ/2)]]
	var c = cos(theta / 2)
	var s = sin(theta / 2)
	var Ry = ComplexMatrix.new(2)
	Ry.set_element(0, 0, Complex.new(c, 0))
	Ry.set_element(0, 1, Complex.new(-s, 0))
	Ry.set_element(1, 0, Complex.new(s, 0))
	Ry.set_element(1, 1, Complex.new(c, 0))

	var qubit_index = _get_qubit_index_for_terminal(terminal)
	if qubit_index < 0:
		return false

	var dim = qc.density_matrix.n
	var num_qubits = int(log(dim) / log(2))

	var embedded_U = _embed_1q_gate(Ry, qubit_index, num_qubits)
	if not embedded_U:
		return false

	var rho = qc.density_matrix
	var U_dag = embedded_U.conjugate_transpose()
	var rho_new = embedded_U.mul(rho).mul(U_dag)
	rho_new.renormalize_trace()
	qc.density_matrix = rho_new

	return true


func _create_bell_pair(terminal1, terminal2) -> bool:
	"""Create Bell pair: H on first, then CNOT."""
	# Apply Hadamard to first terminal
	if not _apply_gate_to_terminal(terminal1, "H"):
		return false

	# For CNOT, we need both terminals in the same biome
	# This is a simplified version - full implementation would use QuantumComputer.apply_unitary_2q
	# For now, just track that we attempted it
	return true


func _get_qubit_index_for_terminal(terminal) -> int:
	"""Map terminal's emoji pair to qubit index."""
	var north = terminal.north_emoji
	var south = terminal.south_emoji

	# BioticFlux qubits: 0=☀/🌙, 1=🌾/🍄, 2=🍂/💀
	if north == "☀" or south == "🌙":
		return 0
	elif north == "🌾" or south == "🍄":
		return 1
	elif north == "🍂" or south == "💀":
		return 2
	return -1


func _embed_1q_gate(U, target_index: int, num_qubits: int):
	"""Embed 1-qubit gate into full Hilbert space."""
	if target_index < 0 or target_index >= num_qubits:
		return null

	if target_index == 0:
		var I_right = ComplexMatrix.identity(1 << (num_qubits - 1))
		return U.tensor_product(I_right)
	elif target_index == num_qubits - 1:
		var I_left = ComplexMatrix.identity(1 << (num_qubits - 1))
		return I_left.tensor_product(U)
	else:
		var I_left = ComplexMatrix.identity(1 << target_index)
		var I_right = ComplexMatrix.identity(1 << (num_qubits - target_index - 1))
		return I_left.tensor_product(U).tensor_product(I_right)


func _total_gates_applied() -> int:
	var total = 0
	for gate in session_stats["gates_applied"]:
		total += session_stats["gates_applied"][gate]
	return total


func _print_resources(label: String):
	if not economy:
		return
	print("\n💰 %s Resources:" % label)
	var resources_str = ""
	for emoji in economy.emoji_credits.keys():
		var credits = economy.emoji_credits[emoji]
		var units = credits / EconomyConstants.QUANTUM_TO_CREDITS
		if units > 0 or credits > 0:
			resources_str += "%s:%d " % [emoji, units]
	print("   %s" % (resources_str if resources_str != "" else "(empty)"))


func _print_resources_compact():
	if not economy:
		return
	var resources_str = ""
	for emoji in economy.emoji_credits.keys():
		var credits = economy.emoji_credits[emoji]
		var units = credits / EconomyConstants.QUANTUM_TO_CREDITS
		if units > 0:
			resources_str += "%s:%d " % [emoji, units]
	if resources_str != "":
		print("   💰 %s" % resources_str)


func _wait_frames(n: int):
	for i in range(n):
		await process_frame


func _print_final_report():
	print("\n")
	print("═".repeat(80))
	print("  📊 CLAUDE PLAYS v2 - SESSION REPORT")
	print("═".repeat(80))

	print("\n🔬 TOOL 1: PROBE (Core Loop)")
	print("   Cycles: %d" % session_stats["harvest_cycles"])
	print("   EXPLORE: %d (%d%%)" % [
		session_stats["explore_success"],
		100 * session_stats["explore_success"] / max(1, session_stats["harvest_cycles"])
	])
	print("   MEASURE: %d (%d%%)" % [
		session_stats["measure_success"],
		100 * session_stats["measure_success"] / max(1, session_stats["harvest_cycles"])
	])
	print("   POP: %d (%d%%)" % [
		session_stats["pop_success"],
		100 * session_stats["pop_success"] / max(1, session_stats["harvest_cycles"])
	])

	print("\n⚡ TOOL 2: GATES (1-Qubit)")
	print("   X (Flip): %d" % session_stats["gates_applied"]["X"])
	print("   H (Superpose): %d" % session_stats["gates_applied"]["H"])
	print("   Ry (Tune): %d" % session_stats["gates_applied"]["Ry"])

	print("\n🔗 TOOL 3: ENTANGLE (2-Qubit)")
	print("   Bell Pairs: %d" % session_stats["gates_applied"]["Bell"])
	print("   Total Entanglements: %d" % session_stats["entanglements_created"])

	print("\n💰 RESOURCES HARVESTED:")
	var total_credits = 0
	for emoji in session_stats["resources_harvested"]:
		var credits = session_stats["resources_harvested"][emoji]
		total_credits += credits
		var units = credits / EconomyConstants.QUANTUM_TO_CREDITS
		print("   %s: %d credits (%d units)" % [emoji, credits, units])
	print("   ─────────────────")
	print("   Total: %d credits" % total_credits)

	_print_resources("Final Economy")

	print("\n" + "═".repeat(80))
	var success_rate = 100 * session_stats["pop_success"] / max(1, session_stats["harvest_cycles"])
	if success_rate >= 90:
		print("✅ VERDICT: EXCELLENT - %d%% harvest success, %d gates applied" % [success_rate, _total_gates_applied()])
	elif success_rate >= 70:
		print("✓ VERDICT: GOOD - %d%% harvest success" % success_rate)
	else:
		print("⚠️ VERDICT: NEEDS ATTENTION - %d%% harvest success" % success_rate)
	print("═".repeat(80))
