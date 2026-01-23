extends SceneTree

func _init():
	print("=== Testing Faction System Compilation ===")

	# Test 1: Load Faction
	var Faction = load("res://Core/Factions/Faction.gd")
	if Faction:
		print("✓ Faction.gd loaded")
	else:
		print("✗ Faction.gd failed to load")

	# Test 2: Load FactionRegistry
	var FactionRegistry = load("res://Core/Factions/FactionRegistry.gd")
	if FactionRegistry:
		print("✓ FactionRegistry.gd loaded")
	else:
		print("✗ FactionRegistry.gd failed to load")

	# Test 3: Load IconBuilder
	var IconBuilder = load("res://Core/Factions/IconBuilder.gd")
	if IconBuilder:
		print("✓ IconBuilder.gd loaded")
	else:
		print("✗ IconBuilder.gd failed to load")

	# Test 4: Load AllFactions (backward-compatible wrapper)
	var AllFactions = load("res://Core/Factions/AllFactions.gd")
	if AllFactions:
		print("✓ AllFactions.gd loaded")
	else:
		print("✗ AllFactions.gd failed to load")

	# Test 5: Create registry and get a faction
	if FactionRegistry:
		var registry = FactionRegistry.new()
		var celestial = registry.get_by_name("Celestial Archons")
		if celestial:
			print("✓ Retrieved Celestial Archons faction: %s" % celestial.name)
			print("  Signature: %s" % str(celestial.signature))
		else:
			print("✗ Failed to retrieve faction")

		print("  Total factions: %d" % registry.get_all().size())

	print("\n=== Faction System Tests Complete ===")
	quit()
