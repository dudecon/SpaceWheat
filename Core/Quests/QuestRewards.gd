class_name QuestRewards
extends RefCounted

## Quest Reward System
## Handles reward generation and vocabulary teaching for completed quests

const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")


class QuestReward:
	"""Rewards for completing a quest"""
	var gold: int = 0
	var learned_vocabulary: Array[String] = []  # Emojis player learned
	var reputation_gain: int = 0  # Future: faction reputation
	var bonus_multiplier: float = 1.0  # From alignment


static func generate_reward(quest: Dictionary, bath, player_vocab: Array) -> QuestReward:
	"""Generate rewards for quest completion

	Args:
		quest: Completed quest data
		bath: Current biome quantum bath
		player_vocab: Player's known emojis

	Returns:
		QuestReward with gold and vocabulary
	"""
	var reward = QuestReward.new()

	# Base gold from quest quantity and alignment
	var base_gold = quest.get("quantity", 5) * 10
	var multiplier = quest.get("reward_multiplier", 1.0)
	reward.gold = int(base_gold * multiplier)
	reward.bonus_multiplier = multiplier

	# Vocabulary reward - teach emoji from faction signature
	var faction_name = quest.get("faction", "")
	var faction_dict = _get_faction_by_name(faction_name)

	if faction_dict:
		var vocab = select_vocabulary_reward(faction_dict, bath, player_vocab)
		if vocab != "":
			reward.learned_vocabulary.append(vocab)

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
	var signature = faction.get("signature", [])

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
	"""Generate human-readable reward text for UI"""
	var lines = []

	# Gold
	lines.append("💰 +%d gold" % reward.gold)

	# Vocabulary
	for emoji in reward.learned_vocabulary:
		lines.append("📖 Learned: %s" % emoji)

	if reward.learned_vocabulary.is_empty():
		lines.append("📖 (No new vocabulary)")

	return "\n".join(lines)


static func preview_possible_rewards(quest: Dictionary, player_vocab: Array) -> String:
	"""Preview what rewards might be earned (before completion)"""
	var lines = []

	# Gold preview
	var base_gold = quest.get("quantity", 5) * 10
	var multiplier = quest.get("reward_multiplier", 1.0)
	var gold = int(base_gold * multiplier)
	lines.append("💰 %d gold" % gold)

	# Vocabulary preview
	var faction_name = quest.get("faction", "")
	var faction_dict = _get_faction_by_name(faction_name)

	if faction_dict:
		var signature = faction_dict.get("signature", [])
		var unknown_vocab = []

		for emoji in signature:
			if emoji not in player_vocab:
				unknown_vocab.append(emoji)

		if unknown_vocab.size() > 0:
			# Show preview of possible vocabulary
			var preview = unknown_vocab.slice(0, 3)  # First 3
			lines.append("📖 Learn: %s" % " or ".join(preview))
			if unknown_vocab.size() > 3:
				lines.append("   (+%d more possible)" % (unknown_vocab.size() - 3))
		else:
			lines.append("📖 (No new vocabulary)")

	return "\n".join(lines)
