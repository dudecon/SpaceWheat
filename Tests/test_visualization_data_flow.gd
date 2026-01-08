extends SceneTree

## Test: Trace what data drives the bubble visualization

var farm = null
var test_frame = 0

func _init():
	print("\n" + "=".repeat(70))
	print("🔍 VISUALIZATION DATA FLOW TEST")
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
		plant_and_analyze()
		return

	if test_frame == 10:
		check_biome_state()
		return

	if test_frame == 20:
		check_bath_evolution()
		return

	if test_frame == 40:
		check_bath_evolution()
		return

	if test_frame == 60:
		check_bath_evolution()
		return

	if test_frame == 65:
		finish_test()


func plant_and_analyze():
	print("=".repeat(70))
	print("STEP 1: Plant crops in each biome")
	print("=".repeat(70) + "\n")

	# Give resources
	for emoji in ["🌾", "🌿", "💨", "🔥"]:
		farm.economy.add_resource(emoji, 1000, "test")

	# Plant one in each biome
	farm.build(Vector2i(5, 0), "wheat")     # BioticFlux
	farm.build(Vector2i(1, 1), "vegetation") # Forest
	farm.build(Vector2i(1, 0), "flour")      # Market
	farm.build(Vector2i(5, 1), "fire")       # Kitchen

	print("✅ Planted 4 crops\n")

	# Check what's in each biome's bath
	print("=".repeat(70))
	print("BIOME BATH STATUS")
	print("=".repeat(70) + "\n")

	var biomes_to_check = [
		{"name": "BioticFlux", "plot_pos": Vector2i(5, 0)},
		{"name": "Forest", "plot_pos": Vector2i(1, 1)},
		{"name": "Market", "plot_pos": Vector2i(1, 0)},
		{"name": "Kitchen", "plot_pos": Vector2i(5, 1)}
	]

	for biome_info in biomes_to_check:
		var biome_name = biome_info["name"]
		var biome = farm.grid.biomes.get(biome_name)

		if not biome:
			print("❌ %s biome not found!" % biome_name)
			continue

		print("📊 %s Biome:" % biome_name)
		print("   Has bath: %s" % ("yes" if biome.bath else "no"))

		if biome.bath:
			var prob_dist = biome.bath.get_probability_distribution()
			print("   Number of states in bath: %d" % prob_dist.size())

			# Show top 5 probabilities
			var sorted_probs = []
			for emoji in prob_dist.keys():
				sorted_probs.append({"emoji": emoji, "prob": prob_dist[emoji]})

			# Sort by probability descending
			sorted_probs.sort_custom(func(a, b): return a["prob"] > b["prob"])

			print("   Top states:")
			for i in range(min(5, sorted_probs.size())):
				var item = sorted_probs[i]
				print("      %s: %.4f" % [item["emoji"], item["prob"]])

		# Check if this biome has a projection system (for bubble positions)
		if "projection_system" in biome and biome.projection_system:
			print("   ✅ Has projection_system (drives bubble positions)")
		else:
			print("   ❌ No projection_system")

		# Check plot connection
		var plot = farm.grid.get_plot(biome_info["plot_pos"])
		if plot and plot.parent_biome:
			print("   ✅ Plot connected to this biome")
		else:
			print("   ❌ Plot not properly connected")

		print("")


func check_biome_state():
	print("=".repeat(70))
	print("STEP 2: Check Biome Projection Systems (Frame 10)")
	print("=".repeat(70) + "\n")

	var biomes_to_check = ["BioticFlux", "Forest", "Market", "Kitchen"]

	for biome_name in biomes_to_check:
		var biome = farm.grid.biomes.get(biome_name)
		if not biome:
			continue

		print("🔬 %s:" % biome_name)

		# Check if biome has projection_system
		if "projection_system" in biome:
			var proj_sys = biome.projection_system
			if proj_sys:
				print("   Projection system exists")

				# Try to get projection data
				if proj_sys.has_method("get_all_projections"):
					var projections = proj_sys.get_all_projections()
					print("   Number of projections: %d" % projections.size())

					if projections.size() > 0:
						print("   Sample projection:")
						var sample_key = projections.keys()[0]
						var proj = projections[sample_key]
						print("      Emoji: %s" % sample_key)
						print("      Position: (%.2f, %.2f)" % [proj.get("x", 0), proj.get("y", 0)])
						print("      Radius: %.2f" % proj.get("radius", 0))
				elif proj_sys.has_method("get_projections"):
					var projections = proj_sys.get_projections()
					print("   Number of projections: %d" % projections.size())
			else:
				print("   ⚠️  projection_system is null")
		else:
			print("   ❌ No projection_system property")

		# Check bath state
		if biome.bath:
			var purity = biome.bath.get_purity()
			var entropy = biome.bath.get_entropy()
			print("   Bath purity: %.3f" % purity)
			print("   Bath entropy: %.3f" % entropy)

		print("")


func check_bath_evolution():
	print("=".repeat(70))
	print("BATH EVOLUTION CHECK (Frame %d)" % test_frame)
	print("=".repeat(70) + "\n")

	var test_cases = [
		{"name": "BioticFlux", "emoji": "🌾"},
		{"name": "Forest", "emoji": "🌿"},
		{"name": "Market", "emoji": "💨"},
		{"name": "Kitchen", "emoji": "🔥"}
	]

	for test in test_cases:
		var biome = farm.grid.biomes.get(test["name"])
		if not biome or not biome.bath:
			continue

		var prob = biome.bath.get_probability(test["emoji"])
		var purity = biome.bath.get_purity()

		print("%s: %s prob=%.4f, purity=%.4f" % [
			test["name"],
			test["emoji"],
			prob,
			purity
		])

	print("")


func finish_test():
	print("=".repeat(70))
	print("✅ VISUALIZATION DATA FLOW TEST COMPLETE")
	print("=".repeat(70))
	print("\nFINDINGS:")
	print("- Each biome has a quantum bath with emoji probability distribution")
	print("- Biomes may have projection_system that converts bath state → bubble positions")
	print("- Plots query parent_biome.bath for north/south probabilities")
	print("")
	print("NEXT STEPS:")
	print("1. Check if projection_system is updating bubble positions from bath")
	print("2. Verify QuantumForceGraph is reading from projection_system")
	print("3. Investigate why bubbles drift to left middle")
	print("")
	quit()
