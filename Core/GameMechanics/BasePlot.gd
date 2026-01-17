class_name BasePlot
extends Resource

## BasePlot - Foundation class for all farm plots (Model C - Analog Bath)
##
## Model C: Plot is a MEASUREMENT BASIS on a biome's QuantumBath.
## Does NOT own quantum state - only tracks which bath subspace to measure.
##
## OLD (Model B): Plot referenced QuantumComputer register (digital/discrete)
## NEW (Model C): Plot references QuantumBath measurement axis (analog/continuous)

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const QuantumRigorConfig = preload("res://Core/GameState/QuantumRigorConfig.gd")

signal growth_complete
signal state_collapsed(final_state: String)

# ============================================================================
# MODEL C: Bath Measurement Axis (NOT Independent Quantum State)
# ============================================================================

# Plot identification
@export var plot_id: String = ""
@export var grid_position: Vector2i = Vector2i.ZERO

# Model C: Quantum register reference (which register in biome's quantum computer)
# NEW: register_id identifies which qubit in biome's QuantumComputer holds this plot's state
@export var register_id: int = -1  # QuantumComputer register ID (-1 = not planted)
@export var bath_subplot_id: int = -1  # Which subplot in bath's composite state (deprecated, kept for backward compat)
var parent_biome: Node = null  # Reference to BiomeBase that owns quantum computer

# Measurement basis labels (defines which bath axis to measure)
@export var north_emoji: String = "🌾"
@export var south_emoji: String = "🌽"

# Plot metadata (NOT quantum state)
@export var is_planted: bool = false
@export var has_been_measured: bool = false  # DEPRECATED: use is_measured() for v2 terminals
@export var theta_frozen: bool = false  # Measurement locked the theta value (stops Hamiltonian drift)
@export var measured_outcome: String = ""  # Measurement result ("north", "south", or empty)

# V2 Architecture: Reference to bound terminal (when using terminal-based binding)
# When bound_terminal is set, query it for is_measured, emoji_pair, etc.
var bound_terminal = null  # Terminal instance

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
# MODEL C: Quantum State Access (Computed from Parent Biome's Bath)
# ============================================================================

## Get current measurement outcome (or empty if unmeasured)
func get_measurement_outcome() -> String:
	return measured_outcome

## Get basis labels for this plot's measurement basis
func get_basis_labels() -> Array[String]:
	return [north_emoji, south_emoji]

## Get purity from parent biome's quantum bath
func get_purity() -> float:
	"""Query purity from parent biome's quantum bath.

	Model C: Purity is computed from the bath's density matrix.
	For analog bath, we approximate purity from probability distribution.
	Returns 0 if plot not planted or no parent_biome.
	"""
	if not is_planted or not parent_biome:
		return 0.0

	# OLD (Model B): Query quantum_computer for marginal purity
	# var comp = parent_biome.quantum_computer.get_component_containing(register_id)
	# return parent_biome.quantum_computer.get_marginal_purity(comp, register_id)

	# NEW (Model C): Query bath for purity
	if not parent_biome.bath:
		return 0.0

	return parent_biome.bath.get_purity()  # Overall bath purity (Tr(ρ²))

## Get coherence from parent biome's quantum bath
func get_coherence() -> float:
	"""Query coherence from parent biome's quantum bath."""
	if not is_planted or not parent_biome:
		return 0.0

	# OLD (Model B): Query quantum_computer for marginal coherence
	# var comp = parent_biome.quantum_computer.get_component_containing(register_id)
	# return parent_biome.quantum_computer.get_marginal_coherence(comp, register_id)

	# NEW (Model C): Query bath for coherence
	if not parent_biome.bath:
		return 0.0

	# Bath coherence is related to off-diagonal density matrix elements
	# For now, approximate from purity
	return parent_biome.bath.get_purity()

## Get mass (probability in subspace)
func get_mass() -> float:
	"""Get probability mass in measurement basis subspace."""
	if not is_planted or not parent_biome:
		return 0.0

	# OLD (Model B): Query quantum_computer for probability in subspace
	# var comp = parent_biome.quantum_computer.get_component_containing(register_id)
	# return parent_biome.quantum_computer.get_marginal_probability_subspace(comp, register_id, [north_emoji, south_emoji])

	# NEW (Model C): Query bath for probability in north/south subspace
	if not parent_biome.bath:
		return 0.0

	var p_north = parent_biome.bath.get_probability(north_emoji)
	var p_south = parent_biome.bath.get_probability(south_emoji)
	return p_north + p_south

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

	V2 Architecture: Delegates to bound_terminal when available.
	Falls back to legacy behavior for v1 compatibility.

	PHASE 5 (PARAMETRIC): Queries parent biome capabilities for emoji pair.
	Falls back to current north/south emojis if no biome or capability found.

	Subclasses can override to customize per-plot basis.
	"""
	# V2: If bound_terminal exists, delegate to it (single source of truth)
	if bound_terminal and bound_terminal.is_bound:
		return bound_terminal.get_emoji_pair()

	# PARAMETRIC: Query parent biome for capability if plot_type_name is set
	if parent_biome and parent_biome.has_method("get_plantable_capabilities"):
		# Get plot_type_name from subclass (FarmPlot has this property)
		var type_name = get("plot_type_name")
		if type_name:
			# Find capability matching plot_type_name
			for cap in parent_biome.get_plantable_capabilities():
				if cap.plant_type == type_name:
					return cap.emoji_pair

	# Fallback: Return current basis labels (set during planting)
	return {"north": north_emoji, "south": south_emoji}


## V2 computed property: is this plot measured?
## Delegates to bound_terminal when available, falls back to has_been_measured
func is_measured() -> bool:
	if bound_terminal:
		return bound_terminal.is_measured
	return has_been_measured


## V2 computed property: is this plot occupied (bound to a terminal)?
## For v2 architecture, a plot is "occupied" if it has a bound terminal
func is_occupied() -> bool:
	return bound_terminal != null and bound_terminal.is_bound


func plant(biome_or_labor = null, wheat_cost: float = 0.0, optional_biome = null) -> bool:
	"""Plant this plot - register measurement axis in biome's quantum bath (Model C version)

	Model C: Planting registers this plot as a measurement axis on the biome's
	QuantumBath. Does NOT create independent quantum state - bath is shared.

	OLD (Model B): Allocated register in QuantumComputer
	NEW (Model C): Register subplot in bath's composite state

	Args:
		biome_or_labor: BiomeBase (preferred), or labor amount (legacy)
		wheat_cost: Wheat cost (legacy parameter, ignored)
		optional_biome: BiomeBase if first arg is labor amount (legacy)

	Returns:
		true if successful, false if failed
	"""
	# Determine parent biome
	var biome = null
	# OLD (Model B): Check for allocate_register_for_plot method
	# if biome_or_labor is Node and biome_or_labor.has_method("allocate_register_for_plot"):

	# NEW (Model C): Check for bath OR quantum_computer property
	# Model C biomes may use bath (MarketBiome, ForestEcosystem) or quantum_computer (BioticFlux, QuantumKitchen)
	if biome_or_labor is Node and ("bath" in biome_or_labor or "quantum_computer" in biome_or_labor):
		biome = biome_or_labor
	elif optional_biome and ("bath" in optional_biome or "quantum_computer" in optional_biome):
		biome = optional_biome
	else:
		push_error("No valid biome with bath or quantum_computer provided for planting!")
		return false

	parent_biome = biome

	# Get basis labels for this plot
	var emojis = get_plot_emojis()
	north_emoji = emojis.get("north", "🌾")
	south_emoji = emojis.get("south", "🌽")

	# Allocate register in biome's quantum computer
	if "quantum_computer" in biome and biome.quantum_computer:
		register_id = biome.quantum_computer.allocate_register(north_emoji, south_emoji)
		if register_id < 0:
			push_error("Failed to allocate quantum register for plot %s!" % grid_position)
			return false
		# Bath is deprecated - density matrix now in quantum_computer
		bath_subplot_id = register_id  # For backward compatibility tracking
	else:
		push_error("Biome has no quantum_computer for plot %s!" % grid_position)
		return false

	# Mark as planted
	is_planted = true
	has_been_measured = false
	measured_outcome = ""

	print("🌱 Plot %s: registered measurement axis (%s/%s) in %s biome bath" % [
		grid_position, north_emoji, south_emoji, biome.get_biome_type()])
	return true


func measure(_icon_network = null) -> String:
	"""Measure (collapse) quantum state at this plot (Model C version)

	Model C: Delegates to parent_biome's bath.measure_axis() for projective measurement.

	OLD (Model B): Measured specific register in QuantumComputer
	NEW (Model C): Measures north/south axis in QuantumBath

	Returns: The measurement outcome emoji (north_emoji or south_emoji)
	Sets: has_been_measured = true and measured_outcome on success
	"""
	if not parent_biome:
		push_error("Plot %s not properly planted - no parent biome!" % grid_position)
		return ""

	if not is_planted:
		push_error("Cannot measure unplanted plot!")
		return ""

	if has_been_measured:
		push_warning("Plot %s already measured - outcome: %s" % [grid_position, measured_outcome])
		# Convert outcome emoji back to basis name
		if measured_outcome == north_emoji:
			return "north"
		elif measured_outcome == south_emoji:
			return "south"
		return measured_outcome

	# OLD (Model B): Get component and measure register
	# var comp = parent_biome.quantum_computer.get_component_containing(register_id)
	# if not comp:
	# 	push_error("Register %d not in any component!" % register_id)
	# 	return ""
	# var outcome = parent_biome.quantum_computer.measure_register(comp, register_id)

	# NEW (Model C): Measure axis in bath
	if not parent_biome.bath:
		push_error("Parent biome %s has no bath!" % parent_biome.get_biome_type())
		return ""

	# Measure north/south axis using marginal measurement
	# (sums over all states containing north/south emoji)
	var outcome_emoji = parent_biome.bath.measure_marginal_axis(north_emoji, south_emoji)

	if outcome_emoji == "":
		push_error("Bath measurement failed for plot %s!" % grid_position)
		return ""

	# Convert emoji outcome to basis name for internal storage
	var basis_outcome = "north" if outcome_emoji == north_emoji else "south"

	# Record outcome
	has_been_measured = true
	measured_outcome = basis_outcome

	print("🔬 Plot %s measured: outcome=%s (emoji: %s, north: %s, south: %s)" % [
		grid_position, basis_outcome, outcome_emoji, north_emoji, south_emoji])

	return basis_outcome


func harvest() -> Dictionary:
	"""Harvest this plot - collect yield and clear quantum state (Model C version)

	Model C: Queries purity from parent_biome's bath.

	OLD (Model B): Queried quantum_computer for purity
	NEW (Model C): Queries bath for purity

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

	# Map basis outcome to emoji (measured_outcome is basis name "north" or "south")
	if measured_outcome == "north":
		outcome = north_emoji
	elif measured_outcome == "south":
		outcome = south_emoji
	else:
		outcome = "?"

	# OLD (Model B): Get purity from quantum_computer
	# var purity = get_purity()  # Queries quantum_computer

	# NEW (Model C): Get purity from bath
	var purity = get_purity()  # Now queries bath.get_purity()
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

	# Clear the plot
	is_planted = false
	# OLD (Model B): register_id = -1
	# NEW (Model C): bath_subplot_id = -1
	bath_subplot_id = -1
	has_been_measured = false
	measured_outcome = ""  # Clear stored outcome
	replant_cycles += 1

	# OLD (Model B): Remove register from parent biome
	# if parent_biome and parent_biome.has_method("clear_register_for_plot"):
	# 	parent_biome.clear_register_for_plot(grid_position)

	# NEW (Model C): Clear subplot from parent biome (if method exists)
	if parent_biome and parent_biome.has_method("clear_subplot_for_plot"):
		parent_biome.clear_subplot_for_plot(grid_position)
	# Note: Bath state persists - not cleared on individual plot harvest

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
	# OLD (Model B): quantum_state is owned by parent_biome.quantum_computer, not by plot
	# register_id = -1  # Clear quantum computer register
	# NEW (Model C): quantum_state is owned by parent_biome.bath, not by plot
	bath_subplot_id = -1  # Clear bath subplot reference
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
