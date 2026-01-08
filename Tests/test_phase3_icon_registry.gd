extends SceneTree

## Phase 3 test: Verify IconRegistry builds from factions

func _init():
	print("=== Phase 3: Testing IconRegistry Faction Building ===")

	# Check if IconRegistry autoload exists
	var icon_registry = null
	if root.has_node("IconRegistry"):
		icon_registry = root.get_node("IconRegistry")

	if icon_registry == null:
		print("⚠️ IconRegistry not found as autoload, testing manually...")

		# Manually create and test
		var IconRegistryScript = load("res://Core/QuantumSubstrate/IconRegistry.gd")
		icon_registry = Node.new()
		icon_registry.set_script(IconRegistryScript)
		root.add_child(icon_registry)

	print("\n--- Test 1: IconRegistry Loaded ---")
	print("✓ IconRegistry available")

	print("\n--- Test 2: Faction-built Icons ---")
	var icon_count = icon_registry.icons.size()
	print("  Icons registered: %d" % icon_count)

	if icon_count > 0:
		print("✓ Icons were built from factions")
	else:
		print("✗ No icons registered!")

	print("\n--- Test 3: Check Key Icons Exist ---")
	var test_emojis = ["☀", "🌙", "🌾", "🍄", "💀", "🔥", "💧", "🐝", "🦠"]
	var found = 0
	var missing: Array = []
	for emoji in test_emojis:
		if icon_registry.has_icon(emoji):
			found += 1
		else:
			missing.append(emoji)

	print("  Found %d/%d test icons" % [found, test_emojis.size()])
	if missing.size() > 0:
		print("  Missing: %s" % str(missing))
	else:
		print("✓ All expected icons present")

	print("\n--- Test 4: Sample Icon Properties ---")
	var sun_icon = icon_registry.get_icon("☀")
	if sun_icon:
		print("  ☀ Sun icon:")
		print("    display_name: %s" % sun_icon.display_name)
		print("    self_energy: %.3f" % sun_icon.self_energy)
		print("    is_driver: %s" % sun_icon.is_driver)
		var desc = sun_icon.description if sun_icon.description.length() < 50 else sun_icon.description.substr(0, 50)
		print("    description: %s" % desc)
		print("✓ Icon properties accessible")
	else:
		print("✗ Sun icon not found")

	print("\n=== Phase 3 Tests Complete ===")
	quit()
