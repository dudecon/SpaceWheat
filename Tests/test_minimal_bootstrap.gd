#!/usr/bin/env -S godot --headless -s
extends SceneTree

## MINIMAL TEST BOOTSTRAP
## Fast startup without UI/visualization
## Target: < 10 seconds boot time

var farm = null
var grid = null
var economy = null
var plot_pool = null
var biome = null

var frame_count = 0
var scene_loaded = false
var bootstrap_complete = false
var test_callback = null

func _init():
	print("\n" + "═".repeat(80))
	print("⚡ MINIMAL TEST BOOTSTRAP")
	print("═".repeat(80))

func _process(_delta):
	frame_count += 1

	# Frame 5: Load scene with minimal setup
	if frame_count == 5 and not scene_loaded:
		print("\n⏳ Frame 5: Creating minimal farm...")
		_create_minimal_farm()
		scene_loaded = true

	# Frame 10: Run callback if setup complete
	if frame_count == 10 and scene_loaded and not bootstrap_complete:
		bootstrap_complete = true
		if test_callback:
			print("\n✅ Bootstrap complete! Running tests...\n")
			test_callback.call()
		else:
			print("\n✅ Bootstrap complete!")
			quit()

func _create_minimal_farm():
	"""Create a farm with minimal initialization - no UI, single biome."""

	# Create autoloads if missing
	if not get_node_or_null("/root/IconRegistry"):
		var icon_reg = preload("res://Core/Factions/IconRegistry.gd").new()
		get_tree().root.add_child(icon_reg)
		icon_reg.name = "IconRegistry"

	if not get_node_or_null("/root/GameStateManager"):
		var game_state = preload("res://Core/GameState/GameStateManager.gd").new()
		get_tree().root.add_child(game_state)
		game_state.name = "GameStateManager"

	# Create farm directly (no scene loading)
	farm = _create_farm_minimal()

	if farm:
		grid = farm.grid
		economy = farm.economy
		plot_pool = farm.plot_pool

		# Get first available biome
		if grid.biomes.size() > 0:
			biome = grid.biomes.values()[0]
			print("   🌿 Using biome: %s" % grid.biomes.keys()[0])

		print("   Farm: ✅ (12 plots)")
		print("   Economy: 💰 = %d" % economy.get_resource("💰"))
		print("   Biomes: ✅ (%d total)" % grid.biomes.size())

		# Bootstrap initial credits
		economy.add_resource("💰", 10000, "test_bootstrap")
	else:
		print("   ❌ Failed to create farm")
		quit(1)

func _create_farm_minimal() -> Node:
	"""Create farm without full scene hierarchy."""

	const GridConfig = preload("res://Core/Config/GridConfig.gd")
	const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
	const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
	const PlotPool = preload("res://Core/GameMechanics/PlotPool.gd")

	print("   Creating farm components...")

	# Create economy
	var economy_inst = FarmEconomy.new()
	economy_inst.name = "FarmEconomy"

	# Create grid config
	var grid_config = GridConfig.new()

	# Create plot pool
	var plot_pool_inst = PlotPool.new()
	plot_pool_inst.name = "PlotPool"

	# Create grid
	var grid_inst = FarmGrid.new()
	grid_inst.name = "FarmGrid"

	# Create farm node
	var farm_node = Node.new()
	farm_node.name = "Farm"

	# Set up farm
	farm_node.add_child(economy_inst)
	farm_node.add_child(plot_pool_inst)
	farm_node.add_child(grid_inst)

	get_tree().root.add_child(farm_node)

	# Initialize farm
	grid_inst.economy = economy_inst
	grid_inst.plot_pool = plot_pool_inst
	grid_inst.grid_config = grid_config

	farm_node.grid = grid_inst
	farm_node.economy = economy_inst
	farm_node.plot_pool = plot_pool_inst

	# Initialize grid
	grid_inst.initialize()

	# Register farm with GameStateManager
	var game_state = get_node_or_null("/root/GameStateManager")
	if game_state:
		game_state.active_farm = farm_node

	return farm_node

# ═══════════════════════════════════════════════════════════════════════════
# TEST HELPER METHODS
# ═══════════════════════════════════════════════════════════════════════════

func run_test(callback: Callable):
	"""Set callback to run after bootstrap completes."""
	test_callback = callback

func assert_test(condition: bool, description: String) -> bool:
	if condition:
		print("   ✅ %s" % description)
		return true
	else:
		print("   ❌ %s" % description)
		return false

func print_header(title: String):
	print("\n" + "─".repeat(80))
	print(title)
	print("─".repeat(80))

func print_summary(passed: int, total: int):
	print("\n" + "─".repeat(80))
	print("📊 RESULTS: %d/%d passed" % [passed, total])
	print("═".repeat(80) + "\n")
