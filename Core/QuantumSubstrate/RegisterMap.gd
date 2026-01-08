class_name RegisterMap
extends RefCounted

## RegisterMap: Translates emoji labels to qubit coordinates
##
## This is the critical translation layer between:
##   - IconRegistry (global physics): HOW emojis interact
##   - QuantumComputer (local hardware): WHERE emojis live in Hilbert space
##
## Structure: Dictionary[emoji] → {qubit: int, pole: int}
##
## Example:
##   coordinates["🔥"] = {qubit: 0, pole: NORTH}  # Fire is |0⟩ on qubit 0
##   coordinates["❄️"] = {qubit: 0, pole: SOUTH}  # Cold is |1⟩ on qubit 0

const NORTH = 0  # |0⟩ state
const SOUTH = 1  # |1⟩ state

## Primary data structure: emoji → coordinate
## {
##   "🔥": {"qubit": 0, "pole": NORTH},
##   "❄️": {"qubit": 0, "pole": SOUTH},
##   "💧": {"qubit": 1, "pole": NORTH},
##   ...
## }
var coordinates: Dictionary = {}

## Reverse lookup: qubit → {north: emoji, south: emoji}
## {
##   0: {"north": "🔥", "south": "❄️"},
##   1: {"north": "💧", "south": "🏜️"},
##   ...
## }
var axes: Dictionary = {}

## Number of qubits registered
var num_qubits: int = 0


func register_axis(qubit_index: int, north_emoji: String, south_emoji: String) -> void:
	"""Register a qubit axis with its pole labels.

	Args:
	    qubit_index: Qubit number (0, 1, 2, ...)
	    north_emoji: Label for |0⟩ state
	    south_emoji: Label for |1⟩ state
	"""

	# Validate orthogonality
	assert(north_emoji != south_emoji,
		"Qubit %d: poles must differ! Got '%s' for both" % [qubit_index, north_emoji])

	# Validate no collisions
	if coordinates.has(north_emoji):
		var existing = coordinates[north_emoji]
		assert(existing["qubit"] == qubit_index,
			"Emoji '%s' already registered on qubit %d!" % [north_emoji, existing["qubit"]])

	if coordinates.has(south_emoji):
		var existing = coordinates[south_emoji]
		assert(existing["qubit"] == qubit_index,
			"Emoji '%s' already registered on qubit %d!" % [south_emoji, existing["qubit"]])

	# Register both poles
	coordinates[north_emoji] = {"qubit": qubit_index, "pole": NORTH}
	coordinates[south_emoji] = {"qubit": qubit_index, "pole": SOUTH}

	# Reverse lookup
	axes[qubit_index] = {"north": north_emoji, "south": south_emoji}

	num_qubits = max(num_qubits, qubit_index + 1)

	print("📊 Qubit %d: |0⟩=%s |1⟩=%s" % [qubit_index, north_emoji, south_emoji])


func has(emoji: String) -> bool:
	"""Check if emoji is registered."""
	return coordinates.has(emoji)


func qubit(emoji: String) -> int:
	"""Get qubit index for emoji, or -1 if not found."""
	return coordinates.get(emoji, {}).get("qubit", -1)


func pole(emoji: String) -> int:
	"""Get pole (0=NORTH, 1=SOUTH) for emoji, or -1 if not found."""
	return coordinates.get(emoji, {}).get("pole", -1)


func axis(qubit_index: int) -> Dictionary:
	"""Get {north: emoji, south: emoji} for qubit."""
	return axes.get(qubit_index, {})


func dim() -> int:
	"""Hilbert space dimension (2^num_qubits)."""
	return 1 << num_qubits


func basis_to_emojis(index: int) -> Array[String]:
	"""Convert basis state index to array of emojis.

	Example (3 qubits):
	    basis_to_emojis(0) → ["🔥", "💧", "💨"]  # |000⟩
	    basis_to_emojis(7) → ["❄️", "🏜️", "🌾"]  # |111⟩
	"""
	var result: Array[String] = []

	# Bounds check
	if index < 0 or index >= dim():
		return result  # Return empty array for invalid index

	for q in range(num_qubits):
		# Extract bit at position q
		# For qubit 0 (leftmost), shift by (num_qubits - 1 - 0)
		# For qubit 2 (rightmost), shift by (num_qubits - 1 - 2) = 0
		var shift = num_qubits - 1 - q
		var bit = (index >> shift) & 1

		var ax = axes[q]
		result.append(ax["north"] if bit == 0 else ax["south"])

	return result


func emojis_to_basis(emojis: Array[String]) -> int:
	"""Convert array of emojis to basis state index.

	Example (3 qubits):
	    emojis_to_basis(["🔥", "💧", "💨"]) → 0  # |000⟩
	    emojis_to_basis(["❄️", "🏜️", "🌾"]) → 7  # |111⟩
	"""
	var index = 0

	for q in range(num_qubits):
		var ax = axes[q]
		var emoji = emojis[q]

		if emoji == ax["south"]:
			# Set bit to 1
			var shift = num_qubits - 1 - q
			index |= (1 << shift)

	return index


func _to_string() -> String:
	"""Debug representation."""
	var s = "RegisterMap(%d qubits, %dD):\n" % [num_qubits, dim()]

	for q in range(num_qubits):
		var ax = axes[q]
		s += "  Qubit %d: |0⟩=%s |1⟩=%s\n" % [q, ax["north"], ax["south"]]

	return s
