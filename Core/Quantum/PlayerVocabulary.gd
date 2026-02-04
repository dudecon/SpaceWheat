extends Node

## Player Vocabulary Quantum Computer
## Note: No class_name to avoid conflict with autoload singleton name
## Maintains a separate density matrix for player's learned vocab pairs
## Used for calculating affinity to biomes

const QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")

var vocab_qc: QuantumComputer = null
var learned_pairs: Array[Dictionary] = []  # [{north, south, timestamp}]

signal vocab_learned(north: String, south: String)
signal vocab_forgotten(north: String, south: String)

func _ready():
	vocab_qc = QuantumComputer.new("player_vocabulary")

func learn_vocab_pair(north: String, south: String) -> void:
	"""Add newly learned vocab pair to player's quantum computer."""
	# Check if already learned
	for pair in learned_pairs:
		if pair.get("north", "") == north and pair.get("south", "") == south:
			return  # Already known

	# Allocate qubit in vocab QC (initializes to ground state automatically)
	var qubit_idx = vocab_qc.allocate_qubit(north, south)
	if qubit_idx >= 0:
		# Track in learned list
		learned_pairs.append({
			"north": north,
			"south": south,
			"timestamp": Time.get_ticks_msec()
		})

		vocab_learned.emit(north, south)

func forget_vocab_pair(north: String, south: String) -> void:
	"""Remove vocab pair from learned list (keeps QC state for now)."""
	for i in range(learned_pairs.size()):
		var pair = learned_pairs[i]
		if pair.get("north", "") == north and pair.get("south", "") == south:
			learned_pairs.remove_at(i)
			vocab_forgotten.emit(north, south)
			break

func has_learned(north: String, south: String) -> bool:
	"""Check if player has learned this vocab pair."""
	for pair in learned_pairs:
		if pair.get("north", "") == north and pair.get("south", "") == south:
			return true
	return false

func get_all_learned_pairs() -> Array[Dictionary]:
	"""Get all learned vocab pairs."""
	return learned_pairs.duplicate()

func get_vocab_emojis() -> Array[String]:
	"""Get all unique emojis from learned vocab pairs."""
	var emojis: Array[String] = []
	for pair in learned_pairs:
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north != "" and north not in emojis:
			emojis.append(north)
		if south != "" and south not in emojis:
			emojis.append(south)
	return emojis

## Persistence
func serialize() -> Dictionary:
	return {
		"learned_pairs": learned_pairs.duplicate(true),
		"density_matrix": vocab_qc.serialize() if vocab_qc else {}
	}

func deserialize(data: Dictionary) -> void:
	if data.has("learned_pairs"):
		learned_pairs = data["learned_pairs"].duplicate(true)

	if data.has("density_matrix") and vocab_qc:
		vocab_qc.deserialize(data["density_matrix"])

func reset() -> void:
	"""Clear all learned pairs and reset quantum computer."""
	learned_pairs.clear()
	if vocab_qc:
		vocab_qc = QuantumComputer.new("player_vocabulary")
