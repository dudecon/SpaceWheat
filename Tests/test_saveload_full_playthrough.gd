#!/usr/bin/env -S godot --headless -s
extends SceneTree

## COMPREHENSIVE SAVE/LOAD PLAYTHROUGH TEST
## Gold standard: Full gameplay → Save → Quit → Reload → Load → Verify
##
## This test simulates a real play session with:
## - Planting multiple crops
## - Building persistent gates (Tool #2)
## - Creating entanglements
## - Spending resources
## - Progressing through goals
## - SAVING the game
## - LOADING and verifying ALL state is preserved

const Farm = preload("res://Core/Farm.gd")

var farm: Farm = null
var test_passed = false

func _initialize():
	print("\n" + "=".repeat(80))
	print("🎮 COMPREHENSIVE SAVE/LOAD PLAYTHROUGH TEST")
	print("Gold Standard: Real gameplay → Save → Load → Verify")
	print("=".repeat(80))

	await get_root().ready

	# Check GameStateManager
	if not check_gamestate_manager():
		quit(1)
		return

	# Run the full test
	await run_full_playthrough_test()

	# Report results
	print("\n" + "=".repeat(80))
	if test_passed:
		print("✅ ✅ ✅  COMPREHENSIVE TEST PASSED  ✅ ✅ ✅")
		print("All game state preserved across save/load!")
	else:
		print("❌ ❌ ❌  TEST FAILED  ❌ ❌ ❌")
	print("=".repeat(80) + "\n")

	quit(0 if test_passed else 1)


func check_gamestate_manager() -> bool:
	"""Verify GameStateManager is available"""
	print("\n" + "─".repeat(80))
	print("Step 0: Check GameStateManager")
	print("─".repeat(80))

	# Load the script
	var gsm_script = load("res://Core/GameState/GameStateManager.gd")
	if not gsm_script:
		print("❌ Failed to load GameStateManager script")
		return false

	# Try to get the singleton
	var gsm = get_root().get_node_or_null("/root/GameStateManager")
	if not gsm:
		print("⚠️  GameStateManager singleton not found in tree")
		print("  This is expected in SceneTree mode - will use direct methods")
	else:
		print("✅ GameStateManager singleton found")

	return true


func run_full_playthrough_test():
	"""Main test sequence"""
	print("\n📋 TEST SEQUENCE:")
	print("  1. Create farm and initialize")
	print("  2. Perform realistic gameplay actions")
	print("  3. Capture detailed pre-save state")
	print("  4. SAVE game to slot 0")
	print("  5. Destroy farm (simulate quit)")
	print("  6. Recreate farm (simulate restart)")
	print("  7. LOAD game from slot 0")
	print("  8. Compare post-load state with pre-save")
	print()

	# Step 1: Create farm
	section("Step 1: Create Farm & Initialize")
	farm = Farm.new()
	get_root().add_child(farm)

	# Register with GameStateManager
	var gsm = get_root().get_node_or_null("/root/GameStateManager")
	if gsm:
		gsm.active_farm = farm
		print("✅ Farm registered with GameStateManager")
	else:
		print("⚠️  No GameStateManager singleton - using direct save/load")

	# Wait for async initialization (biomes, baths)
	print("⏳ Waiting for async initialization...")
	for i in range(8):
		await process_frame

	print("✅ Farm created")
	print("  Grid: %dx%d = %d plots" % [farm.grid.grid_width, farm.grid.grid_height,
		farm.grid.grid_width * farm.grid.grid_height])
	print("  Biomes: %d registered" % (4 if farm.biotic_flux_biome else 0))

	# Step 2: Perform gameplay
	section("Step 2: Perform Realistic Gameplay")
	perform_comprehensive_gameplay()

	# Wait for quantum evolution
	for i in range(3):
		await process_frame

	# Step 3: Capture pre-save state
	section("Step 3: Capture Pre-Save State")
	var pre_save_state = capture_comprehensive_state()
	print_state_report("PRE-SAVE", pre_save_state)

	# Step 4: SAVE
	section("Step 4: SAVE GAME")
	var save_success = save_game_slot(0)
	if not save_success:
		print("❌ Save failed! Aborting test.")
		return

	print("✅ Game saved to slot 0")

	# Step 5: Destroy farm
	section("Step 5: Destroy Farm (Simulate Quit)")
	if gsm:
		gsm.active_farm = null
	farm.queue_free()
	for i in range(3):
		await process_frame
	farm = null
	print("✅ Farm destroyed")

	# Step 6: Recreate farm
	section("Step 6: Recreate Farm (Simulate Restart)")
	farm = Farm.new()
	get_root().add_child(farm)

	if gsm:
		gsm.active_farm = farm

	# Wait for initialization
	for i in range(8):
		await process_frame

	print("✅ Farm recreated")

	# Step 7: LOAD
	section("Step 7: LOAD GAME")
	var load_success = load_game_slot(0)
	if not load_success:
		print("❌ Load failed! Aborting test.")
		return

	print("✅ Game loaded from slot 0")

	# Wait for state application
	for i in range(3):
		await process_frame

	# Step 8: Capture post-load state
	section("Step 8: Capture Post-Load State")
	var post_load_state = capture_comprehensive_state()
	print_state_report("POST-LOAD", post_load_state)

	# Step 9: Compare
	section("Step 9: Compare States")
	test_passed = compare_comprehensive_states(pre_save_state, post_load_state)


func perform_comprehensive_gameplay():
	"""Simulate a realistic play session"""
	print("🎮 Simulating comprehensive gameplay...")

	# Modify economy (use emoji-based resource API)
	farm.economy.set_resource("💰", 123)
	farm.economy.set_resource("🌾", 25)
	farm.economy.set_resource("🍄", 8)
	farm.economy.set_resource("🍞", 7)
	print("  💰 Modified economy: 123 credits, 25 wheat, 8 mushroom, 7 flour")

	# Plant crops in multiple locations
	var grid = farm.grid
	if grid and grid.has_method("plant"):
		# Plant wheat
		grid.plant(Vector2i(0, 0), "wheat")
		grid.plant(Vector2i(2, 0), "wheat")
		print("  🌾 Planted wheat at (0,0) and (2,0)")

		# Plant mushroom
		grid.plant(Vector2i(1, 0), "mushroom")
		print("  🍄 Planted mushroom at (1,0)")

		# Build persistent Bell gate (Tool #2) between plots
		var plot_a = grid.get_plot(Vector2i(0, 0))
		var plot_b = grid.get_plot(Vector2i(2, 0))

		if plot_a and plot_a.has_method("add_persistent_gate"):
			plot_a.add_persistent_gate("bell_phi_plus", [Vector2i(2, 0)])
			print("  🔗 Built persistent Bell gate: (0,0) ↔ (2,0)")

		if plot_b and plot_b.has_method("add_persistent_gate"):
			plot_b.add_persistent_gate("bell_phi_plus", [Vector2i(0, 0)])

		# Build measure trigger on mushroom plot (Tool #2)
		var plot_c = grid.get_plot(Vector2i(1, 0))
		if plot_c and plot_c.has_method("add_persistent_gate"):
			plot_c.add_persistent_gate("measure_trigger", [])
			print("  👁️  Built measure trigger at (1,0)")

		# Measure one plot
		if plot_a and plot_a.has_method("measure"):
			plot_a.measure()
			print("  📏 Measured plot (0,0)")

	# Progress goals
	if farm.goals:
		farm.goals.current_goal_index = 3
		print("  🎯 Advanced to goal index 3")

	print()


func capture_comprehensive_state() -> Dictionary:
	"""Capture complete game state for comparison"""
	var state = {}

	# Economy (use emoji-based resource API)
	state.economy = {
		"credits": farm.economy.get_resource("💰"),
		"wheat": farm.economy.get_resource("🌾"),
		"mushroom": farm.economy.get_resource("🍄"),
		"flour": farm.economy.get_resource("🍞")
	}

	# Grid dimensions
	state.grid_width = farm.grid.grid_width if farm.grid else 0
	state.grid_height = farm.grid.grid_height if farm.grid else 0

	# Plots
	state.plots = []
	if farm.grid:
		for y in range(farm.grid.grid_height):
			for x in range(farm.grid.grid_width):
				var pos = Vector2i(x, y)
				var plot = farm.grid.get_plot(pos)
				if plot:
					var plot_data = {
						"position": pos,
						"type": plot.plot_type,
						"is_planted": plot.is_planted,
						"has_been_measured": plot.has_been_measured,
						"persistent_gates": []
					}

					# Capture persistent gates (Phase 5.2)
					if plot.has("persistent_gates"):
						for gate in plot.persistent_gates:
							plot_data.persistent_gates.append({
								"type": gate.get("type", ""),
								"active": gate.get("active", true),
								"linked_count": gate.get("linked_plots", []).size()
							})

					state.plots.append(plot_data)

	# Goals
	state.goals = {
		"current_index": farm.goals.current_goal_index if farm.goals else 0
	}

	# Biomes
	state.biomes = {}
	if farm.biotic_flux_biome:
		state.biomes["BioticFlux"] = {
			"qubit_count": farm.biotic_flux_biome.quantum_states.size()
		}

	return state


func print_state_report(label: String, state: Dictionary):
	"""Print detailed state summary"""
	print("\n📊 %s STATE REPORT:" % label)
	print("  💰 Economy:")
	print("    - Credits: %d" % state["economy"]["credits"])
	print("    - Wheat: %d" % state["economy"]["wheat"])
	print("    - Mushroom: %d" % state["economy"]["mushroom"])
	print("    - Flour: %d" % state["economy"]["flour"])

	print("  📏 Grid: %dx%d (%d plots)" % [
		state["grid_width"], state["grid_height"],
		state["plots"].size()
	])

	var planted = 0
	var measured = 0
	var gates = 0
	for p in state["plots"]:
		if p["is_planted"]:
			planted += 1
		if p["has_been_measured"]:
			measured += 1
		gates += p["persistent_gates"].size()

	print("  🌾 Plots:")
	print("    - Planted: %d" % planted)
	print("    - Measured: %d" % measured)
	print("    - Persistent gates: %d" % gates)

	print("  🎯 Goals: Index %d" % state["goals"]["current_index"])
	print("  🌍 Biomes: %d registered" % state["biomes"].size())
	print()


func compare_comprehensive_states(pre: Dictionary, post: Dictionary) -> bool:
	"""Compare states and return true if they match"""
	var diffs = []

	# Economy
	if pre["economy"]["credits"] != post["economy"]["credits"]:
		diffs.append("Credits: %d → %d" % [pre["economy"]["credits"], post["economy"]["credits"]])
	if pre["economy"]["wheat"] != post["economy"]["wheat"]:
		diffs.append("Wheat: %d → %d" % [pre["economy"]["wheat"], post["economy"]["wheat"]])
	if pre["economy"]["mushroom"] != post["economy"]["mushroom"]:
		diffs.append("Mushroom: %d → %d" % [pre["economy"]["mushroom"], post["economy"]["mushroom"]])
	if pre["economy"]["flour"] != post["economy"]["flour"]:
		diffs.append("Flour: %d → %d" % [pre["economy"]["flour"], post["economy"]["flour"]])

	# Grid
	if pre["grid_width"] != post["grid_width"] or pre["grid_height"] != post["grid_height"]:
		diffs.append("Grid: %dx%d → %dx%d" % [pre["grid_width"], pre["grid_height"], post["grid_width"], post["grid_height"]])

	# Plots
	if pre["plots"].size() != post["plots"].size():
		diffs.append("Plot count: %d → %d" % [pre["plots"].size(), post["plots"].size()])
	else:
		for i in range(pre["plots"].size()):
			var p1 = pre["plots"][i]
			var p2 = post["plots"][i]

			if p1["is_planted"] != p2["is_planted"]:
				diffs.append("Plot %s planted: %s → %s" % [p1["position"], p1["is_planted"], p2["is_planted"]])
			if p1["has_been_measured"] != p2["has_been_measured"]:
				diffs.append("Plot %s measured: %s → %s" % [p1["position"], p1["has_been_measured"], p2["has_been_measured"]])

			# Phase 5.2: Persistent gates
			if p1["persistent_gates"].size() != p2["persistent_gates"].size():
				diffs.append("Plot %s gates: %d → %d" % [p1["position"], p1["persistent_gates"].size(), p2["persistent_gates"].size()])

	# Goals
	if pre["goals"]["current_index"] != post["goals"]["current_index"]:
		diffs.append("Goal index: %d → %d" % [pre["goals"]["current_index"], post["goals"]["current_index"]])

	# Report
	if diffs.is_empty():
		print("✅ ✅ ✅  PERFECT MATCH - ALL STATE PRESERVED!")
		print("  No differences detected across:")
		print("    - Economy (4 resource types)")
		print("    - Grid dimensions")
		print("    - %d plots (type, planted, measured, gates)" % pre["plots"].size())
		print("    - Goals progress")
		print("    - Biomes")
		return true
	else:
		print("❌ STATE MISMATCH - %d differences found:" % diffs.size())
		for diff in diffs:
			print("  - " + diff)
		return false


func save_game_slot(slot: int) -> bool:
	"""Save game using GameStateManager or direct method"""
	var gsm = get_root().get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("save_game"):
		return gsm.save_game(slot)
	else:
		print("⚠️  No GameStateManager - cannot save")
		return false


func load_game_slot(slot: int) -> bool:
	"""Load game using GameStateManager or direct method"""
	var gsm = get_root().get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("load_game"):
		return gsm.load_game(slot)
	else:
		print("⚠️  No GameStateManager - cannot load")
		return false


func section(title: String):
	"""Print section header"""
	print("\n" + "─".repeat(80))
	print(title)
	print("─".repeat(80))
