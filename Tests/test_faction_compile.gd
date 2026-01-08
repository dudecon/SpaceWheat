extends SceneTree

func _init():
	print("=== Testing Faction System Compilation ===")

	# Test 1: Load IconFaction
	var IconFaction = load("res://Core/Factions/Faction.gd")
	if IconFaction:
		print("✓ IconFaction.gd loaded")
	else:
		print("✗ IconFaction.gd failed to load")

	# Test 2: Load CoreFactions
	var CoreFactions = load("res://Core/Factions/CoreFactions.gd")
	if CoreFactions:
		print("✓ CoreFactions.gd loaded")
	else:
		print("✗ CoreFactions.gd failed to load")

	# Test 3: Load IconBuilder
	var IconBuilder = load("res://Core/Factions/IconBuilder.gd")
	if IconBuilder:
		print("✓ IconBuilder.gd loaded")
	else:
		print("✗ IconBuilder.gd failed to load")

	# Test 4: Create a faction
	if CoreFactions:
		var celestial = CoreFactions.create_celestial_archons()
		if celestial:
			print("✓ Created Celestial Archons faction: %s" % celestial.name)
			print("  Signature: %s" % str(celestial.signature))
		else:
			print("✗ Failed to create faction")

	print("\n=== Faction System Tests Complete ===")
	quit()
