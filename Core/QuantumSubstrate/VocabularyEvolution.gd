class_name VocabularyEvolution
extends Node

## Vocabulary Virus - Self-Mutating Emoji Semantic Evolution
## Based on Revolutionary Biome Collection design
##
## Features:
## - Procedural emoji pair generation from quantum state regions
## - Authentic Schrödinger evolution with Berry phase accumulation
## - Semantic coupling (attraction/repulsion/drift)
## - Quantum cannibalism (weak concepts consumed)
## - Export novel vocabulary for crossbreeding

# Import dependencies
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const SemanticCoupling = preload("res://Core/QuantumSubstrate/SemanticCoupling.gd")

# Emoji database organized by semantic categories
const EMOJI_CATEGORIES = {
	"agriculture": ["🌾", "🌱", "🌿", "🍂", "🌳", "🌻", "🪴"],
	"labor": ["👥", "⚔️", "🏰", "👁️", "🛠️", "⚙️"],
	"cosmic": ["🌌", "🌀", "✨", "🕳️", "🌟", "☄️"],
	"economic": ["💰", "🍅", "🌾", "💎", "📈", "🏦"],
	"political": ["🏰", "⚔️", "⚖️", "👑", "🗡️"],
	"biological": ["🧬", "🦠", "🌿", "🍄", "🐛"],
	"emotional": ["😭", "☀️", "💔", "❤️‍🔥", "🌙", "😴"],
}

# Fiber bundle regions (map Bloch sphere position to emoji categories)
const FIBER_REGIONS = {
	"north_pole": "agriculture",      # θ near 0
	"south_pole": "labor",            # θ near π
	"equator_0": "cosmic",            # θ near π/2, φ near 0
	"equator_90": "political",        # θ near π/2, φ near π/2
	"equator_180": "biological",      # θ near π/2, φ near π
	"equator_270": "emotional",       # θ near π/2, φ near 3π/2
}

# Evolution pool
var evolving_qubits: Array[DualEmojiQubit] = []

# Parameters
@export var max_qubits: int = 25                  # Maximum vocabulary pool size
@export var mutation_pressure: float = 0.15       # Rate of new concept generation
@export var cannibalism_threshold: float = 0.3    # Purity below this → eaten
@export var maturity_threshold: float = 5.0       # Berry phase required for "mature" concept

# Discovered vocabulary (successfully evolved pairs)
var discovered_vocabulary: Array[Dictionary] = []  # {north, south, berry_phase, discovery_time}

# Statistics
var total_spawned: int = 0
var total_cannibalized: int = 0
var time_elapsed: float = 0.0


func _ready():
	# Seed with initial vocabulary
	_seed_initial_vocabulary()
	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_VOCABULARY") == "1":
		print("🧬 Vocabulary Evolution initialized with %d seed concepts" % evolving_qubits.size())


func _seed_initial_vocabulary():
	"""Seed the evolution pool with initial emoji pairs"""
	# Start with classic wheat pair
	var wheat_qubit = DualEmojiQubit.new("🌾", "👥", PI/2)
	# berry_phase enabled by default (no longer a method)
	evolving_qubits.append(wheat_qubit)

	# Add a few random seeds from different categories
	for i in range(4):
		var cat = EMOJI_CATEGORIES.keys()[randi() % EMOJI_CATEGORIES.keys().size()]
		var qb = _create_random_qubit_from_category(cat)
		evolving_qubits.append(qb)
		total_spawned += 1


func evolve(delta: float):
	"""Evolve the vocabulary pool for one time step

	Call this from game loop to drive the vocabulary evolution.
	"""
	time_elapsed += delta

	# 1. Authentic quantum unitary evolution
	for qb in evolving_qubits:
		qb.evolve(delta)

	# 2. Fiber-bundle driven spawns (new concepts emerge from quantum states)
	_maybe_spawn_from_fiber(delta)

	# 3. Semantic coupling between concepts (disabled for now - uses too much CPU for large pools)
	# _apply_vocabulary_coupling(delta)

	# 4. Quantum cannibalism (consume weak/incoherent concepts)
	if evolving_qubits.size() > max_qubits:
		_quantum_cannibalize()

	# 5. Harvest mature concepts
	_harvest_mature_concepts()


func _maybe_spawn_from_fiber(delta: float):
	"""Spawn new concepts based on quantum state regions

	Fiber bundle logic: Bloch sphere position determines emoji category.
	"""
	if evolving_qubits.size() >= max_qubits:
		return

	# Spawn rate scales with mutation pressure
	if randf() < mutation_pressure * delta:
		# Pick a random existing qubit to use as "parent"
		if evolving_qubits.is_empty():
			return

		var parent = evolving_qubits[randi() % evolving_qubits.size()]

		# Determine region based on parent's quantum state
		var region = _get_fiber_region(parent.theta, parent.phi)
		var category = FIBER_REGIONS.get(region, "agriculture")

		# Create new qubit in that category
		var new_qb = _create_random_qubit_from_category(category)
		evolving_qubits.append(new_qb)
		total_spawned += 1

		if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_VOCABULARY") == "1":
			print("🧬 Spawned: %s ↔ %s (region: %s)" % [new_qb.north_emoji, new_qb.south_emoji, region])


func _get_fiber_region(theta: float, phi: float) -> String:
	"""Map Bloch sphere coordinates to fiber bundle region"""
	# North pole
	if theta < PI/6:
		return "north_pole"

	# South pole
	if theta > 5*PI/6:
		return "south_pole"

	# Equator - depends on phi
	var phi_normalized = fmod(phi + TAU, TAU)  # Normalize to [0, 2π]

	if phi_normalized < PI/4 or phi_normalized > 7*PI/4:
		return "equator_0"
	elif phi_normalized < 3*PI/4:
		return "equator_90"
	elif phi_normalized < 5*PI/4:
		return "equator_180"
	else:
		return "equator_270"


func _create_random_qubit_from_category(category: String) -> DualEmojiQubit:
	"""Create a random dual-emoji qubit from a semantic category"""
	var emojis = EMOJI_CATEGORIES.get(category, ["🌾"])

	# Pick two different emojis from category
	var north = emojis[randi() % emojis.size()]
	var south = emojis[randi() % emojis.size()]

	# Try to get different emojis
	for i in range(5):
		if north != south:
			break
		south = emojis[randi() % emojis.size()]

	# Random initial state
	var initial_theta = randf_range(PI/4, 3*PI/4)  # Mid-range
	var qb = DualEmojiQubit.new(north, south, initial_theta)
	qb.phi = randf_range(-PI, PI)
	# berry_phase enabled by default (no longer a method)

	return qb


func _apply_vocabulary_coupling(delta: float):
	"""Apply semantic coupling between evolving concepts

	Uses SemanticCoupling system (already implemented in task #2).
	"""
	# Apply pairwise coupling (O(n²) but n is small)
	for i in range(evolving_qubits.size()):
		for j in range(i + 1, evolving_qubits.size()):
			SemanticCoupling.apply_semantic_coupling(
				evolving_qubits[i],
				evolving_qubits[j],
				delta,
				0.2  # Weaker coupling for vocabulary pool
			)


func _quantum_cannibalize():
	"""Consume the weakest concept to make room for new ones

	Quantum cannibalism: Low purity (mixed state) = weak concept.
	"""
	# Find qubit with lowest purity
	var min_purity = 1.0
	var weakest_index = 0

	for i in range(evolving_qubits.size()):
		var qb = evolving_qubits[i]
		var purity = qb.radius  # Purity = distance from center of Bloch sphere

		if purity < min_purity:
			min_purity = purity
			weakest_index = i

	# Cannibalize if below threshold
	if min_purity < cannibalism_threshold:
		var consumed = evolving_qubits[weakest_index]

		if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_VOCABULARY") == "1":
			print("🍽️ Cannibalized: %s ↔ %s (purity: %.2f)" % [
				consumed.north_emoji,
				consumed.south_emoji,
				min_purity
			])

		# Extract nutrients for mutation
		mutation_pressure += min_purity * 0.05

		# Remove from pool
		evolving_qubits.remove_at(weakest_index)
		total_cannibalized += 1


func _harvest_mature_concepts():
	"""Harvest concepts that have accumulated sufficient Berry phase

	Mature concepts (high Berry phase) are "discovered" and can be used
	for wheat breeding.
	"""
	for i in range(evolving_qubits.size() - 1, -1, -1):
		var qb = evolving_qubits[i]
		var coherence = qb.get_coherence()

		if coherence >= maturity_threshold:
			# Mature! Add to discovered vocabulary
			var discovery = {
				"north": qb.north_emoji,
				"south": qb.south_emoji,
				"berry_phase": coherence,
				"discovery_time": time_elapsed
			}

			discovered_vocabulary.append(discovery)

		if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_VOCABULARY") == "1":
			print("✨ DISCOVERED: %s ↔ %s (Berry phase: %.2f)" % [
				qb.north_emoji,
				qb.south_emoji,
				coherence
				])

		# Remove from evolution pool (graduated!)
		evolving_qubits.remove_at(i)


func get_discovered_vocabulary() -> Array[Dictionary]:
	"""Get all discovered emoji pairs"""
	return discovered_vocabulary


func export_vocabulary_for_breeding() -> Array:
	"""Export novel vocabulary for wheat crossbreeding

	Returns array of {north, south, stability} for use in breeding.
	"""
	var exports: Array[Dictionary] = []

	for vocab in discovered_vocabulary:
		exports.append({
			"north": vocab["north"],
			"south": vocab["south"],
			"stability": vocab["berry_phase"] / 10.0  # Normalize to 0-1 range
		})

	return exports


func get_evolution_stats() -> Dictionary:
	"""Get statistics about vocabulary evolution"""
	return {
		"pool_size": evolving_qubits.size(),
		"discovered_count": discovered_vocabulary.size(),
		"total_spawned": total_spawned,
		"total_cannibalized": total_cannibalized,
		"mutation_pressure": mutation_pressure,
		"time_elapsed": time_elapsed
	}



func get_debug_info() -> String:
	return "Vocabulary: %d evolving, %d discovered, %d spawned, %d eaten" % [
		evolving_qubits.size(),
		discovered_vocabulary.size(),
		total_spawned,
		total_cannibalized
	]


## Persistence - Serialization for Save/Load

func serialize() -> Dictionary:
	"""Serialize vocabulary state for disk persistence

	Returns Dictionary containing:
	- discovered_vocabulary: Already Array[Dictionary], serialize as-is
	- evolving_qubits: Convert DualEmojiQubit objects to serializable format
	- parameters: Current mutation_pressure and thresholds
	- statistics: Total spawned, cannibalized, time elapsed
	"""
	# Serialize evolving qubits (convert Resource objects to Dictionaries)
	var evolving_data: Array[Dictionary] = []
	for qb in evolving_qubits:
		evolving_data.append({
			"north_emoji": qb.north_emoji,
			"south_emoji": qb.south_emoji,
			"theta": qb.theta,
			"phi": qb.phi,
			"radius": qb.radius,
			# energy removed - now derived from theta: sin²(θ/2)
			"berry_phase": qb.berry_phase,
			"entanglement_graph": qb.entanglement_graph.duplicate()
		})

	return {
		"discovered_vocabulary": discovered_vocabulary.duplicate(true),
		"evolving_qubits": evolving_data,
		"parameters": {
			"mutation_pressure": mutation_pressure,
			"max_qubits": max_qubits,
			"cannibalism_threshold": cannibalism_threshold,
			"maturity_threshold": maturity_threshold
		},
		"statistics": {
			"total_spawned": total_spawned,
			"total_cannibalized": total_cannibalized,
			"time_elapsed": time_elapsed
		}
	}


func deserialize(data: Dictionary) -> void:
	"""Restore vocabulary state from serialized data

	Handles gracefully if data is missing (backward compatibility).
	Rebuilds DualEmojiQubit objects from Dictionary representation.
	"""
	if data.is_empty():
		if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_VOCABULARY") == "1":
					print("⚠️  Vocabulary state empty, keeping current pool")
		return

	# Restore discovered vocabulary
	if data.has("discovered_vocabulary"):
		if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_VOCABULARY") == "1":
					discovered_vocabulary = data["discovered_vocabulary"].duplicate(true) as Array[Dictionary]
		print("✨ Restored %d discovered concepts" % discovered_vocabulary.size())

	# Restore parameters
	if data.has("parameters"):
		var params = data["parameters"]
		mutation_pressure = params.get("mutation_pressure", 0.15)
		max_qubits = params.get("max_qubits", 25)
		cannibalism_threshold = params.get("cannibalism_threshold", 0.3)
		maturity_threshold = params.get("maturity_threshold", 5.0)

	# Restore statistics
	if data.has("statistics"):
		var stats = data["statistics"]
		total_spawned = stats.get("total_spawned", 0)
		total_cannibalized = stats.get("total_cannibalized", 0)
		time_elapsed = stats.get("time_elapsed", 0.0)

	# Restore evolving qubits (rebuild from serialized data)
	evolving_qubits.clear()
	if data.has("evolving_qubits"):
		for qb_data in data["evolving_qubits"]:
			var qb = DualEmojiQubit.new(
				qb_data.get("north_emoji", "🌾"),
				qb_data.get("south_emoji", "👥"),
				qb_data.get("theta", PI/2.0)
			)
			qb.phi = qb_data.get("phi", 0.0)
			qb.radius = qb_data.get("radius", 0.3)
			qb.energy = qb_data.get("energy", 0.3)
			qb.berry_phase = qb_data.get("berry_phase", 0.0)
			qb.entanglement_graph = qb_data.get("entanglement_graph", {}).duplicate()
			# berry_phase enabled by default (no longer a method)

			evolving_qubits.append(qb)

		if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_VOCABULARY") == "1":
					print("🧬 Restored %d evolving qubits" % evolving_qubits.size())

		if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_VOCABULARY") == "1":
				print("📚 Vocabulary deserialized - Ready to continue evolution")
