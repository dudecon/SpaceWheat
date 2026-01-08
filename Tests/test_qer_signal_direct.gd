extends SceneTree

## Direct test of Q/E/R signal chain without interactive keypresses

func _ready():
	print("\n=== DIRECT TEST: Q/E/R Signal Chain ===\n")

	# Create a simple test farm
	var Farm = preload("res://Core/Farm.gd")
	var farm = Farm.new()
	add_child(farm)

	# Wait for farm to initialize
	await get_tree().process_frame

	print("OK Farm created\n")

	# Create PlotGridDisplay
	var PlotGridDisplay = preload("res://UI/PlotGridDisplay.gd")
	var display = PlotGridDisplay.new()
	add_child(display)

	# Wait for PlotGridDisplay to initialize
	await get_tree().process_frame

	print("OK PlotGridDisplay created\n")

	# Inject farm into display
	print("Injecting farm into PlotGridDisplay...\n")
	display.inject_farm(farm)

	await get_tree().process_frame
	print("\nOK Farm injected\n")

	# Now test the signal chain
	print("=== TEST: Planting on plot (0, 0) ===\n")

	var pos = Vector2i(0, 0)
	print("Calling farm.build(pos, wheat)...\n")

	var result = farm.build(pos, "wheat")

	await get_tree().process_frame

	print("\nResults:")
	print("farm.build() returned: " + str(result))

	var plot = farm.grid.get_plot(pos)
	if plot:
		print("plot found: is_planted=" + str(plot.is_planted))
	else:
		print("plot: NULL")

	var tile = display.tiles.get(pos, null)
	if tile:
		print("tile found: plot_data=" + str(tile.plot_data))
	else:
		print("tile: NULL")

	print("\n=== TEST COMPLETE ===\n")

	quit()
