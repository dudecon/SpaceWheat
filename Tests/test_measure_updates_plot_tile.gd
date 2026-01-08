extends SceneTree

## Test that measuring a plot updates the plot tile visual
## Verifies the complete flow: measure → signal → PlotGridDisplay update → PlotTile visual change

func _init():
	print("🧪 Testing Measurement → Plot Tile Update")
	print("================================================================================\n")

	# Load FarmView scene
	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		print("❌ Failed to load scene")
		quit()
		return

	var root = scene.instantiate()
	get_root().add_child(root)

	# Wait for initialization
	print("⏳ Waiting for initialization...")
	await create_timer(2.5).timeout

	# Find components
	var farm_view = _find_node(root, "FarmView")
	var farm = _find_node(root, "Farm")
	var plot_grid_display = _find_node(root, "PlotGridDisplay")

	print("\n📍 Components:")
	print("   FarmView: %s" % ("✅" if farm_view else "❌"))
	print("   Farm: %s" % ("✅" if farm else "❌"))
	print("   PlotGridDisplay: %s" % ("✅" if plot_grid_display else "❌"))

	if not farm or not plot_grid_display:
		print("\n❌ Missing required components")
		quit()
		return

	# Test position
	var test_pos = Vector2i(0, 0)

	print("\n🧪 Test Sequence:")
	print("1. Plant wheat at %s" % test_pos)
	print("2. Check plot tile shows superposition (both emojis)")
	print("3. Measure the plot")
	print("4. Check plot tile updates to show single emoji\n")

	# Step 1: Plant wheat
	print("Step 1: Planting wheat...")
	if farm.has_method("plant_wheat"):
		farm.plant_wheat(test_pos)
		await create_timer(0.3).timeout
		print("   ✅ Wheat planted")
	else:
		print("   ❌ farm.plant_wheat() not found")
		quit()
		return

	# Step 2: Check tile shows superposition
	print("\nStep 2: Checking superposition state...")
	var tile_before = _get_tile(plot_grid_display, test_pos)
	if tile_before:
		var north_text = tile_before.emoji_label_north.text
		var south_text = tile_before.emoji_label_south.text
		var north_alpha = tile_before.emoji_label_north.modulate.a
		var south_alpha = tile_before.emoji_label_south.modulate.a

		print("   North emoji: '%s' (alpha=%.2f)" % [north_text, north_alpha])
		print("   South emoji: '%s' (alpha=%.2f)" % [south_text, south_alpha])

		if north_text != "" and south_text != "" and north_alpha > 0 and south_alpha > 0:
			print("   ✅ Tile shows superposition (both emojis visible)")
		else:
			print("   ⚠️  Tile doesn't show clear superposition")
	else:
		print("   ❌ Tile not found")

	# Step 3: Measure the plot
	print("\nStep 3: Measuring plot...")

	# Check if plot_measured signal exists
	if farm.has_signal("plot_measured"):
		print("   ✅ farm.plot_measured signal exists")
	else:
		print("   ❌ farm.plot_measured signal missing!")
		quit()
		return

	# Check if PlotGridDisplay is connected to plot_measured
	var is_connected = false
	if farm.plot_measured.is_connected(Callable(plot_grid_display, "_on_farm_plot_measured")):
		is_connected = true
		print("   ✅ PlotGridDisplay connected to plot_measured")
	else:
		print("   ❌ PlotGridDisplay NOT connected to plot_measured!")
		print("   ⚠️  This is the bug - measurement won't update tile visual")

	var outcome = ""
	if farm.has_method("measure_plot"):
		outcome = farm.measure_plot(test_pos)
		await create_timer(0.3).timeout
		print("   ✅ Measured: %s" % outcome)
	else:
		print("   ❌ farm.measure_plot() not found")
		quit()
		return

	# Step 4: Check tile updated
	print("\nStep 4: Checking if tile updated after measurement...")
	var tile_after = _get_tile(plot_grid_display, test_pos)
	if tile_after:
		var north_text_after = tile_after.emoji_label_north.text
		var south_text_after = tile_after.emoji_label_south.text
		var north_alpha_after = tile_after.emoji_label_north.modulate.a
		var south_alpha_after = tile_after.emoji_label_south.modulate.a

		print("   North emoji: '%s' (alpha=%.2f)" % [north_text_after, north_alpha_after])
		print("   South emoji: '%s' (alpha=%.2f)" % [south_text_after, south_alpha_after])

		# After measurement, should show single emoji at full opacity
		var single_emoji = (south_text_after == "") or (north_text_after == "")
		var full_opacity = (north_alpha_after == 1.0) or (south_alpha_after == 1.0)

		if single_emoji and full_opacity:
			print("   ✅ PASS: Tile updated to show single emoji (%s)" % outcome)
			print("\n✅ TEST PASSED: Measurement updates plot tile correctly")
		else:
			print("   ❌ FAIL: Tile still shows superposition or wrong opacity")
			if not is_connected:
				print("\n❌ ROOT CAUSE: PlotGridDisplay not connected to farm.plot_measured signal")
				print("   FIX NEEDED: Add connection in PlotGridDisplay.set_farm()")
			else:
				print("\n❌ TEST FAILED: Tile didn't update despite signal connection")
	else:
		print("   ❌ Tile not found after measurement")

	quit()


func _find_node(parent: Node, name_contains: String) -> Node:
	"""Find node by name or script path"""
	if name_contains.to_lower() in parent.name.to_lower():
		return parent

	if parent.get_script():
		var script_path = parent.get_script().resource_path
		if name_contains in script_path:
			return parent

	for child in parent.get_children():
		var result = _find_node(child, name_contains)
		if result:
			return result

	return null


func _get_tile(plot_grid_display, pos: Vector2i):
	"""Get PlotTile at position"""
	if not plot_grid_display or not plot_grid_display.has_method("get_tile"):
		return null

	# Try direct access via tiles dictionary
	if plot_grid_display.get("tiles"):
		var tiles = plot_grid_display.tiles
		if tiles.has(pos):
			return tiles[pos]

	return null
