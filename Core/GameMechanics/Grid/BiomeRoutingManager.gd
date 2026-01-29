class_name BiomeRoutingManager
extends RefCounted

## BiomeRoutingManager - Multi-biome registry and quantum computer routing
##
## Extracted from FarmGrid.gd as part of decomposition.
## Handles biome registration, plot-to-biome assignment, and quantum computer access.

# Multi-biome registry
var biomes: Dictionary = {}  # String → BiomeBase (registry of all biomes)
var plot_biome_assignments: Dictionary = {}  # Vector2i → String (plot position → biome name)

# Register mapping (for visualization team)
var plot_register_mapping: Dictionary = {}  # Vector2i → int (plot position → register_id in biome)
var plot_to_biome_quantum_computer: Dictionary = {}  # Vector2i → QuantumComputer reference

# Legacy biome reference (for backward compatibility)
var legacy_biome = null

# External references
var _verbose = null


func set_verbose(verbose_ref) -> void:
	"""Set verbose logger reference."""
	_verbose = verbose_ref


func set_legacy_biome(biome) -> void:
	"""Set legacy biome for backward compatibility."""
	legacy_biome = biome


func register_biome(biome_name: String, biome_instance) -> void:
	"""Register a biome in the grid's biome registry

	Called by Farm._ready() during initialization.
	Enables the grid to route plot operations to the correct biome.
	"""
	if not biome_name or not biome_instance:
		push_error("Cannot register biome: invalid name or instance")
		return

	biomes[biome_name] = biome_instance
	if _verbose:
		_verbose.info("biome", "📍", "Biome registered: %s" % biome_name)


func assign_plot_to_biome(position: Vector2i, biome_name: String) -> bool:
	"""Assign a specific plot to a biome (graceful - skips unregistered biomes)

	Called by Farm._ready() during initialization.
	Configures which biome manages each plot's quantum evolution.

	Returns true if assigned, false if biome not registered (deferred).
	Graceful handling: unregistered biomes are skipped without error,
	allowing plots to be assigned retroactively when biomes are explored.
	"""
	if not biomes.has(biome_name):
		# GRACEFUL: Biome may be locked/not-yet-loaded - defer assignment
		return false

	plot_biome_assignments[position] = biome_name
	return true


func get_biome_for_plot(position: Vector2i):
	"""Get the biome responsible for a specific plot

	Returns the biome instance for the given plot position.
	If no assignment exists, returns the BioticFlux biome (default).
	"""
	# Check if plot has explicit assignment
	if plot_biome_assignments.has(position):
		var biome_name = plot_biome_assignments[position]
		if biomes.has(biome_name):
			return biomes[biome_name]

	# Fallback to BioticFlux (default biome)
	if biomes.has("BioticFlux"):
		return biomes["BioticFlux"]

	# Final fallback to legacy biome variable (for backward compatibility)
	return legacy_biome


func get_biome_id_for_plot(position: Vector2i) -> String:
	"""Get the biome ID (name) for a plot position."""
	return plot_biome_assignments.get(position, "")


func get_entanglement_graph() -> Dictionary:
	"""Export aggregated entanglement graph from all biomes

	Returns a consolidated entanglement_graph showing which registers are entangled across all biomes.
	Format: {register_id → Array[register_id]} (adjacency list)

	Used by visualization team to render entanglement relationships.
	"""
	var consolidated_graph: Dictionary = {}

	# Collect entanglement graphs from all biomes
	for biome_name in biomes.keys():
		var biome = biomes[biome_name]
		if biome and biome.quantum_computer:
			var quantum_comp = biome.quantum_computer
			if quantum_comp.entanglement_graph:
				# Merge this biome's graph into consolidated graph
				for reg_id in quantum_comp.entanglement_graph.keys():
					var entangled_with = quantum_comp.entanglement_graph[reg_id]
					if not consolidated_graph.has(reg_id):
						consolidated_graph[reg_id] = []

					# Add unique entanglements
					for partner_id in entangled_with:
						if not consolidated_graph[reg_id].has(partner_id):
							consolidated_graph[reg_id].append(partner_id)

	return consolidated_graph


func get_plot_to_register_mapping() -> Dictionary:
	"""Export plot position → register_id mapping for visualization team

	Returns: {Vector2i position → int register_id}
	Used to correlate visual grid with quantum register structure.
	"""
	return plot_register_mapping.duplicate()


func get_quantum_computer_for_plot(position: Vector2i) -> Resource:
	"""Get the QuantumComputer instance for a plot's biome

	Returns: QuantumComputer resource, or null if not available
	"""
	return plot_to_biome_quantum_computer.get(position, null)


func track_register_allocation(position: Vector2i, register_id: int, quantum_computer) -> void:
	"""Track register allocation for a plot (legacy planting hook)."""
	plot_register_mapping[position] = register_id
	if quantum_computer:
		plot_to_biome_quantum_computer[position] = quantum_computer


func clear_register_tracking(position: Vector2i) -> void:
	"""Clear register tracking for a plot (called on harvest)."""
	plot_register_mapping.erase(position)
	plot_to_biome_quantum_computer.erase(position)


func get_register_for_plot(position: Vector2i) -> int:
	"""Get the RegisterId for a plot.

	Returns: Register ID (int) if plot is planted, -1 if not found
	"""
	return plot_register_mapping.get(position, -1)


func is_biomes_empty() -> bool:
	"""Check if no biomes are registered."""
	return biomes.is_empty()


func get_all_biomes() -> Dictionary:
	"""Get all registered biomes."""
	return biomes
