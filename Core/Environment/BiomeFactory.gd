class_name BiomeFactory
extends RefCounted

## Create biomes dynamically from emoji axis configurations
##
## Example:
##     BiomeFactory.create([
##         {"north": "🔥", "south": "❄️"},
##         {"north": "💧", "south": "🏜️"},
##         {"north": "💨", "south": "🌾"}
##     ], "Kitchen")

const RegisterMap = preload("res://Core/QuantumSubstrate/RegisterMap.gd")
const HamiltonianBuilder = preload("res://Core/QuantumSubstrate/HamiltonianBuilder.gd")
const LindbladBuilder = preload("res://Core/QuantumSubstrate/LindbladBuilder.gd")
const QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")


static func create(axes: Array[Dictionary], biome_name: String) -> Node:
	"""Create a biome from axis definitions.

	Args:
	    axes: Array of {north: emoji, south: emoji}
	    biome_name: Name for the biome

	Returns:
	    BiomeBase node with quantum_computer configured

	Example:
	    BiomeFactory.create([
	        {"north": "🔥", "south": "❄️"},  # Qubit 0: Temperature
	        {"north": "💧", "south": "🏜️"},  # Qubit 1: Moisture
	        {"north": "💨", "south": "🌾"}   # Qubit 2: Substance
	    ], "Kitchen")
	"""

	# Note: We can't instantiate BiomeBase directly since it's abstract
	# This is a helper for creating the quantum_computer
	# The actual biome class should call this to set up its quantum system

	var quantum_computer = QuantumComputer.new(biome_name)

	# Register each axis
	for i in range(axes.size()):
		var axis = axes[i]
		quantum_computer.register_map.register_axis(
			i, axis["north"], axis["south"]
		)

	# Initialize density matrix to correct size
	var dim = 1 << axes.size()  # 2^num_qubits
	quantum_computer.density_matrix = ComplexMatrix.zeros(dim)

	# Initialize to uniform superposition across all basis states
	quantum_computer.initialize_uniform_superposition()

	print("🏭 Created quantum computer for '%s': %d qubits, %dD" %
		  [biome_name, axes.size(), dim])

	return quantum_computer


static func gather_icons(register_map: RegisterMap) -> Dictionary:
	"""Get icons dictionary for emojis in the register map.

	Args:
	    register_map: RegisterMap with coordinates

	Returns:
	    Dictionary[emoji] → Icon (filtered by what's in register_map)
	"""
	var icons: Dictionary = {}

	# Get IconRegistry from autoload
	var icon_registry = Engine.get_main_loop().root.get_node_or_null("IconRegistry")

	if not icon_registry:
		push_error("🛁 IconRegistry not available!")
		return icons

	# Gather icons for emojis in this register map
	for emoji in register_map.coordinates:
		if icon_registry.has_icon(emoji):
			icons[emoji] = icon_registry.get_icon(emoji)
		else:
			push_warning("🛁 Icon not found for emoji: " + emoji)

	return icons


# Helper to load ComplexMatrix
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
