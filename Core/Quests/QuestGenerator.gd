class_name QuestGenerator
extends Node

## Procedural quest generation from faction bits + biome context
## Based on quest_demo.py - generates quests from faction axioms

# Quest system dependencies
const QuestVocabulary = preload("res://Core/Quests/QuestVocabulary.gd")
const FactionVoices = preload("res://Core/Quests/FactionVoices.gd")
const BiomeLocations = preload("res://Core/Quests/BiomeLocations.gd")

# =============================================================================
# CORE QUEST GENERATION
# =============================================================================

static func generate_quest(faction: Dictionary, biome_name: String, resources: Array) -> Dictionary:
	"""Generate quest from faction data and biome context

	Args:
		faction: {name: String, bits: Array[int], sig: Array[String]}
		biome_name: String (e.g., "BioticFlux")
		resources: Array[String] (available emoji resources in biome)

	Returns:
		Dictionary with complete quest data
	"""
	if resources.is_empty():
		push_error("Cannot generate quest: no resources available in biome %s" % biome_name)
		return {}

	var bits = faction["bits"]
	var faction_name = faction["name"]

	# Select resource from biome's available resources
	var resource = resources[randi() % resources.size()]

	# Determine quantity from bits
	var quantity = _get_quantity_from_bits(bits)

	# Select verb based on bit affinity
	var verb = _select_verb_for_bits(bits)

	# Get modifiers
	var adverb = _get_adverb(bits)
	var adjective = _get_adjective(bits)
	var urgency = _get_urgency(bits)
	var qty_word = QuestVocabulary.get_quantity_word(quantity)
	var location = BiomeLocations.get_random_location(biome_name)

	# Get faction voice
	var voice = FactionVoices.get_voice(faction_name)

	# Build quest text
	var body = _build_quest_body(verb, qty_word, adjective, resource, location, urgency, adverb)

	# Compose full quest
	# Convert signature array to string (first 3 emojis for display)
	# v2.1 uses "sig" not "signature" - check both for compatibility
	var sig = faction.get("sig", faction.get("signature", []))
	var faction_emoji = "".join(sig.slice(0, 3))

	return {
		"faction": faction_name,
		"faction_emoji": faction_emoji,
		"faction_signature": sig,  # Full signature array
		"prefix": voice["prefix"],
		"body": body,
		"suffix": voice["suffix"],
		"full_text": "%s %s %s" % [voice["prefix"], body, voice["suffix"]],
		"failure_text": voice["failure"],
		"time_limit": urgency["time"],
		"resource": resource,
		"quantity": quantity,
		"location": location,
		"verb": verb,
		"biome": biome_name,
		"urgency_emoji": urgency["emoji"],
		"bits": bits.duplicate(),
	}

# =============================================================================
# VERB SELECTION
# =============================================================================

static func _select_verb_for_bits(bits: Array) -> String:
	"""Select verb using bit affinity scoring

	Score = count of matching bits + randomness
	Higher score = better match to faction personality
	"""
	var best_verb = ""
	var best_score = -1.0

	for verb_name in QuestVocabulary.VERBS.keys():
		var verb_data = QuestVocabulary.VERBS[verb_name]
		var affinity = verb_data["affinity"]

		# Score = count of matching bits (where affinity is not null)
		var score = 0
		for i in range(12):
			if affinity[i] != null and affinity[i] == bits[i]:
				score += 1

		# Add randomness (0.0-0.5) to prevent always selecting same verb
		score += randf() * 0.5

		if score > best_score:
			best_score = score
			best_verb = verb_name

	return best_verb

# =============================================================================
# MODIFIER SELECTION
# =============================================================================

static func _get_adverb(bits: Array) -> String:
	"""Get adverb based on bits (40% chance to include)"""
	if randf() < 0.4:
		var idx = randi() % 12
		return QuestVocabulary.BIT_ADVERBS[idx][bits[idx]]
	return ""

static func _get_adjective(bits: Array) -> String:
	"""Get adjective based on bits"""
	var idx = randi() % 12
	return QuestVocabulary.BIT_ADJECTIVES[idx][bits[idx]]

# =============================================================================
# URGENCY & TIMING
# =============================================================================

static func _get_urgency(bits: Array) -> Dictionary:
	"""Get urgency from bits 0 and 4

	Bit 0: Random (0) vs Deterministic (1)
	Bit 4: Instant (0) vs Eternal (1)

	00 = eternal (no time limit)
	01 = before the cycle ends (120s)
	10 = when the signs align (180s)
	11 = immediately (60s)
	"""
	var key = "%d%d" % [bits[0], bits[4]]
	return QuestVocabulary.URGENCY[key]

# =============================================================================
# QUANTITY
# =============================================================================

static func _get_quantity_from_bits(bits: Array) -> int:
	"""Determine quantity from bits

	Bit 2: Common (0) vs Elite (1)
	Common factions ask for less, elite factions ask for more
	"""
	var is_common = bits[2] == 0
	if is_common:
		return randi() % 5 + 1  # 1-5
	else:
		return randi() % 8 + 5  # 5-13

# =============================================================================
# TEXT COMPOSITION
# =============================================================================

static func _build_quest_body(verb: String, qty: String, adj: String,
							   resource: String, location: String,
							   urgency: Dictionary, adverb: String = "") -> String:
	"""Build quest body text

	Frame selection based on bits:
	- Fluid (bit 6 = 1): alternate frame
	- Subtle (bit 7 = 1): covert frame
	- Instant (bit 4 = 0): urgent frame
	- Default: standard frame
	"""
	var body = ""

	# Include adverb if present
	var adv_text = (adverb + " ") if adverb != "" else ""

	# Build body (always use standard frame for now)
	body = "%s%s %s %s %s at %s" % [adv_text, verb.capitalize(), qty, adj, resource, location]

	# Add urgency if present
	if urgency["text"] != "":
		body += " " + urgency["text"]

	return body

# =============================================================================
# EMOJI-ONLY QUEST GENERATION
# =============================================================================

static func generate_emoji_quest(faction: Dictionary, biome_name: String, resources: Array) -> Dictionary:
	"""Generate pure emoji quest (zero English)

	Format: [faction_emoji]: [verb_emoji] [qty×resource] → [target] [urgency_emoji]
	Example: 🌾⚙️: 🔧 🌾×5 → 🏭 ⚡
	"""
	if resources.is_empty():
		return {}

	var bits = faction["bits"]
	var resource = resources[randi() % resources.size()]
	var quantity = _get_quantity_from_bits(bits)
	var urgency = _get_urgency(bits)
	var verb = _select_verb_for_bits(bits)
	var verb_emoji = QuestVocabulary.VERBS[verb]["emoji"]

	# Quantity display
	var qty_display = ""
	if quantity <= 3:
		qty_display = resource.repeat(quantity)
	else:
		qty_display = "%s×%d" % [resource, quantity]

	# Convert signature array to string and get first emoji
	# v2.1 uses "sig" not "signature" - check both for compatibility
	var sig = faction.get("sig", faction.get("signature", []))
	var faction_emoji = "".join(sig.slice(0, 3))
	var target_emoji = sig[0] if sig.size() > 0 else "❓"

	var display = "%s: %s %s → %s %s" % [
		faction_emoji,
		verb_emoji,
		qty_display,
		target_emoji,
		urgency["emoji"]
	]

	return {
		"faction": faction["name"],
		"faction_emoji": faction_emoji,
		"faction_signature": sig,  # Full signature array
		"display": display,
		"resource": resource,
		"quantity": quantity,
		"verb": verb,
		"time_limit": urgency["time"],
		"biome": biome_name,
		"is_emoji_only": true,
	}

# =============================================================================
# DEBUG / TESTING
# =============================================================================

static func test_generation() -> void:
	"""Test quest generation with sample faction"""
	print("🧪 Testing QuestGenerator...")

	var test_faction = {
		"name": "Millwright's Union",
		"bits": [1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
		"emoji": "🌾⚙️🏭"
	}

	var test_resources = ["🌾", "🍄", "💧"]

	var quest = generate_quest(test_faction, "BioticFlux", test_resources)

	print("Generated Quest:")
	print("  %s" % quest["full_text"])
	print("  Time: %d" % quest["time_limit"])
	print("  Resource: %s × %d" % [quest["resource"], quest["quantity"]])
	print("  Location: %s" % quest["location"])
	print("  Verb: %s" % quest["verb"])

	var emoji_quest = generate_emoji_quest(test_faction, "BioticFlux", test_resources)
	print("\nEmoji Quest:")
	print("  %s" % emoji_quest["display"])

	print("\n✅ QuestGenerator test complete")
