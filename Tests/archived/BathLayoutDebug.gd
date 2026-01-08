extends Node

## Headless debug test for bath layout
## Prints all positions to verify biome ovals are separated

const BioticFluxBiomeScript = preload("res://Core/Environment/BioticFluxBiome.gd")
const ForestEcosystemBiomeScript = preload("res://Core/Environment/ForestEcosystem_Biome.gd")
const BiomeLayoutCalculatorScript = preload("res://Core/Visualization/BiomeLayoutCalculator.gd")

func _ready():
	print("\n" + "=".repeat(80))
	print("🔍 BATH LAYOUT DEBUG TEST")
	print("=".repeat(80))

	# Create biomes and add to scene tree (triggers _ready())
	var biotic_flux = BioticFluxBiomeScript.new()
	add_child(biotic_flux)

	var forest = ForestEcosystemBiomeScript.new(4, 1)
	add_child(forest)

	# Give them time to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	print("\n📋 BIOME VISUAL CONFIGS:")
	print("-".repeat(80))

	var bf_config = biotic_flux.get_visual_config()
	print("BioticFlux:")
	print("  center_offset: %s" % bf_config.center_offset)
	print("  oval_width: %.1f" % bf_config.oval_width)
	print("  oval_height: %.1f" % bf_config.oval_height)
	print("  color: %s" % bf_config.color)
	print("  label: %s" % bf_config.label)

	var forest_config = forest.get_visual_config()
	print("\nForest:")
	print("  center_offset: %s" % forest_config.center_offset)
	print("  oval_width: %.1f" % forest_config.oval_width)
	print("  oval_height: %.1f" % forest_config.oval_height)
	print("  color: %s" % forest_config.color)
	print("  label: %s" % forest_config.label)

	# Create layout calculator
	var layout_calc = BiomeLayoutCalculatorScript.new()
	var viewport_size = Vector2(1280, 720)

	print("\n📐 VIEWPORT:")
	print("-".repeat(80))
	print("  size: %s" % viewport_size)

	# Compute layout
	var biomes = {
		"BioticFlux": biotic_flux,
		"Forest": forest
	}

	layout_calc.compute_layout(biomes, viewport_size)

	print("\n📊 COMPUTED LAYOUT:")
	print("-".repeat(80))
	print("  graph_center: %s" % layout_calc.graph_center)
	print("  graph_radius: %.1f" % layout_calc.graph_radius)

	# Show biome ovals
	print("\n🔵 BIOME OVALS:")
	print("-".repeat(80))

	var bf_oval = layout_calc.get_biome_oval("BioticFlux")
	print("BioticFlux oval:")
	if bf_oval.is_empty():
		print("  ❌ NOT COMPUTED!")
	else:
		print("  center: %s" % bf_oval.center)
		print("  semi_a (horizontal): %.1f" % bf_oval.semi_a)
		print("  semi_b (vertical): %.1f" % bf_oval.semi_b)
		print("  bounds: x[%.1f, %.1f] y[%.1f, %.1f]" % [
			bf_oval.center.x - bf_oval.semi_a,
			bf_oval.center.x + bf_oval.semi_a,
			bf_oval.center.y - bf_oval.semi_b,
			bf_oval.center.y + bf_oval.semi_b
		])

	var forest_oval = layout_calc.get_biome_oval("Forest")
	print("\nForest oval:")
	if forest_oval.is_empty():
		print("  ❌ NOT COMPUTED!")
	else:
		print("  center: %s" % forest_oval.center)
		print("  semi_a (horizontal): %.1f" % forest_oval.semi_a)
		print("  semi_b (vertical): %.1f" % forest_oval.semi_b)
		print("  bounds: x[%.1f, %.1f] y[%.1f, %.1f]" % [
			forest_oval.center.x - forest_oval.semi_a,
			forest_oval.center.x + forest_oval.semi_a,
			forest_oval.center.y - forest_oval.semi_b,
			forest_oval.center.y + forest_oval.semi_b
		])

	# Test parametric positions
	print("\n📍 TEST PARAMETRIC POSITIONS:")
	print("-".repeat(80))

	# BioticFlux test points
	print("BioticFlux samples (t, ring) → position:")
	for t in [0.0, 0.25, 0.5, 0.75]:
		for ring in [0.0, 0.5, 1.0]:
			var pos = layout_calc.get_parametric_position("BioticFlux", t, ring)
			print("  (%.2f, %.2f) → %s" % [t, ring, pos])

	print("\nForest samples (t, ring) → position:")
	for t in [0.0, 0.25, 0.5, 0.75]:
		for ring in [0.0, 0.5, 1.0]:
			var pos = layout_calc.get_parametric_position("Forest", t, ring)
			print("  (%.2f, %.2f) → %s" % [t, ring, pos])

	# Calculate distance between ovals
	if not bf_oval.is_empty() and not forest_oval.is_empty():
		var distance = bf_oval.center.distance_to(forest_oval.center)
		print("\n📏 SEPARATION:")
		print("-".repeat(80))
		print("  Distance between centers: %.1f pixels" % distance)
		print("  BioticFlux radius: %.1f" % bf_oval.semi_a)
		print("  Forest radius: %.1f" % forest_oval.semi_a)
		print("  Sum of radii: %.1f" % (bf_oval.semi_a + forest_oval.semi_a))
		if distance < (bf_oval.semi_a + forest_oval.semi_a) * 0.8:
			print("  ⚠️  OVALS ARE OVERLAPPING SIGNIFICANTLY!")
		elif distance > (bf_oval.semi_a + forest_oval.semi_a) * 1.5:
			print("  ✅ OVALS ARE WELL SEPARATED")
		else:
			print("  ✅ OVALS HAVE MILD OVERLAP (expected)")

	print("\n" + "=".repeat(80))
	print("✅ Debug test complete")
	print("=".repeat(80) + "\n")

	get_tree().quit()
