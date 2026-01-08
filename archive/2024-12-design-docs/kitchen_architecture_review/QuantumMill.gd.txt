class_name QuantumMill
extends Node2D

const FlowRateCalculator = preload("res://Core/GameMechanics/FlowRateCalculator.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")

## Quantum Mill - Non-destructive measurement infrastructure
## Couples to wheat qubits via ancilla, measures periodically
## Produces flour (resource) based on measurement outcomes

# Configuration
var grid_position: Vector2i = Vector2i.ZERO
var coupling_strength: float = 0.5  # Hamiltonian coupling coefficient
var measurement_interval: float = 1.0  # Seconds between measurements
var last_measurement_time: float = 0.0

# Statistics
var total_measurements: int = 0
var flour_outcomes: int = 0
var measurement_history: Array = []

# References
var entangled_wheat: Array = []
var farm_grid: FarmGrid = null


func _ready():
	set_process(true)
	print("🏭 QuantumMill initialized at %s" % grid_position)


func _process(delta: float):
	"""Update mill - perform measurements at interval"""
	last_measurement_time += delta

	if last_measurement_time >= measurement_interval:
		print("🏭 Mill at %s: Performing quantum measurement (time=%.2f)" % [grid_position, last_measurement_time])
		perform_quantum_measurement()
		last_measurement_time = 0.0


func set_entangled_wheat(plots: Array) -> void:
	"""Link wheat plots to this mill

	Args:
		plots: Array of WheatPlot references to couple to ancilla
	"""
	entangled_wheat = plots
	print("  Linked %d wheat plots to mill" % entangled_wheat.size())


func perform_quantum_measurement() -> void:
	"""Measure entangled wheat plots and determine flour outcomes (Model B version)

	Model B changes:
	- Plots no longer have quantum_state; use parent_biome.quantum_computer instead
	- Query purity from biome's quantum_computer
	- Flour outcome based on purity probability

	Process:
	1. Query each wheat plot's parent biome quantum state
	2. Get purity (measurement probability) from quantum computer
	3. Determine flour outcome probabilistically
	4. Accumulate flour for economy
	"""
	if entangled_wheat.is_empty():
		return

	var total_flour = 0
	var accumulated_wheat = 0

	for plot in entangled_wheat:
		if not plot or not plot.is_planted:
			continue

		# Model B: Get parent biome and quantum computer
		var biome = plot.parent_biome
		if not biome or not biome.quantum_computer:
			continue

		# Get component containing this plot's register
		var comp = biome.quantum_computer.get_component_containing(plot.register_id)
		if not comp:
			continue

		# Get purity (probability in measurement basis)
		var purity = biome.quantum_computer.get_marginal_purity(comp, plot.register_id)

		# Get mass (total probability in subspace)
		var basis_labels: Array[String] = [plot.north_emoji, plot.south_emoji]
		var mass = biome.quantum_computer.get_marginal_probability_subspace(
			comp, plot.register_id, basis_labels
		)

		if mass < 1e-6:
			# No probability to measure - skip this plot
			continue

		# Flour outcome: probabilistic based on purity
		# Higher purity = higher chance of flour outcome
		var flour_outcome = randf() < purity
		print("    Plot at %s: purity=%.2f, flour_outcome=%s" % [plot.grid_position, purity, flour_outcome])

		if flour_outcome:
			total_flour += 1
			accumulated_wheat += 1
			plot.has_been_measured = true
			plot.measured_outcome = plot.south_emoji  # Mark as measured (flour state)
			print("    ✓ Flour produced!")

	# Update statistics
	total_measurements += 1
	flour_outcomes += total_flour

	measurement_history.append({
		"time": Time.get_ticks_msec(),
		"flour_produced": total_flour,
		"wheat_count": entangled_wheat.size()
	})

	# Convert flour to economy resource
	print("  total_flour=%d, farm_grid=%s" % [total_flour, farm_grid])
	if total_flour > 0 and farm_grid:
		# Route through FarmEconomy for proper conversion
		if farm_grid.has_method("process_mill_flour"):
			print("  Calling process_mill_flour(%d)" % total_flour)
			farm_grid.process_mill_flour(total_flour)
		else:
			print("  ERROR: farm_grid has no process_mill_flour method!")


func get_flow_rate() -> Dictionary:
	"""Compute flour production flow rate from measurement history

	Returns:
		Dictionary with keys: mean, variance, std_error, confidence
	"""
	return FlowRateCalculator.compute_flow_rate(measurement_history, 60.0)


func get_debug_info() -> Dictionary:
	"""Return mill state for debugging"""
	var flow_rate = get_flow_rate()
	return {
		"position": grid_position,
		"total_measurements": total_measurements,
		"flour_produced": flour_outcomes,
		"wheat_count": entangled_wheat.size(),
		"flow_rate_mean": flow_rate.get("mean", 0.0),
		"coupling_strength": coupling_strength,
		"measurement_interval": measurement_interval,
	}
