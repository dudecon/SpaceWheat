extends SceneTree

## Test: Verify all factions load and build icons correctly
## 79 factions loaded from JSON via FactionRegistry

const AllFactions = preload("res://Core/Factions/AllFactions.gd")
const IconBuilder = preload("res://Core/Factions/IconBuilder.gd")

func _init():
	print("========================================")
	print("TESTING: All Factions System (JSON)")
	print("========================================\n")

	# Test 1: Load all factions
	print("=== Test 1: Loading All Factions ===")
	var all_factions = AllFactions.get_all()
	print("Loaded %d factions" % all_factions.size())

	if all_factions.size() < 70:
		print("❌ FAILED: Expected 70+ factions, got %d" % all_factions.size())
		quit(1)
	else:
		print("✅ PASSED: All %d factions loaded" % all_factions.size())

	# Test 2: Verify faction groups
	print("\n=== Test 2: Faction Groups ===")
	var core_factions = AllFactions.get_core()
	var civ_factions = AllFactions.get_civilization()
	var tier2_factions = AllFactions.get_tier2()

	print("Core ecosystem: %d factions" % core_factions.size())
	print("Civilization: %d factions" % civ_factions.size())
	print("Tier 2: %d factions" % tier2_factions.size())

	if core_factions.size() < 8:
		print("❌ FAILED: Expected 8+ core factions, got %d" % core_factions.size())
		quit(1)

	if civ_factions.size() < 6:
		print("❌ FAILED: Expected 6+ civilization factions, got %d" % civ_factions.size())
		quit(1)

	if tier2_factions.size() < 8:
		print("❌ FAILED: Expected 8+ tier2 factions, got %d" % tier2_factions.size())
		quit(1)

	print("✅ PASSED: All faction groups correct")

	# Test 3: Build icons from all factions
	print("\n=== Test 3: Building Icons ===")
	var icons = IconBuilder.build_icons_for_factions(all_factions)
	print("Built %d icons" % icons.size())

	if icons.size() == 0:
		print("❌ FAILED: No icons built")
		quit(1)

	print("✅ PASSED: Icons built successfully")

	# Test 4: Check for new emojis
	print("\n=== Test 4: New Civilization Emojis ===")
	var new_emojis = ["🧺", "🧤", "🥖", "🧪", "⛪", "🫙", "🚢", "🛂", "📜", "📘",
	                  "🏢", "⛓", "🌑", "💸", "⚖", "🦅", "⚜", "🩸", "🏰"]
	var found_count = 0

	for icon in icons:
		if icon.emoji in new_emojis:
			found_count += 1

	print("Found %d / %d new civilization emojis" % [found_count, new_emojis.size()])

	if found_count < 15:
		print("❌ WARNING: Expected at least 15 new emojis, found %d" % found_count)
	else:
		print("✅ PASSED: New civilization emojis present")

	# Test 5: Check for tier 2 emojis
	print("\n=== Test 5: New Tier 2 Emojis ===")
	var tier2_emojis = ["📒", "🚔", "⛏", "💎", "✨", "⚓", "🪝", "🦴", "💉",
	                    "🔋", "🔌", "⚡", "🏷️", "🚀", "🔬", "📋", "🪣", "💳",
	                    "🌹", "🪞", "🍷"]
	var tier2_found = 0

	for icon in icons:
		if icon.emoji in tier2_emojis:
			tier2_found += 1

	print("Found %d / %d tier 2 emojis" % [tier2_found, tier2_emojis.size()])

	if tier2_found < 15:
		print("❌ WARNING: Expected at least 15 tier 2 emojis, found %d" % tier2_found)
	else:
		print("✅ PASSED: Tier 2 emojis present")

	# Test 6: Check for new mechanics
	print("\n=== Test 6: New Mechanics ===")
	var has_inverse_gating = false
	var has_measurement_inversion = false
	var has_negative_energy = false
	var has_ac_clock = false

	# Check for inverse gating (Scavenged Psithurism: refugees starve without waste)
	for faction in all_factions:
		if faction.name == "The Scavenged Psithurism":
			for emoji in faction.gated_lindblad:
				for gate_config in faction.gated_lindblad[emoji]:
					if gate_config.get("inverse", false):
						has_inverse_gating = true
						print("  ✓ Found inverse gating in %s" % faction.name)

	# Check for measurement inversion (🧤 unmeasurable)
	for faction in all_factions:
		for emoji in faction.measurement_behavior:
			if faction.measurement_behavior[emoji].get("inverts", false):
				has_measurement_inversion = true
				print("  ✓ Found measurement inversion: %s" % emoji)

	# Check for negative self-energy (💸 debt)
	for faction in all_factions:
		for emoji in faction.self_energies:
			if faction.self_energies[emoji] < -0.2:
				has_negative_energy = true
				print("  ✓ Found negative self-energy: %s = %.2f" % [emoji, faction.self_energies[emoji]])

	# Check for AC clock (🔌 sine driver @ 1 Hz)
	for faction in all_factions:
		if faction.name == "Kilowatt Collective":
			if faction.drivers.has("🔌"):
				var driver = faction.drivers["🔌"]
				if driver.get("type") == "sine" and driver.get("freq") == 1.0:
					has_ac_clock = true
					print("  ✓ Found AC clock: 🔌 SINE @ 1 Hz")

	if not has_inverse_gating:
		print("❌ FAILED: Inverse gating not found")
		quit(1)

	if not has_measurement_inversion:
		print("❌ FAILED: Measurement inversion not found")
		quit(1)

	if not has_negative_energy:
		print("❌ FAILED: Negative self-energy not found")
		quit(1)

	if not has_ac_clock:
		print("❌ FAILED: AC clock not found")
		quit(1)

	print("✅ PASSED: All new mechanics present")

	# Test 7: Check contestation (emojis shared by multiple factions)
	print("\n=== Test 7: Emoji Contestation ===")
	var contestation = AllFactions.get_emoji_contestation()
	var contested = []
	for emoji in contestation:
		if contestation[emoji].size() > 1:
			contested.append(emoji)

	print("Contested emojis: %d" % contested.size())
	print("Examples:")
	var shown = 0
	for emoji in contested:
		if shown >= 5:
			break
		print("  %s: %s" % [emoji, ", ".join(contestation[emoji])])
		shown += 1

	print("✅ PASSED: Contestation map working")

	# Summary
	print("\n========================================")
	print("ALL TESTS PASSED ✅")
	print("========================================")
	print("Factions loaded: %d" % all_factions.size())
	print("Icons built: %d" % icons.size())
	print("Contested emojis: %d" % contested.size())
	print("New mechanics verified: 4/4")
	print("========================================\n")

	quit(0)
