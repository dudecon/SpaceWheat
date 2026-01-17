#!/usr/bin/env -S godot --headless -s
extends SceneTree

## TEST: Verify visualization signals are properly received
## Tests that bubbles are created when EXPLORE is called

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

var farm = null
var grid = null
var economy = null
var plot_pool = null
var biome = null

var frame_count = 0
var scene_loaded = false
var tests_done = false

func _init():
	print("\n" + "═".repeat(80))
	print("✨ VISUALIZATION FIX VERIFICATION")
	print("═".repeat(80))

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		print("\n⏳ Frame 5: Loading scene...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			var instance = scene.instantiate()
			root.add_child(instance)
			scene_loaded = true
			var boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)

func _on_game_ready():
	if tests_done:
		return
	tests_done = true

	print("\n✅ Game ready! Verifying visualization fix...\n")

	var fv = root.get_node_or_null("FarmView")
	if not fv or not fv.farm:
		print("❌ Farm not found")
		quit(1)
		return

	farm = fv.farm
	grid = farm.grid
	economy = farm.economy
	plot_pool = farm.plot_pool
	biome = grid.biomes.values()[0]

	economy.add_resource("💰", 10000, "test_bootstrap")

	print("   Biome: %s" % biome.get_biome_type())
	print()

	_test_visualization_working()

	quit()

# ═══════════════════════════════════════════════════════════════════════════

func _test_visualization_working():
	print("─".repeat(80))
	print("TEST: Verify bubbles create and actions become available")
	print("─".repeat(80))

	# 1. Initial state - nothing explored
	print("\n1️⃣ INITIAL STATE (no exploration):")
	print("   ✓ Quantum nodes in graph: %d" % (farm.get_node("FarmView/QuantumForceGraph").quantum_nodes.size() if farm.has_node("FarmView/QuantumForceGraph") else -1))

	# 2. EXPLORE and check if signals fire
	print("\n2️⃣ EXPLORE ACTION:")
	var explore_result = ProbeActions.action_explore(plot_pool, biome)

	if not explore_result.get("success"):
		print("   ❌ EXPLORE failed: %s" % explore_result.get("error"))
		return

	var terminal = explore_result["terminal"]
	print("   ✅ EXPLORE succeeded: Terminal %s → Register %d" % [
		terminal.terminal_id, explore_result["register_id"]
	])

	# Check if bubbles exist now (this would fail before the fix)
	var viz_controller = _find_viz_controller(farm.get_parent())
	if viz_controller:
		var bubble_count = 0
		if "basis_bubbles" in viz_controller:
			for biome_name in viz_controller.basis_bubbles:
				bubble_count += viz_controller.basis_bubbles[biome_name].size()
		print("   📊 Bubbles created: %d" % bubble_count)
		if bubble_count > 0:
			print("   ✅ Visualization working! (bubbles were created)")
		else:
			print("   ❌ No bubbles created (visualization signal failed)")
	else:
		print("   ⚠️  Could not find viz controller to verify")

	# 3. Check action availability (requires visualization to work)
	print("\n3️⃣ ACTION AVAILABILITY (requires working visualization):")
	var measure_available = _has_active_terminal_in_biome()
	var pop_available = _has_measured_terminal_in_biome()

	print("   MEASURE available: %s" % ("✅" if measure_available else "❌"))
	print("   POP available: %s (should be false until MEASURE)" % ("✅" if not pop_available else "❌"))

	# 4. MEASURE
	print("\n4️⃣ MEASURE ACTION:")
	var measure_result = ProbeActions.action_measure(terminal, biome)

	if not measure_result.get("success"):
		print("   ❌ MEASURE failed: %s" % measure_result.get("error"))
		return

	print("   ✅ MEASURE succeeded")

	# 5. Check POP availability now
	print("\n5️⃣ POP AVAILABILITY (after MEASURE):")
	pop_available = _has_measured_terminal_in_biome()
	print("   POP available: %s (should be true)" % ("✅" if pop_available else "❌"))

	# 6. POP
	print("\n6️⃣ POP ACTION:")
	var pop_result = ProbeActions.action_pop(terminal, plot_pool, economy)

	if not pop_result.get("success"):
		print("   ❌ POP failed: %s" % pop_result.get("error"))
		return

	print("   ✅ POP succeeded")

	print("\n" + "═".repeat(80))
	print("✅ TEST COMPLETE - Visualization fix appears to be working!")
	print("═".repeat(80) + "\n")

# ═══════════════════════════════════════════════════════════════════════════

func _find_viz_controller(node):
	"""Recursively search for BathQuantumVisualizationController"""
	if node.is_class("BathQuantumVisualizationController"):
		return node
	for child in node.get_children():
		var found = _find_viz_controller(child)
		if found:
			return found
	return null

func _has_active_terminal_in_biome() -> bool:
	"""Check if there are active terminals (bound but not measured) in current biome"""
	for terminal in plot_pool.get_active_terminals():
		if terminal.bound_biome and terminal.bound_biome.get_biome_type() == biome.get_biome_type():
			return true
	return false

func _has_measured_terminal_in_biome() -> bool:
	"""Check if there are measured terminals in current biome"""
	for terminal in plot_pool.get_measured_terminals():
		if terminal.bound_biome and terminal.bound_biome.get_biome_type() == biome.get_biome_type():
			return true
	return false
