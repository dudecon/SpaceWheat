extends Node

## ⚠️ OUT OF SYNC WITH V2 ARCHITECTURE ⚠️
## This uses the OLD Plot-based API (farm.build, farm.measure_plot, farm.harvest_plot)
## The v2 architecture uses Terminals via ProbeActions (action_explore, action_measure, action_pop)
## DO NOT USE - needs rewrite to use ProbeActions + Terminal system
##
# KeyboardPlayer - AI that plays SpaceWheat using keyboard controls
# Simulates real player input to test the game

signal action_completed(action, result)

var farm: Node = null
var current_strategy: String = "tutorial"  # tutorial, quest_hunter, optimizer
var action_queue: Array = []
var time_since_last_action: float = 0.0
var action_cooldown: float = 0.3  # Wait 0.3s between actions - faster gameplay!

# Game state tracking
var planted_plots: Array[Vector2i] = []
var measured_plots: Array[Vector2i] = []
var available_positions: Array[Vector2i] = []

# Stats tracking
var actions_taken: int = 0
var wheat_harvested: int = 0
var quests_completed: int = 0

func _ready():
	print("\n⌨️  KeyboardPlayer initialized")
	print("   Strategy: %s" % current_strategy)

	# Wait for farm to initialize
	await get_tree().create_timer(0.5).timeout

	# Find farm
	farm = _find_farm()
	if not farm:
		print("❌ ERROR: Could not find Farm")
		return

	print("   ✅ Found farm")

	# Scan available plot positions
	_scan_grid()

	print("   📊 Grid: %dx%d = %d plots" % [
		farm.grid.grid_width,
		farm.grid.grid_height,
		available_positions.size()
	])
	print("   💰 Starting wheat: %d credits\n" % farm.economy.get_resource("🌾"))

	# Start playing!
	set_process(true)
	print("🎮 Starting keyboard-driven gameplay!\n")

func _process(delta):
	time_since_last_action += delta

	# Execute actions at regular intervals
	if time_since_last_action >= action_cooldown:
		_decide_next_action()
		time_since_last_action = 0.0

func _decide_next_action():
	# AI decision making - what should I do next?

	match current_strategy:
		"tutorial":
			_tutorial_strategy()
		"quest_hunter":
			_quest_hunter_strategy()
		"optimizer":
			_optimizer_strategy()

func _tutorial_strategy():
	# Simple tutorial: Plant → Wait → Measure → Harvest → Repeat

	# Step 1: Plant wheat on empty plots
	var empty_plot = _find_empty_plot()
	if empty_plot != Vector2i(-1, -1):
		if farm.economy.get_resource("🌾") >= 10:
			_action_plant(empty_plot, "wheat")
			return
		else:
			print("💰 Not enough wheat to plant (need 10 credits)")

	# Step 2: Measure plots that have been planted but not measured
	var unmeasured = _find_unmeasured_plot()
	if unmeasured != Vector2i(-1, -1):
		_action_measure(unmeasured)
		return

	# Step 3: Harvest measured plots
	var measured = _find_measured_plot()
	if measured != Vector2i(-1, -1):
		_action_harvest(measured)
		return

	# Nothing to do - wait
	print("⏸️  [Tutorial] Nothing to do, waiting...")
	print("   Planted: %d, Measured: %d" % [planted_plots.size(), measured_plots.size()])

func _quest_hunter_strategy():
	# Focus on completing active quests
	# TODO: Implement quest-focused strategy
	# - Read quest objectives
	# - Manipulate quantum states to match objectives
	# - Complete quests efficiently
	pass

func _optimizer_strategy():
	# Optimize for maximum resource generation
	# TODO: Implement optimizer strategy
	# - Calculate expected values
	# - Choose high-yield crops
	# - Maximize throughput
	pass

# =============================================================================
# ACTIONS - Keyboard Input Simulation
# =============================================================================

func _action_plant(pos: Vector2i, plant_type: String):
	# Simulate planting via keyboard (P key + position selection)
	print("\n🌱 [Action %d] PLANT %s at %s" % [actions_taken, plant_type, pos])

	var wheat_before = farm.economy.get_resource("🌾")
	var success = farm.build(pos, plant_type)

	if success:
		var wheat_after = farm.economy.get_resource("🌾")
		planted_plots.append(pos)
		actions_taken += 1

		print("   ✅ Planted successfully")
		print("   💰 Wheat: %d → %d (cost: %d)" % [
			wheat_before, wheat_after, wheat_before - wheat_after
		])

		# Check quantum state
		var plot = farm.grid.get_plot(pos)
		if plot and plot.quantum_state:
			# Check if this is legacy DualEmojiQubit or bath-first ProjectionQubit
			if plot.quantum_state.get("north_pole") != null and plot.quantum_state.get("south_pole") != null:
				print("   ⚛️  Quantum state created: %s ↔ %s" % [
					plot.quantum_state.north_pole,
					plot.quantum_state.south_pole
				])
			else:
				print("   ⚛️  Quantum state created (bath-first mode)")

		action_completed.emit("plant", {"success": true, "position": pos})
	else:
		print("   ❌ Failed to plant")
		action_completed.emit("plant", {"success": false, "position": pos})

func _action_measure(pos: Vector2i):
	# Simulate measurement via keyboard (M key)
	print("\n📏 [Action %d] MEASURE at %s" % [actions_taken, pos])

	# Check plot state before measurement (bath-first mode)
	var plot = farm.grid.get_plot(pos)
	if plot and plot.quantum_state:
		print("   ⚛️  Before: radius=%.3f, energy=%.3f" % [plot.quantum_state.radius, plot.quantum_state.energy])

	var outcome = farm.measure_plot(pos)

	if outcome:
		measured_plots.append(pos)
		planted_plots.erase(pos)
		actions_taken += 1

		print("   ✅ Measured: %s" % outcome)
		action_completed.emit("measure", {"success": true, "outcome": outcome})
	else:
		print("   ❌ Failed to measure")
		action_completed.emit("measure", {"success": false})

func _action_harvest(pos: Vector2i):
	# Simulate harvest via keyboard (H key)
	print("\n🚜 [Action %d] HARVEST at %s" % [actions_taken, pos])

	var wheat_before = farm.economy.get_resource("🌾")
	var result = farm.harvest_plot(pos)

	if result.get("success", false):
		var wheat_after = farm.economy.get_resource("🌾")
		measured_plots.erase(pos)
		actions_taken += 1

		if result.get("outcome") == "🌾":
			wheat_harvested += 1

		print("   ✅ Harvested: %s" % result.get("outcome"))
		print("   ⚡ Yield: %d credits" % result.get("yield", 0))
		print("   💰 Wheat: %d → %d (gain: %d)" % [
			wheat_before, wheat_after, wheat_after - wheat_before
		])

		action_completed.emit("harvest", {"success": true, "outcome": result.get("outcome")})
	else:
		print("   ❌ Failed to harvest")
		action_completed.emit("harvest", {"success": false})

func _action_wait(duration: float):
	# Wait for quantum evolution
	print("\n⏳ [Action %d] WAIT %.1fs for evolution..." % [actions_taken, duration])
	action_cooldown = duration
	actions_taken += 1

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _scan_grid():
	# Scan all grid positions
	available_positions.clear()

	for y in range(farm.grid.grid_height):
		for x in range(farm.grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot:
				available_positions.append(pos)

func _find_empty_plot() -> Vector2i:
	# Find first empty plot
	for pos in available_positions:
		var plot = farm.grid.get_plot(pos)
		if plot and not plot.is_planted:
			return pos
	return Vector2i(-1, -1)

func _find_unmeasured_plot() -> Vector2i:
	# Find plot that's planted but not measured
	for pos in planted_plots:
		var plot = farm.grid.get_plot(pos)
		if plot:
			# Debug: Check plot state
			if plot.is_planted and not plot.has_been_measured:
				return pos
		else:
			print("   ⚠️  Plot at %s not found" % pos)
	return Vector2i(-1, -1)

func _find_measured_plot() -> Vector2i:
	# Find plot that's been measured and ready to harvest
	for pos in measured_plots:
		var plot = farm.grid.get_plot(pos)
		if plot and plot.is_planted and plot.has_been_measured:
			return pos
	return Vector2i(-1, -1)

func _find_farm() -> Node:
	# Find Farm node in scene tree
	return _find_node_by_class(get_tree().root, "Farm")

func _find_node_by_class(node: Node, target_class: String) -> Node:
	# Recursively find node by class name
	if node.get_class() == target_class or (node.get_script() and node.get_script().get_global_name() == target_class):
		return node

	for child in node.get_children():
		var result = _find_node_by_class(child, target_class)
		if result:
			return result

	return null

# =============================================================================
# STATS & REPORTING
# =============================================================================

func print_stats():
	# Print current gameplay statistics
	print("\n============================================================")
	print("KEYBOARD PLAYER STATS")
	print("============================================================")
	print("Actions taken: %d" % actions_taken)
	print("Wheat harvested: %d" % wheat_harvested)
	print("Quests completed: %d" % quests_completed)
	print("\nCurrent state:")
	print("  Planted plots: %d" % planted_plots.size())
	print("  Measured plots: %d" % measured_plots.size())
	print("  Empty plots: %d" % (available_positions.size() - planted_plots.size() - measured_plots.size()))
	print("\nResources:")
	print("  🌾 Wheat: %d credits" % farm.economy.get_resource("🌾"))
	print("  👥 Labor: %d credits" % farm.economy.get_resource("👥"))
	print("============================================================\n")
