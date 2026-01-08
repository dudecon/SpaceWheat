extends SceneTree

## Test: Verify that different biomes produce different quantum evolution

const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")

var farm = null
var test_frame = 0
var evolution_frames = 60  # Let plots evolve for 60 frames

# Track plot states over time
var plot_states = {}

func _init():
	print("\n" + "=".repeat(70))
	print("🔬 BIOME DYNAMICS TEST")
	print("=".repeat(70) + "\n")

	# Load farm
	var farm_scene = load("res://Core/Farm.gd")
	if not farm_scene:
		print("❌ Could not load Farm.gd")
		quit()
		return

	farm = farm_scene.new()
	get_root().add_child(farm)

	print("⏳ Waiting for farm initialization...\n")


func _process(delta):
	test_frame += 1

	if test_frame < 5:
		return

	if test_frame == 5:
		setup_test()
		return

	if test_frame == 10:
		plant_all_biomes()
		return

	if test_frame == 15:
		check_initial_state()
		return

	if test_frame > 15 and test_frame < (15 + evolution_frames):
		# Let plots evolve
		if test_frame % 10 == 0:
			sample_states()
		return

	if test_frame == (15 + evolution_frames):
		check_final_state()
		return

	if test_frame == (15 + evolution_frames + 5):
		finish_test()


func setup_test():
	print("=".repeat(70))
	print("SETUP: Giving economy resources")
	print("=".repeat(70) + "\n")

	# Give economy plenty of resources
	for emoji in ["🌾", "🍄", "🍅", "🌿", "🐇", "🐺", "💨", "🍞", "🔥", "💧"]:
		farm.economy.add_resource(emoji, 1000, "test")

	print("✅ Setup complete\n")


func plant_all_biomes():
	print("=".repeat(70))
	print("PLANTING: One crop per biome")
	print("=".repeat(70) + "\n")

	# Plant wheat in BioticFlux (5, 0)
	print("🌾 Planting wheat in BioticFlux (5, 0)...")
	var result1 = farm.build(Vector2i(5, 0), "wheat")
	print("   Result: %s\n" % ("✅" if result1 else "❌"))

	# Plant vegetation in Forest (1, 1)
	print("🌿 Planting vegetation in Forest (1, 1)...")
	var result2 = farm.build(Vector2i(1, 1), "vegetation")
	print("   Result: %s\n" % ("✅" if result2 else "❌"))

	# Plant flour in Market (1, 0)
	print("💨 Planting flour in Market (1, 0)...")
	var result3 = farm.build(Vector2i(1, 0), "flour")
	print("   Result: %s\n" % ("✅" if result3 else "❌"))

	# Plant fire in Kitchen (5, 1)
	print("🔥 Planting fire in Kitchen (5, 1)...")
	var result4 = farm.build(Vector2i(5, 1), "fire")
	print("   Result: %s\n" % ("✅" if result4 else "❌"))


func check_initial_state():
	print("=".repeat(70))
	print("INITIAL STATE: Check biome connections")
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
		var plot = farm.grid.get_plot(pos)

		if not plot:
			print("❌ %s: Plot not found!" % name)
			continue

		print("📊 %s:" % name)
		print("   is_planted: %s" % plot.is_planted)
		print("   plot_type: %s" % plot.plot_type)

		# Check biome connection
		var biome_name = farm.grid.plot_biome_assignments.get(pos, "NONE")
		print("   biome_assigned: %s" % biome_name)

		# Check if plot has quantum_state (Model A) or is bath-connected (Model C)
		if "quantum_state" in plot and plot.quantum_state:
			print("   🔬 Has quantum_state (Model A - discrete)")
			var state = plot.quantum_state
			print("   State type: %s" % state.get_class())
		else:
			print("   🛁 No quantum_state (Model C - bath-based)")

		# Check biome reference
		if plot.biome:
			print("   ✅ Connected to biome: %s" % plot.biome.name)
			if plot.biome.has_method("get_bath_state"):
				print("   🛁 Biome has bath system")
		else:
			print("   ❌ No biome reference!")

		print("")


func sample_states():
	"""Sample plot states during evolution"""
	var frame_key = "frame_%d" % test_frame
	plot_states[frame_key] = {}

	var test_plots = [
		Vector2i(5, 0),  # BioticFlux
		Vector2i(1, 1),  # Forest
		Vector2i(1, 0),  # Market
		Vector2i(5, 1)   # Kitchen
	]

	for pos in test_plots:
		var plot = farm.grid.get_plot(pos)
		if plot and plot.is_planted:
			var emojis = plot.get_plot_emojis()
			var emoji_str = "%s↔%s" % [emojis.get("north", "?"), emojis.get("south", "?")]

			# Try to get state info
			var state_info = "unknown"
			if "quantum_state" in plot and plot.quantum_state:
				# Model A - has discrete quantum_state
				state_info = "discrete"
			elif plot.biome and plot.biome.has_method("get_bath_state"):
				# Model C - bath-based
				state_info = "bath"

			plot_states[frame_key][pos] = {
				"emoji": emoji_str,
				"state_type": state_info
			}


func check_final_state():
	print("=".repeat(70))
	print("FINAL STATE: After %d frames of evolution" % evolution_frames)
	print("=".repeat(70) + "\n")

	var test_cases = [
		{"pos": Vector2i(5, 0), "name": "BioticFlux Wheat", "expected": "bath"},
		{"pos": Vector2i(1, 1), "name": "Forest Vegetation", "expected": "bath"},
		{"pos": Vector2i(1, 0), "name": "Market Flour", "expected": "bath"},
		{"pos": Vector2i(5, 1), "name": "Kitchen Fire", "expected": "bath"}
	]

	print("📈 EVOLUTION TRACKING:\n")

	for test in test_cases:
		var pos = test["pos"]
		var name = test["name"]

		print("%s (position %s):" % [name, pos])

		# Show evolution over time
		var emoji_history = []
		for frame_key in plot_states.keys():
			if plot_states[frame_key].has(pos):
				var data = plot_states[frame_key][pos]
				emoji_history.append(data["emoji"])

		if emoji_history.size() > 0:
			print("   Evolution: %s" % " → ".join(emoji_history))
		else:
			print("   ❌ No evolution data captured")

		print("")

	print("\n" + "=".repeat(70))
	print("ANALYSIS: Are biomes implementing unique dynamics?")
	print("=".repeat(70) + "\n")

	# Check if all plots evolved the same way (bad) or differently (good)
	var all_evolutions = {}
	for test in test_cases:
		var pos = test["pos"]
		var name = test["name"]
		var evolution_seq = []

		for frame_key in plot_states.keys():
			if plot_states[frame_key].has(pos):
				evolution_seq.append(plot_states[frame_key][pos]["emoji"])

		all_evolutions[name] = evolution_seq

	# Compare evolutions
	var unique_evolutions = []
	for name in all_evolutions.keys():
		var seq = all_evolutions[name]
		if seq not in unique_evolutions:
			unique_evolutions.append(seq)

	print("Unique evolution patterns: %d out of %d plots" % [unique_evolutions.size(), all_evolutions.size()])

	if unique_evolutions.size() == 1:
		print("❌ ALL PLOTS EVOLVED IDENTICALLY - Biomes are NOT working!")
		print("   This means plots are using the same dynamics regardless of biome.")
	elif unique_evolutions.size() == all_evolutions.size():
		print("✅ ALL PLOTS EVOLVED DIFFERENTLY - Biomes ARE working!")
		print("   Each biome is producing unique quantum dynamics.")
	else:
		print("⚠️  SOME PLOTS EVOLVED IDENTICALLY - Partial implementation")
		print("   Some biomes working, others not.")

	print("")


func finish_test():
	print("=".repeat(70))
	print("✅ BIOME DYNAMICS TEST COMPLETE")
	print("=".repeat(70))
	print("\nRECOMMENDATION:")
	print("If plots evolved identically:")
	print("  → Check that plots are connected to their biome's quantum bath")
	print("  → Verify biome._process() is driving plot evolution")
	print("  → Ensure bath Hamiltonian/Lindblad are actually different per biome")
	print("")
	quit()
