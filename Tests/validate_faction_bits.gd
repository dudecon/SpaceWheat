#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Validate faction bit encodings
## Decode all 32 factions and verify bits match personalities

const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")

# Bit encoding reference
const BIT_MEANINGS = [
	["Random", "Deterministic"],           # 0
	["Material", "Mystical"],              # 1
	["Common", "Elite"],                   # 2
	["Local", "Cosmic"],                   # 3
	["Instant", "Eternal"],                # 4
	["Physical", "Mental"],                # 5
	["Crystalline", "Fluid"],              # 6
	["Direct", "Subtle"],                  # 7
	["Consumptive", "Providing"],          # 8
	["Monochrome", "Prismatic"],           # 9
	["Emergent", "Imposed"],               # 10
	["Scattered", "Focused"],              # 11
]

func _init():
	print("\n" + "=".repeat(80))
	print("📋 FACTION BIT VALIDATION - ALL 32 FACTIONS")
	print("=".repeat(80))

	validate_all_factions()

	quit(0)


func validate_all_factions():
	"""Validate all factions and output corrected doc format"""

	var categories = [
		["IMPERIAL POWERS", FactionDatabase.FACTIONS_BY_CATEGORY["Imperial Powers"]],
		["WORKING GUILDS & SERVICES", FactionDatabase.FACTIONS_BY_CATEGORY["Working Guilds"]],
		["MYSTIC ORDERS", FactionDatabase.FACTIONS_BY_CATEGORY["Mystic Orders"]],
		["MERCHANTS & TRADERS", FactionDatabase.FACTIONS_BY_CATEGORY["Merchants & Traders"]],
		["MILITANT ORDERS", FactionDatabase.FACTIONS_BY_CATEGORY["Militant Orders"]],
		["SCAVENGER FACTIONS", FactionDatabase.FACTIONS_BY_CATEGORY["Scavenger Factions"]],
		["HORROR CULTS", FactionDatabase.FACTIONS_BY_CATEGORY["Horror Cults"]],
		["DEFENSIVE COMMUNITIES", FactionDatabase.FACTIONS_BY_CATEGORY["Defensive Communities"]],
		["COSMIC MANIPULATORS", FactionDatabase.FACTIONS_BY_CATEGORY["Cosmic Manipulators"]],
		["ULTIMATE COSMIC ENTITIES", FactionDatabase.FACTIONS_BY_CATEGORY["Ultimate Cosmic Entities"]],
	]

	for category_data in categories:
		var category_name = category_data[0]
		var factions = category_data[1]

		print("\n" + "=".repeat(80))
		print("## %s" % category_name)
		print("=".repeat(80))

		for faction in factions:
			validate_faction(faction)


func validate_faction(faction: Dictionary):
	"""Validate single faction and output corrected format"""

	var name = faction.get("name", "Unknown")
	var emoji = faction.get("emoji", "")
	var bits = faction.get("bits", [])
	var description = faction.get("description", "")

	# Decode bits
	var axiom_words = decode_bits(bits)
	var pattern = bits_to_pattern(bits)

	# Output faction entry
	print("\n### %s %s" % [name, emoji])
	print("%s" % description)
	print("**Axiom words**: %s" % ", ".join(axiom_words))
	print("**Pattern**: `%s`" % pattern)
	print("**Bits array**: %s" % str(bits))

	# Analyze if bits make sense
	analyze_faction_coherence(name, axiom_words, description)


func decode_bits(bits: Array) -> Array:
	"""Decode bit array to axiom words"""
	var words = []

	for i in range(min(bits.size(), BIT_MEANINGS.size())):
		var bit_value = bits[i]
		var meaning_pair = BIT_MEANINGS[i]

		# bit=0 → first word, bit=1 → second word
		var word = meaning_pair[bit_value]
		words.append(word)

	return words


func bits_to_pattern(bits: Array) -> String:
	"""Convert bit array to pattern string"""
	var pattern = ""
	for bit in bits:
		pattern += str(bit)
	return pattern


func analyze_faction_coherence(name: String, axiom_words: Array, description: String):
	"""Analyze if decoded bits make sense for faction personality"""

	var notes = []

	# Check for interesting combinations
	if "Material" in axiom_words and "Mystical" in axiom_words:
		notes.append("⚠️  Has both Material and Mystical?")

	if "Random" in axiom_words and "Deterministic" in axiom_words:
		notes.append("⚠️  Has both Random and Deterministic?")

	# Check if mystical factions have mystical bit
	var desc_lower = description.to_lower()
	if "mystic" in desc_lower or "ritual" in desc_lower or "consciousness" in desc_lower:
		if not "Mystical" in axiom_words:
			notes.append("🤔 Mystical description but Material bit")

	# Check if mechanical factions have material bit
	if "mechanical" in desc_lower or "tool" in desc_lower or "machine" in desc_lower:
		if not "Material" in axiom_words:
			notes.append("🤔 Mechanical description but Mystical bit")

	# Check elite vs common
	if "aristocrat" in desc_lower or "imperial" in desc_lower or "ruling" in desc_lower:
		if not "Elite" in axiom_words:
			notes.append("🤔 Elite description but Common bit")

	if "working" in desc_lower or "guild" in desc_lower:
		if "Elite" in axiom_words:
			notes.append("🤔 Working description but Elite bit")

	# Output notes if any
	if notes.size() > 0:
		print("  **Analysis**: %s" % ", ".join(notes))
