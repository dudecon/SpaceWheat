class_name BiomePlotRegisterManager
extends RefCounted

## Plot Register Management Component
##
## Extracted from BiomeBase to handle:
## - Plot register allocation and tracking (plot_registers dictionary)
## - Register-to-plot mapping for quantum state access
## - V2 Architecture: Unbound register queries for EXPLORE action

const QuantumRegister = preload("res://Core/QuantumSubstrate/QuantumRegister.gd")

# Signals
signal qubit_created(position: Vector2i, qubit: Resource)

# Plot register mapping: Vector2i -> QuantumRegister
var plot_registers: Dictionary = {}  # Vector2i -> QuantumRegister (metadata only)

# Injected dependencies
var quantum_computer = null
var biome_type: String = "Base"


func set_quantum_computer(qc, biome_name: String) -> void:
	"""Set the quantum computer reference and biome type."""
	quantum_computer = qc
	biome_type = biome_name


# ============================================================================
# Qubit Allocation API (Model C)
# ============================================================================

func allocate_register_for_plot(position: Vector2i, north_emoji: String = "🌾", south_emoji: String = "🌽") -> int:
	"""Allocate a new qubit for a planted plot.

	Uses allocate_qubit() to add axis to RegisterMap, stores metadata in plot_registers.

	Returns: qubit index (unique per biome)
	"""
	if not quantum_computer:
		push_error("QuantumComputer not initialized!")
		return -1

	# Model C: Allocate qubit in quantum computer
	var reg_id = quantum_computer.allocate_qubit(north_emoji, south_emoji)

	# Create metadata register
	var qubit_reg = QuantumRegister.new(reg_id, biome_type, 0)
	qubit_reg.north_emoji = north_emoji
	qubit_reg.south_emoji = south_emoji
	qubit_reg.is_planted = true

	plot_registers[position] = qubit_reg

	qubit_created.emit(position, qubit_reg)
	return reg_id


# ============================================================================
# Plot Register Metadata (Model C)
# ============================================================================

func clear_subplot_for_plot(position: Vector2i) -> void:
	"""Clear subplot metadata when plot is unplanted (Model C).

	Model C: QuantumComputer state persists - this only clears the measurement axis metadata.
	The underlying quantum state continues evolving with all emojis intact.

	Args:
		position: Grid position of the plot to clear
	"""
	if position in plot_registers:
		plot_registers.erase(position)


func get_register_for_plot(position: Vector2i) -> QuantumRegister:
	"""Get the QuantumRegister metadata for a plot."""
	return plot_registers.get(position, null)


func get_component_for_plot(position: Vector2i) -> Dictionary:
	"""Get the qubit info for this plot's register (Model C: returns qubit metadata).

	Returns: {register_id: int, north: String, south: String} or empty dict
	"""
	var reg = get_register_for_plot(position)
	if not reg:
		return {}
	return {"register_id": reg.register_id, "north": reg.north_emoji, "south": reg.south_emoji}


func get_register_id_for_plot(position: Vector2i) -> int:
	"""Get the logical register ID for a plot."""
	var reg = get_register_for_plot(position)
	if not reg:
		return -1
	return reg.register_id


func clear_register_for_plot(position: Vector2i) -> void:
	"""Remove register metadata when plot is unplanted."""
	if position in plot_registers:
		plot_registers.erase(position)


func has_plot(position: Vector2i) -> bool:
	"""Check if a plot has a register allocated"""
	return position in plot_registers


func get_all_plot_positions() -> Array:
	"""Get all positions with allocated registers"""
	return plot_registers.keys()


# ============================================================================
# V2 Architecture: Register Binding Tracking
# ============================================================================

func get_unbound_registers(plot_pool, biome) -> Array[int]:
	"""Get all register IDs not currently bound to a terminal.

	Used by EXPLORE action for probability-weighted discovery.
	Returns registers available for new terminal binding.

	NOTE: In v2 architecture, a "register" is a qubit axis (0, 1, 2, ...).
	Each register has a north/south emoji pair from RegisterMap.

	Args:
		plot_pool: PlotPool instance (needed to query Terminal binding state)
		biome: BiomeBase instance (for PlotPool register identity check)
	"""
	if not quantum_computer or not quantum_computer.register_map:
		return []

	# Register IDs are qubit indices: 0 to num_qubits-1
	var num_qubits = quantum_computer.register_map.num_qubits
	var unbound: Array[int] = []

	for reg_id in range(num_qubits):
		# Query PlotPool to check if register is bound to ANY terminal
		if not plot_pool or not plot_pool.is_register_bound(reg_id, biome):
			unbound.append(reg_id)

	return unbound


func get_register_probabilities(plot_pool, observer, biome) -> Dictionary:
	"""Get probability distribution over all unbound registers.

	Returns: {register_id: probability} for unbound registers only.
	Used by EXPLORE for weighted selection.

	Args:
		plot_pool: PlotPool instance (needed to query Terminal binding state)
		observer: BiomeQuantumObserver for probability calculations
		biome: BiomeBase instance (passed through to get_unbound_registers)
	"""
	var probs: Dictionary = {}
	var unbound = get_unbound_registers(plot_pool, biome)

	for reg_id in unbound:
		if observer:
			probs[reg_id] = observer.get_register_probability(reg_id)
		else:
			probs[reg_id] = 0.5

	return probs


func get_total_register_count() -> int:
	"""Get total number of registers (qubits) in this biome."""
	if not quantum_computer or not quantum_computer.register_map:
		return 0
	return quantum_computer.register_map.num_qubits


func get_available_registers_v2(plot_pool, biome) -> Array[int]:
	"""Get registers not currently bound to any terminal (V2 Architecture).

	V2.2: Queries PlotPool directly instead of relying on _bound_registers.
	This ensures Terminal is the single source of truth.

	Args:
		plot_pool: PlotPool instance to query
		biome: The biome reference (for PlotPool queries)

	Returns:
		Array of register IDs available for binding
	"""
	if not quantum_computer or not quantum_computer.register_map:
		return []

	var num_qubits = quantum_computer.register_map.num_qubits
	var available: Array[int] = []

	for reg_id in range(num_qubits):
		if not plot_pool.is_register_bound_v2(biome, reg_id):
			available.append(reg_id)

	return available


# ============================================================================
# State Management
# ============================================================================

func clear() -> void:
	"""Clear all plot registers"""
	plot_registers.clear()


func find_plot_by_register_id(register_id: int) -> Vector2i:
	"""Find the plot position for a given register ID.

	Returns: Vector2i position, or Vector2i(-1, -1) if not found.
	"""
	for pos in plot_registers.keys():
		var reg = plot_registers[pos]
		if reg and reg.register_id == register_id:
			return pos
	return Vector2i(-1, -1)
