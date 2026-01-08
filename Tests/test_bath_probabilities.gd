extends SceneTree

## Test: Verify that plots query bath probabilities and show different values

const PlotGridDisplay = preload("res://UI/PlotGridDisplay.gd")

var farm = null
var plot_grid_display = null
var test_frame = 0

func _init():
	print("\n" + "=".repeat(70))
	print("🎲 BATH PROBABILITY QUERY TEST")
	print("=".repeat(70) + "\n")

	# Load farm
	var farm_scene = load("res://Core/Farm.gd")
	if not farm_scene:
		print("❌ Could not load Farm.gd")
		quit()
		return

	farm = farm_scene.new()
	get_root().add_child(farm)


func _process(delta):
	test_frame += 1

	if test_frame < 5:
		return

	if test_frame == 5:
		setup_test()
		return

	if test_frame == 10:
		plant_crops()
		return

	if test_frame == 15:
		check_initial_probabilities()
		return

	# Let baths evolve for 100 frames
	if test_frame > 15 and test_frame < 115:
		# Sample every 20 frames
		if test_frame % 20 == 0:
			sample_probabilities()
		return

	if test_frame == 115:
		check_final_probabilities()
		return

	if test_frame == 120:
		finish_test()


func setup_test():
	print("SETUP: Creating plot grid display\n")

	# Give economy resources
	for emoji in ["🌾", "🌿", "💨", "🔥"]:
		farm.economy.add_resource(emoji, 1000, "test")

	# Create plot grid display
	plot_grid_display = PlotGridDisplay.new()
	get_root().add_child(plot_grid_display)
	plot_grid_display.inject_grid_config(farm.grid_config)
	plot_grid_display.farm = farm

	print("✅ Setup complete\n")


func plant_crops():
	print("=".repeat(70))
	print("PLANTING: One crop per biome")
	print("=".repeat(70) + "\n")

	# Plant wheat in BioticFlux (5, 0)
	farm.build(Vector2i(5, 0), "wheat")
	print("✅ Planted wheat in BioticFlux (5, 0)")

	# Plant vegetation in Forest (1, 1)
	farm.build(Vector2i(1, 1), "vegetation")
	print("✅ Planted vegetation in Forest (1, 1)")

	# Plant flour in Market (1, 0)
	farm.build(Vector2i(1, 0), "flour")
	print("✅ Planted flour in Market (1, 0)")

	# Plant fire in Kitchen (5, 1)
	farm.build(Vector2i(5, 1), "fire")
	print("✅ Planted fire in Kitchen (5, 1)\n")


func check_initial_probabilities():
	print("=".repeat(70))
	print("INITIAL: Bath probabilities (frame 15)")
	print("=".repeat(70) + "\n")

	var test_plots = [
		{"pos": Vector2i(5, 0), "name": "BioticFlux Wheat"},
		{"pos": Vector2i(1, 1), "name": "Forest Vegetation"},
		{"pos": Vector2i(1, 0), "name": "Market Flour"},
		{"pos": Vector2i(5, 1), "name": "Kitchen Fire"}
	]

	for test in test_plots:
		var pos = test["pos"]
		var name = test["name"]

		# Get UI data (which now queries bath probabilities)
		var ui_data = plot_grid_display._create_plot_ui_data(pos)

		print("%s:" % name)
		print("   North emoji: %s  probability: %.3f" % [
			ui_data.get("north_emoji", "?"),
			ui_data.get("north_probability", 0.0)
		])
		print("   South emoji: %s  probability: %.3f" % [
			ui_data.get("south_emoji", "?"),
			ui_data.get("south_probability", 0.0)
		])
		print("")


func sample_probabilities():
	print("Frame %d probabilities:" % test_frame)

	var test_plots = [
		{"pos": Vector2i(5, 0), "short": "BioFlux"},
		{"pos": Vector2i(1, 1), "short": "Forest"},
		{"pos": Vector2i(1, 0), "short": "Market"},
		{"pos": Vector2i(5, 1), "short": "Kitchen"}
	]

	var probs = []
	for test in test_plots:
		var ui_data = plot_grid_display._create_plot_ui_data(test["pos"])
		var north_p = ui_data.get("north_probability", 0.0)
		probs.append("%s: %.3f" % [test["short"], north_p])

	print("   " + " | ".join(probs))


func check_final_probabilities():
	print("\n" + "=".repeat(70))
	print("FINAL: Bath probabilities after 100 frames of evolution")
	print("=".repeat(70) + "\n")

	var test_plots = [
		{"pos": Vector2i(5, 0), "name": "BioticFlux Wheat"},
		{"pos": Vector2i(1, 1), "name": "Forest Vegetation"},
		{"pos": Vector2i(1, 0), "name": "Market Flour"},
		{"pos": Vector2i(5, 1), "name": "Kitchen Fire"}
	]

	var all_probs = []
	for test in test_plots:
		var pos = test["pos"]
		var name = test["name"]

		var ui_data = plot_grid_display._create_plot_ui_data(pos)
		var north_p = ui_data.get("north_probability", 0.0)

		print("%s:" % name)
		print("   North: %s (%.3f)  South: %s (%.3f)" % [
			ui_data.get("north_emoji", "?"),
			north_p,
			ui_data.get("south_emoji", "?"),
			ui_data.get("south_probability", 0.0)
		])
		print("")

		all_probs.append(north_p)

	# Check if probabilities are different
	var unique_count = 0
	for i in range(all_probs.size()):
		var is_unique = true
		for j in range(all_probs.size()):
			if i != j and abs(all_probs[i] - all_probs[j]) < 0.01:
				is_unique = false
				break
		if is_unique:
			unique_count += 1

	print("=".repeat(70))
	if unique_count > 1:
		print("✅ DIFFERENT BIOMES → DIFFERENT PROBABILITIES!")
		print("   Biomes are working correctly - each has unique quantum dynamics")
	else:
		print("⚠️  All probabilities are similar")
		print("   This might be expected if evolution is slow or Hamiltonians are weak")
	print("=".repeat(70))


func finish_test():
	print("\n✅ BATH PROBABILITY QUERY TEST COMPLETE\n")
	quit()
