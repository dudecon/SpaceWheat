#!/usr/bin/env -S godot --headless -s
extends SceneTree

## TEST: Visualization signal flow
## Traces whether plot_planted and plot_harvested signals properly reach visualization

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

var farm = null
var grid = null
var economy = null
var plot_pool = null
var biome = null
var viz_controller = null

var frame_count = 0
var scene_loaded = false
var tests_done = false

func _init():
	print("\n" + "═".repeat(80))
	print("🎬 VISUALIZATION SIGNAL FLOW TEST")
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

	print("\n✅ Game ready! Testing visualization signal flow...\n")

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

	# Find the visualization controller
	viz_controller = _find_viz_controller(fv)
	if not viz_controller:
		print("⚠️  Could not find visualization controller")

	economy.add_resource("💰", 10000, "test_bootstrap")

	print("   Biome: %s" % biome.get_biome_type())
	print()

	_test_visualization_flow()

	quit()

# ═══════════════════════════════════════════════════════════════════════════

func _test_visualization_flow():
	print("─".repeat(80))
	print("TEST: Signal flow for EXPLORE → MEASURE → POP")
	print("─".repeat(80))

	# 1. Check signal connections
	print("\n1️⃣ CHECKING SIGNAL CONNECTIONS:")
	print("   plot_planted signal exists: %s" % farm.has_signal("plot_planted"))
	print("   plot_harvested signal exists: %s" % farm.has_signal("plot_harvested"))

	# Count connections manually
	var plot_planted_connections = _count_signal_connections(farm, "plot_planted")
	var plot_harvested_connections = _count_signal_connections(farm, "plot_harvested")

	print("   plot_planted connections: %d" % plot_planted_connections)
	print("   plot_harvested connections: %d" % plot_harvested_connections)

	# 2. Test EXPLORE with signal tracing
	print("\n2️⃣ TESTING EXPLORE (should emit plot_planted):")
	var explore_result = ProbeActions.action_explore(plot_pool, biome)

	if not explore_result.get("success"):
		print("   ❌ EXPLORE failed: %s" % explore_result.get("error"))
		return

	var terminal = explore_result["terminal"]
	var terminal_pos = Vector2i(2, 0)  # Hardcode a position for testing

	print("   ✅ EXPLORE succeeded: Terminal %s → Register %d" % [
		terminal.terminal_id, explore_result["register_id"]
	])

	# 3. Manually emit plot_planted to test handler
	print("\n3️⃣ MANUALLY EMITTING plot_planted signal:")
	print("   Calling: farm.plot_planted.emit(%s, '%s')" % [terminal_pos, "🌾"])
	farm.plot_planted.emit(terminal_pos, "🌾")
	print("   ✅ Signal emitted")

	# 4. Check if viz controller got it
	if viz_controller and viz_controller.has_method("request_plot_bubble"):
		print("   Viz controller has request_plot_bubble method")

	# 5. Test MEASURE
	print("\n4️⃣ TESTING MEASURE:")
	var measure_result = ProbeActions.action_measure(terminal, biome)

	if not measure_result.get("success"):
		print("   ❌ MEASURE failed: %s" % measure_result.get("error"))
		return

	print("   ✅ MEASURE succeeded")

	# 6. Test POP with signal tracing
	print("\n5️⃣ TESTING POP (should emit plot_harvested):")
	var pop_result = ProbeActions.action_pop(terminal, plot_pool, economy)

	if not pop_result.get("success"):
		print("   ❌ POP failed: %s" % pop_result.get("error"))
		return

	print("   ✅ POP succeeded")

	# 7. Manually emit plot_harvested
	print("\n6️⃣ MANUALLY EMITTING plot_harvested signal:")
	print("   Calling: farm.plot_harvested.emit(%s, {{}})" % terminal_pos)
	farm.plot_harvested.emit(terminal_pos, {})
	print("   ✅ Signal emitted")

	print("\n" + "═".repeat(80))
	print("Test complete - check logs above for signal reception")
	print("═".repeat(80) + "\n")

# ═══════════════════════════════════════════════════════════════════════════

func _find_viz_controller(root_node):
	"""Recursively search for BathQuantumVisualizationController"""
	if root_node.is_class("BathQuantumVisualizationController"):
		return root_node

	for child in root_node.get_children():
		var found = _find_viz_controller(child)
		if found:
			return found

	return null

func _count_signal_connections(obj, signal_name: String) -> int:
	"""Count how many handlers are connected to a signal"""
	# This is a rough count based on get_signal_connection_list
	if obj.has_signal(signal_name):
		var connections = obj.get_signal_connection_list(signal_name)
		return connections.size()
	return 0
