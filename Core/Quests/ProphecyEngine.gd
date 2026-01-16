class_name ProphecyEngine
extends RefCounted

## ProphecyEngine: Eigenvalue-based prophecy computation
##
## Computes dominant eigenstates of the Hamiltonian as "prophecies"
## Used by Loom Priests (fate/threads) and Yeast Prophets (fermentation)
##
## The Hamiltonian's eigenstates represent the "natural outcomes" of the
## quantum system - where it wants to evolve to. By finding the dominant
## eigenstate (largest eigenvalue magnitude), we can predict the system's
## "fate" and generate quests around achieving that prophesied state.
##
## Physics basis:
## - Eigenstates of H are stationary states (don't evolve under H)
## - Dominant eigenvalue = strongest "attractor" in energy landscape
## - High purity = system is close to an eigenstate
## - Prophecy fulfilled = system has reached predicted eigenstate

const QuestTypes = preload("res://Core/Quests/QuestTypes.gd")


## Compute a prophecy from the biome's current quantum state
## Returns Dictionary with prophecy details
static func compute_prophecy(biome) -> Dictionary:
	"""Compute prophecy from biome's Hamiltonian eigenstates

	Args:
		biome: BiomeBase with bath or quantum_computer

	Returns:
		Dictionary with:
		- dominant_eigenvalue: float (energy of fate)
		- fate_emojis: Array[{emoji, weight}] (predicted outcome)
		- fate_string: String (emoji chain for display)
		- stability: float (0-1, how stable the prophecy is)
		- purity: float (current system purity)
	"""
	# Get Hamiltonian and density matrix from biome
	var H = null
	var rho = null
	var emoji_list: Array = []

	# Try quantum_computer first (new architecture)
	if biome and biome.get("quantum_computer"):
		var qc = biome.quantum_computer
		if qc.get("hamiltonian"):
			H = qc.hamiltonian
		if qc.has_method("get_density_matrix"):
			rho = qc.get_density_matrix()
		if qc.get("register_map"):
			emoji_list = qc.register_map.keys()

	# Fallback to bath (legacy architecture)
	if H == null and biome and biome.get("bath"):
		var bath = biome.bath
		if bath.get("_H"):
			H = bath._H
		elif bath.get("hamiltonian"):
			H = bath.hamiltonian
		if bath.get("_density_matrix"):
			rho = bath._density_matrix
			emoji_list = rho.emoji_list

	# No Hamiltonian found
	if H == null:
		return {
			"error": "no_hamiltonian",
			"dominant_eigenvalue": 0.0,
			"fate_emojis": [],
			"fate_string": "???",
			"stability": 0.0,
			"purity": 0.0,
		}

	# Get emoji list from Hamiltonian if not already set
	if emoji_list.is_empty() and H.get("emoji_list"):
		emoji_list = H.emoji_list

	# Compute eigensystem of Hamiltonian
	var eig = H._matrix.eigensystem() if H.get("_matrix") else H.eigensystem()
	var eigenvalues = eig.get("eigenvalues", [])
	var eigenvectors = eig.get("eigenvectors", null)

	if eigenvalues.is_empty():
		return {
			"error": "eigensystem_failed",
			"dominant_eigenvalue": 0.0,
			"fate_emojis": [],
			"fate_string": "???",
			"stability": 0.0,
			"purity": 0.0,
		}

	# Find dominant eigenvalue (largest magnitude)
	var max_idx = 0
	var max_val = abs(eigenvalues[0])
	for i in range(eigenvalues.size()):
		if abs(eigenvalues[i]) > max_val:
			max_val = abs(eigenvalues[i])
			max_idx = i

	# Extract high-amplitude emojis from dominant eigenvector
	var fate_emojis: Array = []

	if eigenvectors and eigenvectors.n > 0:
		# Get column (eigenvector) from eigenvector matrix
		var n = eigenvectors.n
		for i in range(n):
			var element = eigenvectors.get_element(i, max_idx)
			var amplitude = element.abs() if element else 0.0

			if amplitude > 0.15 and i < emoji_list.size():  # Threshold for "significant"
				fate_emojis.append({
					"emoji": emoji_list[i],
					"weight": amplitude
				})

	# Sort by weight (descending)
	fate_emojis.sort_custom(func(a, b): return a.weight > b.weight)

	# Build fate string (top 3 emojis)
	var fate_parts: Array = []
	for i in range(mini(3, fate_emojis.size())):
		fate_parts.append(fate_emojis[i].emoji)
	var fate_string = "→".join(fate_parts) if fate_parts.size() > 0 else "???"

	# Calculate stability from entropy (low entropy = stable prophecy)
	var purity = rho.get_purity() if rho and rho.has_method("get_purity") else 0.5
	var entropy = rho.get_entropy() if rho and rho.has_method("get_entropy") else 0.5
	var stability = clamp(1.0 - entropy, 0.0, 1.0)

	return {
		"dominant_eigenvalue": eigenvalues[max_idx],
		"fate_emojis": fate_emojis,
		"fate_string": fate_string,
		"stability": stability,
		"purity": purity,
	}


## Generate a prophecy quest for a prophecy-capable faction
static func generate_prophecy_quest(faction: Dictionary, biome) -> Dictionary:
	"""Generate ACHIEVE_EIGENSTATE quest from prophecy

	Args:
		faction: Faction dictionary (must have prophecy_capable tag or be Loom Priests/Yeast Prophets)
		biome: BiomeBase with quantum state

	Returns:
		Quest dictionary ready for QuestManager
	"""
	var prophecy = compute_prophecy(biome)

	if prophecy.has("error"):
		return {"error": prophecy.error}

	# Faction-specific flavor
	var faction_name = faction.get("name", "Unknown")
	var is_loom = faction_name == "Loom Priests"
	var is_yeast = faction_name == "Yeast Prophets"

	var prefix: String
	var verb: String
	if is_loom:
		prefix = "The threads converge on:"
		verb = "weave"
	elif is_yeast:
		prefix = "The ferment reveals:"
		verb = "cultivate"
	else:
		prefix = "The eigenstate prophesies:"
		verb = "achieve"

	# Target purity scales with stability (stable prophecy = harder target)
	var target_purity = lerpf(0.85, 0.98, prophecy.stability)

	# Reward multiplier scales with stability (stable prophecy = bigger reward)
	var reward_multiplier = lerpf(2.0, 5.0, prophecy.stability)

	# Build quest description
	var body: String
	if prophecy.fate_emojis.size() >= 2:
		body = "%s %s the %s" % [prefix, verb, prophecy.fate_string]
	else:
		body = "%s reach eigenstate purity %.0f%%" % [prefix, target_purity * 100]

	return {
		"type": QuestTypes.Type.ACHIEVE_EIGENSTATE,
		"faction": faction_name,
		"prophecy_text": "%s %s" % [prefix, prophecy.fate_string],
		"body": body,
		"target_emojis": prophecy.fate_emojis.slice(0, 3),
		"target_purity": target_purity,
		"reward_multiplier": reward_multiplier,
		"observable": "purity",
		"target": target_purity,
		"time_limit": -1,  # No time limit on prophecy quests
	}


## Generate a coherence weaving quest (for maintaining quantum threads)
static func generate_coherence_quest(faction: Dictionary, biome) -> Dictionary:
	"""Generate MAINTAIN_COHERENCE quest

	Args:
		faction: Faction dictionary
		biome: BiomeBase with quantum state

	Returns:
		Quest dictionary ready for QuestManager
	"""
	# Get current coherence to set reasonable target
	var current_coherence = 0.3
	if biome and biome.has_method("_calculate_bath_coherence"):
		current_coherence = biome._calculate_bath_coherence()

	var faction_name = faction.get("name", "Unknown")
	var is_loom = faction_name == "Loom Priests"

	# Target should be achievable but challenging
	var target_coherence = clamp(current_coherence + 0.15, 0.4, 0.8)
	var duration = randf_range(20.0, 45.0)  # 20-45 seconds

	var body: String
	if is_loom:
		body = "Keep the threads woven for %ds (coherence > %.0f%%)" % [int(duration), target_coherence * 100]
	else:
		body = "Maintain quantum coherence > %.0f%% for %ds" % [target_coherence * 100, int(duration)]

	return {
		"type": QuestTypes.Type.MAINTAIN_COHERENCE,
		"faction": faction_name,
		"body": body,
		"target_coherence": target_coherence,
		"duration": duration,
		"elapsed": 0.0,
		"reward_multiplier": lerpf(2.0, 4.0, target_coherence),
		"time_limit": -1,
	}


## Generate a Bell state quest (for entangling specific pairs)
static func generate_bell_quest(faction: Dictionary, biome, player_vocab: Array) -> Dictionary:
	"""Generate INDUCE_BELL_STATE quest

	Args:
		faction: Faction dictionary
		biome: BiomeBase with quantum state
		player_vocab: Player's known emojis

	Returns:
		Quest dictionary ready for QuestManager
	"""
	var faction_name = faction.get("name", "Unknown")
	var faction_sig = faction.get("sig", faction.get("signature", []))

	# Select two emojis from faction signature that player knows
	var valid_emojis: Array = []
	for emoji in faction_sig:
		if emoji in player_vocab:
			valid_emojis.append(emoji)

	if valid_emojis.size() < 2:
		return {"error": "insufficient_vocabulary"}

	# Pick two random emojis to entangle
	valid_emojis.shuffle()
	var target_pair = [valid_emojis[0], valid_emojis[1]]

	var threshold = randf_range(0.5, 0.8)  # Coherence threshold

	var body = "Entangle %s ↔ %s (coherence > %.0f%%)" % [
		target_pair[0], target_pair[1], threshold * 100
	]

	return {
		"type": QuestTypes.Type.INDUCE_BELL_STATE,
		"faction": faction_name,
		"body": body,
		"target_pair": target_pair,
		"threshold": threshold,
		"reward_multiplier": lerpf(2.5, 4.5, threshold),
		"time_limit": -1,
	}


## Check if a faction is prophecy-capable
static func is_prophecy_faction(faction: Dictionary) -> bool:
	"""Check if faction can generate prophecy quests"""
	var name = faction.get("name", "")
	var tags = faction.get("tags", [])

	# Explicit tag
	if "prophecy_capable" in tags:
		return true

	# Named factions
	if name in ["Loom Priests", "Yeast Prophets"]:
		return true

	return false


## Check if a faction is coherence-focused
static func is_coherence_faction(faction: Dictionary) -> bool:
	"""Check if faction can generate coherence quests"""
	var name = faction.get("name", "")
	var tags = faction.get("tags", [])

	if "coherence_weaver" in tags:
		return true

	if name in ["Loom Priests", "Knot-Shriners", "Seamstress Syndicate"]:
		return true

	return false


## Check if a faction is entanglement-focused
static func is_entanglement_faction(faction: Dictionary) -> bool:
	"""Check if faction can generate Bell state quests"""
	var name = faction.get("name", "")
	var tags = faction.get("tags", [])

	if "entanglement_seeker" in tags:
		return true

	if name in ["Knot-Shriners", "Liminal Taper", "Reality Midwives"]:
		return true

	return false
