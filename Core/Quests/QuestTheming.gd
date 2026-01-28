class_name QuestTheming
extends RefCounted

## GAME-SPECIFIC THEMING (SpaceWheat)
## Maps abstract QuestParameters -> concrete quest data
## THIS is where emojis and game content live!
##
## Abstract inputs: alignment, intensity, complexity, urgency, variety
## SpaceWheat outputs: resource emoji, quantity, time_limit, reward_multiplier

const FactionStateMatcher = preload("res://Core/QuantumSubstrate/FactionStateMatcher.gd")
const QuestTypes = preload("res://Core/Quests/QuestTypes.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const VocabularyPairing = preload("res://Core/Quests/VocabularyPairing.gd")

# Light bias toward simulated vocab when selecting north pole.
const NORTH_BIAS_WEIGHT: float = 1.3

## Safe VerboseConfig accessor for RefCounted classes (no scene tree access)
static func _log(level: String, category: String, emoji: String, message: String) -> void:
	var tree = Engine.get_main_loop()
	if tree and tree.root and tree.root.has_node("VerboseConfig"):
		var logger = tree.root.get_node("VerboseConfig")
		match level:
			"debug": logger.debug(category, emoji, message)
			"info": logger.info(category, emoji, message)
			"warn": logger.warn(category, emoji, message)
			"error": logger.error(category, emoji, message)


static func apply_theming(params: FactionStateMatcher.QuestParameters, bath) -> Dictionary:
	"""Map abstract parameters to SpaceWheat quest

	Chooses quest type based on complexity and generates appropriate quest
	"""

	# Choose quest type based on abstract parameters
	var quest_type = _select_quest_type(params)

	# Generate quest based on type
	var quest: Dictionary

	match quest_type:
		QuestTypes.Type.DELIVERY:
			quest = _generate_delivery_quest(params, bath)
		QuestTypes.Type.SHAPE_ACHIEVE:
			quest = _generate_shape_achieve_quest(params)
		QuestTypes.Type.SHAPE_MAINTAIN:
			quest = _generate_shape_maintain_quest(params)
		QuestTypes.Type.EVOLUTION:
			quest = _generate_evolution_quest(params)
		QuestTypes.Type.ENTANGLEMENT:
			quest = _generate_entanglement_quest(params)
		_:
			quest = _generate_delivery_quest(params, bath)  # Fallback

	# Add quest type
	quest["type"] = quest_type

	return quest


static func _select_quest_type(params: FactionStateMatcher.QuestParameters) -> int:
	"""Choose quest type based on abstract parameters

	High complexity → shape/evolution quests (teach quantum manipulation)
	Medium complexity → mix
	Low complexity → mostly delivery (familiar gameplay)
	"""

	# High complexity: Advanced quantum quests
	if params.complexity > 0.7:
		if randf() < 0.5:
			return QuestTypes.Type.SHAPE_MAINTAIN
		else:
			return QuestTypes.Type.EVOLUTION

	# Medium complexity: Mix of types
	elif params.complexity > 0.4:
		var roll = randf()
		if roll < 0.5:
			return QuestTypes.Type.DELIVERY
		elif roll < 0.75:
			return QuestTypes.Type.SHAPE_ACHIEVE
		else:
			return QuestTypes.Type.ENTANGLEMENT

	# Low complexity: Mostly delivery (80%)
	else:
		return QuestTypes.Type.DELIVERY if randf() < 0.8 else QuestTypes.Type.SHAPE_ACHIEVE


static func _generate_delivery_quest(params: FactionStateMatcher.QuestParameters, bath) -> Dictionary:
	"""Generate traditional delivery quest (current system)"""

	# intensity → quantity in CREDITS (10-50 range)
	# This matches the economy where pop gives: probability × 10 = credits
	var base_units = 1 + int(params.intensity * 4)  # 1-5 base
	var quantity = base_units * 10  # Convert to credits: 10-50

	# Sample resource from ALLOWED emojis only (vocabulary constraint!)
	var allowed_emojis = params.available_emojis if params.available_emojis.size() > 0 else []
	var resource = _sample_from_allowed_emojis(bath, allowed_emojis, params)

	# urgency → time limit
	var time_limit = _urgency_to_time(params.urgency)

	# alignment → reward multiplier
	var reward_mult = lerp(1.5, 5.0, params.alignment)

	return {
		"resource": resource,
		"quantity": quantity,
		"time_limit": time_limit,
		"reward_multiplier": reward_mult,
		"_alignment": params.alignment,
		"_intensity": params.intensity,
		"_complexity": params.complexity,
		"_urgency": params.urgency,
		"_variety": params.variety,
	}


static func _generate_shape_achieve_quest(params: FactionStateMatcher.QuestParameters) -> Dictionary:
	"""Generate 'achieve purity > X' style quest"""

	# Pick observable based on variety
	var observable = _pick_observable_from_variety(params.variety)
	var target_value = _calculate_target_value(params, observable)

	# Entropy quests want LOW values (entropy < X), others want HIGH (observable > X)
	var comparison = "<" if observable == "entropy" else ">"

	return {
		"observable": observable,  # "purity", "entropy", or "coherence"
		"target": target_value,
		"comparison": comparison,  # "<" for entropy, ">" for purity/coherence
		"reward_multiplier": lerp(2.0, 4.0, params.alignment),
		"time_limit": -1,  # No time limit for achievement
		"_alignment": params.alignment,
		"_intensity": params.intensity,
		"_complexity": params.complexity,
		"_urgency": params.urgency,
	}


static func _generate_shape_maintain_quest(params: FactionStateMatcher.QuestParameters) -> Dictionary:
	"""Generate 'maintain entropy < X for 30s' style quest"""

	var quest = _generate_shape_achieve_quest(params)
	quest["duration"] = 30.0  # Maintain for 30 seconds
	quest["reward_multiplier"] *= 1.5  # Higher reward for maintenance
	quest["elapsed"] = 0.0  # Track how long maintained

	return quest


static func _generate_evolution_quest(params: FactionStateMatcher.QuestParameters) -> Dictionary:
	"""Generate 'increase coherence by 0.3' style quest"""

	var observable = _pick_observable_from_variety(params.variety)
	var delta = lerp(0.1, 0.5, params.intensity)
	var direction = "increase" if randf() < 0.5 else "decrease"

	return {
		"observable": observable,
		"delta": delta,
		"direction": direction,
		"reward_multiplier": lerp(2.5, 5.0, params.alignment),
		"time_limit": lerp(120.0, 300.0, 1.0 - params.urgency) if params.urgency > 0.2 else -1,
		"initial_value": null,  # Will be set when quest starts
		"_alignment": params.alignment,
		"_intensity": params.intensity,
		"_complexity": params.complexity,
		"_urgency": params.urgency,
	}


static func _generate_entanglement_quest(params: FactionStateMatcher.QuestParameters) -> Dictionary:
	"""Generate 'create coherence > 0.6' quest"""

	return {
		"target_coherence": lerp(0.4, 0.8, params.intensity),
		"reward_multiplier": lerp(3.0, 6.0, params.alignment),
		"time_limit": -1,
		"_alignment": params.alignment,
		"_intensity": params.intensity,
		"_complexity": params.complexity,
	}


static func _pick_observable_from_variety(variety: float) -> String:
	"""Choose which observable based on variety parameter"""
	var roll = randf()

	if roll < 0.4:
		return "purity"
	elif roll < 0.7:
		return "entropy"
	else:
		return "coherence"


static func _calculate_target_value(params: FactionStateMatcher.QuestParameters, observable: String) -> float:
	"""Calculate target value based on intensity and observable type"""

	match observable:
		"purity":
			# High purity = ordered state
			return lerp(0.6, 0.95, params.intensity)
		"entropy":
			# High entropy = chaotic state
			return lerp(0.5, 0.9, params.intensity)
		"coherence":
			# High coherence = quantum entanglement
			return lerp(0.3, 0.7, params.intensity)

	return 0.7  # Fallback


static func _index_to_emoji(bath, index: int) -> String:
	"""Map basis index to emoji from bath's emoji list"""
	if bath == null:
		return _fallback_emoji(index)

	var density_matrix = bath.get("_density_matrix")
	if density_matrix == null:
		return _fallback_emoji(index)

	var emoji_list = density_matrix.emoji_list
	if index >= 0 and index < emoji_list.size():
		return emoji_list[index]

	return emoji_list[0] if emoji_list.size() > 0 else _fallback_emoji(index)


static func _fallback_emoji(index: int) -> String:
	"""Fallback when bath is unavailable - SpaceWheat defaults"""
	var fallbacks = ["🌾", "🍄", "💨", "🍂", "💰", "👥", "🌻"]
	return fallbacks[index % fallbacks.size()]


static func _sample_from_allowed_emojis(bath, allowed_emojis: Array, params) -> String:
	"""Sample emoji from bath's probability distribution, constrained to allowed vocabulary

	Strategy:
	1. Get bath's probability distribution
	2. Filter to only allowed emojis
	3. Renormalize probabilities
	4. Sample from filtered distribution

	If no bath or no probabilities, picks randomly from allowed emojis.
	"""

	if allowed_emojis.is_empty():
		_log("warn", "quest", "⚠️", "Empty allowed_emojis - fallback to 🌾")
		return "🌾"  # Ultimate fallback

	# No bath? Pick random from allowed
	if bath == null:
		var chosen = allowed_emojis[randi() % allowed_emojis.size()]
		_log("debug", "quest", "🎲", "No bath - random from allowed: %s" % chosen)
		return chosen

	var density_matrix = bath.get("_density_matrix")
	if density_matrix == null:
		var chosen = allowed_emojis[randi() % allowed_emojis.size()]
		_log("debug", "quest", "🎲", "No density matrix - random from allowed: %s" % chosen)
		return chosen

	# Get bath emoji list
	var bath_emojis = density_matrix.emoji_list

	# Find indices of allowed emojis in bath
	var allowed_indices = []
	var allowed_probs = []

	for i in range(bath_emojis.size()):
		if bath_emojis[i] in allowed_emojis:
			allowed_indices.append(i)
			allowed_probs.append(density_matrix.get_probability_by_index(i))

	# If no allowed emojis in bath, pick from allowed randomly
	if allowed_indices.is_empty():
		var chosen = allowed_emojis[randi() % allowed_emojis.size()]
		_log("debug", "quest", "🎲", "No overlap with bath - random from allowed: %s" % chosen)
		return chosen

	# Renormalize probabilities
	var total = 0.0
	for p in allowed_probs:
		total += p

	if total < 0.001:
		# No probability mass in allowed emojis, pick random
		return allowed_emojis[randi() % allowed_emojis.size()]

	for i in range(allowed_probs.size()):
		allowed_probs[i] /= total

	# Sample from renormalized distribution
	var roll = randf()
	var cumulative = 0.0
	for i in range(allowed_probs.size()):
		cumulative += allowed_probs[i]
		if roll <= cumulative:
			var chosen = bath_emojis[allowed_indices[i]]
			_log("debug", "quest", "🎯", "Sampled %s (p=%.3f, roll=%.3f) from bath" % [chosen, allowed_probs[i], roll])
			return chosen

	# Fallback
	var fallback = bath_emojis[allowed_indices[0]]
	_log("debug", "quest", "🎲", "Fallback to first allowed: %s" % fallback)
	return fallback


static func _urgency_to_time(urgency: float) -> float:
	"""Map urgency [0,1] to SpaceWheat time limits"""
	if urgency < 0.2:
		return -1  # No time limit
	elif urgency < 0.5:
		return 180  # Relaxed (3 minutes)
	elif urgency < 0.8:
		return 120  # Moderate (2 minutes)
	else:
		return 60   # Urgent (1 minute)


static func generate_quest(
	faction: Dictionary,
	bath,
	player_vocab: Array = [],
	bias_emojis: Array = []
) -> Dictionary:
	"""Full pipeline: faction x bath -> themed quest

	Args:
		faction: Faction data with bits and signature
		bath: Current biome quantum state
		player_vocab: Emojis the player knows (for vocabulary filtering)
		bias_emojis: Optional emojis to bias toward for north pole selection

	Returns:
		Quest dict, or error if no vocabulary overlap
	"""

	# 1. Get faction's complete vocabulary
	var faction_vocab = FactionDatabase.get_faction_vocabulary(faction)
	var faction_name = faction.get("name", "Unknown")

	_log("debug", "quest", "📚", "Quest gen: %s signature=%s axial=%s" % [
		faction_name,
		"".join(faction_vocab.signature),
		"".join(faction_vocab.axial.slice(0, 3)) + "..."
	])

	# 2. Find overlap with player's known vocabulary
	# NEW DESIGN: Quest resources come from SIGNATURE ONLY (not axial vocabulary)
	# This makes factions feel distinct and prevents "everyone wants wheat" problem
	var available_emojis = []
	if player_vocab.is_empty():
		# No filtering - use signature only (backward compatibility for tests)
		available_emojis = faction_vocab.signature
		_log("debug", "quest", "🎲", "No player vocab filter - using full signature")
	else:
		# Filter signature to player's known vocabulary
		available_emojis = FactionDatabase.get_vocabulary_overlap(faction_vocab.signature, player_vocab)
		_log("debug", "quest", "🔍", "Player knows %s, faction signature %s → available %s" % [
			"".join(player_vocab),
			"".join(faction_vocab.signature),
			"".join(available_emojis)
		])

	# 3. If no overlap, faction is inaccessible!
	if available_emojis.is_empty():
		_log("debug", "quest", "🚫", "%s inaccessible - no signature overlap with player vocab" % faction_name)
		return {
			"error": "no_vocabulary_overlap",
			"message": "Learn more about %s's interests first..." % faction.get("name", "Unknown"),
			"faction": faction.get("name", "Unknown"),
			"required_emojis": faction_vocab.signature.slice(0, 3),  # Hint: signature emojis
			"faction_vocabulary": faction_vocab.signature  # Show signature, not axial
		}

	# 4. Extract abstract observables
	var obs = FactionStateMatcher.extract_observables(bath)

	# 5. Generate abstract parameters
	var faction_bits = faction.get("bits", [0,0,0,0,0,0,0,0,0,0,0,0])
	var params = FactionStateMatcher.generate_quest_parameters(faction_bits, obs, bath)

	# 6. Add vocabulary constraint to params
	params.available_emojis = available_emojis

	# 7. Apply SpaceWheat theming (quest resources MUST come from available_emojis)
	var quest = apply_theming(params, bath)

	# 8. Add faction metadata
	quest["faction"] = faction.get("name", "Unknown")
	var signature = faction.get("sig", faction.get("signature", []))  # v2.1 uses "sig" not "signature"
	quest["faction_emoji"] = "".join(signature.slice(0, 3))
	quest["faction_signature"] = signature
	quest["bits"] = faction_bits

	# v2.1 fields
	quest["motto"] = faction.get("motto", null)
	quest["domain"] = faction.get("domain", "Unknown")
	quest["ring"] = faction.get("ring", "unknown")
	quest["description"] = faction.get("description", "")

	# Banner asset path (if available)
	quest["banner_path"] = FactionDatabase.get_faction_banner_path(faction)

	# 9. Add vocabulary info
	quest["faction_vocabulary"] = faction_vocab.all
	quest["available_emojis"] = available_emojis
	quest["vocabulary_overlap_pct"] = float(available_emojis.size()) / max(faction_vocab.all.size(), 1)

	# 10. PRE-ROLL VOCABULARY REWARD PAIR
	# Roll the vocab pair NOW (at quest creation) so player knows what they'll learn
	var vocab_pair = _roll_vocabulary_reward_pair(signature, player_vocab, bias_emojis)
	quest["reward_vocab_north"] = vocab_pair.get("north", "")
	quest["reward_vocab_south"] = vocab_pair.get("south", "")
	quest["reward_vocab_probability"] = vocab_pair.get("probability", 0.0)
	quest["reward_vocab_weight"] = vocab_pair.get("weight", 0.0)

	_log("debug", "quest", "📖", "Pre-rolled vocab pair: %s/%s (%.0f%%)" % [
		vocab_pair.get("north", "?"),
		vocab_pair.get("south", "?"),
		vocab_pair.get("probability", 0) * 100
	])

	# 11. Add debug info
	quest["_preferences"] = FactionStateMatcher.describe_preferences(faction_bits)
	quest["_observables"] = FactionStateMatcher.describe_observables(obs)

	return quest


static func generate_display_text(quest: Dictionary) -> String:
	"""Generate human-readable quest description"""
	var resource = quest.get("resource", "?")
	var quantity = quest.get("quantity", 1)
	var time_limit = quest.get("time_limit", -1)

	var text = "%s x %d" % [resource, quantity]
	if time_limit > 0:
		text += " in %ds" % int(time_limit)

	return text


static func describe_alignment_reason(quest: Dictionary) -> String:
	"""Explain why alignment is high/low for UI feedback"""
	var alignment = quest.get("_alignment", 0.5)
	var preferences = quest.get("_preferences", "")
	var observables = quest.get("_observables", "")

	if alignment > 0.7:
		return "Your farm state matches their preferences!"
	elif alignment > 0.4:
		return "Partial match with faction preferences."
	else:
		return "Farm state misaligned with faction preferences."


static func _roll_vocabulary_reward_pair(
	faction_signature: Array,
	player_vocab: Array,
	bias_emojis: Array = []
) -> Dictionary:
	"""Roll vocabulary reward pair at quest creation time (FACTION SIGNATURE)

	NEW STRATEGY (Faction Signature Rolls):
	1. Roll SOUTH pole from faction signature (weighted by player inventory, can be known/unknown)
	2. Roll NORTH pole from faction signature (weighted by connectedness + player vocab, must be unknown)

	Args:
		faction_signature: Faction's signature emojis
		player_vocab: Emojis the player already knows

	Returns:
		{north, south, weight, probability} or {north: "", south: ""} if none available
	"""
	var icon_registry = VocabularyPairing._get_icon_registry()
	if not icon_registry:
		return {"north": "", "south": "", "error": "no_icon_registry"}

	# Step 1: Roll SOUTH pole from faction signature (weighted by player inventory)
	# South can be known OR unknown to player
	var south_result = VocabularyPairing._roll_south_pole_from_signature(
		icon_registry,
		faction_signature
	)

	if south_result.get("error"):
		_log("warn", "quest", "⚠️", "South roll failed: %s" % south_result.get("message", "unknown"))
		return {"north": "", "south": "", "error": south_result.get("error")}

	var south = south_result.south
	var south_connections = south_result.get("connections", {})

	# Step 2: Find NORTH candidates from faction signature
	# Must be: in faction signature AND connected to South AND unknown to player
	var north_candidates: Array = []
	for emoji in faction_signature:
		# Skip if player already knows this emoji
		if emoji in player_vocab:
			continue
		# Skip if same as south
		if emoji == south:
			continue
		# Skip if not connected to South
		if not south_connections.has(emoji):
			continue

		# Calculate weight: connectedness to South + player vocab connectivity
		var connection_weight = south_connections[emoji].get("weight", 1.0)
		var vocab_connectivity = VocabularyPairing.calculate_vocab_connectivity(emoji, player_vocab, icon_registry)

		# Combined weight (TODO: clarify weighting formula with user)
		var combined_weight = connection_weight * (1.0 + vocab_connectivity)

		north_candidates.append({
			"emoji": emoji,
			"weight": combined_weight,
			"connection_weight": connection_weight,
			"vocab_connectivity": vocab_connectivity
		})

	if north_candidates.is_empty():
		_log("debug", "quest", "📖", "No unknown north candidates for south=%s in faction signature" % south)
		return {"north": "", "south": south, "no_north_candidates": true}

	# Step 3: Weighted roll for NORTH
	var total_weight = 0.0
	for candidate in north_candidates:
		total_weight += candidate.weight

	var north = north_candidates[0].emoji
	var north_weight = 0.0

	if total_weight > 0:
		var roll = randf() * total_weight
		var cumulative = 0.0
		for candidate in north_candidates:
			cumulative += candidate.weight
			if roll <= cumulative:
				north = candidate.emoji
				north_weight = candidate.weight
				break

	_log("debug", "quest", "📖", "Faction pair: %s → %s (weight=%.2f)" % [south, north, north_weight])

	return {
		"north": north,
		"south": south,
		"weight": north_weight,
		"probability": north_weight / total_weight if total_weight > 0 else 0.0,
		"south_weight": south_result.get("weight", 0.0)
	}
