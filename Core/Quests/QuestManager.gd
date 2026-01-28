class_name QuestManager
extends Node

## Quest lifecycle management
## Handles offer → accept → complete/fail flow
## Integrates with FarmEconomy for resource checking

# Quest system dependency
const QuestGenerator = preload("res://Core/Quests/QuestGenerator.gd")
const QuestTheming = preload("res://Core/Quests/QuestTheming.gd")
const QuestTypes = preload("res://Core/Quests/QuestTypes.gd")
const QuestRewards = preload("res://Core/Quests/QuestRewards.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const FactionStateMatcher = preload("res://Core/QuantumSubstrate/FactionStateMatcher.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")

# Logging
@onready var _verbose = get_node("/root/VerboseConfig")

# =============================================================================
# SIGNALS
# =============================================================================

signal quest_offered(quest_data: Dictionary)
signal quest_accepted(quest_id: int)
signal quest_ready_to_claim(quest_id: int)  # Non-delivery quest conditions met, awaiting player claim
signal quest_completed(quest_id: int, rewards: Dictionary)
signal quest_failed(quest_id: int, reason: String)
signal quest_expired(quest_id: int)
signal active_quests_changed()
signal vocabulary_learned(emoji: String, faction: String)
signal vocabulary_pair_learned(north: String, south: String, faction: String)

# =============================================================================
# STATE
# =============================================================================

var active_quests: Dictionary = {}  # quest_id -> quest_data (status: "active" or "ready")
var completed_quests: Array = []
var failed_quests: Array = []
var next_quest_id: int = 0

# Quest timers
var quest_timers: Dictionary = {}  # quest_id -> Timer

# References (set via dependency injection)
var economy: Node = null
var faction_manager: Node = null
var current_biome: Node = null  # For tracking non-delivery quest progress

# =============================================================================
# CONFIGURATION
# =============================================================================

const MAX_ACTIVE_QUESTS: int = 5
const QUEST_OFFER_COOLDOWN: float = 30.0  # Seconds between new quest offers
const AUTO_FAIL_ON_RESOURCE_SHORTAGE: bool = true

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	set_physics_process(true)  # Enable for quest tracking

func _physics_process(delta: float) -> void:
	var t0 = Time.get_ticks_usec()
	"""Update quest progress for non-delivery quests"""
	if current_biome == null:
		return

	for quest in active_quests.values():
		# Skip quests already ready to claim
		if quest.get("status") == "ready":
			continue

		var quest_type = quest.get("type", QuestTypes.Type.DELIVERY)

		# Only track quest types that need continuous monitoring
		if not QuestTypes.requires_tracking(quest_type):
			continue

		match quest_type:
			QuestTypes.Type.SHAPE_ACHIEVE:
				_update_shape_achieve_quest(quest, delta)
			QuestTypes.Type.SHAPE_MAINTAIN:
				_update_shape_maintain_quest(quest, delta)
			QuestTypes.Type.EVOLUTION:
				_update_evolution_quest(quest, delta)
			QuestTypes.Type.ENTANGLEMENT:
				_update_entanglement_quest(quest, delta)
			# Quantum mechanics quest types
			QuestTypes.Type.ACHIEVE_EIGENSTATE:
				_update_achieve_eigenstate_quest(quest, delta)
			QuestTypes.Type.MAINTAIN_COHERENCE:
				_update_maintain_coherence_quest(quest, delta)
			QuestTypes.Type.INDUCE_BELL_STATE:
				_update_induce_bell_state_quest(quest, delta)
			QuestTypes.Type.PREVENT_DECOHERENCE:
				_update_prevent_decoherence_quest(quest, delta)
			QuestTypes.Type.COLLAPSE_DELIBERATELY:
				_update_collapse_deliberately_quest(quest, delta)
	var t1 = Time.get_ticks_usec()
	if Engine.get_physics_frames() % 60 == 0:
		if _verbose:
			_verbose.trace("quest", "⏱️", "QuestManager Physics Trace: Total %d us" % [t1 - t0])

func connect_to_economy(econ: Node) -> void:
	"""Inject economy dependency"""
	economy = econ

func connect_to_faction_manager(fm: Node) -> void:
	"""Inject faction manager dependency"""
	faction_manager = fm

func connect_to_biome(biome: Node) -> void:
	"""Inject biome dependency for quest tracking"""
	current_biome = biome


func _get_gsm():
	"""Get GameStateManager singleton safely (supports headless tests)."""
	var tree = get_tree()
	if tree and tree.root:
		return tree.root.get_node_or_null("/root/GameStateManager")
	return null


func _get_player_vocab_emojis() -> Array:
	"""Get player-known emojis (farm-owned preferred)."""
	var gsm = _get_gsm()
	if gsm and "active_farm" in gsm and gsm.active_farm and gsm.active_farm.has_method("get_known_emojis"):
		return gsm.active_farm.get_known_emojis()
	if gsm and gsm.current_state and gsm.current_state.has_method("get_known_emojis"):
		return gsm.current_state.get_known_emojis()
	return []


func _discover_vocab_pair(north: String, south: String) -> void:
	"""Grant a vocab pair to the player (farm-owned preferred)."""
	var gsm = _get_gsm()
	if gsm and "active_farm" in gsm and gsm.active_farm and gsm.active_farm.has_method("discover_pair"):
		gsm.active_farm.discover_pair(north, south)
	elif gsm and gsm.has_method("discover_pair"):
		gsm.discover_pair(north, south)


func _get_simulated_vocab_emojis(biome: Node) -> Array:
	if not biome or not biome.has_method("get"):
		return []
	var qc = biome.get("quantum_computer")
	if not qc or not qc.has_method("get"):
		return []
	var rm = qc.get("register_map")
	if not rm:
		return []
	var coords = rm.get("coordinates") if rm.has_method("get") else null
	if coords is Dictionary:
		return coords.keys()
	return []

# =============================================================================
# QUEST OFFERING
# =============================================================================

func offer_quest(faction: Dictionary, biome_name: String, resources: Array) -> Dictionary:
	"""Generate and offer a new quest

	Returns:
		Quest data with unique ID, or empty dict if offer failed
	"""
	if active_quests.size() >= MAX_ACTIVE_QUESTS:
		push_warning("Cannot offer quest: max active quests reached (%d)" % MAX_ACTIVE_QUESTS)
		return {}

	# Generate quest
	var quest = QuestGenerator.generate_quest(faction, biome_name, resources)
	if quest.is_empty():
		return {}

	# Assign unique ID
	quest["id"] = next_quest_id
	next_quest_id += 1

	# Add metadata
	quest["status"] = "offered"
	quest["offered_at"] = Time.get_ticks_msec()

	quest_offered.emit(quest)
	return quest

func offer_emoji_quest(faction: Dictionary, biome_name: String, resources: Array) -> Dictionary:
	"""Generate and offer emoji-only quest"""
	if active_quests.size() >= MAX_ACTIVE_QUESTS:
		return {}

	var quest = QuestGenerator.generate_emoji_quest(faction, biome_name, resources)
	if quest.is_empty():
		return {}

	quest["id"] = next_quest_id
	next_quest_id += 1
	quest["status"] = "offered"
	quest["offered_at"] = Time.get_ticks_msec()

	quest_offered.emit(quest)
	return quest

# =============================================================================
# EMERGENT QUEST OFFERING (Quantum x Faction)
# =============================================================================

func offer_quest_emergent(faction: Dictionary, biome) -> Dictionary:
	"""Generate quest using emergent faction x biome multiplication

	This is the quantum approach: faction state-shape preferences are
	matched against biome quantum observables to generate quests.
	Respects player vocabulary for resource constraints!
	"""

	if active_quests.size() >= MAX_ACTIVE_QUESTS:
		return {}

	# Get player vocabulary for filtering
	var player_vocab = _get_player_vocab_emojis()
	var bias_emojis = _get_simulated_vocab_emojis(biome)

	# Generate via abstract machinery + theming (with vocabulary constraint!)
	# Note: bath parameter is null (deprecated - removed from architecture)
	var quest = QuestTheming.generate_quest(faction, null, player_vocab, bias_emojis)

	# Check for vocabulary mismatch error
	if quest.is_empty() or quest.has("error"):
		return {}  # Faction inaccessible - no vocabulary overlap

	# Assign ID and metadata
	quest["id"] = next_quest_id
	next_quest_id += 1
	quest["status"] = "offered"
	quest["offered_at"] = Time.get_ticks_msec()
	quest["biome"] = biome.biome_name if biome and biome.get("biome_name") else "Unknown"

	# Generate display text
	quest["body"] = QuestTheming.generate_display_text(quest)
	if quest.time_limit > 0:
		quest["full_text"] = "%s wants: %s in %ds" % [quest.faction, quest.body, int(quest.time_limit)]
	else:
		quest["full_text"] = "%s wants: %s" % [quest.faction, quest.body]

	quest_offered.emit(quest)
	return quest


func offer_all_faction_quests(biome) -> Array:
	"""Generate quests from ALL factions for current biome state

	Called when player opens quest overlay. Returns array of quest offers
	from all factions, each with alignment score based on biome state.
	Respects player vocabulary - inaccessible factions are filtered out.
	"""
	var quests = []

	# Get player vocabulary for filtering
	var player_vocab = _get_player_vocab_emojis()
	var bias_emojis = _get_simulated_vocab_emojis(biome)

	for faction in FactionDatabase.ALL_FACTIONS:
		# Use full generate_quest pipeline (handles vocabulary filtering!)
		# Note: bath parameter is null (deprecated)
		var quest = QuestTheming.generate_quest(faction, null, player_vocab, bias_emojis)

		# Skip factions with no vocabulary overlap
		if quest.is_empty() or quest.has("error"):
			continue

		# Add metadata
		quest["id"] = next_quest_id
		next_quest_id += 1
		quest["biome"] = biome.biome_name if biome and biome.get("biome_name") else "Unknown"
		quest["status"] = "offered"
		quest["offered_at"] = Time.get_ticks_msec()

		# Generate display text
		quest["body"] = QuestTheming.generate_display_text(quest)

		quests.append(quest)

	return quests  # Return all accessible quests for player to browse


func get_biome_observables(biome) -> Dictionary:
	"""Get current biome quantum observables for UI display"""
	# Note: bath parameter is null (deprecated)
	var obs = FactionStateMatcher.extract_observables(null, biome)

	return {
		"purity": obs.purity,
		"entropy": obs.entropy,
		"coherence": obs.coherence,
		"distribution_shape": obs.distribution_shape,
		"scale": obs.scale,
		"dynamics": obs.dynamics,
		"description": FactionStateMatcher.describe_observables(obs),
	}

# =============================================================================
# QUEST ACCEPTANCE
# =============================================================================

func accept_quest(quest_data: Dictionary) -> bool:
	"""Accept an offered quest

	Args:
		quest_data: Quest with "id" field

	Returns:
		true if accepted, false if invalid
	"""
	if not quest_data.has("id"):
		push_error("Cannot accept quest: missing ID")
		return false

	var quest_id = quest_data["id"]

	if active_quests.has(quest_id):
		push_warning("Quest %d already active" % quest_id)
		return false

	# Update status
	quest_data["status"] = "active"
	quest_data["accepted_at"] = Time.get_ticks_msec()

	# Store
	active_quests[quest_id] = quest_data

	# Start timer if quest has time limit
	if quest_data.get("time_limit", -1) > 0:
		_start_quest_timer(quest_id, quest_data["time_limit"])

	quest_accepted.emit(quest_id)
	active_quests_changed.emit()
	return true

# =============================================================================
# QUEST COMPLETION
# =============================================================================

func check_quest_completion(quest_id: int) -> bool:
	"""Check if player has resources to complete quest

	Returns:
		true if quest can be completed with current resources
	"""
	if not active_quests.has(quest_id):
		return false

	var quest = active_quests[quest_id]
	var required_emoji = quest.get("resource", "")
	var required_qty = quest.get("quantity", 0)

	if required_emoji.is_empty() or required_qty <= 0:
		return false

	if economy == null:
		push_warning("QuestManager: economy not connected, cannot check resources")
		return false

	# Check if player has enough resources
	# quantity is already in credits (10-150 range from QuestTheming)
	var player_amount = economy.get_resource(required_emoji)
	return player_amount >= required_qty

func complete_quest(quest_id: int) -> bool:
	"""Complete an active quest

	Deducts required resources and grants rewards (including vocabulary!)

	Returns:
		true if completed successfully
	"""
	print("🔍 complete_quest called with ID: %d" % quest_id)
	print("🔍 active_quests keys: %s" % str(active_quests.keys()))

	if not active_quests.has(quest_id):
		push_error("Cannot complete quest %d: not active" % quest_id)
		return false

	var quest = active_quests[quest_id]
	print("🔍 Quest found: %s, resource=%s, qty=%d" % [quest.get("faction", "?"), quest.get("resource", "?"), quest.get("quantity", 0)])

	# Check resources
	if not check_quest_completion(quest_id):
		push_warning("Cannot complete quest %d: insufficient resources" % quest_id)
		return false
	print("🔍 Resource check passed")

	# Deduct resources (quantity is already in credits)
	var required_emoji = quest["resource"]
	var required_qty = quest["quantity"]

	# Debug: show exact values being used
	var player_has = economy.get_resource(required_emoji) if economy else -1
	print("🔍 Deducting: emoji='%s' qty=%d, player_has=%d" % [required_emoji, required_qty, player_has])

	if not economy.remove_resource(required_emoji, required_qty, "quest_completion"):
		push_error("Failed to deduct resources for quest %d: need %d %s, have %d" % [quest_id, required_qty, required_emoji, player_has])
		return false

	# Generate rewards (vocabulary only - no universal 💰 currency!)
	var player_vocab = _get_player_vocab_emojis()
	var reward = QuestRewards.generate_reward(quest, null, player_vocab)
	var gsm = _get_gsm()

	# NO UNIVERSAL MONEY - removed 💰 grant

	# Grant vocabulary rewards
	var faction_name = quest.get("faction", "Unknown")

	# Paired vocabulary (preferred - uses discover_pair which handles both emojis)
	for pair in reward.learned_pairs:
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north != "" and south != "":
			_discover_vocab_pair(north, south)
			vocabulary_pair_learned.emit(north, south, faction_name)
			vocabulary_learned.emit(north, faction_name)
			vocabulary_learned.emit(south, faction_name)
			print("📖 %s taught you: %s/%s axis" % [faction_name, north, south])

	# Single emojis (fallback for emojis without connections)
	if reward.learned_pairs.is_empty():
		for emoji in reward.learned_vocabulary:
			if gsm and gsm.has_method("discover_emoji"):
				gsm.discover_emoji(emoji)
			vocabulary_learned.emit(emoji, faction_name)
			print("📖 %s taught you: %s" % [faction_name, emoji])

	# Update quest status
	quest["status"] = "completed"
	quest["completed_at"] = Time.get_ticks_msec()
	quest["reward"] = reward

	# Move to completed list
	active_quests.erase(quest_id)
	completed_quests.append(quest)

	# Stop timer
	_stop_quest_timer(quest_id)

	# Emit with legacy format for compatibility
	var legacy_rewards = {"💰": reward.money_amount}
	quest_completed.emit(quest_id, legacy_rewards)
	active_quests_changed.emit()
	return true

# =============================================================================
# QUEST FAILURE
# =============================================================================

func fail_quest(quest_id: int, reason: String = "player_action") -> void:
	"""Fail an active quest

	Args:
		quest_id: Quest to fail
		reason: Why it failed (timeout, player_action, resource_shortage)
	"""
	if not active_quests.has(quest_id):
		return

	var quest = active_quests[quest_id]
	quest["status"] = "failed"
	quest["failed_at"] = Time.get_ticks_msec()
	quest["failure_reason"] = reason

	# Move to failed list
	active_quests.erase(quest_id)
	failed_quests.append(quest)

	# Stop timer
	_stop_quest_timer(quest_id)

	quest_failed.emit(quest_id, reason)
	active_quests_changed.emit()

# =============================================================================
# QUEST READY/CLAIM (Non-delivery quests)
# =============================================================================

func mark_quest_ready(quest_id: int, completion_reason: String = "conditions_met") -> void:
	"""Mark a non-delivery quest as ready to claim (conditions met)

	The quest stays in active_quests but with status="ready".
	Player must press Claim to receive rewards.
	"""
	if not active_quests.has(quest_id):
		return

	var quest = active_quests[quest_id]

	# Don't re-mark if already ready
	if quest.get("status") == "ready":
		return

	quest["status"] = "ready"
	quest["ready_at"] = Time.get_ticks_msec()
	quest["completion_reason"] = completion_reason

	quest_ready_to_claim.emit(quest_id)
	active_quests_changed.emit()


func claim_quest(quest_id: int) -> bool:
	"""Claim rewards for a ready non-delivery quest

	Returns:
		true if claimed successfully
	"""
	if not active_quests.has(quest_id):
		push_error("Cannot claim quest %d: not active" % quest_id)
		return false

	var quest = active_quests[quest_id]

	# Must be in ready state
	if quest.get("status") != "ready":
		push_warning("Cannot claim quest %d: not ready (status=%s)" % [quest_id, quest.get("status", "?")])
		return false

	# Generate and grant rewards (vocabulary only - no universal 💰 currency!)
	var gsm = _get_gsm()
	var player_vocab = _get_player_vocab_emojis()
	var reward = QuestRewards.generate_reward(quest, null, player_vocab)

	# NO UNIVERSAL MONEY - removed 💰 grant

	# Grant vocabulary rewards
	var faction_name = quest.get("faction", "Unknown")

	for pair in reward.learned_pairs:
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north != "" and south != "":
			_discover_vocab_pair(north, south)
			vocabulary_pair_learned.emit(north, south, faction_name)
			vocabulary_learned.emit(north, faction_name)
			vocabulary_learned.emit(south, faction_name)
			print("📖 %s taught you: %s/%s axis" % [faction_name, north, south])

	if reward.learned_pairs.is_empty():
		for emoji in reward.learned_vocabulary:
			if gsm and gsm.has_method("discover_emoji"):
				gsm.discover_emoji(emoji)
			vocabulary_learned.emit(emoji, faction_name)
			print("📖 %s taught you: %s" % [faction_name, emoji])

	# Update quest status
	quest["status"] = "completed"
	quest["completed_at"] = Time.get_ticks_msec()
	quest["reward"] = reward

	# Move to completed list
	active_quests.erase(quest_id)
	completed_quests.append(quest)

	# Stop timer
	_stop_quest_timer(quest_id)

	var legacy_rewards = {"💰": reward.money_amount}
	quest_completed.emit(quest_id, legacy_rewards)
	active_quests_changed.emit()
	return true


func reject_quest(quest_id: int) -> void:
	"""Reject a ready quest without claiming rewards

	Used when player doesn't want the rewards from a completed non-delivery quest.
	"""
	if not active_quests.has(quest_id):
		return

	var quest = active_quests[quest_id]

	# Must be in ready state to reject
	if quest.get("status") != "ready":
		push_warning("Cannot reject quest %d: not ready" % quest_id)
		return

	quest["status"] = "rejected"
	quest["rejected_at"] = Time.get_ticks_msec()

	# Move to failed list (rejected = voluntary failure)
	active_quests.erase(quest_id)
	failed_quests.append(quest)

	_stop_quest_timer(quest_id)

	quest_failed.emit(quest_id, "rejected")
	active_quests_changed.emit()


func is_quest_ready(quest_id: int) -> bool:
	"""Check if a quest is ready to claim"""
	if not active_quests.has(quest_id):
		return false
	return active_quests[quest_id].get("status") == "ready"

# =============================================================================
# QUEST TIMERS
# =============================================================================

func _start_quest_timer(quest_id: int, duration: float) -> void:
	"""Start countdown timer for quest"""
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(_on_quest_timeout.bind(quest_id))

	add_child(timer)
	quest_timers[quest_id] = timer
	timer.start()

func _stop_quest_timer(quest_id: int) -> void:
	"""Stop and remove quest timer"""
	if quest_timers.has(quest_id):
		var timer = quest_timers[quest_id]
		timer.stop()
		timer.queue_free()
		quest_timers.erase(quest_id)

func _on_quest_timeout(quest_id: int) -> void:
	"""Handle quest timer expiration"""
	if active_quests.has(quest_id):
		fail_quest(quest_id, "timeout")
		quest_expired.emit(quest_id)

func get_quest_time_remaining(quest_id: int) -> float:
	"""Get seconds remaining on quest timer

	Returns:
		-1 if no time limit or timer not found
	"""
	if not quest_timers.has(quest_id):
		return -1.0

	return quest_timers[quest_id].time_left

# =============================================================================
# REWARD CALCULATION
# =============================================================================

func _calculate_rewards(quest: Dictionary) -> Dictionary:
	"""Calculate rewards for completed quest

	Uses emergent reward_multiplier if available (from FactionStateMatcher alignment),
	otherwise falls back to continuous difficulty calculation.

	Difficulty-based rewards:
	- Easy quests (low quantity, no urgency): 2.0x
	- Medium quests: 3.0x
	- Hard quests (high quantity or urgent): 4.0x
	- Super complex (high quantity + urgent): 5.0x

	Returns:
		Dictionary {emoji: credits_amount}
	"""
	var resource = quest.get("resource", "")
	var quantity = quest.get("quantity", 0)

	if resource.is_empty() or quantity <= 0:
		return {}

	# EMERGENT SYSTEM: Use reward_multiplier if present (from FactionStateMatcher)
	var difficulty_multiplier = quest.get("reward_multiplier", 0.0)

	# FALLBACK: Calculate using continuous functions if not emergent quest
	if difficulty_multiplier <= 0.0:
		difficulty_multiplier = _calculate_difficulty_multiplier(quest)

	# Base cost in credits (quantity is already in credits)
	var cost_credits = quantity

	# Reward = cost * difficulty_multiplier
	var reward_credits = int(cost_credits * difficulty_multiplier)

	var rewards = {}
	rewards[resource] = reward_credits  # Return resource with multiplier

	# Small money bonus only for harder quests (25% of reward value)
	if difficulty_multiplier >= 3.0:
		var money_bonus = int(reward_credits * 0.25)
		if money_bonus > 0:
			rewards["💰"] = money_bonus

	return rewards


func _calculate_difficulty_multiplier(quest: Dictionary) -> float:
	"""Calculate difficulty multiplier using CONTINUOUS DIFFERENTIABLE FUNCTIONS

	No categorical buckets! Everything is smooth and physics-based.

	Factors:
	- Quantity: logarithmic scaling (smooth growth)
	- Time pressure: exponential decay (urgency stress)
	- Resource rarity: continuous weight from Hamiltonian coupling

	Returns: 2.0 - 5.0 (continuous, smooth)
	"""
	var quantity = quest.get("quantity", 0)
	var time_limit = quest.get("time_limit", -1)
	var resource = quest.get("resource", "")

	# Base difficulty (minimum reward)
	var base = 2.0

	# 1. QUANTITY: Logarithmic scaling (smooth, no buckets!)
	# log(1+x) gives smooth growth: 10→2.40, 30→3.43, 50→3.93
	# Quantity is now in credits (10-50 range)
	var quantity_difficulty = log(1.0 + quantity) / log(1.0 + 50.0)  # Normalize to [0,1] for qty ≈ 50
	var quantity_bonus = quantity_difficulty * 1.5  # Scale to [0, 1.5]

	# 2. TIME PRESSURE: Exponential decay (smooth urgency curve)
	# No time limit = 0.0, infinite time = 0.0, 60s = 1.0, 30s = 1.5
	var time_bonus = 0.0
	if time_limit > 0:
		# Exponential stress: stress = e^(-t/tau) where tau = 60s
		# Invert so shorter time = higher bonus
		var tau = 60.0  # Time constant (60s feels urgent)
		var normalized_time = time_limit / tau
		# urgency = 1 - e^(-k/t) where k controls curve shape
		time_bonus = 1.0 - exp(-3.0 / normalized_time)  # Smooth curve 0→1
		time_bonus = clamp(time_bonus, 0.0, 1.0)

	# 3. RESOURCE RARITY: Continuous weight (no if/else buckets!)
	# Use Hamiltonian coupling strength as rarity metric
	var rarity_bonus = _get_resource_rarity_continuous(resource)

	# Combine all factors (continuous sum)
	var total_difficulty = base + quantity_bonus + time_bonus + rarity_bonus

	# Smooth clamp to [2.0, 5.0]
	return clamp(total_difficulty, 2.0, 5.0)


func _get_resource_rarity_continuous(resource: String) -> float:
	"""Get continuous rarity weight from quantum Hamiltonian couplings

	Instead of categorical buckets, use actual coupling strengths from IconRegistry!
	This is REAL QUANTUM PHYSICS, not arbitrary categories.

	Returns: 0.0 - 1.0 (continuous based on Hamiltonian)
	"""
	# Access IconRegistry to get Hamiltonian coupling for this resource
	var icon_registry = Engine.get_singleton("IconRegistry")
	if not icon_registry:
		# Fallback: simple continuous mapping
		var rarity_map = {
			"🌾": 0.0,   # Common (wheat)
			"👥": 0.1,   # Labor
			"💰": 0.2,   # Money
			"🌻": 0.3,   # Sunflower
			"💨": 0.4,   # Flour (processed)
			"🍂": 0.5,   # Detritus (forest)
			"🍄": 0.7,   # Mushroom (nocturnal)
			"🌌": 0.8,   # Cosmic chaos
		}
		return rarity_map.get(resource, 0.3)  # Default: medium rarity

	# QUANTUM APPROACH: Use actual Hamiltonian self-energy!
	var icon = icon_registry.get_icon(resource)
	if icon and icon.has("hamiltonian_self_energy"):
		# Higher self-energy = more "isolated" = rarer
		# Normalize to [0, 1] range (typical self-energies: 0.0 - 2.0)
		var self_energy = abs(icon.hamiltonian_self_energy)
		return clamp(self_energy / 2.0, 0.0, 1.0)

	# Fallback: use coupling strength sum
	if icon and icon.has("hamiltonian_couplings"):
		var total_coupling = 0.0
		for target in icon.hamiltonian_couplings:
			total_coupling += abs(icon.hamiltonian_couplings[target])
		# Lower coupling = more isolated = rarer
		# Invert: rarity = 1.0 - coupling_normalized
		var coupling_normalized = clamp(total_coupling / 2.0, 0.0, 1.0)
		return 1.0 - coupling_normalized

	return 0.3  # Default medium rarity

# =============================================================================
# QUEST TYPE TRACKING (non-delivery quests)
# =============================================================================

func _update_shape_achieve_quest(quest: Dictionary, delta: float) -> void:
	"""Track SHAPE_ACHIEVE quest: reach target observable value once

	Quest format:
	  observable: "purity" | "entropy" | "coherence"
	  target: float (0.0-1.0)
	  comparison: ">" | "<" (defaults to ">")
	  reward_multiplier: float
	"""
	var observable_name = quest.get("observable", "purity")
	var target_value = quest.get("target", 0.7)
	var comparison = quest.get("comparison", ">")

	# Get current biome observables
	var obs = get_biome_observables(current_biome)
	var current_value = obs.get(observable_name, 0.0)

	# Check if target reached (respecting comparison operator)
	var target_met = false
	if comparison == "<":
		target_met = current_value <= target_value
	else:  # ">" or default
		target_met = current_value >= target_value

	if target_met:
		# Mark quest as ready to claim (player must press Claim)
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "target_achieved")


func _update_shape_maintain_quest(quest: Dictionary, delta: float) -> void:
	"""Track SHAPE_MAINTAIN quest: hold observable at target for duration

	Quest format:
	  observable: "purity" | "entropy" | "coherence"
	  target: float (0.0-1.0)
	  comparison: ">" | "<" (defaults to ">")
	  duration: float (seconds to maintain)
	  elapsed: float (time maintained so far)
	  reward_multiplier: float
	"""
	var observable_name = quest.get("observable", "purity")
	var target_value = quest.get("target", 0.7)
	var comparison = quest.get("comparison", ">")
	var required_duration = quest.get("duration", 30.0)

	# Get current biome observables
	var obs = get_biome_observables(current_biome)
	var current_value = obs.get(observable_name, 0.0)

	# Check if currently at target (respecting comparison operator)
	var target_met = false
	if comparison == "<":
		target_met = current_value <= target_value
	else:  # ">" or default
		target_met = current_value >= target_value

	if target_met:
		# Increment elapsed time
		quest["elapsed"] = quest.get("elapsed", 0.0) + delta

		# Check if maintained long enough
		if quest["elapsed"] >= required_duration:
			# Auto-complete quest!
			var quest_id = quest.get("id", -1)
			if quest_id >= 0:
				mark_quest_ready(quest_id, "maintained_duration")
	else:
		# Reset timer if dropped outside target
		quest["elapsed"] = 0.0


func _update_evolution_quest(quest: Dictionary, delta: float) -> void:
	"""Track EVOLUTION quest: change observable by delta amount

	Quest format:
	  observable: "purity" | "entropy" | "coherence"
	  delta: float (amount to change)
	  direction: "increase" | "decrease"
	  initial_value: float (set when quest starts)
	  reward_multiplier: float
	"""
	var observable_name = quest.get("observable", "purity")
	var required_delta = quest.get("delta", 0.2)
	var direction = quest.get("direction", "increase")

	# Get current biome observables
	var obs = get_biome_observables(current_biome)
	var current_value = obs.get(observable_name, 0.0)

	# Initialize starting value if first update
	if quest.get("initial_value") == null:
		quest["initial_value"] = current_value
		return

	var initial_value = quest["initial_value"]
	var actual_change = current_value - initial_value

	# Check if target delta achieved
	var target_met = false
	if direction == "increase":
		target_met = actual_change >= required_delta
	else:  # decrease
		target_met = actual_change <= -required_delta

	if target_met:
		# Auto-complete quest!
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "evolution_achieved")


func _update_entanglement_quest(quest: Dictionary, delta: float) -> void:
	"""Track ENTANGLEMENT quest: create coherence above target

	Quest format:
	  target_coherence: float (0.0-1.0)
	  reward_multiplier: float
	"""
	var target_coherence = quest.get("target_coherence", 0.6)

	# Get current biome observables
	var obs = get_biome_observables(current_biome)
	var current_coherence = obs.get("coherence", 0.0)

	# Check if target reached
	if current_coherence >= target_coherence:
		# Auto-complete quest!
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "entanglement_created")


func _update_achieve_eigenstate_quest(quest: Dictionary, delta: float) -> void:
	"""Track ACHIEVE_EIGENSTATE quest: reach dominant eigenstate (high purity)

	Quest format:
	  target_purity: float (0.85-0.98, prophecy-derived)
	  prophecy_text: String (display text from ProphecyEngine)
	  target_emojis: Array (emojis that should dominate)
	  reward_multiplier: float (2.0-5.0 based on stability)
	"""
	var target_purity = quest.get("target_purity", 0.95)

	# Get current biome observables
	var obs = get_biome_observables(current_biome)
	var current_purity = obs.get("purity", 0.0)

	# Check if eigenstate achieved (high purity = system in eigenstate)
	if current_purity >= target_purity:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "eigenstate_achieved")


func _update_maintain_coherence_quest(quest: Dictionary, delta: float) -> void:
	"""Track MAINTAIN_COHERENCE quest: keep coherence above threshold for duration

	Quest format:
	  target_coherence: float (0.3-0.7)
	  duration: float (seconds to maintain)
	  elapsed: float (time maintained so far, auto-managed)
	  reward_multiplier: float
	"""
	var target_coherence = quest.get("target_coherence", 0.5)
	var required_duration = quest.get("duration", 30.0)

	# Get current biome observables
	var obs = get_biome_observables(current_biome)
	var current_coherence = obs.get("coherence", 0.0)

	if current_coherence >= target_coherence:
		# Increment elapsed time
		quest["elapsed"] = quest.get("elapsed", 0.0) + delta

		# Check if maintained long enough
		if quest["elapsed"] >= required_duration:
			var quest_id = quest.get("id", -1)
			if quest_id >= 0:
				mark_quest_ready(quest_id, "coherence_maintained")
	else:
		# Reset timer if coherence drops
		quest["elapsed"] = 0.0


func _update_induce_bell_state_quest(quest: Dictionary, delta: float) -> void:
	"""Track INDUCE_BELL_STATE quest: create entanglement between specific pair

	Quest format:
	  target_pair: Array[String, String] (two emojis to entangle)
	  threshold: float (0.5-0.9 coherence magnitude)
	  reward_multiplier: float
	"""
	var target_pair = quest.get("target_pair", [])
	var threshold = quest.get("threshold", 0.7)

	if target_pair.size() < 2:
		return  # Invalid quest

	# Get quantum_computer from biome to check specific coherence
	if not current_biome or not current_biome.quantum_computer:
		return

	var qc = current_biome.quantum_computer

	# Check coherence between the specific pair
	var emoji_a = target_pair[0]
	var emoji_b = target_pair[1]

	# Try to get coherence via quantum_computer
	var coherence = 0.0
	if qc.has_method("get_coherence"):
		var coh = qc.get_coherence(emoji_a, emoji_b)
		coherence = coh.abs() if coh else 0.0

	if coherence >= threshold:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "bell_state_achieved")


func _update_prevent_decoherence_quest(quest: Dictionary, delta: float) -> void:
	"""Track PREVENT_DECOHERENCE quest: don't let purity drop below threshold

	Quest format:
	  min_purity: float (0.4-0.7)
	  duration: float (seconds to survive)
	  elapsed: float (time survived so far)
	  reward_multiplier: float
	"""
	var min_purity = quest.get("min_purity", 0.5)
	var required_duration = quest.get("duration", 60.0)

	# Get current biome observables
	var obs = get_biome_observables(current_biome)
	var current_purity = obs.get("purity", 0.0)

	if current_purity >= min_purity:
		# Still above threshold, increment elapsed time
		quest["elapsed"] = quest.get("elapsed", 0.0) + delta

		# Check if survived long enough
		if quest["elapsed"] >= required_duration:
			var quest_id = quest.get("id", -1)
			if quest_id >= 0:
				mark_quest_ready(quest_id, "decoherence_prevented")
	else:
		# Purity dropped too low - fail the quest!
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			fail_quest(quest_id, "decoherence_occurred")


func _update_collapse_deliberately_quest(quest: Dictionary, delta: float) -> void:
	"""Track COLLAPSE_DELIBERATELY quest: measure to lock in specific state

	Quest format:
	  target_emoji: String (emoji to collapse into)
	  target_probability: float (required probability after collapse)
	  has_collapsed: bool (tracks if player triggered measurement)
	  reward_multiplier: float

	Note: Player must use measurement/observation tool on target emoji.
	This function checks if the state has been collapsed to target.
	"""
	var target_emoji = quest.get("target_emoji", "")
	var target_probability = quest.get("target_probability", 0.8)

	if target_emoji.is_empty():
		return

	# Get quantum_computer from biome
	if not current_biome or not current_biome.quantum_computer:
		return

	var qc = current_biome.quantum_computer

	# Check probability of target emoji
	var probability = 0.0
	if qc.has_method("get_population"):
		probability = qc.get_population(target_emoji)

	# Also check purity - high purity + high probability = collapsed state
	var purity = qc.get_purity() if qc.has_method("get_purity") else 0.0

	# Quest completes when: high purity AND target emoji dominates
	if probability >= target_probability and purity >= 0.8:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "state_collapsed")


# =============================================================================
# QUERY FUNCTIONS
# =============================================================================

func get_active_quest_count() -> int:
	"""Get number of active quests"""
	return active_quests.size()

func get_active_quests() -> Array:
	"""Get all active quests as array"""
	return active_quests.values()

func get_quest_by_id(quest_id: int) -> Dictionary:
	"""Get quest data by ID (active quests only)"""
	return active_quests.get(quest_id, {})

func has_active_quest_for_faction(faction_name: String) -> bool:
	"""Check if there's an active quest from this faction"""
	for quest in active_quests.values():
		if quest.get("faction", "") == faction_name:
			return true
	return false

func get_completed_quest_count() -> int:
	"""Get total completed quests"""
	return completed_quests.size()

func get_failed_quest_count() -> int:
	"""Get total failed quests"""
	return failed_quests.size()

# =============================================================================
# DEBUG / TESTING
# =============================================================================

func clear_all_quests() -> void:
	"""Clear all quest data (testing only)"""
	for quest_id in quest_timers.keys():
		_stop_quest_timer(quest_id)

	active_quests.clear()
	completed_quests.clear()
	failed_quests.clear()
	next_quest_id = 0
	active_quests_changed.emit()

func print_quest_status() -> void:
	"""Print current quest state"""
	print("🗂️ Quest Manager Status:")
	print("  Active: %d" % active_quests.size())
	print("  Completed: %d" % completed_quests.size())
	print("  Failed: %d" % failed_quests.size())

	if active_quests.size() > 0:
		print("\n  Active Quests:")
		for quest_id in active_quests.keys():
			var quest = active_quests[quest_id]
			var time_left = get_quest_time_remaining(quest_id)
			var time_str = "∞" if time_left < 0 else "%ds" % int(time_left)
			print("    #%d: %s - %s (%s)" % [
				quest_id,
				quest.get("faction", "Unknown"),
				quest.get("body", quest.get("display", "???")),
				time_str
			])

static func test_quest_lifecycle() -> void:
	"""Test quest manager with sample quest"""
	print("🧪 Testing QuestManager lifecycle...")

	var QuestManagerClass = load("res://Core/Quests/QuestManager.gd")
	var manager = QuestManagerClass.new()

	# Mock economy
	var mock_economy = Node.new()
	mock_economy.set_script(load("res://Core/GameMechanics/FarmEconomy.gd"))
	manager.connect_to_economy(mock_economy)

	# Create test faction
	var faction = {
		"name": "Millwright's Union",
		"bits": [1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
		"emoji": "🌾⚙️🏭"
	}

	# Offer quest
	var quest = manager.offer_quest(faction, "BioticFlux", ["🌾", "🍄"])
	print("✓ Quest offered: ID %d" % quest["id"])

	# Accept quest
	var accepted = manager.accept_quest(quest)
	print("✓ Quest accepted: %s" % str(accepted))

	# Check status
	manager.print_quest_status()

	print("\n✅ QuestManager test complete")
