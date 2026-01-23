class_name QuestRewards
extends RefCounted

## Quest Reward System
## Handles reward generation and vocabulary teaching for completed quests

const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const VocabularyPairing = preload("res://Core/Quests/VocabularyPairing.gd")


## Icon Modification: How quest rewards can modify icon physics
class IconModification:
	enum Type {
		ADD_COUPLING,       # Add new hamiltonian coupling
		MODIFY_COUPLING,    # Change existing coupling strength
		REDUCE_DECAY,       # Lower decay rate
		ADD_LINDBLAD,       # Add transfer channel
		UNLOCK_BELL_FEATURE,# Enable bell-activated feature
		ADD_DRIVER,         # Add time-dependent forcing
		BOOST_SELF_ENERGY,  # Increase self-energy (stability)
	}

	var type: Type
	var icon_emoji: String = ""
	var parameters: Dictionary = {}  # Type-specific params

	func _init():
		type = Type.MODIFY_COUPLING

	func _to_string() -> String:
		return "IconMod<%s>[%s]" % [Type.keys()[type], icon_emoji]


class QuestReward:
	"""Rewards for completing a quest"""
	var money_amount: int = 0  # 💰-credits reward (no universal currency!)
	var learned_vocabulary: Array[String] = []  # Emojis player learned (both north and south)
	var learned_pairs: Array = []  # Array of {north, south, weight, probability} - paired vocabulary
	var reputation_gain: int = 0  # Future: faction reputation
	var bonus_multiplier: float = 1.0  # From alignment
	var icon_modifications: Array = []  # Array[IconModification] - physics changes


static func generate_reward(quest: Dictionary, bath, player_vocab: Array) -> QuestReward:
	"""Generate rewards for quest completion

	Uses PRE-ROLLED vocabulary pair from quest creation time (not rolled now).
	This ensures player sees the same pair in preview and actual reward.

	Args:
		quest: Completed quest data (with reward_vocab_north/south)
		bath: Current biome quantum bath
		player_vocab: Player's known emojis

	Returns:
		QuestReward with vocabulary (no universal 💰 currency!)
	"""
	var reward = QuestReward.new()

	# NO UNIVERSAL MONEY! Money is just another emoji resource
	# Remove: reward.money_amount = ...
	reward.money_amount = 0  # No universal currency
	reward.bonus_multiplier = quest.get("reward_multiplier", 1.0)

	# Use PRE-ROLLED vocabulary pair from quest creation
	var north = quest.get("reward_vocab_north", "")
	var south = quest.get("reward_vocab_south", "")

	if north != "":
		reward.learned_vocabulary.append(north)

		if south != "":
			# Full pair (both north and south)
			reward.learned_vocabulary.append(south)
			reward.learned_pairs.append({
				"north": north,
				"south": south,
				"weight": quest.get("reward_vocab_weight", 0.0),
				"probability": quest.get("reward_vocab_probability", 0.0)
			})
		else:
			# Single emoji (no connections found at creation time)
			push_warning("QuestRewards: Quest has north=%s but no south" % north)

	# Icon modification reward (for higher-tier quests)
	var faction_name = quest.get("faction", "")
	var faction_dict = _get_faction_by_name(faction_name)
	if faction_dict and should_grant_icon_modification(quest):
		var mod = generate_icon_modification(faction_dict, quest)
		reward.icon_modifications.append(mod)

	return reward


static func select_vocabulary_reward(faction: Dictionary, bath, player_vocab: Array) -> String:
	"""Choose which emoji from faction signature to teach

	Strategy:
	1. Get faction signature vocabulary
	2. Filter to emojis player doesn't know
	3. Get bath probabilities for unknown emojis (quantum-weighted!)
	4. Sample weighted by probability
	5. Fallback to random if no probabilities

	Args:
		faction: Faction dictionary with signature
		bath: QuantumBath with probability distribution
		player_vocab: Player's known emojis

	Returns:
		Emoji string to teach, or "" if none available
	"""
	# Faction data uses "sig" key (short for signature)
	var signature = faction.get("sig", faction.get("signature", []))

	# Filter to unknown vocabulary
	var unknown = []
	for emoji in signature:
		if emoji not in player_vocab:
			unknown.append(emoji)

	# Already know everything?
	if unknown.is_empty():
		return ""  # No vocabulary to teach

	# Get bath probabilities for unknown emojis (quantum-informed selection!)
	if bath and bath.get("_density_matrix"):
		var density_matrix = bath._density_matrix
		var emoji_list = density_matrix.emoji_list
		var probs = []
		var indices = []

		for i in range(unknown.size()):
			var emoji = unknown[i]
			var idx = emoji_list.find(emoji)

			if idx >= 0:
				var prob = density_matrix.get_probability_by_index(idx)
				probs.append(prob)
				indices.append(i)

		# Sample weighted by probability
		if probs.size() > 0:
			var total = 0.0
			for p in probs:
				total += p

			if total > 0.001:
				# Renormalize and sample
				var roll = randf() * total
				var cumulative = 0.0
				for i in range(probs.size()):
					cumulative += probs[i]
					if roll <= cumulative:
						return unknown[indices[i]]

	# Fallback: random from unknown
	return unknown[randi() % unknown.size()]


static func _get_faction_by_name(faction_name: String) -> Dictionary:
	"""Find faction dictionary by name"""
	for faction in FactionDatabase.ALL_FACTIONS:
		if faction.get("name", "") == faction_name:
			return faction

	return {}


static func format_reward_text(reward: QuestReward) -> String:
	"""Generate human-readable reward text for UI

	No universal 💰 currency - just vocab pairs!
	"""
	var lines = []

	# Vocabulary pairs (primary reward)
	if reward.learned_pairs.size() > 0:
		for pair in reward.learned_pairs:
			var north = pair.get("north", "?")
			var south = pair.get("south", "?")
			lines.append("📖 Learned: %s/%s axis" % [north, south])
	elif reward.learned_vocabulary.size() > 0:
		# Fallback for single emojis (no connections)
		for emoji in reward.learned_vocabulary:
			lines.append("📖 Learned: %s (solo)" % emoji)
	else:
		lines.append("📖 (No new vocabulary)")

	# Icon modifications
	for mod in reward.icon_modifications:
		lines.append("⚛️ %s" % _format_icon_modification(mod))

	return "\n".join(lines)


static func preview_possible_rewards(quest: Dictionary, player_vocab: Array) -> String:
	"""Preview what rewards will be earned (shows pre-rolled pair)

	No universal 💰 currency - just vocab pairs from quantum physics.
	"""
	var lines = []

	# NO UNIVERSAL MONEY - removed 💰 preview

	# Show PRE-ROLLED vocabulary pair
	var north = quest.get("reward_vocab_north", "")
	var south = quest.get("reward_vocab_south", "")

	if north != "":
		if south != "":
			lines.append("📖 Learn: %s/%s axis" % [north, south])
		else:
			lines.append("📖 Learn: %s (solo)" % north)
	else:
		lines.append("📖 (No new vocabulary)")

	return "\n".join(lines)


## ========================================
## Icon Modification Generation
## ========================================

static func generate_icon_modification(faction: Dictionary, quest: Dictionary) -> IconModification:
	"""Generate a faction-specific icon modification as quest reward

	Args:
		faction: Faction dictionary
		quest: Quest dictionary

	Returns:
		IconModification with faction-appropriate changes
	"""
	var mod = IconModification.new()
	var faction_name = faction.get("name", "Unknown")
	var faction_sig = faction.get("sig", faction.get("signature", []))

	# Pick an emoji from faction signature for modification
	var target_emoji = quest.get("resource", "")
	if target_emoji.is_empty() and faction_sig.size() > 0:
		target_emoji = faction_sig[randi() % faction_sig.size()]

	mod.icon_emoji = target_emoji

	# Faction-specific modification types
	match faction_name:
		"Loom Priests":
			# Fate threads are complex! Add imaginary coupling
			mod.type = IconModification.Type.ADD_COUPLING
			var fate_targets = ["🕯️", "🧵", "🌀", "📿"]
			var fate_target = fate_targets[randi() % fate_targets.size()]
			mod.parameters = {
				"target": fate_target,
				"strength": randf_range(0.05, 0.15),
				"imaginary": randf_range(-0.1, 0.1),  # Complex coupling!
				"description": "Fate threads weave new connections"
			}

		"Yeast Prophets":
			# Enhance fermentation couplings
			mod.type = IconModification.Type.MODIFY_COUPLING
			mod.parameters = {
				"target": "🍞",
				"boost_factor": randf_range(1.1, 1.3),
				"description": "Fermentation accelerates"
			}

		"Sacred Flame Keepers":
			# Reduce fire decay
			mod.type = IconModification.Type.REDUCE_DECAY
			mod.icon_emoji = "🔥"
			mod.parameters = {
				"reduction": randf_range(0.005, 0.02),
				"description": "Sacred flame burns longer"
			}

		"Knot-Shriners":
			# Unlock Bell-activated feature
			mod.type = IconModification.Type.UNLOCK_BELL_FEATURE
			mod.icon_emoji = "🪢"
			mod.parameters = {
				"feature_name": "oath_binding",
				"description": "Oaths now bind when entangled"
			}

		"Verdant Pulse", "Granary Guilds":
			# Boost growth
			mod.type = IconModification.Type.MODIFY_COUPLING
			mod.parameters = {
				"target": "🌾",
				"boost_factor": randf_range(1.05, 1.15),
				"description": "Growth flows strengthened"
			}

		"Kilowatt Collective":
			# Add driver for power oscillation
			mod.type = IconModification.Type.ADD_DRIVER
			mod.icon_emoji = "⚡"
			mod.parameters = {
				"driver_type": "cosine",
				"frequency": randf_range(0.1, 0.3),
				"amplitude": randf_range(0.1, 0.3),
				"description": "Power surges rhythmically"
			}

		"Keepers of Silence":
			# Boost decoherence effect (silence kills coherence)
			mod.type = IconModification.Type.BOOST_SELF_ENERGY
			mod.icon_emoji = "🤫"
			mod.parameters = {
				"boost": randf_range(-0.1, -0.05),  # Negative = more unstable
				"description": "Silence deepens"
			}

		_:
			# Default: small coupling boost to a random emoji
			mod.type = IconModification.Type.MODIFY_COUPLING
			if faction_sig.size() >= 2:
				var other = faction_sig[randi() % faction_sig.size()]
				while other == target_emoji and faction_sig.size() > 1:
					other = faction_sig[randi() % faction_sig.size()]
				mod.parameters = {
					"target": other,
					"boost_factor": randf_range(1.03, 1.1),
					"description": "Bonds strengthen"
				}
			else:
				mod.type = IconModification.Type.BOOST_SELF_ENERGY
				mod.parameters = {
					"boost": randf_range(0.02, 0.08),
					"description": "Essence stabilizes"
				}

	return mod


static func _format_icon_modification(mod: IconModification) -> String:
	"""Format an icon modification for display"""
	var desc = mod.parameters.get("description", "Modified physics")

	match mod.type:
		IconModification.Type.ADD_COUPLING:
			var target = mod.parameters.get("target", "?")
			return "%s → %s: %s" % [mod.icon_emoji, target, desc]

		IconModification.Type.MODIFY_COUPLING:
			var target = mod.parameters.get("target", "?")
			var boost = mod.parameters.get("boost_factor", 1.0)
			return "%s → %s: +%.0f%% (%s)" % [mod.icon_emoji, target, (boost - 1) * 100, desc]

		IconModification.Type.REDUCE_DECAY:
			var red = mod.parameters.get("reduction", 0.0)
			return "%s decay -%.1f%% (%s)" % [mod.icon_emoji, red * 100, desc]

		IconModification.Type.ADD_LINDBLAD:
			var target = mod.parameters.get("target", "?")
			return "%s → %s: new transfer (%s)" % [mod.icon_emoji, target, desc]

		IconModification.Type.UNLOCK_BELL_FEATURE:
			var feature = mod.parameters.get("feature_name", "unknown")
			return "%s: Bell feature [%s] unlocked" % [mod.icon_emoji, feature]

		IconModification.Type.ADD_DRIVER:
			var freq = mod.parameters.get("frequency", 0.0)
			return "%s: oscillation at %.2f Hz (%s)" % [mod.icon_emoji, freq, desc]

		IconModification.Type.BOOST_SELF_ENERGY:
			var boost = mod.parameters.get("boost", 0.0)
			var dir = "stabilized" if boost > 0 else "destabilized"
			return "%s: %s (%s)" % [mod.icon_emoji, dir, desc]

	return "%s: %s" % [mod.icon_emoji, desc]


static func should_grant_icon_modification(quest: Dictionary) -> bool:
	"""Determine if this quest should grant an icon modification reward

	Higher-tier quests (prophecy, coherence, bell state) are more likely
	to grant icon modifications as rewards.
	"""
	var quest_type = quest.get("type", 0)

	# Quantum mechanics quests always grant modifications
	const QuestTypes = preload("res://Core/Quests/QuestTypes.gd")
	if quest_type in [
		QuestTypes.Type.ACHIEVE_EIGENSTATE,
		QuestTypes.Type.MAINTAIN_COHERENCE,
		QuestTypes.Type.INDUCE_BELL_STATE,
	]:
		return true

	# Other quests have a chance based on reward multiplier
	var multiplier = quest.get("reward_multiplier", 1.0)
	var chance = clamp((multiplier - 1.5) * 0.3, 0.0, 0.5)  # 0-50% chance

	return randf() < chance
