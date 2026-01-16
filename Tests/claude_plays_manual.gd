extends Node

## ⚠️ OUT OF SYNC WITH V2 ARCHITECTURE ⚠️
## This test uses the OLD Plot-based API (farm.build, farm.measure_plot, farm.harvest_plot)
## The v2 architecture uses Terminals via ProbeActions (action_explore, action_measure, action_pop)
## DO NOT RUN - needs rewrite to use ProbeActions + Terminal system
##
## Claude plays SpaceWheat MANUALLY!
## Updated for compositional biome architecture testing

const Farm = preload("res://Core/Farm.gd")

var farm: Farm
var current_turn: int = 0
var max_turns: int = 100  # Longer gameplay to test full cycle
var game_time: float = 0.0  # Track in-game time

# My play state
var my_planted_plots: Array[Vector2i] = []
var my_measured_plots: Array[Vector2i] = []
var plots_plant_time: Dictionary = {}  # Track when each plot was planted
var plots_per_biome: Dictionary = {}  # Track which biome each plot is in

func _ready():
	print("\n======================================================================")
	print("🎮 CLAUDE PLAYS SPACEWHEAT - MULTI-BIOME TEST!")
	print("======================================================================\n")

	# Set up the game
	_setup_game()

	# Wait one frame for everything to initialize
	await get_tree().process_frame

	# Show biome layout
	_show_biome_layout()

	# Start playing!
	_play_turn()

func _setup_game():
	print("Setting up the game world...")

	# Create farm
	farm = Farm.new()
	add_child(farm)  # CRITICAL: Add to scene tree to trigger _ready()!

	# CRITICAL: Wait for complete initialization (biomes, baths, icons, etc.)
	# Forest biome does Markov derivation which is very slow
	print("   ⏳ Waiting for farm initialization...")
	for i in range(20):  # Multiple frames to ensure all _ready() callbacks complete
		await get_tree().process_frame

	# Give derived icons extra time to settle
	await get_tree().create_timer(2.0).timeout

	if not farm.grid or not farm.grid.biomes:
		print("❌ FATAL: Farm failed to initialize!")
		get_tree().quit(1)
		return

	print("✅ Farm initialized with %d biomes" % farm.grid.biomes.size())
	print("")

func _show_biome_layout():
	"""Show which plots belong to which biomes"""
	print("🗺️  BIOME LAYOUT:")
	print("")

	# Show grid with biome assignments
	for y in range(farm.grid.grid_height):
		var row_str = "   "
		for x in range(farm.grid.grid_width):
			var pos = Vector2i(x, y)
			var biome_name = farm.grid.plot_biome_assignments.get(pos, "?")
			var biome_char = biome_name[0] if biome_name != "?" else "?"
			row_str += "[%s] " % biome_char
		print(row_str)

	print("")
	print("   Legend:")
	for biome_name in farm.grid.biomes.keys():
		print("      %s = %s" % [biome_name[0], biome_name])
	print("")

func _play_turn():
	"""Play one turn manually - I decide what to do!"""

	current_turn += 1

	print("\n──────────────────────────────────────────────────────────────────────")
	print("🎮 TURN %d/%d" % [current_turn, max_turns])
	print("──────────────────────────────────────────────────────────────────────")

	# Show me the current state
	_observe_state()

	# Let me think about what to do
	_decide_action()

	# Continue to next turn
	if current_turn < max_turns:
		await get_tree().create_timer(0.1).timeout  # Faster turns!
		_play_turn()
	else:
		_end_game()

func _observe_state():
	"""Look at the current game state"""

	print("\n📊 CURRENT STATE:")
	print("   ⏰ Game Time: %.1f days" % (game_time / 20.0))  # 20 seconds = 1 day
	print("   💰 Resources:")
	print("      🌾 Wheat: %d credits" % farm.economy.get_resource("🌾"))
	print("      👥 Labor: %d credits" % farm.economy.get_resource("👥"))
	print("      🍄 Mushroom: %d credits" % farm.economy.get_resource("🍄"))

	print("\n   🗺️  Grid Status:")
	var empty_count = 0
	var planted_unmeasured = 0
	var measured_ready = 0
	var biome_counts = {}

	for y in range(farm.grid.grid_height):
		for x in range(farm.grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot:
				if not plot.is_planted:
					empty_count += 1
				elif not plot.has_been_measured:
					planted_unmeasured += 1
					# Track which biome this planted plot is in
					var biome_name = farm.grid.plot_biome_assignments.get(pos, "Unknown")
					if not biome_counts.has(biome_name):
						biome_counts[biome_name] = 0
					biome_counts[biome_name] += 1
				else:
					measured_ready += 1

	print("      Empty plots: %d" % empty_count)
	print("      Planted (unmeasured): %d" % planted_unmeasured)
	if biome_counts.size() > 0:
		print("         Biomes: %s" % biome_counts)
	print("      Measured (ready to harvest): %d" % measured_ready)

func _decide_action():
	"""I make a decision about what to do this turn! IMPROVED STRATEGY WITH WAIT PRIORITY"""

	print("\n🤔 Let me think...")

	# What are my options?
	var can_plant = farm.economy.get_resource("🌾") >= 10
	var has_empty_plots = _count_empty_plots() > 0
	var has_unmeasured = _count_unmeasured_plots() > 0
	var has_measured = _count_measured_plots() > 0

	# SMART STRATEGY: Check if any planted plots have matured (3 days = 60 seconds)
	var has_mature_plots = false
	for pos in my_planted_plots:
		var time_since_plant = game_time - plots_plant_time.get(pos, game_time)
		if time_since_plant >= 60.0:  # 3 days = 60 seconds
			has_mature_plots = true
			break

	# Decision tree - OPTIMIZED FOR ENERGY GROWTH & SUSTAINABLE FARMING!
	var action_taken = false

	# Priority 1: Harvest measured plots
	if has_measured:
		print("   💡 Measured plots ready! Time to harvest and profit!")
		_action_harvest()
		action_taken = true

	# Priority 2: Measure mature plots
	elif has_mature_plots:
		print("   💡 Wheat has grown for 3 days! Energy should be high. Measuring!")
		_action_measure()
		action_taken = true

	# Priority 3: Try entangling adjacent unmeasured plots
	elif has_unmeasured and my_planted_plots.size() >= 2:
		var adjacent_pair = _find_adjacent_unmeasured_pair()
		if adjacent_pair.size() == 2 and not farm.grid.are_plots_entangled(adjacent_pair[0], adjacent_pair[1]):
			print("   💡 Found adjacent plots! Let me try ENTANGLEMENT!")
			_action_entangle(adjacent_pair[0], adjacent_pair[1])
			action_taken = true

	# Priority 4: WAIT if we have unmeasured plots (LET THEM GROW!)
	if not action_taken and has_unmeasured:
		print("   💡 Plots planted, waiting for them to mature...")
		_action_wait()
		action_taken = true

	# Priority 5: Plant if we can and should (but only if we're not waiting)
	if not action_taken and can_plant and has_empty_plots and my_planted_plots.size() < 6:
		print("   💡 Planting wheat to fill the farm!")
		_action_plant()
		action_taken = true

	# Fallback: Wait to advance time
	if not action_taken:
		print("   💡 Nothing specific to do, waiting...")
		_action_wait()

func _action_plant():
	"""I decide to plant wheat"""

	# Find an empty plot
	var pos = _find_empty_plot()
	if pos == Vector2i(-1, -1):
		print("   ❌ No empty plots found!")
		return

	# Check which biome this plot is in
	var biome_name = farm.grid.plot_biome_assignments.get(pos, "Unknown")

	print("\n   🌱 Planting wheat at %s (%s biome)..." % [pos, biome_name])

	var wheat_before = farm.economy.get_resource("🌾")
	var success = farm.build(pos, "wheat")

	if success:
		var wheat_after = farm.economy.get_resource("🌾")
		my_planted_plots.append(pos)
		plots_plant_time[pos] = game_time  # Track when planted!
		plots_per_biome[pos] = biome_name  # Track biome
		print("   ✅ Planted! Wheat: %d → %d" % [wheat_before, wheat_after])
		print("   ⏰ Will mature in 3 days (60 seconds)")
		print("   🌍 Biome: %s" % biome_name)
	else:
		print("   ❌ Failed to plant!")

func _action_measure():
	"""I decide to measure a plot"""

	var pos = _find_unmeasured_plot()
	if pos == Vector2i(-1, -1):
		print("   ❌ No unmeasured plots found!")
		return

	var plot = farm.grid.get_plot(pos)
	if not plot or not plot.is_planted:
		print("   ❌ Plot not planted!")
		return

	print("\n   📏 Measuring plot at %s..." % pos)

	# Get the biome this plot is in and measure via that biome
	var biome_name = farm.grid.plot_biome_assignments.get(pos, "Unknown")
	var biome = farm.grid.biomes.get(biome_name) if farm.grid.biomes else null

	if biome and biome.has_method("measure_plot_in_biome"):
		var outcome = biome.measure_plot_in_biome(pos)
		if outcome:
			my_planted_plots.erase(pos)
			my_measured_plots.append(pos)
			print("   ✅ Measured! Outcome: %s" % outcome)
			print("   🌍 Biome: %s" % biome_name)
			return

	# Fallback: Try farm.measure_plot
	var outcome = farm.measure_plot(pos)

	# Check if plot is now measured (outcome might be empty string which is falsy!)
	plot = farm.grid.get_plot(pos)
	if plot and plot.has_been_measured:
		my_planted_plots.erase(pos)
		my_measured_plots.append(pos)
		print("   ✅ Measured! Outcome: '%s'" % outcome)
	else:
		print("   ❌ Failed to measure!")
		print("   ℹ️  Plot state: planted=%s, measured=%s" % [plot.is_planted if plot else "?", plot.has_been_measured if plot else "?"])

func _action_harvest():
	"""I decide to harvest a plot"""

	var pos = _find_measured_plot()
	if pos == Vector2i(-1, -1):
		print("   ❌ No measured plots found!")
		return

	print("\n   🚜 Harvesting plot at %s..." % pos)

	var wheat_before = farm.economy.get_resource("🌾")
	var result = farm.harvest_plot(pos)

	if result.get("success", false):
		var wheat_after = farm.economy.get_resource("🌾")
		my_measured_plots.erase(pos)
		plots_plant_time.erase(pos)  # Clean up tracking

		print("   ✅ Harvested: %s" % result.get("outcome"))
		print("   ⚡ Yield: %d credits" % result.get("yield", 0))
		print("   💰 Wheat: %d → %d (gain: %d)" % [
			wheat_before, wheat_after, wheat_after - wheat_before
		])
	else:
		print("   ❌ Failed to harvest!")

func _action_wait():
	"""I decide to WAIT - let time pass for quantum evolution!"""

	var wait_time = 20.0  # 20 seconds = 1 day
	print("\n   ⏰ WAITING 1 day (%.0fs) for quantum energy to build..." % wait_time)

	# Advance time in ALL quantum baths!
	if farm.grid.biomes:
		for biome_name in farm.grid.biomes.keys():
			var biome = farm.grid.biomes[biome_name]
			if biome and biome.has_method("_process"):
				biome._process(wait_time)

	# Also advance plot growth on all plots
	for y in range(farm.grid.grid_height):
		for x in range(farm.grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot and plot.is_planted and plot.has_method("_process"):
				plot._process(wait_time)

	game_time += wait_time
	print("   ✅ Time advanced! Game time: %.1f days" % (game_time / 20.0))

# Helper functions to find plots
func _find_empty_plot() -> Vector2i:
	for y in range(farm.grid.grid_height):
		for x in range(farm.grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot and not plot.is_planted:
				return pos
	return Vector2i(-1, -1)

func _find_unmeasured_plot() -> Vector2i:
	for pos in my_planted_plots:
		var plot = farm.grid.get_plot(pos)
		if plot and plot.is_planted and not plot.has_been_measured:
			return pos
	return Vector2i(-1, -1)

func _find_measured_plot() -> Vector2i:
	for pos in my_measured_plots:
		var plot = farm.grid.get_plot(pos)
		if plot and plot.is_planted and plot.has_been_measured:
			return pos
	return Vector2i(-1, -1)

func _count_empty_plots() -> int:
	var count = 0
	for y in range(farm.grid.grid_height):
		for x in range(farm.grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot and not plot.is_planted:
				count += 1
	return count

func _count_unmeasured_plots() -> int:
	return my_planted_plots.size()

func _count_measured_plots() -> int:
	return my_measured_plots.size()

func _find_adjacent_unmeasured_pair() -> Array[Vector2i]:
	"""Find two adjacent unmeasured plots for entanglement"""
	var result: Array[Vector2i] = []

	for i in range(my_planted_plots.size()):
		for j in range(i + 1, my_planted_plots.size()):
			var pos1 = my_planted_plots[i]
			var pos2 = my_planted_plots[j]

			# Check if adjacent (Manhattan distance = 1)
			var distance = abs(pos1.x - pos2.x) + abs(pos1.y - pos2.y)
			if distance == 1:
				var plot1 = farm.grid.get_plot(pos1)
				var plot2 = farm.grid.get_plot(pos2)

				# Both must be planted and unmeasured
				if plot1 and plot2 and not plot1.has_been_measured and not plot2.has_been_measured:
					result.append(pos1)
					result.append(pos2)
					return result

	return result

func _action_entangle(pos1: Vector2i, pos2: Vector2i):
	"""I decide to entangle two plots - creating quantum correlations!"""

	print("\n   🔗 ENTANGLING plots at %s and %s..." % [pos1, pos2])

	# Check if already entangled
	if farm.grid.are_plots_entangled(pos1, pos2):
		print("   ⚠️  These plots are already entangled!")
		return

	var success = farm.entangle_plots(pos1, pos2)

	if success:
		print("   ✅ Entanglement created! Bell state φ+")
		print("   ⚛️  These plots now share quantum correlation!")
		print("   📊 Measuring one will affect the other!")
	else:
		print("   ❌ Failed to create entanglement!")

func _end_game():
	"""Game over - show final results"""

	print("\n\n======================================================================")
	print("🏁 GAME OVER - I PLAYED %d TURNS!" % current_turn)
	print("======================================================================")

	print("\n💰 FINAL RESOURCES:")
	print("   🌾 Wheat: %d credits" % farm.economy.get_resource("🌾"))
	print("   👥 Labor: %d credits" % farm.economy.get_resource("👥"))
	print("   🍄 Mushroom: %d credits" % farm.economy.get_resource("🍄"))

	print("\n🌍 BIOMES TESTED:")
	var biome_usage = {}
	for pos in plots_per_biome.keys():
		var biome_name = plots_per_biome[pos]
		if not biome_usage.has(biome_name):
			biome_usage[biome_name] = 0
		biome_usage[biome_name] += 1

	for biome_name in biome_usage.keys():
		print("   %s: %d plots planted" % [biome_name, biome_usage[biome_name]])

	print("\n📊 GAME STATISTICS:")
	print("   Total turns: %d" % current_turn)
	print("   Game time: %.1f days" % (game_time / 20.0))
	print("   Plots planted: %d" % (my_planted_plots.size() + my_measured_plots.size()))

	print("\n✨ Multi-biome playtest complete!")
	print("======================================================================\n")

	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0)
