class_name BasePlot
extends Resource

## BasePlot - Foundation class for all farm plots (Model B - Physics Correct)
##
## Model B: Plot is a HARDWARE ATTACHMENT to a biome's QuantumComputer.
## Does NOT own quantum state - only holds RegisterId reference and metadata.

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const QuantumRigorConfig = preload("res://Core/GameState/QuantumRigorConfig.gd")

signal growth_complete
signal state_collapsed(final_state: String)

# ============================================================================
# MODEL B: Register Reference (NOT Independent Quantum State)
# ============================================================================

# Plot identification
@export var plot_id: String = ""
@export var grid_position: Vector2i = Vector2i.ZERO

# Model B: Register reference (points to QuantumComputer's logical qubit)
@export var register_id: int = -1  # Logical qubit ID in parent biome's quantum computer
var parent_biome: Node = null  # Reference to BiomeBase that owns quantum state

# Measurement basis labels (NOT quantum state!)
@export var north_emoji: String = "🌾"
@export var south_emoji: String = "🌽"

# Plot metadata (NOT quantum state)
@export var is_planted: bool = false
@export var has_been_measured: bool = false
@export var measured_outcome: String = ""  # Measurement result ("north", "south", or empty)

# Conspiracy network connection
@export var conspiracy_node_id: String = ""
@export var conspiracy_bond_strength: float = 0.0

# Berry phase accumulator (plot memory)
@export var replant_cycles: int = 0
@export var berry_phase: float = 0.0

# Entanglement tracking (updated via parent_biome quantum computer)
var entangled_plots: Dictionary = {}  # plot_id -> strength
var plot_infrastructure_entanglements: Array[Vector2i] = []
const MAX_ENTANGLEMENTS = 3

# Persistent gate infrastructure (survives harvest/replant)
var persistent_gates: Array[Dictionary] = []


func _init():
	plot_id = "plot_%d" % randi()


# ============================================================================
# MODEL B: Quantum State Access (Computed from Parent Biome)
# ============================================================================

## Get current measurement outcome (or empty if unmeasured)
func get_measurement_outcome() -> String:
	return measured_outcome

## Get basis labels for this plot's measurement basis
func get_basis_labels() -> Array[String]:
	return [north_emoji, south_emoji]

## Get purity from parent biome's quantum computer
func get_purity() -> float:
	"""Query purity from parent biome's quantum computer.

	Model B: Purity is computed from the shared state, not stored locally.
	Returns 0 if plot not planted or no parent_biome.
	"""
	if not is_planted or not parent_biome or register_id < 0:
		return 0.0

	var reg = parent_biome.get_register_for_plot(grid_position)
	if not reg:
		return 0.0

	var comp = parent_biome.quantum_computer.get_component_containing(register_id)
	if not comp:
		return 0.0

	return parent_biome.quantum_computer.get_marginal_purity(comp, register_id)

## Get coherence from parent biome's quantum computer
func get_coherence() -> float:
	"""Query coherence from parent biome's quantum computer."""
	if not is_planted or not parent_biome or register_id < 0:
		return 0.0

	var comp = parent_biome.quantum_computer.get_component_containing(register_id)
	if not comp:
		return 0.0

	return parent_biome.quantum_computer.get_marginal_coherence(comp, register_id)

## Get mass (probability in subspace)
func get_mass() -> float:
	"""Get probability mass in measurement basis subspace."""
	if not is_planted or not parent_biome or register_id < 0:
		return 0.0

	var comp = parent_biome.quantum_computer.get_component_containing(register_id)
	if not comp:
		return 0.0

	return parent_biome.quantum_computer.get_marginal_probability_subspace(comp, register_id, [north_emoji, south_emoji])

## Core Methods

func get_dominant_emoji() -> String:
	"""Get the current outcome emoji (measured or measurement outcome)

	Model B: Returns measurement_outcome if measured, or basis label based on marginal.
	"""
	if has_been_measured and measured_outcome != "":
		return measured_outcome

	# If unmeasured, return dominant basis state based on purity
	# This is approximate - true outcome only known after measurement
	var p_north = get_purity() * 0.5  # Simplified; real impl queries marginal
	return north_emoji if (randf() < 0.5) else south_emoji


func get_plot_emojis() -> Dictionary:
	"""Get the dual-emoji pair for this plot type

	Default implementation returns current basis labels.
	Subclasses can override to customize per-plot basis.
	"""
	return {"north": north_emoji, "south": south_emoji}


func plant(biome_or_labor = null, wheat_cost: float = 0.0, optional_biome = null) -> bool:
	"""Plant this plot - allocate register in biome's quantum computer (Model B version)

	Model B: Planting allocates a logical qubit register in the parent biome's
	QuantumComputer. Does NOT create an independent quantum state.

	Args:
		biome_or_labor: BiomeBase (preferred), or labor amount (legacy)
		wheat_cost: Wheat cost (legacy parameter, ignored)
		optional_biome: BiomeBase if first arg is labor amount (legacy)

	Returns:
		true if successful, false if failed
	"""
	# Determine parent biome
	var biome = null
	if biome_or_labor is Node and biome_or_labor.has_method("allocate_register_for_plot"):
		biome = biome_or_labor
	elif optional_biome and optional_biome.has_method("allocate_register_for_plot"):
		biome = optional_biome
	else:
		push_error("No valid biome provided for planting!")
		return false

	parent_biome = biome

	# Get basis labels for this plot
	var emojis = get_plot_emojis()
	north_emoji = emojis.get("north", "🌾")
	south_emoji = emojis.get("south", "🌽")

	# Allocate register in biome's quantum computer (Model B)
	register_id = biome.allocate_register_for_plot(grid_position, north_emoji, south_emoji)

	if register_id < 0:
		push_error("Failed to allocate register for plot %s!" % grid_position)
		return false

	# Mark as planted
	is_planted = true
	has_been_measured = false
	measured_outcome = ""

	print("🌱 Plot %s: allocated register %d in %s biome" % [grid_position, register_id, biome.get_biome_type()])
	return true


func measure(_icon_network = null) -> String:
	"""Measure (collapse) quantum state at this plot (Model B version)

	Model B: Delegates to parent_biome's quantum_computer.measure_register()
	for projective measurement.

	Returns: The measurement outcome ("north" or "south")
	Sets: has_been_measured = true and measured_outcome on success
	"""
	if not parent_biome or register_id < 0:
		push_error("Plot %s not properly planted - no parent biome!" % grid_position)
		return ""

	if not is_planted:
		push_error("Cannot measure unplanted plot!")
		return ""

	if has_been_measured:
		push_warning("Plot %s already measured - outcome: %s" % [grid_position, measured_outcome])
		return measured_outcome

	# Get component from quantum computer
	var comp = parent_biome.quantum_computer.get_component_containing(register_id)
	if not comp:
		push_error("Register %d not in any component!" % register_id)
		return ""

	# Projective measurement via quantum_computer
	var outcome = parent_biome.quantum_computer.measure_register(comp, register_id)

	# Record outcome
	has_been_measured = true
	measured_outcome = outcome

	print("🔬 Plot %s measured: outcome=%s (north: %s, south: %s)" % [
		grid_position, outcome, north_emoji, south_emoji])

	return outcome


func harvest() -> Dictionary:
	"""Harvest this plot - collect yield and clear quantum state (Model B version)

	Model B: Queries purity from parent_biome's quantum_computer.

	Manifest Section 4.4: Harvest follows Gozouta protocol:
	- If POSTSELECT_COSTED enabled: cost = 1/P(subspace), yield *= (1/cost)
	- If INSPECTOR mode: use old formula (backward compatible)

	Returns: Dictionary with:
		- success: bool
		- outcome: String (emoji)
		- energy: float (raw quantum energy for credits calculation)
		- yield: int (credits)
		- measurement_cost: float (POSTSELECT_COSTED mode only)
	"""
	if not is_planted or not parent_biome:
		return {"success": false, "yield": 0, "energy": 0.0}

	# Get quantum rigor config
	var config = QuantumRigorConfig.instance
	var use_costed_model = config and config.selective_measure_model == QuantumRigorConfig.SelectiveMeasureModel.POSTSELECT_COSTED

	var outcome = ""
	var measurement_cost = 1.0

	# Auto-measure if not already measured
	if not has_been_measured:
		measure()

	# Double-check measurement succeeded
	if not has_been_measured:
		return {"success": false, "yield": 0, "energy": 0.0}

	# Map basis outcome to emoji (Model B: measured_outcome is basis name, not emoji)
	if measured_outcome == "north":
		outcome = north_emoji
	elif measured_outcome == "south":
		outcome = south_emoji
	else:
		outcome = "?"

	# Get purity from parent biome's quantum computer (Model B)
	# Purity Tr(ρ²): 1.0 = pure state, 1/N = maximally mixed
	var purity = get_purity()
	if purity == 0.0:
		purity = 1.0  # Default to pure if no quantum state access

	# Purity multiplier for yield:
	# - Pure state (Tr(ρ²) = 1.0) → 2.0× yield
	# - Mixed state (Tr(ρ²) = 0.5) → 1.0× yield
	# - Maximally mixed (Tr(ρ²) ≈ 0.17) → 0.34× yield
	var purity_multiplier = 2.0 * purity

	# Base yield: 10 credits if measurement succeeded
	# (Manifest Section 4.4: outcome-based, not radius-based)
	var base_yield = 10.0

	# Apply purity multiplier
	var yield_with_purity = base_yield * purity_multiplier

	# Apply measurement cost penalty (Manifest Section 4.3)
	# POSTSELECT_COSTED: yield *= (1/cost)
	# INSPECTOR: cost = 1.0, so no penalty
	var yield_amount = max(1, int(yield_with_purity / measurement_cost))

	# Clear the plot (Model B: remove register from biome)
	is_planted = false
	register_id = -1
	has_been_measured = false
	measured_outcome = ""  # Clear stored outcome
	replant_cycles += 1

	# Remove register from parent biome
	if parent_biome and parent_biome.has_method("clear_register_for_plot"):
		parent_biome.clear_register_for_plot(grid_position)

	var result_dict = {
		"success": true,
		"outcome": outcome,
		"energy": base_yield,  # Legacy key - now represents base yield
		"yield": yield_amount,
		"purity": purity,  # Quantum state purity Tr(ρ²)
		"purity_multiplier": purity_multiplier  # Yield multiplier from purity
	}

	# Add measurement cost if using costed model
	if use_costed_model:
		result_dict["measurement_cost"] = measurement_cost

	print("✂️  Plot %s harvested: purity=%.3f (×%.2f), cost=%.2f/%.2f, outcome=%s, yield=%d" % [
		grid_position, purity, purity_multiplier, 1.0/measurement_cost, measurement_cost, outcome, yield_amount])

	return result_dict


func collapse_to_measurement(outcome: String) -> void:
	"""Collapse quantum state based on measurement outcome (Model B version)"""
	# Model B: Measurement collapse is handled by parent biome's quantum computer
	has_been_measured = true
	measured_outcome = outcome
	state_collapsed.emit(outcome)


func reset() -> void:
	"""Reset plot to initial unplanted state.
	Called after harvest or when clearing the plot.
	NOTE: persistent_gates is NOT cleared - infrastructure survives harvest."""
	is_planted = false
	has_been_measured = false
	measured_outcome = ""
	# Model B: quantum_state is owned by parent_biome.quantum_computer, not by plot
	register_id = -1  # Clear quantum computer register
	entangled_plots.clear()
	plot_infrastructure_entanglements.clear()
	conspiracy_node_id = ""
	conspiracy_bond_strength = 0.0
	# persistent_gates intentionally NOT cleared - survives harvest/replant


func remove_entanglement(partner_id: String) -> void:
	"""Remove entanglement with a specific plot.
	Called when breaking entanglement or when partner plot is harvested."""
	if entangled_plots.has(partner_id):
		entangled_plots.erase(partner_id)


# ============================================================================
# PERSISTENT GATE INFRASTRUCTURE
# ============================================================================

func add_persistent_gate(gate_type: String, linked_plots: Array[Vector2i] = []) -> void:
	"""Add a persistent gate to this plot. Gates survive harvest/replant."""
	persistent_gates.append({
		"type": gate_type,
		"active": true,
		"linked_plots": linked_plots.duplicate()
	})
	print("🔧 Added persistent gate '%s' to plot %s (linked: %d plots)" % [gate_type, grid_position, linked_plots.size()])


func clear_persistent_gates() -> void:
	"""Remove ALL persistent gate infrastructure from this plot."""
	var count = persistent_gates.size()
	persistent_gates.clear()
	if count > 0:
		print("🔧 Cleared %d persistent gates from plot %s" % [count, grid_position])


func has_active_gate(gate_type: String) -> bool:
	"""Check if this plot has an active gate of the specified type."""
	for gate in persistent_gates:
		if gate.get("type", "") == gate_type and gate.get("active", false):
			return true
	return false


func get_active_gates() -> Array[Dictionary]:
	"""Get all active persistent gates on this plot."""
	var active: Array[Dictionary] = []
	for gate in persistent_gates:
		if gate.get("active", false):
			active.append(gate)
	return active
